-- ═══════════════════════════════════════════════════════════════════
-- db/73-month-close.sql — 月結：結完就鎖起來
--
-- 專案：FFF 預約系統（fff-platform）· 第 94 步 · 2026-08-22
--
-- ☢️☢️ 起因：payroll_month() 和 finance_report() 都是【即時重算】。
--    今天改一筆加給的結束日、作廢一筆服務紀錄、補一筆帳本調整 ——
--    上個月的數字會跟著變，而且【沒有任何地方記得它原本是多少】。
--    薪資單發給教練之後只要有人動過設定，教練手上那張紙就跟系統對不起來，
--    而且沒有人會知道是哪一次改的。
--
-- ══ 快照存整包 jsonb，不是拆成欄位 ═══════════════════════════════
-- ☢️ 拆成欄位的話，函式以後一改（第 95 步的損益表就要動），
--    舊月份會跟著【新的結構】重新解讀 —— 而「上個月」的意義就是
--    【當時算出來的那個樣子】。整包存起來才鎖得住。
-- ☢️ 代價是查不動（不能 where coach = X）。所以另外開一張 payouts，
--    專門記「薪水發了沒」—— 那是唯一需要被查詢的新資訊。
--
-- ══ 什麼情況擋下來、什麼情況只是提醒 ═════════════════════════════
-- ☢️ 分界線是：【數字會錯】→ 擋；【數字是對的但不完整】→ 提醒。
--    擋：還有待確認的服務紀錄（那些根本沒進薪資）
--    擋：方案對帳對不上（堂數資料本身矛盾）
--    擋：已經結過了（要先重開）
--    擋：未來的月份
--    提醒：還有待補扣、待入帳、這個月還沒過完
--
-- ══ 鎖起來不等於不能改 ═══════════════════════════════════════════
-- ☢️ 要留一條「重開這個月」的路，否則第一次結錯就死鎖。
--    但重開一定要留下痕跡 —— 被換掉的那份快照【整包搬進 log】，
--    不是覆蓋掉。三個月後要查得出「原本是多少」。
-- ═══════════════════════════════════════════════════════════════════

-- ── ① 每個月一列（現值）────────────────────────────────────────
create table if not exists public.month_closes (
  ym         date primary key,                 -- 月份的第一天
  status     text not null default 'closed' check (status in ('open','closed')),
  snapshot   jsonb not null,
  closed_by  uuid references public.employees(id),
  closed_at  timestamptz not null default now(),
  note       text
);

comment on table public.month_closes is
  '月結。一個月一列，snapshot 是結帳當下算出來的整包數字。'
  '☢️ 結了之後所有報表都讀這裡，不再重算 —— 那才叫「上個月」。';

-- ── ② 異動紀錄（只增不刪）──────────────────────────────────────
create table if not exists public.month_close_log (
  id         uuid primary key default gen_random_uuid(),
  ym         date not null,
  action     text not null check (action in ('close','reopen','reclose')),
  why        text,
  snapshot   jsonb,                             -- 重開時，被換掉的那一份
  changed_by uuid references public.employees(id),
  changed_at timestamptz not null default now()
);

create index if not exists month_close_log_ym_idx
  on public.month_close_log (ym, changed_at desc);

comment on table public.month_close_log is
  '月結的痕跡。☢️ 只增不刪。重開的時候把【被換掉的那份快照】整包搬進來 ——'
  '不是覆蓋掉，因為要查得出「原本是多少」。';

-- ── ③ 薪水實際發了沒 ───────────────────────────────────────────
-- ☢️ 這是目前系統【完全不存在】的資訊。算得出應發多少，
--    但沒有任何地方記得「發了沒、哪天發的、實際發了多少」。
create table if not exists public.payouts (
  id         uuid primary key default gen_random_uuid(),
  ym         date not null,
  coach_id   uuid not null references public.employees(id),
  amount     integer not null check (amount >= 0),
  paid_on    date,                              -- 空的＝還沒發
  method     text check (method in ('cash','transfer')),
  note       text,
  created_by uuid references public.employees(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (ym, coach_id)
);

comment on table public.payouts is
  '每位教練每個月實際領到的薪水。paid_on 是空的代表還沒發。'
  '☢️ 跟快照分開存 —— 快照是「該發多少」，這裡是「實際發了什麼」，兩件事。';

alter table public.month_closes    enable row level security;
alter table public.month_close_log enable row level security;
alter table public.payouts         enable row level security;

drop policy if exists "財務看得到月結" on public.month_closes;
create policy "財務看得到月結" on public.month_closes
  for select to authenticated using (public.is_finance());
drop policy if exists "財務看得到月結紀錄" on public.month_close_log;
create policy "財務看得到月結紀錄" on public.month_close_log
  for select to authenticated using (public.is_finance());
-- ☢️ 教練看得到【自己】的薪資發放，不是全部人的。
drop policy if exists "看得到自己的薪水" on public.payouts;
create policy "看得到自己的薪水" on public.payouts
  for select to authenticated
  using (public.is_finance() or coach_id = public.my_employee_id());

grant select on public.month_closes    to authenticated;
grant select on public.month_close_log to authenticated;
grant select on public.payouts         to authenticated;


-- ── ④ 結帳前先看：擋得住嗎 ─────────────────────────────────────
-- ☢️ 獨立一支，因為畫面要在【按下去之前】就告訴人「還缺什麼」，
--    而不是按了才跳錯誤。close_month() 自己也呼叫它，兩邊同一套規則。
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
  v_blocks text[] := '{}'; v_warns text[] := '{}';
begin
  if not public.is_finance() then raise exception '只有負責人和財務可以月結'; end if;

  select status into v_closed from public.month_closes where ym = v_m;
  if v_closed = 'closed' then
    v_blocks := v_blocks || format('%s 已經結過了 —— 要改的話先「重開這個月」', to_char(v_m,'YYYY 年 MM 月'))::text;
  end if;

  if v_m > date_trunc('month', current_date)::date then
    v_blocks := v_blocks || '不能結未來的月份'::text;
  end if;

  -- ☢️ 待確認的服務紀錄【根本沒進薪資】。這時候結帳等於把一個
  --    明知不完整的數字鎖起來，而且鎖起來之後就沒有人會再去看它。
  select count(*) into v_pending from public.service_records
   where not voided and fin_status <> 'final'
     and (done_at at time zone 'Asia/Taipei')::date >= v_m
     and (done_at at time zone 'Asia/Taipei')::date <  v_next;
  if v_pending > 0 then
    v_blocks := v_blocks || format('還有 %s 筆服務紀錄是「待確認」—— 那些沒有算進任何人的薪資，'
                                   '請先在服務登記按「最終認列」', v_pending)::text;
  end if;

  -- ☢️ 帳本與方案對不起來 ＝ 堂數資料自己矛盾。這種狀態下的預收餘額
  --    是錯的，而損益表要把預收餘額當負債列出來。
  select count(*) into v_bad from public.staff_plan_check where not ok;
  if v_bad > 0 then
    v_blocks := v_blocks || format('有 %s 位客人的帳本餘額跟方案餘額對不起來 —— 先查清楚再結', v_bad)::text;
  end if;

  -- 以下三種是「數字是對的，只是還不完整」→ 只提醒
  if v_m = date_trunc('month', current_date)::date then
    v_warns := v_warns || '這個月還沒過完 —— 結了之後這個月剩下的日子還會有新資料，那些不會進快照'::text;
  end if;
  select count(*) into v_nodraw from public.service_records
   where charge_method='plan' and not voided and plan_id is null and customer_id is not null;
  if v_nodraw > 0 then
    v_warns := v_warns || format('還有 %s 筆「扣預收」沒扣到任何一張卡 —— 那幾位客人的預收餘額會偏高', v_nodraw)::text;
  end if;
  select count(*) into v_unpaid from public.credit_ledger
   where reason='purchase' and pay_method='transfer' and paid_at is null;
  if v_unpaid > 0 then
    v_warns := v_warns || format('還有 %s 筆匯款待入帳 —— 那是應收，不是這個月的收入', v_unpaid)::text;
  end if;

  return jsonb_build_object(
    'ok', array_length(v_blocks,1) is null,
    'ym', to_char(v_m,'YYYY-MM'),
    'blocks', coalesce(to_jsonb(v_blocks), '[]'::jsonb),
    'warns',  coalesce(to_jsonb(v_warns),  '[]'::jsonb),
    'n_pending', v_pending, 'n_plan_bad', v_bad,
    'n_no_draw', v_nodraw, 'n_unpaid', v_unpaid);
end $fn$;

revoke all on function public.month_close_check(date) from public, anon;
grant execute on function public.month_close_check(date) to authenticated;


-- ── ⑤ 結帳 ─────────────────────────────────────────────────────
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
      'blocks', v_chk->'blocks', 'msg', (v_chk->'blocks'->>0));
  end if;

  v_me := public.my_employee_id();
  select status into v_was from public.month_closes where ym = v_m;

  -- ☢️ 三份報表【當下算一次】，然後整包封存。之後永遠讀這一份。
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
    -- 結帳當下的幾個「全店狀態」數字，之後查得出當時的樣子
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

  -- ☢️ payroll_month 的 rows ＝【每位教練一列】、lines ＝【每一筆明細】。
  --    名字跟直覺相反，接錯了畫面會變成幾百列。
  return jsonb_build_object('ok', true, 'ym', to_char(v_m,'YYYY-MM'),
    'reclosed', (v_was = 'open'),
    'warns', v_chk->'warns',
    'perf',  v_snap->'payroll'->'rows',
    'size',  length(v_snap::text));
end $fn$;

revoke all on function public.close_month(date, text) from public, anon;
grant execute on function public.close_month(date, text) to authenticated;


-- ── ⑥ 重開 ─────────────────────────────────────────────────────
-- ☢️ 一定要留一條路，否則第一次結錯就死鎖。
--    但被換掉的那份快照【整包搬進 log】，不是覆蓋掉。
create or replace function public.reopen_month(p_ym date, p_why text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare v_m date := date_trunc('month', p_ym)::date; v_r record; v_why text;
begin
  if not public.is_finance() then raise exception '只有負責人和財務可以重開月結'; end if;
  v_why := btrim(coalesce(p_why,''));
  if char_length(v_why) < 4 then
    return jsonb_build_object('ok', false, 'why', 'no_reason',
      'msg', '重開要寫原因至少四個字 —— 這是把已經發出去的數字改掉，三個月後要查得出為什麼');
  end if;

  select * into v_r from public.month_closes where ym = v_m;
  if not found then
    return jsonb_build_object('ok', false, 'why', 'not_closed', 'msg', '這個月還沒結過');
  end if;
  if v_r.status = 'open' then
    return jsonb_build_object('ok', false, 'why', 'already_open', 'msg', '這個月已經是打開的了');
  end if;

  insert into public.month_close_log (ym, action, why, snapshot, changed_by)
  values (v_m, 'reopen', v_why, v_r.snapshot, public.my_employee_id());

  update public.month_closes set status = 'open' where ym = v_m;

  return jsonb_build_object('ok', true, 'ym', to_char(v_m,'YYYY-MM'),
    'was_closed_at', to_char(v_r.closed_at at time zone 'Asia/Taipei','YYYY-MM-DD HH24:MI'),
    'was_closed_by', (select display_name from public.employees where id = v_r.closed_by),
    'msg', '已經打開。舊的那份快照留在異動紀錄裡，查得到原本的數字。');
end $fn$;

revoke all on function public.reopen_month(date, text) from public, anon;
grant execute on function public.reopen_month(date, text) to authenticated;


-- ── ⑦ 讀報表：結了讀快照，沒結就即時算 ─────────────────────────
-- ☢️ 前端不需要知道差別 —— 它只要問「八月是多少」，
--    這一支決定要從哪裡拿。這是整個第 94 步的重點。
create or replace function public.month_report(p_ym date)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $fn$
declare
  v_m date := date_trunc('month', p_ym)::date;
  v_next date := (v_m + interval '1 month')::date;
  v_r record;
begin
  if not public.is_finance() then raise exception '只有負責人和財務看得到月報'; end if;

  select * into v_r from public.month_closes where ym = v_m and status = 'closed';
  if found then
    return v_r.snapshot
      || jsonb_build_object('closed', true,
           'closed_at', to_char(v_r.closed_at at time zone 'Asia/Taipei','YYYY-MM-DD HH24:MI'),
           'closed_by', (select display_name from public.employees where id = v_r.closed_by),
           'note', v_r.note,
           'reopens', (select count(*) from public.month_close_log
                        where ym = v_m and action = 'reopen'),
           'payouts', coalesce((select jsonb_agg(jsonb_build_object(
                          'coach', e.display_name, 'amount', p.amount,
                          'paid_on', p.paid_on, 'method', p.method, 'note', p.note)
                          order by e.display_name)
                        from public.payouts p join public.employees e on e.id = p.coach_id
                       where p.ym = v_m), '[]'::jsonb));
  end if;

  -- 還沒結：即時算，而且【講明白它會變】
  return jsonb_build_object(
    'ym', to_char(v_m,'YYYY-MM'), 'closed', false,
    'live_note', '☢️ 這個月還沒結算 —— 下面的數字是【現在重算】的，'
                 || '任何設定或紀錄一改就會跟著變。結算之後才會固定下來。',
    'check',    public.month_close_check(v_m),
    'payroll',  public.payroll_month(v_m),
    'finance',  public.finance_report(v_m, (v_next - 1)),
    'expenses', public.expense_report(v_m, (v_next - 1)));
end $fn$;

revoke all on function public.month_report(date) from public, anon;
grant execute on function public.month_report(date) to authenticated;


-- ── ⑧ 記薪水發了沒 ─────────────────────────────────────────────
create or replace function public.record_payout(
  p_ym      date,
  p_coach   uuid,
  p_amount  integer,
  p_paid_on date default null,
  p_method  text default null,
  p_note    text default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare v_m date := date_trunc('month', p_ym)::date; v_nm text; v_me uuid;
begin
  if not public.is_finance() then raise exception '只有負責人和財務可以記薪資發放'; end if;
  select display_name into v_nm from public.employees where id = p_coach;
  if v_nm is null then
    return jsonb_build_object('ok', false, 'why', 'no_coach', 'msg', '找不到這位教練');
  end if;
  if p_amount is null or p_amount < 0 then
    return jsonb_build_object('ok', false, 'why', 'bad_amount', 'msg', '金額不能是負的');
  end if;
  if p_paid_on is not null and p_method is null then
    return jsonb_build_object('ok', false, 'why', 'no_method',
      'msg', '已經發了就要寫是現金還是匯款');
  end if;
  if p_paid_on > current_date then
    return jsonb_build_object('ok', false, 'why', 'future', 'msg', '發放日不能是未來');
  end if;
  -- ☢️ 不擋「這個月還沒結」—— 現實裡薪水可能先發、月結後補。
  --    但要記在畫面上看得到的地方，所以回傳裡帶著月結狀態。
  v_me := public.my_employee_id();
  insert into public.payouts (ym, coach_id, amount, paid_on, method, note, created_by)
  values (v_m, p_coach, p_amount, p_paid_on, p_method, nullif(btrim(p_note),''), v_me)
  on conflict (ym, coach_id) do update
    set amount = excluded.amount, paid_on = excluded.paid_on,
        method = excluded.method, note = excluded.note, updated_at = now();

  return jsonb_build_object('ok', true, 'ym', to_char(v_m,'YYYY-MM'), 'coach', v_nm,
    'amount', p_amount, 'paid_on', p_paid_on,
    'month_closed', exists (select 1 from public.month_closes
                             where ym = v_m and status='closed'));
end $fn$;

revoke all on function public.record_payout(date, uuid, integer, date, text, text) from public, anon;
grant execute on function public.record_payout(date, uuid, integer, date, text, text) to authenticated;


-- ── ⑨ 月結一覽 ─────────────────────────────────────────────────
create or replace view public.staff_month_closes as
select
  mc.ym,
  to_char(mc.ym,'YYYY-MM')                                   as ym_text,
  mc.status,
  to_char(mc.closed_at at time zone 'Asia/Taipei','YYYY-MM-DD HH24:MI') as closed_at,
  (select display_name from public.employees where id = mc.closed_by) as closed_by,
  coalesce(mc.note,'')                                        as note,
  -- ☢️ payroll_month 的 rows ＝每位教練一列、lines ＝每一筆明細（名字跟直覺相反）。
  --    而且要取【陣列長度】，不是把陣列轉數字。
  jsonb_array_length(mc.snapshot #> '{payroll,lines}')        as n_items,
  jsonb_array_length(mc.snapshot #> '{payroll,rows}')         as n_coaches,
  (select count(*) from public.month_close_log l
    where l.ym = mc.ym and l.action = 'reopen')::int           as n_reopens,
  (select count(*) from public.payouts p where p.ym = mc.ym)::int as n_payouts,
  (select count(*) from public.payouts p where p.ym = mc.ym and p.paid_on is not null)::int as n_paid
from public.month_closes mc
where public.is_finance()
order by mc.ym desc;

grant select on public.staff_month_closes to authenticated;

comment on view public.staff_month_closes is
  '哪幾個月結過了、誰結的、重開過幾次、薪水發了幾位。';
