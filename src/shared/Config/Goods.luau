--!strict
-- Ürünler (ahır deposu): ürün merkezlerinde (fabrikalar) üretilir, ahırdaki depoda birikir.
-- Ahır siparişleri (GOODS_CONTRACTS) bu depoyu tüketir; `value` bir birimin para değeridir (dengeleme ve sipariş ödülü).
-- Gizli bilgi koyma: ReplicatedStorage client'a da gider.

local Types = require(script.Parent:WaitForChild("Types"))
return {
	GOODS = {
		milk = { id = "milk", displayName = "Süt", icon = "🥛", animalId = "cow", value = 25 },
		egg = { id = "egg", displayName = "Yumurta", icon = "🥚", animalId = "chicken", value = 12 },
		down = { id = "down", displayName = "Tüy", icon = "🪶", animalId = "duck", value = 30 },
		cheese = { id = "cheese", displayName = "Peynir", icon = "🧀", animalId = "goat", value = 70 },
		wool = { id = "wool", displayName = "Yün", icon = "🧶", animalId = "sheep", value = 100 },
		meat = { id = "meat", displayName = "Et", icon = "🥩", animalId = "pig", value = 185 },
		horseshoe = { id = "horseshoe", displayName = "Nal", icon = "🧲", animalId = "horse", value = 85 },
		fish = { id = "fish", displayName = "Balık", icon = "🐟", animalId = "seabass", value = 35 },
	} :: { [string]: Types.GoodConfig },

	-- Depo ve arayüzde gösterim sırası (hayvan türlerinin sırasıyla aynı)
	GOODS_ORDER = { "milk", "egg", "down", "cheese", "wool", "meat", "horseshoe", "fish" },

	-- Ahır siparişleri: pano `seconds` saniyede bir yenilenir; 3 kademe (1/2/3 ürün çeşidi). Ürün merkezi zaten kaçırılan gelirin
	-- üstünde ürün verdiği için çarpan küçüktür; büyük sipariş ürün başına daha çok öder (daha çok çeşit = daha çok emek).
	GOODS_CONTRACTS = {
		seconds = 600,
		tiers = {
			{ id = "small", displayName = "Küçük", lines = 1, units = 10, rewardFactor = 1.1 },
			{ id = "medium", displayName = "Orta", lines = 2, units = 16, rewardFactor = 1.25 },
			{ id = "large", displayName = "Büyük", lines = 3, units = 24, rewardFactor = 1.5 },
		} :: { Types.GoodsContractTierConfig },
	},
}
