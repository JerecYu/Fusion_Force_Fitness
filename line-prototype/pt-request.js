// ═══════════════════════════════════════════════════════════════
//  pt-request.js — 私人課「送出需求」
//
//  專案：FFF 預約系統（fff-platform）
//  對應路線圖第 34 步 · 2026-08-11
//
//  ☢️ 私人課不是預約，是需求。
//     客人送出的是「我想上課，時間大概這樣」，教練聯繫後才敲定。
//     所以這支不會碰任何課堂名額，也不會扣任何堂數 ——
//     它只寫進 pt_requests 這張需求單。
//
//  兩條路：
//   ① 已經在 LINE 裡綁定過的會員 → 直接寫進 pt_requests
//   ② 還沒綁定的人（包含新客）→ 用 LINE 訊息送出，內容一樣完整
//      不強迫他先綁定 —— 這是張招生的頁，不是會員專區。
//
//  PT-booking.html 和 PGT-booking.html 兩頁共用這一支。
//  頁面只負責收集自己的欄位，然後呼叫 window.FFF_SEND_REQUEST(...)。
// ═══════════════════════════════════════════════════════════════

(function () {
  'use strict';

  var OA_ID    = '@fff123';
  var TEL      = '(02) 2356-9462';
  var TEL_HREF = 'tel:0223569462';
  var HOURS    = '週一至週五 09:00–21:00　·　週六日 09:00–18:00';

  var esc = function (s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  };

  // 教練的 id 要跟資料庫對得起來。頁面上寫的是「VC」這種對外名字，
  // 資料庫的 uuid 不能寫死在前端 —— 換人或重建就對不上了。
  var coachMap = null;
  async function loadCoaches() {
    if (coachMap) return coachMap;
    coachMap = {};
    try {
      var r = await window.fffDB.from('public_coaches').select('id,display_name');
      if (r.error) throw r.error;
      (r.data || []).forEach(function (c) { coachMap[c.display_name] = c.id; });
    } catch (e) {
      console.warn('[pt-request] 讀不到教練名單，指定教練會存成「未指定」：', (e && e.message) || e);
    }
    return coachMap;
  }

  function lineLink(text) {
    return 'https://line.me/R/oaMessage/' +
      encodeURIComponent(OA_ID) + '/?' + encodeURIComponent(text);
  }

  // 給 LINE 訊息用的純文字版本。內容跟寫進資料庫的完全一樣。
  function asText(req) {
    var L = ['我想預約' + req.productLabel + '。'];
    req.rows.forEach(function (r) { L.push(r[0] + '：' + r[1]); });
    if (req.name)  L.push('姓名：' + req.name);
    if (req.phone) L.push('電話：' + req.phone);
    if (req.note)  L.push('備註：' + req.note);
    return L.join('\n');
  }

  function cardHtml(req) {
    return req.rows.map(function (r) {
      return '<div class="rw"><span class="k">' + esc(r[0]) +
             '</span><span class="v">' + esc(r[1]) + '</span></div>';
    }).join('');
  }

  // 成功／請用 LINE 送出，共用同一個蓋板，只換文字和主要按鈕
  function openOverlay(opt) {
    var ov = document.getElementById('ov');
    var h  = document.getElementById('ovTitle');
    var p  = document.getElementById('ovSub');
    var a  = document.getElementById('ovAct');
    var ic = document.getElementById('ovIc');
    // ☢️ 圖示不能永遠是勾。失敗的時候顯示勾，等於畫面在說謊。
    if (ic) ic.textContent = opt.icon || '✓';
    if (h) h.textContent = opt.title;
    if (p) p.innerHTML = opt.sub;
    if (a) {
      a.textContent = opt.actText;
      a.setAttribute('href', opt.actHref);
      a.className = 'btn ' + (opt.actClass || 'btn-1');
    }
    document.getElementById('ovCard').innerHTML = opt.card;

    // ☢️ 用電腦開的人按「用 LINE 送出」會被丟到 LINE 官網 ——
    //    桌機沒有 LINE App 可以接手那個網址。他填的東西就這樣蒸發。
    //    所以永遠再給一條不依賴 LINE 的退路：複製內容。
    var copy = document.getElementById('ovCopy');
    if (!copy && opt.copyText) {
      copy = document.createElement('button');
      copy.id = 'ovCopy';
      copy.type = 'button';
      copy.className = 'btn btn-3';
      copy.style.marginTop = '10px';
      document.getElementById('ovCard').insertAdjacentElement('afterend', copy);
    }
    if (copy) {
      copy.hidden = !opt.copyText;
      if (opt.copyText) {
        copy.textContent = '複製內容（用電腦的話按這個）';
        copy.onclick = function () {
          var done = function () {
            copy.textContent = '已複製，貼到 LINE 或 Email 給我們';
          };
          if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(opt.copyText).then(done, function () { legacy(); });
          } else { legacy(); }
          function legacy() {
            var ta = document.createElement('textarea');
            ta.value = opt.copyText;
            ta.style.position = 'fixed'; ta.style.opacity = '0';
            document.body.appendChild(ta); ta.select();
            try { document.execCommand('copy'); done(); } catch (e) { /**/ }
            document.body.removeChild(ta);
          }
        };
      }
    }

    ov.classList.add('show');
  }

  function fail(msg) {
    openOverlay({
      title: '沒有送出',
      sub: esc(msg) + '<br>你可以直接用 LINE 或電話告訴我們。<br>' +
           '<a href="' + TEL_HREF + '">' + TEL + '</a>　·　' + HOURS,
      card: '',
      icon: '!',
      actText: '用 LINE 告訴我們',
      actHref: lineLink('我想預約私人課，但網頁送不出去。'),
      actClass: 'btn-1'
    });
  }

  // ── 頁面呼叫這一支 ──────────────────────────────────────────
  window.FFF_SEND_REQUEST = async function (req) {
    var btn = document.getElementById('bSend');
    var old = btn ? btn.innerHTML : '';
    if (btn) { btn.disabled = true; btn.textContent = '送出中…'; }

    try {
      // 等身分辨識跑完。沒有 liff-auth.js 的話（例如單獨開這頁測試）
      // 就當作沒綁定，走 LINE 那條路 —— 一樣送得出去。
      if (window.FFF_AUTH && window.FFF_AUTH.ready) { await window.FFF_AUTH.ready; }
      var bound = !!(window.FFF_AUTH && window.FFF_AUTH.state === 'bound');

      if (!bound) {
        openOverlay({
          title: '最後一步：用 LINE 送出',
          sub: '你的需求已經整理好了，按下面的按鈕就會開啟聊天室，<br>' +
               '訊息已經幫你打好，按送出即可。<br>' +
               '<span style="opacity:.7">用電腦的話按不開聊天室 —— ' +
               '改按「複製內容」，或來電 <a href="' + TEL_HREF + '">' + TEL + '</a><br>' +
               '營業時間 ' + HOURS + '</span>',
          card: cardHtml(req),
          icon: '›',
          copyText: asText(req),
          actText: '用 LINE 送出需求',
          actHref: lineLink(asText(req)),
          actClass: 'btn-1'
        });
        return;
      }

      // ── 已綁定：直接寫進需求單 ──────────────────────────────
      // ☢️ 一定要自己加 .eq('auth_user_id', …)，不能只靠 RLS 把範圍縮到一列。
      //    對一般客人來說 RLS 只會回一列，maybeSingle() 剛好成立；
      //    但【員工同時也是客人】的時候，「員工可讀全部客人」讓他拿到 83 列，
      //    maybeSingle() 直接報錯 → 需求單送不出去。
      //    ☢️ 千萬不要用 .limit(1) 來「修」這個問題 —— 那會讓員工用
      //       【某一個隨機客人】的名義送出需求單。
      //    （GT-booking.html 2026-08-16 修過同一隻，這裡是漏網的第二處。）
      var u   = await window.fffDB.auth.getUser();
      var uid = u && u.data && u.data.user ? u.data.user.id : null;
      if (!uid) { fail('拿不到你的登入身分，請重開一次頁面。'); return; }

      var me = await window.fffDB.from('customers')
                     .select('id,name').eq('auth_user_id', uid).maybeSingle();
      if (me.error) throw me.error;            // 規則 14：不要吞掉錯誤
      if (!me.data) { fail('找不到你的會員資料。'); return; }

      var map = await loadCoaches();
      var payload = {
        customer_id: me.data.id,
        product: req.product,                        // 'PT' 或 'PGT'
        spec: req.spec,
        people_count: req.people_count || null,
        preferred_coach_id: (req.coachLabel && map[req.coachLabel]) || null,
        preferred_time: req.preferred_time || null,
        note: req.note || null,
        status: 'new'
      };

      var ins = await window.fffDB.from('pt_requests').insert(payload);
      if (ins.error) throw ins.error;

      openOverlay({
        title: '需求已送出',
        sub: '我們會在營業時間內與你聯繫，敲定時間。<br>' +
             '<span style="opacity:.7">' + HOURS + '</span>',
        card: cardHtml(req) +
              '<div class="rw"><span class="k">送出人</span><span class="v">' +
              esc(me.data.name) + '</span></div>',
        actText: '有問題？用 LINE 找我們',
        actHref: lineLink('我剛送出了' + req.productLabel + '的需求，想再補充：'),
        actClass: 'btn-2'
      });

    } catch (e) {
      var m = (e && e.message) || String(e);
      console.error('[pt-request] 送出失敗：', e);
      fail(/row-level security|permission/i.test(m) ? '系統暫時無法接受需求。' : m);
    } finally {
      if (btn) { btn.disabled = false; btn.innerHTML = old; }
    }
  };
})();
