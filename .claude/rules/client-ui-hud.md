---
description: HUD yerleşim bölgeleri, menü kademeleri, Hud modülleri, ada bağlamı, mevsim/hava
paths:
  - "src/client/Ui/FarmHud.client.luau"
  - "src/client/Ui/Hud/**"
  - "src/client/Ui/IslandManager.luau"
---

# Arayüz standardı: Hud

Giriş dosyası: `.claude/rules/client-ui.md` (konu haritası).

## HUD yerleşim bölgeleri (FarmHud) — çakışma olmasın
| Bölge | İçerik |
|---|---|
| Sol orta | `Stats` paneli (sola kayarak kapanır; sağ kenarında sekme): ada adı, para+gelir, ahır, depo, mevsim/hava kartı, sıradaki hedef ve sıradaki ada |
| Üst orta | `MenuTop` karo çubuğu: Pazar, Yükseltmeler, Yol Haritası, Üretim, Adalar (bildirimler bunun altında) |
| Sağ orta | `MenuSide` karo sütunu: Envanter, Ödüller, Market (kimlik 0 iken katalog görünür, ödeme kapalı), İlerleme (ilk hayvan veya rebirth sonrası), Adama Dön, Ayarlar, (yönetici) Yönetici |
| Orta (pencere) | Pazar / Yol Haritası / Yükseltmeler: ortak merkez, geniş içerik; Yol Haritası ada içinde aşama sekmeleri kullanır |
| Orta (pencere) | Ödüller, Sipariş Panosu, Market (Robux katalog, kalıcı altın teklifleri, altın çevirme ve hızlı bitirme), Eşya Dükkânı, Envanter. Dar ekranda UiKit pencere kaydıyla birbirini kapatır; meydan satıcıları ve pazar tezgâhı ilgili pencereyi açar |
| Üst orta | Bildirimler (toast) |
| Sağ üst / sol üst | Roblox oyuncu listesi ve sohbet — HUD buraya bir şey koymaz |

- **Menü kademeli açılır** (`Hud/MenuBar` içinde `updateVisibility` / `setMenuTile`): yeni oyuncu yalnızca temel karoları görür; diğerleri ihtiyaç doğunca (onboarding adımı, kazanç, sahip olunan tesis/eşya) belirir ve kısa süre vurgulanır (`UNLOCK_NOTICES`).
  Yeni karo eklerken ne zaman görüneceğini `updateVisibility`'de belirle; hepsini baştan gösterme.
- Sol panel: ipucu satırı (`StatsPanel` içinde `hintWanted`) yalnızca sorun varken görünür; hedef kartı (`Hud/GoalCard`) tek hedef gösterir, deneyimli oyuncuda altına "bekleyen iş" satırları (`pendingChores`) ve büyük hedef için biriktirirken "Hızlı kazanç" önerisi gelir.
- Yeni yapı/geliştirme kilometre taşı kutlaması `Hud/Celebration` ile (durum farkından `detectMilestone`); yeni kilometre taşı türü eklersen oraya ekle.
- Yeni menü girişi: `Hud/MenuBar` içinde `UiKit.menuButton` kur, `topOrder`/`sideOrder` listesine (gamepad zinciri ve sıra) ve `updateVisibility`'e ekle. Ayrıntılı/az kullanılan bilgi ana HUD'a değil ilgili pencereye gider (ödül ve başarımlar "Ödüller" penceresinde).
- Pencere açılınca `redraw`; kapalı pencere içeriği `*Dirty` bayraklarıyla ertelenir.
- Her yeni ekran metni için çeviri gerekir (localization rule). Kısa etiket seç; menü karosu `UiKit.MenuTileSize` genişliğindedir.

- HUD ana betiği `src/client/Ui/FarmHud.client.luau` yalnızca orkestrasyondur (ekranı kurar, modülleri bağlar, durumu dağıtır). Pencereler ve
  bölümler `src/client/Ui/Hud/` altındadır: `StatsPanel` (sol panel), `GoalCard` (hedef/ada kartları), `MenuBar` (üst menü çubuğu + sağ sütun + rozetler), `Celebration`, `ShopWindow`, `RoadmapWindow`, `UpgradesWindow`, `IslandTabs`, `StoreSection`,
  `RewardsSection`, `BoardSection`, `MarketWindow` (StoreSection katalog, altın cüzdanı/çevirme/hızlı bitirme), `ItemShopWindow` + `InventoryWindow` (+ ortak `ItemText`), `MerchantWindow` (kişisel ziyaretin nakit/tur kataloğu), `SeasonBar`, `Onboarding` (ilk adımlar: `shared/Modules/OnboardingSteps` ile durumdan türetilir, kayıt alanı yok; `UiKit.pulse` vurgusu + `TutorialGuide` özniteliğiyle CollectorGuide ışını), ortak `HudCommon` (`setPurchaseButton`, `purchaseHint`). Yeni pencere/bölüm
  eklerken ana betiğe yığmak yerine buraya `create(...)` + `update(state)` kalıbıyla yeni modül yaz.
- Mevsim/hava: ReplicatedStorage attribute'larını doğrudan okuma/dinleme; `Environment.getSeason()/getWeather()` ve `Environment.onChanged` kullan (asa ile oyuncuya özel katman otomatik uygulanır).
- Ada bağlamı: Yol Haritası/Yükseltmeler/Üretim `IslandTabs.add` ile pencereye özel önizleme tutar. Sekme tıklaması ortak `IslandContext` veya sunucu seçimini değiştirmez; her pencere kendi içeriğini tazeler. Elle seçilmemiş pencereler dünya adasını takip eder; çiftlik/rebirth değişince yerel seçim temizlenir. Üretim dünya promptu yalnız kendi penceresini ilgili adaya odaklar. Diğer HUD parçaları `IslandContext.get()` adasını gösterir. Açık adaya girince `IslandAutoSelect` sunucuda gerçek seçim yapar; kilitli adaya girince yalnızca
  client'ta önizleme (`IslandContext.setPreview`) kurar (sunucu kilitli adayı seçmeyi reddeder). Sunucuya giden hiçbir karar `get()` değerine dayanmamalı; sunucunun
  bildiği seçim `IslandContext.selected()`.
- Kartta durum bildirimi ("Dolu", "Kilitli", "Dolunca açılır") ölü bir düğme olarak değil, kartın sağ üstünde kırmızı yazı olarak gösterilir: `UiKit.setCardStatus(card, metin)` (yazı varken aksiyon düğmesi gizlenir, kart büyümez; metin yoksa `nil`). "Alındı"/"En üst seviye" gibi olumlu durumlar düğmede kalır.
- Para her yerde YEŞİLdir (kasa, gelir baloncukları, para bildirimi, depo etiketi, satın alma kaidesi etiketi/halkası); altın sarısı (`Color.Gold`) yalnızca başlık/vurgu içindir, para yazısında kullanılmaz.
