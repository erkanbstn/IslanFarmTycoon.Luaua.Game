--!strict
return function(rules: any, config: any)
	local save: any = { purchased = {}, animals = {}, unlockedZones = { starter = true }, ordersCompleted = 0 }
	assert(not rules.isUnlocked(save, config), "orders must not distract from initial roadmap")
	for _, upgrade in config.UPGRADES do
		save.purchased[upgrade.id] = true
	end
	assert(rules.isUnlocked(save, config))
	-- Temalı çiftlikler: yalnızca kendi adalarının yükseltmelerini alabilirler; sipariş onlarla açılmalı
	for index in config.THEMES do
		local farmId = tostring(index)
		local themed: any =
			{ purchased = {}, animals = {}, unlockedZones = { starter = true }, activeMainFarmId = farmId }
		local missingId: string? = nil
		for _, upgrade in config.UPGRADES do
			if not upgrade.leveled and config.themeHasIsland(farmId, config.getUpgradeIsland(upgrade)) then
				themed.purchased[upgrade.id] = true
				missingId = missingId or upgrade.id
			end
		end
		assert(rules.isUnlocked(themed, config), `farm {farmId} must unlock orders after its own roadmap`)
		themed.purchased[missingId :: string] = nil
		assert(not rules.isUnlocked(themed, config), `farm {farmId} still needs every upgrade of its own islands`)
	end
	assert(rules.chooseAnimal(save, config) == nil, "empty farms cannot start an order")
	save.animals = { { animalId = "cow", stage = "calf", zoneId = "starter" } }
	assert(rules.chooseAnimal(save, config) == nil, "orders need producing adults")
	save.animals[1].stage = "adult"
	assert(rules.chooseAnimal(save, config) == "cow", "adult cow must be eligible")
	assert(
		rules.advance(0, 2, config.ORDER_PRODUCTION_SECONDS, config) == 2,
		"two adults must produce two units per production period"
	)
	assert(rules.advance(0, 2, 1e6, config) == config.ORDER_UNITS, "production must cap at target")
	assert(rules.advance(3, 0, 60, config) == 3, "no adults means no production")
	assert(rules.advance(3, 5, 0 / 0, config) == 3, "NaN time must not affect progress")
	local adultAt = 1000 + config.GROWTH_SECONDS.calf + config.GROWTH_SECONDS.young
	assert(
		rules.adultSeconds(1000, 1, adultAt - 10, adultAt + 5, config) == 5,
		"only post-adult interval can produce orders"
	)
	assert(rules.adultSeconds(0, 1, 1000, 1015, config) == 15, "starter adults produce the whole interval")
	local split = rules.advance(rules.advance(0, 1, 5, config), 1, 10, config)
	assert(math.abs(split - rules.advance(0, 1, 15, config)) < 1e-9, "scheduler splits must not change production")
	assert(
		rules.reward("cow", config)
			== math.floor(
				config.ANIMALS.cow.baseIncomePerSecond
					* config.ORDER_UNITS
					* config.ORDER_PRODUCTION_SECONDS
					* config.ORDER_REWARD_MULTIPLIER
			),
		"reward must be server Config formula"
	)
	assert(rules.reward("unknown", config) == 0, "unknown animal cannot award money")
	print("orders: unlock, adult eligibility, production caps, elapsed time, rewards passed")
end
