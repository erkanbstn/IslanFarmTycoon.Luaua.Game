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

	-- Tek yükseltme artık kıdemli saymaz: 4. adıma geçer
	save.purchased.barn_2 = true
	assert(OnboardingSteps.stepFor(save) == 4, "ilk yükseltme alındı: Yol Haritası")
	assert(OnboardingSteps.stepFor(save, { roadmapOpened = true }) ~= 4, "Yol Haritası açılınca 4. adım biter")

	-- 1,5 bin kazanç temel adımları ve (oturuma özgü) Yol Haritası adımını atlar
	local mid = newSave()
	mid.lifetimeEarned = OnboardingSteps.SKIP_BASICS_EARNED
	assert(OnboardingSteps.stepFor(mid) ~= 4, "kıdemliye her girişte 4. adım çıkmaz")
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

	-- Genişletmeye para yetmiyorken hazır tesis varsa 6. adım öne geçer; para yetince 5
	local blocked = newSave()
	blocked.lifetimeEarned = OnboardingSteps.SKIP_BASICS_EARNED
	blocked.purchased.barn_2 = true
	fillStarter(blocked)
	local recipe0 = Config.PRODUCTION_RECIPES.packed_milk
	blocked.purchased[recipe0.upgradeId] = true
	blocked.unlockedIslands[recipe0.island] = true
	local _, expansionCost = OnboardingSteps.cheapestExpansion(blocked)
	blocked.cash = 0
	assert(OnboardingSteps.stepFor(blocked) == 6, "para yetmiyorken tesis 5. adımı geçer")
	blocked.cash = expansionCost
	assert(OnboardingSteps.stepFor(blocked) == 5, "para yetince 5. adım")

	-- 6: tesis kurulu ve hiç parti yoksa
	local recipe = Config.PRODUCTION_RECIPES.packed_milk
	local factory = newSave()
	factory.lifetimeEarned = OnboardingSteps.SKIP_BASICS_EARNED
	factory.purchased[recipe.upgradeId] = true
	factory.unlockedIslands[recipe.island] = true
	factory.expansions = { starter = 1 }
	assert(OnboardingSteps.ownsFactory(factory), "tesis kurulu")
	assert(OnboardingSteps.stepFor(factory) == 0, "yetişkinsiz tesis üretim öğreticisini açmaz")
	fillStarter(factory)
	assert(OnboardingSteps.stepFor(factory) == 6, "yeterli yetişkin varsa ilk parti adımı")
	assert(OnboardingSteps.readyFactory(factory, 1700000000) == recipe.id, "gerçek başlatılabilir tesis seçilir")
	assert(OnboardingSteps.stepFor(factory, { skipped = true }) == 0, "atlama bütün yönlendirmeyi kapatır")
	assert(OnboardingSteps.stepFor(newSave(), { skipped = true }) == 0, "atlama yeni oyuncuyu da durdurur")
	factory.production[recipe.id] = { readyAt = 1, startedAt = 0 }
	assert(OnboardingSteps.stepFor(factory) == 0, "parti başlayınca adım biter")
	factory.production = {}
	assert(
		OnboardingSteps.stepFor(factory, { productionStarted = true }) == 0,
		"teslim sonrası öğretici aynı oturumda geri dönmez"
	)
end
