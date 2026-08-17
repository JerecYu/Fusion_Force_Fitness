/* ═══════════════════════════════════════════════════════════════════════
   db/17-checkin.sql  ——  第 39 步：課後點名核銷（資料庫這一半）

   規則（全部來自 HANDOVER 第四節與 2026-08-11 的決定）：
     · 出席 → 扣 1 堂        · 缺席 → 不扣
     · 剩 0 堂照樣扣，餘額可以是負的（欠課，櫃檯補收）
     · 補登最多往回 7 天
     · 沒報名的人可以現場加進來

   ☢️ 這支檔案最重要的一件事：
      【扣課只有一個入口】。教練不能直接改 bookings 的 attended，
      也拿不到 credit_ledger 的寫入權限 —— 只能呼叫 check_in()。
      入口只有一個，帳才有可能一直是對的。
   ═══════════════════════════════════════════════════════════════════════ */


/* ── 1 ☢️ 保險絲：同一筆預約不可能被扣兩次 ──────────────────────────

   前端防連點、函式檢查狀態，這些都會失效（網路重送、兩支手機同時點、
   我哪天改壞一行）。這條索引是最後一道，它由資料庫執行，繞不過去。

   partial index 的兩個條件都是必要的：
     reason = 'class'      更正用的 adjust 筆數不限，才有辦法改回來
     booking_id is not null 舊資料和購課筆數沒有 booking_id，不能被綁住
   ────────────────────────────────────────────────────────────────── */

create unique index if not exists credit_ledger_class_once
  on public.credit_ledger (booking_id)
  where reason = 'class' and booking_id is not null;


/* ── 2  收緊 bookings 的兩條員工政策 ────────────────────────────────

   原本：
     「員工可代開預約」 insert with check ( is_staff() )
     「員工可點名」     update using      ( is_staff() )   ← 沒有 with check

   問題一樣：只檢查「誰」，不檢查「改成什麼」。
   員工可以直接塞一筆 status='attended' 的預約，或把任何一筆改成 attended
   —— 而那筆不會有對應的扣課紀錄。第 40 步的鐘點費會算進去，
   客人的堂數卻沒有少。兩本帳從那一刻起就對不起來，而且不會報錯。

   ☢️ 政策名稱從「員工可點名」改成「員工可代客取消」——
      因為點名這件事從現在起【不走政策，走 check_in()】。
   ────────────────────────────────────────────────────────────────── */

drop policy if exists "員工可代開預約" on public.bookings;

create policy "員工可代開預約" on public.bookings
  for insert
  with check ( public.is_staff() and status = 'booked' );


drop policy if exists "員工可點名"     on public.bookings;
drop policy if exists "員工可代客取消" on public.bookings;

create policy "員工可代客取消" on public.bookings
  for update
  using      ( public.is_staff() )
  with check ( public.is_staff() and status in ('booked','cancelled') );
  -- ☢️ attended / absent 不在這個清單裡，這是刻意的。


/* ── 3  點名：check_in(預約, 有沒有到) ─────────────────────────────

   security definer —— 它自己檢查身分，然後用資料表擁有者的權限寫帳。
   所以教練【不需要】credit_ledger 的任何權限，也就不可能繞過這裡記帳。

   ☢️ 記帳方式是「對帳到目標」，不是「補一筆」：

       目標   出席 = 這筆預約總共扣 1 堂（淨額 -1）
              缺席 = 這筆預約總共扣 0 堂（淨額  0）

       實際   把這筆預約在 credit_ledger 的 delta 加總起來

       差額   目標 - 實際，不是 0 就補一筆

   這樣寫的好處是【怎麼點都不會錯】：連點兩次、出席改缺席再改回出席、
   網路重送 —— 最後的淨額一定等於目標。用「if 出席就扣一堂」那種寫法，
   每一種順序都要各想一次，想漏一種就是一筆對不起來的帳。
   ────────────────────────────────────────────────────────────────── */

create or replace function public.check_in(p_booking uuid, p_present boolean)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me        uuid;
  v_b         record;
  v_start     timestamptz;
  v_new       text;
  v_charged   integer;
  v_target    integer;
  v_diff      integer;
  v_has_class boolean;
begin
  /* 3-1 身分 */
  if not public.is_staff() then
    raise exception '只有員工可以點名';
  end if;
  v_me := public.my_employee_id();

  /* 3-2 把預約和課次一起撈出來。撈不到就是撈不到，不要猜。 */
  select b.id, b.status, b.customer_id, b.paid_by_customer_id,
         s.id as session_id, s.product, s.status as s_status,
         s.session_date, s.start_time
    into v_b
    from public.bookings b
    join public.class_sessions s on s.id = b.session_id
   where b.id = p_booking;

  if not found then
    raise exception '找不到這筆預約';
  end if;

  /* 3-3 這堂課點得了嗎 */
  if v_b.product <> 'GT' then
    raise exception '這不是團體課，私人課不走這裡';
  end if;

  if v_b.s_status = 'cancelled' then
    raise exception '這堂課已經取消了';
  end if;

  if v_b.status = 'cancelled' then
    raise exception '這個人已經取消報名了';
  end if;

  -- ☢️ 資料庫時區是 UTC。session_date + start_time 是台灣時間的字面值，
  --    一定要 at time zone 'Asia/Taipei' 才會變成正確的時刻。（規則 16）
  v_start := (v_b.session_date + v_b.start_time) at time zone 'Asia/Taipei';

  if v_start > now() then
    raise exception '這堂課還沒開始，還不能點名';
  end if;

  if v_start < now() - interval '7 days' then
    raise exception '這堂課超過 7 天了，請找 Jerec 在後台處理';
  end if;

  /* 3-4 改預約狀態 */
  v_new := case when p_present then 'attended' else 'absent' end;

  update public.bookings
     set status     = v_new,
         checked_by = v_me,
         checked_at = now()
   where id = p_booking;

  /* 3-5 對帳到目標 */
  select coalesce(sum(delta), 0),
         bool_or(reason = 'class')
    into v_charged, v_has_class
    from public.credit_ledger
   where booking_id = p_booking;

  v_target := case when p_present then -1 else 0 end;
  v_diff   := v_target - coalesce(v_charged, 0);

  if v_diff <> 0 then
    insert into public.credit_ledger
      (customer_id, delta, reason, booking_id, note, created_by, product)
    values (
      -- ☢️ 扣的是【付錢的人】，不是上課的人。
      --    bookings 有 paid_by_customer_id 就是為了「我幫你付」這件事。
      v_b.paid_by_customer_id,
      v_diff,
      case when coalesce(v_has_class, false) then 'adjust' else 'class' end,
      p_booking,
      case
        when not coalesce(v_has_class, false) then '團體課核銷'
        when p_present then '點名更正：改為出席'
        else                '點名更正：改為缺席'
      end,
      v_me,
      'GT'
    );
  end if;

  return v_new;
end;
$$;


/* ── 4  現場加人：add_walkin(課次, 客人) ────────────────────────────

   沒報名就來了的老客人。建一筆 status='booked' 的預約，
   接著教練照一般流程點他出席 —— 記帳仍然只走 check_in()。

   已經有預約的話不重建，直接把原本那筆的 id 還回去
   （bookings 有 unique (session_id, customer_id)，硬塞會撞）。
   ────────────────────────────────────────────────────────────────── */

create or replace function public.add_walkin(p_session uuid, p_customer uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_s     record;
  v_start timestamptz;
  v_id    uuid;
begin
  if not public.is_staff() then
    raise exception '只有員工可以加人';
  end if;

  select id, product, status, session_date, start_time
    into v_s
    from public.class_sessions
   where id = p_session;

  if not found then
    raise exception '找不到這堂課';
  end if;
  if v_s.product <> 'GT' then
    raise exception '這不是團體課';
  end if;
  if v_s.status = 'cancelled' then
    raise exception '這堂課已經取消了';
  end if;

  v_start := (v_s.session_date + v_s.start_time) at time zone 'Asia/Taipei';
  if v_start < now() - interval '7 days' then
    raise exception '這堂課超過 7 天了，請找 Jerec 在後台處理';
  end if;

  if not exists (select 1 from public.customers
                  where id = p_customer and is_active = true) then
    raise exception '找不到這位客人，或他已經停用';
  end if;

  /* 已經有了就還原本那筆，包括已取消的（把他放回 booked） */
  select id into v_id
    from public.bookings
   where session_id = p_session and customer_id = p_customer;

  if found then
    update public.bookings
       set status       = 'booked',
           cancelled_at = null
     where id = v_id
       and status = 'cancelled';
    return v_id;
  end if;

  insert into public.bookings
    (session_id, customer_id, paid_by_customer_id, status)
  values (p_session, p_customer, p_customer, 'booked')
  returning id into v_id;

  return v_id;
end;
$$;


/* ── 5  教練看的兩張表 ──────────────────────────────────────────────

   都是 definer 檢視表，第一行就是 where public.is_staff() ——
   那一行【就是】那道牆，不是裝飾。沒開通的人查到 0 列。

   ☢️ 「今天」一律用 (now() at time zone 'Asia/Taipei')::date。
      直接寫 current_date 的話，台灣早上 8 點以前 UTC 還是昨天，
      教練一早開啟會看到昨天的課而不是今天的。不會報錯。
   ────────────────────────────────────────────────────────────────── */

-- 5-1 課次清單：最近 7 天 ＋ 今天以後的課，含點名進度
create or replace view public.staff_sessions as
select
  s.id                                   as session_id,
  s.session_date,
  s.start_time,
  s.title,
  s.level,
  s.status                               as session_status,
  s.coach_id,
  e.display_name                         as coach_name,
  ((s.session_date + s.start_time) at time zone 'Asia/Taipei') as starts_at,
  -- ☢️ 欄位名一律用英文。前端是用網址參數點欄位的，中文欄名要編碼，
  --    多一層可能出錯的地方，而且錯了看起來像「查不到資料」。（規則 5）
  count(b.id) filter (where b.status <> 'cancelled')  as n_expected,   -- 應到
  count(b.id) filter (where b.status = 'attended')    as n_present,    -- 已到
  count(b.id) filter (where b.status = 'absent')      as n_absent,     -- 缺席
  count(b.id) filter (where b.status = 'booked')      as n_pending     -- 還沒點
from public.class_sessions s
left join public.employees e on e.id = s.coach_id
left join public.bookings  b on b.session_id = s.id
where public.is_staff()
  and s.product = 'GT'
  and s.session_date >= ((now() at time zone 'Asia/Taipei')::date - 7)
  and s.session_date <= ((now() at time zone 'Asia/Taipei')::date + 1)
group by s.id, e.display_name;

-- 5-2 名單：上面那些課次裡的每一個人
create or replace view public.staff_roster as
select
  b.id                     as booking_id,
  b.session_id,
  b.status                 as booking_status,
  b.checked_at,
  ck.display_name          as checked_by_name,
  c.id                     as customer_id,
  c.name                   as customer_name,
  right(c.phone, 3)        as phone_tail,
  b.paid_by_customer_id,
  payer.name               as payer_name,
  coalesce(bal.balance, 0) as balance
from public.bookings b
join public.class_sessions s on s.id = b.session_id
join public.customers      c on c.id = b.customer_id
left join public.customers payer on payer.id = b.paid_by_customer_id
left join public.employees ck    on ck.id = b.checked_by
left join lateral (
  select sum(l.delta)::integer as balance
  from public.credit_ledger l
  where l.customer_id = b.paid_by_customer_id
    and l.product = 'GT'
) bal on true
where public.is_staff()
  and s.product = 'GT'
  and s.session_date >= ((now() at time zone 'Asia/Taipei')::date - 7)
  and s.session_date <= ((now() at time zone 'Asia/Taipei')::date + 1);


/* ── 6  開權限 ──────────────────────────────────────────────────────
   ☢️ credit_ledger 對 authenticated 一個權限都不給。
      教練寫帳的唯一方式是 check_in()，這是刻意的。
   ────────────────────────────────────────────────────────────────── */

grant select on public.staff_sessions to authenticated;
grant select on public.staff_roster   to authenticated;

grant execute on function public.check_in(uuid, boolean) to authenticated;
grant execute on function public.add_walkin(uuid, uuid)  to authenticated;


/* ── 7  驗收 ────────────────────────────────────────────────────────
   整張 Run 完之後對照註解看。
   ────────────────────────────────────────────────────────────────── */

-- 7-1 保險絲在不在
select indexname as 索引, indexdef as 定義
from pg_indexes
where schemaname='public' and tablename='credit_ledger' and indexname='credit_ledger_class_once';
-- 期望：回 1 列

-- 7-2 兩條政策是不是都有 check 條件，而且 attended 不在裡面
select policyname as 規則, cmd as 動作, coalesce(with_check,'—') as check條件
from pg_policies where schemaname='public' and tablename='bookings' order by cmd, policyname;
-- 期望：「員工可代開預約」的 check 有 status = 'booked'
--       「員工可代客取消」的 check 有 status in ('booked','cancelled')
--       ☢️ 兩條裡面都【不可以】出現 attended

-- 7-3 credit_ledger 對 authenticated 應該一個權限都沒有
select coalesce(string_agg(privilege_type, ', '), '（沒有，正確）') as credit_ledger給authenticated的權限
from information_schema.role_table_grants
where table_schema='public' and table_name='credit_ledger' and grantee='authenticated'
  and privilege_type in ('SELECT','INSERT','UPDATE','DELETE');
-- 期望：（沒有，正確）

-- 7-4 兩張檢視表是不是 definer
select c.relname as 檢視表,
       case when c.reloptions::text like '%security_invoker=true%'
            then 'invoker ☢️ 不對' else 'definer ✓' end as 模式
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in ('staff_sessions','staff_roster');
-- 期望：兩列都是 definer ✓

-- 7-5 ☢️ 直接查 staff_sessions 會拿到 0 列，那是【正確的】——
--     檢視表第一行的 public.is_staff() 對所有人生效，包括你在 SQL Editor
--     裡的 postgres 身分（那個身分沒有 auth.uid()，所以不是員工）。
--     要看到東西，得先假裝成一位已開通的教練：
begin;
  select set_config('request.jwt.claims',
         json_build_object('sub', (select auth_user_id from public.employees
                                    where display_name = 'Jerec'),
                           'role','authenticated')::text, true) is not null as 已切換身分;
  set local role authenticated;

  select count(*) as 看得到幾堂課 from public.staff_sessions;
rollback;
-- 期望：不是 0（最近 7 天一定有課）。
--       如果是 0，先確認 employees 裡 Jerec 的 auth_user_id 有填。
