"""art/oscar.png'den 4 karelik yürüme şeridi üretir: art/oscar_walk.png (128x48).
Bacaklar sırayla kalkar, ön kol ve palto eteği ters yönde sallanır, gövde hafif iner kalkar.
Başka 32x48 karakter için: python3 tools/make_walk.py art/harold.png art/harold_walk.png
Bölge sınırları Oscar'a göre ayarlı; başka karakterde ARM ve HEM değerlerini değiştir.
"""
import sys
from PIL import Image

src = sys.argv[1] if len(sys.argv) > 1 else "art/oscar.png"
dst = sys.argv[2] if len(sys.argv) > 2 else "art/oscar_walk.png"
LEG_TOP = 40                 # bacakların başladığı satır
SPLIT_X = 15                 # sol / sağ bacak ayrımı
ARM = (4, 15, 13, 39)        # ön kol bölgesi (x0, y0, x1, y1)
HEM = (5, 32, 24, 40)        # palto eteği bölgesi

im = Image.open(src).convert("RGBA")
W, H = im.size
body = im.crop((0, 0, W, LEG_TOP))
left = im.crop((0, LEG_TOP, SPLIT_X, H))
right = im.crop((SPLIT_X, LEG_TOP, W, H))
arm = im.crop(ARM)
hem = im.crop(HEM)


def frame(lx, ly, rx, ry, arm_dx, arm_dy, hem_dx, bob):
    f = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    f.alpha_composite(left, (lx, LEG_TOP + ly))
    f.alpha_composite(right, (SPLIT_X + rx, LEG_TOP + ry))
    f.alpha_composite(body, (0, bob))
    f.alpha_composite(hem, (HEM[0] + hem_dx, HEM[1] + bob))   # etek sallanır
    f.alpha_composite(arm, (ARM[0] + arm_dx, ARM[1] + arm_dy + bob))  # kol sallanır
    return f


frames = [
    #     sol bacak  sağ bacak  kol      etek  gövde
    frame(-2, 0,     2, 0,      1, 0,    -1,   0),   # adım: kol öne
    frame(-1, -2,    1, 0,      0, -1,    0,  -1),   # sol bacak havada, gövde yukarı
    frame(-2, 0,     2, 0,     -1, 0,     1,   0),   # adım: kol arkaya
    frame(-1, 0,     1, -2,     0, -1,    0,  -1),   # sağ bacak havada, gövde yukarı
]
sheet = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
for i, f in enumerate(frames):
    sheet.alpha_composite(f, (i * W, 0))
sheet.save(dst)
print("ok", dst, sheet.size)
