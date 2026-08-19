-- 52｜搬遷把「退掉的預約」記成了「有來上課」
--
-- 第 50 步的薪資試算跟舊系統凍結當下的簽到人數對不起來，7 堂課有落差。查下去
-- 是同一個原因：這 7 筆預約在舊系統是 refundedCount=1（客人退掉、堂數退回去、
-- 沒有扣課），搬進來卻變成 status='attended'。
--
-- 自己的資料就能證明：這 7 筆是全系統僅有的「status='attended' 但帳本上一列
-- 都沒有」的預約。舊系統匯出檔逐筆核對，7 筆全部是 refunded。
--
-- ☢️ 為什麼餘額對帳抓不到：帳本本來就沒有這幾筆，所以堂數是對的。錯的只有
--    「這堂課有幾個人到場」—— 而那一欄只有薪資會用到。上線後第一次算薪資才
--    浮出來。
--
-- ☢️ 「沒扣堂數」不能拿來當通則。規則第五篇 3 說體驗、免費、贈課、補課只要
--    實際到場就要列入人數 —— 那些正好也是沒扣堂數的。所以這一支<只>處理切換
--    前的搬遷資料，而且逐筆對過舊系統匯出檔；之後改由報表列出來給人看。

begin;

do $$
declare n int;
begin
  select count(*) into n
  from public.bookings b
  join public.class_sessions s on s.id = b.session_id
  where b.status = 'attended'
    and s.session_date <= date '2026-08-16'
    and not exists (select 1 from public.credit_ledger l where l.booking_id = b.id);

  if n <> 7 then
    raise exception '☢️ 預期 7 筆，實際 % 筆 —— 先逐筆對過舊系統匯出檔再跑', n;
  end if;
end $$;

update public.bookings b
   set status       = 'cancelled',
       cancelled_at = coalesce(b.cancelled_at, now())
  from public.class_sessions s
 where s.id = b.session_id
   and b.status = 'attended'
   and s.session_date <= date '2026-08-16'
   and not exists (select 1 from public.credit_ledger l where l.booking_id = b.id);

commit;

-- ── 驗收 ────────────────────────────────────────────────────
-- 切換前的課次，每一堂的到場人數要跟舊系統匯出檔的 checkedInCount 一致
-- （扣掉舊系統裡的測試帳號與職員測試列）。
--
-- 八月鐘點費影響：VC −900、Jerec −200、Peter −100，合計 −1,200。
