--!strict
-- İstemcide çizilen efekt nesnelerinin hazır modelleri: ReplicatedStorage.ClientAssets.<klasör>.<ad> (kaynak: client-assets/).
-- Model yoksa nil döner; kod geometrisiyle yedek çizim yapılmaz. Hareket/renk/ölçek kodda yönetilir.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientModelAssets = {}
local warnedParts: { [string]: boolean } = {}

local function warnPart(folderName: string, name: string)
	local key = `{folderName}/{name}`
	if not warnedParts[key] then
		warnedParts[key] = true
		warn(`[ClientModelAssets] client-assets/{key}.rbxmx tek Part şablonu bulunamadı`)
	end
end

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

-- Tek parçalık havuz şablonu: mesh çocuklarını korur, model sarmalayıcısını bırakmaz.
function ClientModelAssets.clonePart(folderName: string, name: string): Part?
	local model = ClientModelAssets.clone(folderName, name)
	if not model then
		warnPart(folderName, name)
		return nil
	end
	local part: Part? = nil
	local valid = true
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant:IsA("Part") and not part then
				part = descendant
			else
				valid = false
			end
		end
	end
	if not valid or not part then
		model:Destroy()
		warnPart(folderName, name)
		return nil
	end
	part.Parent = nil
	model:Destroy()
	return part
end

return ClientModelAssets
