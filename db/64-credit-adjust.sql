-- ═══════════════════════════════════════════════════════════════════
-- db/64-credit-adjust.sql — 調整堂數
--
-- 專案：FFF 預約系統（fff-platform）· 修補 · 2026-08-22
--
-- 起因：2026-08-21 Jerec 回報兩筆舊帳要修（團課扣錯人、課後漏扣），
--   而我在查的時候發現一件事 ——
--   ☢️ 【系統完全沒有「調整堂數」這個功能】。
--   credit_ledger 裡確實有 reason='adjust' 的資料，但那些是
--   import_legacy_credits（搬遷）和 void_purchase（沖銷購課）寫的，
--   沒有任何一支函式能讓人手動加減一堂。
--   結果就是：扣錯一堂 → 只能找工程師下 SQL。
--   那不是「偶爾」會發生，是每個月都會發生。
--
-- ══ 為什麼是財務限定 ═══════════════════════════════════════════
-- ☢️ 一堂等於錢。教練可以點名核銷（那有課次與名單背書），
--    但「憑空加一堂／扣一堂」沒有任何東西背書 —— 只有理由。
--    所以跟薪資、對帳、支出簿同一道牆：is_finance()。
--
-- ══ 為什麼一定要寫理由 ═════════════════════════════════════════
-- ☢️ 這支函式留下的痕跡【只有 note 這一欄】。沒寫理由的調整，
--    三個月後看到的是「有人在某天加了一堂」，查不出為什麼，
--    也分不出是修正還是誤操作。
--    所以理由是必填，而且擋掉「修」「調整」這種等於沒寫的字。
--
-- ══ 方案要跟著動 ═══════════════════════════════════════════════
-- ☢️ credit_ledger 有一個 AFTER INSERT 觸發程序（plan_allocate），
--    插進去之後方案那一側會自動跟上，所以不會出現
--    「帳本餘額 ≠ 方案剩餘」（staff_plan_check 會抓的那種）。
-- ☢️ 但【加回堂數時它會放到「最新的那張方案」】。
--    修正通常要放回「當初扣錯的那一張」，所以開一個 p_plan 讓人指定；
--    不指定就照預設走。
--
-- ══ 上限 ═══════════════════════════════════════════════════════
-- ☢️ 一次最多 ±50 堂。不是因為 51 堂不合理，
--    是因為【多打一個 0】比「真的要調 500 堂」常見太多。
--    真的需要大量調整的，那是匯入，不是調整。
-- ═══════════════════════════════════════════════════════════════════

create or replace function public.adjust_credits(
  p_customer uuid,
  p_delta    integer,
  p_why      text,
  p_product  text default 'GT',
  p_plan     uuid default null      -- 指定加減到哪一張方案（不給就用預設）
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

  -- 指定方案的話，要真的是這位客人的
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

  insert into public.credit_ledger (customer_id, delta, reason, note, product, created_by)
  values (p_customer, p_delta, 'adjust', v_why, coalesce(p_product, 'GT'), public.my_employee_id())
  returning id into v_id;

  -- ☢️ 觸發程序已經把方案那一側配好了。指定方案的話改放到指定的那張。
  if p_plan is not null then
    update public.plan_draws set plan_id = p_plan where ledger_id = v_id;
  end if;

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
    -- ☢️ 調成負的不擋（修正過程中可能先扣後補），但要講出來
    'negative', v_after < 0, 'landed', v_landed);
end $fn$;

revoke all on function public.adjust_credits(uuid, integer, text, text, uuid) from public, anon;
grant execute on function public.adjust_credits(uuid, integer, text, text, uuid) to authenticated;

comment on function public.adjust_credits(uuid, integer, text, text, uuid) is
  '手動加減堂數。財務限定、理由必填（至少四個字，而且擋掉「調整一下」這種）。'
  '方案那一側靠 credit_ledger 的觸發程序自動跟上；p_plan 可以指定加減到哪一張。';


-- ── 這位客人的方案清單（調整時要選哪一張）─────────────────────
create or replace view public.staff_customer_plans as
select
  p.id                as plan_id,
  p.owner_customer_id as customer_id,
  c.name              as customer_name,
  right(c.phone, 3)   as phone_tail,
  p.product,
  coalesce(p.product_code, '')                                as product_code,
  p.total_credits,
  coalesce((select sum(d.credits) from public.plan_draws d where d.plan_id = p.id), 0)::int as used_credits,
  (p.total_credits
     - coalesce((select sum(d.credits) from public.plan_draws d where d.plan_id = p.id), 0))::int as remaining,
  p.basis_status,
  coalesce(p.note, '') as note,
  p.opened_at
from public.plans p
join public.customers c on c.id = p.owner_customer_id
where public.is_staff();

grant select on public.staff_customer_plans to authenticated;

comment on view public.staff_customer_plans is
  '每個人手上有哪幾張方案、各剩幾堂。調整堂數要選方案時用這一張。'
  'remaining 是負的，代表那張方案被扣的比買的多 —— 通常是搬遷或扣錯人留下的。';
