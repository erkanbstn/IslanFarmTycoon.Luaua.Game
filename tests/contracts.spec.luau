--!strict
-- Ahır siparişleri: teklif üretimi, atomik teslim, pencere yenilenmesi ve kayıt.
return function(codec: any, config: any, farmMath: any)
	local now = 600000 * 7 + 30
	local serial = 0
	local function uid(): string
		serial += 1
		return `contracts-test-{serial}`
	end
	local function newSave(buildAll: boolean): any
		local save = assert(codec.decode(nil, config, farmMath, now, uid), "fixture decode failed")
		if buildAll then
			for _, upgrade in config.UPGRADES do
				if not upgrade.leveled then
					save.purchased[upgrade.id] = true
				end
			end
			farmMath.applyDerived(save)
		end
		return save
	end
	local function fill(save: any)
		for _, goodsId in config.GOODS_ORDER do
			farmMath.addGoods(save, goodsId, farmMath.getGoodsCap(save))
		end
	end

	-- Ürün merkezi yoksa teklif yok
	local fresh = newSave(false)
	assert(#farmMath.getContractOffers(fresh, now, 0) == 0, "no item center means no barn orders")
	assert(farmMath.getReadyContractCount(fresh, now, 0) == 0, "nothing is ready without offers")

	-- Teklifler: kademe başına bir teklif; satır sayısı kademeyle artar, ödül ürün değerinin üstündedir
	local save = newSave(true)
	local islandBonus = farmMath.getBonus(save, "contractBonus") -- ada yükseltmelerinden gelen sipariş bonusu (At Adası)
	local offers = farmMath.getContractOffers(save, now, 0)
	assert(#offers == config.GOODS_CONTRACTS.slots, "one offer per grid slot")
	local cap = farmMath.getGoodsCap(save)
	for index, offer in offers do
		local tier: any = nil
		for _, candidate in config.GOODS_CONTRACTS.tiers do
			if candidate.id == offer.tier then
				tier = candidate
			end
		end
		assert(tier, "every offer uses a configured tier")
		assert(offer.key == `{farmMath.getContractWindow(now)}:{index}`, "keys carry the window and slot")
		assert(#offer.lines == tier.lines, "line count follows the tier")
		local seen: { [string]: boolean } = {}
		local worth = 0
		for _, line in offer.lines do
			assert(not seen[line.goodsId], "an offer never asks for the same good twice")
			seen[line.goodsId] = true
			assert(line.amount >= 1 and line.amount <= cap, "amounts always fit in the barn")
			worth += line.amount * config.GOODS[line.goodsId].value
		end
		assert(
			offer.worth == worth and offer.reward == math.floor(worth * tier.rewardFactor * (1 + islandBonus)),
			"reward follows worth"
		)
		assert(offer.reward > worth, "delivering beats the raw goods value")
		assert(offer.rewardFactor == tier.rewardFactor, "the tier sets the reward rate")
		for _, line in offer.lines do
			local low = math.max(1, math.floor(tier.units * (1 - config.GOODS_CONTRACTS.variation)))
			local high = math.ceil(tier.units * (1 + config.GOODS_CONTRACTS.variation))
			assert(line.amount >= low and line.amount <= math.min(high, cap), "units vary only inside the tier band")
		end
	end
	-- Rastgelelik: aynı pencere her seferinde aynı teklifleri verir; pencereler farklıdır; kademeler ve ürünler çeşitlenir
	local replay = farmMath.getContractOffers(save, now, 0)
	for index, offer in offers do
		assert(replay[index].tier == offer.tier and replay[index].worth == offer.worth, "a window is deterministic")
	end
	local tiersSeen: { [string]: boolean } = {}
	local goodsSeen: { [string]: boolean } = {}
	local differentWindows = false
	for window = 1, 30 do
		local sample = farmMath.getContractOffers(save, now + window * config.GOODS_CONTRACTS.seconds, 0)
		for index, offer in sample do
			tiersSeen[offer.tier] = true
			for _, line in offer.lines do
				goodsSeen[line.goodsId] = true
			end
			if offer.tier ~= offers[index].tier or offer.worth ~= offers[index].worth then
				differentWindows = true
			end
		end
	end
	local tierCount, goodsCount = 0, 0
	for _ in tiersSeen do
		tierCount += 1
	end
	for _ in goodsSeen do
		goodsCount += 1
	end
	assert(differentWindows, "windows differ from each other")
	assert(tierCount >= 5, "most tiers show up across windows")
	assert(goodsCount >= 6, "most goods show up across windows")
	local seasonal = farmMath.getContractOffers(save, now, 0.5)
	assert(
		seasonal[1].reward == math.floor(offers[1].worth * offers[1].rewardFactor * (1.5 + islandBonus)),
		"season bonus applies"
	)
	-- Takılı muskalar: sipariş ödülü ve ürün merkezi verimi artar
	local milkRecipe = config.PRODUCTION_RECIPES.milk_goods
	local plainYield = farmMath.getGoodsYield(save, milkRecipe, now)
	save.inventory = {
		items = { contract_charm_2 = true, barn_charm_2 = true },
		equipped = { charm = "contract_charm_2" },
	}
	local charmed = farmMath.getContractOffers(save, now, 0)
	assert(charmed[1].reward > offers[1].reward, "the merchant ledger raises delivery rewards")
	assert(
		charmed[1].reward == math.floor(offers[1].worth * offers[1].rewardFactor * (1 + 0.14 + islandBonus)),
		"exact charm bonus"
	)
	save.inventory.equipped = { charm = "barn_charm_2" }
	assert(farmMath.getGoodsYield(save, milkRecipe, now) > plainYield, "the barn key raises production center yield")
	save.inventory = nil
	assert(offers[1].key == `{farmMath.getContractWindow(now)}:1`, "keys carry the window")
	assert(farmMath.getContractSecondsLeft(now) > 0, "the board has time left")

	-- Yetersiz ürün: hiçbir şey değişmez
	local beforeCompleted = if save.contracts then save.contracts.completed else 0
	local reward, reason = farmMath.fulfillContract(save, offers[1].key, now, 0)
	assert(reward == nil and reason == "Ahır deposunda yeterli ürün yok", "an empty barn cannot deliver")
	assert(next(save.goods) == nil and save.contracts.completed == beforeCompleted, "a failed delivery changes nothing")

	-- Teslim: ürünler tam düşer, ödül tekliften gelir, tekrar teslim edilemez
	fill(save)
	assert(farmMath.getReadyContractCount(save, now, 0) == #offers, "a full barn makes every offer ready")
	local stock = {}
	for _, line in offers[2].lines do
		stock[line.goodsId] = farmMath.getGoodsAmount(save, line.goodsId)
	end
	local paid = farmMath.fulfillContract(save, offers[2].key, now, 0)
	assert(paid == offers[2].reward, "the offer's reward is returned")
	for _, line in offers[2].lines do
		assert(farmMath.getGoodsAmount(save, line.goodsId) == stock[line.goodsId] - line.amount, "exact goods removed")
	end
	assert(farmMath.isContractDone(save, offers[2]) and save.contracts.completed == beforeCompleted + 1, "marked done")
	local again, againReason = farmMath.fulfillContract(save, offers[2].key, now + 5, 0)
	assert(again == nil and againReason ~= nil, "the same offer cannot be delivered twice in a window")
	assert(farmMath.getReadyContractCount(save, now, 0) == #offers - 1, "delivered offers are no longer ready")
	for _, bad in { "", "x", "0:0", "9999999:1", {}, 5, string.rep("9", 40) } do
		assert(farmMath.fulfillContract(save, bad, now, 0) == nil, "invalid or foreign keys are rejected")
	end

	-- Yeni pencerede pano yenilenir ve teslimler sıfırlanır
	local later = now + config.GOODS_CONTRACTS.seconds
	local fresherOffers = farmMath.getContractOffers(save, later, 0)
	assert(fresherOffers[1].key ~= offers[1].key, "the next window has new keys")
	assert(not farmMath.isContractDone(save, fresherOffers[2]), "a new window starts with nothing delivered")
	assert(farmMath.fulfillContract(save, offers[1].key, later, 0) == nil, "an old window's key is rejected")
	assert(farmMath.fulfillContract(save, fresherOffers[2].key, later, 0) ~= nil, "new window offers can be delivered")
	assert(save.contracts.window == farmMath.getContractWindow(later), "the record follows the window")

	-- Kayıt: gidiş-dönüş, bozuk kayıt reddi, sınırlar
	local snap = codec.encode(save, later)
	local reloaded = assert(codec.decode(snap, config, farmMath, later, uid), "saved contracts reload")
	assert(reloaded.contracts.completed == save.contracts.completed, "the counter survives")
	assert(reloaded.contracts.done[fresherOffers[2].key] == true, "delivered keys survive")
	assert(reloaded.contracts.window == save.contracts.window, "the window survives")
	local function withContracts(value: any): any
		local copy = table.clone(snap)
		copy.contracts = value
		return copy
	end
	assert(codec.decode(withContracts("broken"), config, farmMath, later, uid) == nil, "a broken record fails closed")
	local repaired = assert(
		codec.decode(
			withContracts({
				window = -5,
				completed = 1e30,
				done = { a = true, b = true, c = true, d = true, e = true, [5] = true },
			}),
			config,
			farmMath,
			later,
			uid
		),
		"messy contracts are repaired"
	)
	local kept = 0
	for _ in repaired.contracts.done do
		kept += 1
	end
	assert(kept <= config.GOODS_CONTRACTS.slots, "delivered keys are bounded")
	assert(repaired.contracts.window == 0 and repaired.contracts.completed <= 1e9, "numbers are clamped")
	print("PASS contracts: offers, atomic delivery, windows, season bonus and save repairs")
end
