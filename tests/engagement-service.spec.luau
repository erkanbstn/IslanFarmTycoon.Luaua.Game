--!strict
-- Geri getiren döngüler: gerçek servis kaynağı; günlük ödül, başarım, mevsim hedefi, altın hayvan ve mevsim imzası yuvarlaması.
return function(
	createService: any,
	createHarness: any,
	createLimiter: any,
	codec: any,
	config: any,
	farmMath: any,
	rewards: any
)
	local harness = createHarness(createLimiter, codec, config, farmMath)
	local function setup(now: number?): any
		local h = harness.new()
		if now then
			h.now = now
		end
		createService(
			h.game,
			h.remotes,
			h.dataService,
			h.economyService,
			h.plotService,
			h.limiter,
			h.metrics,
			h.dateTime,
			h.task,
			h.warn,
			h.guard
		).init()
		return h
	end
	local function claim(h: any, remote: string, value: any?, farmId: any?): any
		return h.fire(remote, value, h.nextId(), farmId or h.data.activeMainFarmId)
	end

	-- Günlük ödül: tutar sunucuda hesaplanır, gün işareti önce yazılır, aynı gün ikinci kez alınamaz
	local h = setup()
	local data = h.data
	local expected = rewards.dailyAmount(data, 1)
	local reply = claim(h, "RequestClaimDaily")
	assert(reply and reply.remote == "PurchaseResult" and reply.ok == true, "the owner can claim the daily reward")
	assert(data.cash == expected and data.daily and data.daily.streak == 1, "the server-computed amount is paid")
	assert(
		h.counters.pushes == 1 and h.counters.saves == 1 and h.metricCounts.DailyRewardsClaimed == 1,
		"pushed, saved, counted"
	)
	local again = claim(h, "RequestClaimDaily")
	assert(
		again and again.ok == false and again.message == "Günlük ödülünü bugün zaten aldın",
		"no second claim today"
	)
	assert(data.cash == expected, "a refused claim pays nothing")

	-- Tekrar eden istek kimliği, hız sınırı, yabancı oyuncu, hazır olmayan dünya
	local replayed = setup()
	local id = replayed.nextId()
	assert(replayed.fire("RequestClaimDaily", nil, id, replayed.data.activeMainFarmId).ok == true, "first claim")
	local cashAfter = replayed.data.cash
	assert(
		replayed.fire("RequestClaimDaily", nil, id, replayed.data.activeMainFarmId) == nil,
		"a replayed id gets no reply"
	)
	assert(replayed.data.cash == cashAfter, "a replay pays nothing")
	local limited = setup()
	assert(claim(limited, "RequestClaimDaily").ok == true, "first claim passes the limiter")
	local spam =
		limited.fireRaw(limited.player, "RequestClaimDaily", nil, limited.nextId(), limited.data.activeMainFarmId)
	assert(
		spam and spam.ok == false and spam.message == "Çok hızlı işlem yapıyorsun; biraz bekle.",
		"throttle reply"
	)
	local foreign =
		limited.fireAs(limited.stranger, "RequestClaimDaily", nil, limited.nextId(), limited.data.activeMainFarmId)
	assert(
		foreign and foreign.ok == false and foreign.message == "Çiftliğin henüz hazır değil",
		"a player without save data"
	)
	local early = setup()
	early.worldReady = false
	local notReady = claim(early, "RequestClaimDaily")
	assert(notReady and notReady.ok == false and early.data.cash == 0, "world not ready: nothing is paid")

	-- Başarım: tamamlanmadan alınamaz, tamamlanınca bir kez ödenir
	local ach = setup()
	local achievement = nil
	for _, candidate in config.ACHIEVEMENTS do
		if candidate.metric == "earned" then
			achievement = candidate
			break
		end
	end
	assert(achievement, "an earned-metric achievement exists")
	local early1 = claim(ach, "RequestClaimAchievement", achievement.id)
	assert(early1 and early1.ok == false and early1.message == "Bu başarım henüz tamamlanmadı", "incomplete")
	assert(ach.data.cash == 0 and not (ach.data.achievements and ach.data.achievements[achievement.id]), "nothing paid")
	ach.data.lifetimeEarned = achievement.target
	local done = claim(ach, "RequestClaimAchievement", achievement.id)
	assert(done and done.ok == true and ach.data.cash == achievement.reward, "the achievement pays its reward")
	assert(
		ach.data.achievements[achievement.id] == true and ach.metricCounts.AchievementsClaimed == 1,
		"marked and counted"
	)
	-- İlk başarım: tek seferlik küçük altın hediyesi (ilk tur), bildirimle; ikinci başarımda tekrar yok
	assert(ach.data.gold == rewards.FIRST_ACHIEVEMENT_GOLD, "the first achievement gifts the teaching gold")
	assert(ach.metricCounts.FirstAchievementGoldGifts == 1, "the gift is counted")
	local giftNotice = nil
	for _, sent in ach.sent do
		if sent.remote == "Notify" and string.find(tostring(sent.args[1]), "altın", 1, true) then
			giftNotice = sent
		end
	end
	assert(giftNotice and giftNotice.args[2] == "success", "the player is told about the gift")
	assert(done.ok == true and done.remote == "PurchaseResult", "the claim reply still comes last")
	local twice = claim(ach, "RequestClaimAchievement", achievement.id)
	assert(
		twice and twice.ok == false and twice.message == "Bu başarımın ödülü zaten alındı",
		"no second reward"
	)
	assert(ach.data.cash == achievement.reward, "a refused claim pays nothing")
	assert(ach.data.gold == rewards.FIRST_ACHIEVEMENT_GOLD, "a refused repeat claim gifts nothing more")
	local second = nil
	for _, candidate in config.ACHIEVEMENTS do
		if candidate.id ~= achievement.id and candidate.metric == "home" then
			second = candidate
			break
		end
	end
	assert(second, "a second, independent achievement exists")
	for _ = 1, second.target do
		table.insert(
			ach.data.animals,
			{ uid = `g{#ach.data.animals}`, animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" }
		)
	end
	local secondClaim = claim(ach, "RequestClaimAchievement", second.id)
	assert(secondClaim and secondClaim.ok == true, "the second achievement can be claimed")
	assert(
		ach.data.gold == rewards.FIRST_ACHIEVEMENT_GOLD and ach.metricCounts.FirstAchievementGoldGifts == 1,
		"only the first achievement gifts gold"
	)
	local unknown = claim(ach, "RequestClaimAchievement", "no_such_achievement")
	assert(unknown and unknown.ok == false and unknown.message == "Bilinmeyen başarım", "unknown achievement")
	local badType = claim(ach, "RequestClaimAchievement", 5)
	assert(badType and badType.ok == false and badType.message == "Geçersiz başarım", "non-string id")

	-- Mevsim hedefi: sunucu hazırlamadan alınamaz; tamamlanınca bir kez ödenir
	local seasonal = setup()
	local notReadyGoal = claim(seasonal, "RequestClaimSeasonal")
	assert(
		notReadyGoal and notReadyGoal.ok == false and notReadyGoal.message == "Bu mevsimin hedefi henüz hazır değil",
		"no goal"
	)
	rewards.ensureSeasonal(seasonal.data, seasonal.now)
	local incomplete = claim(seasonal, "RequestClaimSeasonal")
	assert(
		incomplete and incomplete.ok == false and incomplete.message == "Mevsim hedefi henüz tamamlanmadı",
		"incomplete"
	)
	rewards.forceCompleteSeasonal(seasonal.data, seasonal.now)
	local reward = rewards.seasonalReward(seasonal.data)
	local completed = claim(seasonal, "RequestClaimSeasonal")
	assert(completed and completed.ok == true and seasonal.data.cash == reward, "the seasonal reward is paid")
	assert(seasonal.data.seasonal.claimed == true, "the claimed mark is written")
	local secondSeasonal = claim(seasonal, "RequestClaimSeasonal")
	assert(
		secondSeasonal
			and secondSeasonal.ok == false
			and secondSeasonal.message == "Mevsim hedefinin ödülü zaten alındı",
		"once"
	)
	assert(seasonal.data.cash == reward, "a refused claim pays nothing")

	-- Altın hayvan: pencere sunucuda yeniden hesaplanır; aynı pencerede bir kez ödenir; eski çiftlik kimliği sessizce atılır
	local golden = setup()
	local gdata = golden.data
	table.insert(
		gdata.animals,
		{ uid = "golden-cow", animalId = "cow", zoneId = "starter", stage = "adult", bornAt = 0 }
	)
	local noEvent = claim(golden, "RequestClaimGolden")
	assert(
		noEvent and noEvent.ok == false and noEvent.message == "Altın hayvan artık burada değil",
		"no window, no reward"
	)
	gdata.adminForce = { goldenUntil = golden.now + 120 }
	local stale = golden.fire("RequestClaimGolden", nil, golden.nextId(), "bogus-farm")
	assert(stale == nil and gdata.cash == 0 and gdata.golden == nil, "a stale farm id is dropped without paying")
	golden.near = false
	local far = claim(golden, "RequestClaimGolden")
	assert(
		far and far.ok == false and far.message == "Altın hayvana yeterince yakın değilsin" and gdata.cash == 0,
		"too far from the own island: no reward"
	)
	golden.near = true
	local caught = claim(golden, "RequestClaimGolden")
	assert(caught and caught.ok == true and gdata.cash > 0, `the golden animal pays: {caught and caught.message}`)
	local paid = gdata.cash
	assert(
		gdata.golden and gdata.golden.key ~= nil and golden.metricCounts.GoldenAnimalsClaimed == 1,
		"marked and counted"
	)
	local repeatClaim = claim(golden, "RequestClaimGolden")
	assert(repeatClaim and repeatClaim.ok == false and gdata.cash == paid, "the same window pays only once")

	-- Mevsim imzası: ilerleme hedefin %1'lik adımlarına yuvarlanır; her saniyelik küçük değişim pushState üretmez
	local number = 1000
	while rewards.seasonalDef(number).metric ~= "earned" do
		number += 1
	end
	local sig = setup(number * config.SEASON_SECONDS + 10)
	sig.playersList = { sig.player }
	local loopIndex = 1 -- init'in ilk task.spawn'ı mevsim döngüsüdür
	sig.runSpawned(loopIndex)
	assert(sig.counters.pushes == 1 and sig.data.seasonal ~= nil, "a new seasonal goal is created and pushed once")
	local goal = sig.data.seasonal
	sig.runSpawned(loopIndex)
	assert(sig.counters.pushes == 1, "an unchanged goal is not pushed again")
	sig.data.lifetimeEarned = goal.base + 1
	assert(goal.target >= 300, "the earned target is large enough for a 1% step to be bigger than 1 unit")
	sig.runSpawned(loopIndex)
	assert(sig.counters.pushes == 1, "progress below 1% of the target does not push")
	sig.data.lifetimeEarned = goal.base + math.ceil(goal.target / 2)
	sig.runSpawned(loopIndex)
	assert(sig.counters.pushes == 2, "progress crossing a 1% step pushes once")
	sig.runSpawned(loopIndex)
	assert(sig.counters.pushes == 2, "the new signature is remembered")
	goal.claimed = true
	sig.runSpawned(loopIndex)
	assert(sig.counters.pushes == 3, "a claimed goal changes the signature and pushes")
	print(
		"PASS engagement service: actual service daily, achievement, seasonal, golden claims, replay, throttling and 1% season signature"
	)
end
