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

-- Mevsim asası oyuncuya özel çalışma anı katmanı kullanır (kaydedilmez).
-- Hava asası SeasonService üzerinden sunucu havasını değiştirir; aktifken kişisel katmanı da aşar.
-- Sunucu kaydı açıkça verir; istemcide argümansız çağrılar setClientOverride kullanır.
export type Override = { seasonId: string?, seasonEndsAt: number?, weatherId: string?, weatherEndsAt: number? }

local WEATHER_WINDOW_SECONDS = 240 -- Mevsim geçersiz kılınınca hava bu pencerelerle (oyuncuya özel, kararlı) seçilir
local clientOverride: Override? = nil
local overrideListeners: { () -> () } = {}

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function activeSeasonOverride(override: Override?): Config.SeasonConfig?
	if override and override.seasonId and override.seasonEndsAt and serverNow() < override.seasonEndsAt then
		for _, season in Config.SEASONS do
			if season.id == override.seasonId then
				return season
			end
		end
	end
	return nil
end

-- Geçersiz kılınmış bir mevsimin havası: mevsimin havuzundan, zaman penceresine göre kararlı (her iki taraf aynı sonucu bulur)
local function pickWeatherFor(season: Config.SeasonConfig, now: number): Config.WeatherConfig
	local keys: { string } = {}
	local total = 0
	for id, weight in season.weather do
		table.insert(keys, id)
		total += weight
	end
	table.sort(keys)
	local window = math.floor(now / WEATHER_WINDOW_SECONDS)
	local seed = (window * 7919 + #season.id * 104729) % 2147483648
	seed = (seed * 1103515245 + 12345) % 2147483648
	seed = (seed * 1103515245 + 12345) % 2147483648
	local roll = seed / 2147483648 * total
	for _, id in keys do
		roll -= season.weather[id]
		if roll <= 0 and Config.WEATHER[id] then
			return Config.WEATHER[id]
		end
	end
	return Config.WEATHER.sunny
end

function Environment.getSeason(override: Override?): Config.SeasonConfig
	local overridden = activeSeasonOverride(override or clientOverride)
	if overridden then
		return overridden
	end
	local id = ReplicatedStorage:GetAttribute(SEASON_ATTR)
	for _, season in Config.SEASONS do
		if season.id == id then
			return season
		end
	end
	return Config.SEASONS[Environment.seasonIndexAt(serverNow())]
end

function Environment.getWeather(override: Override?): Config.WeatherConfig
	if ReplicatedStorage:GetAttribute("WandWeatherActive") == true then
		local id = ReplicatedStorage:GetAttribute(WEATHER_ATTR)
		local sharedWeather = if typeof(id) == "string" then Config.WEATHER[id] else nil
		if sharedWeather then
			return sharedWeather
		end
	end
	local active = override or clientOverride
	local overriddenSeason = activeSeasonOverride(active)
	if overriddenSeason then
		return pickWeatherFor(overriddenSeason, serverNow())
	end
	local id = ReplicatedStorage:GetAttribute(WEATHER_ATTR)
	return (if typeof(id) == "string" then Config.WEATHER[id] else nil) or Config.WEATHER.sunny
end

function Environment.getSeasonEndsAt(override: Override?): number
	local active = override or clientOverride
	if activeSeasonOverride(active) and active and active.seasonEndsAt then
		return active.seasonEndsAt
	end
	local value = ReplicatedStorage:GetAttribute(SEASON_ENDS_ATTR)
	return if typeof(value) == "number" and value > 0
		then value
		else (math.floor(serverNow() / Config.SEASON_SECONDS) + 1) * Config.SEASON_SECONDS
end

-- Aynı sunucu saati UI ve mevsimsel görselleri birlikte ilerletir.
function Environment.getSeasonProgress(now: number?, override: Override?): number
	local time = now or serverNow()
	return math.clamp(1 - (Environment.getSeasonEndsAt(override) - time) / Config.SEASON_SECONDS, 0, 1)
end

function Environment.getNextSeason(override: Override?): Config.SeasonConfig
	local current = Environment.getSeason(override)
	for index, season in Config.SEASONS do
		if season.id == current.id then
			return Config.SEASONS[index % #Config.SEASONS + 1]
		end
	end
	return Config.SEASONS[1]
end

-- Client: kendi geçersiz kılmasını (state.envOverride) kur; değişince ve bitiş anlarında dinleyicilere haber verilir.
function Environment.setClientOverride(override: Override?)
	local function signature(value: Override?): string
		if not value then
			return ""
		end
		return `{value.seasonId}|{value.seasonEndsAt}|{value.weatherId}|{value.weatherEndsAt}`
	end
	if signature(override) == signature(clientOverride) then
		return
	end
	clientOverride = override
	local function notify()
		for _, listener in overrideListeners do
			task.spawn(listener)
		end
	end
	notify()
	if override then
		for _, endsAt in { override.seasonEndsAt, override.weatherEndsAt } do
			if typeof(endsAt) == "number" then
				local wait = endsAt - serverNow()
				if wait > 0 then
					task.delay(wait + 0.1, notify)
				end
			end
		end
	end
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

-- Gece payı eğrisi: (saat, pay) anahtarları arasında yumuşak (smoothstep) geçiş. 0 = tam gündüz, 1 = tam gece.
-- Şafak erken başlar (03:30'dan itibaren hafif aydınlanır, 07:00'de tam gündüz); akşam 17:00'de kararmaya başlar, 20:30'da tam gece.
-- Yeni nokta eklerken saatler artan sırada kalmalı; 0 ve 24 uçları aynı değerde (gün sınırında sıçrama olmaz).
Environment.NIGHT_CURVE = {
	{ 0, 1 },
	{ 3.5, 1 },
	{ 5, 0.6 },
	{ 6, 0.2 },
	{ 7, 0 },
	{ 17, 0 },
	{ 18, 0.25 },
	{ 19, 0.7 },
	{ 20.5, 1 },
	{ 24, 1 },
} :: { { number } }

function Environment.getNightFactor(clock: number): number
	local curve = Environment.NIGHT_CURVE
	local hour = clock % 24
	for index = 2, #curve do
		local to = curve[index]
		if hour <= to[1] then
			local from = curve[index - 1]
			return from[2] + (to[2] - from[2]) * smoothstep(from[1], to[1], hour)
		end
	end
	return curve[#curve][2]
end

-- Işık kaynakları gökyüzünün kararmasına bağlıdır: hava belirgin kararınca (≈17:45) yanar, ≈18:40'ta
-- tam açılır; sabah ≈05:00'te sönmeye başlar, gökyüzü aydınlanmadan (≈06:00) tamamen söner.
-- Ayrı saat aralığı kullanma: ikisi ayrışınca güpegündüz ışık yanar.
function Environment.getLightFactor(clock: number): number
	return smoothstep(0.2, 0.6, Environment.getNightFactor(clock))
end

-- Mevsim + hava toplam gelir çarpanı (en az 0.2)
function Environment.getIncomeMultiplier(animalId: string, override: Override?, affinity: number?): number
	local seasonMod = Environment.getSeason(override).incomeModifiers[animalId] or 0
	local weatherMod = Environment.getWeather(override).incomeModifiers[animalId] or 0
	local mods = seasonMod + weatherMod
	-- Mevsim uyumu (bölge geliştirmesi): olumlu etkiler büyür, olumsuzlar küçülür
	if affinity and affinity ~= 0 then
		mods = if mods > 0 then mods * (1 + affinity) else mods * (1 - math.min(affinity, 1))
	end
	return math.max(1 + mods, 0.2)
end

-- Net etki: yüzde (0.1 = +%10) ve işaret (-1/0/+1; eşik `Config.SEASON_SIGNAL_THRESHOLD` altı nötr).
export type SeasonEffect = { percent: number, signal: number }
function Environment.getSeasonEffect(animalId: string, override: Override?, affinity: number?): SeasonEffect
	local percent = Environment.getIncomeMultiplier(animalId, override, affinity) - 1
	local threshold = Config.SEASON_SIGNAL_THRESHOLD
	local signal = if percent >= threshold then 1 elseif percent <= -threshold then -1 else 0
	return { percent = percent, signal = signal }
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
	for _, attr in { SEASON_ATTR, WEATHER_ATTR, "WandWeatherActive" } do
		ReplicatedStorage:GetAttributeChangedSignal(attr):Connect(callback)
	end
	table.insert(overrideListeners, callback)
end

return Environment
