--!strict
-- Oyuncu arayüzü orkestrasyonu: ekranı kurar, pencereleri/menüyü/paneli bağlar ve durumu dağıtır.
-- Görünüm kuralları UiKit'te; hesaplar sadece GÖSTERİM içindir, kararı sunucu verir.
-- Bölümler `Hud/` altındadır: StatsPanel (sol panel), GoalCard (hedef kartları), MenuBar (alt menü, rozetler),
-- Celebration (kilometre taşı panosu) ve pencere modülleri.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local ClientState = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientState"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local Golden = require(Shared:WaitForChild("Modules"):WaitForChild("Golden"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))
local IslandContext = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("IslandContext"))
local IslandManager = require(script.Parent:WaitForChild("IslandManager"))
local Sfx = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Sfx"))
local Hud = script.Parent:WaitForChild("Hud")
local RewardsSection = require(Hud:WaitForChild("RewardsSection"))
local BoardSection = require(Hud:WaitForChild("BoardSection"))
local SeasonBar = require(Hud:WaitForChild("SeasonBar"))
local Onboarding = require(Hud:WaitForChild("Onboarding"))
local OnboardingBanner = require(Hud:WaitForChild("OnboardingBanner"))
local ItemShopWindow = require(Hud:WaitForChild("ItemShopWindow"))
local InventoryWindow = require(Hud:WaitForChild("InventoryWindow"))
local MarketWindow = require(Hud:WaitForChild("MarketWindow"))
local RebirthWindow = require(Hud:WaitForChild("RebirthWindow"))
local IslandTabs = require(Hud:WaitForChild("IslandTabs"))
local ShopWindow = require(Hud:WaitForChild("ShopWindow"))
local MerchantBadge = require(Hud:WaitForChild("MerchantBadge"))
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
-- Güvenli alan + ekran boyutuna bağlı ölçek: tüm HUD bu köke yerleşir (üst menü çubuğu kenardan kenara kalabilir)
local hudRoot = UiKit.screenRoot(screenGui)
ProductionPanel.bind(hudRoot)

local compact = false

-- Ödüller: günlük ödül, mevsim hedefi ve başarımlar.
local rewardsWindow = UiKit.window(hudRoot, {
	title = "Ödüller",
	icon = "🏆",
	tint = Color.Gold,
	width = 380,
	maxHeight = 480,
	anchor = Vector2.new(0.5, 0.5),
	position = UDim2.fromScale(0.5, 0.5),
})

-- Tüm ana pencereler tek kuralla yönetilir (Ui/Kit/Windows): aynı anda biri açık olur, yenisi açılınca öbürleri kapanır.
-- Menü karosu ve kısayollar `toggleWindow` (açıksa kapatır), dünya etkileşimleri `showWindow` (açıksa dokunmaz) kullanır.
local toggleWindow = UiKit.toggleWindow
local showWindow = UiKit.showWindow

-- Sipariş panosu ve destek dükkânı kendi pencerelerinde (Ödüller'e karışmaz)
local boardWindow = UiKit.window(hudRoot, {
	title = "Sipariş Panosu",
	icon = "📋",
	tint = Color.Green,
	width = 380,
	maxHeight = 480,
	anchor = Vector2.new(0.5, 0.5),
	position = UDim2.fromScale(0.5, 0.5),
})
-- Eşya Dükkânı (meydandaki satıcı) ve Envanter
local progressionPanel = MarketWindow.create(hudRoot)
local itemShop = ItemShopWindow.create(hudRoot, function()
	progressionPanel.open("permanent")
end)
local inventoryPanel = InventoryWindow.create(hudRoot)
local rebirthPanel = RebirthWindow.create(hudRoot)

---------------------------------------------------------------------------
-- Sol panel, menü ve hedef kartları (oluşturma sırası ekrandaki üst üste binmeyi belirler)
---------------------------------------------------------------------------

local statsHud = StatsPanel.create(hudRoot)
-- Bildirim alanı aşağıda kurulur; menü karosu açılış bildirimi oraya aktarılır
local toastRelay: { show: (message: string, kind: string?) -> () } = {
	show = function(_message: string, _kind: string?) end,
}
local menu = MenuBar.create(hudRoot, function(message: string)
	toastRelay.show(message, "info")
end)
local onboarding = Onboarding.create({
	shop = menu.shopButton,
	upgrades = menu.upgradesButton,
	roadmap = menu.roadmapButton,
	production = menu.productionButton,
})
local onboardingBanner = OnboardingBanner.create(hudRoot)
local goal = GoalCard.create(statsHud.frame, onboarding, onboardingBanner)
local celebrate = Celebration.create(hudRoot)
menu.goldButton.Activated:Connect(function()
	toggleWindow(progressionPanel.window)
end)
statsHud.progressionButton.Activated:Connect(function()
	progressionPanel.open("convert")
end)
menu.rebirthButton.Activated:Connect(function()
	toggleWindow(rebirthPanel.window)
end)

menu.rewardsButton.Activated:Connect(function()
	toggleWindow(rewardsWindow)
end)
menu.storeButton.Activated:Connect(function()
	toggleWindow(progressionPanel.window)
end)
menu.inventoryButton.Activated:Connect(function()
	toggleWindow(inventoryPanel.window)
end)

---------------------------------------------------------------------------
-- Ödüller penceresi: günlük ödül ve başarımlar
---------------------------------------------------------------------------

local updateRewardsSection, updateRewardsBadge = RewardsSection.create(rewardsWindow.list, menu.setRewardsBadge)
-- Kapalı pencerenin içeriği çizilmez (açılınca `redraw` tazeler); yalnızca Ödüller rozet sayısı güncel tutulur.
local function updateRewards(state: PlayerSave?)
	if not state then
		return
	end
	if rewardsWindow.isOpen() then
		updateRewardsSection(state)
	else
		updateRewardsBadge(state)
	end
end

local updateBoardSection = BoardSection.create(boardWindow.list)
local function updateBoard(state: PlayerSave?)
	if boardWindow.isOpen() then
		updateBoardSection(state)
	end
end

menu.homeButton.Activated:Connect(function()
	Remotes.get("RequestGoHome"):FireServer()
end)

---------------------------------------------------------------------------
-- Pencereler
---------------------------------------------------------------------------

-- Sağ kenarda, sağ menü sütununun (76 px + boşluk) soluna yaslı
local WINDOW_POSITION = UDim2.new(1, -96, 0.5, 0)

local shop = ShopWindow.create(hudRoot, WINDOW_POSITION)
local shopWindow = shop.window
local roadmap = RoadmapWindow.create(hudRoot, WINDOW_POSITION)
local roadmapWindow = roadmap.window
local upgradesHud = UpgradesWindow.create(hudRoot, WINDOW_POSITION)
local upgradesWindow = upgradesHud.window

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
		showWindow(boardWindow)
	end,
	store = function()
		showWindow(itemShop.window)
	end,
	roadmap = function()
		showWindow(roadmapWindow)
	end,
	travel = IslandManager.open,
}
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player?)
	if who and who ~= localPlayer then
		return
	end
	-- Adadaki pazar tezgâhı: hayvan pazarını açar (sağ menüdeki "Pazar" ile aynı)
	if prompt.Name == "MarketPrompt" then
		showWindow(shopWindow)
		return
	end
	-- Ahırdaki sandık: envanter penceresi (Ahır Deposu bölümü üstte) açılır
	if prompt.Name == "BarnChestPrompt" then
		showWindow(inventoryPanel.window)
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
		IslandManager.toggle()
	elseif input.KeyCode == Enum.KeyCode.B then
		toggleWindow(inventoryPanel.window)
	end
end)
-- Gamepad: DPad Yukarı = Pazar, Sağ = Yükseltmeler, Sol = Adalar, Aşağı = Envanter (klavye kısayollarının karşılığı).
-- Arayüz gezintisi açıkken (bir pencere açık ya da bir karo seçili) DPad gezinti için bırakılır; menüyü yalnızca boştayken açar.
-- Açık pencereyi B kapatır (Ui/Kit/Windows), seçimi geri verir.
local gamepadMenu: { [Enum.KeyCode]: () -> () } = {
	[Enum.KeyCode.DPadUp] = function()
		toggleWindow(shopWindow)
	end,
	[Enum.KeyCode.DPadRight] = function()
		toggleWindow(upgradesWindow)
	end,
	[Enum.KeyCode.DPadLeft] = IslandManager.toggle,
	[Enum.KeyCode.DPadDown] = function()
		toggleWindow(inventoryPanel.window)
	end,
}
ContextActionService:BindActionAtPriority(
	"HudGamepadMenu",
	function(_name: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
		local open = gamepadMenu[input.KeyCode]
		-- HUD veri gelmeden kapalıdır: görünmez pencere açılmasın
		if
			state ~= Enum.UserInputState.Begin
			or open == nil
			or not screenGui.Enabled
			or GuiService.SelectedObject ~= nil
		then
			return Enum.ContextActionResult.Pass
		end
		open()
		return Enum.ContextActionResult.Sink
	end,
	false,
	Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.DPadUp,
	Enum.KeyCode.DPadRight,
	Enum.KeyCode.DPadLeft,
	Enum.KeyCode.DPadDown
)
local showToast = UiKit.toastHost(hudRoot)
toastRelay.show = showToast
local toastHolder = hudRoot:FindFirstChild("Toasts") :: Frame
-- Bildirimler üst menü çubuğunun (60 px) altında, sağ menü sütununa ve sol panele taşmadan durur.
toastHolder.AnchorPoint = Vector2.new(0.5, 0)
-- Gezgin tüccar rozeti (MerchantBadge) menü çubuğunun hemen altındadır; bildirimler onun da altında başlar.
toastHolder.Position = UDim2.new(0.5, 0, 0, MerchantBadge.TOP + MerchantBadge.HEIGHT + 8)
toastHolder.Size = UDim2.new(1, -240, 0, 0)
PurchaseController.Completed:Connect(function(success: boolean, message: string?)
	-- Adalar penceresi açıkken bildirimi pencerenin kendi bildirim alanı gösterir (üstte, pencerenin önünde)
	if message and not IslandManager.isOpen() then
		showToast(message, if success then "success" else "error")
	end
end)

local seasonBar = SeasonBar.create(statsHud.frame)

-- Altın hayvan belirdiğinde bir kez haber ver (hayvan çiftlikte parlar); tüccar için kalıcı rozet var
local merchantBadge = MerchantBadge.create(hudRoot, function()
	showWindow(shopWindow)
end, showToast)
local lastGoldenCycle = -1
local function goldenNotice(state: PlayerSave?)
	if not state then
		return
	end
	local golden = Golden.current(state, localPlayer.UserId, Workspace:GetServerTimeNow())
	if golden and golden.cycle ~= lastGoldenCycle then
		lastGoldenCycle = golden.cycle
		Sfx.play("golden_spawn")
		showToast("Bir hayvanın altın gibi parlıyor! Yakala ve ödülünü al.", "info")
	end
end
task.spawn(function()
	while true do
		seasonBar.update()
		local current = ClientState.get()
		goldenNotice(current)
		merchantBadge.update(current)
		menu.updateProductionBadge(ClientState.get())
		-- Geri sayımlar ve zamanla açılan ödüller için; kapalı pencerede yalnızca rozet
		updateRewards(ClientState.get())
		updateBoard(ClientState.get())
		if current then
			progressionPanel.update(current)
			rebirthPanel.update(current)
		end
		task.wait(1)
	end
end)
---------------------------------------------------------------------------
-- Durum güncelleme
---------------------------------------------------------------------------

local shopDirty, roadmapDirty, upgradesDirty = true, true, true
local lastCash: number? = nil
local lastGoods = ""

-- Ahır deposundaki ürün miktarları: açılışların ürün gereksinimi satırları (Yükseltmeler, Yol Haritası, rozetler) bunlarla değişir
local function goodsSignature(state: PlayerSave): string
	local amounts: { number } = {}
	for _, goodsId in Config.GOODS_ORDER do
		table.insert(amounts, FarmMath.getGoodsAmount(state, goodsId))
	end
	return table.concat(amounts, ",")
end

local function onState(state: PlayerSave, structural: boolean)
	-- Asa geçersiz kılması yalnızca bu oyuncunun ekranını ve gelirini etkiler (Environment kendi katmanını uygular)
	Environment.setClientOverride(state.envOverride)
	screenGui.Enabled = true
	local income = FarmMath.computeIncomePerSecond(state)
	statsHud.update(state, income)
	goal.updateIsland(state, income)
	goal.updateGoal(state, income)
	menu.updateVisibility(state)
	progressionPanel.update(state)
	rebirthPanel.update(state)
	celebrate(state)
	updateRewards(state) -- pencere kapalıyken yalnızca rozet sayısı
	updateBoard(state) -- yalnızca açıkken
	if itemShop.window.isOpen() then
		itemShop.update(state)
	end
	if inventoryPanel.window.isOpen() then
		inventoryPanel.update(state)
	end
	local signature = goodsSignature(state)
	local goodsChanged = signature ~= lastGoods
	lastGoods = signature
	shopDirty = shopDirty or structural
	roadmapDirty = roadmapDirty or structural or goodsChanged
	upgradesDirty = upgradesDirty or structural or goodsChanged
	local cashChanged = lastCash ~= state.cash
	if structural or cashChanged or goodsChanged then
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
for _, window in { rewardsWindow, boardWindow, progressionPanel.window, rebirthPanel.window } do
	window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.isOpen() then
			redraw()
		end
	end)
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
		Onboarding.markRoadmapOpened() -- ilk adımlar: 4. adım biter
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
	-- Kısa ama geniş pencerelerde (ör. 1600x645) tam yerleşim kullanılır; yalnızca dar ya da çok kısa ekran kompakt olur.
	-- Ölçüt, kök ölçek uygulanmış etkin boyuttur (telefonda 0,85 ile daha çok yer kalır).
	local viewport = UiKit.viewport()
	compact = viewport.X < 900 or viewport.Y < 560
	statsHud.setCompact(compact)
	-- Kompakt: kasa, depo çubuğu ve tek satırlık mevsim/hava.
	seasonBar.setCompact(compact)
	redraw()
end

local cameraConnection: RBXScriptConnection? = nil
local function watchCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
	end
	local camera = Workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resizeHud)
	end
	resizeHud()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()
ClientState.onChanged(onState)
ClientState.onChanged(IslandTabs.refreshSafe)
IslandContext.Changed:Connect(IslandTabs.refreshSafe)
Remotes.get("Notify").OnClientEvent:Connect(function(message: string, kind: string?, amount: number?)
	if typeof(message) == "string" then
		showToast(message, kind)
		if kind == "info" then
			Sfx.play("notify")
		elseif kind == "success" then
			-- Yerdeki kaide/tabela/prompt alımları PurchaseController'dan geçmez; başarı sesi buradan gelir (Sfx aralığı çifti engeller)
			Sfx.play("success")
		end
	end
	-- Para toplama ödülü: ses + kasa sayısı zıplaması (yüzen yazı ve parçacık CollectorGuide'da)
	if kind == "money" and typeof(amount) == "number" then
		Sfx.play("coin", 0.08)
		statsHud.bounceCash()
	elseif kind == "error" then
		Sfx.play("error")
	end
end)
