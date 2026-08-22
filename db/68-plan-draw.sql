-- ═══════════════════════════════════════════════════════════════════
-- db/68-plan-draw.sql — 服務登記的「扣預收」真的扣一堂
--
-- 專案：FFF 預約系統（fff-platform）· 第 93 步之二 · 2026-08-22
--
-- ☢️☢️ 這是目前系統裡【最大的一個洞】。
--    服務登記選「扣預收」的時候，system 只是把 charge_method 記成 'plan'，
--    然後【什麼都沒做】—— 客人的卡一堂都沒有少。
--    現在有 175 筆這種紀錄。
--    客人買十堂、上完十堂，系統仍然認為他有十堂 ——
--    那是一筆【只會漲、永遠不會跌的負債】，
--    而第 95 步的損益表要把預收餘額當負債列出來。
--
-- ══ 為什麼一定要「人選哪一張卡」═════════════════════════════════
-- ☢️ 一個人可能同時有【一對一】和【一對二】兩張卡，
--    而兩張卡的每堂價值不一樣（實收 ÷ 堂數：15,000÷10 vs 20,000÷10）。
--    舊的 plan_allocate 只認產品別，會照「同產品最舊的那張」抽 ——
--    抽錯 → 業績錯 → 抽成錯 → 【薪水錯】，而且畫面上完全正常。
-- ☢️ 解法不是把猜的邏輯寫得更聰明，是【不要猜】。
--    第 65 步已經讓 credit_ledger 可以指定 plan_id，這一支把它接上來。
--
-- ══ 三種情況，三種反應 ═══════════════════════════════════════════
--   ① 有指定卡 → 驗過之後真的扣一堂
--   ② 沒指定卡，但這位客人【有卡可扣】→ 擋下來，叫他選
--   ③ 沒指定卡，而且這位客人【一張卡都沒有】→ 放行，但留下記號
--
-- ☢️ ③ 不是偷懶，是現況：PT／PGT 的期初餘額還沒匯進來（目前 0 張卡）。
--    這時候擋下來等於【今天就把服務登記整個弄壞】——
--    那是每天在用的工具。
--    但放行也不能沒有痕跡，所以有 staff_service_no_plan 這張清單：
--    期初餘額匯進來之後，那 175 筆要回頭補扣，而清單就是待辦事項。
--
-- ══ 作廢要把堂數還回去 ═══════════════════════════════════════════
-- ☢️ 這是最容易漏的一段。作廢一筆扣了預收的服務，
--    如果不把那一堂還回去，客人就【永久少一堂】——
--    而他不會發現，因為他本來就不知道系統扣了幾堂。
-- ═══════════════════════════════════════════════════════════════════

-- ── ① 帳本那一列要知道自己是哪一筆服務扣的 ─────────────────────
-- ☢️ 不能只靠 note 裡的文字。作廢的時候要找回「剛剛扣的那一列」，
--    用字串找的話，只要有人改過文案就找不到了 —— 而且不會報錯。
alter table public.credit_ledger
  add column if not exists service_id uuid references public.service_records(id);

create index if not exists credit_ledger_service_idx
  on public.credit_ledger (service_id) where service_id is not null;

comment on column public.credit_ledger.service_id is
  '這一列是哪一筆服務紀錄扣的（或退的）。作廢／還原靠它找回原本那一列。';

do $$
begin
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.service_records'::regclass
                    and conname = 'service_records_plan_id_fkey') then
    alter table public.service_records
      add constraint service_records_plan_id_fkey
      foreign key (plan_id) references public.plans(id);
  end if;
end $$;


-- ── ② 這位客人有哪幾張卡可以扣（前端的選單就吃這張）─────────────
-- ☢️ 只列【還有剩】的。列出剩 0 堂的卡只會讓人選錯，
--    而選錯的下一步是一個看不懂的錯誤訊息。
create or replace view public.staff_pickable_plans as
select
  ps.id                       as plan_id,
  ps.owner_customer_id        as customer_id,
  ps.product,
  coalesce(ps.product_code,'') as product_code,
  ps.headcount,
  ps.total_credits,
  ps.remaining::int           as remaining,
  ps.per_credit,
  ps.basis_status,
  coalesce(ps.note,'')        as note,
  ps.opened_at,
  -- 給人看的一行：「一對二預付十堂・剩 8 堂・每堂 2,000」
  concat_ws('・',
    case
      when ps.product = 'GT' then '團體課'
      when ps.headcount = 2  then '一對二'
      when ps.headcount = 1  then '一對一'
      when ps.headcount is not null then ps.headcount || ' 人班'
      else ps.product
    end || case when ps.total_credits > 0
                then '預付 ' || ps.total_credits || ' 堂' else '（補登期初）' end,
    '剩 ' || ps.remaining || ' 堂',
    case when ps.per_credit is not null
         then '每堂 ' || to_char(ps.per_credit, 'FM999,999.##') else '每堂待確認' end
  ) as label
from public.plan_state ps
where public.is_staff() and ps.remaining > 0;

grant select on public.staff_pickable_plans to authenticated;

comment on view public.staff_pickable_plans is
  '服務登記選「扣預收」時，這位客人有哪幾張卡可以扣。只列還有剩的。';


-- ── ③ 扣預收，卻沒有扣到任何一張卡的服務紀錄 ───────────────────
-- ☢️ 這張清單就是待辦事項。期初餘額匯進來之後要回頭把它們補扣掉，
--    清單歸零那天，「客人還剩幾堂」才是可信的。
create or replace view public.staff_service_no_plan as
select
  s.id                as service_id,
  s.done_at,
  s.customer_id,
  coalesce(c.name, s.company_name, '（沒有客人）') as customer_name,
  coalesce(c.client_code,'')                       as client_code,
  right(c.phone, 3)   as phone_tail,
  s.service_type,
  s.headcount,
  s.perf_amount,
  (select string_agg(e.display_name, '、' order by e.display_name)
     from public.service_coaches sc
     join public.employees e on e.id = sc.coach_id
    where sc.service_id = s.id) as coach_names,
  -- 現在有卡可以補扣了嗎
  (select count(*) from public.plan_state ps
    where ps.owner_customer_id = s.customer_id
      and ps.product = case when s.service_type in ('PT','PT_OUT') then 'PT' else 'PGT' end
      and ps.remaining > 0)::int as cards_now
from public.service_records s
left join public.customers c on c.id = s.customer_id
where public.is_finance()
  and s.charge_method = 'plan'
  and not s.voided
  and s.plan_id is null;

grant select on public.staff_service_no_plan to authenticated;

comment on view public.staff_service_no_plan is
  '☢️ 登記成「扣預收」但一張卡都沒扣到的服務紀錄 —— 期初餘額匯入後要回頭補扣。'
  'cards_now > 0 代表這位客人現在已經有卡了，可以補。';


-- ── ④ 登記服務：扣預收要真的扣 ─────────────────────────────────
create or replace function public.add_service(p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_type    text;
  v_done    timestamptz;
  v_cust    uuid;
  v_head    smallint;
  v_att     smallint;
  v_charge  text;
  v_code    text;
  v_price   integer;
  v_rev     integer;
  v_travel  integer := 0;
  v_perf    integer := 0;
  v_hours   numeric(4,1);
  v_raw     numeric;
  v_area    text;
  v_coaches uuid[];
  v_n       integer;
  v_id      uuid;
  v_me      uuid;
  v_c       uuid;
  -- 第 93 步新增
  v_plan    uuid;
  v_prod    text;
  v_ps      record;
  v_ncards  integer := 0;
begin
  if not public.is_staff() then
    raise exception '只有職員可以登記服務';
  end if;
  v_me := public.my_employee_id();

  v_type   := p_data->>'service_type';
  v_charge := coalesce(p_data->>'charge_method', 'single');
  v_cust   := nullif(p_data->>'customer_id','')::uuid;
  v_head   := nullif(p_data->>'headcount','')::smallint;
  v_att    := nullif(p_data->>'attended_count','')::smallint;
  v_plan   := nullif(p_data->>'plan_id','')::uuid;

  if v_type is null or v_type not in ('PT','PGT','PT_OUT','PGT_OUT','EVENT','CORP') then
    return jsonb_build_object('ok', false, 'why', 'bad_type', 'msg', '服務類型不對');
  end if;

  begin
    v_done := (p_data->>'done_at')::timestamptz;
  exception when others then
    return jsonb_build_object('ok', false, 'why', 'bad_date', 'msg', '完成時間格式不對');
  end;
  if v_done is null then
    return jsonb_build_object('ok', false, 'why', 'bad_date', 'msg', '要填完成日期與時間');
  end if;
  if v_done > now() + interval '1 day' then
    return jsonb_build_object('ok', false, 'why', 'future',
      'msg', '完成時間不能是未來 —— 這一欄是「已經上完了」，不是預約。');
  end if;

  select array_agg(x::uuid) into v_coaches
  from jsonb_array_elements_text(coalesce(p_data->'coach_ids','[]'::jsonb)) as t(x)
  where x <> '';
  v_n := coalesce(array_length(v_coaches, 1), 0);
  if v_n = 0 then
    return jsonb_build_object('ok', false, 'why', 'no_coach', 'msg', '要選授課教練');
  end if;

  if v_type in ('PT','PT_OUT','PGT','PGT_OUT') then
    if v_n <> 1 then
      return jsonb_build_object('ok', false, 'why', 'coach_n',
        'msg', 'PT／PGT 一次只有一位授課教練');
    end if;
    if v_cust is null then
      return jsonb_build_object('ok', false, 'why', 'no_customer', 'msg', '要選客人');
    end if;

    if v_type in ('PT','PT_OUT') and (v_head is null or v_head < 1 or v_head > 2) then
      return jsonb_build_object('ok', false, 'why', 'head',
        'msg', 'PT 的人數只能是 1 或 2 人');
    end if;
    if v_type in ('PGT','PGT_OUT') and (v_head is null or v_head < 3 or v_head > 6) then
      return jsonb_build_object('ok', false, 'why', 'head',
        'msg', 'PGT 的人數只能是 3 到 6 人');
    end if;

    v_code := nullif(p_data->>'product_code','');
    if v_charge = 'free' then
      v_rev := 0;
    elsif v_code is not null then
      select price into v_price from public.products
       where code = v_code and is_active;
      if v_price is null then
        return jsonb_build_object('ok', false, 'why', 'bad_product',
          'msg', '找不到這個方案，或它已經停用');
      end if;
      v_rev := v_price;
    else
      v_rev := coalesce(nullif(p_data->>'revenue_amount','')::integer, 0);
    end if;

    if v_type in ('PT_OUT','PGT_OUT') then
      v_travel := 500;
    end if;

    v_perf := v_rev + v_travel;

    -- ══ ☢️ 扣預收：先把卡驗完，再寫任何東西 ════════════════════
    --    驗證放在 insert 之前，這樣所有的「不行」都是一句看得懂的話，
    --    而不是一個資料庫錯誤訊息。
    if v_charge = 'plan' then
      v_prod := case when v_type in ('PT','PT_OUT') then 'PT' else 'PGT' end;

      select count(*) into v_ncards from public.plan_state
       where owner_customer_id = v_cust and product = v_prod and remaining > 0;

      if v_plan is not null then
        select * into v_ps from public.plan_state where id = v_plan;
        if not found then
          return jsonb_build_object('ok', false, 'why', 'bad_plan', 'msg', '找不到這張卡');
        end if;
        if v_ps.owner_customer_id <> v_cust then
          return jsonb_build_object('ok', false, 'why', 'bad_plan',
            'msg', '這張卡不是這位客人的');
        end if;
        if v_ps.product <> v_prod then
          return jsonb_build_object('ok', false, 'why', 'plan_product',
            'msg', format('這是 %s 的卡，不能拿來扣 %s 的課', v_ps.product, v_prod));
        end if;
        if v_ps.remaining < 1 then
          return jsonb_build_object('ok', false, 'why', 'plan_empty',
            'msg', '這張卡已經沒有堂數了');
        end if;
        -- ☢️ 一對一的卡不能扣一對二的課。兩張卡的每堂價值不一樣
        --    （15,000÷10 vs 20,000÷10），扣錯就是業績錯、抽成錯、薪水錯，
        --    而且畫面上完全正常。
        if v_ps.headcount is not null and v_head is not null
           and v_ps.headcount <> v_head then
          return jsonb_build_object('ok', false, 'why', 'plan_head',
            'msg', format('這張是 %s 人的卡，這一堂登記 %s 人 —— 每堂價值不一樣，不能互扣',
                          v_ps.headcount, v_head));
        end if;

      elsif v_ncards > 0 then
        -- ☢️ 有卡卻不指定 → 擋。系統【不猜】要扣哪一張。
        return jsonb_build_object('ok', false, 'why', 'pick_plan',
          'n_cards', v_ncards,
          'msg', format('這位客人有 %s 張還有堂數的卡 —— 要選一張才知道從哪裡扣', v_ncards));
      end if;
      -- v_ncards = 0：這位客人一張卡都沒有（期初餘額還沒匯進來）→ 放行，
      -- 但 plan_id 留空，這一筆會出現在 staff_service_no_plan 待補清單裡。
    end if;

  elsif v_type = 'EVENT' then
    if v_n > 2 then
      return jsonb_build_object('ok', false, 'why', 'coach_n',
        'msg', '諧動外派活動單次最多派 2 位教練');
    end if;
    v_raw := nullif(p_data->>'hours','')::numeric;
    if v_raw is null or v_raw <= 0 then
      return jsonb_build_object('ok', false, 'why', 'hours', 'msg', '要填活動時數');
    end if;
    v_hours := ceil(v_raw)::numeric(4,1);
    v_travel := 500;
    v_rev  := (v_n * v_hours * 600)::integer + (v_hours * 600)::integer;
    v_perf := 0;
    v_plan := null;

  else
    if v_n <> 1 then
      return jsonb_build_object('ok', false, 'why', 'coach_n',
        'msg', '企業包班單次至多 1 位主導教練');
    end if;

    v_area := upper(coalesce(nullif(p_data->>'area_kind',''), ''));
    if v_area not in ('TPE','OUT') then
      return jsonb_build_object('ok', false, 'why', 'area',
        'msg', '要選服務地區：大台北，還是非大台北');
    end if;
    v_code := 'CORP-' || v_area;
    select price into v_price from public.products where code = v_code and is_active;
    if v_price is null then
      return jsonb_build_object('ok', false, 'why', 'bad_product',
        'msg', '找不到企業包班的費率（products 表少了 ' || v_code || '）');
    end if;

    v_raw := nullif(p_data->>'hours','')::numeric;
    if v_raw is null or v_raw <= 0 then
      return jsonb_build_object('ok', false, 'why', 'hours', 'msg', '要填服務時數');
    end if;
    v_hours := v_raw::numeric(4,1);

    if v_head is null or v_head < 7 then
      return jsonb_build_object('ok', false, 'why', 'head',
        'msg', '企業包班 7 人（含）以上才開班，人數上限不限');
    end if;

    v_rev    := round(v_price * v_hours)::integer;
    v_travel := 0;
    v_perf   := v_rev;
    v_plan   := null;
  end if;

  insert into public.service_records (
    service_type, done_at, customer_id, company_name, tax_id,
    headcount, attended_count, product_code, plan_id, charge_method,
    revenue_amount, travel_fee, perf_amount, billed_hours,
    area, booked_hours, approved_headcount, scope, transport,
    approver_id, approved_on, note, created_by)
  values (
    v_type, v_done, v_cust,
    nullif(p_data->>'company_name',''), nullif(p_data->>'tax_id',''),
    case when v_type = 'CORP' then null else v_head end,
    v_att,
    case when v_type in ('EVENT') then null else v_code end,
    case when v_charge = 'plan' then v_plan else null end,
    v_charge,
    v_rev, v_travel, v_perf,
    v_hours,
    nullif(p_data->>'area',''),
    nullif(p_data->>'booked_hours','')::numeric,
    case when v_type = 'CORP' then v_head else nullif(p_data->>'approved_headcount','')::smallint end,
    nullif(p_data->>'scope',''), nullif(p_data->>'transport',''),
    nullif(p_data->>'approver_id','')::uuid,
    nullif(p_data->>'approved_on','')::date,
    nullif(p_data->>'note',''), v_me)
  returning id into v_id;

  foreach v_c in array v_coaches loop
    insert into public.service_coaches (service_id, coach_id, is_lead)
    values (v_id, v_c, v_c = v_coaches[1])
    on conflict do nothing;
  end loop;

  -- ══ 真的扣一堂 ═══════════════════════════════════════════════
  -- ☢️ 一筆服務扣【一堂】。兩小時的課請登記兩筆 ——
  --    讓「幾堂」變成一個可以填的欄位，就等於開了一個可以填錯的地方，
  --    而填錯的症狀是客人的卡莫名其妙變少。
  if v_charge = 'plan' and v_plan is not null then
    insert into public.credit_ledger (
      customer_id, delta, reason, product, plan_id, service_id, note, created_by)
    values (
      v_cust, -1, 'class', v_prod, v_plan, v_id,
      to_char(v_done at time zone 'Asia/Taipei','YYYY-MM-DD') || ' 私人課扣預收',
      v_me);
  end if;

  return jsonb_build_object('ok', true, 'id', v_id,
    'revenue', v_rev, 'travel', v_travel, 'perf', v_perf,
    'hours', v_hours, 'rate', v_price, 'total', v_rev + v_travel,
    'plan_id', v_plan,
    'drew', (v_charge = 'plan' and v_plan is not null),
    'plan_left', case when v_plan is not null
                      then (select remaining::int from public.plan_state where id = v_plan) end,
    'no_card', (v_charge = 'plan' and v_plan is null));
end $fn$;

revoke all on function public.add_service(jsonb) from public, anon;
grant execute on function public.add_service(jsonb) to authenticated;


-- ── ⑤ 作廢：把扣掉的那一堂還回去 ───────────────────────────────
create or replace function public.void_service(p_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare v_r record; v_net int; v_back int := 0;
begin
  if not public.is_finance() then
    raise exception '只有財務可以作廢服務紀錄';
  end if;
  if coalesce(btrim(p_reason),'') = '' then
    return jsonb_build_object('ok', false, 'why', 'no_reason', 'msg', '要寫作廢原因');
  end if;
  select * into v_r from public.service_records where id = p_id;
  if not found then return jsonb_build_object('ok', false, 'why', 'not_found'); end if;
  if v_r.voided then
    return jsonb_build_object('ok', false, 'why', 'already', 'msg', '這筆已經作廢了');
  end if;

  update public.service_records
     set voided = true, void_reason = btrim(p_reason),
         voided_by = public.my_employee_id(), voided_at = now()
   where id = p_id;

  -- ☢️ 這筆服務到底還欠客人幾堂？用【淨額】算，不是「有沒有扣過」——
  --    作廢→還原→再作廢會產生好幾列，只看有沒有扣過會重複退。
  select coalesce(sum(delta),0) into v_net
    from public.credit_ledger where service_id = p_id;

  if v_net < 0 then
    v_back := -v_net;
    insert into public.credit_ledger (
      customer_id, delta, reason, product, plan_id, service_id, note, created_by)
    values (
      v_r.customer_id, v_back, 'class',
      case when v_r.service_type in ('PT','PT_OUT') then 'PT' else 'PGT' end,
      v_r.plan_id, p_id,
      '作廢退回：' || btrim(p_reason), public.my_employee_id());
  end if;

  return jsonb_build_object('ok', true, 'id', p_id,
    'gave_back', v_back,
    'plan_left', case when v_r.plan_id is not null
                      then (select remaining::int from public.plan_state where id = v_r.plan_id) end);
end $fn$;

revoke all on function public.void_service(uuid, text) from public, anon;
grant execute on function public.void_service(uuid, text) to authenticated;


-- ── ⑥ 還原：把還回去的那一堂再扣回來 ───────────────────────────
create or replace function public.restore_service(p_id uuid, p_why text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare v_r record; v_who text; v_net int; v_left int; v_took int := 0;
begin
  if not public.is_finance() then
    raise exception '只有財務可以還原服務紀錄';
  end if;
  if coalesce(btrim(p_why),'') = '' then
    return jsonb_build_object('ok', false, 'why', 'no_reason', 'msg', '要寫還原原因');
  end if;

  select * into v_r from public.service_records where id = p_id;
  if not found then
    return jsonb_build_object('ok', false, 'why', 'not_found', 'msg', '找不到這筆紀錄');
  end if;
  if not v_r.voided then
    return jsonb_build_object('ok', false, 'why', 'not_voided', 'msg', '這筆沒有作廢，不用還原');
  end if;

  -- ☢️ 先確認卡還扣得動【才】還原。順序反過來的話，
  --    會出現「已經還原、但堂數沒扣回去」的紀錄 —— 那比不能還原更難查。
  select coalesce(sum(delta),0) into v_net
    from public.credit_ledger where service_id = p_id;

  if v_r.plan_id is not null and v_net = 0 then
    select remaining::int into v_left from public.plan_state where id = v_r.plan_id;
    if v_left is null then
      return jsonb_build_object('ok', false, 'why', 'plan_gone',
        'msg', '原本那張卡已經不在了 —— 請先處理卡，再還原這一筆');
    end if;
    if v_left < 1 then
      return jsonb_build_object('ok', false, 'why', 'plan_empty',
        'msg', '原本那張卡現在沒有堂數了，還原會把它扣成負的 —— '
               || '請先幫客人補卡或調整堂數，再還原這一筆');
    end if;
  end if;

  select display_name into v_who from public.employees where id = v_r.voided_by;

  update public.service_records
     set voided      = false,
         void_reason = null,
         voided_by   = null,
         voided_at   = null,
         manual_note = concat_ws(' ｜ ', nullif(manual_note,''),
           to_char(now() at time zone 'Asia/Taipei','YYYY-MM-DD HH24:MI')
           || ' 還原作廢（原作廢：' || coalesce(v_who,'不明') || ' 於 '
           || to_char(v_r.voided_at at time zone 'Asia/Taipei','MM-DD HH24:MI')
           || '，原因「' || coalesce(v_r.void_reason,'') || '」）｜ 還原原因：' || btrim(p_why))
   where id = p_id;

  if v_r.plan_id is not null and v_net = 0 then
    v_took := 1;
    insert into public.credit_ledger (
      customer_id, delta, reason, product, plan_id, service_id, note, created_by)
    values (
      v_r.customer_id, -1, 'class',
      case when v_r.service_type in ('PT','PT_OUT') then 'PT' else 'PGT' end,
      v_r.plan_id, p_id,
      '還原作廢，重新扣預收：' || btrim(p_why), public.my_employee_id());
  end if;

  return jsonb_build_object('ok', true, 'id', p_id,
    'perf', v_r.perf_amount, 'fin_status', v_r.fin_status,
    'was_voided_by', coalesce(v_who,'不明'), 'was_reason', v_r.void_reason,
    'took_back', v_took,
    'plan_left', case when v_r.plan_id is not null
                      then (select remaining::int from public.plan_state where id = v_r.plan_id) end);
end $fn$;

revoke all on function public.restore_service(uuid, text) from public, anon;
grant execute on function public.restore_service(uuid, text) to authenticated;


-- ── ⑦ 「我的學員」那張表要把 GT 和私人課分開 ───────────────────
-- ☢️ 原本的 balance 是【所有產品加總】。今天只有 GT 有卡，所以看不出問題；
--    PT 的卡一進來，畫面上就會出現一個「團課 5 堂 ＋ 私人課 8 堂 ＝ 13 堂」
--    這種【誰都不該相信的數字】。趁還沒發生先拆開。
-- ☢️ create or replace view 只能在【最後面】加欄位，不能插在中間
--    （插中間會變成把舊欄位改名，而且錯誤訊息看不出原因）。
create or replace view public.staff_clients_coach as
select
  c.id                       as customer_id,
  c.name                     as customer_name,
  coalesce(c.nickname, '')   as nickname,
  right(c.phone, 3)          as phone_tail,
  coalesce(c.client_code, '') as client_code,
  c.is_active,
  coalesce(array_agg(e.id)            filter (where e.id is not null), '{}')::uuid[] as coach_ids,
  coalesce(string_agg(e.display_name, '、' order by e.display_name)
             filter (where e.id is not null), '')                                   as coach_names,
  count(e.id)::int           as n_coaches,
  -- ☢️ 團體課那一側。私人課在後面獨立一欄。
  coalesce((select sum(l.delta) from public.credit_ledger l
             where l.customer_id = c.id and l.product = 'GT'), 0)::int as balance,
  greatest(
    (select max(s.session_date)::timestamptz
       from public.bookings b join public.class_sessions s on s.id = b.session_id
      where b.customer_id = c.id and b.status = 'attended'),
    (select max(sr.done_at)
       from public.service_records sr
      where sr.customer_id = c.id and not sr.voided)
  ) as last_class_at,
  coalesce((select sum(l.delta) from public.credit_ledger l
             where l.customer_id = c.id and l.product in ('PT','PGT')), 0)::int as balance_pt
from public.customers c
left join public.customer_coaches cc on cc.customer_id = c.id
left join public.employees e on e.id = cc.coach_id
where public.is_staff()
group by c.id, c.name, c.nickname, c.phone, c.client_code, c.is_active;

grant select on public.staff_clients_coach to authenticated;
