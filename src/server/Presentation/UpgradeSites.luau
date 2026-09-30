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

return {
	buildSite = buildSite,
	applyLevelMarks = applyLevelMarks,
}
