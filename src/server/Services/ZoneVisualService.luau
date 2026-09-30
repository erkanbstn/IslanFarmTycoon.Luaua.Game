--!strict
-- Bölgelerin içindeki yapılar: inek barınağı, tavuk kümesi, at bölmeleri, yemlik, saman balyaları...
-- Bölge açılınca kurulur, kapanınca (ada boşalınca) silinir; kilitli bölge çıplak toprak görünür.
-- Koordinatlar bölge zemininin merkezine göre: -Z ön (doğma noktası), +Z arka.

local WorldDecor = require(script.Parent:WaitForChild("WorldDecor"))

local ZoneVisualService = {}

type Builder = (decor: Model, origin: CFrame, size: Vector3) -> ()

local WOOD = Color3.fromRGB(150, 110, 70)
local DARK_WOOD = Color3.fromRGB(100, 70, 45)
local ROOF = Color3.fromRGB(70, 60, 55)
local STRAW = Color3.fromRGB(225, 195, 110)
local WATER = Color3.fromRGB(70, 160, 220)
local METAL = Color3.fromRGB(150, 155, 160)
local STONE_COLOR = Color3.fromRGB(128, 126, 118)

local LOCKED_GROUND = Color3.fromRGB(150, 120, 90)

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

-- Çiftlik numarasına (= tema) göre ana adadaki inek ağılı ve otlağın görünümü
local THEME_LOOKS: { { barn: Color3, pasture: string } } = {
	{ barn = Color3.fromRGB(170, 45, 38), pasture = "daisy" },
	{ barn = Color3.fromRGB(55, 105, 175), pasture = "tulip" },
	{ barn = Color3.fromRGB(205, 150, 45), pasture = "sunflower" },
	{ barn = Color3.fromRGB(215, 120, 140), pasture = "rose" },
	{ barn = Color3.fromRGB(60, 105, 65), pasture = "pine" },
	{ barn = Color3.fromRGB(225, 205, 170), pasture = "cherry" },
}
local currentLook = THEME_LOOKS[1]
local barnColor = currentLook.barn

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

local BUILDERS: { [string]: Builder } = {
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
			barnColor,
			Enum.Material.WoodPlanks
		)
		for _, x in { -1, 1 } do
			part(
				decor,
				"SideWall",
				Vector3.new(0.8, 6.5, zBack - zFront),
				o * CFrame.new(x * (hx - 1), 3.25, (zFront + zBack) / 2),
				barnColor,
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

	-- Süt Adası çayırı: ağıl yapısı, çevresi açık
	dairy = function(decor, o, size)
		BUILDERS.starter(decor, o, size)
	end,

	-- Otlak: balyalar, suluk, çiçekler
	pasture = function(decor, o, size)
		local hx, hz = size.X / 2, size.Z / 2
		hayBale(decor, o * CFrame.new(-(hx - 4), 0, hz - 3))
		hayBale(decor, o * CFrame.new(-(hx - 7), 0, hz - 3))
		hayBale(decor, o * CFrame.new(-(hx - 5.5), 1.6, hz - 3))
		waterTrough(decor, o * CFrame.new(hx - 3, 0, -(hz - 6)), 6)
		local style = PASTURE_STYLES[currentLook.pasture]
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

local function getGround(zone: Instance): BasePart?
	local ground = zone:FindFirstChild("Ground")
	if ground and ground:IsA("BasePart") then
		return ground
	end
	return nil
end

-- Bölge geliştirme bayrakları: her seviye için bölgenin ön kenarında bir flama (renk = o seviyenin türü).
-- Seviye değişince yenilenir; kinds boşsa kaldırılır.
local FLAG_COLORS: { [string]: Color3 } = {
	growth = Color3.fromRGB(96, 190, 110),
	income = Color3.fromRGB(245, 195, 70),
	season = Color3.fromRGB(96, 170, 230),
	capacity = Color3.fromRGB(235, 232, 220),
}
function ZoneVisualService.applyLevelFlags(zone: Instance, kinds: { string })
	local signature = table.concat(kinds, ",")
	local existing = zone:FindFirstChild("LevelFlags")
	if existing and existing:GetAttribute("Signature") == signature then
		return
	end
	if existing then
		existing:Destroy()
	end
	local ground = getGround(zone)
	if not ground or #kinds == 0 then
		return
	end
	local model = Instance.new("Model")
	model.Name = "LevelFlags"
	model:SetAttribute("Signature", signature)
	local top = ground.CFrame * CFrame.new(0, ground.Size.Y / 2, 0)
	for index, kind in kinds do
		local x = -ground.Size.X / 2 + 2.2 + (index - 1) * 2.4
		local z = -ground.Size.Z / 2 + 1.4
		local pole = part(
			model,
			"FlagPole",
			Vector3.new(0.25, 5, 0.25),
			top * CFrame.new(x, 2.5, z),
			Color3.fromRGB(235, 235, 235),
			Enum.Material.Metal
		)
		pole.CanCollide = false
		local cloth = part(
			model,
			"Flag",
			Vector3.new(1.7, 1.05, 0.08),
			top * CFrame.new(x + 0.95, 4.4, z),
			FLAG_COLORS[kind] or FLAG_COLORS.capacity,
			Enum.Material.Fabric
		)
		cloth.CanCollide = false
	end
	model.Parent = zone
end

function ZoneVisualService.apply(zone: Instance, zoneId: string, unlocked: boolean)
	local ground = getGround(zone)
	if not ground then
		return
	end

	local openColor = ground:GetAttribute("OpenColor")
	if typeof(openColor) ~= "Color3" then
		openColor = ground.Color
		ground:SetAttribute("OpenColor", openColor)
	end
	if ground:GetAttribute("Locked") ~= not unlocked then
		ground.Color = if unlocked then openColor :: Color3 else LOCKED_GROUND
		ground:SetAttribute("Locked", not unlocked)
	end

	local existing = zone:FindFirstChild("Decor")
	if not unlocked then
		if existing then
			existing:Destroy()
		end
		return
	end
	local builder = BUILDERS[zoneId]
	if existing or not builder then
		return
	end

	local decor = Instance.new("Model")
	decor.Name = "Decor"
	decor:SetAttribute("VisualCreatedAt", game:GetService("Workspace"):GetServerTimeNow())
	local origin = ground.CFrame * CFrame.new(0, ground.Size.Y / 2, 0)
	local plot = zone.Parent and zone.Parent.Parent
	local farmIndex = tonumber(plot and plot:GetAttribute("PlotId")) or 1
	currentLook = THEME_LOOKS[((farmIndex - 1) % #THEME_LOOKS) + 1]
	barnColor = currentLook.barn
	builder(decor, origin, ground.Size)
	-- Çimenli zeminlere çim tutamı ve çiçek (ön/orta şerit; arkadaki barınak ve yemlikler hariç)
	if ground.Material == Enum.Material.Grass and zoneId ~= "fishpen" then
		local backReserve = ground:GetAttribute("BackReserve")
		local reserve = if typeof(backReserve) == "number" then backReserve else 4
		local hz = ground.Size.Z / 2
		WorldDecor.grassTufts(decor, origin, {
			count = 30,
			seed = #zoneId * 131 + math.floor(ground.Position.X + ground.Position.Z),
			halfX = ground.Size.X / 2 - 2,
			zMin = -hz + 2,
			zMax = hz - reserve - 8,
			flowerChance = 0.18,
		})
	end
	do
		local parts = 0
		for _, descendant in decor:GetDescendants() do
			if descendant:IsA("BasePart") then
				parts += 1
			end
		end
		decor:SetAttribute("PartCount", parts)
	end
	WorldDecor.optimize(decor)
	decor.Parent = zone
end

return ZoneVisualService
