"""Şeffaf alanları doldurur: gökyüzü resmi (art/drive/sky.png) ya da düz renk.
  python3 tools/fill_sky.py girdi.png çıktı.png [--sky art/drive/sky.png] [--color #0e0b10]
      [--box x0,y0,x1,y1,#rrggbb ...] [--below y,#rrggbb] [--width 344]
Önce --box kutuları (ör. ışıklı cam), sonra --below (zemin), kalan boşluklar gökyüzü olur.
"""
import argparse
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("src"); ap.add_argument("dst")
ap.add_argument("--sky", default="")
ap.add_argument("--color", default="#0e0b10")
ap.add_argument("--box", action="append", default=[])
ap.add_argument("--below", default="")
ap.add_argument("--width", type=int, default=0)
a = ap.parse_args()
im = Image.open(a.src).convert("RGBA")
if a.width and a.width > im.width:
    pad = Image.new("RGBA", (a.width, im.height), (0, 0, 0, 0)); pad.paste(im, (0, 0)); im = pad
W, H = im.size
def hexc(h): h = h.lstrip("#"); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4)) + (255,)
base = Image.new("RGBA", (W, H), hexc(a.color))
if a.sky:
    sky = Image.open(a.sky).convert("RGBA")
    base.alpha_composite(sky.crop((0, 0, min(W, sky.width), min(H, sky.height))))
px = im.load(); bp = base.load()
boxes = [(list(map(int, b.split(",")[:4])), hexc(b.split(",")[4])) for b in a.box]
below = (int(a.below.split(",")[0]), hexc(a.below.split(",")[1])) if a.below else None
out = Image.new("RGBA", (W, H))
op = out.load()
for y in range(H):
    for x in range(W):
        r, g, b, al = px[x, y]
        fill = None
        for (x0, y0, x1, y1), c in boxes:
            if x0 <= x < x1 and y0 <= y < y1:
                fill = c; break
        if fill is None and below and y >= below[0]:
            fill = below[1]
        if fill is None:
            fill = bp[x, y]
        t = al / 255.0
        op[x, y] = tuple(int(fill[i] * (1 - t) + (r, g, b)[i] * t) for i in range(3)) + (255,)
out.save(a.dst)
print("ok", a.dst, out.size)
