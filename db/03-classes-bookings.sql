-- ═══════════════════════════════════════════════════
-- class_templates 週課表範本
-- 「每週一 12:30 功能性核心，Johnson 帶」這種固定安排
-- ═══════════════════════════════════════════════════

create table class_templates (
  id            uuid primary key default gen_random_uuid(),
  weekday       smallint not null check (weekday between 1 and 7),  -- 1=週一
  start_time    time not null,
  duration_min  smallint not null default 60,
  title         text not null,
  level         text not null check (level in ('beg','int','adv')),
  coach_id      uuid references employees(id) on delete set null,
  capacity      smallint not null default 10,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

alter table class_templates enable row level security;

-- 課表要公開，任何人都能看
create policy "課表公開可讀"
  on class_templates for select
  using ( true );


-- ═══════════════════════════════════════════════════
-- class_sessions 每一堂實際的課
-- 範本 × 日期 = 一堂真實的課。預約系統的核心
-- ═══════════════════════════════════════════════════

create table class_sessions (
  id            uuid primary key default gen_random_uuid(),
  template_id   uuid references class_templates(id) on delete set null,
  session_date  date not null,
  start_time    time not null,          -- 以下欄位從範本複製，凍結當時狀況
  duration_min  smallint not null default 60,
  title         text not null,
  level         text not null check (level in ('beg','int','adv')),
  coach_id      uuid references employees(id) on delete set null,
  capacity      smallint not null default 10,
  status        text not null default 'pending'
                check (status in ('pending','confirmed','cancelled','completed')),
  settled_at    timestamptz,            -- 00:00 結算的時間
  created_at    timestamptz not null default now(),
  unique (template_id, session_date)    -- 同一天同一堂課不能建兩次
);

alter table class_sessions enable row level security;

create policy "課堂公開可讀"
  on class_sessions for select
  using ( true );

-- 教練可以把自己的課標記為已完成
create policy "教練可改自己的課"
  on class_sessions for update
  using (
    coach_id in (
      select id from employees
      where auth_user_id = auth.uid() and is_active = true
    )
  );


-- ═══════════════════════════════════════════════════
-- bookings 預約
-- ═══════════════════════════════════════════════════

create table bookings (
  id            uuid primary key default gen_random_uuid(),
  session_id    uuid not null references class_sessions(id) on delete cascade,
  customer_id   uuid not null references customers(id) on delete cascade,
  status        text not null default 'booked'
                check (status in ('booked','attended','absent','cancelled')),
  booked_at     timestamptz not null default now(),
  cancelled_at  timestamptz,
  checked_by    uuid references employees(id) on delete set null,
  checked_at    timestamptz,
  unique (session_id, customer_id)      -- 同一堂課同一人只能報一次
);

alter table bookings enable row level security;

-- 客人只看得到自己的預約
create policy "客人讀自己的預約"
  on bookings for select
  using (
    customer_id in (
      select id from customers where auth_user_id = auth.uid()
    )
  );

-- 客人只能幫自己報名
create policy "客人只能幫自己報名"
  on bookings for insert
  with check (
    customer_id in (
      select id from customers where auth_user_id = auth.uid()
    )
  );

-- 客人可以取消，但要在課前 1 小時以前
create policy "客人取消需在課前一小時"
  on bookings for update
  using (
    customer_id in (
      select id from customers where auth_user_id = auth.uid()
    )
    and exists (
      select 1 from class_sessions s
      where s.id = bookings.session_id
        and (s.session_date + s.start_time) - now() > interval '1 hour'
    )
  );

-- 員工可讀全部預約（點名要看名單）
create policy "員工可讀全部預約"
  on bookings for select
  using (
    exists (
      select 1 from employees
      where auth_user_id = auth.uid() and is_active = true
    )
  );

-- 員工可以點名（改 status）
create policy "員工可點名"
  on bookings for update
  using (
    exists (
      select 1 from employees
      where auth_user_id = auth.uid() and is_active = true
    )
  );