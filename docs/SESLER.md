# Ses rehberi

Bütün sesler `src/shared/Config/Audio.luau` içinde tanımlıdır. Her ses bir **yuva**dır: `id` boşsa (`""`) o yuva **sessizdir**.
Kendi sesini yüklediğinde yalnızca ilgili yuvanın `id` alanına `"rbxassetid://NUMARA"` yaz; kodda başka bir şey değişmez.
Ses düzeyi: yuvanın `volume` değeri x oyuncunun Ayarlar'daki sürgüsü. Üç SoundGroup vardır: efektler `SfxMaster` ("Efekt sesleri"), ortam döngüleri + hayvan sesleri `AmbienceMaster` ("Ortam sesleri"), müzik `MusicMaster` ("Müzik"). Sürgü düzeyleri ve "Hareketi azalt" hesaba kaydedilir (`save.audio`, `save.reducedMotion`; `RequestSetPreference`, `Modules/Preferences`); varsayılanlar `Config.AUDIO_DEFAULTS`. `pitch` isteğe bağlıdır (1 = normal).
Aynı yuva 0,05 sn içinde ikinci kez çalmaz (üst üste binmesin). Ses dosyalarını Creator Hub'a yükleyip kimliğini al (ses yükleme
için hesap doğrulaması ve telif kuralları geçerlidir).

## 1. Arayüz ve olay sesleri (`SOUNDS`)

Durum: **Var** = şu an motorun kendi yer tutucu dosyası çalıyor (kendi sesinle değiştir), **Boş** = yuva hazır, ses yok (yüklediğin anda çalar).

| Yuva | Ne zaman çalar | Nerede bağlı | Durum | Önerilen ses |
|---|---|---|---|---|
| `click` | Her buton tıklaması | `Ui/Kit/Controls` (tüm düğmeler, menü karoları, slider) | Var | Kısa, yumuşak "tık" (çok kısık, sık çalar) |
| `coin` | Para platformundan para toplama | `Ui/FarmHud` (Notify "money") | Var | Kısa, tok bozuk para; **tok ve kısık** (sık çalar) |
| `success` | Satın alma/işlem başarılı | `Core/PurchaseController`, `Ui/IslandManager` | Var | Olumlu kısa "ding" |
| `error` | Reddedilen işlem / hata bildirimi | `Core/PurchaseController`, `Ui/FarmHud`, `IslandManager` | Var | Alçak, nazik "bzzt" |
| `build` | Yeni bina/yükseltme belirirken | `Effects/BuildEffects` | Var | İnşaat/çekiç + kısa zafer |
| `ui_open` | Pencere açılır | `Ui/Kit/Windows` (tüm pencereler) | Boş | Hafif kayma/"whoosh" |
| `ui_close` | Pencere kapanır | `Ui/Kit/Windows` | Boş | `ui_open`'ın tersi |
| `notify` | Bilgi bildirimi (mavi toast) | `Ui/FarmHud` (Notify "info") | Boş | Yumuşak zil |
| `animal_buy` | Hayvan satın alındı | `Interaction/EventSounds` (hayvan sayısı arttı) | Boş | Kısa hayvan "hoop"/pop |
| `animal_sell` | Hayvan satıldı | `EventSounds` (hayvan sayısı azaldı) | Boş | Nötr kısa "pat" |
| `upgrade_buy` | Yükseltme alındı | `EventSounds` (alınan yükseltme arttı) | Boş | Tatmin edici "ka-ching" + yükseliş |
| `expansion_buy` | Bölge/tesis geliştirme seviyesi | `EventSounds` (geliştirme toplamı arttı) | Boş | Çekiç + parlayan "çın" |
| `barn_level` | Ahır seviyesi arttı | `EventSounds` | Boş | Büyük kutlama (kısa fanfar) |
| `production_start` | Üretim partisi başladı | `EventSounds` (yeni iş) | Boş | Makine çalışma / düğme basma |
| `production_ready` | Parti hazır oldu | `EventSounds` (süre doldu) | Boş | Fırın "ding" / tamamlanma zili |
| `production_claim` | Parti teslim alındı | `EventSounds` (iş kalktı) | Boş | Kasa/çuval teslim sesi |
| `contract_done` | Ahır siparişi teslim edildi | `EventSounds` (teslim sayacı arttı) | Boş | Ticaret "onay" + bozuk para |
| `achievement` | Başarım ödülü alındı | `EventSounds` (başarım sayısı arttı) | Boş | Ödül fanfarı (kısa, parlak) |
| `daily_claim` | Günlük ödül alındı | `EventSounds` (günlük gün değişti) | Boş | Hediye açma |
| `item_buy` | Eşya satın alındı | `EventSounds` (eşya sayısı arttı) | Boş | Dükkân zili |
| `item_equip` | Eşya takıldı/çıkarıldı | `EventSounds` (takılı değişti) | Boş | Kumaş/metal "tık" |
| `season_change` | Mevsim değişti | `EventSounds` (sunucu saatinden) | Boş | Yumuşak mevsim geçişi |
| `golden_spawn` | Altın hayvan belirdi | `Ui/FarmHud` (merchantNotice) | Boş | Parıltı/"şıngırtı" |
| `merchant_arrive` | Gezgin tüccar geldi | `Ui/FarmHud` (merchantNotice) | Boş | Bisiklet/çan, yolculuk sesi |

## 2. Ortam döngüleri (`AMBIENCE`)

Sürekli (döngü) çalan, mevsim/hava/gece durumuna göre açılıp kısılan katmanlar. Boş kimlik = o katman yok. Kod: `Effects/Soundscape`.

| Yuva | Ne zaman | Durum | Önerilen ses |
|---|---|---|---|
| `birds` | İlkbahar/yaz gündüz | Boş | Kuş cıvıltısı (döngü) |
| `wind` | Sonbahar/kış | Boş | Rüzgâr (döngü) |
| `rain` | Yağmur | Boş | Yağmur (döngü) |
| `storm` | Fırtına | Boş | Gök gürültüsü + yağmur |
| `night` | Gece | Boş | Cırcır böceği (döngü) |

## 3. Hayvan sesleri (`ANIMAL_SOUNDS`)

Yakındaki yetişkin hayvan arada bir çıkarır (3B, uzaklaşınca kısılır). Kod: `Effects/Soundscape`. `id` her tür için ayrıdır.

`cow`, `chicken`, `horse`, `goat`, `duck`, `sheep`, `pig` — hepsi **Boş**. (Balıklar ses çıkarmaz.)

## 3b. Müzik (`MUSIC`)

Tek döngü yuvası: `main` (boş = müzik yok). Kimliği `Config/Audio.luau` içindeki `MUSIC.main.id` alanına `"rbxassetid://NUMARA"` olarak yaz; `Effects/Soundscape` açılışta döngüyle çalar, düzeyini Ayarlar'daki "Müzik" sürgüsü belirler. Önerilen: sakin, döngüye uygun, 1-3 dk'lık çiftlik müziği.

## 4. Şu an sesi olmayan ama eklenebilecek yerler

Yuvası henüz yok; istersen söyle, yuva + bağlantıyı eklerim.

- Adımlar / koşu (karakter yürürken), su içine düşme/yüzme çıkışı (`Effects/Underwater` yalnızca görsel + yuva yok).
- Para toplama platformuna ilk değme (toplama sesi yalnızca para geldiğinde çalar).
- Altın hayvanı yakalama, gezgin tüccardan alım.
- Sipariş panosu tarafında kart seçimi (tıklama sesi dışında).
- Yeni günün/sabahın başlaması, gece başlangıcı.
- Hayvan doğumu/büyümesi (yavru → genç → yetişkin geçişi).
- Yükleme ekranı (ReplicatedFirst).
- Dünyadaki prompt'lar (E basınca): pazar, satıcılar, ahır sandığı.

## 5. Yeni yuva ekleme

1. `Audio.luau` → `SOUNDS` içine `yuva = { id = "", volume = 0.4 }` ekle.
2. Olayın olduğu yerde `Sfx.play("yuva")` çağır (istemcide; bkz. `Core/Sfx`). Durum farkından anlaşılan olaylar `Interaction/EventSounds`'ta toplanır.
3. Bu tabloya satır ekle.
