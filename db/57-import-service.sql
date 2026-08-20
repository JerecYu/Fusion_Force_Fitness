-- ═══════════════════════════════════════════════════════════════════
-- db/57-import-service.sql — 服務紀錄批次匯入
--
-- 專案：FFF 預約系統（fff-platform）· 第 86 步 · 2026-08-20
--
-- 實測（2026-08-20，全程 rollback）：
--   ① 好資料預演 → errors 0、3 筆、預期業績 6,200
--   ② 壞資料預演 → 抓到 6 個錯（教練不存在／PT 填 3 人／業績對不上／完成日跨月／外派交通費不是 500／同批重複 key）
--   ③ 壞資料真的按下寫入 → wrote=false，表裡還是 0 列  ☢️ 這一條才是「全對才寫」的證明
--   ④ 好資料真的寫 → 3 筆、業績 0→6,200、教練關聯 3 筆
--   ⑤ 帶 flag 的那一筆被強制留在「待確認」 → 1 筆
--   ⑥ 同一批再跑一次 → 3 筆全部被 import_key 擋下來
--
-- 起因：八月有 231 堂 PT／PGT 上完了，但 service_records 是 0 筆。
--       薪資報表的「PT＋PGT 抽成」因此是 0 —— 那不是算錯，是算對了一張空表。
--       231 筆用畫面一筆一筆登要四五個小時，所以要一支匯入工具。
--
-- ☢️ 這個 repo 是公開的。這支檔案裡【沒有任何一筆資料】——
--    名字、金額、客人一律走呼叫時傳進來的 jsonb，不寫進版控。
--
-- ☢️ 設計原則跟第 30 步的 import_legacy_credits 一樣：
--    【先驗全部，全對才寫】。一次進 231 筆，最危險的失敗是「做到一半」：
--    前 100 筆寫進去了、第 101 筆教練名字打錯而中斷，然後沒有人知道停在哪，
--    重跑會讓一部分課變成兩倍業績。
--
-- ☢️ 防重靠 import_key 的唯一索引，不靠人記得自己跑過沒有。
--    key 由呼叫端用「內容」算出來（不是流水號），所以同一批資料重跑第二次
--    會被資料庫擋下來，而不是安靜地寫第二份。
-- ═══════════════════════════════════════════════════════════════════

-- ── ① 防重用的欄位 ──────────────────────────────────────────────
alter table public.service_records
  add column if not exists import_key text;

-- 部分唯一索引：手動登記的紀錄 import_key 是 null，不受影響
create unique index if not exists service_records_import_key_uk
  on public.service_records (import_key)
  where import_key is not null;

comment on column public.service_records.import_key is
  '批次匯入的內容鑰匙。手動登記的是 null。同一把鑰匙只能存在一次 —— 這是重跑的保險絲。';


-- ── ② 匯入函式 ─────────────────────────────────────────────────
-- p_rows 每一列要有：
--   key      內容鑰匙（呼叫端算，同一筆資料算出來永遠一樣）
--   done_at  完成時間，帶時區（例：2026-08-01T13:00:00+08:00）
--   coach    教練 display_name
--   stype    PT / PGT / PT_OUT / PGT_OUT / CORP / EVENT
--   charge   single / plan / free
--   n        購買商品人數規格
--   revenue  課程費
--   travel   交通費（外派固定 500，其餘 0）
--   perf     抽成前業績  ☢️ 必須等於 revenue + travel
--   note     原始備註（原始學員字串、方案、來源檔）
--   flag     人工核定備註；有值代表這一筆有疑義，會被強制留在「待確認」
--
create or replace function public.import_service_batch(
  p_rows    jsonb,
  p_batch   text,
  p_month   date,
  p_dry_run boolean default true,
  p_fin     text    default 'pending'
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_me     uuid;
  v_errs   text[] := '{}';
  v_n      int    := 0;
  v_row    jsonb;
  v_i      int    := 0;
  v_coach  uuid;
  v_perf   int;
  v_rev    int;
  v_trv    int;
  v_n_head int;
  v_stype  text;
  v_chg    text;
  v_when   timestamptz;
  v_key    text;
  v_id     uuid;
  v_before numeric;
  v_after  numeric;
  v_out    jsonb;
begin
  if not public.is_finance() then
    raise exception '只有負責人和財務可以匯入服務紀錄';
  end if;
  if p_fin not in ('pending','final') then
    raise exception 'p_fin 只能是 pending 或 final';
  end if;
  if jsonb_typeof(p_rows) <> 'array' then
    raise exception 'p_rows 要是陣列';
  end if;
  if coalesce(p_batch,'') = '' then
    raise exception '要給 p_batch（批次名稱），它是 import_key 的前綴';
  end if;

  select id into v_me from public.employees where auth_user_id = auth.uid();

  -- 匯入前的當月業績，等一下拿來對照
  select coalesce(sum(perf_amount),0) into v_before
    from public.service_records
   where not voided
     and (done_at at time zone 'Asia/Taipei')::date
         between date_trunc('month', p_month)::date
             and (date_trunc('month', p_month) + interval '1 month - 1 day')::date;

  -- ══ 第一輪：只驗，不寫 ════════════════════════════════════════
  for v_row in select * from jsonb_array_elements(p_rows) loop
    v_i := v_i + 1;
    v_key := p_batch || '#' || coalesce(v_row->>'key','');

    if coalesce(v_row->>'key','') = '' then
      v_errs := v_errs || format('第 %s 列：沒有 key', v_i);
    end if;

    select id into v_coach from public.employees
     where display_name = (v_row->>'coach') and is_active and can_teach;
    if v_coach is null then
      v_errs := v_errs || format('第 %s 列：找不到在職的授課教練「%s」', v_i, v_row->>'coach');
    end if;

    begin
      v_when := (v_row->>'done_at')::timestamptz;
    exception when others then
      v_when := null;
      v_errs := v_errs || format('第 %s 列：完成時間讀不出來（%s）', v_i, v_row->>'done_at');
    end;

    if v_when is not null then
      if (v_when at time zone 'Asia/Taipei')::date
         not between date_trunc('month', p_month)::date
                 and (date_trunc('month', p_month) + interval '1 month - 1 day')::date then
        v_errs := v_errs || format('第 %s 列：完成日 %s 不在指定的月份裡', v_i,
                                   (v_when at time zone 'Asia/Taipei')::date);
      end if;
      if v_when > now() then
        v_errs := v_errs || format('第 %s 列：完成時間在未來', v_i);
      end if;
    end if;

    v_stype := v_row->>'stype';
    if v_stype not in ('PT','PGT','PT_OUT','PGT_OUT','CORP','EVENT') then
      v_errs := v_errs || format('第 %s 列：服務類型「%s」不認得', v_i, v_stype);
    end if;

    v_chg := coalesce(v_row->>'charge','single');
    if v_chg not in ('single','plan','free') then
      v_errs := v_errs || format('第 %s 列：銷課方式「%s」不認得', v_i, v_chg);
    end if;

    v_n_head := coalesce((v_row->>'n')::int, 0);
    if v_stype in ('PT','PT_OUT') and v_n_head not between 1 and 2 then
      v_errs := v_errs || format('第 %s 列：PT 只能 1～2 人，這筆是 %s 人（規則第二篇 1.1）', v_i, v_n_head);
    end if;
    if v_stype in ('PGT','PGT_OUT') and v_n_head not between 3 and 6 then
      v_errs := v_errs || format('第 %s 列：PGT 只能 3～6 人，這筆是 %s 人（規則第二篇 1.2）', v_i, v_n_head);
    end if;

    v_perf := coalesce((v_row->>'perf')::int, -1);
    v_rev  := coalesce((v_row->>'revenue')::int, -1);
    v_trv  := coalesce((v_row->>'travel')::int, -1);
    if v_perf < 0 or v_rev < 0 or v_trv < 0 then
      v_errs := v_errs || format('第 %s 列：金額不能是負的或空的', v_i);
    -- ☢️ 這一條是整支最重要的檢查：業績必須等於課程費加交通費。
    --    對不起來就代表分類或金額有一個是錯的，而【兩種錯都算得出一個合理的數字】。
    elsif v_perf <> v_rev + v_trv then
      v_errs := v_errs || format('第 %s 列：業績 %s ≠ 課程費 %s ＋ 交通費 %s', v_i, v_perf, v_rev, v_trv);
    end if;

    if v_stype in ('PT_OUT','PGT_OUT') and v_trv <> 500 then
      v_errs := v_errs || format('第 %s 列：外派的交通費固定 500，這筆是 %s（規則第二篇 2）', v_i, v_trv);
    end if;
    if v_stype in ('PT','PGT') and v_trv <> 0 then
      v_errs := v_errs || format('第 %s 列：不是外派卻有交通費 %s', v_i, v_trv);
    end if;

    if exists (select 1 from public.service_records where import_key = v_key) then
      v_errs := v_errs || format('第 %s 列：這一筆已經匯入過了（%s）', v_i, v_key);
    end if;

    v_n := v_n + 1;
  end loop;

  -- 同一批裡自己重複（☢️ 這是 2026-08-20 那份流水帳真的踩到的情況：
  --    Jessica 8/03 的兩堂各出現兩次。資料庫的唯一索引擋得住重跑，
  --    但擋不住「同一次呼叫裡就帶了兩份」——所以這裡要另外檢查。）
  if (select count(*) from (
        select x->>'key' as k
          from jsonb_array_elements(p_rows) x
         group by 1 having count(*) > 1
      ) d) > 0 then
    -- ☢️ 這個 ::text 不能拿掉。text[] || '字串' 會被當成「陣列 || 陣列」，
    --    Postgres 去解析那個字串當陣列字面值，然後噴 malformed array literal。
    --    上面每一條都是 format() 回傳的 text 所以沒事，只有這條是裸字串。
    --    2026-08-20 第一次測試就是被這一行擋下來的。
    v_errs := v_errs || '這一批資料裡有重複的 key'::text;
  end if;

  if array_length(v_errs,1) > 0 then
    return jsonb_build_object('ok', false, 'wrote', false,
      'n_rows', v_n, 'n_errors', array_length(v_errs,1),
      'errors', to_jsonb(v_errs[1:40]));
  end if;

  if p_dry_run then
    return jsonb_build_object('ok', true, 'wrote', false, 'dry_run', true,
      'n_rows', v_n, 'n_errors', 0,
      'perf_before', v_before,
      'perf_after_expected', v_before + (select coalesce(sum((x->>'perf')::int),0) from jsonb_array_elements(p_rows) x));
  end if;

  -- ══ 第二輪：寫 ═══════════════════════════════════════════════
  v_i := 0;
  for v_row in select * from jsonb_array_elements(p_rows) loop
    v_i   := v_i + 1;
    v_key := p_batch || '#' || (v_row->>'key');
    select id into v_coach from public.employees
     where display_name = (v_row->>'coach') and is_active and can_teach;

    -- ☢️ 有疑義的那幾筆強制留在「待確認」 —— 它們會出現在薪資報表的
    --    「暫停自動計薪」區，而不是安靜地混進去。
    insert into public.service_records
      (service_type, done_at, headcount, attended_count, charge_method,
       revenue_amount, travel_fee, perf_amount,
       fin_status, fin_by, fin_at, note, manual_note, import_key, created_by)
    values
      (v_row->>'stype', (v_row->>'done_at')::timestamptz,
       (v_row->>'n')::int, (v_row->>'n')::int, coalesce(v_row->>'charge','single'),
       (v_row->>'revenue')::int, (v_row->>'travel')::int, (v_row->>'perf')::int,
       case when coalesce(v_row->>'flag','') <> '' then 'pending' else p_fin end,
       case when coalesce(v_row->>'flag','') <> '' or p_fin <> 'final' then null else v_me end,
       case when coalesce(v_row->>'flag','') <> '' or p_fin <> 'final' then null else now() end,
       nullif(v_row->>'note',''),
       nullif(concat_ws(' ｜ ', '批次匯入 '||p_batch, nullif(v_row->>'flag','')), ''),
       v_key, v_me)
    returning id into v_id;

    insert into public.service_coaches (service_id, coach_id, is_lead)
    values (v_id, v_coach, true);
  end loop;

  select coalesce(sum(perf_amount),0) into v_after
    from public.service_records
   where not voided
     and (done_at at time zone 'Asia/Taipei')::date
         between date_trunc('month', p_month)::date
             and (date_trunc('month', p_month) + interval '1 month - 1 day')::date;

  select jsonb_agg(t) into v_out from (
    select e.display_name as coach, count(*) as n, sum(s.perf_amount) as perf,
           count(*) filter (where s.fin_status <> 'final') as 待確認
      from public.service_records s
      join public.service_coaches sc on sc.service_id = s.id and sc.is_lead
      join public.employees e on e.id = sc.coach_id
     where s.import_key like p_batch || '#%'
     group by e.display_name order by sum(s.perf_amount) desc
  ) t;

  return jsonb_build_object('ok', true, 'wrote', true, 'n_rows', v_n,
    'perf_before', v_before, 'perf_after', v_after, 'by_coach', v_out);
end;
$fn$;

revoke all on function public.import_service_batch(jsonb,text,date,boolean,text) from public, anon, authenticated;
grant execute on function public.import_service_batch(jsonb,text,date,boolean,text) to authenticated;

comment on function public.import_service_batch(jsonb,text,date,boolean,text) is
  '服務紀錄批次匯入。先驗全部、全對才寫；預設是預演，要真的寫必須明確傳 p_dry_run => false。';
