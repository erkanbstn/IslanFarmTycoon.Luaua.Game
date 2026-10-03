--!strict
-- Eşya Dükkânı: meydandaki satıcıdan oyun parasıyla eşya alınır (bir kez, kalıcı). Satın alınan eşya Envanter'den takılır.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Inventory = require(Shared:WaitForChild("Modules"):WaitForChild("Inventory"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))
local HudCommon = require(script.Parent:WaitForChild("HudCommon"))
local ItemText = require(script.Parent:WaitForChild("ItemText"))
local ItemPreview = require(script.Parent:WaitForChild("ItemPreview"))

type PlayerSave = GameTypes.PlayerSave

local Color = UiKit.Color
local setPurchaseButton = HudCommon.setPurchaseButton

local ItemShopWindow = {}

export type Shop = {
	window: UiKit.Window,
	update: (state: PlayerSave) -> (),
}

function ItemShopWindow.create(screenGui: Instance, openPermanent: (() -> ())?): Shop
	local window = UiKit.window(screenGui, {
		title = "Eşya Dükkânı",
		icon = "🎒",
		tint = Color.Gold,
		width = 380,
		maxHeight = 480,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	UiKit.text(
		window.list,
		"Nakit eşyalar bu tur içindir. Altın/Robux ile kalıcı sahiplik rebirth'te korunur. Eşyaları Envanter'den takarsın.",
		"Caption"
	).LayoutOrder =
		0
	if openPermanent then
		local permanentButton = UiKit.button(window.list, "Kalıcı altın teklifleri", "secondary")
		permanentButton.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
		permanentButton.LayoutOrder = 1
		permanentButton.Activated:Connect(openPermanent)
	end

	-- Kategori sekmeleri (slot başına): seçili kategorinin eşyaları ızgara karoları olarak gösterilir
	local cards: { [string]: UiKit.Card } = {}
	local grids: { [string]: Frame } = {}
	local tabEntries: { { id: string, label: string } } = {}
	for slotIndex, slotId in Config.ITEM_SLOT_ORDER do
		local slot = Config.ITEM_SLOTS[slotId]
		table.insert(tabEntries, { id = slotId, label = slot.displayName })
		local grid = UiKit.autoGrid(window.list, 10, 2)
		grid.Visible = slotIndex == 1
		grids[slotId] = grid
		for position, item in ItemText.itemsOfSlot(slotId) do
			local card = UiKit.autoTile(grid, position, item.icon, { compact = true })
			ItemPreview.mount(card.icon, item.id)
			card.title.Text = item.displayName
			card.detail.Text = ItemText.describe(item)
			cards[item.id] = card
			card.action.Activated:Connect(function()
				if card.action.Active then
					PurchaseController.submit("RequestBuyItem", item.id)
				end
			end)
		end
	end
	UiKit.tabs(window.list, 5, tabEntries, function(slotId: string)
		for gridSlot, grid in grids do
			grid.Visible = gridSlot == slotId
		end
	end)

	local function update(state: PlayerSave)
		for itemId, card in cards do
			local item = Config.ITEMS[itemId]
			local permanent = state.owned ~= nil and state.owned.items[itemId] == true
			UiKit.setText(card.detail, `{if permanent then "Kalıcı" else "Bu tur"} · {ItemText.describe(item)}`)
			ItemPreview.mount(card.icon, itemId)
			if Inventory.owns(state, itemId) then
				setPurchaseButton(
					card.action,
					if permanent then "Kalıcı olarak sahipsin" else "Sahipsin · Bu tur",
					"owned"
				)
			else
				setPurchaseButton(
					card.action,
					FarmMath.formatMoney(item.price),
					if state.cash >= item.price then "primary" else "warning"
				)
			end
		end
	end

	return { window = window, update = update }
end

return ItemShopWindow
