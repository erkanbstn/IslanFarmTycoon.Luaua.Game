--!strict
-- Dünyadaki satın alma butonlarının rengi: kasa yetiyorsa yeşil, yetmiyorsa kırmızı (yalnızca bu ekranda).
-- Satın alma sunucudaki ProximityPrompt ile yapılır; burası yalnızca görünüm.

local CollectionService = game:GetService("CollectionService")

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local pads: { [BasePart]: number } = {}
local cash = 0

local function paint(pad: BasePart, cost: number)
	local color = if cash >= cost then UiKit.Color.Green else UiKit.Color.Red
	if pad.Color ~= color then
		pad.Color = color
	end
end

local function track(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local cost = instance:GetAttribute("Cost")
	if typeof(cost) ~= "number" then
		return
	end
	pads[instance] = cost
	paint(instance, cost)
end

CollectionService:GetInstanceAddedSignal("BuyPad"):Connect(track)
CollectionService:GetInstanceRemovedSignal("BuyPad"):Connect(function(instance: Instance)
	if instance:IsA("BasePart") then
		pads[instance] = nil
	end
end)
for _, instance in CollectionService:GetTagged("BuyPad") do
	track(instance)
end

ClientState.onChanged(function(state)
	if state.cash == cash then
		return
	end
	cash = state.cash
	for pad, cost in pads do
		paint(pad, cost)
	end
end)
