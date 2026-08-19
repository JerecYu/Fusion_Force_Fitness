-- ============================================================
-- 45 · 方案（plan）—— 轉讓、逐堂認列、分享次數的共同前置
--
-- 規則文件（正式補全版）要的東西，全部指向同一個缺口：
--   第二篇 1.4　「該筆已確認實收總額 ÷ 固定堂數」＝ 每堂業績基礎
--   第二篇 1.3　GT 每堂收入基準 333.33 元（＝4,000 ÷ 12）
--   第二篇 5 　 轉讓要「沿用同一方案 ID、承接剩餘堂數與已使用分享次數」
--   第六篇 4 　 共用結算紀錄要有「原交易／方案 ID」
--
-- 現在的 credit_ledger 是一本流水帳：買 +12、上課 −1，只有【餘額】。
-- 「一張方案、剩幾堂、誰擁有、每堂業績基礎多少」這些都不是獨立的東西。
--
-- ══ 動手前先盤點（2026-08-19 實測）══
--   購課紀錄 97 筆，其中【93 筆是搬遷進來的期初餘額】——
--     沒有 product_code、沒有金額，堂數從 1 到 44 都有。
--     真正走系統買的只有 4 筆（3 × GT-12、1 × GT-1）。
--   ☢️ 所以那 93 張方案【算不出每堂業績基礎】。
--      規則文件第三篇 4 對這種狀況寫得很清楚：
--      「資料不足時維持待確認並暫停自動計薪」—— 不是用檯面價補算。
--      → basis_status 標 pending，不猜。
--
--   78 人有購課紀錄：60 人 1 筆、17 人 2 筆、1 人 3 筆。
--   4 人餘額是負的（最低 −2），3 人有銷課但完全沒有購課紀錄。
--   ☢️ 這兩種都要能表達，不能假設「餘額一定 ≥ 0」。
--
-- ══ 設計：方案是容器，帳本仍然是唯一的餘額來源 ══
--   plans        一張方案（多半就是一筆收款）
--   plan_draws   哪一筆帳本紀錄、從哪一張方案、扣了幾堂
--
--   ☢️ credit_ledger【一個欄位都沒動】。對帳報表、購課、點名全部照舊。
--      方案是【疊上去】的，不是取代 —— 這樣萬一方案算錯，錢還是對的。
--
--   ☢️ 用 plan_draws 而不是在帳本上加一個 plan_id：
--      一筆扣款可能跨兩張方案（舊方案剩 1 堂、這次要扣 2 堂）。
--      硬塞一個 plan_id 就得把帳本那一列拆成兩列 ——
--      而拆列會動到已經在跑的對帳報表。
-- ============================================================

-- ── ① 方案 ──────────────────────────────────────────────────
create table if not exists public.plans (
  id            uuid primary key default gen_random_uuid(),

  -- 這張方案是哪一筆收款生出來的。☢️ null＝系統補開的（見下面第 ④ 段）
  ledger_id     uuid unique references public.credit_ledger(id) on delete restrict,

  product       text not null,
  product_code  text references public.products(code),
  headcount     smallint,                    -- 人數規格（轉讓要沿用）

  -- ☢️ 允許 0：有人銷課但完全沒有購課紀錄，得補一張 0 堂的方案才記得住。
  total_credits integer not null check (total_credits >= 0),
  paid_amount   integer check (paid_amount is null or paid_amount >= 0),

  -- 每堂業績基礎＝實收 ÷ 固定堂數。
  -- ☢️ 存 4 位小數不存 2 位：4,000 ÷ 12 ＝ 333.3333…，
  --    存成 333.33 的話 12 堂會少 0.04 元。
  --    規則文件第六篇 1：「每筆計算保留原始精度…不得逐筆取整」——
  --    取整是【月結小計】才做的事。
  per_credit    numeric(12,4) check (per_credit is null or per_credit >= 0),
  basis_status  text not null default 'pending' check (basis_status in ('ok','pending')),

  owner_customer_id  uuid not null references public.customers(id) on delete restrict,
  origin_customer_id uuid not null references public.customers(id) on delete restrict,

  shares_used   smallint not null default 0 check (shares_used >= 0),

  opened_at     timestamptz not null,
  note          text,
  created_at    timestamptz not null default now()
);

comment on table public.plans is
  '一張方案＝一筆收款帶來的一組堂數。轉讓時沿用同一個 id，只換 owner_customer_id。';
comment on column public.plans.per_credit is
  '每堂業績基礎＝實收 ÷ 固定堂數。☢️ 搬遷進來的舊帳算不出來，會是 null（basis_status = pending）。';
comment on column public.plans.origin_customer_id is
  '原始擁有人。☢️ 轉讓之後 owner 會變，這一欄不變 —— 規則文件要求保留原擁有人。';

create index if not exists plans_owner on public.plans (owner_customer_id, product, opened_at);

-- ── ② 誰從哪張方案扣了幾堂 ──────────────────────────────────
create table if not exists public.plan_draws (
  id         uuid primary key default gen_random_uuid(),
  plan_id    uuid not null references public.plans(id) on delete cascade,
  ledger_id  uuid not null references public.credit_ledger(id) on delete cascade,
  -- 正＝用掉、負＝退回（點名改成缺席會退）
  credits    integer not null,
  created_at timestamptz not null default now(),
  unique (plan_id, ledger_id)
);

comment on table public.plan_draws is
  '帳本的每一筆異動，是從哪一張方案上扣的。☢️ 一筆可以跨兩張方案，所以是獨立一張表。';

create index if not exists plan_draws_ledger on public.plan_draws (ledger_id);

-- ── ③ 方案的現況 ────────────────────────────────────────────
create or replace view public.plan_state as
select p.id, p.ledger_id, p.product, p.product_code, p.headcount,
       p.total_credits, p.paid_amount, p.per_credit, p.basis_status,
       p.owner_customer_id, p.origin_customer_id, p.shares_used,
       p.opened_at, p.note,
       coalesce(d.used, 0)                    as used_credits,
       p.total_credits - coalesce(d.used, 0)  as remaining
from public.plans p
left join lateral (
  select sum(credits) as used from public.plan_draws where plan_id = p.id) d on true;

comment on view public.plan_state is '方案 ＋ 已用幾堂 ＋ 剩幾堂。☢️ remaining 可能是負的（超支）。';

-- ── ④ 配堂數 ────────────────────────────────────────────────
-- 帳本每進一筆，就決定它動到哪一張方案。
-- ☢️ 回填舊資料和以後的新資料【走同一支函式】——
--    分成兩套的話，回填出來的結果跟以後跑出來的會不一樣，而且不會有人發現。
create or replace function public.plan_allocate(p_ledger uuid)
returns void
language plpgsql security definer set search_path = public as $fn$
declare
  l       record;
  r       record;
  v_need  integer;
  v_take  integer;
  v_plan  uuid;
  v_head  smallint;
begin
  select * into l from public.credit_ledger where id = p_ledger;
  if not found then return; end if;

  -- 已經配過就跳過。☢️ 這一行讓回填可以重跑而不會配兩次。
  if exists (select 1 from public.plans      where ledger_id = p_ledger) then return; end if;
  if exists (select 1 from public.plan_draws where ledger_id = p_ledger) then return; end if;

  -- ── ④-1 收款 → 開一張方案 ──
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

  -- ── ④-2 退回（正數、但不是收款）──
  -- 例：點名從出席改成缺席，會補一筆 +1 把堂數還回去。
  -- ☢️ 要還到【當初扣的那張方案】，不能隨便找一張還 ——
  --    還錯方案的話，兩張方案的剩餘都會是錯的，加起來卻剛好對，很難發現。
  if l.delta > 0 then
    v_need := l.delta;
    if l.booking_id is not null then
      for r in
        select d.plan_id, sum(d.credits) as c
        from public.plan_draws d
        join public.credit_ledger cl on cl.id = d.ledger_id
        where cl.booking_id = l.booking_id
        group by d.plan_id
        having sum(d.credits) > 0
        order by 2 desc
      loop
        exit when v_need <= 0;
        v_take := least(v_need, r.c);
        insert into public.plan_draws (plan_id, ledger_id, credits)
        values (r.plan_id, p_ledger, -v_take)
        on conflict (plan_id, ledger_id)
        do update set credits = plan_draws.credits - v_take;
        v_need := v_need - v_take;
      end loop;
    end if;

    -- 找不到原路（沒有 booking_id，或當初就沒扣過）→ 還到最新的那張
    if v_need > 0 then
      select id into v_plan from public.plans
       where owner_customer_id = l.customer_id and product = l.product
       order by opened_at desc, id desc limit 1;
      if v_plan is not null then
        insert into public.plan_draws (plan_id, ledger_id, credits)
        values (v_plan, p_ledger, -v_need)
        on conflict (plan_id, ledger_id)
        do update set credits = plan_draws.credits - v_need;
      end if;
    end if;
    return;
  end if;

  -- ── ④-3 用掉（負數）── 先進先出
  v_need := -l.delta;
  for r in
    select ps.id, ps.remaining
    from public.plan_state ps
    where ps.owner_customer_id = l.customer_id
      and ps.product = l.product
      and ps.remaining > 0
    order by ps.opened_at, ps.id
  loop
    exit when v_need <= 0;
    v_take := least(v_need, r.remaining);
    insert into public.plan_draws (plan_id, ledger_id, credits)
    values (r.id, p_ledger, v_take)
    on conflict (plan_id, ledger_id)
    do update set credits = plan_draws.credits + v_take;
    v_need := v_need - v_take;
  end loop;

  -- 還扣不完 → 記在最新的方案上，那張的剩餘會變負數。
  -- ☢️ 這不是錯誤，是照實記：這個人超支了（實測有 4 位，最低 −2）。
  if v_need > 0 then
    select id into v_plan from public.plans
     where owner_customer_id = l.customer_id and product = l.product
     order by opened_at desc, id desc limit 1;

    -- 完全沒有方案的人（實測 3 位：有銷課、沒有任何購課紀錄）
    if v_plan is null then
      insert into public.plans (
        ledger_id, product, total_credits, basis_status,
        owner_customer_id, origin_customer_id, opened_at, note)
      values (
        null, l.product, 0, 'pending',
        l.customer_id, l.customer_id, l.created_at,
        '☢️ 系統補開：這個人有銷課，但找不到任何購課紀錄')
      returning id into v_plan;
    end if;

    insert into public.plan_draws (plan_id, ledger_id, credits)
    values (v_plan, p_ledger, v_need)
    on conflict (plan_id, ledger_id)
    do update set credits = plan_draws.credits + v_need;
  end if;
end $fn$;

-- ── ⑤ 以後每一筆帳本紀錄都自動配 ────────────────────────────
-- ☢️ 做成 trigger 而不是改 check_in()：
--    check_in 是每天在跑的、動到錢的函式，能不碰就不碰。
--    而且 trigger 守的是【這張表】—— 購課、點名、沖銷、以後的匯入，
--    不管哪條路進來都會配到方案。
create or replace function public.trg_plan_allocate()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  perform public.plan_allocate(new.id);
  return null;
end $fn$;

drop trigger if exists credit_ledger_plan_alloc on public.credit_ledger;
create trigger credit_ledger_plan_alloc
  after insert on public.credit_ledger
  for each row execute function public.trg_plan_allocate();

-- ── ⑥ 權限 ──────────────────────────────────────────────────
alter table public.plans      enable row level security;
alter table public.plan_draws enable row level security;

drop policy if exists "職員看得到方案" on public.plans;
create policy "職員看得到方案" on public.plans for select using (public.is_staff());

drop policy if exists "職員看得到配堂" on public.plan_draws;
create policy "職員看得到配堂" on public.plan_draws for select using (public.is_staff());

grant select on public.plans      to authenticated;
grant select on public.plan_draws to authenticated;
grant select on public.plan_state to authenticated;

-- ── ⑦ 回填 ＋ 對帳 ──────────────────────────────────────────
-- ☢️ 照時間順序一筆一筆配，跟以後 trigger 做的完全一樣。
-- ☢️ 配完【立刻對帳】：每個人的方案剩餘加起來，必須跟帳本餘額一模一樣。
--    對不上就整批回捲 —— 寧可不上線，也不要上線之後才發現堂數對不起來。
-- ☢️☢️ 分【兩趟】跑：先把所有收款變成方案，再配銷課。
--    第一版只跑一趟（照時間順序），結果被搬遷資料的時間戳記騙了 ——
--    有人的期初餘額是 8/17 才登進系統，但他 8/03 就上過課。
--    一趟跑的話，處理 8/03 那筆時方案還不存在，就補開一張「沒有購課紀錄」的空方案，
--    8/17 再開一張正常的 —— 同一個人身上出現一張 −2、一張 +11。
--    加起來是對的，所以【對帳檢查抓不到】，但看起來就是壞的。
--    ☢️ 只有 trigger 走的是真實時序（買一定在用之前），回填不是。
do $$
declare r record; v_bad integer;
begin
  for r in select id from public.credit_ledger
            where reason = 'purchase' and delta > 0
            order by created_at, id loop
    perform public.plan_allocate(r.id);
  end loop;

  for r in select id from public.credit_ledger
            where not (reason = 'purchase' and delta > 0)
            order by created_at, id loop
    perform public.plan_allocate(r.id);
  end loop;

  select count(*) into v_bad from (
    select l.customer_id, l.product,
           sum(l.delta) as ledger_bal,
           coalesce((select sum(ps.remaining) from public.plan_state ps
                      where ps.owner_customer_id = l.customer_id
                        and ps.product = l.product), 0) as plan_bal
    from public.credit_ledger l
    group by l.customer_id, l.product
  ) x where x.ledger_bal <> x.plan_bal;

  if v_bad > 0 then
    raise exception '☢️ 回填後有 % 個人的餘額對不上帳本，整批回捲', v_bad;
  end if;

end $$;

-- ── ⑧ 給人看的對帳檢視表 ────────────────────────────────────
create or replace view public.staff_plan_check as
select c.id                                   as customer_id,
       c.name                                 as customer_name,
       right(c.phone, 3)                      as phone_tail,
       l.product,
       sum(l.delta)::int                      as ledger_balance,
       coalesce(ps.plan_balance, 0)::int      as plan_balance,
       coalesce(ps.n_plans, 0)::int           as n_plans,
       coalesce(ps.n_pending, 0)::int         as n_pending_basis,
       (sum(l.delta)::int = coalesce(ps.plan_balance, 0)::int) as ok
from public.credit_ledger l
join public.customers c on c.id = l.customer_id
left join lateral (
  select sum(remaining) as plan_balance, count(*) as n_plans,
         count(*) filter (where basis_status = 'pending') as n_pending
  from public.plan_state
  where owner_customer_id = l.customer_id and product = l.product) ps on true
where public.is_staff()
group by c.id, c.name, c.phone, l.product, ps.plan_balance, ps.n_plans, ps.n_pending;

comment on view public.staff_plan_check is
  '每個人的「帳本餘額」對「方案剩餘」。☢️ ok 只要有一筆是 false，方案結構就有問題。';

grant select on public.staff_plan_check to authenticated;
