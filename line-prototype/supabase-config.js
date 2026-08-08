// ═══════════════════════════════════════════════════════════════
//  supabase-config.js
//  前端連上 Supabase 的唯一入口。所有頁面都用這一份，不要各寫各的。
//
//  ⚠️  這個檔案會被推上 GitHub，任何人都看得到原始碼。
//      所以裡面只能放 Publishable key（sb_publishable_...）。
//
//      Secret key（sb_secret_...）如果放進來 = 整個資料庫對外公開，
//      而且 RLS 也擋不住它 —— 那把鑰匙的設計就是「繞過所有規則」。
//      放錯不會報錯，網站照樣跑得好好的，你不會知道。
// ═══════════════════════════════════════════════════════════════


// ── ① 專案網址（已經幫你填好，不用改）────────────────────────
const SUPABASE_URL = 'https://ubvbmksvvyzjzsmfxeby.supabase.co';


// ── ② 公開金鑰（你要自己貼）──────────────────────────────────
//
//    去 Supabase → 左下角齒輪 Settings → API Keys
//    複製 Publishable key，貼到下面那對單引號中間。
//
//    貼完一定要看開頭：
//      ✅ sb_publishable_...   ← 對的，可以放
//      ❌ sb_secret_...        ← 錯的，停下來重拿
//
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_ypWxEaKKmCkdYtxayl7YCQ_GciheV_h';


// ── ③ 建立連線 ──────────────────────────────────────────────
//
//    注意變數叫 fffDB，不叫 supabase。
//    因為 window.supabase 是 CDN 載進來的那個「工廠」，
//    如果把連線也命名成 supabase，就會把工廠覆蓋掉，
//    第二個頁面再要建連線時就找不到工廠了。
//
//    工廠（supabase） → 生出 → 連線（fffDB）
//    兩個是不同東西，名字不能撞。
//
const fffDB = window.supabase.createClient(
  SUPABASE_URL,
  SUPABASE_PUBLISHABLE_KEY
);


// ── ④ 提早警告 ──────────────────────────────────────────────
//    萬一哪天有人手滑貼成 secret key，主控台會立刻大聲抗議。
if (SUPABASE_PUBLISHABLE_KEY.startsWith('sb_secret_')) {
  console.error(
    '%c☢️ 危險：這裡放的是 Secret key，不是 Publishable key！\n' +
    '立刻停止使用、去 Supabase 撤銷這把金鑰，並改用 sb_publishable_ 開頭的那把。',
    'color:#fff;background:#D8342B;font-size:16px;padding:6px 10px'
  );
}
