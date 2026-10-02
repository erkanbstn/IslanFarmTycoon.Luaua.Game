--!strict
-- Sunucu ekonomisinden bağımsız, her karede akıcı tekne hareketi. Rota su üstünde doğrulanır.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EffectSettings = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("EffectSettings"))
local ClientModelAssets = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientModelAssets"))
local player = Players.LocalPlayer

type Boat = {
	model: Model,
	home: CFrame?,
	patrolX: number,
	patrolZ: number,
	phase: number,
	checkedAt: number,
	clear: boolean,
	resumeAt: number?,
	from: CFrame?,
	wakes: { BasePart },
	atHome: boolean,
}
local boats: { [Model]: Boat } = {}
local selected: { Boat } = {}
local selectionElapsed = 1
local alive = true
local wakesFolder = Instance.new("Folder")
wakesFolder.Name = "LocalBoatWake"
wakesFolder.Parent = Workspace
local PERIOD = 88
local RAY_HEIGHT = Vector3.new(0, 14, 0)
local RAY_DOWN = Vector3.new(0, -17, 0)

local function hideWake(boat: Boat)
	for _, wake in boat.wakes do
		wake.Transparency = 1
	end
end

local function register(instance: Instance)
	if not instance:IsA("Model") or instance.Name ~= "fishing_boat" or boats[instance] then
		return
	end
	local parent = instance.Parent
	if not parent or parent.Name ~= "Upgrades" or not instance:FindFirstAncestor("Plots") then
		return
	end
	boats[instance] = {
		model = instance,
		home = nil,
		patrolX = 6,
		patrolZ = 3,
		phase = 0,
		checkedAt = -math.huge,
		clear = false,
		resumeAt = nil,
		from = nil,
		wakes = {},
		atHome = false,
	}
end

local function remove(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local boat = boats[instance]
	if not boat then
		return
	end
	boats[instance] = nil
	for _, wake in boat.wakes do
		wake:Destroy()
	end
	if boat.home and instance.PrimaryPart and instance:GetAttribute("BuildPopActive") ~= true then
		instance:PivotTo(boat.home)
	end
end

local function routePosition(home: CFrame, x: number, z: number, phase: number): Vector3
	return home:PointToWorldSpace(Vector3.new(math.sin(phase) * x, 0, math.cos(phase) * z))
end

local function checkRoute(boat: Boat): boolean
	local home = boat.home
	if not home then
		return false
	end
	local exclusions: { Instance } = { boat.model, wakesFolder }
	if player.Character then
		table.insert(exclusions, player.Character)
	end
	local land = RaycastParams.new()
	land.FilterType = Enum.RaycastFilterType.Exclude
	land.FilterDescendantsInstances = exclusions
	land.IgnoreWater = true
	local water = RaycastParams.new()
	water.FilterType = Enum.RaycastFilterType.Exclude
	water.FilterDescendantsInstances = exclusions
	water.IgnoreWater = false
	local plot = boat.model.Parent and boat.model.Parent.Parent
	local zones = plot and plot:FindFirstChild("Zones")
	local fishGrounds: { BasePart } = {}
	if zones then
		for _, zone in zones:GetChildren() do
			local ground = zone:FindFirstChild("Ground")
			if ground and ground:IsA("BasePart") and typeof(ground:GetAttribute("SwimDepth")) == "number" then
				table.insert(fishGrounds, ground)
			end
		end
	end
	-- Tüm elips seyrek fakat geniş bir gövde payıyla taranır; kare başına raycast yoktur.
	for index = 0, 7 do
		local position = routePosition(home, boat.patrolX, boat.patrolZ, index * math.pi / 4)
		if math.abs(position.X) > 538 or math.abs(position.Z) > 538 then
			return false
		end
		for _, ground in fishGrounds do
			local localPosition = ground.CFrame:PointToObjectSpace(position)
			if
				math.abs(localPosition.X) < ground.Size.X / 2 + 8
				and math.abs(localPosition.Z) < ground.Size.Z / 2 + 8
			then
				return false
			end
		end
		for _, offset in
			{ Vector3.zero, Vector3.new(7, 0, 7), Vector3.new(-7, 0, 7), Vector3.new(7, 0, -7), Vector3.new(-7, 0, -7) }
		do
			if Workspace:Raycast(position + offset + RAY_HEIGHT, RAY_DOWN, land) then
				return false
			end
		end
		local hit = Workspace:Raycast(position + RAY_HEIGHT, RAY_DOWN, water)
		if not hit or hit.Material ~= Enum.Material.Water then
			return false
		end
	end
	return true
end

local function prepare(boat: Boat): boolean
	if boat.home then
		return true
	end
	local home = boat.model:GetAttribute("BoatHomeCFrame")
	if typeof(home) ~= "CFrame" or boat.model:GetAttribute("BoatVisual") ~= true or not boat.model.PrimaryPart then
		return false
	end
	boat.home = home
	local x, z = boat.model:GetAttribute("BoatPatrolX"), boat.model:GetAttribute("BoatPatrolZ")
	boat.patrolX = if typeof(x) == "number" and x == x then math.clamp(x, 0, 6) else 6
	boat.patrolZ = if typeof(z) == "number" and z == z then math.clamp(z, 0, 3) else 3
	boat.phase = math.abs(home.Position.X * 0.017 + home.Position.Z * 0.031) % (math.pi * 2)
	return true
end

local function selectNearby(now: number)
	local camera = Workspace.CurrentCamera
	local quality = player:GetAttribute("EffectsQuality")
	local budget = if quality == "low" then 2 elseif quality == "high" then 6 else 4
	local distance = if quality == "low" then 190 elseif quality == "high" then 370 else 280
	local previous: { [Model]: boolean } = {}
	for _, boat in selected do
		previous[boat.model] = true
	end
	table.clear(selected)
	if not camera then
		return
	end
	for _, boat in boats do
		if prepare(boat) and boat.home and (boat.home.Position - camera.CFrame.Position).Magnitude <= distance then
			table.insert(selected, boat)
		end
	end
	table.sort(selected, function(a: Boat, b: Boat): boolean
		return ((a.home :: CFrame).Position - camera.CFrame.Position).Magnitude
			< ((b.home :: CFrame).Position - camera.CFrame.Position).Magnitude
	end)
	while #selected > budget do
		table.remove(selected)
	end
	local checked = false
	for _, boat in selected do
		if not previous[boat.model] then
			boat.resumeAt = nil
		end
		previous[boat.model] = nil
		-- İlk doğrulamalar da zamana yayılır: bir seçim turunda en fazla bir rota.
		if not checked and now - boat.checkedAt >= 8 then
			local wasClear = boat.clear
			boat.clear = checkRoute(boat)
			if boat.clear ~= wasClear then
				boat.resumeAt = nil
			end
			boat.checkedAt = now
			checked = true
		end
	end
	for model in previous do
		local boat = boats[model]
		if boat then
			boat.resumeAt = nil
			hideWake(boat)
		end
	end
end

local foamWarned = false

local function wake(boat: Boat, pivot: CFrame)
	if player:GetAttribute("EffectsQuality") == "low" or not boat.clear then
		hideWake(boat)
		return
	end
	-- Köpük izi: client-assets/Sea/BoatFoam ("Foam" parçası; görünür saydamlığı modelden gelir)
	while #boat.wakes < 2 do
		local model = ClientModelAssets.clone("Sea", "BoatFoam")
		local part = if model then model:FindFirstChild("Foam") else nil
		if not (model and part and part:IsA("BasePart")) then
			if model then
				model:Destroy()
			end
			if not foamWarned then
				foamWarned = true
				warn("[BoatAnimator] client-assets/Sea/BoatFoam.rbxmx bulunamadı; köpük çizilmedi")
			end
			return
		end
		part:SetAttribute("ShownTransparency", part.Transparency)
		part.Parent = wakesFolder
		model:Destroy()
		table.insert(boat.wakes, part)
	end
	local forward = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
	for index, part in boat.wakes do
		local side = if index == 1 then -1 else 1
		local position = pivot:PointToWorldSpace(Vector3.new(side * 2.55, 0, 7.1))
		position = Vector3.new(position.X, 0.07, position.Z)
		part.CFrame = CFrame.lookAt(position, position + forward) * CFrame.Angles(0, side * 0.17, 0)
		part.Transparency = part:GetAttribute("ShownTransparency") :: number
	end
end

local added = Workspace.DescendantAdded:Connect(register)
local removed = Workspace.DescendantRemoving:Connect(remove)
local plots = Workspace:FindFirstChild("Plots")
if plots then
	for _, descendant in plots:GetDescendants() do
		register(descendant)
	end
end
local rendered = RunService.RenderStepped:Connect(function(dt: number)
	if not alive then
		return
	end
	local now = Workspace:GetServerTimeNow()
	selectionElapsed += dt
	if EffectSettings.reducedMotion() then
		for _, boat in boats do
			if
				prepare(boat)
				and not boat.atHome
				and boat.home
				and boat.model:GetAttribute("BuildPopActive") ~= true
			then
				boat.model:PivotTo(boat.home)
				boat.atHome = true
			end
			boat.resumeAt = nil
			hideWake(boat)
		end
		return
	end
	if selectionElapsed >= 0.5 then
		selectionElapsed = 0
		selectNearby(now)
	end
	for _, boat in selected do
		local model = boat.model
		local home = boat.home
		local createdAt = model:GetAttribute("VisualCreatedAt")
		if not boats[model] or not home or not model.PrimaryPart then
			continue
		end
		if model:GetAttribute("BuildPopActive") == true or (typeof(createdAt) == "number" and now - createdAt < 1) then
			boat.resumeAt = nil
			hideWake(boat)
			continue
		end
		if not boat.resumeAt then
			boat.resumeAt = now
			boat.from = model:GetPivot()
		end
		local phase = now * math.pi * 2 / PERIOD + boat.phase
		local position = if boat.clear then routePosition(home, boat.patrolX, boat.patrolZ, phase) else home.Position
		position += Vector3.new(0, math.sin(now * 1.2 + boat.phase) * 0.075, 0)
		local tangent = if boat.clear
			then home:VectorToWorldSpace(
				Vector3.new(math.cos(phase) * boat.patrolX, 0, -math.sin(phase) * boat.patrolZ)
			)
			else home.LookVector
		if tangent.Magnitude < 0.01 then
			tangent = home.LookVector
		end
		local target = CFrame.lookAt(position, position + tangent)
			* CFrame.Angles(math.sin(now * 1.05 + boat.phase) * 0.009, 0, math.sin(now * 0.83 + boat.phase) * 0.013)
		local blend = math.clamp((now - (boat.resumeAt :: number)) / 2, 0, 1)
		blend = blend * blend * (3 - 2 * blend)
		local pivot = if blend < 1 and boat.from then boat.from:Lerp(target, blend) else target
		model:PivotTo(pivot)
		boat.atHome = false
		wake(boat, pivot)
	end
end)
script.Destroying:Connect(function()
	alive = false
	added:Disconnect()
	removed:Disconnect()
	rendered:Disconnect()
	for model in boats do
		remove(model)
	end
	wakesFolder:Destroy()
end)
