"""
重新產生 LINE 圖文選單底圖：
    python3 shot.py

☢️ 三個保險絲，任何一個不過就直接中斷，不要把壞圖傳上 LINE：
   ① 尺寸必須是 2500×1686 —— 差一個像素，LINE 後台六個可點區域就全部錯位
   ② 檔案必須小於 1 MB —— LINE 的硬限制
   ③ 文字對比必須 ≥ 4.5:1 —— 手機上副標只有 13pt，算小字

☢️☢️ ③ 是【從真的算出來的圖上取樣】，不是拿宣告的色碼去算。
   v2 把「都驗過」寫在註解裡 —— 那等於沒驗，改了顏色註解不會跟著變。
   v3 改成從 HTML 裡找色碼 —— 好一點，但底色一旦變成漸層或疊色，
   宣告值就不等於實際值了。
   v4 改成：再截一張【把文字和圖示藏起來】的圖，
   在每一格的文字區域裡找【最深的那個背景像素】，拿它去算對比。
   取樣才問得出真話。
"""
import pathlib
from playwright.sync_api import sync_playwright
from PIL import Image

OUT   = 'fff-richmenu.png'
SRC   = 'richmenu-source.html'
W, H  = 2500, 1686
CW, CH = W // 3, H // 2      # 每格 833 × 843
PAD   = 78                   # 跟 CSS 的 padding 對齊
LIMIT = 1024 * 1024
PHONE = 390
MIN_RATIO = 4.5

# 前景色（要跟 CSS 的 --ink / --sub 一致；不一致下面的斷言會抓到）
INK, SUB = '#FFFFFF', '#E4F2F7'

def _lin(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def lum(rgb):
    r, g, b = rgb
    return 0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b)

def ratio(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)

def hex2rgb(h):
    return tuple(int(h[i:i+2], 16) for i in (1, 3, 5))

html = pathlib.Path(SRC).read_text(encoding='utf-8')
for c in (INK, SUB):
    assert c.lower() in html.lower(), \
        f'{c} 沒有出現在 {SRC} 裡 —— 顏色改過了，這支檔案要跟著改，不然對比檢查是假的'

src = pathlib.Path(SRC).resolve()
with sync_playwright() as p:
    b  = p.chromium.launch()
    pg = b.new_page(viewport={'width': W, 'height': H}, device_scale_factor=1)
    pg.goto(src.as_uri())
    pg.wait_for_timeout(900)                 # 等襯線字體上好
    pg.screenshot(path='/tmp/_raw.png')
    # ☢️ 第二張：只留背景。文字和圖示藏起來，才取樣得到「字底下是什麼顏色」
    pg.add_style_tag(content='.t,.s,.ico{visibility:hidden !important}')
    pg.wait_for_timeout(200)
    pg.screenshot(path='/tmp/_bg.png')
    b.close()

im = Image.open('/tmp/_raw.png').convert('RGB')
assert im.size == (W, H), f'尺寸 {im.size} 不是 {(W, H)} —— 六個按鈕位置會全部跑掉'

# ── ③ 對比：每一格文字區域裡最深的背景像素 ────────────────────
bg = Image.open('/tmp/_bg.png').convert('RGB')
worst = None
for row in range(2):
    for col in range(3):
        # ☢️ 只取【文字真的在的那一塊】。整格內框都取的話，
        #    右下角的裝飾也會被算進去 —— 那裡沒有字，用它去否決設計是誤判。
        #    這個框比實際字塊四邊各多留 ~40px。
        box = (col * CW + PAD, row * CH + 170, col * CW + PAD + 660, row * CH + 690)
        patch = bg.crop(box)
        px = list(patch.getdata())[::7]           # 抽樣就夠，不必每一點
        # ☢️ 最不利的那一點【不一定是最暗的】。
        #    深字淺底 → 最暗的底最危險；白字深底 → 最亮的底最危險。
        #    兩端都算，取比較差的那個 —— 這樣不管哪一種配色都問得出真話。
        #    （v4 只取最暗，換成深藍底之後會全部「通過」，其實是算錯邊。）
        lo, hi = min(px, key=lum), max(px, key=lum)
        ri = min(ratio(hex2rgb(INK), lo), ratio(hex2rgb(INK), hi))
        rs = min(ratio(hex2rgb(SUB), lo), ratio(hex2rgb(SUB), hi))
        worstpx = lo if ratio(hex2rgb(SUB), lo) < ratio(hex2rgb(SUB), hi) else hi
        tag = '第%d格' % (row * 3 + col + 1)
        print(f'  {tag} 最不利底色 #%02X%02X%02X ｜標題 {ri:.2f}:1 ｜副標 {rs:.2f}:1' % worstpx)
        assert ri >= MIN_RATIO, f'{tag} 標題對比只有 {ri:.2f}:1'
        assert rs >= MIN_RATIO, f'{tag} 副標對比只有 {rs:.2f}:1'
        worst = rs if worst is None else min(worst, rs)

# ── ② 壓到 1 MB 以內 ──────────────────────────────────────────
im.quantize(colors=256, method=Image.MEDIANCUT,
            dither=Image.FLOYDSTEINBERG).save(OUT, optimize=True)
size = pathlib.Path(OUT).stat().st_size
assert size < LIMIT, f'{size/1024:.0f} KB 超過 LINE 的 1 MB 上限'

Image.open(OUT).resize((PHONE, round(H * PHONE / W)), Image.LANCZOS).save('phone-v5.png')

print(f'✓ {OUT}  {im.size}  {size/1024:.0f} KB（上限 1024 KB）')
print(f'✓ 最差的對比 {worst:.2f}:1（下限 {MIN_RATIO}:1）')
print(f'✓ 手機上：標題 {148*PHONE/W:.1f}pt　副標 {84*PHONE/W:.1f}pt')
print('✓ phone-v5.png = 客人手機上的實際大小')
print('☢️ 六格順序與 v3 相同 —— 已經照 v3 設好動作的話，這一版不用再改 LINE 後台')
