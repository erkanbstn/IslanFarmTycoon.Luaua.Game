--!strict
-- Kıyı buzu yalnızca görseldir: yürünebilir yüzey, sunucu fiziği veya Terrain değişmez.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local modules = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules")
local Environment = require(modules:WaitForChild("Environment"))
local SeasonVisuals = require(modules:WaitForChild("SeasonVisuals"))
local StartupGate = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("StartupGate"))
StartupGate.wait(4.5)

local WATER_Y = 0
local UPDATE_SECONDS = 2
local CANDIDATES_PER_BASE = 12
local QUALITY = {
	low = { budget = 8, distance = 180 },
	medium = { budget = 18, distance = 260 },
	high = { budget = 32, distance = 360 },
}

type Floe = { part: Part, base: BasePart?, key: string?, tween: Tween? }
type Candidate = { base: BasePart, position: Vector3, size: Vector3, angle: number, key: string, distance: number }

local folder = Instance.new("Folder")
folder.Name = "LocalShoreIce"
folder.Parent = Workspace
local bases: { [BasePart]: RBXScriptConnection } = {}
local waterGrounds: { [BasePart]: boolean } = {}
local beachDiscs: { [BasePart]: boolean } = {}
local pool: { Floe } = {}
local alive = true

local terrainProbe = RaycastParams.new()
terrainProbe.FilterType = Enum.RaycastFilterType.Exclude
terrainProbe.IgnoreWater = true
local waterProbe = RaycastParams.new()
waterProbe.FilterType = Enum.RaycastFilterType.Exclude
waterProbe.IgnoreWater = false
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.MaxParts = 1

local function hide(floe: Floe)
	if floe.tween then
		floe.tween:Cancel()
		floe.tween = nil
	end
	floe.part.Transparency = 1
	floe.base = nil
	floe.key = nil
end

local function hideBase(base: BasePart)
	for _, floe in pool do
		if floe.base == base then
			hide(floe)
		end
	end
end

local function register(instance: Instance)
	if not instance:IsA("BasePart") or not instance:FindFirstAncestor("Plots") then
		return
	end
	if instance.Name == "Ground" then
		-- SwimDepth daha sonra çoğalsa da yeni bir dünya taraması gerekmez.
		waterGrounds[instance] = true
	elseif instance.Name == "Beach" then
		beachDiscs[instance] = true
	elseif (instance.Name == "PlotBase" or instance.Name == "IslandBase") and not bases[instance] then
		bases[instance] = instance:GetAttributeChangedSignal("Locked"):Connect(function()
			if instance:GetAttribute("Locked") == true then
				hideBase(instance)
			end
		end)
	end
end

local function unregister(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	waterGrounds[instance] = nil
	beachDiscs[instance] = nil
	local connection = bases[instance]
	if connection then
		connection:Disconnect()
		bases[instance] = nil
		hideBase(instance)
	end
end

local added = Workspace.DescendantAdded:Connect(register)
local removed = Workspace.DescendantRemoving:Connect(unregister)
local plots = Workspace:FindFirstChild("Plots")
if plots then
	for _, instance in plots:GetDescendants() do
		register(instance)
	end
end

local function resizePool(budget: number)
	while #pool > budget do
		local floe = table.remove(pool)
		if floe then
			hide(floe)
			floe.part:Destroy()
		end
	end
	while #pool < budget do
		local part = Instance.new("Part")
		part.Name = "ShoreIcePatch"
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.16, 0.1, 0.1)
		part.Material = Enum.Material.Ice
		part.Color = Color3.fromRGB(204, 231, 240)
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Transparency = 1
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = folder
		table.insert(pool, { part = part, base = nil, key = nil, tween = nil })
	end
end

local function clearWater(position: Vector3, radius: number): boolean
	-- Görünmez balık kafesi zeminleri CanQuery=false olabilir; onları açıkça dışarıda tut.
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
	-- İskele, köprü veya kafesin herhangi bir parçası buzun üstündeyse aday elenir.
	if
		#Workspace:GetPartBoundsInBox(
			CFrame.new(position + Vector3.new(0, 5, 0)),
			Vector3.new(radius * 2 + 2, 16, radius * 2 + 2),
			overlap
		) > 0
	then
		return false
	end
	for _, offset in
		{
			Vector3.zero,
			Vector3.new(radius, 0, radius),
			Vector3.new(-radius, 0, radius),
			Vector3.new(radius, 0, -radius),
			Vector3.new(-radius, 0, -radius),
		}
	do
		-- Su atlanır; kara/kaya suyun iki stud altına kadar yaklaşıyorsa buz konmaz.
		if Workspace:Raycast(position + offset + Vector3.new(0, 20, 0), Vector3.new(0, -22, 0), terrainProbe) then
			return false
		end
	end
	local hit = Workspace:Raycast(position + Vector3.new(0, 20, 0), Vector3.new(0, -24, 0), waterProbe)
	return hit ~= nil and hit.Material == Enum.Material.Water and math.abs(hit.Position.Y - WATER_Y) < 2
end

local function update()
	local choice = player:GetAttribute("EffectsQuality")
	local quality = if choice == "low" then QUALITY.low elseif choice == "high" then QUALITY.high else QUALITY.medium
	resizePool(quality.budget)
	local season = Environment.getSeason()
	local intensity = math.clamp(SeasonVisuals.sample(season.id, Environment.getSeasonProgress()).ice, 0, 1)
	local camera = Workspace.CurrentCamera
	if not camera or intensity < 0.02 then
		for _, floe in pool do
			hide(floe)
		end
		return
	end
	local exclusions: { Instance } = { folder }
	if player.Character then
		table.insert(exclusions, player.Character)
	end
	terrainProbe.FilterDescendantsInstances = exclusions
	waterProbe.FilterDescendantsInstances = exclusions
	local structureExclusions = table.clone(exclusions)
	for base in bases do
		-- Diskin kare bounding box'ı köşelerde denizi kaplar; gerçek kara raylerle denetlenir.
		table.insert(structureExclusions, base)
	end
	for beach in beachDiscs do
		table.insert(structureExclusions, beach)
	end
	overlap.FilterDescendantsInstances = structureExclusions
	local candidates: { Candidate } = {}
	for base in bases do
		if
			(base.Name == "IslandBase" and base:GetAttribute("Locked") ~= false) or not base:IsDescendantOf(Workspace)
		then
			continue
		end
		if (base.Position - camera.CFrame.Position).Magnitude > quality.distance + 100 then
			continue
		end
		-- MapBuilder silindirleri X ekseni çevrilmiş disklerdir; yatay çap Size.Y/Z'dedir.
		local radius = math.max(base.Size.Y, base.Size.Z) / 2
		local seed = math.abs(math.floor(base.Position.X * 7 + base.Position.Z * 13)) + 1
		local random = Random.new(seed)
		for index = 1, CANDIDATES_PER_BASE do
			-- Üç yakın pul bir küme oluşturur; dört küme kıyıya sabitlenir, sürüklenmez.
			local cluster = math.floor((index - 1) / 3)
			local angle = cluster * math.pi / 2 + (seed % 31) / 31 + random:NextNumber(-0.06, 0.06)
			local edge = radius + 15 + random:NextNumber(0, 7)
			local position = Vector3.new(
				base.Position.X + math.cos(angle) * edge,
				WATER_Y + 0.13,
				base.Position.Z + math.sin(angle) * edge
			)
			local size =
				Vector3.new(0.14 + random:NextNumber(0, 0.05), random:NextNumber(3.8, 7), random:NextNumber(2.4, 4.8))
			local footprint = math.max(size.Y, size.Z) / 2
			if math.abs(position.X) + footprint > 545 or math.abs(position.Z) + footprint > 545 then
				continue
			end
			local distance = (position - camera.CFrame.Position).Magnitude
			local _, onScreen = camera:WorldToViewportPoint(position)
			if onScreen and distance < quality.distance then
				table.insert(candidates, {
					base = base,
					position = position,
					size = size,
					angle = angle,
					key = `{seed}:{index}`,
					distance = distance,
				})
			end
		end
	end
	table.sort(candidates, function(a: Candidate, b: Candidate): boolean
		return a.distance < b.distance
	end)
	local used = 0
	local checks = 0
	for _, candidate in candidates do
		checks += 1
		if used >= quality.budget or checks > quality.budget * 2 then
			break
		end
		local radius = math.max(candidate.size.Y, candidate.size.Z) / 2
		if not clearWater(candidate.position, radius) then
			continue
		end
		used += 1
		local floe = pool[used]
		if floe.tween then
			floe.tween:Cancel()
		end
		if floe.base ~= candidate.base or floe.key ~= candidate.key then
			floe.part.Transparency = 1
			floe.part.CFrame = CFrame.new(candidate.position) * CFrame.Angles(0, candidate.angle, math.pi / 2)
		end
		floe.base = candidate.base
		floe.key = candidate.key
		local scale = 0.32 + intensity * 0.68
		local size = Vector3.new(candidate.size.X, candidate.size.Y * scale, candidate.size.Z * scale)
		local transparency = 0.18 + (1 - intensity) * 0.72
		if player:GetAttribute("ReducedMotion") == true then
			floe.part.Size = size
			floe.part.Transparency = transparency
			floe.tween = nil
		else
			floe.tween = TweenService:Create(
				floe.part,
				TweenInfo.new(UPDATE_SECONDS, Enum.EasingStyle.Sine),
				{ Size = size, Transparency = transparency }
			)
			floe.tween:Play()
		end
	end
	for index = used + 1, #pool do
		hide(pool[index])
	end
end

local qualityChanged = player:GetAttributeChangedSignal("EffectsQuality"):Connect(update)
local motionChanged = player:GetAttributeChangedSignal("ReducedMotion"):Connect(update)
script.Destroying:Connect(function()
	alive = false
	added:Disconnect()
	removed:Disconnect()
	qualityChanged:Disconnect()
	motionChanged:Disconnect()
	for _, connection in bases do
		connection:Disconnect()
	end
	for _, floe in pool do
		hide(floe)
	end
	folder:Destroy()
end)

-- İş parçacığı sabit aralıklarla çalışır; RenderStepped bağlantısı veya kare başına tarama yoktur.
while alive do
	update()
	task.wait(UPDATE_SECONDS)
end
