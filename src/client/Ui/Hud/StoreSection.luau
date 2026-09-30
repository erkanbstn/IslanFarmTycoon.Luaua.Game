--!strict
-- Destek Dükkânı içeriği: oyun geçitleri ve ürünler (kimliği 0 olanlar henüz satışta değildir, gizlenir).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))

type PlayerSave = GameTypes.PlayerSave

local Color = UiKit.Color

local StoreSection = {}

-- Listeyi kurar; durum geldikçe çağrılacak güncelleme işlevini döner
function StoreSection.create(list: Instance): (PlayerSave) -> ()
	local STORE_ORDER = 90
	local storeHeader = UiKit.sectionHeader(list, "Destek paketleri", STORE_ORDER)
	type StoreEntry = { kind: string, key: string, product: Config.ProductConfig, card: UiKit.Card, shown: string }
	local storeEntries: { StoreEntry } = {}
	local storeEmpty = UiKit.text(list, "Dükkân çok yakında açılıyor.", "Caption", Color.TextMuted)
	storeEmpty.LayoutOrder = STORE_ORDER - 1
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
			local card = UiKit.card(list, STORE_ORDER + #storeEntries + 1, product.icon)
			card.title.Text = product.displayName
			card.detail.Text = product.description
			card.action.Activated:Connect(function()
				if card.action.Active then
					Remotes.get("RequestPromptProduct"):FireServer(group.kind, key)
				end
			end)
			table.insert(storeEntries, { kind = group.kind, key = key, product = product, card = card, shown = "" })
		end
	end

	local function updateStore(state: PlayerSave)
		local any = false
		for _, entry in storeEntries do
			local forSale = entry.product.id ~= 0
			local owned = entry.kind == "pass" and state.passes ~= nil and state.passes[entry.key] == true
			local signature = `{forSale}{owned}`
			any = any or forSale
			if signature == entry.shown then
				continue
			end
			entry.shown = signature
			entry.card.frame.Visible = forSale
			entry.card.action.Text = if owned then "Sahipsin" else "Satın al"
			UiKit.setVariant(entry.card.action, if owned then "owned" else "primary")
		end
		(storeHeader.Parent :: GuiObject).Visible = any
		storeEmpty.Visible = not any
	end
	return updateStore
end

return StoreSection
