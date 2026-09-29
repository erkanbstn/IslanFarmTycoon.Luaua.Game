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

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
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
	PlayerDataService.addCash(player, amount)
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
	PlayerDataService.addCash(player, found.reward)
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	Metrics.increment("AchievementsClaimed")
	return true, `Başarım tamamlandı: +{FarmMath.formatMoney(found.reward)}`
end

local function respond(player: Player, requestId: unknown, ok: boolean, message: string?)
	if not ok and message == nil then
		if typeof(requestId) ~= "number" or not RateLimiter.allow(player, "purchaseThrottleReply", 0.5) then
			return
		end
		message = "Çok hızlı işlem yapıyorsun; biraz bekle."
	end
	if message then
		if typeof(requestId) == "number" then
			Remotes.get("PurchaseResult"):FireClient(player, requestId, ok, message)
		else
			Remotes.get("Notify"):FireClient(player, message, if ok then "success" else "error")
		end
	end
end

function EngagementService.init()
	Remotes.get("RequestClaimDaily").OnServerEvent:Connect(function(player: Player, _value: unknown, requestId: unknown)
		if not RateLimiter.acceptRequest(player, requestId) then
			return
		end
		local ok, message = EngagementService.tryClaimDaily(player)
		respond(player, requestId, ok, message)
	end)
	Remotes.get("RequestClaimAchievement").OnServerEvent
		:Connect(function(player: Player, achievementId: unknown, requestId: unknown)
			if not RateLimiter.acceptRequest(player, requestId) then
				return
			end
			local ok, message = EngagementService.tryClaimAchievement(player, achievementId)
			respond(player, requestId, ok, message)
		end)
end

return EngagementService
