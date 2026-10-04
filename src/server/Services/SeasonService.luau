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
local weatherRevision = 0
type QueueEntry = {
	player: Player,
	itemId: string,
	weatherId: string,
	duration: number,
	canActivate: () -> (boolean, string?),
	onStarted: () -> (),
}
type QueueTicket = { token: string, itemId: string, weatherId: string, expiresAt: number, revision: number }
local weatherQueue: { QueueEntry } = {}
local pendingTickets: { [number]: QueueTicket } = {}
local nextTicket = 0

local function queueIndex(player: Player): number?
	for index, entry in weatherQueue do
		if entry.player == player then
			return index
		end
	end
	return nil
end

local function publishQueue()
	local startsAt = weatherEndsAt
	for index, entry in weatherQueue do
		Remotes.get("WeatherQueueOffer"):FireClient(entry.player, {
			kind = "queued",
			itemId = entry.itemId,
			weatherId = entry.weatherId,
			position = index,
			startsAt = startsAt,
		})
		startsAt += entry.duration
	end
end

local function closeQueue(player: Player, message: string?)
	Remotes.get("WeatherQueueOffer"):FireClient(player, { kind = "closed" })
	if message then
		Remotes.get("Notify"):FireClient(player, message, "info")
	end
end

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

local function setWeather(
	weather: Config.WeatherConfig,
	announce: boolean,
	fromWand: boolean?,
	owner: Player?,
	duration: number?
)
	local now = os.time()
	settleBeforeChange()
	weatherEndsAt = now + (duration or random:NextInteger(Config.WEATHER_SECONDS_MIN, Config.WEATHER_SECONDS_MAX))
	weatherRevision += 1
	Environment.setWeather(weather, weatherEndsAt)
	ReplicatedStorage:SetAttribute("WandWeatherActive", fromWand == true)
	ReplicatedStorage:SetAttribute(
		"WandWeatherOwnerName",
		if fromWand and owner then owner.DisplayName or owner.Name else nil
	)
	ReplicatedStorage:SetAttribute("WandWeatherOwnerId", if fromWand and owner then owner.UserId else nil)
	if announce then
		local effects = Environment.describeModifiers(weather.incomeModifiers)
		notifyAll(
			if effects ~= "" then `Hava: {weather.displayName} · Etkilere göz at` else `Hava: {weather.displayName}`
		)
	end
end

local function startQueuedWeather(): boolean
	while #weatherQueue > 0 do
		local entry = assert(table.remove(weatherQueue, 1))
		local allowed = entry.canActivate()
		if allowed and Environment.getSeason({}).weather[entry.weatherId] then
			setWeather(Config.WEATHER[entry.weatherId], true, true, entry.player, entry.duration)
			entry.onStarted()
			closeQueue(entry.player)
			publishQueue()
			return true
		end
		closeQueue(entry.player, "Hava sıran başlayamadı; kullanım hakkı harcanmadı.")
	end
	return false
end

local function update(announce: boolean)
	local now = os.time()
	for userId, ticket in pendingTickets do
		if now >= ticket.expiresAt then
			pendingTickets[userId] = nil
		end
	end
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
		if
			seasonChanged and not (ReplicatedStorage:GetAttribute("WandWeatherActive") == true and now < weatherEndsAt)
		then
			-- Mevsim değişse de yöneticinin sabitlediği hava korunur.
			if not adminWeatherId and startQueuedWeather() then
				return
			end
			setWeather(if adminWeatherId then Config.WEATHER[adminWeatherId] else pickWeather(season), false)
			return
		end
	end
	if now >= weatherEndsAt then
		if not adminWeatherId and startQueuedWeather() then
			return
		end
		local season = Config.SEASONS[currentSeasonIndex]
		local previous = Environment.getWeather()
		local nextWeather = if adminWeatherId then Config.WEATHER[adminWeatherId] else pickWeather(season)
		setWeather(nextWeather, announce and nextWeather.id ~= previous.id)
	end
end

-- Sahiplik, takılı eşya ve kullanım hakkını InventoryService doğrular.
function SeasonService.setPlayerWeather(id: string, owner: Player?): (boolean, string?)
	if ReplicatedStorage:GetAttribute("WandWeatherActive") == true and os.time() < weatherEndsAt then
		return false, "Hava asası etkisi sürüyor; sıraya almayı onayla."
	end
	-- Süresi dolmuş ilk etki ve bekleyen sıra aynı istekte uzlaştırılır.
	update(false)
	if SeasonService.isWandWeatherBusy() then
		return false, "Hava asası etkisi sürüyor; sıraya almayı onayla."
	end
	local weather = Config.WEATHER[id]
	if not weather then
		return false, "Bilinmeyen hava"
	end
	if adminWeatherId then
		return false, "Yönetici havayı sabitledi; şu anda değiştiremezsin"
	end
	-- Hava tüm sunucuyu etkiler; oyuncunun özel mevsimi seçimi genişletemez.
	if not Environment.getSeason({}).weather[id] then
		return false, "Bu hava bu mevsimde seçilemez"
	end
	local currentId = ReplicatedStorage:GetAttribute("Weather")
	if currentId == id then
		return false, "Hava zaten böyle"
	end
	setWeather(weather, true, true, owner)
	return true, nil
end

function SeasonService.hasQueuedWeather(player: Player): boolean
	return queueIndex(player) ~= nil
end

function SeasonService.isWandWeatherBusy(): boolean
	return ReplicatedStorage:GetAttribute("WandWeatherActive") == true and os.time() < weatherEndsAt
end

function SeasonService.offerWeatherQueue(player: Player, itemId: string, weatherId: string): (boolean, string?)
	if adminWeatherId then
		return false, "Yönetici havayı sabitledi; şu anda değiştiremezsin"
	end
	if not Config.WEATHER[weatherId] or not Environment.getSeason({}).weather[weatherId] then
		return false, "Bu hava bu mevsimde seçilemez"
	end
	if queueIndex(player) then
		return false, "Zaten hava sırasında bekliyorsun."
	end
	if not SeasonService.isWandWeatherBusy() then
		return false, "Hava etkisi değişti; yeniden seçerek sırayı onayla."
	end
	nextTicket += 1
	local now = os.time()
	local token = tostring(nextTicket)
	pendingTickets[player.UserId] =
		{ token = token, itemId = itemId, weatherId = weatherId, expiresAt = now + 30, revision = weatherRevision }
	local startsAt = weatherEndsAt
	for _, entry in weatherQueue do
		startsAt += entry.duration
	end
	local current = Environment.getWeather()
	Remotes.get("WeatherQueueOffer"):FireClient(player, {
		kind = "offer",
		itemId = itemId,
		weatherId = weatherId,
		token = token,
		ownerName = ReplicatedStorage:GetAttribute("WandWeatherOwnerName") or "Bir oyuncu",
		weatherName = current.displayName,
		endsAt = weatherEndsAt,
		startsAt = startsAt,
		expiresAt = now + 30,
	})
	return true, nil
end

function SeasonService.confirmWeatherQueue(
	player: Player,
	itemId: string,
	weatherId: string,
	token: string,
	canActivate: () -> (boolean, string?),
	onStarted: () -> ()
): (boolean, string?)
	local ticket = pendingTickets[player.UserId]
	if
		not ticket
		or ticket.token ~= token
		or ticket.itemId ~= itemId
		or ticket.weatherId ~= weatherId
		or os.time() >= ticket.expiresAt
	then
		return false, "Sıra onayı geçersiz veya süresi doldu; yeniden seç."
	end
	if ticket.revision ~= weatherRevision or not SeasonService.isWandWeatherBusy() or adminWeatherId then
		pendingTickets[player.UserId] = nil
		return false, "Hava etkisi değişti; yeniden seçerek sırayı onayla."
	end
	if queueIndex(player) then
		return false, "Zaten hava sırasında bekliyorsun."
	end
	if #weatherQueue >= Config.MAP_PLOT_COUNT then
		return false, "Sıra dolu; daha sonra tekrar dene."
	end
	local allowed, reason = canActivate()
	if not allowed then
		return false, reason
	end
	pendingTickets[player.UserId] = nil
	table.insert(weatherQueue, {
		player = player,
		itemId = itemId,
		weatherId = weatherId,
		duration = random:NextInteger(Config.WEATHER_SECONDS_MIN, Config.WEATHER_SECONDS_MAX),
		canActivate = canActivate,
		onStarted = onStarted,
	})
	publishQueue()
	return true, "Seçtiğin hava sıraya alındı. Kullanım hakkı başlayınca harcanır."
end

function SeasonService.cancelQueuedWeather(player: Player): (boolean, string?)
	pendingTickets[player.UserId] = nil
	local index = queueIndex(player)
	if not index then
		return false, "Hava sırasında bekleyen bir seçimin yok."
	end
	table.remove(weatherQueue, index)
	closeQueue(player)
	publishQueue()
	return true, "Hava sırası iptal edildi; kullanım hakkı harcanmadı."
end

-- Yetkilendirme çağıran AdminService'dedir; istemci bu sunucu modülüne erişemez.
function SeasonService.setAdminWeather(id: string?): boolean
	if id ~= nil and (typeof(id) ~= "string" or not Config.WEATHER[id]) then
		return false
	end
	adminWeatherId = id
	if id then
		for _, entry in weatherQueue do
			closeQueue(entry.player, "Yönetici hava sırasını iptal etti; kullanım hakkı harcanmadı.")
		end
		table.clear(weatherQueue)
		table.clear(pendingTickets)
	end
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
	Players.PlayerRemoving:Connect(function(player: Player)
		SeasonService.cancelQueuedWeather(player)
	end)

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
