--!strict
-- Büyüme süreleri, ahır seviyeleri, adalar, temalar ve yol haritası aşamaları.
-- Gizli bilgi koyma: ReplicatedStorage client'a da gider.

local Types = require(script.Parent:WaitForChild("Types"))
return {
	-- Bir hayvanın her evrede kaldığı süre (saniye). Yetişkin olunca tam gelir verir.
	GROWTH_SECONDS = {
		calf = 600,
		young = 1200,
	},

	BARN_LEVELS = {
		{
			level = 1,
			displayName = "Küçük Ahır",
			barnScale = 1,
			storageCap = 10000,
			goodsCap = 60,
			incomeMultiplier = 1,
		},
		{
			level = 2,
			displayName = "Genişletilmiş Ahır",
			barnScale = 1.2,
			storageCap = 24000,
			goodsCap = 120,
			incomeMultiplier = 1.2,
		},
		{
			level = 3,
			displayName = "Çiftlik Ahırı",
			barnScale = 1.45,
			storageCap = 60000,
			goodsCap = 240,
			incomeMultiplier = 1.4,
		},
		{
			level = 4,
			displayName = "Büyük Çiftlik",
			barnScale = 1.7,
			storageCap = 200000,
			goodsCap = 500,
			incomeMultiplier = 1.7,
		},
	} :: { Types.BarnLevelConfig },

	-- Bütün ada türleri; hangi çiftlikte hangilerinin olduğunu THEMES belirler.
	FARM_ISLAND_ORDER = { "home", "dairy", "poultry", "duck", "horse", "sheep", "goat", "pig" },

	FARM_ISLANDS = {
		home = {
			id = "home",
			displayName = "Ana Ada",
			icon = "🐄",
			trait = "İnek çiftliğin ve ahırın burada",
		},
		dairy = {
			id = "dairy",
			displayName = "Süt Adası",
			icon = "🐄",
			trait = "Serin mahzen: depo kapasitesi +%20",
			upgradeId = "island_dairy",
		},
		poultry = {
			id = "poultry",
			displayName = "Tavuk Adası",
			icon = "🐔",
			trait = "Yumurta hattı: üretim tesisleri %12 daha hızlı",
			upgradeId = "island_poultry",
		},
		horse = {
			id = "horse",
			displayName = "At Adası",
			icon = "🐎",
			trait = "Tüccar yolu: ahır siparişi ödülü +%8",
			upgradeId = "island_horse",
		},
		goat = {
			id = "goat",
			displayName = "Keçi Adası",
			icon = "🐐",
			trait = "Dağ havası: çevrimdışı kazanç +%25",
			upgradeId = "island_goat",
		},
		duck = {
			id = "duck",
			displayName = "Ördek Adası",
			icon = "🦆",
			trait = "Göl pazarı: hayvan satış geliri +%15",
			upgradeId = "island_duck",
		},
		sheep = {
			id = "sheep",
			displayName = "Koyun Adası",
			icon = "🐑",
			trait = "Yün ticareti: ürün merkezi verimi +%10",
			upgradeId = "island_sheep",
		},
		pig = {
			id = "pig",
			displayName = "Domuz Adası",
			icon = "🐖",
			trait = "Trüf ormanı: geliştirme maliyetleri -%8",
			upgradeId = "island_pig",
		},
	} :: { [string]: Types.FarmIslandConfig },

	-- Temalar: dizi sırası = ana çiftlik numarası = fiziksel ada numarası (Çiftlik 1 her zaman Papatya).
	-- Her tema erken (Ahır Sv.2), orta (Sv.3) ve geç (Sv.4) birer ada türü içerir; hiçbir tema diğeriyle aynı değildir.
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
			displayName = "Yün ve Süt",
			homeAnimal = "chicken",
			satellites = { "dairy", "sheep", "goat" },
		},
		{
			id = "aycicegi",
			landmark = "sunflower",
			displayName = "Güneşli Tarla",
			homeAnimal = "duck",
			satellites = { "dairy", "poultry", "pig" },
		},
		{
			id = "gul",
			landmark = "rose",
			displayName = "Göl ve Hara",
			homeAnimal = "cow",
			satellites = { "duck", "horse", "pig" },
		},
		{
			id = "yonca",
			landmark = "pine",
			displayName = "Dağ ve Orman",
			homeAnimal = "chicken",
			satellites = { "dairy", "horse", "pig" },
		},
		{
			id = "kiraz",
			landmark = "cherry",
			displayName = "Meyve ve Süt",
			homeAnimal = "duck",
			satellites = { "dairy", "sheep", "pig" },
		},
	} :: { Types.ThemeConfig },

	-- Yol haritası aşamaları: adalar + onlarla paralel ilerleyen Deniz dalı
	ROADMAP_STAGES = {
		{ name = "Ana Ada", island = "home" },
		{ name = "Deniz", description = "Balık kafesinde hamsi ve levrek yetiştir" },
		{ name = "Tavuk Adası", island = "poultry" },
		{ name = "At Adası", island = "horse" },
		{ name = "Keçi Adası", island = "goat" },
		{ name = "Ördek Adası", island = "duck" },
		{ name = "Koyun Adası", island = "sheep" },
		{ name = "Domuz Adası", island = "pig" },
		{ name = "Süt Adası", island = "dairy" },
	} :: { Types.RoadmapStage },
}
