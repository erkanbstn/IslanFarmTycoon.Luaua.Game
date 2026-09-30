--!strict
-- Hayvan Pazarı penceresi: hayvan listesi, toplu alım çarpanı ve hamsi-levrek değişimi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local Merchant = require(Shared:WaitForChild("Modules"):WaitForChild("Merchant"))
local ClientState = require(script.Parent.Parent:WaitForChild("ClientState"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent:WaitForChild("PurchaseController"))
local IslandContext = require(script.Parent.Parent:WaitForChild("IslandContext"))
local HudCommon = require(script.Parent:WaitForChild("HudCommon"))

type PlayerSave = GameTypes.PlayerSave

local Color = UiKit.Color
local setPurchaseButton = HudCommon.setPurchaseButton

local ShopWindow = {}

export type Shop = {
	window: UiKit.Window,
	update: (state: PlayerSave, content: boolean) -> (),
}

function ShopWindow.create(screenGui: ScreenGui, WINDOW_POSITION: UDim2): Shop
	local shopWindow = UiKit.window(screenGui, {
		title = "Hayvan Pazarı",
		icon = "🐄",
		tint = Color.Green,
		width = 330,
		maxHeight = 430,
		anchor = Vector2.new(1, 0.5),
		position = WINDOW_POSITION,
	})
	local shopInfo =
		UiKit.text(shopWindow.list, "Hayvanlar yavru doğar, büyüdükçe daha çok kazandırır.", "Caption")
	shopInfo.LayoutOrder = 0

	-- Toplu alım çarpanı: x1 / x2 / x3 / x5. Düğmedeki fiyat, o kadar hayvanın toplam fiyatıdır.
	local shopMultiplier = 1
	local multiplierButtons: { [number]: TextButton } = {}
	local multiplierRow = Instance.new("Frame")
	multiplierRow.Name = "Multipliers"
	multiplierRow.BackgroundTransparency = 1
	multiplierRow.Size = UDim2.new(1, 0, 0, 32)
	multiplierRow.LayoutOrder = 1
	multiplierRow.Parent = shopWindow.list
	UiKit.list(multiplierRow, 4, true)
	for index, multiplier in Config.BULK_MULTIPLIERS do
		local button = UiKit.button(multiplierRow, `x{multiplier}`, "secondary")
		button.LayoutOrder = index
		button.Size = UDim2.new(1 / #Config.BULK_MULTIPLIERS, -3, 1, 0)
		multiplierButtons[multiplier] = button
	end

	-- Seçili çarpana göre gerçekte alınacak adet (boş yer yetmezse azalır)
	local function bulkCount(state: PlayerSave, animalId: string): number
		return math.max(1, math.min(shopMultiplier, FarmMath.getFreeSlots(state, animalId)))
	end

	local animalCards: { [string]: UiKit.Card } = {}
	-- Irk geliştirme: sahip olunan her türün kartında ikinci düğme (oyun sonu para harcama yolu)
	local lineageRows: { [string]: Frame } = {}
	local lineageButtons: { [string]: TextButton } = {}
	local sellButtons: { [string]: TextButton } = {}
	for index, animalId in Config.ANIMAL_ORDER do
		local card = UiKit.card(shopWindow.list, index + 1, Config.ANIMALS[animalId].icon)
		animalCards[animalId] = card
		local lineageRow = Instance.new("Frame")
		lineageRow.Name = "LineageRow"
		lineageRow.BackgroundTransparency = 1
		lineageRow.Size = UDim2.new(1, 0, 0, 34)
		lineageRow.LayoutOrder = 3
		lineageRow.Visible = false
		lineageRow.Parent = card.frame
		local lineageButton = UiKit.button(lineageRow, "", "secondary")
		lineageButton.Size = UDim2.new(1, -100, 1, 0)
		local sellButton = UiKit.button(lineageRow, "", "secondary")
		sellButton.AnchorPoint = Vector2.new(1, 0)
		sellButton.Position = UDim2.fromScale(1, 0)
		sellButton.Size = UDim2.new(0, 94, 1, 0)
		sellButtons[animalId] = sellButton
		sellButton.Activated:Connect(function()
			if sellButton.Active then
				PurchaseController.submit("RequestSellAnimal", animalId)
			end
		end)
		lineageRows[animalId] = lineageRow
		lineageButtons[animalId] = lineageButton
		lineageButton.Activated:Connect(function()
			if lineageButton.Active then
				PurchaseController.submit("RequestUpgradeLineage", animalId)
			end
		end)
		card.action.Activated:Connect(function()
			if card.action.Active then
				local state = ClientState.get()
				local count = if state then bulkCount(state, animalId) else 1
				PurchaseController.submit("RequestBuyAnimal", animalId, if count > 1 then count else nil)
			end
		end)
	end

	-- Gezgin tüccar: ziyaret sürerken en üstte indirimli hayvan teklifi (teklif sunucuda yeniden doğrulanır)
	local merchantCard = UiKit.card(shopWindow.list, -1, "🧳")
	merchantCard.frame.Visible = false
	merchantCard.action.Activated:Connect(function()
		if merchantCard.action.Active then
			PurchaseController.submit("RequestBuyMerchantOffer", "merchant")
		end
	end)
	local function updateMerchant(state: PlayerSave)
		local offer = Merchant.offer(state, Players.LocalPlayer.UserId, Workspace:GetServerTimeNow())
		merchantCard.frame.Visible = offer ~= nil
		if not offer then
			return
		end
		local animal = Config.ANIMALS[offer.animalId]
		local left = math.max(0, offer.endsAt - Workspace:GetServerTimeNow())
		merchantCard.icon.Text = animal.icon
		merchantCard.title.Text = animal.displayName
		merchantCard.detail.Text =
			`Gezgin tüccar · x{offer.count} · %{math.round(Config.MERCHANT.discount * 100)} indirim · Normal fiyat: {FarmMath.formatMoney(
				offer.fullPrice
			)} · {string.format("%02d:%02d", math.ceil(left) // 60, math.ceil(left) % 60)} kaldı`
		setPurchaseButton(
			merchantCard.action,
			FarmMath.formatMoney(offer.price),
			if state.cash >= offer.price then "primary" else "warning"
		)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			local state = ClientState.get()
			if state and shopWindow.isOpen() then
				updateMerchant(state)
			end
		end
	end)

	local replacementCard = UiKit.card(shopWindow.list, 3 * #Config.ANIMAL_ORDER + 2, Config.ANIMALS.seabass.icon)
	replacementCard.title.Text = "Hamsiyi levrekle değiştir"
	replacementCard.action.Activated:Connect(function()
		local state = ClientState.get()
		local fish = state and FarmMath.findReplaceableFish(state)
		if fish and replacementCard.action.Active then
			PurchaseController.submit("RequestReplaceFish", fish.uid)
		end
	end)

	local function updateShop(state: PlayerSave, content: boolean)
		updateMerchant(state)
		if content then
			shopInfo.Text =
				`Açık bölgelerdeki hayvanlar listelenir (ada seçimi shop'u gizlemez). Yavru doğar, büyüdükçe kazanç artar.\nIrk geliştirme: her seviye o türün gelirini +%{math.round(
					Config.LINEAGE.incomePerLevel * 100
				)} artırır.`
		end
		for index, animalId in Config.ANIMAL_ORDER do
			local card = animalCards[animalId]
			local relevant = FarmMath.hasUnlockedAnimalZone(state, animalId)
			card.frame.Visible = relevant
			if not relevant then
				continue
			end
			local animalConfig = Config.ANIMALS[animalId]
			local lineageLevel = FarmMath.getLineageLevel(state, animalId)
			local lineageStatus, _, lineageCost = FarmMath.getLineageStatus(state, animalId)
			lineageRows[animalId].Visible = FarmMath.countAnimals(state, animalId) > 0
			local sellable = FarmMath.findSellableAnimal(state, animalId)
			if sellable then
				setPurchaseButton(
					sellButtons[animalId],
					`Sat · {FarmMath.formatMoney(FarmMath.getSellPrice(state, animalId))}`,
					"secondary"
				)
			else
				setPurchaseButton(sellButtons[animalId], "Sat", "disabled")
			end
			if lineageStatus == "max" then
				setPurchaseButton(lineageButtons[animalId], `Irk Sv.{lineageLevel} · en yüksek`, "owned")
			elseif lineageStatus == "locked" then
				setPurchaseButton(lineageButtons[animalId], "Irk: yetişkin gerekir", "disabled")
			else
				setPurchaseButton(
					lineageButtons[animalId],
					`Irk Sv.{lineageLevel} → {lineageLevel + 1} · {FarmMath.formatMoney(lineageCost)}`,
					if state.cash >= lineageCost then "primary" else "warning"
				)
			end
			local zoneId, reason, block = FarmMath.findZoneForAnimal(state, animalId)
			local count = bulkCount(state, animalId)
			local price = FarmMath.getBulkPrice(state, animalId, count)
			-- Alınabilenler üstte, parası yetmeyenler ortada, dolu/kilitliler altta.
			local group = if not zoneId then 2 elseif state.cash >= price then 0 else 1
			card.frame.LayoutOrder = index + 1 + group * #Config.ANIMAL_ORDER
			if content then
				card.title.Text = `{animalConfig.displayName}  {UiKit.colorText(
					`x{FarmMath.countAnimals(state, animalId)}`,
					Color.TextMuted
				)}`
				if zoneId then
					local income = FarmMath.getAnimalIncome(state, animalId)
					local affinity = if zoneId then FarmMath.getBuildBonus(state, zoneId, "seasonAffinity") else 0
					local percent = math.round((Environment.getIncomeMultiplier(animalId, nil, affinity) - 1) * 100)
					local effect = if percent > 0
						then ` · Mevsim/hava: +%{percent}`
						elseif percent < 0 then ` · Mevsim/hava: -%{-percent}`
						else ""
					card.detail.Text = `{animalConfig.product} · Yetişkin +${FarmMath.formatRate(income)}/sn{effect}`
				else
					card.detail.Text = reason or ""
				end
			end
			if not zoneId then
				setPurchaseButton(card.action, if block == "full" then "Dolu" else "Kilitli", "disabled")
			else
				setPurchaseButton(
					card.action,
					if count > 1 then `x{count} · {FarmMath.formatMoney(price)}` else FarmMath.formatMoney(price),
					if state.cash >= price then "primary" else "warning"
				)
			end
		end
		for multiplier, button in multiplierButtons do
			UiKit.setVariant(button, if multiplier == shopMultiplier then "primary" else "secondary")
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

	for multiplier, button in multiplierButtons do
		button.Activated:Connect(function()
			shopMultiplier = multiplier
			local state = ClientState.get()
			if state then
				updateShop(state, true)
			end
		end)
	end

	return { window = shopWindow, update = updateShop }
end

return ShopWindow
