--!strict
-- İlk adımlar (yeni oyuncu yönlendirmesi): hangi adımda olunduğu kayıt durumundan türetilir.
--   1) İlk hayvanı al  2) Parayı topla  3) İlk yükseltmeyi al  4) Üretimde ilk partiyi başlat
-- Adımlar sırayla ilerler; 4. adım yalnızca gerçekten başlatılabilir bir parti varken çıkar.
-- Kapatma tercihi (`progress.skipped`) hesaba kayıtlıdır (Modules/Preferences "tutorialDone"); sunucu ilk üretim
-- partisinde de aynı işareti yazar, böylece tamamlanan öğretici yeniden girişte geri gelmez. Saf mantıktır (arayüz Onboarding.luau'da).

local Config = require(script.Parent.Parent:WaitForChild("Config"))
local FarmMath = require(script.Parent:WaitForChild("FarmMath"))

local OnboardingSteps = {}

export type Progress = { skipped: boolean? }

-- Bu kadar kazanmış hesap temel adımları (1-3) artık istemez (başka çiftlik açanlar dahil: kazanç hesap düzeyindedir)
OnboardingSteps.SKIP_BASICS_EARNED = 1500
-- Bu kadar kazanmış hesap üretim adımını da istemez
OnboardingSteps.SKIP_ALL_EARNED = 20000
OnboardingSteps.TOTAL = 4

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

-- 0 = bitti / gerekmiyor; 1..4 = sıradaki adım
function OnboardingSteps.stepFor(save: any, progress: Progress?): number
	if progress and progress.skipped then
		return 0
	end
	-- Bozuk (sonlu olmayan/negatif) kazanç sıfır sayılır; yeni hesap gibi yönlendirilir
	local earned = save.lifetimeEarned
	if typeof(earned) ~= "number" or earned ~= earned or earned < 0 then
		earned = 0
	end
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
	-- Çalışan bir parti varsa üretim zaten öğrenilmiştir
	if not hasAny(save.production) and OnboardingSteps.readyFactory(save, os.time()) ~= nil then
		return 4
	end
	return 0
end

-- Yönlendirme yalnızca gerçekten başlatılabilir partiye gider; kurulu tesis tek başına yeterli değildir.
function OnboardingSteps.readyFactory(save: any, now: number): string?
	for _, id in Config.PRODUCTION_ORDER do
		local recipe = Config.PRODUCTION_RECIPES[id]
		if
			save.purchased[recipe.upgradeId]
			and save.unlockedIslands[recipe.island]
			and not save.production[id]
			and FarmMath.countProductionAdults(save, recipe, now) >= recipe.requiredAdults
			and save.cash >= FarmMath.getFacilityCost(save, recipe)
			and (
				recipe.output ~= "goods"
				or (
					recipe.goodsId ~= nil
					and FarmMath.getGoodsSpace(save, recipe.goodsId)
						>= math.min(FarmMath.previewGoodsYield(save, recipe, now), FarmMath.getGoodsCap(save))
				)
			)
		then
			return id
		end
	end
	return nil
end

-- Temel adımlar (1-3) bitti mi (4. adım ya da hiç adım kalmamış)
function OnboardingSteps.basicsDone(step: number): boolean
	return step == 0 or step >= 4
end

return OnboardingSteps
