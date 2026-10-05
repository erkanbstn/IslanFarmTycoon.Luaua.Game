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
		getItemChannel = function(itemId: string): string
			return ({
				c_cash = "cash",
				c_cashgold = "cashGold",
				c_goldrobux = "goldRobux",
				c_gold = "gold",
				c_reward = "reward",
			} :: { [string]: string })[itemId] or "none"
		end,
		ITEM_SLOTS = { charm = { displayName = "Muska" } },
		ITEM_POWER_SETTINGS = {
			growth = { fraction = 0.2 },
			rush = { fraction = 0.25 },
			collect = {},
			care = { seconds = 600, bonus = 0.15 },
		},
		ITEM_SLOT_ORDER = { "tool", "charm" },
		ITEM_ORDER = { "strong", "cheap", "starter", "reward" },
		ITEMS = {
			strong = { id = "strong", slot = "tool", level = 4, price = 100 },
			cheap = { id = "cheap", slot = "tool", level = 2, price = 20 },
			starter = { id = "starter", slot = "tool", level = 1, price = 10 },
			reward = { id = "reward", slot = "tool", level = 3, price = 1, rewardOnly = true },
		},
	})
	local ordered = text.itemsOfSlot("tool")
	assert(
		ordered[1].id == "starter"
			and ordered[2].id == "cheap"
			and ordered[3].id == "reward"
			and ordered[4].id == "strong",
		"Level order must survive mixed source order and reward price placeholders"
	)
	assert(
		#text.itemsOfSlot() == 4 and #text.itemsOfSlot("charm") == 0,
		"All-items and category filters remain independent"
	)
	local description = text.describe({
		slot = "charm",
		effects = { movementSpeed = 0.15, contractBonus = 0.25, upgradeDiscount = 0.10, growthSpeed = 0.8 },
		tradeoffs = { offlineBonus = 0.20, facilitySpeed = 0.08, goodsYield = 0.06 },
	})
	assert(
		text.describe({ power = { kind = "growth", usesPerDay = 3 } })
			== "Günde 3 kez: yavru hayvanların kalan büyümesini %20 kısalt",
		"growth staff text states the configured effect"
	)
	assert(
		text.describe({ power = { kind = "rush", usesPerDay = 3 } })
			== "Günde 3 kez: çalışan üretimlerin kalan süresini %25 kısalt",
		"production staff text states the configured effect"
	)
	assert(
		text.describe({ power = { kind = "collect", usesPerDay = 6 } })
			== "Günde 6 kez: depodaki parayı platforma gitmeden topla",
		"shepherd staff text states the remote collection"
	)
	assert(
		text.describe({ power = { kind = "care", usesPerDay = 2 } })
			== "Günde 2 kez: 10 dk boyunca bütün hayvanlara +%15 gelir",
		"care staff text states duration and bonus"
	)
	local weatherDescription = text.describe({ power = { kind = "weather", usesPerDay = 1 } })
	assert(
		string.find(weatherDescription, "Sunucudaki herkes etkilenir", 1, true),
		"weather staff scope is clear before buying or using it"
	)
	assert(
		string.find(description, "Yürüme ve koşma hızı: +%15", 1, true),
		"movement benefit covers walking and sprinting"
	)
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
	local additional = text.additional({ effects = { facilitySpeed = 0.15 }, tradeoffs = { goodsYield = 0.05 } })
	assert(
		not string.find(additional, "Üretim süresi", 1, true),
		"details do not repeat the benefit already visible on the card"
	)
	assert(string.find(additional, "Ürün merkezi verimi: -%5", 1, true), "extra details retain the real penalty")
	assert(
		text.additional({ effects = { incomeBonus = 0.1 } }) == "",
		"single-effect items do not manufacture duplicate details"
	)
	assert(text.channelNotice({ id = "c_cash" }) == "Bu tur · nakit", "cash-only items are run-only")
	assert(
		text.channelNotice({ id = "c_cashgold" }) == "Nakit (bu tur) ya da altın/Robux (kalıcı)",
		"cashGold items state both the cash run and the permanent routes"
	)
	assert(
		text.channelNotice({ id = "c_goldrobux" }) == "Altın ya da Robux ile · kalıcı",
		"goldRobux items never mention cash"
	)
	assert(
		text.channelNotice({ id = "c_gold" }) == "Yalnızca altınla · kalıcı",
		"gold-only items never mention Robux or cash"
	)
	assert(text.channelNotice({ id = "c_reward" }) == "Rebirth ödülü", "reward items are earned by rebirth")
	assert(text.channelNotice({ id = "unknown" }) == "", "unclassified items get no misleading channel text")
	print("PASS item text: benefits, discounts, slower growth, three real penalties and slot opportunity cost")
end
