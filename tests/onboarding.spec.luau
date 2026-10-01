--!strict
-- İlk adımlar: adım sırası, kıdemli atlama eşikleri ve 4-6. adımların yalnızca yapılabilir olduğunda çıkması (saf, gerçek Config/FarmMath).
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
	assert(OnboardingSteps.stepFor(save) == 1, "yeni oyuncu 1. adımda")
	table.insert(save.animals, { uid = "a1", animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" })
	assert(OnboardingSteps.stepFor(save) == 2, "hayvan alındı: parayı topla")
	save.lifetimeEarned = 50
	assert(OnboardingSteps.stepFor(save) == 3, "para toplandı: ilk yükseltme")

	-- Tek yükseltme artık kıdemli saymaz: 4. adıma geçer
	save.purchased.barn_2 = true
	assert(OnboardingSteps.stepFor(save) == 4, "ilk yükseltme alındı: Yol Haritası")
	assert(OnboardingSteps.stepFor(save, { roadmapOpened = true }) ~= 4, "Yol Haritası açılınca 4. adım biter")

	-- 1,5 bin kazanç temel adımları atlar ama 4. adımı atlamaz
	local mid = newSave()
	mid.lifetimeEarned = OnboardingSteps.SKIP_BASICS_EARNED
	assert(OnboardingSteps.stepFor(mid) == 4, "1,5 bin kazanç yalnızca 1-3'ü atlar")
	assert(
		OnboardingSteps.basicsDone(4) and OnboardingSteps.basicsDone(0) and not OnboardingSteps.basicsDone(3),
		"temel adımlar bitti mi"
	)

	-- Çok kazanmış hesap hiç yönlendirilmez
	local veteran = newSave()
	veteran.lifetimeEarned = OnboardingSteps.SKIP_ALL_EARNED
	assert(OnboardingSteps.stepFor(veteran) == 0, "kıdemli hesap atlanır")

	-- 5: yapılabilir bir genişletme varsa
	local roomy = newSave()
	roomy.lifetimeEarned = OnboardingSteps.SKIP_BASICS_EARNED
	roomy.purchased.barn_2 = true
	fillStarter(roomy)
	local id, cost = OnboardingSteps.cheapestExpansion(roomy)
	assert(id ~= nil and cost > 0 and cost < math.huge, "dolu ağılda genişletme alınabilir")
	assert(OnboardingSteps.stepFor(roomy, { roadmapOpened = true }) == 5, "ilk genişletme adımı")
	roomy.expansions = { [id :: string] = 1 }
	assert(OnboardingSteps.stepFor(roomy) == 0, "genişletme alınınca 4 ve 5 biter")

	-- Genişletme yoksa 5. adım atlanır
	local empty = newSave()
	empty.lifetimeEarned = OnboardingSteps.SKIP_BASICS_EARNED
	assert(OnboardingSteps.stepFor(empty, { roadmapOpened = true }) == 0, "yapılabilir genişletme yoksa adım yok")

	-- 6: tesis kurulu ve hiç parti yoksa
	local recipe: any = nil
	for _, candidate in Config.PRODUCTION_RECIPES do
		recipe = recipe or candidate
	end
	local factory = newSave()
	factory.lifetimeEarned = OnboardingSteps.SKIP_BASICS_EARNED
	factory.purchased[recipe.upgradeId] = true
	factory.unlockedIslands[recipe.island] = true
	factory.expansions = { starter = 1 }
	assert(OnboardingSteps.ownsFactory(factory), "tesis kurulu")
	assert(OnboardingSteps.stepFor(factory) == 6, "ilk parti adımı")
	factory.production[recipe.id] = { readyAt = 1, startedAt = 0 }
	assert(OnboardingSteps.stepFor(factory) == 0, "parti başlayınca adım biter")
end
