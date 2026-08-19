-- ============================================================
-- 43 · 企業包班改成「地區 × 時數」費率制 ＋ 財務可以改最終業績金額
--
-- 起因：《財務與教練薪資整合規則》2026-08-19【正式補全版】把企業包班改了。
--
--   舊版：「由指定核定人員人工核定整案總價；系統不採自動時數計價」
--   新版：有價目表了 ——
--         大台北地區    3,300 元／小時（含交通費）
--         非大台北地區  3,600 元／小時（含交通費）
--         7 人（含）以上開班，人數不限
--
-- ☢️ 第 71 步是照舊版寫的：要求人工填「核定整案總價」、而且核准人必填。
--    那個邏輯現在是錯的，所以這一步把它換掉。
--    幸好 service_records 目前是空的，沒有任何一筆用舊規則算出來的資料。
--
-- ☢️ 另一個改動：新版寫「財務最終認列之【實際收入】」（舊版是「核定整案總價」）。
--    系統算出來的是【報價】，財務認列的才是【實際收入】——
--    所以 finalize_service 要能讓財務改金額，而且要留下原本算多少。
-- ============================================================

-- ── ① 企業包班進 products ───────────────────────────────────
-- ☢️ 價格只放一個地方。第 68 步的教訓：同一個數字散在程式裡，
--    改價時一定會漏掉一個。
alter table public.products drop constraint if exists products_kind_check;
alter table public.products add constraint products_kind_check
  check (kind in ('trial','single','pack','half','hourly'));

insert into public.products (code, product, label, kind, headcount, credits, price, is_active, sort_order) values
  ('CORP-TPE', 'CORP', '企業包班（大台北）',   'hourly', 1, 1, 3300, true, 1),
  ('CORP-OUT', 'CORP', '企業包班（非大台北）', 'hourly', 1, 1, 3600, true, 2)
on conflict (code) do update set
  product = excluded.product, label = excluded.label, kind = excluded.kind,
  headcount = excluded.headcount, credits = excluded.credits, price = excluded.price,
  is_active = excluded.is_active, sort_order = excluded.sort_order;

comment on column public.products.kind is
  'trial＝體驗／single＝單堂／pack＝預付包／half＝半堂（內部）／hourly＝按小時（企業包班）。';

-- ☢️ hourly 的 headcount 沒有意義（企業包班不套用 PT／PGT 人數規格），
--    填 1 只是為了滿足 not null。真正的人數下限寫在 add_service 裡（7 人）。

-- ── ② 財務最終業績金額 ──────────────────────────────────────
alter table public.service_records
  add column if not exists perf_final integer check (perf_final is null or perf_final >= 0);

comment on column public.service_records.perf_amount is
  '系統依規則算出來的教練業績基礎（報價）。☢️ 諧動活動是 0（走鐘點費）。';
comment on column public.service_records.perf_final is
  '財務最終認列的業績金額。null＝就用 perf_amount。☢️ 算薪水要讀 coalesce(perf_final, perf_amount)。';

-- ── ③ 登記：改寫企業包班那一段 ──────────────────────────────
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
  v_area    text;
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

  elsif v_type = 'EVENT' then
    if v_n > 2 then
      return jsonb_build_object('ok', false, 'why', 'coach_n',
        'msg', '諧動外派活動單次最多派 2 位教練');
    end if;
    v_raw := nullif(p_data->>'hours','')::numeric;
    if v_raw is null or v_raw <= 0 then
      return jsonb_build_object('ok', false, 'why', 'hours', 'msg', '要填活動時數');
    end if;
    -- ☢️ 無條件進位只有【諧動外派活動】有這條規則（第二篇 3）。
    --    企業包班沒有，所以下面那一段不會進位 —— 不要「順手」統一。
    v_hours := ceil(v_raw)::numeric(4,1);
    v_travel := 500;
    v_rev  := (v_n * v_hours * 600)::integer + (v_hours * 600)::integer;
    v_perf := 0;

  else -- CORP 企業包班（新版第二篇 4）
    if v_n <> 1 then
      return jsonb_build_object('ok', false, 'why', 'coach_n',
        'msg', '企業包班單次至多 1 位主導教練');
    end if;

    -- 地區決定費率。☢️ 費率在 products 表，不寫死在這裡。
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
    -- ☢️ 這裡【不進位】。進位是諧動外派活動的規則，企業包班沒有這一條。
    v_hours := v_raw::numeric(4,1);

    -- 7 人（含）以上開班，人數不限
    if v_head is null or v_head < 7 then
      return jsonb_build_object('ok', false, 'why', 'head',
        'msg', '企業包班 7 人（含）以上才開班，人數上限不限');
    end if;

    -- 每小時費用【已含交通費】，所以 travel_fee 是 0，不要再加一次
    v_rev    := round(v_price * v_hours)::integer;
    v_travel := 0;
    v_perf   := v_rev;
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
    case when v_type = 'CORP' then null else v_head end,
    v_att,
    case when v_type in ('EVENT') then null else v_code end,
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

  return jsonb_build_object('ok', true, 'id', v_id,
    'revenue', v_rev, 'travel', v_travel, 'perf', v_perf,
    'hours', v_hours, 'rate', v_price, 'total', v_rev + v_travel);
end $fn$;

revoke all on function public.add_service(jsonb) from public;
grant execute on function public.add_service(jsonb) to authenticated;

-- ── ④ 最終認列：財務可以改金額 ──────────────────────────────
-- ☢️ 換簽名了（多一個 p_perf），舊的要先 drop。
--    兩個同名函式都在的話，PostgREST 有機會挑錯那一個。
drop function if exists public.finalize_service(uuid, text);

create or replace function public.finalize_service(
  p_id uuid, p_note text default null, p_perf integer default null)
returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare v_r record;
begin
  if not public.is_finance() then
    raise exception '只有財務可以做最終認列';
  end if;
  if p_perf is not null and p_perf < 0 then
    return jsonb_build_object('ok', false, 'why', 'bad_amount', 'msg', '業績金額不能是負的');
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
     set fin_status = 'final',
         fin_by = public.my_employee_id(),
         fin_at = now(),
         -- ☢️ perf_amount【不動】。它是系統照規則算的那個數字，
         --    留著才看得出財務改了多少、改了什麼。
         perf_final = coalesce(p_perf, perf_amount),
         manual_note = coalesce(nullif(p_note,''), manual_note)
   where id = p_id;

  return jsonb_build_object('ok', true, 'id', p_id,
    'perf_final', coalesce(p_perf, v_r.perf_amount),
    'changed', (p_perf is not null and p_perf <> v_r.perf_amount));
end $fn$;

revoke all on function public.finalize_service(uuid, text, integer) from public;
grant execute on function public.finalize_service(uuid, text, integer) to authenticated;

-- ── ⑤ 清單多三欄 ────────────────────────────────────────────
-- ☢️☢️ 這裡【一定】要 drop + create，不能 create or replace。
--    新欄位 approved_headcount 要插在 headcount 後面，而
--    create or replace【只能在最後面加欄位，不能插中間】——
--    實際跑出來的錯是「cannot change name of view column
--    "attended_count" to "approved_headcount"」，看起來像改名，其實是插隊。
-- ☢️ 而 drop view 會把 GRANT 一起帶走（第 66 步把點名頁弄壞的就是這個）。
--    所以下面的 grant 不能省。
drop view if exists public.staff_services;
create view public.staff_services as
select r.id,
       r.service_type,
       r.done_at,
       (r.done_at at time zone 'Asia/Taipei')::date as done_date,
       to_char(r.done_at at time zone 'Asia/Taipei', 'HH24:MI') as done_time,
       c.name                        as customer_name,
       right(c.phone, 3)             as phone_tail,
       r.company_name,
       r.headcount,
       r.approved_headcount,
       r.attended_count,
       r.charge_method,
       r.product_code,
       r.revenue_amount,
       r.travel_fee,
       r.perf_amount,
       r.perf_final,
       coalesce(r.perf_final, r.perf_amount) as perf_pay,
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
