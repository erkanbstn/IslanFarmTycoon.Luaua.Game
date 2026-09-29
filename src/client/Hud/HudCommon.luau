--!strict
-- HUD pencerelerinin ortak yardımcıları: satın alma düğmesi durumu ve "ne zaman alırım" ipucu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent:WaitForChild("PurchaseController"))

type PlayerSave = GameTypes.PlayerSave

local localPlayer = Players.LocalPlayer

local function secondsToText(seconds: number): string
	return if seconds < 60 then `{math.ceil(seconds)} sn` else `{math.ceil(seconds / 60)} dk`
end

local function purchaseHint(state: PlayerSave, price: number, income: number): string
	if state.cash >= price then
		return "Alabilirsin!"
	end
	if not FarmMath.hasAutoCollect(state) then
		if state.cash + math.floor(state.stored) >= price then
			return "Depoyu topla; alabilecek kadar paran var."
		end
		if state.stored >= FarmMath.getStorageCap(state) then
			return "Depo dolu. Devam etmek için parayı topla."
		end
	end
	if income <= 0 then
		return "Önce üretim yapan hayvan al."
	end
	local seconds = math.max(0, price - state.cash - state.stored) / income
	return if FarmMath.hasAutoCollect(state)
		then `Yaklaşık {secondsToText(seconds)} sonra`
		else `Düzenli toplarsan yaklaşık {secondsToText(seconds)} sonra`
end

local buttonStates: { [TextButton]: string } = {}
local function setPurchaseButton(button: TextButton, text: string, variant: UiKit.Variant)
	local pending = PurchaseController.isPending() or localPlayer:GetAttribute("DataStatus") ~= "Active"
	local actualVariant: UiKit.Variant = if pending then "disabled" else variant
	local actualText = if pending and variant ~= "owned" then "Bekleniyor" else text
	local signature = actualVariant .. actualText
	if buttonStates[button] == signature then
		return
	end
	buttonStates[button] = signature
	button.Text = actualText
	UiKit.setVariant(button, actualVariant)
end

return {
	purchaseHint = purchaseHint,
	setPurchaseButton = setPurchaseButton,
}
