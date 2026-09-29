--!strict
-- Dünyada satın alma butonları: adada satın alınabilir sıradaki yükseltmeler yerdeki fiyatlı bir
-- butonla durur. Oyuncu butona yaklaşıp etkileşince mevcut UpgradeService.tryBuy çağrılır; fiyat,
-- ön koşul ve sahiplik doğrulaması orada, sunucuda yapılır (yeni ekonomi mantığı yok).
-- Çalışma anında kurulur (haritaya kaydedilmez); yalnızca liste değişince yeniden çizilir.
-- Buton rengi (yeşil/kırmızı) client'ta kasaya göre belirlenir (BuyPads.client).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local UpgradeService = require(script.Parent:WaitForChild("UpgradeService"))

local BuyPadService = {}

local PADS_NAME = "BuyPads"
local UPDATE_SECONDS = 1
local PAD_SIZE = Vector3.new(4.2, 0.4, 4.2)

-- Ada yerel (x, z) yuvaları: yolun ve bölge çitinin dışında, girişe yakın açık zemin.
local SLOTS: { [string]: { Vector2 } } = {
	home = { Vector2.new(-9, -29), Vector2.new(9, -29), Vector2.new(-14, -29), Vector2.new(14, -29) },
	poultry = { Vector2.new(-8, -22), Vector2.new(8, -22), Vector2.new(-13, -22) },
	horse = { Vector2.new(-8, -22), Vector2.new(8, -22), Vector2.new(-13, -22) },
	goat = { Vector2.new(-8, -22), Vector2.new(8, -22), Vector2.new(-13, -22) },
}
-- Ada tabelası ve eklentiler kendi görselleriyle satılır; butona girmezler.
local EXCLUDED_KINDS: { [string]: boolean } = { island = true, extension = true }

-- IslandBase / PlotBase dik duran silindirdir (X ekseni, Z'de 90° döndürülmüş): yüzey çerçevesi.
local function surfaceFrame(plot: Model, islandId: string): CFrame?
	local base: Instance? = nil
	if islandId == "home" then
		base = plot:FindFirstChild("PlotBase")
	else
		local islands = plot:FindFirstChild("Islands")
		if islands then
			for _, island in islands:GetChildren() do
				if island:GetAttribute("FarmIslandId") == islandId then
					base = island:FindFirstChild("IslandBase")
					break
				end
			end
		end
	end
	if base and base:IsA("BasePart") then
		return base.CFrame * CFrame.Angles(0, 0, -math.pi / 2) * CFrame.new(0, base.Size.X / 2, 0)
	end
	return nil
end

-- Bir adada gösterilecek yükseltmeler: satın alınabilir olanlar, en ucuzdan başlayarak
function BuyPadService.pickUpgrades(save: any, islandId: string, limit: number): { Config.UpgradeConfig }
	local result: { Config.UpgradeConfig } = {}
	for _, upgrade in Config.UPGRADES do
		if
			not EXCLUDED_KINDS[upgrade.kind]
			and Config.getUpgradeIsland(upgrade) == islandId
			and FarmMath.getUpgradeStatus(save, upgrade.id) == "available"
		then
			table.insert(result, upgrade)
		end
	end
	table.sort(result, function(a: Config.UpgradeConfig, b: Config.UpgradeConfig): boolean
		if a.cost ~= b.cost then
			return a.cost < b.cost
		end
		return a.id < b.id
	end)
	while #result > limit do
		table.remove(result)
	end
	return result
end

local function buildPad(container: Model, plot: Model, frame: CFrame, upgrade: Config.UpgradeConfig, slot: Vector2)
	local pad = Instance.new("Part")
	pad.Name = `Pad_{upgrade.id}`
	pad.Size = PAD_SIZE
	pad.CFrame = frame * CFrame.new(slot.X, PAD_SIZE.Y / 2, slot.Y)
	pad.Color = UiTheme.Color.Red
	pad.Material = Enum.Material.Neon
	pad.Anchored = true
	pad.CanCollide, pad.CanTouch, pad.CanQuery = false, false, false
	pad.TopSurface, pad.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	pad:SetAttribute("UpgradeId", upgrade.id)
	pad:SetAttribute("Cost", upgrade.cost)
	pad.Parent = container
	CollectionService:AddTag(pad, "BuyPad")

	WorldUi.tag(pad, "PadTag", {
		text = `{upgrade.displayName} · {FarmMath.formatMoney(upgrade.cost)}`,
		icon = upgrade.icon,
		tint = UiTheme.Color.Gold,
		widthStuds = 11,
		heightStuds = 1.9,
		offset = Vector3.new(0, 3.4, 0),
		maxDistance = 70,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPadPrompt"
	prompt.ActionText = "Satın al"
	prompt.ObjectText = upgrade.displayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Locked", true) -- IslandPrompts: yalnızca sahibine görünür
	prompt:SetAttribute("UpgradeId", upgrade.id)
	prompt.Parent = pad
	prompt.Triggered:Connect(function(player: Player)
		if PlotService.getOwner(plot) ~= player or PlotService.getPlot(player) ~= plot then
			return
		end
		local ok, err = UpgradeService.tryBuy(player, upgrade.id)
		if ok then
			Remotes.get("Notify"):FireClient(player, `{upgrade.displayName} alındı!`, "success")
		elseif err then
			Remotes.get("Notify"):FireClient(player, err, "error")
		end
	end)
end

function BuyPadService.clear(plot: Model)
	local existing = plot:FindFirstChild(PADS_NAME)
	if existing then
		existing:Destroy()
	end
end

function BuyPadService.apply(plot: Model, save: any)
	local wanted: { { island: string, upgrade: Config.UpgradeConfig, slot: Vector2 } } = {}
	local ids: { string } = {}
	for _, islandId in Config.FARM_ISLAND_ORDER do
		local slots = SLOTS[islandId]
		if not slots or save.unlockedIslands[islandId] ~= true then
			continue
		end
		for index, upgrade in BuyPadService.pickUpgrades(save, islandId, #slots) do
			table.insert(wanted, { island = islandId, upgrade = upgrade, slot = slots[index] })
			table.insert(ids, `{islandId}:{upgrade.id}`)
		end
	end
	local signature = table.concat(ids, ",")
	local existing = plot:FindFirstChild(PADS_NAME)
	if existing and existing:GetAttribute("Signature") == signature then
		return
	end
	if existing then
		existing:Destroy()
	end
	if #wanted == 0 then
		return
	end
	local container = Instance.new("Model")
	container.Name = PADS_NAME
	container:SetAttribute("Signature", signature)
	for _, entry in wanted do
		local frame = surfaceFrame(plot, entry.island)
		if frame then
			buildPad(container, plot, frame, entry.upgrade, entry.slot)
		end
	end
	container.Parent = plot
end

local function refreshAll()
	for _, player in Players:GetPlayers() do
		for farmId, plot in PlotService.getAllOwned(player) do
			local data = PlayerDataService.getFarmView(player, farmId)
			if data then
				BuyPadService.apply(plot, data)
			end
		end
	end
end

function BuyPadService.init()
	task.spawn(function()
		while true do
			task.wait(UPDATE_SECONDS)
			local ok, err = pcall(refreshAll)
			if not ok then
				warn(`[BuyPad] {err}`)
			end
		end
	end)
end

return BuyPadService
