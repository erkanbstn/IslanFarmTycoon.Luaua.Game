--!strict
-- Ana çiftlik satın alma/etkinleştirme. Çiftlik numarası = tema; etkinleşen çiftlik oyuncunun adasını yeniden giyer,
-- önceki çiftlik park edilir (kayıtta ve işleyişte kalır).
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local EconomyService = require(script.Parent.EconomyService)
local TelemetryService = require(script.Parent.TelemetryService)
local SaveCodec = require(script.Parent.Parent.Modules.SaveCodec)
local FarmProfiles = require(script.Parent.Parent.Modules.FarmProfiles)
local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local ProductionRules = require(script.Parent.Parent.Modules.ProductionRules)
local MainFarmService = {}
local highest: { [Player]: number } = {}
local initialized = false

local function apply(player: Player, action: unknown, target: unknown): (boolean, string)
	if not RateLimiter.validId(target) or (action ~= "buy" and action ~= "select") then
		return false, "Geçersiz çiftlik işlemi."
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true or not PlotService.getPlot(player) then
		return false, "Çiftliğin henüz hazır değil."
	end
	FarmProfiles.ensure(data)
	local farmId = target :: string
	local previousFarmId = data.activeMainFarmId
	local charge = 0
	if action == "buy" then
		local ids = FarmProfiles.ids(data)
		if #ids >= Config.MAIN_FARM_LIMIT then
			return false, "Ana çiftlik sınırına ulaştın."
		end
		local price = FarmMath.getPrice(data, "farm", nil, #ids + 1)
		local plotNumber = tonumber(target)
		if not plotNumber or plotNumber % 1 ~= 0 or plotNumber < 1 or plotNumber > Config.MAIN_FARM_LIMIT then
			return false, "Geçersiz ana alan."
		end
		if data.mainFarms[tostring(plotNumber)] then
			return false, "Bu ana çiftliğe zaten sahipsin."
		end
		EconomyService.settlePlayer(player)
		if not price or data.cash < price then
			return false, "Yeni çiftlik için yeterli para yok."
		end
		farmId = tostring(plotNumber)
		local farm = SaveCodec.newFarm(Config, FarmMath, DateTime.now().UnixTimestampMillis / 1000, function(): string
			return HttpService:GenerateGUID(false)
		end, farmId, #ids + 1)
		data.mainFarms[farmId] = farm
		charge = price
	else
		if not data.mainFarms[farmId] then
			return false, "Bu ana çiftlik sana ait değil."
		end
		if
			farmId ~= previousFarmId
			and not RateLimiter.allow(player, "mainFarmSwitch", Config.MAIN_FARM_SWITCH_COOLDOWN_SECONDS)
		then
			return false, "Çiftlik değiştirmek için birkaç saniye bekle."
		end
		EconomyService.settlePlayer(player)
	end
	if not PlotService.selectMainFarm(player, farmId) or not PlayerDataService.setActiveMainFarm(player, farmId) then
		-- Önceki etkin görünümü geri getir; başarısız seçim hiçbir ücret doğurmaz.
		PlotService.selectMainFarm(player, previousFarmId)
		PlayerDataService.setActiveMainFarm(player, previousFarmId)
		if action == "buy" then
			data.mainFarms[farmId] = nil
		end
		PlayerDataService.pushState(player)
		return false, "Çiftlik seçilemedi; ücret alınmadı."
	end
	data.cash -= charge
	if charge > 0 then
		TelemetryService.economy(player, "farm", charge, data.cash)
		TelemetryService.progression(player, "farm", #FarmProfiles.ids(data), `Farm {farmId}`)
	end
	player:SetAttribute("SelectedFarmIsland", "home")
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	local ok, err = pcall(function()
		PlotService.refreshPlayerWorld(player)
		PlotService.teleportHome(player)
	end)
	if not ok then
		warn(`[MainFarm] Seçim kaydedildi; görünüm yenilenemedi: {err}`)
	end
	return true, if action == "buy" then "Yeni ana çiftliğin satın alındı!" else "Ana çiftlik seçildi."
end

function MainFarmService.init()
	if initialized then
		return
	end
	initialized = true
	PlayerDataService.setFarmPlotResolver(PlotService.getMainFarmPlotId)
	PlayerDataService.setMainFarmOffersResolver(PlotService.getMainFarmOffers)
	Players.PlayerRemoving:Connect(function(player: Player)
		highest[player] = nil
	end)
	Remotes.get("RequestMainFarmAction").OnServerEvent
		:Connect(function(player: Player, action: unknown, target: unknown, requestId: unknown)
			if not ProductionRules.validRequestId(requestId) then
				return
			end
			local id = requestId :: number
			if id <= (highest[player] or 0) then
				return
			end
			highest[player] = id
			if not RateLimiter.allow(player, "mainFarmAction", 0.6) then
				if RateLimiter.allow(player, "mainFarmReply", 0.6) then
					Remotes.get("MainFarmResult")
						:FireClient(player, id, false, "Çok hızlı işlem yapıyorsun; biraz bekle.")
				end
				return
			end
			local ok, message = apply(player, action, target)
			Remotes.get("MainFarmResult"):FireClient(player, id, ok, message)
		end)
end
return MainFarmService
