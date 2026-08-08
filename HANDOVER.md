# FFF 專案交接紀錄

> 最後更新：2026-08-08 下午
> 開新對話時附上這份即可接續。
>
> 📌 這是一份**持續更新的活文件**，跟著程式碼一起版控。
> 不要另存 `-20260808`、`-v2` 這種檔名 —— 直接改這一份就好，
> Git 會替你記得每一個歷史版本。要看舊版：`git log HANDOVER.md`

---

## ⚡ 這一版新增了什麼（給接手的人快速對焦）

```
✅ 盤點完七張表的全部欄位（第二幕開工前的必要功課，不再憑記憶寫欄位名）
✅ 建好 public_schedule 公開課表檢視表 —— 對外唯一開放讀取的窗口（第六節）
✅ 用 anon 身分實測通過：課表看得到，employees／customers／class_sessions 全部擋住
✅ db/ 補到 11 支，00→10 可完整重建
⚠️ 三個已知風險（第十一節）仍然全部都在，一個都還沒解除
☢️ 第六節新增兩個「絕對不要做」—— 那兩件事都會安靜地把資料庫打開，不會報錯
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

---

### 公開檢視表 `public_schedule`（2026-08-08 新增）

除了 `customer_credits`，現在還有第二個檢視表 —— 這是**對外唯一開放讀取的對象**。

| 項目 | 內容 |
|---|---|
| 建立於 | `10-public-views` 分頁／`db/10-public-views.sql` |
| 欄位數 | 剛好 12 欄 |
| 誰讀得到 | `anon`、`authenticated`（已 grant select） |
| 資料來源 | `class_sessions` ＋ `employees`（left join）＋ `bookings`（count） |

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

## 九、db/ 備份（十一支，可完整重建）

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
└── 10-public-views.sql          ← 公開課表檢視表
```

**現在如果資料庫整個消失，可以從這十一支照 00→10 的順序重建。** 這件事在 2026-08-08 之前是做不到的。

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

## 十一、⚠️ 三個已知風險（都還沒處理）

### 1. 免費方案專案會被自動暫停

Supabase 免費方案的專案，**連續約一週幾乎沒有外部請求就會被自動暫停**。專案一暫停，排程也不會跑 —— 課堂不會長、結算不會做，而且不會有人通知你。

現在前端還沒接上 Supabase，這個資料庫沒有任何外部流量，所以風險是真實存在的。
**等 GT 預約頁接上、有客人在用之後就自然解除。**

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

> 📌 完整版是 `fff-roadmap-steps.html`（跟這份文件一起版控，用瀏覽器打開）。
> 那份有每一步的**完成判準**和可收合的說明；這一節是給接手的人快速對焦用的摘要。
> **兩邊要一起改**，不要只改一邊。

### 進度：17 / 36

第一階段的範圍是「官網 ＋ 能放在 LINE 上的客戶預約系統」。ERP 是終極目標，但刻意不編號、不排序。

```
第一幕  搭後台            ✅ 14 / 14   全部完成
第二幕  接電              🔨  3 / 6    ← 現在在這裡
第三幕  讓觀眾入座        ⬜  0 / 5
第四幕  開大門（LINE）    ⬜  0 / 7
第五幕  讓教練上工        ⬜  0 / 4
─────────────────────────────────────
地平線  ERP               🌫 不編號、不排序
```

---

### ⚠️ 順序改了：為什麼「客人資料匯入」被往後挪

舊版這一節寫的下一步是「客人資料匯入」。**現在改成先做「前端唯讀接上 Supabase」。**

三個理由：

1. **管線沒通之前，匯入再多客人，畫面上也不會多出任何東西。** 做完會不知道自己做對了沒有。
2. **接電這一幕完全不需要任何客人資料。** 課表範本和教練都已經在資料庫裡了，直接讀出來就有畫面。
3. **做完當場解掉第十一節的風險 1。** 免費方案一週沒有外部請求就會被自動暫停，暫停後 pg_cron 也不出勤，而且不會有人通知你。前端接上＝有流量＝這個風險自己消失。

客人資料匯入沒有被刪掉，它排在第三幕（第 21～25 步），不會漏。

---

### 第一幕：搭後台 ✅ 14 / 14

蓋道具間、請場記。這一幕整幕演完了。

- ~~01　定案預約系統的業務規則~~
- ~~02　開 Supabase 專案（東京機房、Free 方案）~~
- ~~03　建七張資料表，每張建完立刻開 RLS 並寫規則~~
- ~~04　建 `customer_credits` 檢視表~~
- ~~05　塞進 6 位教練~~
- ~~06　塞進 14 堂週課表範本~~
- ~~07　修好重複塞資料造成的 12 教練／28 範本~~
- ~~08　寫 `daily_class_job()` 函式~~
- ~~09　安裝 pg_cron（Integrations → Cron，路徑已搬家）~~
- ~~10　排程前先確認函式真的存在~~
- ~~11　註冊排程 `0 16 * * *`，首次自動執行成功~~
- ~~12　把十支 SQL 全部備份進 `db/`~~
- ~~13　為 05／06／09 加保險絲，備份檔和 Supabase 分頁兩邊都裝~~
- ~~14　官網 v1.3.1 上線；`fff-platform` 交給 Git 版控；五個預約頁原型完成~~

> **這一幕換到了什麼**：一個關掉電腦也照樣每天半夜自己運作的資料庫、一個上線中的官網、一份能完整重建一切的備份，還有一份跟著程式碼版控的交接紀錄。

---

### 第二幕：接電 🔨 3 / 6　← 現在做這個

把舞台和後台接起來。**整個專案的分水嶺。** 這六步完全不需要任何客人資料。

- ~~15　先 `select *` 看 `class_sessions` 實際有哪些欄位~~
  - 盤完七張表全部欄位。三個發現：`class_sessions` 已複製範本欄位（檢視表不必碰 `class_templates`）、`employees` 有四個欄位絕不能外流、`coach_id` 可留空所以必須 `left join`。
- ~~16　建一張只含安全欄位的公開課表檢視表~~
  - `public_schedule`，剛好 12 欄。完整說明與兩個「絕對不要做」見**第六節**。
- ~~17　開一條「未登入的人也能讀這張檢視表」的規則~~
  - grant 已寫在 `10-public-views.sql` 裡。用 Role 切 `anon` 實測：課表 30 筆看得到，`employees`／`customers`／`class_sessions` 三張全部 `permission denied`。
- ⬜ **18　把 Project URL 和 Publishable key 放進前端**　← 下一步
  - ⚠️ 再三確認貼的是 `sb_publishable_...`。開頭是 `sb_secret_` 就停下來重拿。
  - **完成判準**：在檔案裡搜尋 `sb_secret`，一個字都找不到。
- ⬜ 19　`GT-booking.html` 改成讀真實課表（只能看，不能訂）
  - 順手改掉：移除候補邏輯、額滿改「可報但先提醒」、加「今日未開課」狀態。
  - ⚠️ `class_sessions.status` 目前只看得到 `pending` 和 `cancelled`，是因為還沒有任何一堂課成立過。**前端不能照現在看到的兩個值寫死邏輯** —— 第 30 步之後會冒出第三種值。要寫成「不認得的狀態就照原樣顯示」。
  - **完成判準**：去 Supabase 把某一堂課的名稱改一個字，重新整理網頁，畫面跟著變。
- ⬜ 20　推上 GitHub Pages，用手機實測
  - **完成判準**：手機瀏覽器看得到真實課表。**同時風險 1 自動解除。**

---

### 第三幕：讓觀眾入座 ⬜ 0 / 5

把客人名冊搬進來。

- ⬜ 21　整理現有客人名單，先確認手機沒有重複
  - `customers.phone` 是 unique **而且 NOT NULL** —— 名單裡沒有手機的人要先處理掉，不然整批匯入會失敗。
- ⬜ 22　**【要你決定】** 舊有「剩餘堂數」怎麼變成 `credit_ledger` 的第一筆
  - (A) 一次性期初餘額，每人一筆「系統上線前結轉 N 堂」
  - (B) 照實際購買紀錄逐筆補
  - 建議 A，並在備註欄寫清楚結轉日期 —— B 需要的舊資料多半也不完整。
- ⬜ 23　寫匯入 SQL，匯入 `customers`（檔名 `11-seed-customers.sql`）
  - ⚠️ 這是「塞資料」的 SQL，**一定要加保險絲**，備份檔和 Supabase 分頁兩邊都要。
  - **完成判準**：整張分頁再按一次 Run，它報錯中止、一筆都沒重複進去。
- ⬜ 24　寫入期初堂數，核對 `customer_credits` 對不對
- ⬜ 25　**【要你決定】** 風險 2：漏跑的日子要不要補結算
  - 技術上只是把 `=` 改成 `<=`，五秒鐘。但那是商業決定：三天前的課現在才判定「取消」合不合理？
  - **現在還沒客人，是做這個決定最沒有代價的時機。**

---

### 第四幕：開大門（LINE）⬜ 0 / 7

客人不會記得網址，但他們每天都開 LINE。

- ⬜ 26　開 LINE 官方帳號 ＋ LINE Developers 的 Provider／Channel
- ⬜ 27　建 LIFF App，指向 GitHub Pages 上的預約頁
- ⬜ 28　**寫 Edge Function：驗 LINE 身分，發 Supabase 憑證**
  - **整個專案技術上最關鍵的一步**，細節見第十三節。
  - **完成判準**：把請求裡的 ID 換成別人的，系統拒絕你。
- ⬜ 29　手機綁定流程（輸入手機 → 比對名單 → 寫入 `line_user_id`）
- ⬜ 30　打開真正的訂課（寫入 `bookings`、取消時限靠 RLS 擋、額滿只提醒）
  - **完成判準**：用手機訂一堂課，Supabase 裡真的多一筆。**同時風險 3 自動解除。**
- ⬜ 31　PT／PGT 頁改成「送出需求」，寫進 `pt_requests`
- ⬜ 32　設定 LINE 圖文選單

---

### 第五幕：讓教練上工 ⬜ 0 / 4

前台櫃檯數位化。客人端跑順之後才做，**也是往 ERP 的第一步**。

- ⬜ 33　六位教練註冊帳號，填回 `employees.auth_user_id`（目前都是空的）
- ⬜ 34　課後點名核銷頁：扣課寫進 `credit_ledger`，缺席不扣課
- ⬜ 35　教練端的私人課需求處理（`pt_requests` 待處理清單）
- ⬜ 36　課前提醒推播（Edge Function ＋ LINE Messaging API）
  - ⚠️ 這一條同時是**架構失效警訊** —— 需要頻繁自動通知，就代表 GitHub Pages 這套開始不夠用了。

---

### 地平線：ERP 🌫

刻意不編號、不排順序。細節取決於預約系統跑順之後才會發現的事，現在猜錯的機率很高。

- ✳ 金流與電子發票　—　一碰就必須搬離 GitHub Pages，條款明確禁止
- ✳ 教練排班與薪資　—　建在 `employees` 上。離職改 `is_active` 不刪除，就是為了這一天
- ✳ 營收與出席報表　—　資料其實從 pg_cron 上工那天就開始累積了
- ✳ 會員關係與續約　—　建在 `customers` 上。`credit_ledger` 本身就是消費行為紀錄
- ✳ 器材與庫存　—　目前完全沒動，也看不出急迫性
- ✳ 多店擴張　—　真要走這條，資料表得先加「場館」欄位，越晚加越痛

> **有一件事已經做完了**：ERP 的每一個模組最後都會長在 `employees` 和 `customers` 這兩張桌子上，
> 而那塊地基在第一幕就打好了。這是往 ERP 走最重要的一步，而它已經完成。

---

### 三個風險會在哪一步消失

| 風險 | 怎麼解除 | 在第幾步 |
|---|---|---|
| 1　免費方案專案被自動暫停 | 自動 | 第 20 步（有外部流量了） |
| 2　漏跑的日子不會補結算 | **要你決定** | 第 25 步 |
| 3　每天的課都被自動取消 | 自動 | 第 30 步（終於有人報名） |

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

## 十四、預約系統原型（已有，但要改）

我做了五個 HTML 原型：`A-entry`、`GT-booking`、`PGT-booking`、`PT-booking`、`pricing`。

**目前資料只存在瀏覽器記憶體**，重新整理就消失，沒有任何對外連線。

### 要改的地方

| 檔案 | 改什麼 |
|---|---|
| `GT-booking.html` | 移除候補邏輯；額滿改「可報但先提醒」；加「今日未開課」狀態 |
| `PT`／`PGT-booking.html` | 「確認預約」改「送出需求」 |
| 全部 | 姓名手機改成 LIFF 自動帶入；資料寫進 Supabase |

---

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
