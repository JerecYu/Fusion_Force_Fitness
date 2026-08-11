/* ═══════════════════════════════════════════════════════════════════════
   db/16-staff-access.sql  ——  第 38 步：教練用 LINE 登入

   跟客人同一道門：教練從 LINE 開頁面 → 拿到 Supabase session →
   資料庫用 auth.uid() 對到 employees.auth_user_id → is_staff() 就是 true。
   不需要密碼、不需要 email。

   這支檔案只做「開門」，不塞任何資料，所以不需要保險絲。
   ═══════════════════════════════════════════════════════════════════════ */


/* ── 1 ☢️ 先修一個洞：employees 的讀取政策太鬆 ─────────────────────────

   原本寫的是：

       using ( auth.uid() is not null )

   意思是「只要是登入過的人，就看得到整張 employees」——
   包括六個人的【本名】【電話】【email】。
   而登入過的人 = 每一個從 LINE 進來的客人。

   ☢️ 它現在沒有造成外洩，純粹是因為 authenticated 這個身分
      在 employees 上「一個 GRANT 都沒有」，外面那道門本來就是鎖的。
      RLS 是裡面那道門，外面鎖著的時候，裡面開多大都沒差。

   ☢️ 但這一步就是要打開外面那道門（第 3 節的 grant）。
      所以政策一定要在同一支檔案裡先改掉 ——
      分兩次做，中間那段時間全部客人都讀得到員工個資。
   ────────────────────────────────────────────────────────────────── */

drop policy if exists "員工可讀全部同事" on public.employees;

create policy "員工可讀全部同事" on public.employees
  for select
  using ( public.is_staff() );

/*  為什麼不會無限遞迴：
    is_staff() 是 security definer、擁有者是 postgres，
    而 employees 也是 postgres 的、沒有開 force row level security ——
    Postgres 的資料表擁有者本來就不受自己資料表的 RLS 限制。
    所以函式裡那句 select 不會再觸發這條政策。
    （已用 pg_class.relforcerowsecurity = false 確認過。）           */


/* ── 2  補兩張表的 with check ────────────────────────────────────────

   跟第 33 步 bookings 那個洞是同一種：
   只寫 using 的話，資料庫只檢查「你可以改哪幾列」，
   完全不檢查「你把它改成什麼樣子」。

   employees：不加的話，教練可以把自己的 auth_user_id 改成別的值
              （等於自己把自己踢出員工名單，或把別人的登入搞壞）。
   customers：不加的話，客人可以把自己的 auth_user_id 清成 null
              ——那一列就變成「沒人綁過」，誰知道姓名＋手機都能重新認領。

   ⚠️ employees 的 UPDATE 目前【沒有 GRANT】，所以這條政策現在是備而不用。
      真正擋住它的是 GRANT，不是政策。這裡先寫好，之後要開才不會忘。
   ────────────────────────────────────────────────────────────────── */

drop policy if exists "只能改自己" on public.employees;

create policy "只能改自己" on public.employees
  for update
  using      ( auth_user_id = auth.uid() )
  with check ( auth_user_id = auth.uid() );


drop policy if exists "客人只能改自己" on public.customers;

create policy "客人只能改自己" on public.customers
  for update
  using      ( auth_user_id = auth.uid() )
  with check ( auth_user_id = auth.uid() );


/* ── 3  開門：authenticated 可以 select employees ───────────────────

   配上第 1 節的政策，實際效果是：

     · 還沒開通的人（含全部客人）→ 查得到，但回 0 列
     · 已開通的教練              → 回 6 列（同事的本名也看得到，那是同事）

   ☢️ 只給 select。不給 insert / update / delete ——
      教練不需要改員工資料，櫃檯的事由你在 Supabase 後台做。
   ────────────────────────────────────────────────────────────────── */

grant select on public.employees to authenticated;


/* ── 4  驗收 ────────────────────────────────────────────────────────
   整張 Run 完之後，這三段的結果應該長成註解寫的樣子。
   ────────────────────────────────────────────────────────────────── */

-- 4-1　政策確認：SELECT 應該是 is_staff()，兩條 UPDATE 都要有 check 條件
select tablename          as 資料表,
       policyname         as 規則,
       cmd                as 動作,
       coalesce(qual,'—')       as using條件,
       coalesce(with_check,'—') as check條件
from pg_policies
where schemaname = 'public'
  and tablename in ('employees','customers')
order by tablename, cmd, policyname;
-- 期望：employees / SELECT / is_staff() / —
--       employees / UPDATE / auth_user_id = auth.uid() / auth_user_id = auth.uid()
--       customers / UPDATE / auth_user_id = auth.uid() / auth_user_id = auth.uid()


-- 4-2　權限確認：employees 對 authenticated 只該有 SELECT
select grantee as 身分,
       string_agg(privilege_type, ', ' order by privilege_type) as 權限
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name   = 'employees'
  and grantee in ('anon','authenticated')
group by grantee
order by grantee;
-- 期望：anon 沒有 SELECT／authenticated 有 SELECT（後面那串 REFERENCES,
--       TRIGGER, TRUNCATE 是 Supabase 預設帶的，不影響讀取）


-- 4-3　目前開通了幾個人（現在應該是 0，六個人登入後會變成 6）
select count(*) filter (where auth_user_id is not null) as 已開通,
       count(*)                                         as 總人數
from public.employees;
-- 期望（現在）：已開通 0 ／ 總人數 6
