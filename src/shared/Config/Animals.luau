--!strict
-- Bölgeler, hayvanlar ve eski kayıt eşlemeleri.
-- Gizli bilgi koyma: ReplicatedStorage client'a da gider.

local Types = require(script.Parent:WaitForChild("Types"))
return {
	-- Bölgeler. Sıra önemli: hayvan alınınca ilk açık & boş alana konur.
	-- Bir bölge, adası açıksa ve (varsa) kendi yol haritası öğesi alınmışsa açıktır.
	ZONE_ORDER = {
		"starter",
		"pasture",
		"fishpen",
		"dairy",
		"poultry",
		"pond",
		"stable",
		"sheepfold",
		"goatpen",
		"pigpen",
	},

	ZONES = {
		starter = {
			id = "starter",
			displayName = "İnek Ağılı",
			icon = "🐄",
			island = "home",
			capacity = 6,
			allowedAnimals = { "cow" },
			themed = true,
		},
		pasture = {
			id = "pasture",
			displayName = "Otlak",
			icon = "🌾",
			island = "home",
			capacity = 8,
			allowedAnimals = { "cow" },
			themed = true,
		},
		dairy = {
			id = "dairy",
			displayName = "İnek Çayırı",
			icon = "🐄",
			island = "dairy",
			capacity = 10,
			allowedAnimals = { "cow" },
		},
		fishpen = {
			id = "fishpen",
			displayName = "Balık Kafesi",
			icon = "🐟",
			island = "home",
			capacity = 10,
			allowedAnimals = { "anchovy", "seabass" },
		},
		poultry = {
			id = "poultry",
			displayName = "Kümes",
			icon = "🐔",
			island = "poultry",
			capacity = 12,
			allowedAnimals = { "chicken" },
		},
		stable = {
			id = "stable",
			displayName = "Hara",
			icon = "🐎",
			island = "horse",
			capacity = 6,
			allowedAnimals = { "horse" },
		},
		goatpen = {
			id = "goatpen",
			displayName = "Keçi Ağılı",
			icon = "🐐",
			island = "goat",
			capacity = 8,
			allowedAnimals = { "goat" },
		},
		pond = {
			id = "pond",
			displayName = "Ördek Gölü",
			icon = "🦆",
			island = "duck",
			capacity = 12,
			allowedAnimals = { "duck" },
		},
		sheepfold = {
			id = "sheepfold",
			displayName = "Koyun Ağılı",
			icon = "🐑",
			island = "sheep",
			capacity = 8,
			allowedAnimals = { "sheep" },
		},
		pigpen = {
			id = "pigpen",
			displayName = "Domuz Çiftliği",
			icon = "🐖",
			island = "pig",
			capacity = 8,
			allowedAnimals = { "pig" },
		},
	} :: { [string]: Types.ZoneConfig },

	ANIMAL_ORDER = { "cow", "anchovy", "chicken", "duck", "seabass", "horse", "sheep", "goat", "pig" },

	ANIMALS = {
		cow = {
			id = "cow",
			displayName = "İnek",
			icon = "🐄",
			product = "Süt",
			price = 75,
			baseIncomePerSecond = 2,
		},
		anchovy = {
			id = "anchovy",
			displayName = "Hamsi",
			icon = "🐟",
			product = "Taze hamsi",
			price = 200,
			baseIncomePerSecond = 4,
		},
		seabass = {
			id = "seabass",
			displayName = "Levrek",
			icon = "🐠",
			product = "Levrek",
			price = 1200,
			baseIncomePerSecond = 16,
		},
		chicken = {
			id = "chicken",
			displayName = "Tavuk",
			icon = "🐔",
			product = "Yumurta",
			price = 350,
			baseIncomePerSecond = 5,
		},
		horse = {
			id = "horse",
			displayName = "At",
			icon = "🐎",
			product = "Yarış ödülü",
			price = 1200,
			baseIncomePerSecond = 12,
		},
		goat = {
			id = "goat",
			displayName = "Keçi",
			icon = "🐐",
			product = "Keçi sütü",
			price = 2000,
			baseIncomePerSecond = 24,
		},
		duck = {
			id = "duck",
			displayName = "Ördek",
			icon = "🦆",
			product = "Ördek yumurtası",
			price = 400,
			baseIncomePerSecond = 5.5,
		},
		sheep = {
			id = "sheep",
			displayName = "Koyun",
			icon = "🐑",
			product = "Yün",
			price = 1400,
			baseIncomePerSecond = 13,
		},
		pig = {
			id = "pig",
			displayName = "Domuz",
			icon = "🐖",
			product = "Trüf",
			price = 2200,
			baseIncomePerSecond = 26,
		},
	} :: { [string]: Types.AnimalConfig },

	STAGE_INCOME_MULTIPLIER = {
		calf = 0.4,
		young = 0.75,
		adult = 1,
	} :: { [string]: number },

	STAGE_DISPLAY = {
		calf = "Yavru",
		young = "Genç",
		adult = "Yetişkin",
	} :: { [string]: string },

	-- Eski kayıtlardaki kaldırılmış yol haritası id'leri → yeni karşılıkları
	LEGACY_UPGRADES = {
		zone_poultry = "island_poultry",
		zone_stable = "island_horse",
	} :: { [string]: string },
}
