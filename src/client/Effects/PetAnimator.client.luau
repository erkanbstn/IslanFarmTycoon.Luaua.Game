--!strict
-- Yardımcıların (pet) görünür çalışması. Her (tür, ada) yuvasının bir yardımcısı vardır; sunucu plot özniteliklerine yalnızca
-- iş durumunu yazar (PetService):
--   PetJob_<tür>_<ada>   : çalışan partinin tesis kimliği ("" = iş yok)
--   PetCycle_<tür>_<ada> : yardımcının teslim ettiği parti sayısı (her artışta teslim turu oynar)
-- Yürüyüş yalnızca görseldir; gerçek teslim sunucuda zamanında olur. İş zaten sürüyorsa yardımcı doğrudan tesisin başına gider.
-- Teslim turu: hayvanı ağıla geri bırak → tesise dön → ürünü al → ahır sandığına (para: toplama platformuna) götür →
-- iş sürüyorsa (otomatik tekrar) yeni hayvanı ağıldan alıp tesise getir. Rotalar taş yolları izler (Shared/MapPaths).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MapPaths = require(Shared:WaitForChild("MapPaths"))
local PetMotion = require(Shared:WaitForChild("Modules"):WaitForChild("PetMotion"))
local EffectSettings = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("EffectSettings"))

local TAG = "PetFigure"
local SPEED = 15
local FAR_TELEPORT_SECONDS = 0.25 -- çok uzaktaki (PetMotion.SKIP_DISTANCE) yardımcı yürütülmez: ışınlanır, durak başına bekler
local IDLE_SLEEP_DISTANCE = 120 -- bu uzaklıktan ötede (ya da düşük kalitede) bekleme sallanması çalışmaz
local IDLE_SLEEP_SECONDS = 0.5
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

local function cameraDistance(actor: Actor): number?
	local camera = Workspace.CurrentCamera
	return if camera then (camera.CFrame.Position - actor.cf.Position).Magnitude else nil
end

-- Çarpışma: yardımcı katı nesnelerin (çit, kütük, bina, ağaç) içinden geçmez. Her adımda yürüyüş yönüne kısa yatay ışın atılır;
-- engel varsa 45/90/135 derece yan yönler denenir. Hiçbiri açık değilse yardımcı bekler; uzun süre ilerleyemezse (takılma)
-- hedefe doğru yürümeye zorlanır, böylece teslim turu asla donmaz.
local PET_RADIUS = 1.2
local PROBE_HEIGHT = 1.4
local STUCK_SECONDS = 2
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true
local SIDE_ANGLES = { 0, 45, -45, 90, -90, 135, -135 }

local function blockedAhead(actor: Actor, position: Vector3, direction: Vector3, distance: number): boolean
	rayParams.FilterDescendantsInstances = { actor.model }
	local origin = Vector3.new(position.X, actor.y + PROBE_HEIGHT, position.Z)
	local hit = Workspace:Raycast(origin, direction * (distance + PET_RADIUS), rayParams)
	if not hit then
		return false
	end
	local instance = hit.Instance
	-- Oyuncular ve yardımcılar engel sayılmaz; yalnızca sabit (Anchored) dünya parçaları
	if instance.Parent and instance.Parent:FindFirstChildOfClass("Humanoid") then
		return false
	end
	return instance.Anchored and instance.CanCollide
end

-- Hedefe yürür. Kalite yalnızca zıplamayı keser; konum her kalitede akıcı ilerler (PetMotion.walkInterval aralığıyla).
-- Yalnızca çok uzaktaki yardımcı ışınlanır.
local function walk(actor: Actor, target: Vector3): boolean
	target = Vector3.new(target.X, actor.y, target.Z)
	if PetMotion.teleports(cameraDistance(actor)) then
		place(actor, CFrame.lookAt(target, target + actor.cf.LookVector))
		task.wait(FAR_TELEPORT_SECONDS)
		return alive(actor)
	end
	local pending = 0
	local stuck = 0
	while true do
		if not alive(actor) then
			return false
		end
		pending += RunService.Heartbeat:Wait()
		if pending < PetMotion.walkInterval(EffectSettings.quality(), cameraDistance(actor)) then
			continue
		end
		local dt = pending
		pending = 0
		local position = actor.cf.Position
		local nextX, nextZ, arrived = PetMotion.advance(position.X, position.Z, target.X, target.Z, SPEED, dt)
		if arrived then
			return true
		end
		if stuck < STUCK_SECONDS then
			local want = Vector3.new(nextX - position.X, 0, nextZ - position.Z)
			local stepLength = want.Magnitude
			if stepLength > 1e-4 then
				local unit = want / stepLength
				local chosen: Vector3? = nil
				for _, degrees in SIDE_ANGLES do
					local candidate = (CFrame.Angles(0, math.rad(degrees), 0) * unit)
					if not blockedAhead(actor, position, candidate, stepLength) then
						chosen = candidate
						break
					end
				end
				if chosen then
					nextX, nextZ = position.X + chosen.X * stepLength, position.Z + chosen.Z * stepLength
					stuck = 0
				else
					stuck += dt
					continue
				end
			end
		end
		actor.t += dt
		local bob = if PetMotion.animates(EffectSettings.quality(), EffectSettings.reducedMotion())
			then math.abs(math.sin(actor.t * 9)) * 0.35
			else 0
		local flat = Vector3.new(nextX, actor.y, nextZ)
		local direction = Vector3.new(nextX - position.X, 0, nextZ - position.Z)
		if direction.Magnitude < 1e-4 then
			direction = actor.cf.LookVector
		end
		place(actor, CFrame.lookAt(flat + Vector3.new(0, bob, 0), flat + Vector3.new(0, bob, 0) + direction))
	end
end

-- Bekleme: olduğu yerde hafifçe sallanır
local function idleStep(actor: Actor, facing: Vector3?)
	-- Kameradan uzaktaki ya da düşük kalitedeki yardımcının sallanması gereksiz: kare başı yerine yarım saniyede bir uyanır
	local distance = cameraDistance(actor)
	local quality = EffectSettings.quality()
	if quality == "low" or (distance ~= nil and distance > IDLE_SLEEP_DISTANCE) then
		task.wait(IDLE_SLEEP_SECONDS)
		return
	end
	local dt = RunService.Heartbeat:Wait()
	actor.t += dt
	local position = Vector3.new(actor.cf.Position.X, actor.y, actor.cf.Position.Z)
	local sway = if PetMotion.animates(quality, EffectSettings.reducedMotion()) then math.sin(actor.t * 3) * 0.12 else 0
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

-- Plotun taş yol ağı (dünya XZ): ana ada yolları + köprüler + uzman ada yolları. Ada içeriği yeniden kurulabildiğinden
-- ve streaming köprüyü geç getirebildiğinden girdilerin imzası her yürüyüşte karşılaştırılır; ağ yalnızca imza değişince
-- yeniden kurulur (aynı plotun tüm yardımcıları aynı ağı paylaşır).
local function graphSignature(plot: Model): string
	local parts = { tostring(plot:GetAttribute("HomeFrame")), tostring(plot:GetAttribute("HomeRadius")) }
	local islands = plot:FindFirstChild("Islands")
	if islands then
		for _, island in islands:GetChildren() do
			local bridge = island:FindFirstChild("Bridge")
			table.insert(
				parts,
				`{island.Name}:{if bridge and bridge:IsA("BasePart")
					then tostring(bridge.CFrame) .. tostring(bridge.Size)
					else "-"}:{island:GetAttribute("PathStart")}:{island:GetAttribute("PathEnd")}`
			)
		end
	end
	return table.concat(parts, "|")
end

local function buildGraph(plot: Model): MapPaths.Graph?
	local frame = plot:GetAttribute("HomeFrame")
	local radius = plot:GetAttribute("HomeRadius")
	if typeof(frame) ~= "CFrame" or typeof(radius) ~= "number" then
		return nil
	end
	local graph = MapPaths.newGraph()
	MapPaths.addSegments(graph, MapPaths.homeSegments(radius), function(x: number, z: number): (number, number)
		local world = frame * Vector3.new(x, 0, z)
		return world.X, world.Z
	end)
	local homeCount = #graph.x
	local islands = plot:FindFirstChild("Islands")
	if not islands then
		return graph
	end
	for _, island in islands:GetChildren() do
		local startPoint, endPoint = island:GetAttribute("PathStart"), island:GetAttribute("PathEnd")
		local bridge = island:FindFirstChild("Bridge")
		if typeof(startPoint) == "Vector3" and typeof(endPoint) == "Vector3" and bridge and bridge:IsA("BasePart") then
			local half = bridge.Size.Z / 2
			local homeEnd = bridge.CFrame * Vector3.new(0, 0, half)
			local islandEnd = bridge.CFrame * Vector3.new(0, 0, -half)
			local a = MapPaths.addNode(graph, homeEnd.X, homeEnd.Z)
			local b = MapPaths.addNode(graph, islandEnd.X, islandEnd.Z)
			local c = MapPaths.addNode(graph, startPoint.X, startPoint.Z)
			local d = MapPaths.addNode(graph, endPoint.X, endPoint.Z)
			MapPaths.connect(graph, a, b)
			MapPaths.connect(graph, b, c)
			MapPaths.connect(graph, c, d)
			-- Köprünün ana ada ucu, en yakın ana ada yoluna bağlanır
			local best: number? = nil
			local bestDistance = math.huge
			for index = 1, homeCount do
				local dx, dz = graph.x[index] - homeEnd.X, graph.z[index] - homeEnd.Z
				local distance = dx * dx + dz * dz
				if distance < bestDistance then
					best, bestDistance = index, distance
				end
			end
			if best then
				MapPaths.connect(graph, a, best)
			end
		end
	end
	return graph
end

local graphCache: { [Model]: { signature: string, graph: MapPaths.Graph? } } = setmetatable({}, { __mode = "k" }) :: any

local function graphOf(plot: Model): MapPaths.Graph?
	local signature = graphSignature(plot)
	local cached = graphCache[plot]
	if cached and cached.signature == signature then
		return cached.graph
	end
	local graph = buildGraph(plot)
	graphCache[plot] = { signature = signature, graph = graph }
	return graph
end

-- Hedefe taş yollar üzerinden yürür.
local function goTo(actor: Actor, target: Vector3): boolean
	local graph = graphOf(actor.plot)
	local position = actor.cf.Position
	local points: { MapPaths.Point } = if graph
		then MapPaths.route(graph, position.X, position.Z, target.X, target.Z)
		else { { x = target.X, z = target.Z } }
	for _, point in points do
		if not walk(actor, Vector3.new(point.x, actor.y, point.z)) then
			return false
		end
	end
	return true
end

-- Hayvanın ağılı: yardımcının adasındaki ilk bölge (ana adada "starter")
local function penPoint(plot: Model, island: string): Vector3?
	local zones = plot:FindFirstChild("Zones")
	if not zones then
		return nil
	end
	local fallback: Vector3? = nil
	for _, zone in zones:GetChildren() do
		local zoneId = zone:GetAttribute("ZoneId")
		local zoneConfig = if typeof(zoneId) == "string" then Config.ZONES[zoneId] else nil
		local ground = zone:FindFirstChild("Ground")
		-- "sea": ana adadaki balık kafesinin yardımcısı; ağılı balık kafesidir
		local sameIsland = if island == "sea"
			then zoneId == "fishpen"
			else zoneConfig ~= nil and zoneConfig.island == island
		if sameIsland and ground and ground:IsA("BasePart") then
			if zoneId == "starter" then
				return ground.Position
			end
			fallback = fallback or ground.Position
		end
	end
	return fallback
end

local function chestPoint(plot: Model): Vector3?
	local prompt = plot:FindFirstChild("BarnChestPrompt", true)
	local anchor = prompt and prompt.Parent
	return if anchor and anchor:IsA("BasePart") then anchor.Position else nil
end

local function run(actor: Actor)
	local plot = actor.plot
	local suffix = `{actor.kind}_{actor.island}`
	local jobAttribute, cycleAttribute = `PetJob_{suffix}`, `PetCycle_{suffix}`
	local function cycle(): number
		local value = plot:GetAttribute(cycleAttribute)
		return if typeof(value) == "number" then value else 0
	end
	local function job(): string
		local value = plot:GetAttribute(jobAttribute)
		return if typeof(value) == "string" then value else ""
	end
	local cycleSeen = cycle()
	local atFacility = false

	while alive(actor) do
		local current = job()
		local spot = if current ~= "" then spotOf(plot, current) else nil
		if not spot then
			cycleSeen = cycle()
			atFacility = false
			clearProps(actor)
			if not goTo(actor, actor.home.Position) then
				return
			end
			idleFor(actor, 0.5)
			continue
		end

		local facilityPoint = (spot.CFrame * FACILITY_OFFSET).Position
		local pen = penPoint(plot, actor.island) or actor.home.Position
		if not atFacility then
			-- İş zaten sürüyor (elle ya da önceki turdan): doğrudan tesisin başına git
			if not goTo(actor, facilityPoint) then
				return
			end
			atFacility = true
		end

		while alive(actor) and job() == current and cycle() == cycleSeen do
			idleStep(actor, spot.Position)
		end
		if not alive(actor) then
			return
		end
		if cycle() == cycleSeen then
			atFacility = false
			continue
		end
		cycleSeen = cycle()

		-- Teslim turu: hayvanı ağıla bırak, ürünü al, sandığa/platforma götür
		carry(actor, "animal")
		if not goTo(actor, pen) then
			return
		end
		clearProps(actor)
		idleFor(actor, 0.3)
		if not goTo(actor, facilityPoint) then
			return
		end
		idleFor(actor, 0.3)
		local destination: Vector3
		if actor.kind == "goods" then
			carry(actor, "crate")
			destination = chestPoint(plot) or actor.home.Position
		else
			carry(actor, "coins")
			local collector = plot:FindFirstChild("Collector")
			destination = if collector and collector:IsA("BasePart") then collector.Position else actor.home.Position
		end
		if not goTo(actor, destination) then
			return
		end
		clearProps(actor)
		idleFor(actor, 0.4)

		-- Otomatik tekrar: yeni parti sürüyorsa hayvanı ağıldan alıp tesise getir
		if job() ~= "" then
			if not goTo(actor, pen) then
				return
			end
			idleFor(actor, 0.3)
			carry(actor, "animal")
			if not goTo(actor, facilityPoint) then
				return
			end
			clearProps(actor)
			atFacility = true
		else
			atFacility = false
		end
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
		local island = model:GetAttribute("PetIsland")
		local home = model:GetAttribute("PetHome")
		local plot = plotOf(model)
		if
			not root
			or typeof(kind) ~= "string"
			or typeof(island) ~= "string"
			or typeof(home) ~= "CFrame"
			or not plot
		then
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
			island = island,
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
