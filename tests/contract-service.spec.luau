--!strict
-- Ahır siparişi servisi: gerçek servis kaynağı; sahiplik, tekrar oynatma, atomik teslim, ödül ve bildirim.
return function(
	createService: any,
	createLimiter: any,
	codec: any,
	config: any,
	farmMath: any,
	createGuard: any,
	rewards: any
)
	local function signal(): any
		local callbacks = {}
		return {
			Connect = function(_self: any, callback: any)
				table.insert(callbacks, callback)
			end,
			fire = function(...: any)
				for _, callback in callbacks do
					callback(...)
				end
			end,
		}
	end
	local now = 600000 * 9 + 10
	local serial = 0
	local function uid(): string
		serial += 1
		return `contract-service-{serial}`
	end
	local data: any = assert(codec.decode(nil, config, farmMath, now, uid), "fixture decode failed")
	for _, upgrade in config.UPGRADES do
		if not upgrade.leveled then
			data.purchased[upgrade.id] = true
		end
	end
	farmMath.applyDerived(data)
	-- Pano yalnızca üretilebilen ürünü ister: her açık merkez için gereken sayıda hayvan açık bölgede durur
	for _, recipe in config.PRODUCTION_RECIPES do
		if recipe.output == "goods" and data.purchased[recipe.upgradeId] and data.unlockedIslands[recipe.island] then
			for zoneId, zone in config.ZONES do
				if
					data.unlockedZones[zoneId] and config.zoneAllows(zone, recipe.animalIds[1], data.activeMainFarmId)
				then
					for _ = 1, recipe.requiredAdults do
						table.insert(data.animals, {
							uid = uid(),
							animalId = recipe.animalIds[1],
							zoneId = zoneId,
							bornAt = 0,
							stage = "adult",
						})
					end
					break
				end
			end
		end
	end
	data.cash = 0
	local worldReady = true
	local player: any = {
		GetAttribute = function(_self: any, name: string): any
			return if name == "WorldReady" then worldReady else nil
		end,
	}
	local stranger: any = { GetAttribute = player.GetAttribute }
	local node: any = {}
	function node:WaitForChild(_name: string): any
		return self
	end
	local fakeGame = {
		GetService = function(_self: any, name: string): any
			if name == "Players" then
				return { PlayerRemoving = signal() }
			end
			return node
		end,
	}
	local clockNow = 0
	local limiter = createLimiter(fakeGame, {
		clock = function(): number
			return clockNow
		end,
	})
	local request = { OnServerEvent = signal() }
	local sellRequest = { OnServerEvent = signal() }
	local results: { any } = {}
	local remotes = {
		get = function(name: string): any
			if name == "RequestFulfillContract" then
				return request
			elseif name == "RequestSellGoods" then
				return sellRequest
			end
			return {
				FireClient = function(_self: any, target: any, id: number, ok: boolean, message: string)
					table.insert(results, { target = target, id = id, ok = ok, message = message })
				end,
			}
		end,
	}
	local active = true
	local bonus = 0
	local pushes, saves, increments = 0, 0, 0
	local cashReasons: { string } = {}
	local dataService = {
		tryGet = function(target: any): any
			return if active and target == player then data else nil
		end,
		addCash = function(_target: any, amount: number, reason: string?)
			data.cash += amount
			table.insert(cashReasons, reason or "")
		end,
		pushState = function()
			pushes += 1
		end,
		requestSave = function()
			saves += 1
		end,
	}
	local metrics = {
		increment = function()
			increments += 1
		end,
	}
	local service = createService(
		fakeGame,
		remotes,
		farmMath,
		{
			getSeason = function(): any
				return { orderBonus = bonus }
			end,
		},
		rewards,
		dataService,
		limiter,
		metrics,
		{
			now = function(): any
				return { UnixTimestamp = now }
			end,
		},
		createGuard(fakeGame, remotes, dataService, limiter, metrics)
	)
	service.init()
	local sequence = 0
	local function fire(key: any, target: any?, farmId: any?): any
		clockNow += 1
		sequence += 1
		local before = #results
		request.OnServerEvent.fire(target or player, key, sequence, farmId or data.activeMainFarmId)
		return if #results > before then results[#results] else nil
	end
	local function offers(): any
		return farmMath.getContractOffers(data, now, bonus)
	end

	-- Ürün merkezi ve ürün olmadan teslim yok
	local empty = fire(offers()[1].key)
	assert(empty and not empty.ok and data.cash == 0, "an empty barn pays nothing")
	assert(fire("x") and not fire("x").ok, "an unknown key is rejected with a reply")
	local denied = fire(offers()[1].key, stranger)
	assert(denied and not denied.ok and data.cash == 0, "a player without data is refused and pays nothing")

	-- Başarılı teslim: ödül tekliften, ürünler düşer, kayıt istenir, sayaç artar
	for _, goodsId in config.GOODS_ORDER do
		farmMath.addGoods(data, goodsId, farmMath.getGoodsCap(data))
	end
	local offer = offers()[3]
	local before = {}
	for _, line in offer.lines do
		before[line.goodsId] = farmMath.getGoodsAmount(data, line.goodsId)
	end
	local pushesBefore, savesBefore = pushes, saves
	local ok = fire(offer.key)
	assert(ok and ok.ok and data.cash == offer.reward, "delivery pays exactly the offer's reward")
	assert(string.find(ok.message, "Ahır siparişi teslim edildi", 1, true) ~= nil, "the player gets a confirmation")
	for _, line in offer.lines do
		assert(farmMath.getGoodsAmount(data, line.goodsId) == before[line.goodsId] - line.amount, "exact goods removed")
	end
	assert(
		pushes == pushesBefore + 1 and saves == savesBefore + 1 and increments == 1,
		"state is pushed, saved, counted"
	)

	-- Çifte teslim ve eski istek
	local second = fire(offer.key)
	assert(second and not second.ok and data.cash == offer.reward, "a delivered offer cannot be delivered twice")
	local repliesBefore = #results
	request.OnServerEvent.fire(player, offers()[1].key, sequence, data.activeMainFarmId)
	assert(#results == repliesBefore and data.cash == offer.reward, "a replayed request id is ignored")
	assert(pushes == pushesBefore + 1, "rejected requests never push state")

	-- Etkin çiftlik bağlamı
	local mismatch = fire(offers()[1].key, nil, "99")
	assert(mismatch and not mismatch.ok and data.cash == offer.reward, "a request for another farm is refused")

	-- Mevsim bonusu ödüle yansır
	bonus = 0.5
	local small = offers()[1]
	local cashBefore = data.cash
	assert(fire(small.key).ok, "a small offer is delivered")
	assert(
		data.cash - cashBefore == small.reward
			and small.reward
				== math.floor(small.worth * small.rewardFactor * (1.5 + farmMath.getBonus(data, "contractBonus"))),
		"the season bonus applies"
	)

	-- Mevsim "yatırım" hedefi: sipariş teslimi de sayılır (yeni hayvan/yükseltme kalmayan geç oyunda hedef ulaşılabilir kalır)
	now += config.SEASON_SECONDS -- sonraki mevsim (yatırım mevsimi)
	assert(rewards.seasonalDef(rewards.seasonNumber(now)).metric == "invest", "the fixture reaches an invest season")
	rewards.ensureSeasonal(data, now)
	local investBefore = data.seasonal.progress
	for _, goodsId in config.GOODS_ORDER do
		farmMath.addGoods(data, goodsId, farmMath.getGoodsCap(data))
	end
	assert(fire(offers()[2].key).ok, "an order is delivered in the invest season")
	assert(
		data.seasonal.progress == investBefore + 1,
		"a delivered order counts as one investment toward the season goal"
	)
	local refused = fire("x")
	assert(not refused.ok and data.seasonal.progress == investBefore + 1, "a refused delivery counts nothing")

	-- Kilit: oturum hazır değilse teslim yok
	worldReady = false
	local notReady = fire(offers()[2].key)
	assert(notReady and not notReady.ok, "a farm that is not ready cannot deliver")
	worldReady = true

	-- Yeni istek kimlikleri işlem sınırını aşsa da cevap trafiği sınırlı kalır.
	clockNow += 1
	sequence += 1
	request.OnServerEvent.fire(player, "x", sequence, data.activeMainFarmId)
	local throttleRepliesBefore = #results
	local throttleCashBefore, throttlePushesBefore, throttleSavesBefore = data.cash, pushes, saves
	for _ = 1, 100 do
		sequence += 1
		request.OnServerEvent.fire(player, "x", sequence, data.activeMainFarmId)
	end
	assert(#results == throttleRepliesBefore + 1, "a burst produces only one throttle reply")
	assert(
		data.cash == throttleCashBefore and pushes == throttlePushesBefore and saves == throttleSavesBefore,
		"throttled deliveries change no account state"
	)

	-- ---------------------------------------------------------------- hızlı boşaltma (Hepsini sat / Yarısını sat)
	local function sell(goodsId: any, mode: any, target: any?, farmId: any?): any
		clockNow += 1
		sequence += 1
		local count = #results
		sellRequest.OnServerEvent.fire(target or player, goodsId, sequence, farmId or data.activeMainFarmId, mode)
		return if #results > count then results[#results] else nil
	end
	data.goods = {}
	local milk = config.GOODS.milk
	farmMath.addGoods(data, "milk", 11)
	local cashBefore2, pushesBefore2, savesBefore2 = data.cash, pushes, saves
	local half = sell("milk", "half")
	assert(
		half and half.ok and farmMath.getGoodsAmount(data, "milk") == 5,
		"selling half removes the upper half, 6 of 11"
	)
	assert(
		data.cash - cashBefore2 == math.floor(6 * milk.value * config.GOODS_SELL.rate),
		"half pays value x rate for the removed units"
	)
	assert(cashReasons[#cashReasons] == "goodsSale", "the sale is reported to telemetry as its own source")
	assert(pushes == pushesBefore2 + 1 and saves == savesBefore2 + 1, "a sale pushes state and saves")
	assert(string.find(half.message, "Ürün satıldı", 1, true) ~= nil, "the player gets a confirmation")
	local cashBefore3 = data.cash
	local all = sell("milk", "all")
	assert(all and all.ok and farmMath.getGoodsAmount(data, "milk") == 0, "selling all empties the stack")
	assert(
		data.cash - cashBefore3 == math.floor(5 * milk.value * config.GOODS_SELL.rate),
		"all pays value x rate for the rest"
	)
	local nothing = sell("milk", "all")
	assert(
		nothing and not nothing.ok and data.cash == cashBefore3 + math.floor(5 * milk.value * config.GOODS_SELL.rate),
		"an empty stack pays nothing"
	)
	farmMath.addGoods(data, "egg", 1)
	local single = sell("egg", "half")
	assert(single and single.ok and farmMath.getGoodsAmount(data, "egg") == 0, "half of a single unit sells that unit")

	-- Doğrulama: bilinmeyen ürün, geçersiz kip, yanlış tür, yabancı oyuncu, çiftlik uyuşmazlığı, tekrar, hız sınırı
	farmMath.addGoods(data, "down", 8)
	local guard = data.cash
	for _, badGoods in { "nope", "", 5, {}, "__index", string.rep("a", 80) } do
		local reply = sell(badGoods, "all")
		assert(reply and not reply.ok, "an unknown good is refused with a reply")
	end
	for _, badMode in { "everything", "", 5, {}, "ALL", false } do
		local reply = sell("down", badMode)
		assert(reply and not reply.ok, "an invalid mode is refused")
	end
	assert(data.cash == guard and farmMath.getGoodsAmount(data, "down") == 8, "refused sales change nothing")
	local stranger2 = sell("down", "all", stranger)
	assert(
		stranger2 and not stranger2.ok and farmMath.getGoodsAmount(data, "down") == 8,
		"a player without data cannot sell"
	)
	local wrongFarm = sell("down", "all", nil, "99")
	assert(
		wrongFarm and not wrongFarm.ok and farmMath.getGoodsAmount(data, "down") == 8,
		"a request for another farm is refused"
	)
	local repliesBefore2 = #results
	sellRequest.OnServerEvent.fire(player, "down", sequence, data.activeMainFarmId, "all")
	assert(
		#results == repliesBefore2 and farmMath.getGoodsAmount(data, "down") == 8,
		"a replayed request id is ignored"
	)
	-- Hız sınırı: saat ilerlemeden ikinci satış reddedilir
	sequence += 1
	clockNow += 1
	sellRequest.OnServerEvent.fire(player, "down", sequence, data.activeMainFarmId, "half")
	local sold = farmMath.getGoodsAmount(data, "down")
	sequence += 1
	sellRequest.OnServerEvent.fire(player, "down", sequence, data.activeMainFarmId, "half")
	assert(farmMath.getGoodsAmount(data, "down") == sold and sold == 4, "a second sale inside the cooldown is refused")
	worldReady = false
	local notReadySell = sell("down", "all")
	assert(
		notReadySell and not notReadySell.ok and farmMath.getGoodsAmount(data, "down") == 4,
		"a farm that is not ready cannot sell"
	)
	worldReady = true

	-- Sömürü yok: satış gelirinin değeri hiçbir zaman sipariş ödülünün (ürün değeri x kademe çarpanı) altında kalmaz; sipariş teslimi satıştan fazla öder
	local lowestFactor = math.huge
	for _, tier in config.GOODS_CONTRACTS.tiers do
		lowestFactor = math.min(lowestFactor, tier.rewardFactor)
	end
	assert(
		config.GOODS_SELL.rate < 1 / lowestFactor,
		"even the cheapest order tier pays more than selling the same goods"
	)
	print("PASS contract service: actual service ownership, replay, atomic delivery, season bonus and persistence")
end
