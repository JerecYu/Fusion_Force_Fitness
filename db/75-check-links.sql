-- ═══════════════════════════════════════════════════════════════════
-- db/75-check-links.sql — 月結檢查的每一條都要能點過去處理
--
-- 專案：FFF 預約系統（fff-platform）· 第 94 步收尾 · 2026-08-22
--
-- ☢️ 原本 blocks / warns 是【一串字】。畫面只能把字印出來，
--    然後人要自己想「這句話該去哪一頁處理」。
--    而擋住月結的那句話，正好是最需要馬上處理的那句話。
--
-- ══☢️☢️ 這一支我做錯過一次，記在這裡 ═════════════════════════
--    第一版我直接把 blocks / warns 從「一串字」改成「一串物件」。
--
--    ☢️ 資料庫一套用，就【立刻對所有還在用舊網頁的人生效】——
--       而網頁是另外推送的。中間那段時間兩邊對不起來，
--       舊的薪資報表照樣把物件當字印 → 畫面上出現 [object Object]。
--       Jerec 當場就撞到了。
--    ☢️ 而且它【不會報錯】。畫面照樣長出來，只是內容是垃圾。
--
--    教訓：資料庫回傳的欄位【只能加，不能改形狀】。
--    前端和資料庫不是同一秒上線的 —— 改形狀等於要求兩邊同時切換，
--    而那件事做不到。
--
-- ══ 改正後的做法 ═══════════════════════════════════════════════
--    blocks / warns  永遠是【一串字】（舊網頁看得懂，不會壞）
--    items           新的，一串物件 { kind, code, msg, n, go }
--                    新網頁讀這個；舊網頁看不到這個欄位，也不會壞。
--
--    kind ＝ block（擋住）／ warn（只提醒）
--    go   ＝ 去哪一頁處理
--
-- ☢️ 有些條目【故意不給 go】：
--    「這個月還沒過完」不是問題，沒有東西要處理。
--    「待補扣」目前【沒有任何一頁列得出那幾筆】—— 給一個連結
--    連到看不到它們的頁面，比不給連結更糟：人點過去、找不到、
--    然後以為是自己不會用。
--
-- ☢️ close_month 取訊息的地方跟著用字串版（blocks->>0）。
--    兩支要一起看 —— plpgsql 不會在建立時檢查這種東西，
--    接錯的話被擋時的訊息會變成一整包 JSON，而且不報錯。
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
  v_blocks text[] := '{}';
  v_warns  text[] := '{}';
  v_items  jsonb  := '[]'::jsonb;
  v_msg text;
begin
  if not public.is_finance() then raise exception '只有負責人和財務可以月結'; end if;

  select status into v_closed from public.month_closes where ym = v_m;
  if v_closed = 'closed' then
    v_msg := format('%s 已經結過了 —— 要改的話先「重開這個月」', to_char(v_m,'YYYY 年 MM 月'));
    v_blocks := v_blocks || v_msg;
    v_items := v_items || jsonb_build_object('kind','block','code','already_closed','msg',v_msg);
  end if;

  if v_m > date_trunc('month', current_date)::date then
    v_msg := '不能結未來的月份';
    v_blocks := v_blocks || v_msg;
    v_items := v_items || jsonb_build_object('kind','block','code','future','msg',v_msg);
  end if;

  -- ☢️ 待確認的服務紀錄【根本沒進薪資】。這時候結帳等於把一個
  --    明知不完整的數字鎖起來，而且鎖起來之後就沒有人會再去看它。
  select count(*) into v_pending from public.service_records
   where not voided and fin_status <> 'final'
     and (done_at at time zone 'Asia/Taipei')::date >= v_m
     and (done_at at time zone 'Asia/Taipei')::date <  v_next;
  if v_pending > 0 then
    v_msg := format('還有 %s 筆服務紀錄是「待確認」—— 那些沒有算進任何人的薪資，'
                    '去服務登記用「整月一次認列」', v_pending);
    v_blocks := v_blocks || v_msg;
    v_items := v_items || jsonb_build_object('kind','block','code','pending',
                            'n',v_pending,'go','service.html','msg',v_msg);
  end if;

  -- ☢️ 帳本與方案對不起來 ＝ 堂數資料自己矛盾。這種狀態下的預收餘額
  --    是錯的，而損益表要把預收餘額當負債列出來。
  select count(*) into v_bad from public.staff_plan_check where not ok;
  if v_bad > 0 then
    v_msg := format('有 %s 位客人的帳本餘額跟方案餘額對不起來 —— 先查清楚再結', v_bad);
    v_blocks := v_blocks || v_msg;
    v_items := v_items || jsonb_build_object('kind','block','code','plan_bad',
                            'n',v_bad,'go','report.html','msg',v_msg);
  end if;

  -- 以下三種是「數字是對的，只是還不完整」→ 只提醒
  if v_m = date_trunc('month', current_date)::date then
    -- ☢️ 沒有 go：這不是問題，沒有東西要處理。
    v_msg := '這個月還沒過完 —— 結了之後這個月剩下的日子還會有新資料，那些不會進快照';
    v_warns := v_warns || v_msg;
    v_items := v_items || jsonb_build_object('kind','warn','code','month_open','msg',v_msg);
  end if;

  select count(*) into v_nodraw from public.service_records
   where charge_method='plan' and not voided and plan_id is null and customer_id is not null;
  if v_nodraw > 0 then
    -- ☢️ 沒有 go：目前沒有任何一頁列得出這幾筆。
    v_msg := format('還有 %s 筆「扣預收」沒扣到任何一張卡 —— 那幾位客人的預收餘額會偏高', v_nodraw);
    v_warns := v_warns || v_msg;
    v_items := v_items || jsonb_build_object('kind','warn','code','no_draw','n',v_nodraw,'msg',v_msg);
  end if;

  select count(*) into v_unpaid from public.credit_ledger
   where reason='purchase' and pay_method='transfer' and paid_at is null;
  if v_unpaid > 0 then
    v_msg := format('還有 %s 筆匯款待入帳 —— 那是應收，不是這個月的收入', v_unpaid);
    v_warns := v_warns || v_msg;
    v_items := v_items || jsonb_build_object('kind','warn','code','unpaid',
                            'n',v_unpaid,'go','report.html','msg',v_msg);
  end if;

  return jsonb_build_object(
    'ok', array_length(v_blocks,1) is null,
    'ym', to_char(v_m,'YYYY-MM'),
    'blocks', coalesce(to_jsonb(v_blocks), '[]'::jsonb),
    'warns',  coalesce(to_jsonb(v_warns),  '[]'::jsonb),
    'items',  v_items,
    'n_pending', v_pending, 'n_plan_bad', v_bad,
    'n_no_draw', v_nodraw, 'n_unpaid', v_unpaid);
end $fn$;

revoke all on function public.month_close_check(date) from public, anon;
grant execute on function public.month_close_check(date) to authenticated;


-- ── close_month：順便把 items 一起存進快照 ─────────────────────
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
