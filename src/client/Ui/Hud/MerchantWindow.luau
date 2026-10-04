--!strict
-- Kişisel ziyaret kataloğu; teklif/fiyat sunucuyla aynı saf modülden, ödeme sunucu doğrulamasıyla.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local Merchant = require(Shared:WaitForChild("Modules"):WaitForChild("Merchant"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))
local HudCommon = require(script.Parent:WaitForChild("HudCommon"))
local ItemPreview = require(script.Parent:WaitForChild("ItemPreview"))
local ItemText = require(script.Parent:WaitForChild("ItemText"))
type PlayerSave = GameTypes.PlayerSave
local MerchantWindow = {}

function MerchantWindow.create(parent: Instance): { window: UiKit.Window, update: (PlayerSave) -> () }
	local window = UiKit.window(parent, {
		title = "Gezgin Tüccar",
		icon = "🧳",
		tint = UiKit.Color.Gold,
		width = 600,
		maxHeight = 560,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	local summary = UiKit.text(window.list, "", "Body")
	summary.LayoutOrder = 0
	UiKit.text(
		window.list,
		"Ziyaret başına bir eşya seçebilirsin. Nakit eşyalar rebirth'te sıfırlanır.",
		"Caption"
	).LayoutOrder =
		1
	local travel = UiKit.button(window.list, "Tüccara git", "secondary")
	travel.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
	travel.LayoutOrder = 2
	travel.Activated:Connect(function()
		Remotes.get("RequestTravel"):FireServer("hub")
	end)
	local grid = UiKit.autoGrid(window.list, 3, 2)
	local entries: { [string]: { card: UiKit.Card, details: any, quote: Merchant.Offer? } } = {}
	local current: PlayerSave? = nil
	local context: string? = nil
	local update: (PlayerSave) -> ()
	for index, itemId in Config.ITEM_ORDER do
		local item = Config.ITEMS[itemId]
		if item.rewardOnly or item.price <= 0 then
			continue
		end
		local card = UiKit.autoTile(grid, index, item.icon, { compact = true })
		card.frame.Visible = false
		UiKit.setText(card.title, item.displayName)
		local details = UiKit.disclosure(card.frame, 6, "Ayrıntılar")
		UiKit.text(details.body, `{ItemText.slotNotice(item)}\n{ItemText.additional(item)}`, "Caption")
		local entry = { card = card, details = details, quote = nil :: Merchant.Offer? }
		entries[itemId] = entry
		details.body:GetPropertyChangedSignal("Visible"):Connect(function()
			if current then
				update(current)
			end
		end)
		card.action.Activated:Connect(function()
			local quote = entry.quote
			if not quote or not card.action.Active then
				return
			end
			if not details.isExpanded() then
				details.setExpanded(true)
				return
			end
			PurchaseController.submit(
				"RequestBuyMerchantOffer",
				itemId,
				{ cycle = quote.cycle, expectedPrice = quote.price }
			)
		end)
	end
	update = function(state: PlayerSave)
		current = state
		if not window.isOpen() then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local status = Merchant.status(state, Players.LocalPlayer.UserId, now)
		local nextContext =
			`{state.activeMainFarmId}:{if state.progression then state.progression.run else 1}:{if status.visit
				then status.visit.cycle
				else -1}`
		if context ~= nextContext then
			context = nextContext
			for _, entry in entries do
				entry.details.setExpanded(false)
			end
		end
		local quotes: { [string]: Merchant.Offer } = {}
		for _, offer in status.offers do
			quotes[offer.itemId] = offer
		end
		for itemId, entry in entries do
			local quote = quotes[itemId]
			entry.quote = quote
			entry.card.frame.Visible = quote ~= nil
			if quote then
				if not entry.card.icon:GetAttribute("MerchantPreview") then
					ItemPreview.mount(entry.card.icon, itemId)
					entry.card.icon:SetAttribute("MerchantPreview", true)
				end
				local item = Config.ITEMS[itemId]
				local benefit = string.split(ItemText.describe(item), "\n")[1]
				UiKit.setText(
					entry.card.detail,
					`{benefit}\nNormal: {FarmMath.formatMoney(quote.fullPrice)} · %{math.round(
						Config.MERCHANT.discount * 100
					)} indirim`
				)
				HudCommon.setPurchaseButton(
					entry.card.action,
					`{if entry.details.isExpanded() then "Satın al" else "İncele"} · {FarmMath.formatMoney(
						quote.price
					)}`,
					if state.cash >= quote.price then "primary" else "warning"
				)
			end
		end
		travel.Visible = status.visit ~= nil and not status.bought
		local left = if status.visit then math.max(0, math.ceil(status.visit.endsAt - now)) else 0
		UiKit.setText(
			summary,
			if not status.visit
				then "Gezgin tüccar şu an yolda. Geldiğinde rozetinden haberdar olursun."
				elseif status.bought then "Bu ziyarette eşyanı aldın. Yeni teklifler bir sonraki ziyarette."
				elseif
					#status.offers == 0
				then "Bu ziyaretin eşyalarına zaten sahipsin. Yeni teklifler bir sonraki ziyarette."
				else `Ziyaretin bitmesine {string.format("%d:%02d", left // 60, left % 60)} kaldı. Satın almak için meydandaki tüccara yaklaş.`
		)
	end
	window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.isOpen() and current then
			update(current)
		else
			for _, entry in entries do
				entry.details.setExpanded(false)
			end
		end
	end)
	return { window = window, update = update }
end

return MerchantWindow
