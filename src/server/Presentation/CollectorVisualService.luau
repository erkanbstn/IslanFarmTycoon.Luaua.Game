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

local GOLD = Color3.fromRGB(255, 200, 60)
local GOLD_DARK = Color3.fromRGB(214, 160, 40)
local BILL = Color3.fromRGB(96, 170, 96)
local BAND = Color3.fromRGB(235, 225, 190)
local PILE_NAME = "CollectorPile"
local SIDE_OFFSET = 6.4 -- Platformun (rim dahil) dışında, yerel +X tarafı
local UPDATE_SECONDS = 1

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Altın para sütunu (silindir ekseni X olduğu için dik durması için Z etrafında döndürülür)
local function coinStack(parent: Instance, base: CFrame, coins: number)
	for index = 1, coins do
		local coin = part(
			parent,
			"Coin",
			Vector3.new(0.28, 1.5, 1.5),
			base * CFrame.new((index % 2) * 0.05, 0.14 + (index - 1) * 0.28, 0) * CFrame.Angles(0, 0, math.rad(90)),
			if index % 3 == 0 then GOLD_DARK else GOLD,
			Enum.Material.Metal
		)
		coin.Shape = Enum.PartType.Cylinder
	end
end

local function billBundle(parent: Instance, base: CFrame, layers: number)
	for layer = 1, layers do
		local yaw = math.rad(((layer * 23) % 30) - 15)
		part(
			parent,
			"Bills",
			Vector3.new(1.9, 0.45, 1),
			base * CFrame.new(0, 0.225 + (layer - 1) * 0.45, 0) * CFrame.Angles(0, yaw, 0),
			BILL,
			Enum.Material.Fabric
		)
	end
	part(
		parent,
		"BillBand",
		Vector3.new(0.3, layers * 0.45 + 0.05, 1.05),
		base * CFrame.new(0, layers * 0.225, 0),
		BAND,
		Enum.Material.Fabric
	)
end

-- Altın külçe piramidi: 3 + 2 + 1 (kademe 4'te alt sıra, kademe 5'te tamamı)
local function goldBars(parent: Instance, base: CFrame, full: boolean)
	local rows = if full then { 3, 2, 1 } else { 3 }
	for row, count in rows do
		for slot = 1, count do
			local x = (slot - (count + 1) / 2) * 1.35
			part(
				parent,
				"GoldBar",
				Vector3.new(1.25, 0.6, 0.75),
				base * CFrame.new(x, 0.3 + (row - 1) * 0.6, 0),
				GOLD,
				Enum.Material.Metal
			)
		end
	end
end

local function build(model: Model, frame: CFrame, level: number)
	-- Kademe büyüdükçe yığın çeşitlenir; küçük kademeler yalnızca birkaç para gösterir.
	local stacks = math.min(level, 4)
	local layout = { Vector2.new(-0.9, -0.9), Vector2.new(0.9, -0.9), Vector2.new(-0.9, 0.9), Vector2.new(0.9, 0.9) }
	for index = 1, stacks do
		local spot = layout[index]
		coinStack(model, frame * CFrame.new(spot.X, 0, spot.Y), math.min(2 + level + (index % 3), 8))
	end
	if level >= 2 then
		billBundle(model, frame * CFrame.new(0, 0, 2.3), math.min(level, 4))
	end
	if level >= 4 then
		goldBars(model, frame * CFrame.new(0, 0, -2.4), level >= 5)
	end
	if level >= 5 then
		local crown = part(
			model,
			"GoldCrown",
			Vector3.new(0.4, 1.7, 1.7),
			frame * CFrame.new(0, 8 * 0.28 + 0.85, 0) * CFrame.Angles(0, 0, math.rad(90)),
			GOLD,
			Enum.Material.Neon
		)
		crown.Shape = Enum.PartType.Cylinder
	end
end

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
	-- Hazır model (assets/Collectors/CollectorPile_Lv<1-5>); yoksa kod kurucusu
	local model = ModelAssets.clone("Collectors", `CollectorPile_Lv{level}`)
	if model then
		model.Name = PILE_NAME
		model:PivotTo(ground * CFrame.new(SIDE_OFFSET, 0, 0))
	else
		model = Instance.new("Model")
		model.Name = PILE_NAME
		build(model, ground * CFrame.new(SIDE_OFFSET, 0, 0), level)
	end
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
			local ok, err = pcall(refreshAll)
			if not ok then
				warn(`[CollectorVisual] {err}`)
			end
		end
	end)
end

return CollectorVisualService
