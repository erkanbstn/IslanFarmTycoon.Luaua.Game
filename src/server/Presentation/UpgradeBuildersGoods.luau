--!strict
-- Ürün merkezleri (depoya ürün üreten fabrikalar): süt, yumurta, tüy, peynir, yün, et, nal ve balık.
-- Her bina `function(model, base)`: model içine parçalar kurar (base = yapı noktasının CFrame'i); kapı -Z yönündedir.
-- Ortak iskelet `house`; her ürünün kendine özgü süsü (bidon, yumurta, peynir tekeri, yün yumağı, örs...) ayrıdır.

local WorldDecor = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("WorldDecor"))
local UpgradeParts = require(script.Parent:WaitForChild("UpgradeParts"))

local METAL = UpgradeParts.METAL
local makePart = UpgradeParts.makePart
local makeColumn = UpgradeParts.makeColumn
local makeBall = UpgradeParts.makeBall
local sign = UpgradeParts.sign
type Builder = UpgradeParts.Builder

type HouseLook = {
	body: Color3,
	roof: Color3,
	bodyMaterial: Enum.Material,
	title: string,
	text: string,
	icon: string,
}

-- Küçük atölye: gövde, çatı, kapı, iki pencere ve çatı üstünde tabela (yaklaşık 10 x 8 stud)
local function house(model: Model, base: CFrame, look: HouseLook)
	makePart(model, "Building", Vector3.new(10, 5.5, 8), base * CFrame.new(0, 2.75, 0), look.body, look.bodyMaterial)
	makePart(model, "Roof", Vector3.new(11.4, 0.8, 9.4), base * CFrame.new(0, 5.9, 0), look.roof, Enum.Material.Slate)
	makePart(
		model,
		"Door",
		Vector3.new(2.8, 4, 0.3),
		base * CFrame.new(0, 2, -4.1),
		Color3.fromRGB(110, 70, 40),
		Enum.Material.Wood
	)
	for _, x in { -3.2, 3.2 } do
		local window = makePart(
			model,
			"Window",
			Vector3.new(1.8, 1.6, 0.2),
			base * CFrame.new(x, 3.4, -4.05),
			Color3.fromRGB(120, 180, 220),
			Enum.Material.Glass
		)
		WorldDecor.markNightWindow(window)
	end
	sign(model, base * CFrame.new(0, 7.5, -4.3), look.title, look.text, look.icon, 8)
end

local builders: { [string]: Builder } = {
	-- Süt Toplama Merkezi: beyaz-mavi sütlük, yanında sıra sıra süt bidonları
	milk_center = function(model, base)
		house(model, base, {
			body = Color3.fromRGB(235, 240, 245),
			roof = Color3.fromRGB(60, 110, 170),
			bodyMaterial = Enum.Material.WoodPlanks,
			title = "Süt Merkezi",
			text = "Süt depoya gider",
			icon = "🥛",
		})
		for index = 0, 2 do
			makeColumn(
				model,
				"MilkChurn",
				1.6,
				2.4,
				base * CFrame.new(-6.8, 1.2, -2 + index * 2.3),
				METAL,
				Enum.Material.Metal
			)
			makeColumn(
				model,
				"ChurnLid",
				1.9,
				0.3,
				base * CFrame.new(-6.8, 2.55, -2 + index * 2.3),
				Color3.fromRGB(60, 110, 170),
				Enum.Material.Metal
			)
		end
	end,

	-- Yumurta Toplama Merkezi: krem kümes, yanında yumurta dolu sepet rafı
	egg_center = function(model, base)
		house(model, base, {
			body = Color3.fromRGB(240, 225, 185),
			roof = Color3.fromRGB(170, 90, 60),
			bodyMaterial = Enum.Material.WoodPlanks,
			title = "Yumurta Merkezi",
			text = "Yumurta depoya gider",
			icon = "🥚",
		})
		makePart(
			model,
			"EggCrate",
			Vector3.new(2.2, 1, 5),
			base * CFrame.new(6.8, 0.5, 0),
			Color3.fromRGB(150, 110, 70),
			Enum.Material.WoodPlanks
		)
		for index = 0, 3 do
			local egg = makeBall(
				model,
				"Egg",
				1.2,
				base * CFrame.new(6.8, 1.4, -1.8 + index * 1.2),
				Color3.fromRGB(250, 245, 235),
				Enum.Material.SmoothPlastic
			)
			egg.Size = Vector3.new(1.1, 1.4, 1.1)
		end
	end,

	-- Tüy Atölyesi: mavi-gri kulübe, yanında beyaz tüy yığınları
	down_workshop = function(model, base)
		house(model, base, {
			body = Color3.fromRGB(120, 160, 180),
			roof = Color3.fromRGB(45, 95, 110),
			bodyMaterial = Enum.Material.WoodPlanks,
			title = "Tüy Atölyesi",
			text = "Tüy depoya gider",
			icon = "🪶",
		})
		for index, size in { 2.6, 2, 1.5 } do
			makeBall(
				model,
				"FeatherPuff",
				size,
				base * CFrame.new(-6.8, size / 2, -2 + (index - 1) * 2.4),
				Color3.fromRGB(250, 250, 255),
				Enum.Material.Fabric
			)
		end
	end,

	-- Peynir Mahzeni: taş mahzen, yanında üst üste peynir tekerlekleri
	cheese_cellar = function(model, base)
		house(model, base, {
			body = Color3.fromRGB(150, 145, 135),
			roof = Color3.fromRGB(95, 70, 55),
			bodyMaterial = Enum.Material.Cobblestone,
			title = "Peynir Mahzeni",
			text = "Peynir depoya gider",
			icon = "🧀",
		})
		for index = 0, 2 do
			makeColumn(
				model,
				"CheeseWheel",
				2.4,
				0.9,
				base * CFrame.new(6.8, 0.45 + index * 0.95, -1.2),
				Color3.fromRGB(245, 205, 90),
				Enum.Material.SmoothPlastic
			)
		end
		makeColumn(
			model,
			"CheeseWheel",
			2.4,
			0.9,
			base * CFrame.new(6.8, 0.45, 1.6),
			Color3.fromRGB(235, 190, 75),
			Enum.Material.SmoothPlastic
		)
	end,

	-- Yün Dokuma Atölyesi: ahşap atölye, yanında renkli yün yumakları rafı
	wool_loom = function(model, base)
		house(model, base, {
			body = Color3.fromRGB(150, 110, 70),
			roof = Color3.fromRGB(165, 70, 60),
			bodyMaterial = Enum.Material.WoodPlanks,
			title = "Yün Atölyesi",
			text = "Yün depoya gider",
			icon = "🧶",
		})
		makePart(
			model,
			"WoolRack",
			Vector3.new(1.2, 0.6, 5.6),
			base * CFrame.new(-6.8, 1, 0),
			Color3.fromRGB(110, 80, 50),
			Enum.Material.Wood
		)
		for index, color in
			{ Color3.fromRGB(235, 130, 160), Color3.fromRGB(110, 150, 215), Color3.fromRGB(245, 240, 225) }
		do
			makeBall(
				model,
				"WoolSkein",
				1.8,
				base * CFrame.new(-6.8, 2, -2 + (index - 1) * 2),
				color,
				Enum.Material.Fabric
			)
		end
	end,

	-- Et Tütsühanesi: koyu tuğla, yüksek baca ve duman; yanında fıçılar
	meat_smokehouse = function(model, base)
		house(model, base, {
			body = Color3.fromRGB(105, 70, 58),
			roof = Color3.fromRGB(45, 40, 40),
			bodyMaterial = Enum.Material.Brick,
			title = "Tütsühane",
			text = "Et depoya gider",
			icon = "🥩",
		})
		makeColumn(
			model,
			"Chimney",
			1.6,
			4.5,
			base * CFrame.new(3, 8.1, 2),
			Color3.fromRGB(95, 65, 55),
			Enum.Material.Brick
		)
		local smoke = makeBall(
			model,
			"Smoke",
			2.6,
			base * CFrame.new(3, 11.6, 2),
			Color3.fromRGB(200, 200, 205),
			Enum.Material.SmoothPlastic
		)
		smoke.Transparency = 0.55
		smoke.CanCollide = false
		for index = 0, 1 do
			makeColumn(
				model,
				"Barrel",
				1.8,
				2.2,
				base * CFrame.new(6.8, 1.1, -1.4 + index * 2.4),
				Color3.fromRGB(130, 90, 55),
				Enum.Material.Wood
			)
		end
	end,

	-- Nal Demirhanesi: taş ocak, parlayan ocak ağzı, yanında örs
	horseshoe_forge = function(model, base)
		house(model, base, {
			body = Color3.fromRGB(112, 112, 118),
			roof = Color3.fromRGB(55, 55, 60),
			bodyMaterial = Enum.Material.Slate,
			title = "Nal Demirhanesi",
			text = "Nal depoya gider",
			icon = "🧲",
		})
		makeColumn(
			model,
			"Chimney",
			1.8,
			4,
			base * CFrame.new(-3, 8, 2),
			Color3.fromRGB(90, 90, 95),
			Enum.Material.Brick
		)
		local fire = makePart(
			model,
			"ForgeGlow",
			Vector3.new(2.2, 1.4, 0.3),
			base * CFrame.new(3.4, 1.4, -4.15),
			Color3.fromRGB(255, 140, 50),
			Enum.Material.Neon
		)
		fire.CanCollide = false
		makePart(
			model,
			"AnvilBase",
			Vector3.new(1.6, 1.2, 1.4),
			base * CFrame.new(-6.8, 0.6, -1.4),
			Color3.fromRGB(70, 60, 55),
			Enum.Material.Wood
		)
		makePart(
			model,
			"Anvil",
			Vector3.new(2.6, 0.8, 1.2),
			base * CFrame.new(-6.8, 1.6, -1.4),
			Color3.fromRGB(45, 45, 50),
			Enum.Material.Metal
		)
	end,

	-- Balık Temizleme Merkezi: mavi tahta depo, yanında balık sandıkları
	fish_cannery = function(model, base)
		house(model, base, {
			body = Color3.fromRGB(90, 140, 170),
			roof = Color3.fromRGB(225, 235, 240),
			bodyMaterial = Enum.Material.WoodPlanks,
			title = "Balık Merkezi",
			text = "Balık depoya gider",
			icon = "🐟",
		})
		for index = 0, 1 do
			makePart(
				model,
				"FishCrate",
				Vector3.new(2.4, 1.1, 1.8),
				base * CFrame.new(6.8, 0.55 + index * 1.15, -1.2 + index * 0.3),
				Color3.fromRGB(150, 115, 75),
				Enum.Material.WoodPlanks
			)
		end
		local fish = makeBall(
			model,
			"Fish",
			1.4,
			base * CFrame.new(6.8, 2.6, -0.9),
			Color3.fromRGB(150, 185, 205),
			Enum.Material.SmoothPlastic
		)
		fish.Size = Vector3.new(0.7, 1, 2)
	end,
}

return builders
