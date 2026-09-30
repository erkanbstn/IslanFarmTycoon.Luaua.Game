--!strict
-- Envanter: slotlara takılı eşyalar, sahip olunan eşyalar (tak/çıkar) ve takılı asanın gücü (mevsim/hava değiştir).
-- Kararlar sunucudadır; burada yalnızca gösterim ve istek vardır (Inventory saf modülü kalan hakkı aynı hesapla verir).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Inventory = require(Shared:WaitForChild("Modules"):WaitForChild("Inventory"))
local ClientState = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientState"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))
local HudCommon = require(script.Parent:WaitForChild("HudCommon"))
local ItemText = require(script.Parent:WaitForChild("ItemText"))

type PlayerSave = GameTypes.PlayerSave

local Color = UiKit.Color
local setPurchaseButton = HudCommon.setPurchaseButton

local InventoryWindow = {}

export type Panel = {
	window: UiKit.Window,
	update: (state: PlayerSave) -> (),
}

local GOODS_ORDER = -30 -- Ahır deposu en üstte (negatif sıra: eşya bölümlerinden önce)
local SLOTS_ORDER = 10
local POWER_ORDER = 30
local OWNED_ORDER = 40
local WEATHER_ORDER = { "sunny", "cloudy", "rain", "storm", "snow" }
local POWER_BUTTONS = 5

function InventoryWindow.create(screenGui: ScreenGui): Panel
	local window = UiKit.window(screenGui, {
		title = "Envanter",
		icon = "🎒",
		tint = Color.Orange,
		width = 380,
		maxHeight = 480,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	UiKit.text(
		window.list,
		"Ürünler ahır deposunda birikir (ahırdaki sandıktan da açılır). Her slota bir eşya takılır; eşyaları meydandaki Usta Ömer'den alırsın.",
		"Caption"
	).LayoutOrder = GOODS_ORDER
		- 1

	-- Sekmeler: Ahır Deposu | Takılı | Eşyalarım (her sekme kendi sayfası; öğeler ızgara karolarıdır)
	local pages: { [string]: Frame } = {}
	local function newPage(id: string): Frame
		local page = Instance.new("Frame")
		page.Name = id
		page.BackgroundTransparency = 1
		page.Size = UDim2.new(1, 0, 0, 0)
		page.AutomaticSize = Enum.AutomaticSize.Y
		page.LayoutOrder = 0
		page.Visible = false
		page.Parent = window.list
		UiKit.list(page, 8)
		pages[id] = page
		return page
	end
	local goodsPage, equippedPage, ownedPage = newPage("goods"), newPage("equipped"), newPage("owned")
	local function showPage(id: string)
		for pageId, page in pages do
			page.Visible = pageId == id
		end
	end
	UiKit.tabs(window.list, GOODS_ORDER, {
		{ id = "goods", label = "Ahır Deposu" },
		{ id = "equipped", label = "Takılı" },
		{ id = "owned", label = "Eşyalarım" },
	}, showPage)
	showPage("goods")

	-- Ahır deposu: ürün merkezlerinin ürettiği ürünler (meydandaki Sipariş Panosu'nda "Ahır siparişleri" olarak teslim edilir)
	local _, goodsMeta = UiKit.sectionHeader(goodsPage, "Ahır Deposu", GOODS_ORDER)
	local goodsGrid = UiKit.grid(goodsPage, GOODS_ORDER + 1, true)
	local goodsCards: { [string]: UiKit.Card } = {}
	for index, goodId in Config.GOODS_ORDER do
		local good = Config.GOODS[goodId]
		local card = UiKit.tile(goodsGrid, index, good.icon, true)
		card.title.Text = good.displayName
		card.action.Visible = false
		goodsCards[goodId] = card
	end

	-- Takılı eşyalar: slot başına bir karo
	UiKit.sectionHeader(equippedPage, "Takılı eşyalar", SLOTS_ORDER)
	local slotGrid = UiKit.grid(equippedPage, SLOTS_ORDER + 1)
	local slotCards: { [string]: UiKit.Card } = {}
	for index, slotId in Config.ITEM_SLOT_ORDER do
		local slot = Config.ITEM_SLOTS[slotId]
		local card = UiKit.tile(slotGrid, index, slot.icon)
		card.title.Text = slot.displayName
		slotCards[slotId] = card
		card.action.Activated:Connect(function()
			local state = ClientState.get()
			local itemId = if state then Inventory.equippedId(state, slotId) else nil
			if itemId and card.action.Active then
				PurchaseController.submit("RequestEquipItem", itemId)
			end
		end)
	end

	-- Asa gücü: takılı asaya göre mevsim ya da hava seçenekleri
	local powerHeader = UiKit.sectionHeader(equippedPage, "Asa gücü", POWER_ORDER)
	local powerCard = UiKit.card(equippedPage, POWER_ORDER + 1, "🪄")
	local powerRow = Instance.new("Frame")
	powerRow.Name = "PowerRow"
	powerRow.BackgroundTransparency = 1
	powerRow.Size = UDim2.new(1, 0, 0, 36)
	powerRow.LayoutOrder = 3
	powerRow.Parent = powerCard.frame
	UiKit.list(powerRow, 4, true)
	local powerButtons: { TextButton } = {}
	for index = 1, POWER_BUTTONS do
		local button = UiKit.button(powerRow, "", "secondary")
		button.LayoutOrder = index
		button.Size = UDim2.new(1 / POWER_BUTTONS, -4, 1, 0)
		button.TextScaled = true
		local fit = Instance.new("UITextSizeConstraint")
		fit.MaxTextSize = 13
		fit.MinTextSize = 8
		fit.Parent = button
		powerButtons[index] = button
		button.Activated:Connect(function()
			local state = ClientState.get()
			local staffId = if state then Inventory.equippedId(state, "staff") else nil
			local optionId = button:GetAttribute("OptionId")
			if staffId and typeof(optionId) == "string" and button.Active then
				PurchaseController.submit("RequestUseItem", staffId, optionId)
			end
		end)
	end
	local function setPowerVisible(visible: boolean)
		(powerHeader.Parent :: GuiObject).Visible = visible
		powerCard.frame.Visible = visible
	end

	-- Sahip olunan eşyalar
	UiKit.sectionHeader(ownedPage, "Eşyalarım", OWNED_ORDER)
	local emptyText = UiKit.text(
		ownedPage,
		"Henüz eşyan yok. Meydandaki Usta Ömer'den eşya alabilirsin.",
		"Body",
		Color.TextMuted
	)
	emptyText.LayoutOrder = OWNED_ORDER + 1
	local ownedGrid = UiKit.grid(ownedPage, OWNED_ORDER + 2)
	local ownedCards: { [string]: UiKit.Card } = {}
	for position, itemId in Config.ITEM_ORDER do
		local item = Config.ITEMS[itemId]
		local card = UiKit.tile(ownedGrid, position, item.icon)
		card.title.Text = item.displayName
		card.detail.Text = ItemText.describe(item)
		card.frame.Visible = false
		ownedCards[itemId] = card
		card.action.Activated:Connect(function()
			if card.action.Active then
				PurchaseController.submit("RequestEquipItem", itemId)
			end
		end)
	end

	local function powerOptions(kind: string): ({ { id: string, label: string } }, string)
		local options: { { id: string, label: string } } = {}
		if kind == "season" then
			for _, season in Config.SEASONS do
				table.insert(options, { id = season.id, label = season.displayName })
			end
			return options, Environment.getSeason().id
		end
		local pool = Environment.getSeason().weather
		for _, weatherId in WEATHER_ORDER do
			if pool[weatherId] and Config.WEATHER[weatherId] then
				table.insert(options, { id = weatherId, label = Config.WEATHER[weatherId].displayName })
			end
		end
		return options, Environment.getWeather().id
	end

	local function update(state: PlayerSave)
		local now = Workspace:GetServerTimeNow()
		-- Ahır deposu
		local cap = FarmMath.getGoodsCap(state)
		for goodId, card in goodsCards do
			local amount = FarmMath.getGoodsAmount(state, goodId)
			card.detail.Text = `{amount}/{cap} · Değer {FarmMath.formatMoney(amount * Config.GOODS[goodId].value)}`
			card.frame.BackgroundTransparency = if amount > 0 then 0 else 0.5
		end
		goodsMeta.Text = FarmMath.formatMoney(FarmMath.getGoodsWorth(state))
		-- Takılı eşyalar
		local ownedAny = false
		for slotId, card in slotCards do
			local itemId = Inventory.equippedId(state, slotId)
			local item = if itemId then Config.ITEMS[itemId] else nil
			if item then
				card.icon.Text = item.icon
				card.title.Text = item.displayName
				card.detail.Text = ItemText.describe(item)
				setPurchaseButton(card.action, "Çıkar", "secondary")
			else
				card.icon.Text = Config.ITEM_SLOTS[slotId].icon
				card.title.Text = Config.ITEM_SLOTS[slotId].displayName
				card.detail.Text = "Boş"
				setPurchaseButton(card.action, "Boş", "disabled")
			end
		end
		-- Sahip olunanlar
		for itemId, card in ownedCards do
			local owned = Inventory.owns(state, itemId)
			card.frame.Visible = owned
			ownedAny = ownedAny or owned
			if owned then
				setPurchaseButton(
					card.action,
					if Inventory.isEquipped(state, itemId) then "Çıkar" else "Tak",
					if Inventory.isEquipped(state, itemId) then "secondary" else "primary"
				)
			end
		end
		emptyText.Visible = not ownedAny
		-- Asa gücü
		local staffId = Inventory.equippedId(state, "staff")
		local staff = if staffId then Config.ITEMS[staffId] else nil
		setPowerVisible(staff ~= nil)
		if not staff or not staffId or not staff.power then
			return
		end
		local left = Inventory.usesLeft(state, staffId, now)
		powerCard.icon.Text = staff.icon
		powerCard.title.Text = staff.displayName
		powerCard.detail.Text = if left == math.huge
			then "Sınırsız hak"
			else `Bugün kalan hak: {left}/{Inventory.usesPerDay(staff)}`
		local options, currentId = powerOptions(staff.power.kind)
		local usable = Inventory.canUse(state, staffId, now)
		for index, button in powerButtons do
			local option = options[index]
			button.Visible = option ~= nil
			if option then
				button:SetAttribute("OptionId", option.id)
				setPurchaseButton(
					button,
					option.label,
					if usable and option.id ~= currentId then "primary" else "disabled"
				)
			end
		end
	end

	-- Kalan hak ve bekleme süresi zamanla değişir: pencere açıkken saniyede bir tazele
	task.spawn(function()
		while true do
			task.wait(1)
			local state = ClientState.get()
			if state and window.isOpen() then
				update(state)
			end
		end
	end)

	return { window = window, update = update }
end

return InventoryWindow
