--!strict
-- Hayvanların süreli görevleri (üretim tesisi / eklenti): süre dolunca hayvan ana bölgesine döner.
-- Gelir, görev penceresiyle hesaplanır (FarmMath.computeIncomeOverInterval); bu servis yalnızca bitmiş görevi
-- kayıttan temizler. Temizlemeden ÖNCE gelir kesilir: yoksa görev süresindeki gelir/bonus geriye dönük kaybolurdu.
local Players = game:GetService("Players")

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

local AnimalTaskService = {}

local SWEEP_SECONDS = 1
local initialized = false

-- Bir oyuncunun tüm çiftliklerinde (park edilmiş olanlar dahil) süresi dolan görevleri bitirir.
-- Dönen değer: en az bir hayvan eve döndü mü.
function AnimalTaskService.sweep(player: Player, now: number): boolean
	local expired = false
	for _, farmId in PlayerDataService.getFarmIds(player) do
		local farm = PlayerDataService.getFarmView(player, farmId)
		if not farm then
			continue
		end
		for _, animal in farm.animals do
			local task = animal.task
			if task and task.endsAt <= now then
				expired = true
				break
			end
		end
		if expired then
			break
		end
	end
	if not expired then
		return false
	end
	EconomyService.settlePlayer(player)
	for _, farmId in PlayerDataService.getFarmIds(player) do
		local farm = PlayerDataService.getFarmView(player, farmId)
		if not farm then
			continue
		end
		for _, animal in farm.animals do
			local task = animal.task
			if task and task.endsAt <= now then
				animal.task = nil
				animal.extensionId = nil
			end
		end
	end
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	local ok, err = pcall(function(): boolean
		PlotService.refreshPlayerWorld(player)
		return true
	end)
	if not ok then
		warn(`[AnimalTask] Hayvanlar döndü fakat görünüm yenilenemedi: {err}`)
	end
	return true
end

function AnimalTaskService.init()
	if initialized then
		return
	end
	initialized = true
	task.spawn(function()
		while true do
			task.wait(SWEEP_SECONDS)
			local now = DateTime.now().UnixTimestampMillis / 1000
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("WorldReady") == true and PlayerDataService.tryGet(player) then
					local ok, err = pcall(function(): boolean
						AnimalTaskService.sweep(player, now)
						return true
					end)
					if not ok then
						warn(`[AnimalTask] {err}`)
					end
				end
			end
		end
	end)
end

return AnimalTaskService
