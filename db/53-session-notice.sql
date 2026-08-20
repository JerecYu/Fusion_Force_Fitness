-- 53｜停課／異動只通知那堂課的人
--
-- 起因（2026-08-16 查到的數字）：「⚠️團課異動⚠️」現在是群發給全部 204 位好友，
-- 而 LINE 中用量每月 3,000 則、群發按好友人數計費 —— 一次就是 204 則。
-- 8/01～8/16 已用掉 2,217 則（74%）。真正需要知道的只有訂了那一堂的那幾個人。
--
-- ☢️☢️ 為什麼不能「照著 line_user_id 推過去就好」
--    `customers.line_user_id` 來自 LINE Login channel（2011063116），
--    推播要的是 Messaging API channel（2009245280）的編號 ——
--    兩個 channel 在【不同的 Provider】，LINE 的 userId 是以 provider 為單位的。
--    2026-08-19 用 Jerec 本人證實過：同一個人兩組完全不同的號碼。
--    而且 channel 不能換 provider（官方文件寫死），所以這件事沒有捷徑。
--
--    橋：客人按一顆按鈕 → LINE 開啟官方帳號聊天室、訊息預填一組一次性短碼
--        → 他按送出 → webhook 收到「這則訊息的 userId ＋ 那個短碼」
--        → 兩組編號對起來，寫進 customers.push_user_id。
--
-- ☢️ 所以橋剛架好那天，推得到的人是 0，之後才一個一個累積。
--    這一支的設計前提就是「一定有人推不到」——
--    推不到的人會列成名單給櫃檯，不是靜靜消失。

begin;

-- ═══════════════════════════════════════════════════════════════
-- 1）推播編號 ＋ 一次性短碼
-- ═══════════════════════════════════════════════════════════════
alter table public.customers
  add column if not exists push_user_id text;

create unique index if not exists customers_push_user_id_uniq
  on public.customers (push_user_id) where push_user_id is not null;

comment on column public.customers.push_user_id is
  '官方帳號（Messaging API channel 2009245280）那一組 userId。☢️ 跟 line_user_id 不是同一組，不可互換。';

create table if not exists public.push_links (
  code        text primary key,
  customer_id uuid not null references public.customers(id) on delete cascade,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null,
  used_at     timestamptz,
  used_by     text
);

comment on table public.push_links is
  '開啟推播通知用的一次性短碼。☢️ 短命（30 分鐘）且只能用一次 —— 這串字被轉傳出去，別人就能把自己的 LINE 綁到這位客人身上。';

create index if not exists push_links_customer on public.push_links (customer_id, created_at desc);

-- ═══════════════════════════════════════════════════════════════
-- 2）客人要一組短碼
-- ═══════════════════════════════════════════════════════════════
-- ☢️ 短碼的字母表刻意拿掉 0/O/1/I/L —— 雖然是預填的不用手打，
--    但客人會把它唸給櫃檯聽，而「零跟歐」在電話裡分不出來。
create or replace function public.issue_push_code()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_cust uuid;
  v_code text;
  v_alpha text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  i int;
begin
  v_cust := public.my_customer_id();
  if v_cust is null then
    return jsonb_build_object('ok', false, 'why', 'not_a_customer',
      'msg', '要先綁定才能開啟通知');
  end if;

  -- 已經綁好了就不用再來一次
  if exists (select 1 from public.customers where id = v_cust and push_user_id is not null) then
    return jsonb_build_object('ok', true, 'already', true);
  end if;

  -- 還沒過期又沒用掉的就沿用，不要每按一次就生一組
  select code into v_code from public.push_links
   where customer_id = v_cust and used_at is null and expires_at > now()
   order by created_at desc limit 1;

  if v_code is null then
    loop
      v_code := '';
      for i in 1..6 loop
        v_code := v_code || substr(v_alpha, 1 + floor(random() * length(v_alpha))::int, 1);
      end loop;
      exit when not exists (select 1 from public.push_links where code = v_code);
    end loop;
    insert into public.push_links (code, customer_id, expires_at)
    values (v_code, v_cust, now() + interval '30 minutes');
  end if;

  return jsonb_build_object('ok', true, 'already', false, 'code', v_code);
end $$;

-- ═══════════════════════════════════════════════════════════════
-- 3）通知紀錄
-- ═══════════════════════════════════════════════════════════════
create table if not exists public.class_notices (
  id         uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.class_sessions(id) on delete cascade,
  kind       text not null check (kind in ('cancel','change','note')),
  body       text not null,
  sent_by    uuid references public.employees(id),
  created_at timestamptz not null default now(),
  n_target   int not null default 0,   -- 這堂課本來有幾個人
  n_push     int not null default 0,   -- 推播真的送出去幾則
  n_manual   int not null default 0,   -- 推不到、要人工聯絡幾位
  result     jsonb
);

create index if not exists class_notices_session on public.class_notices (session_id, created_at desc);

-- ═══════════════════════════════════════════════════════════════
-- 4）取消課次
-- ═══════════════════════════════════════════════════════════════
-- ☢️ 已經有人點過名的課【不能】取消。那不是「停課」，那是「上完了」——
--    取消它會讓已經扣掉的堂數變成沒有對應的課，對帳當場壞掉。
create or replace function public.cancel_session(p_session uuid, p_why text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_me   uuid;
  v_s    record;
  v_done int;
  v_n    int;
begin
  if not public.is_staff() then
    raise exception '只有職員可以取消課次';
  end if;
  v_me := public.my_employee_id();

  select s.*, e.display_name as coach_name into v_s
  from public.class_sessions s
  left join public.employees e on e.id = s.coach_id
  where s.id = p_session;

  if not found then
    return jsonb_build_object('ok', false, 'why', 'no_session', 'msg', '找不到這堂課');
  end if;
  if v_s.status = 'cancelled' then
    return jsonb_build_object('ok', false, 'why', 'already', 'msg', '這堂課已經是取消狀態了');
  end if;

  select count(*) into v_done
  from public.bookings b
  where b.session_id = p_session
    and exists (select 1 from public.credit_ledger l where l.booking_id = b.id);

  if v_done > 0 then
    return jsonb_build_object('ok', false, 'why', 'already_checked_in',
      'msg', '這堂課已經有 ' || v_done || ' 個人點過名、扣過堂數了 —— 取消它會讓那些堂數變成沒有對應的課。要處理請先在點名頁把出席改掉。');
  end if;

  update public.class_sessions
     set status = 'cancelled'
   where id = p_session;

  update public.bookings
     set status = 'cancelled', cancelled_at = now(), cancelled_by = v_me
   where session_id = p_session and status = 'booked';
  get diagnostics v_n = row_count;

  insert into public.class_notices (session_id, kind, body, sent_by, n_target)
  values (p_session, 'cancel',
          coalesce(nullif(trim(p_why), ''), '課程取消'), v_me, v_n);

  return jsonb_build_object('ok', true, 'cancelled_bookings', v_n,
    'session', jsonb_build_object(
      'date',  v_s.session_date, 'time', to_char(v_s.start_time, 'HH24:MI'),
      'title', v_s.title, 'coach', v_s.coach_name));
end $$;

-- ═══════════════════════════════════════════════════════════════
-- 5）要通知誰
-- ═══════════════════════════════════════════════════════════════
-- ☢️ 這一支同時回傳「推得到的」和「推不到的」。
--    只回傳推得到的那半邊，另外那半邊就會安靜地消失 ——
--    而消失的那些人，正是會在門口站著等的人。
create or replace function public.session_notice_list(p_session uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare v_s record; v_push jsonb; v_manual jsonb;
begin
  if not public.is_staff() then
    raise exception '只有職員看得到通知名單';
  end if;

  select s.session_date, s.start_time, s.title, s.status, e.display_name as coach_name
    into v_s
  from public.class_sessions s
  left join public.employees e on e.id = s.coach_id
  where s.id = p_session;
  if not found then
    return jsonb_build_object('ok', false, 'why', 'no_session');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'customer_id', c.id, 'name', c.name, 'phone_tail', right(c.phone, 3))
         order by c.name), '[]'::jsonb)
    into v_push
  from public.bookings b
  join public.customers c on c.id = b.customer_id
  where b.session_id = p_session
    and b.status in ('booked','cancelled')
    and c.push_user_id is not null;

  select coalesce(jsonb_agg(jsonb_build_object(
           'customer_id', c.id, 'name', c.name, 'phone_tail', right(c.phone, 3))
         order by c.name), '[]'::jsonb)
    into v_manual
  from public.bookings b
  join public.customers c on c.id = b.customer_id
  where b.session_id = p_session
    and b.status in ('booked','cancelled')
    and c.push_user_id is null;

  return jsonb_build_object(
    'ok', true,
    'session', jsonb_build_object(
      'date', v_s.session_date, 'time', to_char(v_s.start_time, 'HH24:MI'),
      'title', v_s.title, 'coach', v_s.coach_name, 'status', v_s.status),
    'push',   v_push,
    'manual', v_manual);
end $$;

-- ═══════════════════════════════════════════════════════════════
-- 6）推播涵蓋率 —— 橋架好之後要看著它長
-- ═══════════════════════════════════════════════════════════════
create or replace view public.staff_push_coverage as
select
  count(*)                                                as 客人數,
  count(*) filter (where line_user_id is not null)         as 已綁訂課,
  count(*) filter (where push_user_id is not null)         as 已開通知,
  count(*) filter (where line_user_id is not null
                     and push_user_id is null)             as 訂課有但通知沒有
from public.customers
where is_active is not false;

-- ═══════════════════════════════════════════════════════════════
-- 7）權限
-- ═══════════════════════════════════════════════════════════════
alter table public.push_links    enable row level security;
alter table public.class_notices enable row level security;
-- ☢️ 兩張表都【不開任何 policy】。
--    push_links 存的是「按了就能綁走一位客人」的短碼 —— 客人自己也不該讀得到
--    別人的那一列，而他需要的那一組是 issue_push_code() 直接回給他的。
--    class_notices 由 definer 函式與 Edge Function（service role）寫入。

grant execute on function public.issue_push_code()               to authenticated;
grant execute on function public.cancel_session(uuid, text)      to authenticated;
grant execute on function public.session_notice_list(uuid)       to authenticated;
grant select  on public.staff_push_coverage                      to authenticated;

commit;

-- ── 驗收 ────────────────────────────────────────────────────
-- select * from public.staff_push_coverage;
--   → 客人數 94 / 已綁訂課 47 / 已開通知 0 / 訂課有但通知沒有 47
--
-- ☢️ 「已開通知」會從 0 開始長。長不動就代表按鈕沒人按，
--    那是文案或位置的問題，不是程式的問題。
