--!strict
-- Bir niyet -> bir istek; zaman aşımında otomatik tekrar alım yapılmaz.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local PurchaseController = {}
local sequence = 0
local pending: number? = nil
local sentAt = 0
local changed = Instance.new("BindableEvent")
local completed = Instance.new("BindableEvent")
PurchaseController.Changed = changed.Event
PurchaseController.Completed = completed.Event

function PurchaseController.isPending(): boolean
	return pending ~= nil
end

-- Yerel bildirim isteği (ör. yetersiz bakiye ön kontrolü); arayüz bunu bildirim olarak gösterir.
function PurchaseController.notify(success: boolean, message: string)
	completed:Fire(success, message)
	Sfx.play(if success then "success" else "error")
end

export type Detail = {
	expectedRun: number?,
	amount: number?,
	expectedCash: number?,
	offerId: string?,
	targetKind: string?,
	targetId: string?,
	uid: string?,
	expectedCost: number?,
	expectedEndsAt: number?,
	weatherId: string?,
	queueToken: string?,
	queueAction: string?,
}

function PurchaseController.submit(
	remote: Remotes.EventName,
	value: string,
	extra: (number | string | Detail)?
): boolean
	local state = ClientState.get()
	if pending or not state then
		return false
	end
	sequence += 1
	local id = sequence
	pending = id
	sentAt = os.clock()
	changed:Fire()
	Remotes.get(remote):FireServer(value, id, state.activeMainFarmId or "1", extra)
	task.delay(10, function()
		if pending ~= id then
			return
		end
		pending = nil
		ClientState.requestSnapshot()
		changed:Fire()
		completed:Fire(false, "Yanıt gecikti; durum yenileniyor. Tekrar almadan önce kontrol et.")
	end)
	return true
end

-- Tur değişince eski pencereden gelen işlem sunucuda reddedilir; niyet gönderilirken tur kimliği eklenir.
function PurchaseController.submitWithRun(remote: Remotes.EventName, value: string, detail: Detail?): boolean
	local state = ClientState.get()
	if not state or not state.progression then
		return false
	end
	local payload: Detail = if detail then table.clone(detail) else {}
	payload.expectedRun = state.progression.run
	return PurchaseController.submit(remote, value, payload)
end

-- (hedef, tutar, requestId) biçimli istek (para gönderme): etkin çiftlik bağlamı yok, kimlik aynı sayaçtan gelir (sunucuda tekrar kimlik reddedilir).
function PurchaseController.submitTargeted(remote: Remotes.EventName, target: number, amount: number): boolean
	if pending or not ClientState.get() then
		return false
	end
	sequence += 1
	local id = sequence
	pending = id
	sentAt = os.clock()
	changed:Fire()
	Remotes.get(remote):FireServer(target, amount, id)
	task.delay(10, function()
		if pending ~= id then
			return
		end
		pending = nil
		ClientState.requestSnapshot()
		changed:Fire()
		completed:Fire(false, "Yanıt gecikti; durum yenileniyor. Tekrar göndermeden önce kasanı kontrol et.")
	end)
	return true
end

Remotes.get("PurchaseResult").OnClientEvent:Connect(function(id: number, success: boolean, message: string?)
	if pending ~= id then
		return
	end
	completed:Fire(success, message)
	Sfx.play(if success then "success" else "error")
	-- Başarılı hızlı yanıt, sunucu cooldown'u bitmeden ikinci isteğe izin vermesin.
	task.delay(math.max(0, 0.55 - (os.clock() - sentAt)), function()
		if pending == id then
			pending = nil
			changed:Fire()
		end
	end)
end)
return PurchaseController
