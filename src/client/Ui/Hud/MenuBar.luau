--!strict
-- Menü: üstte ortada yatay çubuk (Pazar, Yükseltmeler, Yol Haritası, Üretim, Adalar), sağ kenarda dikey sütun
-- (Envanter, Ödüller, Adama Dön, Ayarlar, Yönetici). Rozetler ve kademeli açılan karolar da burada.
-- Pencere açan tıklamalar (Pazar, Yol Haritası, Yükseltmeler, Ödüller, Envanter, Adama Dön) FarmHud'da bağlanır;
-- burada yalnızca kendi kendine yeten düğmeler çalışır.
-- Yeni menü girişi: `UiKit.menuButton` (üst çubuk ya da sağ sütun) + ne zaman görüneceği `updateVisibility` içinde.

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

local Color = UiKit.Color
local localPlayer = Players.LocalPlayer

local MenuBar = {}

export type Hud = {
	topBar: Frame,
	sideBar: Frame,
	productionButton: TextButton,
	shopButton: TextButton,
	roadmapButton: TextButton,
	upgradesButton: TextButton,
	islandsButton: TextButton,
	rewardsButton: TextButton,
	inventoryButton: TextButton,
	homeButton: TextButton,
	settingsButton: TextButton,
	adminButton: TextButton,
	setRewardsBadge: (count: number) -> (),
	updateBadges: (state: PlayerSave) -> (),
	updateProductionBadge: (state: PlayerSave?) -> (),
	updateVisibility: (state: PlayerSave) -> (),
}

function MenuBar.create(screenGui: ScreenGui): Hud
	-- Üst çubuk: oyun içi ana pencereler. Bildirimler (toast) bunun altında durur.
	local topBar = Instance.new("Frame")
	topBar.Name = "MenuTop"
	topBar.AnchorPoint = Vector2.new(0.5, 0)
	topBar.Position = UDim2.new(0.5, 0, 0, 14) -- rozetler (üst köşeden taşan sayılar) kesilmesin
	topBar.Size = UDim2.new()
	topBar.AutomaticSize = Enum.AutomaticSize.XY
	topBar.BackgroundTransparency = 1
	topBar.Parent = screenGui
	UiKit.list(topBar, 6, true)

	-- Sağ sütun: envanter, ödüller, adaya dönüş, ayarlar (sağ üstteki oyuncu listesine uzanmaz)
	local sideBar = Instance.new("Frame")
	sideBar.Name = "MenuSide"
	sideBar.AnchorPoint = Vector2.new(1, 0.5)
	sideBar.Position = UDim2.new(1, -8, 0.5, 0)
	sideBar.Size = UDim2.new()
	sideBar.AutomaticSize = Enum.AutomaticSize.XY
	sideBar.BackgroundTransparency = 1
	sideBar.Parent = screenGui
	UiKit.list(sideBar, 6)

	local hasKeyboard = UserInputService.KeyboardEnabled
	local productionButton = UiKit.menuButton(topBar, "🏭", "Üretim", Color.Green, if hasKeyboard then "R" else nil)
	productionButton.Activated:Connect(function()
		ProductionPanel.toggle(screenGui)
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.R then
			ProductionPanel.toggle(screenGui)
		end
	end)
	local shopButton = UiKit.menuButton(topBar, "🐄", "Pazar", Color.Green, if hasKeyboard then "P" else nil)
	local roadmapButton =
		UiKit.menuButton(topBar, "🗺️", "Yol Haritası", Color.Blue, if hasKeyboard then "Y" else nil)
	local upgradesButton =
		UiKit.menuButton(topBar, "🛠️", "Yükseltmeler", Color.Gold, if hasKeyboard then "U" else nil)
	local islandsButton = UiKit.menuButton(topBar, "🧭", "Adalar", Color.Blue, if hasKeyboard then "I" else nil)
	islandsButton.Activated:Connect(IslandManager.toggle)
	local inventoryButton =
		UiKit.menuButton(sideBar, "🎒", "Envanter", Color.Orange, if hasKeyboard then "B" else nil)
	local rewardsButton = UiKit.menuButton(sideBar, "🏆", "Ödüller", Color.Gold, nil)
	local homeButton = UiKit.menuButton(sideBar, "🏠", "Adama Dön", Color.Orange, nil)
	local settingsButton = UiKit.menuButton(sideBar, "⚙️", "Ayarlar", Color.TextMuted, nil)
	local adminButton = UiKit.menuButton(sideBar, "🔑", "Yönetici", Color.Gold, nil)

	-- Çubuk içi sıra
	for index, button in { shopButton, upgradesButton, roadmapButton, productionButton, islandsButton } do
		button.LayoutOrder = index
	end
	for index, button in { inventoryButton, rewardsButton, homeButton, settingsButton, adminButton } do
		button.LayoutOrder = index
	end
	local function updateAdminAccess()
		adminButton.Visible = localPlayer:GetAttribute("IsAdmin") == true
	end
	updateAdminAccess()
	localPlayer:GetAttributeChangedSignal("IsAdmin"):Connect(updateAdminAccess)
	adminButton.Activated:Connect(function()
		if localPlayer:GetAttribute("IsAdmin") == true then
			AdminPanel.toggle(screenGui)
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.F8 and localPlayer:GetAttribute("IsAdmin") == true then
			AdminPanel.toggle(screenGui)
		end
	end)
	settingsButton.Activated:Connect(function()
		SettingsMenu.toggle(screenGui)
	end)

	local setShopBadge = UiKit.badge(shopButton)
	local setRoadmapBadge = UiKit.badge(roadmapButton)
	local setUpgradesBadge = UiKit.badge(upgradesButton)
	local setProductionBadge = UiKit.badge(productionButton)
	local setRewardsBadge = UiKit.badge(rewardsButton)

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

	-- Menü kademeli açılır: yeni oyuncu yalnızca Pazar, Ödüller ve Ayarlar'ı görür; diğer karolar ihtiyaç doğdukça belirir.
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
		local ownsItems = (state.inventory ~= nil and next(state.inventory.items) ~= nil)
			or FarmMath.getGoodsWorth(state) > 0 -- ahır deposunda ürün birikince de görünür
		setMenuTile(upgradesButton, veteran or Onboarding.stepFor(state) >= 3)
		setMenuTile(roadmapButton, veteran or earned >= 300)
		setMenuTile(productionButton, ownsFactory)
		setMenuTile(islandsButton, veteran)
		setMenuTile(homeButton, true) -- "Adama Dön" her zaman görünür: oyuncular adasını bulmakta zorlanıyor
		setMenuTile(inventoryButton, ownsItems or earned >= 1000)
	end

	return {
		topBar = topBar,
		sideBar = sideBar,
		productionButton = productionButton,
		shopButton = shopButton,
		roadmapButton = roadmapButton,
		upgradesButton = upgradesButton,
		islandsButton = islandsButton,
		rewardsButton = rewardsButton,
		inventoryButton = inventoryButton,
		homeButton = homeButton,
		settingsButton = settingsButton,
		adminButton = adminButton,
		setRewardsBadge = setRewardsBadge,
		updateBadges = updateBadges,
		updateProductionBadge = updateProductionBadge,
		updateVisibility = updateMenuVisibility,
	}
end

return MenuBar
