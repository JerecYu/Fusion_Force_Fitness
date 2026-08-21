-- ═══════════════════════════════════════════════════════════════════
-- db/62-finance-report-merge.sql — 對帳報表納入服務登記的錢
--
-- 專案：FFF 預約系統（fff-platform）· 第 91 步 · 2026-08-21
--
-- 起因：對帳報表（第 61 步）的每一段 —— 收款明細、每日現金／匯款小計、
--   待入帳 —— 資料來源【都只有 credit_ledger】。
--   也就是說私人課、企業包班、外派活動的收款，一塊錢都沒出現在報表上。
--   ☢️ 而那個數字【看起來完全合理】：八月的對帳報表就是全店只有 GT 的收入。
--      這是「有資料但沒人看得到」，最容易被誤判成生意變差。
--
-- ══ 兩邊的錢長得不一樣 ═══════════════════════════════════════════
--   GT 那一側：錢在【購課】時收（credit_ledger.amount／pay_method／paid_at），
--              一次收一整包，之後逐堂銷課。
--   私人課那一側：單堂的錢在【上課當下】收（service_payments），
--              扣預收的錢在購課時就收了（PT 購課還沒做，所以現在是 0）。
--
-- ☢️ 合併的鍵是【到帳日】（paid_at），不是上課日、也不是登記日。
--    對帳報表回答的是「這一天銀行和抽屜裡進來多少錢」，所以只認到帳日。
--    還沒到帳的（paid_at is null）一律進「待入帳」，不進當日小計。
--
-- ☢️ 作廢的判定兩邊寫法不同，不能寫成同一條：
--    GT 走「沖銷」——另外插一列 reason='adjust'、note 是「沖銷 <id>：原因」。
--    服務登記走 service_records.voided 旗標。
--    漏掉任何一種，作廢的錢都會被算成收入。
--
-- ☢️ 沒有最終認列的收款【照樣算收入】。
--    收款和認列是兩件事：錢真的進來了，只是還沒完成財務認列。
--    但要標出來（fin_pending），不然對帳的人不知道那筆還會變。
--
-- ══ 相容性 ═══════════════════════════════════════════════════════
-- ☢️ 舊的 key 一個都沒有拿掉，只有新增 —— report.html 不改也不會壞。
--    新增：rows/pending 的 source、payer、method；days 的 sub_n、sub_amt；
--    以及最上層多一個 unpaid（應收未收）。
-- ☢️ 用 create or replace，不是 drop + create。replace 保留 GRANT；
--    drop 會把 GRANT 一起帶走，而症狀是「查無資料」不是「沒有權限」（第 66 步）。
-- ═══════════════════════════════════════════════════════════════════

create or replace function public.finance_report(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $fn$
declare
  v_rows    jsonb;
  v_days    jsonb;
  v_pending jsonb;
  v_unpaid  jsonb;
  v_credits jsonb;
begin
  if not public.is_finance() then
    raise exception '這份報表只有負責人和財務看得到';
  end if;
  if p_from is null or p_to is null then raise exception '要給起訖日期'; end if;
  if p_to < p_from then raise exception '結束日期不能早於開始日期'; end if;
  if p_to - p_from > 366 then raise exception '一次最多查一年'; end if;

  -- ══ 收款明細：兩邊 union ═════════════════════════════════════
  with gt as (
    select
      (l.paid_at at time zone 'Asia/Taipei')::date                      as pay_date,
      to_char(l.paid_at at time zone 'Asia/Taipei', 'HH24:MI')          as pay_time,
      to_char(l.created_at at time zone 'Asia/Taipei', 'MM/DD HH24:MI') as made_at,
      'GT 購課'::text                    as source,
      c.name                             as customer_name,
      right(c.phone, 3)                  as phone_tail,
      coalesce(pr.label, l.product_code) as plan_label,
      l.delta                            as credits,
      l.amount                           as amount,
      case l.pay_method when 'cash' then '現金'
                        when 'transfer' then '匯款'
                        else coalesce(l.pay_method, '—') end as pay_method,
      null::text                         as payer,
      false                              as fin_pending,
      e.display_name                     as taken_by,
      v.id is not null                   as voided,
      substring(v.note, '^沖銷 [0-9a-f-]+：(.*)$') as void_reason,
      ve.display_name                    as voided_by,
      to_char(v.created_at at time zone 'Asia/Taipei', 'MM/DD HH24:MI') as voided_at
    from public.credit_ledger l
    join public.customers c on c.id = l.customer_id
    left join public.employees e on e.id = l.created_by
    left join lateral (
      select x.id, x.note, x.created_by, x.created_at
        from public.credit_ledger x
       where x.reason = 'adjust'
         and x.note like '沖銷 ' || l.id::text || '%'
       order by x.created_at limit 1
    ) v on true
    left join public.employees ve on ve.id = v.created_by
    left join public.products pr on pr.code = l.product_code
    where l.reason = 'purchase'
      and l.amount is not null
      and l.paid_at is not null
      and (l.paid_at at time zone 'Asia/Taipei')::date between p_from and p_to
  ),
  sv as (
    select
      (p.paid_at at time zone 'Asia/Taipei')::date                      as pay_date,
      to_char(p.paid_at at time zone 'Asia/Taipei', 'HH24:MI')          as pay_time,
      to_char(p.created_at at time zone 'Asia/Taipei', 'MM/DD HH24:MI') as made_at,
      '服務登記'::text                   as source,
      coalesce(c.name, s.company_name)   as customer_name,
      right(c.phone, 3)                  as phone_tail,
      -- 標籤：課別 ＋ 上課時間，讓對帳的人認得出是哪一堂
      (case s.service_type
         when 'PT'      then '私人教練課' when 'PGT'     then '私人團體班'
         when 'PT_OUT'  then 'PT 外派'    when 'PGT_OUT' then 'PGT 外派'
         when 'CORP'    then '企業包班'   when 'EVENT'   then '諧動外派活動'
         else s.service_type end)
        || ' ' || to_char(s.done_at at time zone 'Asia/Taipei', 'MM/DD HH24:MI') as plan_label,
      null::integer                      as credits,
      p.amount                           as amount,
      case p.method when 'cash' then '現金'
                    when 'transfer' then '匯款'
                    when 'subsidy' then '補助'
                    else '其他' end      as pay_method,
      p.payer                            as payer,
      (s.fin_status <> 'final')          as fin_pending,
      e.display_name                     as taken_by,
      s.voided                           as voided,
      s.void_reason                      as void_reason,
      ve.display_name                    as voided_by,
      to_char(s.voided_at at time zone 'Asia/Taipei', 'MM/DD HH24:MI') as voided_at
    from public.service_payments p
    join public.service_records s on s.id = p.service_id
    left join public.customers c on c.id = s.customer_id
    left join public.employees e on e.id = p.created_by
    left join public.employees ve on ve.id = s.voided_by
    where p.paid_at is not null
      and (p.paid_at at time zone 'Asia/Taipei')::date between p_from and p_to
  ),
  paid as (select * from gt union all select * from sv)
  select
    coalesce(jsonb_agg(to_jsonb(p) order by p.pay_date, p.pay_time), '[]'::jsonb),
    coalesce((
      select jsonb_agg(d order by d->>'pay_date')
        from (
          select jsonb_build_object(
                   'pay_date',    pay_date,
                   'cash_n',      count(*) filter (where pay_method = '現金' and not voided),
                   'cash_amt',    coalesce(sum(amount) filter (where pay_method = '現金' and not voided), 0),
                   'tr_n',        count(*) filter (where pay_method = '匯款' and not voided),
                   'tr_amt',      coalesce(sum(amount) filter (where pay_method = '匯款' and not voided), 0),
                   -- 新增：政府補助（Usports／動滋券）自己一欄。
                   -- ☢️ 混進現金或匯款的話，跟銀行對帳就永遠差那幾百塊。
                   'sub_n',       count(*) filter (where pay_method = '補助' and not voided),
                   'sub_amt',     coalesce(sum(amount) filter (where pay_method = '補助' and not voided), 0),
                   'void_n',      count(*) filter (where voided),
                   'void_amt',    coalesce(sum(amount) filter (where voided), 0),
                   'net_amt',     coalesce(sum(amount) filter (where not voided), 0),
                   'gt_amt',      coalesce(sum(amount) filter (where source = 'GT 購課' and not voided), 0),
                   'sv_amt',      coalesce(sum(amount) filter (where source = '服務登記' and not voided), 0),
                   'credits_sold',coalesce(sum(credits) filter (where not voided), 0)
                 ) as d
            from paid group by pay_date
        ) s
    ), '[]'::jsonb)
  into v_rows, v_days
  from paid p;

  -- ══ 待入帳：兩邊都要 ═════════════════════════════════════════
  select coalesce(jsonb_agg(to_jsonb(u) order by u.made_raw), '[]'::jsonb)
    into v_pending
  from (
    select
      to_char(l.created_at at time zone 'Asia/Taipei', 'MM/DD HH24:MI') as made_at,
      l.created_at      as made_raw,
      'GT 購課'::text   as source,
      c.name            as customer_name,
      right(c.phone, 3) as phone_tail,
      l.delta           as credits,
      l.amount          as amount,
      '匯款'::text      as method,
      null::text        as payer,
      e.display_name    as taken_by,
      round(extract(epoch from now() - l.created_at) / 86400)::int as waited_days
    from public.credit_ledger l
    join public.customers c on c.id = l.customer_id
    left join public.employees e on e.id = l.created_by
    where l.pay_method = 'transfer'
      and l.paid_at is null
      and not exists (
        select 1 from public.credit_ledger x
         where x.reason = 'adjust' and x.note like '沖銷 ' || l.id::text || '%')

    union all

    -- ☢️ 政府補助的帳齡跟匯款完全不同（匯款是幾天，申請撥款可能是幾個月），
    --    所以 method 一定要帶出去，不然畫面上會把「等三天」和「等三個月」
    --    放在同一個「怎麼還沒到」的清單裡。
    select
      to_char(p.created_at at time zone 'Asia/Taipei', 'MM/DD HH24:MI'),
      p.created_at,
      '服務登記'::text,
      coalesce(c.name, s.company_name),
      right(c.phone, 3),
      null::integer,
      p.amount,
      case p.method when 'transfer' then '匯款' when 'subsidy' then '補助' else '其他' end,
      p.payer,
      e.display_name,
      round(extract(epoch from now() - p.created_at) / 86400)::int
    from public.service_payments p
    join public.service_records s on s.id = p.service_id
    left join public.customers c on c.id = s.customer_id
    left join public.employees e on e.id = p.created_by
    where p.paid_at is null and not s.voided
  ) u;

  -- ══ 應收未收：該收，但一毛都還沒記 ═══════════════════════════
  -- ☢️ 這跟「待入帳」是【兩件不同的事】：
  --    待入帳   ＝ 錢在路上（已經記了一筆收款，只是還沒到帳）。
  --    應收未收 ＝ 錢還沒開始走（整筆服務連一列收款都沒有，或只收了一部分）。
  --    少了這一塊，報表會說「八月收了 107,850」，
  --    而那個【沒收到的 4,000 塊不會出現在任何一個畫面上】。
  -- ☢️ due_amount 只有單堂才不是 0（見 staff_service_pay），
  --    所以扣預收與體驗課本來就進不來，不必再過濾一次。
  select coalesce(jsonb_agg(to_jsonb(w) order by w.done_raw), '[]'::jsonb)
    into v_unpaid
  from (
    select
      (s.done_at at time zone 'Asia/Taipei')::date                    as on_date,
      to_char(s.done_at at time zone 'Asia/Taipei', 'MM/DD HH24:MI')  as done_at,
      s.done_at         as done_raw,
      coalesce(c.name, s.company_name) as customer_name,
      right(c.phone, 3) as phone_tail,
      (case s.service_type
         when 'PT'      then '私人教練課' when 'PGT'     then '私人團體班'
         when 'PT_OUT'  then 'PT 外派'    when 'PGT_OUT' then 'PGT 外派'
         when 'CORP'    then '企業包班'   when 'EVENT'   then '諧動外派活動'
         else s.service_type end)       as kind,
      -- ☢️ 教練不在 service_records 上 —— 一堂課可以有兩個教練，
      --    所以掛在 service_coaches。寫成 s.coach_id 是【建得起來、跑起來才爆】：
      --    plpgsql 不會在建立函式時檢查 SQL 內容。
      coalesce((select string_agg(e2.display_name, '、'
                                  order by sc.is_lead desc, e2.display_name)
                  from public.service_coaches sc
                  join public.employees e2 on e2.id = sc.coach_id
                 where sc.service_id = s.id), '') as coach_name,
      v.due_amount      as due_amount,
      v.paid_amount     as paid_amount,
      (v.due_amount - v.paid_amount)    as gap_amount,
      round(extract(epoch from now() - s.done_at) / 86400)::int as waited_days
    from public.service_records s
    join public.staff_service_pay v on v.service_id = s.id
    left join public.customers c on c.id = s.customer_id
    where not s.voided
      and v.due_amount > v.paid_amount
      and (s.done_at at time zone 'Asia/Taipei')::date between p_from and p_to
  ) w;

  -- ══ 堂數異動（沒有動）═══════════════════════════════════════
  select coalesce(jsonb_agg(to_jsonb(k) order by k.when_raw), '[]'::jsonb)
    into v_credits
  from (
    select
      (l.created_at at time zone 'Asia/Taipei')::date as on_date,
      to_char(l.created_at at time zone 'Asia/Taipei', 'HH24:MI') as on_time,
      l.created_at as when_raw,
      c.name            as customer_name,
      right(c.phone, 3) as phone_tail,
      case l.reason when 'class'    then '上課扣堂'
                    when 'purchase' then '購課／匯入'
                    when 'adjust'   then '調整'
                    else l.reason end as kind,
      l.delta        as credits,
      coalesce(s.title, '') as session_title,
      case when s.session_date is null then ''
           else to_char(s.session_date, 'MM/DD') || ' ' ||
                to_char(s.start_time, 'HH24:MI') end as session_when,
      coalesce(sc.display_name, '') as coach_name,
      coalesce(l.note, '')          as note,
      coalesce(e.display_name, '')  as by_name
    from public.credit_ledger l
    join public.customers c on c.id = l.customer_id
    left join public.employees e on e.id = l.created_by
    left join public.bookings b on b.id = l.booking_id
    left join public.class_sessions s on s.id = b.session_id
    left join public.employees sc on sc.id = s.coach_id
    where (l.created_at at time zone 'Asia/Taipei')::date between p_from and p_to
      and l.reason in ('class', 'adjust')
  ) k;

  return jsonb_build_object(
    'ok',      true,
    'from',    p_from,
    'to',      p_to,
    'made_at', to_char(now() at time zone 'Asia/Taipei', 'YYYY-MM-DD HH24:MI'),
    'rows',    v_rows,
    'days',    v_days,
    'pending', v_pending,
    'unpaid',  v_unpaid,
    'credits', v_credits
  );
end;
$fn$;

comment on function public.finance_report(date, date) is
  '對帳報表。收款明細與每日小計【同時包含 GT 購課與服務登記的收款】，合併的鍵是到帳日。'
  '待入帳兩邊都收，而且帶 method —— 匯款等幾天、政府補助等幾個月，不能混在同一個清單裡看。'
  'unpaid ＝ 應收未收（該收但連一列收款都沒有），跟待入帳不是同一件事。';
