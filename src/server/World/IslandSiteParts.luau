--!strict
-- Uzman ada yapıları için ortak renkler ve yapı taşları (parça, tabela, yüzey).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Studio harita eklentisi modülleri kopyalayıp çalıştırır; o durumda yanımızdaki "Shared" kullanılır.
local Shared = script.Parent.Parent:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")
local WorldUi = require(Shared:WaitForChild("WorldUi"))

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
		cf * CFrame.new(0, 9.6, 0),
		WOOD,
		Enum.Material.WoodPlanks
	)
	board.CanCollide = false
	part(parent, "SignPost", Vector3.new(0.5, 8.6, 0.5), cf * CFrame.new(0, 4.3, 0), WOOD, Enum.Material.Wood)
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

return {
	WOOD = WOOD,
	CREAM = CREAM,
	STRAW = STRAW,
	ROCK = ROCK,
	part = part,
	sign = sign,
	surface = surface,
}
