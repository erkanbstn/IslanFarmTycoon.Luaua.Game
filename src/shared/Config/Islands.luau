--!strict
-- Büyüme süreleri, ahır seviyeleri, adalar, temalar ve yol haritası aşamaları.
-- Gizli bilgi koyma: ReplicatedStorage client'a da gider.

local Types = require(script.Parent:WaitForChild("Types"))
local Species = require(script.Parent:WaitForChild("Species"))

local data = {
	-- Bir hayvanın her evrede kaldığı süre (saniye). Yetişkin olunca tam gelir verir.
	GROWTH_SECONDS = {
		calf = 800,
		young = 1600,
	},

	-- Büyüme hızı birleşimi (FarmMath.getGrowthSpeed): her kaynağın artısı (çarpan - 1) TOPLANIR; toplam artı
	-- GROWTH_SPEED_KNEE'ye kadar aynen geçer (yem silosu tek başına tam 2 kat), üstü azalan getiriyle sıkışır ve toplam
	-- hız GROWTH_SPEED_CAP'e yaklaşır ama hiç ulaşmaz. Her yeni geliştirme hep biraz daha hızlandırır, büyüme anlık olmaz.
	GROWTH_SPEED_KNEE = 1,
	GROWTH_SPEED_CAP = 4,

	BARN_LEVELS = {
		{
			level = 1,
			displayName = "Küçük Ahır",
			barnScale = 1,
			storageCap = 50000,
			goodsCap = 12,
			incomeMultiplier = 1,
		},
		{
			level = 2,
			displayName = "Genişletilmiş Ahır",
			barnScale = 1.2,
			storageCap = 120000,
			goodsCap = 24,
			incomeMultiplier = 1.2,
		},
		{
			level = 3,
			displayName = "Çiftlik Ahırı",
			barnScale = 1.45,
			storageCap = 300000,
			goodsCap = 48,
			incomeMultiplier = 1.4,
		},
		{
			level = 4,
			displayName = "Büyük Çiftlik",
			barnScale = 1.7,
			storageCap = 1000000,
			goodsCap = 96,
			incomeMultiplier = 1.7,
		},
	} :: { Types.BarnLevelConfig },

	-- Bütün ada türleri; hangi çiftlikte hangilerinin olduğunu THEMES belirler.
	FARM_ISLAND_ORDER = { "home", "poultry", "horse", "goat", "sheep", "pig" },

	FARM_ISLANDS = {
		home = {
			id = "home",
			displayName = "Ana Ada",
			icon = "🐄",
			trait = "İnek çiftliğin ve ahırın burada",
		},
		poultry = {
			id = "poultry",
			displayName = "Tavuk Adası",
			icon = "🐔",
			trait = "Yumurta hattı: üretim tesisleri %12 daha hızlı",
			upgradeId = "island_poultry",
			animalId = "chicken",
			buildUpgradeId = "egg_factory",
			itemUpgradeId = "egg_center",
		},
		horse = {
			id = "horse",
			displayName = "At Adası",
			icon = "🐎",
			trait = "Tüccar yolu: ahır siparişi ödülü +%8",
			upgradeId = "island_horse",
			animalId = "horse",
			buildUpgradeId = "golden_horseshoe",
			itemUpgradeId = "horseshoe_forge",
		},
		goat = {
			id = "goat",
			displayName = "Keçi Adası",
			icon = "🐐",
			trait = "Dağ havası: çevrimdışı kazanç +%25",
			upgradeId = "island_goat",
			animalId = "goat",
			buildUpgradeId = "cheese_dairy",
			itemUpgradeId = "cheese_cellar",
		},
		sheep = {
			id = "sheep",
			displayName = "Koyun Adası",
			icon = "🐑",
			trait = "Yün ticareti: ürün merkezi verimi +%10",
			upgradeId = "island_sheep",
			animalId = "sheep",
			buildUpgradeId = "wool_mill",
			itemUpgradeId = "wool_loom",
		},
		pig = {
			id = "pig",
			displayName = "Domuz Adası",
			icon = "🐖",
			trait = "Trüf ormanı: geliştirme maliyetleri -%8",
			upgradeId = "island_pig",
			animalId = "pig",
			buildUpgradeId = "truffle_kitchen",
			itemUpgradeId = "meat_smokehouse",
		},
	} :: { [string]: Types.FarmIslandConfig },

	-- Temalar: dizi sırası = ana çiftlik numarası = fiziksel ada numarası = zorluk kademesi (Çiftlik 1 her zaman Papatya).
	-- Her çiftlik = ana ada + 3 küçük ada; HER ADADA TEK HAYVAN yaşar ve hiçbir hayvan iki çiftlikte yoktur (24 benzersiz tür; test: config.spec).
	-- satellites sırası = erken (Ahır Sv.2) / orta (Sv.3) / geç (Sv.4) ada = harita yuvası sırası. Hayvan -> ada -> çiftlik eşlemesi tek yerde: burası
	-- (homeAnimal + satellites) ve FARM_ISLANDS[ada].animalId. Tasarım ve ürün zinciri: docs/ADA_TASARIMI.md.
	THEMES = {
		{
			id = "papatya",
			landmark = "daisy",
			displayName = "Klasik Çayır",
			homeAnimal = "cow",
			satellites = { "poultry", "horse", "goat" },
		},
		{
			id = "lale",
			landmark = "tulip",
			displayName = "Göl ve Yün",
			homeAnimal = "duck",
			satellites = { "rabbit", "sheep", "pig" },
			fish = {
				anchovy = { id = "red_mullet", displayName = "Barbun", icon = "🐟", product = "Taze barbun" },
				seabass = { id = "sea_bream", displayName = "Çipura", icon = "🐠", product = "Çipura" },
			},
		},
		{
			id = "aycicegi",
			landmark = "sunflower",
			displayName = "Güneşli Tarla",
			homeAnimal = "turkey",
			satellites = { "bee", "camel", "peacock" },
			fish = {
				anchovy = { id = "sardine", displayName = "Sardalya", icon = "🐟", product = "Taze sardalya" },
				seabass = { id = "bluefish", displayName = "Lüfer", icon = "🐠", product = "Lüfer" },
			},
		},
		{
			id = "gul",
			landmark = "rose",
			displayName = "Gül Vadisi",
			homeAnimal = "buffalo",
			satellites = { "quail", "pigeon", "snail" },
			fish = {
				anchovy = { id = "whiting", displayName = "Mezgit", icon = "🐟", product = "Taze mezgit" },
				seabass = { id = "turbot", displayName = "Kalkan", icon = "🐠", product = "Kalkan" },
			},
		},
		{
			id = "yonca",
			landmark = "pine",
			displayName = "Dağ ve Orman",
			homeAnimal = "yak",
			satellites = { "llama", "deer", "falcon" },
			fish = {
				anchovy = { id = "trout", displayName = "Alabalık", icon = "🐟", product = "Taze alabalık" },
				seabass = { id = "salmon", displayName = "Somon", icon = "🐠", product = "Somon" },
			},
		},
		{
			id = "kiraz",
			landmark = "cherry",
			displayName = "Meyve Bahçesi",
			homeAnimal = "squirrel",
			satellites = { "silkworm", "parrot", "tortoise" },
			fish = {
				anchovy = { id = "koi", displayName = "Koi", icon = "🎏", product = "Koi" },
				seabass = { id = "tuna", displayName = "Orkinos", icon = "🐠", product = "Orkinos" },
			},
		},
	} :: { Types.ThemeConfig },

	-- Yol haritası aşamaları: adalar + onlarla paralel ilerleyen Deniz dalı
	ROADMAP_STAGES = {
		{ name = "Ana Ada", island = "home" },
		{ name = "Deniz", description = "Balık kafesinde küçük ve büyük balık yetiştir" },
		{ name = "Tavuk Adası", island = "poultry" },
		{ name = "At Adası", island = "horse" },
		{ name = "Keçi Adası", island = "goat" },
		{ name = "Koyun Adası", island = "sheep" },
		{ name = "Domuz Adası", island = "pig" },
	} :: { Types.RoadmapStage },
}

-- Hayvan türü tablosundan gelen adalar ve yol haritası aşamaları (Config/Species.luau)
assert(
	#data.ROADMAP_STAGES == Species.BASE_STAGES,
	"Species.BASE_STAGES elle yazılan yol haritası aşamalarıyla uyuşmuyor"
)
local species = Species.get()
for id, island in species.islands do
	data.FARM_ISLANDS[id] = island
end
for _, id in species.islandOrder do
	table.insert(data.FARM_ISLAND_ORDER, id)
end
for _, stage in species.stages do
	table.insert(data.ROADMAP_STAGES, stage)
end

return data
