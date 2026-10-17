# Island Farm Tycoon — Claude rehberi

Roblox tycoon oyunu, Luau ve Rojo kullanır. Kodun kaynağı bu depodur. Bu dosya Claude Code'un tek giriş noktasıdır; başka ajan/IDE rehberi tutulmaz.

## Başlangıç ve devir

Yeni oturumda önce bu dosyayı ve `docs/AI_DEVIR_REHBERI.md` dosyasını oku (çalışma ağacını koruma, araç teşhisi, başlangıç doğrulaması, sonuç devri). Oturumu `python scripts/triage.py` ile başlat: durumu, ilgili kuralı/skill'i ve çalıştırılacak en küçük komutları verir (`--run` ucuzlarını çalıştırır, `--json` makine çıktısı). Tüm belgeleri her görevde baştan okuma.

- Mimari ve yeni dosyanın yeri: `docs/MIMARI.md`. Görev→komut tarifleri: `docs/HIZLI_AKSIYON.md`. Güncel durum: `docs/DEVIR_DURUMU.md`.
- Güncel davranış: ilgili kaynak + tüketicisi + testi. Eski analiz/ilerleme raporları tarihsel kanıttır; mevcut kod yerine geçmez.
- Önce hedef kaynak, tüketici ve testini izle; geniş inceleme istenirse kapsamı aşamalara ayır. Studio'da gerçekten çalıştırılan ve bekleyen kontrolleri ayır.

## Nerede ne var (başka projeye taşırken)

| Ne | Yer |
|---|---|
| Giriş rehberi | `CLAUDE.md` (bu dosya) |
| Kurallar (dosyaya dokununca otomatik yüklenir) | `.claude/rules/*.md` |
| İş akışı skill'leri | `.claude/skills/<ad>/SKILL.md` |
| Betikler (doğrulama, simülasyon, triage, hijyen) | `scripts/` (giriş: `python scripts/triage.py`, `scripts/doctor.py`) |
| Testler | `tests/` (harness `scripts/run-tests.py`) |
| Belgeler (mimari, devir, denge, hızlı tarifler) | `docs/` |

Taşınan projede `CLAUDE.md`, `.claude/`, `scripts/` ve `docs/` birlikte alınır; başka konuma kural/skill/betik kaynağı açılmaz.

## Kurallar ve skill'ler (tek kaynak: `.claude/`)

- **Kurallar** `.claude/rules/*.md`; her dosyanın `paths:` listesi var, Claude eşleşen dosyaya dokununca kuralı kendisi yükler (elle açmak gerekmez, gerekirse oku). Değişince `python scripts/check-ai-docs.py` ile tutarlılığı denetle.

| Kural | Dokunduğun yer |
|---|---|
| `.claude/rules/luau-style.md` | her `.luau` |
| `.claude/rules/server-security.md` | `src/server/**` |
| `.claude/rules/client-ui.md` | `src/client/**`, UiTheme, WorldUi, `src/first/**` |
| `.claude/rules/localization.md` | oyuncuya görünen metin |
| `.claude/rules/world-map.md` | World, Presentation, plugin, Effects görselleri |
| `.claude/rules/economy-data.md` | Config, FarmMath, GameTypes, SaveCodec, kayıt ve ekonomi servisleri |
| `.claude/rules/client-performance.md` | istemci efekt/görsel LocalScript'leri |
| `.claude/rules/tests-tooling.md` | tests, scripts, mimari belgesi, araç/proje ayarları |

- **Skill'ler** `.claude/skills/<ad>/SKILL.md` (tam metin burada; başka kopya yok):
  - `roblox-add-remote`: istemci/sunucu işlem sözleşmesi.
  - `roblox-add-ui`: ekran, pencere, HUD ve menü değişikliği.
  - `roblox-add-content`: içerik, fiyat ve denge değişikliği.
  - `roblox-map-change`: kayıtlı harita, modeller ve ışık yerleşimi.
  - `roblox-localize`: Türkçe kaynak metin ve beş dil sözlüğü.
  - `roblox-save-schema`: kalıcı kayıt ve finansal veri.
  - `roblox-verify`: hızlı/tam doğrulama ve Studio sınırları.
- Kural/skill başka yerde (`.cursor`, `.github`, `AGENTS.md`...) açılmaz; `check-ai-docs.py` sapmayı yakalar.

## Hızlı kontrol komutları (tek yer)

Önce `triage`, sonra en küçük yeterli kontrol; tam liste `docs/HIZLI_AKSIYON.md`.

| Ne zaman | Komut | Süre |
|---|---|---|
| Oturum başı: durum, ilgili kural/skill, en küçük komutlar | `python scripts/triage.py` (`--run`, `--json`) | saniyeler |
| Araç/ortam teşhisi (salt okunur) | `python scripts/doctor.py` | saniyeler |
| Tek spec / saf Luau alt kümesi | `python scripts/smoke-quick.py --only <ad>` (`run-tests.py --list` adları gösterir) | <1 sn |
| Silme, yeniden adlandırma, yeni belge/betik sonrası: ölü yol, yetim dosya, ölü fonksiyon/Remote/çeviri | `python scripts/check-repo-hygiene.py` | saniyeler |
| Kural/skill/rehber tutarlılığı | `python scripts/check-ai-docs.py` | saniyeler |
| Her değişiklikten sonra (biçim, lint, derleme, saf testler, çeviri, mimari, tip) | `powershell -ExecutionPolicy Bypass -File scripts/verify-fast.ps1 -RequireTypes` | ~10 sn |
| Yayın/merge öncesi (simülasyon, model kapsamı, Rojo derlemeleri) | `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Mode Full -RequireTypes` | dakikalar |
| Model sözleşmesi / yeni model | `python scripts/check-assets.py` | saniyeler |

Fast geçmesi Full veya Studio kanıtı değildir. Doğrulama akışının güncel tek kaynağı `.claude/skills/roblox-verify/SKILL.md` ve `scripts/verify.ps1`'dir; araç komutlarını başka yerde çoğaltma.

## Mimari ve değişmezler

| Depo | Roblox konumu | Çalıştığı yer |
|---|---|---|
| `src/server` | ServerScriptService.Server | Sunucu |
| `src/client` | StarterPlayer.StarterPlayerScripts.Client | İstemci |
| `src/shared` | ReplicatedStorage.Shared | İkisi |
| `src/first` | ReplicatedFirst | İlk istemci yüklemesi |

- Sunucu bağımlılığı: Modules → World → Presentation → Services. İstemci: Core → Effects → Ui → Interaction. Shared sunucu/istemciye bağlanmaz; `python scripts/check-architecture.py` denetler.
- Luau dosyaları `--!strict`; tipler, tab girintisi ve StyLua kullanır. Script türünü Rojo belirler: `.server.luau`, `.client.luau`, `.luau`.
- Para, sahiplik, kayıt ve Remote kararları sunucuda doğrulanır; fiyat/hesap Config/FarmMath'ten gelir. DataStore'a yalnız SaveStore dokunur. Gizli bilgi Shared'a konmaz.
- Görünen dünya geometrisi `assets/` veya `client-assets/` modellerinden gelir. Model sözleşmesi `docs/MODEL_SOZLESMESI.md`; yeni model kapsamı `python scripts/check-assets.py`. Model ajanı işi için `docs/GPT_MODEL_IS_LISTESI.md` ilgili bölümü oku.
- Ekran bileşenleri UiKit, dünya yazıları WorldUi; tema tek kaynak UiTheme'dir. Yerleşim ve mobil hedefler `client-ui` kuralında tanımlıdır.
- Metin kaynağı Türkçe; Localizer en/de/ru/es/pt sözlüklerini uygular. Yeni oyuncu metni beş dilde tamamlanır.

## Çalışma sınırları

Kullanıcının mevcut değişikliklerini koru. Yeni dal/commit/push/yayın için oturumdaki yetkiyi esas al; rutin bir düzeltme bunları kendiliğinden yetkilendirmez. Canlı veri sıfırlama, veri silme veya geri alınamaz kayıt dönüşümü öncesinde açık onay gerekir. Test amacıyla gerçek yönetici sıfırlamasını çalıştırma. Çalıştırılan kontrolleri, atlananları ve kalan gerçek belirsizlikleri sonuçta yaz; nihai raporlar kısa Türkçe olur.
