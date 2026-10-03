--!strict
-- Gerçek DataStore cephesi kayıp yanıtı, callback tekrarını ve eşzamanlı posta gelişini korur.
return function(factory: any)
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
	local function fixture(nonpersistent: boolean): (any, any)
		local state: any = { values = {}, replay = false, loseResponse = false, failRead = false, calls = 0 }
		local datastore = {}
		function datastore:GetAsync(key: string): any
			state.calls += 1
			if state.failRead then
				error("read unavailable")
			end
			return copy(state.values[key])
		end
		function datastore:UpdateAsync(key: string, transform: any): any
			state.calls += 1
			if state.replay then
				transform(copy(state.values[key]))
				if state.beforeReplay then
					state.beforeReplay(key)
				end
			end
			local result = transform(copy(state.values[key]))
			if result ~= nil then
				state.values[key] = copy(result)
			end
			if state.loseResponse then
				state.loseResponse = false
				error("response lost after commit")
			end
			return copy(result)
		end
		local replicated = {}
		function replicated:WaitForChild(_name: string): any
			return self
		end
		local services: any = {
			DataStoreService = {
				GetDataStore = function(): any
					return datastore
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
		local taskFake = { wait = noOp }
		local osFake = {
			clock = function(): number
				return 1
			end,
			time = function(): number
				return 2000000000
			end,
		}
		local metrics = { increment = noOp }
		return factory(gameFake, taskFake, osFake, metrics, noOp), state
	end
	local entry = { senderId = 101, targetId = 202, amount = 75, epoch = 3 }
	local key = "__transfer_inbox_202"
	for _, nonpersistent in { false, true } do
		local store, state = fixture(nonpersistent)
		assert(store.persistent == not nonpersistent, "explicit Studio mode selects memory storage")
		state.replay = true
		assert(store.publishTransfer("first", entry), "callback replay must publish exactly one inbox entry")
		assert(store.publishTransfer("first", copy(entry)), "identical publish retry must succeed")
		local inbox = assert(store.readTransferInbox(202))
		local inboxCount = 0
		for _ in inbox do
			inboxCount += 1
		end
		assert(inbox.first.amount == 75 and inboxCount == 1, "replay cannot duplicate or change amount")
		inbox.first.amount = 999
		assert(store.readTransferInbox(202).first.amount == 75, "read results cannot mutate stored inbox")
		local conflict = copy(entry)
		conflict.amount = 90
		assert(not store.publishTransfer("first", conflict), "ID collision must preserve original payment")
		assert(store.readTransferInbox(202).first.amount == 75, "collision must not overwrite stored amount")
		assert(store.publishTransfer("second", entry), "independent transfer ID accepted")
		assert(store.ackTransfers(202, { "first", "unknown" }), "ack removes requested IDs idempotently")
		local remaining = assert(store.readTransferInbox(202))
		assert(remaining.first == nil and remaining.second.amount == 75, "ack preserves unrelated pending transfers")
		assert(store.ackTransfers(202, { "first" }), "repeated ack must succeed")
		assert(next(assert(store.readTransferInbox(999))) == nil, "missing mailbox reads empty")
		if nonpersistent then
			assert(state.calls == 0, "Studio nonpersistent transfers never touch DataStore")
		end
	end

	local store, state = fixture(false)
	state.loseResponse = true
	assert(not store.publishTransfer("lost-response", entry), "lost response must report uncertainty")
	assert(state.values[key]["lost-response"].amount == 75, "commit can persist even when response is lost")
	assert(store.publishTransfer("lost-response", entry), "lost publish response must safely retry same ID")
	assert(state.values[key]["lost-response"].amount == 75, "retry cannot duplicate or alter amount")
	state.replay = true
	state.beforeReplay = function(replayedKey: string)
		state.values[replayedKey].concurrent = copy(entry)
	end
	assert(store.ackTransfers(202, { "lost-response" }), "ack must replay against latest inbox")
	assert(
		state.values[key]["lost-response"] == nil and state.values[key].concurrent.amount == 75,
		"ack replay preserves concurrently published ID"
	)
	state.beforeReplay = nil
	state.values[key] = { good = copy(entry), corrupt = "invalid" }
	assert(not store.publishTransfer("new", entry), "corrupt inbox cannot be overwritten by publish")
	assert(not store.ackTransfers(202, { "good" }), "corrupt inbox cannot be partially erased by ack")
	assert(
		state.values[key].good.amount == 75 and state.values[key].corrupt == "invalid",
		"rejected updates preserve original corrupt data"
	)
	assert(store.readTransferInbox(202) == nil, "corrupt inbox read must not appear empty")
	state.values[key] = { good = copy(entry) }
	state.failRead = true
	assert(store.readTransferInbox(202) == nil, "failed DataStore read must not appear as empty success")

	state.failRead = false
	state.beforeReplay = function(replayedKey: string)
		state.values[replayedKey].corrupt = "arrived between callbacks"
	end
	assert(not store.publishTransfer("new", entry), "last rejected callback must override prior accepted callback")
	assert(
		state.values[key].new == nil and state.values[key].corrupt == "arrived between callbacks",
		"rejected replay cannot replace latest corrupt inbox"
	)
end
