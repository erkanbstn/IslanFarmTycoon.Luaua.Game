--!strict
-- Tavuk ve at adası binaları: kuluçkahane, yumurta fabrikası, at eğitimi, altın nal.
-- Her bina `function(model, base)`: model içine parçalar kurar (base = yapı noktasının CFrame'i).

local UpgradeParts = require(script.Parent:WaitForChild("UpgradeParts"))

local METAL = UpgradeParts.METAL
local GOLD = UpgradeParts.GOLD
local makePart = UpgradeParts.makePart
local makeBall = UpgradeParts.makeBall
local sign = UpgradeParts.sign
type Builder = UpgradeParts.Builder

local builders: { [string]: Builder } = {
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
}

return builders
