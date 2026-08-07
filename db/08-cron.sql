-- ═══════════════════════════════════════════════════════════
-- 08-cron：讓 daily_class_job() 每天自動執行
--
-- 專案：FFF 預約系統（fff-platform）
-- 建立：2026-08-07
--
-- ✅ 這張分頁可以重複執行
--    cron.schedule 是用「排程名稱」認人的，
--    同名重跑會「覆蓋」原本那筆，不會像 05／06 長出第二份。
--
-- 前提：pg_cron 已安裝
--    新版路徑：Supabase 後台 → Integrations → Cron → Install integration
--    舊版路徑：Database → Extensions → 搜尋 pg_cron → 開啟
--    （文件裡寫的是舊路徑，2026-08 的介面已搬到 Integrations）
-- ═══════════════════════════════════════════════════════════


-- ── 步驟 1：先確認函式真的存在（純查詢，安全）────────────────
--
-- 為什麼要先查：排程失敗的時候是「安靜的」。
-- 如果函式名字打錯，排程照樣建得起來、active 照樣是 true，
-- 但每天半夜跑的時候會撞牆，而且沒有任何人會通知你。
-- 你可能兩週後才發現課表沒長。三十秒的檢查，換掉這個風險。
--
-- 應該回傳 1 筆：public ｜ daily_class_job ｜（無參數）

select
  n.nspname as 所在位置,
  p.proname as 函式名稱,
  coalesce(
    nullif(pg_get_function_identity_arguments(p.oid), ''),
    '（無參數）'
  ) as 需要的參數
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where p.proname = 'daily_class_job';


-- ── 步驟 2：註冊排程 ───────────────────────────────────────
--
-- 時間：台灣 00:00 ＝ UTC 16:00（前一天）
--   資料庫排程用 UTC 計時，台灣快 8 小時。
--   寫 '0 0 * * *' 的話實際會在台灣早上 8 點才跑，那時早課已經開始。
--
-- 為什麼寫 public.：
--   排程是半夜由背景程序執行的，那個環境預設會找哪些 schema
--   不一定跟 SQL Editor 一樣。寫上 public. 等於直接給門牌號碼，不靠猜。

select cron.schedule(
  'daily-class-job',
  '0 16 * * *',
  $$ select public.daily_class_job(); $$
);


-- ── 步驟 3：確認排程進去了（純查詢，安全）──────────────────
--
-- 應該看到：
--   1 ｜ daily-class-job ｜ 0 16 * * * ｜ true ｜ select public.daily_class_job();
--
-- active = true 是關鍵那一欄 —— 排程可以存在但被停用，那樣一樣不會跑。

select jobid, jobname, schedule, active, command
from cron.job;


-- ── 步驟 4：驗證時區換算（純查詢，安全）────────────────────
--
-- 不要相信算術，讓資料庫自己回答。
-- 第三欄應該是「明天 00:00:00」，那就是證據。

select
  (now() at time zone 'Asia/Taipei')::timestamp(0)  as 台灣現在時間,
  (now() at time zone 'UTC')::timestamp(0)          as 資料庫UTC時間,
  ((current_date + time '16:00')
     at time zone 'UTC'
     at time zone 'Asia/Taipei')::timestamp(0)      as 今天UTC16點在台灣是;


-- ── 步驟 5：查排程執行紀錄（純查詢，安全）──────────────────
--
-- 排程跑過沒？成功還是失敗？這是之後排查問題的第一站。
--   status = succeeded  → 成功
--   status = failed     → return_message 會說原因
--   0 筆                → 還沒到執行時間

-- ⚠️ 注意：cron.job_run_details 裡「沒有」jobname 欄位，
--    排程名稱只存在 cron.job，執行紀錄表只記 jobid。
--    所以要 join 兩張表才能用名稱篩選。

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

-- 如果上面又出錯，用這個保證能跑的版本先看欄位有哪些：
-- select * from cron.job_run_details order by start_time desc limit 5;


-- ═══════════════════════════════════════════════════════════
-- 需要撤銷排程時（平常不要跑，故意註解起來）
-- ═══════════════════════════════════════════════════════════
--
-- select cron.unschedule('daily-class-job');
--
-- 撤銷後排程立刻停止，資料不受影響。
-- 要恢復的話重跑步驟 2 即可。
--
-- ⚠️ 絕對不要下 drop extension pg_cron;
--    那會把所有排程連同設定一起永久刪除，救不回來。
