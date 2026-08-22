-- ═══════════════════════════════════════════════════════════════════
-- db/65-plan-pick.sql — 扣堂的時候【指定哪一張卡】
--
-- 專案：FFF 預約系統（fff-platform）· 第 93 步之一 · 2026-08-22
--
-- ══ 為什麼要有這一欄 ═════════════════════════════════════════════
-- ☢️☢️ <code>plan_allocate</code> 現在扣堂是【用猜的】：
--    「同一位客人、同一個產品別、最舊的那一張，先扣」。
--    GT 只有一種卡，猜得對。
--    私人課不是 —— 一位客人可以同時有【一對一】和【一對二】兩張，
--    而兩張的每堂價值完全不同（實收總額 ÷ 固定堂數）。
--    猜錯張 → 這一堂的業績金額錯 → 抽成錯 → 【薪水錯】，
--    而且畫面上完全正常，沒有任何地方會報錯。
--
-- ☢️ 解法不是把猜的邏輯寫得更聰明（例如再比對人數）。
--    「再多比一個條件」只是把猜錯的機率變小，不是消除 ——
--    同一個人有兩張一對一的舊卡時照樣會猜。
--    真正的解法是【讓人在登記的當下直接指定】：
--    登記服務的人看得到那一堂上的是什麼，他知道要扣哪一張。
--    猜測本身才是問題。
--
-- ══ 語意 ═════════════════════════════════════════════════════════
--   credit_ledger.plan_id = null → 照舊（GT 走這條，行為完全不變）
--   credit_ledger.plan_id 有值   → 【只從這一張扣／退】，不再猜
--
-- ☢️ 指定了卻不是這位客人的卡 → 直接丟例外，不是默默改用猜的。
--    默默降級會讓「指定錯了」看起來像成功。
-- ☢️ 購課不能指定 —— 購課是【開一張新的卡】，不是從舊卡扣。
--    傳了就是程式寫錯，當場擋下來。
--
-- ☢️ 剩 0 堂的卡【不擋】。修正舊帳的時候需要把卡扣成負的，
--    而「這張卡透支了」是看得見的（staff_customer_plans.remaining 是負數），
--    擋下來反而會讓人找不到路把帳修對。
--    要不要提醒是【登記畫面】的事，不是這裡的事。
-- ═══════════════════════════════════════════════════════════════════

alter table public.credit_ledger
  add column if not exists plan_id uuid references public.plans(id);

comment on column public.credit_ledger.plan_id is
  '這一筆要從【哪一張方案】扣／退。null ＝ 照舊由 plan_allocate 自己找（GT 走這條）。'
  '☢️ 私人課一定要指定 —— 一對一和一對二的每堂價值不同，猜錯張薪水就錯。';

create index if not exists credit_ledger_plan_idx on public.credit_ledger (plan_id)
  where plan_id is not null;


-- ── 配方案：指定的優先，沒指定才照舊 ───────────────────────────
create or replace function public.plan_allocate(p_ledger uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  l record; r record;
  v_need integer; v_take integer; v_plan uuid; v_head smallint;
begin
  select * into l from public.credit_ledger where id = p_ledger;
  if not found then return; end if;

  if l.reason in ('transfer_out','transfer_in') then return; end if;

  -- 已經配過就不要再配一次（觸發程序可能被重放）
  if exists (select 1 from public.plans      where ledger_id = p_ledger) then return; end if;
  if exists (select 1 from public.plan_draws where ledger_id = p_ledger) then return; end if;

  -- ══ ☢️ 有指定方案：照指定的做，不猜 ═══════════════════════════
  if l.plan_id is not null then
    if l.reason = 'purchase' and l.delta > 0 then
      raise exception '購課不可以指定方案 —— 購課是開一張新的卡，不是從舊卡扣';
    end if;
    if not exists (select 1 from public.plans
                    where id = l.plan_id and owner_customer_id = l.customer_id) then
      -- ☢️ 不要默默改用猜的。默默降級會讓「指定錯了」看起來像成功。
      raise exception '指定的方案不是這位客人的（ledger %）', p_ledger;
    end if;
    insert into public.plan_draws (plan_id, ledger_id, credits)
    values (l.plan_id, p_ledger, -l.delta)
    on conflict (plan_id, ledger_id) do update set credits = plan_draws.credits - l.delta;
    return;
  end if;

  -- ══ 以下完全是舊行為（GT 走這條）═════════════════════════════
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
    -- 取消預約：退回原本那幾堂是從哪幾張扣的
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


-- ── 調整堂數：改成把方案寫進帳本，不再事後搬 plan_draws ─────────
-- ☢️ 原本是「先讓觸發程序自己配，再把 plan_draws 搬過去」。
--    那是兩步，中間那一瞬間帳是錯的，而且搬的邏輯散在兩個地方。
--    現在方案直接寫進 credit_ledger，觸發程序一次就配對。
create or replace function public.adjust_credits(
  p_customer uuid,
  p_delta    integer,
  p_why      text,
  p_product  text default 'GT',
  p_plan     uuid default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_name text; v_before int; v_after int; v_id uuid; v_why text;
  v_plan_ok boolean; v_landed jsonb;
begin
  if not public.is_finance() then
    raise exception '只有負責人和財務可以調整堂數';
  end if;

  select name into v_name from public.customers where id = p_customer;
  if v_name is null then
    return jsonb_build_object('ok', false, 'why', 'not_found', 'msg', '找不到這位客人');
  end if;

  if coalesce(p_delta, 0) = 0 then
    return jsonb_build_object('ok', false, 'why', 'zero', 'msg', '要加或要扣幾堂？0 沒有意義');
  end if;
  if abs(p_delta) > 50 then
    return jsonb_build_object('ok', false, 'why', 'too_big',
      'msg', format('一次最多 50 堂，你輸入的是 %s —— 確認一下是不是多打了一個 0', p_delta));
  end if;

  v_why := btrim(coalesce(p_why, ''));
  if char_length(v_why) < 4 then
    return jsonb_build_object('ok', false, 'why', 'no_reason',
      'msg', '理由至少要四個字，而且要寫得出「為什麼」——「修正」「調整」不算理由');
  end if;
  -- ☢️ 擋掉等於沒寫的理由。三個月後看到「調整」兩個字，查不出任何東西。
  if v_why in ('修正一下','調整一下','資料調整','堂數調整','系統調整','手動調整') then
    return jsonb_build_object('ok', false, 'why', 'lazy_reason',
      'msg', '這個理由等於沒寫。要寫得出是哪一堂課、哪一天、為什麼 —— 例如「2026-07-31 Jessica 交叉肌力訓練課後漏扣」');
  end if;

  if p_plan is not null then
    select true into v_plan_ok from public.plans
     where id = p_plan and owner_customer_id = p_customer;
    if not coalesce(v_plan_ok, false) then
      return jsonb_build_object('ok', false, 'why', 'bad_plan',
        'msg', '指定的方案不是這位客人的');
    end if;
  end if;

  select coalesce(sum(delta), 0) into v_before
    from public.credit_ledger where customer_id = p_customer;

  insert into public.credit_ledger
    (customer_id, delta, reason, note, product, plan_id, created_by)
  values (p_customer, p_delta, 'adjust', v_why, coalesce(p_product, 'GT'),
          p_plan, public.my_employee_id())
  returning id into v_id;

  select coalesce(sum(delta), 0) into v_after
    from public.credit_ledger where customer_id = p_customer;

  select coalesce(jsonb_agg(jsonb_build_object(
           'plan', left(d.plan_id::text, 8), 'credits', d.credits,
           'plan_note', coalesce(p.note, ''))), '[]'::jsonb)
    into v_landed
  from public.plan_draws d join public.plans p on p.id = d.plan_id
  where d.ledger_id = v_id;

  return jsonb_build_object('ok', true, 'id', v_id, 'name', v_name,
    'delta', p_delta, 'before', v_before, 'after', v_after,
    'negative', v_after < 0, 'landed', v_landed);
end $fn$;

revoke all on function public.adjust_credits(uuid, integer, text, text, uuid) from public, anon;
grant execute on function public.adjust_credits(uuid, integer, text, text, uuid) to authenticated;
