-- ═══════════════════════════════════════════════════════════════════
-- db/58-phone-optional.sql — 手機可以留空，但一支號碼還是只能一個人
--
-- 專案：FFF 預約系統（fff-platform）· 第 87 步 · 2026-08-21
--
-- 起因：PT／PGT 的 155 位客人要進系統，其中【21 位沒有手機】——
--       聯絡不上，短期補不齊。而 customers.phone 當時是 not null，
--       他們一個都塞不進去。八月已經有 23 堂、37,400 業績掛在這群人身上。
--
-- ☢️☢️ 為什麼不塞假手機（Jerec 2026-08-21 問過「先用代號」）：
--   1. 報表上的「末三碼」會變成假的末三碼。對帳報表、停課通知的
--      「推不到的名單」都印它 —— 櫃檯拿它認人就會認錯人。
--   2. 手機是唯一鍵。代號哪天長得像號碼、或真的有人擁有那組號碼，就撞號。
--   3. 最難查的一種錯：資料看起來是完整的。
--      空值會逼人去處理，假值不會 —— 半年後沒有人記得那 21 筆是假的。
--
-- ☢️☢️ 【一支手機只能一個人】這條規則保留（Jerec 2026-08-21 定案）。
--   中途一度考慮開放家人共用（德龍爺爺與陳悠瑩 Lisa 共用 0935518808），
--   評估之後放棄，理由記在這裡免得將來有人重新想一次：
--     · 手機＝身分證這條規則的價值不在省程式，在於【沒有人需要記例外】。
--       開放共用之後，每一個「用手機找人」的地方都要處理「找到多個」，
--       而忘記的症狀是「查無此人」，不是報錯 —— 最難發現的那一種。
--     · 櫃檯用手機搜尋會跳出兩個人，點錯就扣到別人的堂數。
--     · 末三碼會失去辨識力（兩個人整支號碼一樣）。
--     · 真的要做「一家人」這件事，正確做法是一張【家庭關係表】，
--       不是讓兩個人共用唯一鍵。共用手機是那件事的窮人版，
--       而且會污染唯一鍵。號碼歸個人，關係歸關係。
--   → 所以德龍爺爺跟那 21 位同一類：【手機留空】。
--     號碼 0935518808 留給實際持有的陳悠瑩 Lisa。
--
-- ☢️ 留空的人是什麼狀態，要講清楚，不要以為建了就通了：
--   推不到任何通知、綁不了 LINE、查不到自己的堂數。
--   他【只存在於櫃檯的帳上】—— 可以被扣課、可以算業績，但看不到自己的頁面。
--   等哪天他走進門留下號碼，櫃檯補上去就全部接通。
--
-- ☢️ 櫃檯建檔【照樣必填手機】。可以留空的只有匯入那條路。
--   要讓一個人沒有手機，必須是「我們真的聯絡不上他」，
--   不能是「櫃檯懶得問」。
--
-- ☢️ Postgres 的 UNIQUE 本來就允許多個 NULL ——
--   所以「phone 可為空 ＋ UNIQUE(phone)」剛好就是我們要的：
--   有號碼的一號一人，沒號碼的要幾個有幾個。不需要 partial index。
-- ═══════════════════════════════════════════════════════════════════

-- ── ① 只放寬「可以留空」，唯一鍵不動 ───────────────────────────
alter table public.customers alter column phone drop not null;

-- 中途試過的 (phone, name) 複合唯一鍵：不採用，清掉。
drop index if exists public.customers_phone_name_uk;

do $$
begin
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.customers'::regclass
                    and conname  = 'customers_phone_key') then
    alter table public.customers add constraint customers_phone_key unique (phone);
  end if;
end $$;

comment on column public.customers.phone is
  '手機。一支號碼只能一個人（UNIQUE）。可以是 null —— 只給「真的聯絡不上、'
  '匯入進來的舊客人」用，這種人推不到通知、也綁不了 LINE；櫃檯建檔一律必填。';


-- ── ② 建客人：手機被佔用時，把「已經是誰」講出來 ─────────────────
-- ☢️ 中途做過 4 個參數的版本（p_allow_shared），策略改了之後要清掉 ——
--    留著會變成兩個多載，3 個參數的呼叫直接 ambiguous 而失敗。
--    drop 會把 GRANT 一起帶走，所以最後一定要重新 grant（第 66 步的坑）。
drop function if exists public.create_customer(text, text, text, boolean);
drop function if exists public.create_customer(text, text, text);

create or replace function public.create_customer(
  p_name     text,
  p_phone    text,
  p_nickname text default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare v_name text; v_nick text; v_phone text; v_exist record; v_id uuid;
begin
  if not public.is_staff() then
    raise exception '只有員工可以建立客人資料';
  end if;

  v_phone := regexp_replace(coalesce(p_phone, ''), '[\s\-()]', '', 'g');
  if v_phone like '+886%' then v_phone := '0' || substring(v_phone from 5);
  elsif v_phone like '886%' then v_phone := '0' || substring(v_phone from 4);
  end if;
  v_phone := regexp_replace(v_phone, '\D', '', 'g');

  -- ☢️ 櫃檯這條路不接受空手機。資料庫允許 null 是給匯入用的。
  if v_phone !~ '^09\d{8}$' then
    return jsonb_build_object('ok', false, 'why', 'bad_phone');
  end if;

  v_name := btrim(coalesce(p_name, ''));
  if length(regexp_replace(v_name, '[\s　]', '', 'g')) < 2 then
    return jsonb_build_object('ok', false, 'why', 'bad_name');
  end if;

  v_nick := nullif(btrim(coalesce(p_nickname, '')), '');

  select c.id, c.name, (c.line_user_id is not null) as bound, c.is_active
    into v_exist
  from public.customers c where c.phone = v_phone;

  if found then
    return jsonb_build_object('ok', false, 'why', 'phone_taken',
             'name', v_exist.name, 'bound', v_exist.bound, 'active', v_exist.is_active);
  end if;

  begin
    insert into public.customers (name, nickname, phone, is_active, note)
    values (v_name, v_nick, v_phone, true,
            to_char(now() at time zone 'Asia/Taipei', 'YYYY-MM-DD') || ' 教練後台建立')
    returning id into v_id;
  exception when unique_violation then
    -- 在我們讀取到寫入之間，有別的教練先建好了同一支號碼
    select c.id, c.name, (c.line_user_id is not null) as bound, c.is_active
      into v_exist
    from public.customers c where c.phone = v_phone;
    return jsonb_build_object('ok', false, 'why', 'phone_taken',
             'name', v_exist.name, 'bound', v_exist.bound, 'active', v_exist.is_active,
             'race', true);
  end;

  return jsonb_build_object('ok', true, 'id', v_id, 'name', v_name,
                            'nickname', v_nick, 'phone_tail', right(v_phone, 3));
end $fn$;

revoke all on function public.create_customer(text, text, text) from public, anon;
grant execute on function public.create_customer(text, text, text) to authenticated;

comment on function public.create_customer(text, text, text) is
  '教練後台建客人。手機必填且一支號碼只能一個人；已經被佔用時回 phone_taken 並附上現有的姓名。';
