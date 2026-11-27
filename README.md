# Dark Files

2D pixel art dedektiflik oyunu. 2003, kurgusal liman şehri Ravenport. Oyuncu, FCD (Federal Crimes Division) danışmanı ve eski sahne sihirbazı Oscar Penn'i yönetir.

Vaka 1 "Boş Vitrin" baştan sona oynanabilir: ana menü, 6 mekan, 5 karakter, ipucu toplama, sorgu, kanıt gösterme, kanıt tahtası, suçlama ve puanlı final. Karakterler PixelLab çizimi; salon, hol, güvenlik ve ofis çizildi, diğerleri çizim gelene kadar sade duvar/zemin ile gösterilir.

## Nasıl açılır

1. Godot 4.3 veya daha yenisini aç.
2. "Import" (İçe aktar) butonuna bas, bu klasördeki `project.godot` dosyasını seç.
3. Proje açılınca sağ üstteki oynat butonuna (veya F5) bas.

## Kontroller

| Eylem | Fare / dokunma | Klavye |
| --- | --- | --- |
| Menüde başla | "Vakayı aç" | Enter / Boşluk |
| Yürü | Yere tıkla | A / D veya ok tuşları |
| İncele, konuş, kapıdan geç | Nesneye tıkla (üstüne gelince ne olduğu yazar) | F (veya E) |
| Oscar'ın Gözü (mekan başına 3, gizli ipuçlarını gösterir) | Üstteki buton | Q |
| Defter ve kanıt tahtası | Üstteki buton | Tab |
| Diyaloğu ilerlet / yazıyı hızlandır | Kutuya tıkla | Boşluk / Enter / F |
| Duraklat (devam, ayarlar, ana menü, çıkış) | Sağ üstteki "Menü" | Esc |

Ayarlar (ana menüden veya duraklatma menüsünden): müzik sesi, efekt sesi, tam ekran. Tercihler `user://settings.cfg` dosyasına kaydedilir.

Sahne çizimi olan mekanlarda ipuçları yanıp sönen sarı yıldızlarla belli olur.

Bir ipucu alınca inceleme ekranı açılır: "Çevir" (F) ile önü ve arkası görülür, "?" noktalarına tıklayınca detay bulunur ve deftere yazılır. Defterden bir ipucu seçip "yakından incele" ile tekrar açılabilir. Detay noktaları `data/case1.json` içinde her ipucunun `inspect` alanında (0-1 arası konum). Eşya çizimleri için promptlar: `docs/esya_promptlari.md`.

## Klasörler

- `scripts/main.gd`: tüm oyun kodu (sahneyi, arayüzü ve sesleri koddan kurar).
- `data/case1.json`: Vaka 1'in mekanları, ipuçları, diyalogları, dedüksiyonları ve finali. Yeni vaka eklemek = yeni bir JSON dosyası.
- `scenes/main.tscn`: tek sahne.
- `art/`: çizimler. `art/rooms/`: mekan arka planları.
- `sfx/`: ses efektleri ve müzik (WAV).
- `tools/`: çizim ve ses üreten yardımcı Python betikleri.

## Ölçek

Ekran 640x360, kamera 2x yakınlaştırır; yani dünya 320x180 "çizim pikseli" görünür. Karakterler 32x48, mekanlar 344x192 (PixelLab sahne boyutu). JSON'daki tüm konumlar bu çizim pikseli biriminde: `x` nesnenin ortası, `y` zeminden yükseklik, `floor_y` mekanın zemin çizgisi (yoksa 168).

## Çizimleri oyuna takmak

`art/` klasörüne doğru isimle bir PNG koyduğunda oyun o nesne için kutu yerine çizimi kullanır. Kod değişikliği gerekmez.

| Ne | Dosya adı | Boyut |
| --- | --- | --- |
| Oscar | `art/oscar.png` (sağa bakan) | 32x48 |
| Oscar yürüme | `art/oscar_walk.png` | 32x48 kareler yan yana |
| Şüpheliler | `art/toby.png`, `art/vivian.png`, `art/gus.png`, `art/harold.png` | 32x48 |
| FCD karakterleri | `art/memur1.png` (Şef Calloway), `art/memur2.png` (Memur Park), `art/maya.png` | 32x48 |
| Durma (nefes) animasyonu | `art/<ad>_idle.png` (ör. `art/gus_idle.png`) | 32x48 kareler yan yana |
| İpucu (sahnede) | `art/<ipucu id>.png` (ör. `art/kupe.png`); yoksa yanıp sönen yıldız | 4-30 px |
| İpucu (inceleme ekranı) | `art/items/<ipucu id>.png` ön, `art/items/<ipucu id>_back.png` arka | 96x96 |
| Mekan arka planı | `art/rooms/<mekan id>.png` | 344x192 |
| Oscar oturan / yudum | `art/oscar_sit.png`, `art/oscar_sip.png` (isteğe bağlı) | 32x48 |
| Araba (yandan, sağa bakan) | `art/araba.png` | ~96x40 |
| Gece yolu katmanları | `art/drive/sky.png`, `art/drive/lamps.png`, `art/drive/road.png` (yatayda tekrar eden, şeffaf) | 320x180 |
| Açılış sahnesi kartları | `art/cutscene/sehir.png`, `sahne.png`, `muze.png`; yoksa sadece yazı | 320x180 civarı |

Mekan id'leri: `oscar_ofis` (başlangıç), `koridor` (640 genişlik), `fcd`, `sokak`, `muze_onu`, `hol`, `salon`, `guvenlik`, `ofis`, `depo`, `otopark`. Yeni bir mekan çizimi gelince JSON'da o mekanın `floor_y` değeri ve nesnelerin `x`/`y` değerleri resme göre ayarlanır.

Kendi çizdiğin bir animasyon şeridi aynı isimle konursa otomatik üretilenin yerine geçer.

Palet: `#0f0b08`, `#2b1d14`, `#5a3d2b`, `#8a6a4f`, `#e8c547`, `#f2e3b3`.

## Araçlar

- `tools/fix_room.py`: PixelLab'ın arka planı şeffaf bıraktığı sahnelerde boşlukları doldurur ve resmi oyunun paletine çeker. Salon böyle hazırlandı:
  `python3 tools/fix_room.py girdi.png art/rooms/salon.png --floor 145 --cone 127,10,68,183,160 --dark-left 19 --dark-top 6`
- `tools/make_walk.py`: tek karakter çiziminden 4 karelik yürüme şeridi.
- `tools/make_walk2.py`: kolu sallanmayan karakterler için temiz yürüme (Maya: `--leg-top 39 --split 17 --hem 34`).
- `tools/make_idle.py`: tek karakter çiziminden 2 karelik nefes alma şeridi.
- `tools/pixelize.py`: ChatGPT/Gemini gibi araçlardan gelen normal bir resmi pixel art'a çevirir (arka planı siler, 64x64 ya da 344x192'ye küçültür, renkleri azaltır).
- `tools/make_sfx.py`: tüm ses efektlerini ve noir müzik döngüsünü sentezler (lisans sorunu yok).

## Henüz olmayanlar

- Vaka 1 çizimleri tamam.
- Sihir numaralarının mini oyunları (soğuk okuma şimdilik diyalog seçeneği, cep aşırma finalde ara sahne).
- Yırtık belge birleştirme yapbozu.
- Kayıt sistemi, Vaka 2+.

## Yazı tipi

`fonts/Rubik-Medium.ttf` (Rubik, SIL Open Font License): diyalog ve arayüz, okunaklı olsun diye. `fonts/PixelifySans-Medium.ttf` (Pixelify Sans, OFL): sadece büyük başlık. İkisi de ticari kullanımda serbest.
