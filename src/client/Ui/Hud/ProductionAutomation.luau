--!strict
-- Yardımcı hazır partiyi her zaman teslim alır; düğme yalnız yeni parti başlatmayı yönetir.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))

local ProductionAutomation = {}

export type View = {
	visible: boolean,
	enabled: boolean,
	repeating: boolean,
	status: string,
	action: string,
}

function ProductionAutomation.getView(state: any, recipe: Config.ProductionRecipeConfig, now: number): View
	local kind = FarmMath.petKindFor(recipe)
	local visible = kind ~= nil and state.purchased[recipe.upgradeId] == true
	local hasPet = kind ~= nil and FarmMath.hasPet(state, kind)
	local repeating = state.autoRepeat ~= nil and state.autoRepeat[recipe.id] ~= nil
	local result: View = {
		visible = visible,
		enabled = hasPet,
		repeating = repeating,
		status = "",
		action = if repeating then "Otomatik üretimi kapat" else "Otomatik üretimi aç",
	}
	if not visible then
		return result
	end
	if not hasPet then
		result.status = if kind == "goods"
			then "Ürün Yardımcısı yok. Market veya Yükseltmeler'den alabilirsin."
			else "Para Yardımcısı yok. Market veya Yükseltmeler'den alabilirsin."
		result.action = "Yardımcı gerekli"
		return result
	end
	local job = state.production and state.production[recipe.id]
	if job then
		if job.readyAt > now then
			result.status = if repeating
				then "Otomatik üretim açık · Üretiliyor."
				else "Otomatik üretim kapalı · Üretiliyor."
		elseif recipe.output == "goods" and recipe.goodsId then
			local amount = FarmMath.getGoodsYield(state, recipe, now, job)
			local full = FarmMath.getGoodsSpace(state, recipe.goodsId) < math.min(amount, FarmMath.getGoodsCap(state))
			result.status = if full
				then (if repeating
					then "Otomatik üretim açık · Depoda yer bekliyor."
					else "Otomatik üretim kapalı · Depoda yer bekliyor.")
				else (if repeating
					then "Otomatik üretim açık · Yardımcı partiyi alacak."
					else "Otomatik üretim kapalı · Yardımcı partiyi alacak.")
		elseif recipe.output == "chicken" and FarmMath.findZoneForAnimal(state, "chicken") == nil then
			result.status = if repeating
				then "Otomatik üretim açık · Kümeste yer bekliyor."
				else "Otomatik üretim kapalı · Kümeste yer bekliyor."
		else
			result.status = if repeating
				then "Otomatik üretim açık · Yardımcı partiyi alacak."
				else "Otomatik üretim kapalı · Yardımcı partiyi alacak."
		end
		return result
	end
	if not repeating then
		result.status = "Otomatik üretim kapalı · Partiyi sen başlat; bitince yardımcı alır."
		return result
	end
	local selected = state.autoRepeat[recipe.id]
	local optionId = if selected == "default" or selected == "fill" then nil else selected
	local batch = FarmMath.resolveRecipe(recipe, optionId)
	if recipe.output == "goods" and recipe.goodsId then
		local amount = math.min(FarmMath.previewGoodsYield(state, recipe, now), FarmMath.getGoodsCap(state))
		local target = FarmMath.getGoodsProductionTarget(state, recipe.goodsId, amount, now, nil, selected == "fill")
		if FarmMath.getGoodsSpace(state, recipe.goodsId) < amount then
			result.status = "Otomatik üretim açık · Depoda yer bekliyor."
			return result
		end
		if FarmMath.getGoodsAmount(state, recipe.goodsId) + amount > target then
			result.status = "Otomatik üretim açık · Stok yeterli, azalınca devam eder."
			return result
		end
	end
	if FarmMath.countProductionAdults(state, recipe, now) < batch.requiredAdults then
		result.status = "Otomatik üretim açık · Boşta yetişkin hayvan bekliyor."
	elseif state.cash < FarmMath.getFacilityCost(state, recipe) then
		result.status = "Otomatik üretim açık · Başlatmak için para bekliyor."
	else
		result.status = "Otomatik üretim açık · Yeni parti başlayacak."
	end
	if recipe.options then
		local option = FarmMath.findProductionOption(recipe, optionId) or recipe.options[1]
		result.status ..= `\nParti: {option.displayName}`
	end
	return result
end

return ProductionAutomation
