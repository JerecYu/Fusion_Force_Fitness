-- ═══════════════════════════════════════════════════
-- customers 客人
-- phone 是綁定 LINE 的鑰匙，一定要唯一
-- ═══════════════════════════════════════════════════

create table customers (
  id            uuid primary key default gen_random_uuid(),
  auth_user_id  uuid unique references auth.users(id) on delete set null,
  name          text not null,
  phone         text not null unique,       -- 綁定 LINE 用，不可重複
  line_user_id  text unique,                -- 綁定後才有值
  birthday      date,
  note          text,                       -- 內部備註，客人看不到
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

-- 開啟 RLS
alter table customers enable row level security;

-- 規則一：客人只能看自己那一筆
create policy "客人只能讀自己"
  on customers for select
  using ( auth_user_id = auth.uid() );

-- 規則二：客人只能改自己那一筆
create policy "客人只能改自己"
  on customers for update
  using ( auth_user_id = auth.uid() );

-- 規則三：員工可以讀全部客人（上課要看名單）
create policy "員工可讀全部客人"
  on customers for select
  using (
    exists (
      select 1 from employees
      where employees.auth_user_id = auth.uid()
        and employees.is_active = true
    )
  );