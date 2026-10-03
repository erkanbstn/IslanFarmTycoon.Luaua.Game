--!strict
-- Geri getiren döngüler: günlük giriş ödülü ve başarım ödülleri. Miktar, gün ve koşul yalnızca
-- sunucuda hesaplanır (Rewards); client yalnızca "al" der. Ödül verilmeden önce kayıt işaretlenir,
-- böylece tekrarlanan ya da gecikmiş istek ikinci ödülü alamaz.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Rewards = require(Shared:WaitForChild("Modules"):WaitForChild("Rewards"))
local Golden = require(Shared:WaitForChild("Modules"):WaitForChild("Golden"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local RequestGuard = require(script.Parent:WaitForChild("RequestGuard"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))
local Metrics = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Metrics"))

local EngagementService = {}

local function nowSeconds(): number
	return DateTime.now().UnixTimestamp
end

local function ready(player: Player): any?
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true then
		return nil
	end
	return data
end

function EngagementService.tryClaimDaily(player: Player): (boolean, string?)
	if not RateLimiter.allow(player, "claimDaily", 1) then
		return false, nil
	end
	local data = ready(player)
	if not data then
		return false, "Çiftliğin henüz hazır değil"
	end
	local now = nowSeconds()
	local status = Rewards.dailyStatus(data.daily, now)
	if not status.canClaim then
		return false, "Günlük ödülünü bugün zaten aldın"
	end
	EconomyService.settlePlayer(player)
	local amount = Rewards.dailyAmount(data, status.nextStreak)
	-- Gün işareti hemen yazılır; aynı ya da gecikmiş istek ikinci ödülü alamaz.
	data.daily = { day = Rewards.dayIndex(now), streak = status.nextStreak }
	PlayerDataService.addCash(player, amount, "daily")
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	Metrics.increment("DailyRewardsClaimed")
	return true, `Günlük ödül: +{FarmMath.formatMoney(amount)}`
end

function EngagementService.tryClaimAchievement(player: Player, achievementId: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "claimAchievement", 0.4) then
		return false, nil
	end
	if not RateLimiter.validId(achievementId) then
		return false, "Geçersiz başarım"
	end
	local data = ready(player)
	if not data then
		return false, "Çiftliğin henüz hazır değil"
	end
	local found: Config.AchievementConfig? = nil
	for _, achievement in Config.ACHIEVEMENTS do
		if achievement.id == achievementId then
			found = achievement
			break
		end
	end
	if not found then
		return false, "Bilinmeyen başarım"
	end
	local achievements = data.achievements
	if not achievements then
		achievements = {}
		data.achievements = achievements
	end
	if achievements[found.id] then
		return false, "Bu başarımın ödülü zaten alındı"
	end
	if not Rewards.isComplete(data, found) then
		return false, "Bu başarım henüz tamamlanmadı"
	end
	achievements[found.id] = true
	PlayerDataService.addCash(player, found.reward, "achievement")
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	Metrics.increment("AchievementsClaimed")
	return true, `Başarım tamamlandı: +{FarmMath.formatMoney(found.reward)}`
end

function EngagementService.tryClaimSeasonal(player: Player): (boolean, string?)
	if not RateLimiter.allow(player, "claimSeasonal", 1) then
		return false, nil
	end
	local data = ready(player)
	if not data then
		return false, "Çiftliğin henüz hazır değil"
	end
	local now = nowSeconds()
	local goal, stored = Rewards.seasonalGoal(data, now)
	if not stored then
		return false, "Bu mevsimin hedefi henüz hazır değil"
	end
	if goal.claimed then
		return false, "Mevsim hedefinin ödülü zaten alındı"
	end
	if Rewards.seasonalProgress(data, goal) < goal.target then
		return false, "Mevsim hedefi henüz tamamlanmadı"
	end
	EconomyService.settlePlayer(player)
	local amount = Rewards.seasonalReward(data)
	-- İşaret önce yazılır; tekrarlanan ya da gecikmiş istek ikinci ödülü alamaz.
	goal.claimed = true
	PlayerDataService.addCash(player, amount, "season")
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	Metrics.increment("SeasonalGoalsClaimed")
	return true, `Mevsim hedefi tamamlandı: +{FarmMath.formatMoney(amount)}`
end

-- Altın hayvan: parlayan hayvan sunucuda yeniden hesaplanır; ödül aynı pencerede yalnızca bir kez verilir
function EngagementService.tryClaimGolden(player: Player): (boolean, string?)
	if not RateLimiter.allow(player, "claimGolden", 0.5) then
		return false, nil
	end
	local data = ready(player)
	if not data then
		return false, "Çiftliğin henüz hazır değil"
	end
	local event = Golden.current(data, player.UserId, nowSeconds())
	if not event then
		return false, "Altın hayvan artık burada değil"
	end
	-- Hayvanın konumu istemcide; sunucu yalnızca oyuncunun kendi adasında olduğunu doğrular.
	if not PlotService.isNearPlot(player, Config.GOLDEN.claimRadius) then
		return false, "Altın hayvana yeterince yakın değilsin"
	end
	-- İşaret önce yazılır; tekrarlanan ya da gecikmiş istek ikinci ödülü alamaz.
	data.golden = { key = event.cycle }
	PlayerDataService.addCash(player, event.reward, "golden")
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	Metrics.increment("GoldenAnimalsClaimed")
	return true, `Altın hayvan yakalandı: +{FarmMath.formatMoney(event.reward)}`
end

-- Mevsim hedefini her oyuncu için hazır tut ve ilerleme değiştikçe (en fazla birkaç sn'de bir) client'a bildir:
-- kazanç ilerlemesi sunucuda birikir, client yalnızca yapısal durum paketlerinde yeni değeri görür.
local SEASONAL_REFRESH_SECONDS = 5

local function refreshSeasonal(player: Player, lastSent: { [Player]: string })
	local data = ready(player)
	if not data then
		return
	end
	local now = nowSeconds()
	local created = Rewards.ensureSeasonal(data, now)
	if data.adminForce and data.adminForce.completeSeason then
		data.adminForce.completeSeason = nil
		Rewards.forceCompleteSeasonal(data, now)
		lastSent[player] = nil -- ilerleme imzası değişti: durumu hemen it
	end
	local goal = data.seasonal
	-- İlerleme hedefin %1'lik adımlarına yuvarlanır: "earned" her saniye değişse de her seferinde tam pushState gitmez.
	local signature = ""
	if goal then
		local percent =
			math.floor(math.min(Rewards.seasonalProgress(data, goal), goal.target) * 100 / math.max(goal.target, 1))
		signature = `{goal.key}|{goal.claimed}|{percent}`
	end
	if created or lastSent[player] ~= signature then
		lastSent[player] = signature
		PlayerDataService.pushState(player)
	end
end

function EngagementService.init()
	local lastSent: { [Player]: string } = {}
	game:GetService("Players").PlayerRemoving:Connect(function(player: Player)
		lastSent[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(SEASONAL_REFRESH_SECONDS)
			for _, player in game:GetService("Players"):GetPlayers() do
				local ok, err = pcall(function(): boolean
					refreshSeasonal(player, lastSent)
					return true
				end)
				if not ok then
					warn(`[Engagement] Mevsim hedefi güncellenemedi: {err}`)
				end
			end
		end
	end)
	Remotes.get("RequestClaimGolden").OnServerEvent
		:Connect(function(player: Player, _value: unknown, requestId: unknown, expectedFarmId: unknown)
			if not RateLimiter.acceptRequest(player, requestId) then
				return
			end
			local data = PlayerDataService.tryGet(player)
			if not data or expectedFarmId ~= data.activeMainFarmId then
				return
			end
			local ok, message = EngagementService.tryClaimGolden(player)
			RequestGuard.reply(player, requestId, ok, message)
		end)
	Remotes.get("RequestClaimSeasonal").OnServerEvent
		:Connect(function(player: Player, _value: unknown, requestId: unknown)
			if not RateLimiter.acceptRequest(player, requestId) then
				return
			end
			local ok, message = EngagementService.tryClaimSeasonal(player)
			RequestGuard.reply(player, requestId, ok, message)
		end)
	Remotes.get("RequestClaimDaily").OnServerEvent:Connect(function(player: Player, _value: unknown, requestId: unknown)
		if not RateLimiter.acceptRequest(player, requestId) then
			return
		end
		local ok, message = EngagementService.tryClaimDaily(player)
		RequestGuard.reply(player, requestId, ok, message)
	end)
	Remotes.get("RequestClaimAchievement").OnServerEvent
		:Connect(function(player: Player, achievementId: unknown, requestId: unknown)
			if not RateLimiter.acceptRequest(player, requestId) then
				return
			end
			local ok, message = EngagementService.tryClaimAchievement(player, achievementId)
			RequestGuard.reply(player, requestId, ok, message)
		end)
end

return EngagementService
