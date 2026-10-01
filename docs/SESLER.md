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
| `click` | Her buton tıklaması | `Ui/Kit/Controls` (tüm düğmeler, menü karoları, slider) | Var (yüklendi) | Kısa, yumuşak "tık" (çok kısık, sık çalar) |
| `coin` | Para platformundan para toplama | `Ui/FarmHud` (Notify "money") | Var (yüklendi) | Kısa, tok bozuk para; **tok ve kısık** (sık çalar) |
| `success` | Satın alma/işlem başarılı | `Core/PurchaseController`, `Ui/IslandManager` | Var (yüklendi) | Olumlu kısa "ding" |
| `error` | Reddedilen işlem / hata bildirimi | `Core/PurchaseController`, `Ui/FarmHud`, `IslandManager` | Var (yüklendi) | Alçak, nazik "bzzt" |
| `build` | Yeni bina/yükseltme belirirken | `Effects/BuildEffects` | Var (yüklendi) | İnşaat/çekiç + kısa zafer |
| `ui_open` | Pencere açılır | `Ui/Kit/Windows` (tüm pencereler) | Var (yüklendi) | Hafif kayma/"whoosh" |
| `ui_close` | Pencere kapanır | `Ui/Kit/Windows` | Var (yüklendi) | `ui_open`'ın tersi |
| `notify` | Bilgi bildirimi (mavi toast) | `Ui/FarmHud` (Notify "info") | Var (yüklendi) | Yumuşak zil |
| `animal_buy` | Hayvan satın alındı | `Interaction/EventSounds` (hayvan sayısı arttı) | Var (yüklendi) | Kısa hayvan "hoop"/pop |
| `animal_sell` | Hayvan satıldı | `EventSounds` (hayvan sayısı azaldı) | Var (yüklendi) | Nötr kısa "pat" |
| `upgrade_buy` | Yükseltme alındı | `EventSounds` (alınan yükseltme arttı) | Var (yüklendi) | Tatmin edici "ka-ching" + yükseliş |
| `expansion_buy` | Bölge/tesis geliştirme seviyesi | `EventSounds` (geliştirme toplamı arttı) | Var (yüklendi) | Çekiç + parlayan "çın" |
| `barn_level` | Ahır seviyesi arttı | `EventSounds` | Var (yüklendi) | Büyük kutlama (kısa fanfar) |
| `production_start` | Üretim partisi başladı | `EventSounds` (yeni iş) | Var (yüklendi) | Makine çalışma / düğme basma |
| `production_ready` | Parti hazır oldu | `EventSounds` (süre doldu) | Var (yüklendi) | Fırın "ding" / tamamlanma zili |
| `production_claim` | Parti teslim alındı | `EventSounds` (iş kalktı) | Var (yüklendi) | Kasa/çuval teslim sesi |
| `contract_done` | Ahır siparişi teslim edildi | `EventSounds` (teslim sayacı arttı) | Var (yüklendi) | Ticaret "onay" + bozuk para |
| `achievement` | Başarım ödülü alındı | `EventSounds` (başarım sayısı arttı) | Var (yüklendi) | Ödül fanfarı (kısa, parlak) |
| `daily_claim` | Günlük ödül alındı | `EventSounds` (günlük gün değişti) | Var (yüklendi) | Hediye açma |
| `item_buy` | Eşya satın alındı | `EventSounds` (eşya sayısı arttı) | Var (yüklendi) | Dükkân zili |
| `item_equip` | Eşya takıldı/çıkarıldı | `EventSounds` (takılı değişti) | Var (yüklendi) | Kumaş/metal "tık" |
| `season_change` | Mevsim değişti | `EventSounds` (sunucu saatinden) | Var (yüklendi) | Yumuşak mevsim geçişi |
| `golden_spawn` | Altın hayvan belirdi | `Ui/FarmHud` (merchantNotice) | Var (yüklendi) | Parıltı/"şıngırtı" |
| `merchant_arrive` | Gezgin tüccar geldi | `Ui/FarmHud` (merchantNotice) | Var (yüklendi) | Bisiklet/çan, yolculuk sesi |

## 2. Ortam döngüleri (`AMBIENCE`)

Sürekli (döngü) çalan, mevsim/hava/gece durumuna göre açılıp kısılan katmanlar. Boş kimlik = o katman yok. Kod: `Effects/Soundscape`.

| Yuva | Ne zaman | Durum | Önerilen ses |
|---|---|---|---|
| `birds` | İlkbahar/yaz gündüz | Var (yüklendi) | Kuş cıvıltısı (döngü) |
| `wind` | Sonbahar/kış | Var (yüklendi) | Rüzgâr (döngü) |
| `rain` | Yağmur | Var (yüklendi) | Yağmur (döngü) |
| `storm` | Fırtına | Var (yüklendi) | Gök gürültüsü + yağmur |
| `night` | Gece | Var (yüklendi) | Cırcır böceği (döngü) |

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

## 6. Ses üretme (dosya kuralları ve istek örnekleri)

Genel kurallar: mono ya da stereo `.wav`/`.mp3`, en fazla 7 dakika (Roblox sınırı); kısa efektler 0,2-1,5 sn,
döngüler 20-40 sn ve başı-sonu dikişsiz. Sessizlikle başlayıp bitmesin (kırpılmış olsun). Ortam döngülerini
ayrı ayrı yükle, oyun katmanları karıştırır.

| Yuva | İstek (prompt) örneği | Süre |
|---|---|---|
| `click` | "soft wooden UI click, cozy farm game, dry" | 0,1-0,2 sn |
| `coin` | "bright coin pickup chime, cartoon, sparkly, short" | 0,4-0,7 sn |
| `success` | "cheerful two-note success chime, warm, cartoon" | 0,6-1 sn |
| `error` | "soft low error blip, gentle, not harsh" | 0,3-0,5 sn |
| `build` | "construction pop with wood and sparkles, triumphant short jingle" | 1-1,5 sn |
| `birds` | "peaceful spring meadow ambience, gentle birdsong, soft breeze, seamless loop" | döngü |
| `wind` | "cold autumn wind over open field, soft, slow gusts, seamless loop" | döngü |
| `rain` | "steady light rain on grass and wood roofs, calm, seamless loop" | döngü |
| `storm` | "heavy rain with distant rolling thunder, wind, seamless loop" | döngü |
| `night` | "summer night crickets and soft frogs, quiet countryside, seamless loop" | döngü |
| `MUSIC.main` | "relaxing acoustic farm tycoon background music, light guitar and strings, warm, loopable, 90 BPM" | 1-2 dk döngü |

Hayvanlar (0,6-1,5 sn, yumuşak ve sevimli): cow (yumuşak böğürme), chicken (kısa gıdaklama), horse (kısa kişneme), goat (melemek),
duck (vak vak), sheep (mee), pig (hafif homurtu). Kalıp: "friendly cartoon {hayvan} sound, gentle, short, no background".

Su altı için yuva henüz yok (bkz. 4); eklenirse: `splash` "small water splash, soft, cartoon, short", `bubbles` "underwater bubbles rising,
calm, short loop", `underwaterAmbience` "muffled deep underwater ambience, soft hum, seamless loop".
