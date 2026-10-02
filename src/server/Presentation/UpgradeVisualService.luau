--!strict
-- Yol haritasından alınan güçlendirmeleri adada bina olarak gösterir (silo, süt makinesi...).
-- Konum: plot içindeki BuildSpots klasöründe "<upgradeId>" adlı görünmez parça.
-- Bina geometrisi hazır modelden gelir: assets/Buildings/<upgradeId>.rbxmx (ServerStorage.Assets.Buildings; pivot zemine oturur,
-- tabela tahtası "SignBoard" + 2 "SignPost"). Model yoksa warn verilir ve bina çizilmez (yedek kod kurucusu yoktur).
-- Parçalar: UpgradeParts (METAL/GOLD, tarifler, faceSign), UpgradeSites (yapım alanı ve seviye işaretleri), UpgradeLevelProps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))
local AssetSanitizer = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("AssetSanitizer"))
local InstanceUtil = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("InstanceUtil"))
local WorldDecor = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("WorldDecor"))
local UpgradeParts = require(script.Parent:WaitForChild("UpgradeParts"))
local UpgradeSites = require(script.Parent:WaitForChild("UpgradeSites"))
local JobMarks = require(script.Parent:WaitForChild("JobMarks"))
local DecorReveal = require(script.Parent:WaitForChild("DecorReveal"))
local UpgradeLevelProps = require(script.Parent:WaitForChild("UpgradeLevelProps"))

type PlayerSave = GameTypes.PlayerSave

local UpgradeVisualService = {}

local VISUAL_VERSION = 2
local METAL = UpgradeParts.METAL
local PRODUCTION_RECIPES = UpgradeParts.PRODUCTION_RECIPES
local makePart = UpgradeParts.makePart
local buildSite = UpgradeSites.buildSite
local applyLevelMarks = UpgradeSites.applyLevelMarks

local function cloneAsset(upgradeId: string): Model?
	local assets = ServerStorage:FindFirstChild("Assets") or ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Buildings")
	local template = folder and folder:FindFirstChild(upgradeId)
	if template and template:IsA("Model") then
		return AssetSanitizer.clone(template, true)
	end
	return nil
end

local missingWarned: { [string]: boolean } = {}

-- Bu bina için hazır model var mı? (Yapım alanı ve görsel yalnızca modeli olan binalar için kurulur.)
local function hasAsset(upgradeId: string): boolean
	local assets = ServerStorage:FindFirstChild("Assets") or ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Buildings")
	local template = folder and folder:FindFirstChild(upgradeId)
	return template ~= nil and template:IsA("Model")
end

-- Hazır modelde (assets/Buildings) tabela tahtası ve direkleri "SignBoard"/"SignPost" olarak vardır (SurfaceGui modelde saklanmaz).
-- Yazı binanın üretim tarifinden gelir: bina adı + tarif adı + tarif simgesi (Config).
type SignText = { title: string, text: string, icon: string }
local function signTextFor(upgradeId: string): SignText?
	local upgrade = Config.getUpgrade(upgradeId)
	if not upgrade then
		return nil
	end
	for _, recipe in Config.PRODUCTION_RECIPES do
		if recipe.upgradeId == upgradeId then
			return { title = upgrade.displayName, text = recipe.displayName, icon = recipe.icon }
		end
	end
	return nil
end

local function buildUpgrade(upgradeId: string, spot: BasePart, parent: Instance)
	local base = spot.CFrame
	local built = cloneAsset(upgradeId)
	if not built then
		if not missingWarned[upgradeId] then
			missingWarned[upgradeId] = true
			warn(`[UpgradeVisual] assets/Buildings/{upgradeId}.rbxmx bulunamadı; bina çizilmedi`)
		end
		return
	end
	built:PivotTo(base)
	local board = built:FindFirstChild("SignBoard")
	local sign = signTextFor(upgradeId)
	if board and board:IsA("BasePart") and sign then
		UpgradeParts.faceSign(board, sign.title, sign.text, sign.icon)
	end
	built.Name = upgradeId
	built:SetAttribute("UpgradeVisualVersion", VISUAL_VERSION)
	for _, descendant in built:GetDescendants() do
		if
			descendant:IsA("BasePart")
			and descendant.Name:find("Window")
			and descendant.Material == Enum.Material.Glass
		then
			WorldDecor.markNightWindow(descendant)
		end
	end
	WorldDecor.optimize(built)
	if upgradeId == "fishing_boat" then
		-- Hareket sadece client görselidir; tüm parçalar sunucuda da fizik dışıdır.
		-- Gövde, güverte ve kamara katıdır (içinden geçilmez); korkuluk, halat, ışık gibi ince parçalar geçilir.
		-- Tekne her oyuncunun kendi ekranında oynatıldığı için çarpışma da o oyuncunun yerel fiziğinde hesaplanır.
		local SOLID =
			{ Hull = true, Deck = true, JoinedBow = true, BowDeck = true, Wheelhouse = true, CabinRoof = true }
		for _, descendant in built:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = SOLID[descendant.Name] == true
				descendant.CanTouch, descendant.CanQuery = false, false
			end
		end
		local root = makePart(built, "BoatRoot", Vector3.one * 0.1, base, METAL)
		root.Transparency = 1
		root.CanCollide, root.CanTouch, root.CanQuery = false, false, false
		built.PrimaryPart = root
		built.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		built:SetAttribute("BoatHomeCFrame", base)
		built:SetAttribute("BoatPatrolX", spot:GetAttribute("BoatPatrolX") or 6)
		built:SetAttribute("BoatPatrolZ", spot:GetAttribute("BoatPatrolZ") or 3)
		built:SetAttribute("BoatVisual", true)
	end
	local recipe = PRODUCTION_RECIPES[upgradeId]
	if recipe then
		local anchor =
			makePart(built, "ProductionPromptAnchor", Vector3.one * 0.2, base * CFrame.new(0, 2.5, -6), METAL)
		anchor.Transparency = 1
		anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ProductionPrompt"
		prompt.ActionText = "Üretim"
		local upgrade = Config.getUpgrade(upgradeId)
		prompt.ObjectText = if upgrade then upgrade.displayName else "Üretim Merkezi"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 13
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt:SetAttribute("ProductionRecipe", recipe)
		WorldUi.configureProximityPrompt(prompt)
		prompt.Parent = anchor
		-- Binanın üstünde iş ilerlemesi (çubuk + yeşil tik) için işaret noktası
		JobMarks.ensureAnchor(built, nil, 6)
	end
	do
		local parts = 0
		for _, descendant in built:GetDescendants() do
			if descendant:IsA("BasePart") then
				parts += 1
			end
		end
		built:SetAttribute("PartCount", parts)
	end
	built:SetAttribute("VisualCreatedAt", game:GetService("Workspace"):GetServerTimeNow())
	built.Parent = parent
end

-- Bu bina için haritada yapım alanı (tabela + "Satın al") kurulabiliyor mu? Kurulabiliyorsa yerdeki kaide ona ek olmaz.
function UpgradeVisualService.hasBuildSite(plot: Model, upgradeId: string): boolean
	local spots = plot:FindFirstChild("BuildSpots")
	local spot = if spots then spots:FindFirstChild(upgradeId) else nil
	return spot ~= nil and spot:IsA("BasePart") and spot:GetAttribute("BoatPatrolX") == nil and hasAsset(upgradeId)
end

function UpgradeVisualService.apply(plot: Model, save: PlayerSave?)
	local spots = plot:FindFirstChild("BuildSpots")
	if not spots then
		return
	end
	local upgradesFolder = InstanceUtil.getOrCreateFolder(plot, "Upgrades")
	local sitesFolder = InstanceUtil.getOrCreateFolder(plot, "Sites")

	for _, upgrade in Config.UPGRADES do
		local owned = save ~= nil and save.purchased[upgrade.id] == true
		local existing = upgradesFolder:FindFirstChild(upgrade.id)
		if owned and existing and existing:GetAttribute("UpgradeVisualVersion") ~= VISUAL_VERSION then
			existing:Destroy()
			existing = nil
		end
		if owned and not existing then
			local spot = spots:FindFirstChild(upgrade.id)
			if spot and spot:IsA("BasePart") then
				buildUpgrade(upgrade.id, spot, upgradesFolder)
			end
		elseif not owned and existing then
			existing:Destroy()
		end
		-- Üretim tesisi: sürmekte olan iş varsa binanın üstünde ilerleme çubuğu, bitince yeşil tik gösterilir.
		local recipeId = PRODUCTION_RECIPES[upgrade.id]
		if owned and recipeId then
			local built = upgradesFolder:FindFirstChild(upgrade.id)
			local recipe = Config.PRODUCTION_RECIPES[recipeId]
			if built and recipe then
				JobMarks.setProduction(built, if save then save.production[recipeId] else nil, recipe)
			end
		end
		-- Yapım alanı: yalnızca şu an satın alınabilen, karada bir yapı noktası olan ve görseli tanımlı binalar
		local site = (sitesFolder :: Instance):FindFirstChild(upgrade.id)
		local spot = spots:FindFirstChild(upgrade.id)
		local wantSite = save ~= nil
			and not owned
			and spot ~= nil
			and spot:IsA("BasePart")
			and spot:GetAttribute("BoatPatrolX") == nil
			and hasAsset(upgrade.id)
			and FarmMath.getUpgradeStatus(save, upgrade.id) == "available"
		if wantSite and not site then
			buildSite(upgrade, spot :: BasePart, sitesFolder :: Instance, FarmMath.formatUpgradePrice(save, upgrade))
		elseif not wantSite and site then
			site:Destroy()
		end
	end
	applyLevelMarks(plot, spots, save)
	-- Ahır/bölge seviyesine bağlı süs yapıları (değirmen, tarla, kuyu...) bu çiftliğin durumuna göre gelir/gider
	DecorReveal.apply(plot, save)
	-- Yem kalitesi, depo genişletme ve hızlı büyüme seviyelerinin görünen karşılığı
	UpgradeLevelProps.apply(plot, save)
end

return UpgradeVisualService
