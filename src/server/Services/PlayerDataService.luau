--!strict
-- Sunucu profili (oturum/facade): oyuncu başına durum, para/durum itme ve kayıt döngüleri. DataStore erişimi
-- (oturum kilidi, sıralı yazım, yedek, kurtarma) `SaveStore`'dadır.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local SessionLock = require(script.Parent.Parent.Modules.SessionLock)
local SaveCodec = require(script.Parent.Parent.Modules.SaveCodec)
local FarmProfiles = require(script.Parent.Parent.Modules.FarmProfiles)
local Metrics = require(script.Parent.Parent.Modules.Metrics)
local SaveBackup = require(script.Parent.Parent.Modules.SaveBackup)
local SaveStore = require(script.Parent.SaveStore)
local TelemetryService = require(script.Parent.TelemetryService)
local Preferences = require(script.Parent.Parent.Modules.Preferences)

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
	saveFailing: boolean, -- son kayıt denemesi aktarım hatasıyla başarısız oldu (kira dolsa da oturum düşmez)
	offlineEarned: number,
	offlineGrown: number, -- Çevrimdışıyken yetişkin olan hayvan sayısı (dönüş özeti)
	cashStat: IntValue?,
	saveScheduled: boolean,
	lastBackupAt: number, -- son yedek yazma zamanı (os.time)
	backupSlot: number, -- dönüşümlü yedek yuvası
	statePending: boolean, -- PlayerState gönderimi sıraya alındı (birleştirme)
	lastStateAt: number, -- son PlayerState gönderimi (os.clock)
	sizeLevel: string, -- son bildirilen kayıt boyutu seviyesi (ok/warn/critical)
	recovered: boolean, -- asıl kayıt bozuk olduğu için yedekten açıldı
	pending: {
		payload: { [string]: any },
		token: string,
		revision: number,
		packetRevision: number,
		release: boolean,
	}?,
}

local PlayerDataService = {}
local LEASE_SECONDS = SaveStore.LEASE_SECONDS
local SAVE_BUDGET = SaveStore.SAVE_BUDGET
local QUICK_SAVE_DELAY = 10
local CLOSE_BUDGET = 25
local STATE_PUSH_INTERVAL = 0.25 -- oyuncu başına PlayerState en çok bu aralıkla gider
local FINAL_SAVE_GRACE_SECONDS = 600 -- bırakma yazımı, kira dolduktan sonra da (kilit hâlâ bizse) bu süre denenir
local sessions: { [Player]: Session } = {}
local initialized = false

local function keyFor(player: Player): string
	return SaveStore.keyFor(player.UserId)
end

local function status(player: Player, session: Session, state: string, problem: string?)
	session.status = state
	player:SetAttribute("DataStatus", state)
	player:SetAttribute("DataPersistent", session.persistent)
	player:SetAttribute("DataError", problem or "")
end

local function fail(player: Player, session: Session, problem: string)
	status(player, session, "Failed", problem)
	-- Veri kaybı riski: Creator Hub'da görünsün diye warn değil hata olarak (ayrı iş parçacığında) loglanır.
	TelemetryService.critical(`[Data] ProfileFailed user={player.UserId}: {problem}`)
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
	local startedAt = os.clock()
	if not SaveStore.lockKey(key, deadline) then
		return false
	end
	if sessions[player] ~= session or not session.data or not SaveStore.available() then
		SaveStore.unlockKey(key)
		return false
	end
	if not release and session.status ~= "Active" then
		SaveStore.unlockKey(key)
		return false
	end
	if not session.pending then
		local encodeOk, payload = pcall(SaveCodec.encode, session.data, DateTime.now().UnixTimestampMillis / 1000)
		if not encodeOk then
			SaveStore.unlockKey(key)
			fail(player, session, `Kayıt hazırlanamadı: {payload}`)
			return false
		end
		local measured, encoded = pcall(function()
			return HttpService:JSONEncode(payload)
		end)
		if measured and typeof(encoded) == "string" then
			local bytes = #encoded
			Metrics.set("SaveBytesLast", bytes)
			Metrics.max("SaveBytesMax", bytes)
			player:SetAttribute("DataBytes", bytes)
			local level = SaveBackup.sizeLevel(bytes)
			if level ~= session.sizeLevel then
				session.sizeLevel = level
				if level ~= "ok" then
					Metrics.increment("SaveSizeWarning")
					warn(`[Data] SaveSize{level} user={player.UserId} bytes={bytes}/4194304`)
				end
			end
		end
		session.pending = {
			payload = payload,
			token = newUid(),
			revision = session.revision,
			packetRevision = session.packetRevision,
			release = release :: boolean,
		}
	end
	local operation = assert(session.pending, "Serialized write operation missing")
	local snapshotRevision = operation.packetRevision
	local outcome = SaveStore.commit(key, player.UserId, session.owner, operation, deadline)
	if outcome.ok then
		session.revision = outcome.revision
		session.savedPacketRevision = snapshotRevision
		session.leaseExpires = outcome.expiresAt
		session.pending = nil
		session.saveFailing = false
		player:SetAttribute("DataLastSavedAt", os.time())
		player:SetAttribute("DataDirty", session.packetRevision ~= snapshotRevision)
		player:SetAttribute("DataError", "")
		Metrics.increment("SaveSucceeded")
		Metrics.duration("SaveWrite", os.clock() - startedAt)
		if SaveBackup.due(os.time(), session.lastBackupAt) then
			session.lastBackupAt = os.time()
			session.backupSlot = SaveBackup.nextSlot(session.backupSlot)
			local slot = session.backupSlot
			task.spawn(function()
				local written, stampedAt = SaveStore.writeBackup(key, player.UserId, slot, operation.payload)
				if written then
					player:SetAttribute("DataBackupAt", stampedAt)
				end
			end)
		end
	end
	SaveStore.unlockKey(key)
	if outcome.ok and release and not operation.release then
		-- Önce cevabı kaybolmuş eski yazmayı uzlaştır; sonra EN SON snapshot ile kilidi bırak.
		return write(player, session, true, deadline)
	end
	if not outcome.ok then
		Metrics.increment("SaveFailed")
		TelemetryService.custom(player, "SaveFailed")
		player:SetAttribute("DataError", outcome.lastError)
		-- Kira dolsa bile yalnızca sahiplik gerçekten kaybedildiyse düş: sahip + revizyon bizse sonraki yazım güvenle geçer.
		if outcome.ownershipLost then
			fail(player, session, outcome.lastError)
		else
			session.saveFailing = true
		end
	end
	return outcome.ok
end

function PlayerDataService.tryGet(player: Player): PlayerSave?
	local session = sessions[player]
	if not session or session.status ~= "Active" then
		return nil
	end
	if session.persistent and os.time() >= session.leaseExpires and not session.saveFailing then
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

-- Telemetri: hunide kayıttan geçilmiş adımlar ve çevrimdışı dönüş (süre ham kayıttaki lastSeen'den; sınır Pasif Gelir'e göre).
local function reportLoaded(player: Player, session: Session, raw: unknown)
	local data = session.data
	if not data then
		return
	end
	local views = {}
	for _, farmId in FarmProfiles.ids(data) do
		table.insert(views, FarmProfiles.view(data, farmId))
	end
	local now = DateTime.now().UnixTimestampMillis / 1000
	local lastSeen = if typeof(raw) == "table" then (raw :: any).lastSeen else nil
	local offline = nil
	if session.offlineEarned > 0 and typeof(lastSeen) == "number" and lastSeen >= 0 and lastSeen <= now then
		local _, hours = FarmMath.getOfflineTerms(data)
		offline = {
			earned = session.offlineEarned,
			awaySeconds = now - lastSeen,
			capped = now - lastSeen > hours * 3600,
			balance = data.cash,
		}
	end
	TelemetryService.onLoaded(player, views, offline)
end

function PlayerDataService.load(player: Player): PlayerSave?
	if sessions[player] or SaveStore.shutdownDeadline() then
		return nil
	end
	local loadStarted = os.clock()
	local session: Session = {
		owner = newUid(),
		data = nil,
		persistent = SaveStore.persistent,
		status = "Loading",
		loaded = false,
		releasing = false,
		revision = 0,
		packetRevision = 0,
		savedPacketRevision = 0,
		leaseExpires = 0,
		saveFailing = false,
		offlineEarned = 0,
		offlineGrown = 0,
		cashStat = nil,
		saveScheduled = false,
		statePending = false,
		lastStateAt = -math.huge,
		lastBackupAt = 0,
		backupSlot = 0,
		sizeLevel = "ok",
		recovered = false,
		pending = nil,
	}
	sessions[player] = session
	status(player, session, "Loading", nil)
	local raw: unknown = nil
	local problem: string? = nil
	local acquired = not SaveStore.persistent
	local key = keyFor(player)
	if session.persistent then
		local lockedRecord, reason = SaveStore.acquire(key, session.owner, function(): boolean
			return player.Parent ~= nil
		end, function()
			Metrics.increment("LoadLockWait")
			TelemetryService.custom(player, "LoadLockWait")
		end)
		if lockedRecord then
			raw = lockedRecord
			session.revision = lockedRecord._revision
			session.leaseExpires = lockedRecord._session.expiresAt
			acquired = true
		else
			problem = reason
		end
	end
	if acquired then
		local decodeNow = DateTime.now().UnixTimestampMillis / 1000
		local function adopt(data: any, offlineEarned: number, repairs: number?, grown: number?)
			session.data = data
			session.offlineEarned = offlineEarned
			session.offlineGrown = grown or 0
			player:SetAttribute("SavedLanguage", data.language or "")
			player:SetAttribute("SavedGraphics", data.graphics or "")
			for name, value in Preferences.attributes(data) do
				player:SetAttribute(name, value)
			end
			player:SetAttribute("DataRepairCount", repairs or 0)
			if repairs and repairs > 0 then
				warn(`[Data] ProfileNormalized user={player.UserId} repairs={repairs}`)
			end
		end
		local decodeOk, data, offlineEarned, decodeProblem, repairs, grown =
			pcall(SaveCodec.decode, raw, Config, FarmMath, decodeNow, newUid)
		if decodeOk and data then
			adopt(data, offlineEarned, repairs, grown)
		else
			problem = if decodeOk then decodeProblem else tostring(data)
			-- Bozuk asıl kayıt: en yeni çözülebilir yedekten aç (asıl kayıt karantinaya alınır, sonraki kayıtla düzelir)
			local backup = if session.persistent and raw ~= nil
				then SaveStore.recoverFromBackup(key, player.UserId, raw, function(candidate: unknown): boolean
					return (
						pcall(function()
							local decoded = SaveCodec.decode(candidate, Config, FarmMath, decodeNow, newUid)
							assert(decoded, "backup does not decode")
						end)
					)
				end)
				else nil
			if backup then
				local backupOk, backupData, backupEarned, _, backupRepairs, backupGrown =
					pcall(SaveCodec.decode, backup, Config, FarmMath, decodeNow, newUid)
				if backupOk and backupData then
					adopt(backupData, backupEarned, backupRepairs, backupGrown)
					session.recovered = true
					TelemetryService.critical(`[Data] ProfileRecovered user={player.UserId}: {problem}`)
					problem = nil
					Metrics.increment("ProfileRecovered")
					TelemetryService.custom(player, "ProfileRecovered")
				end
			end
		end
	end
	session.loaded = true
	Metrics.duration("ProfileLoad", os.clock() - loadStarted)
	if not acquired or not session.data then
		Metrics.increment("ProfileLoadFailed")
		TelemetryService.custom(player, "ProfileLoadFailed")
		fail(player, session, problem or "Kayıt yüklenemedi. Lütfen yeniden bağlan.")
		if not player.Parent then
			cleanup(player, session)
		end
		return nil
	end
	if not player.Parent or session.status == "Closing" or SaveStore.shutdownDeadline() then
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
	-- Telemetri hatası girişi bozmasın.
	if not pcall(reportLoaded, player, session, raw) then
		Metrics.increment("TelemetryError")
	end
	player:SetAttribute("DataDirty", true)
	player:SetAttribute("DataRecovered", session.recovered)
	if session.recovered then
		PlayerDataService.requestSave(player) -- asıl kayıt kısa sürede yedekten düzelir
	end
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
	local deadline = SaveStore.deadlineAfter(SAVE_BUDGET)
	-- Önceki başarısız yazımdan kalan eski anlık görüntü (pending) yeniden gönderilir; bu, sonradan olan değişiklikleri
	-- içermez. Başarılı sayılması için güncel veriyi taşıyan bir yazım daha gerekir (bırakma yolundaki gibi).
	local stale = session.pending
	local written = write(player, session, false, deadline)
	if written and stale and not stale.release then
		return write(player, session, false, deadline)
	end
	return written
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
	local deadline = SaveStore.deadlineAfter(CLOSE_BUDGET)
	if session.releasing then
		while sessions[player] == session and session.releasing and SaveStore.withinDeadline(deadline) do
			task.wait(0.05)
		end
		return sessions[player] ~= session
	end
	session.releasing = true
	status(player, session, "Closing", nil)
	while not session.loaded and SaveStore.withinDeadline(deadline) do
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
		local lastError = player:GetAttribute("DataError")
		status(player, session, "Closing", if typeof(lastError) == "string" then lastError else nil)
		warn(`[Data] FinalSaveFailed user={player.UserId}; snapshot retained`)
		Metrics.increment("FinalSaveFailed")
		TelemetryService.custom(player, "FinalSaveFailed")
	end
	return success
end

-- reason/sku: telemetri kategorisi (TelemetryLogic.ECONOMY anahtarı) ve sınırlı kümeden ürün kimliği; yoksa olay gönderilmez.
function PlayerDataService.addCash(player: Player, amount: number, reason: string?, sku: string?)
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
	if reason then
		TelemetryService.economy(player, reason, amount, data.cash, sku)
	end
end

-- Kazanç sayılmayan nakit girişi (hayvan satışı iadesi): başarım ve mevsim hedefi sayaçlarını şişirmez.
function PlayerDataService.addRefund(player: Player, amount: number, reason: string?, sku: string?)
	if not SessionLock.isFinite(amount) or amount <= 0 then
		return
	end
	local data = PlayerDataService.tryGet(player)
	if not data then
		return
	end
	data.cash = math.min(1e15, data.cash + amount)
	PlayerDataService.pushEconomy(player)
	if reason then
		TelemetryService.economy(player, reason, amount, data.cash, sku)
	end
end

-- Para (ve isteğe bağlı ürün) harcar. goodsCost verilirse para ve ürün TEK adımda düşer: biri yetmiyorsa hiçbiri düşmez.
function PlayerDataService.trySpend(
	player: Player,
	amount: number,
	reason: string?,
	sku: string?,
	goodsCost: { [string]: number }?
): boolean
	if not SessionLock.isFinite(amount) or amount < 0 then
		return false
	end
	local data = PlayerDataService.tryGet(player)
	if not data or data.cash < amount then
		return false
	end
	if goodsCost ~= nil and next(goodsCost) ~= nil and not FarmMath.removeGoodsBundle(data, goodsCost) then
		return false
	end
	data.cash -= amount
	PlayerDataService.pushEconomy(player)
	if reason then
		TelemetryService.economy(player, reason, amount, data.cash, sku)
	end
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

local function sendState(player: Player, session: Session)
	session.statePending = false
	local data = PlayerDataService.tryGet(player)
	if sessions[player] ~= session or not data or not player.Parent then
		return
	end
	session.lastStateAt = os.clock()
	local summaries = FarmProfiles.summaries(data, function(id: string): string?
		return if farmPlotResolver then farmPlotResolver(player, id) else nil
	end)
	local offers = if mainFarmOffersResolver then mainFarmOffersResolver() else {}
	Remotes.get("PlayerState")
		:FireClient(player, FarmProfiles.clientState(data, summaries, offers), session.packetRevision)
end

-- Kayıt/kirli işareti hemen güncellenir; istemciye gönderim oyuncu başına birleştirilir:
-- sessiz bir andaki ilk çağrı aynı karede (task.defer), sonrakiler son gönderimden 0,25 sn sonra tek pakette gider.
function PlayerDataService.pushState(player: Player)
	local data = PlayerDataService.tryGet(player)
	local session = sessions[player]
	if not data or not session then
		return
	end
	session.packetRevision += 1
	player:SetAttribute("DataDirty", true)
	updateLeaderstat(session, data)
	if session.statePending then
		return
	end
	session.statePending = true
	local delay = session.lastStateAt + STATE_PUSH_INTERVAL - os.clock()
	if delay > 0 then
		task.delay(delay, sendState, player, session)
	else
		task.defer(sendState, player, session)
	end
end

function PlayerDataService.pushEconomy(player: Player)
	local data = PlayerDataService.tryGet(player)
	local session = sessions[player]
	if not data or not session then
		return
	end
	player:SetAttribute("DataDirty", true)
	updateLeaderstat(session, data)
	if session.statePending then
		-- Bekleyen PlayerState zaten güncel parayı/depoyu taşır; araya giren EconomyTick istemcide revizyon boşluğu açıp
		-- gereksiz tam durum isteği doğurur.
		return
	end
	session.packetRevision += 1
	Remotes.get("EconomyTick"):FireClient(player, data.cash, data.stored, session.packetRevision, data.activeMainFarmId)
end

function PlayerDataService.init()
	if initialized then
		return
	end
	initialized = true
	task.spawn(function()
		while not SaveStore.shutdownDeadline() do
			task.wait(math.min(Config.AUTOSAVE_SECONDS, LEASE_SECONDS / 3))
			for player, session in sessions do
				if session.status == "Active" then
					task.spawn(PlayerDataService.save, player)
				elseif session.status == "Closing" and not session.releasing and session.data then
					if os.time() < session.leaseExpires + FINAL_SAVE_GRACE_SECONDS then
						task.spawn(PlayerDataService.release, player)
					else
						TelemetryService.critical(`[Data] FinalSaveAbandoned user={player.UserId}; lease expired`)
						TelemetryService.custom(player, "FinalSaveAbandoned")
						cleanup(player, session)
					end
				end
			end
		end
	end)
	game:BindToClose(function()
		SaveStore.beginShutdown(CLOSE_BUDGET)
		local closeDeadline = SaveStore.shutdownDeadline() :: number
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				PlayerDataService.release(player)
				pending -= 1
			end)
		end
		while pending > 0 and os.clock() < closeDeadline do
			task.wait(0.05)
		end
		if pending > 0 then
			warn(`[Data] ShutdownDeadline pending={pending}`)
		end
	end)
end

return PlayerDataService
