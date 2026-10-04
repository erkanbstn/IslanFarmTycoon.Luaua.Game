--!strict
return function(BridgeSurface: any)
	local function node(name: string, class: string, parent: any?): any
		return {
			Name = name,
			Parent = parent,
			IsA = function(_self: any, expected: string): boolean
				return class == expected or (class == "Part" and expected == "BasePart")
			end,
		}
	end
	for _, name in { "BridgeModule_8", "BridgeModule_2" } do
		local model = node(name, "Model", nil)
		for _, deck in { "Deck", "DeckPlank" } do
			assert(BridgeSurface.isDeck(node(deck, "Part", model)), "both bridge modules support deck boost")
			assert(BridgeSurface.isDeck(node(deck, "Part", node("Nested", "Model", model))), "nested deck supported")
		end
		assert(not BridgeSurface.isDeck(node("Rail", "Part", model)), "railing does not accelerate")
	end
	assert(BridgeSurface.isDeck(node("Bridge", "Part", nil)), "legacy bridge supported")
	assert(not BridgeSurface.isDeck(node("Deck", "Part", node("Dock", "Model", nil))), "non-bridge deck excluded")
	assert(not BridgeSurface.isDeck(node("Bridge", "Model", nil)), "only physical floors qualify")
	assert(not BridgeSurface.isDeck(node("Grass", "Part", nil)), "island floor excluded")
	print("PASS bridge surface: module decks, legacy floors and unrelated geometry")
end
