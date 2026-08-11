-- ═══════════════════════════════════════════════════════════
-- 14-view-fixes：兩張檢視表算錯了
--
-- 專案：FFF 預約系統（fff-platform）
-- 2026-08-11 · 第 34 步途中發現
--
-- ✅ 可重複執行（drop view + create view）
-- ═══════════════════════════════════════════════════════════
--
-- ① public_schedule 的人數算成「佔位的人」而不是「報名的人」
--
--    原本寫 count(*) where bk.cancelled_at is null。
--    但搬遷進來的 62 筆預約，cancelled_at 全部是 null ——
--    包括 5 筆狀態是 cancelled 的，和 44 筆已經上完課（attended）的。
--    結果：取消的人還佔著位置，上完課的也算在裡面。
--
--    改用 status，那才是權威欄位（daily_class_job 也是看它）：
--      status in ('booked','attended')
--    未來的課：沒有人是 attended，等於 booked 人數 ✅
--    過去的課：報名沒點名的 ＋ 有出席的 = 實際在場人數 ✅
--    取消的、缺席的：都不算 ✅
--
--    影響到的 18 堂全是過去的課（前端只顯示今天以後），
--    所以沒有客人看過錯的數字 —— 但規則錯了就是錯了。
--
-- ② my_bookings 顯示教練的本名
--
--    課表用 e.display_name（「VC」），我的預約用 e.name（「穆孝偉」）。
--    同一個人兩個名字，客人會以為是兩位教練。
--    而且本名是員工個資，客人不需要知道。
-- ═══════════════════════════════════════════════════════════

do $$
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='employees'
                   and column_name='display_name') then
    raise exception '⛔ employees 沒有 display_name 欄位，先確認 schema';
  end if;
end $$;


-- ── ① 公開課表 ────────────────────────────────────────────
drop view if exists public.public_schedule;
create view public.public_schedule as
select session_id, session_date, start_time, duration_min, title, level, coach_name,
       capacity, booked_count,
       greatest(capacity - booked_count, 0) as seats_left,
       booked_count >= capacity             as is_full,
       status
from (
  select s.id as session_id, s.session_date, s.start_time, s.duration_min,
         s.title, s.level,
         e.display_name as coach_name,
         s.capacity,
         (select count(*) from public.bookings bk
           where bk.session_id = s.id
             and bk.status in ('booked','attended'))::integer as booked_count,
         s.status
  from public.class_sessions s
  left join public.employees e on e.id = s.coach_id
  -- ☢️ 這一行是一道牆，不是一個篩選條件。拿掉的話 PT／PGT 課次會全部外流。
  where s.product = 'GT'
) x;

revoke all on public.public_schedule from public, anon, authenticated;
grant  select on public.public_schedule to anon, authenticated;


-- ── ② 我的預約 ────────────────────────────────────────────
drop view if exists public.my_bookings;
create view public.my_bookings as
select b.id, b.session_id, b.status, b.booked_at, b.cancelled_at,
       s.session_date, s.start_time, s.duration_min, s.title, s.level,
       e.display_name as coach_name,          -- ☢️ 不是 e.name（那是本名）
       (((s.session_date + s.start_time) at time zone 'Asia/Taipei') - now()
          > interval '1 hour') as can_cancel,
       ((s.session_date + s.start_time) at time zone 'Asia/Taipei') as starts_at
from public.bookings b
join public.class_sessions s on s.id = b.session_id
left join public.employees   e on e.id = s.coach_id
where b.customer_id = public.my_customer_id();   -- ☢️ 這一行是牆

revoke all on public.my_bookings from public, anon, authenticated;
grant  select on public.my_bookings to authenticated;


select (select count(*) from public.public_schedule
         where session_date >= (now() at time zone 'Asia/Taipei')::date) as 未來的課,
       (select sum(booked_count) from public.public_schedule
         where session_date >= (now() at time zone 'Asia/Taipei')::date) as 未來總報名人數;
