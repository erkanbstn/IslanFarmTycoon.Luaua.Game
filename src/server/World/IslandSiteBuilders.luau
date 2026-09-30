--!strict
-- Uzman ada yapı kurucuları: at eğitimi, kümes, keçi kayalığı, ördek koyu, koyun tepesi, trüf korusu ve süt yükleme alanı.

local WorldDecor = require(script.Parent:WaitForChild("WorldDecor"))
local IslandSiteParts = require(script.Parent:WaitForChild("IslandSiteParts"))

local WOOD = IslandSiteParts.WOOD
local CREAM = IslandSiteParts.CREAM
local STRAW = IslandSiteParts.STRAW
local ROCK = IslandSiteParts.ROCK
local part = IslandSiteParts.part
local surface = IslandSiteParts.surface

local function horse(parent: Instance, cf: CFrame)
	-- Dar oval koşu yolu ağıldan ayrı batı şeridindedir: x=-35..-17, z=-19..19.
	local track = Instance.new("Model")
	track.Name = "TrainingTrack"
	track.Parent = parent
	local count = 24
	for index = 1, count do
		local a, b = (index - 1) / count * math.pi * 2, index / count * math.pi * 2
		local from = (cf * CFrame.new(-26 + math.cos(a) * 6, 0, math.sin(a) * 16)).Position
		local to = (cf * CFrame.new(-26 + math.cos(b) * 6, 0, math.sin(b) * 16)).Position
		local segment = surface(
			track,
			"TrackSand",
			CFrame.lookAt((from + to) / 2, to),
			Vector2.new(4, (to - from).Magnitude + 0.5),
			Color3.fromRGB(180, 151, 107),
			Enum.Material.Sand
		)
		segment:SetAttribute("OutsideAnimalZone", true)
	end
	for index, z in { -8, 7 } do
		local base = cf * CFrame.new(-26, 0, z)
		for _, x in { -2.8, 2.8 } do
			part(
				track,
				"JumpStandard",
				Vector3.new(0.5, 3.4, 0.6),
				base * CFrame.new(x, 1.7, 0),
				CREAM,
				Enum.Material.Wood
			)
		end
		for _, height in { 1.3, 2.3 } do
			local rail = part(
				track,
				"TrainingRail",
				Vector3.new(5.6, 0.25, 0.25),
				base * CFrame.new(0, height, 0),
				if index == 1 then Color3.fromRGB(190, 70, 55) else Color3.fromRGB(65, 100, 157),
				Enum.Material.Wood
			)
			rail.CanCollide = false
		end
	end
	WorldDecor.path(parent, (cf * CFrame.new(-3, 0, -24)).Position, (cf * CFrame.new(-19, 0, -24)).Position, 3)
	WorldDecor.path(parent, (cf * CFrame.new(3, 0, -17)).Position, (cf * CFrame.new(25, 0, -13)).Position, 3)
	WorldDecor.barrel(parent, cf * CFrame.new(30, 0, 17))
end

local function poultry(parent: Instance, cf: CFrame)
	-- Açık folluk bahçesi doğu tarafında; satın alınan kuluçkahane batıda kalır.
	local garden = Instance.new("Model")
	garden.Name = "NestingGarden"
	garden.Parent = parent
	surface(garden, "StrawYard", cf * CFrame.new(25, 0, 3), Vector2.new(14, 25), STRAW, Enum.Material.Sand)
	for index, z in { -5, 2, 9 } do
		local base = cf * CFrame.new(28, 0, z)
		part(
			garden,
			"NestFloor",
			Vector3.new(4.5, 0.35, 4),
			base * CFrame.new(0, 0.55, 0),
			WOOD,
			Enum.Material.WoodPlanks
		)
		part(
			garden,
			"NestBack",
			Vector3.new(4.5, 2.4, 0.3),
			base * CFrame.new(0, 1.8, 1.8),
			WOOD,
			Enum.Material.WoodPlanks
		)
		for _, side in { -2.1, 2.1 } do
			part(
				garden,
				"NestSide",
				Vector3.new(0.3, 2.4, 4),
				base * CFrame.new(side, 1.8, 0),
				CREAM,
				Enum.Material.WoodPlanks
			)
		end
		part(
			garden,
			"NestRoof",
			Vector3.new(5, 0.35, 4.4),
			base * CFrame.new(0, 3.15, 0) * CFrame.Angles(0.06, 0, 0),
			Color3.fromRGB(161, 72, 49),
			Enum.Material.WoodPlanks
		)
		local straw = part(
			garden,
			"NestStraw",
			Vector3.new(3.7, 0.25, 3.3),
			base * CFrame.new(0, 0.85, 0),
			STRAW,
			Enum.Material.Grass
		)
		straw.CanCollide = false
		WorldDecor.flowerPatch(parent, cf * CFrame.new(21, 0, 18 + index), index * 13)
	end
	WorldDecor.path(parent, (cf * CFrame.new(3, 0, -20)).Position, (cf * CFrame.new(23, 0, -19)).Position, 3)
	WorldDecor.path(parent, (cf * CFrame.new(-3, 0, -17)).Position, (cf * CFrame.new(-25, 0, -7)).Position, 3)
	WorldDecor.crate(parent, cf * CFrame.new(-20, 0, 21), 2)
end

local function goat(parent: Instance, cf: CFrame)
	local terraces = Instance.new("Model")
	terraces.Name = "HillsideTerraces"
	terraces.Parent = parent
	for index = 1, 3 do
		local height = index * 1.2
		local width = 15 - index
		local z = -12 + (index - 1) * 10
		local base = cf * CFrame.new(-26, 0, z)
		part(
			terraces,
			"RetainingRock",
			Vector3.new(width, height, 8),
			base * CFrame.new(0, height / 2, 0),
			ROCK,
			Enum.Material.Rock
		)
		part(
			terraces,
			"TerraceGrass",
			Vector3.new(width - 0.3, 0.15, 7.7),
			base * CFrame.new(0, height + 0.075, 0),
			Color3.fromRGB(115, 138, 79),
			Enum.Material.Grass
		)
		-- Küçük yükseltiler her seviyeye yürüyerek çıkılabilsin diye basamaklara ayrılır.
		for step = 1, 3 do
			local stairHeight = math.max(0.4, height - 1.2 + step * 0.4)
			part(
				terraces,
				"TerraceStep",
				Vector3.new(4, stairHeight, 0.9),
				base * CFrame.new(2.5, stairHeight / 2, -6.3 + step * 0.8),
				ROCK,
				Enum.Material.Slate
			)
		end
		WorldDecor.bush(terraces, base * CFrame.new(-3, height + 0.15, 1.5), index * 17)
	end
	WorldDecor.path(parent, (cf * CFrame.new(-3, 0, -25)).Position, (cf * CFrame.new(-23, 0, -23)).Position, 3)
	-- Peynirhanenin önündeki yükleme alanı, ahırın arka şeridinden ayrıdır.
	surface(
		parent,
		"DairyApron",
		cf * CFrame.new(0, 0, 26),
		Vector2.new(15, 13),
		Color3.fromRGB(177, 169, 146),
		Enum.Material.Cobblestone
	)
	WorldDecor.path(parent, (cf * CFrame.new(22, 0, -17)).Position, (cf * CFrame.new(23, 0, 22)).Position, 3)
	WorldDecor.path(parent, (cf * CFrame.new(23, 0, 22)).Position, (cf * CFrame.new(9, 0, 25)).Position, 3)
	WorldDecor.barrel(parent, cf * CFrame.new(10, 0, 28))
	WorldDecor.barrel(parent, cf * CFrame.new(13, 0, 26))
end

-- Ördek koyu: kıyısı kumlu, kamışlı küçük bir göl ve iskele (ördekler suyun üstünde gezinir)
local function duckCove(parent: Instance, cf: CFrame)
	local water = part(
		parent,
		"CoveWater",
		Vector3.new(16, 0.2, 24),
		cf * CFrame.new(-26, 0.14, 0),
		Color3.fromRGB(80, 160, 205),
		Enum.Material.Glass
	)
	water.Transparency = 0.25
	water.CanCollide = false
	local sand = Color3.fromRGB(214, 198, 150)
	for _, z in { -12.6, 12.6 } do
		part(parent, "CoveBank", Vector3.new(18.4, 0.4, 1.6), cf * CFrame.new(-26, 0.2, z), sand, Enum.Material.Sand).CanCollide =
			false
	end
	for _, x in { -35, -17 } do
		part(parent, "CoveBank", Vector3.new(1.6, 0.4, 24), cf * CFrame.new(x, 0.2, 0), sand, Enum.Material.Sand).CanCollide =
			false
	end
	for index = 1, 6 do
		local z = -10 + (index - 1) * 4
		for _, x in { -34.4, -17.6 } do
			for blade = 1, 3 do
				local height = 2.6 + blade * 0.5
				local reed = part(
					parent,
					"Reed",
					Vector3.new(0.18, height, 0.18),
					cf * CFrame.new(x + (blade - 2) * 0.35, height / 2, z + (blade - 2) * 0.3),
					Color3.fromRGB(96, 150, 64),
					Enum.Material.Grass
				)
				reed.CanCollide = false
			end
		end
	end
	for index, spot in { Vector2.new(-30, -6), Vector2.new(-22, 4), Vector2.new(-28, 8), Vector2.new(-24, -9) } do
		local pad = part(
			parent,
			"LilyPad",
			Vector3.new(0.1, 2, 2),
			cf * CFrame.new(spot.X, 0.28, spot.Y) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(70, 150, 70),
			Enum.Material.LeafyGrass
		)
		pad.Shape = Enum.PartType.Cylinder
		pad.CanCollide = false
		if index % 2 == 1 then
			local lotus = part(
				parent,
				"Lotus",
				Vector3.new(0.6, 0.6, 0.6),
				cf * CFrame.new(spot.X, 0.6, spot.Y),
				Color3.fromRGB(245, 150, 190),
				Enum.Material.SmoothPlastic
			)
			lotus.Shape = Enum.PartType.Ball
			lotus.CanCollide = false
		end
	end
	part(parent, "CovePier", Vector3.new(6, 0.35, 3), cf * CFrame.new(-19, 0.32, -5), WOOD, Enum.Material.WoodPlanks)
	for _, z in { -6.2, -3.8 } do
		part(
			parent,
			"CovePierPost",
			Vector3.new(0.4, 1.4, 0.4),
			cf * CFrame.new(-16.4, 0.7, z),
			WOOD,
			Enum.Material.Wood
		)
	end
end

-- Yün yamacı: taş duvarlı, çiçekli yamaç otlağı ve çoban kulübesi
local function sheepHill(parent: Instance, cf: CFrame)
	local meadow = part(
		parent,
		"HillMeadow",
		Vector3.new(16, 0.2, 26),
		cf * CFrame.new(26, 0.12, 0),
		Color3.fromRGB(132, 184, 96),
		Enum.Material.Grass
	)
	meadow.CanCollide = false
	local stone = Color3.fromRGB(140, 138, 128)
	for _, z in { -13.4, 13.4 } do
		part(parent, "HillWall", Vector3.new(17.6, 1.1, 0.9), cf * CFrame.new(26, 0.55, z), stone, Enum.Material.Slate)
	end
	part(parent, "HillWall", Vector3.new(0.9, 1.1, 26.8), cf * CFrame.new(34.4, 0.55, 0), stone, Enum.Material.Slate)
	for _, z in { -8, 8 } do
		part(
			parent,
			"HillWall",
			Vector3.new(0.9, 1.1, 10),
			cf * CFrame.new(17.6, 0.55, z * 1.2),
			stone,
			Enum.Material.Slate
		)
	end
	for index, spot in
		{ Vector2.new(22, -7), Vector2.new(30, -3), Vector2.new(24, 6), Vector2.new(31, 9), Vector2.new(27, 1) }
	do
		WorldDecor.flowerPatch(parent, cf * CFrame.new(spot.X, 0, spot.Y), 40 + index)
	end
	-- Çoban kulübesi: içine girilebilen küçük yapı
	local hut = cf * CFrame.new(30, 0, 19.5)
	part(parent, "HutFloor", Vector3.new(8, 0.5, 6.4), hut * CFrame.new(0, 0.25, 0), WOOD, Enum.Material.WoodPlanks)
	local wall = Color3.fromRGB(220, 208, 176)
	part(parent, "HutBack", Vector3.new(8, 7.2, 0.4), hut * CFrame.new(0, 4.1, 3), wall, Enum.Material.Plaster)
	for _, side in { -1, 1 } do
		part(
			parent,
			"HutSide",
			Vector3.new(0.4, 7.2, 6.4),
			hut * CFrame.new(side * 3.8, 4.1, 0),
			wall,
			Enum.Material.Plaster
		)
		part(
			parent,
			"HutFront",
			Vector3.new(1.6, 7.2, 0.4),
			hut * CFrame.new(side * 3.2, 4.1, -3),
			wall,
			Enum.Material.Plaster
		)
	end
	part(parent, "HutHeader", Vector3.new(4.8, 0.8, 0.4), hut * CFrame.new(0, 7.3, -3), wall, Enum.Material.Plaster)
	for _, side in { -1, 1 } do
		part(
			parent,
			"HutRoof",
			Vector3.new(4.9, 0.4, 7.4),
			hut * CFrame.new(side * 2.2, 8.9, 0) * CFrame.Angles(0, 0, side * math.rad(-28)),
			Color3.fromRGB(150, 70, 60),
			Enum.Material.Slate
		)
	end
	part(
		parent,
		"HutStep",
		Vector3.new(4.8, 0.4, 1.4),
		hut * CFrame.new(0, 0.2, -3.9),
		stone,
		Enum.Material.Cobblestone
	)
end

-- Trüf korusu: koyu topraklı açıklık, çam halkası, mantarlar ve kütük çit
local function truffleGrove(parent: Instance, cf: CFrame)
	local soil = part(
		parent,
		"GroveSoil",
		Vector3.new(16, 0.2, 26),
		cf * CFrame.new(-26, 0.12, 0),
		Color3.fromRGB(86, 64, 46),
		Enum.Material.Ground
	)
	soil.CanCollide = false
	for index, spot in
		{
			Vector2.new(-35, -14),
			Vector2.new(-35, 0),
			Vector2.new(-35, 14),
			Vector2.new(-17, -14),
			Vector2.new(-17, 14),
			Vector2.new(-26, 15.5),
		}
	do
		WorldDecor.pineTree(parent, cf * CFrame.new(spot.X, 0, spot.Y), 70 + index * 5)
	end
	for _, spot in
		{ Vector2.new(-31, -6), Vector2.new(-22, -9), Vector2.new(-29, 5), Vector2.new(-21, 7), Vector2.new(-26, -1) }
	do
		part(
			parent,
			"MushroomStem",
			Vector3.new(0.4, 0.9, 0.4),
			cf * CFrame.new(spot.X, 0.55, spot.Y),
			Color3.fromRGB(240, 230, 210),
			Enum.Material.SmoothPlastic
		).CanCollide =
			false
		local cap = part(
			parent,
			"MushroomCap",
			Vector3.new(1.3, 0.7, 1.3),
			cf * CFrame.new(spot.X, 1.1, spot.Y),
			Color3.fromRGB(196, 60, 52),
			Enum.Material.SmoothPlastic
		)
		cap.Shape = Enum.PartType.Ball
		cap.CanCollide = false
	end
	for _, z in { -10, -5 } do
		local log = part(
			parent,
			"GroveLog",
			Vector3.new(0.8, 0.8, 5),
			cf * CFrame.new(-17.8, 0.5, z),
			Color3.fromRGB(110, 78, 50),
			Enum.Material.Wood
		)
		log.CanCollide = false
	end
end

local function home(parent: Instance, cf: CFrame)
	WorldDecor.path(parent, (cf * CFrame.new(20, 0, -17)).Position, (cf * CFrame.new(31, 0, -30)).Position, 4)
	WorldDecor.path(parent, (cf * CFrame.new(31, 0, -30)).Position, (cf * CFrame.new(43, 0, -30)).Position, 4)
	for index = 1, 4 do
		local stripe = surface(
			parent,
			"LoadingBayStripe",
			cf * CFrame.new(35 + index * 3, 0.2, -32),
			Vector2.new(0.3, 4),
			STRAW,
			Enum.Material.SmoothPlastic
		)
		stripe.CanQuery = false
	end
	WorldDecor.crate(parent, cf * CFrame.new(56, 0, -24), 2.2)
	WorldDecor.crate(parent, cf * CFrame.new(56, 0, -20), 2.2)
end

return {
	horse = horse,
	poultry = poultry,
	goat = goat,
	duckCove = duckCove,
	sheepHill = sheepHill,
	truffleGrove = truffleGrove,
	home = home,
}
