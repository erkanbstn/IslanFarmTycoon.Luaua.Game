--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local player = Players.LocalPlayer
local IslandContext = {}
local changed = Instance.new("BindableEvent")
IslandContext.Changed = changed.Event
player:GetAttributeChangedSignal("SelectedFarmIsland"):Connect(function()
	changed:Fire()
end)
player:GetAttributeChangedSignal("ActiveMainFarmId"):Connect(function()
	changed:Fire()
end)

function IslandContext.get(): string
	local id = player:GetAttribute("SelectedFarmIsland")
	return if typeof(id) == "string" and Config.FARM_ISLANDS[id] then id else "home"
end

function IslandContext.name(): string
	local farm = player:GetAttribute("ActiveMainFarmId") or "1"
	return `Çiftlik {farm} · {Config.FARM_ISLANDS[IslandContext.get()].displayName}`
end

function IslandContext.upgradeIsland(upgrade: Config.UpgradeConfig): string
	local stage = Config.ROADMAP_STAGES[upgrade.stage]
	return if stage and stage.island then stage.island else "home"
end

function IslandContext.hasAnimal(animalId: string): boolean
	for _, zone in Config.ZONES do
		if zone.island == IslandContext.get() and table.find(zone.allowedAnimals, animalId) then
			return true
		end
	end
	return false
end

return IslandContext
