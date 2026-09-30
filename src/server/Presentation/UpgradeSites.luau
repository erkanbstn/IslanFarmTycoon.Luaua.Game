--!strict
-- Yapım alanı (satın alınabilir ama alınmamış bina yeri) ve tesis geliştirme seviye işaretleri.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))
local InstanceUtil = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("InstanceUtil"))
local UpgradeParts = require(script.Parent:WaitForChild("UpgradeParts"))

type PlayerSave = GameTypes.PlayerSave

local METAL = UpgradeParts.METAL
local GOLD = UpgradeParts.GOLD
local PRODUCTION_RECIPES = UpgradeParts.PRODUCTION_RECIPES
local makePart = UpgradeParts.makePart

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

-- Tesis seviyesine göre binanın çevresine eklenen süsler (her seviye yenisini ekler; alttakiler kalır).
-- Bina 10 x 8 stud, kapısı -Z yönünde; süsler yürüme yolunu kapatmaz (kapı önü boş, parçalar yan köşelerde).
local function addFacilityProps(mark: Model, spotCf: CFrame, level: number)
	local function prop(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material,
		shape: Enum.PartType?
	)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = spotCf * offset
		p.Color = color
		p.Material = material
		p.Anchored = true
		p.CanCollide = name == "Crate" or name == "Counter" or name == "AwningPost" or name == "LampPost"
		p.CanTouch = false
		p.CanQuery = p.CanCollide
		if shape then
			p.Shape = shape
		end
		p.Parent = mark
		return p
	end
	local wood = Color3.fromRGB(150, 110, 70)
	if level >= 1 then
		-- Arka yanda kasa yığını
		for index, x in { -2.2, 0, 2.2 } do
			prop("Crate", Vector3.new(1.8, 1.6, 1.8), CFrame.new(x, 0.8, 6.4), wood, Enum.Material.WoodPlanks)
			if index == 2 then
				prop(
					"Crate",
					Vector3.new(1.8, 1.6, 1.8),
					CFrame.new(x, 2.4, 6.4),
					Color3.fromRGB(170, 130, 85),
					Enum.Material.WoodPlanks
				)
			end
		end
	end
	if level >= 2 then
		-- Ön sol köşede bayrak
		prop(
			"FlagPole",
			Vector3.new(0.25, 7, 0.25),
			CFrame.new(-6.4, 3.5, -5.6),
			Color3.fromRGB(235, 235, 235),
			Enum.Material.Metal
		)
		prop("Flag", Vector3.new(2.2, 1.3, 0.1), CFrame.new(-5.3, 6.3, -5.6), GOLD, Enum.Material.Fabric)
	end
	if level >= 3 then
		-- Kapının iki yanında fener direkleri
		for _, x in { -4.4, 4.4 } do
			prop(
				"LampPost",
				Vector3.new(0.3, 4, 0.3),
				CFrame.new(x, 2, -5.6),
				Color3.fromRGB(70, 65, 60),
				Enum.Material.Metal
			)
			prop(
				"LampGlow",
				Vector3.new(0.8, 0.8, 0.8),
				CFrame.new(x, 4.3, -5.6),
				Color3.fromRGB(255, 226, 150),
				Enum.Material.Neon,
				Enum.PartType.Ball
			)
		end
	end
	if level >= 4 then
		-- Arka sağ yanda gölgelik ve tezgâh
		for _, z in { 5, 8.2 } do
			prop("AwningPost", Vector3.new(0.35, 3.6, 0.35), CFrame.new(7.2, 1.8, z), wood, Enum.Material.Wood)
		end
		prop(
			"AwningRoof",
			Vector3.new(2.6, 0.3, 4.2),
			CFrame.new(7.2, 3.7, 6.6),
			Color3.fromRGB(196, 70, 60),
			Enum.Material.Fabric
		)
		prop("Counter", Vector3.new(1.6, 1.1, 3), CFrame.new(7.2, 0.55, 6.6), wood, Enum.Material.WoodPlanks)
	end
	if level >= 5 then
		-- Altın çatı kenarı ve tepe küresi
		prop("GoldTrim", Vector3.new(11.8, 0.25, 9.8), CFrame.new(0, 6.45, 0), GOLD, Enum.Material.Metal)
		prop(
			"GoldOrb",
			Vector3.new(1.8, 1.8, 1.8),
			CFrame.new(0, 7.3, 3),
			GOLD,
			Enum.Material.Metal,
			Enum.PartType.Ball
		)
	end
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
			addFacilityProps(mark, CFrame.new(spot.Position.X, ground, spot.Position.Z) * spot.CFrame.Rotation, level)
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

return {
	buildSite = buildSite,
	applyLevelMarks = applyLevelMarks,
}
