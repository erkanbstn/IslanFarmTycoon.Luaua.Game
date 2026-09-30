--!strict
-- Alt ortadaki menü çubuğu (dar ekranda sağ kenarda dikey sütun; diğer karolar Çiftliğim penceresinde),
-- rozetler ve kademeli açılan karolar. Pencere açan tıklamalar (Pazar, Yol Haritası, Yükseltmeler, Çiftliğim,
-- Envanter, Adama Dön) FarmHud'da bağlanır; burada yalnızca kendi kendine yeten düğmeler çalışır.
-- Yeni menü girişi: `UiKit.menuButton` + `menuEntries` (compactDock = dar ekranda menüde kalsın mı) +
-- ne zaman görüneceği `updateVisibility` içinde.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local IslandContext = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("IslandContext"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local SettingsMenu = require(script.Parent.Parent:WaitForChild("SettingsMenu"))
local AdminPanel = require(script.Parent.Parent:WaitForChild("AdminPanel"))
local ProductionPanel = require(script.Parent.Parent:WaitForChild("ProductionPanel"))
local IslandManager = require(script.Parent.Parent:WaitForChild("IslandManager"))
local Onboarding = require(script.Parent:WaitForChild("Onboarding"))

type PlayerSave = GameTypes.PlayerSave
type MenuEntry = { button: TextButton, compactDock: boolean }

local Color = UiKit.Color
local localPlayer = Players.LocalPlayer

local MenuBar = {}

export type Hud = {
	dock: Frame,
	productionButton: TextButton,
	shopButton: TextButton,
	roadmapButton: TextButton,
	upgradesButton: TextButton,
	islandsButton: TextButton,
	goalsButton: TextButton,
	inventoryButton: TextButton,
	homeButton: TextButton,
	settingsButton: TextButton,
	adminButton: TextButton,
	setGoalsBadge: (count: number) -> (),
	updateBadges: (state: PlayerSave) -> (),
	updateProductionBadge: (state: PlayerSave?) -> (),
	updateVisibility: (state: PlayerSave) -> (),
	setCompact: (compact: boolean) -> (), -- çubuğun yönü ve yeri
	place: (compact: boolean) -> (), -- karoların çubuk / Çiftliğim arasında dağılımı
}

function MenuBar.create(screenGui: ScreenGui, goalsList: Instance): Hud
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
	moreActions.Parent = goalsList
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
	local roadmapButton =
		UiKit.menuButton(dock, "🗺️", "Yol Haritası", Color.Blue, if hasKeyboard then "Y" else nil)
	local upgradesButton =
		UiKit.menuButton(dock, "🛠️", "Yükseltmeler", Color.Gold, if hasKeyboard then "U" else nil)
	local islandsButton = UiKit.menuButton(dock, "🧭", "Adalar", Color.Blue, if hasKeyboard then "I" else nil)
	islandsButton.Activated:Connect(IslandManager.open)
	local goalsButton = UiKit.menuButton(dock, "🏆", "Çiftliğim", Color.Gold, nil)
	local inventoryButton = UiKit.menuButton(dock, "🎒", "Envanter", Color.Orange, if hasKeyboard then "B" else nil)
	local homeButton = UiKit.menuButton(dock, "🏠", "Adama Dön", Color.Orange, nil)
	local settingsButton = UiKit.menuButton(dock, "⚙️", "Ayarlar", Color.TextMuted, nil)
	local adminButton = UiKit.menuButton(dock, "🔑", "Yönetici", Color.Gold, nil)

	-- Sıra ve yer: dar ekranda yalnızca "compactDock" karoları menüde kalır, diğerleri Çiftliğim'e taşınır.
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
		-- Açık adadaki alınabilir geliştirmeler de rozete sayılır (yoksa oyuncu bunları fark etmez)
		for targetId, target in Config.BUILD_TARGETS do
			if target.island == IslandContext.get() then
				local status, _, cost = FarmMath.getExpansionStatus(state, targetId)
				if status == "available" and state.cash >= cost then
					upgrades += 1
				end
			end
		end
		-- Tek önerilen adım parlar: önce yükseltme (kalıcı ilerleme), yoksa hayvan. Yol haritası
		-- yükseltmelerle aynı listeyi gösterdiği için ayrıca rozet almaz.
		setUpgradesBadge(upgrades)
		setShopBadge(if upgrades > 0 then 0 else animals)
		setRoadmapBadge(0)
	end

	-- Menü kademeli açılır: yeni oyuncu yalnızca Pazar, Çiftliğim ve Ayarlar'ı görür; diğer karolar ihtiyaç doğdukça belirir.
	-- (Kısayollar ve pencereler yine çalışır; yalnızca düğme gizlenir.)
	local menuPulses: { [GuiObject]: (boolean) -> () } = {}
	local menuWasVisible: { [GuiObject]: boolean } = {}
	local function setMenuTile(button: GuiObject, visible: boolean)
		local was = menuWasVisible[button]
		button.Visible = visible
		menuWasVisible[button] = visible
		-- Yeni belirdiyse (oturumun ilk durumu hariç) birkaç saniye vurgulanır
		if visible and was == false then
			local pulse = menuPulses[button]
			if not pulse then
				pulse = UiKit.pulse(button)
				menuPulses[button] = pulse
			end
			pulse(true)
			task.delay(8, function()
				pulse(false)
			end)
		end
	end

	local function updateMenuVisibility(state: PlayerSave)
		local earned = state.lifetimeEarned or 0
		local veteran = Onboarding.stepFor(state) == 0
		local ownsFactory = next(state.production or {}) ~= nil
		for _, recipe in Config.PRODUCTION_RECIPES do
			if state.purchased[recipe.upgradeId] then
				ownsFactory = true
			end
		end
		local ownsItems = state.inventory ~= nil and next(state.inventory.items) ~= nil
		setMenuTile(upgradesButton, veteran or Onboarding.stepFor(state) >= 3)
		setMenuTile(roadmapButton, veteran or earned >= 300)
		setMenuTile(productionButton, ownsFactory)
		setMenuTile(islandsButton, veteran)
		setMenuTile(homeButton, veteran)
		setMenuTile(inventoryButton, ownsItems or earned >= 1000)
	end

	local function setCompact(compact: boolean)
		dockLayout.FillDirection = if compact then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
		dock.AnchorPoint = if compact then Vector2.new(1, 0.5) else Vector2.new(0.5, 1)
		dock.Position = if compact then UDim2.new(1, -8, 0.5, 0) else UDim2.new(0.5, 0, 1, -10)
	end

	local function place(compact: boolean)
		moreActions.Visible = compact
		for _, entry in menuEntries do
			entry.button.Parent = if compact and not entry.compactDock then moreActions else dock
		end
	end

	return {
		dock = dock,
		productionButton = productionButton,
		shopButton = shopButton,
		roadmapButton = roadmapButton,
		upgradesButton = upgradesButton,
		islandsButton = islandsButton,
		goalsButton = goalsButton,
		inventoryButton = inventoryButton,
		homeButton = homeButton,
		settingsButton = settingsButton,
		adminButton = adminButton,
		setGoalsBadge = setGoalsBadge,
		updateBadges = updateBadges,
		updateProductionBadge = updateProductionBadge,
		updateVisibility = updateMenuVisibility,
		setCompact = setCompact,
		place = place,
	}
end

return MenuBar
