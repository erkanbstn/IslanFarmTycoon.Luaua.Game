--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local player = Players.LocalPlayer
local IslandContext = {}
local changed = Instance.new("BindableEvent")
IslandContext.Changed = changed.Event
-- Kilitli (henüz alınmamış) bir adada durulurken paneller o adayı gösterir: bu yalnızca client'ta tutulan bir önizlemedir.
-- Sunucu kilitli adayı seçmeyi reddeder (seçim kilidi aşılamaz); gerçek bir seçim ya da çiftlik değişimi önizlemeyi siler.
local preview: string? = nil

player:GetAttributeChangedSignal("SelectedFarmIsland"):Connect(function()
	preview = nil
	changed:Fire()
end)
player:GetAttributeChangedSignal("ActiveMainFarmId"):Connect(function()
	preview = nil
	changed:Fire()
end)

-- Sunucunun bildiği seçili ada (önizleme hariç)
function IslandContext.selected(): string
	local id = player:GetAttribute("SelectedFarmIsland")
	return if typeof(id) == "string" and Config.FARM_ISLANDS[id] then id else "home"
end

function IslandContext.setPreview(islandId: string?)
	if islandId ~= nil and not Config.FARM_ISLANDS[islandId] then
		return
	end
	if preview == islandId then
		return
	end
	preview = islandId
	changed:Fire()
end

-- Panellerin gösterdiği ada: önizleme varsa o, yoksa sunucudaki seçili ada
function IslandContext.get(): string
	return preview or IslandContext.selected()
end

function IslandContext.name(): string
	local farm = player:GetAttribute("ActiveMainFarmId") or "1"
	return `Çiftlik {farm} · {Config.FARM_ISLANDS[IslandContext.get()].displayName}`
end

-- Yükseltmenin hangi ada sekmesinde listeleneceği (ahır ve ana ada bonusları her zaman "home").
function IslandContext.upgradeIsland(upgrade: Config.UpgradeConfig): string
	return Config.getUpgradeIsland(upgrade)
end

return IslandContext
