--!strict
-- Ahır siparişleri: depodaki ürünler para karşılığı teslim edilir. Teklif, miktar ve ödül sunucuda yeniden hesaplanır;
-- istemci yalnızca teklif anahtarı gönderir. Ürünler ve teslim işareti tek adımda değişir (çifte teslim olmaz).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local Rewards = require(Shared:WaitForChild("Modules"):WaitForChild("Rewards"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local RequestGuard = require(script.Parent:WaitForChild("RequestGuard"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))
local Metrics = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Metrics"))

local ContractService = {}

local FARM_GUARD: RequestGuard.FarmOptions = { message = "Etkin çiftlik değişti; siparişi tekrar seç." }

function ContractService.tryFulfill(player: Player, key: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "fulfillContract", 0.5) then
		return false, nil
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true then
		return false, "Çiftliğin henüz hazır değil"
	end
	local now = DateTime.now().UnixTimestamp
	local reward, problem = FarmMath.fulfillContract(data, key, now, Environment.getSeason(data.envOverride).orderBonus)
	if not reward then
		return false, problem
	end
	Metrics.increment("ContractsCompleted")
	Rewards.recordInvest(data, now) -- sipariş teslimi de mevsimin "yatırım" hedefine sayılır (geç oyunda yeni hayvan/yükseltme kalmasa da)
	PlayerDataService.addCash(player, reward, "order")
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	return true, `Ahır siparişi teslim edildi: +{FarmMath.formatMoney(reward)}`
end

function ContractService.init()
	Remotes.get("RequestFulfillContract").OnServerEvent
		:Connect(function(player: Player, key: unknown, requestId: unknown, expectedFarmId: unknown)
			if not RateLimiter.acceptRequest(player, requestId) then
				return
			end
			if not RequestGuard.activeFarm(player, requestId, expectedFarmId, FARM_GUARD) then
				return
			end
			local ok, message = ContractService.tryFulfill(player, key)
			if message == nil and not ok and typeof(requestId) == "number" then
				message = "Çok hızlı işlem yapıyorsun; biraz bekle."
			end
			if message and typeof(requestId) == "number" then
				Remotes.get("PurchaseResult"):FireClient(player, requestId, ok, message)
			end
		end)
end

return ContractService
