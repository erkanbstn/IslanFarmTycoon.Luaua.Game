--!strict
-- Mevcut dört adanın boş kenarlarını uzmanlaştırır; hayvan bölgelerine ve köprü girişlerine dokunmaz.
-- Parçalar: IslandLayout (veri), IslandSiteParts (yapı taşları). Yapılar hazır modellerdir (assets/Extensions, ProductionSites).
local IslandLayout = require(script.Parent:WaitForChild("IslandLayout"))
local IslandSiteParts = require(script.Parent:WaitForChild("IslandSiteParts"))
local ModelAssets = require(script.Parent:WaitForChild("ModelAssets"))

local IslandSpecialization = {}

export type Site = IslandLayout.Site
export type ExtensionLayout = IslandLayout.ExtensionLayout

IslandSpecialization.EXTENSIONS = IslandLayout.EXTENSIONS
IslandSpecialization.SITES = IslandLayout.SITES
IslandSpecialization.SITE_UPGRADE_ID = IslandLayout.SITE_UPGRADE_ID

local part = IslandSiteParts.part
local sign = IslandSiteParts.sign
IslandSpecialization.markObstacles = IslandSiteParts.markObstacles

local function productionSite(parent: Instance, cf: CFrame, id: string, site: Site)
	local base = cf * CFrame.new(site.offset)
	-- Hazır zemin (assets/ProductionSites/ProductionSite_<id>, pivot = ada yüzeyi). Tabela her zaman kodla eklenir.
	local ready = ModelAssets.clone("ProductionSites", `ProductionSite_{id}`)
	local readyPad = if ready then ready:FindFirstChild("ProductionPad") else nil
	if ready and readyPad then
		ready:PivotTo(cf)
		ready.Parent = parent
		readyPad:SetAttribute("ProductionSiteId", id)
	else
		warn(
			`[IslandSpecialization] assets/ProductionSites/ProductionSite_{id}.rbxmx bulunamadı ya da ProductionPad yok`
		)
		if ready then
			ready:Destroy()
		end
	end
	local front = site.footprint.Y / 2 + 2.5
	-- Tabela kapının tam önünde değil, yükleme alanının kenarında durur.
	sign(parent, base * CFrame.new(site.footprint.X / 2 - 2, 0, -front), site.title, site.icon)
end

local function createExtensionSlot(parent: Instance, surfaceCf: CFrame, layout: ExtensionLayout)
	local anchor = part(
		parent,
		`ExtensionSlot_{layout.id}`,
		Vector3.new(2, 1, 2),
		surfaceCf * CFrame.new(layout.signOffset.X, 0.5, layout.signOffset.Z),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic
	)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor:SetAttribute("ExtensionId", layout.id)
	local areaCf = surfaceCf * CFrame.new(layout.areaOffset)
	anchor:SetAttribute("AreaCFrame", areaCf)
	anchor:SetAttribute("AreaSize", layout.areaSize)
	anchor:SetAttribute("MovementStyle", layout.movement)
end

function IslandSpecialization.buildExtensionVisual(parent: Instance, surfaceCf: CFrame, extensionId: string): Model?
	local layout = IslandSpecialization.EXTENSIONS[extensionId]
	if not layout then
		return nil
	end
	local wrapper = Instance.new("Model")
	wrapper.Name = extensionId
	wrapper.Parent = parent
	-- Hazır yapı (assets/Extensions/<eklentiId>, pivot = ada yüzeyi)
	if not ModelAssets.place(wrapper, "Extensions", extensionId, surfaceCf) then
		warn(`[IslandSpecialization] assets/Extensions/{extensionId}.rbxmx bulunamadı`)
	end
	-- Satın alınan eklentide de tabela olsun: etkileşim balonları rastgele bir yapı parçasına değil buna bağlanır.
	sign(wrapper, surfaceCf * CFrame.new(layout.signOffset.X, 0, layout.signOffset.Z), layout.title, layout.icon)
	local areaCf = surfaceCf * CFrame.new(layout.areaOffset)
	wrapper:SetAttribute("AreaCFrame", areaCf)
	wrapper:SetAttribute("AreaSize", layout.areaSize)
	wrapper:SetAttribute("MovementStyle", layout.movement)
	wrapper:SetAttribute("ExtensionId", extensionId)
	IslandSiteParts.markObstacles(wrapper)
	return wrapper
end

function IslandSpecialization.buildForSaleSign(
	parent: Instance,
	surfaceCf: CFrame,
	extensionId: string,
	priceText: string
): Model
	local layout = IslandSpecialization.EXTENSIONS[extensionId]
	local wrapper = Instance.new("Model")
	wrapper.Name = `ForSale_{extensionId}`
	wrapper.Parent = parent
	if layout then
		local cf = surfaceCf * CFrame.new(layout.signOffset.X, 0, layout.signOffset.Z)
		sign(wrapper, cf, layout.title, layout.icon, "ForSaleSign", `Satılık · {priceText}`)
		createExtensionSlot(wrapper, surfaceCf, layout)
	end
	wrapper:SetAttribute("ExtensionId", extensionId)
	return wrapper
end

local function stripLegacyProductionDecor(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("Folder") and (child.Name == "ProductionSites" or child.Name == "MilkLoadingDecor") then
			continue
		end
		if child:IsA("Folder") then
			continue
		end
		if string.sub(child.Name, 1, 14) == "ExtensionSlot_" then
			continue
		end
		local legacyPart = child:IsA("BasePart")
			and (
				child.Name == "ProductionPad"
				or child.Name == "SpecialtySign"
				or child.Name == "SignPost"
				or child.Name == "SpecialtyPost"
				or child.Name == "LoadingBayStripe"
			)
		local legacyModel = child:IsA("Model") and (child.Name == "Crate" or child.Name:find("Path") ~= nil)
		if legacyPart or legacyModel then
			child:Destroy()
		end
	end
	local legacyDecor = parent:FindFirstChild("MilkLoadingDecor")
	if legacyDecor then
		legacyDecor:Destroy()
	end
end

function IslandSpecialization.syncMilkLoadingDecor(parent: Instance, surfaceCf: CFrame, enabled: boolean)
	local folder = parent:FindFirstChild("MilkLoadingDecor")
	if not enabled then
		if folder then
			folder:Destroy()
		end
		return
	end
	if folder then
		return
	end
	local created = Instance.new("Folder")
	created.Name = "MilkLoadingDecor"
	created.Parent = parent
	if not ModelAssets.place(created, "Extensions", "MilkLoadingDecor", surfaceCf) then
		warn("[IslandSpecialization] assets/Extensions/MilkLoadingDecor.rbxmx bulunamadı")
	end
end

-- İlgili yol haritası öğesi alındığında üretim tabelası + zemin (ada açık olmalı).
function IslandSpecialization.syncProductionSites(parent: Instance, surfaceCf: CFrame, islandId: string, save: any?)
	stripLegacyProductionDecor(parent)
	local folder = parent:FindFirstChild("ProductionSites")
	if not save or save.unlockedIslands[islandId] ~= true then
		if folder then
			folder:Destroy()
		end
		return
	end
	-- Hangi üretim alanları kurulacak? Aynıysa dokunma: her yenilemede silinip yeniden kurulunca
	-- tabelalar ve zeminler ekranda baştan çiziliyordu (ör. her hayvan alımında).
	local built: { string } = {}
	for id, site in IslandSpecialization.SITES do
		if site.island ~= islandId then
			continue
		end
		local upgradeId = IslandSpecialization.SITE_UPGRADE_ID[id]
		if upgradeId and save.purchased[upgradeId] ~= true then
			continue
		end
		table.insert(built, id)
	end
	table.sort(built)
	local signature = table.concat(built, ",")
	if folder and folder:GetAttribute("Signature") == signature then
		return
	end
	local target: Instance
	if folder then
		target = folder
		target:ClearAllChildren()
	else
		local created = Instance.new("Folder")
		created.Name = "ProductionSites"
		created.Parent = parent
		target = created
	end
	target:SetAttribute("Signature", signature)
	for _, id in built do
		productionSite(target, surfaceCf, id, IslandSpecialization.SITES[id])
	end
end

function IslandSpecialization.build(parent: Instance, islandId: string, surfaceCf: CFrame)
	local model = Instance.new("Model")
	model.Name = "Specialization"
	model:SetAttribute("FarmIslandId", islandId)
	model.Parent = parent
	for _, layout in IslandSpecialization.EXTENSIONS do
		if layout.island == islandId then
			createExtensionSlot(model, surfaceCf, layout)
		end
	end
end

return IslandSpecialization
