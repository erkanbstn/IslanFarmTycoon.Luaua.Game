--!strict
-- Bina görselleri için ortak yapı taşları (parça, sütun, top, kiriş, tabela, sivri burun) ve sabitler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))

export type Builder = (model: Model, base: CFrame) -> ()

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

-- Dik silindir (Part silindirinin ekseni X olduğu için döndürülür)
local function makeColumn(
	model: Model,
	name: string,
	diameter: number,
	height: number,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = makePart(
		model,
		name,
		Vector3.new(height, diameter, diameter),
		cframe * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function makeBall(
	model: Model,
	name: string,
	diameter: number,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = makePart(model, name, Vector3.one * diameter, cframe, color, material)
	part.Shape = Enum.PartType.Ball
	return part
end

local function beam(model: Model, name: string, from: Vector3, to: Vector3, width: number, color: Color3): Part
	return makePart(
		model,
		name,
		Vector3.new(width, width, (to - from).Magnitude),
		CFrame.lookAt((from + to) / 2, to),
		color,
		Enum.Material.Metal
	)
end

-- Hazır modeldeki tahtanın (SignBoard, geometri modelde) ön yüzüne yazıyı ekler; tahta çarpışmaz, direkler çarpışır.
local function faceSign(board: BasePart, title: string, text: string, icon: string)
	board.Name = "ProductionSign"
	board.CanCollide = false
	WorldUi.sign(board, Enum.NormalId.Front, { title = title, text = text, icon = icon })
end

local function sign(model: Model, at: CFrame, title: string, text: string, icon: string, width: number)
	local board = makePart(
		model,
		"ProductionSign",
		Vector3.new(width, 1.7, 0.16),
		at,
		Color3.fromRGB(39, 66, 77),
		Enum.Material.Metal
	)
	faceSign(board, title, text, icon)
end

-- Wedge'ın eğimi Y/Z düzlemindedir. Z çevresinde ±90° döndürüp çift kullanarak
-- yatayda daralan, ortası birleşik ve gövdeyle örtüşen gerçek bir sivri burun oluşur.
local function taperedBow(
	model: Model,
	name: string,
	base: CFrame,
	halfWidth: number,
	height: number,
	length: number,
	y: number,
	z: number,
	color: Color3,
	material: Enum.Material
)
	for _, side in { -1, 1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = name
		wedge.Size = Vector3.new(height, halfWidth, length)
		wedge.CFrame = base * CFrame.new(side * halfWidth / 2, y, z) * CFrame.Angles(0, 0, -side * math.pi / 2)
		wedge.Color = color
		wedge.Material = material
		wedge.Anchored = true
		wedge.CanCollide, wedge.CanTouch, wedge.CanQuery = false, false, false
		wedge.Parent = model
	end
end

return {
	METAL = METAL,
	GOLD = GOLD,
	PRODUCTION_RECIPES = PRODUCTION_RECIPES,
	makePart = makePart,
	makeColumn = makeColumn,
	makeBall = makeBall,
	beam = beam,
	sign = sign,
	faceSign = faceSign,
	taperedBow = taperedBow,
}
