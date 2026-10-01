--!strict
-- Oyuncudan oyuncuya para gönderme. İstemci yalnızca (alıcı UserId, tutar, requestId) yollar; alıcı, tutar ve bakiye sunucuda doğrulanır.
-- Düşme ve ekleme aynı adımdadır (gönderen yetmezse hiçbir şey olmaz); alıcıya `addRefund` ile eklenir, böylece ömür boyu
-- kazanç/başarımlara ve telemetri kaynak/gider kalemlerine girmez (para yeni üretilmez, yalnızca el değiştirir).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local RequestGuard = require(script.Parent:WaitForChild("RequestGuard"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))
local TransferRules = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("TransferRules"))

local TransferService = {}

local function findPlayer(userId: number): Player?
	for _, candidate in Players:GetPlayers() do
		if candidate.UserId == userId then
			return candidate
		end
	end
	return nil
end

local function ready(player: Player): boolean
	return PlayerDataService.tryGet(player) ~= nil and player:GetAttribute("WorldReady") == true
end

function TransferService.trySend(player: Player, targetUserId: unknown, amount: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "sendMoney", TransferRules.COOLDOWN) then
		return false, nil
	end
	if not TransferRules.validUserId(targetUserId) or not TransferRules.validAmount(amount) then
		return false, "Geçersiz tutar ya da oyuncu"
	end
	if targetUserId == player.UserId then
		return false, "Kendine para gönderemezsin"
	end
	local target = findPlayer(targetUserId :: number)
	if not target then
		return false, "Oyuncu bu sunucuda değil"
	end
	if not ready(player) then
		return false, "Çiftliğin henüz hazır değil"
	end
	if not ready(target) then
		return false, "Alıcının çiftliği henüz hazır değil"
	end
	-- Önce iki tarafın birikmiş geliri kapanır; bakiyeler güncel olsun.
	EconomyService.settlePlayer(player)
	EconomyService.settlePlayer(target)
	local senderData = PlayerDataService.tryGet(player)
	local receiverData = PlayerDataService.tryGet(target)
	if not senderData or not receiverData then
		return false, "Kayıt oturumu artık etkin değil"
	end
	local value = amount :: number
	local allowed, problem = TransferRules.check(senderData.cash, receiverData.cash, value)
	if not allowed then
		return false, problem
	end
	if not PlayerDataService.trySpend(player, value) then
		return false, "Bakiyen yetmiyor"
	end
	PlayerDataService.addRefund(target, value)
	PlayerDataService.pushState(player)
	PlayerDataService.pushState(target)
	PlayerDataService.requestSave(player)
	PlayerDataService.requestSave(target)
	Remotes.get("Notify")
		:FireClient(target, `{player.DisplayName} sana {FarmMath.formatMoney(value)} gönderdi`, "money")
	local sentText = `{target.DisplayName} oyuncusuna {FarmMath.formatMoney(value)} gönderildi`
	Remotes.get("Notify"):FireClient(player, sentText, "money")
	return true, `{target.DisplayName} oyuncusuna {FarmMath.formatMoney(value)} gönderildi`
end

function TransferService.init()
	Remotes.get("RequestSendMoney").OnServerEvent
		:Connect(function(player: Player, targetUserId: unknown, amount: unknown, requestId: unknown)
			if not RateLimiter.acceptRequest(player, requestId) then
				return
			end
			local ok, message = TransferService.trySend(player, targetUserId, amount)
			RequestGuard.reply(player, requestId, ok, message)
		end)
end

return TransferService
