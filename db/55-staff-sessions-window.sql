-- 55｜停課要能提前排 —— 把課表看得到的範圍放寬
--
-- 第 81 步做了「停課／請假　通知這堂課的人」，但實測時才發現一件事：
-- 教練後台的課次清單來自 staff_sessions，而它的範圍寫死在
--
--     今天 − 7  到  今天 + 1
--
-- 也就是【只看得到明天為止】。臨時請假沒問題，但
-- 「下週三我要出國，先把那堂課停掉」做不到 —— 那堂課根本不在畫面上。
--
-- ☢️ 這是第 81 步自己的限制，不是別的功能的問題。
--    功能做完之後真的拿去用，才會撞到這種事。
--
-- 改成 今天 − 7 到 今天 + 14。目前課表最遠排到 2026-09-02，14 天全涵蓋。
--
-- ☢️ 用 create or replace，不要 drop + create。
--    這支檢視表的欄位一個都沒變（只動 where），replace 會保留 GRANT；
--    drop 會把 GRANT 一起帶走，然後所有教練當場看不到任何課
--    ——【而且錯誤訊息是「查無資料」，不是「沒有權限」】（第 37 步踩過）。

begin;

create or replace view public.staff_sessions as
select s.id                                                        as session_id,
       s.session_date,
       s.start_time,
       s.title,
       s.level,
       s.status                                                    as session_status,
       s.coach_id,
       e.display_name                                              as coach_name,
       ((s.session_date + s.start_time) at time zone 'Asia/Taipei') as starts_at,
       count(b.id) filter (where b.status <> 'cancelled')           as n_expected,
       count(b.id) filter (where b.status = 'attended')             as n_present,
       count(b.id) filter (where b.status = 'absent')               as n_absent,
       count(b.id) filter (where b.status = 'booked')               as n_pending
from public.class_sessions s
left join public.employees e on e.id = s.coach_id
left join public.bookings  b on b.session_id = s.id
where public.is_staff()
  and s.product = 'GT'
  and s.session_date >= ((now() at time zone 'Asia/Taipei')::date - 7)
  and s.session_date <= ((now() at time zone 'Asia/Taipei')::date + 14)
group by s.id, e.display_name;

commit;

-- ── 驗收 ────────────────────────────────────────────────────
-- ① 範圍真的變寬了（今天 8/20 的話：18 → 42）
--
-- select count(*) from public.class_sessions
--  where product='GT'
--    and session_date between (now() at time zone 'Asia/Taipei')::date - 7
--                         and (now() at time zone 'Asia/Taipei')::date + 14;
--
-- ② ☢️ GRANT 還在（replace 應該保留，但這一項一定要親眼確認）
--
-- select grantee, privilege_type from information_schema.role_table_grants
--  where table_schema='public' and table_name='staff_sessions';
--   → authenticated / SELECT
--
-- ③ ☢️ 還是 definer（reloptions 是空的就對了）
--
-- select reloptions from pg_class where oid='public.staff_sessions'::regclass;
--   → null
