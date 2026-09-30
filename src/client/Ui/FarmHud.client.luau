--!strict
-- Oyuncu arayüzü orkestrasyonu: ekranı kurar, pencereleri/menüyü/paneli bağlar ve durumu dağıtır.
-- Görünüm kuralları UiKit'te; hesaplar sadece GÖSTERİM içindir, kararı sunucu verir.
-- Bölümler `Hud/` altındadır: StatsPanel (sol panel), GoalCard (hedef kartları), MenuBar (alt menü, rozetler),
-- Celebration (kilometre taşı panosu) ve pencere modülleri.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local ClientState = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientState"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local Merchant = require(Shared:WaitForChild("Modules"):WaitForChild("Merchant"))
local Golden = require(Shared:WaitForChild("Modules"):WaitForChild("Golden"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))
local IslandContext = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("IslandContext"))
local IslandManager = require(script.Parent:WaitForChild("IslandManager"))
local Sfx = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Sfx"))
local Hud = script.Parent:WaitForChild("Hud")
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
local StatsPanel = require(Hud:WaitForChild("StatsPanel"))
local GoalCard = require(Hud:WaitForChild("GoalCard"))
local MenuBar = require(Hud:WaitForChild("MenuBar"))
local Celebration = require(Hud:WaitForChild("Celebration"))
local ProductionPanel = require(script.Parent:WaitForChild("ProductionPanel"))

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
-- Sol panel, menü ve hedef kartları (oluşturma sırası ekrandaki üst üste binmeyi belirler)
---------------------------------------------------------------------------

local statsHud = StatsPanel.create(screenGui, goalsWindow.list)
local menu = MenuBar.create(screenGui, goalsWindow.list)
local onboarding = Onboarding.create(menu.shopButton, menu.upgradesButton)
local goal = GoalCard.create(statsHud.frame, goalsWindow.list, onboarding)
local celebrate = Celebration.create(screenGui)

menu.goalsButton.Activated:Connect(function()
	openCenter(goalsWindow)
end)
menu.inventoryButton.Activated:Connect(function()
	if inventoryPanel.window.isOpen() then
		inventoryPanel.window.close()
	else
		openCenter(inventoryPanel.window)
	end
end)

---------------------------------------------------------------------------
-- Çiftliğim penceresi: günlük ödül ve başarımlar
---------------------------------------------------------------------------

local updateStore = StoreSection.create(storeWindow.list)
local updateRewardsSection = RewardsSection.create(goalsWindow.list, menu.setGoalsBadge)
local function updateRewards(state: PlayerSave?)
	if not state then
		return
	end
	updateStore(state)
	updateRewardsSection(state)
end

local updateBoard = BoardSection.create(boardWindow.list)

menu.homeButton.Activated:Connect(function()
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
menu.shopButton.Activated:Connect(function()
	toggleWindow(shopWindow)
end)
menu.roadmapButton.Activated:Connect(function()
	toggleWindow(roadmapWindow)
end)

menu.upgradesButton.Activated:Connect(function()
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
	toastHolder.Position = if compact
		then UDim2.fromOffset(8, statsHud.frame.AbsoluteSize.Y + 20)
		else UDim2.new(0.5, 0, 0, 12)
	-- Dar ekranda sağ menüyü ve hava kartını bildirimlerin dışında tut.
	toastHolder.Size = UDim2.new(1, if compact then -128 else -24, 0, 0)
end
statsHud.frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutToasts)
PurchaseController.Completed:Connect(function(success: boolean, message: string?)
	-- Adalar penceresi açıkken bildirimi pencerenin kendi bildirim alanı gösterir (üstte, pencerenin önünde)
	if message and not IslandManager.isOpen() then
		showToast(message, if success then "success" else "error")
	end
end)

local seasonBar = SeasonBar.create(statsHud.frame)

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
		menu.updateProductionBadge(ClientState.get())
		updateRewards(ClientState.get())
		updateBoard(ClientState.get())
		task.wait(1)
	end
end)
---------------------------------------------------------------------------
-- Durum güncelleme
---------------------------------------------------------------------------

local shopDirty, roadmapDirty, upgradesDirty = true, true, true
local lastCash: number? = nil

local function onState(state: PlayerSave, structural: boolean)
	-- Asa geçersiz kılması yalnızca bu oyuncunun ekranını ve gelirini etkiler (Environment kendi katmanını uygular)
	Environment.setClientOverride(state.envOverride)
	screenGui.Enabled = true
	local income = FarmMath.computeIncomePerSecond(state)
	statsHud.update(state, income)
	goal.updateIsland(state, income)
	goal.updateGoal(state, income)
	menu.updateVisibility(state)
	celebrate(state)
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
		menu.updateBadges(state)
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
	statsHud.setCompact(compact)
	-- Kompakt: kasa, depo çubuğu ve tek satırlık mevsim/hava; ayrıntılar Çiftliğim penceresinde.
	seasonBar.setCompact(compact)
	-- Geniş: alt ortada yatay çubuk. Dar: sağ kenarın ortasında kısa sütun (üstteki oyuncu listesine uzanmaz).
	menu.setCompact(compact)
	layoutToasts()
	redraw()
end

local function placeGoals()
	goal.card.Parent = if compact then goalsWindow.list else statsHud.frame
	goal.card.LayoutOrder = if compact then 3 else 5
	goal.card.Visible = true
	menu.place(compact)
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
		statsHud.bounceCash()
	elseif kind == "error" then
		Sfx.play("error")
	end
end)
