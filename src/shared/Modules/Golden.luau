--!strict
-- Altın hayvan (rastgele olay): pencere ve hangi hayvanın parladığı oyuncu kimliği + döngü numarasından türer
-- (Merchant.rand). Sunucu ödülü doğrular ve verir, client aynı hesapla hayvanı vurgular. Yalnızca alınan pencerenin
-- döngüsü `save.golden` içinde tutulur.

local Config = require(script.Parent.Parent:WaitForChild("Config"))
local FarmMath = require(script.Parent:WaitForChild("FarmMath"))
local Merchant = require(script.Parent:WaitForChild("Merchant"))

local Golden = {}

export type Event = { uid: string, animalId: string, cycle: number, endsAt: number, reward: number }

-- Bu oyuncunun bu döngüdeki penceresi: (cycle, startsAt, endsAt, active) ya da nil
local function window(
	userId: number,
	now: number
): { cycle: number, startsAt: number, endsAt: number, active: boolean }?
	local settings = Config.GOLDEN
	local cycle = math.floor(now / settings.cycleSeconds)
	if Merchant.rand(userId, cycle, 11) >= settings.chance then
		return nil
	end
	local offset = math.floor(Merchant.rand(userId, cycle, 12) * (settings.cycleSeconds - settings.windowSeconds))
	local startsAt = cycle * settings.cycleSeconds + offset
	local endsAt = startsAt + settings.windowSeconds
	return { cycle = cycle, startsAt = startsAt, endsAt = endsAt, active = now >= startsAt and now < endsAt }
end

Golden.window = window

-- Şu an parlayan hayvan: pencere açık, bu döngüde ödül alınmamış ve açık bölgede yetişkin hayvan var.
function Golden.current(save: any, userId: number, now: number): Event?
	-- Test aracı: yönetici pencereyi zorlayabilir (save.adminForce yalnızca çalışma anında vardır, kaydedilmez)
	local forcedUntil = if save.adminForce then save.adminForce.goldenUntil else nil
	local span = if typeof(forcedUntil) == "number" and now < forcedUntil
		then {
			cycle = math.floor(now / Config.GOLDEN.cycleSeconds),
			startsAt = now,
			endsAt = forcedUntil,
			active = true,
		}
		else window(userId, now)
	if not span or not span.active then
		return nil
	end
	if save.golden and save.golden.key == span.cycle then
		return nil
	end
	local adults: { any } = {}
	for _, animal in save.animals do
		-- Tesiste çalışan hayvan görünmez: altın hayvan olamaz
		if
			animal.stage == "adult"
			and save.unlockedZones[animal.zoneId]
			and not FarmMath.isInProduction(animal, now)
		then
			table.insert(adults, animal)
		end
	end
	if #adults == 0 then
		return nil
	end
	-- Sıra kararlı olsun: kimliğe göre sırala
	table.sort(adults, function(a: any, b: any): boolean
		return a.uid < b.uid
	end)
	local chosen = adults[math.floor(Merchant.rand(userId, span.cycle, 13) * #adults) + 1]
	local reward = math.max(
		Config.GOLDEN.minReward,
		math.floor(FarmMath.computeIncomePerSecond(save, now) * Config.GOLDEN.rewardSeconds)
	)
	return { uid = chosen.uid, animalId = chosen.animalId, cycle = span.cycle, endsAt = span.endsAt, reward = reward }
end

return Golden
