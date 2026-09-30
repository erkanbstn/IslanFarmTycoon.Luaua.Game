--!strict
-- Envanter: eşya tanımlarının tutarlılığı, sahiplik/takma/asa hakları ve takılı eşyaların FarmMath etkileri (saf, gerçek Config).
return function(Inventory: any, Config: any, FarmMath: any, SaveCodec: any, SessionLock: any, FarmProfiles: any)
	-- ------------------------------------------------------------ Tanımlar
	local seen: { [string]: boolean } = {}
	for _, itemId in Config.ITEM_ORDER do
		local item = Config.ITEMS[itemId]
		assert(item and item.id == itemId and not seen[itemId], `ITEM_ORDER entry {itemId} must be unique and defined`)
		seen[itemId] = true
		assert(Config.ITEM_SLOTS[item.slot], `item {itemId} uses unknown slot {item.slot}`)
		assert(item.price > 0 and item.displayName ~= "" and item.icon ~= "", `item {itemId} is malformed`)
		local effectCount = 0
		for _ in item.effects or {} do
			effectCount += 1
		end
		if item.slot == "staff" then
			assert(
				item.power and (item.power.kind == "season" or item.power.kind == "weather"),
				`staff {itemId} needs a power`
			)
			assert(effectCount >= 1, `staff {itemId} also needs a passive effect`)
		elseif item.slot == "tool" or item.slot == "charm" then
			-- Tek bir fayda yerine birkaç farklı fayda: eşyalar sadece "aynı şeyin artırılmışı" olmasın
			assert(item.power == nil and effectCount >= 2, `{item.slot} {itemId} needs at least two different effects`)
		else
			assert(item.power == nil and effectCount == 0, `cosmetic {itemId} must not carry effects`)
		end
		assert(item.look and #item.look.parts > 0, `item {itemId} needs a visible look`)
		assert(
			table.find({ "head", "back", "hip", "chest", "hand" }, item.look.attach),
			`item {itemId} has an unknown attach point`
		)
		for _, part in item.look.parts do
			assert(#part.size == 3 and #part.offset == 3, `item {itemId} has a malformed part`)
		end
	end
	for itemId in Config.ITEMS do
		assert(seen[itemId], `item {itemId} is missing from ITEM_ORDER`)
	end
	for _, slotId in Config.ITEM_SLOT_ORDER do
		assert(Config.ITEM_SLOTS[slotId], `ITEM_SLOT_ORDER lists unknown slot {slotId}`)
	end
	-- Aileler: fiyat arttıkça fayda da artar (aksi halde ucuz kademe pahalıyı gereksiz kılar)
	local function family(filter: (any) -> number?): { { price: number, value: number } }
		local list = {}
		for _, itemId in Config.ITEM_ORDER do
			local item = Config.ITEMS[itemId]
			local value = filter(item)
			if value then
				table.insert(list, { price = item.price, value = value })
			end
		end
		table.sort(list, function(a, b)
			return a.price < b.price
		end)
		return list
	end
	local families = {
		family(function(item)
			return item.effects and item.effects.upgradeDiscount
		end),
		family(function(item)
			return item.effects and item.effects.storageBonus
		end),
		family(function(item)
			return item.effects and item.effects.growthSpeed
		end),
		family(function(item)
			return item.effects and item.effects.incomeBonus
		end),
		family(function(item)
			return if item.power and item.power.kind == "season" then item.power.usesPerDay or 1000 else nil
		end),
		family(function(item)
			return if item.power and item.power.kind == "weather" then item.power.usesPerDay or 1000 else nil
		end),
	}
	for index, list in families do
		assert(#list >= 2, `family {index} needs several tiers`)
		for position = 2, #list do
			assert(list[position].value > list[position - 1].value, `family {index}: pricier tiers must be stronger`)
		end
	end

	-- ------------------------------------------------------------ Envanter işlemleri
	local function newSave(): any
		local data: any = {
			cash = 0,
			stored = 0,
			purchased = {},
			animals = {},
			barnLevel = 1,
			unlockedIslands = {},
			unlockedZones = {},
			production = {},
			activeMainFarmId = "1",
		}
		FarmMath.applyDerived(data)
		return data
	end
	local save = newSave()
	assert(not Inventory.owns(save, "copper_hammer") and Inventory.ownedCount(save) == 0, "a new account owns nothing")
	assert(not Inventory.grant(save, "no_such_item"), "unknown items cannot be granted")
	assert(
		Inventory.grant(save, "copper_hammer") and not Inventory.grant(save, "copper_hammer"),
		"granting twice is a no-op"
	)
	assert(not Inventory.equip(save, "iron_hammer"), "unowned items cannot be equipped")
	assert(
		Inventory.equip(save, "copper_hammer") and Inventory.isEquipped(save, "copper_hammer"),
		"owned items can be equipped"
	)
	Inventory.grant(save, "iron_hammer")
	Inventory.equip(save, "iron_hammer")
	assert(
		Inventory.equippedId(save, "tool") == "iron_hammer" and not Inventory.isEquipped(save, "copper_hammer"),
		"a slot holds one item: equipping replaces the previous one"
	)
	Inventory.unequip(save, "tool")
	assert(Inventory.equippedId(save, "tool") == nil, "unequipping empties the slot")
	-- Bozuk kayıt: sahip olunmayan eşya takılı görünse de sayılmaz
	save.inventory.equipped.tool = "diamond_hammer"
	assert(Inventory.equippedId(save, "tool") == nil, "an equipped but unowned item is ignored")
	save.inventory.equipped.tool = nil

	-- ------------------------------------------------------------ Asa hakları
	local day = Inventory.dayIndex(0)
	local t0 = 100 * 86400 + 10
	Inventory.grant(save, "season_staff_3")
	assert(not Inventory.canUse(save, "season_staff_3", t0), "an unequipped staff cannot be used")
	Inventory.equip(save, "season_staff_3")
	assert(Inventory.usesLeft(save, "season_staff_3", t0) == 3, "a fresh day gives every use")
	assert(Inventory.canUse(save, "season_staff_3", t0), "an equipped staff can be used")
	Inventory.recordUse(save, "season_staff_3", t0)
	assert(not Inventory.canUse(save, "season_staff_3", t0 + 1), "the cooldown blocks immediate reuse")
	assert(
		Inventory.canUse(save, "season_staff_3", t0 + Config.ITEM_USE_COOLDOWN_SECONDS),
		"the staff is ready after the cooldown"
	)
	Inventory.recordUse(save, "season_staff_3", t0 + 100)
	Inventory.recordUse(save, "season_staff_3", t0 + 200)
	assert(Inventory.usesLeft(save, "season_staff_3", t0 + 300) == 0, "three uses exhaust a three-use staff")
	assert(not Inventory.canUse(save, "season_staff_3", t0 + 300), "no uses left today")
	assert(Inventory.canUse(save, "season_staff_3", t0 + 86400), "a new UTC day restores the uses")
	-- Haklar güç türüne göredir: daha yüksek kademeye geçmek kullanılmış hakları sıfırlamaz
	Inventory.grant(save, "season_staff_inf")
	Inventory.grant(save, "season_staff_1")
	Inventory.equip(save, "season_staff_1")
	assert(
		Inventory.usesLeft(save, "season_staff_1", t0 + 300) == 0,
		"used uses carry over to a different staff of the same kind"
	)
	-- Hava hakkı mevsim hakkından ayrı
	Inventory.grant(save, "weather_staff_1")
	Inventory.equip(save, "weather_staff_1")
	assert(Inventory.canUse(save, "weather_staff_1", t0 + 300), "weather uses are separate from season uses")
	-- Sınırsız asa: günlük sınır yok, yalnızca bekleme
	Inventory.equip(save, "season_staff_inf")
	assert(Inventory.usesLeft(save, "season_staff_inf", t0 + 300) == math.huge, "unlimited staffs never run out")
	assert(
		Inventory.canUse(save, "season_staff_inf", t0 + 300 + Config.ITEM_USE_COOLDOWN_SECONDS),
		"unlimited staffs obey only the cooldown"
	)
	assert(day == 0, "day index is UTC based")

	-- ------------------------------------------------------------ FarmMath etkileri
	local function effects(itemId: string): any
		local farm = newSave()
		Inventory.grant(farm, itemId)
		Inventory.equip(farm, itemId)
		return farm
	end
	local plain = newSave()
	local upgrade = Config.getUpgrade("barn_2")
	assert(FarmMath.getUpgradeCost(plain, upgrade) == upgrade.cost, "no tool, no discount")
	local hammer = effects("iron_hammer")
	assert(
		FarmMath.getUpgradeCost(hammer, upgrade) == math.floor(upgrade.cost * 0.9),
		"an iron hammer takes 10% off every upgrade"
	)
	local unequipped = newSave()
	Inventory.grant(unequipped, "iron_hammer")
	assert(FarmMath.getUpgradeCost(unequipped, upgrade) == upgrade.cost, "owned but unequipped items do nothing")
	local storage = effects("storage_charm_2")
	assert(
		FarmMath.getStorageCap(storage) > FarmMath.getStorageCap(plain)
			and math.abs(FarmMath.getStorageCap(storage) / FarmMath.getStorageCap(plain) - 1.35) < 0.01,
		"a storage charm raises the storage cap"
	)
	local growth = effects("growth_charm_2")
	assert(
		math.abs(FarmMath.getGrowthSpeed(growth, "cow") / FarmMath.getGrowthSpeed(plain, "cow") - 1.4) < 1e-9,
		"a growth charm speeds growth up"
	)
	local income = effects("income_charm_2")
	assert(
		math.abs(
			FarmMath.getAnimalMultiplier(income, "cow", true) / FarmMath.getAnimalMultiplier(plain, "cow", true) - 1.06
		) < 1e-9,
		"an income charm adds to every animal's income"
	)
	local cosmetic = effects("golden_crown")
	assert(
		FarmMath.getUpgradeCost(cosmetic, upgrade) == upgrade.cost
			and FarmMath.getStorageCap(cosmetic) == FarmMath.getStorageCap(plain),
		"cosmetics never change the economy"
	)
	-- Bozuk kayıt: sahip olunmayan takılı eşya etki etmez
	local forged = newSave()
	forged.inventory = { items = {}, equipped = { tool = "diamond_hammer" }, uses = {} }
	assert(FarmMath.getUpgradeCost(forged, upgrade) == upgrade.cost, "an unowned equipped item has no effect")

	-- ------------------------------------------------------------ Kayıt
	local counter = 0
	local uid = function()
		counter += 1
		return `u{counter}`
	end
	local now = 1000000
	local account = assert(SaveCodec.decode(nil, Config, FarmMath, now, uid))
	assert(account.inventory and next(account.inventory.items) == nil, "a new account starts with an empty inventory")
	Inventory.grant(account, "gold_hammer")
	Inventory.grant(account, "season_staff_5")
	Inventory.grant(account, "red_cape")
	Inventory.equip(account, "gold_hammer")
	Inventory.equip(account, "season_staff_5")
	Inventory.recordUse(account, "season_staff_5", now)
	local raw = SaveCodec.encode(account, now)
	local loaded = assert(SaveCodec.decode(raw, Config, FarmMath, now, uid))
	assert(
		Inventory.owns(loaded, "gold_hammer")
			and Inventory.owns(loaded, "red_cape")
			and Inventory.isEquipped(loaded, "season_staff_5")
			and Inventory.usesLeft(loaded, "season_staff_5", now) == 4,
		"inventory survives a save"
	)
	raw.inventory.items = { "gold_hammer", "ghost_item", 7 }
	raw.inventory.equipped = { tool = "gold_hammer", staff = "season_staff_5", head = "gold_hammer", back = "red_cape" }
	raw.inventory.uses = { season = { day = 5, count = 1e9, last = 0 }, hack = { day = 1, count = 1, last = 1 } }
	local cleaned = assert(SaveCodec.decode(raw, Config, FarmMath, now, uid))
	assert(
		Inventory.owns(cleaned, "gold_hammer") and not Inventory.owns(cleaned, "ghost_item"),
		"unknown items are dropped"
	)
	assert(Inventory.equippedId(cleaned, "tool") == "gold_hammer", "a valid equipped item is kept")
	assert(
		Inventory.equippedId(cleaned, "staff") == nil and Inventory.equippedId(cleaned, "back") == nil,
		"equipped items must be owned"
	)
	assert(Inventory.equippedId(cleaned, "head") == nil, "an item in the wrong slot is dropped")
	assert(
		cleaned.inventory.uses.season.count == 1000 and cleaned.inventory.uses.hack == nil,
		"use records are clamped and validated"
	)
	raw.inventory = "broken"
	local fallback = assert(SaveCodec.decode(raw, Config, FarmMath, now, uid))
	assert(next(fallback.inventory.items) == nil, "a corrupt inventory falls back to empty")
	-- Etkin olmayan çiftlik görünümü de envanteri taşır (gelir/depo etkileri her çiftlikte geçerli)
	local data: any = account
	FarmProfiles.capture(data)
	local view = FarmProfiles.view(data, "1")
	assert(view.inventory == data.inventory, "the active view shares the account inventory")
	assert(SessionLock.isFinite(1), "sanity")
	print("PASS inventory: definitions, equipping, staff uses, economy effects and save validation")
end
