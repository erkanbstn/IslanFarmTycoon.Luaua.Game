--!strict
-- Ahır siparişi servisi: gerçek servis kaynağı; sahiplik, tekrar oynatma, atomik teslim, ödül ve bildirim.
return function(createService: any, createLimiter: any, codec: any, config: any, farmMath: any)
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
	local results: { any } = {}
	local remotes = {
		get = function(name: string): any
			if name == "RequestFulfillContract" then
				return request
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
	local dataService = {
		tryGet = function(target: any): any
			return if active and target == player then data else nil
		end,
		addCash = function(_target: any, amount: number)
			data.cash += amount
		end,
		pushState = function()
			pushes += 1
		end,
		requestSave = function()
			saves += 1
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
		dataService,
		limiter,
		{
			increment = function()
				increments += 1
			end,
		},
		{
			now = function(): any
				return { UnixTimestamp = now }
			end,
		}
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
		data.cash - cashBefore == small.reward and small.reward == math.floor(small.worth * small.rewardFactor * 1.5),
		"the season bonus applies"
	)

	-- Kilit: oturum hazır değilse teslim yok
	worldReady = false
	local notReady = fire(offers()[2].key)
	assert(notReady and not notReady.ok, "a farm that is not ready cannot deliver")
	worldReady = true
	print("PASS contract service: actual service ownership, replay, atomic delivery, season bonus and persistence")
end
