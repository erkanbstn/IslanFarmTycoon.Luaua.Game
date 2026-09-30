--!strict
-- Yardımcıların (pet) görünür çalışması. Sunucu plot özniteliklerine yalnızca iş durumunu yazar (PetService):
--   PetCashJob / PetGoodsJob : çalışan partinin tesis kimliği ("" = iş yok)
--   PetCashCycle / PetGoodsCycle : yardımcının teslim ettiği parti sayısı (her artışta teslim turu oynar)
-- Hayvan alma/bırakma ve teslim yürüyüşü yalnızca görseldir; gerçek teslim sunucuda zamanında olur.
-- Tur: hayvanı ağıldan al → tesise götür → başında bekle → hayvanı ağıla geri bırak → ürünü al → ahıra (para: toplama
-- platformuna) götür → tekrar. Uzak adalardaki tesislere köprüden geçilir.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local TAG = "PetFigure"
local SPEED = 15
local SKIP_DISTANCE = 350 -- çok uzaktaki yardımcı yürütülmez, ışınlanır
local FACILITY_OFFSET = CFrame.new(0, 0, -8)

type Prop = { part: Part, offset: CFrame }
type Actor = {
	model: Model,
	plot: Model,
	kind: string,
	home: CFrame,
	cf: CFrame,
	y: number,
	t: number,
	island: string,
	props: { Prop },
}

local function alive(actor: Actor): boolean
	return actor.model.Parent ~= nil and actor.model:IsDescendantOf(Workspace)
end

local function place(actor: Actor, cf: CFrame)
	actor.cf = cf
	actor.model:PivotTo(cf)
	for _, prop in actor.props do
		prop.part.CFrame = cf * prop.offset
	end
end

local function clearProps(actor: Actor)
	for _, prop in actor.props do
		prop.part:Destroy()
	end
	table.clear(actor.props)
end

local function addProp(
	actor: Actor,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = false
	if shape then
		part.Shape = shape
	end
	part.CFrame = actor.cf * offset
	part.Parent = actor.model
	table.insert(actor.props, { part = part, offset = offset })
end

local function carry(actor: Actor, what: string)
	clearProps(actor)
	if what == "animal" then
		addProp(
			actor,
			"CarriedBody",
			Vector3.new(1.6, 1.1, 2.2),
			CFrame.new(0, 3.7, 0.2),
			Color3.fromRGB(240, 240, 235),
			Enum.Material.Fabric
		)
		addProp(
			actor,
			"CarriedPatch",
			Vector3.new(1.7, 0.6, 0.9),
			CFrame.new(0, 3.9, 0.6),
			Color3.fromRGB(60, 50, 45),
			Enum.Material.Fabric
		)
		addProp(
			actor,
			"CarriedHead",
			Vector3.new(1, 1, 1),
			CFrame.new(0, 4.1, -1.3),
			Color3.fromRGB(235, 225, 215),
			Enum.Material.Fabric
		)
	elseif what == "crate" then
		addProp(
			actor,
			"CarriedCrate",
			Vector3.new(1.8, 1.5, 1.8),
			CFrame.new(0, 3.5, 0),
			Color3.fromRGB(170, 125, 75),
			Enum.Material.WoodPlanks
		)
	elseif what == "coins" then
		addProp(
			actor,
			"CarriedCoins",
			Vector3.new(1.6, 1.6, 1.6),
			CFrame.new(0, 3.5, 0),
			Color3.fromRGB(255, 200, 60),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
	end
end

local function farAway(actor: Actor): boolean
	local camera = Workspace.CurrentCamera
	local low = player:GetAttribute("EffectsQuality") == "low"
	return low or (camera ~= nil and (camera.CFrame.Position - actor.cf.Position).Magnitude > SKIP_DISTANCE)
end

local function walk(actor: Actor, target: Vector3): boolean
	target = Vector3.new(target.X, actor.y, target.Z)
	if farAway(actor) then
		place(actor, CFrame.lookAt(target, target + actor.cf.LookVector))
		task.wait(0.25)
		return alive(actor)
	end
	local reduced = player:GetAttribute("ReducedMotion") == true
	while true do
		if not alive(actor) then
			return false
		end
		local dt = RunService.Heartbeat:Wait()
		local position = actor.cf.Position
		local delta = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
		local distance = delta.Magnitude
		if distance < 0.4 then
			return true
		end
		local direction = delta.Unit
		local nextPosition = Vector3.new(position.X, actor.y, position.Z) + direction * math.min(distance, SPEED * dt)
		actor.t += dt
		local bob = if reduced then 0 else math.abs(math.sin(actor.t * 9)) * 0.35
		place(
			actor,
			CFrame.lookAt(nextPosition + Vector3.new(0, bob, 0), nextPosition + Vector3.new(0, bob, 0) + direction)
		)
	end
end

-- Bekleme: olduğu yerde hafifçe sallanır
local function idleStep(actor: Actor, facing: Vector3?)
	local dt = RunService.Heartbeat:Wait()
	actor.t += dt
	local position = Vector3.new(actor.cf.Position.X, actor.y, actor.cf.Position.Z)
	local sway = if player:GetAttribute("ReducedMotion") == true then 0 else math.sin(actor.t * 3) * 0.12
	local lookAt = if facing then Vector3.new(facing.X, actor.y, facing.Z) else position + actor.cf.LookVector
	if (lookAt - position).Magnitude < 0.1 then
		lookAt = position + actor.cf.LookVector
	end
	place(actor, CFrame.lookAt(position + Vector3.new(0, sway, 0), lookAt + Vector3.new(0, sway, 0)))
end

local function idleFor(actor: Actor, seconds: number)
	local untilTime = os.clock() + seconds
	while alive(actor) and os.clock() < untilTime do
		idleStep(actor)
	end
end

local function spotOf(plot: Model, upgradeId: string): BasePart?
	local spots = plot:FindFirstChild("BuildSpots")
	local spot = spots and spots:FindFirstChild(upgradeId)
	return if spot and spot:IsA("BasePart") then spot else nil
end

local function islandOfSpot(spot: BasePart): string
	local id = spot:GetAttribute("FarmIslandId")
	return if typeof(id) == "string" then id else "home"
end

-- Ana adadan uzman adaya giden köprünün iki ucu (ana ada ucu, uzman ada ucu)
local function bridgeEnds(plot: Model, islandId: string, y: number): (Vector3?, Vector3?)
	local islands = plot:FindFirstChild("Islands")
	if not islands then
		return nil, nil
	end
	for _, island in islands:GetChildren() do
		if island:GetAttribute("FarmIslandId") == islandId then
			local bridge = island:FindFirstChild("Bridge")
			if bridge and bridge:IsA("BasePart") then
				local half = bridge.Size.Z / 2
				local homeEnd = bridge.CFrame * Vector3.new(0, 0, half)
				local islandEnd = bridge.CFrame * Vector3.new(0, 0, -half)
				return Vector3.new(homeEnd.X, y, homeEnd.Z), Vector3.new(islandEnd.X, y, islandEnd.Z)
			end
		end
	end
	return nil, nil
end

-- Bulunduğu adadan hedef adaya: aynı adada doğrudan, değilse köprü uçları üzerinden (uzman adalar arası ana adadan)
local function goTo(actor: Actor, target: Vector3, targetIsland: string): boolean
	local from = actor.island
	if from ~= targetIsland then
		if from ~= "home" then
			local homeEnd, islandEnd = bridgeEnds(actor.plot, from, actor.y)
			if islandEnd and homeEnd then
				if not walk(actor, islandEnd) or not walk(actor, homeEnd) then
					return false
				end
			end
			actor.island = "home"
		end
		if targetIsland ~= "home" then
			local homeEnd, islandEnd = bridgeEnds(actor.plot, targetIsland, actor.y)
			if homeEnd and islandEnd then
				if not walk(actor, homeEnd) or not walk(actor, islandEnd) then
					return false
				end
			end
		end
		actor.island = targetIsland
	end
	return walk(actor, target)
end

local function penPoint(plot: Model): Vector3?
	local zones = plot:FindFirstChild("Zones")
	if not zones then
		return nil
	end
	for _, zone in zones:GetChildren() do
		if zone:GetAttribute("ZoneId") == "starter" then
			local ground = zone:FindFirstChild("Ground")
			if ground and ground:IsA("BasePart") then
				return ground.Position
			end
		end
	end
	return nil
end

local function run(actor: Actor)
	local plot = actor.plot
	local jobAttribute = if actor.kind == "cash" then "PetCashJob" else "PetGoodsJob"
	local cycleAttribute = if actor.kind == "cash" then "PetCashCycle" else "PetGoodsCycle"
	local function cycle(): number
		local value = plot:GetAttribute(cycleAttribute)
		return if typeof(value) == "number" then value else 0
	end
	local function job(): string
		local value = plot:GetAttribute(jobAttribute)
		return if typeof(value) == "string" then value else ""
	end
	local cycleSeen = cycle()
	local animalThere = false

	while alive(actor) do
		local current = job()
		local spot = if current ~= "" then spotOf(plot, current) else nil
		if not spot then
			cycleSeen = cycle()
			animalThere = false
			clearProps(actor)
			if not goTo(actor, actor.home.Position, "home") then
				return
			end
			idleFor(actor, 0.5)
			continue
		end

		local facilityPoint = (spot.CFrame * FACILITY_OFFSET).Position
		local facilityIsland = islandOfSpot(spot)
		local pen = penPoint(plot) or actor.home.Position

		if not animalThere then
			if not goTo(actor, pen, "home") then
				return
			end
			idleFor(actor, 0.3)
			carry(actor, "animal")
			if not goTo(actor, facilityPoint, facilityIsland) then
				return
			end
			clearProps(actor)
			animalThere = true
		else
			if not goTo(actor, facilityPoint, facilityIsland) then
				return
			end
		end

		while alive(actor) and job() == current and cycle() == cycleSeen do
			idleStep(actor, spot.Position)
		end
		if not alive(actor) then
			return
		end
		animalThere = false
		if cycle() == cycleSeen then
			continue
		end
		cycleSeen = cycle()

		carry(actor, "animal")
		if not goTo(actor, pen, "home") then
			return
		end
		clearProps(actor)
		idleFor(actor, 0.3)
		if not goTo(actor, facilityPoint, facilityIsland) then
			return
		end
		idleFor(actor, 0.3)
		local destination: Vector3
		if actor.kind == "goods" then
			carry(actor, "crate")
			local barn = plot:FindFirstChild("BarnSpot")
			destination = if barn and barn:IsA("BasePart")
				then barn.Position + barn.CFrame.LookVector * 8
				else actor.home.Position
		else
			carry(actor, "coins")
			local collector = plot:FindFirstChild("Collector")
			destination = if collector and collector:IsA("BasePart") then collector.Position else actor.home.Position
		end
		if not goTo(actor, destination, "home") then
			return
		end
		clearProps(actor)
		idleFor(actor, 0.4)
	end
end

local function plotOf(instance: Instance): Model?
	local current: Instance? = instance
	while current and not (current.Parent and current.Parent.Name == "Plots") do
		current = current.Parent
	end
	return if current and current:IsA("Model") then current else nil
end

local function track(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance
	task.spawn(function()
		local root = model:WaitForChild("Root", 10)
		local kind = model:GetAttribute("PetKind")
		local home = model:GetAttribute("PetHome")
		local plot = plotOf(model)
		if not root or typeof(kind) ~= "string" or typeof(home) ~= "CFrame" or not plot then
			return
		end
		local actor: Actor = {
			model = model,
			plot = plot,
			kind = kind,
			home = home,
			cf = home,
			y = home.Position.Y,
			t = 0,
			island = "home",
			props = {},
		}
		local ok, err = pcall(function()
			run(actor)
		end)
		if not ok then
			warn(`[PetAnimator] {err}`)
		end
	end)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
for _, instance in CollectionService:GetTagged(TAG) do
	track(instance)
end
