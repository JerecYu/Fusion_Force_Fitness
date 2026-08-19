-- ============================================================
-- 42 · 登記一次服務 —— 規則寫在資料庫裡，不是寫在畫面上
--
-- ☢️ 為什麼用 jsonb 當參數：五種服務要填的欄位差很多
--    （活動要時數、包班要核定總價與核准人、外派要交通費）。
--    寫成 20 個具名參數的話，每加一種商品就要改簽名，
--    而改簽名就要 drop function，drop 就會掉權限。
--
-- ☢️ 金額一律【由資料庫算】，前端只能送「人數、時數、核定總價」這種原始輸入。
--    前端算好再送過來的話，改一下網頁原始碼就能塞任何金額進帳。
-- ============================================================

-- ── ① 登記 ──────────────────────────────────────────────────
create or replace function public.add_service(p_data jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $fn$
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
  v_coaches uuid[];
  v_n       integer;
  v_id      uuid;
  v_me      uuid;
  v_c       uuid;
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
  -- ☢️ 完成日期決定薪資月份（第六篇 1），未來的日期一定是填錯。
  if v_done > now() + interval '1 day' then
    return jsonb_build_object('ok', false, 'why', 'future',
      'msg', '完成時間不能是未來 —— 這一欄是「已經上完了」，不是預約。');
  end if;

  -- 教練名單
  select array_agg(x::uuid) into v_coaches
  from jsonb_array_elements_text(coalesce(p_data->'coach_ids','[]'::jsonb)) as t(x)
  where x <> '';
  v_n := coalesce(array_length(v_coaches, 1), 0);
  if v_n = 0 then
    return jsonb_build_object('ok', false, 'why', 'no_coach', 'msg', '要選授課教練');
  end if;

  -- ── 分商品驗證與算錢 ──
  if v_type in ('PT','PT_OUT','PGT','PGT_OUT') then
    if v_n <> 1 then
      return jsonb_build_object('ok', false, 'why', 'coach_n',
        'msg', 'PT／PGT 一次只有一位授課教練');
    end if;
    if v_cust is null then
      return jsonb_build_object('ok', false, 'why', 'no_customer', 'msg', '要選客人');
    end if;

    -- 人數規格（第二篇 1.1、1.2）
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
      v_rev := 0;                              -- 體驗或贈課：不認列課程收入
    elsif v_code is not null then
      -- ☢️ 價格【從資料庫查】，不收前端送來的金額。
      select price into v_price from public.products
       where code = v_code and is_active;
      if v_price is null then
        return jsonb_build_object('ok', false, 'why', 'bad_product',
          'msg', '找不到這個方案，或它已經停用');
      end if;
      v_rev := v_price;
    else
      -- 歷史方案／扣預收：業績基礎由財務給（第二篇 1.4「實收 ÷ 固定堂數」）
      v_rev := coalesce(nullif(p_data->>'revenue_amount','')::integer, 0);
    end if;

    -- 外派：每次固定交通費 500（第二篇 2）
    if v_type in ('PT_OUT','PGT_OUT') then
      v_travel := 500;
    end if;

    -- 課程費與交通費【都】列入該教練的 PT＋PGT 業績（第五篇 1）
    v_perf := v_rev + v_travel;

  elsif v_type = 'EVENT' then
    -- 諧動外派活動（第二篇 3）
    if v_n > 2 then
      return jsonb_build_object('ok', false, 'why', 'coach_n',
        'msg', '諧動外派活動單次最多派 2 位教練');
    end if;
    v_raw := nullif(p_data->>'hours','')::numeric;
    if v_raw is null or v_raw <= 0 then
      return jsonb_build_object('ok', false, 'why', 'hours', 'msg', '要填活動時數');
    end if;
    -- ☢️ 無條件進位：0.5→1、1.5→2、2.2→3。在資料庫做，前端改不掉。
    v_hours := ceil(v_raw)::numeric(4,1);
    v_travel := 500;                                   -- 基礎交通費
    -- 對客報價 ＝ 教練費（教練人數 × 時數 × 600）＋ 活動費（時數 × 600）
    v_rev  := (v_n * v_hours * 600)::integer + (v_hours * 600)::integer;
    -- ☢️ 活動走鐘點費，不進 PT＋PGT 抽成（第五篇 1）
    v_perf := 0;

  else -- CORP 企業包班（第二篇 4）
    if v_n <> 1 then
      return jsonb_build_object('ok', false, 'why', 'coach_n',
        'msg', '企業包班單次至多 1 位主導教練');
    end if;
    v_rev := nullif(p_data->>'revenue_amount','')::integer;
    if v_rev is null or v_rev <= 0 then
      return jsonb_build_object('ok', false, 'why', 'amount',
        'msg', '企業包班要填核定整案總價 —— 系統不自動算時數');
    end if;
    if nullif(p_data->>'approver_id','') is null then
      return jsonb_build_object('ok', false, 'why', 'approver',
        'msg', '企業包班要記核准人');
    end if;
    -- 核定整案總價併入該教練 PT＋PGT 抽成（第二篇 4、第五篇 1）
    v_perf := v_rev;
    v_head := null;   -- 企業包班不套用 PT／PGT 人數規格
  end if;

  insert into public.service_records (
    service_type, done_at, customer_id, company_name, tax_id,
    headcount, attended_count, product_code, charge_method,
    revenue_amount, travel_fee, perf_amount, billed_hours,
    area, booked_hours, approved_headcount, scope, transport,
    approver_id, approved_on, note, created_by)
  values (
    v_type, v_done, v_cust,
    nullif(p_data->>'company_name',''), nullif(p_data->>'tax_id',''),
    v_head, v_att, v_code, v_charge,
    v_rev, v_travel, v_perf, v_hours,
    nullif(p_data->>'area',''),
    nullif(p_data->>'booked_hours','')::numeric,
    nullif(p_data->>'approved_headcount','')::smallint,
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

  return jsonb_build_object('ok', true, 'id', v_id,
    'revenue', v_rev, 'travel', v_travel, 'perf', v_perf,
    'hours', v_hours, 'total', v_rev + v_travel);
end $fn$;

revoke all on function public.add_service(jsonb) from public;
grant execute on function public.add_service(jsonb) to authenticated;

-- ── ② 財務最終認列 ──────────────────────────────────────────
-- ☢️ 只有財務可以按。第一篇 2：「薪資端只使用財務最終認列結果」——
--    沒有這一關，任何人登記完就直接變成薪水。
create or replace function public.finalize_service(p_id uuid, p_note text default null)
returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare v_r record;
begin
  if not public.is_finance() then
    raise exception '只有財務可以做最終認列';
  end if;
  select * into v_r from public.service_records where id = p_id;
  if not found then return jsonb_build_object('ok', false, 'why', 'not_found'); end if;
  if v_r.voided then
    return jsonb_build_object('ok', false, 'why', 'voided', 'msg', '這筆已經作廢了');
  end if;
  if v_r.fin_status = 'final' then
    return jsonb_build_object('ok', false, 'why', 'already', 'msg', '這筆已經認列過了');
  end if;

  update public.service_records
     set fin_status = 'final', fin_by = public.my_employee_id(), fin_at = now(),
         manual_note = coalesce(nullif(p_note,''), manual_note)
   where id = p_id;

  return jsonb_build_object('ok', true, 'id', p_id);
end $fn$;

revoke all on function public.finalize_service(uuid, text) from public;
grant execute on function public.finalize_service(uuid, text) to authenticated;

-- ── ③ 作廢 ──────────────────────────────────────────────────
-- ☢️ 不是刪除。刪掉的話對帳時會看到一個洞，而且說不出來是誰刪的。
create or replace function public.void_service(p_id uuid, p_reason text)
returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare v_r record;
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

  return jsonb_build_object('ok', true, 'id', p_id);
end $fn$;

revoke all on function public.void_service(uuid, text) from public;
grant execute on function public.void_service(uuid, text) to authenticated;

-- ── ④ 清單 ──────────────────────────────────────────────────
-- ☢️ definer，牆是 is_staff()。不要加 security_invoker（第 25、66 步）。
create or replace view public.staff_services as
select r.id,
       r.service_type,
       r.done_at,
       (r.done_at at time zone 'Asia/Taipei')::date as done_date,
       to_char(r.done_at at time zone 'Asia/Taipei', 'HH24:MI') as done_time,
       c.name                        as customer_name,
       right(c.phone, 3)             as phone_tail,
       r.company_name,
       r.headcount,
       r.attended_count,
       r.charge_method,
       r.product_code,
       r.revenue_amount,
       r.travel_fee,
       r.perf_amount,
       r.revenue_amount + r.travel_fee as total_amount,
       r.billed_hours,
       r.area,
       r.scope,
       r.fin_status,
       fb.display_name               as fin_by_name,
       r.fin_at,
       r.note,
       r.manual_note,
       r.voided, r.void_reason,
       vb.display_name               as voided_by_name,
       cb.display_name               as created_by_name,
       r.created_at,
       coalesce(co.names, '')        as coach_names,
       coalesce(co.n, 0)             as coach_n
from public.service_records r
left join public.customers c  on c.id  = r.customer_id
left join public.employees fb on fb.id = r.fin_by
left join public.employees vb on vb.id = r.voided_by
left join public.employees cb on cb.id = r.created_by
left join lateral (
  select string_agg(e.display_name, '、' order by sc.is_lead desc, e.display_name) as names,
         count(*)::int as n
  from public.service_coaches sc
  join public.employees e on e.id = sc.coach_id
  where sc.service_id = r.id) co on true
where public.is_staff();

comment on view public.staff_services is '服務紀錄清單。☢️ definer，不要加 security_invoker。';
grant select on public.staff_services to authenticated;
