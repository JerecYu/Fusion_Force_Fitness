# FFF 專案交接紀錄

> 最後更新：2026-08-08 · 第二幕完成（分水嶺過了）
> 開新對話時附上這份即可接續。
>
> 📌 這是一份**持續更新的活文件**，跟著程式碼一起版控。
> 不要另存 `-20260808`、`-v2` 這種檔名 —— 直接改這一份就好，
> Git 會替你記得每一個歷史版本。要看舊版：`git log HANDOVER.md`

---

## ⚡ 這一版新增了什麼（給接手的人快速對焦）

```
🎯 第二幕完成 —— 分水嶺過了。GT 課表已經在網路上讀真實資料庫
✅ public_schedule 公開課表檢視表（第六節）＋ 用 anon 實測三張原表全部擋住
✅ GT-booking.html 接上 Supabase，日期分頁改成真實日期，候補邏輯整套移除
✅ 上線網址：jerecyu.github.io/Fusion_Force_Fitness/line-prototype/GT-booking.html
✅ db/ 補到 11 支；新增 plan/ 資料夾放進度地圖（進度會自己算，見第十二節）
✅ 風險 1（免費方案被自動暫停）已解除 —— 資料庫從此有外部流量
☢️ 第六節有兩個「絕對不要做」，第十四節有兩個「不會報錯的坑」
```

---

## 一、我是誰

- Jerec，諧動空間 Fusion Force Fitness（FFF）總教練
- 場館：台北市信義路二段 74 號 10 樓
- **程式設計新手**，偏好白話、比喻式說明，不喜歡直接丟術語
- 習慣先問「為什麼」再動手，會主動確認理解是否正確
- 一次給一個步驟，等我回報結果再繼續
- 我會截圖確認，請直接指出畫面上該點哪裡
- 有風險的操作請先講清楚後果，不要事後才說

---

## 二、目前有三條線同時進行

我用不同設備開不同對話，分頭處理：

| 線 | 內容 | 是否碰 `index.html` |
|---|---|---|
| A | 官網細節打磨 | ✅ **這條線獨占** |
| B | 預約系統（本文件主線） | ❌ 只碰 `db/` 和預約頁 |
| C | ERP 架構知識與工具評估 | ❌ 純討論 |

⚠️ **已經撞過一次**：B 線做的「手機版教練卡左右排列」被 A 線改成上下堆疊。
**規則：`index.html` 只由 A 線改動。** 其他線需要動它時，先請我提供最新檔案，不要憑記憶改。

---

## 三、官網現況

- **版本 v1.3.1**（版本號寫在 `index.html` 第 5 行 `<meta name="fff-version">`）
- 網址：`https://jerecyu.github.io/Fusion_Force_Fitness/`
- 本機路徑：`C:\Users\user\FFF-Projects\fff-platform`
- GitHub：`https://github.com/JerecYu/Fusion_Force_Fitness`

### 專案資料夾結構

```
fff-platform/
├── .git/
├── .gitignore
├── assets/
├── db/            ← 預約系統的 SQL，B 線只碰這裡
├── index.html     ← A 線獨占，其他線不要動
└── README.md
```

### 版本編號規則

| 位置 | 何時加 |
|---|---|
| 大 1.x.x | 動架構、加模組 |
| 中 x.1.x | 加新區塊、新功能 |
| 小 x.x.1 | 改文字、價格、換照片 |

### ⚠️ 未解決

1. **GitHub Pages 部署卡住**：build 成功但 deploy 一直 `deployment_queued` 逾時。這是 GitHub 端的已知問題，不是設定錯誤。解法是重試（可能要多次）或推空 commit。備案是改用 Cloudflare Pages。
   註：這是「網站部署」卡住，跟 `git push` 是兩回事。部署卡住不代表程式碼沒上傳。
2. **年齡層資訊矛盾**：首頁寫「12+」，但服務課程頁有「6–14 兒童體適能」卡片、聯絡頁 FAQ 寫「服務 6 歲到 100 歲」。這是服務範圍的商業決定，還沒定案。

---

## 四、預約系統：業務規則（已定案）

| 規則 | 定案 |
|---|---|
| 團體課取消期限 | 課前 1 小時 |
| 報名截止 | 上課當天 00:00 **結算**（不是關閉報名） |
| 缺席 | 不扣課 |
| 扣課時機 | 課後由教練現場點名核銷 |
| 同時預約上限 | 無限制 |
| 剩 0 堂能否預約 | 可以，到現場再課購 |
| 候補機制 | 不需要 |
| 額滿處理 | 系統不硬擋，跳提醒「已額滿，現場座位需與教練確認」 |
| 私人課 | 客人送需求 → 教練聯繫敲定（不是預約） |

### 00:00 的正確理解

```
報名開放（隨時可報）
   │
   ├── 00:00 之前 ── 教練持續等待，有人報就成立
   │
00:00 結算  ← 現在由 pg_cron 自動執行
   ├─ 有人（≥1）→ ✅ 成立
   │       └→ 當天仍可加入（未滿 10 人，課程進行中也能插入）
   │
   └─ 無人（=0）→ ❌ 取消
           └→ 之後有人報名也不開課、不扣課
```

---

## 五、Supabase 現況

- 組織 `JerecYu`，專案 `fff-platform`，Free 方案
- Region：**Northeast Asia (Tokyo)**
- Project URL：`https://ubvbmksvvyzjzsmfxeby.supabase.co`

### 金鑰（新命名）

| 畫面上的 | 舊稱 | 能否進前端 |
|---|---|---|
| Publishable key（`sb_publishable_...`） | anon key | ✅ |
| Secret key（`sb_secret_...`） | service_role key | ❌ **絕對不行** |

⚠️ 金鑰存在我的密碼管理工具，**不在專案資料夾裡**。

### 建立專案時的設定

- Enable Data API：✅
- Automatically expose new tables：❌
- Enable automatic RLS：✅

### 已安裝的模組（Integrations）

```
Data API｜Vault｜Cron（pg_cron，2026-08-08 安裝）
```

---

## 六、七張資料表（已建好，RLS 全部上鎖）

| 資料表 | 用途 | 規則數 |
|---|---|---|
| `employees` | 員工／教練，**能登入**（點名核銷用） | 2 |
| `customers` | 客人，含 `line_user_id` | 3 |
| `class_templates` | 週課表範本 | 1 |
| `class_sessions` | 每一堂實際的課 | 2 |
| `bookings` | 預約 | 5 |
| `credit_ledger` | 堂數異動流水帳 | 3 |
| `pt_requests` | 私人課需求單 | 4 |

外加一個檢視表 `customer_credits`（剩餘堂數＝流水帳加總）。

### 三條不能破的線

1. **`credit_ledger` 客人只能讀，永遠不能寫**——能寫就能自己加堂數
2. **`bookings` 的取消時限寫在 RLS 裡**，不是只靠前端藏按鈕
3. **`employees` 不對客人開放**——網站要顯示教練資料，另開只含安全欄位的公開檢視表

### 幾個設計決定的理由

- **`class_sessions` 複製範本欄位**而非每次查範本：範本會改，歷史紀錄不該跟著變
- **剩餘堂數存流水帳不存數字**：客人問「為什麼少一堂」要查得到，扣錯要追得回
- **離職改 `is_active` 不刪除**：刪掉會讓歷史課堂失去教練資訊

### 商品別 `product`（2026-08-08 晚間新增的維度）

FFF 賣的不只團體課：

| 代號 | 商品 | 有教練 | 扣堂數 | 上公開課表 | 教練薪資 |
|---|---|---|---|---|---|
| `GT` | 主題式團體課 | ✅ | ✅ | ✅ | 依實到人頭 |
| `PT` | 私人教練課 | ✅ | ✅ | ❌ | 業績抽成 |
| `PGT` | 私人團體班 | ✅ | ✅ | ❌ | 待定 |
| `RT` | 場地租借 | ❌ | ❌ 收租金 | ❌ | 無 |

**第一階段只做 GT。**但 `class_sessions` 和 `credit_ledger` 兩張表都先加上 `product` 欄位（預設 `GT`），
因為現在加是四行 SQL，等 81 個人和幾百筆流水搬進來之後再加，**每一列都要回頭補標**。

兩個因此改變的設計：

1. **堂數是分錢包的。** `customer_credits` 從「一個人一個餘額」改成「一個人每一種商品各一個餘額」。
   不分的話，客人可以拿團體課的堂數去上私人課，而系統覺得完全合理。
2. **`RT` 跟課不是同一種東西**（沒教練、不扣堂數、收租金）。它跟課唯一共用的是「佔用場地的一段時間」。
   真的要做的時候，關鍵不是「RT 要不要進系統」，而是**排課時系統要知道那個時段已經被租走了**，不然會撞場。


---

### 公開檢視表 `public_schedule`（2026-08-08 新增）

除了 `customer_credits`，現在還有第二個檢視表 —— 這是**對外唯一開放讀取的對象**。

| 項目 | 內容 |
|---|---|
| 建立於 | `10-public-views` 分頁／`db/10-public-views.sql` |
| 欄位數 | 剛好 12 欄 |
| 誰讀得到 | `anon`、`authenticated`（已 grant select） |
| 資料來源 | `class_sessions` ＋ `employees`（left join）＋ `bookings`（count） |
| 過濾條件 | ☢️ **`where s.product = 'GT'`**（2026-08-09 第 24 步加上）|

12 個欄位：
`session_id`／`session_date`／`start_time`／`duration_min`／`title`／`level`／`coach_name`／`capacity`／`booked_count`／`seats_left`／`is_full`／`status`

#### 兩個寫法上的決定

1. **`left join employees`，不是一般 join**
   `class_sessions.coach_id` 可以留空。用一般 join 的話，還沒指定教練的課會**整堂從課表消失** —— 客人不會看到「教練待定」，他會看到那個時段根本沒課。

2. **人數用 `bookings.cancelled_at is null` 來數，不用 `status`**
   `bookings.status` 是 `text`，實際會存什麼字還沒定。猜錯的話人數永遠是 0，**而且不會報錯**。`cancelled_at` 有沒有值則沒有歧義，將來 status 怎麼命名都不影響這支。

#### ⚠️ 它刻意繞過 RLS —— 這是設計，不是漏洞

`employees` 不對客人開放，但課表要顯示教練名字。

如果改成「讓訪客用自己的身分讀」，就得在 `employees` 上開一條訪客可讀的規則 —— 而 **RLS 是整列開放，不是單一欄位**。開了那條規則，訪客就能直接查 `employees`，把手機和 email 一起撈走。

所以做法是反過來：訪客連 `employees` 的門都碰不到，檢視表以管理員身分進去，只端出 `display_name` 一欄。

**這扇窗本身就是那道牆。窗裡沒有的欄位，外面永遠拿不到。**

#### ☢️ 兩個絕對不要做的動作

1. **不要照 `permission denied` 的 HINT 執行 `GRANT SELECT ON public.employees TO anon;`**
   Postgres 只知道「有人被擋住了」，它不知道那正是你要的結果。照做等於一行拆掉整道牆，而且**不會報錯** —— 可能很久以後才發現教練手機是公開的。同理，`Debug with Assistant` 那顆按鈕在這種錯誤上也不要按。

2. **不要因為 Advisors 顯示 `Security Definer View` 警告就改成 `security_invoker`**
   那個警告是在提醒「這東西繞過 RLS，請確認你是故意的」。你是故意的。改掉就等於打開上面那個洞。

3. **☢️ 絕不讓 `public_schedule` 沒有 `where product = 'GT'`**　✅ 2026-08-09 已加上
   這張檢視表建立時是**無條件**讀 `class_sessions` 的每一列 —— 因為那時候表裡只可能有團體課。
   但排 PT 的時候一定會把它排進 `class_sessions`（場地要排班，不然撞場），那一刻
   **「王小姐 週二 14:00 上私人課」就會出現在官網課表上**。
   這個外洩**不會報錯、不會有人通知你**。

   第 24 步用一次真的攻擊測試證實過：加 `where` 之前，假的 PT 課**確實**出現在公開課表上（33 筆 vs 32 堂 GT）；
   加了之後變 0。**這不是理論風險，是量到的。**

   > 新增商品別的時候，**預設是「不給看」**。要公開才明確加進 `where` 裡 —— 不要反過來寫成「排除 PT」，
   > 那樣每多一種商品就多一個會忘記的地方。

> 記一條原則：**`permission denied` 不一定是問題。**
> 先問「這個身分本來就該進得去嗎」，再決定要不要修。

#### 驗證過的結果（2026-08-08，SQL Editor 右上角把 Role 切成 `anon` 實測）

```
public_schedule   →  30 筆              ✅ 訪客看得到
employees         →  permission denied  ✅ 擋住
customers         →  permission denied  ✅ 擋住
class_sessions    →  permission denied  ✅ 擋住
```

`public_schedule` 和 `class_sessions` 是**同一批課表資料**。走窗口拿得到、走原表拿不到 —— 這一對結果就是整個設計的證明。

⚠️ 用 `anon` 測完，**記得把 Role 切回 `postgres`**。忘了切的話之後每個查詢都會安靜地失敗，畫面上不會告訴你原因。

#### 2026-08-09 加上 product 過濾後的複測

```
① 原表塞一筆假的 PT   →  class_sessions 看得到      1 筆  ✅
② 公開課表            →  看不到它                   0 筆  ✅  ← 門關上了
③ 公開課表總筆數      →  32 ＝ GT 課堂數 32         沒誤殺 ✅
④ anon 讀 public_schedule →  32 筆                        ✅
⑤ anon 讀 class_sessions  →  permission denied           ✅
```

假資料用 `id` 比對刪除（不是課名字串），整段一次交易，測完殘留 0 筆。


---

## 七、目前資料

```
教練 6 位｜課表範本 14 堂｜課堂數量每天由排程自動增長
```

教練：簡基城、Jerec（owner）、Jessica、VC、Peter、Johnson
`auth_user_id` 目前都是空的，等教練真的註冊帳號才會填。

⚠️ **課堂數量不再是固定的 28。** 排程每天會往前補到未來 14 天，所以這個數字會浮動。看到它變動是正常的，不是出錯。

### 週課表 14 堂

| 星期 | 時間 | 課程 | 難度 | 教練 |
|---|---|---|---|---|
| 一 | 09:00 | TRX綜合雕塑 | adv | Peter |
| 一 | 12:30 | 功能性核心 | beg | Johnson |
| 一 | 19:30 | 循環有氧 | int | Johnson |
| 二 | 09:00 | 功能性核心 | beg | Peter |
| 二 | 12:30 | 基礎運動養成 | beg | Jerec |
| 二 | 18:30 | 交叉肌力訓練 | adv | VC |
| 三 | 12:20 | 間歇有氧 | adv | VC |
| 四 | 10:00 | 交叉肌力訓練 | int | Johnson |
| 四 | 19:00 | 基礎運動養成 | beg | Johnson |
| 五 | 12:20 | 交叉肌力訓練 | int | VC |
| 五 | 19:00 | 交叉肌力訓練 | int | Jessica |
| 六 | 11:00 | 功能性核心 | beg | Johnson |
| 六 | 16:00 | 交叉肌力訓練 | adv | VC |
| 日 | 11:00 | 循環有氧 | int | VC |

### 快速健檢查詢（貼在 `00-check`）

```sql
-- 純查詢，可以隨便重複執行
select
  (select count(*) from employees)       as 教練,
  (select count(*) from class_templates) as 範本,
  (select count(*) from class_sessions)  as 課堂,
  (select count(*) from (
     select display_name from employees
     group by display_name having count(*) > 1
   ) x) as 重複的教練;
```

**應該看到**：`6 ｜ 14 ｜（浮動）｜ 0`

最後那個 `0` 是重點 —— 光看總數對不對還不夠，萬一刪錯人又補錯人，總數也可能湊巧正確。這一欄專門抓「同一個名字出現兩次」。

---

## 八、SQL Editor 十一張分頁

| 分頁 | 能否重複執行 | 保險絲 |
|---|---|---|
| `00-check` | ✅ 純查詢 | 不需要 |
| `01-employees` ~ `04-credits+pt` | ❌ 建表，重跑會報錯（安全） | 不需要 |
| `05-seed-employees` | ⚠️ 塞資料 | ✅ 已加 |
| `06-seed-class-templates` | ⚠️ 塞資料 | ✅ 已加 |
| `07-daily-job` | ✅ `create or replace` ＋ `on conflict do nothing` | 不需要 |
| `08-cron` | ✅ 同名排程會覆蓋，不會產生第二份 | 不需要 |
| `09-fix-dup` | ☢️ **最危險**，三行沒有 where 的 delete | ✅ 已加 |
| `10-public-views` | ✅ `create or replace view`，不塞資料 | 不需要 |

### `00-check` 現在放了六段常駐工具

| # | 用途 | 何時跑 |
|---|---|---|
| ① | 快速健檢（教練／範本／課堂／重複的教練） | 每次登入第一件事 |
| ② | 看公開課表 `public_schedule` | 想確認客人看到什麼 |
| ③ | 場記 `daily-class-job` 執行紀錄 | 懷疑課表沒長的時候 |
| ④ | 課堂結算狀況總覽（各 status 幾堂） | 想看整體 |
| ⑤ | 稽核：所有資料表都上鎖了嗎 | **每建一張新表就跑** |
| ⑥ | 稽核：`public_schedule` 有沒有多開欄位 | **每次改那扇窗就跑** |

⚠️ **⑤ 看不到 `public_schedule`，那是正常的。** 它的條件是 `relkind = 'r'`（只抓一般資料表），檢視表是 `'v'`。檢視表沒有自己的 RLS —— 它的安全來自「窗裡開了哪些欄位」和「誰有 select 權限」。

**⑤ 管房間的鎖，⑥ 管窗口的大小，兩支合起來才涵蓋全部。**

分隔線以下是「臨時鷹架區」，臨時查詢貼那裡，**跑完就刪**。
（2026-08-08 踩過一次：四段長得很像的盤點查詢混在一起，反白時框錯一段，拿到的是上一次的結果卻沒發現。）

### 保險絲是什麼

在塞資料的 SQL **最上面**加一段檢查，已經有資料就直接中止並報錯，一筆都不會插進去。

```sql
-- 05 用 employees，06 用 class_templates
do $$
begin
  if exists (select 1 from class_templates) then
    raise exception '⛔ class_templates 已有 % 筆資料，這支已經執行過了。要重建請先跑 09-fix-dup 清空。',
      (select count(*) from class_templates);
  end if;
end $$;
```

09 的保險絲不一樣，它擋的是「系統已經上線」：

```sql
do $$
begin
  if exists (select 1 from bookings) then
    raise exception '⛔ bookings 已有 % 筆預約紀錄。這支會把課堂連同預約一起清掉，已中止。',
      (select count(*) from bookings);
  end if;
  if exists (select 1 from customers) then
    raise exception '⛔ customers 已有 % 位客人。系統已經上線，不能再用「全部清空重建」的方式修資料，已中止。',
      (select count(*) from customers);
  end if;
end $$;
```

**原理**：Postgres 把一次送出的敘述當成一個整體，中間任何一步出錯，前面做過的全部退回，不會做半套。

### ⚠️ 保險絲必須裝在「兩個地方」，缺一不可

這是 2026-08-08 當晚差點漏掉的重點：

| 位置 | 作用 |
|---|---|
| `db/*.sql` 備份檔 | 未來重建資料庫時照著跑，不會重複插入 |
| **Supabase 分頁** | **真正防手滑的地方** |

**只有備份檔有保險絲＝防護等於零。** 沒有人會不小心去執行備份檔，會被手滑按到 Run 的永遠是 Supabase 分頁。保險絲要裝在槍上，不是裝在保險箱裡。

**目前兩邊都已裝好。**

### ⚠️ 保險絲的唯一漏洞

它只在「整張分頁一起執行」時有效。如果用 `Run selected` 只選下面的 insert，就繞過它了。所以下面那個習慣還是得留著，兩層是互補的，不是誰取代誰。

### 一定要養成的習慣：按 Run 之前先看按鈕

- 按鈕寫 **`Run`** → 整張分頁從頭跑到尾
- 按鈕寫 **`Run selected`** → 只跑你反白的部分

用滑鼠反白一段再按，就只跑那一段。同一張分頁可以放很多段查詢，各跑各的，不用一直開新分頁。

⚠️ **Results 面板顯示的是「上次按 Run 的快照」，不是即時資料。**
它像相簿裡的舊照片，不是一扇窗。要知道現在的真實狀況，一定要重新查詢。

**千萬不要為了讓 Results 看起來乾淨，而回去按 05／06 的 Run** —— 那會把畫面「修好」，同時把資料再弄壞一次。

### 分頁會自動儲存

上方有 `Autosave enabled`，存好時旁邊會出現 ✓。分頁存在 Supabase 伺服器上，不是瀏覽器裡，換一台電腦登入一樣都在。**可以安全關閉瀏覽器。**

### 已踩過的坑

**05 和 06 被重複執行過**，變成 12 位教練、28 筆範本。已用 `09-fix-dup` 清空重建。現在兩張都有保險絲了。

---

## 九、db/ 備份（十二支，可完整重建）

```
db/
├── 00-check-rls.sql
├── 01-employees.sql
├── 02-customers.sql
├── 03-classes-bookings.sql
├── 04-credits-pt.sql
├── 05-seed-employees.sql        ← 有保險絲
├── 06-seed-class-templates.sql  ← 有保險絲
├── 07-daily-job.sql
├── 08-cron.sql
├── 09-fix-dup.sql               ← 有保險絲
├── 10-public-views.sql          ← 公開課表檢視表（含 where product='GT'）
└── 11-alter-migration.sql       ← 商品別 product ＋ paid_by ＋ 重建 customer_credits
```

**現在如果資料庫整個消失，可以從這十二支照 00→11 的順序重建。** 這件事在 2026-08-08 之前是做不到的。

⚠️ 舊文件誤記為「已包含 00~06」，實際上 `06`、`07`、`08`、`09` 從來沒備份過。

**檔名規則**：分頁名的 `+` 換成 `-`，例如分頁 `03-classes+bookings` → 檔案 `03-classes-bookings.sql`。

**怎麼從 Supabase 匯出 SQL**：打開分頁 → 編輯區 `Ctrl+A` → `Ctrl+C` → 貼進本機檔案。
⚠️ 右上角的 `Export` 按鈕**不要用**，它匯出的是下方 Results 的 CSV，不是 SQL。

---

## 十、✅ pg_cron 排程（2026-08-08 完成）

### 安裝路徑已變更

⚠️ **不再是 Database → Extensions**（舊文件寫的路徑）。
現在走：**Integrations → Cron → Install integration**（右上角綠色按鈕）。
裝好後左側 `INSTALLED` 數字會 +1，多出 Cron。

### 排程內容

```sql
select cron.schedule(
  'daily-class-job',
  '0 16 * * *',
  $$ select public.daily_class_job(); $$
);
```

| 項目 | 值 |
|---|---|
| jobid | 1 |
| jobname | `daily-class-job` |
| schedule | `0 16 * * *`（UTC）＝台灣 00:00 |
| active | `true` |
| command | `select public.daily_class_job();` |

**首次自動執行**：`2026-08-08 00:00:00`（台灣時間，分秒不差）→ `succeeded` ✅

### 排程跟你的瀏覽器完全無關

`daily-class-job` 註冊在**資料庫內部**，跑的時候是 Supabase 東京機房的 Postgres 自己在動。關掉瀏覽器、關機、出國兩週，它照樣每天台灣 00:00 執行。

### 三個當時想清楚的細節

**為什麼是 16 不是 0**
資料庫排程用 UTC 計時，台灣快 8 小時。寫 `0 0 * * *` 實際會在台灣早上 8 點才跑，那時早課已經開始。
已用查詢向資料庫求證過，不是憑算術：

```sql
select
  (now() at time zone 'Asia/Taipei')::timestamp(0)  as 台灣現在時間,
  (now() at time zone 'UTC')::timestamp(0)          as 資料庫UTC時間,
  ((current_date + time '16:00')
     at time zone 'UTC'
     at time zone 'Asia/Taipei')::timestamp(0)      as 今天UTC16點在台灣是;
```

第三欄回傳「明天 00:00:00」，那就是證據。

**為什麼函式前面要加 `public.`**
排程是半夜由背景程序執行的，那個環境預設會找哪些 schema 不一定跟 SQL Editor 一樣。寫上 `public.` 等於直接給門牌號碼，不靠猜。

**為什麼要先確認函式存在才排程**
排程失敗的時候是**安靜的**。名字打錯的話，排程照樣建得起來、`active` 照樣是 true，但每天半夜撞牆，不會有人通知你。可能兩週後才發現課表沒長。

```sql
-- 排程前先確認函式在，應該回傳 1 筆：public ｜ daily_class_job ｜（無參數）
select
  n.nspname as 所在位置,
  p.proname as 函式名稱,
  coalesce(nullif(pg_get_function_identity_arguments(p.oid), ''), '（無參數）') as 需要的參數
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where p.proname = 'daily_class_job';
```

### 常用查詢

```sql
-- 排程還在嗎？
select jobid, jobname, schedule, active, command from cron.job;

-- 跑過幾次？成功嗎？
-- ⚠️ cron.job_run_details 沒有 jobname 欄位，只有 jobid，一定要 join 才能用名稱篩選
select
  d.runid,
  (d.start_time at time zone 'Asia/Taipei')::timestamp(0) as 台灣時間,
  d.status,
  d.return_message
from cron.job_run_details d
join cron.job j on j.jobid = d.jobid
where j.jobname = 'daily-class-job'
order by d.start_time desc
limit 5;
```

`return_message` 顯示的是資料庫的執行結果標記（例如 `1 row`），**不是函式回傳的那句中文訊息**。想知道實際做了什麼，要直接查 `class_sessions`。

### 要停用時

```sql
select cron.unschedule('daily-class-job');
```

☢️ **絕對不要下 `drop extension pg_cron;`** —— 那會把所有排程連同設定一起永久刪除，救不回來。

---

## 十一、⚠️ 三個已知風險（1 已解除，2、3 還在）

### 1. ~~免費方案專案會被自動暫停~~　✅ 2026-08-08 已解除

Supabase 免費方案的專案，**連續約一週幾乎沒有外部請求就會被自動暫停**。專案一暫停，排程也不會跑 —— 課堂不會長、結算不會做，而且不會有人通知你。

**已解除**：GT 預約頁在第 20 步接上並推上 GitHub Pages，資料庫從此有外部流量。
（留著這一段是因為它解釋了「為什麼要先接前端再匯客人」—— 那個決定的理由值得記得。）

### 2. 排程漏跑的那幾天，永遠不會被補結算

`daily_class_job()` 的 ②③ 都寫 `session_date = v_today`，**只結算「今天」**。

如果排程有幾天沒跑（例如上面那個暫停情境），中間那幾天的課堂會永遠停在 `pending`，既沒成立也沒取消，卡在那裡。

**改法**：把 `=` 改成 `<=`

```sql
where s.session_date <= v_today
  and s.status = 'pending'
```

這樣每次執行都會順手把所有還沒結算的過去日期一起補掉。

⬜ **還沒改，因為要先想清楚**：三天前的課現在才補判定「取消」，對已經報名的客人合不合理？這是商業決定，不只是技術問題。

### 3. 在有客人之前，每天的課都會被自動取消

**這不是錯誤，是照規則正確運作。**

`bookings` 現在是空的（前端還沒接上，沒有客人能報名），所以每天 00:00 結算時，函式會判定「無人報名 → 取消」，把當天所有課標成 `cancelled`。

**在客人資料匯入、前端接上之前，每天半夜都會發生一次。** 看到一整排 `cancelled` 不用緊張。

想看實際狀況：

```sql
select
  session_date as 日期,
  status       as 狀態,
  count(*)     as 堂數
from class_sessions
group by session_date, status
order by session_date, status;
```

---

## 十二、之後的路線

> 📌 **完整的 42 步清單在 `plan/` 資料夾**，用瀏覽器打開 `plan/fff-roadmap-steps.html`。
> 那份有每一步的完成判準、當時踩過的坑、和一張五幕路線圖。
>
> **這一節刻意不再重複寫進度數字。**
> 同一個事實寫在兩個地方，遲早會對不起來 —— 第九節那個「`db/` 已包含 00~06、實際只有 00~05」
> 就是這樣來的。這裡只留「為什麼」，「做到哪」交給 `plan/`。

### 怎麼更新進度

只改 `plan/roadmap-data.js` 一個檔案，把那一步的 `done: false` 改成 `done: true`。

進度條、每一幕的計數、路線圖上綠線的長度、紅色定位釘的位置、「現在只做這一件事」那張卡、
架構地圖的「你在這裡」三格、三個風險的「已解除」標記 —— **全部會自己跟上，一個數字都不用手改。**

### 五幕結構

第一階段的範圍是「官網 ＋ 能放在 LINE 上的客戶預約系統」。ERP 是終極目標，但刻意不編號、不排序。

| 幕 | 做什麼 | 劇場比喻 |
|---|---|---|
| 一 | 搭後台 | 蓋道具間、請場記 |
| 二 | 接電 | 把舞台和後台接起來　←　**分水嶺** |
| 三 | 接手舊劇院 | 舊系統資料搬遷 |
| 四 | 開大門 | 蓋 LINE 劇院大門 |
| 五 | 讓教練上工 | 前台櫃檯數位化 |
| 地平線 | ERP | 看得到方向，還沒有路 |

---

### ⚠️ 順序改過：為什麼「客人資料匯入」被往後挪

舊版這一節寫的下一步是「客人資料匯入」，後來改成先做「前端接上 Supabase」。

三個理由：

1. **管線沒通之前，匯入再多客人，畫面上也不會多出任何東西。** 做完會不知道自己做對了沒有。
2. **接電那一幕完全不需要任何客人資料。** 課表範本和教練都已經在資料庫裡了，直接讀出來就有畫面。
3. **做完當場解掉風險 1。** 免費方案一週沒有外部請求就會被自動暫停，而且不會有人通知你。

**事後看，這個決定是對的。** 第二幕在接的過程中踩到兩個不會報錯的坑（見第十四節），
那兩個坑如果混在「客人資料也剛匯完」的狀態下出現，會很難分辨是資料錯還是程式錯。

客人資料匯入排在第三幕，沒有被刪掉。

---

### ⚠️ 第三幕已改寫（2026-08-08 晚間）

原本第三幕叫「匯入客人名單」，假設是**手工整理一份 Excel 再匯進去**。

後來發現舊系統有**完整的資料庫匯出**（10 個分頁：members／Staff／Classes／Bookings／
LessonInstances／PassLedger…），而且離線盤點證實**舊帳本是自洽的**。

於是整幕改寫成 **「舊系統資料搬遷」**：

- 要搬的不是一張名單，是**一整套還在營運中的帳** —— 81 個人、完整堂數流水、上課歷史
- 「期初餘額怎麼記」這個原本的難題**直接消失了** —— 有完整流水，不需要結轉
- 新增了 **第 37 步「切換日」**：停業一天，正式搬家（週三只有一堂課，是天然的分水嶺）
- 步驟總數 **36 → 39**

四個搬遷決定和薪資規則記在**附錄四**。

---

### 第二幕過完之後，狀況變了

| | 之前 | 現在 |
|---|---|---|
| 課表資料 | 寫死在 `GT-booking.html` 裡 | 即時讀 `public_schedule` |
| 客人看得到的網址 | 只有官網 | 多了 GitHub Pages 上的預約頁 |
| 資料庫外部流量 | 零 | 有了（風險 1 解除） |
| 訂課 | 假的，存在瀏覽器記憶體 | **關著**，等第 31～33 步 |

**下一個分水嶺是第 31 步的 LINE 身分驗證。** 在那之前訂課功能不能打開 ——
沒有辦法確認「你是誰」，就沒有辦法讓你訂「屬於你的」課。

---

### 三個風險會在哪一步消失

| 風險 | 怎麼解除 | 狀態 |
|---|---|---|
| 1　免費方案專案被自動暫停 | 自動 | ✅ **第 20 步已解除** |
| 2　漏跑的日子不會補結算 | **要你決定** | ⬜ 第 28 步 |
| 3　每天的課都被自動取消 | 自動 | ⬜ 第 33 步（終於有人報名） |

## 十三、LINE 整合的關鍵認知

### 客人怎麼「登入」——做錯會漏光所有資料

❌ **錯**：LIFF 取得 `line_user_id`，前端直接拿它查資料庫
→ 任何人改一個字串就能查別人的資料

✅ **對**：
```
LIFF 取得 ID Token（LINE 簽章過的憑證）
   ↓ 送到 Supabase Edge Function
   ↓ 向 LINE 官方驗證
   ↓ 發一張 Supabase 登入憑證
之後所有查詢用 auth.uid() 判斷身分
```

**這一步沒做對，後面所有 RLS 都是裝飾。**

### 綁定流程

客人第一次開 LIFF → 輸入手機 → 比對既有名單 → 寫入 `line_user_id`。
`customers.phone` 設成 unique 就是為了這個。

### 預約介面不能真的長在對話泡泡裡

LIFF 會在 LINE 內部開一個網頁圖層蓋在對話上，客人全程不離開 LINE，但本質是網頁。
簡單查詢（如「剩幾堂」）可以用機器人純文字回覆，不用開網頁。

---

## 十四、預約系統原型（`line-prototype/`）

五個 HTML 原型：`A-entry`、`GT-booking`、`PGT-booking`、`PT-booking`、`pricing`。
另外兩支是接 Supabase 用的：`supabase-config.js`（連線設定）、`connection-test.html`（診斷工具）。

| 檔案 | 狀態 |
|---|---|
| `GT-booking.html` | ✅ 已接上 `public_schedule`，讀真實課表（**只能看，不能訂**） |
| `supabase-config.js` | ✅ 專案網址 ＋ Publishable key ＋ 建立連線 |
| `connection-test.html` | ✅ 診斷工具，連不上的時候先跑它 |
| `A-entry` / `pricing` | ⬜ 還是純靜態，沒有對外連線 |
| `PT` / `PGT-booking.html` | ⬜ 「確認預約」要改「送出需求」，寫進 `pt_requests` |
| 全部 | ⬜ 姓名手機要改成 LIFF 自動帶入 |

### GT-booking 改了什麼（2026-08-08）

**日期分頁從「週一～週日」改成真實日期。** 這不是偏好，是資料逼的 ——
`class_sessions` 存的是「2026-08-10 那一堂」，不是「每個週一」。
用星期分頁的話，「今天這堂已取消、下週同一堂還在」這個差別會整個消失。

其他：候補整套移除｜額滿改成「仍可報名，現場座位需與教練確認」｜取消的課轉灰顯示「本日未開課」。

**訂課按鈕停用中。** 腳本第一行有 `BOOKING_OPEN = false` 開關 ——
**第 31 步才能打開，而且必須先做完第 28、29 步（LINE 身分驗證與綁定）。**

### ☢️ 兩個不會報錯的坑

這兩個都花了時間才找到，因為它們**沒有任何錯誤訊息**：

**1. CSS class 撞名**
新加的 `.x` 撞到原檔的彈窗關閉鈕（32×32 圓形 flex），整段文字被壓成直排。
**在既有樣式裡加東西，class 名字一律加前綴**（`.rt-txt`、`.err-h`…）。
`.h` `.t` `.n` `.i` `.x` 這種單字母 class 特別容易撞。

**2. `const` 宣告的東西不會變成 `window` 的屬性**
```js
const fffDB = window.supabase.createClient(...);
fffDB          // ✅ 用得到
window.fffDB   // ❌ undefined
```
`connection-test.html` 寫 `fffDB` 所以能動，`GT-booking.html` 寫 `window.fffDB` 就掛掉。
**同一支設定檔、同一個資料夾，一個能用一個不能。**
解法是在 `supabase-config.js` 多寫一行 `window.fffDB = fffDB;`。

**3.（給未來的自己）假造得太淺的測試等於沒測**
當時用 `window.fffDB = {假物件}` 餵測試資料，等於**假造成「我以為的樣子」**，
所以測試通過、真實掛掉。正確做法是只假造最外層的 CDN，讓 `supabase-config.js` 真的跑一次。

## 十五、不可違反的規則

1. **每建一張資料表，立刻開 RLS 並寫至少一條規則**
2. **`service_role`／`sb_secret_` 金鑰絕不可出現在前端**
3. **前端隱藏不是安全**——真正的權限控管只在 RLS
4. **`employees` 和 `customers` 是所有模組的地基**
5. **檔名與路徑一律英文小寫加連字號**，不得有中文或空格
6. **不要在 GitHub 網頁上直接改檔案**——會造成雲端比本機新，下次 push 被拒
7. **塞資料的 SQL 一律加保險絲**，備份檔和 Supabase 分頁**兩邊都要**
8. **按 Run 之前先看按鈕寫 `Run` 還是 `Run selected`**
9. **不要憑記憶寫欄位名稱**——不確定就先 `select *` 看實際有哪些欄位
10. **☢️ 絕不 `drop extension pg_cron;`**
11. **☢️ `09-fix-dup` 只能反白保險絲那段測試，絕不整張跑**
12. **看到 `permission denied` 先問「這個身分本來就該進得去嗎」** —— 答案是「不該」的話，那不是錯誤，是正確答案。**絕不照錯誤訊息的 HINT 去 GRANT**，也不要按 `Debug with Assistant`。
13. **含個資的 SQL 絕不放進 `db/`** —— 那個資料夾是版控的，而且 repo 是公開的。搬遷產出的 SQL 一律輸出到 `migration-local/`，而且**先改 `.gitignore`，再產生檔案**。

---

## 十六、Git 操作

### commit 和 push 是兩件事

```
git add .        挑出這次要記錄的檔案，放進待處理的籃子
      ↓
git commit       把籃子裡的東西沖洗成一張「版本快照」，
                 貼進你電腦裡的相簿，旁邊寫一句為什麼
      ↓  ← 到這裡為止，東西都還在你家
git push         把相簿寄一份到 GitHub 的保險箱
```

**commit 完但沒 push，GitHub 上什麼都看不到。** 電腦這時候壞掉，紀錄一樣會消失。

這個設計是有用的：可以整個下午連續 commit 五次（每做完一小塊就記一次，方便日後回溯），收工時 push 一次把五筆一起送上去。而且沒網路也能 commit，因為它根本不需要連線。

### commit 訊息類型

`feat`（新功能）／`fix`（修 bug）／`docs`（文件註解）／`style`（外觀）／`chore`（雜項）

**寫「為什麼改」，不要寫「改了 index.html」**——Git 自己會記錄改了哪個檔案。

### 其他

`git pull` 只在換設備、或在 GitHub 網頁改過檔案時才需要。單機單人作業用不到。

---

## 附錄：2026-08-08 當晚的完整經過

給接手的人理解「為什麼會長成現在這樣」：

1. 先發現 05／06 分頁的 Results 面板還顯示重複資料 → 查證後確認那是**上次 Run 的舊快照**，實際資料是乾淨的 6／14／28
2. 安裝 pg_cron → 發現後台路徑已從 Database → Extensions 搬到 **Integrations → Cron**
3. 排程前先查函式是否存在 → 確認 `public.daily_class_job()`（無參數）
4. 註冊排程時把命令改成 `public.daily_class_job()` → 避免背景程序找不到函式
5. 用查詢向資料庫求證時區換算 → 確認 `0 16 * * *` 確實是台灣午夜
6. 連上本機專案資料夾 → 發現 `db/` **只有 00~05**，舊文件誤記為 00~06
7. 補齊 06／07／08／09，並為 05／06／09 加保險絲
8. 00:00 排程首次自動執行 → `succeeded` ✅
9. 查執行紀錄時踩到 `cron.job_run_details` 沒有 `jobname` 欄位的坑 → 改用 join
10. **發現保險絲只加在備份檔、沒加進 Supabase 分頁** → 補上，防護才真正生效

---

## 附錄二：2026-08-08 下午（第 15～17 步）

1. 盤點 `class_sessions`／`class_templates`／`employees` 欄位 → 發現 `coach_id` 可留空，檢視表必須用 `left join`
2. 盤點剩下四張表 ＋ `customer_credits` → 發現 `bookings.cancelled_at`，決定用它數人數而不是猜 `status` 存什麼字
3. 查 `class_sessions` 的 status 實際值 → `pending 26`／`cancelled 4`，確認風險 3 正在照規則運作
4. 建 `public_schedule` 檢視表（12 欄）＋ revoke all ＋ grant select to anon, authenticated
5. 驗收：`select *` 12 欄、`information_schema` 交叉確認 12 欄，沒有任何敏感欄位
6. 用 SQL Editor 右上角把 Role 切成 `anon` 實測 → 課表 30 筆看得到，三張原表全部 `permission denied`
7. 備份 `db/10-public-views.sql`，並順手把 `00-check` 整理成六段常駐工具 ＋ 一個臨時鷹架區

### 這一輪踩到的坑

- **貼了兩段長得幾乎一樣的盤點查詢**（只有 `in (...)` 裡的表名不同），反白時框錯一段，拿到上一次的結果卻沒發現。
  解法：在查詢裡加一個標籤欄位（例如 `'★A段' as 這是哪一段`），拿錯的話第一眼就看得出來。
- **`00-check` 分頁鷹架和常駐工具混在一起**，是上面那個坑的根因。現在用分隔線把兩區分開，鷹架跑完就刪。

---

## 附錄三：2026-08-08 傍晚（第 18～20 步 · 第二幕完成）

1. Publishable key 貼進 `supabase-config.js`，用 `connection-test.html` 驗三項全綠
2. `GT-booking.html` 接上 `public_schedule`：日期分頁改真實日期、移除候補、加「本日未開課」
3. 踩到 CSS class 撞名 → 全部改成加前綴
4. 踩到 `const` 不會掛到 `window` → 設定檔補上 `window.fffDB = fffDB;`
5. Table Editor 改一個課名 → 網頁重新整理跟著變（**證明這條線是活的，不是快照**）
6. push → GitHub Pages 自動部署 → 桌機和手機都確認看得到
7. **風險 1 解除**

### 這一輪學到的三件事

- **不會報錯的錯最貴。** 兩個坑都沒有錯誤訊息，只有「看起來怪怪的」。
- **假造得太淺的測試，測到的是自己的想像。** 假貨要盡量接近真貨的形狀。
- **一個猜錯但指對方向的錯誤訊息，比一片空白有用得多。** 畫面上那句「supabase-config.js 沒有載入」其實猜錯了（檔案有載入，只是名字查不到），但它把範圍縮到「設定檔與主程式之間的接口」，一看就知道去哪裡找。

### 順帶記一筆：`00-check` 不要放會寫入的 SQL

那張分頁的身分是「純查詢，可以隨便重複執行」—— 放一支 `update` 進去，這句話就不再是真的，
而你以後會**依賴**那句話才敢整張按 Run。臨時要寫入，開一張 `zz-` 開頭的拋棄式分頁，用完刪掉。

---

## 附錄四：營運規則（薪資／優惠／搬遷決定）

> 這一節記的是**只存在於老闆腦子裡的規則**。
> 它不是技術文件 —— 但少了它，第 39 步的點名核銷和之後的 ERP 薪資模組都寫不出來。
> 來源：Jerec 於 2026-08-08 口述，當場用程式驗算過，10/10 相符。

### 1. 團體課（GT）鐘點費 —— 依單堂實到人數

| 人數 | 教練鐘點費 | 人數 | 教練鐘點費 |
|---:|---:|---:|---:|
| 0 | 0（未開課） | 6 | 800 |
| 1 | 200 | 7 | 900 |
| 2 | 400 | 8 | 1000 |
| 3 | 500 | 9 | 1100 |
| 4 | 600 | 10 | 1200 |
| 5 | 700 | | |

**公式**

```
payout(0) = 0
payout(1) = 200
payout(n) = 200 + 100 × n      （n ≥ 2）
```

第 1 人 200，第 2 人再 +200，第 3 人起每多一人 +100。

> ⚠️ **`n` 是「實到人數」，不是「報名人數」。**
> 所以第 39 步的點名核銷不只是扣客人的課 —— **它同時是教練薪資的原始憑證**。
> 點名漏掉一個人，教練就少領 100 元。

### 2. 私人課（PT／私人團體班）抽成 —— 依當月累積業績

- 業績 = 當月**單堂課程費用**的加總
- 累積業績 **未超過 80,000**：教練 4 ／ 諧動 6
- 累積業績 **超過 80,000**：教練 5 ／ 諧動 5
- **跨越門檻的那一堂，整堂算 5:5**（不拆帳）
- 門檻**每月重算**

**驗算範例**（一堂 1200、當月 80 堂）

```
第 1～66 堂   累積 79,200（未過門檻）  → 1200 × 0.4 = 480   480 × 66 = 31,680
第 67 堂      累積 80,400（跨過門檻）  → 整堂算 5:5
第 67～80 堂  共 14 堂                → 1200 × 0.5 = 600   600 × 14 =  8,400
                                                          當月薪資 = 40,080
```

**❓ 兩件還沒問清楚的事**（做薪資模組前一定要補）

1. 那個 80,000 的門檻，**只算 PT 業績，還是 PT + GT 一起算**？
2. **私人團體班**一堂的「課程費用」怎麼認定 —— 是總價，還是每人各計？

### 3. 團體課購課優惠：買 10 堂送 2 堂

- 送的 2 堂**可以給購課者本人用，也可以送給非購課者**（親朋好友體驗）
- 贈送額度用完之後仍要帶人來體驗 → **直接扣購課者本人的剩餘堂數**

> ⚠️ **舊系統的 `PassLedger` 沒有把這 2 堂分開記**（只有單一 `balanceAfter`）。
> 「贈送額度用完了才動到本人堂數」這條規則，過去只存在於老闆的判斷裡。

### 4. 搬遷的四個決定（2026-08-08 定案）

| # | 決定 | 為什麼 |
|---|---|---|
| ① | 帶朋友來體驗 → **體驗客建檔，一人一列**。`bookings` 加 `paid_by_customer_id` 記「扣誰的卡」 | 舊系統的 `headCount` 把 5 個人壓成 1 筆 → **鐘點費會算成 200 而不是 700**。人數錯，薪水就錯。而且體驗客是最可能成交的名單，壓成數字就丟了 |
| ② | 買十送二 → **帳本拆兩列**（`purchase +10`、`bonus +2`） | 餘額還是 12，扣課邏輯一行都不用改，但送出去的成本和贈送帶來的轉換率查得出來。舊資料分不出來，一律標 `purchase` |
| ③ | 教練鐘點費 `payout` → **不搬，改用點名人數算** | 它是衍生資料，跟人數一對一。**能算出來的東西就不要另外記一份** —— 記兩份，兩份遲早會對不起來（跟 `db/ 00~06` 是同一個病） |
| ④ | 舊 `LessonInstances` **只有團體課** | 所以 `payout = 1200` 就是「10 個人」，沒有第二種解釋，反推規則成立 |
| ⑤ | 全面加上**商品別 `product`**（`GT`／`PT`／`PGT`／`RT`，預設 `GT`） | `class_sessions` 和 `credit_ledger` 兩張都加。現在加是四行 SQL；資料搬進來之後再加，每一列都要回頭補標 |
| ⑥ | **堂數分錢包** —— 團體課堂數不能上私人課 | `customer_credits` 改成「每人每種商品各一個餘額」。不分的話系統會覺得拿 GT 堂數上 PT 完全合理 |
| ⑦ | 教練薪資第一階段**只算 GT 人頭費** | 資料來源就是點名，不需要額外輸入。PT 的 8 萬門檻抽成要等每一堂 PT 都進系統，那是 ERP 那一段 |

| ⑧ | **搬遷策略改成「混合版」**：GT 整套搬、PT／PGT 自然迭代、RT 不搬 | 兩邊資料品質差太多。GT 有獨立 `members` 表、手機 81/81 唯一、帳本自洽 → 搬它幾乎沒有額外成本，還順便帶進歷史。PT／PGT 只有一張手工流水帳，沒有客人表也沒有手機 → 重建歷史的成本遠大於價值，而且 2022 年的客人一大半早就不來了 |
| ⑨ | PT／PGT 走**「平行週」**：舊系統續跑 7 天，前 6 天建人、第 7 天才填餘額 | 餘額是移動標靶 —— 那七天還有人買課上課。人不會變，數字會變，所以分開做 |

> 決定 ①～④ 於 2026-08-08 晚間定案（搬遷相關）。
> 決定 ⑤～⑦ 是同晚稍後、確認商品線包含 **PT（私人教練課、私人團體班）** 和 **RT（場地租借）** 之後補的。
> 決定 ⑧～⑨ 是 2026-08-09 討論「要不要整套搬歷史」之後的結論。
> **第一階段的明確範圍：團體課預約系統 ＋ 後台團體課 ＋ GT 教練鐘點費計算。**
> PT／RT 只預留欄位，不寫功能。

### 4-1. 搬 / 不搬 一覽（決定 ⑧ 的細節）

| | 搬什麼 | 不搬什麼 |
|---|---|---|
| **GT** | 81 人、四年堂數流水、上課歷史、預約紀錄 | — |
| **PT／PGT** | 只搬「**還有剩餘堂數**」的人：姓名 ＋ 手機 ＋ 一筆期初結轉 | 四年流水明細、上課歷史、餘額歸零的人 |
| **RT** | — | 全部。那份 Excel 只有收款日期和金額，沒有時段也沒有租客 |

**刻意接受的三個代價**（只影響 PT／PGT，GT 不受影響）：

1. 系統查不到切換前的 PT 上課紀錄 → **舊系統設唯讀留三個月**，去那裡查
2. 客人在 LINE 看不到切換前的 PT 課
3. PT 抽成薪資報表從切換日才開始（過去的月薪早就發過了）

> 期初結轉那一筆長這樣：`reason='adjust'`、`product='PT'` 或 `'PGT'`、`note='系統上線前結轉'`。

### 5. 舊系統盤點結果（2026-08-08，離線工具 `tools/legacy-inventory.html`）

**健康的部分**

- **帳本自洽**：68 個有帳的人，每人 `delta` 加總 = 最後記錄的餘額 → 舊帳可整份直接搬
- **手機 81／81 唯一**，無重複、無空白
- **無孤兒帳列**：每一筆流水都對得到人

**要處理的差異**

| 差異 | 處理方式 | 狀態 |
|---|---|---|
| 舊系統有容量 12 的課，我們 14 堂全是 10 | **現況全部 10**，那個 12 是歷史值 → 搬歷史時**照舊值搬**，不要改成 10 | ✅ 08-09 確認 |
| 程度舊系統寫全字、我們用縮寫 | `beginner→beg`／`intermediate→int`／`advanced→adv`，一對一無例外 | ✅ 08-09 確認 |
| 舊 `Classes` 只有 5 位教練，沒有簡基城 | **簡基城不帶團體課**。留在 `employees`（PT 用），不出現在任何 GT 課表 | ✅ 08-09 確認 |
| 81 人中 13 人完全沒有帳本紀錄 | 確認是「0 堂」還是「沒建帳」 | ⬜ 待辦 |
| `assignedCoach`、`email` 幾乎全空 | 不搬 | ✅ 已決定 |

> 2026-08-09 逐堂核對過現行 14 堂：**沒有停開的課，時間／教練／程度全部相符，資料庫一筆都不用改。**

**⚠️ 最重要的一條**

> **81 個人裡只有 4 個人有 `lineId`。**
> 第 32 步的手機綁定**完全不能跳過** —— 77 個人要重新綁一次。
> 切換日的公告要把這件事寫清楚，不然客人會以為系統壞了。

### 6. 舊系統的欄位取值（供對照用）

- `Bookings.status`：`booked` ／ `cancelled` ／ `settled`
- `PassLedger.type`：`checkin` ／ `manual_deduction` ／ `topup`

> 第 19 步當時擔心的「status 可能有第三種值」，在舊系統這裡有了現實的命名前例。
> 前端「認不得的值就照原樣顯示」這個寫法，事後看是對的。

---

## 附錄五：2026-08-09 凌晨（第 23～24 步 · 商品別與公開課表的門）

### 這一輪做了什麼

| 步 | 內容 |
|---|---|
| 23 | `class_sessions.product`、`credit_ledger.product`、`bookings.paid_by_customer_id`；重建 `customer_credits`；`pt_requests.kind` 改名 `product`；兩條 RLS |
| 24 | `public_schedule` 加 `where s.product = 'GT'` |

### 六件學到的事

**1. 規則 9 當場救了一次。**
原本計畫要在 `credit_ledger` 加一個 `kind` 欄位（`purchase`／`bonus`／…）。
照規則 9 先 `select` 實際欄位，才發現**它本來就有 `reason`**，值域正是
`purchase / bonus / class / adjust / refund`。
再加 `kind` 就是「兩個欄位講同一件事」—— 跟 `db/ 00~06` 那個坑同一個病。
**憑記憶寫欄位不只是會打錯字，是會憑空長出多餘的設計。**

**2. 驗證 SQL 漏了 `from`，整張 rollback —— 而這證明了交易是有效的。**
`★B` 那段 `select ... count(*) filter (where paid_by_customer_id = customer_id)` 少寫 `from public.bookings`，
跳 `column "paid_by_customer_id" does not exist`。
**看起來像「欄位沒加成功」，其實是「查詢寫錯」** —— 這兩件事的錯誤訊息一模一樣。
事後查欄位數＝0，確認整張退回，資料庫完全沒被動到。

**3. 從這一步開始，每一支 SQL 都先在本機 PostgreSQL 跑過再給人。**
在容器裡裝 PostgreSQL 16、照 `db/01~04` 建出一模一樣的七張表，把 `11` 整支跑兩次
（確認重複執行安全），才交出去。
上一版只用眼睛看，結果就是上面第 2 點。

**4. `customer_credits` 和 `public_schedule` 是方向相反的兩張檢視表。**

| | `public_schedule` | `customer_credits` |
|---|---|---|
| 要不要繞過 RLS | **故意繞過**（要端出教練 `display_name`） | **絕對不能繞過**（每個人只能看自己的餘額） |
| 寫法 | 預設（definer） | `with (security_invoker = true)` |
| Advisors 會不會叫 | 會，而且不要理它 | 不會 |

實測過：`security_invoker=false` 時，一個客人查到 **2 筆**（含別人的餘額）；改成 `true` 之後只查到 **1 筆**。

> **以後每建一張新的檢視表，都要重問一次「這張該不該繞過 RLS」。**
> 沒有預設答案。

**5. 「改之前 vs 改之後」的對照實驗，比「全綠」更有價值。**
第 24 步的攻擊測試先在**還沒加 `where`** 的狀態下跑了一次，親眼看到假的 PT 出現在公開課表上（② 1 筆、③ 33 vs 32）。
加了 `where` 再跑，變成 0 和 32 vs 32。
**如果一開始就全綠，你只會知道「現在沒問題」，不會知道「那行 `where` 真的在擋東西」。**

**6. 測試用的 `delete` 要用 `id`，不要用字串比對。**
第一版寫 `where title like '★測試用-%'`。
壓力測試：先塞一堂真的叫「★測試用-…」的課再跑測試 —— **它被誤刪了**。
改成把新增的 `id` 存進暫存表、`delete` 只認 `id` 之後，同名的真課安然無恙。
而且刪之前先報一次「這個 `where` 會打到幾列（必須是 1）」，在按下去之前就看得到。

### 留給第 33 步的一個地雷

`credit_ledger` 的政策裡有
`select 1 from employees where auth_user_id = auth.uid()`。
`customer_credits` 加了 `security_invoker = true` 之後，這一句是**用客人的身分**去查 `employees` 的 ——
客人沒有讀取權，會直接跳 `permission denied`，**不是回 0 筆，是整句查詢失敗**。

正解不是把 `employees` 開給客人（那等於拆掉第二幕蓋的牆），
而是把這類判斷包成 `security definer` 的小函式，只回傳 `true`/`false`。
本機 PostgreSQL 16 實測確認會這樣。
