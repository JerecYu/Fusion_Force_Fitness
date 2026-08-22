-- ═══════════════════════════════════════════════════════════════════
-- db/74-finalize-month.sql — 整月認列
--
-- 專案：FFF 預約系統（fff-platform）· 第 94 步收尾 · 2026-08-22
--
-- ☢️☢️ 起因：月結會擋在「還有 25 筆待確認」。一筆一筆按要按 25 次。
--
-- ══ 但「一鍵」不等於「全部照准」═════════════════════════════════
-- ☢️ 最終認列的意思是【財務看過，這個數字是對的】。做成一顆
--    「全部認列」的鍵，那個檢查就變成蓋章 —— 而月結整套機制
--    正好是靠那個檢查才有意義的。鎖起來的如果是沒人看過的數字，
--    月結只是把錯誤鎖得更牢而已。
--
-- ☢️ 所以這一支的規則是：【看起來有問題的，留下來不動，而且列出來】。
--    它處理的是「沒什麼好看的那幾筆」，不是「全部」。
--    留下來的那幾筆，還是要一筆一筆看 —— 那才是財務該花時間的地方。
--
-- ══ 什麼算「有問題」════════════════════════════════════════════
-- ☢️ 只看【會讓錢算錯】的：業績金額是 0 或空的。
--    業績 0 表示這一堂不會進任何人的薪資 —— 有可能是對的（贈課），
--    也有可能是登記的時候漏填。系統分不出來，所以不猜，留給人看。
--    ☢️ 實測：全店 256 筆非作廢紀錄裡，業績 0 的只有 1 筆，
--       而且【從來沒有一筆業績 0 的紀錄被認列過】—— 所以這條規則
--       目前不會誤傷任何正常的資料。
--
-- ☢️ 待補扣（扣預收但沒扣到卡）【不算問題】，跟著認列。
--    那是「堂數沒扣」，不是「錢算錯」—— 月結那邊也是只提醒不擋，
--    兩邊要用同一套標準，否則會出現「月結說可以結、認列說不行」。
--
-- ══ 為什麼是迴圈呼叫 finalize_service，不是一次 update ═══════════
-- ☢️ 認列要寫哪幾個欄位（fin_status / fin_by / fin_at / perf_final）
--    只能有【一個地方】知道。另外寫一次 update 的話，哪天那支改了、
--    這支沒跟著改，就會做出「認列了但 perf_final 是空的」這種紀錄 ——
--    而且畫面上看起來完全正常。
--    ☢️ 這個坑今天才踩過一次（db/73 的檔案跟資料庫分家）。
--    25 筆跑迴圈的代價是零，同一個交易裡跑完。
-- ═══════════════════════════════════════════════════════════════════

create or replace function public.finalize_month(
  p_ym      date,
  p_dry_run boolean default true
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_m    date := date_trunc('month', p_ym)::date;
  v_next date := (v_m + interval '1 month')::date;
  r        record;
  v_res    jsonb;
  v_done   int := 0;
  v_skip   int := 0;
  v_nodraw int := 0;
  v_left   jsonb := '[]'::jsonb;
  v_why    text;
begin
  if not public.is_finance() then raise exception '只有負責人和財務可以做最終認列'; end if;

  for r in
    select sr.id, sr.perf_amount, sr.charge_method, sr.plan_id, sr.headcount,
           sr.service_type,
           to_char(sr.done_at at time zone 'Asia/Taipei','MM/DD HH24:MI') as t,
           (select string_agg(e.display_name, '＋' order by e.display_name)
              from public.service_coaches c
              join public.employees e on e.id = c.coach_id
             where c.service_id = sr.id) as coach
      from public.service_records sr
     where not sr.voided
       and sr.fin_status <> 'final'
       and (sr.done_at at time zone 'Asia/Taipei')::date >= v_m
       and (sr.done_at at time zone 'Asia/Taipei')::date <  v_next
     order by sr.done_at
  loop
    v_why := null;
    if coalesce(r.perf_amount, 0) = 0 then
      v_why := '業績金額是 0 —— 這一堂不會進任何人的薪資，要先確認是漏填還是真的沒有';
    end if;

    if v_why is not null then
      v_skip := v_skip + 1;
      v_left := v_left || jsonb_build_object(
        'id', r.id, 'when', r.t, 'coach', coalesce(r.coach, '?'),
        'what', r.service_type || coalesce(r.headcount::text || ' 人', ''),
        'why', v_why);
    else
      if r.charge_method = 'plan' and r.plan_id is null then
        v_nodraw := v_nodraw + 1;
      end if;
      if not p_dry_run then
        v_res := public.finalize_service(r.id, null, null);
        -- ☢️ 只要有一筆做不成就整個停下來。做一半的認列比完全沒做更糟：
        --    薪資會變成「一部分是新的、一部分是舊的」，而且沒有地方寫著
        --    停在哪裡。
        if not coalesce((v_res->>'ok')::boolean, false) then
          raise exception '第 % 筆（% %）認列失敗：% —— 整批都沒有做',
            v_done + 1, r.t, coalesce(r.coach,'?'), coalesce(v_res->>'msg', v_res->>'why');
        end if;
      end if;
      v_done := v_done + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'ok', true,
    'ym', to_char(v_m, 'YYYY-MM'),
    'dry_run', p_dry_run,
    'n_total', v_done + v_skip,
    'n_done',  v_done,
    'n_skip',  v_skip,
    'n_no_draw', v_nodraw,
    'skipped', v_left,
    'msg', case
      when v_done + v_skip = 0 then '這個月沒有待確認的紀錄'
      when v_skip = 0 and p_dry_run then format('%s 筆全部可以認列', v_done)
      when v_skip = 0 then format('%s 筆全部認列完成', v_done)
      when p_dry_run then format('%s 筆可以認列，%s 筆要自己看', v_done, v_skip)
      else format('%s 筆認列完成，%s 筆留著沒動', v_done, v_skip)
    end);
end $fn$;

revoke all on function public.finalize_month(date, boolean) from public, anon;
grant execute on function public.finalize_month(date, boolean) to authenticated;

comment on function public.finalize_month(date, boolean) is
  '整月最終認列。☢️ 不是「全部照准」—— 業績金額是 0 的會【留下來不動】並列出來。'
  '預設 dry_run＝true，先看會做什麼再做。';
