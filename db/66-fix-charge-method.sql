-- ═══════════════════════════════════════════════════════════════════
-- db/66-fix-charge-method.sql — 改「這一堂怎麼收費」
--
-- 專案：FFF 預約系統（fff-platform）· 修補 · 2026-08-22
--
-- 起因：2026-08-22 Jerec 回報 ——「教練 Peter 登打錯誤，
--   他把『扣預收』寫成『扣單堂』」。兩筆，都是同一位客人。
--
-- ☢️ 這個錯誤【看起來像沒收到錢】。
--    收費方式一寫成單堂，系統就認為客人這一堂要付現，
--    於是那兩筆跳進服務登記的「還沒收齊」紅色警示區，合計四千。
--    而實際上那兩堂是從客人的預付卡扣的 —— 一毛都不該收。
--    ☢️ 更糟的是它會【一路錯到損益表】：那四千會被當成應收帳款。
--
-- ══ 為什麼不用「作廢＋重記」═══════════════════════════════════
-- ☢️ 系統其他地方的原則都是作廢重記，這裡是例外，理由要講清楚：
--    那兩筆【其他欄位全部是對的】—— 日期、教練、客人、人數、業績金額。
--    錯的只有一個下拉選單。
--    作廢重記等於把一筆正確的紀錄毀掉再手打一次，
--    而手打就是【再錯一次的機會】（原本就是手打錯的）。
--
-- ☢️ 但「不留痕跡地改」也不行。所以：改動一律寫進 manual_note，
--    誰改的、什麼時候、從什麼改成什麼、為什麼 —— 四件事都留下。
--
-- ══ 業績會不會變 ═════════════════════════════════════════════════
-- ☢️ 這一支【不動 perf_amount】，所以薪水不會變。
--    這次剛好可以驗證：一對二預付十堂是 20,000 ÷ 10 = 每堂 2,000，
--    跟那兩筆原本記的 2,000 一模一樣 —— 收費方式錯了，業績沒錯。
--    ☢️ 如果哪天遇到「業績也錯了」的情況，那不是這一支的工作，
--       那要作廢重記，因為那是【算錯錢】，不是【選錯分類】。
--
-- ══ 什麼時候會被擋下來 ═══════════════════════════════════════════
-- ☢️ 已經有收款紀錄、又要改成非單堂 → 擋。
--    改過去的話那筆錢會變成孤兒：客人不用付，但帳上有一筆收款。
--    要先把收款刪掉（remove_service_payment）再改。
-- ═══════════════════════════════════════════════════════════════════

create or replace function public.fix_charge_method(
  p_service uuid,
  p_method  text,
  p_why     text
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_s record; v_why text; v_pay int; v_old text; v_name text;
begin
  if not public.is_finance() then
    raise exception '只有負責人和財務可以改收費方式';
  end if;

  if p_method not in ('single','plan','free') then
    return jsonb_build_object('ok', false, 'why', 'bad_method',
      'msg', '收費方式只能是 single（單堂）／plan（扣預收）／free（體驗贈課）');
  end if;

  v_why := btrim(coalesce(p_why, ''));
  if char_length(v_why) < 4 then
    return jsonb_build_object('ok', false, 'why', 'no_reason',
      'msg', '理由至少要四個字 —— 三個月後要查得出為什麼有人改過這一筆');
  end if;

  select * into v_s from public.service_records where id = p_service;
  if not found then
    return jsonb_build_object('ok', false, 'why', 'not_found', 'msg', '找不到這筆服務紀錄');
  end if;
  if v_s.voided then
    return jsonb_build_object('ok', false, 'why', 'voided', 'msg', '這筆已經作廢了');
  end if;
  v_old := v_s.charge_method;
  if v_old = p_method then
    return jsonb_build_object('ok', false, 'why', 'same',
      'msg', format('這筆本來就是 %s，沒有東西要改', v_old));
  end if;

  select count(*) into v_pay from public.service_payments where service_id = p_service;
  -- ☢️ 有收款又要改成非單堂 → 那筆錢會變孤兒（客人不用付，帳上卻有一筆收款）
  if v_pay > 0 and p_method <> 'single' then
    return jsonb_build_object('ok', false, 'why', 'has_payment',
      'msg', format('這筆已經記了 %s 筆收款。改成非單堂會讓那筆錢變孤兒 —— '
                    '請先把收款刪掉（要寫原因），再回來改收費方式。', v_pay));
  end if;

  select name into v_name from public.customers where id = v_s.customer_id;

  update public.service_records
     set charge_method = p_method,
         manual_note = concat_ws(' ｜ ', nullif(manual_note,''),
           to_char(now() at time zone 'Asia/Taipei','YYYY-MM-DD HH24:MI')
           || ' 收費方式 ' || v_old || ' → ' || p_method
           || '（' || coalesce((select display_name from public.employees
                                 where id = public.my_employee_id()), '不明') || '）：'
           || v_why)
   where id = p_service;

  return jsonb_build_object('ok', true, 'id', p_service,
    'name', coalesce(v_name, v_s.company_name), 'was', v_old, 'now', p_method,
    'perf_amount', v_s.perf_amount,
    'done_at', to_char(v_s.done_at at time zone 'Asia/Taipei','YYYY-MM-DD HH24:MI'));
end $fn$;

revoke all on function public.fix_charge_method(uuid, text, text) from public, anon;
grant execute on function public.fix_charge_method(uuid, text, text) to authenticated;

comment on function public.fix_charge_method(uuid, text, text) is
  '只改「這一堂怎麼收費」這一個欄位，其他一律不動（業績不變＝薪水不變）。'
  '財務限定、理由必填、改動寫進 manual_note。'
  '☢️ 已經有收款又要改成非單堂會被擋 —— 那筆錢會變孤兒。';
