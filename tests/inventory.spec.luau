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
		if item.slot == "staff" and item.power then
			assert(item.power.kind == "season" or item.power.kind == "weather", `staff {itemId} has an unknown power`)
			assert(effectCount >= 1, `staff {itemId} also needs a passive effect`)
		elseif item.slot == "staff" then
			-- Güçsüz asalar (Çoban Asaları): yalnızca pasif fayda; hava gücü sadece Ebedi Hava Asası'nda
			assert(effectCount >= 2, `power-less staff {itemId} needs at least two different effects`)
		elseif item.slot == "tool" or item.slot == "charm" then
			-- Tek bir fayda yerine birkaç farklı fayda: eşyalar sadece "aynı şeyin artırılmışı" olmasın
			assert(item.power == nil and effectCount >= 2, `{item.slot} {itemId} needs at least two different effects`)
		else
			-- Şapka (ticari) ve sırt (lojistik) eşyalarının da katkısı olur; etki anahtarları config.spec'te denetlenir
			assert(item.power == nil and effectCount >= 1, `{item.slot} {itemId} needs at least one effect`)
		end
		assert(item.look, `item {itemId} needs a visible look`)
		assert(
			table.find({ "head", "back", "hip", "chest", "hand" }, item.look.attach),
			`item {itemId} has an unknown attach point`
		)
	end
	for itemId in Config.ITEMS do
		assert(seen[itemId], `item {itemId} is missing from ITEM_ORDER`)
	end
	for _, slotId in Config.ITEM_SLOT_ORDER do
		assert(Config.ITEM_SLOTS[slotId], `ITEM_SLOT_ORDER lists unknown slot {slotId}`)
	end
	-- Aileler: fiyat arttıkça fayda da artar (aksi halde ucuz kademe pahalıyı gereksiz kılar)
	-- Aileler muskalar içindedir: şapka/sırt eşyaları farklı slotta oldukları için ayrı kurala (config.spec) bağlıdır
	local function family(filter: (any) -> number?): { { price: number, value: number } }
		local list = {}
		for _, itemId in Config.ITEM_ORDER do
			local item = Config.ITEMS[itemId]
			local value = if item.slot == "head"
					or item.slot == "back"
					or (item.slot == "staff" and not item.power)
				then nil
				else filter(item)
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
	Inventory.grant(save, "weather_staff_inf")
	Inventory.equip(save, "weather_staff_inf")
	assert(Inventory.canUse(save, "weather_staff_inf", t0 + 300), "weather uses are separate from season uses")
	assert(Config.ITEMS.weather_staff_inf.power.usesPerDay == 1, "the weather staff allows one change per day")
	Inventory.recordUse(save, "weather_staff_inf", t0 + 300)
	assert(
		Inventory.usesLeft(save, "weather_staff_inf", t0 + 600) == 0
			and not Inventory.canUse(save, "weather_staff_inf", t0 + 600 + Config.ITEM_USE_COOLDOWN_SECONDS),
		"the weather staff is spent for the day"
	)
	assert(Inventory.canUse(save, "weather_staff_inf", t0 + 86400 + 300), "a new UTC day restores the weather use")
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
	-- Şapka/sırt: yükseltme indirimi vermez, ama kendi etkilerini FarmMath'e taşır
	local crown = effects("golden_crown")
	assert(
		FarmMath.getUpgradeCost(crown, upgrade) == upgrade.cost
			and FarmMath.getStorageCap(crown) == FarmMath.getStorageCap(plain),
		"hats and back items never discount upgrades"
	)
	assert(
		math.abs(
			FarmMath.getAnimalMultiplier(crown, "cow", true) / FarmMath.getAnimalMultiplier(plain, "cow", true) - 2
		) < 1e-9,
		"a crown doubles every animal's income"
	)
	-- Takılı şapka + sırt etkileri toplanır
	local worn = newSave()
	for _, itemId in { "cowboy_hat", "peacock_tail" } do
		Inventory.grant(worn, itemId)
		assert(Inventory.equip(worn, itemId), `{itemId} can be equipped`)
	end
	assert(
		math.abs(FarmMath.getBonus(worn, "contractBonus") - 0.09) < 1e-9
			and math.abs(FarmMath.getBonus(worn, "sellBonus") - 0.04) < 1e-9
			and math.abs(FarmMath.getBonus(worn, "goodsYield") - 0.03) < 1e-9,
		"hat and back effects add up"
	)
	local leaf = effects("leaf_cloak")
	assert(
		math.abs(FarmMath.getGrowthSpeed(leaf, "cow") / FarmMath.getGrowthSpeed(plain, "cow") - 1.08) < 1e-9,
		"a growth cloak speeds growth up"
	)
	-- Hepsi takılı: her slotta en güçlü eşya, ekonomi sınırları içinde kalmalı
	local maxed = newSave()
	for _, slotId in Config.ITEM_SLOT_ORDER do
		local best: any = nil
		for _, itemId in Config.ITEM_ORDER do
			local item = Config.ITEMS[itemId]
			if item.slot == slotId and (best == nil or item.price > best.price) then
				best = item
			end
		end
		if best then
			Inventory.grant(maxed, best.id)
			assert(Inventory.equip(maxed, best.id), `{best.id} can be equipped`)
		end
	end
	assert(FarmMath.getEquippedBonus(maxed, "incomeBonus") <= 1.2, "all-equipped income bonus stays capped")
	assert(FarmMath.getEquippedBonus(maxed, "sellBonus") <= 0.35, "all-equipped sell bonus stays capped")
	assert(FarmMath.getEquippedBonus(maxed, "upgradeDiscount") <= 0.2, "all-equipped upgrade discount stays capped")
	assert(FarmMath.getBonus(maxed, "expansionDiscount") <= 0.12, "all-equipped expansion discount stays capped")
	assert(FarmMath.getBonus(maxed, "contractBonus") <= 0.3, "all-equipped contract bonus stays capped")
	assert(FarmMath.getBonus(maxed, "goodsYield") <= 0.25, "all-equipped goods yield stays capped")
	assert(FarmMath.getGrowthSpeed(maxed, "cow") < Config.GROWTH_SPEED_CAP, "all-equipped growth stays under the cap")
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
