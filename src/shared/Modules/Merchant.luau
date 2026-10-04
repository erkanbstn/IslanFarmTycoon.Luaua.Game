--!strict
-- Gezgin tüccar (rastgele olay): ziyaret pencereleri ve indirimli tur eşyaları. Saf ve paylaşılan:
-- sunucu teklifi doğrular ve ücreti alır, client aynı hesapla teklifi gösterir. Rastgelelik oyuncu kimliği ve
-- döngü numarasından türetilir; kayıt gerekmez (yalnızca alınan teklifin döngüsü `save.merchant` içinde tutulur).

local Config = require(script.Parent.Parent:WaitForChild("Config"))
local Inventory = require(script.Parent:WaitForChild("Inventory"))

local Merchant = {}

export type Visit = { cycle: number, startsAt: number, endsAt: number, active: boolean }
export type Offer = {
	itemId: string,
	price: number,
	fullPrice: number,
	cycle: number,
	endsAt: number,
}

-- 0 <= sonuç < 1, aynı girdiyle her yerde aynı değer (Golden de kullanır)
local function rand(userId: number, cycle: number, salt: number): number
	local seed = ((userId % 1000003) * 7919 + cycle * 104729 + salt * 15485863) % 2147483648
	seed = (seed * 1103515245 + 12345) % 2147483648
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

Merchant.rand = rand

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

-- Şu an süren ziyaret (yönetici zorlaması dahil) ve bu ziyaretin teklifi alınmış mı. Teklif/rozet/bildirim aynı kaynaktan okur.
export type Status = { visit: Visit?, bought: boolean, offer: Offer?, offers: { Offer } }

local function activeVisit(save: any, userId: number, now: number): Visit?
	-- Test aracı: yönetici ziyareti zorlayabilir (save.adminForce yalnızca çalışma anında vardır, kaydedilmez)
	local forcedUntil = if save.adminForce then save.adminForce.merchantUntil else nil
	local visit: Visit? = nil
	if typeof(forcedUntil) == "number" and now < forcedUntil then
		visit = {
			cycle = math.floor(now / Config.MERCHANT.cycleSeconds),
			startsAt = now,
			endsAt = forcedUntil,
			active = true,
		}
	else
		visit = Merchant.visit(userId, now)
	end
	if visit and visit.active then
		return visit
	end
	return nil
end

-- NPC yaşam döngüsü katalog üretmeden aynı ziyaret sınırını okuyabilir.
Merchant.currentVisit = activeVisit

-- Ziyaret başına tek alım; sabit katalog sahiplik değişince yeni bir teklif üretmez.
function Merchant.status(save: any, userId: number, now: number): Status
	local visit = activeVisit(save, userId, now)
	if not visit then
		return { visit = nil, bought = false, offer = nil, offers = {} }
	end
	local marker = save.merchant
	local bought = marker ~= nil and marker.key == visit.cycle and marker.bought == true
	if bought then
		return { visit = visit, bought = true, offer = nil, offers = {} }
	end
	local candidates: { string } = {}
	local ranks: { [string]: number } = {}
	for index, itemId in Config.ITEM_ORDER do
		local item = Config.ITEMS[itemId]
		if item and not item.rewardOnly and item.price > 0 then
			table.insert(candidates, itemId)
			ranks[itemId] = rand(userId, visit.cycle, 100 + index)
		end
	end
	table.sort(candidates, function(a: string, b: string): boolean
		local left = ranks[a]
		local right = ranks[b]
		return if left == right then a < b else left < right
	end)
	local offers: { Offer } = {}
	for index = 1, math.min(Config.MERCHANT.stock, #candidates) do
		local itemId = candidates[index]
		if not Inventory.owns(save, itemId) then
			local fullPrice = Config.ITEMS[itemId].price
			table.insert(offers, {
				itemId = itemId,
				fullPrice = fullPrice,
				price = math.max(1, math.floor(fullPrice * (1 - Config.MERCHANT.discount))),
				cycle = visit.cycle,
				endsAt = visit.endsAt,
			})
		end
	end
	return { visit = visit, bought = false, offer = offers[1], offers = offers }
end

function Merchant.findOffer(save: any, userId: number, now: number, itemId: string): Offer?
	for _, offer in Merchant.status(save, userId, now).offers do
		if offer.itemId == itemId then
			return offer
		end
	end
	return nil
end

function Merchant.offer(save: any, userId: number, now: number): Offer?
	return Merchant.status(save, userId, now).offer
end

-- Ziyaret takibi (istemci): teklif belirince "arrived", alınmadan bitince "missed" döner; alınan teklif haber vermez.
export type Tracker = { cycle: number?, pending: boolean }

function Merchant.newTracker(): Tracker
	return { cycle = nil, pending = false }
end

function Merchant.advance(tracker: Tracker, status: Status): "arrived" | "missed" | nil
	local offer = status.offer
	if offer then
		if tracker.cycle ~= offer.cycle then
			tracker.cycle = offer.cycle
			tracker.pending = true
			return "arrived"
		end
		return nil
	end
	-- Ziyaret sürerken teklif geçici kaybolduysa (yer doldu, alındı) beklemeye devam; ziyaret bitince karar ver
	if tracker.pending and not status.visit then
		tracker.pending = false
		return "missed"
	end
	if status.bought then
		tracker.pending = false
	end
	return nil
end

return Merchant
