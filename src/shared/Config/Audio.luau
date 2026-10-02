--!strict
-- Ses, ortam sesi, müzik ve hayvan sesleri.
-- Gizli bilgi koyma: ReplicatedStorage client'a da gider.

local Types = require(script.Parent:WaitForChild("Types"))
local Species = require(script.Parent:WaitForChild("Species"))

local data = {
	-- Ses. `id` boşsa o ses çalınmaz. Arayüz sesleri motorun kendi dosyalarını kullanır (yer tutucu);
	-- gerçek "cha-ching", ortam ve hayvan sesleri için Creator Store'dan (Roblox'un ücretsiz sesleri)
	-- aldığın `rbxassetid://NUMARA` kimliklerini aşağıya yaz. Kimlik doğrulaması Studio'da yapılır.
	SOUNDS = {
		click = { id = "rbxassetid://85853715220509", volume = 0.033, pitch = 0.92 },
		coin = { id = "rbxassetid://74269875292754", volume = 0.066, pitch = 1.25 },
		success = { id = "rbxassetid://132667477808512", volume = 0.11, pitch = 1.15 },
		error = { id = "rbxassetid://130559881440398", volume = 0.11, pitch = 0.7 },
		build = { id = "rbxassetid://95681593748458", volume = 0.055 },

		-- Aşağıdakiler yeni yuvalar: kimlik boş (sessiz) olduğu sürece çalınmaz. Kimlik yazınca kod aynen kullanır.
		-- Ne zaman çaldıkları docs/SESLER.md içinde listelidir (bağlantılar Interaction/EventSounds ve arayüzde).
		ui_open = { id = "rbxassetid://128235535469237", volume = 0.138 }, -- pencere açılır
		ui_close = { id = "rbxassetid://132018544065484", volume = 0.11 }, -- pencere kapanır
		notify = { id = "rbxassetid://86097027014620", volume = 0.165 }, -- bilgi bildirimi (toast: info)
		animal_buy = { id = "rbxassetid://121364334724911", volume = 0.248 }, -- hayvan satın alındı
		animal_sell = { id = "rbxassetid://89615029143186", volume = 0.193 }, -- hayvan satıldı
		upgrade_buy = { id = "rbxassetid://86216126014266", volume = 0.275 }, -- yükseltme alındı
		expansion_buy = { id = "rbxassetid://138806082296791", volume = 0.275 }, -- bölge/tesis geliştirme seviyesi
		barn_level = { id = "rbxassetid://84152587576214", volume = 0.33 }, -- ahır seviyesi arttı
		production_start = { id = "rbxassetid://86073865078012", volume = 0.193 }, -- üretim partisi başladı
		production_ready = { id = "rbxassetid://108025716157095", volume = 0.248 }, -- parti hazır
		production_claim = { id = "rbxassetid://103424984000486", volume = 0.22 }, -- parti teslim alındı
		contract_done = { id = "rbxassetid://92643647887597", volume = 0.275 }, -- ahır siparişi teslim edildi
		achievement = { id = "rbxassetid://135430398433445", volume = 0.303 }, -- başarım ödülü alındı
		daily_claim = { id = "rbxassetid://89846442997889", volume = 0.248 }, -- günlük ödül alındı
		item_buy = { id = "rbxassetid://127670787229948", volume = 0.248 }, -- eşya alındı
		item_equip = { id = "rbxassetid://88923022696257", volume = 0.193 }, -- eşya takıldı/çıkarıldı
		season_change = { id = "rbxassetid://127257574251711", volume = 0.22 }, -- mevsim değişti
		golden_spawn = { id = "rbxassetid://85918027908593", volume = 0.275 }, -- altın hayvan belirdi
		merchant_arrive = { id = "rbxassetid://134598992857758", volume = 0.248 }, -- gezgin tüccar geldi
	} :: { [string]: Types.SoundConfig },

	-- Müzik: tek döngü yuvası, kendi SoundGroup'unda ("Müzik" sürgüsü). Boş kimlik = müzik yok; kimliği sen yaz
	-- (`rbxassetid://NUMARA`), kod aynen çalar. Birden fazla parça gerekirse buraya anahtar ekle; hepsi sırayla değil birlikte çalar,
	-- bu yüzden şimdilik tek parça önerilir.
	MUSIC = {
		main = { id = "", volume = 0.35 },
	} :: { [string]: Types.SoundConfig },

	-- Ayarlar'daki üç sürgünün varsayılan düzeyi (0..1): oyuncu hiç değiştirmediyse bunlar geçerlidir.
	AUDIO_DEFAULTS = { sfx = 0.4, ambience = 0.35, music = 0.4 } :: { [string]: number },

	-- Ortam döngüleri (mevsim, hava ve gece): boş kimlik = o katman yok.
	AMBIENCE = {
		birds = { id = "rbxassetid://127027242520219", volume = 0.04 }, -- ilkbahar/yaz gündüz
		wind = { id = "rbxassetid://125057374855022", volume = 0.08 }, -- sonbahar/kış
		rain = { id = "rbxassetid://133112480071276", volume = 0.1 }, -- yağmur
		storm = { id = "rbxassetid://134519304498687", volume = 0.12 }, -- fırtına
		night = { id = "rbxassetid://133269110109074", volume = 0.08 }, -- gece (cırcır böceği)
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

-- Hayvan türü tablosundaki her hayvan için ses satırı (kimlik boş: ses asset'i eklenince doldurulur)
for _, row in Species.SPECIES do
	data.ANIMAL_SOUNDS[row.id] = { id = "", volume = 0.45 }
end

return data
