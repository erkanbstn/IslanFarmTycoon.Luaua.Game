--!strict
-- Mevsim, gün-gece ve hava olayı tanımları.
-- Gizli bilgi koyma: ReplicatedStorage client'a da gider.

local Types = require(script.Parent:WaitForChild("Types"))
return {
	-- Mevsimler sırayla döner; tüm sunucularda aynı anda değişir (saat os.time'a bağlı).
	-- Hava her sunucuda rastgele, mevsime uygun olarak birkaç dakikada bir değişir.
	SEASON_SECONDS = 900, -- 15 dakika; dört mevsimlik döngü bir saat sürer.

	DAY_SECONDS = 480, -- Bir gün-gece döngüsü (24 oyun saati) gerçek 8 dakikadır; tüm sunucuda aynı anda ilerler.

	DAY_START_HOUR = 9, -- Sunucu saati 0 iken oyun saati

	WEATHER_SECONDS_MIN = 150,

	WEATHER_SECONDS_MAX = 270,

	-- Hayvan başına net mevsim/hava etkisi bu eşiğin altındaysa nötr sayılır (hayvan üstünde ok çıkmaz): 0.03 = %3.
	SEASON_SIGNAL_THRESHOLD = 0.03,

	SEASONS = {
		{
			id = "spring",
			displayName = "İlkbahar",
			icon = "🌸",
			incomeModifiers = { cow = 0.2, chicken = 0.25, duck = 0.2, sheep = 0.2 },
			weather = { sunny = 4, cloudy = 3, rain = 3 },
			eventName = "Bahar Şenliği",
			orderBonus = 0.15,
			grassColor = Color3.fromRGB(106, 168, 74),
		},
		{
			id = "summer",
			displayName = "Yaz",
			icon = "☀️",
			incomeModifiers = {
				anchovy = 0.3,
				seabass = 0.3,
				horse = 0.15,
				cow = -0.1,
				duck = 0.15,
				sheep = -0.1,
				pig = -0.1,
			},
			weather = { sunny = 6, cloudy = 2, storm = 1 },
			eventName = "Hasat Zamanı",
			orderBonus = 0.2,
			grassColor = Color3.fromRGB(128, 170, 70),
		},
		{
			id = "autumn",
			displayName = "Sonbahar",
			icon = "🍂",
			incomeModifiers = { horse = 0.25, goat = 0.2, chicken = -0.1, pig = 0.25, sheep = 0.1 },
			weather = { cloudy = 4, rain = 3, storm = 2, sunny = 2 },
			eventName = "Sonbahar Pazarı",
			orderBonus = 0.2,
			grassColor = Color3.fromRGB(150, 150, 75),
		},
		{
			id = "winter",
			displayName = "Kış",
			icon = "❄️",
			incomeModifiers = {
				goat = 0.3,
				cow = 0.15,
				chicken = -0.2,
				anchovy = -0.2,
				seabass = -0.2,
				sheep = 0.2,
				duck = -0.15,
				pig = 0.05,
			},
			weather = { snow = 4, cloudy = 3, sunny = 2 },
			eventName = "Kış Festivali",
			orderBonus = 0.3,
			grassColor = Color3.fromRGB(175, 190, 180),
		},
	} :: { Types.SeasonConfig },

	WEATHER = {
		sunny = { id = "sunny", displayName = "Güneşli", icon = "☀️", incomeModifiers = {} },
		cloudy = { id = "cloudy", displayName = "Bulutlu", icon = "☁️", incomeModifiers = {} },
		rain = {
			id = "rain",
			displayName = "Yağmurlu",
			icon = "🌧️",
			incomeModifiers = { cow = 0.1, horse = 0.1, goat = 0.1 },
		},
		storm = {
			id = "storm",
			displayName = "Fırtına",
			icon = "⛈️",
			incomeModifiers = { anchovy = -0.3, seabass = -0.3, chicken = -0.1 },
		},
		snow = {
			id = "snow",
			displayName = "Karlı",
			icon = "🌨️",
			incomeModifiers = { goat = 0.1, chicken = -0.1 },
		},
	} :: { [string]: Types.WeatherConfig },
}
