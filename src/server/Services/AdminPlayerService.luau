--!strict
-- Yönetici (yalnızca AdminPolicy sahibi) başka bir oyuncuya: para ver / al / ayarla, kayıt özeti gör, sunucudan at.
-- Hedef bu sunucudaki oyunculardan UserId ile bulunur; kendi profili de hedef olabilir. Yetki, tutar ve hedef sunucuda doğrulanır.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local AdminPolicy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("AdminPolicy"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))

local AdminPlayerService = {}
local highWater: { [Player]: number } = {}
local initialized = false

local CASH_CAP = 1e15

local function findPlayer(userId: number): Player?
	for _, candidate in Players:GetPlayers() do
		if candidate.UserId == userId then
			return candidate
		end
	end
	return nil
end

local function execute(target: Player, action: string, value: unknown): (boolean, string)
	if action == "kickPlayer" then
		target:Kick("Yönetici tarafından sunucudan çıkarıldın.")
		return true, `{target.DisplayName} sunucudan atıldı`
	end
	if target:GetAttribute("WorldReady") ~= true or not PlayerDataService.tryGet(target) then
		return false, "Oyuncunun çiftliği henüz hazır değil"
	end
	EconomyService.settlePlayer(target)
	local data = PlayerDataService.tryGet(target)
	if not data then
		return false, "Kayıt oturumu artık etkin değil"
	end
	if action == "inspect" then
		return true,
			`{target.DisplayName} · Kasa {FarmMath.formatMoney(data.cash)} · Hayvan {#data.animals} · Çiftlik {tostring(
				data.activeMainFarmId
			)}`
	end
	local amount = value :: number
	local before = data.cash
	if action == "giveCash" then
		if before + amount > CASH_CAP then
			return false, "Bakiye sınırı aşılıyor"
		end
		data.cash = before + amount
	elseif action == "takeCash" then
		data.cash = math.max(0, before - amount)
	else
		data.cash = amount
	end
	PlayerDataService.pushState(target)
	PlayerDataService.requestSave(target)
	local notice = if action == "giveCash"
		then `Yönetici sana {FarmMath.formatMoney(amount)} verdi`
		elseif action == "takeCash" then `Yönetici kasandan {FarmMath.formatMoney(before - data.cash)} aldı`
		else `Yönetici kasanı {FarmMath.formatMoney(data.cash)} yaptı`
	Remotes.get("Notify"):FireClient(target, notice, if action == "takeCash" then "info" else "money")
	return true, `{target.DisplayName} kasası: {FarmMath.formatMoney(before)} → {FarmMath.formatMoney(data.cash)}`
end

local function validValue(action: string, value: unknown): boolean
	if action == "giveCash" or action == "takeCash" then
		return AdminPolicy.validCash(value, true)
	elseif action == "setTargetCash" then
		return AdminPolicy.validCash(value, false)
	end
	return true -- inspect / kickPlayer değer taşımaz
end

local function onRequest(player: Player, targetUserId: unknown, action: unknown, value: unknown, requestId: unknown)
	if not AdminPolicy.isAllowed(player.UserId) then
		return
	end
	if
		not AdminPolicy.validRequestId(requestId)
		or not AdminPolicy.validTargetAction(action)
		or not AdminPolicy.validTargetUserId(targetUserId)
	then
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
	if not RateLimiter.allow(player, "adminPlayer", 0.3) then
		if RateLimiter.allow(player, "adminPlayerThrottle", 0.5) then
			Remotes.get("AdminResult"):FireClient(player, id, false, "Lütfen kısa bir süre bekle")
		end
		return
	end
	local target = findPlayer(targetUserId :: number)
	if not target then
		Remotes.get("AdminResult"):FireClient(player, id, false, "Oyuncu bu sunucuda değil")
		return
	end
	local ok, message = execute(target, actionName, value)
	Remotes.get("AdminResult"):FireClient(player, id, ok, message)
end

function AdminPlayerService.init()
	if initialized then
		return
	end
	initialized = true
	Players.PlayerRemoving:Connect(function(player: Player)
		highWater[player] = nil
	end)
	Remotes.get("RequestAdminPlayerAction").OnServerEvent:Connect(onRequest)
end

return AdminPlayerService
