--!strict
-- Genel (ana) adanın zenginleştirilmesi: çiftlik evi, yel değirmeni, kuyu, sebze bahçesi, meyve bahçesi,
-- arı kovanları, ambar ve pazar tezgâhı (sipariş panosu). Haritaya kaydedilir (MapBuilder çağırır).
-- Her yapı yerel çerçevede kurulur: -Z ön (kapı yönü), taban zemin yüzeyindedir.
-- Karakterin girebilmesi için kapılar >= 4.6 x 6.6 stud'dur (kümes/ahır ile aynı ölçü kuralı).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Studio harita eklentisi modülleri kopyalayıp çalıştırır; o durumda yanımızdaki "Shared" kullanılır.
local Shared = script.Parent.Parent:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")
local WorldUi = require(Shared:WaitForChild("WorldUi"))
local WorldDecor = require(script.Parent:WaitForChild("WorldDecor"))

local HomeBuildings = {}

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

---------------------------------------------------------------------------
-- Çiftlik evi
---------------------------------------------------------------------------

function HomeBuildings.farmhouse(parent: Instance, base: CFrame)
	local house = model(parent, "Farmhouse")
	local width, depth, wallH = 14, 11, 8
	local doorW, doorH = 5, 7
	part(house, "Floor", Vector3.new(width, 0.6, depth), base * CFrame.new(0, 0.3, 0), WOOD, Enum.Material.WoodPlanks)
	local room = base * CFrame.new(0, 0.6, 0)
	walledRoom(house, room, width, depth, wallH, doorW, doorH, PLASTER, Enum.Material.Plaster)
	-- Taş temel şeridi
	part(
		house,
		"Foundation",
		Vector3.new(width + 0.6, 0.9, depth + 0.6),
		base * CFrame.new(0, 0.05, 0),
		STONE,
		Enum.Material.Cobblestone,
		false
	)
	gableRoof(house, room, width, depth, wallH, ROOF_RED)
	-- Pencereler: yanlarda ve arkada; ön yüzde kapının iki yanında
	for _, x in { -4.8, 4.8 } do
		windowPane(house, room, Vector3.new(2.4, 2.2, 0.2), Vector3.new(x, 4.6, -(depth / 2 - 0.15)))
	end
	for _, side in { -1, 1 } do
		windowPane(house, room, Vector3.new(0.2, 2.2, 2.4), Vector3.new(side * (width / 2 - 0.15), 4.6, 0))
	end
	-- Sundurma: basamak, iki direk ve küçük saçak
	part(
		house,
		"PorchStep",
		Vector3.new(doorW + 1, 0.4, 2),
		base * CFrame.new(0, 0.2, -(depth / 2 + 1)),
		STONE,
		Enum.Material.Cobblestone
	)
	for _, x in { -(doorW / 2 + 0.8), doorW / 2 + 0.8 } do
		part(
			house,
			"PorchPost",
			Vector3.new(0.5, 7.4, 0.5),
			base * CFrame.new(x, 4.3, -(depth / 2 + 1.6)),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end
	part(
		house,
		"PorchRoof",
		Vector3.new(doorW + 3, 0.4, 3),
		base * CFrame.new(0, 8.1, -(depth / 2 + 1.5)),
		ROOF_RED,
		Enum.Material.Slate,
		true
	)
	-- Baca: taş gövde + duman
	local chimney = part(
		house,
		"Chimney",
		Vector3.new(1.8, 4.5, 1.8),
		room * CFrame.new(-width / 2 + 2.5, wallH + 3.4, 2),
		STONE,
		Enum.Material.Brick
	)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, chimney.Size.Y / 2, 0)
	attachment.Parent = chimney
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(200, 200, 205))
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.2) })
	smoke.Lifetime = NumberRange.new(3, 4.5)
	smoke.Rate = 3
	smoke.Speed = NumberRange.new(2, 3)
	smoke.SpreadAngle = Vector2.new(8, 8)
	smoke.Acceleration = Vector3.new(0.6, 0.5, 0)
	smoke.LightEmission = 0
	smoke.Parent = attachment
	-- İçerisi: yatak, masa ve sandalye (girince ev dolu görünsün)
	part(
		house,
		"BedFrame",
		Vector3.new(3.2, 1, 5.6),
		room * CFrame.new(width / 2 - 2.4, 0.5, 1.2),
		WOOD,
		Enum.Material.WoodPlanks
	)
	part(
		house,
		"Blanket",
		Vector3.new(3, 0.5, 3.6),
		room * CFrame.new(width / 2 - 2.4, 1.2, 2),
		Color3.fromRGB(190, 70, 60),
		Enum.Material.Fabric,
		false
	)
	part(
		house,
		"Table",
		Vector3.new(3.4, 0.4, 2.2),
		room * CFrame.new(-2, 2.6, 2.6),
		WOOD,
		Enum.Material.WoodPlanks,
		false
	)
	for _, x in { -3.4, -0.6 } do
		part(
			house,
			"TableLeg",
			Vector3.new(0.4, 2.6, 0.4),
			room * CFrame.new(x, 1.3, 2.6),
			DARK_WOOD,
			Enum.Material.Wood,
			false
		)
	end
	local lamp = ball(
		house,
		"HouseLantern",
		0.8,
		room * CFrame.new(0, wallH - 1.2, 1),
		Color3.fromRGB(205, 175, 115),
		Enum.Material.SmoothPlastic
	)
	lamp:SetAttribute("NightColor", Color3.fromRGB(255, 214, 130))
	CollectionService:AddTag(lamp, "NightLight")
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 205, 130)
	light.Range = 18
	light.Brightness = 1.2
	light.Shadows = false
	light.Enabled = false
	light.Parent = lamp
	WorldDecor.flowerPatch(house, base * CFrame.new(-(doorW / 2 + 3.4), 0, -(depth / 2 + 1.6)), 11)
	WorldDecor.flowerPatch(house, base * CFrame.new(doorW / 2 + 3.4, 0, -(depth / 2 + 1.6)), 12)
end

---------------------------------------------------------------------------
-- Yel değirmeni (kanatlar client'ta döner: Windmill.client)
---------------------------------------------------------------------------

function HomeBuildings.windmill(parent: Instance, base: CFrame)
	local mill = model(parent, "Windmill")
	-- Kule: yukarı daralan üç silindir
	local heights = { 0, 5, 10 }
	local diameters = { 9, 7.6, 6.2 }
	for index, y in heights do
		column(mill, "Tower", diameters[index], 5.2, base * CFrame.new(0, y + 2.6, 0), PLASTER, Enum.Material.Brick)
	end
	column(mill, "TowerBase", 10, 0.8, base * CFrame.new(0, 0.4, 0), STONE, Enum.Material.Cobblestone)
	-- Kapı (girilebilir alan değil, ama işaretli): çerçeve ve koyu ahşap kapı
	part(
		mill,
		"Door",
		Vector3.new(3.2, 5.2, 0.5),
		base * CFrame.new(0, 2.6, -4.3),
		DARK_WOOD,
		Enum.Material.WoodPlanks,
		false
	)
	-- Çatı: üç kademeli kırmızı başlık
	column(mill, "CapLow", 7.4, 1.4, base * CFrame.new(0, 15.7, 0), ROOF_RED, Enum.Material.Slate)
	column(mill, "CapMid", 5.2, 1.4, base * CFrame.new(0, 17, 0), ROOF_RED, Enum.Material.Slate)
	column(mill, "CapTop", 2.6, 1.6, base * CFrame.new(0, 18.3, 0), ROOF_RED, Enum.Material.Slate)
	windowPane(mill, base, Vector3.new(1.6, 2.2, 0.3), Vector3.new(0, 12, -3.3))

	-- Kanatlar: tek Model; merkez (hub) tarafında ve kule önünde döner
	local blades = model(mill, "Blades")
	local hubCf = base * CFrame.new(0, 13.5, -4.6)
	local hub = part(blades, "Hub", Vector3.new(1.4, 1.4, 1.6), hubCf, DARK_WOOD, Enum.Material.Wood, false)
	hub.Shape = Enum.PartType.Ball
	for arm = 0, 3 do
		local armCf = hubCf * CFrame.Angles(0, 0, math.rad(arm * 90 + 45))
		part(blades, "Arm", Vector3.new(0.5, 13, 0.35), armCf, DARK_WOOD, Enum.Material.Wood, false)
		part(
			blades,
			"Sail",
			Vector3.new(2.6, 8, 0.15),
			armCf * CFrame.new(1.7, 2.6, -0.1),
			Color3.fromRGB(240, 232, 210),
			Enum.Material.Fabric,
			false
		)
	end
	blades.PrimaryPart = hub
	blades:SetAttribute("Speed", 0.7)
	CollectionService:AddTag(blades, "Windmill")
	WorldDecor.crate(mill, base * CFrame.new(6.4, 0, -3), 2)
	WorldDecor.barrel(mill, base * CFrame.new(-6.4, 0, -3.2))
end

---------------------------------------------------------------------------
-- Kuyu
---------------------------------------------------------------------------

function HomeBuildings.well(parent: Instance, base: CFrame)
	local well = model(parent, "Well")
	column(well, "Ring", 5, 2.4, base * CFrame.new(0, 1.2, 0), STONE, Enum.Material.Cobblestone)
	local water = column(well, "Water", 3.8, 0.2, base * CFrame.new(0, 2.05, 0), WATER, Enum.Material.Glass, false)
	water.Transparency = 0.25
	for _, side in { -1, 1 } do
		part(well, "Post", Vector3.new(0.5, 6, 0.5), base * CFrame.new(side * 2.3, 3, 0), DARK_WOOD, Enum.Material.Wood)
	end
	part(well, "Beam", Vector3.new(5.4, 0.4, 0.4), base * CFrame.new(0, 5.6, 0), DARK_WOOD, Enum.Material.Wood, false)
	for _, side in { -1, 1 } do
		part(
			well,
			"Roof",
			Vector3.new(3.4, 0.35, 5.4),
			base * CFrame.new(side * 1.5, 6.5, 0) * CFrame.Angles(0, 0, side * math.rad(28)),
			ROOF_RED,
			Enum.Material.WoodPlanks,
			true
		)
	end
	part(
		well,
		"Rope",
		Vector3.new(0.12, 2, 0.12),
		base * CFrame.new(0, 4.4, 0),
		Color3.fromRGB(190, 160, 110),
		Enum.Material.Fabric,
		false
	)
	column(well, "Bucket", 1, 0.9, base * CFrame.new(0, 3.2, 0), WOOD, Enum.Material.WoodPlanks, false)
end

---------------------------------------------------------------------------
-- Sebze bahçesi: çitli, dört sıra ekim (lahana, havuç, mısır, domates)
---------------------------------------------------------------------------

function HomeBuildings.vegetableGarden(parent: Instance, base: CFrame)
	local garden = model(parent, "VegetableGarden")
	local width, depth = 12, 9
	local SOIL = Color3.fromRGB(96, 70, 50)
	part(
		garden,
		"Soil",
		Vector3.new(width, 0.3, depth),
		base * CFrame.new(0, 0.15, 0),
		Color3.fromRGB(110, 82, 58),
		Enum.Material.Ground,
		false
	)
	-- Alçak çit; ön kenarda geçit boşluğu
	local function fence(from: Vector3, to: Vector3)
		local length = (to - from).Magnitude
		local mid = (from + to) / 2
		local rotation = if math.abs(to.X - from.X) > 0.01 then CFrame.new() else CFrame.Angles(0, math.rad(90), 0)
		part(
			garden,
			"FenceRail",
			Vector3.new(length, 0.3, 0.25),
			base * CFrame.new(mid.X, 1.1, mid.Z) * rotation,
			WOOD,
			Enum.Material.Wood
		)
		local posts = math.max(1, math.round(length / 3))
		for index = 0, posts do
			local p = from:Lerp(to, index / posts)
			part(
				garden,
				"FencePost",
				Vector3.new(0.4, 1.7, 0.4),
				base * CFrame.new(p.X, 0.85, p.Z),
				DARK_WOOD,
				Enum.Material.Wood
			)
		end
	end
	local hx, hz = width / 2 + 0.6, depth / 2 + 0.6
	fence(Vector3.new(-hx, 0, hz), Vector3.new(hx, 0, hz))
	fence(Vector3.new(-hx, 0, -hz), Vector3.new(-hx, 0, hz))
	fence(Vector3.new(hx, 0, -hz), Vector3.new(hx, 0, hz))
	fence(Vector3.new(-hx, 0, -hz), Vector3.new(-2.2, 0, -hz))
	fence(Vector3.new(2.2, 0, -hz), Vector3.new(hx, 0, -hz))
	-- Ekim sıraları
	local rows = {
		{ z = -2.8, kind = "cabbage" },
		{ z = -0.9, kind = "carrot" },
		{ z = 1.0, kind = "corn" },
		{ z = 2.9, kind = "tomato" },
	}
	for _, row in rows do
		part(
			garden,
			"Bed",
			Vector3.new(width - 1.4, 0.55, 1.2),
			base * CFrame.new(0, 0.45, row.z),
			SOIL,
			Enum.Material.Ground,
			false
		)
		for slot = 1, 6 do
			local x = -width / 2 + 1.3 + (slot - 1) * 1.9
			local spot = base * CFrame.new(x, 0.7, row.z)
			if row.kind == "cabbage" then
				ball(
					garden,
					"Cabbage",
					1.15,
					spot * CFrame.new(0, 0.4, 0),
					Color3.fromRGB(120, 180, 90),
					Enum.Material.LeafyGrass
				)
			elseif row.kind == "carrot" then
				part(
					garden,
					"CarrotLeaf",
					Vector3.new(0.9, 0.7, 0.9),
					spot * CFrame.new(0, 0.35, 0),
					Color3.fromRGB(80, 160, 70),
					Enum.Material.LeafyGrass,
					false
				)
				part(
					garden,
					"Carrot",
					Vector3.new(0.3, 0.4, 0.3),
					spot * CFrame.new(0, 0.05, 0.35),
					Color3.fromRGB(240, 130, 40),
					Enum.Material.SmoothPlastic,
					false
				)
			elseif row.kind == "corn" then
				part(
					garden,
					"CornStalk",
					Vector3.new(0.3, 2.8, 0.3),
					spot * CFrame.new(0, 1.4, 0),
					Color3.fromRGB(110, 160, 60),
					Enum.Material.Grass,
					false
				)
				part(
					garden,
					"CornCob",
					Vector3.new(0.45, 0.9, 0.45),
					spot * CFrame.new(0.3, 1.5, 0),
					Color3.fromRGB(240, 210, 80),
					Enum.Material.SmoothPlastic,
					false
				)
			else
				part(
					garden,
					"TomatoStake",
					Vector3.new(0.2, 2, 0.2),
					spot * CFrame.new(0, 1, 0),
					WOOD,
					Enum.Material.Wood,
					false
				)
				for tomato = 1, 3 do
					ball(
						garden,
						"Tomato",
						0.5,
						spot * CFrame.new(0.25, 0.6 + tomato * 0.45, (tomato - 2) * 0.2),
						Color3.fromRGB(210, 55, 50),
						Enum.Material.SmoothPlastic
					)
				end
			end
		end
	end
	part(
		garden,
		"Scarecrow",
		Vector3.new(0.3, 4.2, 0.3),
		base * CFrame.new(-4.6, 2.1, 2.9),
		DARK_WOOD,
		Enum.Material.Wood,
		false
	)
	part(
		garden,
		"ScarecrowArms",
		Vector3.new(3, 0.3, 0.3),
		base * CFrame.new(-4.6, 3.3, 2.9),
		DARK_WOOD,
		Enum.Material.Wood,
		false
	)
	ball(garden, "ScarecrowHead", 1.1, base * CFrame.new(-4.6, 4.5, 2.9), STRAW, Enum.Material.Fabric)
	part(
		garden,
		"ScarecrowHat",
		Vector3.new(1.6, 0.25, 1.6),
		base * CFrame.new(-4.6, 5, 2.9),
		Color3.fromRGB(150, 110, 70),
		Enum.Material.Fabric,
		false
	)
end

---------------------------------------------------------------------------
-- Meyve bahçesi: elma ve kiraz ağaçları
---------------------------------------------------------------------------

local function fruitTree(parent: Instance, base: CFrame, seed: number, fruitColor: Color3)
	local random = Random.new(seed)
	local tree = model(parent, "FruitTree")
	local bark = Color3.fromRGB(100, 70, 45)
	column(tree, "Trunk", 1.6, 6, base * CFrame.new(0, 3, 0), bark, Enum.Material.Wood)
	local leaf = Color3.fromRGB(80, 150, 65)
	for index = 1, 4 do
		local angle = index / 4 * math.pi * 2 + random:NextNumber(-0.3, 0.3)
		local crown = ball(
			tree,
			"Leaves",
			random:NextNumber(4.6, 6),
			base * CFrame.new(math.cos(angle) * 1.6, 7.6 + random:NextNumber(-0.6, 0.8), math.sin(angle) * 1.6),
			leaf:Lerp(Color3.fromRGB(110, 170, 70), random:NextNumber(0, 0.5)),
			Enum.Material.LeafyGrass
		)
		crown.CanCollide = false
	end
	ball(tree, "Leaves", 5.4, base * CFrame.new(0, 9, 0), leaf, Enum.Material.LeafyGrass).CanCollide = false
	for _ = 1, 9 do
		local angle = random:NextNumber(0, math.pi * 2)
		local radius = random:NextNumber(2.2, 3.4)
		ball(
			tree,
			"Fruit",
			0.55,
			base * CFrame.new(math.cos(angle) * radius, random:NextNumber(6.4, 9.6), math.sin(angle) * radius),
			fruitColor,
			Enum.Material.SmoothPlastic
		)
	end
end

function HomeBuildings.orchard(parent: Instance, base: CFrame)
	local orchard = model(parent, "Orchard")
	local trees = {
		{ Vector2.new(0, 0), Color3.fromRGB(205, 50, 45) },
		{ Vector2.new(7.5, 4), Color3.fromRGB(230, 90, 100) },
		{ Vector2.new(-1.5, 8.5), Color3.fromRGB(205, 50, 45) },
		{ Vector2.new(6.5, 12), Color3.fromRGB(240, 190, 60) },
	}
	for index, entry in trees do
		fruitTree(orchard, base * CFrame.new(entry[1].X, 0, entry[1].Y), index * 17, entry[2])
	end
	-- Toplama sepeti ve düşmüş meyveler
	part(orchard, "Basket", Vector3.new(2, 1.2, 1.6), base * CFrame.new(3.6, 0.6, 2), WOOD, Enum.Material.WoodPlanks)
	for index = 1, 4 do
		ball(
			orchard,
			"BasketFruit",
			0.6,
			base * CFrame.new(3 + index * 0.35, 1.3, 2 + (index % 2) * 0.3),
			Color3.fromRGB(205, 50, 45),
			Enum.Material.SmoothPlastic
		)
	end
end

---------------------------------------------------------------------------
-- Arı kovanları
---------------------------------------------------------------------------

function HomeBuildings.beehives(parent: Instance, base: CFrame)
	local hives = model(parent, "Beehives")
	local spots = { Vector2.new(-3, 0), Vector2.new(0.5, -1), Vector2.new(4, 0.4) }
	for index, spot in spots do
		local frame = base * CFrame.new(spot.X, 0, spot.Y) * CFrame.Angles(0, math.rad((index - 2) * 12), 0)
		for _, x in { -0.9, 0.9 } do
			part(hives, "Leg", Vector3.new(0.3, 1.2, 0.3), frame * CFrame.new(x, 0.6, 0), DARK_WOOD, Enum.Material.Wood)
		end
		for level = 1, 3 do
			part(
				hives,
				"HiveBox",
				Vector3.new(2.2, 0.8, 1.8),
				frame * CFrame.new(0, 1.2 + (level - 0.5) * 0.85, 0),
				if level % 2 == 0 then STRAW else Color3.fromRGB(240, 208, 110),
				Enum.Material.WoodPlanks
			)
		end
		part(
			hives,
			"HiveRoof",
			Vector3.new(2.6, 0.3, 2.2),
			frame * CFrame.new(0, 4.15, 0),
			WOOD,
			Enum.Material.WoodPlanks
		)
		part(
			hives,
			"Entrance",
			Vector3.new(0.9, 0.18, 0.2),
			frame * CFrame.new(0, 1.55, -0.95),
			Color3.fromRGB(40, 30, 20),
			Enum.Material.SmoothPlastic,
			false
		)
	end
	WorldDecor.flowerPatch(hives, base * CFrame.new(-2, 0, -4), 21)
	WorldDecor.flowerPatch(hives, base * CFrame.new(3, 0, -4.5), 22)
end

---------------------------------------------------------------------------
-- Ambar
---------------------------------------------------------------------------

function HomeBuildings.granary(parent: Instance, base: CFrame)
	local granary = model(parent, "Granary")
	local width, depth, wallH = 11, 9, 8
	part(granary, "Floor", Vector3.new(width, 0.6, depth), base * CFrame.new(0, 0.3, 0), WOOD, Enum.Material.WoodPlanks)
	local room = base * CFrame.new(0, 0.6, 0)
	walledRoom(granary, room, width, depth, wallH, 5.2, 6.8, WOOD, Enum.Material.WoodPlanks)
	gableRoof(granary, room, width, depth, wallH, Color3.fromRGB(110, 70, 55))
	part(
		granary,
		"PorchStep",
		Vector3.new(6, 0.4, 1.8),
		base * CFrame.new(0, 0.2, -(depth / 2 + 0.9)),
		STONE,
		Enum.Material.Cobblestone
	)
	-- İçeride çuvallar ve saman
	for index = 1, 5 do
		part(
			granary,
			"Sack",
			Vector3.new(1.6, 1.8, 1.2),
			room
				* CFrame.new(
					-width / 2 + 1.5 + (index % 3) * 1.6,
					0.9 + math.floor(index / 4) * 1.8,
					depth / 2 - 1.6 - math.floor(index / 3)
				),
			Color3.fromRGB(215, 195, 150),
			Enum.Material.Fabric,
			false
		)
	end
	for index = 1, 3 do
		part(
			granary,
			"Hay",
			Vector3.new(2.6, 1.6, 1.6),
			room
				* CFrame.new(
					width / 2 - 2.2,
					0.8 + (index - 1) * 1.6 * (if index > 2 then 1 else 0),
					depth / 2 - 1.5 - (index % 2) * 1.8
				),
			STRAW,
			Enum.Material.Fabric,
			false
		)
	end
	windowPane(granary, room, Vector3.new(2, 1.6, 0.2), Vector3.new(0, 5.6, depth / 2 - 0.15))
	WorldDecor.barrel(granary, base * CFrame.new(-(width / 2 + 1.4), 0, -depth / 2 + 1))
	WorldDecor.crate(granary, base * CFrame.new(width / 2 + 1.4, 0, -depth / 2 + 1), 1.8)
end

---------------------------------------------------------------------------
-- Pazar tezgâhı: sipariş panosuna erişim (MarketPrompt; client Çiftliğim penceresini açar)
---------------------------------------------------------------------------

function HomeBuildings.market(parent: Instance, base: CFrame)
	local stall = model(parent, "MarketStall")
	part(stall, "Counter", Vector3.new(9, 2.4, 2.6), base * CFrame.new(0, 1.2, 0), WOOD, Enum.Material.WoodPlanks)
	part(
		stall,
		"CounterTop",
		Vector3.new(9.4, 0.3, 3),
		base * CFrame.new(0, 2.55, -0.1),
		DARK_WOOD,
		Enum.Material.WoodPlanks,
		false
	)
	for _, x in { -4.4, 4.4 } do
		part(stall, "Post", Vector3.new(0.5, 7, 0.5), base * CFrame.new(x, 3.5, 1.5), DARK_WOOD, Enum.Material.Wood)
		part(
			stall,
			"FrontPost",
			Vector3.new(0.5, 6.4, 0.5),
			base * CFrame.new(x, 3.2, -1.6),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end
	-- Çizgili tente: kırmızı ve krem şeritler öne doğru eğimli
	for index = 1, 6 do
		part(
			stall,
			"Awning",
			Vector3.new(1.55, 0.25, 4.6),
			base * CFrame.new(-3.9 + (index - 1) * 1.56, 6.7, -0.1) * CFrame.Angles(math.rad(-12), 0, 0),
			if index % 2 == 0 then CREAM else Color3.fromRGB(190, 60, 55),
			Enum.Material.Fabric,
			false
		)
	end
	-- Tezgâhta ürünler
	local produce = {
		{ Color3.fromRGB(210, 55, 50), -3.2 },
		{ Color3.fromRGB(240, 190, 60), -1.6 },
		{ Color3.fromRGB(120, 180, 90), 0 },
		{ Color3.fromRGB(240, 130, 40), 1.6 },
		{ Color3.fromRGB(150, 90, 170), 3.2 },
	}
	for _, entry in produce do
		part(
			stall,
			"Crate",
			Vector3.new(1.3, 0.6, 1.3),
			base * CFrame.new(entry[2], 2.95, -0.2),
			WOOD,
			Enum.Material.WoodPlanks,
			false
		)
		for fruit = 1, 3 do
			ball(
				stall,
				"Produce",
				0.55,
				base * CFrame.new(entry[2] + (fruit - 2) * 0.3, 3.45, -0.2 + (fruit % 2) * 0.2),
				entry[1],
				Enum.Material.SmoothPlastic
			)
		end
	end
	-- Tabela: sipariş panosu
	local board = part(
		stall,
		"MarketSign",
		Vector3.new(6.2, 1.6, 0.3),
		base * CFrame.new(0, 5.6, -2.3),
		DARK_WOOD,
		Enum.Material.WoodPlanks,
		false
	)
	WorldUi.sign(board, Enum.NormalId.Front, { icon = "📋", title = "Pazar", text = "Sipariş panosu" })
	-- Etkileşim: tezgâhın önünde, tabelayı kapatmayan alçak nokta
	local anchor = part(
		stall,
		"MarketPromptAnchor",
		Vector3.one,
		base * CFrame.new(0, 2, -3.2),
		WOOD,
		Enum.Material.SmoothPlastic,
		false
	)
	anchor.Transparency = 1
	anchor.CanQuery = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MarketPrompt"
	prompt.ActionText = "Sipariş panosu"
	prompt.ObjectText = "Pazar"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Locked", true) -- IslandPrompts: yalnızca sahibine görünür
	prompt.Parent = anchor
end

return HomeBuildings
