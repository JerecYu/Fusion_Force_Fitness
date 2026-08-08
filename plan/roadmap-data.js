/* ═══════════════════════════════════════════════════════════════════════
   roadmap-data.js  —  FFF 專案進度的「單一真相來源」

   ┌──────────────────────────────────────────────────────────────────┐
   │  要更新進度，只改這一個檔案。                                       │
   │                                                                  │
   │  把某一步的  done: false  改成  done: true  ，然後存檔。            │
   │                                                                  │
   │  這些東西會自己跟著變，你完全不用手動改：                            │
   │    · 進度條和「17 / 36」那個數字                                   │
   │    · 每一幕的「3 / 6」計數                                        │
   │    · 路線圖上綠色實線的長度                                        │
   │    · 紅色定位釘會自動移到下一個還沒做的步驟                          │
   │    · 「現在只做這一件事」那張卡                                     │
   │    · 架構地圖的「你在這裡」三格                                     │
   │                                                                  │
   │  ⚠️ 這就是為什麼要抽出來：交接紀錄踩過「文件說 db/ 有 00~06、        │
   │     實際只有 00~05」的坑。數字分散在多個地方，遲早會對不起來。        │
   │     現在只有一個地方寫著真相。                                      │
   └──────────────────────────────────────────────────────────────────┘

   欄位說明
     n        步驟編號（連續，不要跳號）
     t        標題（一行講完）
     where    在哪裡做：SQL / 前端 / Git / Supabase / LINE後台 / 決定
     done     true = 已完成，會被劃掉
     kind     'decide' = 這一步是商業決定，不是技術動作（顯示成橘色）
     summary  可收合註解的標題
     body     可收合註解的內容（可用 HTML）
     ck       完成判準（怎麼知道自己做完了）
     warn     警告框（會用橘色強調）
   ═══════════════════════════════════════════════════════════════════════ */

window.FFF_ROADMAP = {

  meta: {
    updated: '2026-08-08 傍晚',
    phaseName: '第一階段：官網 ＋ LINE 預約系統',
    repo: 'https://github.com/JerecYu/Fusion_Force_Fitness'
  },

  /* ── 五幕 ────────────────────────────────────────────────────── */
  acts: [

    /* ══════════ 第一幕 ══════════ */
    {
      key: 'a1', place: '後台道具間', no: '第一幕', name: '搭後台', theatre: '＝ 蓋道具間、請場記',
      note: '這一幕整幕演完了。以下每一條都劃掉，代表你不用再回頭看 —— 但萬一資料庫整個消失，<code>db/</code> 裡的 SQL 照 00→10 跑一遍就能重建。',
      milestone: {
        title: '▲ 第一幕結束 — 你現在擁有的',
        text: '一個關掉電腦也照樣每天半夜自己運作的資料庫，一個上線中的官網，一份能完整重建一切的備份，還有一份跟著程式碼版控的交接紀錄。<b>這是很紮實的地基。</b>'
      },
      steps: [
        { n:1, t:'定案預約系統的業務規則', where:'決定', done:true,
          summary:'當時定了哪九條',
          body:'取消期限課前 1 小時｜報名截止是當天 00:00 <b>結算</b>（不是關閉報名）｜缺席不扣課｜扣課時機在課後由教練現場點名核銷｜同時預約無上限｜剩 0 堂也能預約，到現場再課購｜不做候補｜額滿不硬擋，跳提醒「已額滿，現場座位需與教練確認」｜私人課是客人送需求、教練聯繫敲定，不是預約。' },

        { n:2, t:'開 Supabase 專案', where:'Supabase', done:true,
          summary:'當時的設定',
          body:'組織 <code>JerecYu</code>、專案 <code>fff-platform</code>、Free 方案、Region 東京。<br>Enable Data API ✅｜Automatically expose new tables ❌｜Enable automatic RLS ✅<br>金鑰存在你的密碼管理工具，<b>不在專案資料夾裡</b>。' },

        { n:3, t:'建七張資料表，每張建完立刻開 RLS 並寫規則', where:'SQL', done:true,
          summary:'七張桌子與規則數',
          body:'<code>employees</code>（2 條，能登入，點名核銷用）｜<code>customers</code>（3 條，含 <code>line_user_id</code>）｜<code>class_templates</code>（1 條）｜<code>class_sessions</code>（2 條）｜<code>bookings</code>（5 條）｜<code>credit_ledger</code>（3 條）｜<code>pt_requests</code>（4 條）' },

        { n:4, t:'建 customer_credits 檢視表', where:'SQL', done:true,
          summary:'為什麼存流水帳不存數字',
          body:'剩餘堂數＝流水帳加總。客人問「為什麼少一堂」要查得到，扣錯要追得回。存單一數字就沒有這個能力了。' },

        { n:5, t:'塞進 6 位教練', where:'SQL', done:true,
          summary:'是哪六位',
          body:'簡基城、Jerec（owner）、Jessica、VC、Peter、Johnson。<br><code>auth_user_id</code> 目前都是空的，等教練真的註冊帳號才會填（第 33 步）。<br>離職改 <code>is_active</code> 不刪除 —— 刪掉會讓歷史課堂失去教練資訊。' },

        { n:6, t:'塞進 14 堂週課表範本', where:'SQL', done:true,
          summary:'週課表內容',
          body:'一 09:00 TRX綜合雕塑／12:30 功能性核心／19:30 循環有氧　·　二 09:00 功能性核心／12:30 基礎運動養成／18:30 交叉肌力訓練　·　三 12:20 間歇有氧　·　四 10:00 交叉肌力訓練／19:00 基礎運動養成　·　五 12:20 交叉肌力訓練／19:00 交叉肌力訓練　·　六 11:00 功能性核心／16:00 交叉肌力訓練　·　日 11:00 循環有氧' },

        { n:7, t:'修好重複塞資料造成的 12 教練／28 範本', where:'SQL', done:true,
          summary:'怎麼發現、怎麼修的',
          body:'05 和 06 被重複執行過。用 <code>09-fix-dup</code> 清空重建，回到乾淨的 6／14。',
          warn:'<b>順便學到的：</b>Results 面板顯示的是「上次按 Run 的快照」，不是即時資料。它像相簿裡的舊照片，不是一扇窗。<b>千萬不要為了讓 Results 看起來乾淨，而回去按 05／06 的 Run</b> —— 那會把畫面「修好」，同時把資料再弄壞一次。' },

        { n:8, t:'寫 daily_class_job() 函式', where:'SQL', done:true,
          summary:'它每天做什麼',
          body:'① 往前補課堂到未來 14 天　② 對「今天」的課做成立判定　③ 對「今天」無人報名的課做取消。<br><b>課堂數量不再是固定的 28</b>，排程每天往前補，所以這個數字會浮動。看到它變動是正常的，不是出錯。' },

        { n:9, t:'安裝 pg_cron', where:'Supabase', done:true,
          summary:'路徑已經搬家了',
          body:'<b>不再是 Database → Extensions</b>（舊文件寫的路徑）。<br>現在走：<b>Integrations → Cron → Install integration</b>（右上角綠色按鈕）。裝好後左側 <code>INSTALLED</code> 數字會 +1。' },

        { n:10, t:'排程前先確認函式真的存在', where:'SQL', done:true,
          summary:'為什麼這一步不能跳',
          body:'<b>排程失敗的時候是安靜的。</b>名字打錯的話，排程照樣建得起來、<code>active</code> 照樣是 true，但每天半夜撞牆，不會有人通知你。可能兩週後才發現課表沒長。<br>查詢 <code>pg_proc</code> 應該回傳 1 筆：<code>public ｜ daily_class_job ｜（無參數）</code>' },

        { n:11, t:'註冊排程 0 16 * * *，首次自動執行成功', where:'SQL', done:true,
          summary:'兩個當時想清楚的細節',
          body:'<ul><li><b>為什麼是 16 不是 0</b>：資料庫排程用 UTC，台灣快 8 小時。寫 <code>0 0 * * *</code> 實際會在台灣早上 8 點才跑，那時早課已經開始。已用查詢向資料庫求證過，不是憑算術</li><li><b>為什麼函式前面加 <code>public.</code></b>：半夜由背景程序執行，那個環境找哪些 schema 不一定跟 SQL Editor 一樣。寫上等於直接給門牌號碼</li></ul>首次自動執行：2026-08-08 00:00:00（台灣時間，分秒不差）→ <code>succeeded</code>',
          warn:'☢️ <b>絕對不要下 <code>drop extension pg_cron;</code></b> —— 那會把所有排程連同設定一起永久刪除，救不回來。要停用請用 <code>select cron.unschedule(\'daily-class-job\');</code>' },

        { n:12, t:'把十支 SQL 全部備份進 db/', where:'Git', done:true,
          summary:'備份了哪些、怎麼匯出的',
          body:'<code>00-check-rls</code>／<code>01-employees</code>／<code>02-customers</code>／<code>03-classes-bookings</code>／<code>04-credits-pt</code>／<code>05-seed-employees</code>／<code>06-seed-class-templates</code>／<code>07-daily-job</code>／<code>08-cron</code>／<code>09-fix-dup</code><br><br><b>資料庫整個消失也重建得回來。</b>這件事在 2026-08-08 之前是做不到的（當時只有 00～05，舊文件誤記為 00～06）。<br><b>怎麼匯出</b>：打開分頁 → 編輯區 <code>Ctrl+A</code> → <code>Ctrl+C</code> → 貼進本機檔案。',
          warn:'右上角的 <code>Export</code> 按鈕<b>不要用</b>，它匯出的是下方 Results 的 CSV，不是 SQL。' },

        { n:13, t:'為 05／06／09 加保險絲，備份檔和 Supabase 分頁兩邊都裝', where:'SQL', done:true,
          summary:'保險絲是什麼、為什麼要裝兩邊',
          body:'在塞資料的 SQL <b>最上面</b>加一段檢查，已經有資料就直接中止並報錯，一筆都不會插進去。<br>原理：Postgres 把一次送出的敘述當成一個整體，中間任何一步出錯，前面做過的全部退回，不會做半套。<br><br><b>為什麼兩邊都要裝</b>：只有備份檔有保險絲＝防護等於零。沒有人會不小心去執行備份檔，會被手滑按到 Run 的永遠是 Supabase 分頁。<b>保險絲要裝在槍上，不是裝在保險箱裡。</b>',
          warn:'<b>唯一漏洞</b>：它只在「整張分頁一起執行」時有效。如果用 <code>Run selected</code> 只選下面的 insert，就繞過去了。所以「按 Run 之前先看按鈕」這個習慣還是得留著，兩層是互補的。' },

        { n:14, t:'官網 v1.3.1 上線；fff-platform 交給 Git 版控；五個預約頁原型完成', where:'Git', done:true,
          summary:'五個原型是哪些',
          body:'<code>A-entry</code>／<code>GT-booking</code>／<code>PGT-booking</code>／<code>PT-booking</code>／<code>pricing</code>，放在 <code>line-prototype/</code>。<br>目前資料只存在瀏覽器記憶體，重新整理就消失，沒有任何對外連線 —— 這正是第二幕要解決的事。' }
      ]
    },

    /* ══════════ 第二幕 ══════════ */
    {
      key: 'a2', place: '舞台與後台之間', no: '第二幕', name: '接電', theatre: '＝ 把舞台和後台接起來',
      note: '整個專案的<b>分水嶺</b>。過了這一幕，預約才開始是真的。這六步<b>完全不需要任何客人資料</b> —— 這就是它排在客人匯入前面的理由。',
      milestone: {
        title: '▲ 第二幕結束 — 分水嶺過了',
        text: '從這一刻起，你不再是在做原型。網頁和資料庫是真的接在一起的，之後每一個新功能都只是在這條已經通了的管線上加東西。'
      },
      steps: [
        { n:15, t:'先 select * 看 class_sessions 實際有哪些欄位', where:'SQL', done:true,
          summary:'做完之後發現了什麼',
          body:'盤完七張表 ＋ <code>customer_credits</code> 的全部欄位。三個關鍵發現：<ul><li><b><code>class_sessions</code> 已經複製了範本欄位</b>（title／level／duration_min／capacity／coach_id）→ 檢視表根本不用碰 <code>class_templates</code>，少一張表要擔心</li><li><b><code>employees</code> 有四個欄位絕不能外流</b>：<code>name</code>／<code>phone</code>／<code>email</code>／<code>auth_user_id</code></li><li><b><code>coach_id</code> 可以留空</b> → 用一般 join 的話，還沒指定教練的課會整堂從課表消失。必須 <code>left join</code></li></ul>另外查到 <code>bookings.cancelled_at</code>，決定用它來數人數，而不是猜 <code>status</code> 會存什麼字。',
          ck:'手上有一張紙（或一則筆記），寫著七張表實際的欄位名稱。' },

        { n:16, t:'建一張只含安全欄位的公開課表檢視表', where:'SQL', done:true,
          summary:'建出了什麼',
          body:'<code>public_schedule</code>，<b>剛好 12 欄</b>：<code>session_id</code>／<code>session_date</code>／<code>start_time</code>／<code>duration_min</code>／<code>title</code>／<code>level</code>／<code>coach_name</code>／<code>capacity</code>／<code>booked_count</code>／<code>seats_left</code>／<code>is_full</code>／<code>status</code><br><br>備份在 <code>db/10-public-views.sql</code>。完整說明（含兩個「絕對不要做」）寫在 <b>HANDOVER.md 第六節</b>。',
          warn:'☢️ 之後 Advisors 會顯示 <code>Security Definer View</code> 警告 —— <b>那是預期的，不要改</b>。改成 <code>security_invoker</code> 就等於把 employees 對訪客打開。',
          ck:'查這張檢視表看得到未來 14 天的課，而且沒有任何一欄是你不想給外人看的。' },

        { n:17, t:'開一條「未登入的人也能讀這張檢視表」的規則', where:'SQL', done:true,
          summary:'實測結果',
          body:'grant 已經寫在 <code>10-public-views.sql</code> 裡（先 <code>revoke all</code> 全部關死，再 <code>grant select</code> 只開一條縫）。<br><br>用 SQL Editor 右上角把 Role 切成 <code>anon</code> 實測：<br><code>public_schedule → 30 筆 ✅</code><br><code>employees → permission denied ✅</code><br><code>customers → permission denied ✅</code><br><code>class_sessions → permission denied ✅</code><br><br><b>同一批課表資料，走窗口拿得到、走原表拿不到</b> —— 這一對結果就是整個設計的證明。',
          warn:'測完<b>記得把 Role 切回 <code>postgres</code></b>。忘了切的話之後每個查詢都會安靜地回 0，不會報錯，你會找很久。',
          ck:'用 Publishable key 查得到課表；用同一把鑰匙查其他表，什麼都查不到。' },

        { n:18, t:'把 Project URL 和 Publishable key 放進前端', where:'前端', done:true,
          summary:'做完之後驗到了什麼',
          body:'設定檔 <code>line-prototype/supabase-config.js</code>（專案網址 ＋ Publishable key ＋ 建立連線），驗收工具 <code>line-prototype/connection-test.html</code>。<br><br><b>三項測試全綠：</b><ul><li>① 金鑰是 <code>sb_publishable_</code> 開頭，46 字元，沒有零寬字元</li><li>② 從瀏覽器讀到 <b>28 堂</b>今天以後的真實課表（含教練名、名額、狀態）</li><li>③ <code>employees</code>／<code>customers</code>／<code>class_sessions</code> 三張全部 <code>permission denied</code></li></ul>③ 這次是<b>從真正的瀏覽器、用真正會放進網站的那把鑰匙</b>測的，比第 17 步在後台切 Role 更接近客人的處境。',
          warn:'⚠️ 「搜尋 <code>sb_secret</code> 一個字都找不到」這個判準太粗糙 —— 檔案裡本來就有 3 處註解和保險檢查會提到它。<b>正確判準是「沒有任何變數被指派成 <code>sb_secret_</code> 開頭的值」</b>。',
          ck:'connection-test.html 三個區塊全綠。' },

        { n:19, t:'GT-booking.html 改成讀真實課表（只能看，不能訂）', where:'前端', done:true,
          summary:'做完之後改了什麼、踩到什麼',
          body:'寫死的 <code>RAW</code> 週課表整段拿掉，改讀 <code>public_schedule</code>。視覺設計一個像素沒動，換掉的只有資料來源。<br><br><b>① 日期分頁從「週一～週日」改成真實日期</b><br>這不是偏好，是資料逼的。<code>class_sessions</code> 存的是「2026-08-10 那一堂」，不是「每個週一」。用星期分頁的話，「今天這堂已取消、下週同一堂還在」這個差別會整個消失。<br><br><b>② 候補整套移除</b>；額滿改成「仍可報名，現場座位需與教練確認」（規則：不硬擋）<br><br><b>③ 取消的課</b>卡片轉灰、按鈕變「本日未開課」<br><br><b>④ 訂課按鈕停用</b>，腳本第一行有 <code>BOOKING_OPEN = false</code> 開關 —— 第 30 步才打開，而且要先做完 28、29 步。<br><br><b>⑤ 兩個「不寫死」</b>：認不得的 <code>status</code> 和 <code>level</code> 都照原樣顯示，不會壞掉、不會空白。',
          warn:'踩到兩個坑，<b>兩個都不會報錯</b>：<br>① <b>CSS class 撞名</b> —— 新加的 <code>.x</code> 跟原檔的彈窗關閉鈕撞到，版面整個爛掉。在既有樣式裡加東西，class 名字一律加前綴。<br>② <b><code>const</code> 宣告的東西不會變成 <code>window</code> 的屬性</b> —— <code>supabase-config.js</code> 裡 <code>const fffDB</code> 存在，但 <code>window.fffDB</code> 是 undefined。要多寫一行 <code>window.fffDB = fffDB;</code> 才掛得上門牌。',
          ck:'在 Table Editor 把 8/10 的「TRX綜合雕塑」改成「TRX綜合雕塑（測試中）」，網頁重新整理後跟著變 —— <b>證明這條線是活的，不是快照</b>。' },

        { n:20, t:'推上 GitHub Pages，用手機實測', where:'Git', done:false,
          summary:'說明 ＋ 完成判準',
          body:'用自己的手機、關掉 Wi-Fi 用行動網路開一次。桌機看得到不代表手機看得到。',
          warn:'部署可能卡在 <code>deployment_queued</code>，那是 GitHub 端的已知問題，不是你設定錯。解法是重試（可能要多次）或推一個空 commit。',
          ck:'手機瀏覽器看得到真實課表。<br><b>同時：風險 1（免費方案被自動暫停）自動解除 —— 這個資料庫從此有外部流量了。</b>' }
      ]
    },

    /* ══════════ 第三幕 ══════════ */
    {
      key: 'a3', place: '後台名冊室', no: '第三幕', name: '讓觀眾入座', theatre: '＝ 把客人名冊搬進來',
      note: '交接紀錄原本把這一幕排在最前面。往後挪不是因為它不重要，而是因為它<b>看不到成果</b> —— 管線通了之後再匯入，你才驗證得了自己做對了。',
      steps: [
        { n:21, t:'整理現有客人名單，先確認手機沒有重複', where:'決定', done:false,
          summary:'說明 ＋ 完成判準',
          body:'<code>customers.phone</code> 是 unique <b>而且 NOT NULL</b>。名單裡有兩個一樣的手機、或有人沒填手機，整批匯入都會直接失敗。<b>匯入前先在 Excel 排序看一遍</b>，比匯入後才發現省事得多。',
          ck:'一份姓名、手機、剩餘堂數、方案都齊全，而且手機沒有重複、沒有空白的名單。' },

        { n:22, t:'「舊有剩餘堂數」怎麼變成流水帳的第一筆', where:'決定', done:false, kind:'decide',
          summary:'兩條路的取捨 ＋ 完成判準',
          body:'<ul><li><b>(A) 一次性期初餘額</b>：每人一筆「系統上線前結轉 N 堂」。快、簡單，但客人問「這 N 堂哪來的」你只能說結轉</li><li><b>(B) 照實際購買紀錄逐筆補</b>：慢很多，但完整可追</li></ul><b>建議 A</b>，並在備註欄寫清楚結轉日期 —— 反正 B 需要的舊資料多半也不完整。',
          ck:'你選定了一種，而且能對客人解釋為什麼。' },

        { n:23, t:'寫匯入 SQL，匯入 customers', where:'SQL', done:false,
          summary:'說明 ＋ 完成判準',
          body:'檔名跟著慣例叫 <code>11-seed-customers.sql</code>（10 已經被 public-views 用掉了）。',
          warn:'這是「塞資料」的 SQL —— <b>一定要加保險絲</b>，而且備份檔和 Supabase 分頁<b>兩邊都要</b>。這是你自己訂的第 7 條規則。',
          ck:'把整張分頁再按一次 Run，它報錯中止、一筆都沒重複進去。這才叫保險絲有效。' },

        { n:24, t:'寫入期初堂數，核對 customer_credits 對不對', where:'SQL', done:false,
          summary:'說明 ＋ 完成判準',
          body:'寫進 <code>credit_ledger</code>（<code>delta</code> 是整數，加課正數、扣課負數），然後查 <code>customer_credits</code>，逐筆比對跟你手上的名單一不一樣。',
          ck:'隨機抽三個人，系統算出來的剩餘堂數跟紙本一致。' },

        { n:25, t:'風險 2：漏跑的日子要不要補結算', where:'決定', done:false, kind:'decide',
          summary:'技術上五秒，商業上要想 ＋ 完成判準',
          body:'<code>daily_class_job()</code> 的 ②③ 都寫 <code>session_date = v_today</code>，只結算「今天」。如果排程有幾天沒跑，中間那幾天的課堂會永遠停在 <code>pending</code>，既沒成立也沒取消。<br>改法是把 <code>=</code> 改成 <code>&lt;=</code>，五秒鐘。<br><br><b>但那是商業決定：</b>三天前的課現在才補判定「取消」，對已經報名的客人合不合理？<br><b>現在還沒客人，是做這個決定最沒有代價的時機。</b>',
          ck:'你做了決定，而且理由寫進 HANDOVER.md。' }
      ]
    },

    /* ══════════ 第四幕 ══════════ */
    {
      key: 'a4', place: '劇院大門', no: '第四幕', name: '開大門', theatre: '＝ 蓋 LINE 劇院大門',
      note: '客人不會記得你的網址，但他們每天都開 LINE。這一幕最難的不是介面，是<b>第 28 步的身分驗證</b> —— 那一步做錯，前面所有的鎖都只是裝飾。',
      milestone: {
        title: '▲ 第四幕結束 — 系統正式上線',
        text: '客人可以在 LINE 裡自己訂課、自己取消、自己查堂數。你原本要花在接電話和回訊息的時間，從這裡開始省下來。'
      },
      steps: [
        { n:26, t:'開 LINE 官方帳號 ＋ LINE Developers 的 Provider／Channel', where:'LINE後台', done:false,
          summary:'說明 ＋ 完成判準',
          body:'兩個不同的後台，容易搞混：官方帳號管「客人看到的門面」，Developers 管「程式怎麼進去」。',
          ck:'你能用自己的 LINE 加到這個官方帳號的好友。' },

        { n:27, t:'建 LIFF App，指向 GitHub Pages 上的預約頁', where:'LINE後台', done:false,
          summary:'說明 ＋ 完成判準',
          body:'LIFF 會在 LINE 內部開一層網頁蓋在對話上 —— 客人全程不離開 LINE，但本質仍是網頁。<b>預約介面不可能真的長在對話泡泡裡。</b><br>簡單查詢（例如「剩幾堂」）可以用機器人純文字回覆，不用開網頁。',
          ck:'在 LINE 裡點一個連結，課表在 LINE 內部打開。' },

        { n:28, t:'寫 Edge Function：驗 LINE 身分，發 Supabase 憑證', where:'SQL', done:false,
          summary:'整個專案技術上最關鍵的一步 ＋ 完成判準',
          body:'❌ <b>錯</b>：LIFF 取得 <code>line_user_id</code>，前端直接拿它查資料庫<br>→ 任何人改一個字串就能查別人的資料<br><br>✅ <b>對</b>：<br>LIFF 取得 ID Token（LINE 簽章過的憑證）<br>↓ 送到 Supabase Edge Function<br>↓ 向 LINE 官方驗證<br>↓ 發一張 Supabase 登入憑證<br>之後所有查詢用 <code>auth.uid()</code> 判斷身分',
          warn:'<b>這一步沒做對，後面所有 RLS 都是裝飾。</b>',
          ck:'你試著把請求裡的 ID 換成別人的，系統拒絕你。' },

        { n:29, t:'手機綁定流程', where:'前端', done:false,
          summary:'說明 ＋ 完成判準',
          body:'客人第一次開 LIFF → 輸入手機 → 比對第三幕匯入的名單 → 寫入 <code>line_user_id</code>。<br><code>customers.phone</code> 設成 unique 就是為了這一刻。',
          ck:'用你自己的 LINE 綁定成功，第二次打開直接認得你。' },

        { n:30, t:'打開真正的訂課', where:'前端', done:false,
          summary:'說明 ＋ 完成判準',
          body:'寫入 <code>bookings</code>、取消時限靠 RLS 擋（<b>不是靠前端藏按鈕</b>）、額滿只跳提醒不硬擋。<br>順便：查課卡餘額、看自己的課、取消自己的課。',
          ck:'你用手機訂一堂課，Supabase 裡真的多一筆。<br><b>同時：風險 3（每天課都被自動取消）自動解除 —— 終於有人報名了。</b>' },

        { n:31, t:'PT／PGT 頁改成「送出需求」', where:'前端', done:false,
          summary:'說明 ＋ 完成判準',
          body:'按鈕文字從「確認預約」改成「送出需求」，寫進 <code>pt_requests</code>。<br><b>私人課不是預約</b> —— 客人送需求，教練聯繫後才敲定。',
          ck:'送出一筆需求，<code>pt_requests</code> 裡看得到，而且沒有動到任何課堂名額。' },

        { n:32, t:'設定 LINE 圖文選單', where:'LINE後台', done:false,
          summary:'說明 ＋ 完成判準',
          body:'大門上的指示牌：訂課／我的課／剩幾堂／聯絡我們。',
          ck:'加好友之後，不用任何說明就知道該點哪裡。' }
      ]
    },

    /* ══════════ 第五幕 ══════════ */
    {
      key: 'a5', place: '前台櫃檯', no: '第五幕', name: '讓教練上工', theatre: '＝ 前台櫃檯數位化',
      note: '客人端跑順之後才做這一幕。前面四幕都在服務觀眾，這一幕開始服務工作人員 —— 也是<b>往 ERP 的第一步</b>。',
      steps: [
        { n:33, t:'六位教練註冊帳號，填回 employees.auth_user_id', where:'Supabase', done:false,
          summary:'說明 ＋ 完成判準',
          body:'目前六個人的 <code>auth_user_id</code> 都是空的，等的就是這一步。',
          ck:'六位教練都能登入，而且各自只看得到自己該看的。' },

        { n:34, t:'課後點名核銷頁', where:'前端', done:false,
          summary:'說明 ＋ 完成判準',
          body:'教練在現場點名，扣課寫進 <code>credit_ledger</code>。<code>bookings</code> 已經預留了 <code>checked_by</code> 和 <code>checked_at</code> 兩個欄位給這一步。<br><b>缺席不扣課</b> —— 這條規則要寫進程式，不能靠教練記得。',
          ck:'核銷一堂課，客人手機上的剩餘堂數當場少一堂。' },

        { n:35, t:'教練端的私人課需求處理', where:'前端', done:false,
          summary:'說明 ＋ 完成判準',
          body:'看到 <code>pt_requests</code> 的待處理清單，聯繫客人、敲定時間、標記完成。',
          ck:'教練不用再翻 LINE 訊息找誰要約私人課。' },

        { n:36, t:'課前提醒推播', where:'SQL', done:false,
          summary:'說明 ＋ 完成判準',
          body:'Edge Function ＋ LINE Messaging API。',
          warn:'這一條同時是<b>架構失效警訊</b> —— 需要頻繁自動通知，就代表 GitHub Pages 這套開始不夠用了，該考慮搬去 Cloudflare 或更完整的系統鏈。',
          ck:'課前一小時，報名的人收到 LINE 提醒。' }
      ]
    }
  ],

  /* ── 地平線：ERP（刻意不編號、不排序） ──────────────────────── */
  horizon: [
    { t:'金流與電子發票',   d:'一碰這個就必須搬離 GitHub Pages —— 條款明確禁止，沒有討論空間' },
    { t:'教練排班與薪資',   d:'建在 employees 上。離職改 is_active 不刪除，就是為了這一天' },
    { t:'營收與出席報表',   d:'資料其實從 pg_cron 上工那天就開始累積了' },
    { t:'會員關係與續約管理', d:'建在 customers 上。credit_ledger 本身就是一份消費行為紀錄' },
    { t:'器材與庫存',       d:'目前完全沒動，也還看不出急迫性' },
    { t:'多店擴張',         d:'真的要走這條，資料表得先加「場館」欄位 —— 越晚加越痛' }
  ],

  /* ── 三個已知風險 ──────────────────────────────────────────── */
  risks: [
    { n:1, t:'免費方案專案會被自動暫停',
      d:'連續約一週幾乎沒有外部請求就會停。專案一停，場記也不出勤 —— 課堂不會長、結算不會做，而且沒有人會通知你。',
      clearAt:20, how:'auto' },
    { n:2, t:'漏跑的那幾天永遠不會被補結算',
      d:'<code>daily_class_job()</code> 只結算「今天」。中間漏掉的日子會永遠卡在 <code>pending</code>。改法是把 <code>=</code> 改成 <code>&lt;=</code>。',
      clearAt:25, how:'hand' },
    { n:3, t:'在有客人之前，每天的課都會被自動取消',
      d:'這不是錯誤，是照規則正確運作。<code>bookings</code> 空的 → 每天 00:00 判定「無人報名 → 取消」。看到一整排 <code>cancelled</code> 不用緊張。',
      clearAt:30, how:'auto' }
  ],

  /* ── 不可違反的規則（挑出接下來最容易踩到的） ────────────────── */
  rules: [
    { t:'每建一張資料表，立刻開 RLS 並寫至少一條規則', at:'建檢視表時同樣適用' },
    { t:'<code>sb_secret_</code> 絕不可出現在前端', at:'第 18 步唯一要盯的事' },
    { t:'前端隱藏不是安全', at:'第 30 步的取消時限要寫在 RLS，不是靠藏按鈕' },
    { t:'塞資料的 SQL 一律加保險絲，備份檔和 Supabase 分頁兩邊都要', at:'第 23 步' },
    { t:'按 Run 之前先看按鈕寫 <code>Run</code> 還是 <code>Run selected</code>', at:'整張跑和只跑反白的差很多' },
    { t:'不要憑記憶寫欄位名稱', at:'這就是第 15 步存在的理由' },
    { t:'看到 <code>permission denied</code> 先問「這個身分本來就該進得去嗎」', at:'絕不照錯誤訊息的 HINT 去 GRANT' }
  ]
};


/* ═══════════════════════════════════════════════════════════════════════
   以下是推導邏輯，不用改。
   進度、幕別計數、目前位置全部從上面的 done 欄位算出來。
   ═══════════════════════════════════════════════════════════════════════ */
window.FFF_PROGRESS = (function (R) {
  const allSteps = R.acts.flatMap(a => a.steps);
  const total    = allSteps.length;
  const doneList = allSteps.filter(s => s.done);
  const done     = doneList.length;

  // 目前這一步 = 第一個還沒完成的
  const current  = allSteps.find(s => !s.done) || null;

  // 目前在哪一幕
  const currentActIndex = current
    ? R.acts.findIndex(a => a.steps.some(s => s.n === current.n))
    : R.acts.length - 1;

  // 每一幕的完成數
  const actStats = R.acts.map((a, i) => {
    const d = a.steps.filter(s => s.done).length;
    return {
      key: a.key, no: a.no, name: a.name,
      done: d, total: a.steps.length,
      state: d === a.steps.length ? 'done' : (i === currentActIndex ? 'current' : 'todo')
    };
  });

  // 上一個完成的步驟（給「剛走完的路」用）
  const lastDone = doneList.length ? doneList[doneList.length - 1] : null;
  // 下下一步（給「前方」用）
  const afterCurrent = current
    ? allSteps.find(s => !s.done && s.n > current.n) || null
    : null;

  return {
    total, done, current, lastDone, afterCurrent,
    currentActIndex, actStats,
    remaining: total - done - (current ? 1 : 0),
    pctDone: (done / total) * 100,
    pctCurrent: current ? (1 / total) * 100 : 0
  };
})(window.FFF_ROADMAP);
