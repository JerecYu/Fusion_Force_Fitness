"""
重新產生【職員版】LINE 圖文選單底圖：
    python3 shot-staff.py

☢️☢️ 這支【不再有自己的 HTML】。
   以前是 richmenu-staff-source.html 和 richmenu-source.html 兩份，
   而兩份的開頭都寫著「兩張圖要一起改」—— 那句警告之所以需要存在，
   正是因為有兩份。而它還是失效了：
   客人版在 v3 換了六格順序，職員版沒跟上，兩張圖從此對不起來
   （2026-08-22 Jerec 發現）。

   v5 改成【只有一份設計】：直接讀客人版的 richmenu-source.html，
   在瀏覽器裡把第六格換成「教練工具」，再截圖。
   前五格因此【不可能】不一樣 —— 不是靠人記得，是靠沒有第二份可以改。

☢️ 第六格的動作是 staff.html（教練登入），不是傳訊息給櫃檯。
   舊版那一格畫的是「聯絡我們／傳訊息給櫃檯」，底下才加一行 ★STAFF 入口 ——
   【寫的跟做的不一樣】。教練按下去進的是登入頁，不是聊天室。
   v5 直接把字改成「教練工具」，讓畫面說實話。

☢️ 六格順序改了 → tools/setup-staff-richmenu.ps1 裡的六個動作也要跟著改。
   可點區域綁的是位置，不是圖案。
"""
import pathlib
from playwright.sync_api import sync_playwright
from PIL import Image

OUT   = 'fff-richmenu-staff.png'
SRC   = 'richmenu-source.html'      # ☢️ 跟客人版同一份
W, H  = 2500, 1686
CW, CH = W // 3, H // 2
PAD   = 78
LIMIT = 1024 * 1024
PHONE = 390
MIN_RATIO = 4.5
INK, SUB = '#FFFFFF', '#E4F2F7'

# 第六格換成教練工具：盾牌加星星，一眼看得出「這格是給自己人的」
STAFF_ICON = ('<path d="M50 10 L84 26 V50 C84 72 68 84 50 90 C32 84 16 72 16 50 V26 Z"/>'
              '<path class="fill" d="M50 38 L55 49 L67 50 L58 58 L61 70 L50 63 '
              'L39 70 L42 58 L33 50 L45 49 Z"/>')

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

SWAP = """(icon) => {
  const cells = document.querySelectorAll('.c');
  if (cells.length !== 6) throw new Error('格數不是 6，版面改過了');
  const f = cells[5];
  f.querySelector('.t').textContent = '教練工具';
  f.querySelector('.s').textContent = '登入・點名・登記';
  f.querySelector('.ico').innerHTML = icon;
  return f.querySelector('.t').textContent;
}"""

src = pathlib.Path(SRC).resolve()
with sync_playwright() as p:
    b  = p.chromium.launch()
    pg = b.new_page(viewport={'width': W, 'height': H}, device_scale_factor=1)
    pg.goto(src.as_uri())
    pg.wait_for_timeout(900)
    got = pg.evaluate(SWAP, STAFF_ICON)
    assert got == '教練工具', '第六格沒換成功'
    pg.wait_for_timeout(250)
    pg.screenshot(path='/tmp/_raw_staff.png')
    pg.add_style_tag(content='.t,.s,.ico{visibility:hidden !important}')
    pg.wait_for_timeout(200)
    pg.screenshot(path='/tmp/_bg_staff.png')
    b.close()

im = Image.open('/tmp/_raw_staff.png').convert('RGB')
assert im.size == (W, H), f'尺寸 {im.size} 不是 {(W, H)}'

bg = Image.open('/tmp/_bg_staff.png').convert('RGB')
worst = None
for row in range(2):
    for col in range(3):
        box = (col * CW + PAD, row * CH + 170, col * CW + PAD + 660, row * CH + 690)
        px = list(bg.crop(box).getdata())[::7]
        # ☢️ 最不利不一定是最暗的（白字深底時最亮的才危險）—— 兩端都算
        lo, hi = min(px, key=lum), max(px, key=lum)
        ri = min(ratio(hex2rgb(INK), lo), ratio(hex2rgb(INK), hi))
        rs = min(ratio(hex2rgb(SUB), lo), ratio(hex2rgb(SUB), hi))
        tag = '第%d格' % (row * 3 + col + 1)
        print(f'  {tag} 標題 {ri:.2f}:1 ｜副標 {rs:.2f}:1')
        assert ri >= MIN_RATIO, f'{tag} 標題對比只有 {ri:.2f}:1'
        assert rs >= MIN_RATIO, f'{tag} 副標對比只有 {rs:.2f}:1'
        worst = rs if worst is None else min(worst, rs)

im.quantize(colors=256, method=Image.MEDIANCUT,
            dither=Image.FLOYDSTEINBERG).save(OUT, optimize=True)
size = pathlib.Path(OUT).stat().st_size
assert size < LIMIT, f'{size/1024:.0f} KB 超過 LINE 的 1 MB 上限'

Image.open(OUT).resize((PHONE, round(H * PHONE / W)), Image.LANCZOS).save('phone-staff-v5.png')

print(f'✓ {OUT}  {im.size}  {size/1024:.0f} KB（上限 1024 KB）')
print(f'✓ 最差的對比 {worst:.2f}:1（下限 {MIN_RATIO}:1）')
print('✓ 前五格與客人版【同一份原始檔】產生 —— 不可能不一樣')
print('☢️ 六格順序：私人課／團體課／私人團體／我的預約／價目表／教練工具')
print('☢️ tools/setup-staff-richmenu.ps1 的六個動作要跟這個順序一致')
