--!strict
-- Ses, ortam sesi ve hayvan sesleri.
-- Gizli bilgi koyma: ReplicatedStorage client'a da gider.

local Types = require(script.Parent:WaitForChild("Types"))
return {
	-- Ses. `id` boşsa o ses çalınmaz. Arayüz sesleri motorun kendi dosyalarını kullanır (yer tutucu);
	-- gerçek "cha-ching", ortam ve hayvan sesleri için Creator Store'dan (Roblox'un ücretsiz sesleri)
	-- aldığın `rbxassetid://NUMARA` kimliklerini aşağıya yaz. Kimlik doğrulaması Studio'da yapılır.
	SOUNDS = {
		click = { id = "rbxasset://sounds/clickfast.wav", volume = 0.35 },
		coin = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.55, pitch = 1.6 },
		success = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.45, pitch = 1.15 },
		error = { id = "rbxasset://sounds/switch.wav", volume = 0.4, pitch = 0.7 },
		build = { id = "rbxasset://sounds/victory.wav", volume = 0.3 },
	} :: { [string]: Types.SoundConfig },

	-- Ortam döngüleri (mevsim, hava ve gece): boş kimlik = o katman yok.
	AMBIENCE = {
		birds = { id = "", volume = 0.35 }, -- ilkbahar/yaz gündüz
		wind = { id = "", volume = 0.3 }, -- sonbahar/kış
		rain = { id = "", volume = 0.45 }, -- yağmur
		storm = { id = "", volume = 0.5 }, -- fırtına
		night = { id = "", volume = 0.3 }, -- gece (cırcır böceği)
	} :: { [string]: Types.SoundConfig },

	-- Hayvan sesleri: animalId -> ses. Yakındaki yetişkin hayvan arada bir ses çıkarır.
	ANIMAL_SOUNDS = {
		cow = { id = "", volume = 0.5 },
		chicken = { id = "", volume = 0.45 },
		horse = { id = "", volume = 0.5 },
		goat = { id = "", volume = 0.5 },
		duck = { id = "", volume = 0.45 },
		sheep = { id = "", volume = 0.5 },
		pig = { id = "", volume = 0.5 },
	} :: { [string]: Types.SoundConfig },
}
