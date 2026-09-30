--!strict
-- Sunucu profili: atomik oturum kilidi, anahtar başına sıralı kayıt ve kontrollü kapanış.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local SessionLock = require(script.Parent.Parent.Modules.SessionLock)
local SaveCodec = require(script.Parent.Parent.Modules.SaveCodec)
local FarmProfiles = require(script.Parent.Parent.Modules.FarmProfiles)
local Metrics = require(script.Parent.Parent.Modules.Metrics)

type PlayerSave = GameTypes.PlayerSave
type Session = {
	owner: string,
	data: PlayerSave?,
	persistent: boolean,
	status: string,
	loaded: boolean,
	releasing: boolean,
	revision: number,
	packetRevision: number,
	savedPacketRevision: number,
	leaseExpires: number,
	offlineEarned: number,
	offlineGrown: number, -- Çevrimdışıyken yetişkin olan hayvan sayısı (dönüş özeti)
	cashStat: IntValue?,
	saveScheduled: boolean,
	pending: {
		payload: { [string]: any },
		token: string,
		revision: number,
		packetRevision: number,
		release: boolean,
	}?,
}

local PlayerDataService = {}
local LEASE_SECONDS = 180
local SAVE_RETRIES = 3
local QUICK_SAVE_DELAY = 10
local SAVE_BUDGET = 15
local CLOSE_BUDGET = 25
local sessions: { [Player]: Session } = {}
local busyKeys: { [string]: boolean } = {}
local shutdownDeadline: number? = nil
local initialized = false
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

local function keyFor(player: Player): string
	return `player_{player.UserId}`
end

local function deadlineAfter(seconds: number): number
	return math.min(os.clock() + seconds, shutdownDeadline or math.huge)
end

local function withinDeadline(deadline: number): boolean
	return os.clock() < math.min(deadline, shutdownDeadline or math.huge)
end

local function retryWait(deadline: number, seconds: number)
	local remaining = math.min(deadline, shutdownDeadline or math.huge) - os.clock()
	if remaining > 0 then
		task.wait(math.min(seconds, remaining))
	end
end

local function lockKey(key: string, deadline: number): boolean
	while busyKeys[key] do
		if not withinDeadline(deadline) then
			return false
		end
		task.wait(0.05)
	end
	if not withinDeadline(deadline) then
		return false
	end
	busyKeys[key] = true
	return true
end

local function status(player: Player, session: Session, state: string, problem: string?)
	session.status = state
	player:SetAttribute("DataStatus", state)
	player:SetAttribute("DataPersistent", session.persistent)
	player:SetAttribute("DataError", problem or "")
end

local function fail(player: Player, session: Session, problem: string)
	status(player, session, "Failed", problem)
	warn(`[Data] ProfileFailed user={player.UserId}: {problem}`)
	-- Erişim kapalı kalır; client kalıcı hata ekranını DataStatus üzerinden gösterir.
end

local function newUid(): string
	return HttpService:GenerateGUID(false)
end

local function cleanup(player: Player, session: Session)
	if sessions[player] == session then
		sessions[player] = nil
	end
	session.data = nil
	status(player, session, "Closed", nil)
end

local function updateLeaderstat(session: Session, data: PlayerSave)
	if session.cashStat then
		session.cashStat.Value = math.floor(data.cash)
	end
end

-- Snapshot, anahtar kilidine girdikten sonra alınır. Retry aynı payload/token ile yapılır.
local function write(player: Player, session: Session, release: boolean, deadline: number): boolean
	local key = keyFor(player)
	if not lockKey(key, deadline) then
		return false
	end
	if sessions[player] ~= session or not session.data or not store then
		busyKeys[key] = nil
		return false
	end
	if not release and session.status ~= "Active" then
		busyKeys[key] = nil
		return false
	end
	if not session.pending then
		local encodeOk, payload = pcall(SaveCodec.encode, session.data, DateTime.now().UnixTimestampMillis / 1000)
		if not encodeOk then
			busyKeys[key] = nil
			fail(player, session, `Kayıt hazırlanamadı: {payload}`)
			return false
		end
		session.pending = {
			payload = payload,
			token = newUid(),
			revision = session.revision,
			packetRevision = session.packetRevision,
			release = release,
		}
	end
	local operation = assert(session.pending, "Serialized write operation missing")
	local token = operation.token
	local snapshotRevision = operation.packetRevision
	local success = false
	local ownershipLost = false
	local lastError = "Kayıt zaman bütçesi doldu"
	for attempt = 1, SAVE_RETRIES do
		if not withinDeadline(deadline) then
			break
		end
		local rejection: string? = nil
		local ok, result = pcall(function()
			return (store :: DataStore):UpdateAsync(key, function(current)
				if not withinDeadline(deadline) then
					rejection = "Kayıt zaman bütçesi doldu"
					return nil
				end
				local nextValue, problem = SessionLock.commit(
					current,
					session.owner,
					operation.revision,
					token,
					operation.payload,
					os.time(),
					LEASE_SECONDS,
					operation.release
				)
				rejection = problem
				return nextValue
			end)
		end)
		if ok and typeof(result) == "table" and result._lastWrite == token then
			if not operation.release and not SessionLock.owns(result, session.owner, os.time()) then
				ownershipLost = true
				lastError = "Kayıt oturumunun sahipliği kaybedildi"
				break
			end
			session.revision = result._revision
			session.savedPacketRevision = snapshotRevision
			session.leaseExpires = if operation.release then 0 else result._session.expiresAt
			session.pending = nil
			player:SetAttribute("DataLastSavedAt", os.time())
			player:SetAttribute("DataDirty", session.packetRevision ~= snapshotRevision)
			player:SetAttribute("DataError", "")
			success = true
			Metrics.increment("SaveSucceeded")
			break
		end
		lastError = rejection or tostring(result)
		if rejection and rejection ~= "Kayıt zaman bütçesi doldu" then
			ownershipLost = true
			break
		end
		warn(`[Data] SaveRetry user={player.UserId} attempt={attempt}: {lastError}`)
		Metrics.increment("SaveRetry")
		if attempt < SAVE_RETRIES and withinDeadline(deadline) then
			retryWait(deadline, attempt)
		end
	end
	busyKeys[key] = nil
	if success and release and not operation.release then
		-- Önce cevabı kaybolmuş eski yazmayı uzlaştır; sonra EN SON snapshot ile kilidi bırak.
		return write(player, session, true, deadline)
	end
	if not success then
		player:SetAttribute("DataError", lastError)
		if ownershipLost or os.time() >= session.leaseExpires then
			fail(player, session, lastError)
		end
	end
	return success
end

function PlayerDataService.tryGet(player: Player): PlayerSave?
	local session = sessions[player]
	if not session or session.status ~= "Active" then
		return nil
	end
	if session.persistent and os.time() >= session.leaseExpires then
		fail(player, session, "Kayıt oturumu yenilenemedi; yeniden bağlanmalısın.")
		return nil
	end
	return session.data
end

function PlayerDataService.get(player: Player): PlayerSave
	local data = PlayerDataService.tryGet(player)
	assert(data, `Etkin PlayerData yok: {player.Name}`)
	return data
end

function PlayerDataService.load(player: Player): PlayerSave?
	if sessions[player] or shutdownDeadline then
		return nil
	end
	local loadStarted = os.clock()
	local session: Session = {
		owner = newUid(),
		data = nil,
		persistent = not nonpersistent,
		status = "Loading",
		loaded = false,
		releasing = false,
		revision = 0,
		packetRevision = 0,
		savedPacketRevision = 0,
		leaseExpires = 0,
		offlineEarned = 0,
		offlineGrown = 0,
		cashStat = nil,
		saveScheduled = false,
		pending = nil,
	}
	sessions[player] = session
	status(player, session, "Loading", nil)
	local raw: unknown = nil
	local problem: string? = nil
	local acquired = nonpersistent
	local deadline = deadlineAfter(SAVE_BUDGET)
	local key = keyFor(player)
	if session.persistent then
		if not store then
			problem = "Kayıt hizmetine bağlanılamadı. Lütfen yeniden bağlan."
		elseif lockKey(key, deadline) then
			for attempt = 1, SAVE_RETRIES do
				if not withinDeadline(deadline) then
					break
				end
				local rejection: string? = nil
				local ok, result = pcall(function()
					return (store :: DataStore):UpdateAsync(key, function(current)
						if not withinDeadline(deadline) then
							rejection = "Yükleme zaman bütçesi doldu"
							return nil
						end
						local nextValue, reason = SessionLock.acquire(current, session.owner, os.time(), LEASE_SECONDS)
						rejection = reason
						return nextValue
					end)
				end)
				if ok and SessionLock.owns(result, session.owner, os.time()) then
					raw = result
					session.revision = result._revision
					session.leaseExpires = result._session.expiresAt
					acquired = true
					break
				end
				problem = rejection or tostring(result)
				if rejection then
					break
				end
				if attempt < SAVE_RETRIES and withinDeadline(deadline) then
					retryWait(deadline, attempt)
				end
			end
			busyKeys[key] = nil
		end
	end
	if acquired then
		local decodeOk, data, offlineEarned, decodeProblem, repairs, grown =
			pcall(SaveCodec.decode, raw, Config, FarmMath, DateTime.now().UnixTimestampMillis / 1000, newUid)
		if decodeOk and data then
			session.data = data
			session.offlineEarned = offlineEarned
			session.offlineGrown = grown or 0
			player:SetAttribute("SavedLanguage", data.language or "")
			player:SetAttribute("SavedGraphics", data.graphics or "")
			player:SetAttribute("DataRepairCount", repairs or 0)
			if repairs and repairs > 0 then
				warn(`[Data] ProfileNormalized user={player.UserId} repairs={repairs}`)
			end
		else
			problem = if decodeOk then decodeProblem else tostring(data)
		end
	end
	session.loaded = true
	Metrics.duration("ProfileLoad", os.clock() - loadStarted)
	if not acquired or not session.data then
		Metrics.increment("ProfileLoadFailed")
		fail(player, session, problem or "Kayıt yüklenemedi. Lütfen yeniden bağlan.")
		if not player.Parent then
			cleanup(player, session)
		end
		return nil
	end
	if not player.Parent or session.status == "Closing" or shutdownDeadline then
		-- PlayerRemoving/BindToClose çağrısı yükleme tamamlanmasını bekliyor olabilir.
		if not session.releasing then
			PlayerDataService.release(player)
		end
		return nil
	end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Para"
	cash.Parent = leaderstats
	leaderstats.Parent = player
	session.cashStat = cash
	updateLeaderstat(session, session.data)
	status(player, session, "Active", nil)
	Metrics.increment("ProfileLoaded")
	player:SetAttribute("DataDirty", true)
	return session.data
end

-- Dönüş özeti için: çevrimdışıyken kazanılan para ve yetişkin olan hayvan sayısı (bir kez okunur)
function PlayerDataService.takeOfflineSummary(player: Player): (number, number)
	local session = sessions[player]
	if not session then
		return 0, 0
	end
	local earned, grown = session.offlineEarned, session.offlineGrown
	session.offlineEarned, session.offlineGrown = 0, 0
	return earned, grown
end

function PlayerDataService.takeOfflineEarnings(player: Player): number
	local session = sessions[player]
	if not session then
		return 0
	end
	local amount = session.offlineEarned
	session.offlineEarned = 0
	return amount
end

function PlayerDataService.save(player: Player): boolean
	local session = sessions[player]
	if not session or not PlayerDataService.tryGet(player) then
		return false
	end
	if not session.persistent then
		return true
	end
	return write(player, session, false, deadlineAfter(SAVE_BUDGET))
end

function PlayerDataService.requestSave(player: Player)
	local session = sessions[player]
	if not session or session.status ~= "Active" or session.saveScheduled then
		return
	end
	player:SetAttribute("DataDirty", true)
	session.saveScheduled = true
	task.delay(QUICK_SAVE_DELAY, function()
		if sessions[player] ~= session then
			return
		end
		session.saveScheduled = false
		PlayerDataService.save(player)
	end)
end

function PlayerDataService.release(player: Player): boolean
	local session = sessions[player]
	if not session then
		return true
	end
	local deadline = deadlineAfter(CLOSE_BUDGET)
	if session.releasing then
		while sessions[player] == session and session.releasing and withinDeadline(deadline) do
			task.wait(0.05)
		end
		return sessions[player] ~= session
	end
	session.releasing = true
	status(player, session, "Closing", nil)
	while not session.loaded and withinDeadline(deadline) do
		task.wait(0.05)
	end
	if not session.loaded then
		session.releasing = false
		return false
	end
	if not session.data or not session.persistent then
		cleanup(player, session)
		return true
	end
	local success = write(player, session, true, deadline)
	if success then
		cleanup(player, session)
	else
		-- Başarısız son snapshot bellekten atılmaz; bakım döngüsü süreli kilit bitene kadar tekrar dener.
		session.releasing = false
		status(player, session, "Closing", player:GetAttribute("DataError"))
		warn(`[Data] FinalSaveFailed user={player.UserId}; snapshot retained`)
		Metrics.increment("FinalSaveFailed")
	end
	return success
end

function PlayerDataService.addCash(player: Player, amount: number)
	if not SessionLock.isFinite(amount) or amount <= 0 then
		return
	end
	local data = PlayerDataService.tryGet(player)
	if not data then
		return
	end
	data.cash = math.min(1e15, data.cash + amount)
	-- Ömür boyu kazanç (başarımlar): yalnızca kazanç kalemleri addCash'ten geçer, harcama düşmez.
	data.lifetimeEarned = math.min(1e18, (data.lifetimeEarned or 0) + amount)
	PlayerDataService.pushEconomy(player)
end

-- Kazanç sayılmayan nakit girişi (hayvan satışı iadesi): başarım ve mevsim hedefi sayaçlarını şişirmez.
function PlayerDataService.addRefund(player: Player, amount: number)
	if not SessionLock.isFinite(amount) or amount <= 0 then
		return
	end
	local data = PlayerDataService.tryGet(player)
	if not data then
		return
	end
	data.cash = math.min(1e15, data.cash + amount)
	PlayerDataService.pushEconomy(player)
end

function PlayerDataService.trySpend(player: Player, amount: number): boolean
	if not SessionLock.isFinite(amount) or amount < 0 then
		return false
	end
	local data = PlayerDataService.tryGet(player)
	if not data or data.cash < amount then
		return false
	end
	data.cash -= amount
	PlayerDataService.pushEconomy(player)
	return true
end

local mainFarmOffersResolver: (() -> { any })? = nil
function PlayerDataService.setMainFarmOffersResolver(resolver: () -> { any })
	mainFarmOffersResolver = resolver
end

local farmPlotResolver: ((Player, string) -> string?)? = nil
function PlayerDataService.setFarmPlotResolver(resolver: (Player, string) -> string?)
	farmPlotResolver = resolver
end
function PlayerDataService.getFarmIds(player: Player): { string }
	local data = PlayerDataService.tryGet(player)
	return if data then FarmProfiles.ids(data) else {}
end
function PlayerDataService.getFarmView(player: Player, farmId: string): any
	local data = PlayerDataService.tryGet(player)
	return if data then FarmProfiles.view(data, farmId) else nil
end
function PlayerDataService.setActiveMainFarm(player: Player, farmId: string): boolean
	local data = PlayerDataService.tryGet(player)
	return data ~= nil and FarmProfiles.select(data, farmId)
end

function PlayerDataService.pushState(player: Player)
	local data = PlayerDataService.tryGet(player)
	local session = sessions[player]
	if not data or not session then
		return
	end
	session.packetRevision += 1
	player:SetAttribute("DataDirty", true)
	updateLeaderstat(session, data)
	data.mainFarmSummaries = FarmProfiles.summaries(data, function(id: string): string?
		return if farmPlotResolver then farmPlotResolver(player, id) else nil
	end)
	data.mainFarmOffers = if mainFarmOffersResolver then mainFarmOffersResolver() else {}
	Remotes.get("PlayerState"):FireClient(player, data, session.packetRevision)
end

function PlayerDataService.pushEconomy(player: Player)
	local data = PlayerDataService.tryGet(player)
	local session = sessions[player]
	if not data or not session then
		return
	end
	session.packetRevision += 1
	player:SetAttribute("DataDirty", true)
	updateLeaderstat(session, data)
	Remotes.get("EconomyTick"):FireClient(
		player,
		data.cash,
		data.stored,
		session.packetRevision,
		if data.order then data.order.progress else nil,
		data.activeMainFarmId
	)
end

function PlayerDataService.init()
	if initialized then
		return
	end
	initialized = true
	task.spawn(function()
		while not shutdownDeadline do
			task.wait(math.min(Config.AUTOSAVE_SECONDS, LEASE_SECONDS / 3))
			for player, session in sessions do
				if session.status == "Active" then
					task.spawn(PlayerDataService.save, player)
				elseif session.status == "Closing" and not session.releasing and session.data then
					if os.time() < session.leaseExpires then
						task.spawn(PlayerDataService.release, player)
					else
						warn(`[Data] FinalSaveAbandoned user={player.UserId}; lease expired`)
						cleanup(player, session)
					end
				end
			end
		end
	end)
	game:BindToClose(function()
		shutdownDeadline = os.clock() + CLOSE_BUDGET
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				PlayerDataService.release(player)
				pending -= 1
			end)
		end
		while pending > 0 and os.clock() < (shutdownDeadline :: number) do
			task.wait(0.05)
		end
		if pending > 0 then
			warn(`[Data] ShutdownDeadline pending={pending}`)
		end
	end)
end

return PlayerDataService
