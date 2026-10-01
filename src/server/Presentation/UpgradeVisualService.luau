--!strict
-- Yol haritasından alınan güçlendirmeleri adada bina olarak gösterir (silo, süt makinesi...).
-- Konum: plot içindeki BuildSpots klasöründe "<upgradeId>" adlı görünmez parça.
-- Kendi modelini kullanmak için: ServerStorage.Assets.Buildings içine upgrade id'si
-- ile aynı isimde bir Model koy (ör. "silo"). Model'in pivotu zemine oturmalı.
-- Parçalar: UpgradeParts (ortak yapı taşları), UpgradeBuildersHome/Barnyard/Workshops (bina görselleri),
-- UpgradeSites (yapım alanı ve seviye işaretleri).

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
local BuildersGoods = require(script.Parent:WaitForChild("UpgradeBuildersGoods"))
local BuildersHome = require(script.Parent:WaitForChild("UpgradeBuildersHome"))
local BuildersBarnyard = require(script.Parent:WaitForChild("UpgradeBuildersBarnyard"))
local BuildersWorkshops = require(script.Parent:WaitForChild("UpgradeBuildersWorkshops"))

type PlayerSave = GameTypes.PlayerSave
type Builder = UpgradeParts.Builder

local UpgradeVisualService = {}

local VISUAL_VERSION = 2
local METAL = UpgradeParts.METAL
local PRODUCTION_RECIPES = UpgradeParts.PRODUCTION_RECIPES
local makePart = UpgradeParts.makePart
local buildSite = UpgradeSites.buildSite
local applyLevelMarks = UpgradeSites.applyLevelMarks

-- Bina id -> görsel kurucu (gruplar ayrı dosyalarda)
local BUILDERS: { [string]: Builder } = {}
for _, group in { BuildersHome, BuildersBarnyard, BuildersWorkshops, BuildersGoods } do
	for id, builder in group do
		BUILDERS[id] = builder
	end
end

local function cloneAsset(upgradeId: string): Model?
	local assets = ServerStorage:FindFirstChild("Assets") or ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Buildings")
	local template = folder and folder:FindFirstChild(upgradeId)
	if template and template:IsA("Model") then
		return AssetSanitizer.clone(template, true)
	end
	return nil
end

local function buildUpgrade(upgradeId: string, spot: BasePart, parent: Instance)
	local base = spot.CFrame
	local cloned = cloneAsset(upgradeId)
	local built: Model
	if cloned then
		cloned:PivotTo(base)
		built = cloned
	else
		local builder = BUILDERS[upgradeId]
		if not builder then
			return
		end
		local fresh = Instance.new("Model")
		builder(fresh, base)
		built = fresh
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
		JobMarks.ensureAnchor(built, nil, 3)
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
	return spot ~= nil
		and spot:IsA("BasePart")
		and spot:GetAttribute("BoatPatrolX") == nil
		and BUILDERS[upgradeId] ~= nil
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
			and BUILDERS[upgrade.id] ~= nil
			and FarmMath.getUpgradeStatus(save, upgrade.id) == "available"
		if wantSite and not site then
			buildSite(upgrade, spot :: BasePart, sitesFolder :: Instance, FarmMath.getUpgradeCost(save, upgrade))
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
