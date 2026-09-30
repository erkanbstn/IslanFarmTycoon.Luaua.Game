--!strict
-- Oyuncu arayüzü: para/depo paneli, menü, Hayvan Pazarı, Yol Haritası, bildirimler.
-- Görünüm kuralları UiKit'te; buradaki hesaplar sadece GÖSTERİM içindir, kararı sunucu verir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local Merchant = require(Shared:WaitForChild("Modules"):WaitForChild("Merchant"))
local Golden = require(Shared:WaitForChild("Modules"):WaitForChild("Golden"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent:WaitForChild("PurchaseController"))
local SettingsMenu = require(script.Parent:WaitForChild("SettingsMenu"))
local AdminPanel = require(script.Parent:WaitForChild("AdminPanel"))
local ProductionPanel = require(script.Parent:WaitForChild("ProductionPanel"))
local IslandContext = require(script.Parent:WaitForChild("IslandContext"))
local IslandManager = require(script.Parent:WaitForChild("IslandManager"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local Hud = script.Parent:WaitForChild("Hud")
local HudCommon = require(Hud:WaitForChild("HudCommon"))
local StoreSection = require(Hud:WaitForChild("StoreSection"))
local RewardsSection = require(Hud:WaitForChild("RewardsSection"))
local BoardSection = require(Hud:WaitForChild("BoardSection"))
local SeasonBar = require(Hud:WaitForChild("SeasonBar"))
local Onboarding = require(Hud:WaitForChild("Onboarding"))
local ItemShopWindow = require(Hud:WaitForChild("ItemShopWindow"))
local InventoryWindow = require(Hud:WaitForChild("InventoryWindow"))
local IslandTabs = require(Hud:WaitForChild("IslandTabs"))
local ShopWindow = require(Hud:WaitForChild("ShopWindow"))
local RoadmapWindow = require(Hud:WaitForChild("RoadmapWindow"))
local UpgradesWindow = require(Hud:WaitForChild("UpgradesWindow"))
local TweenServiceForCash = game:GetService("TweenService")

type PlayerSave = GameTypes.PlayerSave

local Color = UiKit.Color
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

---------------------------------------------------------------------------
-- Ekran
---------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FarmHud"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled = false -- Kayıt verisi gelince açılır (boş "$0" görünmesin)
screenGui.Parent = playerGui
ProductionPanel.bind(screenGui)

local compact = false

-- Çiftliğim: ahır, sıradaki ada ve (dar ekranda) hedef kartı ile ek menü karoları.
-- Ana HUD yalnızca sık bakılan bilgiyi (para, depo, mevsim, sıradaki hedef) gösterir.
local goalsWindow = UiKit.window(screenGui, {
	title = "Çiftliğim",
	icon = "🏆",
	tint = Color.Gold,
	width = 380,
	maxHeight = 480,
	anchor = Vector2.new(0.5, 0.5),
	position = UDim2.fromScale(0.5, 0.5),
})

-- Ortadaki pencereler aynı yerde açılır: biri açılınca diğerleri kapanır (üst üste binmesin)
local centerWindows: { UiKit.Window } = {}
local function openCenter(window: UiKit.Window)
	for _, other in centerWindows do
		if other ~= window then
			other.close()
		end
	end
	window.open()
end

-- Sipariş panosu ve destek dükkânı kendi pencerelerinde (Çiftliğim'e karışmaz)
local boardWindow = UiKit.window(screenGui, {
	title = "Sipariş Panosu",
	icon = "📋",
	tint = Color.Green,
	width = 380,
	maxHeight = 480,
	anchor = Vector2.new(0.5, 0.5),
	position = UDim2.fromScale(0.5, 0.5),
})
local storeWindow = UiKit.window(screenGui, {
	title = "Destek Dükkânı",
	icon = "🎒",
	tint = Color.Blue,
	width = 380,
	maxHeight = 480,
	anchor = Vector2.new(0.5, 0.5),
	position = UDim2.fromScale(0.5, 0.5),
})
table.insert(centerWindows, goalsWindow)
table.insert(centerWindows, boardWindow)
table.insert(centerWindows, storeWindow)
-- Eşya Dükkânı (meydandaki satıcı) ve Envanter: ortadaki pencereler, birbirini kapatır
local itemShop = ItemShopWindow.create(screenGui)
local inventoryPanel = InventoryWindow.create(screenGui)
table.insert(centerWindows, itemShop.window)
table.insert(centerWindows, inventoryPanel.window)

---------------------------------------------------------------------------
-- Sol panel: para, gelir, depo, mevsim, sıradaki hedef
---------------------------------------------------------------------------

local stats = UiKit.panel(screenGui)
stats.Name = "Stats"
stats.AnchorPoint = Vector2.new(0, 0.5)
stats.Position = UDim2.new(0, 12, 0.5, 0)
stats.Size = UDim2.fromOffset(240, 0)
stats.AutomaticSize = Enum.AutomaticSize.Y
UiKit.padding(stats, 12)
UiKit.list(stats, 8)
local farmContextLabel = UiKit.text(stats, IslandContext.name(), "Caption", Color.Gold)
farmContextLabel.LayoutOrder = -1
local dataHealth = UiKit.text(stats, "", "Caption", Color.Red)
dataHealth.LayoutOrder = 0
dataHealth.Visible = false

-- İkon kutusu + yanında alt alta yazılar (dönen çerçeveye yazılar eklenir)
local function statRow(parent: Instance, order: number, icon: string, tint: Color3): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 40)
	row.LayoutOrder = order
	row.Parent = parent

	UiKit.iconChip(row, icon, 40, tint)

	local texts = Instance.new("Frame")
	texts.BackgroundTransparency = 1
	texts.AnchorPoint = Vector2.new(0, 0.5)
	texts.Position = UDim2.new(0, 50, 0.5, 0)
	texts.Size = UDim2.new(1, -50, 0, 0)
	texts.AutomaticSize = Enum.AutomaticSize.Y
	texts.Parent = row
	UiKit.list(texts, 0)
	return texts
end

local cashTexts = statRow(stats, 1, "💰", Color.Gold)
local cashLabel = UiKit.text(cashTexts, "$0", "Display", Color.Gold)
cashLabel.LayoutOrder = 1
-- Para toplayınca kasadaki sayı hafifçe zıplar
local cashScale = Instance.new("UIScale")
cashScale.Parent = cashLabel
local function bounceCash()
	if localPlayer:GetAttribute("ReducedMotion") == true then
		return
	end
	cashScale.Scale = 1.25
	TweenServiceForCash:Create(cashScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
end
local incomeLabel = UiKit.text(cashTexts, "+$0/sn", "Caption")
incomeLabel.LayoutOrder = 2

local barnTexts = statRow(goalsWindow.list, 1, "🏚️", Color.Red)
local barnLabel = UiKit.text(barnTexts, "", "Heading")
barnLabel.LayoutOrder = 1
local barnDetail = UiKit.text(barnTexts, "", "Caption")
barnDetail.LayoutOrder = 2

-- Depo: başlık + değer, çubuk, ipucu
local storageBlock = Instance.new("Frame")
storageBlock.BackgroundTransparency = 1
storageBlock.Size = UDim2.new(1, 0, 0, 0)
storageBlock.AutomaticSize = Enum.AutomaticSize.Y
storageBlock.LayoutOrder = 3
storageBlock.Parent = stats
UiKit.list(storageBlock, 6)

local storageHeader = Instance.new("Frame")
storageHeader.BackgroundTransparency = 1
storageHeader.Size = UDim2.new(1, 0, 0, 20)
storageHeader.LayoutOrder = 1
storageHeader.Parent = storageBlock
local storageTitle = UiKit.text(storageHeader, "Depo", "Heading")
storageTitle.AutomaticSize = Enum.AutomaticSize.None
storageTitle.Size = UDim2.fromScale(0.4, 1)
local storageValue = UiKit.text(storageHeader, "", "Body", Color.TextMuted)
storageValue.AutomaticSize = Enum.AutomaticSize.None
storageValue.AnchorPoint = Vector2.new(1, 0)
storageValue.Position = UDim2.fromScale(1, 0)
storageValue.Size = UDim2.fromScale(0.6, 1)
storageValue.TextXAlignment = Enum.TextXAlignment.Right

local storageBar, setStorageBar = UiKit.progressBar(storageBlock, 10)
storageBar.LayoutOrder = 2
local hintLabel = UiKit.text(storageBlock, "", "Caption")
hintLabel.LayoutOrder = 3

-- Sıradaki ada kartı: oyuncunun uzun vadeli amacı
local islandCard = Instance.new("Frame")
islandCard.BackgroundColor3 = Color.Surface
islandCard.Size = UDim2.new(1, 0, 0, 0)
islandCard.AutomaticSize = Enum.AutomaticSize.Y
islandCard.LayoutOrder = 2
islandCard.Parent = goalsWindow.list
UiKit.corner(islandCard, UiKit.Radius.Card)
UiKit.stroke(islandCard, 0.6).Color = Color.Gold
UiKit.padding(islandCard, 10)

local islandChip = UiKit.iconChip(islandCard, "🏝️", 40, Color.Gold)
local islandTexts = Instance.new("Frame")
islandTexts.BackgroundTransparency = 1
islandTexts.Position = UDim2.fromOffset(50, 0)
islandTexts.Size = UDim2.new(1, -50, 0, 0)
islandTexts.AutomaticSize = Enum.AutomaticSize.Y
islandTexts.Parent = islandCard
UiKit.list(islandTexts, 1)
local islandHeader = UiKit.text(islandTexts, "SIRADAKİ ADA", "Caption", Color.Gold)
islandHeader.FontFace = UiKit.Font.Bold
islandHeader.LayoutOrder = 1
local islandName = UiKit.text(islandTexts, "", "Heading")
islandName.LayoutOrder = 2
local islandTrait = UiKit.text(islandTexts, "", "Caption")
islandTrait.LayoutOrder = 3
local islandEta = UiKit.text(islandTexts, "", "Caption", Color.Text)
islandEta.LayoutOrder = 4

-- Sıradaki hedef kartı
local goalCard = Instance.new("Frame")
goalCard.BackgroundColor3 = Color.Surface
goalCard.Size = UDim2.new(1, 0, 0, 0)
goalCard.AutomaticSize = Enum.AutomaticSize.Y
goalCard.LayoutOrder = 5
goalCard.Parent = stats
UiKit.corner(goalCard, UiKit.Radius.Card)
UiKit.padding(goalCard, 10)
UiKit.list(goalCard, 2)
local goalTitle = UiKit.text(goalCard, "SIRADAKİ HEDEF", "Caption", Color.Gold)
goalTitle.FontFace = UiKit.Font.Bold
goalTitle.LayoutOrder = 1
local goalLabel = UiKit.text(goalCard, "", "Body")
goalLabel.LayoutOrder = 2
local goalDetail = UiKit.text(goalCard, "", "Caption")
goalDetail.LayoutOrder = 3

---------------------------------------------------------------------------
-- Menü: geniş ekranda alt ortada yatay çubuk (sağ üstteki Roblox oyuncu listesine ve sohbete
-- değmez); dar ekranda sağ kenarda kısa dikey sütun, diğer karolar Çiftliğim penceresinde.
---------------------------------------------------------------------------

local dock = Instance.new("Frame")
dock.Name = "Menu"
dock.AnchorPoint = Vector2.new(0.5, 1)
dock.Position = UDim2.new(0.5, 0, 1, -10)
dock.Size = UDim2.new()
dock.AutomaticSize = Enum.AutomaticSize.XY
dock.BackgroundTransparency = 1
dock.Parent = screenGui
local dockLayout = UiKit.list(dock, 6, true)

-- Çiftliğim penceresindeki ek menü karoları (dar ekranda menüden taşınanlar)
local moreActions = Instance.new("Frame")
moreActions.Name = "MoreActions"
moreActions.BackgroundTransparency = 1
moreActions.Size = UDim2.new(1, 0, 0, 0)
moreActions.AutomaticSize = Enum.AutomaticSize.Y
moreActions.LayoutOrder = 10
moreActions.Visible = false
moreActions.Parent = goalsWindow.list
local moreGrid = Instance.new("UIGridLayout")
moreGrid.CellSize = UDim2.fromOffset(UiKit.MenuTileSize.X, UiKit.MenuTileSize.Y)
moreGrid.CellPadding = UDim2.fromOffset(6, 6)
moreGrid.SortOrder = Enum.SortOrder.LayoutOrder
moreGrid.Parent = moreActions

local hasKeyboard = UserInputService.KeyboardEnabled
local productionButton = UiKit.menuButton(dock, "🏭", "Üretim", Color.Green, if hasKeyboard then "R" else nil)
productionButton.Activated:Connect(function()
	ProductionPanel.open(screenGui)
end)
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if not processed and input.KeyCode == Enum.KeyCode.R then
		ProductionPanel.open(screenGui)
	end
end)
local shopButton = UiKit.menuButton(dock, "🐄", "Pazar", Color.Green, if hasKeyboard then "P" else nil)
local roadmapButton = UiKit.menuButton(dock, "🗺️", "Yol Haritası", Color.Blue, if hasKeyboard then "Y" else nil)
local upgradesButton = UiKit.menuButton(dock, "🛠️", "Yükseltmeler", Color.Gold, if hasKeyboard then "U" else nil)
local islandsButton = UiKit.menuButton(dock, "🧭", "Adalar", Color.Blue, if hasKeyboard then "I" else nil)
islandsButton.Activated:Connect(IslandManager.open)
local goalsButton = UiKit.menuButton(dock, "🏆", "Çiftliğim", Color.Gold, nil)
goalsButton.Activated:Connect(function()
	openCenter(goalsWindow)
end)
local inventoryButton = UiKit.menuButton(dock, "🎒", "Envanter", Color.Orange, if hasKeyboard then "B" else nil)
inventoryButton.Activated:Connect(function()
	if inventoryPanel.window.isOpen() then
		inventoryPanel.window.close()
	else
		openCenter(inventoryPanel.window)
	end
end)
local homeButton = UiKit.menuButton(dock, "🏠", "Adama Dön", Color.Orange, nil)
local settingsButton = UiKit.menuButton(dock, "⚙️", "Ayarlar", Color.TextMuted, nil)
local adminButton = UiKit.menuButton(dock, "🔑", "Yönetici", Color.Gold, nil)

-- Sıra ve yer: dar ekranda yalnızca "compactDock" karoları menüde kalır, diğerleri Çiftliğim'e taşınır.
type MenuEntry = { button: TextButton, compactDock: boolean }
local menuEntries: { MenuEntry } = {
	{ button = shopButton, compactDock = true },
	{ button = roadmapButton, compactDock = false },
	{ button = upgradesButton, compactDock = true },
	{ button = productionButton, compactDock = false },
	{ button = islandsButton, compactDock = false },
	{ button = goalsButton, compactDock = true },
	{ button = inventoryButton, compactDock = false },
	{ button = homeButton, compactDock = false },
	{ button = settingsButton, compactDock = false },
	{ button = adminButton, compactDock = false },
}
for index, entry in menuEntries do
	entry.button.LayoutOrder = index
end
local function updateAdminAccess()
	adminButton.Visible = localPlayer:GetAttribute("IsAdmin") == true
end
updateAdminAccess()
localPlayer:GetAttributeChangedSignal("IsAdmin"):Connect(updateAdminAccess)
adminButton.Activated:Connect(function()
	if localPlayer:GetAttribute("IsAdmin") == true then
		AdminPanel.open(screenGui)
	end
end)
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if not processed and input.KeyCode == Enum.KeyCode.F8 and localPlayer:GetAttribute("IsAdmin") == true then
		AdminPanel.open(screenGui)
	end
end)
settingsButton.Activated:Connect(function()
	SettingsMenu.open(screenGui)
end)

local setShopBadge = UiKit.badge(shopButton)
local setRoadmapBadge = UiKit.badge(roadmapButton)
local setUpgradesBadge = UiKit.badge(upgradesButton)
local setProductionBadge = UiKit.badge(productionButton)
local setGoalsBadge = UiKit.badge(goalsButton)
local onboarding = Onboarding.create(shopButton, upgradesButton)

---------------------------------------------------------------------------
-- Çiftliğim penceresi: günlük ödül ve başarımlar
---------------------------------------------------------------------------

local updateStore = StoreSection.create(storeWindow.list)
local updateRewardsSection = RewardsSection.create(goalsWindow.list, setGoalsBadge)
local function updateRewards(state: PlayerSave?)
	if not state then
		return
	end
	updateStore(state)
	updateRewardsSection(state)
end

local updateBoard = BoardSection.create(boardWindow.list)

homeButton.Activated:Connect(function()
	Remotes.get("RequestGoHome"):FireServer()
end)

---------------------------------------------------------------------------
-- Pencereler
---------------------------------------------------------------------------

-- Sağ kenarda, alttaki menü çubuğunun üstünde kalacak kadar yukarıda
local WINDOW_POSITION = UDim2.new(1, -12, 0.5, -30)

local shop = ShopWindow.create(screenGui, WINDOW_POSITION)
local shopWindow = shop.window
local roadmap = RoadmapWindow.create(screenGui, WINDOW_POSITION)
local roadmapWindow = roadmap.window
local upgradesHud = UpgradesWindow.create(screenGui, WINDOW_POSITION)
local upgradesWindow = upgradesHud.window

local function toggleWindow(window: UiKit.Window)
	local wasOpen = window.isOpen()
	shopWindow.close()
	roadmapWindow.close()
	upgradesWindow.close()
	if not wasOpen then
		window.open()
	end
end
shopButton.Activated:Connect(function()
	toggleWindow(shopWindow)
end)
roadmapButton.Activated:Connect(function()
	toggleWindow(roadmapWindow)
end)

upgradesButton.Activated:Connect(function()
	toggleWindow(upgradesWindow)
end)

-- Meydandaki satıcı NPC'ler: mevcut pencereleri açar (satın alma yine sunucuda doğrulanır)
local vendorActions: { [string]: () -> () } = {
	orders = function()
		openCenter(boardWindow)
	end,
	store = function()
		openCenter(itemShop.window)
	end,
	roadmap = function()
		if not roadmapWindow.isOpen() then
			toggleWindow(roadmapWindow)
		end
	end,
	travel = IslandManager.open,
}
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player?)
	if who and who ~= localPlayer then
		return
	end
	-- Adadaki pazar tezgâhı: hayvan pazarını açar (sağ menüdeki "Pazar" ile aynı)
	if prompt.Name == "MarketPrompt" then
		if not shopWindow.isOpen() then
			toggleWindow(shopWindow)
		end
		return
	end
	if prompt.Name ~= "VendorPrompt" then
		return
	end
	local action = prompt:GetAttribute("Action")
	local handler = if typeof(action) == "string" then vendorActions[action] else nil
	if handler then
		handler()
	end
end)
-- Klavye kısayolları: P = Pazar, Y = Yol Haritası, U = Yükseltmeler, I = Adalar
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.P then
		toggleWindow(shopWindow)
	elseif input.KeyCode == Enum.KeyCode.Y then
		toggleWindow(roadmapWindow)
	elseif input.KeyCode == Enum.KeyCode.U then
		toggleWindow(upgradesWindow)
	elseif input.KeyCode == Enum.KeyCode.I then
		IslandManager.open()
	elseif input.KeyCode == Enum.KeyCode.B then
		if inventoryPanel.window.isOpen() then
			inventoryPanel.window.close()
		else
			openCenter(inventoryPanel.window)
		end
	end
end)

local showToast = UiKit.toastHost(screenGui)
local toastHolder = screenGui:FindFirstChild("Toasts") :: Frame
local function layoutToasts()
	toastHolder.AnchorPoint = if compact then Vector2.zero else Vector2.new(0.5, 0)
	toastHolder.Position = if compact then UDim2.fromOffset(8, stats.AbsoluteSize.Y + 20) else UDim2.new(0.5, 0, 0, 12)
	-- Dar ekranda sağ menüyü ve hava kartını bildirimlerin dışında tut.
	toastHolder.Size = UDim2.new(1, if compact then -128 else -24, 0, 0)
end
stats:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutToasts)
PurchaseController.Completed:Connect(function(success: boolean, message: string?)
	-- Adalar penceresi açıkken bildirimi pencerenin kendi bildirim alanı gösterir (üstte, pencerenin önünde)
	if message and not IslandManager.isOpen() then
		showToast(message, if success then "success" else "error")
	end
end)

local orderButton = UiKit.button(goalCard, "Siparişi teslim et", "primary")
orderButton.Size = UDim2.new(1, 0, 0, 40)
orderButton.LayoutOrder = 4
orderButton.Visible = false
orderButton.Activated:Connect(function()
	local state = ClientState.get()
	if state and state.order and orderButton.Active then
		PurchaseController.submit("RequestClaimOrder", state.order.uid)
	end
end)

local seasonBar = SeasonBar.create(stats)

local function updateProductionBadge(state: PlayerSave?)
	local ready = 0
	if state and state.production then
		for recipeId, job in state.production do
			local recipe = Config.PRODUCTION_RECIPES[recipeId]
			if recipe and recipe.island == IslandContext.get() and job.readyAt <= Workspace:GetServerTimeNow() then
				ready += 1
			end
		end
	end
	setProductionBadge(ready)
end

-- Gezgin tüccar ve altın hayvan belirdiğinde bir kez haber ver (teklif Pazar penceresinde, hayvan çiftlikte parlar)
local lastMerchantCycle = -1
local lastGoldenCycle = -1
local function merchantNotice(state: PlayerSave?)
	if not state then
		return
	end
	local golden = Golden.current(state, localPlayer.UserId, Workspace:GetServerTimeNow())
	if golden and golden.cycle ~= lastGoldenCycle then
		lastGoldenCycle = golden.cycle
		showToast("Bir hayvanın altın gibi parlıyor! Yakala ve ödülünü al.", "info")
	end
	local offer = Merchant.offer(state, localPlayer.UserId, Workspace:GetServerTimeNow())
	if offer and offer.cycle ~= lastMerchantCycle then
		lastMerchantCycle = offer.cycle
		showToast("Gezgin tüccar meydana geldi: Pazar'da indirimli hayvanlar var!", "info")
	end
end

task.spawn(function()
	while true do
		seasonBar.update()
		merchantNotice(ClientState.get())
		updateProductionBadge(ClientState.get())
		updateRewards(ClientState.get())
		updateBoard(ClientState.get())
		task.wait(1)
	end
end)

---------------------------------------------------------------------------
-- Durum güncelleme
---------------------------------------------------------------------------

local purchaseHint = HudCommon.purchaseHint
local setPurchaseButton = HudCommon.setPurchaseButton

local function updateBadges(state: PlayerSave)
	updateProductionBadge(state)
	local animals, upgrades = 0, 0
	for _, animalId in Config.ANIMAL_ORDER do
		if
			FarmMath.hasUnlockedAnimalZone(state, animalId)
			and FarmMath.findZoneForAnimal(state, animalId)
			and state.cash >= FarmMath.getAnimalPrice(state, animalId)
		then
			animals += 1
		end
	end
	for _, upgrade in Config.UPGRADES do
		if
			upgrade.kind ~= "island"
			and IslandContext.upgradeIsland(upgrade) == IslandContext.get()
			and FarmMath.getUpgradeStatus(state, upgrade.id) == "available"
			and state.cash >= FarmMath.getUpgradeCost(state, upgrade)
		then
			upgrades += 1
		end
	end
	-- Tek önerilen adım parlar: önce yükseltme (kalıcı ilerleme), yoksa hayvan. Yol haritası
	-- yükseltmelerle aynı listeyi gösterdiği için ayrıca rozet almaz.
	setUpgradesBadge(upgrades)
	setShopBadge(if upgrades > 0 then 0 else animals)
	setRoadmapBadge(0)
end

local function updateGoal(state: PlayerSave, income: number)
	orderButton.Visible = false
	goalTitle.Text = "SIRADAKİ HEDEF"
	-- İlk adımlar: hayvan al → parayı topla → ilk yükseltme (durumdan türetilir, vurgular Onboarding'de)
	local cheapest: Config.UpgradeConfig? = nil
	for _, upgrade in Config.UPGRADES do
		if
			FarmMath.getUpgradeStatus(state, upgrade.id) == "available"
			and (not cheapest or FarmMath.getUpgradeCost(state, upgrade) < FarmMath.getUpgradeCost(state, cheapest))
		then
			cheapest = upgrade
		end
	end
	local step = onboarding.apply(state, cheapest ~= nil and state.cash >= FarmMath.getUpgradeCost(state, cheapest))
	if step == 2 then
		goalTitle.Text = "İLK ADIMLAR 2/3"
		goalLabel.Text = "Yeşil platforma basıp parayı topla"
		goalDetail.Text = "Hayvanların depoya para üretir; platforma basınca kasana geçer."
		return
	elseif step == 3 and cheapest then
		goalTitle.Text = "İLK ADIMLAR 3/3"
		goalLabel.Text = `İlk yükseltme: {cheapest.displayName} · {FarmMath.formatMoney(
			FarmMath.getUpgradeCost(state, cheapest)
		)}`
		goalDetail.Text = purchaseHint(state, FarmMath.getUpgradeCost(state, cheapest), income)
		return
	end
	if step == 1 then
		goalTitle.Text = "İLK ADIMLAR 1/3"
		local homeAnimal = Config.getHomeAnimal(state.activeMainFarmId)
		goalLabel.Text = if homeAnimal == "chicken"
			then "İlk hedef: yeni bir tavuk"
			elseif homeAnimal == "duck" then "İlk hedef: yeni bir ördek"
			else "İlk hedef: yeni bir inek"
		goalDetail.Text = purchaseHint(state, FarmMath.getAnimalPrice(state, homeAnimal), income)
		return
	end
	local best: Config.UpgradeConfig? = nil
	for _, upgrade in Config.UPGRADES do
		local status = FarmMath.getUpgradeStatus(state, upgrade.id)
		local useful = upgrade.id ~= "zone_pasture"
			or FarmMath.countInZone(state, "starter") >= FarmMath.getZoneCapacity(state, "starter")
		if
			useful
			and status == "available"
			and (not best or FarmMath.getUpgradeCost(state, upgrade) < FarmMath.getUpgradeCost(state, best))
		then
			best = upgrade
		end
	end
	-- Otlak diğer tüm tercihlerden sonra hâlâ eksik olabilir.
	if not best then
		for _, upgrade in Config.UPGRADES do
			if FarmMath.getUpgradeStatus(state, upgrade.id) == "available" then
				best = upgrade
				break
			end
		end
	end
	if best then
		goalLabel.Text = `{best.displayName} · {FarmMath.formatMoney(FarmMath.getUpgradeCost(state, best))}`
		goalDetail.Text = purchaseHint(state, FarmMath.getUpgradeCost(state, best), income)
		return
	end
	-- Yükseltme kalmadı: oyun sonu yatırımları (en ucuz ırk seviyesi ya da alan genişletmesi) hedef olur
	local lateLabel: string? = nil
	local lateCost = math.huge
	for _, animalId in Config.ANIMAL_ORDER do
		local status, _, cost = FarmMath.getLineageStatus(state, animalId)
		if status == "available" and cost < lateCost then
			lateCost = cost
			lateLabel =
				`{Config.ANIMALS[animalId].displayName} · Irk Sv.{FarmMath.getLineageLevel(state, animalId) + 1} · {FarmMath.formatMoney(
					cost
				)}`
		end
	end
	local lateIslands = FarmMath.themeIslands(state)
	for targetId, target in Config.BUILD_TARGETS do
		if table.find(lateIslands, target.island) then
			local status, _, cost = FarmMath.getExpansionStatus(state, targetId)
			if status == "available" and cost < lateCost then
				lateCost = cost
				lateLabel =
					`{Config.getBuildTargetName(targetId, state.activeMainFarmId)} · Geliştir Sv.{FarmMath.getExpansionLevel(
						state,
						targetId
					) + 1} · {FarmMath.formatMoney(cost)}`
			end
		end
	end
	if lateLabel then
		goalLabel.Text = lateLabel
		goalDetail.Text = purchaseHint(state, lateCost, income)
		return
	end
	goalTitle.Text = "ÇİFTLİK USTALIĞI VE SİPARİŞ"
	local capacity = 0
	local themeIslands = FarmMath.themeIslands(state)
	for zoneId, zone in Config.ZONES do
		if table.find(themeIslands, zone.island) then
			capacity += FarmMath.getZoneCapacity(state, zoneId)
		end
	end
	local adults = 0
	for _, animal in state.animals do
		if animal.stage == "adult" then
			adults += 1
		end
	end
	goalLabel.Text =
		`Ustalık: {adults}/{capacity} yetişkin · {FarmMath.countAnimals(state, "seabass")}/{FarmMath.getZoneCapacity(
			state,
			"fishpen"
		)} levrek`
	if state.order then
		local order = state.order
		local animal = Config.ANIMALS[order.animalId]
		goalDetail.Text =
			`{animal.product}: {math.floor(order.progress)}/{order.target} · Teslim edilen: {state.ordersCompleted}`
		orderButton.Visible = true
		setPurchaseButton(
			orderButton,
			"Siparişi teslim et",
			if order.progress >= order.target then "primary" else "disabled"
		)
	else
		goalDetail.Text = "Yetişkin hayvanların sıradaki sipariş için hazırlanıyor."
	end
end

local cashValue = Instance.new("NumberValue")
local cashTween: Tween? = nil
local cashTarget: number? = nil
cashValue.Changed:Connect(function(value: number)
	cashLabel.Text = FarmMath.formatMoney(value)
end)
local function animateCash(target: number)
	if cashTarget == target then
		return
	end
	local first = cashTarget == nil
	cashTarget = target
	if cashTween then
		cashTween:Cancel()
	end
	if first or localPlayer:GetAttribute("ReducedMotion") == true then
		cashValue.Value = target
		return
	end
	local tween = TweenService:Create(cashValue, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Value = target })
	cashTween = tween
	tween:Play()
end

local function updateIslandGoal(state: PlayerSave, income: number)
	local island, upgrade = FarmMath.getNextIsland(state)
	islandCard.Visible = island ~= nil
	if not island or not upgrade then
		return
	end
	islandChip.Text = island.icon
	islandName.Text = `{island.displayName} · {FarmMath.formatMoney(FarmMath.getUpgradeCost(state, upgrade))}`
	islandTrait.Text = island.trait
	local status, missing = FarmMath.getUpgradeStatus(state, upgrade.id)
	islandEta.Text = if status == "locked"
		then `Önce: {table.concat(missing, ", ")}`
		else purchaseHint(state, FarmMath.getUpgradeCost(state, upgrade), income)
end

local shopDirty, roadmapDirty, upgradesDirty = true, true, true
local lastCash: number? = nil
local function onState(state: PlayerSave, structural: boolean)
	-- Asa geçersiz kılması yalnızca bu oyuncunun ekranını ve gelirini etkiler (Environment kendi katmanını uygular)
	Environment.setClientOverride(state.envOverride)
	farmContextLabel.Text = IslandContext.name()
	screenGui.Enabled = true
	local status = localPlayer:GetAttribute("DataStatus")
	local dataError = localPlayer:GetAttribute("DataError")
	dataHealth.Visible = status ~= "Active" or (typeof(dataError) == "string" and dataError ~= "")
	dataHealth.Text = if status ~= "Active"
		then "Kayıt bağlantısı kesildi. Ekonomi durduruldu; lütfen yeniden katıl."
		else "Son kayıt tamamlanamadı; tekrar deneniyor."
	local income = FarmMath.computeIncomePerSecond(state)
	local cap = FarmMath.getStorageCap(state)
	local barnConfig = FarmMath.getBarnConfig(state)
	animateCash(state.cash)
	incomeLabel.Text = `+${FarmMath.formatRate(income)}/sn gelir`
	barnLabel.Text = barnConfig.displayName
	local ownedIslands, totalIslands = FarmMath.countIslands(state)
	local islandAnimals, islandCapacity = 0, 0
	for zoneId, zone in Config.ZONES do
		if zone.island == IslandContext.get() and state.unlockedZones[zoneId] then
			islandAnimals += FarmMath.countInZone(state, zoneId)
			islandCapacity += FarmMath.getZoneCapacity(state, zoneId)
		end
	end
	barnDetail.Text =
		`Seviye {state.barnLevel} · Ada {ownedIslands}/{totalIslands}\nBu ada: {islandAnimals}/{islandCapacity} hayvan`
	local auto = FarmMath.hasAutoCollect(state)
	if auto then
		storageValue.Text = "Otomatik"
		setStorageBar(1, Color.Green)
	else
		local ratio = if cap > 0 then state.stored / cap else 0
		storageValue.Text = `{FarmMath.formatMoney(state.stored)} / {FarmMath.formatMoney(cap)}`
		setStorageBar(ratio, if ratio >= 1 then Color.Red elseif ratio > 0.8 then Color.Orange else Color.Green)
	end
	hintLabel.Text = if localPlayer:GetAttribute("DataPersistent") == false
		then "Kayıtsız Studio testi: bu ilerleme saklanmaz."
		elseif auto then "Otomatik toplama açık. Çevrimdışı kazanç da kasana eklenir."
		elseif state.stored >= cap then "Depo dolu, üretim durdu! Yeşil platforma bas."
		else "Parayı almak için yeşil platforma bas. Çevrimdışı kazanç kasana eklenir."
	updateIslandGoal(state, income)
	updateGoal(state, income)
	updateRewards(state)
	updateBoard(state)
	if itemShop.window.isOpen() then
		itemShop.update(state)
	end
	if inventoryPanel.window.isOpen() then
		inventoryPanel.update(state)
	end
	shopDirty = shopDirty or structural
	roadmapDirty = roadmapDirty or structural
	upgradesDirty = upgradesDirty or structural
	local cashChanged = lastCash ~= state.cash
	if structural or cashChanged then
		updateBadges(state)
	end
	if shopWindow.isOpen() and (shopDirty or cashChanged) then
		shop.update(state, shopDirty)
		shopDirty = false
	end
	if roadmapWindow.isOpen() and (roadmapDirty or cashChanged) then
		roadmap.update(state, roadmapDirty)
		roadmapDirty = false
	end
	if upgradesWindow.isOpen() and (upgradesDirty or cashChanged) then
		upgradesHud.update(state, upgradesDirty)
		upgradesDirty = false
	end
	lastCash = state.cash
end

local function redraw()
	local state = ClientState.get()
	if state then
		onState(state, true)
	end
end
itemShop.window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
	if itemShop.window.isOpen() then
		redraw()
	end
end)
inventoryPanel.window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
	if inventoryPanel.window.isOpen() then
		redraw()
	end
end)
shopWindow.frame:GetPropertyChangedSignal("Visible"):Connect(function()
	if shopWindow.isOpen() then
		redraw()
	end
end)
roadmapWindow.frame:GetPropertyChangedSignal("Visible"):Connect(function()
	if roadmapWindow.isOpen() then
		redraw()
	end
end)
upgradesWindow.frame:GetPropertyChangedSignal("Visible"):Connect(function()
	if upgradesWindow.isOpen() then
		redraw()
	end
end)
PurchaseController.Changed:Connect(redraw)
IslandContext.Changed:Connect(redraw)
Environment.onChanged(redraw)
localPlayer:GetAttributeChangedSignal("DataStatus"):Connect(redraw)
localPlayer:GetAttributeChangedSignal("DataError"):Connect(redraw)

local function resizeHud()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	-- Kısa ama geniş pencerelerde (ör. 1600x645) tam yerleşim kullanılır; yalnızca dar ya da çok kısa ekran kompakt olur.
	compact = camera.ViewportSize.X < 900 or camera.ViewportSize.Y < 560
	stats.AnchorPoint = if compact then Vector2.zero else Vector2.new(0, 0.5)
	stats.Position = if compact then UDim2.fromOffset(8, 8) else UDim2.new(0, 12, 0.5, 0)
	stats.Size = if compact then UDim2.fromOffset(200, 0) else UDim2.fromOffset(240, 0)
	-- Kompakt: kasa, depo çubuğu ve tek satırlık mevsim/hava; ayrıntılar Çiftliğim penceresinde.
	seasonBar.setCompact(compact)
	farmContextLabel.Visible = not compact
	hintLabel.Visible = not compact
	-- Geniş: alt ortada yatay çubuk. Dar: sağ kenarın ortasında kısa sütun (üstteki oyuncu listesine uzanmaz).
	dockLayout.FillDirection = if compact then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	dock.AnchorPoint = if compact then Vector2.new(1, 0.5) else Vector2.new(0.5, 1)
	dock.Position = if compact then UDim2.new(1, -8, 0.5, 0) else UDim2.new(0.5, 0, 1, -10)
	layoutToasts()
	redraw()
end

local function placeGoals()
	goalCard.Parent = if compact then goalsWindow.list else stats
	goalCard.LayoutOrder = if compact then 3 else 5
	goalCard.Visible = true
	moreActions.Visible = compact
	for _, entry in menuEntries do
		entry.button.Parent = if compact and not entry.compactDock then moreActions else dock
	end
end
local cameraConnection: RBXScriptConnection? = nil
local function watchCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
	end
	local camera = Workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			resizeHud()
			placeGoals()
		end)
	end
	resizeHud()
	placeGoals()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()
ClientState.onChanged(onState)
ClientState.onChanged(IslandTabs.refreshSafe)
IslandContext.Changed:Connect(IslandTabs.refreshSafe)
Remotes.get("Notify").OnClientEvent:Connect(function(message: string, kind: string?, amount: number?)
	if typeof(message) == "string" then
		showToast(message, kind)
	end
	-- Para toplama ödülü: ses + kasa sayısı zıplaması (yüzen yazı ve parçacık CollectorGuide'da)
	if kind == "money" and typeof(amount) == "number" then
		Sfx.play("coin", 0.08)
		bounceCash()
	elseif kind == "error" then
		Sfx.play("error")
	end
end)
