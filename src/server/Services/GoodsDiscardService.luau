--!strict
-- Ahır deposundaki ürünü KALICI silme: seçilen adet depodan düşer, karşılığında para/iade verilmez (satıştan ayrı bir işlem).
-- Yalnız ürün adedi silinir; ekipman ve kalıcı haklar (altın/Robux ile alınanlar dahil) silinemez, bu yüzden onlar için Remote yoktur.
-- Başlamış üretimin ürünleri üretim başlarken zaten düşülür; burada silinen yalnızca depoda kalandır, bekleyen bir iş bozulmaz.
-- Ürün, adet ve miktar sınırı sunucuda doğrulanır (istemci toplamına güvenilmez); düşme ile kayıt isteği tek adımdadır,
-- tekrar oynatma `requestId` ile elenir.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Config = require(Shared:WaitForChild("Config"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local GoodsDiscard = require(Shared:WaitForChild("Modules"):WaitForChild("GoodsDiscard"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local RequestGuard = require(script.Parent:WaitForChild("RequestGuard"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))
local Metrics = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Metrics"))

local GoodsDiscardService = {}

local FARM_GUARD: RequestGuard.FarmOptions = { message = "Etkin çiftlik değişti; silinecek ürünü tekrar seç." }

function GoodsDiscardService.tryDiscard(player: Player, goodsId: unknown, amount: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "discardGoods", 0.5) then
		return false, nil
	end
	if typeof(goodsId) ~= "string" or not RateLimiter.validId(goodsId) or not Config.GOODS[goodsId] then
		return false, "Bilinmeyen ürün"
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true then
		return false, "Çiftliğin henüz hazır değil"
	end
	local available = FarmMath.getGoodsAmount(data, goodsId)
	if available < 1 then
		return false, "Silinecek ürün yok"
	end
	local count = GoodsDiscard.validAmount(amount, available)
	if not count or not FarmMath.removeGoods(data, goodsId, count) then
		return false, "Geçersiz miktar"
	end
	Metrics.increment("ItemsDiscarded", count)
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	return true, `Ürün silindi · {Config.GOODS[goodsId].displayName} · {count} adet`
end

function GoodsDiscardService.init()
	Remotes.get("RequestDiscardGoods").OnServerEvent
		:Connect(
			function(player: Player, goodsId: unknown, requestId: unknown, expectedFarmId: unknown, amount: unknown)
				if not RateLimiter.acceptRequest(player, requestId) then
					return
				end
				if not RequestGuard.activeFarm(player, requestId, expectedFarmId, FARM_GUARD) then
					return
				end
				local ok, message = GoodsDiscardService.tryDiscard(player, goodsId, amount)
				RequestGuard.reply(player, requestId, ok, message)
			end
		)
end

return GoodsDiscardService
