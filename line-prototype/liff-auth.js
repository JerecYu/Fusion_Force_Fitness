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
    ready: null
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
  function offerLogin() {
    if (!elBand || elBand.querySelector('.ab-b')) return;
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'ab-b';
    btn.textContent = '用 LINE 登入';
    btn.addEventListener('click', function () {
      try { window.liff.login(); } catch (e) { paint('error', '無法開啟 LINE 登入', String(e)); }
    });
    elBand.appendChild(btn);
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
          paint('browsing');
          offerLogin();
          return 'stop';
        }
        return null;
      })

      // ③ 拿 ID Token（LINE 用私鑰簽章過的憑證，前端偽造不出來）
      .then(function (r) {
        if (r === 'stop') return 'stop';
        var t = window.liff.getIDToken();
        if (!t) {
          paint('error', '拿不到 LINE 憑證，請重開一次', 'no_id_token');
          return 'stop';
        }
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
              paint('error', '伺服器不認這張憑證', (data && data.error) || ('HTTP ' + res.status));
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
