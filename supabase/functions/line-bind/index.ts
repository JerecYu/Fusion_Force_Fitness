// ═══════════════════════════════════════════════════════════
// line-bind — 把 LINE 身分綁到一位客人身上
//
// 專案：FFF 預約系統（fff-platform）
// 對應路線圖第 32 步 · 2026-08-11（第 54 步 2026-08-18 加暱稱）
//
// 第 31 步回答的是「你是哪個 LINE 使用者」。
// 這一支回答的是「那個 LINE 使用者是我們名單上的哪一位客人」。
//
// ☢️ 最重要的一行在第 ⑤ 段：auth_user_id。
//    line_user_id 是給人看的，RLS 一個字都不看它。
//    資料庫認的是 auth.uid()，也就是 auth_user_id。
//    只寫 line_user_id 不寫 auth_user_id，客人會綁定成功、
//    然後查不到自己的任何資料 —— 而且不會有錯誤訊息。
//
// 規則（2026-08-11 決定，選 A）：
//   查無此人 → 擋下來，不自動建客人。
//   建客人的路徑從頭到尾只有櫃檯一條。
//   但把他留的資料記進 signup_requests（留言簿），讓他不會消失。
//
// verify_jwt 設 false，改由第 ① 段自己驗 —— 理由同 line-auth：
// 這樣錯誤訊息是我們自己寫的，看得懂；而且驗完馬上就要用那個 user。
// ═══════════════════════════════════════════════════════════

import { createClient } from 'jsr:@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { autoRefreshToken: false, persistSession: false } },
)

// 09xx-xxx-xxx、0912 333 444、+886912333444 都要歸成 0912333444
function normPhone(v: string): string {
  let s = String(v ?? '').trim().replace(/[\s\-()]/g, '')
  if (s.startsWith('+886')) s = '0' + s.slice(4)
  else if (s.startsWith('886')) s = '0' + s.slice(3)
  return s.replace(/\D/g, '')
}

// 去掉所有空白（含全形），大小寫不計。中文姓名不會有大小寫問題，
// 但英文名字的客人會 —— 順手處理掉。
function normName(v: string): string {
  return String(v ?? '').replace(/[\s　]/g, '').toLowerCase()
}

// ☢️ 姓名比對放寬：客人填的只要【包含完整的登記姓名】就算過。多寫可以，少寫不行。
//
//    起因是 2026-08-17 早上翻 signup_requests 看到的兩筆：
//      「廖庭均 Teresa」 對不上登記的「廖庭均」 —— 試了 5 次，從 17:15 到隔天 08:53
//      「荔芬Adele」    對不上登記的「Adele」  —— 試了 3 次
//    兩位的手機【一個數字都沒錯】。他們只是多打了自己的另一個名字。
//
//    ☢️ 手機那一關【不放寬】，還是要完全一致。
//       能走到姓名比對這一步的人，本來就已經知道正確手機號碼了 ——
//       所以放寬姓名的邊際風險很小，而擋掉真客人的代價是可以量的。
//
//    ☢️ 但登記姓名太短時不能用包含比對：只有一個字（例如「王」）的話，
//       任何含「王」的名字都會通過。所以要求登記姓名至少 2 個字。
//       （2026-08-17 查過：最短的登記姓名是 2 個字，沒有 1 個字的。）
function oneNameMatches(registered: string, typed: string): boolean {
  const a = normName(registered), b = normName(typed)
  if (!a || !b) return false
  if (a === b) return true
  // ☢️ 這裡是【不對稱】的：客人填的必須包含【完整的】登記姓名。
  //    多寫沒關係（廖庭均 Teresa ⊃ 廖庭均），少寫不行（王惠 ⊅ 王惠君）。
  //    對稱寫法（誰包含誰都算）測出來太鬆 —— 那等於「猜對姓 ＋ 一個字」就能過。
  //    今天兩個真實案例都是「多寫」，沒有人是「少寫」。
  return a.length >= 2 && b.includes(a)
}

// ☢️ 2026-08-18（第 54 步）：姓名或暱稱，對上【任一個】就算過。
//
//    起因是盤點出來的數字：93 位客人裡有 18 位的登記姓名【完全沒有中文字】
//    （純英文名或綽號），佔五分之一。這些人照自己的中文名去綁，一定卡住。
//
//    ☢️ Jerec 本來想把暱稱也設成必填、綁定時一起比對，理由是「資訊越多信心越高」。
//       那句話在【找人】的時候成立，在【驗證】的時候是反的 ——
//       每多一個「必須對得上」的欄位，就多一個對不上的機會。
//       而且暱稱是自由填的：櫃檯記「小虎」、客人打「虎哥」，一樣卡。
//       所以這裡做的是多一條【可以】對得上的路，不是多一道關卡。
//
//    ☢️ 手機那一關【不放寬】，還是要完全一致。
//    ☢️ 暱稱少於 2 個字時自動失效（oneNameMatches 裡的 a.length >= 2）——
//       否則登記暱稱「明」的話，任何含「明」的名字都會通過。
//
//    ☢️ 這一支要跟資料庫的 name_matches(registered, nickname, typed) 完全一致。
//       不一致的話教練後台會說「這樣打會過」，實際上卻不會過 —— 比沒有更糟。
//       2026-08-18 用 26 個案例逐一比對過，兩邊結果完全相同。
function nameMatches(registered: string, nickname: string | null, typed: string): boolean {
  return oneNameMatches(registered, typed) || oneNameMatches(nickname ?? '', typed)
}

// 留言簿：同一個 LINE 帳號只留一筆，重試就把次數加一。
// 失敗不影響綁定流程的回應 —— 記錄壞掉不該讓客人看到錯誤。
async function leaveNote(lineUserId: string, name: string, phone: string) {
  try {
    const { data: old } = await admin
      .from('signup_requests')
      .select('tries')
      .eq('line_user_id', lineUserId)
      .maybeSingle()

    await admin.from('signup_requests').upsert({
      line_user_id: lineUserId,
      name,
      phone,
      tries: (old?.tries ?? 0) + 1,
      updated_at: new Date().toISOString(),
    })
  } catch (_) { /* 記不起來就算了，不能因此擋住客人 */ }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

  try {
    // ── ① 驗憑證：必須是 line-auth 發出來的那張 ────────────
    const raw = req.headers.get('Authorization') ?? ''
    const token = raw.replace(/^Bearer\s+/i, '').trim()
    if (!token) return json({ error: 'missing_token' }, 401)

    const { data: got, error: authErr } = await admin.auth.getUser(token)
    const user = got?.user
    if (authErr || !user) return json({ error: 'bad_token' }, 401)

    const lineUserId = String(user.user_metadata?.line_user_id ?? '')
    if (!lineUserId) return json({ error: 'not_a_line_user' }, 401)

    // ── ② 收資料 ─────────────────────────────────────────
    let phone = '', name = ''
    try {
      const b = await req.json()
      phone = normPhone(b?.phone)
      name = String(b?.name ?? '').trim()
    } catch {
      return json({ error: 'bad_request' }, 400)
    }
    if (!/^09\d{8}$/.test(phone)) return json({ ok: false, reason: 'bad_phone' })
    if (!normName(name)) return json({ ok: false, reason: 'bad_name' })

    // ── ③ 這支 LINE 已經綁過人了嗎 ────────────────────────
    const { data: mine } = await admin
      .from('customers')
      .select('id, name, phone')
      .eq('line_user_id', lineUserId)
      .maybeSingle()

    if (mine) {
      // 綁的就是同一個人 → 重複按不會壞
      if (mine.phone === phone) return json({ ok: true, displayName: mine.name, already: true })
      // 想改綁別人 → 不行。這要櫃檯處理。
      return json({ ok: false, reason: 'line_already_used', boundName: mine.name })
    }

    // ── ④ 找人：手機要完全一致，姓名或暱稱對上任一個 ──────────
    const { data: cust } = await admin
      .from('customers')
      .select('id, name, nickname, line_user_id, auth_user_id, is_active')
      .eq('phone', phone)
      .maybeSingle()

    // ☢️ 手機查無、和姓名對不上，一律回同一個 reason。
    //    如果分開講，這支就變成「輸入手機就能查出這個人叫什麼名字」的工具。
    if (!cust || !nameMatches(cust.name, cust.nickname, name)) {
      await leaveNote(lineUserId, name, phone)
      return json({ ok: false, reason: 'not_found' })
    }

    if (cust.is_active === false) return json({ ok: false, reason: 'inactive' })

    // 這筆客人已經被別支 LINE 綁走了
    if (cust.line_user_id && cust.line_user_id !== lineUserId) {
      return json({ ok: false, reason: 'already_bound' })
    }

    // ── ⑤ 寫回去 ─────────────────────────────────────────
    //    auth_user_id 才是 RLS 認的那一個，兩個都要寫。
    //    .is('line_user_id', null) 是保險絲：只有還沒綁的才寫得進去。
    const { data: done, error: upErr } = await admin
      .from('customers')
      .update({ line_user_id: lineUserId, auth_user_id: user.id })
      .eq('id', cust.id)
      .is('line_user_id', null)
      .select('id, name')

    if (upErr) return json({ ok: false, reason: 'write_failed', detail: upErr.message }, 500)
    if (!done || done.length === 0) {
      // 保險絲燒了：在我們讀取到寫入之間，有人搶先綁走了
      return json({ ok: false, reason: 'already_bound' })
    }

    // 綁成功 → 他已經是客人了，留言簿那筆可以撤掉
    await admin.from('signup_requests').delete().eq('line_user_id', lineUserId)

    return json({ ok: true, displayName: done[0].name })
  } catch (e) {
    return json({ error: 'unexpected', detail: String(e) }, 500)
  }
})
