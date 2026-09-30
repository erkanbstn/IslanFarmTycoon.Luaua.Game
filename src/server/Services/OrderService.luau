--!strict
-- Yol haritasından sonra tekrar eden üretim siparişi. Offline sipariş üretimi yoktur.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local OrderBoard = require(Shared:WaitForChild("Modules"):WaitForChild("OrderBoard"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))
local OrderRules = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("OrderRules"))
local Metrics = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Metrics"))

local OrderService = {}

local function assignOrder(player: Player, farm: any?): boolean
	local data = farm or PlayerDataService.tryGet(player)
	if not data or not OrderRules.isUnlocked(data, Config) then
		return false
	end
	local animalId = OrderRules.chooseAnimal(data, Config)
	if not animalId then
		return false
	end
	data.order =
		{ uid = HttpService:GenerateGUID(false), animalId = animalId, progress = 0, target = Config.ORDER_UNITS }
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	return true
end

function OrderService.update(player: Player, elapsed: number, startedAt: number?, endedAt: number?, farm: any?)
	local data = farm or PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true or not OrderRules.isUnlocked(data, Config) then
		return
	end
	if not data.order then
		assignOrder(player, data)
		-- Yeni atanan sipariş geçmiş tick için üretim kazanmaz.
		return
	end
	local order = data.order
	local anyOwned = false
	local adultSeconds = 0
	local now = endedAt or DateTime.now().UnixTimestampMillis / 1000
	local start = startedAt or now - elapsed
	for _, animal in data.animals do
		if animal.animalId ~= order.animalId or not data.unlockedZones[animal.zoneId] then
			continue
		end
		anyOwned = true
		-- Üretim tesisinde çalışan hayvan bu sürede sipariş ürünü de vermez.
		if FarmMath.isInProduction(animal, now) then
			continue
		end
		adultSeconds += OrderRules.adultSeconds(
			animal.bornAt,
			FarmMath.getGrowthSpeed(data, animal.animalId, animal.zoneId),
			start,
			now,
			Config
		)
	end
	if not anyOwned then
		data.order = nil
		if not assignOrder(player, data) then
			PlayerDataService.pushState(player)
			PlayerDataService.requestSave(player)
		end
		return
	end
	order.progress = OrderRules.advance(order.progress, 1, adultSeconds, Config, order.target)
end

function OrderService.tryClaim(player: Player, uid: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "claimOrder", 0.5) then
		return false, nil
	end
	if not RateLimiter.validId(uid) then
		return false, "Geçersiz sipariş"
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true then
		return false, "Çiftliğin henüz hazır değil"
	end
	local order = data.order
	if not order or order.uid ~= uid or not OrderRules.isUnlocked(data, Config) then
		return false, "Sipariş artık geçerli değil"
	end
	if order.progress < order.target then
		return false, "Sipariş henüz tamamlanmadı"
	end
	-- Ödül: pano çarpanı ve aktif mevsim etkinliği bonusu dahil (sunucuda hesaplanır)
	local reward = OrderBoard.claimReward(order, Environment.getSeason(data.envOverride).orderBonus)
	-- UID hemen tüketilir. Aynı veya gecikmiş istek ikinci ödülü alamaz.
	data.order = nil
	data.ordersCompleted += 1
	Metrics.increment("OrdersCompleted")
	PlayerDataService.addCash(player, reward)
	if not assignOrder(player) then
		PlayerDataService.pushState(player)
	end
	PlayerDataService.requestSave(player)
	return true, `Sipariş teslim edildi: +{FarmMath.formatMoney(reward)}`
end

-- Panodan sipariş seç: seçenekler sunucuda yeniden hesaplanır (pencere eskiyse reddedilir).
-- Etkin sipariş tamamlanmışsa önce teslim edilmelidir; aksi halde seçim ilerlemeyi sıfırlar.
function OrderService.tryPick(player: Player, key: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "pickOrder", 0.5) then
		return false, nil
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true then
		return false, "Çiftliğin henüz hazır değil"
	end
	if not OrderRules.isUnlocked(data, Config) then
		return false, "Sipariş panosu henüz açılmadı"
	end
	local offer, problem =
		OrderBoard.resolve(data, key, DateTime.now().UnixTimestamp, Environment.getSeason(data.envOverride).orderBonus)
	if not offer then
		return false, problem
	end
	local current = data.order
	if current and current.progress >= current.target then
		return false, "Önce tamamlanan siparişi teslim et"
	end
	data.order = {
		uid = HttpService:GenerateGUID(false),
		animalId = offer.animalId,
		progress = 0,
		target = offer.units,
		rewardFactor = offer.rewardFactor,
	}
	Metrics.increment("OrdersPicked")
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	return true, "Yeni sipariş seçildi"
end

function OrderService.init()
	Remotes.get("RequestPickOrder").OnServerEvent
		:Connect(function(player: Player, key: unknown, requestId: unknown, expectedFarmId: unknown)
			if not RateLimiter.acceptRequest(player, requestId) then
				return
			end
			local data = PlayerDataService.tryGet(player)
			if not data or expectedFarmId ~= data.activeMainFarmId then
				if typeof(requestId) == "number" and RateLimiter.allow(player, "farmContextReply", 0.5) then
					Remotes.get("PurchaseResult")
						:FireClient(player, requestId, false, "Etkin çiftlik değişti; siparişi tekrar seç.")
				end
				return
			end
			local ok, message = OrderService.tryPick(player, key)
			if message and typeof(requestId) == "number" then
				Remotes.get("PurchaseResult"):FireClient(player, requestId, ok, message)
			end
		end)

	Remotes.get("RequestClaimOrder").OnServerEvent
		:Connect(function(player: Player, uid: unknown, requestId: unknown, expectedFarmId: unknown)
			if not RateLimiter.acceptRequest(player, requestId) then
				return
			end
			local data = PlayerDataService.tryGet(player)
			if not data or expectedFarmId ~= data.activeMainFarmId then
				if typeof(requestId) == "number" and RateLimiter.allow(player, "farmContextReply", 0.5) then
					Remotes.get("PurchaseResult")
						:FireClient(player, requestId, false, "Etkin çiftlik değişti; siparişi tekrar seç.")
				end
				return
			end
			local ok, message = OrderService.tryClaim(player, uid)
			if
				not ok
				and message == nil
				and typeof(requestId) == "number"
				and RateLimiter.allow(player, "purchaseThrottleReply", 0.5)
			then
				message = "Çok hızlı işlem yapıyorsun; biraz bekle."
			end
			if message then
				if typeof(requestId) == "number" then
					Remotes.get("PurchaseResult"):FireClient(player, requestId, ok, message)
				else
					Remotes.get("Notify"):FireClient(player, message, if ok then "success" else "error")
				end
			end
		end)
end

return OrderService
