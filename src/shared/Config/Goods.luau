--!strict
-- Ürünler (ahır deposu): ürün merkezlerinde (fabrikalar) üretilir, ahırdaki depoda birikir.
-- Sipariş sistemi bu depoyu tüketecek; `value` bir birimin para değeridir (dengeleme ve ileride sipariş ödülü).
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
}
