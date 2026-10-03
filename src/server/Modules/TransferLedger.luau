--!strict
-- Borç, gönderim kuyruğu ve alıcıdaki tekrar koruması birlikte kaydedilir; eski kimlikler silinmez.
local TransferRules = require(script.Parent:WaitForChild("TransferRules"))

local TransferLedger = {}
TransferLedger.MAX_RECEIVED = 20000
TransferLedger.MAX_PENDING = 64
TransferLedger.MAX_INBOX = 128
export type Entry = { senderId: number, targetId: number, amount: number, epoch: number }
export type Ledger = { outbox: { [string]: Entry }, received: { [string]: boolean }, quarantined: boolean? }

function TransferLedger.validId(id: unknown): boolean
	return typeof(id) == "string" and #id > 0 and #id <= 40 and string.match(id, "^[%w%-]+$") ~= nil
end

local function validEntry(value: any): boolean
	return typeof(value) == "table"
		and TransferRules.validUserId(value.senderId)
		and TransferRules.validUserId(value.targetId)
		and value.senderId ~= value.targetId
		and TransferRules.validAmount(value.amount)
		and typeof(value.epoch) == "number"
		and value.epoch == value.epoch
		and value.epoch >= 0
		and value.epoch <= 1e9
		and value.epoch % 1 == 0
end

function TransferLedger.count(values: { [string]: any }): number
	local count = 0
	for _ in values do
		count += 1
	end
	return count
end

function TransferLedger.parseInbox(raw: unknown): { [string]: Entry }?
	if raw == nil then
		return {}
	end
	if typeof(raw) ~= "table" then
		return nil
	end
	local result: { [string]: Entry } = {}
	for id, entry in raw :: any do
		if not TransferLedger.validId(id) or not validEntry(entry) then
			return nil
		end
		result[id] =
			{ senderId = entry.senderId, targetId = entry.targetId, amount = entry.amount, epoch = entry.epoch }
	end
	return result
end

function TransferLedger.decode(raw: unknown): Ledger?
	if raw == nil then
		return { outbox = {}, received = {} }
	end
	if typeof(raw) ~= "table" then
		return nil
	end
	local value = raw :: any
	if value.quarantined ~= nil and typeof(value.quarantined) ~= "boolean" then
		return nil
	end
	if typeof(value.outbox) ~= "table" then
		return nil
	end
	local outbox = TransferLedger.parseInbox(value.outbox)
	if not outbox or typeof(value.received) ~= "table" then
		return nil
	end
	local received: { [string]: boolean } = {}
	for id, done in value.received do
		if not TransferLedger.validId(id) or done ~= true then
			return nil
		end
		received[id] = true
	end
	return { outbox = outbox, received = received, quarantined = value.quarantined }
end

function TransferLedger.publish(raw: unknown, id: string, entry: Entry): { [string]: Entry }?
	local inbox = TransferLedger.parseInbox(raw)
	if not inbox or not TransferLedger.validId(id) or not validEntry(entry) then
		return nil
	end
	local previous = inbox[id]
	if previous then
		if
			previous.senderId ~= entry.senderId
			or previous.targetId ~= entry.targetId
			or previous.amount ~= entry.amount
			or previous.epoch ~= entry.epoch
		then
			return nil
		end
	elseif TransferLedger.count(inbox) >= TransferLedger.MAX_INBOX then
		return nil
	end
	inbox[id] = table.clone(entry)
	return inbox
end

return TransferLedger
