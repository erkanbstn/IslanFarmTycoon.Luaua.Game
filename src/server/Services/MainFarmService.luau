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
local VisualWorkBudget = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("VisualWorkBudget"))
local MainFarmService = {}
type Request = { player: Player, action: unknown, target: unknown, id: number }
local queue: { Request } = {}
local pending: { [Player]: boolean } = {}
local working = false
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
	local purchasedFarm: any = nil
	if action == "buy" then
		local ids = FarmProfiles.ids(data)
		if #ids >= Config.MAIN_FARM_LIMIT then
			return false, "Ana çiftlik sınırına ulaştın."
		end
		local plotNumber = tonumber(target)
		if not plotNumber or plotNumber % 1 ~= 0 or plotNumber < 1 or plotNumber > Config.MAIN_FARM_LIMIT then
			return false, "Geçersiz ana alan."
		end
		local price = FarmMath.getPrice(data, "farm", nil, plotNumber) -- fiyat temanın numarasına bağlıdır (alım sırasına değil)
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
		end, farmId)
		purchasedFarm = farm
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
	if action == "select" and farmId == previousFarmId then
		PlayerDataService.pushState(player)
		return true, "Ana çiftlik seçildi."
	end
	local plot = PlotService.getPlot(player) :: Model
	local function valid(): boolean
		return player.Parent ~= nil
			and PlayerDataService.tryGet(player) == data
			and PlotService.getPlot(player) == plot
			and PlotService.getOwner(plot) == player
	end
	if not valid() then
		return false, "Çiftliğin henüz hazır değil."
	end
	player:SetAttribute("WorldReady", false)
	plot:SetAttribute("WorldTransition", true)
	local transitionStarted = os.clock()
	VisualWorkBudget.begin(valid)
	local committed = false
	local ok, problem = pcall(function()
		assert(PlotService.selectMainFarm(player, farmId, purchasedFarm ~= nil), "Theme selection failed")
		VisualWorkBudget.step()
		-- Kayıt ve ücret aynı yield etmeyen blokta kesinleşir; hazırlıkta alınan çiftlik kayda sızmaz.
		EconomyService.settlePlayer(player)
		assert(data.cash >= charge, "Farm balance changed during transition")
		if purchasedFarm then
			data.mainFarms[farmId] = purchasedFarm
		end
		local returnSpeeds: { [string]: any } = {}
		local progression = data.progression
		local returnNow = DateTime.now().UnixTimestampMillis / 1000
		if progression and not progression.returnEnded and farmId ~= "1" then
			for _, id in FarmProfiles.ids(data) do
				returnSpeeds[id] = FarmMath.snapshotGrowthSpeeds(FarmProfiles.view(data, id), returnNow)
			end
		end
		if not PlayerDataService.setActiveMainFarm(player, farmId) then
			if purchasedFarm then
				data.mainFarms[farmId] = nil
			end
			error("Profile selection failed")
		end
		data.cash -= charge
		if progression and next(returnSpeeds) ~= nil then
			progression.returnEnded = true
			for id, speeds in returnSpeeds do
				FarmMath.preserveGrowthProgress(FarmProfiles.view(data, id), speeds, returnNow)
			end
		end
		committed = true
		if charge > 0 then
			TelemetryService.economy(player, "farm", charge, data.cash)
			TelemetryService.progression(player, "farm", #FarmProfiles.ids(data), `Farm {farmId}`)
		end
		player:SetAttribute("SelectedFarmIsland", "home")
		PlayerDataService.pushState(player)
		PlayerDataService.requestSave(player)
		PlotService.refreshPlayerWorld(player, true)
		VisualWorkBudget.step()
		PlotService.teleportHome(player)
	end)
	if not ok and not committed and valid() then
		-- Hazırlık yarıda kesildiyse yalnız aynı sahibin adası eski temaya döner.
		local restored, restoreError = pcall(function()
			PlotService.selectMainFarm(player, previousFarmId)
			PlotService.refreshPlayerWorld(player, true)
		end)
		if not restored then
			warn(`[MainFarm] Önceki görünüm geri yüklenemedi: {restoreError}`)
		end
	end
	VisualWorkBudget.finish()
	if valid() then
		plot:SetAttribute("WorldTransitionSeconds", os.clock() - transitionStarted)
		plot:SetAttribute("WorldTransition", nil)
		player:SetAttribute("WorldReady", true)
	end
	if not ok then
		warn(`[MainFarm] Çiftlik geçişi kesildi: {problem}`)
		if not committed then
			if valid() then
				PlayerDataService.pushState(player)
			end
			return false, "Çiftlik seçilemedi; ücret alınmadı."
		end
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
		pending[player] = nil
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
			if pending[player] then
				Remotes.get("MainFarmResult"):FireClient(player, id, false, "Çiftliğin henüz hazır değil.")
				return
			end
			pending[player] = true
			table.insert(queue, { player = player, action = action, target = target, id = id })
			if working then
				return
			end
			working = true
			task.spawn(function()
				while #queue > 0 do
					local nextRequest = table.remove(queue, 1)
					if not nextRequest then
						break
					end
					local owner = nextRequest.player
					if owner.Parent and pending[owner] then
						local succeeded, accepted, message = pcall(apply, owner, nextRequest.action, nextRequest.target)
						if owner.Parent then
							Remotes.get("MainFarmResult"):FireClient(
								owner,
								nextRequest.id,
								succeeded and accepted == true,
								if succeeded then message else "Çiftlik seçilemedi; ücret alınmadı."
							)
						end
						if not succeeded then
							warn(`[MainFarm] İş kuyruğu hatası: {accepted}`)
						end
					end
					pending[owner] = nil
				end
				working = false
			end)
		end)
end
return MainFarmService
