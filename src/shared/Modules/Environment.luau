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

-- Sunucu tarafı yazıcılar (SeasonService)
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
