--!strict
-- Sipariş seçimi ve hesabı saftır; istemciden miktar/fiyat kabul edilmez.
local OrderRules = {}

function OrderRules.isUnlocked(save: any, config: any): boolean
	for _, upgrade in config.UPGRADES do
		if not save.purchased[upgrade.id] then
			return false
		end
	end
	return true
end

function OrderRules.chooseAnimal(save: any, config: any): string?
	local available: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, animal in save.animals do
		if
			animal.stage == "adult"
			and config.ANIMALS[animal.animalId]
			and save.unlockedZones[animal.zoneId]
			and not seen[animal.animalId]
		then
			seen[animal.animalId] = true
			table.insert(available, animal.animalId)
		end
	end
	table.sort(available)
	if #available == 0 then
		return nil
	end
	return available[(save.ordersCompleted or 0) % #available + 1]
end

function OrderRules.advance(progress: number, adults: number, elapsed: number, config: any): number
	if elapsed ~= elapsed or elapsed <= 0 or elapsed == math.huge or adults <= 0 then
		return progress
	end
	return math.min(config.ORDER_UNITS, progress + adults * elapsed / config.ORDER_PRODUCTION_SECONDS)
end

function OrderRules.adultSeconds(
	bornAt: number,
	growthSpeed: number,
	startedAt: number,
	endedAt: number,
	config: any
): number
	if endedAt <= startedAt or growthSpeed <= 0 then
		return 0
	end
	local adultAt = if bornAt == 0
		then startedAt
		else bornAt + (config.GROWTH_SECONDS.calf + config.GROWTH_SECONDS.young) / growthSpeed
	return math.max(0, endedAt - math.max(startedAt, adultAt))
end

function OrderRules.reward(animalId: string, config: any): number
	local animal = config.ANIMALS[animalId]
	if not animal then
		return 0
	end
	return math.floor(
		animal.baseIncomePerSecond
			* config.ORDER_UNITS
			* config.ORDER_PRODUCTION_SECONDS
			* config.ORDER_REWARD_MULTIPLIER
	)
end

return OrderRules
