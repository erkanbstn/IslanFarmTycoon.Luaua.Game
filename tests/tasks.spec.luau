--!strict
-- Hayvan görevleri: üretim tesisine verilen hayvan (iş boyunca gelirsiz) ve eklentide duran hayvan (süreli bonus).
return function(
	createExtensionService: any,
	createTaskService: any,
	createLimiter: any,
	codec: any,
	config: any,
	farmMath: any
)
	local now = 100000
	local serial = 0
	local function uid(): string
		serial += 1
		return `task-test-{serial}`
	end
	local function near(actual: number, expected: number, message: string)
		assert(
			math.abs(actual - expected) <= math.max(1e-6, math.abs(expected) * 1e-9),
			`{message}: {actual} ~= {expected}`
		)
	end

	local function newSave(): any
		local save = assert(codec.decode(nil, config, farmMath, now, uid), "fixture decode failed")
		save.cash = 1e6
		for _, upgrade in config.UPGRADES do
			if not upgrade.leveled then
				save.purchased[upgrade.id] = true
			end
		end
		farmMath.applyDerived(save)
		save.animals = {}
		return save
	end
	local function addAnimal(save: any, animalId: string, zoneId: string, extra: any?): any
		local animal: any = { uid = uid(), animalId = animalId, zoneId = zoneId, bornAt = 0, stage = "adult" }
		for key, value in extra or {} do
			animal[key] = value
		end
		table.insert(save.animals, animal)
		return animal
	end

	-- ------------------------------------------------------------------ gelir pencereleri
	local save = newSave()
	local cow = addAnimal(save, "cow", "starter")
	local baseIncome = farmMath.computeIncomeOverInterval(save, now, now + 100, true)
	assert(baseIncome > 0, "an adult cow earns")
	local rate = baseIncome / 100

	cow.task = { kind = "production", id = "dairy", startedAt = now + 20, endsAt = now + 60 }
	near(farmMath.computeIncomeOverInterval(save, now, now + 100, true), rate * 60, "production window earns nothing")
	near(
		farmMath.computeIncomeOverInterval(save, now + 50, now + 150, true),
		rate * 90,
		"partial overlap only removes the overlap"
	)
	near(
		farmMath.computeIncomeOverInterval(save, now + 60, now + 160, true),
		rate * 100,
		"after the window the animal earns again"
	)
	near(
		farmMath.computeIncomeOverInterval(save, now - 100, now + 20, true),
		rate * 120,
		"before the window the animal earns"
	)
	assert(
		farmMath.computeIncomePerSecond(save, now + 30) < farmMath.computeIncomePerSecond(save, now + 70),
		"instant income respects the window"
	)
	assert(
		farmMath.getActiveTask(cow, now + 59) ~= nil and farmMath.getActiveTask(cow, now + 60) == nil,
		"tasks end exactly at endsAt"
	)
	assert(
		farmMath.isInProduction(cow, now + 30) and not farmMath.isInProduction(cow, now + 61),
		"production busy flag follows the window"
	)

	-- Eklenti: pencere içinde bonus, dışında normal
	local chickenSave = newSave()
	local chicken = addAnimal(chickenSave, "chicken", "poultry")
	local chickenRate = farmMath.computeIncomeOverInterval(chickenSave, now, now + 100, true) / 100
	local folluk = config.EXTENSIONS.folluk_garden
	chicken.extensionId = "folluk_garden"
	chicken.task = { kind = "extension", id = "folluk_garden", startedAt = now, endsAt = now + folluk.stayDuration }
	near(
		farmMath.computeIncomeOverInterval(chickenSave, now, now + folluk.stayDuration + 100, true),
		chickenRate * (folluk.stayDuration * (1 + folluk.incomeBonus) + 100),
		"extension stay earns the bonus only during the stay"
	)
	chickenSave.purchased.ext_folluk_garden = nil
	near(
		farmMath.computeIncomeOverInterval(chickenSave, now, now + 100, true),
		chickenRate * 100,
		"an unowned extension gives no bonus"
	)

	-- ------------------------------------------------------------------ yapılandırma ve kapasite
	for id, extension in config.EXTENSIONS do
		assert(extension.capacity == 2, `extension {id} starts with 2 animals`)
		assert(extension.stayDuration > 0 and extension.incomeBonus > 0, `extension {id} has a timed bonus`)
		local ids = config.EXTENSION_CAPACITY_UPGRADES[id]
		assert(ids and #ids == config.EXTENSION_CAPACITY_LEVELS, `extension {id} has capacity upgrades`)
		local base = assert(config.getExtensionUpgrade(id), `extension {id} has an upgrade`)
		local previous = base
		for level, upgradeId in ids do
			local upgrade = assert(config.getUpgrade(upgradeId), "capacity upgrade exists")
			assert(upgrade.kind == "level" and upgrade.leveled, "capacity upgrades are level upgrades")
			assert(upgrade.extensionId == id and upgrade.extensionCapacity == 1, "each level adds one animal")
			assert(table.find(upgrade.requires, previous.id), "each level needs the previous one")
			assert(upgrade.cost > previous.cost, "each level costs more than the previous one")
			assert(
				config.getUpgradeIsland(upgrade) == extension.island,
				"capacity upgrades live on the extension's island"
			)
			previous = upgrade
			assert(level <= config.EXTENSION_CAPACITY_LEVELS, "no more levels than configured")
		end
	end
	local goatExtensions = 0
	for _, extension in config.EXTENSIONS do
		if extension.island == "goat" then
			goatExtensions += 1
		end
	end
	assert(goatExtensions >= 2, "the goat island has a second extension")
	local capacitySave = newSave()
	assert(farmMath.getExtensionCapacity(capacitySave, "training_course") == 2, "base capacity is two")
	capacitySave.purchased.ext_training_course_cap1 = true
	assert(farmMath.getExtensionCapacity(capacitySave, "training_course") == 3, "first upgrade gives three")
	capacitySave.purchased.ext_training_course_cap2 = true
	assert(farmMath.getExtensionCapacity(capacitySave, "training_course") == 4, "second upgrade gives four")
	assert(farmMath.getExtensionCapacity(capacitySave, "unknown") == 0, "unknown extension has no capacity")

	-- Eklentideki hayvanın ana bölgedeki yeri ayrılı kalır; boşta yetişkin seçimi görevdekileri atlar.
	local zoneSave = newSave()
	local zoneCount = farmMath.countInZone(zoneSave, "poultry")
	local sent = addAnimal(zoneSave, "chicken", "poultry", {
		extensionId = "folluk_garden",
		task = { kind = "extension", id = "folluk_garden", startedAt = now, endsAt = now + 120 },
	})
	addAnimal(zoneSave, "chicken", "poultry")
	assert(farmMath.countInZone(zoneSave, "poultry") == zoneCount + 2, "extension animals keep their zone slot")
	assert(farmMath.countInExtension(zoneSave, "folluk_garden", now + 60) == 1, "one animal is in the extension")
	assert(farmMath.countInExtension(zoneSave, "folluk_garden", now + 120) == 0, "expired stays are not counted")
	local hatchery = config.PRODUCTION_RECIPES.hatchery
	assert(hatchery.requiredAdults == 2, "hatchery needs two adults")
	assert(
		farmMath.pickProductionAnimals(zoneSave, hatchery, now + 10) == nil,
		"an animal in an extension cannot be given to a facility"
	)
	addAnimal(zoneSave, "chicken", "poultry")
	local picked = farmMath.pickProductionAnimals(zoneSave, hatchery, now + 10)
	assert(
		picked and #picked == 2 and picked[1] ~= sent and picked[2] ~= sent,
		"idle adults are picked, never the busy one"
	)
	assert(farmMath.pickProductionAnimals(zoneSave, hatchery, now + 130) ~= nil, "returned animals become available")

	-- Sınır değişmez: bölge dolu iken hayvanlar tesise/eklentiye çıksa da yeni hayvan alınamaz; dönüşte yer sorunu olmaz.
	local fullSave = newSave()
	local stable = config.ZONES.stable
	local capacity = farmMath.getZoneCapacity(fullSave, "stable")
	local horses: { any } = {}
	while farmMath.countInZone(fullSave, "stable") < capacity do
		table.insert(horses, addAnimal(fullSave, "horse", "stable"))
	end
	assert(stable.allowedAnimals[1] == "horse" and farmMath.getFreeSlots(fullSave, "horse") == 0, "the zone is full")
	assert(farmMath.findZoneForAnimal(fullSave, "horse") == nil, "a full zone takes no new animal")
	horses[1].task = { kind = "production", id = "horse_training", startedAt = now, endsAt = now + 75 }
	horses[2].extensionId = "training_course"
	horses[2].task = { kind = "extension", id = "training_course", startedAt = now, endsAt = now + 120 }
	assert(farmMath.countInZone(fullSave, "stable") == capacity, "animals away keep the zone at the same count")
	assert(farmMath.getFreeSlots(fullSave, "horse") == 0, "no slot opens while animals are away")
	assert(
		farmMath.findZoneForAnimal(fullSave, "horse") == nil,
		"a new animal cannot take the place of one that is away"
	)
	local sellable = farmMath.findSellableAnimal(fullSave, "horse", now + 10)
	assert(sellable ~= nil and sellable ~= horses[1] and sellable ~= horses[2], "only animals at home can be sold")
	-- Hayvan satılınca sınır değişir: tek yer açılır, dönen hayvanlar yine sığar
	for index, animal in fullSave.animals do
		if animal == sellable then
			table.remove(fullSave.animals, index)
			break
		end
	end
	assert(farmMath.getFreeSlots(fullSave, "horse") == 1, "selling an animal opens exactly one slot")
	horses[1].task = nil
	horses[2].task = nil
	horses[2].extensionId = nil
	assert(farmMath.countInZone(fullSave, "stable") == capacity - 1, "returning animals never need a free slot")

	-- Teslim ödülü: kaçırılan gelirin üstünde bir taban
	local rewardSave = newSave()
	addAnimal(rewardSave, "cow", "starter")
	addAnimal(rewardSave, "cow", "starter")
	local dairy = config.PRODUCTION_RECIPES.dairy
	local normal = farmMath.getProductionReward(rewardSave, dairy, now)
	local hugeForgone = normal * 10
	local floored =
		farmMath.getProductionReward(rewardSave, dairy, now, { uid = "j", readyAt = now, forgone = hugeForgone })
	assert(
		floored == math.ceil((hugeForgone + farmMath.getFacilityCost(rewardSave, dairy)) * config.PRODUCTION_MIN_RETURN),
		"reward follows the forgone-income floor"
	)
	assert(floored > hugeForgone, "reward always exceeds the forgone income")
	assert(
		farmMath.getProductionReward(rewardSave, dairy, now, { uid = "j", readyAt = now, forgone = 0 }) == normal,
		"a small forgone income does not lower the configured reward"
	)
	local animals = farmMath.pickProductionAnimals(rewardSave, dairy, now)
	assert(animals and #animals == 2, "two dairy animals are picked")
	assert(farmMath.estimateForgoneIncome(rewardSave, animals, 60) > 0, "forgone income is positive")
	local planned = farmMath.estimateForgoneIncome(rewardSave, animals, 60)
	for _, animal in animals do
		animal.task = { kind = "production", id = "dairy", startedAt = now, endsAt = now + 60 }
	end
	near(
		farmMath.computeIncomeOverInterval(rewardSave, now, now + 60, false),
		0,
		"working animals earn nothing for the whole job"
	)
	for _, animal in animals do
		animal.task = nil
	end
	near(
		farmMath.computeIncomeOverInterval(rewardSave, now, now + 60, false),
		planned,
		"the estimate equals what the animals would have earned"
	)

	-- ------------------------------------------------------------------ kayıt
	local stored = newSave()
	stored.farmId = nil
	addAnimal(stored, "chicken", "poultry", {
		extensionId = "folluk_garden",
		task = { kind = "extension", id = "folluk_garden", startedAt = now - 10, endsAt = now + 110 },
	})
	addAnimal(stored, "cow", "starter", {
		task = { kind = "production", id = "dairy", startedAt = now, endsAt = now + 60 },
	})
	stored.production.dairy = { uid = "job-1", readyAt = now + 60, startedAt = now, forgone = 123.5 }
	local encoded = codec.encode(stored, now)
	local farm = encoded.mainFarms["1"]
	assert(farm.production.dairy.startedAt == now and farm.production.dairy.forgone == 123.5, "job fields are saved")
	local tasks = 0
	for _, entry in farm.animals do
		if entry.task then
			tasks += 1
			entry.task.endsAt += 0 -- kopya: kayıt dışarıdan değiştirilemez olmalı
		end
	end
	assert(tasks == 2, "animal tasks are saved")
	local reloaded = assert(codec.decode(encoded, config, farmMath, now + 30, uid), "saved tasks reload")
	local live = 0
	for _, animal in reloaded.animals do
		if animal.task then
			live += 1
			assert(animal.task.endsAt > now + 30, "only running tasks survive a reload")
		end
	end
	assert(live == 2, "both running tasks survive a short reload")
	assert(reloaded.production.dairy.forgone == 123.5, "forgone survives a reload")

	-- Çevrimdışıyken biten görevler hayvanı eve döndürür; bonus penceresi çevrimdışı gelire işlenir.
	local late = assert(codec.decode(encoded, config, farmMath, now + 1000, uid), "offline reload")
	for _, animal in late.animals do
		assert(animal.task == nil and animal.extensionId == nil, "finished tasks are cleared on load")
	end
	assert(late.production.dairy ~= nil, "the job itself stays until claimed")
	local stayEncoded = codec.encode(stored, now)
	stayEncoded.mainFarms["1"].lastSeen = now - 10
	local plainEncoded = codec.encode(stored, now)
	plainEncoded.mainFarms["1"].lastSeen = now - 10
	for _, entry in plainEncoded.mainFarms["1"].animals do
		if entry.animalId == "chicken" then
			entry.task = nil
			entry.extensionId = nil
		end
	end
	local _, withStay = codec.decode(stayEncoded, config, farmMath, now + 3600, uid)
	local _, withoutStay = codec.decode(plainEncoded, config, farmMath, now + 3600, uid)
	assert(withStay > withoutStay, "an extension stay that ended while offline still pays its bonus")

	-- Eski kayıt: kalıcı eklenti ataması (görevsiz) hayvanı kaybettirmez, eve döndürür.
	local legacy = newSave()
	addAnimal(legacy, "chicken", "poultry")
	local legacyEncoded = codec.encode(legacy, now)
	legacyEncoded.mainFarms["1"].animals[1].extensionId = "folluk_garden"
	local migrated = assert(codec.decode(legacyEncoded, config, farmMath, now, uid), "legacy extension save loads")
	assert(#migrated.animals == #legacy.animals, "legacy extension animals are kept")
	for _, animal in migrated.animals do
		assert(animal.extensionId == nil and animal.task == nil, "legacy permanent assignments return home")
	end

	-- Bozuk görev yok sayılır, hayvan korunur
	for _, bad in
		{
			{ kind = "hack", id = "dairy", startedAt = now, endsAt = now + 60 },
			{ kind = "production", id = "nope", startedAt = now, endsAt = now + 60 },
			{ kind = "production", id = "dairy", startedAt = now, endsAt = math.huge },
			{ kind = "production", id = "dairy", startedAt = now + 100, endsAt = now + 50 },
			{ kind = "production", id = "dairy", startedAt = now, endsAt = now + 10 * 86400 },
			"task",
		}
	do
		local corrupt = newSave()
		addAnimal(corrupt, "cow", "starter")
		local data = codec.encode(corrupt, now)
		data.mainFarms["1"].animals[1].task = bad
		local result =
			assert(codec.decode(data, config, farmMath, now + 5, uid), "corrupt task must not reject the save")
		assert(
			#result.animals == #corrupt.animals and result.animals[1].task == nil,
			"corrupt task is dropped, animal kept"
		)
	end

	-- ------------------------------------------------------------------ ExtensionService
	local clock = now
	local function signal(): any
		local callbacks = {}
		return {
			Connect = function(_self: any, callback: any)
				table.insert(callbacks, callback)
			end,
			fire = function(...: any)
				for _, callback in callbacks do
					callback(...)
				end
			end,
		}
	end
	local node: any = {}
	function node:WaitForChild(_name: string): any
		return self
	end
	local function fakeGameWith(players: any): any
		return {
			GetService = function(_self: any, name: string): any
				if name == "Players" then
					return players
				end
				return node
			end,
		}
	end
	local limiter = createLimiter(fakeGameWith({ PlayerRemoving = signal() }), {
		clock = function(): number
			return clock
		end,
	})
	local fakeDateTime = {
		now = function(): any
			return { UnixTimestampMillis = clock * 1000 }
		end,
	}
	local owner: any = {
		GetAttribute = function(): boolean
			return true
		end,
	}
	local data = newSave()
	for index = 1, 4 do
		addAnimal(data, "chicken", "poultry")
		assert(index > 0, "fixture counter")
	end
	local settlements, pushes, saves, refreshes = 0, 0, 0, 0
	local extRequest = { OnServerEvent = signal() }
	local notices: { any } = {}
	local remotes = {
		get = function(name: string): any
			if name == "RequestExtensionAction" then
				return extRequest
			end
			return {
				FireClient = function(_self: any, _target: any, message: string, kind: string)
					table.insert(notices, { message = message, kind = kind })
				end,
			}
		end,
	}
	local dataService = {
		tryGet = function(target: any): any
			return if target == owner then data else nil
		end,
		pushState = function()
			pushes += 1
		end,
		requestSave = function()
			saves += 1
		end,
		getFarmIds = function(): { string }
			return { "1" }
		end,
		getFarmView = function(): any
			return data
		end,
	}
	local economy = {
		settlePlayer = function()
			settlements += 1
		end,
	}
	local plots = {
		refreshPlayerWorld = function()
			refreshes += 1
		end,
	}
	local extension =
		createExtensionService(fakeGameWith({}), remotes, dataService, economy, plots, limiter, fakeDateTime)
	extension.init()
	local function chickensIn(id: string): number
		return farmMath.countInExtension(data, id, clock)
	end

	assert(not (extension.tryAssign(owner, "unknown")), "unknown extension is rejected")
	data.purchased.ext_folluk_garden = nil
	local ok, message = extension.tryAssign(owner, "folluk_garden")
	assert(not ok and message == "Eklenti satın alınmamış", "unowned extension is rejected")
	data.purchased.ext_folluk_garden = true
	local before = settlements
	ok = extension.tryAssign(owner, "folluk_garden")
	assert(ok, "an idle adult can be sent")
	assert(
		settlements == before + 1 and refreshes >= 1 and pushes >= 1 and saves >= 1,
		"income is settled and the world refreshed"
	)
	assert(chickensIn("folluk_garden") == 1, "one chicken is in the extension")
	local stay: any = nil
	for _, animal in data.animals do
		if animal.task then
			stay = animal
		end
	end
	assert(
		stay.extensionId == "folluk_garden"
			and stay.task.startedAt == clock
			and stay.task.endsAt == clock + config.EXTENSIONS.folluk_garden.stayDuration,
		"the stay lasts the configured duration"
	)
	assert(extension.tryAssign(owner, "folluk_garden"), "the second animal fits (capacity two)")
	ok, message = extension.tryAssign(owner, "folluk_garden")
	assert(not ok and message == "Eklenti dolu", "capacity is two without upgrades")
	data.purchased.ext_folluk_garden_cap1 = true
	assert(extension.tryAssign(owner, "folluk_garden"), "the capacity upgrade allows a third animal")
	data.purchased.ext_folluk_garden_cap2 = true
	assert(extension.tryAssign(owner, "folluk_garden"), "and a fourth")
	ok, message = extension.tryAssign(owner, "folluk_garden")
	assert(not ok and message == "Eklenti dolu", "four is the maximum")
	assert(chickensIn("folluk_garden") == 4, "four chickens are in the extension")
	-- Geri çağırma: en erken bitecek olan döner
	clock += 5
	before = settlements
	assert(extension.tryUnassign(owner, "folluk_garden"), "an animal can be recalled early")
	assert(settlements == before + 1, "recall settles income first")
	assert(chickensIn("folluk_garden") == 3, "one chicken returned")
	-- Remote yolu: geçerli eylem bildirim üretir, geçersiz eylem üretmez
	clock += 1
	local noticeCount = #notices
	extRequest.OnServerEvent.fire(owner, "folluk_garden", "unassign")
	assert(
		#notices == noticeCount + 1 and notices[#notices].kind == "success",
		"a valid remote action notifies the player"
	)
	clock += 1
	extRequest.OnServerEvent.fire(owner, "folluk_garden", "hack")
	extRequest.OnServerEvent.fire(owner, 5, "assign")
	assert(#notices == noticeCount + 1, "invalid remote actions are ignored")
	-- Yetişkin olmayan ya da başka bölgedeki hayvan gönderilemez
	local calfData = newSave()
	addAnimal(calfData, "chicken", "poultry", { bornAt = clock, stage = "calf" })
	local savedData = data
	data = calfData
	calfData.purchased.ext_folluk_garden = true
	ok, message = extension.tryAssign(owner, "folluk_garden")
	assert(not ok, "a calf cannot be sent")
	data = savedData
	-- Bir eklentideki hayvan başka bir tesise verilemez ve tersi de geçerli
	local busyData = newSave()
	addAnimal(busyData, "chicken", "poultry", {
		task = { kind = "production", id = "hatchery", startedAt = clock, endsAt = clock + 90 },
	})
	data = busyData
	busyData.purchased.ext_folluk_garden = true
	ok = extension.tryAssign(owner, "folluk_garden")
	assert(not ok, "an animal working in a facility cannot be sent to an extension")
	data = savedData

	-- ------------------------------------------------------------------ AnimalTaskService
	local taskPlayer: any = {
		GetAttribute = function(): boolean
			return true
		end,
	}
	local players = {
		GetPlayers = function(): { any }
			return { taskPlayer }
		end,
	}
	dataService.tryGet = function(target: any): any
		return if target == taskPlayer or target == owner then data else nil
	end
	local taskService = createTaskService(
		fakeGameWith(players),
		{ spawn = function() end, wait = function() end },
		fakeDateTime,
		function() end,
		dataService,
		plots,
		economy
	)
	assert(not taskService.sweep(taskPlayer, clock), "nothing expires while stays are running")
	local settledBefore, refreshesBefore = settlements, refreshes
	local lastEnd = 0
	for _, animal in data.animals do
		if animal.task and animal.task.endsAt > lastEnd then
			lastEnd = animal.task.endsAt
		end
	end
	assert(taskService.sweep(taskPlayer, lastEnd), "finished stays return home")
	assert(settlements == settledBefore + 1, "income is settled before animals return")
	assert(refreshes == refreshesBefore + 1, "the world is refreshed once")
	for _, animal in data.animals do
		assert(animal.task == nil and animal.extensionId == nil, "all expired tasks are cleared")
	end
	assert(not taskService.sweep(taskPlayer, lastEnd + 1), "a second sweep is a no-op")
	print("PASS tasks: income windows, extension capacity, reward floor, save migration, extension and sweep services")
end
