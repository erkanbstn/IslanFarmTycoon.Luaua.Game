--!strict
-- Ürün silme servisi: gerçek servis kaynağı; doğrulama, tekrar oynatma, hız sınırı, atomik düşme ve başka hiçbir şeyin değişmemesi.
return function(
	createService: any,
	createLimiter: any,
	codec: any,
	config: any,
	farmMath: any,
	createGuard: any,
	goodsDiscard: any
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
		return `goods-discard-{serial}`
	end
	local data: any = assert(codec.decode(nil, config, farmMath, now, uid), "fixture decode failed")
	farmMath.applyDerived(data)
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
	local discardRequest = { OnServerEvent = signal() }
	local results: { any } = {}
	local remotes = {
		get = function(name: string): any
			if name == "RequestDiscardGoods" then
				return discardRequest
			end
			return {
				FireClient = function(_self: any, target: any, id: number, ok: boolean, message: string)
					table.insert(results, { target = target, id = id, ok = ok, message = message })
				end,
			}
		end,
	}
	local pushes, saves, discarded, otherMetrics = 0, 0, 0, 0
	local cashCalls = 0
	local dataService = {
		tryGet = function(target: any): any
			return if target == player then data else nil
		end,
		addCash = function()
			cashCalls += 1
		end,
		pushState = function()
			pushes += 1
		end,
		requestSave = function()
			saves += 1
		end,
	}
	local metrics = {
		increment = function(name: string, amount: number?)
			if name == "ItemsDiscarded" then
				discarded += amount or 1
			else
				otherMetrics += 1
			end
		end,
	}
	local service = createService(
		fakeGame,
		remotes,
		farmMath,
		goodsDiscard,
		dataService,
		limiter,
		metrics,
		createGuard(fakeGame, remotes, dataService, limiter, metrics)
	)
	service.init()
	local sequence = 0
	local function discard(goodId: any, amount: any, target: any?, farmId: any?): any
		clockNow += 1
		sequence += 1
		local before = #results
		discardRequest.OnServerEvent.fire(target or player, goodId, sequence, farmId or data.activeMainFarmId, amount)
		return if #results > before then results[#results] else nil
	end
	local function snapshot(): string
		local parts = {}
		for _, goodId in config.GOODS_ORDER do
			table.insert(parts, `{goodId}={farmMath.getGoodsAmount(data, goodId)}`)
		end
		return table.concat(parts, ",")
	end

	data.goods = {}
	farmMath.addGoods(data, "milk", 12)
	farmMath.addGoods(data, "egg", 7)
	local cashBefore = data.cash

	-- Başarılı kısmi silme: yalnız seçilen ürün ve adet düşer, para değişmez, kayıt istenir, sayaç adet kadar artar
	local pushesBefore, savesBefore = pushes, saves
	local partial = discard("milk", 4)
	assert(partial and partial.ok, "a valid partial discard succeeds")
	assert(farmMath.getGoodsAmount(data, "milk") == 8, "exactly the chosen amount is removed")
	assert(farmMath.getGoodsAmount(data, "egg") == 7, "other goods are untouched")
	assert(data.cash == cashBefore and cashCalls == 0, "discarding never pays or refunds cash")
	assert(pushes == pushesBefore + 1 and saves == savesBefore + 1, "state is pushed and a save requested once")
	assert(discarded == 4 and otherMetrics == 0, "the discard counter grows by the discarded amount only")
	assert(string.find(partial.message, "Ürün silindi", 1, true) ~= nil, "the player gets a confirmation")

	-- Hepsini sil: yığın tamamen kalkar, miktar negatif olmaz
	local all = discard("egg", 7)
	assert(all and all.ok and farmMath.getGoodsAmount(data, "egg") == 0, "discarding the whole stack empties it")
	assert(data.goods.egg == nil, "an emptied stack leaves no zero entry")
	local again = discard("egg", 1)
	assert(again and not again.ok, "an empty stack cannot be discarded again")

	-- Geçersiz miktarlar hiçbir şeyi değiştirmez ve cevap alır
	local before = snapshot()
	local pushesGuard, savesGuard, discardedGuard = pushes, saves, discarded
	for _, bad in { 0, -1, -5, 0.5, 2.5, 13, 1e9, math.huge, -math.huge, 0 / 0, "3", "", true, {}, false } do
		local reply = discard("milk", bad)
		assert(reply and not reply.ok, "an invalid amount is refused with a reply")
	end
	local missing = discard("milk", nil)
	assert(missing and not missing.ok, "a missing amount is refused")
	for _, badGoods in { "nope", "", 5, {}, "__index", string.rep("a", 80), true } do
		local reply = discard(badGoods, 1)
		assert(reply and not reply.ok, "an unknown good is refused with a reply")
	end
	for itemId in config.ITEMS do
		local reply = discard(itemId, 1)
		assert(reply and not reply.ok, "equipment and permanent entitlements can never be discarded")
	end
	assert(snapshot() == before, "refused requests change no goods")
	assert(
		pushes == pushesGuard and saves == savesGuard and discarded == discardedGuard,
		"refused requests push, save and count nothing"
	)
	assert(farmMath.getGoodsAmount(data, "milk") == 8, "goods never drop below the stock")

	-- Yabancı oyuncu, çiftlik uyuşmazlığı, hazır olmayan dünya
	local noData = discard("milk", 1, stranger)
	assert(
		noData and not noData.ok and farmMath.getGoodsAmount(data, "milk") == 8,
		"a player without data cannot discard"
	)
	local wrongFarm = discard("milk", 1, nil, "99")
	assert(
		wrongFarm and not wrongFarm.ok and farmMath.getGoodsAmount(data, "milk") == 8,
		"a request for another farm is refused"
	)
	worldReady = false
	local notReady = discard("milk", 1)
	assert(
		notReady and not notReady.ok and farmMath.getGoodsAmount(data, "milk") == 8,
		"a farm that is not ready is refused"
	)
	worldReady = true

	-- Tekrar oynatma: aynı istek kimliği ikinci kez uygulanmaz
	clockNow += 1
	sequence += 1
	local replayId = sequence
	discardRequest.OnServerEvent.fire(player, "milk", replayId, data.activeMainFarmId, 2)
	assert(farmMath.getGoodsAmount(data, "milk") == 6, "the first request applies")
	clockNow += 1
	local repliesBefore = #results
	discardRequest.OnServerEvent.fire(player, "milk", replayId, data.activeMainFarmId, 2)
	assert(#results == repliesBefore and farmMath.getGoodsAmount(data, "milk") == 6, "a replayed request id is ignored")
	clockNow += 1
	discardRequest.OnServerEvent.fire(player, "milk", nil, data.activeMainFarmId, 2)
	assert(farmMath.getGoodsAmount(data, "milk") == 6, "a request without an id is refused")

	-- Hız sınırı: saat ilerlemeden ikinci silme uygulanmaz
	sequence += 1
	clockNow += 1
	discardRequest.OnServerEvent.fire(player, "milk", sequence, data.activeMainFarmId, 1)
	local afterFirst = farmMath.getGoodsAmount(data, "milk")
	sequence += 1
	discardRequest.OnServerEvent.fire(player, "milk", sequence, data.activeMainFarmId, 1)
	assert(
		afterFirst == 5 and farmMath.getGoodsAmount(data, "milk") == 5,
		"a second discard inside the cooldown is refused"
	)

	-- Toplam değer silinen kadar düşer
	assert(farmMath.getGoodsWorth(data) == 5 * config.GOODS.milk.value, "the barn worth shrinks by the discarded goods")

	-- removeGoods yetersizken hiçbir şey değiştirmez (servisin dayandığı kural)
	local stock = farmMath.getGoodsAmount(data, "milk")
	assert(
		not farmMath.removeGoods(data, "milk", stock + 1) and farmMath.getGoodsAmount(data, "milk") == stock,
		"insufficient stock changes nothing"
	)
	print("PASS goods discard service: validation, replay, rate limit, atomic removal and no side effects")
end
