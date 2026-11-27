"""Make a 2-frame breathing (idle) strip from a single character sprite.

Frame 1 is the sprite as drawn; in frame 2 everything above `--split` (head
and chest) sinks by one pixel. Output goes next to the input as <name>_idle.png,
which the game plays automatically. Drawn animations can replace these files.

Usage: python3 tools/make_idle.py art/oscar.png [art/gus.png ...] [--split 30]
"""
import argparse
import os
from PIL import Image


def idle_strip(path, split):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    f2 = im.copy()
    top = im.crop((0, 0, w, split))
    f2.paste((0, 0, 0, 0), (0, 0, w, split + 1))
    f2.paste(im.crop((0, split + 1, w, h)), (0, split + 1))
    f2.alpha_composite(top, (0, 1))
    strip = Image.new("RGBA", (w * 2, h))
    strip.paste(im, (0, 0))
    strip.paste(f2, (w, 0))
    root, ext = os.path.splitext(path)
    strip.save(root + "_idle" + ext)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("sprites", nargs="+")
    p.add_argument("--split", type=int, default=30)
    a = p.parse_args()
    for s in a.sprites:
        idle_strip(s, a.split)


if __name__ == "__main__":
    main()
