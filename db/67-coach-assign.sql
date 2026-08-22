-- ═══════════════════════════════════════════════════════════════════
-- db/67-coach-assign.sql — 學員歸屬哪位教練
--
-- 專案：FFF 預約系統（fff-platform）· 修補 · 2026-08-22
--
-- 起因：Jerec 2026-08-22 ——「客人們有時候會換教練，需要在教練後台中
--   自訂有關既有學員的教練歸屬」。
--
-- ☢️ 資料【早就在了，只是被丟掉了】。
--    Active Client List V3 有一欄「負責教練」，155 位全部有值。
--    第 36 步匯入客戶時我只帶了姓名、手機、編號、備註 ——
--    因為 customers 根本沒有教練欄位，那一欄就這樣不見了。
--
-- ══ 為什麼是一張多對多的表，不是 customers 加一欄 ═════════════
-- ☢️ 155 位裡有 10 位是【兩位教練共同負責】（「Johnson、VC」這種）。
--    一個 coach_id 欄位裝不下兩個人。
--    硬塞的話只有兩條路：挑一個丟掉另一個（資料就是錯的），
--    或者把兩個名字塞進同一個文字欄（那就查不動了）。
-- ☢️ 而且「我的學員」清單要的正是多對多：共同負責的客人
--    【本來就應該同時出現在兩位教練的名單上】。
--
-- ══ 為什麼現值和歷史分開存 ═══════════════════════════════════════
--   customer_coaches      → 現在是誰的（好查、好顯示、UI 簡單）
--   customer_coach_log    → 誰在哪一天改的、為什麼（只增不刪）
--
-- ☢️ 沒有做「起訖日」。理由是現在的抽成【跟歸屬無關】——
--    誰上的課誰抽，歸屬只是一個標籤。
--    但哪天要做「客人續約，歸屬教練抽 X%」，就必須答得出
--    「八月的時候這個客人是誰的」—— 那時候 log 查得出來。
--    ☢️ 先做起訖日是把一個還不存在的需求提前變成 UI 複雜度；
--       完全不留痕跡則是把未來的路堵死。留 log 是兩者之間唯一划算的點。
--
-- ══ 誰能改 ═══════════════════════════════════════════════════════
-- ☢️ 看得到 ＝ 所有職員；改 ＝ 只有負責人和財務。
--    教練互相改歸屬會變成搶客人 —— 這不是資安問題，是人的問題，
--    但它一樣要在資料庫擋，不能只靠前端不畫按鈕。
-- ═══════════════════════════════════════════════════════════════════

create table if not exists public.customer_coaches (
  customer_id uuid not null references public.customers(id) on delete cascade,
  coach_id    uuid not null references public.employees(id) on delete cascade,
  created_at  timestamptz not null default now(),
  created_by  uuid references public.employees(id),
  primary key (customer_id, coach_id)
);

create index if not exists customer_coaches_coach_idx on public.customer_coaches (coach_id);

comment on table public.customer_coaches is
  '學員歸屬哪位教練。多對多 —— 有客人是兩位教練共同負責的，'
  '而且那種客人本來就該同時出現在兩位的「我的學員」清單上。';

-- ── 異動紀錄（只增不刪）────────────────────────────────────────
create table if not exists public.customer_coach_log (
  id          uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  coach_id    uuid not null references public.employees(id),
  action      text not null check (action in ('add','remove')),
  why         text,
  changed_by  uuid references public.employees(id),
  changed_at  timestamptz not null default now()
);

create index if not exists customer_coach_log_cust_idx on public.customer_coach_log (customer_id, changed_at desc);

comment on table public.customer_coach_log is
  '歸屬異動的痕跡。☢️ 只增不刪 —— 這張表存在的唯一理由是「三個月後查得出'
  '八月那個客人是誰的」，能刪就沒有意義了。';

alter table public.customer_coaches   enable row level security;
alter table public.customer_coach_log enable row level security;

drop policy if exists "職員看得到歸屬" on public.customer_coaches;
create policy "職員看得到歸屬" on public.customer_coaches
  for select to authenticated using (public.is_staff());
drop policy if exists "職員看得到異動" on public.customer_coach_log;
create policy "職員看得到異動" on public.customer_coach_log
  for select to authenticated using (public.is_staff());

grant select on public.customer_coaches   to authenticated;
grant select on public.customer_coach_log to authenticated;


-- ── 一位客人一列，教練併成陣列 ─────────────────────────────────
-- ☢️ 一位客人一列（不是一組歸屬一列）。前端要的是
--    「這個人是誰的」而不是「這一組關係」——
--    一組一列的話，共同負責的客人在清單上會出現兩次。
create or replace view public.staff_clients_coach as
select
  c.id                       as customer_id,
  c.name                     as customer_name,
  coalesce(c.nickname, '')   as nickname,
  right(c.phone, 3)          as phone_tail,
  coalesce(c.client_code, '') as client_code,
  c.is_active,
  coalesce(array_agg(e.id)            filter (where e.id is not null), '{}')::uuid[] as coach_ids,
  coalesce(string_agg(e.display_name, '、' order by e.display_name)
             filter (where e.id is not null), '')                                   as coach_names,
  count(e.id)::int           as n_coaches,
  -- 帳本餘額（GT 那一側；私人課要等第 93 步的期初餘額匯入）
  coalesce((select sum(l.delta) from public.credit_ledger l where l.customer_id = c.id), 0)::int as balance,
  -- 最後一次上課：團課與私人課取比較晚的那一個
  greatest(
    (select max(s.session_date)::timestamptz
       from public.bookings b join public.class_sessions s on s.id = b.session_id
      where b.customer_id = c.id and b.status = 'attended'),
    (select max(sr.done_at)
       from public.service_records sr
      where sr.customer_id = c.id and not sr.voided)
  ) as last_class_at
from public.customers c
left join public.customer_coaches cc on cc.customer_id = c.id
left join public.employees e on e.id = cc.coach_id
where public.is_staff()
group by c.id, c.name, c.nickname, c.phone, c.client_code, c.is_active;

grant select on public.staff_clients_coach to authenticated;

comment on view public.staff_clients_coach is
  '每位客人歸屬哪幾位教練（coach_ids 是陣列）＋ 餘額 ＋ 最後一次上課。'
  '「我的學員」＝ 前端用自己的 employee id 去比對 coach_ids。';


-- ── 改歸屬 ─────────────────────────────────────────────────────
-- ☢️ 傳的是【改完之後應該有哪幾位】，不是「加一位」或「減一位」。
--    加減式的 API 在畫面重按兩次時會做出「加了兩次」這種結果；
--    整組覆蓋不會 —— 送兩次一樣的東西，第二次什麼都不會發生。
create or replace function public.set_customer_coaches(
  p_customer uuid,
  p_coaches  uuid[],
  p_why      text default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_name text; v_me uuid; v_why text;
  v_old uuid[]; v_add uuid[]; v_del uuid[]; c uuid;
begin
  if not public.is_finance() then
    raise exception '只有負責人和財務可以改教練歸屬';
  end if;

  select name into v_name from public.customers where id = p_customer;
  if v_name is null then
    return jsonb_build_object('ok', false, 'why', 'not_found', 'msg', '找不到這位客人');
  end if;

  p_coaches := coalesce(p_coaches, '{}');
  -- ☢️ 去重：同一位傳兩次不該變成兩列（主鍵會擋，但錯誤訊息很難懂）
  select coalesce(array_agg(distinct x), '{}') into p_coaches from unnest(p_coaches) x;

  if array_length(p_coaches, 1) > 3 then
    return jsonb_build_object('ok', false, 'why', 'too_many',
      'msg', '一位客人最多掛三位教練 —— 再多就不是「歸屬」了');
  end if;

  -- 每一位都要是還在職、而且會教課的
  foreach c in array p_coaches loop
    if not exists (select 1 from public.employees
                    where id = c and is_active and can_teach) then
      return jsonb_build_object('ok', false, 'why', 'bad_coach',
        'msg', '名單裡有不是在職教練的人');
    end if;
  end loop;

  select coalesce(array_agg(coach_id), '{}') into v_old
    from public.customer_coaches where customer_id = p_customer;

  select coalesce(array_agg(x), '{}') into v_add
    from unnest(p_coaches) x where x <> all (v_old);
  select coalesce(array_agg(x), '{}') into v_del
    from unnest(v_old) x where x <> all (p_coaches);

  if array_length(v_add,1) is null and array_length(v_del,1) is null then
    return jsonb_build_object('ok', true, 'changed', false, 'name', v_name,
      'msg', '沒有變動');
  end if;

  -- ☢️ 真的有換人的時候要寫原因。第一次建立（原本沒有）不強迫，
  --    因為那是匯入，不是「換教練」。
  v_why := btrim(coalesce(p_why, ''));
  if array_length(v_old,1) is not null and char_length(v_why) < 2 then
    return jsonb_build_object('ok', false, 'why', 'no_reason',
      'msg', '換教練要寫原因 —— 三個月後要查得出為什麼換');
  end if;

  v_me := public.my_employee_id();

  delete from public.customer_coaches
   where customer_id = p_customer and coach_id = any (v_del);
  insert into public.customer_coaches (customer_id, coach_id, created_by)
  select p_customer, x, v_me from unnest(v_add) x;

  insert into public.customer_coach_log (customer_id, coach_id, action, why, changed_by)
  select p_customer, x, 'remove', nullif(v_why,''), v_me from unnest(v_del) x
  union all
  select p_customer, x, 'add',    nullif(v_why,''), v_me from unnest(v_add) x;

  return jsonb_build_object('ok', true, 'changed', true, 'name', v_name,
    'added', coalesce(array_length(v_add,1),0),
    'removed', coalesce(array_length(v_del,1),0),
    'now', coalesce((select string_agg(e.display_name, '、' order by e.display_name)
                       from public.customer_coaches cc
                       join public.employees e on e.id = cc.coach_id
                      where cc.customer_id = p_customer), '（沒有歸屬）'));
end $fn$;

revoke all on function public.set_customer_coaches(uuid, uuid[], text) from public, anon;
grant execute on function public.set_customer_coaches(uuid, uuid[], text) to authenticated;

comment on function public.set_customer_coaches(uuid, uuid[], text) is
  '設定一位客人的歸屬教練。傳【改完之後應該有哪幾位】，不是加一位減一位 ——'
  '整組覆蓋才不會因為重按兩次而做出重複的結果。財務限定，換人要寫原因。';


-- ── 匯入用：一次設定很多位（第一次從名單匯進來時用）───────────
-- ☢️ 先驗全部、全對才寫（跟第 86 步匯入同一個原則）。
--    p_rows：[{"client_code":"C0001","coaches":["Peter"]}, …]
create or replace function public.import_customer_coaches(
  p_rows    jsonb,
  p_dry_run boolean default true
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_i int; x jsonb; v_code text; v_cust uuid; v_me uuid;
  v_names text[]; v_ids uuid[]; nm text; v_cid uuid;
  v_err text[] := '{}'; v_n int := 0; v_pairs int := 0;
begin
  if not public.is_finance() then raise exception '只有負責人和財務可以匯入歸屬'; end if;
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    return jsonb_build_object('ok', false, 'msg', 'p_rows 要是陣列');
  end if;

  for v_i in 0 .. jsonb_array_length(p_rows) - 1 loop
    x := p_rows -> v_i;
    v_code := btrim(coalesce(x ->> 'client_code',''));
    select id into v_cust from public.customers where client_code = v_code;
    if v_cust is null then
      v_err := v_err || format('第 %s 列：找不到客戶編號 %s', v_i+1, v_code);
      continue;
    end if;
    select coalesce(array_agg(y #>> '{}'), '{}') into v_names
      from jsonb_array_elements(x -> 'coaches') y;
    if array_length(v_names,1) is null then
      v_err := v_err || format('第 %s 列（%s）：沒有教練', v_i+1, v_code);
      continue;
    end if;
    foreach nm in array v_names loop
      select id into v_cid from public.employees
       where display_name = btrim(nm) and is_active and can_teach;
      if v_cid is null then
        v_err := v_err || format('第 %s 列（%s）：查不到在職教練「%s」', v_i+1, v_code, nm);
      end if;
    end loop;
    v_n := v_n + 1;
    v_pairs := v_pairs + array_length(v_names,1);
  end loop;

  if array_length(v_err,1) is not null then
    return jsonb_build_object('ok', false, 'n_errors', array_length(v_err,1),
      'errors', to_jsonb(v_err));
  end if;
  if p_dry_run then
    return jsonb_build_object('ok', true, 'dry_run', true,
      'n_customers', v_n, 'n_pairs', v_pairs, 'msg', '預演通過，一列都沒寫');
  end if;

  v_me := public.my_employee_id();
  for v_i in 0 .. jsonb_array_length(p_rows) - 1 loop
    x := p_rows -> v_i;
    select id into v_cust from public.customers
     where client_code = btrim(x ->> 'client_code');
    select coalesce(array_agg(e.id), '{}') into v_ids
      from jsonb_array_elements(x -> 'coaches') y
      join public.employees e on e.display_name = btrim(y #>> '{}')
     where e.is_active and e.can_teach;
    delete from public.customer_coaches where customer_id = v_cust;
    insert into public.customer_coaches (customer_id, coach_id, created_by)
    select v_cust, u, v_me from unnest(v_ids) u;
    insert into public.customer_coach_log (customer_id, coach_id, action, why, changed_by)
    select v_cust, u, 'add', '從 Active Client List 匯入', v_me from unnest(v_ids) u;
  end loop;

  return jsonb_build_object('ok', true, 'dry_run', false,
    'n_customers', v_n, 'n_pairs', v_pairs);
end $fn$;

revoke all on function public.import_customer_coaches(jsonb, boolean) from public, anon;
grant execute on function public.import_customer_coaches(jsonb, boolean) to authenticated;
