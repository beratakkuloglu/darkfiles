"""Turn an ordinary AI image (ChatGPT, Gemini...) into game-ready pixel art.

Steps: optional background removal (flood fill from the corners over colors
close to the corner color), crop to the object, shrink to the target size with
a box filter, then reduce to a small palette so it reads as pixel art.

Usage:
  python3 tools/pixelize.py in.png art/items/kupe.png --size 64 --remove-bg
  python3 tools/pixelize.py both.png art/items/kupe_back.png --half right --remove-bg
  python3 tools/pixelize.py in.png art/rooms/depo.png --size 344x192
"""
import argparse
from collections import deque
from PIL import Image


def remove_bg(im, tol):
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    q = deque([(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)])
    ref = [px[x, y][:3] for x, y in q]
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y * w + x]:
            continue
        seen[y * w + x] = 1
        c = px[x, y][:3]
        if min(sum(abs(c[i] - r[i]) for i in range(3)) for r in ref) > tol:
            continue
        px[x, y] = (0, 0, 0, 0)
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return im


def main():
    p = argparse.ArgumentParser()
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("--size", default="64", help="64 (square, keeps aspect inside) or WxH (fills exactly)")
    p.add_argument("--remove-bg", action="store_true")
    p.add_argument("--tol", type=int, default=60)
    p.add_argument("--colors", type=int, default=24)
    p.add_argument("--half", choices=["left", "right"], help="use only one half (front/back views side by side)")
    a = p.parse_args()
    im = Image.open(a.src).convert("RGBA")
    if a.half == "left":
        im = im.crop((0, 0, im.width // 2, im.height))
    elif a.half == "right":
        im = im.crop((im.width // 2, 0, im.width, im.height))
    if a.remove_bg:
        im = remove_bg(im, a.tol)
        box = im.getchannel("A").point(lambda v: 255 if v > 0 else 0).getbbox()
        if box:
            im = im.crop(box)
    if "x" in a.size:
        tw, th = (int(v) for v in a.size.split("x"))
        out = im.resize((tw, th), Image.BOX)
    else:
        n = int(a.size)
        im.thumbnail((n, n), Image.BOX)
        out = Image.new("RGBA", (n, n))
        out.paste(im, ((n - im.width) // 2, (n - im.height) // 2))
    alpha = out.getchannel("A").point(lambda v: 255 if v > 128 else 0)
    rgb = out.convert("RGB").quantize(colors=a.colors, method=Image.Quantize.MEDIANCUT).convert("RGB")
    rgb.putalpha(alpha)
    rgb.save(a.dst)


if __name__ == "__main__":
    main()
