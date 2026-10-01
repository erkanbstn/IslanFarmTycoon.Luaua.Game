--!strict
-- Sunucu giriş noktası (ServerScriptService/Server)
-- Oyun mantığı, veri kaydı ve doğrulama burada yapılır. Client'a asla güvenme.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local UpgradeService = require(Services:WaitForChild("UpgradeService"))
local AnimalService = require(Services:WaitForChild("AnimalService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local SeasonService = require(Services:WaitForChild("SeasonService"))
local ContractService = require(Services:WaitForChild("ContractService"))
local MainFarmService = require(Services:WaitForChild("MainFarmService"))
local ProductionService = require(Services:WaitForChild("ProductionService"))
local PetService = require(Services:WaitForChild("PetService"))
local HubBoardService = require(Services:WaitForChild("HubBoardService"))
local AdminService = require(Services:WaitForChild("AdminService"))
local ExtensionService = require(Services:WaitForChild("ExtensionService"))
local AnimalTaskService = require(Services:WaitForChild("AnimalTaskService"))
local CollectorVisualService = require(script:WaitForChild("Presentation"):WaitForChild("CollectorVisualService"))
local BuyPadService = require(Services:WaitForChild("BuyPadService"))
local EngagementService = require(Services:WaitForChild("EngagementService"))
local MonetizationService = require(Services:WaitForChild("MonetizationService"))
local InventoryService = require(Services:WaitForChild("InventoryService"))
local TelemetryService = require(Services:WaitForChild("TelemetryService"))
local Rewards = require(Shared:WaitForChild("Modules"):WaitForChild("Rewards"))
local RateLimiter = require(script:WaitForChild("Modules"):WaitForChild("RateLimiter"))
local SessionLock = require(script:WaitForChild("Modules"):WaitForChild("SessionLock"))

-- Karakter, veri yüklenip ada atandıktan SONRA yüklenir: böylece oyuncu önce meydanda doğup
-- sonra ışınlanmaz, doğrudan kendi adasında doğar (default.project.json'da da kapalı).
Players.CharacterAutoLoads = false
-- Oyunda ölüm yok (CharacterSafety.client); yine de bir şey olursa hemen yeniden doğ
Players.RespawnTime = 1

Remotes.init()

PlayerDataService.init()
TelemetryService.init()
SeasonService.init(function()
	-- Hava/mevsim değişmeden önce eski çarpanla geçen süreyi kapat.
	for _, player in Players:GetPlayers() do
		EconomyService.settlePlayer(player)
	end
end)
local mapReady, mapError = pcall(PlotService.init)
if not mapReady then
	warn(`[Server] Harita hazırlanamadı: {mapError}`)
end
UpgradeService.init()
ExtensionService.init()
AnimalService.init()
EconomyService.init()
CollectorVisualService.init()
BuyPadService.init()
EngagementService.init()
MonetizationService.init()
InventoryService.init()
ContractService.init()
AdminService.init()
ProductionService.init()
PetService.init()
AnimalTaskService.init()
MainFarmService.init()
HubBoardService.init()

local TELEPORT_COOLDOWN = 1.5
local lastTeleportAt: { [Player]: number } = {}
local joining: { [Player]: boolean } = {}

local function canTeleport(player: Player): boolean
	if not PlayerDataService.tryGet(player) or player:GetAttribute("WorldReady") ~= true then
		return false
	end
	local now = os.clock()
	if now - (lastTeleportAt[player] or 0) < TELEPORT_COOLDOWN then
		return false
	end
	lastTeleportAt[player] = now
	return true
end

Remotes.get("RequestPlayerState").OnServerEvent:Connect(function(player: Player)
	if RateLimiter.allow(player, "snapshot", 2) then
		PlayerDataService.pushState(player)
	end
end)

-- Arayüz dili tercihi: yalnızca bilinen kodlar kaydedilir; çeviriyi client kendi ekranında yapar.
Remotes.get("RequestSetLanguage").OnServerEvent:Connect(function(player: Player, code: unknown)
	if typeof(code) ~= "string" or Config.LANGUAGES[code] == nil or not RateLimiter.allow(player, "language", 0.5) then
		return
	end
	local data = PlayerDataService.tryGet(player)
	if not data or data.language == code then
		return
	end
	data.language = code
	player:SetAttribute("SavedLanguage", code)
	PlayerDataService.requestSave(player)
end)

-- Grafik tercihi: yalnızca bilinen modlar kaydedilir; uygulama client'ta (Graphics.client).
Remotes.get("RequestSetGraphics").OnServerEvent:Connect(function(player: Player, mode: unknown)
	if
		typeof(mode) ~= "string"
		or Config.GRAPHICS_MODES[mode] ~= true
		or not RateLimiter.allow(player, "graphics", 0.5)
	then
		return
	end
	local data = PlayerDataService.tryGet(player)
	if not data or data.graphics == mode then
		return
	end
	data.graphics = mode
	player:SetAttribute("SavedGraphics", mode)
	PlayerDataService.requestSave(player)
end)

Remotes.get("RequestGoHome").OnServerEvent:Connect(function(player: Player)
	if canTeleport(player) then
		PlotService.teleportHome(player)
	end
end)

Remotes.get("RequestTravelIsland").OnServerEvent
	:Connect(function(player: Player, islandId: unknown, selectOnly: unknown)
		if
			typeof(islandId) ~= "string"
			or #islandId > 32
			or (selectOnly ~= nil and typeof(selectOnly) ~= "boolean")
		then
			return
		end
		-- Menü seçimi seyahat bekleme süresini tüketmez; yürüyerek açılan menüden hemen gidilebilir.
		if selectOnly == true then
			if not RateLimiter.allow(player, "islandSelection", 0.3) then
				return
			end
		elseif not canTeleport(player) then
			if RateLimiter.allow(player, "travelReply", 1.5) then
				Remotes.get("Notify"):FireClient(player, "Seyahat için kısa bir süre bekleyip yeniden dene.", "info")
			end
			return
		end
		local ok = if selectOnly == true
			then PlotService.selectIsland(player, islandId)
			else PlotService.teleportToIsland(player, islandId)
		if not ok then
			Remotes.get("Notify")
				:FireClient(player, "Bu ada henüz açık değil veya seyahat için hazır değil.", "error")
		end
	end)

-- Tabeladaki "Adalar" menüsü: "hub" = meydan, diğerleri plotId
Remotes.get("RequestTravel").OnServerEvent:Connect(function(player: Player, target: unknown)
	if typeof(target) ~= "string" or #target > 16 or not canTeleport(player) then
		return
	end
	if target == "hub" then
		PlotService.teleportToHub(player)
	elseif not PlotService.teleportToPlot(player, target) then
		Remotes.get("Notify"):FireClient(player, "Böyle bir ada yok.", "error")
	end
end)

-- CharacterAutoLoads kapalı olduğu için ölünce yeniden doğmayı biz yönetiyoruz
local function setupRespawn(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.BreakJointsOnDeath = false
			humanoid.Died:Connect(function()
				task.wait(Players.RespawnTime)
				if player.Parent and PlayerDataService.tryGet(player) then
					local ok, err = pcall(function()
						player:LoadCharacter()
					end)
					if not ok then
						warn(`[Spawn] Yeniden doğma başarısız: {err}`)
					end
				end
			end)
		end
	end)
end

local function onPlayerAdded(player: Player)
	if joining[player] then
		return
	end
	joining[player] = true
	player:SetAttribute("SelectedFarmIsland", "home")
	player:SetAttribute("WorldReady", false)
	if not mapReady then
		player:Kick("Harita hazırlanamadı. Lütfen başka bir sunucuya katıl.")
		joining[player] = nil
		return
	end
	setupRespawn(player)

	-- 1) Adayı hemen ver ve karakteri orada doğur (kayıt verisini beklemeden)
	local hasPlot = PlotService.assign(player)
	if not hasPlot then
		player:Kick("Sunucuda boş ada kalmadı. Lütfen başka bir sunucuya katıl.")
		joining[player] = nil
		return
	end

	-- 2) Kaydı arka planda yükle; gelince ada (hayvanlar, binalar) ve arayüz dolar
	local data = PlayerDataService.load(player) -- yield eder
	if not data or not player.Parent then
		if not data and player.Parent then
			-- Kayıt açılamadı (ör. kilit başka sunucuda kaldı): adayı boşalt, oyuncuya nedenini söyle.
			local reason = player:GetAttribute("DataError")
			local message = if reason == SessionLock.HELD
				then "Kaydın başka bir sunucuda hâlâ açık. Biraz bekleyip yeniden katıl."
				else "Kayıt yüklenemedi. Lütfen yeniden katıl."
			if RunService:IsStudio() then
				-- Studio'da API erişimi kapalıyken neden görünsün; canlıda mesaj aynı kalır.
				message ..= ` [DataError: {tostring(reason)}]`
			end
			player:Kick(message)
		end
		joining[player] = nil
		return
	end
	-- Arayüz veri beklerken çiftlik kuruluyor; snapshot'ı erken gönder.
	PlayerDataService.pushState(player)
	local prepared, prepareError = pcall(function()
		assert(
			PlotService.restoreMainFarms(player, PlayerDataService.getFarmIds(player), data.activeMainFarmId),
			"Owned farm allocation failed"
		)
		if not player.Character then
			player:LoadCharacter()
		end
	end)
	if not prepared then
		warn(`[Server] Çiftlik hazırlanamadı: {prepareError}`)
		player:SetAttribute("DataError", "Çiftlik hazırlanamadı. Lütfen yeniden katıl.")
		PlayerDataService.release(player)
		if player.Parent then
			player:Kick("Çiftlik hazırlanamadı. Lütfen yeniden katıl.")
		end
		joining[player] = nil
		return
	end
	if not player.Parent then
		joining[player] = nil
		return
	end
	player:SetAttribute("WorldReady", true)
	-- Oyun geçitleri arka planda doğrulanır (yield eder); giriş akışını geciktirmez
	task.spawn(MonetizationService.refreshPasses, player)
	EconomyService.startPlayer(player)
	PlayerDataService.pushState(player)

	Remotes.get("Notify"):FireClient(player, `{Config.GAME_NAME}'a hoş geldin! Yol Haritası'ndan ilerle.`, "info")
	-- Dönüş özeti: sen yokken kazanılan para ve büyüyen hayvanlar (client küçük bir pencere gösterir)
	local offline, grown = PlayerDataService.takeOfflineSummary(player)
	if offline > 0 or grown > 0 then
		Remotes.get("OfflineSummary"):FireClient(player, offline, grown)
	end
	if Rewards.dailyStatus(data.daily, DateTime.now().UnixTimestamp).canClaim then
		Remotes.get("Notify"):FireClient(player, "Günlük ödülün hazır! Ödüller menüsünden al.", "info")
	end
	print(`[Server] {player.Name} katıldı.`)
	joining[player] = nil
end

local function onPlayerRemoving(player: Player)
	joining[player] = nil
	lastTeleportAt[player] = nil
	EconomyService.stopPlayer(player)
	TelemetryService.onLeaving(player)
	player:SetAttribute("WorldReady", false)
	local released, releaseError = pcall(PlotService.release, player)
	if not released then
		warn(`[Server] Ada temizliği başarısız: {releaseError}`)
	end
	PlayerDataService.release(player) -- Kaydeder (yield eder)
	print(`[Server] {player.Name} ayrıldı.`)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
