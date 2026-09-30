--!strict
-- Yol haritasından alınan güçlendirmeleri adada bina olarak gösterir (silo, süt makinesi...).
-- Konum: plot içindeki BuildSpots klasöründe "<upgradeId>" adlı görünmez parça.
-- Kendi modelini kullanmak için: ServerStorage.Assets.Buildings içine upgrade id'si
-- ile aynı isimde bir Model koy (ör. "silo"). Model'in pivotu zemine oturmalı.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerStorage = game:GetService("ServerStorage")
local AssetSanitizer = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("AssetSanitizer"))
local InstanceUtil = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("InstanceUtil"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))
local WorldDecor = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("WorldDecor"))

type PlayerSave = GameTypes.PlayerSave
type Builder = (model: Model, base: CFrame) -> ()

local UpgradeVisualService = {}

local METAL = Color3.fromRGB(190, 195, 200)
local GOLD = Color3.fromRGB(255, 200, 60)
local VISUAL_VERSION = 2
local PRODUCTION_RECIPES: { [string]: string } = {
	milk_factory = "dairy",
	hatchery = "hatchery",
	horse_training = "horse_training",
	cheese_dairy = "cheese",
	duck_house = "duck_eggs",
	wool_mill = "wool",
	truffle_kitchen = "truffle",
}

local function makePart(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- Dik silindir (Part silindirinin ekseni X olduğu için döndürülür)
local function makeColumn(
	model: Model,
	name: string,
	diameter: number,
	height: number,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = makePart(
		model,
		name,
		Vector3.new(height, diameter, diameter),
		cframe * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function makeBall(
	model: Model,
	name: string,
	diameter: number,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = makePart(model, name, Vector3.one * diameter, cframe, color, material)
	part.Shape = Enum.PartType.Ball
	return part
end

local function beam(model: Model, name: string, from: Vector3, to: Vector3, width: number, color: Color3): Part
	return makePart(
		model,
		name,
		Vector3.new(width, width, (to - from).Magnitude),
		CFrame.lookAt((from + to) / 2, to),
		color,
		Enum.Material.Metal
	)
end

local function sign(model: Model, at: CFrame, title: string, text: string, icon: string, width: number)
	local board = makePart(
		model,
		"ProductionSign",
		Vector3.new(width, 1.7, 0.16),
		at,
		Color3.fromRGB(39, 66, 77),
		Enum.Material.Metal
	)
	board.CanCollide = false
	WorldUi.sign(board, Enum.NormalId.Front, { title = title, text = text, icon = icon })
end

-- Wedge'ın eğimi Y/Z düzlemindedir. Z çevresinde ±90° döndürüp çift kullanarak
-- yatayda daralan, ortası birleşik ve gövdeyle örtüşen gerçek bir sivri burun oluşur.
local function taperedBow(
	model: Model,
	name: string,
	base: CFrame,
	halfWidth: number,
	height: number,
	length: number,
	y: number,
	z: number,
	color: Color3,
	material: Enum.Material
)
	for _, side in { -1, 1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = name
		wedge.Size = Vector3.new(height, halfWidth, length)
		wedge.CFrame = base * CFrame.new(side * halfWidth / 2, y, z) * CFrame.Angles(0, 0, -side * math.pi / 2)
		wedge.Color = color
		wedge.Material = material
		wedge.Anchored = true
		wedge.CanCollide, wedge.CanTouch, wedge.CanQuery = false, false, false
		wedge.Parent = model
	end
end

local BUILDERS: { [string]: Builder } = {
	silo = function(model, base)
		makeColumn(model, "Tank", 7, 16, base * CFrame.new(0, 8, 0), METAL, Enum.Material.DiamondPlate)
		makeBall(model, "Dome", 7, base * CFrame.new(0, 16, 0), Color3.fromRGB(170, 45, 38), Enum.Material.Metal)
		for _, y in { 4, 9, 14 } do
			makeColumn(
				model,
				"Ring",
				7.3,
				0.5,
				base * CFrame.new(0, y, 0),
				Color3.fromRGB(120, 120, 125),
				Enum.Material.Metal
			)
		end
		makePart(
			model,
			"Chute",
			Vector3.new(1.2, 1.2, 5),
			base * CFrame.new(0, 3, -4) * CFrame.Angles(math.rad(-30), 0, 0),
			METAL,
			Enum.Material.Metal
		)
	end,

	milk_machine = function(model, base)
		makePart(
			model,
			"Body",
			Vector3.new(6, 5, 5),
			base * CFrame.new(0, 2.5, 0),
			Color3.fromRGB(240, 240, 245),
			Enum.Material.Metal
		)
		makeColumn(model, "MilkTank", 4, 6, base * CFrame.new(0, 8, 0), METAL, Enum.Material.Metal)
		makePart(
			model,
			"Label",
			Vector3.new(4, 1.5, 0.2),
			base * CFrame.new(0, 3, -2.6),
			Color3.fromRGB(60, 130, 230),
			Enum.Material.Neon
		)
		makePart(model, "Pipe", Vector3.new(0.8, 0.8, 6), base * CFrame.new(2, 1, -5), METAL, Enum.Material.Metal)
	end,

	milk_factory = function(model, base)
		local cream = Color3.fromRGB(238, 232, 215)
		local blue = Color3.fromRGB(63, 119, 148)
		makePart(model, "Factory", Vector3.new(12, 7, 10), base * CFrame.new(-2, 3.5, 0), cream, Enum.Material.Brick)
		makePart(
			model,
			"FactoryRoof",
			Vector3.new(13, 0.6, 11),
			base * CFrame.new(-2, 7.3, 0),
			blue,
			Enum.Material.Metal
		)
		makePart(
			model,
			"LoadingApron",
			Vector3.new(13, 0.35, 2),
			base * CFrame.new(-1.5, 0.175, -6),
			Color3.fromRGB(150, 151, 145),
			Enum.Material.Concrete
		)
		makePart(
			model,
			"LoadingDoor",
			Vector3.new(3.3, 4, 0.18),
			base * CFrame.new(-2, 2, -5.12),
			blue,
			Enum.Material.Metal
		)
		for _, x in { -6, 2 } do
			makePart(
				model,
				"FactoryWindow",
				Vector3.new(2.1, 1.8, 0.16),
				base * CFrame.new(x, 3.7, -5.1),
				Color3.fromRGB(162, 212, 223),
				Enum.Material.Glass
			)
		end
		for _, z in { -2.8, 2.8 } do
			makeColumn(model, "PasteurizingTank", 3.2, 8, base * CFrame.new(6.6, 4, z), METAL, Enum.Material.Metal)
			makeBall(model, "TankCap", 3.2, base * CFrame.new(6.6, 8, z), METAL, Enum.Material.Metal)
			makePart(
				model,
				"TankPipe",
				Vector3.new(3.6, 0.45, 0.45),
				base * CFrame.new(5.1, 2, z),
				METAL,
				Enum.Material.Metal
			)
		end
		for index = 1, 3 do
			local carton = makePart(
				model,
				"MilkCarton",
				Vector3.new(0.65, 1.1, 0.65),
				base * CFrame.new(1.9 + index * 0.8, 0.95, -6),
				cream
			)
			makePart(model, "CartonBand", Vector3.new(0.67, 0.3, 0.67), carton.CFrame, blue)
		end
		sign(model, base * CFrame.new(-2, 5.65, -5.2), "Süt Fabrikası", "İşleme ve paketleme", "🥛", 8)
	end,

	hatchery = function(model, base)
		local yellow = Color3.fromRGB(245, 216, 127)
		local roof = Color3.fromRGB(95, 140, 121)
		makePart(
			model,
			"IncubatorBuilding",
			Vector3.new(10, 6, 8),
			base * CFrame.new(0, 3, 2),
			Color3.fromRGB(242, 230, 200),
			Enum.Material.Brick
		)
		makePart(
			model,
			"HatcheryRoof",
			Vector3.new(11, 0.55, 9),
			base * CFrame.new(0, 6.28, 2),
			roof,
			Enum.Material.Slate
		)
		makePart(
			model,
			"IncubatorWindow",
			Vector3.new(7.8, 2, 0.16),
			base * CFrame.new(0, 3, -2.12),
			Color3.fromRGB(166, 212, 216),
			Enum.Material.Glass
		)
		makePart(
			model,
			"Conveyor",
			Vector3.new(11, 0.35, 2.2),
			base * CFrame.new(0, 1.5, -5),
			Color3.fromRGB(65, 73, 70),
			Enum.Material.Metal
		)
		for _, x in { -4.5, 4.5 } do
			makePart(
				model,
				"ConveyorLeg",
				Vector3.new(0.5, 1.5, 1.5),
				base * CFrame.new(x, 0.75, -5),
				METAL,
				Enum.Material.Metal
			)
		end
		for index = 1, 5 do
			local x = -4.4 + index * 1.2
			local egg =
				makeBall(model, "IncubatingEgg", 0.7, base * CFrame.new(x, 2, -5), Color3.fromRGB(255, 250, 231))
			egg.Size = Vector3.new(0.65, 0.85, 0.65)
		end
		for index = 1, 2 do
			local chick = base * CFrame.new(2.8 + index * 0.8, 2, -5)
			makeBall(model, "ChickBody", 0.7, chick, yellow)
			makeBall(model, "ChickHead", 0.48, chick * CFrame.new(0, 0.4, -0.2), yellow)
			makePart(
				model,
				"ChickBeak",
				Vector3.new(0.16, 0.12, 0.22),
				chick * CFrame.new(0, 0.38, -0.48),
				Color3.fromRGB(232, 142, 47)
			)
			for _, side in { -1, 1 } do
				makeBall(
					model,
					"ChickEye",
					0.07,
					chick * CFrame.new(side * 0.17, 0.47, -0.37),
					Color3.fromRGB(37, 39, 33)
				)
			end
		end
		sign(model, base * CFrame.new(0, 5, -2.2), "Kuluçkahane", "Yumurta ve civciv", "🐣", 8)
	end,

	horse_training = function(model, base)
		local timber = Color3.fromRGB(126, 90, 60)
		makePart(
			model,
			"TrainingSand",
			Vector3.new(13.5, 0.2, 17.5),
			base * CFrame.new(0, 0.1, 0),
			Color3.fromRGB(212, 191, 147),
			Enum.Material.Sand
		)
		for _, x in { -6.2, 6.2 } do
			for _, z in { -7.8, 0, 7.8 } do
				makePart(
					model,
					"FencePost",
					Vector3.new(0.45, 2.6, 0.45),
					base * CFrame.new(x, 1.3, z),
					timber,
					Enum.Material.Wood
				)
			end
			makePart(
				model,
				"FenceRail",
				Vector3.new(0.25, 0.3, 16),
				base * CFrame.new(x, 2, 0),
				timber,
				Enum.Material.Wood
			)
		end
		for _, z in { -3.5, 2.8 } do
			for _, x in { -4.4, 4.4 } do
				makePart(
					model,
					"JumpStandard",
					Vector3.new(0.5, 2.8, 0.7),
					base * CFrame.new(x, 1.4, z),
					Color3.fromRGB(240, 235, 218),
					Enum.Material.Wood
				)
			end
			for index = 1, 8 do
				makePart(
					model,
					"JumpRail",
					Vector3.new(1.08, 0.24, 0.24),
					base * CFrame.new(-4.32 + (index - 0.5) * 1.08, 1.7, z),
					if index % 2 == 0 then Color3.fromRGB(186, 65, 54) else Color3.fromRGB(242, 235, 214),
					Enum.Material.Wood
				)
			end
		end
		makePart(
			model,
			"TackShelterRoof",
			Vector3.new(7, 0.4, 3),
			base * CFrame.new(0, 4, 6.6),
			Color3.fromRGB(132, 62, 47),
			Enum.Material.Slate
		)
		for _, x in { -3, 3 } do
			makePart(
				model,
				"ShelterPost",
				Vector3.new(0.4, 4, 0.4),
				base * CFrame.new(x, 2, 7.4),
				timber,
				Enum.Material.Wood
			)
		end
		makePart(
			model,
			"SaddleRack",
			Vector3.new(3, 1.3, 1.2),
			base * CFrame.new(0, 0.85, 6.7),
			timber,
			Enum.Material.Wood
		)
		makePart(
			model,
			"Saddle",
			Vector3.new(2.1, 0.45, 1.5),
			base * CFrame.new(0, 1.7, 6.7),
			Color3.fromRGB(91, 51, 34),
			Enum.Material.Fabric
		)
		sign(model, base * CFrame.new(0, 3.15, 5.05), "At Eğitim Alanı", "Antrenman istasyonu", "🏇", 6.4)
	end,

	auto_collector = function(model, base)
		makePart(
			model,
			"Tower",
			Vector3.new(3, 10, 3),
			base * CFrame.new(0, 5, 0),
			Color3.fromRGB(80, 85, 95),
			Enum.Material.DiamondPlate
		)
		makeBall(model, "Core", 3.5, base * CFrame.new(0, 11.5, 0), Color3.fromRGB(60, 230, 110), Enum.Material.Neon)
		makePart(model, "Arm", Vector3.new(8, 0.8, 0.8), base * CFrame.new(-4, 8, 0), METAL, Enum.Material.Metal)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(60, 230, 110)
		light.Range = 14
		light.Parent = model:FindFirstChild("Core")
	end,

	-- Ördek Kulübesi: kıyıda mavi tahta kulübe, çatıda dev sarı ördek heykeli
	duck_house = function(model, base)
		makePart(
			model,
			"Building",
			Vector3.new(10, 6, 8),
			base * CFrame.new(0, 3, 0),
			Color3.fromRGB(88, 150, 175),
			Enum.Material.WoodPlanks
		)
		makePart(
			model,
			"Roof",
			Vector3.new(11, 0.9, 9),
			base * CFrame.new(0, 6.4, 0),
			Color3.fromRGB(130, 85, 55),
			Enum.Material.Slate
		)
		makePart(
			model,
			"Door",
			Vector3.new(2.8, 4.4, 0.3),
			base * CFrame.new(0, 2.2, -4.1),
			Color3.fromRGB(110, 70, 40),
			Enum.Material.Wood
		)
		for _, x in { -3.2, 3.2 } do
			local window = makePart(
				model,
				"Window",
				Vector3.new(1.8, 1.6, 0.2),
				base * CFrame.new(x, 3.6, -4.05),
				Color3.fromRGB(120, 180, 220),
				Enum.Material.Glass
			)
			WorldDecor.markNightWindow(window)
		end
		local duck = makeBall(
			model,
			"DuckBody",
			4,
			base * CFrame.new(0, 9, 0),
			Color3.fromRGB(255, 215, 60),
			Enum.Material.SmoothPlastic
		)
		duck.Size = Vector3.new(4.4, 3.4, 5.4)
		makeBall(
			model,
			"DuckHead",
			2.4,
			base * CFrame.new(0, 11.3, -2.1),
			Color3.fromRGB(255, 215, 60),
			Enum.Material.SmoothPlastic
		)
		makePart(
			model,
			"DuckBill",
			Vector3.new(1.3, 0.5, 1.2),
			base * CFrame.new(0, 11.1, -3.6),
			Color3.fromRGB(245, 140, 40),
			Enum.Material.SmoothPlastic
		)
	end,

	-- Yün Değirmeni: taş yapı, çatıda dev yün yumağı ve dönen bir çarkın çerçevesi
	wool_mill = function(model, base)
		makePart(
			model,
			"Building",
			Vector3.new(10, 6, 8),
			base * CFrame.new(0, 3, 0),
			Color3.fromRGB(232, 222, 198),
			Enum.Material.Brick
		)
		makePart(
			model,
			"Roof",
			Vector3.new(11, 0.9, 9),
			base * CFrame.new(0, 6.4, 0),
			Color3.fromRGB(150, 70, 60),
			Enum.Material.Slate
		)
		makePart(
			model,
			"Door",
			Vector3.new(2.8, 4.4, 0.3),
			base * CFrame.new(0, 2.2, -4.1),
			Color3.fromRGB(110, 70, 40),
			Enum.Material.Wood
		)
		for _, x in { -3.2, 3.2 } do
			local window = makePart(
				model,
				"Window",
				Vector3.new(1.8, 1.6, 0.2),
				base * CFrame.new(x, 3.6, -4.05),
				Color3.fromRGB(120, 180, 220),
				Enum.Material.Glass
			)
			WorldDecor.markNightWindow(window)
		end
		local wool = makeBall(
			model,
			"WoolBall",
			4.6,
			base * CFrame.new(0, 9.4, 0),
			Color3.fromRGB(246, 242, 232),
			Enum.Material.Fabric
		)
		wool.CanCollide = false
		makeColumn(
			model,
			"Spindle",
			0.5,
			4.2,
			base * CFrame.new(0, 8.6, 0),
			Color3.fromRGB(120, 85, 55),
			Enum.Material.Wood
		)
		for _, x in { -1, 1 } do
			makePart(
				model,
				"Skein",
				Vector3.new(0.9, 1.6, 0.9),
				base * CFrame.new(x * 5.6, 1.2, -3),
				Color3.fromRGB(200, 90, 90),
				Enum.Material.Fabric
			).CanCollide =
				false
		end
	end,

	-- Trüf Mutfağı: koyu ahşap kulübe, bacası ve çatıda dev mantar
	truffle_kitchen = function(model, base)
		makePart(
			model,
			"Building",
			Vector3.new(10, 6, 8),
			base * CFrame.new(0, 3, 0),
			Color3.fromRGB(96, 70, 52),
			Enum.Material.WoodPlanks
		)
		makePart(
			model,
			"Roof",
			Vector3.new(11, 0.9, 9),
			base * CFrame.new(0, 6.4, 0),
			Color3.fromRGB(70, 60, 55),
			Enum.Material.Slate
		)
		makePart(
			model,
			"Door",
			Vector3.new(2.8, 4.4, 0.3),
			base * CFrame.new(0, 2.2, -4.1),
			Color3.fromRGB(70, 48, 32),
			Enum.Material.Wood
		)
		for _, x in { -3.2, 3.2 } do
			local window = makePart(
				model,
				"Window",
				Vector3.new(1.8, 1.6, 0.2),
				base * CFrame.new(x, 3.6, -4.05),
				Color3.fromRGB(120, 180, 220),
				Enum.Material.Glass
			)
			WorldDecor.markNightWindow(window)
		end
		makePart(
			model,
			"Chimney",
			Vector3.new(1.6, 4, 1.6),
			base * CFrame.new(3.4, 8.4, 2),
			Color3.fromRGB(120, 118, 110),
			Enum.Material.Brick
		)
		makeColumn(
			model,
			"MushroomStem",
			1.8,
			3.4,
			base * CFrame.new(-2, 8.6, 0),
			Color3.fromRGB(240, 230, 210),
			Enum.Material.SmoothPlastic
		)
		local cap = makeBall(
			model,
			"MushroomCap",
			5,
			base * CFrame.new(-2, 10.8, 0),
			Color3.fromRGB(196, 60, 52),
			Enum.Material.SmoothPlastic
		)
		cap.Size = Vector3.new(5.4, 2.6, 5.4)
		for _, offset in { Vector3.new(-1, 1.6, -1.4), Vector3.new(1.2, 1.7, 0.6), Vector3.new(-0.2, 2, 1.4) } do
			makeBall(
				model,
				"MushroomDot",
				0.8,
				base * CFrame.new(-2 + offset.X, 10.8 + offset.Y - 0.9, offset.Z),
				Color3.fromRGB(250, 245, 235),
				Enum.Material.SmoothPlastic
			)
		end
	end,

	egg_factory = function(model, base)
		makePart(
			model,
			"Building",
			Vector3.new(10, 7, 8),
			base * CFrame.new(0, 3.5, 0),
			Color3.fromRGB(245, 215, 110),
			Enum.Material.Brick
		)
		makePart(
			model,
			"Roof",
			Vector3.new(11, 1, 9),
			base * CFrame.new(0, 7.5, 0),
			Color3.fromRGB(150, 60, 40),
			Enum.Material.Slate
		)
		local egg = makeBall(
			model,
			"Egg",
			4,
			base * CFrame.new(0, 10.5, 0),
			Color3.fromRGB(255, 250, 235),
			Enum.Material.SmoothPlastic
		)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(1, 1.35, 1)
		mesh.Parent = egg
		makePart(
			model,
			"Door",
			Vector3.new(3, 4, 0.3),
			base * CFrame.new(0, 2, -4.1),
			Color3.fromRGB(110, 70, 40),
			Enum.Material.Wood
		)
	end,

	golden_horseshoe = function(model, base)
		for _, x in { -4, 4 } do
			makePart(
				model,
				"Post",
				Vector3.new(1.2, 9, 1.2),
				base * CFrame.new(x, 4.5, 0),
				Color3.fromRGB(110, 80, 50),
				Enum.Material.Wood
			)
		end
		makePart(
			model,
			"Beam",
			Vector3.new(10, 1.2, 1.4),
			base * CFrame.new(0, 9.5, 0),
			Color3.fromRGB(110, 80, 50),
			Enum.Material.Wood
		)
		-- U şeklinde nal
		makePart(model, "ShoeL", Vector3.new(0.8, 3, 0.6), base * CFrame.new(-1.2, 12, 0), GOLD, Enum.Material.Neon)
		makePart(model, "ShoeR", Vector3.new(0.8, 3, 0.6), base * CFrame.new(1.2, 12, 0), GOLD, Enum.Material.Neon)
		makePart(
			model,
			"ShoeBottom",
			Vector3.new(3.2, 0.8, 0.6),
			base * CFrame.new(0, 10.6, 0),
			GOLD,
			Enum.Material.Neon
		)
	end,

	-- Peynirhane: krem renkli küçük bina, çatısında dev peynir tekerleği
	cheese_dairy = function(model, base)
		local wall = Color3.fromRGB(240, 225, 190)
		makePart(model, "Building", Vector3.new(10, 6, 8), base * CFrame.new(0, 3, 0), wall, Enum.Material.Brick)
		makePart(
			model,
			"Roof",
			Vector3.new(11, 0.8, 9),
			base * CFrame.new(0, 6.4, 0),
			Color3.fromRGB(120, 70, 45),
			Enum.Material.Slate
		)
		local wheel = makePart(
			model,
			"CheeseWheel",
			Vector3.new(1.4, 4.4, 4.4),
			base * CFrame.new(0, 9.2, 0) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(250, 200, 70),
			Enum.Material.SmoothPlastic
		)
		wheel.Shape = Enum.PartType.Cylinder
		makePart(
			model,
			"Door",
			Vector3.new(2.6, 3.6, 0.3),
			base * CFrame.new(0, 1.8, -4.1),
			Color3.fromRGB(110, 70, 40),
			Enum.Material.Wood
		)
		for _, x in { -3.2, 3.2 } do
			makePart(
				model,
				"Window",
				Vector3.new(1.6, 1.4, 0.2),
				base * CFrame.new(x, 3.6, -4.05),
				Color3.fromRGB(120, 180, 220),
				Enum.Material.Glass
			)
		end
	end,

	-- Su çizgisi y=0; omurga hafif su altında, güverte ve birleşik burun su üstündedir.
	fishing_boat = function(model, base)
		local hull = Color3.fromRGB(39, 88, 132)
		local trim = Color3.fromRGB(238, 232, 215)
		local deck = Color3.fromRGB(164, 128, 86)
		makePart(
			model,
			"Hull",
			Vector3.new(5.6, 1.8, 9.4),
			base * CFrame.new(0, 0.35, 1.2),
			hull,
			Enum.Material.WoodPlanks
		)
		taperedBow(model, "JoinedBow", base, 2.8, 1.8, 3.8, 0.35, -4.65, hull, Enum.Material.WoodPlanks)
		makePart(
			model,
			"Deck",
			Vector3.new(5.2, 0.18, 9.3),
			base * CFrame.new(0, 1.32, 1.15),
			deck,
			Enum.Material.WoodPlanks
		)
		taperedBow(model, "BowDeck", base, 2.6, 0.18, 3.7, 1.32, -4.6, deck, Enum.Material.WoodPlanks)
		for _, side in { -1, 1 } do
			makePart(
				model,
				"Gunwale",
				Vector3.new(0.2, 0.45, 9.4),
				base * CFrame.new(side * 2.8, 1.58, 1.2),
				trim,
				Enum.Material.Wood
			)
			beam(
				model,
				"BowRail",
				(base * CFrame.new(side * 2.8, 1.63, -3.3)).Position,
				(base * CFrame.new(0, 1.63, -6.55)).Position,
				0.18,
				trim
			)
			for _, z in { -1.5, 3.6 } do
				makeColumn(
					model,
					"Fender",
					0.42,
					1.05,
					base * CFrame.new(side * 3, 0.75, z),
					Color3.fromRGB(55, 62, 65),
					Enum.Material.SmoothPlastic
				)
			end
		end
		makePart(
			model,
			"TransomRail",
			Vector3.new(5.7, 0.45, 0.2),
			base * CFrame.new(0, 1.58, 5.9),
			trim,
			Enum.Material.Wood
		)
		makePart(
			model,
			"Wheelhouse",
			Vector3.new(3.6, 2.6, 3.4),
			base * CFrame.new(0, 2.7, 2.7),
			trim,
			Enum.Material.WoodPlanks
		)
		makePart(
			model,
			"CabinRoof",
			Vector3.new(4.1, 0.3, 3.9),
			base * CFrame.new(0, 4.15, 2.7),
			Color3.fromRGB(166, 62, 48),
			Enum.Material.Metal
		)
		makePart(
			model,
			"Windshield",
			Vector3.new(2.85, 1, 0.14),
			base * CFrame.new(0, 3.1, 0.94),
			Color3.fromRGB(115, 178, 191),
			Enum.Material.Glass
		)
		makePart(
			model,
			"WindshieldDivider",
			Vector3.new(0.12, 1.05, 0.18),
			base * CFrame.new(0, 3.1, 0.89),
			trim,
			Enum.Material.Metal
		)
		for _, side in { -1, 1 } do
			makePart(
				model,
				"SideWindow",
				Vector3.new(0.14, 1, 1.7),
				base * CFrame.new(side * 1.86, 3.1, 2.55),
				Color3.fromRGB(115, 178, 191),
				Enum.Material.Glass
			)
			makeBall(
				model,
				"NavigationLamp",
				0.22,
				base * CFrame.new(side * 1.9, 4.42, 1.2),
				if side < 0 then Color3.fromRGB(209, 61, 55) else Color3.fromRGB(61, 167, 118),
				Enum.Material.Neon
			)
		end
		makePart(
			model,
			"CabinDoor",
			Vector3.new(1.05, 1.8, 0.12),
			base * CFrame.new(0, 2.35, 4.45),
			Color3.fromRGB(74, 114, 127),
			Enum.Material.Wood
		)
		makeColumn(model, "Mast", 0.17, 3.1, base * CFrame.new(0, 4.85, 0.2), METAL, Enum.Material.Metal)
		makeBall(
			model,
			"MastLight",
			0.28,
			base * CFrame.new(0, 6.5, 0.2),
			Color3.fromRGB(255, 239, 189),
			Enum.Material.Neon
		)
		makePart(
			model,
			"FishCrate",
			Vector3.new(2.1, 0.65, 1.65),
			base * CFrame.new(-0.65, 1.76, -1.6),
			Color3.fromRGB(112, 87, 57),
			Enum.Material.WoodPlanks
		)
		makePart(
			model,
			"NetBundle",
			Vector3.new(1.2, 0.5, 1.8),
			base * CFrame.new(1.45, 1.68, -1.5),
			Color3.fromRGB(83, 107, 95),
			Enum.Material.Fabric
		)
		beam(
			model,
			"FishingBoom",
			(base * CFrame.new(0, 2.3, 5.2)).Position,
			(base * CFrame.new(0, 4.5, 7)).Position,
			0.2,
			METAL
		)
		beam(
			model,
			"FishingLine",
			(base * CFrame.new(0, 4.5, 7)).Position,
			(base * CFrame.new(0, 0.2, 7)).Position,
			0.035,
			Color3.fromRGB(201, 205, 193)
		)
	end,
}

local function cloneAsset(upgradeId: string): Model?
	local assets = ServerStorage:FindFirstChild("Assets") or ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Buildings")
	local template = folder and folder:FindFirstChild(upgradeId)
	if template and template:IsA("Model") then
		return AssetSanitizer.clone(template, true)
	end
	return nil
end

local function buildUpgrade(upgradeId: string, spot: BasePart, parent: Instance)
	local base = spot.CFrame
	local model = cloneAsset(upgradeId)
	if model then
		model:PivotTo(base)
	else
		local builder = BUILDERS[upgradeId]
		if not builder then
			return
		end
		model = Instance.new("Model")
		builder(model :: Model, base)
	end
	local built = model :: Model
	built.Name = upgradeId
	built:SetAttribute("UpgradeVisualVersion", VISUAL_VERSION)
	for _, descendant in built:GetDescendants() do
		if
			descendant:IsA("BasePart")
			and descendant.Name:find("Window")
			and descendant.Material == Enum.Material.Glass
		then
			WorldDecor.markNightWindow(descendant)
		end
	end
	WorldDecor.optimize(built)
	if upgradeId == "fishing_boat" then
		-- Hareket sadece client görselidir; tüm parçalar sunucuda da fizik dışıdır.
		for _, descendant in built:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide, descendant.CanTouch, descendant.CanQuery = false, false, false
			end
		end
		local root = makePart(built, "BoatRoot", Vector3.one * 0.1, base, METAL)
		root.Transparency = 1
		root.CanCollide, root.CanTouch, root.CanQuery = false, false, false
		built.PrimaryPart = root
		built.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		built:SetAttribute("BoatHomeCFrame", base)
		built:SetAttribute("BoatPatrolX", spot:GetAttribute("BoatPatrolX") or 6)
		built:SetAttribute("BoatPatrolZ", spot:GetAttribute("BoatPatrolZ") or 3)
		built:SetAttribute("BoatVisual", true)
	end
	local recipe = PRODUCTION_RECIPES[upgradeId]
	if recipe then
		local anchor =
			makePart(built, "ProductionPromptAnchor", Vector3.one * 0.2, base * CFrame.new(0, 2.5, -6), METAL)
		anchor.Transparency = 1
		anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ProductionPrompt"
		prompt.ActionText = "Üretim"
		local upgrade = Config.getUpgrade(upgradeId)
		prompt.ObjectText = if upgrade then upgrade.displayName else "Üretim Merkezi"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 13
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt:SetAttribute("ProductionRecipe", recipe)
		WorldUi.configureProximityPrompt(prompt)
		prompt.Parent = anchor
	end
	do
		local parts = 0
		for _, descendant in built:GetDescendants() do
			if descendant:IsA("BasePart") then
				parts += 1
			end
		end
		built:SetAttribute("PartCount", parts)
	end
	built:SetAttribute("VisualCreatedAt", game:GetService("Workspace"):GetServerTimeNow())
	built.Parent = parent
end

-- Yapım alanı: satın alınabilir ama henüz alınmamış bir binanın yeri. Toprak zemin, kazıklar, sarı şerit ve fiyatlı
-- küçük bir tabela; alınınca kaldırılır ve yerine bina kurulur (oyuncu neyin nereye geleceğini görür).
local SITE_HALF = 4.4

local function buildSite(upgrade: Config.UpgradeConfig, spot: BasePart, parent: Instance, price: number)
	local site = Instance.new("Model")
	site.Name = upgrade.id
	site:SetAttribute("UpgradeId", upgrade.id)
	local base = spot.CFrame
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): Part
		local p = makePart(site, name, size, base * offset, color, material)
		p.CanCollide = false
		p.CanQuery = false
		return p
	end
	piece(
		"Dirt",
		Vector3.new(SITE_HALF * 2, 0.3, SITE_HALF * 2),
		CFrame.new(0, 0.15, 0),
		Color3.fromRGB(128, 96, 66),
		Enum.Material.Ground
	)
	local tape = Color3.fromRGB(245, 205, 60)
	for _, corner in { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(1, 1), Vector2.new(-1, 1) } do
		local stake = piece(
			"Stake",
			Vector3.new(0.35, 2.6, 0.35),
			CFrame.new(corner.X * SITE_HALF, 1.3, corner.Y * SITE_HALF),
			Color3.fromRGB(150, 110, 70),
			Enum.Material.Wood
		)
		stake.CanCollide = true
	end
	-- Şeritler: dört kenar boyunca gerilmiş sarı bant
	for _, side in { -1, 1 } do
		piece(
			"TapeX",
			Vector3.new(SITE_HALF * 2, 0.12, 0.06),
			CFrame.new(0, 2.2, side * SITE_HALF),
			tape,
			Enum.Material.Fabric
		)
		piece(
			"TapeZ",
			Vector3.new(0.06, 0.12, SITE_HALF * 2),
			CFrame.new(side * SITE_HALF, 2.2, 0),
			tape,
			Enum.Material.Fabric
		)
	end
	-- Fiyat tabelası: ön köşede (yürüme yolunu kapatmaz: tahta yüksekte, direk ince)
	local pole = piece(
		"SignPole",
		Vector3.new(0.4, 6, 0.4),
		CFrame.new(0, 3, -SITE_HALF - 1.4),
		Color3.fromRGB(110, 80, 50),
		Enum.Material.Wood
	)
	pole.CanCollide = true
	local board = piece(
		"SiteSign",
		Vector3.new(5.6, 1.9, 0.3),
		CFrame.new(0, 6.6, -SITE_HALF - 1.4),
		Color3.fromRGB(85, 60, 40),
		Enum.Material.WoodPlanks
	)
	WorldUi.sign(board, Enum.NormalId.Front, {
		icon = upgrade.icon,
		title = upgrade.displayName,
		text = `Yapım alanı · {FarmMath.formatMoney(price)}`,
	})
	-- Tabelaya yaklaşınca "Satın al": satın almayı BuyPadService sunucuda doğrular (UpgradeService.tryBuy).
	local promptAnchor =
		piece("SitePromptAnchor", Vector3.one * 0.2, CFrame.new(0, 2.6, -SITE_HALF - 1.4), METAL, Enum.Material.Metal)
	promptAnchor.Transparency = 1
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuySitePrompt"
	prompt.ActionText = "Satın al"
	prompt.ObjectText = upgrade.displayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Locked", true) -- IslandPrompts: yalnızca sahibine görünür
	prompt:SetAttribute("UpgradeId", upgrade.id)
	WorldUi.configureProximityPrompt(prompt)
	prompt.Parent = promptAnchor
	site.Parent = parent
end

-- Tesis geliştirme seviyesi dünyada görünür: binanın dibinde seviye kadar altın halka ve üstünde "Sv.N" etiketi.
-- Kurulu değilse ya da seviye 0 ise çizilmez; seviye değişince yenilenir.
local function applyLevelMarks(plot: Model, spots: Instance, save: PlayerSave?)
	local marksFolder = InstanceUtil.getOrCreateFolder(plot, "LevelMarks")
	for upgradeId, recipeId in PRODUCTION_RECIPES do
		local level = if save and save.purchased[upgradeId] then FarmMath.getExpansionLevel(save, recipeId) else 0
		local existing = marksFolder:FindFirstChild(upgradeId)
		if existing and existing:GetAttribute("Level") ~= level then
			existing:Destroy()
			existing = nil
		end
		local spot = spots:FindFirstChild(upgradeId)
		if level > 0 and not existing and spot and spot:IsA("BasePart") then
			local mark = Instance.new("Model")
			mark.Name = upgradeId
			mark:SetAttribute("Level", level)
			local ground = spot.Position.Y - spot.Size.Y / 2
			for ring = 1, level do
				local disc = Instance.new("Part")
				disc.Name = "LevelRing"
				disc.Shape = Enum.PartType.Cylinder
				disc.Size = Vector3.new(0.12, 9 + ring * 1.4, 9 + ring * 1.4)
				disc.CFrame = CFrame.new(spot.Position.X, ground + 0.08 + ring * 0.02, spot.Position.Z)
					* CFrame.Angles(0, 0, math.rad(90))
				disc.Color = GOLD
				disc.Material = Enum.Material.Neon
				disc.Transparency = 0.55 + (level - ring) * 0.05
				disc.Anchored = true
				disc.CanCollide = false
				disc.CanTouch = false
				disc.CanQuery = false
				disc.CastShadow = false
				disc.Parent = mark
			end
			local anchor = Instance.new("Part")
			anchor.Name = "LevelTagAnchor"
			anchor.Size = Vector3.one
			anchor.Position = Vector3.new(spot.Position.X, ground + 1, spot.Position.Z)
			anchor.Transparency = 1
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanTouch = false
			anchor.CanQuery = false
			anchor.Parent = mark
			WorldUi.tag(anchor, "LevelTag", {
				text = `Sv.{level}`,
				icon = "⭐",
				tint = GOLD,
				widthStuds = 5,
				heightStuds = 1.6,
				worldOffset = Vector3.new(0, 13, 0),
				maxDistance = 70,
			})
			mark.Parent = marksFolder
		end
	end
end

function UpgradeVisualService.apply(plot: Model, save: PlayerSave?)
	local spots = plot:FindFirstChild("BuildSpots")
	if not spots then
		return
	end
	local upgradesFolder = InstanceUtil.getOrCreateFolder(plot, "Upgrades")
	local sitesFolder = InstanceUtil.getOrCreateFolder(plot, "Sites")

	for _, upgrade in Config.UPGRADES do
		local owned = save ~= nil and save.purchased[upgrade.id] == true
		local existing = upgradesFolder:FindFirstChild(upgrade.id)
		if owned and existing and existing:GetAttribute("UpgradeVisualVersion") ~= VISUAL_VERSION then
			existing:Destroy()
			existing = nil
		end
		if owned and not existing then
			local spot = spots:FindFirstChild(upgrade.id)
			if spot and spot:IsA("BasePart") then
				buildUpgrade(upgrade.id, spot, upgradesFolder)
			end
		elseif not owned and existing then
			existing:Destroy()
		end
		-- Yapım alanı: yalnızca şu an satın alınabilen, karada bir yapı noktası olan ve görseli tanımlı binalar
		local site = (sitesFolder :: Instance):FindFirstChild(upgrade.id)
		local spot = spots:FindFirstChild(upgrade.id)
		local wantSite = save ~= nil
			and not owned
			and spot ~= nil
			and spot:IsA("BasePart")
			and spot:GetAttribute("BoatPatrolX") == nil
			and BUILDERS[upgrade.id] ~= nil
			and FarmMath.getUpgradeStatus(save, upgrade.id) == "available"
		if wantSite and not site then
			buildSite(upgrade, spot :: BasePart, sitesFolder :: Instance, FarmMath.getUpgradeCost(save, upgrade))
		elseif not wantSite and site then
			site:Destroy()
		end
	end
	applyLevelMarks(plot, spots, save)
end

return UpgradeVisualService
