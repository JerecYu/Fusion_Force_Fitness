-- ═══════════════════════════════════════════════════════════════════
-- 35 — 對帳報表（第 61 步）
--
-- 專案：FFF 預約系統（fff-platform）· 2026-08-18
--
-- 起因（Jerec）：
--   「目前金流還是臨櫃，財務人員（VC）需要對帳……
--     VC 需要核對當天收的錢與資料上的帳是否相符，
--     而這個功能只能開放給我和 VC。」
--
-- 做兩件事：
--   ① employees 加一個 can_finance —— 誰看得到錢
--   ② finance_report(起日, 迄日) —— 一次回四份資料
--
-- ☢️ 為什麼用【新欄位】而不是用 role
--    VC 的 role 是 coach，他還要點名；role 只有一格，改成 admin
--    就會影響點名那一路的判斷。而且「看得到錢」跟「是什麼職務」
--    本來就是兩件事 —— 以後多一位會計、或 VC 交接，都只要改這一欄。
--
-- ☢️ 為什麼是【函式】不是檢視表
--    四份資料要用同一個日期區間、而且必須套同一道權限。
--    拆成四張檢視表 = 四個地方各寫一次 where can_finance ——
--    漏掉一張就是整份帳外洩，而且不會有任何錯誤訊息。
--    一支函式只有一道門。
-- ═══════════════════════════════════════════════════════════════════

-- ── ① 誰看得到錢 ──────────────────────────────────────────────────
alter table public.employees
  add column if not exists can_finance boolean not null default false;

comment on column public.employees.can_finance is
  '看得到對帳報表（金額、付款方式、經手人）。跟 role 分開 —— VC 是 coach 但要對帳。';

update public.employees set can_finance = true
 where is_active and (role = 'owner' or display_name = 'VC');

create or replace function public.is_finance()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.employees
     where auth_user_id = auth.uid() and is_active and can_finance
  );
$$;

comment on function public.is_finance() is
  '這個登入身分看得到錢嗎。is_staff() 是「是不是員工」，這一支更窄。';


-- ── ② 報表本體 ────────────────────────────────────────────────────
--
-- ☢️ 日期一律用【台北時間】切。資料庫的 TimeZone 是 UTC，
--    直接拿 created_at::date 會把台北時間早上 8 點以前的收款
--    算到前一天 —— 對帳表上會少一筆、前一天多一筆，
--    而兩天的總數又剛好對得起來，所以【非常難發現】。
--
-- ☢️ 收款明細以 paid_at（錢真的到手的時間）為準，不是 created_at。
--    現金兩者相同；匯款是隔幾天按「錢到了」才算收到。
--    VC 數的是抽屜裡的現金和帳戶進帳，所以基準必須是 paid_at。
--    但 created_at 也一起放進去 —— 兩個日期不一樣的那幾筆
--    正是要看清楚的。
--
-- ☢️ 只算 amount is not null 的那些。95 筆 purchase 裡有 93 筆
--    是 8/16 交接匯進來的舊堂數 —— 那些【沒有收到錢】，
--    混進來的話帳面會憑空多出幾十筆零元交易。
create or replace function public.finance_report(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_rows     jsonb;
  v_days     jsonb;
  v_pending  jsonb;
  v_credits  jsonb;
begin
  if not public.is_finance() then
    raise exception '這份報表只有負責人和財務看得到';
  end if;

  if p_from is null or p_to is null then
    raise exception '要給起訖日期';
  end if;
  if p_to < p_from then
    raise exception '結束日期不能早於開始日期';
  end if;
  -- 一次拉太長會把瀏覽器拖垮，而且對帳本來就不會一次看一年
  if p_to - p_from > 366 then
    raise exception '一次最多查一年';
  end if;

  -- ── 收款明細 ───────────────────────────────────────────────────
  with paid as (
    select
      l.id,
      (l.paid_at    at time zone 'Asia/Taipei')::date   as pay_date,
      to_char(l.paid_at    at time zone 'Asia/Taipei', 'HH24:MI')      as pay_time,
      to_char(l.created_at at time zone 'Asia/Taipei', 'MM/DD HH24:MI') as made_at,
      c.name                       as customer_name,
      right(c.phone, 3)            as phone_tail,
      coalesce(pr.label, l.product_code) as plan_label,
      l.delta                      as credits,
      l.amount                     as amount,
      case l.pay_method when 'cash' then '現金'
                        when 'transfer' then '匯款'
                        else coalesce(l.pay_method, '—') end as pay_method,
      e.display_name               as taken_by,
      v.id is not null             as voided,
      substring(v.note, '^沖銷 [0-9a-f-]+：(.*)$') as void_reason,
      ve.display_name              as voided_by,
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
  )
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
                   'void_n',      count(*) filter (where voided),
                   'void_amt',    coalesce(sum(amount) filter (where voided), 0),
                   'net_amt',     coalesce(sum(amount) filter (where not voided), 0),
                   'credits_sold',coalesce(sum(credits) filter (where not voided), 0)
                 ) as d
            from paid group by pay_date
        ) s
    ), '[]'::jsonb)
  into v_rows, v_days
  from paid p;

  -- ── 待入帳的匯款 ───────────────────────────────────────────────
  -- ☢️ 【故意不受日期區間限制】。這一塊問的是「還沒收到的錢」，
  --    而最該被看到的正是拖最久、已經掉出這次查詢區間的那幾筆。
  select coalesce(jsonb_agg(to_jsonb(u) order by u.made_raw), '[]'::jsonb)
    into v_pending
  from (
    select
      to_char(l.created_at at time zone 'Asia/Taipei', 'MM/DD HH24:MI') as made_at,
      l.created_at as made_raw,
      c.name            as customer_name,
      right(c.phone, 3) as phone_tail,
      l.delta           as credits,
      l.amount          as amount,
      e.display_name    as taken_by,
      round(extract(epoch from now() - l.created_at) / 86400)::int as waited_days
    from public.credit_ledger l
    join public.customers c on c.id = l.customer_id
    left join public.employees e on e.id = l.created_by
    where l.pay_method = 'transfer'
      and l.paid_at is null
      and not exists (
        select 1 from public.credit_ledger x
         where x.reason = 'adjust' and x.note like '沖銷 ' || l.id::text || '%'
      )
  ) u;

  -- ── 堂數異動 ───────────────────────────────────────────────────
  -- 賣出去的堂數被用掉多少。不是金流，是課堂消耗。
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
    'credits', v_credits
  );
end;
$$;

comment on function public.finance_report(date, date) is
  '對帳報表：收款明細／每日合計／待入帳匯款／堂數異動。只有 can_finance 過得了。';

revoke all on function public.finance_report(date, date) from public, anon;
grant execute on function public.finance_report(date, date) to authenticated;
