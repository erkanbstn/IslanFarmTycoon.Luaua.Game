--!strict
-- Hesap düzeyi oyuncu tercihleri: ses düzeyleri (SFX / Ortam / Müzik), hareket azaltma ve başlangıç öğreticisinin kapatılması.
-- Roblox'tan bağımsız saf mantık: kayıt çözümü, uzaktan gelen değerin doğrulanması ve istemciye giden öznitelikler.
-- Doğrulama listesi buradadır; remote ve SaveCodec aynı kuralı kullanır (graphics/language kalıbı).

local Preferences = {}

-- Tercih türü -> kayıt alanı. Ses düzeyleri `data.audio[tür]`; mantıksal tercihler aynı adlı kök alandır
-- (`data.reducedMotion`, `data.tutorialDone`: öğretici atlandı ya da tamamlandı, false = yeniden göster).
local VOLUME_KINDS: { [string]: boolean } = { sfx = true, ambience = true, music = true }
local BOOLEAN_KINDS: { [string]: boolean } = { reducedMotion = true, tutorialDone = true }

-- Sunucunun Player üzerine yazdığı öznitelik adları (kayıt yüklenince ve değişince). Boş metin = hiç seçilmemiş.
local ATTRIBUTES: { [string]: string } = {
	sfx = "SavedSfxVolume",
	ambience = "SavedAmbienceVolume",
	music = "SavedMusicVolume",
	reducedMotion = "SavedReducedMotion",
	tutorialDone = "SavedTutorialDone",
}

function Preferences.isKind(kind: unknown): boolean
	return typeof(kind) == "string" and (VOLUME_KINDS[kind] == true or BOOLEAN_KINDS[kind] == true)
end

-- Sonlu sayı -> 0..1, 0,01 adımına yuvarlanır; başka her şey nil.
function Preferences.volume(value: unknown): number?
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return math.round(math.clamp(value, 0, 1) * 100) / 100
end

-- Ham kayıttan çözer: yalnızca geçerli alanlar döner (bozuk/bilinmeyen değer yok sayılır, hata değildir).
function Preferences.decode(source: any): ({ [string]: number }?, boolean?)
	local audio: { [string]: number }? = nil
	if typeof(source.audio) == "table" then
		for kind in VOLUME_KINDS do
			local volume = Preferences.volume(source.audio[kind])
			if volume ~= nil then
				audio = audio or {};
				(audio :: { [string]: number })[kind] = volume
			end
		end
	end
	local reduced: boolean? = if typeof(source.reducedMotion) == "boolean" then source.reducedMotion else nil
	return audio, reduced
end

-- Öğretici işareti: yalnızca mantıksal değer; bozuk alan yok sayılır (öğretici durumdan türediği için güvenlidir).
function Preferences.decodeTutorialDone(source: any): boolean?
	return if typeof(source.tutorialDone) == "boolean" then source.tutorialDone else nil
end

-- Uzaktan gelen tercihi doğrular ve kayda yazar. Değişiklik olduysa true; geçersiz tür/değer ya da aynı değer false.
function Preferences.apply(data: any, kind: unknown, value: unknown): boolean
	if typeof(kind) ~= "string" then
		return false
	end
	if BOOLEAN_KINDS[kind] == true then
		if typeof(value) ~= "boolean" or data[kind] == value then
			return false
		end
		data[kind] = value
		return true
	end
	if VOLUME_KINDS[kind] ~= true then
		return false
	end
	local volume = Preferences.volume(value)
	if volume == nil then
		return false
	end
	local audio = data.audio
	if typeof(audio) ~= "table" then
		audio = {}
		data.audio = audio
	end
	if audio[kind] == volume then
		return false
	end
	audio[kind] = volume
	return true
end

-- İstemciye gidecek öznitelikler: ad -> değer (seçilmemişse ""), her tercih için eksiksiz.
function Preferences.attributes(data: any): { [string]: number | boolean | string }
	local result: { [string]: number | boolean | string } = {}
	local audio = if typeof(data.audio) == "table" then data.audio else {}
	for kind in VOLUME_KINDS do
		local volume = Preferences.volume(audio[kind])
		result[ATTRIBUTES[kind]] = if volume ~= nil then volume else ""
	end
	for kind in BOOLEAN_KINDS do
		local value = data[kind]
		result[ATTRIBUTES[kind]] = if typeof(value) == "boolean" then value else ""
	end
	return result
end

return Preferences
