--!strict
-- Sipariş Panosu: 3 seçenek (kısa/orta/uzun) ve mevsim etkinliği bonusu.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local OrderBoard = require(Shared:WaitForChild("Modules"):WaitForChild("OrderBoard"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent:WaitForChild("PurchaseController"))

type PlayerSave = GameTypes.PlayerSave

local Color = UiKit.Color

local BoardSection = {}

function BoardSection.create(list: Instance): (PlayerSave?) -> ()
	local BOARD_ORDER = 60
	local _, boardMeta = UiKit.sectionHeader(list, "Sipariş panosu", BOARD_ORDER)
	local lockedNote =
		UiKit.text(list, "Siparişler, yol haritasındaki her şey tamamlanınca açılır.", "Body", Color.TextMuted)
	lockedNote.LayoutOrder = BOARD_ORDER - 1
	local boardEvent = UiKit.text(list, "", "Caption", Color.Gold)
	boardEvent.LayoutOrder = BOARD_ORDER + 1
	local boardCards: { UiKit.Card } = {}
	local boardOffers: { OrderBoard.Offer } = {}
	for index = 1, #Config.ORDER_TIERS do
		local card = UiKit.card(list, BOARD_ORDER + 1 + index, "📋")
		boardCards[index] = card
		card.action.Activated:Connect(function()
			local offer = boardOffers[index]
			if card.action.Active and offer then
				PurchaseController.submit("RequestPickOrder", offer.key)
			end
		end)
	end

	-- Yol haritası bitince (seviyeli geliştirmeler hariç) sipariş sistemi açılır
	local function ordersUnlocked(state: PlayerSave): boolean
		for _, upgrade in Config.UPGRADES do
			if
				not upgrade.leveled
				and FarmMath.isUpgradeInTheme(state, upgrade)
				and not state.purchased[upgrade.id]
			then
				return false
			end
		end
		return true
	end

	local boardSignature = ""
	local function updateBoard(state: PlayerSave?)
		if not state then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local visible = ordersUnlocked(state)
		local season = Environment.getSeason()
		local bonus = season.orderBonus or 0
		local offers = if visible then OrderBoard.offers(state, now, bonus) else {}
		visible = visible and #offers > 0
		local order = state.order
		local blocked = order ~= nil and order.progress >= order.target
		local parts: { string } =
			{ tostring(visible), tostring(bonus), tostring(blocked), tostring(PurchaseController.isPending()) }
		for _, offer in offers do
			table.insert(parts, `{offer.key}{offer.animalId}{offer.reward}`)
		end
		if order then
			table.insert(parts, `{order.animalId}{order.target}{order.rewardFactor or 1}`)
		end
		local signature = table.concat(parts, "|")
		if signature == boardSignature then
			return
		end
		boardSignature = signature
		boardOffers = offers
		lockedNote.Visible = not ordersUnlocked(state);
		(boardMeta.Parent :: GuiObject).Visible = visible
		boardEvent.Visible = visible and bonus > 0
		if bonus > 0 and season.eventName then
			boardEvent.Text = `{season.eventName} · Sipariş ödülü +%{math.round(bonus * 100)}`
		end
		local pending = PurchaseController.isPending()
		for index, card in boardCards do
			local offer = offers[index]
			card.frame.Visible = visible and offer ~= nil
			if not offer then
				continue
			end
			local animal = Config.ANIMALS[offer.animalId]
			local tier = Config.ORDER_TIERS[index]
			card.icon.Text = animal.icon
			card.title.Text = `{tier.displayName} · {animal.product}`
			card.detail.Text = `{offer.units} birim · Ödül: {FarmMath.formatMoney(offer.reward)}`
			local active = order ~= nil
				and order.animalId == offer.animalId
				and order.target == offer.units
				and (order.rewardFactor or 1) == offer.rewardFactor
			if active then
				card.action.Text = "Aktif sipariş"
				UiKit.setVariant(card.action, "owned")
			elseif blocked then
				card.action.Text = "Önce teslim et"
				UiKit.setVariant(card.action, "disabled")
			else
				card.action.Text = if order and order.progress > 0 then "Seç · ilerleme sıfırlanır" else "Seç"
				UiKit.setVariant(card.action, if pending then "disabled" else "primary")
			end
		end
	end
	return updateBoard
end

return BoardSection
