--!strict
-- Eşya tanımları. Fiyatlar toplam yükseltme harcamasına (≈12 milyon) ve gelir tempo hedeflerine göre ayarlıdır:
-- çekiç indirimleri, ilk saatte alınırsa büyük tasarruf sağlar; pahalı kademeler geç oyun içindir.
-- Tanımları `items` ve `order` tablolarına ekler (Config.ITEMS / Config.ITEM_ORDER).

local Types = require(script.Parent:WaitForChild("Types"))

local Items = {}

function Items.install(items: { [string]: Types.ItemConfig }, order: { string })
	local function block(
		size: { number },
		offset: { number },
		color: Color3,
		material: string?,
		angle: { number }?
	): Types.ItemPart
		return { shape = "Block", size = size, offset = offset, color = color, material = material, angle = angle }
	end
	local function ball(diameter: number, offset: { number }, color: Color3, material: string?): Types.ItemPart
		return {
			shape = "Ball",
			size = { diameter, diameter, diameter },
			offset = offset,
			color = color,
			material = material,
		}
	end
	local WOOD = Color3.fromRGB(120, 85, 55)
	local GOLD = Color3.fromRGB(255, 200, 70)

	local function hammerLook(headColor: Color3, material: string): Types.ItemLook
		return {
			attach = "hip",
			parts = {
				block({ 0.22, 1.8, 0.22 }, { -1.25, -0.6, 0.55 }, WOOD, "Wood", { 0, 0, 25 }),
				block({ 1, 0.6, 0.6 }, { -0.9, 0.35, 0.55 }, headColor, material, { 0, 0, 25 }),
			},
		}
	end
	local function staffLook(orbColor: Color3, rodColor: Color3): Types.ItemLook
		return {
			attach = "hand",
			parts = {
				block({ 0.25, 5, 0.25 }, { 0, 1.8, 0 }, rodColor, "Wood"),
				ball(1, { 0, 4.6, 0 }, orbColor, "Neon"),
				block({ 0.7, 0.18, 0.7 }, { 0, 4, 0 }, GOLD, "Metal"),
			},
		}
	end
	local function charmLook(color: Color3, diameter: number): Types.ItemLook
		return { attach = "chest", parts = { ball(diameter, { 0, 0.6, -0.95 }, color, "Neon") } }
	end

	local function add(item: Types.ItemConfig)
		items[item.id] = item
		table.insert(order, item.id)
	end

	-- Aletler: tüm yükseltme maliyetlerinden kalıcı indirim
	add({
		id = "copper_hammer",
		displayName = "Bakır Çekiç",
		icon = "🔨",
		slot = "tool",
		price = 60000,
		effects = { upgradeDiscount = 0.05, expansionDiscount = 0.03 },
		look = hammerLook(Color3.fromRGB(184, 115, 51), "Metal"),
	})
	add({
		id = "iron_hammer",
		displayName = "Demir Çekiç",
		icon = "🔨",
		slot = "tool",
		price = 250000,
		effects = { upgradeDiscount = 0.1, expansionDiscount = 0.06, sellBonus = 0.05 },
		look = hammerLook(Color3.fromRGB(150, 155, 165), "Metal"),
	})
	add({
		id = "gold_hammer",
		displayName = "Altın Çekiç",
		icon = "🔨",
		slot = "tool",
		price = 800000,
		effects = { upgradeDiscount = 0.15, expansionDiscount = 0.09, sellBonus = 0.08, facilitySpeed = 0.05 },
		look = hammerLook(GOLD, "Neon"),
	})
	add({
		id = "diamond_hammer",
		displayName = "Elmas Çekiç",
		icon = "🔨",
		slot = "tool",
		price = 2000000,
		effects = { upgradeDiscount = 0.2, expansionDiscount = 0.12, sellBonus = 0.12, facilitySpeed = 0.08 },
		look = hammerLook(Color3.fromRGB(110, 220, 255), "Neon"),
	})

	-- Asalar: mevsim ya da hava değiştirme gücü (günlük hak sayısına göre kademeli, en üst kademe sınırsız)
	local seasonOrb, weatherOrb = Color3.fromRGB(120, 230, 120), Color3.fromRGB(110, 180, 255)
	add({
		id = "season_staff_1",
		displayName = "Çırak Mevsim Asası",
		icon = "🪄",
		slot = "staff",
		price = 150000,
		effects = { contractBonus = 0.02 },
		power = { kind = "season", usesPerDay = 1 },
		look = staffLook(seasonOrb, WOOD),
	})
	add({
		id = "season_staff_3",
		displayName = "Usta Mevsim Asası",
		icon = "🪄",
		slot = "staff",
		price = 600000,
		effects = { contractBonus = 0.04 },
		power = { kind = "season", usesPerDay = 3 },
		look = staffLook(seasonOrb, Color3.fromRGB(90, 60, 110)),
	})
	add({
		id = "season_staff_5",
		displayName = "Büyücü Mevsim Asası",
		icon = "🪄",
		slot = "staff",
		price = 1500000,
		effects = { contractBonus = 0.06 },
		power = { kind = "season", usesPerDay = 5 },
		look = staffLook(seasonOrb, Color3.fromRGB(60, 40, 90)),
	})
	add({
		id = "season_staff_inf",
		displayName = "Ebedi Mevsim Asası",
		icon = "🪄",
		slot = "staff",
		price = 6000000,
		effects = { contractBonus = 0.1 },
		power = { kind = "season" },
		look = staffLook(Color3.fromRGB(255, 230, 120), GOLD),
	})
	add({
		id = "weather_staff_1",
		displayName = "Çırak Hava Asası",
		icon = "🪄",
		slot = "staff",
		price = 100000,
		effects = { goodsYield = 0.02 },
		power = { kind = "weather", usesPerDay = 1 },
		look = staffLook(weatherOrb, WOOD),
	})
	add({
		id = "weather_staff_3",
		displayName = "Usta Hava Asası",
		icon = "🪄",
		slot = "staff",
		price = 400000,
		effects = { goodsYield = 0.04 },
		power = { kind = "weather", usesPerDay = 3 },
		look = staffLook(weatherOrb, Color3.fromRGB(60, 90, 130)),
	})
	add({
		id = "weather_staff_5",
		displayName = "Büyücü Hava Asası",
		icon = "🪄",
		slot = "staff",
		price = 1000000,
		effects = { goodsYield = 0.06 },
		power = { kind = "weather", usesPerDay = 5 },
		look = staffLook(weatherOrb, Color3.fromRGB(40, 70, 120)),
	})
	add({
		id = "weather_staff_inf",
		displayName = "Ebedi Hava Asası",
		icon = "🪄",
		slot = "staff",
		price = 4000000,
		effects = { goodsYield = 0.1 },
		power = { kind = "weather" },
		look = staffLook(Color3.fromRGB(200, 240, 255), Color3.fromRGB(220, 235, 250)),
	})

	-- Muskalar: takılıyken kalıcı pasif fayda (yalnızca bir muska takılır: hangisinin seçileceği bir karardır)
	add({
		id = "storage_charm_1",
		displayName = "Depo Muskası",
		icon = "📿",
		slot = "charm",
		price = 40000,
		effects = { storageBonus = 0.15, offlineBonus = 0.1 },
		look = charmLook(Color3.fromRGB(190, 140, 80), 0.6),
	})
	add({
		id = "storage_charm_2",
		displayName = "Büyük Depo Muskası",
		icon = "📿",
		slot = "charm",
		price = 400000,
		effects = { storageBonus = 0.35, offlineBonus = 0.2 },
		look = charmLook(Color3.fromRGB(230, 170, 70), 0.8),
	})
	add({
		id = "growth_charm_1",
		displayName = "Büyüme Muskası",
		icon = "📿",
		slot = "charm",
		price = 50000,
		effects = { growthSpeed = 1.15, facilitySpeed = 0.05 },
		look = charmLook(Color3.fromRGB(110, 210, 110), 0.6),
	})
	add({
		id = "growth_charm_2",
		displayName = "Büyük Büyüme Muskası",
		icon = "📿",
		slot = "charm",
		price = 600000,
		effects = { growthSpeed = 1.4, facilitySpeed = 0.1 },
		look = charmLook(Color3.fromRGB(60, 240, 120), 0.8),
	})
	add({
		id = "income_charm_1",
		displayName = "Bereket Muskası",
		icon = "📿",
		slot = "charm",
		price = 150000,
		effects = { incomeBonus = 0.03, sellBonus = 0.05 },
		look = charmLook(Color3.fromRGB(255, 220, 100), 0.6),
	})
	add({
		id = "income_charm_2",
		displayName = "Büyük Bereket Muskası",
		icon = "📿",
		slot = "charm",
		price = 900000,
		effects = { incomeBonus = 0.06, sellBonus = 0.1 },
		look = charmLook(Color3.fromRGB(255, 200, 60), 0.8),
	})
	add({
		id = "income_charm_3",
		displayName = "Altın Bereket Muskası",
		icon = "📿",
		slot = "charm",
		price = 5000000,
		effects = { incomeBonus = 0.1, sellBonus = 0.15 },
		look = charmLook(Color3.fromRGB(255, 240, 150), 1),
	})

	-- Başlıklar (görünüm)
	local band = Color3.fromRGB(170, 45, 38)
	add({
		id = "farmer_hat",
		displayName = "Çiftçi Şapkası",
		icon = "🎩",
		slot = "head",
		price = 10000,
		look = {
			attach = "head",
			parts = {
				block({ 3, 0.15, 3 }, { 0, 0.55, 0 }, Color3.fromRGB(225, 195, 110), "Fabric"),
				block({ 1.6, 0.8, 1.6 }, { 0, 0.95, 0 }, Color3.fromRGB(225, 195, 110), "Fabric"),
				block({ 1.65, 0.2, 1.65 }, { 0, 0.72, 0 }, band, "Fabric"),
			},
		},
	})
	add({
		id = "flat_cap",
		displayName = "Kasket",
		icon = "🎩",
		slot = "head",
		price = 15000,
		look = {
			attach = "head",
			parts = {
				block({ 1.8, 0.6, 1.8 }, { 0, 0.75, 0 }, Color3.fromRGB(70, 90, 140), "Fabric"),
				block({ 1.5, 0.12, 0.9 }, { 0, 0.5, -1.05 }, Color3.fromRGB(50, 65, 105), "Fabric"),
			},
		},
	})
	add({
		id = "chicken_hat",
		displayName = "Tavuk Şapkası",
		icon = "🎩",
		slot = "head",
		price = 30000,
		look = {
			attach = "head",
			parts = {
				ball(1.7, { 0, 0.85, 0 }, Color3.fromRGB(250, 250, 250), "SmoothPlastic"),
				block({ 0.3, 0.7, 1 }, { 0, 1.6, 0 }, Color3.fromRGB(220, 50, 50), "SmoothPlastic"),
				block({ 0.5, 0.25, 0.5 }, { 0, 0.55, -0.95 }, Color3.fromRGB(250, 190, 50), "SmoothPlastic"),
			},
		},
	})
	add({
		id = "cowboy_hat",
		displayName = "Kovboy Şapkası",
		icon = "🎩",
		slot = "head",
		price = 60000,
		look = {
			attach = "head",
			parts = {
				block({ 3.4, 0.15, 2.6 }, { 0, 0.55, 0 }, Color3.fromRGB(130, 85, 50), "Fabric"),
				block({ 1.7, 1, 1.7 }, { 0, 1.05, 0 }, Color3.fromRGB(130, 85, 50), "Fabric"),
				block({ 1.75, 0.2, 1.75 }, { 0, 0.72, 0 }, Color3.fromRGB(60, 40, 30), "Fabric"),
			},
		},
	})
	add({
		id = "golden_crown",
		displayName = "Altın Taç",
		icon = "🎩",
		slot = "head",
		price = 400000,
		look = {
			attach = "head",
			parts = {
				block({ 1.8, 0.5, 1.8 }, { 0, 0.75, 0 }, GOLD, "Neon"),
				block({ 0.3, 0.6, 0.3 }, { -0.7, 1.25, -0.7 }, GOLD, "Neon"),
				block({ 0.3, 0.6, 0.3 }, { 0.7, 1.25, -0.7 }, GOLD, "Neon"),
				block({ 0.3, 0.6, 0.3 }, { -0.7, 1.25, 0.7 }, GOLD, "Neon"),
				block({ 0.3, 0.6, 0.3 }, { 0.7, 1.25, 0.7 }, GOLD, "Neon"),
				ball(0.5, { 0, 1.05, -0.95 }, Color3.fromRGB(220, 40, 70), "Neon"),
			},
		},
	})

	-- Sırt eşyaları (görünüm)
	add({
		id = "backpack",
		displayName = "Sırt Çantası",
		icon = "🧥",
		slot = "back",
		price = 12000,
		look = {
			attach = "back",
			parts = {
				block({ 1.6, 2, 0.8 }, { 0, 0.2, 0.9 }, Color3.fromRGB(130, 90, 55), "Fabric"),
				block({ 1.2, 0.5, 0.9 }, { 0, 1.2, 0.95 }, Color3.fromRGB(100, 70, 45), "Fabric"),
			},
		},
	})
	add({
		id = "red_cape",
		displayName = "Kırmızı Pelerin",
		icon = "🧥",
		slot = "back",
		price = 50000,
		look = {
			attach = "back",
			parts = { block({ 2.2, 3, 0.15 }, { 0, -0.1, 0.85 }, Color3.fromRGB(190, 40, 50), "Fabric", { 8, 0, 0 }) },
		},
	})
	add({
		id = "angel_wings",
		displayName = "Melek Kanatları",
		icon = "🧥",
		slot = "back",
		price = 250000,
		look = {
			attach = "back",
			parts = {
				block({ 0.2, 2.6, 1.6 }, { -1.2, 0.6, 0.95 }, Color3.fromRGB(250, 250, 255), "Neon", { 0, 25, -15 }),
				block({ 0.2, 2.6, 1.6 }, { 1.2, 0.6, 0.95 }, Color3.fromRGB(250, 250, 255), "Neon", { 0, -25, 15 }),
			},
		},
	})
	add({
		id = "golden_wings",
		displayName = "Altın Kanatlar",
		icon = "🧥",
		slot = "back",
		price = 1000000,
		look = {
			attach = "back",
			parts = {
				block({ 0.25, 3.4, 2.2 }, { -1.4, 0.7, 1 }, GOLD, "Neon", { 0, 25, -15 }),
				block({ 0.25, 3.4, 2.2 }, { 1.4, 0.7, 1 }, GOLD, "Neon", { 0, -25, 15 }),
				block({ 0.2, 2.2, 1.4 }, { -1.1, 0.2, 0.9 }, Color3.fromRGB(255, 235, 150), "Neon", { 0, 25, -15 }),
				block({ 0.2, 2.2, 1.4 }, { 1.1, 0.2, 0.9 }, Color3.fromRGB(255, 235, 150), "Neon", { 0, -25, 15 }),
			},
		},
	})

	-- Ahır ve sipariş muskaları: ahır siparişi ödülünü ya da ürün merkezi verimini artırır
	add({
		id = "barn_charm_1",
		displayName = "Ambar Anahtarı",
		icon = "📿",
		slot = "charm",
		price = 90000,
		effects = { goodsYield = 0.1, offlineBonus = 0.05 },
		look = charmLook(Color3.fromRGB(200, 170, 110), 0.6),
	})
	add({
		id = "barn_charm_2",
		displayName = "Altın Ambar Anahtarı",
		icon = "📿",
		slot = "charm",
		price = 700000,
		effects = { goodsYield = 0.25, offlineBonus = 0.12 },
		look = charmLook(Color3.fromRGB(255, 215, 90), 0.8),
	})
	add({
		id = "contract_charm_1",
		displayName = "Tüccar Defteri",
		icon = "📿",
		slot = "charm",
		price = 120000,
		effects = { contractBonus = 0.06, sellBonus = 0.03 },
		look = charmLook(Color3.fromRGB(120, 170, 235), 0.6),
	})
	add({
		id = "contract_charm_2",
		displayName = "Usta Tüccar Defteri",
		icon = "📿",
		slot = "charm",
		price = 800000,
		effects = { contractBonus = 0.14, sellBonus = 0.07 },
		look = charmLook(Color3.fromRGB(90, 140, 255), 0.8),
	})

	-- Yeni başlıklar
	add({
		id = "beanie",
		displayName = "Bere",
		icon = "🎩",
		slot = "head",
		price = 12000,
		look = {
			attach = "head",
			parts = {
				block({ 1.9, 0.7, 1.9 }, { 0, 0.8, 0 }, Color3.fromRGB(200, 60, 70), "Fabric"),
				ball(0.6, { 0, 1.3, 0 }, Color3.fromRGB(250, 250, 250), "Fabric"),
			},
		},
	})
	add({
		id = "straw_hat",
		displayName = "Hasır Şapka",
		icon = "🎩",
		slot = "head",
		price = 20000,
		look = {
			attach = "head",
			parts = {
				block({ 3.6, 0.12, 3.6 }, { 0, 0.55, 0 }, Color3.fromRGB(232, 205, 120), "Fabric"),
				block({ 1.7, 0.9, 1.7 }, { 0, 0.95, 0 }, Color3.fromRGB(232, 205, 120), "Fabric"),
				block({ 1.75, 0.2, 1.75 }, { 0, 0.72, 0 }, Color3.fromRGB(110, 150, 80), "Fabric"),
			},
		},
	})
	add({
		id = "flower_crown",
		displayName = "Çiçek Tacı",
		icon = "🎩",
		slot = "head",
		price = 45000,
		look = {
			attach = "head",
			parts = {
				block({ 1.9, 0.2, 1.9 }, { 0, 0.6, 0 }, Color3.fromRGB(90, 160, 80), "Grass"),
				ball(0.45, { -0.8, 0.75, -0.8 }, Color3.fromRGB(240, 120, 150), "SmoothPlastic"),
				ball(0.45, { 0.8, 0.75, -0.8 }, Color3.fromRGB(250, 215, 90), "SmoothPlastic"),
				ball(0.45, { -0.8, 0.75, 0.8 }, Color3.fromRGB(250, 215, 90), "SmoothPlastic"),
				ball(0.45, { 0.8, 0.75, 0.8 }, Color3.fromRGB(240, 120, 150), "SmoothPlastic"),
			},
		},
	})

	-- Yeni sırt eşyaları
	add({
		id = "harvest_basket",
		displayName = "Hasat Sepeti",
		icon = "🧥",
		slot = "back",
		price = 25000,
		look = {
			attach = "back",
			parts = {
				block({ 1.8, 1.4, 1 }, { 0, 0.2, 0.95 }, Color3.fromRGB(150, 105, 60), "Wood"),
				block({ 0.12, 1.4, 0.12 }, { -0.45, 1.3, 0.95 }, Color3.fromRGB(235, 200, 90), "Grass", { 0, 0, 10 }),
				block({ 0.12, 1.5, 0.12 }, { 0, 1.4, 0.95 }, Color3.fromRGB(235, 200, 90), "Grass"),
				block({ 0.12, 1.4, 0.12 }, { 0.45, 1.3, 0.95 }, Color3.fromRGB(235, 200, 90), "Grass", { 0, 0, -10 }),
			},
		},
	})
	add({
		id = "leaf_cloak",
		displayName = "Yaprak Pelerin",
		icon = "🧥",
		slot = "back",
		price = 90000,
		look = {
			attach = "back",
			parts = {
				block({ 2.2, 3, 0.12 }, { 0, -0.1, 0.85 }, Color3.fromRGB(80, 150, 70), "Grass", { 8, 0, 0 }),
				block({ 0.8, 1.1, 0.14 }, { -0.6, 0.9, 0.92 }, Color3.fromRGB(120, 190, 100), "Grass", { 8, 0, 20 }),
				block({ 0.8, 1.1, 0.14 }, { 0.6, 0.5, 0.92 }, Color3.fromRGB(120, 190, 100), "Grass", { 8, 0, -20 }),
			},
		},
	})
	add({
		id = "peacock_tail",
		displayName = "Tavus Kuyruğu",
		icon = "🧥",
		slot = "back",
		price = 500000,
		look = {
			attach = "back",
			parts = {
				block({ 0.25, 3, 0.12 }, { -1.3, 1, 0.95 }, Color3.fromRGB(40, 170, 160), "Neon", { 0, 0, 35 }),
				block({ 0.25, 3.4, 0.12 }, { -0.65, 1.3, 0.95 }, Color3.fromRGB(50, 130, 200), "Neon", { 0, 0, 18 }),
				block({ 0.25, 3.6, 0.12 }, { 0, 1.4, 0.95 }, Color3.fromRGB(60, 200, 130), "Neon"),
				block({ 0.25, 3.4, 0.12 }, { 0.65, 1.3, 0.95 }, Color3.fromRGB(50, 130, 200), "Neon", { 0, 0, -18 }),
				block({ 0.25, 3, 0.12 }, { 1.3, 1, 0.95 }, Color3.fromRGB(40, 170, 160), "Neon", { 0, 0, -35 }),
			},
		},
	})
end

return Items
