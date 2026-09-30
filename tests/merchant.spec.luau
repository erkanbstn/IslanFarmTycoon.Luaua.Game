--!strict
-- Gezgin tüccar: ziyaret pencereleri, olasılık, teklif seçimi ve "döngü başına bir kez" kuralı (saf, gerçek Config/FarmMath).
return function(Merchant: any, Config: any, FarmMath: any)
	local settings = Config.MERCHANT
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

	-- Pencere sınırları ve kararlılık
	local visits, total = 0, 400
	for cycle = 0, total - 1 do
		local now = cycle * settings.cycleSeconds + 1
		local visit = Merchant.visit(1234, now)
		assert(visit == nil or Merchant.visit(1234, now).startsAt == visit.startsAt, "visits are deterministic")
		if visit then
			visits += 1
			assert(visit.cycle == cycle, "visit belongs to its cycle")
			assert(
				visit.startsAt >= cycle * settings.cycleSeconds
					and visit.endsAt <= (cycle + 1) * settings.cycleSeconds
					and visit.endsAt - visit.startsAt == settings.visitSeconds,
				"a visit fits inside its cycle"
			)
			assert(Merchant.visit(1234, visit.startsAt).active, "active at arrival")
			assert(not Merchant.visit(1234, visit.endsAt).active, "gone at departure")
		end
	end
	assert(math.abs(visits / total - settings.chance) < 0.12, "visit frequency follows the configured chance")
	local differs = false
	for cycle = 0, 40 do
		local a = Merchant.visit(1, cycle * settings.cycleSeconds + 1)
		local b = Merchant.visit(2, cycle * settings.cycleSeconds + 1)
		if (a == nil) ~= (b == nil) or (a and b and a.startsAt ~= b.startsAt) then
			differs = true
		end
	end
	assert(differs, "different players get different visit times")

	-- Teklif
	local userId = 777
	local activeAt: number? = nil
	local cycleAt = 0
	for cycle = 0, 200 do
		local visit = Merchant.visit(userId, cycle * settings.cycleSeconds + 1)
		if visit then
			activeAt, cycleAt = visit.startsAt + 1, cycle
			break
		end
	end
	assert(activeAt, "the test player gets a visit soon")
	local now = activeAt :: number
	local farm = newSave()
	local offer = Merchant.offer(farm, userId, now)
	assert(offer, "an active visit makes an offer")
	assert(Config.ANIMALS[offer.animalId], "the offer is a real animal")
	assert(FarmMath.findZoneForAnimal(farm, offer.animalId), "the offered animal can actually be placed")
	assert(offer.count >= 1 and offer.count <= settings.stock, "stock is respected")
	assert(offer.count <= FarmMath.getFreeSlots(farm, offer.animalId), "no more than the free slots")
	assert(offer.fullPrice == FarmMath.getBulkPrice(farm, offer.animalId, offer.count), "full price is the bulk price")
	assert(
		offer.price == math.floor(offer.fullPrice * (1 - settings.discount)) and offer.price < offer.fullPrice,
		"discount applied"
	)
	assert(offer.cycle == cycleAt and offer.endsAt > now, "the offer knows its cycle and departure")

	-- Döngü başına bir kez; sonraki döngüde yeniden teklif edilebilir
	farm.merchant = { key = offer.cycle, bought = true }
	assert(Merchant.offer(farm, userId, now) == nil, "an already bought offer is not repeated in the same visit")
	farm.merchant = { key = offer.cycle - 1, bought = true }
	assert(Merchant.offer(farm, userId, now), "a marker from an older cycle does not block this visit")
	assert(Merchant.offer(farm, userId, now + settings.visitSeconds + 1) == nil, "no offer after the merchant leaves")

	-- Yer yoksa teklif yok: başlangıç bölgesi dolunca satın alınabilir hayvan kalmaz
	farm.merchant = nil
	while FarmMath.findZoneForAnimal(farm, "cow") do
		table.insert(
			farm.animals,
			{ uid = `x{#farm.animals}`, animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" }
		)
	end
	local everyAnimalBlocked = true
	for _, animalId in Config.ANIMAL_ORDER do
		if FarmMath.findZoneForAnimal(farm, animalId) then
			everyAnimalBlocked = false
		end
	end
	if everyAnimalBlocked then
		assert(Merchant.offer(farm, userId, now) == nil, "a full farm gets no offer")
	end
	-- Yönetici zorlaması: ziyaret yokken bile teklif çıkar, süre bitince kaybolur
	local quietAt: number? = nil
	for cycle = 0, 400 do
		local t = cycle * settings.cycleSeconds + 1
		local visit = Merchant.visit(userId, t)
		if not visit or not visit.active then
			quietAt = t
			break
		end
	end
	assert(quietAt, "the test player has a quiet moment")
	local quiet = quietAt :: number
	local forcedFarm = newSave()
	assert(Merchant.offer(forcedFarm, userId, quiet) == nil, "no offer outside a visit")
	forcedFarm.adminForce = { merchantUntil = quiet + 100 }
	local forcedOffer = Merchant.offer(forcedFarm, userId, quiet)
	assert(forcedOffer and forcedOffer.endsAt == quiet + 100, "an admin-forced visit makes an offer")
	assert(Merchant.offer(forcedFarm, userId, quiet + 101) == nil, "a forced visit ends on time")
	forcedFarm.merchant = { key = forcedOffer.cycle, bought = true }
	assert(Merchant.offer(forcedFarm, userId, quiet) == nil, "a forced visit still respects the bought marker")
	print("PASS merchant: visit windows, frequency, offer selection, discount and once-per-visit rule")
end
