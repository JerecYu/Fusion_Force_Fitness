// ═══════════════════════════════════════════════════════════════
//  liff-bind.js — 綁定畫面
//
//  專案：FFF 預約系統（fff-platform）
//  對應路線圖第 32 步 · 2026-08-11
//
//  第 31 步認出「你是哪個 LINE 使用者」。
//  這一支問「那你是我們名單上的哪一位客人」。
//
//  規則（選 A）：查無此人就擋下來，不自動建客人。
//  建客人的路徑從頭到尾只有櫃檯一條。
//  但他填的資料會留進 signup_requests，而且畫面會直呼其名、
//  給他一個一按就能用 LINE 找到你的按鈕 —— 被擋不等於被丟掉。
// ═══════════════════════════════════════════════════════════════

(function () {
  'use strict';

  var FN_URL   = 'https://ubvbmksvvyzjzsmfxeby.supabase.co/functions/v1/line-bind';
  var OA_ID    = '@fff123';
  var TEL      = '(02) 2356-9462';
  var TEL_HREF = 'tel:0223569462';
  var HOURS    = '週一至週五 09:00–21:00　·　週六日 09:00–18:00';

  // 一按就開啟官方帳號聊天室，訊息幫他打好。
  // 這是純 LINE 網址，不碰 API、不需要任何權限。
  function oaLink(name, phone) {
    var msg = '我想報名團體課。' +
      (name ? '我是 ' + name : '') +
      (phone ? '，電話 ' + phone : '');
    return 'https://line.me/R/oaMessage/' +
      encodeURIComponent(OA_ID) + '/?' + encodeURIComponent(msg);
  }

  var el = {};
  function $(id) { return document.getElementById(id); }

  function grab() {
    el.box   = $('bindBox');
    el.phone = $('bdPhone');
    el.name  = $('bdName');
    el.go    = $('bdGo');
    el.msg   = $('bdMsg');
    return !!el.box;
  }

  function show(on) { if (el.box) el.box.hidden = !on; }

  function clearMsg() {
    if (!el.msg) return;
    el.msg.hidden = true;
    el.msg.className = 'bd-m';
    el.msg.innerHTML = '';
  }

  // kind: 'warn' 橘（他要動手改） / 'stop' 紅（他自己改不了，要找我們）
  function say(kind, html) {
    if (!el.msg) return;
    el.msg.className = 'bd-m bd-' + kind;
    el.msg.innerHTML = html;
    el.msg.hidden = false;
  }

  var esc = function (s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  };

  // 「找不到你」的畫面。這一段是整個第 32 步最重要的文案 ——
  // 被擋下來的人在這裡決定要不要繼續往下走。
  function notFound(name, phone) {
    say('stop',
      '<b>' + esc(name) + '，我們的名單裡還沒有你的資料。</b><br>' +
      '你填的資料我們已經收到了，上班後會與你聯絡。<br>' +
      '<span class="bd-hint">如果你本來就是會員：手機要跟櫃檯登記的<b>完全一樣</b>；'+
      '姓名打<b>中文全名</b>或我們平常叫你的<b>英文名／綽號</b>都可以。</span>' +
      '<a class="bd-oa" href="' + esc(oaLink(name, phone)) + '">用 LINE 告訴我們</a>' +
      '<span class="bd-hint">或來電 <a href="' + TEL_HREF + '">' + TEL + '</a>　·　' + HOURS + '</span>');
  }

  var REASON = {
    bad_phone: function () {
      say('warn', '手機號碼看起來不對。請填 09 開頭的 10 碼。');
    },
    bad_name: function () {
      say('warn', '請填姓名。');
    },
    inactive: function (n, p) {
      say('stop',
        '<b>這個帳號目前是停用狀態。</b><br>' +
        '請與櫃檯確認。' +
        '<a class="bd-oa" href="' + esc(oaLink(n, p)) + '">用 LINE 告訴我們</a>' +
        '<span class="bd-hint">或來電 <a href="' + TEL_HREF + '">' + TEL + '</a></span>');
    },
    already_bound: function (n, p) {
      say('stop',
        '<b>這筆資料已經綁在另一個 LINE 帳號上了。</b><br>' +
        '如果那不是你的，請讓我們幫你處理 —— 我們不會自動換掉，因為換錯了會讓別人看到你的紀錄。' +
        '<a class="bd-oa" href="' + esc(oaLink(n, p)) + '">用 LINE 告訴我們</a>' +
        '<span class="bd-hint">或來電 <a href="' + TEL_HREF + '">' + TEL + '</a></span>');
    },
    line_already_used: function (n, p, data) {
      say('stop',
        '<b>你的 LINE 已經綁定「' + esc(data && data.boundName) + '」了。</b><br>' +
        '一個 LINE 帳號只能對應一位客人。要換人請找櫃檯。' +
        '<a class="bd-oa" href="' + esc(oaLink(n, p)) + '">用 LINE 告訴我們</a>');
    },
    not_found: notFound
  };

  function busy(on) {
    if (!el.go) return;
    el.go.disabled = on;
    el.go.textContent = on ? '確認中…' : '綁定';
  }

  async function submit() {
    var name  = (el.name.value || '').trim();
    var phone = (el.phone.value || '').trim();

    clearMsg();
    if (!phone) { say('warn', '請填手機號碼。'); el.phone.focus(); return; }
    if (!name)  { say('warn', '請填姓名。');     el.name.focus();  return; }

    // 必須先有第 31 步發的憑證，才有資格問「我是誰」
    var sess = null;
    try {
      var got = await window.fffDB.auth.getSession();
      sess = got && got.data && got.data.session;
    } catch (e) { /* 下面統一處理 */ }

    if (!sess) {
      say('warn', '身分還沒辨識完成，請重新整理這一頁再試。');
      return;
    }

    busy(true);
    try {
      var res = await fetch(FN_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + sess.access_token
        },
        body: JSON.stringify({ phone: phone, name: name })
      });
      var data = await res.json().catch(function () { return {}; });

      if (data.ok) {
        var A = window.FFF_AUTH;
        if (A) { A.bound = true; A.displayName = data.displayName || name; }
        show(false);
        if (window.FFF_AUTH_PAINT) window.FFF_AUTH_PAINT('bound');
        return;
      }

      var fn = REASON[data.reason];
      if (fn) fn(name, phone, data);
      else if (data.error) say('warn', '伺服器回了看不懂的錯誤（' + esc(data.error) + '），請稍後再試。');
      else say('warn', '沒有成功，請再試一次。');
    } catch (e) {
      say('warn', '連不上伺服器，請確認網路後再試一次。');
    } finally {
      busy(false);
    }
  }

  function boot() {
    if (!grab()) return;
    el.go.addEventListener('click', submit);
    el.name.addEventListener('keydown', function (ev) { if (ev.key === 'Enter') submit(); });
    el.phone.addEventListener('keydown', function (ev) { if (ev.key === 'Enter') el.name.focus(); });

    // liff-auth.js 辨識完之後才知道要不要顯示這張卡
    var A = window.FFF_AUTH;
    if (!A || !A.ready) return;
    A.ready.then(function () {
      show(A.state === 'unbound');
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
