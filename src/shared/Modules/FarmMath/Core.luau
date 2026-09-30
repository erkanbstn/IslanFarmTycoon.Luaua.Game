--!strict
-- Temel türetilmiş durum: açık ada/bölgeler, takılı eşya etkileri, yükseltme maliyeti, depo, ahır, evre.
-- FarmMath cephesi (init.luau) bunları birleştirir; her zaman `FarmMath.<ad>` ile kullan.

local Config = require(script.Parent.Parent.Parent:WaitForChild("Config"))
local GameTypes = require(script.Parent.Parent.Parent:WaitForChild("GameTypes"))

type PlayerSave = GameTypes.PlayerSave
type AnimalStage = GameTypes.AnimalStage

local Core = {}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

-- purchased'dan barnLevel, açık adaları ve açık bölgeleri yeniden hesaplar (tek doğruluk kaynağı: purchased).
-- Bir bölge açıktır: adası açıksa VE (bölgeyi açan bir yol haritası öğesi yoksa ya da alınmışsa).
function Core.applyDerived(save: PlayerSave)
	local level = 1
	local islands: { [string]: boolean } = { home = true }
	for _, upgrade in Config.UPGRADES do
		if not save.purchased[upgrade.id] then
			continue
		end
		if upgrade.kind == "barn" and upgrade.barnLevel then
			level = math.max(level, upgrade.barnLevel)
		elseif upgrade.kind == "island" and upgrade.islandId then
			islands[upgrade.islandId] = true
		end
	end

	local zones: { [string]: boolean } = {}
	for zoneId, zone in Config.ZONES do
		if not islands[zone.island] then
			continue
		end
		local zoneUpgrade = Config.getZoneUpgrade(zoneId)
		if zoneUpgrade == nil or save.purchased[zoneUpgrade.id] then
			zones[zoneId] = true
		end
	end

	save.barnLevel = level
	save.unlockedIslands = islands
	save.unlockedZones = zones
end

-- Takılı eşyaların etkileri (envanter): slot başına bir eşya; sahiplik ve slot uyumu kayıtta doğrulanır.
local function forEachEquippedEffect(save: PlayerSave, key: string, apply: (value: number) -> ())
	local inventory = save.inventory
	if not inventory or not inventory.equipped or not inventory.items then
		return
	end
	for _, itemId in inventory.equipped do
		local item = Config.ITEMS[itemId]
		local value = if item and item.effects and inventory.items[itemId] then (item.effects :: any)[key] else nil
		if typeof(value) == "number" and isFinite(value) then
			apply(value)
		end
	end
end

-- Toplanan etkiler: upgradeDiscount, storageBonus, incomeBonus
function Core.getEquippedBonus(save: PlayerSave, key: string): number
	local total = 0
	forEachEquippedEffect(save, key, function(value: number)
		total += value
	end)
	return total
end

-- Çarpılan etki: growthSpeed
function Core.getEquippedMultiplier(save: PlayerSave, key: string): number
	local product = 1
	forEachEquippedEffect(save, key, function(value: number)
		product *= value
	end)
	return product
end

-- Yükseltmenin bu oyuncu için maliyeti: takılı alet indirimi uygulanır (en az 1). Gösterim ve tahsilat aynı işlevi kullanır.
function Core.getUpgradeCost(save: PlayerSave?, upgrade: Config.UpgradeConfig): number
	if not save then
		return upgrade.cost
	end
	local discount = math.clamp(Core.getEquippedBonus(save, "upgradeDiscount"), 0, 0.9)
	if discount <= 0 then
		return upgrade.cost
	end
	return math.max(1, math.floor(upgrade.cost * (1 - discount)))
end

function Core.hasAutoCollect(save: PlayerSave): boolean
	for key, pass in Config.PRODUCTS.passes do
		if pass.autoCollect and save.passes and save.passes[key] then
			return true
		end
	end
	for _, upgrade in Config.UPGRADES do
		if upgrade.autoCollect and save.purchased[upgrade.id] then
			return true
		end
	end
	return false
end

function Core.getStage(bornAt: number, now: number, growthSpeed: number): AnimalStage
	if bornAt == 0 then
		return "adult"
	end
	local age = (now - bornAt) * growthSpeed
	if age < Config.GROWTH_SECONDS.calf then
		return "calf"
	elseif age < Config.GROWTH_SECONDS.calf + Config.GROWTH_SECONDS.young then
		return "young"
	end
	return "adult"
end

function Core.getBarnConfig(save: PlayerSave): Config.BarnLevelConfig
	return Config.getBarnLevelConfig(save.barnLevel) or Config.BARN_LEVELS[1]
end

function Core.getStorageCap(save: PlayerSave): number
	local bonus = 0
	for _, upgrade in Config.UPGRADES do
		if upgrade.storageBonus and save.purchased[upgrade.id] then
			bonus += upgrade.storageBonus
		end
	end
	bonus += Core.getEquippedBonus(save, "storageBonus")
	-- Oyun geçidi: ekstra depo
	for key, pass in Config.PRODUCTS.passes do
		if pass.storageBonus and save.passes and save.passes[key] then
			bonus += pass.storageBonus
		end
	end
	return math.floor(Core.getBarnConfig(save).storageCap * (1 + bonus))
end

-- Depo doluluğu: 0 = boş, 1..5 = para yığını büyüklüğü (dünyadaki yığın görseli bunu kullanır).
function Core.getStorageLevel(stored: number, cap: number): number
	if cap <= 0 or stored < 1 then
		return 0
	end
	local ratio = math.clamp(stored / cap, 0, 1)
	if ratio >= 0.999 then
		return 5
	end
	return math.clamp(math.floor(ratio * 4) + 1, 1, 4)
end

Core.isFinite = isFinite

return Core
