--!strict
-- Oyun olaylarının sesleri: çiftlik durumundaki değişikliği (hayvan, yükseltme, üretim, sipariş, başarım...) önceki duruma
-- bakarak anlar ve Config.SOUNDS'taki yuvayı çalar. Kimliği boş olan yuva sessizdir; ses dosyası yüklenince kod değişmez.
-- Oturumun ilk durumu (giriş, çiftlik değiştirme) ses çalmaz. Liste ve yuvalar: docs/SESLER.md.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local ClientState = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientState"))
local Sfx = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Sfx"))

type PlayerSave = GameTypes.PlayerSave

local player = Players.LocalPlayer

type Snapshot = {
	farmId: string,
	animals: number,
	purchased: number,
	expansions: number,
	barnLevel: number,
	jobs: { [string]: boolean }, -- çalışan üretim işleri
	ready: { [string]: boolean }, -- hazır bekleyen işler
	contracts: number,
	achievements: number,
	dailyDay: number,
	items: number,
	equipped: string,
}

local function countKeys(map: { [string]: any }?): number
	local count = 0
	if not map then
		return 0
	end
	for _, value in map do
		if value then
			count += 1
		end
	end
	return count
end

local function sumValues(map: { [string]: number }?): number
	local total = 0
	if not map then
		return 0
	end
	for _, value in map do
		total += value
	end
	return total
end

local function take(state: PlayerSave): Snapshot
	local now = Workspace:GetServerTimeNow()
	local jobs: { [string]: boolean } = {}
	local ready: { [string]: boolean } = {}
	for recipeId, job in state.production do
		jobs[recipeId] = true
		if job.readyAt <= now then
			ready[recipeId] = true
		end
	end
	local equipped: { string } = {}
	if state.inventory then
		for slot, itemId in state.inventory.equipped do
			table.insert(equipped, `{slot}={itemId}`)
		end
		table.sort(equipped)
	end
	return {
		farmId = state.activeMainFarmId or "1",
		animals = #state.animals,
		purchased = countKeys(state.purchased),
		expansions = sumValues(state.expansions),
		barnLevel = state.barnLevel or 1,
		jobs = jobs,
		ready = ready,
		contracts = if state.contracts then state.contracts.completed else 0,
		achievements = countKeys(state.achievements),
		dailyDay = if state.daily then state.daily.day else 0,
		items = if state.inventory then countKeys(state.inventory.items) else 0,
		equipped = table.concat(equipped, ","),
	}
end

local previous: Snapshot? = nil

local function compare(before: Snapshot, now: Snapshot)
	-- Başka çiftliğe geçildiyse sayılar başka profile aittir
	if before.farmId ~= now.farmId then
		return
	end
	if now.animals > before.animals then
		Sfx.play("animal_buy", 0.05)
	elseif now.animals < before.animals then
		Sfx.play("animal_sell", 0.05)
	end
	if now.barnLevel > before.barnLevel then
		Sfx.play("barn_level")
	elseif now.purchased > before.purchased then
		Sfx.play("upgrade_buy", 0.05)
	elseif now.expansions > before.expansions then
		Sfx.play("expansion_buy", 0.05)
	end
	for recipeId in now.jobs do
		if not before.jobs[recipeId] then
			Sfx.play("production_start", 0.05)
			break
		end
	end
	for recipeId in before.jobs do
		if not now.jobs[recipeId] then
			Sfx.play("production_claim", 0.05)
			break
		end
	end
	for recipeId in now.ready do
		if not before.ready[recipeId] then
			Sfx.play("production_ready")
			break
		end
	end
	if now.contracts > before.contracts then
		Sfx.play("contract_done")
	end
	if now.achievements > before.achievements then
		Sfx.play("achievement")
	end
	if now.dailyDay ~= before.dailyDay and now.dailyDay > 0 then
		Sfx.play("daily_claim")
	end
	if now.items > before.items then
		Sfx.play("item_buy")
	elseif now.equipped ~= before.equipped then
		Sfx.play("item_equip")
	end
end

ClientState.onChanged(function(state: PlayerSave, _structural: boolean)
	local now = take(state)
	local before = previous
	previous = now
	if before then
		compare(before, now)
	end
end)

-- Hazır olma anı kayıt değişmeden de gelir (süre dolar): saniyede bir kontrol edilir
task.spawn(function()
	while true do
		task.wait(1)
		local state = ClientState.get()
		local before = previous
		if state and before and player:GetAttribute("DataStatus") == "Active" then
			local now = take(state)
			for recipeId in now.ready do
				if not before.ready[recipeId] then
					Sfx.play("production_ready")
					break
				end
			end
			before.ready = now.ready
		end
	end
end)

-- Mevsim değişimi (sunucu saatinden türer)
local lastSeason = Environment.getSeason().id
task.spawn(function()
	while true do
		task.wait(5)
		local season = Environment.getSeason().id
		if season ~= lastSeason then
			lastSeason = season
			Sfx.play("season_change")
		end
	end
end)
