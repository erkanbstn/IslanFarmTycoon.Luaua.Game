--!strict
-- Hayvan modelleri: ServerStorage.Assets.Animals.<animalId> (kaynak: assets/Animals/<id>.rbxmx; kural: docs/MODEL_SOZLESMESI.md).
-- Model yoksa görünür bir yer tutucu kutu çizilir ve bir kez uyarılır (Config'e yeni hayvan eklenip modeli unutulursa hemen anlaşılsın).

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetSanitizer = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("AssetSanitizer"))

local STAGE_SCALE: { [string]: number } = {
	calf = 0.55,
	young = 0.8,
	adult = 1,
}

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

-- Yer tutucu: 2x2x3 koyu pembe kutu (baş -Z), PrimaryPart Body
local function placeholder(animalId: string, scale: number): Model
	if not warned[animalId] then
		warned[animalId] = true
		warn(`[AnimalModels] assets/Animals/{animalId}.rbxmx bulunamadı; yer tutucu kutu çiziliyor`)
	end
	local model = Instance.new("Model")
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2, 2, 3) * scale
	body.Position = Vector3.new(0, 1.5 * scale, 0)
	body.Color = Color3.fromRGB(190, 60, 140)
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Parent = model
	model.PrimaryPart = body
	return model
end

local function createAnimalVisual(animalId: string, stage: string): Model
	local scale = STAGE_SCALE[stage] or 1
	return cloneAssetAnimal(animalId, scale) or placeholder(animalId, scale)
end

return {
	createAnimalVisual = createAnimalVisual,
}
