--!strict
-- Ana adanın doğu kıyısındaki tema işaret yapıları (Config.THEMES[n].landmark: daisy/tulip/sunflower/rose/pine/cherry).

local WorldDecor = require(script.Parent:WaitForChild("WorldDecor"))
local HomeParts = require(script.Parent:WaitForChild("HomeParts"))

local WOOD = HomeParts.WOOD
local DARK_WOOD = HomeParts.DARK_WOOD
local STONE = HomeParts.STONE
local STRAW = HomeParts.STRAW
local part = HomeParts.part
local ball = HomeParts.ball
local model = HomeParts.model

local Landmarks = {}

---------------------------------------------------------------------------
-- Tema işaret yapısı: her çiftliğin ana adasında doğu kıyıda kendine özgü küçük bir alan (Config.THEMES[n].landmark).
-- Yaklaşık 14x14 stud; çoğu parça çarpışmaz, yalnızca gövde/direk/kaya katıdır.
---------------------------------------------------------------------------

local function flower(parent: Instance, base: CFrame, height: number, headColor: Color3, headSize: number)
	part(
		parent,
		"Stem",
		Vector3.new(0.2, height, 0.2),
		base * CFrame.new(0, height / 2, 0),
		Color3.fromRGB(70, 130, 60),
		Enum.Material.Grass,
		false
	)
	ball(parent, "Bloom", headSize, base * CFrame.new(0, height, 0), headColor, Enum.Material.SmoothPlastic)
end

local LANDMARKS: { [string]: (parent: Instance, base: CFrame) -> () } = {
	-- Papatya: korkuluklu papatya halkası
	daisy = function(parent, base)
		part(
			parent,
			"ScarecrowPole",
			Vector3.new(0.4, 5, 0.4),
			base * CFrame.new(0, 2.5, 0),
			DARK_WOOD,
			Enum.Material.Wood
		)
		part(
			parent,
			"ScarecrowArms",
			Vector3.new(4, 0.35, 0.35),
			base * CFrame.new(0, 4, 0),
			DARK_WOOD,
			Enum.Material.Wood,
			false
		)
		ball(parent, "ScarecrowHead", 1.4, base * CFrame.new(0, 5.4, 0), STRAW, Enum.Material.Fabric)
		part(
			parent,
			"ScarecrowHat",
			Vector3.new(2.2, 0.3, 2.2),
			base * CFrame.new(0, 6.1, 0),
			Color3.fromRGB(120, 85, 50),
			Enum.Material.Fabric,
			false
		)
		for index = 0, 13 do
			local angle = index / 14 * math.pi * 2
			local color = if index % 2 == 0 then Color3.fromRGB(250, 250, 250) else Color3.fromRGB(250, 215, 70)
			flower(parent, base * CFrame.new(math.sin(angle) * 5.5, 0, math.cos(angle) * 5.5), 1.2, color, 0.8)
		end
	end,
	-- Lale: renkli lale tarhası ve alçak çit
	tulip = function(parent, base)
		local colors = {
			Color3.fromRGB(230, 60, 80),
			Color3.fromRGB(250, 200, 60),
			Color3.fromRGB(190, 90, 200),
			Color3.fromRGB(250, 140, 170),
		}
		for row = 0, 3 do
			for col = 0, 6 do
				flower(
					parent,
					base * CFrame.new(-5 + col * 1.7, 0, -4.5 + row * 3),
					1.3,
					colors[(row + col) % #colors + 1],
					0.75
				)
			end
		end
		for side = -1, 1, 2 do
			part(
				parent,
				"FenceRail",
				Vector3.new(14, 0.3, 0.3),
				base * CFrame.new(0, 1.2, side * 7.2),
				WOOD,
				Enum.Material.Wood,
				false
			)
			for x = -6, 6, 3 do
				part(
					parent,
					"FencePost",
					Vector3.new(0.4, 1.8, 0.4),
					base * CFrame.new(x, 0.9, side * 7.2),
					DARK_WOOD,
					Enum.Material.Wood
				)
			end
		end
	end,
	-- Ayçiçeği: uzun boylu ayçiçeği tarlası
	sunflower = function(parent, base)
		for row = 0, 2 do
			for col = 0, 3 do
				local at = base * CFrame.new(-5.4 + col * 3.6, 0, -4.5 + row * 4.5)
				flower(parent, at, 3.6, Color3.fromRGB(245, 195, 30), 1.8)
				ball(
					parent,
					"Seeds",
					0.9,
					at * CFrame.new(0, 3.6, -0.75),
					Color3.fromRGB(90, 60, 35),
					Enum.Material.Fabric
				)
			end
		end
		part(parent, "Sack", Vector3.new(1.6, 1.4, 1.2), base * CFrame.new(6.2, 0.7, 5.6), STRAW, Enum.Material.Fabric)
	end,
	-- Gül: çardak ve gül çalıları
	rose = function(parent, base)
		for _, x in { -2.4, 2.4 } do
			part(
				parent,
				"ArborPost",
				Vector3.new(0.5, 6.2, 0.5),
				base * CFrame.new(x, 3.1, 0),
				Color3.fromRGB(240, 235, 225),
				Enum.Material.Wood
			)
		end
		part(
			parent,
			"ArborBeam",
			Vector3.new(5.6, 0.6, 0.9),
			base * CFrame.new(0, 6.2, 0),
			Color3.fromRGB(240, 235, 225),
			Enum.Material.Wood,
			false
		)
		ball(
			parent,
			"ArborRoses",
			1.6,
			base * CFrame.new(-2.4, 6.4, 0),
			Color3.fromRGB(215, 40, 70),
			Enum.Material.SmoothPlastic
		)
		ball(
			parent,
			"ArborRoses",
			1.6,
			base * CFrame.new(2.4, 6.4, 0),
			Color3.fromRGB(235, 90, 120),
			Enum.Material.SmoothPlastic
		)
		for index = 0, 7 do
			local angle = index / 8 * math.pi * 2
			local at = base * CFrame.new(math.sin(angle) * 6.4, 0, math.cos(angle) * 6.4 + 1)
			ball(parent, "RoseBush", 2, at * CFrame.new(0, 1, 0), Color3.fromRGB(60, 120, 55), Enum.Material.Grass)
			ball(
				parent,
				"RoseBloom",
				0.7,
				at * CFrame.new(0.4, 1.9, 0),
				if index % 2 == 0 then Color3.fromRGB(215, 40, 70) else Color3.fromRGB(250, 160, 185),
				Enum.Material.SmoothPlastic
			)
		end
	end,
	-- Yonca: çam öbeği ve kayalar
	pine = function(parent, base)
		WorldDecor.pineTree(parent, base * CFrame.new(-3.5, 0, -3), 41)
		WorldDecor.pineTree(parent, base * CFrame.new(3, 0, -1), 42)
		WorldDecor.pineTree(parent, base * CFrame.new(-1, 0, 4.5), 43)
		for index, spot in { Vector2.new(5.5, 4), Vector2.new(-6, 1), Vector2.new(1.5, -6.5) } do
			local size = 2.2 + index * 0.5
			part(
				parent,
				"Rock",
				Vector3.new(size * 1.3, size, size * 1.1),
				base * CFrame.new(spot.X, size / 2, spot.Y) * CFrame.Angles(0.1 * index, index, 0.06),
				STONE,
				Enum.Material.Slate
			)
		end
	end,
	-- Kiraz: pembe çiçekli kiraz ağaçları ve çiçek yaprağı halısı
	cherry = function(parent, base)
		part(
			parent,
			"Petals",
			Vector3.new(13, 0.1, 13),
			base * CFrame.new(0, 0.05, 0),
			Color3.fromRGB(245, 190, 210),
			Enum.Material.Fabric,
			false
		)
		for index, spot in { Vector2.new(-3.5, -2.5), Vector2.new(3.5, 0.5), Vector2.new(-0.5, 4.5) } do
			local at = base * CFrame.new(spot.X, 0, spot.Y)
			part(parent, "Trunk", Vector3.new(0.9, 3.6, 0.9), at * CFrame.new(0, 1.8, 0), DARK_WOOD, Enum.Material.Wood)
			ball(
				parent,
				"Blossom",
				5.2 - index * 0.3,
				at * CFrame.new(0, 4.8, 0),
				if index % 2 == 0 then Color3.fromRGB(245, 160, 190) else Color3.fromRGB(250, 185, 208),
				Enum.Material.Grass
			)
		end
	end,
}

function Landmarks.landmark(parent: Instance, base: CFrame, kind: string)
	local builder = LANDMARKS[kind]
	if not builder then
		return
	end
	local landmark = model(parent, "Landmark")
	landmark:SetAttribute("Kind", kind)
	builder(landmark, base)
end

return Landmarks
