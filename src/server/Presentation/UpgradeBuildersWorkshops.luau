--!strict
-- Ördek, koyun, domuz ve keçi adası atölyeleri: ördek evi, yün değirmeni, trüf mutfağı, peynir mandırası.
-- Her bina `function(model, base)`: model içine parçalar kurar (base = yapı noktasının CFrame'i).

local WorldDecor = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("WorldDecor"))
local UpgradeParts = require(script.Parent:WaitForChild("UpgradeParts"))

local makePart = UpgradeParts.makePart
local makeColumn = UpgradeParts.makeColumn
local makeBall = UpgradeParts.makeBall
type Builder = UpgradeParts.Builder

local builders: { [string]: Builder } = {
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
}

return builders
