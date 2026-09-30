--!strict
-- Eşya açıklaması: etkiden türetilir (metinler çeviri sözlüğünde şablon olarak durur; sayı `{}` yerine yazılır).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ItemText = {}

function ItemText.describe(item: Config.ItemConfig): string
	local parts: { string } = {}
	local effects = item.effects
	if effects then
		if effects.upgradeDiscount then
			table.insert(parts, `Yükseltme maliyetleri -%{math.round(effects.upgradeDiscount * 100)}`)
		end
		if effects.expansionDiscount then
			table.insert(parts, `Geliştirme maliyetleri -%{math.round(effects.expansionDiscount * 100)}`)
		end
		if effects.storageBonus then
			table.insert(parts, `Depo kapasitesi +%{math.round(effects.storageBonus * 100)}`)
		end
		if effects.growthSpeed then
			table.insert(parts, `Hayvanlar %{math.round((effects.growthSpeed - 1) * 100)} daha hızlı büyür`)
		end
		if effects.incomeBonus then
			table.insert(parts, `Bütün gelir +%{math.round(effects.incomeBonus * 100)}`)
		end
		if effects.contractBonus then
			table.insert(parts, `Ahır siparişi ödülü +%{math.round(effects.contractBonus * 100)}`)
		end
		if effects.goodsYield then
			table.insert(parts, `Ürün merkezi verimi +%{math.round(effects.goodsYield * 100)}`)
		end
		if effects.sellBonus then
			table.insert(parts, `Hayvan satış geliri +%{math.round(effects.sellBonus * 100)}`)
		end
		if effects.facilitySpeed then
			table.insert(parts, `Üretim tesisleri %{math.round(effects.facilitySpeed * 100)} daha hızlı`)
		end
		if effects.offlineBonus then
			table.insert(parts, `Çevrimdışı kazanç +%{math.round(effects.offlineBonus * 100)}`)
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
		end
	end
	if #parts == 0 then
		return "Görünüm eşyası"
	end
	return table.concat(parts, "\n")
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
