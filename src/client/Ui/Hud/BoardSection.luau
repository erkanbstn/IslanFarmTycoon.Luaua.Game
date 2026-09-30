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
local PurchaseController = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))

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

	-- Ahır siparişleri: ürün merkezlerinin ahır deposuna koyduğu ürünler para karşılığı teslim edilir (yol haritasından bağımsız)
	local CONTRACT_ORDER = 10
	local _, contractMeta = UiKit.sectionHeader(list, "Ahır siparişleri", CONTRACT_ORDER)
	local contractNote = UiKit.text(list, "", "Caption", Color.TextMuted)
	contractNote.LayoutOrder = CONTRACT_ORDER + 1
	local contractCards: { UiKit.Card } = {}
	local contractOffers: { FarmMath.ContractOffer } = {}
	for index = 1, #Config.GOODS_CONTRACTS.tiers do
		local card = UiKit.card(list, CONTRACT_ORDER + 1 + index, "📦")
		contractCards[index] = card
		card.action.Activated:Connect(function()
			local offer = contractOffers[index]
			if card.action.Active and offer then
				PurchaseController.submit("RequestFulfillContract", offer.key)
			end
		end)
	end
	local contractSignature = ""
	local function updateContracts(state: PlayerSave)
		local now = Workspace:GetServerTimeNow()
		local bonus = Environment.getSeason().orderBonus or 0
		local offers = FarmMath.getContractOffers(state, now, bonus)
		local hasCenter = #offers > 0
		local left = math.ceil(FarmMath.getContractSecondsLeft(now))
		contractMeta.Text = if hasCenter then `{math.floor(left / 60)}:{string.format("%02d", left % 60)}` else ""
		local pending = PurchaseController.isPending()
		local parts: { string } = { tostring(hasCenter), tostring(pending), tostring(bonus) }
		for _, offer in offers do
			local ready = FarmMath.canFulfillContract(state, offer)
			table.insert(parts, `{offer.key}|{offer.reward}|{ready}|{FarmMath.isContractDone(state, offer)}`)
			for _, line in offer.lines do
				table.insert(parts, `{line.goodsId}{line.amount}{FarmMath.getGoodsAmount(state, line.goodsId)}`)
			end
		end
		local signature = table.concat(parts, ",")
		if signature == contractSignature then
			return
		end
		contractSignature = signature
		contractOffers = offers
		contractNote.Text = if hasCenter
			then "Ürün merkezlerinin ahır deposuna koyduğu ürünleri para karşılığı teslim et. Pano süre dolunca yenilenir."
			else "Bir ürün merkezi kurunca ahır siparişleri açılır (Üretim penceresi)."
		for index, card in contractCards do
			local offer = offers[index]
			card.frame.Visible = offer ~= nil
			if not offer then
				continue
			end
			local lines: { string } = {}
			for _, line in offer.lines do
				local good = Config.GOODS[line.goodsId]
				table.insert(
					lines,
					`{good.displayName} · {FarmMath.getGoodsAmount(state, line.goodsId)}/{line.amount}`
				)
			end
			table.insert(lines, `Ödül: {FarmMath.formatMoney(offer.reward)}`)
			card.icon.Text = Config.GOODS[offer.lines[1].goodsId].icon
			card.title.Text = offer.displayName
			card.detail.Text = table.concat(lines, "\n")
			if FarmMath.isContractDone(state, offer) then
				card.action.Text = "Teslim edildi"
				UiKit.setVariant(card.action, "owned")
			elseif FarmMath.canFulfillContract(state, offer) then
				card.action.Text = "Teslim et"
				UiKit.setVariant(card.action, if pending then "disabled" else "primary")
			else
				card.action.Text = "Yeterli ürün yok"
				UiKit.setVariant(card.action, "disabled")
			end
		end
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
		updateContracts(state)
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
