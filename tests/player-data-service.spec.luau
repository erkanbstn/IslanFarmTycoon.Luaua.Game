--!strict
-- Gerçek PlayerDataService test runner tarafından bir factory içine alınır.
-- Sadece Roblox servisleri/saat/scheduler taklit edilir; kayıt algoritması aynıdır.
return function(createService: any, Config: any)
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
		local remotes = {
			get = function(): any
				return { FireClient = function() end }
			end,
		}
		local dateTime = {
			now = function(): any
				return { UnixTimestampMillis = (2000000000 + clock) * 1000 }
			end,
		}
		local metrics = { increment = function() end, duration = function() end }
		local player: any = { UserId = 42, Name = "Fixture", Parent = true, attributes = {} }
		function player:SetAttribute(name: string, value: any)
			self.attributes[name] = value
		end
		function player:GetAttribute(name: string): any
			return self.attributes[name]
		end
		return {
			service = createService(engine, tasks, instances, time, remotes, dateTime, metrics, function() end),
			store = store,
			player = player,
			call = call,
			tasks = tasks,
			runUntil = runUntil,
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
	assert(not t.call(function()
		return t.service.release(t.player)
	end), "expired owner cannot force a final write")
	assert(t.store.raw._revision == 0, "expired owner must not commit")

	-- Gelecek sürüm asla boş profille açılmaz veya geri yazılmaz.
	t = fixture()
	t.store.raw = { version = 999, cash = 12345 }
	assert(t.call(function()
		return t.service.load(t.player)
	end) == nil, "future schema must fail load")
	assert(t.store.raw.version == 999 and t.store.raw.cash == 12345, "future record stays intact")
	print(
		"PASS player-data service: retries, uncertain responses, save/release overlap, leave during load, retained final save, ownership/lease loss, future schema"
	)
end
