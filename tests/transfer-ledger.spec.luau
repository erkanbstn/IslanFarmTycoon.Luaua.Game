--!strict
-- Kalıcı aktarım kimlikleri hiçbir yükleme veya tekrar denemesinde sessizce kaybolmamalı.
return function(ledger: any, codec: any, config: any, farmMath: any, lock: any)
	local entry = { senderId = 101, targetId = 202, amount = 75, epoch = 3 }
	local function sameEntry(actual: any, expected: any)
		assert(
			actual.senderId == expected.senderId and actual.targetId == expected.targetId,
			"transfer parties must match"
		)
		assert(
			actual.amount == expected.amount and actual.epoch == expected.epoch,
			"transfer amount and epoch must match"
		)
	end
	local empty = assert(ledger.decode(nil))
	assert(next(empty.outbox) == nil and next(empty.received) == nil, "old saves start with empty transfer history")
	assert(next(assert(ledger.parseInbox(nil))) == nil, "missing mailbox has no pending transfers")
	for _, id in { "", "bad id", "bad/id", string.rep("x", 41), 123, false } do
		assert(not ledger.validId(id), "malformed operation IDs must be rejected")
	end
	assert(ledger.validId("GUID-123-a") and ledger.validId(string.rep("x", 40)), "valid IDs must be accepted")
	local parsed = assert(ledger.parseInbox({ ["transfer-1"] = entry }))
	sameEntry(parsed["transfer-1"], entry)
	assert(parsed["transfer-1"] ~= entry, "mailbox parse must detach entries from original stored data")
	parsed["transfer-1"].amount = 999
	assert(entry.amount == 75, "decoded edits must not mutate original stored transfer")

	for _, field in { "senderId", "targetId", "amount", "epoch" } do
		for _, value in { "bad", false, 0 / 0, math.huge, -1, 1.5 } do
			local bad: any = table.clone(entry)
			bad[field] = value
			assert(ledger.parseInbox({ corrupt = bad }) == nil, `invalid {field} must abort mailbox parsing`)
		end
		local missing: any = table.clone(entry)
		missing[field] = nil
		assert(ledger.parseInbox({ corrupt = missing }) == nil, `missing {field} must abort mailbox parsing`)
	end
	assert(
		ledger.parseInbox({ self = { senderId = 101, targetId = 101, amount = 75, epoch = 3 } }) == nil,
		"self transfer invalid"
	)
	assert(ledger.parseInbox({ ["bad id"] = entry }) == nil, "invalid mailbox ID rejected")
	assert(ledger.parseInbox({ corrupt = false }) == nil, "invalid mailbox entry rejected")
	assert(ledger.parseInbox("bad") == nil, "invalid mailbox shape rejected")
	assert(
		ledger.parseInbox({ overflow = { senderId = 101, targetId = 202, amount = 1e12 + 1, epoch = 3 } }) == nil,
		"amount ceiling enforced"
	)
	assert(
		ledger.parseInbox({ overflow = { senderId = 101, targetId = 202, amount = 75, epoch = 1e9 + 1 } }) == nil,
		"epoch ceiling enforced"
	)
	assert(
		ledger.parseInbox({ zero = { senderId = 101, targetId = 202, amount = 75, epoch = 0 } }),
		"legacy epoch zero valid"
	)

	local first = assert(ledger.publish(nil, "transfer-1", entry))
	local retry = assert(ledger.publish(first, "transfer-1", table.clone(entry)))
	assert(ledger.count(retry) == 1, "identical retry must not create a second payment")
	sameEntry(retry["transfer-1"], entry)
	assert(first ~= retry and first["transfer-1"] ~= retry["transfer-1"], "publish must not mutate UpdateAsync input")
	for _, field in { "senderId", "targetId", "amount", "epoch" } do
		local collision: any = table.clone(entry)
		collision[field] += 1
		assert(ledger.publish(first, "transfer-1", collision) == nil, `ID collision must reject changed {field}`)
		sameEntry(first["transfer-1"], entry)
	end
	local corruptInbox = { good = entry, corrupt = "bad" }
	assert(ledger.publish(corruptInbox, "new-transfer", entry) == nil, "publishing cannot erase corrupt stored entries")
	assert(corruptInbox.corrupt == "bad" and corruptInbox.good == entry, "rejected publish preserves original data")

	local full: any = {}
	for i = 1, ledger.MAX_INBOX do
		full[`transfer-{i}`] = table.clone(entry)
	end
	assert(ledger.publish(full, "new-transfer", entry) == nil, "full mailbox must refuse new IDs without eviction")
	assert(
		ledger.count(full) == ledger.MAX_INBOX and full["transfer-1"].amount == 75,
		"capacity rejection cannot evict stored transfers"
	)
	local fullRetry = assert(ledger.publish(full, "transfer-1", entry))
	assert(ledger.count(fullRetry) == ledger.MAX_INBOX, "retry must remain valid at mailbox capacity")
	local history: any = {}
	for i = 1, ledger.MAX_RECEIVED + 1 do
		history[`received-{i}`] = true
	end
	local recovered = assert(ledger.decode({ outbox = {}, received = history }))
	assert(
		ledger.count(recovered.received) == ledger.MAX_RECEIVED + 1,
		"decode must preserve all existing deduplication IDs"
	)
	assert(recovered.received ~= history, "decode must detach completed transfer IDs")

	for _, raw in
		{
			"bad",
			{},
			{ received = {} },
			{ outbox = {} },
			{ outbox = {}, received = "bad" },
			{ outbox = "bad", received = {} },
			{ outbox = {}, received = { ["bad id"] = true } },
			{ outbox = {}, received = { done = false } },
			{ outbox = {}, received = { done = 1 } },
			{ outbox = { corrupt = "bad" }, received = { done = true } },
		}
	do
		assert(ledger.decode(raw) == nil, "invalid ledger must abort instead of clearing payment history")
	end

	local now = 2000000000
	local counter = 0
	local function uid(): string
		counter += 1
		return `ledger-test-{counter}`
	end
	local function rawSave(transfers: any?): any
		return {
			version = lock.VERSION,
			epoch = 3,
			cash = 125,
			activeMainFarmId = "1",
			mainFarms = { ["1"] = codec.newFarm(config, farmMath, now, uid, "1") },
			transfers = transfers,
		}
	end
	local old = assert(codec.decode(rawSave(nil), config, farmMath, now, uid, 3))
	assert(next(old.transfers.outbox) == nil and next(old.transfers.received) == nil, "absent old ledger decodes empty")
	local oldEncoded = codec.encode(old, now)
	assert(
		next(oldEncoded.transfers.outbox) == nil and next(oldEncoded.transfers.received) == nil,
		"old ledger encodes empty"
	)
	local raw = rawSave({ outbox = { pending = entry }, received = { completed = true } })
	local decoded = assert(codec.decode(raw, config, farmMath, now, uid, 3))
	local encoded = codec.encode(decoded, now)
	sameEntry(encoded.transfers.outbox.pending, entry)
	assert(
		encoded.transfers.received.completed and encoded.epoch == 3 and encoded.cash == 125,
		"encode preserves history, epoch and wallet"
	)
	encoded.transfers.outbox.pending.amount = 90
	assert(
		raw.transfers.outbox.pending.amount == 75 and decoded.transfers.outbox.pending.amount == 75,
		"encoded transfer snapshot must be detached"
	)
	local roundtrip = assert(codec.decode(codec.encode(decoded, now), config, farmMath, now, uid, 3))
	sameEntry(roundtrip.transfers.outbox.pending, entry)
	assert(
		roundtrip.transfers.received.completed and roundtrip.epoch == 3,
		"roundtrip preserves completed IDs and epoch"
	)
	local invalid = rawSave({ outbox = { pending = entry }, received = { completed = false } })
	local rejected, earned, problem = codec.decode(invalid, config, farmMath, now, uid, 3)
	assert(rejected == nil and earned == 0 and problem, "corrupt payment history must abort full save loading")
	assert(
		invalid.cash == 125 and invalid.transfers.received.completed == false,
		"decode rejection preserves original save"
	)
	sameEntry(invalid.transfers.outbox.pending, entry)
	decoded.transfers = invalid.transfers
	assert(not pcall(codec.encode, decoded, now), "encoding cannot write a corrupt ledger as empty data")
	assert(
		decoded.cash == 125 and decoded.transfers == invalid.transfers,
		"encode rejection cannot replace corrupt history"
	)
end
