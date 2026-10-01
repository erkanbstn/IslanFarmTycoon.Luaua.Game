--!strict
-- Her oyuncuya tek fiziksel ada verir (hepsi aynı düzende kurulur). Oyuncunun etkin ana çiftliği o adada çizilir:
-- çiftlik değişince ada temasını MapBuilder.applyTheme ile yeniden giyer, diğer çiftlikler park edilir (kayıtta kalır,
-- PetService/EconomyService onları çizim olmadan işletir).
--
-- Haritayı Studio'da elle kurmak istersen (Config.MAP_AUTO_BUILD = false) yapı şöyle olmalı:
--   Workspace.Plots (Folder)
--     <Model>  Attribute PlotId = "1"
--       Zones (Folder) → her bölge bir Model, Attribute ZoneId (Config.ZONES ile aynı)
--                         içinde "Ground" parçası (BackReserve attribute), isteğe bağlı "LabelAnchor/ZoneBillboard"
--       Spawn (Part)      → oyuncunun ışınlandığı yer
--       Collector (Part)  → para toplama platformu
--       BarnSpot (Part)   → ahırın konumu (LookVector = kapı yönü)
--       BuildSpots (Folder) → güçlendirme binalarının yerleri (upgrade id'si isimli parçalar)
--       PlotSign (Part)   → SurfaceGui içinde "Text" adlı TextLabel

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local MapBuilder = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("MapBuilder"))
local AnimalVisualService =
	require(script.Parent.Parent:WaitForChild("Presentation"):WaitForChild("AnimalVisualService"))
local BarnVisualService = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("BarnVisualService"))
local UpgradeVisualService =
	require(script.Parent.Parent:WaitForChild("Presentation"):WaitForChild("UpgradeVisualService"))
local ZoneVisualService = require(script.Parent.Parent:WaitForChild("Presentation"):WaitForChild("ZoneVisualService"))
local DecorReveal = require(script.Parent.Parent:WaitForChild("Presentation"):WaitForChild("DecorReveal"))
local ExtensionVisualService =
	require(script.Parent.Parent:WaitForChild("Presentation"):WaitForChild("ExtensionVisualService"))
local IslandSpecialization = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("IslandSpecialization"))

type PlayerSave = GameTypes.PlayerSave

local PlotService = {}

local ownerByPlotId: { [string]: Player } = {}
local plotModelByPlotId: { [string]: Model } = {}
local plotOrder: { Model } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}
local ownedPlots: { [Player]: { [string]: Model } } = {}
local activePlots: { [Player]: Model } = {}
local farmIdByPlotId: { [string]: string } = {}
local NO_PLOTS: { [string]: Model } = {}

local function ownedOf(player: Player): { [string]: Model }
	return ownedPlots[player] or NO_PLOTS
end

local function collectPlotModels()
	table.clear(plotOrder)
	table.clear(plotModelByPlotId)
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then
		return
	end
	for _, child in plotsFolder:GetChildren() do
		if child:IsA("Model") then
			local plotId = child:GetAttribute("PlotId")
			if typeof(plotId) == "string" and plotId ~= "" then
				table.insert(plotOrder, child)
				plotModelByPlotId[plotId] = child
			end
		end
	end
	table.sort(plotOrder, function(a, b)
		return (tonumber(a:GetAttribute("PlotId")) or 0) < (tonumber(b:GetAttribute("PlotId")) or 0)
	end)
end

function PlotService.getAllPlots(): { Model }
	return plotOrder
end

-- Satın alınabilir ana çiftlik temaları (fiziksel ada rezervasyonu yok: her oyuncu kendi adasında tema değiştirir).
function PlotService.getMainFarmOffers(): { { id: string, name: string, icon: string, ownerUserId: number? } }
	local offers = {}
	for index = 1, Config.MAIN_FARM_LIMIT do
		local info = Config.PLOT_NAMES[index]
		table.insert(offers, {
			id = tostring(index),
			name = if info then info.name else `Ada {index}`,
			icon = if info then info.icon else "🏝️",
			ownerUserId = nil,
		})
	end
	return offers
end

-- Ada sahipliği kayıt verisinden bağımsız: oyuncu girer girmez adası belli olur ve orada doğar,
-- kayıt arka planda yüklenir.
function PlotService.getPlot(player: Player): Model?
	return activePlots[player]
end

-- Karakter canlı ve oyuncunun etkin adasının merkezine yatayda radius stud içinde mi (istemci konumu yalnızca ucuz bir sınır denetimidir).
function PlotService.isNearPlot(player: Player, radius: number): boolean
	local plot = activePlots[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not plot or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local offset = root.Position - plot:GetPivot().Position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius
end

function PlotService.getAllOwned(player: Player): { [string]: Model }
	return table.clone(ownedOf(player))
end

function PlotService.getMainFarmPlotId(player: Player, farmId: string): string?
	local farms = ownedPlots[player]
	local plot = farms and farms[farmId]
	return if plot then plot:GetAttribute("PlotId") :: string else nil
end

function PlotService.getFarmId(plot: Model): string?
	local plotId = plot:GetAttribute("PlotId")
	return if typeof(plotId) == "string" then farmIdByPlotId[plotId] else nil
end

function PlotService.getOwner(plot: Model): Player?
	local plotId = plot:GetAttribute("PlotId")
	if typeof(plotId) ~= "string" then
		return nil
	end
	return ownerByPlotId[plotId]
end

local function getSpawnCFrame(plot: Model): CFrame
	local spawn = plot:FindFirstChild("Spawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 4, 0)
	end
	return plot:GetPivot() + Vector3.new(0, 10, 0)
end

local function teleportCharacter(player: Player, target: CFrame): boolean
	local character = player.Character
	if character and character.Parent then
		character:PivotTo(target)
		return true
	end
	return false
end

function PlotService.teleportHome(player: Player)
	local plot = PlotService.getPlot(player)
	if plot and teleportCharacter(player, getSpawnCFrame(plot)) then
		player:SetAttribute("SelectedFarmIsland", "home")
	end
end

-- Seçim de seyahat de yalnızca aktif oyuncunun açık ve kendisine ait adalarını kullanır.
local function ownedIslandPlot(player: Player, islandId: unknown): Model?
	if typeof(islandId) ~= "string" or #islandId > 32 or not Config.FARM_ISLANDS[islandId] then
		return nil
	end
	local data = PlayerDataService.tryGet(player)
	local plot = PlotService.getPlot(player)
	if not data or not plot or player:GetAttribute("WorldReady") ~= true or data.unlockedIslands[islandId] ~= true then
		return nil
	end
	return plot
end

-- Binaya yürüyerek gelen oyuncu menüsünü eşitler; karakteri yeniden ışınlamaz.
function PlotService.selectIsland(player: Player, islandId: unknown): boolean
	if not ownedIslandPlot(player, islandId) then
		return false
	end
	player:SetAttribute("SelectedFarmIsland", islandId)
	return true
end

function PlotService.teleportToIsland(player: Player, islandId: unknown): boolean
	local plot = ownedIslandPlot(player, islandId)
	if not plot then
		return false
	end
	local target: CFrame? = nil
	if islandId == "home" then
		target = getSpawnCFrame(plot)
	else
		local islands = plot:FindFirstChild("Islands")
		if not islands then
			return false
		end
		for _, island in islands:GetChildren() do
			if island:GetAttribute("FarmIslandId") == islandId then
				local sign = island:FindFirstChild("IslandSign")
				if sign and sign:IsA("BasePart") then
					-- Tabela köprü girişinin 9,5 stud sağındadır; köprü ekseninin ortasına, tabelanın biraz gerisine iner.
					target = sign.CFrame * CFrame.new(-9.5, -2, 4) * CFrame.Angles(0, math.pi, 0)
				end
				break
			end
		end
	end
	if not target or not teleportCharacter(player, target) then
		return false
	end
	player:SetAttribute("SelectedFarmIsland", islandId)
	return true
end

function PlotService.teleportToPlot(player: Player, plotId: string): boolean
	local plot = plotModelByPlotId[plotId]
	if not plot then
		return false
	end
	teleportCharacter(player, getSpawnCFrame(plot))
	return true
end

function PlotService.teleportToHub(player: Player)
	local world = Workspace:FindFirstChild("World")
	local hubSpawn = world and world:FindFirstChild("HubSpawn", true)
	if hubSpawn and hubSpawn:IsA("BasePart") then
		teleportCharacter(player, hubSpawn.CFrame + Vector3.new(0, 4, 0))
	end
end

-- Tabela ve uzaktan görünen ada etiketi: sahibin adı (nil = boş ada)
local function setOwnerDisplay(plot: Model, ownerName: string?)
	local sign = plot:FindFirstChild("PlotSign")
	if sign then
		WorldUi.setSignText(sign, if ownerName then `{ownerName} Çiftliği` else "Boş Ada")
	end

	local anchor = plot:FindFirstChild("IslandLabelAnchor")
	local name = plot:GetAttribute("IslandName") or plot.Name
	WorldUi.setTag(
		anchor and anchor:FindFirstChild("IslandLabel"),
		if ownerName then `{name} · {ownerName}` else `{name} · Boş`
	)
end

local function setZoneLabel(zone: Instance, text: string, icon: string, locked: boolean)
	local anchor = zone:FindFirstChild("LabelAnchor")
	WorldUi.setTag(
		anchor and anchor:FindFirstChild("ZoneBillboard"),
		text,
		icon,
		if locked then UiTheme.Color.Red else UiTheme.Color.Green
	)
end

-- data nil ise ada boş (sahipsiz) görünümüne döner
local function applyZoneState(plot: Model, data: PlayerSave?)
	local zonesFolder = plot:FindFirstChild("Zones")
	if not zonesFolder then
		return
	end
	for _, zone in zonesFolder:GetChildren() do
		local zoneId = zone:GetAttribute("ZoneId")
		if typeof(zoneId) ~= "string" then
			continue
		end
		local zoneConfig = Config.ZONES[zoneId]
		if not zoneConfig then
			continue
		end

		local unlocked = data ~= nil and data.unlockedZones[zoneId] == true
		local zoneName = Config.getZoneName(zoneConfig, tostring(plot:GetAttribute("ThemeIndex")))
		ZoneVisualService.apply(zone, zoneId, unlocked)
		if not unlocked then
			ZoneVisualService.applyLevelFlags(zone, {})
		end

		if data and unlocked then
			local label = `{zoneName} · {FarmMath.countInZone(data, zoneId)}/{FarmMath.getZoneCapacity(data, zoneId)}`
			local zoneLevel = FarmMath.getExpansionLevel(data, zoneId)
			if zoneLevel > 0 then
				label ..= ` · Sv.{zoneLevel}`
			end
			for extensionId, extension in Config.EXTENSIONS do
				if extension.sourceZoneId == zoneId then
					local upgrade = Config.getExtensionUpgrade(extensionId)
					if upgrade and data.purchased[upgrade.id] then
						local inExt = FarmMath.countInExtension(data, extensionId)
						if inExt > 0 then
							label ..= ` · {extension.displayName}: {inExt}/{FarmMath.getExtensionCapacity(
								data,
								extensionId
							)}`
						end
					end
				end
			end
			setZoneLabel(zone, label, Config.getZoneIcon(zoneConfig, tostring(plot:GetAttribute("ThemeIndex"))), false)
			local kinds: { string } = {}
			for level = 1, zoneLevel do
				table.insert(kinds, FarmMath.getBuildLevelKind(zoneId, level))
			end
			ZoneVisualService.applyLevelFlags(zone, kinds, zoneConfig.upgradeProfile ~= "sea")
		elseif data and not data.unlockedIslands[zoneConfig.island] then
			-- Ada kilitliyse etiketi ada tabelası anlatıyor; burada sadece ad
			setZoneLabel(zone, zoneName, "🔒", true)
		else
			local upgrade = Config.getZoneUpgrade(zoneId)
			local price = if upgrade then ` · {FarmMath.formatMoney(FarmMath.getUpgradeCost(data, upgrade))}` else ""
			setZoneLabel(zone, `{zoneName}{price}`, "🔒", true)
		end
	end
end

-- Uzman adalar: açıksa yeşil zemin + özellik, kilitliyse toprak rengi + fiyat ve "Satın Al" düğmesi.
-- data nil ise (boş çiftlik) hepsi kilitli görünür.
-- Kilitli ada: sönük ama yeşil çayır (kuru toprak yerine); üstünde SATILIK flamaları durur.
local LOCKED_ISLAND_COLOR = Color3.fromRGB(120, 140, 92)

local function islandSurfaceCf(island: Model): CFrame
	local base = island:FindFirstChild("IslandBase")
	if base and base:IsA("BasePart") then
		-- IslandBase dik duran bir silindirdir (X ekseni, Z'de 90° döndürülmüş); yüzey = eski düz çerçeve + yükseklik/2.
		return base.CFrame * CFrame.Angles(0, 0, -math.pi / 2) * CFrame.new(0, base.Size.X / 2, 0)
	end
	return island:GetPivot()
end

local function applyIslandState(plot: Model, data: PlayerSave?)
	local islands = plot:FindFirstChild("Islands")
	if not islands then
		return
	end
	for _, island in islands:GetChildren() do
		local islandId = island:GetAttribute("FarmIslandId")
		local islandConfig = if typeof(islandId) == "string" then Config.FARM_ISLANDS[islandId] else nil
		if not islandConfig then
			continue
		end
		local unlocked = data ~= nil and data.unlockedIslands[islandConfig.id] == true
		local upgrade = if islandConfig.upgradeId then Config.getUpgrade(islandConfig.upgradeId) else nil

		-- Zemin: kilitliyken kuru toprak, açılınca çimen. "Locked" attribute'u client'taki mevsim
		-- renklendirmesine de haber verir (kilitli adayı boyamaz).
		local base = island:FindFirstChild("IslandBase")
		if base and base:IsA("BasePart") and base:GetAttribute("Locked") ~= not unlocked then
			local openColor = base:GetAttribute("OpenColor")
			base.Color = if unlocked and typeof(openColor) == "Color3" then openColor else LOCKED_ISLAND_COLOR
			base.Material = Enum.Material.Grass
			base:SetAttribute("Locked", not unlocked)
			-- Satılık flamaları ve taşlar yalnızca kilitli adada görünür.
			local forSale = island:FindFirstChild("LockedDecor")
			if forSale then
				for _, item in forSale:GetDescendants() do
					if item:IsA("BasePart") then
						item.Transparency = if unlocked then 1 else 0
						item.CanCollide = not unlocked and item.Name == "SaleStone"
					elseif item:IsA("SurfaceGui") then
						item.Enabled = not unlocked
					end
				end
			end
		end

		local anchor = island:FindFirstChild("IslandLabelAnchor")
		local label = anchor and anchor:FindFirstChild("IslandLabel")
		if unlocked then
			WorldUi.setTag(label, islandConfig.displayName, islandConfig.icon, UiTheme.Color.Gold)
		else
			local price = if upgrade then ` · {FarmMath.formatMoney(FarmMath.getUpgradeCost(data, upgrade))}` else ""
			WorldUi.setTag(label, `{islandConfig.displayName}{price}`, "🔒", UiTheme.Color.Red)
		end

		local spec = island:FindFirstChild("Specialization")
		if spec and island:IsA("Model") and typeof(islandId) == "string" then
			local surfaceCf = islandSurfaceCf(island)
			IslandSpecialization.syncProductionSites(spec, surfaceCf, islandId, data)
			if islandId == "home" then
				local milkOwned = data ~= nil and data.purchased.milk_factory == true
				IslandSpecialization.syncMilkLoadingDecor(spec, surfaceCf, milkOwned)
			end
		end

		local sign = island:FindFirstChild("IslandSign")
		if sign then
			local prompt = island:FindFirstChild("BuyIslandPrompt", true)
			if prompt and prompt:IsA("ProximityPrompt") then
				-- Görünürlüğü client (IslandPrompts) belirler: sadece sahibine ve kilitliyse
				prompt:SetAttribute("Locked", not unlocked)
				if upgrade then
					prompt.ObjectText =
						`{islandConfig.displayName} · {FarmMath.formatMoney(FarmMath.getUpgradeCost(data, upgrade))}`
				end
			end
		end
	end
end

-- Her fiziksel çiftlik yalnızca kendisine ait kayıtla çizilir; etkin facade diğerlerine sızmaz.
local function renderFarm(plot: Model, data: PlayerSave)
	BarnVisualService.applyForPlayer(plot, data.barnLevel)
	applyIslandState(plot, data)
	applyZoneState(plot, data)
	UpgradeVisualService.apply(plot, data)
	ExtensionVisualService.apply(plot, data)
	AnimalVisualService.refresh(plot, data)
end

function PlotService.refreshPlayerWorld(player: Player)
	if not PlayerDataService.tryGet(player) then
		return
	end
	for farmId, plot in ownedOf(player) do
		local view = PlayerDataService.getFarmView(player, farmId)
		if view then
			renderFarm(plot, view)
		end
	end
end

-- Yalnızca tek çiftliğin adasını yeniden çizer (park edilmiş çiftlikte hayvan evresi değişince).
function PlotService.refreshFarmWorld(player: Player, farmId: string)
	local plot = ownedOf(player)[farmId]
	local view = if plot then PlayerDataService.getFarmView(player, farmId) else nil
	if plot and view then
		renderFarm(plot, view)
	end
end

local function themeOf(farmId: string): number
	return tonumber(farmId) or 1
end

-- Adadaki sahibe ait görselleri temizler (tema içeriğine dokunmaz); sonrasında renderFarm/resetPlot çizer.
local function clearOwnerVisuals(plot: Model)
	UpgradeVisualService.apply(plot, nil)
	ExtensionVisualService.apply(plot, nil)
	AnimalVisualService.clear(plot)
	DecorReveal.reset(plot)
	local pads = plot:FindFirstChild("BuyPads")
	if pads then
		pads:Destroy() -- eski temanın ada yuvalarına kurulmuştu
	end
end

local function resetPlot(plot: Model)
	plot:SetAttribute("OwnerUserId", nil)
	plot:SetAttribute("MainFarmId", nil)
	plot:SetAttribute("FarmActive", nil)
	-- Boş ada temasını korur (ada şablon kopyasıyla giydirilir; boşalırken yeniden giydirmek gereksiz). Sonraki sahip
	-- restoreMainFarms/selectMainFarm ile kendi temasını giydirir.
	clearOwnerVisuals(plot)
	setOwnerDisplay(plot, nil)
	BarnVisualService.applyForPlayer(plot, 1)
	applyIslandState(plot, nil)
	applyZoneState(plot, nil)
	-- Yapı/eklenti/hayvan/BuyPads temizliği clearOwnerVisuals içinde yapıldı; burada yalnızca para yığını kalır.
	local pile = plot:FindFirstChild("CollectorPile")
	if pile then
		pile:Destroy()
	end
	local collector = plot:FindFirstChild("Collector")
	if collector then
		WorldUi.setTag(collector:FindFirstChild("CollectorBillboard"), "Depo", "💰", UiTheme.Color.Gold)
	end
end

-- Oyuncunun adasını verilen çiftliğe bağlar. Yield etmez; para/kayıt işlemini MainFarmService yönetir.
-- keepTheme: kayıt henüz yüklenmedi (assign); ada mevcut temasında kalır, tema restoreMainFarms'ta bir kez giydirilir.
local function bindFarm(player: Player, farmId: string, plot: Model, keepTheme: boolean?)
	local plotId = plot:GetAttribute("PlotId") :: string
	-- Tema değişecekse de temizle: BuyPads/DecorReveal eski temanın yuvalarına ve nesnelerine bağlı kalmasın.
	local themeChanges = not keepTheme and plot:GetAttribute("ThemeIndex") ~= themeOf(farmId)
	if farmIdByPlotId[plotId] ~= farmId or ownerByPlotId[plotId] ~= player or themeChanges then
		clearOwnerVisuals(plot)
	end
	if not keepTheme then
		MapBuilder.applyTheme(plot, themeOf(farmId)) -- ada zaten bu temadaysa hiçbir şey yapmaz
	end
	ownedPlots[player] = { [farmId] = plot }
	activePlots[player] = plot
	ownerByPlotId[plotId] = player
	farmIdByPlotId[plotId] = farmId
	plot:SetAttribute("MainFarmId", farmId)
	plot:SetAttribute("OwnerUserId", player.UserId)
	plot:SetAttribute("FarmActive", true)
	setOwnerDisplay(plot, `{player.DisplayName} · Çiftlik {farmId}`)
	player:SetAttribute("ActiveMainFarmId", farmId)
	player:SetAttribute("ActivePlotId", plotId)
	player:SetAttribute("SelectedFarmIsland", "home")
	local spawn = plot:FindFirstChild("Spawn")
	if spawn and spawn:IsA("SpawnLocation") then
		player.RespawnLocation = spawn
	end
end

-- Aynı sunucuda ayrılan oyuncunun son teması: geri dönerse aynı temadaki boş adaya konur (kayıt gelince tema değişimi gerekmez).
local lastThemeByUserId: { [number]: number } = {}

-- Boş adalardan biri verilir; sahipsiz adalar kilitli/boş yer tutucu olarak görünür. Kayıt henüz yüklenmediği için tema
-- bilinmez: oyuncunun bu sunucudaki son temasını, yoksa yeni oyuncu teması 1'i taşıyan adayı tercih eder (kayıtlı tema
-- sonradan restoreMainFarms'ta zaten giydirilir; bu yalnızca gereksiz yeniden giydirmeyi azaltır).
local function findFreePlot(player: Player?): Model?
	local free: { Model } = {}
	local preferred: { Model } = {}
	local wanted = if player then lastThemeByUserId[player.UserId] or 1 else 1
	for _, plot in plotOrder do
		if not ownerByPlotId[plot:GetAttribute("PlotId") :: string] then
			table.insert(free, plot)
			if plot:GetAttribute("ThemeIndex") == wanted then
				table.insert(preferred, plot)
			end
		end
	end
	local pool = if #preferred > 0 then preferred else free
	return if #pool > 0 then pool[math.random(#pool)] else nil
end

-- Kayıttaki etkin çiftliği oyuncunun adasına yükler (giriş).
function PlotService.restoreMainFarms(player: Player, farmIds: { string }, activeId: string): boolean
	local plot = activePlots[player]
	if not plot or not table.find(farmIds, activeId) then
		return false
	end
	bindFarm(player, activeId, plot)
	PlotService.refreshPlayerWorld(player)
	return true
end

-- Etkin çiftliği değiştirir: ada yeni çiftliğin temasıyla yeniden kurulur, eskisi park edilir.
function PlotService.selectMainFarm(player: Player, farmId: string): boolean
	local data = PlayerDataService.tryGet(player)
	local plot = activePlots[player]
	if not data or not data.mainFarms[farmId] or not plot then
		return false
	end
	bindFarm(player, farmId, plot)
	return true
end

-- Normalde karakter RespawnLocation sayesinde doğrudan adada doğar. Yine de uzakta doğduysa
-- (ör. karakter ada atanmadan önce yüklendiyse) adaya ışınla.
local function onCharacterAdded(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local plot = PlotService.getPlot(player)
	if not root or not root:IsA("BasePart") or not plot or not character.Parent then
		return
	end
	if (root.Position - getSpawnCFrame(plot).Position).Magnitude > 40 then
		PlotService.teleportHome(player)
	end
end

-- Oyuncuya boş bir ada verir. Kayıt verisini beklemez; veri gelince refreshPlayerWorld çağrılır.
function PlotService.assign(player: Player): boolean
	if PlotService.getPlot(player) then
		return true
	end
	local plot = findFreePlot(player)
	if not plot then
		warn(`[Plot] Boş ada yok: {player.Name}`)
		return false
	end
	bindFarm(player, "1", plot, true)
	characterConnections[player] = player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	if Config.DEBUG then
		print(`[Plot] {player.Name} -> ada {plot:GetAttribute("PlotId")}`)
	end
	return true
end

function PlotService.release(player: Player)
	local connection = characterConnections[player]
	if connection then
		connection:Disconnect()
		characterConnections[player] = nil
	end
	(player :: any).RespawnLocation = nil -- Roblox tipi nil kabul etmez; çalışma anında temizlemek geçerlidir
	local active = activePlots[player]
	local activeTheme = active and active:GetAttribute("ThemeIndex")
	if typeof(activeTheme) == "number" then
		lastThemeByUserId[player.UserId] = activeTheme
	end
	for _, plot in table.clone(ownedOf(player)) do
		local plotId = plot:GetAttribute("PlotId") :: string
		ownerByPlotId[plotId], farmIdByPlotId[plotId] = nil, nil
		resetPlot(plot)
	end
	ownedPlots[player], activePlots[player] = nil, nil
	player:SetAttribute("ActivePlotId", nil)
	player:SetAttribute("ActiveMainFarmId", nil)
end

function PlotService.init()
	MapBuilder.ensure()
	MapBuilder.validate()
	-- assign() boş ada olmadığında false döner; giriş noktası yalnızca fazla oyuncuyu reddeder.
	if Players.MaxPlayers > Config.MAP_PLOT_COUNT then
		warn(`[Map] MaxPlayers={Players.MaxPlayers}; haritada yalnızca {Config.MAP_PLOT_COUNT} ada var.`)
	end
	collectPlotModels()
	for _, plot in plotOrder do
		resetPlot(plot)
	end

	-- Ayrılma sırası init.server tarafından yönetilir: son gelir → ada → kayıt.
end

return PlotService
