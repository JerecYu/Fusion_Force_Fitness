-- ═══════════════════════════════════════════════════════════════
--  21-guest-count.sql · 帶朋友來（已於 2026-08-17 執行）
--
--  舊系統有「預約 N 位」，我們沒有。後果是兩層，而且都在漏錢：
--    ① check_in() 寫死扣 1 堂 —— 帶一個朋友來，第二堂扣不掉
--    ② gt_payout(n) 的 n 是「幾筆預約」不是「幾個人頭」
--       ☢️ 教練少領錢：8/06 少 200、8/11 少 100，兩週兩次。
--
--  課卡可以分享給親朋好友（買 10 送 2 的那 2 堂），而且那 2 堂
--  【不是免費的】—— 費用稀釋在 4,000 的方案裡。錢收了、人來了、
--  教練帶了，人頭費就該算。
--
--  ☢️ 朋友【不會】進 customers。第一次來的朋友要先到櫃檯建資料，
--     而那通常是他體驗完覺得不錯才發生的事。所以用一個計數，
--     不硬幫他建一筆假客人。
--
--  執行結果：歷史兩筆補上 guest_count=1，
--  總堂數 557 = 561 − 今天早上核銷的 4 堂（沒有任何餘額被這次改動動到）。
--  鐘點費 8/06 200→400、8/11 600→700，其餘課次一分不變。
-- ═══════════════════════════════════════════════════════════════

alter table public.bookings
  add column if not exists guest_count smallint not null default 0;

comment on column public.bookings.guest_count is
  '這筆預約另外帶了幾位朋友（不進 customers）。扣課和鐘點費都算 1 + guest_count。';

-- ☢️ 上限 5。沒有上限的話，一次誤觸就會扣掉一整張課卡。
alter table public.bookings drop constraint if exists bookings_guest_count_sane;
alter table public.bookings add constraint bookings_guest_count_sane
  check (guest_count >= 0 and guest_count <= 5);

-- 教練改人數。☢️ 改完會重跑一次 check_in() ——
--    它是「對帳到目標」，算的是差額，所以重跑不會重複扣。
create or replace function public.set_guests(p_booking uuid, p_n smallint)
returns integer
language plpgsql security definer set search_path = public as $$
declare v_start timestamptz; v_status text;
begin
  if not public.is_staff() then raise exception '只有教練可以改人數'; end if;
  if p_n is null or p_n < 0 or p_n > 5 then raise exception '帶的人數只能是 0 到 5'; end if;

  select (s.session_date + s.start_time) at time zone 'Asia/Taipei', b.status
    into v_start, v_status
  from public.bookings b join public.class_sessions s on s.id = b.session_id
  where b.id = p_booking and s.product = 'GT';

  if v_start is null then raise exception '找不到這筆預約'; end if;
  if v_start < now() - interval '7 days' then
    raise exception '這堂課超過 7 天了，請找 Jerec 在後台處理';
  end if;

  update public.bookings set guest_count = p_n where id = p_booking;

  if v_status in ('attended','absent') then
    perform public.check_in(p_booking, v_status = 'attended');
  end if;
  return p_n;
end $$;

revoke all on function public.set_guests(uuid, smallint) from public;
grant execute on function public.set_guests(uuid, smallint) to authenticated;

-- check_in()：唯一的改動是目標從 -1 變成 -(1 + guest_count)。
-- gt_payout_sessions：n 從「幾筆預約」變成「幾個人頭」。
-- staff_roster：只【加】 guest_count 一欄，其餘不動（前端照欄位名取）。
-- （三支的完整內容見 Supabase migration，此處不重複貼。）
