-- ═══════════════════════════════════════════════════════════════
--  20-link-legacy-ledger.sql · 把舊系統搬過來的扣課接回預約
--  2026-08-16（已執行）
--
--  ☢️ 起因是一位客人問：「8/14 我沒上課，為什麼寫已上課？」
--
--  舊系統的【報名紀錄】和【扣課紀錄】本來就是兩份對不起來的資料：
--    · bookings   誰報名了哪一堂 —— 狀態全部是 attended，不會回頭改
--    · PassLedger 誰哪天真的被扣了一堂
--  缺席不扣課，所以「報了名沒去」的人，報名紀錄還在、流水裡沒有。
--  搬過來之後就變成：畫面說「已上課」，帳上沒扣錢。
--  ☢️ 帳是對的，畫面在說謊。
--
--  匯入時 credit_ledger.booking_id 全部是 null，所以系統答不出
--  「這一筆預約到底有沒有扣課」。這一支把它接回去。
--
--  ☢️ 只寫 booking_id，一個 delta 都不碰 —— 餘額在結構上不可能改變。
--     而且 credit_ledger_class_once 那個唯一索引會擋掉任何重複指派。
--
--  執行前先驗過一對一：72 筆流水 → 72 筆不重複預約，零歧義。
--  執行後指紋 e89ebf8c2f04c9dcb8d1f2828f4cd81a 完全沒動。
--  結果：72 筆全部接上，7 筆預約標著「已上課」但從來沒扣過課。
-- ═══════════════════════════════════════════════════════════════

with m as (
  select l.id as lid, b.id as bid
  from public.credit_ledger l
  join public.bookings b       on b.customer_id = l.customer_id
  join public.class_sessions s on s.id = b.session_id
  where l.reason = 'class' and l.booking_id is null
    and s.session_date = substring(l.note from '^(\d{4}-\d{2}-\d{2})')::date
    and s.title        = substring(l.note from '^\d{4}-\d{2}-\d{2} (.+)$')
)
update public.credit_ledger l set booking_id = m.bid
from m where l.id = m.lid;

-- my_bookings 加上 charged_delta：這一筆預約【實際】扣了幾堂。
-- 0 = 沒扣過，不管 status 寫什麼。前端就是靠這一欄講實話。
create or replace view public.my_bookings
-- ☢️☢️ 2026-08-17：下面這一行 with (security_invoker = true) 是【錯的】，
--        它讓 my_bookings 在線上整張讀不到（permission denied for table class_sessions）。
--        這幾張檢視表【必須是 definer】—— 牆是 where 裡的 my_customer_id()／is_staff()，
--        不是底層資料表的權限，而 authenticated 對 class_sessions 故意沒有 SELECT。
--        ☢️ 要重跑這一支的話，跑完一定要接著跑 db/25-fix-view-security.sql。
--        原因寫在 25 那一支的開頭。
  with (security_invoker = true) as
select b.id, b.session_id, b.status, b.booked_at, b.cancelled_at,
       s.session_date, s.start_time, s.duration_min, s.title, s.level,
       e.display_name as coach_name,
       (((s.session_date + s.start_time) at time zone 'Asia/Taipei') - now())
         > '01:00:00'::interval                                    as can_cancel,
       ((s.session_date + s.start_time) at time zone 'Asia/Taipei') as starts_at,
       b.confirmed_at,
       (b.status = 'attended' and b.confirmed_at is null)          as needs_confirm,
       coalesce((select sum(l.delta) from public.credit_ledger l
                  where l.booking_id = b.id), 0)::int              as charged_delta
from bookings b
join class_sessions s on s.id = b.session_id
left join employees   e on e.id = s.coach_id
where b.customer_id = my_customer_id();
