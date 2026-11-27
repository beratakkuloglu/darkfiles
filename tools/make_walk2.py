"""Kolu sallanmayan karakterler için (Maya gibi, eller cepte/belde) temiz 4 kare yürüme.
Sadece bacaklar adım atar, palto eteği hafifçe sallanır, gövde iner kalkar.
Etek bölgesi gövdeden silinip ayrı kaydırıldığı için iz/kalıntı kalmaz.

Kullanım:
  python3 tools/make_walk2.py art/maya.png art/maya_walk.png --leg-top 39 --split 17 --hem 33
--leg-top: bacakların başladığı satır, --split: arka/ön bacak ayrım sütunu,
--hem: palto eteğinin sallanmaya başladığı satır.
"""
import argparse
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("dst")
ap.add_argument("--leg-top", type=int, required=True)
ap.add_argument("--split", type=int, required=True)
ap.add_argument("--hem", type=int, required=True)
a = ap.parse_args()

im = Image.open(a.src).convert("RGBA")
W, H = im.size
L, S, M = a.leg_top, a.split, a.hem
upper = im.crop((0, 0, W, M))
hem = im.crop((0, M, W, L))
back = im.crop((0, L, S, H))
front = im.crop((S, L, W, H))


def frame(bx, by, fx, fy, hem_dx, bob):
    f = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    f.alpha_composite(back, (bx, L + by))
    f.alpha_composite(front, (S + fx, L + fy))
    f.alpha_composite(hem, (hem_dx, M + bob))
    f.alpha_composite(upper, (0, bob))
    return f


frames = [
    #     arka bacak  ön bacak  etek  gövde
    frame(-2, 0,      2, 0,     0,    0),   # geniş adım
    frame(-1, 0,      1, -1,    1,   -1),   # ön ayak havada, geçiş
    frame(1, 0,      -1, 0,     0,    0),   # bacaklar yer değiştirdi
    frame(0, -1,      0, 0,    -1,   -1),   # arka ayak havada, geçiş
]
sheet = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
for i, f in enumerate(frames):
    sheet.alpha_composite(f, (i * W, 0))
sheet.save(a.dst)
print("ok", a.dst, sheet.size)
