---
name: roblox-verify
description: Runs this Roblox project's automated checks (StyLua, Selene, Luau compile, pure Luau regression tests, locale coverage, Rojo builds) and lists the manual Studio checks that remain. Use after code changes, before committing, or when the user asks to test, lint, format or verify the project.
---

# Doğrulama ve devir

Yeni oturumdaki kapsam/çalışma ağacı kontrolü `docs/AI_DEVIR_REHBERI.md` içindedir. Kontroller kaynakları biçimlendirmez; gereken StyLua düzeltmesini yalnız değiştirdiğin dosyalara uygula.

## Araç teşhisi ve hızlı döngü

En hızlı başlangıç: `python scripts/triage.py` değişen dosyalardan en küçük hedefli kontrolleri önerir (`--run` ucuzlarını çalıştırır); `python scripts/smoke-quick.py [--only ad]` saf Luau spec alt kümesini saniyeler içinde koşar (alt küme tam paket değildir). Görev bazlı komutlar `docs/HIZLI_AKSIYON.md`.

```
python scripts/doctor.py
powershell -ExecutionPolicy Bypass -File scripts/verify-fast.ps1
```

Hızlı wrapper, `scripts/verify.ps1 -Mode Fast` çağırır. Adımların güncel listesi ve parametreleri `verify.ps1`'dedir; test bağımlılığı, gerçek Luau regresyonu, lint/derleme, mimari/rehber/çeviri kontrolleri aynı kaynaktan çalışır. Fast uzun ekonomi kampanyası ve bütün Rojo derlemelerinin yerine geçmez.

Silme/yeniden adlandırma veya yeni belge/betik sonrası ucuz salt okunur hijyen kontrolü (ölü yol ve bağlantı, yetim belge/betik/modül, izlenen çöp):

```
python scripts/check-repo-hygiene.py
```

Fast/Full bunu zaten çalıştırır; bulguyu referansı düzelterek, belgeyi `docs/AI_DEVIR_REHBERI.md` dizinine ekleyerek ya da gerçekten yetim dosyayı silerek çöz.

Yeni `require` veya spec kaydı için, testleri çalıştırmadan önce ucuz salt okunur kontrol:

```
python scripts/check-test-dependencies.py
```

Aynı kontrol `run-tests.py --check-dependencies` ile de çağrılabilir. Gerçek kaynaktaki bağımlılık seti, paket parça listesi ve tanım sırası runner ile eşleşmelidir; geçmeyen test için beklenti azaltılmaz.

## Tam regresyon

```
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Mode Full -RequireTypes
```

Full varsayılandır. Uzun simülasyonlar, model/tip/rehber denetimi ve oyun/eklenti/test derlemeleri dahildir; kesin adımları betikten oku. `-RequireTypes` eksik luau-lsp'yi başarısız sayar. Doctor eksik araçları gösterir; Rojo/StyLua/Selene pinleri `rokit.toml`, Luau dizini `.tools/luau`, LSP `.tools/luau-lsp`. Farklı Luau için `-LuauDirectory` kullanılabilir. Araç kurulumu gerekiyorsa ilgili teşhis çıktısındaki yolu kullan; kontrol başarı vermiş gibi atlama.

## Ekonomi karşılaştırması

Denge değişikliğinden önce uygun persona/çiftlik/rebirth senaryosunu seç. Örnek, HEAD'deki aynı senaryoyu çalışan ağaçla karşılaştırır; görev başlangıcı başka ref ise o doğrulanmış SHA/ref'i ver:

```
python scripts/compare-economy.py run --baseline-ref HEAD --repeats 2 --output-dir .test-build/economy-comparison -- --persona hardcore --session 0 --hours 6 --farm 1
```

Baseline SHA'ya sabitlenir ve geçici git archive ile çalıştırılır; checkout yapılmaz, kullanıcı değişiklikleri korunur. Aynı Luau/Python, simülasyon argümanları ve JSON settings karşılaştırılır. Önceden kaydedilmiş sonuçlar:

```
python scripts/compare-economy.py compare --before .test-build/before.json --after .test-build/after.json --output-dir .test-build/economy-comparison
```

Çıktı `report.md`/`report.json`; run modunda before/after tekrar JSON'ları da saklanır. Eksik metrik bilinmeyendir, sıfır sayılmaz. Metadata bulunmayan eski çıktılar sınırlı kanıttır; persona/ayar uyumsuzluğu başarı olarak sunulmaz. Süre, para, ürün, tamamlanma farkını aynı koşullarda raporla; sim oyuncu davranışı/FPS profilinin yerini tutmaz.

## İzole Studio kontrolü

```
python scripts/studio-qa.py build --output .test-build/studio-qa.rbxlx
python scripts/studio-qa.py command --scenario production --user-id 123 --request-id 1
python scripts/studio-qa.py inspect --side server
python scripts/studio-qa.py inspect --side client
```

123 yerine test oyuncusunun gerçek UserId'sini kullan. Build, tam oyunu QA runner/fixtures ile ayrı place'e paketler. Normal `default.project.json` QA runner içermez. Dosyayı Studio'da aç, Play başlat, command çıktısını **server** MCP bağlamında çalıştır; inspect çıktısıyla whitelist durum/sonuç alanlarını oku. Bu araç MCP içinde modül require etmez, yeni production Remote/API açmaz. Senaryolar `fresh`, `production`, `merchant`, `rebirth-ready`; kesin CLI ve izolasyon sözleşmesini `studio-qa.py --help` ile doğrula.

QA place yayınlanmaz; canlı yer/kayıt üzerinde fixture çalıştırılmaz. Ayrı test place sonucu, canlı place'in harita kaydını yenilemez. Play durdurulduğunda geçici fixture oturumu biter.

## Studio'da kalan kanıt

- `test.project.json` dünya testleri ve harita eklentisi `MapToolRun=buildverify`: sözleşme/yapı doğrulaması; statik harita değiştiyse kurulum + place kaydı gerekir. Plugin değiştiyse eklenti yeniden derlenir ve Studio yeniden açılır (`tests-tooling.mdc`).
- Telefon/masaüstü, uzun çeviri, gamepad ve gece ışıklarının gerçek görsel kontrolü; QA inspect veya saf UI mock'u render doğrulaması sayılmaz.
- İki oyuncu, streaming, uzun kullanım ve MicroProfiler gerekiyorsa aynı senaryoda ölç. Gerçek makbuz/reconnect, canlı DataStore ve ağ hatası, izole nonpersistent QA'da kanıtlanmış değildir.

Sonuçta komut, kapsam, başarı/hata/atlama ve artifact yolunu yaz. Kalan engel için somut sonraki adımı belirt; Full veya Studio koşulmadıysa bunu açıkça söyle.
