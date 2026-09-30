--!strict
-- Günlük ödül ve başarım hesapları (saf, paylaşılan: sunucu ödülü verir, client durumu gösterir).

local Config = require(script.Parent.Parent:WaitForChild("Config"))
local FarmMath = require(script.Parent:WaitForChild("FarmMath"))

local Rewards = {}

export type SeasonalGoal = { key: number, progress: number, target: number, base: number, claimed: boolean }

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

---------------------------------------------------------------------------
-- Mevsim hedefi
---------------------------------------------------------------------------

-- Mevsim numarası sunucu saatinden türer (Environment.seasonIndexAt ile aynı döngü); yönetici mevsim zorlaması etkilemez.
function Rewards.seasonNumber(now: number): number
	return math.floor(now / Config.SEASON_SECONDS)
end

function Rewards.seasonalDef(number: number): (any, Config.SeasonConfig)
	local season = Config.SEASONS[number % #Config.SEASONS + 1]
	return Config.SEASONAL_GOALS[season.id], season
end

local function roundSignificant(value: number): number
	if value < 10 then
		return math.max(1, math.floor(value + 0.5))
	end
	local step = 10 ^ (math.floor(math.log10(value)) - 1)
	return math.floor(value / step + 0.5) * step
end

-- Yeni mevsim hedefi: "earned" için hedef o anki gelire göre sabitlenir, başlangıç kazancı kaydedilir.
function Rewards.newSeasonalGoal(save: any, number: number): SeasonalGoal
	local def = Rewards.seasonalDef(number)
	local target: number
	if def.metric == "earned" then
		local income = FarmMath.computeIncomePerSecond(save)
		target = math.max(def.minTarget or 1, roundSignificant(income * Config.SEASON_SECONDS * (def.factor or 0.3)))
	else
		target = def.target or 1
	end
	return {
		key = number,
		progress = 0,
		target = target,
		base = save.lifetimeEarned or 0,
		claimed = false,
	}
end

-- Kayıtlı hedef bu mevsime aitse o, değilse (kaydedilmemiş) yeni bir hedef. İkinci değer: kayıtlı mı.
function Rewards.seasonalGoal(save: any, now: number): (SeasonalGoal, boolean)
	local number = Rewards.seasonNumber(now)
	local stored = save.seasonal
	if stored and stored.key == number then
		return stored, true
	end
	return Rewards.newSeasonalGoal(save, number), false
end

-- Hedefe yönelik ilerleme (hedefi aşmaz): kazanç canlı hesaplanır, yatırım sayacı kayıttadır.
function Rewards.seasonalProgress(save: any, goal: SeasonalGoal): number
	local def = Rewards.seasonalDef(goal.key)
	if def.metric == "earned" then
		return math.clamp((save.lifetimeEarned or 0) - goal.base, 0, goal.target)
	end
	return math.clamp(goal.progress, 0, goal.target)
end

function Rewards.seasonalClaimable(save: any, now: number): boolean
	local goal, stored = Rewards.seasonalGoal(save, now)
	return stored and not goal.claimed and Rewards.seasonalProgress(save, goal) >= goal.target
end

-- Ödül alındığı andaki gelire göre hesaplanır
function Rewards.seasonalReward(save: any): number
	local income = FarmMath.computeIncomePerSecond(save)
	return math.max(Config.SEASONAL_MIN_REWARD, math.floor(income * Config.SEASONAL_REWARD_SECONDS))
end

-- Sunucu: bu mevsimin hedefi kayıtlı değilse oluşturur. Yeni oluştuysa true.
function Rewards.ensureSeasonal(save: any, now: number): boolean
	local goal, stored = Rewards.seasonalGoal(save, now)
	if stored then
		return false
	end
	save.seasonal = goal
	return true
end

-- Sunucu: başarılı bir yatırım (hayvan, yükseltme, ırk, alan genişletme) sayılır; yalnızca "invest" mevsiminde işler.
function Rewards.recordInvest(save: any, now: number)
	Rewards.ensureSeasonal(save, now)
	local goal = save.seasonal
	if goal and not goal.claimed and Rewards.seasonalDef(goal.key).metric == "invest" then
		goal.progress = math.min(goal.target, goal.progress + 1)
	end
end

function Rewards.isComplete(save: any, achievement: Config.AchievementConfig): boolean
	return Rewards.progress(save, achievement) >= achievement.target
end

-- Alınabilir (tamamlanmış ve ödülü henüz alınmamış) başarım sayısı; `now` verilirse tamamlanmış mevsim hedefi de sayılır
function Rewards.claimableCount(save: any, now: number?): number
	local count = if now and Rewards.seasonalClaimable(save, now) then 1 else 0
	for _, achievement in Config.ACHIEVEMENTS do
		if not (save.achievements and save.achievements[achievement.id]) and Rewards.isComplete(save, achievement) then
			count += 1
		end
	end
	return count
end

return Rewards
