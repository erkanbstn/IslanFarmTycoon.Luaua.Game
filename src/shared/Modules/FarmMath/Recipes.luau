--!strict
-- Para tesislerinin parti seçenekleri: seçilen seçeneğin alanlarıyla tarifin "çözülmüş" kopyası.
-- FarmMath cephesi (init.luau) bunları birleştirir; her zaman `FarmMath.<ad>` ile kullan.

local Config = require(script.Parent.Parent.Parent:WaitForChild("Config"))

local Recipes = {}

local cache: { [Config.ProductionRecipeConfig]: { [string]: Config.ProductionRecipeConfig } } = {}

-- Tarifin verilen kimlikli seçeneği (yoksa nil); seçeneği olmayan tarifte her zaman nil
function Recipes.findOption(recipe: Config.ProductionRecipeConfig, optionId: unknown): Config.ProductionOptionConfig?
	if typeof(optionId) ~= "string" or not recipe.options then
		return nil
	end
	for _, option in recipe.options do
		if option.id == optionId then
			return option
		end
	end
	return nil
end

-- Seçenekli tarifte seçilen partinin (bilinmiyorsa ilk seçeneğin) gereken hayvan, süre ve ödülü tarif alanlarına yazılmış
-- kopya döner (`optionId`, `returnMultiplier` dolar); seçeneksiz tarifte tarifin kendisi. Sonuç önbelleklenir, değiştirme.
function Recipes.resolve(recipe: Config.ProductionRecipeConfig, optionId: unknown): Config.ProductionRecipeConfig
	local options = recipe.options
	if not options or #options == 0 then
		return recipe
	end
	local chosen = Recipes.findOption(recipe, optionId) or options[1]
	local perRecipe = cache[recipe]
	if not perRecipe then
		perRecipe = {}
		cache[recipe] = perRecipe
	end
	local existing = perRecipe[chosen.id]
	if existing then
		return existing
	end
	local resolved = table.clone(recipe)
	resolved.requiredAdults = chosen.requiredAdults
	resolved.duration = chosen.duration
	resolved.reward = chosen.reward
	resolved.optionId = chosen.id
	resolved.returnMultiplier = chosen.returnMultiplier
	perRecipe[chosen.id] = resolved
	return resolved
end

-- Tarifi yönetebilecek yardımcı türü: ürün merkezi "goods"; para fabrikası ve kuluçka (civciv çıkar) "cash"; yoksa nil.
-- Elle/otomatik teslim, kayıt doğrulaması ve arayüz aynı eşlemeyi kullanır.
function Recipes.petKindFor(recipe: Config.ProductionRecipeConfig): string?
	local output = recipe.output
	return if output == "goods" then "goods" elseif output == "cash" or output == "chicken" then "cash" else nil
end

return Recipes
