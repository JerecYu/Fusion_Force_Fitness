-- ═══════════════════════════════════════════════════════════════════
-- db/69-sell-cards.sql — 購課頁開放賣私人課的預付卡
--
-- 專案：FFF 預約系統（fff-platform）· 第 93 步之三 · 2026-08-22
--
-- 起因：購課頁寫死 `.eq('product','GT')`，所以【賣不出私人課的卡】。
--   第 93 步之二（db/68）已經讓「扣預收」真的扣得動，
--   但沒有卡可以扣 —— 全店 0 張 PT 卡，因為根本沒有地方開卡。
--
-- ══ ☢️ 為什麼不是把 GT 那個條件拿掉就好 ═════════════════════════
-- ☢️ 拿掉的話，購課頁會同時冒出【單堂】的品項：
--      PT 單堂（一對一）1,800 ／ PGT 單堂（一對三）2,100 ／ 企業包班費率…
--    而單堂的錢【已經在服務登記那一側收了】（第 90 步的 service_payments）。
--    在購課頁再賣一次 ＝ 同一堂課的收入被記兩遍，
--    而且會開出一張「1 堂」的卡，下次上課又被扣掉一次。
--    ☢️ 損益表會憑空多出一筆收入，對帳報表也對得起來 —— 因為兩邊都是真的資料。
--
-- ══ 為什麼用一個欄位，不是用「credits >= 2」這條規則 ═════════════
-- ☢️ 「堂數大於一就是卡」今天成立，但它是【推論】不是【事實】。
--    哪天出現「體驗雙人套組 2 堂」或「單張券」，這條規則就悄悄判錯，
--    而判錯的症狀是購課頁多出或少掉一個品項 —— 沒有人會報錯。
--    改成資料庫裡一個明確的欄位：要賣就標 true，一翻兩瞪眼。
-- ═══════════════════════════════════════════════════════════════════

alter table public.products
  add column if not exists sellable boolean not null default false;

comment on column public.products.sellable is
  '這個品項能不能在【購課頁】賣（＝開一張預付卡）。'
  '☢️ 單堂類一律 false —— 單堂的錢在服務登記那一側收，兩邊都賣會記兩遍收入。';

-- 目前能開卡的四個。☢️ GT-1 也算：團體課買一堂就是帳本 +1，
-- 而團體課的銷課本來就走帳本，跟私人課的單堂不一樣。
update public.products set sellable = true
 where code in ('GT-1','GT-12','PT-10-1','PT-10-2');

update public.products set sellable = false
 where code not in ('GT-1','GT-12','PT-10-1','PT-10-2');


-- ── 購課：只賣標了 sellable 的品項 ─────────────────────────────
-- ☢️ 前端不畫那顆鍵只是不要讓人白按。真正的牆在這裡 ——
--    有人直接打 RPC，或哪天前端改壞了，這一關照樣擋得住。
create or replace function public.add_purchase(
  p_customer uuid,
  p_code     text,
  p_method   text,
  p_note     text default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare v_p record; v_c record; v_id uuid; v_bal integer;
begin
  if not public.is_staff() then
    raise exception '只有員工可以課購';
  end if;
  if p_method not in ('cash','transfer') then
    return jsonb_build_object('ok', false, 'why', 'bad_method');
  end if;

  select * into v_p from public.products where code = p_code and is_active;
  if not found then return jsonb_build_object('ok', false, 'why', 'bad_product'); end if;

  -- ☢️ 單堂不能在這裡賣。錢在服務登記那一側收，這裡再賣一次會記兩遍收入，
  --    還會開出一張「1 堂」的卡，下次上課又被扣掉一次。
  if not v_p.sellable then
    return jsonb_build_object('ok', false, 'why', 'not_sellable',
      'msg', format('「%s」不是預付卡，不能在購課頁賣 —— '
                    '單堂請走服務登記的「單堂現收」，錢在那裡收。', v_p.label));
  end if;

  select id, name, is_active into v_c from public.customers where id = p_customer;
  if not found then return jsonb_build_object('ok', false, 'why', 'no_customer'); end if;
  if v_c.is_active = false then return jsonb_build_object('ok', false, 'why', 'inactive'); end if;

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
           'product', v_p.product, 'headcount', v_p.headcount,
           'balance', v_bal, 'pending', (p_method = 'transfer'));
end $fn$;

revoke all on function public.add_purchase(uuid, text, text, text) from public, anon;
grant execute on function public.add_purchase(uuid, text, text, text) to authenticated;

comment on function public.add_purchase(uuid, text, text, text) is
  '幫客人開一張預付卡。☢️ 只賣 products.sellable = true 的品項 ——'
  '單堂的錢在服務登記那一側收，兩邊都賣會把同一筆收入記兩遍。';


-- ── 查客人的時候要看得到私人課還剩幾堂 ─────────────────────────
-- ☢️ staff_customers 的 balance 一直是【GT 那一欄】。
--    PT 的卡開始存在之後，櫃檯在購課頁看到的「剩 N 堂」如果只有團課，
--    就會出現「客人說他還有八堂、畫面上寫 0」這種對話 ——
--    而兩邊都沒有錯，只是講的不是同一件事。
-- ☢️ 新欄位只能加在【最後面】。create or replace view 不允許把欄位插在中間 ——
--    它會把那一欄當成「舊欄位改名」，然後回一句看不出原因的錯誤
--    （第 54 步踩過一次，寫在那支的註解裡）。
create or replace view public.staff_customers as
select
  c.id,
  c.name,
  c.nickname,
  c.phone,
  right(c.phone, 3) as phone_tail,
  c.line_user_id is not null as bound,
  c.is_active,
  c.created_at,
  coalesce(bal.balance, 0) as balance,
  -- ── 這一行是新的 ──
  coalesce((select sum(l.delta)::integer from public.credit_ledger l
             where l.customer_id = c.id and l.product in ('PT','PGT')), 0) as balance_pt
from public.customers c
left join lateral (
  select sum(l.delta)::integer as balance
    from public.credit_ledger l
   where l.customer_id = c.id and l.product = 'GT'
) bal on true
where public.is_staff();

grant select on public.staff_customers to authenticated;

comment on view public.staff_customers is
  '櫃檯查客人用。☢️ balance 是【團體課】那一欄，balance_pt 是【私人課】——'
  '兩種堂數的每堂價值完全不同，加起來的數字不代表任何東西。';
