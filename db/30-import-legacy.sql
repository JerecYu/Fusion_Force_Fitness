-- ═══════════════════════════════════════════════════════════════
--  30-import-legacy.sql  ·  舊表孤兒批次匯入
--  2026-08-17
--
--  背景：2026-08-17 傍晚查出來的 —— 舊系統的建立者當初把
--  「資料不齊、但有買課」的學員【排除在舊系統之外】，另外放在雲端
--  某個資料夾，交接時忘了這批人。他們從來沒有進過新系統。
--
--  比對結果（舊表 154 人 vs 新系統 84 人）：
--    · 完全對不到的           74 人
--    · 其中【還有餘課】的     65 人，合計 402 堂
--  這 402 堂大約等於新系統當時全部 556 堂的 72%。
--  這些人付過錢，卻訂不了課、也查不到自己的堂數。
--
--  ☢️ 一次要進 65 個人。這種批次最危險的失敗方式是【做到一半】——
--     前 30 個寫進去了、第 31 個手機重複而中斷，然後沒有人知道
--     停在哪裡；重跑會讓一部分人拿到兩倍堂數。
--     所以規矩是：先把整批驗完，有任何一列不合格就【一列都不寫】。
-- ═══════════════════════════════════════════════════════════════

-- ── 姓名相似判斷 ─────────────────────────────────────────────
--  ☢️ 手機擋不住「同一個人換了號碼」：Adele 在系統裡是舊號碼、
--     員工查到的是新號碼 → 會被當成新人建一次 → 兩筆資料、兩份堂數。
--     這種靠人眼不可靠，所以在【預演階段】用機器標出來。
--
--  ☢️ 第一版只做「互相包含」，測試四筆全部漏掉 ——
--     因為最常見的那一種是【同長度、只差一個同音字】：
--     林屏玟／林屏妏、鄭旭媢／鄭旭媚、張小筠／張小雲。
create or replace function public.name_close(a text, b text)
returns boolean
language plpgsql immutable set search_path = public as $$
declare x text; y text; n int; d int := 0; i int;
begin
  x := lower(regexp_replace(coalesce(a,''),'[\s　]','','g'));
  y := lower(regexp_replace(coalesce(b,''),'[\s　]','','g'));
  if x = '' or y = '' then return false; end if;
  if x = y then return true; end if;
  -- 多寫／少寫（廖庭均 ⊂ 廖庭均 Teresa）
  if length(x) >= 2 and position(x in y) > 0 then return true; end if;
  if length(y) >= 2 and position(y in x) > 0 then return true; end if;
  -- ☢️ 同長度、只差一個字 —— 同音錯字就是長這樣
  if length(x) = length(y) and length(x) >= 2 then
    n := length(x);
    for i in 1..n loop
      if substr(x,i,1) <> substr(y,i,1) then d := d + 1; end if;
      exit when d > 1;
    end loop;
    if d = 1 then return true; end if;
  end if;
  return false;
end $$;
-- 2026-08-17 用真實案例驗過 8 組全對：
--   林屏玟／林屏妏 ✓　鄭旭媢／鄭旭媚 ✓　張小筠／張小雲 ✓　廖庭均 Teresa／廖庭均 ✓
--   陳荔芬／Adele ✗（正確 —— 名字完全不同，機器不可能認得出來，這一種只能靠人掃）
--   王小明／陳大文 ✗　林嘉惠／林惠萱 ✗

create or replace function public.import_legacy_credits(
  p_rows jsonb, p_dry_run boolean default true)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  r jsonb; v_name text; v_phone text; v_credits int;
  v_errors jsonb := '[]'::jsonb; v_plan jsonb := '[]'::jsonb; v_warn jsonb := '[]'::jsonb;
  v_names jsonb := '[]'::jsonb;
  v_exist record; v_near record; v_seen text[] := '{}'; v_i int := 0;
  v_new int := 0; v_reuse int := 0; v_credits_total int := 0;
  v_cid uuid; v_before int; v_after int;
begin
  -- ☢️ 只有負責人。這一支一次能動幾百堂，比任何單一操作都重。
  if not public.is_owner() then raise exception '只有負責人可以批次匯入'; end if;

  -- ── 第一輪：只驗，不寫 ──────────────────────────────────
  for r in select * from jsonb_array_elements(p_rows) loop
    v_i := v_i + 1;
    v_name    := btrim(coalesce(r->>'name',''));
    v_phone   := regexp_replace(coalesce(r->>'phone',''), '\D', '', 'g');
    v_credits := coalesce((r->>'credits')::int, 0);

    -- 至少兩個字（跟 create_customer 同一條規則：一個字會讓綁定亂中）
    if length(regexp_replace(v_name,'[\s　]','','g')) < 2 then
      v_errors := v_errors || jsonb_build_object('i',v_i,'name',v_name,'why','姓名少於兩個字'); end if;
    if v_phone !~ '^09\d{8}$' then
      v_errors := v_errors || jsonb_build_object('i',v_i,'name',v_name,
                    'why','手機格式不對：'||coalesce(r->>'phone','(空白)')); end if;
    if v_credits <= 0 then
      v_errors := v_errors || jsonb_build_object('i',v_i,'name',v_name,'why','堂數要大於 0'); end if;
    -- ☢️ 同一批裡面自己重複 —— 最容易被忽略，而且會直接撞 unique 索引
    if v_phone = any(v_seen) then
      v_errors := v_errors || jsonb_build_object('i',v_i,'name',v_name,'why','這支手機在同一批裡出現兩次'); end if;
    v_seen := v_seen || v_phone;

    select id, name into v_exist from public.customers where phone = v_phone;
    if found then
      v_reuse := v_reuse + 1;
      v_plan := v_plan || jsonb_build_object('i',v_i,'name',v_name,'phone_tail',right(v_phone,3),
                  'credits',v_credits,'action','已存在（'||v_exist.name||'）→ 只補堂數');
    else
      v_new := v_new + 1;
      v_names := v_names || to_jsonb(v_name || '（' || right(v_phone,3) || '，' || v_credits || ' 堂）');
      v_plan := v_plan || jsonb_build_object('i',v_i,'name',v_name,'phone_tail',right(v_phone,3),
                  'credits',v_credits,'action','建客人 ＋ 補堂數');

      -- ☢️ 只有【要新建】的人才要過這一關（已存在的本來就不會重複建）
      for v_near in
        select c.name, right(c.phone,3) as tail,
               coalesce((select sum(l.delta) from public.credit_ledger l
                         where l.customer_id=c.id and l.product='GT'),0) as bal
        from public.customers c
        where c.is_active and public.name_close(v_name, c.name)
        limit 3
      loop
        v_warn := v_warn || jsonb_build_object('i',v_i,'name',v_name,'phone_tail',right(v_phone,3),
                    'looks_like', v_near.name||'（'||v_near.tail||'，剩 '||v_near.bal||' 堂）',
                    'why','☢️ 系統裡有名字很像的人。同一個人換過手機的話，建下去會變成兩筆資料、兩份堂數。');
      end loop;
    end if;
    v_credits_total := v_credits_total + v_credits;
  end loop;

  if jsonb_array_length(v_errors) > 0 then
    return jsonb_build_object('ok',false,'wrote',false,
      'why','有 '||jsonb_array_length(v_errors)||' 列不合格，整批都沒有寫入','errors',v_errors);
  end if;

  -- 預設是預演。要真的寫，必須明確傳 p_dry_run = false。
  if p_dry_run then
    return jsonb_build_object('ok',true,'wrote',false,'dry_run',true,'rows',v_i,
      'new_customers',v_new,'existing',v_reuse,'credits_total',v_credits_total,
      'warnings',v_warn,'new_names',v_names,'plan',v_plan);
  end if;

  -- ── 第二輪：真的寫（驗過了才會走到這裡）──────────────────
  select coalesce(sum(delta),0) into v_before from public.credit_ledger where product='GT';
  for r in select * from jsonb_array_elements(p_rows) loop
    v_name := btrim(r->>'name');
    v_phone := regexp_replace(r->>'phone','\D','','g');
    v_credits := (r->>'credits')::int;
    select id into v_cid from public.customers where phone = v_phone;
    if not found then
      insert into public.customers (name, phone, is_active, note)
      values (v_name, v_phone, true,
              to_char(now() at time zone 'Asia/Taipei','YYYY-MM-DD')||' 舊表孤兒補建')
      returning id into v_cid;
    end if;
    -- ☢️ amount 留 null —— 我們確實不知道當時收了多少錢。不要假裝知道。
    --    pay_method 也留 null，這樣它不會跑進「待入帳」清單（見 db/29）。
    insert into public.credit_ledger (customer_id, delta, reason, product, note, created_by)
    values (v_cid, v_credits, 'purchase', 'GT', '舊表期初結轉', public.my_employee_id());
  end loop;
  select coalesce(sum(delta),0) into v_after from public.credit_ledger where product='GT';

  return jsonb_build_object('ok',true,'wrote',true,'rows',v_i,'new_customers',v_new,
    'existing',v_reuse,'warnings',v_warn,'gt_before',v_before,'gt_after',v_after,
    'gt_delta',v_after - v_before);
end $$;

revoke all on function public.import_legacy_credits(jsonb, boolean) from public;
grant execute on function public.import_legacy_credits(jsonb, boolean) to authenticated;

-- ── 用法 ──────────────────────────────────────────────────────
--  ① 先預演（不會寫任何東西）：
--     select public.import_legacy_credits('[{"name":"王小明","phone":"0912345678","credits":10}]'::jsonb, true);
--  ② 看回傳的 plan 沒問題，再真的寫：
--     select public.import_legacy_credits('[...]'::jsonb, false);
--  ③ 回傳裡的 gt_before / gt_after / gt_delta 就是驗收 ——
--     gt_delta 必須等於名單上所有堂數的總和。

-- ── 驗收（2026-08-17 實測）─────────────────────────────────────
--  測試一：故意放五種錯（姓名一個字／手機格式錯／堂數 0／同批重複手機）
--          → 回傳 4 個錯誤，客人數 84 → 84，【一列都沒寫】✓
--  測試二：全對的資料預演 → 正確分出「建客人＋補堂數」和「已存在→只補堂數」✓
--  測試三：真的寫兩筆 → gt_before 551 → gt_after 584，delta ＝ 33 ＝ 10+23 ✓
--          清乾淨後回到 84 人／551 堂 ✓
--  測試四：放四個「名字很像現有客人」的新號碼 → 正確標出
--          林屏玟 ↔ 林屏妏、鄭旭媢 ↔ 鄭旭媚；陳荔芬和卓家夙沒被標（正確）✓
--
--  ☢️ 這道檢查【只警告、不擋】。它抓得到同音錯字，抓不到
--     「陳荔芬其實就是 Adele」那一種 —— 名字毫無關聯的，機器沒有辦法。
--     所以預演還會回傳 new_names（所有將要新建的名字），讓人掃一遍。
