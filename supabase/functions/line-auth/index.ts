// ═══════════════════════════════════════════════════════════
// line-auth — 驗 LINE 身分，發 Supabase 憑證
//
// 專案：FFF 預約系統（fff-platform）
// 對應路線圖第 31 步 · 2026-08-11
//
// 這支是整個系統的身分關卡。它回答一個問題：
//   「打開這個網頁的人，真的是他自己說的那個 LINE 使用者嗎？」
//
// ❌ 錯的做法：前端用 liff.getProfile() 拿 userId，直接送給資料庫查資料。
//    那個 userId 是「前端說的」—— 任何人打開開發者工具改一個字串，
//    就能查別人的資料、取消別人的課。前端說的話一律不能信。
//
// ✅ 這支的做法：前端送的是 ID Token（LINE 用私鑰簽章過的憑證），
//    這支拿去問 LINE 官方「這張是真的嗎？是發給我們這個 channel 的嗎？」
//    LINE 說是，才發一張 Supabase 憑證。
//    之後所有查詢用 auth.uid() 判斷身分 —— 那是資料庫自己認的。
//
// ☢️ verify_jwt 設成 false 是刻意的，不是疏忽。
//    這支「本身就是登入端點」，呼叫它的人當然還沒有 Supabase 憑證。
//    真正的驗證是下面第 ② 段的 LINE ID Token 驗證 ——
//    沒有一張 LINE 簽過章的有效憑證，這支什麼都不會給你。
// ═══════════════════════════════════════════════════════════

import { createClient } from 'jsr:@supabase/supabase-js@2'

// LINE Login channel 的 Channel ID。
// 這不是密碼 —— 它會出現在網頁原始碼裡，公開的。
const LINE_CHANNEL_ID = '2011063116'

// 合成帳號的網域。客人不會收到任何信，這只是 Supabase 內部的唯一鍵。
// （已用探針實測過 Supabase 接受這個格式）
const SYNTH_DOMAIN = 'fff.local'

// CORS 開放給所有來源。
// 這裡不用 CORS 當安全邊界 —— 真正的門檻是「有沒有有效的 LINE ID Token」。
// 鎖網域只會在你哪天換網址時，變成一個很難查的錯誤。
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
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,   // 這把鑰匙只活在伺服器上，前端永遠拿不到
  { auth: { autoRefreshToken: false, persistSession: false } },
)

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

  try {
    // ── ① 收下前端送來的 ID Token ─────────────────────────
    let idToken = ''
    try {
      const body = await req.json()
      idToken = String(body?.idToken ?? '')
    } catch {
      return json({ error: 'bad_request', hint: '要送 JSON，格式 { "idToken": "..." }' }, 400)
    }
    if (!idToken) return json({ error: 'missing_id_token' }, 400)

    // ── ② 拿去問 LINE：這張憑證是真的嗎？ ─────────────────
    //    這一步是整支程式的重點。LINE 會檢查簽章、有效期限，
    //    而且 client_id 對不上（別人的 channel 發的憑證）也會被拒絕。
    const verifyRes = await fetch('https://api.line.me/oauth2/v2.1/verify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ id_token: idToken, client_id: LINE_CHANNEL_ID }),
    })
    const verified = await verifyRes.json().catch(() => ({}))

    if (!verifyRes.ok) {
      // 憑證假的、過期、或不是發給我們 channel 的 —— 一律擋掉
      return json({ error: 'line_verify_failed', detail: verified }, 401)
    }

    const lineUserId: string = verified?.sub ?? ''
    if (!lineUserId) return json({ error: 'no_sub_in_token' }, 401)

    // 再自己確認一次 aud（LINE 已經檢查過，但多一道不花錢）
    if (verified.aud && String(verified.aud) !== LINE_CHANNEL_ID) {
      return json({ error: 'aud_mismatch' }, 401)
    }

    // ── ③ 找出（或建立）對應的 Supabase 帳號 ───────────────
    //    一個 LINE 使用者 = 一個 Supabase 帳號，用合成 email 當唯一鍵。
    const email = `line.${lineUserId.toLowerCase()}@${SYNTH_DOMAIN}`

    const { error: createErr } = await admin.auth.admin.createUser({
      email,
      email_confirm: true,
      user_metadata: { line_user_id: lineUserId, source: 'liff' },
    })
    // 已經存在是正常的（第二次以後打開就會走到這裡），其他錯誤才要中止
    if (createErr && !/already been registered/i.test(createErr.message)) {
      return json({ error: 'create_user_failed', detail: createErr.message }, 500)
    }

    // ── ④ 發一張一次性的登入票，前端拿去換 session ─────────
    const { data: link, error: linkErr } = await admin.auth.admin.generateLink({
      type: 'magiclink',
      email,
    })
    const tokenHash = link?.properties?.hashed_token
    if (linkErr || !tokenHash) {
      return json({ error: 'generate_link_failed', detail: linkErr?.message ?? 'no token' }, 500)
    }

    // ── ⑤ 順便告訴前端：這個 LINE 使用者綁過手機了嗎？ ──────
    //    綁過 → 直接進課表；沒綁過 → 第 32 步的手機綁定畫面。
    const { data: cust } = await admin
      .from('customers')
      .select('id, name')
      .eq('line_user_id', lineUserId)
      .maybeSingle()

    return json({
      ok: true,
      tokenHash,                    // 前端用它換 session
      bound: !!cust,                // 綁過手機了嗎
      displayName: cust?.name ?? null,
      // ⚠️ 這裡刻意不回傳 lineUserId。前端不需要它，
      //    回傳只會讓人以為那個值可以拿來查資料 —— 它不行。
    })
  } catch (e) {
    return json({ error: 'unexpected', detail: String(e) }, 500)
  }
})
