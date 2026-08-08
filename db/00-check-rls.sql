-- ═══════════════════════════════════════════════════════════
-- 00-check ｜ 常駐檢查工具　全部純查詢，不會動到任何資料
-- 用法：反白其中一段 → 按 Run selected
-- ⚠️ 全部都要用 postgres 身分跑，切成 anon 會全變 0
-- ═══════════════════════════════════════════════════════════


-- ①  每次登入先跑這個　應該看到 6 ｜ 14 ｜（浮動）｜ 0 ──────────
--     最後那個 0 是重點：抓「同一個教練名字出現兩次」
select
  (select count(*) from employees)       as 教練,
  (select count(*) from class_templates) as 範本,
  (select count(*) from class_sessions)  as 課堂,
  (select count(*) from (
     select display_name
     from employees
     group by display_name
     having count(*) > 1
   ) x) as 重複的教練;


-- ②  看公開課表：客人會看到的，跟這裡一模一樣 ──────────────────
select *
from public.public_schedule
where session_date >= current_date
order by session_date, start_time
limit 20;


-- ③  場記有沒有上工　status 要是 succeeded ────────────────────
--     ⚠️ return_message 顯示的是資料庫的執行標記（如 1 row），
--        不是函式回傳的中文訊息。想知道實際做了什麼要查 class_sessions
select
  d.runid,
  (d.start_time at time zone 'Asia/Taipei')::timestamp(0) as 台灣時間,
  d.status,
  d.return_message
from cron.job_run_details d
join cron.job j on j.jobid = d.jobid
where j.jobname = 'daily-class-job'
order by d.start_time desc
limit 5;


-- ④  課堂結算狀況總覽 ────────────────────────────────────────
--     有客人之前會看到一堆 cancelled，那是風險 3，正常的
select
  status   as 狀態,
  count(*) as 幾堂
from class_sessions
group by status
order by count(*) desc;


-- ⑤  稽核：所有「資料表」都上鎖了嗎　每建一張表就跑一次 ─────────
--     ⚠️ 這支只看得到一般資料表（relkind='r'），
--        檢視表如 public_schedule 不會出現在這裡，那是正常的，改用 ⑥ 稽核
select
  c.relname                          as 資料表,
  case when c.relrowsecurity
       then '✅ 已上鎖' else '❌ 未上鎖' end as RLS,
  count(p.polname)                   as 規則數
from pg_class c
left join pg_policy p on p.polrelid = c.oid
where c.relnamespace = 'public'::regnamespace
  and c.relkind = 'r'
group by c.relname, c.relrowsecurity
order by c.relname;


-- ⑥  稽核：那扇窗有沒有多開欄位　每次改 public_schedule 後都跑 ──
--     目前應該剛好 12 欄，不可以出現 phone / email / name /
--     auth_user_id / coach_id / customer_id 任何一個
select
  ordinal_position as 順序,
  column_name      as 欄位,
  data_type        as 型別
from information_schema.columns
where table_schema = 'public'
  and table_name   = 'public_schedule'
order by ordinal_position;


-- ═══════════════════════════════════════════════════════════
-- 以下是臨時鷹架區　用完就刪　不要讓它長住
-- ═══════════════════════════════════════════════════════════
