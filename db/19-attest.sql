-- ═══════════════════════════════════════════════════════════════
--  19-attest.sql  ·  到課共同確認（第一期：只做存證，不碰金額）
--  2026-08-16
--
--  取代的是舊流程裡「教練和學員一起簽在紙上」那個動作。
--
--  ☢️ 這一支【完全不碰扣款】。check_in() 一行都沒改。
--     客人的確認是「另外一條紀錄」，不是扣課的前提 ——
--     客人手機沒電、忘了帶、當場不會用，課都還是要能結算。
--     把確認做成前提的話，第一次遇到沒電就會癱在現場，
--     然後所有人就回去用紙了。
--
--  ☢️ 客人的確認【絕對不會】把 attended 打勾。
--     否則客人就能自己扣自己的堂數 —— 那會打破第 39 步最重要的
--     那條規則：動到錢的入口只有一個，而且只有教練走得進去。
-- ═══════════════════════════════════════════════════════════════

-- ── ① 兩個欄位 ────────────────────────────────────────────────
alter table public.bookings
  add column if not exists confirmed_at   timestamptz,
  add column if not exists confirmed_by   text;    -- 'qr' | 'staff'

comment on column public.bookings.confirmed_at is
  '客人本人確認到課的時間。null = 還沒確認。☢️ 跟 status/attended 無關，不影響扣課。';
comment on column public.bookings.confirmed_by is
  '確認來源：qr = 客人自己掃碼確認；staff = 教練代確認（要留痕，帳上可信度較低）。';

-- ── ② 一次性 QR 憑證 ──────────────────────────────────────────
create table if not exists public.checkin_tokens (
  token       text        primary key,
  session_id  uuid        not null references public.class_sessions(id) on delete cascade,
  issued_by   uuid        not null references public.employees(id),
  issued_at   timestamptz not null default now(),
  expires_at  timestamptz not null
);
comment on table public.checkin_tokens is
  '教練畫面上那個 QR 的內容。60 秒過期。☢️ 它只證明「掃的人當時看得到教練的螢幕」。';

create index if not exists checkin_tokens_expiry on public.checkin_tokens (expires_at);

alter table public.checkin_tokens enable row level security;

-- ☢️ 沒有任何 select policy —— 誰都不能列出憑證。
--    發放和驗證都只能走底下兩支 security definer 函式。
drop policy if exists "員工可發憑證" on public.checkin_tokens;
create policy "員工可發憑證" on public.checkin_tokens
  for insert with check ( public.is_staff() );

-- ── ③ 教練發一張憑證 ──────────────────────────────────────────
create or replace function public.issue_checkin_token(p_session uuid)
returns text
language plpgsql security definer set search_path = public as $$
declare v_token text; v_start timestamptz;
begin
  if not public.is_staff() then
    raise exception '只有教練可以產生確認碼';
  end if;

  select (s.session_date + s.start_time) at time zone 'Asia/Taipei'
    into v_start
  from public.class_sessions s
  where s.id = p_session and s.product = 'GT' and s.status <> 'cancelled';

  if v_start is null then
    raise exception '找不到這堂課，或這堂課已經取消';
  end if;

  -- ☢️ 只有「課開始前 30 分鐘 ～ 課後 2 小時」之間才發得出來。
  --    憑證能在任何時間發的話，就等於一張可以帶回家的空白簽名。
  if now() < v_start - interval '30 min' or now() > v_start + interval '2 hour' then
    raise exception '確認碼只能在課前 30 分鐘到課後 2 小時之間產生';
  end if;

  v_token := encode(gen_random_bytes(16), 'hex');

  insert into public.checkin_tokens (token, session_id, issued_by, expires_at)
  values (v_token, p_session, public.my_employee_id(), now() + interval '60 sec');

  -- 順手清掉過期的，這張表不需要留歷史
  delete from public.checkin_tokens where expires_at < now() - interval '1 day';

  return v_token;
end $$;

revoke all on function public.issue_checkin_token(uuid) from public;
grant execute on function public.issue_checkin_token(uuid) to authenticated;

-- ── ④ 客人拿憑證確認自己那一筆 ────────────────────────────────
create or replace function public.confirm_attendance(p_token text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_session uuid; v_me uuid; v_booking uuid; v_title text; v_when text;
begin
  select t.session_id into v_session
  from public.checkin_tokens t
  where t.token = p_token and t.expires_at > now();

  if v_session is null then
    return jsonb_build_object('ok', false, 'why', 'expired');
  end if;

  v_me := public.my_customer_id();
  if v_me is null then
    return jsonb_build_object('ok', false, 'why', 'not_bound');
  end if;

  -- ☢️ 只找【自己的】那一筆。找不到就是沒報名這堂課。
  select b.id into v_booking
  from public.bookings b
  where b.session_id = v_session
    and b.customer_id = v_me
    and b.status in ('booked','attended');

  if v_booking is null then
    return jsonb_build_object('ok', false, 'why', 'no_booking');
  end if;

  -- ☢️ 這裡【只】寫 confirmed_at。
  --    不碰 status、不碰 attended、不碰 credit_ledger。
  update public.bookings
     set confirmed_at = coalesce(confirmed_at, now()),
         confirmed_by = coalesce(confirmed_by, 'qr')
   where id = v_booking;

  select s.title, to_char(s.session_date,'MM/DD') || ' ' || to_char(s.start_time,'HH24:MI')
    into v_title, v_when
  from public.class_sessions s where s.id = v_session;

  return jsonb_build_object('ok', true, 'title', v_title, 'when', v_when);
end $$;

revoke all on function public.confirm_attendance(text) from public;
grant execute on function public.confirm_attendance(text) to authenticated;

-- ── ⑤ my_bookings 加上「還沒確認」 ────────────────────────────
--     ☢️ 原本的欄位【一個都不能少、一個都不能改】—— 前端是照欄位名取的。
--        下面是把現有定義原封不動抄過來，只在最後【加】兩欄。
--        （第一版我漏抄了 booked_at / cancelled_at，而且順手把 can_cancel
--          的條件改嚴了 —— 那會讓「已上課」的紀錄突然變成可取消的樣子。
--          ☢️ 改檢視表之前一定要先 pg_get_viewdef 看一次。）
create or replace view public.my_bookings
  with (security_invoker = true) as
select b.id,
       b.session_id,
       b.status,
       b.booked_at,
       b.cancelled_at,
       s.session_date,
       s.start_time,
       s.duration_min,
       s.title,
       s.level,
       e.display_name as coach_name,
       (((s.session_date + s.start_time) at time zone 'Asia/Taipei') - now())
         > '01:00:00'::interval                                as can_cancel,
       ((s.session_date + s.start_time) at time zone 'Asia/Taipei') as starts_at,
       -- ↓↓ 這一版新增的兩欄 ↓↓
       b.confirmed_at,
       (b.status = 'attended' and b.confirmed_at is null)      as needs_confirm
from bookings b
join class_sessions s on s.id = b.session_id
left join employees   e on e.id = s.coach_id
where b.customer_id = my_customer_id();
