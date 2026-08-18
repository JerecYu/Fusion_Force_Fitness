"""
重新產生【職員版】LINE 圖文選單底圖：
    python3 shot-staff.py

☢️ 跟 shot.py 同一套保險絲，理由見那支的註解：
   ① 尺寸必須是 2500×1686　② 檔案 < 1 MB　③ 白字對比 ≥ 4.5:1
☢️ 兩張圖的【格線必須完全一樣】—— 六個可點區域是照 833×843 切的，
   職員版只是換了第六格的字，網格一動所有按鈕就錯位。
"""
import pathlib
from playwright.sync_api import sync_playwright
from PIL import Image

OUT   = 'fff-richmenu-staff.png'
W, H  = 2500, 1686
LIMIT = 1024 * 1024
PHONE = 390

src = pathlib.Path('richmenu-staff-source.html').resolve()
with sync_playwright() as p:
    b  = p.chromium.launch()
    pg = b.new_page(viewport={'width': W, 'height': H}, device_scale_factor=1)
    pg.goto(src.as_uri())
    pg.wait_for_timeout(600)
    pg.screenshot(path='/tmp/_raw_staff.png')
    b.close()

im = Image.open('/tmp/_raw_staff.png').convert('RGB')
assert im.size == (W, H), f'尺寸 {im.size} 不是 {(W, H)} —— 六個按鈕位置會全部跑掉'

im.quantize(colors=256, method=Image.MEDIANCUT,
            dither=Image.FLOYDSTEINBERG).save(OUT, optimize=True)
size = pathlib.Path(OUT).stat().st_size
assert size < LIMIT, f'{size/1024:.0f} KB 超過 LINE 的 1 MB 上限'

Image.open(OUT).resize((PHONE, round(H * PHONE / W)), Image.LANCZOS).save('phone-staff.png')
print(f'✓ {OUT}  {im.size}  {size/1024:.0f} KB（上限 1024 KB）')
print(f'✓ 手機上：STAFF 入口那一行 {62*PHONE/W:.1f}pt')
print('✓ phone-staff.png = 教練手機上的實際大小')
