--!strict
-- Asa yetenekleri (saf, gerçek Config/FarmMath): büyüme kısaltma, üretim kısaltma, süreli bakım geliri ve sınır durumları.
return function(StaffPowers: any, SaveCodec: any, Config: any, FarmMath: any)
	local now = 2000000000
	local function newSave(): any
		local save = assert(SaveCodec.decode(nil, Config, FarmMath, now, function(): string
			return "u"
		end))
		save.animals = {}
		save.production = {}
		return save
	end
	local function animal(uid: string, bornAt: number, stage: string, task: any?): any
		return { uid = uid, animalId = "cow", zoneId = "starter", bornAt = bornAt, stage = stage, task = task }
	end
	local total = Config.GROWTH_SECONDS.calf + Config.GROWTH_SECONDS.young
	local fraction = Config.ITEM_POWER_SETTINGS.growth.fraction

	-- Yetiştirici: yalnız yavru/genç hayvanın kalan büyümesi kısalır
	local save = newSave()
	local speed = FarmMath.getGrowthSpeed(save, "cow", "starter")
	local calf = animal("calf", now - 60, "calf")
	local starter = animal("starter", 0, "adult")
	local grown = animal("grown", now - total / speed - 10, "adult")
	save.animals = { calf, starter, grown }
	local ageBefore = (now - calf.bornAt) * speed
	assert(StaffPowers.grow(save, now, fraction, FarmMath, Config) == 1, "only the young animal changes")
	local ageAfter = (now - calf.bornAt) * speed
	assert(
		math.abs(ageAfter - (ageBefore + fraction * (total - ageBefore))) < 1e-6,
		"remaining growth shrinks by the configured fraction"
	)
	assert(starter.bornAt == 0 and grown.stage == "adult", "starter adults and grown animals are untouched")
	assert(calf.stage == FarmMath.getStage(calf.bornAt, now, speed), "the stage follows the new birth time")
	for _ = 1, 200 do
		StaffPowers.grow(save, now, fraction, FarmMath, Config)
	end
	assert(
		calf.bornAt >= 1 and (now - calf.bornAt) * speed <= total + 1e-6,
		"repeated uses never overshoot or write the starter-adult marker"
	)
	assert(StaffPowers.grow({ animals = {} }, now, fraction, FarmMath, Config) == 0, "no animals, no change")
	local untouched = animal("x", now - 60, "calf")
	local before = untouched.bornAt
	save.animals = { untouched }
	for _, bad in { 0, -1, 2, 0 / 0, math.huge, "x" } do
		assert(StaffPowers.grow(save, now, bad :: any, FarmMath, Config) == 0, "invalid fraction changes nothing")
	end
	assert(untouched.bornAt == before, "invalid fraction leaves animals alone")
	local tiny = animal("tiny", now - 1e-3, "calf")
	save.animals = { tiny }
	assert(
		StaffPowers.grow(save, now, 1, FarmMath, Config) == 1 and tiny.stage == "adult",
		"full fraction finishes growth"
	)
	assert(tiny.bornAt >= 1, "the adult marker 0 is never written")

	-- Üretim: kalan süre kısalır, görevdeki hayvanlar ve kaçırılan gelir tabanı uyumlu kalır
	local farm: any = newSave()
	local worker =
		animal("w1", 0, "adult", { kind = "production", id = "packed_milk", startedAt = now - 100, endsAt = now + 400 })
	local other =
		animal("w2", 0, "adult", { kind = "production", id = "hatchery", startedAt = now - 100, endsAt = now + 999 })
	farm.animals = { worker, other }
	farm.production = {
		packed_milk = { uid = "j1", startedAt = now - 100, readyAt = now + 400, forgone = 500 },
		done = { uid = "j2", startedAt = now - 500, readyAt = now - 5, forgone = 10 },
		broken = { uid = "j3", startedAt = now, readyAt = 0 / 0 },
		endless = { uid = "j4", startedAt = now, readyAt = math.huge },
	}
	local rushFraction = Config.ITEM_POWER_SETTINGS.rush.fraction
	assert(StaffPowers.rush(farm, now, rushFraction) == 1, "only the running, valid job is shortened")
	local job = farm.production.packed_milk
	local expectedReady = now + 400 * (1 - rushFraction)
	assert(math.abs(job.readyAt - expectedReady) < 1e-6, "remaining time shrinks by the configured fraction")
	assert(worker.task.endsAt == job.readyAt, "the job's workers finish with it")
	assert(other.task.endsAt == now + 999, "other jobs' workers are untouched")
	assert(
		math.abs(job.forgone - 500 * (expectedReady - (now - 100)) / 500) < 1e-6,
		"the forgone-income floor scales with the real duration"
	)
	assert(
		farm.production.done.readyAt == now - 5 and farm.production.done.forgone == 10,
		"finished jobs are untouched"
	)
	assert(farm.production.endless.readyAt == math.huge, "corrupt jobs are ignored")
	farm.production = {}
	assert(StaffPowers.rush(farm, now, rushFraction) == 0, "no running production, no change")
	assert(
		StaffPowers.rush({ animals = {}, production = { a = { readyAt = now + 10 } } }, now, 0 / 0) == 0,
		"bad fraction"
	)

	-- Bakıcı: süreli +gelir; etkinken yenilenmez, süre bitince yeniden başlar
	local root: any = newSave()
	local settings = Config.ITEM_POWER_SETTINGS.care
	assert(StaffPowers.care(root, now, settings.seconds, settings.bonus) == 1, "care starts")
	assert(
		root.careBoost.endsAt == now + settings.seconds and root.careBoost.bonus == settings.bonus,
		"window and bonus"
	)
	assert(StaffPowers.care(root, now + 1, settings.seconds, settings.bonus) == 0, "an active care is not extended")
	assert(
		StaffPowers.care(root, now + settings.seconds, settings.seconds, settings.bonus) == 1,
		"care can restart once the window ends"
	)
	for _, bad in { { 0, 0.1 }, { -5, 0.1 }, { 60, 0 }, { 60, 2 }, { 0 / 0, 0.1 }, { 60, 0 / 0 } } do
		local fresh: any = {}
		assert(StaffPowers.care(fresh, now, bad[1], bad[2]) == 0 and fresh.careBoost == nil, "invalid care is rejected")
	end

	-- Gelir: anlık oran ve aralık geliri bakım penceresiyle kesişen kısımda +bonus alır
	local earner: any = newSave()
	earner.animals = { animal("a", 0, "adult"), animal("b", 0, "adult") }
	local base = FarmMath.computeIncomePerSecond(earner, now)
	assert(base > 0, "the test farm earns income")
	local baseInterval = FarmMath.computeIncomeOverInterval(earner, now - 100, now + 100)
	earner.careBoost = { startedAt = now, endsAt = now + 50, bonus = settings.bonus }
	assert(
		math.abs(FarmMath.computeIncomePerSecond(earner, now + 10) - base * (1 + settings.bonus)) < 1e-9,
		"live income rises while the care is active"
	)
	assert(FarmMath.computeIncomePerSecond(earner, now + 60) == base, "live income is normal after the window")
	assert(FarmMath.computeIncomePerSecond(earner, now - 1) == base, "and before the window")
	local boosted = FarmMath.computeIncomeOverInterval(earner, now - 100, now + 100)
	local expected = baseInterval + settings.bonus * baseInterval * (50 / 200)
	assert(math.abs(boosted - expected) < 1e-6, "interval income adds the bonus only on the overlap")
	assert(
		FarmMath.computeIncomeOverInterval(earner, now + 60, now + 160)
			== FarmMath.computeIncomeOverInterval(newSave().animals and earner, now + 60, now + 160),
		"an interval after the window is unaffected"
	)
	for _, bad in
		{
			{ startedAt = now, endsAt = now - 5, bonus = 0.1 },
			{ startedAt = now, endsAt = now + 50, bonus = 5 },
			{ startedAt = now, endsAt = now + 50, bonus = 0 / 0 },
			{ startedAt = now, endsAt = now + 50, bonus = -0.1 },
			{ startedAt = "x", endsAt = now + 50, bonus = 0.1 },
			"junk",
		}
	do
		earner.careBoost = bad
		assert(FarmMath.computeIncomePerSecond(earner, now + 10) == base, "corrupt care records are ignored")
		assert(FarmMath.computeIncomeOverInterval(earner, now - 100, now + 100) == baseInterval, "interval too")
	end
	-- Kayıt şeması: bakım çalışma anıdır, kaydedilmez
	earner.careBoost = { startedAt = now, endsAt = now + 50, bonus = settings.bonus }
	local encoded = SaveCodec.encode(earner, now)
	assert(encoded.careBoost == nil, "care is never persisted")
	print("PASS staff powers: growth/production shortening, timed care income, bounds and corrupt records")
end
