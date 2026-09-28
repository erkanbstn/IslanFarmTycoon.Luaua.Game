--!strict
-- Deniz, ortada meydan ve etrafında halka şeklinde oyuncu çiftlikleri (takımadalar) kurar.
-- Her çiftlik: ana ada (inek ağılı, otlak, ahır, depo, doğma noktası, tabela) + arkasında köprüyle bağlı
-- 3 uzman ada (Tavuk / At / Keçi). Uzman adalar yol haritasından açılır; kilitliyken toprak renginde durur.
-- Ana ada yerel ekseni: -Z meydana bakar (doğma noktası o tarafta), +Z arkası (ahır ve uzman adalar).

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Studio plugin'i modülleri kopyalayıp taze Config ile çalıştırır; o durumda yanımızdaki "Shared" kullanılır.
local Shared = script.Parent.Parent:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))
local BarnVisualService = require(script.Parent:WaitForChild("BarnVisualService"))
local WorldDecor = require(script.Parent:WaitForChild("WorldDecor"))
local IslandSpecialization = require(script.Parent:WaitForChild("IslandSpecialization"))

local MapBuilder = {}

-- Harita düzenini (adalar, bölgeler, yapı yerleri) değiştirince bunu 1 artır:
-- oyun, place'e kaydedilmiş eski haritayı fark edip uyarır.
local MAP_VERSION = 17

local SURFACE_Y = 4 -- Ada ve meydan yüzeyinin yüksekliği
local WATER_Y = 0 -- Deniz yüzeyi
local ISLAND_RADIUS = 70
local SATELLITE_RADIUS = 42
local HUB_RADIUS = 40
local WATER_SIZE = 1100
local WATER_DEPTH = 20

type ZoneLayout = {
	id: string,
	offset: Vector3,
	size: Vector3,
	color: Color3,
	backReserve: number, -- Arkada hayvan konmayacak şerit (barınak, kümes...)
	water: boolean?, -- Denizdeki bölge (balık kafesi): zemin görünmez, çit yerine yüzen iskele
}

local FISH_PEN_CENTER = Vector3.new(-40, 0, -95)
local FISH_PEN_SIZE = Vector3.new(20, 0.4, 20)
local FISH_WALKWAY_WIDTH = 2.4

-- Ana adadaki bölgeler (ana ada yerel koordinatı)
local HOME_ZONES: { ZoneLayout } = {
	{
		id = "starter",
		offset = Vector3.new(-20, 0, 2),
		size = Vector3.new(30, 0.4, 24),
		color = Color3.fromRGB(96, 150, 70),
		backReserve = 2.5,
	},
	{
		id = "pasture",
		offset = Vector3.new(20, 0, 2),
		size = Vector3.new(30, 0.4, 26),
		color = Color3.fromRGB(110, 170, 80),
		backReserve = 4,
	},
	-- Ana adanın ön-solunda denizde; iskeleyle bağlı (meydan köprüsünden ve komşu adalardan uzak)
	{
		id = "fishpen",
		offset = FISH_PEN_CENTER,
		size = FISH_PEN_SIZE,
		color = Color3.fromRGB(40, 110, 150),
		backReserve = 0,
		water = true,
	},
}

local DOCK_START = Vector3.new(-26.4, 0, -62.7) -- Ana adanın kenarında, kafese bakan nokta
-- Diyagonal iskelenin ucu yakın yürüyüş tahtasının merkezine ulaşır; sabit uzunlukta boşluk kalmaz.
local dockDirection = (FISH_PEN_CENTER - DOCK_START).Unit
local dockJoinZ = FISH_PEN_CENTER.Z + FISH_PEN_SIZE.Z / 2 + FISH_WALKWAY_WIDTH / 2
local DOCK_LENGTH = (dockJoinZ - DOCK_START.Z) / dockDirection.Z
local DOCK_SURFACE_Y = SURFACE_Y - 0.04 -- Kara/tahta birleşiminde üst üste yüzeyler titreşmesin.

-- Ana adadaki güçlendirme binalarının yerleri (UpgradeVisualService kullanır)
local HOME_BUILD_SPOTS: { [string]: Vector3 } = {
	silo = Vector3.new(-31, 0, 33),
	milk_machine = Vector3.new(31, 0, 33),
	auto_collector = Vector3.new(24, 0, -40),
}

-- Denizdeki bina yerleri (su seviyesinde): Balıkçı Teknesi kafesin dış kenarına bağlanır
local HOME_WATER_SPOTS: { [string]: { offset: Vector3, yaw: number } } = {
	fishing_boat = { offset = Vector3.new(-40, 0, -126), yaw = 90 },
}

type SatelliteLayout = {
	id: string, -- Config.FARM_ISLANDS id
	offset: Vector3, -- Ana adaya göre konum
	groundColor: Color3,
	zone: ZoneLayout,
	buildSpot: { upgradeId: string, offset: Vector3 }?,
}

-- Uzman adalar (kendi yerel koordinatlarında -Z ana adaya, yani köprüye bakar)
local SATELLITES: { SatelliteLayout } = {
	{
		id = "poultry",
		offset = Vector3.new(-85, 0, 105),
		groundColor = Color3.fromRGB(150, 165, 80),
		zone = {
			id = "poultry",
			offset = Vector3.new(0, 0, 2),
			size = Vector3.new(30, 0.4, 24),
			color = Color3.fromRGB(205, 185, 125),
			backReserve = 8,
		},
		buildSpot = { upgradeId = "egg_factory", offset = Vector3.new(0, 0, 26) },
	},
	{
		id = "horse",
		offset = Vector3.new(85, 0, 105),
		groundColor = Color3.fromRGB(90, 150, 70),
		zone = {
			id = "stable",
			offset = Vector3.new(0, 0, 2),
			size = Vector3.new(30, 0.4, 24),
			color = Color3.fromRGB(145, 110, 80),
			backReserve = 8,
		},
		buildSpot = { upgradeId = "golden_horseshoe", offset = Vector3.new(0, 0, 25) },
	},
	{
		id = "goat",
		offset = Vector3.new(0, 0, 165),
		groundColor = Color3.fromRGB(120, 140, 95),
		zone = {
			id = "goatpen",
			offset = Vector3.new(0, 0, 2),
			size = Vector3.new(30, 0.4, 24),
			color = Color3.fromRGB(130, 150, 90),
			backReserve = 5,
		},
		buildSpot = { upgradeId = "cheese_dairy", offset = Vector3.new(0, 0, 26) },
	},
}

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Silindir Part'ın ekseni X'tir; yere yatık değil dik durması için Z etrafında 90° döndürülür.
local function makeDisc(
	name: string,
	diameter: number,
	height: number,
	center: CFrame,
	color: Color3,
	parent: Instance
): Part
	local part = makePart(
		name,
		Vector3.new(height, diameter, diameter),
		center * CFrame.Angles(0, 0, math.rad(90)),
		color,
		parent
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Tabelaya yaklaşınca çıkan "Adalar" düğmesi; client'taki TravelMenu dinler
local function addTravelPrompt(part: BasePart, objectText: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TravelPrompt"
	prompt.ActionText = "Adalara Git"
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
end

-- Konuma göre sabit tohum: aynı harita her kurulumda aynı görünsün
local function seedFrom(cf: CFrame): number
	local p = cf.Position
	return math.abs(math.floor(p.X * 7 + p.Z * 13)) + 1
end

local function buildTree(parent: Instance, base: CFrame)
	local seed = seedFrom(base)
	if seed % 3 == 0 then
		WorldDecor.pineTree(parent, base, seed)
	else
		WorldDecor.oakTree(parent, base, seed)
	end
end

-- Bölge adı / kilit bilgisi (metni PlotService yazar)
local function addZoneLabel(zoneModel: Model, center: CFrame, zoneConfig: Config.ZoneConfig)
	local labelAnchor =
		makePart("LabelAnchor", Vector3.new(1, 1, 1), center * CFrame.new(0, 12, 0), Color3.new(), zoneModel)
	labelAnchor.Transparency = 1
	labelAnchor.CanCollide = false
	labelAnchor.CanQuery = false
	WorldUi.tag(labelAnchor, "ZoneBillboard", {
		text = zoneConfig.displayName,
		icon = zoneConfig.icon,
		tint = UiTheme.Color.Green,
		widthStuds = 9,
		heightStuds = 1.8,
	})
end

-- Balık kafesinin çevresindeki kazıklı yürüme yolu (iskeleyle aynı yükseklikte)
local function buildFloatingWalkway(zoneModel: Model, center: CFrame, size: Vector3)
	local walkway = Instance.new("Model")
	walkway.Name = "Walkway"
	walkway.Parent = zoneModel
	local wood = Color3.fromRGB(125, 90, 60)
	local deckY = SURFACE_Y - 0.3
	local frame = CFrame.new(center.Position.X, deckY, center.Position.Z) * center.Rotation
	local width = FISH_WALKWAY_WIDTH
	local hx, hz = size.X / 2 + width / 2, size.Z / 2 + width / 2
	local planks = {
		{ Vector3.new(size.X + width * 2, 0.6, width), Vector3.new(0, 0, hz) },
		{ Vector3.new(size.X + width * 2, 0.6, width), Vector3.new(0, 0, -hz) },
		{ Vector3.new(width, 0.6, size.Z), Vector3.new(hx, 0, 0) },
		{ Vector3.new(width, 0.6, size.Z), Vector3.new(-hx, 0, 0) },
	}
	for _, plank in planks do
		local p = makePart("Deck", plank[1], frame * CFrame.new(plank[2]), wood, walkway)
		p.Material = Enum.Material.WoodPlanks
		p.CanTouch = false
		p:SetAttribute("WalkSurfaceY", SURFACE_Y)
	end
	for _, x in { -hx, 0, hx } do
		for _, z in { -hz, 0, hz } do
			if x == 0 and z == 0 then
				continue
			end
			WorldDecor.pierPile(walkway, (frame * CFrame.new(x, 0, z)).Position, SURFACE_Y, -WATER_DEPTH)
		end
	end
end

local function buildZone(plotModel: Model, islandCf: CFrame, layout: ZoneLayout)
	-- Tüm bölgeler (uzman adalardakiler de) plot.Zones altında durur; servisler tek yerden bulur
	local zoneConfig = Config.ZONES[layout.id]
	if not zoneConfig then
		return
	end

	local zoneModel = Instance.new("Model")
	zoneModel.Name = zoneConfig.displayName
	zoneModel:SetAttribute("ZoneId", layout.id)
	zoneModel.Parent = plotModel:FindFirstChild("Zones")

	local isWater = layout.water == true
	local surfaceY = if isWater then WATER_Y else SURFACE_Y
	local center = islandCf * CFrame.new(layout.offset.X, surfaceY + layout.size.Y / 2, layout.offset.Z)
	local ground = makePart("Ground", layout.size, center, layout.color, zoneModel)
	ground.Material = if layout.id == "poultry" or layout.id == "stable"
		then Enum.Material.Sand
		else Enum.Material.Grass
	ground:SetAttribute("OpenColor", layout.color)
	ground:SetAttribute("BackReserve", layout.backReserve)
	zoneModel.PrimaryPart = ground

	if isWater then
		-- Balıklar yüzeyin bu kadar altında yüzer (AnimalVisualService); zemin görünmez
		ground:SetAttribute("SwimDepth", 1.8)
		ground.Transparency = 1
		ground.CanCollide = false
		ground.CanQuery = false
		buildFloatingWalkway(zoneModel, center, layout.size)
		addZoneLabel(zoneModel, center, zoneConfig)
		return
	end

	-- Direkli çit; ön tarafta (-Z, doğma noktası yönü) giriş boşluğu
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	fence.Parent = zoneModel
	local postColor = Color3.fromRGB(120, 85, 55)
	local railColor = Color3.fromRGB(165, 125, 80)
	local hx, hz = layout.size.X / 2, layout.size.Z / 2
	local gap = 6
	local top = layout.size.Y / 2

	-- Köşe direkleri iki segmentte de oluşmasın: üst üste binen parçalar yürürken titrer (z-fighting)
	local placedPosts: { [string]: boolean } = {}
	local function fenceSegment(from: Vector3, to: Vector3)
		local length = (to - from).Magnitude
		local posts = math.max(1, math.round(length / 4))
		for i = 0, posts do
			local p = from:Lerp(to, i / posts)
			local key = `{math.round(p.X * 10)},{math.round(p.Z * 10)}`
			if placedPosts[key] then
				continue
			end
			placedPosts[key] = true
			local post =
				makePart("Post", Vector3.new(0.7, 3.4, 0.7), center * CFrame.new(p.X, top + 1.7, p.Z), postColor, fence)
			post.Material = Enum.Material.Wood
		end
		local mid = (from + to) / 2
		local rotation = if math.abs(to.X - from.X) > 0.01 then CFrame.new() else CFrame.Angles(0, math.rad(90), 0)
		for _, height in { 1.3, 2.6 } do
			local rail = makePart(
				"Rail",
				Vector3.new(length, 0.45, 0.3),
				center * CFrame.new(mid.X, top + height, mid.Z) * rotation,
				railColor,
				fence
			)
			rail.Material = Enum.Material.Wood
		end
	end

	fenceSegment(Vector3.new(-hx, 0, hz), Vector3.new(hx, 0, hz))
	fenceSegment(Vector3.new(-hx, 0, -hz), Vector3.new(-hx, 0, hz))
	fenceSegment(Vector3.new(hx, 0, -hz), Vector3.new(hx, 0, hz))
	fenceSegment(Vector3.new(-hx, 0, -hz), Vector3.new(-gap / 2, 0, -hz))
	fenceSegment(Vector3.new(gap / 2, 0, -hz), Vector3.new(hx, 0, -hz))

	addZoneLabel(zoneModel, center, zoneConfig)
end

local function addBuildSpot(folder: Instance, upgradeId: string, cf: CFrame): Part
	local marker = makePart(upgradeId, Vector3.new(1, 1, 1), cf, Color3.new(), folder)
	marker.Transparency = 1
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	return marker
end

-- İki nokta arasında tahta köprü (uçları ada zemininin 0.05 altında: çakışıp titremesin)
local function buildBridgeBetween(parent: Instance, from: Vector3, to: Vector3)
	local y = SURFACE_Y - 0.55
	local a = Vector3.new(from.X, y, from.Z)
	local b = Vector3.new(to.X, y, to.Z)
	local length = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	local bridge = makePart("Bridge", Vector3.new(8, 1, length), cf, Color3.fromRGB(140, 100, 60), parent)
	bridge.Material = Enum.Material.WoodPlanks
	for _, side in { -4, 4 } do
		local rail = makePart(
			"Rail",
			Vector3.new(0.5, 2, length),
			cf * CFrame.new(side, 1.5, 0),
			Color3.fromRGB(110, 80, 50),
			parent
		)
		rail.Material = Enum.Material.Wood
	end
end

-- Adaya özel süsler ve yollar (açık/kilitli fark etmez; adanın karakterini gösterir)
local function buildSatelliteDecor(islandId: string, parent: Instance, cf: CFrame)
	local function at(x: number, z: number): CFrame
		return cf * CFrame.new(x, SURFACE_Y, z)
	end
	-- Ortak köprü girişi açık kalır; her adanın çalışma alanı farklı kenardadır.
	WorldDecor.path(parent, at(0, -(SATELLITE_RADIUS - 2)).Position, at(0, -11).Position, 5)
	WorldDecor.lamp(parent, at(-5, -30))
	if islandId == "goat" then
		WorldDecor.pineTree(parent, at(30, 11), seedFrom(cf))
		WorldDecor.bush(parent, at(23, -25), 23)
	else
		for _, x in { -13, 13 } do
			if islandId == "horse" then
				WorldDecor.pineTree(parent, at(x, 32), seedFrom(cf) + x)
			else
				WorldDecor.oakTree(parent, at(x, 31), seedFrom(cf) + x)
			end
		end
		WorldDecor.bush(parent, at(25, 25), 21 + #islandId)
	end
	IslandSpecialization.build(parent, islandId, cf * CFrame.new(0, SURFACE_Y, 0))
end

-- Uzman ada: gövde, bölge, tabela (satın alma düğmesiyle), uzaktan görünen ad, bina yeri, köprü
local function buildSatellite(
	plotModel: Model,
	islandsFolder: Instance,
	buildSpots: Instance,
	homeCf: CFrame,
	layout: SatelliteLayout
)
	local islandConfig = Config.FARM_ISLANDS[layout.id]
	local upgrade = if islandConfig.upgradeId then Config.getUpgrade(islandConfig.upgradeId) else nil

	local islandModel = Instance.new("Model")
	islandModel.Name = islandConfig.displayName
	islandModel:SetAttribute("FarmIslandId", layout.id)
	islandModel.Parent = islandsFolder

	local center = homeCf * CFrame.new(layout.offset)
	local cf = CFrame.lookAt(center.Position, homeCf.Position) -- -Z ana adaya (köprüye) bakar

	-- Kıyı Terrain (kaya + kum plaj); üstü düz çimen parça
	WorldDecor.terrainIsland(islandModel, cf.Position, SATELLITE_RADIUS, SURFACE_Y, 7)
	WorldDecor.shoreRocks(cf, SATELLITE_RADIUS, { 35, -35, 90, -90, 140, -140 }, seedFrom(cf))
	local base = makeDisc(
		"IslandBase",
		SATELLITE_RADIUS * 2,
		4,
		cf * CFrame.new(0, SURFACE_Y - 2, 0),
		layout.groundColor,
		islandModel
	)
	-- Ada yüzeyi: tam düz parça (kilitliyken PlotService toprak rengine çevirir)
	base.Material = Enum.Material.Grass
	base:SetAttribute("OpenColor", layout.groundColor)
	base:SetAttribute("Radius", SATELLITE_RADIUS)
	islandModel.PrimaryPart = base

	buildZone(plotModel, cf, layout.zone)
	if layout.buildSpot then
		local spotCf = cf * CFrame.new(layout.buildSpot.offset.X, SURFACE_Y, layout.buildSpot.offset.Z)
		addBuildSpot(buildSpots, layout.buildSpot.upgradeId, spotCf)
	end
	for upgradeId, site in IslandSpecialization.SITES do
		if site.island == layout.id then
			local marker =
				addBuildSpot(buildSpots, upgradeId, cf * CFrame.new(site.offset + Vector3.new(0, SURFACE_Y, 0)))
			marker:SetAttribute("FarmIslandId", layout.id)
		end
	end
	buildSatelliteDecor(layout.id, islandModel, cf)

	-- Köprünün yanında ada tabelası: ad + özellik; kilitliyken "Satın Al" düğmesi
	local signCf = cf * CFrame.new(10, SURFACE_Y + 4, -(SATELLITE_RADIUS - 8))
	local frameColor = Color3.fromRGB(140, 100, 60)
	local sign = makePart("IslandSign", Vector3.new(12, 3.4, 0.5), signCf, Color3.fromRGB(85, 60, 40), islandModel)
	sign.Material = Enum.Material.WoodPlanks
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		WorldUi.sign(
			sign,
			face,
			{ icon = islandConfig.icon, title = islandConfig.displayName, text = islandConfig.trait }
		)
	end
	for _, x in { -6.3, 6.3 } do
		local post = makePart(
			"SignPost",
			Vector3.new(0.7, 6, 0.7),
			cf * CFrame.new(10 + x, SURFACE_Y + 3, -(SATELLITE_RADIUS - 8)),
			frameColor,
			islandModel
		)
		post.Material = Enum.Material.Wood
	end
	if upgrade then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BuyIslandPrompt"
		prompt.ActionText = "Satın Al"
		prompt.ObjectText = islandConfig.displayName
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("UpgradeId", upgrade.id)
		prompt:SetAttribute("Locked", true)
		WorldUi.configureProximityPrompt(prompt)
		prompt.Parent = sign
	end

	-- Uzaktan görünen ad (kilitliyken fiyatı da yazar; metni PlotService günceller)
	local nameAnchor = makePart(
		"IslandLabelAnchor",
		Vector3.new(1, 1, 1),
		cf * CFrame.new(0, SURFACE_Y + 22, 0),
		Color3.new(),
		islandModel
	)
	nameAnchor.Transparency = 1
	nameAnchor.CanCollide = false
	nameAnchor.CanQuery = false
	WorldUi.tag(nameAnchor, "IslandLabel", {
		text = islandConfig.displayName,
		icon = islandConfig.icon,
		tint = UiTheme.Color.Gold,
		widthStuds = 16,
		heightStuds = 2.8,
		maxDistance = 400,
	})

	-- Ana adadan uzman adaya köprü (iki adanın kenarları arası)
	local direction = (cf.Position - homeCf.Position).Unit
	buildBridgeBetween(
		islandModel,
		homeCf.Position + direction * (ISLAND_RADIUS - 2),
		cf.Position - direction * (SATELLITE_RADIUS - 2)
	)
end

-- Ana adanın yolları ve süsleri. Yollar: meydan köprüsü → doğma noktası → ağıllar → ahır → uzman ada köprüleri
local function decorateHome(decor: Instance, islandCf: CFrame, plotIndex: number)
	local function at(x: number, z: number): CFrame
		return islandCf * CFrame.new(x, SURFACE_Y, z)
	end
	local function pos(x: number, z: number): Vector3
		return at(x, z).Position
	end

	WorldDecor.path(decor, pos(0, -(ISLAND_RADIUS - 2)), pos(0, -49), 6)
	WorldDecor.path(decor, pos(0, -41), pos(0, 28), 6)
	WorldDecor.path(decor, pos(3, -42), pos(12, -40), 4)
	WorldDecor.path(decor, pos(-20, -16), pos(20, -16), 5)
	WorldDecor.path(decor, pos(-14, 27), pos(-43, 53), 5)
	WorldDecor.path(decor, pos(14, 27), pos(43, 53), 5)
	WorldDecor.path(decor, pos(-15, 28), pos(-16, 54), 5)
	WorldDecor.path(decor, pos(-16, 54), pos(0, ISLAND_RADIUS - 2), 5)
	WorldDecor.path(decor, pos(-4, -50), pos(DOCK_START.X, DOCK_START.Z), 4) -- balık kafesi iskelesine

	local trees = {
		Vector2.new(-45, -35),
		Vector2.new(45, -38),
		Vector2.new(-58, -5),
		Vector2.new(58, -8),
		Vector2.new(-54, 20),
		Vector2.new(54, 20),
		Vector2.new(-32, -48),
		Vector2.new(30, -58),
	}
	for _, spot in trees do
		buildTree(decor, at(spot.X, spot.Y))
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

	for _, spot in { Vector2.new(-4.8, -34), Vector2.new(4.8, -20), Vector2.new(-4.8, 18) } do
		WorldDecor.lamp(decor, at(spot.X, spot.Y))
	end

	-- Ahırın önünde fıçılar ve sandıklar
	WorldDecor.barrel(decor, at(9, 27))
	WorldDecor.barrel(decor, at(11.4, 28.4))
	WorldDecor.crate(decor, at(-9, 27), 2.2)
	WorldDecor.crate(decor, at(-11.4, 27.6), 1.6)
	WorldDecor.mailbox(decor, at(8, -53))

	-- Ana adadan balık kafesine iskele (LookVector kafese bakar)
	WorldDecor.dock(
		decor,
		islandCf * CFrame.lookAt(DOCK_START, FISH_PEN_CENTER),
		DOCK_LENGTH,
		DOCK_SURFACE_Y,
		-WATER_DEPTH
	)
end

local function buildIsland(plotIndex: number, islandCf: CFrame): Model
	local info = Config.PLOT_NAMES[plotIndex]
	local islandName = if info then info.name else `Ada {plotIndex}`
	local islandIcon = if info then info.icon else "🏝️"

	local plotModel = Instance.new("Model")
	plotModel.Name = `Plot{plotIndex}`
	plotModel:SetAttribute("PlotId", tostring(plotIndex))
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
		tint = UiTheme.Color.Gold,
		widthStuds = 7,
		heightStuds = 1.6,
		offset = Vector3.new(0, 3.5, 0),
	})

	-- Ada tabelası: üstte ada adı, altta sahibi. Yaklaşınca "Adalar" menüsü açılır (TravelMenu).
	local signCf = islandCf * CFrame.new(0, SURFACE_Y + 5, -56)
	local frameColor = Color3.fromRGB(140, 100, 60)
	local sign = makePart("PlotSign", Vector3.new(11, 3.2, 0.5), signCf, Color3.fromRGB(85, 60, 40), plotModel)
	sign.Material = Enum.Material.WoodPlanks
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		WorldUi.sign(sign, face, { icon = islandIcon, title = islandName, text = "Boş Ada" })
	end
	for _, y in { -1.75, 1.75 } do
		local frame =
			makePart("SignFrame", Vector3.new(11.6, 0.3, 0.7), signCf * CFrame.new(0, y, 0), frameColor, plotModel)
		frame.Material = Enum.Material.Wood
	end
	for _, x in { -5.8, 5.8 } do
		local post = makePart(
			"SignPost",
			Vector3.new(0.7, 7, 0.7),
			islandCf * CFrame.new(x, SURFACE_Y + 3.5, -56),
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
	decorateHome(decor, islandCf, plotIndex)
	IslandSpecialization.build(decor, "home", islandCf * CFrame.new(0, SURFACE_Y, 0))

	local islandsFolder = Instance.new("Folder")
	islandsFolder.Name = "Islands"
	islandsFolder.Parent = plotModel
	for _, layout in SATELLITES do
		buildSatellite(plotModel, islandsFolder, buildSpots, islandCf, layout)
	end

	plotModel.PrimaryPart = base
	return plotModel
end

local function buildHub(parent: Instance)
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	hub.Parent = parent

	-- Meydan: kıyısı Terrain, zemini düz arnavut kaldırımı parça; çevresinde fenerler
	WorldDecor.terrainIsland(hub, Vector3.zero, HUB_RADIUS, SURFACE_Y, 6)
	local floor =
		makeDisc("Floor", HUB_RADIUS * 2, 4, CFrame.new(0, SURFACE_Y - 2, 0), Color3.fromRGB(165, 160, 150), hub)
	floor.Material = Enum.Material.Cobblestone
	for i = 1, 6 do
		local angle = (i - 0.5) / 6 * math.pi * 2
		local p = Vector3.new(math.sin(angle), 0, math.cos(angle)) * (HUB_RADIUS - 4)
		WorldDecor.lamp(hub, CFrame.lookAt(p + Vector3.new(0, SURFACE_Y, 0), Vector3.new(0, SURFACE_Y, 0)))
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.new(0, SURFACE_Y + 0.2, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(240, 200, 80)
	spawn.Parent = hub

	-- Tabela iki köprünün arasına, meydanın ortasına bakacak şekilde
	local betweenBridges = math.pi / Config.MAP_PLOT_COUNT
	local signPos = Vector3.new(math.sin(betweenBridges), 0, math.cos(betweenBridges)) * (HUB_RADIUS - 8)
	local signCf = CFrame.lookAt(signPos, Vector3.zero)
	local sign = makePart(
		"Title",
		Vector3.new(20, 6, 1),
		signCf + Vector3.new(0, SURFACE_Y + 12, 0),
		Color3.fromRGB(150, 45, 40),
		hub
	)
	sign.Material = Enum.Material.Wood
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		WorldUi.sign(sign, face, { icon = "🐄", title = "Hoş geldin", text = Config.GAME_NAME })
	end
	makePart(
		"Pole",
		Vector3.new(1, 9, 1),
		signCf * CFrame.new(0, SURFACE_Y + 4.5, 0.9),
		Color3.fromRGB(80, 60, 40),
		hub
	)

	-- Direğin önünde yön tabelası: adalara ışınlanma menüsü
	local board = makePart(
		"TravelBoard",
		Vector3.new(6, 2.4, 0.4),
		signCf * CFrame.new(0, SURFACE_Y + 3.5, 0.2),
		Color3.fromRGB(85, 60, 40),
		hub
	)
	board.Material = Enum.Material.WoodPlanks
	WorldUi.sign(board, Enum.NormalId.Front, { icon = "🧭", text = "Adalar", tint = UiTheme.Color.Blue })
	addTravelPrompt(board, "Meydan")
end

local function buildBridge(parent: Instance, direction: Vector3)
	local startDist = HUB_RADIUS - 2
	local endDist = Config.ISLAND_RING_RADIUS - ISLAND_RADIUS + 2
	local length = endDist - startDist
	local mid = direction * (startDist + length / 2)
	-- Üst yüzey, ada/meydan zemininin 0.05 altında: uçlar zeminle aynı düzlemde çakışıp titremesin
	local y = SURFACE_Y - 0.55
	local cf = CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(0, y, 0))
	local bridge = makePart("Bridge", Vector3.new(8, 1, length), cf, Color3.fromRGB(140, 100, 60), parent)
	bridge.Material = Enum.Material.WoodPlanks
	for _, side in { -4, 4 } do
		local rail = makePart(
			"Rail",
			Vector3.new(0.5, 2, length),
			cf * CFrame.new(side, 1.5, 0),
			Color3.fromRGB(110, 80, 50),
			parent
		)
		rail.Material = Enum.Material.Wood
	end
end

-- Harita sözleşmesi: eksik dünyada ekonomik oturum açılmaz.
function MapBuilder.validate()
	local plots = Workspace:FindFirstChild("Plots")
	assert(plots and plots:IsA("Folder"), "[Map] Plots klasörü eksik; Haritayı Kur ile yeniden oluştur.")
	assert(
		plots:GetAttribute("MapVersion") == MAP_VERSION,
		"[Map] Harita sürümü uyumsuz; Haritayı Kur ve place kaydı gerekli."
	)
	local world = Workspace:FindFirstChild("World")
	local hub = world and world:FindFirstChild("HubSpawn", true)
	assert(hub and hub:IsA("BasePart"), "[Map] World/HubSpawn eksik.")
	local ids: { [string]: boolean } = {}
	local count = 0
	for _, plot in plots:GetChildren() do
		assert(plot:IsA("Model"), `[Map] Geçersiz plot: {plot.Name}`)
		local id = plot:GetAttribute("PlotId")
		assert(typeof(id) == "string" and id ~= "" and not ids[id], `[Map] Eksik/tekrarlı PlotId: {plot.Name}`)
		ids[id] = true
		count += 1
		for _, name in { "Spawn", "Collector", "BarnSpot" } do
			local part = plot:FindFirstChild(name)
			assert(part and part:IsA("BasePart"), `[Map] {plot.Name}/{name} eksik.`)
		end
		local zones = plot:FindFirstChild("Zones")
		assert(zones and zones:IsA("Folder"), `[Map] {plot.Name}/Zones eksik.`)
		local zoneIds: { [string]: boolean } = {}
		for _, zone in zones:GetChildren() do
			local zoneId = zone:GetAttribute("ZoneId")
			assert(
				typeof(zoneId) == "string" and Config.ZONES[zoneId] and not zoneIds[zoneId],
				`[Map] {plot.Name}: geçersiz/tekrarlı bölge.`
			)
			local ground = zone:FindFirstChild("Ground")
			assert(ground and ground:IsA("BasePart"), `[Map] {plot.Name}/{zone.Name}/Ground eksik.`)
			assert(ground.Size.X > 0 and ground.Size.Z > 0, "[Map] Geçersiz bölge boyutu.")
			zoneIds[zoneId] = true
		end
		for zoneId in Config.ZONES do
			assert(zoneIds[zoneId], `[Map] {plot.Name}/{zoneId} bölgesi eksik.`)
		end
		local islands = plot:FindFirstChild("Islands")
		assert(islands and islands:IsA("Folder"), `[Map] {plot.Name}/Islands eksik.`)
		local islandIds: { [string]: boolean } = {}
		for _, island in islands:GetChildren() do
			local islandId = island:GetAttribute("FarmIslandId")
			assert(
				typeof(islandId) == "string" and Config.FARM_ISLANDS[islandId] and not islandIds[islandId],
				`[Map] {plot.Name}: geçersiz/tekrarlı uzman ada.`
			)
			local base = island:FindFirstChild("IslandBase")
			assert(base and base:IsA("BasePart"), `[Map] {plot.Name}/{island.Name}/IslandBase eksik.`)
			assert(island:FindFirstChild("Specialization"), `[Map] {plot.Name}/{island.Name}: uzmanlık alanı eksik.`)
			islandIds[islandId] = true
		end
		for islandId, island in Config.FARM_ISLANDS do
			if island.upgradeId then
				assert(islandIds[islandId], `[Map] {plot.Name}/{islandId} adası eksik.`)
			end
		end
		local homeDecor = plot:FindFirstChild("Decor")
		assert(
			homeDecor and homeDecor:FindFirstChild("Specialization"),
			`[Map] {plot.Name}: süt işleme alanı eksik.`
		)
		local spots = plot:FindFirstChild("BuildSpots")
		assert(spots and spots:IsA("Folder"), `[Map] {plot.Name}/BuildSpots eksik.`)
		for upgradeId in IslandSpecialization.SITES do
			local spot = spots:FindFirstChild(upgradeId)
			assert(spot and spot:IsA("BasePart"), `[Map] {plot.Name}/{upgradeId} üretim noktası eksik.`)
		end
		for _, upgrade in Config.UPGRADES do
			if upgrade.kind == "boost" then
				local spot = spots:FindFirstChild(upgrade.id)
				assert(spot and spot:IsA("BasePart"), `[Map] {plot.Name}/{upgrade.id} yapı noktası eksik.`)
			end
		end
	end
	assert(count == Config.MAP_PLOT_COUNT, `[Map] {Config.MAP_PLOT_COUNT} ada bekleniyor; {count} bulundu.`)
end

local function hasValidPlots(_plotsFolder: Instance): boolean
	local ok = pcall(MapBuilder.validate)
	return ok
end

function MapBuilder.warnIfNoPlots()
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if plotsFolder and hasValidPlots(plotsFolder) then
		return
	end
	warn("[Map] Workspace'te ada yok. Studio'da 'Ahır Tycoon → Haritayı Kur' butonuna bas.")
end

local function getOrCreate(parent: Instance, className: string): Instance
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Parent = parent
	return created
end

-- Sıcak, canlı bir öğleden sonra: yumuşak gölgeler, hafif parıltı, güneş ışınları, bulutlar.
-- (Lighting.Technology = Future, default.project.json'dan gelir; script ile ayarlanamıyor.)
local function applyLighting()
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.4
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 135, 150)
	Lighting.Ambient = Color3.fromRGB(70, 70, 80)

	local atmosphere = getOrCreate(Lighting, "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(199, 220, 235)
	atmosphere.Decay = Color3.fromRGB(106, 135, 165)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.3

	local bloom = getOrCreate(Lighting, "BloomEffect") :: BloomEffect
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.8

	local sunRays = getOrCreate(Lighting, "SunRaysEffect") :: SunRaysEffect
	sunRays.Intensity = 0.05
	sunRays.Spread = 0.8

	local color = getOrCreate(Lighting, "ColorCorrectionEffect") :: ColorCorrectionEffect
	color.Saturation = 0.15
	color.Contrast = 0.08
	color.Brightness = 0.02
	color.TintColor = Color3.fromRGB(255, 250, 240)

	local clouds = getOrCreate(Workspace.Terrain, "Clouds") :: Clouds
	clouds.Cover = 0.55
	clouds.Density = 0.6
end

-- Deniz: su + kum taban + görünmez güvenlik zemini ve kenar duvarları.
-- Eskiden suyun altı boşluktu; dalan ya da dipten geçen oyuncu boşluğa düşüp ölüyordu.
-- Her açılışta da çağrılır (ensure): kayıtlı haritada su eksikse boş hücreleri suyla doldurur.
local function ensureSea()
	local terrain = Workspace.Terrain
	local half = WATER_SIZE / 2
	-- Boş (Air) hücreleri suyla doldur: adaların kayalarına dokunmaz
	local region = Region3.new(Vector3.new(-half, -WATER_DEPTH, -half), Vector3.new(half, 0, half)):ExpandToGrid(4)
	terrain:ReplaceMaterial(region, 4, Enum.Material.Air, Enum.Material.Water)
	-- Dipte kum: sudan bakınca deniz tabanı görünsün
	terrain:FillBlock(CFrame.new(0, -WATER_DEPTH - 2, 0), Vector3.new(WATER_SIZE, 4, WATER_SIZE), Enum.Material.Sand)

	local world = Workspace:FindFirstChild("World")
	if not world then
		world = Instance.new("Folder")
		world.Name = "World"
		world.Parent = Workspace
	end
	local worldFolder = world :: Instance
	if worldFolder:FindFirstChild("SeaSafety") then
		return
	end
	local safety = Instance.new("Model")
	safety.Name = "SeaSafety"
	safety.Parent = worldFolder

	local function invisible(name: string, size: Vector3, cf: CFrame)
		local p = makePart(name, size, cf, Color3.new(), safety)
		p.Transparency = 1
		p.CastShadow = false
		p.CanQuery = false
	end
	-- Kumun altında: ne olursa olsun kimse boşluğa düşmesin
	invisible("SafetyFloor", Vector3.new(WATER_SIZE + 200, 2, WATER_SIZE + 200), CFrame.new(0, -WATER_DEPTH - 6, 0))
	-- Haritanın kenarı: denizin sonuna görünmez duvar
	local wallHeight = 200
	for _, side in { -1, 1 } do
		invisible(
			"EdgeWall",
			Vector3.new(4, wallHeight, WATER_SIZE),
			CFrame.new(side * (half - 20), wallHeight / 2 - WATER_DEPTH, 0)
		)
		invisible(
			"EdgeWall",
			Vector3.new(WATER_SIZE, wallHeight, 4),
			CFrame.new(0, wallHeight / 2 - WATER_DEPTH, side * (half - 20))
		)
	end
end

-- Haritayı sıfırdan kurar (eskisini siler). Studio plugin'i düzenleme modunda bunu çağırır.
function MapBuilder.build(replaceGeneratedRegion: boolean?)
	-- Eklenti bu sınırlı alanı yeniden oluşturmayı açıkça ister. Çevresindeki kullanıcı
	-- Terrain'i ve Workspace'teki bağımsız modeller/doğma noktaları korunur.
	local half = WATER_SIZE / 2
	local generatedRegion = Region3.new(Vector3.new(-half, -32, -half), Vector3.new(half, 32, half)):ExpandToGrid(4)
	for _, name in { "Plots", "World" } do
		local old = Workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	if replaceGeneratedRegion then
		Workspace.Terrain:FillRegion(generatedRegion, 4, Enum.Material.Air)
	end
	Workspace.Terrain:FillBlock(
		CFrame.new(0, -WATER_DEPTH / 2, 0),
		Vector3.new(WATER_SIZE, WATER_DEPTH, WATER_SIZE),
		Enum.Material.Water
	)

	local terrain = Workspace.Terrain
	-- Çimen yaprakları rüzgârda sallansın (bazı bağlamlarda script ile ayarlanamayabilir; o zaman
	-- Studio'da Terrain → Decoration kutusunu elle işaretle)
	pcall(function()
		(terrain :: any).Decoration = true
	end)
	terrain.WaterColor = Color3.fromRGB(35, 135, 170)
	terrain.WaterTransparency = 0.35
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.15
	terrain.WaterWaveSpeed = 10
	applyLighting()

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder:SetAttribute("MapVersion", MAP_VERSION)
	plotsFolder.Parent = Workspace

	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = Workspace
	buildHub(world)

	local count = Config.MAP_PLOT_COUNT
	for i = 1, count do
		local angle = (i - 1) / count * math.pi * 2
		local direction = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local position = direction * Config.ISLAND_RING_RADIUS
		-- LookVector (-Z) meydana baksın
		local islandCf = CFrame.lookAt(position, Vector3.zero)
		buildIsland(i, islandCf).Parent = plotsFolder
		buildBridge(world, direction)
	end

	ensureSea()
	MapBuilder.validate()
	print(`[Map] {count} ada oluşturuldu (harita sürümü {MAP_VERSION}).`)
end

-- Oyun başlarken: place'e kaydedilmiş harita varsa onu kullan, yoksa kur
function MapBuilder.ensure()
	local existing = Workspace:FindFirstChild("Plots")
	if existing then
		MapBuilder.validate()
		ensureSea() -- Eski kayıtlı haritalarda da deniz tabanı ve güvenlik zemini olsun
		return
	end
	if Config.MAP_AUTO_BUILD then
		MapBuilder.build()
	end
end

return MapBuilder
