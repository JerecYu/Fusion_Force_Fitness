-- ═══════════════════════════════════════════════════════════
-- 13-booking：打開真正的訂課（第 33 步）
--
-- 專案：FFF 預約系統（fff-platform）
-- 2026-08-11
--
-- ⚠️ 這支跑完，訂課功能就「做好了」，但還沒開放 ——
--    因為 app_settings.live 預設是 false。
--    上線那天只要改那一列，第 37 步會用到。
--
-- ✅ 可重複執行
-- ═══════════════════════════════════════════════════════════
--
-- 這支修掉的三個洞（都是實際存在的，不是假想）：
--
-- ① 客人可以把自己的預約改成 status='attended'
--    原本的 UPDATE 政策只寫了 using，沒寫 with check，
--    所以「哪幾列可以改」有管，「可以改成什麼」沒管。
--    後果：客人自己標出席 → 第 39 步扣他的課、第 40 步算教練鐘點費，
--    兩份帳都被灌水，而且看起來完全正常。
--
-- ② 客人可以指定「別人付錢」
--    INSERT 政策只檢查 customer_id 是自己，沒檢查 paid_by_customer_id。
--    後果：我報名、扣你的課卡。
--
-- ③ 客人可以報名已取消的課、過去的課、甚至 PT 課次
--    INSERT 政策完全沒看 session。
--
-- 還有一個設計問題：
--
-- ④ 原本「上線」要同時改前端的 BOOKING_OPEN 和排程裡的 v_auto_cancel。
--    兩個地方、靠人記得、忘了不會報錯。
--    而且前端那個旗標「擋不住任何人」——真正的門是 RLS，
--    前端只是不畫按鈕。所以開關必須在資料庫裡。
--    → app_settings.live 一個開關，RLS、排程、前端三邊都讀它。
-- ═══════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════
-- ① 上線開關
-- ═══════════════════════════════════════════════════

create table if not exists public.app_settings (
  id           smallint primary key default 1,
  live         boolean not null default false,
  updated_at   timestamptz not null default now(),
  constraint 只能有一列 check (id = 1)
);

comment on table public.app_settings is
  '全系統開關。live = 系統是否正式上線（可訂課 ＋ 排程會自動取消沒人的課）。永遠只有一列。';

-- 保險絲：已經有值就不要覆蓋掉（避免重跑時把已上線改回未上線）
insert into public.app_settings (id, live) values (1, false)
on conflict (id) do nothing;

alter table public.app_settings enable row level security;

-- 誰都不能透過 API 改它。上線那天在 Table Editor 或 SQL Editor 改。
drop policy if exists "開關人人可讀" on public.app_settings;
create policy "開關人人可讀" on public.app_settings for select using (true);

grant select on public.app_settings to anon, authenticated;


create or replace function public.is_live()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select live from public.app_settings where id = 1), false);
$$;
comment on function public.is_live() is '系統上線了嗎。給 RLS 政策和排程用。';

revoke all on function public.is_live() from public;
grant execute on function public.is_live() to anon, authenticated, service_role;


-- ═══════════════════════════════════════════════════
-- ② 這堂課現在可以報名嗎
--
-- security definer —— 客人對 class_sessions 沒有讀取權，
-- 而且那張表刻意不開給他們：它的 SELECT 政策是 using(true)，
-- 一旦 grant 下去，客人就看得到所有 PT／PGT 課次。
-- 第 24 步花了整整一節在關那道門，不要從這裡再打開一次。
-- ═══════════════════════════════════════════════════

create or replace function public.can_book_session(p_session uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.class_sessions s
    where s.id = p_session
      and s.product = 'GT'                                          -- ☢️ 只有團體課能自己訂
      and s.status  = 'pending'                                     -- 已成立／已取消的都不能再訂
      and s.session_date >= (now() at time zone 'Asia/Taipei')::date -- 過去的課不能訂
  );
$$;
comment on function public.can_book_session(uuid) is
  '這堂課現在可以自己報名嗎。pending 代表「還沒到結算時間」—— 剛好等於你們原本「前一日午夜前預約」的規矩。';

revoke all on function public.can_book_session(uuid) from public;
grant execute on function public.can_book_session(uuid) to authenticated, service_role;


-- ── 這筆預約現在還能取消嗎 ────────────────────────────────
--
-- ☢️ 這一支是被測試逼出來的。
--    原本我把「課前一小時」直接寫在 RLS 政策的 exists 裡，
--    測試立刻回：permission denied for table class_sessions。
--
--    因為政策裡的子查詢是用「呼叫者」的身分跑的 ——
--    客人對 class_sessions 沒有讀取權，所以那個檢查根本跑不起來。
--    畫面上看到的是「不准取消」，實際上是「檢查條件掛了」。
--    兩者長得一樣，但一個是規則，一個是壞掉。
--
--    正解不是把 class_sessions 開給客人（那會漏 PT 課次），
--    而是包成 definer 函式 —— 跟 is_staff() 同一招。
create or replace function public.can_cancel_booking(p_session uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.class_sessions s
    where s.id = p_session
      and ((s.session_date + s.start_time) at time zone 'Asia/Taipei') - now()
            > interval '1 hour'
  );
$$;
comment on function public.can_cancel_booking(uuid) is
  '這筆預約現在還能取消嗎（課前一小時以上）。包成 definer 是因為客人對 class_sessions 沒有讀取權，而且那張表不能開給他們——會漏 PT 課次。';

revoke all on function public.can_cancel_booking(uuid) from public;
grant execute on function public.can_cancel_booking(uuid) to authenticated, service_role;


-- ═══════════════════════════════════════════════════
-- ③ 重寫 bookings 的客人政策
-- ═══════════════════════════════════════════════════

-- 報名：五個條件缺一不可
drop policy if exists "客人只能幫自己報名" on public.bookings;
create policy "客人只能幫自己報名" on public.bookings
  for insert with check (
        customer_id          = public.my_customer_id()   -- 只能報自己
    and paid_by_customer_id  = public.my_customer_id()   -- ☢️ 不能叫別人付錢
    and status               = 'booked'                  -- ☢️ 不能一開始就寫 attended
    and public.is_live()                                 -- 系統上線了才行
    and public.can_book_session(session_id)              -- 這堂課現在可以訂
  );

-- 取消：能改哪幾列（using）和能改成什麼（with check）要分開寫
drop policy if exists "客人取消需在課前一小時" on public.bookings;
create policy "客人取消需在課前一小時" on public.bookings
  for update
  using (
        customer_id = public.my_customer_id()
    and public.can_cancel_booking(session_id)
  )
  with check (
        customer_id         = public.my_customer_id()
    and paid_by_customer_id = public.my_customer_id()
    -- ☢️ 這一行是整支檔案最重要的一行。
    --    沒有它，客人可以把自己標成 attended，兩份帳一起被灌水。
    and status in ('booked', 'cancelled')
  );


-- ═══════════════════════════════════════════════════
-- ④ 我的預約：definer 檢視表
--
-- ☢️ 這張表的 where 是一道牆，不是一個篩選條件。
--    它用 definer 身分讀 class_sessions（客人自己讀不到），
--    然後只回傳「我自己的」那幾列。
--    改動這個 where 之前，先想清楚會不會讓人看到別人的預約。
-- ═══════════════════════════════════════════════════

drop view if exists public.my_bookings;
create view public.my_bookings as
select
  b.id,
  b.session_id,
  b.status,
  b.booked_at,
  b.cancelled_at,
  s.session_date,
  s.start_time,
  s.duration_min,
  s.title,
  s.level,
  e.name as coach_name,
  -- 課前一小時內就不能取消了。這裡算給前端顯示用，
  -- 但真正擋人的是上面那條 RLS —— 前端只是不畫按鈕。
  -- ☢️ at time zone 'Asia/Taipei' 不能省，理由見上面那條政策的註解。
  (((s.session_date + s.start_time) at time zone 'Asia/Taipei') - now()
     > interval '1 hour') as can_cancel,
  -- 給前端排序和「已經過去了」判斷用
  ((s.session_date + s.start_time) at time zone 'Asia/Taipei') as starts_at
from public.bookings b
join public.class_sessions s on s.id = b.session_id
left join public.employees   e on e.id = s.coach_id
where b.customer_id = public.my_customer_id();   -- ☢️ 這一行是牆

revoke all on public.my_bookings from public, anon, authenticated;
grant select on public.my_bookings to authenticated;


-- ═══════════════════════════════════════════════════
-- ⑤ 我的課卡餘額
--
-- 用 definer 是為了不必把 credit_ledger 開給客人 ——
-- 那張表裡有每一筆購課、贈送、調整的紀錄，
-- 客人只需要知道「還剩幾堂」，不需要碰那張帳本。
-- ═══════════════════════════════════════════════════

drop view if exists public.my_credits;
create view public.my_credits as
select product, sum(delta)::integer as balance
from public.credit_ledger
where customer_id = public.my_customer_id()      -- ☢️ 這一行是牆
group by product;

revoke all on public.my_credits from public, anon, authenticated;
grant select on public.my_credits to authenticated;


-- ═══════════════════════════════════════════════════
-- ⑥ 權限
--    bookings 開給 authenticated，實際能做什麼由上面的政策決定。
--    class_sessions、credit_ledger 一個字都不開 —— 都走 definer 檢視表。
-- ═══════════════════════════════════════════════════

grant select, insert, update on public.bookings to authenticated;


-- ═══════════════════════════════════════════════════
-- ⑦ 排程改讀開關
--    原本是寫死的 v_auto_cancel := false，要人記得改。
--    現在跟訂課共用同一個 app_settings.live。
-- ═══════════════════════════════════════════════════

create or replace function daily_class_job()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_created integer := 0;
  v_confirmed integer := 0;
  v_cancelled integer := 0;
  v_today date := (now() at time zone 'Asia/Taipei')::date;

  -- 2026-08-11：不再寫死。跟訂課共用同一個開關（第 33 步）。
  v_auto_cancel boolean := public.is_live();
begin
  -- ① 產生未來 14 天的課堂
  insert into class_sessions
    (template_id, session_date, start_time, duration_min, title, level, coach_id, capacity)
  select t.id, d.the_date, t.start_time, t.duration_min, t.title, t.level, t.coach_id, t.capacity
  from class_templates t
  cross join generate_series(v_today, v_today + 13, interval '1 day') as d(the_date)
  where t.is_active = true
    and extract(isodow from d.the_date) = t.weekday
  on conflict (template_id, session_date) do nothing;

  get diagnostics v_created = row_count;

  -- ② 結算：有人報名的成立
  --    <= 不是 = ：排程漏跑的日子，下次執行時一起補。
  --    只補「有人報名」的 —— 那是紀錄，補了不會錯。
  update class_sessions s
  set status = 'confirmed', settled_at = now()
  where s.session_date <= v_today
    and s.status = 'pending'
    and exists (
      select 1 from bookings b
      where b.session_id = s.id and b.status = 'booked'
    );

  get diagnostics v_confirmed = row_count;

  -- ③ 結算今天：沒人報名的取消
  --    只做「今天」，不追溯；而且要等系統上線才做。
  --    ☢️ 沒上線就開這一段的話，會把每一堂課都取消掉 ——
  --       因為報名還在舊系統裡，新系統當然是空的。
  if v_auto_cancel then
    update class_sessions s
    set status = 'cancelled', settled_at = now()
    where s.session_date = v_today
      and s.status = 'pending';

    get diagnostics v_cancelled = row_count;
  end if;

  return format('新增課堂 %s 筆｜成立 %s 堂｜取消 %s 堂｜系統上線：%s',
                v_created, v_confirmed, v_cancelled,
                case when v_auto_cancel then '是' else '否（訂課也還沒開）' end);
end;
$$;


-- ═══════════════════════════════════════════════════
-- 驗收
-- ═══════════════════════════════════════════════════
select
  public.is_live()                                                       as 系統上線了嗎,
  (select count(*) from public.app_settings)                             as 開關列數,
  (select string_agg(policyname, '、' order by policyname)
     from pg_policies where schemaname='public' and tablename='bookings') as bookings政策,
  (select string_agg(table_name||':'||privilege_type, '、'
                     order by table_name, privilege_type)
     from information_schema.role_table_grants
    where table_schema='public' and grantee='authenticated'
      and privilege_type in ('SELECT','INSERT','UPDATE','DELETE'))        as authenticated開了什麼;
