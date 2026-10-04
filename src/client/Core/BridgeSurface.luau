--!strict
-- Modüler köprü güvertesi; korkuluk ve yakındaki ada zemini hız vermez.
local BridgeSurface = {}

function BridgeSurface.isDeck(part: Instance): boolean
	if not part:IsA("BasePart") then
		return false
	end
	if part.Name == "Bridge" then
		return true
	end
	if part.Name ~= "Deck" and part.Name ~= "DeckPlank" then
		return false
	end
	local parent = part.Parent
	while parent do
		if parent:IsA("Model") and (parent.Name == "BridgeModule_8" or parent.Name == "BridgeModule_2") then
			return true
		end
		parent = parent.Parent
	end
	return false
end

return BridgeSurface
