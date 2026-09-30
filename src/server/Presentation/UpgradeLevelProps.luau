--!strict
-- Seviyeli genel yükseltmelerin dünyada görünen karşılığı: her seviye yeni bir şey ekler ya da eskisini değiştirir.
--   Yem Kalitesi (feed_quality)        : her açık bölgenin sağ kenarında yem istasyonu (kase, çuval, huni, vitamin yemi, altın)
--   Depo Genişletme (storage_expansion): toplama platformunun yanında depo yığını (kasalar, fıçılar, kulübe, altın kilit)
--   Hızlı Büyüme (fast_growth)         : her açık bölgenin sol kenarında büyüme fenerleri (kristal, halka, iri kristal ve yıldızlar)
-- Model plot içinde "LevelProps" adıyla durur; seviyeler ya da açık bölgeler değişince imza değişir ve yeniden kurulur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))

type PlayerSave = GameTypes.PlayerSave

local UpgradeLevelProps = {}

local GOLD = Color3.fromRGB(255, 200, 60)
local WOOD = Color3.fromRGB(150, 110, 70)
local DARK_WOOD = Color3.fromRGB(100, 70, 45)
local METAL = Color3.fromRGB(170, 175, 180)
local MODEL_NAME = "LevelProps"

-- "<id>_lv1".."<id>_lvN": art arda alınmış seviye sayısı
local function chainLevel(save: PlayerSave, id: string): number
	local level = 0
	while save.purchased[`{id}_lv{level + 1}`] do
		level += 1
	end
	return level
end

local function piece(
	model: Model,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	options: { shape: Enum.PartType?, solid: boolean? }?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	local solid = options ~= nil and options.solid == true
	p.CanCollide, p.CanTouch, p.CanQuery = solid, false, solid
	if options and options.shape then
		p.Shape = options.shape
	end
	p.Parent = model
	return p
end

local SOLID = { solid = true }
local BALL = { shape = Enum.PartType.Ball }

-- cf: zemin yüzeyinde; yem istasyonu X ekseni boyunca uzanır
local function feedStation(model: Model, cf: CFrame, level: number)
	local rim = if level >= 5 then GOLD else DARK_WOOD
	local feedColor = if level >= 5
		then GOLD
		elseif level >= 4 then Color3.fromRGB(110, 210, 150)
		else Color3.fromRGB(225, 195, 110)
	local feedMaterial = if level >= 5 then Enum.Material.Neon else Enum.Material.Grass
	piece(model, "FeedBowl", Vector3.new(3, 0.9, 1.6), cf * CFrame.new(0, 0.45, 0), rim, Enum.Material.Wood, SOLID)
	piece(model, "Feed", Vector3.new(2.6, 0.15, 1.2), cf * CFrame.new(0, 0.95, 0), feedColor, feedMaterial)
	if level >= 2 then
		piece(
			model,
			"GrainSack",
			Vector3.new(1.2, 1.4, 1),
			cf * CFrame.new(2.2, 0.7, 0.3),
			Color3.fromRGB(215, 195, 150),
			Enum.Material.Fabric,
			SOLID
		)
		piece(
			model,
			"GrainTie",
			Vector3.new(0.9, 0.2, 0.8),
			cf * CFrame.new(2.2, 1.45, 0.3),
			DARK_WOOD,
			Enum.Material.Fabric
		)
	end
	if level >= 3 then
		piece(
			model,
			"HopperPost",
			Vector3.new(0.4, 3.2, 0.4),
			cf * CFrame.new(-1.6, 1.6, 0.6),
			METAL,
			Enum.Material.Metal,
			SOLID
		)
		piece(model, "Hopper", Vector3.new(1.6, 1.2, 1.6), cf * CFrame.new(-1.6, 3.4, 0.6), METAL, Enum.Material.Metal)
	end
	if level >= 4 then
		piece(
			model,
			"SecondBowl",
			Vector3.new(2, 0.7, 1.3),
			cf * CFrame.new(-0.2, 0.35, 2.1),
			rim,
			Enum.Material.Wood,
			SOLID
		)
		piece(
			model,
			"SecondFeed",
			Vector3.new(1.7, 0.12, 0.95),
			cf * CFrame.new(-0.2, 0.75, 2.1),
			feedColor,
			feedMaterial
		)
	end
	if level >= 5 then
		piece(
			model,
			"GoldStar",
			Vector3.new(0.9, 0.9, 0.9),
			cf * CFrame.new(-1.6, 4.4, 0.6),
			GOLD,
			Enum.Material.Neon,
			BALL
		)
	end
end

-- Büyüme feneri: direk ve kristal; seviye arttıkça kristal büyür, halka ve yıldızlar eklenir
local function growthBeacon(model: Model, cf: CFrame, level: number)
	local crystalColor = Color3.fromRGB(110, 235, 140)
	piece(
		model,
		"BeaconPost",
		Vector3.new(0.45, 3.4, 0.45),
		cf * CFrame.new(0, 1.7, 0),
		WOOD,
		Enum.Material.Wood,
		SOLID
	)
	local size = if level >= 3 then 1.7 else 1
	local top = cf * CFrame.new(0, 3.4 + size / 2, 0)
	piece(model, "BeaconCrystal", Vector3.new(size, size, size), top, crystalColor, Enum.Material.Neon, BALL)
	if level >= 2 then
		local ring = piece(
			model,
			"BeaconRing",
			Vector3.new(0.15, 2.6, 2.6),
			top * CFrame.Angles(0, 0, math.rad(90)),
			crystalColor,
			Enum.Material.Neon,
			{ shape = Enum.PartType.Cylinder }
		)
		ring.Transparency = 0.5
	end
	if level >= 3 then
		for _, side in { -1, 1 } do
			piece(
				model,
				"BeaconStar",
				Vector3.new(0.5, 0.5, 0.5),
				cf * CFrame.new(side * 1.7, 4.4, 0),
				Color3.fromRGB(240, 255, 200),
				Enum.Material.Neon,
				BALL
			)
		end
	end
end

-- Depo yığını: toplama platformunun yanı
local function storageYard(model: Model, cf: CFrame, level: number)
	local crate = Color3.fromRGB(170, 125, 75)
	for _, offset in { Vector3.new(0, 0.9, 0), Vector3.new(2, 0.9, 0), Vector3.new(1, 2.7, 0) } do
		piece(
			model,
			"Crate",
			Vector3.new(1.8, 1.8, 1.8),
			cf * CFrame.new(offset),
			crate,
			Enum.Material.WoodPlanks,
			SOLID
		)
	end
	if level >= 2 then
		for index = 0, 1 do
			piece(
				model,
				"Barrel",
				Vector3.new(2.6, 2, 2),
				cf * CFrame.new(index * 2.2, 1.3, 3) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(135, 90, 55),
				Enum.Material.WoodPlanks,
				{ shape = Enum.PartType.Cylinder, solid = true }
			)
		end
	end
	if level >= 3 then
		-- Depo kulübesi: gövde ve beşik çatı
		piece(
			model,
			"ShedBody",
			Vector3.new(5.6, 3.6, 4.6),
			cf * CFrame.new(1, 1.8, -5.4),
			Color3.fromRGB(165, 120, 80),
			Enum.Material.WoodPlanks,
			SOLID
		)
		for _, side in { -1, 1 } do
			piece(
				model,
				"ShedRoof",
				Vector3.new(3.6, 0.35, 5.2),
				cf * CFrame.new(1 + side * 1.55, 4.3, -5.4) * CFrame.Angles(0, 0, -side * math.rad(28)),
				Color3.fromRGB(150, 70, 60),
				Enum.Material.Slate
			)
		end
		piece(
			model,
			"ShedDoor",
			Vector3.new(1.6, 2.6, 0.25),
			cf * CFrame.new(1, 1.3, -3.05),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end
	if level >= 4 then
		piece(
			model,
			"GoldLock",
			Vector3.new(0.8, 0.8, 0.3),
			cf * CFrame.new(1, 1.9, -2.95),
			GOLD,
			Enum.Material.Metal,
			BALL
		)
		piece(model, "GoldTrim", Vector3.new(5.8, 0.25, 4.8), cf * CFrame.new(1, 3.65, -5.4), GOLD, Enum.Material.Metal)
	end
end

-- Irk anıtı: ana adada, geliştirilmiş (Irk Sv.1+) her tür için bir kaide. Seviye arttıkça kaide yükselir ve malzemesi
-- değişir: Sv.1-3 bronz top, Sv.4-6 gümüş kupa, Sv.7-9 altın kupa, Sv.10 altın taç ve ışık sütunu.
local MONUMENT_OFFSET = Vector3.new(30, 0, -47)
local PEDESTAL_SPACING = 1.6

local function lineageMonument(model: Model, cf: CFrame, levels: { { id: string, level: number } })
	for index, entry in levels do
		local level = entry.level
		local height = 0.8 + level * 0.3
		local at = cf * CFrame.new((index - 1) * PEDESTAL_SPACING, 0, 0)
		piece(
			model,
			"Pedestal",
			Vector3.new(1.3, height, 1.3),
			at * CFrame.new(0, height / 2, 0),
			Color3.fromRGB(150, 146, 136),
			Enum.Material.Cobblestone,
			SOLID
		)
		local tint, material = Color3.fromRGB(184, 115, 51), Enum.Material.Metal
		if level >= 7 then
			tint = GOLD
		elseif level >= 4 then
			tint = Color3.fromRGB(215, 220, 228)
		end
		if level >= 10 then
			material = Enum.Material.Neon
		end
		local top = at * CFrame.new(0, height, 0)
		if level >= 4 then
			-- Kupa: gövde ve kadeh
			piece(
				model,
				"TrophyStem",
				Vector3.new(0.3, 0.8, 0.3),
				top * CFrame.new(0, 0.4, 0),
				tint,
				Enum.Material.Metal
			)
			piece(model, "TrophyCup", Vector3.new(1, 0.9, 1), top * CFrame.new(0, 1.25, 0), tint, material, BALL)
		else
			piece(model, "Orb", Vector3.new(0.9, 0.9, 0.9), top * CFrame.new(0, 0.6, 0), tint, material, BALL)
		end
		if level >= 10 then
			piece(model, "Crown", Vector3.new(0.9, 0.35, 0.9), top * CFrame.new(0, 2.05, 0), GOLD, Enum.Material.Neon)
			local beam = piece(
				model,
				"Beam",
				Vector3.new(0.35, 6, 0.35),
				top * CFrame.new(0, 5, 0),
				Color3.fromRGB(255, 240, 170),
				Enum.Material.Neon
			)
			beam.Transparency = 0.6
		end
	end
end

function UpgradeLevelProps.apply(plot: Model, save: PlayerSave?)
	local existing = plot:FindFirstChild(MODEL_NAME)
	if not save then
		if existing then
			existing:Destroy()
		end
		return
	end
	local feed = chainLevel(save, "feed_quality")
	local storage = chainLevel(save, "storage_expansion")
	local growth = chainLevel(save, "fast_growth")
	local zones: { { id: string, ground: BasePart } } = {}
	local zonesFolder = plot:FindFirstChild("Zones")
	if zonesFolder then
		for _, zone in zonesFolder:GetChildren() do
			local zoneId = zone:GetAttribute("ZoneId")
			local ground = zone:FindFirstChild("Ground")
			if
				typeof(zoneId) == "string"
				and save.unlockedZones[zoneId]
				and ground
				and ground:IsA("BasePart")
				and ground:GetAttribute("SwimDepth") == nil -- denizdeki bölgeye yem istasyonu konmaz
			then
				table.insert(zones, { id = zoneId, ground = ground })
			end
		end
	end
	table.sort(zones, function(a, b)
		return a.id < b.id
	end)
	local ids: { string } = {}
	for _, zone in zones do
		table.insert(ids, zone.id)
	end
	local monument: { { id: string, level: number } } = {}
	for _, animalId in Config.ANIMAL_ORDER do
		local level = if save.lineage then save.lineage[animalId] else nil
		if typeof(level) == "number" and level > 0 then
			table.insert(monument, { id = animalId, level = math.min(level, 10) })
		end
	end
	local monumentKey = {}
	for _, entry in monument do
		table.insert(monumentKey, `{entry.id}{entry.level}`)
	end
	local signature = `{feed}|{storage}|{growth}|{table.concat(ids, ",")}|{table.concat(monumentKey, ",")}`
	if existing and existing:GetAttribute("Signature") == signature then
		return
	end
	if existing then
		existing:Destroy()
	end
	if feed + storage + growth + #monument == 0 then
		return
	end
	local model = Instance.new("Model")
	model.Name = MODEL_NAME
	model:SetAttribute("Signature", signature)
	for _, zone in zones do
		local ground = zone.ground
		local top = ground.CFrame * CFrame.new(0, ground.Size.Y / 2, 0)
		local halfX, halfZ = ground.Size.X / 2, ground.Size.Z / 2
		if feed > 0 then
			feedStation(model, top * CFrame.new(halfX - 2, 0, -halfZ * 0.55) * CFrame.Angles(0, math.rad(90), 0), feed)
		end
		if growth > 0 then
			growthBeacon(model, top * CFrame.new(-halfX + 1.5, 0, -halfZ * 0.75), growth)
		end
	end
	local collector = plot:FindFirstChild("Collector")
	if storage > 0 and collector and collector:IsA("BasePart") then
		local base = CFrame.new(collector.Position.X, collector.Position.Y - 0.75, collector.Position.Z)
			* collector.CFrame.Rotation
		storageYard(model, base * CFrame.new(-9, 0, 0), storage)
	end
	local plotBase = plot:FindFirstChild("PlotBase")
	if #monument > 0 and plotBase and plotBase:IsA("BasePart") then
		local frame = plotBase.CFrame * CFrame.Angles(0, 0, -math.pi / 2) * CFrame.new(0, plotBase.Size.X / 2, 0)
		lineageMonument(model, frame * CFrame.new(MONUMENT_OFFSET.X, 0, MONUMENT_OFFSET.Z), monument)
	end
	model.Parent = plot
end

return UpgradeLevelProps
