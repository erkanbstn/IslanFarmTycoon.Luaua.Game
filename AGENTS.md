# AI Asistanları İçin Proje Rehberi

Roblox tycoon oyunu, Luau ve Rojo kullanır. Kodun kaynağı bu depodur. `CLAUDE.md`, `.cursorrules` ve `.github/copilot-instructions.md` bu dosyaya yönlendirir.

## Başlangıç ve devir

Yeni oturumda önce bu dosyayı ve `docs/AI_DEVIR_REHBERI.md` dosyasını oku. Rehber, çalışma ağacını koruma, araç teşhisi, başlangıç doğrulaması ve sonuç devrini anlatır. Ardından yalnızca görevine uygun aşağıdaki kuralları ve skill'i aç. Tüm belgeleri her görevde baştan okuma.

- Mimari ve yeni dosyanın yeri: `docs/MIMARI.md`.
- Güncel davranış: ilgili kaynak + tüketicisi + testi. Eski analiz/ilerleme raporları tarihsel kanıttır; mevcut kod yerine geçmez.
- Kuralların tek kaynağı `.cursor/rules/`, iş akışlarının tek kaynağı `.cursor/skills/`; `.claude/skills/` yönlendirmedir.
- Kurallar değişirse ilgili kaynak rehberi güncelle. Tutarlılık: `python scripts/check-ai-docs.py`. Hızlı başlangıç: `python scripts/triage.py` (durum, kural, skill, en küçük kontrol); görev→komut: `docs/HIZLI_AKSIYON.md`.

## Tek kaynak haritası

Bütün AI araçları aynı yerden okur: kurallar `.cursor/rules/*.mdc`, iş akışları `.cursor/skills/<ad>/SKILL.md`. `.claude/skills/` Claude Code'un skill'leri bulması için yalnızca yönlendirir; `CLAUDE.md`, `.cursorrules` ve `.github/copilot-instructions.md` bu dosyaya (ve oradan bu kaynaklara) yönlendirir. Başka yerde kural/skill kaynağı açma; `check-ai-docs.py` yetim kaynağı ve yönlendirme sapmasını yakalar.

## Hızlı kontrol komutları (tek yer)

Önce `triage`, sonra en küçük yeterli kontrol; tam liste ve görev tarifleri `docs/HIZLI_AKSIYON.md`.

| Ne zaman | Komut | Süre |
|---|---|---|
| Oturum başı: durum, ilgili kural/skill, çalıştırılacak en küçük komutlar | `python scripts/triage.py` (`--run` ucuz olanları çalıştırır, `--json` makine çıktısı) | saniyeler |
| Araç/ortam teşhisi (salt okunur) | `python scripts/doctor.py` | saniyeler |
| Tek spec / saf Luau alt kümesi | `python scripts/smoke-quick.py --only <ad>` (`run-tests.py --list` adları gösterir) | <1 sn |
| Silme, yeniden adlandırma, yeni belge/betik sonrası: ölü yol, yetim dosya, ölü fonksiyon/Remote/çeviri | `python scripts/check-repo-hygiene.py` | saniyeler |
| Rehber/kural/skill tutarlılığı | `python scripts/check-ai-docs.py` | saniyeler |
| Her değişiklikten sonra (biçim, lint, derleme, saf testler, çeviri, mimari, tip) | `powershell -ExecutionPolicy Bypass -File scripts/verify-fast.ps1 -RequireTypes` | ~10 sn |
| Yayın/merge öncesi (simülasyon, model kapsamı, Rojo derlemeleri) | `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Mode Full -RequireTypes` | dakikalar |
| Model sözleşmesi / yeni model | `python scripts/check-assets.py` | saniyeler |

Fast geçmesi Full veya Studio kanıtı değildir.

## Dokunduğun yere göre okunacak kural dosyası

Cursor globları otomatik yükler; diğer araçlar ilgili satırı değişiklikten önce bir kez okur.

| Dokunduğun yer | Oku |
|---|---|
| Herhangi bir `.luau` | `.cursor/rules/luau-style.mdc` |
| `src/server/**` | `.cursor/rules/server-security.mdc` |
| `src/client/**`, UiTheme, WorldUi, `src/first/**` | `.cursor/rules/client-ui.mdc` |
| Oyuncuya görünen metin | `.cursor/rules/localization.mdc` |
| World, Presentation, plugin, Effects görselleri | `.cursor/rules/world-map.mdc` |
| Config, FarmMath, GameTypes, SaveCodec, kayıt ve ekonomi servisleri | `.cursor/rules/economy-data.mdc` |
| İstemci efekt/görsel LocalScript'leri | `.cursor/rules/client-performance.mdc` |
| tests, scripts, mimari belgesi ve araç/proje ayarları | `.cursor/rules/tests-tooling.mdc` |

## İş akışı skill'leri

Tam metin `.cursor/skills/<ad>/SKILL.md` içindedir; `.claude/skills/` yalnızca yönlendirir:

- `roblox-add-remote`: istemci/sunucu işlem sözleşmesi.
- `roblox-add-ui`: ekran, pencere, HUD ve menü değişikliği.
- `roblox-add-content`: içerik, fiyat ve denge değişikliği.
- `roblox-map-change`: kayıtlı harita, modeller ve ışık yerleşimi.
- `roblox-localize`: Türkçe kaynak metin ve beş dil sözlüğü.
- `roblox-save-schema`: kalıcı kayıt ve finansal veri.
- `roblox-verify`: hızlı/tam doğrulama ve Studio sınırları.

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
- Ekran bileşenleri UiKit, dünya yazıları WorldUi; tema tek kaynak UiTheme'dir. Yerleşim ve mobil hedefler client-ui kuralında tanımlıdır.
- Metin kaynağı Türkçe; Localizer en/de/ru/es/pt sözlüklerini uygular. Yeni oyuncu metni beş dilde tamamlanır.

## Çalışma sınırları

Kullanıcının mevcut değişikliklerini koru. Yeni dal/commit/push/yayın için oturumdaki yetkiyi esas al; rutin bir düzeltme bunları kendiliğinden yetkilendirmez. Canlı veri sıfırlama, veri silme veya geri alınamaz kayıt dönüşümü öncesinde açık onay gerekir. Test amacıyla gerçek yönetici sıfırlamasını çalıştırma.

Doğrulama komutlarının, Studio akışının ve ölçüm karşılaştırmasının güncel tek kaynağı `.cursor/skills/roblox-verify/SKILL.md` ve `scripts/verify.ps1`'dir. Çalıştırılan kontrolleri, atlananları ve kalan gerçek belirsizlikleri sonuçta yaz.
