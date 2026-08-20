/* ═══════════════════════════════════════════════════════════════════
   push-optin.js —— 「開啟課程異動通知」那顆按鈕

   專案：FFF 預約系統（fff-platform）· 第 81 步 · 2026-08-20

   ☢️☢️ 為什麼要客人自己按一下，不能系統自動開
      customers.line_user_id 來自 LINE Login channel（2011063116），
      推播要的是官方帳號 Messaging API channel（2009245280）的編號。
      兩個 channel 在【不同的 Provider】，而 LINE 的 userId 是以 provider
      為單位發的 —— 同一個人在兩邊是兩組完全不同的號碼。
      channel 不能換 provider（官方文件寫死），所以拿不到第二組編號的
      唯一辦法，就是請他主動傳一則訊息給官方帳號。

      流程：按鈕 → 跟資料庫要一組 30 分鐘的一次性短碼
           → 開啟官方帳號聊天室、訊息已經預填好
           → 他按送出 → line-hook 收到「userId ＋ 短碼」→ 對起來

   ☢️ 這一支【只在已綁定而且還沒開通知】的時候出現。
      已經開好的人再看到這顆按鈕，會以為自己沒開成功。

   ☢️ 短碼是【預填】的，不叫客人手打。手打六碼的失敗率會殺掉整個流程。
   ═══════════════════════════════════════════════════════════════════ */

(function () {
  'use strict';

  var OA_ID = '@fff123';
  var PREFIX = '開啟課程異動通知';

  var el = {};
  function $(id) { return document.getElementById(id); }

  function grab() {
    el.box = $('pushBox');
    el.go  = $('pbGo');
    el.msg = $('pbMsg');
    return !!el.box;
  }

  function say(t, bad) {
    if (!el.msg) return;
    el.msg.hidden = !t;
    el.msg.textContent = t || '';
    el.msg.style.color = bad ? '#A4211A' : '';
  }

  function show(on) { if (el.box) el.box.hidden = !on; }

  // ☢️ 一按就開啟官方帳號聊天室，訊息幫他打好。
  //    這是純 LINE 網址，不碰 API、不需要任何權限。（同 liff-bind.js）
  function oaLink(code) {
    var msg = PREFIX + ' ' + code;
    return 'https://line.me/R/oaMessage/' +
      encodeURIComponent(OA_ID) + '/?' + encodeURIComponent(msg);
  }

  var CHECKING = false;

  // 已經開好了嗎？開好了就把整張卡收起來。
  function refresh() {
    if (CHECKING) return;
    var A = window.FFF_AUTH;
    if (!A || A.state !== 'bound' || !window.fffDB) { show(false); return; }
    CHECKING = true;
    window.fffDB.from('customers').select('push_user_id').limit(1)
      .then(function (r) {
        CHECKING = false;
        // ☢️ 錯誤和「沒有資料」在 supabase-js 裡都會拿到空的，意思相反。（規則 14）
        //    讀不到就【不要】把卡打開 —— 對一個已經開好的人再喊一次「快去開」，
        //    比什麼都不顯示更糟。
        if (r.error || !r.data || !r.data.length) { show(false); return; }
        show(!r.data[0].push_user_id);
      }, function () { CHECKING = false; show(false); });
  }

  function click() {
    if (!window.fffDB) return;
    el.go.disabled = true;
    var old = el.go.textContent;
    el.go.textContent = '準備中…';
    say('');

    window.fffDB.rpc('issue_push_code').then(function (r) {
      el.go.disabled = false;
      el.go.textContent = old;

      if (r.error) { say('開不起來：' + (r.error.message || ''), true); return; }
      var d = r.data || {};
      if (!d.ok) { say(d.msg || '要先完成綁定才能開啟通知', true); return; }
      if (d.already) { show(false); return; }

      // ☢️ 這裡【一定】要用 location.href，不要 window.open。
      //    LIFF 視窗裡 window.open 會被擋掉，而且不會有任何錯誤 ——
      //    按鈕看起來就是沒反應。
      say('開啟 LINE 之後，那則訊息已經打好了，你只要按送出。');
      window.location.href = oaLink(d.code);
    }, function (e) {
      el.go.disabled = false;
      el.go.textContent = old;
      say('開不起來：' + String(e && e.message || e), true);
    });
  }

  function boot() {
    if (!grab()) return;
    el.go.onclick = click;

    if (!window.FFF_AUTH || !window.FFF_AUTH.ready) return;
    window.FFF_AUTH.ready.then(refresh, function () {});

    // ☢️ 從 LINE 聊天室切回來的時候要再看一次 —— 那正是他剛按完送出的時刻。
    //    liff-auth.js 的 onResume 已經被別的頁面用掉了，所以這裡自己接
    //    visibilitychange，不去搶那個位子。
    document.addEventListener('visibilitychange', function () {
      if (!document.hidden) setTimeout(refresh, 400);
    });
    window.addEventListener('pageshow', function () { setTimeout(refresh, 400); });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
