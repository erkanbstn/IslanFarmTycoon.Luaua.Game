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
local ItemPreview = require(script.Parent:WaitForChild("ItemPreview"))
local WeatherQueuePrompt = require(script.Parent:WaitForChild("WeatherQueuePrompt"))

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

function InventoryWindow.create(screenGui: Instance): Panel
	local weatherQueue = WeatherQueuePrompt.create(screenGui)
	local window = UiKit.window(screenGui, {
		title = "Envanter",
		icon = "🎒",
		tint = Color.Orange,
		width = 600,
		maxHeight = 560,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	UiKit.text(window.list, "Ürünlerini sat veya eşyalarını tak.", "Caption").LayoutOrder = GOODS_ORDER - 1

	-- Sekmeler: Ahır Deposu | Takılı | Eşyalarım (her sekme kendi sayfası; öğeler ızgara karolarıdır)
	local pages: { [string]: Frame } = {}
	local disclosures: { any } = {}
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
	local weatherQueueButton = UiKit.button(equippedPage, "Hava sıram", "secondary")
	weatherQueueButton.LayoutOrder = POWER_ORDER + 2
	weatherQueueButton.Visible = false
	weatherQueueButton.Activated:Connect(weatherQueue.open)
	local function showPage(id: string)
		for _, details in disclosures do
			details.setExpanded(false)
		end
		for pageId, page in pages do
			page.Visible = pageId == id
		end
	end
	local _, _, setPageBadge = UiKit.tabs(window.list, GOODS_ORDER, {
		{ id = "goods", label = "Ahır Deposu" },
		{ id = "equipped", label = "Takılı" },
		{ id = "owned", label = "Eşyalarım" },
	}, showPage)
	showPage("goods")

	-- Ahır deposu: ürün merkezlerinin ürettiği ürünler (meydandaki Sipariş Panosu'nda "Ahır siparişleri" olarak teslim edilir)
	local _, goodsMeta = UiKit.sectionHeader(goodsPage, "Ahır Deposu", GOODS_ORDER)
	local goodsNote = UiKit.text(goodsPage, "", "Caption", Color.TextMuted)
	goodsNote.LayoutOrder = GOODS_ORDER + 1
	-- Esnek karolar (2 sütun): her ürünün altında "Yarısı" ve "Hepsi" hızlı satış düğmeleri (para ve ürün sunucuda hesaplanır)
	local goodsGrid = UiKit.autoGrid(goodsPage, GOODS_ORDER + 2, 2)
	local goodsCards: { [string]: UiKit.Card } = {}
	local halfButtons: { [string]: TextButton } = {}
	local allButtons: { [string]: TextButton } = {}
	for index, goodId in Config.GOODS_ORDER do
		local good = Config.GOODS[goodId]
		local card = UiKit.autoTile(goodsGrid, index, good.icon)
		card.title.Text = good.displayName
		card.action.Visible = false
		goodsCards[goodId] = card
		local row = Instance.new("Frame")
		row.Name = "SellRow"
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
		row.LayoutOrder = 5
		row.Parent = card.frame
		local sellLayout = UiKit.list(row, 4, true)
		local halfButton = UiKit.button(row, "", "secondary")
		halfButton.Size = UDim2.new(0.5, -2, 1, 0)
		halfButton.TextSize = UiKit.TextSize.Caption
		halfButton.LayoutOrder = 1
		halfButtons[goodId] = halfButton
		local allButton = UiKit.button(row, "", "secondary")
		allButton.Size = UDim2.new(0.5, -2, 1, 0)
		allButton.TextSize = UiKit.TextSize.Caption
		allButton.LayoutOrder = 2
		allButtons[goodId] = allButton
		-- Dar kartta fiyatlı iki düğme yan yana sıkışmasın; dokunma alanları korunur.
		local stacked: boolean? = nil
		local function resizeSellRow()
			local nextStacked = row.AbsoluteSize.X < 240
			if nextStacked == stacked then
				return
			end
			stacked = nextStacked
			sellLayout.FillDirection = if nextStacked
				then Enum.FillDirection.Vertical
				else Enum.FillDirection.Horizontal
			row.Size = UDim2.new(1, 0, 0, if nextStacked then UiKit.TouchTarget * 2 + 4 else UiKit.TouchTarget)
			local size = if nextStacked
				then UDim2.new(1, 0, 0, UiKit.TouchTarget)
				else UDim2.new(0.5, -2, 0, UiKit.TouchTarget)
			halfButton.Size = size
			allButton.Size = size
		end
		local sellSizeConnection = row:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeSellRow)
		row.Destroying:Connect(function()
			sellSizeConnection:Disconnect()
		end)
		resizeSellRow()
		halfButton.Activated:Connect(function()
			if halfButton.Active then
				PurchaseController.submit("RequestSellGoods", goodId, "half")
			end
		end)
		allButton.Activated:Connect(function()
			if allButton.Active then
				PurchaseController.submit("RequestSellGoods", goodId, "all")
			end
		end)
	end

	-- Takılı eşyalar: slot başına bir karo
	UiKit.sectionHeader(equippedPage, "Takılı eşyalar", SLOTS_ORDER)
	local slotGrid = UiKit.autoGrid(equippedPage, SLOTS_ORDER + 1, 2)
	local slotCards: { [string]: UiKit.Card } = {}
	local slotDetails: { [string]: TextLabel } = {}
	local slotPanels: { [string]: any } = {}
	for index, slotId in Config.ITEM_SLOT_ORDER do
		local slot = Config.ITEM_SLOTS[slotId]
		local card = UiKit.autoTile(slotGrid, index, slot.icon, { compact = true })
		card.title.Text = slot.displayName
		slotCards[slotId] = card
		local details = UiKit.disclosure(card.frame, 6, "Ayrıntılar")
		table.insert(disclosures, details)
		slotDetails[slotId] = UiKit.text(details.body, "", "Caption")
		slotPanels[slotId] = details
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
	local powerRow = UiKit.actionRow(powerCard.frame, 3, 4, 86)
	local powerButtons: { TextButton } = {}
	for index = 1, POWER_BUTTONS do
		local button = UiKit.actionButton(powerRow, index, "", "secondary")
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

	-- Sahip olunan eşyalar: yalnızca seçili slotun eşyaları gösterilir.
	UiKit.sectionHeader(ownedPage, "Eşyalarım", OWNED_ORDER)
	local selectedCategory = "all"
	local categoryEntries: { { id: string, label: string } } = { { id = "all", label = "Tümü" } }
	for _, slotId in Config.ITEM_SLOT_ORDER do
		table.insert(categoryEntries, { id = slotId, label = Config.ITEM_SLOTS[slotId].displayName })
	end
	local emptyState = UiKit.emptyState(
		ownedPage,
		"🎒",
		"Henüz eşyan yok",
		"Henüz eşyan yok. Meydandaki Usta Ömer'den eşya alabilirsin."
	)
	local emptyText = emptyState.description
	emptyState.frame.LayoutOrder = OWNED_ORDER + 2
	local ownedGrid = UiKit.autoGrid(ownedPage, OWNED_ORDER + 3, 2)
	local ownedCards: { [string]: UiKit.Card } = {}
	local ownedDetails: { [string]: TextLabel } = {}
	for position, item in ItemText.itemsOfSlot() do
		local itemId = item.id
		local card = UiKit.autoTile(ownedGrid, position, item.icon, { compact = true })
		card.title.Text = `{item.displayName} · Sv.{item.level or 1}`
		card.detail.Text = ItemText.describe(item)
		ItemPreview.mount(card.icon, itemId)
		card.frame.Visible = false
		ownedCards[itemId] = card
		local details = UiKit.disclosure(card.frame, 6, "Ayrıntılar")
		table.insert(disclosures, details)
		ownedDetails[itemId] = UiKit.text(details.body, ItemText.describe(item), "Caption")
		card.action.Activated:Connect(function()
			if card.action.Active then
				local state = ClientState.get()
				if state and not Inventory.isEquipped(state, itemId) and not details.isExpanded() then
					details.setExpanded(true)
					return
				end
				PurchaseController.submit("RequestEquipItem", itemId)
			end
		end)
	end
	local lastState: PlayerSave? = nil
	local function filterOwned(state: PlayerSave?)
		local anyOwned, anyVisible = false, false
		for itemId, card in ownedCards do
			local owned = state ~= nil and Inventory.owns(state, itemId)
			local visible = owned and (selectedCategory == "all" or Config.ITEMS[itemId].slot == selectedCategory)
			card.frame.Visible = visible
			anyOwned = anyOwned or owned
			anyVisible = anyVisible or visible
		end
		ownedGrid.Visible = anyVisible
		emptyState.frame.Visible = not anyVisible
		UiKit.setText(emptyState.title, if anyOwned then "Bu kategori boş" else "Henüz eşyan yok")
		UiKit.setText(
			emptyText,
			if anyOwned
				then "Bu kategoride henüz eşyan yok."
				else "Henüz eşyan yok. Meydandaki Usta Ömer'den eşya alabilirsin."
		)
	end
	UiKit.tabs(ownedPage, OWNED_ORDER + 1, categoryEntries, function(categoryId: string)
		selectedCategory = categoryId
		for _, details in disclosures do
			details.setExpanded(false)
		end
		filterOwned(lastState)
	end)

	local function powerOptions(kind: string): ({ { id: string, label: string } }, string)
		local options: { { id: string, label: string } } = {}
		if kind == "season" then
			for _, season in Config.SEASONS do
				table.insert(options, { id = season.id, label = season.displayName })
			end
			return options, Environment.getSeason().id
		end
		-- Hava asası sunucu mevsimine göre seçilir; kişisel mevsim asası havuzu değiştirmez.
		local pool = Environment.getSeason({}).weather
		for _, weatherId in WEATHER_ORDER do
			if pool[weatherId] and Config.WEATHER[weatherId] then
				table.insert(options, { id = weatherId, label = Config.WEATHER[weatherId].displayName })
			end
		end
		return options, Environment.getWeather().id
	end

	local lastContext: string? = nil
	local function update(state: PlayerSave)
		weatherQueueButton.Visible = weatherQueue.hasEntry()
		local context = `{state.activeMainFarmId}:{if state.progression then state.progression.run else 1}`
		if context ~= lastContext then
			for _, details in disclosures do
				details.setExpanded(false)
			end
			lastContext = context
		end
		local now = Workspace:GetServerTimeNow()
		-- Ahır deposu
		local cap = FarmMath.getGoodsCap(state)
		local fullGoods = FarmMath.getFullGoods(state)
		setPageBadge("goods", #fullGoods)
		for goodId, card in goodsCards do
			local amount = FarmMath.getGoodsAmount(state, goodId)
			card.frame.Visible = amount > 0
			local worth = FarmMath.formatMoney(amount * Config.GOODS[goodId].value)
			card.detail.Text = if table.find(fullGoods, goodId)
				then `{amount}/{cap} · Depo dolu · Değer {worth}`
				else `{amount}/{cap} · Değer {worth}`
			card.frame.BackgroundTransparency = if amount > 0 then 0 else 0.5
			local halfAmount = FarmMath.getGoodsSellAmount(state, goodId, "half")
			if amount > 0 then
				setPurchaseButton(
					halfButtons[goodId],
					`Yarısı · {FarmMath.formatMoney(FarmMath.getGoodsSellValue(goodId, halfAmount))}`,
					"secondary"
				)
				setPurchaseButton(
					allButtons[goodId],
					`Hepsi · {FarmMath.formatMoney(FarmMath.getGoodsSellValue(goodId, amount))}`,
					"primary"
				)
			else
				setPurchaseButton(halfButtons[goodId], "Yarısı", "disabled")
				setPurchaseButton(allButtons[goodId], "Hepsi", "disabled")
			end
		end
		goodsMeta.Text = FarmMath.formatMoney(FarmMath.getGoodsWorth(state))
		goodsNote.Text = if FarmMath.getGoodsWorth(state) <= 0
			then "Ahır deposunda henüz ürün yok. Üretimden ürün kazanabilirsin."
			else `Hızlı satış ürün değerinin %{math.round(Config.GOODS_SELL.rate * 100)}'ini öder; ahır siparişi her zaman daha çok kazandırır.`
		-- Takılı eşyalar
		for slotId, card in slotCards do
			local itemId = Inventory.equippedId(state, slotId)
			local item = if itemId then Config.ITEMS[itemId] else nil
			if item then
				slotPanels[slotId].frame.Visible = true
				card.icon.Text = item.icon
				ItemPreview.mount(card.icon, itemId)
				card.title.Text = item.displayName
				UiKit.setText(
					slotDetails[slotId],
					`{if state.owned and state.owned.items[itemId :: string] then "Kalıcı" else "Bu tur"} · {ItemText.slotNotice(
						item
					)}\n{ItemText.additional(item)}`
				)
				UiKit.setText(card.detail, string.match(ItemText.describe(item), "[^\n]+") or "")
				setPurchaseButton(card.action, "Çıkar", "secondary")
			else
				slotPanels[slotId].frame.Visible = false
				slotPanels[slotId].setExpanded(false)
				UiKit.setText(slotDetails[slotId], "")
				card.icon.Text = Config.ITEM_SLOTS[slotId].icon
				ItemPreview.mount(card.icon, nil)
				card.title.Text = Config.ITEM_SLOTS[slotId].displayName
				card.detail.Text = "Boş"
				setPurchaseButton(card.action, "Boş", "disabled")
			end
		end
		-- Sahip olunanlar
		for itemId, card in ownedCards do
			local owned = Inventory.owns(state, itemId)
			if owned then
				UiKit.setText(
					ownedDetails[itemId],
					`{if state.owned and state.owned.items[itemId] then "Kalıcı" else "Bu tur"} · {ItemText.slotNotice(
						Config.ITEMS[itemId]
					)}\n{ItemText.additional(Config.ITEMS[itemId])}`
				)
				UiKit.setText(card.detail, string.match(ItemText.describe(Config.ITEMS[itemId]), "[^\n]+") or "")
				ItemPreview.mount(card.icon, itemId)
				setPurchaseButton(
					card.action,
					if Inventory.isEquipped(state, itemId) then "Çıkar" else "Tak",
					if Inventory.isEquipped(state, itemId) then "secondary" else "primary"
				)
			end
		end
		lastState = state
		filterOwned(state)
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
		while window.frame.Parent do
			task.wait(1)
			local state = ClientState.get()
			if state and window.isOpen() then
				update(state)
			end
		end
	end)

	window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not window.isOpen() then
			for _, details in disclosures do
				details.setExpanded(false)
			end
		end
	end)
	return { window = window, update = update }
end

return InventoryWindow
