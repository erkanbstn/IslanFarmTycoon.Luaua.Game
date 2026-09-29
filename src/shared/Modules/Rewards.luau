--!strict
-- Günlük ödül ve başarım hesapları (saf, paylaşılan: sunucu ödülü verir, client durumu gösterir).

local Config = require(script.Parent.Parent:WaitForChild("Config"))
local FarmMath = require(script.Parent:WaitForChild("FarmMath"))

local Rewards = {}

local SECONDS_PER_DAY = 86400

-- UTC gün numarası: yerel saate ve saat dilimine bağlı değildir.
function Rewards.dayIndex(now: number): number
	return math.floor(now / SECONDS_PER_DAY)
end

export type DailyStatus = { canClaim: boolean, streak: number, nextStreak: number }

-- daily: kayıttaki { day, streak } (yoksa nil). streak = şu an geçerli seri; nextStreak = alınırsa olacak seri.
function Rewards.dailyStatus(daily: { day: number, streak: number }?, now: number): DailyStatus
	local today = Rewards.dayIndex(now)
	local length = #Config.DAILY_REWARD_MULTIPLIERS
	if not daily then
		return { canClaim = true, streak = 0, nextStreak = 1 }
	end
	if daily.day >= today then
		return { canClaim = false, streak = daily.streak, nextStreak = daily.streak % length + 1 }
	end
	-- Dün alındıysa seri sürer (7. günden sonra baştan başlar); daha eskiyse seri bozulur.
	if daily.day == today - 1 then
		return { canClaim = true, streak = daily.streak, nextStreak = daily.streak % length + 1 }
	end
	return { canClaim = true, streak = 0, nextStreak = 1 }
end

-- Ödül: gelir x DAILY_MINUTES dakika x seri çarpanı; en az DAILY_MIN_REWARD.
function Rewards.dailyAmount(save: any, streak: number): number
	local multiplier = Config.DAILY_REWARD_MULTIPLIERS[math.clamp(streak, 1, #Config.DAILY_REWARD_MULTIPLIERS)]
	local income = FarmMath.computeIncomePerSecond(save)
	local base = math.max(income * Config.DAILY_MINUTES * 60, Config.DAILY_MIN_REWARD)
	return math.floor(base * multiplier)
end

-- Başarım metriğinin şu anki değeri
function Rewards.progress(save: any, achievement: Config.AchievementConfig): number
	local metric = achievement.metric
	if metric == "cows" then
		return FarmMath.countAnimals(save, "cow")
	elseif metric == "animals" then
		return #save.animals
	elseif metric == "islands" then
		local owned = FarmMath.countIslands(save)
		return owned
	elseif metric == "purchases" then
		local count = 0
		for _, owned in save.purchased do
			if owned then
				count += 1
			end
		end
		return count
	elseif metric == "earned" then
		return save.lifetimeEarned or 0
	elseif metric == "orders" then
		return save.ordersCompleted or 0
	end
	return 0
end

function Rewards.isComplete(save: any, achievement: Config.AchievementConfig): boolean
	return Rewards.progress(save, achievement) >= achievement.target
end

-- Alınabilir (tamamlanmış ve ödülü henüz alınmamış) başarım sayısı
function Rewards.claimableCount(save: any): number
	local count = 0
	for _, achievement in Config.ACHIEVEMENTS do
		if not (save.achievements and save.achievements[achievement.id]) and Rewards.isComplete(save, achievement) then
			count += 1
		end
	end
	return count
end

return Rewards
