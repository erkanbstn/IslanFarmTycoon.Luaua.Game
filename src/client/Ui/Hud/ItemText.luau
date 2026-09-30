--!strict
-- Eşya açıklaması: etkiden türetilir (metinler çeviri sözlüğünde şablon olarak durur; sayı `{}` yerine yazılır).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ItemText = {}

function ItemText.describe(item: Config.ItemConfig): string
	local effects = item.effects
	if effects then
		if effects.upgradeDiscount then
			return `Yükseltme maliyetleri -%{math.round(effects.upgradeDiscount * 100)}`
		elseif effects.storageBonus then
			return `Depo kapasitesi +%{math.round(effects.storageBonus * 100)}`
		elseif effects.growthSpeed then
			return `Hayvanlar %{math.round((effects.growthSpeed - 1) * 100)} daha hızlı büyür`
		elseif effects.incomeBonus then
			return `Bütün gelir +%{math.round(effects.incomeBonus * 100)}`
		end
	end
	local power = item.power
	if power then
		if power.kind == "season" then
			return if power.usesPerDay
				then `Günde {power.usesPerDay} kez mevsim değiştir`
				else "Sınırsız mevsim değiştir"
		end
		return if power.usesPerDay
			then `Günde {power.usesPerDay} kez hava değiştir`
			else "Sınırsız hava değiştir"
	end
	return "Görünüm eşyası"
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
