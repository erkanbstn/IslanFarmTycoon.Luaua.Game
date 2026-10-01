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
	assert(customCount <= 100, "özel olay adı sınırı 100")
	-- Yalnızca hayvan ve yükseltme kimlikleri SKU olarak gider (eşya, genişletme, tesis SKU'suz); deneyim başına 100 sınırı.
	local skuCount = 0
	for _, table_ in { Config.ANIMALS, Config.UPGRADES } do
		for _ in table_ do
			skuCount += 1
		end
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
		{ animals = {}, purchased = {}, unlockedIslands = { home = true, dairy = true }, barnLevel = 2 },
	})
	local reached = Logic.funnelReached(facts)
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
	assert(#ofKind(live, "funnel") == 1 and ofKind(live, "funnel")[1].args[2] == 2, "adım bir kez, doğru numara")
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
	live.service.progression(player, "island", 2, "dairy")
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
