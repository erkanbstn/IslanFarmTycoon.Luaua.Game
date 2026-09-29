--!strict
-- Şu anki mevsim ve hava. Sunucu (SeasonService) ReplicatedStorage attribute'larına yazar,
-- herkes buradan okur; böylece gelir hesabı sunucuda ve client'ta aynı çıkar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent:WaitForChild("Config"))

local Environment = {}

local SEASON_ATTR = "Season"
local SEASON_ENDS_ATTR = "SeasonEndsAt"
local WEATHER_ATTR = "Weather"
local WEATHER_ENDS_ATTR = "WeatherEndsAt"

-- Mevsim saate bağlı: tüm sunucularda aynı anda değişir
function Environment.seasonIndexAt(time: number): number
	return math.floor(time / Config.SEASON_SECONDS) % #Config.SEASONS + 1
end

function Environment.getSeason(): Config.SeasonConfig
	local id = ReplicatedStorage:GetAttribute(SEASON_ATTR)
	for _, season in Config.SEASONS do
		if season.id == id then
			return season
		end
	end
	return Config.SEASONS[Environment.seasonIndexAt(Workspace:GetServerTimeNow())]
end

function Environment.getWeather(): Config.WeatherConfig
	local id = ReplicatedStorage:GetAttribute(WEATHER_ATTR)
	return (if typeof(id) == "string" then Config.WEATHER[id] else nil) or Config.WEATHER.sunny
end

function Environment.getSeasonEndsAt(): number
	local value = ReplicatedStorage:GetAttribute(SEASON_ENDS_ATTR)
	return if typeof(value) == "number" and value > 0
		then value
		else (math.floor(Workspace:GetServerTimeNow() / Config.SEASON_SECONDS) + 1) * Config.SEASON_SECONDS
end

-- Aynı sunucu saati UI ve mevsimsel görselleri birlikte ilerletir.
function Environment.getSeasonProgress(now: number?): number
	local time = now or Workspace:GetServerTimeNow()
	return math.clamp(1 - (Environment.getSeasonEndsAt() - time) / Config.SEASON_SECONDS, 0, 1)
end

function Environment.getNextSeason(): Config.SeasonConfig
	local current = Environment.getSeason()
	for index, season in Config.SEASONS do
		if season.id == current.id then
			return Config.SEASONS[index % #Config.SEASONS + 1]
		end
	end
	return Config.SEASONS[1]
end

-- Gün-gece: sunucu saatinden türetilir, herkes aynı saati görür (client Lighting.ClockTime'a yazar).
Environment.CLOCK_PRESETS = { dawn = 6.5, noon = 12, dusk = 18.5, night = 23 } :: { [string]: number }
Environment.LIGHT_LEVELS = { dim = 0.5, low = 0.75, normal = 1, strong = 1.5 } :: { [string]: number }
local CLOCK_ID_ATTR = "AdminClockId"
local LIGHTS_ID_ATTR = "AdminLightsId"
local LIGHT_LEVEL_ID_ATTR = "AdminLightLevelId"

-- Yönetici saat seçtiyse gün-gece o saatte sabit kalır.
function Environment.getClockTime(now: number?): number
	local overrideId = ReplicatedStorage:GetAttribute(CLOCK_ID_ATTR)
	local preset = if typeof(overrideId) == "string" then Environment.CLOCK_PRESETS[overrideId] else nil
	if preset then
		return preset
	end
	local time = now or Workspace:GetServerTimeNow()
	return (Config.DAY_START_HOUR + time / Config.DAY_SECONDS * 24) % 24
end

local function smoothstep(from: number, to: number, x: number): number
	local t = math.clamp((x - from) / (to - from), 0, 1)
	return t * t * (3 - 2 * t)
end

-- 0 = tam gündüz, 1 = tam gece; akşam 17.5-19.5 arası kararır, sabah 4.5-6.5 arası aydınlanır.
function Environment.getNightFactor(clock: number): number
	if clock >= 12 then
		return smoothstep(17.5, 19.5, clock)
	end
	return 1 - smoothstep(4.5, 6.5, clock)
end

-- Işık kaynakları gökyüzünün kararmasına bağlıdır: hava belirgin kararınca (≈18:05) yanar, ≈18:40'ta
-- tam açılır; sabah ≈05:20'de sönmeye başlar, gökyüzü aydınlanmadan (≈05:55) tamamen söner.
-- Ayrı saat aralığı kullanma: ikisi ayrışınca güpegündüz ışık yanar.
function Environment.getLightFactor(clock: number): number
	return smoothstep(0.2, 0.6, Environment.getNightFactor(clock))
end

-- Mevsim + hava toplam gelir çarpanı (en az 0.2)
function Environment.getIncomeMultiplier(animalId: string): number
	local seasonMod = Environment.getSeason().incomeModifiers[animalId] or 0
	local weatherMod = Environment.getWeather().incomeModifiers[animalId] or 0
	return math.max(1 + seasonMod + weatherMod, 0.2)
end

-- "At +%25 · Tavuk -%10" gibi özet (sıralı, sabit)
function Environment.describeModifiers(modifiers: { [string]: number }): string
	local parts = {}
	for _, animalId in Config.ANIMAL_ORDER do
		local value = modifiers[animalId]
		if value and value ~= 0 then
			local animal = Config.ANIMALS[animalId]
			local sign = if value > 0 then "+" else "-"
			table.insert(parts, `{animal.displayName} {sign}%{math.round(math.abs(value) * 100)}`)
		end
	end
	return table.concat(parts, " · ")
end

-- Yönetici gece ışıkları: "on" hep açık, "off" hep kapalı, nil otomatik
function Environment.getLightsOverride(): string?
	local id = ReplicatedStorage:GetAttribute(LIGHTS_ID_ATTR)
	return if id == "on" or id == "off" then id else nil
end

-- Işık parlaklığı çarpanı (varsayılan 1)
function Environment.getLightMultiplier(): number
	local id = ReplicatedStorage:GetAttribute(LIGHT_LEVEL_ID_ATTR)
	return (if typeof(id) == "string" then Environment.LIGHT_LEVELS[id] else nil) or 1
end

-- Sunucu tarafı yazıcılar (SeasonService)
function Environment.setClockOverride(id: string?)
	ReplicatedStorage:SetAttribute(CLOCK_ID_ATTR, id)
end

function Environment.setLightsOverride(id: string?)
	ReplicatedStorage:SetAttribute(LIGHTS_ID_ATTR, id)
end

function Environment.setLightLevel(id: string?)
	ReplicatedStorage:SetAttribute(LIGHT_LEVEL_ID_ATTR, id)
end

function Environment.setSeason(season: Config.SeasonConfig, endsAt: number)
	ReplicatedStorage:SetAttribute(SEASON_ATTR, season.id)
	ReplicatedStorage:SetAttribute(SEASON_ENDS_ATTR, endsAt)
end

function Environment.setWeather(weather: Config.WeatherConfig, endsAt: number)
	ReplicatedStorage:SetAttribute(WEATHER_ATTR, weather.id)
	ReplicatedStorage:SetAttribute(WEATHER_ENDS_ATTR, endsAt)
end

-- Değişiklikleri dinlemek için (client görselleri, arayüz)
function Environment.onChanged(callback: () -> ())
	for _, attr in { SEASON_ATTR, WEATHER_ATTR } do
		ReplicatedStorage:GetAttributeChangedSignal(attr):Connect(callback)
	end
end

return Environment
