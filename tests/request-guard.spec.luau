--!strict
-- RequestGuard: cevap yolu (PurchaseResult/Notify), hız sınırı cevabı ve etkin çiftlik kontrolü tek yerde.
return function(createHarness: any, createLimiter: any, codec: any, config: any, farmMath: any)
	local harness = createHarness(createLimiter, codec, config, farmMath)
	local function setup(): any
		return harness.new()
	end
	local function last(h: any): any
		return h.sent[#h.sent]
	end

	-- reply: kimlik varsa PurchaseResult, yoksa Notify (tür ok'a göre)
	local h = setup()
	local guard = h.guard
	assert(guard.reply(h.player, 5, true, "tamam"), "a reply with a message is sent")
	assert(
		last(h).remote == "PurchaseResult" and last(h).id == 5 and last(h).ok == true,
		"numeric id -> PurchaseResult"
	)
	assert(guard.reply(h.player, nil, false, "olmadı"), "an id-less failure is still sent")
	assert(
		last(h).remote == "Notify" and last(h).args[1] == "olmadı" and last(h).args[2] == "error",
		"no id -> Notify error"
	)
	assert(guard.reply(h.player, nil, true, "oldu") and last(h).args[2] == "success", "Notify success kind")
	assert(not guard.reply(h.player, 6, true, nil), "a success without a message sends nothing")

	-- reply: nil mesaj + başarısız = hız sınırı; yalnızca numeric kimlikle, kendisi de sınırlı
	local sentBefore = #h.sent
	assert(not guard.reply(h.player, nil, false, nil), "throttle replies need a numeric request id")
	assert(#h.sent == sentBefore, "nothing was sent for an id-less throttle")
	assert(
		guard.reply(h.player, 7, false, nil) and last(h).message == guard.THROTTLE_MESSAGE,
		"the throttle text is used"
	)
	local afterThrottle = #h.sent
	assert(not guard.reply(h.player, 8, false, nil) and #h.sent == afterThrottle, "throttle replies are rate limited")

	-- reply: reddedilen sayacı yalnızca isteyen çağıran için ve yalnızca cevap gittiyse artar
	local counted = setup()
	counted.guard.reply(counted.player, 1, true, "ok", true)
	assert(counted.metricCounts.PurchaseRejected == nil, "successes are not rejections")
	counted.guard.reply(counted.player, 1, false, "red")
	assert(counted.metricCounts.PurchaseRejected == nil, "callers opt in to the counter")
	counted.guard.reply(counted.player, 1, false, "red", true)
	assert(counted.metricCounts.PurchaseRejected == 1, "an opted-in rejection is counted")
	counted.guard.reply(counted.player, nil, false, nil, true)
	assert(counted.metricCounts.PurchaseRejected == 1, "a dropped throttle reply is not counted")

	-- activeFarm: doğru çiftlik kaydı döndürür; yanlış çiftlik bildirilir
	local farm = setup()
	local data = farm.data
	assert(farm.guard.activeFarm(farm.player, 1, data.activeMainFarmId) == data, "a matching farm id returns the save")
	assert(#farm.sent == 0, "a matching farm id says nothing")
	assert(farm.guard.activeFarm(farm.player, 2, "bogus") == nil, "a stale farm id returns nil")
	assert(
		last(farm).remote == "PurchaseResult" and last(farm).message == farm.guard.FARM_CHANGED_MESSAGE,
		"default text"
	)
	assert(farm.counters.pushes == 0, "the guard never pushes state")
	local sentAfter = #farm.sent
	assert(
		farm.guard.activeFarm(farm.player, 3, "bogus") == nil and #farm.sent == sentAfter,
		"farm replies are rate limited"
	)
	farm.clockNow += 10

	-- activeFarm: kimliksiz istekte sessiz; notifyWithoutId açıksa Notify; özel mesaj ve sayaç seçenekleri
	local silent = farm.guard.activeFarm(farm.player, nil, "bogus")
	assert(silent == nil and #farm.sent == sentAfter, "an id-less stale request is silent by default")
	assert(
		farm.guard.activeFarm(farm.player, nil, "bogus", { notifyWithoutId = true, countRejected = true }) == nil,
		"nil"
	)
	assert(last(farm).remote == "Notify" and last(farm).args[2] == "error", "notifyWithoutId reaches the player")
	assert(farm.metricCounts.PurchaseRejected == 1, "countRejected counts the farm rejection")
	farm.clockNow += 10
	farm.guard.activeFarm(farm.player, 9, "bogus", { message = "özel mesaj" })
	assert(
		last(farm).message == "özel mesaj" and farm.metricCounts.PurchaseRejected == 1,
		"custom text, no counter by default"
	)

	-- Verisi olmayan oyuncu: nil döner ve oyuncu sessizce bırakılmaz
	local stranger = setup()
	assert(stranger.guard.activeFarm(stranger.stranger, 4, stranger.data.activeMainFarmId) == nil, "no save, no farm")
	assert(last(stranger) and last(stranger).target == stranger.stranger, "the refused player is told")
	print("PASS request guard: reply routing, throttle reply limit, rejection counter and active-farm check options")
end
