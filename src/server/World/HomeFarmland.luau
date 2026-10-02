--!strict
-- Ana ada tarım alanları: sebze bahçesi, meyve bahçesi ve arı kovanları.
-- Her yapı yerel çerçevede kurulur: -Z ön (kapı yönü), taban zemin yüzeyindedir.

local WorldDecor = require(script.Parent:WaitForChild("WorldDecor"))
local HomeParts = require(script.Parent:WaitForChild("HomeParts"))

local WOOD = HomeParts.WOOD
local DARK_WOOD = HomeParts.DARK_WOOD
local STRAW = HomeParts.STRAW
local part = HomeParts.part
local ball = HomeParts.ball
local column = HomeParts.column
local model = HomeParts.model

local Farmland = {}

---------------------------------------------------------------------------
-- Sebze bahçesi: çitli, dört sıra ekim (lahana, havuç, mısır, domates)
---------------------------------------------------------------------------

function Farmland.vegetableGarden(parent: Instance, base: CFrame)
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
	-- Alçak çit; ön kenarda geçit boşluğu. Köşede iki çit uç uca gelir: aynı noktaya ikinci direk konmaz (üst üste binip titremesin).
	local placedPosts: { [string]: boolean } = {}
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
			local key = string.format("%.2f,%.2f", p.X, p.Z)
			if placedPosts[key] then
				continue
			end
			placedPosts[key] = true
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

function Farmland.orchard(parent: Instance, base: CFrame)
	local orchard = model(parent, "Orchard")
	local trees: { { at: Vector2, color: Color3 } } = {
		{ at = Vector2.new(0, 0), color = Color3.fromRGB(205, 50, 45) },
		{ at = Vector2.new(7.5, 4), color = Color3.fromRGB(230, 90, 100) },
		{ at = Vector2.new(-1.5, 8.5), color = Color3.fromRGB(205, 50, 45) },
		{ at = Vector2.new(6.5, 12), color = Color3.fromRGB(240, 190, 60) },
	}
	for index, entry in trees do
		fruitTree(orchard, base * CFrame.new(entry.at.X, 0, entry.at.Y), index * 17, entry.color)
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

function Farmland.beehives(parent: Instance, base: CFrame)
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

return Farmland
