--!strict
-- Oyuncuya özel, sunucuda ücretlendirilen tek partilik üretim. Çevrimdışında süre dolar;
-- ödül yalnızca aynı uid bir kez teslim alındığında verilir, kendiliğinden tekrar başlamaz.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local ProductionRules = require(script.Parent.Parent.Modules.ProductionRules)
local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)

local ProductionService = {}
local highestRequest: { [Player]: number } = {}
local initialized = false

-- Tesise verilmiş hayvanların görevini bitirir (süre dolduğunda zaten döndüler; yine de kayıt temizlenir).
local function releaseProductionAnimals(data: any, recipeId: string)
	for _, animal in data.animals do
		if animal.task and animal.task.kind == "production" and animal.task.id == recipeId then
			animal.task = nil
		end
	end
end

-- detail: "start" için para tesisinin parti kimliği (yoksa ilk seçenek), "sell"/"keep" için teslim alınacak işin uid'i
local function act(player: Player, action: unknown, recipeId: unknown, detail: unknown): (boolean, string)
	if not RateLimiter.validId(recipeId) then
		return false, "Geçersiz üretim."
	end
	local recipe = Config.PRODUCTION_RECIPES[recipeId :: string]
	if not recipe or (action ~= "start" and action ~= "sell" and action ~= "keep") then
		return false, "Bilinmeyen üretim işlemi."
	end
	if detail ~= nil and not RateLimiter.validId(detail) then
		return false, "Geçersiz üretim kimliği."
	end
	if action == "start" then
		if not ProductionRules.validOption(recipe, FarmMath, detail) then
			return false, "Geçersiz üretim seçeneği."
		end
	elseif detail == nil then
		return false, "Geçersiz üretim kimliği."
	end
	local jobUid = detail
	local optionId = if action == "start" then detail :: string? else nil
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true or not PlotService.getPlot(player) then
		return false, "Çiftliğin henüz hazır değil."
	end
	local now = DateTime.now().UnixTimestampMillis / 1000
	local reward = 0
	local goodsMessage = ""
	if action == "start" then
		local allowed, reason = ProductionRules.canStart(data, recipe, FarmMath, now, optionId)
		if not allowed then
			return false, reason or "Üretim başlatılamadı."
		end
		-- Görev başlamadan önce eski durumla gelir kesilir (hayvanlar bu andan itibaren tesiste sayılır).
		EconomyService.settlePlayer(player)
		local startCost = FarmMath.getFacilityCost(data, recipe)
		local batch = FarmMath.resolveRecipe(recipe, optionId)
		local animals = FarmMath.pickProductionAnimals(data, recipe, now, optionId)
		if not animals then
			return false, `Bu üretim için boşta {batch.requiredAdults} yetişkin hayvan gerekli.`
		end
		if startCost > 0 and not PlayerDataService.trySpend(player, startCost) then
			return false, `Yeterli para yok ({FarmMath.formatMoney(startCost)}).`
		end
		local duration = FarmMath.getFacilityDuration(data, recipe, optionId)
		local readyAt = now + duration
		-- Tesise verilen hayvanlar iş boyunca gelir getirmez; ödül bu kaybın üzerinde bir tabanla garanti edilir.
		local forgone = FarmMath.estimateForgoneIncome(data, animals, duration)
		for _, animal in animals do
			animal.task = { kind = "production", id = recipe.id, startedAt = now, endsAt = readyAt }
		end
		data.production[recipe.id] = {
			uid = HttpService:GenerateGUID(false),
			readyAt = readyAt,
			startedAt = now,
			forgone = forgone,
			optionId = batch.optionId,
		}
	else
		local job = data.production[recipe.id]
		if not job or job.uid ~= jobUid then
			return false, "Bu üretim zaten teslim alındı veya artık bulunamıyor."
		end
		if now < job.readyAt then
			return false, "Üretim henüz tamamlanmadı."
		end
		if action == "keep" then
			if recipe.output ~= "chicken" then
				return false, "Bu üretim yalnızca satılabilir."
			end
			local zoneId, reason = FarmMath.findZoneForAnimal(data, "chicken")
			if not zoneId then
				return false, reason or "Kümeste yer yok; civcivi satabilirsin."
			end
			EconomyService.settlePlayer(player)
			releaseProductionAnimals(data, recipe.id)
			data.production[recipe.id] = nil
			table.insert(data.animals, {
				uid = HttpService:GenerateGUID(false),
				animalId = "chicken",
				zoneId = zoneId,
				stage = "calf",
				bornAt = now,
			})
		else
			EconomyService.settlePlayer(player)
			releaseProductionAnimals(data, recipe.id)
			data.production[recipe.id] = nil
			if recipe.output == "goods" and recipe.goodsId then
				-- Ürün merkezi: para yerine ahır deposuna ürün (sığmayan kısım eklenmez)
				local amount = FarmMath.getGoodsYield(data, recipe, now, job)
				local added = FarmMath.addGoods(data, recipe.goodsId, amount)
				local good = Config.GOODS[recipe.goodsId]
				goodsMessage = `Ahıra eklendi · {good.displayName} · +{added}`
				if added < amount then
					goodsMessage ..= " · Depo doldu"
				end
			else
				reward = FarmMath.getProductionReward(data, recipe, now, job)
				PlayerDataService.addCash(player, reward)
			end
		end
	end
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	-- Hayvanlar tesise girdi/çıktı ve bina üstündeki ilerleme çubuğu değişti: dünya yenilenir.
	local visualOk, visualError = pcall(PlotService.refreshPlayerWorld, player)
	if not visualOk then
		warn(`[Production] Üretim kaydedildi fakat görünüm yenilenemedi: {visualError}`)
	end
	return true,
		if action == "start"
			then "Üretim başladı!"
			elseif action == "keep" then "Yeni civciv kümese eklendi!"
			elseif goodsMessage ~= "" then goodsMessage
			else `Üretim satıldı: {FarmMath.formatMoney(reward)}`
end

function ProductionService.init()
	if initialized then
		return
	end
	initialized = true
	Players.PlayerRemoving:Connect(function(player: Player)
		highestRequest[player] = nil
	end)
	Remotes.get("RequestProductionAction").OnServerEvent:Connect(
		function(
			player: Player,
			action: unknown,
			recipeId: unknown,
			jobUid: unknown,
			requestId: unknown,
			expectedFarmId: unknown
		)
			if not ProductionRules.validRequestId(requestId) then
				return
			end
			local id = requestId :: number
			-- Tek artan sayaç: eski kimliklerin yeniden oynatılması sınırsız geçmiş tutmadan engellenir.
			if id <= (highestRequest[player] or 0) then
				return
			end
			highestRequest[player] = id
			if not RateLimiter.allow(player, "production", 0.5) then
				if RateLimiter.allow(player, "productionReply", 0.5) then
					Remotes.get("ProductionResult")
						:FireClient(player, id, false, "Çok hızlı işlem yapıyorsun; biraz bekle.")
				end
				return
			end
			local data = PlayerDataService.tryGet(player)
			if not data or expectedFarmId ~= data.activeMainFarmId then
				Remotes.get("ProductionResult")
					:FireClient(player, id, false, "Etkin çiftlik değişti; üretimi tekrar seç.")
				return
			end
			local ok, message = act(player, action, recipeId, jobUid)
			Remotes.get("ProductionResult"):FireClient(player, id, ok, message)
		end
	)
end

return ProductionService
