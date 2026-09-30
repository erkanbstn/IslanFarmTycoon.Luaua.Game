--!strict
-- Ağıl tipi bölgeler: at bölmeleri, keçi, koyun ve domuz ağılı.
-- Her bölge `function(decor, o, size)`: decor içine yapıları kurar (o = bölge zemininin merkez CFrame'i).

local ZoneParts = require(script.Parent:WaitForChild("ZoneParts"))

type Builder = ZoneParts.Builder
local WOOD = ZoneParts.WOOD
local DARK_WOOD = ZoneParts.DARK_WOOD
local STRAW = ZoneParts.STRAW
local STONE_COLOR = ZoneParts.STONE_COLOR
local part = ZoneParts.part
local slopedRoof = ZoneParts.slopedRoof
local hayBale = ZoneParts.hayBale
local waterTrough = ZoneParts.waterTrough
local feedTrough = ZoneParts.feedTrough

local builders: { [string]: Builder } = {
	-- At ahırı: arkada bölmeli, çatılı ahır; önde otlama alanı
	stable = function(decor, o, size)
		local hx, hz = size.X / 2, size.Z / 2
		local zFront, zBack = hz - 7, hz - 0.8
		part(
			decor,
			"BackWall",
			Vector3.new(size.X - 2, 8, 0.8),
			o * CFrame.new(0, 4, zBack),
			Color3.fromRGB(120, 80, 50),
			Enum.Material.WoodPlanks
		)
		part(
			decor,
			"Straw",
			Vector3.new(size.X - 2, 0.1, zBack - zFront),
			o * CFrame.new(0, 0.05, (zFront + zBack) / 2),
			STRAW,
			Enum.Material.Fabric
		).CanCollide =
			false
		local stalls = 4
		local stallW = (size.X - 2) / stalls
		for i = 0, stalls do
			local x = -(hx - 1) + i * stallW
			part(
				decor,
				"Divider",
				Vector3.new(0.6, 4, zBack - zFront),
				o * CFrame.new(x, 2, (zFront + zBack) / 2),
				WOOD,
				Enum.Material.WoodPlanks
			)
			part(decor, "Post", Vector3.new(0.8, 7, 0.8), o * CFrame.new(x, 3.5, zFront), DARK_WOOD)
		end
		slopedRoof(decor, o, size.X, zFront - 1, zBack + 0.6, 7, 8.6)
		-- Her bölmenin arkasında yemlik (bölme duvarları yemliği ayırır)
		feedTrough(decor, o * CFrame.new(0, 0, zBack - 1.3), size.X - 3)
		hayBale(decor, o * CFrame.new(-(hx - 3.5), 0, zFront + 1.5))
	end,

	-- Keçi ağılı: arkada alçak, çatılı barınak; samanlık ve suluk barınağın içinde
	goatpen = function(decor, o, size)
		local hx, hz = size.X / 2, size.Z / 2
		local zFront, zBack = hz - 5, hz - 0.8
		part(
			decor,
			"BackWall",
			Vector3.new(size.X - 2, 8, 0.8),
			o * CFrame.new(0, 4, zBack),
			Color3.fromRGB(150, 120, 90),
			Enum.Material.WoodPlanks
		)
		for _, x in { -(hx - 1), hx - 1 } do
			part(decor, "Post", Vector3.new(0.8, 7.2, 0.8), o * CFrame.new(x, 3.6, zFront), DARK_WOOD)
		end
		slopedRoof(decor, o, size.X, zFront - 0.5, zBack + 0.6, 7.3, 8.6)
		part(
			decor,
			"Straw",
			Vector3.new(size.X - 2, 0.1, zBack - zFront),
			o * CFrame.new(0, 0.05, (zFront + zBack) / 2),
			STRAW,
			Enum.Material.Fabric
		).CanCollide =
			false
		feedTrough(decor, o * CFrame.new(2, 0, zBack - 1.3), size.X - 12)
		waterTrough(decor, o * CFrame.new(-(hx - 2.5), 0, zBack - 2.2), 3)
	end,

	-- Koyun ağılı: taş duvarlı tıraş ahırı, yün balyaları ve saman
	sheepfold = function(decor, o, size)
		local hx, hz = size.X / 2, size.Z / 2
		local zFront, zBack = hz - 6.5, hz - 0.8
		part(
			decor,
			"ShedBack",
			Vector3.new(size.X - 2, 8, 0.8),
			o * CFrame.new(0, 4, zBack),
			Color3.fromRGB(150, 140, 120),
			Enum.Material.Brick
		)
		for _, x in { -1, 1 } do
			part(
				decor,
				"ShedSide",
				Vector3.new(0.8, 7.4, zBack - zFront),
				o * CFrame.new(x * (hx - 1), 3.7, (zFront + zBack) / 2),
				Color3.fromRGB(150, 140, 120),
				Enum.Material.Brick
			)
		end
		for _, x in { -(hx - 1), 0, hx - 1 } do
			part(decor, "ShedPost", Vector3.new(0.8, 7.6, 0.8), o * CFrame.new(x, 3.8, zFront), DARK_WOOD)
		end
		slopedRoof(decor, o, size.X, zFront - 1, zBack + 0.6, 7.7, 9.1)
		part(
			decor,
			"Straw",
			Vector3.new(size.X - 2, 0.1, zBack - zFront),
			o * CFrame.new(0, 0.05, (zFront + zBack) / 2),
			STRAW,
			Enum.Material.Fabric
		).CanCollide =
			false
		-- Yün balyaları
		for index = 0, 3 do
			local bale = part(
				decor,
				"WoolBale",
				Vector3.new(2.2, 1.9, 1.9),
				o * CFrame.new(-(hx - 3.5) + index * 2.6, 0.95, zBack - 1.6),
				Color3.fromRGB(246, 242, 232),
				Enum.Material.Fabric
			)
			bale.CanCollide = false
			if index % 2 == 0 then
				local top = part(
					decor,
					"WoolBale",
					Vector3.new(2.2, 1.9, 1.9),
					o * CFrame.new(-(hx - 3.5) + index * 2.6, 2.85, zBack - 1.6),
					Color3.fromRGB(240, 236, 224),
					Enum.Material.Fabric
				)
				top.CanCollide = false
			end
		end
		waterTrough(decor, o * CFrame.new(hx - 3.5, 0, zBack - 3.4), 4)
		hayBale(decor, o * CFrame.new(-(hx - 3), 0, zFront + 1.6))
		-- Ön tarafta çiçekler
		for index, spot in { Vector2.new(-9, -7), Vector2.new(7, -9), Vector2.new(10, -3), Vector2.new(-4, -3) } do
			local flower = part(
				decor,
				"Flower",
				Vector3.new(0.7, 0.7, 0.7),
				o * CFrame.new(spot.X, 0.35, spot.Y),
				if index % 2 == 0 then Color3.fromRGB(250, 220, 80) else Color3.fromRGB(240, 120, 160),
				Enum.Material.SmoothPlastic
			)
			flower.Shape = Enum.PartType.Ball
			flower.CanCollide = false
		end
	end,

	-- Domuz çiftliği: çamur birikintileri, içine girilen ahşap ağıl, yemlik ve mantarlar
	pigpen = function(decor, o, size)
		local hx, hz = size.X / 2, size.Z / 2
		local mud = Color3.fromRGB(88, 62, 42)
		for _, spot in { Vector3.new(-7, 0, -4), Vector3.new(5, 0, -7), Vector3.new(9, 0, 0), Vector3.new(-3, 0, 1) } do
			local puddle = part(
				decor,
				"Mud",
				Vector3.new(0.1, 5.4, 5.4),
				o * CFrame.new(spot.X, 0.08, spot.Z) * CFrame.Angles(0, 0, math.rad(90)),
				mud,
				Enum.Material.Mud
			)
			puddle.Shape = Enum.PartType.Cylinder
			puddle.CanCollide = false
		end
		local sty = o * CFrame.new(-(hx - 6), 0, hz - 3.8)
		part(decor, "StyFloor", Vector3.new(10, 0.5, 6.6), sty * CFrame.new(0, 0.25, 0), WOOD, Enum.Material.WoodPlanks)
		local wall = Color3.fromRGB(150, 108, 70)
		part(decor, "StyBack", Vector3.new(10, 7.2, 0.4), sty * CFrame.new(0, 4.1, 3.1), wall, Enum.Material.WoodPlanks)
		for _, side in { -1, 1 } do
			part(
				decor,
				"StySide",
				Vector3.new(0.4, 7.2, 6.6),
				sty * CFrame.new(side * 4.8, 4.1, 0),
				wall,
				Enum.Material.WoodPlanks
			)
			part(
				decor,
				"StyFront",
				Vector3.new(2.6, 7.2, 0.4),
				sty * CFrame.new(side * 3.7, 4.1, -3.1),
				wall,
				Enum.Material.WoodPlanks
			)
		end
		part(
			decor,
			"StyHeader",
			Vector3.new(4.8, 0.8, 0.4),
			sty * CFrame.new(0, 7.3, -3.1),
			wall,
			Enum.Material.WoodPlanks
		)
		slopedRoof(decor, sty, 10.8, -3.7, 3.7, 7.9, 9.2)
		part(
			decor,
			"StyStep",
			Vector3.new(4.8, 0.4, 1.4),
			sty * CFrame.new(0, 0.2, -4),
			STONE_COLOR,
			Enum.Material.Cobblestone
		)
		hayBale(decor, sty * CFrame.new(2.6, 0.5, 1.8))
		feedTrough(decor, o * CFrame.new(hx - 6, 0, hz - 3), 6)
		-- Mantarlar: yer yer kırmızı şapkalı, beyaz benekli
		for _, spot in { Vector2.new(-11, -8), Vector2.new(11, -9), Vector2.new(-10, 0), Vector2.new(12, 1) } do
			part(
				decor,
				"MushroomStem",
				Vector3.new(0.4, 0.9, 0.4),
				o * CFrame.new(spot.X, 0.45, spot.Y),
				Color3.fromRGB(240, 230, 210),
				Enum.Material.SmoothPlastic
			).CanCollide =
				false
			local cap = part(
				decor,
				"MushroomCap",
				Vector3.new(1.4, 0.7, 1.4),
				o * CFrame.new(spot.X, 1.05, spot.Y),
				Color3.fromRGB(196, 60, 52),
				Enum.Material.SmoothPlastic
			)
			cap.Shape = Enum.PartType.Ball
			cap.CanCollide = false
		end
	end,
}

return builders
