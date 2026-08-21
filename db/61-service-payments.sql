-- ═══════════════════════════════════════════════════════════════════
-- db/61-service-payments.sql — 服務登記的收款
--
-- 專案：FFF 預約系統（fff-platform）· 第 90 步 · 2026-08-21
--
-- 起因：私人課那一側【只記了賺多少，沒記收到沒】。
--   credit_ledger 有 amount／pay_method／paid_at 三欄，所以 GT 分得出
--   「現金」「匯款」「還沒入帳」；service_records 一欄都沒有。
--   ☢️ 後果：企業包班動輒幾萬塊、而且幾乎一定是匯款 —— 那筆錢沒進帳，
--      現在【沒有任何一個畫面會提醒你】。
--
-- ══ 為什麼是一張表，不是三個欄位 ═══════════════════════════════
-- ☢️☢️ 一筆交易可以有【兩個付款人】。
--    Jerec 2026-08-21：「Usports 是政府惠民政策，客人用它省下 500，
--    實繳 14,500 給商家，但商家可以和政府申請拿回 500。」
--    → 收入是 15,000，其中 500 的付款人是【政府】，而且還沒到帳。
--    如果只加一欄 pay_method，這種交易永遠塞不進去 —— 只能記成
--    「14,500 現金」然後把 500 弄丟，或記成「15,000 現金」然後跟銀行對不起來。
--
--    健康化檔顯示 Usports 從 2024 年起出現過 25 次，而且長相不只一種：
--    「500元Usports」（折抵）、「多買兩堂 Usports」（換堂數）、
--    「動滋劵1000，500退款」（券＋退款混合）、金額 0 的純權益列。
--
-- ══ 錢掛在哪裡 ═══════════════════════════════════════════════════
-- ☢️ 這張表只記【在課堂當下收的錢】。
--    八月 231 筆裡有 173 筆是「扣預收」—— 那些錢在【購課的時候】就收了，
--    不該再記一次，否則收入會被算兩遍。
--    預收那一側的錢走 credit_ledger（GT 已經是這樣），
--    PT 的購課要等「私人課完整流程」才會有。
--
-- ☢️ 但不硬擋「扣預收也有收款」—— 真的會發生：
--    八月流水帳有一筆「50塊差額是上次付款時未找錢」。
--    改成【非單堂收款必須寫原因】，讓例外留下痕跡而不是被擋掉。
--
-- ☢️ 方法代碼跟 credit_ledger 用【同一組】：cash／transfer。
--    不一樣的話，第 91 步合併兩邊時就要寫一張轉換表 ——
--    而轉換表就是下一個對不起來的地方。
-- ═══════════════════════════════════════════════════════════════════

create table if not exists public.service_payments (
  id         uuid primary key default gen_random_uuid(),
  service_id uuid not null references public.service_records(id) on delete cascade,
  -- cash 現金｜transfer 匯款｜subsidy 政府補助（Usports／動滋券）｜other 其他
  method     text not null check (method in ('cash','transfer','subsidy','other')),
  -- 付款人。現金／匯款留空＝客人本人；補助要寫是誰付的（例：Usports）
  payer      text,
  amount     integer not null check (amount > 0),
  -- ☢️ null ＝【還沒到帳】。匯款在途、補助還沒撥下來，都是 null。
  --    第 91 步的「待入帳」就是靠這一欄。
  paid_at    timestamptz,
  note       text,
  created_by uuid references public.employees(id),
  created_at timestamptz not null default now()
);

create index if not exists service_payments_service_idx on public.service_payments (service_id);
-- 待入帳查詢會很常跑，而且只關心還沒到帳的那幾筆
create index if not exists service_payments_unpaid_idx on public.service_payments (service_id)
  where paid_at is null;

comment on table public.service_payments is
  '服務登記【在課堂當下收的錢】。一筆服務可以有多列 —— Usports 那種「客人付一部分、'
  '政府付一部分」就是兩列。扣預收的錢不在這裡，它在購課的時候就收了（credit_ledger）。';
comment on column public.service_payments.paid_at is
  'null ＝ 還沒到帳。匯款在途、政府補助還沒撥，都是 null；第 91 步的「待入帳」看這一欄。';

alter table public.service_payments enable row level security;

-- ☢️ 寫入完全不開 policy —— 所有異動一律走 RPC，
--    跟第 39 步「動到規則的入口只有一個」同一個原則。
drop policy if exists "職員看得到收款" on public.service_payments;
create policy "職員看得到收款" on public.service_payments
  for select to authenticated using (public.is_staff());

grant select on public.service_payments to authenticated;


-- ── 一筆服務收了多少、還差多少 ─────────────────────────────────
create or replace view public.staff_service_pay as
select
  s.id                                            as service_id,
  -- 客人這一堂該付多少。☢️ 扣預收和體驗課是 0 —— 錢不是在這一堂收的。
  case when s.charge_method = 'single'
       then s.revenue_amount + s.travel_fee else 0 end as due_amount,
  coalesce(sum(p.amount), 0)::int                 as paid_amount,
  coalesce(sum(p.amount) filter (where p.paid_at is not null), 0)::int as in_amount,
  coalesce(sum(p.amount) filter (where p.paid_at is null), 0)::int     as pending_amount,
  count(p.id)::int                                as n_payments,
  coalesce(string_agg(distinct p.method, ',' order by p.method), '')   as methods
from public.service_records s
left join public.service_payments p on p.service_id = s.id
where public.is_staff()
group by s.id, s.charge_method, s.revenue_amount, s.travel_fee;

grant select on public.staff_service_pay to authenticated;

comment on view public.staff_service_pay is
  'due_amount ＝ 這一堂客人該付（扣預收與體驗課是 0）｜paid_amount 已登記的收款｜'
  'in_amount 已到帳｜pending_amount 還沒到帳。due 與 paid 對不起來的那幾筆就是要查的。';


-- ── 記一筆收款 ─────────────────────────────────────────────────
create or replace function public.add_service_payment(
  p_service uuid,
  p_method  text,
  p_amount  integer,
  p_paid    boolean default true,   -- 已經到帳了嗎（現金一定是 true；匯款在途、補助未撥是 false）
  p_payer   text default null,
  p_note    text default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare v_s record; v_due int; v_paid int; v_id uuid;
begin
  if not public.is_staff() then raise exception '只有職員可以登記收款'; end if;

  if p_method not in ('cash','transfer','subsidy','other') then
    return jsonb_build_object('ok', false, 'why', 'bad_method',
      'msg', '收款方式只能是 現金／匯款／補助／其他');
  end if;
  if coalesce(p_amount, 0) <= 0 then
    return jsonb_build_object('ok', false, 'why', 'bad_amount', 'msg', '金額要大於 0');
  end if;

  select * into v_s from public.service_records where id = p_service;
  if not found then
    return jsonb_build_object('ok', false, 'why', 'not_found', 'msg', '找不到這筆服務紀錄');
  end if;
  if v_s.voided then
    return jsonb_build_object('ok', false, 'why', 'voided', 'msg', '這筆已經作廢了，不能再記收款');
  end if;

  -- ☢️ 補助一定要寫付款人。「500 補助」而不知道是誰付的，
  --    等於知道錢會來、但不知道要跟誰要。
  if p_method = 'subsidy' and coalesce(btrim(p_payer),'') = '' then
    return jsonb_build_object('ok', false, 'why', 'no_payer',
      'msg', '補助要寫付款人（例：Usports）—— 不然不知道這 500 要跟誰要');
  end if;

  v_due := case when v_s.charge_method = 'single'
                then v_s.revenue_amount + v_s.travel_fee else 0 end;
  select coalesce(sum(amount),0) into v_paid
    from public.service_payments where service_id = p_service;

  -- ☢️ 單堂：收款合計不能超過客人該付的。打錯一個 0 就會被擋下來。
  if v_s.charge_method = 'single' and v_paid + p_amount > v_due then
    return jsonb_build_object('ok', false, 'why', 'over_paid',
      'msg', format('這一堂客人只該付 %s 元，已經記了 %s，再加 %s 會超過。', v_due, v_paid, p_amount));
  end if;

  -- ☢️ 不是單堂卻有收款 —— 真的會發生（補差額、找零），但一定要寫原因，
  --    否則那筆錢會變成「重複認列的收入」而沒有人知道為什麼。
  if v_s.charge_method <> 'single' and coalesce(btrim(p_note),'') = '' then
    return jsonb_build_object('ok', false, 'why', 'need_note',
      'msg', '這一堂是扣預收或體驗課，錢應該在購課時就收了。真的要記收款請寫原因。');
  end if;

  insert into public.service_payments (service_id, method, payer, amount, paid_at, note, created_by)
  values (p_service, p_method, nullif(btrim(p_payer),''), p_amount,
          case when p_paid then now() else null end,
          nullif(btrim(p_note),''), public.my_employee_id())
  returning id into v_id;

  select coalesce(sum(amount),0) into v_paid
    from public.service_payments where service_id = p_service;

  return jsonb_build_object('ok', true, 'id', v_id,
    'due', v_due, 'paid', v_paid, 'gap', v_due - v_paid);
end $fn$;

revoke all on function public.add_service_payment(uuid, text, integer, boolean, text, text)
  from public, anon;
grant execute on function public.add_service_payment(uuid, text, integer, boolean, text, text)
  to authenticated;


-- ── 到帳了 ─────────────────────────────────────────────────────
create or replace function public.mark_payment_in(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare v_p record;
begin
  if not public.is_staff() then raise exception '只有職員可以標記到帳'; end if;
  select * into v_p from public.service_payments where id = p_id;
  if not found then return jsonb_build_object('ok', false, 'why', 'not_found'); end if;
  if v_p.paid_at is not null then
    return jsonb_build_object('ok', false, 'why', 'already', 'msg', '這一筆已經標記到帳了');
  end if;
  update public.service_payments set paid_at = now() where id = p_id;
  return jsonb_build_object('ok', true, 'id', p_id, 'amount', v_p.amount);
end $fn$;

revoke all on function public.mark_payment_in(uuid) from public, anon;
grant execute on function public.mark_payment_in(uuid) to authenticated;


-- ── 記錯了 ─────────────────────────────────────────────────────
-- ☢️ 這一支是真的刪除，不是作廢 —— 收款列還很新、量也小，
--    留一堆作廢列只會讓對帳更難讀。但【刪掉這件事要留痕】：
--    寫進母筆服務紀錄的人工註記。
create or replace function public.remove_service_payment(p_id uuid, p_why text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare v_p record; v_who text;
begin
  if not public.is_finance() then raise exception '只有財務可以刪除收款紀錄'; end if;
  if coalesce(btrim(p_why),'') = '' then
    return jsonb_build_object('ok', false, 'why', 'no_reason', 'msg', '要寫刪除原因');
  end if;
  select * into v_p from public.service_payments where id = p_id;
  if not found then return jsonb_build_object('ok', false, 'why', 'not_found'); end if;

  select display_name into v_who from public.employees where id = v_p.created_by;

  update public.service_records
     set manual_note = concat_ws(' ｜ ', nullif(manual_note,''),
           to_char(now() at time zone 'Asia/Taipei','YYYY-MM-DD HH24:MI')
           || ' 刪除一筆收款（' || v_p.method || ' ' || v_p.amount || ' 元，'
           || coalesce(v_who,'不明') || ' 登的）：' || btrim(p_why))
   where id = v_p.service_id;

  delete from public.service_payments where id = p_id;

  return jsonb_build_object('ok', true, 'service_id', v_p.service_id, 'amount', v_p.amount);
end $fn$;

revoke all on function public.remove_service_payment(uuid, text) from public, anon;
grant execute on function public.remove_service_payment(uuid, text) to authenticated;
