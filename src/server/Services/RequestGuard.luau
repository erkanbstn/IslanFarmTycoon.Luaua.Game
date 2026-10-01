--!strict
-- Talep (Remote) işleyicilerinin ortak savunma ve cevap yardımcıları. "Doğrula → sınırla → hesapla → kaydet → pushState"
-- sırasının başındaki iki ortak adım tek yerde durur: etkin çiftlik kontrolü ve hız sınırı cevabı. Servisler bunu
-- elle kopyalamaz; mesajlar ve cevap yolu (PurchaseResult / Notify) burada değişir.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))
local Metrics = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Metrics"))

local RequestGuard = {}

RequestGuard.THROTTLE_MESSAGE = "Çok hızlı işlem yapıyorsun; biraz bekle."
RequestGuard.FARM_CHANGED_MESSAGE = "Etkin çiftlik değişti; işlemi yeni çiftlikte tekrar seç."

export type FarmOptions = {
	message: string?, -- varsayılan: FARM_CHANGED_MESSAGE
	notifyWithoutId: boolean?, -- istek kimliği yoksa (eski istemci) Notify ile bildir; yoksa sessiz
	countRejected: boolean?, -- cevap "PurchaseRejected" sayacına yazılsın
}

-- Satın alma ailesinin cevabı: kimlik varsa PurchaseResult, yoksa Notify. `message` nil ve ok=false hız sınırı demektir
-- (servislerin tryX işlevleri spam'i sessizce nil mesajla döndürür); bu cevap da sınırlanır. Cevap gittiyse true döner.
function RequestGuard.reply(
	player: Player,
	requestId: unknown,
	ok: boolean,
	message: string?,
	countRejected: boolean?
): boolean
	local text = message
	if not ok and text == nil then
		if typeof(requestId) ~= "number" or not RateLimiter.allow(player, "purchaseThrottleReply", 0.5) then
			return false
		end
		text = RequestGuard.THROTTLE_MESSAGE
	end
	if text == nil then
		return false
	end
	if not ok and countRejected then
		Metrics.increment("PurchaseRejected")
	end
	if typeof(requestId) == "number" then
		Remotes.get("PurchaseResult"):FireClient(player, requestId, ok, text)
	else
		Remotes.get("Notify"):FireClient(player, text, if ok then "success" else "error")
	end
	return true
end

-- İstemcinin gördüğü etkin çiftlik hâlâ sunucudakiyle aynı mı? Aynıysa oyuncunun kaydını döndürür; değilse (ya da kayıt
-- yoksa) oyuncuya söyler (sınırlı) ve nil döner. Çağıran nil'de işlemi bırakır.
function RequestGuard.activeFarm(
	player: Player,
	requestId: unknown,
	expectedFarmId: unknown,
	options: FarmOptions?
): any?
	local data = PlayerDataService.tryGet(player)
	if data and expectedFarmId == data.activeMainFarmId then
		return data
	end
	local canReply = typeof(requestId) == "number" or (options ~= nil and options.notifyWithoutId == true)
	if canReply and RateLimiter.allow(player, "farmContextReply", 0.5) then
		local message = if options and options.message then options.message else RequestGuard.FARM_CHANGED_MESSAGE
		RequestGuard.reply(player, requestId, false, message, options ~= nil and options.countRejected == true)
	end
	return nil
end

return RequestGuard
