--!strict
-- Ana ada binaları: silo, süt makinesi ve fabrikası, otomatik toplayıcı, balıkçı teknesi.
-- Her bina `function(model, base)`: model içine parçalar kurar (base = yapı noktasının CFrame'i).

local UpgradeParts = require(script.Parent:WaitForChild("UpgradeParts"))

local METAL = UpgradeParts.METAL
local makePart = UpgradeParts.makePart
local makeColumn = UpgradeParts.makeColumn
local makeBall = UpgradeParts.makeBall
local beam = UpgradeParts.beam
local sign = UpgradeParts.sign
local taperedBow = UpgradeParts.taperedBow
type Builder = UpgradeParts.Builder

local builders: { [string]: Builder } = {
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
		-- Tanklar çatı çıkıntısının (x 4.5) dışında durur; borular duvardan (x 4) tanka uzanır
		for _, z in { -2.8, 2.8 } do
			makeColumn(model, "PasteurizingTank", 3.2, 8, base * CFrame.new(8.8, 4, z), METAL, Enum.Material.Metal)
			makeBall(model, "TankCap", 3.2, base * CFrame.new(8.8, 8, z), METAL, Enum.Material.Metal)
			makePart(
				model,
				"TankPipe",
				Vector3.new(3.6, 0.45, 0.45),
				base * CFrame.new(6.1, 2, z),
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

return builders
