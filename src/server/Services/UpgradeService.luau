--!strict
-- Yol haritası satın alımları (bölgeler, ahır seviyeleri, güçlendirmeler).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Rewards = require(Shared:WaitForChild("Modules"):WaitForChild("Rewards"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))
local Metrics = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Metrics"))

local UpgradeService = {}

function UpgradeService.tryBuy(player: Player, upgradeId: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "purchase", 0.2) then
		return false, nil
	end
	if typeof(upgradeId) ~= "string" or not RateLimiter.validId(upgradeId) then
		return false, "Geçersiz istek"
	end
	local upgrade = Config.getUpgrade(upgradeId)
	if not upgrade then
		return false, "Bilinmeyen yükseltme"
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true or not PlotService.getPlot(player) then
		return false, "Veri henüz yüklenmedi"
	end

	-- Ada teması: yalnızca bu çiftliğin adalarındaki yükseltmeler alınabilir (istemci başka ada isteyemez)
	if not Config.themeHasIsland(data.activeMainFarmId, Config.getUpgradeIsland(upgrade)) then
		return false, "Bu ada bu çiftlikte yok"
	end
	local status, missing = FarmMath.getUpgradeStatus(data, upgrade.id)
	if status == "owned" then
		return false, "Buna zaten sahipsin"
	elseif status == "locked" then
		return false, `Önce: {table.concat(missing, ", ")}`
	end

	EconomyService.settlePlayer(player)
	local price = FarmMath.getUpgradeCost(data, upgrade)
	if not PlayerDataService.trySpend(player, price) then
		return false, `Yeterli para yok ({FarmMath.formatMoney(price)})`
	end

	local previousSpeeds: { [string]: number } = {}
	if upgrade.growthSpeed or upgrade.growthBoost then
		for _, animal in data.animals do
			previousSpeeds[animal.animalId] = FarmMath.getGrowthSpeed(data, animal.animalId)
		end
	end
	data.purchased[upgrade.id] = true
	FarmMath.applyDerived(data)
	FarmMath.preserveGrowthProgress(data, previousSpeeds, DateTime.now().UnixTimestampMillis / 1000)
	Rewards.recordInvest(data, DateTime.now().UnixTimestamp)
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	Metrics.increment("UpgradesPurchased")
	PlotService.refreshPlayerWorld(player)
	return true, nil
end

-- Irk geliştirme: seçili çiftlikteki bir türün seviyesini bir artırır (para sunucuda düşülür)
function UpgradeService.tryUpgradeLineage(player: Player, animalId: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "purchase", 0.2) then
		return false, nil
	end
	if typeof(animalId) ~= "string" or not RateLimiter.validId(animalId) or not Config.ANIMALS[animalId] then
		return false, "Geçersiz istek"
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true then
		return false, "Veri henüz yüklenmedi"
	end
	local status, reason, cost = FarmMath.getLineageStatus(data, animalId)
	if status == "max" then
		return false, "Bu ırk zaten en üst seviyede"
	elseif status == "locked" then
		return false, reason
	end
	EconomyService.settlePlayer(player)
	if not PlayerDataService.trySpend(player, cost) then
		return false, `Yeterli para yok ({FarmMath.formatMoney(cost)})`
	end
	local lineage = data.lineage or {}
	data.lineage = lineage
	lineage[animalId] = FarmMath.getLineageLevel(data, animalId) + 1
	Rewards.recordInvest(data, DateTime.now().UnixTimestamp)
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	Metrics.increment("LineageUpgraded")
	PlotService.refreshPlayerWorld(player) -- Hayvanların üstündeki ırk rozeti yenilenir
	return true, nil
end

-- Satın al ve sonucu oyuncuya bildir (yol haritası düğmesi ve ada tabelası ortak kullanır)
local function buyAndNotify(player: Player, upgradeId: unknown, requestId: unknown)
	if not RateLimiter.acceptRequest(player, requestId) then
		return
	end
	local ok, err = UpgradeService.tryBuy(player, upgradeId)
	if ok then
		local upgrade = Config.getUpgrade(upgradeId :: string)
		if upgrade and upgrade.kind == "island" and upgrade.islandId then
			local island = Config.FARM_ISLANDS[upgrade.islandId]
			err = `{upgrade.displayName} açıldı! {island.trait}`
		elseif upgrade then
			err = `{upgrade.displayName} alındı!`
		end
	end
	if not ok and err == nil then
		if typeof(requestId) ~= "number" or not RateLimiter.allow(player, "purchaseThrottleReply", 0.5) then
			return
		end
		err = "Çok hızlı işlem yapıyorsun; biraz bekle."
	end
	if not ok then
		Metrics.increment("PurchaseRejected")
	end
	if typeof(requestId) == "number" then
		Remotes.get("PurchaseResult"):FireClient(player, requestId, ok, err)
	else
		Remotes.get("Notify"):FireClient(player, err, if ok then "success" else "error")
	end
end

-- Alan genişletme: dolu bir bölgenin kapasitesini bir seviye artırır
function UpgradeService.tryExpandZone(player: Player, zoneId: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "purchase", 0.2) then
		return false, nil
	end
	if typeof(zoneId) ~= "string" or not RateLimiter.validId(zoneId) or not Config.ZONES[zoneId] then
		return false, "Geçersiz istek"
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true then
		return false, "Veri henüz yüklenmedi"
	end
	if not Config.themeHasIsland(data.activeMainFarmId, Config.ZONES[zoneId].island) then
		return false, "Bu ada bu çiftlikte yok"
	end
	local status, reason, cost = FarmMath.getExpansionStatus(data, zoneId)
	if status == "max" then
		return false, "Bu alan zaten en büyük boyutta"
	elseif status == "locked" then
		return false, reason
	end
	EconomyService.settlePlayer(player)
	if not PlayerDataService.trySpend(player, cost) then
		return false, `Yeterli para yok ({FarmMath.formatMoney(cost)})`
	end
	local expansions = data.expansions or {}
	data.expansions = expansions
	expansions[zoneId] = FarmMath.getExpansionLevel(data, zoneId) + 1
	Rewards.recordInvest(data, DateTime.now().UnixTimestamp)
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	Metrics.increment("ZoneExpanded")
	PlotService.refreshPlayerWorld(player)
	return true, nil
end

local function expandAndNotify(player: Player, zoneId: unknown, requestId: unknown)
	if not RateLimiter.acceptRequest(player, requestId) then
		return
	end
	local ok, err = UpgradeService.tryExpandZone(player, zoneId)
	if ok then
		local data = PlayerDataService.tryGet(player) :: any
		local zone = Config.ZONES[zoneId :: string]
		err =
			`{Config.getZoneName(zone, data.activeMainFarmId)} genişletildi! Yeni kapasite: {FarmMath.getZoneCapacity(
				data,
				zoneId :: string
			)}`
	elseif err == nil then
		if typeof(requestId) ~= "number" or not RateLimiter.allow(player, "purchaseThrottleReply", 0.5) then
			return
		end
		err = "Çok hızlı işlem yapıyorsun; biraz bekle."
	end
	if typeof(requestId) == "number" then
		Remotes.get("PurchaseResult"):FireClient(player, requestId, ok, err)
	else
		Remotes.get("Notify"):FireClient(player, err, if ok then "success" else "error")
	end
end

local function lineageAndNotify(player: Player, animalId: unknown, requestId: unknown)
	if not RateLimiter.acceptRequest(player, requestId) then
		return
	end
	local ok, err = UpgradeService.tryUpgradeLineage(player, animalId)
	if ok then
		local data = PlayerDataService.tryGet(player)
		local animal = Config.ANIMALS[animalId :: string]
		err = `{animal.displayName} ırkı Sv.{FarmMath.getLineageLevel(data :: any, animalId :: string)} oldu!`
	elseif err == nil then
		if typeof(requestId) ~= "number" or not RateLimiter.allow(player, "purchaseThrottleReply", 0.5) then
			return
		end
		err = "Çok hızlı işlem yapıyorsun; biraz bekle."
	end
	if typeof(requestId) == "number" then
		Remotes.get("PurchaseResult"):FireClient(player, requestId, ok, err)
	else
		Remotes.get("Notify"):FireClient(player, err, if ok then "success" else "error")
	end
end

function UpgradeService.init()
	Remotes.get("RequestExpandZone").OnServerEvent
		:Connect(function(player: Player, zoneId: unknown, requestId: unknown, expectedFarmId: unknown)
			local data = PlayerDataService.tryGet(player)
			if not data or expectedFarmId ~= data.activeMainFarmId then
				if typeof(requestId) == "number" and RateLimiter.allow(player, "farmContextReply", 0.5) then
					Remotes.get("PurchaseResult"):FireClient(
						player,
						requestId,
						false,
						"Etkin çiftlik değişti; işlemi yeni çiftlikte tekrar seç."
					)
				end
				return
			end
			expandAndNotify(player, zoneId, requestId)
		end)
	Remotes.get("RequestUpgradeLineage").OnServerEvent
		:Connect(function(player: Player, animalId: unknown, requestId: unknown, expectedFarmId: unknown)
			local data = PlayerDataService.tryGet(player)
			if not data or expectedFarmId ~= data.activeMainFarmId then
				if typeof(requestId) == "number" and RateLimiter.allow(player, "farmContextReply", 0.5) then
					Remotes.get("PurchaseResult"):FireClient(
						player,
						requestId,
						false,
						"Etkin çiftlik değişti; işlemi yeni çiftlikte tekrar seç."
					)
				end
				return
			end
			lineageAndNotify(player, animalId, requestId)
		end)

	Remotes.get("RequestBuyUpgrade").OnServerEvent
		:Connect(function(player: Player, upgradeId: unknown, requestId: unknown, expectedFarmId: unknown)
			local data = PlayerDataService.tryGet(player)
			if not data or expectedFarmId ~= data.activeMainFarmId then
				if typeof(requestId) == "number" and RateLimiter.allow(player, "farmContextReply", 0.5) then
					Remotes.get("PurchaseResult"):FireClient(
						player,
						requestId,
						false,
						"Etkin çiftlik değişti; işlemi yeni çiftlikte tekrar seç."
					)
				end
				return
			end
			buyAndNotify(player, upgradeId, requestId)
		end)

	-- Kilitli adanın tabelasındaki "Satın Al" düğmesi: sadece takımadanın sahibi alabilir
	for _, plot in PlotService.getAllPlots() do
		for _, prompt in plot:GetDescendants() do
			if not prompt:IsA("ProximityPrompt") or prompt.Name ~= "BuyIslandPrompt" then
				continue
			end
			prompt.Triggered:Connect(function(player: Player)
				if PlotService.getOwner(plot) ~= player or PlotService.getPlot(player) ~= plot then
					if RateLimiter.allow(player, "invalidPrompt", 1) then
						Remotes.get("Notify"):FireClient(player, "Bu ada başka bir çiftliğe ait.", "error")
					end
					return
				end
				buyAndNotify(player, prompt:GetAttribute("UpgradeId"), nil)
			end)
		end
	end
end

return UpgradeService
