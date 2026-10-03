--!strict
-- DataStore kalıcılığı: anahtar kilidi, oturum kilidini alma, sıralı yazma (UpdateAsync + yeniden deneme), yedek ve
-- bozuk kayıttan kurtarma. Oyuncu oturumu/durumu bilmez; çağıran (PlayerDataService) sonucu işler.
-- Projedeki tüm DataStore çağrıları yalnızca bu dosyada yapılır.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local SessionLock = require(script.Parent.Parent.Modules.SessionLock)
local Metrics = require(script.Parent.Parent.Modules.Metrics)
local SaveBackup = require(script.Parent.Parent.Modules.SaveBackup)
local TransferLedger = require(script.Parent.Parent.Modules.TransferLedger)

export type Operation = {
	payload: { [string]: any },
	token: string,
	revision: number,
	release: boolean,
}

export type CommitResult = {
	ok: boolean,
	revision: number, -- başarıda yeni kayıt revizyonu
	expiresAt: number, -- başarıda kilit kirası bitişi
	ownershipLost: boolean, -- sahiplik gerçekten kaybedildi (yazım yeniden denenmez, oturum düşer)
	lastError: string,
}

local SaveStore = {}
SaveStore.LEASE_SECONDS = 180
SaveStore.SAVE_BUDGET = 15
local SAVE_RETRIES = 3
local LOCK_WAIT_SECONDS = 60 -- kilit başka sunucudayken girişte en çok bu kadar beklenir
local BUDGET_EXHAUSTED = "Kayıt zaman bütçesi doldu"

local busyKeys: { [string]: boolean } = {}
local shutdownDeadline: number? = nil
local studio = RunService:IsStudio()
-- API hatası kayıtsız oyuna geçirmez. Bu seçenek yalnızca açıkça seçilmiş Studio testidir.
local nonpersistent = studio and Workspace:GetAttribute("StudioNonPersistentData") == true
local store: DataStore? = nil
if not nonpersistent then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME .. (if studio then "_Studio" else ""))
	end)
	if ok then
		store = result
	else
		warn(`[Data] StoreInitFailed: {result}`)
	end
end

-- Kalıcı kayıt kullanılıyor mu (Studio'da açıkça seçilen kayıtsız test hariç).
SaveStore.persistent = not nonpersistent

function SaveStore.available(): boolean
	return store ~= nil
end

function SaveStore.keyFor(userId: number): string
	return `player_{userId}`
end

-- Veri çağı: yönetici "herkesi sıfırla" bu sayıyı artırır; kaydındaki sayı farklı olan oyuncu girişte temiz yeni oyunla başlar
-- (SaveCodec.decode). Tek anahtarda tutulur; DataStore yoksa/okunamazsa son bilinen değer kullanılır (hiç yoksa nil: denetim yapılmaz).
local EPOCH_KEY = "__meta_epoch"
local knownEpoch: number? = if store == nil then 0 else nil

function SaveStore.getEpoch(): number?
	local activeStore = store
	if not activeStore then
		return knownEpoch
	end
	for attempt = 1, 3 do
		local ok, value = pcall(function()
			return (activeStore :: DataStore):GetAsync(EPOCH_KEY)
		end)
		if ok then
			knownEpoch = if typeof(value) == "number" and value == value and value >= 0 then value else 0
			return knownEpoch
		end
		if attempt < 3 then
			task.wait(0.5 * attempt)
		end
	end
	warn("[Data] EpochReadFailed: son bilinen değer kullanılıyor")
	return knownEpoch
end

-- Genel çağı bir artırır (yönetici sıfırlaması). Dönüş: yeni çağ; yazılamazsa nil (hiçbir şey değişmez).
function SaveStore.bumpEpoch(): number?
	local activeStore = store
	if not activeStore then
		knownEpoch = (knownEpoch or 0) + 1
		return knownEpoch
	end
	local result: number? = nil
	local ok, err = pcall(function()
		(activeStore :: DataStore):UpdateAsync(EPOCH_KEY, function(current: any)
			local base = if typeof(current) == "number" and current == current and current >= 0 then current else 0
			result = base + 1
			return result
		end)
	end)
	if not ok or result == nil then
		warn(`[Data] EpochBumpFailed: {err}`)
		return nil
	end
	knownEpoch = result
	return result
end

-- Sıfırlanan çağın eski kaydını geri alınabilir tutar: `<anahtar>_archive_<eskiÇağ>` anahtarına kopyalar (oturum kilidi çıkarılır).
-- Yazılamazsa false döner; çağıran yine de devam eder ama uyarır (asıl kayıt zaten ancak ilk kayıtta ezilir).
function SaveStore.archive(key: string, userId: number, raw: unknown, oldEpoch: number): boolean
	local activeStore = store
	if not activeStore or typeof(raw) ~= "table" then
		return false
	end
	local copy = table.clone(raw :: any)
	copy._session = nil
	local ok, err = pcall(function()
		(activeStore :: DataStore):SetAsync(`{key}_archive_{oldEpoch}`, copy)
	end)
	if not ok then
		warn(`[Data] ArchiveFailed user={userId}: {err}`)
	end
	return ok
end

function SaveStore.beginShutdown(seconds: number)
	shutdownDeadline = os.clock() + seconds
end

-- Kapanış başladıysa kapanış bütçesinin bitiş zamanı; yoksa nil.
function SaveStore.shutdownDeadline(): number?
	return shutdownDeadline
end

function SaveStore.deadlineAfter(seconds: number): number
	return math.min(os.clock() + seconds, shutdownDeadline or math.huge)
end

function SaveStore.withinDeadline(deadline: number): boolean
	return os.clock() < math.min(deadline, shutdownDeadline or math.huge)
end

local function retryWait(deadline: number, seconds: number)
	local remaining = math.min(deadline, shutdownDeadline or math.huge) - os.clock()
	if remaining > 0 then
		task.wait(math.min(seconds, remaining))
	end
end

-- Anahtar başına sıralı yazım: kilit alınırsa true (çağıran unlockKey ile bırakır).
function SaveStore.lockKey(key: string, deadline: number): boolean
	while busyKeys[key] do
		if not SaveStore.withinDeadline(deadline) then
			return false
		end
		task.wait(0.05)
	end
	if not SaveStore.withinDeadline(deadline) then
		return false
	end
	busyKeys[key] = true
	return true
end

function SaveStore.unlockKey(key: string)
	busyKeys[key] = nil
end

-- Oturum kilidini alır ve kaydı okur (UpdateAsync). Kilit başka sunucudayken hemen vazgeçmez: hızlı sunucu değiştiren
-- oyuncunun eski kilidi birkaç saniye içinde bırakılır; artan beklemeyle LOCK_WAIT_SECONDS boyunca tekrar dener.
-- Dönüş: (kayıt ya da nil, sorun mesajı). `isPresent` oyuncu hâlâ oyundaysa true; `onLockWait` her bekleme turunda çağrılır.
function SaveStore.acquire(key: string, owner: string, isPresent: () -> boolean, onLockWait: () -> ()): (any?, string?)
	if not store then
		return nil, "Kayıt hizmetine bağlanılamadı. Lütfen yeniden bağlan."
	end
	local activeStore: DataStore = store
	local problem: string? = nil
	local lockWaitUntil = SaveStore.deadlineAfter(LOCK_WAIT_SECONDS)
	local pause = 2
	while true do
		local deadline = SaveStore.deadlineAfter(SaveStore.SAVE_BUDGET)
		local heldElsewhere = false
		local acquired: any = nil
		if SaveStore.lockKey(key, deadline) then
			for attempt = 1, SAVE_RETRIES do
				if not SaveStore.withinDeadline(deadline) then
					break
				end
				local rejection: string? = nil
				local ok, result = pcall(function()
					return activeStore:UpdateAsync(key, function(current)
						if not SaveStore.withinDeadline(deadline) then
							rejection = "Yükleme zaman bütçesi doldu"
							return nil
						end
						local nextValue, reason =
							SessionLock.acquire(current, owner, os.time(), SaveStore.LEASE_SECONDS)
						rejection = reason
						return nextValue
					end)
				end)
				if ok and SessionLock.owns(result, owner, os.time()) then
					acquired = result
					break
				end
				problem = rejection or tostring(result)
				if rejection then
					heldElsewhere = rejection == SessionLock.HELD
					break
				end
				if attempt < SAVE_RETRIES and SaveStore.withinDeadline(deadline) then
					retryWait(deadline, attempt)
				end
			end
			SaveStore.unlockKey(key)
		end
		if acquired then
			return acquired, nil
		end
		if not heldElsewhere or not isPresent() or not SaveStore.withinDeadline(lockWaitUntil) then
			break
		end
		onLockWait()
		retryWait(lockWaitUntil, pause)
		pause = math.min(pause * 2, 15)
	end
	return nil, problem
end

-- Çağıran anahtar kilidini (lockKey) tutarken tek bir yazımı en çok SAVE_RETRIES kez dener. Aynı payload/token ile yeniden
-- denemek güvenlidir (SessionLock.commit `_lastWrite` ile aynı yazımı tanır). `userId` yalnızca günlük içindir.
function SaveStore.commit(
	key: string,
	userId: number,
	owner: string,
	operation: Operation,
	deadline: number
): CommitResult
	local activeStore = store :: DataStore
	local token = operation.token
	local outcome: CommitResult =
		{ ok = false, revision = 0, expiresAt = 0, ownershipLost = false, lastError = BUDGET_EXHAUSTED }
	for attempt = 1, SAVE_RETRIES do
		if not SaveStore.withinDeadline(deadline) then
			break
		end
		local rejection: string? = nil
		local ok, result = pcall(function()
			return activeStore:UpdateAsync(key, function(current)
				if not SaveStore.withinDeadline(deadline) then
					rejection = BUDGET_EXHAUSTED
					return nil
				end
				local nextValue, problem = SessionLock.commit(
					current,
					owner,
					operation.revision,
					token,
					operation.payload,
					os.time(),
					SaveStore.LEASE_SECONDS,
					operation.release
				)
				rejection = problem
				return nextValue
			end)
		end)
		if ok and typeof(result) == "table" and result._lastWrite == token then
			if not operation.release and not SessionLock.owns(result, owner, os.time()) then
				outcome.ownershipLost = true
				outcome.lastError = "Kayıt oturumunun sahipliği kaybedildi"
				break
			end
			outcome.ok = true
			outcome.revision = result._revision
			outcome.expiresAt = if operation.release then 0 else result._session.expiresAt
			break
		end
		outcome.lastError = rejection or tostring(result)
		if rejection and rejection ~= BUDGET_EXHAUSTED then
			outcome.ownershipLost = true
			break
		end
		warn(`[Data] SaveRetry user={userId} attempt={attempt}: {outcome.lastError}`)
		Metrics.increment("SaveRetry")
		if attempt < SAVE_RETRIES and SaveStore.withinDeadline(deadline) then
			retryWait(deadline, attempt)
		end
	end
	return outcome
end

-- Dönüşümlü yedek yuvasına yazar (bloklar; çağıran task.spawn ile çağırır). Dönüş: (başarılı mı, yedek damgası).
function SaveStore.writeBackup(key: string, userId: number, slot: number, payload: { [string]: any }): (boolean, any)
	local stamped = SaveBackup.stamp(payload, os.time())
	local written, backupError = pcall(function()
		(store :: DataStore):SetAsync(SaveBackup.slotKey(key, slot), stamped)
	end)
	if written then
		Metrics.increment("BackupWritten")
	else
		Metrics.increment("BackupFailed")
		warn(`[Data] BackupFailed user={userId}: {backupError}`)
	end
	return written, stamped._backupAt
end

-- Asıl kayıt çözülemiyorsa (bozuk): önce olduğu gibi karantina anahtarına kopyalanır, sonra en yeni çözülebilir yedek döner.
-- Karantina yazılamazsa kurtarma yapılmaz (asıl kayıt ezilmez). `canDecode` bir adayın çözülüp çözülemediğini söyler.
function SaveStore.recoverFromBackup(
	key: string,
	userId: number,
	corrupt: unknown,
	canDecode: (unknown) -> boolean
): unknown?
	local activeStore = store
	if not activeStore then
		return nil
	end
	local candidates: { unknown } = {}
	for slot = 1, SaveBackup.SLOTS do
		local ok, value = pcall(function()
			return (activeStore :: DataStore):GetAsync(SaveBackup.slotKey(key, slot))
		end)
		if ok and value ~= nil then
			table.insert(candidates, value)
		end
	end
	for _, candidate in SaveBackup.newestFirst(candidates) do
		if canDecode(candidate) then
			local quarantined = pcall(function()
				(activeStore :: DataStore):SetAsync(SaveBackup.quarantineKey(key), corrupt)
			end)
			if not quarantined then
				warn(`[Data] RecoveryAborted user={userId}: karantina yazılamadı`)
				return nil
			end
			return candidate
		end
	end
	return nil
end

-- Kuyruk yalnız borç+outbox profil snapshot'ı doğrulandıktan sonra yayımlanır.
local memoryInboxes: { [number]: { [string]: TransferLedger.Entry } } = {}
local function inboxKey(userId: number): string
	return `__transfer_inbox_{userId}`
end

function SaveStore.publishTransfer(id: string, entry: TransferLedger.Entry): boolean
	if nonpersistent then
		local nextInbox = TransferLedger.publish(memoryInboxes[entry.targetId], id, entry)
		if not nextInbox then
			return false
		end
		memoryInboxes[entry.targetId] = nextInbox
		return true
	end
	local activeStore = store
	if not activeStore then
		return false
	end
	local accepted = false
	local ok = pcall(function()
		activeStore:UpdateAsync(inboxKey(entry.targetId), function(raw)
			local nextInbox = TransferLedger.publish(raw, id, entry)
			accepted = nextInbox ~= nil
			return nextInbox
		end)
	end)
	return ok and accepted
end

function SaveStore.readTransferInbox(userId: number): { [string]: TransferLedger.Entry }?
	if nonpersistent then
		return TransferLedger.parseInbox(memoryInboxes[userId])
	end
	local activeStore = store
	if not activeStore then
		return nil
	end
	local ok, raw = pcall(function()
		return activeStore:GetAsync(inboxKey(userId))
	end)
	return if ok then TransferLedger.parseInbox(raw) else nil
end

function SaveStore.ackTransfers(userId: number, ids: { string }): boolean
	local function remove(raw: unknown): { [string]: TransferLedger.Entry }?
		local inbox = TransferLedger.parseInbox(raw)
		if not inbox then
			return nil
		end
		for _, id in ids do
			inbox[id] = nil
		end
		return inbox
	end
	if nonpersistent then
		local inbox = remove(memoryInboxes[userId])
		if not inbox then
			return false
		end
		memoryInboxes[userId] = inbox
		return true
	end
	local activeStore = store
	if not activeStore then
		return false
	end
	local accepted = false
	local ok = pcall(function()
		activeStore:UpdateAsync(inboxKey(userId), function(raw)
			local inbox = remove(raw)
			accepted = inbox ~= nil
			return inbox
		end)
	end)
	return ok and accepted
end

return SaveStore
