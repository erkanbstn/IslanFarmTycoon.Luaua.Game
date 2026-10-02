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
local ModelAssets = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("ModelAssets"))

type PlayerSave = GameTypes.PlayerSave

local UpgradeLevelProps = {}

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

-- Hazır model (assets/<klasör>/<ad>, pivot = zemin çerçevesi) kopyasını `cf` noktasına koyar; yoksa bir kez uyarır ve bir şey çizmez
local missingWarned: { [string]: boolean } = {}
local function placeAsset(model: Model, folder: string, name: string, cf: CFrame)
	if not ModelAssets.place(model, folder, name, cf) and not missingWarned[`{folder}/{name}`] then
		missingWarned[`{folder}/{name}`] = true
		warn(`[UpgradeLevelProps] assets/{folder}/{name}.rbxmx bulunamadı`)
	end
end

-- cf: zemin yüzeyinde; yem istasyonu X ekseni boyunca uzanır
local function feedStation(model: Model, cf: CFrame, level: number)
	placeAsset(model, "LevelProps", `FeedStation_Lv{level}`, cf)
end

-- Büyüme feneri: direk ve kristal; seviye arttıkça kristal büyür, halka ve yıldızlar eklenir
local function growthBeacon(model: Model, cf: CFrame, level: number)
	placeAsset(model, "LevelProps", `GrowthBeacon_Lv{level}`, cf)
end

-- Depo yığını: toplama platformunun yanı
local function storageYard(model: Model, cf: CFrame, level: number)
	placeAsset(model, "LevelProps", `StorageYard_Lv{level}`, cf)
end

-- Irk anıtı: ana adada, geliştirilmiş (Irk Sv.1+) her tür için bir kaide. Seviye arttıkça kaide yükselir ve malzemesi
-- değişir: Sv.1-3 bronz top, Sv.4-6 gümüş kupa, Sv.7-9 altın kupa, Sv.10 altın taç ve ışık sütunu.
local MONUMENT_OFFSET = Vector3.new(30, 0, -47)
local PEDESTAL_SPACING = 1.6

local function lineageMonument(model: Model, cf: CFrame, levels: { { id: string, level: number } })
	for index, entry in levels do
		-- 8 kaideden sonra ikinci sıra (ada kenarına taşmasın; 24 hayvan türünde tek sıra x>56 olur)
		local at = cf * CFrame.new(((index - 1) % 8) * PEDESTAL_SPACING, 0, -math.floor((index - 1) / 8) * 2.6)
		placeAsset(model, "Lineage", `LineageMonument_Lv{entry.level}`, at)
	end
end

-- Yardımcılar (pet): toplama platformunun yanında durur. Para yardımcısı köpek, ürün yardımcısı kedi.
-- Yardımcı türleri: her adanın kendi hayvanı vardır (ana ada köpek/kedi); görünüm assets/Pets modellerindedir.
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
	-- Hazır gövde (assets/Pets/Pet_<tür>_<cash|goods>, pivot = zemin, önü -Z, görünmez Root); PetAnimator (istemci) bu modeli yürütür.
	-- Öznitelik ve etiket burada eklenir.
	local species = petSpecies(island, kind)
	local model = ModelAssets.clone("Pets", `Pet_{species}_{kind}`)
	local root = if model then model:FindFirstChild("Root") else nil
	if not model or not root or not root:IsA("BasePart") then
		warn(
			`[UpgradeLevelProps] assets/Pets/Pet_{species}_{kind}.rbxmx bulunamadı ya da Root parçası yok; yardımcı çizilmedi`
		)
		if model then
			model:Destroy()
		end
		return
	end
	model:PivotTo(cf)
	model.Name = `Pet_{kind}_{island}`
	model:SetAttribute("PetKind", kind)
	model:SetAttribute("PetIsland", island)
	model:SetAttribute("PetHome", cf)
	model.PrimaryPart = root
	CollectionService:AddTag(model, "PetFigure")
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
			growthBeacon(model, top * CFrame.new(halfX - 5, 0, -halfZ * 0.75), growth)
		end
	end
	local collector = plot:FindFirstChild("Collector")
	if storage > 0 and collector and collector:IsA("BasePart") then
		local base = CFrame.new(collector.Position.X, collector.Position.Y - 0.75, collector.Position.Z)
			* collector.CFrame.Rotation
		-- Toplayıcı 180° döner: yerel -X dünyada kuleye (+X) düşüyordu; yığın kulenin ve yardımcıların dışında, ada kuzeyinde durur.
		storageYard(model, base * CFrame.new(-1, 0, 9) * CFrame.Angles(0, math.pi, 0), storage)
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
				-- Yardımcılar platformun güney-doğu şeridinde (dünya z -33) yan yana durur: para yığını (batı), Depo istifi (kuzey),
				-- yol ve alım kaideleri bu şeride girmez. Deniz yardımcısı ev yardımcılarının da yanında, daha doğuda durur.
				local lx = -6 - (if slot.island == "sea" then 7 else 0) - (if slot.kind == "cash" then 0 else 3.5)
				home = base
					* CFrame.new(lx, 0, -7)
					* CFrame.Angles(0, math.rad(if slot.kind == "cash" then -150 else -30), 0)
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
