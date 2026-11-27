# Eşya çizimleri (PixelLab promptları)

Her eşya için bir ön yüz, çoğu için bir arka yüz çizimi gerekiyor. Oyun bunları inceleme ekranında 3 kat büyütüp gösteriyor ve oyuncu "Çevir" ile önünü arkasını görüyor.

- Boyut: **64x64**, şeffaf arka plan, eşya ortada ve kareyi doldursun.
- Dosya adı: ön yüz `art/items/<id>.png`, arka yüz `art/items/<id>_back.png`.
- Detay noktaları (oyundaki "?" işaretleri) aşağıda parantez içinde yazan yerlere denk geliyor. Çizim o detayı göstersin.

Her promptun başına bu ortak kısmı koy:

`pixel art item icon, 64x64, single object centered, transparent background, early 2000s noir detective game, dark brown black and warm yellow palette, soft top light, clean outline, no text unless stated`

| id | Ön yüz promptu | Arka yüz promptu |
| --- | --- | --- |
| `ruj` | champagne glass with a dark red lipstick mark on the rim (rim at top, stem at bottom) | the same champagne glass seen from the other side, a second fainter lipstick mark near the top |
| `misafir` | open museum guest book, handwritten names and times on the left page, a shaky signature lower right | closed guest book back cover, "21:40" written in pencil and underlined in the middle |
| `sakiz` | crumpled mint gum wrapper, silver and green, brand label in the middle | the unfolded inner side of the gum wrapper, plain foil, crumpled |
| `kilit` | brass display case lock, front face with a clean keyhole in the middle | back of the brass lock, four painted screw heads, paint intact |
| `taban` | close-up of the bottom of a glass display case, a hair-thin line running around the base, a tiny hinge in the left corner | the underside of the display base, a spring mechanism in the middle |
| `kupe` | emerald drop earring, gold setting, green gem in the upper middle | back of the same earring, the clasp open at the bottom |
| `sac` | a single short grey hair on a dark cloth, a shiny residue at its top end | the same grey hair, a small purple lavender sprig next to it to show a lavender smell |
| `kamera` | VHS security tape with a small CRT screen above it showing a dark museum hall with two timestamps, left and right | the side of the VHS tape with a handwritten paper label |
| `kart` | museum security access log printout, one highlighted line in the upper middle | white plastic keycard back side with a small yellow sticky note in the middle |
| `fincan` | white coffee mug with the word "MÜDÜR" on it (text allowed), white powder residue visible at the bottom inside | the same mug from behind, two smudged fingerprints on the handle |
| `gus_ifadesi` | a small police notepad page with handwritten lines (statement) | - |
| `krem` | expensive lavender hair cream bottle, purple label in the upper middle | back of the bottle, a small pharmacy receipt taped in the lower middle |
| `kol1` | single silver cufflink engraved with the letters "H.F.M." (text allowed) | back of the cufflink, a bent pin in the middle |
| `anahtar` | old Mercedes-style car key, upper part shows the logo | the key ring with a small paper tag lower middle reading "P3" (text allowed) |
| `sigorta` | torn insurance document taped back together, a big amount number in the upper left | the lower half of the torn document, a date and a signature in the middle |
| `plan` | building floor plan blueprint, the exhibition hall marked in the upper middle, the basement directly below it with a pencil arrow | - |
| `bileklik` | broken leather bracelet, the buckle torn, a letter "T" scratched inside (text allowed) | the same bracelet with a dark liquor stain in the middle |
| `oluk` | a metal chute coming down from the top into a wooden crate stamped "Vesper & Co." (text allowed) | back of the wooden crate with a shipping label in the middle |
| `kol2` | single silver cufflink engraved "H.F.M.", covered in a little basement dust | back of the dusty cufflink, light dust on the pin |
| `afis` | old torn magic show poster, a young confident stage magician in a top hat in the upper part, a small company logo in the lower right corner | back of the poster, faded handwritten note in the middle |
| `fatura` | invoice paper with a company header at the top, a line "custom display case and chute system" in the upper middle | lower part of the invoice, a date and "cash" stamp in the lower middle |
| `kartvizit` | black business card, "Vesper & Co." in gold letters and a phone number (text allowed) | back of the business card with handwritten notes in the middle |

Not: "text allowed" yazan yerlerde yazı okunmasa da olur, oyun detayı zaten metinle söylüyor.
