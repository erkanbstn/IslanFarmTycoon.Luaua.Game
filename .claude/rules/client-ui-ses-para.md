---
description: Ses (Sfx), para biçimi, bildirimler ve UI performansı
paths:
  - "src/client/Core/**"
  - "src/client/Ui/**/*.luau"
---

# Arayüz standardı: Ses Para

Giriş dosyası: `.claude/rules/client-ui.md` (konu haritası).

## Ses ve para biçimi
- Robux düğmeleri `Core/ProductPrices` üzerinden istemcide `GetProductInfoAsync` fiyatını gösterir (GamePass/Product türü ayrı). Fiyatı Config'e kopyalama; bölgesel fiyat korunur. Sorgular katalogla sınırlı, tek kuyruk ve süreli önbellekle yapılır; yükleme menüyü bekletmez. Başarısızlık fiyat uydurmaz, Roblox ekranında kontrol seçeneği verir. StoreSection fiyat dinleyicisi sayfa yok edilince kopar.
- Sesler `src/client/Core/Sfx.luau` üzerinden çalınır (`Sfx.play("coin")`, `Sfx.playAt`); kimlikler
  `Config.SOUNDS / AMBIENCE / ANIMAL_SOUNDS / MUSIC`. Boş `id` = ses yok. Üç SoundGroup (`SfxMaster`, `AmbienceMaster`, `MusicMaster`): efekt (`SoundVolume`), ortam + hayvan (`AmbienceVolume`),
  müzik (`MusicVolume`); varsayılanlar `Config.AUDIO_DEFAULTS`; Ayarlar'da üç `UiKit.slider`. Ses düzeyleri ve `ReducedMotion` hesaba kaydedilir (`Core/Preferences.client`,
  remote `RequestSetPreference`, sunucu `Modules/Preferences`): yeni tercih eklerken oraya ekle (roblox-save-schema + roblox-add-remote).
  Ortam, hayvan ve müzik `Soundscape.client`.
- Para her yerde `FarmMath.formatMoney` ile yazılır (küçük tutarlar tam, büyükler `$12.4K`/`$3.1M` gibi kısaltılır; eşik fonksiyonda). Kendi biçimlendiricini yazma.
- Altın cüzdanı `UiKit.iconChip` içinde `🪙` ile gösterilir; bileşen bu simgeyi GUI şekilleriyle çizer (platformun emoji/Robux glifine güvenmez). Uzun fiyat ve açıklama doğal büyür; kullanıcıya görünen miktarı taşırma.
- Bildirimler `toastHost` ile tek ortak Notifications katmanında gösterilir (menülerin üstünde). En fazla iki görünür, altı bekleyen bildirim tutulur; taşmada en eski bekleyen çıkarılır. Aynı metin/tür ×N ile birleştirilir. İsteğe bağlı görünür engeller (üst menü, öğretici, tüccar rozeti) gerçek yükseklikleriyle alan ayırır; kök yok edilince kuyruk ve zamanlayıcılar temizlenir. Ayrı konumlama/tekrar süzme kodu yazma.

## Performans
- Durum güncellemesi yapısal (`structural`) ve para değişimi ayrı ele alınır; aynı metni tekrar yazma
  (`buttonStates` imza kalıbı). Her karede UI güncelleme yok; 0.25–1 sn aralık yeterli.
