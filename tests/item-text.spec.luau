--!strict
return function(createItemText: any)
	local root: any = {}
	root.WaitForChild = function(): any
		return root
	end
	local text = createItemText({
		GetService = function(): any
			return root
		end,
	}, {
		ITEM_SLOTS = { charm = { displayName = "Muska" } },
		ITEM_ORDER = {},
		ITEMS = {},
	})
	local description = text.describe({
		slot = "charm",
		effects = { contractBonus = 0.25, upgradeDiscount = 0.10, growthSpeed = 0.8 },
		tradeoffs = { offlineBonus = 0.20, facilitySpeed = 0.08, goodsYield = 0.06 },
	})
	assert(
		string.find(description, "Ahır siparişi ödülü: +%25", 1, true),
		"advertised contract benefit keeps its sign"
	)
	assert(string.find(description, "Yükseltme maliyeti: -%10", 1, true), "discount is a reduction in cost")
	assert(
		string.find(description, "Hayvan büyüme hızı: -%20", 1, true),
		"slower growth cannot be advertised as faster"
	)
	assert(
		string.find(description, "Çevrimdışı gelir oranı: -20 puan", 1, true),
		"offline penalty is shown as a real reduction"
	)
	assert(string.find(description, "Üretim süresi: +%8", 1, true), "production penalty is explicit")
	assert(string.find(description, "Ürün merkezi verimi: -%6", 1, true), "yield penalty is explicit")
	assert(
		string.find(text.slotNotice({ slot = "charm" }), "Muska", 1, true),
		"slot replacement notice identifies the actual slot"
	)
	print("PASS item text: benefits, discounts, slower growth, three real penalties and slot opportunity cost")
end
