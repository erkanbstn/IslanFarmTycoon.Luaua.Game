--!strict
-- Kümes, gölet ve balık kafesi.
-- Her bölge `function(decor, o, size)`: decor içine yapıları kurar (o = bölge zemininin merkez CFrame'i).

local WorldDecor = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("WorldDecor"))
local ZoneParts = require(script.Parent:WaitForChild("ZoneParts"))

type Builder = ZoneParts.Builder
local WOOD = ZoneParts.WOOD
local DARK_WOOD = ZoneParts.DARK_WOOD
local STRAW = ZoneParts.STRAW
local STONE_COLOR = ZoneParts.STONE_COLOR
local part = ZoneParts.part
local slopedRoof = ZoneParts.slopedRoof
local waterTrough = ZoneParts.waterTrough
local feedTrough = ZoneParts.feedTrough

local builders: { [string]: Builder } = {
	-- Kümes: içine girilebilen, basamaklı kümes evi; içinde tünek ve folluklar
	poultry = function(decor, o, size)
		local hx, hz = size.X / 2, size.Z / 2
		local coop = o * CFrame.new(-(hx - 6.5), 0, hz - 4.6)
		local wall = Color3.fromRGB(235, 205, 145)
		local floorTop, wallH = 1.4, 8
		local doorW, doorH = 4.6, 6.6
		for _, x in { -4.4, 0, 4.4 } do
			for _, z in { -3.4, 3.4 } do
				part(decor, "Stilt", Vector3.new(0.6, 1, 0.6), coop * CFrame.new(x, 0.5, z), DARK_WOOD)
			end
		end
		part(
			decor,
			"CoopFloor",
			Vector3.new(10, 0.4, 8),
			coop * CFrame.new(0, floorTop - 0.2, 0),
			WOOD,
			Enum.Material.WoodPlanks
		)
		local wallY = floorTop + wallH / 2
		part(
			decor,
			"CoopBack",
			Vector3.new(10, wallH, 0.4),
			coop * CFrame.new(0, wallY, 3.8),
			wall,
			Enum.Material.WoodPlanks
		)
		for _, x in { -1, 1 } do
			part(
				decor,
				"CoopSide",
				Vector3.new(0.4, wallH, 8),
				coop * CFrame.new(x * 4.8, wallY, 0),
				wall,
				Enum.Material.WoodPlanks
			)
			local frontW = (10 - doorW) / 2
			part(
				decor,
				"CoopFront",
				Vector3.new(frontW, wallH, 0.4),
				coop * CFrame.new(x * (doorW / 2 + frontW / 2), wallY, -3.8),
				wall,
				Enum.Material.WoodPlanks
			)
		end
		part(
			decor,
			"CoopHeader",
			Vector3.new(doorW, wallH - doorH, 0.4),
			coop * CFrame.new(0, floorTop + doorH + (wallH - doorH) / 2, -3.8),
			wall,
			Enum.Material.WoodPlanks
		)
		slopedRoof(decor, coop, 11, -4.6, 4.6, floorTop + wallH + 0.4, floorTop + wallH + 2)
		WorldDecor.markNightWindow(
			part(
				decor,
				"Window",
				Vector3.new(2.4, 1.8, 0.1),
				coop * CFrame.new(-2.6, floorTop + 5.2, 3.55),
				Color3.fromRGB(120, 180, 220),
				Enum.Material.Glass
			)
		)
		-- Kapıya üç basamak (yerden zemine)
		for i = 1, 3 do
			part(
				decor,
				"CoopStep",
				Vector3.new(doorW, floorTop * i / 3, 1.2),
				coop * CFrame.new(0, floorTop * i / 3 / 2, -4.6 - (3 - i) * 1.2),
				WOOD,
				Enum.Material.WoodPlanks
			)
		end
		-- İçeride tünek ve folluklar
		part(decor, "Perch", Vector3.new(8, 0.3, 0.3), coop * CFrame.new(0, floorTop + 2.2, 2.4), DARK_WOOD).CanCollide =
			false
		for i = -1, 1 do
			local nest = coop * CFrame.new(i * 2.8, floorTop, 3)
			part(decor, "NestBox", Vector3.new(2, 1.2, 1.6), nest * CFrame.new(0, 0.6, 0), WOOD)
			part(decor, "Nest", Vector3.new(1.6, 0.1, 1.2), nest * CFrame.new(0, 1.25, 0), STRAW, Enum.Material.Fabric).CanCollide =
				false
		end
		feedTrough(decor, o * CFrame.new(4, 0, -(hz - 4)), 5)
		waterTrough(decor, o * CFrame.new(9, 0, -(hz - 4)), 3)
	end,

	-- Ördek gölü: zemin su gibi mavi; nilüfer, kamış, tahta iskele ve arkada yürünebilir ördek evi
	pond = function(decor, o, size)
		local hx, hz = size.X / 2, size.Z / 2
		local reed = Color3.fromRGB(96, 150, 64)
		-- Nilüferler ve pembe çiçekler
		for index, spot in
			{
				Vector2.new(-8, -5),
				Vector2.new(6, -8),
				Vector2.new(9, -1),
				Vector2.new(-4, 0),
				Vector2.new(-11, 1),
				Vector2.new(2, -3),
			}
		do
			local pad = part(
				decor,
				"LilyPad",
				Vector3.new(0.12, 2.2, 2.2),
				o * CFrame.new(spot.X, 0.12, spot.Y) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(70, 150, 70),
				Enum.Material.LeafyGrass
			)
			pad.Shape = Enum.PartType.Cylinder
			pad.CanCollide = false
			if index % 2 == 0 then
				local flower = part(
					decor,
					"Lotus",
					Vector3.new(0.7, 0.7, 0.7),
					o * CFrame.new(spot.X, 0.5, spot.Y),
					Color3.fromRGB(245, 150, 190),
					Enum.Material.SmoothPlastic
				)
				flower.Shape = Enum.PartType.Ball
				flower.CanCollide = false
			end
		end
		-- Kamış demetleri iki kenarda
		for _, x in { -(hx - 1.6), hx - 1.6 } do
			for index = 1, 5 do
				local z = -hz + 3 + index * 3.4
				for blade = 1, 3 do
					local stalk = part(
						decor,
						"Reed",
						Vector3.new(0.18, 3 + blade * 0.5, 0.18),
						o * CFrame.new(x + (blade - 2) * 0.35, (3 + blade * 0.5) / 2, z + (blade - 2) * 0.3),
						reed,
						Enum.Material.Grass
					)
					stalk.CanCollide = false
				end
			end
		end
		-- Tahta iskele: arka kıyıdan suya
		part(decor, "Pier", Vector3.new(5, 0.35, 8), o * CFrame.new(-6, 0.22, hz - 6.2), WOOD, Enum.Material.WoodPlanks)
		for _, x in { -8.2, -3.8 } do
			for _, z in { hz - 9.6, hz - 2.6 } do
				part(decor, "PierPost", Vector3.new(0.5, 1.4, 0.5), o * CFrame.new(x, 0.5, z), DARK_WOOD)
			end
		end
		-- Ördek evi: içine girilebilen ahşap kulübe
		local house = o * CFrame.new(7, 0, hz - 4)
		part(
			decor,
			"DuckHouseFloor",
			Vector3.new(8, 0.5, 6.4),
			house * CFrame.new(0, 0.25, 0),
			WOOD,
			Enum.Material.WoodPlanks
		)
		local wall = Color3.fromRGB(96, 158, 184)
		part(
			decor,
			"DuckHouseBack",
			Vector3.new(8, 7.2, 0.4),
			house * CFrame.new(0, 4.1, 3),
			wall,
			Enum.Material.WoodPlanks
		)
		for _, side in { -1, 1 } do
			part(
				decor,
				"DuckHouseSide",
				Vector3.new(0.4, 7.2, 6.4),
				house * CFrame.new(side * 3.8, 4.1, 0),
				wall,
				Enum.Material.WoodPlanks
			)
			part(
				decor,
				"DuckHouseFront",
				Vector3.new(1.6, 7.2, 0.4),
				house * CFrame.new(side * 3.2, 4.1, -3),
				wall,
				Enum.Material.WoodPlanks
			)
		end
		part(
			decor,
			"DuckHouseHeader",
			Vector3.new(4.8, 0.8, 0.4),
			house * CFrame.new(0, 7.3, -3),
			wall,
			Enum.Material.WoodPlanks
		)
		slopedRoof(decor, house, 8.8, -3.6, 3.6, 7.9, 9.2)
		part(
			decor,
			"DuckHouseStep",
			Vector3.new(4.8, 0.4, 1.4),
			house * CFrame.new(0, 0.2, -3.9),
			STONE_COLOR,
			Enum.Material.Cobblestone
		)
		feedTrough(decor, o * CFrame.new(-1, 0, hz - 3), 5)
	end,

	-- Balık kafesi: suya sarkan ağ duvarları ve köşelerde yüzen şamandıralar (origin = su yüzeyi)
	fishpen = function(decor, o, size)
		local hx, hz = size.X / 2, size.Z / 2
		local net = Color3.fromRGB(30, 55, 65)
		local walls = {
			{ Vector3.new(size.X, 3.6, 0.1), Vector3.new(0, -1.2, hz) },
			{ Vector3.new(size.X, 3.6, 0.1), Vector3.new(0, -1.2, -hz) },
			{ Vector3.new(0.1, 3.6, size.Z), Vector3.new(hx, -1.2, 0) },
			{ Vector3.new(0.1, 3.6, size.Z), Vector3.new(-hx, -1.2, 0) },
		}
		for _, wall in walls do
			local p = part(decor, "Net", wall[1], o * CFrame.new(wall[2]), net, Enum.Material.Fabric)
			p.Transparency = 0.55
			p.CanCollide = false
			p.CastShadow = false
		end
		for index, spot in
			{
				Vector2.new(-hx, -hz),
				Vector2.new(hx, -hz),
				Vector2.new(-hx, hz),
				Vector2.new(hx, hz),
				Vector2.new(0, -hz),
				Vector2.new(0, hz),
			}
		do
			local buoy = part(
				decor,
				"Buoy",
				Vector3.new(1.1, 1.1, 1.1),
				o * CFrame.new(spot.X, 0.25, spot.Y),
				if index % 2 == 0 then Color3.fromRGB(240, 240, 240) else Color3.fromRGB(235, 110, 50),
				Enum.Material.SmoothPlastic
			)
			buoy.Shape = Enum.PartType.Ball
			buoy.CanCollide = false
		end
	end,
}

return builders
