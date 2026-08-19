# ═══════════════════════════════════════════════════════════════════
#  探測：換 token ＋ 找出七位教練的 Messaging API 使用者編號
#  諧動空間 FFF · 2026-08-19 · 第 67 步（之一）
#
#  用法（PowerShell，在專案根目錄）：
#      powershell -ExecutionPolicy Bypass -File .\tools\probe-line-ids.ps1
#
#  這一支【只讀不寫】。它不會建立選單、不會綁定任何人、不會改任何設定。
#  跑完只產生一個檔案：tools\line-followers.csv
#
#  ☢️ 那個 csv 裡是兩百多位客人的 LINE 使用者編號和顯示名稱 —— 那是個資。
#     .gitignore 已經把它擋掉了，不要手動加進 git，也不要整份傳給別人。
#
#  ☢️ 為什麼不需要 LINE Developers 的權限：
#     圖文選單的 token 可以直接用 Channel ID ＋ Channel secret 換
#     （POST /v2/oauth/accessToken，grant_type=client_credentials）。
#     那兩樣 OA Manager 的「Messaging API」那一頁就看得到。
#     換出來的 token 有效 30 天，而且【不會讓現有的 token 失效】。
# ═══════════════════════════════════════════════════════════════════

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Stop'

$CHANNEL_ID = '2009245280'
$OUT = Join-Path $PSScriptRoot 'line-followers.csv'

# 我們要找的七位。顯示名稱不一定跟這裡一樣，所以只拿來當提示。
$WANT = @('Jerec','VC','Peter','Jessica','Johnson','簡基城','林智謙')

Write-Host ''
Write-Host '── 探測 LINE Messaging API ────────────────────────' -ForegroundColor Cyan
Write-Host "   Channel ID：$CHANNEL_ID"
Write-Host ''

$sec = Read-Host '貼上 Channel secret（OA Manager → 設定 → Messaging API）' -AsSecureString
$SECRET = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
if (-not $SECRET) { Write-Host '☢️ 沒有輸入，停止。' -ForegroundColor Red; exit 1 }

# ── ① 換 token ───────────────────────────────────────────────────
Write-Host ''
Write-Host '① 用 Channel secret 換 token…' -NoNewline
try {
  $body = "grant_type=client_credentials&client_id=$CHANNEL_ID&client_secret=$SECRET"
  $r = Invoke-RestMethod -Method Post -Uri 'https://api.line.me/v2/oauth/accessToken' `
        -ContentType 'application/x-www-form-urlencoded' -Body $body
  $TOKEN = $r.access_token
  Write-Host ("  ✓ 拿到了（有效 {0} 天）" -f [int]($r.expires_in / 86400)) -ForegroundColor Green
} catch {
  Write-Host '  ☢️ 失敗' -ForegroundColor Red
  Write-Host "     $($_.Exception.Message)"
  Write-Host '     400 = Channel secret 貼錯，或前後多了空白'
  exit 1
}
$H = @{ Authorization = "Bearer $TOKEN" }

# ── ② 確認這張 token 真的能用（順便看看官方帳號基本資料）─────────
Write-Host '② 確認 token 可用…' -NoNewline
try {
  $info = Invoke-RestMethod -Uri 'https://api.line.me/v2/bot/info' -Headers $H
  Write-Host "  ✓ $($info.displayName)　好友數請看 OA Manager" -ForegroundColor Green
} catch {
  Write-Host '  ☢️ token 拿到了但用不了：' -ForegroundColor Red
  Write-Host "     $($_.Exception.Message)"
  exit 1
}

# ── ③ 撈好友清單 ─────────────────────────────────────────────────
# ☢️ 這一支要「認證帳號或付費方案」才給用。403 就是沒資格，不是壞掉。
Write-Host '③ 撈好友清單…' -NoNewline
$ids = @()
try {
  $next = $null
  do {
    $u = 'https://api.line.me/v2/bot/followers/ids?limit=1000'
    if ($next) { $u += "&start=$next" }
    $p = Invoke-RestMethod -Uri $u -Headers $H
    $ids += $p.userIds
    $next = $p.next
  } while ($next)
  Write-Host "  ✓ $($ids.Count) 位" -ForegroundColor Green
} catch {
  Write-Host '  ☢️ 撈不到' -ForegroundColor Yellow
  Write-Host "     $($_.Exception.Message)"
  Write-Host ''
  Write-Host '   這通常表示官方帳號不是「認證帳號」，LINE 不開放這一支。' -ForegroundColor Yellow
  Write-Host '   那就改走另一條路：請七位教練各傳一則訊息給官方帳號，'
  Write-Host '   我從 webhook 收他們的編號。把這個畫面截給 Claude 就好。'
  exit 2
}

# ── ④ 一個一個查顯示名稱 ─────────────────────────────────────────
Write-Host '④ 查顯示名稱…（一個一個問 LINE，會跑一下）'
$rows = @()
$i = 0
foreach ($id in $ids) {
  $i++
  if ($i % 25 -eq 0) { Write-Host "   $i / $($ids.Count)…" }
  try {
    $pf = Invoke-RestMethod -Uri "https://api.line.me/v2/bot/profile/$id" -Headers $H
    $rows += [pscustomobject]@{ displayName = $pf.displayName; userId = $id }
  } catch {
    $rows += [pscustomobject]@{ displayName = '（查不到）'; userId = $id }
  }
  Start-Sleep -Milliseconds 60      # 不要打太快
}

$rows | Sort-Object displayName | Export-Csv -Path $OUT -NoTypeInformation -Encoding UTF8
Write-Host ''
Write-Host "✓ 全部 $($rows.Count) 位已寫進：$OUT" -ForegroundColor Green

# ── ⑤ 挑出看起來像教練的 ─────────────────────────────────────────
Write-Host ''
Write-Host '── 名字看起來像教練的（請你確認）──────────────────' -ForegroundColor Cyan
$hit = $rows | Where-Object {
  $n = $_.displayName
  ($WANT | Where-Object { $n -like "*$_*" }).Count -gt 0
}
if ($hit) {
  $hit | ForEach-Object { Write-Host ("   {0,-20} {1}" -f $_.displayName, $_.userId) }
} else {
  Write-Host '   一個都沒對到 —— 教練的 LINE 顯示名稱可能跟系統裡的稱呼不一樣。' -ForegroundColor Yellow
  Write-Host "   請直接打開 $OUT 自己找。"
}
Write-Host ''
Write-Host '☢️ 把上面這幾行（或你自己從 csv 找出來的七筆）貼給 Claude，'
Write-Host '   我把編號寫進綁定腳本，然後就可以建立選單了。'
Write-Host ''
Write-Host '☢️ csv 裡有兩百多位客人的個資 —— 不要整份傳出去，只挑那七筆。' -ForegroundColor Yellow
Write-Host ''
