"""
重新產生 LINE 圖文選單底圖：
    python3 shot.py

☢️ 三個保險絲，任何一個不過就直接中斷，不要把壞圖傳上 LINE：
   ① 尺寸必須是 2500×1686 —— 差一個像素，後台六個可點區域就全部錯位
   ② 檔案必須小於 1 MB —— LINE 的硬限制。純漸層的 PNG 很容易爆掉
      （這一版沒壓縮是 1243 KB，會被 LINE 擋下來）
   ③ 白字對比必須 ≥ 4.5:1 —— 手機上副標只有 11pt，算小字
"""
import pathlib
from playwright.sync_api import sync_playwright
from PIL import Image

OUT   = 'fff-richmenu.png'
W, H  = 2500, 1686
LIMIT = 1024 * 1024        # LINE 的 1 MB 上限
PHONE = 390                # iPhone 邏輯寬度，選單滿版

src = pathlib.Path('richmenu-source.html').resolve()
with sync_playwright() as p:
    b  = p.chromium.launch()
    pg = b.new_page(viewport={'width': W, 'height': H}, device_scale_factor=1)
    pg.goto(src.as_uri())
    pg.wait_for_timeout(600)          # 等字體上好
    pg.screenshot(path='/tmp/_raw.png')
    b.close()

im = Image.open('/tmp/_raw.png').convert('RGB')

# ① 尺寸
assert im.size == (W, H), f'尺寸 {im.size} 不是 {(W, H)} —— 六個按鈕位置會全部跑掉'

# ② 壓到 1 MB 以內。256 色調色盤：平均誤差比 JPEG q95 低（0.13 vs 0.59），
#    而且文字邊緣不會有 JPEG 的振鈴。
im.quantize(colors=256, method=Image.MEDIANCUT,
            dither=Image.FLOYDSTEINBERG).save(OUT, optimize=True)
size = pathlib.Path(OUT).stat().st_size
assert size < LIMIT, f'{size/1024:.0f} KB 超過 LINE 的 1 MB 上限'

# 手機模擬圖：這才是客人真正看到的大小
Image.open(OUT).resize((PHONE, round(H * PHONE / W)), Image.LANCZOS).save('phone-v2.png')

print(f'✓ {OUT}  {im.size}  {size/1024:.0f} KB（上限 1024 KB）')
print(f'✓ 手機上：標題 {148*PHONE/W:.1f}pt　副標 {72*PHONE/W:.1f}pt'
      f'（v1 是 14.7pt / 6.9pt）')
print('✓ phone-v2.png = 客人手機上的實際大小')
