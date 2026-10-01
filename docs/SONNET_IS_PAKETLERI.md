# Sonnet 5.5 iş paketleri (yapılmamış kalanlar)

Kaynak: `docs/ANALIZ_RAPORU.md` ve güncel durum için `docs/DURUM_RAPORU.md`. Yapılan paketler (P0-P8, P10, P11, P3) çıkarıldı; tarihçeleri git geçmişinde.
Her paket **yeni bir Sonnet 5.5 oturumunda** çalıştırılır; prompt kod bloğundadır. Push etmek kullanıcının kararıdır.

| # | Paket | Opus incelemesi | Senden gereken |
|---|---|---|---|
| P9 | CI (GitHub Actions) | hayır | Push sonrası Actions sekmesine bak |
| P12 | İspanyolca ve Portekizce | hayır | — |
| K1 | Admin komut kısıtlaması | — | **Karar:** canlıda admin kullanacak mısın? |
| K2 | Robux açılışı | — | **Karar + ürün kimlikleri** |
| K3 | Lobi / rezerve sunucu | — | **Karar:** telemetri 2-4 hafta birikince |

K paketleri için karar verdiğinde Sonnet'e "docs/ANALIZ_RAPORU.md bölüm X'i şu kararla uygula" demen yeterli (K1: 1.5, K2: 8.2, K3: 2.5/8.1). Ortak kurallar yine geçerli.

---

## Ortak kurallar (her prompt bunu okutur)
- `CLAUDE.md`, `AGENTS.md`, `docs/MIMARI.md` ve `docs/ANALIZ_RAPORU.md`'nin ilgili bölümlerini oku. AGENTS.md'deki tabloya göre dokunduğun dosyanın kural dosyasını bir kez oku. İlgili `.cursor/skills/<ad>/SKILL.md` varsa (remote, ui, content, map, localize, save-schema) onu izle.
- Main'den `git checkout -b <paket-dalı>` ile çalış. Her madde ayrı commit (`fix:` / `feat:` / `balance:` / `perf:` / `test:` / `docs:` öneki, kısa Türkçe başlık). Push etme.
- Her maddeden sonra: `stylua src tests plugin` → `selene src` → `python scripts/run-tests.py`. Bitirirken `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1` temiz olmalı.
- Yeni oyuncu metni → en/de/ru çevirisi. Kayıt alanı değişirse `roblox-save-schema` skill'i. `src/server/World` veya `plugin/` değişirse raporda "eklentiyi yeniden derle" de. Harita düzeni değişirse `MAP_VERSION` artır.
- Soru sormak için durma. Riskli ya da belirsiz maddeyi atla, gerekçeyi yaz, devam et. Kapsam dışına çıkma; gördüğün sorunları yalnızca not et.
- **Rapor biçimi (kısa tut):**
  1. Özet (3 satır).
  2. Madde tablosu: # | Durum | Commit | Dosyalar | Testler.
  3. Sapmalar.
  4. verify.ps1 son satırı.
  5. Studio'da denenecekler.
  6. Açık sorular.
  7. `git log --oneline main..HEAD`.

---

## P9 — CI
```text
docs/SONNET_IS_PAKETLERI.md "Ortak kurallar"a uy. Dal: ci/github-actions. Kapsam: docs/ANALIZ_RAPORU.md 7.2.
.github/workflows/verify.yml: push ve pull_request'te windows-latest; rokit ile rokit.toml araçları (resmî kurulum yöntemini kullan), Python, scripts/setup-types.ps1 ile Luau + luau-lsp, sonra scripts/verify.ps1. Araç önbelleği (actions/cache). Gizli anahtar gerekmez.
Yerelde çalıştırılabilecek kadarını dene (verify.ps1); workflow sözdizimini dikkatle kontrol et. Push etme; raporda kullanıcının push sonrası Actions sekmesinde neye bakacağını yaz.
README'ye kısa CI bölümü.
```

---

## P12 — İspanyolca ve Portekizce
```text
docs/SONNET_IS_PAKETLERI.md "Ortak kurallar"a uy (localization.mdc, roblox-localize skill). Dal: feat/es-pt. Kapsam: docs/ANALIZ_RAPORU.md bölüm 5 dil satırı.
Config.LANGUAGES'e es ve pt-br ekle; src/shared/Locales/es.luau ve pt.luau (en.luau'daki bütün anahtarlar, {1}/{2} yer tutucuları korunarak; oyuncuya "tú"/"você" ile hitap). UiKit.flag ile İspanya ve Brezilya bayrakları (şekillerle). LocaleId eşlemesi (es-*, pt-*). check-locales.py yeni dilleri de denetlesin; --strict-literals temiz.
Ayrıca rapor 5'teki Rusça hitap tutarlılığı (ты) ve Almanca "es" düzeltmesi.
```
