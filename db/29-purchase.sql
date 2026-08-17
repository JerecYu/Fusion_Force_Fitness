-- ═══════════════════════════════════════════════════════════════
--  29-purchase.sql  ·  購課（C 第二期第一段）
--  2026-08-17
--
--  Jerec 2026-08-17 的三個決定：
--    ① 匯款【先給堂數】，但標成「待入帳」
--    ② 付款方式只有兩種：現金、匯款／轉帳
--    ③ 所有教練都能購課（跟現場收錢的是同一批人）
--
--  ☢️ 為什麼要現在做：上線兩天，購課紀錄 0 筆 —— 錢在收，但沒進系統。
--     19 位客人剩 0 堂、8 位剩 1～2 堂，第一個 0 堂的人來上課，帳就會變負。
--
--  ☢️ 這是第二個「能動到錢」的入口（第一個是 check_in）。
--     所以它跟 check_in 用同一套規矩：
--       · 只能走函式，資料表沒有 INSERT 政策
--       · 每一筆都記 created_by（誰入的帳）
--       · 出錯不用刪，用【沖銷】—— 帳本只增不減
-- ═══════════════════════════════════════════════════════════════

-- ── ① 商品 ───────────────────────────────────────────────────
--  ☢️ 不要把價格寫死在程式裡。價目表會變，而【那一筆當時賣多少】
--     是查帳時唯一重要的事 —— 所以金額要跟著每一筆存下來，
--     商品表只負責「現在賣多少」。
create table if not exists public.products (
  code        text primary key,
  product     text        not null,          -- 'GT' / 'PT' / 'PGT'
  label       text        not null,
  credits     integer     not null check (credits > 0),
  price       integer     not null check (price >= 0),
  is_active   boolean     not null default true,
  sort_order  integer     not null default 0
);
comment on table public.products is '課程方案。價格會變，所以每一筆購課都要自己存下當時的金額。';

insert into public.products (code, product, label, credits, price, sort_order) values
  ('GT-1',  'GT', '單堂',       1,   400, 1),
  ('GT-12', 'GT', '買 10 送 2', 12, 4000, 2)
on conflict (code) do nothing;

alter table public.products enable row level security;
drop policy if exists "大家都看得到方案" on public.products;
create policy "大家都看得到方案" on public.products for select using (true);
grant select on public.products to anon, authenticated;

-- ── ② 帳本加四欄 ─────────────────────────────────────────────
--  ☢️ 舊資料全部是 null，這是誠實的 —— 搬遷進來的那 76 筆，
--     我們本來就不知道當時收了多少錢。不要假裝知道。
alter table public.credit_ledger
  add column if not exists amount       integer,
  add column if not exists pay_method   text,
  add column if not exists paid_at      timestamptz,
  add column if not exists product_code text references public.products(code);

do $$ begin
  alter table public.credit_ledger add constraint credit_ledger_pay_method_ck
    check (pay_method is null or pay_method in ('cash','transfer'));
exception when duplicate_object then null; end $$;

comment on column public.credit_ledger.amount is '這一筆實際收了多少錢（NT$）。沖銷是負的。舊資料是 null（不知道）。';
comment on column public.credit_ledger.pay_method is 'cash＝現金／transfer＝匯款。舊資料是 null。';
comment on column public.credit_ledger.paid_at is
  '錢【實際進帳戶】的時間。現金＝當下；匯款＝確認入帳才填。☢️ null 且 pay_method=transfer ＝ 待入帳。';

-- ☢️ 待入帳清單靠這個索引，人多了才不會全表掃描
create index if not exists credit_ledger_unpaid
  on public.credit_ledger (created_at) where pay_method = 'transfer' and paid_at is null;

-- ── ③ 購課 ───────────────────────────────────────────────────
create or replace function public.add_purchase(
  p_customer uuid, p_code text, p_method text, p_note text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_p record; v_c record; v_id uuid; v_bal integer;
begin
  if not public.is_staff() then
    raise exception '只有員工可以購課';
  end if;
  if p_method not in ('cash','transfer') then
    return jsonb_build_object('ok', false, 'why', 'bad_method');
  end if;

  select * into v_p from public.products where code = p_code and is_active;
  if not found then return jsonb_build_object('ok', false, 'why', 'bad_product'); end if;

  select id, name, is_active into v_c from public.customers where id = p_customer;
  if not found then return jsonb_build_object('ok', false, 'why', 'no_customer'); end if;
  if v_c.is_active = false then return jsonb_build_object('ok', false, 'why', 'inactive'); end if;

  -- ☢️ 堂數【立刻】給，不管付款方式 —— 這是 Jerec 選的：
  --    「先給，但標待入帳」。匯款的人不會卡在現場訂不到課。
  --    paid_at 只影響「這筆錢收到了沒」，不影響餘額。
  insert into public.credit_ledger
    (customer_id, delta, reason, product, note, created_by,
     amount, pay_method, paid_at, product_code)
  values
    (p_customer, v_p.credits, 'purchase', v_p.product,
     coalesce(p_note, v_p.label), public.my_employee_id(),
     v_p.price, p_method,
     case when p_method = 'cash' then now() else null end,
     v_p.code)
  returning id into v_id;

  select coalesce(sum(delta),0) into v_bal
  from public.credit_ledger where customer_id = p_customer and product = v_p.product;

  return jsonb_build_object('ok', true, 'ledger_id', v_id, 'name', v_c.name,
           'label', v_p.label, 'credits', v_p.credits, 'price', v_p.price,
           'balance', v_bal, 'pending', (p_method = 'transfer'));
end $$;

revoke all on function public.add_purchase(uuid, text, text, text) from public;
grant execute on function public.add_purchase(uuid, text, text, text) to authenticated;

-- ── ④ 匯款確認入帳 ───────────────────────────────────────────
create or replace function public.confirm_payment(p_ledger uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_l record;
begin
  if not public.is_staff() then raise exception '只有員工可以確認入帳'; end if;

  select l.id, l.paid_at, l.pay_method, l.amount, c.name
    into v_l
  from public.credit_ledger l join public.customers c on c.id = l.customer_id
  where l.id = p_ledger;

  if not found then return jsonb_build_object('ok', false, 'why', 'not_found'); end if;
  if v_l.pay_method <> 'transfer' then return jsonb_build_object('ok', false, 'why', 'not_transfer'); end if;
  if v_l.paid_at is not null then
    return jsonb_build_object('ok', true, 'already', true, 'name', v_l.name);
  end if;

  -- ☢️ 只寫 paid_at。不碰 delta —— 堂數在購課當下就已經給了。
  update public.credit_ledger set paid_at = now() where id = p_ledger;
  return jsonb_build_object('ok', true, 'name', v_l.name, 'amount', v_l.amount);
end $$;

revoke all on function public.confirm_payment(uuid) from public;
grant execute on function public.confirm_payment(uuid) to authenticated;

-- ── ⑤ 購課按錯 → 沖銷（不是刪除）──────────────────────────────
--  ☢️ 帳本只增不減。刪掉一筆的話，事後沒有人能回答「這裡本來有什麼」。
--     沖銷是補一筆相反的，兩筆都留著。
create or replace function public.void_purchase(p_ledger uuid, p_why text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_l record; v_bal integer; v_why text;
begin
  -- ☢️ 2026-08-17 Jerec 調查實際發生頻率之後的決定：
  --      只有他能按 · 往回不限時間 · 原因必填
  --    這裡【不是】is_staff()。沖銷會同時改掉堂數和金額，而且是往回改 ——
  --    這個能力不該散給六位教練。教練按錯 → 告訴 Jerec → Jerec 沖銷。
  if not public.is_owner() then
    raise exception '只有負責人可以沖銷。教練按錯的話，請告訴 Jerec。';
  end if;

  -- ☢️ 原因必填。沒有原因的沖銷，三個月後跟「資料被人偷偷動過」長得一模一樣。
  v_why := btrim(coalesce(p_why, ''));
  if length(v_why) < 2 then
    return jsonb_build_object('ok', false, 'why', 'need_reason');
  end if;

  select l.*, c.name as cname into v_l
  from public.credit_ledger l join public.customers c on c.id = l.customer_id
  where l.id = p_ledger;

  if not found then return jsonb_build_object('ok', false, 'why', 'not_found'); end if;
  if v_l.reason <> 'purchase' then return jsonb_build_object('ok', false, 'why', 'not_purchase'); end if;

  -- 已經沖銷過的不要再沖一次
  if exists (select 1 from public.credit_ledger x
             where x.reason = 'adjust' and x.note like '沖銷 ' || p_ledger::text || '%') then
    return jsonb_build_object('ok', false, 'why', 'already_voided');
  end if;

  insert into public.credit_ledger
    (customer_id, delta, reason, product, note, created_by, amount, product_code)
  values
    (v_l.customer_id, -v_l.delta, 'adjust', v_l.product,
     '沖銷 ' || p_ledger::text || '：' || v_why,
     public.my_employee_id(), -coalesce(v_l.amount, 0), v_l.product_code);

  select coalesce(sum(delta),0) into v_bal
  from public.credit_ledger where customer_id = v_l.customer_id and product = v_l.product;

  return jsonb_build_object('ok', true, 'name', v_l.cname, 'balance', v_bal,
           'credits', v_l.delta, 'amount', v_l.amount, 'reason', v_why);
end $$;

revoke all on function public.void_purchase(uuid, text) from public;
grant execute on function public.void_purchase(uuid, text) to authenticated;

-- ── ⑥ 待入帳清單 ─────────────────────────────────────────────
--  ☢️ definer，不要加 security_invoker（牆是 is_staff()，見 db/25）
create or replace view public.staff_unpaid as
select l.id             as ledger_id,
       l.created_at,
       c.name           as customer_name,
       right(c.phone,3) as phone_tail,
       l.delta          as credits,
       l.amount,
       l.note,
       e.display_name   as created_by_name,
       round(extract(epoch from (now() - l.created_at)) / 86400)::int as waited_days
from public.credit_ledger l
join public.customers c on c.id = l.customer_id
left join public.employees e on e.id = l.created_by
where public.is_staff()
  -- ☢️ 一定要同時看 pay_method，不能只看 paid_at is null。
  --    搬遷進來的舊資料 paid_at 也是 null，但那不是「待入帳」，
  --    只是「我們不知道」。只看 paid_at 的話清單會多出 76 筆假的。
  and l.pay_method = 'transfer' and l.paid_at is null
  -- ☢️ 已經沖銷的要排除。2026-08-17 實測抓到的：購課按錯 → 沖銷之後，
  --    那筆匯款【還留在待入帳清單裡】，教練會去追一筆已經取消的錢。
  and not exists (select 1 from public.credit_ledger x
                  where x.reason = 'adjust' and x.note like '沖銷 ' || l.id::text || '%');

comment on view public.staff_unpaid is '匯款但還沒確認入帳的購課。純讀。';
grant select on public.staff_unpaid to authenticated;

-- ── ⑦ 最近的購課（給 Jerec 看，也是沖銷的入口）──────────────
--  ☢️ 用 drop + create，不是 create or replace ——
--     replace 不能把新欄位插到中間，只能加在最後。
drop view if exists public.staff_recent_purchases;

create view public.staff_recent_purchases as
select l.id             as ledger_id,
       l.created_at,
       c.name           as customer_name,
       right(c.phone,3) as phone_tail,
       l.delta          as credits,
       l.amount,
       l.pay_method,
       l.paid_at,
       l.product_code,
       l.note,
       e.display_name   as created_by_name,
       (v.id is not null) as voided,
       -- 沖銷的原因、誰沖的、什麼時候 —— 讓那一列自己說完整個故事
       substring(v.note from '^沖銷 [0-9a-f-]+：(.*)$') as void_reason,
       ve.display_name  as voided_by_name,
       v.created_at     as voided_at
from public.credit_ledger l
join public.customers c on c.id = l.customer_id
left join public.employees e on e.id = l.created_by
left join lateral (
  select x.* from public.credit_ledger x
  where x.reason = 'adjust' and x.note like '沖銷 ' || l.id::text || '%'
  order by x.created_at limit 1
) v on true
left join public.employees ve on ve.id = v.created_by
where public.is_staff()
  and l.reason = 'purchase'
  and l.product_code is not null;         -- 只看新系統開出來的，不含搬遷資料

grant select on public.staff_recent_purchases to authenticated;

-- ── 驗收 ──────────────────────────────────────────────────────
-- ☢️ 三支動到錢的函式，都要有擋非員工，而且不能改到別人的餘額
select p.proname as 函式,
       (pg_get_functiondef(p.oid) ilike '%is_staff%') as 有擋非員工,
       (pg_get_functiondef(p.oid) ilike '%my_employee_id%') as 有記是誰做的
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname='public' and p.proname in ('add_purchase','confirm_payment','void_purchase')
order by 1;

-- ☢️ 兩張檢視表必須是 definer（牆是 is_staff()，見 db/25 的教訓）
select c.relname as 檢視表,
       case when coalesce(c.reloptions::text,'') like '%security_invoker=true%'
            then 'invoker ☢️ 不對' else 'definer ✓' end as 模式
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname='public' and c.relkind='v'
  and c.relname in ('staff_unpaid','staff_recent_purchases');

-- ☢️ 待入帳清單【不能】把搬遷進來的舊資料算進去（那些 paid_at 也是 null）
select count(*) as 待入帳筆數 from public.staff_unpaid;
-- 剛上線時期望：0

-- ☢️ 沖銷只有負責人能做、原因必填、而且【不刪任何東西】
select (pg_get_functiondef(p.oid) ilike '%is_owner%')    as 只有負責人,
       (pg_get_functiondef(p.oid) ilike '%need_reason%') as 原因必填,
       (pg_get_functiondef(p.oid) ilike '%delete %')     as 有刪除動作
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname='public' and p.proname='void_purchase';
-- 期望：true / true / false
