# ═══════════════════════════════════════════════════════════════════
#  職員專屬圖文選單 —— 一鍵建立並綁定（第 67 步）
#  諧動空間 FFF · 2026-08-19
#
#  用法（PowerShell，在專案根目錄執行）：
#      .\tools\setup-staff-richmenu.ps1
#      然後把 Messaging API 的 Channel access token 貼進去
#
#  做三件事：
#    ① 在 LINE 建立一張「職員版」圖文選單（六格，前五格跟客人版一樣）
#    ② 把 assets/brand/fff-richmenu-staff.png 上傳上去當底圖
#    ③ 把它綁到七位職員的 LINE 帳號
#
#  ☢️ 客人【完全不受影響】。預設的圖文選單一動也沒動 ——
#     只有被綁定的那七個人會看到職員版，其他人看到的還是原本那張。
#
#  ☢️ 這一支要的是 Channel secret，不是 token。
#     OA Manager → 設定 → Messaging API → Channel secret（就在 Channel ID 下面）
#     程式會自己拿它去換一張 30 天的 token。
#     ☢️ 所以【不需要 LINE Developers Console 的權限】——
#        2026-08-19 查出來那個 channel 掛在別人的 Provider 底下，進不去。
#        換 token 這條路繞過那個問題。
#
#  ☢️ 換新 token【不會】讓現有的 token 失效，所以不會弄壞任何正在跑的東西。
#  ☢️ secret 不要存進檔案、不要貼進 git。這支程式只在記憶體裡用它。
# ═══════════════════════════════════════════════════════════════════

# ☢️ PowerShell 5.1 預設可能用 TLS 1.0，LINE 的 API 只收 1.2 以上。
#    不設這一行的話會是「無法建立 SSL/TLS 安全通道」——
#    那個錯誤訊息完全看不出跟 TLS 版本有關。
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ErrorActionPreference = 'Stop'
$CHANNEL_ID = '2009245280'
$LIFF = 'https://liff.line.me/2011063116-QOxXN30h/'
$IMG  = Join-Path $PSScriptRoot '..\assets\brand\fff-richmenu-staff.png'

# ── 七位職員（櫃檯平板還沒開通，所以不在名單上）──────────────────
# ☢️☢️ 這裡【必須填 Messaging API 那個 Provider 的編號】。
#    我們資料庫裡那七個編號是 LINE Login channel（FUSIONFORCE）給的，
#    而圖文選單屬於另一個 Provider —— 同一個人在兩邊是【不同的編號】。
#    直接把舊的貼過來，七個全部都會 404。
#    先跑 probe-line-ids.ps1 把正確的編號找出來，再填進這裡。
$STAFF = @(
  # @{ name = 'Jerec';    id = 'U...' },
  # @{ name = 'VC';       id = 'U...' },
  # @{ name = 'Peter';    id = 'U...' },
  # @{ name = 'Jessica';  id = 'U...' },
  # @{ name = 'Johnson';  id = 'U...' },
  # @{ name = '簡基城';   id = 'U...' },
  # @{ name = '林智謙';   id = 'U...' }
)

# ── 六格的座標 ───────────────────────────────────────────────────
# ☢️ 2500 除以 3 除不盡（833.33）。中間那格給 834，總和才會剛好是 2500。
#    差一個像素，LINE 會直接拒絕整張選單。
$AREAS = @(
  @{ bounds = @{ x = 0;    y = 0;   width = 833; height = 843 }
     action = @{ type = 'uri'; label = '團體課預約'; uri = $LIFF + 'GT-booking.html' } },
  @{ bounds = @{ x = 833;  y = 0;   width = 834; height = 843 }
     action = @{ type = 'uri'; label = '我的預約';   uri = $LIFF + 'GT-booking.html?tab=m' } },
  @{ bounds = @{ x = 1667; y = 0;   width = 833; height = 843 }
     action = @{ type = 'uri'; label = '私人教練課'; uri = $LIFF + 'PT-booking.html' } },
  @{ bounds = @{ x = 0;    y = 843; width = 833; height = 843 }
     action = @{ type = 'uri'; label = '私人團體班'; uri = $LIFF + 'PGT-booking.html' } },
  @{ bounds = @{ x = 833;  y = 843; width = 834; height = 843 }
     action = @{ type = 'uri'; label = '價目表';     uri = $LIFF + 'pricing.html' } },
  # ★ 這一格就是差別所在：客人版是傳訊息，職員版直接進教練入口
  @{ bounds = @{ x = 1667; y = 843; width = 833; height = 843 }
     action = @{ type = 'uri'; label = 'STAFF 入口'; uri = $LIFF + 'staff.html' } }
)

$MENU = @{
  size        = @{ width = 2500; height = 1686 }
  selected    = $false          # ☢️ 不能設 true —— 那會把它變成【全部使用者】的預設選單
  name        = 'FFF 職員選單 v1'
  chatBarText = '教練選單'
  areas       = $AREAS
}

# ── 開始 ─────────────────────────────────────────────────────────
Write-Host ''
Write-Host '── 職員專屬圖文選單 ──────────────────────────────' -ForegroundColor Cyan
Write-Host ''

if ($STAFF.Count -eq 0) {
  Write-Host '☢️ 職員名單是空的。' -ForegroundColor Red
  Write-Host '   先跑 .\tools\probe-line-ids.ps1 找出七個人的編號，'
  Write-Host '   把它們填進這支程式上面的 $STAFF，再回來執行。'
  exit 1
}

if (-not (Test-Path $IMG)) {
  Write-Host "☢️ 找不到底圖：$IMG" -ForegroundColor Red
  Write-Host '   先在 assets/brand 執行 python3 shot-staff.py 產生它。'
  exit 1
}
$imgSize = (Get-Item $IMG).Length
Write-Host ("底圖：{0}  {1:N0} KB" -f (Split-Path $IMG -Leaf), ($imgSize / 1KB))
if ($imgSize -ge 1MB) {
  Write-Host '☢️ 超過 LINE 的 1 MB 上限，會被拒絕。' -ForegroundColor Red
  exit 1
}

$sec = Read-Host '貼上 Channel secret（OA Manager → 設定 → Messaging API）' -AsSecureString
$SECRET = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
if (-not $SECRET) { Write-Host '☢️ 沒有輸入，停止。' -ForegroundColor Red; exit 1 }

Write-Host ''
Write-Host '⓪ 換 token…' -NoNewline
try {
  $body = "grant_type=client_credentials&client_id=$CHANNEL_ID&client_secret=$SECRET"
  $t = Invoke-RestMethod -Method Post -Uri 'https://api.line.me/v2/oauth/accessToken' `
        -ContentType 'application/x-www-form-urlencoded' -Body $body
  $TOKEN = $t.access_token
  Write-Host ("  ✓ 有效 {0} 天" -f [int]($t.expires_in / 86400)) -ForegroundColor Green
} catch {
  Write-Host '  ☢️ 失敗（400 通常是 secret 貼錯或前後有空白）' -ForegroundColor Red
  Write-Host "     $($_.Exception.Message)"
  exit 1
}

$H = @{ Authorization = "Bearer $TOKEN" }

# ── ① 建立選單 ───────────────────────────────────────────────────
Write-Host ''
Write-Host '① 建立選單…' -NoNewline
try {
  $json  = $MENU | ConvertTo-Json -Depth 10 -Compress
  # ☢️ 一定要自己轉成 UTF-8 位元組。PS 5.1 的 Invoke-RestMethod 送字串時
  #    預設不是 UTF-8，中文的 name / label 會變成亂碼傳過去。
  $bytes = [Text.Encoding]::UTF8.GetBytes($json)
  $r = Invoke-RestMethod -Method Post -Uri 'https://api.line.me/v2/bot/richmenu' `
        -Headers $H -ContentType 'application/json' -Body $bytes
  $MENU_ID = $r.richMenuId
  Write-Host "  ✓ $MENU_ID" -ForegroundColor Green
} catch {
  Write-Host '  ☢️ 失敗' -ForegroundColor Red
  Write-Host "     $($_.Exception.Message)"
  Write-Host '     401 = token 拿錯 channel（要 Messaging API 那個，不是 LINE Login）'
  exit 1
}

# ── ② 上傳底圖 ───────────────────────────────────────────────────
# ☢️ 網域是 api-data.line.me，不是 api.line.me。用錯會 404，
#    而 404 看起來像「選單不存在」，其實選單好好的。
Write-Host '② 上傳底圖…' -NoNewline
try {
  Invoke-RestMethod -Method Post `
    -Uri "https://api-data.line.me/v2/bot/richmenu/$MENU_ID/content" `
    -Headers $H -ContentType 'image/png' -InFile $IMG | Out-Null
  Write-Host '  ✓' -ForegroundColor Green
} catch {
  Write-Host '  ☢️ 失敗' -ForegroundColor Red
  Write-Host "     $($_.Exception.Message)"
  Write-Host "     選單已經建立了（$MENU_ID）但沒有圖，記得刪掉再重來："
  Write-Host "     Invoke-RestMethod -Method Delete -Uri 'https://api.line.me/v2/bot/richmenu/$MENU_ID' -Headers @{Authorization='Bearer <token>'}"
  exit 1
}

# ── ③ 綁到七位職員 ───────────────────────────────────────────────
Write-Host '③ 綁定職員…'
$ok = 0; $ng = 0
foreach ($s in $STAFF) {
  Write-Host ("   {0,-8}" -f $s.name) -NoNewline
  try {
    Invoke-RestMethod -Method Post `
      -Uri "https://api.line.me/v2/bot/user/$($s.id)/richmenu/$MENU_ID" `
      -Headers $H | Out-Null
    Write-Host ' ✓' -ForegroundColor Green
    $ok++
  } catch {
    Write-Host " ☢️ $($_.Exception.Message)" -ForegroundColor Red
    $ng++
  }
}

Write-Host ''
Write-Host "完成：$ok 位綁上，$ng 位失敗" -ForegroundColor Cyan
Write-Host "選單編號（要解除或改圖時會用到）：$MENU_ID"
Write-Host ''
Write-Host '☢️ 如果全部都失敗而且訊息是 404：'
Write-Host '   代表 LINE Login channel 和 Messaging API channel 不在同一個 provider，'
Write-Host '   兩邊的 userId 是不同的。那就要改從 Messaging API 的 webhook 收 userId。'
Write-Host ''
Write-Host '── 要解除某一位（讓他回到客人版選單）───────────────'
Write-Host '   Invoke-RestMethod -Method Delete -Headers @{Authorization="Bearer <token>"} `'
Write-Host '     -Uri "https://api.line.me/v2/bot/user/<userId>/richmenu"'
Write-Host ''
