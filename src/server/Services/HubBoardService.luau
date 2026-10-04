--!strict
-- Meydandaki "Sunucu Sıralaması" panosu: sunucudaki oyuncuların kasası ve ada (ana çiftlik) sayısı ve rebirth seviyesi, para sırasına göre.
-- Pano haritada kurulur (HubBuilder); burası yalnızca satırları günceller (değişmeyen metne yazılmaz).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local HubBoardService = {}

local REFRESH_SECONDS = 3
local initialized = false

type Entry = { name: string, cash: number, farms: number, rebirth: number }

local function findBoard(): Instance?
	local world = Workspace:FindFirstChild("World")
	return if world then world:FindFirstChild("PlayerBoard", true) else nil
end

local function refresh()
	local board = findBoard()
	if not board then
		return
	end
	local entries: { Entry } = {}
	for _, player in Players:GetPlayers() do
		local data = PlayerDataService.tryGet(player)
		if data then
			table.insert(entries, {
				name = player.DisplayName,
				cash = math.floor(data.cash),
				farms = #PlayerDataService.getFarmIds(player),
				rebirth = if data.progression then data.progression.count else 0,
			})
		end
	end
	table.sort(entries, function(a: Entry, b: Entry): boolean
		if a.cash ~= b.cash then
			return a.cash > b.cash
		end
		return a.name < b.name
	end)
	for index = 1, Config.MAP_PLOT_COUNT do
		local entry = entries[index]
		if entry then
			WorldUi.setBoardRow(
				board,
				index,
				`{index}. {entry.name}`,
				`{FarmMath.formatMoney(entry.cash)} · {entry.farms} ada\nRebirth: {entry.rebirth}`
			)
		else
			WorldUi.setBoardRow(board, index, "", "")
		end
	end
end

function HubBoardService.init()
	if initialized then
		return
	end
	initialized = true
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				refresh()
			end)
			if not ok then
				warn(`[HubBoard] {err}`)
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return HubBoardService
