// ═══════════════════════════════════════════════════════════════
//  prices.js　—　價格的唯一出口
//
//  規則：價格的正本在資料庫的 products 表。
//        這個檔案負責去把它讀回來，順便準備一份「讀不到時照樣有數字」的備援。
//
//  ☢️ 備援那份數字（FALLBACK）必須跟資料庫一模一樣。
//     不用你自己記得對 —— tools/check-prices.mjs 會幫你對，對不上就報錯。
// ═══════════════════════════════════════════════════════════════

(function (w) {
  'use strict';

  // ── ① 備援：網路斷了、資料庫掛了，頁面還是要有數字可以看 ────────
  //    （以《財務與教練薪資整合規則》2026-08-19 正式版 表 1／表 2／表 3 為準）
  var FALLBACK = {
    'GT-1':      400,
    'GT-12':     4000,
    'PT-TRY-1':  1000,
    'PT-TRY-2':  1500,
    'PT-1-1':    1800,
    'PT-1-2':    2200,
    'PT-10-1':   15000,
    'PT-10-2':   20000,
    'PGT-1-3':   2100,
    'PGT-1-4':   2400,
    'PGT-1-5':   2700,
    'PGT-1-6':   3000
  };

  // PGT 的人數範圍。☢️ 上限是 6，不是「以此類推」——
  //    規則寫死只賣到六人，超過要另外談外派／企業包班。
  var PGT_MIN = 3, PGT_MAX = 6;

  // ── ② 把一堆 products 的列，整理成頁面好用的形狀 ────────────────
  function shape(rows) {
    var by = {};
    (rows || []).forEach(function (r) { by[r.code] = r.price; });

    // 讀不到的那幾筆用備援補，不要讓畫面出現 undefined
    Object.keys(FALLBACK).forEach(function (k) {
      if (typeof by[k] !== 'number') by[k] = FALLBACK[k];
    });

    var pgt = {};
    for (var n = PGT_MIN; n <= PGT_MAX; n++) pgt[n] = by['PGT-1-' + n];

    return {
      byCode: by,
      GT:  { single: by['GT-1'], pack: by['GT-12'], packCredits: 12 },
      PT:  {
        1: { trial: by['PT-TRY-1'], single: by['PT-1-1'], pack10: by['PT-10-1'] },
        2: { trial: by['PT-TRY-2'], single: by['PT-1-2'], pack10: by['PT-10-2'] }
      },
      PGT: { min: PGT_MIN, max: PGT_MAX, rates: pgt }
    };
  }

  // ── ③ 去資料庫拿 ────────────────────────────────────────────────
  //    有 supabase 連線就用連線；沒有就直接打 REST。
  //    兩條路都走不通 → 回備援，頁面照樣正常。
  function fetchRows() {
    if (w.fffDB && w.fffDB.from) {
      return w.fffDB.from('products')
        .select('code,price')
        .eq('is_active', true)
        .then(function (r) { return (r && !r.error && r.data) ? r.data : null; });
    }
    if (w.SUPABASE_URL && w.SUPABASE_PUBLISHABLE_KEY && w.fetch) {
      var url = w.SUPABASE_URL +
        '/rest/v1/products?select=code,price&is_active=eq.true';
      return w.fetch(url, {
        headers: {
          apikey: w.SUPABASE_PUBLISHABLE_KEY,
          Authorization: 'Bearer ' + w.SUPABASE_PUBLISHABLE_KEY
        }
      }).then(function (res) { return res.ok ? res.json() : null; });
    }
    return Promise.resolve(null);
  }

  var cached = null;

  // load() 一定會 resolve，永遠不會 reject —— 價格讀不到不該讓整頁壞掉。
  function load() {
    if (cached) return Promise.resolve(cached);
    return fetchRows()
      .catch(function () { return null; })
      .then(function (rows) {
        cached = shape(rows);
        cached.live = !!(rows && rows.length);   // true＝這是資料庫的數字
        return cached;
      });
  }

  // 立刻可用的備援版本（同步）。頁面第一時間先畫這個，load() 回來再覆蓋。
  function now() { return shape(null); }

  function money(v) {
    return 'NT$' + Number(v || 0).toLocaleString('en-US');
  }

  // ── ④ 把畫面上 data-p="商品代號" 的欄位一次填好 ──────────────────
  //    HTML 裡本來就寫著正確數字（沒 JS 也看得到），
  //    這一步只是拿資料庫的版本蓋上去。
  function paint(P, root) {
    var el = (root || w.document).querySelectorAll('[data-p]');
    for (var i = 0; i < el.length; i++) {
      var code = el[i].getAttribute('data-p');
      if (typeof P.byCode[code] === 'number') el[i].textContent = money(P.byCode[code]);
    }
  }

  w.FFF_PRICES = {
    FALLBACK: FALLBACK,
    PGT_MIN: PGT_MIN,
    PGT_MAX: PGT_MAX,
    load: load,
    now: now,
    money: money,
    paint: paint
  };
})(window);
