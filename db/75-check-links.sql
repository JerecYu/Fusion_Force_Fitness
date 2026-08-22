-- ═══════════════════════════════════════════════════════════════════
-- db/75-check-links.sql — 月結檢查的每一條都要能點過去處理
--
-- 專案：FFF 預約系統（fff-platform）· 第 94 步收尾 · 2026-08-22
--
-- ☢️ 原本 blocks / warns 是【一串字】。畫面只能把字印出來，
--    然後人要自己想「這句話該去哪一頁處理」。
--    ☢️ 而擋住月結的那句話，正好是最需要馬上處理的那句話。
--
-- ══ 改成一串物件 ═══════════════════════════════════════════════
--    { code, msg, n, go }
--    code ＝ 這是哪一種問題（畫面可以據此決定樣式）
--    n    ＝ 幾筆
--    go   ＝ 去哪一頁處理（沒有頁可以去的就【不給】—— 見下）
--
-- ☢️☢️ 有些條目【故意不給 go】：
--    「這個月還沒過完」不是問題，沒有東西要處理。
--    「待補扣」目前<b>沒有任何一頁列得出那幾筆</b> —— 給一個連結
--    連到看不到它們的頁面，比不給連結更糟：人點過去、找不到、
--    然後以為是自己不會用。
--
-- ☢️ 這一支改了回傳的形狀，所以 close_month 取訊息的地方要跟著改
--    （'blocks'->>0 變成 'blocks'->0->>'msg'）。
--    ☢️ plpgsql 不會在建立時檢查這種東西 —— 兩支要一起換，
--       漏掉一支的話錯誤訊息會變成整包 JSON，而且不會報錯。
-- ═══════════════════════════════════════════════════════════════════

create or replace function public.month_close_check(p_ym date)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $fn$
declare
  v_m date := date_trunc('month', p_ym)::date;
  v_next date := (v_m + interval '1 month')::date;
  v_pending int; v_bad int; v_nodraw int; v_unpaid int; v_closed text;
  v_blocks jsonb := '[]'::jsonb;
  v_warns  jsonb := '[]'::jsonb;
begin
  if not public.is_finance() then raise exception '只有負責人和財務可以月結'; end if;

  select status into v_closed from public.month_closes where ym = v_m;
  if v_closed = 'closed' then
    v_blocks := v_blocks || jsonb_build_object(
      'code', 'already_closed',
      'msg', format('%s 已經結過了 —— 要改的話先「重開這個月」', to_char(v_m,'YYYY 年 MM 月')));
  end if;

  if v_m > date_trunc('month', current_date)::date then
    v_blocks := v_blocks || jsonb_build_object('code','future','msg','不能結未來的月份');
  end if;

  -- ☢️ 待確認的服務紀錄【根本沒進薪資】。這時候結帳等於把一個
  --    明知不完整的數字鎖起來，而且鎖起來之後就沒有人會再去看它。
  select count(*) into v_pending from public.service_records
   where not voided and fin_status <> 'final'
     and (done_at at time zone 'Asia/Taipei')::date >= v_m
     and (done_at at time zone 'Asia/Taipei')::date <  v_next;
  if v_pending > 0 then
    v_blocks := v_blocks || jsonb_build_object(
      'code','pending', 'n', v_pending, 'go','service.html',
      'msg', format('還有 %s 筆服務紀錄是「待確認」—— 那些沒有算進任何人的薪資，'
                    '去服務登記用「整月一次認列」', v_pending));
  end if;

  -- ☢️ 帳本與方案對不起來 ＝ 堂數資料自己矛盾。這種狀態下的預收餘額
  --    是錯的，而損益表要把預收餘額當負債列出來。
  select count(*) into v_bad from public.staff_plan_check where not ok;
  if v_bad > 0 then
    v_blocks := v_blocks || jsonb_build_object(
      'code','plan_bad', 'n', v_bad, 'go','report.html',
      'msg', format('有 %s 位客人的帳本餘額跟方案餘額對不起來 —— 先查清楚再結', v_bad));
  end if;

  -- 以下三種是「數字是對的，只是還不完整」→ 只提醒
  if v_m = date_trunc('month', current_date)::date then
    -- ☢️ 沒有 go：這不是問題，沒有東西要處理。
    v_warns := v_warns || jsonb_build_object('code','month_open',
      'msg','這個月還沒過完 —— 結了之後這個月剩下的日子還會有新資料，那些不會進快照');
  end if;

  select count(*) into v_nodraw from public.service_records
   where charge_method='plan' and not voided and plan_id is null and customer_id is not null;
  if v_nodraw > 0 then
    -- ☢️ 沒有 go：目前沒有任何一頁列得出這幾筆。給一個連到看不到它們的
    --    頁面，比不給連結更糟 —— 人點過去、找不到、以為是自己不會用。
    v_warns := v_warns || jsonb_build_object('code','no_draw', 'n', v_nodraw,
      'msg', format('還有 %s 筆「扣預收」沒扣到任何一張卡 —— 那幾位客人的預收餘額會偏高', v_nodraw));
  end if;

  select count(*) into v_unpaid from public.credit_ledger
   where reason='purchase' and pay_method='transfer' and paid_at is null;
  if v_unpaid > 0 then
    v_warns := v_warns || jsonb_build_object('code','unpaid', 'n', v_unpaid, 'go','report.html',
      'msg', format('還有 %s 筆匯款待入帳 —— 那是應收，不是這個月的收入', v_unpaid));
  end if;

  return jsonb_build_object(
    'ok', jsonb_array_length(v_blocks) = 0,
    'ym', to_char(v_m,'YYYY-MM'),
    'blocks', v_blocks,
    'warns',  v_warns,
    'n_pending', v_pending, 'n_plan_bad', v_bad,
    'n_no_draw', v_nodraw, 'n_unpaid', v_unpaid);
end $fn$;

revoke all on function public.month_close_check(date) from public, anon;
grant execute on function public.month_close_check(date) to authenticated;


-- ── close_month：取訊息的方式要跟著換 ──────────────────────────
-- ☢️ 只改上面那一支的話，被擋下來時回傳的 msg 會變成一整包 JSON，
--    而且【不會報錯】。
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
      'blocks', v_chk->'blocks', 'msg', (v_chk->'blocks'->0->>'msg'));
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
    'payroll',  public.payroll_month(v_m),
    'finance',  public.finance_report(v_m, (v_next - 1)),
    'expenses', public.expense_report(v_m, (v_next - 1)),
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
    'size',  length(v_snap::text));
end $fn$;

revoke all on function public.close_month(date, text) from public, anon;
grant execute on function public.close_month(date, text) to authenticated;
