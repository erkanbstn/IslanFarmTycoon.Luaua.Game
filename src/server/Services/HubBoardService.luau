--!strict
-- Meydandaki sıralama panoları. Pano modelleri haritada kurulur (HubBuilder); burası yalnızca satırları günceller
-- (değişmeyen metne yazılmaz). Üç pano vardır:
--   PlayerBoard   "Sunucu Sıralaması": bu sunucudaki oyuncuların kasası, ada ve rebirth sayısı (3 sn'de bir, yerel).
--   RebirthBoard  Genel (tüm sunucular): en çok rebirth.
--   FarmBoard     Genel (tüm sunucular): en çok tamamlanmış çiftlik.
-- Genel tablolar yalnızca bilgi içindir (ödül/gerçek para yok). Değer her zaman sunucudaki kayıttan hesaplanır
-- (Modules/Leaderboard), yönetici hesabı canlı sunucuda yazılmaz/listelenmez (Studio'da ayrı _Studio/bellek mağazası
-- kullanıldığı için test edilebilsin diye listelenir), DataStore'a yalnızca SaveStore dokunur. Yazma/okuma
-- aralıklı ve önbellekli; hata/bütçe aşımında son bilinen liste görünür kalır. Görünen ad yalnızca DisplayName'dir.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Progression = require(Shared:WaitForChild("Modules"):WaitForChild("Progression"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))
local AdminPolicy = require(script.Parent.Parent.Modules.AdminPolicy)
local Leaderboard = require(script.Parent.Parent.Modules.Leaderboard)
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local SaveStore = require(script.Parent:WaitForChild("SaveStore"))

local HubBoardService = {}

local REFRESH_SECONDS = 3
local GLOBAL_STEP_SECONDS = 5
local NAME_RETRY_SECONDS = 120
local MAX_TRACKED_PLAYERS = 64
local initialized = false

type Entry = { name: string, cash: number, farms: number, rebirth: number }

-- Genel tablo: modeldeki pano parçası adı ve satır metni
local GLOBAL_BOARDS: { { id: string, part: string, value: (score: number) -> string } } = {
	{
		id = "rebirth",
		part = "RebirthBoard",
		value = function(score: number): string
			return `Rebirth: {score}`
		end,
	},
	{
		id = "farms",
		part = "FarmBoard",
		value = function(score: number): string
			return `{score} çiftlik`
		end,
	},
}

-- Canlı sunucuda yönetici hesabı genel tablolardan dışlanır (hile/test verisi listelenmesin); Studio'da dahildir.
local function isExcluded(userId: number): boolean
	return AdminPolicy.isAllowed(userId) and not RunService:IsStudio()
end

local function findBoard(partName: string): Instance?
	local world = Workspace:FindFirstChild("World")
	return if world then world:FindFirstChild(partName, true) else nil
end

local function refreshLocal()
	local board = findBoard("PlayerBoard")
	if not board then
		return
	end
	local entries: { Entry } = {}
	for _, player in Players:GetPlayers() do
		local data = PlayerDataService.tryGet(player)
		if data then
			table.insert(entries, {
				name = player.DisplayName,
				cash = math.floor(data.cash),
				farms = #PlayerDataService.getFarmIds(player),
				rebirth = if data.progression then data.progression.count else 0,
			})
		end
	end
	table.sort(entries, function(a: Entry, b: Entry): boolean
		if a.cash ~= b.cash then
			return a.cash > b.cash
		end
		return a.name < b.name
	end)
	for index = 1, Config.MAP_PLOT_COUNT do
		local entry = entries[index]
		if entry then
			WorldUi.setBoardRow(
				board,
				index,
				`{index}. {entry.name}`,
				`{FarmMath.formatMoney(entry.cash)} · {entry.farms} ada\nRebirth: {entry.rebirth}`
			)
		else
			WorldUi.setBoardRow(board, index, "", "")
		end
	end
end

-- Genel tablolar -------------------------------------------------------------------------------------------------

type GlobalState = {
	stored: { { userId: number, score: number } },
	loaded: boolean, -- en az bir başarılı okuma oldu
	read: Leaderboard.Schedule,
}

local globalState: { [string]: GlobalState } = {}
local publishSchedules: { [number]: { [string]: Leaderboard.Schedule } } = {}
local nameCache: { [number]: string } = {}
local nameFailedAt: { [number]: number } = {}

local function scheduleFor(userId: number, boardId: string): Leaderboard.Schedule
	local perUser = publishSchedules[userId]
	if not perUser then
		perUser = {}
		publishSchedules[userId] = perUser
	end
	local schedule = perUser[boardId]
	if not schedule then
		schedule = Leaderboard.newSchedule(Leaderboard.PUBLISH_INTERVAL)
		perUser[boardId] = schedule
	end
	return schedule
end

-- Sunucudaki oyuncuların canlı değerleri: kimlik -> değer (yönetici ve kaydı yüklenmemiş oyuncu hariç)
local function liveScores(boardId: string): ({ [number]: number }, { [number]: string })
	local scores: { [number]: number } = {}
	local names: { [number]: string } = {}
	for _, player in Players:GetPlayers() do
		local data = PlayerDataService.tryGet(player)
		if data then
			local score = Leaderboard.score(boardId, data, Progression.progress(data), isExcluded(player.UserId))
			if score ~= nil then
				scores[player.UserId] = score
				names[player.UserId] = player.DisplayName
			end
		end
	end
	return scores, names
end

local function publishStep(now: number)
	for _, player in Players:GetPlayers() do
		local data = PlayerDataService.tryGet(player)
		if data then
			for _, board in GLOBAL_BOARDS do
				local score = Leaderboard.score(board.id, data, Progression.progress(data), isExcluded(player.UserId))
				local schedule = if score ~= nil then scheduleFor(player.UserId, board.id) else nil
				-- Sıfır değer boş satır olur ve yazım bütçesini harcar: daha önce yazılmış bir değer yoksa yazılmaz
				if score ~= nil and schedule and not (score == 0 and schedule.lastValue() == nil) then
					if Leaderboard.shouldPublish(schedule, score, now) then
						local ok = SaveStore.publishRank(board.id, player.UserId, score)
						if ok then
							schedule.success(now, score)
						else
							schedule.failure(now)
						end
					end
				end
			end
		end
	end
	-- Ayrılan oyuncuların takvimleri sınırsız büyümesin (yeniden girişte hemen yazma önlemi için kısa süre tutulur)
	local tracked = 0
	for _ in publishSchedules do
		tracked += 1
	end
	if tracked > MAX_TRACKED_PLAYERS then
		local present: { [number]: boolean } = {}
		for _, player in Players:GetPlayers() do
			present[player.UserId] = true
		end
		for userId in publishSchedules do
			if not present[userId] then
				publishSchedules[userId] = nil
			end
		end
	end
end

-- Çevrimdışı oyuncuların görünen adı: UserService (DisplayName), yalnızca bellekte önbellek; başarısızsa kısa süre sonra yeniden denenir
local function resolveNames(userIds: { number }, now: number)
	local missing: { number } = {}
	for _, userId in userIds do
		local failedAt = nameFailedAt[userId]
		if nameCache[userId] == nil and (failedAt == nil or now - failedAt >= NAME_RETRY_SECONDS) then
			table.insert(missing, userId)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function()
		return game:GetService("UserService"):GetUserInfosByUserIdsAsync(missing)
	end)
	if ok and typeof(infos) == "table" then
		for _, info in infos :: { any } do
			if typeof(info) == "table" and typeof(info.Id) == "number" then
				local name = if typeof(info.DisplayName) == "string" and info.DisplayName ~= ""
					then info.DisplayName
					else info.Username
				nameCache[info.Id] = Leaderboard.cleanName(name)
			end
		end
	end
	for _, userId in missing do
		if nameCache[userId] == nil then
			nameFailedAt[userId] = now
		end
	end
end

local function renderGlobal(board: { id: string, part: string, value: (score: number) -> string })
	local instance = findBoard(board.part)
	if not instance then
		return
	end
	local state = globalState[board.id]
	local rows = Config.MAP_PLOT_COUNT
	if not state.loaded and #state.stored == 0 then
		-- İlk başarılı okumaya kadar ya da genel liste hiç kullanılamıyorsa tek satır açıklama; yalnız sunucudaki oyuncular da görünür
		local scores, names = liveScores(board.id)
		local live = Leaderboard.merge({}, scores, names)
		for index = 1, rows do
			local entry = live[index]
			if entry then
				WorldUi.setBoardRow(instance, index, `{index}. {entry.name}`, board.value(entry.score))
			elseif index == #live + 1 then
				WorldUi.setBoardRow(
					instance,
					index,
					if SaveStore.rankingAvailable() then "Yükleniyor…" else "Şu an kullanılamıyor",
					""
				)
			else
				WorldUi.setBoardRow(instance, index, "", "")
			end
		end
		return
	end
	local scores, liveNames = liveScores(board.id)
	local names = table.clone(nameCache)
	for userId, name in liveNames do
		names[userId] = name
	end
	local storedRows: { any } = {}
	for _, row in state.stored do
		-- Yönetici/hariç tutulan hesap eski bir kayıttan bile görünmez
		if not isExcluded(row.userId) then
			table.insert(storedRows, row)
		end
	end
	local ranked = Leaderboard.merge(storedRows, scores, names)
	for index = 1, rows do
		local entry = ranked[index]
		if entry then
			WorldUi.setBoardRow(instance, index, `{index}. {entry.name}`, board.value(entry.score))
		else
			WorldUi.setBoardRow(instance, index, "", "")
		end
	end
end

local function readStep(now: number)
	for _, board in GLOBAL_BOARDS do
		local state = globalState[board.id]
		if state.read.due(now) then
			local rows, reason = SaveStore.readTopRank(board.id, Config.MAP_PLOT_COUNT + 4)
			if rows then
				state.stored = rows
				state.loaded = true
				state.read.success(now)
				local ids: { number } = {}
				for _, row in rows do
					table.insert(ids, row.userId)
				end
				resolveNames(ids, now)
			else
				state.read.failure(now)
				-- Aynı kesinti her denemede günlüğü doldurmasın: yalnızca ilk hata yazılır
				if state.read.failures() == 1 then
					warn(`[HubBoard] genel sıralama okunamadı ({board.id}): {reason}`)
				end
			end
		end
	end
end

local function globalStep(now: number)
	publishStep(now)
	readStep(now)
	for _, board in GLOBAL_BOARDS do
		renderGlobal(board)
	end
end

function HubBoardService.init()
	if initialized then
		return
	end
	initialized = true
	for _, board in GLOBAL_BOARDS do
		globalState[board.id] = {
			stored = {},
			loaded = false,
			read = Leaderboard.newSchedule(Leaderboard.READ_INTERVAL),
		}
	end
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				refreshLocal()
			end)
			if not ok then
				warn(`[HubBoard] {err}`)
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
	-- Genel tablolar ayrı işçide: DataStore beklemesi yerel panoyu geciktirmez
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				globalStep(os.clock())
			end)
			if not ok then
				warn(`[HubBoard] genel sıralama: {err}`)
			end
			task.wait(GLOBAL_STEP_SECONDS)
		end
	end)
end

return HubBoardService
