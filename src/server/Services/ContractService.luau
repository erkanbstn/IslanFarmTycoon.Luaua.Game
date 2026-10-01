--!strict
-- Ahır siparişleri: depodaki ürünler para karşılığı teslim edilir. Teklif, miktar ve ödül sunucuda yeniden hesaplanır;
-- istemci yalnızca teklif anahtarı gönderir. Ürünler ve teslim işareti tek adımda değişir (çifte teslim olmaz).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Config = require(Shared:WaitForChild("Config"))
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

-- Hızlı boşaltma: tek üründen "hepsi" ya da "yarısı" depo değerinin GOODS_SELL.rate katına paraya çevrilir. Ürün, kip ve para sunucuda
-- hesaplanır (istemci yalnızca ürün kimliği ve kip gönderir); düşme ve nakit aynı adımdadır, tekrar oynatma `requestId` ile elenir.
function ContractService.trySell(player: Player, goodsId: unknown, mode: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "sellGoods", 0.5) then
		return false, nil
	end
	if typeof(goodsId) ~= "string" or not RateLimiter.validId(goodsId) or not Config.GOODS[goodsId] then
		return false, "Bilinmeyen ürün"
	end
	if mode ~= "all" and mode ~= "half" then
		return false, "Geçersiz miktar"
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true then
		return false, "Çiftliğin henüz hazır değil"
	end
	local cash, amount = FarmMath.sellGoods(data, goodsId, mode)
	if not cash or not amount then
		return false, "Satacak ürün yok"
	end
	Metrics.increment("GoodsSold")
	PlayerDataService.addCash(player, cash, "goodsSale")
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	return true,
		`Ürün satıldı · {Config.GOODS[goodsId].displayName} · {amount} adet · +{FarmMath.formatMoney(cash)}`
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

	Remotes.get("RequestSellGoods").OnServerEvent
		:Connect(function(player: Player, goodsId: unknown, requestId: unknown, expectedFarmId: unknown, mode: unknown)
			if not RateLimiter.acceptRequest(player, requestId) then
				return
			end
			if not RequestGuard.activeFarm(player, requestId, expectedFarmId, FARM_GUARD) then
				return
			end
			local ok, message = ContractService.trySell(player, goodsId, mode)
			RequestGuard.reply(player, requestId, ok, message)
		end)
end

return ContractService
