--!strict
-- Hayvanları bölgelerin zemininde ızgara halinde gösterir.
-- Kendi modelini kullanmak için: ServerStorage.Assets.Animals içine "cow", "horse", "chicken"
-- adında Model koy (Toolbox'tan da olur). Yoksa kodla basit bloklardan hayvan yapılır.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerStorage = game:GetService("ServerStorage")
local AssetSanitizer = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("AssetSanitizer"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))

local ExtensionAreas = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ExtensionAreas"))

type PlayerSave = GameTypes.PlayerSave

local AnimalVisualService = {}

local STAGE_SCALE: { [string]: number } = {
	calf = 0.55,
	young = 0.8,
	adult = 1,
}

local function block(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Anchored = true
	p.CanTouch = false
	p.CanCollide = false
	p.CanQuery = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Tüm ölçüler s (evre ölçeği) ile çarpılır. Model -Z yönüne (başı) bakar.
local function buildCow(model: Model, s: number)
	local white = Color3.fromRGB(245, 245, 240)
	local black = Color3.fromRGB(35, 35, 35)
	local pink = Color3.fromRGB(240, 170, 170)
	local legH = 2 * s
	local body = block(model, "Body", Vector3.new(3.2, 2.4, 5) * s, CFrame.new(0, legH + 1.2 * s, 0), white)
	block(model, "Spot1", Vector3.new(3.3, 1.2, 1.6) * s, body.CFrame * CFrame.new(0, 0.5 * s, 0.8 * s), black)
	block(model, "Spot2", Vector3.new(1.4, 1.3, 1.2) * s, body.CFrame * CFrame.new(1.0 * s, 0.2 * s, -1.4 * s), black)
	local head =
		block(model, "Head", Vector3.new(2, 1.8, 1.8) * s, body.CFrame * CFrame.new(0, 0.8 * s, -3.1 * s), white)
	block(model, "Snout", Vector3.new(1.8, 0.9, 0.6) * s, head.CFrame * CFrame.new(0, -0.45 * s, -1.1 * s), pink)
	for _, x in { -1, 1 } do
		block(
			model,
			"Horn",
			Vector3.new(0.3, 0.7, 0.3) * s,
			head.CFrame * CFrame.new(x * 0.7 * s, 1.2 * s, 0.2 * s),
			Color3.fromRGB(230, 220, 190)
		)
		block(
			model,
			"Eye",
			Vector3.new(0.3, 0.3, 0.1) * s,
			head.CFrame * CFrame.new(x * 0.5 * s, 0.3 * s, -0.91 * s),
			black
		)
		for _, z in { -1, 1 } do
			block(
				model,
				"Leg",
				Vector3.new(0.8 * s, legH, 0.8 * s),
				CFrame.new(x * 1.1 * s, legH / 2, z * 1.8 * s),
				white
			)
		end
	end
	block(model, "Udder", Vector3.new(1, 0.5, 1) * s, body.CFrame * CFrame.new(0, -1.35 * s, 1.2 * s), pink)
	block(model, "Tail", Vector3.new(0.25, 1.8, 0.25) * s, body.CFrame * CFrame.new(0, -0.3 * s, 2.6 * s), black)
	model.PrimaryPart = body
end

local function buildHorse(model: Model, s: number)
	local brown = Color3.fromRGB(125, 80, 45)
	local dark = Color3.fromRGB(45, 30, 20)
	local legH = 3 * s
	local body = block(model, "Body", Vector3.new(2.4, 2.4, 5.2) * s, CFrame.new(0, legH + 1.2 * s, 0), brown)
	local neck = block(
		model,
		"Neck",
		Vector3.new(1.4, 2.8, 1.4) * s,
		body.CFrame * CFrame.new(0, 1.8 * s, -2.4 * s) * CFrame.Angles(math.rad(-25), 0, 0),
		brown
	)
	local head =
		block(model, "Head", Vector3.new(1.3, 1.3, 2.6) * s, neck.CFrame * CFrame.new(0, 1.4 * s, -0.8 * s), brown)
	block(model, "Mane", Vector3.new(0.4, 2.8, 1.5) * s, neck.CFrame * CFrame.new(0, 0.2 * s, 0.5 * s), dark)
	for _, x in { -1, 1 } do
		block(
			model,
			"Eye",
			Vector3.new(0.1, 0.3, 0.3) * s,
			head.CFrame * CFrame.new(x * 0.66 * s, 0.2 * s, -0.4 * s),
			dark
		)
		block(
			model,
			"Ear",
			Vector3.new(0.3, 0.6, 0.3) * s,
			head.CFrame * CFrame.new(x * 0.4 * s, 0.9 * s, 0.7 * s),
			brown
		)
		for _, z in { -1, 1 } do
			block(
				model,
				"Leg",
				Vector3.new(0.7 * s, legH, 0.7 * s),
				CFrame.new(x * 0.8 * s, legH / 2, z * 2 * s),
				brown
			)
			block(model, "Hoof", Vector3.new(0.8, 0.4, 0.8) * s, CFrame.new(x * 0.8 * s, 0.2 * s, z * 2 * s), dark)
		end
	end
	block(
		model,
		"Tail",
		Vector3.new(0.5, 2.4, 0.5) * s,
		body.CFrame * CFrame.new(0, -0.2 * s, 2.9 * s) * CFrame.Angles(math.rad(20), 0, 0),
		dark
	)
	model.PrimaryPart = body
end

local function buildChicken(model: Model, s: number)
	local white = Color3.fromRGB(250, 250, 245)
	local red = Color3.fromRGB(220, 40, 40)
	local orange = Color3.fromRGB(245, 160, 40)
	local legH = 0.8 * s
	local body = block(model, "Body", Vector3.new(1.4, 1.3, 1.8) * s, CFrame.new(0, legH + 0.65 * s, 0), white)
	local head =
		block(model, "Head", Vector3.new(0.9, 0.9, 0.9) * s, body.CFrame * CFrame.new(0, 0.9 * s, -0.8 * s), white)
	block(model, "Comb", Vector3.new(0.25, 0.5, 0.7) * s, head.CFrame * CFrame.new(0, 0.6 * s, 0), red)
	block(model, "Beak", Vector3.new(0.35, 0.3, 0.4) * s, head.CFrame * CFrame.new(0, -0.05 * s, -0.6 * s), orange)
	block(model, "Wattle", Vector3.new(0.2, 0.35, 0.15) * s, head.CFrame * CFrame.new(0, -0.45 * s, -0.45 * s), red)
	block(model, "TailFeathers", Vector3.new(1, 0.9, 0.5) * s, body.CFrame * CFrame.new(0, 0.4 * s, 1 * s), white)
	for _, x in { -1, 1 } do
		block(model, "Leg", Vector3.new(0.2 * s, legH, 0.2 * s), CFrame.new(x * 0.35 * s, legH / 2, 0), orange)
		block(
			model,
			"Wing",
			Vector3.new(0.2, 0.8, 1.2) * s,
			body.CFrame * CFrame.new(x * 0.78 * s, 0.05 * s, 0.1 * s),
			Color3.fromRGB(235, 235, 230)
		)
	end
	model.PrimaryPart = body
end

local function buildGoat(model: Model, s: number)
	local coat = Color3.fromRGB(235, 228, 215)
	local patch = Color3.fromRGB(140, 100, 70)
	local horn = Color3.fromRGB(120, 115, 105)
	local dark = Color3.fromRGB(40, 35, 30)
	local legH = 1.7 * s
	local body = block(model, "Body", Vector3.new(1.7, 1.6, 3) * s, CFrame.new(0, legH + 0.8 * s, 0), coat)
	block(model, "Patch", Vector3.new(1.75, 0.9, 1.2) * s, body.CFrame * CFrame.new(0, 0.4 * s, 0.5 * s), patch)
	local head = block(
		model,
		"Head",
		Vector3.new(1, 1.1, 1.4) * s,
		body.CFrame * CFrame.new(0, 1 * s, -1.8 * s) * CFrame.Angles(math.rad(-15), 0, 0),
		coat
	)
	block(model, "Beard", Vector3.new(0.35, 0.7, 0.25) * s, head.CFrame * CFrame.new(0, -0.8 * s, -0.4 * s), coat)
	for _, x in { -1, 1 } do
		block(
			model,
			"Horn",
			Vector3.new(0.22, 0.9, 0.22) * s,
			head.CFrame * CFrame.new(x * 0.3 * s, 0.85 * s, 0.35 * s) * CFrame.Angles(math.rad(35), 0, 0),
			horn
		)
		block(
			model,
			"Ear",
			Vector3.new(0.6, 0.2, 0.3) * s,
			head.CFrame * CFrame.new(x * 0.7 * s, 0.25 * s, 0.1 * s) * CFrame.Angles(0, 0, x * math.rad(-20)),
			coat
		)
		block(
			model,
			"Eye",
			Vector3.new(0.1, 0.2, 0.2) * s,
			head.CFrame * CFrame.new(x * 0.51 * s, 0.15 * s, -0.35 * s),
			dark
		)
		for _, z in { -1, 1 } do
			block(
				model,
				"Leg",
				Vector3.new(0.4 * s, legH, 0.4 * s),
				CFrame.new(x * 0.55 * s, legH / 2, z * 1.1 * s),
				coat
			)
			block(
				model,
				"Hoof",
				Vector3.new(0.45, 0.25, 0.45) * s,
				CFrame.new(x * 0.55 * s, 0.12 * s, z * 1.1 * s),
				dark
			)
		end
	end
	block(
		model,
		"Tail",
		Vector3.new(0.25, 0.6, 0.25) * s,
		body.CFrame * CFrame.new(0, 0.7 * s, 1.55 * s) * CFrame.Angles(math.rad(-30), 0, 0),
		coat
	)
	model.PrimaryPart = body
end

-- Balık: elips gövde, açık renkli karın, yüzgeçler, çatal kuyruk. -Z yönüne yüzer.
local function buildFishModel(model: Model, s: number, back: Color3, belly: Color3, length: number)
	local body = block(model, "Body", Vector3.new(0.7, 0.8, length) * s, CFrame.new(0, 0, 0), back)
	local bodyMesh = Instance.new("SpecialMesh")
	bodyMesh.MeshType = Enum.MeshType.Sphere
	bodyMesh.Parent = body
	local bellyPart =
		block(model, "Belly", Vector3.new(0.6, 0.45, length * 0.85) * s, CFrame.new(0, -0.18 * s, 0), belly)
	local bellyMesh = Instance.new("SpecialMesh")
	bellyMesh.MeshType = Enum.MeshType.Sphere
	bellyMesh.Parent = bellyPart
	for _, x in { -1, 1 } do
		block(
			model,
			"Eye",
			Vector3.new(0.08, 0.14, 0.14) * s,
			CFrame.new(x * 0.3 * s, 0.1 * s, -length * 0.36 * s),
			Color3.fromRGB(20, 20, 25)
		)
		block(
			model,
			"Fin",
			Vector3.new(0.05, 0.3, 0.45) * s,
			CFrame.new(x * 0.36 * s, -0.1 * s, -length * 0.1 * s) * CFrame.Angles(0, 0, x * math.rad(40)),
			back
		)
	end
	block(model, "DorsalFin", Vector3.new(0.05, 0.4, length * 0.35) * s, CFrame.new(0, 0.5 * s, 0), back)
	for _, angle in { 30, -30 } do
		block(
			model,
			"Tail",
			Vector3.new(0.05, 0.55, 0.45) * s,
			CFrame.new(0, 0, length * 0.55 * s) * CFrame.Angles(math.rad(angle), 0, 0) * CFrame.new(0, 0, 0.15 * s),
			back
		)
	end
	model.PrimaryPart = body
end

local function buildAnchovy(model: Model, s: number)
	buildFishModel(model, s * 0.9, Color3.fromRGB(70, 110, 150), Color3.fromRGB(215, 225, 235), 2)
end

local function buildSeabass(model: Model, s: number)
	buildFishModel(model, s * 1.4, Color3.fromRGB(110, 120, 130), Color3.fromRGB(230, 232, 235), 2.4)
end

local BUILDERS: { [string]: (Model, number) -> () } = {
	cow = buildCow,
	horse = buildHorse,
	chicken = buildChicken,
	goat = buildGoat,
	anchovy = buildAnchovy,
	seabass = buildSeabass,
}

local function cloneAssetAnimal(animalId: string, scale: number): Model?
	local assets = ServerStorage:FindFirstChild("Assets") or ReplicatedStorage:FindFirstChild("Assets")
	local animalsFolder = assets and assets:FindFirstChild("Animals")
	local template = animalsFolder and animalsFolder:FindFirstChild(animalId)
	if not template or not template:IsA("Model") then
		return nil
	end

	local clone = AssetSanitizer.clone(template, false)
	if scale ~= 1 then
		clone:ScaleTo(clone:GetScale() * scale)
	end
	return clone
end

local function createAnimalVisual(animalId: string, stage: string): Model
	local scale = STAGE_SCALE[stage] or 1
	local asset = cloneAssetAnimal(animalId, scale)
	if asset then
		return asset
	end
	local model = Instance.new("Model")
	local builder = BUILDERS[animalId] or buildCow
	builder(model, scale)
	return model
end

-- Hayvanların durabileceği alan: zemin eksi kenar payı ve arkadaki yapılar (Ground.BackReserve)
local SIDE_MARGIN = 2

local function getAnimalArea(ground: BasePart): (CFrame, Vector3)
	local size = ground.Size
	local reserve = ground:GetAttribute("BackReserve")
	local back = if typeof(reserve) == "number" then reserve else 0
	local width = math.max(size.X - SIDE_MARGIN * 2, 1)
	local depth = math.max(size.Z - SIDE_MARGIN - math.max(back, SIDE_MARGIN), 1)
	-- Alan önden (-Z) başlar, arka şeridi dışarıda bırakır
	local centerZ = -size.Z / 2 + SIDE_MARGIN + depth / 2
	return ground.CFrame * CFrame.new(0, size.Y / 2, centerZ), Vector3.new(width, 0, depth)
end

-- Alanı hücrelere bölüp index. hücrenin merkezini döner
local function slotCFrame(area: CFrame, size: Vector3, index: number, capacity: number): CFrame
	local cols = math.max(1, math.ceil(math.sqrt(capacity * size.X / size.Z)))
	local rows = math.max(1, math.ceil(capacity / cols))
	local col = (index - 1) % cols
	local row = math.floor((index - 1) / cols) % rows
	local x = -size.X / 2 + size.X / cols * (col + 0.5)
	local z = -size.Z / 2 + size.Z / rows * (row + 0.5)
	-- Hepsi aynı yöne bakmasın diye hafif rastgele görünen açı
	local yaw = math.rad(((index * 47) % 90) - 45)
	return area * CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
end

-- Modeli, alt noktası yüzeye oturacak şekilde yerleştirir
local function placeOnSurface(model: Model, target: CFrame)
	model:PivotTo(target)
	local boxCf, boxSize = model:GetBoundingBox()
	local bottom = boxCf.Position.Y - boxSize.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, target.Position.Y - bottom, 0))
end

local function addNameTag(model: Model, text: string, extraHeight: number)
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then
		return
	end
	local _, boxSize = model:GetBoundingBox()
	local length = utf8.len(text) or #text
	WorldUi.tag(anchor, "NameTag", {
		text = text,
		widthStuds = math.max(length * 0.32 + 0.6, 2.2),
		heightStuds = 0.8,
		worldOffset = Vector3.new(0, boxSize.Y / 2 + 1 + extraHeight, 0),
		maxDistance = 45,
	})
end

local function findZoneGround(plot: Model, zoneId: string): BasePart?
	local zones = plot:FindFirstChild("Zones")
	if not zones then
		return nil
	end
	for _, zone in zones:GetChildren() do
		if zone:GetAttribute("ZoneId") == zoneId then
			local ground = zone:FindFirstChild("Ground")
			if ground and ground:IsA("BasePart") then
				return ground
			end
		end
	end
	return nil
end

function AnimalVisualService.clear(plot: Model)
	local folder = plot:FindFirstChild("Animals")
	if folder then
		folder:ClearAllChildren()
	end
end

local function buildAnimal(
	animal: GameTypes.AnimalRecord,
	ground: BasePart,
	slot: number,
	capacity: number,
	movementStyle: string?
): Model
	local visual = createAnimalVisual(animal.animalId, animal.stage)
	visual.Name = `{animal.animalId}_{animal.uid}`
	visual:SetAttribute("VisualCreatedAt", game:GetService("Workspace"):GetServerTimeNow())
	local areaCf, areaSize = getAnimalArea(ground)
	-- Denizdeki bölgede (balık kafesi) hayvan yüzeyin altında yüzer
	local swimDepth = ground:GetAttribute("SwimDepth")
	local depth = if typeof(swimDepth) == "number" then swimDepth else 0
	placeOnSurface(visual, slotCFrame(areaCf, areaSize, slot, capacity) * CFrame.new(0, -depth, 0))

	-- Değişmeyen hayvanları bir dahaki yenilemede tanımak için
	visual:SetAttribute("Uid", animal.uid)
	visual:SetAttribute("Stage", animal.stage)
	visual:SetAttribute("ZoneId", animal.zoneId)
	visual:SetAttribute("ExtensionId", animal.extensionId or "")
	-- Client'taki AnimalAnimator hayvanı bu alan içinde gezdirir
	visual:SetAttribute("AreaCFrame", areaCf)
	visual:SetAttribute("AreaSize", areaSize)
	visual:SetAttribute("HeightOffset", visual:GetPivot().Position.Y - areaCf.Position.Y)
	if movementStyle then
		visual:SetAttribute("MovementStyle", movementStyle)
	end
	CollectionService:AddTag(visual, "Animal")

	local animalConfig = Config.ANIMALS[animal.animalId]
	local name = if animalConfig then animalConfig.displayName else animal.animalId
	-- Yetişkinlerde sadece ad; büyüyenlerde evre de yazsın
	local tag = if animal.stage == "adult"
		then name
		else `{name} ({Config.STAGE_DISPLAY[animal.stage] or animal.stage})`
	addNameTag(visual, tag, depth) -- Balıklarda etiket suyun üstünde kalsın
	return visual
end

local function buildAnimalInArea(
	animal: GameTypes.AnimalRecord,
	areaCf: CFrame,
	areaSize: Vector3,
	slot: number,
	capacity: number,
	movementStyle: string?
): Model
	local ground = Instance.new("Part")
	ground.Size = Vector3.new(areaSize.X, 1, areaSize.Z)
	ground.CFrame = areaCf
	ground.Anchored = true
	ground.Transparency = 1
	ground.CanCollide = false
	ground.CanQuery = false
	local visual = buildAnimal(animal, ground, slot, capacity, movementStyle)
	ground:Destroy()
	return visual
end

-- Sadece değişen hayvanları yeniden kurar: yeni alınanlar eklenir, büyüyenler (evresi değişen)
-- yenilenir, gidenler silinir. Değişmeyenlere dokunulmaz, böylece gezinirken yerlerine zıplamazlar.
function AnimalVisualService.refresh(plot: Model, data: PlayerSave)
	local folder = plot:FindFirstChild("Animals")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Animals"
		folder.Parent = plot
	end
	local animalsFolder = folder :: Instance

	local existingByUid: { [string]: Model } = {}
	for _, child in animalsFolder:GetChildren() do
		local uid = child:GetAttribute("Uid")
		if child:IsA("Model") and typeof(uid) == "string" then
			existingByUid[uid] = child
		else
			child:Destroy()
		end
	end

	local perZoneCount: { [string]: number } = {}
	local perExtensionCount: { [string]: number } = {}
	local keep: { [string]: boolean } = {}
	for _, animal in data.animals do
		if not data.unlockedZones[animal.zoneId] then
			continue
		end

		local existing = existingByUid[animal.uid]
		local existingExt = if existing then existing:GetAttribute("ExtensionId") else nil
		if
			existing
			and existing:GetAttribute("Stage") == animal.stage
			and existing:GetAttribute("ZoneId") == animal.zoneId
			and existingExt == (animal.extensionId or "")
		then
			keep[animal.uid] = true
			continue
		end

		local visual: Model
		if animal.extensionId and animal.extensionId ~= "" then
			local areaCf, areaSize, movement = ExtensionAreas.find(plot, animal.extensionId)
			local extension = Config.getExtension(animal.extensionId)
			if not areaCf or not areaSize or not extension then
				continue
			end
			perExtensionCount[animal.extensionId] = (perExtensionCount[animal.extensionId] or 0) + 1
			visual = buildAnimalInArea(
				animal,
				areaCf,
				areaSize,
				perExtensionCount[animal.extensionId],
				extension.capacity,
				movement
			)
		else
			local ground = findZoneGround(plot, animal.zoneId)
			local zoneConfig = Config.ZONES[animal.zoneId]
			if not ground or not zoneConfig then
				continue
			end
			perZoneCount[animal.zoneId] = (perZoneCount[animal.zoneId] or 0) + 1
			visual = buildAnimal(animal, ground, perZoneCount[animal.zoneId], zoneConfig.capacity, nil)
		end
		if existing then
			existing:Destroy()
		end
		keep[animal.uid] = true
		visual.Parent = animalsFolder
	end

	for uid, model in existingByUid do
		if not keep[uid] and model.Parent then
			model:Destroy()
		end
	end
end

return AnimalVisualService
