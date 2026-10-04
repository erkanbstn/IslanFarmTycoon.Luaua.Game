# GPT model iş listesi (kodla çizilen görselleri modele çevirme)

Bu dosya, **model üreten yapay zekâya (GPT) verilen kalıcı üretici sözleşmesidir**. Oyun kodunu model ajanı değiştirmez;
yükleyici/yerleşim ve harita kaydı kod tarafındadır (`docs/MODEL_SOZLESMESI.md`, `docs/MODEL_IS_PLANI.md`).

> Kural: bir model bittiğinde hemen dosyaya yazılır ve kendi doğrulaması yapılır. Hepsini bitirip sonda toplu doğrulama yapma.

---

## 0. Kısa özet (önce bunu oku)

1. Her model **ilkel parçalardan** (Part, WedgePart) yapılan, tek bir `Model`'dir. Betik, ışık, arayüz, MeshPart **yok**; SpecialMesh yalnızca elips gövde için (bkz. 1.1).
2. Her model **ayrı bir `.rbxmx` dosyasıdır**; dosya adı = model adı (`Gull.rbxmx` → Model adı `Gull`).
3. Kodun **ayrı ayrı hareket ettireceği parçalar** (kanat, kuyruk, kol...) **ayrı parça** olmalı ve aşağıda yazılan adı taşımalı.
4. Ölçü, renk, malzeme ve parça adları mevcut model dosyalarından ve istek notundan alınır; sapma = oyunda farklı görünür.
5. Üretim **bir Python betiğiyle** yapılmalı (elle XML yazma); betik repoya `tools/models/` altına konur ve yeniden çalıştırılabilir olur.
6. Teslim: `.rbxmx` dosyaları + üretici betik + her model için tek satırlık kısa rapor (parça sayısı, kutu ölçüsü).

---

## 1. Ortak sözleşme (bütün modeller için ZORUNLU)

### 1.1 Dosya biçimi (en sık yapılan hatalar burada)
- Çıktı Roblox XML modeli: kök `<roblox version="4">`, içinde tek `<Item class="Model">`, onun içinde parçalar (`<Item class="Part">` / `<Item class="WedgePart">`).
- **Part şekil (`Shape`) değerleri: `0 = Ball`, `1 = Block`, `2 = Cylinder`.** (Önceki bir üretici bunları ters yazdı ve tekne topa dönüştü; kontrol et.) WedgePart'ta `Shape` yazılmaz.
- **Silindir X ekseni boyunca uzar.** Dikey sütun/direk için ya `Block` kullan ya da `Size=(uzunluk, çap, çap)` ve CFrame'i Z çevresinde 90° döndür. Dönmemiş `Size=(0.3, 6, 0.3)` silindir **düz bir disk** olur.
- **Ball (top) parçaların üç boyutu eşit** olmalı (`Size=(d,d,d)`). **Eşit olmayan Ball, Roblox'ta küre olarak çizilir ve en küçük boyuta düşer** (Studio'da denendi: 0.5×0.45×1.6 "top" ~0.45'lik küre çıktı).
- **Elips (uzun/basık gövde) gerekiyorsa tek yol:** `Block` bir `Part` + onun **çocuğu** olan bir `SpecialMesh` (`MeshType=3` yani Sphere, `Scale=(1,1,1)`, `Offset=(0,0,0)`). Part'ın `Size`'ı elipsoidin boyutudur. SpecialMesh'i **başka amaçla kullanma** (Head/Torso/FileMesh yok); XML'de: `<Item class="SpecialMesh"><Properties><token name="MeshType">3</token></Properties></Item>`.
- Boyut alanı adı `Size` (büyük S), renk `Color3` (`<Color3 name="Color"><R/><G/><B/></Color3>`, 0-1 arası kayan sayı). `Color3uint8` kullanma.
- Her parça: `Anchored=true`, `CanTouch=false`. `CanCollide`/`CanQuery`: aksi yazılmadıkça **false**.
- `Material` sayısal token'dır: Plastic 256, SmoothPlastic 272, Neon 288, Wood 512, WoodPlanks 528, Slate 800, Concrete 816, Granite 832, Brick 848, Cobblestone 880, Rock 896, Sandstone 912, Metal 1088, Grass 1280, Sand 1296, Fabric 1312, Snow 1328, Ice 1536, Glacier 1552, Glass 1568.
- Model'in `WorldPivotData` özelliği (pivot) **mutlaka yazılmalı** (aşağıda her modelin pivotu belirtilmiştir). Pivot yoksa Roblox kutu merkezini kullanır ve model yanlış yere oturur.
- `PrimaryPart` yalnızca "hareket eden gövde" olan modellerde (kuş, balık...) ve **o modelde belirtilmişse** yazılır; adı genelde `Body`.
- **Yasak:** Script/LocalScript/ModuleScript, ışık (PointLight/SpotLight/SurfaceLight), SurfaceGui/BillboardGui/ProximityPrompt, MeshPart, (yukarıdaki elips kuralı dışında) SpecialMesh, Decal/Texture, ParticleEmitter, Attribute/Tag, Weld/WeldConstraint.
- Parça sayısı: her modelde belirtilen üst sınırı aşma. Gereksiz süs ekleme.

### 1.2 Görsel dil
- Hafif stilize, düz renkli, **blok-ağırlıklı** (Minecraft'a yakın) bir görünüm. Dokusuz; renk ve malzemeyle ayrışır.
- Renk paleti: ilgili modelde RGB (0-255) olarak verilmiştir; onu birebir kullan.
- Gece/gündüz ışığı kod tarafından uygulanır; modelde emissive hile yok (Neon yalnızca belirtilmişse).

### 1.3 Adlandırma
- Parça adları İngilizce, `PascalCase`, mevcut model dosyasındaki gibi. Aynı adı taşıyan birden çok parça serbesttir (örn. iki `Eye`).
- Hareketli parçalar (kanat, kuyruk, kol) için adlar **sabit** olmalı çünkü kod `FindFirstChild("LeftWing")` ile bulur.

### 1.4 Teslim yeri
- İstemci tarafında çizilen efekt nesneleri (kuş, balık, deniz canlısı, buz, mevsim süsü, tekne izi...) → `client-assets/<Klasör>/<Ad>.rbxmx`
  (Rojo bunları `ReplicatedStorage.ClientAssets.<Klasör>.<Ad>` altına koyar; istemci okuyabilsin diye.)
- Sunucu tarafında çizilen dekor (harita, ada kiti) → `assets/<Klasör>/<Ad>.rbxmx` (`ServerStorage.Assets` altına).
- Hangi modelin hangi yolda olduğu mevcut `assets/` ve `client-assets/` klasörleri ile `check-assets.py` beklentisidir.
- Üretici betikler `tools/models/` altına.

### 1.5 Doğrulama (her model için, teslim etmeden önce)
1. `python scripts/check-assets.py` çalışır, hata vermez (bu betik klasörleri/adları/yasak sınıfları denetler).
2. Dosya Python `xml.etree` ile hatasız açılır; model adı dosya adıyla aynı; pivot yazılı.
3. Ölçü kontrolü: modelin sınırlayıcı kutusu benzer mevcut modelin ve istek notunun kutusuyla ±%10 uyumlu.
4. Şekil kontrolü: bütün `Part` `Shape` değerleri §1.1 kuralındaki gibi (özellikle top/blok ters değil, dikey direkler silindir değil).
5. Hareketli parça adları kodun aradığı adlarla (mevcut modeldeki gibi) var.

### 1.6 Sorun çıkarsa
Bir ölçü/ad belirsizse **tahmin etme**; sorun maddesini rapora yaz ve en yakın makul değeri seç.

---

---

## 2. Modele DÖNÜŞMEYECEKLER (kodda kalır; GPT'den bu yüzden istenmiyor)

| Ne | Neden |
|---|---|
| Kıyı buzu pulu, toz bulutu, parıltı, yüzme izi, tekne köpük izi, yıldırım çubuğu, yağış levhaları, su altı çapaları | **Tek parçalık** efekt; her karede boyutu/saydamlığı/konumu değişir. Model katkısı yok |
| Yosun (kelp), kabarcık | İki parçalı, kod yüksekliği her seferinde ayarlıyor (animasyon); kabarcık tek top |
| Taş yol (`Path`), çim yaması (`GrassPatches`) | Uzunluk/yarıçap parametrik, düz levha |
| Ada gövdesi, plaj diski, deniz kayası, dağlar, deniz | Terrain; "donduruldu" kuralı |
| `Ground`, `IslandBase`, meydan zemini, `SpawnLocation` | Parametrik zemin, öznitelikleri var |
| Işık, etiket, yazı (`WorldUi`), `ProximityPrompt` | XML taşımaz; kod ekler |
| Çit uzunluğu (`FenceRun`) | Uzunluk 13 stud; mevcut `Fence_8` yetmez. **İstenirse** `Fence_Module_4.rbxmx` (post + rail, 4 stud) modülü yapılabilir, kod tekrar eder |
| Kazık (`Pile`) yüksekliği | Deniz tabanına göre değişir |

---

---

## 3. Durum (2026-10-04)

Bu dosyadaki eski teslim listeleri (istemci efekt modelleri, köprü/tabela/hub/varyant paketleri, öncelik tablosu P1–P4 ve
kopyala-yapıştır komutu) **tamamlandı ve koda bağlandı**; eski yordamsal çizim kodu silindi. Her modelin gerçek ölçüsü,
parça adı ve pivotu artık `assets/` ve `client-assets/` içindeki `.rbxmx` dosyaları ile `scripts/check-assets.py` sözleşmesidir.
Eski ayrıntılı listeler yalnız Git geçmişinde (`git log -- docs/GPT_MODEL_IS_LISTESI.md`) durur.

Yeni model işi için sırayla: (1) bu dosyanın §1 sözleşmesi ve `docs/MODEL_SOZLESMESI.md`, (2) mevcut benzer `.rbxmx`
dosyası (renk/ölçü/pivot kaynağı), (3) `python scripts/check-assets.py`, (4) teslim notunu sohbette kısa ver (ad, yol, parça sayısı, pivot, sapma).
Üretici betikler: `tools/models/` ve `docs/model-ureticileri/` (yeniden çalıştırılabilir olanlar). Tek seferlik düzeltme
betikleri uygulandıktan sonra silinir; sonuç model dosyasındadır.
