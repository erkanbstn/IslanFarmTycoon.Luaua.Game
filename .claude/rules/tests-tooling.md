---
description: Test yazma, test harness ve doğrulama komutları
paths:
  - "tests/**"
  - "scripts/**"
  - "*.project.json"
  - "selene.toml"
  - "stylua.toml"
  - "rokit.toml"
---

# Testler ve araçlar

## Saf Luau testleri (`python scripts/run-tests.py`)
- Gerçek kaynağı birleştirip `.tools/luau` ile koşar (Luau sürümü `scripts/verify.ps1`'de sabittir). Yalnızca `local X = require(...)` deyimlerini (çok satırlı olsa da) değiştirir;
  başka biçimde `require` hata verir. Her modülün `dependencies` kümesi koddaki require'larla **tam eşleşmeli**, yoksa "Unexpected dependency / Dependency mismatch".
- Klasör olan modüller parça listeleriyle birleştirilir: `CONFIG_PARTS`, `FARM_MATH_PARTS`, `SAVE_CODEC_PARTS` (`run-tests.py`). Bu klasörlere dosya ekler/çıkarır/yeniden adlandırırsan
  ilgili listeyi (sıra bağımlılığı izler) güncelle.
- Sim ve çeviri denetimi: `scripts/simulate-tiers.py --personas ideal,casual,idle --assert-monotonic` (çiftlik süresi tema 1 -> 6 her personada artar; `--order` en kötü alım sırası) ve
  `scripts/check-config-locales.py` (Config metinleri her dilde tam çevrili; yeni içerikte atomları sözlüğe ekle, birleşik cümleler şablonla çevrilir) `verify.ps1` içindedir.
- Yeni spec: `tests/<ad>.spec.luau` bir fonksiyon döndürür → `run-tests.py` içinde `module(...)` ile ekle ve `main()` sonundaki çağrı listesine yaz. Roblox servisleri gerekiyorsa
  `factory_args` ile sahte (`game`, `task`, `os`...) enjekte edilir.
- Servis testleri (Animal/Upgrade/Inventory/Engagement/Monetization/BuyPad/Contract...): `tests/service-harness.luau` ortak sahte dünyayı kurar (oyuncu + kayıt, Remote'lar, saat,
  `task.spawn` döngüsünü tek tur çalıştırma, sayaçlar, gerçek `RequestGuard`). Yeni servis spec'i sahip / parası yok / tekrar istek / yanlış çiftlik / hız sınırı durumlarını bununla yazar.
- Testi geçirmek için beklentiyi gevşetme; davranış bilinçli değiştiyse testi güncelle ve nedenini değişiklik raporunda yaz.

## Studio (dünya) testleri
- `tests/map-structure.spec.luau` ve `tests/world.spec.luau` Studio eklentisine gömülüdür (`plugin.project.json`); panelde **Haritayı Doğrula** çalıştırır (`MapBuilder.validate` + iki spec).
  Spec `return function(context)` kalıbında kalmalı (`context.mapBuilder/Config` eklentiden taze gelir). Yeni tabela/satıcı/tema kuralı bunu genişletir. Harita sürümünü sabit sayıyla değil `validate()` ile kontrol et.
- Spec dosyaları Rojo ile `ServerStorage.MapSpecs` altına da senkronlanır; eklenti varsa o güncel kopyayı (klonlayıp) çalıştırır, yani testi değiştirince eklentiyi yeniden üretmek gerekmez. Eklenti (`plugin/`) değişirse `rojo build plugin.project.json --plugin IslandFarmTycoonHarita.rbxm` + Studio'yu yeniden aç (eklenti yalnızca açılışta yüklenir).
- Geliştirme otomasyonu: eklenti `ServerStorage` özniteliği `MapToolRun`'ı dinler (`build` | `verify` | `buildverify`); Studio MCP `execute_luau` (Edit) ile `game:GetService("ServerStorage"):SetAttribute("MapToolRun","buildverify")` yazınca panel düğmeleriyle aynı kod çalışır, sonuç Output'ta (`get_console_output`) okunur. MCP oturumu modülleri `require` edemez (Capabilities), bu yüzden eklenti yolu kullanılır. Kaydetme (Ctrl+S) kullanıcıda kalır.
- Plot ile şablonu karşılaştıran sayımlar tohum farkına karşı toleranslıdır; yeni tohumlu süs sayımı oynatıyorsa `compareThemes` muafiyetine ekle, testi gevşetme.
- `test.project.json` ayrı dünya testi place'idir; `tests/run.server.luau` çalıştırır. Tam oyun fixture senaryoları için `scripts/studio-qa.py` ayrı nonpersistent QA place üretir; `roblox-verify` izolasyon akışını kullan. Üretim projesine QA runner eklenmez.

## Doğrulama komutları
- Oturum başı ve "ne çalıştırmalıyım": `python scripts/triage.py` (değişen dosyalara göre kural/skill/en küçük komutlar; `--run`, `--json`); tek spec için `python scripts/smoke-quick.py --only <ad>` (`run-tests.py --only/--list`); görev→komut tarifleri `docs/HIZLI_AKSIYON.md`; tek tablo `CLAUDE.md` "Hızlı kontrol komutları".
- Yeni oturum araç teşhisi: `python scripts/doctor.py` (salt okunur).
- Hızlı döngü: `powershell -ExecutionPolicy Bypass -File scripts/verify-fast.ps1` (`verify.ps1 -Mode Fast`); tam regresyon `verify.ps1 -Mode Full -RequireTypes`. Güncel adımlar `scripts/verify.ps1`, örnekler `roblox-verify` skill'indedir.
- Test bağımlılığı/sırası: `python scripts/check-test-dependencies.py`; test çalıştırmaz ve çıktı dosyası üretmez. `run-tests.py --check-dependencies` aynı kontrolü çağırır.
- Ekonomi önce/sonra ve izole Studio QA akışı `roblox-verify` içindedir; Fast geçmesi Full/Studio kanıtı değildir.
- `python scripts/check-repo-hygiene.py`: depo genelinde ölü yol/bağlantı, yetim `docs/` belgesi, yetim `scripts/` betiği, adı hiçbir yerde geçmeyen `src/` modülü, izlenen log/önbellek/derleme çıktısı, 400 satırı aşan belge `DEVIR_DURUMU.md` içindeki olmayan commit, yalnızca tanımlı (çağrılmayan) `function Mod.ad`, yorum satırına alınmış kod, istemci ya da sunucuda hiç geçmeyen Remote olayı ve kodda karşılığı kalmamış (5 dilde ortak) çeviri anahtarı. Çeviri anahtarı kelimeleri Config atomlarını da kapsar (kodda alt dize olarak geçmesi yeter); bilinçli kullanılmayan bir fonksiyon/anahtar için silmek yerine kullan ya da kaldır. Bir şeyi silince/yeniden adlandırınca burası kırılırsa referansı güncelle; belge yetimse `AI_DEVIR_REHBERI.md` dizinine ekle; tarihsel anıyı "git geçmişi/arşiv" ifadesiyle işaretle. Testi `tests/tooling.spec.py`.
- Elle çalıştırılan yardımcılar (verify'a bağlı değil): `scripts/benchmark-season-glow.py` (mevsim ışıması döngüsü mikro ölçümü, Studio FPS değildir), `scripts/render-island-trailer.py` (tanıtım videosu üretimi; Pillow/NumPy/imageio-ffmpeg `.tools/video-runtime`).
- `python scripts/check-ai-docs.py`: kural/skill/giriş dosyası tutarlılığı (`paths:` frontmatter, glob eşleşmesi, CLAUDE.md tablosu ve skill listesi, skill'in yönlendirme taslağı olmaması, `.cursor`/`.mdc`/`AGENTS.md` gibi ikinci kaynak kalıntısı yok, metindeki repo yolları gerçekten var mı).
- `python scripts/check-assets.py`: kodun beklediği her hayvan/bina/bölge/eklenti/seviye görünümü için `assets/` modeli var mı, XML sağlıklı mı (ad, yasak sınıf, PrimaryPart, bina ≤35 parça). Bilinçli boşluklar betikteki `ALLOWED_MISSING`'e gerekçesiyle girer. Yeni görünüm (hayvan/bina/bölge/süs) eklerken beklenen listeyi (`expected()`) ve XML'i birlikte güncelle; eksik model görünümü çizilmez (yedek kod kurucusu yoktur), `verify.ps1` kırmızı olur. `UNWIRED_FOLDERS` koda bağlanmamış model klasörlerini bildirir.
- `python scripts/check-architecture.py`: katmanlar yalnızca izinli katmanlara `require` eder (`docs/MIMARI.md`); bilinçli istisna gerekçesiyle `ALLOW` listesine girer.
- `python scripts/check-locales.py --strict-literals`: çeviri anahtarı eşitliği ve arayüz metni kapsamı.

## Tip analizi (`python scripts/check-types.py`)
- luau-lsp analyze + Roblox tip tanımları + rojo sourcemap. Araçlar `.tools/luau-lsp` altındadır (git'e girmez; `powershell scripts/setup-types.ps1` indirir). Yoksa komut atlar, `verify.ps1` görünür uyarı basar.
- Bilinen bulgular `scripts/types-baseline.json` tabanındadır; yalnızca **yeni ya da artan** bulgu hatadır. Taban yalnızca küçülür: bulgu düzeldiyse `python scripts/check-types.py --update`;
  yeni bulguyu tabana ekleme, düzelt. Yeni bulguyu önce gerçek hata diye incele (ör. `local T = { f = function() T.x() end }` içinde `T` yerel değildir → çalışma anında nil).
