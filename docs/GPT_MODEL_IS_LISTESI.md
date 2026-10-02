# GPT model iş listesi (kodla çizilen görselleri modele çevirme)

Bu dosya, **model üreten yapay zekâya (GPT) verilecek tek iş tanımıdır**. Okuyan her şeyi buradan alır: ne yapılacak, her
modelin ölçüsü/rengi/parçaları, hangi dosya adıyla nereye kaydedilecek, nasıl doğrulanacak. Oyun kodunu GPT değiştirmez;
model dosyaları gelince **kod tarafındaki yükleyiciyi ve eski yordamsal kodun silinmesini Claude yapar** (bkz. "Entegrasyon").

> Kural: bir model bittiğinde hemen dosyaya yazılır ve kendi doğrulaması yapılır. Hepsini bitirip sonda toplu doğrulama yapma.

---

## 0. Kısa özet (önce bunu oku)

1. Her model **ilkel parçalardan** (Part, WedgePart) yapılan, tek bir `Model`'dir. Betik, ışık, arayüz, MeshPart **yok**; SpecialMesh yalnızca elips gövde için (bkz. 1.1).
2. Her model **ayrı bir `.rbxmx` dosyasıdır**; dosya adı = model adı (`Gull.rbxmx` → Model adı `Gull`).
3. Kodun **ayrı ayrı hareket ettireceği parçalar** (kanat, kuyruk, kol...) **ayrı parça** olmalı ve aşağıda yazılan adı taşımalı.
4. Ölçü, renk, malzeme ve parça adları bu dosyada yazıldığı gibidir; bunlar koddan çıkarılmıştır. Sapma = oyunda farklı görünür.
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
- Parça adları İngilizce, `PascalCase`, aşağıdaki listede yazıldığı gibi. Aynı adı taşıyan birden çok parça serbesttir (örn. iki `Eye`).
- Hareketli parçalar (kanat, kuyruk, kol) için adlar **sabit** olmalı çünkü kod `FindFirstChild("LeftWing")` ile bulur.

### 1.4 Teslim yeri
- İstemci tarafında çizilen efekt nesneleri (kuş, balık, deniz canlısı, buz, mevsim süsü, tekne izi...) → `client-assets/<Klasör>/<Ad>.rbxmx`
  (Rojo bunları `ReplicatedStorage.ClientAssets.<Klasör>.<Ad>` altına koyar; istemci okuyabilsin diye.)
- Sunucu tarafında çizilen dekor (harita, ada kiti) → `assets/<Klasör>/<Ad>.rbxmx` (`ServerStorage.Assets` altına).
- Hangi modelin hangi yolda olduğu aşağıdaki iş listesinde yazılıdır.
- Üretici betikler `tools/models/` altına.

### 1.5 Doğrulama (her model için, teslim etmeden önce)
1. `python scripts/check-assets.py` çalışır, hata vermez (bu betik klasörleri/adları/yasak sınıfları denetler).
2. Dosya Python `xml.etree` ile hatasız açılır; model adı dosya adıyla aynı; pivot yazılı.
3. Ölçü kontrolü: modelin sınırlayıcı kutusu bu belgedeki "Kutu" satırıyla ±%10 uyumlu.
4. Şekil kontrolü: bütün `Part` `Shape` değerleri bu belgedeki gibi (özellikle top/blok ters değil, dikey direkler silindir değil).
5. Hareketli parça adları listede yazıldığı gibi var.

### 1.6 Sorun çıkarsa
Bir ölçü/ad belirsizse **tahmin etme**; sorun maddesini rapora yaz ve en yakın makul değeri seç.

---

## 2. İstemci efekt modelleri (`client-assets/`)

Bu bölümdeki her modelin **kodu ayrı parçalarıyla oynatır**. Bu yüzden iki tür iş var:

- **Hareketli modeller (kuş, balık, denizanası):** kodun bildiği adlı parçalar korunur; **ek süs parçaları (göz, yüzgeç, gaga...) serbest** ve
  model merkezini izler. Her modelde parça üst sınırı belirtilmiştir.
- **Durağan modeller (mercan, kaya, deniz yıldızı, dal...):** tamamen serbest tasarım; sınırlayıcı kutu ve parça üst sınırı içinde kal, `Tint` adlı
  parçalar kodun rengini (rastgele ton) alacağı yerlerdir.

> Her tablodaki "Boyut" modelin **ölçek 1 (çarpan 1.0)** hâlidir; oyun kodu `ScaleTo` ile büyütür/küçültür. Modeli bu ölçülerde çiz.

### 2.1 Kuşlar — `client-assets/Birds/`

Kullanıldığı yer: `src/client/Effects/Birds.client.luau`. Gökyüzünde süzülen sürüler. Gövde sürüyü izler, kanatlar çırpar.

| Dosya / Model adı | Rol | Ölçek (kodda) |
|---|---|---|
| `Gull.rbxmx` | Martı (denizin üstünde) | 1.2 – 1.5 |
| `Songbird.rbxmx` | Küçük kuş (adaların üstünde) | 0.7 – 0.9 |

Ortak yapı (iki modelde de aynı **parça adları**; ikisi de ölçek-1 hâlinde çizilir):

| Parça adı | Sınıf / Şekil | Boyut (X,Y,Z) | Not |
|---|---|---|---|
| `Body` (**PrimaryPart**) | Part Block + `SpecialMesh` Sphere (elips) | 0.5 × 0.45 × 1.6 | Gövde. Baş **−Z**. Model pivotu = Body merkezi |
| `LeftWing` | Part Block | 2.2 × 0.08 × 0.7 | Düz kanat. **Merkezi Body merkezinden (−1.1, 0, +0.1)** |
| `RightWing` | Part Block | 2.2 × 0.08 × 0.7 | **Merkezi Body merkezinden (+1.1, 0, +0.1)** |
| (isteğe bağlı) `Head`, `Beak`, `Tail` | Part | küçük | En çok 5 ek parça. Gövdeyle birlikte hareket eder (kanatlar gibi ayrı çırpılmaz) |

- Renk **Gull**: gövde RGB(245,245,245), kanat RGB(190,195,205). Gaga/ayak: sarı-turuncu RGB(245,180,60).
- Renk **Songbird**: gövde RGB(80,70,65), kanat RGB(60,52,48). Gaga: RGB(235,190,70).
- Malzeme SmoothPlastic. Kanatlar yatay düz kalmalı; kod kanatları dinlenme konumundan (gövde merkezinden ∓1.1) başlayıp Z ekseni etrafında çırptırır, bu yüzden kanat parçalarının **kendi merkezi** pivottur.
- Üst sınır: toplam **8 parça**. Kutu (Gull, ölçek 1): X 4.4 (kanat uçları), Y ≤ 0.9, Z 1.8.
- Kabul: kanatlar `LeftWing`/`RightWing` adıyla var, gövde `Body` ve PrimaryPart; pivot yazılı (0,0,0 = Body merkezi).

### 2.2 Balık (sürü ve derin su) — `client-assets/Fish/`

Kullanıldığı yer: `FishLife.client.luau` (yüzeyde dönen süs sürüleri, sıçrama) ve `SeabedLife.client.luau` (derin su sürüleri).
**İkisi de aynı modeli kullanır** (kod rengi ve ölçeği ayarlar).

| Dosya / Model adı | Rol |
|---|---|
| `ReefFish.rbxmx` | Genel süs balığı (ölçek 0.68 – 1.65) |

| Parça adı | Sınıf / Şekil | Boyut | Not |
|---|---|---|---|
| `Body` (**PrimaryPart**) | Part Block + `SpecialMesh` Sphere | 0.55 × 0.5 × 1.4 | Gövde elipsoidi. Baş **−Z**, kuyruk **+Z**, sırt **+Y**. **Kod bunu boyar** (rengi sürüye göre değişir) |
| `Tail` | **WedgePart** | 0.08 × 0.55 × 0.5 | Kuyruk. Merkezi Body merkezinden **(0, 0, 0.55+0.25−0.1 = +0.7)**. Kod kuyruğu kendi merkezi etrafında sallar (Y ekseni). **Kod boyar** (gövdeden %20 açık) |
| (isteğe bağlı) `Eye` ×2 | Part Ball, 0.12³ | Gövdenin yanlarında, ön ucuna yakın (±0.2, 0.1, −0.5). Siyah RGB(15,15,15). **Boyanmaz** |
| (isteğe bağlı) `DorsalFin`, `PectoralFin` ×2 | Part / WedgePart | küçük | `Tint` adlı değil; gövde rengini alır istenirse adı **`Tint`** yap |

- `Tint` adlı her parça kodun verdiği rengi alır (gövde, kuyruk, yüzgeçler). Renk almayacak parçalara (`Eye`) başka ad ver.
- Renkler kodda: turuncu (240,140,50), gümüş (190,200,215), mavi (70,130,205), sarı (245,205,70) ve derin suda ek (80,150,230), (230,90,110), (110,210,170).
  Modeli **nötr açık gri RGB(200,200,205)** çiz; kod boyayacak.
- Malzeme SmoothPlastic. Üst sınır **8 parça**. Kutu (ölçek 1): X 0.55, Y 0.7, Z 1.9.
- Kabul: `Body`, `Tail` adları var; kuyruk **WedgePart**; eşit olmayan Ball yok.

### 2.3 Denizanası — `client-assets/Sea/Jellyfish.rbxmx`

Kullanıldığı yer: `SeabedLife.client.luau:437-467`. Çan nabız atar (Size değişir), dokunaçlar sallanır.

| Parça adı | Sınıf / Şekil | Boyut | Konum (model merkezi = çan merkezi) | Not |
|---|---|---|---|---|
| `JellyBell` (**PrimaryPart**) | Part Block + `SpecialMesh` Sphere | 2.4 × 1.8 × 2.4 | (0,0,0) | Neon, **Transparency 0.45**. Kod Size'ını her karede değiştirir; tek Part kalmalı |
| `JellyTentacle` ×5 | Part Block | 0.12 × 2.6 × 0.12 | (cos a·0.7, **−1.9**, sin a·0.7), a = i/5·2π (i=1..5) | Neon, **Transparency 0.55**. Kod her birini ayrı sallar |

- Renk: açık pembe-mor RGB(240,150,220) (kod 150,190,255'e doğru karıştırır) → modeli RGB(240,150,220) çiz; renk alacak parçalar adı `JellyBell`/`JellyTentacle` olanlardır.
- Ek süs serbest ama en çok **4 ek parça** (çan kenarı, iç organ gibi küçük parçalar adı `Frill`; çanla birlikte hareket eder).
- Kutu: X 2.4, Y ≈ 4.3, Z 2.4. Pivot = çan merkezi.

### 2.4 Mercan — `client-assets/Sea/`

Kullanıldığı yer: `SeabedLife.client.luau:163-228`. Durağan; kod rastgele yaw verip rastgele bir mercan rengiyle boyar. **Tamamen serbest tasarım.**

| Dosya | Tür | Kutu (X,Y,Z) | Parça üst sınırı |
|---|---|---|---|
| `BranchCoral.rbxmx` | Dallı mercan: ortada gövde, 4-6 eğik dal, uçlarda küre | ~ 2.5 × 4.4 × 2.5 | 14 |
| `BrainCoral.rbxmx` | Beyin mercanı: 3 yassı küme yan yana | ~ 5.4 × 1.9 × 3.2 | 10 |
| `FanCoral.rbxmx` | Yelpaze mercanı: **dik duran** 3 ince disk/yelpaze | ~ 4.5 × 4.2 × 1.0 | 10 |

- **Pivot:** zemine oturan taban merkezi (Y=0 modelin en alçak noktası), model merkezi yatayda ortada.
- **Renk:** `Tint` adlı parçalar kodun verdiği mercan rengini alır (turuncu, pembe, mor, sarı, turkuaz). Geri kalan parçalar sabit (beyaz ucu, gövde).
- `BranchCoral` ucu küreleri **dalın tepesinde** olsun (koddaki hata "tabanda" idi; modelde doğrusu geçerli).
- `FanCoral`: yelpaze **dik**, ince (0.2) ve geniş; kodda yatay düşen bir hata vardı, modelde dik olsun.
- `BrainCoral` yüzeyi tümsekli olabilir (küçük bloklar/toplar). Malzeme Slate; `FanCoral` Neon istenirse **Transparency 0.15**.
- Eşit olmayan Ball yok; yassı kümeler için SpecialMesh Sphere (bölüm 1.1).

### 2.5 Kaya, deniz yıldızı — `client-assets/Sea/`

| Dosya | Tür | Kutu | Üst sınır | Not |
|---|---|---|---|---|
| `SeaRock_A.rbxmx`, `SeaRock_B.rbxmx`, `SeaRock_C.rbxmx` | Deniz dibi kayası (3 farklı biçim) | ~ 3 × 2 × 3 (A), 4 × 2.5 × 3 (B), 2.5 × 1.8 × 2.5 (C) | 6 | Slate, gri RGB(110,112,118) (kod 70,95,90'a doğru karıştırır). `Tint` parçaları boyanır. Düzensiz yığın (3-5 blok, hafif döndürülmüş). Tabanı düz |
| `Starfish.rbxmx` | Deniz yıldızı | ~ 2.9 × 0.3 × 2.9 | 8 | 5 kol (kol ≈ 0.5 × 0.25 × 1.5) merkezde birleşir; kolların uçları hafif yukarı kıvrık olabilir. Turuncu RGB(240,120,70); `Tint` parçaları rastgele turuncu→pembe |

- Pivot: tabanın merkezi (zemine oturur). Hepsi durağan.

### 2.6 Kış dalı ve mevsim yaprağı — `client-assets/Season/`

| Dosya | Kullanım | Kutu | Üst sınır | Not |
|---|---|---|---|---|
| `BareBranch.rbxmx` | Kışın çıplak ağaçta dal (kod ağaç başına 4 dal koyar) | ~ 0.25 × 3 × 0.25 (ince dal) | 5 | Ahşap kahvesi. Uzun eksen **Y**, pivot dalın **alt ucu** (gövdeye yapışan uç). Küçük yan dal serbest |
| `FallingLeaf.rbxmx` | Sonbahar yaprağı / ilkbahar çiçek yaprağı (sürekli dönerek düşer) | ~ 0.22 × 0.05 × 0.42 | 3 | Basık elips (SpecialMesh Sphere). Renk koddan (`Tint`): turuncu RGB(207,104,37) / pembe RGB(255,198,219). Pivot merkez |

> Not: kıyı buzu pulu, toz bulutu, parıltı, tekne köpük izi, yüzme izi, yıldırım çubukları ve yağış taşıyıcıları **tek parçalık efekttir**
> ve her karede boyutu/saydamlığı değiştirilir; model yapılmaz, **kodda kalır** (bkz. bölüm 5).


## 3. Harita ve dekor modelleri (`assets/`) — şu an karşılığı OLMAYANLAR

Hepsi sunucu tarafında çizilir ve `assets/<Klasör>/<Ad>.rbxmx` altına konur. **Pivot her zaman zemin yüzeyindeki noktadır (Y=0 = zemin), ön −Z.**
Tabela/direk modellerinde yazı (WorldUi) kodda kalır; modelde **yalnızca tahta/direk geometrisi** olur.

### 3.1 Köprü modülleri — `assets/BridgeModels/` (ÖNCELİK 1)

Kullanıldığı yer: `MapParts.luau:234-252`, `HubBuilder.luau:176-196`. 24 köprü var; uzunluk her köprüde farklı (adalar arası mesafe, meydan→ana ada 69 stud).
Tek parça halinde değil, **modül tekrarıyla** kurulacak (kod modülleri uç uca dizer).

| Dosya | Boy (Z) | Parçalar |
|---|---|---|
| `BridgeModule_8.rbxmx` | 8 | `Deck` Block **8 × 1 × 8** RGB(140,100,60) WoodPlanks; `Rail` ×2 Block **0.5 × 2 × 8** RGB(110,80,50) Wood, konum x=**±4**, y=**+1.5** (Deck merkezine göre) |
| `BridgeModule_2.rbxmx` | 2 | aynı yapı, boy 2 (kalan kısım için) |

- Pivot: **Deck'in üst yüzünün orta noktası** (köprü yürüme yüzeyi). Köprü ekseni **Z**.
- Süs serbest (korkuluk direkleri, kiriş altı) ama genişlik 8, rayların dışı x=±4.25'i **aşmasın**; Deck üst yüzü düz kalsın. Üst sınır modül başına **8 parça**.
- Kural: üst yüzey düz ve çarpışır (`CanCollide=true`) olmalı; korkuluk **çarpışmaz** (`false`). Köprünün üzerinde yürünür.

### 3.2 Ada tabelası iskeleti — `assets/SignModels/IslandSign.rbxmx` (ÖNCELİK 1)

Kullanıldığı yer: `SatelliteBuilder.luau:216-247`. 18 adet (her uzman adada 1). Kod "adanın adı + ikon + özellik" yazısını tahtanın ön ve arka yüzüne ekler.

| Parça adı | Boyut | Konum (pivot = iki direğin ortası, zeminde) | Not |
|---|---|---|---|
| `SignPost` ×2 | 0.5 × 15.4 × 0.5, RGB(140,100,60) Wood | x = **±3.55**, y = **7.7**, z = 0 | Çarpışır |
| `IslandSign` | **6.4 × 2.2 × 0.35**, RGB(85,60,40) WoodPlanks | (0, **13.6**, 0) | **Adı `IslandSign` olmalı** (kod bu parçaya yazı koyar). `CanCollide=false` |

- Süs serbest (direk başlıkları, çatı, ip) ama tahtanın ön/arka yüzü **düz** kalsın. Üst sınır **10 parça**.

### 3.3 Ana ada yön tabelası — `assets/SignModels/Signpost_Direction.rbxmx`

Kullanıldığı yer: `IslandBuilder.luau:47-68`. Ana ada başına 1 adet (6 toplam).

| Parça adı | Boyut | Not |
|---|---|---|
| `Post` | 0.6 × 7 × 0.6, RGB(110,80,50) Wood | Dikey direk, zeminde. `CanCollide=false` |
| `Board` ×3 | 5.4 × 1.3 × 0.3, RGB(150,110,70) WoodPlanks | Direğe aşağı doğru üst üste (≈ y 5.6 / 4.0 / 2.4). Her tahta direğin farklı yönüne hafif dönük olabilir ama **yazı alanı düz kalsın**. Kod yazıyı `Board` yüzlerine koyar |

- Pivot: direk tabanı. Üst sınır 8 parça.

### 3.4 "SATILIK" seti — `assets/SignModels/SaleMarker.rbxmx`

Kullanıldığı yer: `SatelliteBuilder.luau:180-214`. Kilitli uzman adada 4 yerde, toplam 72 set. Ada açılınca kod gizler.

| Parça adı | Boyut | Konum | Not |
|---|---|---|---|
| `SalePole` | 0.45 × 10 × 0.45, RGB(120,85,55) Wood | y = 5 | Çarpışmaz |
| `SaleBanner` | **4.2 × 2.4 × 0.2**, RGB(196,60,52) Fabric | (2.3, 8.6, 0) | **Adı `SaleBanner` olmalı**; kod "SATILIK" yazısını ön ve arka yüze koyar. Düz |
| `SaleStone` ×3 | (1.6+0.5r) × (1.2+0.2r) × (1.8+0.4r), r=1,2,3; RGB(120,118,110) Slate | x = 1.3r−3.4, y = 0.5, z = 1.6+0.5r | Hafif döndürülmüş (0.1r, r, 0.05 rad). Çarpışır (kod `SaleStone` çarpışmasını kapatıp açar) |

- Pivot: direk tabanı. Üst sınır 8 parça. Süs: flamaya iki ucu ip, taşlara çalı serbest; renk şeması aynı kalsın (kırmızı flama = "satılık").

### 3.5 Meydan tabelaları — `assets/HubModels/` (ÖNCELİK 3)

Kullanıldığı yer: `HubBuilder.luau:134-173`. Yazı kodda; yalnızca iskelet:

| Dosya | İçerik |
|---|---|
| `HubTitleBoard.rbxmx` | `Pole` 1 × 18 × 1 RGB(80,60,40) Wood (y=9) + `Title` **20 × 6 × 1** RGB(150,45,40) Wood, direğin üstünde (y≈16). `Title` adı sabit |
| `HubTravelBoard.rbxmx` | `TravelBoard` **6 × 2.4 × 0.4** WoodPlanks + iki kısa direk |
| `HubPlayerBoard.rbxmx` | `PlayerBoard` **16 × 7.5 × 0.4** RGB(60,42,30) WoodPlanks, `CanCollide=false` + çerçeve süsü |

- Pivot: tahta/direk tabanı, ön −Z. Yazı alanı düz. Üst sınır 12 parça.

### 3.6 Çeşitlilik: mevcut tek-tohumlu şablonların varyantları (ÖNCELİK 2)

Şu an `assets/CommonDecor/`'da her tür için **tek** örnek (seed 11) var; kod ise 4-5 çeşit üretiyor. Bunlar kodla çeşitlendirildiği için,
varyantları modele çevirince kodun rastgele geometri üretimi silinir.

| Hedef | Dosyalar (`assets/CommonDecor/`) | Şartname |
|---|---|---|
| Meşe | `OakTree_A..D.rbxmx` (4 şekil) | Gövde `Trunk` (Cylinder çap 1.8, h 8), 1-2 `Branch`, 4-6 top yaprak (`Leaves`, çap 5-8). Yaprak rengi **(70,140,60) (85,155,65) (60,125,55) (100,160,70)** dörtlüsünden; **`Leaves` adlı parçalar kod tarafından boyanabilir** (mevsim). Ölçek 1 = kodun ölçek 1.0'ı. Kutu ~ 8 × 14 × 8. Üst sınır 9 parça |
| Çam | `PineTree_A..C.rbxmx` (3 şekil) | `Trunk` (çap 1.2, h 11), 5 katman `Needles` (**Block + SpecialMesh Sphere**, katman X/Z 8.5→2.2, Y 2.4). Renk (45,100,60) / (38,88,52). Kutu ~ 8.5 × 14.5 × 8.5. Üst sınır 8 |
| Çalı | `Bush_A.rbxmx`, `Bush_B.rbxmx`, `Bush_Berry.rbxmx` | 3 top `Leaves` (çap 2.2-3.4) ; `Bush_Berry`'de 4 küçük kırmızı `Berry` (çap 0.45, RGB(220,60,70)). **`Leaves`/`Berry` adları sabit** (mevsim kodu boyar/gizler). Kutu ~ 4 × 3 × 4. Üst sınır 8 |
| Çiçek tarhı | `FlowerPatch_Yellow/Pink/White/Purple/Orange.rbxmx` (5) | 7 `Stem` (0.12 × 0.6-1.1 × 0.12, RGB(70,130,60)) + 7 `Bloom` (top, çap 0.45): renkler **(250,220,80) (240,120,160) (250,250,250) (170,120,230) (245,140,60)**. Kutu ~ 4 × 1.2 × 4. **`Stem`/`Bloom` adları sabit**. Üst sınır 14 |
| Sandık | `Crate_16.rbxmx`, `Crate_20.rbxmx`, `Crate_24.rbxmx` | `Box` kenar 1.6 / 2.0 / 2.4 + 2 çıta (kalınlık sabit 0.2). RGB(170,125,75) WoodPlanks. Üst sınır 4 |
| Çim tutamı | `GrassTuft.rbxmx`, `GrassTuft_Flower.rbxmx` | `Tuft` ×2 çapraz levha (0.14 × 1 × 1.2, birbirine 90°, Grass), 4 renk (88,152,64) (104,168,70) (72,136,58) (126,176,78); `_Flower`'da ek `Stem` + `Bloom`. Kod yaklaşık 140 + 18×45 + bölge tutamı yerleştirir |

> Varyant sayısı arttıkça kod kendi geometrisini silebilir; yeterli çeşitlilik yoksa aynı şablon tekrarlandığı için "klonlama" belli olur.
> En az **3 şekil / tür** hedefle. Daha fazlası (çeşitlilik) bölüm 4'te.

---

## 4. İstek üzerine ek çeşitlilik paketi (ÖNCELİK 4, kod yerleşimini Claude ekler)

Aşağıdakiler **kodda şu an yok**; modeller gelirse ben yerleştirme kodunu eklerim. Tek tek istenebilir.

| Klasör | Modeller | Not |
|---|---|---|
| `assets/CommonDecor/` | `Rock_A..C` (kara kayası), `Stump_A..B` (kütük), `LogPile` | Ada çimenliğine serpiştirilir. Kutu ~ 2-3 stud. Slate/Wood |
| `assets/CommonDecor/` | `Reed_A..B` (sazlık), `Cattail` | Kıyı ve suya yakın tarh için. Pivot zeminde |
| `assets/CommonDecor/` | `PalmTree_A..B`, `BirchTree_A..B` | Yeni ağaç türleri; temalara göre kullanılabilir |
| `assets/CommonDecor/` | `Mushroom_A..C`, `Pumpkin`, `Sunflower_Single` | Küçük süs, tohumla serpiştirilir |
| `assets/ShoreModels/` | `Pile.rbxmx` (tek kazık 0.7 çap, h 12) | Yükseklik kodla `ScaleTo` (Y) ayarlanır |
| `assets/SeasonModels/` | `SnowCap_Oak`, `SnowCap_Pine`, `SnowCap_Bush`, `Snowman` | Kış süsü; kod sadece görünür yapar |
| `assets/HubModels/` | `Hub_Statue`, `Hub_Banner`, `Hub_Flag` | Meydan süsü |

Her biri için kural aynı: ölçek 1'de çiz, pivot zeminde, `Tint` adlı parçalar kod renklendirsin, parça sınırı ≤ 12.

---

## 5. Modele DÖNÜŞMEYECEKLER (kodda kalır; GPT'den bu yüzden istenmiyor)

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

## 6. Öncelik sırası ve teslim

| Sıra | Grup | Dosya sayısı |
|---|---|---|
| **P1** | Köprü modülleri (3.1), IslandSign (3.2), Signpost_Direction (3.3), SaleMarker (3.4) | 5 |
| **P1** | Kuşlar (2.1), ReefFish (2.2), Jellyfish (2.3) | 4 |
| **P2** | Mercan ×3 (2.4), Kaya ×3 + Deniz yıldızı (2.5), BareBranch + FallingLeaf (2.6) | 9 |
| **P2** | Ağaç/çalı/çiçek/sandık/çim varyantları (3.6) | ~25 |
| **P3** | Hub tabelaları (3.5) | 3 |
| **P4** | Ek çeşitlilik paketi (bölüm 4) | ~25 |

**Her grup bittiğinde dur ve raporla**; Claude o grubu koda bağlayıp eski yordamsal kodu siler, sonra sıradaki gruba geç.

### 6.1 Rapor şablonu (her model için bir satır)

    Ad | Dosya yolu | Parça sayısı | Kutu (X×Y×Z) | Pivot | Notlar/sapma

---

## 7. Entegrasyon (Claude yapar — GPT dokunmaz)

**Durum (2026-10-02): tamamlandı.** Bu listedeki modellerin hepsi koda bağlandı ve eski çizim kodu silindi: `client-assets/` modelleri `Core/ClientModelAssets` ile (kuş, balık, mercan, kaya, deniz yıldızı, denizanası), `assets/` modelleri `World/ModelAssets` ile
(`HomeBuildings`, `HubNpcs`, `DecorProps/Nature/Lights/Shore`, `MapParts`, `IslandBuilder`, `SatelliteBuilder`, `BarnVisualService`, `IslandSiteParts`). Ayrıntı ve güncel durum tablosu `docs/GPT_ILETISIM.md` "Entegrasyon durumu".
Kodda kalanlar (modele çevrilmez): zemin plakaları, Terrain/kıyı, taş yollar, çim yamaları, dağ halkası, `BareBranch`/`FallingLeaf` havuz parçaları. `check-assets.py` `verify.ps1` içinde çalışır; yerleşim değişirse `MAP_VERSION` artırılır ve harita yeniden kurulur (`tests-tooling.mdc` "Geliştirme otomasyonu").

---

## 8. GPT'ye verilecek kısa komut (kopyala-yapıştır)

    Bu depodaki docs/GPT_MODEL_IS_LISTESI.md dosyasını baştan sona oku. Bölüm 1 (ortak sözleşme) ZORUNLU.
    Bölüm 6'daki P1 grubundan başla. Her model için: (1) tools/models/ altında tek bir Python üretici yaz,
    (2) .rbxmx dosyalarını belgedeki yola yaz, (3) bölüm 1.5'teki doğrulamaları çalıştır
    (python scripts/check-assets.py), (4) bölüm 6.1 şablonuyla rapor ver.
    Şekil değerlerinde Ball=0, Block=1, Cylinder=2 olduğuna ve eşit olmayan Ball'un küre çizildiğine DİKKAT et.
    Bir grup bitince dur. Oyun kodunu değiştirme.
