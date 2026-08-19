-- ============================================================
-- 46 · 課程轉讓（規則文件正式補全版 第二篇 5）
--
--   可轉讓 │ PT 預付、GT 預付；須有剩餘堂數。PGT 不可轉讓
--   同類   │ PT 不得轉 GT，GT 亦不得轉 PT
--   識別   │ 沿用同一方案 ID，不得建立新銷售方案
--   金額   │ 0 元，不產生新收入或新業績
--   轉出   │ 「銷課方式」標示「轉出」，扣除相對應堂數
--   轉入   │ 「銷課方式」標示「轉入」，新增相對應堂數
--   紀錄   │ 保留原擁有人、新擁有人、轉讓日期、核准人及原方案紀錄
--
-- ☢️ 轉讓【不動用任何一堂】—— 堂數只是換了主人。
--    所以它不產生 plan_draws，只有兩筆帳本紀錄 ＋ 方案換擁有人。
--    對帳算式自己就會對：
--      原主人 帳本 −N、方案不再屬於他 → 兩邊各少 N ✓
--      新主人 帳本 +N、方案變成他的   → 兩邊各多 N ✓
-- ============================================================

-- ── ① 帳本要收得下這兩種理由 ────────────────────────────────
alter table public.credit_ledger drop constraint if exists credit_ledger_reason_check;
alter table public.credit_ledger add constraint credit_ledger_reason_check
  check (reason in ('purchase','bonus','class','adjust','refund','transfer_out','transfer_in'));

-- ── ② 配堂數要放過轉讓 ──────────────────────────────────────
-- ☢️ 不加這一段的話：轉出那筆（負的）會被當成「上課」去 FIFO 扣方案，
--    轉入那筆（正的）會被當成「退課」去找最新的方案退 —— 兩邊都會扣錯方案。
--    轉讓根本沒有用掉堂數，所以正確做法是【什麼都不配】。
create or replace function public.plan_allocate(p_ledger uuid)
returns void
language plpgsql security definer set search_path = public as $fn$
declare
  l record; r record;
  v_need integer; v_take integer; v_plan uuid; v_head smallint;
begin
  select * into l from public.credit_ledger where id = p_ledger;
  if not found then return; end if;

  -- ☢️ 轉讓：堂數換主人，沒有用掉。方案的 owner 由 transfer_plan() 直接改。
  if l.reason in ('transfer_out','transfer_in') then return; end if;

  if exists (select 1 from public.plans      where ledger_id = p_ledger) then return; end if;
  if exists (select 1 from public.plan_draws where ledger_id = p_ledger) then return; end if;

  if l.reason = 'purchase' and l.delta > 0 then
    select pr.headcount into v_head from public.products pr where pr.code = l.product_code;
    insert into public.plans (
      ledger_id, product, product_code, headcount,
      total_credits, paid_amount, per_credit, basis_status,
      owner_customer_id, origin_customer_id, opened_at, note)
    values (
      p_ledger, l.product, l.product_code, v_head,
      l.delta, l.amount,
      case when l.amount is not null and l.delta > 0
           then round(l.amount::numeric / l.delta, 4) end,
      case when l.amount is not null then 'ok' else 'pending' end,
      l.customer_id, l.customer_id, l.created_at, l.note);
    return;
  end if;

  if l.delta > 0 then
    v_need := l.delta;
    if l.booking_id is not null then
      for r in
        select d.plan_id, sum(d.credits) as c
        from public.plan_draws d
        join public.credit_ledger cl on cl.id = d.ledger_id
        where cl.booking_id = l.booking_id
        group by d.plan_id having sum(d.credits) > 0
        order by 2 desc
      loop
        exit when v_need <= 0;
        v_take := least(v_need, r.c);
        insert into public.plan_draws (plan_id, ledger_id, credits)
        values (r.plan_id, p_ledger, -v_take)
        on conflict (plan_id, ledger_id) do update set credits = plan_draws.credits - v_take;
        v_need := v_need - v_take;
      end loop;
    end if;
    if v_need > 0 then
      select id into v_plan from public.plans
       where owner_customer_id = l.customer_id and product = l.product
       order by opened_at desc, id desc limit 1;
      if v_plan is not null then
        insert into public.plan_draws (plan_id, ledger_id, credits)
        values (v_plan, p_ledger, -v_need)
        on conflict (plan_id, ledger_id) do update set credits = plan_draws.credits - v_need;
      end if;
    end if;
    return;
  end if;

  v_need := -l.delta;
  for r in
    select ps.id, ps.remaining from public.plan_state ps
    where ps.owner_customer_id = l.customer_id and ps.product = l.product and ps.remaining > 0
    order by ps.opened_at, ps.id
  loop
    exit when v_need <= 0;
    v_take := least(v_need, r.remaining);
    insert into public.plan_draws (plan_id, ledger_id, credits)
    values (r.id, p_ledger, v_take)
    on conflict (plan_id, ledger_id) do update set credits = plan_draws.credits + v_take;
    v_need := v_need - v_take;
  end loop;

  if v_need > 0 then
    select id into v_plan from public.plans
     where owner_customer_id = l.customer_id and product = l.product
     order by opened_at desc, id desc limit 1;
    if v_plan is null then
      insert into public.plans (
        ledger_id, product, total_credits, basis_status,
        owner_customer_id, origin_customer_id, opened_at, note)
      values (null, l.product, 0, 'pending', l.customer_id, l.customer_id, l.created_at,
              '☢️ 系統補開：這個人有銷課，但找不到任何購課紀錄')
      returning id into v_plan;
    end if;
    insert into public.plan_draws (plan_id, ledger_id, credits)
    values (v_plan, p_ledger, v_need)
    on conflict (plan_id, ledger_id) do update set credits = plan_draws.credits + v_need;
  end if;
end $fn$;

-- ── ③ 分享額度不能因為轉讓而變多 ────────────────────────────
-- ☢️ 額度是「每【拿到】12 堂給 2 次」。轉入也是正的 delta ——
--    不排除的話，同一批堂數會在原主人和新主人身上【各算一次額度】。
--    原主人的轉出是負的，本來就不影響他的額度，所以只要擋轉入。
--
-- ☢️ 已知的簡化：規則文件說轉讓要「承接 GT 已使用分享次數」。
--    現在的做法是【新主人拿不到這批堂數的分享額度】（比較嚴），
--    而不是「承接已用幾次再給剩下的」。
--    目前為止一次轉讓都還沒發生過，等真的要用時再做完整的承接。
--    ☢️ 轉讓當下的已用次數有記在 plan_transfers.shares_used_at_transfer，資料不會流失。
create or replace function public.gt_share_quota(p_customer uuid)
returns integer
language sql stable security definer set search_path = public as $fn$
  select (floor(coalesce(sum(delta), 0) / 12.0) * 2)::integer
  from public.credit_ledger
  where customer_id = p_customer
    and product = 'GT'
    and delta > 0
    and reason <> 'transfer_in';
$fn$;

comment on function public.gt_share_quota(uuid) is
  '可以分享幾堂＝floor(累計拿到的堂數 / 12) × 2。☢️ 不含轉讓進來的 —— 否則同一批堂數會被算兩次額度。';

-- ── ④ 轉讓紀錄 ──────────────────────────────────────────────
create table if not exists public.plan_transfers (
  id                uuid primary key default gen_random_uuid(),
  plan_id           uuid not null references public.plans(id) on delete restrict,
  from_customer_id  uuid not null references public.customers(id) on delete restrict,
  to_customer_id    uuid not null references public.customers(id) on delete restrict,
  credits           integer not null check (credits > 0),
  -- 轉讓當下這張方案已經用掉幾次分享。☢️ 留著，以後要做「承接」時用得到。
  shares_used_at_transfer smallint not null default 0,
  approver_id       uuid references public.employees(id),
  transferred_at    timestamptz not null default now(),
  note              text,
  out_ledger_id     uuid references public.credit_ledger(id),
  in_ledger_id      uuid references public.credit_ledger(id),
  created_by        uuid references public.employees(id)
);

comment on table public.plan_transfers is
  '課程轉讓紀錄：原擁有人、新擁有人、日期、核准人、方案 ID。☢️ 方案 ID 不變，只換擁有人。';

alter table public.plan_transfers enable row level security;
drop policy if exists "職員看得到轉讓紀錄" on public.plan_transfers;
create policy "職員看得到轉讓紀錄" on public.plan_transfers
  for select using (public.is_staff());
grant select on public.plan_transfers to authenticated;

-- ── ⑤ 轉讓 ──────────────────────────────────────────────────
create or replace function public.transfer_plan(
  p_plan uuid, p_to uuid, p_approver uuid default null, p_note text default null)
returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  ps       record;
  v_from   record;
  v_to     record;
  v_kind   text;
  v_out    uuid;
  v_in     uuid;
  v_me     uuid;
begin
  -- ☢️ 只有財務。轉一張 12 堂的方案＝把 NT$4,000 的權益換人，
  --    那不該是任何一位教練按一下就能做的事。
  if not public.is_finance() then
    raise exception '只有財務可以做課程轉讓';
  end if;
  v_me := public.my_employee_id();

  select * into ps from public.plan_state where id = p_plan;
  if not found then
    return jsonb_build_object('ok', false, 'why', 'no_plan', 'msg', '找不到這張方案');
  end if;

  -- PGT 不可轉讓
  if ps.product = 'PGT' then
    return jsonb_build_object('ok', false, 'why', 'pgt',
      'msg', 'PGT 不可轉讓（規則文件第二篇 5）');
  end if;
  if ps.product not in ('GT','PT') then
    return jsonb_build_object('ok', false, 'why', 'product',
      'msg', '只有 PT 預付與 GT 預付可以轉讓');
  end if;

  -- 單堂不是「預付課程」
  select kind into v_kind from public.products where code = ps.product_code;
  if v_kind = 'single' then
    return jsonb_build_object('ok', false, 'why', 'single',
      'msg', '單堂課程不能轉讓 —— 可轉讓的是預付課程');
  end if;

  if ps.remaining <= 0 then
    return jsonb_build_object('ok', false, 'why', 'empty',
      'msg', '這張方案沒有剩餘堂數了');
  end if;

  select id, name, is_active into v_from from public.customers where id = ps.owner_customer_id;
  select id, name, is_active into v_to   from public.customers where id = p_to;
  if v_to.id is null then
    return jsonb_build_object('ok', false, 'why', 'no_customer', 'msg', '找不到接收的客人');
  end if;
  if v_to.is_active = false then
    return jsonb_build_object('ok', false, 'why', 'inactive', 'msg', '接收的客人已停用');
  end if;
  if v_to.id = v_from.id then
    return jsonb_build_object('ok', false, 'why', 'same', 'msg', '轉給同一個人沒有意義');
  end if;

  -- ☢️ 轉出／轉入金額都是 0（amount 留 null）——
  --    規則文件：轉讓事件金額為 0 元，不產生新收入或新業績。
  insert into public.credit_ledger
    (customer_id, delta, reason, product, note, created_by)
  values (v_from.id, -ps.remaining, 'transfer_out', ps.product,
          '轉出給 ' || v_to.name || coalesce('（' || nullif(btrim(p_note),'') || '）', ''), v_me)
  returning id into v_out;

  insert into public.credit_ledger
    (customer_id, delta, reason, product, note, created_by)
  values (v_to.id, ps.remaining, 'transfer_in', ps.product,
          '由 ' || v_from.name || ' 轉入' || coalesce('（' || nullif(btrim(p_note),'') || '）', ''), v_me)
  returning id into v_in;

  -- ☢️ 沿用同一個方案 ID，只換擁有人。不建立新方案。
  update public.plans set owner_customer_id = v_to.id where id = p_plan;

  insert into public.plan_transfers
    (plan_id, from_customer_id, to_customer_id, credits, shares_used_at_transfer,
     approver_id, note, out_ledger_id, in_ledger_id, created_by)
  values (p_plan, v_from.id, v_to.id, ps.remaining, ps.shares_used,
          p_approver, nullif(btrim(p_note),''), v_out, v_in, v_me);

  return jsonb_build_object('ok', true, 'plan_id', p_plan,
    'credits', ps.remaining, 'from', v_from.name, 'to', v_to.name);
end $fn$;

revoke all on function public.transfer_plan(uuid, uuid, uuid, text) from public;
grant execute on function public.transfer_plan(uuid, uuid, uuid, text) to authenticated;

-- ── ⑥ 給畫面用的方案清單 ────────────────────────────────────
create or replace view public.staff_plans as
select ps.id,
       ps.product,
       ps.product_code,
       pr.label                      as product_label,
       pr.kind                       as product_kind,
       ps.total_credits,
       ps.used_credits,
       ps.remaining,
       ps.paid_amount,
       ps.per_credit,
       ps.basis_status,
       ps.opened_at,
       (ps.opened_at at time zone 'Asia/Taipei')::date as opened_on,
       ps.owner_customer_id,
       ow.name                       as owner_name,
       right(ow.phone, 3)            as owner_tail,
       ps.origin_customer_id,
       og.name                       as origin_name,
       (ps.origin_customer_id <> ps.owner_customer_id) as transferred,
       ps.shares_used,
       ps.note
from public.plan_state ps
join public.customers ow on ow.id = ps.owner_customer_id
join public.customers og on og.id = ps.origin_customer_id
left join public.products pr on pr.code = ps.product_code
where public.is_staff();

comment on view public.staff_plans is '方案清單（給後台選要轉讓哪一張用）。☢️ definer，不要加 security_invoker。';
grant select on public.staff_plans to authenticated;
