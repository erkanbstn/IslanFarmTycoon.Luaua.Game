--!strict
-- Mevsim ve hava döngüsü. Mevsim saate bağlı (tüm sunucularda aynı), hava her sunucuda rastgele
-- ve mevsime uygun. Değişince herkese bildirilir (renkleri client'taki WeatherEffects değiştirir).
-- Gelire etkisi FarmMath → Environment üzerinden otomatik uygulanır.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local AdminPolicy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("AdminPolicy"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))
local Metrics = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Metrics"))

local SeasonService = {}

local random = Random.new()
local currentSeasonIndex = 0
local weatherEndsAt = 0
local adminWeatherId: string? = nil
local adminSeasonIndex: number? = nil
local adminSeasonEndsAt = 0
local beforeEnvironmentChange: (() -> ())? = nil
local initialized = false

local function settleBeforeChange()
	if beforeEnvironmentChange then
		beforeEnvironmentChange()
	end
end

local function notifyAll(message: string)
	for _, player in Players:GetPlayers() do
		Remotes.get("Notify"):FireClient(player, message, "info")
	end
end

local function pickWeather(season: Config.SeasonConfig): Config.WeatherConfig
	local total = 0
	for _, weight in season.weather do
		total += weight
	end
	local roll = random:NextNumber(0, total)
	for id, weight in season.weather do
		roll -= weight
		if roll <= 0 and Config.WEATHER[id] then
			return Config.WEATHER[id]
		end
	end
	return Config.WEATHER.sunny
end

local function setWeather(weather: Config.WeatherConfig, announce: boolean)
	local now = os.time()
	weatherEndsAt = now + random:NextInteger(Config.WEATHER_SECONDS_MIN, Config.WEATHER_SECONDS_MAX)
	settleBeforeChange()
	Environment.setWeather(weather, weatherEndsAt)
	if announce then
		local effects = Environment.describeModifiers(weather.incomeModifiers)
		notifyAll(
			if effects ~= "" then `Hava: {weather.displayName} · Etkilere göz at` else `Hava: {weather.displayName}`
		)
	end
end

local function update(announce: boolean)
	local now = os.time()
	local seasonIndex = adminSeasonIndex or Environment.seasonIndexAt(now)
	local repeatForcedSeason = adminSeasonIndex ~= nil and now >= adminSeasonEndsAt
	if repeatForcedSeason then
		adminSeasonEndsAt += (math.floor((now - adminSeasonEndsAt) / Config.SEASON_SECONDS) + 1) * Config.SEASON_SECONDS
	end
	local seasonChanged = seasonIndex ~= currentSeasonIndex
	if seasonChanged or repeatForcedSeason then
		settleBeforeChange()
		currentSeasonIndex = seasonIndex
		local season = Config.SEASONS[seasonIndex]
		local endsAt = if adminSeasonIndex
			then adminSeasonEndsAt
			else (math.floor(now / Config.SEASON_SECONDS) + 1) * Config.SEASON_SECONDS
		Environment.setSeason(season, endsAt)
		if announce and seasonChanged then
			-- Etkilerin tam listesi bildirimi şişirmesin: ayrıntı Mevsim çubuğundaki "Etkileri göster"de
			notifyAll(`{season.displayName} geldi! Etkilere göz at (Mevsim çubuğu)`)
		end
		if seasonChanged then
			-- Mevsim değişse de yöneticinin sabitlediği hava korunur.
			setWeather(if adminWeatherId then Config.WEATHER[adminWeatherId] else pickWeather(season), false)
			return
		end
	end
	if now >= weatherEndsAt then
		local season = Config.SEASONS[currentSeasonIndex]
		local previous = Environment.getWeather()
		local nextWeather = if adminWeatherId then Config.WEATHER[adminWeatherId] else pickWeather(season)
		setWeather(nextWeather, announce and nextWeather.id ~= previous.id)
	end
end

-- Yetkilendirme çağıran AdminService'dedir; istemci bu sunucu modülüne erişemez.
function SeasonService.setAdminWeather(id: string?): boolean
	if id ~= nil and (typeof(id) ~= "string" or not Config.WEATHER[id]) then
		return false
	end
	adminWeatherId = id
	ReplicatedStorage:SetAttribute("AdminWeatherOverride", id)
	if id then
		setWeather(Config.WEATHER[id], true)
	else
		weatherEndsAt = 0
		update(true)
	end
	return true
end

-- Gün-gece ve ışık testi: saat/ışık durumu yalnızca görünümdür, gelire etkisi yoktur.
function SeasonService.setAdminClock(id: string?): boolean
	if id ~= nil and (typeof(id) ~= "string" or not Environment.CLOCK_PRESETS[id]) then
		return false
	end
	Environment.setClockOverride(id)
	return true
end

function SeasonService.setAdminLights(id: string?): boolean
	if id ~= nil and id ~= "on" and id ~= "off" then
		return false
	end
	Environment.setLightsOverride(id)
	return true
end

function SeasonService.setAdminLightLevel(id: string?): boolean
	if id ~= nil and (typeof(id) ~= "string" or not Environment.LIGHT_LEVELS[id]) then
		return false
	end
	Environment.setLightLevel(id)
	return true
end

function SeasonService.setAdminSeason(id: string?): boolean
	local index: number? = nil
	if id ~= nil then
		if typeof(id) ~= "string" then
			return false
		end
		for candidateIndex, season in Config.SEASONS do
			if season.id == id then
				index = candidateIndex
				break
			end
		end
		if not index then
			return false
		end
	end
	adminSeasonIndex = index
	adminSeasonEndsAt = if index then os.time() + Config.SEASON_SECONDS else 0
	ReplicatedStorage:SetAttribute("AdminSeasonOverride", id)
	currentSeasonIndex = 0 -- Aynı mevsim seçilse bile zamanlayıcı yeniden kurulur.
	update(true)
	return true
end

local DEBUG_WEATHER_ORDER = { "sunny", "cloudy", "rain", "storm", "snow" }

function SeasonService.init(beforeChange: (() -> ())?)
	if initialized then
		return
	end
	initialized = true
	beforeEnvironmentChange = beforeChange
	ReplicatedStorage:SetAttribute("AdminWeatherOverride", adminWeatherId)
	ReplicatedStorage:SetAttribute(
		"AdminSeasonOverride",
		if adminSeasonIndex then Config.SEASONS[adminSeasonIndex].id else nil
	)
	update(false)

	-- F7 de aynı hesap iznine bağlıdır; Studio'daki diğer oyuncular yetkili sayılmaz.
	Remotes.get("DebugCycleWeather").OnServerEvent:Connect(function(player: Player)
		if
			not RunService:IsStudio()
			or not AdminPolicy.isAllowed(player.UserId)
			or not RateLimiter.allow(player, "debugWeather", 0.5)
		then
			return
		end
		local current = table.find(DEBUG_WEATHER_ORDER, Environment.getWeather().id) or 0
		local nextId = DEBUG_WEATHER_ORDER[current % #DEBUG_WEATHER_ORDER + 1]
		SeasonService.setAdminWeather(nextId)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				update(true)
			end)
			if not ok then
				warn(`[Season] Mevsim güncellenemedi: {err}`)
				Metrics.increment("LoopError")
			end
		end
	end)
end

return SeasonService
