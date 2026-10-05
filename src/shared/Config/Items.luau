--!strict
-- Eşya tanımları. Fiyatlar toplam yükseltme harcamasına (≈12 milyon) ve gelir tempo hedeflerine göre ayarlıdır:
-- çekiç indirimleri, ilk saatte alınırsa büyük tasarruf sağlar; pahalı kademeler geç oyun içindir.
-- Tanımları `items` ve `order` tablolarına ekler (Config.ITEMS / Config.ITEM_ORDER).
-- Satış kanalı `price` (nakit referans) ve `noCash` ile belirlenir (Config.getItemChannel): ~150k ve altı yalnız nakit,
-- ~150k-1.5M nakit + kalıcı teklif, üst kademe `noCash` (yalnız Progression.permanentOffers: altın, Robux kimliği varsa Robux).
-- Altın bedeli ölçülen tempo kazancından türer (Progression.luau açıklaması; `price` yalnız kanal/sıralama referansıdır).
-- 5 Ekim 2026 ölçümü (scripts/simulate-items.py): ölü yük etkiler (`contractBonus`, <+%50 `goodsYield`) tek başına değer
-- üretmediği için ana faydası bunlar olan eşyalara gerçek bir ikinci etki (gelir/çevrimdışı) eklendi. Yuva rolleri: alet = maliyet indirimi, başlık = ticaret,
-- sırt = lojistik, muska = ekonomi, asa = güç + pasif.

local Types = require(script.Parent:WaitForChild("Types"))

local Items = {}

function Items.install(items: { [string]: Types.ItemConfig }, order: { string })
	local levels: { [string]: number } = {}
	local tiers = {
		{
			"copper_hammer",
			"season_staff_1",
			"weather_staff_1",
			"storage_charm_1",
			"growth_charm_1",
			"income_charm_1",
			"farmer_hat",
			"flat_cap",
			"beanie",
			"straw_hat",
			"flower_crown",
			"backpack",
			"harvest_basket",
			"leaf_cloak",
		},
		{
			"iron_hammer",
			"pioneer_hammer",
			"season_staff_3",
			"weather_staff_3",
			"income_charm_2",
			"barn_charm_1",
			"contract_charm_1",
			"wind_charm",
			"chicken_hat",
			"cowboy_hat",
			"red_cape",
			"peacock_tail",
		},
		{
			"gold_hammer",
			"season_staff_5",
			"weather_staff_5",
			"caretaker_staff",
			"breeder_staff",
			"storage_charm_2",
			"growth_charm_2",
			"income_charm_3",
			"barn_charm_2",
			"contract_charm_2",
			"harbor_charm",
			"merchant_hat",
			"angel_wings",
			"artisan_cape",
			"expedition_pack",
			"lucky_clover",
			"harvest_sickle",
		},
		{
			"diamond_hammer",
			"artisan_hammer",
			"artisan_staff",
			"night_charm",
			"logistics_charm",
			"orchard_charm",
			"trade_charm",
			"golden_wings",
			"warehouse_pack",
			"night_cape",
			"master_crown",
			"foreman_mallet",
			"fortune_charm",
			"caravan_satchel",
			"victory_laurel",
			"phoenix_wings",
			"crystal_wings",
			"engineer_wrench",
			"scholar_charm",
			"captain_hat",
			"courier_pack",
			"merchant_seal",
		},
		{
			"season_staff_inf",
			"weather_staff_inf",
			"golden_crown",
			"eternal_shepherd_staff",
			"tycoon_crown",
		},
	}
	for level, ids in tiers do
		for _, id in ids do
			levels[id] = level
		end
	end
	local function add(item: Types.ItemConfig)
		assert(levels[item.id], `Eşya katalog seviyesi eksik: {item.id}`)
		item.level = levels[item.id]
		items[item.id] = item
		table.insert(order, item.id)
	end

	-- Hız odaklı muska: ekonomik muska yuvasından vazgeçerek daha rahat ulaşım.
	add({
		id = "wind_charm",
		displayName = "Rüzgar Muskası",
		icon = "📿",
		slot = "charm",
		price = 550000,
		effects = { movementSpeed = 0.15, offlineBonus = 0.03 },
		tradeoffs = { goodsYield = 0.03 },
		look = { attach = "chest" },
	})

	-- Aletler: tüm yükseltme maliyetlerinden kalıcı indirim
	add({
		id = "copper_hammer",
		displayName = "Bakır Çekiç",
		icon = "🔨",
		slot = "tool",
		price = 150000,
		effects = { upgradeDiscount = 0.05, expansionDiscount = 0.03 },
		look = { attach = "hip" },
	})
	add({
		id = "iron_hammer",
		displayName = "Demir Çekiç",
		icon = "🔨",
		slot = "tool",
		price = 600000,
		effects = { upgradeDiscount = 0.1, expansionDiscount = 0.06, sellBonus = 0.05 },
		look = { attach = "hip" },
	})
	add({
		id = "gold_hammer",
		displayName = "Altın Çekiç",
		icon = "🔨",
		slot = "tool",
		price = 2000000,
		noCash = true,
		effects = { upgradeDiscount = 0.14, expansionDiscount = 0.09, sellBonus = 0.08, facilitySpeed = 0.05 },
		look = { attach = "hip" },
	})
	add({
		id = "diamond_hammer",
		displayName = "Elmas Çekiç",
		icon = "🔨",
		slot = "tool",
		-- Ölçüm: upgradeDiscount 0,20 -> 0,15 (ideal R5 %12,1 -> ~%10,9). `price` referansı Ustabaşı/Mühendis'in altına çekildi:
		-- aile testi (pahalı kademe daha güçlü) için sıra Altın Çekiç .14 < Elmas .15 < Mühendis .16 < Ustabaşı .17.
		price = 2300000,
		noCash = true,
		effects = {
			movementSpeed = 0.02,
			upgradeDiscount = 0.15,
			expansionDiscount = 0.12,
			sellBonus = 0.12,
			facilitySpeed = 0.08,
		},
		look = { attach = "hip" },
	})

	-- Asalar: mevsim ya da hava değiştirme gücü (günlük hak sayısına göre kademeli, en üst kademe sınırsız)
	add({
		id = "season_staff_1",
		displayName = "Çırak Mevsim Asası",
		icon = "🪄",
		slot = "staff",
		price = 150000,
		effects = { contractBonus = 0.03 },
		power = { kind = "season", usesPerDay = 1 },
		look = { attach = "hand" },
	})
	add({
		id = "season_staff_3",
		displayName = "Usta Mevsim Asası",
		icon = "🪄",
		slot = "staff",
		price = 600000,
		effects = { contractBonus = 0.05, sellBonus = 0.03 },
		power = { kind = "season", usesPerDay = 3 },
		look = { attach = "hand" },
	})
	add({
		id = "season_staff_5",
		displayName = "Büyücü Mevsim Asası",
		icon = "🪄",
		slot = "staff",
		price = 1200000,
		effects = { contractBonus = 0.08, sellBonus = 0.05, goodsYield = 0.04 },
		power = { kind = "season", usesPerDay = 5 },
		look = { attach = "hand" },
	})
	add({
		id = "season_staff_inf",
		displayName = "Ebedi Mevsim Asası",
		icon = "🪄",
		slot = "staff",
		price = 6000000,
		noCash = true,
		effects = { movementSpeed = 0.03, contractBonus = 0.12, goodsYield = 0.06 },
		power = { kind = "season" },
		look = { attach = "hand" },
	})
	add({
		id = "weather_staff_1",
		displayName = "Çırak Çoban Asası",
		icon = "🪄",
		slot = "staff",
		price = 100000,
		effects = { facilitySpeed = 0.03, storageBonus = 0.05 },
		power = { kind = "collect", usesPerDay = 3 },
		look = { attach = "hand" },
	})
	add({
		id = "weather_staff_3",
		displayName = "Usta Çoban Asası",
		icon = "🪄",
		slot = "staff",
		price = 400000,
		effects = { facilitySpeed = 0.05, offlineBonus = 0.08 },
		power = { kind = "collect", usesPerDay = 6 },
		look = { attach = "hand" },
	})
	add({
		id = "weather_staff_5",
		displayName = "Üstat Çoban Asası",
		icon = "🪄",
		slot = "staff",
		price = 1000000,
		effects = { facilitySpeed = 0.07, offlineBonus = 0.1, expansionDiscount = 0.04 },
		power = { kind = "collect", usesPerDay = 12 },
		look = { attach = "hand" },
	})
	add({
		id = "weather_staff_inf",
		displayName = "Ebedi Hava Asası",
		icon = "🪄",
		slot = "staff",
		price = 4000000,
		noCash = true,
		effects = { movementSpeed = 0.03, goodsYield = 0.12, facilitySpeed = 0.06 },
		power = { kind = "weather", usesPerDay = 1 },
		look = { attach = "hand" },
	})

	-- Muskalar: takılıyken kalıcı pasif fayda (yalnızca bir muska takılır: hangisinin seçileceği bir karardır)
	add({
		id = "storage_charm_1",
		displayName = "Depo Muskası",
		icon = "📿",
		slot = "charm",
		price = 40000,
		effects = { storageBonus = 0.15, offlineBonus = 0.1 },
		look = { attach = "chest" },
	})
	add({
		id = "storage_charm_2",
		displayName = "Büyük Depo Muskası",
		icon = "📿",
		slot = "charm",
		price = 400000,
		effects = { storageBonus = 0.35, offlineBonus = 0.1 }, -- ölçüm: 0,20 casual'da %12 (ücretsiz R3 ödülü için fazla)
		look = { attach = "chest" },
	})
	add({
		id = "growth_charm_1",
		displayName = "Büyüme Muskası",
		icon = "📿",
		slot = "charm",
		price = 50000,
		effects = { growthSpeed = 1.15, facilitySpeed = 0.05 },
		look = { attach = "chest" },
	})
	add({
		id = "growth_charm_2",
		displayName = "Büyük Büyüme Muskası",
		icon = "📿",
		slot = "charm",
		price = 600000,
		effects = { growthSpeed = 1.4, facilitySpeed = 0.1 },
		look = { attach = "chest" },
	})
	add({
		id = "income_charm_1",
		displayName = "Bereket Muskası",
		icon = "📿",
		slot = "charm",
		price = 150000,
		effects = { incomeBonus = 0.03, sellBonus = 0.05 },
		look = { attach = "chest" },
	})
	add({
		id = "income_charm_2",
		displayName = "Büyük Bereket Muskası",
		icon = "📿",
		slot = "charm",
		price = 900000,
		effects = { incomeBonus = 0.06, sellBonus = 0.1 },
		look = { attach = "chest" },
	})
	add({
		id = "income_charm_3",
		displayName = "Altın Bereket Muskası",
		icon = "📿",
		slot = "charm",
		price = 5000000,
		noCash = true,
		effects = { incomeBonus = 0.1, sellBonus = 0.15 },
		look = { attach = "chest" },
	})

	-- Başlıklar (ticari etki)
	add({
		id = "farmer_hat",
		displayName = "Çiftçi Şapkası",
		icon = "🎩",
		slot = "head",
		price = 10000,
		effects = { sellBonus = 0.01 },
		look = { attach = "head" },
	})
	add({
		id = "flat_cap",
		displayName = "Kasket",
		icon = "🎩",
		slot = "head",
		price = 15000,
		effects = { contractBonus = 0.02 },
		look = { attach = "head" },
	})
	add({
		id = "chicken_hat",
		displayName = "Tavuk Şapkası",
		icon = "🎩",
		slot = "head",
		price = 30000,
		effects = { goodsYield = 0.02, sellBonus = 0.015 },
		look = { attach = "head" },
	})
	add({
		id = "cowboy_hat",
		displayName = "Kovboy Şapkası",
		icon = "🎩",
		slot = "head",
		price = 60000,
		effects = { sellBonus = 0.04, contractBonus = 0.03 },
		look = { attach = "head" },
	})
	add({
		id = "golden_crown",
		displayName = "Altın Taç",
		icon = "🎩",
		slot = "head",
		price = 30000000,
		noCash = true,
		-- Ölçüm: incomeBonus 1,0 tek başına tur süresini %50 kısaltıyordu (oyun kırıcı); 0,4 ≈ %29 (0,35 -> %26): hâlâ en güçlü ekipman.
		effects = { movementSpeed = 0.03, incomeBonus = 0.4, sellBonus = 0.04 },
		look = { attach = "head" },
	})

	-- Sırt eşyaları (lojistik etki)
	add({
		id = "backpack",
		displayName = "Sırt Çantası",
		icon = "🧥",
		slot = "back",
		price = 12000,
		effects = { storageBonus = 0.05 },
		look = { attach = "back" },
	})
	add({
		id = "red_cape",
		displayName = "Kırmızı Pelerin",
		icon = "🧥",
		slot = "back",
		price = 50000,
		effects = { offlineBonus = 0.07 },
		look = { attach = "back" },
	})
	add({
		id = "angel_wings",
		displayName = "Melek Kanatları",
		icon = "🧥",
		slot = "back",
		price = 300000,
		effects = { incomeBonus = 0.05, movementSpeed = 0.06 },
		look = { attach = "back" },
	})
	add({
		id = "golden_wings",
		displayName = "Altın Kanatlar",
		icon = "🧥",
		slot = "back",
		price = 1600000,
		noCash = true,
		effects = { movementSpeed = 0.12, incomeBonus = 0.08, offlineBonus = 0.1 },
		look = { attach = "back" },
	})

	-- Ahır ve sipariş muskaları: ahır siparişi ödülünü ya da ürün merkezi verimini artırır
	add({
		id = "barn_charm_1",
		displayName = "Ambar Anahtarı",
		icon = "📿",
		slot = "charm",
		price = 90000,
		effects = { goodsYield = 0.1, offlineBonus = 0.05 },
		look = { attach = "chest" },
	})
	add({
		id = "barn_charm_2",
		displayName = "Altın Ambar Anahtarı",
		icon = "📿",
		slot = "charm",
		price = 700000,
		effects = { goodsYield = 0.25, offlineBonus = 0.12 },
		look = { attach = "chest" },
	})
	add({
		id = "contract_charm_1",
		displayName = "Tüccar Defteri",
		icon = "📿",
		slot = "charm",
		price = 120000,
		effects = { contractBonus = 0.06, sellBonus = 0.03 },
		look = { attach = "chest" },
	})
	add({
		id = "contract_charm_2",
		displayName = "Usta Tüccar Defteri",
		icon = "📿",
		slot = "charm",
		price = 800000,
		effects = { contractBonus = 0.17, sellBonus = 0.08 },
		look = { attach = "chest" },
	})

	-- Yeni başlıklar (ticari etki)
	add({
		id = "beanie",
		displayName = "Bere",
		icon = "🎩",
		slot = "head",
		price = 12000,
		effects = { offlineBonus = 0.03 },
		look = { attach = "head" },
	})
	add({
		id = "straw_hat",
		displayName = "Hasır Şapka",
		icon = "🎩",
		slot = "head",
		price = 20000,
		effects = { storageBonus = 0.05 },
		look = { attach = "head" },
	})
	add({
		id = "flower_crown",
		displayName = "Çiçek Tacı",
		icon = "🎩",
		slot = "head",
		price = 45000,
		effects = { growthSpeed = 1.08 },
		look = { attach = "head" },
	})

	-- Yeni sırt eşyaları (lojistik etki)
	add({
		id = "harvest_basket",
		displayName = "Hasat Sepeti",
		icon = "🧥",
		slot = "back",
		price = 25000,
		effects = { goodsYield = 0.03 },
		look = { attach = "back" },
	})
	add({
		id = "leaf_cloak",
		displayName = "Yaprak Pelerin",
		icon = "🧥",
		slot = "back",
		price = 90000,
		effects = { growthSpeed = 1.08, offlineBonus = 0.02 },
		look = { attach = "back" },
	})
	add({
		id = "peacock_tail",
		displayName = "Tavus Kuyruğu",
		icon = "🧥",
		slot = "back",
		price = 500000,
		effects = { contractBonus = 0.06, goodsYield = 0.03 },
		look = { attach = "back" },
	})

	-- Uzman ekipmanları: aynı yuvada gelir yerine üretim, ticaret veya çevrimdışı oyun seçilir.
	add({
		id = "artisan_hammer",
		displayName = "Atölye Çekici",
		icon = "🔨",
		slot = "tool",
		price = 1600000,
		noCash = true,
		-- Ölçüm: yalnız genişleme+tesis hızı ideal R5'te %3,7 idi; upgradeDiscount eklendi (0,10 -> ~%11,7).
		effects = { upgradeDiscount = 0.1, expansionDiscount = 0.18, facilitySpeed = 0.18 },
		look = { attach = "hip" },
	})
	add({
		id = "artisan_staff",
		displayName = "Üretim Asası",
		icon = "🪄",
		slot = "staff",
		price = 1800000,
		noCash = true,
		effects = { facilitySpeed = 0.18, goodsYield = 0.12 },
		power = { kind = "rush", usesPerDay = 3 },
		look = { attach = "hand" },
	})
	add({
		id = "night_charm",
		displayName = "Gece Nöbeti Muskası",
		icon = "📿",
		slot = "charm",
		price = 900000,
		effects = { offlineBonus = 0.25, contractBonus = 0.05 }, -- ölçüm: 0,45 casual'da %25 (450 altın) tek başına fazlaydı
		look = { attach = "chest" },
	})
	add({
		id = "logistics_charm",
		displayName = "Lojistik Muskası",
		icon = "📿",
		slot = "charm",
		price = 1800000,
		noCash = true,
		effects = { movementSpeed = 0.06, storageBonus = 0.7, goodsYield = 0.12, offlineBonus = 0.1 },
		look = { attach = "chest" },
	})
	add({
		id = "orchard_charm",
		displayName = "Filiz Muskası",
		icon = "📿",
		slot = "charm",
		price = 1500000,
		noCash = true,
		effects = { growthSpeed = 1.5, sellBonus = 0.06 },
		look = { attach = "chest" },
	})
	add({
		id = "merchant_hat",
		displayName = "Tüccar Şapkası",
		icon = "🎩",
		slot = "head",
		price = 350000,
		effects = { incomeBonus = 0.04, contractBonus = 0.1, sellBonus = 0.08 }, -- ölçüm: contractBonus tek başına ~0, gelir eklendi
		look = { attach = "head" },
	})
	add({
		id = "expedition_pack",
		displayName = "Keşif Çantası",
		icon = "🧥",
		slot = "back",
		price = 1800000,
		noCash = true,
		effects = { movementSpeed = 0.08, offlineBonus = 0.2, storageBonus = 0.25 },
		look = { attach = "back" },
	})
	add({
		id = "artisan_cape",
		displayName = "Atölye Pelerini",
		icon = "🧥",
		slot = "back",
		price = 1300000,
		effects = { movementSpeed = 0.04, facilitySpeed = 0.08, goodsYield = 0.08 },
		look = { attach = "back" },
	})
	add({
		id = "trade_charm",
		displayName = "Pazarlık Muskası",
		icon = "📿",
		slot = "charm",
		price = 2500000,
		noCash = true,
		effects = { incomeBonus = 0.06, contractBonus = 0.25, sellBonus = 0.12 }, -- gelir eklendi (sipariş payı ~%5, tek başına ölü)
		tradeoffs = { goodsYield = 0.06 },
		look = { attach = "chest" },
	})
	add({
		id = "warehouse_pack",
		displayName = "Ambar Çantası",
		icon = "🧥",
		slot = "back",
		price = 2600000,
		noCash = true,
		effects = { storageBonus = 0.6, offlineBonus = 0.2 },
		tradeoffs = { facilitySpeed = 0.05 },
		look = { attach = "back" },
	})
	add({
		id = "breeder_staff",
		displayName = "Yetiştirici Asası",
		icon = "🪄",
		slot = "staff",
		price = 1300000,
		effects = { growthSpeed = 1.3, goodsYield = 0.08 },
		tradeoffs = { offlineBonus = 0.15 },
		power = { kind = "growth", usesPerDay = 3 },
		look = { attach = "hand" },
	})
	-- Yalnız altınla alınan ekipmanlar (noCash, Robux kimliği yok): fiyat yalnızca değer/sıralama referansıdır.
	-- Her biri kendi yuvasında benzersiz bir rol taşır ve üst sınırların (hız %25, gelir x3) altında kalır.
	add({
		id = "foreman_mallet",
		displayName = "Ustabaşı Tokmağı",
		icon = "🔨",
		slot = "tool",
		price = 3000000,
		noCash = true,
		effects = { upgradeDiscount = 0.17, expansionDiscount = 0.14, facilitySpeed = 0.12 },
		look = { attach = "hip" },
	})
	add({
		id = "fortune_charm",
		displayName = "Servet Tılsımı",
		icon = "📿",
		slot = "charm",
		price = 4000000,
		noCash = true,
		effects = { incomeBonus = 0.08, offlineBonus = 0.3 },
		look = { attach = "chest" },
	})
	add({
		id = "tycoon_crown",
		displayName = "Tüccar Tacı",
		icon = "🎩",
		slot = "head",
		price = 5500000,
		noCash = true,
		effects = { incomeBonus = 0.08, contractBonus = 0.18, sellBonus = 0.14 }, -- gelir eklendi (yalnız-altın başlık)
		look = { attach = "head" },
	})
	add({
		id = "caravan_satchel",
		displayName = "Kervan Çantası",
		icon = "🧥",
		slot = "back",
		price = 3800000,
		noCash = true,
		effects = { storageBonus = 0.6, goodsYield = 0.15, movementSpeed = 0.03, offlineBonus = 0.1 }, -- depo/üretim tek başına ölü: çevrimdışı eklendi
		look = { attach = "back" },
	})
	add({
		id = "eternal_shepherd_staff",
		displayName = "Ebedi Çoban Asası",
		icon = "🪄",
		slot = "staff",
		price = 4500000,
		noCash = true,
		effects = { facilitySpeed = 0.12, offlineBonus = 0.25 },
		power = { kind = "collect" },
		look = { attach = "hand" },
	})
	-- Yeni rebirth ödülleri (R9/R15/R21/R27): kendi yuvalarındaki satılık ekipmandan güçlü, R30 ödüllerinden (Ustalık Tacı,
	-- Gece Pelerini) zayıftır. Fiyat 1 yalnız referanstır; satılmaz. Kanat merdiveni: Melek .06 < Kristal .09 < Altın .12 < Anka .15.
	add({
		id = "lucky_clover",
		displayName = "Şans Yoncası",
		icon = "📿",
		slot = "charm",
		price = 1,
		rewardOnly = true,
		effects = { incomeBonus = 0.06, sellBonus = 0.12, contractBonus = 0.1, goodsYield = 0.05 },
		look = { attach = "chest" },
	})
	add({
		id = "harvest_sickle",
		displayName = "Hasat Orağı",
		icon = "🔨",
		slot = "tool",
		price = 1,
		rewardOnly = true,
		effects = { upgradeDiscount = 0.13, expansionDiscount = 0.1, sellBonus = 0.06 },
		look = { attach = "hip" },
	})
	add({
		id = "victory_laurel",
		displayName = "Zafer Çelengi",
		icon = "🎩",
		slot = "head",
		price = 1,
		rewardOnly = true,
		effects = { incomeBonus = 0.08, contractBonus = 0.14, sellBonus = 0.12 },
		look = { attach = "head" },
	})
	add({
		id = "phoenix_wings",
		displayName = "Anka Kanatları",
		icon = "🧥",
		slot = "back",
		price = 1,
		rewardOnly = true,
		effects = { movementSpeed = 0.15, incomeBonus = 0.1, offlineBonus = 0.2 },
		look = { attach = "back" },
	})
	-- Yeni yalnız-altın ekipmanlar (noCash, Robux kimliği yok). Kristal Kanatlar fiyatı Altın Kanatlar'ın (1,6M) hemen altında
	-- ve Atölye Pelerini'nin (1,3M) üstündedir: kanat merdiveni ile slot içi fiyat-güç sırası birlikte korunur.
	add({
		id = "crystal_wings",
		displayName = "Kristal Kanatlar",
		icon = "🧥",
		slot = "back",
		price = 1550000,
		noCash = true,
		effects = { movementSpeed = 0.09, incomeBonus = 0.06, storageBonus = 0.16 },
		look = { attach = "back" },
	})
	add({
		id = "engineer_wrench",
		displayName = "Mühendis Anahtarı",
		icon = "🔨",
		slot = "tool",
		price = 2700000,
		noCash = true,
		effects = { upgradeDiscount = 0.16, expansionDiscount = 0.1, facilitySpeed = 0.1 },
		look = { attach = "hip" },
	})
	add({
		id = "scholar_charm",
		displayName = "Bilge Tılsımı",
		icon = "📿",
		slot = "charm",
		price = 2200000,
		noCash = true,
		effects = { incomeBonus = 0.05, growthSpeed = 1.6, facilitySpeed = 0.12, goodsYield = 0.05 }, -- büyüme R5'te doygun: gelir eklendi
		look = { attach = "chest" },
	})
	add({
		id = "captain_hat",
		displayName = "Kaptan Şapkası",
		icon = "🎩",
		slot = "head",
		price = 2400000,
		noCash = true,
		effects = { incomeBonus = 0.04, contractBonus = 0.14, sellBonus = 0.1, goodsYield = 0.04 }, -- gelir eklendi (ölü yük)
		look = { attach = "head" },
	})
	add({
		id = "courier_pack",
		displayName = "Ulak Çantası",
		icon = "🧥",
		slot = "back",
		price = 2000000,
		noCash = true,
		effects = { movementSpeed = 0.06, storageBonus = 0.5, goodsYield = 0.08, offlineBonus = 0.05 }, -- depo/üretim tek başına ölü: çevrimdışı eklendi
		look = { attach = "back" },
	})
	add({
		id = "merchant_seal",
		displayName = "Tüccar Mührü",
		icon = "📿",
		slot = "charm",
		price = 3200000,
		noCash = true,
		effects = { contractBonus = 0.2, sellBonus = 0.15, offlineBonus = 0.1 },
		look = { attach = "chest" },
	})
	-- Başarım ekipmanları para ile satılmaz; tek yuvayı kullanarak diğer ekipmanlardan vazgeçmeyi gerektirir.
	add({
		id = "pioneer_hammer",
		displayName = "Öncü Çekici",
		icon = "🔨",
		slot = "tool",
		price = 1,
		rewardOnly = true,
		effects = { upgradeDiscount = 0.08, expansionDiscount = 0.08 },
		look = { attach = "hip" },
	})
	add({
		id = "caretaker_staff",
		displayName = "Bakıcı Asası",
		icon = "🪄",
		slot = "staff",
		price = 1,
		rewardOnly = true,
		effects = { growthSpeed = 1.25, facilitySpeed = 0.1 },
		power = { kind = "care", usesPerDay = 2 },
		look = { attach = "hand" },
	})
	add({
		id = "harbor_charm",
		displayName = "Liman Muskası",
		icon = "📿",
		slot = "charm",
		price = 1,
		rewardOnly = true,
		effects = { goodsYield = 0.2, contractBonus = 0.12 },
		look = { attach = "chest" },
	})
	add({
		id = "night_cape",
		displayName = "Gece Pelerini",
		icon = "🧥",
		slot = "back",
		price = 1,
		rewardOnly = true,
		effects = { offlineBonus = 0.3, storageBonus = 0.3 },
		look = { attach = "back" },
	})
	add({
		id = "master_crown",
		displayName = "Ustalık Tacı",
		icon = "🎩",
		slot = "head",
		price = 1,
		rewardOnly = true,
		effects = { incomeBonus = 0.25, contractBonus = 0.15 },
		look = { attach = "head" },
	})
end

return Items
