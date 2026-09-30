--!strict
-- Arayüzdeki ve dünyadaki tabelalardaki yazıları seçili dile çevirir.
-- Oyun kodu Türkçe metin yazmaya devam eder; burada her metnin kaynağı saklanır, dil değişince
-- kaynaktan yeniden çevrilir. Sözlük: shared/Locales, motor: shared/Localization.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Localization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Localization"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

type Entry = { source: string, output: string }

-- Çevrilen özellikler; ProximityPrompt yazıları da tuşa yaklaşınca görünen metindir.
local PROPERTIES: { [string]: { string } } = {
	TextLabel = { "Text" },
	TextButton = { "Text" },
	ProximityPrompt = { "ActionText", "ObjectText" },
}

local tracked: { [Instance]: { [string]: Entry } } = setmetatable({}, { __mode = "k" }) :: any

local function refresh(instance: Instance, property: string)
	local entries = tracked[instance]
	if not entries then
		return
	end
	local target: any = instance
	local current = target[property] :: string
	local entry = entries[property]
	-- Kendi yazdığımız çeviri değişiklik olayı üretir; onu yok say.
	if entry and current == entry.output then
		return
	end
	local translated = Localization.tr(current)
	entries[property] = { source = current, output = translated }
	if translated ~= current then
		target[property] = translated
	end
end

local function watch(instance: Instance)
	local properties = PROPERTIES[instance.ClassName]
	if not properties or tracked[instance] then
		return
	end
	-- Dünyada yalnızca tabela yüzeylerindeki yazılar (Workspace'te başka TextLabel bulunmaz).
	if
		instance:IsA("GuiObject")
		and instance:IsDescendantOf(Workspace)
		and not instance:FindFirstAncestorWhichIsA("SurfaceGui")
		and not instance:FindFirstAncestorWhichIsA("BillboardGui")
	then
		return
	end
	tracked[instance] = {}
	for _, property in properties do
		refresh(instance, property)
		instance:GetPropertyChangedSignal(property):Connect(function()
			refresh(instance, property)
		end)
	end
end

local function watchTree(root: Instance)
	for _, descendant in root:GetDescendants() do
		watch(descendant)
	end
	root.DescendantAdded:Connect(watch)
end

Localization.onChanged(function()
	for instance, entries in tracked do
		for property, entry in entries do
			local translated = Localization.tr(entry.source)
			if translated ~= entry.output then
				entry.output = translated
				local target: any = instance
				target[property] = translated
			end
		end
	end
end)

watchTree(playerGui)
watchTree(Workspace)
