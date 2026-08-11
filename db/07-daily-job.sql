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
--
-- ═══════════════════════════════════════════════════════════
-- 2026-08-11 修改（第 28 步 · 風險 2 的決定：選 C）
--
-- ② 改成 <= ：漏跑的日子，只要有人報名就補標「成立」。
--    「有人報名」是紀錄不是推測，追溯確認不可能錯。
--
-- ③ 維持 = ，而且外面再包一個開關 v_auto_cancel。
--    「沒人報名」是推測 —— 它只說明系統沒收到報名，
--    不說明現場發生了什麼。追溯取消一堂三天前的課沒有營運意義，
--    只會在歷史裡寫下一個可能是錯的事實。
--
-- ☢️ v_auto_cancel 現在是 false。
--    第 33 步「打開真正的訂課」時，要跟前端的 BOOKING_OPEN
--    一起改成 true —— 那兩個是同一件事的兩半。
--    忘了打開的話：沒人報名的課永遠不會自動取消，
--    教練會白跑空堂，而且不會有任何錯誤訊息。
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

  -- ☢️ 第 33 步開放訂課時，跟前端的 BOOKING_OPEN 一起改成 true
  v_auto_cancel boolean := false;
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
  --    只做「今天」，不追溯；而且要等 v_auto_cancel 打開才做。
  if v_auto_cancel then
    update class_sessions s
    set status = 'cancelled', settled_at = now()
    where s.session_date = v_today
      and s.status = 'pending';

    get diagnostics v_cancelled = row_count;
  end if;

  return format('新增課堂 %s 筆｜成立 %s 堂｜取消 %s 堂｜自動取消：%s',
                v_created, v_confirmed, v_cancelled,
                case when v_auto_cancel then '開啟' else '關閉（第 33 步才打開）' end);
end;
$$;

-- 立刻執行一次，看結果
select daily_class_job();
