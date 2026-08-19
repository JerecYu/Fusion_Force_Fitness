-- ============================================================
-- 39 · 團體課每班上限統一為 12
--
-- Jerec 2026-08-19：「GT 每班上限是 12，不會出現 13 人以上。
--                    團體課購買也是 12（10＋2）為一組。」
--
-- 現況（動手前實測）：
--   class_templates　14 筆　全部 capacity = 10
--   class_sessions 　117 筆 capacity = 10（其中 28 筆是未來的）、9 筆 = 12（全部是過去的）
--   兩張表的預設值都還是 10 → 明天 pg_cron 長出來的課又會是 10
--
-- ☢️ 這次改動【不可能弄壞任何預約】：
--    目前所有課堂裡人數最多的一堂是 8 人，沒有任何一堂接近上限。
--    10 → 12 是「放寬」，只會讓 seats_left 變多、is_full 變得更難成立。
-- ============================================================

-- ── ① 預設值 ────────────────────────────────────────────────
-- ☢️ 這一條最重要。不改預設值的話，今天手動改的那些明天就被新長出來的課稀釋掉。
alter table public.class_templates alter column capacity set default 12;
alter table public.class_sessions  alter column capacity set default 12;

-- ── ② 週課表範本：全部改 12 ─────────────────────────────────
update public.class_templates set capacity = 12 where capacity <> 12;

-- ── ③ 課堂：只改【今天以後】的 ──────────────────────────────
-- ☢️ 過去的課不動。那些課當時的上限就是 10，改掉等於竄改紀錄。
--    capacity 不參與任何金額計算（薪資看的是實際出席人數），
--    所以留著舊值不會影響對帳，只會讓歷史是誠實的。
update public.class_sessions
   set capacity = 12
 where capacity < 12
   and session_date >= (now() at time zone 'Asia/Taipei')::date;

-- ── ④ 上限不准超過 12 ───────────────────────────────────────
-- ☢️ class_sessions 未來可能放 PGT（上限 6）或場租 RT（整場 20~25 人），
--    所以只對 GT 設限，不要一刀切死。
alter table public.class_sessions drop constraint if exists class_sessions_capacity_sane;
alter table public.class_sessions add constraint class_sessions_capacity_sane
  check (capacity >= 1 and (product <> 'GT' or capacity <= 12));

-- class_templates 沒有 product 欄位 —— 它就是團體課的週課表，所以直接設 1~12。
alter table public.class_templates drop constraint if exists class_templates_capacity_sane;
alter table public.class_templates add constraint class_templates_capacity_sane
  check (capacity >= 1 and capacity <= 12);

comment on column public.class_sessions.capacity is
  '這堂課最多幾個人。GT 一律 12（10＋2 一組的規則）。☢️ 這是【顯示用】的上限，訂課不會被擋 —— 額滿仍可報名是 Jerec 選的。';

-- ── ⑤ 超額偵測 ──────────────────────────────────────────────
-- 「不會出現 13 人以上」是規則，不是保證。訂課本來就不擋額滿，
-- 教練點名時又能加「另外帶了 N 位」—— 兩邊加起來就可能超過。
-- 系統不擋，但要看得到。
--
-- ☢️ definer，不要加 security_invoker（牆是 is_staff()，見 db/25）
create or replace view public.staff_overbooked as
select s.id                                   as session_id,
       s.session_date,
       s.start_time,
       s.title,
       e.display_name                         as coach_name,
       s.capacity,
       sum(b.attendee_count)::int             as people,
       count(b.id)::int                       as booking_rows,
       (sum(b.attendee_count) - s.capacity)::int as over_by
from public.class_sessions s
join public.bookings b
  on b.session_id = s.id and b.status in ('booked','attended')
left join public.employees e on e.id = s.coach_id
where public.is_staff()
group by s.id, s.session_date, s.start_time, s.title, e.display_name, s.capacity
having sum(b.attendee_count) > s.capacity
order by s.session_date desc, s.start_time desc;

comment on view public.staff_overbooked is
  '實際人數超過上限的課堂 —— 資料異常，不是正常狀況。正常時這張表是空的。';

grant select on public.staff_overbooked to authenticated;
