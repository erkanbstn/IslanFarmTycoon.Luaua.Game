--!strict
return function(createContext: any, config: any)
	local context = createContext({
		GetService = function(): any
			return {}
		end,
	}, config)
	local recipes = config.PRODUCTION_RECIPES
	assert(
		context.isRelated(recipes.fish_dispatch, recipes.fish_goods),
		"fish factory exposes shipping without changing its boat prerequisite"
	)
	assert(context.isRelated(recipes.fish_goods, recipes.fish_dispatch), "boat exposes fish processing symmetrically")
	for _, focused in recipes do
		assert(context.isRelated(focused, focused), "every production building retains its own recipe")
		for _, recipe in recipes do
			local related = context.isRelated(recipe, focused)
			assert(related == context.isRelated(focused, recipe), "entry point cannot change the related recipe group")
			if related then
				assert(recipe.island == focused.island, "world focus cannot expose another island")
				local shared = false
				for _, animalId in recipe.animalIds do
					shared = shared or table.find(focused.animalIds, animalId) ~= nil
				end
				assert(
					shared or recipe.upgradeId == focused.upgradeId,
					"unrelated buildings and animals remain outside the focused production group"
				)
			end
		end
	end
	print(
		"PASS production context: fish goods/shipping, symmetric groups and island/animal isolation across all recipes"
	)
end
