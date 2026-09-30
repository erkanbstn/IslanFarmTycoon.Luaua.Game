--!strict
-- Gezgin tüccar (rastgele olay): ziyaret pencereleri ve indirimli hayvan teklifi. Saf ve paylaşılan:
-- sunucu teklifi doğrular ve ücreti alır, client aynı hesapla teklifi gösterir. Rastgelelik oyuncu kimliği ve
-- döngü numarasından türetilir; kayıt gerekmez (yalnızca alınan teklifin döngüsü `save.merchant` içinde tutulur).

local Config = require(script.Parent.Parent:WaitForChild("Config"))
local FarmMath = require(script.Parent:WaitForChild("FarmMath"))

local Merchant = {}

export type Visit = { cycle: number, startsAt: number, endsAt: number, active: boolean }
export type Offer = {
	animalId: string,
	count: number,
	price: number, -- İndirimli toplam fiyat
	fullPrice: number,
	cycle: number,
	endsAt: number,
}

-- 0 <= sonuç < 1, aynı girdiyle her yerde aynı değer
local function rand(userId: number, cycle: number, salt: number): number
	local seed = ((userId % 1000003) * 7919 + cycle * 104729 + salt * 15485863) % 2147483648
	seed = (seed * 1103515245 + 12345) % 2147483648
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

-- Bu oyuncunun bu döngüdeki ziyareti (yoksa nil). `active`: şu an tüccar burada mı.
function Merchant.visit(userId: number, now: number): Visit?
	local settings = Config.MERCHANT
	local cycle = math.floor(now / settings.cycleSeconds)
	if rand(userId, cycle, 1) >= settings.chance then
		return nil
	end
	local offset = math.floor(rand(userId, cycle, 2) * (settings.cycleSeconds - settings.visitSeconds))
	local startsAt = cycle * settings.cycleSeconds + offset
	local endsAt = startsAt + settings.visitSeconds
	return { cycle = cycle, startsAt = startsAt, endsAt = endsAt, active = now >= startsAt and now < endsAt }
end

-- Şu an sunulan teklif: ziyaret sürüyor, bu döngüde alınmadı ve satın alınabilen bir hayvan var.
function Merchant.offer(save: any, userId: number, now: number): Offer?
	local visit = Merchant.visit(userId, now)
	if not visit or not visit.active then
		return nil
	end
	local merchant = save.merchant
	if merchant and merchant.key == visit.cycle and merchant.bought then
		return nil
	end
	local candidates: { string } = {}
	for _, animalId in Config.ANIMAL_ORDER do
		if FarmMath.findZoneForAnimal(save, animalId) then
			table.insert(candidates, animalId)
		end
	end
	if #candidates == 0 then
		return nil
	end
	-- Pahalı yarıdan seç: indirim anlamlı olsun
	table.sort(candidates, function(a: string, b: string): boolean
		return Config.ANIMALS[a].price < Config.ANIMALS[b].price
	end)
	local upper: { string } = {}
	for index = #candidates - math.ceil(#candidates / 2) + 1, #candidates do
		table.insert(upper, candidates[index])
	end
	local animalId = upper[math.floor(rand(userId, visit.cycle, 3) * #upper) + 1]
	local count = math.min(Config.MERCHANT.stock, FarmMath.getFreeSlots(save, animalId))
	if count < 1 then
		return nil
	end
	local fullPrice = FarmMath.getBulkPrice(save, animalId, count)
	return {
		animalId = animalId,
		count = count,
		price = math.floor(fullPrice * (1 - Config.MERCHANT.discount)),
		fullPrice = fullPrice,
		cycle = visit.cycle,
		endsAt = visit.endsAt,
	}
end

return Merchant
