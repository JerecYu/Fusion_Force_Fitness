-- ═══════════════════════════════════════════════════════════
-- 06-seed-class-templates：週課表範本 14 堂
--
-- 專案：FFF 預約系統（fff-platform）
-- 備份：2026-08-07（難度調整後的版本）
--
-- ⚠️⚠️⚠️  只能執行一次  ⚠️⚠️⚠️
--
-- 這支是「塞資料」的 SQL，重複執行會產生重複資料。
-- 2026-08 曾經誤按第二次，14 筆變成 28 筆，用 09-fix-dup 清理過。
-- 下面加了保險絲，現在重跑會直接中止，不會再發生。
-- ═══════════════════════════════════════════════════════════


-- ── 保險絲：已有資料就中止 ────────────────────────────────
--
-- 原理：先問「class_templates 裡面有東西嗎？」
--       有的話就丟出錯誤，整批操作連同下面的 insert 一起取消。
--       Postgres 會把一次送出的敘述當成一個整體，
--       中間任何一步出錯，前面做過的全部退回，不會做半套。
--
-- ⚠️ 但這個保險絲只在「整張分頁一起執行」時有效。
--    如果你用 Run selected 只選下面的 insert，就繞過它了。
--    所以按 Run 之前還是要看一眼按鈕寫什麼。

do $$
begin
  if exists (select 1 from class_templates) then
    raise exception
      '⛔ class_templates 已有 % 筆資料，這支已經執行過了。要重建請先跑 09-fix-dup 清空。',
      (select count(*) from class_templates);
  end if;
end $$;


-- ═══════════════════════════════════════════════════════════
-- 以下為原始內容，未改動
-- ═══════════════════════════════════════════════════════════

-- 週課表範本 14 堂
-- weekday: 1=週一 … 7=週日

insert into class_templates (weekday, start_time, duration_min, title, level, coach_id)
select v.weekday, v.start_time::time, 60, v.title, v.level, e.id
from (values
  (1, '09:00', 'TRX綜合雕塑',   'adv', 'Peter'),
  (1, '12:30', '功能性核心',     'beg', 'Johnson'),
  (1, '19:30', '循環有氧',       'int', 'Johnson'),
  (2, '09:00', '功能性核心',     'beg', 'Peter'),
  (2, '12:30', '基礎運動養成',   'beg', 'Jerec'),
  (2, '18:30', '交叉肌力訓練',   'adv', 'VC'),
  (3, '12:20', '間歇有氧',       'adv', 'VC'),
  (4, '10:00', '交叉肌力訓練',   'int', 'Johnson'),
  (4, '19:00', '基礎運動養成',   'beg', 'Johnson'),
  (5, '12:20', '交叉肌力訓練',   'int', 'VC'),
  (5, '19:00', '交叉肌力訓練',   'int', 'Jessica'),
  (6, '11:00', '功能性核心',     'beg', 'Johnson'),
  (6, '16:00', '交叉肌力訓練',   'adv', 'VC'),
  (7, '11:00', '循環有氧',       'int', 'VC')
) as v(weekday, start_time, title, level, coach)
join employees e on e.display_name = v.coach;

-- 確認：應該是 14 筆
select
  case weekday when 1 then '一' when 2 then '二' when 3 then '三'
       when 4 then '四' when 5 then '五' when 6 then '六' else '日' end as 星期,
  start_time as 時間, title as 課程, level as 難度, e.display_name as 教練
from class_templates t
join employees e on e.id = t.coach_id
order by weekday, start_time;
