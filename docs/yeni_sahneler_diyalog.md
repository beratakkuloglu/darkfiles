# Yeni sahneler: görseller ve diyaloglar

Görseller `art/` altında (PR'da). Bu dosya, oyuna nasıl bağlanacaklarını ve diyalogları anlatır.

## 1. Açılış: iki ayrı tiyatro görseli
- "Beş yıl önce bu şehir adımı haykırıyordu. Büyük Valentino. Evet, ben." → `cutscene/sahne_parlak` (dolu salon, spot ışıkları, sahnede Valentino)
- "Sonra son numaramda bir şeyler ters gitti. O geceden sonra kimse bilet almadı." → `cutscene/sahne` (mevcut, terk edilmiş sahne)
- İkinci görsele geçerken aynı resim tekrar belirmesin; parlak görselden harabeye yavaş bir çapraz geçiş (crossfade) yeterli.

## 2. Oscar'ın ofisi: pencereden şehir
`oscar_ofis` odasına pencerenin üstüne bir `look` nesnesi. Tıklayınca tam ekran `cutscene/pencere` gösterilir (yağmur efekti açık kalabilir), sonra şu satırlar:

- Oscar: "Ravenport. Gece hiç uyumaz, ama gözünü de pek açmaz."
- Oscar: "Yağmur yine başlamış. Ya da hiç durmadı, emin değilim."
- Oscar: "Şu kırmızı neonun yarısı yanmıyor. Bu şehirde her şey yarım yanar zaten."
- Oscar: "Bir zamanlar bu şehrin her ışığı benim için yanardı. Şimdi kahvem bile soğuk."

İkinci kez bakılırsa (keep:true ile kısa satır):
- Oscar: "Hâlâ yağıyor. Sürpriz."

## 3. Müze önü: kapıda bekleyen iki polis
Yeni karakterler (`art/polis1*.png`, `art/polis2*.png`, duruş + idle + yürüme):
- **Memur Riley** (`polis1`): siyah yağmurluklu, bıyıklı, yorgun bir devriye polisi. Kapının solunda durur (x≈245).
- **Memur Alvarez** (`polis2`): hardal yağmurluklu, el feneri tutan kadın polis. Kapının sağında durur (x≈315), kordonu tutuyor.

Giriş satırları (`enter_lines`, araba durduktan sonra):
- Maya: "Kapıda iki üniforma var. İçerisi daha kalabalık."
- Oscar: "Seyirci hazır demek. Hadi sahneye."

### Riley diyalogu (`riley`)
- Riley: "Siz FCD'densiniz, değil mi? Şef söyledi. Şu... sihirbaz."
- Oscar: "Eski sihirbaz. Artık sadece borçlarımı yok ediyorum."
- Riley: "Dört saattir bu yağmurun altındayım. İçeride kimse bir şey bulamadı. Siz bulursanız eve gidebilirim."
- Seçenek "Ne gördün?":
  - Riley: "İlk gelen bendim. Vitrin kapalıydı, cam sapasağlamdı. Taş yoktu. O kadar."
  - Riley: "Müdür bey çok sakindi ama. Benim evimden bir yakut çalınsa ben o kadar sakin olmazdım."
- Seçenek "Kimse çıktı mı?":
  - Riley: "Biz geldikten sonra kimse binadan çıkmadı. Sadece genç olan, yeğen, arka kapıdan sigara içmeye çıkmak istedi. İzin vermedim."
- Tekrar konuşunca:
  - Riley: "Hâlâ buradayım. Hâlâ ıslağım."

### Alvarez diyalogu (`alvarez`)
- Alvarez: "Kordonun arkasında kalın, lütfen. ...Ah, Maya. Sen misin?"
- Maya: "Selam, Alvarez. Bu da Penn. Benimle."
- Alvarez: "Penn mi? Gazetelerdeki Valentino?" (Oscar'a bakar) "Annem sizi seyretmeye gelmişti. Hâlâ anlatır."
- Oscar: "Umarım iyi kısmı anlatıyordur."
- Alvarez: "...Kısmen."
- Seçenek "Alarm?":
  - Alvarez: "Alarm hiç çalmadı. Ama güvenlik kamerasında, salonun ışıkları bir ara dört saniyeliğine sönüyor. Gerisini içeridekiler anlatır."
- Seçenek "Müdür?":
  - Alvarez: "Harold Bey bizi kapıda karşıladı, elinde telefon. Sigortacıyla konuşuyordu. Taş çalınmış, adamın ilk işi poliçe. Bilmem dikkatinizi çeker mi."
- Tekrar konuşunca:
  - Alvarez: "Bir şey bulursanız bana da söyleyin. Rapor yazmaktan nefret ediyorum."

(Not: Alvarez'in sigorta ve "dört saniye karanlık" sözleri var olan ipuçlarıyla çelişmez, sadece pekiştirir; yeni bir zorunlu ipucu değildir.)

## 4. Final: yakut yeniden vitrinde
Suçlu doğru seçildikten ve `reveal_lines` bittikten sonra, kredi/sonuç ekranından önce kısa bir sahne:

1. Tam ekran `cutscene/yakut_vitrin` (karanlık salon, tek spot, yakut kadife yastığında).
2. Satırlar:
   - "": "Ertesi sabah. Finch-Moore Müzesi, Mücevher Salonu."
   - Felix: "Kırk bir yıl bu taşa baktım, Bay Penn. Hiç bu kadar güzel görünmemişti."
   - Oscar: "Bir gece kayıp kalınca herkes daha güzel görünür. İnsanlar da öyle."
   - Felix: "Siz olmasaydınız sahtesini buraya koyacaklardı. Ben de farkına varmadan ona bakıp duracaktım."
   - Maya: "Edith, ödülü bu akşam hesabına yatıracakmış. 900 dolar, Penn."
   - Oscar: "Bayan Kowalski bunu duyunca ağlar. Sevinçten değil, 'bu kadar mı' diye."
   - Maya: "Hadi. Kahve benden."
   - Oscar: "Sıcak mı?"
   - Maya: "Abartma."
3. İstenirse oyuncu salonda serbest dolaşıp vitrine bakabilir; salondaki boş vitrin nesnesinin `lines`'ı finalden sonra şu olur:
   - Oscar: "Yerinde. Parlıyor. Bir dahaki sefere daha iyi bir vitrin alın."
