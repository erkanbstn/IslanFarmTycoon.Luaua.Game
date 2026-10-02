# Model iş planı (Studio MCP ajanıyla model üretimi)

Kurallar `docs/MODEL_SOZLESMESI.md`'dedir (bu belge onları tekrar etmez, § numarasıyla gösterir). Burada: modeli repoya
alma yolu, kod tarafında gereken kararlar, pilot, ajan şablonları ve riskler.

## 1. Doğrulanan / doğrulanamayan araç yetenekleri

| Yetenek | Durum | Kaynak |
|---|---|---|
| MCP araçları: `execute_luau` (Edit/Client/Server veri modeli), `generate_procedural_model`, `generate_mesh`, `insert_asset`, `search_game_tree`, `inspect_instance`, `screen_capture` (kamera parametreli), `start_stop_play`, `character_navigation`, `get_console_output` | Doğrulandı | create.roblox.com/docs/studio/mcp |
| MCP güvenlik notu: istemci açık place'i okuyup değiştirebilir; yalnızca güvenilir istemci bağla | Doğrulandı | aynı sayfa |
| `execute_luau`'nun güvenlik düzeyi (Plugin yetkisi var mı) | **Doğrulanamadı** | belgede yok |
| `SerializationService:SerializeInstancesAsync` → `buffer` | Var, ama `PluginOrOpenCloud` yetkisi ister; `execute_luau`'da çalışırlığı **doğrulanamadı**; Luau diske yazamaz | Engine API SerializationService |
| MCP ile diske `.rbxm` kaydetme aracı | **Yok / doğrulanamadı** (araç listesinde dosya dışa aktarma yok) | MCP sayfası |
| Rojo `.rbxm`/`.rbxmx` model dosyalarını eşler | Doğrulandı; MeshPart `MeshId` ve bazı ikili tipler canlı eşlenemez | rojo.space/docs/v7/sync-details |
| `.model.json` (elle yazılan JSON model) | Doğrulandı; öznitelik/etiket/`WorldPivot`/`PrimaryPart` (Ref) desteği Rojo 7.4.4'te **doğrulanamadı** | aynı sayfa |
| `rojo syncback` (place/model dosyasından projeye) | Rojo **7.7.0**'da geldi; repo `rojo-rbx/rojo@7.4.4` (`rokit.toml:2`) | Rojo 7.7.0 sürüm notu |
| `$path` verilmiş düğümde `$ignoreUnknownInstances` varsayılanı `false` → Rojo'nun bilmediği çocuk **silinir** | Doğrulandı | rojo.space/docs/v7/project-format |

**Sonuç:** `ServerStorage.Assets` `$path: "assets"` ile eşli (`default.project.json:12-16`). Studio'da doğrudan
`Assets/Buildings` içine kurulan model, `rojo serve` bağlanınca silinir. Ajan **asla** orada çalışmaz; tezgâh olarak
Rojo'nun yönetmediği `Workspace.ModelBench` kullanılır (Workspace düğümünde `$path` yok, `default.project.json:62-69`).

## 2. Repoya alma yolu

| Yol | Nasıl | Artı | Eksi | Karar |
|---|---|---|---|---|
| **A. `.rbxmx` (Save to File)** | Tezgâhtaki Model seç → sağ tık *Save to File...* → `assets/<Buildings|Animals>/<id>.rbxmx` | Pivot, PrimaryPart, etiket, öznitelik korunur; XML olduğu için diff ve Python denetimi mümkün | Kullanıcı tıklaması gerekir (model başına ~10 sn) | **Varsayılan** |
| B. `.model.json` (ajan yazar) | `execute_luau` modeli JSON metnine çevirip döndürür, ajan `Write` ile dosyaya yazar | Tam otomatik | Pivot/Ref/öznitelik desteği doğrulanamadı (pivot kayarsa bina havada/gömük kurulur) | Pilotta bir kez denenir (P0) |
| C. `rojo syncback` | Place'i `.rbxl` kaydet → `rojo syncback` | Toplu | Rojo 7.7 yükseltmesi gerekir; tüm projeyi etkiler | Şimdilik değil |
| D. SerializationService + base64 | `execute_luau` → buffer → base64 → ajan çözüp `.rbxm` yazar | Otomatik, ikili doğru | Yetki ve çıktı boyutu doğrulanamadı | Yalnızca B başarısızsa denenir |

`.rbxm` yerine `.rbxmx` seçilir: denetim betiği XML'i okuyabilir, git diff anlamlı olur.

### Harita eklentisi ve `MAP_VERSION`
- Binalar/hayvanlar çalışma anında `Presentation/` tarafından kurulur (`plot.Upgrades`, `UpgradeVisualService.luau:171`): `MAP_VERSION`
  (`MapBuilder.luau:28`) artmaz, eklenti (`plugin/MapTool.server.luau`) yeniden derlenmez (AGENTS.md "çalışma anı `Presentation/` için gerekmez").
- Bölge zemini/çit (`MapParts.buildZone`) veya `World/` dekoru modelle değişirse o zaman `MAP_VERSION` + eklenti gerekir; bu plan kapsamı dışı.

### Tutarlılık denetimi (öneri: `scripts/check-assets.py`, `verify.ps1`'e eklenir)
1. `assets/Buildings/*.rbxmx` adları `Config.UPGRADES` kimliği, `assets/Animals/*` adları tür kimliği olmalı (kimlikler türetildiği için
   `.tools/luau` ile `Config`'i yükleyip liste döken küçük bir Luau betiği; `run-tests.py` aynı yorumlayıcıyı kullanır).
2. XML'den: kök sınıf `Model`; BasePart sayısı ≤ sözleşme §3a/§3b bütçesi; `Script/LocalScript/ModuleScript`, `ProductionPromptAnchor`,
   `ProductionPrompt`, etkin `PointLight/SpotLight/SurfaceLight` yok; `Window*` adlı parçalar `Glass`.
3. Bina: sınır kutusu §3a gövde kutusunu ve yüksekliğini aşmıyor; pivot y = taban (±0.1).
4. Yönlendirme dosyası değişmez: `check-ai-docs.py` `docs/*.md` için yalnızca `MIMARI.md`'yi zorunlu tutar; bu iki belge serbesttir.

## 3. Kod tarafında gereken kararlar (bu planda kod değişmez; ayrı Sonnet paketi)

| # | Konu | Neden | Öneri | Pilot için şart mı |
|---|---|---|---|---|
| K1 | Bina klonunda her parça çarpışır | `AssetSanitizer.luau:12` `CanCollide = collide` | Şablondaki `CanCollide`'ı koru (yalnızca `true`→ zorlamayı kaldır) ya da `NoCollide` özniteliği | Hayır (pilot binada tabela/ince süs yok) |
| K2 | Asset takma adı yok | `cloneAsset` tam ad arar (`UpgradeVisualService.luau:64`) | `BUILDER_ALIASES` asset aramasına da uygulansın (`duck_house` modeli `duck_packer`'ı da kapsasın) | Hayır |
| K3 | ~~Kod kurucusu silinemez~~ | Çözüldü (2026-10-02): kurucular silindi, `hasBuildSite` modele bakar | Model yoksa görünüm çizilmez; `check-assets.py` denetler | — |
| K4 | Ağıl/ahır/eklenti köprüsü yok | sözleşme §1, §3c | `ZoneVisualService.luau:117-130`'a `Assets/Zones` + `markObstacles` | Hayır (2. dalga) |
| K5 | `VISUAL_VERSION` | Sahipli binalar yalnızca sürüm değişince yeniden kurulur (`:177-180`) | Asset değişince sunucu yeniden açılır; canlı yenileme gerekmez | Hayır |

## 4. Pilot: ördek çiftliği

| Seçim | Neden | Risk |
|---|---|---|
| **Bina: `duck_packer`** (ana ada, (43,0,-21), `MapLayout.luau:88`) | Son çakışma düzeltmesi bu bölgede (`1556ceb`); kodda takma ad (`duck_house`) ile ortak, karşılaştırması kolay; üretim tesisi olduğundan prompt + iş çubuğu + gece penceresi aynı anda sınanır | Düşük: kod kurucusu yedekte; dosya silinirse eski görünüm döner |
| **Hayvan: `duck`** (`Config/Islands.luau:134` ana hayvan) | Aynı ada → tek ekran görüntüsünde ikisi; küçük model (≤ 20 parça); su bölgesi değil (SwimDepth yalnızca balık, `MapParts.luau:164-166`) | Düşük |

### P0 (bir kez, 10 dk): dışa aktarma yolu denemesi
`Workspace.ModelBench`'te 3 parçalı deneme modeli → Yol B ile `.model.json` yaz → `rojo build default.project.json -o .test-build/p0.rbxlx`
→ Studio'da `PivotTo` sonrası taban y doğru mu? Doğruysa B kullanılabilir; değilse Yol A.

### Başarı ölçütleri (ekran görüntüsü kontrol listesi)

| # | Ölçüt | Nasıl ölçülür |
|---|---|---|
| 1 | İç içe geçme yok (bina ↔ anıt, yol, seviye süsleri; hayvan ↔ çit/dekor) | Üstten + önden `screen_capture`; `execute_luau` ile `GetPartBoundsInBox` çakışma listesi boş |
| 2 | Pivot doğru: taban = ada yüzeyi, kapı -Z (yola bakıyor) | `GetBoundingBox` alt y − spot y ∈ [-0.1, 0.1] |
| 3 | Üretim prompt'u çalışıyor | Play → `character_navigation` kapıya → prompt görünüyor, E ile panel açılıyor |
| 4 | İş çubuğu bina üstünde, binaya gömülü değil | Üretim başlat → ekran görüntüsü |
| 5 | Gece pencereleri yanıyor | `Lighting.ClockTime = 22` → ekran görüntüsü; `CollectionService:GetTagged("NightWindow")` sayısı ≥ pencere |
| 6 | Parça bütçesi | `PartCount` özniteliği ≤ 35 (bina) / ≤ 20 (ördek) |
| 7 | Seviye 1-5 süsleri binaya girmiyor | Yönetici panelinden seviye artır, her seviyede küçük ekran görüntüsü |
| 8 | Hayvan: yavru/genç/yetişkin ölçeği, isim etiketi başın üstünde, yürürken parçalar ayrılmıyor | Play, 10 sn izle |
| 9 | Dosya repoda, `rojo build` hatasız, denetim (varsa) geçiyor | `python scripts/run-tests.py`, `rojo build` |
| 10 | (Eski adım: yedek kod görünümü) artık yok; dosya kaldırılınca görünüm çizilmez ve `warn` düşer | `python scripts/check-assets.py` |

## 5. Ajan şablonları

### 5a. Sonnet — tek model (kopyala, `<...>` doldur)

```text
Görev: Roblox Studio'da TEK model yap: <Buildings|Animals>/<id>. Repo: C:\Users\erkan\Desktop\roblox-oyun.
Oku (yalnızca bunlar): docs/MODEL_SOZLESMESI.md §2 ve §<3a|3b>, docs/MODEL_IS_PLANI.md §1-2 ve §4 tablosu.
Referans görünüm: mevcut model dosyası ya da `git log` (kod kurucuları 2026-10-02 silindi; renk/oranları mevcut `assets/` modelinden al).

Kurallar:
- Studio MCP ile çalış. Önce list_roblox_studios + get_studio_state; play modundaysan durdur.
- Tezgâh: Workspace.ModelBench (yoksa oluştur). ServerStorage.Assets'e ASLA yazma (Rojo siler).
- Parçaları execute_luau ile, her çağrıda bir bölüm (taban, duvar, çatı, süs) olacak şekilde kur. generate_mesh kullanma;
  generate_procedural_model yalnızca taslak için, sonucu parçalara indirip sözleşmeye uydur. insert_asset yok.
- Her bölümden sonra execute_luau ile sayı/kutu raporu al (parça sayısı, GetBoundingBox), ekran görüntüsü ALMA.
- Bitince tek screen_capture (önden + üstten, küçük). Düzeltme gerekirse yalnızca ilgili bölgeyi küçük ölçekte yeniden çek.
- Sözleşmedeki YASAK listesini execute_luau ile tara (script, açık ışık, ProductionPromptAnchor, Window+Glass dışı pencere).
- Dışa aktarma: <A: kullanıcıya "ModelBench.<id>'i assets/<klasör>/<id>.rbxmx olarak Save to File yap" de ve bekle |
  B: modeli .model.json'a çevirip assets/<klasör>/<id>.model.json yaz>.
- Sonra Play'de doğrula: plan §4 ölçütleri 1-8 (bina) ya da 1, 2, 6, 8 (hayvan). Gece için ClockTime=22.
- Kod dosyası değiştirme, commit/push yapma, soru sorma; takılırsan raporda yaz.

Rapor (sohbette ya da `docs/GPT_ILETISIM.md` "Teslimler"de, ≤ 25 satır): kontrol listesi (✓/✗ + ölçülen değer), parça sayısı, kutu ölçüsü,
dosya yolu, açık sorunlar, kod tarafına önerilen değişiklik (varsa K1-K5 numarasıyla).
```

### 5b. Haiku — tekrar işi (ör. aynı binanın ikinci adı, renk varyantı, denetim)

```text
Repo C:\Users\erkan\Desktop\roblox-oyun. Tek iş: <ör. assets/Buildings/duck_packer.rbxmx'i duck_house adıyla kopyala ve
içteki kök Model adını duck_house yap | ModelBench.<id> parça sayısı ve kutusunu raporla>.
Yalnızca docs/MODEL_SOZLESMESI.md §<n>'e bak. Başka dosyaya dokunma, commit yapma. 5 satırlık sonuç yaz.
```

## 6. Riskler ve kararlar

| # | Risk | Etki | Karar |
|---|---|---|---|
| R1 | Stil tutarsızlığı: `generate_mesh` dokulu mesh, voxel stile uymaz; MeshPart Rojo'da canlı eşlenmez; mesh varlıkları hesaba yüklenir | Yüksek | Yalnızca parça (Part/WedgePart/ball). Procedural yalnızca taslak |
| R2 | Rojo `Assets` altındaki Studio modellerini siler | Yüksek | Tezgâh `Workspace.ModelBench`; repo dosyası tek kaynak |
| R3 | Bina klonu her parçayı çarpışır yapar (K1) | Orta | Pilotta tabela/ince süs yok; K1 ikinci dalgadan önce |
| R4 | Pivot kayması (`.model.json`) | Orta | P0 denemesi; başarısızsa Yol A |
| R5 | Parça bütçesi aşımı (mobil, hayvan animatörü her kare taşır) | Orta | §4 ölçüt 6 + denetim betiği |
| R6 | MCP istemcisi place'i değiştirebilir | Orta | Yalnızca güvenilir istemci; oturumdan önce place yedeği (*File → Save to File* `.rbxl`, repo dışı) |
| R7 | Ajan geçerli dosya yazar ama oyunda görülmez (yanlış ad) | Düşük | Ad = kimlik; denetim adım 1 |

**AI üretimine uygun değil (kod kalsın):** balıkçı teknesi (istemci animasyonu ve katı parça adları, `UpgradeVisualService.luau:99-121`),
bölge zemini/çit (harita, `MAP_VERSION`), seviye işaretleri ve seviye süsleri (zemine/bina kutusuna göre hesaplanır), gece lambaları
(`WorldDecor.lamp` sözleşmesi), tabelalar (`WorldUi.sign` ve çeviri).

**Geri dönüş:** kod kurucuları silindi; bir modeli geri almak için dosyayı git geçmişinden getir.

## 7. Sıra

1. P0 dışa aktarma denemesi → 2. pilot (`duck_packer` + `duck`) → 3. Opus kısa inceleme (rapor + ekran görüntüsü) →
4. K1 + K2 + `check-assets.py` (tek Sonnet paketi) → 5. kalan binalar (ada başına bir oturum) → 6. K4 ve ağıllar.
