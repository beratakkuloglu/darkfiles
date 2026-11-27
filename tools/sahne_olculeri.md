# Sabit ölçü: tüm sahneler bu kurala göre çizilir

Karakterler her yerde aynı boyda (32x48, adam ~46 px). Değişen tek şey sahne çizimi.

## Kural (344x192 tuval)
- Zemin çizgisi: y = 172 (ayaklar burada). Altında 20 px zemin.
- Kapı: ~30 px geniş, ~62 px yüksek (resim yüksekliğinin üçte biri).
- Masa: ~22 px yüksek. Sandalye sırtı: ~30 px. Raf/dolap en fazla ~75 px.
- Tavan çizgisi y ≈ 60 civarı; üstü lamba, pencere, tabela ile dolu (boş duvar olmasın).
- Yandan görünüm, düz ön duvar, perspektif yok. Palet: siyah, kahve, sarı.
- Rehber resim: olcu_rehberi.png (PixelLab'de init/referans resim olarak yükle, üstüne çizdir).

## Ortak prompt eki (her sahnenin sonuna ekle)
side view pixel art game background, 344x192, flat front wall, no perspective, floor line at bottom 20 pixels, doors one third of image height, small furniture, lots of wall space, dark brown black and warm yellow palette, 2000s noir, no people

## Yeniden çizilecek sahneler (öncelik sırası)
1. guvenlik: small museum security room, wall of small CRT monitors above a low desk, office chair, filing cabinet, two metal doors left and right
2. ofis: museum director's office, low bookshelf with bottles, framed blueprint, desk with green banker lamp, leather chair, fuse box, two wooden doors on the right
3. hol: museum main hall entrance, glass entrance doors on the left, reception desk with brass lamp, chandelier, coat stand, double wooden door on the right
4. salon: museum jewel gallery, empty glass display case on a pedestal in a spotlight, framed paintings, arched windows, doors left and right
5. depo: museum basement storage, brick walls, wooden crates, statues under cloth, old circus poster, stairs door on the left, hanging bulb
6. oscar_ofis: small cluttered consultant office, desk with coffee mug and papers, chair, old magician poster, top hat on a shelf, door on the right
7. fcd: police division bullpen, desks, glass-walled chief office, elevator door on the left, exit door on the right
8. koridor (2 parça, 344x192 + 344x192): office building hallway, water cooler, notice board, office door, elevator at the far right end
9. sorgu: interrogation room, metal table, two chairs, one-way mirror, single hanging lamp

Sokak, müze önü ve otopark zaten bu ölçüde, kalabilir.
