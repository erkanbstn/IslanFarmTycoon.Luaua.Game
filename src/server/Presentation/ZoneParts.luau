--!strict
-- Bölge görselleri için ortak yapı taşları, renkler ve tema görünümü (THEME_LOOKS + Look durumu).

export type Builder = (decor: Model, origin: CFrame, size: Vector3) -> ()

local WOOD = Color3.fromRGB(150, 110, 70)
local DARK_WOOD = Color3.fromRGB(100, 70, 45)
local ROOF = Color3.fromRGB(70, 60, 55)
local STRAW = Color3.fromRGB(225, 195, 110)
local WATER = Color3.fromRGB(70, 160, 220)
local METAL = Color3.fromRGB(150, 155, 160)
local STONE_COLOR = Color3.fromRGB(128, 126, 118)

local function part(
	decor: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.Wood
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = decor
	return p
end

-- Arkası (+Z) önünden yüksek, eğimli çatı
local function slopedRoof(
	decor: Model,
	origin: CFrame,
	width: number,
	zFront: number,
	zBack: number,
	yFront: number,
	yBack: number
)
	local depth = zBack - zFront
	local rise = yBack - yFront
	local length = math.sqrt(depth * depth + rise * rise) + 1
	local angle = math.atan2(rise, depth)
	local cf = origin * CFrame.new(0, (yFront + yBack) / 2, (zFront + zBack) / 2) * CFrame.Angles(-angle, 0, 0)
	part(decor, "Roof", Vector3.new(width, 0.5, length), cf, ROOF, Enum.Material.Slate)
end

local function hayBale(decor: Model, cf: CFrame)
	part(decor, "HayBale", Vector3.new(2.6, 1.6, 1.6), cf * CFrame.new(0, 0.8, 0), STRAW, Enum.Material.Fabric)
	-- Bağ ipleri
	for _, x in { -0.6, 0.6 } do
		part(decor, "Twine", Vector3.new(0.15, 1.65, 1.65), cf * CFrame.new(x, 0.8, 0), DARK_WOOD, Enum.Material.Fabric).CanCollide =
			false
	end
end

local function waterTrough(decor: Model, cf: CFrame, length: number)
	part(decor, "Trough", Vector3.new(1.8, 1.2, length), cf * CFrame.new(0, 0.6, 0), METAL, Enum.Material.Metal)
	local water = part(
		decor,
		"Water",
		Vector3.new(1.4, 0.1, length - 0.4),
		cf * CFrame.new(0, 1.24, 0),
		WATER,
		Enum.Material.Glass
	)
	water.Transparency = 0.2
	water.CanCollide = false
end

local function feedTrough(decor: Model, cf: CFrame, length: number)
	part(decor, "FeedTrough", Vector3.new(length, 1.2, 1.6), cf * CFrame.new(0, 0.6, 0), WOOD)
	part(decor, "Feed", Vector3.new(length - 0.4, 0.1, 1.2), cf * CFrame.new(0, 1.24, 0), STRAW, Enum.Material.Grass).CanCollide =
		false
end

local function plant(decor: Model, cf: CFrame, height: number, headColor: Color3, headSize: number)
	part(
		decor,
		"Stem",
		Vector3.new(0.2, height, 0.2),
		cf * CFrame.new(0, height / 2, 0),
		Color3.fromRGB(70, 130, 60),
		Enum.Material.Grass
	).CanCollide =
		false
	local head = part(
		decor,
		"Bloom",
		Vector3.new(headSize, headSize, headSize),
		cf * CFrame.new(0, height, 0),
		headColor,
		Enum.Material.SmoothPlastic
	)
	head.Shape = Enum.PartType.Ball
	head.CanCollide = false
end

local function blossomTree(decor: Model, cf: CFrame, leaf: Color3)
	part(decor, "Trunk", Vector3.new(0.9, 3.4, 0.9), cf * CFrame.new(0, 1.7, 0), DARK_WOOD, Enum.Material.Wood)
	local crown =
		part(decor, "Crown", Vector3.new(4.6, 3.8, 4.6), cf * CFrame.new(0, 4.6, 0), leaf, Enum.Material.Grass)
	crown.Shape = Enum.PartType.Ball
end

local function rockPile(decor: Model, cf: CFrame, scale: number)
	part(
		decor,
		"Rock",
		Vector3.new(2.4, 1.6, 2) * scale,
		cf * CFrame.new(0, 0.7 * scale, 0) * CFrame.Angles(0, 0.6, 0.1),
		STONE_COLOR,
		Enum.Material.Slate
	)
	part(
		decor,
		"Rock",
		Vector3.new(1.4, 1, 1.4) * scale,
		cf * CFrame.new(1.6 * scale, 0.4 * scale, 0.6),
		STONE_COLOR,
		Enum.Material.Slate
	)
end

-- Çiftlik numarasına (= tema) göre ana adadaki inek ağılı ve otlağın görünümü
local THEME_LOOKS: { { barn: Color3, pasture: string } } = {
	{ barn = Color3.fromRGB(170, 45, 38), pasture = "daisy" },
	{ barn = Color3.fromRGB(55, 105, 175), pasture = "tulip" },
	{ barn = Color3.fromRGB(205, 150, 45), pasture = "sunflower" },
	{ barn = Color3.fromRGB(215, 120, 140), pasture = "rose" },
	{ barn = Color3.fromRGB(60, 105, 65), pasture = "pine" },
	{ barn = Color3.fromRGB(225, 205, 170), pasture = "cherry" },
}

-- apply() çiftliğin temasını yazar, builder'lar okur (modül düzeyi durum).
local Look: { current: { barn: Color3, pasture: string }, barnColor: Color3 } = {
	current = THEME_LOOKS[1],
	barnColor = THEME_LOOKS[1].barn,
}

return {
	WOOD = WOOD,
	DARK_WOOD = DARK_WOOD,
	ROOF = ROOF,
	STRAW = STRAW,
	WATER = WATER,
	METAL = METAL,
	STONE_COLOR = STONE_COLOR,
	part = part,
	slopedRoof = slopedRoof,
	hayBale = hayBale,
	waterTrough = waterTrough,
	feedTrough = feedTrough,
	plant = plant,
	blossomTree = blossomTree,
	rockPile = rockPile,
	THEME_LOOKS = THEME_LOOKS,
	Look = Look,
}
