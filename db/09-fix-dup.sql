-- ═══════════════════════════════════════════════════════════
-- 09-fix-dup：清除重複資料，從乾淨狀態重建
--
-- 專案：FFF 預約系統（fff-platform）
-- 備份：2026-08-07
--
-- ☢️☢️☢️  這是整個 db/ 裡最危險的一支  ☢️☢️☢️
--
-- 它會 delete from 三張資料表，而且沒有 where 條件。
-- 執行 = 全部清空重來。沒有確認視窗，沒有回收桶。
--
-- 存在理由：2026-08 時 05／06 被誤按第二次，資料變成 12／28／56，
--           用這支清空重建回 6／14／28。它是救火工具，不是日常工具。
--
-- ⚠️ 最大的隱藏風險：
--    這支是在「系統還沒有客人」的時候寫的。
--    等 customers 和 bookings 有真實資料之後，
--    delete from class_sessions 會連帶影響客人的預約紀錄
--    （視外鍵設定，可能被連鎖刪除，也可能直接報錯）。
--    那時候這支就不能再用了，必須改寫成「只刪重複的那一份」。
--
--    下面的保險絲就是在防這件事。
-- ═══════════════════════════════════════════════════════════


-- ── 保險絲：有客人或預約資料就拒絕執行 ──────────────────────
--
-- 現在 customers 和 bookings 都是空的，所以這支還能安全使用。
-- 哪天你匯入客人名單、或前端開始有人預約之後，
-- 這道關卡會擋下來，逼你停下來想清楚，而不是直接刪光。

do $$
begin
  if exists (select 1 from bookings) then
    raise exception
      '⛔ bookings 已有 % 筆預約紀錄。這支會把課堂連同預約一起清掉，已中止。',
      (select count(*) from bookings);
  end if;

  if exists (select 1 from customers) then
    raise exception
      '⛔ customers 已有 % 位客人。系統已經上線，不能再用「全部清空重建」的方式修資料，已中止。',
      (select count(*) from customers);
  end if;
end $$;


-- ── 執行前的數字（純查詢）─────────────────────────────────

select
  (select count(*) from employees)       as 教練,
  (select count(*) from class_templates) as 課表範本,
  (select count(*) from class_sessions)  as 已產生課堂;


-- ═══════════════════════════════════════════════════════════
-- 以下為原始內容，未改動
-- ═══════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════
-- 清除重複資料，從乾淨狀態重建
-- ═══════════════════════════════════════════════════

-- 依相依順序清空：課堂 → 範本 → 教練
delete from class_sessions;
delete from class_templates;
delete from employees;

-- 重建六位教練
insert into employees (name, display_name, role) values
  ('簡基城', '簡基城',  'coach'),
  ('于郅弘', 'Jerec',   'owner'),
  ('王韻茹', 'Jessica', 'coach'),
  ('穆孝偉', 'VC',      'coach'),
  ('謝原',   'Peter',   'coach'),
  ('饒誠',   'Johnson', 'coach');

-- 重建 14 堂課表範本
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

-- 重新產生課堂
select daily_class_job();

-- 確認
select
  (select count(*) from employees)       as 教練,
  (select count(*) from class_templates) as 課表範本,
  (select count(*) from class_sessions)  as 已產生課堂;
