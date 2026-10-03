--!strict
-- Üretim partisini başlatma ve teslim alma çekirdeği. Roblox nesnelerinden bağımsızdır: elle işlem (ProductionService) ve
-- yardımcı (PetService) aynı kuralları kullanır.
--   root : kök kayıt (hesap düzeyi: ortak ahır deposu ve para burada)
--   farm : üretimin yapıldığı çiftlik görünümü (etkin çiftlikte root ile aynı tablo; park edilmiş çiftlikte kaydı)
-- hooks: settle() görev değişmeden önce geliri keser; trySpend/addCash cüzdan; newUid iş kimliği üretir.
local ProductionRules = require(script.Parent:WaitForChild("ProductionRules"))

local ProductionLogic = {}

export type Hooks = {
	settle: () -> (),
	trySpend: (amount: number) -> boolean,
	addCash: (amount: number) -> (),
	newUid: () -> string,
}

-- Tesise verilmiş hayvanların görevini bitirir (süre dolduğunda zaten döndüler; yine de kayıt temizlenir).
function ProductionLogic.releaseAnimals(farm: any, recipeId: string)
	for _, animal in farm.animals do
		if animal.task and animal.task.kind == "production" and animal.task.id == recipeId then
			animal.task = nil
		end
	end
end

-- Partiyi başlatır. Başarısızlıkta hiçbir şey değişmez; (false, sebep) döner.
function ProductionLogic.start(
	root: any,
	farm: any,
	recipe: any,
	optionId: string?,
	now: number,
	farmMath: any,
	hooks: Hooks
): (boolean, string?)
	local allowed, reason = ProductionRules.canStart(farm, recipe, farmMath, now, optionId, root)
	if not allowed then
		return false, reason or "Üretim başlatılamadı."
	end
	-- Görev başlamadan önce eski durumla gelir kesilir (hayvanlar bu andan itibaren tesiste sayılır).
	hooks.settle()
	local startCost = farmMath.getFacilityCost(farm, recipe)
	local batch = farmMath.resolveRecipe(recipe, optionId)
	local animals = farmMath.pickProductionAnimals(farm, recipe, now, optionId)
	if not animals then
		return false, `Bu üretim için boşta {batch.requiredAdults} yetişkin hayvan gerekli.`
	end
	if startCost > 0 and not hooks.trySpend(startCost) then
		return false, `Yeterli para yok ({farmMath.formatMoney(startCost)}).`
	end
	local duration = farmMath.getFacilityDuration(farm, recipe, optionId)
	local readyAt = now + duration
	-- Tesise verilen hayvanlar iş boyunca gelir getirmez; ödül bu kaybın üzerinde bir tabanla garanti edilir.
	local forgone = farmMath.estimateForgoneIncome(farm, animals, duration, now)
	for _, animal in animals do
		animal.task = { kind = "production", id = recipe.id, startedAt = now, endsAt = readyAt }
	end
	farm.production[recipe.id] = {
		uid = hooks.newUid(),
		readyAt = readyAt,
		startedAt = now,
		forgone = forgone,
		startCost = startCost,
		optionId = batch.optionId,
	}
	return true, nil
end

-- Yardımcı için: hazır partiyi zarar etmeden teslim alabilir miyiz? (ürün merkezinde depoda yer olmalı; boşa gitmesin)
function ProductionLogic.canClaimAutomatically(
	root: any,
	farm: any,
	recipe: any,
	job: any,
	now: number,
	farmMath: any
): boolean
	if job.readyAt > now then
		return false
	end
	if recipe.output == "chicken" then
		-- Civciv kümese eklenir; yer yoksa teslim bekler (elle teslimdeki "Kümeste yer yok" kuralıyla aynı)
		return farmMath.findZoneForAnimal(farm, "chicken") ~= nil
	end
	if recipe.output == "goods" and recipe.goodsId then
		local yield = farmMath.getGoodsYield(farm, recipe, now, job)
		-- Kapasiteyi aşan kısım teslimde paraya çevrilir; yalnızca sığabilecek kısım için yer aranır
		return farmMath.getGoodsSpace(root, recipe.goodsId) >= math.min(yield, farmMath.getGoodsCap(root))
	end
	return true
end

-- Hazır partiyi teslim alır (süresi dolmuş olmalı; çağıran kontrol eder). Döner: (nakit ödül, ürün bildirimi).
-- Ürün ortak depoya gider; yüksek gelir bonusunda miktar tavanının bozduğu asgari getiri nakitle tamamlanır.
function ProductionLogic.claim(
	root: any,
	farm: any,
	recipe: any,
	job: any,
	now: number,
	farmMath: any,
	config: any,
	hooks: Hooks
): (number, string)
	hooks.settle()
	ProductionLogic.releaseAnimals(farm, recipe.id)
	farm.production[recipe.id] = nil
	if recipe.output == "goods" and recipe.goodsId then
		local amount = farmMath.getGoodsYield(farm, recipe, now, job)
		local added = farmMath.addGoods(root, recipe.goodsId, amount)
		local good = config.GOODS[recipe.goodsId]
		local message = `Ahıra eklendi · {good.displayName} · +{added}`
		-- Depoya sığmayan kısım "Hepsini sat" ile aynı oranla paraya çevrilir (boşa gitmez; satıştan kaçak olmasın)
		local overflow = amount - added
		local cash = if overflow > 0 then farmMath.getGoodsSellValue(recipe.goodsId, overflow) else 0
		-- Depo taşmasının indirimli satışı aynı kalır; telafi yalnız parti miktar tavanındaki farktır.
		local compensation = farmMath.getGoodsCompensation(farm, recipe, job, now, amount)
		cash += compensation
		if cash > 0 then
			hooks.addCash(cash)
			message = `{message} · Nakit karşılık · +{farmMath.formatMoney(cash)}`
		end
		return cash, message
	end
	local reward = farmMath.getProductionReward(farm, recipe, now, job)
	hooks.addCash(reward)
	return reward, ""
end

-- Kuluçka partisini teslim alır: civciv kümese eklenir (para yok). Yer yoksa hiçbir şey değişmez; (false, sebep) döner.
function ProductionLogic.claimChicken(
	farm: any,
	recipe: any,
	now: number,
	farmMath: any,
	hooks: Hooks
): (boolean, string?)
	local zoneId, reason = farmMath.findZoneForAnimal(farm, "chicken")
	if not zoneId then
		return false, reason or "Kümeste yer yok; civcivi satabilirsin."
	end
	hooks.settle()
	ProductionLogic.releaseAnimals(farm, recipe.id)
	farm.production[recipe.id] = nil
	table.insert(farm.animals, {
		uid = hooks.newUid(),
		animalId = "chicken",
		zoneId = zoneId,
		stage = "calf",
		bornAt = now,
	})
	return true, nil
end

export type PetSlot = { kind: string, island: string }

-- Yardımcı türü (tek kaynak: FarmMath.petKindFor): ürün merkezi "goods", para fabrikası ve kuluçka "cash".
function ProductionLogic.petKind(recipe: any, farmMath: any): string?
	return farmMath.petKindFor(recipe)
end

-- Bir çiftlikte yardımcı duran (tür, ada) yuvaları: o türün yardımcısı alınmış ve o adada kurulu en az bir tesis var.
function ProductionLogic.petSlots(farm: any, recipeOrder: { string }, farmMath: any, config: any): { PetSlot }
	local slots: { PetSlot } = {}
	local seen: { [string]: boolean } = {}
	for _, recipeId in recipeOrder do
		local recipe = config.PRODUCTION_RECIPES[recipeId]
		local kind = ProductionLogic.petKind(recipe, farmMath)
		if
			kind
			and farmMath.hasPet(farm, kind)
			and farm.purchased[recipe.upgradeId]
			and farm.unlockedIslands[recipe.island]
		then
			local petIsland = farmMath.petIsland(recipe)
			local key = `{kind}:{petIsland}`
			if not seen[key] then
				seen[key] = true
				table.insert(slots, { kind = kind, island = petIsland })
			end
		end
	end
	return slots
end

export type PetSummary = {
	changedFarms: { [string]: boolean },
	cash: number,
	goodsMessages: { string },
	started: number,
	messages: { string }, -- "Yardımcı · Tesis · miktar" bildirimleri (her teslim için bir satır)
	claims: { [string]: { [string]: number } }, -- çiftlik → "tür:ada" (ör. "goods:poultry") → yardımcının teslim ettiği parti sayısı
}

-- Yardımcılar: sahip olunan her çiftlikte (etkin ya da park edilmiş) hazır partileri teslim alır ve "otomatik tekrar"
-- açıksa yenisini başlatır. Para yardımcısı para fabrikalarını, ürün yardımcısı ürün merkezlerini yönetir.
-- farmIds/getView: çiftlik kimlikleri ve görünümleri; root: hesap kaydı (ortak ürün deposu ve cüzdan).
-- Hiçbir şey kaybolmaz: ürün merkezi teslimi depoda yer yoksa bekler, başlatma para/hayvan/depo yetersizse atlanır.
function ProductionLogic.runPets(
	root: any,
	farmIds: { string },
	getView: (farmId: string) -> any,
	recipeOrder: { string },
	now: number,
	farmMath: any,
	config: any,
	hooks: Hooks
): PetSummary
	local summary: PetSummary =
		{ changedFarms = {}, cash = 0, goodsMessages = {}, started = 0, messages = {}, claims = {} }
	for _, farmId in farmIds do
		local farm = getView(farmId)
		if not farm or not farm.production then
			continue
		end
		for _, recipeId in recipeOrder do
			local recipe = config.PRODUCTION_RECIPES[recipeId]
			local kind = ProductionLogic.petKind(recipe, farmMath)
			if
				not kind
				or not farmMath.hasPet(farm, kind)
				or not farm.purchased[recipe.upgradeId]
				or not farm.unlockedIslands[recipe.island]
			then
				continue
			end
			local job = farm.production[recipeId]
			if job and ProductionLogic.canClaimAutomatically(root, farm, recipe, job, now, farmMath) then
				local reward, message = 0, ""
				if recipe.output == "chicken" then
					if ProductionLogic.claimChicken(farm, recipe, now, farmMath, hooks) then
						message = "Civciv kümese eklendi"
					end
				else
					reward, message = ProductionLogic.claim(root, farm, recipe, job, now, farmMath, config, hooks)
				end
				summary.cash += reward
				local petName = if kind == "cash" then "Para Yardımcısı" else "Ürün Yardımcısı"
				table.insert(
					summary.messages,
					if kind == "cash"
						then (if recipe.output == "chicken"
							then `{petName} · {recipe.displayName} · {message}`
							else `{petName} · {recipe.displayName} · +{farmMath.formatMoney(reward)}`)
						else `{petName} · {recipe.displayName} · {message}`
				)
				if message ~= "" and recipe.output ~= "chicken" then
					table.insert(summary.goodsMessages, message)
				end
				summary.changedFarms[farmId] = true
				local counts = summary.claims[farmId]
				if not counts then
					counts = {}
					summary.claims[farmId] = counts
				end
				local key = `{kind}:{farmMath.petIsland(recipe)}`
				counts[key] = (counts[key] or 0) + 1
			end
			local repeatOption = if farm.autoRepeat then farm.autoRepeat[recipeId] else nil
			if farm.production[recipeId] == nil and repeatOption ~= nil then
				local optionId = if repeatOption == "default" then nil else repeatOption
				local started = ProductionLogic.start(root, farm, recipe, optionId, now, farmMath, hooks)
				if started then
					summary.started += 1
					summary.changedFarms[farmId] = true
				end
			end
		end
	end
	return summary
end

return ProductionLogic
