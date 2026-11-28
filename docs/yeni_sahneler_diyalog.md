# Yeni sahneler: görseller ve diyaloglar

Görseller `art/` altında. Aşağıda her birinin oyunda nereye bağlanacağı ve diyalogları var.

## 1. Açılış: iki ayrı tiyatro görseli
- "Beş yıl önce bu şehir adımı haykırıyordu. Büyük Valentino. Evet, ben." satırında `cutscene/sahne_parlak` (dolu salon, spot ışıkları, sahnede Valentino).
- "Sonra son numaramda bir şeyler ters gitti. O geceden sonra kimse bilet almadı." satırında `cutscene/sahne` (mevcut, terk edilmiş sahne).
- İkinci satırda resim baştan belirmesin. Parlak görselden harabeye yavaş bir çapraz geçiş (crossfade) yeterli.

## 2. Oscar'ın ofisi: pencereden şehir
`oscar_ofis` odasında pencerenin üstüne bir `look` nesnesi konur. Tıklayınca tam ekran `cutscene/pencere` açılır (yağmur efekti açık kalabilir), ardından:

- Oscar: "Ravenport. Buradan bakınca fena görünmüyor. Aşağı inince anlarsın."
- Oscar: "Yağmur yine başlamış. Ya da hiç durmadı, emin değilim."
- Oscar: "Karşıdaki neonun yarısı üç yıldır yanmıyor. Kimse de tamir ettirmiyor."
- Oscar: "Eskiden bu sokaklarda afişim asılıydı. Şimdi adımı hatırlayan tek kişi ev sahibim."

İkinci bakışta (keep:true, kısa satır):
- Oscar: "Hâlâ yağıyor. Sürpriz."

## 3. Müze önü: kapıda bekleyen iki polis
Yeni karakterler (`art/polis1*.png`, `art/polis2*.png`; duruş, idle ve yürüme):
- Memur Riley (`polis1`): siyah yağmurluklu, yorgun bir devriye polisi. Kapının solunda durur (x≈245).
- Memur Alvarez (`polis2`): hardal yağmurluklu kadın polis. Kapının sağında, kordonun başında durur (x≈315).

Giriş satırları (`enter_lines`, araba durduktan sonra):
- Maya: "Kapıda iki memur var. İçerisi daha da kalabalık."
- Oscar: "Seyirci hazır demek. Hadi sahneye."

### Riley diyalogu (`riley`)
- Riley: "Siz FCD'densiniz, değil mi? Şef söyledi. Şu... sihirbaz."
- Oscar: "Eski sihirbaz. Artık tek numaram borçlarımı büyütmek."
- Riley: "Üç saattir bu yağmurun altındayım. İçeridekiler bir şey bulamadı. Siz bulursanız belki eve giderim."
- Seçenek "Ne gördün?":
  - Riley: "İlk gelen bendim. Vitrin kilitliydi, camda tek çizik yoktu. Taş da yoktu."
  - Riley: "Müdür bey çok sakindi ama. Benim evimden yakut çalınsa duvarlara tırmanırdım."
- Seçenek "Kimse çıktı mı?":
  - Riley: "Biz geldikten sonra kimse çıkmadı. Yeğeni, şu genç olan, arka kapıdan sigaraya çıkmak istedi. Bırakmadım."
- Tekrar konuşunca:
  - Riley: "Hâlâ buradayım. Hâlâ ıslağım."

### Alvarez diyalogu (`alvarez`)
- Alvarez: "Kordonun arkasında kalın, lütfen. ...Aa, Maya, sen misin?"
- Maya: "Selam, Alvarez. Bu da Penn, benimle."
- Alvarez: "Penn mi? Gazetedeki Valentino?" (Oscar'a bakar) "Annem sizi seyretmeye gelmişti. Hâlâ anlatır."
- Oscar: "Umarım güzel kısmını anlatıyordur."
- Alvarez: "...Bazen."
- Seçenek "Alarm?":
  - Alvarez: "Alarm hiç çalmamış. Ama kamera kayıtlarında salonun ışıkları dört saniye sönüyor. Gerisini içeridekilere sorun."
- Seçenek "Müdür?":
  - Alvarez: "Harold Bey bizi kapıda karşıladı, kulağında telefon. Sigortacıyla konuşuyordu. Yakutu çalınmış, aklı poliçede. Ben olsam ağlardım."
- Tekrar konuşunca:
  - Alvarez: "Bir şey bulursanız bana da söyleyin. Raporu ben yazacağım çünkü."

Alvarez'in sigorta ve dört saniyelik karanlık sözleri var olan ipuçlarını tekrarlar, yeni bir zorunlu ipucu eklemez.

## 4. Final: yakut yeniden vitrinde
Suçlu doğru seçilip `reveal_lines` bittikten sonra, sonuç ekranından önce kısa bir sahne:

1. Tam ekran `cutscene/yakut_vitrin` (karanlık salon, tek spot, yakut kadife yastığında).
2. Satırlar:
   - "": "Ertesi sabah. Finch-Moore Müzesi, Mücevher Salonu."
   - Felix: "Kızıl Göz'e kırk bir yıl baktım, Bay Penn. Hiç bu kadar güzel görünmemişti."
   - Oscar: "Bir gece ortadan kaybolunca öyle oluyor. Ben beş yıldır deniyorum, bende işe yaramadı."
   - Felix: "O cam kopyayı yıllar önce sergi için ben yapmıştım. Birinin onu satmaya kalkacağı aklımın ucundan geçmezdi."
   - Maya: "FCD ödemeni yarın yatırıyor. 900 dolar, Penn."
   - Oscar: "Bayan Kowalski'ye yeter. Bana da bir kahve parası kalır belki."
   - Maya: "Kahve benden."
   - Oscar: "Sıcak mı?"
   - Maya: "Abartma."
3. Oyuncu sonra salonda dolaşıp vitrine bakabilir. Finalden sonra vitrin nesnesinin satırı:
   - Oscar: "Yerinde, parlıyor. Vitrini de bu sefer düzgün bir camcıya yaptırsınlar."
