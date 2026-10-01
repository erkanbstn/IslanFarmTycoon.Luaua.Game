--!strict
-- İlk adımlar (yeni oyuncu yönlendirmesi): hangi adımda olunduğu kayıt durumundan türetilir, kayıt alanı yoktur.
--   1) İlk hayvanı al  2) Parayı topla  3) İlk yükseltmeyi al
--   4) Yol Haritası'nı aç  5) İlk genişletmeyi al  6) Üretimde ilk partiyi başlat
-- Adımlar sırayla ilerler; 4-6 yalnızca yapılabilir olduğunda çıkar. Saf mantıktır (arayüz, Onboarding.luau'da).

local Config = require(script.Parent.Parent:WaitForChild("Config"))
local FarmMath = require(script.Parent:WaitForChild("FarmMath"))

local OnboardingSteps = {}

export type Progress = { roadmapOpened: boolean? }

-- Bu kadar kazanmış hesap temel adımları (1-3) artık istemez (başka çiftlik açanlar dahil: kazanç hesap düzeyindedir)
OnboardingSteps.SKIP_BASICS_EARNED = 1500
-- Bu kadar kazanmış hesap 4-6. adımları da istemez
OnboardingSteps.SKIP_ALL_EARNED = 20000
OnboardingSteps.TOTAL = 6

local function hasAny(map: { [string]: any }?): boolean
	return map ~= nil and next(map) ~= nil
end

-- Kurulu üretim tesisi var mı (yükseltme alınmış ve adası açık)
function OnboardingSteps.ownsFactory(save: any): boolean
	for _, recipe in Config.PRODUCTION_RECIPES do
		if save.purchased[recipe.upgradeId] and save.unlockedIslands[recipe.island] then
			return true
		end
	end
	return false
end

-- Alınabilir en ucuz yapı geliştirmesi: (kimlik, maliyet); yoksa nil
function OnboardingSteps.cheapestExpansion(save: any): (string?, number)
	local bestId: string? = nil
	local bestCost = math.huge
	for _, targetId in Config.BUILD_ORDER do
		local status, _, cost = FarmMath.getExpansionStatus(save, targetId)
		if status == "available" and cost < bestCost then
			bestId, bestCost = targetId, cost
		end
	end
	return bestId, bestCost
end

-- 0 = bitti / gerekmiyor; 1..6 = sıradaki adım
function OnboardingSteps.stepFor(save: any, progress: Progress?): number
	local earned = save.lifetimeEarned or 0
	if earned >= OnboardingSteps.SKIP_ALL_EARNED then
		return 0
	end
	if earned < OnboardingSteps.SKIP_BASICS_EARNED then
		if #save.animals <= Config.STARTING_COW_COUNT then
			return 1
		end
		if earned <= 0 then
			return 2
		end
		if not hasAny(save.purchased) then
			return 3
		end
	end
	local expanded = hasAny(save.expansions)
	if not expanded and not (progress and progress.roadmapOpened) then
		return 4
	end
	if not expanded and OnboardingSteps.cheapestExpansion(save) ~= nil then
		return 5
	end
	if OnboardingSteps.ownsFactory(save) and not hasAny(save.production) then
		return 6
	end
	return 0
end

-- Temel adımlar (1-3) bitti mi (4-6 ya da hiç adım kalmamış)
function OnboardingSteps.basicsDone(step: number): boolean
	return step == 0 or step >= 4
end

return OnboardingSteps
