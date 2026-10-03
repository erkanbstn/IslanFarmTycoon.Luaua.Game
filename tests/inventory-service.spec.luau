--!strict
-- Envanter servisi: gerçek servis kaynağı; satın alma, takma/çıkarma ve asa gücü (sahip, parası yok, tekrar, hız sınırı).
return function(
	createService: any,
	createHarness: any,
	createLimiter: any,
	createEnvironment: any,
	codec: any,
	config: any,
	farmMath: any,
	inventory: any
)
	local harness = createHarness(createLimiter, codec, config, farmMath)
	local function setup(): any
		local h = harness.new()
		local environment = createEnvironment(h.game)
		createService(
			h.game,
			h.remotes,
			h.dataService,
			h.plotService,
			h.economyService,
			h.limiter,
			h.metrics,
			h.dateTime,
			h.task,
			h.osFake,
			environment,
			h.guard,
			{
				find = function()
					return nil
				end,
			}
		).init()
		h.environment = environment
		return h
	end
	local function itemOf(predicate: (any) -> boolean): any
		for _, itemId in config.ITEM_ORDER do
			local item = config.ITEMS[itemId]
			if predicate(item) then
				return item
			end
		end
		error("no matching item in Config.ITEMS")
	end
	local function buy(h: any, itemId: any, requestId: any?): any
		return h.fire("RequestBuyItem", itemId, requestId or h.nextId())
	end

	local rewardShop = setup()
	rewardShop.data.cash = 1e12
	local rewardCash = rewardShop.data.cash
	for _, milestone in config.PROGRESSION.milestones do
		if milestone.itemId then
			assert(
				not buy(rewardShop, milestone.itemId).ok,
				"earned-only reward cannot be forged through the cash remote"
			)
			assert(
				not rewardShop.data.inventory.items[milestone.itemId],
				"cash remote never grants locked rebirth cosmetics"
			)
		end
	end
	assert(
		rewardShop.data.cash == rewardCash and rewardShop.counters.saves == 0,
		"earned-only attempts never debit or persist"
	)
	-- Satın alma: fiyat sunucuda okunur, sahiplik yazılır, boş slota otomatik takılır
	local h = setup()
	local data = h.data
	local item = itemOf(function(candidate: any): boolean
		return candidate.price > 0
	end)
	data.cash = item.price + 3
	local reply = buy(h, item.id)
	assert(reply and reply.remote == "PurchaseResult" and reply.ok == true, "the owner can buy an item")
	assert(inventory.owns(data, item.id) and data.cash == 3, "ownership is written and exactly the price is spent")
	assert(inventory.equippedId(data, item.slot) == item.id, "an item bought into an empty slot is equipped")
	assert(
		h.counters.pushes == 1 and h.counters.saves == 1 and h.counters.refreshes == 1,
		"state pushed, saved, redrawn"
	)
	assert(
		h.counters.settles == 2 and h.metricCounts.ItemsPurchased == 1,
		"income is settled before and during the change"
	)

	-- Zaten alınmış / parası yok / geçersiz kimlik
	data.cash = item.price * 10
	local owned = buy(h, item.id)
	assert(owned and owned.ok == false and owned.message == "Bu eşyaya zaten sahipsin", "no double purchase")
	assert(data.cash == item.price * 10, "no money is taken for an owned item")
	local poor = setup()
	poor.data.cash = item.price - 1
	local broke = buy(poor, item.id)
	assert(broke and broke.ok == false and string.find(broke.message, "Yeterli para yok", 1, true) ~= nil, "no cash")
	assert(not inventory.owns(poor.data, item.id) and poor.counters.saves == 0, "a refused purchase changes nothing")
	local unknown = buy(poor, "no_such_item")
	assert(unknown and unknown.ok == false and unknown.message == "Bilinmeyen eşya", "unknown item")
	local badType = buy(poor, {})
	assert(badType and badType.ok == false, "a non-string item id is rejected")

	-- Verisi olmayan oyuncu ve dünya hazır değil
	local foreign = poor.fireAs(poor.stranger, "RequestBuyItem", item.id, poor.nextId())
	assert(
		foreign and foreign.ok == false and foreign.message == "Veri henüz yüklenmedi",
		"a player without save data"
	)
	poor.data.cash = item.price
	poor.worldReady = false
	local early = buy(poor, item.id)
	assert(early and early.ok == false and poor.data.cash == item.price, "world not ready: nothing is bought")
	poor.worldReady = true

	-- Tekrar eden istek kimliği
	local replayed = setup()
	replayed.data.cash = item.price * 3
	local id = replayed.nextId()
	assert(buy(replayed, item.id, id).ok == true, "first request processed")
	local cashAfter = replayed.data.cash
	assert(buy(replayed, item.id, id) == nil, "a replayed request id is ignored without reply")
	assert(replayed.data.cash == cashAfter and replayed.counters.saves == 1, "a replay changes nothing")

	-- Hız sınırı: aynı anda ikinci satın alma "çok hızlı" cevabı alır
	local limited = setup()
	limited.data.cash = 1e12
	local second = itemOf(function(candidate: any): boolean
		return candidate.id ~= item.id and candidate.price > 0
	end)
	assert(buy(limited, item.id).ok == true, "first purchase passes the limiter")
	local cashBefore = limited.data.cash
	local spam = limited.fireRaw(limited.player, "RequestBuyItem", second.id, limited.nextId())
	assert(
		spam and spam.ok == false and spam.message == "Çok hızlı işlem yapıyorsun; biraz bekle.",
		"throttle reply"
	)
	assert(
		limited.data.cash == cashBefore and not inventory.owns(limited.data, second.id),
		"the throttled request changes nothing"
	)
	local spamAgain = limited.fireRaw(limited.player, "RequestBuyItem", second.id, limited.nextId())
	assert(spamAgain == nil, "throttle replies are rate limited too")

	-- Takma/çıkarma: sahip olunmayan eşya takılamaz; takılıyken çıkarılır, tekrar takılır
	local equip = setup()
	equip.data.cash = 1e12
	local notOwned = equip.fire("RequestEquipItem", item.id, equip.nextId())
	assert(
		notOwned and notOwned.ok == false and notOwned.message == "Bu eşyaya sahip değilsin",
		"equip needs ownership"
	)
	assert(buy(equip, item.id).ok == true, "bought")
	local removed = equip.fire("RequestEquipItem", item.id, equip.nextId())
	assert(removed and removed.ok == true and not inventory.isEquipped(equip.data, item.id), "a worn item is taken off")
	local worn = equip.fire("RequestEquipItem", item.id, equip.nextId())
	assert(worn and worn.ok == true and inventory.isEquipped(equip.data, item.id), "it can be put on again")
	assert(equip.metricCounts.ItemsEquipped == 2, "both changes are counted")

	-- Asa gücü: takılı olmadan kullanılamaz; mevsim değişir, hak ve bekleme süresi sunucuda denetlenir
	local power = setup()
	power.data.cash = 1e12
	local staff = itemOf(function(candidate: any): boolean
		return candidate.power ~= nil and candidate.power.kind == "season" and candidate.price > 0
	end)
	local current = power.environment.getSeason(power.data.envOverride)
	local target = nil
	for _, season in config.SEASONS do
		if season.id ~= current.id then
			target = season.id
			break
		end
	end
	assert(target, "there is another season to switch to")
	local function use(argument: any): any
		return power.fire("RequestUseItem", staff.id, power.nextId(), power.data.activeMainFarmId, argument)
	end
	local unowned = use(target)
	assert(unowned and unowned.ok == false and power.data.envOverride == nil, "an unowned staff does nothing")
	assert(buy(power, staff.id).ok == true, "staff bought")
	local badArgument = use(5)
	assert(
		badArgument and badArgument.ok == false and badArgument.message == "Geçersiz seçim",
		"argument must be an id string"
	)
	local badSeason = use("no_such_season")
	assert(badSeason and badSeason.ok == false and badSeason.message == "Bilinmeyen mevsim", "unknown season")
	local same = use(current.id)
	assert(same and same.ok == false and same.message == "Zaten bu mevsimdesin", "the current season cannot be picked")
	local used = use(target)
	assert(
		used and used.ok == true and power.data.envOverride and power.data.envOverride.seasonId == target,
		"season changes"
	)
	assert(power.metricCounts.ItemPowersUsed == 1, "the use is counted")
	local cooling = use(current.id)
	assert(
		cooling
			and cooling.ok == false
			and (cooling.message == "Asa dinleniyor; biraz bekle" or cooling.message == "Bugünkü hakkın bitti"),
		"the staff cooldown or daily allowance holds"
	)
	assert(power.data.envOverride.seasonId == target, "a refused use leaves the season untouched")
	print(
		"PASS inventory service: actual service purchase, equip, staff power, ownership, replay and throttling guards"
	)
end
