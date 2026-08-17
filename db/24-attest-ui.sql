-- ═══════════════════════════════════════════════════════════════
--  24-attest-ui.sql  ·  到課共同確認（第一期 · 畫面要用的兩樣東西）
--  2026-08-17
--
--  第 19 支把資料庫的部分做完了（欄位、憑證表、發碼、驗碼）。
--  這一支只補畫面需要的兩樣：
--    ① staff_roster 要看得到「這個人確認了沒」
--    ② 教練代確認（客人沒手機／沒電／不會掃的時候）
--
--  ☢️ 一樣【完全不碰扣款】。這兩樣都只寫 confirmed_at / confirmed_by。
-- ═══════════════════════════════════════════════════════════════

-- ── ① staff_roster 加兩欄 ─────────────────────────────────────
--    ☢️ 改檢視表之前一定要先 pg_get_viewdef 看一次（第 19 支學到的）。
--       下面是 2026-08-17 抄下來的原定義，【一個欄位都沒改、沒少】，
--       只在最後加兩欄。前端是照欄位名取的，少一欄就少一塊畫面。
create or replace view public.staff_roster
  with (security_invoker = true) as
select b.id                              as booking_id,
       b.session_id,
       b.status                          as booking_status,
       b.checked_at,
       ck.display_name                   as checked_by_name,
       c.id                              as customer_id,
       c.name                            as customer_name,
       right(c.phone, 3)                 as phone_tail,
       b.paid_by_customer_id,
       payer.name                        as payer_name,
       coalesce(bal.balance, 0)          as balance,
       b.guest_count,
       -- ↓↓ 這一版新增的兩欄 ↓↓
       b.confirmed_at,
       b.confirmed_by
from bookings b
join class_sessions s on s.id = b.session_id
join customers c      on c.id = b.customer_id
left join customers payer on payer.id = b.paid_by_customer_id
left join employees ck    on ck.id = b.checked_by
left join lateral ( select sum(l.delta)::integer as balance
                    from credit_ledger l
                    where l.customer_id = b.paid_by_customer_id
                      and l.product = 'GT' ) bal on true
where is_staff()
  and s.product = 'GT'
  and s.session_date >= ((now() at time zone 'Asia/Taipei')::date - 7)
  and s.session_date <= ((now() at time zone 'Asia/Taipei')::date + 1);

-- ── ② 教練代確認 ──────────────────────────────────────────────
--  2026-08-17 Jerec 選了 (A)：客人沒手機／不會掃的時候，教練幫他按一下，
--  記成 confirmed_by = 'staff'。
--
--  ☢️ 為什麼不乾脆留白？
--     因為留白的話，帳上「沒確認」會有兩種完全不同的意思：
--     「客人不肯確認」和「客人沒有手機」。兩件事混在一起，
--     這份紀錄就沒有任何證據價值了。留痕比留白有用。
--
--  ☢️ 但 'staff' 和 'qr' 的可信度【不一樣】，所以分開存。
--     qr  = 客人拿自己的手機掃了教練螢幕上的碼（雙方在場）
--     staff = 教練說他來了（單方）
create or replace function public.confirm_by_staff(p_booking uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_b record; v_start timestamptz;
begin
  if not public.is_staff() then
    raise exception '只有教練可以代確認';
  end if;

  select b.id, b.status, b.confirmed_at, b.confirmed_by,
         s.session_date, s.start_time, s.product, s.status as s_status
    into v_b
  from public.bookings b
  join public.class_sessions s on s.id = b.session_id
  where b.id = p_booking;

  if not found then raise exception '找不到這筆預約'; end if;
  if v_b.product <> 'GT' then raise exception '這不是團體課'; end if;
  if v_b.status = 'cancelled' then raise exception '這個人已經取消報名了'; end if;

  v_start := (v_b.session_date + v_b.start_time) at time zone 'Asia/Taipei';

  -- ☢️ 跟 issue_checkin_token 同一條線：課前 15 分 ～ 課後 2 小時。
  --    三個地方的時窗不能不一樣（2026-08-17 已經因為這個錯過一次）。
  if now() < v_start - interval '15 min' or now() > v_start + interval '2 hour' then
    raise exception '代確認只能在課前 15 分鐘到課後 2 小時之間';
  end if;

  -- ☢️ 已經是客人自己掃的，就【不要】蓋掉。
  --    qr 的可信度比 staff 高，覆蓋等於把證據降級。
  if v_b.confirmed_at is not null then
    return jsonb_build_object('ok', true, 'already', true, 'by', v_b.confirmed_by);
  end if;

  -- ☢️ 這裡【只】寫這兩欄。不碰 status、不碰 attended、不碰 credit_ledger。
  update public.bookings
     set confirmed_at = now(), confirmed_by = 'staff'
   where id = p_booking;

  return jsonb_build_object('ok', true, 'by', 'staff');
end $$;

revoke all on function public.confirm_by_staff(uuid) from public;
grant execute on function public.confirm_by_staff(uuid) to authenticated;
