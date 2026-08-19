-- ============================================================
-- 38 · PT／PGT 進 products 表（以《財務與教練薪資整合規則》2026-08-19 正式版為準）
--
-- 為什麼要進表：LIFF 三頁（pricing／PT-booking／PGT-booking）本來把價格寫死在
-- HTML 裡，跟正式規則對不上（PT 單堂少報 300、10 堂少報 3000、PGT 整排錯一格）。
-- 價格只放一個地方 = 以後改價只改一個地方。
--
-- ☢️ products 只是「牌價」。實際收多少一律以 credit_ledger.amount 為準
--    （29-purchase.sql 已經是這樣做）。改這裡不會動到任何一筆已成交的錢。
-- ============================================================

-- ── ① 兩個新欄位 ─────────────────────────────────────────────
-- headcount：這個方案是幾個人一起上。GT 一律 1。
-- kind：方案種類。前端靠 (kind, headcount) 兩個欄位就能把價目表排出來，
--       不用去猜 label 裡的中文字。
alter table public.products
  add column if not exists headcount smallint not null default 1,
  add column if not exists kind text not null default 'single';

alter table public.products drop constraint if exists products_headcount_check;
alter table public.products add constraint products_headcount_check
  check (headcount >= 1 and headcount <= 12);

alter table public.products drop constraint if exists products_kind_check;
alter table public.products add constraint products_kind_check
  check (kind in ('trial','single','pack','half'));

comment on column public.products.headcount is '幾個人一起上。GT＝1；PT＝1 或 2；PGT＝3～6。';
comment on column public.products.kind is 'trial＝體驗／single＝單堂／pack＝預付包／half＝半堂（內部）。';
comment on column public.products.price is '☢️ 牌價，不是實收。實收看 credit_ledger.amount。PT／PGT 是【整堂總價】不是每人價。';

-- 舊的 GT 兩筆補上種類
update public.products set kind = 'single' where code = 'GT-1';
update public.products set kind = 'pack'   where code = 'GT-12';

-- ── ② PT ─────────────────────────────────────────────────────
-- 表 2：體驗 1人 1,000／2人 1,500；單堂 1人 1,800／2人 2,200；
--       預付 10 堂 1人 15,000／2人 20,000。
insert into public.products (code, product, label, kind, headcount, credits, price, is_active, sort_order) values
  ('PT-TRY-1',  'PT', '體驗（一對一）',       'trial',  1,  1,  1000, true, 1),
  ('PT-TRY-2',  'PT', '體驗（一對二）',       'trial',  2,  1,  1500, true, 2),
  ('PT-1-1',    'PT', '單堂（一對一）',       'single', 1,  1,  1800, true, 3),
  ('PT-1-2',    'PT', '單堂（一對二）',       'single', 2,  1,  2200, true, 4),
  ('PT-10-1',   'PT', '預付 10 堂（一對一）', 'pack',   1, 10, 15000, true, 5),
  ('PT-10-2',   'PT', '預付 10 堂（一對二）', 'pack',   2, 10, 20000, true, 6),
  -- ☢️ 半堂是內部價，不對外標。is_active = false ⇒ add_purchase 會擋掉，
  --    所以就算 code 被猜到也買不了。credits 先記 1（半堂到底扣幾堂還沒定案）。
  ('PT-HALF-1', 'PT', '半堂（內部）',         'half',   1,  1,   600, false, 7)
on conflict (code) do update set
  product = excluded.product, label = excluded.label, kind = excluded.kind,
  headcount = excluded.headcount, credits = excluded.credits, price = excluded.price,
  is_active = excluded.is_active, sort_order = excluded.sort_order;

-- ── ③ PGT ────────────────────────────────────────────────────
-- 表 3：單堂 3人 2,100／4人 2,400／5人 2,700／6人 3,000。
-- ☢️ 上限 6 人，而且【不販售預付】—— 所以這裡只有 single、沒有 pack。
insert into public.products (code, product, label, kind, headcount, credits, price, is_active, sort_order) values
  ('PGT-1-3', 'PGT', '單堂（一對三）', 'single', 3, 1, 2100, true, 1),
  ('PGT-1-4', 'PGT', '單堂（一對四）', 'single', 4, 1, 2400, true, 2),
  ('PGT-1-5', 'PGT', '單堂（一對五）', 'single', 5, 1, 2700, true, 3),
  ('PGT-1-6', 'PGT', '單堂（一對六）', 'single', 6, 1, 3000, true, 4)
on conflict (code) do update set
  product = excluded.product, label = excluded.label, kind = excluded.kind,
  headcount = excluded.headcount, credits = excluded.credits, price = excluded.price,
  is_active = excluded.is_active, sort_order = excluded.sort_order;

-- ── ④ 權限 ───────────────────────────────────────────────────
-- 沒有 drop view／drop table，權限不會掉；但第 66 步的教訓是「別用猜的」，補一次不花錢。
grant select on public.products to anon, authenticated;
