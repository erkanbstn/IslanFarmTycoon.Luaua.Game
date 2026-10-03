--!strict
-- Borç+outbox önce kaydedilir; kalıcı alıcı kuyruğu ve received kimliği tekrar/çökmeyi uzlaştırır.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local SaveStore = require(script.Parent:WaitForChild("SaveStore"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local RequestGuard = require(script.Parent:WaitForChild("RequestGuard"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))
local TransferRules = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("TransferRules"))
local TransferLedger = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("TransferLedger"))

local TransferService = {}
local initialized = false
local processing: { [Player]: boolean } = {}
local lastInboxAt: { [Player]: number } = {}
local RETRY_SECONDS = 10
local MAX_BATCH = 64

local function ledgerOf(data: any): TransferLedger.Ledger
	if not data.transfers then
		data.transfers = { outbox = {}, received = {} }
	end
	return data.transfers
end

local function notify(player: Player, text: string, kind: string)
	if player.Parent then
		pcall(function()
			Remotes.get("Notify"):FireClient(player, text, kind)
		end)
	end
end

local function refresh(player: Player)
	pcall(PlayerDataService.pushState, player)
	PlayerDataService.requestSave(player)
end

local function publishOutbox(player: Player, data: any): boolean
	local ledger = ledgerOf(data)
	if next(ledger.outbox) == nil then
		return true
	end
	-- Kayıt yield ederken eklenen yeni borç, bu checkpoint'te bulunmayabilir.
	local pending = table.clone(ledger.outbox)
	if not PlayerDataService.save(player) then
		return false
	end
	local published: { string } = {}
	for id, entry in pending do
		if entry.senderId ~= player.UserId or entry.epoch ~= (data.epoch or 0) then
			warn(`[Transfer] Gönderim sahibi/çağı geçersiz user={player.UserId}; kayıt korunuyor`)
			return false
		end
		if SaveStore.publishTransfer(id, entry) then
			table.insert(published, id)
		end
	end
	if PlayerDataService.tryGet(player) ~= data then
		return #published > 0
	end
	for _, id in published do
		ledger.outbox[id] = nil
	end
	if #published > 0 then
		PlayerDataService.markDirty(player)
		PlayerDataService.requestSave(player)
	end
	return next(ledger.outbox) == nil
end

local function receiveInbox(player: Player, data: any): boolean
	local inbox = SaveStore.readTransferInbox(player.UserId)
	if not inbox or PlayerDataService.tryGet(player) ~= data then
		return false
	end
	local ledger = ledgerOf(data)
	local count = TransferLedger.count(ledger.received)
	local acknowledged: { string } = {}
	local changed = false
	for id, entry in inbox do
		if #acknowledged >= MAX_BATCH then
			break
		end
		if entry.targetId ~= player.UserId then
			warn(`[Transfer] Alıcı kuyruğu sahibi geçersiz user={player.UserId}; kayıt korunuyor`)
			return false
		end
		if ledger.received[id] or entry.epoch ~= (data.epoch or 0) then
			table.insert(acknowledged, id)
		elseif count < TransferLedger.MAX_RECEIVED and data.cash + entry.amount <= TransferRules.CASH_CAP then
			-- Nakit ve tekrar işareti aynı yield etmeyen blokta; iade başarımları artırmaz.
			data.cash += entry.amount
			ledger.received[id] = true
			count += 1
			changed = true
			table.insert(acknowledged, id)
		end
	end
	if #acknowledged == 0 then
		return next(inbox) == nil
	end
	if changed then
		PlayerDataService.markDirty(player)
		refresh(player)
	end
	-- Bellekteki received, önceki başarısız yazımdan kalmış olabilir: duplicate'da da kaydı doğrula.
	if not PlayerDataService.save(player) then
		return false
	end
	return SaveStore.ackTransfers(player.UserId, acknowledged)
end

function TransferService.reconcile(player: Player, forceInbox: boolean?): boolean
	if processing[player] then
		return false
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true then
		return false
	end
	if ledgerOf(data).quarantined then
		return false
	end
	processing[player] = true
	local ok, result = pcall(function(): boolean
		local outgoing = publishOutbox(player, data)
		if PlayerDataService.tryGet(player) ~= data then
			return outgoing
		end
		local now = os.clock()
		if
			forceInbox ~= false and (forceInbox == true or now - (lastInboxAt[player] or -math.huge) >= RETRY_SECONDS)
		then
			lastInboxAt[player] = now
			return receiveInbox(player, data) and outgoing
		end
		return outgoing
	end)
	processing[player] = nil
	if not ok then
		warn(`[Transfer] Aktarım yeniden denenecek user={player.UserId}: {result}`)
		return false
	end
	return result == true
end

local function ready(player: Player): boolean
	return PlayerDataService.tryGet(player) ~= nil and player:GetAttribute("WorldReady") == true
end

function TransferService.trySend(player: Player, targetUserId: unknown, amount: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "sendMoney", TransferRules.COOLDOWN) then
		return false, nil
	end
	if not TransferRules.validUserId(targetUserId) or not TransferRules.validAmount(amount) then
		return false, "Geçersiz tutar ya da oyuncu"
	end
	if targetUserId == player.UserId then
		return false, "Kendine para gönderemezsin"
	end
	local target = Players:GetPlayerByUserId(targetUserId :: number)
	if not target then
		return false, "Oyuncu bu sunucuda değil"
	end
	if not ready(player) then
		return false, "Çiftliğin henüz hazır değil"
	end
	if not ready(target) then
		return false, "Alıcının çiftliği henüz hazır değil"
	end
	EconomyService.settlePlayer(player)
	EconomyService.settlePlayer(target)
	local data = PlayerDataService.tryGet(player)
	local targetData = PlayerDataService.tryGet(target)
	if not data or not targetData then
		return false, "Kayıt oturumu artık etkin değil"
	end
	local value = amount :: number
	local allowed, problem = TransferRules.check(data.cash, targetData.cash, value)
	if not allowed then
		return false, problem
	end
	local ledger = ledgerOf(data)
	if ledger.quarantined or ledgerOf(targetData).quarantined then
		return false, "Kurtarılan kaydın aktarım geçmişi inceleme bekliyor."
	end
	if TransferLedger.count(ledger.outbox) >= TransferLedger.MAX_PENDING then
		return false, "Aktarım kuyruğu dolu. Bekleyen işlemler tamamlanınca yeniden dene."
	end
	if TransferLedger.count(ledgerOf(targetData).received) >= TransferLedger.MAX_RECEIVED then
		return false,
			"Alıcı para alma sınırına ulaştı. Devam etmek için oyun geliştiricisinin desteği gerekiyor."
	end
	local id = HttpService:GenerateGUID(false)
	-- Borç ve dayanıklı gönderim niyeti birlikte yazılır; belirsiz yazımda para geri eklenmez.
	data.cash -= value
	ledger.outbox[id] = { senderId = player.UserId, targetId = target.UserId, amount = value, epoch = data.epoch or 0 }
	PlayerDataService.markDirty(player)
	refresh(player)
	TransferService.reconcile(player, false)
	TransferService.reconcile(target, true)
	local delivered = ledgerOf(targetData).received[id] == true and target:GetAttribute("DataDirty") == false
	if delivered then
		notify(target, `{player.DisplayName} sana {FarmMath.formatMoney(value)} gönderdi`, "money")
		local sentText = `{target.DisplayName} oyuncusuna {FarmMath.formatMoney(value)} gönderildi`
		notify(player, sentText, "money")
		return true, sentText
	end
	return true, "Aktarım kuyruğa alındı. Kayıt hizmeti hazır olunca otomatik tamamlanacak."
end

function TransferService.init()
	if initialized then
		return
	end
	initialized = true
	Players.PlayerRemoving:Connect(function(player: Player)
		lastInboxAt[player] = nil
	end)
	Remotes.get("RequestSendMoney").OnServerEvent
		:Connect(function(player: Player, targetUserId: unknown, amount: unknown, requestId: unknown)
			if not RateLimiter.acceptRequest(player, requestId) then
				return
			end
			local ok, message = TransferService.trySend(player, targetUserId, amount)
			RequestGuard.reply(player, requestId, ok, message)
		end)
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				task.spawn(TransferService.reconcile, player)
			end
			task.wait(RETRY_SECONDS)
		end
	end)
end

return TransferService
