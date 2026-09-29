--!strict
-- Sipariş panosu: 3 seçenek (kısa/orta/uzun) ve ödül hesabı. Saf ve paylaşılan: sunucu seçimi doğrular
-- ve ödülü verir, client aynı hesapla panoyu çizer. Mevsim bonusu (`bonus`) çağıran tarafından verilir.

local Config = require(script.Parent.Parent:WaitForChild("Config"))

local OrderBoard = {}

export type Offer = {
	key: string, -- "<pencere>:<sıra>": sunucu bu anahtarı yeniden hesaplayıp doğrular
	tier: string,
	animalId: string,
	units: number,
	rewardFactor: number,
	reward: number,
}

-- Yenilenme penceresi numarası (sunucu saatinden)
function OrderBoard.window(now: number): number
	return math.floor(now / Config.ORDER_BOARD_SECONDS)
end

-- Kaç saniye sonra yenilenir
function OrderBoard.secondsLeft(now: number): number
	return Config.ORDER_BOARD_SECONDS - now % Config.ORDER_BOARD_SECONDS
end

-- Bir siparişin ödülü: hayvanın taban ödülü x birim oranı x panodaki çarpan x mevsim bonusu
function OrderBoard.reward(animalId: string, units: number, rewardFactor: number?, bonus: number?): number
	local animal = Config.ANIMALS[animalId]
	if not animal then
		return 0
	end
	local base = animal.baseIncomePerSecond * units * Config.ORDER_PRODUCTION_SECONDS * Config.ORDER_REWARD_MULTIPLIER
	return math.floor(base * (rewardFactor or 1) * (1 + (bonus or 0)))
end

-- Kayıtlı bir siparişin teslim ödülü
function OrderBoard.claimReward(
	order: { animalId: string, target: number, rewardFactor: number? },
	bonus: number?
): number
	return OrderBoard.reward(order.animalId, order.target, order.rewardFactor, bonus)
end

-- Yetişkin ve açık bölgedeki hayvan türleri (sıralı, tekrarsız)
local function availableAnimals(save: any): { string }
	local seen: { [string]: boolean } = {}
	local result: { string } = {}
	for _, animal in save.animals do
		if
			animal.stage == "adult"
			and Config.ANIMALS[animal.animalId]
			and save.unlockedZones[animal.zoneId]
			and not seen[animal.animalId]
		then
			seen[animal.animalId] = true
			table.insert(result, animal.animalId)
		end
	end
	table.sort(result)
	return result
end

function OrderBoard.offers(save: any, now: number, bonus: number?): { Offer }
	local animals = availableAnimals(save)
	local offers: { Offer } = {}
	if #animals == 0 then
		return offers
	end
	local window = OrderBoard.window(now)
	for index, tier in Config.ORDER_TIERS do
		-- Her pencerede ve sırada farklı hayvan: seçenekler çeşitli görünür
		local animalId = animals[(window + index + (save.ordersCompleted or 0)) % #animals + 1]
		table.insert(offers, {
			key = `{window}:{index}`,
			tier = tier.id,
			animalId = animalId,
			units = tier.units,
			rewardFactor = tier.rewardFactor,
			reward = OrderBoard.reward(animalId, tier.units, tier.rewardFactor, bonus),
		})
	end
	return offers
end

-- "<pencere>:<sıra>" anahtarını doğrular; geçerliyse ilgili seçeneği döner.
function OrderBoard.resolve(save: any, key: unknown, now: number, bonus: number?): (Offer?, string?)
	if typeof(key) ~= "string" or #key > 24 then
		return nil, "Geçersiz sipariş"
	end
	for _, offer in OrderBoard.offers(save, now, bonus) do
		if offer.key == key then
			return offer, nil
		end
	end
	return nil, "Teklifler yenilendi; panodan yeniden seç"
end

return OrderBoard
