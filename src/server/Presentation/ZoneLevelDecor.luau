--!strict
-- Bölge geliştirme seviyesinin dünyada görünen süsleri: her seviye bölgenin kenarlarına yeni bir şey ekler
-- (yemlik, saman, gölgelik ve fener, çiçek sandıkları, altın direkler). Koordinatlar bölge zemininin üst yüzeyine göredir;
-- süsler hayvanların gezdiği orta alanın dışında, yan kenarlarda ve köşelerde durur. Sonuç `LevelFlags` modeline eklenir.

local ZoneParts = require(script.Parent:WaitForChild("ZoneParts"))

local part = ZoneParts.part
local GOLD = Color3.fromRGB(255, 200, 60)

local ZoneLevelDecor = {}

local function lantern(model: Model, cf: CFrame)
	part(model, "LanternPost", Vector3.new(0.35, 4.2, 0.35), cf * CFrame.new(0, 2.1, 0), ZoneParts.DARK_WOOD).CanCollide =
		false
	local lamp = part(
		model,
		"LanternLamp",
		Vector3.new(0.9, 0.9, 0.9),
		cf * CFrame.new(0, 4.5, 0),
		Color3.fromRGB(255, 226, 150),
		Enum.Material.Neon
	)
	lamp.CanCollide = false
	lamp.Transparency = 0.15
end

-- level: 1..5 (üstü sınırlanır). Her seviye kendi parçalarını ekler; alttakiler kalır.
function ZoneLevelDecor.build(model: Model, top: CFrame, size: Vector3, level: number)
	local halfX, halfZ = size.X / 2, size.Z / 2
	if level >= 1 then
		-- Yemlikler: sol yan kenarda iki adet
		for _, z in { -halfZ * 0.35, halfZ * 0.15 } do
			ZoneParts.feedTrough(model, top * CFrame.new(-halfX + 1.3, 0, z) * CFrame.Angles(0, math.rad(90), 0), 4)
		end
	end
	if level >= 2 then
		-- Saman balyaları: sağ arka köşede yığın
		local corner = top * CFrame.new(halfX - 1.6, 0, halfZ - 2.2)
		ZoneParts.hayBale(model, corner)
		ZoneParts.hayBale(model, corner * CFrame.new(0, 0, -1.9))
		ZoneParts.hayBale(model, corner * CFrame.new(0, 1.6, -0.9))
	end
	if level >= 3 then
		-- Gölgelik: sol arka köşede dört direkli çatı ve iki fener
		local shelter = top * CFrame.new(-halfX + 2.6, 0, halfZ - 3.2)
		for _, x in { -1.8, 1.8 } do
			for _, z in { -1.8, 1.8 } do
				part(
					model,
					"ShelterPost",
					Vector3.new(0.4, 4.2, 0.4),
					shelter * CFrame.new(x, 2.1, z),
					ZoneParts.DARK_WOOD
				)
			end
		end
		part(
			model,
			"ShelterRoof",
			Vector3.new(5.2, 0.4, 5.2),
			shelter * CFrame.new(0, 4.3, 0),
			ZoneParts.ROOF,
			Enum.Material.Slate
		)
		lantern(model, top * CFrame.new(halfX - 1, 0, -halfZ * 0.2))
		lantern(model, top * CFrame.new(-halfX + 1, 0, -halfZ * 0.2))
	end
	if level >= 4 then
		-- Çiçek sandıkları: ön kenarın sağ yarısında
		for index = 0, 3 do
			local box = top * CFrame.new(halfX - 3 - index * 3.2, 0, -halfZ + 1.1)
			part(model, "FlowerBox", Vector3.new(2.4, 0.9, 1.1), box * CFrame.new(0, 0.45, 0), ZoneParts.WOOD)
			for step = -1, 1 do
				ZoneParts.plant(
					model,
					box * CFrame.new(step * 0.75, 0.9, 0),
					0.7,
					if (index + step) % 2 == 0 then Color3.fromRGB(235, 110, 130) else Color3.fromRGB(250, 215, 90),
					0.55
				)
			end
		end
	end
	if level >= 5 then
		-- Altın direkler: arka köşelerde altın küreli iki sütun ve altın bayrak direği
		for _, side in { -1, 1 } do
			local post = top * CFrame.new(side * (halfX - 0.8), 0, halfZ - 0.8)
			part(
				model,
				"GoldColumn",
				Vector3.new(0.9, 6, 0.9),
				post * CFrame.new(0, 3, 0),
				Color3.fromRGB(240, 235, 225),
				Enum.Material.Marble
			).CanCollide =
				false
			local orb = part(
				model,
				"GoldOrb",
				Vector3.new(1.6, 1.6, 1.6),
				post * CFrame.new(0, 6.6, 0),
				GOLD,
				Enum.Material.Metal
			)
			orb.Shape = Enum.PartType.Ball
			orb.CanCollide = false
		end
	end
end

return ZoneLevelDecor
