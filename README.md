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
