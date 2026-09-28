--!strict
-- Ada eklentileri: satın alınmadan yalnızca "Satılık" tabelası; alındığında yapı + etkileşim.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))

local IslandSpecialization = require(script.Parent:WaitForChild("IslandSpecialization"))
local ExtensionAreas = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ExtensionAreas"))

local function plotService()
	return require(script.Parent:WaitForChild("PlotService"))
end

local function extensionService()
	return require(script.Parent:WaitForChild("ExtensionService"))
end

local function upgradeService()
	return require(script.Parent:WaitForChild("UpgradeService"))
end

type PlayerSave = GameTypes.PlayerSave

local ExtensionVisualService = {}

local function getIslandModel(plot: Model, islandId: string): Model?
	local islands = plot:FindFirstChild("Islands")
	if not islands then
		return nil
	end
	for _, child in islands:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("FarmIslandId") == islandId then
			return child
		end
	end
	return nil
end

-- MapBuilder ile aynı: ada yürüme yüzeyi (IslandBase üstü).
local function getIslandSurfaceCf(island: Model): CFrame
	local base = island:FindFirstChild("IslandBase")
	if base and base:IsA("BasePart") then
		return base.CFrame * CFrame.new(0, base.Size.Y / 2, 0)
	end
	return island:GetPivot()
end

local function configurePrompt(prompt: ProximityPrompt)
	WorldUi.configureProximityPrompt(prompt)
end

local function attachPrompts(
	plot: Model,
	model: Model,
	extensionId: string,
	upgradeId: string,
	owned: boolean,
	save: PlayerSave?
)
	local layout = IslandSpecialization.EXTENSIONS[extensionId]
	if not layout then
		return
	end
	local anchor = model:FindFirstChild("ForSaleSign", true)
		or model:FindFirstChild("SpecialtySign", true)
		or model:FindFirstChildWhichIsA("BasePart", true)
	if not anchor or not anchor:IsA("BasePart") then
		return
	end

	for _, name in { "BuyExtensionPrompt", "ExtensionAssignPrompt", "ExtensionUnassignPrompt" } do
		local existing = anchor:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end

	if not owned then
		local buy = Instance.new("ProximityPrompt")
		buy.Name = "BuyExtensionPrompt"
		buy.ActionText = "Satın al"
		buy.ObjectText = layout.title
		buy.MaxActivationDistance = 12
		buy.RequiresLineOfSight = false
		buy:SetAttribute("UpgradeId", upgradeId)
		buy:SetAttribute("Locked", true)
		configurePrompt(buy)
		buy.Parent = anchor
		buy.Triggered:Connect(function(player: Player)
			if plotService().getOwner(plot) ~= player then
				return
			end
			local ok, err = upgradeService().tryBuy(player, upgradeId)
			if ok then
				local upgrade = Config.getUpgrade(upgradeId)
				if upgrade then
					Remotes.get("Notify"):FireClient(player, `{upgrade.displayName} açıldı!`, "success")
				end
			elseif err then
				Remotes.get("Notify"):FireClient(player, err, "error")
			end
		end)
		return
	end

	local ext = Config.getExtension(extensionId)
	if not ext or not save then
		return
	end
	local count = FarmMath.countInExtension(save, extensionId)

	local assign = Instance.new("ProximityPrompt")
	assign.Name = "ExtensionAssignPrompt"
	assign.ActionText = "Hayvan ekle"
	assign.ObjectText = `{layout.title} ({count}/{ext.capacity})`
	assign.MaxActivationDistance = 12
	assign.RequiresLineOfSight = false
	assign:SetAttribute("ExtensionId", extensionId)
	configurePrompt(assign)
	assign.Parent = anchor

	local unassign = Instance.new("ProximityPrompt")
	unassign.Name = "ExtensionUnassignPrompt"
	unassign.ActionText = "Hayvan çıkar"
	unassign.ObjectText = layout.title
	unassign.MaxActivationDistance = 12
	unassign.RequiresLineOfSight = false
	-- Aynı tuşlu iki balon aynı anda gösterilmez; çıkarma ayrı tuşta olsun.
	unassign.KeyboardKeyCode = Enum.KeyCode.F
	unassign.GamepadKeyCode = Enum.KeyCode.ButtonX
	unassign:SetAttribute("ExtensionId", extensionId)
	configurePrompt(unassign)
	unassign.Parent = anchor

	assign.Triggered:Connect(function(player: Player)
		if plotService().getOwner(plot) ~= player then
			return
		end
		local ok, err = extensionService().tryAssign(player, extensionId)
		if not ok and err then
			Remotes.get("Notify"):FireClient(player, err, "error")
		end
	end)
	unassign.Triggered:Connect(function(player: Player)
		if plotService().getOwner(plot) ~= player then
			return
		end
		local ok, err = extensionService().tryUnassign(player, extensionId)
		if not ok and err then
			Remotes.get("Notify"):FireClient(player, err, "error")
		end
	end)
end

function ExtensionVisualService.apply(plot: Model, save: PlayerSave?)
	local legacy = plot:FindFirstChild("ExtensionVisuals")
	if legacy then
		legacy:Destroy()
	end
	local islandsFolder = plot:FindFirstChild("Islands")
	if islandsFolder then
		for _, island in islandsFolder:GetChildren() do
			if island:IsA("Model") then
				local existing = island:FindFirstChild("ExtensionVisuals")
				if existing then
					existing:ClearAllChildren()
				end
			end
		end
	end

	for extensionId, layout in IslandSpecialization.EXTENSIONS do
		local upgrade = Config.getExtensionUpgrade(extensionId)
		if not upgrade then
			continue
		end
		local island = getIslandModel(plot, layout.island)
		if not island then
			continue
		end
		local islandUnlocked = save ~= nil and save.unlockedIslands[layout.island] == true
		local folder = island:FindFirstChild("ExtensionVisuals")
		if folder then
			folder:ClearAllChildren()
		else
			folder = Instance.new("Folder")
			folder.Name = "ExtensionVisuals"
			folder.Parent = island
		end
		if not islandUnlocked then
			continue
		end

		local surfaceCf = getIslandSurfaceCf(island)
		local owned = save ~= nil and save.purchased[upgrade.id] == true
		local model: Model
		if owned then
			model = IslandSpecialization.buildExtensionVisual(folder, surfaceCf, extensionId) :: Model
			if model then
				model:SetAttribute("VisualCreatedAt", game:GetService("Workspace"):GetServerTimeNow())
			end
		else
			model = IslandSpecialization.buildForSaleSign(
				folder,
				surfaceCf,
				extensionId,
				FarmMath.formatMoney(upgrade.cost)
			)
		end
		attachPrompts(plot, model, extensionId, upgrade.id, owned, save)
	end
end

function ExtensionVisualService.findExtensionArea(plot: Model, extensionId: string): (CFrame?, Vector3?, string?)
	return ExtensionAreas.find(plot, extensionId)
end

return ExtensionVisualService
