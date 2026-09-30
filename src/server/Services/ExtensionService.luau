--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))

local ExtensionService = {}

-- Eklentiler süreli çalışır: gönderilen yetişkin hayvan `stayDuration` saniye boyunca bonus gelir kazanır,
-- sonra ana bölgesine döner (AnimalTaskService). Aynı anda en fazla FarmMath.getExtensionCapacity hayvan durur
-- (2; kapasite yükseltmeleriyle 3 ve 4). Hayvanın ana bölgedeki yeri boşalmaz, dönünce yerine oturur.

local function validateExtensionOwned(data: typeof(PlayerDataService.get(nil :: any)), extensionId: string): boolean
	local upgrade = Config.getExtensionUpgrade(extensionId)
	return upgrade ~= nil and data.purchased[upgrade.id] == true
end

local function nowSeconds(): number
	return DateTime.now().UnixTimestampMillis / 1000
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
	local now = nowSeconds()
	if FarmMath.countInExtension(data, extensionId, now) >= FarmMath.getExtensionCapacity(data, extensionId) then
		return false, "Eklenti dolu"
	end

	for _, animal in data.animals do
		if
			animal.animalId ~= extension.animalId
			or animal.zoneId ~= extension.sourceZoneId
			or not data.unlockedZones[animal.zoneId]
			or FarmMath.getActiveTask(animal, now) ~= nil
		then
			continue
		end
		-- Eklentiye yalnızca yetişkin hayvan gider (kayıtlı evre değil, süreden hesaplanan evre)
		local speed = FarmMath.getGrowthSpeed(data, animal.animalId, animal.zoneId)
		if FarmMath.getStage(animal.bornAt, now, speed) ~= "adult" then
			continue
		end
		-- Görev başlamadan önce gelir kesilir: bonus yalnızca bu andan sonraki süreye uygulanır.
		EconomyService.settlePlayer(player)
		animal.extensionId = extensionId
		animal.task = { kind = "extension", id = extensionId, startedAt = now, endsAt = now + extension.stayDuration }
		PlayerDataService.pushState(player)
		PlayerDataService.requestSave(player)
		PlotService.refreshPlayerWorld(player)
		return true, nil
	end

	return false, "Boşta yetişkin hayvan yok (ana bölgedeki yetişkinler gönderilebilir)"
end

-- Erken geri çağırma: en çok bekleyen hayvanı hemen ana bölgesine döndürür (kalan bonus süresi kaybolur).
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
	local now = nowSeconds()
	local chosen: typeof(data.animals[1])? = nil
	for _, animal in data.animals do
		local task = FarmMath.getActiveTask(animal, now)
		if task and task.kind == "extension" and task.id == extensionId then
			if not chosen or (chosen.task :: any).endsAt > task.endsAt then
				chosen = animal
			end
		end
	end
	if not chosen then
		return false, "Eklentide hayvan yok"
	end
	-- Önce kazanılan bonus kaydedilir, sonra hayvan döner.
	EconomyService.settlePlayer(player)
	chosen.task = nil
	chosen.extensionId = nil
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	PlotService.refreshPlayerWorld(player)
	return true, nil
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
			local success = ""
			if action == "assign" then
				ok, err = ExtensionService.tryAssign(player, extensionId)
				success = "Hayvan eklentiye gönderildi; süre dolunca geri döner."
			elseif action == "unassign" then
				ok, err = ExtensionService.tryUnassign(player, extensionId)
				success = "Hayvan geri çağrıldı."
			else
				return
			end
			if not ok and err then
				Remotes.get("Notify"):FireClient(player, err, "error")
			elseif ok then
				Remotes.get("Notify"):FireClient(player, success, "success")
			end
		end)
end

return ExtensionService
