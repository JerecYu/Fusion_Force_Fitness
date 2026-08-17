-- ═══════════════════════════════════════════════════════════════
--  27-desk-account.sql  ·  櫃檯公用平板的帳號
--  2026-08-17
--
--  來源：2026-08-17 Jerec「有時候教練會有課程連續不中斷的狀況，
--        這時會需要其他教練或兼職人員用自己的手機或公用平板協助銷課」
--        → 三個做法裡選了 (B)：平板用一個獨立的帳號。
--
--  ☢️ 為什麼不讓平板共用某一位教練的 LINE？
--     因為系統認的是「哪一個 LINE 帳號」，checked_by 會記成那個人。
--     共用某位教練的帳號 = 帳上出現一個【假的、但看起來可信的】名字。
--     那比「查不到是誰」更糟 —— 之後要「聯絡教練釐清資訊落差」的時候，
--     你會去問一個根本不在場的人。
--
--     用獨立帳號的話，帳上寫的是「櫃檯平板 點的」——
--     查不到「是哪個人」，但至少誠實地告訴你「這筆是在櫃檯做的」。
--     ☢️ 這是一個【刻意接受的取捨】，不是疏漏。
-- ═══════════════════════════════════════════════════════════════

-- ── ① role 多一種：'staff'（櫃檯）──────────────────────────────
--    ☢️ 不是自己發明的名字 —— staff.html 第 167 行的對照表裡
--       本來就寫著 staff:'櫃檯'，只是資料庫的 check 沒放進去。
--       用同一個字，畫面上不用改任何東西。
alter table public.employees drop constraint if exists employees_role_check;
alter table public.employees add constraint employees_role_check
  check (role = any (array['owner','admin','coach','staff']));

-- ── ② ☢️ 櫃檯【不可以】出現在公開的教練名單裡 ──────────────────
--    public_coaches 原本是「所有在職員工」，而它是 anon 讀得到的，
--    私人課頁面的「指定教練」下拉選單就是讀它。
--    不擋的話，客人會在選單裡看到「櫃檯平板」這位教練。
--
--    ☢️ 改檢視表之前先 pg_get_viewdef 看過（2026-08-17 抄下來的原定義）：
--         select id, display_name, role from employees where is_active = true;
--       欄位一個都沒改，只多一個 role 的條件。
--    今天的結果不會變：6 位（5 教練 ＋ Jerec，他本人有排課）。
create or replace view public.public_coaches as
select id, display_name, role
from public.employees
where is_active = true
  and role in ('owner','coach');

-- ── ③ 建帳號 ──────────────────────────────────────────────────
--    auth_user_id 先留空。平板上用它自己的 LINE 開 staff.html，
--    把畫面上的登入代號給 Jerec，再跑第 ④ 段開通。
insert into public.employees (name, display_name, role, is_active)
select '櫃檯公用平板', '櫃檯平板', 'staff', true
where not exists (select 1 from public.employees where display_name = '櫃檯平板');

-- ── ④ 開通用的指令（拿到登入代號之後再跑）─────────────────────
--    update public.employees
--       set auth_user_id = '這裡貼平板畫面上的登入代號'
--     where display_name = '櫃檯平板';

-- ── 驗收 ──────────────────────────────────────────────────────
select display_name, role, is_active,
       case when auth_user_id is null then '☢️ 還沒開通' else '已開通' end as 狀態
from public.employees order by role, display_name;

select count(*) as 公開教練名單人數,
       bool_or(display_name = '櫃檯平板') as ☢️櫃檯有沒有跑進去
from public.public_coaches;
-- 期望：6 位、false
