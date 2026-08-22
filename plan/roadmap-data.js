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
    updated: '2026-08-22 · 路線圖插入「私人課完整流程」為第 93 步，月結 94、損益表 95（共 95 步）',
    phaseName: '劇院建造進度 · 第一～八幕',
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
          body:'取消期限課前 1 小時｜報名截止是當天 00:00 <b>結算</b>（不是關閉報名）｜缺席不扣課｜扣課時機在課後由教練現場點名核銷｜同時預約無上限｜剩 0 堂也能預約，到現場再購課｜不做候補｜額滿不硬擋，跳提醒「已額滿，現場座位需與教練確認」｜私人課是客人送需求、教練聯繫敲定，不是預約。' },

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

        { n:36, t:'PT／PGT 上線第一段：客人資料 ＋ 期初餘額', where:'決定 ＋ 資料庫', done:true, kind:'decide',
          summary:'☢️ 2026-08-16 改寫：原本的「平行週」前提已經不成立',
          body:'<b>做這一步之前要先清掉三個阻塞：</b><ol><li><b>補齊 24 位客人的手機</b> —— 只補「還有剩餘堂數」的那些人。餘額 0、早就不來的不用建，哪天回來櫃檯當場建就好</li><li><b>從流水帳算出每個人的期初餘額</b>（15,860 筆已健康化，但進度欄有已知失真，要從異動加總，不能直接讀「已銷課堂數」）</li><li>☢️ <b><code>credit_ledger</code> 加一個 <code>spec</code> 欄位</b>，<code>customer_credits</code> 改成 <code>group by customer_id, product, spec</code>。<b>必須在塞資料之前做</b> —— 塞完再改，兩張卡已經合併了</li></ol><b>這一步不寫程式（除了第 3 項），是人工作業。</b><br><br>舊系統繼續在檯面上跑七天，新系統維持 <code>app_settings.live = false</code>。這七天你用舊系統的查詢功能，把 PT／PGT 客人補進新系統。<br><br><b>只補「還有剩餘堂數」的人。</b>餘額歸零的、早就不來的，一個都不用建 —— 他們哪天回來，櫃檯當場建檔就好。<br><br><b>第 1～6 天：建「人」</b><br>姓名 ＋ 手機，寫進 <code>customers</code>。<br>⚠️ 很多 PT 客人也買過 GT —— 那些人第 27 步就已經建好了，<b>不要重複建</b>（<code>phone</code> 是 unique，重複會直接報錯，這是好事）。<br><br><b>第 7 天：填餘額</b><br>每人一筆 <code>credit_ledger</code>：<code>reason=\'adjust\'</code>、<code>product=\'PT\'</code> 或 <code>\'PGT\'</code>、<code>note=\'系統上線前結轉\'</code>。',
          warn:'⚠️ <b>餘額是移動標靶。</b>這七天舊系統還在跑，有人買課有人上課 —— 你週一填的「剩 7 堂」，週五可能變 5 堂。<br><b>所以人和餘額要分開做：前六天建人（人不會變），最後一天才填數字。</b><br><br>⚠️ 這一步做完就<b>沒有回頭路</b>了。填完的隔天舊系統就要設唯讀，否則兩邊會同時被改。',
          ck:'每一個還有堂數的 PT／PGT 客人，在 <code>customer_credits</code> 查得到正確的 <code>product</code>、<code>spec</code> 和 <code>balance</code>，而且跟手工流水帳算出來的一致。',
          note:'<b>☢️ 2026-08-16 這一步整個改寫過。</b><br>原本的規格是「七天平行週：建人 ＋ 最後一天填餘額」，前提是 PT／PGT 會在切換日一起進系統。<b>那個前提沒有成立</b> —— 切換日只切了 GT，理由是資料還沒備齊：<ul><li><b>24 位客人沒有手機</b>，而 <code>customers.phone</code> 是 <code>not null</code>，建不進去</li><li>期初餘額還沒從流水帳算出來</li><li>☢️ <b>一個人可能同時有「一對二共用課卡」和「自己的一對一課卡」</b>，而 <code>customer_credits</code> 目前 <code>group by customer_id, product</code> —— 兩張卡的餘額會被加成一個數字，<b>而且再也分不開</b>（見附錄四 8-2）</li></ul>而且 2026-08-14～16 之間 PT／PGT 的規格本身也長大了：外派 ＋500 交通費、企業包班兩種基礎費、半堂 600、六種以上的優惠價、以及「<b>價格綁的是跟客人的關係，不是商品</b>」這條認知（附錄四第 7 節）。<br><br><b>所以這一步現在是「PT／PGT 上線」的第一段，不是一週的人工作業。</b><br><br><b>☢️ 2026-08-21 完成 —— 卡了五天。</b>檔案：<code>db/59-client-code.sql</code>（新）、<code>local/59-clients-import.sql</code> 與 <code>local/59-name-map.sql</code>（資料，不進 Git）。<br><br><b>解法跟原規格完全不同</b>：不是「七天平行週人工建人」，是 Jerec 交出一份《Active Client List V2》（155 位活躍客人，含客戶編號、姓名、暱稱、手機、負責教練），然後一次匯入。<b>客人數 95 → 223</b>（新建 128、掛到既有 27），八月 231 筆服務紀錄的 <code>customer_id</code> <b>全數回填</b>，0 筆孤兒。<br><br>☢️ <b>三個當初的阻塞是這樣拆掉的</b>：① 沒手機的人 —— 第 87 步讓 <code>phone</code> 可為空，18 位留空而不是塞假號碼。② 期初餘額 —— <b>沒有做</b>，改由第 86 步逐筆匯入八月的服務紀錄取代；PT 預收餘額留到「私人課完整流程」再處理。③ <code>spec</code> 欄位 —— 不需要了，第 73 步的 <code>plans</code> 已經用 <code>headcount</code> ＋ <code>product_code</code> 分得開一對一和一對二。<br><br>☢️ <b>比對的橋是 Jerec 自己寫的</b>：V2 備註欄的「同PT流水帳-學員資料[⋯]」。流水帳裡 121 種學員寫法，有 25 種不是完整姓名（貴婦團／新貴婦團／Merlinda貴婦團 三個人的暱稱都是 Ladies Group）—— <b>沒有那一欄，這些只能用猜的</b>。<br><br>☢️ <b>匯入工具第一次跑就炸了，而且只炸沒手機的那 18 位</b>：plpgsql 的 <code>record</code> 變數在被 SELECT INTO 指派之前<b>沒有欄位結構</b>，<code>v_exist := null</code> 給不了它結構。有手機的全部會過，沒手機的一列都進不來 —— <b>如果名單裡剛好每個人都有手機，這支會一路正常，直到某天第一個沒手機的人出現</b>。改用純量變數。' },

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
      note: '前面四幕都在服務觀眾，這一幕開始服務工作人員 —— 也是<b>往 ERP 的第一步</b>。<br><br>☢️ <b>2026-08-12 執行順序改了：38 → 39 → 36 → 37。</b>原本這一幕排在切換日之後，代價是「切換完成到第 39 步做好」那段期間，每一堂課的扣課都要人工在 Table Editor 補。而<b>餘額是客人唯一會逐筆核對的數字</b>，把它交給手工正好押在最不該出錯的時間點。先做 38、39，切換那天系統就是完整的：訂課 → 上課 → 扣課全在線上。<br>步驟編號<b>沒有跟著改</b>（改了整份文件的交叉引用會全部對不上）—— 第 36、37 步的卡片上有提醒。<br><br>☢️ <b>這一幕有一半是「開演之後才看得到的毛病」</b>（第 53 步以後）：手機排版、憑證過期、桌機的登出鍵、圖文選單、價格散在五個地方。<b>那些在沒有觀眾的時候一個都不會出現。</b>',
      milestone: {
        title: '▲ 第五幕結束 — 你現在擁有的',
        text: '教練用 LINE 就能上工：現場點名、逾期未核銷的待辦、掃碼共同確認、櫃檯建客人、購課入帳。<b>從訂課到扣課到收錢，全部在線上，沒有一段要人工補。</b>☢️ 這一幕留下兩步暫緩：第 41 步（私人課需求畫面）和第 42 步（課前提醒推播）。'
      },
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
          note:'<b>2026-08-12 完成。</b>檔案：<code>db/17-checkin.sql</code>、<code>line-prototype/checkin.html</code>。<br><br><b>☢️ 整步最重要的一件事：扣課只有一個入口。</b><br>教練對 <code>credit_ledger</code> <b>沒有任何權限</b>，也不能把預約直接改成 <code>attended</code>（兩條員工政策的 <code>with check</code> 裡都沒有這個值）。唯一的路是呼叫 <code>check_in()</code>。就算 <code>checkin.html</code> 哪天被改壞，也<b>寫不出一筆錯的帳，只會失敗</b>。<br><br><b>記帳寫成「對帳到目標」，不是「補一筆」。</b>出席 = 這筆預約淨扣 1 堂、缺席 = 淨扣 0 堂，實際差多少就補多少。所以連點兩次、出席改缺席再改回出席、網路重送 —— 最後淨額一定對。用「if 出席就扣一堂」那種寫法，每一種順序都要各想一次，想漏一種就是一筆爛帳。<br>更正走 <code>reason=\'adjust\'</code>，原始那筆永遠是 <code>\'class\'</code>，而且 <code>credit_ledger</code> 上有 partial unique index 保證<b>一筆預約只扣得了一次 class</b>。<br><br><b>三個當天定案的規則：</b><ul><li><b>剩 0 堂照扣，餘額可以是負的</b> —— 帳要誠實，他確實上了那堂課。畫面把那個人標紅，教練當場就知道要提醒購課。（擋下來的話，教練在現場被卡住，而下課時客人已經走了）</li><li><b>補登最多往回 7 天</b> —— 跨得過週末和連假。超過就找 Jerec 在後台處理，因為那時候「他到底有沒有來」已經是猜的了</li><li><b>可以現場加人</b> —— 老客人臨時出現這件事一定會發生。沒有這個功能，教練只能紙本記著等你補，而那張紙就是帳目開始對不起來的地方</li></ul><b>驗證</b>：資料庫五項攻擊測試（非員工點名／未來的課／已取消的課／超過 7 天／硬塞第二筆扣款）全部擋下，訊息都是人話；出席→再點一次→改缺席→改回出席，帳上 3 筆、淨扣 −1、餘額只少 1 堂。全部在 transaction 裡跑完 rollback，62 筆預約、117 筆帳<b>一列都沒動</b>。<br>前端 Playwright 37 項情境全過，含「這一頁不得出現 insert／update／delete，也不得碰 credit_ledger」。' },

        { n:40, t:'教練鐘點費月報表（GT 人頭費）', where:'SQL', done:true,
          summary:'為什麼它一定排在點名核銷後面',
          body:'規則寫在 <b>HANDOVER.md 附錄四</b>：1 人 200，第 2 人起每多一人 +100。<br><br><b>資料來源就是上一步的點名</b> —— 一堂課實到幾個人，鐘點費就是多少，<b>不需要任何額外輸入</b>。這就是當初決定「<code>payout</code> 不搬、改用算的」換來的東西。<br><br>做一張 <code>coach_monthly_payout</code> 檢視表：教練 × 月份 → 堂數、總人次、鐘點費合計。',
          warn:'⚠️ <b><code>n</code> 是「實到人數」，不是「報名人數」。</b>點名漏掉一個人，教練就少領 100 元 —— 這張報表的正確性<b>完全建立在上一步的點名紀律上</b>。<br><br>PT 的抽成（8 萬門檻、4:6 → 5:5）<b>不在這一步</b>，因為它需要每一堂 PT 都進系統。那是地平線那一段。',
          ck:'隨機挑一個月，報表算出來的金額跟你自己手算的一樣。',
          note:'<b>2026-08-12 完成。</b>檔案：<code>db/18-payout.sql</code>。<br>公式對照附錄四那張表，0～10 人全部相符。<br><br><b>☢️ 報表最右邊那一欄「還沒點名的課次」是它的良心。</b>不是 0 就代表這個月還沒點完，「鐘點費合計」是<b>少算的</b>，不能拿去發薪水。沒有那一欄的話，一張少算 1,100 元的報表和一張正確的報表<b>長得一模一樣</b>。<br><br><b>薪資只有本人和老闆看得到</b> —— <code>is_staff()</code> 在這裡不夠用，那會讓 Peter 看到 VC 領多少。用的是 <code>is_owner() or coach_id = my_employee_id()</code>，實測 Peter 只查得到自己那一列。<br><br><b>算的是實際點名結果，不是課次狀態</b> —— 搬遷資料裡有「課次 cancelled、但有人 attended」的組合，人既然上了課，教練就是帶了那一堂。<br><br>⚠️ <b>搬遷進來的歷史課次沒有教練</b>（<code>coach_id</code> 是空的），所以會掛在「（未指定教練）」底下。那段期間的鐘點費舊系統早就發過了，<b>發薪水時那一列直接略過</b>。' },

        { n:41, t:'教練端的私人課需求處理', where:'前端', done:false,
          defer:true, deferWhy:'沒有排進來，也沒有卡住。需求單還是進得來，只是教練得自己翻 LINE 找。',
          summary:'說明 ＋ 完成判準',
          body:'看到 <code>pt_requests</code> 的待處理清單，聯繫客人、敲定時間、標記完成。',
          ck:'教練不用再翻 LINE 訊息找誰要約私人課。' },

        { n:42, t:'課前提醒推播', where:'SQL', done:false,
          defer:true, deferWhy:'☢️ <b>已經解鎖了。</b>第 81 步把兩組 LINE ID 之間的橋架起來，推播找得到人了（停課通知就是走這條）。現在缺的只剩「課前一小時自動發」那段排程 —— 底下這段警告是解鎖<b>之前</b>寫的，留著當紀錄。',
          summary:'說明 ＋ 完成判準',
          body:'Edge Function ＋ LINE Messaging API。',
          warn:'☢️ <b>2026-08-11 發現的阻礙：官方帳號和 LINE Login channel 不在同一個 Provider。</b><br>官方帳號的 Messaging API channel（<code>2009245280</code>）不在 <code>FUSIONFORCE</code> 裡，而 <code>Linked LINE Official Account</code> 的下拉選單是空的 —— <b>跨 Provider 綁不起來</b>。<br><br><b>後果：</b>LIFF 拿到的 userId 跟 Messaging API 的 userId <b>不是同一組</b>，所以<b>推播找不到人</b>。<br>訂課、綁定、入帳、報表、圖文選單<b>全部不受影響</b> —— 只有這一步。<br><br><b>☢️ 2026-08-11 續查：那個 Provider 拿不回來了，而且是永久的。</b><br>官方文件寫死：<i>「Channels can\'t be moved to a different provider later.」</i>channel 建在哪個 provider 就永遠在那裡，官方帳號轉手時 channel 不會跟著走。林智謙跟你並列 <code>FUSIONFORCE</code> 的 Admin，他也拿不到 —— 這個官方帳號經過好幾手，provider 在某位前手的帳號底下。<br><br><b>✅ 但同一天發現：不需要那個 Provider 也做得到。</b><br>OA 後台「設定 → Messaging API」那一頁其實已經給了全部需要的東西：<b>Channel ID ＋ Channel secret</b>（看得到、複製得到）和 <b>Webhook 網址</b>（可編輯，目前是空的）。<br><ul><li><code>POST /oauth2/v3/token</code> 帶 <code>grant_type=client_credentials</code> ＋ Channel ID ＋ secret → 換到存取權杖。<b>推播 API 就能用了</b>（長期權杖才需要 Console，我們用短期的，每次排程前重換）</li><li>設 Webhook → 收得到訊息事件，事件裡帶的就是<b>官方帳號那一組 userId</b></li></ul><b>兩組 ID 之間的橋：</b>客人綁定完成後，畫面給一顆 <code>line.me/R/oaMessage</code> 按鈕，預填訊息裡帶一個一次性短碼。他按送出 → webhook 收到「這則訊息的 userId ＋ 那個短碼」→ 把兩組 ID 對起來，寫進 <code>customers.push_user_id</code>（要加的新欄位）。<b>全程不需要 Developers Console。</b><br><br><b>☢️ 那把 Channel secret 換不掉。</b>換發只能在 Developers Console。它在 2026-08-11 的對話截圖裡外洩過一次（沒有貼上公開網路）。風險是：有人能用你官方帳號的名義推訊息給那 203 位好友。哪天真的出事，唯一的解法是換一個官方帳號。<br><br>這一條同時是<b>架構失效警訊</b> —— 需要頻繁自動通知，就代表 GitHub Pages 這套開始不夠用了，該考慮搬去 Cloudflare 或更完整的系統鏈。',
          ck:'課前一小時，報名的人收到 LINE 提醒。' },

        { n:43, t:'停課異動只通知那堂課的人', where:'SQL', done:true,
          summary:'為什麼這是一步，不是一個小優化',
          body:'<b>☢️ 這一步在 2026-08-20 由<a href="#">第 81 步</a>做完了</b> —— 當時記在這裡的推估「8/22 額度用完」<b>是高估的</b>：實際到 8/20 只用掉 2,421/3,000，四天只增加 204 則（剛好一次群發）。切換到新系統之後群發次數本來就掉下來了。<br>但這一步該做還是做了，而且做完才發現真正的難題不是額度，是<b>兩組 LINE 編號不互通</b> —— 細節見第 81 步。<br><br>── 以下是 2026-08-16 當時的記錄 ──<br><br>「⚠️團課異動⚠️」現在是<b>群發給全部 204 位好友</b>，但真正需要知道的只有訂了那一堂的<b>那幾個人</b>。<br><br><b>2026-08-16 查到的實際數字：</b>方案是中用量，每月 3,000 則；8/01～8/16 已經用掉 <b>2,217 則（74%）</b>，平均 <b>1.5 天一次群發</b>，而群發是<b>按好友人數計費</b>的 —— 一次就是 204 則。<br><br>剩下的 783 則約等於 <b>3.8 次</b>，八月卻還有 15 天。<b>照這個節奏大約 8/22 用完，而中用量不能加購</b>（要買只能升到高用量 6,000 則）。<br><br>系統其實早就知道誰訂了哪一堂（<code>bookings</code> × <code>class_sessions</code>）。這一步就是把「發給 204 人」換成「發給 6 人」—— <b>成本掉到 1/34，而且訊息本身變得有意義</b>：收到的人真的需要改行程。',
          warn:'☢️ <b>這一步的依賴是第 42 步那座 userId 橋，不是新東西。</b>兩步共用同一套：<code>client_credentials</code> 換權杖 → webhook 收官方帳號那組 userId → 寫進 <code>customers.push_user_id</code>。42 做完之後，這一步只是換一個觸發點而已。<br><br>☢️ <b>但不要等 42。</b>在那之前教練就能手動做到八成：那堂課的名單在 <code>checkin.html</code> 看得到，<b>只通知那幾個人，不要驚動全部 204 人</b>。省下來的額度要留給真正全體適用的公告。<br><br>☢️ <b>通知對象有兩種，不要混在一起：</b><ul><li><b>客人</b> —— 教練臨時停課，有預約的人要知道</li><li><b>教練</b> —— 半夜的 <code>daily_class_job()</code> 會把沒人報名的課自動取消。那種課<b>沒有客人要通知</b>（本來就沒人訂），但<b>教練會白跑一趟</b></li></ul>第二種很容易被忘記，因為它不是人按出來的，<b>兩邊都不會報錯</b>。',
          note:'<b>2026-08-20 由第 81 步完成。</b>做出來的東西比這裡原本設想的多一層：<code>customers.push_user_id</code>（推播編號）、<code>push_links</code>（一次性短碼）、復活並改寫的 <code>line-hook</code>（驗簽 ＋ 對編號）、新的 <code>line-notify</code>（只發給那堂課的人）、後台的「停課／請假」，以及推不到的人會列成名單給櫃檯。<br>☢️ <b>原本以為只要「照 line_user_id 推過去」</b> —— 實際上那組編號推播 API 根本不認。',
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
          ck:'Jerec 打開核銷頁，一眼看到全館哪幾堂沒點完、是誰的課、逾期多久。' },

        { n:46, t:'到課共同確認（掃碼簽名）', where:'SQL ＋ 前端', done:true,
          summary:'它取代的是「教練和學員一起簽在紙上」那一個動作',
          body:'Jerec 2026-08-16 說得很清楚：<i>「舊系統時代是教練學員共同簽名在紙本上……新系統的角色就是要有共同確認的機制（取代原本紙本上的簽名）」</i>、<i>「重點是雙方手機與人都要在場，雖然還無法百分百安全，但已經大大提高鑽漏洞的成本」</i>。<br><br><b>怎麼運作：</b><ol><li>教練在名單頁按「出示確認碼」→ 資料庫發一張 <b>60 秒</b>過期的憑證，畫面上變成一個 QR</li><li>學員用<b>自己的手機</b>、在 LINE 裡掃那個碼</li><li>掃到的是 LIFF 網址 → 系統知道他是誰 → 只在<b>他自己那一筆</b>寫下 <code>confirmed_at</code></li></ol>教練的手機舉著不動，蓋板每 55 秒自己換一張新碼，所以一群人可以輪流掃。',
          warn:'☢️ <b>客人的確認【絕對不會】把 attended 打勾，也不會扣任何堂數。</b>否則客人就能自己扣自己的課 —— 那會打破第 39 步最重要的規則：<b>動到錢的入口只有一個，而且只有教練走得進去</b>。<code>confirm_attendance()</code> 和 <code>confirm_by_staff()</code> 都靜態驗過：兩支的 <code>update</code> 子句<b>只寫 confirmed_at 和 confirmed_by</b>，沒有一個字碰到 <code>credit_ledger</code> 或 <code>status</code>。<br><br>☢️ <b>確認不是核銷的前提。</b>客人手機沒電、忘了帶、當場不會用，課都還是要能結算。做成前提的話，第一次遇到沒電就會癱在現場，然後所有人就回去用紙了。所以有<b>教練代確認</b>這條路（<code>confirmed_by = \'staff\'</code>），而且畫面上 <b>qr 和 staff 長得不一樣</b> —— 一個是雙方在場，一個是教練單方說的，可信度本來就不同，不能混成同一種紀錄。<br><br>☢️ <b>QR 裡面一定是 LIFF 網址，不能是 github.io 的原始網址。</b>掃到原始網址的話，客人的瀏覽器裡沒有 LINE 身分，<code>my_customer_id()</code> 會是 null，確認必定失敗 —— 而且失敗得莫名其妙。<br><br>☢️ <b>憑證表沒有任何 select 政策</b>，誰都列不出憑證清單。它證明的是「掃的人當時看得到教練的螢幕」，不是「他真的上了課」。',
          note:'<b>2026-08-17 完成。</b><br>檔案：<code>db/19-attest.sql</code>（8/16）、<code>db/24-attest-ui.sql</code>、<code>line-prototype/checkin.html</code>、<code>line-prototype/confirm.html</code>、<code>line-prototype/GT-booking.html</code>。<br><br><b>☢️ QR 產生器是自己寫的，內嵌在 <code>checkin.html</code> 裡（約 13 KB）。</b>沒有用 CDN —— 這一頁是教練<b>在場邊、可能訊號很差的時候</b>要開的，多一個外部相依就多一個失敗點，而那個失敗點會剛好在最忙的三十秒發生。<br>只做 byte 模式、糾錯等級 M、版本 1～10。<b>驗證方式</b>：node 產生矩陣 → 畫成圖 → 用 OpenCV 的解碼器掃回來比對，<b>42 個案例（每個版本的容量邊界都測）全過</b>；再用 Playwright 把畫面上真正顯示的那個 QR 截下來解一次，確認掃出來就是正確的 LIFF 網址。<br><br><b>踩到的坑（三個，都是「不會報錯」那一種）：</b><ol><li><b>QR 格式資訊那 15 個位元的落點不是連續的</b>，中間會跳過時序圖案那一格。第一版寫錯 —— 圖看起來完全正常，只是<b>掃不出來</b>。</li><li><b><code>gen_random_bytes</code> 在線上不存在。</b>它來自 pgcrypto，而 Supabase 把 pgcrypto 裝在 <code>extensions</code> schema；這支函式的 <code>search_path</code> 鎖成 <code>public</code>（這是對的，不該為一個函式放寬）。☢️ <b>建立函式的時候 plpgsql 不會解析函式體，所以不會報錯</b> —— 只建立不呼叫等於沒測過。改用核心內建的 <code>gen_random_uuid()</code>，去掉連字號剛好也是 32 個十六進位字元，QR 版本和大小都不變。（<code>db/26</code>）</li><li><b>時窗外那顆按鈕還按得下去。</b>點名是課後 7 天內，確認碼是課後 2 小時內 —— 兩個時窗不一樣，所以會出現「還能點名、但發不出確認碼」。原本按下去才跳紅字，<b>按了才知道不能按等於按鈕在騙人</b>。改成時窗外直接不畫按鈕，改講一句「確認碼的時間已經過了，還有 N 位沒確認，可以用『幫他確認』」（這顆鍵 8/18 從「代確認」改名，見第 56 步）。</li></ol>',
          ck:'教練按「出示確認碼」，學員用自己的手機掃完，教練畫面上那個人變成「✓ 本人已確認」，而且<b>堂數一堂都沒有變</b>。' },

        { n:47, t:'修：檢視表被我改成 invoker，線上讀不到', where:'SQL ＋ 前端', done:true,
          summary:'一次真正的線上故障，以及它為什麼可以躲兩天',
          body:'<b>現場症狀</b>（2026-08-17 13:33）：教練點進課次名單 →「讀不到名單　<code>permission denied for table class_sessions</code>」。<br><br><b>原因：</b>我在第 19、20、23、24 支 SQL 裡把檢視表寫成 <code>create or replace view … with (security_invoker = true)</code>。而 <code>pg_get_viewdef()</code> <b>不會顯示這個選項</b> —— 我抄舊定義的時候只抄到 SELECT 的部分，看不出原本沒有這一行，就自己加了上去。<br><br>加上去等於改成「用查詢者的身分」讀底層資料表。而 <code>authenticated</code> 對 <code>class_sessions</code> 和 <code>credit_ledger</code> <b>是故意沒有 SELECT 權限的</b>（第 33 步就是這樣設計的）。所以整張檢視表讀不到。<br><br><b>這幾張本來就必須是 definer</b>：它們的牆是自己 <code>where</code> 裡那一行（<code>my_customer_id()</code> ／ <code>is_staff()</code>），不是底層權限 —— <code>13-booking.sql</code> 第 187 行原話就寫著「它用 definer 身分讀 class_sessions（客人自己讀不到）」。',
          warn:'☢️ <b>它可以躲兩天，是因為錯誤被前端吞掉了。</b><ul><li><code>GT-booking</code> 的「我的預約」：<code>if (b.error) console.error(…)</code> —— 錯誤只進主控台，畫面上 <code>myBookings</code> 還是空陣列，長得<b>跟「你沒有任何預約」一模一樣</b>。所以 <code>my_bookings</code> 從 <b>8/16 晚上就壞了</b>，一路沒人發現。</li><li><code>checkin</code> 的逾期清單更徹底：整段 catch 掉、設成空陣列 —— 剛做好的第 44、45 步<b>從來沒有真的運作過</b>，而畫面完全正常，看起來就像「沒有人逾期」。</li></ul>☢️ <b>而 <code>17-checkin.sql</code> 的驗收清單第 7-4 條早就寫著</b>：<code>staff_sessions</code> ／ <code>staff_roster</code> 兩列都必須是 definer ✓。<b>我自己寫的檢查，自己違反，而且改完沒有回頭跑那份清單。</b><br><br>☢️ <b>definer 會繞過 RLS</b>，所以改回去之後一定要重驗那道牆還在。已驗：一般客人的 <code>my_bookings</code> 混到別人的 <b>0 列</b>，<code>staff_roster</code>／<code>staff_sessions</code>／<code>overdue_checkins</code> 都是 <b>0 列</b>；換成 Jerec 的身分則讀得到 63 ／ 20 列。',
          note:'<b>2026-08-17 修好。</b>檔案：<code>db/25-fix-view-security.sql</code>，另外在 19、20、23、24 四支的那一行上面都加了警告 —— 那幾支重跑一次就會再壞一次。<br><br><b>結構上的修正（比修 bug 本身重要）：</b><ul><li>「我的預約」讀不到 → 畫面上明說「讀不到你的預約，這是系統的問題，不是你的資料不見了」，並附上錯誤訊息</li><li>核銷頁的逾期清單讀不到 → 頂端出現「逾期提醒暫時讀不到，課表和點名都正常」，附錯誤訊息</li></ul>☢️ 規則 14 本來就寫著「不要吞掉錯誤」。這次是<b>被自己的例外咬到</b> —— 那兩處都是我為了「壞掉也不要擋住主功能」刻意寫的 catch，而它們把故障藏了兩天。<b>不擋住主功能</b>和<b>不出聲</b>是兩件事。',
          ck:'教練點得進名單；客人看得到「我的預約」；任何一張檢視表壞掉的時候，畫面上會出現錯誤訊息，而不是一片空白。' },

        { n:48, t:'教練後台：新增客人與綁定診斷', where:'SQL ＋ 前端', done:true,
          summary:'難的不是建一筆資料，是查出他為什麼綁不上',
          body:'2026-08-17 林正明綁不上，查了半天才發現「他根本不在 82 人名單裡」。<b>真正花時間的是診斷，不是動作。</b>Jerec 接著問「遇到新客人告訴你就對了嗎」—— 答案是「現在對，但不該長期靠我」：新客人是走進門就要當場處理的事。<br><br>新增一頁 <code>staff-tools.html</code>（<code>staff.html</code> 和核銷頁都進得去），三塊：<ol><li><b>綁不上的人</b> —— 直接講出卡在哪：手機不在名單／手機對姓名對不上（並顯示登記姓名）／已被別支 LINE 綁走／客人被停用</li><li><b>新增客人</b> —— 姓名 ＋ 手機，留言簿那筆可以一鍵帶進表單</li><li><b>查客人</b> —— 姓名或手機後三碼 → 剩幾堂、綁定了沒</li></ol>',
          warn:'☢️ <b>這一頁完全不碰堂數。</b>Jerec 2026-08-17 的決定（原話）：<i>「舊系統……不只新增客人還直接可選購買方案，這會有『先上車，但不一定會補票』的問題，所以我選 1 不碰堂數，只建人」</i>。建出來的客人固定 <b>0 堂</b>，堂數走購課流程（C 第二期）。這同時守住第 39 步：<b>動到錢的入口只有一個</b>。<br><br>☢️ <b>「一鍵建客人」故意不做成一鍵。</b>按下去只是把留言簿那筆<b>帶進表單</b>，不直接建 —— 因為姓名那一欄正是最常出問題的地方，要讓教練有機會把「廖庭均 Teresa」改成「廖庭均」再送。<br><br>☢️ <b>登記姓名要短。</b>比對規則是「客人打的要<b>包含</b>登記姓名」：登記「王小明」，他打「王小明 Ming」也會過；登記「王小明 Ming」，他打「王小明」就<b>過不了</b>。8/17 卡住的兩個人都是這個原因，所以這句話直接寫在輸入框底下。<br><br>☢️ <b><code>customers</code> 沒有 INSERT 政策，只能走 <code>create_customer()</code></b> —— 這是刻意的。走函式才有地方擋「手機格式」「重複」「姓名少於兩個字」這三件事。姓名至少兩個字是硬性的：登記只有一個字（例如「王」）的話，<b>任何含「王」的名字都會通過綁定</b>。<br><br>☢️ 兩張新檢視表（<code>staff_signups</code>／<code>staff_customers</code>）都<b>不能</b>加 <code>security_invoker</code> —— 牆是 <code>is_staff()</code>，不是底層權限（第 47 步剛付過這個學費）。',
          note:'<b>2026-08-17 完成。</b>檔案：<code>db/28-staff-tools.sql</code>、<code>line-prototype/staff-tools.html</code>，並在 <code>staff.html</code> 和 <code>checkin.html</code> 加了入口。<br><br><b>驗證</b>：<code>create_customer</code> 靜態驗過不含 <code>credit_ledger</code>、有擋非員工；牆驗過（教練看得到 7 筆留言簿／83 位客人，一般客人兩張都是 <b>0</b>）；前端五種情況都跑過（帶入、重複手機、手機格式錯、姓名太短、建立成功），查客人的姓名與手機後三碼兩種查法也都對得上資料庫。<br><br><b>沒做的（刻意）：</b>改綁 LINE。<code>taken</code> 那一種畫面上直接寫「這個要找 Jerec，教練這邊改不了」—— 改綁等於可以把任何一位客人的身分轉移到任何一支手機上，那個權限不該散出去。',
          ck:'教練自己打開後台就知道某個客人為什麼綁不上，而且能當場把新客人建進去（0 堂）。' },

        { n:49, t:'購課入口：錢和堂數一起進系統', where:'SQL ＋ 前端', done:true,
          summary:'上線兩天，購課紀錄 0 筆',
          body:'2026-08-17 查到的數字：系統上線兩天，<code>credit_ledger</code> 裡<b>沒有任何一筆新的購課</b>（最後一筆是 8/15 搬遷時的）。同時有 <b>19 位</b>客人剩 0 堂、<b>8 位</b>剩 1～2 堂。<b>錢已經在收，只是沒進系統</b>，而第一個剩 0 堂的人來上課，帳就會變負。<br><br><b>Jerec 的三個決定：</b><ol><li><b>匯款先給堂數</b>，但標成「待入帳」—— 客人不會卡在現場訂不到課</li><li>付款方式只有兩種：<b>現金、匯款／轉帳</b></li><li><b>所有教練都能購課</b> —— 跟現場收錢的是同一批人，收完當場入帳最不容易漏</li></ol>做法：新增 <code>products</code> 表（GT 只有兩種：單堂 NT$400／買 10 送 2 NT$4,000），<code>credit_ledger</code> 加 <code>amount</code>／<code>pay_method</code>／<code>paid_at</code>／<code>product_code</code> 四欄，三支函式 <code>add_purchase</code>／<code>confirm_payment</code>／<code>void_purchase</code>，教練後台的「查客人」每一列多一顆<b>購課</b>。',
          warn:'☢️ <b>這是第二個能動到錢的入口</b>（第一個是 <code>check_in</code>），所以套用同一套規矩：只能走函式（資料表沒有 INSERT 政策）、每一筆都記 <code>created_by</code>、出錯用<b>沖銷</b>不用刪除。<br><br>☢️ <b>價格要跟著每一筆存下來，不能只存商品代號。</b>價目表會變，而查帳時唯一重要的是「<b>那一筆當時賣多少</b>」。<code>products</code> 只負責「現在賣多少」。<br><br>☢️ <b>待入帳不能只看 <code>paid_at is null</code>。</b>搬遷進來的 76 筆舊資料 <code>paid_at</code> 也是 null，但那是「我們不知道」不是「還沒收」。要同時看 <code>pay_method = \'transfer\'</code>。<br><br>☢️ <b>購課按錯 → 沖銷之後，那筆匯款會【留在待入帳清單裡】</b>—— 教練會去追一筆已經取消的錢。實測抓到，檢視表要排除沖銷過的。<br><br>☢️ <b>入帳成功之後不要整頁重畫。</b>第一版這樣寫，結果剛按完的「＋1 堂、現在剩 7 堂」連同搜尋結果一起被洗掉，教練會不確定自己到底有沒有按成功。只更新該更新的兩塊。',
          note:'<b>2026-08-17 完成。</b>檔案：<code>db/29-purchase.sql</code>、<code>line-prototype/staff-tools.html</code>。<br><br><b>畫面是兩段式的</b>：先點方案＋付款方式（2×2 四顆），再按「確定，入帳」。☢️ 一鍵直接入帳太快 —— 點名按錯只是堂數，這裡按錯是<b>錢和堂數一起錯</b>。<br><br><b>驗證</b>：在資料庫真的跑過一次完整流程（購課 → 沖銷），餘額回到原點；前端四種路徑都測過（現金、匯款、確認入帳、餘額就地更新）。☢️ 測試產生的兩筆已經刪掉 —— 「帳本只增不減」保護的是<b>真實營業紀錄</b>，不是我三十秒前造的測試資料，留著會讓月底出現一筆客人從來沒買過的 NT$4,000。<br><br><b>沖銷按鈕（同日補上）：</b>Jerec 調查過實際發生頻率 ——「有發生過但很稀有」—— 之後決定：<b>只有他能按、往回不限時間、原因必填</b>，而且要在按鈕旁邊寫清楚使用時機。<br>所以 <code>void_purchase</code> 從 <code>is_staff()</code> 收緊成 <code>is_owner()</code>，原因少於兩個字直接擋下來。<br><br>☢️ <b>畫面上最重要的不是那顆按鈕，是旁邊那段「什麼時候不要用」。</b>沖銷最大的風險不是被亂按，是<b>被用在不該用的地方</b> —— 特別是拿來當退費：那會讓帳上看起來退了、<b>錢其實還在店裡</b>。所以三個反例（退費／上到負數／匯款沒進來）跟三個正例並排寫在按鈕上方。<br>判準寫成一句話：<b>沖銷是在說「這件事根本沒發生過」；只要事情真的發生過，就不該用它。</b><br><br>沖銷完會給一段可以一鍵複製的紀錄（Jerec：「同時告訴你也可以，雙重保險」）。☢️ 這一段<b>不能被重畫洗掉</b> —— 第一版寫完就去重畫整個清單，結果那份保險連同輸入框一起消失。現在改成就地把那一列標成已沖銷。<br><br><b>還沒做的：</b>PT／PGT 的方案（要等第 36 步）、發票、以及「一個月沒入帳自動提醒」。',
          ck:'教練在現場收完錢，當場在後台幫客人加堂數，而且月底看得出每一筆是誰收的、收多少、進帳了沒。' },

        { n:50, t:'舊表孤兒：80 位、551 堂（已匯入）', where:'資料', done:true,
          summary:'搬遷漏掉的不是幾個人，是一整批',
          body:'2026-08-17 傍晚，林正明說他在舊系統有 10 堂、新系統查是 0。查下去發現他<b>根本不在 82 人名單裡</b>。<br><br>原因（Jerec 查到的）：<i>「舊系統創建人當初把那些資料未齊全但有購買課程的學員排除在舊系統之外，獨立在雲端上某個資料夾，交接給新系統卻忘記這些孤兒。」</i>—— 八月初的搬遷是從<b>舊系統</b>搬的，所以這批人從頭到尾沒有機會進來。<br><br><b>比對結果</b>（舊手工流水帳 154 人 vs 新系統 84 人）：<ul><li>完全對不到 <b>74 人</b>，其中<b>還有餘課的 65 人、合計 402 堂</b></li><li>疑似同一人（要人確認）15 組</li><li>兩邊都有但堂數不同 51 人</li></ul>☢️ <b>那 402 堂約等於新系統當時全部 556 堂的 72%</b>。付過錢卻訂不了課、查不到堂數的人，規模跟已經進系統的人差不多。今天卡在綁定的幾位（林正明 10 堂、吳明蒨 13 堂、林子翔 5 堂）都在這批裡 —— 他們不是綁定壞掉，是<b>系統裡根本沒有他們</b>。',
          warn:'☢️ <b>舊表停在 07/05，新系統含到 08/17 的實際上課</b>，所以「堂數對不上」那 51 人有一部分是正常的，不是錯誤清單。<br><br>☢️ <b>餘課那一欄是人工填的</b>：154 列裡有 <b>136 列</b>的 購入 − 上課 ≠ 餘課。不能拿前兩欄回推。<br><br>☢️ <b>兩邊沒有共同的手機號可以對，只能靠姓名</b>，所以機器比對必然不完美。已知假警報：舊表「陳荔芬」＝新系統「Adele」。這是為什麼交回來的表要人填「這是誰」，不能讓程式自己認。<br><br>☢️ <b>第一版比對表漏了「手機」欄</b> —— 舊手工帳裡完全沒有手機號碼，而 <code>customers.phone</code> 是必填且唯一。<b>沒有手機就建不了人，他也永遠綁不上。</b>在員工開始填之前發現，補了一欄。晚幾小時發現的話，整批要重做一次。',
          note:'<b>工具已經做好（<code>db/30-import-legacy.sql</code>），等名單。</b><br><br><code>import_legacy_credits(rows, dry_run)</code>：<ul><li><b>先驗全部，全對才寫</b> —— 一次進 65 個人，最危險的失敗是「做到一半」：前 30 個寫進去了、第 31 個手機重複而中斷，然後沒人知道停在哪；重跑會讓一部分人拿到兩倍堂數</li><li>擋四種錯：姓名少於兩個字／手機格式不對／堂數 ≤ 0／<b>同一批裡手機重複</b></li><li>預設是預演，要真的寫必須明確傳 <code>dry_run = false</code></li><li>回傳 <code>gt_before</code> / <code>gt_after</code> / <code>gt_delta</code> 當驗收</li></ul><b>實測</b>：故意放五種錯 → 回報 4 個錯誤、客人數 84 → 84（一列都沒寫）；真的寫兩筆 → 551 → 584（delta 33 ＝ 10+23）；清乾淨後回到 84 人／551 堂。<br><br>☢️ 金額欄留空 —— 我們確實不知道這些人當時付了多少錢，不要假裝知道。<br><br><b>2026-08-18 02:xx 完成匯入。</b>員工交回兩份名單，我先做交叉檢查，發現三個名單裡沒交代的缺口，Jerec 逐一裁決：<ul><li><b>第二種 6 位手機欄整欄空白</b>（33 堂）—— <code>customers.phone</code> 必填且唯一，沒有手機建不出客人。→ 改放封存區，補到手機再一鍵轉入。</li><li><b>「不是同一人」的 11 位（92 堂）三份名單都沒有</b> —— 他們是確認過的獨立客人，卻沒被分進任何一類。→ 全部放封存區。</li><li><b>封存名單裡 8 位堂數 ≤ 0</b>（4 位 0 堂、4 位負數合計 −14 堂）—— <code>legacy_credits</code> 有 <code>credits > 0</code> 的限制會擋下來。→ 兩種都略過，另外給一張留底清單。</li><li><b>「是同一人」的 4 位（28 堂）</b>不該建新客人也不該封存 —— 查出他們在系統裡的完整手機，走補堂數那一條。</li></ul><b>實際寫入</b>：<code>import_legacy_credits</code> 16 筆／139 堂（新建 5 人、既有 11 人只補堂數）；<code>import_legacy_vault</code> 64 筆／412 堂。客人 88 → <b>93</b>，GT 總堂數 551 → <b>690</b>，封存區 0 → <b>64 筆／412 堂</b>，三個數字都跟預演一致。',
          ck:'孤兒的堂數全部進系統：會回來的直接掛在他名下（+139 堂），不確定會不會回來的放封存區（412 堂）。'
          + '哪天走進門，教練查名字就會看到「封存區有他的 N 堂」，一鍵轉入。已經沒有任何一筆餘課只存在於 Excel 裡。' },

        { n:51, t:'封存堂數等候區', where:'SQL ＋ 前端', done:true,
          summary:'不是每個孤兒都要現在補齊 —— 但也不能留在檔案裡',
          body:'Jerec 整理孤兒名單時的實務判斷（原話）：<i>「資料中許多客人雖然留有剩餘堂數，但其實都不會再來消費了……不來的原因可能是長期移民、搬家、甚至不喜歡我們而不來，而這些變數是資料中不會知道的，只能人工判斷。」</i><br><br>所以 65 位分成三種：<ol><li><b>今天卡住綁定的</b> → 優先處理</li><li><b>近期有機會再來的</b> → 主動補齊手機並綁定（走第 50 步的匯入）</li><li><b>近期確定不會再來的</b> → <b>這一步</b>。資料先封存，堂數仍然有效，人出現時再調出來</li></ol>新增 <code>legacy_credits</code>：只有姓名和堂數，<b>不需要手機</b>、不是客人、不能訂課。人出現時教練按一下就把堂數轉進 <code>credit_ledger</code>。',
          warn:'☢️ <b>第三種絕對不能留在 Excel 裡。</b>孤兒之所以存在，就是因為當初有人把「資料不齊的人」放在系統<b>外面</b>的一個資料夾，交接時就忘了（第 50 步）。留在 Excel 等於用同樣的方式製造下一批孤兒 —— 只是這次是我們自己做的。所以他們進系統，只是不進 <code>customers</code>。<br><br>☢️ <b>而這張表真正的價值不是「存起來」，是【教練查名字時系統會自己講】。</b>只放在檔案裡的話，要靠人記得去翻 —— 而那正是失敗過一次的做法。所以教練在後台查客人時，名字對到封存區就會跳出一張卡：「封存區　王淑文　9 堂」，旁邊直接是「轉給 王淑文（222）」。<br><br>☢️ <b>封存前要先擋「這個人其實已經是客人」。</b>預演會拿名字比對現有客人（<code>name_close</code>），像的話警告 —— 已經是客人的話，堂數應該直接補給他，不該封存。<br><br>☢️ <b>領走之後那一筆不刪</b>，只標記被誰領走、什麼時候、誰經手。而且已領過的不能再領一次，否則同一筆堂數會被發兩份。',
          note:'<b>2026-08-17 完成。</b>檔案：<code>db/31-legacy-vault.sql</code>、<code>line-prototype/staff-tools.html</code>。<br><br><b>驗證</b>：預演正確警告「林屏玟 ↔ 系統裡的林屏妏（650）」；封存 8 堂 → 轉給林正明 → 0 變 8 堂；清乾淨後回到 0 筆／551 堂。<br>前端：查「王淑文」→ 系統裡沒這個人，但封存卡跳出來並提示「先建檔再回來轉」；建檔後同一個查詢就出現「轉給 王淑文（222）」，按下去餘額 0 → 9 堂、卡片變綠、按鈕鎖住；再查一次那筆封存不再出現。',
          ck:'近期不會再來的人資料留在系統裡而不是檔案裡；哪天他走進門，教練查名字就會看到「封存區有他的 N 堂」，一鍵轉入。' },
        { n:52, t:'教練後台重排 ＋ 全站箭頭', where:'前端', done:true,
          summary:'最常做的事被排在最後一個 —— 順序本身就是介面',
          body:'Jerec 2026-08-17 的反應（原話）：<i>「購課區似乎藏的太深，介面似乎不太直覺」</i>、<i>「按鈕上的字左右排序似乎反了」</i>、<i>「立即預約那四個字顏色太淡」</i>、<i>「箭頭符號太小，看起來像是圖片的雜訊」</i>。<br><br>四件事一起處理：<ol><li><b>教練後台重排</b>：舊順序是 待入帳 → 綁不上的人 → 新增客人 → 最近的購課 → 查客人／購課，量出來購課落在捲動 2600px 以下。新順序是 提醒條 → <b>購課</b> → 新增客人（收合）→ 待入帳 → 綁不上的人 → 最近的購課，購課移到距頁首 149px。</li><li><b>方案表改成表格</b>：列＝方案、欄＝現金／匯款。原本 4 顆按鈕把方案名寫兩次、付款方式縮在小字第二行。</li><li><b>官網按鈕</b>加進頂列。</li><li><b>全站箭頭</b>從「›」字元改成用兩條邊框畫的 V 形。</li><li><b>正名「課購」→「購課」</b>：全專案 61 處。</li></ol>',
          warn:'☢️ <b>警示往下移不等於可以看不見。</b>購課提到最上面之後，待入帳和綁不上的人都被推到第一屏之外 —— 所以最上面留一條提醒條，一行講完「還有幾件事」，按下去直接捲過去。沒事的時候整條不出現。<br><br>☢️ <b>「立即預約太淡」不是顏色調錯，是被蓋掉。</b><code>.nav-links a</code> 的特異度 (0,1,1) 大於 <code>.btn-1</code> 的 (0,1,0)，藍底上的白字被改成灰藍 <code>var(--dim)</code>。這條沒包在 media query 裡，所以<b>手機和電腦都中招</b>。只看 CSS 檔看不出來 —— 要量瀏覽器算完的 computed color（量到 rgb(84,114,138)）。<br><br>☢️ <b>斜切高光原本是 <code>::before</code>，會蓋在文字上面。</b>絕對定位的偽元素排在文字之後才畫。改成寫進 <code>background-image</code>（112deg 等同原本的 skewX(-22deg)），背景永遠在文字下面。<br><br>☢️ <b>箭頭「太小」只是一半，另一半是「太淡」。</b><code>var(--faint)</code> #8DA9B9 對白底只有 2.47:1，而圖形元素最低要 3:1。改成 <code>--blue</code>（4.11:1）。<br><br>☢️ <b>「按鈕上的字左右排序反了」指的是<u>兩個字本身</u>。</b>第一次我讀成兩顆按鈕的左右位置，猜錯了 —— Jerec 指著截圖說的是：<b>「課購」要寫成「購課」</b>。中文是動詞在前（購＝買、課＝課程），「課購」把它寫反了，而且他自己從頭到尾都說「購課區」。全專案 61 處一次改掉。<br>☢️ <b>教訓：使用者指著螢幕講的位置詞（左／右／上／下），先問是哪一層。</b>「按鈕上的字」可以是按鈕之間、也可以是字之間 —— 我挑了範圍大的那個去猜。<br><br>☢️ 順帶修掉的：點名核銷頁是 [← 課表][重新整理]（導覽在左），教練後台原本是 [重新整理][點名核銷]（導覽在右）。統一成導覽在左、重新整理固定最右。<br><br>☢️ <b>&lt;details&gt; 收合會把剛剛發生的事藏起來。</b>建完客人會重畫一次，成功訊息就跟著被收進去 —— 用一個變數記住展開狀態。這是同一個坑的第四次（第 44、47、49 步各一次）。',
          note:'<b>2026-08-17 完成。</b>檔案：<code>index.html</code>、<code>line-prototype/</code> 底下 8 支。<br><br><b>驗證</b>：Playwright 量測 —— 購課區距頁首 149px（原本 2600px 以下）；360px 窄機頂列三顆鍵同一列、不溢出；方案表欄頭「現金／匯款」、列頭「單堂／買10送2」、四顆金額有千分位；教練視角看不到沖銷鍵；17 個頁面／路由零 JS 錯誤、零橫向溢出、所有 <code>.btn-1</code> 白字都是 rgb(255,255,255)；23 顆箭頭全部 13×13px、對比 ≥3:1（原本 --faint 是 2.47:1）。<br><br>☢️ 順手補上：官網「聯絡我們」三張卡原本<b>沒有箭頭</b>（<code>.ch .ar</code> 規則寫了但 HTML 裡沒那個 span），同頁其他可點的都有 —— 補齊。',
          ck:'教練打開後台，第一屏就是「幫學員購課」的搜尋框；還沒處理的事在最上面一行講清楚。全站箭頭一眼看得出是箭頭，不是雜訊。' },
        { n:53, t:'手機版排版修正', where:'前端', done:true,
          summary:'字級寫成 clamp，手機永遠取最小值 —— 等於手機從來沒縮小過',
          body:'Jerec 2026-08-18 上線後在手機上的回報（原話）：<i>「官網上價目表分頁以及其他分頁似乎版面過於放大，導致字句跳行或是文字太接近螢幕邊緣，但在電腦版上看就非常理想」</i>、<i>「團員介紹那邊一樣是版面過大，人物介紹的邊框被擠到螢幕右邊」</i>、<i>「付費方式那邊還保留了舊系統的『加入團課群組』步驟」</i>。<br><br>量出來的數字：手機上 body 是 <b>20.4px</b>、h1 是 <b>34.6px</b> —— 那是筆電的字級搬到 390px 的螢幕上，一行只塞得下 19 個字。改完之後 body 16.7px、h1 28.4px。',
          warn:'☢️ <b>根因：clamp() 的「最小值」在手機上是唯一會用到的值。</b>字級寫成 <code>clamp(1.274rem, 1.55vw, 1.44rem)</code>，390px 的手機上 1.55vw 只有 6px，所以永遠取 1.274rem —— <b>手機等於完全沒有縮小</b>，而且視窗越窄字反而越顯得大。<br><br>☢️ <b>不能去改那些最小值。</b>1280px 的筆電同樣落在「取最小值」的區間，動最小值會連 Jerec 滿意的電腦版一起變小。改的是<b>根字級</b>（<code>html{font-size}</code>），而且只寫在 media query 裡：<code>≤860px→91%</code>、<code>≤620px→82%</code>。實測 900／1024／1280／1440px 四種寬度，改前改後每一個字級<b>完全一樣</b>。<br>這一招成立的前提是：整份 index.html 裡 rem <b>只</b>拿來寫字級，沒拿來寫尺寸或間距（查過）。所以縮的是字，按鈕大小、間距、圓角一個都沒動。<br>用 % 不用 px，是為了讓自己把瀏覽器預設字級調大的人還是能放大。<br><br>☢️ <b>手機覆寫一定要寫在樣式表最後面。</b>media query <b>不會</b>提高特異度 —— <code>.tb table</code> 兩邊都是 (0,1,1)，平手就看誰寫在後面。第一版寫在檔案前段，結果 <code>min-width:520px</code> 照樣贏，價目表還是被切掉，看起來像沒生效。<br><br>☢️ <b>教練頭像寫死 150px。</b>手機兩欄時一欄扣掉內距只剩約 134px，150px 的圓塞不進去就把整張卡撐出畫面 —— 這就是「邊框被擠到螢幕右邊」。改成 <code>min(150px,84%)</code> ＋ <code>aspect-ratio:1</code>。<br><br>☢️ <b>nowrap 是跟別欄「搶」寬度。</b>第一欄（時段／費用／人數）被擠成直排很像壞掉，加了 nowrap 之後 5 欄的表反而被推出去 31px。要同時把字距歸零、金額字級收一格，把搶走的寬度還回去。<br><br>☢️ <b>有些表格真的塞不下就不要硬擠。</b>首頁課表 7 天、教練場租 7 欄 —— 硬縮只會讓字看不清楚。那兩張維持左右捲動，但用 JS 量出「這張確實超出去」之後補一行「← 左右滑動看完整表格 →」。純 CSS 量不到寬度，塞得下的表也就不會多出一行沒用的字。',
          note:'<b>2026-08-18 完成。</b>檔案：<code>index.html</code>。<br><br><b>驗證</b>：Playwright ——<br>· 電腦版 900／1024／1280／1440px 四種寬度，16 個選擇器的字級改前改後<b>逐一比對完全相同</b>；<br>· 390px 手機：價目表 6 張表有 5 張完整顯示（原本 4 張被切），跳頁連結 6 顆全部看得到（原本只看得到 3 顆）；<br>· 課程比較表 8 欄從溢出 249px 變成 0；<br>· 提示列只在真的溢出的 2 張表出現，電腦版 0 張；<br>· 17 個頁面／路由零 JS 錯誤、零橫向溢出。<br><br>另外刪掉付費流程的第 3 步「加入團課群組」（舊系統的做法），後面的步驟號碼一起遞補 —— 那個號碼是 CSS 用 <code>content:attr(data-n)</code> 畫的，不會自己重算。',
          ck:'同一支手機打開價目表，價格整張看得完、不用左右拉；團隊卡片兩欄都在畫面內。電腦版跟改之前一模一樣。' },
        { n:54, t:'暱稱欄位 ＋ 綁定比對放寬', where:'SQL ＋ Edge Function ＋ 前端', done:true,
          summary:'資訊越多信心越高 —— 這句話在「找人」成立，在「驗證」是反的',
          body:'Jerec 2026-08-18 的觀察（原話）：<i>「客人其實很奇怪，有人就是不喜歡給出中文名，因此當初舊系統時代才決定在登入或綁定時，只認手機不認名，這造成了資料內會有重複名稱的問題，甚至客人雖然乖乖的輸入中文全名，但也是有同名同姓的。」</i><br><br><b>先盤點</b>（93 位客人）：<ul><li>登記姓名<b>完全沒有中文字</b>的：<b>18 位</b>（五分之一，不是原本以為的 3 位）</li><li>同名同姓：<b>0 組</b></li><li>中文只有 1～2 個字的：5 位</li></ul>做法：<code>customers</code> 加 <code>nickname</code> 欄；比對規則從「客人打的要包含<b>登記姓名</b>」改成「包含<b>登記姓名或暱稱</b>任一個」。Adele 打「陳荔芬」或「Adele」都能綁。',
          warn:'☢️ <b>Jerec 原本要把暱稱也設成必填、綁定時一起比對，我建議倒過來做。</b>理由：「資訊量越多、信心水準越高」在<b>識別</b>（我要找哪一位）完全成立，在<b>驗證</b>（證明是你）是反的 —— <b>每多一個「必須對得上」的欄位，就多一個對不上的機會</b>。而且暱稱是自由填的：櫃檯記「小虎」、客人打「虎哥」，一樣卡住，等於把 Adele／Yiting 那個問題再複製一份。所以做的是多一條<b>可以</b>對得上的路，不是多一道關卡。<br><br>☢️ <b>同名同姓不會造成綁錯人。</b>手機是唯一鎖 —— 先用手機找到那一筆，才比姓名。兩位「陳怡君」的手機不同，永遠不會互相干擾。同名的麻煩在<b>櫃檯畫面上分不出誰是誰</b>，那才是暱稱要解的事，所以暱稱只顯示、不參與驗證。<br><br>☢️ <b>必填放在表單，資料庫那一欄允許空白。</b>既有 93 位客人一個暱稱都沒有，設 NOT NULL 會直接失敗；而 Jerec 已經決定「既有已綁定的無需追討」，那它實務上就不是必填 —— 寫成 NOT NULL 只會逼我們到處塞空字串。<br><br>☢️ <b>一致性陷阱：兩邊的提示必須講同一件事。</b>客人端如果寫「請輸入完整中文姓名」，櫃檯端就不能還寫著「登記短的就好」（舊規則的產物）—— 櫃檯登記短名、客人照提示打全名，會永遠對不上。兩段文案一起換掉。<br><br>☢️ <b>暱稱少於 2 個字自動失效。</b>登記暱稱「明」的話，任何含「明」的名字都會通過。這條保護沿用登記姓名那一條的寫法。<br><br>☢️ <b><code>create or replace view</code> 又踩了一次。</b>新欄位 <code>registered_nickname</code> 插在 <code>why</code> 前面，資料庫回「cannot change name of view column "why"」—— replace 只會把第 8 欄<b>改名</b>，不會插入。要 drop + create。這是第二次犯，寫進註解了。<br><br>☢️ <b>不能直接給 <code>create_customer</code> 加一個有預設值的第三參數</b> —— 那會變成兩支同名函式，兩個參數的呼叫就成了「不知道要叫哪一支」。要先 drop 掉舊簽名。<br><br>☢️ <b>查客人沒有用 PostgREST 的 <code>or()</code>。</b>那是把條件塞進網址的字串，客人名字裡只要有逗號或括號就會把它拆壞。改成姓名、暱稱各查一次再合併去重 —— 多一個來回，但沒有「某些名字會查不動」這種難查的坑。',
          note:'<b>2026-08-18 完成。</b>檔案：<code>db/32-nickname.sql</code>、<code>supabase/functions/line-bind/index.ts</code>（已部署 v3）、<code>line-prototype/staff-tools.html</code>、<code>GT-booking.html</code>、<code>liff-bind.js</code>。<br><br><b>驗證</b>：<ul><li><b>26 個案例逐一比對資料庫的 <code>name_matches</code> 和 Edge Function 的 <code>nameMatches</code></b>，兩邊結果<b>完全相同</b> —— 這兩支不一致的話，教練後台會說「這樣打會過」而實際上不會過，比沒有這一頁更糟</li><li>關鍵案例：登記 Adele／暱稱 陳荔芬 → 打中文名過、打 Adele 過、打「荔芬Adele」也過；沒填暱稱時維持原本行為（多寫過、少寫不過）；<b>一個字的暱稱不會變成後門</b></li><li>前端 18 項：三欄都標 *必填、缺欄位在按下去之前就講、<code>p_nickname</code> 有帶出去、暱稱顯示在姓名後面、徽章不折行、購課鍵垂直置中、綁不上卡片把兩個名字都講出來</li><li>17 個頁面／路由零 JS 錯誤、零橫向溢出</li></ul>',
          ck:'櫃檯登記中文全名＋暱稱兩欄；客人綁定時打哪一個都會過。教練查客人時同名的兩位靠暱稱一眼分得開。' },
        { n:55, t:'一鍵通知 ＋ 提醒條即時更新', where:'前端', done:true,
          summary:'教練不該自己想「這個人卡在哪、要跟他說什麼」',
          body:'2026-08-18 上午把動到錢的四條路實地走完（購課現金／購課匯款／確認入帳／沖銷），加上暱稱綁定，全部通過。走完之後 Jerec 提了兩件事：<ol><li><i>「能否在『綁不上的人』下方的客人清單上直接設計『點擊就可以傳送給客人通知』的功能？」</i></li><li><i>「提醒條出現『💰 1 筆匯款待入帳』這個訊息不是即時的，而是需要按重新整理，有辦法優化嗎？」</i></li></ol><b>一鍵通知</b>：每張「綁不上」的卡片加一顆「通知他」，展開後是一段<b>照他卡住的原因寫好的訊息</b>，兩顆鍵 —— 傳簡訊（手機自己開，內文已帶好）、複製訊息。<br><b>提醒條即時</b>：購課／確認入帳／沖銷做完，最上面那條自己就變了，不用按重新整理。',
          warn:'☢️ <b>為什麼是簡訊不是 LINE 推播。</b>我們手上有的是客人打的<b>手機</b>，不是可以主動發訊的管道；而用官方帳號推播要走 Messaging API，<b>每一則都吃月額度</b> —— 8/16 量到 2,217/3,000，推估 8/22 見底。拿來做客服通知會更快燒完。簡訊由手機自己開，不經過我們的伺服器，也不佔任何額度。<br><br>☢️ <b>「複製」是必要的退路，不是多做的。</b>LINE 內建瀏覽器在某些 Android 機型上不讓 <code>sms:</code> 開出去 —— 那時候至少文字還在剪貼簿裡。同理 <code>navigator.clipboard</code> 在舊 WebView 上不存在，要留 <code>execCommand</code> 的老路，只寫新 API 的話按鈕會<b>整顆沒反應而且不報錯</b>。<br><br>☢️ <b>no_phone 那一種的訊息裡，一個字都不能提到別的客人。</b>那支手機<b>不在名單裡</b> —— 可能是他打錯一個數字，那則簡訊就會寄到陌生人手上。其他三種（retry／name_mismatch／taken）手機是對得上的，所以訊息裡寫他自己的登記姓名沒問題。這條有寫成測試。<br><br>☢️ <b>提醒條不即時的原因不是「沒有輪詢」，是「沒人動它」。</b>購課做完只重畫了「待入帳」那一塊，最上面那條沒有被更新。修法<b>不是</b>整頁重畫 —— 那會把剛剛的成功訊息洗掉（同一個坑犯過四次）。包一層固定的 <code>#alertBox</code>，只換它的內容。<br><br>☢️ <b>刻意不做自動輪詢。</b>這一頁本來就明說「這份清單是打開頁面當下的，其他教練同時在處理的話要按重新整理」——自動更新會跟這句話打架，而且會讓兩個教練的畫面在不同時間跳動。只有<b>自己這台做的動作</b>才即時反映。',
          note:'<b>2026-08-18 完成。</b>檔案：<code>line-prototype/staff-tools.html</code>。<br><br><b>當天的實地測試結果</b>（測試客人建→用→刪，全程 25 分鐘）：<ul><li>購課・現金 → 剩 1 堂，不進待入帳 ✓</li><li>購課・匯款 → 剩 2 堂，進待入帳 ✓</li><li>「錢到了」→ 離開待入帳，<b>堂數維持 2 堂不變</b> ✓</li><li>沖銷 → 帳本補一筆 −12 堂／−NT$4,000，餘額回 0，待入帳清單不會把它撿回來 ✓</li><li>LINE 綁定<b>只打暱稱「Test」</b> → 綁定成功，我的預約看得到 2 堂 ✓（第 54 步放寬那條路的第一次真人驗證）</li></ul><b>收尾</b>：測試客人整筆刪除（<code>credit_ledger</code> 和 <code>bookings</code> 都是 cascade，跟著一起走），刪完覆核 —— 沒有主人的帳本列 <b>0</b>、待入帳 <b>0</b>、GT 總堂數回到 693。刪掉那一列的同時 Jerec 的 LINE 也跟著解開（綁定關係就存在客人那一列上）。<br><br><b>新功能驗證</b>：15 項自動測試全過，包含「☢️ no_phone 的訊息沒有洩漏任何其他人的資料」和「購課後提醒條自己從 2 筆變 3 筆，而且剛剛的成功訊息還在」。',
          ck:'教練看到「綁不上的人」，按一下就能把寫好的話傳出去，不用自己想措辭。做完動到錢的動作，最上面那條數字當場就對。' },
        { n:56, t:'「代確認」改名 ＋ 撈出一個從上線就在的靜默錯誤', where:'前端 ＋ SQL', done:true,
          summary:'去改三個字，結果發現到課確認從頭到尾沒顯示過',
          body:'Jerec 2026-08-18：<i>「點名核銷頁面的客人框右下角『代確認』三個字，應該是『待確認』，對嗎？」</i><br><br>不是錯字 —— 那是<b>代替</b>的代。但那一行其實是<b>兩個東西</b>：<br><code>還沒確認　　　　　　［代確認］</code><br>左邊是<b>狀態</b>（意思就是「待確認」），右邊是<b>按鈕</b>（教練代替客人確認）。兩個詞同音、形近，又剛好貼在一起。<br><br>改成<b>「幫他確認」</b>：沒有同音字可以混淆，而且跟「幫學員購課」同一種語氣。已確認的徽章也跟著成對 —— <code>✓ 本人已確認</code>／<code>✓ 教練確認的</code>，對比點回到「誰確認的」。',
          warn:'☢️ <b>要靠解釋才懂的字，不該留在按鈕上。</b>這件事的價值不在改三個字，在於：<b>寫的人知道那是「代替」，所以永遠不會看錯</b> —— 只有沒讀過程式的人會看錯，而他們正是使用者。<br><br>☢️ <b>資料庫也要跟著改。</b><code>confirm_by_staff()</code> 裡那兩句 <code>raise exception</code> <b>會浮到教練畫面上</b> —— <code>proxyConfirm</code> 在 catch 裡直接把 <code>e.message</code> 丟給 toast。所以它們不是內部訊息，是文案。<br><br>☢️☢️ <b>順手抓到一個從第 47 步就存在的錯 —— 錯在【驗證方法本身】。</b>當時用的靜態檢查是 <code>pg_get_functiondef(oid) ilike \'%credit_ledger%\'</code>，但 <code>pg_get_functiondef</code> 會<b>連註解一起吐出來</b>。所以只要函式裡有一句註解寫著「一個字都不碰 credit_ledger」，這個檢查就會回 true —— <b>明明沒碰，卻報告成碰到了</b>（這次改版加了那句註解，當場就假警報）。<br>反過來更危險：「有擋非員工」那一項也可能只是因為註解提到 <code>is_staff</code> 就通過，而真正的 <code>if not is_staff()</code> 根本沒寫。<b>一個會說謊的檢查比沒有檢查更糟 —— 它讓人停止懷疑。</b>修法：先用 <code>regexp_replace</code> 把 <code>--</code> 註解拿掉再驗。<br><br>☢️☢️☢️ <b>改文案的時候撞到一個真正的錯，而且它從 8/17 第 47 步上線那天就在。</b><code>loadRoster()</code> 的 <code>.select()</code> <b>漏了 <code>confirmed_at</code> 和 <code>confirmed_by</code></b> —— <code>staff_roster</code> 這兩欄一直都有（<code>db/24</code> 加的），是前端沒跟它要。<b>PostgREST 只回你點名的欄位，沒點的就是 <code>undefined</code></b>，而 undefined 是 falsy，所以 <code>if (p.confirmed_at)</code> 永遠不成立：<ul><li>「✓ 本人已確認」「✓ 教練確認的」<b>永遠不會出現</b></li><li>「還有 N 位沒確認」<b>永遠等於全部人數</b></li><li>按了「幫他確認」，資料庫有寫進去，畫面卻還是「還沒確認」—— <b>教練會以為沒成功，然後一直按</b></li></ul>☢️ <b>沒有人發現，因為它不會報錯</b>，而且到 8/18 為止資料庫裡 <code>confirmed_at</code> 有值的預約是 <b>0 筆</b> —— 整個功能上線兩天，一次都沒有真正成功顯示過，而畫面看起來完全正常。<br>☢️ <b>教訓：<code>.select()</code> 的欄位清單是一份【會過期的合約】。</b>檢視表加了欄位、前端開始用那個欄位，但沒有任何東西會提醒你去更新那串字。這種錯只會用「功能靜靜地不動」的方式出現。',
          note:'<b>2026-08-18 完成。</b>檔案：<code>db/33-confirm-wording.sql</code>、<code>line-prototype/checkin.html</code>、<code>confirm.html</code>。<br><br><b>驗證</b>（用「先去掉註解再掃」的新方法重驗八支函式）：<ul><li><code>confirm_by_staff</code>／<code>confirm_attendance</code>／<code>create_customer</code> → <b>不碰堂數帳本</b> ✓</li><li><code>add_purchase</code>／<code>check_in</code>／<code>claim_legacy</code>／<code>confirm_payment</code>／<code>void_purchase</code> → 碰帳本（本來就該碰）且都有員工關卡 ✓</li><li><code>confirm_attendance</code> 沒有員工關卡是<b>對的</b> —— 那一支是客人自己掃碼在用，牆是 <code>my_customer_id()</code></li><li>最關鍵的一條單獨驗：<code>confirm_by_staff</code> 的 update 子句實際內容是 <code>confirmed_at = now(), confirmed_by = \'staff\'</code> —— <b>就這兩欄</b>，沒有碰 status、沒有碰堂數 ✓</li></ul><br><b>漏 select 那個錯的驗證</b>：用假資料放三種狀態各一位（掃碼確認／教練確認／還沒確認），修好之後畫面依序顯示 <code>✓ 本人已確認</code>／<code>✓ 教練確認的</code>／<code>還沒確認 ＋ 幫他確認</code>，上面的提示也從「還有 3 位沒確認」變成正確的「還有 1 位」。修之前這三列<b>會長得一模一樣</b>。',
          ck:'教練看到按鈕就知道那是「我幫他按」，不用有人在旁邊解釋；而且客人掃完碼之後，教練畫面上真的看得到「✓ 本人已確認」。' },
        { n:57, t:'閒置太久就進不去 —— 憑證自動換、切回來自動接', where:'前端', done:true,
          summary:'不是「時間設太短」，是憑證過期之後沒有第二條路',
          body:'Jerec 2026-08-18：<i>「教練後台若一段時間沒操作，頁面就會逾時無法進入，可否延長時間至無限？或是重新切換至後台網頁時自動重新整理並常駐手機背景，這樣就不用再跳回 line 聊天室畫面，還要多點擊一次網址」</i><br><br><b>根因</b>：<code>liff.getIDToken()</code> 回的是<b>登入當下拿到的那一張</b>身分憑證，LIFF <b>不會自動幫它續期</b>。放著幾十分鐘後那張就過期，送去 <code>line-auth</code> 會被 LINE 打回票，畫面停在「伺服器不認這張憑證」—— 看起來像系統壞了，其實只是憑證舊了，而且<b>當時沒有任何一條路可以自己換一張</b>。<br><br><b>做了三件事</b>：<ol><li><b>憑證過期就自動換一張</b>。伺服器回 401 → 呼叫 <code>liff.login()</code>（在 LINE App 裡是靜默的，畫面閃一下就回來）。</li><li><b>離開超過 5 分鐘再切回來，自己把線接上</b>：檢查登入票 → 快過期就先續 → 續不動才重跑整條身分鏈 → 接好之後呼叫這一頁註冊的 <code>onResume()</code> 重讀資料。</li><li>真的接不回來，才顯示錯誤並給一顆<b>「重新載入」</b>。</li></ol>',
          warn:'☢️ <b>「延長到無限」不能做，而且它也不是解法。</b>會過期的是兩張票：LINE 的身分憑證、和我們自己的登入票。設成永不過期＝任何人撿到這支手機就永遠是教練 —— 而這一頁按得到錢（購課、沖銷）。真正要修的是「過期之後怎麼辦」，不是「不要過期」。<br><br>☢️ <b>「常駐手機背景」網頁做不到。</b>頁面活在 LINE 的內建瀏覽器裡，記憶體不夠時要不要殺掉它是 Android 和 LINE 決定的，網頁沒有任何 API 可以要求自己被留著。做得到的是<b>被殺掉之後回來得快、而且不用重打</b>。<br><br>☢️ <b>自動換憑證一定要防迴圈。</b>萬一換回來的還是不被接受（例如 channel 設定壞了），沒有保險就會變成「開啟 → 跳轉 → 開啟 → 跳轉」，使用者<b>連錯誤訊息都看不到</b>，只會覺得手機壞了。用 sessionStorage 記「這個分頁已經換過一次」，第二次改成顯示看得懂的字。成功之後要記得<b>把記號清掉</b>，否則下次真的過期就不會再幫他換了。<br><br>☢️ <b>接回來之後【故意不做整頁重載】。</b>教練可能正打到一半的新增客人表單、或開著沖銷的原因欄 —— 整頁重載會把那些一起洗掉（同一個坑這個專案犯過四次）。所以只重讀資料，畫面上打的字留著。連最後那顆「重新載入」都<b>不自動按</b>，讓人自己決定時機。<br><br>☢️ <b>iOS 的返回不會發 visibilitychange</b>，走的是 <code>pageshow(persisted)</code>，兩個都要接。',
          note:'<b>2026-08-18 完成。</b>檔案：<code>line-prototype/liff-auth.js</code>、<code>checkin.html</code>、<code>staff-tools.html</code>（後兩者只是註冊 <code>FFF_AUTH.onResume</code>，等同「幫我按一下重新整理」）。<br><br><b>驗證</b>（用假的 liff 和假的 fetch 讓真正那條身分鏈跑起來，16 項全過）：<ul><li>伺服器回 401 → 自動換一次憑證；<b>換回來還是被拒 → 第二次不再跳轉</b>，改顯示看得懂的字 ✓</li><li>正常登入成功後，「換過一次」的記號有被清掉 ✓</li><li>離開 30 秒切回來 → <b>不做多餘的重連</b> ✓</li><li>離開 10 分鐘、票還有效 → 只重讀資料，<b>不重跑身分鏈</b>（省一次來回）✓</li><li>票剩不到 2 分鐘 → 自動續一次，續完照樣重讀 ✓</li><li>票救不回來 → 重跑身分鏈接回來 ✓</li><li>連身分鏈都失敗 → <b>不假裝成功</b>，給一顆「重新載入」讓人自己按 ✓</li></ul>',
          ck:'教練把手機鎖起來去上課，回來點開後台就是可以用的 —— 不用退回聊天室再點一次網址。' },
        { n:58, t:'把加錯的人從名單上拿掉', where:'SQL ＋ 前端', done:true,
          summary:'現場加人有，相對的那一顆從來沒做',
          body:'2026-08-18 下午 Jerec 示範「現場加人」給其他教練看的時候按錯人，名單上多了一位根本沒報名的客人。他<b>自己拿不掉</b> —— <code>add_walkin()</code> 有，相對的那一顆從來沒做，最後是進資料庫改的。<br><br>☢️ 現場加人本來就是站在櫃檯、一邊講話一邊按的動作 —— <b>按錯是常態，不是意外</b>。沒有「拿掉」的話，每按錯一次就要走 教練 → Jerec → Claude 一輪。<br><br>做法：每個人下面多一列很小聲的「這個人不該在名單上」，按下去先問一次（<b>把名字唸出來</b>），再確定才送出。改成 <code>cancelled</code>，<b>不刪除</b>。',
          warn:'☢️ <b>已經記出席的人不給拿 —— 而且畫面上根本不出現那一顆。</b>他的堂數已經扣掉了，直接把預約改成取消，那一堂課的錢就<b>永遠消失在帳上</b>：客人少一堂，而且事後查不出為什麼。正確順序是先按「改成缺席」把堂數退回去，那顆才會冒出來。<br><br>☢️ <b>擋的條件是「這一筆的堂數變動加總 = 0」，不是「一列都沒有」。</b>出席過又改成缺席的人，帳本上有 −1 和 +1 兩列，但淨值是 0 —— 客人已經被補回來了，可以拿掉。用「有沒有列」去擋會把這種人一起擋掉，而他正是最需要拿掉的那一種（點錯人、退回去、再移除）。<br><br>☢️ <b>教練就可以做，不用等 Jerec。</b>「加」本來就是教練做的，能加不能減只會讓錯誤在畫面上留更久。代價用三件事補：確認框把名字唸出來（今天就是名字看錯才按錯的）、堂數動過一律擋、以及新增 <code>cancelled_by</code> 記下是誰拿的。<br><br>☢️ <b>不是 delete。</b>紀錄留著才查得到「誰在什麼時候加的、誰又在什麼時候拿掉」。而且 <code>cancelled_by</code> 空／不空剛好分得出兩種來源 —— 客人自己取消走的是 RLS 政策，不經過這一支，那一欄會是空的。<br><br>☢️ <b>上限跟點名一樣是課後 7 天，但故意沒有下限。</b>現場加人在開課前就能按，那拿掉也必須能按 —— 否則按錯的人要等到課前 15 分鐘才拿得掉。<br><br>☢️ <b>每一種擋下來的理由都要講「下一步做什麼」。</b>只說「不行」會讓人卡在原地又按一次。堂數動過 → 講「先按改成缺席」；找不到 → 講「可能被別的教練處理掉了，按重新整理」。',
          note:'<b>2026-08-18 完成。</b>檔案：<code>db/34-remove-booking.sql</code>、<code>line-prototype/checkin.html</code>。<br><br><b>這次的起因值得記一筆</b>：Jerec 回報時把名字寫成「林秀珊」，而畫面上是<b>林</b>卉婷和王<b>秀珊</b>兩個人。照字面刪會拿掉一位真的有報名的客人，誤加的那位還留著。決定性的證據是<b>林卉婷沒綁 LINE —— 她不可能自己線上報名</b>，而且加入時間 15:12:20，跟截圖的 15:13 差一分鐘。<b>先問一句再動手，比動作快重要。</b>這也是確認框一定要唸名字的理由。<br><br><b>驗證</b>：<ul><li>資料庫（去掉註解後掃）：<b>不寫堂數帳本、沒有 delete、有員工關卡</b>，update 只寫 status／cancelled_at／cancelled_by 三欄 ✓</li><li>前端 11 項：booked 和 absent 有「拿掉」、<b>attended 沒有</b>；第一下只是問、不送出；取消會收起來；送出時帶對 booking id；被擋下來時講出下一步且按鈕回復可按（不會卡在「拿掉中…」）✓</li><li>12 個頁面零 JS 錯誤 ✓</li></ul><br>☢️☢️ <b>第一版整顆鍵在最需要的時候消失，而且我的測試也沒抓到。</b><code>removeRow</code> 寫成 <code>if (lock) return &#39;&#39;</code> —— 我是照抄旁邊 <code>confirmRow</code> 的判斷，<b>沒有問「這個 lock 在擋什麼」</b>。<code>lock = dead || soon</code>，而 <code>soon</code> 是「課還沒到、點不了名」—— 那正是<b>現場加人會發生的時候</b>（畫面上的橫幅自己就寫著「現在可以先把臨時要來的人加進名單」）。<b>加得進去卻拿不掉，等於沒做。</b><br>☢️ <b>而我的測試用的是「課已經開始」的假資料，剛好避開了他真正遇到的狀態。</b>測試通過不等於功能會動 —— 只等於「我想到的那個情況會動」。修完之後兩種狀態都測（課還沒到／課已開始 × booked／absent／attended 六格）。<br>☢️ 教訓寫成一句：<b><code>lock</code> 的意思是「點不了名」，不是「名單不能改」——抄一個條件之前要先問它在擋什麼。</b>',
          ck:'教練現場加錯人，自己按兩下就拿掉了 —— 不用找人。而已經扣過堂數的人，畫面上根本沒有那顆可以按。' },
        { n:59, t:'桌機也能用 —— 找出一顆從來沒機會出現的按鈕', where:'前端', done:true,
          summary:'功能早就寫好了，只是掛在三個頁面都沒有的元素上',
          body:'Jerec 2026-08-18：<i>「教練反應系統能否在桌機上操作？能的話更好。」</i><br><br>我先回答「應該可以，<code>liff-auth.js</code> 裡本來就有一顆『用 LINE 登入』」—— <b>然後他實測，畫面停在「還沒認出你 · 不是從 LINE 開的」，沒有任何可以按的東西。</b><br><br><b>根因</b>：那顆鍵的第一行是 <code>if (!elBand || …) return;</code>，<code>elBand</code> 是 <code>#authBand</code>。而 <b>staff.html／staff-tools.html／checkin.html 三個教練頁面都沒有 <code>#authBand</code></b>（只有客人的 <code>GT-booking.html</code> 有）。所以那顆鍵<b>從上線到現在一次都沒有出現過</b>。<br><br><b>做法</b>：把登入動作從那顆鍵裡搬出來，變成 <code>FFF_AUTH.login()</code>，任何頁面都叫得到；再加一個 <code>FFF_AUTH.canLogin</code> 旗標，三個教練頁面照它決定要顯示「按這裡登入」還是「請從 LINE 裡面開」。',
          warn:'☢️☢️ <b>我看著程式碼說「這個功能有」，但它接不到畫面 —— 只讀程式碼分不出這兩件事。</b>那顆鍵存在、寫得也對、不會報錯，只是掛在一個那三頁沒有的元素上。<b>「功能存在」和「使用者按得到」是兩件事</b>，而靜態閱讀永遠只看得到前者。這一題只有真的打開頁面才會知道 —— Jerec 花 30 秒實測，推翻了我的判斷。<br><br>☢️ <b><code>browsing</code> 這個狀態底下藏著三種完全不同的處境，畫面卻長得一模一樣：</b><ol><li>LINE 的程式沒載進來（CDN 被擋）→ 沒救</li><li><code>liff.init()</code> 失敗（LIFF ID／網域設錯）→ 沒救</li><li>init 成功，只是<b>還沒登入</b> → <b>按一下就好</b></li></ol>原本三種一律說「要從 LINE 裡面開」。對第 ③ 種來說<b>那句話是錯的</b>，而第 ③ 種正是桌機。<b>把「沒救」和「有救」混成同一句話，等於把有救的人擋在門外。</b><br><br>☢️ <code>liff.login()</code> 一定要帶 <code>redirectUri: location.href</code>。不帶的話 LINE 會把人送回 LIFF 的 Endpoint 首頁 —— 教練登入完會發現自己站在別的頁面上，而他根本不知道發生什麼事。<br><br>☢️ <b>LINE 網頁版登入要掃 QR 或 email＋密碼</b>，這一關我們控制不了。所以按鈕下面直接寫「可以用手機掃 QR Code」—— 很多人不記得自己的 LINE 密碼，但手機一定在手上。',
          note:'<b>2026-08-18 完成。</b>檔案：<code>line-prototype/liff-auth.js</code>（新增 <code>FFF_AUTH.login()</code> 與 <code>canLogin</code>）、<code>staff.html</code>、<code>staff-tools.html</code>、<code>checkin.html</code>。<br><br><b>驗證</b>（三個頁面 × 三種 browsing 原因，共九格，全過）：<ul><li>③ 在瀏覽器、還沒登入 → 三頁<b>都出現</b>「用 LINE 登入」，按下去 <code>liff.login()</code> 確實收到<b>當前網址</b>當 <code>redirectUri</code> ✓</li><li>② <code>liff.init()</code> 失敗 → 三頁<b>都不出現</b>那顆鍵，維持原本的「要從 LINE 裡面開」 ✓</li><li>① SDK 沒載進來 → 同上 ✓</li></ul><b>在 LINE App 裡不受影響</b>：<code>canLogin</code> 只在「init 成功但沒登入」那一支才會設成 true，LINE App 裡是自動登入的，走不到那一支。<br><br><b>2026-08-18 傍晚 Jerec 實測成功登入</b>，接著回報版面：<i>「留白很多，字體很小，右上角的連結按鈕太遠」</i>。<br><br><b>三件事其實是同一個原因</b>：這三頁是照<b>手機直式</b>畫的，整套字級和間距都是為了 390px 寬的螢幕。搬到 2560px 上，字沒有變大、欄位被推到正中央，而<b>頂欄是滿版的</b> —— 所以按鈕留在最右邊，離內容一個螢幕遠。<br><br><b>做法：<code>zoom</code> 等比例放大，不是逐條改 font-size。</b>這三頁加起來有 <b>134 條 <code>font-size</code></b>，逐條加桌機版等於維護兩套字級 —— 改一次要改兩個地方，遲早有一條忘了改，而且<b>只在桌機上看得出來</b>。<code>zoom</code> 是整套一起走，版面比例完全不變，也不會多出第二套數字要對。<br><br>☢️ <code>zoom</code> 只加在 <code>.top</code> 和 <code>.wrap</code> 兩個元素上，<b>不加在 <code>body</code></b> —— 出示確認碼的蓋板和 toast 是 body 的直接子元素而且是 <code>position:fixed</code>，跟著放大會算錯尺寸，整片蓋板會超出螢幕。<br><br>☢️ <b>頂欄對齊是算出來的，不是試出來的</b>：<code>.top</code> 和 <code>.wrap</code> 用<b>同一個倍率</b>，所以在放大後的座標系裡兩者的 <code>100%</code> 是同一個數字，padding 用同一個 <code>--col</code> 去算就自動對齊。<b>還要再 +14px</b>，因為 <code>.wrap</code> 自己有 <code>padding:0 14px</code>、卡片的邊在那之後 —— 少加這 14px，按鈕會比卡片往外 14px（看起來像沒對齊，因為真的沒有）。<br><br><b>版面驗證</b>：<ul><li>1280／1920／2560 三種螢幕，頂欄按鈕與卡片<b>左右各差 0px</b> ✓</li><li>桌機欄寬約 700～720px（原本 520／560），字級等比放大 1.22 倍 ✓</li><li>☢️ <b>手機完全沒被動到</b>：390px 下 <code>zoom=1</code>、<code>max-width</code> 維持 560／520px、沒有橫向捲動 ✓</li><li>桌機的名單畫面（進到一堂課）零 JS 錯誤，順便看到第 56、58 步的成果都在：「✓ 本人已確認」「✓ 教練確認的」「這個人不該在名單上」都正常 ✓</li></ul>',
          ck:'教練在自己的電腦上打開網址 → 看到「用 LINE 登入」→ 掃 QR → 直接進到後台；字看得清楚，右上角的按鈕就在內容正上方。' },
        { n:60, t:'登出 —— 桌機能用之後才浮出來的問題', where:'前端', done:true,
          summary:'憑證會留在那台電腦上，而這幾頁按得到錢',
          body:'第 59 步讓桌機能用，隨即帶出一件本來不存在的事：<b>教練登入之後，憑證會留在那台電腦的瀏覽器裡</b>，而且要等它自己過期。共用電腦上，<b>下一個開這個網址的人就是那位教練</b> —— 而這幾頁按得到錢（購課、沖銷）。<br><br>三頁都加了登出。',
          warn:'☢️ <b>兩張票都要退，順序是先 Supabase 再 LINE。</b>只呼叫 <code>liff.logout()</code> 的話，LINE 那邊登出了，但 <b>Supabase 的 session 還在</b> —— 那才是資料庫認的身分（<code>auth.uid()</code>），這台電腦<b>照樣查得到客人資料</b>。看起來安全，其實沒有。<br><br>☢️ <b>在 LINE App 裡【故意不給登出】。</b>那邊是自動登入的：按了登出 → 重新載入 → 又自動登入回來，畫面什麼都沒變。<b>一顆按了沒反應的按鈕比沒有更糟</b> —— 教練會以為自己登出了。<br><br>☢️ <b>最後用 <code>location.replace</code> 不用 <code>reload</code>。</b>把這一頁從歷史紀錄裡換掉，否則下一個人按「上一頁」又回到有資料的畫面。<br><br>☢️ <b>教練後台和點名頁的登出要按兩下。</b>它就在「重新整理」旁邊，誤按的代價是整個被丟出去 —— 而教練可能正幫學員購課、或正在點名。第一下只是把字改成「確定登出？」，四秒沒動作就自己變回去。<br><br>☢️☢️ <b>做這一步時撞到一個藏了很久的坑：<code>staff-tools.html</code> 沒有 <code>[hidden]{display:none !important}</code> 這一行。</b>HTML 的 <code>hidden</code> 屬性靠瀏覽器預設樣式生效，那是<b>最低優先權</b>，任何 class 規則都壓得過它 —— 而 <code>.iconbtn</code> 寫了 <code>display:inline-flex</code>。所以 <code>&lt;a class="iconbtn" hidden&gt;</code> <b>照樣看得見</b>。<br>☢️ 差一點就出事：第 61 步新加的「對帳」入口正是這樣藏的，<b>沒有這一行的話每一位教練都會看到那顆按鈕</b>。（資料仍然拿不到 —— 資料庫那一關擋著 —— 但按鈕本身不該出現。）<b>它不會報錯、不會壞掉，只是「藏起來的東西沒藏住」，只有真的打開頁面看才會發現。</b>另外三頁本來就有這一行，唯獨這一頁漏了。',
          note:'<b>2026-08-18 完成。</b>檔案：<code>line-prototype/liff-auth.js</code>（新增 <code>FFF_AUTH.logout()</code> 與 <code>canLogout</code>）、<code>staff.html</code>、<code>staff-tools.html</code>、<code>checkin.html</code>。<br><br><b>驗證</b>（三頁 × 兩種環境）：<ul><li>瀏覽器裡：三頁都出現登出鍵 ✓</li><li>按下去：<b>Supabase 和 LINE 兩張票都確實退掉</b>（用假的 client 記錄有沒有被呼叫，記在 sessionStorage 才不會被跳頁洗掉）✓</li><li>兩段式那兩頁：<b>第一下沒有登出</b>，只是改字 ✓</li><li>LINE App 裡：三頁<b>都不出現</b>登出鍵 ✓</li><li>12 頁手機 390px 零 JS 錯誤、沒有橫向溢出 ✓</li></ul>',
          ck:'教練在共用電腦上用完，按一下登出，下一個人打開同一個網址看到的是「還沒登入」。' },
        { n:61, t:'對帳報表（Excel）—— 只給負責人和 VC', where:'SQL ＋ 前端', done:true,
          summary:'金流還在臨櫃，VC 要核對「當天收的錢」跟系統上的帳',
          body:'Jerec 2026-08-18：<i>「目前金流還是臨櫃，財務人員（就是 VC）需要對帳……VC 需要核對當天收的錢與資料上的帳是否相符，而這個功能只能開放給我和 VC。」</i><br><br>新的一頁 <code>report.html</code>：選日期（今天／昨天／這 7 天／這個月，也可以自己指定區間）→ 畫面上先看到數字 → 一顆<b>下載 Excel</b>。Excel 有四個工作表：<ol><li><b>收款明細</b> —— 誰、幾堂、多少錢、現金／匯款、誰收的、登記時間、有沒有被沖銷</li><li><b>每日合計</b> —— 現金小計、匯款小計、合計、賣出堂數、沖銷</li><li><b>待入帳匯款</b> —— 堂數給了但錢還沒確認進帳戶的</li><li><b>堂數異動</b> —— 上課扣堂、調整（畫面上不列，通常上百筆）</li></ol>',
          warn:'☢️ <b>權限用新欄位 <code>can_finance</code>，不是用 <code>role</code>。</b>VC 的 role 是 <code>coach</code>，他還要點名；改成 admin 就會影響點名那一路的判斷。而且「看得到錢」跟「是什麼職務」本來就是兩件事 —— 以後多一位會計、或 VC 交接，都只要改這一欄。<br><br>☢️ <b>四份資料包成【一支函式】，不是四張檢視表。</b>四張表 = 四個地方各寫一次權限判斷，<b>漏掉一張就是整份帳外洩，而且不會有任何錯誤訊息</b>。一支函式只有一道門。<br><br>☢️ <b>這一頁一個字都不寫回資料庫。</b>只有讀。對帳工具改得動帳，對帳就沒有意義了。<br><br>☢️ <b>日期一律用台北時間切。</b>資料庫的 TimeZone 是 UTC，直接 <code>created_at::date</code> 會把台北早上 8 點以前的收款算到前一天 —— 對帳表少一筆、前一天多一筆，<b>而兩天加起來又剛好對得起來，所以極難發現</b>。前端的預設日期也一樣：<code>toISOString()</code> 給的是 UTC，台灣半夜到早上 8 點之間它會回「昨天」。<br><br>☢️ <b>收款以 <code>paid_at</code>（錢真的到手）為準，不是 <code>created_at</code>。</b>現金兩者相同；匯款是隔幾天按「錢到了」才算收到。VC 數的是抽屜裡的現金和帳戶進帳。但 <code>created_at</code> 也一起放進報表 —— 兩個日期不一樣的那幾筆正是要看清楚的。<br><br>☢️ <b>只算 <code>amount is not null</code> 的。</b>資料庫裡 95 筆 purchase 有 <b>93 筆是 8/16 交接匯進來的舊堂數</b>，那些沒有收到錢；混進來的話帳面會憑空多出幾十筆零元交易。<br><br>☢️ <b>「待入帳匯款」故意不受日期區間限制。</b>那一塊問的是「還沒收到的錢」，<b>最該被看到的正是拖最久、已經掉出查詢區間的那幾筆</b>。<br><br>☢️☢️ <b>Excel 是自己寫的，沒有用 SheetJS。</b>本來要從 CDN 載，但在我這邊<b>載不到它</b> —— 也就沒辦法在交出去之前真的產一個檔案打開來看。<b>「我沒辦法測，但應該會動」對一份財務報表不成立</b>：VC 拿到一個開不起來的檔案，等於這個功能沒做，而且他會在對帳當下才發現。<br>.xlsx 本身就是一個裝著幾個 XML 的 ZIP，而 <b>ZIP 規格允許不壓縮</b>（stored）—— 少寫幾百行 DEFLATE，就是少幾百行可能出錯的地方。字串用 <code>inlineStr</code> 而不是共用字串表，也是同一個理由：少一份要對得上的東西。<br><br>☢️☢️ <b>檔名只能用英數，不能有中文。</b>本來叫「FFF對帳_2026-08-18.xlsx」，實測發現 <code>&lt;a download&gt;</code> 的檔名只要含中文，Chromium 會<b>整個丟掉</b>，存出來的檔案叫 <code>download</code> —— <b>連 .xlsx 都沒有</b>，在 Windows 上點兩下打不開，看起來就像「檔案壞了」。五種檔名逐一測過，兩種含中文的都失敗。工作表名稱在檔案<b>裡面</b>，那邊用中文沒問題。<br><br>☢️ <b>手機末三碼絕對不能寫成數字格式。</b>「016」變成 16，前面的 0 消失 —— 而 VC 是用那三碼認人的。所以只有<b>欄位自己宣告是金額</b>時才寫成數字，不能用「看起來像數字」去猜。',
          note:'<b>2026-08-18 完成。</b>檔案：<code>db/35-finance-report.sql</code>、<code>line-prototype/report.html</code>（新）、<code>line-prototype/xlsx-lite.js</code>（新）、<code>staff.html</code>、<code>staff-tools.html</code>。<br><br><b>權限驗證</b>（用五個真實員工身分實際呼叫 <code>finance_report()</code>）：<ul><li>Jerec（負責人）✓ 拿得到　·　VC（財務）✓ 拿得到</li><li>Peter／Jessica（教練）、林智謙（櫃檯）→ <b>三個都被擋</b>，訊息是「這份報表只有負責人和財務看得到」 ✓</li><li>前端：一般教練進 <code>report.html</code> <b>畫面上一個金額都沒有</b>；<code>staff.html</code> 和後台頂欄的入口<b>完全不出現</b> ✓</li></ul><b>數字驗證</b>：不透過函式直接下 SQL 算一次，8/01～8/18 得到「2 筆・NT$4,400・13 堂・都是現金」，跟報表的每日合計<b>逐格相同</b> ✓<br><br><b>Excel 驗證</b>（用真的瀏覽器按下載，把檔案存下來用 openpyxl 打開）：<ul><li>ZIP 完整性 <code>unzip -t</code> 無錯 ✓</li><li>四個工作表名稱正確、中文正常 ✓</li><li>金額是<b>數字</b>且套用千分位格式；<b>末三碼「016」仍然是字串</b> ✓</li><li>標題列粗體、凍結窗格、欄寬都在 ✓</li><li>XML 跳脫：客人名字含 <code>&lt;</code> <code>&amp;</code> 也能正確還原 ✓</li><li>檔名 <code>FFF_2026-08-18.xlsx</code> ✓</li></ul>',
          ck:'VC 打開報表 → 選「今天」→ 看到現金合計 → 按下載 → Excel 打得開，四個工作表都在。其他教練連那顆按鈕都看不到。' },
        { n:62, t:'「line_verify_failed」—— 憑證過期，但畫面上是一句看不懂的英文', where:'前端', done:true,
          summary:'伺服器紀錄把 LINE 憑證的壽命寫成了一個確定的數字：一小時',
          body:'Jerec 2026-08-18 傍晚：桌機上打開教練後台，畫面停在<b>「辨識失敗 · line_verify_failed」</b>，沒有任何可以按的東西。<br><br><b>去翻伺服器紀錄，事實長這樣</b>：<ul><li><b>18:47～18:49</b>　五次 <code>line-auth</code> 全部 <b>200</b>（登入成功）</li><li><b>19:47～19:48</b>　<b>五次 401</b>，40 秒內連續發生</li><li><b>19:58</b>　又一次 200</li></ul>☢️ <b>整整一小時 —— LINE 的身分憑證就是一小時到期，這下有數字了。</b>第 57 步只知道「會過期」，現在知道多久。<br><br>☢️ 而那五次 401 <b>是我們自己打出去的</b>：憑證早就過期，前端還是照送，等伺服器打回票才知道。他開著三個分頁，每頁各送一次、再重試一次，就湊成五次。<br><br><b>改了三件事</b>：<ol><li><b>送出去之前先自己看一眼到期時間。</b>憑證是 JWT，中間那段是明文 JSON，讀得到 <code>exp</code>。過期就直接去換一張，不浪費一次來回。</li><li><b>重試改成兩段。</b>第一次只 <code>login()</code>；不夠的話第二次<b>先 <code>logout()</code> 再 <code>login()</code></b>。</li><li><b>失敗一定要留一條路</b>：畫面顯示「登入過期了」＋一顆<b>「重新登入」</b>。</li></ol>',
          warn:'☢️☢️ <b>本來有一句寫給人看的中文，但它被丟掉了。</b><code>liff-auth.js</code> 的 <code>paint(state, note, code)</code> 裡，<code>note</code> 是給人看的、<code>code</code> 是給我看的 —— 但 <code>note</code> <b>只寫進狀態列</b>，而<b>三個教練頁面根本沒有狀態列</b>（第 59 步才發現這件事），它們讀的是 <code>AUTH.error</code>，也就是代碼。<b>所以好好的一句「登入過期了」變成了 <code>line_verify_failed</code>。</b>加了 <code>AUTH.errorNote</code> 把它交出去。<br>☢️ 教訓跟第 59 步是同一個：<b>寫了訊息 ≠ 使用者看得到訊息。</b>中間少一段接線，程式完全正常，人卻看到亂碼般的英文。<br><br>☢️ <b>原本的錯誤文案是「請關掉這一頁重新打開」—— 那句話對桌機是【錯的】。</b>關掉重開，憑證還是同一張（它存在瀏覽器裡，不是存在分頁裡），所以照做只會再失敗一次。<b>叫人做一件沒有用的事，比不給建議更糟。</b><br><br>☢️☢️ <b>順手撈到一個更嚴重的：state 停在 <code>checking</code> 時，頁面會【往下走】。</b>四個教練頁的 <code>boot()</code> 只判斷 <code>browsing</code> 和 <code>error</code>，<code>checking</code> 沒人管 —— 於是在「正要跳去 LINE 重新登入」的那一刻，程式<b>把整個後台畫出來，看起來像已經登入</b>。實際上憑證是壞的，查詢會全部回空。<b>畫面正常、資料是空的，比一個明白的錯誤更難發現。</b>（實測時是因為假的 <code>liff.login()</code> 不會真的跳頁才露出來 —— 真實情況下頁面正在跳走，所以一直沒人看見。）四頁都補上擋板。<br><br>☢️ <b>自己讀 <code>exp</code> 不是拿來當驗證用的。</b>憑證真假還是伺服器問 LINE 才算數；這裡只是「明知過期就不要送」。而且<b>讀不到 <code>exp</code> 就當作沒過期</b>，交給伺服器判斷 —— 自己解析失敗就把人擋在門外，是拿一個小疑慮換一個大故障。<br><br>☢️ 留 <b>90 秒緩衝</b>。剛好在到期那一秒送出去，一樣會被拒。',
          note:'<b>2026-08-18 完成。</b>檔案：<code>line-prototype/liff-auth.js</code>、<code>staff.html</code>、<code>staff-tools.html</code>、<code>checkin.html</code>、<code>report.html</code>。<br><br><b>驗證</b>（自己做過期的假憑證，重現 Jerec 遇到的情況）：<ul><li>憑證已過期一小時 → <b>完全不送出</b>，直接去換一張 ✓</li><li>憑證只剩 30 秒（在緩衝內）→ <b>也不送</b> ✓</li><li>憑證還新 → 照常送出 ✓（不會誤擋）</li><li>連換兩次都失敗 → <code>liff.login()</code> <b>最多只叫兩次</b>、第二次前面確實有 <code>logout()</code>、然後<b>停下來</b>顯示「登入過期了」＋「重新登入」按鈕 —— <b>沒有無限跳轉</b> ✓</li><li><code>checking</code> 擋板：跳轉途中畫面顯示「正在重新登入…」，<b>不再假裝已登入</b> ✓</li></ul><b>全套回歸</b>：12 頁手機零 JS 錯誤、報表、登出、入口權限、桌機頂欄對齊 —— 全部重跑一次都過 ✓',
          ck:'憑證過期時，教練看到的是「登入過期了」和一顆「重新登入」，按一下就回到後台 —— 不是一行看不懂的英文。' },
        { n:63, t:'官網那套「預約」是假的 —— 拆掉，改成導到 LINE', where:'前端', done:true,
          summary:'客人在官網按下「立即預約」，店裡一筆都收不到',
          body:'Jerec 2026-08-18：<i>「官方網站上的預約系統與 line 官方所進入的預約系統在介面設計與功能上是不同步的，幫我同步這兩邊。」</i><br><br>去查才發現不是「不同步」這麼簡單 —— <b>官網那一套根本沒有連到任何東西</b>：<ul><li>按「立即預約」→ 只寫進<b>客人自己瀏覽器的 localStorage</b>（<code>gt-mine</code>），<b>店裡一筆都收不到</b>。客人以為約好了，然後直接來上課。</li><li>卡片上的名額圖示畫的是「你在這台裝置上的紀錄」——<b>對新訪客永遠是 0/10</b>，客滿的課看起來也是空的。頁面自己在下面小字承認了這件事，但沒有人會讀那行。</li><li>步驟說明寫著「額滿則顯示『加入候補』」——<b>那顆按鈕從來沒有被寫出來過</b>。</li><li>另有六處還在講舊系統的「團課群組／約課群組」，而那個群組已經沒有了。</li></ul><b>決定（Jerec）：官網不做預約，只導到 LINE。</b>課表保留（它是有用的招生內容），但標明是「每週固定課表」而不是「本週課表」——它沒有日期，停課、調課、加開都反映不出來。',
          warn:'☢️ <b>「拆掉假功能」比「修好假功能」重要。</b>把官網的預約接上資料庫是做得到的（桌機 LINE 登入第 59、62 步已經證明可行），但那會多出<b>第二個要維護的訂課入口</b>，而且兩邊的規則（一小時取消、缺席不扣課、額滿仍可報名）遲早又會分岔。一個入口比兩個一致的入口更容易保持一致。<br><br>☢️ <b>拆就要拆乾淨。</b><code>openForm</code>／<code>buildMsg</code>／<code>gt-mine</code>／收姓名手機的表單，全部一起拿掉。<b>「留著程式碼但不接上按鈕」不算拆乾淨</b> —— 下次有人看到 <code>openForm</code> 還在，會以為它只是壞了，然後把它修好。收個資的表單更不能留：欄位還在畫面上，資料卻哪裡都不會去。<br><br>☢️ <b>所有「預約」連結一定要用 <code>liff.line.me/2011063116-QOxXN30h/…</code></b>（規則 17）。寫成 <code>jerecyu.github.io/…</code> 的話，在 LINE 裡只是普通瀏覽器，<code>liff.isLoggedIn()</code> 會是 false，客人被當成沒綁定的人 —— <b>不會報錯，只是功能默默降級</b>。<br><br>☢️ <b>置中的坑</b>：<code>.btn</code> 是 <code>inline-flex</code>，單獨給它 <code>margin:0 auto</code> 沒有用（auto 邊界對非區塊元素不生效），按鈕會貼左、說明貼右。要包一層區塊容器。<br><br>☢️ <b>還沒做完的部分</b>：<code>#/pt</code> 和 <code>#/pgt</code> 仍然是「產生一段文字叫客人貼到 LINE」。那一套<b>至少真的會傳到店裡</b>（不像 GT 那樣憑空消失），所以危害小得多，但最終也要改成導到 LIFF。<b>連同價格一起改</b> —— Jerec 正在整理一份完整商品資訊，兩邊的 PT／PGT 價格目前對不起來（官網 PT 單堂 NT$1,800／LINE NT$1,500；PGT 官網整整高一階），而<b>兩組都不是最新的</b>，所以等文件到了一次改對。',
          note:'<b>2026-08-18 第一段完成（GT ＋ 文案），PT／PGT 與價格待續。</b>檔案：<code>index.html</code>。<br><br><b>做了什麼</b>：<ul><li>拆掉 GT 的假預約：按鈕、名額圖示、「我的預約」分頁、「已記錄 · 取消」、收姓名手機的表單、<code>localStorage</code> 全部移除</li><li>「本週課表」→「團體課課表」，並標明是每週固定時段、沒有日期</li><li>「前往預約」改成「在 LINE 裡預約」，指向 <code>liff.line.me/…/GT-booking.html</code>（GT／PT／PGT 三個下拉選項各自對應）</li><li>補上 LINE 那邊本來就有、官網卻沒寫的規則：<b>送出就生效</b>、<b>課前一小時內不能取消</b>、缺席不扣課、堂數由教練現場核銷、剩餘堂數在「我的預約」查</li><li>六處「團課群組／約課群組」全部改寫；「加入候補」改成「額滿仍可報名」（跟系統實際行為一致）</li></ul><br><b>驗證</b>：官網十個分頁（首頁／預約／GT／價目表／課表／PT／PGT／服務／關於／聯絡）<b>零 JS 錯誤</b>；手機 390px 與桌機 1400px 都沒有橫向溢出；「已記錄／加入候補／團課群組／約課群組」四個字眼全站掃過<b>一個都不剩</b> ✓',
          ck:'客人在官網按「預約」，會被帶到 LINE 裡真的訂得到課的地方 —— 而不是在官網按完之後以為約好了。' },
        { n:64, t:'一筆預約可以是多個人 —— 「帶了幾位」改成「共幾人」', where:'SQL ＋ 前端', done:true,
          summary:'要靠心算才填得對的欄位，遲早會填錯，而錯的是錢',
          body:'Jerec 2026-08-18：<i>「吳佳芳想幫兩位兒子報名 8/19 的 GT，系統拒絕說只能報一人……明天只有兩個兒子上課，吳佳芳不上課，但也有時候是三位都一起上。」</i><br><br><b>系統拒絕第二次報名是對的</b>（<code>bookings</code> 有 <code>unique(session_id, customer_id)</code>，那是防重複報名的）。要多帶人走的是另一條路，而那條路本來就有 —— 只是<b>算法不對</b>。<br><br><b>舊模型</b>：<code>guest_count</code> = 除了本人以外還帶幾個，扣 <code>1 + guest_count</code> 堂。<b>它假設本人一定會來。</b>吳佳芳不來、只有兩個兒子來的時候，教練得填「帶 1 位」才扣得對（2 堂）—— 紀錄上卻寫著「她來了 ＋ 帶 1 人」，而那是假的。<br><br><b>新模型</b>：<code>attendee_count</code> = 這一筆總共幾個人上課（預設 1），扣一樣多堂。三人都來填 3、只有兩個兒子填 2、只有她填 1。<b>教練填的就是眼睛看到的人數，不用換算。</b>',
          warn:'☢️ <b>「出席」的意思跟著變了</b>：從「吳佳芳本人有沒有來」變成「<b>這個名額有沒有被用到</b>」。而堂數帳本來關心的就是後者 —— 舊模型其實也沒真的在追蹤本人到沒到（她本來就可以派人來）。<br><br>☢️☢️ <b>為什麼是【改名 ＋ 搬資料】而不是「沿用同一欄、改變意思」。</b>同一個欄位換意思是這個專案能犯的最貴的錯：<b>舊資料還躺在那裡，數字沒變，意思卻變了，而且不會有任何錯誤</b>。改名之後，任何還在讀 <code>guest_count</code> 的地方會【當場壞掉】—— 那正是我要的。<b>壞掉看得見，意思悄悄改掉看不見。</b><br><br>☢️ <b>搬資料的順序不能換</b>：先改名 → 再 +1 → 再設 default 1 → 最後換檢查條件。先設 default 的話，接下來的 +1 會把新寫入的列也算進去。<br><br>☢️ <b>舊的 <code>set_guests</code> 直接刪掉，不留相容層。</b>留著的話會有一支前端傳「額外人數」、另一支傳「總人數」，<b>兩邊都不會報錯，而錯的是扣幾堂</b>。<br><br>☢️☢️ <b>順手修掉一個一直都在的名額錯誤。</b><code>public_schedule.booked_count</code> 本來是 <code>count(bookings)</code> —— <b>數筆數，不數人數</b>。所以吳佳芳帶兩個兒子在課表上只佔 <b>1 個位子</b>，現場卻會坐 3 個人。<b>課表說「還有空位」，教室其實已經滿了。</b>越常用這個功能，落差越大。改成 <code>sum(attendee_count)</code>。<code>gt_payout_sessions</code>（教練鐘點）也一起改，否則帶人來的課會少算人頭。<br><br>☢️ <b>人數控制要在課前就看得到。</b>舊版只在點名之後才出現 —— 但幫家人報名、現場加人都是<b>課前</b>的動作，課前看不到就沒得填。',
          note:'<b>2026-08-18 完成。</b>檔案：<code>db/36-attendee-count.sql</code>、<code>line-prototype/checkin.html</code>。<br><br><b>☢️ 最重要的驗證：舊資料的錢有沒有被動到。</b>126 筆預約裡有 <b>2 筆</b>是舊制「帶 1 人」的，兩筆都已經點過名、各扣 2 堂。搬完之後 <code>attendee_count = 2</code>，新制應扣也是 2 —— <b>逐筆核對，帳本一分一毫都沒變</b> ✓<br>其餘 124 筆從 <code>guest_count = 0</code> 變成 <code>attendee_count = 1</code>，意思相同 ✓<br><br><b>前端驗證</b>（假資料三種狀態各一位）：<ul><li>未點名、共 3 人 → 顯示「這一筆共 3 人上課（扣 3 堂）」，<b>課前就看得到</b> ✓</li><li>已出席、1 人 → 「改成缺席／退回 1 堂」 ✓</li><li>已缺席、共 2 人 → 「改成出席／扣 2 堂」 ✓</li><li>按 ＋ 送出的是 <code>set_attendees</code>，帶的是<b>新的總人數</b>（不是增量）✓</li><li>下限 1、上限 6；零 JS 錯誤 ✓</li></ul>',
          ck:'吳佳芳帶兩個兒子來，教練填「3 人」就扣 3 堂；她自己不來、只有兒子來，就填「2 人」扣 2 堂 —— 不用心算。而且課表上的名額數的是人。' },
        { n:65, t:'報名後看得到同學是誰（姓名遮蔽）', where:'SQL ＋ 前端', done:true,
          summary:'吳〇芳、林〇婷 —— 看得到有誰，看不到是誰',
          body:'Jerec 2026-08-18 轉述客人的要求：<i>「客人會希望每次報名時也可以知道還有誰報名這堂課程，但只有檢視其他報名者局部姓名的功能，例如報名後有個小臨時視窗顯示：吳X芳、林X婷。」</i><br><br>報名成功之後自動跳出一張小卡，列出這堂課的同學：<code>吳〇芳</code>、<code>林〇婷</code>、<code>A***</code>。已經報名的課，卡片上也有一個「看看這堂還有誰 ›」。<br><br><b>顯示的只有三樣</b>：遮蔽後的姓名、這一筆幾個人、以及哪一個是自己。手機、堂數、出缺席狀態<b>一律不給</b>。',
          warn:'☢️☢️ <b>「誰看得到」這道門寫在資料庫，不在前端。</b><code>session_mates()</code> 自己擋兩關：① 必須是已綁定的客人 ② <b>必須自己也報了這一堂</b>。沒有第 ② 關的話，這支就變成「<b>輸入課程編號就能查出全館誰在上課</b>」的工具。<br>☢️ 前端<b>不做任何判斷</b> —— 判斷寫在兩個地方，遲早會不一致，而不一致的那一次就是外洩。<br><br>☢️ <b>遮蔽規則要處理「中文名 ＋ 英文名」。</b>第一版逐字遮，「吳弘琳 Wendy」變成「吳〇〇〇〇〇〇〇y」—— <b>又醜又沒有比較安全，而且尾巴那個 y 反而把英文名洩出來了</b>。93 位客人裡有 <b>18 位</b>是這種名字。改成<b>只取第一段連續的中文</b>：「吳〇琳」。純英文名走另一條路：<code>A***</code>。<br><br>☢️ <b>這不是強隱私。</b>10 人的班、93 位客人的館，「吳〇芳」通常只對得到一個人。這是 Jerec 明確要的功能，做成「看得到有誰、看不到聯絡方式」的程度；<b>不要把 <code>mask_name()</code> 當成別處的隱私保護</b>（函式的註解裡也寫了）。<br><br>☢️ 蓋板要在 <code>render()</code> <b>之後</b>才叫，而且<b>不要 await</b> —— 重畫會把蓋板的 class 洗掉，而名單讀不到不該影響「已經報名成功」這件事。',
          note:'<b>2026-08-18 完成。</b>檔案：<code>db/36-attendee-count.sql</code>（<code>mask_name</code>、<code>session_mates</code>）、<code>line-prototype/GT-booking.html</code>。<br><br><b>遮蔽規則驗證</b>（12 種名字逐一測）：<ul><li>吳佳芳 → 吳〇芳　·　王惠 → 王〇　·　歐陽小明 → 歐〇〇明</li><li><b>吳弘琳 Wendy → 吳〇琳</b>　·　Wendy 吳弘琳 → 吳〇琳　·　荔芬Adele → 荔〇</li><li>Adele → A***　·　空白／null → （未填姓名）</li></ul><b>權限驗證</b>（用真實身分實際呼叫）：<ul><li>吳佳芳（有報 8/19 那堂）→ 看得到 6 位遮蔽姓名，自己被標成「你」 ✓</li><li>Adele（有綁 LINE、<b>沒報這一堂</b>）→ <b>被擋</b>：「你還沒報名這一堂」 ✓</li><li>沒綁 LINE 的客人 → <b>被擋</b>：「要先綁定手機才看得到同學名單」 ✓</li></ul><b>畫面驗證</b>：手機 420px 下蓋板正常，合計人數用 <code>attendee_count</code> 加總（不是列數），零 JS 錯誤 ✓',
          ck:'客人報名完，馬上看到「這堂還有誰：吳〇芳、林〇婷…」；沒報這堂的人打什麼都查不到。' },
        { n:66, t:'☢️ 我把點名頁弄壞了 —— drop view 會把權限一起帶走', where:'SQL', done:true,
          summary:'用一個繞過權限的身分去驗權限，不是疏忽，是方法本身錯了',
          body:'第 64 步推上去之後，Jerec 打開點名核銷，畫面是<b>「讀不到名單 · permission denied for view staff_roster」</b>。<b>整個點名功能停擺</b>，直到他回報。<br><br><b>原因</b>：為了把 <code>guest_count</code> 改名成 <code>attendee_count</code>，<code>staff_roster</code> 用了 <code>drop + create</code>（<code>create or replace view</code> 不能改欄位名稱 —— 這個限制這個專案已經踩過三次）。<b>☢️ 而 <code>drop view</code> 會把這張檢視表的 GRANT 一起帶走。</b>重建之後 <code>authenticated</code> 沒有 <code>SELECT</code>。<br><br>修法是一行 <code>grant select on public.staff_roster to authenticated;</code>。',
          warn:'☢️☢️ <b>為什麼我的驗證沒抓到 —— 這才是重點。</b>我驗了檢視表的【內容】（欄位對不對、數字對不對、舊資料有沒有被動到），全部都對。<b>但我沒驗它的【權限】。</b><br>而且更根本的是：<b>我用來測試的連線是 <code>service_role</code>，它繞過所有 GRANT</b>。所以在我這邊怎麼查都是好的，在教練的手機上是壞的。<br><br>☢️ <b>「用一個繞過權限的身分去驗權限」不是疏忽，是方法本身錯了。</b>之前所有「用 set_config 換成某位教練的身分」的驗證，都只換了 <b>auth.uid()</b>（我是誰），<b>沒有換資料庫角色</b>（我能不能）。RLS 測得出來，GRANT 測不出來。<br><br>正確的驗證要兩層都換：<br><code>perform set_config(\'request.jwt.claims\', …, true);　-- 換 auth.uid()</code><br><code>set local role authenticated;　　　　　　　　　-- ★ 換資料庫角色</code><br><code>select … ;　　　　　　　　　　　　　　　　　　-- 這時 GRANT 才會生效</code><br><code>reset role;</code><br><br>☢️ <b>通則：<code>drop view</code> 之後一定要重新 grant。</b><code>create or replace view</code> 會保留權限，<code>drop + create</code> 不會。而這個專案只有在「改欄位名稱／把欄位插到中間」時才需要 drop —— <b>也就是說，每一次踩到那個限制，就會同時踩到這一個</b>。兩件事要綁在一起記。<br><br>☢️ <b>時機也值得記一筆。</b>我在交付時有提醒「資料庫已改、網站還沒，先推送」—— 但那句話講的是<b>另一個</b>問題（欄位改名）。推送之後那個問題確實解決了，<b>而這個問題被那句提醒蓋住了</b>：他以為推完就好，結果推完還是壞的。<b>提醒了一個風險，不代表沒有第二個。</b>',
          note:'<b>2026-08-19 凌晨修復。</b>檔案：<code>db/37-fix-roster-grant.sql</code>。<br><br><b>修完之後用【真的換角色】的方法重驗</b>（<code>set local role authenticated</code>）：<ul><li>Jerec／VC／Peter 三個身分讀 <code>staff_roster</code> → <b>都讀得到，63 列</b> ✓</li><li>「同學名單」用真實客人身分跑：吳佳芳看得到 7 位遮蔽姓名、自己被標成「你」；沒綁定的被擋 ✓</li></ul><b>順手把整個權限層盤點一次</b>（這是第一次做）：<ul><li>前端會用到的 <b>11 張檢視表</b>，<code>authenticated</code> 的 <code>SELECT</code> → 全部都有 ✓</li><li>前端會呼叫的 <b>14 支函式</b>，<code>EXECUTE</code> → 全部都有 ✓</li><li>五張 staff 檢視表的 <code>reloptions</code> → 都是空的，確認還是 <b>definer</b> 不是 <code>security_invoker</code> ✓（<code>pg_get_viewdef()</code> 看不到這個，要看 <code>pg_class.reloptions</code>）</li></ul>',
          ck:'教練打開點名核銷看得到名單 —— 而且以後任何一次 drop view 之後，權限盤點是驗證的固定一環，不是想到才做。' },
        { n:67, t:'職員專屬圖文選單 —— 同一格，客人傳訊息、教練進後台', where:'LINE 設定 ＋ 前端', done:true,
          summary:'不是多一格，是多一張只有八個人看得到的選單',
          body:'Jerec 2026-08-18：<i>「想做一個職員與學員的統一入口……學員點擊「聯絡我們」的功能是自動回覆訊息，而職員點擊則是點名核銷與教練後台，這樣可行嗎？」</i>後來又問：<i>「已經劃分六宮格了，再新增一個教練專屬選單，畫面會不會太擠？」</i><br><br><b>不會擠 —— 它不是在現有選單裡多一格。</b>LINE 允許同一個官方帳號掛兩張圖文選單：一張是<b>預設</b>的（所有人），另一張用 API <b>綁到特定的 userId</b>。被綁的人看到的就是另一張，<b>取代</b>原本那張。<br><br><table><tr><td></td><td><b>客人</b></td><td><b>職員</b></td></tr><tr><td>格數</td><td>六格</td><td><b>一樣六格</b></td></tr><tr><td>前五格</td><td>訂課／我的預約／PT／PGT／價目表</td><td><b>完全相同</b></td></tr><tr><td>第六格</td><td>聯絡我們 → 自動回覆</td><td>聯絡我們 → <b>staff.html</b></td></tr><tr><td>圖</td><td>現在這張</td><td>同一張，第六格多一行「★ STAFF 入口」</td></tr></table><br>另一個做法（共用一格、進去才分流）比較差：客人點下去會跳出網頁，<b>失去「點一下就自動回覆」</b>那個體驗。',
          warn:'☢️ <b>建立選單時 <code>selected</code> 必須是 <code>false</code>。</b>設成 true 會把它變成<b>全部使用者的預設選單</b> —— 203 位客人當場看到「STAFF 入口」，而且第六格會把他們帶到教練頁面（進得去看不到東西，但那是驚嚇）。<br><br>☢️ <b>上傳底圖的網域是 <code>api-data.line.me</code>，不是 <code>api.line.me</code>。</b>用錯會回 404，而 404 看起來像「選單不存在」—— 其實選單好好的，只是傳錯地方。<br><br>☢️ <b>PowerShell 5.1 兩個坑</b>：① 預設可能用 TLS 1.0，LINE 只收 1.2 以上，不設會是「無法建立 SSL/TLS 安全通道」，那個訊息完全看不出跟 TLS 有關；② <code>Invoke-RestMethod</code> 送字串時預設不是 UTF-8，<b>中文的選單名稱會變亂碼</b> —— 要自己轉成 UTF-8 位元組再送。<br><br>☢️ <b>2500 ÷ 3 除不盡</b>（833.33）。中間那格給 834，總和才剛好 2500。<b>差一個像素 LINE 會拒絕整張選單。</b><br><br>☢️☢️ <b>userId 真的對不上 —— 這不是預警，是實測結果。</b>我們手上的七個 userId 來自 <b>LINE Login channel（2011063116）</b>，而圖文選單屬於 <b>Messaging API channel（2009245280）</b>。LINE 的 userId 是<b>以 provider 為單位</b>的 —— 兩個 channel 在同一個 provider 底下才會是同一組 ID。<b>2026-08-19 證實了</b>：Jerec 在 LINE Login 是 <code>Ue999b97…11b9</code>，在 Messaging API 是 <code>Ud623ef0…adf9</code> —— <b>同一個人，兩組完全不同的號碼</b>。直接把舊的貼過去會六個全部 404，而 404 的訊息不會告訴你原因。<br>☢️ 拿另一組編號的兩條路：<code>GET /v2/bot/followers/ids</code>（要「認證帳號」，實測 <b>403</b>）、或 <b>webhook</b>（走這條，請六位教練各傳一則 <code>STAFF 名字</code>）。<br><br>☢️ <b>圖上那行「傳訊息給櫃檯」對職員會變成謊話</b> —— 他按下去是進教練頁面，不是傳訊息。所以 <code>staff.html</code> 加了一顆<b>「回聊天室傳訊息給櫃檯」</b>（只在 LINE App 裡出現，按下去 <code>liff.closeWindow()</code>）。<b>網頁沒有權限代替使用者發訊息</b> —— 我們刻意沒要 <code>chat_message.write</code>，那個權限會讓 LIFF 視窗縮不到底下。能做的是把視窗關掉，人就回到聊天室。<br><br>☢️ <b>兩張圖要一起改。</b>只改一張的話，教練跟客人講的畫面會對不上。',
          note:'<b>2026-08-19 上午完成，六位教練全部綁定成功。</b>檔案：<code>assets/brand/richmenu-staff-source.html</code>、<code>shot-staff.py</code>、<code>fff-richmenu-staff.png</code>（448 KB）、<code>tools/setup-staff-richmenu.ps1</code>、<code>tools/probe-line-ids.ps1</code>、<code>supabase/functions/line-hook</code>、<code>line-prototype/staff.html</code>。<br><b>選單編號</b>：<code>richmenu-2f804e043225b42746866072c55249ec</code>（換圖或解除綁定會用到）。<br><br><b>綁定名單（6 位）</b>：Jerec、VC、Peter、Jessica、Johnson、林智謙。<b>簡基城博士不在名單上</b> —— 顧問／股東身分，用不到教練工具；他在系統裡仍然是教練，只是六宮格維持客人版。<br><br><b>驗證</b>：Jerec 手機實測 —— 右下角顯示「聯絡我們／傳訊息給櫃檯／★ STAFF 入口」，聊天列名稱變成「教練選單」，點進去是教練登入頁（含「回聊天室傳訊息給櫃檯」）；<b>前五格一個字都沒動</b>；<b>客人的自動回覆照常運作</b>（開 Webhook 前後各測一次）✓<br><br><b>收尾</b>：LINE 的 Webhook 開關關回去、<code>line-hook</code> 換成不做事的版本。<b>兩邊都斷</b> —— 只斷一邊的話，下次有人把 LINE 那個開關打開，程式就又默默開始收資料了。資料表 <code>line_messaging_ids</code> <b>保留</b>（以後新增教練或重新綁定還用得到那六個編號）。',
          ck:'教練打開 LINE，第六格寫著「★ STAFF 入口」，按下去直接進教練入口；客人的第六格一個字都沒變，按下去還是自動回覆。' },

        { n:68, t:'PT／PGT 價格進資料庫 —— 五個地方的數字全部收成一份', where:'資料庫 ＋ 前端 ＋ 工具', done:true,
          summary:'客人正在看的數字是錯的，而且錯的方向是「少報」',
          body:'Jerec 2026-08-19 給了《財務與教練薪資整合規則》正式版。對照之後發現<b>客人現在看到的 PT／PGT 價格跟規則不一樣</b>：<br><br><table><tr><td></td><td><b>客人看到</b></td><td><b>規則</b></td><td><b>差額</b></td></tr><tr><td>PT 單堂 一對一</td><td>NT$1,500</td><td><b>NT$1,800</b></td><td>少報 300</td></tr><tr><td>PT 10 堂 一對一</td><td>NT$12,000</td><td><b>NT$15,000</b></td><td>少報 3,000</td></tr><tr><td>PGT 一對三</td><td>NT$1,800</td><td><b>NT$2,100</b></td><td>少報 300</td></tr><tr><td>PGT 一對四</td><td>NT$2,100</td><td><b>NT$2,400</b></td><td>少報 300</td></tr><tr><td>PGT 一對五</td><td>NT$2,400</td><td><b>NT$2,700</b></td><td>少報 300</td></tr><tr><td>PGT 一對六</td><td>沒有（寫「以此類推」）</td><td><b>NT$3,000，六人為上限</b></td><td>—</td></tr></table><br><b>為什麼會錯：同一個數字散在五個檔案裡。</b>改價的時候只要漏掉一個，那一頁就永遠停在舊價。所以這一步不只是改數字，是<b>把價格搬進資料庫的 <code>products</code> 表</b>，讓它變成唯一的正本。<br><br><b>Jerec 選的是「B 案」</b>：LIFF 那幾頁去資料庫讀（改價不用推程式）；<b>官網維持寫死</b>（它是靜態網站，讀資料庫會拖慢首頁）——但<b>多加一支自動比對</b>，官網跟資料庫對不上就當場報錯。',
          warn:'☢️ <b>價格讀不到不能讓畫面空白。</b>每一頁都先畫「備援數字」（HTML 裡本來就寫著），資料庫回來了才蓋上去。網路慢或資料庫掛掉時，客人看到的是舊價格 —— 不是空的，也不是 <code>undefined</code>。<br><br>☢️ <b>備援數字本身也會走鐘。</b>它是第二份寫死的數字，所以 <code>tools/check-prices.html</code> 連它一起對。<br><br>☢️ <b>同一個代號在一頁裡會出現好幾次</b>（表格一次、文案一次、規格卡一次）。比對程式如果把它們整併成「代號→價格」的對照表，<b>只要最後一次是對的，前面漏改的就被蓋掉看不見了</b>。所以它回傳的是一筆一筆的清單，不是對照表。<br><br>☢️ <b><code>products</code> 只是牌價，不是實收。</b>實際收多少一律看 <code>credit_ledger.amount</code>（購課當下就把金額存起來了）。所以改牌價<b>不會動到任何一筆已成交的錢</b>。<br><br>☢️ <b>PT 半堂 NT$600 是內部價，設成 <code>is_active = false</code></b>。<code>add_purchase</code> 只認 active 的方案，所以就算代號被猜到也買不了。<br><br>☢️ <b>PGT 不販售預付</b>，所以表裡只有單堂、沒有 10 堂包。<br><br>☢️ <b><code>supabase-config.js</code> 現在要能在「沒載 CDN」的頁面上跑</b>（價目表是純靜態頁，不需要整包 supabase-js）。所以網址與金鑰的匯出<b>必須放在 <code>createClient</code> 前面</b> —— 放後面的話，CDN 一失敗就整支斷在那行，後面什麼都匯不出去。',
          note:'<b>2026-08-19 完成。</b>檔案：<code>db/38-products-pt-pgt.sql</code>、<code>line-prototype/prices.js</code>（新）、<code>tools/price-extract.js</code>（新）、<code>tools/check-prices.html</code>（新），以及 <code>pricing.html</code>、<code>PT-booking.html</code>、<code>PGT-booking.html</code>、<code>A-entry.html</code>、<code>GT-booking.html</code>、<code>index.html</code>、<code>supabase-config.js</code>。<br><br><b><code>products</code> 新增兩個欄位</b>：<code>headcount</code>（幾個人一起上）、<code>kind</code>（trial／single／pack／half）。前端靠這兩個欄位就能把價目表排出來，不用去猜 label 裡的中文字。<br><br><b>驗證</b>：① 以 <code>authenticated</code> 與 <code>anon</code> 兩種身分實際查表，13 筆全讀得到（<b>不是</b>用 MCP 的 service_role 查 —— 那個繞過所有權限，看不出問題，第 66 步的教訓）✓ ② 無頭瀏覽器實測兩種情境：<b>資料庫連不上</b>→ 五頁都顯示備援數字、沒有 <code>undefined</code>、沒有 JS 錯誤；<b>資料庫回了不同的價格</b>→ 五頁當場跟著變 ✓ ③ 比對程式跑過全部五個來源共 <b>54 項</b>，全對；再故意改壞三處（數字錯、代號打錯、漏一筆），三種都被抓出來 ✓ ④ PGT 加號按到 6 就停住 ✓',
          ck:'打開 <code>tools/check-prices.html</code>（要從網站上開，不是用檔案總管點），整頁綠色寫「全部一致」。'},

        { n:69, t:'團體課每班上限統一為 12 —— 順便讓「超過 12 人」看得見', where:'資料庫 ＋ 前端', done:true,
          summary:'網站寫 10、資料庫也是 10，但規則早就改成 12 了',
          body:'Jerec 2026-08-19：<i>「GT 每班上限是 12，不會出現 13 人以上。團體課購買也是 12（10＋2）為一組。」</i><br><br><b>動手前的實際狀況</b>：<table><tr><td>週課表範本</td><td>14 筆<b>全部是 10</b></td></tr><tr><td>已排定的課</td><td>117 筆是 10（其中 28 筆是<b>未來的</b>）、9 筆是 12</td></tr><tr><td>兩張表的預設值</td><td><b>都還是 10</b> → 明天自動長出來的課又會是 10</td></tr><tr><td>網頁文案</td><td><b>20 句</b>「每班上限 10 人」散在 4 個檔案裡</td></tr></table><br><b>預設值是這一步最重要的一行。</b>只改現有資料不改預設值的話，今天改完，明天 pg_cron 長出來的課又是 10 —— 而且不會有任何錯誤訊息。<br><br><b>過去的課刻意不動。</b>那些課當時的上限就是 10，改掉等於竄改紀錄。capacity 不參與任何金額計算（薪資看的是實際出席人數），所以留著舊值不影響對帳，只會讓歷史是誠實的。',
          warn:'☢️ <b>這次改動不可能弄壞任何預約</b> —— 動手前先查過：目前人數最多的一堂是 <b>8 人</b>，沒有任何一堂接近上限。10 → 12 是「放寬」，只會讓剩餘名額變多。<b>先查再改，不要先改再查。</b><br><br>☢️ <b>「超過上限」不等於「額滿」。</b>額滿是正常的 —— 我們本來就不擋額滿報名（那是 Jerec 選的）。超過上限是<b>資料異常</b>：可能重複報名，也可能點名時「另外帶了 N 位」按多了。所以做的是<b>看得見</b>，不是<b>擋下來</b>。<br><br>☢️ <b>上限的 CHECK 不能一刀切死。</b><code>class_sessions</code> 未來要放 PGT（上限 6）和場租 RT（整場 20~25 人），所以條件寫成「product 不是 GT，或 capacity ≤ 12」。寫死 <code>capacity &lt;= 12</code> 的話，以後開場租會被自己的規則擋住。<br><br>☢️ <b>文案的比對不能靠人工標記。</b>「上限 N 人」散在內文、表格、SEO 描述、下拉選單裡 —— 靠手動加標記一定會漏。比對程式改成<b>直接掃整份文字</b>，所以以後不管誰在哪裡多寫一句舊數字，都會被抓到。<br><br>☢️ <code>staff_overbooked</code> 是 <b>definer</b> 檢視表，牆是 <code>is_staff()</code>。<b>不要加 <code>security_invoker</code></b>（見第 25、66 步）。',
          note:'<b>2026-08-19 完成。</b>檔案：<code>db/39-capacity-12.sql</code>（新）、<code>line-prototype/staff-tools.html</code>、<code>tools/price-extract.js</code>、<code>tools/check-prices.html</code>，以及 <code>index.html</code>、<code>pricing.html</code>、<code>GT-booking.html</code>、<code>A-entry.html</code> 共 <b>20 句</b>文案。<br><br><b>驗證</b>：① 週課表範本 14 筆全部 12、未來的課 28 筆全部 12、過去的課原封不動（89 筆 10 ＋ 9 筆 12）✓ ② 以 <code>anon</code> 身分查公開課表，28 堂的上限只有一種值：12 ✓ ③ <code>staff_overbooked</code> 用真實身分測兩種人：職員查得到（目前 0 筆＝乾淨）、一般客人被擋（<code>is_staff()</code> 是 false）✓ ④ 把門檻假裝降到 5，同一段邏輯抓出 5 堂 —— <b>證明它真的會抓，不是永遠空的</b> ✓ ⑤ 後台那一塊沒資料時回空字串（整塊不出現），有資料時版面正確 ✓ ⑥ 比對頁增加到 <b>63 項</b>，全綠；再故意讓資料庫停在 10，四個檔案全部被標紅 ✓',
          ck:'比對頁最下面多一張「團體課每班上限」的卡片，寫著 ✅ 5 項全對；後台<b>沒有</b>出現紅色的「人數超過上限」區塊（有出現才是要處理的事）。'},

        { n:70, t:'分享課程 ——「＋2」有上限了，而且看得出被分享的是誰', where:'資料庫 ＋ 前端', done:true,
          summary:'買 10 送 2，送的那 2 堂可以給別人；一組就是 2 次，不能無限外流',
          body:'Jerec 2026-08-19 拍板兩件事：<br>① <b>舊堂數怎麼算額度 → 選 B：每 12 堂就給 2 次</b>，不分新舊。<i>「有些學員因工作關係，有一段時間沒上，但有許多餘課，把原本的權益拿掉，怕客戶反感；真正鑽漏洞的只有家庭成員，這樣的狀況極少。」</i><br>② <b>被分享人可以不留姓名手機，只留線索</b>（跟分享人的關係）。<br><br><b>額度怎麼算</b>：<code>floor(累計拿到的堂數 ÷ 12) × 2</code>，算在<b>付堂數的那個人</b>身上（不是報名的人）—— 因為被稀釋的是他的 10 送 2。<br><br><b>本人有沒有上，是這一步的關鍵。</b><code>attendee_count</code> 是「現場實際幾個人」，它分不出兩種情況：<table><tr><td>本人＋1 位朋友</td><td>2 人</td><td>用掉 <b>1</b> 個額度</td></tr><tr><td>兩個兒子來、媽媽沒來</td><td>2 人</td><td>用掉 <b>2</b> 個額度</td></tr></table>所以 <code>bookings</code> 多一欄 <code>owner_present</code>，點名頁多一個勾選框。<br><br><b>目前實際狀況</b>（動手時查的）：全系統只有 3 筆 2 人預約。吳佳芳那筆（8/19 12:20）是<b>兩個兒子上、她自己沒上</b>，所以 <code>owner_present</code> 補成 false、算 2 個額度 —— 她的額度剛好用完。',
          warn:'☢️ <b>這一步不動任何一筆錢。</b>扣堂數的規則完全沒改（還是 <code>check_in</code> 依 <code>attendee_count</code> 扣、扣在 <code>paid_by_customer_id</code> 身上）。做完之後三個人的餘額分毫未動：16／6／10，整個 GT 帳本 204 筆、淨 708 堂，跟做之前一模一樣。<br><br>☢️ <b>「用掉幾次」要從 <code>attendee_count</code> 算，不能數被分享人的筆數。</b>線索是選填的 —— 教練沒填的話筆數是 0，額度就會被少算，而扣堂數看的是 <code>attendee_count</code>。兩邊看同一個數字才不會對不起來。<br><br>☢️ <b>只有在人數【變多】的時候才檢查額度。</b>舊資料本來就可能超額（第 70 步之前沒有這條規則，實測有一位是 −1），如果連「不變」和「變少」都擋，教練會連改回去都做不到 —— <b>規則會把人鎖死在錯誤的狀態裡</b>。<br><br>☢️ <b>額度不夠不是「錯誤」，是規則擋下來</b>，所以走 <code>ok:false</code> 而不是丟例外。而且訊息要講<b>現在該怎麼辦</b>：櫃檯站著一個客人的時候，「這一筆最多只能填 2 人」比「額度不足」有用一百倍。<br><br>☢️☢️ <b><code>staff_roster</code> 又 drop 重建了一次</b> —— <b>GRANT 會跟著消失</b>（第 66 步就是這樣把點名頁弄壞的）。這次有重新 grant，而且用 <code>set local role authenticated</code> 帶真實身分驗過拿得到 66 筆。<br><br>☢️ <code>shared_attendees</code> <b>不是客人名單</b>。姓名手機可以全空，它只是「這個座位是誰」的線索。不要拿它當 <code>customers</code> 用。<br><br>☢️ <b>寫入完全不開 policy</b> —— 只有 select。所有異動一律走 RPC，跟第 39 步「動到規則的入口只有一個」同一個原則。',
          note:'<b>2026-08-19 完成。</b>檔案：<code>db/40-shared-classes.sql</code>（新）、<code>line-prototype/checkin.html</code>、<code>line-prototype/report.html</code>。<br><br><b>新東西</b>：<code>bookings.owner_present</code>、<code>shared_attendees</code> 表、<code>gt_share_quota()</code>／<code>gt_share_used()</code>、改寫的 <code>set_attendees(uuid, smallint, boolean)</code>、<code>set_share_labels()</code>、<code>staff_share_log</code> 檢視表。<br><br><b>驗證</b>：① 額度計算對三位真實客人核過 —— 累計 9 堂→額度 0（已用 1，超額 −1，誠實呈現）、22 堂→額度 2（已用 2）、12 堂→額度 2（已用 1）✓ ② 用真實職員身分跑四種情境（全部在交易裡跑完 rollback，沒動到正式資料）：超額被擋、剛好夠通過、再加一個被擋、變少不檢查 ✓ ③ 點名頁四種畫面實測：<b>單人預約完全看不到這一塊</b>（129 筆的畫面一個字沒變）、本人＋1 位、兩個兒子本人沒上、舊資料超額顯示 −1 ✓ ④ 8 個頁面無頭瀏覽器載入，零 JS 例外 ✓ ⑤ 餘額與帳本總數做前做後完全相同 ✓',
          ck:'點名頁把某一筆按成 2 人，下面會出現「本人也有上這堂」的勾選框、一格「第 1 位」線索欄，右邊寫著還剩幾次可以分享；額度用完再按＋會跳出「這一筆最多只能填 N 人」。'}
      ]
    },

    /* ══════════ 第六幕 ══════════ */
    {
      key: 'a6', place: '帳房', no: '第六幕', name: '開帳房', theatre: '＝ 蓋帳房、把錢算清楚',
      note: '前五幕都在讓「課」跑得動。這一幕開始管<b>錢</b> —— 誰付了多少、誰該領多少。<br><br>☢️ 這一幕有四步不是新功能，是<b>把已經算錯的帳找出來</b>（第 75～77、79 步）。帳務系統的價值不在算得快，在於<b>算錯的時候有人發現</b>。',
      milestone: {
        title: '▲ 第六幕結束 — 你現在擁有的',
        text: '一本自己會對帳的 GT 帳本、一個能把外派／企業包班／私人課逐筆記進去的服務登記，以及一份四條線各自算清楚、最後才加起來的薪資報表。<b>錢從客人手上到教練手上，中間每一段都留得下紀錄。</b>☢️ 但帳房還沒接上金庫 —— 見第七幕。'
      },
      steps: [

        { n:71, t:'服務紀錄骨架 —— 外派、諧動活動、企業包班一次到位', where:'資料庫 ＋ 前端', done:true,
          summary:'PT／PGT 四年來只記在 Excel 裡，系統一筆上課紀錄都沒有',
          body:'Jerec 2026-08-19：<i>「四個新商品（外派／諧動活動／企業包班／課程轉讓）現在就可以上。」</i><br><br><b>但先發現一個順序問題。</b>這三個商品都要記「這一次服務發生了、誰上的、認列多少」，而系統<b>只有 GT 有這種紀錄</b>（bookings ＋ 點名核銷）。<b>PT／PGT 本身一筆上課紀錄都沒有</b> —— 只有 <code>pt_requests</code>（客人送給教練的需求單）。外派是 PT／PGT 的加購項，所以它沒辦法比 PT／PGT 本體早做。<br><br><b>而答案早就寫在 Jerec 的 Sales Record 裡了。</b>「PT流水帳」15,861 筆，欄位是：<br><code>日期｜時間｜教練｜學員｜銷課方式｜上課人數｜堂數｜當課教練抽成前業績｜課程方案｜已銷課堂數 3/10</code><br>那就是規則文件第六篇 4 講的「<b>共用結算紀錄</b>」，而 <code>3/10</code> 那一格就是「<b>方案</b>」。他已經這樣記了四年，只是記在 Excel 裡。這一步就是把那本 Excel 的形狀搬進資料庫。<br><br><b>錢怎麼算（全部照規則文件，不是猜的）</b>：<table><tr><td><b>PT／PGT</b></td><td>課程費照檯面價</td><td>全額進該教練 PT＋PGT 抽成</td></tr><tr><td><b>外派</b></td><td>課程費 ＋ 交通費 <b>500／次</b></td><td><b>兩個都</b>進抽成，不另付外派鐘點費</td></tr><tr><td><b>諧動活動</b></td><td>教練人數×時數×600 ＋ 時數×600 ＋ 交通 500</td><td>每位教練＝時數×600，<b>不進抽成</b></td></tr><tr><td><b>企業包班</b></td><td>人工核定整案總價</td><td>總價全額併入該教練抽成</td></tr></table>',
          warn:'☢️ <b>GT 不搬進來。</b>GT 已經在線上收錢（bookings ＋ check_in），重做等於拿正在運作的功能去冒險。GT 的 booking id 就當它的服務紀錄 ID，以後算薪水時用一張檢視表把兩邊併起來。<br><br>☢️ <b>金額一律由資料庫算，前端只能送「人數、時數、核定總價」這種原始輸入。</b>前端算好再送過來的話，改一下網頁原始碼就能塞任何金額進帳。畫面上那塊試算<b>只是給人看的</b>，送出後以資料庫回傳為準。<br><br>☢️ <b>登記 ≠ 認列。</b>教練可以登記，但只有<b>財務</b>（Jerec／VC）能按「最終認列」。第一篇 2 寫得很清楚：「薪資端只使用財務最終認列結果」—— 沒有這一關，任何人登記完就直接變成別人的薪水。<br><br>☢️ <b>作廢不是刪除。</b>刪掉的話對帳時會看到一個洞，而且說不出來是誰刪的。作廢一定要寫原因。<br><br>☢️ <b>時數無條件進位寫在資料庫</b>（0.5→1、1.5→2、2.2→3）。寫在前端的話，改網頁就能少報時數。<br><br>☢️ <b>參數用 jsonb 不用 20 個具名參數。</b>每加一種商品就要改簽名，而改簽名要 drop function，<b>drop 就會掉權限</b>（第 66 步的教訓）。<br><br>☢️ <b>「不是檯面方案」那一格要自己填業績金額</b>，規則是「該筆已確認實收總額 ÷ 固定堂數」（第二篇 1.4）。<b>不可以拿現在的檯面價回推舊帳</b> —— 第三篇 4 明文禁止用相近價、平均值、內插外推產生價格。',
          note:'<b>2026-08-19 完成。</b>檔案：<code>db/41-service-records.sql</code>、<code>db/42-service-rpc.sql</code>、<code>line-prototype/service.html</code>（全新）、<code>line-prototype/staff-tools.html</code>（多一顆入口）。<br><br><b>新東西</b>：<code>service_records</code>（共用結算紀錄，欄位對齊第六篇 4）、<code>service_coaches</code>（活動最多 2 位教練）、<code>add_service()</code>／<code>finalize_service()</code>／<code>void_service()</code>／<code>list_prices()</code>、<code>staff_services</code> 檢視表。<br><br><b>驗證</b>（全部在交易裡跑完 rollback，正式資料一筆都沒動）：① 七種金額逐條對規則文件 —— PT 1800、PT一對二 2200、PT外派 1800＋500＝2300、PGT外派一對四 2400＋500＝2900、<b>活動 2 位 2 小時＝客人 4,100／教練共 2,400（文件範例原文）</b>、2.2 小時進位成 3、包班 30,000 全額進抽成 ✓ ② 八種該擋的都擋了：PT 填 3 人、PGT 填 7 人、活動派 3 位、包班沒核准人、包班沒總價、未來日期、沒選教練、包班派 2 位 ✓ ③ 權限用真實身分測：Peter（教練）可以登記但<b>認列與作廢都被擋</b>；一般客人連清單都看不到 ✓ ④ 表單無頭瀏覽器實測九種操作，切類型／切人數／方案下拉跟著換／教練上限／送出鍵會講「還缺什麼」 ✓ ⑤ 做完之後 GT 帳本 204 筆、淨 708 堂、預約 132 筆，<b>跟做之前完全相同</b> ✓',
          ck:'教練後台頂欄多一顆「服務登記」。點進去選「諧動外派活動」、挑 2 位教練、時數填 2.2，畫面會顯示「計費時數（進位後）3 小時」、客人付 NT$5,900、每位教練鐘點 NT$1,800。'},

        { n:72, t:'企業包班改成費率制 ＋ 頂欄按鍵不再被切掉', where:'資料庫 ＋ 前端', done:true,
          summary:'新版規則文件把企業包班從「人工核定總價」改成「地區 × 時數」',
          body:'Jerec 2026-08-19 補上《財務與教練薪資整合規則》<b>正式補全版</b>，其中<b>企業包班整條改掉</b>：<table><tr><td></td><td><b>舊版（第 71 步照這個做的）</b></td><td><b>補全版</b></td></tr><tr><td>怎麼算</td><td>人工核定整案總價，系統不算</td><td><b>地區 × 時數，系統算</b></td></tr><tr><td>費率</td><td>沒有</td><td>大台北 <b>3,300</b>／小時、非大台北 <b>3,600</b>／小時（<b>含交通費</b>）</td></tr><tr><td>人數</td><td>「核定人數」</td><td><b>7 人（含）以上開班，人數不限</b></td></tr><tr><td>核准人</td><td>必填</td><td>不再要求</td></tr><tr><td>薪資基礎</td><td>核定整案總價</td><td>財務最終認列之<b>實際收入</b></td></tr></table><br><b>「實際收入」這四個字帶出一個新東西。</b>系統算出來的是<b>報價</b>，財務認列的才是<b>實收</b> —— 客戶議價、專案追加都會讓兩者不同。所以 <code>finalize_service()</code> 現在可以帶一個金額，而且<b>系統算的那個數字原封不動留著</b>，看得出財務改了多少。<br><br>順手修掉 Jerec 回報的兩件事：① 第 71 步在教練後台加了「服務登記」之後變成 6 顆鍵，手機上排不下；② 服務登記的<b>授課教練清單把不授課的人也列進去了</b>（林智謙、簡基城、櫃檯平板）。',
          warn:'☢️☢️ <b>頂欄的坑有兩層，第二層是我自己踩的。</b><br>第一層：<code>flex</code> 預設 <code>nowrap</code> —— 排不下的按鍵不是換行，是<b>直接被切在畫面外</b>，沒有捲軸、沒有提示。<br>第二層：我把縮短字用的 class 取名 <code>.lg</code>，而 <code>staff-tools.html</code> <b>第 301 行早就有一個 <code>.lg</code></b>（「綁不上的人」那張卡片，帶 padding 和邊框）。按鍵裡的「核銷」兩個字被套上卡片樣式，整顆鍵變兩行高、頂欄從 87px 漲到 183px。<b>CSS 撞名不會報錯</b>，只會讓版面莫名其妙壞掉 —— <b>取新 class 名之前先在檔案裡搜一次</b>。<br><br>☢️ <b>時數不進位。</b>無條件進位是<b>諧動外派活動</b>的規則（第二篇 3），企業包班沒有這一條。看到隔壁有就「順手統一」是錯的 —— 2.5 小時就是 2.5 小時。<br><br>☢️ <b>每小時費用已含交通費</b>，所以 <code>travel_fee</code> 是 0。再加一次 500 就是多收客人錢。<br><br>☢️ <b><code>create or replace view</code> 不能把新欄位插在中間。</b>這次要在 <code>headcount</code> 後面插 <code>approved_headcount</code>，跑出來的錯是「cannot change name of view column "attended_count" to "approved_headcount"」—— 看起來像改名，其實是插隊。只能 drop + create，<b>而 drop view 會把 GRANT 一起帶走</b>（第 66 步）。<br><br>☢️ <b>規則文件不能進 Git。</b>這個 repo 是公開的，而文件裡有抽成級距、鐘點費表、以及具名的固定加給（誰每月加多少）。所以放在 <code>local/</code> 並寫進 <code>.gitignore</code> —— 程式讀得到、GitHub 看不到。<br><br>☢️ <b>「授課教練」不能靠 <code>role</code> 過濾。</b>林智謙與櫃檯平板是 <code>staff</code>，濾得掉；<b>但簡基城的 <code>role</code> 是 <code>coach</code></b> —— 他是顧問／股東，職稱是教練但不實際授課（第 67 步沒把他加進教練選單也是同一個理由）。所以加了一個 <code>employees.can_teach</code> 欄位，事實只放一個地方。<br>☢️ <b>而且不能只在前端濾。</b>「前端隱藏不是安全」是這個專案的規則第 3 條 —— 改一下網頁原始碼就能把課記到別人身上，<b>那會變成他的薪水</b>。所以 <code>service_coaches</code> 上加了 trigger：不管資料從哪條路進來都會被擋。<br>☢️ <b>核准人下拉不要跟著濾。</b>核准跟授課是兩件事，顧問／股東本來就可能是核准人。<br><br>☢️ <b>企業包班費率進了 <code>products</code>，但比對頁不能把它一起比。</b>它是 B2B 報價，官網和 LIFF 都不會印 —— 一起比的話 <code>prices.js</code> 會被判「漏了兩筆」，整頁變紅，而其實什麼都沒錯。',
          note:'<b>2026-08-19 完成。</b>檔案：<code>db/43-corp-rate.sql</code>、<code>db/44-can-teach.sql</code>（都是新的）、<code>line-prototype/service.html</code>、<code>line-prototype/staff-tools.html</code>、<code>tools/check-prices.html</code>、<code>.gitignore</code>。<br><br><b>新東西</b>：<code>products</code> 多了 <code>CORP-TPE</code>／<code>CORP-OUT</code> 兩筆（<code>kind = hourly</code>）、<code>service_records.perf_final</code>（財務最終認列金額）、<code>finalize_service(uuid, text, integer)</code>。<br><br><b>驗證</b>（全部 rollback，正式資料沒動）：① 大台北 3 小時＝9,900、非大台北 2.5 小時＝9,000（<b>不進位</b>）✓ ② 六人被擋、沒選地區被擋、沒填時數被擋、沒填核准人<b>可以通過</b>（新版不再要求）✓ ③ 財務把 9,900 改成實收 9,000 —— 系統算的 9,900 <b>原封不動留著</b>，算薪水用 9,000 ✓ ④ <code>drop view</code> 之後權限確認還在 ✓ ⑤ 表單無頭瀏覽器實測：費率顯示在地區按鈕上、換地區金額跟著變、送出的內容<b>只有原始輸入</b>（地區／時數／人數），沒有金額 ✓ ⑥ 頂欄 7 種寬度 × 4 個頁面，<b>沒有任何一顆鍵被切到</b>；390px 六顆排成一列 ✓ ⑦ 比對頁在 CORP 進表之後仍然 63 項全綠 ✓ ⑧ 授課教練：把課記到簡基城／櫃檯平板身上，<b>資料庫直接擋下並說出是誰</b>；活動派 2 位其中一位不授課也擋；記到 Peter 正常通過；客人選教練的清單剩 Jerec／Jessica／Johnson／Peter／VC 五位 ✓ ⑨ 畫面實測：授課教練只剩會上課的人，<b>核准人下拉仍然列全體職員</b> ✓',
          ck:'服務登記選「企業包班」→ 按「大台北地區　NT$3,300／小時」→ 時數 3、人數 20、選一位教練，試算會顯示客人付 NT$9,900。手機開教練後台，頂欄六顆鍵（官網・點名・服務・對帳・重整・登出）全部看得到。授課教練那一排<b>只剩 5 位</b>，沒有林智謙、簡基城、櫃檯平板。'}
,

        { n:73, t:'方案（plan）—— 轉讓與逐堂認列的地基', where:'資料庫 ＋ 前端', done:true,
          summary:'帳本只有「餘額」，沒有「一張方案剩幾堂、誰擁有、每堂業績基礎多少」',
          body:'規則文件要的三件事全部指向同一個缺口：<br>· 第二篇 1.4「該筆已確認實收總額 ÷ 固定堂數」＝每堂業績基礎<br>· 第二篇 1.3　GT 每堂收入基準 333.33 元（＝4,000 ÷ 12）<br>· 第二篇 5 　 轉讓要「<b>沿用同一方案 ID</b>、承接剩餘堂數與已使用分享次數」<br><br><b>動手前先盤點（實測）</b>：<table><tr><td>購課紀錄</td><td>97 筆 —— 其中 <b>93 筆是搬遷進來的期初餘額</b>（沒有金額、沒有商品代號，堂數 1 到 44 都有）</td></tr><tr><td>真正走系統買的</td><td>只有 <b>4 筆</b>（3 × GT-12、1 × GT-1）</td></tr><tr><td>每人幾張方案</td><td>60 人 1 張、17 人 2 張、1 人 3 張</td></tr><tr><td>例外</td><td>4 人餘額是負的（最低 −2）、<b>3 人有銷課卻沒有任何購課紀錄</b></td></tr></table><br><b>設計：方案是容器，帳本仍然是唯一的餘額來源。</b><code>credit_ledger</code> 一個欄位都沒動 —— 對帳報表、購課、點名全部照舊。方案是<b>疊上去</b>的，萬一方案算錯，錢還是對的。',
          warn:'☢️ <b>那 93 張搬遷方案算不出「每堂業績基礎」。</b>規則文件第三篇 4 寫得很清楚：「資料不足時<b>維持待確認</b>並暫停自動計薪」—— <b>不是</b>拿現在的檯面價回推。所以 <code>basis_status</code> 標 <code>pending</code>，不猜。<br><br>☢️ <b>每堂基礎存 4 位小數，不存 2 位。</b>4,000 ÷ 12 ＝ 333.3333…，存成 333.33 的話 12 堂會少 0.04 元。第六篇 1：「每筆計算保留原始精度…<b>不得逐筆取整</b>」—— 取整是月結小計才做的事。<br><br>☢️ <b>一筆扣款可能跨兩張方案</b>（舊方案剩 1 堂、這次要扣 2 堂）。所以配堂數是獨立一張表，不是在帳本上加一個 <code>plan_id</code> —— 硬塞一個欄位就得把帳本那一列拆成兩列，而拆列會動到已經在跑的對帳報表。<br><br>☢️ <b>做成 trigger，不改 <code>check_in()</code>。</b>check_in 是每天在跑、動到錢的函式，能不碰就不碰；而且 trigger 守的是<b>整張表</b>，購課／點名／沖銷／以後的匯入都會配到方案。<br><br>☢️☢️ <b>回填要分兩趟跑，這是實際踩到的。</b>第一版只跑一趟（照時間順序），結果被搬遷資料的時間戳記騙了 —— 有人的期初餘額 8/17 才登進系統，但他 8/03 就上過課。一趟跑的話，處理 8/03 那筆時方案還不存在，就補開一張「沒有購課紀錄」的空方案（−2），8/17 再開一張正常的（+11）。<b>加起來剛好是對的，所以對帳檢查抓不到</b>，但畫面上看就是壞的。改成「先建所有方案，再配銷課」之後，系統補開的方案從 5 張降回 3 張 —— 正好就是那 3 位真的沒有購課紀錄的人。<br><br>☢️ <b>回填完就地對帳，對不上整批回捲。</b>寧可不上線，也不要上線之後才發現堂數對不起來。',
          note:'<b>2026-08-19 完成。</b>檔案：<code>db/45-plans.sql</code>（新）、<code>line-prototype/report.html</code>。<br><br><b>新東西</b>：<code>plans</code>（方案）、<code>plan_draws</code>（哪一筆帳本從哪張方案扣了幾堂）、<code>plan_state</code>（剩幾堂）、<code>plan_allocate()</code>、<code>credit_ledger</code> 的 after-insert trigger、<code>staff_plan_check</code>（對帳檢視表）。<br><br><b>驗證</b>：① 回填後 <b>100 張方案、107 筆配堂</b>，方案剩餘總和 <b>708</b> ＝ 帳本餘額總和 <b>708</b>；81 人逐人對帳<b>全部相等</b>，沒有一筆帳本列沒配到 ✓ ② 系統補開的方案剛好 3 張，就是那 3 位有銷課、沒購課的人 ✓ ③ 剩餘為負的方案 4 張，對上原本餘額為負的 4 個人 ✓ ④ trigger 實測：買一組 GT-12 → 自動開方案、<b>每堂基礎 333.3333、狀態 ok</b> ✓ ⑤ <b>跨方案實測</b>：最舊那張剩 1 堂、故意扣 2 堂 → 配成「08/01 那張扣 1 ＋ 08/13 那張扣 1」✓ ⑥ <b>退回實測</b>：同一筆預約補一筆正的 → 堂數<b>回到當初扣的那張方案</b>，不是隨便找一張 ✓ ⑦ 每一步都重新全體對帳，<b>0 個人對不上</b>；全部在交易裡跑完 rollback ✓',
          ck:'開對帳報表，最下面多一塊「🧾 方案對帳」，綠色寫著「81 人全部對得上」。下面那行會說有幾張方案算不出每堂業績基礎 —— 那是搬遷進來的舊帳，正常。'}
,

        { n:74, t:'課程轉讓 —— 方案換人，一堂都不會憑空多出來', where:'資料庫 ＋ 前端', done:true,
          summary:'堂數只是換了主人，所以它不該產生任何「用掉」的紀錄',
          body:'規則文件（正式補全版）第二篇 5 把轉讓寫得很細：<table><tr><td>可轉讓</td><td>PT 預付、GT 預付；須有剩餘堂數。<b>PGT 不可轉讓</b></td></tr><tr><td>同類</td><td>PT 不得轉 GT，GT 亦不得轉 PT</td></tr><tr><td>識別</td><td><b>沿用同一方案 ID</b>，不得建立新銷售方案</td></tr><tr><td>金額</td><td><b>0 元</b>，不產生新收入或新業績</td></tr><tr><td>轉出／轉入</td><td>各記一筆，銷課方式標示「轉出」「轉入」</td></tr><tr><td>紀錄</td><td>原擁有人、新擁有人、日期、核准人、原方案</td></tr></table><br><b>做法出乎意料地簡單，因為第 73 步的地基是對的。</b>轉讓<b>不動用任何一堂</b> —— 所以它不產生任何配堂紀錄，只有兩筆帳本 ＋ 方案換擁有人。對帳算式自己就會對：<br>原主人 帳本 −N、方案不再屬於他 → 兩邊各少 N；<br>新主人 帳本 +N、方案變成他的 → 兩邊各多 N。<br><br>實測轉了 44 堂：原主人帳本 44 → 0，新主人 3 → 47，<b>全系統總堂數還是 708</b>，81 人逐人對帳 0 個對不上。',
          warn:'☢️☢️ <b>配堂數那支函式一定要放過轉讓。</b>不加這一段的話：轉出那筆（負的）會被當成「上課」去先進先出扣方案，轉入那筆（正的）會被當成「退課」去找最新的方案退 —— <b>兩邊都扣錯方案</b>，而且總數還是對的，所以對帳檢查抓不到。<br><br>☢️☢️ <b>分享額度會被算兩次。</b>額度是「每拿到 12 堂給 2 次」，而轉入也是正的堂數 —— 不排除的話，同一批堂數會在原主人和新主人身上<b>各算一次額度</b>。所以 <code>gt_share_quota</code> 加了 <code>reason &lt;&gt; \'transfer_in\'</code>。<br>☢️ <b>已知的簡化</b>：規則文件說轉讓要「承接 GT 已使用分享次數」。現在的做法是<b>新主人拿不到這批堂數的分享額度</b>（比較嚴），而不是「承接已用幾次、再給剩下的」。轉讓當下的已用次數有記在 <code>plan_transfers</code> 裡，<b>資料沒有流失</b>，等真的有人要用再做完整的承接。<br><br>☢️ <b>只有財務能按。</b>一張 12 堂的方案換人＝把 NT$4,000 的權益移過去，那不該是任何一位教練按一下就能做的事。前端只是把區塊藏起來（實測非財務身分看不到），<b>真正的牆在資料庫</b> —— Peter 直接呼叫也會被擋。<br><br>☢️ <b>畫面只列真的能轉的方案。</b>單堂、已用完、PGT 全部先濾掉 —— 列出來卻按不下去，比不列出來更討厭。',
          note:'<b>2026-08-19 完成。</b>檔案：<code>db/46-transfer.sql</code>（新）、<code>line-prototype/staff-tools.html</code>。<br><br><b>新東西</b>：<code>credit_ledger</code> 多兩種理由（<code>transfer_out</code>／<code>transfer_in</code>）、<code>plan_transfers</code>（轉讓紀錄）、<code>transfer_plan()</code>、<code>staff_plans</code> 檢視表、後台的「課程轉讓」摺疊區。<br><br><b>驗證</b>（全部 rollback）：① 轉 44 堂：帳本 44→0 與 3→47，<b>方案 ID 沒變、擁有人換了、原始擁有人留著</b>，全系統 708 堂不變，81 人對帳 0 不合 ✓ ② 分享額度：新主人收到 44 堂之後<b>額度仍然是 0</b>（沒有被重複給） ✓ ③ 該擋的都擋了：單堂方案、沒有剩餘堂數、不存在的方案、不存在的接收人、轉給同一個人 ✓ ④ Peter（教練）呼叫 → <b>被擋「只有財務可以做課程轉讓」</b> ✓ ⑤ 轉出去再轉回來，兩次都成功 ✓ ⑥ 畫面實測六步：財務才看得到區塊、搜尋轉出人、<b>3 張方案只列出 1 張</b>（單堂與 PGT 被濾掉）、選方案後才出現「轉給誰」、按鈕文字會說還缺什麼、送出的內容只有方案與接收人 ✓ ⑦ 非財務身分實測<b>看不到這個區塊</b> ✓',
          ck:'教練後台（用你或 VC 的身分）會多一個「課程轉讓」摺疊區。展開 → 搜一個有剩餘堂數的人 → 他的方案會列出來 → 選一張 → 搜接收人 → 按鈕變成「確認轉讓 N 堂」。轉完到對帳報表看「方案對帳」，應該還是全部對得上。'}
,

        { n:75, t:'期初結轉被記兩次 —— 8 位客人多出 66 堂', where:'資料庫', done:true,
          summary:'第二批搬遷本來是要「更正」第一批的數字，卻被當成「再加一次」',
          body:'Jerec 發現某位客人餘課顯示 11 堂、實際不該是 11。查下去發現不是單一個案：<table><tr><td>第一批</td><td><code>note=\'原團課堂數\'</code>，08/02～08/07，來源是<b>舊 ERP</b>（FusionForceErp 的 PassLedger）</td></tr><tr><td>第二批</td><td><code>note=\'舊表期初結轉\'</code>，08/18，來源是<b>舊表</b>（團課流水帳 Excel）</td></tr></table>第二批是「孤兒名單」的後續 —— 那份名單裡有 12 位「要建檔」和 4 位「同一人」，合計 16 人 139 堂。<b>其中 8 位在第一批就已經進來了</b>，於是同一筆期初被加了兩次，全店憑空多出 <b>66 堂</b>。<br><br><b>怎麼判斷哪一個數字才對</b>：拿 2026 年 5～7 月的手寫團課流水帳重算。那三張表的「已上堂數」欄位是「累計已上／累計已購」，兩個數字相減就是當下的剩餘。六位能對得上名字的客人算出來是 10／9／7／8／3／1 —— <b>六個全部命中舊表那一欄，舊 ERP 那一欄一個都沒中</b>。所以以舊表為準，沖掉舊 ERP 那一筆。',
          warn:'☢️ <b>兩個數字加起來剛好等於一個看起來合理的餘額，所以對帳檢查抓不到。</b>第 73 步的方案對帳是「方案剩餘總和 ＝ 帳本餘額總和」—— 重複的期初<b>兩邊都多算</b>，等式照樣成立。第 74 步轉讓實測時全系統 708 堂「不變」，那個 708 本身就已經多了 66。<b>能發現是因為 Jerec 認得客人</b>，不是因為系統報錯。<br><br>☢️ <b>不能刪，要沖。</b><code>credit_ledger</code> 是 append-only，所以是加一筆負數 <code>adjust</code>。刪掉的話，三個月後沒有人知道這 66 堂去了哪裡。<br><br>☢️☢️ <b><code>gt_share_quota</code> 原本只算 <code>delta &gt; 0</code>，堂數退了、分享次數不會退。</b>某位客人 66 堂 → 可分享 10 次，沖回 33 堂之後<b>還是 10 次</b>。改成「正數一律算，<code>adjust</code> 不管正負都算」—— adjust 本來就是用來更正購課紀錄的。<br><br>☢️ <b>SQL 檔裡不能寫死客人是誰。</b>這個 repo 是公開的。所以判斷條件寫成「同時有這兩種 note 的人」，一個姓名、一個手機號碼都沒進版控，而且以後同樣的情況再發生也能直接重跑。<br><br>☢️ <b>沖銷前先驗人數和堂數，不對就整批停下。</b>migration 開頭是一段 <code>raise exception</code>：不是剛好 8 人 66 堂就不准跑。',
          note:'<b>2026-08-19 完成。</b>檔案：<code>db/47-fix-dup-opening.sql</code>（新）。<br><br><b>修正後的 8 筆餘額</b>：33 / 10 / 8 / 8 / 7 / 5 / 5 / 2。<br><br><b>驗證</b>：① 全系統 GT 總堂數 <b>708 → 642</b>，剛好少 66 ✓ ② 方案剩餘總和 <b>642 ＝ 帳本餘額總和 642</b> ✓ ③ <b>沒有一筆帳本列沒配到方案</b>（0 筆）✓ ④ 剩餘為負的方案仍然是<b>原本那 4 張</b>，沒有因為沖銷多出新的 ✓ ⑤ 分享次數跟著退（10 → 4，其餘歸 0）✓ ⑥ 順手全面體檢：<b>沒有重複手機、沒有同名重複帳號</b>，其餘 64 人都只有一筆期初 ✓<br><br>☢️☢️ <b>這一步沖錯邊了，隔天被第 76 步推翻。</b>沖掉的應該是舊表那一筆，不是舊 ERP 那一筆。留著不刪，因為犯錯的方式比修好的結果更值得記住 —— 見第 76 步。',
          ck:'（已被第 76 步取代）'}
,

        { n:76, t:'誰說了算 —— 舊系統凍結當下的餘額才是真相', where:'資料庫', done:true,
          summary:'第 75 步用「哪一份比較完整」下判斷，但完整不等於正確',
          body:'第 75 步之後 Jerec 說：「人工查帳 8/5 她上完剩 2 堂，跟修正完的 8 堂還是不符。」<br><br>然後他給了關鍵的一份東西 —— <b>舊系統凍結當下的完整帳目表</b>（<code>FusionForceErp.xlsx</code>，<code>PassLedger</code> 最後一列是 2026-08-16 12:10）。那位客人的帳長這樣：<table><tr><td>08/01</td><td>期初 <b>+3</b></td><td>餘 3</td></tr><tr><td>08/05</td><td>間歇有氧 <b>−1</b></td><td>餘 <b>2</b></td></tr></table>跟人工查帳一模一樣。<b>舊表那筆 10 是舊系統上線<i>之前</i>的手寫本子</b> —— 舊系統早就把它接手了，兩份相加等於把同一批堂數認兩次。<br><br><b>正確的規則不是「哪一份比較完整」，是「哪一份還在跑」</b>：<table><tr><td>舊系統裡有帳</td><td><b>舊系統凍結當下的餘額</b>。每一筆點名都真的寫進去了</td></tr><tr><td>舊系統裡沒有帳（孤兒）</td><td>才輪到手寫流水帳</td></tr></table>那 8 位<b>兩邊都有帳</b>，所以 08/18 整批都是多的。做法：把第 75 步沖掉的期初加回來（+66），再沖掉 08/18 那一批（−84），淨 <b>−18</b>。',
          warn:'☢️☢️ <b>對帳查詢會自己證明自己對。</b>第一版把「切換後的異動」定義成「時間戳晚於切換點的帳本列」—— 而 08/18 那批搬遷資料的時間戳<b>正好晚於切換點</b>。於是它被算進「切換後的營業異動」，<code>應該是</code> 跟著一起長，<b>差額永遠是 0</b>。72 人跑出來只有 2 個不符，看起來漂亮得不得了，錯誤剛好被自己藏起來。<b>對帳的分母裡混進了要被檢查的東西，就不是對帳了。</b><br><br>☢️ <b><code>&gt;=</code> 和 <code>&gt;</code> 差一個人。</b>舊系統最後一筆點名的時間戳<b>就是</b>切換點。用 <code>&gt;=</code> 會把它算成「切換後」再扣一次，憑空生出一個 1 堂的假差異，害人去查一個根本沒問題的客人。<br><br>☢️ <b>「完整」是錯的判準。</b>第 75 步的推理是：流水帳六個人的數字都命中舊表那一欄，舊 ERP 一個都沒中 —— 這是真的，因為<b>舊表和流水帳本來就是同一本帳</b>。互相印證的兩份資料只會證明它們是同一份，不會證明它是對的。<b>真正該問的是「客人最後一次上課之後，哪個系統記了那一筆」。</b><br><br>☢️ <b>還好帳本是 append-only。</b>第 75 步如果是 <code>delete</code>，這一步就沒有東西可以加回來了。整條線現在攤開來看得見：<code>+3 → −1 → +10 → −1 → −3 → +3 → −10</code>。',
          note:'<b>2026-08-19 完成。</b>檔案：<code>db/48-erp-final-truth.sql</code>（新）、<code>tools/recon-erp.md</code>（新，對帳的做法與四個坑）。<br><br><b>最終的 8 筆餘額</b>：廖庭均 33、Adele 8、Yiting 8、小虎 5、鄭旭媚 3、張小筠 1、Vickie wang 1、林屏妏 1。<br><br><b>驗證</b>：① <b>72 位舊系統客人逐人對帳，71 位完全相符</b>（舊系統最後餘額 ＋ 切換後真正的營業異動 ＝ 現在）✓ ② 唯一跳出來的 <code>0972925321</code> 是舊系統的測試帳號 ——<b>備註寫「屁股1」、<code>Members</code> 裡根本沒有這個人</b>、兩筆 40 堂 topup、兩筆 −20 手動扣、兩筆 −5 重複點名，本來就不該搬 ✓ ③ 全系統 GT 總堂數 <b>642 → 624</b>（−18）✓ ④ 方案剩餘總和 <b>624 ＝ 帳本餘額總和 624</b>，未歸屬分錄 0 ✓ ⑤ 負餘額仍然是原本那 4 位，沒有多出新的 ✓ ⑥ 分享次數重算正確 ✓',
          ck:'教練後台搜 Vickie wang，餘課會是 <b>1 堂</b>（舊系統 8/5 上完剩 2，8/19 新系統又上了一堂）。對帳報表的「方案對帳」還是綠色全部對得上。'}
,

        { n:77, t:'對帳抓不到的那一種錯 —— 基準本身就抄錯了', where:'資料庫', done:true,
          summary:'拿舊系統當真相，就沒有任何查詢能發現舊系統抄錯了',
          body:'第 76 步之後 Jerec 逐一回頭核對，抓到一位（末三碼 <b>112</b>）。她的三份資料是三個數字：<table><tr><td>舊 ERP 期初（08/01）</td><td><b>1</b> 堂 —— 08/16 凍結前她完全沒有異動，只有一筆取消的預約</td></tr><tr><td>手寫流水帳（07/04 最後一列 9/12）</td><td>3 堂</td></tr><tr><td>Jerec 人工核對「最新紀錄」</td><td><b>2</b> 堂 ← 採用</td></tr></table><b>舊系統的「期初」本身也只是 08/01 從舊表抄過去的一個數字。</b>抄錯的話，以舊系統為基準的對帳<b>不可能</b>抓到 —— 基準就是錯的那個。71/72 全部相符，看起來很漂亮，因為那 71 個人的期初剛好抄對了。<br><br>同時確認了另外兩件事：<ul><li><b>末三碼 157</b>（每次都現場買單堂、當場銷掉）：08/10 買 1 上 1、08/18 上 1 買 1 → <b>餘 0，本來就是對的</b>，不用動</li><li><b>4 位負餘額</b>：Jerec 說「應該只是還沒購課，這點常常發生，因為我們並沒有強制沒課堂數就不能上課，與客人關係是建立在信任下」—— <b>這不是 bug，是營運方式</b>。系統不擋負數，維持現狀</li></ul>',
          warn:'☢️☢️ <b>「71/72 相符」不代表 71 個人都是對的，只代表有 71 個人跟基準一致。</b>基準抄錯的那幾個會一起「一致」。這種錯只有<b>認得客人的人</b>能抓 —— 系統永遠抓不到。所以搬遷之後的頭幾個月，人工抽查不是多餘的儀式。<br><br>☢️ <b>負餘額不要「修」。</b>看到 −2、−1 很容易當成資料損壞去補平，但這裡是老闆刻意的營運政策（信任制、先上課後補課）。<b>修掉等於把真實的欠款抹掉。</b>動任何看起來像壞資料的東西之前，先問那是不是有人故意的。<br><br>☢️ <b>這一步沒有通則可寫，所以用 <code>customer_id</code> 直接指名。</b>這個 repo 是公開的 —— UUID 沒有 DB 就什麼都不是，手機號碼和姓名不行。migration 開頭有一段「目前必須剛好是 1 堂」的檢查，跑錯時機會自己停下。',
          note:'<b>2026-08-20 完成。</b>檔案：<code>db/49-manual-check-112.sql</code>（新）。<br><br><b>驗證</b>：① 該客人餘課 <b>1 → 2</b> ✓ ② 全系統 GT 總堂數 <b>624 → 625</b> ✓ ③ 方案剩餘總和 <b>625 ＝ 帳本餘額總和 625</b>，未歸屬分錄 0 ✓ ④ 負餘額仍然是那 4 位，沒有多也沒有少 ✓',
          ck:'教練後台搜末三碼 112 那位，餘課 <b>2 堂</b>。對帳報表的「方案對帳」還是綠色全部對得上。'}
,

        { n:78, t:'薪資計算 —— 四條線各自算清楚，最後才加起來', where:'資料庫', done:true,
          summary:'規則文件最禁止的事，就是把不同薪資類型混在一起算',
          body:'規則文件第六篇 1：<br><b>教練當月薪資 ＝ PT＋PGT 累計業績抽成（含外派及企業包班）＋ GT 鐘點費 ＋ 諧動外派活動鐘點費 ＋ 固定加給</b><br><br>四條線的規則完全不同：<table><tr><td>抽成業績</td><td>80,000 以內看職級（主管 45%／一般 40%），<b>超過的部分一律 50%</b>；同一筆跨過門檻要分段</td></tr><tr><td>GT 鐘點費</td><td>只看每堂<b>實際到場並完成簽到</b>的人數查表 15；不分職級</td></tr><tr><td>諧動外派活動</td><td>每位教練 計費時數 × 600；不列入抽成</td></tr><tr><td>固定加給</td><td>月中到職按<b>日曆天數</b>比例；不影響抽成級距</td></tr></table><br><b>新東西</b>：<code>coach_grades</code>（職級異動史）、<code>coach_allowances</code>（職務加給）、<code>coach_grade_on()</code>、<code>payroll_lines()</code>（每一筆明細）、<code>payroll_month()</code>（月結 ＋ 待處理 ＋ 提醒）。',
          warn:'☢️ <b>職級存的是異動史，不是一個欄位。</b>規則說「職級於月中生效或停止時，以生效日前後的實際業績分段套用相應比例」—— 一個 <code>is_supervisor</code> 布林值做不到這件事，而且改了之後<b>連上個月已經結完的薪資都會跟著變</b>。所以存「從哪一天開始」，逐筆用完成日去查。<br><br>☢️ <b>查不到職級＝一般教練，這是規則不是預設值。</b>規則第五篇 2：「未正式核定為主管者，適用一般教練比例。」所以空的資料表是正確狀態，不是待補。<br><br>☢️☢️ <b>取整只能發生一次，而且是在月結小計。</b>規則第六篇 1：「每筆計算保留原始精度…<b>不得逐筆取整</b>。」所以 <code>payroll_lines</code> 回傳 numeric，<code>payroll_month</code> 才 round —— 而且是四類<b>各自</b>四捨五入再相加，不是加總後才 round。<br><br>☢️ <b>算不出來的東西要「停下來」，不能算成 0。</b>沒指定教練的課、到場 13 人以上（規則明講不得套 12 人封頂）、還沒財務最終認列的服務 —— 全部進 <code>holds</code>，不進小計。<b>靜靜算成 0 的話錢會直接消失，而且沒有任何地方會報錯。</b>第 79 步就是這個設計擋下來的。<br><br>☢️ <b>「沒扣堂數」不等於「沒來上課」。</b>規則第五篇 3：體驗、免費、贈課、補課只要實際到場就要列入人數 —— 那些正好都沒扣堂數。所以這種情況進 <code>warns</code> 給人看，<b>不擋</b>。<br><br>☢️ <b>加給金額與職級名單不寫進 SQL 檔。</b>這個 repo 是公開的，而具名的薪資數字是最不該進版控的東西。migration 只建表，值由財務在後台輸入。<br><br>☢️ <code>with pl as <b>materialized</b></code> —— 不寫 materialized 的話 PG 會把它展開成三次，同一份資料算三遍。',
          note:'<b>2026-08-19 完成。</b>檔案：<code>db/50-payroll.sql</code>（新）。<br><br><b>2026 年 8 月試算（月份還沒結束）</b>：<table><tr><td>Jerec</td><td>GT 1,200 ＋ 加給 20,000</td><td><b>21,200</b></td></tr><tr><td>VC</td><td>GT 5,200 ＋ 加給 5,000</td><td><b>10,200</b></td></tr><tr><td>Johnson</td><td>GT 5,300</td><td><b>5,300</b></td></tr><tr><td>Peter</td><td>GT 3,700</td><td><b>3,700</b></td></tr><tr><td>Jessica</td><td>GT 1,000</td><td><b>1,000</b></td></tr><tr><td colspan=2>合計</td><td><b>41,400</b></td></tr></table><br><b>驗證</b>：① <b>把規則文件表 15 原封不動寫成對照表獨立重算</b>，五位教練的 GT 鐘點費跟 <code>gt_payout()</code> 算的<b>一模一樣，差 0</b> ✓ ② 加給比例實測：月加給 3,100、8/16～8/31 在任 16 天 → <b>1,600.0000</b>（3,100 × 16/31，起訖日都算）✓ ③ 全月在任的兩筆是<b>剛好</b> 20,000 與 5,000，沒有因為比例計算跑出小數 ✓ ④ 待處理 0、提醒 0 ✓ ⑤ 非財務身分呼叫 → <b>被擋</b> ✓<br><br><b>還沒有資料的部分</b>：<code>service_records</code> 目前 0 筆（服務登記頁剛上線），所以抽成與活動鐘點費這兩條線是 0。累進分段的邏輯寫好了，等第一筆 PT 進來就會動。',
          ck:'還沒有畫面 —— 這一步只做資料庫。要看數字的話，在 Supabase SQL Editor 跑 <code>select jsonb_pretty(public.payroll_month(\'2026-08-01\'));</code>'}
,

        { n:79, t:'算薪資才浮出來的兩個搬遷錯誤', where:'資料庫', done:true,
          summary:'餘額對得起來，不代表「這堂課有幾個人」也對得起來',
          body:'第 78 步的薪資一跑，兩件事當場掉出來。<br><br><b>① 9 堂課有錢要付，卻沒有人可以付。</b>八月初那批搬遷只搬了「課次 ＋ 誰上了課」，<b>沒有搬「這堂課是誰帶的」</b>。31 人次、4,800 元掛在「（未指定教練）」名下。舊系統匯出檔的 <code>LessonInstances</code> 每一列都有 <code>coachName</code>，用「日期 ＋ 開始時間」對回來就補齊了。<br><br><b>② 7 筆「退掉的預約」被記成「有來上課」。</b>跟舊系統凍結當下的簽到人數逐堂對，7 堂對不起來。這 7 筆在舊系統是 <code>refundedCount=1</code>（客人退掉、堂數退回去、沒扣課），搬進來卻變成 <code>attended</code>。<b>自己的資料就能證明</b>：它們是全系統僅有的「<code>attended</code> 但帳本上一列都沒有」的預約。<br>影響：VC −900、Jerec −200、Peter −100，八月鐘點費合計少 <b>1,200 元</b>。',
          warn:'☢️☢️ <b>餘額對帳永遠抓不到這兩個錯。</b>第 73 步的「方案剩餘 ＝ 帳本餘額」、第 76 步的「舊系統餘額 ＋ 切換後異動 ＝ 現在」—— 兩個都<b>只看堂數</b>。而這兩個錯一個在「教練是誰」、一個在「有幾個人到場」，<b>兩欄都不影響任何人的堂數</b>。上線後第一次算薪資才浮出來。<br><b>對帳對得起來，不代表資料是對的 —— 只代表你檢查的那一欄是對的。</b><br><br>☢️ <b>能發現①，是因為第 78 步選擇「停下來」而不是「算成 0」。</b>沒指定教練的課如果靜靜算成 0，這 4,800 元會直接消失，而且沒有任何畫面會顯示異常。<b>擋下來的不是查詢，是設計。</b><br><br>☢️ <b>「沒扣堂數」不能拿來當通則去改資料。</b>規則第五篇 3 說體驗、免費、贈課、補課只要實際到場就要算人頭 —— 那些也是沒扣堂數的。所以第 ② 件<b>只</b>動切換前的搬遷資料，而且逐筆對過舊系統匯出檔；之後同樣情況改由報表列出來給人判斷。<br><br>☢️ <b>補教練只補到 8/16。</b>舊系統的課表排到 8/31，但 8/16 之後的課次是在新系統建立的，教練可能已經換人 —— 拿舊課表去蓋<b>會蓋錯，而且不會報錯</b>。<br><br>☢️ <b>對照時 <code>&gt;=</code> 和 <code>&gt;</code> 又差一次。</b>舊系統最後一筆點名的時間戳就是切換點；邊界寫錯會多冒出一個假的差異。',
          note:'<b>2026-08-19 完成。</b>檔案：<code>db/51-backfill-coach.sql</code>（新）、<code>db/52-refunded-not-attended.sql</code>（新）。<br><br><b>驗證</b>：① 補教練後，<b>「有人到場但沒有教練」的課次 0 堂</b>，126 堂 GT 全部有教練 ✓ ② 7 筆改成 <code>cancelled</code> 之後，「<code>attended</code> 但帳本沒有列」的預約剩 <b>0 筆</b> ✓ ③ 拿舊系統匯出檔<b>逐堂</b>比對切換前的簽到人數，八月<b>全部相符</b> ✓ ④ 七月剩兩堂、八月剩一堂對不起來，三堂都是<b>舊系統裡的測試帳號「屁股1」與職員測試列</b>造成的，本來就不該搬 ✓ ⑤ 修完重跑薪資：VC 6,100→5,200、Jerec 1,400→1,200、Peter 3,800→3,700，<b>剛好就是預估的 −1,200</b> ✓ ⑥ 客人堂數餘額<b>一堂都沒動</b>（這 7 筆本來就沒扣過課）✓',
          ck:'重跑 <code>payroll_month(\'2026-08-01\')</code>，「待處理」與「提醒」都應該是空的，而且不會再有「（未指定教練）」那一列。'}
,

        { n:80, t:'薪資報表畫面 —— 算不出來的東西要看得見', where:'前端', done:true,
          summary:'第 78 步的數字只有 SQL Editor 看得到，而算薪水的人不會開 SQL Editor',
          body:'新頁面 <code>payroll.html</code>，跟對帳報表同一套外殼與身分流程。<br><br><b>畫面由上而下</b>：<table><tr><td>月份</td><td>這個月／上個月，或直接挑</td></tr><tr><td>四類小計</td><td>抽成、GT 鐘點、活動鐘點、加給，各一格 ＋ 全店合計</td></tr><tr><td>每位教練</td><td>合計一行；<b>點名字展開逐筆明細</b></td></tr><tr><td>暫停自動計薪</td><td>紅色；<b>沒有</b>算進任何人的合計</td></tr><tr><td>要看一眼</td><td>橘色；<b>已經</b>算進合計了</td></tr><tr><td>下載</td><td>Excel 4 個工作表</td></tr></table><br><b>紅色與橘色的差別是刻意的</b>：紅色＝系統不敢算，錢還沒發；橘色＝系統算了，但你最好確認一下。兩種混在一起，人就會兩種都不看。',
          warn:'☢️ <b>這一頁用月份，不用日期區間。</b>對帳報表是「今天／昨天／這 7 天」，薪資<b>不能</b>照抄 —— 80,000 元的抽成門檻是<b>當月累計</b>，抓半個月來看門檻會算錯，<b>而且錯得很合理，不會有任何地方報錯</b>。所以這裡連日期輸入框都沒有。<br><br>☢️ <b>月份也要用台北時間算。</b><code>toISOString()</code> 給 UTC —— 每個月 1 號凌晨 0 點到 8 點之間它會回上個月，而那正好是「月初來算上個月薪水」最可能發生的時段。（規則 16 第 N 次）<br><br>☢️ <b>明細顯示原始精度，小計顯示取整後。</b>兩個數字對不起來是<b>正常的</b>，畫面上要寫清楚為什麼 —— 不寫的話第一個發現的人會以為是 bug。<br><br>☢️ <b>加了「薪資」按鈕之後，兩頁的上方列都要重測。</b><code>report.html</code> 的 <code>.top</code> 是 <code>display:flex</code> <b>沒有 wrap</b> —— 塞不下就直接切掉，沒有捲軸也沒有提示（第 62 步踩過）。實測 320／360／390／430px 四種寬度，兩頁的按鈕全部看得到。<br><br>☢️ <b>非財務身分要「完全不呼叫」，不是「呼叫了再擋」。</b>實測 <code>can_finance=false</code> 時 <code>payroll_month</code> 被呼叫 <b>0 次</b>。就算前端漏擋，資料庫也會丟例外 —— 兩層都在。',
          note:'<b>2026-08-20 完成。</b>檔案：<code>line-prototype/payroll.html</code>（新）、<code>staff-tools.html</code>、<code>report.html</code>（各加一顆「薪資」鍵，只有財務看得到）。<br><br><b>驗證</b>（Playwright，兩種資料 × 六種寬度）：① <b>乾淨資料</b>與<b>有暫停／提醒／跨門檻抽成</b>兩種情境，320／360／390／430／768／1280px 全部：JS 錯誤 0、橫向溢出 0px、上方按鈕沒有一顆被切掉 ✓ ② 展開 VC：<b>三種類別都在</b>（抽成／GT／加給），抽成顯示 45% 與 NT$41,000、加給顯示 31 天、GT 顯示 8 人 ✓ ③ 再點一次收起來、兩位可以同時展開 ✓ ④ 「（未指定教練）」合計 <b>NT$0</b>，那一筆金額欄寫「<b>暫停</b>」不是 0 ✓ ⑤ 非財務身分：被擋在門口、訊息看得懂、<b>payroll_month 呼叫 0 次</b> ✓ ⑥ <code>report.html</code> 與 <code>staff-tools.html</code> 把所有權限鍵都打開（7 顆）測最擠的情況，320px 也<b>一顆都沒被切掉</b> ✓',
          ck:'教練後台（用你或 VC 的身分）右上角會多一顆「薪資」。點進去預設是這個月，最上面四格是四類小計，綠色那格是全店合計。點教練名字會展開他的逐筆明細。<b>非財務的教練看不到那顆鍵</b>，直接打網址進去會被擋。'}
,

        { n:81, t:'停課只通知那堂課的人 —— 並且先架好那座橋', where:'資料庫 ＋ 前端 ＋ Edge Function', done:true,
          summary:'204 則換 6 則，但中間隔著兩組不互通的 LINE 編號',
          body:'2026-08-16 查到的數字：LINE 中用量每月 <b>3,000 則</b>，群發<b>按好友人數計費</b> —— 一次「⚠️團課異動⚠️」就是 <b>204 則</b>。8/01～8/16 已用掉 2,217 則（74%），照那個節奏 8/22 前後見底，而中用量<b>不能加購</b>。<br><br><b>做了三件事</b>：<table><tr><td>後台停課</td><td>點名頁多一顆「停課／請假」。以前要開 Supabase 表格編輯器改 status</td></tr><tr><td>誰要通知</td><td>當場列出<b>推得到的</b>和<b>推不到的</b>兩份名單</td></tr><tr><td>那座橋</td><td>客人按一顆按鈕，把兩組 LINE 編號對起來</td></tr></table>',
          warn:'☢️☢️ <b>customers.line_user_id 不能拿來推播。</b>它來自 LINE Login channel（2011063116），推播要的是官方帳號 Messaging API channel（2009245280）的編號 —— 兩個 channel 在<b>不同的 Provider</b>，而 LINE 的 userId 是以 provider 為單位發的。2026-08-19 用 Jerec 本人證實過：同一個人兩組完全不同的號碼。channel 不能換 provider（官方文件寫死），<b>所以這件事沒有捷徑</b>：只能請客人主動傳一則帶短碼的訊息過來。<br><br>☢️ <b>橋剛架好那天，推得到的人是 0。</b>這不是 bug，是這個設計的起點。所以每一次通知都<b>一定</b>會回傳「推不到的名單」給櫃檯 —— 那些人不會靜靜消失，他們是會站在門口等的人。<br><br>☢️☢️ <b>line-hook 這次一定要驗 X-Line-Signature。</b>它會寫 <code>customers.push_user_id</code> —— 不驗簽的話任何人都能 POST 一則假的「userId ＋ 短碼」把自己綁到別人身上。（8/19 的舊版沒驗，因為那時它只寫一張對照表、還要配上六句講好的暗號。<b>動客人資料的標準不一樣。</b>）<br><br>☢️ <b>回覆訊息（reply）不計費，推播才計費。</b>確認訊息一律走 reply —— 那是整套裡唯一免費的一則。<br><br>☢️ <b>webhook 一律回 200</b>，連驗簽失敗也是。回 401 等於告訴對方「這個網址真的是 webhook」；而 LINE 收到非 200 會重送，連續失敗<b>會自動把 webhook 關掉</b> —— 橋就在沒人發現的情況下斷了。<br><br>☢️ <b>收件人由 Edge Function 自己去資料庫查，不接受前端傳。</b>接受的話，這支就變成「叫我發給誰就發給誰」的工具。<br><br>☢️ <b>已經有人點過名的課不能取消。</b>那不是停課，那是上完了 —— 取消它會讓已經扣掉的堂數變成沒有對應的課，對帳當場壞掉。擋在資料庫，前端只是不要讓人白按。<br><br>☢️ <b>取消之後 CUR 還是舊的那個物件。</b>重讀課表之後要把它換掉，否則 <code>session_status</code> 仍寫著 pending、紅色橫幅不會出現 —— 看起來像「按了沒反應」，其實課已經取消了。<br><br>☢️ <b>LIFF 視窗裡 window.open 會被擋掉，而且不報錯。</b>跳去官方帳號聊天室一定要用 <code>location.href</code>。<br><br>☢️☢️ <b>PostgREST 遇到兩條外鍵會整個查詢回錯。</b><code>bookings</code> 有兩條指向 <code>customers</code>：<code>customer_id</code>（誰上課）和 <code>paid_by_customer_id</code>（誰的堂數付的）。只寫 <code>customers!inner(...)</code> 的話它不知道要走哪一條 —— <b>而我只接了 data 沒接 error</b>，於是收件人變成空陣列，畫面上顯示「這堂課沒有人要通知」。<b>那一則該發的通知會安靜地不見，而且沒有任何地方會亮紅燈。</b>實測時是靠資料庫裡 <code>n_target = 0</code> 抓到的 —— 畫面本身看起來完全正常。<br>☢️ 教訓：<b>嵌套查詢一定要指名外鍵，而且 error 一定要接</b>。',
          note:'<b>2026-08-20 完成。</b>檔案：<code>db/53-session-notice.sql</code>（新）、<code>db/54-customers-readonly.sql</code>（新）、<code>supabase/functions/line-hook/index.ts</code>（復活並改寫）、<code>supabase/functions/line-notify/index.ts</code>（新）、<code>line-prototype/push-optin.js</code>（新）、<code>GT-booking.html</code>、<code>checkin.html</code>。<br><br><b>新東西</b>：<code>customers.push_user_id</code>、<code>push_links</code>（30 分鐘一次性短碼）、<code>class_notices</code>（通知紀錄）、<code>issue_push_code()</code>、<code>cancel_session()</code>、<code>session_notice_list()</code>、<code>staff_push_coverage</code>。<br><br><b>☢️ 途中挖到一個跟這一步無關、但更嚴重的洞 —— 見第 82 步。</b><br><br><b>驗證</b>（Playwright，客人端 ＋ 教練端）：① 客人端四種身分：已綁定沒開通知<b>才</b>出現卡片，已開好的／沒綁定的／純瀏覽<b>都不出現</b> ✓ ② 按下去：跟資料庫要到短碼 → 跳去 <code>line.me/R/oaMessage/@fff123</code>，網址裡<b>帶著短碼與辨識前綴</b> ✓ ③ 教練端展開「停課／請假」：同時列出<b>推得到的 1 位</b>與<b>推不到、要打電話的林小華(456)</b> ✓ ④ 確認停課 → 呼叫 <code>cancel_session</code> → <b>成功之後才</b>去推播，紅色橫幅出現，提示寫「已停課。推播 1 則。☢️ 要打電話：林小華(456)」 ✓ ⑤ 模擬「已經有人點名」：<b>擋下來、而且不推播</b>，訊息是看得懂的那一句 ✓ ⑥ 兩邊都 0 個 JS 錯誤 ✓<br><br><b>2026-08-20 下午端到端實測通過</b>（Jerec 本人的手機）：① 訂課頁按「開啟通知」→ 跳官方帳號 → 送出 → <b>36 秒內</b>收到「✅ 課程異動通知已開啟」 ✓ ② 資料庫核對：短碼 <code>YAEPJ3</code> 標成已使用、<code>push_user_id</code> 寫入、<b>而且跟 <code>line_user_id</code> 是兩組完全不同的號碼</b>（<code>Ue999…11b9</code> ／ <code>Ud623…adf9</code>）—— 這正是整座橋存在的理由 ✓ ③ 建一堂只有自己報名的測試課 → 停課 → 畫面顯示「推播給 1 位」→ 確認 → <code>class_notices</code> 記錄 <b>n_push=1、錯誤 null</b>，LINE 收到「⚠️ 團課異動」 ✓ ④ 測試課次與通知紀錄事後<b>整批刪除</b>，客人資料一筆都沒動 ✓<br><br>☢️ <b>測試不能拿真的課來做。</b>本週六堂課都有客人報名，取消會直接動到他們的「我的預約」；就算挑沒人報名的那堂，課表上也會出現「已取消」，<b>而那正是我們要避免的誤會</b>。所以另開一堂名字寫「系統測試　勿報名」的課，測完刪掉。',
          ck:'① 客人端：用一個已綁定的帳號開訂課頁，課表下面會出現「開啟課程異動通知」。按下去 → LINE 開啟官方帳號、訊息已經打好 → 按送出 → 三秒內收到「✅ 課程異動通知已開啟」。再回訂課頁重整，<b>那張卡會消失</b>。<br>② 教練端：點名頁點進一堂未來的課 → 「停課／請假　通知這堂課的人」→ 展開會列出誰推得到、誰要打電話 → 填原因 → 確認。課會標成已取消，堂數<b>不會被扣</b>。<br>③ <code>select * from staff_push_coverage;</code> 看「已開通知」有沒有在長。'}
,

        { n:82, t:'客人可以改寫自己的客戶資料 —— 從第一天就在', where:'資料庫', done:true,
          summary:'加一個新欄位之前，先看看那張表現在誰寫得進去',
          body:'第 81 步要加 <code>customers.push_user_id</code>（決定停課通知送到誰的 LINE）。動手前順手看了一眼那張表的權限，結果是：<br><br><code>authenticated</code> 對 <code>customers</code> 有<b>全欄位 UPDATE</b>，而 RLS 上有一條「客人只能改自己」的 UPDATE policy。兩個加起來 ＝ <b>任何一位登入的客人都可以改寫自己那一列的每一個欄位</b>：<table><tr><td><code>phone</code></td><td>改成別人的號碼</td></tr><tr><td><code>name</code></td><td>櫃檯就搜不到他了</td></tr><tr><td><code>is_active</code></td><td>把自己藏起來</td></tr><tr><td><code>auth_user_id</code></td><td>☢️ <b>RLS 認人就是認這一欄</b>。改成別人的 uid 等於把自己這筆客戶資料交出去，或讓兩筆資料同時宣稱同一個登入身分</td></tr><tr><td><code>push_user_id</code></td><td>停課通知送到別人的 LINE（第 81 步才會有這一欄）</td></tr></table><br><b>這個洞不是第 81 步做出來的 —— 它從第一天就在。</b>只是一直沒有人問過「那張表誰寫得進去」。',
          warn:'☢️☢️ <b>會發現它，純粹是因為要加一個新欄位。</b>沒有任何錯誤、沒有任何異常紀錄，功能全部正常 —— 這種洞不會自己浮出來，只有在<b>有人特地去看</b>的時候才看得到。<br><b>加欄位到一張既有的表之前，先查一次那張表的 GRANT 和 policy。</b>你加的欄位會直接繼承那張表現有的權限，而你不會收到通知。<br><br>☢️ <b>收掉之前先確認沒有人在用。</b>翻過整個前端：<code>GT-booking.html</code>、<code>pt-request.js</code>、<code>checkin.html</code> 對 <code>customers</code> <b>全部只有 select</b>，一行 update 都沒有。建客人走 <code>create_customer()</code>（definer）、綁定走 <code>line-bind</code>（service role）、<code>push_user_id</code> 走 <code>line-hook</code>（service role）—— <b>definer 與 service role 都不看 authenticated 的權限</b>，所以收掉不影響任何功能。<br><br>☢️ <b>policy 也要一起刪掉，不能只收 GRANT。</b>留著一條寫著「客人只能改自己」的 UPDATE policy，下一個人看到會以為那條路是通的，然後照著它去補 GRANT。<b>沒有用途的規則比沒有規則更危險。</b>',
          note:'<b>2026-08-20 完成。</b>檔案：<code>db/54-customers-readonly.sql</code>（新）。<br><br><b>驗證</b>：① <code>authenticated</code> 對 <code>customers</code> 現在<b>只剩 SELECT</b>（原本 SELECT ＋ 全欄位 UPDATE）✓ ② <code>customers</code> 上只剩兩條 SELECT policy：「員工可讀全部客人」「客人只能讀自己」✓ ③ 訂課、綁定、點名、報表全部照常 —— 它們走的是 definer 函式與 service role，一開始就沒用到那個權限 ✓',
          ck:'客人端所有功能照舊（訂課、查堂數、綁定）。要驗的話跑：<code>select privilege_type from information_schema.column_privileges where table_name=\'customers\' and grantee=\'authenticated\' group by 1;</code> → 只會有 <code>SELECT</code> 一列。'}
,

        { n:83, t:'停課要能提前排 —— 但別把每天在用的畫面弄慢', where:'資料庫 ＋ 前端', done:true,
          summary:'教練後台只看得到「明天」為止，下週的課根本不在畫面上',
          body:'第 81 步做完真的拿去用，才撞到這件事：<b>「下週三我要出國，先把那堂課停掉」做不到</b> —— 那堂課不在清單裡。<br><br>原因在 <code>staff_sessions</code> 這支檢視表，範圍寫死在 <b>今天 −7 到 今天 +1</b>。放寬到 <b>今天 +14</b>（目前課表最遠排到 09/02，全涵蓋）。<br><br><b>但放寬會帶來新問題</b>：「接下來」會從 3 張卡變成 <b>27 張</b>，而教練 99% 的時候是來點<b>今天</b>的名。所以畫面拆成三段：<table><tr><td>今天</td><td>攤開</td></tr><tr><td>明天</td><td>攤開</td></tr><tr><td>更後面的課（24 堂）</td><td><b>收合</b>，副標寫「要提前停課在這裡找」</td></tr></table>要提前停課的人找得到，每天在用的人不用滑過去。',
          warn:'☢️☢️ <b>用 <code>create or replace view</code>，不要 drop + create。</b>欄位一個都沒變（只動 where），replace 會保留 GRANT。drop 會把 GRANT 一起帶走，然後<b>所有教練當場看不到任何課</b> —— 而且錯誤訊息是「查無資料」，不是「沒有權限」（第 37 步踩過一次）。改完親眼確認了兩件事：<code>authenticated:SELECT</code> 還在、<code>reloptions</code> 仍然是空的（definer 沒被改掉）。<br><br>☢️ <b>加一天不能用 <code>new Date(y,m,d)</code> 再 <code>setDate</code></b> —— 那會用瀏覽器所在時區，跨月時可能多一天或少一天。要用 UTC 推。（規則 16 的另一種長相）<br><br>☢️ <b>「收合」不等於「不載入」。</b>24 張卡還是在 DOM 裡，只是 <code>&lt;details&gt;</code> 沒展開 —— 所以卡片的 <code>onclick</code> 照樣掛得上，展開就能點。如果改成「展開才去撈資料」，反而多一次來回、還要處理載入中狀態。<br><br>☢️ <b>測「有沒有被藏起來」不能用 <code>offsetParent</code> 或 <code>getBoundingClientRect()</code>。</b>Chromium 對收合的 <code>&lt;details&gt;</code> 用的是 <code>content-visibility:hidden</code> 而不是 <code>display:none</code> —— 那兩個 API <b>都會回報「看得到」</b>，測試就這樣綠燈通過一個沒生效的功能。要用 <code>checkVisibility({contentVisibilityAuto:true})</code>。<b>第一版測試就是這樣騙過自己的。</b>',
          note:'<b>2026-08-20 完成。</b>檔案：<code>db/55-staff-sessions-window.sql</code>（新）、<code>line-prototype/checkin.html</code>。<br><br><b>驗證</b>（Playwright，360／390／430px）：① 檢視表範圍 <b>18 堂 → 42 堂</b>，GRANT 與 definer 都沒掉 ✓ ② 畫面分成「今天 8/20」「明天 8/21」「更後面的課（24 堂）」三段 ✓ ③ <b>收合時只看得到 5 張卡</b>（今天 2 ＋ 明天 3），DOM 裡 29 張都在 ✓ ④ 展開後 29 張全部看得到，頁面高度 <b>1000 → 3118px</b> ✓ ⑤ 摺疊區裡的卡片 <code>onclick</code> 有掛上，點得進去 ✓ ⑥ 三種寬度都沒有橫向溢出、0 個 JS 錯誤 ✓',
          ck:'點名核銷會多一段「<b>更後面的課（N 堂）</b>」的摺疊列，在「明天」那一區下面。點開能看到未來兩週的課，點進去就能用「停課／請假」。今天和明天那兩段<b>維持原樣攤開</b>，不用多按。'},

        { n:84, t:'職級與加給的設定介面 —— 把 SQL 從流程裡拿掉', where:'資料庫 ＋ 前端', done:true,
          summary:'第 78 步建了兩張表，但值只能用 SQL 塞',
          body:'薪資算得出來，但「誰是主管階層教練」「VC 的店長加給改成多少」這兩件事<b>只能開 Supabase 跑 SQL</b>。那不是能交給人每個月用的東西。<br><br>薪資報表最下面加一個摺疊區「<b>設定：職級與職務加給</b>」：<table><tr><td>職級</td><td>列出所有<b>授課教練</b>與目前職級（主管 45%／一般 40%）。改職級＝<b>新增一筆帶生效日的異動</b></td></tr><tr><td>職務加給</td><td>誰、什麼項目、每月多少、從哪天起。結束一筆＝<b>填結束日</b></td></tr></table>',
          warn:'☢️☢️ <b>改職級不能是一個開關。</b>規則第五篇 2：「職級於月中生效或停止時，以生效日前後的實際業績分段套用相應比例。」如果直接改一個欄位，<b>上個月已經結完的薪資會跟著一起變</b> —— 那是重算歷史，不是改設定。所以存的是<b>異動史</b>，每次改都是新增一列帶生效日，<code>coach_grade_on()</code> 逐筆用完成日去查。<br><br>☢️☢️ <b>結束一筆加給是「填結束日」，不是刪掉。</b>刪掉的話<b>以前的月份會跟著少發</b> —— 八月的加給憑空消失，而且沒有任何地方會記得它曾經存在。<b>實測驗過整條路完全沒有 delete。</b><br><br>☢️☢️ <b>同一人同一項加給的時間區間重疊，會在月結時發兩份。</b>而且對帳看不出來 —— 金額是「合理的兩倍」，不是一個明顯的錯數字。加了 <code>exclude using gist</code> 的排除約束擋在資料庫（要 <code>btree_gist</code> 擴充）。<b>前端只是把原文錯誤訊息翻成人話，真正的牆在資料庫。</b><br><br>☢️☢️ <b>可以挑到新系統上線前的月份 —— 那會跑出一個看起來像答案的錯數字。</b>2026-08 之前系統裡只有搬遷進來的課次：沒有職務加給、沒有服務紀錄、沒有職級核定。算得出東西，<b>而且不完整的地方不會自己顯示出來</b>。做法是<b>三層</b>：「上個月」那顆鍵在早於起點時不出現、月份輸入框加 <code>min</code>、真的挑到了再跳紅字說明為什麼不能用。<br>☢️ <b>紅字不擋數字。</b>擋掉的話下次有人需要查歷史就沒得查；標註「這個不可信」才是對的 —— 系統的責任是<b>不讓人誤以為它可信</b>，不是不給看。<br><b>決定（Jerec 2026-08-20）</b>：加給實際上更早就開始，但<b>八月起才正式計算</b>，舊的封存在系統外的檔案庫。<br><br>☢️ <b>「查不到職級」＝一般教練，那是規則不是預設值。</b>規則第五篇 2：「未正式核定為主管者，適用一般教練比例。」所以空的職級表是<b>正確狀態</b>，不是待補 —— 畫面上要把這句話寫出來，否則看到「沒有核定紀錄」的人會以為系統壞了。<br><br>☢️ <b>非授課教練不出現在職級清單。</b>林智謙、簡基城、櫃檯平板的 <code>can_teach</code> 是 false，他們沒有抽成業績，列出來只會讓人以為漏設了什麼。<br><br>☢️ <b>設定讀完之後一定要再畫一次。</b>第一版只呼叫 <code>loadConfig()</code> 不重畫 —— 設定區<b>永遠是空的，而且沒有任何錯誤</b>。實測才發現。<br><br>☢️☢️ <b>同一個外鍵陷阱，兩天內踩第二次。</b><code>coach_allowances</code> 也有兩條指向 <code>employees</code>：<code>employee_id</code>（誰領）和 <code>created_by</code>（誰設定的）。只寫 <code>employees(...)</code> 整個查詢回錯，而 <code>(!r.error && r.data) ? r.data : []</code> 把錯誤吞掉回空陣列 —— 畫面顯示<b>「還沒有任何職務加給」，但資料明明在</b>。上線後 Jerec 一眼看出來的。<br>☢️ 規則記死：<b>嵌套查詢一律指名外鍵，而且 error 一律不吞</b>。（第 81 步已經記過一次，還是又踩了 —— 所以這次連錯誤訊息也顯示出來。）<br><br>☢️ <b>沒有包成 RPC，直接寫表。</b>兩張表的 RLS policy 就是 <code>is_finance()</code>，牆已經在資料庫了；再包一層 definer 函式只會多一個要維護的東西，不會多一分安全。<b>但寫入失敗一定要顯示出來</b> —— 靜靜地什麼都不做，使用者會以為存好了，下個月才發現薪水算錯。',
          note:'<b>2026-08-20 完成。</b>檔案：<code>db/56-allowance-guard.sql</code>（新）、<code>line-prototype/payroll.html</code>。<br><br><b>驗證</b>（Playwright，390px）：① 摺疊區<b>預設收合</b> ✓ ② 三位授課教練都列出來，<b>林智謙（非授課）不出現</b> ✓ ③ 有核定紀錄的顯示「主管階層 45%」，沒紀錄的顯示「一般教練 40%」 ✓ ④ 改職級寫出的是 <code>{employee_id, grade, effective_from}</code> ＋ <code>onConflict</code>，<b>是新增異動不是覆寫</b> ✓ ⑤ 結束加給寫的是 <code>{to_date}</code>，<b>整條路 0 次 delete</b> ✓ ⑥ 金額沒填會擋下來，而且<b>擋下來就真的沒寫進去</b> ✓ ⑦ 沒有橫向溢出、0 個 JS 錯誤 ✓ ⑧ <b>上線後才發現加給列表是空的</b>（外鍵沒指名，錯誤被吞掉），已修並改成錯誤會顯示出來 ✓ ⑨ 早於 2026-08 的月份：「上個月」鍵不出現、<code>min</code> 擋住、硬挑會跳紅字且<b>數字照樣顯示</b>（標註不可信而不是擋掉）✓<br><br><b>資料庫實測</b>：故意塞一筆時間重疊的加給 → <code>exclusion_violation</code> 被擋，資料列數不變 ✓',
          ck:'薪資報表滑到最下面，會多一個「<b>設定：職級與職務加給</b>」摺疊區。點開能看到三位教練目前都是「一般教練 40%」（<b>那是對的</b> —— 還沒核定任何人為主管），以及你和 VC 的兩筆加給。要把某位設成主管：按「改職級」→ 選主管階層 → 填生效日 → 存起來。'},

        { n:85, t:'累進抽成的驗算 ＋ 服務登記實跑一筆', where:'資料庫 ＋ 前端', done:true,
          summary:'抽成的算法寫好了，但從來沒有真資料走過那條路',
          body:'第 78 步把累進抽成寫進 <code>payroll_lines</code>，第 84 步把職級搬到畫面上，<b>但 <code>service_records</code> 到今天還是 0 筆</b> —— 整條「上了一堂 PT → 進業績 → 抽成進薪水」的路，從來沒有真的走過一次。<br><br>拆成兩半驗：<table><tr><td><b>數學</b></td><td>五個情境全程 rollback，不留任何資料</td></tr><tr><td><b>管線</b></td><td>Jerec 用手機真的登記一筆 PT，看它走完待確認 → 認列 → 進薪資 → 作廢</td></tr></table>五個情境：<ul><li><b>A</b> 一般教練 90,000 一筆 → 37,000（80,000×40% ＋ 10,000×50%）</li><li><b>B</b> 同樣業績改主管 → 41,000（80,000×45% ＋ 10,000×50%）</li><li><b>C</b> 主管 30,000×<b>三筆</b> → 還是 41,000</li><li><b>D</b> 月中升職：09/05 的 40,000 用一般、09/20 的 50,000 用升職後的級距 → 39,000</li><li><b>E</b> 沒有最終認列的 → 0</li></ul>',
          warn:'☢️☢️ <b>C 情境才是這一支的重點。</b>總額一樣、拆成幾筆不該影響抽成。如果 C 算出來不是 41,000，代表累進是<b>每一筆各自從 0 開始算</b> —— 那是這類程式最典型的錯法，而且算出來的錢<b>永遠看起來是合理的</b>，不是一個明顯的錯數字。等到月底發現，錢已經發出去了。<br><br>☢️☢️ <b>測試月份要用 2099-01，不能用「下個月」。</b>第一版寫 2026-09。現在 <code>service_records</code> 是空的所以剛好會過，但等系統裡開始有真的服務紀錄，這支就會把真資料一起加進來算，然後永遠說「錯」—— 而那時候沒有人會相信是測試寫壞了。每一句 <code>select</code> 也加上 <code>coach_id = v_coach</code>，只看測試對象那一位。<br><br>☢️ <b>借來的那位教練可能本來就有職級紀錄。</b>不先清掉的話 A 情境會被他原本的職級影響。清掉一樣會跟著回捲。<br><br>☢️ <b>不要寫死教練名字。</b>第一版直接寫某位教練的名字挑人 —— 這個 repo 是公開的，而且那個人離職這支就壞了。改成「隨便挑一位在職的」。<br><br>☢️ <b>最後一行的 <code>raise exception</code> 是故意的。</b><code>raise notice</code> 的輸出拿不回來，而要同時「拿到結果」又「保證整批回捲」，只有這一種寫法。<b>看到紅色錯誤訊息才是正常的，訊息本身就是答案。</b><br><br>☢️ <b>沒有認列的紀錄必須「被看見地」不算，不是靜靜地不算。</b>實跑時它出現在<b>「1 筆暫停自動計薪」</b>那一區，紅底寫著「這些沒有算進上面的合計」。如果只是不算，財務會以為那筆漏掉了。',
          note:'<b>2026-08-20 完成。</b>檔案：<code>tools/payroll-perf-check.sql</code>（新）。<br><br><b>數學（五項全過）：</b><table><tr><td>A 一般 90,000 一筆</td><td>37,000 ✓</td></tr><tr><td>B 主管 90,000 一筆</td><td>41,000 ✓</td></tr><tr><td>C 主管 30,000×3</td><td>41,000 ✓</td></tr><tr><td>D 月中升職 40,000＋50,000</td><td>39,000 ✓</td></tr><tr><td>E 待確認</td><td>0 ✓</td></tr></table>跑完確認資料庫乾淨：服務紀錄 0、服務教練 0、職級紀錄 0。<br><br><b>管線（Jerec 手機實跑）：</b>① 完成時間填未來 → 被擋「完成時間不能是未來」✓ ② 登記後是<b>待確認</b>，薪資報表合計 <b>42,300</b>、抽成 0，多出「<b>1 筆暫停自動計薪</b>」✓ ③ 按最終認列後合計 <b>42,700</b>，該教練出現「抽成 NT$400（業績 NT$1,000）」＝ 1,000×40% ✓ ④ 作廢後回到 42,300，紀錄變刪除線且留著作廢原因 ✓ ⑤ 測試紀錄刪除後 <code>service_records</code> 回到 0，八月合計 42,300、0 筆暫停 ✓',
          ck:'以後只要動過抽成級距、職級規則或 <code>payroll_lines</code>，把 <code>tools/payroll-perf-check.sql</code> 整份貼進 Supabase 的 SQL Editor 跑一次。<b>會跳紅色錯誤訊息，那是正常的</b> —— 訊息裡看到五個 OK 就是對的，出現「☢️錯」就是哪裡壞了。'}
      ]
    },


    /* ══════════ 第七幕 ══════════ */
    {
      key: 'a7', place: '名冊室與帳房之間', no: '第七幕', name: '把帳接起來', theatre: '＝ 把真的資料搬進帳房',
      note: '前六幕蓋好了帳房，但裡面是空的。這一幕把<b>真的東西</b>搬進去：八月 231 堂 PT／PGT、155 位客人、還有兩顆「按錯了怎麼辦」的鍵。<br><br>☢️ 這一幕也把卡了五天的<b>第 36 步</b>解掉了 —— 它在第四幕，2026-08-16 卡到 08-21。',
      milestone: {
        title: '▲ 第七幕結束 — 你現在擁有的',
        text: '系統第一次裝著<b>完整的一個月</b>：231 堂課、223 位客人、每一堂都掛得到人、每一塊錢都算得出是誰賺的。八月薪資從 42,300 變成 218,175 —— 差的那 17 萬不是漲價，是<b>本來就發生了、只是系統看不到</b>。☢️ 客人那一側還看不到自己 —— PT 預收餘額是 0，見地平線。'
      },
      steps: [
        { n:86, t:'服務紀錄批次匯入 —— 先驗全部、全對才寫', where:'資料庫', done:true,
          summary:'薪資報表的「PT＋PGT 抽成」是 0，那不是算錯，是算對了一張空表',
          body:'八月有 231 堂 PT／PGT 上完了，但 <code>service_records</code> 是 <b>0 筆</b>。所以薪資報表的抽成是 0 —— <b>那不是算錯，是算對了一張空表</b>。<br><br>用畫面一筆一筆登要四五個小時，所以做一支匯入工具。<br><br><b>口徑</b>（Jerec 裁決）：8/01–8/09 用《健康化》檔（除錯後信心最高的版本）、8/10–8/20 用八月流水帳、完全重複的 3 筆只算一次、7 筆「補 3/13、補 6/19…上課紀錄」屬於已封存的月份不進系統。',
          warn:'☢️☢️ <b>先驗全部，全對才寫。</b>一次進 231 筆，最危險的失敗是「做到一半」：前 100 筆寫進去了、第 101 筆教練名字打錯而中斷，然後<b>沒有人知道停在哪</b>，重跑會讓一部分課變成兩倍業績。<br><br>☢️ <b>防重靠 <code>import_key</code> 的唯一索引，不靠人記得自己跑過沒有。</b>key 由內容算出來，同一批重跑第二次會被資料庫擋下來，而不是安靜地寫第二份。<br><br>☢️ <b>唯一索引擋得住重跑，擋不住「同一次呼叫裡就帶了兩份」。</b>那份流水帳真的有（Jessica 8/03 的兩堂各出現兩次），所以要另外檢查同一批裡的重複 key。<br><br>☢️ <b>最重要的一條檢查是「業績 ＝ 課程費 ＋ 交通費」。</b>對不起來就代表分類或金額有一個是錯的 —— 而<b>兩種錯都算得出一個合理的數字</b>。<br><br>☢️☢️ <b>清單排序不能用 <code>created_at</code>。</b>批次匯入的 231 筆<b>共用同一個 <code>created_at</code></b>（同一個交易裡的 <code>now()</code> 是同一個值），所以它們之間的先後<b>沒有定義</b>。「最近登記」實測回來的是<b>最舊的 20 筆</b>。<br>☢️ 更嚴重的是第二層：唯一那筆「待確認」排在第 100 多名，<b>被 20 筆上限藏起來</b>——而沒認列就不進薪資，那筆錢會永遠沒有人處理。待確認因此獨立一區、置頂、不受筆數限制。<br><br>☢️ <code>text[] ‖ 字串</code> 會被當成「陣列 ‖ 陣列」，Postgres 去解析那個字串當陣列字面值然後噴 <code>malformed array literal</code>。要寫 <code>::text</code>。第一次測試就是被這一行擋下來的。',
          note:'<b>2026-08-20～21 完成。</b>檔案：<code>db/57-import-service.sql</code>（新）、<code>local/57-aug-import.sql</code>（資料，不進 Git）、<code>line-prototype/service.html</code>。<br><br><b>結果</b>：231 筆、業績 <b>361,450</b>、教練關聯 231、0 筆沒有教練。1 筆有疑義的被強制留在「待確認」（中華電信包班記成一對一），Jerec 裁決為特殊個案後認列。<br><br>☢️ <b>累進級距第一次真的用上</b>：Peter 115,700、Johnson 107,200 都跨過 80,000，超過的部分抽 50%。第 85 步驗的就是這件事。<br><br><b>八月薪資</b>：42,300 → <b>218,175</b>（抽成 165,975 ＋ GT 17,300 ＋ 加給 34,500）。<br><br>☢️ 匯入時用「第一個財務帳號」冒充身分，所以 231 筆的登記人一開始記成 VC 而不是實際執行的 Jerec，事後改正。<b>下次寫匯入腳本要讓它問「你是誰」，不要自己挑一個。</b>',
          ck:'薪資報表選 2026-08，「PT＋PGT 抽成」不再是 0；服務登記的「待確認」自成一區在最上面，不會被 20 筆上限藏起來。' },

        { n:87, t:'手機可以留空，但一支號碼還是只能一個人', where:'資料庫', done:true,
          summary:'155 位裡有 18 位聯絡不上，而 phone 當時是 not null',
          body:'PT／PGT 的 155 位客人要進系統，其中 <b>18 位沒有手機</b> —— 聯絡不上，短期補不齊。而 <code>customers.phone</code> 當時是 <code>not null</code>，他們一個都塞不進去。八月已經有 <b>23 堂、37,400 業績</b>掛在這群人身上。',
          warn:'☢️☢️ <b>不塞假手機。</b>Jerec 問過「先用代號」，三個理由否決：① 報表上的「末三碼」會變成假的末三碼，對帳報表和停課通知的人工名單都印它 —— 櫃檯拿它認人就會認錯人。② 手機是唯一鍵，代號哪天長得像號碼、或真的有人擁有那組號碼，就撞號。③ <b>最難查的一種錯：資料看起來是完整的。</b>空值會逼人去處理，假值不會。<br><br>☢️☢️ <b>一度要開放「家人共用手機」，評估後放棄</b>（德龍爺爺與陳悠瑩 Lisa 共用 0935518808）。理由記在這裡免得將來有人重新想一次：手機＝身分證這條規則的價值不在省程式，在於<b>沒有人需要記例外</b>；開放之後每一個「用手機找人」的地方都要處理「找到多個」，而<b>忘記的症狀是「查無此人」不是報錯</b>；櫃檯搜尋會跳兩個人，點錯就扣到別人的堂數。<br>☢️ 而且真要做「一家人」，正確做法是一張<b>家庭關係表</b>，不是讓兩個人共用唯一鍵。<b>號碼歸個人，關係歸關係。</b><br>→ 德龍爺爺跟那 18 位同一類：手機留空，號碼留給實際持有的 Lisa。<br><br>☢️ <b>Postgres 的 UNIQUE 本來就允許多個 NULL</b> —— 所以「可為空 ＋ UNIQUE(phone)」剛好就是要的：有號碼的一號一人，沒號碼的要幾個有幾個。不需要 partial index。<br><br>☢️ <b>留空的人是什麼狀態要講清楚</b>：推不到通知、綁不了 LINE、查不到自己的堂數 —— <b>只存在於櫃檯的帳上</b>。不是建了就通了。<br><br>☢️ <b>櫃檯建檔照樣必填。</b>可以留空的只有匯入那條路 —— 要讓一個人沒有手機，必須是「我們真的聯絡不上他」，不能是「櫃檯懶得問」。',
          note:'<b>2026-08-21 完成。</b>檔案：<code>db/58-phone-optional.sql</code>（新）、<code>supabase/functions/line-bind/index.ts</code>。<br><br><b>驗證</b>（全程 rollback、0 筆殘留）：沒手機的可以有多位 ✓ 同號碼建第二個人被擋且講出已經是誰 ✓ 櫃檯不填手機被擋 ✓ 繞過函式直接 insert 重複號碼<b>資料庫自己擋下來</b> ✓ <code>create_customer</code> 只剩一個版本、GRANT 沒掉 ✓<br><br>☢️ <b>順手修掉綁定的一個吞錯誤</b>：<code>line-bind</code> 用 <code>.maybeSingle()</code> 撈手機而且<b>沒接住 error</b> —— 查詢一出錯就變成 <code>null</code>，客人一律看到「查無此人」。<b>讀不到跟真的沒這個人，意思完全相反。</b>改成撈清單 ＋ 錯誤照實回報。（<b>這一支還沒部署</b> —— 用手貼 11KB 到客人登入的必經之路，風險比它修的 bug 大，等下次要動那支時一起做。）',
          ck:'教練後台建客人時，手機還是必填；但匯入進來的 18 位在客人名單上查得到，末三碼是空的。' },

        { n:88, t:'兩顆還原鍵 —— 作廢的紀錄、取消的課次', where:'資料庫 ＋ 前端', done:true,
          summary:'同一天撞到兩次「只有 SQL 做得到、畫面上沒有」的操作',
          body:'① VC 誤按了一筆服務紀錄的「作廢」（原因欄填「爽」），畫面上<b>沒有還原鍵</b>，只能進資料庫改。<br>② 8/21 19:00 那堂課被夜間排程判定無人報名而取消，而點名頁的紅字寫著「請找 Jerec 在後台改課次狀態」—— ☢️ <b>但後台根本沒有那個開關。那句話從第 39 步寫到現在都是假的。</b>',
          warn:'☢️☢️ <b>還原不是抹掉。</b>作廢過、取消過這件事本身要留在紀錄上。<b>靜靜地變回去，比錯誤本身更難查</b> —— 三個月後沒有人知道那筆錢中間消失過。所以還原<b>也要寫原因</b>，而且原本的作廢者、時間、原因會一起寫進人工註記。<br><br>☢️☢️ <b>重新開課時，客人自己取消的預約一律不還原。</b>他真的不想來，系統不該替他決定。只還原「職員取消整堂課時連帶取消」的那些 —— 而且<b>只看 <code>cancelled_by</code> 不夠</b>：櫃檯可能為了別的理由單獨取消過某一個人，那一筆不該被連帶救回來。要拿 <code>class_notices</code> 的取消時間當基準。<br><br>☢️ <code>class_notices.kind</code> 原本只認得 cancel／change／note。直接寫 reopen 會被 CHECK 擋下來，<b>而那發生在 update 之後，整個交易回捲</b> —— 畫面上看起來是「按了沒反應」。<br><br>☢️ <b>作廢原因欄沒有擋。</b>填「爽」也過，而且會永遠留在紀錄上、對帳報表看得到。',
          note:'<b>2026-08-21 完成。</b>檔案：<code>db/60-undo.sql</code>（新）、<code>line-prototype/service.html</code>、<code>line-prototype/checkin.html</code>。<br><br><b>驗證</b>（八個情境，全程 rollback）：沒寫原因擋下 ✓ 沒作廢的不能還原 ✓ 作廢→還原後註記留著「原作廢者、原因」✓ 沒取消的課不能重新開課 ✓ 真的重新開課 → 狀態 <code>confirmed</code>、還原預約 0、客人自己取消的 2 ✓<br><br><b>那堂課的真相</b>：兩位客人<b>都是自己取消的</b>（8/19 訂了同一分鐘就退、8/20 晚上退），到 8/21 00:00 結算時真的 0 人報名 —— <b>夜間排程沒有做錯</b>。',
          ck:'服務登記：作廢過的那一列有「還原」。點名頁：取消的課下面有綠色的「重新開課」，按下去填原因就能點名。' }
      ]
    },

    /* ══════════ 第八幕 ══════════ */
    {
      key: 'a8', place: '帳房後間', no: '第八幕', name: '把錢收齊', theatre: '＝ 帳房還沒接上金庫',
      note: '☢️ <b>這一幕還沒開始蓋。</b>下面七步（89～95）是「帳務完整線上化」剩下的距離 —— 每一步都是<b>現在查得出來的缺口</b>，不是願望清單。<br><br>目前的狀態講白一點：<b>GT 那一側的錢是完整的</b>（購課金額、現金／匯款、待入帳、方案對帳都在），<b>服務登記那一側只記了「賺多少」，沒記「收到沒」</b>，而<b>支出除了教練薪資以外，系統一毛都不知道</b>。',
      milestone: {
        title: '▲ 第八幕結束 — 你會擁有的',
        text: '一個月結束時按一顆鍵，就知道這個月收了多少、發了多少、剩多少。<b>而且那個數字結完就鎖住，不會被明天改的設定悄悄改掉。</b>☢️ 但「錢真的在線上收」不在這一幕裡 —— 那要先搬離 GitHub Pages，在地平線那一頭。'
      },
      steps: [
        { n:89, t:'決定：一個月的「收入」算收到錢那天，還是上完課那天', where:'決定', done:true, kind:'decide',
          summary:'這一條決定損益表每個月的數字長什麼樣',
          body:'GT 是<b>預收</b>：客人八月付 12,000 買 12 堂，可能上到十二月才上完。這筆 12,000 要算成八月的收入，還是每上一堂認 1,000？<table><tr><td><b>收現制</b></td><td>收到錢那天算收入。簡單、跟銀行帳戶對得起來，但八月會很好看、十二月會很難看</td></tr><tr><td><b>權責制</b></td><td>上完課才認。每個月的數字才反映「這個月實際做了多少生意」，代價是要多顧一本「還欠客人幾堂」</td></tr></table>☢️ <b>兩種算法需要的資料我們都已經有了</b>（<code>credit_ledger.amount</code> 是收現那一側，<code>plans.per_credit</code> ＋ 逐堂認列是權責那一側）—— 所以這是<b>選擇</b>，不是能力問題。先選，後面三步才知道要算什麼。',
          note:'<b>2026-08-21 裁決：權責制。</b>記在 <code>local/rules-v2.md</code> 附註 A（不進 Git）。<br><br>☢️ <b>結果是「這不是新決定」。</b>規則第二篇 1.3、1.4 本來就寫著權責制 ——「每堂完成時均須記錄公司收入」「完成一堂，認列一堂」「尚未完成的堂數不得提前認列」。這一步做的是<b>把它講明白，並且確定損益表照它走</b>。<br><br><b>裁決當下的八月數字</b>：<table><tr><td></td><td>收現制</td><td>權責制</td></tr><tr><td>GT</td><td>16,800</td><td>110 堂 × 333.33 ＝ 36,667</td></tr><tr><td>私人課</td><td><b>系統無資料</b></td><td>361,450</td></tr><tr><td>八月收入</td><td>16,800（不完整）</td><td><b>398,116</b></td></tr></table>還欠客人 <b>631 堂 ≒ 210,331 元</b>（負債，不是收入）。<br><br>☢️ <b>這張表本身就在回答問題</b>：權責制現在就算得出來，收現制算不出來 —— 因為 <code>service_records</code> 沒有付款欄位（那是第 90 步）。八月的 16,800 不是生意差，是<b>錢在五、六月就收了</b>。<br><br>☢️ <b>選權責制不表示不記收款。</b>兩本帳都要有，收現那一側是「跟銀行對得起來」用的，只是不當損益表的主軸。規則 1.4 要求的四欄要分開記：實收金額、預收餘額、已完成收入、教練業績。<br><b>目前只有 GT 四欄齊全</b> —— 私人課沒有實收（第 90 步）、PT 預收餘額是 0 張方案（私人課完整流程）。<br><br>☢️ <b>權責制成立的前提是「預收餘額」是準的。</b>PT 現在 0 張方案，等於那一側的負債沒有記 —— 損益表之前一定要補。<br><br><b>外部條件</b>：工作室符合<b>免用統一發票</b>條件，所以沒有稅務上的強制要求，這純粹是管理決定。',
          ck:'白紙黑字寫下來選哪一種，並且寫進財務規則文件。' },

        { n:90, t:'服務登記要記「收到錢了沒、怎麼收的」', where:'資料庫 ＋ 前端', done:true,
          summary:'私人課那一側只記了賺多少，沒記收到沒',
          body:'<code>credit_ledger</code> 有 <code>amount</code>／<code>pay_method</code>／<code>paid_at</code> 三欄，所以 GT 那一側分得出「現金」「匯款」「還沒入帳」。<b><code>service_records</code> 一欄都沒有</b> —— 私人課、企業包班、外派活動只記得 <code>revenue_amount</code>（賺多少），完全不知道錢到了沒。',
          warn:'☢️ <b>「待入帳的匯款」目前只認得 GT。</b>企業包班動輒幾萬塊，而且幾乎一定是匯款 —— 那筆錢沒進帳的話，現在<b>沒有任何一個畫面會提醒你</b>。<br><br>☢️ 欄位要跟 <code>credit_ledger</code> 用<b>同一組名字、同一組值</b>（<code>cash</code>／<code>transfer</code>）。不一樣的話，第 88 步合併兩邊時就要寫一張轉換表，而轉換表就是下一個對不起來的地方。',
          note:'<b>2026-08-21 完成。</b>檔案：<code>db/61-service-payments.sql</code>（新）、<code>line-prototype/service.html</code>、<code>local/62-aug-payments.sql</code>（補登資料，不進 Git）。<br><br>☢️☢️ <b>結果不是加三個欄位，是一張表。</b>因為 Usports ——「客人實繳 14,500，商家再跟政府申請拿回 500」，<b>一筆交易有兩個付款人</b>。只加一欄 <code>pay_method</code> 的話這種交易永遠塞不進去：只能記成「14,500 現金」然後把 500 弄丟，或記成「15,000 現金」然後跟銀行對不起來。健康化檔顯示 Usports 從 2024 年起出現過 <b>25 次</b>，長相還不只一種。<br><br>☢️ <b>這張表只記「在課堂當下收的錢」。</b>231 筆裡有 173 筆是扣預收 —— 那些錢在購課時就收了，再記一次收入會算兩遍。但<b>不硬擋</b>（八月真的有一筆「50 塊差額是上次付款時未找錢」），改成非單堂收款必須寫原因。<br><br><b>八月補登</b>（Jerec 選「回頭補登」）：58 筆單堂全部對上流水帳，<b>寫入 56 筆、91,050</b>。☢️ 剩下 2 筆是真的發現 —— <b>鄭立中 08/10、08/18 各該付 2,000，流水帳收款欄是空的</b>，留在未收區。<br>☢️ 補登也補不完整：八月實收約 331,950，這裡只補得到單堂的 91,050，另外 229,000 是預收，要等 PT 購課功能才有地方去。<br><b>選補登的理由不是帳變完整，是</b>「還沒收齊」<b>那個數字從此可信</b> ——永遠掛著 58 筆紅字的警示區，兩週後就沒有人會看，58 變 59 也沒有人看得出來。<br><br>☢️☢️ <b>踩到一個新的坑：程式碼被插進 &lt;style&gt; 裡。</b>我用「待確認專區」當錨點做字串取代，但那句話<b>在 CSS 註解裡也有一份</b>，於是六個函式全部寫進樣式表 —— <code>unpaidBlock</code> 不存在，<code>render()</code> 一呼叫就 ReferenceError，<b>整頁空白</b>。而我的語法檢查<b>只檢查 &lt;script&gt; 裡面</b>，錯的東西在外面，檢查看不到。<br>☢️ 教訓兩條：<b>取代用的錨點要挑「只可能出現在那一層」的字串</b>（函式宣告本身，不是註解）；<b>改完要把整頁真的跑起來</b>，不能只驗語法。<br><br>☢️ <b>可讀性補丁</b>：扣預收那幾列原本一片空白，20 筆裡有 15 筆長這樣 —— 看起來像功能壞了。加一行淡灰色的「預收扣抵 —— 這一堂不在現場收錢」／「體驗／贈課 —— 不收費」，讓「本來就不用收」跟「還沒開始收」<b>長得不一樣</b>。',
          ck:'服務登記多一欄付款方式；匯款但還沒入帳的那幾筆，會跟 GT 的匯款一起出現在對帳報表的「待入帳」區。' },

        { n:91, t:'對帳報表納入服務登記的錢', where:'資料庫 ＋ 前端', done:true,
          summary:'finance_report 目前只讀 credit_ledger 一張表',
          body:'對帳報表（第 61 步）的每一段 —— 收款明細、每日現金／匯款小計、待入帳 —— <b>資料來源都只有 <code>credit_ledger</code></b>。也就是說<b>私人課、企業包班、外派活動的營收，一塊錢都沒出現在報表上</b>。<br><br>它們不是沒記，是記在另一張表（<code>service_records</code>），只是從來沒有人把兩邊加起來。',
          warn:'☢️ <b>這是「有資料但沒人看得到」，最容易被誤判成生意變差。</b>八月的對帳報表看起來就是全店只有 GT 的收入 —— 而那個數字<b>看起來完全合理</b>，不是一個明顯的錯數字。<br><br>☢️ 加總時<b>作廢的不能算、沒有最終認列的要分開顯示</b>，規則要跟薪資那邊一致（第 85 步）。同一筆錢在兩張報表上算法不一樣，比少算還糟。',
          note:'<b>2026-08-21 完成。</b>檔案：<code>db/62-finance-report-merge.sql</code>（新）、<code>line-prototype/report.html</code>。<br><br><b>八月的數字接起來了</b>：收款明細從 <b>6 筆 16,800</b>（只有 GT）變成 <b>62 筆 107,850</b> —— GT 購課 6 筆 16,800 ＋ 服務登記 56 筆 91,050。<br><br>☢️ <b>多做了一塊「應收未收」，而它不在原本的規劃裡。</b>做到一半才發現報表少一個洞：「待入帳」問的是<b>錢在路上</b>（已經記了一筆收款，只是還沒進帳戶），但八月那兩筆<b>鄭立中各 2,000</b> 連一列收款都沒有 —— 錢<b>還沒開始走</b>。這兩件事處理方式完全不同（一個是等、一個是去要），合成一塊就都不會被處理。沒有這一區的話，報表只會說「八月收了 107,850」，那 4,000 的洞<b>不會出現在任何一個畫面上</b>。<br><br>☢️ <b>前端的合計是最容易漏的地方。</b>後端多了一種付款方式「補助」，而前端的合計原本寫死是 <code>現金 ＋ 匯款</code> —— 不改的話報表會<b>少算那幾百塊，而且畫面上看起來完全正常</b>。那是最難發現的一種錯。<br><br>☢️ <b>踩到一個新坑：plpgsql 建得起來、跑起來才爆。</b>我在應收未收那段寫了 <code>s.coach_id</code>，但教練<b>不在 <code>service_records</code> 上</b>（一堂課可以有兩個教練，所以掛在 <code>service_coaches</code>）。<code>create function</code> <b>完全不檢查函式體裡的 SQL</b> —— 建立成功、回 <code>{"success":true}</code>，直到真的有一筆應收未收的資料才炸。<br>☢️ 教訓：<b>函式建好一定要用真資料跑一次，而且要跑到有資料的那條路</b>。空區間跑過不算跑過。<br><br>☢️ <b>兩邊的「作廢」寫法不一樣，不能寫成同一條</b>：GT 走沖銷（另外插一列 <code>reason=\'adjust\'</code>），服務登記走 <code>voided</code> 旗標。漏掉任何一種，作廢的錢都會被算成收入。<br><br>☢️ <b>服務登記沒有堂數</b>（<code>credits</code> 是 null）。前端不擋的話那一列會印出「<code>+null 堂</code>」—— 看起來像資料壞了，不像「本來就沒有」。<br><br>☢️ <b>政府補助自己一欄、自己一個顏色。</b>混進現金或匯款，跟銀行對帳就<b>永遠差那幾百塊</b>；而且補助的帳齡是<b>幾個月</b>，跟匯款的幾天放在同一個「怎麼還沒到」清單裡，正常的撥款週期會被當成出事。<br><br><b>舊的 key 一個都沒拿掉</b>，只有新增 —— 用 <code>create or replace</code> 保留 GRANT（第 66 步的教訓）。<b>Excel 從 5 張工作表變 6 張</b>（多一張「應收未收」）。',
          ck:'挑一天同時有 GT 購課和一筆私人課，對帳報表那天的合計＝兩者相加，而且分得出哪一筆是哪一種。' },

        { n:92, t:'支出簿 —— 薪水以外的錢', where:'資料庫 ＋ 前端', done:true,
          summary:'房租、水電、器材、行銷、雜支，系統目前一毛都不知道',
          body:'系統現在只認得<b>一種支出：教練薪資</b>。房租、水電、器材、行銷、清潔、保險、軟體訂閱 —— 全部在系統外面。<br><br>一張表就夠：日期、科目、金額、付款方式、給誰、備註、收據照片（選填）。<b>不要一開始就做核銷流程和預算控管</b> —— 先讓錢有地方記。',
          warn:'☢️ <b>科目一開始就要定死，而且要少。</b>科目表一旦長出兩個意思相近的項目（「器材」和「設備」），以後每一份損益表都要先問「這兩個是不是同一件事」。<br><br>☢️ 這張表<b>只有負責人和財務看得到</b>，跟薪資報表同一道牆（<code>is_finance()</code>）。',
          note:'<b>2026-08-21 完成。</b>檔案：<code>db/63-expenses.sql</code>（新）、<code>line-prototype/expenses.html</code>（新）、<code>staff-tools.html</code>、<code>report.html</code>。<br><br><b>科目 9 個</b>（Jerec 提供實際支出結構後定案）：固定 —— 房租／管理費／健保費；變動 —— 通訊費（電話＋網路）／電費／水費／器材／雜支；另外一個是<b>備用金</b>。<br><br>☢️☢️ <b>備用金不是支出，是「內部提撥」。</b>提撥備用金是錢從公司的一個口袋進另一個口袋 —— <b>它還在公司手上</b>。記成支出的話，損益表每個月都會憑空少一筆，而那筆錢根本沒有離開公司。真正的支出是備用金<b>被花掉</b>的時候（那時候用對應的科目記）—— 提撥也算一次的話，同一筆錢算兩遍。所以科目多一個 <code>kind</code>：<code>fixed</code>／<code>variable</code>／<code>transfer</code>，而<b>損益只加總前兩種</b>。<br>☢️ 用<b>一個</b> kind 欄位，不是「kind ＋ 一個 is_expense 布林」—— 兩個欄位可以互相矛盾，一個不會。<br><br>☢️ <b>房租是一筆成本、三個付款方向。</b>Jerec 的房租總額實際上分成：匯款給房東 ＋ 二代健保補充保費（健保署規定，單次租金達 2 萬時按 2.11% 扣取）＋ 租金所得扣繳稅款（財政部規定，支付給境內個人的租金原則上按 10% 扣繳）。後兩筆是<b>暫代扣</b> —— 錢原本是房東的，公司先扣下來再替他繳給政府。<br>做成<b>一組三列</b>（<code>bundle</code>），理由是<b>三塊錢的付款對象與時間都不同</b>：記成一列的話，「扣繳稅款這個月還沒繳」這件事<b>系統永遠看不到</b>，而漏繳是會被罰的。<br>☢️ 代扣那兩列<b>不掛「稅費」科目</b> —— 那不是公司的稅，是房東的。掛過去房租會看起來變便宜、公司的稅會看起來變貴，兩邊都錯。<br>☢️ <code>bundle</code> 是 uuid 不是文字標籤 —— 用「房租」當標籤會把<b>每個月的房租全部黏成同一組</b>。<br>☢️ 作廢<b>整組一起作廢</b>。只廢一列會留下一筆金額對不起來的房租，而畫面上看起來完全正常。<br><br>☢️ <b>週期有兩種：每月、每兩個月。</b>電費水費都是兩個月一期，而且<b>兩邊的期別還錯開</b>。所以不是「複製上個月」，而是各自從<b>自己的上一期</b>往前推（每月推 1、每兩個月推 2），兩條週期就會各走各的。<br>☢️ 位移用 <code>interval</code> 不是加天數：1/31 加一個月 Postgres 會夾成 2/28，加 31 天會變成 3/3。<br>☢️ 複製出來的<b>付款日一律留空</b> —— 複製的是「這個月也要付這筆」，不是「這個月也已經付了」。防重複按靠 <code>copied_from</code>，<b>不是靠金額比對</b>（金額比對會把「這個月真的付了兩次」誤判成重複）。<br>☢️ bundle 對照表要<b>先去重再產 uuid</b>：<code>select distinct bundle, gen_random_uuid()</code> 是錯的 —— <code>gen_random_uuid()</code> 是 volatile，每一列都不一樣，distinct 永遠去不掉重複，結果房租三列會散成三筆。<br><br>☢️ <b>開了一條窄路可以就地改：只有「還沒付」的能改金額。</b>原則仍然是作廢＋重記，但變動帳單每一期金額都不同，複製過來不能改的話複製鈕等於沒用。付掉了就是既成事實，只能作廢重記。<br><br><b>畫面</b>（Jerec：「用簡約高效的設計不讓版面資訊過多」）：一組預設<b>折起來只顯示一列總額</b>，點開才看細項，展開時最上面一行淡紫說明什麼是代扣代繳。科目小計按<b>固定／變動／內部提撥</b>分三段。<br><br>☢️ <b>倉庫是公開的，所以這一頁與 SQL 裡不寫任何實際金額。</b>科目名稱、法規比例可以寫，金額一律不寫。<br><br><b>驗證</b>：資料庫六情境全過（一組三列、四道擋牆且<b>整組不落地</b>、產生下個月時每兩個月的只有到期的那一條會進來、重複按跳過、整組作廢、已付的不能改金額），測完整段回滾、正式資料 0 筆。前端用 Playwright 跑整頁：折疊、展開、拆三筆、擋牆之後<b>三筆內容都還在</b>。',
          ck:'把上個月的房租和水電記進去，第 94 步的損益表就會把它們扣掉。' },

        { n:93, t:'私人課完整流程 —— 預收真的扣得動', where:'資料庫 ＋ 前端', done:false,
          summary:'買了預付十堂、上了十堂課，餘額還是十堂',
          body:'私人課那一側只做了一半。<b>服務登記記得起來、抽成算得出來</b>（第 71、85 步），但<b>客人的卡從來沒有真的被扣過</b>：<ul><li>選「扣預收」的時候，<code>service_records</code> 記了，可是<b>沒有寫任何一筆扣堂</b></li><li>購課頁面寫死只賣 GT（<code>.eq(\'product\',\'GT\')</code>），所以 PT／PGT／企業包班根本買不了</li><li>客人自己看不到私人課還剩幾堂</li></ul>四件事一起做：<b>① <code>credit_ledger</code> 加一欄「從哪一張卡扣」② 服務登記選卡、真的扣 ③ 購課頁開放非 GT ④ 客人端看得到餘額</b>。',
          warn:'☢️☢️ <b>只做「開放購課」是最糟的做法。</b>那會做出一筆<b>只會漲、永遠不會跌的負債</b> —— 客人買了十堂，上完十堂，系統仍然認為他有十堂。第 95 步的損益表要把預收餘額當負債列出來，那個數字會從第一天就是錯的。<br><br>☢️ <b><code>plan_allocate</code> 現在只認產品別，不認人數。</b>扣的時候照「同產品最舊的那張」抽 —— 客人同時有一對一和一對二的卡就會抽錯張，而<b>兩張的每堂價值不一樣</b>（實收 ÷ 堂數）。抽錯 → 業績錯 → 抽成錯 → <b>薪水錯</b>，而且畫面上完全正常。<br>解法不是把猜的邏輯寫得更聰明，是<b>讓人在登記的當下直接指定哪一張</b> —— 猜測本身才是問題。<br><br>☢️ 這一步<b>必須排在損益表前面</b>。預收餘額是負債，負債是錯的，損益表就沒有意義。',
          ck:'幫一位客人買預付十堂 → 用服務登記上一堂並選「扣預收」→ 他的餘額變成九堂，而且方案對帳仍然對得上。' },

        { n:94, t:'月結 —— 結完就鎖起來', where:'資料庫 ＋ 前端', done:false,
          summary:'現在每一份報表都是「用今天的設定重算一次」',
          body:'☢️ <code>payroll_month()</code> 和 <code>finance_report()</code> 都是<b>即時重算</b>。今天改一筆加給的結束日、作廢一筆服務紀錄、補一筆帳本調整 —— <b>上個月的數字會跟著變，而且沒有任何地方記得它原本是多少</b>。<br><br>要的是一個動作：<b>「八月結了」</b>。結的時候把當下算出來的每一行<b>存成快照</b>，之後再打開就是讀快照，不是重算。順便記下<b>薪水實際發了沒、哪天發的、發了多少</b> —— 那是目前完全不存在的資訊。',
          warn:'☢️☢️ <b>沒有月結，就沒有「上個月」這個東西。</b>薪資單發給教練之後，只要有人動過任何設定，教練手上那張紙就跟系統對不起來 —— 而且<b>沒有人會知道是哪一次改的</b>。<br><br>☢️ <b>鎖起來不等於不能改。</b>要留一條「重開這個月」的路（誰重開的、為什麼、原本是多少），否則第一次結錯就死鎖。<b>但重開一定要留下痕跡</b>，不能安靜地重算掉。',
          ck:'按下「結算八月」之後，把某位教練的職級改掉，再打開八月的薪資報表 —— <b>數字一毛都不動</b>。' },
        // ☢️ 2026-08-22 調整順序：私人課完整流程從第 94 步移到第 93 步，月結往後。
        //    理由是【不能把還沒修好的數字鎖起來】—— 月結要存快照，
        //    而快照要存什麼取決於損益表要什麼，損益表要「預收餘額」。
        //    預收那一欄在私人課那一步之前是錯的，先結等於把錯的鎖住。

        { n:95, t:'損益表 —— 一個月一頁', where:'資料庫 ＋ 前端', done:false,
          summary:'收入 − 支出。前面五步都是為了這一頁',
          body:'一頁講完一個月：<b>收入</b>（GT／私人課／企業包班／外派，依第 89 步的決定認列）<b>減掉支出</b>（教練薪資 ＋ 第 92 步的支出簿）<b>等於這個月剩多少</b>。<br><br>再加兩個數字：<b>還欠客人幾堂</b>（預收餘額 —— 那是負債，不是收入）和<b>還沒收到的錢</b>（待入帳）。',
          warn:'☢️ <b>這一頁的每一個數字都必須點得進去看逐筆。</b>看不到明細的總數沒有人敢信，也查不出錯 —— 第 80 步（薪資報表）已經學過一次這件事。',
          ck:'打開任何一個月，看得到「收多少、花多少、剩多少」，而且每一格點下去都看得到是哪幾筆組成的。' }
      ]
    }
  ],

  /* ── 地平線：ERP（刻意不編號、不排序） ──────────────────────── */
  horizon: [
    { t:'系統使用說明書', d:'☢️ <b>Jerec 2026-08-22 指定：預約 ＋ 帳務全部完工後要寫。</b>'
      + '對象是<b>後來的人</b> —— 新教練、新櫃檯、下一任財務。他們不會讀這份路線圖，'
      + '也不會讀程式碼裡的註解，他們只會問「這個鍵按下去會怎樣」。<br>'
      + '☢️ 寫的時機是<b>第 94 步之後</b>，不能更早：現在每一步都還在改欄位和畫面，'
      + '提早寫等於寫一份三週後就對不上的文件，而<b>對不上的說明書比沒有說明書更糟</b> ——'
      + '人會照著做，然後怪自己。<br>'
      + '☢️ 分兩本，不要合成一本：<b>教練那本</b>（點名核銷、服務登記，五頁以內）'
      + '和<b>財務那本</b>（購課、對帳、支出、薪資、月結）。'
      + '教練不需要知道抽成怎麼算，財務不需要知道怎麼開課。' },
    { t:'金流與電子發票',   d:'☢️ 一碰這個就必須搬離 GitHub Pages —— 條款明確禁止，沒有討論空間。這是「錢真的在線上收」跟第七幕「帳算得清楚」之間的分界線' },
    { t:'教練排班',         d:'抽成薪資已經在第 78、84、85 步做完了（含 8 萬門檻累進）。這裡剩下的是<b>排班</b> —— 誰哪天上哪堂，目前還是人排' },
    { t:'場地租借 RT',       d:'第一階段只預留 product 欄位。真的要做時，關鍵是「場地佔用」要跟課排在同一本行事曆上，不然會撞場。它也會變成第七幕損益表上的第五條收入線' },
    { t:'出席與會員行為報表', d:'營收那一半在第七幕。這裡剩下的是「誰在流失、誰該續約」—— credit_ledger 本身就是一份消費行為紀錄' },
    { t:'會員關係與續約管理', d:'建在 customers 上。要先有上面那份報表，不然是憑感覺打電話' },
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

  // ☢️ 暫緩（defer:true）的步驟不算「前面還沒走到」——
  //    它們是刻意放著的。不跳過的話，紅色定位釘會永遠卡在第 36 步，
  //    而它後面五十幾步明明都做完了 —— 整張圖會變成假的。
  const deferList = allSteps.filter(s => !s.done && s.defer);
  const deferred  = deferList.length;

  // 目前這一步 = 第一個「還沒完成、而且沒有被暫緩」的
  const current  = allSteps.find(s => !s.done && !s.defer) || null;

  // 目前在哪一幕
  const currentActIndex = current
    ? R.acts.findIndex(a => a.steps.some(s => s.n === current.n))
    : R.acts.length - 1;

  // 每一幕的完成數
  const actStats = R.acts.map((a, i) => {
    const d    = a.steps.filter(s => s.done).length;
    const df   = a.steps.filter(s => !s.done && s.defer).length;
    const live = a.steps.length - df;      // 這一幕實際要走的步數（扣掉暫緩的）
    return {
      key: a.key, no: a.no, name: a.name,
      done: d, total: a.steps.length, defer: df,
      state: d === live ? 'done' : (i === currentActIndex ? 'current' : 'todo')
    };
  });

  // 上一個完成的步驟（給「剛走完的路」用）
  const lastDone = doneList.length ? doneList[doneList.length - 1] : null;
  // 下下一步（給「前方」用）
  const afterCurrent = current
    ? allSteps.find(s => !s.done && !s.defer && s.n > current.n) || null
    : null;

  return {
    total, done, deferred, deferList, current, lastDone, afterCurrent,
    currentActIndex, actStats,
    remaining: total - done - deferred - (current ? 1 : 0),
    pctDone:    (done / total) * 100,
    pctCurrent: current ? (1 / total) * 100 : 0,
    pctDefer:   (deferred / total) * 100
  };
})(window.FFF_ROADMAP);
