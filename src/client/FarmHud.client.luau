--!strict
-- Oyuncu arayüzü: para/depo paneli, menü, Hayvan Pazarı, Yol Haritası, bildirimler.
-- Görünüm kuralları UiKit'te; buradaki hesaplar sadece GÖSTERİM içindir, kararı sunucu verir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent:WaitForChild("PurchaseController"))
local SettingsMenu = require(script.Parent:WaitForChild("SettingsMenu"))
local AdminPanel = require(script.Parent:WaitForChild("AdminPanel"))
local ProductionPanel = require(script.Parent:WaitForChild("ProductionPanel"))
local IslandContext = require(script.Parent:WaitForChild("IslandContext"))
local IslandManager = require(script.Parent:WaitForChild("IslandManager"))

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

---------------------------------------------------------------------------
-- Sol panel: para, gelir, ahır, depo, sıradaki hedef
---------------------------------------------------------------------------

local stats = UiKit.panel(screenGui)
stats.Name = "Stats"
stats.AnchorPoint = Vector2.new(0, 0.5)
stats.Position = UDim2.new(0, 12, 0.5, 0)
stats.Size = UDim2.fromOffset(260, 0)
stats.AutomaticSize = Enum.AutomaticSize.Y
UiKit.padding(stats, 14)
UiKit.list(stats, 10)
local farmContextLabel = UiKit.text(stats, IslandContext.name(), "Caption", Color.Gold)
farmContextLabel.LayoutOrder = -1
local dataHealth = UiKit.text(stats, "", "Caption", Color.Red)
dataHealth.LayoutOrder = 0
dataHealth.Visible = false

-- İkon kutusu + yanında alt alta yazılar (dönen çerçeveye yazılar eklenir)
local function statRow(order: number, icon: string, tint: Color3): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 40)
	row.LayoutOrder = order
	row.Parent = stats

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

local cashTexts = statRow(1, "💰", Color.Gold)
local cashLabel = UiKit.text(cashTexts, "$0", "Display", Color.Gold)
cashLabel.LayoutOrder = 1
local incomeLabel = UiKit.text(cashTexts, "+$0/sn", "Caption")
incomeLabel.LayoutOrder = 2

local barnTexts = statRow(2, "🏚️", Color.Red)
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
islandCard.LayoutOrder = 4
islandCard.Parent = stats
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
-- Sağ menü
---------------------------------------------------------------------------

local dock = Instance.new("Frame")
dock.Name = "Menu"
dock.AnchorPoint = Vector2.new(1, 0.5)
dock.Position = UDim2.new(1, -12, 0.5, 0)
dock.Size = UDim2.fromOffset(170, 0)
dock.AutomaticSize = Enum.AutomaticSize.Y
dock.BackgroundTransparency = 1
dock.Parent = screenGui
UiKit.list(dock, 8)

local hasKeyboard = UserInputService.KeyboardEnabled
local productionButton = UiKit.menuButton(dock, "🏭", "Üretim", Color.Green, if hasKeyboard then "R" else nil)
productionButton.LayoutOrder = 4
productionButton.Activated:Connect(function()
	ProductionPanel.open(screenGui)
end)
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if not processed and input.KeyCode == Enum.KeyCode.R then
		ProductionPanel.open(screenGui)
	end
end)
local shopButton = UiKit.menuButton(dock, "🐄", "Pazar", Color.Green, if hasKeyboard then "P" else nil)
shopButton.LayoutOrder = 1
local roadmapButton = UiKit.menuButton(dock, "🗺️", "Yol Haritası", Color.Blue, if hasKeyboard then "Y" else nil)
roadmapButton.LayoutOrder = 2
local upgradesButton = UiKit.menuButton(dock, "🛠️", "Yükseltmeler", Color.Gold, nil)
upgradesButton.LayoutOrder = 3
local islandsButton = UiKit.menuButton(dock, "🧭", "Adalar", Color.Blue, if hasKeyboard then "I" else nil)
islandsButton.LayoutOrder = 5
islandsButton.Activated:Connect(IslandManager.open)
local homeButton = UiKit.menuButton(dock, "🏠", "Adama Dön", Color.Orange, nil)
homeButton.LayoutOrder = 6
local settingsButton = UiKit.menuButton(dock, "⚙️", "Ayarlar", Color.TextMuted, nil)
settingsButton.LayoutOrder = 4
local adminButton = UiKit.menuButton(dock, "🛠️", "Yönetici", Color.Gold, nil)
adminButton.LayoutOrder = 6
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

homeButton.Activated:Connect(function()
	Remotes.get("RequestGoHome"):FireServer()
end)

---------------------------------------------------------------------------
-- Pencereler
---------------------------------------------------------------------------

local WINDOW_POSITION = UDim2.new(1, -194, 0.5, 0)

local shopWindow = UiKit.window(screenGui, {
	title = "Hayvan Pazarı",
	icon = "🐄",
	tint = Color.Green,
	width = 330,
	maxHeight = 430,
	anchor = Vector2.new(1, 0.5),
	position = WINDOW_POSITION,
})
local shopInfo = UiKit.text(shopWindow.list, "Hayvanlar yavru doğar, büyüdükçe daha çok kazandırır.", "Caption")
shopInfo.LayoutOrder = 0

local animalCards: { [string]: UiKit.Card } = {}
for index, animalId in Config.ANIMAL_ORDER do
	local card = UiKit.card(shopWindow.list, index, Config.ANIMALS[animalId].icon)
	animalCards[animalId] = card
	card.action.Activated:Connect(function()
		if card.action.Active then
			PurchaseController.submit("RequestBuyAnimal", animalId)
		end
	end)
end

local replacementCard = UiKit.card(shopWindow.list, #Config.ANIMAL_ORDER + 1, Config.ANIMALS.seabass.icon)
replacementCard.title.Text = "Hamsiyi levrekle değiştir"
replacementCard.action.Activated:Connect(function()
	local state = ClientState.get()
	local fish = state and FarmMath.findReplaceableFish(state)
	if fish and replacementCard.action.Active then
		PurchaseController.submit("RequestReplaceFish", fish.uid)
	end
end)

local roadmapWindow = UiKit.window(screenGui, {
	title = "Yol Haritası",
	icon = "🗺️",
	tint = Color.Blue,
	width = 330,
	maxHeight = 430,
	anchor = Vector2.new(1, 0.5),
	position = WINDOW_POSITION,
})
local roadmapInfo = UiKit.text(
	roadmapWindow.list,
	"Sırayı sen seç: ucuz olanı hemen al ya da biriktirip büyüğünü al. Kilitli olanlar için önce gerekeni aç.",
	"Caption"
)
roadmapInfo.LayoutOrder = 0

local upgradeCards: { [string]: UiKit.Card } = {}
local stageMeta: { [number]: TextLabel } = {}
local stageGroups: { [number]: { GuiObject } } = {}
do
	local order = 1
	for stageIndex, stage in Config.ROADMAP_STAGES do
		local stageName = stage.name
		local header, meta = UiKit.sectionHeader(roadmapWindow.list, `Aşama {stageIndex} · {stageName}`, order)
		stageMeta[stageIndex] = meta
		stageGroups[stageIndex] = { header.Parent :: GuiObject }
		order += 1

		-- Aşama bir uzman adaya aitse adanın özelliği, değilse aşamanın açıklaması başlığın altında yazsın
		local islandConfig = if stage.island then Config.FARM_ISLANDS[stage.island] else nil
		local caption = if islandConfig and islandConfig.upgradeId
			then `Ada özelliği: {islandConfig.trait}`
			else stage.description
		if caption then
			local captionLabel = UiKit.text(roadmapWindow.list, caption, "Caption")
			captionLabel.LayoutOrder = order
			table.insert(stageGroups[stageIndex], captionLabel)
			order += 1
		end

		if stageIndex == 1 then
			local free = UiKit.card(roadmapWindow.list, order, "🎁")
			free.title.Text = "Başlangıç hediyesi"
			free.detail.Text =
				`{Config.BARN_LEVELS[1].displayName}, {Config.ZONES.starter.displayName}, {Config.STARTING_COW_COUNT} inek`
			free.action.Text = "Alındı"
			UiKit.setVariant(free.action, "owned")
			table.insert(stageGroups[stageIndex], free.frame)
			order += 1
		end

		for _, upgrade in Config.UPGRADES do
			if upgrade.stage ~= stageIndex then
				continue
			end
			local card = UiKit.card(roadmapWindow.list, order, upgrade.icon)
			card.title.Text = upgrade.displayName
			order += 1
			upgradeCards[upgrade.id] = card
			card.action.Activated:Connect(function()
				if card.action.Active then
					PurchaseController.submit("RequestBuyUpgrade", upgrade.id)
				end
			end)
		end
	end
end

local upgradesWindow = UiKit.window(screenGui, {
	title = "Yükseltmeler",
	icon = "🛠️",
	tint = Color.Gold,
	width = 330,
	maxHeight = 430,
	anchor = Vector2.new(1, 0.5),
	position = WINDOW_POSITION,
})
local upgradesInfo = UiKit.text(
	upgradesWindow.list,
	"Açık yükseltmeler üstte; alınanlar bu listeden çıkar. Kısayol: U.",
	"Caption"
)
upgradesInfo.LayoutOrder = 0
local upgradesEmpty = UiKit.text(
	upgradesWindow.list,
	"Tüm yükseltmeleri aldın. Çiftliğini hayvanlarla büyütmeye devam edebilirsin.",
	"Body"
)
upgradesEmpty.LayoutOrder = 1
upgradesEmpty.Visible = false
local nextIslandButton = UiKit.button(upgradesWindow.list, "Adalar'da sıradaki yatırımı seç", "primary")
nextIslandButton.Size = UDim2.new(1, 0, 0, 42)
nextIslandButton.LayoutOrder = 2
nextIslandButton.Visible = false
nextIslandButton.Activated:Connect(IslandManager.open)
local directUpgradeCards: { [string]: UiKit.Card } = {}
for index, upgrade in Config.UPGRADES do
	local card = UiKit.card(upgradesWindow.list, index + 1, upgrade.icon)
	card.title.Text = upgrade.displayName
	directUpgradeCards[upgrade.id] = card
	card.action.Activated:Connect(function()
		if card.action.Active then
			PurchaseController.submit("RequestBuyUpgrade", upgrade.id)
		end
	end)
end

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
	if message then
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

---------------------------------------------------------------------------
-- Sağ menüde küçük mevsim/hava kartı; bildirim alanından ayrı.
---------------------------------------------------------------------------

local seasonBar = UiKit.panel(dock)
seasonBar.Name = "SeasonBar"
seasonBar.LayoutOrder = 10
seasonBar.Size = UDim2.new(1, 0, 0, 0)
seasonBar.AutomaticSize = Enum.AutomaticSize.Y
UiKit.padding(seasonBar, 8)
UiKit.list(seasonBar, 4)

local seasonHeader = Instance.new("Frame")
seasonHeader.BackgroundTransparency = 1
seasonHeader.Size = UDim2.new(1, 0, 0, 20)
seasonHeader.LayoutOrder = 1
seasonHeader.Parent = seasonBar
local seasonChip = UiKit.iconChip(seasonHeader, "", 20, Color.Green)
local seasonTitle = UiKit.text(seasonHeader, "", "Caption")
seasonTitle.AutomaticSize = Enum.AutomaticSize.None
seasonTitle.Position = UDim2.fromOffset(26, 0)
seasonTitle.Size = UDim2.new(1, -26, 1, 0)
seasonTitle.TextWrapped = false
seasonTitle.TextTruncate = Enum.TextTruncate.AtEnd
local seasonClock = UiKit.text(seasonBar, "", "Caption", Color.Gold)
seasonClock.LayoutOrder = 2
seasonClock.TextWrapped = false

local seasonProgress, setSeasonProgress = UiKit.progressBar(seasonBar, 6)
seasonProgress.Name = "SeasonProgress"
seasonProgress.LayoutOrder = 3

local seasonFooter = Instance.new("Frame")
seasonFooter.BackgroundTransparency = 1
seasonFooter.Size = UDim2.new(1, 0, 0, 20)
seasonFooter.LayoutOrder = 4
seasonFooter.Parent = seasonBar
local weatherChip = UiKit.iconChip(seasonFooter, "", 20, Color.Blue)
local weatherTitle = UiKit.text(seasonFooter, "", "Caption", Color.Text)
weatherTitle.AutomaticSize = Enum.AutomaticSize.None
weatherTitle.Position = UDim2.fromOffset(26, 0)
weatherTitle.Size = UDim2.new(1, -26, 1, 0)
weatherTitle.TextWrapped = false
weatherTitle.TextTruncate = Enum.TextTruncate.AtEnd
local nextSeasonLabel = UiKit.text(seasonBar, "", "Caption")
nextSeasonLabel.LayoutOrder = 5

local seasonTints: { [string]: Color3 } = {
	spring = Color.Green,
	summer = Color.Gold,
	autumn = Color.Orange,
	winter = Color.Blue,
}

local function formatClock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d", s // 60, s % 60)
end

local function updateSeasonBar()
	local season = Environment.getSeason()
	local weather = Environment.getWeather()
	local now = Workspace:GetServerTimeNow()
	local progress = Environment.getSeasonProgress(now)
	local left = math.max(0, Config.SEASON_SECONDS * (1 - progress))
	local tint = seasonTints[season.id] or Color.Green
	seasonChip.Text = season.icon
	seasonChip.BackgroundColor3 = tint
	seasonTitle.Text = season.displayName
	seasonClock.Text = `{formatClock(left)} kaldı`
	setSeasonProgress(progress, tint)
	nextSeasonLabel.Text = if ReplicatedStorage:GetAttribute("AdminSeasonOverride")
		then "Mevsim sabit"
		else `Sonra: {Environment.getNextSeason().displayName}`
	weatherChip.Text = weather.icon
	weatherTitle.Text = weather.displayName
end

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

task.spawn(function()
	while true do
		updateSeasonBar()
		updateProductionBadge(ClientState.get())
		task.wait(1)
	end
end)

---------------------------------------------------------------------------
-- Durum güncelleme
---------------------------------------------------------------------------

local function secondsToText(seconds: number): string
	return if seconds < 60 then `{math.ceil(seconds)} sn` else `{math.ceil(seconds / 60)} dk`
end

local function purchaseHint(state: PlayerSave, price: number, income: number): string
	if state.cash >= price then
		return "Alabilirsin!"
	end
	if not FarmMath.hasAutoCollect(state) then
		if state.cash + math.floor(state.stored) >= price then
			return "Depoyu topla; alabilecek kadar paran var."
		end
		if state.stored >= FarmMath.getStorageCap(state) then
			return "Depo dolu. Devam etmek için parayı topla."
		end
	end
	if income <= 0 then
		return "Önce üretim yapan hayvan al."
	end
	local seconds = math.max(0, price - state.cash - state.stored) / income
	return if FarmMath.hasAutoCollect(state)
		then `Yaklaşık {secondsToText(seconds)} sonra`
		else `Düzenli toplarsan yaklaşık {secondsToText(seconds)} sonra`
end

local buttonStates: { [TextButton]: string } = {}
local function setPurchaseButton(button: TextButton, text: string, variant: UiKit.Variant)
	local pending = PurchaseController.isPending() or localPlayer:GetAttribute("DataStatus") ~= "Active"
	local actualVariant: UiKit.Variant = if pending then "disabled" else variant
	local actualText = if pending and variant ~= "owned" then "Bekleniyor" else text
	local signature = actualVariant .. actualText
	if buttonStates[button] == signature then
		return
	end
	buttonStates[button] = signature
	button.Text = actualText
	UiKit.setVariant(button, actualVariant)
end

local function updateShop(state: PlayerSave, content: boolean)
	if content then
		shopInfo.Text =
			`Seçili: {IslandContext.name()}\nHayvanlar yavru doğar, büyüdükçe daha çok kazandırır. Ada değiştirmek için Adalar.`
	end
	for _, animalId in Config.ANIMAL_ORDER do
		local card = animalCards[animalId]
		local relevant = IslandContext.hasAnimal(animalId)
		card.frame.Visible = relevant
		if not relevant then
			continue
		end
		local animalConfig = Config.ANIMALS[animalId]
		local zoneId, reason, block = FarmMath.findZoneForAnimal(state, animalId)
		local price = FarmMath.getAnimalPrice(state, animalId)
		if content then
			card.title.Text = `{animalConfig.displayName}  {UiKit.colorText(
				`x{FarmMath.countAnimals(state, animalId)}`,
				Color.TextMuted
			)}`
			if zoneId then
				local income = FarmMath.getAnimalIncome(state, animalId)
				card.detail.Text = `{animalConfig.product} · Yetişkin +${FarmMath.formatRate(income)}/sn`
			else
				card.detail.Text = reason or ""
			end
		end
		if not zoneId then
			setPurchaseButton(card.action, if block == "full" then "Dolu" else "Kilitli", "disabled")
		else
			setPurchaseButton(
				card.action,
				FarmMath.formatMoney(price),
				if state.cash >= price then "primary" else "warning"
			)
		end
	end
	local fish = if IslandContext.get() == "home" then FarmMath.findReplaceableFish(state) else nil
	replacementCard.frame.Visible = fish ~= nil
	if fish then
		local price = FarmMath.getFishReplacementPrice(state)
		replacementCard.detail.Text =
			"Bir hamsi çıkar, yerine yavru levrek gelir. Hamsinin temel fiyatının yarısı bedelden düşülür."
		setPurchaseButton(
			replacementCard.action,
			`Değiştir · {FarmMath.formatMoney(price)}`,
			if state.cash >= price then "primary" else "warning"
		)
	end
end

local function updateRoadmap(state: PlayerSave, content: boolean)
	local selectedIsland = IslandContext.get()
	if content then
		roadmapInfo.Text =
			`Seçili: {IslandContext.name()}\nBu adanın gelişim adımları. Ada değiştirmek ve yeni ada açmak için Adalar.`
	end
	local ownedPerStage: { [number]: number } = {}
	local totalPerStage: { [number]: number } = {}
	for _, upgrade in Config.UPGRADES do
		local card = upgradeCards[upgrade.id]
		local relevant = upgrade.kind ~= "island" and IslandContext.upgradeIsland(upgrade) == selectedIsland
		card.frame.Visible = relevant
		if not relevant then
			continue
		end
		local status, missing = FarmMath.getUpgradeStatus(state, upgrade.id)
		if content then
			totalPerStage[upgrade.stage] = (totalPerStage[upgrade.stage] or 0) + 1
			if status == "owned" then
				ownedPerStage[upgrade.stage] = (ownedPerStage[upgrade.stage] or 0) + 1
			end
			card.detail.Text = if status == "locked"
				then `Önce: {table.concat(missing, ", ")}`
				else upgrade.description
			card.frame.BackgroundTransparency = if status == "owned" then 0.5 else 0
		end
		local variant: UiKit.Variant = if status == "owned"
			then "owned"
			elseif status == "locked" then "disabled"
			elseif state.cash >= upgrade.cost then "primary"
			else "warning"
		setPurchaseButton(
			card.action,
			if status == "owned" then "Alındı" else FarmMath.formatMoney(upgrade.cost),
			variant
		)
	end
	if content then
		for stageIndex, stage in Config.ROADMAP_STAGES do
			stageMeta[stageIndex].Text = `{ownedPerStage[stageIndex] or 0}/{totalPerStage[stageIndex] or 0}`
			for _, item in stageGroups[stageIndex] do
				item.Visible = (stage.island or "home") == selectedIsland
			end
		end
	end
end

local function updateUpgrades(state: PlayerSave, content: boolean)
	local remaining = 0
	local selectedIsland = IslandContext.get()
	if content then
		upgradesInfo.Text =
			`Seçili: {IslandContext.name()}\nAçık yükseltmeler üstte; alınanlar listeden çıkar. Ada değiştirmek için Adalar.`
		upgradesEmpty.Text =
			`{IslandContext.name()} yükseltmeleri tamamlandı. Sıradaki yatırımını seçmek için Adalar'ı aç.`
	end
	for index, upgrade in Config.UPGRADES do
		local card = directUpgradeCards[upgrade.id]
		local relevant = upgrade.kind ~= "island" and IslandContext.upgradeIsland(upgrade) == selectedIsland
		if not relevant then
			card.frame.Visible = false
			continue
		end
		local status, missing = FarmMath.getUpgradeStatus(state, upgrade.id)
		if content then
			card.frame.Visible = status ~= "owned"
			card.frame.LayoutOrder = index + 1 + (if status == "locked" then #Config.UPGRADES else 0)
			card.detail.Text = if status == "locked"
				then `Önce: {table.concat(missing, ", ")}`
				else upgrade.description
		end
		if status ~= "owned" then
			remaining += 1
			setPurchaseButton(
				card.action,
				if status == "locked" then "Kilitli" else FarmMath.formatMoney(upgrade.cost),
				if status == "locked" then "disabled" elseif state.cash >= upgrade.cost then "primary" else "warning"
			)
		end
	end
	if content then
		upgradesEmpty.Visible = remaining == 0
		nextIslandButton.Visible = remaining == 0
		upgradesInfo.Visible = true
	end
end

local function updateBadges(state: PlayerSave)
	updateProductionBadge(state)
	local animals, upgrades = 0, 0
	for _, animalId in Config.ANIMAL_ORDER do
		if
			IslandContext.hasAnimal(animalId)
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
			and state.cash >= upgrade.cost
		then
			upgrades += 1
		end
	end
	setShopBadge(animals)
	setRoadmapBadge(upgrades)
	setUpgradesBadge(upgrades)
end

local function updateGoal(state: PlayerSave, income: number)
	orderButton.Visible = false
	goalTitle.Text = "SIRADAKİ HEDEF"
	-- İlk boş kapasiteyi kullanmayı öğret; iki inek varken daha fazla yer önermeyiz.
	if #state.animals <= Config.STARTING_COW_COUNT and next(state.purchased) == nil then
		goalLabel.Text = "İlk hedef: yeni bir inek"
		goalDetail.Text = purchaseHint(state, FarmMath.getAnimalPrice(state, "cow"), income)
		return
	end
	local best: Config.UpgradeConfig? = nil
	for _, upgrade in Config.UPGRADES do
		local status = FarmMath.getUpgradeStatus(state, upgrade.id)
		local useful = upgrade.id ~= "zone_pasture"
			or FarmMath.countInZone(state, "starter") >= Config.ZONES.starter.capacity
		if useful and status == "available" and (not best or upgrade.cost < best.cost) then
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
		goalLabel.Text = `{best.displayName} · {FarmMath.formatMoney(best.cost)}`
		goalDetail.Text = purchaseHint(state, best.cost, income)
		return
	end
	goalTitle.Text = "ÇİFTLİK USTALIĞI VE SİPARİŞ"
	local capacity = 0
	for _, zone in Config.ZONES do
		capacity += zone.capacity
	end
	local adults = 0
	for _, animal in state.animals do
		if animal.stage == "adult" then
			adults += 1
		end
	end
	goalLabel.Text =
		`Ustalık: {adults}/{capacity} yetişkin · {FarmMath.countAnimals(state, "seabass")}/{Config.ZONES.fishpen.capacity} levrek`
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
	islandCard.Visible = not compact and island ~= nil
	if not island or not upgrade then
		return
	end
	islandChip.Text = island.icon
	islandName.Text = `{island.displayName} · {FarmMath.formatMoney(upgrade.cost)}`
	islandTrait.Text = island.trait
	local status, missing = FarmMath.getUpgradeStatus(state, upgrade.id)
	islandEta.Text = if status == "locked"
		then `Önce: {table.concat(missing, ", ")}`
		else purchaseHint(state, upgrade.cost, income)
end

local shopDirty, roadmapDirty, upgradesDirty = true, true, true
local lastCash: number? = nil
local function onState(state: PlayerSave, structural: boolean)
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
	barnDetail.Text = `Seviye {state.barnLevel} · Ada {ownedIslands}/{totalIslands}`
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
		elseif auto then "Otomatik toplama çevrimiçinde çalışır. Çevrimdışında depo sınırı geçerlidir."
		elseif state.stored >= cap then "Depo dolu, üretim durdu! Yeşil platforma bas."
		else "Parayı almak için yeşil platforma bas. Çevrimdışı kazanç depoyla sınırlıdır."
	updateIslandGoal(state, income)
	updateGoal(state, income)
	shopDirty = shopDirty or structural
	roadmapDirty = roadmapDirty or structural
	upgradesDirty = upgradesDirty or structural
	local cashChanged = lastCash ~= state.cash
	if structural or cashChanged then
		updateBadges(state)
	end
	if shopWindow.isOpen() and (shopDirty or cashChanged) then
		updateShop(state, shopDirty)
		shopDirty = false
	end
	if roadmapWindow.isOpen() and (roadmapDirty or cashChanged) then
		updateRoadmap(state, roadmapDirty)
		roadmapDirty = false
	end
	if upgradesWindow.isOpen() and (upgradesDirty or cashChanged) then
		updateUpgrades(state, upgradesDirty)
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
	compact = camera.ViewportSize.X < 900 or camera.ViewportSize.Y < 650
	stats.AnchorPoint = if compact then Vector2.zero else Vector2.new(0, 0.5)
	stats.Position = if compact then UDim2.fromOffset(8, 8) else UDim2.new(0, 12, 0.5, 0)
	stats.Size = if compact then UDim2.new(1, -128, 0, 0) else UDim2.fromOffset(260, 0)
	local barnRow = barnTexts.Parent
	if barnRow and barnRow:IsA("GuiObject") then
		barnRow.Visible = not compact
	end
	islandCard.Visible = not compact
	goalCard.Visible = not compact
	-- Mobilde hedefler ayrı pencereye taşınır; HUD oyunu kaplamaz.
	nextSeasonLabel.Visible = not compact
	hintLabel.Visible = not compact or localPlayer:GetAttribute("DataPersistent") == false
	dock.AnchorPoint = if compact then Vector2.new(1, 0) else Vector2.new(1, 0.5)
	dock.Position = if compact then UDim2.new(1, -8, 0, 8) else UDim2.new(1, -12, 0.5, 0)
	dock.Size = UDim2.fromOffset(if compact then 104 else 170, 0)
	layoutToasts()
	for _, button in
		{
			shopButton,
			roadmapButton,
			upgradesButton,
			productionButton,
			islandsButton,
			homeButton,
			settingsButton,
			adminButton,
		}
	do
		local icon = button:FindFirstChild("Icon", true)
		if icon and icon:IsA("GuiObject") then
			icon.Visible = not compact
		end
		local shortcut = button:FindFirstChild("Shortcut", true)
		if shortcut and shortcut:IsA("GuiObject") then
			shortcut.Visible = not compact
		end
		local row = button:FindFirstChildWhichIsA("Frame")
		if row then
			for _, child in row:GetChildren() do
				if child:IsA("TextLabel") and child.Name ~= "Icon" and child.Name ~= "Shortcut" then
					if button == upgradesButton then
						child.TextSize = if compact then UiKit.TextSize.Caption else UiKit.TextSize.Heading
					end
					child.Size = UDim2.new(
						1,
						if compact
							then 0
							elseif
								hasKeyboard
								and button ~= upgradesButton
								and button ~= homeButton
								and button ~= settingsButton
								and button ~= adminButton
							then -66
							else -40,
						1,
						0
					)
				end
			end
		end
	end
	redraw()
end

local goalsWindow = UiKit.window(screenGui, {
	title = "Çiftlik hedefleri",
	icon = "🏆",
	tint = Color.Gold,
	width = 380,
	maxHeight = 480,
	anchor = Vector2.new(0.5, 0.5),
	position = UDim2.fromScale(0.5, 0.5),
})
local goalsButton = UiKit.menuButton(dock, "🏆", "Çiftliğim", Color.Gold, nil)
goalsButton.LayoutOrder = 6
local goalMenuRow = goalsButton:FindFirstChildWhichIsA("Frame")
if goalMenuRow then
	for _, child in goalMenuRow:GetChildren() do
		if child:IsA("TextLabel") then
			if child.Name == "Icon" then
				child.Visible = false
			else
				child.Size = UDim2.fromScale(1, 1)
			end
		end
	end
end
local function placeGoals()
	if not compact then
		goalsWindow.close()
	end
	goalCard.Parent = if compact then goalsWindow.list else stats
	goalCard.Visible = true
	goalsButton.Visible = compact
	roadmapButton.Parent = if compact then goalsWindow.list else dock
	roadmapButton.LayoutOrder = if compact then 9 else 2
	productionButton.Parent = if compact then goalsWindow.list else dock
	productionButton.LayoutOrder = if compact then 8 else 4
	islandsButton.Parent = if compact then goalsWindow.list else dock
	islandsButton.LayoutOrder = if compact then 7 else 5
	homeButton.Parent = if compact then goalsWindow.list else dock
	settingsButton.Parent = if compact then goalsWindow.list else dock
	adminButton.Parent = if compact then goalsWindow.list else dock
	homeButton.LayoutOrder = if compact then 10 else 6
	settingsButton.LayoutOrder = if compact then 11 else 7
	adminButton.LayoutOrder = if compact then 12 else 8
end
goalsButton.Activated:Connect(function()
	goalsWindow.open()
end)
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
Remotes.get("Notify").OnClientEvent:Connect(function(message: string, kind: string?)
	if typeof(message) == "string" then
		showToast(message, kind)
	end
end)
