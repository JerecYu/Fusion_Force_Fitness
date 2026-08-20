-- 54｜客人不能改自己的客戶資料
--
-- ☢️☢️ 架 push_user_id 那座橋的時候發現的：
--    `authenticated` 對 `customers` 有【全欄位 UPDATE】權限，
--    而 RLS 有一條「客人只能改自己」的 UPDATE policy。
--    兩個加起來 ＝ 任何一位登入的客人都可以改寫自己那一列的每一個欄位。
--
--    能改的包括：
--      · phone         → 改成別人的號碼
--      · name          → 櫃檯就搜不到他了
--      · is_active     → 把自己藏起來
--      · auth_user_id  → ☢️ 這一欄是 RLS 認人的那一欄。
--                          改成別人的 uid 等於把自己這筆客戶資料交出去，
--                          或讓兩筆資料同時宣稱同一個登入身分。
--      · push_user_id  → 停課通知送到別人的 LINE
--
-- ☢️ 這個洞不是今天做出來的 —— 它從一開始就在，只是今天要拿 push_user_id
--    來決定「通知送給誰」，才第一次去看那一欄誰改得動。
--    <加一個新欄位之前，先看看那張表現在誰寫得進去。>
--
-- 檢查過整個前端：一行都沒有寫 customers。
--   · GT-booking.html / pt-request.js / checkin.html → 全部只有 select
--   · 建客人走 create_customer()（definer）
--   · 綁定走 line-bind Edge Function（service role）
--   · push_user_id 走 line-hook Edge Function（service role）
-- definer 函式與 service role 都不看 authenticated 的權限，所以收掉不影響任何功能。

begin;

revoke update on public.customers from authenticated;
drop policy if exists "客人只能改自己" on public.customers;

commit;

-- ── 驗收 ────────────────────────────────────────────────────
-- ① authenticated 對 customers 應該只剩 SELECT
--
-- select privilege_type, count(*) as 欄位數
-- from information_schema.column_privileges
-- where table_schema='public' and table_name='customers' and grantee='authenticated'
--   and privilege_type in ('SELECT','UPDATE','INSERT','DELETE')
-- group by 1;
--   → 只會有 SELECT 一列
--
-- ② customers 上應該只剩兩條 SELECT policy
--
-- select polname from pg_policy p join pg_class c on c.oid=p.polrelid
--  where c.relname='customers';
--   → 員工可讀全部客人 / 客人只能讀自己
