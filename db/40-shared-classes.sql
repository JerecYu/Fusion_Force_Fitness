-- ============================================================
-- 40 · 分享課程：＋2 的上限，以及「被分享的是誰」
--
-- 規則（《財務與教練薪資整合規則》2026-08-19 正式版）：
--   團體課買 10 送 2，一組 12 堂。那多送的 2 堂【可以給別人上】，
--   但一組就是 2 次，不能無限外流 —— 不然 10 送 2 的折扣會流到
--   從來沒買過課的人身上。
--
-- Jerec 2026-08-19 的兩個決定：
--   ① 舊的堂數怎麼算額度 → 選 B：【每 12 堂就給 2 次】，不分新舊。
--      理由：有些學員因工作停很久但還有很多餘課，把原本的權益拿掉會反感；
--      真的會鑽漏洞的只有家庭成員，狀況極少。
--   ② 被分享人可以【不留姓名手機】，只留線索（跟分享人的關係）。
--
-- ☢️ 這一步【不動任何一筆錢】。扣堂數的規則完全沒改
--    （還是 check_in 依 attendee_count 扣，扣在 paid_by_customer_id 身上）。
--    這裡只是把「這幾個人裡面有幾個不是本人」記下來，並且擋住超額。
-- ============================================================

-- ── ① 本人這堂有沒有上 ──────────────────────────────────────
-- ☢️ 為什麼需要這一欄：attendee_count 是【現場實際幾個人】，
--    它分不出「本人＋1 位朋友」和「兩個兒子來、媽媽沒來」——
--    前者用掉 1 次分享額度，後者用掉 2 次。差別就在本人算不算在裡面。
alter table public.bookings
  add column if not exists owner_present boolean not null default true;

comment on column public.bookings.owner_present is
  '這一筆的「本人」（付堂數的那個人）有沒有親自上這堂。false＝只有帶來的人上。';

-- ── ② 被分享人 ──────────────────────────────────────────────
-- ☢️ 姓名、電話都可以是空的。Jerec 明確要求：只留線索也可以。
--    所以這張表【不是客人名單】，不要拿它當客人用。
create table if not exists public.shared_attendees (
  id          uuid primary key default gen_random_uuid(),
  booking_id  uuid not null references public.bookings(id) on delete cascade,
  seq         smallint not null check (seq >= 1 and seq <= 5),
  label       text,       -- 線索：大兒子、小兒子、同事、朋友…（可空白）
  name        text,       -- 有留才填
  phone       text,       -- 有留才填
  customer_id uuid references public.customers(id) on delete set null,  -- 以後變成正式客人再接上
  created_at  timestamptz not null default now(),
  created_by  uuid references public.employees(id),
  unique (booking_id, seq)
);

comment on table public.shared_attendees is
  '被分享人。姓名手機可以全空，只留線索。☢️ 這不是客人名單。';

alter table public.shared_attendees enable row level security;

drop policy if exists "職員看得到被分享人" on public.shared_attendees;
create policy "職員看得到被分享人" on public.shared_attendees
  for select using (public.is_staff());
-- ☢️ 沒有 insert／update／delete 的 policy —— 寫入一律走下面的 RPC。
--    「動到規則的入口只有一個」，跟第 39 步同一個原則。

grant select on public.shared_attendees to authenticated;

create index if not exists shared_attendees_booking on public.shared_attendees (booking_id);

-- ── ③ 額度：有幾次可以分享、已經用掉幾次 ────────────────────
-- ☢️ 算在【付堂數的人】身上（paid_by_customer_id），不是報名的人。
--    因為被稀釋的是他的 10 送 2。
create or replace function public.gt_share_quota(p_customer uuid)
returns integer
language sql stable security definer set search_path = public as $$
  -- 每【拿到】12 堂就給 2 次。不分是買的、送的、還是搬遷進來的舊餘額 ——
  -- 這是 Jerec 選的 B 案。
  select (floor(coalesce(sum(delta), 0) / 12.0) * 2)::integer
  from public.credit_ledger
  where customer_id = p_customer and product = 'GT' and delta > 0;
$$;

comment on function public.gt_share_quota(uuid) is
  '這個人一輩子可以分享幾堂＝floor(累計拿到的堂數 / 12) × 2。';

-- ☢️ 用掉幾次要從 attendee_count 算，【不能】數 shared_attendees 的筆數 ——
--    線索是選填的，教練沒填的話筆數會是 0，額度就會被少算。
--    扣堂數看的是 attendee_count，額度也要看同一個數字，兩邊才不會對不起來。
create or replace function public.gt_share_used(p_customer uuid)
returns integer
language sql stable security definer set search_path = public as $$
  select coalesce(sum(
           greatest(b.attendee_count - (case when b.owner_present then 1 else 0 end), 0)
         ), 0)::integer
  from public.bookings b
  join public.class_sessions s on s.id = b.session_id
  where coalesce(b.paid_by_customer_id, b.customer_id) = p_customer
    and s.product = 'GT'
    and b.status in ('booked', 'attended');
$$;

comment on function public.gt_share_used(uuid) is
  '已經分享出去幾堂。缺席與取消不算（那兩種也不扣堂數）。';

revoke all on function public.gt_share_quota(uuid) from public;
revoke all on function public.gt_share_used(uuid)  from public;
grant execute on function public.gt_share_quota(uuid) to authenticated;
grant execute on function public.gt_share_used(uuid)  to authenticated;

-- ── ④ 改人數：順便擋超額 ────────────────────────────────────
-- ☢️ 換簽名了（多一個 p_owner_present），所以要先 drop。
--    不留舊版相容層 —— 兩個都在的話 PostgREST 有機會挑錯那一個。
drop function if exists public.set_attendees(uuid, smallint);

create or replace function public.set_attendees(
  p_booking uuid, p_n smallint, p_owner_present boolean default true)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_b       record;
  v_payer   uuid;
  v_old     integer;
  v_new     integer;
  v_quota   integer;
  v_used    integer;
  v_others  integer;
  v_left    integer;
  v_max_n   integer;
begin
  if not public.is_staff() then
    raise exception '只有教練可以改人數';
  end if;
  if p_n is null or p_n < 1 or p_n > 6 then
    raise exception '這一筆的人數只能是 1 到 6';
  end if;

  select b.id, b.status, b.attendee_count, b.owner_present,
         coalesce(b.paid_by_customer_id, b.customer_id) as payer,
         (s.session_date + s.start_time) at time zone 'Asia/Taipei' as starts
    into v_b
  from public.bookings b
  join public.class_sessions s on s.id = b.session_id
  where b.id = p_booking and s.product = 'GT';

  if not found then raise exception '找不到這筆預約'; end if;
  v_payer := v_b.payer;

  if v_b.starts < now() - interval '7 days' then
    raise exception '這堂課超過 7 天了，請找 Jerec 在後台處理';
  end if;

  v_old := greatest(v_b.attendee_count - (case when v_b.owner_present then 1 else 0 end), 0);
  v_new := greatest(p_n              - (case when p_owner_present   then 1 else 0 end), 0);

  -- ☢️ 只有在【變多】的時候才檢查額度。
  --    舊資料可能本來就超額（第 40 步之前沒有這條規則），
  --    如果連「不變」和「變少」都擋，教練會連改回去都做不到。
  if v_new > v_old then
    v_quota  := public.gt_share_quota(v_payer);
    v_used   := public.gt_share_used(v_payer);
    -- ☢️ gt_share_used 包含【這一筆自己】，所以要先扣掉，
    --    不然算出來的「別人用掉多少」會多算一次自己。
    v_others := greatest(v_used - v_old, 0);
    v_left   := v_quota - v_others;
    if v_new > v_left then
      v_max_n := greatest(v_left, 0) + (case when p_owner_present then 1 else 0 end);
      return jsonb_build_object(
        'ok', false, 'why', 'share_over',
        'quota', v_quota, 'used_elsewhere', v_others, 'left', greatest(v_left, 0),
        'want', v_new, 'max_n', v_max_n,
        -- ☢️ 錯誤訊息要講【現在該怎麼辦】，不是只講哪裡錯。
        --    櫃檯站著一個客人的時候，「最多只能填 2 人」比「額度不足」有用。
        'msg', '分享額度不夠。每 12 堂只能分享 2 堂 —— 這個人的額度是 ' || v_quota
               || ' 堂，其他預約已經用掉 ' || v_others || ' 堂，還剩 ' || greatest(v_left, 0) || ' 堂。'
               || case when v_max_n >= 1
                       then '這一筆最多只能填 ' || v_max_n || ' 人。'
                       else '本人沒上的話至少要 1 位，但額度已經用完了。' end);
    end if;
  end if;

  update public.bookings
     set attendee_count = p_n, owner_present = p_owner_present
   where id = p_booking;

  -- 人數變少的話，多出來的線索要跟著刪掉，不然會留下對不上的紀錄
  delete from public.shared_attendees where booking_id = p_booking and seq > v_new;

  if v_b.status in ('attended', 'absent') then
    perform public.check_in(p_booking, v_b.status = 'attended');
  end if;

  return jsonb_build_object('ok', true, 'n', p_n, 'owner_present', p_owner_present,
                            'shares', v_new);
end $$;

revoke all on function public.set_attendees(uuid, smallint, boolean) from public;
grant execute on function public.set_attendees(uuid, smallint, boolean) to authenticated;

-- ── ⑤ 填線索 ────────────────────────────────────────────────
-- p_labels 是一個字串陣列，第 1 個就是第 1 位被分享人的線索。
-- 空字串＝這一位不留線索（不是錯誤）。
create or replace function public.set_share_labels(p_booking uuid, p_labels text[])
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_b     record;
  v_share integer;
  v_i     integer;
  v_txt   text;
begin
  if not public.is_staff() then
    raise exception '只有教練可以填被分享人';
  end if;

  select b.attendee_count, b.owner_present,
         (s.session_date + s.start_time) at time zone 'Asia/Taipei' as starts
    into v_b
  from public.bookings b
  join public.class_sessions s on s.id = b.session_id
  where b.id = p_booking and s.product = 'GT';

  if not found then raise exception '找不到這筆預約'; end if;
  if v_b.starts < now() - interval '7 days' then
    raise exception '這堂課超過 7 天了，請找 Jerec 在後台處理';
  end if;

  v_share := greatest(v_b.attendee_count - (case when v_b.owner_present then 1 else 0 end), 0);

  for v_i in 1 .. v_share loop
    v_txt := nullif(btrim(coalesce(p_labels[v_i], '')), '');
    insert into public.shared_attendees (booking_id, seq, label, created_by)
    values (p_booking, v_i::smallint, v_txt, public.my_employee_id())
    on conflict (booking_id, seq) do update set label = excluded.label;
  end loop;

  delete from public.shared_attendees where booking_id = p_booking and seq > v_share;

  return jsonb_build_object('ok', true, 'saved', v_share);
end $$;

revoke all on function public.set_share_labels(uuid, text[]) from public;
grant execute on function public.set_share_labels(uuid, text[]) to authenticated;

-- ── ⑥ 點名名單要看得到額度 ──────────────────────────────────
-- ☢️☢️ drop view 會把 GRANT 一起帶走（第 66 步的教訓）。
--       下面一定要重新 grant，而且要用 set local role authenticated 驗過。
drop view if exists public.staff_roster;
create view public.staff_roster as
select b.id                                   as booking_id,
       b.session_id,
       b.status                               as booking_status,
       b.checked_at,
       ck.display_name                        as checked_by_name,
       c.id                                   as customer_id,
       c.name                                 as customer_name,
       right(c.phone, 3)                      as phone_tail,
       b.paid_by_customer_id,
       payer.name                             as payer_name,
       coalesce(bal.balance, 0)               as balance,
       b.attendee_count,
       b.owner_present,
       public.gt_share_quota(coalesce(b.paid_by_customer_id, b.customer_id)) as share_quota,
       public.gt_share_used (coalesce(b.paid_by_customer_id, b.customer_id)) as share_used,
       coalesce(sh.labels, '[]'::jsonb)       as share_labels,
       b.confirmed_at,
       b.confirmed_by
from public.bookings b
join public.class_sessions s on s.id = b.session_id
join public.customers c on c.id = b.customer_id
left join public.customers payer on payer.id = b.paid_by_customer_id
left join public.employees ck on ck.id = b.checked_by
left join lateral (
  select sum(l.delta)::integer as balance
  from public.credit_ledger l
  where l.customer_id = b.paid_by_customer_id and l.product = 'GT') bal on true
left join lateral (
  select jsonb_agg(jsonb_build_object('seq', sa.seq, 'label', sa.label) order by sa.seq) as labels
  from public.shared_attendees sa where sa.booking_id = b.id) sh on true
where public.is_staff()
  and s.product = 'GT'
  and s.session_date >= ((now() at time zone 'Asia/Taipei')::date - 7)
  and s.session_date <= ((now() at time zone 'Asia/Taipei')::date + 1);

comment on view public.staff_roster is '點名名單。☢️ definer，不要加 security_invoker。';
grant select on public.staff_roster to authenticated;

-- ── ⑦ 分享紀錄（給對帳報表用）────────────────────────────────
create or replace view public.staff_share_log as
select s.session_date,
       s.start_time,
       s.title,
       b.id                          as booking_id,
       coalesce(payer.name, c.name)  as payer_name,
       right(coalesce(payer.phone, c.phone), 3) as phone_tail,
       b.attendee_count,
       b.owner_present,
       greatest(b.attendee_count - (case when b.owner_present then 1 else 0 end), 0) as shares,
       coalesce((select string_agg(coalesce(nullif(sa.label,''), '未具名 ' || sa.seq), '、' order by sa.seq)
                 from public.shared_attendees sa where sa.booking_id = b.id), '') as who,
       b.status
from public.bookings b
join public.class_sessions s on s.id = b.session_id
join public.customers c on c.id = b.customer_id
left join public.customers payer on payer.id = b.paid_by_customer_id
where public.is_staff()
  and s.product = 'GT'
  and b.status in ('booked', 'attended')
  and b.attendee_count - (case when b.owner_present then 1 else 0 end) > 0;

comment on view public.staff_share_log is '分享課程紀錄：誰把堂數分給誰、用掉幾堂。';
grant select on public.staff_share_log to authenticated;

-- ── ⑧ 補回已經發生的三筆 ────────────────────────────────────
-- 目前 attendee_count > 1 的只有三筆，全部是 2 人。
-- 其中 8/19 12:20 那筆是吳佳芳幫兩個兒子報名、【她自己沒上】——
-- 這是 Jerec 親口說的，所以 owner_present 設 false，兩位都算分享。
update public.bookings b
   set owner_present = false
 where b.attendee_count = 2
   and exists (select 1 from public.class_sessions s
                where s.id = b.session_id
                  and s.session_date = date '2026-08-19'
                  and s.start_time = time '12:20');

-- 另外兩筆（8/06、8/11）當時的實際情形沒有紀錄，維持「本人有上 ＋ 1 位」。
-- 線索一律先留空，教練之後在點名頁補得回來。
insert into public.shared_attendees (booking_id, seq, label)
select b.id, gs.seq::smallint, null
from public.bookings b
join public.class_sessions s on s.id = b.session_id
cross join lateral generate_series(
  1, greatest(b.attendee_count - (case when b.owner_present then 1 else 0 end), 0)) as gs(seq)
where s.product = 'GT' and b.attendee_count > 1
on conflict (booking_id, seq) do nothing;
