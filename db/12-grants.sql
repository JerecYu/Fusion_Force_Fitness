-- ═══════════════════════════════════════════════════════════
-- 12-grants：修好「誰進得了這些表」
--
-- 專案：FFF 預約系統（fff-platform）
-- 2026-08-11 · 第 32 步途中發現
--
-- ☢️ 發現的問題
--    整個 public schema，除了 public_schedule 這個檢視表以外，
--    anon／authenticated／service_role 三個角色對每一張表都是
--    「連碰都不能碰」—— 連 SELECT 都沒有。
--
--    這件事之所以到今天才爆，是因為在此之前所有寫入都是
--    你在 SQL 編輯器裡用 postgres 身分跑的，而 daily_class_job()
--    是 security definer（等於用 postgres 跑）。第一個用
--    service_role 去寫表的東西就是 line-bind，它立刻撞牆。
--
-- ⚠️ 更陰險的是 line-auth：它查 customers 但沒檢查錯誤，
--    所以查詢失敗時它安靜地回「這個人沒綁定過」。
--    也就是說在修好之前，就算綁定成功，第二次打開還是會說沒綁。
--    不會報錯，只會給錯答案。（那支的程式碼一起修了。）
--
-- ── 兩件事分開想（規則 12：先問「這個身分本來就該進得去嗎」）──
--
-- ① GRANT 決定「這個角色碰不碰得到這張表」
-- ② RLS   決定「碰得到之後看得到哪幾列」
--
--    沒有 ①，RLS 寫得再好都是裝飾 —— 因為根本沒人走到那一關。
--    這也是為什麼之前看起來「很安全」：它安全在沒有人進得來，
--    包括該進來的人。
--
-- ── 這支做什麼 ──────────────────────────────────────────────
--   ⓐ 三個 security definer 小工具，讓政策不必直接讀 employees
--   ⓑ 把 10 條引用 employees 的政策改成呼叫小工具
--   ⓒ service_role 給滿（它就是伺服器端的管理身分）
--   ⓓ authenticated 只開 customers 和 signup_requests，其餘等第 33 步
--
-- ✅ 可重複執行
-- ═══════════════════════════════════════════════════════════


-- ── 保險絲 ────────────────────────────────────────────────
--    要開給 authenticated 的表，RLS 一定要是開著的。
--    對一張沒有 RLS 的表 grant select，等於把它公開。
do $$
declare
  v_bad text;
begin
  select string_agg(c.relname, '、')
    into v_bad
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname in ('customers', 'signup_requests')
    and c.relrowsecurity = false;

  if v_bad is not null then
    raise exception
      '⛔ 這些表沒有開 RLS，不可以 grant 給 authenticated：%。先開 RLS 再跑這支。', v_bad;
  end if;
end $$;


-- ═══════════════════════════════════════════════════
-- ⓐ 三個小工具
--
-- 它們是 security definer —— 用函式擁有者（postgres）的身分執行，
-- 所以呼叫的人不需要對 employees／customers 有任何權限。
--
-- 為什麼要這樣做：
--   政策裡的 EXISTS (SELECT ... FROM employees ...) 是用「呼叫者」
--   的權限跑的。客人對 employees 沒有權限，於是他查 customers 時
--   會撞到 permission denied —— 錯在 employees，訊息卻出現在 customers。
--   把它包成 definer 函式，這個牽連就斷掉了。
--
-- ☢️ security definer 的函式一定要 set search_path，
--    否則有人改了 search_path 就能讓它去讀別的 schema 的假表。
-- ═══════════════════════════════════════════════════

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.employees
    where auth_user_id = auth.uid() and is_active = true
  );
$$;
comment on function public.is_staff() is
  '目前登入的人是不是在職員工。給 RLS 政策用，避免政策直接讀 employees。';

create or replace function public.my_employee_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.employees
  where auth_user_id = auth.uid() and is_active = true
  limit 1;
$$;

create or replace function public.my_customer_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.customers
  where auth_user_id = auth.uid()
  limit 1;
$$;

revoke all on function public.is_staff()        from public;
revoke all on function public.my_employee_id()  from public;
revoke all on function public.my_customer_id()  from public;
grant execute on function public.is_staff()       to authenticated, service_role;
grant execute on function public.my_employee_id() to authenticated, service_role;
grant execute on function public.my_customer_id() to authenticated, service_role;


-- ═══════════════════════════════════════════════════
-- ⓑ 把 10 條政策改成呼叫小工具
--    意思完全沒變，只是不再要求呼叫者對 employees 有權限。
-- ═══════════════════════════════════════════════════

-- customers
drop policy if exists "員工可讀全部客人" on public.customers;
create policy "員工可讀全部客人" on public.customers
  for select using (public.is_staff());

-- credit_ledger
drop policy if exists "員工可讀全部堂數" on public.credit_ledger;
create policy "員工可讀全部堂數" on public.credit_ledger
  for select using (public.is_staff());

drop policy if exists "員工可新增堂數異動" on public.credit_ledger;
create policy "員工可新增堂數異動" on public.credit_ledger
  for insert with check (public.is_staff());

-- bookings
drop policy if exists "員工可讀全部預約" on public.bookings;
create policy "員工可讀全部預約" on public.bookings
  for select using (public.is_staff());

drop policy if exists "員工可代開預約" on public.bookings;
create policy "員工可代開預約" on public.bookings
  for insert with check (public.is_staff());

drop policy if exists "員工可點名" on public.bookings;
create policy "員工可點名" on public.bookings
  for update using (public.is_staff());

-- pt_requests
drop policy if exists "員工可讀全部需求單" on public.pt_requests;
create policy "員工可讀全部需求單" on public.pt_requests
  for select using (public.is_staff());

drop policy if exists "員工可處理需求單" on public.pt_requests;
create policy "員工可處理需求單" on public.pt_requests
  for update using (public.is_staff());

-- signup_requests
drop policy if exists "員工可讀留言簿" on public.signup_requests;
create policy "員工可讀留言簿" on public.signup_requests
  for select using (public.is_staff());

-- class_sessions
-- ☢️ 這一條不一樣：它問的不是「你是不是員工」，
--    而是「這堂課的教練是不是你本人」。
--    改成 is_staff() 會讓任何員工都能改任何人的課 —— 不可以。
drop policy if exists "教練可改自己的課" on public.class_sessions;
create policy "教練可改自己的課" on public.class_sessions
  for update using (coach_id = public.my_employee_id());


-- ═══════════════════════════════════════════════════
-- ⓒ service_role：給滿
--
--    它是伺服器端的管理身分，只活在 Edge Function 裡，
--    前端永遠拿不到（HANDOVER 規則 2）。Edge Function 要能
--    做的事，就是它要能做的事。
--
--    alter default privileges 是為了以後新增的表不用再修一次。
-- ═══════════════════════════════════════════════════

grant usage on schema public to service_role;
grant all on all tables    in schema public to service_role;
grant all on all sequences in schema public to service_role;
grant all on all functions in schema public to service_role;

alter default privileges in schema public grant all on tables    to service_role;
alter default privileges in schema public grant all on sequences to service_role;
alter default privileges in schema public grant all on functions to service_role;


-- ═══════════════════════════════════════════════════
-- ⓓ authenticated：只開這一步真的需要的
--
--    customers        客人綁定後要看得到自己（RLS 已限制成自己那列）
--    signup_requests  之後的留言簿頁面（RLS 已限制成只有員工）
--
-- ☢️ bookings、credit_ledger、class_sessions 故意不開。
--    那是第 33 步的事，要跟訂課邏輯一起測。
--    第 33 步一定會再撞到一次 permission denied —— 那是預期的，
--    不是壞掉。到時候看這支檔案就知道要補什麼。
-- ═══════════════════════════════════════════════════

grant usage on schema public to anon, authenticated;
grant select, update on public.customers      to authenticated;
grant select          on public.signup_requests to authenticated;


-- ═══════════════════════════════════════════════════
-- 驗收
-- ═══════════════════════════════════════════════════
select
  (select count(*) from information_schema.role_table_grants
    where table_schema='public' and grantee='service_role'
      and privilege_type in ('SELECT','INSERT','UPDATE','DELETE'))          as service_role權限數,
  (select string_agg(table_name||':'||privilege_type, '、' order by table_name, privilege_type)
     from information_schema.role_table_grants
    where table_schema='public' and grantee='authenticated'
      and privilege_type in ('SELECT','INSERT','UPDATE','DELETE'))          as authenticated開了什麼,
  (select count(*) from information_schema.role_table_grants
    where table_schema='public' and grantee='anon'
      and privilege_type in ('SELECT','INSERT','UPDATE','DELETE'))          as anon權限數,
  (select count(*) from pg_policies
    where schemaname='public'
      and coalesce(qual,'')||coalesce(with_check,'') like '%FROM employees%') as還在直接讀employees的政策數,
  (select rolbypassrls from pg_roles where rolname='service_role')           as service_role能繞過RLS嗎;
