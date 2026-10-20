# Sıcak dosyalar (büyük dosyaları baştan okuma)

Satır aralıkları Grep -n ile doğrulandı (2026-10-20); dosya değişince Grep ile yeniden bul. Önce `Grep -n`, sonra `Read offset/limit`.

## src/shared/Config/init.luau (720 sat, ~27 KB)
Veri tabloları `Config/*.luau` alt modüllerindedir; `init` birleştirir. Önce alt modüle bak. Bölümler: 24-44 tip dışa aktarımı; 171-247 tema/ada/hayvan yardımcıları; 249-367 `LevelChain` seviye zincirleri; 368-433 eklenti kapasitesi, yapı geliştirme, `BUILD_TARGETS`; 434-486 başlangıç parası, görünüm/simge/ad; 488-505 `curvedCost`; 507-553 eşya kanalı; 555-636 yükseltme sorguları; 638-682 ürün kaynağı; 684-719 `getMinBarnLevel`, eklenti sorguları. İşlev: `Grep -n "^function Config\." src/shared/Config/init.luau`.

## src/shared/GameTypes.luau (129 sat, ~34 KB, satırlar uzun)
Bütün okuma; `Grep -n "export type X"` + `Read offset/limit`. Tip satırları: AnimalStage 3-6, AnimalTask 7-13, AnimalRecord 14-23, ContractsRecord 24-29, ProductionJob 30-40, MainFarmSummary 41-48, SeasonalGoal 49-50, EnvOverride 51-52, InventoryData 53-58, WalletTransfers 59-64, PermanentOwned 65-65, ProgressionData 66-81, PlayerSave 82-129.

## src/server/Services/PlotService.luau (674 sat)
46-142 sahiplik sorguları; 143-237 ışınlama; 238-453 görsel durum (`applyZoneState`, `applyIslandState`, `renderFarm`, `refreshPlayerWorld`); 454-548 `resetPlot`, `bindFarm`, `findFreePlot`; 549-598 ana çiftlik (`restoreMainFarms`, `selectMainFarm`); 599-674 `assign`, `release`, `init`.

## docs/DEVIR_DURUMU.md (279 sat, ~63 KB)
Tarihsel devir notu; güncel davranış kaynak koddadır. `## ` başlıkları (satır aralığı başlık): 3-5 Uzun ayrılıktan dönüş; 6-8 Oyuncu metni sadeleştirme; 9-11 Ekipman dengesi; 12-36 Sekiz adımlı öğretici; 37-46 Etkileşim / elde tutma incelemesi; 47-52 Hazır Başlangıç güçlendirildi; 53-58 Rebirth'i değerli kılma paketi; 59-62 Altın yalnız rebirth'te ve erken rebirth; 63-66 On yeni ekipman; 67-74 Ekipman kanalları ve altın ekonomisi; 75-78 Çoban asaları ve kanat hızı; 79-84 Asa yetenekleri; 85-96 Başlangıç öğreticisi ve meydan sıralama; 97-102 Model yüzey birleşimleri; 103-110 Canlı dünya geliştirmesi; 111-118 Boş ve tamamlanmış arayüzler; 119-126 Teslim edilen yapı; 127-138 Temizlik; 139-150 Yayın öncesi somut kalan işler; 151-154 Devralma promptu; 155-162 Son arayüz çalışması; 163-174 Ada dönüşü, meydan ve bildirim düzeni; 175-182 Canlı çimen yüzeyi; 183-192 Görünür geometriyi model kaynağına taşıma; 193-204 Creator Hub kimlikleri; 205-216 Sürüklenebilir pencereler ve sekme geçişleri; 217-220 4 Ekim 2026 özetı; 221-231 Eklentide hayvan hareketinin kilitlenmesi; 232-272 Mesh içermeyen yeni çayır tasarımı; 273-279 Ada geneline yayılan ıslanma ve gerçek.

## tests/economy.spec.luau (1100 sat)
Tek `return function(FarmMath, Config, Environment)`, yardımcılar 4-27. Bölümler: çevrimdışı/gelir hesabı (28-211); büyüme hızı/süresi (212-289); satış, iade, para biçimi (290-377); depo, toplu alım (378-410); ada temaları, tarifler, ana hayvan (411-554); ırk geliştirme ve gelir çarpanı (555-614); alan genişletme, yapı geliştirme (615-759); tema ulaşılabilirliği (760-829); eşya etkileri (830-857); zorluk ve dinamik fiyat (858-1046); gelir dağılımı, açılış, büyüme süresi (1047-1100).

## src/shared/Locales/*.luau (en 112 KB, ru 153 KB)
Bütün okuma. Anahtarı `Grep -n` ile bul, çevresini `Read offset/limit` ile oku; beş dilde birlikte güncelle (`roblox-localize`).
