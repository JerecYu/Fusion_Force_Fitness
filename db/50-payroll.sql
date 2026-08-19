-- 50｜薪資計算
--
-- 規則文件第六篇 1：
--   教練當月薪資 ＝ PT＋PGT 累計業績抽成（含 PT／PGT 外派及企業包班）
--                  ＋ GT 鐘點費
--                  ＋ 諧動外派活動鐘點費
--                  ＋ 固定加給
--
-- 這一支把四條線各自算清楚，再加起來。四條線的規則完全不同，混在一起算是這
-- 份規則文件最禁止的事（第五篇「防重規定」：同一筆服務不得同時列為抽成業績
-- 與鐘點費）。
--
-- ☢️ 這個 repo 是公開的。職級名單與加給金額不寫在這個檔案裡 ——
--    只建表，值由財務在後台輸入，只存在資料庫。

begin;

-- ═══════════════════════════════════════════════════════════════
-- 1）職級 —— 決定 80,000 以內抽 45% 還是 40%
-- ═══════════════════════════════════════════════════════════════
-- 規則第五篇 2：「職級以工作室正式核定與公告為準；未正式核定為主管者，適用
-- 一般教練比例。」→ 查不到資料就是一般教練，這是規則，不是預設值湊數。
-- 「職級於月中生效或停止時，以生效日前後的實際業績分段套用相應比例。」
-- → 所以存的是異動史（從哪一天開始），逐筆用完成日去查，不是每人一個欄位。

create table if not exists public.coach_grades (
  id             uuid primary key default gen_random_uuid(),
  employee_id    uuid not null references public.employees(id) on delete cascade,
  grade          text not null check (grade in ('supervisor','regular')),
  effective_from date not null,
  note           text,
  created_at     timestamptz not null default now(),
  created_by     uuid references public.employees(id),
  unique (employee_id, effective_from)
);

comment on table public.coach_grades is
  '教練職級異動史。supervisor＝主管階層教練（80,000 以內 45%），regular＝一般教練（40%）。查不到＝一般教練。';

create index if not exists coach_grades_lookup
  on public.coach_grades (employee_id, effective_from desc);

create or replace function public.coach_grade_on(p_emp uuid, p_on date)
returns text
language sql
stable
security definer
set search_path to 'public'
as $$
  select coalesce(
    (select g.grade from public.coach_grades g
      where g.employee_id = p_emp and g.effective_from <= p_on
      order by g.effective_from desc limit 1),
    'regular');
$$;

-- ═══════════════════════════════════════════════════════════════
-- 2）固定加給 —— 不是課程業績，不影響抽成級距
-- ═══════════════════════════════════════════════════════════════
-- 規則第五篇 5：「月中開始或停止擔任者，當月加給＝月加給 × 實際在任日曆天數
-- ÷ 當月日曆天數；起訖日均列入實際在任日曆天數。」

create table if not exists public.coach_allowances (
  id             uuid primary key default gen_random_uuid(),
  employee_id    uuid not null references public.employees(id) on delete cascade,
  item           text not null,
  monthly_amount integer not null check (monthly_amount > 0),
  from_date      date not null,
  to_date        date,
  note           text,
  created_at     timestamptz not null default now(),
  created_by     uuid references public.employees(id),
  check (to_date is null or to_date >= from_date)
);

comment on table public.coach_allowances is
  '職務加給。to_date 留白＝仍在任。☢️ 金額只存在資料庫，不進版控。';

create index if not exists coach_allowances_lookup
  on public.coach_allowances (employee_id, from_date);

-- ═══════════════════════════════════════════════════════════════
-- 3）每一筆薪資明細
-- ═══════════════════════════════════════════════════════════════
-- ☢️ amount 一律保留原始精度（numeric），不逐筆取整。
--    規則第六篇 1：「每筆計算保留原始精度…不得逐筆取整。」
--
-- qty 這一欄每一類意思不同：
--    perf      → 空的
--    gt        → 當堂實際到場並完成簽到的人數
--    event     → 空的
--    allowance → 當月實際在任日曆天數

drop function if exists public.payroll_lines(date);

create function public.payroll_lines(p_month date)
returns table (
  coach_id   uuid,
  coach_name text,
  kind       text,      -- perf｜gt｜event｜allowance
  done_at    timestamptz,
  ref_id     uuid,
  label      text,
  qty        integer,
  base       numeric,   -- 業績金額／到場人數／計費時數／月加給
  rate       numeric,   -- 抽成率／時薪；GT 與加給沒有
  amount     numeric,
  hold       boolean,   -- true＝暫停自動計薪，要人工核定
  hold_why   text
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  m_from date    := date_trunc('month', p_month)::date;
  m_to   date    := (date_trunc('month', p_month) + interval '1 month - 1 day')::date;
  m_days integer := (date_trunc('month', p_month) + interval '1 month - 1 day')::date
                  - date_trunc('month', p_month)::date + 1;
begin
  if not public.is_finance() then
    raise exception '薪資明細只有負責人和財務看得到';
  end if;

  return query
  -- ── ① PT／PGT／外派／企業包班：抽成業績（累進，逐筆排序）──────
  with perf as (
    select sc.coach_id as cid,
           s.id        as rid,
           s.done_at   as dat,
           s.service_type as styp,
           coalesce(s.perf_final, s.perf_amount, 0)::numeric as amt
    from public.service_records s
    join public.service_coaches sc on sc.service_id = s.id
    where not s.voided
      and s.fin_status = 'final'
      and s.service_type in ('PT','PGT','PT_OUT','PGT_OUT','CORP')
      and (s.done_at at time zone 'Asia/Taipei')::date between m_from and m_to
  ),
  perf_run as (
    -- 規則第五篇 2：「依完成日期與時間逐筆累加當月 PT＋PGT 業績。」
    select p.*,
           coalesce(sum(p.amt) over (
             partition by p.cid
             order by p.dat, p.rid
             rows between unbounded preceding and 1 preceding), 0) as run_before
    from perf p
  ),
  perf_split as (
    select r.*,
           greatest(0, least(80000 - r.run_before, r.amt))          as low,
           r.amt - greatest(0, least(80000 - r.run_before, r.amt))  as high,
           case when public.coach_grade_on(
                       r.cid, (r.dat at time zone 'Asia/Taipei')::date) = 'supervisor'
                then 0.45 else 0.40 end                             as rate_low
    from perf_run r
  )
  select x.cid, e.display_name, 'perf'::text, x.dat, x.rid,
         case x.styp
           when 'PT'      then 'PT'
           when 'PGT'     then 'PGT'
           when 'PT_OUT'  then 'PT 外派'
           when 'PGT_OUT' then 'PGT 外派'
           else                '企業包班' end,
         null::integer,
         x.amt,
         x.rate_low,
         x.low * x.rate_low + x.high * 0.50,
         false,
         null::text
  from perf_split x
  join public.employees e on e.id = x.cid

  union all

  -- ── ② GT：鐘點費，只看每堂實際到場並完成簽到的人數 ──────────
  -- 規則第五篇 3：無學員實際到場不計；13 人以上是資料異常，不得套 12 人封頂。
  select g.coach_id,
         coalesce(e.display_name, '（未指定教練）'),
         'gt'::text,
         (g.session_date + g.start_time) at time zone 'Asia/Taipei',
         g.session_id,
         coalesce(g.title, 'GT'),
         g.n_present,
         g.n_present::numeric,
         null::numeric,
         case when g.n_present >= 13 then 0::numeric
              else public.gt_payout(g.n_present)::numeric end,
         (g.n_present >= 13 or g.coach_id is null),
         case when g.coach_id is null
                then '這堂課沒有指定授課教練 —— 規則第六篇 6：實際授課教練待確認，暫不自動計薪'
              when g.n_present >= 13
                then '到場 ' || g.n_present || ' 人超過商品上限 12 人 —— 規則第五篇 3：'
                     || '不得套用 12 人級距封頂，暫停自動計薪'
              end
  from (
    select s.id as session_id, s.coach_id, s.session_date, s.start_time, s.title,
           coalesce(sum(b.attendee_count) filter (where b.status = 'attended'), 0)::int
             as n_present
    from public.class_sessions s
    left join public.bookings b on b.session_id = s.id
    where s.product = 'GT'
      and s.session_date between m_from and m_to
    group by s.id
  ) g
  left join public.employees e on e.id = g.coach_id
  where g.n_present > 0

  union all

  -- ── ③ 諧動外派活動：每位教練 計費時數 × 600 ─────────────────
  -- 規則第五篇 4：多人派送時每位按相同計費時數分別計算。
  select sc.coach_id, e.display_name, 'event'::text, s.done_at, s.id,
         '諧動外派活動',
         null::integer,
         s.billed_hours,
         600::numeric,
         s.billed_hours * 600,
         false,
         null::text
  from public.service_records s
  join public.service_coaches sc on sc.service_id = s.id
  join public.employees e on e.id = sc.coach_id
  where not s.voided
    and s.fin_status = 'final'
    and s.service_type = 'EVENT'
    and (s.done_at at time zone 'Asia/Taipei')::date between m_from and m_to

  union all

  -- ── ④ 固定加給：按實際在任日曆天數比例，起訖日都算 ───────────
  select a.employee_id, e.display_name, 'allowance'::text,
         (m_to + time '23:59:59') at time zone 'Asia/Taipei',
         a.id,
         a.item,
         (least(coalesce(a.to_date, m_to), m_to) - greatest(a.from_date, m_from) + 1)::integer,
         a.monthly_amount::numeric,
         null::numeric,
         a.monthly_amount::numeric
           * (least(coalesce(a.to_date, m_to), m_to) - greatest(a.from_date, m_from) + 1)
           / m_days,
         false,
         null::text
  from public.coach_allowances a
  join public.employees e on e.id = a.employee_id
  where a.from_date <= m_to
    and coalesce(a.to_date, m_to) >= m_from;
end $$;

-- ═══════════════════════════════════════════════════════════════
-- 4）月結：四個小計各自四捨五入，再相加
-- ═══════════════════════════════════════════════════════════════
create or replace function public.payroll_month(p_month date)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  m_from date := date_trunc('month', p_month)::date;
  m_to   date := (date_trunc('month', p_month) + interval '1 month - 1 day')::date;
  v_out  jsonb;
begin
  if not public.is_finance() then
    raise exception '薪資報表只有負責人和財務看得到';
  end if;

  -- ☢️ materialized：payroll_lines 只跑一次。不寫的話 PG 可能把它展開成三次，
  --    同一份資料算三遍。
  with pl as materialized (
    select * from public.payroll_lines(p_month)
  ),
  -- ☢️ 取整只在這裡發生，而且是「每一類小計各自四捨五入」。
  --    規則第六篇 1：不得逐筆取整。
  sums as (
    select coach_name,
           round(coalesce(sum(amount) filter (where kind='perf'      and not hold), 0))::int as perf,
           round(coalesce(sum(amount) filter (where kind='gt'        and not hold), 0))::int as gt,
           round(coalesce(sum(amount) filter (where kind='event'     and not hold), 0))::int as event,
           round(coalesce(sum(amount) filter (where kind='allowance' and not hold), 0))::int as allowance,
           coalesce(sum(base)   filter (where kind='perf'  and not hold), 0)::int as perf_base,
           count(*)             filter (where kind='gt'    and not hold)::int     as gt_classes,
           coalesce(sum(qty)    filter (where kind='gt'    and not hold), 0)::int as gt_heads,
           coalesce(sum(base)   filter (where kind='event' and not hold), 0)      as event_hours,
           count(*)             filter (where hold)::int                          as hold_n
    from pl group by coach_name
  ),
  rows as (
    select coach_name, perf, gt, event, allowance,
           perf + gt + event + allowance as total,
           perf_base, gt_classes, gt_heads, event_hours, hold_n
    from sums
  ),
  lines as (
    select coach_name, kind, done_at, label, qty, base, rate,
           round(amount, 4) as amount, hold, hold_why
    from pl
  ),
  holds as (
    select coach_name, done_at, label, hold_why from pl where hold
    union all
    -- 規則第六篇 6：財務認列狀態還是「待確認」的，暫不自動計薪
    select coalesce(e.display_name, '（未指定教練）'), s.done_at,
           s.service_type || '｜還沒財務最終認列',
           '規則第六篇 6：財務認列狀態是「待確認」，暫不自動計薪'
    from public.service_records s
    left join public.service_coaches sc on sc.service_id = s.id
    left join public.employees e on e.id = sc.coach_id
    where not s.voided and s.fin_status is distinct from 'final'
      and (s.done_at at time zone 'Asia/Taipei')::date between m_from and m_to
  ),
  -- 到場但沒扣堂數：可能是體驗／免費／贈課／補課（規則第五篇 3 說要算人頭），
  -- 也可能是點名點錯。系統分不出來，所以列出來給人看，不擋。
  warns as (
    select coalesce(e.display_name, '（未指定教練）') as coach_name,
           (s.session_date + s.start_time) at time zone 'Asia/Taipei' as done_at,
           coalesce(s.title, 'GT') as label,
           public.mask_name(c.name) as who,
           '這一位算進鐘點費人數，但帳本上沒有扣堂 —— 體驗／免費／贈課是正常的，點錯就要改' as why
    from public.bookings b
    join public.class_sessions s on s.id = b.session_id
    join public.customers c on c.id = b.customer_id
    left join public.employees e on e.id = s.coach_id
    where b.status = 'attended'
      and s.product = 'GT'
      and s.session_date between m_from and m_to
      and not exists (select 1 from public.credit_ledger l where l.booking_id = b.id)
  )
  select jsonb_build_object(
    'ok',           true,
    'month',        to_char(m_from, 'YYYY-MM'),
    'from',         m_from,
    'to',           m_to,
    'made_at',      to_char(now() at time zone 'Asia/Taipei', 'YYYY-MM-DD HH24:MI'),
    'rule_version', '2026-08-19',
    'rows',   coalesce((select jsonb_agg(to_jsonb(r) order by r.total desc) from rows  r), '[]'::jsonb),
    'lines',  coalesce((select jsonb_agg(to_jsonb(l) order by l.done_at, l.coach_name) from lines l), '[]'::jsonb),
    'holds',  coalesce((select jsonb_agg(to_jsonb(h) order by h.done_at) from holds h), '[]'::jsonb),
    'warns',  coalesce((select jsonb_agg(to_jsonb(w) order by w.done_at) from warns w), '[]'::jsonb))
  into v_out;

  return v_out;
end $$;

-- ═══════════════════════════════════════════════════════════════
-- 5）權限
-- ═══════════════════════════════════════════════════════════════
alter table public.coach_grades     enable row level security;
alter table public.coach_allowances enable row level security;

drop policy if exists coach_grades_fin     on public.coach_grades;
drop policy if exists coach_allowances_fin on public.coach_allowances;

create policy coach_grades_fin on public.coach_grades
  for all to authenticated
  using (public.is_finance()) with check (public.is_finance());

create policy coach_allowances_fin on public.coach_allowances
  for all to authenticated
  using (public.is_finance()) with check (public.is_finance());

grant select, insert, update, delete on public.coach_grades     to authenticated;
grant select, insert, update, delete on public.coach_allowances to authenticated;

grant execute on function public.coach_grade_on(uuid, date) to authenticated;
grant execute on function public.payroll_lines(date)        to authenticated;
grant execute on function public.payroll_month(date)        to authenticated;

commit;

-- ── 驗收 ────────────────────────────────────────────────────
-- select jsonb_pretty(public.payroll_month('2026-08-01'));
--
--   · rows  每一位教練四個小計 ＋ total
--   · lines 每一筆明細，amount 保留 4 位小數（沒有逐筆取整）
--   · holds 所有暫停自動計薪的項目
--   · warns 到場但沒扣堂數的人（體驗／免費／贈課是正常的，點錯就要改）
--
-- ☢️ 加給金額與職級名單不在這個檔案裡。要設定：
--    insert into public.coach_allowances (employee_id, item, monthly_amount, from_date)
--    insert into public.coach_grades     (employee_id, grade, effective_from)
