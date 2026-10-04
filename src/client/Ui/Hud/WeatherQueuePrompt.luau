--!strict
-- Sunucunun süreli teklifini onaylar; kuyruğa girene kadar asa hakkı harcanmaz.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))
local HudCommon = require(script.Parent:WaitForChild("HudCommon"))

local WeatherQueuePrompt = {}
type Entry = {
	kind: string,
	itemId: string,
	weatherId: string,
	token: string?,
	ownerName: string?,
	weatherName: string?,
	endsAt: number?,
	startsAt: number,
	expiresAt: number?,
	position: number?,
}
export type Panel = { open: () -> (), hasEntry: () -> boolean }

function WeatherQueuePrompt.create(screenGui: Instance): Panel
	local window = UiKit.window(screenGui, {
		title = "Hava sırası",
		icon = "🌤️",
		tint = UiKit.Color.Blue,
		width = 500,
		maxHeight = 440,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	local card = UiKit.card(window.list, 1, "🌤️")
	local timing = UiKit.text(window.list, "", "Body")
	timing.LayoutOrder = 2
	local note = UiKit.text(window.list, "", "Caption", UiKit.Color.TextMuted)
	note.LayoutOrder = 3
	local cancel = UiKit.button(window.list, "Vazgeç", "secondary")
	cancel.LayoutOrder = 4
	local entry: Entry? = nil

	local function render()
		local current = entry
		if not current then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local weather = Config.WEATHER[current.weatherId]
		UiKit.setText(card.title, `Seçtiğin hava: {weather.displayName}`)
		if current.kind == "offer" then
			UiKit.setText(card.detail, `Şu an {current.ownerName} tarafından kullanılan hava: {current.weatherName}`)
			UiKit.setText(
				timing,
				`Mevcut etki {math.max(0, math.ceil((current.endsAt or now) - now))} saniye sonra sona erecek.`
			)
			local expired = now >= (current.expiresAt or now)
			UiKit.setText(
				note,
				if expired
					then "Teklifin süresi doldu. Asayı yeniden kullanarak kontrol et."
					else "Sıraya alınsın mı? Hakkın yalnızca etki başladığında kullanılır."
			)
			HudCommon.setPurchaseButton(card.action, "Sıraya al", if expired then "disabled" else "primary")
			HudCommon.setPurchaseButton(cancel, "Vazgeç", "secondary")
		else
			UiKit.setText(card.detail, `Sıradaki yerin: {current.position or 1}`)
			UiKit.setText(timing, `Tahmini başlangıç: {math.max(0, math.ceil(current.startsAt - now))} saniye sonra`)
			UiKit.setText(note, "Etkin başlamadan sıradan çıkabilirsin; asa hakkın harcanmaz.")
			card.action.Visible = false
			HudCommon.setPurchaseButton(cancel, "Sıradan çık", "secondary")
		end
	end
	card.action.Activated:Connect(function()
		local current = entry
		if
			current
			and current.kind == "offer"
			and card.action.Active
			and Workspace:GetServerTimeNow() < (current.expiresAt or 0)
		then
			PurchaseController.submit(
				"RequestUseItem",
				current.itemId,
				{ weatherId = current.weatherId, queueToken = current.token }
			)
		end
	end)
	cancel.Activated:Connect(function()
		local current = entry
		if not current or not cancel.Active then
			return
		end
		if current.kind == "queued" then
			PurchaseController.submit("RequestUseItem", current.itemId, { queueAction = "cancel" })
		else
			entry = nil
			window.close()
		end
	end)
	local eventConnection = Remotes.get("WeatherQueueOffer").OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.kind == "closed" then
			entry = nil
			window.close()
			return
		end
		if
			(payload.kind ~= "offer" and payload.kind ~= "queued")
			or typeof(payload.itemId) ~= "string"
			or typeof(payload.weatherId) ~= "string"
			or not Config.WEATHER[payload.weatherId]
			or typeof(payload.startsAt) ~= "number"
		then
			return
		end
		if
			payload.kind == "offer"
			and (
				typeof(payload.token) ~= "string"
				or typeof(payload.ownerName) ~= "string"
				or typeof(payload.weatherName) ~= "string"
				or typeof(payload.endsAt) ~= "number"
				or typeof(payload.expiresAt) ~= "number"
			)
		then
			return
		end
		local shouldOpen = payload.kind == "offer" or not entry or entry.kind ~= payload.kind
		entry = payload
		card.action.Visible = payload.kind == "offer"
		if shouldOpen then
			UiKit.showWindow(window)
		end
		if window.isOpen() then
			render()
		end
	end)
	local pendingConnection = PurchaseController.Changed:Connect(function()
		if window.isOpen() then
			render()
		end
	end)
	local visibleConnection = window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.isOpen() then
			render()
		end
	end)
	window.frame.Destroying:Connect(function()
		eventConnection:Disconnect()
		pendingConnection:Disconnect()
		visibleConnection:Disconnect()
		entry = nil
	end)
	task.spawn(function()
		while window.frame.Parent do
			task.wait(1)
			if window.isOpen() then
				render()
			end
		end
	end)
	return {
		open = function()
			if entry then
				UiKit.showWindow(window)
				render()
			end
		end,
		hasEntry = function(): boolean
			return entry ~= nil
		end,
	}
end

return WeatherQueuePrompt
