-- ============================================================
-- 41 · 服務紀錄骨架 —— 規則文件第六篇 4「共用結算紀錄」
--
-- 為什麼是這一步：
--   外派、諧動活動、企業包班三個新商品，都要記「這一次服務發生了、
--   誰上的、認列多少」。系統現在【只有 GT 有這種紀錄】（bookings ＋ 點名），
--   PT／PGT 本身一筆上課紀錄都沒有 —— 只有 pt_requests（需求單）。
--   外派是 PT／PGT 的加購項，所以它沒辦法比 PT／PGT 本體早做。
--
--   Jerec 的 Sales Record「PT流水帳」15,861 筆已經把形狀寫出來了：
--     日期｜時間｜教練｜學員｜銷課方式｜人數｜堂數｜當課教練抽成前業績｜課程方案
--   這張表就是把那本 Excel 搬進資料庫，欄位對齊規則文件。
--
-- ☢️ GT 不搬進來。GT 已經在線上跑（bookings ＋ check_in），
--    重做等於拿正在收錢的功能去冒險。GT 的 booking id 就當它的服務紀錄 ID。
--    以後算薪水時再用一張檢視表把兩邊併起來。
--
-- ☢️ 這一步【不動任何現有資料】。純新增資料表，沒有 drop、沒有 update。
-- ============================================================

-- ── ① 服務紀錄 ──────────────────────────────────────────────
create table if not exists public.service_records (
  id             uuid primary key default gen_random_uuid(),

  -- 服務類型。☢️ 一筆只能是一種，決定它走抽成還是鐘點費（第五篇 1）。
  --   PT      私人教練課
  --   PGT     私人團體班
  --   PT_OUT  PT 外派
  --   PGT_OUT PGT 外派
  --   EVENT   諧動外派活動
  --   CORP    企業包班
  service_type   text not null
                 check (service_type in ('PT','PGT','PT_OUT','PGT_OUT','EVENT','CORP')),

  -- 完成日期與時間。☢️ 薪資月份看這個，不看收款日（第六篇 1）。
  done_at        timestamptz not null,

  customer_id    uuid references public.customers(id) on delete restrict,
  company_name   text,                    -- 表 11：依原始帳目填寫，無資料留白
  tax_id         text,                    -- 表 11：統一編號

  headcount      smallint,                -- 購買商品人數規格（PT 1~2、PGT 3~6）
  attended_count smallint,                -- 當日實際出席人數
  product_code   text references public.products(code),
  plan_id        uuid,                    -- 原交易／方案 ID。☢️ 方案表還沒做，先留欄位不加 FK

  -- 銷課方式：single＝單堂現收、plan＝扣預收、free＝體驗或贈課
  charge_method  text not null default 'single'
                 check (charge_method in ('single','plan','free')),

  -- ── 錢 ──
  -- ☢️ 三個欄位是三件不同的事，不要混：
  --    revenue_amount 客人付的【課程／活動】部分
  --    travel_fee     客人付的【交通費】（外派 500／次、活動 500／次）
  --    perf_amount    這筆進【教練抽成基礎】多少 —— 活動走鐘點費，所以是 0
  revenue_amount integer not null default 0 check (revenue_amount >= 0),
  travel_fee     integer not null default 0 check (travel_fee     >= 0),
  perf_amount    integer not null default 0 check (perf_amount    >= 0),

  -- ── 諧動外派活動專用 ──
  -- 計費時數。☢️ 存進來的一定是【已經無條件進位】的值（第二篇 3）。
  billed_hours   numeric(4,1) check (billed_hours is null or billed_hours > 0),

  -- ── 企業包班專用（第二篇 4 的核定紀錄）──
  area               text,      -- 服務地區
  booked_hours       numeric(4,1),  -- 預約時數
  approved_headcount smallint,  -- 核定人數
  scope              text,      -- 專案內容
  transport          text,      -- 交通安排
  approver_id        uuid references public.employees(id),
  approved_on        date,

  -- ── 財務認列（第六篇 2 的狀態機，先做前兩段）──
  fin_status     text not null default 'pending' check (fin_status in ('pending','final')),
  fin_by         uuid references public.employees(id),
  fin_at         timestamptz,

  note           text,     -- 原始備註（表 11）
  manual_note    text,     -- 人工核定備註。☢️ 不得覆蓋原始備註，所以是另一欄
  rule_version   text not null default '2026-08-19',

  voided         boolean not null default false,
  void_reason    text,
  voided_by      uuid references public.employees(id),
  voided_at      timestamptz,

  created_at     timestamptz not null default now(),
  created_by     uuid references public.employees(id)
);

comment on table public.service_records is
  '共用結算紀錄（規則文件第六篇 4）。一筆＝一堂課或一次活動。☢️ GT 不在這裡，GT 走 bookings。';
comment on column public.service_records.perf_amount is
  '教練 PT＋PGT 抽成基礎。☢️ 諧動活動是 0（它走鐘點費）；外派是 課程費＋交通費。';
comment on column public.service_records.billed_hours is
  '計費時數，存進來時【已經無條件進位】：0.5→1、1.5→2、2.2→3。';

create index if not exists service_records_done  on public.service_records (done_at desc);
create index if not exists service_records_cust  on public.service_records (customer_id);
create index if not exists service_records_type  on public.service_records (service_type, done_at desc);

-- ── ② 這一次是誰上的 ────────────────────────────────────────
-- ☢️ 為什麼要獨立一張表：諧動外派活動【單次最多 2 位教練】，
--    而且每位都各自拿「時數 × 600」。塞在 service_records 裡的話
--    要嘛開兩個欄位、要嘛把同一次活動記兩筆 —— 記兩筆會讓客人付的錢被算兩次。
create table if not exists public.service_coaches (
  service_id uuid not null references public.service_records(id) on delete cascade,
  coach_id   uuid not null references public.employees(id) on delete restrict,
  is_lead    boolean not null default true,   -- 企業包班：單次至多 1 位主導教練
  primary key (service_id, coach_id)
);

comment on table public.service_coaches is '這一次服務由誰授課。活動最多 2 位；其他一律 1 位。';

create index if not exists service_coaches_coach on public.service_coaches (coach_id);

-- ── ③ 權限 ──────────────────────────────────────────────────
-- ☢️ 只開 select 給職員，寫入一律走 RPC（跟第 39、70 步同一個原則）。
alter table public.service_records enable row level security;
alter table public.service_coaches enable row level security;

drop policy if exists "職員看得到服務紀錄" on public.service_records;
create policy "職員看得到服務紀錄" on public.service_records
  for select using (public.is_staff());

drop policy if exists "職員看得到授課教練" on public.service_coaches;
create policy "職員看得到授課教練" on public.service_coaches
  for select using (public.is_staff());

grant select on public.service_records to authenticated;
grant select on public.service_coaches to authenticated;

-- ── ④ 檯面價查詢 ────────────────────────────────────────────
-- 給前端和 RPC 共用：PT／PGT 的檯面單價。
-- ☢️ 只回 is_active 的。歷史價格（第三篇 2、3）不從這裡出來 ——
--    那些只供辨識舊帳，不得用來產生新價格（第三篇 4）。
create or replace function public.list_prices(p_product text)
returns table (code text, kind text, headcount smallint, credits integer, price integer, label text)
language sql stable security definer set search_path = public as $fn$
  select code, kind, headcount, credits, price, label
  from public.products
  where product = p_product and is_active
  order by sort_order;
$fn$;

revoke all on function public.list_prices(text) from public;
grant execute on function public.list_prices(text) to authenticated;
