# 拿舊系統的最後帳目，逐人對回新系統

搬遷之後每次懷疑「某個人的堂數不對」，就跑這一份。它不是猜，是把舊系統凍結
當下的餘額一個一個對回來。

☢️ **不要把手機號碼或姓名寫進這個 repo。** 這是公開 repo。下面的做法是「從
Excel 現場產生查詢、貼進 Supabase 執行、用完就丟」，中間不落地。

---

## 材料

`FusionForceErp.xlsx` —— 舊系統凍結當下的匯出檔（2026-08-16 12:54 凍結，
`PassLedger` 最後一列是 12:10）。這個檔**不放進 repo**，放在 `local/` 或
你自己的資料夾。

要用的兩張表：

| 表 | 欄位 | 意思 |
|---|---|---|
| `PassLedger` | `phone` / `delta` / `balanceAfter` / `createdAt` | 每一筆堂數異動，`balanceAfter` 是那一刻的餘額 |
| `Members` | `phone` / `name` | 有沒有這個人。**只在 PassLedger 出現、Members 沒有的，是測試帳號** |

---

## 步驟

**1）從 Excel 抓出每個人的最後餘額**

每個 `phone` 取 `createdAt` 最大的那一列，讀它的 `balanceAfter`。
（順手驗一下：同一個人的 `delta` 加總應該等於 `balanceAfter`，不等於就是那個
人的帳本身有問題，先查那個人。）

**2）組成一段 `values`**

```
('09xxxxxxxx',5),('09xxxxxxxx',44), ...
```

**3）貼進 Supabase SQL Editor，套進這個查詢**

```sql
with erp(phone,fin) as (values /* ← 第 2 步產生的那一段 */),
g as (
  select e.phone, e.fin, c.name,
    coalesce(sum(l.delta) filter (where l.product='GT'),0) as now_bal,
    -- 切換後真正的營業異動：上課、購課。搬遷列和更正列都要排掉
    coalesce(sum(l.delta) filter (where l.product='GT'
       and l.created_at > '2026-08-16 04:10:07+00'
       and l.reason in ('class','purchase','bonus','refund','transfer_out','transfer_in')
       and coalesce(l.note,'') not like '%期初%'),0) as biz
  from erp e
  left join public.customers c on c.phone = e.phone
  left join public.credit_ledger l on l.customer_id = c.id
  group by e.phone, e.fin, c.name)
select coalesce(name,'(系統沒這人)') as 客人, right(phone,3) as 末三碼,
       fin as 舊系統最後, biz as 切換後, fin + biz as 應該是,
       now_bal as 現在, now_bal - (fin + biz) as 差
from g
where now_bal <> fin + biz
order by abs(now_bal - (fin + biz)) desc;
```

**4）看結果**

跑完應該是空的，或只剩已知該排除的帳號。有東西跳出來就是真的對不上。

---

## 踩過的坑

☢️ **`>=` 和 `>` 差一個人。** 舊系統最後一筆是 `2026-08-16 04:10:07+00`，那筆
點名兩邊都有記。用 `>=` 會把它算成「切換後」再扣一次，Sandy Hu 就會平白多出
1 堂的假差異。要用 `>`。

☢️ **搬遷列一定要排掉，不然這支查詢會自己證明自己對。** 08/18 的「舊表期初
結轉」時間戳在切換之後，不排掉的話它會被算成「切換後的營業異動」，於是
`應該是` 跟著一起長，差額永遠是 0 —— 錯誤剛好被自己藏起來。第一次跑就是這樣
漏掉的。

☢️ **`Members` 沒有、`PassLedger` 有 → 測試帳號。** `0972925321`（備註寫
「屁股1」）就是：兩筆 40 堂 topup、兩筆 −20 手動扣、兩筆 −5 重複點名。它會以
「系統沒這人、欠 28 堂」的樣子跳出來，那是對的，不要搬。

☢️ **舊系統的時間戳是 UTC。** 查詢裡的 `+00` 不能拿掉。

---

## 判斷誰說了算

| 情況 | 用哪一份 |
|---|---|
| 舊系統（ERP）裡有帳 | **舊系統凍結當下的餘額**。它是真的在跑的系統，每一筆點名都寫進去了 |
| 舊系統裡沒有帳（孤兒） | 才輪到手寫的團課流水帳 |

☢️ 兩邊都有的人，**不要相加**。手寫流水帳是舊系統上線前的本子，舊系統已經
把它接手了 —— 相加等於把同一批堂數認兩次。第 47、48 步就是在收這個。
