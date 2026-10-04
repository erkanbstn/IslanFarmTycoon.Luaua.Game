--!strict
-- Eşya açıklaması: etkiden türetilir (metinler çeviri sözlüğünde şablon olarak durur; sayı `{}` yerine yazılır).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ItemText = {}

local function percent(label: string, value: number): string
	return `{label}: {if value >= 0 then "+" else "-"}%{math.round(math.abs(value) * 100)}`
end

local function points(label: string, value: number): string
	return `{label}: {if value >= 0 then "+" else "-"}{math.round(math.abs(value) * 100)} puan`
end

function ItemText.slotNotice(item: Config.ItemConfig): string
	local slot = Config.ITEM_SLOTS[item.slot]
	return `Yuva: {if slot then slot.displayName else item.slot} · Takılı eşyanın yerine geçer.`
end

function ItemText.describe(item: Config.ItemConfig): string
	local parts: { string } = {}
	local effects = item.effects
	if effects then
		if effects.movementSpeed then
			table.insert(parts, percent("Yürüme ve koşma hızı", effects.movementSpeed))
		end
		if effects.upgradeDiscount then
			table.insert(parts, percent("Yükseltme maliyeti", -effects.upgradeDiscount))
		end
		if effects.expansionDiscount then
			table.insert(parts, percent("Geliştirme maliyeti", -effects.expansionDiscount))
		end
		if effects.storageBonus then
			table.insert(parts, percent("Depo kapasitesi", effects.storageBonus))
		end
		if effects.growthSpeed then
			table.insert(parts, percent("Hayvan büyüme hızı", effects.growthSpeed - 1))
		end
		if effects.incomeBonus then
			table.insert(parts, percent("Bütün gelir", effects.incomeBonus))
		end
		if effects.contractBonus then
			table.insert(parts, percent("Ahır siparişi ödülü", effects.contractBonus))
		end
		if effects.goodsYield then
			table.insert(parts, percent("Ürün merkezi verimi", effects.goodsYield))
		end
		if effects.sellBonus then
			table.insert(parts, percent("Hayvan satış geliri", effects.sellBonus))
		end
		if effects.facilitySpeed then
			table.insert(parts, percent("Üretim süresi", -effects.facilitySpeed))
		end
		if effects.offlineBonus then
			table.insert(parts, points("Çevrimdışı gelir oranı", effects.offlineBonus))
		end
	end
	local tradeoffs = item.tradeoffs
	if tradeoffs then
		if tradeoffs.offlineBonus then
			table.insert(parts, points("Çevrimdışı gelir oranı", -tradeoffs.offlineBonus))
		end
		if tradeoffs.facilitySpeed then
			table.insert(parts, percent("Üretim süresi", tradeoffs.facilitySpeed))
		end
		if tradeoffs.goodsYield then
			table.insert(parts, percent("Ürün merkezi verimi", -tradeoffs.goodsYield))
		end
	end
	local power = item.power
	if power then
		if power.kind == "season" then
			table.insert(
				parts,
				if power.usesPerDay
					then `Günde {power.usesPerDay} kez mevsim değiştir`
					else "Sınırsız mevsim değiştir"
			)
		else
			table.insert(
				parts,
				if power.usesPerDay
					then `Günde {power.usesPerDay} kez hava değiştir`
					else "Sınırsız hava değiştir"
			)
			table.insert(parts, "Sunucudaki herkes etkilenir; normal hava süresi sonunda doğal döngü sürer.")
		end
	end
	if #parts == 0 then
		return "Görünüm eşyası"
	end
	return table.concat(parts, "\n")
end

-- Ana fayda kartta kalır; açılan bölüm yalnızca ek etkileri ve eksileri gösterir.
function ItemText.additional(item: Config.ItemConfig): string
	local description = ItemText.describe(item)
	local splitAt = string.find(description, "\n", 1, true)
	return if splitAt then string.sub(description, splitAt + 1) else ""
end

-- Bir slotun eşyaları, ITEM_ORDER sırasıyla
function ItemText.itemsOfSlot(slotId: string): { Config.ItemConfig }
	local result: { Config.ItemConfig } = {}
	for _, itemId in Config.ITEM_ORDER do
		local item = Config.ITEMS[itemId]
		if item.slot == slotId then
			table.insert(result, item)
		end
	end
	return result
end

return ItemText
