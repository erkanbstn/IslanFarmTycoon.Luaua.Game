--!strict
return function(factory: any)
	local now = 0
	local tasks = {}
	local calls, changes = {}, {}
	local response: any = { PriceInRobux = 149, IsForSale = true }
	local fail = false
	local signal = {
		Fire = function(_self: any, kind: string, id: number)
			table.insert(changes, { kind, id })
		end,
		Event = {},
	}
	local service = {
		GetProductInfoAsync = function(_self: any, id: number, infoType: string): any
			table.insert(calls, { id, infoType })
			if fail then
				error("platform unavailable")
			end
			return response
		end,
		WaitForChild = function(self: any): any
			return self
		end,
	}
	local prices = factory({
		GetService = function(): any
			return service
		end,
	}, {
		PRODUCTS = { passes = { x = { id = 1 } }, products = { y = { id = 2 }, closed = { id = 0 } } },
	}, {
		new = function(): any
			return signal
		end,
	}, {
		spawn = function(callback: any)
			table.insert(tasks, callback)
		end,
	}, {
		clock = function(): number
			return now
		end,
	}, { InfoType = { GamePass = "pass", Product = "product" } })
	local price, status = prices.get("product", 2)
	assert(price == nil and status == "loading", "price lookup does not block menu rendering")
	prices.get("product", 2)
	prices.get("pass", 1)
	assert(#tasks == 1 and #calls == 0, "one worker coalesces repeated requests and serializes API calls")
	table.remove(tasks, 1)()
	price, status = prices.get("product", 2)
	assert(price == 149 and status == "ready" and #calls == 2, "real platform price is cached")
	assert(calls[1][2] == "product" and calls[2][2] == "pass", "products and passes use correct info types")
	assert(#changes == 2, "loaded prices notify their own identifiers")
	now = 301
	response.PriceInRobux = 97
	prices.get("product", 2)
	table.remove(tasks, 1)()
	assert(prices.get("product", 2) == 97, "expired price refresh reflects regional or platform changes")
	now = 602
	fail = true
	prices.get("product", 2)
	table.remove(tasks, 1)()
	price, status = prices.get("product", 2)
	assert(price == nil and status == "failed", "failure never displays old or invented price")
	prices.get("product", 2)
	assert(#tasks == 0, "failed requests back off rather than repeat every UI update")
	now = 633
	fail = false
	response = { PriceInRobux = 0, IsForSale = true }
	prices.get("product", 2)
	table.remove(tasks, 1)()
	assert(prices.get("product", 2) == 0, "valid zero price is not mistaken for a lookup failure")
	now = 934
	response = { PriceInRobux = 149, IsForSale = false }
	prices.get("product", 2)
	table.remove(tasks, 1)()
	price, status = prices.get("product", 2)
	assert(price == nil and status == "unavailable", "off-sale items cannot advertise a purchasable price")
	now = 1235
	response = { PriceInRobux = math.huge }
	prices.get("product", 2)
	table.remove(tasks, 1)()
	price, status = prices.get("product", 2)
	assert(price == nil and status == "failed", "invalid prices never reach purchase buttons")
	for id = 3, 100 do
		price, status = prices.get("product", id)
		assert(price == nil and status == "unavailable", "unknown identifiers do not grow the price cache")
	end
	assert(#tasks == 0, "unsupported and zero identifiers never query Roblox")
	print("PASS product prices: async regional values, dedup, expiry, failure backoff and bounded catalog")
end
