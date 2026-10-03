--!strict
-- Gerçek PlayerDataService test runner tarafından bir factory içine alınır.
-- Sadece Roblox servisleri/saat/scheduler taklit edilir; kayıt algoritması aynıdır.
return function(createService: any, Config: any, saveVersion: number)
	local function copy(value: any): any
		if typeof(value) ~= "table" then
			return value
		end
		local result = {}
		for key, child in value do
			result[key] = copy(child)
		end
		return result
	end
	local function fixture(): any
		local clock = 0
		local sequence = 0
		local queue: { any } = {}
		local function schedule(thread: thread, at: number, arguments: any)
			sequence += 1
			table.insert(queue, { thread = thread, at = at, arguments = arguments, sequence = sequence })
		end
		local tasks: any = {}
		function tasks.spawn(callback: any, ...: any)
			schedule(coroutine.create(callback), clock, table.pack(...))
		end
		function tasks.delay(seconds: number, callback: any, ...: any)
			schedule(coroutine.create(callback), clock + seconds, table.pack(...))
		end
		function tasks.defer(callback: any, ...: any)
			schedule(coroutine.create(callback), clock, table.pack(...))
		end
		function tasks.wait(seconds: number?)
			return coroutine.yield(seconds or 0.01)
		end
		local function runUntil(done: () -> boolean)
			local steps = 0
			while not done() do
				steps += 1
				assert(steps < 10000, "scheduler must make bounded progress")
				table.sort(queue, function(a: any, b: any): boolean
					return if a.at == b.at then a.sequence < b.sequence else a.at < b.at
				end)
				local job = table.remove(queue, 1)
				assert(job, "expected pending coroutine")
				clock = job.at
				local ok, yielded = coroutine.resume(job.thread, table.unpack(job.arguments, 1, job.arguments.n))
				assert(ok, tostring(yielded))
				if coroutine.status(job.thread) ~= "dead" then
					schedule(job.thread, clock + yielded, table.pack(yielded))
				end
			end
		end
		local function call(callback: any): any
			local done = false
			local results: any = nil
			tasks.spawn(function()
				results = table.pack(callback())
				done = true
			end)
			runUntil(function(): boolean
				return done
			end)
			return table.unpack(results, 1, results.n)
		end
		local store: any = { raw = nil, actions = {}, calls = 0 }
		function store:UpdateAsync(_key: string, transform: any): any
			self.calls += 1
			local action = table.remove(self.actions, 1) or {}
			if action.delay then
				tasks.wait(action.delay)
			end
			if action.failBefore then
				error("Injected transport failure before commit")
			end
			local result = transform(copy(self.raw))
			if result == nil then
				return nil
			end
			self.raw = copy(result)
			if action.failAfter then
				error("Injected lost response after commit")
			end
			return copy(self.raw)
		end
		store.extra = {}
		function store:SetAsync(key: string, value: any)
			self.extra[key] = copy(value)
		end
		function store:GetAsync(key: string): any
			return copy(self.extra[key])
		end
		local ids = 0
		local services: any = {
			DataStoreService = {
				GetDataStore = function(): any
					return store
				end,
			},
			HttpService = {
				GenerateGUID = function(): string
					ids += 1
					return `test-id-{ids}`
				end,
				JSONEncode = function(_self: any, value: any): string
					local function encode(item: any): string
						if typeof(item) ~= "table" then
							return tostring(item)
						end
						local parts = {}
						for key, child in item do
							table.insert(parts, `{key}:{encode(child)}`)
						end
						return `\{{table.concat(parts, ",")}\}`
					end
					return encode(value)
				end,
			},
			ReplicatedStorage = {
				WaitForChild = function(): any
					return {}
				end,
			},
			RunService = {
				IsStudio = function(): boolean
					return false
				end,
			},
			Workspace = {
				GetAttribute = function(): any
					return nil
				end,
			},
		}
		local engine: any = {
			GetService = function(_self: any, name: string): any
				return services[name]
			end,
		}
		function engine:BindToClose(callback: any)
			self.onClose = callback
		end
		local instances: any = {
			new = function(): any
				return {}
			end,
		}
		local time = {
			clock = function(): number
				return clock
			end,
			time = function(): number
				return 2000000000 + math.floor(clock)
			end,
		}
		local sent: { any } = {}
		local economy: { any } = {}
		local remotes = {
			get = function(name: string): any
				return {
					FireClient = function(_self: any, _player: any, payload: any, second: any, third: any)
						if name == "PlayerState" then
							table.insert(sent, { at = clock, payload = payload, revision = second })
						elseif name == "EconomyTick" then
							table.insert(economy, { at = clock, payload = payload, revision = third })
						end
					end,
				}
			end,
		}
		local dateTime = {
			now = function(): any
				return { UnixTimestampMillis = (2000000000 + clock) * 1000 }
			end,
		}
		local metrics: any = { values = {}, counters = {} }
		function metrics.increment(name: string, amount: number?)
			metrics.counters[name] = (metrics.counters[name] or 0) + (amount or 1)
		end
		function metrics.duration() end
		function metrics.set(name: string, value: number)
			metrics.values[name] = value
		end
		function metrics.max(name: string, value: number)
			metrics.values[name] = math.max(metrics.values[name] or 0, value)
		end
		local player: any = { UserId = 42, Name = "Fixture", Parent = true, attributes = {} }
		function player:SetAttribute(name: string, value: any)
			self.attributes[name] = value
		end
		function player:GetAttribute(name: string): any
			return self.attributes[name]
		end
		return {
			service = createService(engine, tasks, instances, time, remotes, dateTime, metrics, function() end),
			sent = sent,
			economy = economy,
			store = store,
			metrics = metrics,
			player = player,
			call = call,
			tasks = tasks,
			runUntil = runUntil,
			advance = function(seconds: number)
				clock += seconds
			end,
		}
	end
	local function loaded(): any
		local test = fixture()
		assert(
			test.call(function()
				return test.service.load(test.player)
			end),
			"fixture must load active profile"
		)
		return test
	end

	-- Son kayıt iki kez hata verse de üçüncü denemede başarı; başarıdan önce bellek atılmaz.
	local t = loaded()
	t.service.addCash(t.player, 100)
	t.store.actions = { { failBefore = true }, { failBefore = true } }
	assert(
		t.call(function()
			return t.service.release(t.player)
		end),
		"third final-save attempt succeeds"
	)
	assert(t.store.raw.cash == Config.STARTING_CASH + 100, "retry must retain latest cash")
	assert(
		t.store.raw._session == nil and t.player.attributes.DataStatus == "Closed",
		"successful release unlocks and closes"
	)

	-- Para + ürün tek adımda harcanır: biri yetmezse ya da değer geçersizse hiçbir şey düşmez
	t = loaded()
	t.service.addCash(t.player, 500)
	local account = assert(t.service.tryGet(t.player), "active account")
	account.goods = { milk = 5 }
	local cashBefore = account.cash
	assert(not t.service.trySpend(t.player, 100, "upgrade", "x", { milk = 6 }), "one goods unit short")
	assert(account.cash == cashBefore and account.goods.milk == 5, "missing goods take no money")
	assert(not t.service.trySpend(t.player, cashBefore + 1, "upgrade", "x", { milk = 1 }), "missing cash")
	assert(account.cash == cashBefore and account.goods.milk == 5, "missing cash takes no goods")
	for _, bad in { -1, 1.5, 0 / 0, math.huge } do
		assert(not t.service.trySpend(t.player, 10, "upgrade", "x", { milk = bad }), "invalid goods amount is refused")
		assert(account.cash == cashBefore and account.goods.milk == 5, "an invalid amount changes nothing")
	end
	assert(not t.service.trySpend(t.player, 10, "upgrade", "x", { no_such_goods = 1 }), "unknown goods are refused")
	assert(not t.service.trySpend(t.player, -5, "upgrade", "x", { milk = 1 }), "negative money is refused")
	assert(t.service.trySpend(t.player, 100, "upgrade", "x", { milk = 2 }), "money and goods together")
	assert(account.cash == cashBefore - 100 and account.goods.milk == 3, "exactly both are taken")
	assert(
		t.service.trySpend(t.player, 10, "upgrade", "x", {}) and account.goods.milk == 3,
		"no goods cost: money only"
	)

	-- Sunucu cevabı kaybolan yazma 3 kere yinelenir; sonra yeni para + çıkış.
	t = loaded()
	t.service.addCash(t.player, 200)
	t.store.actions = { { failAfter = true }, { failAfter = true }, { failAfter = true } }
	assert(not t.call(function()
		return t.service.save(t.player)
	end), "uncertain write remains pending")
	assert(t.store.raw._revision == 1, "retries do not duplicate commit revision")
	t.service.addCash(t.player, 75)
	assert(
		t.call(function()
			return t.service.release(t.player)
		end),
		"release reconciles then saves latest snapshot"
	)
	assert(t.store.raw.cash == Config.STARTING_CASH + 275, "pending old payload must not erase later cash")
	assert(t.store.raw._revision == 2 and t.store.raw._session == nil, "latest release commits once")

	-- Eski (başarısız) anlık görüntü gönderilse bile save() ancak güncel veri yazılınca true döner.
	t = loaded()
	t.service.addCash(t.player, 200)
	t.store.actions = { { failBefore = true }, { failBefore = true }, { failBefore = true } }
	assert(not t.call(function()
		return t.service.save(t.player)
	end), "all attempts failed")
	t.service.addCash(t.player, 75)
	assert(
		t.call(function()
			return t.service.save(t.player)
		end),
		"save after recovery succeeds"
	)
	assert(
		t.store.raw.cash == Config.STARTING_CASH + 275,
		"stale pending payload is followed by a write of the current data"
	)
	assert(t.store.raw._revision == 2, "stale flush and current write are two commits")

	-- DataStore yield sırasında para değişir ve ayrılma başlar; anahtar kuyruğu sıralar.
	t = loaded()
	t.store.actions = { { delay = 2 } }
	local saveDone, releaseDone = false, false
	t.tasks.spawn(function()
		t.service.save(t.player)
		saveDone = true
	end)
	t.runUntil(function(): boolean
		return t.store.calls == 2
	end)
	t.service.addCash(t.player, 55)
	t.tasks.spawn(function()
		assert(t.service.release(t.player), "overlapping release must complete")
		releaseDone = true
	end)
	t.runUntil(function(): boolean
		return saveDone and releaseDone
	end)
	assert(t.store.raw.cash == Config.STARTING_CASH + 55, "serialized release uses newest snapshot")
	assert(t.store.raw._revision == 2, "one normal save and one final save")

	-- Bekleyen tam paket ekonomik değişimi birleştirirken devam eden kayıt eski snapshot'ı temiz sayamaz.
	t = loaded()
	t.service.pushState(t.player)
	t.call(function() end) -- ilk tam paketi gönder; sonraki paket 0,25 sn bekler
	t.service.pushState(t.player)
	t.store.actions = { { delay = 2 } }
	saveDone = false
	t.tasks.spawn(function()
		assert(t.service.save(t.player), "the original snapshot is saved")
		saveDone = true
	end)
	t.runUntil(function(): boolean
		return t.store.calls == 2
	end)
	t.service.addCash(t.player, 25)
	assert(#t.economy == 0, "the pending full packet still coalesces the economy update")
	t.runUntil(function(): boolean
		return saveDone
	end)
	assert(t.store.raw.cash == Config.STARTING_CASH, "the in-flight snapshot predates the cash change")
	assert(t.player.attributes.DataDirty == true, "cash changed during a save must remain dirty")
	assert(
		t.call(function()
			return t.service.save(t.player)
		end),
		"the next save persists the later cash"
	)
	assert(
		t.store.raw.cash == Config.STARTING_CASH + 25 and t.player.attributes.DataDirty == false,
		"latest save is clean"
	)

	-- Yükleme sırasında ayrılma: sonradan Active/hayalet profil oluşmamalı.
	t = fixture()
	t.store.actions = { { delay = 2 } }
	local loadDone = false
	releaseDone = false
	t.tasks.spawn(function()
		assert(t.service.load(t.player) == nil, "departed player load must return nil")
		loadDone = true
	end)
	t.runUntil(function(): boolean
		return t.store.calls == 1
	end)
	t.player.Parent = nil
	t.tasks.spawn(function()
		assert(t.service.release(t.player), "loading release waits for ownership result")
		releaseDone = true
	end)
	t.runUntil(function(): boolean
		return loadDone and releaseDone
	end)
	assert(t.player.attributes.DataStatus == "Closed" and t.store.raw._session == nil, "departed load is released")

	-- Başarısız son kayıt bellekten silinmez; sonraki deneme aynı ilerlemeyi yazar.
	t = loaded()
	t.service.addCash(t.player, 99)
	t.store.actions = { { failBefore = true }, { failBefore = true }, { failBefore = true } }
	assert(not t.call(function()
		return t.service.release(t.player)
	end), "failed final save reports failure")
	assert(
		t.player.attributes.DataStatus == "Closing" and t.service.tryGet(t.player) == nil,
		"closing profile cannot transact"
	)
	assert(
		t.call(function()
			return t.service.release(t.player)
		end),
		"retained final snapshot can retry"
	)
	assert(t.store.raw.cash == Config.STARTING_CASH + 99, "retry persists retained progress")

	-- Sahiplik kaybında mutasyon durur; başka sunucunun kaydı değişmez.
	t = loaded()
	t.store.raw._session.owner = "other-server"
	local before = copy(t.store.raw)
	assert(not t.call(function()
		return t.service.save(t.player)
	end), "foreign owner rejects save")
	assert(
		t.service.tryGet(t.player) == nil and t.player.attributes.DataStatus == "Failed",
		"ownership loss fail-closes"
	)
	t.service.addCash(t.player, 100000)
	assert(
		t.store.raw._session.owner == before._session.owner and t.store.raw._revision == before._revision,
		"foreign save remains untouched"
	)

	-- Sahip başka sunucuya geçmese bile yenilenmeyen süre dolunca ekonomi durur.
	t = loaded()
	t.call(function()
		t.tasks.wait(181)
	end)
	assert(t.service.tryGet(t.player) == nil, "expired lease cannot continue transactions")
	assert(t.player.attributes.DataStatus == "Failed", "lease expiry is visible")
	assert(
		t.call(function()
			return t.service.release(t.player)
		end),
		"an expired lease that nobody took over may still write the final snapshot"
	)
	assert(t.store.raw._revision == 1 and t.store.raw._session == nil, "late final write commits and unlocks")

	-- Kira dolduktan sonra başka sunucu devraldıysa son yazım reddedilir.
	t = loaded()
	t.call(function()
		t.tasks.wait(181)
	end)
	t.store.raw._session = { owner = "other-server", expiresAt = 2000000000 + 400 }
	assert(not t.call(function()
		return t.service.release(t.player)
	end), "a taken-over lease cannot write")
	assert(
		t.store.raw._revision == 0 and t.store.raw._session.owner == "other-server",
		"taken-over record is untouched"
	)

	-- DataStore kesintisi kira süresinden uzun sürse de oturum düşmez; kayıt dönünce ilerleme yazılır.
	t = loaded()
	t.service.addCash(t.player, 10)
	t.store.actions = { { failBefore = true }, { failBefore = true }, { failBefore = true } }
	assert(not t.call(function()
		return t.service.save(t.player)
	end), "outage save fails")
	t.advance(200)
	assert(t.service.tryGet(t.player) ~= nil, "retrying saves keep the session alive past the lease")
	t.service.addCash(t.player, 5)
	assert(
		t.call(function()
			return t.service.save(t.player)
		end),
		"first save after the outage succeeds"
	)
	assert(
		t.store.raw.cash == Config.STARTING_CASH + 15 and t.player.attributes.DataStatus == "Active",
		"progress made during the outage is persisted"
	)

	-- Kilit başka sunucudayken giriş beklenir (hızlı sunucu değiştirme); çok uzun sürerse açık hatayla düşer.
	t = loaded()
	t.service.addCash(t.player, 7)
	assert(
		t.call(function()
			return t.service.release(t.player)
		end),
		"first server releases"
	)
	t.store.raw._session = { owner = "slow-server", expiresAt = 2000000000 + 40 }
	local rejoined = t.call(function()
		return t.service.load(t.player)
	end)
	assert(
		rejoined ~= nil and rejoined.cash == Config.STARTING_CASH + 7,
		"a lock that expires within the wait window is acquired"
	)
	assert(t.player.attributes.DataStatus == "Active", "waited load becomes active")
	assert(t.metrics.counters.LoadLockWait ~= nil, "lock waits are counted")
	t = loaded()
	assert(
		t.call(function()
			return t.service.release(t.player)
		end),
		"release before long lock"
	)
	t.store.raw._session = { owner = "stuck-server", expiresAt = 2000000000 + 170 }
	assert(t.call(function()
		return t.service.load(t.player)
	end) == nil, "a lock held beyond the wait window fails the load")
	assert(
		t.player.attributes.DataStatus == "Failed"
			and t.player.attributes.DataError == "Profil başka bir sunucuda açık",
		"the failure names the lock"
	)
	assert(t.store.raw._session.owner == "stuck-server", "the other server's lock stays untouched")

	-- Gelecek sürüm asla boş profille açılmaz veya geri yazılmaz.
	t = fixture()
	t.store.raw = { version = 999, cash = 12345 }
	assert(t.call(function()
		return t.service.load(t.player)
	end) == nil, "future schema must fail load")
	assert(t.store.raw.version == 999 and t.store.raw.cash == 12345, "future record stays intact")
	-- Ölçüm: her kayıtta boyut yazılır ve sayaçlar güncellenir
	t = loaded()
	t.service.addCash(t.player, 5)
	assert(
		t.call(function()
			return t.service.save(t.player)
		end),
		"measured save succeeds"
	)
	assert((t.metrics.values.SaveBytesLast or 0) > 100, "payload size is measured")
	assert(t.metrics.values.SaveBytesMax == t.metrics.values.SaveBytesLast, "largest payload is tracked")
	assert(t.player.attributes.DataBytes == t.metrics.values.SaveBytesLast, "size is published for diagnostics")

	-- Yedek: ilk başarılı kayıtta yazılır, aralık dolmadan tekrar yazılmaz, sonra diğer yuvaya döner
	local backupKey1, backupKey2 = "player_42_backup1", "player_42_backup2"
	t.runUntil(function(): boolean
		return t.store.extra[backupKey1] ~= nil
	end)
	local first = t.store.extra[backupKey1]
	assert(
		first._session == nil and first._revision == nil and first._backupAt ~= nil,
		"backup omits lock and revision"
	)
	assert(first.cash == Config.STARTING_CASH + 5, "backup holds the saved progress")
	t.service.addCash(t.player, 10)
	assert(
		t.call(function()
			return t.service.save(t.player)
		end),
		"second save inside the interval"
	)
	t.runUntil(function(): boolean
		return true
	end)
	assert(
		t.store.extra[backupKey2] == nil and t.store.extra[backupKey1].cash == first.cash,
		"no backup before the interval"
	)
	for _ = 1, 7 do
		t.advance(100)
		assert(
			t.call(function()
				return t.service.save(t.player)
			end),
			"periodic save keeps the lease"
		)
	end
	t.service.addCash(t.player, 20)
	assert(
		t.call(function()
			return t.service.save(t.player)
		end),
		"save after the interval"
	)
	t.runUntil(function(): boolean
		return t.store.extra[backupKey2] ~= nil
	end)
	assert(t.store.extra[backupKey2].cash == Config.STARTING_CASH + 15, "second backup rotates to the other slot")

	-- Kurtarma: asıl kayıt bozulursa en yeni çözülebilir yedekten açılır; bozuk kayıt karantinaya alınır
	assert(
		t.call(function()
			return t.service.release(t.player)
		end),
		"release before corruption"
	)
	local corrupt = { version = saveVersion, mainFarms = 5, activeMainFarmId = "1", _revision = t.store.raw._revision }
	t.store.raw = corrupt
	t.player.Parent = true
	local recovered = t.call(function()
		return t.service.load(t.player)
	end)
	assert(recovered, "a corrupt primary opens from the backup")
	assert(recovered.cash == Config.STARTING_CASH + 15, "newest backup is used")
	assert(recovered.transfers.quarantined == true, "a recovered financial history must block automated replay")
	assert(
		t.call(function()
			return t.service.save(t.player)
		end),
		"recovery quarantine is persisted"
	)
	assert(t.store.raw.transfers.quarantined == true, "financial quarantine survives subsequent login")
	assert(
		t.player.attributes.DataRecovered == true and t.metrics.counters.ProfileRecovered == 1,
		"recovery is flagged"
	)
	assert(
		t.store.extra["player_42_quarantine"] and t.store.extra["player_42_quarantine"].mainFarms == 5,
		"the corrupt record is kept in quarantine"
	)

	-- Gelecek sürüm: yedekle ezilmez (yükleme reddedilir, karantina yok)
	local future = fixture()
	future.store.raw = { version = 99, _revision = 3 }
	future.store.extra["player_42_backup1"] = { version = saveVersion, _backupAt = 1 }
	assert(not future.call(function()
		return future.service.load(future.player)
	end), "future schema is rejected")
	assert(
		future.store.extra["player_42_quarantine"] == nil,
		"a rejected future record is never quarantined or replaced"
	)

	-- Yedek yoksa bozuk kayıt yine kapalı kalır (veri uydurulmaz)
	local noBackup = fixture()
	noBackup.store.raw = { version = saveVersion, mainFarms = 5, activeMainFarmId = "1" }
	assert(not noBackup.call(function()
		return noBackup.service.load(noBackup.player)
	end), "corrupt primary without backup fails closed")
	assert(noBackup.player.attributes.DataStatus == "Failed", "failure is shown to the player")

	-- pushState birleştirme: aynı karedeki çağrılar tek pakette, sıkışık çağrılar 0,25 sn aralıkla gider.
	local push = loaded()
	local function idle()
		push.call(function()
			return nil
		end)
	end
	push.service.pushState(push.player)
	push.service.pushState(push.player)
	push.service.pushState(push.player)
	assert(#push.sent == 0, "pushState must not send synchronously")
	idle()
	assert(#push.sent == 1, "same-frame pushState calls collapse into one packet")
	local firstPacket = push.sent[1]
	local lightFarms = firstPacket.payload.mainFarms
	assert(
		lightFarms ~= nil and lightFarms["1"] ~= nil and lightFarms["1"].barnLevel == firstPacket.payload.barnLevel,
		"only a light farm view is sent to the client"
	)
	assert(lightFarms["1"].animals == nil and lightFarms["1"].cash == nil, "full parked farm records are not sent")
	assert(
		typeof(firstPacket.payload.mainFarmSummaries) == "table" and #firstPacket.payload.mainFarmSummaries == 1,
		"summaries replace parked farm records"
	)
	assert(
		firstPacket.payload.cash == Config.STARTING_CASH and firstPacket.payload.animals ~= nil,
		"active farm fields stay at top level"
	)
	local data = push.service.tryGet(push.player)
	assert(data.mainFarms ~= nil and data.mainFarmSummaries == nil, "server data is not mutated by sending")
	assert(firstPacket.revision >= 1, "packet carries a revision")

	-- Hemen ardından gelen çağrılar 0,25 sn dolunca tek pakette gider; son durum gönderilir.
	push.service.pushState(push.player)
	idle()
	assert(#push.sent == 1, "throttled call waits for the interval")
	data.cash += 5
	push.service.pushState(push.player)
	push.service.pushState(push.player)
	push.advance(0.1)
	idle()
	assert(#push.sent == 1, "still inside the 0.25 s window")
	push.advance(0.2)
	idle()
	assert(#push.sent == 2, "pending calls flush once after the window")
	assert(push.sent[2].payload.cash == data.cash, "flush carries the latest state")
	assert(push.sent[2].revision > firstPacket.revision, "revisions keep increasing")

	-- Sessiz bir aradan sonra ilk çağrı gecikmesiz (aynı kare) gider.
	push.advance(5)
	push.service.pushState(push.player)
	idle()
	assert(#push.sent == 3, "firstPacket call after a quiet period is not delayed")

	-- Bekleyen PlayerState varken pushEconomy ek paket (ve revizyon boşluğu) üretmez.
	push.advance(5)
	push.service.pushState(push.player)
	local beforeEconomy = #push.economy
	push.service.pushEconomy(push.player)
	assert(#push.economy == beforeEconomy, "pushEconomy is skipped while a state packet is pending")
	idle()
	assert(#push.sent == 4, "the pending state packet still goes out")
	push.service.pushEconomy(push.player)
	assert(#push.economy == beforeEconomy + 1, "pushEconomy sends when nothing is pending")
	assert(push.economy[#push.economy].revision == push.sent[4].revision + 1, "economy revision follows without gap")

	-- Oturum kapanınca bekleyen paket gönderilmez.
	push.service.pushState(push.player)
	push.call(function()
		return push.service.release(push.player)
	end)
	local count = #push.sent
	push.advance(1)
	idle()
	assert(#push.sent == count, "no packet after the session is gone")

	local transaction = loaded()
	local root = assert(transaction.service.tryGet(transaction.player), "transaction profile exists")
	root.gold = 500
	local afterCount = 0
	transaction.store.actions = { { delay = 1 } }
	transaction.tasks.delay(0.1, function()
		assert(transaction.service.tryGet(transaction.player) == nil, "financial checkpoint hides the mutable account")
		assert(not transaction.service.trySpend(transaction.player, 1), "concurrent spending is blocked")
		transaction.service.addCash(transaction.player, 500)
	end)
	assert(
		transaction.call(function()
			return transaction.service.transactAccount(
				transaction.player,
				function(financialData: any): (boolean, string?)
					financialData.gold -= 100
					financialData.owned.conveniences.auto_collect = true
					return true, "granted"
				end,
				function()
					afterCount += 1
				end
			)
		end),
		"financial transaction persists before success"
	)
	assert(
		root.gold == 400 and root.cash == Config.STARTING_CASH,
		"blocked mutations cannot change the transaction snapshot"
	)
	assert(
		transaction.store.raw.gold == 400 and transaction.store.raw.owned.conveniences.auto_collect,
		"wallet and entitlement commit together"
	)
	assert(
		afterCount == 1 and transaction.service.tryGet(transaction.player) == root,
		"successful commit unlocks the same root exactly once"
	)
	assert(not transaction.call(function()
		return transaction.service.transactAccount(transaction.player, function(financialData: any): (boolean, string?)
			financialData.gold = 0
			financialData.owned.conveniences.auto_collect = nil
			return false, "rejected"
		end)
	end), "a rejected mutator is rolled back before any write")
	assert(
		root.gold == 400 and root.owned.conveniences.auto_collect,
		"rejection restores account contents without replacing its root"
	)
	transaction.store.actions = { { failBefore = true }, { failBefore = true }, { failBefore = true } }
	assert(not transaction.call(function()
		return transaction.service.transactAccount(transaction.player, function(financialData: any): (boolean, string?)
			financialData.gold -= 100
			financialData.owned.conveniences.pet_cash = true
			return true, nil
		end, function()
			afterCount += 1
		end)
	end), "an uncertain transaction is not reported as committed")
	assert(
		transaction.service.tryGet(transaction.player) == nil and root.gold == 300,
		"uncertain write retains tentative financialData behind the lock"
	)
	transaction.runUntil(function(): boolean
		return transaction.player.attributes.AccountTransactionPending == false
	end)
	assert(
		transaction.store.raw.gold == 300 and transaction.store.raw.owned.conveniences.pet_cash,
		"maintenance retries the same financial intent"
	)
	assert(
		afterCount == 2 and transaction.service.tryGet(transaction.player) == root,
		"retry unlocks and presents exactly once"
	)

	print(
		"PASS player-data service: retries, uncertain responses, save/release overlap, leave during load, retained final save, ownership/lease loss, future schema, financial mutex"
	)
end
