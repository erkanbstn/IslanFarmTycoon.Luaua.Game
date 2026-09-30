--!strict
-- Ana ada yapıları: çiftlik evi, yel değirmeni, kuyu ve ambar.
-- Her yapı yerel çerçevede kurulur: -Z ön (kapı yönü), taban zemin yüzeyindedir.

local CollectionService = game:GetService("CollectionService")
local WorldDecor = require(script.Parent:WaitForChild("WorldDecor"))
local HomeParts = require(script.Parent:WaitForChild("HomeParts"))

local WOOD = HomeParts.WOOD
local DARK_WOOD = HomeParts.DARK_WOOD
local PLASTER = HomeParts.PLASTER
local ROOF_RED = HomeParts.ROOF_RED
local STONE = HomeParts.STONE
local STRAW = HomeParts.STRAW
local WATER = HomeParts.WATER
local part = HomeParts.part
local ball = HomeParts.ball
local column = HomeParts.column
local model = HomeParts.model
local gableRoof = HomeParts.gableRoof
local walledRoom = HomeParts.walledRoom
local windowPane = HomeParts.windowPane

local Houses = {}

---------------------------------------------------------------------------
-- Çiftlik evi
---------------------------------------------------------------------------

function Houses.farmhouse(parent: Instance, base: CFrame)
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

function Houses.windmill(parent: Instance, base: CFrame)
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
	-- İki tam boy kol çapraz durur (arka arkaya, aynı düzlemde değil: titreme olmasın); yelkenler yalnızca kolların dış
	-- uçlarında durur ve birbirine girmez.
	for arm = 0, 1 do
		local armCf = hubCf * CFrame.Angles(0, 0, math.rad(45 + arm * 90)) * CFrame.new(0, 0, arm * 0.4)
		part(blades, "Arm", Vector3.new(0.5, 13, 0.35), armCf, DARK_WOOD, Enum.Material.Wood, false)
	end
	for sail = 0, 3 do
		local sailCf = hubCf * CFrame.Angles(0, 0, math.rad(45 + sail * 90))
		part(
			blades,
			"Sail",
			Vector3.new(2.6, 5.2, 0.15),
			sailCf * CFrame.new(1.6, 3.9, -0.45),
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

function Houses.well(parent: Instance, base: CFrame)
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
-- Ambar
---------------------------------------------------------------------------

function Houses.granary(parent: Instance, base: CFrame)
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

return Houses
