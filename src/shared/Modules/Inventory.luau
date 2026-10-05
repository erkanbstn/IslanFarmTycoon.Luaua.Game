--!strict
-- Envanter mantığı (saf, paylaşılan): sahiplik, slotlara takma ve asa gücü hakları. Sunucu karar verir ve kaydeder;
-- client aynı hesapla düğmeleri ve kalan hakkı gösterir. Etkiler FarmMath'te (getEquippedBonus vb.) hesaplanır.
--
-- Kayıt biçimi (hesap düzeyi): inventory = { items = { [itemId] = true }, equipped = { [slot] = itemId },
-- uses = { season|weather = { day, count, last } } }. Günlük haklar güç TÜRÜNE göredir (mevsim/hava), eşyaya değil:
-- daha yüksek kademeli asaya geçmek kullanılmış hakları sıfırlamaz.

local Config = require(script.Parent.Parent:WaitForChild("Config"))

local Inventory = {}

local SECONDS_PER_DAY = 86400

-- UTC gün numarası: yerel saate bağlı değildir (günlük ödülle aynı ölçü).
function Inventory.dayIndex(now: number): number
	return math.floor(now / SECONDS_PER_DAY)
end

local function ensure(save: any): any
	local inventory = save.inventory
	if not inventory then
		inventory = {}
		save.inventory = inventory
	end
	inventory.items = inventory.items or {}
	inventory.equipped = inventory.equipped or {}
	inventory.uses = inventory.uses or {}
	return inventory
end

function Inventory.owns(save: any, itemId: string): boolean
	local inventory = save.inventory
	return inventory ~= nil and inventory.items ~= nil and inventory.items[itemId] == true
end

function Inventory.ownedCount(save: any): number
	local count = 0
	local inventory = save.inventory
	for _ in if inventory and inventory.items then inventory.items else {} do
		count += 1
	end
	return count
end

-- Eşyayı sahiplenir (ödeme çağıranın işidir). Yeni eklendiyse true.
function Inventory.grant(save: any, itemId: string): boolean
	if not Config.ITEMS[itemId] then
		return false
	end
	local inventory = ensure(save)
	if inventory.items[itemId] then
		return false
	end
	inventory.items[itemId] = true
	return true
end

function Inventory.equippedId(save: any, slot: string): string?
	local inventory = save.inventory
	local id = if inventory and inventory.equipped then inventory.equipped[slot] else nil
	if typeof(id) == "string" and Inventory.owns(save, id) then
		return id
	end
	return nil
end

function Inventory.isEquipped(save: any, itemId: string): boolean
	local item = Config.ITEMS[itemId]
	return item ~= nil and Inventory.equippedId(save, item.slot) == itemId
end

-- Eşyayı kendi slotuna takar (slottaki eskisi çıkar).
function Inventory.equip(save: any, itemId: string): (boolean, string?)
	local item = Config.ITEMS[itemId]
	if not item then
		return false, "Bilinmeyen eşya"
	end
	if not Inventory.owns(save, itemId) then
		return false, "Bu eşyaya sahip değilsin"
	end
	ensure(save).equipped[item.slot] = itemId
	return true, nil
end

function Inventory.unequip(save: any, slot: string)
	local inventory = save.inventory
	if inventory and inventory.equipped then
		inventory.equipped[slot] = nil
	end
end

-- Eşyanın kullanılabilir bir gücü var mı (yalnız mevsim/hava asaları; üretim/ticaret asaları yalnız kalıcı etki verir)
function Inventory.hasPower(item: Config.ItemConfig?): boolean
	return item ~= nil and item.power ~= nil
end

-- Günlük hak sayısı (sınırsız asalarda math.huge)
function Inventory.usesPerDay(item: Config.ItemConfig): number
	local power = item.power
	if not power then
		return 0
	end
	return power.usesPerDay or math.huge
end

-- O güç türünün (season/weather) bugünkü kullanım kaydı
local function usage(save: any, kind: string, now: number): { day: number, count: number, last: number }
	local inventory = save.inventory
	local entry = if inventory and inventory.uses then inventory.uses[kind] else nil
	if entry and entry.day == Inventory.dayIndex(now) then
		return entry
	end
	return { day = Inventory.dayIndex(now), count = 0, last = if entry then entry.last else 0 }
end

-- Bugün kalan hak (sınırsız = math.huge); takılı asa yoksa 0
function Inventory.usesLeft(save: any, itemId: string, now: number): number
	local item = Config.ITEMS[itemId]
	if not item or not item.power then
		return 0
	end
	return math.max(0, Inventory.usesPerDay(item) - usage(save, item.power.kind, now).count)
end

-- Gücü şimdi kullanabilir mi? Eşya sahipli, takılı, günlük hak var ve bekleme süresi geçmiş olmalı.
function Inventory.canUse(save: any, itemId: string, now: number): (boolean, string?)
	local item = Config.ITEMS[itemId]
	if not item then
		return false, "Bilinmeyen eşya"
	end
	if not item.power then
		return false, "Bu eşyanın kullanılabilir bir gücü yok"
	end
	if not Inventory.owns(save, itemId) then
		return false, "Bu eşyaya sahip değilsin"
	end
	if not Inventory.isEquipped(save, itemId) then
		return false, "Önce bu eşyayı tak"
	end
	local entry = usage(save, item.power.kind, now)
	if entry.count >= Inventory.usesPerDay(item) then
		return false, "Bugünkü hakkın bitti"
	end
	if now - entry.last < Config.ITEM_USE_COOLDOWN_SECONDS then
		return false, "Asa dinleniyor; biraz bekle"
	end
	return true, nil
end

function Inventory.recordUse(save: any, itemId: string, now: number)
	local item = Config.ITEMS[itemId]
	if not item or not item.power then
		return
	end
	local inventory = ensure(save)
	local entry = usage(save, item.power.kind, now)
	entry.count += 1
	entry.last = now
	inventory.uses[item.power.kind] = entry
end

return Inventory
