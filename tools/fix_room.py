"""Fill transparent holes in a PixelLab room image and remap it to the game palette.

PixelLab sometimes returns scenes with the background removed (walls and floor
transparent). This fills the holes with a wall tone above `floor_y` and a floor
tone below it, optionally lightens a spotlight cone, then maps every pixel's
brightness onto the black/brown/yellow ramp so all rooms share one look.

Usage: python3 tools/fix_room.py in.png out.png --floor 145 [--cone ax,ay,x0,x1,by] [--dark-left 19 --dark-top 6]
       [--keep] [--fill x0,y0,x1,y1,lum ...] [--glow cx,cy,r,lum ...]
"""
import argparse
from PIL import Image

RAMP = [(15, 11, 8), (43, 29, 20), (90, 61, 43), (138, 106, 79), (196, 160, 98), (232, 197, 71), (242, 227, 179)]


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def ramp(l):
    l = max(0.0, min(1.0, l)) * (len(RAMP) - 1)
    i = min(int(l), len(RAMP) - 2)
    return lerp(RAMP[i], RAMP[i + 1], l - i)


def in_cone(x, y, cone):
    ax, ay, x0, x1, by = cone
    if y < ay or y > by:
        return False
    t = (y - ay) / (by - ay)
    return ax + (x0 - ax) * t <= x <= ax + (x1 - ax) * t


def main():
    p = argparse.ArgumentParser()
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("--floor", type=int, required=True)
    p.add_argument("--cone", type=str, default="")
    p.add_argument("--wall", type=float, default=0.42)
    p.add_argument("--tile", type=float, default=0.55)
    p.add_argument("--light", type=float, default=0.78)
    p.add_argument("--dark-left", type=int, default=0, help="transparent columns left of this become black")
    p.add_argument("--dark-top", type=int, default=0, help="transparent rows above this become black")
    p.add_argument("--keep", action="store_true", help="keep the drawn pixels' colors, only fill holes")
    p.add_argument("--fill", action="append", default=[], help="x0,y0,x1,y1,lum: holes in this box get this brightness")
    p.add_argument("--glow", action="append", default=[], help="cx,cy,r,lum: holes in this circle get this brightness")
    a = p.parse_args()
    fills = [tuple(float(v) for v in f.split(",")) for f in a.fill]
    glows = [tuple(float(v) for v in g.split(",")) for g in a.glow]
    cone = tuple(int(v) for v in a.cone.split(",")) if a.cone else None
    im = Image.open(a.src).convert("RGBA")
    w, h = im.size
    out = Image.new("RGB", (w, h))
    src, dst = im.load(), out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, al = src[x, y]
            lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            if al < 128:
                lum = a.wall if y < a.floor else a.tile
                if cone and in_cone(x, y, cone):
                    lum = a.light
                for x0, y0, x1, y1, fl in fills:
                    if x0 <= x < x1 and y0 <= y < y1:
                        lum = fl
                for cx, cy, r, gl in glows:
                    d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                    if d < r:
                        lum = max(lum, gl * (1 - 0.5 * d / r))
                if x < a.dark_left or y < a.dark_top:
                    lum = 0.0
                elif y >= a.floor:
                    lum -= 0.12 * (y - a.floor) / max(1, h - a.floor)  # darker toward camera
            elif a.keep:
                dst[x, y] = (r, g, b)
                continue
            else:
                lum = lum * 0.9
            dst[x, y] = ramp(lum)
    out.save(a.dst)


if __name__ == "__main__":
    main()
