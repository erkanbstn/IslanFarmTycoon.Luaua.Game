--!strict
-- Mevcut dört adanın boş kenarlarını uzmanlaştırır; hayvan bölgelerine ve köprü girişlerine dokunmaz.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = script.Parent.Parent:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")
local WorldUi = require(Shared:WaitForChild("WorldUi"))
local WorldDecor = require(script.Parent:WaitForChild("WorldDecor"))

local IslandSpecialization = {}

export type Site = { island: string, offset: Vector3, footprint: Vector2, title: string, icon: string }
IslandSpecialization.SITES = {
	milk_factory = {
		island = "home",
		offset = Vector3.new(43, 0, -21),
		footprint = Vector2.new(20, 14),
		title = "Süt işleme alanı",
		icon = "🥛",
	},
	hatchery = {
		island = "poultry",
		offset = Vector3.new(-25, 0, 5),
		footprint = Vector2.new(14, 16),
		title = "Kuluçka alanı",
		icon = "🥚",
	},
	horse_training = {
		island = "horse",
		offset = Vector3.new(25, 0, 0),
		footprint = Vector2.new(14, 18),
		title = "Antrenman merkezi",
		icon = "🐎",
	},
} :: { [string]: Site }

local WOOD = Color3.fromRGB(131, 93, 58)
local CREAM = Color3.fromRGB(235, 224, 192)
local STRAW = Color3.fromRGB(210, 180, 92)
local ROCK = Color3.fromRGB(121, 121, 113)

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color, p.Material = name, size, cf, color, material
	p.Anchored, p.CanTouch = true, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function sign(parent: Instance, cf: CFrame, title: string, icon: string)
	local board = part(
		parent,
		"SpecialtySign",
		Vector3.new(7, 2, 0.35),
		cf * CFrame.new(0, 3.1, 0),
		WOOD,
		Enum.Material.WoodPlanks
	)
	part(parent, "SignPost", Vector3.new(0.45, 2.1, 0.45), cf * CFrame.new(0, 1.05, 0), WOOD, Enum.Material.Wood)
	WorldUi.sign(board, Enum.NormalId.Front, { text = title, icon = icon })
end

local function surface(
	parent: Instance,
	name: string,
	cf: CFrame,
	size: Vector2,
	color: Color3,
	material: Enum.Material
): Part
	local p = part(parent, name, Vector3.new(size.X, 0.12, size.Y), cf * CFrame.new(0, 0.07, 0), color, material)
	p.CanCollide = false
	p.CastShadow = false
	return p
end

local function productionSite(parent: Instance, cf: CFrame, id: string, site: Site)
	local base = cf * CFrame.new(site.offset)
	local pad =
		surface(parent, "ProductionPad", base, site.footprint, Color3.fromRGB(168, 165, 150), Enum.Material.Concrete)
	pad:SetAttribute("ProductionSiteId", id)
	local front = site.footprint.Y / 2 + 2.5
	-- Tabela kapının tam önünde değil, yükleme alanının kenarında durur.
	sign(parent, base * CFrame.new(site.footprint.X / 2 - 2, 0, -front), site.title, site.icon)
end

local function horse(parent: Instance, cf: CFrame)
	-- Dar oval koşu yolu ağıldan ayrı batı şeridindedir: x=-35..-17, z=-19..19.
	local track = Instance.new("Model")
	track.Name = "TrainingTrack"
	track.Parent = parent
	local count = 24
	for index = 1, count do
		local a, b = (index - 1) / count * math.pi * 2, index / count * math.pi * 2
		local from = (cf * CFrame.new(-26 + math.cos(a) * 6, 0, math.sin(a) * 16)).Position
		local to = (cf * CFrame.new(-26 + math.cos(b) * 6, 0, math.sin(b) * 16)).Position
		local segment = surface(
			track,
			"TrackSand",
			CFrame.lookAt((from + to) / 2, to),
			Vector2.new(4, (to - from).Magnitude + 0.5),
			Color3.fromRGB(180, 151, 107),
			Enum.Material.Sand
		)
		segment:SetAttribute("OutsideAnimalZone", true)
	end
	for index, z in { -8, 7 } do
		local base = cf * CFrame.new(-26, 0, z)
		for _, x in { -2.8, 2.8 } do
			part(
				track,
				"JumpStandard",
				Vector3.new(0.5, 3.4, 0.6),
				base * CFrame.new(x, 1.7, 0),
				CREAM,
				Enum.Material.Wood
			)
		end
		for _, height in { 1.3, 2.3 } do
			local rail = part(
				track,
				"TrainingRail",
				Vector3.new(5.6, 0.25, 0.25),
				base * CFrame.new(0, height, 0),
				if index == 1 then Color3.fromRGB(190, 70, 55) else Color3.fromRGB(65, 100, 157),
				Enum.Material.Wood
			)
			rail.CanCollide = false
		end
	end
	sign(parent, cf * CFrame.new(-23, 0, -24), "Koşu ve engel parkuru", "🐎")
	WorldDecor.path(parent, (cf * CFrame.new(-3, 0, -24)).Position, (cf * CFrame.new(-19, 0, -24)).Position, 3)
	WorldDecor.path(parent, (cf * CFrame.new(3, 0, -17)).Position, (cf * CFrame.new(25, 0, -13)).Position, 3)
	WorldDecor.barrel(parent, cf * CFrame.new(30, 0, 17))
end

local function poultry(parent: Instance, cf: CFrame)
	-- Açık folluk bahçesi doğu tarafında; satın alınan kuluçkahane batıda kalır.
	local garden = Instance.new("Model")
	garden.Name = "NestingGarden"
	garden.Parent = parent
	surface(garden, "StrawYard", cf * CFrame.new(25, 0, 3), Vector2.new(14, 25), STRAW, Enum.Material.Sand)
	for index, z in { -5, 2, 9 } do
		local base = cf * CFrame.new(28, 0, z)
		part(
			garden,
			"NestFloor",
			Vector3.new(4.5, 0.35, 4),
			base * CFrame.new(0, 0.55, 0),
			WOOD,
			Enum.Material.WoodPlanks
		)
		part(
			garden,
			"NestBack",
			Vector3.new(4.5, 2.4, 0.3),
			base * CFrame.new(0, 1.8, 1.8),
			WOOD,
			Enum.Material.WoodPlanks
		)
		for _, side in { -2.1, 2.1 } do
			part(
				garden,
				"NestSide",
				Vector3.new(0.3, 2.4, 4),
				base * CFrame.new(side, 1.8, 0),
				CREAM,
				Enum.Material.WoodPlanks
			)
		end
		part(
			garden,
			"NestRoof",
			Vector3.new(5, 0.35, 4.4),
			base * CFrame.new(0, 3.15, 0) * CFrame.Angles(0.06, 0, 0),
			Color3.fromRGB(161, 72, 49),
			Enum.Material.WoodPlanks
		)
		local straw = part(
			garden,
			"NestStraw",
			Vector3.new(3.7, 0.25, 3.3),
			base * CFrame.new(0, 0.85, 0),
			STRAW,
			Enum.Material.Grass
		)
		straw.CanCollide = false
		WorldDecor.flowerPatch(parent, cf * CFrame.new(21, 0, 18 + index), index * 13)
	end
	sign(parent, cf * CFrame.new(25, 0, -14), "Folluk bahçesi", "🐔")
	WorldDecor.path(parent, (cf * CFrame.new(3, 0, -20)).Position, (cf * CFrame.new(23, 0, -19)).Position, 3)
	WorldDecor.path(parent, (cf * CFrame.new(-3, 0, -17)).Position, (cf * CFrame.new(-25, 0, -7)).Position, 3)
	WorldDecor.crate(parent, cf * CFrame.new(-20, 0, 21), 2)
end

local function goat(parent: Instance, cf: CFrame)
	local terraces = Instance.new("Model")
	terraces.Name = "HillsideTerraces"
	terraces.Parent = parent
	for index = 1, 3 do
		local height = index * 1.2
		local width = 15 - index
		local z = -12 + (index - 1) * 10
		local base = cf * CFrame.new(-26, 0, z)
		part(
			terraces,
			"RetainingRock",
			Vector3.new(width, height, 8),
			base * CFrame.new(0, height / 2, 0),
			ROCK,
			Enum.Material.Rock
		)
		part(
			terraces,
			"TerraceGrass",
			Vector3.new(width - 0.3, 0.15, 7.7),
			base * CFrame.new(0, height + 0.075, 0),
			Color3.fromRGB(115, 138, 79),
			Enum.Material.Grass
		)
		-- Küçük yükseltiler her seviyeye yürüyerek çıkılabilsin diye basamaklara ayrılır.
		for step = 1, 3 do
			local stairHeight = math.max(0.4, height - 1.2 + step * 0.4)
			part(
				terraces,
				"TerraceStep",
				Vector3.new(4, stairHeight, 0.9),
				base * CFrame.new(2.5, stairHeight / 2, -6.3 + step * 0.8),
				ROCK,
				Enum.Material.Slate
			)
		end
		WorldDecor.bush(terraces, base * CFrame.new(-3, height + 0.15, 1.5), index * 17)
	end
	sign(parent, cf * CFrame.new(-24, 0, -22), "Kayalık otlak terasları", "🐐")
	WorldDecor.path(parent, (cf * CFrame.new(-3, 0, -25)).Position, (cf * CFrame.new(-23, 0, -23)).Position, 3)
	-- Peynirhanenin önündeki yükleme alanı, ahırın arka şeridinden ayrıdır.
	surface(
		parent,
		"DairyApron",
		cf * CFrame.new(0, 0, 26),
		Vector2.new(15, 13),
		Color3.fromRGB(177, 169, 146),
		Enum.Material.Cobblestone
	)
	WorldDecor.path(parent, (cf * CFrame.new(22, 0, -17)).Position, (cf * CFrame.new(23, 0, 22)).Position, 3)
	WorldDecor.path(parent, (cf * CFrame.new(23, 0, 22)).Position, (cf * CFrame.new(9, 0, 25)).Position, 3)
	WorldDecor.barrel(parent, cf * CFrame.new(10, 0, 28))
	WorldDecor.barrel(parent, cf * CFrame.new(13, 0, 26))
end

local function home(parent: Instance, cf: CFrame)
	WorldDecor.path(parent, (cf * CFrame.new(20, 0, -17)).Position, (cf * CFrame.new(31, 0, -30)).Position, 4)
	WorldDecor.path(parent, (cf * CFrame.new(31, 0, -30)).Position, (cf * CFrame.new(43, 0, -30)).Position, 4)
	for index = 1, 4 do
		local stripe = surface(
			parent,
			"LoadingBayStripe",
			cf * CFrame.new(35 + index * 3, 0.2, -32),
			Vector2.new(0.3, 4),
			STRAW,
			Enum.Material.SmoothPlastic
		)
		stripe.CanQuery = false
	end
	WorldDecor.crate(parent, cf * CFrame.new(56, 0, -24), 2.2)
	WorldDecor.crate(parent, cf * CFrame.new(56, 0, -20), 2.2)
end

function IslandSpecialization.build(parent: Instance, islandId: string, surfaceCf: CFrame)
	local model = Instance.new("Model")
	model.Name = "Specialization"
	model:SetAttribute("FarmIslandId", islandId)
	model.Parent = parent
	for id, site in IslandSpecialization.SITES do
		if site.island == islandId then
			productionSite(model, surfaceCf, id, site)
		end
	end
	if islandId == "home" then
		home(model, surfaceCf)
	elseif islandId == "horse" then
		horse(model, surfaceCf)
	elseif islandId == "poultry" then
		poultry(model, surfaceCf)
	elseif islandId == "goat" then
		goat(model, surfaceCf)
	end
end

return IslandSpecialization
