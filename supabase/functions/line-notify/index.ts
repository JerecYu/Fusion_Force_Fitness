// ═══════════════════════════════════════════════════════════════════
// line-notify — 只通知那堂課的人
//
// 專案：FFF 預約系統（fff-platform）· 第 81 步 · 2026-08-20
//
// 起因：「⚠️團課異動⚠️」現在是群發給全部 204 位好友，一次就是 204 則。
// 中用量每月 3,000 則，8/01～8/16 已用掉 2,217 則。這一支把它換成
// 「只發給訂了那一堂的那幾個人」—— 6 個人就是 6 則。
//
// ☢️ 推得到的人只有【完成推播綁定】的那些（customers.push_user_id）。
//    橋剛架好那天是 0 個人，之後才一個一個累積。所以這一支【一定】會
//    回傳「推不到的名單」給櫃檯 —— 那些人不會靜靜消失。
//
// ☢️ 收件人由這一支自己去資料庫查，【不接受前端傳進來】。
//    接受的話，這支就變成「叫我發給誰我就發給誰」的工具。
//
// ☢️ verify_jwt 設 false，改由第 ① 段自己驗 —— 理由同 line-bind：
//    這樣錯誤訊息是我們自己寫的，看得懂；而且驗完馬上就要用那個人。
//
// 需要的環境變數（Supabase → Edge Functions → Secrets）：
//    LINE_MSG_CHANNEL_SECRET   OA Manager → 設定 → Messaging API
// ═══════════════════════════════════════════════════════════════════

import { createClient } from 'jsr:@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } })

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { autoRefreshToken: false, persistSession: false } },
)

const SECRET = Deno.env.get('LINE_MSG_CHANNEL_SECRET') ?? ''
const CHANNEL_ID = '2009245280'

async function mintToken(): Promise<string | null> {
  if (!SECRET) return null
  const r = await fetch('https://api.line.me/oauth2/v3/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'client_credentials', client_id: CHANNEL_ID, client_secret: SECRET,
    }),
  })
  if (!r.ok) return null
  const j = await r.json()
  return j.access_token ?? null
}

function fmt(d: string): string {
  // 2026-08-22 → 08/22（週五）
  const wk = ['週日','週一','週二','週三','週四','週五','週六']
  const p = d.split('-').map(Number)
  const dt = new Date(Date.UTC(p[0], p[1] - 1, p[2]))
  return `${String(p[1]).padStart(2,'0')}/${String(p[2]).padStart(2,'0')}（${wk[dt.getUTCDay()]}）`
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

  try {
    // ── ① 這是不是我們的職員 ─────────────────────────────
    const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '').trim()
    if (!token) return json({ ok: false, why: 'missing_token' }, 401)
    const { data: got, error: aErr } = await admin.auth.getUser(token)
    if (aErr || !got?.user) return json({ ok: false, why: 'bad_token' }, 401)

    const { data: emp } = await admin
      .from('employees').select('id, display_name, is_active')
      .eq('auth_user_id', got.user.id).maybeSingle()
    if (!emp || emp.is_active === false) {
      return json({ ok: false, why: 'not_staff', msg: '只有職員可以發通知' }, 403)
    }

    // ── ② 收參數 ────────────────────────────────────────
    let sessionId = '', body = ''
    try {
      const b = await req.json()
      sessionId = String(b?.session_id ?? '')
      body = String(b?.body ?? '').trim()
    } catch { return json({ ok: false, why: 'bad_request' }, 400) }
    if (!sessionId) return json({ ok: false, why: 'no_session' }, 400)

    // ── ③ 收件人由這裡自己查 ──────────────────────────────
    const { data: ses } = await admin
      .from('class_sessions')
      .select('id, session_date, start_time, title, status, coach_id')
      .eq('id', sessionId).maybeSingle()
    if (!ses) return json({ ok: false, why: 'no_session', msg: '找不到這堂課' }, 404)

    const { data: bks } = await admin
      .from('bookings')
      .select('customer_id, status, customers!inner(id, name, phone, push_user_id)')
      .eq('session_id', sessionId)
      .in('status', ['booked', 'cancelled'])

    const seen = new Set<string>()
    const people: any[] = []
    for (const b of (bks ?? []) as any[]) {
      const c = b.customers
      if (!c || seen.has(c.id)) continue
      seen.add(c.id); people.push(c)
    }
    const targets = people.filter(c => !!c.push_user_id)
    const manual  = people
      .filter(c => !c.push_user_id)
      .map(c => ({ name: c.name, phone_tail: String(c.phone ?? '').slice(-3) }))

    // ── ④ 組訊息 ────────────────────────────────────────
    const when = `${fmt(ses.session_date)} ${String(ses.start_time).slice(0, 5)}`
    const text =
      `⚠️ 團課異動\n\n${when}　${ses.title ?? '團體課'}\n\n` +
      (body || '這堂課取消了。') +
      `\n\n你的堂數沒有被扣，可以直接改訂其他時段。`

    // ── ⑤ 送出 ──────────────────────────────────────────
    let sent = 0
    let detail: any = null
    if (targets.length) {
      const tok = await mintToken()
      if (!tok) {
        return json({
          ok: false, why: 'no_line_credential',
          msg: '還沒設定 LINE_MSG_CHANNEL_SECRET —— 到 Supabase → Edge Functions → Secrets 加上去',
          push: 0, manual,
        }, 200)
      }
      // multicast：一次最多 500 人；每一位算一則
      const ids = targets.map(c => c.push_user_id)
      const r = await fetch('https://api.line.me/v2/bot/message/multicast', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tok}` },
        body: JSON.stringify({ to: ids, messages: [{ type: 'text', text }] }),
      })
      if (r.ok) {
        sent = ids.length
      } else {
        detail = { status: r.status, body: (await r.text()).slice(0, 400) }
      }
    }

    // ── ⑥ 留紀錄 ────────────────────────────────────────
    await admin.from('class_notices').insert({
      session_id: sessionId,
      kind: 'cancel',
      body: body || '課程取消',
      sent_by: emp.id,
      n_target: people.length,
      n_push: sent,
      n_manual: manual.length,
      result: detail,
    })

    return json({
      ok: sent > 0 || targets.length === 0,
      push: sent,
      target: people.length,
      manual,
      text,
      error: detail,
    })
  } catch (e) {
    return json({ ok: false, why: 'unexpected', detail: String(e) }, 500)
  }
})
