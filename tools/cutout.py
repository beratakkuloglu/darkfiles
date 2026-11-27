"""Remove only the white background of an item image; keep every other pixel.

Flood fill from the corners (and optional seed points for enclosed holes,
like the inside of a cup handle), crop, shrink to --size with a box filter.
No palette reduction, so the drawing keeps its detail.

  python3 tools/cutout.py both.webp art/items/fincan.png --half left --seeds 0.09,0.40 --size 192
"""
import argparse
from collections import deque
from PIL import Image


def flood(im, seeds, tol):
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    ref = px[0, 0][:3]
    q = deque(seeds)
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y * w + x]:
            continue
        seen[y * w + x] = 1
        c = px[x, y][:3]
        if sum(abs(c[i] - ref[i]) for i in range(3)) > tol:
            continue
        px[x, y] = (0, 0, 0, 0)
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("--half", choices=["left", "right"])
    p.add_argument("--seeds", default="", help="x,y;x,y as fractions of the (half) image")
    p.add_argument("--tol", type=int, default=45)
    p.add_argument("--size", type=int, default=192)
    a = p.parse_args()
    im = Image.open(a.src).convert("RGBA")
    if a.half == "left":
        im = im.crop((0, 0, im.width // 2, im.height))
    elif a.half == "right":
        im = im.crop((im.width // 2, 0, im.width, im.height))
    w, h = im.size
    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    for s in filter(None, a.seeds.split(";")):
        fx, fy = (float(v) for v in s.split(","))
        seeds.append((int(fx * w), int(fy * h)))
    flood(im, seeds, a.tol)
    # soften the edge: semi-transparent fringe pixels next to the background
    im = im.crop(im.getchannel("A").getbbox())
    im.thumbnail((a.size, a.size), Image.LANCZOS)
    out = Image.new("RGBA", (a.size, a.size))
    out.paste(im, ((a.size - im.width) // 2, (a.size - im.height) // 2))
    alpha = out.getchannel("A").point(lambda v: 255 if v > 110 else 0)
    out.putalpha(alpha)
    out.save(a.dst)


if __name__ == "__main__":
    main()
