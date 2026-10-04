--!strict
-- Market kataloğu; kimliği hazır olmayan ürünler görünür, ücretli satın alma kapalı kalır.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Progression = require(Shared:WaitForChild("Modules"):WaitForChild("Progression"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local ItemPreview = require(script.Parent:WaitForChild("ItemPreview"))
local ItemText = require(script.Parent:WaitForChild("ItemText"))
local PurchaseController = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))
local ProductPrices = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("ProductPrices"))
local HudCommon = require(script.Parent:WaitForChild("HudCommon"))
type PlayerSave = GameTypes.PlayerSave
local StoreSection = {}
local CONVENIENCE_BENEFITS: { [string]: string } = {
	auto_collect = "Parayı otomatik toplar",
	pet_cash = "Para partilerini teslim alır",
	pet_goods = "Ürün partilerini teslim alır",
}

local function categoryFor(kind: string, product: Config.ProductConfig): string
	if product.effect == "goldPack" then
		return "gold"
	elseif product.effect == "incomePack" then
		return "cash"
	elseif kind == "pass" or product.lifetime == "permanent" or product.effect == "permanentOffer" then
		return "permanent"
	end
	return "run"
end

function StoreSection.create(list: GuiObject, category: string?): ((PlayerSave) -> (), () -> ())
	local selected = category or "featured"
	if selected == "featured" then
		UiKit.text(list, "Kendi oyun tarzını seç: üretim, ticaret, depolama veya çevrimdışı ilerleme.", "Body").LayoutOrder =
			1
	elseif selected == "permanent" then
		UiKit.text(list, "Kalıcı sahiplik rebirth'te korunur. Eşyaları Envanter'den takabilirsin.", "Body").LayoutOrder =
			1
	elseif selected == "gold" then
		UiKit.text(
			list,
			"Altın satın almak günlük ve tur başına paraya çevirme sınırlarını artırmaz.",
			"Body"
		).LayoutOrder =
			1
	elseif selected == "cash" then
		UiKit.text(list, "Para paketi gelirinle büyür. Oyun parası rebirth'te sıfırlanır.", "Body").LayoutOrder =
			1
	end
	local grid = UiKit.autoGrid(list, 2, 2)
	type Entry = {
		kind: string,
		key: string,
		product: Config.ProductConfig,
		card: UiKit.Card,
		goldButton: TextButton?,
		details: any,
		detailsLabel: TextLabel,
	}
	local entries: { Entry } = {}
	local current: PlayerSave? = nil
	local updateEntry: (Entry, PlayerSave) -> ()
	local featured: { [string]: boolean } = {
		gold_100 = true,
		income_pack_small = true,
		permanent_artisan_staff = true,
		permanent_night_charm = true,
		permanent_merchant_hat = true,
		run_double_income = true,
	}
	for _, group in
		{ { kind = "pass", items = Config.PRODUCTS.passes }, { kind = "product", items = Config.PRODUCTS.products } }
	do
		local keys: { string } = {}
		for key, product in group.items do
			if (selected == "featured" and featured[key]) or selected == categoryFor(group.kind, product) then
				table.insert(keys, key)
			end
		end
		table.sort(keys)
		for _, key in keys do
			local product = group.items[key]
			local entry: Entry
			local card = UiKit.autoTile(grid, #entries + 1, product.icon)
			card.frame.Name = key
			card.icon.Size = UDim2.new(1, 0, 0, 72)
			UiKit.setText(card.title, product.displayName)
			local offer = if product.offerId then Config.PROGRESSION.permanentOffers[product.offerId] else nil
			if offer and offer.itemId then
				ItemPreview.mount(card.icon, offer.itemId)
			end
			local details = UiKit.disclosure(card.frame, 6, "Ayrıntılar")
			local detailsLabel = UiKit.text(details.body, "", "Caption")
			detailsLabel.LayoutOrder = 1
			if offer then
				card.action.Parent = details.body
				card.action.LayoutOrder = 2
			end
			details.body:GetPropertyChangedSignal("Visible"):Connect(function()
				if current then
					updateEntry(entry, current)
				end
			end)
			card.action.Activated:Connect(function()
				if card.action.Active and product.id ~= 0 then
					if not details.isExpanded() then
						details.setExpanded(true)
						return
					end
					Remotes.get("RequestPromptProduct"):FireServer(group.kind, key)
				end
			end)
			local goldButton: TextButton? = nil
			if offer then
				local button = UiKit.button(card.frame, "", "disabled")
				button.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
				button.LayoutOrder = 5
				button.Activated:Connect(function()
					if button.Active then
						if not details.isExpanded() then
							details.setExpanded(true)
							return
						end
						PurchaseController.submitWithRun("RequestGoldAction", "buy", { offerId = product.offerId })
					end
				end)
				goldButton = button
			end
			entry = {
				kind = group.kind,
				key = key,
				product = product,
				card = card,
				goldButton = goldButton,
				details = details,
				detailsLabel = detailsLabel,
			}
			table.insert(entries, entry)
		end
	end
	local function resetDetails()
		for _, entry in entries do
			entry.details.setExpanded(false)
		end
	end
	list:GetPropertyChangedSignal("Visible"):Connect(function()
		if not (list :: GuiObject).Visible then
			resetDetails()
		end
	end)
	local lastContext: string? = nil
	updateEntry = function(entry: Entry, state: PlayerSave)
		local product = entry.product
		local offer = if product.offerId then Config.PROGRESSION.permanentOffers[product.offerId] else nil
		local owned = entry.kind == "pass" and state.passes ~= nil and state.passes[entry.key] == true
		if offer and state.owned then
			owned = owned
				or (
					if offer.kind == "item"
						then state.owned.items[offer.itemId or offer.id] == true
						else state.owned.conveniences[offer.id] == true
				)
		end
		if (offer and offer.id == "auto_collect") or entry.key == "auto_collector" then
			owned = owned
				or (state.passes ~= nil and state.passes.auto_collector == true)
				or (state.owned ~= nil and state.owned.conveniences.auto_collect == true)
		end
		local blocked = Players.LocalPlayer:GetAttribute("DataStatus") ~= "Active"
			or Players.LocalPlayer:GetAttribute("AccountTransactionPending") == true
			or PurchaseController.isPending()
		local detail = product.description
		local cashAmount: number? = nil
		local label = if owned
			then "Kalıcı olarak sahipsin"
			elseif product.id == 0 then "Robux · Yakında"
			else "Robux ile al"
		if product.effect == "goldPack" then
			detail =
				"Altını kalıcı eşyalarda veya hızlı bitirmede kullanabilirsin. Paraya çevirme sınırlarını artırmaz."
		elseif product.effect == "incomePack" then
			local amount = math.floor(
				math.max(
					FarmMath.getPermanentReferenceIncome(state) * 3600 * (product.incomeHours or 1),
					Config.PRODUCT_MIN_INCOME_PACK
				)
			)
			cashAmount = amount
			detail =
				"Paket tutarı en yüksek kalıcı çiftlik gelirine göre hesaplanır; geçici bonuslar dahil değildir."
		elseif product.effect == "runDouble" then
			local active = state.progression ~= nil and state.progression.runDouble
			local hasPass = state.passes ~= nil and state.passes.double_income == true
			local ready = Progression.canRebirth(state)
			owned = active or hasPass
			blocked = blocked or ready
			label = if active
				then "Bu tur 2x açık"
				elseif hasPass then "Kalıcı 2x gelirin var"
				elseif ready then "Yeni turda alınabilir"
				else label
			detail = "Yalnız bu tur: rebirth'te sona erer ve sonraki turda yeniden alınır."
		elseif entry.key == "double_income" and state.progression and state.progression.runDouble then
			detail = "Bu turdaki 2x ile çarpılmaz. Rebirth sonrasında da 2x gelir sağlar."
		elseif offer then
			local item = if offer.itemId then Config.ITEMS[offer.itemId] else nil
			detail = if item
				then `{ItemText.slotNotice(item)}\n{ItemText.additional(item)}\nNakit alternatif: {FarmMath.formatMoney(
					item.price
				)} · Bu tur`
				else if offer.id == "pet_cash" or offer.id == "pet_goods"
					then "Otomatik tekrar açıksa yeni parti başlatır. Hayvan ve depo koşulları yine gerekir."
					else "Bütün açık çiftliklerinde çalışır. Kalıcı sahiplik rebirth'te korunur."
		elseif entry.kind == "pass" then
			detail = if entry.key == "double_income"
				then "Her turda geçerlidir. Bu tur için alınan 2x ile çarpılmaz."
				else "Rebirth'te korunur ve sonraki turlarda da çalışır."
		elseif product.effect == "instantGrowth" then
			detail = `Tek kullanım · {product.description}`
		else
			detail = `Bu tur · {product.description}`
		end
		local item = if offer and offer.itemId then Config.ITEMS[offer.itemId] else nil
		UiKit.setText(entry.detailsLabel, detail)
		local summary = if item
			then `Kalıcı · {string.match(ItemText.describe(item), "[^\n]+") or ""}`
			elseif offer then `Kalıcı · {CONVENIENCE_BENEFITS[offer.id] or product.description}`
			elseif product.effect == "incomePack" then `{FarmMath.formatMoney(cashAmount or 0)} · Bu tur`
			elseif product.effect == "runDouble" then "Bu tur · 2x gelir"
			elseif product.effect == "instantGrowth" then "Tek kullanım"
			elseif product.effect == "goldPack" then `{product.goldAmount or 0} altın · Rebirth'te kalır`
			elseif entry.kind == "pass" then product.description
			else string.match(detail, "[^\n]+") or detail
		UiKit.setText(entry.card.detail, summary)
		local price: number? = nil
		local priceStatus: ProductPrices.Status = "loading"
		if not owned and product.id ~= 0 and list.Visible ~= false then
			price, priceStatus = ProductPrices.get(entry.kind, product.id)
		end
		local paidLabel = if priceStatus == "ready"
			then `{if entry.details.isExpanded() then "Satın al" else "İncele"} · {price or 0} Robux`
			elseif priceStatus == "unavailable" then "Satışta değil"
			elseif priceStatus == "failed" then "Fiyatı Roblox'ta gör"
			else "Fiyat yükleniyor"
		UiKit.setText(entry.card.action, if label == "Robux ile al" then paidLabel else label)
		UiKit.setVariant(
			entry.card.action,
			if owned
				then "owned"
				elseif
					blocked
					or product.id == 0
					or priceStatus == "loading"
					or priceStatus == "unavailable"
				then "disabled"
				else "primary"
		)
		if offer and entry.goldButton then
			HudCommon.setPurchaseButton(
				entry.goldButton,
				if owned
					then "Kalıcı olarak sahipsin"
					else `{if entry.details.isExpanded() then "Satın al" else "İncele"} · {offer.goldCost} altın · Kalıcı`,
				if owned
					then "owned"
					elseif blocked then "disabled"
					elseif (state.gold or 0) >= offer.goldCost then "primary"
					else "warning"
			)
		end
	end
	local pricesConnection = ProductPrices.Changed:Connect(function(kind: string, id: number)
		if current and list.Visible ~= false then
			for _, entry in entries do
				if entry.kind == kind and entry.product.id == id then
					updateEntry(entry, current)
				end
			end
		end
	end)
	list.Destroying:Connect(function()
		pricesConnection:Disconnect()
		current = nil
	end)
	local function update(state: PlayerSave)
		current = state
		local context = `{state.activeMainFarmId}:{if state.progression then state.progression.run else 1}`
		if context ~= lastContext then
			lastContext = context
			for _, entry in entries do
				entry.details.setExpanded(false)
			end
			lastContext = context
		end
		for _, entry in entries do
			updateEntry(entry, state)
		end
	end
	return update, resetDetails
end
return StoreSection
