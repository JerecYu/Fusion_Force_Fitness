"""
重新產生 LINE 圖文選單底圖：
    python3 shot.py

☢️ 四個保險絲，任何一個不過就直接中斷，不要把壞圖傳上 LINE：
   ① 尺寸必須是 2500×1686 —— 差一個像素，LINE 後台六個可點區域就全部錯位
   ② 檔案必須小於 1 MB —— LINE 的硬限制。純漸層的 PNG 很容易爆掉
   ③ 文字對比必須 ≥ 4.5:1 —— 手機上副標只有 13pt，算小字
   ④ ③ 用的色碼必須真的出現在 richmenu-source.html 裡

☢️ ④ 這一條是 2026-08-22 加的，而且它才是重點。
   v2 的時候對比只寫在註解裡「都驗過」—— 那等於沒驗：
   改了 CSS 的顏色，註解不會跟著變，而下一個人會相信它。
   現在改成【從 HTML 裡找那些色碼】，找不到就中斷 ——
   換了顏色卻忘了更新這裡，會當場被擋下來，不會默默通過。
"""
import pathlib, re
from playwright.sync_api import sync_playwright
from PIL import Image

OUT   = 'fff-richmenu.png'
SRC   = 'richmenu-source.html'
W, H  = 2500, 1686
LIMIT = 1024 * 1024        # LINE 的 1 MB 上限
PHONE = 390                # iPhone 邏輯寬度，選單滿版

# ── ③④ 對比 ────────────────────────────────────────────────────
# 前景 → 要驗的背景（每一階漸層【最深】的那一端，最不利的情況）
INK, SUB = '#23414E', '#4E6B77'
BGS = ['#F4EEE5', '#E9F2F5', '#E9EFEB']
MIN_RATIO = 4.5

def _lin(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def lum(hex_):
    r, g, b = (int(hex_[i:i+2], 16) for i in (1, 3, 5))
    return 0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b)

def ratio(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)

html = pathlib.Path(SRC).read_text(encoding='utf-8')
for c in [INK, SUB] + BGS:
    assert c.lower() in html.lower(), \
        f'{c} 沒有出現在 {SRC} 裡 —— 顏色改過了，這支檔案要跟著改，不然對比檢查是假的'

for fg, name in ((INK, '標題'), (SUB, '副標')):
    for bg in BGS:
        r = ratio(fg, bg)
        assert r >= MIN_RATIO, f'{name} {fg} 在 {bg} 上只有 {r:.2f}:1，低於 {MIN_RATIO}:1'
        print(f'  對比 {name} {fg} / {bg} = {r:.2f}:1')

# ── 截圖 ────────────────────────────────────────────────────────
src = pathlib.Path(SRC).resolve()
with sync_playwright() as p:
    b  = p.chromium.launch()
    pg = b.new_page(viewport={'width': W, 'height': H}, device_scale_factor=1)
    pg.goto(src.as_uri())
    pg.wait_for_timeout(900)          # 等字體上好（襯線體比較慢）
    pg.screenshot(path='/tmp/_raw.png')
    b.close()

im = Image.open('/tmp/_raw.png').convert('RGB')

# ① 尺寸
assert im.size == (W, H), f'尺寸 {im.size} 不是 {(W, H)} —— 六個按鈕位置會全部跑掉'

# ② 壓到 1 MB 以內。256 色調色盤：平均誤差比 JPEG q95 低，
#    而且文字邊緣不會有 JPEG 的振鈴。
im.quantize(colors=256, method=Image.MEDIANCUT,
            dither=Image.FLOYDSTEINBERG).save(OUT, optimize=True)
size = pathlib.Path(OUT).stat().st_size
assert size < LIMIT, f'{size/1024:.0f} KB 超過 LINE 的 1 MB 上限'

# 手機模擬圖：這才是客人真正看到的大小
Image.open(OUT).resize((PHONE, round(H * PHONE / W)), Image.LANCZOS).save('phone-v3.png')

print(f'✓ {OUT}  {im.size}  {size/1024:.0f} KB（上限 1024 KB）')
print(f'✓ 手機上：標題 {148*PHONE/W:.1f}pt　副標 {84*PHONE/W:.1f}pt'
      f'（v2 是 23.1pt / 11.2pt）')
print('✓ phone-v3.png = 客人手機上的實際大小')
print('☢️ 這一版換了六格順序 —— LINE 後台的六個動作【一定要重設】，'
      '見 richmenu-source.html 開頭的對應表')
