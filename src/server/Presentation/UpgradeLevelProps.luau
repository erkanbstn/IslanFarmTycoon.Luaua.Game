--!strict
-- Seviyeli genel yükseltmelerin dünyada görünen karşılığı: her seviye yeni bir şey ekler ya da eskisini değiştirir.
--   Yem Kalitesi (feed_quality)        : her açık bölgenin sağ kenarında yem istasyonu (kase, çuval, huni, vitamin yemi, altın)
--   Depo Genişletme (storage_expansion): toplama platformunun yanında depo yığını (kasalar, fıçılar, kulübe, altın kilit)
--   Hızlı Büyüme (fast_growth)         : her açık bölgenin sol kenarında büyüme fenerleri (kristal, halka, iri kristal ve yıldızlar)
-- Model plot içinde "LevelProps" adıyla durur; seviyeler ya da açık bölgeler değişince imza değişir ve yeniden kurulur.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local ProductionLogic = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProductionLogic"))
local MapLayout = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("MapLayout"))

type PlayerSave = GameTypes.PlayerSave

local UpgradeLevelProps = {}

local GOLD = Color3.fromRGB(255, 200, 60)
local WOOD = Color3.fromRGB(150, 110, 70)
local DARK_WOOD = Color3.fromRGB(100, 70, 45)
local METAL = Color3.fromRGB(170, 175, 180)
local MODEL_NAME = "LevelProps"
local SATELLITE_RADIUS = MapLayout.SATELLITE_RADIUS

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

-- Yardımcılar (pet): toplama platformunun yanında durur. Para yardımcısı köpek, ürün yardımcısı kedi.
-- Yardımcı türleri: her adanın kendi hayvanı vardır (ana ada köpek/kedi). Tür, renk ve kulak/kuyruk biçimiyle ayrılır;
-- yaka rengi görevi gösterir (altın = para, mavi = ürün).
type PetStyle = {
	fur: Color3,
	light: Color3,
	earColor: Color3?,
	earHeight: number,
	earWidth: number,
	earX: number,
	tailLength: number,
	tailWidth: number,
	mask: Color3?,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local PET_STYLES: { [string]: PetStyle } = {
	dog = {
		fur = rgb(196, 140, 84),
		light = rgb(245, 225, 190),
		earHeight = 0.7,
		earWidth = 0.35,
		earX = 0.5,
		tailLength = 1.4,
		tailWidth = 0.3,
	},
	cat = {
		fur = rgb(120, 120, 130),
		light = rgb(235, 235, 240),
		earHeight = 0.9,
		earWidth = 0.35,
		earX = 0.5,
		tailLength = 1.6,
		tailWidth = 0.25,
	},
	fox = {
		fur = rgb(224, 120, 40),
		light = rgb(250, 235, 215),
		earColor = rgb(60, 40, 30),
		earHeight = 1.0,
		earWidth = 0.4,
		earX = 0.45,
		tailLength = 1.9,
		tailWidth = 0.75,
	},
	bunny = {
		fur = rgb(236, 230, 224),
		light = rgb(255, 255, 255),
		earColor = rgb(250, 200, 205),
		earHeight = 1.6,
		earWidth = 0.3,
		earX = 0.35,
		tailLength = 0.6,
		tailWidth = 0.6,
	},
	raccoon = {
		fur = rgb(130, 130, 138),
		light = rgb(222, 222, 228),
		mask = rgb(40, 40, 48),
		earHeight = 0.6,
		earWidth = 0.45,
		earX = 0.55,
		tailLength = 1.7,
		tailWidth = 0.55,
	},
	panda = {
		fur = rgb(245, 245, 245),
		light = rgb(245, 245, 245),
		earColor = rgb(35, 35, 40),
		mask = rgb(35, 35, 40),
		earHeight = 0.5,
		earWidth = 0.5,
		earX = 0.6,
		tailLength = 0.5,
		tailWidth = 0.5,
	},
	frog = {
		fur = rgb(90, 170, 80),
		light = rgb(215, 238, 165),
		earColor = rgb(120, 195, 95),
		earHeight = 0.35,
		earWidth = 0.5,
		earX = 0.42,
		tailLength = 0.3,
		tailWidth = 0.3,
	},
	lamb = {
		fur = rgb(246, 242, 228),
		light = rgb(70, 62, 58),
		earColor = rgb(70, 62, 58),
		earHeight = 0.45,
		earWidth = 0.55,
		earX = 0.75,
		tailLength = 0.6,
		tailWidth = 0.55,
	},
	hedgehog = {
		fur = rgb(120, 92, 72),
		light = rgb(238, 208, 172),
		earColor = rgb(92, 70, 56),
		earHeight = 0.35,
		earWidth = 0.4,
		earX = 0.5,
		tailLength = 0.4,
		tailWidth = 0.4,
	},
}

-- ada -> tür (ana adada para yardımcısı köpek, ürün yardımcısı kedi)
local PET_SPECIES: { [string]: string } = {
	poultry = "fox",
	horse = "bunny",
	goat = "raccoon",
	sheep = "lamb",
	pig = "hedgehog",
	-- Hayvan türü tablosundaki adalar (Config/Species.luau); yardımcı türleri çiftlikler arası paylaşılır
	rabbit = "bunny",
	bee = "hedgehog",
	camel = "fox",
	peacock = "frog",
	quail = "lamb",
	pigeon = "raccoon",
	snail = "frog",
	llama = "lamb",
	deer = "fox",
	falcon = "raccoon",
	silkworm = "panda",
	parrot = "bunny",
	tortoise = "hedgehog",
}

local function petSpecies(island: string, kind: string): string
	if island == "home" then
		return if kind == "cash" then "dog" else "cat"
	elseif island == "sea" then
		return "frog"
	end
	return PET_SPECIES[island] or "dog"
end

local function petFigure(parent: Model, cf: CFrame, kind: string, island: string)
	-- Kendi Model'i ve görünmez kök parçasıyla durur; PetAnimator (istemci) bu modeli yürütür. Pivot: zemin, önü -Z.
	local species = petSpecies(island, kind)
	local style = PET_STYLES[species]
	local model = Instance.new("Model")
	model.Name = `Pet_{kind}_{island}`
	model:SetAttribute("PetKind", kind)
	model:SetAttribute("PetIsland", island)
	model:SetAttribute("PetHome", cf)
	local root = piece(model, "Root", Vector3.one * 0.2, cf, Color3.new(), Enum.Material.SmoothPlastic)
	root.Transparency = 1
	model.PrimaryPart = root
	CollectionService:AddTag(model, "PetFigure")
	local fur, light = style.fur, style.light
	local earColor = style.earColor or fur
	local cloth = Enum.Material.Fabric
	piece(model, "Body", Vector3.new(1.6, 1.1, 2.4), cf * CFrame.new(0, 1.35, 0), fur, cloth)
	piece(model, "Head", Vector3.new(1.3, 1.2, 1.3), cf * CFrame.new(0, 2.15, -1.5), fur, cloth)
	piece(model, "Muzzle", Vector3.new(0.7, 0.5, 0.6), cf * CFrame.new(0, 1.95, -2.2), light, cloth)
	if style.mask then
		piece(model, "Mask", Vector3.new(1.34, 0.36, 0.3), cf * CFrame.new(0, 2.3, -2.02), style.mask, cloth)
	end
	for _, side in { -1, 1 } do
		piece(
			model,
			"Ear",
			Vector3.new(style.earWidth, style.earHeight, 0.35),
			cf * CFrame.new(side * style.earX, 2.75 + style.earHeight / 2, -1.5),
			earColor,
			cloth
		)
		piece(
			model,
			"Eye",
			Vector3.new(0.2, 0.2, 0.2),
			cf * CFrame.new(side * 0.35, 2.3, -2.16),
			if style.mask then rgb(245, 245, 245) else rgb(30, 30, 35),
			Enum.Material.SmoothPlastic,
			BALL
		)
		for _, z in { -0.8, 0.8 } do
			piece(
				model,
				"Leg",
				Vector3.new(0.4, 0.8, 0.4),
				cf * CFrame.new(side * 0.55, 0.4, z),
				if species == "panda" then style.mask :: Color3 else fur,
				cloth
			)
		end
	end
	piece(
		model,
		"Tail",
		Vector3.new(style.tailWidth, style.tailWidth, style.tailLength),
		cf * CFrame.new(0, 1.9, 1.2 + style.tailLength / 2) * CFrame.Angles(math.rad(-35), 0, 0),
		fur,
		cloth
	)
	piece(
		model,
		"Collar",
		Vector3.new(1.4, 0.25, 1.4),
		cf * CFrame.new(0, 1.7, -1.05),
		if kind == "cash" then GOLD else rgb(90, 140, 255),
		Enum.Material.Neon
	)
	model.Parent = parent
end

local function applyProps(plot: Model, save: PlayerSave?)
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
		-- Toplayıcı 180° döner: yerel -X dünyada kuleye (+X) düşüyordu; yığın kulenin ve yardımcıların dışında, ada kuzeyinde durur.
		storageYard(model, base * CFrame.new(0, 0, 8), storage)
	end
	local plotBase = plot:FindFirstChild("PlotBase")
	if #monument > 0 and plotBase and plotBase:IsA("BasePart") then
		local frame = plotBase.CFrame * CFrame.Angles(0, 0, -math.pi / 2) * CFrame.new(0, plotBase.Size.X / 2, 0)
		lineageMonument(model, frame * CFrame.new(MONUMENT_OFFSET.X, 0, MONUMENT_OFFSET.Z), monument)
	end
	model.Parent = plot
end

-- Yardımcılar ayrı modelde durur: seviye/bölge değişip LevelProps yeniden kurulsa da yürüyen yardımcı kaybolmaz.
local PETS_NAME = "PetYard"

local function applyPets(plot: Model, save: PlayerSave?)
	local existing = plot:FindFirstChild(PETS_NAME)
	local slots: { ProductionLogic.PetSlot } = if save
		then ProductionLogic.petSlots(save, Config.PRODUCTION_ORDER, FarmMath, Config)
		else {}
	local keys: { string } = {}
	for _, slot in slots do
		table.insert(keys, `{slot.kind}:{slot.island}`)
	end
	local signature = table.concat(keys, ",")
	if existing and existing:GetAttribute("Signature") == signature then
		return
	end
	if existing then
		existing:Destroy()
	end
	if #slots == 0 then
		return
	end
	local model = Instance.new("Model")
	model.Name = PETS_NAME
	model:SetAttribute("Signature", signature)
	local collector = plot:FindFirstChild("Collector")
	local islands = plot:FindFirstChild("Islands")
	for _, slot in slots do
		local home: CFrame? = nil
		if slot.island == "home" or slot.island == "sea" then
			if collector and collector:IsA("BasePart") then
				local base = CFrame.new(collector.Position.X, collector.Position.Y - 0.75, collector.Position.Z)
					* collector.CFrame.Rotation
				-- Deniz yardımcısı toplama platformunun öbür yanında durur (süt/yumurta yardımcılarıyla karışmasın)
				local side = if slot.island == "sea" then -6 else 6
				home = if slot.kind == "cash"
					then base * CFrame.new(side, 0, 3) * CFrame.Angles(0, math.rad(-150), 0)
					else base * CFrame.new(side, 0, -3) * CFrame.Angles(0, math.rad(-30), 0)
			end
		elseif islands then
			for _, island in islands:GetChildren() do
				local frame = island:GetAttribute("IslandFrame")
				if island:GetAttribute("FarmIslandId") == slot.island and typeof(frame) == "CFrame" then
					-- Köprü girişindeki yolun yanı; para yardımcısı bir yanda, ürün yardımcısı öbür yanda
					home = frame * CFrame.new(if slot.kind == "cash" then 6 else -6, 0, -(SATELLITE_RADIUS - 12))
					break
				end
			end
		end
		if home then
			petFigure(model, home, slot.kind, slot.island)
		end
	end
	model.Parent = plot
end

function UpgradeLevelProps.apply(plot: Model, save: PlayerSave?)
	applyProps(plot, save)
	applyPets(plot, save)
end

return UpgradeLevelProps
