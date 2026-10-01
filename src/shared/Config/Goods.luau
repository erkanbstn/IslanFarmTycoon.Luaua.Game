--!strict
-- Ürünler (ahır deposu): ürün merkezlerinde (fabrikalar) üretilir, ahırdaki depoda birikir.
-- Ahır siparişleri (GOODS_CONTRACTS) bu depoyu tüketir; `value` bir birimin para değeridir (dengeleme ve sipariş ödülü).
-- Gizli bilgi koyma: ReplicatedStorage client'a da gider.

local Types = require(script.Parent:WaitForChild("Types"))
return {
	GOODS = {
		milk = { id = "milk", displayName = "Süt", icon = "🥛", animalId = "cow", value = 250 },
		egg = { id = "egg", displayName = "Yumurta", icon = "🥚", animalId = "chicken", value = 480 },
		down = { id = "down", displayName = "Tüy", icon = "🪶", animalId = "duck", value = 800 },
		cheese = { id = "cheese", displayName = "Peynir", icon = "🧀", animalId = "goat", value = 5500 },
		wool = { id = "wool", displayName = "Yün", icon = "🧶", animalId = "sheep", value = 2000 },
		meat = { id = "meat", displayName = "Et", icon = "🥩", animalId = "pig", value = 9000 },
		horseshoe = { id = "horseshoe", displayName = "Nal", icon = "🧲", animalId = "horse", value = 1300 },
		fish = { id = "fish", displayName = "Balık", icon = "🐟", animalId = "seabass", value = 500 },
	} :: { [string]: Types.GoodConfig },

	-- Depo ve arayüzde gösterim sırası (hayvan türlerinin sırasıyla aynı)
	GOODS_ORDER = { "milk", "egg", "down", "cheese", "wool", "meat", "horseshoe", "fish" },

	-- Ahır siparişleri: pano `seconds` saniyede bir yenilenir; 6 kademe (1-4 ürün çeşidi; "toptan" tek üründen çok ister). Ürün merkezi zaten kaçırılan gelirin
	-- üstünde ürün verdiği için çarpan küçüktür; büyük sipariş ürün başına daha çok öder (daha çok çeşit = daha çok emek).
	GOODS_CONTRACTS = {
		seconds = 600,
		-- Pano ızgara biçimindedir: her pencerede `slots` teklif, her biri ağırlıklı rastgele kademe + rastgele ürünler
		-- (pencere numarası ve sıra ile türetilir; sunucu ve client aynı sonucu bulur). Birim sayısı kademe değerinin
		-- ± variation oranında değişir.
		slots = 9,
		variation = 0.34,
		-- Ödül tabanı: etkin çiftliğin geliri x bu süre (sn). Ödül = max(ürün değeri, taban) x kademe çarpanı x bonus.
		incomeSeconds = 60,
		tiers = {
			{ id = "quick", displayName = "Hızlı", lines = 1, units = 2, rewardFactor = 1.05, weight = 3 },
			{ id = "small", displayName = "Küçük", lines = 1, units = 3, rewardFactor = 1.1, weight = 3 },
			{ id = "medium", displayName = "Orta", lines = 2, units = 3, rewardFactor = 1.25, weight = 2 },
			{ id = "bulk", displayName = "Toptan", lines = 1, units = 6, rewardFactor = 1.3, weight = 1.5 },
			{ id = "large", displayName = "Büyük", lines = 3, units = 4, rewardFactor = 1.5, weight = 1 },
			{ id = "grand", displayName = "Dev", lines = 4, units = 3, rewardFactor = 1.7, weight = 0.7 },
		} :: { Types.GoodsContractTierConfig },
	},
}
