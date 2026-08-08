-- ═══════════════════════════════════════════════════════════
-- 11-alter-migration.sql
-- 為「舊系統搬遷」和「PT／RT 商品線」預留的欄位
-- 2026-08-08　對應路線圖第 23 步
--
-- 這一支不塞任何業務資料，所以不需要保險絲。
-- 每一段都寫成「重複執行安全」（if not exists / where ... is null /
-- create or replace），整張跑幾次結果都一樣。
--
-- ⚠️ 跑之前先確認 SQL Editor 右上角的 Role 是 postgres，不是 anon。
--
-- ❓ 半夜的排程會不會壞掉？　不會。
--    daily_class_job() 的 insert 沒有列出 product，而新欄位有預設值 'GT'，
--    所以它照跑，長出來的課自動就是 GT。07-daily-job.sql 一個字都不用動。
--
-- ❓ 中間哪一段失敗會怎樣？　整張退回，什麼都沒改。
--    Supabase 把整個分頁當成一次交易，跟保險絲是同一個原理。
--    看到紅字不用緊張，資料庫還是跑之前的樣子。
-- ═══════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════
-- ① class_sessions.product ── 這一堂是哪一種商品
-- ═══════════════════════════════════════════════════════════
-- GT  主題式團體課（目前唯一在做的）
-- PT  私人教練課
-- PGT 私人團體班
-- RT  場地租借（沒有教練、不扣堂數、收租金）
--
-- 預設 GT：現有的 28 堂課全部是團體課，加完立刻就是對的。

alter table public.class_sessions
  add column if not exists product text not null default 'GT';

alter table public.class_sessions
  drop constraint if exists class_sessions_product_check;

alter table public.class_sessions
  add constraint class_sessions_product_check
  check (product in ('GT','PT','PGT','RT'));

comment on column public.class_sessions.product is
  '商品別。GT=團體課（唯一會出現在公開課表）／PT／PGT／RT。改這一欄之前先看 public_schedule 有沒有跟著過濾。';

-- 公開課表之後會用 product 過濾，先把索引準備好
create index if not exists class_sessions_product_date_idx
  on public.class_sessions (product, session_date);


-- ═══════════════════════════════════════════════════════════
-- ② credit_ledger.product ── 這筆堂數是哪一種商品的
-- ═══════════════════════════════════════════════════════════
-- 團體課的堂數不能拿去上私人課。不分的話，系統會覺得完全合理。
--
-- ⚠️ 注意：這裡「沒有」加 kind 欄位。
--    credit_ledger 本來就有 reason，值域是
--    purchase / bonus / class / adjust / refund
--    「買十送二」拆兩列用的就是 purchase + bonus，現成的，不要再開新欄位。

alter table public.credit_ledger
  add column if not exists product text not null default 'GT';

alter table public.credit_ledger
  drop constraint if exists credit_ledger_product_check;

alter table public.credit_ledger
  add constraint credit_ledger_product_check
  check (product in ('GT','PT','PGT'));      -- RT 不扣堂數，所以不在這裡

comment on column public.credit_ledger.product is
  '這筆堂數屬於哪一種商品。餘額是「每人每種商品各一個」，不是一個總數。';


-- ═══════════════════════════════════════════════════════════
-- ③ bookings.paid_by_customer_id ── 這一堂扣誰的卡
-- ═══════════════════════════════════════════════════════════
-- 購課者帶朋友來體驗：朋友各自一列 bookings（人數才會對，教練鐘點費才算得對），
-- 但五列的 paid_by_customer_id 都指向購課者。
--
-- on delete restrict：擋住「刪掉一個曾經幫別人付過錢的客人」。
-- 客人本來就不該被刪除 —— 刪掉會讓別人的預約歷史失去付款人。

alter table public.bookings
  add column if not exists paid_by_customer_id uuid;

-- 既有每一列先補成「自己付」
update public.bookings
   set paid_by_customer_id = customer_id
 where paid_by_customer_id is null;

alter table public.bookings
  alter column paid_by_customer_id set not null;

alter table public.bookings
  drop constraint if exists bookings_paid_by_fkey;

alter table public.bookings
  add constraint bookings_paid_by_fkey
  foreign key (paid_by_customer_id) references public.customers(id)
  on delete restrict;

comment on column public.bookings.paid_by_customer_id is
  '這一堂的堂數從誰的卡扣。預設等於 customer_id（自己付）。代訂體驗客時指向購課者。';

create index if not exists bookings_paid_by_idx
  on public.bookings (paid_by_customer_id);


-- ═══════════════════════════════════════════════════════════
-- ④ 重建 customer_credits ── 每人「每種商品」各一個餘額
-- ═══════════════════════════════════════════════════════════
-- 原本是：customer_id, balance          （一個人一個數字）
-- 改成：  customer_id, product, balance （一個人每種商品各一個數字）
--
-- ⚠️ 為什麼要 drop 再 create，不能 create or replace：
--    create or replace view 只能在「最後面」加欄位，不能在中間插。
--    product 要插在 balance 前面，所以只能重建。
--
-- ☢️ security_invoker = true ── 這一行是重點，不要拿掉。
--    檢視表預設是「以擁有者身分執行」，會繞過 RLS
--    → 哪天開放給客人讀，每個人都看得到別人的餘額。
--    加上 invoker 之後，它會走 credit_ledger 上「客人只讀自己的」那條規則。
--
--    ⚠️ 這跟 public_schedule 剛好相反：
--       public_schedule 是「故意」繞過 RLS（要端出教練名字）
--       customer_credits 是「絕對不能」繞過（每個人只能看自己的錢）
--       同樣是檢視表，方向相反 —— 建新的檢視表時每次都要重問一次。

drop view if exists public.customer_credits;

create view public.customer_credits
  with (security_invoker = true)
as
  select
    customer_id,
    product,
    sum(delta)::integer as balance
  from public.credit_ledger
  group by customer_id, product;

revoke all on public.customer_credits from public, anon, authenticated;
-- 先全部關死。客人要能查自己的堂數是第 33 步的事，那時候再開。
--
-- 📌 給第 33 步的自己：開放的時候會踩到這個
--    credit_ledger 的兩條政策裡面有
--      select id from customers where auth_user_id = auth.uid()
--      select 1  from employees where auth_user_id = auth.uid()
--    security_invoker = true 之後，這兩句是「用客人的身分」去查的。
--    客人沒有 employees 的讀取權 → 會直接跳 permission denied，
--    不是回 0 筆，是整句查詢失敗。
--
--    正解不是把 employees 開給客人（那等於拆掉第二幕辛苦蓋的牆），
--    而是把這兩個判斷包成 security definer 的小函式，只回傳 true/false。
--    本機用 PostgreSQL 16 實測過，確認會這樣。

comment on view public.customer_credits is
  '剩餘堂數＝流水帳加總，每人每種商品各一列。security_invoker=true，一定要走 RLS。';


-- ═══════════════════════════════════════════════════════════
-- ⑤ pt_requests.kind → product ── 同一個概念只留一個名字
-- ═══════════════════════════════════════════════════════════
-- pt_requests 原本叫 kind（值 PT／PGT），跟上面兩張表的 product 是同一件事。
-- 同一個概念兩個名字，半年後一定會有人寫錯。趁還沒資料改掉。
--
-- 保險：有資料就直接中止，不動它。

do $$
begin
  if exists (select 1 from public.pt_requests) then
    raise exception '⛔ pt_requests 已經有資料（% 筆），這段改名先不要跑，來找人討論。',
      (select count(*) from public.pt_requests);
  end if;

  if exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'pt_requests' and column_name = 'kind'
  ) then
    alter table public.pt_requests rename column kind to product;
    raise notice '✅ pt_requests.kind 已改名為 product';
  else
    raise notice '－ pt_requests.product 已經是這個名字了，跳過';
  end if;
end $$;


-- ═══════════════════════════════════════════════════════════
-- ⑥ 兩條 RLS 規則 ── 讓 paid_by 真的有作用
-- ═══════════════════════════════════════════════════════════
-- 不改的話，paid_by_customer_id 只是一個沒人看的欄位：
-- 購課者查不到自己幫朋友訂的課，櫃檯也開不了體驗客的預約。
-- 「加了欄位但沒有人用它」是最難發現的那種錯 —— 不會報錯，只是功能不會動。

-- (1) 客人讀自己的預約 → 「自己上的課」＋「自己付錢的課」
drop policy if exists "客人讀自己的預約" on public.bookings;
create policy "客人讀自己的預約"
  on public.bookings for select
  using (
    customer_id in (
      select id from public.customers where auth_user_id = auth.uid()
    )
    or paid_by_customer_id in (
      select id from public.customers where auth_user_id = auth.uid()
    )
  );

-- (2) 員工可以代客人開預約（櫃檯幫體驗客報名）
--     原本 bookings 只有「客人只能幫自己報名」，員工完全不能新增。
drop policy if exists "員工可代開預約" on public.bookings;
create policy "員工可代開預約"
  on public.bookings for insert
  with check (
    exists (
      select 1 from public.employees
      where auth_user_id = auth.uid() and is_active = true
    )
  );


-- ═══════════════════════════════════════════════════════════
-- ⑦ 驗收 ── 跑完把下面整段反白，按 Run selected
-- ═══════════════════════════════════════════════════════════
-- 每一段都有 ★ 開頭的標記欄，Results 是舊的一眼就看得出來。

-- ★A：三個新欄位都在嗎？（應該回 3 筆：兩個 product ＋ 一個 paid_by）
select '★A段 新欄位' as 這是哪一段,
       table_name as 資料表, column_name as 欄位, data_type as 型別, is_nullable as 可空白
  from information_schema.columns
 where table_schema = 'public'
   and (   (table_name = 'class_sessions' and column_name = 'product')
        or (table_name = 'credit_ledger'  and column_name = 'product')
        or (table_name = 'bookings'       and column_name = 'paid_by_customer_id'))
 order by table_name;

-- ★B：既有的預約，paid_by 是不是每一列都等於 customer_id？
--     「不一樣的列數」必須是 0。
select '★B段 回填檢查' as 這是哪一段,
       count(*)                                                   as 預約總數,
       count(*) filter (where paid_by_customer_id = customer_id)   as 自己付的,
       count(*) filter (where paid_by_customer_id <> customer_id)  as 不一樣的
  from public.bookings;

-- ★C：customer_credits 現在長什麼樣？
--     現在還沒有客人，回 0 筆是正確的。重點看下面 ★D 的欄位。
select '★C段 餘額' as 這是哪一段, * from public.customer_credits limit 20;

-- ★D：customer_credits 的欄位應該是 customer_id / product / balance 三欄
select '★D段 檢視表欄位' as 這是哪一段,
       column_name as 欄位, ordinal_position as 順序
  from information_schema.columns
 where table_schema = 'public' and table_name = 'customer_credits'
 order by ordinal_position;

-- ★E：pt_requests 改名成功了嗎？（應該看到 product，看不到 kind）
select '★E段 pt_requests' as 這是哪一段, column_name as 欄位
  from information_schema.columns
 where table_schema = 'public' and table_name = 'pt_requests'
   and column_name in ('kind','product');

-- ★F：bookings 現在有幾條 RLS 規則？（原本 5 條，加一條代開＝6 條）
select '★F段 RLS 規則' as 這是哪一段,
       policyname as 規則名稱, cmd as 動作
  from pg_policies
 where schemaname = 'public' and tablename = 'bookings'
 order by cmd, policyname;

-- ★G：現有 28 堂課的 product 應該全部是 GT
select '★G段 課堂商品別' as 這是哪一段, product as 商品, count(*) as 堂數
  from public.class_sessions
 group by product;
