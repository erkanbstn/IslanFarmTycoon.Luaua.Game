--!strict
-- İlk adımlar (yeni oyuncu yönlendirmesi): hangi adımda olunduğu kayıt durumundan türetilir.
--   1) İlk hayvanı al  2) Parayı topla  3) İlk yükseltmeyi al  4) Üretimde ilk partiyi başlat
--   5) İlk siparişi teslim et  6) İlk geliştirmeyi al  7) İlk eşyayı al  8) İlk rebirth'e hazırlan
-- Adımlar sırayla ilerler: sıradaki adım, kayıtlı aşamadan (`tutorialStage`) sonraki ilk "bekleyen" adımdır. Bir adımın özelliği
-- henüz yoksa (ürün merkezi, geliştirilebilir yapı, yetecek para...) adım bekletmez, atlanır ve hazır olunca geri gelir.
-- Kayıt iki alan taşır (ikisi de isteğe bağlı, hesap düzeyi):
--   `tutorialStage`  yalnız artan "tamamlanan en yüksek adım" (0..TOTAL); tamamlanan adım bir daha görünmez (rebirth, satış,
--                    tüketilen eşya gibi durum değişse de). Yazan: sunucu (Modules/TutorialProgress, OnboardingSteps.reachedStage).
--   `tutorialDone`   atla/bitti işareti (Modules/Preferences, `progress.skipped`); son adım bitince ya da oyuncu atlayınca true.
-- Saf mantıktır (arayüz Hud/Onboarding.luau'da).

local Config = require(script.Parent.Parent:WaitForChild("Config"))
local FarmMath = require(script.Parent:WaitForChild("FarmMath"))
local Progression = require(script.Parent:WaitForChild("Progression"))

local OnboardingSteps = {}

export type Progress = { skipped: boolean?, stage: number? }

-- Bu kadar kazanmış hesap temel adımları (1-3) artık istemez (başka çiftlik açanlar dahil: kazanç hesap düzeyindedir).
-- Sayılar tek yerden gelir (Config.ONBOARDING): kayıt çözücü eski kayıtları aynı eşikle öğreticiden çıkarır.
OnboardingSteps.SKIP_BASICS_EARNED = Config.ONBOARDING.SKIP_BASICS_EARNED
-- Bu kadar kazanmış hesap hiçbir adım istemez
OnboardingSteps.SKIP_ALL_EARNED = Config.ONBOARDING.SKIP_ALL_EARNED
OnboardingSteps.TOTAL = Config.ONBOARDING.TOTAL_STEPS

local function hasAny(map: { [string]: any }?): boolean
	return map ~= nil and next(map) ~= nil
end

local function hasAnyPositive(map: { [string]: any }?): boolean
	if map == nil then
		return false
	end
	for _, value in map do
		if typeof(value) == "number" and value > 0 then
			return true
		end
	end
	return false
end

-- Bozuk (sonlu olmayan/negatif) kazanç sıfır sayılır; yeni hesap gibi yönlendirilir
local function cleanEarned(save: any): number
	local earned = save.lifetimeEarned
	if typeof(earned) ~= "number" or earned ~= earned or earned < 0 then
		return 0
	end
	return earned
end

-- Kayıtlı aşama: sonlu tam sayı 0..TOTAL; bozuk değer 0
function OnboardingSteps.clampStage(value: unknown): number
	if typeof(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, OnboardingSteps.TOTAL)
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

-- Ürün merkezi (ahır deposuna ürün veren tesis) kurulu mu: sipariş adımı yalnızca bununla anlamlıdır
function OnboardingSteps.ownsGoodsCenter(save: any): boolean
	for _, recipe in Config.PRODUCTION_RECIPES do
		if recipe.output == "goods" and save.purchased[recipe.upgradeId] and save.unlockedIslands[recipe.island] then
			return true
		end
	end
	return false
end

-- Hayvan alındı, para toplandı ve ilk yükseltme alındı mı (kazanç eşiğini aşan hesap da geçmiş sayılır)
local function basicsComplete(save: any, earned: number): boolean
	if earned >= OnboardingSteps.SKIP_BASICS_EARNED then
		return true
	end
	return #save.animals > Config.STARTING_COW_COUNT and earned > 0 and hasAny(save.purchased)
end

local function ownsAnyItem(save: any): boolean
	local inventory = save.inventory
	if typeof(inventory) ~= "table" then
		return false
	end
	for _, owned in inventory.items or {} do
		if owned == true then
			return true
		end
	end
	return hasAny(inventory.equipped)
end

-- Nakitle alınabilen en ucuz eşyanın fiyatı (Config.isCashItem); eşya yoksa nil
local cheapestCash: number? = nil
local function cheapestCashItemPrice(): number?
	if cheapestCash == nil then
		local best = math.huge
		for _, item in Config.ITEMS do
			if Config.isCashItem(item) and item.price < best then
				best = item.price
			end
		end
		cheapestCash = best
	end
	return if cheapestCash == math.huge then nil else cheapestCash
end

-- Parası yeten ilk geliştirilebilir yapı (BUILD_ORDER sırasıyla); yoksa nil
function OnboardingSteps.affordableExpansion(save: any): string?
	for _, targetId in Config.BUILD_ORDER do
		local status, _, cost = FarmMath.getExpansionStatus(save, targetId)
		if status == "available" and cost <= save.cash then
			return targetId
		end
	end
	return nil
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

local function rebirthCount(save: any): number
	local state = save.progression
	return if typeof(state) == "table" and typeof(state.count) == "number" then state.count else 0
end

-- Adım şu an yapılabilir ve henüz yapılmamış mı (kayıtlı aşama dışında; sıralamayı stepFor yapar)
local function pending(step: number, save: any, earned: number, now: number): boolean
	if step == 1 then
		return earned < OnboardingSteps.SKIP_BASICS_EARNED and #save.animals <= Config.STARTING_COW_COUNT
	elseif step == 2 then
		return earned < OnboardingSteps.SKIP_BASICS_EARNED and earned <= 0
	elseif step == 3 then
		return earned < OnboardingSteps.SKIP_BASICS_EARNED and not hasAny(save.purchased)
	elseif step == 4 then
		-- Çalışan bir parti varsa üretim zaten öğrenilmiştir
		return not hasAny(save.production) and OnboardingSteps.readyFactory(save, now) ~= nil
	end
	-- 5-8: temel adımlar bittikten sonra
	if not basicsComplete(save, earned) then
		return false
	end
	if step == 5 then
		-- Ürün merkezi yoksa ya da teslime hazır sipariş yoksa adım atlanır (ürün biriktikçe geri gelir)
		local completed = if save.contracts then save.contracts.completed else 0
		return completed == 0
			and OnboardingSteps.ownsGoodsCenter(save)
			and FarmMath.getReadyContractCount(save, now, 0) > 0
	elseif step == 6 then
		return not hasAnyPositive(save.expansions) and OnboardingSteps.affordableExpansion(save) ~= nil
	elseif step == 7 then
		local price = cheapestCashItemPrice()
		return price ~= nil and not ownsAnyItem(save) and save.cash >= price
	elseif step == 8 then
		return rebirthCount(save) == 0 and Progression.canRebirth(save)
	end
	return false
end

-- 0 = bitti / gerekmiyor; 1..TOTAL = sıradaki adım
function OnboardingSteps.stepFor(save: any, progress: Progress?, now: number?): number
	if progress and progress.skipped then
		return 0
	end
	local earned = cleanEarned(save)
	if earned >= OnboardingSteps.SKIP_ALL_EARNED then
		return 0
	end
	local at = now or os.time()
	for step = OnboardingSteps.clampStage(if progress then progress.stage else nil) + 1, OnboardingSteps.TOTAL do
		if pending(step, save, earned, at) then
			return step
		end
	end
	return 0
end

-- Adım gerçekten tamamlandı mı (durumdan; kayıtlı aşamadan bağımsız)
local function completed(step: number, save: any, earned: number): boolean
	if step == 1 then
		return #save.animals > Config.STARTING_COW_COUNT
	elseif step == 2 then
		return earned > 0
	elseif step == 3 then
		return hasAny(save.purchased)
	elseif step == 4 then
		return hasAny(save.production)
	elseif step == 5 then
		return save.contracts ~= nil and save.contracts.completed > 0
	elseif step == 6 then
		return hasAnyPositive(save.expansions)
	elseif step == 7 then
		return ownsAnyItem(save)
	end
	return rebirthCount(save) > 0
end

-- Gözlenen en yüksek aşama (yalnız artar): kayıtlı aşama, tamamlanan en yüksek adım ve kazanç eşikleri.
-- Sunucu bunu kayda yazar (Modules/TutorialProgress); adım atlayan oyuncu önceki adımları da geçmiş sayılır.
function OnboardingSteps.reachedStage(save: any): number
	local stage = OnboardingSteps.clampStage(save.tutorialStage)
	local earned = cleanEarned(save)
	if earned >= OnboardingSteps.SKIP_ALL_EARNED then
		return OnboardingSteps.TOTAL
	end
	if earned >= OnboardingSteps.SKIP_BASICS_EARNED then
		stage = math.max(stage, 3)
	end
	for step = OnboardingSteps.TOTAL, stage + 1, -1 do
		if completed(step, save, earned) then
			return step
		end
	end
	return stage
end

-- Temel adımlar (1-3) bitti mi (4. adım ya da sonrası, ya da hiç adım kalmamış)
function OnboardingSteps.basicsDone(step: number): boolean
	return step == 0 or step >= 4
end

return OnboardingSteps
