--!strict
-- Eşya tanımları. Fiyatlar toplam yükseltme harcamasına (≈12 milyon) ve gelir tempo hedeflerine göre ayarlıdır:
-- çekiç indirimleri, ilk saatte alınırsa büyük tasarruf sağlar; pahalı kademeler geç oyun içindir.
-- Tanımları `items` ve `order` tablolarına ekler (Config.ITEMS / Config.ITEM_ORDER).

local Types = require(script.Parent:WaitForChild("Types"))

local Items = {}

function Items.install(items: { [string]: Types.ItemConfig }, order: { string })
	local function add(item: Types.ItemConfig)
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
		effects = { upgradeDiscount = 0.15, expansionDiscount = 0.09, sellBonus = 0.08, facilitySpeed = 0.05 },
		look = { attach = "hip" },
	})
	add({
		id = "diamond_hammer",
		displayName = "Elmas Çekiç",
		icon = "🔨",
		slot = "tool",
		price = 2500000,
		effects = {
			movementSpeed = 0.02,
			upgradeDiscount = 0.2,
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
		effects = { contractBonus = 0.02 },
		power = { kind = "season", usesPerDay = 1 },
		look = { attach = "hand" },
	})
	add({
		id = "season_staff_3",
		displayName = "Usta Mevsim Asası",
		icon = "🪄",
		slot = "staff",
		price = 600000,
		effects = { contractBonus = 0.04 },
		power = { kind = "season", usesPerDay = 3 },
		look = { attach = "hand" },
	})
	add({
		id = "season_staff_5",
		displayName = "Büyücü Mevsim Asası",
		icon = "🪄",
		slot = "staff",
		price = 1500000,
		effects = { contractBonus = 0.06 },
		power = { kind = "season", usesPerDay = 5 },
		look = { attach = "hand" },
	})
	add({
		id = "season_staff_inf",
		displayName = "Ebedi Mevsim Asası",
		icon = "🪄",
		slot = "staff",
		price = 6000000,
		effects = { movementSpeed = 0.03, contractBonus = 0.1 },
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
		look = { attach = "hand" },
	})
	add({
		id = "weather_staff_3",
		displayName = "Usta Çoban Asası",
		icon = "🪄",
		slot = "staff",
		price = 400000,
		effects = { facilitySpeed = 0.05, offlineBonus = 0.08 },
		look = { attach = "hand" },
	})
	add({
		id = "weather_staff_5",
		displayName = "Üstat Çoban Asası",
		icon = "🪄",
		slot = "staff",
		price = 1000000,
		effects = { facilitySpeed = 0.07, offlineBonus = 0.1, expansionDiscount = 0.04 },
		look = { attach = "hand" },
	})
	add({
		id = "weather_staff_inf",
		displayName = "Ebedi Hava Asası",
		icon = "🪄",
		slot = "staff",
		price = 4000000,
		effects = { movementSpeed = 0.03, goodsYield = 0.1 },
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
		effects = { storageBonus = 0.35, offlineBonus = 0.2 },
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
		effects = { goodsYield = 0.03 },
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
		effects = { movementSpeed = 0.03, incomeBonus = 1, sellBonus = 0.04 },
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
		price = 250000,
		effects = { incomeBonus = 0.05 },
		look = { attach = "back" },
	})
	add({
		id = "golden_wings",
		displayName = "Altın Kanatlar",
		icon = "🧥",
		slot = "back",
		price = 1000000,
		effects = { movementSpeed = 0.1, incomeBonus = 0.06, offlineBonus = 0.1 },
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
		effects = { contractBonus = 0.14, sellBonus = 0.07 },
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
		effects = { growthSpeed = 1.08 },
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
		effects = { expansionDiscount = 0.18, facilitySpeed = 0.18 },
		look = { attach = "hip" },
	})
	add({
		id = "artisan_staff",
		displayName = "Üretim Asası",
		icon = "🪄",
		slot = "staff",
		price = 1200000,
		effects = { facilitySpeed = 0.18, goodsYield = 0.12 },
		look = { attach = "hand" },
	})
	add({
		id = "night_charm",
		displayName = "Gece Nöbeti Muskası",
		icon = "📿",
		slot = "charm",
		price = 900000,
		effects = { offlineBonus = 0.45, contractBonus = 0.05 },
		look = { attach = "chest" },
	})
	add({
		id = "logistics_charm",
		displayName = "Lojistik Muskası",
		icon = "📿",
		slot = "charm",
		price = 1800000,
		effects = { movementSpeed = 0.04, storageBonus = 0.6, goodsYield = 0.08 },
		look = { attach = "chest" },
	})
	add({
		id = "orchard_charm",
		displayName = "Filiz Muskası",
		icon = "📿",
		slot = "charm",
		price = 1500000,
		effects = { growthSpeed = 1.5, sellBonus = 0.06 },
		look = { attach = "chest" },
	})
	add({
		id = "merchant_hat",
		displayName = "Tüccar Şapkası",
		icon = "🎩",
		slot = "head",
		price = 350000,
		effects = { contractBonus = 0.1, sellBonus = 0.08 },
		look = { attach = "head" },
	})
	add({
		id = "expedition_pack",
		displayName = "Keşif Çantası",
		icon = "🧥",
		slot = "back",
		price = 1800000,
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
		effects = { contractBonus = 0.25, sellBonus = 0.05 },
		tradeoffs = { goodsYield = 0.1 },
		look = { attach = "chest" },
	})
	add({
		id = "warehouse_pack",
		displayName = "Ambar Çantası",
		icon = "🧥",
		slot = "back",
		price = 2600000,
		effects = { storageBonus = 0.5, offlineBonus = 0.15 },
		tradeoffs = { facilitySpeed = 0.05 },
		look = { attach = "back" },
	})
	add({
		id = "breeder_staff",
		displayName = "Yetiştirici Asası",
		icon = "🪄",
		slot = "staff",
		price = 900000,
		effects = { growthSpeed = 1.3, goodsYield = 0.08 },
		tradeoffs = { offlineBonus = 0.15 },
		look = { attach = "hand" },
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
