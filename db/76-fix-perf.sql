-- ═══════════════════════════════════════════════════════════════════
-- db/76-fix-perf.sql — 補金額 / 改金額
--
-- 專案：FFF 預約系統（fff-platform）· 第 94 步收尾 · 2026-08-22
--
-- ☢️☢️ 起因：8/21 莊有德那一堂，原始流水帳的金額欄是空的，
--    匯進來就是業績 0。0 表示【這一堂不會進任何人的薪資】——
--    Peter 實際上少了 1,500 × 45% ＝ 675。
--
--    整月認列有把它留下來（規則是對的），但畫面上按「最終認列」
--    【沒有地方可以填金額】—— 所以只能認列成 0，或者不認列。
--    ☢️ 兩條路都是錯的，而選了前者就會【安靜地少發薪水】。
--
--    finalize_service() 本來就收 p_perf，是前端沒有接。
--    但那只解決「還沒認列」的情況；已經認列成 0 的要另外一條路。
--
-- ══ 為什麼要一張 log ═══════════════════════════════════════════
-- ☢️ 改的是【某個人的薪水】。不留痕跡的話，三個月後看到
--    「Peter 八月 59,725」沒有人查得出這個數字是怎麼來的、
--    誰改的、原本是多少。系統裡已經有 customer_coach_log 和
--    month_close_log 兩個同樣的東西，這是第三個。
--
-- ══ 為什麼 perf_amount 和 perf_final 兩個都寫 ═══════════════════
-- ☢️ payroll_lines 用 coalesce(perf_final, perf_amount)，所以
--    只寫 perf_final 薪資就會對。但服務登記那一頁的清單顯示的是
--    perf_amount —— 只寫一個的話，畫面上會一直是「業績 NT$0」，
--    而薪資卻是對的。【兩個數字都是真的，但看起來互相矛盾】，
--    那種狀態沒有人有辦法對帳。原始值留在 log 裡，不留在欄位裡。
--
-- ══ 已經月結的月份不給改 ═══════════════════════════════════════
-- ☢️ 這正是月結存在的理由。要改就先「重開這個月」——
--    重開會留下原因和舊快照，改完再結。繞過去的話，
--    發出去的薪資單就跟系統對不起來了，而且查不出是哪一次。
-- ═══════════════════════════════════════════════════════════════════

create table if not exists public.service_perf_log (
  id          uuid primary key default gen_random_uuid(),
  service_id  uuid not null references public.service_records(id),
  old_perf    integer,
  new_perf    integer,
  old_revenue integer,
  new_revenue integer,
  why         text not null,
  changed_by  uuid references public.employees(id),
  changed_at  timestamptz not null default now()
);

create index if not exists service_perf_log_svc_idx
  on public.service_perf_log (service_id, changed_at desc);

comment on table public.service_perf_log is
  '服務紀錄的金額被人工改過的痕跡。☢️ 只增不刪 —— 改的是某個人的薪水，'
  '三個月後要查得出誰改的、原本是多少、為什麼。';

alter table public.service_perf_log enable row level security;
drop policy if exists "財務看得到金額異動" on public.service_perf_log;
create policy "財務看得到金額異動" on public.service_perf_log
  for select to authenticated using (public.is_finance());
grant select on public.service_perf_log to authenticated;


create or replace function public.set_service_perf(
  p_id      uuid,
  p_perf    integer,
  p_revenue integer default null,
  p_why     text    default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_r record; v_why text; v_m date; v_rev integer;
begin
  if not public.is_finance() then raise exception '只有負責人和財務可以改金額'; end if;

  v_why := btrim(coalesce(p_why, ''));
  if char_length(v_why) < 4 then
    return jsonb_build_object('ok', false, 'why', 'no_reason',
      'msg', '改金額要寫原因至少四個字 —— 這會動到教練的薪水，三個月後要查得出為什麼');
  end if;
  if p_perf is null or p_perf < 0 then
    return jsonb_build_object('ok', false, 'why', 'bad_amount', 'msg', '業績金額不能是負的或空的');
  end if;
  if p_revenue is not null and p_revenue < 0 then
    return jsonb_build_object('ok', false, 'why', 'bad_amount', 'msg', '收入金額不能是負的');
  end if;

  select * into v_r from public.service_records where id = p_id;
  if not found then
    return jsonb_build_object('ok', false, 'why', 'not_found', 'msg', '找不到這一筆');
  end if;
  if v_r.voided then
    return jsonb_build_object('ok', false, 'why', 'voided', 'msg', '這一筆已經作廢了');
  end if;

  -- ☢️ 已經結算的月份不給改。要改就先「重開這個月」——
  --    重開會留下原因和舊快照。繞過去的話薪資單就對不起來了。
  v_m := date_trunc('month', (v_r.done_at at time zone 'Asia/Taipei'))::date;
  if exists (select 1 from public.month_closes where ym = v_m and status = 'closed') then
    return jsonb_build_object('ok', false, 'why', 'month_closed',
      'msg', format('%s 已經結算了 —— 要改金額請先到薪資報表「重開這個月」',
                    to_char(v_m, 'YYYY 年 MM 月')));
  end if;

  v_rev := coalesce(p_revenue, v_r.revenue_amount);

  insert into public.service_perf_log
    (service_id, old_perf, new_perf, old_revenue, new_revenue, why, changed_by)
  values (p_id, v_r.perf_amount, p_perf, v_r.revenue_amount, v_rev,
          v_why, public.my_employee_id());

  -- ☢️ 兩個都寫。只寫 perf_final 的話薪資會對，但服務登記的清單
  --    顯示的是 perf_amount —— 畫面上會一直是「業績 NT$0」。
  update public.service_records
     set perf_amount    = p_perf,
         perf_final     = case when fin_status = 'final' then p_perf else perf_final end,
         revenue_amount = v_rev
   where id = p_id;

  return jsonb_build_object('ok', true, 'id', p_id,
    'old_perf', v_r.perf_amount, 'perf', p_perf,
    'old_revenue', v_r.revenue_amount, 'revenue', v_rev,
    'was_final', (v_r.fin_status = 'final'),
    'msg', format('業績 %s → %s', coalesce(v_r.perf_amount,0), p_perf));
end $fn$;

revoke all on function public.set_service_perf(uuid, integer, integer, text) from public, anon;
grant execute on function public.set_service_perf(uuid, integer, integer, text) to authenticated;

comment on function public.set_service_perf(uuid, integer, integer, text) is
  '人工改一筆服務紀錄的業績／收入金額。☢️ 一定要寫原因，而且【已經月結的月份不給改】'
  '（要先重開）。每一次都留一列在 service_perf_log。';
