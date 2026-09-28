--!strict
-- Eklenti hayvan alanı (PlotService / ExtensionVisualService döngüsünü kırmak için ayrı modül).

local ExtensionAreas = {}

function ExtensionAreas.find(plot: Model, extensionId: string): (CFrame?, Vector3?, string?)
	for _, desc in plot:GetDescendants() do
		if desc:GetAttribute("ExtensionId") == extensionId then
			local area = desc:GetAttribute("AreaCFrame")
			local size = desc:GetAttribute("AreaSize")
			local movement = desc:GetAttribute("MovementStyle")
			if typeof(area) == "CFrame" and typeof(size) == "Vector3" then
				return area, size, if typeof(movement) == "string" then movement else "wander"
			end
		end
	end
	return nil, nil, nil
end

return ExtensionAreas
