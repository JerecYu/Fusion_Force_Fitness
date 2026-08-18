// ═══════════════════════════════════════════════════════════════
//  liff-auth.js — 在 LINE 裡辨識身分
//
//  專案：FFF 預約系統（fff-platform）
//  對應路線圖第 31 步 · 2026-08-11
//
//  這支只做一件事：把「打開這個網頁的 LINE 使用者」
//  換成一張 Supabase 憑證，讓資料庫自己認得他是誰。
//
//  ❌ 它不會拿 LINE userId 去查任何資料。
//     前端說自己是誰一律不算數 —— 那是 line-auth 這支 Edge Function
//     的工作，它會把憑證拿去問 LINE 官方「這張是真的嗎」。
//     之後所有查詢靠 auth.uid()，那是資料庫自己認的。
//
//  ⚠️ 這支不會擋住課表。
//     沒在 LINE 裡開、沒登入、驗證失敗 —— 課表通通照常顯示。
//     身分只影響「能不能訂」，不影響「能不能看」。
//     如果哪天這支壞了，客人還是看得到今天有什麼課。
// ═══════════════════════════════════════════════════════════════

(function () {
  'use strict';

  // LIFF ID：公開資訊，會出現在網址列裡，不是密碼
  var LIFF_ID = '2011063116-QOxXN30h';
  var FN_URL  = 'https://ubvbmksvvyzjzsmfxeby.supabase.co/functions/v1/line-auth';

  // 網路卡住時的保險。沒有這個，狀態列會永遠停在「辨識中…」，
  // 而「一直轉圈」比「明白說失敗」更難查。
  var TIMEOUT_MS = 12000;

  // ── 對外的門牌 ───────────────────────────────────────────────
  //  第 32、33 步都靠這個物件。用法：
  //    await FFF_AUTH.ready;
  //    if (FFF_AUTH.state === 'bound') { ...可以訂課... }
  //
  //  四種狀態，只有 bound 能訂課：
  //    browsing  沒在 LINE 裡開、或還沒登入 → 只能看
  //    unbound   已辨識，但還沒綁手機       → 走第 32 步的綁定畫面
  //    bound     已辨識，而且綁過手機       → 可以訂課
  //    error     途中出事                   → 只能看，並顯示錯誤碼
  var AUTH = window.FFF_AUTH = {
    state: 'checking',
    bound: false,
    displayName: null,
    error: null,
    ready: null,
    // 頁面自己註冊：離開一陣子再切回來、身分確認還在的時候，資料要怎麼重讀。
    //   window.FFF_AUTH.onResume = function () { ...重讀這一頁的資料... };
    // ☢️ 這裡【故意不做 location.reload()】—— 整頁重載會把教練打到一半的
    //    表單、開著的沖銷原因欄一起洗掉。只重讀資料，畫面上的輸入留著。
    onResume: null,

    /* ☢️ 2026-08-18（第 59 步）canLogin —— state === 'browsing' 有三種原因，
          但只有一種救得回來：

            ① LINE 的程式沒載進來（CDN 被擋、沒網路）  → 救不回來
            ② liff.init() 失敗（LIFF ID 或網域設錯）    → 救不回來
            ③ init 成功，只是【還沒登入】                → ★ 按一下就能登入

          三種在畫面上長得一模一樣。沒有這個旗標的話，頁面只能一律說
          「要從 LINE 裡面開」—— 對第 ③ 種是錯的，而第 ③ 種正是【桌機】。

          ☢️ 所以這不是「新功能」，是把一條本來就通、只是沒有入口的路打開。 */
    canLogin: false
  };

  // 給頁面呼叫的登入。回傳 false 代表現在按也沒用（上面的 ①②）。
  // ☢️ redirectUri 要帶 location.href，否則 LINE 會把人送回 LIFF 的
  //    Endpoint URL 首頁，教練登入完會發現自己站在別的頁面上。
  AUTH.login = function () {
    if (!AUTH.canLogin || !window.liff || !window.liff.login) return false;
    try { window.liff.login({ redirectUri: location.href }); return true; }
    catch (e) { return false; }
  };

  // ☢️ ready 必須在這裡就存在，不能等 DOMContentLoaded 才建立。
  //    別的腳本（liff-bind.js、訂課那段）是在解析階段就跑的，
  //    那時如果 ready 還是 null，它們的 if (A.ready) 會整段跳過 ——
  //    不會報錯，只是永遠不知道身分辨識完成了。
  var markReady;
  AUTH.ready = new Promise(function (resolve) { markReady = resolve; });

  // ── 狀態列的文案 ─────────────────────────────────────────────
  var BAND = {
    checking: { cls: 'ab-wait', icon: '◌', text: '正在辨識身分…' },
    browsing: { cls: 'ab-off',  icon: '○', text: '瀏覽模式　·　在 LINE 裡開啟才能訂課' },
    unbound:  { cls: 'ab-warn', icon: '●', text: '已辨識　·　還沒綁定手機' },
    bound:    { cls: 'ab-ok',   icon: '●', text: '已辨識' },
    error:    { cls: 'ab-err',  icon: '✕', text: '身分辨識失敗' }
  };

  var elBand, elIcon, elText, elSub;

  function grab() {
    elBand = document.getElementById('authBand');
    if (!elBand) return false;
    elIcon = elBand.querySelector('.ab-i');
    elText = elBand.querySelector('.ab-t');
    elSub  = elBand.querySelector('.ab-s');
    return true;
  }

  // note = 灰色小字，只寫給人看的補充；code = 錯誤代碼，寫給我看的
  function paint(state, note, code) {
    AUTH.state = state;
    AUTH.error = code || null;
    if (!elBand && !grab()) return;

    var b = BAND[state] || BAND.error;
    elBand.className = 'ab ' + b.cls;
    elIcon.textContent = b.icon;

    var main = b.text;
    if (state === 'bound' && AUTH.displayName) main = '已辨識　·　' + AUTH.displayName;
    elText.textContent = main;

    var sub = note || '';
    if (code) sub = (sub ? sub + '　' : '') + '（' + code + '）';
    elSub.textContent = sub;
    elSub.hidden = !sub;

    elBand.hidden = false;
  }

  // 給第 32 步的綁定畫面用：綁定成功之後，把狀態列從橘色改成綠色。
  // 只開放這一個動作，不把整個內部狀態掛出去。
  window.FFF_AUTH_PAINT = function (state, note, code) { paint(state, note, code); };

  // 「用 LINE 登入」按鈕。只在 LIFF 起得來、但人還沒登入時出現。
  // 在 LINE App 裡永遠不會看到它 —— 那邊是自動登入的。
  //
  // ☢️ 2026-08-18 Jerec 在桌機上打開後台，畫面停在「不是從 LINE 開的」，
  //    沒有任何可以按的東西。查出來原因是這一行：這顆鍵掛在 #authBand 上，
  //    而【三個教練頁面都沒有 #authBand】（只有 GT-booking.html 有）——
  //    elBand 是 null，第一行直接 return，這顆鍵從來沒有機會出現過。
  //
  //    ☢️ 它不會報錯，程式碼看起來也完全正常 —— 教訓是「功能存在」和
  //       「功能接得到畫面」是兩件事，只讀程式碼分不出來。
  //
  //    所以真正的登入動作搬到上面的 AUTH.login()，任何頁面都叫得到；
  //    這一顆只是「頁面剛好有 authBand 就順便給你」的便利品。
  function offerLogin() {
    if (!elBand || elBand.querySelector('.ab-b')) return;
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'ab-b';
    btn.textContent = '用 LINE 登入';
    btn.addEventListener('click', function () {
      if (!AUTH.login()) paint('error', '無法開啟 LINE 登入', 'login_unavailable');
    });
    elBand.appendChild(btn);
  }

  // 換一張 LINE 憑證。
  // ☢️ 一定要防迴圈：萬一換回來的還是不被接受（例如 channel 設定壞了），
  //    沒有這道保險的話會變成「開啟 → 跳轉 → 開啟 → 跳轉」，
  //    使用者連錯誤訊息都看不到，只會覺得手機壞了。
  //    sessionStorage 的值只活在這個分頁，關掉再開就重新算一次。
  var RELOGIN_KEY = 'fff_relogin_once';
  function relogin(why) {
    var tried = false;
    try { tried = sessionStorage.getItem(RELOGIN_KEY) === '1'; } catch (e) {}
    if (tried || !window.liff || !window.liff.login) {
      paint('error', '身分憑證過期了，請關掉這一頁重新打開', why || 'stale_id_token');
      return 'stop';
    }
    try { sessionStorage.setItem(RELOGIN_KEY, '1'); } catch (e) {}
    paint('checking', '憑證過期了，正在重新取得…');
    try {
      window.liff.login({ redirectUri: location.href });
    } catch (e) {
      paint('error', '無法重新取得憑證，請關掉這一頁重新打開', String(e));
    }
    return 'stop';       // 頁面正要跳走，後面不用再跑
  }

  // ── 主流程 ───────────────────────────────────────────────────
  function run() {
    return Promise.resolve()
      // ① LIFF SDK 有載進來嗎
      .then(function () {
        if (!window.liff) {
          paint('browsing', 'LINE 的程式沒載進來');
          return 'stop';
        }
        return window.liff.init({ liffId: LIFF_ID }).catch(function (e) {
          paint('browsing', 'LINE 初始化失敗', (e && (e.code || e.message)) || 'liff_init_failed');
          return 'stop';
        });
      })

      // ② 登入了嗎。沒登入就停在瀏覽模式，不強迫跳轉 ——
      //    這頁同時也是對外的公開課表，不能因為沒登入就看不到。
      .then(function (r) {
        if (r === 'stop') return 'stop';
        if (!window.liff.isLoggedIn()) {
          // ☢️ 只有走到這裡才代表「按一下就能登入」。
          //    上面兩個 paint('browsing') 是【真的沒救】，不能設這個旗標。
          AUTH.canLogin = true;
          paint('browsing');
          offerLogin();
          return 'stop';
        }
        return null;
      })

      // ③ 拿 ID Token（LINE 用私鑰簽章過的憑證，前端偽造不出來）
      //
      // ☢️ 2026-08-18 Jerec：「教練後台若一段時間沒操作，就逾時無法進入」。
      //    根因在這裡：liff.getIDToken() 回的是【登入當下拿到的那一張】，
      //    LIFF 不會自動幫它續期。放著幾十分鐘之後那張就過期了，
      //    第 ④ 段拿去問 LINE 會被打回票，畫面就停在「伺服器不認這張憑證」。
      //    ☢️ 而且它長得像「系統壞了」，其實只是「憑證舊了」。
      //
      //    解法：換一張。liff.login() 在 LINE App 裡是靜默的，
      //    使用者只會看到畫面閃一下就回來。
      .then(function (r) {
        if (r === 'stop') return 'stop';
        var t = window.liff.getIDToken();
        if (!t) return relogin('no_id_token');
        return t;
      })

      // ④ 送給 Edge Function 驗。驗過才會拿到一張 Supabase 入場券。
      .then(function (idToken) {
        if (idToken === 'stop') return 'stop';
        return fetch(FN_URL, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ idToken: idToken })
        }).then(function (res) {
          return res.json().catch(function () { return {}; }).then(function (data) {
            if (!res.ok || !data.ok) {
              var why = (data && data.error) || ('HTTP ' + res.status);
              // 憑證過期／不被接受 → 換一張再來（只換一次，見 relogin）
              if (res.status === 401 || /verify|token/i.test(String(why))) {
                return relogin(why);
              }
              paint('error', '伺服器不認這張憑證', why);
              return 'stop';
            }
            return data;
          });
        }, function (e) {
          paint('error', '連不上伺服器', String(e && e.message || e));
          return 'stop';
        });
      })

      // ⑤ 把入場券換成正式 session。
      //    換完之後，資料庫查詢就靠 auth.uid() —— 那才是真正的身分。
      .then(function (data) {
        if (data === 'stop') return;
        if (!window.fffDB) {
          paint('error', '資料庫連線沒建立', 'no_fffDB');
          return;
        }
        return window.fffDB.auth
          .verifyOtp({ token_hash: data.tokenHash, type: 'magiclink' })
          .then(function (res) {
            if (res.error) {
              paint('error', '換憑證失敗', res.error.message);
              return;
            }
            // 這一輪成功了 → 把「已經換過一張」的記號清掉，
            // 否則下次真的過期時就不會再幫他換了。
            try { sessionStorage.removeItem(RELOGIN_KEY); } catch (e) {}
            AUTH.bound = !!data.bound;
            AUTH.displayName = data.displayName || null;
            paint(data.bound ? 'bound' : 'unbound',
                  data.bound ? '' : '下一步會請你填手機號碼');
          });
      })

      .catch(function (e) {
        paint('error', '', String(e && e.message || e));
      });
  }


  /* ══ 切回來就自己接上 ═══════════════════════════════════════
     ☢️ 2026-08-18 Jerec：「可否延長時間至無限？或是重新切換至後台網頁時
        自動重新整理，這樣就不用再跳回 line 聊天室畫面，還要多點擊一次網址」。

     ☢️ 先講【做不到】的那一半，免得以為漏做：
        · 「常駐手機背景」網頁做不到。頁面活在 LINE 的內建瀏覽器裡，
          記憶體不夠時要不要把它殺掉是 Android 和 LINE 決定的，
          網頁沒有任何 API 可以要求自己被留著。
        · 「時間延長到無限」也不該做。真正會過期的有兩張票：
          LINE 的身分憑證、和我們自己的登入票。把它們設成永不過期，
          等於任何人撿到這支手機就永遠是教練 —— 而這一頁按得到錢。

     ☢️ 所以做的是【過期了就自己換一張】，使用者不需要知道有這回事：
        ① 離開超過 5 分鐘再切回來 → 自動檢查登入票還在不在
        ② 票要過期了 → 靜靜換一張新的
        ③ 換得成 → 呼叫這一頁註冊的 onResume()，把資料重讀一次
        ④ 換不成 → 才顯示錯誤，並給一顆「重新載入」

     ☢️ 第 ③ 步【故意不做整頁重載】。教練可能正打到一半的新增客人表單、
        或開著沖銷的原因欄 —— 整頁重載會把那些一起洗掉。
        只重讀資料，畫面上打的字留著。
     ═══════════════════════════════════════════════════════════ */
  var STALE_MS = 5 * 60 * 1000;      // 離開多久才需要重新確認
  var hiddenAt = 0;
  var resuming = false;

  // 登入票還有效嗎？快過期的話先續一次。
  function ensureSession() {
    if (!window.fffDB) return Promise.resolve(false);
    return window.fffDB.auth.getSession()
      .then(function (r) {
        var ss = r && r.data && r.data.session;
        if (!ss) return false;
        // 還剩不到 2 分鐘就當作要過期了，先續再說 —— 不要等它真的死掉
        var left = (ss.expires_at || 0) * 1000 - Date.now();
        if (left > 120000) return true;
        return window.fffDB.auth.refreshSession()
          .then(function (r2) { return !!(r2 && r2.data && r2.data.session); },
                function () { return false; });
      }, function () { return false; });
  }

  function resume() {
    // 本來就沒登入（純瀏覽模式）就不用管
    if (resuming || (AUTH.state !== 'bound' && AUTH.state !== 'unbound')) return;
    resuming = true;
    paint('checking', '正在重新連線…');

    ensureSession()
      .then(function (ok) {
        if (ok) return true;
        // 登入票沒了 → 整條身分鏈重跑一次（不重載頁面）
        return run().then(function () {
          return AUTH.state === 'bound' || AUTH.state === 'unbound';
        });
      })
      .then(function (ok) {
        resuming = false;
        if (!ok) { offerReload(); return; }
        paint(AUTH.bound ? 'bound' : 'unbound',
              AUTH.bound ? '' : '下一步會請你填手機號碼');
        if (typeof AUTH.onResume === 'function') {
          try { AUTH.onResume(); } catch (e) {}
        }
      })
      .catch(function () { resuming = false; offerReload(); });
  }

  // 真的接不回來時的最後一步。☢️ 不自動重載 —— 這時候多半有東西沒存，
  //    要讓人自己決定什麼時候按。
  function offerReload() {
    paint('error', '連線中斷了', 'resume_failed');
    if (!elBand || elBand.querySelector('.ab-b')) return;
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'ab-b';
    btn.textContent = '重新載入';
    btn.addEventListener('click', function () { location.reload(); });
    elBand.appendChild(btn);
  }

  document.addEventListener('visibilitychange', function () {
    if (document.hidden) { hiddenAt = Date.now(); return; }
    if (!hiddenAt || Date.now() - hiddenAt < STALE_MS) { hiddenAt = 0; return; }
    hiddenAt = 0;
    resume();
  });
  // ☢️ iOS 從「上一頁」回來時走的是 pageshow(persisted)，不會發 visibilitychange。
  window.addEventListener('pageshow', function (e) {
    if (e.persisted) resume();
  });

  function boot() {
    grab();
    paint('checking');

    var timer;
    var guard = new Promise(function (resolve) {
      timer = setTimeout(function () {
        if (AUTH.state === 'checking') paint('error', '等太久了，請重開一次', 'timeout');
        resolve();
      }, TIMEOUT_MS);
    });

    Promise.race([run().then(function () { clearTimeout(timer); }), guard])
      .then(markReady, markReady);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
