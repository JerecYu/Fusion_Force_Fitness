-- ═══════════════════════════════════════════════════════════════
--  23-overdue.sql  ·  逾期未核銷（提醒用，不動任何資料）
--  2026-08-17
--
--  來源：2026-08-17 Jerec「核銷時間不能放寬太長，會干擾現場作業。
--        新增超過 2 個小時系統發 E-MAIL 提示給教練如何呢？也可以留作存證」
--
--  ☢️ 存證和提醒是兩件事，不要混在一起。
--     存證【已經有了】—— checked_at / checked_by 一直都在資料庫裡，
--     而且改不掉。E-mail 不會讓證據變得更有效力，它只是一條通知管道。
--     所以這一支只解決【提醒】：把「該點卻沒點」算出來讓人看得到。
--
--  ☢️ 這是一張【純讀】的檢視表。沒有 insert、沒有 update、沒有函式。
--     提醒功能永遠不該有能力改到帳。
-- ═══════════════════════════════════════════════════════════════

-- ☢️ 為什麼不直接改 staff_sessions 加個欄位就好？
--    因為 staff_sessions 的 where 寫死了 session_date >= today - 7。
--    超過 7 天沒點的課會【整堂消失】—— 而那正是最需要有人看到的一筆
--    （check_in() 也擋在 7 天，代表它已經不是教練能自己救的了）。
--    要嘛放寬 staff_sessions 的範圍（會讓教練的課表變得很長），
--    要嘛另開一張只放逾期的。選後者。
create or replace view public.overdue_checkins
-- ☢️☢️ 2026-08-17：下面這一行 with (security_invoker = true) 是【錯的】，
--        它讓 overdue_checkins 在線上整張讀不到（permission denied for table class_sessions）。
--        這幾張檢視表【必須是 definer】—— 牆是 where 裡的 my_customer_id()／is_staff()，
--        不是底層資料表的權限，而 authenticated 對 class_sessions 故意沒有 SELECT。
--        ☢️ 要重跑這一支的話，跑完一定要接著跑 db/25-fix-view-security.sql。
--        原因寫在 25 那一支的開頭。
  with (security_invoker = true) as
select
  s.id                                                          as session_id,
  s.session_date,
  s.start_time,
  s.title,
  s.status                                                      as session_status,
  s.coach_id,
  e.display_name                                                as coach_name,
  ((s.session_date + s.start_time) at time zone 'Asia/Taipei')   as starts_at,
  count(b.id) filter (where b.status = 'booked')                 as n_pending,
  count(b.id) filter (where b.status <> 'cancelled')             as n_expected,
  -- 逾期幾小時。前端拿去顯示「逾期 3 小時」，不用自己算時區。
  round(extract(epoch from (
      now() - ((s.session_date + s.start_time) at time zone 'Asia/Taipei')
  )) / 3600)::int                                               as overdue_hours,
  -- ☢️ 超過 7 天 = 教練自己按也按不動了（check_in 會擋），只有 Jerec 從後台救得回來。
  --    這個旗標存在的意義就是把「還能自己處理」和「要找人」分開。
  (((s.session_date + s.start_time) at time zone 'Asia/Taipei')
     < now() - interval '7 days')                               as too_late
from public.class_sessions s
left join public.employees e on e.id = s.coach_id
left join public.bookings  b on b.session_id = s.id
where public.is_staff()
  and s.product = 'GT'
  -- ☢️ 課【開始】後 2 小時，不是課結束後 2 小時。
  --    跟 issue_checkin_token 的「課後 2 小時」是同一條線，兩邊不能不一樣。
  and ((s.session_date + s.start_time) at time zone 'Asia/Taipei')
        < now() - interval '2 hours'
group by s.id, e.display_name
-- ☢️ 已取消的課如果還有人掛在上面，【也要出現】。
--    那種課教練點不了名（check_in 會擋），但人是真的來了或真的沒來，
--    帳掛在那裡。藏起來的話那幾個人就永遠不見了。
having count(b.id) filter (where b.status = 'booked') > 0;

comment on view public.overdue_checkins is
  '課開始 2 小時後還有人沒點名的課。純提醒用，不動任何資料。too_late = 超過 7 天，教練按不動了。';

grant select on public.overdue_checkins to authenticated;
