-- ═══════════════════════════════════════════════════════════
-- 05-seed-employees：建立六位教練
--
-- 專案：FFF 預約系統（fff-platform）
-- 備份：2026-08-08（加上保險絲）
--
-- ⚠️⚠️⚠️  只能執行一次  ⚠️⚠️⚠️
--
-- 這支是「塞資料」的 SQL，重複執行會產生重複資料。
-- 2026-08 曾經誤按第二次，6 位變成 12 位，用 09-fix-dup 清理過。
-- 下面加了保險絲，現在重跑會直接中止，不會再發生。
-- ═══════════════════════════════════════════════════════════


-- ── 保險絲：已有資料就中止 ────────────────────────────────
--
-- 原理：先問「employees 裡面有東西嗎？」
--       有的話就丟出錯誤，整批操作連同下面的 insert 一起取消。
--       Postgres 會把一次送出的敘述當成一個整體，
--       中間任何一步出錯，前面做過的全部退回，不會做半套。
--
-- ⚠️ 但這個保險絲只在「整張分頁一起執行」時有效。
--    如果你用 Run selected 只選下面的 insert，就繞過它了。
--    所以按 Run 之前還是要看一眼按鈕寫什麼。

do $$
begin
  if exists (select 1 from employees) then
    raise exception
      '⛔ employees 已有 % 位員工，這支已經執行過了。要重建請先跑 09-fix-dup 清空。',
      (select count(*) from employees);
  end if;
end $$;


-- ═══════════════════════════════════════════════════════════
-- 以下為原始內容，未改動
-- ═══════════════════════════════════════════════════════════

insert into employees (name, display_name, role) values
  ('簡基城', '簡基城',  'coach'),
  ('于郅弘', 'Jerec',   'owner'),
  ('王韻茹', 'Jessica', 'coach'),
  ('穆孝偉', 'VC',      'coach'),
  ('謝原',   'Peter',   'coach'),
  ('饒誠',   'Johnson', 'coach');

-- 確認寫進去了
select display_name, name, role, is_active from employees order by created_at;
