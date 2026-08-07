-- ═══════════════════════════════════════════════════
-- employees 員工／教練
-- 這張表是所有模組的地基，其他表都會參照它
-- ═══════════════════════════════════════════════════

create table employees (
  id            uuid primary key default gen_random_uuid(),
  auth_user_id  uuid unique references auth.users(id) on delete set null,
  name          text not null,              -- 中文姓名：于郅弘
  display_name  text not null,              -- 對外顯示：Jerec
  role          text not null default 'coach'
                check (role in ('owner','admin','coach')),
  phone         text,
  email         text,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

-- 開啟 RLS（大門上鎖）
alter table employees enable row level security;

-- 規則一：員工可以看到所有同事的資料
create policy "員工可讀全部同事"
  on employees for select
  using ( auth.uid() is not null );

-- 規則二：只能改自己那一筆
create policy "只能改自己"
  on employees for update
  using ( auth_user_id = auth.uid() );