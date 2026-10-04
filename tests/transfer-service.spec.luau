--!strict
-- Gerçek transfer servisi: kalıcı görüntüler, belirsiz yanıtlar, yeniden başlatma ve tekrar koruması.
return function(createService: any, ledger: any, rules: any)
	local function copy(value: any): any
		if typeof(value) ~= "table" then
			return value
		end
		local result = {}
		for key, entry in value do
			result[key] = copy(entry)
		end
		return result
	end

	local function setup(): any
		local h: any = {
			profiles = {},
			persisted = {},
			inboxes = {},
			modes = {},
			published = {},
			ackMode = nil,
			publishMode = nil,
			saveHook = nil,
			reads = 0,
			saves = 0,
			now = 100,
			players = {},
			remotes = {},
			notifications = {},
			replies = {},
			policy = {},
			dirty = {},
			serial = 0,
		}
		local function signal(): any
			local callbacks = {}
			return {
				Connect = function(_self: any, callback: any)
					table.insert(callbacks, callback)
				end,
				fire = function(...: any)
					for _, callback in callbacks do
						callback(...)
					end
				end,
			}
		end
		for _, id in { 1, 2 } do
			local player: any = { UserId = id, DisplayName = `player{id}`, Parent = true, ready = true }
			-- DataDirty olmaması başarılı save işaretidir.
			player.GetAttribute = function(_self: any, key: string): any
				if key == "WorldReady" then
					return player.ready
				end
				if key == "DataDirty" then
					return h.dirty[id] == true
				end
				return nil
			end
			h.players[id] = player
			h.profiles[id] =
				{ cash = 1000, epoch = 0, lifetimeEarned = 500, transfers = { outbox = {}, received = {} } }
			h.persisted[id] = copy(h.profiles[id])
		end
		local playersService = {
			GetPlayerByUserId = function(_self: any, id: number): any
				return h.players[id]
			end,
			GetPlayers = function(): any
				return { h.players[1], h.players[2] }
			end,
			PlayerRemoving = signal(),
		}
		local node: any = {}
		node.WaitForChild = function(): any
			return node
		end
		local services = {
			Players = playersService,
			ReplicatedStorage = node,
			HttpService = {
				GenerateGUID = function(): string
					h.serial += 1
					return `transfer-{h.serial}`
				end,
			},
		}
		local game = {
			GetService = function(_self: any, name: string): any
				return services[name]
			end,
		}
		local remotes = {
			get = function(name: string): any
				if not h.remotes[name] then
					h.remotes[name] = {
						OnServerEvent = signal(),
						FireClient = function(_self: any, player: any, ...: any)
							table.insert(h.notifications, { player = player, args = { ... } })
						end,
					}
				end
				return h.remotes[name]
			end,
		}
		local dataService = {
			tryGet = function(player: any): any
				return h.profiles[player.UserId]
			end,
			markDirty = function(player: any)
				h.dirty[player.UserId] = true
			end,
			pushState = function() end,
			requestSave = function() end,
			save = function(player: any): boolean
				h.saves += 1
				local id = player.UserId
				local mode = h.modes[id]
				if mode == "failBefore" then
					return false
				end
				local snapshot = copy(h.profiles[id])
				if h.saveHook then
					local hook = h.saveHook
					h.saveHook = nil
					hook(player)
				end
				h.persisted[id] = snapshot
				if mode == "failAfter" then
					return false
				end
				h.dirty[id] = false
				return true
			end,
		}
		local store = {
			publishTransfer = function(id: string, entry: any): boolean
				if h.publishMode == "failBefore" then
					return false
				end
				local nextInbox = ledger.publish(h.inboxes[entry.targetId], id, entry)
				if not nextInbox then
					return false
				end
				h.inboxes[entry.targetId] = nextInbox
				table.insert(h.published, id)
				return h.publishMode ~= "failAfter"
			end,
			readTransferInbox = function(id: number): any
				h.reads += 1
				return ledger.parseInbox(h.inboxes[id])
			end,
			ackTransfers = function(id: number, ids: any): boolean
				if h.ackMode == "failBefore" then
					return false
				end
				local inbox = copy(h.inboxes[id] or {})
				for _, receipt in ids do
					inbox[receipt] = nil
				end
				h.inboxes[id] = inbox
				return h.ackMode ~= "failAfter"
			end,
		}
		local rate = {
			allow = function(): boolean
				return h.rateAllowed ~= false
			end,
			acceptRequest = function(): boolean
				return true
			end,
		}
		local economy = { settlePlayer = function() end }
		local guard = {
			reply = function(_player: any, _id: any, ok: boolean, message: string?)
				table.insert(h.replies, { ok = ok, message = message })
			end,
		}
		-- Sunucudaki politika önbelleğinin yerine geçer; varsayılan: iki oyuncu da "allowed".
		local policy = {
			status = function(player: any): string
				return h.policy[player.UserId] or "allowed"
			end,
			canTrade = function(player: any): boolean
				return (h.policy[player.UserId] or "allowed") == "allowed"
			end,
		}
		local fakeTask = { spawn = function() end, wait = function() end }
		local fakeOs = {
			clock = function(): number
				return h.now
			end,
		}
		local function restart()
			h.profiles = copy(h.persisted)
			h.dirty = {}
			h.service = createService(
				game,
				remotes,
				dataService,
				store,
				economy,
				policy,
				guard,
				rate,
				fakeTask,
				fakeOs,
				function() end
			)
		end
		h.restart = restart
		h.send = function(amount: any, target: any?): boolean
			return h.service.trySend(h.players[1], target or 2, amount)
		end
		h.reconcile = function(id: number): boolean
			return h.service.reconcile(h.players[id], true)
		end
		h.total = function(): number
			local total = h.persisted[1].cash + h.persisted[2].cash
			local pending = {}
			for _, profile in h.persisted do
				for id, entry in profile.transfers.outbox do
					pending[id] = entry
				end
			end
			for _, inbox in h.inboxes do
				for id, entry in inbox do
					pending[id] = entry
				end
			end
			for id, entry in pending do
				if not h.persisted[entry.targetId].transfers.received[id] then
					total += entry.amount
				end
			end
			return total
		end
		restart()
		return h
	end

	local basic = setup()
	assert(basic.send(100), "a valid transfer is accepted")
	assert(basic.profiles[1].cash == 900 and basic.profiles[2].cash == 1100, "debit and credit match")
	assert(basic.profiles[2].lifetimeEarned == 500, "transfers do not inflate earned income")
	assert(basic.total() == 2000, "durable cash plus escrow is conserved")
	for _ = 1, 5 do
		basic.reconcile(1)
		basic.reconcile(2)
	end
	assert(basic.profiles[2].cash == 1100, "repeated reconciliation never credits twice")

	for _, mode in { "failBefore", "failAfter" } do
		local h = setup()
		h.modes[1] = mode
		assert(h.send(100), "uncertain sender save preserves an accepted intent")
		assert(h.profiles[2].cash == 1000 and #h.published == 0, "no publish before confirmed sender checkpoint")
		assert(h.total() == 2000, "failed sender save conserves durable cash plus escrow")
		h.modes[1] = nil
		h.restart()
		h.reconcile(1)
		h.reconcile(2)
		assert(h.total() == 2000, "sender-save restart preserves value")
		assert(
			h.profiles[2].cash == (if mode == "failBefore" then 1000 else 1100),
			"only committed sender intent survives a crash"
		)
	end

	for _, mode in { "failBefore", "failAfter" } do
		local h = setup()
		h.publishMode = mode
		assert(h.send(100), "failed publishing retains transfer intent")
		assert(h.total() == 2000, "uncertain publishing conserves value")
		h.publishMode = nil
		h.restart()
		h.reconcile(1)
		h.reconcile(2)
		h.reconcile(1)
		h.reconcile(2)
		assert(h.profiles[2].cash == 1100 and h.total() == 2000, "republish after response loss credits exactly once")
	end

	for _, mode in { "failBefore", "failAfter" } do
		local h = setup()
		h.modes[2] = mode
		assert(h.send(100), "receiver save outage keeps the transfer recoverable")
		assert(next(h.inboxes[2]) ~= nil, "receiver cannot acknowledge before confirmed save")
		assert(h.total() == 2000, "receiver save failure retains durable escrow or credit")
		h.modes[2] = nil
		h.restart()
		h.reconcile(1)
		h.reconcile(2)
		h.reconcile(2)
		assert(h.profiles[2].cash == 1100 and h.total() == 2000, "receiver restart neither loses nor doubles credit")
	end

	for _, mode in { "failBefore", "failAfter" } do
		local h = setup()
		h.ackMode = mode
		assert(h.send(100), "ack failure preserves the saved receiver credit")
		h.ackMode = nil
		h.restart()
		h.reconcile(1)
		h.reconcile(2)
		h.reconcile(2)
		assert(
			h.profiles[2].cash == 1100 and h.total() == 2000,
			"lost ack and sender outbox replay never duplicate credit"
		)
	end

	local concurrent = setup()
	concurrent.saveHook = function(player: any)
		assert(player.UserId == 1 and concurrent.send(200), "new send can arrive while the first checkpoint yields")
	end
	assert(concurrent.send(100), "initial concurrent transfer accepted")
	assert(
		#concurrent.published == 1 and concurrent.published[1] == "transfer-1",
		"only the checkpoint's captured outbox is published"
	)
	assert(concurrent.profiles[2].cash == 1100, "the uncheckpointed concurrent debit is not delivered")
	assert(concurrent.profiles[1].transfers.outbox["transfer-2"] ~= nil, "concurrent intent remains pending")
	concurrent.reconcile(1)
	concurrent.reconcile(2)
	assert(
		concurrent.profiles[2].cash == 1300 and concurrent.total() == 2000,
		"later checkpoint delivers concurrent intent exactly once"
	)

	local invalid = setup()
	for _, amount in { 0, -1, 0.5, math.huge, 0 / 0, "100", {} } do
		assert(not invalid.send(amount), "invalid amounts are rejected")
	end
	assert(not invalid.send(100, 1), "self transfer is rejected")
	assert(not invalid.send(100, 99), "absent receiver is rejected")
	assert(not invalid.send(100, {}), "invalid receiver is rejected")
	assert(not invalid.service.trySend(invalid.players[1], nil, 100), "missing receiver is rejected")
	assert(not invalid.send(1001), "insufficient balance is rejected")
	invalid.players[1].ready = false
	assert(not invalid.send(100), "sender readiness is required")
	invalid.players[1].ready = true
	invalid.players[2].ready = false
	assert(not invalid.send(100), "receiver readiness is required")
	invalid.players[2].ready = true
	invalid.rateAllowed = false
	assert(not invalid.send(100), "rate-limited transfer cannot mutate balances")
	assert(invalid.profiles[1].cash == 1000 and invalid.profiles[2].cash == 1000, "rejections do not mutate cash")

	local caps = setup()
	for index = 1, ledger.MAX_PENDING do
		caps.profiles[1].transfers.outbox[`pending-{index}`] = { senderId = 1, targetId = 2, amount = 1, epoch = 0 }
	end
	local pendingOk, pendingMessage = caps.service.trySend(caps.players[1], 2, 100)
	assert(not pendingOk and caps.profiles[1].cash == 1000, "full sender outbox blocks before debit")
	assert(
		pendingMessage == "Aktarım kuyruğu dolu. Bekleyen işlemler tamamlanınca yeniden dene.",
		"a temporary queue limit explains automatic recovery"
	)
	caps.profiles[1].transfers.outbox = {}
	for index = 1, ledger.MAX_RECEIVED do
		caps.profiles[2].transfers.received[`received-{index}`] = true
	end
	local historyOk, historyMessage = caps.service.trySend(caps.players[1], 2, 100)
	assert(not historyOk and caps.profiles[1].cash == 1000, "full receiver tombstone ledger blocks before debit")
	assert(
		historyMessage
			== "Alıcı para alma sınırına ulaştı. Devam etmek için oyun geliştiricisinin desteği gerekiyor.",
		"permanent history capacity does not promise recovery by waiting"
	)
	caps.profiles[2].transfers.received = {}
	caps.profiles[2].cash = rules.CASH_CAP
	assert(not caps.send(100), "receiver cash cap blocks the request")
	local fullInbox = setup()
	fullInbox.inboxes[2] = {}
	for index = 1, ledger.MAX_INBOX do
		fullInbox.inboxes[2][`inbox-{index}`] = { senderId = 1, targetId = 2, amount = 1, epoch = 0 }
	end
	fullInbox.saveHook = function()
		fullInbox.profiles[2].cash = rules.CASH_CAP
	end
	assert(fullInbox.send(100), "an inbox capacity outage retains an accepted sender intent")
	assert(
		fullInbox.profiles[1].cash == 900 and #fullInbox.published == 0,
		"full inbox neither refunds nor publishes the new debit"
	)
	assert(fullInbox.profiles[1].transfers.outbox["transfer-1"] ~= nil, "inbox capacity retains the outbox for retry")
	-- Diğer işlemlerin tamamlanmasını simüle et; bekleyen niyet yeni checkpoint ile yayımlanır.
	fullInbox.inboxes[2] = {}
	fullInbox.profiles[2].cash = 1000
	assert(fullInbox.reconcile(1) and fullInbox.reconcile(2), "space becoming available resumes the pending intent")
	assert(fullInbox.profiles[2].cash == 1100, "resumed inbox capacity transfers credit once")

	local waiting = setup()
	assert(waiting.send(100), "initial transfer commits")
	-- Sender outbox intentionally remains on disk; recipient cap must retain a new pending credit.
	waiting.inboxes[2] = { waiting = { senderId = 1, targetId = 2, amount = 1, epoch = 0 } }
	waiting.profiles[2].cash = rules.CASH_CAP
	assert(not waiting.reconcile(2) and waiting.inboxes[2].waiting ~= nil, "cash cap retains undeliverable inbox entry")
	waiting.profiles[2].cash = 1000
	assert(waiting.reconcile(2) and waiting.profiles[2].cash == 1001, "credit resumes after receiver gains space")
	for _, id in { 1, 2 } do
		local quarantine = setup()
		quarantine.profiles[id].transfers.quarantined = true
		quarantine.inboxes[id] =
			{ pending = { senderId = if id == 1 then 2 else 1, targetId = id, amount = 100, epoch = 0 } }
		assert(not quarantine.send(100), "sender or recipient backup quarantine blocks transfers")
		assert(not quarantine.reconcile(id), "quarantined backup cannot replay uncertain financial history")
		assert(
			quarantine.profiles[id].cash == 1000 and quarantine.inboxes[id].pending ~= nil,
			"quarantine preserves cash and inbox evidence"
		)
	end
	-- PolicyService kapısı: yalnız yeni gönderim engellenir; hiçbir durum/ledger/kayıt değişmez.
	local function untouched(h: any, label: string)
		assert(h.profiles[1].cash == 1000 and h.profiles[2].cash == 1000, label .. ": balances unchanged")
		assert(next(h.profiles[1].transfers.outbox) == nil, label .. ": no outbox entry")
		assert(next(h.profiles[2].transfers.received) == nil, label .. ": no received tombstone")
		assert(
			h.saves == 0 and #h.published == 0 and next(h.inboxes) == nil,
			label .. ": no save, publish or inbox write"
		)
		assert(#h.notifications == 0, label .. ": no money notification")
		assert(h.total() == 2000, label .. ": value conserved")
	end

	local both = setup()
	assert(both.send(100) and both.profiles[2].cash == 1100, "both players allowed: the transfer is delivered")

	local senderMessages = {
		loading = "Hesap izinlerin kontrol ediliyor. Birkaç saniye sonra yeniden dene.",
		restricted = "Hesabında oyuncular arası para gönderimi kullanılamıyor.",
		unavailable = "Hesap izinleri doğrulanamadı. Biraz sonra yeniden dene.",
	}
	for status, expected in senderMessages do
		local h = setup()
		h.policy[1] = status
		local ok, message = h.service.trySend(h.players[1], 2, 100)
		assert(not ok and message == expected, "sender policy " .. status .. " rejects with its own reason")
		untouched(h, "sender " .. status)
	end
	for _, status in { "loading", "restricted", "unavailable" } do
		local h = setup()
		h.policy[2] = status
		local ok, message = h.service.trySend(h.players[1], 2, 100)
		assert(
			not ok and message == "Bu oyuncuya şu anda para gönderilemiyor.",
			"receiver policy " .. status .. " is rejected without revealing why"
		)
		untouched(h, "receiver " .. status)
	end
	local unknown = setup()
	unknown.policy[1] = "anything-unexpected"
	assert(not unknown.send(100), "an unknown policy status never counts as allowed")
	untouched(unknown, "unknown status")

	-- İstemci sahte izin gönderemez: Remote yalnız (hedef, tutar, requestId) okur, fazla argümanlar yok sayılır.
	local forged = setup()
	forged.service.init()
	forged.policy[1] = "restricted"
	forged.remotes.RequestSendMoney.OnServerEvent.fire(
		forged.players[1],
		2,
		100,
		1,
		true,
		"allowed",
		{ IsPaidItemTradingAllowed = true }
	)
	assert(forged.replies[1] and forged.replies[1].ok == false, "forged permission arguments cannot enable a transfer")
	untouched(forged, "forged client permission")
	forged.policy[1] = nil
	forged.policy[2] = "restricted"
	forged.remotes.RequestSendMoney.OnServerEvent.fire(forged.players[1], 2, 100, 2, true)
	assert(forged.replies[2] and forged.replies[2].ok == false, "forged flags cannot bypass the receiver check")
	untouched(forged, "forged receiver permission")

	-- Önceden kabul edilmiş bekleyen aktarım, politika sonradan kısıtlansa da güvenle tamamlanır (yeni gönderim değildir).
	for _, mode in { "failBefore", "failAfter" } do
		local h = setup()
		h.publishMode = mode
		assert(h.send(100), "transfer accepted while both players were allowed")
		assert(h.profiles[1].cash == 900 and h.total() == 2000, "accepted intent is durable escrow")
		h.policy[1] = "restricted"
		h.policy[2] = "unavailable"
		assert(not h.send(50), "new sends are blocked once the policy changes")
		h.publishMode = nil
		h.restart()
		h.reconcile(1)
		h.reconcile(2)
		h.reconcile(2)
		assert(
			h.profiles[2].cash == 1100 and h.profiles[1].cash == 900,
			"pending accepted transfer completes exactly once"
		)
		assert(h.total() == 2000, "completed pending transfer conserves value")
	end

	print(
		"PASS transfer service: durable cash/escrow, failure before/after writes, restart/replay, concurrent checkpoints, caps and PolicyService gate"
	)
end
