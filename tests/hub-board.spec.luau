--!strict
-- Meydan panoları (sahte dünya): yerel sunucu sıralaması + iki genel tablo (rebirth, tamamlanmış çiftlik).
return function(createService: any, config: any, leaderboard: any, adminPolicy: any)
	local ADMIN_ID = 11641916529
	local boards: { [string]: any } = { PlayerBoard = {}, RebirthBoard = {}, FarmBoard = {} }
	local available = false
	local studio = false
	local players: { any } = {
		{ UserId = 1, DisplayName = "Ada" },
		{ UserId = 2, DisplayName = "Bora" },
		{ UserId = 3, DisplayName = "Cem" },
	}
	local saves: { [any]: any } = {
		[players[1]] = { cash = 100.9, progression = { count = 30 }, farms = { "1", "2" }, complete = 2 },
		[players[2]] = { cash = 200, farms = { "1" }, complete = 1 },
	}
	local rows: { [string]: { any } } = { PlayerBoard = {}, RebirthBoard = {}, FarmBoard = {} }
	local worldRoot: any = {}
	function worldRoot:FindFirstChild(name: string, recursive: boolean): any
		assert(recursive, "boards are searched recursively")
		return if available then boards[name] else nil
	end
	local workspaceMock: any = {}
	function workspaceMock:FindFirstChild(name: string): any
		assert(name == "World", "boards live under the world model")
		return worldRoot
	end
	local userService = {
		fail = false,
		requests = 0,
		infos = {
			[10] = { Id = 10, Username = "ten_user", DisplayName = "Onuncu" },
			[11] = { Id = 11, Username = "eleven_user", DisplayName = "" },
			[12] = { Id = 12, Username = "long", DisplayName = string.rep("u", 80) },
		} :: { [number]: any },
	}
	function userService:GetUserInfosByUserIdsAsync(ids: { number }): any
		self.requests += 1
		if self.fail then
			error("user service unavailable")
		end
		local result = {}
		for _, id in ids do
			if self.infos[id] then
				table.insert(result, self.infos[id])
			end
		end
		return result
	end
	local node: any = {}
	function node:WaitForChild(_name: string): any
		return self
	end
	local gameMock: any = {}
	function gameMock:GetService(name: string): any
		if name == "Players" then
			return {
				GetPlayers = function(): any
					return players
				end,
			}
		elseif name == "Workspace" then
			return workspaceMock
		elseif name == "UserService" then
			return userService
		elseif name == "RunService" then
			return {
				IsStudio = function(): boolean
					return studio
				end,
			}
		end
		return node
	end
	local workers: { thread } = {}
	local waits: { number } = {}
	local taskMock = {
		spawn = function(callback: () -> ())
			table.insert(workers, coroutine.create(callback))
		end,
		wait = function(seconds: number)
			local index = 0
			for position, worker in workers do
				if worker == coroutine.running() then
					index = position
				end
			end
			waits[index] = seconds
			coroutine.yield()
		end,
	}
	local function tick(index: number)
		local ok, err = coroutine.resume(workers[index])
		assert(ok, tostring(err))
	end
	local clock = 1000
	local osMock = {
		clock = function(): number
			return clock
		end,
	}

	local store = {
		persistent = true,
		published = {} :: { any },
		rows = {} :: { [string]: { any } },
		publishFails = false,
		readFails = false,
		readCalls = 0,
	}
	local fakeStore = {
		rankingAvailable = function(): boolean
			return store.persistent
		end,
		publishRank = function(board: string, userId: number, score: number): (boolean, string?)
			table.insert(store.published, { board = board, userId = userId, score = score })
			if store.publishFails then
				return false, "budget"
			end
			return true, nil
		end,
		readTopRank = function(board: string, limit: number): (any, string?)
			store.readCalls += 1
			assert(limit >= config.MAP_PLOT_COUNT and limit <= 25, "reads request a bounded page")
			if store.readFails or not store.persistent then
				return nil, "unavailable"
			end
			return store.rows[board] or {}, nil
		end,
	}
	local progressionFake = {
		progress = function(data: any): any
			return { farmsComplete = data.complete or 0, farmsTotal = config.MAIN_FARM_LIMIT }
		end,
	}
	local function make(storeImpl: any)
		workers = {}
		local service = createService(
			gameMock,
			taskMock,
			osMock,
			function() end,
			config,
			{
				formatMoney = function(cash: number): string
					return `${cash}`
				end,
			},
			progressionFake,
			{
				setBoardRow = function(actualBoard: any, index: number, name: string, value: string)
					for boardName, board in boards do
						if board == actualBoard then
							rows[boardName][index] = { name = name, value = value }
						end
					end
				end,
			},
			adminPolicy,
			leaderboard,
			{
				tryGet = function(player: any): any
					return saves[player]
				end,
				getFarmIds = function(player: any): any
					return saves[player].farms
				end,
			},
			storeImpl
		)
		service.init()
		service.init()
		return service
	end
	make(fakeStore)
	assert(#workers == 2, "initializes one local and one global worker only")
	local function clearRows()
		for name in rows do
			rows[name] = {}
		end
	end

	-- Yerel sıralama (mevcut davranış)
	tick(1)
	assert(waits[1] == 3, "local ranking keeps its bounded refresh interval")
	assert(next(rows.PlayerBoard) == nil, "missing world is safely retried")
	available = true
	tick(1)
	assert(
		rows.PlayerBoard[1].name == "1. Bora" and rows.PlayerBoard[2].name == "2. Ada",
		"cash ranking remains descending"
	)
	assert(rows.PlayerBoard[1].value == "$200 · 1 ada\nRebirth: 0", "legacy profile displays zero rebirth")
	assert(
		rows.PlayerBoard[2].value == "$100 · 2 ada\nRebirth: 30",
		"terminal rebirth count and farm count appear alongside cash"
	)
	assert(rows.PlayerBoard[3].name == "" and rows.PlayerBoard[3].value == "", "unloaded player cannot occupy a row")
	saves[players[1]].progression.count = 29
	saves[players[1]].cash = 300
	tick(1)
	assert(
		rows.PlayerBoard[1].name == "1. Ada" and rows.PlayerBoard[1].value == "$300 · 2 ada\nRebirth: 29",
		"live rebirth/cash changes refresh together"
	)
	saves[players[1]] = nil
	tick(1)
	assert(rows.PlayerBoard[2].name == "" and rows.PlayerBoard[2].value == "", "departed profile clears stale text")
	for index = 3, config.MAP_PLOT_COUNT do
		assert(rows.PlayerBoard[index].name == "" and rows.PlayerBoard[index].value == "", "unused rows are cleared")
	end
	saves[players[1]] = { cash = 100.9, progression = { count = 30 }, farms = { "1", "2" }, complete = 2 }

	-- Genel tablolar: ilk açılış, okuma gelmeden yalnız bu sunucu + "Yükleniyor"
	clearRows()
	tick(2)
	assert(waits[2] == 5, "global worker uses its own bounded step")
	assert(
		rows.RebirthBoard[1].name == "1. Ada"
			and rows.RebirthBoard[1].value == "Rebirth: 30"
			and rows.RebirthBoard[2].name == "",
		"only players with a rebirth are listed: a zero-rebirth player never appears on the rebirth board"
	)
	assert(
		rows.FarmBoard[1].name == "1. Ada" and rows.FarmBoard[1].value == `{30 * config.MAIN_FARM_LIMIT + 2} çiftlik`,
		"farm score adds past runs and current completed farms"
	)
	assert(store.readCalls == 2, "each board reads once on startup")
	assert(#store.published == 3, "present players publish once per board, except a first zero score")
	assert(
		rows.RebirthBoard[3].name == "" and rows.RebirthBoard[3].value == "",
		"empty rows are blank when the list loaded"
	)

	-- Yazma: aynı değer tekrar yazılmaz, değişim aralığı bekler, başarısızlıkta geri çekilir
	clock += 5
	tick(2)
	assert(#store.published == 3, "unchanged values are not rewritten")
	saves[players[2]].progression = { count = 3 }
	clock += 5
	tick(2)
	assert(
		#store.published == 4 and store.published[4].board == "rebirth" and store.published[4].userId == 2,
		"a first non-zero score publishes at once while a changed value (farms) waits for the interval"
	)
	clock += leaderboard.PUBLISH_INTERVAL
	tick(2)
	-- Rebirth değişimi iki tabloyu da etkiler (çiftlik değeri tur sayısını içerir): iki yazma
	assert(#store.published == 5, "the changed value publishes on both boards once the interval passes")
	local function lastFor(board: string, userId: number): any
		for index = #store.published, 1, -1 do
			local item = store.published[index]
			if item.board == board and item.userId == userId then
				return item
			end
		end
		return nil
	end
	assert(lastFor("rebirth", 2).score == 3, "rebirth payload")
	assert(lastFor("farms", 2).score == 3 * config.MAIN_FARM_LIMIT + 1, "farm payload")
	saves[players[2]].progression = { count = 4 }
	store.publishFails = true
	clock += leaderboard.PUBLISH_INTERVAL
	tick(2)
	assert(#store.published == 7, "failing writes are attempted once per board")
	clock += 10
	tick(2)
	assert(#store.published == 7, "a failed write backs off instead of retrying immediately")
	store.publishFails = false
	clock += leaderboard.PUBLISH_INTERVAL * 4
	tick(2)
	assert(#store.published == 9 and lastFor("rebirth", 2).score == 4, "the writes retry after the backoff and succeed")

	-- Okuma: genel satırlar, canlı değer ezmesi, ad çözümü, uzun ad, geçersiz satırlar, yönetici
	store.rows.rebirth = {
		{ userId = 10, score = 50 },
		{ userId = 11, score = 40 },
		{ userId = 12, score = 40 },
		{ userId = 1, score = 99 }, -- Ada'nın eski/yüksek kaydı: sunucudaki canlı değer (30) ezer
		{ userId = 13, score = 20 }, -- adı çözülemeyen
		{ userId = ADMIN_ID, score = 1000 }, -- yönetici hiç görünmez
		{ userId = 14, score = 0 / 0 }, -- bozuk satır
		{ userId = 15, score = -3 },
	}
	clock += leaderboard.READ_INTERVAL
	userService.requests = 0
	tick(2)
	assert(userService.requests == 1, "unknown offline names are resolved in a single batch")
	local first = rows.RebirthBoard[1]
	assert(first.name == "1. Onuncu" and first.value == "Rebirth: 50", "display name is used (not the username)")
	assert(rows.RebirthBoard[2].name == "2. eleven_user", "empty display name falls back to the username")
	assert(
		rows.RebirthBoard[4].name == "4. Ada" and rows.RebirthBoard[4].value == "Rebirth: 30",
		"live value overrides the stored one"
	)
	local longName = rows.RebirthBoard[3].name
	assert(utf8.len(longName) <= leaderboard.NAME_MAX + 4, "very long names are truncated")
	local seenAdmin = false
	for _, row in rows.RebirthBoard do
		if string.find(row.name, tostring(ADMIN_ID), 1, true) or row.value == "Rebirth: 1000" then
			seenAdmin = true
		end
	end
	assert(not seenAdmin, "the administrator's stored row is never listed")
	assert(rows.RebirthBoard[6].name ~= nil, "board rows stay within the modeled row count")

	-- Yönetici oyuncu yazılmaz ve listelenmez
	players[4] = { UserId = ADMIN_ID, DisplayName = "Yönetici" }
	saves[players[4]] = { cash = 1e9, progression = { count = 30 }, farms = { "1" }, complete = 6 }
	local publishedBefore = #store.published
	clock += leaderboard.PUBLISH_INTERVAL
	tick(2)
	for index = publishedBefore + 1, #store.published do
		assert(store.published[index].userId ~= ADMIN_ID, "the administrator's values are never published")
	end
	for _, row in rows.RebirthBoard do
		assert(
			not string.find(row.name, "Yönetici", 1, true),
			"the administrator is not listed from the live server either"
		)
	end
	players[4] = nil

	-- Studio'da yönetici test için listelenir ve yazılır (ayrı _Studio/bellek mağazası)
	studio = true
	players[4] = { UserId = ADMIN_ID, DisplayName = "Yönetici" }
	saves[players[4]] = { cash = 1e9, progression = { count = 30 }, farms = { "1" }, complete = 6 }
	clock += leaderboard.PUBLISH_INTERVAL
	tick(2)
	local studioAdmin = false
	for _, row in rows.RebirthBoard do
		if string.find(row.name, "Yönetici", 1, true) then
			studioAdmin = true
		end
	end
	assert(studioAdmin, "in Studio the administrator is listed so the boards can be tested")
	studio = false
	players[4] = nil
	saves = {
		[players[1]] = saves[players[1]],
		[players[2]] = saves[players[2]],
	}

	-- Okuma hatası: son bilinen liste kalır, yeniden deneme geri çekilir, günlük taşmaz
	store.readFails = true
	local readsBefore = store.readCalls
	clock += leaderboard.READ_INTERVAL
	tick(2)
	assert(store.readCalls == readsBefore + 2, "a failed read is attempted for both boards")
	assert(rows.RebirthBoard[1].name == "1. Onuncu", "the last known list stays visible during an outage")
	clock += 5
	tick(2)
	assert(store.readCalls == readsBefore + 2, "failed reads back off")
	store.readFails = false
	clock += leaderboard.BACKOFF_MAX
	store.rows.rebirth = {}
	tick(2)
	assert(store.readCalls == readsBefore + 4, "reads resume after the outage")
	assert(
		rows.RebirthBoard[1].name == "1. Ada" and rows.RebirthBoard[1].value == "Rebirth: 30",
		"an emptied list shows only live players"
	)

	-- Sıfırlama: kayıtlı değerler boşalır, sunucudaki sıfırlanmış oyuncu 0 ile görünür (eski yüksek değer yok)
	saves[players[2]].progression = nil
	store.rows.rebirth = { { userId = 2, score = 4 } }
	clock += leaderboard.READ_INTERVAL
	tick(2)
	local bora = 0
	for _, row in rows.RebirthBoard do
		if row.name ~= "" and string.find(row.name, "Bora", 1, true) then
			bora += 1
		end
	end
	assert(bora == 0, "a reset account (live zero) disappears even though a stale stored value exists")
	-- Kimsenin değeri yoksa (liste okundu): tek açıklama satırı
	saves[players[1]].progression = nil
	store.rows.rebirth = {}
	clock += leaderboard.READ_INTERVAL
	tick(2)
	assert(rows.RebirthBoard[1].name == "Henüz kimse yok" and rows.RebirthBoard[2].name == "", "an empty list says so")
	saves[players[1]].progression = { count = 30 }

	-- Genel mağaza hiç kullanılamıyorsa: açıklama satırı, yerel oyuncular yine görünür, çökme yok
	store.readFails = false
	players[4] = nil
	local offline = {
		rankingAvailable = function(): boolean
			return false
		end,
		publishRank = function(): (boolean, string?)
			return false, "unavailable"
		end,
		readTopRank = function(): (any, string?)
			return nil, "unavailable"
		end,
	}
	make(offline)
	clearRows()
	tick(1)
	assert(rows.RebirthBoard[3] == nil or rows.RebirthBoard[3].name == "", "fresh board has no stale rows")
	tick(2)
	assert(
		rows.RebirthBoard[1].name == "1. Ada",
		"local players with a rebirth are still listed when the global store is down"
	)
	assert(rows.RebirthBoard[2].name == "Şu an kullanılamıyor", "an explanatory row follows the listed players")
	assert(rows.RebirthBoard[3].name == "", "no more rows after the explanation")
	-- Mağaza açık ama ilk okuma henüz başarısız: "Yükleniyor"
	local pending = {
		rankingAvailable = function(): boolean
			return true
		end,
		publishRank = function(): (boolean, string?)
			return true, nil
		end,
		readTopRank = function(): (any, string?)
			return nil, "budget"
		end,
	}
	make(pending)
	clearRows()
	tick(2)
	assert(rows.RebirthBoard[2].name == "Yükleniyor…", "before any successful read the board says it is loading")
	print("PASS hub board: local ranking, global boards, throttle/backoff, admin exclusion, resets and outages")
end
