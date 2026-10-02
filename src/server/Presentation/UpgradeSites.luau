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
local ModelAssets = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("ModelAssets"))

type PlayerSave = GameTypes.PlayerSave

local METAL = UpgradeParts.METAL
local GOLD = UpgradeParts.GOLD
local PRODUCTION_RECIPES = UpgradeParts.PRODUCTION_RECIPES
local makePart = UpgradeParts.makePart

-- Yapım alanı: satın alınabilir ama henüz alınmamış bir binanın yeri. Toprak zemin, kazıklar, sarı şerit ve fiyatlı
-- küçük bir tabela; alınınca kaldırılır ve yerine bina kurulur (oyuncu neyin nereye geleceğini görür).
local SITE_HALF = 4.4

local function buildSite(upgrade: Config.UpgradeConfig, spot: BasePart, parent: Instance, priceText: string)
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
	-- Hazır model (assets/FacilityProps/BuildSite_Unbuilt: toprak, kazıklar, şeritler); tabela, direk ve satın alma istemi kodla eklenir
	ModelAssets.place(site, "FacilityProps", "BuildSite_Unbuilt", base)
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
		text = `Yapım alanı · {priceText}`,
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
	prompt.HoldDuration = 0.5 -- yanlışlıkla satın alma olmasın: basılı tut
	prompt.MaxActivationDistance = 7
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
			local groundCf = CFrame.new(spot.Position.X, ground, spot.Position.Z)
			-- Hazır halkalar ve süsler (assets/FacilityProps/FacilityRings_Lv<1-5>, FacilityProps_Lv<1-5>; pivot = bina zemini)
			local levelKey = math.min(level, 5)
			-- Halka plakaları setin arkasındadır: ikisi de yapı noktasının dönüşüyle yerleşir (döndürülmüş binalarda ayrılmazlar)
			ModelAssets.place(mark, "FacilityProps", `FacilityRings_Lv{levelKey}`, groundCf * spot.CFrame.Rotation)
			ModelAssets.place(mark, "FacilityProps", `FacilityProps_Lv{levelKey}`, groundCf * spot.CFrame.Rotation)
			-- Seviye 2 camlı fenerleri geceleri yanar (ortak fener bağlayıcısı)
			ModelAssets.eachNamed(mark, { "LampGlow" }, function(glow: BasePart)
				ModelAssets.markLantern(glow)
			end)
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
