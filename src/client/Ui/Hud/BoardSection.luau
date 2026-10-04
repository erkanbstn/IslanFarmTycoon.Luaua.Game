--!strict
-- Sipariş Panosu: ahır siparişleri (ürün merkezlerinin depoya koyduğu ürünler para karşılığı teslim edilir) ve mevsim etkinliği bonusu.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))

type PlayerSave = GameTypes.PlayerSave

local Color = UiKit.Color

local BoardSection = {}

function BoardSection.create(list: Instance): (PlayerSave?) -> ()
	-- Ahır siparişleri: ürün merkezlerinin ahır deposuna koyduğu ürünler para karşılığı teslim edilir (yol haritasından bağımsız)
	local CONTRACT_ORDER = 10
	local _, contractMeta = UiKit.sectionHeader(list, "Ahır siparişleri", CONTRACT_ORDER)
	local information = UiKit.disclosure(list, CONTRACT_ORDER + 1, "Ayrıntılar")
	local contractNote = UiKit.text(information.body, "", "Caption", Color.TextMuted)
	local emptyState = UiKit.emptyState(
		list,
		"📦",
		"Siparişler henüz açılmadı",
		"Bir ürün merkezi kurunca ahır siparişleri açılır (Üretim penceresi)."
	)
	local empty = emptyState.frame
	empty.LayoutOrder = CONTRACT_ORDER + 1
	local contractCards: { UiKit.Card } = {}
	local contractOffers: { FarmMath.ContractOffer } = {}
	-- Siparişler ızgara karolarıdır: aşağı uzayan liste yerine yan yana, daha çok teklif görünür. Esnek karo: altı çeşitlik "Dev Karma"
	-- siparişin satırları da sığar (karo yüksekliği satır sayısına göre uzar).
	local contractGrid = UiKit.autoGrid(list, CONTRACT_ORDER + 2, 2)
	for index = 1, Config.GOODS_CONTRACTS.slots do
		local card = UiKit.autoTile(contractGrid, index, "📦")
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
		information.frame.Visible = hasCenter
		empty.Visible = not hasCenter
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
			local done = FarmMath.isContractDone(state, offer)
			local lines: { string } = {}
			if done then
				-- Teslim sonrası stok azalır; tamamlanan slot yeni ürün/ödülle de değişebilir.
				table.insert(lines, "Bu sipariş bu turda zaten teslim edildi")
			else
				for _, line in offer.lines do
					local good = Config.GOODS[line.goodsId]
					table.insert(
						lines,
						`{good.displayName} · {FarmMath.getGoodsAmount(state, line.goodsId)}/{line.amount}`
					)
				end
				table.insert(lines, `Ödül: {FarmMath.formatMoney(offer.reward)}`)
			end
			card.icon.Text = Config.GOODS[offer.lines[1].goodsId].icon
			card.title.Text = offer.displayName
			card.detail.Text = table.concat(lines, "\n")
			if done then
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

	return function(state: PlayerSave?)
		if state then
			updateContracts(state)
		end
	end
end

return BoardSection
