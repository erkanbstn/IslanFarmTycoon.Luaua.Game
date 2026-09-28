--!strict
-- Import edilen görseller dünyaya eklenmeden önce çalışabilir içerikten arındırılır.
local AssetSanitizer = {}

function AssetSanitizer.clone(template: Model, collide: boolean): Model
	local model = template:Clone()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = collide
			descendant.CanTouch = false
			if not collide then
				descendant.CanQuery = false
			end
		end
	end
	return model
end

return table.freeze(AssetSanitizer)
