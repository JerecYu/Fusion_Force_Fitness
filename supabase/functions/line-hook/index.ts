// ═══════════════════════════════════════════════════════════════════
// line-hook — 兩組 LINE 編號之間的那座橋
//
// 專案：FFF 預約系統（fff-platform）· 第 81 步 · 2026-08-20
//
// ☢️☢️ 為什麼需要這座橋
//    customers.line_user_id 來自 LINE Login channel（2011063116）。
//    推播要的是官方帳號 Messaging API channel（2009245280）的編號。
//    兩個 channel 在【不同的 Provider】，而 LINE 的 userId 是以 provider
//    為單位發的 —— 同一個人在兩邊是兩組完全不同的號碼（2026-08-19 用
//    Jerec 本人證實過）。channel 不能換 provider，官方文件寫死，所以
//    這件事沒有捷徑：只能請客人主動傳一則訊息過來，我們才拿得到。
//
//    流程：訂課頁給一顆按鈕 → LINE 開啟官方帳號聊天室、訊息預填一組
//    一次性短碼 → 他按送出 → 這一支收到「userId ＋ 短碼」→ 對起來。
//
// ☢️ 這一支【一定要驗 X-Line-Signature】。
//    它會寫 customers.push_user_id —— 沒驗簽的話，任何人都能 POST
//    一則假的「userId ＋ 短碼」進來，把自己的 LINE 綁到別人身上。
//    （2026-08-19 的舊版本沒驗，因為那時它只寫一張對照表、而且要配上
//     六句講好的暗號。現在它動的是客人資料，標準不一樣。）
//
// ☢️ 回覆訊息（reply）【不計費】，推播（push／multicast）才計費。
//    所以確認訊息一律走 reply —— 這是整套設計裡唯一免費的一則。
//
// ☢️ 一律回 200。LINE 收不到 200 會重送，連續失敗還會自動把 webhook
//    關掉 —— 那會讓這座橋在沒有人發現的情況下停止運作。
//
// 需要的環境變數（Supabase → Edge Functions → Secrets）：
//    LINE_MSG_CHANNEL_SECRET   OA Manager → 設定 → Messaging API
// ═══════════════════════════════════════════════════════════════════

import { createClient } from 'jsr:@supabase/supabase-js@2'

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { autoRefreshToken: false, persistSession: false } },
)

const SECRET = Deno.env.get('LINE_MSG_CHANNEL_SECRET') ?? ''
const CHANNEL_ID = '2009245280'

// ☢️ 短碼字母表跟資料庫那支 issue_push_code() 必須一致 ——
//    不一致的話客人送出的碼永遠對不上，而兩邊都不會報錯。
const CODE_RE = /([23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6})/

async function verifySignature(body: string, sig: string): Promise<boolean> {
  if (!SECRET || !sig) return false
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(SECRET),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  )
  const mac = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body))
  const mine = btoa(String.fromCharCode(...new Uint8Array(mac)))
  if (mine.length !== sig.length) return false
  let diff = 0
  for (let i = 0; i < mine.length; i++) diff |= mine.charCodeAt(i) ^ sig.charCodeAt(i)
  return diff === 0
}

// ☢️ 用短期權杖（15 分鐘），每次現換。
//    長期權杖要進 Developers Console，而那個 provider 我們進不去。
async function mintToken(): Promise<string | null> {
  if (!SECRET) return null
  try {
    const r = await fetch('https://api.line.me/oauth2/v3/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'client_credentials',
        client_id: CHANNEL_ID,
        client_secret: SECRET,
      }),
    })
    if (!r.ok) return null
    const j = await r.json()
    return j.access_token ?? null
  } catch (_) { return null }
}

async function reply(replyToken: string, text: string) {
  try {
    const tok = await mintToken()
    if (!tok) return
    await fetch('https://api.line.me/v2/bot/message/reply', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tok}` },
      body: JSON.stringify({ replyToken, messages: [{ type: 'text', text }] }),
    })
  } catch (_) { /* 回覆失敗不該影響綁定結果 */ }
}

Deno.serve(async (req) => {
  const ok200 = () => new Response('ok', { status: 200 })
  if (req.method !== 'POST') return ok200()

  let raw = ''
  try { raw = await req.text() } catch { return ok200() }

  const sig = req.headers.get('x-line-signature') ?? ''
  if (!(await verifySignature(raw, sig))) {
    // ☢️ 這裡也回 200。回 401 的話，攻擊者可以用回應碼確認「這個網址真的是
    //    webhook」；而 LINE 自己收到非 200 會重送。
    console.log('line-hook: bad signature')
    return ok200()
  }

  let body: any
  try { body = JSON.parse(raw) } catch { return ok200() }

  for (const ev of body?.events ?? []) {
    try {
      if (ev.type !== 'message' || ev.message?.type !== 'text') continue
      const uid = String(ev.source?.userId ?? '')
      if (!uid) continue

      const m = CODE_RE.exec(String(ev.message.text ?? '').toUpperCase())
      if (!m) continue
      const code = m[1]

      const { data: link } = await admin
        .from('push_links')
        .select('code, customer_id, used_at, expires_at')
        .eq('code', code)
        .maybeSingle()

      if (!link) {
        await reply(ev.replyToken, '這組代碼查不到。請回訂課頁再按一次「開啟課程異動通知」。')
        continue
      }
      if (link.used_at) {
        await reply(ev.replyToken, '這組代碼已經用過了。如果通知還沒開起來，請回訂課頁再按一次。')
        continue
      }
      if (new Date(link.expires_at).getTime() < Date.now()) {
        await reply(ev.replyToken, '這組代碼過期了（只有 30 分鐘）。請回訂課頁再按一次。')
        continue
      }

      // ☢️ 這支 LINE 已經綁在別位客人身上了 —— 唯一索引會擋，但先講清楚。
      const { data: taken } = await admin
        .from('customers').select('id').eq('push_user_id', uid).maybeSingle()
      if (taken && taken.id !== link.customer_id) {
        await reply(ev.replyToken, '這個 LINE 帳號已經開給另一位學員了。請找櫃檯處理。')
        continue
      }

      const { error: upErr } = await admin
        .from('customers')
        .update({ push_user_id: uid })
        .eq('id', link.customer_id)

      if (upErr) {
        await reply(ev.replyToken, '開啟失敗，請找櫃檯。')
        continue
      }

      await admin.from('push_links')
        .update({ used_at: new Date().toISOString(), used_by: uid })
        .eq('code', code)

      await reply(ev.replyToken,
        '✅ 課程異動通知已開啟。\n以後你訂的課如果停課或改時間，我們會直接傳到這裡，不用自己查。')
    } catch (e) {
      console.log('line-hook event failed:', String(e))
    }
  }

  return ok200()
})
