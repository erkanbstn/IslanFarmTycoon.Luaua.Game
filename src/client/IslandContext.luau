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

-- Yükseltmenin hangi ada sekmesinde listeleneceği (ahır ve ana ada bonusları her zaman "home").
function IslandContext.upgradeIsland(upgrade: Config.UpgradeConfig): string
	if upgrade.kind == "barn" then
		return "home"
	end
	if upgrade.kind == "island" and upgrade.islandId then
		return upgrade.islandId
	end
	if upgrade.kind == "zone" and upgrade.zoneId then
		local zone = Config.ZONES[upgrade.zoneId]
		if zone then
			return zone.island
		end
	end
	if upgrade.kind == "extension" and upgrade.extensionId then
		local extension = Config.getExtension(upgrade.extensionId)
		if extension then
			return extension.island
		end
	end
	local boostHome: { [string]: boolean } = {
		silo = true,
		milk_machine = true,
		milk_factory = true,
		fish_farm = true,
		fishing_boat = true,
		auto_collector = true,
	}
	if boostHome[upgrade.id] then
		return "home"
	end
	local boostByIsland: { [string]: string } = {
		egg_factory = "poultry",
		hatchery = "poultry",
		golden_horseshoe = "horse",
		horse_training = "horse",
		cheese_dairy = "goat",
	}
	local mapped = boostByIsland[upgrade.id]
	if mapped then
		return mapped
	end
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
