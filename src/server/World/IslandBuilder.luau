--!strict
-- Ana ada: zemin, bölgeler, avlu dekoru, yapı yerleri ve küçük adaların bağlanması.

local CollectionService = game:GetService("CollectionService")

-- Studio plugin'i modülleri kopyalayıp taze Config ile çalıştırır; Shared araması SharedRef'te (kopyadaki Shared'ı bulur).
local Shared = require(script.Parent:WaitForChild("SharedRef")) :: typeof(game.ReplicatedStorage.Shared)
local Config = require(Shared:WaitForChild("Config"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local MapPaths = require(Shared:WaitForChild("MapPaths"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))
local BarnVisualService = require(script.Parent:WaitForChild("BarnVisualService"))
local WorldDecor = require(script.Parent:WaitForChild("WorldDecor"))
local IslandSpecialization = require(script.Parent:WaitForChild("IslandSpecialization"))
local HomeBuildings = require(script.Parent:WaitForChild("HomeBuildings"))
local MapLayout = require(script.Parent:WaitForChild("MapLayout"))
local MapParts = require(script.Parent:WaitForChild("MapParts"))
local SatelliteBuilder = require(script.Parent:WaitForChild("SatelliteBuilder"))

local SURFACE_Y = MapLayout.SURFACE_Y
local WATER_Y = MapLayout.WATER_Y
local ISLAND_RADIUS = MapLayout.ISLAND_RADIUS
local WATER_DEPTH = MapLayout.WATER_DEPTH
local FISH_PEN_CENTER = MapLayout.FISH_PEN_CENTER
local FISH_PEN_SIZE = MapLayout.FISH_PEN_SIZE
local FISH_WALKWAY_WIDTH = MapLayout.FISH_WALKWAY_WIDTH
local HOME_ZONES = MapLayout.HOME_ZONES
local DOCK_START = MapLayout.DOCK_START
local DOCK_LENGTH = MapLayout.DOCK_LENGTH
local DOCK_SURFACE_Y = MapLayout.DOCK_SURFACE_Y
local HOME_BUILD_SPOTS = MapLayout.HOME_BUILD_SPOTS
local HOME_WATER_SPOTS = MapLayout.HOME_WATER_SPOTS
local satelliteLayouts = MapLayout.satelliteLayouts
local homePlacements = MapLayout.homePlacements
local homeBuildingAvoidRects = MapLayout.homeBuildingAvoidRects
local makePart = MapParts.makePart
local makeDisc = MapParts.makeDisc
local addTravelPrompt = MapParts.addTravelPrompt
local buildTree = MapParts.buildTree
local buildZone = MapParts.buildZone
local addBuildSpot = MapParts.addBuildSpot
local addIslandGrass = MapParts.addIslandGrass
local lampsAlong = MapParts.lampsAlong
local buildSatellite = SatelliteBuilder.buildSatellite

-- Kavşak yön tabelası: direğe çakılı okları olan tahtalar (her biri bir yere gider)
local function buildSignpost(parent: Instance, base: CFrame, arrows: { { label: string, icon: string, yaw: number } })
	local model = Instance.new("Model")
	model.Name = "Signpost"
	model.Parent = parent
	local post =
		makePart("Post", Vector3.new(0.6, 7, 0.6), base * CFrame.new(0, 3.5, 0), Color3.fromRGB(110, 80, 50), model)
	post.Material = Enum.Material.Wood
	post.CanCollide = false
	for index, arrow in arrows do
		local board = makePart(
			"Board",
			Vector3.new(5.4, 1.3, 0.3),
			base * CFrame.Angles(0, math.rad(arrow.yaw), 0) * CFrame.new(2.4, 6.2 - (index - 1) * 1.5, 0),
			Color3.fromRGB(150, 110, 70),
			model
		)
		board.Material = Enum.Material.WoodPlanks
		board.CanCollide = false
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			WorldUi.sign(board, face, { icon = arrow.icon, text = arrow.label })
		end
	end
end

local function decorateHome(decor: Instance, islandCf: CFrame, plotIndex: number)
	local function at(x: number, z: number): CFrame
		return islandCf * CFrame.new(x, SURFACE_Y, z)
	end
	local function pos(x: number, z: number): Vector3
		return at(x, z).Position
	end

	-- Taş yollar MapPaths'te tanımlıdır (yardımcıların rotası da aynı listeyi kullanır)
	for _, segment in MapPaths.homeSegments(ISLAND_RADIUS) do
		WorldDecor.path(decor, pos(segment.ax, segment.az), pos(segment.bx, segment.bz), segment.width)
	end
	WorldDecor.path(decor, pos(-4, -50), pos(DOCK_START.X, DOCK_START.Z), 4) -- balık kafesi iskelesine
	WorldDecor.path(decor, pos(-33, -51), pos(DOCK_START.X + 2, DOCK_START.Z + 3), 4) -- balık merkezinin kapısından iskeleye

	local trees = {
		Vector2.new(-45, -35),
		Vector2.new(45, -38),
		Vector2.new(-58, -5),
		Vector2.new(62, -24),
		Vector2.new(-54, 20),
		Vector2.new(54, 20),
		Vector2.new(30, -58),
	}
	for _, spot in trees do
		buildTree(decor, at(spot.X, spot.Y), plotIndex)
	end

	local bushes = {
		Vector2.new(-9, -60),
		Vector2.new(9, -60),
		Vector2.new(-39, -19),
		Vector2.new(55, -34),
		Vector2.new(-33, 25),
		Vector2.new(33, 23),
	}
	for index, spot in bushes do
		WorldDecor.bush(decor, at(spot.X, spot.Y), plotIndex * 10 + index)
	end

	local flowers = {
		Vector2.new(-6, -30),
		Vector2.new(6, -26),
		Vector2.new(-10, -22),
		Vector2.new(10, -24),
		Vector2.new(-12, -44),
		Vector2.new(-44, -10),
		Vector2.new(58, 10),
	}
	for index, spot in flowers do
		WorldDecor.flowerPatch(decor, at(spot.X, spot.Y), plotIndex + index)
	end

	-- Işıklandırma: her yol kendi uzunluğuna göre eşit aralıklı; ağıl köşeleri ve balıkçı noktaları ayrıca.
	local function homeAt(x: number, z: number): CFrame
		return at(x, z)
	end
	lampsAlong(decor, homeAt, Vector2.new(0, -64), Vector2.new(0, 26), 26, 4.6, -1) -- ana yol
	lampsAlong(decor, homeAt, Vector2.new(-30, -16), Vector2.new(30, -16), 32, 3.8, 1) -- ağıllar arası yol
	lampsAlong(decor, homeAt, Vector2.new(-15, 28), Vector2.new(-42, 52), 30, 3.8, 1) -- sol köprü yolu
	lampsAlong(decor, homeAt, Vector2.new(15, 28), Vector2.new(42, 52), 30, 3.8, -1) -- sağ köprü yolu
	lampsAlong(decor, homeAt, Vector2.new(-16, 32), Vector2.new(-16, 66), 34, 3.8, 1) -- güney yol
	for _, corner in { Vector2.new(-37, -12), Vector2.new(37, -12), Vector2.new(-37, 16), Vector2.new(37, 16) } do
		WorldDecor.lamp(decor, at(corner.X, corner.Y) * CFrame.Angles(0, if corner.X > 0 then math.pi else 0, 0))
	end
	-- Ahır girişi
	for _, x in { -12, 12 } do
		WorldDecor.lamp(decor, at(x, 30) * CFrame.Angles(0, if x > 0 then math.pi else 0, 0))
	end

	-- Balıkçı noktaları: yalnızca balık kafesi yürüme yolunun dört köşesinde ve iskelenin iki ucunda alçak fener
	local dockFrame = islandCf * CFrame.lookAt(DOCK_START, FISH_PEN_CENTER)
	for _, distance in { 3, DOCK_LENGTH - 3 } do
		local base = dockFrame * CFrame.new(2.4, 0, -distance)
		WorldDecor.smallLamp(decor, CFrame.new(base.Position.X, DOCK_SURFACE_Y, base.Position.Z))
	end
	local ring = FISH_PEN_SIZE.X / 2 + FISH_WALKWAY_WIDTH / 2
	for _, offset in
		{
			Vector2.new(-ring, -ring),
			Vector2.new(ring, -ring),
			Vector2.new(-ring, ring),
			Vector2.new(ring, ring),
		}
	do
		local world = islandCf * CFrame.new(FISH_PEN_CENTER.X + offset.X, SURFACE_Y - 0.3, FISH_PEN_CENTER.Z + offset.Y)
		WorldDecor.smallLamp(decor, world)
	end

	-- Ahırın önünde fıçılar ve sandıklar
	WorldDecor.barrel(decor, at(9, 27))
	WorldDecor.barrel(decor, at(11.4, 28.4))
	WorldDecor.crate(decor, at(-9, 27), 2.2)
	WorldDecor.crate(decor, at(-11.4, 27.6), 1.6)
	WorldDecor.mailbox(decor, at(8, -53))

	-- Çiftlik avlusu: ana yolu çerçeveleyen alçak çitler, saman balyaları, korkuluk, el arabası ve kavşak tabelası
	for _, x in { -3.8, 3.8 } do
		WorldDecor.fenceRun(decor, pos(x, -34), pos(x, -21))
	end
	WorldDecor.hayBale(decor, at(-27, -26) * CFrame.Angles(0, 0.3, 0), true)
	WorldDecor.hayBale(decor, at(-23.5, -27.5) * CFrame.Angles(0, -0.2, 0), false)
	WorldDecor.hayBale(decor, at(-25.5, -23.8) * CFrame.Angles(0, 0.8, 0), false)
	WorldDecor.scarecrow(decor, at(-32, -23) * CFrame.Angles(0, 0.5, 0))
	WorldDecor.wheelbarrow(decor, at(24, -26) * CFrame.Angles(0, -0.6, 0))
	WorldDecor.barrel(decor, at(28, -25))
	WorldDecor.barrel(decor, at(30.2, -26.4))
	WorldDecor.crate(decor, at(27, -28.5), 1.8)
	buildSignpost(decor, at(5.6, -19.5), {
		{ label = "Ahır", icon = "🏚️", yaw = -90 },
		{ label = "Ağıllar", icon = Config.getHomeAnimalIcon(tostring(plotIndex)), yaw = -56 },
		{ label = "Liman", icon = "⚓", yaw = 115 },
	})

	-- Ana ada yapıları (HomeBuildings): yerleşim temaya göre değişir (homePlacements); ön (-Z) yönü yaw ile çevrilir.
	local placed = homePlacements(plotIndex)
	local function place(name: string): CFrame
		local spot = placed[name]
		return at(spot.x, spot.z) * CFrame.Angles(0, spot.yaw, 0)
	end
	-- Kapılı yapılar: her yapı kendi Model'inde; ahır (RevealBarnLevel) ya da bölge seviyesine (RevealZoneId/RevealZoneLevel)
	-- ulaşılınca görünür (Presentation/DecorReveal). Böylece geliştirdikçe ada gözle görülür büyür.
	local function gated(name: string, barnLevel: number?, zoneId: string?, zoneLevel: number?): Model
		local model = Instance.new("Model")
		model.Name = name
		if barnLevel then
			model:SetAttribute("RevealBarnLevel", barnLevel)
		end
		if zoneId and zoneLevel then
			model:SetAttribute("RevealZoneId", zoneId)
			model:SetAttribute("RevealZoneLevel", zoneLevel)
		end
		CollectionService:AddTag(model, "RevealGate")
		model.Parent = decor
		return model
	end
	HomeBuildings.market(decor, place("market"))
	HomeBuildings.farmhouse(gated("Farmhouse", nil, "pasture", 1), place("farmhouse"))
	HomeBuildings.well(gated("Well", 2), place("well"))
	HomeBuildings.vegetableGarden(gated("VegetableGarden", 2), place("garden"))
	HomeBuildings.windmill(gated("Windmill", 3), place("windmill"))
	HomeBuildings.beehives(gated("Beehives", 3), place("hives"))
	HomeBuildings.granary(gated("Granary", 3), place("granary"))
	HomeBuildings.orchard(gated("Orchard", 4), place("orchard"))
	HomeBuildings.landmark(gated("Landmark", 4), place("landmark"), Config.getTheme(tostring(plotIndex)).landmark)

	-- Ana adadan balık kafesine iskele (LookVector kafese bakar)
	WorldDecor.dock(
		decor,
		islandCf * CFrame.lookAt(DOCK_START, FISH_PEN_CENTER),
		DOCK_LENGTH,
		DOCK_SURFACE_Y,
		-WATER_DEPTH
	)
end

-- Temaya (çiftlik numarasına) bağlı içerik: yapı noktaları, ana ada süsleri ve yerleşimi, uzman adalar (+ bölgeleri).
-- Zemin (Terrain), ana bölgeler, ahır, doğma noktası, toplama platformu ve köprüler bütün adalarda aynıdır ve bunun dışındadır.
-- Çalışma anında oyuncu başka bir çiftliği etkinleştirince MapBuilder.applyTheme bu içeriği (Terrain'siz) yeniden kurar.
local function buildThemeContent(plotModel: Model, themeIndex: number, islandCf: CFrame, withTerrain: boolean)
	local info = Config.PLOT_NAMES[themeIndex]
	plotModel:SetAttribute("ThemeIndex", themeIndex)
	plotModel:SetAttribute("IslandName", if info then info.name else `Ada {themeIndex}`)
	plotModel:SetAttribute("IslandIcon", if info then info.icon else "🏝️")

	local buildSpots = Instance.new("Folder")
	buildSpots.Name = "BuildSpots"
	buildSpots.Parent = plotModel
	for upgradeId, offset in HOME_BUILD_SPOTS do
		addBuildSpot(buildSpots, upgradeId, islandCf * CFrame.new(offset.X, SURFACE_Y, offset.Z))
	end
	for upgradeId, site in IslandSpecialization.SITES do
		if site.island == "home" then
			local marker =
				addBuildSpot(buildSpots, upgradeId, islandCf * CFrame.new(site.offset + Vector3.new(0, SURFACE_Y, 0)))
			marker:SetAttribute("FarmIslandId", "home")
		end
	end
	for upgradeId, spot in HOME_WATER_SPOTS do
		local marker = addBuildSpot(
			buildSpots,
			upgradeId,
			islandCf * CFrame.new(spot.offset.X, WATER_Y, spot.offset.Z) * CFrame.Angles(0, math.rad(spot.yaw), 0)
		)
		marker:SetAttribute("BoatPatrolX", 6)
		marker:SetAttribute("BoatPatrolZ", 3)
	end

	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = plotModel
	decorateHome(decor, islandCf, themeIndex)
	IslandSpecialization.build(decor, "home", islandCf * CFrame.new(0, SURFACE_Y, 0))
	local grassAvoid = {
		{ x = 0, z = -20, hx = 5, hz = 52 }, -- ana yol
		{ x = 0, z = -16, hx = 22, hz = 4 },
		{ x = 0, z = 40, hx = 13, hz = 10 }, -- ahır
		{ x = -31, z = 33, hx = 5, hz = 5 }, -- silo
		{ x = 31, z = 33, hx = 5, hz = 5 }, -- süt makinesi
		{ x = 24, z = -40, hx = 5, hz = 5 },
		{ x = 0, z = -45, hx = 7, hz = 7 }, -- doğma noktası
		{ x = -36, z = 41, hx = 22, hz = 5 }, -- köprü yolları
		{ x = 36, z = 41, hx = 22, hz = 5 },
	}
	for _, rect in homeBuildingAvoidRects(themeIndex) do
		table.insert(grassAvoid, rect)
	end
	addIslandGrass(
		decor,
		islandCf * CFrame.new(0, SURFACE_Y, 0),
		"home",
		ISLAND_RADIUS,
		HOME_ZONES,
		grassAvoid,
		140,
		themeIndex * 97
	)

	local islandsFolder = Instance.new("Folder")
	islandsFolder.Name = "Islands"
	islandsFolder.Parent = plotModel
	for _, layout in satelliteLayouts(themeIndex) do
		buildSatellite(plotModel, islandsFolder, buildSpots, islandCf, layout, withTerrain)
	end
end

-- plotIndex: fiziksel ada numarası (konum); themeIndex: içeriğin teması (çiftlik numarası, varsayılan plotIndex)
local function buildIsland(plotIndex: number, islandCf: CFrame, theme: number?): Model
	local themeIndex = theme or plotIndex
	local info = Config.PLOT_NAMES[themeIndex]
	local islandName = if info then info.name else `Ada {themeIndex}`
	local islandIcon = if info then info.icon else "🏝️"

	local plotModel = Instance.new("Model")
	plotModel.Name = `Plot{plotIndex}`
	plotModel:SetAttribute("PlotId", tostring(plotIndex))
	-- Ana adanın yerel çerçevesi (yüzeyde): istemcideki yardımcılar yol ağını buradan dünyaya çevirir
	plotModel:SetAttribute("HomeFrame", islandCf * CFrame.new(0, SURFACE_Y, 0))
	plotModel:SetAttribute("HomeRadius", ISLAND_RADIUS)
	plotModel:SetAttribute("ThemeIndex", themeIndex)
	plotModel:SetAttribute("IslandName", islandName)
	plotModel:SetAttribute("IslandIcon", islandIcon)

	-- Kıyı Terrain (kaya + kum plaj); üstü tam düz çimen parça (PlotBase) — her şey tam SURFACE_Y'de durur
	WorldDecor.terrainIsland(plotModel, islandCf.Position, ISLAND_RADIUS, SURFACE_Y, 8)
	WorldDecor.shoreRocks(islandCf, ISLAND_RADIUS, { 25, -25, 65, 115, 150, -110, -80, -60 }, plotIndex * 31)
	local base = makeDisc(
		"PlotBase",
		ISLAND_RADIUS * 2,
		4,
		islandCf * CFrame.new(0, SURFACE_Y - 2, 0),
		Color3.fromRGB(86, 150, 68),
		plotModel
	)
	base.Material = Enum.Material.Grass
	base:SetAttribute("OpenColor", base.Color)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = plotModel
	for _, layout in HOME_ZONES do
		buildZone(plotModel, islandCf, layout)
	end

	-- Ahırın konumu (kapısı -Z yönüne, yani doğma noktasına bakar)
	local barnSpot =
		makePart("BarnSpot", Vector3.new(1, 1, 1), islandCf * CFrame.new(0, SURFACE_Y, 40), Color3.new(), plotModel)
	barnSpot.Transparency = 1
	barnSpot.CanCollide = false
	barnSpot.CanQuery = false
	BarnVisualService.buildAt(plotModel, 1)

	-- Doğma noktası: adanın sahibi burada doğar (PlotService Player.RespawnLocation'ı buna ayarlar).
	-- Neutral = false: sahibi olmayan oyuncular burada doğmaz, meydanda doğar. Oyuncu adaya doğru bakar.
	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "Spawn"
	spawnPad.Size = Vector3.new(8, 0.4, 8)
	spawnPad.CFrame = islandCf * CFrame.new(0, SURFACE_Y + 0.2, -45) * CFrame.Angles(0, math.pi, 0)
	spawnPad.Anchored = true
	spawnPad.Neutral = false
	spawnPad.AllowTeamChangeOnTouch = false
	spawnPad.Duration = 0
	spawnPad.Color = Color3.fromRGB(230, 225, 210)
	spawnPad.Material = Enum.Material.Slate
	spawnPad.TopSurface = Enum.SurfaceType.Smooth
	spawnPad.Parent = plotModel

	-- Para toplama platformu: altın çerçeve + parlayan yeşil yüzey
	local collectorCf = islandCf * CFrame.new(14, SURFACE_Y, -40)
	local rim = makePart(
		"CollectorRim",
		Vector3.new(7.4, 0.5, 7.4),
		collectorCf * CFrame.new(0, 0.25, 0),
		Color3.fromRGB(230, 180, 50),
		plotModel
	)
	rim.Material = Enum.Material.Metal
	local collector = makePart(
		"Collector",
		Vector3.new(6, 0.3, 6),
		collectorCf * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(60, 220, 90),
		plotModel
	)
	collector.Material = Enum.Material.Neon
	WorldUi.sign(collector, Enum.NormalId.Top, { text = "TOPLA", textColor = Color3.fromRGB(20, 90, 35) })
	WorldUi.tag(collector, "CollectorBillboard", {
		text = "Depo",
		icon = "💰",
		tint = UiTheme.Color.Green,
		widthStuds = 7,
		heightStuds = 1.6,
		offset = Vector3.new(0, 3.5, 0),
	})

	-- Ada tabelası: üstte ada adı, altta sahibi. Yaklaşınca "Adalar" menüsü açılır (TravelMenu).
	-- Tabela yolun üstünde durur ama alt kenarı karakter boyunun çok üstünde; direkler yolun dışında.
	local signCf = islandCf * CFrame.new(0, SURFACE_Y + 16, -56)
	local frameColor = Color3.fromRGB(140, 100, 60)
	local sign = makePart("PlotSign", Vector3.new(9, 2.8, 0.5), signCf, Color3.fromRGB(85, 60, 40), plotModel)
	sign.Material = Enum.Material.WoodPlanks
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		WorldUi.sign(sign, face, { icon = islandIcon, title = islandName, text = "Boş Ada" })
	end
	for _, y in { -1.55, 1.55 } do
		local frame =
			makePart("SignFrame", Vector3.new(9.4, 0.3, 0.7), signCf * CFrame.new(0, y, 0), frameColor, plotModel)
		frame.Material = Enum.Material.Wood
	end
	sign.CanCollide = false
	for _, x in { -5.4, 5.4 } do
		local post = makePart(
			"SignPost",
			Vector3.new(0.7, 18, 0.7),
			islandCf * CFrame.new(x, SURFACE_Y + 9, -56),
			frameColor,
			plotModel
		)
		post.Material = Enum.Material.Wood
	end
	addTravelPrompt(sign, islandName)

	-- Uzaktan (diğer adalardan) görünen ada adı
	local nameAnchor = makePart(
		"IslandLabelAnchor",
		Vector3.new(1, 1, 1),
		islandCf * CFrame.new(0, SURFACE_Y + 30, 0),
		Color3.new(),
		plotModel
	)
	nameAnchor.Transparency = 1
	nameAnchor.CanCollide = false
	nameAnchor.CanQuery = false
	WorldUi.tag(nameAnchor, "IslandLabel", {
		text = islandName,
		icon = islandIcon,
		tint = UiTheme.Color.Gold,
		widthStuds = 24,
		heightStuds = 3.6,
		maxDistance = 600,
	})

	buildThemeContent(plotModel, themeIndex, islandCf, true)

	plotModel.PrimaryPart = base
	return plotModel
end

return {
	buildIsland = buildIsland,
	buildThemeContent = buildThemeContent,
}
