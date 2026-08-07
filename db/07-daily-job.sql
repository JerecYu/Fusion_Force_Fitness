-- ═══════════════════════════════════════════════════════════
-- 07-daily-job：每日排程函式
--
-- 專案：FFF 預約系統（fff-platform）
-- 備份：2026-08-07
--
-- ✅ 可重複執行
--    create or replace 會覆蓋舊版本，不會產生第二個函式。
--    ① 有 on conflict do nothing 防護。
--    ②③ 只處理 status = 'pending' 的課堂，已結算過的不會重複動到。
--
-- 由 08-cron.sql 註冊的排程 daily-class-job 每天台灣 00:00 呼叫。
--
-- ⚠️ 注意：檔案最後一行 select daily_class_job(); 會「立刻執行一次」。
--    這是安全的（本身可重複執行），但你會看到資料變動，那是正常的。
-- ═══════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════
-- 每日排程：產生未來課堂 + 結算今日課程
-- 可重複執行，不會產生重複資料
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

  -- ② 結算今天：有人報名的成立
  update class_sessions s
  set status = 'confirmed', settled_at = now()
  where s.session_date = v_today
    and s.status = 'pending'
    and exists (
      select 1 from bookings b
      where b.session_id = s.id and b.status = 'booked'
    );

  get diagnostics v_confirmed = row_count;

  -- ③ 結算今天：沒人報名的取消
  update class_sessions s
  set status = 'cancelled', settled_at = now()
  where s.session_date = v_today
    and s.status = 'pending';

  get diagnostics v_cancelled = row_count;

  return format('新增課堂 %s 筆｜今日成立 %s 堂｜今日取消 %s 堂',
                v_created, v_confirmed, v_cancelled);
end;
$$;

-- 立刻執行一次，看結果
select daily_class_job();
