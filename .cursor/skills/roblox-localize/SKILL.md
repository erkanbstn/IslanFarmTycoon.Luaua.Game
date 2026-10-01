---
name: roblox-localize
description: Adds or fixes translations for this Roblox project's Turkish source texts in the en/de/ru/es/pt dictionaries, including template placeholders and split parts, and verifies coverage with scripts/check-locales.py. Use when new player-visible text is added, text shows up untranslated in-game, or a new language is requested.
---

# Çeviri ekleme

1. Metni bul (UiKit.text/button/menuButton, `.Text = `, WorldUi ve harita tabelaları, ProximityPrompt, sunucu Notify, kutlama panosu `celebrate`).
2. Anahtar = ekrana yazılan Türkçe metnin **tam hali**. Değişken kısımlar `{}`:
   kod `` `Önce: {names}` `` → anahtar `"Önce: {}"` → hedef `"Requires: {1}"`.
3. Aynı anahtarı `src/shared/Locales/en.luau`, `de.luau`, `ru.luau` içine ilgili bölüme ekle.
4. Parçalı metin: Localizer önce tam eşleşme, sonra " · " / satır sonu, sonra şablon, sonra ", "
   ile böler. `"İnek x3 · Süt"` için `"İnek x{}"` ve `"Süt"` ayrı ayrı yeterli.
5. Kısa etiket kuralı: menü karosu ~10 karakter; Almanca/Rusça/İspanyolca/Portekizce uzarsa kısalt ("Nach Hause", "Домой").
6. Doğrula:
   ```
   python scripts/check-locales.py --strict-literals
   ```
   Anahtar eşitliği hatası = bir dilde eksik anahtar. Literal uyarısı = sözlükte karşılığı olmayan
   UI metni (Localizer bölerek çeviremiyorsa oyunda Türkçe kalır).

## Yeni dil
`Config.LANGUAGES`'a kod ekle → `Locales/<kod>.luau` (en.luau'yu kopyala) → `UiKit.flag` için
`flagPainters[<kod>]` çiz → `check-locales.py` içindeki `LANGS`'a ekle.

## Toplu ekleme
Çok sayıda anahtar için küçük bir Python betiği yaz (Write aracıyla; bash heredoc ters eğik çizgiyi bozar): mevcut anahtarları oku, eksikleri sözlük dosyalarının sonuna ekle, `check-locales.py --strict-literals` ile doğrula.
