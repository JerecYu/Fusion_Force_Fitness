-- ═══════════════════════════════════════════════════════════
-- 15-pt-requests：私人課「送出需求」（第 34 步）
--
-- 專案：FFF 預約系統（fff-platform）
-- 2026-08-11
--
-- ☢️ 私人課不是預約，是需求。
--    這一步不碰 class_sessions、不碰名額、不碰課卡。
--    它只讓客人寫進 pt_requests，教練聯繫後才敲定。
--
-- pt_requests 這張表和它的四條政策在第一幕就建好了，
-- 這支只補兩件事：一個公開的教練名單，和 authenticated 的權限。
--
-- ✅ 可重複執行
-- ═══════════════════════════════════════════════════════════

-- ── 公開教練名單 ──────────────────────────────────────────
--
-- 前端要把「VC」這個對外名字換成資料庫的 uuid。
-- ☢️ 不可以把 uuid 寫死在前端 —— 換教練或重建資料庫就對不上，
--    而且不會報錯，只會默默存成「未指定」。
--
-- 只給 id、對外顯示名、職稱。
-- 本名、電話、Email 一個字都不給 —— 那些留在 employees，客人碰不到。
drop view if exists public.public_coaches;
create view public.public_coaches as
select id, display_name, role
from public.employees
where is_active = true;

revoke all on public.public_coaches from public, anon, authenticated;
grant  select on public.public_coaches to anon, authenticated;


-- ── 需求單權限 ────────────────────────────────────────────
--
-- 政策早就寫好了（客人只能新增和讀自己的、員工可讀全部可處理），
-- 缺的只是表層權限 —— 這就是附錄六之一那個洞的延續。
grant select, insert on public.pt_requests to authenticated;


select (select count(*) from public.public_coaches) as 公開教練數,
       (select string_agg(display_name, '、' order by display_name)
          from public.public_coaches)               as 名單,
       (select count(*) from public.pt_requests)    as 目前需求單數;
