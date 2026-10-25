--!strict
-- Hayvan Pazarı penceresi: hayvan listesi, toplu alım çarpanı ve kartta doğrudan hayvan satışı.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local ClientState = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientState"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))
local IslandContext = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("IslandContext"))
local HudCommon = require(script.Parent:WaitForChild("HudCommon"))

type PlayerSave = GameTypes.PlayerSave

local Color = UiKit.Color
local setPurchaseButton = HudCommon.setPurchaseButton

local ShopWindow = {}

export type Shop = {
	window: UiKit.Window,
	update: (state: PlayerSave, content: boolean) -> (),
}

function ShopWindow.create(screenGui: Instance, WINDOW_POSITION: UDim2): Shop
	local shopWindow = UiKit.window(screenGui, {
		title = "Hayvan Pazarı",
		icon = "🐄",
		tint = Color.Green,
		width = 600,
		maxHeight = 560,
		anchor = Vector2.new(0.5, 0.5),
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
	multiplierRow.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
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
	local detailsById: { [string]: any } = {}
	local fullDetails: { [string]: TextLabel } = {}
	-- Irk geliştirme: sahip olunan her türün kartında ikinci düğme (oyun sonu para harcama yolu)
	local lineageRows: { [string]: Frame } = {}
	local lineageButtons: { [string]: TextButton } = {}
	local sellButtons: { [string]: TextButton } = {}
	local barterButtons: { [string]: TextButton } = {}
	local animalGrid = UiKit.autoGrid(shopWindow.list, 2)
	for index, animalId in Config.ANIMAL_ORDER do
		local card = UiKit.autoTile(animalGrid, index, Config.ANIMALS[animalId].icon)
		animalCards[animalId] = card
		local details = UiKit.disclosure(card.frame, 6, "Ayrıntılar")
		detailsById[animalId] = details
		fullDetails[animalId] = UiKit.text(details.body, "", "Caption")
		local lineageRow = UiKit.actionRow(details.body, 4, 2, 96)
		lineageRow.Name = "LineageRow"
		lineageRow.BackgroundTransparency = 1
		lineageRow.Size = UDim2.new(1, 0, 0, 0)
		lineageRow.AutomaticSize = Enum.AutomaticSize.Y
		lineageRow.LayoutOrder = 4
		lineageRow.Visible = false
		lineageRow.Parent = details.body
		local lineageButton = UiKit.actionButton(lineageRow, 1, "", "secondary")
		lineageButton.AutomaticSize = Enum.AutomaticSize.Y
		lineageButton.TextSize = UiKit.TextSize.Button
		UiKit.padding(lineageButton, 6, 6)
		lineageButton.LayoutOrder = 1
		-- Satış kartta doğrudan görünür (Ayrıntılar kapalıyken de ulaşılır); alım düğmesinin hemen altındadır.
		local sellButton = UiKit.button(card.frame, "", "secondary")
		sellButton.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
		sellButton.AutomaticSize = Enum.AutomaticSize.Y
		sellButton.TextSize = UiKit.TextSize.Button
		UiKit.padding(sellButton, 6, 6)
		sellButton.LayoutOrder = 5
		sellButton.Visible = false
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
		-- Ürünle satın al: depodaki ürünlerin değeri (GOODS_BARTER.rate) hayvanın fiyatını karşılıyorsa tek hayvan takasla alınır
		local barterButton = UiKit.button(details.body, "", "secondary")
		barterButton.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
		barterButton.AutomaticSize = Enum.AutomaticSize.Y
		barterButton.TextSize = UiKit.TextSize.Button
		UiKit.padding(barterButton, 6, 6)
		barterButton.TextSize = UiKit.TextSize.Button
		barterButton.LayoutOrder = 6
		barterButton.Visible = false
		barterButtons[animalId] = barterButton
		barterButton.Activated:Connect(function()
			if barterButton.Active then
				local state = ClientState.get()
				local count = if state then bulkCount(state, animalId) else 1
				PurchaseController.submit("RequestBarterAnimal", animalId, if count > 1 then count else nil)
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

	local lastContext: string? = nil
	local function updateShop(state: PlayerSave, content: boolean)
		local context =
			`{state.activeMainFarmId}:{IslandContext.get()}:{if state.progression then state.progression.run else 1}`
		if context ~= lastContext then
			for _, details in detailsById do
				details.setExpanded(false)
			end
			lastContext = context
		end
		if content then
			UiKit.setText(shopInfo, "Hayvan al ve çiftliğinin gelirini büyüt.")
		end
		for index, animalId in Config.ANIMAL_ORDER do
			local card = animalCards[animalId]
			local relevant = FarmMath.hasUnlockedAnimalZone(state, animalId)
			card.frame.Visible = relevant
			if not relevant then
				continue
			end
			local animalConfig = Config.getAnimalLook(animalId, state.activeMainFarmId)
			card.icon.Text = animalConfig.icon
			local lineageLevel = FarmMath.getLineageLevel(state, animalId)
			local lineageStatus, _, lineageCost = FarmMath.getLineageStatus(state, animalId)
			local owned = FarmMath.countAnimals(state, animalId) > 0
			lineageRows[animalId].Visible = owned
			sellButtons[animalId].Visible = owned
			local sellBlock = FarmMath.getSellBlockReason(state, animalId)
			if sellBlock then
				setPurchaseButton(sellButtons[animalId], sellBlock, "disabled")
			else
				setPurchaseButton(
					sellButtons[animalId],
					`Sat · {FarmMath.formatMoney(FarmMath.getSellPrice(state, animalId))}`,
					"secondary"
				)
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
					UiKit.setText(card.detail, `Yetişkin +${FarmMath.formatRate(income)}/sn`)
					UiKit.setText(
						fullDetails[animalId],
						`{animalConfig.product} · Yetişkin +${FarmMath.formatRate(income)}/sn{effect}\nHayvanlar yavru doğar, büyüdükçe daha çok kazandırır.\nIrk geliştirme: her seviye o türün gelirini +%{math.round(
							Config.LINEAGE.incomePerLevel * 100
						)} artırır.\nÜrünle al: depodaki ürünler değerinin %{math.round(
							Config.GOODS_BARTER.rate * 100
						)}'i kadar sayılır (ahır deposu).`
					)
				else
					UiKit.setText(card.detail, reason or "")
					UiKit.setText(fullDetails[animalId], reason or "")
				end
			end
			if not zoneId then
				-- Dolu/kilitli: ölü bir düğme yerine kartın sağ üstünde kırmızı yazı
				UiKit.setCardStatus(card, if block == "full" then "Dolu" else "Kilitli")
			else
				UiKit.setCardStatus(card, nil)
				setPurchaseButton(
					card.action,
					if count > 1 then `x{count} · {FarmMath.formatMoney(price)}` else FarmMath.formatMoney(price),
					if state.cash >= price then "primary" else "warning"
				)
			end
			local barterButton = barterButtons[animalId]
			local barterWorth = FarmMath.getGoodsBarterWorth(state)
			local roomForBarter = zoneId ~= nil and FarmMath.getFreeSlots(state, animalId) >= 1
			local barterPrice = if roomForBarter then price else 0
			local barterPlan = if roomForBarter and barterWorth > 0
				then FarmMath.planGoodsBarter(state, barterPrice)
				else nil
			-- Ürünle alım mümkünse düğme hangi ürünlerin gideceğini yazar; ürün yetmiyorsa ölü düğme yerine kartın sağ üstünde kırmızı yazı
			barterButton.Visible = barterPlan ~= nil
			if barterPlan then
				setPurchaseButton(
					barterButton,
					if count > 1
						then `Ürünle al x{count} · {FarmMath.formatGoodsCost(barterPlan)}`
						else `Ürünle al · {FarmMath.formatGoodsCost(barterPlan)}`,
					"primary"
				)
			end
			if roomForBarter and barterWorth > 0 and not barterPlan then
				card.status.Text = "Ürün yetmiyor"
				card.status.Visible = true
			end
		end
		for multiplier, button in multiplierButtons do
			UiKit.setVariant(button, if multiplier == shopMultiplier then "primary" else "secondary")
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

	shopWindow.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not shopWindow.isOpen() then
			for _, details in detailsById do
				details.setExpanded(false)
			end
		end
	end)
	return { window = shopWindow, update = updateShop }
end

return ShopWindow
