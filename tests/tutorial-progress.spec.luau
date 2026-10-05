--!strict
-- Öğretici kalıcı ilerlemesi (sunucu): aşama yalnız artar, son adım/kıdemli kazanç öğreticiyi bitirir, öznitelikler yayımlanır,
-- tekrar göster aşamayı sıfırlamaz, bozuk kayıtlı alan çökertmez. Gerçek OnboardingSteps/Preferences kaynağı kullanılır.
return function(OnboardingSteps: any, TutorialProgress: any, Preferences: any, Config: any, FarmMath: any)
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
	local function fakePlayer(): any
		local attributes: { [string]: any } = {}
		return {
			attributes = attributes,
			SetAttribute = function(_self: any, name: string, value: any)
				attributes[name] = value
			end,
		}
	end
	local function adult(index: number): any
		return { uid = `a{index}`, animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" }
	end

	-- Her kilometre taşı aşamayı yükseltir; aynı durum ikinci kez değişiklik sayılmaz; öğretici bitmez
	local data = newSave()
	local player = fakePlayer()
	assert(not TutorialProgress.observe(data, OnboardingSteps, player), "yeni hesap: değişiklik yok")
	assert(data.tutorialStage == nil, "değişmeyen hesaba aşama alanı yazılmaz")
	table.insert(data.animals, adult(1))
	assert(TutorialProgress.observe(data, OnboardingSteps, player) and data.tutorialStage == 1, "ilk hayvan: aşama 1")
	assert(not TutorialProgress.observe(data, OnboardingSteps, player), "aynı durum tekrar değişiklik değil")
	data.lifetimeEarned = 40
	data.purchased.barn_2 = true
	assert(
		TutorialProgress.observe(data, OnboardingSteps, player) and data.tutorialStage == 3,
		"para + yükseltme: aşama 3"
	)
	data.production = { packed_milk = { readyAt = 1, startedAt = 0 } }
	assert(TutorialProgress.observe(data, OnboardingSteps, player) and data.tutorialStage == 4, "ilk üretim: aşama 4")
	assert(data.tutorialDone == nil and player.attributes.SavedTutorialDone == nil, "dört adım öğreticiyi bitirmez")

	-- Aşama asla azalmaz: parti alınsa, geliştirme/eşya kaybolsa bile
	data.production = {}
	assert(
		not TutorialProgress.observe(data, OnboardingSteps, player) and data.tutorialStage == 4,
		"durum geri gitse aşama düşmez"
	)
	data.contracts = { window = 1, done = {}, completed = 1 }
	data.expansions = { starter = 1 }
	data.inventory = { items = { wind_charm = true }, equipped = {}, uses = {} }
	assert(
		TutorialProgress.observe(data, OnboardingSteps, player) and data.tutorialStage == 7,
		"sipariş + geliştirme + eşya: aşama 7"
	)
	data.inventory = { items = {}, equipped = {}, uses = {} }
	data.expansions = {}
	assert(
		not TutorialProgress.observe(data, OnboardingSteps, player) and data.tutorialStage == 7,
		"eşya satılsa aşama düşmez"
	)
	assert(OnboardingSteps.stepFor(data, { stage = data.tutorialStage }) == 0, "tamamlanan adımlar geri gelmez")

	-- Rebirth: son aşama öğreticiyi bitirir ve öznitelik yayımlanır; sonraki gözlem tekrar yazmaz
	data.progression = { count = 1 }
	assert(
		TutorialProgress.observe(data, OnboardingSteps, player) and data.tutorialStage == OnboardingSteps.TOTAL,
		"rebirth: son aşama"
	)
	assert(
		data.tutorialDone == true and player.attributes.SavedTutorialDone == true,
		"son adım öğreticiyi bitirir ve istemciye bildirir"
	)
	-- Tekrar göster: bayrak sıfırlanır, aşama korunur ve bir sonraki gözlem bayrağı geri çevirmez (yalnız geçiş anında yazılır)
	assert(Preferences.apply(data, "tutorialDone", false), "tekrar göster bayrağı sıfırlar")
	assert(not TutorialProgress.observe(data, OnboardingSteps, player), "aşama aynı: gözlem değişmez")
	assert(
		data.tutorialDone == false and data.tutorialStage == OnboardingSteps.TOTAL,
		"tekrar göster aşamayı sıfırlamaz ve bayrağı geri açmaz"
	)

	-- Kıdemli kazanç (20.000+) öğreticiyi bitirir
	local veteran = newSave()
	veteran.lifetimeEarned = OnboardingSteps.SKIP_ALL_EARNED
	local vPlayer = fakePlayer()
	assert(TutorialProgress.observe(veteran, OnboardingSteps, vPlayer), "kıdemli hesap son aşamaya geçer")
	assert(
		veteran.tutorialDone == true and vPlayer.attributes.SavedTutorialDone == true,
		"kıdemli hesap bitmiş sayılır"
	)
	local midVeteran = newSave()
	midVeteran.lifetimeEarned = OnboardingSteps.SKIP_BASICS_EARNED
	assert(
		TutorialProgress.observe(midVeteran, OnboardingSteps, nil) and midVeteran.tutorialStage == 3,
		"1.500+ kazanç temel adımları geçirir"
	)
	assert(midVeteran.tutorialDone == nil, "temel adımları geçen hesap öğreticiyi bitirmez (üretim vb. sürer)")

	-- Bozuk kayıtlı alan: normalleşir, çökmez, azalma yazılmaz
	local corrupt = newSave()
	table.insert(corrupt.animals, adult(1))
	for _, bad in { 0 / 0, -4, "x", {}, true, 2.9 } do
		corrupt.tutorialStage = bad
		TutorialProgress.observe(corrupt, OnboardingSteps, nil)
		local stage = corrupt.tutorialStage
		assert(
			typeof(stage) == "number" and stage == math.floor(stage) and stage >= 1 and stage <= OnboardingSteps.TOTAL,
			"bozuk aşama sınırlı tam sayıya döner"
		)
	end
	corrupt.tutorialStage = 2.9
	corrupt.animals = {}
	TutorialProgress.observe(corrupt, OnboardingSteps, nil)
	assert(corrupt.tutorialStage == 2, "kesirli aşama aşağı yuvarlanır, azalma yazılmaz")

	-- markDone: yönetici test eylemleri; yalnız değişince true, öznitelikleri yayımlar, oyuncusuz da çalışır
	local admin = newSave()
	local aPlayer = fakePlayer()
	assert(TutorialProgress.markDone(admin, aPlayer), "ilk işaretleme değişiklik")
	assert(
		admin.tutorialDone == true and aPlayer.attributes.SavedTutorialDone == true,
		"bayrak yazılır ve yayımlanır"
	)
	assert(not TutorialProgress.markDone(admin, aPlayer), "tekrar işaretleme değişiklik değil")
	assert(admin.tutorialStage == nil, "yönetici işaretlemesi aşamayı değiştirmez")
	assert(OnboardingSteps.stepFor(admin, { skipped = admin.tutorialDone }) == 0, "yönetici profilinde adım yok")
	local plain = newSave()
	assert(TutorialProgress.markDone(plain, nil) and plain.tutorialDone == true, "oyuncusuz çağrı çökmez")
	assert(Config.ONBOARDING.TOTAL_STEPS == OnboardingSteps.TOTAL, "adım sayısı tek kaynak")
	print("PASS tutorial progress: monotonic stage, finish rules, replay, admin mark and corrupt values")
end
