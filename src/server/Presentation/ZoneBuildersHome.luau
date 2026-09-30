--!strict
-- Ana ada bölgeleri: ağıl (starter) ve otlak (pasture) + otlak süsleri.
-- Her bölge `function(decor, o, size)`: decor içine yapıları kurar (o = bölge zemininin merkez CFrame'i).

local WorldDecor = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("WorldDecor"))
local ZoneParts = require(script.Parent:WaitForChild("ZoneParts"))

type Builder = ZoneParts.Builder
local STRAW = ZoneParts.STRAW
local part = ZoneParts.part
local slopedRoof = ZoneParts.slopedRoof
local hayBale = ZoneParts.hayBale
local waterTrough = ZoneParts.waterTrough
local feedTrough = ZoneParts.feedTrough
local plant = ZoneParts.plant
local blossomTree = ZoneParts.blossomTree
local rockPile = ZoneParts.rockPile
local Look = ZoneParts.Look

-- Otlağın kendine özgü süsü: ön ve orta şeritte (arkadaki balyalar ve suluk hariç)
local PASTURE_STYLES: { [string]: (decor: Model, o: CFrame, size: Vector3) -> () } = {
	tulip = function(decor, o, _size)
		local colors = { Color3.fromRGB(230, 60, 80), Color3.fromRGB(250, 200, 60), Color3.fromRGB(190, 90, 200) }
		for row = 1, 3 do
			for i = 0, 5 do
				plant(decor, o * CFrame.new(-10 + i * 1.6, 0, -10 + row * 1.6), 1.1, colors[row], 0.7)
			end
		end
	end,
	sunflower = function(decor, o, _size)
		for i = 0, 7 do
			local x = -12 + (i % 4) * 2.4
			local z = -9 + math.floor(i / 4) * 2.6
			plant(decor, o * CFrame.new(x, 0, z), 3.2, Color3.fromRGB(245, 195, 30), 1.5)
		end
	end,
	rose = function(decor, o, size)
		local hz = size.Z / 2
		for i = 0, 4 do
			local cf = o * CFrame.new(-11 + i * 2.2, 0, -(hz - 3))
			part(
				decor,
				"RoseBush",
				Vector3.new(1.8, 1.2, 1.8),
				cf * CFrame.new(0, 0.6, 0),
				Color3.fromRGB(60, 120, 55),
				Enum.Material.Grass
			).Shape =
				Enum.PartType.Ball
			plant(decor, cf * CFrame.new(0.3, 1, 0), 0.4, Color3.fromRGB(215, 40, 70), 0.6)
		end
	end,
	pine = function(decor, o, _size)
		WorldDecor.pineTree(decor, o * CFrame.new(-9, 0, -8), 11)
		WorldDecor.pineTree(decor, o * CFrame.new(-12, 0, 0), 12)
		rockPile(decor, o * CFrame.new(8, 0, -7), 1)
		rockPile(decor, o * CFrame.new(-4, 0, 6), 0.7)
	end,
	cherry = function(decor, o, _size)
		blossomTree(decor, o * CFrame.new(-9, 0, -7), Color3.fromRGB(245, 160, 190))
		blossomTree(decor, o * CFrame.new(10, 0, 5), Color3.fromRGB(240, 140, 175))
		blossomTree(decor, o * CFrame.new(-11, 0, 4), Color3.fromRGB(250, 180, 205))
	end,
}
local builders: { [string]: Builder } = {
	-- İnek barınağı: arkada çatılı, samanlı, kırmızı duvarlı ahır bölmesi
	starter = function(decor, o, size)
		local hx, hz = size.X / 2, size.Z / 2
		local zFront, zBack = hz - 10, hz - 0.8
		part(
			decor,
			"Straw",
			Vector3.new(size.X - 2, 0.1, zBack - zFront),
			o * CFrame.new(0, 0.05, (zFront + zBack) / 2),
			STRAW,
			Enum.Material.Fabric
		).CanCollide =
			false
		part(
			decor,
			"BackWall",
			Vector3.new(size.X - 2, 7.5, 0.8),
			o * CFrame.new(0, 3.75, zBack),
			Look.barnColor,
			Enum.Material.WoodPlanks
		)
		for _, x in { -1, 1 } do
			part(
				decor,
				"SideWall",
				Vector3.new(0.8, 6.5, zBack - zFront),
				o * CFrame.new(x * (hx - 1), 3.25, (zFront + zBack) / 2),
				Look.barnColor,
				Enum.Material.WoodPlanks
			)
		end
		for _, x in { -(hx - 1), hx - 1 } do
			part(
				decor,
				"Post",
				Vector3.new(0.9, 6.4, 0.9),
				o * CFrame.new(x, 3.2, zFront),
				Color3.fromRGB(240, 235, 225)
			)
		end
		slopedRoof(decor, o, size.X, zFront - 1, zBack + 0.6, 6.6, 8)
		feedTrough(decor, o * CFrame.new(0, 0, zBack - 1.4), size.X - 10)
		-- Barınağın arka köşeleri: bir yanda balyalar, bir yanda suluk
		waterTrough(decor, o * CFrame.new(-(hx - 2.5), 0, zBack - 3), 4)
		hayBale(decor, o * CFrame.new(hx - 2.8, 0, zBack - 1.6))
		hayBale(decor, o * CFrame.new(hx - 2.8, 0, zBack - 3.4))
		hayBale(decor, o * CFrame.new(hx - 2.8, 1.6, zBack - 2.5))
	end,

	-- Otlak: balyalar, suluk, çiçekler
	pasture = function(decor, o, size)
		local hx, hz = size.X / 2, size.Z / 2
		hayBale(decor, o * CFrame.new(-(hx - 4), 0, hz - 3))
		hayBale(decor, o * CFrame.new(-(hx - 7), 0, hz - 3))
		hayBale(decor, o * CFrame.new(-(hx - 5.5), 1.6, hz - 3))
		waterTrough(decor, o * CFrame.new(hx - 3, 0, -(hz - 6)), 6)
		local style = PASTURE_STYLES[Look.current.pasture]
		if style then
			style(decor, o, size)
			return
		end
		local flowerColors =
			{ Color3.fromRGB(250, 220, 80), Color3.fromRGB(240, 120, 160), Color3.fromRGB(250, 250, 250) }
		for i, spot in
			{ Vector2.new(-8, -9), Vector2.new(6, 9), Vector2.new(10, 2), Vector2.new(-3, 4), Vector2.new(-11, -2) }
		do
			local flower = part(
				decor,
				"Flower",
				Vector3.new(0.7, 0.7, 0.7),
				o * CFrame.new(spot.X, 0.35, spot.Y),
				flowerColors[(i % 3) + 1],
				Enum.Material.SmoothPlastic
			)
			flower.Shape = Enum.PartType.Ball
			flower.CanCollide = false
		end
	end,
}

return builders
