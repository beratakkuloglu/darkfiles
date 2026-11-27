"""art/oscar.png'den 4 karelik yürüme şeridi üretir: art/oscar_walk.png (128x48).
Bacaklar sırayla kalkar, gövde sabit kalır. Başka 32x48 karakter için de çalışır:
python3 tools/make_walk.py art/harold.png art/harold_walk.png
"""
import sys
from PIL import Image

src = sys.argv[1] if len(sys.argv) > 1 else "art/oscar.png"
dst = sys.argv[2] if len(sys.argv) > 2 else "art/oscar_walk.png"
LEG_TOP = 40   # bacakların başladığı satır
SPLIT_X = 15   # sol / sağ bacak ayrımı

im = Image.open(src).convert("RGBA")
W, H = im.size
body = im.crop((0, 0, W, LEG_TOP))
left = im.crop((0, LEG_TOP, SPLIT_X, H))
right = im.crop((SPLIT_X, LEG_TOP, W, H))


def frame(lx, ly, rx, ry):
    f = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    f.alpha_composite(left, (0 + lx, LEG_TOP + ly))
    f.alpha_composite(right, (SPLIT_X + rx, LEG_TOP + ry))
    f.alpha_composite(body, (0, 0))  # palto bacakların üstünde
    return f


frames = [
    frame(0, 0, 0, 0),
    frame(-1, -2, 1, 0),   # sol bacak havada
    frame(0, 0, 0, 0),
    frame(-1, 0, 1, -2),   # sağ bacak havada
]
sheet = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
for i, f in enumerate(frames):
    sheet.alpha_composite(f, (i * W, 0))
sheet.save(dst)
print("ok", dst, sheet.size)
