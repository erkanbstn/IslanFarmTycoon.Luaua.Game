--!strict
-- Ana ada yapıları için ortak renkler ve yapı taşları (parça, top, sütun, duvarlı oda, çatı, pencere).
-- Kapılar >= 4.6 x 6.6 stud (kümes/ahır ile aynı ölçü kuralı).

local WorldDecor = require(script.Parent:WaitForChild("WorldDecor"))

local WOOD = Color3.fromRGB(150, 110, 70)
local DARK_WOOD = Color3.fromRGB(100, 70, 45)
local CREAM = Color3.fromRGB(235, 224, 192)
local PLASTER = Color3.fromRGB(226, 214, 190)
local ROOF_RED = Color3.fromRGB(160, 62, 48)
local STONE = Color3.fromRGB(128, 126, 118)
local STRAW = Color3.fromRGB(225, 195, 110)
local WATER = Color3.fromRGB(70, 160, 220)

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	solid: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanTouch = false
	p.CanCollide = solid ~= false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function ball(
	parent: Instance,
	name: string,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
)
	local p = part(parent, name, Vector3.one * diameter, cf, color, material, false)
	p.Shape = Enum.PartType.Ball
	p.CastShadow = false
	return p
end

-- Dik silindir (Part silindirinin ekseni X'tir)
local function column(
	parent: Instance,
	name: string,
	diameter: number,
	height: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	solid: boolean?
): Part
	local p = part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		cf * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		solid
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Beşik çatı: X boyunca uzanan, iki eğik levha
local function gableRoof(parent: Instance, base: CFrame, width: number, depth: number, y: number, color: Color3)
	local angle = math.rad(30)
	local half = (width / 2 + 0.8) / math.cos(angle)
	for _, side in { -1, 1 } do
		part(
			parent,
			"Roof",
			Vector3.new(half, 0.5, depth + 1.6),
			base
				* CFrame.new(side * (half / 2) * math.cos(angle), y + (half / 2) * math.sin(angle), 0)
				* CFrame.Angles(0, 0, -side * angle),
			color,
			Enum.Material.Slate,
			true -- Çatı katı: üstten içeri düşülmez
		)
	end
end

-- Duvarlı bölme: ön duvarda kapı boşluğu bırakır (karakter girebilsin)
local function walledRoom(
	parent: Instance,
	base: CFrame,
	width: number,
	depth: number,
	wallH: number,
	doorW: number,
	doorH: number,
	color: Color3,
	material: Enum.Material
)
	local wallY = wallH / 2
	part(
		parent,
		"WallBack",
		Vector3.new(width, wallH, 0.5),
		base * CFrame.new(0, wallY, depth / 2 - 0.25),
		color,
		material
	)
	for _, side in { -1, 1 } do
		part(
			parent,
			"WallSide",
			Vector3.new(0.5, wallH, depth),
			base * CFrame.new(side * (width / 2 - 0.25), wallY, 0),
			color,
			material
		)
		local frontW = (width - doorW) / 2
		part(
			parent,
			"WallFront",
			Vector3.new(frontW, wallH, 0.5),
			base * CFrame.new(side * (doorW / 2 + frontW / 2), wallY, -(depth / 2 - 0.25)),
			color,
			material
		)
	end
	part(
		parent,
		"WallHeader",
		Vector3.new(doorW, wallH - doorH, 0.5),
		base * CFrame.new(0, doorH + (wallH - doorH) / 2, -(depth / 2 - 0.25)),
		color,
		material
	)
end

local function windowPane(parent: Instance, base: CFrame, size: Vector3, offset: Vector3)
	local pane = part(
		parent,
		"Window",
		size,
		base * CFrame.new(offset),
		Color3.fromRGB(120, 180, 220),
		Enum.Material.Glass,
		false
	)
	WorldDecor.markNightWindow(pane)
	return pane
end

return {
	WOOD = WOOD,
	DARK_WOOD = DARK_WOOD,
	CREAM = CREAM,
	PLASTER = PLASTER,
	ROOF_RED = ROOF_RED,
	STONE = STONE,
	STRAW = STRAW,
	WATER = WATER,
	part = part,
	ball = ball,
	column = column,
	model = model,
	gableRoof = gableRoof,
	walledRoom = walledRoom,
	windowPane = windowPane,
}
