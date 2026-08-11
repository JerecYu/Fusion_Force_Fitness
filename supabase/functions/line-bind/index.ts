// ═══════════════════════════════════════════════════════════
// line-bind — 把 LINE 身分綁到一位客人身上
//
// 專案：FFF 預約系統（fff-platform）
// 對應路線圖第 32 步 · 2026-08-11
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

    // ── ④ 找人：手機和姓名都要對 ──────────────────────────
    const { data: cust } = await admin
      .from('customers')
      .select('id, name, line_user_id, auth_user_id, is_active')
      .eq('phone', phone)
      .maybeSingle()

    // ☢️ 手機查無、和姓名對不上，一律回同一個 reason。
    //    如果分開講，這支就變成「輸入手機就能查出這個人叫什麼名字」的工具。
    if (!cust || normName(cust.name) !== normName(name)) {
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
