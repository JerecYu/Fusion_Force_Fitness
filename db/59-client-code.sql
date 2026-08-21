-- ═══════════════════════════════════════════════════════════════════
-- db/59-client-code.sql — 客戶編號 ＋ PT／PGT 客人批次匯入
--
-- 專案：FFF 預約系統（fff-platform）· 第 36 步 · 2026-08-21
--
-- 起因：PT／PGT 的 155 位活躍客人一直不在系統裡（第 36 步從 2026-08-16
--       卡到現在）。八月已經有 231 堂掛在他們身上，但 customer_id 全是 null。
--
-- ☢️ 這個 repo 是公開的。這支檔案裡【沒有任何一筆資料】——
--    姓名、手機、編號一律走呼叫時傳進來的 jsonb，不寫進版控。
--
-- ══ 為什麼要 client_code ═══════════════════════════════════════
-- Jerec 手上那份《Active Client List》是活的主檔，之後還會來回好幾次。
-- 沒有一個穩定的鍵，每次對帳都要靠姓名猜 —— 而【19 位沒有手機】的人
-- 連手機都不能當鍵。客戶編號（C0001…C0155）是唯一能兩邊都認得的東西。
--
-- ══ 三條不可違反的規則 ═══════════════════════════════════════
-- ☢️ ① 不覆蓋既有姓名。
--    手機對得上就是同一個人，但系統裡那個名字是【教練認得的字】——
--    點名表（staff_roster）目前只顯示 name，改了它，下課前最趕的那個
--    畫面上就有五個人同時換名字。正式姓名另外一步處理。
--
-- ☢️ ② 手機對得上 → 掛上去，不新建。
--    155 位裡有 26 位早就在系統裡（GT 那邊建的）。新建一次就是
--    【同一個人兩筆】，而且其中一筆永遠是孤兒 —— 事後幾乎修不回來，
--    因為堂數、預約、帳本會各自掛在不同那一筆上。
--
-- ☢️ ③ 先驗全部，全對才寫（跟第 30、86 步同一個原則）。
--    一次進 155 筆，最危險的失敗是「做到一半」。
--
-- ══ 防重 ═══════════════════════════════════════════════════════
-- 靠 client_code 的唯一索引，不靠人記得自己跑過沒有。
-- 同一份名單重跑第二次，每一列都會被「這個編號已經給過別人了」擋下來。
-- ═══════════════════════════════════════════════════════════════════

-- ── ① 客戶編號 ─────────────────────────────────────────────────
alter table public.customers
  add column if not exists client_code text;

create unique index if not exists customers_client_code_uk
  on public.customers (client_code)
  where client_code is not null;

comment on column public.customers.client_code is
  'Jerec 主檔《Active Client List》的客戶編號（C0001…）。'
  '沒有手機的客人只能靠這個對回主檔。GT 那邊自己建的客人是 null。';


-- ── ② 匯入函式 ─────────────────────────────────────────────────
-- p_rows 每一列要有：
--   code   客戶編號（C0001…）
--   name   正式姓名（☢️ 只在【新建】時使用；掛到既有客人時不覆蓋）
--   nick   暱稱（既有客人的暱稱是空的才補上去）
--   phone  手機，可以是 null（真的聯絡不上的人）
--   coach  負責教練（只寫進備註，不建關聯 —— PT 的教練歸屬看服務紀錄）
--
create or replace function public.import_customers(
  p_rows    jsonb,
  p_batch   text,
  p_dry_run boolean default true
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_errs   text[] := '{}';
  v_diff   jsonb  := '[]'::jsonb;
  v_row    jsonb;
  v_i      int := 0;
  v_code   text; v_name text; v_nick text; v_phone text;
  -- ☢️ 不能用 record。plpgsql 的 record 在【被 SELECT INTO 指派之前沒有欄位結構】，
  --    v_exist := null 給不了它結構 —— 沒有手機、跳過查詢的那幾列，
  --    下一行讀 v_exist.id 就噴 "record is not assigned yet"。
  --    而那剛好是 18 位沒手機的人：有手機的全部會過，沒手機的一列都進不來。
  --    2026-08-21 預演時真的踩到。用純量就沒有這個問題。
  v_eid    uuid; v_ename text; v_ecode text;
  v_n_link int := 0; v_n_new int := 0;
  v_before int; v_after int;
begin
  if not public.is_finance() then
    raise exception '只有負責人和財務可以匯入客人';
  end if;
  if jsonb_typeof(p_rows) <> 'array' then
    raise exception 'p_rows 要是陣列';
  end if;
  if coalesce(p_batch,'') = '' then
    raise exception '要給 p_batch（批次名稱），它會寫進備註當來源';
  end if;

  select count(*) into v_before from public.customers;

  -- ══ 第一輪：只驗，不寫 ════════════════════════════════════════
  for v_row in select * from jsonb_array_elements(p_rows) loop
    v_i := v_i + 1;
    v_code  := btrim(coalesce(v_row->>'code',''));
    v_name  := btrim(coalesce(v_row->>'name',''));
    v_nick  := nullif(btrim(coalesce(v_row->>'nick','')), '');
    v_phone := nullif(regexp_replace(coalesce(v_row->>'phone',''), '\D', '', 'g'), '');

    if v_code = '' then
      v_errs := v_errs || format('第 %s 列：沒有客戶編號', v_i);
    end if;
    if length(regexp_replace(v_name, '[\s　]', '', 'g')) < 2 then
      v_errs := v_errs || format('第 %s 列（%s）：姓名少於兩個字', v_i, v_code);
    end if;
    -- ☢️ 手機可以是 null，但只要有填就必須是完整的 09 十碼。
    --    「半個號碼」比沒有號碼更糟 —— 它看起來是可以聯絡的。
    if v_phone is not null and v_phone !~ '^09\d{8}$' then
      v_errs := v_errs || format('第 %s 列（%s）：手機格式不對「%s」', v_i, v_code, v_phone);
    end if;

    -- 這個編號是不是已經給過別人了（重跑的保險絲）
    if exists (select 1 from public.customers where client_code = v_code) then
      v_errs := v_errs || format('第 %s 列（%s）：這個編號已經匯入過了', v_i, v_code);
    end if;

    -- 手機已經在系統裡 → 等一下要「掛上去」。
    -- ☢️ 但如果那一位已經掛著【別的】編號，就是兩份名單對不起來，要人來看。
    v_eid := null; v_ecode := null;
    if v_phone is not null then
      select c.id, c.client_code into v_eid, v_ecode
        from public.customers c where c.phone = v_phone;
      if v_eid is not null and v_ecode is not null and v_ecode <> v_code then
        v_errs := v_errs || format('第 %s 列（%s）：這支手機已經掛著編號 %s',
                                   v_i, v_code, v_ecode);
      end if;
    end if;
  end loop;

  -- 同一批裡自己重複
  if exists (select 1 from (
        select x->>'code' as k from jsonb_array_elements(p_rows) x
         group by 1 having count(*) > 1) d) then
    v_errs := v_errs || '這一批裡有重複的客戶編號'::text;
  end if;
  if exists (select 1 from (
        select regexp_replace(coalesce(x->>'phone',''),'\D','','g') as k
          from jsonb_array_elements(p_rows) x
         where coalesce(x->>'phone','') <> ''
         group by 1 having count(*) > 1) d) then
    v_errs := v_errs || '這一批裡有重複的手機'::text;
  end if;

  if array_length(v_errs,1) > 0 then
    return jsonb_build_object('ok', false, 'wrote', false,
      'n_rows', v_i, 'n_errors', array_length(v_errs,1),
      'errors', to_jsonb(v_errs[1:40]));
  end if;

  -- ══ 預演：先算出「會掛上幾位、會新建幾位」，並列出姓名不一樣的 ══
  v_i := 0;
  for v_row in select * from jsonb_array_elements(p_rows) loop
    v_i := v_i + 1;
    v_code  := btrim(v_row->>'code');
    v_name  := btrim(v_row->>'name');
    v_phone := nullif(regexp_replace(coalesce(v_row->>'phone',''), '\D', '', 'g'), '');

    v_eid := null; v_ename := null;
    if v_phone is not null then
      select c.id, c.name into v_eid, v_ename
        from public.customers c where c.phone = v_phone;
    end if;

    if v_eid is not null then
      v_n_link := v_n_link + 1;
      if v_ename <> v_name then
        -- ☢️ 只回報，不改。改姓名是另一步的事。
        v_diff := v_diff || jsonb_build_object(
          'code', v_code, 'in_system', v_ename, 'in_list', v_name);
      end if;
    else
      v_n_new := v_n_new + 1;
    end if;
  end loop;

  if p_dry_run then
    return jsonb_build_object('ok', true, 'wrote', false, 'dry_run', true,
      'n_rows', v_i, 'n_errors', 0,
      'will_link', v_n_link, 'will_create', v_n_new,
      'customers_before', v_before,
      'customers_after_expected', v_before + v_n_new,
      'name_diff', v_diff);
  end if;

  -- ══ 第二輪：寫 ═══════════════════════════════════════════════
  for v_row in select * from jsonb_array_elements(p_rows) loop
    v_code  := btrim(v_row->>'code');
    v_name  := btrim(v_row->>'name');
    v_nick  := nullif(btrim(coalesce(v_row->>'nick','')), '');
    v_phone := nullif(regexp_replace(coalesce(v_row->>'phone',''), '\D', '', 'g'), '');

    v_eid := null;
    if v_phone is not null then
      select c.id into v_eid from public.customers c where c.phone = v_phone;
    end if;

    if v_eid is not null then
      -- 掛上去。☢️ name 一個字都不動；暱稱只在原本是空的時候才補。
      update public.customers
         set client_code = v_code,
             nickname    = coalesce(nickname, v_nick),
             note        = concat_ws(' ｜ ', nullif(note,''), p_batch || ' 掛上編號 ' || v_code)
       where id = v_eid;
    else
      insert into public.customers (name, nickname, phone, client_code, is_active, note)
      values (v_name, v_nick, v_phone, v_code, true,
              p_batch || ' 匯入 ' || v_code
              || case when v_phone is null then '（☢️ 沒有手機：推不到通知、綁不了 LINE）' else '' end
              || case when coalesce(v_row->>'coach','') <> ''
                      then ' ｜ 負責教練 ' || (v_row->>'coach') else '' end);
    end if;
  end loop;

  select count(*) into v_after from public.customers;

  return jsonb_build_object('ok', true, 'wrote', true,
    'n_rows', jsonb_array_length(p_rows),
    'linked', v_n_link, 'created', v_n_new,
    'customers_before', v_before, 'customers_after', v_after,
    'no_phone', (select count(*) from public.customers
                  where client_code is not null and phone is null),
    'name_diff', v_diff);
end $fn$;

revoke all on function public.import_customers(jsonb, text, boolean) from public, anon, authenticated;
grant execute on function public.import_customers(jsonb, text, boolean) to authenticated;

comment on function public.import_customers(jsonb, text, boolean) is
  'PT／PGT 客人批次匯入。先驗全部、全對才寫；手機對得上就掛編號不新建，而且不覆蓋既有姓名。'
  '預設是預演，要真的寫必須明確傳 p_dry_run => false。';
