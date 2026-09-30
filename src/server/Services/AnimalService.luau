--!strict
-- Hayvan satın alma ve büyüme (yavru → genç → yetişkin).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Rewards = require(Shared:WaitForChild("Modules"):WaitForChild("Rewards"))
local Merchant = require(Shared:WaitForChild("Modules"):WaitForChild("Merchant"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))
local Metrics = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Metrics"))

local AnimalService = {}

-- Yavru hayvanları ilk uygun bölgelere ekler (normal alım ve gezgin tüccar ortak kullanır)
local function addAnimals(data: any, animalId: string, amount: number)
	local bornAt = DateTime.now().UnixTimestampMillis / 1000
	for _ = 1, amount do
		local targetZone = FarmMath.findZoneForAnimal(data, animalId)
		if not targetZone then
			break -- Çağıran boş yer denetimini yapmış olmalı
		end
		table.insert(data.animals, {
			uid = HttpService:GenerateGUID(false),
			animalId = animalId,
			zoneId = targetZone,
			stage = "calf",
			bornAt = bornAt,
		})
	end
end

function AnimalService.tryBuy(player: Player, animalId: unknown, count: unknown?): (boolean, string?)
	if not RateLimiter.allow(player, "purchase", 0.2) then
		return false, nil -- Spam; sessizce yoksay
	end

	if typeof(animalId) ~= "string" or not RateLimiter.validId(animalId) or not Config.ANIMALS[animalId] then
		return false, "Bilinmeyen hayvan"
	end
	-- Toplu alım: yalnızca izin verilen çarpanlar; miktar ve fiyat sunucuda hesaplanır.
	local amount = 1
	if count ~= nil then
		if typeof(count) ~= "number" or count % 1 ~= 0 or not table.find(Config.BULK_MULTIPLIERS, count) then
			return false, "Geçersiz miktar"
		end
		amount = count :: number
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true or not PlotService.getPlot(player) then
		return false, "Veri henüz yüklenmedi"
	end

	local zoneId, reason = FarmMath.findZoneForAnimal(data, animalId)
	if not zoneId then
		return false, reason
	end
	local free = FarmMath.getFreeSlots(data, animalId)
	if free < amount then
		return false, `Yeterli yer yok ({free} boş yer var)`
	end

	local price = FarmMath.getBulkPrice(data, animalId, amount)
	EconomyService.settlePlayer(player)
	if not PlayerDataService.trySpend(player, price) then
		return false, `Yeterli para yok ({FarmMath.formatMoney(price)})`
	end

	addAnimals(data, animalId, amount)
	Rewards.recordInvest(data, DateTime.now().UnixTimestamp)
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	Metrics.increment("AnimalsPurchased")
	PlotService.refreshPlayerWorld(player)
	return true, nil
end

-- Gezgin tüccarın indirimli hayvan teklifini alır: teklif, fiyat ve adet sunucuda yeniden hesaplanır.
function AnimalService.tryBuyMerchantOffer(player: Player): (boolean, string?)
	if not RateLimiter.allow(player, "purchase", 0.2) then
		return false, nil
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true or not PlotService.getPlot(player) then
		return false, "Veri henüz yüklenmedi"
	end
	local offer = Merchant.offer(data, player.UserId, DateTime.now().UnixTimestamp)
	if not offer then
		return false, "Gezgin tüccar şu an teklif sunmuyor"
	end
	EconomyService.settlePlayer(player)
	if not PlayerDataService.trySpend(player, offer.price) then
		return false, `Yeterli para yok ({FarmMath.formatMoney(offer.price)})`
	end
	-- Alındı işareti hemen yazılır; tekrarlanan ya da gecikmiş istek ikinci teklifi alamaz.
	data.merchant = { key = offer.cycle, bought = true }
	addAnimals(data, offer.animalId, offer.count)
	Rewards.recordInvest(data, DateTime.now().UnixTimestamp)
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	Metrics.increment("MerchantOffersBought")
	PlotService.refreshPlayerWorld(player)
	return true, nil
end

function AnimalService.tryReplaceFish(player: Player, uid: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "purchase", 0.2) then
		return false, nil
	end
	if typeof(uid) ~= "string" or not RateLimiter.validId(uid) then
		return false, "Geçersiz balık"
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true or not PlotService.getPlot(player) then
		return false, "Veri henüz yüklenmedi"
	end
	for index, animal in data.animals do
		if animal.uid ~= uid then
			continue
		end
		local zone = Config.ZONES[animal.zoneId]
		if
			animal.animalId ~= "anchovy"
			or not zone
			or not data.unlockedZones[animal.zoneId]
			or not table.find(zone.allowedAnimals, "seabass")
		then
			return false, "Bu balık levrekle değiştirilemez"
		end
		local price = FarmMath.getFishReplacementPrice(data)
		EconomyService.settlePlayer(player)
		if not PlayerDataService.trySpend(player, price) then
			return false, `Yeterli para yok ({FarmMath.formatMoney(price)})`
		end
		data.animals[index] = {
			uid = HttpService:GenerateGUID(false),
			animalId = "seabass",
			zoneId = animal.zoneId,
			stage = "calf",
			bornAt = DateTime.now().UnixTimestampMillis / 1000,
		}
		PlayerDataService.pushState(player)
		PlayerDataService.requestSave(player)
		Metrics.increment("FishReplaced")
		PlotService.refreshPlayerWorld(player)
		return true, nil
	end
	return false, "Balık artık bulunamıyor"
end

local function respond(player: Player, requestId: unknown, ok: boolean, message: string?)
	-- Spam kontrolü nil mesaj döner; cevap trafiğini de sınırla.
	if not ok and message == nil then
		if typeof(requestId) ~= "number" or not RateLimiter.allow(player, "purchaseThrottleReply", 0.5) then
			return
		end
		message = "Çok hızlı işlem yapıyorsun; biraz bekle."
	end
	if not ok then
		Metrics.increment("PurchaseRejected")
	end
	if typeof(requestId) == "number" then
		Remotes.get("PurchaseResult"):FireClient(player, requestId, ok, message)
	else
		Remotes.get("Notify"):FireClient(player, message, if ok then "success" else "error")
	end
end

-- Evresi değişen hayvan varsa adayı yeniden çizer
local function updateGrowth(player: Player, farm: any?)
	local data = farm or PlayerDataService.tryGet(player)
	if not data then
		return
	end
	local now = os.time()
	local speedByAnimal: { [string]: number } = {}
	local changed = false
	for _, animal in data.animals do
		local speedKey = `{animal.animalId}|{animal.zoneId}`
		local speed = speedByAnimal[speedKey]
		if not speed then
			speed = FarmMath.getGrowthSpeed(data, animal.animalId, animal.zoneId)
			speedByAnimal[speedKey] = speed
		end
		local stage = FarmMath.getStage(animal.bornAt, now, speed)
		if stage ~= animal.stage then
			animal.stage = stage
			changed = true
		end
	end
	if changed then
		PlayerDataService.pushState(player)
		PlotService.refreshPlayerWorld(player)
	end
end

function AnimalService.init()
	Remotes.get("RequestBuyMerchantOffer").OnServerEvent
		:Connect(function(player: Player, _value: unknown, requestId: unknown, expectedFarmId: unknown)
			if not RateLimiter.acceptRequest(player, requestId) then
				return
			end
			local data = PlayerDataService.tryGet(player)
			if not data or expectedFarmId ~= data.activeMainFarmId then
				if RateLimiter.allow(player, "farmContextReply", 0.5) then
					respond(player, requestId, false, "Etkin çiftlik değişti; işlemi yeni çiftlikte tekrar seç.")
				end
				return
			end
			local ok, err = AnimalService.tryBuyMerchantOffer(player)
			respond(player, requestId, ok, if ok then "Gezgin tüccardan indirimli hayvanlar geldi!" else err)
		end)
	Remotes.get("RequestBuyAnimal").OnServerEvent
		:Connect(
			function(player: Player, animalId: unknown, requestId: unknown, expectedFarmId: unknown, count: unknown)
				if not RateLimiter.acceptRequest(player, requestId) then
					return
				end
				local data = PlayerDataService.tryGet(player)
				if not data or expectedFarmId ~= data.activeMainFarmId then
					if RateLimiter.allow(player, "farmContextReply", 0.5) then
						respond(
							player,
							requestId,
							false,
							"Etkin çiftlik değişti; işlemi yeni çiftlikte tekrar seç."
						)
					end
					return
				end
				local ok, err = AnimalService.tryBuy(player, animalId, count)
				if ok then
					local animalConfig = Config.ANIMALS[animalId :: string]
					err = if typeof(count) == "number" and count > 1
						then `{count} {animalConfig.displayName} geldi!`
						else `Yeni {animalConfig.displayName} geldi!`
				end
				respond(player, requestId, ok, err)
			end
		)

	Remotes.get("RequestReplaceFish").OnServerEvent
		:Connect(function(player: Player, uid: unknown, requestId: unknown, expectedFarmId: unknown)
			if not RateLimiter.acceptRequest(player, requestId) then
				return
			end
			local data = PlayerDataService.tryGet(player)
			if not data or expectedFarmId ~= data.activeMainFarmId then
				if RateLimiter.allow(player, "farmContextReply", 0.5) then
					respond(player, requestId, false, "Etkin çiftlik değişti; işlemi yeni çiftlikte tekrar seç.")
				end
				return
			end
			local ok, err = AnimalService.tryReplaceFish(player, uid)
			respond(player, requestId, ok, if ok then "Hamsi yavru levrekle değiştirildi!" else err)
		end)

	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				for _, farmId in PlayerDataService.getFarmIds(player) do
					updateGrowth(player, PlayerDataService.getFarmView(player, farmId))
				end
			end
		end
	end)
end

return AnimalService
