--!strict
-- Telemetri: saf mantık (yuvarlama, toplama, bütçe, huni) ve gerçek TelemetryService (sahte AnalyticsService ile):
-- toplu gönderim, tek seferlik huni, bütçe, pcall, çıkışta özet ve "Studio'da gönderme yok".
return function(createService: any, Logic: any, Config: any)
	-- ── Saf mantık ────────────────────────────────────────────────────────────
	assert(Logic.roundAmount(0.4) == nil, "1'in altı gönderilmez")
	assert(
		Logic.roundAmount(0.5) == 1 and Logic.roundAmount(2.4) == 2 and Logic.roundAmount(2.5) == 3,
		"yarıya yuvarlama"
	)
	assert(Logic.roundAmount(1e20) == Logic.MAX_AMOUNT, "üst sınır")
	for _, bad in { 0 / 0, math.huge, -math.huge, -5, 0, "5", {}, false } do
		assert(Logic.roundAmount(bad) == nil, "geçersiz tutar gönderilmez")
	end
	assert(
		Logic.roundBalance(-3) == 0 and Logic.roundBalance(0 / 0) == 0 and Logic.roundBalance("x") == 0,
		"bakiye >= 0"
	)
	assert(Logic.roundBalance(10.6) == 11, "bakiye yuvarlanır")

	local transactions: { [string]: boolean } = {}
	local transactionCount = 0
	for key, category in Logic.ECONOMY do
		assert(category.flow == "Source" or category.flow == "Sink", `{key}: yön`)
		assert(not transactions[category.transaction], `{key}: işlem türü benzersiz`)
		transactions[category.transaction] = true
		transactionCount += 1
		assert(
			category.batched == (key == "collect" or key == "autoCollect" or key == "parkedPay" or key == "production"),
			`{key}: yalnızca toplama ve üretim toplu gider`
		)
	end
	assert(transactionCount <= 20, "AnalyticsService işlem türü sınırı 20")
	for _, key in
		{
			"collect",
			"autoCollect",
			"parkedPay",
			"offline",
			"daily",
			"season",
			"golden",
			"order",
			"goodsSale",
			"production",
			"refund",
		}
	do
		assert(Logic.ECONOMY[key].flow == "Source", `{key} kaynak olmalı`)
	end
	for _, key in { "animal", "upgrade", "item", "farm", "lineage" } do
		assert(Logic.ECONOMY[key].flow == "Sink", `{key} gider olmalı`)
	end
	local customCount = 0
	for _ in Logic.CUSTOM_EVENTS do
		customCount += 1
	end
	assert(customCount <= Logic.CUSTOM_EVENT_CAP and Logic.CUSTOM_EVENT_CAP == 100, "özel olay adı sınırı 100")
	assert(customCount == 20, `özel olay sayısı belgeyle aynı olmalı (20): {customCount}`)
	assert(Logic.CUSTOM_EVENTS.ItemAcquired == true, "ItemAcquired özel olay listesinde")
	-- Hayvan kimlikleri ve yükseltmeler (ada/ahır/bölge kimliğiyle, diğerleri türüyle: Config.getUpgradeSku) SKU olarak gider (eşya, genişletme, tesis SKU'suz); deneyim başına 100 sınırı.
	local skus: { [string]: boolean } = {}
	for animalId in Config.ANIMALS do
		skus[animalId] = true
	end
	for _, upgrade in Config.UPGRADES do
		skus[Config.getUpgradeSku(upgrade)] = true -- ada/ahır/bölge kimliğiyle, diğerleri türüyle
	end
	local skuCount = 0
	for _ in skus do
		skuCount += 1
	end
	assert(skuCount <= 100, `SKU adayı sayısı {skuCount} > 100: içerik büyüdü, telemetri SKU listesini daralt`)
	local seen: { [number]: boolean } = {}
	local steps = 0
	for id, step in Logic.FUNNEL do
		assert(not seen[step.step] and step.step >= 1 and step.step <= 100, `{id}: huni adımı benzersiz 1-100`)
		seen[step.step] = true
		steps += 1
	end
	for number = 1, steps do
		assert(seen[number], "huni adımları ardışık")
	end
	-- İlk dört adım öğreticiyle (OnboardingSteps) aynı sıradadır: hayvan -> toplama -> yükseltme -> üretim.
	assert(
		Logic.FUNNEL.first_animal.step == 1
			and Logic.FUNNEL.first_collect.step == 2
			and Logic.FUNNEL.first_upgrade.step == 3
			and Logic.FUNNEL.first_production.step == 4,
		"huni sırası öğreticiyle aynı"
	)
	assert(steps == 6, "altı huni adımı: dört öğretici + ada + ahır")
	for _, name in
		{
			"RebirthAvailable",
			"RebirthDone",
			"RebirthPerk",
			"GoldGained",
			"GoldSpent",
			"SessionSeconds",
			"OfflineSeconds",
		}
	do
		assert(Logic.CUSTOM_EVENTS[name] == true, `{name} özel olay listesinde`)
	end

	-- Rebirth hunisi ve altın akışı: yalnızca iki görüntü arasındaki fark olay olur
	local function observation(gold: number, rebirths: number, canRebirth: boolean, perks: any?): any
		return {
			gold = gold,
			rebirths = rebirths,
			canRebirth = canRebirth,
			perks = perks or {},
			perkOrder = { "income", "growth", "starting_cash" },
		}
	end
	assert(
		#Logic.progressEvents(nil, observation(500, 2, true)) == 0,
		"ilk görüntü yalnızca başlangıç çizgisidir"
	)
	assert(
		#Logic.progressEvents(observation(10, 0, false), observation(10, 0, false)) == 0,
		"değişmeyen durum olay üretmez"
	)
	local available = Logic.progressEvents(observation(10, 3, false), observation(10, 3, true))
	assert(
		#available == 1 and available[1].name == "RebirthAvailable" and available[1].value == 4,
		"rebirth hazır olunca bir kez, sıradaki rebirth numarasıyla"
	)
	assert(
		#Logic.progressEvents(observation(10, 3, true), observation(10, 3, true)) == 0,
		"hazır kalmak yeniden olay üretmez"
	)
	local done = Logic.progressEvents(
		observation(10, 3, true, { income = 1 }),
		observation(760, 4, false, { income = 1, growth = 1 })
	)
	assert(#done == 3, "rebirth: tamamlandı + etki + altın kazancı")
	assert(done[1].name == "RebirthDone" and done[1].value == 4, "tamamlanan rebirth sayısı")
	assert(done[2].name == "RebirthPerk" and done[2].value == 2, "seçilen etkinin perkOrder sırası")
	assert(done[3].name == "GoldGained" and done[3].value == 750, "rebirth altın ödülü kazanç olarak görünür")
	local spent = Logic.progressEvents(observation(100, 1, false), observation(70.4, 1, false))
	assert(#spent == 1 and spent[1].name == "GoldSpent" and spent[1].value == 30, "altın harcaması (yuvarlanır)")
	assert(
		#Logic.progressEvents(observation(100, 1, false), observation(100.2, 1, false)) == 0,
		"1'in altı gönderilmez"
	)
	local unknownPerk = Logic.progressEvents(observation(0, 1, false), observation(0, 2, false))
	assert(unknownPerk[2].name == "RebirthPerk" and unknownPerk[2].value == 0, "etki bulunamazsa 0")

	local aggregator = Logic.newAggregator()
	Logic.add(aggregator, "collect", 10, 100)
	Logic.add(aggregator, "collect", 5, 90)
	Logic.add(aggregator, "autoCollect", 7, 50)
	local batches = Logic.drain(aggregator)
	assert(#batches == 2 and batches[1].key == "autoCollect" and batches[2].key == "collect", "anahtar sırası")
	assert(batches[2].amount == 15 and batches[2].count == 2 and batches[2].balance == 90, "toplam, adet, son bakiye")
	assert(#Logic.drain(aggregator) == 0, "drain sıfırlar")

	local budget = Logic.newBudget(120, 0)
	for _ = 1, 120 do
		assert(Logic.allow(budget, 0), "bütçe dolana kadar izin")
	end
	assert(not Logic.allow(budget, 0), "bütçe bitince reddet")
	assert(Logic.allow(budget, 0.5) and not Logic.allow(budget, 0.5), "saniyede limit/60 jeton dolar")
	assert(Logic.allow(budget, 600), "uzun beklemeden sonra yeniden izin")
	local refilled = 0
	while Logic.allow(budget, 600) do
		refilled += 1
		assert(refilled < 1000, "kova sınırsız dolmaz")
	end
	assert(refilled == 119, "kova en çok limit kadar dolar")

	local empty = Logic.factsFromViews({})
	assert(
		not Logic.funnelReached(empty).first_collect and not Logic.funnelReached(empty).barn_2,
		"boş kayıtta adım yok"
	)
	local facts = Logic.factsFromViews({
		{
			lifetimeEarned = 5,
			animals = { {}, {} },
			purchased = { a = true },
			unlockedIslands = { home = true },
			barnLevel = 1,
		},
		{ animals = {}, purchased = {}, unlockedIslands = { home = true, poultry = true }, barnLevel = 2 },
	})
	local reached = Logic.funnelReached(facts)
	assert(not reached.first_production, "üretim partisi yoksa üretim adımı geçilmemiştir")
	assert(
		Logic.funnelReached(Logic.factsFromViews({ { production = { milk = { uid = "x" } } } })).first_production,
		"çalışan üretim partisi olan kayıtta üretim adımı geçilmiştir"
	)
	assert(
		reached.first_collect
			and reached.first_animal
			and reached.first_upgrade
			and reached.first_island
			and reached.barn_2,
		"herhangi bir çiftlikte yapılan adım geçilmiş sayılır"
	)
	assert(
		not Logic.funnelReached(Logic.factsFromViews({ { unlockedIslands = { home = true }, barnLevel = 1 } })).first_island,
		"home ada sayılmaz"
	)

	-- Eşya edinimi alanları: bilinmeyen kanal gönderilmez; slot sınırlı biçimde (eşya kimliği yok)
	for _, channel in { "cash", "gold", "robux", "merchant", "reward" } do
		local fields = Logic.acquiredFields(channel, "charm")
		assert(
			fields and fields.CustomField01 == channel and fields.CustomField02 == "charm",
			`{channel}: kanal ve slot alanı`
		)
	end
	assert(Logic.acquiredFields("hack", "charm") == nil and Logic.acquiredFields(5, "charm") == nil, "bilinmeyen kanal")
	assert(
		Logic.cleanSlot("Weird Slot!") == "other"
			and Logic.cleanSlot("a_very_long_slot_name_here") == "other"
			and Logic.cleanSlot(nil) == "other"
			and Logic.cleanSlot("back") == "back",
		"slot adı temizlenir"
	)
	-- Altın harcaması kaynaklara bölünür: bildirilen tutarlar toplamı aşamaz, kalan "other"
	local function splitText(total: number, reported: any): string
		local parts = {}
		for _, part in Logic.splitGoldSpent(total, reported) do
			table.insert(parts, `{part.source}={part.amount}`)
		end
		return table.concat(parts, ",")
	end
	assert(splitText(30, nil) == "other=30", "bildirimsiz harcama other")
	assert(splitText(100, { item = 60, finish = 10 }) == "item=60,finish=10,other=30", "kaynaklar ve kalan")
	assert(splitText(50, { item = 80 }) == "item=50", "bildirilen tutar toplamı aşamaz")
	assert(splitText(10, { convert = -5, item = 0 / 0, other = 9 }) == "other=10", "geçersiz tutar yok sayılır")
	local splitEvents = Logic.progressEvents(observation(100, 1, false), observation(40, 1, false), { item = 45 })
	assert(
		#splitEvents == 2
			and splitEvents[1].value == 45
			and splitEvents[1].fields.CustomField01 == "item"
			and splitEvents[2].value == 15
			and splitEvents[2].fields.CustomField01 == "other",
		"GoldSpent kaynak alanıyla bölünür"
	)

	-- ── Servis ───────────────────────────────────────────────────────────────
	local function build(studio: boolean, throwing: boolean?)
		local clock = 1000
		local calls: { any } = {}
		local metrics: { [string]: number } = {}
		local spawned: { any } = {}
		local warnings: { string } = {}
		local printed: { string } = {}
		local printAttribute = false
		local function record(kind: string): (...any) -> ()
			return function(_self: any, ...: any)
				if throwing then
					error("AnalyticsService reddetti")
				end
				table.insert(calls, { kind = kind, args = table.pack(...) })
			end
		end
		local analytics = {
			LogEconomyEvent = record("economy"),
			LogOnboardingFunnelStepEvent = record("funnel"),
			LogCustomEvent = record("custom"),
			LogProgressionCompleteEvent = record("progression"),
		}
		local players: any = {
			PlayerAdded = { Connect = function() end },
			GetPlayers = function(): { any }
				return {}
			end,
		}
		local services: any = {
			Players = players,
			RunService = {
				IsStudio = function(): boolean
					return studio
				end,
			},
			AnalyticsService = analytics,
			Workspace = {
				GetAttribute = function(_self: any, name: string): any
					return if name == "TelemetryPrint" then printAttribute else nil
				end,
			},
		}
		local engine: any = {
			GetService = function(_self: any, name: string): any
				return services[name]
			end,
		}
		local fakeMetrics: any = {
			increment = function(name: string, amount: number?)
				metrics[name] = (metrics[name] or 0) + (amount or 1)
			end,
		}
		local fakeTask: any = {
			spawn = function(callback: any, ...: any)
				table.insert(spawned, { callback = callback, args = table.pack(...) })
			end,
			wait = function() end,
		}
		local fakeOs: any = {
			clock = function(): number
				return clock
			end,
			time = function(): number
				return clock
			end,
		}
		local fakeEnum: any = { AnalyticsEconomyFlowType = { Source = "Source", Sink = "Sink" } }
		local service = createService(engine, fakeTask, fakeOs, fakeEnum, fakeMetrics, function(message: string)
			table.insert(warnings, message)
		end, function(message: string)
			table.insert(printed, message)
		end)
		return {
			service = service,
			analytics = analytics,
			calls = calls,
			metrics = metrics,
			spawned = spawned,
			warnings = warnings,
			printed = printed,
			advance = function(seconds: number)
				clock += seconds
			end,
			setPrint = function(value: boolean)
				printAttribute = value
			end,
		}
	end
	local function newPlayer(): any
		return { Parent = {}, Name = "Test" }
	end
	local function ofKind(world: any, kind: string): { any }
		local result = {}
		for _, call in world.calls do
			if call.kind == kind then
				table.insert(result, call)
			end
		end
		return result
	end

	-- Toplu: 50 toplama olayı tek olay olur; otomatik toplama ayrı; bakiye sonuncusu.
	local live = build(false)
	local player = newPlayer()
	for index = 1, 50 do
		live.service.economy(player, "collect", 10, 1000 + index)
	end
	live.service.economy(player, "autoCollect", 4.4, 77)
	assert(#live.calls == 0, "yüksek frekanslı kaynaklar anında gönderilmez")
	live.service.flushAll()
	local economy = ofKind(live, "economy")
	assert(#economy == 2, "toplama ve otomatik toplama birer olay")
	assert(economy[2].args[2] == "Source" and economy[2].args[3] == "Cash", "kaynak yönü ve para birimi")
	assert(
		economy[2].args[4] == 500 and economy[2].args[5] == 1050 and economy[2].args[6] == "Collect",
		"toplam, son bakiye, tür"
	)
	assert(economy[1].args[4] == 4 and economy[1].args[6] == "AutoCollect", "otomatik toplama yuvarlanır")
	live.service.flushAll()
	assert(#ofKind(live, "economy") == 2, "gönderilenler tekrar gönderilmez")

	-- Anında: günlük ödül, gider, SKU.
	live.service.economy(player, "daily", 250, 300)
	live.service.economy(player, "animal", 120, 180, "cow")
	economy = ofKind(live, "economy")
	assert(economy[3].args[6] == "Daily" and economy[3].args[7] == "", "SKU yoksa boş")
	assert(
		economy[4].args[2] == "Sink" and economy[4].args[6] == "Animal" and economy[4].args[7] == "cow",
		"gider + SKU"
	)
	live.service.economy(player, "nope", 5, 5)
	live.service.economy(player, "daily", 0, 5)
	live.service.economy(player, "daily", 0 / 0, 5)
	assert(#ofKind(live, "economy") == 4, "bilinmeyen tür ve geçersiz tutar gönderilmez")
	assert(live.metrics.TelemetryUnknownEconomy == 1, "bilinmeyen tür sayılır")

	-- Huni: bir kez; kayıttan geçilmiş adım tekrar gönderilmez.
	live.service.funnel(player, "first_animal")
	live.service.funnel(player, "first_animal")
	assert(#ofKind(live, "funnel") == 1 and ofKind(live, "funnel")[1].args[2] == 1, "adım bir kez, doğru numara")
	local returning = newPlayer()
	live.service.onLoaded(returning, {
		{ lifetimeEarned = 10, animals = { {} }, purchased = {}, unlockedIslands = { home = true }, barnLevel = 1 },
	}, nil)
	live.service.funnel(returning, "first_collect")
	live.service.funnel(returning, "first_animal")
	live.service.funnel(returning, "first_upgrade")
	local funnelCalls = ofKind(live, "funnel")
	assert(#funnelCalls == 2 and funnelCalls[2].args[2] == 3, "yalnızca henüz geçilmemiş adım gönderilir")
	live.service.funnel(player, "yok")
	assert(#ofKind(live, "funnel") == 2, "bilinmeyen adım yok sayılır")

	-- Çevrimdışı dönüş: kaynak + süre + sınır.
	local away = newPlayer()
	live.service.onLoaded(away, {}, { earned = 900, awaySeconds = 7200, capped = true, balance = 1900 })
	local customs = ofKind(live, "custom")
	assert(
		#customs == 2 and customs[1].args[2] == "OfflineSeconds" and customs[1].args[3] == 7200,
		"çevrimdışı süre"
	)
	assert(customs[2].args[2] == "OfflineCapped", "sınıra takılma")
	assert(ofKind(live, "economy")[5].args[6] == "Offline", "çevrimdışı kazanç kaynak olarak")

	-- İlerleme: progression + özel olay birlikte.
	live.service.progression(player, "island", 2, "poultry")
	assert(
		ofKind(live, "progression")[1].args[2] == "Islands" and ofKind(live, "progression")[1].args[3] == 2,
		"ilerleme yolu"
	)
	assert(
		ofKind(live, "custom")[3].args[2] == "IslandUnlocked" and ofKind(live, "custom")[3].args[3] == 2,
		"eşlik eden özel olay"
	)
	live.service.custom(player, "BilinmeyenOlay")
	assert(live.metrics.TelemetryUnknownCustom == 1, "izinsiz özel olay adı gönderilmez")

	-- Gözlem: ilk görüntü sessiz, sonraki farklar özel olay; çıkmış oyuncu için durum açılmaz.
	local watcher = build(false)
	local watched = newPlayer()
	local function snapshot(gold: number, rebirths: number, canRebirth: boolean, perks: any): any
		return {
			gold = gold,
			rebirths = rebirths,
			canRebirth = canRebirth,
			perks = perks,
			perkOrder = { "income", "growth" },
		}
	end
	watcher.service.observe(watched, snapshot(0, 0, false, {}))
	assert(#ofKind(watcher, "custom") == 0, "ilk gözlem olay göndermez")
	watcher.service.observe(watched, snapshot(0, 0, true, {}))
	watcher.service.observe(watched, snapshot(750, 1, false, { growth = 1 }))
	watcher.service.observe(watched, snapshot(720, 1, false, { growth = 1 }))
	local watchedEvents = ofKind(watcher, "custom")
	local names = {}
	for _, call in watchedEvents do
		table.insert(names, `{call.args[2]}={call.args[3]}`)
	end
	assert(
		table.concat(names, ",") == "RebirthAvailable=1,RebirthDone=1,RebirthPerk=2,GoldGained=750,GoldSpent=30",
		`rebirth hunisi ve altın olayları: {table.concat(names, ",")}`
	)
	local gone = newPlayer()
	gone.Parent = nil
	watcher.service.observe(gone, snapshot(0, 0, false, {}))
	watcher.service.observe(gone, snapshot(99, 0, false, {}))
	assert(#ofKind(watcher, "custom") == #watchedEvents, "çıkmış oyuncu için gözlem durumu açılmaz")
	local studioWatch = build(true)
	local devWatcher = newPlayer()
	studioWatch.service.observe(devWatcher, snapshot(0, 0, false, {}))
	studioWatch.service.observe(devWatcher, snapshot(10, 0, false, {}))
	assert(#studioWatch.calls == 0, "Studio'da gözlem olayı gönderilmez")

	-- Eşya edinimi: bir çağrı = bir olay (kanal + slot alanı); bilinmeyen kanal düşer, Studio'da gönderilmez.
	local acquire = build(false)
	local buyer = newPlayer()
	acquire.service.acquired(buyer, "cash", "charm")
	acquire.service.acquired(buyer, "robux", "back")
	acquire.service.acquired(buyer, "bogus", "back")
	local acquiredCalls = ofKind(acquire, "custom")
	assert(#acquiredCalls == 2, "iki geçerli edinim iki olay üretir")
	assert(
		acquiredCalls[1].args[2] == "ItemAcquired"
			and acquiredCalls[1].args[3] == 1
			and acquiredCalls[1].args[4].CustomField01 == "cash"
			and acquiredCalls[1].args[4].CustomField02 == "charm",
		"ItemAcquired değeri 1, alanlar kanal ve slot"
	)
	assert(acquiredCalls[2].args[4].CustomField01 == "robux", "kanal ayrımı")
	assert(acquire.metrics.TelemetryUnknownCustom == 1, "bilinmeyen kanal sayılır, gönderilmez")
	local studioAcquire = build(true)
	studioAcquire.service.acquired(newPlayer(), "cash", "charm")
	assert(#studioAcquire.calls == 0, "Studio'da edinim olayı gönderilmez")

	-- Alanlı gönderim reddedilirse alansız bir kez gönderilir (olay kaybolmaz)
	local picky = build(false)
	local pickyPlayer = newPlayer()
	local pickyCalls = 0
	local analyticsFake = picky.analytics
	analyticsFake.LogCustomEvent = function(_self: any, _player: any, name: string, value: number, fields: any)
		pickyCalls += 1
		if fields ~= nil then
			error("alan reddedildi")
		end
		table.insert(picky.calls, { kind = "custom", args = table.pack(_player, name, value) })
	end
	picky.service.acquired(pickyPlayer, "gold", "tool")
	assert(pickyCalls == 2 and #ofKind(picky, "custom") == 1, "alan reddedilirse alansız gönderilir")
	assert(picky.metrics.TelemetryFieldsRejected == 1, "reddedilen alan sayılır")

	-- Altın harcaması: kanalların bildirdiği tutar bir sonraki gözlemde kaynak olarak ayrışır; tüketilen tutar taşınmaz
	local spender = build(false)
	local spenderPlayer = newPlayer()
	spender.service.observe(spenderPlayer, snapshot(500, 0, false, {}))
	spender.service.goldSpent(spenderPlayer, "item", 300)
	spender.service.goldSpent(spenderPlayer, "finish", 20)
	spender.service.goldSpent(spenderPlayer, "bogus", 99)
	spender.service.goldSpent(spenderPlayer, "convert", 0)
	spender.service.observe(spenderPlayer, snapshot(150, 0, false, {}))
	local spendText = {}
	for _, call in ofKind(spender, "custom") do
		table.insert(spendText, `{call.args[2]}={call.args[3]}/{call.args[4].CustomField01}`)
	end
	assert(
		table.concat(spendText, ",") == "GoldSpent=300/item,GoldSpent=20/finish,GoldSpent=30/other",
		`altın harcama kaynakları: {table.concat(spendText, ",")}`
	)
	assert(spender.metrics.TelemetryUnknownCustom == 1, "bilinmeyen altın kaynağı sayılır")
	spender.service.observe(spenderPlayer, snapshot(100, 0, false, {}))
	local lastSpend = ofKind(spender, "custom")
	assert(
		#lastSpend == 4 and lastSpend[4].args[3] == 50 and lastSpend[4].args[4].CustomField01 == "other",
		"önceki pencerenin kaynakları sonrakine taşınmaz"
	)
	-- Çıkmış oyuncu için kaynak durumu açılmaz
	local goneSpender = newPlayer()
	goneSpender.Parent = nil
	spender.service.goldSpent(goneSpender, "item", 5)

	-- Çıkış: birikenler, oturum süresi, depo dolu süresi.
	local leaving = newPlayer()
	live.service.economy(leaving, "collect", 30, 60)
	live.service.storageFull(leaving, 12.4)
	live.service.storageFull(leaving, 0)
	live.advance(300)
	local before = #live.calls
	live.service.onLeaving(leaving)
	local tail = {}
	for index = before + 1, #live.calls do
		table.insert(tail, live.calls[index])
	end
	assert(#tail == 3, "çıkışta: toplu gelir + oturum + depo dolu")
	assert(tail[1].kind == "economy" and tail[1].args[4] == 30, "çıkışta birikenler gider")
	assert(tail[2].args[2] == "SessionSeconds" and tail[2].args[3] == 300, "oturum süresi")
	assert(tail[3].args[2] == "StorageFullSeconds" and tail[3].args[3] == 12, "depo dolu süre")
	live.service.onLeaving(leaving)
	assert(#live.calls == before + 3, "ikinci çıkış bir şey göndermez")
	live.service.economy(leaving, "collect", 1, 1) -- Parent hâlâ Players: yine de durum açılmaz
	live.service.flushAll()
	assert(#live.calls == before + 3, "çıkışı başlayan oyuncu için durum yeniden açılmaz")
	leaving.Parent = nil
	live.service.economy(leaving, "collect", 1, 1)
	live.service.flushAll()
	assert(#live.calls == before + 3, "çıkmış oyuncu için durum yeniden açılmaz")

	-- Bütçe: sel olursa düşer, oyun etkilenmez.
	local flood = build(false)
	local spammer = newPlayer()
	for _ = 1, 300 do
		flood.service.economy(spammer, "daily", 5, 5)
	end
	assert(#flood.calls == Logic.EVENTS_PER_MINUTE, "dakikalık bütçe aşılmaz")
	assert(flood.metrics.TelemetryDropped == 300 - Logic.EVENTS_PER_MINUTE, "düşen olaylar sayılır")
	flood.advance(60)
	flood.service.economy(spammer, "daily", 5, 5)
	assert(#flood.calls == Logic.EVENTS_PER_MINUTE + 1, "bütçe zamanla yenilenir")

	-- Bütçe yüzünden düşen huni adımı işaretlenmez; bütçe yenilenince bir sonraki çağrıda gider.
	local starved = build(false)
	local newcomer = newPlayer()
	for _ = 1, Logic.EVENTS_PER_MINUTE do
		starved.service.economy(spammer, "daily", 5, 5)
	end
	starved.service.funnel(newcomer, "first_collect")
	assert(#ofKind(starved, "funnel") == 0, "bütçe doluyken huni adımı düşer")
	starved.advance(60)
	starved.service.funnel(newcomer, "first_collect")
	starved.service.funnel(newcomer, "first_collect")
	assert(#ofKind(starved, "funnel") == 1, "düşen huni adımı sonra bir kez gider")

	-- pcall: AnalyticsService hata verirse oyun akışı sürer.
	local broken = build(false, true)
	local survivor = newPlayer()
	broken.service.economy(survivor, "daily", 5, 5)
	broken.service.funnel(survivor, "first_collect")
	broken.service.custom(survivor, "SaveFailed")
	assert(broken.metrics.TelemetryError == 3, "hatalar sayılır, fırlatılmaz")

	-- Studio: hiçbir olay gönderilmez; yalnızca sayaç, print yalnızca isteyince.
	local studio = build(true)
	local dev = newPlayer()
	studio.service.economy(dev, "daily", 5, 5)
	studio.service.funnel(dev, "first_collect")
	studio.service.progression(dev, "farm", 2, "Farm 2")
	studio.service.custom(dev, "SaveFailed")
	studio.service.economy(dev, "collect", 5, 5)
	studio.service.flushAll()
	studio.service.onLeaving(dev)
	assert(#studio.calls == 0, "Studio'da AnalyticsService çağrılmaz")
	assert(#studio.printed == 0, "Studio'da print varsayılan kapalı")
	assert(
		studio.metrics.TelemetryStudioSkipped >= 6 and studio.metrics.TelemetryEconomy >= 2,
		"Metrics sayaçları yazılır"
	)
	studio.setPrint(true)
	studio.service.economy(newPlayer(), "daily", 5, 5)
	assert(#studio.printed == 1 and #studio.calls == 0, "TelemetryPrint açıkken yalnızca print")

	-- Kritik hata: ayrı iş parçacığında error; sel olursa warn.
	local critical = build(false)
	critical.service.critical("[Data] ProfileFailed user=1: x")
	assert(
		#critical.spawned == 1 and critical.spawned[1].args[1] == "[Data] ProfileFailed user=1: x",
		"error ayrı iş parçacığında atılır"
	)
	assert(critical.spawned[1].callback == error, "task.spawn(error, mesaj)")
	for _ = 1, 40 do
		critical.service.critical("tekrar")
	end
	assert(#critical.spawned == 20 and #critical.warnings == 21, "dakikada en çok 20 hata, fazlası warn")
	assert(critical.metrics.CriticalLogged == 41, "kritik kayıtlar sayılır")

	print(
		"PASS telemetry: rounding, batching, funnel once, budget, pcall, session summary, studio no-send, critical logs"
	)
end
