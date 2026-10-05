--!strict
-- Gerçek SaveStore sıralama API'si (sahte DataStoreService): doğrulama, çağ başına mağaza, hata, bütçe, gecikme ve Studio belleği.
return function(factory: any)
	local function fixture(nonpersistent: boolean): (any, any)
		local state: any = {
			clock = 1,
			stores = {}, -- mağaza adı -> { [anahtar] = değer }
			names = {}, -- açılan mağaza adları (sırayla)
			failWrite = false,
			failRead = false,
			writeBudget = 100,
			readBudget = 100,
			yields = 0,
			epoch = 0,
			calls = 0,
		}
		local ordered = function(name: string): any
			state.stores[name] = state.stores[name] or {}
			local values = state.stores[name]
			local object = {}
			function object:SetAsync(key: string, value: number)
				state.calls += 1
				state.yields += 1 -- gecikmeyi temsil eder (gerçek çağrı bekler)
				if state.failWrite then
					error("write unavailable")
				end
				values[key] = value
			end
			function object:GetSortedAsync(ascending: boolean, count: number): any
				state.calls += 1
				state.yields += 1
				if state.failRead then
					error("read unavailable")
				end
				assert(ascending == false and count >= 1 and count <= 25, "reads are descending and bounded")
				local items = {}
				for key, value in values do
					table.insert(items, { key = key, value = value })
				end
				table.sort(items, function(a: any, b: any): boolean
					return a.value > b.value
				end)
				while #items > count do
					table.remove(items)
				end
				return {
					GetCurrentPage = function(): any
						return items
					end,
				}
			end
			return object
		end
		local plainStore: any = {
			GetAsync = function(_self: any, key: string): any
				if key == "__meta_epoch" then
					return state.epoch
				end
				return nil
			end,
			UpdateAsync = function(_self: any, key: string, transform: any): any
				if key == "__meta_epoch" then
					state.epoch = transform(state.epoch)
					return state.epoch
				end
				return nil
			end,
		}
		local replicated: any = {}
		function replicated:WaitForChild(_name: string): any
			return self
		end
		local services: any = {
			DataStoreService = {
				GetDataStore = function(): any
					return plainStore
				end,
				GetOrderedDataStore = function(_self: any, name: string): any
					table.insert(state.names, name)
					return ordered(name)
				end,
				GetRequestBudgetForRequestType = function(_self: any, kind: string): number
					return if kind == "set" then state.writeBudget else state.readBudget
				end,
			},
			ReplicatedStorage = replicated,
			RunService = {
				IsStudio = function(): boolean
					return nonpersistent
				end,
			},
			Workspace = {
				GetAttribute = function(_self: any, name: string): any
					return if name == "StudioNonPersistentData" then nonpersistent else nil
				end,
			},
		}
		local gameFake = {
			GetService = function(_self: any, name: string): any
				return assert(services[name], `unexpected service {name}`)
			end,
		}
		local noOp = function() end
		local osFake = {
			clock = function(): number
				return state.clock
			end,
			time = function(): number
				return 2000000000
			end,
		}
		local counters: { [string]: number } = {}
		local metrics = {
			increment = function(name: string)
				counters[name] = (counters[name] or 0) + 1
			end,
		}
		state.counters = counters
		local enumFake = { DataStoreRequestType = { SetIncrementSortedAsync = "set", GetSortedAsync = "get" } }
		return factory(gameFake, { wait = noOp }, osFake, metrics, noOp, enumFake), state
	end

	-- Kalıcı mod: yazma/okuma, çağ başına ayrı mağaza
	local store, state = fixture(false)
	assert(store.rankingAvailable(), "persistent store offers rankings")
	assert(store.publishRank("rebirth", 101, 4) and store.publishRank("rebirth", 202, 9), "valid writes succeed")
	assert(store.publishRank("rebirth", 101, 5), "a player's value can be rewritten")
	assert(store.publishRank("rebirth", 303, 0), "zero is a real value")
	local rows = assert(store.readTopRank("rebirth", 6))
	assert(
		#rows == 3 and rows[1].userId == 202 and rows[1].score == 9 and rows[2].userId == 101 and rows[2].score == 5,
		"top rows are descending with numeric ids"
	)
	assert(store.publishRank("rebirth", 101, 2), "a lower value is written too (reset or correction)")
	assert(
		assert(store.readTopRank("rebirth", 6))[2].score == 2 or assert(store.readTopRank("rebirth", 6))[3].score == 2,
		"drop"
	)
	local farms = assert(store.readTopRank("farms", 6))
	assert(#farms == 0, "boards are independent")
	assert(#assert(store.readTopRank("rebirth", 1)) == 1, "limit is honored")
	assert(#assert(store.readTopRank("rebirth", 1000)) <= 25, "limit is capped at the API maximum")
	assert(state.names[1] == "IslandFarmTycoon_v2_Rank_rebirth_e0", "store name carries board and epoch")

	-- Geçersiz girdi hiçbir çağrı yapmaz
	local callsBefore = state.calls
	for _, bad in { 0 / 0, -1, math.huge, "5", true } do
		local ok, reason = store.publishRank("rebirth", 111, bad)
		assert(not ok and reason == "invalid", "bad score is rejected")
	end
	assert(not store.publishRank("cash", 111, 1) and not store.publishRank("rebirth", 0, 1), "bad board or user")
	assert(not store.publishRank("rebirth", 1.5, 1) and not store.publishRank("rebirth", 0 / 0, 1), "bad user ids")
	assert(store.readTopRank("cash", 5) == nil and store.readTopRank("rebirth", 0 / 0) == nil, "bad reads")
	assert(state.calls == callsBefore, "invalid input never reaches the DataStore")

	-- Hata ve gecikme: çağrı hatası yutulur, neden döner, sayaç artar
	state.failWrite = true
	local okWrite, writeReason = store.publishRank("rebirth", 101, 7)
	assert(
		not okWrite and writeReason ~= nil and state.counters.RankWriteFailed == 1,
		"write errors are reported, not thrown"
	)
	state.failWrite = false
	state.failRead = true
	local failedRows, readReason = store.readTopRank("rebirth", 6)
	assert(failedRows == nil and readReason ~= nil and state.counters.RankReadFailed == 1, "read errors are reported")
	state.failRead = false
	assert(store.readTopRank("rebirth", 6), "reads recover after the outage")
	assert(state.yields > 0, "calls model yielding DataStore latency")

	-- Kota (bütçe): yeterli bütçe yoksa çağrı yapılmaz
	state.writeBudget = 1
	local callsAtBudget = state.calls
	local okBudget, budgetReason = store.publishRank("rebirth", 101, 8)
	assert(not okBudget and budgetReason == "budget" and state.calls == callsAtBudget, "writes skip when budget is low")
	assert(state.counters.RankWriteSkippedBudget == 1, "skipped write is counted")
	state.writeBudget = 100
	state.readBudget = 0
	local noRows, noReason = store.readTopRank("rebirth", 6)
	assert(
		noRows == nil and noReason == "budget" and state.calls == callsAtBudget,
		"reads skip when budget is exhausted"
	)
	state.readBudget = 100

	-- Yönetici sıfırlaması (çağ artışı): yeni ad, boş başlangıç; eski mağaza korunur ama okunmaz
	assert(store.bumpEpoch() == 1, "epoch bumps")
	assert(#assert(store.readTopRank("rebirth", 6)) == 0, "a new epoch starts with empty boards")
	assert(store.publishRank("rebirth", 101, 1), "new epoch accepts writes")
	assert(state.names[#state.names] == "IslandFarmTycoon_v2_Rank_rebirth_e1", "new epoch uses a new store name")
	assert(next(state.stores.IslandFarmTycoon_v2_Rank_rebirth_e0) ~= nil, "old epoch data is not deleted")

	-- Başka sunucuda çağ artarsa bu sunucu da en geç 5 dakikada yeni mağazayı kullanır (eski çağ tablosuna yazmaz)
	state.epoch = 7
	assert(store.publishRank("rebirth", 101, 3), "writes keep working inside the refresh window")
	assert(
		state.stores.IslandFarmTycoon_v2_Rank_rebirth_e7 == nil,
		"the cached epoch is used inside the refresh window"
	)
	state.clock += 301
	assert(store.publishRank("rebirth", 101, 3), "writes keep working after the refresh window")
	assert(
		state.stores.IslandFarmTycoon_v2_Rank_rebirth_e7 ~= nil
			and next(state.stores.IslandFarmTycoon_v2_Rank_rebirth_e7) ~= nil,
		"after the refresh interval the new epoch's board is used"
	)

	-- Studio kayıtsız mod: yalnızca bellek, DataStore'a dokunmaz
	local memory, memoryState = fixture(true)
	assert(memory.rankingAvailable(), "memory rankings keep Studio visuals working")
	assert(memory.publishRank("farms", 5, 12) and memory.publishRank("farms", 6, 20), "memory writes")
	local memoryRows = assert(memory.readTopRank("farms", 6))
	assert(#memoryRows == 2 and memoryRows[1].userId == 6 and memoryRows[1].score == 20, "memory rows are ordered")
	assert(not memory.publishRank("farms", 7, 0 / 0), "memory writes are validated too")
	assert(memoryState.calls == 0 and #memoryState.names == 0, "nonpersistent mode never touches OrderedDataStore")
	print("PASS save store ranking: validation, epoch-scoped stores, failures, budget skips and Studio memory")
end
