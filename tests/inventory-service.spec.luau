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
	inventory: any,
	merchant: any
)
	local harness = createHarness(createLimiter, codec, config, farmMath)
	local function setup(): any
		local h = harness.new()
		local attributes: { [string]: any } = {}
		local originalGet = h.player.GetAttribute
		h.player.SetAttribute = function(_player: any, name: string, value: any)
			attributes[name] = value
		end
		h.player.GetAttribute = function(player: any, name: string): any
			return if attributes[name] ~= nil then attributes[name] else originalGet(player, name)
		end
		local environment = createEnvironment(h.game)
		local sharedWeatherCalls = 0
		local sharedWeatherId: string? = nil
		h.seasonService = {
			hasQueuedWeather = function(): boolean
				return h.weatherQueued == true
			end,
			isWandWeatherBusy = function(): boolean
				return h.weatherBusy == true
			end,
			offerWeatherQueue = function(): (boolean, string?)
				h.weatherOffers = (h.weatherOffers or 0) + 1
				return true, nil
			end,
			confirmWeatherQueue = function(
				_player: any,
				_item: string,
				_weather: string,
				token: string,
				validate: any,
				started: any
			): (boolean, string?)
				if token ~= "ticket" then
					return false, "invalid ticket"
				end
				h.weatherQueued = true
				h.validateWeather = validate
				h.startWeather = started
				return true, nil
			end,
			cancelQueuedWeather = function(): (boolean, string?)
				h.weatherQueued = false
				return true, nil
			end,
			setPlayerWeather = function(id: string): (boolean, string?)
				sharedWeatherCalls += 1
				if h.weatherRejected then
					return false, "Bu hava bu mevsimde seçilemez"
				end
				sharedWeatherId = id
				return true, nil
			end,
		}
		h.weatherCalls = function(): number
			return sharedWeatherCalls
		end
		h.weatherId = function(): string?
			return sharedWeatherId
		end
		local service = createService(
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
			},
			merchant,
			h.seasonService
		)
		service.configureMerchantProximity(function(): boolean
			return h.near ~= false
		end)
		service.init()
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
	do
		local speed = setup()
		speed.data.cash = 1e9
		assert(buy(speed, "wind_charm").ok, "speed item can be earned with regular cash")
		assert(speed.player:GetAttribute("MovementSpeedMultiplier") == 1.15, "server publishes owned equipped speed")
		assert(speed.fire("RequestEquipItem", "wind_charm", speed.nextId()).ok, "speed item can be removed")
		assert(speed.player:GetAttribute("MovementSpeedMultiplier") == 1, "server removes speed when unequipped")
	end

	-- Eşya tüccarı: aynı sunucu teklifi, eski fiyat/döngü ve uzaktan ödeme korunur.
	local trader = setup()
	local tdata = trader.data
	tdata.adminForce = { merchantUntil = trader.now + 600 }
	tdata.cash = 1e9
	local offer = assert(merchant.offer(tdata, trader.player.UserId, trader.now))
	local quote = { cycle = offer.cycle, expectedPrice = offer.price }
	local function trade(target: any, id: any, detail: any, farmId: any?, requestId: any?): any
		return target.fire(
			"RequestBuyMerchantOffer",
			id,
			requestId or target.nextId(),
			farmId or target.data.activeMainFarmId,
			detail
		)
	end
	local beforeTrade = tdata.cash
	trader.near = false
	assert(
		not trade(trader, offer.itemId, quote).ok and tdata.cash == beforeTrade,
		"remote catalog cannot buy away from the physical stall"
	)
	trader.near = true
	assert(
		not trade(trader, offer.itemId, { cycle = offer.cycle - 1, expectedPrice = offer.price }).ok,
		"previous visit nonce is rejected"
	)
	assert(
		not trade(trader, offer.itemId, { cycle = offer.cycle, expectedPrice = 1 }).ok,
		"forged or stale price is rejected"
	)
	assert(not trade(trader, offer.itemId, quote, "wrong-farm").ok, "active farm must match")
	assert(not trade(trader, {}, quote).ok, "malformed item is rejected")
	assert(not trade(trader, offer.itemId, "bad").ok, "malformed quote is rejected")
	tdata.cash = offer.price - 1
	assert(
		not trade(trader, offer.itemId, quote).ok and not tdata.merchant,
		"poor trader never writes the visit marker"
	)
	tdata.cash = beforeTrade
	local requestId = trader.nextId()
	assert(trade(trader, offer.itemId, quote, nil, requestId).ok, "valid current quote buys the run item")
	assert(
		tdata.cash == beforeTrade - offer.price and inventory.owns(tdata, offer.itemId),
		"actual server discount is debited and item is granted"
	)
	assert(tdata.merchant.key == offer.cycle and tdata.merchant.bought, "one purchase marks the visit immediately")
	local afterTrade = tdata.cash
	trade(trader, offer.itemId, quote, nil, requestId)
	assert(
		not trade(trader, offer.itemId, quote).ok and tdata.cash == afterTrade,
		"replay and second visit purchase cannot duplicate"
	)
	local savedTrader =
		assert(codec.decode(codec.encode(tdata, trader.now), config, farmMath, trader.now, function(): string
			return "merchant-save"
		end))
	assert(
		savedTrader.merchant.key == offer.cycle and savedTrader.merchant.bought,
		"visit ownership survives encode/decode"
	)
	-- Tüccarın ilk seçimi sahip olunan eşyalarsa boş liste yerine sunulan yeni stok alınabilir.
	do
		local stocked = setup()
		stocked.data.adminForce = { merchantUntil = stocked.now + 600 }
		stocked.data.cash = 1e9
		local initial = merchant.status(stocked.data, stocked.player.UserId, stocked.now).offers
		for _, entry in initial do
			inventory.grant(stocked.data, entry.itemId)
		end
		local replacement = assert(merchant.offer(stocked.data, stocked.player.UserId, stocked.now))
		assert(not inventory.owns(stocked.data, replacement.itemId), "replacement is unowned")
		local boughtReplacement =
			trade(stocked, replacement.itemId, { cycle = replacement.cycle, expectedPrice = replacement.price })
		assert(
			boughtReplacement.ok and inventory.owns(stocked.data, replacement.itemId),
			"actual server accepts the replenished personal offer"
		)
		assert(
			merchant.status(stocked.data, stocked.player.UserId, stocked.now).bought,
			"replacement still consumes the single visit purchase"
		)
		local untouched = setup()
		untouched.data.adminForce = { merchantUntil = untouched.now + 600 }
		assert(
			#merchant.status(untouched.data, untouched.player.UserId, untouched.now).offers == config.MERCHANT.stock,
			"one player's purchase never depletes another player's stock"
		)
	end
	local departed = setup()
	departed.data.cash = 1e9
	departed.data.adminForce = { merchantUntil = departed.now + 1 }
	local lastOffer = assert(merchant.offer(departed.data, departed.player.UserId, departed.now))
	departed.now += 1000
	assert(
		not trade(departed, lastOffer.itemId, { cycle = lastOffer.cycle, expectedPrice = lastOffer.price }).ok,
		"departed catalog cannot debit a delayed purchase"
	)

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
	-- Hava asası özel kayıt üretmez; küresel servise yalnız yetkili kullanım ulaşır.
	do
		local weather = setup()
		weather.data.cash = 1e12
		local weatherStaff = itemOf(function(candidate: any): boolean
			return candidate.power ~= nil and candidate.power.kind == "weather" and candidate.price > 0
		end)
		local function useWeather(): any
			return weather.fire(
				"RequestUseItem",
				weatherStaff.id,
				weather.nextId(),
				weather.data.activeMainFarmId,
				"rain"
			)
		end
		assert(not useWeather().ok and weather.weatherCalls() == 0, "unowned weather staff cannot mutate the server")
		assert(buy(weather, weatherStaff.id).ok, "weather staff bought and equipped")
		weather.weatherRejected = true
		assert(
			not useWeather().ok and weather.metricCounts.ItemPowersUsed == nil,
			"global validation failure consumes no use"
		)
		weather.weatherRejected = false
		assert(useWeather().ok and weather.weatherId() == "rain", "authorized use forwards to the shared weather timer")
		assert(weather.data.envOverride == nil, "weather power creates no personal override")
		local count = weather.weatherCalls()
		assert(not useWeather().ok and weather.weatherCalls() == count, "cooldown blocks further global mutation")
	end
	do
		local queued = setup()
		queued.data.cash = 1e12
		local queuedStaff = itemOf(function(candidate: any): boolean
			return candidate.power ~= nil and candidate.power.kind == "weather" and candidate.price > 0
		end)
		assert(buy(queued, queuedStaff.id).ok, "queue staff acquired")
		queued.weatherBusy = true
		local function request(detail: any, farm: string?): any
			return queued.fire(
				"RequestUseItem",
				queuedStaff.id,
				queued.nextId(),
				farm or queued.data.activeMainFarmId,
				detail
			)
		end
		assert(not request("rain", "wrong-farm").ok and queued.weatherOffers == nil, "stale farm cannot offer a queue")
		assert(request("rain").ok and queued.weatherOffers == 1, "busy weather offers confirmation")
		assert(queued.metricCounts.ItemPowersUsed == nil, "offer consumes no rights")
		assert(not request({ weatherId = "rain", queueToken = "forged" }).ok, "forged confirmation rejected")
		assert(request({ weatherId = "rain", queueToken = "ticket" }).ok, "valid confirmation queues")
		assert(queued.metricCounts.ItemPowersUsed == nil, "confirmation consumes no rights")
		assert(not request("rain").ok, "already queued cannot add another choice")
		assert(queued.validateWeather(), "queued staff eligible while equipped")
		assert(queued.fire("RequestEquipItem", queuedStaff.id, queued.nextId()).ok, "staff can be unequipped")
		assert(not queued.validateWeather(), "unequipping invalidates queued activation")
		assert(request({ queueAction = "cancel" }).ok, "unequipped staff can cancel queue")
		assert(queued.metricCounts.ItemPowersUsed == nil, "cancellation consumes no rights")
		assert(queued.fire("RequestEquipItem", queuedStaff.id, queued.nextId()).ok, "staff can be re-equipped")
		assert(request({ weatherId = "rain", queueToken = "ticket" }).ok, "re-equipped staff queues")
		local run = queued.data.progression.run
		queued.data.progression.run += 1
		assert(not queued.validateWeather(), "rebirth invalidates previous run queue")
		queued.data.progression.run = run
		assert(queued.validateWeather())
		queued.startWeather()
		assert(
			queued.metricCounts.ItemPowersUsed == 1 and not queued.validateWeather(),
			"activation charges once and cooldown applies"
		)
	end
	print(
		"PASS inventory service: actual service purchase, equip, staff power, ownership, replay and throttling guards"
	)
end
