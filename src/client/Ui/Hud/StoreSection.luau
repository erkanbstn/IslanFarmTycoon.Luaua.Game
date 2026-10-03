--!strict
-- Destek Dükkânı içeriği: oyun geçitleri ve ürünler (kimliği 0 olanlar henüz satışta değildir, gizlenir).

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
local PurchaseController = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))

type PlayerSave = GameTypes.PlayerSave

local Color = UiKit.Color

local StoreSection = {}

-- Satışta ürün var mı (Config/Shop'ta kimliği 0 olmayan en az bir geçit ya da ürün). Yoksa dükkân karosu çıkmaz, güncelleme çalışmaz.
function StoreSection.isForSale(): boolean
	for _, group in { Config.PRODUCTS.passes, Config.PRODUCTS.products } do
		for _, product in group do
			if product.id ~= 0 then
				return true
			end
		end
	end
	return false
end

-- Listeyi kurar; durum geldikçe çağrılacak güncelleme işlevini döner
function StoreSection.create(list: Instance): (PlayerSave) -> ()
	local STORE_ORDER = 90
	local storeHeader = UiKit.sectionHeader(list, "Robux Marketi", STORE_ORDER)
	UiKit.text(
		list,
		"Robux fiyatı satın alma penceresinde gösterilir. Altın ve kalıcı teklifleri oyun ilerlemesiyle de kazanabilirsin.",
		"Caption"
	).LayoutOrder = STORE_ORDER
		+ 1
	type StoreEntry = { kind: string, key: string, product: Config.ProductConfig, card: UiKit.Card, category: string }
	local storeEntries: { StoreEntry } = {}
	local storeEmpty = UiKit.text(list, "Dükkân çok yakında açılıyor.", "Caption", Color.TextMuted)
	storeEmpty.LayoutOrder = STORE_ORDER - 1
	local grids: { [string]: Frame } = {}
	for _, category in { "gold", "cash", "run", "permanent" } do
		local grid = UiKit.autoGrid(list, STORE_ORDER + 3, 2)
		grid.Visible = category == "gold"
		grids[category] = grid
	end
	local _, selectTab = UiKit.tabs(list, STORE_ORDER + 2, {
		{ id = "gold", label = "Altın" },
		{ id = "cash", label = "Para" },
		{ id = "run", label = "Bu Tur" },
		{ id = "permanent", label = "Kalıcı" },
	}, function(id: string)
		for category, grid in grids do
			grid.Visible = category == id
		end
	end)
	for _, group in
		{ { kind = "pass", items = Config.PRODUCTS.passes }, { kind = "product", items = Config.PRODUCTS.products } }
	do
		local keys: { string } = {}
		for key in group.items do
			table.insert(keys, key)
		end
		table.sort(keys)
		for _, key in keys do
			local product = group.items[key]
			local category = if product.effect == "goldPack"
				then "gold"
				elseif product.effect == "incomePack" then "cash"
				elseif
					group.kind == "pass"
					or product.lifetime == "permanent"
					or product.effect == "permanentOffer"
				then "permanent"
				else "run"
			local card = UiKit.autoTile(grids[category], #storeEntries + 1, product.icon)
			card.title.Text = product.displayName
			card.detail.Text = product.description
			local offer = if product.offerId then Config.PROGRESSION.permanentOffers[product.offerId] else nil
			if offer and offer.itemId then
				ItemPreview.mount(card.icon, offer.itemId)
			end
			card.action.Activated:Connect(function()
				if card.action.Active then
					Remotes.get("RequestPromptProduct"):FireServer(group.kind, key)
				end
			end)
			table.insert(
				storeEntries,
				{ kind = group.kind, key = key, product = product, card = card, category = category }
			)
		end
	end
	-- Mevcut geçitler tek başına satışa açıldığında boş Altın sekmesiyle karşılaşılmaz.
	for _, category in { "gold", "cash", "run", "permanent" } do
		local available = false
		for _, entry in storeEntries do
			available = available or (entry.category == category and entry.product.id ~= 0)
		end
		if available then
			selectTab(category)
			for id, grid in grids do
				grid.Visible = id == category
			end
			break
		end
	end

	local function updateStore(state: PlayerSave)
		local any = false
		for _, entry in storeEntries do
			local forSale = entry.product.id ~= 0
			local owned = entry.kind == "pass" and state.passes ~= nil and state.passes[entry.key] == true
			local product = entry.product
			local offer = if product.offerId then Config.PROGRESSION.permanentOffers[product.offerId] else nil
			if offer and state.owned then
				owned = owned
					or (
						if offer.kind == "item"
							then state.owned.items[offer.itemId or offer.id] == true
							else state.owned.conveniences[offer.id] == true
					)
			end
			local blocked = Players.LocalPlayer:GetAttribute("DataStatus") ~= "Active" or PurchaseController.isPending()
			local text = if owned then "Kalıcı olarak sahipsin" else "Robux ile al"
			local detail = product.description
			if product.effect == "goldPack" then
				detail = `{product.goldAmount or 0} altın · Rebirth'te kalır`
			elseif product.effect == "incomePack" then
				local amount = math.floor(
					math.max(
						FarmMath.getPermanentReferenceIncome(state) * 3600 * (product.incomeHours or 1),
						Config.PRODUCT_MIN_INCOME_PACK
					)
				)
				detail =
					`{FarmMath.formatMoney(amount)} · Kalıcı referans gelire göre; geçici bonuslar dahil değildir.`
			elseif product.effect == "runDouble" then
				local active = state.progression ~= nil and state.progression.runDouble
				local hasPass = state.passes ~= nil and state.passes.double_income == true
				local ready = Progression.canRebirth(state)
				owned = active or hasPass
				blocked = blocked or ready
				text = if active
					then "Bu tur 2x açık"
					elseif hasPass then "Kalıcı 2x geçidin var"
					elseif ready then "Yeni turda alınabilir"
					else "Robux ile al · Bu tur"
				detail = if ready
					then "Rebirth hazır. Bu ürün sıfırlamada sona erer; yeni turda alabilirsin."
					else "Yalnız bu tur: rebirth'te sona erer ve sonraki turda yeniden alınır."
			elseif product.effect == "permanentOffer" then
				detail = `Kalıcı · {product.description}\nTekrar teslim edilen kalıcı hak altına çevrilir.`
			elseif entry.category == "run" then
				detail = `Bu tur · {product.description}`
			elseif entry.kind == "pass" then
				detail = `Kalıcı geçit · {product.description}`
			end
			any = any or forSale
			entry.card.frame.Visible = forSale
			UiKit.setText(entry.card.detail, detail)
			UiKit.setText(entry.card.action, text)
			UiKit.setVariant(
				entry.card.action,
				if owned then "owned" elseif blocked or not forSale then "disabled" else "primary"
			)
		end
		(storeHeader.Parent :: GuiObject).Visible = any
		storeEmpty.Visible = not any
	end
	return updateStore
end

return StoreSection
