--!strict
-- Toplama platformunun yanındaki para yığını: depo doldukça altın ve para büyür (0..5 kademe).
-- Çalışma anında kurulur (haritaya kaydedilmez), yalnızca kademe değişince yeniden çizilir.
-- Kademe hesabı FarmMath.getStorageLevel (paylaşılan, test edilir).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local ModelAssets = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("ModelAssets"))

-- Services katmanı bu dosyaya bağlanır; döngü olmasın diye tembel require (ALLOW'da gerekçe)
local function playerDataService()
	return require(script.Parent.Parent:WaitForChild("Services"):WaitForChild("PlayerDataService"))
end

local function plotService()
	return require(script.Parent.Parent:WaitForChild("Services"):WaitForChild("PlotService"))
end

local CollectorVisualService = {}

local PILE_NAME = "CollectorPile"
local SIDE_OFFSET = 6.4 -- Platformun (rim dahil) dışında, yerel +X tarafı
local UPDATE_SECONDS = 1

function CollectorVisualService.clear(plot: Model)
	local pile = plot:FindFirstChild(PILE_NAME)
	if pile then
		pile:Destroy()
	end
end

function CollectorVisualService.apply(plot: Model, level: number)
	local existing = plot:FindFirstChild(PILE_NAME)
	if level <= 0 then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing and existing:GetAttribute("Level") == level then
		return
	end
	local collector = plot:FindFirstChild("Collector")
	if not collector or not collector:IsA("BasePart") then
		return
	end
	if existing then
		existing:Destroy()
	end
	-- Zemin: platformun merkezi zeminden 0.6 stud yukarıdadır (MapBuilder)
	local ground = CFrame.new(collector.Position.X, collector.Position.Y - 0.6, collector.Position.Z)
		* collector.CFrame.Rotation
	-- Hazır model (assets/Collectors/CollectorPile_Lv<1-5>, pivot = platform zemini)
	local model = ModelAssets.clone("Collectors", `CollectorPile_Lv{level}`)
	if not model then
		warn(`[CollectorVisual] assets/Collectors/CollectorPile_Lv{level}.rbxmx bulunamadı`)
		return
	end
	model:PivotTo(ground * CFrame.new(SIDE_OFFSET, 0, 0))
	model.Name = PILE_NAME
	model:SetAttribute("Level", level)
	model.Parent = plot
end

local function refreshAll()
	local plots, playerData = plotService(), playerDataService()
	for _, player in Players:GetPlayers() do
		for farmId, plot in plots.getAllOwned(player) do
			local data = playerData.getFarmView(player, farmId)
			if not data then
				continue
			end
			-- Otomatik toplayıcıda depo hiç dolmaz: yığın da yok
			local level = if FarmMath.hasAutoCollect(data)
				then 0
				else FarmMath.getStorageLevel(data.stored, FarmMath.getStorageCap(data))
			CollectorVisualService.apply(plot, level)
		end
	end
end

function CollectorVisualService.init()
	task.spawn(function()
		while true do
			task.wait(UPDATE_SECONDS)
			local ok, err = pcall(function(): boolean
				refreshAll()
				return true
			end)
			if not ok then
				warn(`[CollectorVisual] {err}`)
			end
		end
	end)
end

return CollectorVisualService
