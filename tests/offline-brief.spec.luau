--!strict
-- Dönüş özeti ek alanları (sunucuda kayıttan): günlük ödül, hazır sipariş, gezgin tüccar, altın hayvan.
-- Alanlar isteğe bağlıdır: ilgili değilse yazılmaz; bir hesap hata verse bile diğerleri çalışır.
return function(OfflineBrief: any, FarmMath: any, Rewards: any, Merchant: any, Golden: any)
	local userId = 4242
	local function newSave(adults: number): any
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
			inventory = { items = {}, equipped = {}, uses = {} },
		}
		FarmMath.applyDerived(data)
		for index = 1, adults do
			table.insert(
				data.animals,
				{ uid = `a{index}`, animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" }
			)
		end
		return data
	end
	local real = { Rewards = Rewards, FarmMath = FarmMath, Merchant = Merchant, Golden = Golden }
	-- Rastgele olaylar kimlik+zamandan türer: "sakin" senaryo için ikisinin de kapalı olduğu bir an bulunur.
	local now = 1.7e9
	for step = 0, 5000 do
		local candidate = 1.7e9 + step * 997
		if not Merchant.currentVisit(newSave(0), userId, candidate) and not Golden.window(userId, candidate) then
			now = candidate
			break
		end
	end
	assert(
		not Merchant.currentVisit(newSave(0), userId, now) and not Golden.window(userId, now),
		"sakin bir an bulundu"
	)

	-- Sakin kayıt: yalnızca günlük ödül (hiç alınmamış) görünür; ilgisiz alanlar yazılmaz
	local calm = OfflineBrief.build(newSave(2), userId, now, real)
	assert(calm.daily == true, "alınmamış günlük ödül görünür")
	assert(calm.orders == nil and calm.merchant == nil and calm.golden == nil, "ilgisiz alanlar yazılmaz")
	local claimed = newSave(2)
	claimed.daily = { day = Rewards.dayIndex(now), streak = 1 }
	assert(Rewards.dailyStatus(claimed.daily, now).canClaim == false, "fixture gerçekten alınmış")
	local none = OfflineBrief.build(claimed, userId, now, real)
	assert(next(none) == nil, "bugün alınmış ödülde ve sakin kayıtta özet boş (tüm alanlar yok)")

	-- Gezgin tüccar ve altın hayvan: yönetici zorlaması (çalışma anı alanı) gerçek hesabı açar
	local event = newSave(3)
	event.daily = claimed.daily
	event.adminForce = { merchantUntil = now + 600, goldenUntil = now + 600 }
	local live = OfflineBrief.build(event, userId, now, real)
	assert(live.merchant == true and live.golden == true, "tüccar ve altın hayvan etkinken görünür")
	assert(live.daily == nil, "alınmış günlük ödül görünmez")
	event.merchant = { key = Merchant.status(event, userId, now).visit.cycle, bought = true }
	assert(
		OfflineBrief.build(event, userId, now, real).merchant == nil,
		"tekliften alım yapıldıysa tüccar satırı yok"
	)
	local noAdults = newSave(0)
	noAdults.daily = claimed.daily
	noAdults.adminForce = { goldenUntil = now + 600 }
	assert(OfflineBrief.build(noAdults, userId, now, real).golden == nil, "yetişkin hayvan yoksa altın hayvan yok")

	-- Sipariş sayısı: sunucu hesabı, 1+ ve üst sınırlı tam sayı
	local function withOrders(count: any): any
		return {
			Rewards = Rewards,
			Merchant = Merchant,
			Golden = Golden,
			FarmMath = {
				getReadyContractCount = function(_save: any, _now: number, bonus: any): any
					assert(bonus == 0, "sipariş hesabı bonussuz (HUD ile aynı)")
					return count
				end,
			},
		}
	end
	assert(OfflineBrief.build(claimed, userId, now, withOrders(3)).orders == 3, "hazır sipariş sayısı")
	assert(OfflineBrief.build(claimed, userId, now, withOrders(0)).orders == nil, "sıfır sipariş yazılmaz")
	assert(OfflineBrief.build(claimed, userId, now, withOrders(2.9)).orders == 2, "tam sayıya indirilir")
	assert(OfflineBrief.build(claimed, userId, now, withOrders(5000)).orders == OfflineBrief.MAX_ORDERS, "üst sınır")
	assert(OfflineBrief.build(claimed, userId, now, withOrders("x")).orders == nil, "geçersiz tür yazılmaz")

	-- Hata yalıtımı: biri hata verirse diğerleri yine hesaplanır; özet asla hata fırlatmaz
	local broken = {
		Rewards = {
			dailyStatus = function()
				error("boom")
			end,
		},
		FarmMath = {
			getReadyContractCount = function(): number
				return 2
			end,
		},
		Merchant = {
			status = function()
				error("boom")
			end,
		},
		Golden = {
			current = function(): any
				return { uid = "x" }
			end,
		},
	}
	local partial = OfflineBrief.build(claimed, userId, now, broken)
	assert(
		partial.daily == nil and partial.merchant == nil and partial.orders == 2 and partial.golden == true,
		"tek bir hesabın hatası diğer alanları engellemez"
	)

	-- Kayıtta yeni kalıcı alan yazılmaz (yalnız okuma)
	local before = newSave(3)
	local snapshot = table.clone(before)
	OfflineBrief.build(before, userId, now, real)
	local count, snapshotCount = 0, 0
	for key, value in snapshot do
		snapshotCount += 1
		assert(before[key] == value, `kayıt değişmedi: {key}`)
	end
	for _ in before do
		count += 1
	end
	assert(count == snapshotCount, "özet kayda yeni alan eklemez")
end
