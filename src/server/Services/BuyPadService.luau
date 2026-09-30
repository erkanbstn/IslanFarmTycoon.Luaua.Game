--!strict
-- Dünyada satın alma butonları: adada satın alınabilir sıradaki yükseltmeler yerdeki fiyatlı bir
-- butonla durur. Oyuncu butona yaklaşıp etkileşince mevcut UpgradeService.tryBuy çağrılır; fiyat,
-- ön koşul ve sahiplik doğrulaması orada, sunucuda yapılır (yeni ekonomi mantığı yok).
-- Çalışma anında kurulur (haritaya kaydedilmez); yalnızca liste değişince yeniden çizilir.
-- Buton rengi (yeşil/kırmızı) client'ta kasaya göre belirlenir (BuyPads.client).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local UpgradeService = require(script.Parent:WaitForChild("UpgradeService"))
local UpgradeVisualService =
	require(script.Parent.Parent:WaitForChild("Presentation"):WaitForChild("UpgradeVisualService"))

local BuyPadService = {}

local PADS_NAME = "BuyPads"
local UPDATE_SECONDS = 1

-- Ada yerel (x, z) yuvaları: yolun ve bölge çitinin dışında, girişe yakın açık zemin.
local SLOTS: { [string]: { Vector2 } } = {
	home = { Vector2.new(-9, -29), Vector2.new(9, -29), Vector2.new(-14, -29), Vector2.new(14, -29) },
}
-- Bütün küçük adalar aynı yuvaları kullanır (yeni bir ada türü eklenince ayrıca tanımlamak gerekmez)
local SATELLITE_SLOTS = { Vector2.new(-8, -22), Vector2.new(8, -22), Vector2.new(-13, -22) }
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
function BuyPadService.pickUpgrades(
	save: any,
	islandId: string,
	limit: number,
	skip: ((upgradeId: string) -> boolean)?
): { Config.UpgradeConfig }
	local result: { Config.UpgradeConfig } = {}
	for _, upgrade in Config.UPGRADES do
		if
			not EXCLUDED_KINDS[upgrade.kind]
			and not (skip ~= nil and skip(upgrade.id))
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

local function disc(
	parent: Instance,
	name: string,
	diameter: number,
	height: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	-- Silindirin ekseni X'tir; dik durması için Z etrafında 90° döndürülür.
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = false, false, false, false
	p.Parent = parent
	return p
end

-- Taş kaide + parlayan halka + havada dönen altın para; renk (yeterli/yetersiz) client'ta halkaya uygulanır.
local function buildPad(
	container: Model,
	plot: Model,
	frame: CFrame,
	upgrade: Config.UpgradeConfig,
	slot: Vector2,
	cost: number
)
	local origin = frame * CFrame.new(slot.X, 0, slot.Y)
	local pad = disc(
		container,
		`Pad_{upgrade.id}`,
		5,
		0.5,
		origin * CFrame.new(0, 0.25, 0),
		Color3.fromRGB(122, 118, 108),
		Enum.Material.Cobblestone
	)
	local ring =
		disc(container, "Ring", 4.4, 0.12, origin * CFrame.new(0, 0.56, 0), UiTheme.Color.Disabled, Enum.Material.Neon)
	ring:SetAttribute("UpgradeId", upgrade.id)
	ring:SetAttribute("Cost", cost)
	CollectionService:AddTag(ring, "BuyPad")
	disc(
		container,
		"Inner",
		3.7,
		0.16,
		origin * CFrame.new(0, 0.6, 0),
		Color3.fromRGB(58, 54, 48),
		Enum.Material.SmoothPlastic
	)
	local coinPosition = origin.Position + Vector3.new(0, 2.3, 0)
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.22, 1.7, 1.7)
	coin.CFrame = CFrame.new(coinPosition)
	coin.Color = UiTheme.Color.Gold
	coin.Material = Enum.Material.Metal
	coin.Anchored = true
	coin.CanCollide, coin.CanTouch, coin.CanQuery, coin.CastShadow = false, false, false, false
	coin:SetAttribute("Cost", cost)
	coin:SetAttribute("BasePos", coinPosition)
	coin.Parent = container
	CollectionService:AddTag(coin, "BuyPadSpin")

	WorldUi.tag(pad, "PadTag", {
		text = `{upgrade.displayName} · {FarmMath.formatMoney(cost)}`,
		icon = upgrade.icon,
		tint = UiTheme.Color.Gold,
		widthStuds = 11,
		heightStuds = 1.9,
		offset = Vector3.new(0, 4.6, 0),
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
		BuyPadService.buyFromWorld(player, plot, upgrade.id)
	end)
end

-- Dünyadaki bir satın alma promptundan (kaide ya da yapım alanı tabelası) alım: sahiplik ve fiyat sunucuda doğrulanır.
function BuyPadService.buyFromWorld(player: Player, plot: Model, upgradeId: string)
	if PlotService.getOwner(plot) ~= player or PlotService.getPlot(player) ~= plot then
		return
	end
	local upgrade = Config.getUpgrade(upgradeId)
	if not upgrade then
		return
	end
	local owned = PlayerDataService.tryGet(player)
	if owned and owned.purchased[upgradeId] then
		-- Başka menüden alınmış: kaide/tabela eski kalmış olabilir; uyarı vermeden dünyayı tazele
		BuyPadService.apply(plot, owned)
		PlotService.refreshPlayerWorld(player)
		return
	end
	local ok, err = UpgradeService.tryBuy(player, upgradeId)
	if ok then
		Remotes.get("Notify"):FireClient(player, `{upgrade.displayName} alındı!`, "success")
	elseif err then
		Remotes.get("Notify"):FireClient(player, err, "error")
	end
end

function BuyPadService.clear(plot: Model)
	local existing = plot:FindFirstChild(PADS_NAME)
	if existing then
		existing:Destroy()
	end
end

function BuyPadService.apply(plot: Model, save: any)
	local wanted: { { island: string, upgrade: Config.UpgradeConfig, slot: Vector2, cost: number } } = {}
	local ids: { string } = {}
	for _, islandId in Config.FARM_ISLAND_ORDER do
		local slots = SLOTS[islandId] or SATELLITE_SLOTS
		if save.unlockedIslands[islandId] ~= true then
			continue
		end
		local function hasSite(upgradeId: string): boolean
			return UpgradeVisualService.hasBuildSite(plot, upgradeId)
		end
		for index, upgrade in BuyPadService.pickUpgrades(save, islandId, #slots, hasSite) do
			-- Fiyat takılı alet indirimine göre değişir: imzaya girer ki düğmeler eski fiyatla kalmasın
			local cost = FarmMath.getUpgradeCost(save, upgrade)
			table.insert(wanted, { island = islandId, upgrade = upgrade, slot = slots[index], cost = cost })
			table.insert(ids, `{islandId}:{upgrade.id}:{cost}`)
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
			buildPad(container, plot, frame, entry.upgrade, entry.slot, entry.cost)
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
	-- Yapım alanı tabelasındaki "Satın al" promptu (UpgradeVisualService kurar; alım burada).
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if prompt.Name ~= "BuySitePrompt" then
			return
		end
		local upgradeId = prompt:GetAttribute("UpgradeId")
		if typeof(upgradeId) ~= "string" or not RateLimiter.allow(player, "buySitePrompt", 0.4) then
			return
		end
		for _, plot in PlotService.getAllPlots() do
			if prompt:IsDescendantOf(plot) then
				BuyPadService.buyFromWorld(player, plot, upgradeId)
				return
			end
		end
	end)
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
