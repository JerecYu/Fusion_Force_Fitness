-- 48｜期初結轉重複（續）：第 47 步沖錯邊了
--
-- 第 47 步的判斷是「舊表比舊 ERP 完整，以舊表為準」，所以沖掉舊 ERP 那一筆。
-- 拿到舊系統凍結當下的完整帳目表（FusionForceErp，PassLedger 最後一列是
-- 2026-08-16 12:10 台北時間）之後，這個判斷是錯的：
--
--   Vickie wang 舊系統最後餘額 = 2（8/01 期初 3 → 8/05 上課 −1 → 2）
--   人工查帳也是 2。舊表那筆 10 是另一本手寫帳，舊 ERP 早就取代它了。
--
-- 正確的規則：
--   · 這個人「舊系統裡有帳」  → 舊系統凍結當下的餘額就是真相
--   · 這個人「舊系統裡沒有帳」→ 才輪到舊表（那 8 位真正的孤兒，這支不動他們）
--
-- 這 8 位兩邊都有帳，所以 08/18 那筆「舊表期初結轉」整筆都是多的。
-- 要做兩件事：把第 47 步沖掉的舊 ERP 期初加回來，再沖掉 08/18 那一筆。

begin;

-- ── 1）先確認影響範圍，數字不對就整批停下 ────────────────────
do $$
declare n int; s1 int; s2 int; s3 int;
begin
  select count(*), sum(b1), sum(b2), sum(f47) into n, s1, s2, s3
  from (
    select l.customer_id,
      sum(l.delta) filter (where coalesce(l.note,'') = '原團課堂數')       as b1,
      sum(l.delta) filter (where coalesce(l.note,'') = '舊表期初結轉')     as b2,
      sum(l.delta) filter (where coalesce(l.note,'') like '%期初結轉重複%') as f47
    from public.credit_ledger l
    where l.product = 'GT'
    group by 1
  ) t
  where b1 is not null and b2 is not null;

  if n <> 8 or s1 <> 66 or s2 <> 84 or s3 <> -66 then
    raise exception '☢️ 預期 8 人／期初 66／舊表 84／第 47 步 -66，實際 % / % / % / %', n, s1, s2, s3;
  end if;
end $$;

-- ── 2）把第 47 步沖掉的舊 ERP 期初加回來 ──────────────────────
with dup8 as (
  select l.customer_id,
         sum(l.delta) filter (where coalesce(l.note,'') = '原團課堂數')   as b1,
         sum(l.delta) filter (where coalesce(l.note,'') = '舊表期初結轉') as b2
  from public.credit_ledger l
  where l.product = 'GT'
  group by 1
  having sum(l.delta) filter (where coalesce(l.note,'') = '原團課堂數')   is not null
     and sum(l.delta) filter (where coalesce(l.note,'') = '舊表期初結轉') is not null
)
insert into public.credit_ledger (customer_id, delta, reason, product, note)
select customer_id, b1, 'adjust', 'GT',
       '更正：前一筆沖錯邊了，把舊系統的期初堂數加回來'
from dup8;

-- ── 3）沖掉 08/18 那筆「舊表期初結轉」 ────────────────────────
with dup8 as (
  select l.customer_id,
         sum(l.delta) filter (where coalesce(l.note,'') = '原團課堂數')   as b1,
         sum(l.delta) filter (where coalesce(l.note,'') = '舊表期初結轉') as b2
  from public.credit_ledger l
  where l.product = 'GT'
  group by 1
  having sum(l.delta) filter (where coalesce(l.note,'') = '原團課堂數')   is not null
     and sum(l.delta) filter (where coalesce(l.note,'') = '舊表期初結轉') is not null
)
insert into public.credit_ledger (customer_id, delta, reason, product, note)
select customer_id, -b2, 'adjust', 'GT',
       '☢️ 這 8 位在舊系統本來就有帳，08/18 那筆舊表期初是多加的 —— 以舊系統凍結當下的餘額為準'
from dup8;

commit;

-- ── 驗收 ────────────────────────────────────────────────────
-- 期望：這 8 人的餘額變成
--   廖庭均 33、Adele 8、Yiting 8、小虎 5、鄭旭媚 3、張小筠 1、Vickie wang 1、林屏妏 1
-- 全系統 GT 總堂數 642 → 624（−18）
--
-- 逐人對帳（舊系統凍結當下的餘額 ＋ 切換後真正的營業異動）見 tools/recon-erp.md。
-- 跑完應該只剩測試帳號 0972925321 —— 舊系統裡的「屁股1」，連 Members 資料列
-- 都沒有，本來就不該搬進來。
