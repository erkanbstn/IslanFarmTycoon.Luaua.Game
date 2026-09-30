--!strict
-- Geliştirmeyle belirip büyüyen adalar: haritaya kaydedilen bazı süs yapıları "RevealGate" etiketiyle Model olarak kurulur ve
--   RevealBarnLevel = n                      ahır seviyesi n'e ulaşınca,
--   RevealZoneId + RevealZoneLevel = n       bölge geliştirme seviyesi n'e ulaşınca
-- görünür. Henüz hak edilmemiş yapı ServerStorage'daki "HiddenDecor" klasörüne alınır (çarpışma, ışık ve ağ yükü de gider)
-- ve hak edilince eski yerine geri konur. Hangi Model'in hangi çiftliğe ait olduğu ilk taramada kaydedilir.

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))

type PlayerSave = GameTypes.PlayerSave

local DecorReveal = {}

local TAG = "RevealGate"

type Entry = { model: Model, parent: Instance }
local registry: { [Model]: { Entry } } = {}

local function hiddenFolder(): Folder
	local folder = ServerStorage:FindFirstChild("HiddenDecor")
	if folder and folder:IsA("Folder") then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = "HiddenDecor"
	created.Parent = ServerStorage
	return created
end

-- Bu çiftlik durumunda yapı görünür mü (save nil = sahipsiz ada: en düşük seviye)
function DecorReveal.isRevealed(model: Instance, save: PlayerSave?): boolean
	local barnLevel = model:GetAttribute("RevealBarnLevel")
	if typeof(barnLevel) == "number" and (if save then save.barnLevel else 1) < barnLevel then
		return false
	end
	local zoneId = model:GetAttribute("RevealZoneId")
	local zoneLevel = model:GetAttribute("RevealZoneLevel")
	if typeof(zoneId) == "string" and typeof(zoneLevel) == "number" then
		if not save or not save.unlockedZones[zoneId] then
			return false
		end
		if FarmMath.getExpansionLevel(save, zoneId) < zoneLevel then
			return false
		end
	end
	return true
end

local function scan(plot: Model): { Entry }
	local existing = registry[plot]
	if existing then
		return existing
	end
	local entries: { Entry } = {}
	for _, instance in CollectionService:GetTagged(TAG) do
		if instance:IsA("Model") and instance:IsDescendantOf(plot) and instance.Parent then
			table.insert(entries, { model = instance, parent = instance.Parent })
		end
	end
	registry[plot] = entries
	return entries
end

function DecorReveal.apply(plot: Model, save: PlayerSave?)
	for _, entry in scan(plot) do
		local model = entry.model
		local show = DecorReveal.isRevealed(model, save)
		local shown = model.Parent == entry.parent
		if show and not shown and entry.parent.Parent then
			model.Parent = entry.parent
		elseif not show and shown then
			model.Parent = hiddenFolder()
		end
	end
end

return DecorReveal
