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

function Core.getPerkLevel(save: PlayerSave, id: string): number
	local definition = Config.PROGRESSION.perks[id]
	local progression = (save :: any).progression
	local value = if progression and progression.perks then progression.perks[id] else nil
	return if definition
			and typeof(value) == "number"
			and isFinite(value)
		then math.clamp(math.floor(value), 0, definition.maxLevel)
		else 0
end

function Core.getPerkBonus(save: PlayerSave, effect: string): number
	local total = 0
	for id, definition in Config.PROGRESSION.perks do
		local value = (definition.effects :: any)[effect]
		if typeof(value) == "number" then
			total += value * Core.getPerkLevel(save, id)
		end
	end
	return total
end

function Core.getMilestoneBonus(save: PlayerSave, effect: string): number
	local progression = (save :: any).progression
	local count = if progression
			and typeof(progression.count) == "number"
			and isFinite(progression.count)
		then math.clamp(math.floor(progression.count), 0, Config.PROGRESSION.maxRebirth)
		else 0
	local total = 0
	for level = 1, count do
		local milestone = Config.PROGRESSION.milestones[level]
		total += if milestone and milestone.effects then milestone.effects[effect] or 0 else 0
	end
	return total
end

function Core.isReturnActive(save: PlayerSave, now: number?): boolean
	local progression = (save :: any).progression
	return progression ~= nil
		and progression.count > 0
		and progression.returnEnded ~= true
		and (save.farmId or save.activeMainFarmId) == "1"
		and (now or os.time()) >= progression.startedAt
		and (now or os.time()) < progression.returnEndsAt
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
		local owned = (save :: any).owned
		local permanent = owned and owned.items and owned.items[itemId] == true
		local value = if item
				and item.effects
				and (inventory.items[itemId] or permanent)
				and ((item.effects :: any)[key] ~= nil or (item.tradeoffs and item.tradeoffs[key] ~= nil))
			then ((item.effects :: any)[key] or 0) - (if item.tradeoffs then item.tradeoffs[key] or 0 else 0)
			else nil
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

-- Yalnız geçerli yuvada takılı ve sahip olunan eşyalar hız verir; yığılma ulaşımı bozmaz.
function Core.getMovementSpeedMultiplier(save: PlayerSave): number
	local total = 0
	local inventory = save.inventory
	local owned = (save :: any).owned
	if inventory and inventory.equipped then
		for slot, id in inventory.equipped do
			local item = Config.ITEMS[id]
			local permanent = owned and owned.items and owned.items[id] == true
			local hasItem = (inventory.items and inventory.items[id] == true) or permanent
			local bonus = if item and item.effects then item.effects.movementSpeed else nil
			if item and item.slot == slot and hasItem and typeof(bonus) == "number" and isFinite(bonus) then
				total += math.max(0, bonus)
			end
		end
	end
	return 1 + math.clamp(total, 0, Config.MOVEMENT_SPEED_BONUS_CAP)
end

-- Satın alınmış yükseltmelerin aynı anahtarlı faydaları toplamı (ör. ada özellikleri: facilitySpeed, sellBonus...)
function Core.getUpgradeBonus(save: PlayerSave, key: string): number
	local total = 0
	for _, upgrade in Config.UPGRADES do
		if save.purchased[upgrade.id] then
			local value = (upgrade :: any)[key]
			if typeof(value) == "number" and isFinite(value) then
				total += value
			end
		end
	end
	return total
end

-- Takılı eşya + yükseltme faydalarının toplamı (contractBonus, goodsYield, sellBonus, offlineBonus, facilitySpeed, expansionDiscount)
function Core.getBonus(save: PlayerSave, key: string): number
	return Core.getEquippedBonus(save, key)
		+ Core.getUpgradeBonus(save, key)
		+ Core.getPerkBonus(save, key)
		+ Core.getMilestoneBonus(save, key)
end

-- Pasif Gelir: alınmışsa çevrimdışı kazanç doğrudan kasaya yatar; alınmamışsa yalnızca depo birikir (dolunca durur).
function Core.hasOfflineIncome(save: PlayerSave): boolean
	return save.purchased.offline_income_lv1 == true
end

-- Yardımcı (pet): "cash" = para fabrikaları, "goods" = ürün merkezleri; çiftlik başına satın alınır (save.purchased)
function Core.hasPet(save: PlayerSave, kind: string): boolean
	local owned = (save :: any).owned
	return save.purchased[`pet_{kind}_lv1`] == true
		or (owned ~= nil and owned.conveniences ~= nil and owned.conveniences[`pet_{kind}`] == true)
end

-- Çarpılan etki: growthSpeed
function Core.getEquippedMultiplier(save: PlayerSave, key: string): number
	local product = 1
	forEachEquippedEffect(save, key, function(value: number)
		product *= value
	end)
	return product
end

-- Çarpan olarak yazılmış etkinin artısı: (çarpan - 1) toplamı (growthSpeed: 1.15 -> +0.15)
function Core.getEquippedExcess(save: PlayerSave, key: string): number
	local total = 0
	forEachEquippedEffect(save, key, function(value: number)
		total += value - 1
	end)
	return total
end

function Core.hasAutoCollect(save: PlayerSave): boolean
	local owned = (save :: any).owned
	if
		(owned and owned.conveniences and owned.conveniences.auto_collect == true)
		or ((save.farmId or save.activeMainFarmId) == "1" and Core.getPerkLevel(save, "ready_start") >= 1)
	then
		return true
	end
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

-- Bir çiftliğin `earned` gelirinin dağılımı: (kasaya yatan, yeni depo). Toplayıcılı çiftlik her şeyi (depo dahil) kasaya yatırır;
-- toplayıcısız park edilmiş çiftlik gelirin PARKED_FARM_PAY_RATE'ini kasaya yatırır ve deposuna dokunmaz; etkin çiftlik depoyu doldurur.
function Core.settleFarmIncome(farm: PlayerSave, earned: number, parked: boolean): (number, number)
	if Core.hasAutoCollect(farm) then
		return earned + farm.stored, 0
	elseif parked then
		return earned * Config.PARKED_FARM_PAY_RATE, farm.stored
	end
	return 0, math.min(farm.stored + earned, Core.getStorageCap(farm))
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
	bonus += Core.getMilestoneBonus(save, "storageBonus")
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
