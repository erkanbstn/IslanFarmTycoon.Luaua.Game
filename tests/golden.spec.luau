--!strict
-- Altın hayvan: pencere, hayvan seçimi, ödül ve "pencere başına bir kez" kuralı (saf, gerçek Config/FarmMath).
return function(Golden: any, Config: any, FarmMath: any)
	local settings = Config.GOLDEN
	local function newSave(adults: number): any
		local data: any = {
			cash = 0,
			stored = 0,
			purchased = {},
			animals = {},
			barnLevel = 1,
			unlockedIslands = {},
			unlockedZones = {},
			ordersCompleted = 0,
			production = {},
			activeMainFarmId = "1",
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

	-- Pencere sınırları
	local windows, total = 0, 400
	for cycle = 0, total - 1 do
		local span = Golden.window(4321, cycle * settings.cycleSeconds + 1)
		if span then
			windows += 1
			assert(span.cycle == cycle and span.endsAt - span.startsAt == settings.windowSeconds, "window length")
			assert(
				span.startsAt >= cycle * settings.cycleSeconds and span.endsAt <= (cycle + 1) * settings.cycleSeconds,
				"window fits its cycle"
			)
		end
	end
	assert(math.abs(windows / total - settings.chance) < 0.12, "window frequency follows the configured chance")

	-- Olay
	local userId = 99
	local startsAt: number? = nil
	for cycle = 0, 200 do
		local span = Golden.window(userId, cycle * settings.cycleSeconds + 1)
		if span then
			startsAt = span.startsAt + 1
			break
		end
	end
	assert(startsAt, "the test player gets a window soon")
	local now = startsAt :: number
	local farm = newSave(4)
	local event = Golden.current(farm, userId, now)
	assert(event, "an open window with adults has an event")
	assert(
		event.animalId == "cow" and string.find(event.uid, "^a%d$"),
		"the glowing animal is one of the player's adults"
	)
	assert(event.reward >= settings.minReward, "reward has a floor")
	assert(Golden.current(farm, userId, now + 1).uid == event.uid, "the same animal glows for the whole window")
	assert(Golden.current(farm, userId, now + settings.windowSeconds + 1) == nil, "no event after the window")

	-- Bir kez: aynı pencerede alındıysa yok; başka pencerede yeniden olur
	farm.golden = { key = event.cycle }
	assert(Golden.current(farm, userId, now) == nil, "a claimed window cannot be claimed again")
	farm.golden = { key = event.cycle - 1 }
	assert(Golden.current(farm, userId, now), "an older claim does not block this window")

	-- Yetişkin yoksa olay yok; yavru sayılmaz
	local calves = newSave(0)
	table.insert(calves.animals, { uid = "c", animalId = "cow", zoneId = "starter", bornAt = now, stage = "calf" })
	assert(Golden.current(calves, userId, now) == nil, "calves never glow")

	-- Ödül hayvanın gelirine ölçeklenir
	local baseReward = Golden.current(newSave(4), userId, now).reward
	local rich = newSave(4)
	rich.purchased.milk_machine = true
	FarmMath.applyDerived(rich)
	local boosted = Golden.current(rich, userId, now)
	assert(boosted and boosted.reward >= baseReward, "a stronger farm earns a larger reward")
	print("PASS golden: windows, frequency, stable animal, reward floor and once-per-window rule")
end
