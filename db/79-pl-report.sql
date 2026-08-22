-- ═══════════════════════════════════════════════════════════════════
-- db/79-pl-report.sql — 損益表：一個月一頁
--
-- 專案：FFF 預約系統（fff-platform）· 第 95 步 · 2026-08-23
--
-- ══ 權責制（第 89 步裁決）═══════════════════════════════════════
-- ☢️ 收入認在【上完課那天】，不是收到錢那天。
--    規則第二篇 1.3、1.4：「每堂完成時均須記錄公司收入」
--    「完成一堂，認列一堂」「尚未完成的堂數不得提前認列」。
--    所以客人八月付 12,000 買 12 堂，八月的收入不是 12,000 ——
--    是他八月實際上完的那幾堂。剩下的是【負債】：我們還欠他課。
--
-- ══☢️☢️ 算不出金額的堂數，只列堂數，不猜金額 ══════════════════
--    決定（Jerec 2026-08-23）。
--    186 張方案裡 178 張沒有「每堂多少錢」—— 搬遷進來的舊卡
--    沒有實收金額。規則第三篇 4：資料不足時維持待確認，
--    【不可以拿現在的檯面價回推】。
--    所以：算得出金額的才進收入與負債；其餘只出現在
--    「還有 N 堂，金額待確認」那一行，【不進任何一個總計】。
--    ☢️ 拿檯面價回推會做出一個看起來很完整、而且永遠沒有人
--       查得出是估的數字。少一個數字比多一個假數字好。
--
-- ══☢️☢️ 「這一堂從哪一張卡扣的」要去 plan_draws 查 ═══════════
--    ☢️ 我第一版查錯地方，結論整個反過來，記在這裡：
--       我查 credit_ledger.plan_id，看到團課那 117 筆全是 null，
--       於是判斷「系統根本沒記是從哪張卡扣的，這是結構性的洞」。
--       ☢️ 錯的。plan_allocate() 一直都有做，只是做在【plan_draws】：
--       每一次扣堂照 opened_at 先進先出拆到卡上，跨卡時會拆成多列。
--       credit_ledger.plan_id 只在【人自己指定】時才有值 ——
--       那是私人課（db/68）才有的動作，團課沒有人在指定。
--    ☢️ 查錯地方拿到的是 0，而【0 看起來就像「這個月沒有團課收入」】。
--       實測：117 筆扣堂，plan_draws 裡 117 筆全部找得到。
--
--    真正算不出金額的原因是另一件事：104 張 GT 卡裡只有 7 張有實收金額
--    （那 7 張是新系統賣出去的），其餘 97 張是搬遷進來的舊卡。
--    所以八月 120 堂裡 6 堂算得出（2,133 元）、114 堂算不出。
--
-- ══ 只算已經最終認列的 ═════════════════════════════════════════
-- ☢️ 待確認的服務紀錄不進收入 —— 跟薪資同一套標準。
--    抽成是這個收入的百分比，兩邊用不同的母數的話，
--    「收入 × 抽成率」永遠對不上薪資，而且沒有人查得出為什麼。
--
-- ══ 備用金不是支出（第 92 步）═══════════════════════════════════
-- ☢️ 提撥備用金是錢從公司一個口袋進另一個口袋，錢還在公司手上。
--    所以只加總 fixed ＋ variable，不加 transfer。
--
-- ══ 每一格都要點得進去 ═════════════════════════════════════════
-- ☢️ 第 80 步學過：看不到明細的總數沒有人敢信，也查不出錯。
--    所以每一塊都帶 lines。
-- ═══════════════════════════════════════════════════════════════════

create or replace function public.pl_report(p_ym date)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $fn$
declare
  v_m    date := date_trunc('month', p_ym)::date;
  v_next date := (v_m + interval '1 month')::date;
  v_to   date := (v_next - 1);

  v_pt_amt   numeric := 0;  v_pt_n   int := 0;
  v_gt_amt   numeric := 0;  v_gt_n   int := 0;
  v_gt_wait  int := 0;      v_pend_n int := 0;  v_pend_amt numeric := 0;
  v_pay      numeric := 0;  v_pay_n  int := 0;
  v_exp      jsonb;         v_exp_amt numeric := 0;  v_exp_n int := 0;
  v_lines    jsonb;         v_gtlines jsonb;  v_paylines jsonb;  v_explines jsonb;
  v_liab     jsonb;         v_liab_c jsonb;
  v_recv_amt numeric := 0;  v_recv_n int := 0;  v_recv jsonb;
  v_val_cr   numeric := 0;  v_val_amt numeric := 0;  v_unval_cr numeric := 0;
  v_snap     jsonb;
begin
  if not public.is_finance() then raise exception '只有負責人和財務看得到損益表'; end if;

  -- ══ 結過的月份讀快照，沒結過才即時算（第 94 步的規矩）═══════
  -- ☢️ 不這樣做的話，月結就白鎖了：薪資鎖住了、損益表卻還會跟著
  --    設定變 —— 兩張報表對同一個月講不同的話，比兩張都會變更糟。
  -- ☢️ close_month() 是在【寫進 month_closes 之前】呼叫這一支的，
  --    所以不會繞回自己。
  select mc.snapshot -> 'pl' into v_snap
    from public.month_closes mc where mc.ym = v_m and mc.status = 'closed';
  if v_snap is not null and v_snap <> 'null'::jsonb then
    return v_snap || jsonb_build_object('closed', true);
  end if;

  -- ══ ① 認列收入：私人課那一側 ═══════════════════════════════
  -- ☢️ revenue_amount 是【這一堂認列多少】，不是收了多少現金。
  --    扣預收的課現場一毛錢都沒收，但它就是這個月的收入。
  select coalesce(sum(sr.revenue_amount + coalesce(sr.travel_fee,0)), 0), count(*)
    into v_pt_amt, v_pt_n
    from public.service_records sr
   where not sr.voided and sr.fin_status = 'final'
     and (sr.done_at at time zone 'Asia/Taipei')::date >= v_m
     and (sr.done_at at time zone 'Asia/Taipei')::date <= v_to;

  select coalesce(jsonb_agg(x order by x->>'when'), '[]'::jsonb) into v_lines
    from (
      select jsonb_build_object(
        'when',   to_char(sr.done_at at time zone 'Asia/Taipei','MM/DD HH24:MI'),
        'what',   sr.service_type,
        'who',    coalesce(c.name, sr.company_name, '—'),
        'coach',  coalesce((select string_agg(e.display_name,'＋' order by e.display_name)
                    from public.service_coaches sc join public.employees e on e.id=sc.coach_id
                   where sc.service_id = sr.id), '—'),
        'heads',  sr.headcount,
        'how',    sr.charge_method,
        'amount', sr.revenue_amount + coalesce(sr.travel_fee,0)) as x
        from public.service_records sr
        left join public.customers c on c.id = sr.customer_id
       where not sr.voided and sr.fin_status = 'final'
         and (sr.done_at at time zone 'Asia/Taipei')::date >= v_m
         and (sr.done_at at time zone 'Asia/Taipei')::date <= v_to
    ) t;

  -- 待確認的：課上了，但金額還沒被財務確認 → 不進收入，但要講出來
  select count(*), coalesce(sum(coalesce(sr.revenue_amount,0)),0)
    into v_pend_n, v_pend_amt
    from public.service_records sr
   where not sr.voided and sr.fin_status <> 'final'
     and (sr.done_at at time zone 'Asia/Taipei')::date >= v_m
     and (sr.done_at at time zone 'Asia/Taipei')::date <= v_to;

  -- ══ ② 認列收入：團課那一側 ═════════════════════════════════
  -- ☢️ 走 plan_draws，不是 credit_ledger.plan_id（理由見檔頭）。
  --    只算【從有實收金額的那張卡扣掉】的堂數。
  select coalesce(sum(d.credits * p.per_credit), 0),
         coalesce(sum(d.credits), 0)::int
    into v_gt_amt, v_gt_n
    from public.plan_draws d
    join public.credit_ledger l on l.id = d.ledger_id
    join public.plans p on p.id = d.plan_id and p.per_credit is not null
   where l.product = 'GT' and l.reason = 'class' and l.delta < 0
     and (l.created_at at time zone 'Asia/Taipei')::date >= v_m
     and (l.created_at at time zone 'Asia/Taipei')::date <= v_to;

  select coalesce(jsonb_agg(x order by x->>'when'), '[]'::jsonb) into v_gtlines
    from (
      select jsonb_build_object(
        'when',   to_char(l.created_at at time zone 'Asia/Taipei','MM/DD HH24:MI'),
        'who',    c.name,
        'credits', d.credits,
        'rate',   round(p.per_credit),
        'amount', round(d.credits * p.per_credit)) as x
        from public.plan_draws d
        join public.credit_ledger l on l.id = d.ledger_id
        join public.plans p on p.id = d.plan_id and p.per_credit is not null
        left join public.customers c on c.id = l.customer_id
       where l.product = 'GT' and l.reason = 'class' and l.delta < 0
         and (l.created_at at time zone 'Asia/Taipei')::date >= v_m
         and (l.created_at at time zone 'Asia/Taipei')::date <= v_to
    ) t;

  -- 從【沒有實收金額的舊卡】扣掉的那幾堂 —— 只列堂數，不猜金額
  select coalesce(sum(d.credits), 0)::int into v_gt_wait
    from public.plan_draws d
    join public.credit_ledger l on l.id = d.ledger_id
    join public.plans p on p.id = d.plan_id
   where l.product = 'GT' and l.reason = 'class' and l.delta < 0
     and p.per_credit is null
     and (l.created_at at time zone 'Asia/Taipei')::date >= v_m
     and (l.created_at at time zone 'Asia/Taipei')::date <= v_to;

  -- ══ ③ 支出：教練薪資 ═══════════════════════════════════════
  select coalesce(sum((x->>'total')::numeric), 0), count(*)
    into v_pay, v_pay_n
    from jsonb_array_elements(public.payroll_month(v_m) -> 'rows') x;
  v_paylines := coalesce(public.payroll_month(v_m) -> 'rows', '[]'::jsonb);

  -- ══ ④ 支出：營運支出（不含備用金提撥）═══════════════════════
  v_exp := public.expense_report(v_m, v_to);
  v_exp_amt := coalesce((v_exp #>> '{sum,pl_amt}')::numeric, 0);
  v_exp_n   := coalesce((v_exp #>> '{sum,n}')::int, 0);
  v_explines := coalesce(v_exp -> 'rows', '[]'::jsonb);

  -- ══ ⑤ 負債：還欠客人幾堂 ═══════════════════════════════════
  select coalesce(jsonb_object_agg(product, bal), '{}'::jsonb) into v_liab_c
    from (select l.product, sum(l.delta) as bal
            from public.credit_ledger l
           where (l.created_at at time zone 'Asia/Taipei')::date <= v_to
           group by l.product having sum(l.delta) <> 0) t;

  -- 這些堂數裡算得出金額的
  -- ☢️ 用 plan_state（它本身就是拿 plan_draws 算的），實測跟帳本
  --    完全對得起來：GT 655＝655、私人課 409＝409。
  --    ☢️ 不要自己拿 total_credits 減 credit_ledger.plan_id ——
  --       第一版那樣算出 853 堂，跟帳本差了 198 堂。
  select coalesce(sum(ps.remaining), 0), coalesce(sum(ps.remaining * ps.per_credit), 0)
    into v_val_cr, v_val_amt
    from public.plan_state ps
   where ps.per_credit is not null and ps.remaining > 0;

  -- ☢️ 這裡是【淨額】：有幾位客人上的課比買的多（餘額是負的），
  --    那是真的欠課，不是資料錯（見第 93 步）。把負的也算進去，
  --    因為「還欠客人幾堂」的答案本來就該扣掉那幾位。
  v_unval_cr := coalesce((select sum(e.value::numeric) from jsonb_each_text(v_liab_c) e), 0)
                - v_val_cr;

  select coalesce(jsonb_agg(x order by (x->>'credits')::int desc), '[]'::jsonb) into v_liab
    from (
      select jsonb_build_object(
        'who',     c.name,
        'tail',    right(c.phone,3),
        'product', l.product,
        'credits', sum(l.delta)) as x
        from public.credit_ledger l
        join public.customers c on c.id = l.customer_id
       where (l.created_at at time zone 'Asia/Taipei')::date <= v_to
       group by c.name, right(c.phone,3), l.product
      having sum(l.delta) <> 0
    ) t;

  -- ══ ⑥ 還沒收到的錢（待入帳）════════════════════════════════
  select coalesce(sum((x->>'amount')::numeric), 0), count(*)
    into v_recv_amt, v_recv_n
    from jsonb_array_elements(public.finance_report(v_m, v_to) -> 'pending') x;
  v_recv := coalesce(public.finance_report(v_m, v_to) -> 'pending', '[]'::jsonb);

  return jsonb_build_object(
    'ok', true,
    'ym', to_char(v_m,'YYYY-MM'),
    'from', v_m, 'to', v_to,
    'made_at', to_char(now() at time zone 'Asia/Taipei','YYYY-MM-DD HH24:MI'),
    'closed', false,

    'income', jsonb_build_object(
      'pt',    jsonb_build_object('amount', v_pt_amt, 'n', v_pt_n),
      'gt',    jsonb_build_object('amount', round(v_gt_amt), 'n', v_gt_n),
      'total', round(v_pt_amt + v_gt_amt)),

    -- 有堂數、沒金額 —— ☢️ 不進上面任何一個總計
    'income_wait', jsonb_build_object(
      'gt_classes',  v_gt_wait,
      'pend_n',      v_pend_n,
      'pend_amount', v_pend_amt),

    'cost', jsonb_build_object(
      'payroll', jsonb_build_object('amount', v_pay, 'n', v_pay_n),
      'expense', jsonb_build_object('amount', v_exp_amt, 'n', v_exp_n),
      'total',   v_pay + v_exp_amt),

    'net', round((v_pt_amt + v_gt_amt) - (v_pay + v_exp_amt)),

    -- ☢️ 支出簿是空的 → 「剩多少」一定偏高，畫面要大聲講
    'expense_empty', (v_exp_n = 0),

    'liability', jsonb_build_object(
      'credits',   coalesce(v_liab_c, '{}'::jsonb),
      'valued_credits', v_val_cr,
      'valued_amount',  round(v_val_amt),
      'unvalued_credits', v_unval_cr),

    'receivable', jsonb_build_object('amount', v_recv_amt, 'n', v_recv_n),

    'lines', jsonb_build_object(
      'income',     v_lines,
      'gt',         v_gtlines,
      'payroll',    v_paylines,
      'expense',    v_explines,
      'liability',  v_liab,
      'receivable', v_recv));
end $fn$;

revoke all on function public.pl_report(date) from public, anon;
grant execute on function public.pl_report(date) to authenticated;

comment on function public.pl_report(date) is
  '損益表：認列收入 − （教練薪資 ＋ 營運支出）。權責制（第 89 步裁決）。'
  '☢️ 算不出金額的堂數只列堂數，不進任何總計 —— 不拿檯面價回推。';


-- ── 月結時把損益也封存起來 ─────────────────────────────────────
-- ☢️ 快照少存一塊，那一塊就永遠是「現在重算」的 ——
--    而月結存在的意義就是【上個月不會再變】。
create or replace function public.close_month(p_ym date, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_m date := date_trunc('month', p_ym)::date;
  v_next date := (v_m + interval '1 month')::date;
  v_chk jsonb; v_snap jsonb; v_me uuid; v_was text;
begin
  if not public.is_finance() then raise exception '只有負責人和財務可以月結'; end if;
  v_chk := public.month_close_check(v_m);
  if not (v_chk->>'ok')::boolean then
    return jsonb_build_object('ok', false, 'why', 'blocked',
      'blocks', v_chk->'blocks', 'items', v_chk->'items',
      'msg', (v_chk->'blocks'->>0));
  end if;

  v_me := public.my_employee_id();
  select status into v_was from public.month_closes where ym = v_m;

  v_snap := jsonb_build_object(
    'ym',       to_char(v_m,'YYYY-MM'),
    'from',     v_m,
    'to',       (v_next - 1),
    'made_at',  now(),
    'made_by',  (select display_name from public.employees where id = v_me),
    'warns',    v_chk->'warns',
    'items',    v_chk->'items',
    'payroll',  public.payroll_month(v_m),
    'finance',  public.finance_report(v_m, (v_next - 1)),
    'expenses', public.expense_report(v_m, (v_next - 1)),
    -- 第 95 步：損益也一起封存
    'pl',       public.pl_report(v_m),
    'stat', jsonb_build_object(
      'gt_credits',  (select coalesce(sum(delta),0) from public.credit_ledger where product='GT'),
      'pt_credits',  (select coalesce(sum(delta),0) from public.credit_ledger where product in ('PT','PGT')),
      'customers',   (select count(*) from public.customers where is_active),
      'no_draw',     v_chk->>'n_no_draw',
      'unpaid',      v_chk->>'n_unpaid'));

  insert into public.month_closes (ym, status, snapshot, closed_by, closed_at, note)
  values (v_m, 'closed', v_snap, v_me, now(), nullif(btrim(p_note),''))
  on conflict (ym) do update
    set status = 'closed', snapshot = excluded.snapshot,
        closed_by = excluded.closed_by, closed_at = excluded.closed_at,
        note = excluded.note;

  insert into public.month_close_log (ym, action, why, changed_by)
  values (v_m, case when v_was = 'open' then 'reclose' else 'close' end,
          nullif(btrim(p_note),''), v_me);

  -- payroll_month 的 rows = 每位教練一列、lines = 每一筆明細（名字跟直覺相反）
  return jsonb_build_object('ok', true, 'ym', to_char(v_m,'YYYY-MM'),
    'reclosed', (v_was = 'open'),
    'warns', v_chk->'warns',
    'perf',  v_snap->'payroll'->'rows',
    'net',   v_snap->'pl'->'net',
    'size',  length(v_snap::text));
end $fn$;

revoke all on function public.close_month(date, text) from public, anon;
grant execute on function public.close_month(date, text) to authenticated;
