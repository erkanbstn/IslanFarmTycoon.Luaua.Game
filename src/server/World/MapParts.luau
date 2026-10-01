--!strict
-- Harita yapı taşları: parça/disk üretimi, bölge (zemin + çit + tabela), köprü, çim ve lamba yardımcıları.
-- MapBuilder, SatelliteBuilder, IslandBuilder ve HubBuilder bunları ortak kullanır.

-- Studio plugin'i modülleri kopyalayıp taze Config ile çalıştırır; Shared araması SharedRef'te (kopyadaki Shared'ı bulur).
local Shared = require(script.Parent:WaitForChild("SharedRef")) :: typeof(game.ReplicatedStorage.Shared)
local Config = require(Shared:WaitForChild("Config"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))
local WorldDecor = require(script.Parent:WaitForChild("WorldDecor"))
local IslandSpecialization = require(script.Parent:WaitForChild("IslandSpecialization"))
local MapLayout = require(script.Parent:WaitForChild("MapLayout"))

local SURFACE_Y = MapLayout.SURFACE_Y
local WATER_Y = MapLayout.WATER_Y
local WATER_DEPTH = MapLayout.WATER_DEPTH
local FISH_WALKWAY_WIDTH = MapLayout.FISH_WALKWAY_WIDTH
type ZoneLayout = MapLayout.ZoneLayout

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
-- Tabela yazısını kapatmasın diye etkileşim balonu direğin dibinde, göz hizasının altındaki görünmez bir noktaya bağlanır.
local function makePromptAnchor(parent: Instance, worldPosition: Vector3): Part
	local anchor = makePart("SignPromptAnchor", Vector3.new(1, 1, 1), CFrame.new(worldPosition), Color3.new(), parent)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	return anchor
end

local function addTravelPrompt(part: BasePart, objectText: string)
	local anchor = makePromptAnchor(part.Parent or part, Vector3.new(part.Position.X, SURFACE_Y + 2, part.Position.Z))
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TravelPrompt"
	prompt.ActionText = "Adalara Git"
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
end

-- Konuma göre sabit tohum: aynı harita her kurulumda aynı görünsün
local function seedFrom(cf: CFrame): number
	local p = cf.Position
	return math.abs(math.floor(p.X * 7 + p.Z * 13)) + 1
end

local function buildTree(parent: Instance, base: CFrame, variant: number?)
	local seed = seedFrom(base) + (variant or 0) * 7
	if seed % 3 == 0 then
		WorldDecor.pineTree(parent, base, seed)
	else
		WorldDecor.oakTree(parent, base, seed)
	end
end

-- Bölge adı / kilit bilgisi (metni PlotService yazar)
local function addZoneLabel(zoneModel: Model, center: CFrame, zoneConfig: Config.ZoneConfig, farmId: string?)
	local labelAnchor =
		makePart("LabelAnchor", Vector3.new(1, 1, 1), center * CFrame.new(0, 12, 0), Color3.new(), zoneModel)
	labelAnchor.Transparency = 1
	labelAnchor.CanCollide = false
	labelAnchor.CanQuery = false
	WorldUi.tag(labelAnchor, "ZoneBillboard", {
		text = Config.getZoneName(zoneConfig, farmId),
		icon = Config.getZoneIcon(zoneConfig, farmId),
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
	local themeKey = tostring(plotModel:GetAttribute("ThemeIndex") or plotModel:GetAttribute("PlotId"))
	zoneModel.Name = Config.getZoneName(zoneConfig, themeKey)
	zoneModel:SetAttribute("ZoneId", layout.id)
	zoneModel.Parent = plotModel:FindFirstChild("Zones")

	local isWater = layout.water == true
	local surfaceY = if isWater then WATER_Y else SURFACE_Y
	local center = islandCf * CFrame.new(layout.offset.X, surfaceY + layout.size.Y / 2, layout.offset.Z)
	local ground = makePart("Ground", layout.size, center, layout.color, zoneModel)
	ground.Material = if layout.id == "poultry" or layout.id == "stable"
		then Enum.Material.Sand
		elseif layout.id == "pond" then Enum.Material.Glass
		elseif layout.id == "pigpen" then Enum.Material.Ground
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
		addZoneLabel(zoneModel, center, zoneConfig, themeKey)
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

	addZoneLabel(zoneModel, center, zoneConfig, themeKey)
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

-- Ada çimeni: yer yer ton farkı + çim tutamları/çiçekler. Yol, bölge, bina ve eklenti alanlarından kaçınır.
local function addIslandGrass(
	parent: Instance,
	surfaceCf: CFrame,
	islandId: string,
	radius: number,
	zones: { ZoneLayout },
	extraAvoid: { WorldDecor.GrassRect },
	count: number,
	seed: number
)
	local avoid: { WorldDecor.GrassRect } = table.clone(extraAvoid)
	for _, zone in zones do
		if not zone.water then
			table.insert(
				avoid,
				{ x = zone.offset.X, z = zone.offset.Z, hx = zone.size.X / 2 + 2, hz = zone.size.Z / 2 + 2 }
			)
		end
	end
	for _, site in IslandSpecialization.SITES do
		if site.island == islandId then
			table.insert(avoid, {
				x = site.offset.X,
				z = site.offset.Z,
				hx = site.footprint.X / 2 + 4,
				hz = site.footprint.Y / 2 + 5,
			})
		end
	end
	for _, layout in IslandSpecialization.EXTENSIONS do
		if layout.island == islandId then
			table.insert(avoid, {
				x = layout.areaOffset.X,
				z = layout.areaOffset.Z,
				hx = layout.areaSize.X / 2 + 3,
				hz = layout.areaSize.Z / 2 + 3,
			})
			table.insert(avoid, { x = layout.signOffset.X, z = layout.signOffset.Z, hx = 5, hz = 4 })
		end
	end
	WorldDecor.grassPatches(parent, surfaceCf, math.floor(count / 10), 8, radius - 12, seed)
	WorldDecor.grassTufts(parent, surfaceCf, {
		count = count,
		seed = seed + 1,
		minRadius = 6,
		maxRadius = radius - 9,
		avoid = avoid,
	})
end

-- Bir yol boyunca eşit aralıklı, iki yanda dönüşümlü fener direkleri; kollar yolun ortasına uzanır.
-- from/to: ada yerel (x, z); spacing: hedef aralık; offset: yol ortasından uzaklık.
local function lampsAlong(
	parent: Instance,
	at: (number, number) -> CFrame,
	from: Vector2,
	to: Vector2,
	spacing: number,
	offset: number,
	startSide: number
)
	local delta = to - from
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local direction = delta.Unit
	local normal = Vector2.new(-direction.Y, direction.X)
	local count = math.max(1, math.round(length / spacing))
	for index = 1, count do
		local side = if index % 2 == 0 then -startSide else startSide
		local point = from + direction * (length * (index - 0.5) / count) + normal * (offset * side)
		local toPath = -normal * side -- kol yola bakar
		WorldDecor.lamp(parent, at(point.X, point.Y) * CFrame.Angles(0, math.atan2(-toPath.Y, toPath.X), 0))
	end
end

return {
	makePart = makePart,
	makeDisc = makeDisc,
	makePromptAnchor = makePromptAnchor,
	addTravelPrompt = addTravelPrompt,
	seedFrom = seedFrom,
	buildTree = buildTree,
	addZoneLabel = addZoneLabel,
	buildFloatingWalkway = buildFloatingWalkway,
	buildZone = buildZone,
	addBuildSpot = addBuildSpot,
	buildBridgeBetween = buildBridgeBetween,
	addIslandGrass = addIslandGrass,
	lampsAlong = lampsAlong,
}
