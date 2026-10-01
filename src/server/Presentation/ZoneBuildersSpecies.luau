--!strict
-- Hayvan türü tablosundaki (Config/Species.luau) küçük adaların bölge görselleri: bölge kimliği ("<tür>_pen") -> kurucu.
-- Her kurucu `function(decor, o, size)`: decor içine yapıları kurar (o = bölge zemininin merkez CFrame'i; -Z ön, +Z arka).
-- Yapılar arka şeride (z ≈ hz - 7 ... hz - 0.8) konur; ön giriş (x ≈ 0, z < 0) ve orta alan hayvanlara boş kalır.

local ZoneParts = require(script.Parent:WaitForChild("ZoneParts"))

local WOOD = ZoneParts.WOOD
local DARK_WOOD = ZoneParts.DARK_WOOD
local STRAW = ZoneParts.STRAW
local WATER = ZoneParts.WATER
local METAL = ZoneParts.METAL
local STONE_COLOR = ZoneParts.STONE_COLOR
local part = ZoneParts.part
local slopedRoof = ZoneParts.slopedRoof
local hayBale = ZoneParts.hayBale
local waterTrough = ZoneParts.waterTrough
local feedTrough = ZoneParts.feedTrough
local plant = ZoneParts.plant
local blossomTree = ZoneParts.blossomTree
local rockPile = ZoneParts.rockPile

local LEAF = Color3.fromRGB(80, 140, 65)
local PLANKS = Enum.Material.WoodPlanks
local WHITE = Color3.new(1, 1, 1)

-- Kutu: pos = merkez (bölge yerel koordinatı); solid=false ise çarpışmaz
local function box(
	decor: Model,
	o: CFrame,
	name: string,
	size: Vector3,
	pos: Vector3,
	color: Color3,
	material: Enum.Material?,
	solid: boolean?
): Part
	local p = part(decor, name, size, o * CFrame.new(pos), color, material)
	if solid == false then
		p.CanCollide = false
	end
	return p
end

-- Döndürülmüş kutu (yaw/roll radyan)
local function tilted(
	decor: Model,
	o: CFrame,
	name: string,
	size: Vector3,
	pos: Vector3,
	rot: CFrame,
	color: Color3,
	material: Enum.Material?,
	solid: boolean?
): Part
	local p = box(decor, o, name, size, pos, color, material, solid)
	p.CFrame = o * CFrame.new(pos) * rot
	return p
end

-- Direk: tabanı zeminde, h yüksekliğinde
local function pole(decor: Model, o: CFrame, x: number, z: number, h: number, w: number, color: Color3): Part
	return box(decor, o, "Post", Vector3.new(w, h, w), Vector3.new(x, h / 2, z), color, nil)
end

-- Ayakta duran silindir (kütük, taş halka, havuz); çap d, yükseklik h
local function disc(
	decor: Model,
	o: CFrame,
	name: string,
	d: number,
	h: number,
	pos: Vector3,
	color: Color3,
	material: Enum.Material?,
	solid: boolean?
): Part
	local p =
		tilted(decor, o, name, Vector3.new(h, d, d), pos, CFrame.Angles(0, 0, math.pi / 2), color, material, solid)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Küre (yaprak, meyve, koza); çarpışmaz
local function ball(
	decor: Model,
	o: CFrame,
	name: string,
	d: number,
	pos: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local p = box(decor, o, name, Vector3.new(d, d, d), pos, color, material or Enum.Material.SmoothPlastic, false)
	p.Shape = Enum.PartType.Ball
	return p
end

-- Eğimli bez/branda: arka (+Z) yüksek
local function cloth(
	decor: Model,
	o: CFrame,
	width: number,
	zFront: number,
	zBack: number,
	yFront: number,
	yBack: number,
	color: Color3
)
	local depth = zBack - zFront
	local rise = yBack - yFront
	local length = math.sqrt(depth * depth + rise * rise)
	local angle = math.atan2(rise, depth)
	local pos = Vector3.new(0, (yFront + yBack) / 2, (zFront + zBack) / 2)
	tilted(
		decor,
		o,
		"Cloth",
		Vector3.new(width, 0.3, length),
		pos,
		CFrame.Angles(-angle, 0, 0),
		color,
		Enum.Material.Fabric
	)
end

local builders: { [string]: ZoneParts.Builder } = {
	-- Tavşan: sıralı, bacaklı tel kafesli ahşap kulübeler + havuç tarhı
	rabbit_pen = function(decor, o, size)
		local hz = size.Z / 2
		local z = hz - 2.6
		local colors = {
			Color3.fromRGB(165, 120, 80),
			Color3.fromRGB(190, 150, 100),
			Color3.fromRGB(150, 105, 70),
			Color3.fromRGB(175, 135, 90),
		}
		for index, x in { -10.5, -3.5, 3.5, 10.5 } do
			for _, side in { -1, 1 } do
				box(
					decor,
					o,
					"HutchLeg",
					Vector3.new(0.4, 1.4, 2.4),
					Vector3.new(x + side * 1.8, 0.7, z),
					DARK_WOOD,
					PLANKS
				)
			end
			box(decor, o, "Hutch", Vector3.new(4.2, 1.8, 2.6), Vector3.new(x, 2.3, z), colors[index], PLANKS)
			local wire = box(
				decor,
				o,
				"Wire",
				Vector3.new(3.2, 1.2, 0.15),
				Vector3.new(x - 0.3, 2.3, z - 1.35),
				METAL,
				Enum.Material.DiamondPlate,
				false
			)
			wire.Transparency = 0.35
			box(decor, o, "HutchRoof", Vector3.new(4.8, 0.3, 3.2), Vector3.new(x, 3.35, z), DARK_WOOD, PLANKS)
		end
		-- Yemlik ve saman
		feedTrough(decor, o * CFrame.new(0, 0, hz - 5.6), 5)
		hayBale(decor, o * CFrame.new(-12.5, 0, hz - 5.6))
		-- Havuç tarhı
		for index = 0, 4 do
			plant(decor, o * CFrame.new(-13 + index * 1.2, 0, hz - 9.5), 0.8, Color3.fromRGB(235, 130, 40), 0.7)
		end
	end,

	-- Arı: renkli petek kovanları (iki sıra) + çiçek tarhları
	bee_pen = function(decor, o, size)
		local hz = size.Z / 2
		local colors = {
			Color3.fromRGB(240, 200, 70),
			Color3.fromRGB(110, 175, 225),
			Color3.fromRGB(235, 120, 130),
			Color3.fromRGB(130, 200, 120),
			Color3.fromRGB(245, 245, 235),
			Color3.fromRGB(190, 140, 220),
		}
		for index, x in { -7, 0, 7 } do
			for row = 0, 1 do
				local z = hz - 1.8 - row * 3.4
				local c = colors[(index - 1) * 2 + row + 1]
				box(decor, o, "HiveStand", Vector3.new(1.8, 0.8, 1.8), Vector3.new(x, 0.4, z), DARK_WOOD, PLANKS)
				box(decor, o, "HiveBox", Vector3.new(1.7, 1.1, 1.7), Vector3.new(x, 1.35, z), c, PLANKS)
				box(
					decor,
					o,
					"HiveBox",
					Vector3.new(1.7, 1.1, 1.7),
					Vector3.new(x, 2.45, z),
					c:Lerp(WHITE, 0.25),
					PLANKS
				)
				box(
					decor,
					o,
					"HiveRoof",
					Vector3.new(2.2, 0.3, 2.2),
					Vector3.new(x, 3.15, z),
					STRAW,
					Enum.Material.Fabric
				)
			end
		end
		-- Çiçek tarhları (iki yanda)
		local blooms = {
			Color3.fromRGB(235, 90, 110),
			Color3.fromRGB(250, 220, 80),
			Color3.fromRGB(170, 120, 230),
		}
		for index = 0, 5 do
			local side = if index % 2 == 0 then -1 else 1
			plant(decor, o * CFrame.new(side * 12.8, 0, hz - 1.8 - index * 1.1), 1.2, blooms[index % 3 + 1], 0.9)
			plant(decor, o * CFrame.new(side * 11.6, 0, hz - 2.3 - index * 1.1), 0.9, blooms[(index + 1) % 3 + 1], 0.8)
		end
		box(decor, o, "Bench", Vector3.new(3, 0.4, 1), Vector3.new(0, 0.9, hz - 7.6), WOOD, PLANKS, false)
	end,

	-- Deve: kumaş gölgelik çadır + taş kuyu ve suluk
	camel_pen = function(decor, o, size)
		local hz = size.Z / 2
		local zFront, zBack = hz - 6.8, hz - 1
		for _, x in { -5.5, 5.5 } do
			pole(decor, o, x, zFront, 5.2, 0.6, DARK_WOOD)
			pole(decor, o, x, zBack, 6.8, 0.6, DARK_WOOD)
		end
		cloth(decor, o, 13, zFront - 0.8, zBack + 0.8, 5.2, 6.8, Color3.fromRGB(200, 120, 70))
		cloth(decor, o, 13.4, zFront - 1.6, zFront - 0.8, 4.7, 5.2, Color3.fromRGB(240, 225, 190))
		-- Halı ve minderler
		box(
			decor,
			o,
			"Carpet",
			Vector3.new(9, 0.1, 4),
			Vector3.new(0, 0.05, hz - 3.9),
			Color3.fromRGB(170, 60, 55),
			Enum.Material.Fabric,
			false
		)
		for _, x in { -2.5, 0.5, 3 } do
			box(
				decor,
				o,
				"Cushion",
				Vector3.new(1.4, 0.6, 1.4),
				Vector3.new(x, 0.4, hz - 3.4),
				Color3.fromRGB(235, 175, 60),
				Enum.Material.Fabric,
				false
			)
		end
		-- Taş kuyu (solda)
		local wx, wz = -11.5, hz - 3.6
		for _, dz in { -1.4, 1.4 } do
			box(
				decor,
				o,
				"WellWall",
				Vector3.new(3.4, 1.4, 0.8),
				Vector3.new(wx, 0.7, wz + dz),
				STONE_COLOR,
				Enum.Material.Slate
			)
		end
		for _, dx in { -1.3, 1.3 } do
			box(
				decor,
				o,
				"WellWall",
				Vector3.new(0.8, 1.4, 2),
				Vector3.new(wx + dx, 0.7, wz),
				STONE_COLOR,
				Enum.Material.Slate
			)
		end
		local water = box(
			decor,
			o,
			"Water",
			Vector3.new(1.8, 0.1, 2),
			Vector3.new(wx, 1.2, wz),
			WATER,
			Enum.Material.Glass,
			false
		)
		water.Transparency = 0.2
		for _, x in { wx - 1.3, wx + 1.3 } do
			pole(decor, o, x, wz, 4.2, 0.4, DARK_WOOD)
		end
		box(decor, o, "WellBeam", Vector3.new(3.4, 0.4, 0.6), Vector3.new(wx, 4.2, wz), DARK_WOOD, nil)
		waterTrough(decor, o * CFrame.new(10.5, 0, hz - 3.6) * CFrame.Angles(0, math.pi / 2, 0), 5)
		rockPile(decor, o * CFrame.new(13, 0, hz - 8), 0.8)
	end,

	-- Tavus: kemerli bahçe çardağı + süs havuzu
	peacock_pen = function(decor, o, size)
		local hz = size.Z / 2
		local ax, az = 6, hz - 2.8
		local white = Color3.fromRGB(240, 238, 230)
		for _, x in { ax - 3, ax + 3 } do
			pole(decor, o, x, az, 6.2, 0.8, white)
			pole(decor, o, x, az + 1.8, 6.2, 0.8, white)
			box(decor, o, "ArchSide", Vector3.new(0.5, 0.5, 2.6), Vector3.new(x, 6.4, az + 0.9), white, nil)
		end
		box(decor, o, "ArchTop", Vector3.new(7.4, 0.6, 0.8), Vector3.new(ax, 6.7, az), white, nil)
		box(decor, o, "ArchTop", Vector3.new(7.4, 0.6, 0.8), Vector3.new(ax, 6.7, az + 1.8), white, nil)
		box(decor, o, "ArchMid", Vector3.new(0.8, 0.5, 2.6), Vector3.new(ax, 7.1, az + 0.9), white, nil)
		for index = 0, 5 do
			local x = ax - 3 + index * 1.2
			ball(decor, o, "Vine", 1.2, Vector3.new(x, 6.9 + (index % 2) * 0.4, az + 0.9), LEAF, Enum.Material.Grass)
		end
		for _, x in { ax - 3, ax + 3 } do
			ball(decor, o, "Bloom", 0.9, Vector3.new(x, 4.6, az - 0.5), Color3.fromRGB(235, 90, 150))
			ball(decor, o, "Bloom", 0.9, Vector3.new(x, 3.2, az - 0.5), Color3.fromRGB(250, 210, 80))
		end
		-- Süs havuzu
		local px, pz = -8.5, hz - 4
		disc(decor, o, "PondRim", 8, 0.5, Vector3.new(px, 0.25, pz), STONE_COLOR, Enum.Material.Slate, false)
		local water = disc(decor, o, "Water", 6.8, 0.2, Vector3.new(px, 0.52, pz), WATER, Enum.Material.Glass, false)
		water.Transparency = 0.25
		for _, off in { Vector3.new(-1, 0, 0.6), Vector3.new(1.3, 0, -0.8), Vector3.new(0.2, 0, 1.4) } do
			disc(
				decor,
				o,
				"Lily",
				1.1,
				0.1,
				Vector3.new(px, 0.66, pz) + off,
				Color3.fromRGB(80, 160, 90),
				Enum.Material.Grass,
				false
			)
		end
		ball(decor, o, "LilyBloom", 0.6, Vector3.new(px - 1, 0.9, pz + 0.6), Color3.fromRGB(250, 170, 200))
		-- Çiçekler
		for index = 0, 3 do
			plant(decor, o * CFrame.new(-13.5 + index * 1.2, 0, hz - 8.4), 1.1, Color3.fromRGB(240, 120, 170), 0.8)
		end
		rockPile(decor, o * CFrame.new(-13.5, 0, hz - 2.2), 0.7)
	end,

	-- Bıldırcın: alçak sıralı kümesler + tahıl yemlikleri
	quail_pen = function(decor, o, size)
		local hz = size.Z / 2
		local z = hz - 2.4
		for _, x in { -9, 0, 9 } do
			box(
				decor,
				o,
				"Coop",
				Vector3.new(5.4, 1.6, 2.4),
				Vector3.new(x, 0.9, z),
				Color3.fromRGB(190, 150, 100),
				PLANKS
			)
			local wire = box(
				decor,
				o,
				"Wire",
				Vector3.new(4.6, 1, 0.15),
				Vector3.new(x, 1, z - 1.25),
				METAL,
				Enum.Material.DiamondPlate,
				false
			)
			wire.Transparency = 0.35
			slopedRoof(decor, o * CFrame.new(x, 0, 0), 5.8, z - 1.5, z + 1.5, 1.9, 2.5)
			box(decor, o, "NestBox", Vector3.new(1.2, 0.8, 1), Vector3.new(x + 2, 0.4, z + 1.9), DARK_WOOD, PLANKS)
			box(
				decor,
				o,
				"Eggs",
				Vector3.new(0.7, 0.3, 0.5),
				Vector3.new(x + 2, 0.9, z + 1.9),
				Color3.fromRGB(235, 225, 200),
				Enum.Material.SmoothPlastic,
				false
			)
			feedTrough(decor, o * CFrame.new(x, 0, z - 3.4), 3.6)
		end
		-- Tahıl çuvalları
		for index = 0, 2 do
			box(
				decor,
				o,
				"GrainSack",
				Vector3.new(1, 1.2, 0.8),
				Vector3.new(-14 + index * 0.9, 0.6, hz - 8.2),
				Color3.fromRGB(215, 190, 140),
				Enum.Material.Fabric,
				false
			)
		end
		hayBale(decor, o * CFrame.new(13, 0, hz - 8))
	end,

	-- Güvercin: güvercinlik kulesi + iki yanda tünek direkleri
	pigeon_pen = function(decor, o, size)
		local hz = size.Z / 2
		local tz = hz - 2.8
		local brick = Color3.fromRGB(205, 190, 165)
		local tile = Color3.fromRGB(150, 70, 55)
		box(decor, o, "TowerBase", Vector3.new(5, 3.4, 4.6), Vector3.new(0, 1.7, tz), STONE_COLOR, Enum.Material.Slate)
		box(decor, o, "Tower", Vector3.new(4.2, 5.2, 3.8), Vector3.new(0, 6, tz), brick, Enum.Material.Brick)
		box(decor, o, "TowerRoof", Vector3.new(5.2, 0.5, 4.6), Vector3.new(0, 8.8, tz), tile, Enum.Material.Slate)
		box(decor, o, "TowerCap", Vector3.new(3.2, 0.9, 3.2), Vector3.new(0, 9.5, tz), tile, Enum.Material.Slate)
		box(decor, o, "TowerCap", Vector3.new(1.4, 0.9, 1.4), Vector3.new(0, 10.4, tz), tile, Enum.Material.Slate)
		-- Giriş delikleri ve konma çıtaları (ön yüz)
		for row = 0, 1 do
			for col = -1, 1 do
				local x = col * 1.2
				local y = 5 + row * 2
				box(
					decor,
					o,
					"Hole",
					Vector3.new(0.7, 0.8, 0.2),
					Vector3.new(x, y, tz - 1.95),
					Color3.fromRGB(50, 40, 35),
					nil,
					false
				)
				box(
					decor,
					o,
					"Ledge",
					Vector3.new(0.9, 0.12, 0.5),
					Vector3.new(x, y - 0.5, tz - 2.15),
					DARK_WOOD,
					nil,
					false
				)
			end
		end
		-- Tünek direkleri
		for _, x in { -9.5, 9.5 } do
			pole(decor, o, x, tz, 6, 0.5, DARK_WOOD)
			for level = 0, 2 do
				box(decor, o, "Perch", Vector3.new(3, 0.3, 0.3), Vector3.new(x, 3 + level * 1.2, tz), WOOD, nil, false)
			end
			box(
				decor,
				o,
				"Dish",
				Vector3.new(1.8, 0.4, 1.8),
				Vector3.new(x, 0.2, tz - 3),
				METAL,
				Enum.Material.Metal,
				false
			)
			box(
				decor,
				o,
				"Grain",
				Vector3.new(1.4, 0.1, 1.4),
				Vector3.new(x, 0.45, tz - 3),
				STRAW,
				Enum.Material.Grass,
				false
			)
		end
	end,

	-- Salyangoz: taş çerçeveli nemli bahçe tarhları (marul/lahana)
	snail_pen = function(decor, o, size)
		local hz = size.Z / 2
		local z = hz - 3
		local lettuce = Color3.fromRGB(150, 205, 90)
		local cabbage = Color3.fromRGB(95, 160, 80)
		for bed, x in { -9.5, 0, 9.5 } do
			local w, d = 8, 3.4
			box(
				decor,
				o,
				"BedFrame",
				Vector3.new(w, 0.9, 0.7),
				Vector3.new(x, 0.45, z - d / 2),
				STONE_COLOR,
				Enum.Material.Slate
			)
			box(
				decor,
				o,
				"BedFrame",
				Vector3.new(w, 0.9, 0.7),
				Vector3.new(x, 0.45, z + d / 2),
				STONE_COLOR,
				Enum.Material.Slate
			)
			for _, side in { -1, 1 } do
				box(
					decor,
					o,
					"BedFrame",
					Vector3.new(0.7, 0.9, d),
					Vector3.new(x + side * (w / 2 - 0.35), 0.45, z),
					STONE_COLOR,
					Enum.Material.Slate
				)
			end
			box(
				decor,
				o,
				"Soil",
				Vector3.new(w - 1.4, 0.8, d - 1.2),
				Vector3.new(x, 0.45, z),
				Color3.fromRGB(70, 50, 38),
				Enum.Material.Mud,
				false
			)
			for index = 0, 4 do
				local isCabbage = (bed + index) % 2 == 0
				local d2 = if isCabbage then 1.4 else 1.1
				local pos = Vector3.new(x - 2.6 + index * 1.3, 0.85 + d2 / 2, z + ((index % 2) - 0.5) * 0.8)
				ball(
					decor,
					o,
					if isCabbage then "Cabbage" else "Lettuce",
					d2,
					pos,
					if isCabbage then cabbage else lettuce,
					Enum.Material.Grass
				)
			end
		end
		-- Sulama kovası ve taşlar
		disc(decor, o, "Bucket", 1.2, 1, Vector3.new(-14, 0.5, hz - 7.6), METAL, Enum.Material.Metal)
		rockPile(decor, o * CFrame.new(13.5, 0, hz - 7.6), 0.6)
		box(
			decor,
			o,
			"MossStone",
			Vector3.new(1.6, 1, 1.4),
			Vector3.new(-4.8, 0.5, hz - 7.4),
			Color3.fromRGB(90, 130, 80),
			Enum.Material.Slate
		)
	end,

	-- Lama: taş duvarlı yayla ağılı + saman rafı
	llama_pen = function(decor, o, size)
		local hx, hz = size.X / 2, size.Z / 2
		local wallH = 2.2
		local zWall = hz - 0.8
		local capColor = Color3.fromRGB(105, 103, 96)
		box(
			decor,
			o,
			"StoneWall",
			Vector3.new(size.X - 2, wallH, 0.9),
			Vector3.new(0, wallH / 2, zWall),
			STONE_COLOR,
			Enum.Material.Cobblestone
		)
		box(
			decor,
			o,
			"WallCap",
			Vector3.new(size.X - 1.6, 0.3, 1.2),
			Vector3.new(0, wallH + 0.15, zWall),
			capColor,
			Enum.Material.Slate
		)
		for _, side in { -1, 1 } do
			box(
				decor,
				o,
				"StoneWall",
				Vector3.new(0.9, wallH, 6),
				Vector3.new(side * (hx - 1), wallH / 2, hz - 4.2),
				STONE_COLOR,
				Enum.Material.Cobblestone
			)
			box(
				decor,
				o,
				"WallCap",
				Vector3.new(1.2, 0.3, 6.4),
				Vector3.new(side * (hx - 1), wallH + 0.15, hz - 4.2),
				capColor,
				Enum.Material.Slate
			)
		end
		-- Saman rafı (çatılı)
		local rx, rz = -5, hz - 3
		for _, x in { rx - 3, rx + 3 } do
			pole(decor, o, x, rz, 4.2, 0.6, DARK_WOOD)
		end
		box(decor, o, "RackShelf", Vector3.new(6.6, 0.3, 1.8), Vector3.new(rx, 1.8, rz), WOOD, PLANKS)
		for index = 0, 5 do
			box(
				decor,
				o,
				"RackSlat",
				Vector3.new(0.2, 1.1, 0.2),
				Vector3.new(rx - 2.6 + index * 1.04, 2.5, rz - 0.9),
				DARK_WOOD,
				nil,
				false
			)
		end
		box(decor, o, "RackHay", Vector3.new(6, 0.8, 1.4), Vector3.new(rx, 2.3, rz), STRAW, Enum.Material.Grass, false)
		slopedRoof(decor, o * CFrame.new(rx, 0, 0), 7.4, rz - 1.6, rz + 1.6, 4.3, 5)
		hayBale(decor, o * CFrame.new(rx + 5, 0, hz - 6.4))
		waterTrough(decor, o * CFrame.new(7, 0, hz - 3) * CFrame.Angles(0, math.pi / 2, 0), 5)
		rockPile(decor, o * CFrame.new(11.5, 0, hz - 6.8), 0.9)
		rockPile(decor, o * CFrame.new(-12.5, 0, hz - 6.8), 0.7)
	end,

	-- Geyik: yaslı çatılı orman sığınağı + kütükler + tuz taşı
	deer_pen = function(decor, o, size)
		local hz = size.Z / 2
		local zFront, zBack = hz - 6, hz - 0.8
		local bark = Color3.fromRGB(95, 70, 50)
		box(decor, o, "BackWall", Vector3.new(14, 6.2, 0.7), Vector3.new(-4, 3.1, zBack), bark, PLANKS)
		for _, x in { -11, -4, 3 } do
			pole(decor, o, x, zFront, 5.2, 0.7, bark)
		end
		slopedRoof(decor, o * CFrame.new(-4, 0, 0), 15, zFront - 0.8, zBack + 0.6, 5.3, 6.5)
		box(
			decor,
			o,
			"StrawBed",
			Vector3.new(13, 0.1, 4.6),
			Vector3.new(-4, 0.05, hz - 3.4),
			STRAW,
			Enum.Material.Fabric,
			false
		)
		-- Kütükler (yatan) ve kesik kütükler
		local log =
			box(decor, o, "Log", Vector3.new(4.2, 1, 1), Vector3.new(7.5, 0.5, hz - 7), bark, Enum.Material.Wood)
		log.Shape = Enum.PartType.Cylinder
		local log2 =
			box(decor, o, "Log", Vector3.new(3.4, 0.9, 0.9), Vector3.new(9.4, 1.4, hz - 7), bark, Enum.Material.Wood)
		log2.Shape = Enum.PartType.Cylinder
		for _, pos in
			{ Vector3.new(12.5, 0.5, hz - 4.5), Vector3.new(11.6, 0.4, hz - 2.6), Vector3.new(-13.5, 0.5, hz - 7.2) }
		do
			disc(decor, o, "Stump", 1.5, pos.Y * 2, pos, bark, Enum.Material.Wood)
		end
		-- Tuz taşı
		box(
			decor,
			o,
			"SaltBase",
			Vector3.new(2.4, 0.5, 2.4),
			Vector3.new(-13.2, 0.25, hz - 2.5),
			STONE_COLOR,
			Enum.Material.Slate
		)
		box(
			decor,
			o,
			"SaltBlock",
			Vector3.new(1.6, 1.1, 1.6),
			Vector3.new(-13.2, 1.05, hz - 2.5),
			Color3.fromRGB(245, 225, 225),
			Enum.Material.Slate
		)
		blossomTree(decor, o * CFrame.new(13.5, 0, hz - 1.8), Color3.fromRGB(60, 110, 60))
	end,

	-- Şahin: tünek direkleri + kaya blokları + eğitim halkası
	falcon_pen = function(decor, o, size)
		local hz = size.Z / 2
		local z = hz - 3
		-- Tünek direkleri (üstte T çubuğu, eldiven bloğu)
		for index, x in { -12, -7.5, -3 } do
			local h = 3.4 + (index % 2) * 1.2
			pole(decor, o, x, z, h, 0.5, DARK_WOOD)
			box(decor, o, "PerchBar", Vector3.new(2.2, 0.3, 0.4), Vector3.new(x, h + 0.15, z), WOOD, nil, false)
			box(
				decor,
				o,
				"LeatherBlock",
				Vector3.new(0.8, 0.5, 0.8),
				Vector3.new(x, 0.25, z - 1.2),
				Color3.fromRGB(120, 80, 50),
				Enum.Material.Leather,
				false
			)
		end
		-- Kaya blokları
		tilted(
			decor,
			o,
			"RockBlock",
			Vector3.new(3.6, 2.4, 3),
			Vector3.new(11, 1.2, hz - 6.5),
			CFrame.Angles(0, 0.4, 0),
			STONE_COLOR,
			Enum.Material.Slate
		)
		tilted(
			decor,
			o,
			"RockBlock",
			Vector3.new(2.6, 3.8, 2.4),
			Vector3.new(13, 1.9, hz - 3),
			CFrame.Angles(0, -0.3, 0),
			Color3.fromRGB(110, 108, 100),
			Enum.Material.Slate
		)
		box(
			decor,
			o,
			"RockBlock",
			Vector3.new(2, 1.4, 2),
			Vector3.new(9, 0.7, hz - 2.2),
			STONE_COLOR,
			Enum.Material.Slate,
			false
		)
		-- Eğitim halkası: iki direk arasında 8 parçalı halka
		local cx, cy = 3, 4.6
		for _, off in { -2.4, 2.4 } do
			pole(decor, o, cx + off, z, 3.2, 0.3, DARK_WOOD)
		end
		for step = 0, 7 do
			local a = step * math.pi / 4
			local pos = Vector3.new(cx + math.cos(a) * 1.8, cy + math.sin(a) * 1.8, z)
			tilted(
				decor,
				o,
				"Hoop",
				Vector3.new(1.4, 0.3, 0.3),
				pos,
				CFrame.Angles(0, 0, a + math.pi / 2),
				Color3.fromRGB(215, 70, 55),
				Enum.Material.SmoothPlastic,
				false
			)
		end
		box(decor, o, "HoopBase", Vector3.new(5.4, 0.3, 0.6), Vector3.new(cx, 3.35, z), DARK_WOOD, nil, false)
		-- Su kasesi
		disc(decor, o, "Bath", 2.4, 0.5, Vector3.new(-8, 0.25, hz - 6.8), STONE_COLOR, Enum.Material.Slate, false)
		local water =
			disc(decor, o, "Water", 1.9, 0.1, Vector3.new(-8, 0.52, hz - 6.8), WATER, Enum.Material.Glass, false)
		water.Transparency = 0.2
	end,

	-- İpek böceği: dut ağacı dalları + raf tepsileri
	silkworm_pen = function(decor, o, size)
		local hz = size.Z / 2
		local z = hz - 3
		-- Dut ağacı (solda), meyveleri ve yan dalları
		local tx = -10.5
		box(decor, o, "Trunk", Vector3.new(1.1, 4.4, 1.1), Vector3.new(tx, 2.2, z), DARK_WOOD, Enum.Material.Wood)
		for _, off in { Vector3.new(-2, 0, 0.3), Vector3.new(2.2, 0.6, -0.4), Vector3.new(0.3, 1.8, 1) } do
			ball(decor, o, "Crown", 4, Vector3.new(tx, 5.4, z) + off, Color3.fromRGB(95, 150, 70), Enum.Material.Grass)
		end
		for _, off in { Vector3.new(-2.8, -0.6, -1.4), Vector3.new(1.6, -0.2, -1.8), Vector3.new(2.8, 0.6, 1) } do
			ball(decor, o, "Mulberry", 0.5, Vector3.new(tx, 5.4, z) + off, Color3.fromRGB(110, 40, 90))
		end
		for _, side in { -1, 1 } do
			tilted(
				decor,
				o,
				"Branch",
				Vector3.new(0.3, 2.4, 0.3),
				Vector3.new(tx + side * 1.1, 3.8, z),
				CFrame.Angles(0, 0, side * 0.7),
				DARK_WOOD,
				nil,
				false
			)
		end
		-- Raf: 4 direk, 4 tepsi, yaprak ve koza
		local rx = 4
		for _, x in { rx - 4, rx + 4 } do
			for _, dz in { -1.4, 1.4 } do
				pole(decor, o, x, z + dz, 5.4, 0.4, WOOD)
			end
		end
		for level = 0, 3 do
			local y = 1 + level * 1.3
			box(
				decor,
				o,
				"Tray",
				Vector3.new(8.6, 0.25, 3.2),
				Vector3.new(rx, y, z),
				Color3.fromRGB(215, 195, 150),
				Enum.Material.Wood,
				false
			)
			box(
				decor,
				o,
				"MulberryLeaf",
				Vector3.new(3.2, 0.12, 1.6),
				Vector3.new(rx - 2, y + 0.18, z),
				LEAF,
				Enum.Material.Grass,
				false
			)
			ball(
				decor,
				o,
				"Cocoon",
				0.55,
				Vector3.new(rx + 1.2 + (level % 2) * 0.8, y + 0.4, z - 0.4),
				Color3.fromRGB(250, 248, 235),
				Enum.Material.Fabric
			)
			ball(
				decor,
				o,
				"Cocoon",
				0.55,
				Vector3.new(rx + 2.6, y + 0.4, z + 0.5),
				Color3.fromRGB(245, 240, 225),
				Enum.Material.Fabric
			)
		end
		box(
			decor,
			o,
			"ShelfRoof",
			Vector3.new(9.4, 0.3, 4),
			Vector3.new(rx, 5.6, z),
			Color3.fromRGB(150, 110, 70),
			PLANKS
		)
	end,

	-- Papağan: renkli tünek çerçevesi + yemlik istasyonu
	parrot_pen = function(decor, o, size)
		local hz = size.Z / 2
		local z = hz - 3
		local red = Color3.fromRGB(215, 60, 55)
		local blue = Color3.fromRGB(60, 120, 215)
		local yellow = Color3.fromRGB(245, 200, 60)
		local green = Color3.fromRGB(70, 175, 90)
		local fruitColors = { red, yellow, blue }
		-- Çerçeve: iki renkli direk, üst kiriş, asılı tüneklerle
		pole(decor, o, -8, z, 7, 0.7, red)
		pole(decor, o, 2, z, 7, 0.7, blue)
		box(decor, o, "FrameBeam", Vector3.new(10.7, 0.7, 0.7), Vector3.new(-3, 7.1, z), yellow, nil)
		box(decor, o, "FrameBeam", Vector3.new(10.7, 0.5, 0.5), Vector3.new(-3, 4.2, z), green, nil, false)
		box(decor, o, "FrameBeam", Vector3.new(7, 0.5, 0.5), Vector3.new(-3, 2.2, z), red, nil, false)
		for index, x in { -6, -3, 0 } do
			local c = fruitColors[index]
			box(decor, o, "Rope", Vector3.new(0.12, 2.6, 0.12), Vector3.new(x, 5.8, z), c, Enum.Material.Fabric, false)
			box(decor, o, "HangPerch", Vector3.new(2, 0.3, 0.3), Vector3.new(x, 4.4, z), c, nil, false)
			ball(decor, o, "Fruit", 0.5, Vector3.new(x + 0.5, 4.9, z), c:Lerp(WHITE, 0.2))
		end
		-- Yemlik istasyonu (sağda): masa, renkli kaplar, meyveler
		local sx = 9
		box(decor, o, "FeedTable", Vector3.new(7, 0.4, 2.4), Vector3.new(sx, 1.5, z), WOOD, PLANKS)
		for _, dx in { -3.1, 3.1 } do
			for _, dz in { -0.9, 0.9 } do
				pole(decor, o, sx + dx, z + dz, 1.4, 0.35, DARK_WOOD)
			end
		end
		local bowls = { red, yellow, green }
		for index, c in bowls do
			local bx = sx - 2.2 + (index - 1) * 2.2
			disc(decor, o, "Bowl", 1.4, 0.5, Vector3.new(bx, 1.95, z), c, Enum.Material.SmoothPlastic, false)
			ball(decor, o, "Fruit", 0.6, Vector3.new(bx, 2.3, z), c:Lerp(WHITE, 0.3))
		end
		for index, c in fruitColors do
			plant(decor, o * CFrame.new(-13.5, 0, hz - 8 + index * 1.2), 1, c, 0.8)
		end
	end,

	-- Kaplumbağa: sığ havuz (Glass su) + güneşlenme kayaları + alçak taş duvar
	tortoise_pen = function(decor, o, size)
		local hx, hz = size.X / 2, size.Z / 2
		-- Alçak taş duvar (arkada) ve sütunlar
		box(
			decor,
			o,
			"LowWall",
			Vector3.new(size.X - 2, 1.2, 0.8),
			Vector3.new(0, 0.6, hz - 0.8),
			STONE_COLOR,
			Enum.Material.Cobblestone
		)
		for _, x in { -(hx - 1), 0, hx - 1 } do
			box(
				decor,
				o,
				"WallPillar",
				Vector3.new(1.4, 2, 1.4),
				Vector3.new(x, 1, hz - 0.8),
				Color3.fromRGB(110, 108, 100),
				Enum.Material.Slate
			)
		end
		-- Sığ havuz: dört taş kenar + cam su
		local px, pz, w, d = -6, hz - 4.4, 10, 5
		local rim = Color3.fromRGB(135, 130, 120)
		for _, side in { -1, 1 } do
			box(
				decor,
				o,
				"PoolRim",
				Vector3.new(w, 0.5, 0.7),
				Vector3.new(px, 0.25, pz + side * (d / 2)),
				rim,
				Enum.Material.Slate
			)
			box(
				decor,
				o,
				"PoolRim",
				Vector3.new(0.7, 0.5, d),
				Vector3.new(px + side * (w / 2 - 0.35), 0.25, pz),
				rim,
				Enum.Material.Slate
			)
		end
		local water = box(
			decor,
			o,
			"Water",
			Vector3.new(w - 1.4, 0.2, d - 1),
			Vector3.new(px, 0.4, pz),
			WATER,
			Enum.Material.Glass,
			false
		)
		water.Transparency = 0.3
		for _, off in { Vector3.new(-2, 0, 0.4), Vector3.new(1.8, 0, -0.5) } do
			disc(
				decor,
				o,
				"Lily",
				1.2,
				0.1,
				Vector3.new(px, 0.52, pz) + off,
				Color3.fromRGB(80, 160, 90),
				Enum.Material.Grass,
				false
			)
		end
		-- Güneşlenme kayaları (düz, alçak)
		disc(
			decor,
			o,
			"BaskingRock",
			3.6,
			0.8,
			Vector3.new(7, 0.4, hz - 6.5),
			Color3.fromRGB(150, 140, 120),
			Enum.Material.Slate
		)
		disc(
			decor,
			o,
			"BaskingRock",
			2.6,
			0.6,
			Vector3.new(11, 0.3, hz - 4),
			Color3.fromRGB(140, 132, 115),
			Enum.Material.Slate
		)
		disc(
			decor,
			o,
			"BaskingRock",
			2,
			0.5,
			Vector3.new(5.6, 0.25, hz - 3.2),
			Color3.fromRGB(155, 145, 125),
			Enum.Material.Slate
		)
		for index = 0, 3 do
			plant(decor, o * CFrame.new(1.5 + index * 1.4, 0, hz - 2.2), 0.7, Color3.fromRGB(250, 220, 90), 0.6)
		end
		hayBale(decor, o * CFrame.new(13, 0, hz - 7.4))
	end,
}

return builders
