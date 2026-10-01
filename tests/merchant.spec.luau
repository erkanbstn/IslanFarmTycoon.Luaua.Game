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
	-- Gerçek zaman ölçeği (Workspace:GetServerTimeNow ~ 1.7e9): küçük sayılarla geçen testler büyük döngü numaralarında
	-- bozulan rastgeleliği yakalayamazdı. 2 saatte ortalama ziyaret sayısı beklenen bantta olmalı.
	local epoch = 1.76e9
	local hourCycles = math.floor(7200 / settings.cycleSeconds)
	local sampleUsers = { 1, 777, 98765, 1234567, 55555555, 4567890123, 3000000001, 9876543210 }
	local twoHourVisits = 0
	for _, sampleUser in sampleUsers do
		for cycle = 0, hourCycles - 1 do
			if Merchant.visit(sampleUser, epoch + cycle * settings.cycleSeconds) then
				twoHourVisits += 1
			end
		end
	end
	local averageVisits = twoHourVisits / #sampleUsers
	local expectedVisits = hourCycles * settings.chance
	assert(
		averageVisits >= expectedVisits * 0.6 and averageVisits <= math.min(hourCycles, expectedVisits * 1.4),
		`visits in 2 hours at real timestamps: {averageVisits} (expected about {expectedVisits})`
	)
	assert(averageVisits >= 4, "a long session meets the merchant several times")
	-- Oturum uzunluğu: ~20 dk oynayan oyuncu ortalama en az bir ziyaret yakalamalı ve çoğu oturumda en az birini görmeli
	for _, sampleUser in sampleUsers do
		local sessions, caught, seenVisits = 0, 0, 0
		for startOffset = 0, 30 * 3600, 211 do
			sessions += 1
			local cyclesSeen: { [number]: boolean } = {}
			local count = 0
			for t = epoch + startOffset, epoch + startOffset + 1200, 20 do
				local visit = Merchant.visit(sampleUser, t)
				if visit and visit.active and not cyclesSeen[visit.cycle] then
					cyclesSeen[visit.cycle] = true
					count += 1
				end
			end
			seenVisits += count
			if count > 0 then
				caught += 1
			end
		end
		assert(caught / sessions >= 0.75, `a 20 min session catches a visit: {caught / sessions} (user {sampleUser})`)
		assert(seenVisits / sessions >= 1, `20 min sessions average {seenVisits / sessions} visits (user {sampleUser})`)
	end

	-- İstemci ve sunucu aynı teklifi üretir: istemci kesirli sunucu saatini, sunucu tam saniyeyi kullanır
	local syncFarm = newSave()
	local syncUser = 424242
	local syncVisit: any = nil
	for cycle = 0, 60 do
		syncVisit = Merchant.visit(syncUser, epoch + cycle * settings.cycleSeconds)
		if syncVisit then
			break
		end
	end
	assert(syncVisit, "sync player has a visit")
	local serverNow = syncVisit.startsAt + 10
	local serverOffer = Merchant.offer(syncFarm, syncUser, serverNow)
	local clientStatus = Merchant.status(syncFarm, syncUser, serverNow + 0.37)
	assert(serverOffer and clientStatus.offer, "both sides see the offer")
	local clientOffer: any = clientStatus.offer
	assert(
		clientOffer.animalId == serverOffer.animalId
			and clientOffer.count == serverOffer.count
			and clientOffer.price == serverOffer.price
			and clientOffer.cycle == serverOffer.cycle
			and clientOffer.endsAt == serverOffer.endsAt,
		"client and server compute the same offer"
	)
	assert(clientStatus.visit and clientStatus.visit.active and not clientStatus.bought, "status reports the visit")

	-- Ziyaret takibi: geliş bir kez, alınmadan bitince "kaçırdın", alınırsa sessiz
	local tracker = Merchant.newTracker()
	local function statusAt(t: number): any
		return Merchant.status(syncFarm, syncUser, t)
	end
	assert(Merchant.advance(tracker, statusAt(syncVisit.startsAt - 1)) == nil, "quiet before the visit")
	assert(Merchant.advance(tracker, statusAt(serverNow)) == "arrived", "arrival is announced")
	assert(Merchant.advance(tracker, statusAt(serverNow + 5)) == nil, "arrival is announced once")
	assert(
		Merchant.advance(tracker, statusAt(syncVisit.endsAt + 1)) == "missed",
		"an unbought visit is reported missed"
	)
	assert(Merchant.advance(tracker, statusAt(syncVisit.endsAt + 2)) == nil, "missed is reported once")
	syncFarm.merchant = { key = syncVisit.cycle, bought = true }
	local boughtTracker = Merchant.newTracker()
	syncFarm.merchant = nil
	assert(Merchant.advance(boughtTracker, statusAt(serverNow)) == "arrived", "arrival before buying")
	syncFarm.merchant = { key = syncVisit.cycle, bought = true }
	assert(Merchant.advance(boughtTracker, statusAt(serverNow + 5)) == nil, "buying is not a miss")
	assert(Merchant.advance(boughtTracker, statusAt(syncVisit.endsAt + 1)) == nil, "a bought visit is never missed")

	-- Al-sat marjı: en iyi eşya takımıyla satış iadesi, tüccar fiyatının altında kalmalı (tüccardan al, geri sat = kâr yok)
	local bestPerSlot: { [string]: number } = {}
	for _, item in Config.ITEMS do
		local bonus = if item.effects and item.effects.sellBonus then item.effects.sellBonus else 0
		if bonus > (bestPerSlot[item.slot] or 0) then
			bestPerSlot[item.slot] = bonus
		end
	end
	local maxSellBonus = 0
	for _, bonus in bestPerSlot do
		maxSellBonus += bonus
	end
	local maxRefund = Config.ANIMAL_SELL_FRACTION * (1 + maxSellBonus)
	assert(
		maxRefund < 1 - settings.discount,
		`sell refund {maxRefund} must stay below the merchant price ratio {1 - settings.discount}`
	)

	print("PASS merchant: visit windows, frequency, offer selection, discount and once-per-visit rule")
end
