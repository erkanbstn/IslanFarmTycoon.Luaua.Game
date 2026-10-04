--!strict
-- Hayvan modelleri: ServerStorage.Assets.Animals.<animalId> (kaynak: assets/Animals/<id>.rbxmx; kural: docs/MODEL_SOZLESMESI.md).
-- Model yoksa bir kez uyarılır ve görünüm atlanır; sonraki yenileme modeli yeniden arar.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetSanitizer = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("AssetSanitizer"))

local STAGE_SCALE: { [string]: number } = {
	calf = 0.55,
	young = 0.8,
	adult = 1,
}

-- Irk kademesine göre görünüm (docs/ANIMAL_LINEAGE_MODELLERI.md): boy büyümesi, hafif renk tonu ve türe özel aksesuar modelleri.
-- Aksesuarlar assets/AnimalLineage/<modelId>_T2|T3|T4 (yalnız o kademenin yeni parçaları; yüksek kademe öncekileri de alır).
-- Parçalar yetişkin hayvanın Body koordinatındadır; hayvanın o anki ölçeğiyle büyütülüp Body'ye göre konur, hayvanın parçası olur.
local TIER_SCALE = { 1.03, 1.06, 1.09, 1.12 }
local TIER_TINT = {
	Color3.fromRGB(205, 127, 50),
	Color3.fromRGB(190, 198, 210),
	Color3.fromRGB(255, 200, 70),
	Color3.fromRGB(110, 220, 255),
}
local TIER_TINT_AMOUNT = { 0.06, 0.08, 0.1, 0.12 }
local TINT_SKIP = { Eye = true, Pupil = true, Lineage = true }

local warned: { [string]: boolean } = {}

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

local function findLineageModel(animalId: string, tier: number): Model?
	local assets = ServerStorage:FindFirstChild("Assets") or ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("AnimalLineage")
	local template = folder and folder:FindFirstChild(`{animalId}_T{tier}`)
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

local function applyTier(visual: Model, animalId: string, tier: number)
	local body = visual.PrimaryPart or visual:FindFirstChild("Body")
	if not (body and body:IsA("BasePart")) then
		return
	end
	-- Hafif renk tonu (gövde parçaları; gözler ve aksesuarlar hariç)
	for _, part in visual:GetDescendants() do
		if part:IsA("BasePart") and not TINT_SKIP[part.Name] then
			part.Color = part.Color:Lerp(TIER_TINT[tier], TIER_TINT_AMOUNT[tier])
		end
	end
	-- Aksesuarlar: T2 ve üstü; T3 = T2+T3, T4 = T2+T3+T4
	local scale = visual:GetScale()
	local bodyCf = body.CFrame
	for level = 2, tier do
		local template = findLineageModel(animalId, level)
		if not template then
			if not warned[`{animalId}_T{level}`] then
				warned[`{animalId}_T{level}`] = true
				warn(`[AnimalModels] assets/AnimalLineage/{animalId}_T{level}.rbxmx bulunamadı; aksesuar çizilmedi`)
			end
			continue
		end
		for _, source in template:GetDescendants() do
			if source:IsA("BasePart") then
				local part = source:Clone()
				for _, child in part:GetChildren() do
					if child:IsA("LuaSourceContainer") then
						child:Destroy()
					end
				end
				local cf = source.CFrame
				part.Size = source.Size * scale
				part.CFrame = bodyCf * (cf.Rotation + cf.Position * scale)
				part.Anchored = true
				part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
				part.Parent = visual
			end
		end
	end
	-- Kademeye göre boy büyümesi (aksesuarlarla birlikte, gövde merkezi etrafında)
	visual:ScaleTo(scale * TIER_SCALE[tier])
end

local function createAnimalVisual(animalId: string, stage: string, tier: number?): Model?
	local scale = STAGE_SCALE[stage] or 1
	local visual = cloneAssetAnimal(animalId, scale)
	if not visual then
		if not warned[animalId] then
			warned[animalId] = true
			warn(`[AnimalModels] assets/Animals/{animalId}.rbxmx bulunamadı; görünüm çizilmedi`)
		end
		return nil
	end
	if tier and tier >= 1 then
		applyTier(visual, animalId, math.min(tier, 4))
	end
	return visual
end

return {
	createAnimalVisual = createAnimalVisual,
}
