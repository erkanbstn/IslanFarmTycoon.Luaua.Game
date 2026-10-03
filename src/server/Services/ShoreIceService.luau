--!strict
-- Fiziksel buz kameraya göre taşınmaz; tüm oyuncular aynı sabit yüzeyi kullanır.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local SeasonVisuals = require(Shared:WaitForChild("Modules"):WaitForChild("SeasonVisuals"))
local ModelAssets = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("ModelAssets"))

local ShoreIceService = {}
local initialized = false
local bases: { [BasePart]: { Model } } = {}
local built: { [BasePart]: boolean } = {}
local waterGrounds: { [BasePart]: boolean } = {}
local folder: Folder? = nil
local UPDATE_SECONDS = 5
local WATER_Y = 0

local function clearWater(position: Vector3, radius: number, base: BasePart): boolean
	for ground in waterGrounds do
		if typeof(ground:GetAttribute("SwimDepth")) == "number" then
			local offset = ground.CFrame:PointToObjectSpace(position)
			if
				math.abs(offset.X) < ground.Size.X / 2 + radius + 4
				and math.abs(offset.Z) < ground.Size.Z / 2 + radius + 4
			then
				return false
			end
		end
	end
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		return false
	end
	local terrain = RaycastParams.new()
	terrain.FilterType = Enum.RaycastFilterType.Include
	terrain.FilterDescendantsInstances = { Workspace.Terrain }
	terrain.IgnoreWater = false
	for _, offset in
		{
			Vector3.zero,
			Vector3.new(radius, 0, 0),
			Vector3.new(-radius, 0, 0),
			Vector3.new(0, 0, radius),
			Vector3.new(0, 0, -radius),
		}
	do
		local hit = Workspace:Raycast(position + offset + Vector3.new(0, 20, 0), Vector3.new(0, -24, 0), terrain)
		if not hit or hit.Material ~= Enum.Material.Water or math.abs(hit.Position.Y - WATER_Y) > 1 then
			return false
		end
	end
	local exclusions: { Instance } = { base }
	if folder then
		table.insert(exclusions, folder)
	end
	local plot = base:FindFirstAncestorWhichIsA("Model")
	if plot then
		for _, part in plot:GetChildren() do
			if
				part:IsA("BasePart") and (part.Name == "Beach" or part.Name == "PlotBase" or part.Name == "IslandBase")
			then
				table.insert(exclusions, part)
			end
		end
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = exclusions
	for _, part in
		Workspace:GetPartBoundsInBox(
			CFrame.new(position + Vector3.new(0, 3, 0)),
			Vector3.new(radius * 2 + 2, 8, radius * 2 + 2),
			overlap
		)
	do
		if part.Name == "Ground" and typeof(part:GetAttribute("SwimDepth")) == "number" then
			return false
		end
		-- Gerçek geometriyi ışınla doğrula; ada disklerinin kare bounds köşeleri deniz değildir.
		if part.CanCollide and part.Name ~= "Beach" and part.Name ~= "IslandBase" and part.Name ~= "PlotBase" then
			return false
		end
	end
	return true
end

local function build(base: BasePart): { Model }
	local result: { Model } = {}
	local radius = math.max(base.Size.Y, base.Size.Z) / 2
	local seed = math.abs(math.floor(base.Position.X * 7 + base.Position.Z * 13)) + 1
	local random = Random.new(seed)
	for index = 1, 12 do
		local cluster = math.floor((index - 1) / 3)
		local angle = cluster * math.pi / 2
			+ (seed % 31) / 31
			+ (((index - 1) % 3) - 1) * 0.14
			+ random:NextNumber(-0.02, 0.02)
		local edge = radius + 15 + random:NextNumber(0, 7)
		local position = Vector3.new(
			base.Position.X + math.cos(angle) * edge,
			WATER_Y + 0.35,
			base.Position.Z + math.sin(angle) * edge
		)
		local scale = random:NextNumber(0.65, 1.05)
		local footprint = 4.7 * scale
		local crowded = false
		for _, previous in result do
			if (previous:GetPivot().Position - position).Magnitude < footprint + 4.7 * previous:GetScale() then
				crowded = true
				break
			end
		end
		if
			crowded
			or math.abs(position.X) + footprint > 545
			or math.abs(position.Z) + footprint > 545
			or not clearWater(position, footprint, base)
		then
			continue
		end
		local model = ModelAssets.clone("SeasonModels", "IceFloe")
		if not model then
			warn("[ShoreIceService] SeasonModels/IceFloe eksik")
			break
		end
		model.Name = `IceFloe_{index}`
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		model:ScaleTo(scale)
		model:PivotTo(CFrame.new(position) * CFrame.Angles(0, angle, 0))
		model.Parent = folder
		table.insert(result, model)
	end
	return result
end

local function register(instance: Instance)
	if instance:IsA("BasePart") and instance.Name == "Ground" and instance:FindFirstAncestor("Plots") then
		waterGrounds[instance] = true
	end
	if
		instance:IsA("BasePart")
		and (instance.Name == "PlotBase" or instance.Name == "IslandBase")
		and instance:FindFirstAncestor("Plots")
	then
		bases[instance] = bases[instance] or {}
	end
end

local function update()
	local season = Environment.getSeason()
	local intensity = math.clamp(SeasonVisuals.sample(season.id, Environment.getSeasonProgress()).ice, 0, 1)
	for base, models in bases do
		local available = base:IsDescendantOf(Workspace)
			and (base.Name ~= "IslandBase" or base:GetAttribute("Locked") == false)
		if not available or intensity < 0.08 then
			for _, model in models do
				model:Destroy()
			end
			table.clear(models)
			built[base] = nil
		elseif intensity >= 0.2 then
			if not built[base] then
				models = build(base)
				bases[base] = models
				built[base] = true
			end
		end
		for _, model in models do
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					-- Donmuş yüzeyin boyutu sabittir; erime görüntüsü fiziği kaydırmaz.
					part.Transparency = 0.12 + (1 - intensity) * 0.65
					part.CanCollide = true
					part.CanQuery = true
				end
			end
		end
	end
end

function ShoreIceService.init()
	if initialized then
		return
	end
	initialized = true
	local root = Instance.new("Folder")
	root.Name = "ShoreIce"
	root.Parent = Workspace
	folder = root
	local plots = Workspace:FindFirstChild("Plots")
	if plots then
		for _, instance in plots:GetDescendants() do
			register(instance)
		end
	end
	local added = Workspace.DescendantAdded:Connect(register)
	local removed = Workspace.DescendantRemoving:Connect(function(instance: Instance)
		if instance:IsA("BasePart") then
			waterGrounds[instance] = nil
			built[instance] = nil
		end
		if instance:IsA("BasePart") and bases[instance] then
			for _, model in bases[instance] do
				model:Destroy()
			end
			bases[instance] = nil
		end
	end)
	local elapsed = UPDATE_SECONDS
	local heartbeat = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= UPDATE_SECONDS then
			elapsed = 0
			update()
		end
	end)
	root.Destroying:Connect(function()
		added:Disconnect()
		removed:Disconnect()
		heartbeat:Disconnect()
		table.clear(bases)
		table.clear(built)
		table.clear(waterGrounds)
	end)
end

return ShoreIceService
