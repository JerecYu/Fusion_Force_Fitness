// ═══════════════════════════════════════════════════════════════
//  price-extract.js　—　把「寫死在檔案裡的價格」挖出來
//
//  這支只做一件事：讀一段文字，吐出 {商品代號: 價格}。
//  不連網路、不碰畫面 —— 所以瀏覽器跟 node 都跑得動，
//  也代表 tools/check-prices.html 用的邏輯，跟我在沙盒裡測過的是同一份。
// ═══════════════════════════════════════════════════════════════

(function (root, factory) {
  var api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.FFF_PRICE_EXTRACT = api;
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  function num(s) { return parseInt(String(s).replace(/,/g, ''), 10); }

  // ── ① 畫面上 data-p="代號" 的那些格子 ───────────────────────────
  //    例：<td data-p="PT-1-1">NT$1,800</td>
  //    ☢️ 回傳「一筆一筆」不是「代號→價格」的對照表 ——
  //       同一個代號在一頁裡可能出現好幾次（表格一次、文案一次），
  //       整併成對照表的話，只要最後一次是對的，前面漏改的就被蓋掉看不見了。
  function fromDataP(html) {
    var out = [], re = /data-p="([A-Z0-9-]+)"[^>]*>\s*NT\$([\d,]+)/g, m;
    while ((m = re.exec(html))) out.push({ code: m[1], value: num(m[2]) });
    return out;
  }

  // ── ② prices.js 裡的備援表 ──────────────────────────────────────
  function fromFallback(js) {
    var blk = js.match(/var\s+FALLBACK\s*=\s*\{([\s\S]*?)\}\s*;/);
    if (!blk) return null;
    var out = {}, re = /'([A-Z0-9-]+)'\s*:\s*(\d+)/g, m;
    while ((m = re.exec(blk[1]))) out[m[1]] = num(m[2]);
    return out;
  }

  // ── ③ 官網 index.html 裡的 FFDATA.pricing ───────────────────────
  //    官網照規劃是「寫死的」，所以更要有人幫忙盯著它有沒有跟資料庫走鐘。
  function fromSiteData(html) {
    var out = {}, meta = {};

    // pt: [ { id:'1v1', ..., trial:1000, single:1800, pack10:15000 }, ... ]
    var ptRe = /\{\s*id:\s*'(1v[12])'[^}]*?trial:\s*(\d+)[^}]*?single:\s*(\d+)[^}]*?pack10:\s*(\d+)[^}]*?\}/g, m;
    while ((m = ptRe.exec(html))) {
      var h = m[1] === '1v1' ? '1' : '2';
      out['PT-TRY-' + h]  = num(m[2]);
      out['PT-1-' + h]    = num(m[3]);
      out['PT-10-' + h]   = num(m[4]);
    }

    // pgt: { rates: { 3: 2100, ... }, min: 3, max: 6 }
    var pgt = html.match(/pgt:\s*\{\s*rates:\s*\{([^}]*)\}\s*,\s*min:\s*(\d+)\s*,\s*max:\s*(\d+)/);
    if (pgt) {
      var rRe = /(\d+)\s*:\s*(\d+)/g, r;
      while ((r = rRe.exec(pgt[1]))) out['PGT-1-' + r[1]] = num(r[2]);
      meta.pgtMin = num(pgt[2]);
      meta.pgtMax = num(pgt[3]);
    }

    // gt: { single: 400, pack: 4000, ... }
    var gt = html.match(/gt:\s*\{\s*single:\s*(\d+)\s*,\s*pack:\s*(\d+)/);
    if (gt) { out['GT-1'] = num(gt[1]); out['GT-12'] = num(gt[2]); }

    return { prices: out, meta: meta };
  }

  // ── ④ 比對 ─────────────────────────────────────────────────────
  //    db     ＝ {代號: 價格}，資料庫那份，當標準答案
  //    source ＝ {name, prices, expectAll}
  //    只檢查 source 裡真的有出現的代號 —— 一個頁面沒印 GT 的價格
  //    不代表它錯，只代表它不管 GT。
  // prices 可以是 {代號: 價格} 的對照表，也可以是 [{code, value}] 的清單。
  function entries(p) {
    if (Array.isArray(p)) return p.slice();
    return Object.keys(p || {}).map(function (c) { return { code: c, value: p[c] }; });
  }

  function compare(db, sources) {
    var rows = [];
    sources.forEach(function (s) {
      var list = entries(s.prices);
      if (!list.length) {
        rows.push({ source: s.name, code: '(整份)', want: '—', got: '一個價格都沒抓到',
                    ok: false, note: '格式可能被改過，抓不到了' });
        return;
      }
      list.forEach(function (e) {
        var want = db[e.code];
        rows.push({
          source: s.name, code: e.code,
          want: (want === undefined ? '(資料庫沒這筆)' : want),
          got: e.value,
          ok: want !== undefined && want === e.value
        });
      });
      if (s.expectAll) {
        var seen = {};
        list.forEach(function (e) { seen[e.code] = true; });
        Object.keys(db).forEach(function (c) {
          if (!seen[c]) {
            rows.push({ source: s.name, code: c, want: db[c], got: '(這份漏了)', ok: false });
          }
        });
      }
    });
    return rows;
  }

  return { fromDataP: fromDataP, fromFallback: fromFallback,
           fromSiteData: fromSiteData, compare: compare };
});
