--!strict
-- İlk adımlar: adım sırası, kıdemli atlama eşikleri, 4. adımın yalnızca başlatılabilir parti varken çıkması, 5-8. adımlar (sipariş,
-- geliştirme, eşya, rebirth), kalıcı aşama ve eski kayıt göçü (saf, gerçek Config/FarmMath/SaveCodec).
return function(OnboardingSteps: any, Config: any, FarmMath: any, SaveCodec: any)
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
	assert(OnboardingSteps.TOTAL == 8, "sekiz adım")
	assert(
		OnboardingSteps.SKIP_BASICS_EARNED == Config.ONBOARDING.SKIP_BASICS_EARNED
			and OnboardingSteps.SKIP_ALL_EARNED == Config.ONBOARDING.SKIP_ALL_EARNED
			and OnboardingSteps.TOTAL == Config.ONBOARDING.TOTAL_STEPS,
		"eşikler ve adım sayısı tek kaynaktan (Config.ONBOARDING) gelir"
	)
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
	-- Tamamlanma kalıcıdır: sunucu ilk partide `tutorialStage` = 4 yazar (öğreticiyi bitirmez), istemci bunu aşama olarak geçirir
	assert(OnboardingSteps.stepFor(factory, { skipped = true }) == 0, "atlama/bitti işareti öğreticiyi kapatır")
	assert(
		OnboardingSteps.stepFor(factory, { stage = 4 }) == 0,
		"parti teslim alınıp çalışan iş kalmasa da 4. adım kayıtlı aşamayla geri dönmez"
	)
	assert(OnboardingSteps.stepFor(factory, { stage = 3 }) == 4, "3. aşamadan sonra üretim adımı sürer")

	-- Sözleşme değişikliği (4 -> 8 adım): yükseltme alındıktan sonra yeni adımlar kendi koşullarıyla sürer; koşul yoksa öğretici boştur.
	-- Üstteki "yükseltme alındı, tesis yok: 0" iddiası bu yüzden hâlâ doğrudur (başlangıç parasıyla geliştirme/eşya karşılanmaz).
	local function basicsSave(): any
		local built = newSave()
		built.lifetimeEarned = OnboardingSteps.SKIP_BASICS_EARNED + 500
		fillStarter(built)
		return built
	end
	local now = 1700000000
	local cheapestCash = math.huge
	for _, item in Config.ITEMS do
		if Config.isCashItem(item) and item.price < cheapestCash then
			cheapestCash = item.price
		end
	end
	assert(cheapestCash < math.huge, "nakitle alınabilen eşya var")

	-- 6 ve 7: geliştirme eşyadan önce gelir; ilk geliştirme alınınca bir daha çıkmaz; eşya yoksa ve para yetiyorsa 7
	local gear = basicsSave()
	assert(OnboardingSteps.stepFor(gear, nil, now) == 0, "para yokken 5-8. adımlar sessiz")
	gear.cash = cheapestCash
	local target = OnboardingSteps.affordableExpansion(gear)
	assert(target ~= nil, "başlangıç bölgesi doluyken geliştirme alınabilir")
	assert(OnboardingSteps.stepFor(gear, nil, now) == 6, "geliştirme eşyadan önce (sıra)")
	assert(OnboardingSteps.stepFor(gear, { stage = 5 }, now) == 6, "5. aşamadan sonra 6 gelir")
	gear.expansions = { [target :: string] = 1 }
	assert(
		OnboardingSteps.stepFor(gear, nil, now) == 7,
		"ilk geliştirme alındı: diğer yapılar 6. adımı geri getirmez, 7 gelir"
	)
	assert(OnboardingSteps.stepFor(gear, { stage = 6 }, now) == 7, "6. aşamadan sonra 7 gelir")
	gear.cash = cheapestCash - 1
	assert(OnboardingSteps.stepFor(gear, nil, now) == 0, "en ucuz nakit eşyaya para yetmezse 7. adım yok")
	gear.cash = cheapestCash
	gear.inventory = { items = { wind_charm = true }, equipped = {}, uses = {} }
	assert(OnboardingSteps.stepFor(gear, nil, now) == 0, "eşya alınınca 7. adım biter")
	gear.inventory = { items = { wind_charm = false }, equipped = {}, uses = {} }
	assert(OnboardingSteps.stepFor(gear, nil, now) == 7, "sahip olunmayan (false) eşya sayılmaz")
	gear.inventory = { items = {}, equipped = { head = "x" }, uses = {} }
	assert(OnboardingSteps.stepFor(gear, nil, now) == 0, "takılı eşya da eşya sahibi olmaktır")
	gear.inventory = nil
	-- Kalıcı aşama: eşya satılsa/tüketilse bile tamamlanan adım geri gelmez; bozuk aşama 0 sayılır
	assert(
		OnboardingSteps.stepFor(gear, { stage = 7 }, now) == 0,
		"tamamlanan 7. adım kayıtlı aşamayla geri gelmez"
	)
	assert(
		OnboardingSteps.stepFor(gear, { stage = 8 }, now) == 0
			and OnboardingSteps.stepFor(gear, { stage = 99 }, now) == 0,
		"son/aşırı aşama hiçbir adım göstermez"
	)
	assert(OnboardingSteps.stepFor(gear, { stage = -3 }, now) == 7, "negatif aşama 0 sayılır")
	assert(OnboardingSteps.stepFor(gear, { stage = 0 / 0 }, now) == 7, "NaN aşama 0 sayılır")
	assert(OnboardingSteps.stepFor(gear, { stage = "x" :: any }, now) == 7, "yanlış türde aşama 0 sayılır")

	-- 8: rebirth tanıtımı; sayaç ya da hazırlık kalkınca kendiliğinden kaybolur (kalıcı "açıldı" durumu yok)
	local rebirth = basicsSave()
	rebirth.progressionStatus = { canRebirth = true }
	assert(OnboardingSteps.stepFor(rebirth, nil, now) == 8, "rebirth hazırken 8. adım")
	rebirth.progression = { count = 1 }
	assert(OnboardingSteps.stepFor(rebirth, nil, now) == 0, "rebirth yapılmışsa 8. adım yok")
	rebirth.progression = { count = 0 }
	rebirth.progressionStatus = { canRebirth = false }
	assert(OnboardingSteps.stepFor(rebirth, nil, now) == 0, "hazır değilken 8. adım kaybolur")
	rebirth.progressionStatus = { canRebirth = true }
	assert(OnboardingSteps.stepFor(rebirth, { skipped = true }, now) == 0, "oyuncu 8. adımı atlayabilir")
	assert(OnboardingSteps.stepFor(rebirth, { stage = 8 }, now) == 0, "8. aşamadan sonra yok")
	local richRebirth = basicsSave()
	richRebirth.lifetimeEarned = OnboardingSteps.SKIP_ALL_EARNED
	richRebirth.progressionStatus = { canRebirth = true }
	assert(OnboardingSteps.stepFor(richRebirth, nil, now) == 0, "kıdemli hesap hiçbir yeni adım görmez")

	-- 5: ilk sipariş teslimi; ürün merkezi yoksa atlanır, teslim edilmişse bir daha çıkmaz
	local order = basicsSave()
	local goodsRecipe: any = nil
	for _, id in Config.PRODUCTION_ORDER do
		local candidate = Config.PRODUCTION_RECIPES[id]
		if candidate.output == "goods" and candidate.goodsId and not goodsRecipe then
			goodsRecipe = candidate
		end
	end
	assert(goodsRecipe ~= nil, "ürün merkezi tarifi var")
	order.purchased[goodsRecipe.upgradeId] = true
	order.unlockedIslands[goodsRecipe.island] = true
	FarmMath.applyDerived(order)
	assert(OnboardingSteps.ownsGoodsCenter(order), "ürün merkezi kurulu")
	assert(OnboardingSteps.stepFor(order, nil, now) ~= 5, "depoda ürün yokken hazır sipariş yok: adım atlanır")
	order.goods = {}
	for _, goodsId in Config.GOODS_ORDER do
		order.goods[goodsId] = FarmMath.getGoodsCap(order)
	end
	assert(FarmMath.getReadyContractCount(order, now, 0) > 0, "depo doluyken teslime hazır sipariş var")
	assert(OnboardingSteps.stepFor(order, nil, now) == 5, "hazır sipariş varken 5. adım")
	assert(OnboardingSteps.stepFor(order, { stage = 5 }, now) ~= 5, "kayıtlı aşama 5. adımı kapatır")
	order.contracts = { window = 1, done = {}, completed = 1 }
	assert(OnboardingSteps.stepFor(order, nil, now) ~= 5, "ilk teslimden sonra 5. adım bir daha çıkmaz")
	local noCenter = basicsSave()
	noCenter.goods = { [Config.GOODS_ORDER[1]] = 5 }
	assert(OnboardingSteps.stepFor(noCenter, nil, now) ~= 5, "ürün merkezi yokken 5. adım bekletmez")
	-- Yeni özellik adımı bekletmez: sipariş yokken 6 hazırsa 6 gelir
	local skipForward = basicsSave()
	skipForward.cash = 1e9
	skipForward.inventory = { items = { a = true }, equipped = {}, uses = {} }
	assert(OnboardingSteps.stepFor(skipForward, nil, now) == 6, "5. adımın özelliği yokken 6. adıma geçilir")
	-- Hiçbir özelliği olmayan hesap boş kalır (adım bekletmez)
	assert(OnboardingSteps.stepFor(basicsSave(), nil, now) == 0, "özellik yoksa adım yok")
	-- Temel adımlar bitmeden 5-8 çıkmaz
	local early = newSave()
	early.cash = 1e9
	early.progressionStatus = { canRebirth = true }
	fillStarter(early)
	assert(OnboardingSteps.stepFor(early, nil, now) == 2, "temel adımlar bitmeden yeni adımlar çıkmaz")

	-- reachedStage: yalnız artar; tamamlanan en yüksek adım, atlayan oyuncu önceki adımları da geçer
	local progress = newSave()
	assert(OnboardingSteps.reachedStage(progress) == 0, "yeni hesap 0")
	table.insert(progress.animals, { uid = "a1", animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" })
	assert(OnboardingSteps.reachedStage(progress) == 1, "hayvan alındı: 1")
	progress.lifetimeEarned = 10
	assert(OnboardingSteps.reachedStage(progress) == 2, "para toplandı: 2")
	progress.purchased.barn_2 = true
	assert(OnboardingSteps.reachedStage(progress) == 3, "yükseltme: 3")
	progress.production = { x = { readyAt = 1, startedAt = 0 } }
	assert(OnboardingSteps.reachedStage(progress) == 4, "üretim: 4")
	progress.contracts = { window = 1, done = {}, completed = 2 }
	assert(OnboardingSteps.reachedStage(progress) == 5, "teslim: 5")
	progress.expansions = { starter = 1 }
	assert(OnboardingSteps.reachedStage(progress) == 6, "geliştirme: 6")
	progress.inventory = { items = { a = true }, equipped = {}, uses = {} }
	assert(OnboardingSteps.reachedStage(progress) == 7, "eşya: 7")
	progress.progression = { count = 1 }
	assert(OnboardingSteps.reachedStage(progress) == 8, "rebirth: 8")
	progress.progression = { count = 0 }
	progress.inventory = nil
	progress.expansions = {}
	progress.tutorialStage = 7
	assert(OnboardingSteps.reachedStage(progress) == 7, "durum geri gitse de kayıtlı aşama düşmez")
	progress.tutorialStage = 99
	assert(
		OnboardingSteps.reachedStage(progress) == OnboardingSteps.TOTAL,
		"aşırı kayıtlı aşama TOTAL ile sınırlanır"
	)
	progress.tutorialStage = 0 / 0
	assert(OnboardingSteps.reachedStage(progress) == 5, "bozuk kayıtlı aşama yok sayılır (durumdan türer)")
	local skipper = newSave()
	skipper.inventory = { items = { a = true }, equipped = {}, uses = {} }
	assert(OnboardingSteps.reachedStage(skipper) == 7, "eşya alan oyuncu önceki adımları geçmiş sayılır")
	local earnedBasics = newSave()
	earnedBasics.lifetimeEarned = OnboardingSteps.SKIP_BASICS_EARNED
	assert(OnboardingSteps.reachedStage(earnedBasics) == 3, "kazanç eşiği temel adımları geçirir")
	earnedBasics.lifetimeEarned = OnboardingSteps.SKIP_ALL_EARNED
	assert(OnboardingSteps.reachedStage(earnedBasics) == OnboardingSteps.TOTAL, "kıdemli hesap bitmiş sayılır")
	earnedBasics.lifetimeEarned = 0 / 0
	assert(OnboardingSteps.reachedStage(earnedBasics) == 0, "bozuk kazanç aşama vermez")

	-- Eski kayıt göçü (SaveCodec.decode): işaret yokken eşik üstü kazanç öğreticiyi bitmiş sayar; sürüm değişmez
	local uid = function()
		return "u"
	end
	local decodeNow = 2000000000
	local fresh = assert(SaveCodec.decode(nil, Config, FarmMath, decodeNow, uid))
	assert(fresh.tutorialDone == nil and fresh.tutorialStage == nil, "yeni hesap etkilenmez")
	local function reload(edit: (any) -> ()): any
		local raw = SaveCodec.encode(fresh, decodeNow)
		edit(raw)
		return assert(SaveCodec.decode(raw, Config, FarmMath, decodeNow, uid))
	end
	local below = reload(function(raw)
		raw.tutorialDone = nil
		raw.lifetimeEarned = OnboardingSteps.SKIP_BASICS_EARNED - 1
	end)
	assert(below.tutorialDone == nil, "eşik altı eski kayıt öğreticide kalır")
	local above = reload(function(raw)
		raw.tutorialDone = nil
		raw.lifetimeEarned = OnboardingSteps.SKIP_BASICS_EARNED
	end)
	assert(above.tutorialDone == true, "eşik üstü eski kayıt bitmiş sayılır")
	local explicitFalse = reload(function(raw)
		raw.tutorialDone = false
		raw.lifetimeEarned = OnboardingSteps.SKIP_ALL_EARNED
	end)
	assert(explicitFalse.tutorialDone == false, "açık false (yeniden göster) korunur")
	local explicitTrue = reload(function(raw)
		raw.tutorialDone = true
		raw.lifetimeEarned = 0
	end)
	assert(explicitTrue.tutorialDone == true, "açık true korunur")
	local corruptAbove = reload(function(raw)
		raw.tutorialDone = "yes"
		raw.lifetimeEarned = OnboardingSteps.SKIP_BASICS_EARNED + 1
	end)
	assert(corruptAbove.tutorialDone == true, "bozuk işaret yok sayılır, eşik üstü göç uygulanır")
	local corruptBelow = reload(function(raw)
		raw.tutorialDone = { true }
		raw.lifetimeEarned = 1
	end)
	assert(corruptBelow.tutorialDone == nil, "bozuk işaret eşik altında öğreticiyi bitirmez")
	local corruptEarned = reload(function(raw)
		raw.tutorialDone = nil
		raw.lifetimeEarned = 0 / 0
	end)
	assert(corruptEarned.tutorialDone == nil and corruptEarned.lifetimeEarned == 0, "bozuk kazanç göç tetiklemez")
	-- Kalıcı aşama: eksik = nil, geçerli değer korunur, bozuk/aşırı değer sınırlanır ya da atılır; encode yalnız temiz değer yazar
	local noStage = reload(function(raw)
		raw.tutorialStage = nil
	end)
	assert(noStage.tutorialStage == nil, "eski kayıtta aşama yok")
	for _, case in
		{ { 3, 3 }, { 0, 0 }, { 99, OnboardingSteps.TOTAL }, { -5, 0 }, { 2.7, 2 }, { 1e308, OnboardingSteps.TOTAL } }
	do
		local value = case[1]
		local restored = reload(function(raw)
			raw.tutorialStage = value
		end)
		assert(restored.tutorialStage == case[2], `aşama {value} -> {case[2]}`)
	end
	for _, bad in { 0 / 0, math.huge, -math.huge, "3", true, {} } do
		local restored = reload(function(raw)
			raw.tutorialStage = bad
		end)
		assert(restored.tutorialStage == nil, "bozuk aşama atılır")
	end
	fresh.tutorialStage = 5
	local roundTrip = assert(SaveCodec.decode(SaveCodec.encode(fresh, decodeNow), Config, FarmMath, decodeNow, uid))
	assert(roundTrip.tutorialStage == 5, "aşama kayıttan geri gelir")
	fresh.tutorialStage = 1e9
	assert(SaveCodec.encode(fresh, decodeNow).tutorialStage <= 100, "encode sert üst sınır uygular")
	fresh.tutorialStage = 0 / 0
	assert(SaveCodec.encode(fresh, decodeNow).tutorialStage == nil, "encode bozuk aşamayı yazmaz")
	fresh.tutorialStage = nil
end
