--!strict
-- Bağımsız ana çiftlik satın alma/seçme. Fiziksel yer yoksa ücret alınmaz; park edilen kayıt korunur.
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
local SaveCodec = require(script.Parent.Parent.Modules.SaveCodec)
local FarmProfiles = require(script.Parent.Parent.Modules.FarmProfiles)
local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local ProductionRules = require(script.Parent.Parent.Modules.ProductionRules)
local MainFarmService = {}
local highest: { [Player]: number } = {}
local initialized = false

local function apply(player: Player, action: unknown, target: unknown): (boolean, string)
	if not RateLimiter.validId(target) or (action ~= "buy" and action ~= "select" and action ~= "activate") then
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
		local price = Config.MAIN_FARM_PRICES[#ids + 1]
		-- Çiftlik numarası = seçilen fiziksel ada numarası (tema numaraya bağlıdır)
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
		end)
		-- reserveMainFarm ve aşağıdaki mutasyonlar yield etmez: tahsis başarısızsa cüzdana dokunulmaz.
		if not PlotService.reserveMainFarm(player, farmId, target :: string) then
			return false, "Bu ana ada artık boş değil. Başka bir boş ada seç."
		end
		data.mainFarms[farmId] = farm
		charge = price
	else
		if not data.mainFarms[farmId] then
			return false, "Bu ana çiftlik sana ait değil."
		end
		EconomyService.settlePlayer(player)
	end
	if not PlotService.selectMainFarm(player, farmId) or not PlayerDataService.setActiveMainFarm(player, farmId) then
		-- Önceki etkin görünümü ve tahsisi geri getir; başarısız seçim hiçbir ücret doğurmaz.
		PlotService.selectMainFarm(player, previousFarmId)
		PlayerDataService.setActiveMainFarm(player, previousFarmId)
		if action == "buy" then
			PlotService.cancelMainFarmReservation(player, farmId)
			data.mainFarms[farmId] = nil
		end
		PlayerDataService.pushState(player)
		return false, "Çiftlik seçilemedi; ücret alınmadı."
	end
	data.cash -= charge
	-- "activate": oyuncu başka bir ana çiftliğin adasına yürüdü; etkin çiftlik değişir ama karakter ışınlanmaz.
	local walking = action == "activate"
	if walking then
		local active = PlayerDataService.tryGet(player)
		local selected = player:GetAttribute("SelectedFarmIsland")
		if not active or typeof(selected) ~= "string" or active.unlockedIslands[selected] ~= true then
			player:SetAttribute("SelectedFarmIsland", "home")
		end
	else
		player:SetAttribute("SelectedFarmIsland", "home")
	end
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	local ok, err = pcall(function()
		PlotService.refreshPlayerWorld(player)
		if not walking then
			PlotService.teleportHome(player)
		end
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
