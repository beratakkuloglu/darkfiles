"""Geçici karakter sprite'larını üretir (20x48 piksel, oyunun paleti).
Bunlar başlangıç çizimleri: Pixelorama'da açıp üzerine çizebilirsin.
Çalıştırma: python3 tools/make_sprites.py
"""
from PIL import Image

PAL = {
    "k": (15, 11, 8, 255),      # siyah
    "d": (43, 29, 20, 255),     # koyu kahve
    "b": (90, 61, 43, 255),     # kahve
    "l": (138, 106, 79, 255),   # açık kahve
    "y": (232, 197, 71, 255),   # sarı
    "p": (242, 227, 179, 255),  # soluk (ten, gömlek)
    "g": (176, 160, 130, 255),  # kır saç
}
W, H = 20, 48


def new():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def rect(img, x, y, w, h, c):
    for i in range(x, x + w):
        for j in range(y, y + h):
            if 0 <= i < W and 0 <= j < H:
                img.putpixel((i, j), PAL[c])


def px(img, x, y, c):
    rect(img, x, y, 1, 1, c)


def base(img, coat, pants="k", wide=0, coat_len=0):
    """Kafa, gövde, bacaklar. Kafa 7..15, gövde 17..33, bacak 34..47."""
    rect(img, 6, 6, 8, 10, "p")            # yüz
    px(img, 8, 10, "k"); px(img, 11, 10, "k")  # gözler
    rect(img, 9, 16, 2, 2, "p")             # boyun
    rect(img, 4 - wide, 18, 12 + 2 * wide, 16 + coat_len, coat)  # gövde
    rect(img, 2 - wide, 19, 2, 13, coat)    # sol kol
    rect(img, 16 + wide, 19, 2, 13, coat)   # sağ kol
    px(img, 2 - wide, 32, "p"); px(img, 17 + wide, 32, "p")  # eller
    top = 34 + coat_len
    rect(img, 6, top, 3, 46 - top, pants)   # bacaklar
    rect(img, 11, top, 3, 46 - top, pants)
    rect(img, 5, 46, 4, 2, "k")             # ayakkabılar
    rect(img, 11, 46, 4, 2, "k")


def oscar():
    img = new()
    base(img, "l", pants="d", coat_len=4)    # uzun trençkot
    rect(img, 9, 18, 2, 10, "y")             # sarı kravat
    rect(img, 8, 18, 1, 4, "p"); rect(img, 11, 18, 1, 4, "p")  # gömlek yakası
    rect(img, 3, 3, 14, 2, "b")              # şapka siperi
    rect(img, 5, 0, 10, 4, "b")              # şapka
    rect(img, 5, 3, 10, 1, "k")              # şapka bandı
    px(img, 9, 13, "b"); px(img, 10, 13, "b")  # bıyıkla gülümseme
    return img


def toby():
    img = new()
    base(img, "b", pants="d")                # kapüşonlu
    rect(img, 6, 3, 8, 4, "b")               # saç
    rect(img, 6, 2, 8, 1, "y"); px(img, 7, 1, "y"); px(img, 11, 1, "y")  # sarı uçlar
    rect(img, 8, 20, 4, 3, "l")              # kapüşon ipi
    px(img, 16, 30, "l")                     # telefon
    return img


def vivian():
    img = new()
    base(img, "k", pants="k")                # siyah elbise
    rect(img, 5, 4, 10, 3, "k")              # saç üstü
    rect(img, 4, 6, 2, 16, "k"); rect(img, 14, 6, 2, 16, "k")  # uzun saç
    px(img, 6, 12, "y"); px(img, 13, 12, "y")  # zümrüt küpe (palette sarı)
    rect(img, 9, 13, 2, 1, "b")              # ruj
    rect(img, 6, 34, 8, 5, "k")              # elbise eteği
    return img


def gus():
    img = new()
    base(img, "b", pants="d", wide=1)        # bekçi üniforması, kilolu
    rect(img, 5, 3, 10, 3, "k")              # kasket
    rect(img, 5, 5, 12, 1, "k")              # siperlik
    rect(img, 5, 6, 1, 4, "g"); rect(img, 14, 6, 1, 4, "g")  # kır favoriler
    px(img, 6, 21, "y"); px(img, 7, 21, "y")  # rozet
    rect(img, 3, 30, 14, 1, "k")             # kemer
    return img


def harold():
    img = new()
    base(img, "k", pants="k")                # siyah takım
    rect(img, 6, 4, 8, 2, "g")               # kır saç, düzgün
    rect(img, 5, 5, 1, 4, "g"); rect(img, 14, 5, 1, 4, "g")
    rect(img, 8, 12, 4, 1, "g")              # bıyık
    rect(img, 8, 18, 4, 6, "p")              # gömlek
    rect(img, 9, 18, 2, 8, "b")              # kravat
    px(img, 9, 21, "y")                      # kravat iğnesi
    px(img, 2, 31, "y"); px(img, 17, 31, "y")  # kol düğmeleri
    return img


if __name__ == "__main__":
    import os
    out = os.path.join(os.path.dirname(__file__), "..", "art")
    for name, fn in [("oscar", oscar), ("toby", toby), ("vivian", vivian), ("gus", gus), ("harold", harold)]:
        fn().save(os.path.join(out, name + ".png"))
        print("ok", name)
