/* ═══════════════════════════════════════════════════════════════════════
   roadmap-data.js  —  FFF 專案進度的「單一真相來源」

   ┌──────────────────────────────────────────────────────────────────┐
   │  要更新進度，只改這一個檔案。                                       │
   │                                                                  │
   │  把某一步的  done: false  改成  done: true  ，然後存檔。            │
   │                                                                  │
   │  這些東西會自己跟著變，你完全不用手動改：                            │
   │    · 進度條和「25 / 42」那個數字                                   │
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
    updated: '2026-08-17 · GT 上線第二天 · 新增第 44、45 步（逾期未核銷提醒）',
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
          body:'簡基城、Jerec（owner）、Jessica、VC、Peter、Johnson。<br><code>auth_user_id</code> 目前都是空的，等教練真的註冊帳號才會填（第 38 步）。<br>離職改 <code>is_active</code> 不刪除 —— 刪掉會讓歷史課堂失去教練資訊。' },

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
          body:'寫死的 <code>RAW</code> 週課表整段拿掉，改讀 <code>public_schedule</code>。視覺設計一個像素沒動，換掉的只有資料來源。<br><br><b>① 日期分頁從「週一～週日」改成真實日期</b><br>這不是偏好，是資料逼的。<code>class_sessions</code> 存的是「2026-08-10 那一堂」，不是「每個週一」。用星期分頁的話，「今天這堂已取消、下週同一堂還在」這個差別會整個消失。<br><br><b>② 候補整套移除</b>；額滿改成「仍可報名，現場座位需與教練確認」（規則：不硬擋）<br><br><b>③ 取消的課</b>卡片轉灰、按鈕變「本日未開課」<br><br><b>④ 訂課按鈕停用</b>（第 33 步改成讀資料庫的 <code>app_settings.live</code>，前端不再有自己的旗標）。<br><br><b>⑤ 兩個「不寫死」</b>：認不得的 <code>status</code> 和 <code>level</code> 都照原樣顯示，不會壞掉、不會空白。',
          warn:'踩到兩個坑，<b>兩個都不會報錯</b>：<br>① <b>CSS class 撞名</b> —— 新加的 <code>.x</code> 跟原檔的彈窗關閉鈕撞到，版面整個爛掉。在既有樣式裡加東西，class 名字一律加前綴。<br>② <b><code>const</code> 宣告的東西不會變成 <code>window</code> 的屬性</b> —— <code>supabase-config.js</code> 裡 <code>const fffDB</code> 存在，但 <code>window.fffDB</code> 是 undefined。要多寫一行 <code>window.fffDB = fffDB;</code> 才掛得上門牌。',
          ck:'在 Table Editor 把 8/10 的「TRX綜合雕塑」改成「TRX綜合雕塑（測試中）」，網頁重新整理後跟著變 —— <b>證明這條線是活的，不是快照</b>。' },

        { n:20, t:'推上 GitHub Pages，用手機實測', where:'Git', done:true,
          summary:'上線了，而且風險 1 解除',
          body:'網址：<code>jerecyu.github.io/Fusion_Force_Fitness/line-prototype/GT-booking.html</code><br><br>桌機和手機都確認過，畫面跟本機一模一樣。手機那次是在<b>手機內建瀏覽器</b>開的 —— 那正是第 30 步 LIFF 之後客人會用的環境，等於提前測到了。<br><br><b>⚠️ 風險 1 到此解除。</b>這個資料庫從此有外部流量，免費方案不會再因為「一週沒人用」被自動暫停。',
          ck:'手機瀏覽器看得到真實課表。' }
      ]
    },

    /* ══════════ 第三幕 ══════════ */
    {
      key: 'a3', place: '後台名冊室', no: '第三幕', name: '接手舊劇院', theatre: '＝ 舊系統資料搬遷',
      note: '<b>兩種商品，兩種策略（2026-08-09 定案的「混合版」）。</b>因為資料品質差太多：<br><br><b>GT → 整套搬</b>（人 ＋ 全部流水 ＋ 近期預約）。它有獨立的 <code>members</code> 表、手機唯一、帳本自洽 —— 資料乾淨，搬它幾乎沒有額外成本。<br>⚠️ <b>2026-08-10 發現：舊系統是 2026-07 底才導入的</b>，裡面只有約 <b>12 天</b>的流水和預約，沒有四年歷史。2022-09 到 2026-07 之間的 GT 紀錄<b>根本不存在於任何系統</b>（當時是紙本／Excel）。所以「整套搬」實際上就是<b>人 ＋ 餘額 ＋ 近期紀錄</b>。<br><br><b>PT／PGT → 自然迭代</b>（只搬「人 ＋ 還沒用完的堂數」）。它沒有獨立客人表、沒有手機、四年流水混在一張手工表裡。重建那些歷史的成本遠大於價值 —— 而且 2022 年的客人有一大半早就不來了。<br><br><b>RT → 不搬。</b>那份 Excel 只有收款日期和金額，沒有時段也沒有租客，搬進來也不知道場地被誰佔了。等做金流時再處理。<br><br>往後挪不是因為它不重要，而是因為它<b>看不到成果</b> —— 管線通了之後再搬，你才驗證得了自己做對了。',
      milestone: {
        title: '▲ 第三幕結束 — 兩套帳對得起來',
        text: 'GT 的客人、堂數流水、近期預約全部進來了，而且<b>每一個人的餘額都跟舊系統一模一樣</b>。你手上有兩套帳，而且它們對得起來 —— 這是可以放心搬家的前提。（PT／PGT 走自然迭代，在第 36 步處理。）'
      },
      steps: [
        { n:21, t:'盤點舊系統，確認舊帳是健康的', where:'決定', done:true,
          summary:'三個好消息 ＋ 五個要處理的差異',
          body:'用離線工具 <code>tools/legacy-inventory.html</code> 掃過舊系統匯出的 10 個分頁。<b>全程沒有任何一個位元組離開你的電腦</b>，報告裡也不含任何姓名或手機。<br><br><b>三個好消息：</b><ul><li><b>舊帳本是自洽的</b> —— 68 個有帳的人，每一個人的 <code>delta</code> 加總都等於最後記錄的餘額。這代表舊帳可以整份直接搬，不用重算</li><li><b>手機 81／81 唯一</b>，沒有重複、沒有空白</li><li><b>沒有孤兒帳列</b> —— 每一筆流水都對得到人</li></ul><b>五個要處理的差異：</b><ul><li>舊系統有容量 <b>12</b> 的課，我們 14 堂目前全是 10</li><li>程度舊系統寫全字，我們用縮寫 → 要一組對照表</li><li>舊 <code>Classes</code> 只有 <b>5 位</b>教練，沒有簡基城</li><li>81 人裡有 <b>13 人完全沒有帳本紀錄</b> → 要確認是「0 堂」還是「沒建帳」</li><li><code>assignedCoach</code> 和 <code>email</code> 幾乎全空 → 不搬</li></ul>',
          warn:'⚠️ <b>只有 4 個人有 <code>lineId</code>。</b>這代表第 32 步的手機綁定完全不能跳過 —— 77 個人要重新綁一次。切換日的公告要把這件事講清楚。',
          ck:'你看過報告，「帳本自洽」和「手機唯一」兩項都通過。' },

        { n:22, t:'決定搬遷範圍與商品架構：七個決定', where:'決定', done:true, kind:'decide',
          summary:'七個決定與各自的理由',
          body:'<b>① 帶朋友來體驗 → 體驗客建檔，一人一列</b><br><code>bookings</code> 加一個 <code>paid_by_customer_id</code> 記「這堂扣誰的卡」。舊系統用 <code>headCount</code> 把 5 個人壓成 1 筆，<b>教練鐘點費會算成 200 而不是 700</b> —— 人數錯，薪水就錯。順帶：帶來體驗的人是最可能成交的名單，舊系統把他們變成一個數字就丟掉了。<br><br><b>② 買十送二 → 帳本拆兩列</b><br>買課時記 <code>purchase +10</code> 和 <code>bonus +2</code> 兩筆。餘額還是 12，扣課邏輯一行都不用改，但「送出去多少堂」和「贈送帶來多少新客」查得出來。舊資料分不出來，一律標 <code>purchase</code>。<br><br><b>③ 教練鐘點費 <code>payout</code> → 不搬</b><br>它是<b>算出來的</b>：團體課 1 人 200，第 2 人起每多一人 +100，跟人數一對一。只要點名是對的，錢就是對的。規則寫進 HANDOVER 附錄四。<br><br><b>④ 舊 <code>LessonInstances</code> 只有團體課</b><br>所以 <code>payout=1200</code> 就是「10 個人」，沒有第二種解釋。反推規則成立。<br><br><b>—— 以下三個是知道還有 PT／RT 之後補的 ——</b><br><br><b>⑤ 全面加上「商品別」<code>product</code></b><br>值：<code>GT</code>（主題式團體課）／<code>PT</code>（私人教練課）／<code>PGT</code>（私人團體班）／<code>RT</code>（場地租借），<b>預設一律 <code>GT</code></b>。<code>class_sessions</code> 和 <code>credit_ledger</code> 兩張都要加。<br><br><b>⑥ 堂數分錢包</b><br>買 10 堂團體課<b>不能</b>拿去上私人課。<code>customer_credits</code> 要從「一個人一個餘額」改成「一個人每一種商品各一個餘額」。<br><br><b>⑦ 教練薪資第一階段只算 GT 人頭費</b><br>資料來源就是點名 —— 實到幾個人，鐘點費就是多少，不需要任何額外輸入。PT 的 8 萬門檻抽成要等每一堂 PT 都進系統，那是 ERP 那一段。',
          warn:'③ 的道理跟這份路線圖本身一樣：<b>能算出來的東西就不要另外記一份</b>。記兩份，兩份遲早會對不起來 —— 這就是 <code>db/</code> 那個坑的同一個病。',
          ck:'四個決定都寫進 <code>HANDOVER.md</code> 附錄四。' },

        { n:23, t:'改資料表：加上「商品別」和「扣誰的卡」', where:'SQL', done:true,
          summary:'四個欄位，為什麼一定要現在加',
          body:'檔名 <code>db/11-alter-migration.sql</code>（10 已經被 <code>public-views</code> 用掉了）。<b>三個新欄位 ＋ 一張檢視表重建 ＋ 兩條 RLS</b>：<ul><li><code>class_sessions.product</code> → <code>GT</code>／<code>PT</code>／<code>PGT</code>／<code>RT</code>，<b>預設 <code>GT</code></b></li><li><code>credit_ledger.product</code> → <code>GT</code>／<code>PT</code>／<code>PGT</code>（RT 不扣堂數），預設 <code>GT</code></li><li><code>bookings.paid_by_customer_id</code> → 指向 <code>customers</code>，既有每一列先補成等於自己的 <code>customer_id</code></li><li>重建 <code>customer_credits</code> → 從「一個人一個餘額」改成「<b>每人每種商品各一個餘額</b>」</li><li><code>pt_requests.kind</code> 改名成 <code>product</code> —— 同一個概念只留一個名字</li></ul><b>⚠️ 原本說要加的 <code>kind</code> 欄位取消了。</b>照規則 9 撈實際欄位才發現，<code>credit_ledger</code> <b>本來就有 <code>reason</code></b>，值域是 <code>purchase</code>／<code>bonus</code>／<code>class</code>／<code>adjust</code>／<code>refund</code> —— 「買十送二」拆兩列要用的 <code>purchase</code> 和 <code>bonus</code> 現成就在裡面。再加一個 <code>kind</code> 就是兩個欄位講同一件事。<br><br><b>為什麼是現在：</b>這些現在加是幾行 SQL，表裡幾乎沒有資料。等 81 個人和幾百筆流水都搬進來之後再加，<b>每一列都要回頭補標</b> —— 而且你會沒把握哪幾列標對了。',
          warn:'☢️ <b>撈欄位時發現的一個現成的洞：<code>customer_credits</code> 會繞過 RLS。</b><br>檢視表預設是「以擁有者身分執行」。<code>customer_credits</code> 現在沒開放給任何人，所以還沒出事 —— 但第 33 步客人要查自己的堂數時一開放，<b>每個人都看得到別人的餘額</b>。<br>重建時要加 <code>with (security_invoker = true)</code>，讓它走 <code>credit_ledger</code> 上「客人只讀自己的」那條規則。<br><br>⚠️ <b>這跟 <code>public_schedule</code> 剛好相反</b>：那一張是<b>故意</b>繞過 RLS（要端出教練名字），這一張是<b>絕對不能</b>繞過。同樣是檢視表、方向相反 —— 以後每建一張新的檢視表都要重問一次「這張該不該繞過 RLS」。<br><br>另外：<b>新欄位不會自動被現有 RLS 涵蓋。</b>「客人讀自己的預約」那條要加上「或是我付錢的」，還要補一條「員工可代開預約」—— 否則櫃檯根本開不了體驗客的單，而且<b>不會報錯，只是功能不會動</b>。',
          ck:'SQL 檔最後有 ★A～★G 七段驗收，反白跑一次：<ul><li>★A 三個新欄位都在</li><li>★B 既有預約「不一樣的」＝ <b>0</b></li><li>★D <code>customer_credits</code> 是 <b>customer_id／product／balance 三欄</b></li><li>★E 看得到 <code>product</code>、看不到 <code>kind</code></li><li>★F <code>bookings</code> 有 <b>6</b> 條 RLS 規則</li><li>★G 現有課堂 <b>全部是 GT</b></li></ul>' },

        { n:24, t:'把公開課表的門關上：public_schedule 只給 GT', where:'SQL', done:true,
          summary:'一個還沒發生、但一定會發生的外洩',
          body:'<code>public_schedule</code> 現在<b>無條件</b>讀 <code>class_sessions</code> 的每一列 —— 因為建它的時候，那張表裡只可能有團體課。<br><br>但排 PT 的時候，你<b>一定</b>會把它排進 <code>class_sessions</code>（場地要排班，不然會撞場）。那一刻：<br><br><code>class_sessions</code> 多一列「週二 14:00 私人課 · 王小姐 · 教練 Peter」<br>↓ <code>public_schedule</code> 沒有任何過濾<br>↓ <b>官網課表上，全世界都看得到王小姐週二下午在上私人課</b><br><br><b>改法：</b>改 <code>db/10-public-views.sql</code> 那一張分頁本身（<code>create or replace view</code> 可以重複執行），加一行 <code>where x.product = \'GT\'</code>。<br><br><b>為什麼改 10 而不是開一支新的：</b>檢視表的定義應該<b>只有一個地方</b>寫著。開新檔案的話，半年後沒人知道哪一份才是現行的 —— 那正是 <code>db/ 00~06</code> 那個坑。',
          warn:'☢️ <b>這一步要在「還沒有任何 PT 資料」的時候做完。</b>等到有資料才想起來，那就不是預防，是善後了。<br>而且這種錯<b>不會報錯、不會有人通知你</b> —— 跟 CSS 撞名、跟 <code>const</code> 不上 <code>window</code> 是同一種：安靜地錯。',
          ck:'手動在 <code>class_sessions</code> 塞一列 <code>product=\'PT\'</code> 的假資料 → 查 <code>public_schedule</code> <b>看不到它</b> → 把 Role 切成 <code>anon</code> 再查一次<b>還是看不到</b> → 刪掉假資料、Role 切回 <code>postgres</code>。<b>看不到才算過。</b>' },

        { n:25, t:'課表校正：容量、程度用語、教練名單', where:'決定', done:true, kind:'decide',
          summary:'這一步是「對現實」，不是「對資料」',
          body:'三件事只有你答得出來，資料庫裡找不到答案：<ul><li>舊系統有容量 <b>12</b> 的課，我們現在 14 堂<b>全部是 10</b>。哪幾堂真的收 12？</li><li><b>簡基城不在舊 <code>Classes</code> 裡</b> —— 他現在到底帶不帶團體課？</li><li>舊系統程度寫全字、我們用縮寫，要一組一對一的對照表</li></ul>先對完再搬。搬完才發現容量不對，等於整批課堂的名額都要重來。',
          ck:'<b>2026-08-09 對完，三題都有答案：</b><ul><li><b>容量全部 10</b> —— 舊系統那個 12 是歷史值，現況沒有收 12 的課。搬歷史時<b>照舊值搬</b>，不要改成 10</li><li><b>簡基城不帶團體課</b> —— 他留在 <code>employees</code> 裡（PT 用），但不會出現在任何 GT 課表</li><li><b>程度對照</b>：<code>beginner→beg</code>／<code>intermediate→int</code>／<code>advanced→adv</code>，一對一，沒有例外</li></ul>另外逐堂對過：14 堂全部是現行的，沒有停開的課，時間／教練／程度都相符。<b>資料庫不用改任何一筆。</b>' },

        { n:26, t:'做 GT 搬遷工具（離線，在你自己的電腦上跑）', where:'前端', done:true,
          summary:'只做 GT。PT／PGT 不寫工具',
          body:'一個 HTML 檔，跟 <code>tools/legacy-inventory.html</code> 一樣<b>雙擊就能開、完全不連網</b>。<br><br>讀舊系統匯出的四個分頁，吐出四支 SQL：<ul><li><code>members</code> → <code>customers</code></li><li><code>PassLedger</code> → <code>credit_ledger</code>（<code>product=\'GT\'</code>，完整流水）</li><li><code>LessonInstances</code> → <code>class_sessions</code>（<code>product=\'GT\'</code>、<code>template_id</code> 留空）</li><li><code>Bookings</code> → <code>bookings</code></li></ul><b>PT／PGT 不在這支工具裡</b> —— 它們走自然迭代，只在第 36 步人工建「人 ＋ 餘額」。<br><br><b>為什麼是工具不是手工：</b>八十幾個人、上百筆流水，手打一定會錯，而且切換日還要再跑一次乾淨的。工具做一次，用兩次。<br><br>⚠️ 工具有一個<b>日期上限</b>（預設今天）：<b>今天之後的課次不匯入</b>。那些時段由我們自己的 <code>pg_cron</code> 產生，兩邊都匯的話客人會看到同一時段兩堂課。<br>但那些課上<b>已經有人報名</b>的預約會一起跳過 —— <b>切換日那天要人工處理這幾個人</b>。',
          warn:'☢️ <b>產出的 SQL 含完整姓名和手機。</b><ul><li>絕不貼進聊天室</li><li><b>絕不放進 <code>db/</code></b> —— 那個資料夾是版控的，而且 repo 是公開的</li><li>輸出到 <code>migration-local/</code>，並且先把這個資料夾寫進 <code>.gitignore</code></li></ul>順序很重要：<b>先改 <code>.gitignore</code>，再產生檔案。</b>反過來的話，檔案有可能在你改之前就被 Git 看到了。',
          ck:'拿備份資料跑一次，四支 SQL 都打得開，行數跟盤點報告上的數字對得起來。而且 <code>git status</code> 看不到它們。' },

        { n:27, t:'GT 彩排：完整匯入 ＋ 逐筆對帳', where:'SQL', done:true,
          summary:'彩排的目的不是上線，是證明工具是對的',
          body:'用備份資料整套跑一次：客人 → 堂數流水 → 上課歷史 → 預約。<br><br><b>對帳方式：</b>查 <code>customer_credits</code>（<code>product=\'GT\'</code>），跟舊系統最後的餘額<b>逐筆</b>比。<b>每一筆都要中</b> —— 這一步<b>不接受抽查</b>，因為抽查抽不到的那一筆，就是上線後客人打來抱怨的那一筆。<br>（人數是浮動的：第 21 步盤點時 81 人，08-10 已經 84 人。舊系統還在跑，切換日那天再以當下為準。）<br><br><br><br><b>⚠️ 對完的資料<u>留著不要清</u></b>（2026-08-10 改的決定）。原本計畫是清掉，但留著更有用：第 31～33 步的身分驗證、手機綁定、開放訂課<b>要有真實客人資料才測得起來</b>，你可以用自己的手機實測。反正第 37 步本來就會「清掉彩排資料、正式匯入」，中間測試弄髒也無所謂。',
          warn:'⚠️ 這是「塞資料」的 SQL —— <b>一定要加保險絲，備份檔和 Supabase 分頁兩邊都要</b>。這是你自己訂的第 7 條規則。<br><br>還有一條：<b>有一筆對不上，就是工具有問題。</b>不要手動改資料庫把它「喬」過去 —— 喬過去的那一筆會在半年後變成一個查不出來的鬼。',
          ck:'<b>2026-08-10 彩排結果，全部通過：</b><ul><li><code>g1</code> 客人 <b>84</b> 人</li><li><code>g2</code> 流水 <b>117</b> 筆 → <b>71</b> 人有餘額，合計 <b>579 堂</b>（這是全店欠客人的堂數）</li><li><code>g3</code> 歷史課次 <b>73</b> 堂（＋排程 33 ＝ 106），<b>重疊檢查 0 列</b></li><li><code>g4</code> 預約 <b>35</b> 筆（attended 34 ＋ booked 1）</li><li><code>g5</code> 未來預約 <b>27/27 全部自動對回</b>，0 筆要人工</li></ul><b>端到端驗證：</b>Excel 的 <code>delta</code> 整欄加總 = <b>579</b>，跟資料庫算出來的完全吻合。一筆漏掉、一筆重複、一個正負號寫反都會讓這個數字對不上。' },

        { n:28, t:'風險 2：漏跑的日子要不要補結算', where:'決定', done:true, kind:'decide',
          summary:'技術上五秒，商業上要想 ＋ 完成判準',
          body:'<code>daily_class_job()</code> 的 ②③ 都寫 <code>session_date = v_today</code>，只結算「今天」。如果排程有幾天沒跑，中間那幾天的課堂會永遠停在 <code>pending</code>，既沒成立也沒取消。<br>改法是把 <code>=</code> 改成 <code>&lt;=</code>，五秒鐘。<br><br><b>但那是商業決定：</b>三天前的課現在才補判定「取消」，對已經報名的客人合不合理？<br><b>現在還沒客人，是做這個決定最沒有代價的時機。</b>',
          ck:'<b>2026-08-11 決定：選 C ＋ 一個開關。</b><ul><li><b>② 改成 <code>&lt;=</code></b> —— 漏跑的日子，只要有人報名就補標「成立」。「有人報名」是<b>紀錄</b>不是推測，追溯確認不可能錯</li><li><b>③ 維持 <code>=</code>，外面再包一個開關（現在 false —— 第 33 步已經把它換成 <code>app_settings.live</code>）</b> —— 「沒人報名」是<b>推測</b>，只說明系統沒收到報名，不說明現場發生了什麼</li></ul>本機 PostgreSQL 16 驗過四種情況：開關 false 時「三天前有人報名」補成 <code>confirmed</code>、「三天前沒人報名」和「今天沒人報名」都留 <code>pending</code>；開關 true 時只有今天的空堂被取消，三天前那堂依然不動。<br><br>☢️ <b>第 33 步已經把這個開關和前端的旗標合併成 <code>app_settings.live</code> 一列</b>，上線那天只改那一個。' }
      ]
    },

    /* ══════════ 第四幕 ══════════ */
    {
      key: 'a4', place: '劇院大門', no: '第四幕', name: '開大門', theatre: '＝ 蓋 LINE 劇院大門',
      note: '客人不會記得你的網址，但他們每天都開 LINE。這一幕最難的不是介面，是<b>第 31 步的身分驗證</b> —— 那一步做錯，前面所有的鎖都只是裝飾。',
      milestone: {
        title: '▲ 第四幕結束 — 系統正式上線',
        text: '客人可以在 LINE 裡自己訂課、自己取消、自己查堂數。GT 的四年歷史整套搬進來了，PT／PGT 帶著餘額重新開始，舊系統變成唯讀的存證。你原本要花在接電話和回訊息的時間，從這裡開始省下來。'
      },
      steps: [
        { n:29, t:'開 LINE 官方帳號 ＋ LINE Developers 的 Provider／Channel', where:'LINE後台', done:true,
          summary:'說明 ＋ 完成判準',
          body:'兩個不同的後台，容易搞混：官方帳號管「客人看到的門面」，Developers 管「程式怎麼進去」。',
          ck:'<b>2026-08-11 完成。</b><ul><li>官方帳號 <code>@fff123</code> 早就有了（203 位好友），Messaging API 也早就是「使用中」</li><li>Provider <b><code>FUSIONFORCE</code></b>（ID <code>2005312469</code>），Jerec 已是 Admin</li><li>新建 LINE Login channel <b>「FFF 預約系統」</b>，Channel ID <b><code>2011063116</code></b>，App type = Web app</li></ul><b>踩到的坑：</b>舊系統管理者說「建 channel 會進死循環，是官方 bug」。查過官方文件和中英文社群，<b>沒有任何人回報過</b>。改用<b>無痕視窗</b>（擴充功能全停）再試一次就成功了 —— 是瀏覽器擴充攔截表單送出，不是 LINE 的問題。<br><b>教訓：後台操作卡住時，先開無痕視窗試一次，那比查文件快。</b>' },

        { n:30, t:'建 LIFF App，指向 GitHub Pages 上的預約頁', where:'LINE後台', done:true,
          summary:'說明 ＋ 完成判準',
          body:'LIFF 會在 LINE 內部開一層網頁蓋在對話上 —— 客人全程不離開 LINE，但本質仍是網頁。<b>預約介面不可能真的長在對話泡泡裡。</b><br>簡單查詢（例如「剩幾堂」）可以用機器人純文字回覆，不用開網頁。',
          ck:'<b>2026-08-11 完成。</b><ul><li>LIFF app <b>「GT 團體課預約」</b>，LIFF ID <b><code>2011063116-QOxXN30h</code></b></li><li>Size <code>Full</code>、Scopes <code>openid</code> ＋ <code>profile</code>、Add friend option <code>Off</code></li><li>網址：<code>https://liff.line.me/2011063116-QOxXN30h</code></li></ul>手機在 LINE 裡點開，課表直接在 LINE 內部顯示，資料是即時從資料庫讀的。<br><br><b>沒有勾 <code>chat_message.write</code></b> —— 它會讓客人<b>不能把 LIFF 視窗縮到底下</b>，而我們根本不需要「代替使用者發訊息」這個功能。' },

        { n:31, t:'寫 Edge Function：驗 LINE 身分，發 Supabase 憑證', where:'SQL', done:true,
          summary:'整個專案技術上最關鍵的一步 ＋ 完成判準',
          body:'❌ <b>錯</b>：LIFF 取得 <code>line_user_id</code>，前端直接拿它查資料庫<br>→ 任何人改一個字串就能查別人的資料<br><br>✅ <b>對</b>：<br>LIFF 取得 ID Token（LINE 簽章過的憑證）<br>↓ 送到 Supabase Edge Function<br>↓ 向 LINE 官方驗證<br>↓ 發一張 Supabase 登入憑證<br>之後所有查詢用 <code>auth.uid()</code> 判斷身分',
          warn:'<b>這一步沒做對，後面所有 RLS 都是裝飾。</b>',
          ck:'你試著把請求裡的 ID 換成別人的，系統拒絕你。',
          note:'<b>2026-08-11 完成。</b><br>檔案：<code>supabase/functions/line-auth/index.ts</code>（伺服器端）、<code>line-prototype/liff-auth.js</code>（前端）。<br><br><b>攻擊測試五種全部被擋，沒有任何一種發出憑證：</b>什麼都不送 400／空物件 400／亂碼 401／偽造 JWT（格式對簽章假）401／別人 channel 的憑證 401。<br><br><b>實機驗證</b>：手機從 LINE 開 → 顯示「已辨識」，同一分鐘 <code>auth.users</code> 多一個 <code>line.…@fff.local</code> 帳號並完成登入；電腦一般瀏覽器開 → 只顯示「瀏覽模式」，課表照常看得到。<br><br><b>踩過的坑</b>：Supabase 文件說 <code>token_hash</code> 要配 <code>type:\'email\'</code>，但 <code>generateLink({type:\'magiclink\'})</code> 產出的 hash 用 <code>magiclink</code>、<code>email</code>、<code>recovery</code> 三種都通得過，只有 <code>signup</code> 會被拒。這是用探針對正式專案實測出來的，不是查文件推論的。' },

        { n:32, t:'手機綁定流程', where:'前端', done:true,
          summary:'說明 ＋ 完成判準',
          body:'客人第一次開 LIFF → 輸入手機 → 比對第三幕匯入的名單 → 寫入 <code>line_user_id</code>。<br><code>customers.phone</code> 設成 unique 就是為了這一刻。',
          ck:'用你自己的 LINE 綁定成功，第二次打開直接認得你。',
          note:'<b>2026-08-11 完成。</b><br>檔案：<code>supabase/functions/line-bind/index.ts</code>、<code>line-prototype/liff-bind.js</code>、<code>db/12-grants.sql</code>。<br><br><b>決定：查無此人一律擋下來，不自動建客人。</b>建客人的路徑從頭到尾只有櫃檯一條 —— 因為新客幾乎都是老客人口碑帶來的，會走進門，櫃檯一定遇得到。自動建人只會換來「打錯一碼就佔走別人號碼」這種最難查的問題。<br>驗證條件是<b>手機 ＋ 姓名兩個都對</b>（84 筆的手機和姓名都不重複）。手機查無和姓名對不上回<b>同一句話</b> —— 分開講的話，這支就變成「輸入手機查姓名」的工具。<br><br><b>被擋的人不會消失</b>：資料留進 <code>signup_requests</code>（留言簿，不是待審佇列，永遠不會自動變成客人），畫面直呼其名，並給一顆 <code>line.me/R/oaMessage</code> 按鈕 —— 一按就開啟官方帳號聊天室、訊息已經打好，送出後 OA 的自動回應三秒內回他。<br><br><b>攻擊測試 20 項全過</b>：沒憑證／假憑證／非 LINE 身分的憑證／格式錯／查無此人／手機對姓名錯（不洩漏真名）／停用客人／重複綁／同一支 LINE 改綁別人／另一支 LINE 搶已綁的客人。並驗證綁完後客人用自己的憑證查 <code>customers</code> 只看得到自己 1 筆、查 <code>signup_requests</code> 得到 0 筆。<br><br>☢️ <b>途中挖到一個比這一步嚴重得多的洞，見附錄六。</b>' },

        { n:33, t:'打開真正的訂課', where:'前端', done:true,
          summary:'說明 ＋ 完成判準',
          body:'寫入 <code>bookings</code>、取消時限靠 RLS 擋（<b>不是靠前端藏按鈕</b>）、額滿只跳提醒不硬擋。<br>順便：查課卡餘額、看自己的課、取消自己的課。<br><br><b>☢️ 2026-08-11 從舊系統的公告發現的既有規則：</b>「請學員於<b>前一日午夜 12 點前</b>完成課程預約」、「來不及的話現場掃 QR code 補報名核銷」。<br>這條規則跟 <code>daily_class_job()</code> 在台灣時間 00:00 結算<b>剛好對得起來</b> —— 所以訂課的規則可以寫得很乾淨：<b>只能訂 <code>status = pending</code> 的課</b>。當天的課在 00:00 就已經變成 confirmed 或 cancelled，自然訂不到，不需要另外寫一條時間判斷。現場補報名走第 39 步的核銷頁。<br><br><b>☢️ 權限會再撞一次牆：</b><code>db/12-grants.sql</code> 只開了 <code>authenticated</code> 對 <code>customers</code> 和 <code>signup_requests</code> 的權限。<code>bookings</code>、<code>credit_ledger</code>、<code>class_sessions</code>、<code>customer_credits</code> 是<b>故意沒開的</b> —— 要跟訂課邏輯一起測。看到 <code>permission denied</code> 是預期的，不是壞掉；照 12-grants 的寫法補。',
          ck:'你用手機訂一堂課，Supabase 裡真的多一筆；取消之後人數退回去；取消過的同一堂再訂一次，還是同一筆（不是新增第二筆）。',
          note:'<b>2026-08-11 完成。</b><br>檔案：<code>db/13-booking.sql</code>、<code>line-prototype/GT-booking.html</code>。<br><br><b>☢️ 兩個開關收成一個了。</b>原本要記得同時改前端的 <code>BOOKING_OPEN</code> 和排程裡的 <code>v_auto_cancel</code> —— 兩個地方、靠人記得、忘了不會報錯。而且<b>前端那個旗標本來就擋不住任何人</b>，真正的門是 RLS，前端只是不畫按鈕。<br>現在資料庫裡有一列 <code>app_settings.live</code>，RLS、排程、前端三邊都讀它。<b>上線那天只要改那一列</b>（第 37 步）：<br><code>update app_settings set live = true where id = 1;</code><br><br><b>修掉的三個洞</b>（都是實際存在的）：<ul><li>UPDATE 政策只寫 using 沒寫 with check → 客人可以<b>把自己標成 attended</b>，第 39 步扣他的課、第 40 步算教練鐘點費，兩份帳一起被灌水</li><li>INSERT 沒檢查 <code>paid_by_customer_id</code> → <b>我報名、扣你的課卡</b></li><li>INSERT 完全沒看 session → 可以報名已取消的課、過去的課、甚至 PT 課次</li></ul><b>☢️ 還修掉一個差 8 小時的 bug。</b>原本「課前一小時」寫成 <code>(session_date + start_time)::timestamptz</code>，而資料庫時區是 UTC —— 那個寫法把「台灣 19:00」當成「UTC 19:00」。客人可以在課<b>上完 7 小時之後</b>才取消，而且系統覺得完全合法。正解是 <code>at time zone \'Asia/Taipei\'</code>。<br><br><b>驗證</b>：資料庫攻擊測試 21 項全過、前端 Playwright 11 種情境全過、實機把開關打開 40 分鐘走完訂課→取消→再訂的完整流程，測完關回 false。<br><br><b>做錯又改回來的一件事</b>：我一開始把「只能訂 pending 的課」寫進規則，結果當天已成立的課全部訂不了。第四節早就定案了：<b>「報名截止 = 當天 00:00 結算（不是關閉報名）」「當天仍可加入」</b>。現在擋的是<b>「已經開始」和「已取消」</b>，不是「已結算」。' },

        { n:34, t:'PT／PGT 頁改成「送出需求」', where:'前端', done:true,
          summary:'說明 ＋ 完成判準',
          body:'按鈕文字從「確認預約」改成「送出需求」，寫進 <code>pt_requests</code>。<br><b>私人課不是預約</b> —— 客人送需求，教練聯繫後才敲定。',
          ck:'送出一筆需求，<code>pt_requests</code> 裡看得到，而且沒有動到任何課堂名額。',
          note:'<b>2026-08-11 完成。</b><br>檔案：<code>line-prototype/pt-request.js</code>（兩頁共用）、<code>PT-booking.html</code>、<code>PGT-booking.html</code>、<code>index.html</code>（新）、<code>db/15-pt-requests.sql</code>。<br><br><b>決定：私人課頁不強迫綁定。</b>那是一張招生的頁，不是會員專區。<br><ul><li><b>已綁定的會員</b> → 直接寫進 <code>pt_requests</code></li><li><b>還沒綁定的人</b> → 開啟官方帳號聊天室，訊息已經幫他打好（規格、教練、時段、姓名、電話、備註全帶著）</li><li><b>用電腦的人</b> → 多一顆「複製內容」按鈕。桌機按 LINE 連結會被丟到 LINE 官網，填的東西就這樣蒸發 —— 這是實測踩到的</li></ul><b>教練的 uuid 不寫死在前端。</b>加了 <code>public_coaches</code> 檢視表（只給 id、對外顯示名、職稱 —— 本名和電話一個字都沒有）。寫死的話換教練或重建資料庫就對不上，而且<b>不會報錯，只會默默存成「未指定」</b>。<br><br><b>驗證</b>：Playwright 七種情境（含「不能碰到任何 <code>bookings</code>」）＋ 桌機複製退路 ＋ 實機從 LINE 送出一筆，資料庫欄位逐項對過（商品、規格、人數、教練 uuid、時段、備註、送出人），而且預約 62 筆、課次 109 筆、未來報名 8 人一動也沒動。<br><br>☢️ <b>途中挖到 LIFF 的一個大坑，見附錄六之八</b> —— 第 35 步做圖文選單前一定要先看。' },

        { n:35, t:'設定 LINE 圖文選單', where:'LINE後台', done:true,
          summary:'說明 ＋ 完成判準',
          body:'大門上的指示牌：訂課／我的課／剩幾堂／聯絡我們。<br><br><b>☢️ 每一個按鈕都必須用 LIFF 網址，不能用 GitHub Pages 的網址。</b><br><code>https://liff.line.me/2011063116-QOxXN30h/GT-booking.html</code><br><code>https://liff.line.me/2011063116-QOxXN30h/PT-booking.html</code><br><code>https://liff.line.me/2011063116-QOxXN30h/PGT-booking.html</code><br><br>直接用 <code>jerecyu.github.io/…</code> 的話，在 LINE 裡只是普通瀏覽器 —— <code>liff.isLoggedIn()</code> 會是 false，客人會被當成沒綁定的人。<b>不會報錯，只是功能默默降級。</b>2026-08-11 實測踩到，細節見附錄六之八。',
          ck:'「FFF 主選單」在後台存成草稿，六個動作都對：五個 liff.line.me 網址 ＋ 一個文字「我想詢問」。啟用是第 37 步的事。',
          note:'<b>2026-08-11 完成 —— 但只存成草稿，沒有啟用。</b><br>檔案：<code>assets/brand/fff-richmenu.png</code>（2500×1686，六宮格）、<code>line-prototype/GT-booking.html</code>（新增 <code>?tab=m</code>）。<br><br><b>六格分別是：</b><ul><li>團體課預約 → <code>GT-booking.html</code></li><li>我的預約 → <code>GT-booking.html?tab=m</code>（同一頁，直接落在「我的預約」分頁）</li><li>私人教練課 → <code>PT-booking.html</code></li><li>私人團體班 → <code>PGT-booking.html</code></li><li>價目表 → <code>pricing.html</code></li><li>聯絡我們 → <b>文字</b>「我想詢問」（接上第 32 步設好的自動回應）</li></ul>前五格全部是 <code>https://liff.line.me/2011063116-QOxXN30h/…</code> —— 規則 17。<br><br><b>☢️ 為什麼不啟用。</b>圖文選單一啟用，<b>203 位客人的入口當場全部改變</b>。而現在 <code>app_settings.live</code> 還是 false，他們會看到「線上訂課尚未開放」，同時舊系統的入口已經不見了 —— <b>等於當場斷掉所有人的訂課管道</b>。啟用排進第 37 步。<br><br><b>☢️ LINE 的一則錯誤訊息救了一次：</b>「此使用期間已設有其他圖文選單」。查出來舊選單「預約系統1.0」的使用期間排到 <b>2028/08/08</b>，動作是連到舊系統 <code>https://fusionforcefit.netlify.app/</code>。<b>切換日一定要先把它的結束日改成當天，新選單才擠得進去。</b>已寫進第 37 步。' },

        { n:36, t:'PT／PGT 上線第一段：客人資料 ＋ 期初餘額', where:'決定', done:false, kind:'decide',
          summary:'☢️ 2026-08-16 改寫：原本的「平行週」前提已經不成立',
          body:'<b>做這一步之前要先清掉三個阻塞：</b><ol><li><b>補齊 24 位客人的手機</b> —— 只補「還有剩餘堂數」的那些人。餘額 0、早就不來的不用建，哪天回來櫃檯當場建就好</li><li><b>從流水帳算出每個人的期初餘額</b>（15,860 筆已健康化，但進度欄有已知失真，要從異動加總，不能直接讀「已銷課堂數」）</li><li>☢️ <b><code>credit_ledger</code> 加一個 <code>spec</code> 欄位</b>，<code>customer_credits</code> 改成 <code>group by customer_id, product, spec</code>。<b>必須在塞資料之前做</b> —— 塞完再改，兩張卡已經合併了</li></ol><b>這一步不寫程式（除了第 3 項），是人工作業。</b><br><br>舊系統繼續在檯面上跑七天，新系統維持 <code>app_settings.live = false</code>。這七天你用舊系統的查詢功能，把 PT／PGT 客人補進新系統。<br><br><b>只補「還有剩餘堂數」的人。</b>餘額歸零的、早就不來的，一個都不用建 —— 他們哪天回來，櫃檯當場建檔就好。<br><br><b>第 1～6 天：建「人」</b><br>姓名 ＋ 手機，寫進 <code>customers</code>。<br>⚠️ 很多 PT 客人也買過 GT —— 那些人第 27 步就已經建好了，<b>不要重複建</b>（<code>phone</code> 是 unique，重複會直接報錯，這是好事）。<br><br><b>第 7 天：填餘額</b><br>每人一筆 <code>credit_ledger</code>：<code>reason=\'adjust\'</code>、<code>product=\'PT\'</code> 或 <code>\'PGT\'</code>、<code>note=\'系統上線前結轉\'</code>。',
          warn:'⚠️ <b>餘額是移動標靶。</b>這七天舊系統還在跑，有人買課有人上課 —— 你週一填的「剩 7 堂」，週五可能變 5 堂。<br><b>所以人和餘額要分開做：前六天建人（人不會變），最後一天才填數字。</b><br><br>⚠️ 這一步做完就<b>沒有回頭路</b>了。填完的隔天舊系統就要設唯讀，否則兩邊會同時被改。',
          ck:'每一個還有堂數的 PT／PGT 客人，在 <code>customer_credits</code> 查得到正確的 <code>product</code>、<code>spec</code> 和 <code>balance</code>，而且跟手工流水帳算出來的一致。',
          note:'<b>☢️ 2026-08-16 這一步整個改寫過。</b><br>原本的規格是「七天平行週：建人 ＋ 最後一天填餘額」，前提是 PT／PGT 會在切換日一起進系統。<b>那個前提沒有成立</b> —— 切換日只切了 GT，理由是資料還沒備齊：<ul><li><b>24 位客人沒有手機</b>，而 <code>customers.phone</code> 是 <code>not null</code>，建不進去</li><li>期初餘額還沒從流水帳算出來</li><li>☢️ <b>一個人可能同時有「一對二共用課卡」和「自己的一對一課卡」</b>，而 <code>customer_credits</code> 目前 <code>group by customer_id, product</code> —— 兩張卡的餘額會被加成一個數字，<b>而且再也分不開</b>（見附錄四 8-2）</li></ul>而且 2026-08-14～16 之間 PT／PGT 的規格本身也長大了：外派 ＋500 交通費、企業包班兩種基礎費、半堂 600、六種以上的優惠價、以及「<b>價格綁的是跟客人的關係，不是商品</b>」這條認知（附錄四第 7 節）。<br><br><b>所以這一步現在是「PT／PGT 上線」的第一段，不是一週的人工作業。</b>' },

        { n:37, t:'切換日：舊系統退場（GT）', where:'決定', done:true, kind:'decide',
          summary:'2026-08-16 17:00 完成 —— 只切 GT',
          body:'<b>挑哪一天：</b>第 36 步平行週結束的隔天。課最少的那天最好 —— 你的課表裡<b>週三只有一堂</b>（12:20 間歇有氧）。<br><b>前一週：</b>公告「X 月 X 日起改用新系統預約」。<br><br><b>當天照順序做，不要跳：</b><ul><li><b>①</b> <b>舊系統停止購課與消課</b> —— 先把帳凍住，後面每一步才有意義</li><li><b>②</b> 舊系統最後一次完整匯出（GT 那份）</li><li><b>③</b> 用第 26 步的工具產生 SQL</li><li><b>④</b> 清掉彩排資料，正式匯入 GT</li><li><b>⑤</b> <b>餘額逐筆對帳</b>（跟第 27 步同一套查詢）＋ 抽查幾個 PT 客人的結轉餘額</li><li><b>⑥</b> <b>打開新系統</b>：<code>update app_settings set live = true where id = 1;</code></li><li><b>⑦</b> <b>換圖文選單</b>（兩個動作，順序不能反）：<br>　<b>先</b>把舊選單「預約系統1.0」的使用期間結束日從 <b>2028/08/08</b> 改成<b>當天</b><br>　<b>再</b>啟用第 35 步存好的「FFF 主選單」草稿，使用期間從當天開始<br>不先改舊的，LINE 會擋：「此使用期間已設有其他圖文選單」</li><li><b>⑧</b> <b>舊系統設為唯讀，不要刪</b> —— 至少留三個月。要查切換前的紀錄，去那裡查</li><li><b>⑨</b> <b>換掉 LINE Channel secret</b>（2026-08-11 曾外洩到聊天室）。舊系統會用它推播課程訊息，所以不能提早換 —— 但舊系統退場的這一天，它就沒有理由再有效了。路徑：LINE Developers Console → 那個 Messaging API channel → Basic settings → Channel secret 的 Issue／重新發行</li></ul><b>☢️ ⑥ 一定要排在 ⑦ 前面 —— 先開門，再把指示牌指過來。</b>反過來的話，客人被帶到一個還沒開的系統，而舊系統的入口已經不見了。<br><br><b>關於 ⑥ 那一行：</b>它同時打開「客人可以訂課」和「午夜自動取消沒人報名的課」（第 33 步已經把兩個開關收成一個）。改完重新整理預約頁，按鈕就會從灰色變成「立即預約」——<b>前端不用改、不用重新 push</b>。<br>然後公告上線，發綁定指引給還沒綁 LINE 的人。',
          warn:'☢️ <b>先處理「已經報名未來課程」的那些人。</b><br>搬遷工具的日期上限固定在 <code>2026-08-06</code>（<code>pg_cron</code> 最早產生的課是 8/07）。所以<b>客人在舊系統報的、8/07 以後的課，一筆都不會自動進來</b> —— 那些課次在新系統是排程產生的，id 不一樣。<br>08-10 彩排時是 8 筆，到切換日會累積成幾十筆。<b>那天要按「日期 ＋ 時間」把它們對到我們自己的課次上</b>，人工或另外寫一小段 SQL 都行 —— 但不能漏掉，漏掉的人到現場會發現自己沒報到名。<br><br>⚠️ <b>這一天結束時，教練還不能在系統上點名核銷</b>（那是第 39 步）。中間這段期間扣課要你自己在 Table Editor 手動做，或先紙本記、之後補。<br><b>這是已知的取捨，不是疏漏</b> —— 早一點切換，就早一點停掉維護兩套系統的心力。<br><br>⚠️ <b>PT／PGT 的上課歷史從此只存在舊系統。</b>那是刻意的決定，不是漏掉的 —— 舊系統設唯讀就是為了這件事。',
          ck:'隔天早上，新系統的餘額跟前一天舊系統的最後畫面一致，而且舊系統再也沒有新資料進去。',
          note:'<b>☢️ 2026-08-16 完成 —— 但只切了 GT。</b><br>PT／PGT 繼續走已經健康化的 Excel，RT 另排。決定的理由和資料阻塞見第 36 步。<br><br><b>當天的時間軸（採納教練建議後改的）：</b><ul><li><b>11:00</b> 舊系統最後一堂課，照常點名消課（4 位學員）</li><li><b>12:54</b> 凍結 ＋ 最終匯出</li><li><b>13:00–14:10</b> 清彩排資料 → 匯入 → 逐筆對帳</li><li><b>16:30</b> 舊系統設唯讀</li><li><b>17:00</b> 開燈 → 圖文選單自動翻 → 發公告</li></ul><b>☢️ 切換時間從「早上」改成 17:00，是教練提的，而且他是對的。</b>17:00 本來就是舊系統「開放下週預約」的時刻 —— 把技術切換綁在客人腦子裡已經有的那條線上，公告從「我們換系統了，但今天的課還是舊的」變成「今天開放下週課表，同時改用新系統」。<br><b>而且他的建議逼出了一個排序錯誤</b>：原本「舊系統設唯讀」排在最後一步。在 17:00 的方案裡那會留下一個空窗 —— 舊系統放出下週課表、卻還沒唯讀，客人訂得進去、而那筆永遠不會進新系統。<b>客人手機上有「預約成功」，教練名單上沒有他，兩邊都不會報錯。</b><br><br><b>匯入結果：</b>客人 82 ／ 堂數流水 150 ／ 總堂數 561 ／ 歷史課次 73 ／ 預約 85。<br><b>對帳方式改用指紋比對</b>：把 82 個人的「手機:餘額」照順序串起來取 md5，兩邊一模一樣 —— <code>e89ebf8c…</code>。<b>只要有一個人差一堂，指紋就會完全不同。</b>比逐列看更嚴格，而且不會看漏。<br><br><b>途中擋下來的三件事：</b><ul><li>☢️ <b>舊系統的時間戳是 UTC</b>。直接寫進來整批會差 8 小時（又一次規則 16）</li><li>☢️ <b>舊系統允許同一人對同一堂課建立多筆預約</b>（Keira 一堂課九筆、Rosa 三筆 —— 連點造成的）。新系統的 <code>unique(session_id, customer_id)</code> 擋下來了。查證後確認<b>沒有造成重複扣課</b>，三個人的餘額都是對的，所以安全去重（96 → 85）</li><li>☢️ <b>林智謙與教練的封閉測試資料</b>（8 筆流水、淨額 +28 堂）—— 匯出前已由 Jerec 移除</li></ul>' }
      ]
    },

    /* ══════════ 第五幕 ══════════ */
    {
      key: 'a5', place: '前台櫃檯', no: '第五幕', name: '讓教練上工', theatre: '＝ 前台櫃檯數位化',
      note: '前面四幕都在服務觀眾，這一幕開始服務工作人員 —— 也是<b>往 ERP 的第一步</b>。<br><br>☢️ <b>2026-08-12 執行順序改了：38 → 39 → 36 → 37。</b>原本這一幕排在切換日之後，代價是「切換完成到第 39 步做好」那段期間，每一堂課的扣課都要人工在 Table Editor 補。而<b>餘額是客人唯一會逐筆核對的數字</b>，把它交給手工正好押在最不該出錯的時間點。先做 38、39，切換那天系統就是完整的：訂課 → 上課 → 扣課全在線上。<br>步驟編號<b>沒有跟著改</b>（改了整份文件的交叉引用會全部對不上）—— 第 36、37 步的卡片上有提醒。',
      steps: [
        { n:38, t:'六位教練用 LINE 登入，填回 employees.auth_user_id', where:'Supabase', done:true,
          summary:'說明 ＋ 完成判準',
          body:'教練從 LINE 開 <code>staff.html</code> → 拿到 Supabase 憑證 → 資料庫用 <code>auth.uid()</code> 對到 <code>employees.auth_user_id</code>，<code>is_staff()</code> 就是 true。<b>不需要密碼、不需要 email。</b><br><br>網址單獨發給六個人，<b>不要放進客人的圖文選單</b>：<br><code>https://liff.line.me/2011063116-QOxXN30h/staff.html</code>',
          ck:'六個人在 <code>employees</code> 都有 <code>auth_user_id</code>，而且各自在 staff.html 上看到的是<b>自己的名字</b>。',
          note:'<b>2026-08-12 完成。</b>檔案：<code>db/16-staff-access.sql</code>、<code>line-prototype/staff.html</code>、<code>migration-local/38-staff-activate.sql</code>。<br><br><b>決定：教練走 LINE 登入，跟客人同一道門。</b>六個人都沒有 email、也沒有電話，走密碼那條路要先跟每個人收 email、教他們記一組新密碼，而且忘記密碼的時刻剛好是他在現場要點名的時刻。LINE 這條路他們什麼都不用學。<br>教練開 <code>staff.html</code> → 畫面給一串登入代號 → 傳給你 → 你跑一行 SQL 開通。六個人、一次性，不值得為它寫一套綁定流程。<br><br><b>☢️ 途中挖到一個洞。</b><code>employees</code> 的讀取政策寫的是 <code>auth.uid() is not null</code> —— 「只要登入過就看得到整張表」，包括六個人的<b>本名、電話、email</b>。而登入過的人就是每一個從 LINE 進來的客人。<br>它當時沒有外洩，純粹是因為 <code>authenticated</code> 在那張表上<b>一個 GRANT 都沒有</b> —— 外面那道門本來就鎖著，裡面開多大都沒差。<b>而這一步就是要開外面那道門。</b>所以政策和 GRANT 一定要在同一支檔案裡改，分兩次做，中間那段時間全部客人都讀得到員工個資。<br><br>順手補了 <code>employees</code> 和 <code>customers</code> 兩條 UPDATE 政策的 <code>with check</code>（跟第 33 步 bookings 那個洞同一種）。<br><br><b>驗證</b>：切換身分實測 —— 沒開通的人查 <code>employees</code> 回 <b>0 列</b>、已開通的教練回 <b>6 列</b>且查得到自己是誰、<code>public_coaches</code> 對客人仍然正常 6 列。另外發現一道免費的保險絲：<code>auth_user_id</code> 有 foreign key 指向 <code>auth.users</code>，代號打錯一個字會直接報錯。' },

        { n:39, t:'課後點名核銷頁', where:'前端', done:true,
          summary:'說明 ＋ 完成判準',
          body:'教練在現場點名，扣課寫進 <code>credit_ledger</code>。<b>缺席不扣課</b> —— 這條規則寫在資料庫的 <code>check_in()</code> 裡，不是靠教練記得。<br><br>畫面以<b>手機直式</b>為主（下課前現場點完），櫃檯平板補登共用同一頁。課表上有一區<b>「還沒點完 · 過去 7 天」</b> —— 漏掉的當天就看得見。<br><code>https://liff.line.me/2011063116-QOxXN30h/checkin.html</code>',
          ck:'核銷一堂課，客人手機上的剩餘堂數當場少一堂；而且同一筆連點兩次，只會少一堂。',
          note:'<b>2026-08-12 完成。</b>檔案：<code>db/17-checkin.sql</code>、<code>line-prototype/checkin.html</code>。<br><br><b>☢️ 整步最重要的一件事：扣課只有一個入口。</b><br>教練對 <code>credit_ledger</code> <b>沒有任何權限</b>，也不能把預約直接改成 <code>attended</code>（兩條員工政策的 <code>with check</code> 裡都沒有這個值）。唯一的路是呼叫 <code>check_in()</code>。就算 <code>checkin.html</code> 哪天被改壞，也<b>寫不出一筆錯的帳，只會失敗</b>。<br><br><b>記帳寫成「對帳到目標」，不是「補一筆」。</b>出席 = 這筆預約淨扣 1 堂、缺席 = 淨扣 0 堂，實際差多少就補多少。所以連點兩次、出席改缺席再改回出席、網路重送 —— 最後淨額一定對。用「if 出席就扣一堂」那種寫法，每一種順序都要各想一次，想漏一種就是一筆爛帳。<br>更正走 <code>reason=\'adjust\'</code>，原始那筆永遠是 <code>\'class\'</code>，而且 <code>credit_ledger</code> 上有 partial unique index 保證<b>一筆預約只扣得了一次 class</b>。<br><br><b>三個當天定案的規則：</b><ul><li><b>剩 0 堂照扣，餘額可以是負的</b> —— 帳要誠實，他確實上了那堂課。畫面把那個人標紅，教練當場就知道要提醒課購。（擋下來的話，教練在現場被卡住，而下課時客人已經走了）</li><li><b>補登最多往回 7 天</b> —— 跨得過週末和連假。超過就找 Jerec 在後台處理，因為那時候「他到底有沒有來」已經是猜的了</li><li><b>可以現場加人</b> —— 老客人臨時出現這件事一定會發生。沒有這個功能，教練只能紙本記著等你補，而那張紙就是帳目開始對不起來的地方</li></ul><b>驗證</b>：資料庫五項攻擊測試（非員工點名／未來的課／已取消的課／超過 7 天／硬塞第二筆扣款）全部擋下，訊息都是人話；出席→再點一次→改缺席→改回出席，帳上 3 筆、淨扣 −1、餘額只少 1 堂。全部在 transaction 裡跑完 rollback，62 筆預約、117 筆帳<b>一列都沒動</b>。<br>前端 Playwright 37 項情境全過，含「這一頁不得出現 insert／update／delete，也不得碰 credit_ledger」。' },

        { n:40, t:'教練鐘點費月報表（GT 人頭費）', where:'SQL', done:true,
          summary:'為什麼它一定排在點名核銷後面',
          body:'規則寫在 <b>HANDOVER.md 附錄四</b>：1 人 200，第 2 人起每多一人 +100。<br><br><b>資料來源就是上一步的點名</b> —— 一堂課實到幾個人，鐘點費就是多少，<b>不需要任何額外輸入</b>。這就是當初決定「<code>payout</code> 不搬、改用算的」換來的東西。<br><br>做一張 <code>coach_monthly_payout</code> 檢視表：教練 × 月份 → 堂數、總人次、鐘點費合計。',
          warn:'⚠️ <b><code>n</code> 是「實到人數」，不是「報名人數」。</b>點名漏掉一個人，教練就少領 100 元 —— 這張報表的正確性<b>完全建立在上一步的點名紀律上</b>。<br><br>PT 的抽成（8 萬門檻、4:6 → 5:5）<b>不在這一步</b>，因為它需要每一堂 PT 都進系統。那是地平線那一段。',
          ck:'隨機挑一個月，報表算出來的金額跟你自己手算的一樣。',
          note:'<b>2026-08-12 完成。</b>檔案：<code>db/18-payout.sql</code>。<br>公式對照附錄四那張表，0～10 人全部相符。<br><br><b>☢️ 報表最右邊那一欄「還沒點名的課次」是它的良心。</b>不是 0 就代表這個月還沒點完，「鐘點費合計」是<b>少算的</b>，不能拿去發薪水。沒有那一欄的話，一張少算 1,100 元的報表和一張正確的報表<b>長得一模一樣</b>。<br><br><b>薪資只有本人和老闆看得到</b> —— <code>is_staff()</code> 在這裡不夠用，那會讓 Peter 看到 VC 領多少。用的是 <code>is_owner() or coach_id = my_employee_id()</code>，實測 Peter 只查得到自己那一列。<br><br><b>算的是實際點名結果，不是課次狀態</b> —— 搬遷資料裡有「課次 cancelled、但有人 attended」的組合，人既然上了課，教練就是帶了那一堂。<br><br>⚠️ <b>搬遷進來的歷史課次沒有教練</b>（<code>coach_id</code> 是空的），所以會掛在「（未指定教練）」底下。那段期間的鐘點費舊系統早就發過了，<b>發薪水時那一列直接略過</b>。' },

        { n:41, t:'教練端的私人課需求處理', where:'前端', done:false,
          summary:'說明 ＋ 完成判準',
          body:'看到 <code>pt_requests</code> 的待處理清單，聯繫客人、敲定時間、標記完成。',
          ck:'教練不用再翻 LINE 訊息找誰要約私人課。' },

        { n:42, t:'課前提醒推播', where:'SQL', done:false,
          summary:'說明 ＋ 完成判準',
          body:'Edge Function ＋ LINE Messaging API。',
          warn:'☢️ <b>2026-08-11 發現的阻礙：官方帳號和 LINE Login channel 不在同一個 Provider。</b><br>官方帳號的 Messaging API channel（<code>2009245280</code>）不在 <code>FUSIONFORCE</code> 裡，而 <code>Linked LINE Official Account</code> 的下拉選單是空的 —— <b>跨 Provider 綁不起來</b>。<br><br><b>後果：</b>LIFF 拿到的 userId 跟 Messaging API 的 userId <b>不是同一組</b>，所以<b>推播找不到人</b>。<br>訂課、綁定、入帳、報表、圖文選單<b>全部不受影響</b> —— 只有這一步。<br><br><b>☢️ 2026-08-11 續查：那個 Provider 拿不回來了，而且是永久的。</b><br>官方文件寫死：<i>「Channels can\'t be moved to a different provider later.」</i>channel 建在哪個 provider 就永遠在那裡，官方帳號轉手時 channel 不會跟著走。林智謙跟你並列 <code>FUSIONFORCE</code> 的 Admin，他也拿不到 —— 這個官方帳號經過好幾手，provider 在某位前手的帳號底下。<br><br><b>✅ 但同一天發現：不需要那個 Provider 也做得到。</b><br>OA 後台「設定 → Messaging API」那一頁其實已經給了全部需要的東西：<b>Channel ID ＋ Channel secret</b>（看得到、複製得到）和 <b>Webhook 網址</b>（可編輯，目前是空的）。<br><ul><li><code>POST /oauth2/v3/token</code> 帶 <code>grant_type=client_credentials</code> ＋ Channel ID ＋ secret → 換到存取權杖。<b>推播 API 就能用了</b>（長期權杖才需要 Console，我們用短期的，每次排程前重換）</li><li>設 Webhook → 收得到訊息事件，事件裡帶的就是<b>官方帳號那一組 userId</b></li></ul><b>兩組 ID 之間的橋：</b>客人綁定完成後，畫面給一顆 <code>line.me/R/oaMessage</code> 按鈕，預填訊息裡帶一個一次性短碼。他按送出 → webhook 收到「這則訊息的 userId ＋ 那個短碼」→ 把兩組 ID 對起來，寫進 <code>customers.push_user_id</code>（要加的新欄位）。<b>全程不需要 Developers Console。</b><br><br><b>☢️ 那把 Channel secret 換不掉。</b>換發只能在 Developers Console。它在 2026-08-11 的對話截圖裡外洩過一次（沒有貼上公開網路）。風險是：有人能用你官方帳號的名義推訊息給那 203 位好友。哪天真的出事，唯一的解法是換一個官方帳號。<br><br>這一條同時是<b>架構失效警訊</b> —— 需要頻繁自動通知，就代表 GitHub Pages 這套開始不夠用了，該考慮搬去 Cloudflare 或更完整的系統鏈。',
          ck:'課前一小時，報名的人收到 LINE 提醒。' },

        { n:43, t:'停課異動只通知那堂課的人', where:'SQL', done:false,
          summary:'為什麼這是一步，不是一個小優化',
          body:'「⚠️團課異動⚠️」現在是<b>群發給全部 204 位好友</b>，但真正需要知道的只有訂了那一堂的<b>那幾個人</b>。<br><br><b>2026-08-16 查到的實際數字：</b>方案是中用量，每月 3,000 則；8/01～8/16 已經用掉 <b>2,217 則（74%）</b>，平均 <b>1.5 天一次群發</b>，而群發是<b>按好友人數計費</b>的 —— 一次就是 204 則。<br><br>剩下的 783 則約等於 <b>3.8 次</b>，八月卻還有 15 天。<b>照這個節奏大約 8/22 用完，而中用量不能加購</b>（要買只能升到高用量 6,000 則）。<br><br>系統其實早就知道誰訂了哪一堂（<code>bookings</code> × <code>class_sessions</code>）。這一步就是把「發給 204 人」換成「發給 6 人」—— <b>成本掉到 1/34，而且訊息本身變得有意義</b>：收到的人真的需要改行程。',
          warn:'☢️ <b>這一步的依賴是第 42 步那座 userId 橋，不是新東西。</b>兩步共用同一套：<code>client_credentials</code> 換權杖 → webhook 收官方帳號那組 userId → 寫進 <code>customers.push_user_id</code>。42 做完之後，這一步只是換一個觸發點而已。<br><br>☢️ <b>但不要等 42。</b>在那之前教練就能手動做到八成：那堂課的名單在 <code>checkin.html</code> 看得到，<b>只通知那幾個人，不要驚動全部 204 人</b>。省下來的額度要留給真正全體適用的公告。<br><br>☢️ <b>通知對象有兩種，不要混在一起：</b><ul><li><b>客人</b> —— 教練臨時停課，有預約的人要知道</li><li><b>教練</b> —— 半夜的 <code>daily_class_job()</code> 會把沒人報名的課自動取消。那種課<b>沒有客人要通知</b>（本來就沒人訂），但<b>教練會白跑一趟</b></li></ul>第二種很容易被忘記，因為它不是人按出來的，<b>兩邊都不會報錯</b>。',
          ck:'一次停課，只有訂了那堂課的人收到通知，「群發訊息」的則數沒有被動用。' },

        { n:44, t:'逾期未核銷：教練自己的待辦', where:'前端', done:true,
          summary:'為什麼是「畫面」而不是「寄信」',
          body:'2026-08-17 Jerec 提的需求原話是：<i>「新增超過 2 個小時系統發 E-MAIL 提示給教練如何呢？也可以留作存證」</i>。<br><br>☢️ <b>存證和提醒是兩件事，混在一起會做出一個沒必要的東西。</b><ul><li><b>存證已經有了</b> —— <code>checked_at</code>／<code>checked_by</code> 一直在資料庫裡，而且改不掉。E-mail 不會讓證據更有效力。</li><li><b>缺的只有提醒</b> —— 也就是「把該點卻沒點的課算出來，讓人看得到」。</li></ul>而 E-mail 是三種提醒管道裡<b>唯一需要註冊第三方服務、驗證網域</b>的一種，能做到的事其他兩種都做得到。所以先做畫面。<br><br>做法：新增檢視表 <code>overdue_checkins</code>（課開始 2 小時後還有人是 <code>booked</code> 的課），<code>checkin.html</code> 一打開就在<b>課表最上面</b>用紅框擋住：「你有 N 堂還沒核銷」，點一下直接進那一堂的名單。',
          warn:'☢️ <b>不能從 <code>staff_sessions</code> 自己算。</b>那張檢視表的範圍寫死了「過去 7 天」，超過就<b>整堂消失</b> —— 而超過 7 天的那一筆正是最需要被看到的，因為 <code>check_in()</code> 也擋在 7 天，代表教練已經按不動了。所以另開一張沒有時間下限的 <code>overdue_checkins</code>。<br><br>☢️ <b>逾期清單讀不到，不能把整個課表擋掉。</b>它是提醒不是主功能，壞掉的時候要讓教練照樣點名。<br><br>☢️ <b>從逾期清單點進去的課，有可能不在 <code>SESSIONS</code> 裡。</b><code>openSession()</code> 原本找不到就 <code>return</code> —— 畫面<b>什麼都不會發生</b>，使用者只會覺得按鈕壞了。現在會講話。',
          note:'<b>2026-08-17 完成。</b><br>檔案：<code>db/23-overdue.sql</code>、<code>line-prototype/checkin.html</code>。<br>同一批還做了<b>「退回 N 堂」的標示</b>：教練問「核銷頁能不能有返還功能？舊系統有，因為會點錯點到別人的」—— 功能本來就在（「改成缺席」會把堂數退回去），但按鈕上<b>一個字都沒提到錢</b>，所以沒人知道那顆就是返還。<br>☢️ <b>修的是說明不是功能。</b>另外寫一支返還 RPC 會變成「兩條路都能改堂數」，正好違反第 39 步「動到錢的入口只有一個」。',
          ck:'課開始 2 小時後還有人沒點名，教練一打開核銷頁就被紅框擋住，點一下就能進去補。' },

        { n:45, t:'逾期未核銷：Jerec 的全館清單', where:'前端', done:true,
          summary:'說明 ＋ 完成判準',
          body:'第 44 步讓每位教練看到<b>自己的</b>。這一步讓 Jerec 看到<b>其他人的</b> —— 同一頁往下一格，橘色框，多一欄教練名字。<br><br>這其實就是舊流程的線上版。Jerec 2026-08-16 的原話：<i>「一旦發現有教練沒有登打、簽名、或收款紀錄缺失，就要馬上聯絡教練釐清資訊落差」</i>。差別只在於「發現」這個動作以前要翻紙本，現在是打開頁面就看到。',
          warn:'☢️ <b>一般教練看不到別人的。</b>別人的待辦對他只是雜訊，而且那不是他能處理的事 —— 條件是 <code>role === \'owner\'</code>。<br><br>☢️ <b>超過 7 天的那幾筆不做成按鈕。</b><code>check_in()</code> 擋在 7 天，做成按鈕會按了沒反應 —— 那比「不能按」更糟。改成顯示「要找 Jerec」。<br><br>☢️ <b>已取消但還有人掛在上面的課也要出現。</b>教練點不了名（<code>check_in()</code> 會擋），但人是真的來了或真的沒來，帳掛在那裡。藏起來的話那幾個人就永遠不見了。',
          note:'<b>2026-08-17 完成。</b>檔案同第 44 步。<br><br>下一階段（還沒做）：<ul><li>教練綁定 LINE 之後，把這份清單改成<b>推播</b>（6 位教練一個月十幾則，額度上完全不是問題）</li><li>E-mail 排最後 —— 它需要第三方服務，而且能做到的事上面兩種都做得到</li></ul>',
          ck:'Jerec 打開核銷頁，一眼看到全館哪幾堂沒點完、是誰的課、逾期多久。' }
      ]
    }
  ],

  /* ── 地平線：ERP（刻意不編號、不排序） ──────────────────────── */
  horizon: [
    { t:'金流與電子發票',   d:'一碰這個就必須搬離 GitHub Pages —— 條款明確禁止，沒有討論空間' },
    { t:'教練排班與 PT 抽成薪資', d:'GT 人頭費第 40 步就做掉了。這裡剩下的是 PT 的 8 萬門檻抽成 —— 它需要每一堂 PT 都進系統' },
    { t:'私人課 PT／PGT 完整流程', d:'目前只有 pt_requests（需求單）。要算抽成就得有「實際上了哪幾堂、每堂賣多少」' },
    { t:'場地租借 RT',       d:'第一階段只預留 product 欄位。真的要做時，關鍵是「場地佔用」要跟課排在同一本行事曆上，不然會撞場' },
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
      clearAt:28, how:'hand' },
    { n:3, t:'在有客人之前，每天的課都會被自動取消',
      d:'這不是錯誤，是照規則正確運作。<code>bookings</code> 空的 → 每天 00:00 判定「無人報名 → 取消」。看到一整排 <code>cancelled</code> 不用緊張。',
      clearAt:33, how:'auto' }
  ],

  /* ── 不可違反的規則（挑出接下來最容易踩到的） ────────────────── */
  rules: [
    { t:'每建一張資料表，立刻開 RLS 並寫至少一條規則', at:'建檢視表時同樣適用' },
    { t:'<code>sb_secret_</code> 絕不可出現在前端', at:'第 18 步唯一要盯的事' },
    { t:'前端隱藏不是安全', at:'第 33 步的取消時限要寫在 RLS，不是靠藏按鈕' },
    { t:'塞資料的 SQL 一律加保險絲，備份檔和 Supabase 分頁兩邊都要', at:'第 27 步' },
    { t:'按 Run 之前先看按鈕寫 <code>Run</code> 還是 <code>Run selected</code>', at:'整張跑和只跑反白的差很多' },
    { t:'含個資的 SQL 絕不放進 <code>db/</code>', at:'那個資料夾是版控的，而且 repo 是公開的（第 26 步）' },
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
