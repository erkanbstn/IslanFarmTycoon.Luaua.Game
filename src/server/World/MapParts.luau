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
local ModelAssets = require(script.Parent:WaitForChild("ModelAssets"))

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

local zoneBaseWarned: { [string]: boolean } = {}
local function warnZoneBase(name: string)
	if not zoneBaseWarned[name] then
		zoneBaseWarned[name] = true
		warn(`[MapParts] assets/ZoneBases/{name}.rbxmx bulunamadı; çizilmedi`)
	end
end

-- Balık kafesinin çevresindeki kazıklı yürüme yolu (iskeleyle aynı yükseklikte).
-- Tahtalar hazır modelden (ZoneBases/FishWalkway_Module: tek "Deck" parçası) alınır; boyu kafesin ölçüsüne göre ayarlanır.
local function buildFloatingWalkway(zoneModel: Model, center: CFrame, size: Vector3)
	local walkway = Instance.new("Model")
	walkway.Name = "Walkway"
	walkway.Parent = zoneModel
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
		local template = ModelAssets.clone("ZoneBases", "FishWalkway_Module")
		local deck = if template then template:FindFirstChild("Deck") else nil
		if not (template and deck and deck:IsA("BasePart")) then
			warnZoneBase("FishWalkway_Module")
			break
		end
		deck.Size = plank[1]
		deck.CFrame = frame * CFrame.new(plank[2])
		deck:SetAttribute("WalkSurfaceY", SURFACE_Y)
		deck.Parent = walkway
		template:Destroy()
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
	ground.Material = layout.material or Enum.Material.Grass
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

	-- Direkli çit; ön tarafta (-Z, doğma noktası yönü) giriş boşluğu.
	-- Hazır modüller: ZoneBases/ZoneFence_Segment_4 (başlangıç direği + iki ray, +X'te 4 stud) uç uca dizilir, ray boyu
	-- bölüme göre ayarlanır; bitiş direği ZoneFence_Corner'dır.
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	fence.Parent = zoneModel
	local hx, hz = layout.size.X / 2, layout.size.Z / 2
	local gap = 6
	local top = layout.size.Y / 2

	-- Köşe direkleri iki segmentte de oluşmasın: üst üste binen parçalar yürürken titrer (z-fighting)
	local placedPosts: { [string]: boolean } = {}
	local function postKey(p: Vector3): string
		return `{math.round(p.X * 10)},{math.round(p.Z * 10)}`
	end
	local function fenceSegment(from: Vector3, to: Vector3)
		local length = (to - from).Magnitude
		local direction = (to - from).Unit
		local count = math.max(1, math.round(length / 4))
		local step = length / count
		local rotation = CFrame.fromMatrix(Vector3.zero, direction, Vector3.yAxis)
		for i = 0, count - 1 do
			local startPoint = from + direction * (step * i)
			local cf = center * CFrame.new(startPoint.X, top, startPoint.Z) * rotation
			local segment = ModelAssets.clone("ZoneBases", "ZoneFence_Segment_4")
			if not segment then
				warnZoneBase("ZoneFence_Segment_4")
				return
			end
			local pivot = segment:GetPivot()
			for _, child in segment:GetChildren() do
				if not child:IsA("BasePart") then
					continue
				end
				if child.Name == "Post" then
					-- Bu noktada direk zaten varsa (önceki segmentin bitişi) tekrar konmaz
					if placedPosts[postKey(startPoint)] then
						child:Destroy()
					else
						placedPosts[postKey(startPoint)] = true
					end
				else
					-- Ray: modeldeki 4 stud'luk boy bölümün gerçek boyuna uzar (başlangıç direğinden itibaren)
					local rel = pivot:ToObjectSpace(child.CFrame)
					child.Size = Vector3.new(step, child.Size.Y, child.Size.Z)
					child.CFrame = pivot * CFrame.new(step / 2, rel.Y, rel.Z)
				end
			end
			segment:PivotTo(cf)
			for _, child in segment:GetChildren() do
				child.Parent = fence
			end
			segment:Destroy()
		end
		-- Bitiş direği
		if not placedPosts[postKey(to)] then
			placedPosts[postKey(to)] = true
			local corner = ModelAssets.clone("ZoneBases", "ZoneFence_Corner")
			if corner then
				corner:PivotTo(center * CFrame.new(to.X, top + 1.7, to.Z) * rotation) -- PrimaryPart (Post) merkezi pivottur
				for _, child in corner:GetChildren() do
					child.Parent = fence
				end
				corner:Destroy()
			else
				warnZoneBase("ZoneFence_Corner")
			end
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

-- İki nokta arasında tahta köprü: hazır modüllerden (assets/BridgeModels: 8 ve 2 stud'luk) uç uca dizilir.
-- Güverte ince taş yolların üstünde kalır; artan uzunluk ortalanır (en çok 1 stud taşar).
local bridgeWarned = false
local function buildBridgeBetween(parent: Instance, from: Vector3, to: Vector3)
	local y = SURFACE_Y + 0.25 -- modül pivotu güverte üstündedir; kıyıda taş yüzey güverteyi kesmez
	local a = Vector3.new(from.X, y, from.Z)
	local b = Vector3.new(to.X, y, to.Z)
	local length = (b - a).Magnitude
	local dir = (b - a).Unit
	local long = math.floor(length / 8)
	local short = math.ceil((length - long * 8) / 2 - 0.01)
	local cursor = (length - (long * 8 + short * 2)) / 2 -- negatifse iki uçtan eşit taşar
	local function lay(name: string, size: number)
		local center = a + dir * (cursor + size / 2)
		if
			not ModelAssets.place(parent, "BridgeModels", name, CFrame.lookAt(center, center + dir))
			and not bridgeWarned
		then
			bridgeWarned = true
			warn(`[MapParts] assets/BridgeModels/{name}.rbxmx bulunamadı; köprü çizilmedi`)
		end
		cursor += size
	end
	for _ = 1, long do
		lay("BridgeModule_8", 8)
	end
	for _ = 1, short do
		lay("BridgeModule_2", 2)
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
	-- Kaya, kütük, mantar, kabak, saz, palmiye... (assets/CommonDecor): yaklaşık her 7 çim tutamı için 1 süs
	WorldDecor.scatterProps(parent, surfaceCf, {
		count = math.floor(count / 7),
		seed = seed + 2,
		minRadius = 10,
		maxRadius = radius - 6,
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
