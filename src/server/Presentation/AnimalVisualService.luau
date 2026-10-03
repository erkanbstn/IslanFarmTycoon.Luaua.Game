--!strict
-- Hayvanları bölgelerin zemininde ızgara halinde gösterir.
-- Kendi modelini kullanmak için: ServerStorage.Assets.Animals içine "cow", "horse", "chicken"
-- adında Model koy (Toolbox'tan da olur). Yoksa kodla basit bloklardan hayvan yapılır.

-- Parçalar: AnimalModels (model üretimi), AnimalPlacement (yerleşim), AnimalLabels (ad/ırk etiketi).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local InstanceUtil = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("InstanceUtil"))
local ExtensionAreas = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ExtensionAreas"))
local AnimalModels = require(script.Parent:WaitForChild("AnimalModels"))
local AnimalPlacement = require(script.Parent:WaitForChild("AnimalPlacement"))
local AnimalLabels = require(script.Parent:WaitForChild("AnimalLabels"))
local VisualWorkBudget = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("VisualWorkBudget"))

type PlayerSave = GameTypes.PlayerSave

local AnimalVisualService = {}

local createAnimalVisual = AnimalModels.createAnimalVisual
local getAnimalArea = AnimalPlacement.getAnimalArea
local slotCFrame = AnimalPlacement.slotCFrame
local placeOnSurface = AnimalPlacement.placeOnSurface
local findZoneGround = AnimalPlacement.findZoneGround
local addNameTag = AnimalLabels.addNameTag
local applyLineage = AnimalLabels.applyLineage
local tierOf = AnimalLabels.tierOf

function AnimalVisualService.clear(plot: Model)
	local folder = plot:FindFirstChild("Animals")
	if folder then
		for _, child in folder:GetChildren() do
			local weight = #child:GetDescendants() + 1
			child:Destroy()
			VisualWorkBudget.step(weight)
		end
	end
end

local function buildAnimal(
	animal: GameTypes.AnimalRecord,
	ground: BasePart,
	slot: number,
	capacity: number,
	movementStyle: string?,
	lineageLevel: number,
	themeKey: string
): Model
	local look = Config.getAnimalLook(animal.animalId, themeKey)
	local visual = createAnimalVisual(look.modelId, animal.stage, tierOf(lineageLevel))
	visual.Name = `{animal.animalId}_{animal.uid}`
	-- Parçalar birlikte akar: istemcideki AnimalAnimator parça listesini bir kez çıkarıp topluca taşır; streaming parçaları ayrı
	-- getirirse geç gelen parça (baş, kanat, bacak) hayvanın yerinde kalıp kopuk görünür.
	visual.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	visual:SetAttribute("VisualCreatedAt", game:GetService("Workspace"):GetServerTimeNow())
	local areaCf, areaSize = getAnimalArea(ground)
	-- Denizdeki bölgede (balık kafesi) hayvan yüzeyin altında yüzer
	local swimDepth = ground:GetAttribute("SwimDepth")
	local depth = if typeof(swimDepth) == "number" then swimDepth else 0
	placeOnSurface(visual, slotCFrame(areaCf, areaSize, slot, capacity) * CFrame.new(0, -depth, 0))

	-- Değişmeyen hayvanları bir dahaki yenilemede tanımak için
	visual:SetAttribute("Uid", animal.uid)
	visual:SetAttribute("SwimDepthOffset", depth)
	visual:SetAttribute("Stage", animal.stage)
	visual:SetAttribute("LineageTier", tierOf(lineageLevel))
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

	local name = look.displayName
	-- Yetişkinlerde sadece ad; büyüyenlerde evre de yazsın
	local tag = if animal.stage == "adult"
		then name
		else `{name} ({Config.STAGE_DISPLAY[animal.stage] or animal.stage})`
	addNameTag(visual, tag, depth) -- Balıklarda etiket suyun üstünde kalsın
	applyLineage(visual, lineageLevel, depth)
	do
		local parts = 0
		for _, descendant in visual:GetDescendants() do
			if descendant:IsA("BasePart") then
				parts += 1
			end
		end
		visual:SetAttribute("PartCount", parts)
	end
	return visual
end

local function buildAnimalInArea(
	animal: GameTypes.AnimalRecord,
	areaCf: CFrame,
	areaSize: Vector3,
	slot: number,
	capacity: number,
	movementStyle: string?,
	lineageLevel: number,
	themeKey: string
): Model
	local ground = Instance.new("Part")
	ground.Size = Vector3.new(areaSize.X, 1, areaSize.Z)
	ground.CFrame = areaCf
	ground.Anchored = true
	ground.Transparency = 1
	ground.CanCollide = false
	ground.CanQuery = false
	local visual = buildAnimal(animal, ground, slot, capacity, movementStyle, lineageLevel, themeKey)
	ground:Destroy()
	return visual
end

-- Sadece değişen hayvanları yeniden kurar: yeni alınanlar eklenir, büyüyenler (evresi değişen)
-- yenilenir, gidenler silinir. Değişmeyenlere dokunulmaz, böylece gezinirken yerlerine zıplamazlar.
function AnimalVisualService.refresh(plot: Model, data: PlayerSave)
	local animalsFolder = InstanceUtil.getOrCreateFolder(plot, "Animals")
	local themeKey = tostring(plot:GetAttribute("ThemeIndex") or "1")

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
	local now = DateTime.now().UnixTimestampMillis / 1000
	for _, animal in data.animals do
		-- Üretim tesisine verilen hayvan iş boyunca görünmez (tesiste çalışır); süre dolunca AnimalTaskService eve döndürür.
		if not data.unlockedZones[animal.zoneId] or FarmMath.isInProduction(animal, now) then
			continue
		end

		-- Yuva sırası bölgedeki (ya da eklenti alanındaki) tüm görünür hayvanlara göre verilir; yerinde kalanlar da sayılır,
		-- böylece yeni eklenen hayvan onların yuvasına düşmez.
		local isExtension = animal.extensionId ~= nil and animal.extensionId ~= ""
		local slot: number
		local extensionId = animal.extensionId or ""
		if isExtension then
			slot = (perExtensionCount[extensionId] or 0) + 1
			perExtensionCount[extensionId] = slot
		else
			slot = (perZoneCount[animal.zoneId] or 0) + 1
			perZoneCount[animal.zoneId] = slot
		end

		local existing = existingByUid[animal.uid]
		local existingExt = if existing then existing:GetAttribute("ExtensionId") else nil
		local lineageLevel = FarmMath.getLineageLevel(data, animal.animalId)
		if
			existing
			and existing:GetAttribute("Stage") == animal.stage
			and existing:GetAttribute("LineageTier") == tierOf(lineageLevel)
			and existing:GetAttribute("ZoneId") == animal.zoneId
			and existingExt == (animal.extensionId or "")
		then
			keep[animal.uid] = true
			-- Irk seviyesi aynı kademede değiştiyse yalnızca rozet yenilenir; kademe değişince hayvan yukarıda yeniden kurulur (boy/aksesuar)
			if existing:GetAttribute("Lineage") ~= lineageLevel then
				local swimDepth = existing:GetAttribute("SwimDepthOffset")
				applyLineage(existing, lineageLevel, if typeof(swimDepth) == "number" then swimDepth else 0)
			end
			continue
		end

		VisualWorkBudget.step()
		local visual: Model
		if isExtension then
			local areaCf, areaSize, movement = ExtensionAreas.find(plot, extensionId)
			local extension = Config.getExtension(extensionId)
			if not areaCf or not areaSize or not extension then
				continue
			end
			visual = buildAnimalInArea(
				animal,
				areaCf,
				areaSize,
				slot,
				FarmMath.getExtensionCapacity(data, extensionId),
				movement,
				lineageLevel,
				themeKey
			)
		else
			local ground = findZoneGround(plot, animal.zoneId)
			local zoneConfig = Config.ZONES[animal.zoneId]
			if not ground or not zoneConfig then
				continue
			end
			visual = buildAnimal(
				animal,
				ground,
				slot,
				FarmMath.getZoneCapacity(data, animal.zoneId),
				nil,
				lineageLevel,
				themeKey
			)
		end
		if existing then
			existing:Destroy()
		end
		keep[animal.uid] = true
		visual.Parent = animalsFolder
		VisualWorkBudget.step(#visual:GetDescendants() + 1)
	end

	for uid, model in existingByUid do
		if not keep[uid] and model.Parent then
			local weight = #model:GetDescendants() + 1
			model:Destroy()
			VisualWorkBudget.step(weight)
		end
	end
end

return AnimalVisualService
