--!strict
-- Telemetri saf mantığı (Roblox'a dokunmaz): olay adları, değer yuvarlama, toplama ve gönderim bütçesi.
-- AnalyticsService çağrıları Services/TelemetryService'tedir; burası test edilebilir kuralları tutar.

export type EconomyCategory = {
	flow: "Source" | "Sink",
	transaction: string, -- AnalyticsService transactionType (deneyim başına en çok 20 farklı değer)
	batched: boolean, -- yüksek frekanslı: olay başına değil, oyuncu başına toplanıp periyodik gönderilir
}

export type Batch = { key: string, amount: number, count: number, balance: number }

local TelemetryLogic = {}

TelemetryLogic.CURRENCY = "Cash" -- deneyim başına en çok 5 para birimi
TelemetryLogic.FLUSH_SECONDS = 60
-- AnalyticsService'in belgelenmiş bir dakikalık sınırı yok; sunucu başına muhafazakâr iç bütçe.
TelemetryLogic.EVENTS_PER_MINUTE = 120
TelemetryLogic.MAX_AMOUNT = 1e15

TelemetryLogic.ECONOMY = {
	-- Kaynaklar
	collect = { flow = "Source", transaction = "Collect", batched = true },
	autoCollect = { flow = "Source", transaction = "AutoCollect", batched = true },
	parkedPay = { flow = "Source", transaction = "ParkedPay", batched = true },
	offline = { flow = "Source", transaction = "Offline", batched = false },
	daily = { flow = "Source", transaction = "Daily", batched = false },
	season = { flow = "Source", transaction = "Season", batched = false },
	golden = { flow = "Source", transaction = "GoldenAnimal", batched = false },
	order = { flow = "Source", transaction = "Order", batched = false },
	production = { flow = "Source", transaction = "Production", batched = true },
	achievement = { flow = "Source", transaction = "Achievement", batched = false },
	iap = { flow = "Source", transaction = "IncomePack", batched = false },
	refund = { flow = "Source", transaction = "Refund", batched = false },
	-- Giderler
	animal = { flow = "Sink", transaction = "Animal", batched = false },
	upgrade = { flow = "Sink", transaction = "Upgrade", batched = false },
	expansion = { flow = "Sink", transaction = "Expansion", batched = false },
	item = { flow = "Sink", transaction = "Item", batched = false },
	farm = { flow = "Sink", transaction = "Farm", batched = false },
	lineage = { flow = "Sink", transaction = "Lineage", batched = false },
	facility = { flow = "Sink", transaction = "Facility", batched = false },
} :: { [string]: EconomyCategory }

-- Onboarding hunisi: adım numarası benzersiz ve 1'den başlar (Roblox 1-100 kabul eder).
TelemetryLogic.FUNNEL = {
	first_collect = { step = 1, name = "First collect" },
	first_animal = { step = 2, name = "First animal" },
	first_upgrade = { step = 3, name = "First upgrade" },
	first_island = { step = 4, name = "First island" },
	barn_2 = { step = 5, name = "Barn level 2" },
} :: { [string]: { step: number, name: string } }

-- Deneyim başına benzersiz özel olay adı sayısı sınırlı (100); yalnızca bu listedekiler gönderilir.
TelemetryLogic.CUSTOM_EVENTS = {
	SessionSeconds = true,
	OfflineSeconds = true,
	OfflineCapped = true,
	StorageFullSeconds = true,
	IslandUnlocked = true,
	FarmUnlocked = true,
	BarnLevel = true,
	SaveFailed = true,
	FinalSaveFailed = true,
	FinalSaveAbandoned = true,
	ProfileRecovered = true,
	ProfileLoadFailed = true,
	LoadLockWait = true,
	LoopError = true,
} :: { [string]: boolean }

-- Pozitif tam sayıya yuvarlar; sonlu olmayan, 0'dan küçük ya da 1'in altındaki değer nil (gönderilmez).
function TelemetryLogic.roundAmount(value: unknown): number?
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	local rounded = math.floor(math.min(value, TelemetryLogic.MAX_AMOUNT) + 0.5)
	return if rounded >= 1 then rounded else nil
end

-- Bakiye 0'dan küçük olamaz (AnalyticsService şartı).
function TelemetryLogic.roundBalance(value: unknown): number
	if typeof(value) ~= "number" or value ~= value or value < 0 then
		return 0
	end
	return math.floor(math.min(value, TelemetryLogic.MAX_AMOUNT) + 0.5)
end

-- Kayıttan hunide hangi adımlar zaten geçilmiş (yeniden girişte aynı adım tekrar gönderilmez; kayıt şeması değişmez).
export type Facts = {
	lifetimeEarned: number,
	animalCount: number,
	purchasedCount: number,
	extraIslands: number,
	barnLevel: number,
}

function TelemetryLogic.funnelReached(facts: Facts): { [string]: boolean }
	return {
		first_collect = facts.lifetimeEarned > 0,
		first_animal = facts.animalCount > 0,
		first_upgrade = facts.purchasedCount > 0,
		first_island = facts.extraIslands > 0,
		barn_2 = facts.barnLevel >= 2,
	}
end

-- Çiftlik görünümlerinden (FarmProfiles.view) huni bilgileri: bir çiftlikte bile yapıldıysa o adım geçilmiştir.
function TelemetryLogic.factsFromViews(views: { any }): Facts
	local facts: Facts = { lifetimeEarned = 0, animalCount = 0, purchasedCount = 0, extraIslands = 0, barnLevel = 1 }
	for _, view in views do
		local earned = view.lifetimeEarned
		if typeof(earned) == "number" then
			facts.lifetimeEarned = math.max(facts.lifetimeEarned, earned)
		end
		if typeof(view.animals) == "table" then
			facts.animalCount = math.max(facts.animalCount, #view.animals)
		end
		local purchased = 0
		if typeof(view.purchased) == "table" then
			for _ in view.purchased do
				purchased += 1
			end
		end
		facts.purchasedCount = math.max(facts.purchasedCount, purchased)
		local islands = 0
		if typeof(view.unlockedIslands) == "table" then
			for _ in view.unlockedIslands do
				islands += 1
			end
		end
		facts.extraIslands = math.max(facts.extraIslands, islands - 1) -- "home" her zaman açık
		if typeof(view.barnLevel) == "number" then
			facts.barnLevel = math.max(facts.barnLevel, view.barnLevel)
		end
	end
	return facts
end

-- Oyuncu başına toplayıcı: yüksek frekanslı kaynaklar burada birikir, periyodik drain ile tek olay olur.
export type Aggregator = { totals: { [string]: Batch } }

function TelemetryLogic.newAggregator(): Aggregator
	return { totals = {} }
end

function TelemetryLogic.add(aggregator: Aggregator, key: string, amount: number, balance: number)
	local entry = aggregator.totals[key]
	if not entry then
		entry = { key = key, amount = 0, count = 0, balance = 0 }
		aggregator.totals[key] = entry
	end
	entry.amount += amount
	entry.count += 1
	entry.balance = balance
end

-- Birikenleri anahtar sırasıyla döndürür ve sıfırlar.
function TelemetryLogic.drain(aggregator: Aggregator): { Batch }
	local list: { Batch } = {}
	for _, entry in aggregator.totals do
		table.insert(list, entry)
	end
	table.sort(list, function(a: Batch, b: Batch): boolean
		return a.key < b.key
	end)
	aggregator.totals = {}
	return list
end

-- Jeton kovası: dakikada `limit` olay; boşalınca olay düşer (çağıran sayar).
export type Budget = { limit: number, tokens: number, updatedAt: number }

function TelemetryLogic.newBudget(limit: number, now: number): Budget
	return { limit = limit, tokens = limit, updatedAt = now }
end

function TelemetryLogic.allow(budget: Budget, now: number): boolean
	local elapsed = math.max(0, now - budget.updatedAt)
	budget.updatedAt = now
	budget.tokens = math.min(budget.limit, budget.tokens + elapsed * budget.limit / 60)
	if budget.tokens >= 1 then
		budget.tokens -= 1
		return true
	end
	return false
end

return TelemetryLogic
