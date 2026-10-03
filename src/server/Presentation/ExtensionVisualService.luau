--!strict
-- Ada eklentileri: satın alınmadan yalnızca "Satılık" tabelası; alındığında yapı + etkileşim.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local InstanceUtil = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("InstanceUtil"))
local JobMarks = require(script.Parent:WaitForChild("JobMarks"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))

local IslandSpecialization = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("IslandSpecialization"))
local ModelAssets = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("ModelAssets"))
local ExtensionAreas = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ExtensionAreas"))

local function plotService()
	return require(script.Parent.Parent:WaitForChild("Services"):WaitForChild("PlotService"))
end

local function extensionService()
	return require(script.Parent.Parent:WaitForChild("Services"):WaitForChild("ExtensionService"))
end

local function upgradeService()
	return require(script.Parent.Parent:WaitForChild("Services"):WaitForChild("UpgradeService"))
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
		-- IslandBase dik duran bir silindirdir (X ekseni, Z'de 90° döndürülmüş); yüzey = eski düz çerçeve + yükseklik/2.
		return base.CFrame * CFrame.Angles(0, 0, -math.pi / 2) * CFrame.new(0, base.Size.X / 2, 0)
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

	-- Etkileşim balonları tabela yazısını kapatmasın ve birbirine girmesin: direk dibindeki görünmez
	-- bir noktaya bağlanır, "ekle" üstte "çıkar" altta durur.
	local promptAnchor = Instance.new("Part")
	promptAnchor.Name = "ExtensionPromptAnchor"
	promptAnchor.Size = Vector3.one
	promptAnchor.Transparency = 1
	promptAnchor.Anchored = true
	promptAnchor.CanCollide, promptAnchor.CanQuery, promptAnchor.CanTouch, promptAnchor.CastShadow =
		false, false, false, false
	promptAnchor.CFrame = CFrame.new(anchor.Position.X, anchor.Position.Y - 1.2, anchor.Position.Z)
	promptAnchor.Parent = model

	if not owned then
		local buy = Instance.new("ProximityPrompt")
		buy.Name = "BuyExtensionPrompt"
		buy.ActionText = "Satın al"
		buy.ObjectText = layout.title
		buy.HoldDuration = 0.5 -- yanlışlıkla satın alma olmasın: basılı tut
		buy.MaxActivationDistance = 12
		buy.RequiresLineOfSight = false
		buy:SetAttribute("UpgradeId", upgradeId)
		buy:SetAttribute("Locked", true)
		configurePrompt(buy)
		buy.Parent = promptAnchor
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
	local capacity = FarmMath.getExtensionCapacity(save, extensionId)

	local assign = Instance.new("ProximityPrompt")
	assign.Name = "ExtensionAssignPrompt"
	assign.ActionText = "Hayvan gönder"
	assign.ObjectText = `{layout.title} ({count}/{capacity})`
	assign.MaxActivationDistance = 12
	assign.RequiresLineOfSight = false
	assign:SetAttribute("ExtensionId", extensionId)
	configurePrompt(assign)
	assign.UIOffset = Vector2.new(0, -48)
	assign.Parent = promptAnchor

	local unassign = Instance.new("ProximityPrompt")
	unassign.Name = "ExtensionUnassignPrompt"
	unassign.ActionText = "Geri çağır"
	unassign.ObjectText = layout.title
	unassign.MaxActivationDistance = 12
	unassign.RequiresLineOfSight = false
	-- Aynı tuşlu iki balon aynı anda gösterilmez; çıkarma ayrı tuşta olsun.
	unassign.KeyboardKeyCode = Enum.KeyCode.F
	unassign.GamepadKeyCode = Enum.KeyCode.ButtonX
	unassign:SetAttribute("ExtensionId", extensionId)
	configurePrompt(unassign)
	unassign.UIOffset = Vector2.new(0, 48)
	unassign.Parent = promptAnchor

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

-- Eklenti kapasitesi 2'nin üstüne çıktıkça alanın arka kenarına yenisi eklenir:
-- 3. hayvan: su teknesi ve saman balyaları, 4. hayvan: gölgelik (dört direk, çatı) ve fener.
local function addCapacityProps(parent: Instance, surfaceCf: CFrame, layout: any, capacity: number)
	local extra = capacity - 2
	if extra <= 0 then
		return
	end
	-- Hazır kapasite süsü (assets/ExtensionCapacity/CapacityProps_<eklentiId>_Cap3|Cap4, pivot = ada yüzeyi)
	local ready = ModelAssets.clone("ExtensionCapacity", `CapacityProps_{layout.id}_Cap{math.min(capacity, 4)}`)
	if ready then
		ready:PivotTo(surfaceCf)
		ready.Name = "CapacityProps"
		ready.Parent = parent
		return
	end
	warn(
		`[ExtensionVisual] assets/ExtensionCapacity/CapacityProps_{layout.id}_Cap{math.min(capacity, 4)}.rbxmx bulunamadı`
	)
end

local function syncCapacityProps(parent: Instance, surfaceCf: CFrame, layout: any, capacity: number)
	local visualCapacity = math.min(capacity, 4)
	local existing = parent:FindFirstChild("CapacityProps")
	if parent:GetAttribute("VisualCapacity") == visualCapacity and (visualCapacity <= 2 or existing) then
		return
	end
	if existing then
		existing:Destroy()
	end
	addCapacityProps(parent, surfaceCf, layout, visualCapacity)
	parent:SetAttribute("VisualCapacity", visualCapacity)
	IslandSpecialization.markObstacles(parent)
end

function ExtensionVisualService.apply(plot: Model, save: PlayerSave?)
	local legacy = plot:FindFirstChild("ExtensionVisuals")
	if legacy then
		legacy:Destroy()
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
		local owned = save ~= nil and save.purchased[upgrade.id] == true
		local now = DateTime.now().UnixTimestampMillis / 1000
		local count, startedAt, endsAt = 0, nil, nil
		local capacity = 0
		if save ~= nil then
			count, startedAt, endsAt = JobMarks.extensionSummary(save, extensionId, now)
			capacity = FarmMath.getExtensionCapacity(save, extensionId)
		end
		-- Yalnızca görünür yapı türü değişince yeniden kur. İndirimler, işler ve kapasite ana yapıyı değiştirmez.
		local priceText = FarmMath.formatUpgradePrice(save, upgrade)
		local signature = `{islandUnlocked}|{owned}`
		-- Aynı adadaki eklentiler (ör. keçi adası) imzayı ve klasörü paylaşmasın: her birinin kendi alt klasörü var.
		local root = InstanceUtil.getOrCreateFolder(island, "ExtensionVisuals")
		if root:GetAttribute("Signature") ~= nil then
			root:ClearAllChildren()
			root:SetAttribute("Signature", nil)
		end
		local folder = root:FindFirstChild(extensionId)
		local previousSignature = if folder then folder:GetAttribute("Signature") else nil
		local sameStructure = previousSignature == signature
			or (
				typeof(previousSignature) == "string"
				and string.sub(previousSignature, 1, #signature + 1) == signature .. "|"
			)
		if folder and sameStructure then
			folder:SetAttribute("Signature", signature)
			local existing = folder:FindFirstChild(extensionId)
			if existing and existing:IsA("Model") then
				syncCapacityProps(folder, getIslandSurfaceCf(island), layout, capacity)
				JobMarks.setExtension(existing, count, capacity, startedAt, endsAt)
				local assign = existing:FindFirstChild("ExtensionAssignPrompt", true)
				if assign and assign:IsA("ProximityPrompt") then
					assign.ObjectText = `{layout.title} ({count}/{capacity})`
				end
			elseif islandUnlocked and not owned and folder:GetAttribute("PriceText") ~= priceText then
				local sale = folder:FindFirstChild(`ForSale_{extensionId}`)
				local board = if sale then sale:FindFirstChild("ForSaleSign", true) else nil
				if board then
					WorldUi.setSignText(board, `Satılık · {priceText}`)
					folder:SetAttribute("PriceText", priceText)
				end
			end
			continue
		end
		local target = InstanceUtil.getOrCreateFolder(root, extensionId)
		if folder then
			target:ClearAllChildren()
		end
		target:SetAttribute("Signature", signature)
		if not islandUnlocked then
			continue
		end

		local surfaceCf = getIslandSurfaceCf(island)
		local model: Model
		if owned then
			model = IslandSpecialization.buildExtensionVisual(target, surfaceCf, extensionId) :: Model
			if model then
				model:SetAttribute("VisualCreatedAt", game:GetService("Workspace"):GetServerTimeNow())
				-- Eklentide duran hayvanlar: tabelanın üstünde "duran/kapasite" ve ilk dönüşe kalan süre
				local signBoard = model:FindFirstChild("SpecialtySign", true)
				JobMarks.ensureAnchor(model, if signBoard and signBoard:IsA("BasePart") then signBoard else nil, 3)
				JobMarks.setExtension(model, count, capacity, startedAt, endsAt)
				syncCapacityProps(target, surfaceCf, layout, capacity)
			end
		else
			model = IslandSpecialization.buildForSaleSign(target, surfaceCf, extensionId, priceText)
			target:SetAttribute("PriceText", priceText)
		end
		attachPrompts(plot, model, extensionId, upgrade.id, owned, save)
	end
end

function ExtensionVisualService.findExtensionArea(plot: Model, extensionId: string): (CFrame?, Vector3?, string?)
	return ExtensionAreas.find(plot, extensionId)
end

return ExtensionVisualService
