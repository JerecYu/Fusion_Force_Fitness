-- ═══════════════════════════════════════════════════════════════════
-- db/63-expenses.sql — 支出簿
--
-- 專案：FFF 預約系統（fff-platform）· 第 92 步 · 2026-08-21
--
-- 起因：系統只認得【一種支出：教練薪資】。房租、水電、器材、通訊 ——
--   全部在系統外面。第 94 步的損益表是「收入 − 支出」，
--   而現在的支出只有薪資那一半。
--
-- ══ 這張表【故意沒有「薪資」這個科目】═══════════════════════════
-- ☢️☢️ 教練薪資由 payroll_month() 算（第 71–85 步）。
--    支出簿再記一次，損益表就會【扣兩遍】。
--    而且兩邊的數字幾乎一定會有落差（加給起訖日、作廢、補登），
--    到時候沒有人分得出哪一邊才是對的。
--    科目是外鍵，所以「薪資」【連插都插不進去】。
--
-- ══ 三種科目性質（kind）══════════════════════════════════════════
--   fixed    固定支出 —— 每個月幾乎一樣（房租、管理費、健保費）
--   variable 變動支出 —— 每次金額不同（電費、水費、通訊費、器材、雜支）
--   transfer 【內部提撥，不是支出】
--
-- ☢️☢️ transfer 為什麼要跟支出分開：
--    Jerec 2026-08-21：「備用金 每月固定提撥」。
--    提撥備用金是【錢從公司的一個口袋進另一個口袋】—— 它還在公司手上。
--    記成支出的話，損益表【每個月都會憑空少一筆】，
--    而那筆錢根本沒有離開公司。
--    真正的支出是備用金【被花掉】的時候（例如買器材），
--    那時候會用「器材」記一次 —— 提撥也算一次的話，同一筆錢算兩遍。
--    所以：transfer 進得了支出簿（看得到現金流動），
--    但【不計入損益】。第 94 步只加總 fixed ＋ variable。
--
-- ☢️ 用【一個 kind 欄位】而不是「kind ＋ 一個 is_expense 布林」：
--    兩個欄位可以互相矛盾（kind='transfer' 但 is_expense=true），
--    一個欄位不會。
--
-- ══ 一筆錢拆成幾列：bundle ═══════════════════════════════════════
-- ☢️ Jerec 2026-08-21 的房租結構：
--    公司付出去的租金成本是【總額】，但那筆錢分三個方向流出去：
--      1. 匯款給房東（每月 1 號）
--      2. 二代健保補充保費 —— 健保署規定，單次租金達 20,000 元時
--         按 2.11% 扣取
--      3. 租金所得扣繳稅款 —— 財政部規定，支付給境內居住個人的租金
--         原則上按 10% 扣繳
--    後兩筆是【暫代扣】：錢原本是房東的，公司先扣下來，
--    之後再替房東繳給政府。
--
-- ☢️ 為什麼三列而不是一列：
--    三塊錢的【付款對象與付款時間都不同】。記成一列的話，
--    「扣繳稅款這個月還沒繳」這件事【系統永遠看不到】——
--    而漏繳扣繳稅款是會被罰的。
-- ☢️ 為什麼不把代扣那兩列改掛「稅費」科目：
--    代扣那兩筆不是公司的稅，是【房東的】。掛到稅費去，
--    房租會看起來變便宜，而公司的稅會看起來變貴。兩邊都錯。
--    三列全部掛「房租」，加起來才是真正的租金成本。
-- ☢️ bundle 是 uuid（一次發生一個），不是文字標籤。
--    用文字的話「房租」這個 bundle 會把每一個月的房租全部黏在一起。
--
-- ══ 兩個日期，不是一個 ═══════════════════════════════════════════
-- ☢️ incurred_on（發生日）＝ 這筆算【哪一個月】的成本。
--    paid_on（付款日）＝ 錢【哪一天】離開帳戶。null ＝ 還沒付。
--    第 89 步已經裁決權責制，支出這一側必須跟著同一套。
-- ☢️ 收入那側的對稱物：paid_at（到帳日）／應收未收。
--    這裡是 paid_on（付款日）／【應付未付】。
--
-- ══ 週期：每月、每兩個月 ═════════════════════════════════════════
-- ☢️ Jerec：「每兩個月繳的變動支出：電費、水費」。
--    台電與自來水都是兩個月一期，而且【兩邊的期別還錯開】。
--    所以不能只有「複製上個月」——
--      monthly   的來源是【上個月】
--      bimonthly 的來源是【兩個月前】
--    各自從自己的上一期往前推，兩條錯開的週期就會各走各的。
--
-- ══ 唯一的「可以改」：還沒付的金額 ═══════════════════════════════
-- ☢️ 原則仍然是【作廢＋重記】，沒有全面的編輯。
--    但變動帳單（電費、水費、通訊費）每一期金額都不同，
--    複製過來的金額一定要能改，否則複製鈕等於沒用。
--    所以開一條窄路：【還沒付、而且沒作廢】的才能改金額。
--    付掉了就是既成事實，只能作廢重記。
--    （第 93 步月結之後還要再加一道「已結算不能改」。）
-- ═══════════════════════════════════════════════════════════════════

drop view   if exists public.finance_expenses;
drop table  if exists public.expenses cascade;
drop table  if exists public.expense_categories cascade;

-- ── 科目 ───────────────────────────────────────────────────────
create table public.expense_categories (
  code          text primary key,
  label         text not null,
  -- fixed 固定支出｜variable 變動支出｜transfer 內部提撥（不計入損益）
  kind          text not null default 'variable'
                check (kind in ('fixed','variable','transfer')),
  -- 新增時預設的週期，讓常見的那幾筆不用每次選
  default_recur text not null default 'none'
                check (default_recur in ('none','monthly','bimonthly')),
  sort_order    integer not null default 999,
  is_active     boolean not null default true,
  note          text
);

comment on table public.expense_categories is
  '支出科目。☢️ 這裡【沒有薪資】—— 教練薪資由 payroll_month() 算，記在這裡會扣兩遍。'
  'kind=transfer 的（備用金）會進支出簿但【不計入損益】。';

insert into public.expense_categories (code, label, kind, default_recur, sort_order, note) values
  ('rent',      '房租',     'fixed',    'monthly',   10,
     '☢️ 記的是【總額】。實際分三筆流出：匯款給房東、二代健保補充保費、租金所得扣繳稅款。後兩筆是暫代扣。'),
  ('mgmt',      '管理費',   'fixed',    'monthly',   20, null),
  ('health',    '健保費',   'fixed',    'monthly',   30,
     '☢️ 公司負擔的健保。商業保險（公共意外責任險那種）不要記在這裡。'),
  ('telecom',   '通訊費',   'variable', 'monthly',   40, '電話＋網路'),
  ('power',     '電費',     'variable', 'bimonthly', 50, '台電，兩個月一期'),
  ('water',     '水費',     'variable', 'bimonthly', 60, '自來水，兩個月一期'),
  ('equipment', '器材',     'variable', 'none',      70,
     '☢️ 購買與維修都算這一項 —— 不要再開一個「設備」'),
  ('misc',      '雜支',     'variable', 'none',      80,
     '☢️ 這一項越大代表科目表越不夠用，該檢討的是科目表'),
  ('reserve',   '備用金',   'transfer', 'monthly',   90,
     '☢️☢️ 這【不是支出】，是錢從公司的一個口袋進另一個口袋。不計入損益表。'
     '真正的支出是這筆錢被花掉的時候（那時候用對應的科目記）。');

alter table public.expense_categories enable row level security;
create policy "財務看得到科目" on public.expense_categories
  for select to authenticated using (public.is_finance());
grant select on public.expense_categories to authenticated;


-- ── 支出 ───────────────────────────────────────────────────────
create table public.expenses (
  id           uuid primary key default gen_random_uuid(),
  category     text not null references public.expense_categories(code),
  -- 這筆算哪一個月的成本（權責制的依據）
  incurred_on  date not null,
  -- 錢哪一天離開帳戶。☢️ null ＝ 還沒付，那就是「應付未付」。
  paid_on      date,
  amount       integer not null check (amount > 0),
  -- cash 現金｜transfer 匯款｜card 刷卡｜other 其他
  method       text check (method in ('cash','transfer','card','other')),
  payee        text,
  note         text,
  recur        text not null default 'none'
               check (recur in ('none','monthly','bimonthly')),
  -- ☢️ 同一筆錢拆成幾列時的群組。uuid 不是文字 ——
  --    文字標籤會把每個月的房租全部黏成同一組。
  bundle       uuid,
  -- ☢️ 暫代扣：錢原本是別人的（例：房東的稅），公司先扣下來再替他繳。
  withheld     boolean not null default false,
  -- 從哪一筆複製來的。☢️ 靠這一欄擋重複複製，不是靠金額比對。
  copied_from  uuid references public.expenses(id) on delete set null,
  voided       boolean not null default false,
  void_reason  text,
  voided_by    uuid references public.employees(id),
  voided_at    timestamptz,
  created_by   uuid references public.employees(id),
  created_at   timestamptz not null default now(),
  -- ☢️ 付了款卻不知道怎麼付的，對帳時查不下去。
  constraint expenses_paid_needs_method check (paid_on is null or method is not null)
);

create index expenses_incurred_idx on public.expenses (incurred_on);
create index expenses_category_idx on public.expenses (category);
-- 應付未付會很常查，而且只關心還沒付的
create index expenses_unpaid_idx on public.expenses (incurred_on)
  where paid_on is null and not voided;
create index expenses_copied_idx on public.expenses (copied_from);
create index expenses_bundle_idx on public.expenses (bundle) where bundle is not null;

comment on table public.expenses is
  '薪水以外的支出。incurred_on ＝ 算哪個月的成本（權責制）；paid_on ＝ 錢哪天離開帳戶，'
  'null 就是應付未付。bundle ＝ 同一筆錢拆成幾列（房租那種）。'
  '☢️ 只有【還沒付】的能改金額，其他一律作廢＋重記。';
comment on column public.expenses.withheld is
  '暫代扣：這筆錢原本是別人的（例：房東的二代健保補充保費、租金所得扣繳稅款），'
  '公司先從應付款中扣下來，之後再替對方繳給政府。';

alter table public.expenses enable row level security;
-- ☢️ 寫入完全不開 policy —— 一律走 RPC（第 39 步：動到規則的入口只有一個）
create policy "財務看得到支出" on public.expenses
  for select to authenticated using (public.is_finance());
grant select on public.expenses to authenticated;


-- ── 看板用的攤平檢視 ───────────────────────────────────────────
create or replace view public.finance_expenses as
select
  e.id,
  e.category,
  c.label                       as category_label,
  c.kind                        as kind,
  c.sort_order                  as category_sort,
  e.incurred_on,
  e.paid_on,
  e.amount,
  case e.method when 'cash' then '現金' when 'transfer' then '匯款'
                when 'card' then '刷卡' when 'other' then '其他'
                else null end   as method_label,
  e.method,
  e.payee,
  e.note,
  e.recur,
  case e.recur when 'monthly' then '每月' when 'bimonthly' then '每兩個月'
               else null end    as recur_label,
  e.bundle,
  e.withheld,
  (e.copied_from is not null)   as is_copy,
  e.voided,
  e.void_reason,
  vb.display_name               as voided_by_name,
  cb.display_name               as created_by_name,
  e.created_at
from public.expenses e
join public.expense_categories c on c.code = e.category
left join public.employees vb on vb.id = e.voided_by
left join public.employees cb on cb.id = e.created_by
where public.is_finance();

grant select on public.finance_expenses to authenticated;


-- ── 記一筆（可以一次記一組）─────────────────────────────────────
-- p_rows 是 jsonb 陣列，一列一個物件：
--   {"amount":<金額>,"payee":"房東","method":"transfer","paid_on":"2026-08-01",
--    "note":"","withheld":false}
-- ☢️ 一組要嘛全寫、要嘛全不寫。分三次呼叫的話，
--    第二次失敗會留下【半筆房租】—— 而那看起來像一筆正常的支出。
create or replace function public.add_expense(
  p_category    text,
  p_incurred_on date,
  p_rows        jsonb,
  p_recur       text default 'none'
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_label text; v_kind text; v_bundle uuid; v_me uuid;
  v_n int; v_total int := 0; v_i int; x jsonb;
  v_amt int; v_method text; v_paid date; v_ids uuid[] := '{}'; v_id uuid;
begin
  if not public.is_finance() then raise exception '支出簿只有負責人和財務可以動'; end if;

  select label, kind into v_label, v_kind from public.expense_categories
   where code = p_category and is_active;
  if v_label is null then
    return jsonb_build_object('ok', false, 'why', 'bad_category',
      'msg', '沒有這個科目，或這個科目已經停用');
  end if;
  if p_incurred_on is null then
    return jsonb_build_object('ok', false, 'why', 'no_date',
      'msg', '要寫發生日（這筆算哪個月的）');
  end if;
  -- ☢️ 未來的發生日通常是打錯年份，不是真的預先入帳
  if p_incurred_on > (current_date + 60) then
    return jsonb_build_object('ok', false, 'why', 'too_future',
      'msg', format('發生日 %s 在兩個月以後，確認一下年份有沒有打錯', p_incurred_on));
  end if;
  if coalesce(p_recur,'none') not in ('none','monthly','bimonthly') then
    return jsonb_build_object('ok', false, 'why', 'bad_recur', 'msg', '週期只能是 不固定／每月／每兩個月');
  end if;
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) = 0 then
    return jsonb_build_object('ok', false, 'why', 'no_rows', 'msg', '至少要有一列金額');
  end if;

  v_n := jsonb_array_length(p_rows);
  if v_n > 10 then
    return jsonb_build_object('ok', false, 'why', 'too_many', 'msg', '一組最多 10 列');
  end if;

  -- ══ 先驗全部，全對才寫（跟第 86 步匯入同一個原則）══
  for v_i in 0 .. v_n - 1 loop
    x := p_rows -> v_i;
    v_amt    := nullif(x ->> 'amount','')::int;
    v_method := nullif(btrim(coalesce(x ->> 'method','')),'');
    v_paid   := nullif(btrim(coalesce(x ->> 'paid_on','')),'')::date;

    if coalesce(v_amt, 0) <= 0 then
      return jsonb_build_object('ok', false, 'why', 'bad_amount',
        'msg', format('第 %s 列的金額要大於 0', v_i + 1));
    end if;
    if v_method is not null and v_method not in ('cash','transfer','card','other') then
      return jsonb_build_object('ok', false, 'why', 'bad_method',
        'msg', format('第 %s 列的付款方式只能是 現金／匯款／刷卡／其他', v_i + 1));
    end if;
    if v_paid is not null and v_method is null then
      return jsonb_build_object('ok', false, 'why', 'no_method',
        'msg', format('第 %s 列已經付款了，要寫付款方式 —— 不然對帳時查不出這筆錢從哪裡出去', v_i + 1));
    end if;
    if v_method is not null and v_paid is null then
      return jsonb_build_object('ok', false, 'why', 'no_paid_date',
        'msg', format('第 %s 列選了付款方式，就要寫付款日', v_i + 1));
    end if;
    v_total := v_total + v_amt;
  end loop;

  v_me := public.my_employee_id();
  -- 一列的不給 bundle —— 沒有東西要群組
  if v_n > 1 then v_bundle := gen_random_uuid(); end if;

  for v_i in 0 .. v_n - 1 loop
    x := p_rows -> v_i;
    insert into public.expenses
      (category, incurred_on, paid_on, amount, method, payee, note,
       recur, bundle, withheld, created_by)
    values
      (p_category, p_incurred_on,
       nullif(btrim(coalesce(x ->> 'paid_on','')),'')::date,
       (x ->> 'amount')::int,
       nullif(btrim(coalesce(x ->> 'method','')),''),
       nullif(btrim(coalesce(x ->> 'payee','')),''),
       nullif(btrim(coalesce(x ->> 'note','')),''),
       coalesce(p_recur,'none'), v_bundle,
       coalesce((x ->> 'withheld')::boolean, false), v_me)
    returning id into v_id;
    v_ids := v_ids || v_id;
  end loop;

  return jsonb_build_object('ok', true, 'ids', to_jsonb(v_ids), 'bundle', v_bundle,
    'n', v_n, 'total', v_total, 'category_label', v_label, 'kind', v_kind);
end $fn$;

revoke all on function public.add_expense(text, date, jsonb, text) from public, anon;
grant execute on function public.add_expense(text, date, jsonb, text) to authenticated;


-- ── 改金額（只有還沒付的）───────────────────────────────────────
-- ☢️ 這是【唯一】能就地改的東西，而且只在還沒付的時候。
--    電費、水費、通訊費每一期金額都不同，複製過來的金額不能改的話，
--    複製鈕等於沒用。付掉了就是既成事實 —— 只能作廢重記。
create or replace function public.update_unpaid_expense(
  p_id     uuid,
  p_amount integer,
  p_payee  text default null,
  p_note   text default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare v_e record;
begin
  if not public.is_finance() then raise exception '支出簿只有負責人和財務可以動'; end if;
  select * into v_e from public.expenses where id = p_id;
  if not found then return jsonb_build_object('ok', false, 'why', 'not_found'); end if;
  if v_e.voided then
    return jsonb_build_object('ok', false, 'why', 'voided', 'msg', '這筆已經作廢了');
  end if;
  if v_e.paid_on is not null then
    return jsonb_build_object('ok', false, 'why', 'already_paid',
      'msg', '這筆已經付掉了，不能改金額 —— 請作廢再重記，這樣才留得下痕跡');
  end if;
  if coalesce(p_amount, 0) <= 0 then
    return jsonb_build_object('ok', false, 'why', 'bad_amount', 'msg', '金額要大於 0');
  end if;

  update public.expenses
     set amount = p_amount,
         payee  = coalesce(nullif(btrim(p_payee),''), payee),
         note   = coalesce(nullif(btrim(p_note),''),  note)
   where id = p_id;

  return jsonb_build_object('ok', true, 'id', p_id, 'was', v_e.amount, 'now', p_amount);
end $fn$;

revoke all on function public.update_unpaid_expense(uuid, integer, text, text) from public, anon;
grant execute on function public.update_unpaid_expense(uuid, integer, text, text) to authenticated;


-- ── 付了 ───────────────────────────────────────────────────────
create or replace function public.mark_expense_paid(
  p_id     uuid,
  p_paid   date,
  p_method text
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare v_e record;
begin
  if not public.is_finance() then raise exception '支出簿只有負責人和財務可以動'; end if;
  select * into v_e from public.expenses where id = p_id;
  if not found then return jsonb_build_object('ok', false, 'why', 'not_found'); end if;
  if v_e.voided then
    return jsonb_build_object('ok', false, 'why', 'voided', 'msg', '這筆已經作廢了');
  end if;
  if v_e.paid_on is not null then
    return jsonb_build_object('ok', false, 'why', 'already',
      'msg', format('這筆已經標記在 %s 付掉了', v_e.paid_on));
  end if;
  if p_method not in ('cash','transfer','card','other') then
    return jsonb_build_object('ok', false, 'why', 'bad_method',
      'msg', '付款方式只能是 現金／匯款／刷卡／其他');
  end if;

  update public.expenses
     set paid_on = coalesce(p_paid, current_date), method = p_method
   where id = p_id;

  return jsonb_build_object('ok', true, 'id', p_id,
    'paid_on', coalesce(p_paid, current_date), 'amount', v_e.amount);
end $fn$;

revoke all on function public.mark_expense_paid(uuid, date, text) from public, anon;
grant execute on function public.mark_expense_paid(uuid, date, text) to authenticated;


-- ── 記錯了 ─────────────────────────────────────────────────────
create or replace function public.void_expense(p_id uuid, p_why text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare v_e record; v_n int;
begin
  if not public.is_finance() then raise exception '支出簿只有負責人和財務可以動'; end if;
  if coalesce(btrim(p_why),'') = '' then
    return jsonb_build_object('ok', false, 'why', 'no_reason', 'msg', '要寫作廢原因');
  end if;
  select * into v_e from public.expenses where id = p_id;
  if not found then return jsonb_build_object('ok', false, 'why', 'not_found'); end if;
  if v_e.voided then
    return jsonb_build_object('ok', false, 'why', 'already', 'msg', '這筆已經作廢過了');
  end if;

  -- ☢️ 一組（房租那種）要【整組一起作廢】。
  --    只廢掉其中一列，剩下的兩列會變成一筆金額對不起來的房租，
  --    而畫面上看起來完全正常。
  if v_e.bundle is not null then
    update public.expenses
       set voided = true, void_reason = btrim(p_why),
           voided_by = public.my_employee_id(), voided_at = now()
     where bundle = v_e.bundle and not voided;
    get diagnostics v_n = row_count;
  else
    update public.expenses
       set voided = true, void_reason = btrim(p_why),
           voided_by = public.my_employee_id(), voided_at = now()
     where id = p_id;
    v_n := 1;
  end if;

  return jsonb_build_object('ok', true, 'id', p_id, 'n', v_n,
    'amount', (select coalesce(sum(amount),0) from public.expenses
                where (v_e.bundle is not null and bundle = v_e.bundle) or id = p_id));
end $fn$;

revoke all on function public.void_expense(uuid, text) from public, anon;
grant execute on function public.void_expense(uuid, text) to authenticated;


-- ── 產生這個月的固定支出 ───────────────────────────────────────
-- ☢️ monthly 的來源是【上個月】，bimonthly 的來源是【兩個月前】。
--    台電和自來水都是兩個月一期，而且期別還錯開 ——
--    各自從自己的上一期往前推，兩條週期就會各走各的。
-- ☢️ 複製出來的 paid_on 一律是 null —— 複製的是「這個月也要付這筆」，
--    不是「這個月也已經付了」。把付款日一起複製過來，
--    帳上會出現一筆【從來沒發生過的付款】。
-- ☢️ 防重複按靠 copied_from，不是靠金額比對：
--    同一個來源在同一個月已經有小孩了就跳過。
--    用金額比對的話，「這個月真的付了兩次」會被誤判成重複。
-- ☢️ 位移用 interval，不是「加 N 天」。
--    1/31 加一個月，Postgres 會夾成 2/28；加 31 天會變成 3/3。
-- ☢️ 一組（房租三列）複製過去要拿到【一個新的 bundle】，
--    不能沿用舊的 —— 沿用的話每個月的房租會黏成同一組。
create or replace function public.expense_next_on(p_on date, p_recur text)
returns date
language sql
immutable
as $fn$
  select case p_recur
           when 'monthly'   then (p_on + interval '1 month')::date
           when 'bimonthly' then (p_on + interval '2 month')::date
         end
$fn$;

comment on function public.expense_next_on(date, text) is
  '這一期的下一期落在哪一天。☢️ 用 interval 不是加天數 —— 1/31 加一個月 Postgres 夾成 2/28，加 31 天會變 3/3。';

create or replace function public.copy_recurring_expenses(
  p_to_month date,                    -- 目標月份（給該月任一天都可以）
  p_dry_run  boolean default true
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_to   date := date_trunc('month', p_to_month)::date;
  v_nx   date;
  v_list jsonb; v_skip jsonb;
  v_n int := 0; v_amt int := 0;
begin
  if not public.is_finance() then raise exception '支出簿只有負責人和財務可以動'; end if;
  if p_to_month is null then raise exception '要給目標月份'; end if;
  v_nx := (v_to + interval '1 month')::date;

  -- 要複製的
  select coalesce(jsonb_agg(to_jsonb(s) order by s.sort_order, s.new_incurred_on), '[]'::jsonb),
         count(*), coalesce(sum(s.amount), 0)
    into v_list, v_n, v_amt
  from (
    select e.id, e.category, c.label as category_label, c.kind, c.sort_order,
           e.incurred_on, e.amount, e.payee, e.note, e.recur, e.bundle, e.withheld,
           public.expense_next_on(e.incurred_on, e.recur) as new_incurred_on
      from public.expenses e
      join public.expense_categories c on c.code = e.category
     where e.recur in ('monthly','bimonthly')
       and not e.voided
       and public.expense_next_on(e.incurred_on, e.recur) >= v_to
       and public.expense_next_on(e.incurred_on, e.recur) <  v_nx
       and not exists (select 1 from public.expenses x
                        where x.copied_from = e.id and not x.voided)
  ) s;

  -- 已經複製過、這次跳過的（要講出來，不然使用者會以為按鈕壞了）
  select coalesce(jsonb_agg(to_jsonb(k) order by k.sort_order), '[]'::jsonb)
    into v_skip
  from (
    select c.label as category_label, c.sort_order, e.amount, e.payee
      from public.expenses e
      join public.expense_categories c on c.code = e.category
     where e.recur in ('monthly','bimonthly') and not e.voided
       and public.expense_next_on(e.incurred_on, e.recur) >= v_to
       and public.expense_next_on(e.incurred_on, e.recur) <  v_nx
       and exists (select 1 from public.expenses x
                    where x.copied_from = e.id and not x.voided)
  ) k;

  if p_dry_run then
    return jsonb_build_object('ok', true, 'dry_run', true,
      'to_month', to_char(v_to, 'YYYY-MM'), 'n', v_n, 'amount', v_amt,
      'rows', v_list, 'skipped', v_skip);
  end if;

  -- ☢️ bundle 對照表要【先去重再產 uuid】。
  --    select distinct bundle, gen_random_uuid() 是錯的 —— gen_random_uuid()
  --    是 volatile，每一列都不一樣，distinct 就永遠去不掉重複，
  --    結果是房租三列各自拿到不同的 bundle，畫面上就散成三筆。
  with src as (
    select e.id, e.category, e.amount, e.payee, e.note, e.recur, e.bundle, e.withheld,
           public.expense_next_on(e.incurred_on, e.recur) as new_incurred_on
      from public.expenses e
     where e.recur in ('monthly','bimonthly')
       and not e.voided
       and public.expense_next_on(e.incurred_on, e.recur) >= v_to
       and public.expense_next_on(e.incurred_on, e.recur) <  v_nx
       and not exists (select 1 from public.expenses x
                        where x.copied_from = e.id and not x.voided)
  ),
  bmap as (
    select b.bundle as old_bundle, gen_random_uuid() as new_bundle
      from (select distinct bundle from src where bundle is not null) b
  )
  insert into public.expenses
    (category, incurred_on, paid_on, amount, method, payee, note,
     recur, bundle, withheld, copied_from, created_by)
  select s.category, s.new_incurred_on, null, s.amount, null, s.payee, s.note,
         s.recur, m.new_bundle, s.withheld, s.id, public.my_employee_id()
    from src s
    left join bmap m on m.old_bundle = s.bundle;

  return jsonb_build_object('ok', true, 'dry_run', false,
    'to_month', to_char(v_to, 'YYYY-MM'), 'n', v_n, 'amount', v_amt,
    'rows', v_list, 'skipped', v_skip);
end $fn$;

revoke all on function public.copy_recurring_expenses(date, boolean) from public, anon;
grant execute on function public.copy_recurring_expenses(date, boolean) to authenticated;


-- ── 支出報表 ───────────────────────────────────────────────────
-- ☢️ 這裡的區間看的是【發生日】，不是付款日。
--    收入那側（finance_report）看的是到帳日 —— 因為對帳報表回答的是
--    「這一天帳戶進來多少」。這裡回答的是「這個月花了多少」，
--    所以基準必須是發生日（第 89 步權責制）。
-- ☢️ 應付未付【不受區間影響】，跟收入那側的「待入帳」同一個理由：
--    兩個月前的扣繳稅款到現在還沒繳，才是最該看到的那一筆。
-- ☢️ sum.pl_amt ＝【進損益表的】＝ fixed ＋ variable。
--    transfer（備用金）不在裡面 —— 那筆錢還在公司手上。
create or replace function public.expense_report(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $fn$
declare v_rows jsonb; v_cat jsonb; v_unpaid jsonb; v_sum jsonb;
begin
  if not public.is_finance() then
    raise exception '支出簿只有負責人和財務看得到';
  end if;
  if p_from is null or p_to is null then raise exception '要給起訖日期'; end if;
  if p_to < p_from then raise exception '結束日期不能早於開始日期'; end if;
  if p_to - p_from > 366 then raise exception '一次最多查一年'; end if;

  select coalesce(jsonb_agg(to_jsonb(r) order by r.incurred_on, r.category_sort, r.withheld), '[]'::jsonb)
    into v_rows
  from (
    select id, category, category_label, kind, category_sort, incurred_on, paid_on,
           amount, method, method_label, payee, note, recur, recur_label,
           bundle, withheld, is_copy,
           voided, void_reason, voided_by_name, created_by_name
      from public.finance_expenses
     where incurred_on between p_from and p_to
  ) r;

  select coalesce(jsonb_agg(to_jsonb(g) order by g.category_sort), '[]'::jsonb)
    into v_cat
  from (
    select category, category_label, min(kind) as kind, min(category_sort) as category_sort,
           count(*) filter (where not voided)::int                        as n,
           coalesce(sum(amount) filter (where not voided), 0)::int         as amount,
           coalesce(sum(amount) filter (where not voided and paid_on is null), 0)::int as unpaid_amount
      from public.finance_expenses
     where incurred_on between p_from and p_to
     group by category, category_label
  ) g;

  -- ☢️ 不加日期條件 —— 拖最久的那幾筆才是最該看到的
  select coalesce(jsonb_agg(to_jsonb(u) order by u.incurred_on, u.withheld), '[]'::jsonb)
    into v_unpaid
  from (
    select id, category, category_label, kind, incurred_on, amount, payee, note,
           withheld, bundle, (current_date - incurred_on) as waited_days
      from public.finance_expenses
     where paid_on is null and not voided
  ) u;

  select jsonb_build_object(
           'n',           coalesce(count(*) filter (where not voided), 0),
           'amount',      coalesce(sum(amount) filter (where not voided), 0),
           'pl_amt',      coalesce(sum(amount) filter (where not voided and kind <> 'transfer'), 0),
           'fixed_amt',   coalesce(sum(amount) filter (where not voided and kind = 'fixed'), 0),
           'var_amt',     coalesce(sum(amount) filter (where not voided and kind = 'variable'), 0),
           'transfer_amt',coalesce(sum(amount) filter (where not voided and kind = 'transfer'), 0),
           'paid_amt',    coalesce(sum(amount) filter (where not voided and paid_on is not null), 0),
           'unpaid_amt',  coalesce(sum(amount) filter (where not voided and paid_on is null), 0),
           'withheld_amt',coalesce(sum(amount) filter (where not voided and withheld), 0),
           'void_n',      coalesce(count(*) filter (where voided), 0),
           'void_amt',    coalesce(sum(amount) filter (where voided), 0))
    into v_sum
  from public.finance_expenses
  where incurred_on between p_from and p_to;

  return jsonb_build_object(
    'ok', true, 'from', p_from, 'to', p_to,
    'made_at', to_char(now() at time zone 'Asia/Taipei', 'YYYY-MM-DD HH24:MI'),
    'sum', v_sum, 'rows', v_rows, 'by_category', v_cat, 'unpaid', v_unpaid);
end $fn$;

revoke all on function public.expense_report(date, date) from public, anon;
grant execute on function public.expense_report(date, date) to authenticated;

comment on function public.expense_report(date, date) is
  '支出報表。區間看【發生日】（權責制），不是付款日。'
  'pl_amt ＝ 進損益表的（fixed ＋ variable）—— transfer 是內部提撥，錢還在公司手上。'
  'unpaid ＝ 應付未付，不受區間影響。';
