--!strict
-- Fiyat istemciden alınır: bölgesel fiyat ve Roblox fiyat deneyleri sabit Config fiyatıyla ezilmez.
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ProductPrices = {}
local changed = Instance.new("BindableEvent")
ProductPrices.Changed = changed.Event

export type Status = "loading" | "ready" | "failed" | "unavailable"
type Entry = { kind: string, id: number, price: number?, status: Status, expiresAt: number, pending: boolean }
local entries: { [string]: Entry } = {}
local queue: { Entry } = {}
local running = false

for _, group in
	{ { kind = "pass", items = Config.PRODUCTS.passes }, { kind = "product", items = Config.PRODUCTS.products } }
do
	for _, product in group.items do
		if product.id > 0 then
			entries[`{group.kind}:{product.id}`] = {
				kind = group.kind,
				id = product.id,
				price = nil,
				status = "loading",
				expiresAt = 0,
				pending = false,
			}
		end
	end
end

local function drain()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while #queue > 0 do
			local entry = table.remove(queue, 1)
			if not entry then
				break
			end
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfoAsync(
					entry.id,
					if entry.kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
				)
			end)
			entry.price = nil
			entry.status = "failed"
			if ok and typeof(info) == "table" then
				local price = info.PriceInRobux
				if info.IsForSale == false then
					entry.status = "unavailable"
				elseif
					typeof(price) == "number"
					and price == price
					and price >= 0
					and price < math.huge
					and price % 1 == 0
				then
					entry.price = price
					entry.status = "ready"
				end
			end
			entry.expiresAt = os.clock() + (if entry.status == "failed" then 30 else 300)
			entry.pending = false
			changed:Fire(entry.kind, entry.id)
		end
		running = false
	end)
end

function ProductPrices.get(kind: string, id: number): (number?, Status)
	local entry = entries[`{kind}:{id}`]
	if not entry then
		return nil, "unavailable"
	end
	if os.clock() >= entry.expiresAt and not entry.pending then
		entry.pending = true
		entry.status = "loading"
		entry.price = nil
		table.insert(queue, entry)
		drain()
	end
	return entry.price, entry.status
end

return ProductPrices
