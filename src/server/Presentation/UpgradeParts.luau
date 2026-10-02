--!strict
-- Bina görselleri için ortak yapı taşları (parça, tabela yüzü) ve sabitler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))

local METAL = Color3.fromRGB(190, 195, 200)
local GOLD = Color3.fromRGB(255, 200, 60)
-- Bina id -> üretim tarifi kimliği (Config'ten türetilir). Balıkçı Teknesi gezindiği için dünyada prompt/işaret taşımaz.
local PRODUCTION_RECIPES: { [string]: string } = {}
for recipeId, recipe in Config.PRODUCTION_RECIPES do
	if recipe.upgradeId ~= "fishing_boat" then
		PRODUCTION_RECIPES[recipe.upgradeId] = recipeId
	end
end

local function makePart(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- Hazır modeldeki tahtanın (SignBoard, geometri modelde) ön yüzüne yazıyı ekler; tahta çarpışmaz, direkler çarpışır.
local function faceSign(board: BasePart, title: string, text: string, icon: string)
	board.Name = "ProductionSign"
	board.CanCollide = false
	WorldUi.sign(board, Enum.NormalId.Front, { title = title, text = text, icon = icon })
end

return {
	METAL = METAL,
	GOLD = GOLD,
	PRODUCTION_RECIPES = PRODUCTION_RECIPES,
	makePart = makePart,
	faceSign = faceSign,
}
