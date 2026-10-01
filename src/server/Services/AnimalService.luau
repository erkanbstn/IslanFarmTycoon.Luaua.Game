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
local RequestGuard = require(script.Parent:WaitForChild("RequestGuard"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))
local Metrics = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Metrics"))
local TelemetryService = require(script.Parent:WaitForChild("TelemetryService"))

local AnimalService = {}

-- Hayvan taleplerinde etkin çiftlik uyuşmazlığı kimliksiz istekte de bildirilir ve reddedilen alım olarak sayılır.
local FARM_GUARD: RequestGuard.FarmOptions = { notifyWithoutId = true, countRejected = true }

local function reply(player: Player, requestId: unknown, ok: boolean, message: string?)
	RequestGuard.reply(player, requestId, ok, message, true)
end

-- Yavru hayvanları ilk uygun bölgelere ekler (normal alım ve gezgin tüccar ortak kullanır)
local function addAnimals(data: any, animalId: string, amount: number)
	local now = DateTime.now().UnixTimestampMillis / 1000
	for _ = 1, amount do
		local targetZone = FarmMath.findZoneForAnimal(data, animalId)
		if not targetZone then
			break -- Çağıran boş yer denetimini yapmış olmalı
		end
		-- Çiftliğin ilk hayvanları yetişkin doğar (bornAt = 0), sonrakiler yavru
		local bornAt = FarmMath.getNewAnimalBornAt(data, now)
		table.insert(data.animals, {
			uid = HttpService:GenerateGUID(false),
			animalId = animalId,
			zoneId = targetZone,
			stage = if bornAt == 0 then "adult" else "calf",
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
	if not PlayerDataService.trySpend(player, price, "animal", animalId) then
		return false, `Yeterli para yok ({FarmMath.formatMoney(price)})`
	end

	addAnimals(data, animalId, amount)
	TelemetryService.funnel(player, "first_animal")
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
	if not PlayerDataService.trySpend(player, offer.price, "animal", offer.animalId) then
		return false, `Yeterli para yok ({FarmMath.formatMoney(offer.price)})`
	end
	-- Alındı işareti hemen yazılır; tekrarlanan ya da gecikmiş istek ikinci teklifi alamaz.
	data.merchant = { key = offer.cycle, bought = true }
	addAnimals(data, offer.animalId, offer.count)
	TelemetryService.funnel(player, "first_animal")
	Rewards.recordInvest(data, DateTime.now().UnixTimestamp)
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	Metrics.increment("MerchantOffersBought")
	PlotService.refreshPlayerWorld(player)
	return true, nil
end

-- Ürünle takas: bir hayvanın normal fiyatı, depodaki ürünlerin değerinin GOODS_BARTER.rate katıyla karşılanır. Fiyat, ürün planı ve boş yer
-- sunucuda hesaplanır; ürünler düşer + hayvan eklenir tek adımda (yer yoksa ya da ürün yetmiyorsa hiçbir şey değişmez). Nakit harcanmaz,
-- yani çiftlik fiyat çarpanı ve bölge kapasitesi normal alımla aynıdır; gezgin tüccar indirimi takasa uygulanmaz.
function AnimalService.tryBarter(player: Player, animalId: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "purchase", 0.2) then
		return false, nil
	end
	if typeof(animalId) ~= "string" or not RateLimiter.validId(animalId) or not Config.ANIMALS[animalId] then
		return false, "Bilinmeyen hayvan"
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true or not PlotService.getPlot(player) then
		return false, "Veri henüz yüklenmedi"
	end
	local zoneId, reason = FarmMath.findZoneForAnimal(data, animalId)
	if not zoneId then
		return false, reason
	end
	if FarmMath.getFreeSlots(data, animalId) < 1 then
		return false, "Yeterli yer yok (0 boş yer var)"
	end
	local price = FarmMath.getBulkPrice(data, animalId, 1)
	local plan, have = FarmMath.planGoodsBarter(data, price)
	if not plan then
		return false,
			`Ürünlerin değeri yetmiyor (gereken {FarmMath.formatMoney(price)}, eldeki {FarmMath.formatMoney(have)})`
	end
	EconomyService.settlePlayer(player)
	if not FarmMath.applyGoodsBarter(data, plan) then
		return false, "Ürünler artık yetmiyor"
	end
	addAnimals(data, animalId, 1)
	TelemetryService.funnel(player, "first_animal")
	Rewards.recordInvest(data, DateTime.now().UnixTimestamp)
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	Metrics.increment("AnimalsBartered")
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
		if not PlayerDataService.trySpend(player, price, "animal", "seabass") then
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

-- Hayvan satışı: aynı türün en genci satılır, fiyatın yarısı geri gelir (kazanç sayılmaz). Çiftlikte son hayvan satılmaz.
function AnimalService.trySell(player: Player, animalId: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "purchase", 0.2) then
		return false, nil
	end
	if typeof(animalId) ~= "string" or not RateLimiter.validId(animalId) or not Config.ANIMALS[animalId] then
		return false, "Bilinmeyen hayvan"
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true or not PlotService.getPlot(player) then
		return false, "Veri henüz yüklenmedi"
	end
	local animal = FarmMath.findSellableAnimal(data, animalId)
	if not animal then
		return false,
			if FarmMath.countAnimals(data, animalId) > 0
				then "Çiftlikteki son hayvanı satamazsın"
				else "Bu hayvandan yok"
	end
	local refund = FarmMath.getSellPrice(data, animalId)
	EconomyService.settlePlayer(player)
	local index = table.find(data.animals, animal)
	if not index then
		return false, "Hayvan artık bulunamıyor"
	end
	table.remove(data.animals, index)
	PlayerDataService.addRefund(player, refund, "refund", animalId)
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	Metrics.increment("AnimalsSold")
	PlotService.refreshPlayerWorld(player)
	return true, nil
end

-- Evresi değişen hayvan varsa o çiftliğin adasını yeniden çizer. Etkin çiftlikte istemci durumu da gider;
-- park edilmiş çiftlikte yalnızca kendi adası yenilenir (istemci park edilmiş çiftliğin hayvan evrelerini okumaz).
local function updateGrowth(player: Player, farmId: string)
	local data = PlayerDataService.getFarmView(player, farmId)
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
	if not changed then
		return
	end
	local active = PlayerDataService.tryGet(player)
	if active and active.activeMainFarmId == farmId then
		PlayerDataService.pushState(player)
		PlotService.refreshPlayerWorld(player)
	else
		PlotService.refreshFarmWorld(player, farmId)
	end
end

function AnimalService.init()
	Remotes.get("RequestBuyMerchantOffer").OnServerEvent
		:Connect(function(player: Player, _value: unknown, requestId: unknown, expectedFarmId: unknown)
			if not RateLimiter.acceptRequest(player, requestId) then
				return
			end
			local data = RequestGuard.activeFarm(player, requestId, expectedFarmId, FARM_GUARD)
			if not data then
				return
			end
			local ok, err = AnimalService.tryBuyMerchantOffer(player)
			reply(player, requestId, ok, if ok then "Gezgin tüccardan indirimli hayvanlar geldi!" else err)
		end)
	Remotes.get("RequestBuyAnimal").OnServerEvent
		:Connect(
			function(player: Player, animalId: unknown, requestId: unknown, expectedFarmId: unknown, count: unknown)
				if not RateLimiter.acceptRequest(player, requestId) then
					return
				end
				if not RequestGuard.activeFarm(player, requestId, expectedFarmId, FARM_GUARD) then
					return
				end
				local ok, err = AnimalService.tryBuy(player, animalId, count)
				if ok then
					local animalConfig = Config.ANIMALS[animalId :: string]
					err = if typeof(count) == "number" and count > 1
						then `{count} {animalConfig.displayName} geldi!`
						else `Yeni {animalConfig.displayName} geldi!`
				end
				reply(player, requestId, ok, err)
			end
		)

	Remotes.get("RequestBarterAnimal").OnServerEvent
		:Connect(function(player: Player, animalId: unknown, requestId: unknown, expectedFarmId: unknown)
			if not RateLimiter.acceptRequest(player, requestId) then
				return
			end
			if not RequestGuard.activeFarm(player, requestId, expectedFarmId, FARM_GUARD) then
				return
			end
			local ok, err = AnimalService.tryBarter(player, animalId)
			if ok then
				err = `Ürünlerle takas edildi · Yeni {Config.ANIMALS[animalId :: string].displayName} geldi!`
			end
			reply(player, requestId, ok, err)
		end)

	Remotes.get("RequestSellAnimal").OnServerEvent
		:Connect(function(player: Player, animalId: unknown, requestId: unknown, expectedFarmId: unknown)
			if not RateLimiter.acceptRequest(player, requestId) then
				return
			end
			local data = RequestGuard.activeFarm(player, requestId, expectedFarmId, FARM_GUARD)
			if not data then
				return
			end
			local refund = if typeof(animalId) == "string" and Config.ANIMALS[animalId]
				then FarmMath.getSellPrice(data, animalId)
				else 0
			local ok, err = AnimalService.trySell(player, animalId)
			reply(player, requestId, ok, if ok then `Hayvan satıldı: +{FarmMath.formatMoney(refund)}` else err)
		end)

	Remotes.get("RequestReplaceFish").OnServerEvent
		:Connect(function(player: Player, uid: unknown, requestId: unknown, expectedFarmId: unknown)
			if not RateLimiter.acceptRequest(player, requestId) then
				return
			end
			local data = RequestGuard.activeFarm(player, requestId, expectedFarmId, FARM_GUARD)
			if not data then
				return
			end
			local ok, err = AnimalService.tryReplaceFish(player, uid)
			reply(player, requestId, ok, if ok then "Hamsi yavru levrekle değiştirildi!" else err)
		end)

	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(function()
					for _, farmId in PlayerDataService.getFarmIds(player) do
						updateGrowth(player, farmId)
					end
				end)
				if not ok then
					warn(`[Animal] Büyüme güncellenemedi: {err}`)
					Metrics.increment("LoopError")
					TelemetryService.custom(player, "LoopError")
				end
			end
		end
	end)
end

return AnimalService
