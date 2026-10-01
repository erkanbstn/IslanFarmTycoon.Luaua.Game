--!strict
-- Ses, ortam sesi, müzik ve hayvan sesleri.
-- Gizli bilgi koyma: ReplicatedStorage client'a da gider.

local Types = require(script.Parent:WaitForChild("Types"))
return {
	-- Ses. `id` boşsa o ses çalınmaz. Arayüz sesleri motorun kendi dosyalarını kullanır (yer tutucu);
	-- gerçek "cha-ching", ortam ve hayvan sesleri için Creator Store'dan (Roblox'un ücretsiz sesleri)
	-- aldığın `rbxassetid://NUMARA` kimliklerini aşağıya yaz. Kimlik doğrulaması Studio'da yapılır.
	SOUNDS = {
		click = { id = "rbxasset://sounds/clickfast.wav", volume = 0.06, pitch = 0.92 },
		coin = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.12, pitch = 1.25 },
		success = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.2, pitch = 1.15 },
		error = { id = "rbxasset://sounds/switch.wav", volume = 0.2, pitch = 0.7 },
		build = { id = "rbxasset://sounds/victory.wav", volume = 0.1 },

		-- Aşağıdakiler yeni yuvalar: kimlik boş (sessiz) olduğu sürece çalınmaz. Kimlik yazınca kod aynen kullanır.
		-- Ne zaman çaldıkları docs/SESLER.md içinde listelidir (bağlantılar Interaction/EventSounds ve arayüzde).
		ui_open = { id = "", volume = 0.25 }, -- pencere açılır
		ui_close = { id = "", volume = 0.2 }, -- pencere kapanır
		notify = { id = "", volume = 0.3 }, -- bilgi bildirimi (toast: info)
		animal_buy = { id = "", volume = 0.45 }, -- hayvan satın alındı
		animal_sell = { id = "", volume = 0.35 }, -- hayvan satıldı
		upgrade_buy = { id = "", volume = 0.5 }, -- yükseltme alındı
		expansion_buy = { id = "", volume = 0.5 }, -- bölge/tesis geliştirme seviyesi
		barn_level = { id = "", volume = 0.6 }, -- ahır seviyesi arttı
		production_start = { id = "", volume = 0.35 }, -- üretim partisi başladı
		production_ready = { id = "", volume = 0.45 }, -- parti hazır
		production_claim = { id = "", volume = 0.4 }, -- parti teslim alındı
		contract_done = { id = "", volume = 0.5 }, -- ahır siparişi teslim edildi
		achievement = { id = "", volume = 0.55 }, -- başarım ödülü alındı
		daily_claim = { id = "", volume = 0.45 }, -- günlük ödül alındı
		item_buy = { id = "", volume = 0.45 }, -- eşya alındı
		item_equip = { id = "", volume = 0.35 }, -- eşya takıldı/çıkarıldı
		season_change = { id = "", volume = 0.4 }, -- mevsim değişti
		golden_spawn = { id = "", volume = 0.5 }, -- altın hayvan belirdi
		merchant_arrive = { id = "", volume = 0.45 }, -- gezgin tüccar geldi
	} :: { [string]: Types.SoundConfig },

	-- Müzik: tek döngü yuvası, kendi SoundGroup'unda ("Müzik" sürgüsü). Boş kimlik = müzik yok; kimliği sen yaz
	-- (`rbxassetid://NUMARA`), kod aynen çalar. Birden fazla parça gerekirse buraya anahtar ekle; hepsi sırayla değil birlikte çalar,
	-- bu yüzden şimdilik tek parça önerilir.
	MUSIC = {
		main = { id = "", volume = 0.35 },
	} :: { [string]: Types.SoundConfig },

	-- Ayarlar'daki üç sürgünün varsayılan düzeyi (0..1): oyuncu hiç değiştirmediyse bunlar geçerlidir.
	AUDIO_DEFAULTS = { sfx = 0.5, ambience = 0.7, music = 0.5 } :: { [string]: number },

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
