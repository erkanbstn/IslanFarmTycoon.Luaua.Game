--!strict
-- Yol haritası satın alımları (bölgeler, ahır seviyeleri, güçlendirmeler).

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Rewards = require(Shared:WaitForChild("Modules"):WaitForChild("Rewards"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local RequestGuard = require(script.Parent:WaitForChild("RequestGuard"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))
local Metrics = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Metrics"))
local TelemetryService = require(script.Parent:WaitForChild("TelemetryService"))

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
	if not PlayerDataService.trySpend(player, price, "upgrade", upgrade.id) then
		return false, `Yeterli para yok ({FarmMath.formatMoney(price)})`
	end

	local previousSpeeds = FarmMath.snapshotGrowthSpeeds(data)
	data.purchased[upgrade.id] = true
	FarmMath.applyDerived(data)
	TelemetryService.funnel(player, "first_upgrade")
	if upgrade.kind == "island" and upgrade.islandId then
		TelemetryService.funnel(player, "first_island")
		TelemetryService.progression(player, "island", (FarmMath.countIslands(data)), upgrade.islandId)
	elseif upgrade.kind == "barn" and upgrade.barnLevel then
		if upgrade.barnLevel >= 2 then
			TelemetryService.funnel(player, "barn_2")
		end
		TelemetryService.progression(player, "barn", upgrade.barnLevel, `Barn {upgrade.barnLevel}`)
	end
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
	if not PlayerDataService.trySpend(player, cost, "lineage", animalId) then
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
local function buyAndNotify(player: Player, upgradeId: unknown, requestId: unknown, fromPrompt: boolean?)
	if not RateLimiter.acceptRequest(player, requestId, fromPrompt) then
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
	RequestGuard.reply(player, requestId, ok, err, true)
end

-- Yapı geliştirme: bir bölgeyi ya da üretim tesisini bir seviye yükseltir (faydalar Config.BUILD_UPGRADES profilinden)
function UpgradeService.tryExpandZone(player: Player, targetId: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "purchase", 0.2) then
		return false, nil
	end
	if typeof(targetId) ~= "string" or not RateLimiter.validId(targetId) then
		return false, "Geçersiz istek"
	end
	local zone = Config.ZONES[targetId]
	local recipe = Config.PRODUCTION_RECIPES[targetId]
	if not zone and not recipe then
		return false, "Geçersiz istek"
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true then
		return false, "Veri henüz yüklenmedi"
	end
	local island = if zone then zone.island else (recipe :: any).island
	if not Config.themeHasIsland(data.activeMainFarmId, island) then
		return false, "Bu ada bu çiftlikte yok"
	end
	local status, reason, cost = FarmMath.getExpansionStatus(data, targetId)
	if status == "max" then
		return false, "Bu yapı zaten en üst seviyede"
	elseif status == "locked" then
		return false, reason
	end
	EconomyService.settlePlayer(player)
	if not PlayerDataService.trySpend(player, cost, "expansion") then
		return false, `Yeterli para yok ({FarmMath.formatMoney(cost)})`
	end
	-- Büyüme hızı ve gelir bu seviyeden itibaren değişir; ilerleme korunur
	local previousSpeeds = FarmMath.snapshotGrowthSpeeds(data)
	local expansions = data.expansions or {}
	data.expansions = expansions
	expansions[targetId] = FarmMath.getExpansionLevel(data, targetId) + 1
	FarmMath.preserveGrowthProgress(data, previousSpeeds, DateTime.now().UnixTimestampMillis / 1000)
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
		local name = if zone
			then Config.getZoneName(zone, data.activeMainFarmId)
			else Config.PRODUCTION_RECIPES[zoneId :: string].displayName
		err = `{name} geliştirildi! Seviye {FarmMath.getExpansionLevel(data, zoneId :: string)}`
	end
	RequestGuard.reply(player, requestId, ok, err)
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
	end
	RequestGuard.reply(player, requestId, ok, err)
end

function UpgradeService.init()
	Remotes.get("RequestExpandZone").OnServerEvent
		:Connect(function(player: Player, zoneId: unknown, requestId: unknown, expectedFarmId: unknown)
			if not RequestGuard.activeFarm(player, requestId, expectedFarmId) then
				return
			end
			expandAndNotify(player, zoneId, requestId)
		end)
	Remotes.get("RequestUpgradeLineage").OnServerEvent
		:Connect(function(player: Player, animalId: unknown, requestId: unknown, expectedFarmId: unknown)
			if not RequestGuard.activeFarm(player, requestId, expectedFarmId) then
				return
			end
			lineageAndNotify(player, animalId, requestId)
		end)

	Remotes.get("RequestBuyUpgrade").OnServerEvent
		:Connect(function(player: Player, upgradeId: unknown, requestId: unknown, expectedFarmId: unknown)
			if not RequestGuard.activeFarm(player, requestId, expectedFarmId) then
				return
			end
			buyAndNotify(player, upgradeId, requestId)
		end)

	-- Kilitli adanın tabelasındaki "Satın Al" düğmesi: sadece takımadanın sahibi alabilir.
	-- Ada içeriği çalışma anında yeniden kurulduğundan (tema değişimi) prompt'lara tek tek bağlanılmaz.
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if prompt.Name ~= "BuyIslandPrompt" then
			return
		end
		for _, plot in PlotService.getAllPlots() do
			if prompt:IsDescendantOf(plot) then
				if PlotService.getOwner(plot) ~= player or PlotService.getPlot(player) ~= plot then
					if RateLimiter.allow(player, "invalidPrompt", 1) then
						Remotes.get("Notify"):FireClient(player, "Bu ada başka bir çiftliğe ait.", "error")
					end
					return
				end
				buyAndNotify(player, prompt:GetAttribute("UpgradeId"), nil, true)
				return
			end
		end
	end)
end

return UpgradeService
