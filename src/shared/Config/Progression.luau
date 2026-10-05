--!strict
-- Altın ve rebirth başlangıç ayarları; ölçümle yeniden ayarlanabilir.
export type PerkDefinition = { maxLevel: number, effects: { [string]: number } }
-- Creator Hub kimliği hazır olduğunda teklife robuxProductId eklenir; yoksa satış kapalıdır.
export type PermanentOffer = { id: string, kind: string, itemId: string?, goldCost: number, robuxProductId: number? }
export type Milestone = { displayName: string, description: string, effects: { [string]: number }?, itemId: string? }
export type CompletionRequirements = {
	fromCount: number,
	homeExpansionLevel: number,
	zoneExpansionLevel: number,
	homeLineageLevel: number,
	homeFacilityLevel: number,
	description: string,
}

local data = {
	maxRebirth = 30,
	terminalDoubleGold = 200,
	milestones = {
		{
			displayName = "Yeni Ufuk",
			description = "Nakit deposu +%2 · Kalıcı Rüzgar Muskası",
			effects = { storageBonus = 0.02 },
			itemId = "wind_charm",
		},
		{
			displayName = "İlk Ortaklık",
			description = "Sipariş ödülü +%1 · Kalıcı Tüccar Şapkası",
			effects = { contractBonus = 0.01 },
			itemId = "merchant_hat",
		},
		{
			displayName = "Ada Kâşifi",
			description = "Rebirth altını +%10 · Kalıcı Büyük Depo Muskası",
			effects = { goldBonus = 0.1 },
			itemId = "storage_charm_2",
		},
		{
			displayName = "Çalışkan Atölye",
			description = "Üretim hızı +%1 · Kalıcı Büyük Büyüme Muskası",
			effects = { facilitySpeed = 0.01 },
			itemId = "growth_charm_2",
		},
		{
			displayName = "Zaman Ustası",
			description = "Altınla bitirme indirimi %10 · Kalıcı Usta Tüccar Defteri",
			effects = { finishDiscount = 0.1 },
			itemId = "contract_charm_2",
		},
		{ displayName = "Öncü Çiftçi", description = "Kalıcı Öncü Çekici", itemId = "pioneer_hammer" },
		{ displayName = "Ambar Düzeni", description = "Nakit deposu +%2", effects = { storageBonus = 0.02 } },
		{
			displayName = "Gece Vardiyası",
			description = "Çevrimdışı gelir oranı +1 puan",
			effects = { offlineBonus = 0.01 },
		},
		{
			displayName = "Pazar Dostu",
			description = "Sipariş ödülü +%1 · Kalıcı Şans Yoncası",
			effects = { contractBonus = 0.01 },
			itemId = "lucky_clover",
		},
		{ displayName = "Takımada Uzmanı", description = "Rebirth altını +%10", effects = { goldBonus = 0.1 } },
		{
			displayName = "Hazır Sermaye",
			description = "Başlangıç parası bir hayvan bedeli artar",
			effects = { startingAnimals = 1 },
		},
		{ displayName = "Bakım Uzmanı", description = "Kalıcı Bakıcı Asası", itemId = "caretaker_staff" },
		{ displayName = "Usta Üretici", description = "Üretim hızı +%1", effects = { facilitySpeed = 0.01 } },
		{ displayName = "Geniş Ambar", description = "Nakit deposu +%3", effects = { storageBonus = 0.03 } },
		{
			displayName = "Uzun Mola",
			description = "Çevrimdışı kazanç süresi +15 dakika · Kalıcı Hasat Orağı",
			effects = { offlineHours = 0.25 },
			itemId = "harvest_sickle",
		},
		{ displayName = "Ticaret Ağı", description = "Sipariş ödülü +%2", effects = { contractBonus = 0.02 } },
		{ displayName = "Atölye Düzeni", description = "Üretim hızı +%1", effects = { facilitySpeed = 0.01 } },
		{ displayName = "Liman Ustası", description = "Kalıcı Liman Muskası", itemId = "harbor_charm" },
		{ displayName = "Güçlü Lojistik", description = "Nakit deposu +%3", effects = { storageBonus = 0.03 } },
		{
			displayName = "İkinci Sermaye",
			description = "Başlangıç parası bir hayvan bedeli artar",
			effects = { startingAnimals = 1 },
		},
		{
			displayName = "Dinlenen Çiftlik",
			description = "Çevrimdışı gelir oranı +1 puan · Kalıcı Zafer Çelengi",
			effects = { offlineBonus = 0.01 },
			itemId = "victory_laurel",
		},
		{
			displayName = "Güvenilir Tüccar",
			description = "Sipariş ödülü +%2",
			effects = { contractBonus = 0.02 },
		},
		{ displayName = "İleri Atölye", description = "Üretim hızı +%2", effects = { facilitySpeed = 0.02 } },
		{ displayName = "Gece Yolcusu", description = "Kalıcı Gece Pelerini", itemId = "night_cape" },
		{
			displayName = "Rahat Mola",
			description = "Çevrimdışı kazanç süresi +15 dakika",
			effects = { offlineHours = 0.25 },
		},
		{ displayName = "Büyük Lojistik", description = "Nakit deposu +%5", effects = { storageBonus = 0.05 } },
		{
			displayName = "Ticaret Ustası",
			description = "Sipariş ödülü +%2 · Kalıcı Anka Kanatları",
			effects = { contractBonus = 0.02 },
			itemId = "phoenix_wings",
		},
		{ displayName = "Son Atölye", description = "Üretim hızı +%2", effects = { facilitySpeed = 0.02 } },
		{
			displayName = "Zamanın Efendisi",
			description = "Altınla bitirme indirimi +%5",
			effects = { finishDiscount = 0.05 },
		},
		{
			displayName = "Takımada Şampiyonu",
			description = "Kalıcı Ustalık Tacı; son rebirth",
			itemId = "master_crown",
		},
	} :: { Milestone },
	completionRequirements = {
		{
			fromCount = 0,
			homeExpansionLevel = 0,
			zoneExpansionLevel = 0,
			homeLineageLevel = 0,
			homeFacilityLevel = 0,
			description = "Altı çiftliğin temel yükseltmelerini tamamla",
		},
		{
			fromCount = 5,
			homeExpansionLevel = 1,
			zoneExpansionLevel = 0,
			homeLineageLevel = 1,
			homeFacilityLevel = 0,
			description = "Her çiftlikte ana ağılı ve ana hayvan soyunu Sv.1 yap",
		},
		{
			fromCount = 10,
			homeExpansionLevel = 2,
			zoneExpansionLevel = 0,
			homeLineageLevel = 2,
			homeFacilityLevel = 1,
			description = "Ana ağıl ve soy Sv.2; ana para tesisi Sv.1",
		},
		{
			fromCount = 15,
			homeExpansionLevel = 2,
			zoneExpansionLevel = 1,
			homeLineageLevel = 2,
			homeFacilityLevel = 2,
			description = "Bütün açık ağıllar Sv.1; ana ağıl ve soy Sv.2; ana para tesisi Sv.2",
		},
		{
			fromCount = 20,
			homeExpansionLevel = 3,
			zoneExpansionLevel = 2,
			homeLineageLevel = 3,
			homeFacilityLevel = 3,
			description = "Bütün açık ağıllar Sv.2; ana ağıl, soy ve para tesisi Sv.3",
		},
		{
			fromCount = 25,
			homeExpansionLevel = 4,
			zoneExpansionLevel = 3,
			homeLineageLevel = 4,
			homeFacilityLevel = 4,
			description = "Bütün açık ağıllar Sv.3; ana ağıl, soy ve para tesisi Sv.4",
		},
		{
			fromCount = 29,
			homeExpansionLevel = 5,
			zoneExpansionLevel = 4,
			homeLineageLevel = 5,
			homeFacilityLevel = 5,
			description = "Bütün açık ağıllar Sv.4; ana ağıl, soy ve para tesisi Sv.5",
		},
	} :: { CompletionRequirements },
	-- Altın yalnız bütün tur bitince (altı çiftlik tamam = rebirth hazır) TEK ödül olarak, rebirth işlemiyle birlikte
	-- verilir: rebirthBase + rebirthPerLevel * (o ana kadarki rebirth sayısı), sonra tamamlama altını (goldBonus) %'si.
	-- ~750-1040 altın = bir kalıcı prim eşyanın altın bedeli (350-900; Elmas Çekiç 740), yani bir rebirth ~bir kalıcı eşya.
	-- R30'da (son sıfırlama bitti) tur tamamlanınca aynı ödül bir kez `claims.terminal` ile verilir.
	-- Ada/çiftlik başına altın yoktur (eski island/farm alanları ve `island:`/`farm:` hak anahtarları kaldırıldı).
	gold = {
		rebirthBase = 750,
		rebirthPerLevel = 10,
		cashSeconds = 30,
		dailyLimit = 200,
		runLimit = 600,
		maxBalance = 1e9,
	},
	finishTargets = { growth = true, extension = true } :: { [string]: boolean },
	returnSeconds = 86400,
	returnIncomeMultiplier = 3,
	returnGrowthExcess = 0.5,
	permanentIncomeCap = 3,
	perkOrder = {
		"income",
		"growth",
		"starting_cash",
		"upgrade_discount",
		"facility_speed",
		"offline",
		"contract",
		"ready_start",
	},
	perks = {
		income = { maxLevel = 5, effects = { incomeBonus = 0.10 } },
		growth = { maxLevel = 5, effects = { growthExcess = 0.075 } },
		starting_cash = { maxLevel = 5, effects = { startingAnimals = 2 } },
		upgrade_discount = { maxLevel = 5, effects = { upgradeDiscount = 0.04 } },
		facility_speed = { maxLevel = 5, effects = { facilitySpeed = 0.06 } },
		offline = { maxLevel = 5, effects = { offlineBonus = 0.06, offlineHours = 0.6 } },
		contract = { maxLevel = 5, effects = { contractBonus = 0.05 } },
		ready_start = { maxLevel = 5, effects = { incomeBonus = 0.015 } }, -- Başlangıç paketi (Progression.applyReadyStart) + seviye başına küçük kalıcı gelir
	} :: { [string]: PerkDefinition },
	-- Eşya teklifinin altın bedeli ÖLÇÜLEN tempo kazancından türer (tests/config.spec doğrular; eski nakit-fiyat formülü
	-- ölçülen faydayla yalnız 0,36 korelasyonluydu):
	--   goldCost = min(1500, yuvarla10(taban(kanal) + 28 * puan)); taban: cashGold 150, goldRobux/gold 400
	--   puan = TEMPO_POINTS + 15 * hareket + 8 * satış; TEMPO_POINTS = (ideal R5 % + max(casual R5 % - 2, 0)) / 2
	--   (`python scripts/simulate-items.py` tek eşya kazancı; tablo tests/config.spec'te, sonuçlar docs/ZORLUK_VE_FIYAT.md'de).
	-- Aynı kanalda daha çok tempo veren eşya daha ucuz olamaz; ölü yük eşya taban fiyatta (ucuz), Altın Taç tavana yakın kalır.
	-- Bir rebirth ~750-1040 altın verir (gold.rebirthBase): iyi bir eşya ~bir rebirth, orta eşya bir kesir, Altın Taç ~1,5 rebirth.
	-- Kanallar: nakit fiyat <= ~150k yalnız nakit (teklif yok); aşağıdaki ilk grup nakit + kalıcı teklif;
	-- ikinci grup nakitsiz altın/Robux; üçüncü grup nakitsiz yalnız altın. Robux kimlikleri değişmez, yenisi eklenmez.
	permanentOffers = {
		-- Nakit + altın/Robux: tur içi nakitle ya da kalıcı teklifle (Robux kimliği olanlar Robux ile de)
		iron_hammer = { id = "iron_hammer", kind = "item", itemId = "iron_hammer", goldCost = 320 },
		weather_staff_3 = { id = "weather_staff_3", kind = "item", itemId = "weather_staff_3", goldCost = 230 },
		season_staff_3 = { id = "season_staff_3", kind = "item", itemId = "season_staff_3", goldCost = 160 },
		weather_staff_5 = { id = "weather_staff_5", kind = "item", itemId = "weather_staff_5", goldCost = 270 },
		season_staff_5 = { id = "season_staff_5", kind = "item", itemId = "season_staff_5", goldCost = 160 },
		breeder_staff = {
			id = "breeder_staff",
			kind = "item",
			itemId = "breeder_staff",
			goldCost = 150,
			robuxProductId = 3716414748,
		},
		storage_charm_2 = {
			id = "storage_charm_2",
			kind = "item",
			itemId = "storage_charm_2",
			goldCost = 200,
			robuxProductId = 3716414468,
		},
		wind_charm = {
			id = "wind_charm",
			kind = "item",
			itemId = "wind_charm",
			goldCost = 240,
			robuxProductId = 3716422184,
		},
		growth_charm_2 = {
			id = "growth_charm_2",
			kind = "item",
			itemId = "growth_charm_2",
			goldCost = 150,
			robuxProductId = 3716414440,
		},
		barn_charm_2 = {
			id = "barn_charm_2",
			kind = "item",
			itemId = "barn_charm_2",
			goldCost = 260,
			robuxProductId = 3716414486,
		},
		contract_charm_2 = {
			id = "contract_charm_2",
			kind = "item",
			itemId = "contract_charm_2",
			goldCost = 190,
			robuxProductId = 3716414500,
		},
		income_charm_2 = { id = "income_charm_2", kind = "item", itemId = "income_charm_2", goldCost = 340 },
		night_charm = {
			id = "night_charm",
			kind = "item",
			itemId = "night_charm",
			goldCost = 320,
			robuxProductId = 3716414581,
		},
		angel_wings = { id = "angel_wings", kind = "item", itemId = "angel_wings", goldCost = 320 },
		peacock_tail = { id = "peacock_tail", kind = "item", itemId = "peacock_tail", goldCost = 150 },
		merchant_hat = {
			id = "merchant_hat",
			kind = "item",
			itemId = "merchant_hat",
			goldCost = 250,
			robuxProductId = 3716414654,
		},
		artisan_cape = {
			id = "artisan_cape",
			kind = "item",
			itemId = "artisan_cape",
			goldCost = 170,
			robuxProductId = 3716414694,
		},
		-- Altın + Robux (nakit yok): üst kademe ekipman
		artisan_hammer = {
			id = "artisan_hammer",
			kind = "item",
			itemId = "artisan_hammer",
			goldCost = 730,
			robuxProductId = 3716414543,
		},
		diamond_hammer = {
			id = "diamond_hammer",
			kind = "item",
			itemId = "diamond_hammer",
			goldCost = 750,
			robuxProductId = 3716414346,
		},
		artisan_staff = {
			id = "artisan_staff",
			kind = "item",
			itemId = "artisan_staff",
			goldCost = 400,
			robuxProductId = 3716414566,
		},
		weather_staff_inf = {
			id = "weather_staff_inf",
			kind = "item",
			itemId = "weather_staff_inf",
			goldCost = 420,
			robuxProductId = 3716414398,
		},
		season_staff_inf = {
			id = "season_staff_inf",
			kind = "item",
			itemId = "season_staff_inf",
			goldCost = 410,
			robuxProductId = 3716414370,
		},
		orchard_charm = {
			id = "orchard_charm",
			kind = "item",
			itemId = "orchard_charm",
			goldCost = 420,
			robuxProductId = 3716414629,
		},
		logistics_charm = {
			id = "logistics_charm",
			kind = "item",
			itemId = "logistics_charm",
			goldCost = 500,
			robuxProductId = 3716414610,
		},
		trade_charm = {
			id = "trade_charm",
			kind = "item",
			itemId = "trade_charm",
			goldCost = 560,
			robuxProductId = 3716414706,
		},
		income_charm_3 = {
			id = "income_charm_3",
			kind = "item",
			itemId = "income_charm_3",
			goldCost = 700,
			robuxProductId = 3716414420,
		},
		golden_crown = {
			id = "golden_crown",
			kind = "item",
			itemId = "golden_crown",
			goldCost = 1180,
			robuxProductId = 3716414520,
		},
		golden_wings = {
			id = "golden_wings",
			kind = "item",
			itemId = "golden_wings",
			goldCost = 720,
			robuxProductId = 3716415888,
		},
		expedition_pack = {
			id = "expedition_pack",
			kind = "item",
			itemId = "expedition_pack",
			goldCost = 590,
			robuxProductId = 3716414674,
		},
		warehouse_pack = {
			id = "warehouse_pack",
			kind = "item",
			itemId = "warehouse_pack",
			goldCost = 560,
			robuxProductId = 3716414729,
		},
		-- Yalnız altın (nakit yok, Robux kimliği yok)
		gold_hammer = { id = "gold_hammer", kind = "item", itemId = "gold_hammer", goldCost = 680 },
		foreman_mallet = { id = "foreman_mallet", kind = "item", itemId = "foreman_mallet", goldCost = 790 },
		fortune_charm = { id = "fortune_charm", kind = "item", itemId = "fortune_charm", goldCost = 830 },
		tycoon_crown = { id = "tycoon_crown", kind = "item", itemId = "tycoon_crown", goldCost = 620 },
		caravan_satchel = { id = "caravan_satchel", kind = "item", itemId = "caravan_satchel", goldCost = 470 },
		eternal_shepherd_staff = {
			id = "eternal_shepherd_staff",
			kind = "item",
			itemId = "eternal_shepherd_staff",
			goldCost = 620,
		},
		crystal_wings = { id = "crystal_wings", kind = "item", itemId = "crystal_wings", goldCost = 600 },
		engineer_wrench = { id = "engineer_wrench", kind = "item", itemId = "engineer_wrench", goldCost = 750 },
		scholar_charm = { id = "scholar_charm", kind = "item", itemId = "scholar_charm", goldCost = 520 },
		captain_hat = { id = "captain_hat", kind = "item", itemId = "captain_hat", goldCost = 510 },
		courier_pack = { id = "courier_pack", kind = "item", itemId = "courier_pack", goldCost = 450 },
		merchant_seal = { id = "merchant_seal", kind = "item", itemId = "merchant_seal", goldCost = 510 },
		-- Kolaylıklar: altın bedeli sabit (eşya formülüne bağlı değil)
		auto_collect = { id = "auto_collect", kind = "convenience", goldCost = 300 },
		pet_cash = { id = "pet_cash", kind = "convenience", goldCost = 500, robuxProductId = 3716414769 },
		pet_goods = { id = "pet_goods", kind = "convenience", goldCost = 500, robuxProductId = 3716414780 },
	} :: { [string]: PermanentOffer },
}

return data
