-- 56｜職級與加給的護欄
--
-- 第 78 步建了 coach_grades 和 coach_allowances 兩張表，值只能用 SQL 塞。
-- 第 84 步要做設定介面 —— 一旦有畫面能寫，就會有寫壞的可能。
-- 動畫面之前先把護欄補上。
--
-- ☢️ 最嚴重的一種寫壞：同一個人、同一項加給，時間區間【重疊】。
--    例如 VC 的店長加給有兩列：08/01 起（沒有結束日）和 09/01 起。
--    payroll_lines 會把兩列都算進去 —— 九月<b>發兩份店長加給</b>。
--    而且對帳看不出來：金額是「合理的兩倍」，不是一個明顯的錯數字。
--    ☢️ 這種錯不能靠前端擋。前端只是不要讓人白按，真正的牆要在這裡。

begin;

-- 判斷區間重疊需要 gist 索引同時處理 uuid／text 的相等比較
create extension if not exists btree_gist;

alter table public.coach_allowances
  drop constraint if exists coach_allowances_no_overlap;

alter table public.coach_allowances
  add constraint coach_allowances_no_overlap
  exclude using gist (
    employee_id with =,
    item        with =,
    daterange(from_date, coalesce(to_date, 'infinity'::date), '[]') with &&
  );

comment on constraint coach_allowances_no_overlap on public.coach_allowances is
  '同一個人的同一項加給不可以有時間重疊的兩列 —— 重疊會在月結時發兩份。';

-- ☢️ 職級不需要這一條：coach_grades 存的是「從哪一天起」的時間點，
--    不是區間。原有的 unique(employee_id, effective_from) 已經夠了。
--    「後面那一列蓋掉前面那一列」是 coach_grade_on() 的查法決定的，
--    不是資料結構的問題。

commit;

-- ── 驗收 ────────────────────────────────────────────────────
-- 故意塞一列重疊的，應該要被擋下來（跑完記得 rollback）：
--
-- begin;
-- insert into public.coach_allowances (employee_id, item, monthly_amount, from_date)
-- select employee_id, item, 999, from_date + 1 from public.coach_allowances limit 1;
--   → ERROR: conflicting key value violates exclusion constraint
-- rollback;
