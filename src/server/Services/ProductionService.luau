--!strict
-- Oyuncuya özel, sunucuda ücretlendirilen tek partilik üretim. Çevrimdışında süre dolar;
-- ödül yalnızca aynı uid bir kez teslim alındığında verilir. Yardımcı (pet) varsa ve "otomatik tekrar" açıksa
-- PetService hazır partiyi teslim alıp aynı seçenekle yenisini başlatır (çekirdek: Modules/ProductionLogic).
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
local TutorialProgress = require(script.Parent.Parent.Modules.TutorialProgress)
local OnboardingSteps = require(Shared:WaitForChild("Modules"):WaitForChild("OnboardingSteps"))
local ProductionRules = require(script.Parent.Parent.Modules.ProductionRules)
local ProductionLogic = require(script.Parent.Parent.Modules.ProductionLogic)
local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local TelemetryService = require(script.Parent:WaitForChild("TelemetryService"))

local ProductionService = {}
local highestRequest: { [Player]: number } = {}
local initialized = false

-- Oyuncunun cüzdanına bağlı kancalar (elle işlem ve yardımcı aynı çekirdeği kullanır)
local function hooksFor(player: Player): ProductionLogic.Hooks
	return {
		settle = function()
			EconomyService.settlePlayer(player)
		end,
		trySpend = function(amount: number): boolean
			return PlayerDataService.trySpend(player, amount, "facility")
		end,
		addCash = function(amount: number)
			PlayerDataService.addCash(player, amount, "production")
		end,
		addRefund = function(amount: number)
			PlayerDataService.addRefund(player, amount, "refund")
		end,
		newUid = function(): string
			return HttpService:GenerateGUID(false)
		end,
	}
end

-- detail: "start" için para tesisinin parti kimliği (yoksa ilk seçenek), "sell"/"keep"/"cancel" için işin uid'i,
-- "auto": parti kimliği ("off" kapat, "fill" ürün deposu, nil sipariş stoğu).
local function act(player: Player, action: unknown, recipeId: unknown, detail: unknown): (boolean, string)
	if not RateLimiter.validId(recipeId) then
		return false, "Geçersiz üretim."
	end
	local recipe = Config.PRODUCTION_RECIPES[recipeId :: string]
	if
		not recipe
		or (action ~= "start" and action ~= "sell" and action ~= "keep" and action ~= "auto" and action ~= "cancel")
	then
		return false, "Bilinmeyen üretim işlemi."
	end
	if detail ~= nil and not RateLimiter.validId(detail) then
		return false, "Geçersiz üretim kimliği."
	end
	if action == "start" then
		if not ProductionRules.validOption(recipe, FarmMath, detail) then
			return false, "Geçersiz üretim seçeneği."
		end
	elseif action == "auto" then
		if
			detail ~= "off"
			and not (detail == "fill" and recipe.output == "goods")
			and not ProductionRules.validOption(recipe, FarmMath, detail)
		then
			return false, "Geçersiz üretim seçeneği."
		end
	elseif detail == nil then
		return false, "Geçersiz üretim kimliği."
	end
	local jobUid = detail
	local optionId = if action == "start" or action == "auto" then detail :: string? else nil
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true or not PlotService.getPlot(player) then
		return false, "Çiftliğin henüz hazır değil."
	end
	local now = DateTime.now().UnixTimestampMillis / 1000
	local hooks = hooksFor(player)
	local reward = 0
	local goodsMessage = ""
	if action == "auto" then
		-- Yardımcı (pet) ile otomatik tekrar: açıkken yardımcı hazır partiyi teslim alır ve aynı seçenekle yenisini başlatır
		if detail == "off" then
			data.autoRepeat[recipe.id] = nil
		else
			if not data.purchased[recipe.upgradeId] or not data.unlockedIslands[recipe.island] then
				return false, "Önce bu üretim binasını açmalısın."
			end
			local kind = FarmMath.petKindFor(recipe)
			if not kind or not FarmMath.hasPet(data, kind) then
				return false, "Bunun için önce yardımcı almalısın."
			end
			data.autoRepeat[recipe.id] = optionId or "default"
		end
	elseif action == "start" then
		local ok, reason = ProductionLogic.start(data, data, recipe, optionId, now, FarmMath, hooks)
		if not ok then
			return false, reason or "Üretim başlatılamadı."
		end
		TelemetryService.funnel(player, "first_production") -- oyuncu başına bir kez (servis kendisi tekrarı eler)
		-- İlk parti başlayınca öğretici 4. adımı geçer (aşama hesaba yazılır, parti bitip alınsa da geri gelmez); öğreticiyi bitirmez:
		-- sonraki adımlar (sipariş, geliştirme, eşya, rebirth) sürer.
		TutorialProgress.observe(data, OnboardingSteps, player)
		-- Tekrar açıksa son elle seçilen parti tekrarlanır
		if data.autoRepeat[recipe.id] ~= nil and data.autoRepeat[recipe.id] ~= "fill" then
			data.autoRepeat[recipe.id] = optionId or "default"
		end
	elseif action == "cancel" then
		local cancelled, reason = ProductionLogic.cancel(data, recipe, jobUid :: string, now, hooks)
		if not cancelled then
			return false, reason or "Üretim iptal edilemedi."
		end
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
			local kept, reason = ProductionLogic.claimChicken(data, recipe, now, FarmMath, hooks)
			if not kept then
				return false, reason or "Kümeste yer yok; civcivi satabilirsin."
			end
		else
			reward, goodsMessage = ProductionLogic.claim(data, data, recipe, job, now, FarmMath, Config, hooks)
		end
	end
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	-- Hayvanlar tesise girdi/çıktı ve bina üstündeki ilerleme çubuğu değişti: dünya yenilenir.
	local visualOk, visualError = pcall(function(): boolean
		PlotService.refreshPlayerWorld(player)
		return true
	end)
	if not visualOk then
		warn(`[Production] Üretim kaydedildi fakat görünüm yenilenemedi: {visualError}`)
	end
	return true,
		if action == "start"
			then "Üretim başladı!"
			elseif action == "auto" then (if detail == "off"
				then "Otomatik tekrar kapandı."
				else "Otomatik tekrar açıldı.")
			elseif
				action == "cancel"
			then "Üretim iptal edildi; ödenen ücret iade edildi ve otomatik tekrar kapatıldı."
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
