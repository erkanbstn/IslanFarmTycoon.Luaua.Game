# Model harita deneyi — özet

- Studio: **Ada Tarım Zengini** (`102047004387802`), Edit. Ada/yapı modelleri asıl `Workspace.Plots` / `Workspace.World` konumunda; deniz ve çevre dağları yerleşik Terrain. Sahne Studio'da Roblox'a kaydedildi; Publish, kod değişikliği, commit/push yapılmadı.
- X +1000 test alanı: `Terrain.ReadVoxels` x=900..1100, z=75..275, y=-20..60 için dolu voxel **0**.
- Yöntem: mevcut Edit haritasındaki BasePart özellikleri `Instance.new` ile yeni modellere aktarıldı; Script/Prompt alınmadı. Doğa dağılımı mevcut haritanın birebir konumlarından geldi; çim/ağaç tohumları yeniden çalıştırılmadı. Dağ halkası kaynak `20260930` tohumuyla yeniden kuruldu.

| Bölüm | BasePart | Sonuç |
|---|---:|---|
| `01_zemin` / `02_doga` | 48 / 561 | Ana zemin, sahil, yol, iskele; ağaç/çim/çiçek. |
| `03_yapilar` / `04_tarim` | 181 / 268 | Ev, değirmen, pazar, anıt; bahçe, kovan, fener, çit ve küçük süsler. |
| `05_agil` / `06_binalar` | 240 / 62 | Bölgeler ve ahır; altı yeni ana ada bina prototipi (her biri ≤35 parça). |
| `07_kucuk_adalar` | 530 | Plot1'in Tavuk, At, Keçi adaları. |
| `08_meydan` / `09_kopruler` | 210 / 18 | Hub ve altı ana köprü. |
| `10_ciftlik2`…`14_ciftlik6` | 9312 | Kalan beş fiziksel çiftlik, mevcut Edit görünümü. |
| `15_ankrajlar` / `16_sinir` | 36 / 101 | Plot1 işaretleri, MapRim ve SeaSafety. |
| `17_kayalik` / `18_deniz` / `19_daglar` | 0 / 0 / 0 | Parçalı önizleme kaldırıldı; kaya/su/dağ Terrain içinde. |

- Prototipler kaldırılmadan önce toplam **11.567 BasePart** idi; 2.344.480 dolu Terrain hücresi. İlk statik imzadaki 5 bilinçli fark (2 Beach, 3 Patch) ve aşağıdaki yerleşim/çevre revizyonları bulunuyor.
- Altı çiftlikte 12 yan ada yerel (±85,105)→(±100,125) taşındı; ana ada kıyı boşluğu yaklaşık 13→38 stud, yan köprüler 17.09→42.08 stud. Uzak üçüncü ada yerinde. Bölge, üç BuildSpot, kaya çekirdeği ve yol/alan öznitelikleri birlikte taşındı; uydu adalar arası en dar boşluk 21 stud.
- Şikâyet edilen cam deniz, katmanlı model tabanı ve kama dağlar çıkarıldı. Özgün Terrain dağları ve yerleşik dalgalı su geri getirildi. Kum tabanı kalınlaştırıldı; 25 ada/meydan kaya gövdesi kum tabanından plaj altına kadar uzatıldı. Taşınan 12 adanın eski su altı gövdeleri temizlenip yeni yerlerinde kuruldu.
- `StreamingEnabled` korunarak 6 Plot modeli, Hub ve `World.Bridges` modeli `Persistent` yapıldı. Uzak üstten Play görüntüsünde tüm adalar/dağlar görünüyor; bunun istemci bellek maliyeti ayrıca ölçülmeli.
- Düzeltilen temaslar: iki küçük sahil diski 118→114 stud; üç çim yaması bölge zemininden dışarı 20 stud; yan ada/köprü yerleşimi açıldı. Parçalı dağ önizlemesi kaldırıldı.
- Kalan amaçlı birleşimler: iskele kazığı/kum-kayalık, köprü/sahil, direk/yürüyüş alanı, istifli saman ve dağ/görünmez sınır. Yan ada tabanı ile başka ada/dağ parçası arasında istenmeyen `GetPartsInPart` teması **0**.
- Etiket/öznitelikler taşındı (`NightLight` 252, `NightWindow` 42, `RevealGate` 54, `Windmill` 6; `NightColor`, `RevealZoneId` vb.). `Window*` cam; açık ışık, Script ve `ProductionPromptAnchor` **0**. Oynanabilirlik için 41 özgün ProximityPrompt ve 7 SpawnLocation geri bağlandı.
- Bilinen sınır: altı çiftlik Edit'teki aynı tema içeriğini gösterir; hayvanlar ve satın alınan diğer yükseltmeler modellenmedi. Su ve dağ Terrain'dir; ada/yapılar modeldir. Uzak kamerada kalıcılık bellek yükünü artırabilir. 5.5 stud gövdede 6.6 kapı açıklığı sağlanamıyor; silo/toplayıcı 12 stud önerisini aşıyor.
- Geri dönüş yedeği `ServerStorage._ModelSwapBackup`: orijinal `Plots`, `World`, iki `TerrainRegion`, önceki dağ modeli ve `VisualsBeforeNativeWater` altındaki çıkarılan görseller. `MapBuilder.validate()` geçti; kısa Play'de tüm adalar uzaktan göründü ve başlangıç hatası yoktu, sonra Edit'e dönüldü.
- Yanlışlıkla eksilen `Plot4`, Studio yedeğinden geri kuruldu; Tavuk/At adaları ve köprüleri yeni aralığa uyarlandı. Altı çiftlik ve 11.567 parça doğrulandı; `MapBuilder.validate()` geçti. 02.10.2026 01:05'te Studio değişiklikleri Roblox'a kaydetti. Kod akışı korunuyor; `Haritayı Kur` yeniden çalıştırılırsa kod haritayı baştan kurabilir. Kesin süre/token sayacı yok.
- `Workspace.ModelBench` içinde dört bina (`duck_packer`, `wool_mill`, `truffle_kitchen`, `cheese_dairy`) ve dört hayvan (`duck`, `sheep`, `pig`, `goat`) hazır: toplam **158** BasePart. Bina girişi/prompt noktası açık, boyut ve hayvan ölçeği sınırları geçti; `duck_packer` gerçek noktasında alternatif `milk_factory` dışında yerleşim teması 0. Ayrıntı: `model-duck-pilot.md`.
- Sekiz model `assets/Buildings|Animals/*.rbxmx` olarak repoya alındı; Rojo build ve Studio senkronunda parça/pivot/PrimaryPart farkı **0**. İkili `.rbxm` biçimi Rojo 7.4.4 ile uyumsuzdu ve kaldırıldı. Kısa Play açılışı hatasızdı; satın alma/hayvan oluşturma dalı henüz oynanışta test edilmedi. Kod kurucuları yedek olarak duruyor.
- Model dosyası kapsamı tamamlandı: `assets/` altında **54 bina + 24 hayvan = 78 model**, toplam **1.254 BasePart**; planlanan eksik model **0**. `Plot1.Upgrades` içindeki 6 statik prototip Edit oturumunda kaldırıldı; `Plots+World` **11.505 BasePart**. Rojo build, 73 tezgâh/asset imza karşılaştırması ve kısa Play geçti. Kaynak kodun fiziksel görünümleri korundu; tabelalar ve çalışma anı gece ışıkları şablon dışında. Üç hayvan 20 parça önerisini aşıyor; son görsel/oynanış incelemesi bekliyor. Yerleşim/Terrain/kod değişmedi. Studio Ctrl+S otomatik onayca reddedildi, bu turun sahne değişiklikleri kaydedilmedi; ayrıntı `ilerleme.md`.
