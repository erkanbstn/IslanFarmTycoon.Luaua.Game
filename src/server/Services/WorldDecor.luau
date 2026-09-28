--!strict
-- Doğal görünüm: Terrain ile kıyı (su altı kayalık, kum plaj, kıyı kayaları) ve detaylı süs eşyaları
-- (ağaç çeşitleri, çalı, çiçek, fener, fıçı, sandık, posta kutusu, iskele).
-- MapBuilder bunları çağırır; PlotService kilitli uzman adaların zeminini buradan değiştirir.
--
-- Not: Ada ÜSTÜ Terrain değil, düz bir parçadır (MapBuilder). Terrain yüzeyi 4 stud'luk ızgaraya
-- oturduğu için hesaplanandan 1-2 stud yukarıda çıkıp yerdeki ince parçaları (yol, platform, ağıl
-- zemini) gömüyordu. Kum, üst parçanın altında kalacak şekilde alçak tutulur.

local Workspace = game:GetService("Workspace")

local WorldDecor = {}

local function terrain(): Terrain
	return Workspace.Terrain
end

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

---------------------------------------------------------------------------
-- Terrain
---------------------------------------------------------------------------

-- Ada kıyısı: kum plaj PARÇA halkası (çimenin 1 stud altında) + su altında Terrain kayalık gövde.
-- Terrain yüzeyi 4 stud'luk ızgarada öngörülemez şekilde yukarı yuvarlandığı için ada yüzeyine yakın
-- hiçbir yerde Terrain kullanılmaz; kayalık gövdenin üstü suyun iyice altındadır.
function WorldDecor.terrainIsland(parent: Instance, center: Vector3, radius: number, surfaceY: number, beach: number)
	local base = Vector3.new(center.X, 0, center.Z)
	terrain():FillCylinder(CFrame.new(base + Vector3.new(0, -14, 0)), 16, radius + beach - 1, Enum.Material.Rock)

	local sandTop = surfaceY - 1
	local sandBottom = -2
	column(
		parent,
		"Beach",
		(radius + beach) * 2,
		sandTop - sandBottom,
		CFrame.new(base + Vector3.new(0, (sandTop + sandBottom) / 2, 0)),
		Color3.fromRGB(226, 208, 158),
		Enum.Material.Sand
	)
end

-- Kıyıya yarı gömülü kayalar. angles: adanın yerel açıları (derece, 0 = +Z)
function WorldDecor.shoreRocks(islandCf: CFrame, radius: number, angles: { number }, seed: number)
	local random = Random.new(seed)
	for _, angle in angles do
		local a = math.rad(angle)
		local distance = radius + random:NextNumber(1, 5)
		local position = (islandCf * CFrame.new(math.sin(a) * distance, 0, math.cos(a) * distance)).Position
		terrain():FillBall(position, random:NextNumber(3, 4.5), Enum.Material.Rock)
	end
end

-- Taş yol: zeminin hemen üstünde ince parça. Kesişen yollar aynı yükseklikte olursa titrer (z-fighting),
-- bu yüzden her yol bir öncekinden birkaç milim yüksek.
local pathLayer = 0
function WorldDecor.path(parent: Instance, from: Vector3, to: Vector3, width: number)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	if length < 0.1 then
		return
	end
	pathLayer = (pathLayer + 1) % 6
	local y = from.Y + 0.08 + pathLayer * 0.03
	local a = Vector3.new(from.X, y, from.Z)
	local cf = CFrame.lookAt(a + flat / 2, a + flat)
	local p = part(
		parent,
		"Path",
		Vector3.new(width, 0.16, length + width * 0.6),
		cf,
		Color3.fromRGB(150, 145, 135),
		Enum.Material.Cobblestone
	)
	p.CastShadow = false
end

---------------------------------------------------------------------------
-- Bitki örtüsü
---------------------------------------------------------------------------

local LEAF_COLORS = {
	Color3.fromRGB(70, 140, 60),
	Color3.fromRGB(85, 155, 65),
	Color3.fromRGB(60, 125, 55),
	Color3.fromRGB(100, 160, 70),
}

-- Yuvarlak taçlı ağaç: gövde + dal + birkaç farklı tonda yaprak kümesi
function WorldDecor.oakTree(parent: Instance, base: CFrame, seed: number)
	local random = Random.new(seed)
	local scale = random:NextNumber(0.85, 1.2)
	local model = Instance.new("Model")
	model.Name = "OakTree"
	model.Parent = parent

	local bark = Color3.fromRGB(100, 70, 45)
	column(model, "Trunk", 1.8 * scale, 8 * scale, base * CFrame.new(0, 4 * scale, 0), bark, Enum.Material.Wood)
	part(
		model,
		"Branch",
		Vector3.new(0.7, 3.5, 0.7) * scale,
		base * CFrame.new(1 * scale, 6.5 * scale, 0) * CFrame.Angles(0, 0, math.rad(-40)),
		bark,
		Enum.Material.Wood
	)
	local crown = {
		{ Vector3.new(0, 10, 0), 8 },
		{ Vector3.new(2.6, 9, 1.2), 6 },
		{ Vector3.new(-2.4, 9.2, -1), 6.2 },
		{ Vector3.new(0.6, 12, -1.6), 5.5 },
		{ Vector3.new(-1, 8.6, 2.6), 5 },
	}
	for i, leaf in crown do
		local offset = leaf[1] :: Vector3
		local size = leaf[2] :: number
		local p = ball(
			model,
			"Leaves",
			size * scale,
			base * CFrame.new(offset * scale),
			LEAF_COLORS[(i + seed) % #LEAF_COLORS + 1],
			Enum.Material.LeafyGrass
		)
		p.CanCollide = false
	end
end

-- Çam: ince uzun gövde + yukarı doğru küçülen koyu yaprak katmanları
function WorldDecor.pineTree(parent: Instance, base: CFrame, seed: number)
	local random = Random.new(seed)
	local scale = random:NextNumber(0.9, 1.25)
	local model = Instance.new("Model")
	model.Name = "PineTree"
	model.Parent = parent

	column(
		model,
		"Trunk",
		1.2 * scale,
		11 * scale,
		base * CFrame.new(0, 5.5 * scale, 0),
		Color3.fromRGB(90, 60, 40),
		Enum.Material.Wood
	)
	-- Aşağıdan yukarı daralan yassı katmanlar (koni silueti)
	local layers = { { 4, 8.5 }, { 6.4, 7 }, { 8.6, 5.4 }, { 10.6, 3.8 }, { 12.3, 2.2 } }
	for index, layer in layers do
		local p = part(
			model,
			"Needles",
			Vector3.new(layer[2], 2.4, layer[2]) * scale,
			base * CFrame.new(0, layer[1] * scale, 0),
			if index % 2 == 0 then Color3.fromRGB(45, 100, 60) else Color3.fromRGB(38, 88, 52),
			Enum.Material.LeafyGrass
		)
		p.CanCollide = false
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
end

function WorldDecor.bush(parent: Instance, base: CFrame, seed: number)
	local random = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "Bush"
	model.Parent = parent
	for i = 1, 3 do
		local size = random:NextNumber(2.2, 3.4)
		local p = ball(
			model,
			"Leaves",
			size,
			base * CFrame.new(random:NextNumber(-1.2, 1.2), size * 0.35, random:NextNumber(-1.2, 1.2)),
			LEAF_COLORS[(i + seed) % #LEAF_COLORS + 1],
			Enum.Material.LeafyGrass
		)
		p.CanCollide = false
	end
	-- Bazı çalılarda küçük çiçekler/meyveler
	if seed % 2 == 0 then
		for _ = 1, 4 do
			local p = ball(
				model,
				"Berry",
				0.45,
				base * CFrame.new(random:NextNumber(-1.4, 1.4), random:NextNumber(1, 2), random:NextNumber(-1.4, 1.4)),
				Color3.fromRGB(220, 60, 70),
				Enum.Material.SmoothPlastic
			)
			p.CanCollide = false
		end
	end
end

local FLOWER_COLORS = {
	Color3.fromRGB(250, 220, 80),
	Color3.fromRGB(240, 120, 160),
	Color3.fromRGB(250, 250, 250),
	Color3.fromRGB(170, 120, 230),
	Color3.fromRGB(245, 140, 60),
}

-- Küçük çiçek tarhı: saplı, renkli çiçekler
function WorldDecor.flowerPatch(parent: Instance, base: CFrame, seed: number)
	local random = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "Flowers"
	model.Parent = parent
	local color = FLOWER_COLORS[seed % #FLOWER_COLORS + 1]
	for _ = 1, 7 do
		local offset = CFrame.new(random:NextNumber(-2, 2), 0, random:NextNumber(-2, 2))
		local height = random:NextNumber(0.6, 1.1)
		local stem = part(
			model,
			"Stem",
			Vector3.new(0.12, height, 0.12),
			base * offset * CFrame.new(0, height / 2, 0),
			Color3.fromRGB(70, 130, 60),
			Enum.Material.SmoothPlastic
		)
		stem.CanCollide = false
		local bloom =
			ball(model, "Bloom", 0.45, base * offset * CFrame.new(0, height, 0), color, Enum.Material.SmoothPlastic)
		bloom.CanCollide = false
	end
end

---------------------------------------------------------------------------
-- Çiftlik eşyaları
---------------------------------------------------------------------------

function WorldDecor.lamp(parent: Instance, base: CFrame)
	local model = Instance.new("Model")
	model.Name = "Lamp"
	model.Parent = parent
	local iron = Color3.fromRGB(45, 45, 50)
	column(model, "Pole", 0.45, 6, base * CFrame.new(0, 3, 0), iron, Enum.Material.Metal)
	part(model, "Arm", Vector3.new(1.4, 0.2, 0.2), base * CFrame.new(0.6, 5.9, 0), iron, Enum.Material.Metal)
	local lantern = part(
		model,
		"Lantern",
		Vector3.new(0.7, 0.9, 0.7),
		base * CFrame.new(1.2, 5.3, 0),
		Color3.fromRGB(255, 210, 120),
		Enum.Material.Neon
	)
	part(model, "Cap", Vector3.new(0.9, 0.2, 0.9), base * CFrame.new(1.2, 5.85, 0), iron, Enum.Material.Metal)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 120)
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = lantern
end

function WorldDecor.barrel(parent: Instance, base: CFrame)
	local model = Instance.new("Model")
	model.Name = "Barrel"
	model.Parent = parent
	column(model, "Body", 2, 2.6, base * CFrame.new(0, 1.3, 0), Color3.fromRGB(135, 90, 55), Enum.Material.WoodPlanks)
	for _, y in { 0.5, 2.1 } do
		column(model, "Hoop", 2.1, 0.2, base * CFrame.new(0, y, 0), Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
	end
end

function WorldDecor.crate(parent: Instance, base: CFrame, size: number)
	local model = Instance.new("Model")
	model.Name = "Crate"
	model.Parent = parent
	part(
		model,
		"Box",
		Vector3.one * size,
		base * CFrame.new(0, size / 2, 0),
		Color3.fromRGB(170, 125, 75),
		Enum.Material.WoodPlanks
	)
	-- Köşe çıtaları
	for _, x in { -1, 1 } do
		part(
			model,
			"Slat",
			Vector3.new(0.2, size + 0.05, 0.2),
			base * CFrame.new(x * (size / 2 - 0.05), size / 2, -(size / 2 - 0.05)),
			Color3.fromRGB(120, 85, 50),
			Enum.Material.Wood
		)
	end
end

function WorldDecor.mailbox(parent: Instance, base: CFrame)
	local model = Instance.new("Model")
	model.Name = "Mailbox"
	model.Parent = parent
	part(
		model,
		"Post",
		Vector3.new(0.4, 3.2, 0.4),
		base * CFrame.new(0, 1.6, 0),
		Color3.fromRGB(110, 80, 50),
		Enum.Material.Wood
	)
	part(
		model,
		"Box",
		Vector3.new(1, 0.9, 1.6),
		base * CFrame.new(0, 3.5, 0),
		Color3.fromRGB(200, 60, 55),
		Enum.Material.Metal
	)
	part(
		model,
		"Flag",
		Vector3.new(0.1, 0.8, 0.3),
		base * CFrame.new(0.55, 3.8, 0.3),
		Color3.fromRGB(250, 220, 80),
		Enum.Material.SmoothPlastic
	)
end

-- Kazık üstü tahtanın içinde, altı deniz tabanının içinde kalır; su altında havada bitmez.
function WorldDecor.pierPile(parent: Instance, position: Vector3, surfaceY: number, seabedY: number): Part
	local top, bottom = surfaceY - 0.3, seabedY - 0.5
	assert(top > bottom, "İskele tabanı yürüyüş yüzeyinden aşağıda olmalı.")
	local pile = column(
		parent,
		"Pile",
		0.7,
		top - bottom,
		CFrame.new(position.X, (top + bottom) / 2, position.Z),
		Color3.fromRGB(95, 70, 50),
		Enum.Material.Wood
	)
	pile:SetAttribute("SeabedY", seabedY)
	return pile
end

-- Adanın kenarından denize uzanan iskele (kazıklar + tahta + fıçı ve olta).
-- surfaceY yürünebilir üst yüzeydir, parçanın merkezi değil.
function WorldDecor.dock(parent: Instance, start: CFrame, length: number, surfaceY: number, seabedY: number)
	local model = Instance.new("Model")
	model.Name = "Dock"
	model.Parent = parent
	local wood = Color3.fromRGB(125, 90, 60)
	local deckY = surfaceY - 0.3
	local deckCf = start * CFrame.new(0, 0, -length / 2)
	local deck = part(
		model,
		"Deck",
		Vector3.new(6, 0.6, length),
		CFrame.new(deckCf.Position.X, deckY, deckCf.Position.Z) * deckCf.Rotation,
		wood,
		Enum.Material.WoodPlanks
	)
	deck:SetAttribute("WalkSurfaceY", surfaceY)
	local segments = math.max(1, math.ceil(length / 5))
	for i = 0, segments do
		for _, x in { -2.6, 2.6 } do
			local z = -(0.8 + (length - 1.6) * i / segments)
			local pos = (start * CFrame.new(x, 0, z)).Position
			WorldDecor.pierPile(model, pos, surfaceY, seabedY)
		end
	end
	local tip = start * CFrame.new(0, 0, -length + 2)
	WorldDecor.barrel(
		model,
		CFrame.new(tip.Position.X, deckY + 0.3, tip.Position.Z) * tip.Rotation * CFrame.new(-1.8, 0, 0)
	)
	-- Olta
	part(
		model,
		"FishingRod",
		Vector3.new(0.15, 0.15, 6),
		CFrame.new(tip.Position.X, deckY + 1.6, tip.Position.Z)
			* tip.Rotation
			* CFrame.new(1.8, 0, -2)
			* CFrame.Angles(math.rad(25), 0, 0),
		Color3.fromRGB(80, 60, 40),
		Enum.Material.Wood
	)
end

return WorldDecor
