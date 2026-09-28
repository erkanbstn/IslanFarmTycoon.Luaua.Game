--!strict
-- Kendi bakiyesi ve sunucunun hava/mevsimi. Hedef oyuncu veya client miktar hesabı kabul edilmez.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local SeasonService = require(script.Parent:WaitForChild("SeasonService"))
local AdminPolicy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("AdminPolicy"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))

local AdminService = {}
local highWater: { [Player]: number } = {}
local initialized = false

local function validValue(action: string, value: unknown): boolean
	if action == "setCash" or action == "addCash" then
		return AdminPolicy.validCash(value, action == "addCash")
	end
	return typeof(value) == "string" and #value > 0 and #value <= 32 and string.match(value, "^[a-z_]+$") ~= nil
end

local function validSeason(id: string): boolean
	for _, season in Config.SEASONS do
		if season.id == id then
			return true
		end
	end
	return false
end

local function execute(player: Player, action: string, value: unknown): (boolean, string)
	if action == "setCash" or action == "addCash" then
		if player:GetAttribute("WorldReady") ~= true or not PlayerDataService.tryGet(player) then
			return false, "Çiftliğin henüz hazır değil"
		end
		EconomyService.settlePlayer(player)
		local data = PlayerDataService.tryGet(player)
		if not data then
			return false, "Kayıt oturumu artık etkin değil"
		end
		local amount = value :: number
		if action == "addCash" and data.cash + amount > 1e15 then
			return false, "Bakiye sınırı aşılıyor"
		end
		data.cash = if action == "setCash" then amount else data.cash + amount
		PlayerDataService.pushState(player)
		PlayerDataService.requestSave(player)
		return true, "Para güncellendi"
	end
	local id = value :: string
	if action == "setWeather" and id ~= "auto" and not Config.WEATHER[id] then
		return false, "Bilinmeyen hava"
	end
	if action == "setSeason" and id ~= "auto" and not validSeason(id) then
		return false, "Bilinmeyen mevsim"
	end
	-- SeasonService ortak geçiş callback'iyle tüm oyuncuların eski hava gelirini önce kapatır.
	-- Bu çağrıdan önce ID doğrulanır; geçersiz komut hiçbir ekonomik yan etki üretmez.
	local override = if id == "auto" then nil else id
	if action == "setWeather" then
		local ok = SeasonService.setAdminWeather(override)
		return ok, if ok then "Hava güncellendi" else "Hava değiştirilemedi"
	end
	local ok = SeasonService.setAdminSeason(override)
	return ok, if ok then "Mevsim güncellendi" else "Mevsim değiştirilemedi"
end

local function onRequest(player: Player, action: unknown, value: unknown, requestId: unknown)
	-- IsAdmin yalnızca arayüz ipucudur; güvenlik kontrolünde hiçbir zaman okunmaz.
	if not AdminPolicy.isAllowed(player.UserId) then
		return
	end
	if not AdminPolicy.validRequestId(requestId) or not AdminPolicy.validAction(action) then
		return
	end
	local id = requestId :: number
	if id <= (highWater[player] or 0) then
		return
	end
	highWater[player] = id
	local actionName = action :: string
	if not validValue(actionName, value) then
		return
	end
	if not RateLimiter.allow(player, "admin", 0.3) then
		if RateLimiter.allow(player, "adminThrottle", 0.5) then
			Remotes.get("AdminResult"):FireClient(player, id, false, "Lütfen kısa bir süre bekle")
		end
		return
	end
	local ok, message = execute(player, actionName, value)
	Remotes.get("AdminResult"):FireClient(player, id, ok, message)
end

local function markPlayer(player: Player)
	player:SetAttribute("IsAdmin", AdminPolicy.isAllowed(player.UserId))
end

function AdminService.init()
	if initialized then
		return
	end
	initialized = true
	Players.PlayerAdded:Connect(markPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		highWater[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		markPlayer(player)
	end
	Remotes.get("RequestAdminAction").OnServerEvent:Connect(onRequest)
end

return AdminService
