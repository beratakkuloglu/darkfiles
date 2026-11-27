# Dark Files

2D pixel art dedektiflik oyunu. Oyuncu, FCD (Federal Crimes Division) danışmanı ve eski sahne sihirbazı Oscar Penn'i yönetir.

Bu depo şu an **gri kutu sürümü**: tüm görseller renkli kutulardır. Amaç, Vaka 1'in baştan sona oynanabilir olması ve oynanışın test edilmesi.

## Nasıl açılır

1. Godot 4.3 veya daha yenisini aç.
2. "Import" (İçe aktar) butonuna bas, bu klasördeki `project.godot` dosyasını seç.
3. Proje açılınca sağ üstteki oynat butonuna (veya F5) bas.

## Kontroller

| Eylem | Fare / dokunma | Klavye |
| --- | --- | --- |
| Yürü | Yere tıkla | A / D veya ok tuşları |
| İncele, konuş, kapıdan geç | Nesneye tıkla | E |
| Oscar'ın Gözü (mekan başına 3) | Üstteki buton | Q |
| Defter ve dedüksiyon tahtası | Üstteki buton | Tab |
| Diyaloğu ilerlet | Kutuya tıkla | Boşluk / Enter |

Renkler: sarı kutular ipucu, açık kahve kutular kişi, koyu kahve kutular kapı.

## Klasörler

- `scripts/main.gd`: tüm oyun kodu.
- `data/case1.json`: Vaka 1'in mekanları, ipuçları, diyalogları, dedüksiyonları ve finali. Yeni vaka eklemek = yeni bir JSON dosyası.
- `scenes/main.tscn`: tek sahne.

## Henüz olmayanlar

- Pixel art, animasyon, ses, müzik.
- Sihir numaralarının mini oyunları (soğuk okuma şimdilik diyalog seçeneği, cep aşırma finalde ara sahne).
- Yırtık belge birleştirme yapbozu.
- Kayıt sistemi, ana menü, Vaka 2+.

## Çizimleri oyuna takmak

`art/` klasörüne doğru isimle bir PNG koyduğunda oyun o nesne için kutu yerine çizimi kullanır. Kod değişikliği gerekmez.

| Ne | Dosya adı | Önerilen boyut |
| --- | --- | --- |
| Oscar | `art/oscar.png` | 20x48 |
| Şüpheliler | `art/toby.png`, `art/vivian.png`, `art/gus.png`, `art/harold.png` | 20x48 |
| İpucu | `art/<ipucu id>.png` (ör. `art/kupe.png`, `art/fincan.png`) | 4-30 px |
| Kapı | `art/door.png` | 34x64 |
| Mekan arka planı | `art/rooms/<mekan id>.png` (ör. `art/rooms/hol.png`) | mekan genişliği x 360 (hol: 900x360) |

İpucu ve mekan id'leri `data/case1.json` içinde. Zemin çizgisi y=290'da. Palet: `#0f0b08`, `#2b1d14`, `#5a3d2b`, `#8a6a4f`, `#e8c547`, `#f2e3b3`.

Şu anki karakter sprite'ları `tools/make_sprites.py` ile üretilmiş geçici çizimler. Pixelorama'da açıp üzerine çizebilirsin.
