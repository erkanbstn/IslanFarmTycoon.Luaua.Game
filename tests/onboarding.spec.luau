--!strict
-- İlk adımlar: adım sırası, kıdemli atlama eşikleri ve 4. adımın yalnızca başlatılabilir parti varken çıkması (saf, gerçek Config/FarmMath).
return function(OnboardingSteps: any, Config: any, FarmMath: any)
	local function newSave(): any
		local data: any = {
			cash = 0,
			stored = 0,
			purchased = {},
			animals = {},
			barnLevel = 1,
			unlockedIslands = {},
			unlockedZones = {},
			production = {},
			activeMainFarmId = "1",
		}
		FarmMath.applyDerived(data)
		return data
	end
	local function fillStarter(data: any)
		local capacity = FarmMath.getZoneCapacity(data, "starter")
		for index = #data.animals + 1, capacity do
			table.insert(
				data.animals,
				{ uid = `a{index}`, animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" }
			)
		end
	end

	-- 1-3: temel adımlar sırayla ilerler
	local save = newSave()
	assert(OnboardingSteps.TOTAL == 4, "dört adım")
	assert(OnboardingSteps.stepFor(save) == 1, "yeni oyuncu 1. adımda")
	save.cash = 0
	assert(
		OnboardingSteps.stepFor(save) == 1,
		"ilk hayvan adımı para şartı aramaz (Pazar parasız da işaretlenir)"
	)
	save.cash = Config.STARTING_CASH
	table.insert(save.animals, { uid = "a1", animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" })
	assert(OnboardingSteps.stepFor(save) == 2, "hayvan alındı: parayı topla")
	save.lifetimeEarned = 50
	assert(OnboardingSteps.stepFor(save) == 3, "para toplandı: ilk yükseltme")

	-- İlk yükseltme alınınca, başlatılabilir tesis yoksa öğretici biter
	save.purchased.barn_2 = true
	assert(OnboardingSteps.stepFor(save) == 0, "yükseltme alındı, tesis yok: öğretici biter")
	assert(
		OnboardingSteps.basicsDone(4) and OnboardingSteps.basicsDone(0) and not OnboardingSteps.basicsDone(3),
		"temel adımlar bitti mi"
	)

	-- 1,5 bin kazanç temel adımlarını atlar; kıdemli hesap hiç yönlendirilmez
	local mid = newSave()
	mid.lifetimeEarned = OnboardingSteps.SKIP_BASICS_EARNED
	assert(OnboardingSteps.stepFor(mid) == 0, "temel adımları geçmiş hesapta tesis yoksa adım yok")
	mid.lifetimeEarned = OnboardingSteps.SKIP_BASICS_EARNED - 1
	assert(OnboardingSteps.stepFor(mid) == 1, "eşiğin hemen altında temel adımlar sürer")
	local veteran = newSave()
	veteran.lifetimeEarned = OnboardingSteps.SKIP_ALL_EARNED
	assert(OnboardingSteps.stepFor(veteran) == 0, "kıdemli hesap atlanır")
	veteran.lifetimeEarned = OnboardingSteps.SKIP_ALL_EARNED - 1
	local vRecipe = Config.PRODUCTION_RECIPES.packed_milk
	veteran.purchased[vRecipe.upgradeId] = true
	veteran.unlockedIslands[vRecipe.island] = true
	fillStarter(veteran)
	assert(OnboardingSteps.stepFor(veteran) == 4, "eşiğin hemen altında üretim adımı çıkar")

	-- Bozuk kazanç değeri yeni hesap gibi yönlendirilir (NaN/negatif/yanlış tür), çökmez
	for _, bad in { 0 / 0, -5, "x", math.huge * 0, -math.huge } do
		local corrupt = newSave()
		corrupt.lifetimeEarned = bad
		assert(OnboardingSteps.stepFor(corrupt) == 1, "bozuk kazanç sıfır sayılır")
	end
	local noEarned = newSave()
	noEarned.lifetimeEarned = nil
	assert(OnboardingSteps.stepFor(noEarned) == 1, "kazanç alanı yoksa yeni hesap")

	-- 4: tesis kurulu ve hiç parti yoksa
	local recipe = Config.PRODUCTION_RECIPES.packed_milk
	local factory = newSave()
	factory.lifetimeEarned = OnboardingSteps.SKIP_BASICS_EARNED
	factory.purchased[recipe.upgradeId] = true
	factory.unlockedIslands[recipe.island] = true
	assert(OnboardingSteps.ownsFactory(factory), "tesis kurulu")
	assert(OnboardingSteps.stepFor(factory) == 0, "yetişkinsiz tesis üretim öğreticisini açmaz")
	fillStarter(factory)
	assert(OnboardingSteps.stepFor(factory) == 4, "yeterli yetişkin varsa ilk parti adımı")
	assert(OnboardingSteps.readyFactory(factory, 1700000000) == recipe.id, "gerçek başlatılabilir tesis seçilir")
	assert(OnboardingSteps.stepFor(factory, { skipped = true }) == 0, "atlama bütün yönlendirmeyi kapatır")
	assert(OnboardingSteps.stepFor(newSave(), { skipped = true }) == 0, "atlama yeni oyuncuyu da durdurur")
	assert(OnboardingSteps.stepFor(newSave(), { skipped = false }) == 1, "tekrar göster adımı durumdan türetir")
	factory.production[recipe.id] = { readyAt = 1, startedAt = 0 }
	assert(OnboardingSteps.stepFor(factory) == 0, "parti başlayınca adım biter")
	-- Çalışan başka parti varken bekleyen ikinci tesis adımı yeniden açmaz
	local second = Config.PRODUCTION_ORDER[2]
	assert(second ~= nil and second ~= recipe.id, "ikinci tarif var")
	factory.production = { [second] = { readyAt = 1, startedAt = 0 } }
	assert(OnboardingSteps.stepFor(factory) == 0, "herhangi bir parti çalışıyorsa üretim öğrenilmiştir")
	factory.production = {}
	-- Tamamlanma kalıcıdır: sunucu ilk partide tutorialDone yazar, istemci bunu skipped olarak geçirir
	assert(
		OnboardingSteps.stepFor(factory, { skipped = true }) == 0,
		"teslim sonrası öğretici kayıtlı işaretle geri dönmez"
	)
end
