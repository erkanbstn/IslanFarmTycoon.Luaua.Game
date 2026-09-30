--!strict
-- Süs eşyaları için ortak yapı taşları: parça, top, sütun.
-- WorldDecor cephesi bunları birleştirir; her zaman `WorldDecor.<ad>` ile kullan.

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
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
): Part
	local p = part(parent, name, Vector3.one * diameter, cf, color, material)
	p.Shape = Enum.PartType.Ball
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
	material: Enum.Material
): Part
	local p = part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		cf * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

return {
	part = part,
	ball = ball,
	column = column,
}
