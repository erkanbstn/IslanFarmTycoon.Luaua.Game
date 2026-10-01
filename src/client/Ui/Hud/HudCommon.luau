--!strict
-- HUD pencerelerinin ortak yardımcıları: satın alma düğmesi durumu ve "ne zaman alırım" ipucu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local Config = require(Shared:WaitForChild("Config"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))

type PlayerSave = GameTypes.PlayerSave

local localPlayer = Players.LocalPlayer

local function secondsToText(seconds: number): string
	return if seconds < 60 then `{math.ceil(seconds)} sn` else `{math.ceil(seconds / 60)} dk`
end

-- upgrade verilirse açılışın ürün gereksinimi de hesaba katılır (para yeterli ama ürün eksikse eksik kalemler yazılır)
local function purchaseHint(state: PlayerSave, price: number, income: number, upgrade: Config.UpgradeConfig?): string
	if state.cash >= price then
		local shortfall = if upgrade
			then FarmMath.getGoodsShortfall(state, FarmMath.getGoodsCost(state, upgrade))
			else {}
		if #shortfall > 0 then
			return `Ürün gerekli: {FarmMath.formatGoodsShortfall(shortfall)}`
		end
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

-- Açılış maliyeti (para + ürün): sunucunun tahsil ettiğiyle aynı FarmMath hesabı. Para ya da ürün yetmiyorsa "warning".
local function upgradeAffordable(state: PlayerSave, upgrade: Config.UpgradeConfig): boolean
	return state.cash >= FarmMath.getUpgradeCost(state, upgrade)
		and #FarmMath.getGoodsShortfall(state, FarmMath.getGoodsCost(state, upgrade)) == 0
end

local function upgradeVariant(state: PlayerSave, upgrade: Config.UpgradeConfig): UiKit.Variant
	return if upgradeAffordable(state, upgrade) then "primary" else "warning"
end

-- "Gereken ürün: Süt 2/4 · Yumurta 3/3": yetmeyen kalem kırmızı, karşılanan yeşil; ürün gerekmiyorsa nil
local function goodsNeedText(state: PlayerSave, upgrade: Config.UpgradeConfig): string?
	local cost = FarmMath.getGoodsCost(state, upgrade)
	local parts: { string } = {}
	for _, entry in FarmMath.listGoodsCost(cost) do
		local have = FarmMath.getGoodsAmount(state, entry.goodsId)
		local text = `{Config.GOODS[entry.goodsId].displayName} {math.min(have, entry.amount)}/{entry.amount}`
		table.insert(parts, UiKit.colorText(text, if have >= entry.amount then UiKit.Color.Green else UiKit.Color.Red))
	end
	if #parts == 0 then
		return nil
	end
	return `Gereken ürün: {table.concat(parts, " · ")}`
end

return {
	upgradeAffordable = upgradeAffordable,
	upgradeVariant = upgradeVariant,
	goodsNeedText = goodsNeedText,
	purchaseHint = purchaseHint,
	setPurchaseButton = setPurchaseButton,
}
