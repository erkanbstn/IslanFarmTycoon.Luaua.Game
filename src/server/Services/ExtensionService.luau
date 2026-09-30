--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))

local ExtensionService = {}

local function validateExtensionOwned(data: typeof(PlayerDataService.get(nil :: any)), extensionId: string): boolean
	local upgrade = Config.getExtensionUpgrade(extensionId)
	return upgrade ~= nil and data.purchased[upgrade.id] == true
end

function ExtensionService.tryAssign(player: Player, extensionId: string): (boolean, string?)
	local extension = Config.getExtension(extensionId)
	if not extension then
		return false, "Bilinmeyen eklenti"
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true then
		return false, "Veri henüz yüklenmedi"
	end
	if not validateExtensionOwned(data, extensionId) then
		return false, "Eklenti satın alınmamış"
	end
	if FarmMath.countInExtension(data, extensionId) >= extension.capacity then
		return false, "Eklenti dolu"
	end

	for _, animal in data.animals do
		if animal.extensionId == extensionId then
			continue
		end
		if animal.animalId ~= extension.animalId then
			continue
		end
		if animal.zoneId ~= extension.sourceZoneId then
			continue
		end
		if not data.unlockedZones[animal.zoneId] then
			continue
		end
		if animal.stage ~= "adult" then
			continue
		end
		animal.extensionId = extensionId
		PlayerDataService.pushState(player)
		PlayerDataService.requestSave(player)
		PlotService.refreshPlayerWorld(player)
		return true, nil
	end

	return false, "Uygun yetişkin hayvan yok (ana bölgede boş slot için)"
end

function ExtensionService.tryUnassign(player: Player, extensionId: string): (boolean, string?)
	local extension = Config.getExtension(extensionId)
	if not extension then
		return false, "Bilinmeyen eklenti"
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true then
		return false, "Veri henüz yüklenmedi"
	end
	if not validateExtensionOwned(data, extensionId) then
		return false, "Eklenti satın alınmamış"
	end

	for index = #data.animals, 1, -1 do
		local animal = data.animals[index]
		if animal.extensionId == extensionId then
			local zone = Config.ZONES[extension.sourceZoneId]
			if
				zone
				and FarmMath.countInZone(data, extension.sourceZoneId)
					>= FarmMath.getZoneCapacity(data, extension.sourceZoneId)
			then
				return false, "Ana bölge dolu; önce yer aç"
			end
			animal.extensionId = nil
			PlayerDataService.pushState(player)
			PlayerDataService.requestSave(player)
			PlotService.refreshPlayerWorld(player)
			return true, nil
		end
	end

	return false, "Eklentide hayvan yok"
end

function ExtensionService.init()
	Remotes.get("RequestExtensionAction").OnServerEvent
		:Connect(function(player: Player, extensionId: unknown, action: unknown)
			if typeof(extensionId) ~= "string" or typeof(action) ~= "string" then
				return
			end
			if not RateLimiter.allow(player, "extension", 0.25) then
				return
			end
			local ok, err
			if action == "assign" then
				ok, err = ExtensionService.tryAssign(player, extensionId)
			elseif action == "unassign" then
				ok, err = ExtensionService.tryUnassign(player, extensionId)
			else
				return
			end
			if not ok and err then
				Remotes.get("Notify"):FireClient(player, err, "error")
			elseif ok then
				Remotes.get("Notify"):FireClient(player, "Hayvan listesi güncellendi.", "success")
			end
		end)
end

return ExtensionService
