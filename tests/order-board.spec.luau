--!strict
-- Sipariş panosu: 3 seçenek, pencere yenilenmesi, ödül ölçeği, seçim doğrulaması ve kayıt sınırları.
return function(OrderBoard: any, OrderRules: any, Config: any, SaveCodec: any, FarmMath: any)
	local function farm(): any
		local data: any = {
			cash = 0,
			stored = 0,
			production = {},
			purchased = {},
			animals = {
				{ uid = "a", animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" },
				{ uid = "b", animalId = "cow", zoneId = "starter", bornAt = 0, stage = "calf" },
			},
			unlockedIslands = {},
			unlockedZones = {},
			ordersCompleted = 0,
			barnLevel = 1,
		}
		FarmMath.applyDerived(data)
		return data
	end
	local now = Config.ORDER_BOARD_SECONDS * 100 + 10

	-- Yetişkin hayvan yoksa pano boş
	local empty: any = farm()
	empty.animals = { { uid = "c", animalId = "cow", zoneId = "starter", bornAt = 0, stage = "calf" } }
	assert(#OrderBoard.offers(empty, now, 0) == 0, "no adults means no offers")

	local data = farm()
	local offers = OrderBoard.offers(data, now, 0)
	assert(#offers == #Config.ORDER_TIERS, "one offer per tier")
	assert(offers[1].units < offers[2].units and offers[2].units < offers[3].units, "tiers grow in length")
	assert(offers[1].reward < offers[2].reward and offers[2].reward < offers[3].reward, "longer orders pay more")
	local keys: { [string]: boolean } = {}
	for _, offer in offers do
		assert(not keys[offer.key], "offer keys are unique")
		keys[offer.key] = true
	end
	local again = OrderBoard.offers(data, now + 3, 0)
	assert(
		again[1].key == offers[1].key and again[2].animalId == offers[2].animalId,
		"offers stay stable inside a window"
	)
	local later = OrderBoard.offers(data, now + Config.ORDER_BOARD_SECONDS, 0)
	assert(later[1].key ~= offers[1].key, "offers refresh in the next window")
	assert(
		OrderBoard.secondsLeft(now) > 0 and OrderBoard.secondsLeft(now) <= Config.ORDER_BOARD_SECONDS,
		"refresh countdown is bounded"
	)

	-- Mevsim etkinliği bonusu ödülü artırır
	local bonus = OrderBoard.offers(data, now, 0.3)
	assert(bonus[2].reward > offers[2].reward, "season bonus raises the reward")
	assert(OrderBoard.reward("unknown_animal", 12, 1, 0) == 0, "unknown animal pays nothing")

	-- Seçim doğrulaması: geçerli, eski pencere, sahte anahtar
	local picked = OrderBoard.resolve(data, offers[2].key, now, 0)
	assert(picked and picked.units == offers[2].units, "a current key resolves to its offer")
	local stale, staleReason = OrderBoard.resolve(data, offers[2].key, now + Config.ORDER_BOARD_SECONDS * 2, 0)
	assert(stale == nil and staleReason ~= nil, "an old window key is rejected")
	for _, bad in { 5, "", "0:0", "abc", string.rep("9", 40), {} } do
		assert(OrderBoard.resolve(data, bad, now, 0) == nil, "forged keys are rejected")
	end

	-- Ödül ölçeği: birim ve çarpan orantılı; varsayılan sipariş eski ödülle aynı
	local plain = { animalId = "cow", target = Config.ORDER_UNITS }
	assert(OrderBoard.claimReward(plain, 0) == OrderRules.reward("cow", Config), "default order keeps the old reward")
	assert(
		OrderBoard.claimReward({ animalId = "cow", target = Config.ORDER_UNITS * 2 }, 0)
			== OrderRules.reward("cow", Config) * 2,
		"reward scales with units"
	)
	assert(
		OrderBoard.claimReward({ animalId = "cow", target = Config.ORDER_UNITS, rewardFactor = 1.4 }, 0)
			> OrderRules.reward("cow", Config),
		"board factor raises the reward"
	)

	-- Hedef sınırlı ilerleme: uzun siparişte 12'de kesilmez
	assert(OrderRules.advance(0, 1, 1000, Config, 24) == 24, "progress reaches the order's own target")
	assert(OrderRules.advance(0, 1, 1000, Config) == Config.ORDER_UNITS, "default target stays ORDER_UNITS")

	-- Kayıt: hedef ve çarpan sınırlanır
	local raw = SaveCodec.encode(data, 1000)
	data.order = { uid = "o1", animalId = "cow", progress = 30, target = 24, rewardFactor = 1.4 }
	local encoded = SaveCodec.encode(data, 1000)
	local decoded = assert(SaveCodec.decode(encoded, Config, FarmMath, 2000, function()
		return "u"
	end))
	assert(decoded.order.target == 24 and decoded.order.rewardFactor == 1.4, "board order survives a save")
	assert(decoded.order.progress <= 24, "progress is clamped to the target")
	local mainFarm = encoded.mainFarms[encoded.activeMainFarmId]
	mainFarm.order.target = 9999
	mainFarm.order.rewardFactor = 99
	local clamped = assert(SaveCodec.decode(encoded, Config, FarmMath, 2000, function()
		return "u"
	end))
	assert(clamped.order.target <= 24 and clamped.order.rewardFactor <= 3, "forged target and factor are clamped")
	mainFarm.order.target = 0 / 0
	mainFarm.order.rewardFactor = "x"
	local sane = assert(SaveCodec.decode(encoded, Config, FarmMath, 2000, function()
		return "u"
	end))
	assert(
		sane.order.target == Config.ORDER_UNITS and sane.order.rewardFactor == 1,
		"invalid values fall back to defaults"
	)
	assert(raw ~= nil, "encode works without an order")
	print("PASS order board: offers, refresh, rewards, key validation and save bounds")
end
