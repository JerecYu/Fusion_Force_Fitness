-- ═══════════════════════════════════════════════════════════════════
-- db/71-opening-plans.sql — 私人課的期初餘額匯入 ＋ 回頭補扣
--
-- 專案：FFF 預約系統（fff-platform）· 第 93 步收尾 · 2026-08-22
--
-- 起因：第 93 步把「扣預收」整條路做通了，但【卡本身還沒有】——
--   八月有 175 筆登記成扣預收、卻一張卡都沒扣到（staff_service_no_plan）。
--   那 175 筆牽涉 75 位客人、78 個「客人 × 人數規格」的組合。
--
-- ☢️☢️ 這一步【必須排在月結（第 94 步）前面】。
--    月結會把當下的數字存成快照，而預收餘額現在是錯的 ——
--    先結等於把錯的鎖住，而且鎖起來之後就沒有人會再去查它。
--
-- ══ 兩支函式，分兩趟跑 ═══════════════════════════════════════════
--   ① import_opening_plans  —— 把「某人某規格還剩幾堂」開成一張卡
--   ② backfill_service_draws —— 把那 175 筆回頭掛到卡上、真的扣掉
-- ☢️ 分兩趟的理由跟第 73 步一樣（那次踩過）：一趟跑會被時間順序騙 ——
--    卡還沒開的時候處理銷課，系統會補開一張空的「找不到購課紀錄」方案，
--    加起來剛好還是對的，所以【對帳檢查抓不到】，但畫面上就是壞的。
--
-- ══ 錢的部分：一毛都不記 ═════════════════════════════════════════
-- ☢️ 期初卡的 amount 一律留空 —— 那些錢收在舊系統，是【去年到今年】收的。
--    在這裡填金額會讓八月的收入憑空多出幾十萬，而且對帳報表照樣對得起來
--    （因為兩邊都是真的資料），這種錯查不出來。
-- ☢️ amount 空 → basis_status = 'pending' → 規則文件第三篇 4：
--    「資料不足時維持待確認並暫停自動計薪」。不猜每堂單價。
--
-- ══ as_of：每一張卡有自己的基準日 ═══════════════════════════════
-- ☢️ 「還剩幾堂」一定要附帶「到哪一天為止」。
--    流水帳最後一次動到那張卡是 7/15 的話，基準日就是 7/15，
--    而我們系統裡 8/03、8/11 那兩堂【還沒有被算進去】，要補扣。
--    反過來，基準日之前的課【已經算進去了】，再扣一次就是扣兩遍。
--    所以基準日存進 plans.opened_at，補扣時只處理 done_at > opened_at 的。
-- ═══════════════════════════════════════════════════════════════════


-- ── ① 開期初卡 ─────────────────────────────────────────────────
-- p_rows：[{"client_code":"C0113","product":"PT","headcount":2,
--           "credits":8,"as_of":"2026-08-09","note":"流水帳第 2 堂／共 10 堂"}]
create or replace function public.import_opening_plans(
  p_rows    jsonb,
  p_dry_run boolean default true
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_i int; x jsonb; v_me uuid;
  v_code text; v_cust uuid; v_prod text; v_head int; v_cr int; v_as date;
  v_err text[] := '{}'; v_n int := 0; v_sum int := 0;
  v_led uuid; v_plan uuid;
begin
  if not public.is_finance() then raise exception '只有負責人和財務可以匯入期初餘額'; end if;
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    return jsonb_build_object('ok', false, 'msg', 'p_rows 要是陣列');
  end if;

  -- ══ 先驗全部，全對才寫 ═══════════════════════════════════════
  -- ☢️ 最危險的失敗是「做到一半」：前 40 張卡開好了、第 41 列出錯而中斷，
  --    然後沒有人知道停在哪；重跑會讓一部分人拿到兩倍堂數。
  for v_i in 0 .. jsonb_array_length(p_rows) - 1 loop
    x := p_rows -> v_i;
    v_code := btrim(coalesce(x ->> 'client_code',''));
    v_prod := upper(btrim(coalesce(x ->> 'product','PT')));
    v_head := nullif(x ->> 'headcount','')::int;
    v_cr   := nullif(x ->> 'credits','')::int;
    begin
      v_as := nullif(x ->> 'as_of','')::date;
    exception when others then
      v_err := v_err || format('第 %s 列（%s）：基準日格式不對', v_i+1, v_code); continue;
    end;

    select id into v_cust from public.customers where client_code = v_code;
    if v_cust is null then
      v_err := v_err || format('第 %s 列：找不到客戶編號 %s', v_i+1, v_code); continue;
    end if;
    if v_prod not in ('PT','PGT') then
      v_err := v_err || format('第 %s 列（%s）：product 只能是 PT 或 PGT', v_i+1, v_code); continue;
    end if;
    if v_head is null or v_head < 1 or v_head > 6 then
      v_err := v_err || format('第 %s 列（%s）：人數規格要在 1～6', v_i+1, v_code); continue;
    end if;
    -- ☢️ 0 堂或負數不要開卡。0 堂的卡只會出現在選單上讓人選錯；
    --    負數代表流水帳本身有問題，那要人去看，不是默默匯進來。
    if v_cr is null or v_cr < 1 or v_cr > 100 then
      v_err := v_err || format('第 %s 列（%s）：堂數要在 1～100（拿到 %s）',
                               v_i+1, v_code, coalesce(v_cr::text,'空')); continue;
    end if;
    if v_as is null then
      v_err := v_err || format('第 %s 列（%s）：要填基準日 as_of —— '
        || '「還剩幾堂」沒有「到哪一天為止」就沒有意義', v_i+1, v_code); continue;
    end if;
    if v_as > current_date then
      v_err := v_err || format('第 %s 列（%s）：基準日不能是未來', v_i+1, v_code); continue;
    end if;

    -- ☢️ 防重複匯入。同一位客人同一個規格已經有一張期初卡就擋下來 ——
    --    重跑一次會讓他憑空多出一整張卡，而畫面上完全正常。
    if exists (select 1 from public.plans p
                where p.owner_customer_id = v_cust and p.product = v_prod
                  and p.headcount = v_head and p.note like '期初餘額匯入%') then
      v_err := v_err || format('第 %s 列（%s）：這位客人的 %s 人規格已經有一張期初卡了',
                               v_i+1, v_code, v_head); continue;
    end if;

    v_n := v_n + 1; v_sum := v_sum + v_cr;
  end loop;

  if array_length(v_err,1) is not null then
    return jsonb_build_object('ok', false, 'n_errors', array_length(v_err,1),
      'errors', to_jsonb(v_err));
  end if;
  if p_dry_run then
    return jsonb_build_object('ok', true, 'dry_run', true,
      'n_plans', v_n, 'n_credits', v_sum, 'msg', '預演通過，一列都沒寫');
  end if;

  -- ══ 真的寫 ═══════════════════════════════════════════════════
  v_me := public.my_employee_id();
  for v_i in 0 .. jsonb_array_length(p_rows) - 1 loop
    x := p_rows -> v_i;
    v_code := btrim(x ->> 'client_code');
    v_prod := upper(btrim(coalesce(x ->> 'product','PT')));
    v_head := (x ->> 'headcount')::int;
    v_cr   := (x ->> 'credits')::int;
    v_as   := (x ->> 'as_of')::date;
    select id into v_cust from public.customers where client_code = v_code;

    -- ☢️ 走 reason='purchase' 這條路，因為【只有它會開出一張新的卡】。
    --    product_code 留空，所以 plan_allocate 查不到人數規格 ——
    --    下面自己補上去。amount 留空 → basis_status 自動變 pending。
    insert into public.credit_ledger
      (customer_id, delta, reason, product, product_code, amount, pay_method,
       note, created_at, created_by)
    values
      (v_cust, v_cr, 'purchase', v_prod, null, null, null,
       '期初餘額匯入（舊系統流水帳，基準日 ' || to_char(v_as,'YYYY-MM-DD') || '）',
       (v_as::timestamp at time zone 'Asia/Taipei'), v_me)
    returning id into v_led;

    select id into v_plan from public.plans where ledger_id = v_led;
    if v_plan is null then
      raise exception '第 % 列（%）：方案沒有被建出來 —— 觸發程序壞了，整批回捲', v_i+1, v_code;
    end if;

    update public.plans
       set headcount = v_head,
           opened_at = (v_as::timestamp at time zone 'Asia/Taipei'),
           note = '期初餘額匯入 ｜ 基準日 ' || to_char(v_as,'YYYY-MM-DD')
                  || ' 還剩 ' || v_cr || ' 堂 ｜ '
                  || coalesce(nullif(btrim(x ->> 'note'),''), '來源：舊系統流水帳')
                  || ' ｜ ☢️ 這張卡的錢收在舊系統，不是本系統的收入'
     where id = v_plan;
  end loop;

  return jsonb_build_object('ok', true, 'dry_run', false,
    'n_plans', v_n, 'n_credits', v_sum);
end $fn$;

revoke all on function public.import_opening_plans(jsonb, boolean) from public, anon;
grant execute on function public.import_opening_plans(jsonb, boolean) to authenticated;

comment on function public.import_opening_plans(jsonb, boolean) is
  '把舊系統流水帳的「還剩幾堂」開成一張期初卡。先驗全部、全對才寫。'
  '☢️ 金額一律留空 —— 那些錢收在舊系統，填進來會讓八月營收憑空變多。';


-- ── ② 回頭把八月那些「扣預收卻沒扣到卡」的補扣掉 ───────────────
-- ☢️ 照【上課日由早到晚】處理。同一位客人有兩張同規格的卡時，
--    先扣舊的那一張 —— 跟現場的直覺一致（先用完舊卡）。
create or replace function public.backfill_service_draws(
  p_dry_run boolean default true
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  r record; v_me uuid; v_plan uuid; v_prod text;
  v_done int := 0; v_nocard int := 0; v_empty int := 0; v_early int := 0;
  v_bad int;
begin
  if not public.is_finance() then raise exception '只有負責人和財務可以補扣'; end if;
  v_me := public.my_employee_id();

  for r in
    select s.id, s.customer_id, s.service_type, s.headcount, s.done_at
      from public.service_records s
     where s.charge_method = 'plan' and not s.voided and s.plan_id is null
       and s.customer_id is not null
     order by s.done_at, s.id
  loop
    v_prod := case when r.service_type in ('PT','PT_OUT') then 'PT' else 'PGT' end;

    -- ☢️ 只挑【基準日在這一堂之前】的卡。基準日之後的課才是還沒算進去的；
    --    基準日當天或更早的課，流水帳裡已經扣過了，再扣一次就是扣兩遍。
    select ps.id into v_plan
      from public.plan_state ps
     where ps.owner_customer_id = r.customer_id
       and ps.product = v_prod
       and ps.headcount = r.headcount
       and ps.remaining > 0
       and ps.opened_at < r.done_at
     order by ps.opened_at, ps.id
     limit 1;

    if v_plan is null then
      -- 分得出是「根本沒有卡」還是「有卡但這一堂在基準日之前」
      if exists (select 1 from public.plan_state ps
                  where ps.owner_customer_id = r.customer_id
                    and ps.product = v_prod and ps.headcount = r.headcount
                    and ps.opened_at >= r.done_at) then
        v_early := v_early + 1;
      elsif exists (select 1 from public.plan_state ps
                     where ps.owner_customer_id = r.customer_id
                       and ps.product = v_prod and ps.headcount = r.headcount) then
        v_empty := v_empty + 1;
      else
        v_nocard := v_nocard + 1;
      end if;
      continue;
    end if;

    if not p_dry_run then
      update public.service_records set plan_id = v_plan where id = r.id;
      insert into public.credit_ledger
        (customer_id, delta, reason, product, plan_id, service_id, note, created_at, created_by)
      values
        (r.customer_id, -1, 'class', v_prod, v_plan, r.id,
         to_char(r.done_at at time zone 'Asia/Taipei','YYYY-MM-DD') || ' 私人課扣預收（期初匯入後補扣）',
         r.done_at, v_me);
    end if;
    v_done := v_done + 1;
  end loop;

  -- ☢️ 補完就地對帳。對不上就整批回捲 —— 寧可不補，也不要補出一份
  --    「帳本說 8 堂、方案說 6 堂」的資料，那比沒補更難查。
  if not p_dry_run then
    select count(*) into v_bad from public.staff_plan_check where not ok;
    if v_bad > 0 then
      raise exception '補扣後方案對帳有 % 筆不符 —— 整批回捲', v_bad;
    end if;
  end if;

  return jsonb_build_object('ok', true, 'dry_run', p_dry_run,
    'drew', v_done, 'no_card', v_nocard, 'card_empty', v_empty, 'before_as_of', v_early,
    'left', (select count(*) from public.service_records
              where charge_method='plan' and not voided and plan_id is null
                and customer_id is not null) - (case when p_dry_run then v_done else 0 end));
end $fn$;

revoke all on function public.backfill_service_draws(boolean) from public, anon;
grant execute on function public.backfill_service_draws(boolean) to authenticated;

comment on function public.backfill_service_draws(boolean) is
  '把「登記成扣預收卻沒扣到卡」的服務紀錄回頭掛到期初卡上並真的扣掉。'
  '☢️ 只處理上課日晚於卡片基準日的 —— 基準日之前的課，舊流水帳裡已經扣過了。';


-- ── ③ 匯入之前先看：誰需要卡、需要幾張 ─────────────────────────
-- ☢️ 這張表是【匯入清單的骨架】。跑它拿到「客人編號 × 人數規格 × 幾堂沒扣」，
--    再去舊流水帳把「還剩幾堂」填進去 —— 而不是反過來從流水帳猜誰要開卡。
create or replace view public.staff_opening_needed as
select
  coalesce(c.client_code,'')                       as client_code,
  c.name                                           as customer_name,
  case when s.service_type in ('PT','PT_OUT') then 'PT' else 'PGT' end as product,
  s.headcount,
  count(*)::int                                    as n_pending,
  min(s.done_at)                                   as first_done_at,
  max(s.done_at)                                   as last_done_at,
  (select string_agg(distinct e.display_name, '、')
     from public.service_coaches sc
     join public.employees e on e.id = sc.coach_id
     join public.service_records s2 on s2.id = sc.service_id
    where s2.customer_id = s.customer_id
      and s2.charge_method='plan' and not s2.voided and s2.plan_id is null) as coach_names,
  (select count(*) from public.plan_state ps
    where ps.owner_customer_id = s.customer_id
      and ps.product = case when s.service_type in ('PT','PT_OUT') then 'PT' else 'PGT' end
      and ps.headcount = s.headcount)::int         as cards_now
from public.service_records s
join public.customers c on c.id = s.customer_id
where public.is_finance()
  and s.charge_method = 'plan' and not s.voided and s.plan_id is null
group by c.client_code, c.name, s.customer_id,
         case when s.service_type in ('PT','PT_OUT') then 'PT' else 'PGT' end, s.headcount;

grant select on public.staff_opening_needed to authenticated;

comment on view public.staff_opening_needed is
  '匯入期初餘額之前的清單：哪一位客人、哪一個人數規格、有幾堂還沒扣到卡。'
  'cards_now > 0 代表他已經有卡了（可能只是堂數不夠）。';
