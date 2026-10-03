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
local warnedSiteAsset = false

local function buildSite(upgrade: Config.UpgradeConfig, spot: BasePart, parent: Instance, priceText: string)
	local site = ModelAssets.clone("FacilityProps", "BuildSite_Unbuilt")
	if not site then
		if not warnedSiteAsset then
			warn("[UpgradeSites] FacilityProps/BuildSite_Unbuilt modeli eksik")
			warnedSiteAsset = true
		end
		return
	end
	local board = site:FindFirstChild("SiteSign")
	local pole = site:FindFirstChild("SignPole")
	if not board or not board:IsA("BasePart") or not pole or not pole:IsA("BasePart") then
		site:Destroy()
		if not warnedSiteAsset then
			warn("[UpgradeSites] BuildSite_Unbuilt içinde SiteSign/SignPole eksik")
			warnedSiteAsset = true
		end
		return
	end
	site.Name = upgrade.id
	site:SetAttribute("UpgradeId", upgrade.id)
	site:SetAttribute("PriceText", priceText)
	local base = spot.CFrame
	site:SetAttribute("SiteFrame", base)
	site:PivotTo(base)
	WorldUi.sign(board, Enum.NormalId.Front, {
		icon = upgrade.icon,
		title = upgrade.displayName,
		text = `Yapım alanı · {priceText}`,
	})
	-- Tabelaya yaklaşınca "Satın al": satın almayı BuyPadService sunucuda doğrular (UpgradeService.tryBuy).
	local promptAnchor = makePart(
		site,
		"SitePromptAnchor",
		Vector3.one * 0.2,
		base * CFrame.new(0, 2.6, -SITE_HALF - 1.4),
		METAL,
		Enum.Material.Metal
	)
	promptAnchor.CanCollide = false
	promptAnchor.CanQuery = false
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

-- Fiyat indirimi/yerleşim güncellenirken mevcut tabela ve prompt korunur.
local function updateSite(site: Instance, spot: BasePart, priceText: string)
	if site:GetAttribute("PriceText") ~= priceText then
		local board = site:FindFirstChild("SiteSign")
		if board then
			WorldUi.setSignText(board, `Yapım alanı · {priceText}`)
		end
		site:SetAttribute("PriceText", priceText)
	end
	if site:IsA("Model") and site:GetAttribute("SiteFrame") ~= spot.CFrame then
		site:PivotTo(spot.CFrame)
		site:SetAttribute("SiteFrame", spot.CFrame)
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
			-- Sv.N etiketi binanın üstünde durur (yükseklik binanın sınır kutusundan): çatıyı/kuleyi kapatmaz, iş çubuğuyla (bina üstü +6) çakışmaz
			local tagHeight = 13
			local upgrades = plot:FindFirstChild("Upgrades")
			local building = if upgrades then upgrades:FindFirstChild(upgradeId) else nil
			if building and building:IsA("Model") then
				local boxCf, boxSize = building:GetBoundingBox()
				tagHeight = math.clamp(boxCf.Position.Y + boxSize.Y / 2 - (ground + 1) + 1.4, 6, 24)
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
				worldOffset = Vector3.new(0, tagHeight, 0),
				maxDistance = 70,
			})
			mark.Parent = marksFolder
		end
	end
end

return {
	buildSite = buildSite,
	updateSite = updateSite,
	applyLevelMarks = applyLevelMarks,
}
