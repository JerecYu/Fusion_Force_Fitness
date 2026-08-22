-- ═══════════════════════════════════════════════════════════════════
-- db/77-pending-coach.sql — 待入帳要看得出「這筆錢該找誰問」
--
-- 專案：FFF 預約系統（fff-platform）· 2026-08-23
--
-- ☢️ 待入帳清單上有客人、金額、等幾天、誰入的帳 ——
--    就是沒有【教練】。而催款的時候要找的人正好是教練，
--    不是當初在櫃檯按下去的那個人。
--
-- ══ 兩個來源，兩種「教練」的意思 ═══════════════════════════════
-- ☢️ GT 購課：這一筆沒有「上課」，所以帶【這位客人的歸屬教練】
--    （customer_coaches）。一位客人可能有兩位，所以要 string_agg。
-- ☢️ 服務登記：這一筆真的有上課，所以帶【實際授課的教練】
--    （service_coaches），不是歸屬教練 —— 代課的時候兩者不一樣，
--    而要問「這堂到底收了沒」的人是站在現場的那一位。
--
-- ══ 只加欄位，不動舊的 ═════════════════════════════════════════
-- ☢️ 2026-08-22 才踩過：改了回傳的形狀，舊網頁立刻壞掉
--    （見 db/75 的說明）。這一支【只加一個 coach】，
--    舊網頁看不到它，也不會壞 —— 前端可以慢慢推。
--
-- ══ 為什麼是 replace 而不是整支重寫 ════════════════════════════
-- ☢️ finance_report() 有 250 多行，整支貼一次＝多 250 行可能抄錯的機會。
--    這裡改的只有兩段，所以【對到才改，對不到就整支不動並且報錯】。
--    重複執行是安全的：已經有 coach 就直接跳過。
-- ═══════════════════════════════════════════════════════════════════

do $do$
declare
  v_src text; v_a text; v_b text;
begin
  select prosrc into v_src from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'finance_report';

  if v_src is null then
    raise exception 'finance_report 不存在 —— 先跑 db/62';
  end if;
  if position('as coach,' in v_src) > 0 then
    raise notice '已經有 coach 了，跳過';
    return;
  end if;

  -- ① GT 購課那一段：客人的歸屬教練
  v_a := E'      null::text        as payer,\n'
      || E'      e.display_name    as taken_by,\n'
      || E'      round(extract(epoch from now() - l.created_at) / 86400)::int as waited_days';
  v_b := E'      null::text        as payer,\n'
      || E'      e.display_name    as taken_by,\n'
      || E'      -- ☢️ 購課沒有「上課的教練」，所以帶【這位客人的歸屬教練】——\n'
      || E'      --    這筆錢要找誰問，答案是他。一位客人可能有兩位，所以要 agg。\n'
      || E'      (select string_agg(ce.display_name, ''、'' order by ce.display_name)\n'
      || E'         from public.customer_coaches cc\n'
      || E'         join public.employees ce on ce.id = cc.coach_id\n'
      || E'        where cc.customer_id = c.id)      as coach,\n'
      || E'      round(extract(epoch from now() - l.created_at) / 86400)::int as waited_days';
  if position(v_a in v_src) = 0 then
    raise exception '① GT 購課那一段對不到 —— 整支沒有動，先看看 finance_report 是不是被改過了';
  end if;
  v_src := replace(v_src, v_a, v_b);

  -- ② 服務登記那一段：實際授課的教練
  --    ☢️ 欄位順序要跟 ① 一模一樣 —— union all 是照位置對的，
  --       插錯位置的話「教練」欄會變成天數，而且不會報錯。
  v_a := E'      p.payer,\n'
      || E'      e.display_name,\n'
      || E'      round(extract(epoch from now() - p.created_at) / 86400)::int';
  v_b := E'      p.payer,\n'
      || E'      e.display_name,\n'
      || E'      -- ☢️ 這一段有真的上課，所以帶【實際授課的教練】，不是歸屬教練。\n'
      || E'      (select string_agg(ce.display_name, ''＋'' order by ce.display_name)\n'
      || E'         from public.service_coaches sc\n'
      || E'         join public.employees ce on ce.id = sc.coach_id\n'
      || E'        where sc.service_id = s.id),\n'
      || E'      round(extract(epoch from now() - p.created_at) / 86400)::int';
  if position(v_a in v_src) = 0 then
    raise exception '② 服務登記那一段對不到 —— 整支沒有動';
  end if;
  v_src := replace(v_src, v_a, v_b);

  execute 'create or replace function public.finance_report(p_from date, p_to date)'
       || E'\nreturns jsonb\nlanguage plpgsql\nstable\nsecurity definer\n'
       || E'set search_path to ''public''\nas $ff$' || v_src || '$ff$;';
end $do$;

revoke all on function public.finance_report(date, date) from public, anon;
grant execute on function public.finance_report(date, date) to authenticated;
