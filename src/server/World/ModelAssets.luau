--!strict
-- Studio'da yapılan hazır modellerin (assets/ → ServerStorage.Assets.<klasör>.<ad>) ortak yükleyicisi.
-- Model dosyaları yalnızca parça geometrisi taşır (ad, ölçü, renk, malzeme, çarpışma, pivot); öznitelik, etiket, ışık, tabela ve istemci
-- etkileşimi yoktur: bunları çağıran kurucu ekler. Model yoksa nil döner; çağıran bir kez `warn` verip o görünümü çizmez (yedek kod kurucusu yoktur; `scripts/check-assets.py` eksiği yakalar).
-- World katmanı: eklenti (plugin) ve Presentation aynı modülü kullanır.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local VisualWorkBudget = require(script.Parent:WaitForChild("VisualWorkBudget"))

local ModelAssets = {}

local function assetsRoot(): Instance?
	return ServerStorage:FindFirstChild("Assets") or ReplicatedStorage:FindFirstChild("Assets")
end

-- Şablon: Assets.<klasör>.<ad> (Model); yoksa nil
function ModelAssets.find(folderName: string, name: string): Model?
	local root = assetsRoot()
	local folder = if root then root:FindFirstChild(folderName) else nil
	local template = if folder then folder:FindFirstChild(name) else nil
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

-- Şablonun temiz kopyası: çalışabilir içerik atılır, parçalar sabitlenir; çarpışma/sorgu değerleri modeldekiyle kalır
-- (AssetSanitizer.clone zorla çarpışır/çarpışmaz yapar; modeldeki ince süs parçaları için yanlış, o yüzden yalnızca hayvan modelleri onu kullanır).
function ModelAssets.clone(folderName: string, name: string): Model?
	local template = ModelAssets.find(folderName, name)
	if not template then
		return nil
	end
	VisualWorkBudget.step(#template:GetDescendants() + 1)
	local model = template:Clone()
	model:SetAttribute("ModelAsset", `{folderName}/{name}`) -- hazır modelden geldiğini gösterir (Studio denetimi/hata ayıklama)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanTouch = false
		end
	end
	return model
end

-- Şablonun kopyasını `cf` pivotuyla `parent` içine koyar (adı şablon adı kalır); şablon yoksa false
function ModelAssets.place(parent: Instance, folderName: string, name: string, cf: CFrame): boolean
	local model = ModelAssets.clone(folderName, name)
	if not model then
		return false
	end
	model:PivotTo(cf)
	model.Parent = parent
	return true
end

function ModelAssets.partCount(model: Instance): number
	local count = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

local function addNightLight(
	part: BasePart,
	tag: string,
	nightColor: Color3,
	lightColor: Color3,
	range: number,
	brightness: number
)
	part:SetAttribute("NightColor", nightColor)
	CollectionService:AddTag(part, tag)
	local light = Instance.new("PointLight")
	light.Color = lightColor
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Enabled = false
	light.Parent = part
end

-- Fener gövdesi (geceleri DayNight yakar): menzil/parlaklık verilmezse ortak varsayılan (26 / 2.5)
function ModelAssets.markLantern(part: BasePart, range: number?, brightness: number?)
	addNightLight(
		part,
		"NightLight",
		Color3.fromRGB(255, 214, 130),
		Color3.fromRGB(255, 205, 130),
		range or 26,
		brightness or 2.5
	)
end

-- Pencere (geceleri DayNight parlatır)
function ModelAssets.markGlowWindow(part: BasePart)
	addNightLight(part, "NightWindow", Color3.fromRGB(255, 219, 140), Color3.fromRGB(255, 205, 130), 12, 1.4)
end

-- Adı `names` içinde olan parçaların her birine `apply` uygular
function ModelAssets.eachNamed(model: Instance, names: { string }, apply: (BasePart) -> ())
	local wanted: { [string]: boolean } = {}
	for _, name in names do
		wanted[name] = true
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and wanted[descendant.Name] then
			apply(descendant)
		end
	end
end

return ModelAssets
