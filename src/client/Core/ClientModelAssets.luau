--!strict
-- İstemcide çizilen efekt nesnelerinin hazır modelleri: ReplicatedStorage.ClientAssets.<klasör>.<ad> (kaynak: client-assets/).
-- Model yoksa nil döner; çağıran yedek (kod) çizimine düşebilir. Modeller yalnızca parça geometrisi taşır; hareket/renk/ölçek kodda.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientModelAssets = {}

-- Şablon: ClientAssets.<klasör>.<ad> (Model); yoksa nil
function ClientModelAssets.find(folderName: string, name: string): Model?
	local root = ReplicatedStorage:FindFirstChild("ClientAssets")
	local folder = if root then root:FindFirstChild(folderName) else nil
	local template = if folder then folder:FindFirstChild(name) else nil
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

-- Temiz kopya: parçalar sabit, çarpışmasız, sorgusuz; gölge atmaz (uzak efektler için ucuz). Yoksa nil.
function ClientModelAssets.clone(folderName: string, name: string): Model?
	local template = ClientModelAssets.find(folderName, name)
	if not template then
		return nil
	end
	local model = template:Clone()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		end
	end
	return model
end

return ClientModelAssets
