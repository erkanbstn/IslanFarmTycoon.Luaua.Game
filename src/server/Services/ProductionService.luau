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

local function act(player: Player, action: unknown, recipeId: unknown, jobUid: unknown): (boolean, string)
	if not RateLimiter.validId(recipeId) then
		return false, "Geçersiz üretim."
	end
	local recipe = Config.PRODUCTION_RECIPES[recipeId :: string]
	if not recipe or (action ~= "start" and action ~= "sell" and action ~= "keep") then
		return false, "Bilinmeyen üretim işlemi."
	end
	if (action == "start" and jobUid ~= nil) or (action ~= "start" and not RateLimiter.validId(jobUid)) then
		return false, "Geçersiz üretim kimliği."
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true or not PlotService.getPlot(player) then
		return false, "Çiftliğin henüz hazır değil."
	end
	local now = DateTime.now().UnixTimestampMillis / 1000
	if action == "start" then
		local allowed, reason = ProductionRules.canStart(data, recipe, FarmMath, now)
		if not allowed then
			return false, reason or "Üretim başlatılamadı."
		end
		EconomyService.settlePlayer(player)
		if not PlayerDataService.trySpend(player, recipe.cost) then
			return false, `Yeterli para yok ({FarmMath.formatMoney(recipe.cost)}).`
		end
		data.production[recipe.id] = { uid = HttpService:GenerateGUID(false), readyAt = now + recipe.duration }
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
			data.production[recipe.id] = nil
			table.insert(data.animals, {
				uid = HttpService:GenerateGUID(false),
				animalId = "chicken",
				zoneId = zoneId,
				stage = "calf",
				bornAt = now,
			})
		else
			data.production[recipe.id] = nil
			PlayerDataService.addCash(player, recipe.reward)
		end
	end
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	if action == "keep" then
		local visualOk, visualError = pcall(PlotService.refreshPlayerWorld, player)
		if not visualOk then
			warn(`[Production] Civciv kaydedildi fakat görünüm yenilenemedi: {visualError}`)
		end
	end
	return true,
		if action == "start"
			then "Üretim başladı!"
			elseif action == "keep" then "Yeni civciv kümese eklendi!"
			else `Üretim satıldı: {FarmMath.formatMoney(recipe.reward)}`
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
