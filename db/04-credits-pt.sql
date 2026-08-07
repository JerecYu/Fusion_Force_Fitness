-- ═══════════════════════════════════════════════════
-- credit_ledger 堂數異動紀錄
-- 不存「剩餘堂數」，存每一筆變動，加總才是餘額
-- ═══════════════════════════════════════════════════

create table credit_ledger (
  id            uuid primary key default gen_random_uuid(),
  customer_id   uuid not null references customers(id) on delete cascade,
  delta         integer not null,           -- +10 / +2 / -1
  reason        text not null
                check (reason in ('purchase','bonus','class','adjust','refund')),
  booking_id    uuid references bookings(id) on delete set null,
  note          text,
  created_by    uuid references employees(id) on delete set null,
  created_at    timestamptz not null default now()
);

alter table credit_ledger enable row level security;

-- 客人只能讀自己的，永遠不能寫
create policy "客人唯讀自己的堂數"
  on credit_ledger for select
  using (
    customer_id in (
      select id from customers where auth_user_id = auth.uid()
    )
  );

-- 員工可讀全部
create policy "員工可讀全部堂數"
  on credit_ledger for select
  using (
    exists (
      select 1 from employees
      where auth_user_id = auth.uid() and is_active = true
    )
  );

-- 員工可以新增異動紀錄（課後核銷、櫃檯售課）
create policy "員工可新增堂數異動"
  on credit_ledger for insert
  with check (
    exists (
      select 1 from employees
      where auth_user_id = auth.uid() and is_active = true
    )
  );


-- ═══════════════════════════════════════════════════
-- pt_requests 私人課需求單
-- PT／PGT 是「需求」不是預約，不佔名額
-- ═══════════════════════════════════════════════════

create table pt_requests (
  id                 uuid primary key default gen_random_uuid(),
  customer_id        uuid not null references customers(id) on delete cascade,
  kind               text not null check (kind in ('PT','PGT')),
  spec               text,                  -- 一對一 / 一對二 / 一對三…
  people_count       smallint,              -- PGT 用
  preferred_coach_id uuid references employees(id) on delete set null,
  preferred_time     text,                  -- 客人自由填寫的希望時段
  note               text,
  status             text not null default 'new'
                     check (status in ('new','contacting','scheduled','done','cancelled')),
  handled_by         uuid references employees(id) on delete set null,
  created_at         timestamptz not null default now()
);

alter table pt_requests enable row level security;

create policy "客人讀自己的需求單"
  on pt_requests for select
  using (
    customer_id in (
      select id from customers where auth_user_id = auth.uid()
    )
  );

create policy "客人可送出需求單"
  on pt_requests for insert
  with check (
    customer_id in (
      select id from customers where auth_user_id = auth.uid()
    )
  );

create policy "員工可讀全部需求單"
  on pt_requests for select
  using (
    exists (
      select 1 from employees
      where auth_user_id = auth.uid() and is_active = true
    )
  );

create policy "員工可處理需求單"
  on pt_requests for update
  using (
    exists (
      select 1 from employees
      where auth_user_id = auth.uid() and is_active = true
    )
  );


-- ═══════════════════════════════════════════════════
-- 剩餘堂數：不是欄位，是即時算出來的
-- ═══════════════════════════════════════════════════

create view customer_credits as
  select customer_id, sum(delta)::integer as balance
  from credit_ledger
  group by customer_id;