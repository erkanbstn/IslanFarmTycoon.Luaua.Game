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
local ClientModelAssets = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientModelAssets"))

local TAG = "PetFigure"
local SPEED = 15
local FAR_TELEPORT_SECONDS = 0.25 -- çok uzaktaki (PetMotion.SKIP_DISTANCE) yardımcı yürütülmez: ışınlanır, durak başına bekler
local IDLE_SLEEP_DISTANCE = 120 -- bu uzaklıktan ötede (ya da düşük kalitede) bekleme sallanması çalışmaz
local IDLE_SLEEP_SECONDS = 0.5
local FACILITY_OFFSET = CFrame.new(0, 0, -8)

type Prop = { part: BasePart, offset: CFrame }
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
	propModel: Model?, -- taşınan nesnenin (client-assets/PetProps) sarmalayıcısı
	radius: number,
	height: number,
	width: number,
	length: number,
	center: Vector3,
	carryHeight: number,
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
	if actor.propModel then
		actor.propModel:Destroy()
		actor.propModel = nil
	end
	table.clear(actor.props)
end

local missingWarned: { [string]: boolean } = {}

-- Hayvan gerçek şablondan, ürün/para PetProps modelinden gelir; hepsi yardımcının gövdesinin üstüne oturur.
-- Her parçanın ofseti yardımcının CFrame'inden bir kez yakalanır ve her adımda `actor.cf * ofset` uygulanır.
local function addProp(actor: Actor, modelName: string, isAnimal: boolean?)
	local folder = if isAnimal then "Animals" else "PetProps"
	local model = ClientModelAssets.clone(folder, modelName)
	if not model then
		if not missingWarned[modelName] then
			missingWarned[modelName] = true
			warn(`[PetAnimator] ClientAssets/{folder}/{modelName} bulunamadı; taşınan nesne çizilmedi`)
		end
		return
	end
	local _, size = model:GetBoundingBox()
	local scale = math.min(if isAnimal then 0.5 else 1, 1.8 / math.max(size.X, size.Y, size.Z))
	model:ScaleTo(model:GetScale() * scale)
	model:PivotTo(CFrame.identity)
	local bounds, scaledSize = model:GetBoundingBox()
	local lift = actor.carryHeight + scaledSize.Y / 2 + 0.12
	model:PivotTo(CFrame.new(-bounds.Position.X, lift - bounds.Position.Y, -bounds.Position.Z))
	local pivot = CFrame.identity
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(actor.props, { part = descendant, offset = pivot:ToObjectSpace(descendant.CFrame) })
		end
	end
	model:PivotTo(actor.cf * pivot:ToObjectSpace(model:GetPivot()))
	model.Parent = actor.model
	actor.propModel = model
end

local function carry(actor: Actor, what: string, animalModel: string?)
	clearProps(actor)
	if what == "animal" then
		if animalModel and animalModel ~= "" then
			addProp(actor, animalModel, true)
		end
	elseif what == "crate" then
		addProp(actor, "CarryCrate")
	elseif what == "coins" then
		addProp(actor, "CarryCoins")
	end
end

local function cameraDistance(actor: Actor): number?
	local camera = Workspace.CurrentCamera
	return if camera then (camera.CFrame.Position - actor.cf.Position).Magnitude else nil
end

-- Her türün gerçek gövde hacmi korunur; bekleme süresi engelleri hiçbir zaman kapatmaz.
local MAX_STEP = 0.8
local MIN_NORMAL = 0.7
local RETRY_SECONDS = 1
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.RespectCanCollide = true
rayParams.IgnoreWater = true
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include
overlapParams.RespectCanCollide = true

local function queryWorld(actor: Actor)
	local include: { Instance } = { actor.plot, Workspace.Terrain }
	local world = Workspace:FindFirstChild("World")
	if world then
		table.insert(include, world)
	end
	rayParams.FilterDescendantsInstances = include
	overlapParams.FilterDescendantsInstances = include
end

local function updateBodySize(actor: Actor)
	local cf, size = actor.model:GetBoundingBox()
	local center = actor.cf:PointToObjectSpace(cf.Position)
	actor.center = Vector3.new(center.X, 0, center.Z)
	actor.width = size.X + 0.24
	actor.length = size.Z + 0.24
	actor.radius = math.abs(center.X) + actor.width / 2
	actor.height = math.max(1, center.Y + size.Y / 2 + 0.12)
end

local function heading(actor: Actor, direction: Vector3?): CFrame
	if direction and direction.Magnitude > 1e-4 then
		return CFrame.lookAt(Vector3.zero, direction)
	end
	return actor.cf.Rotation
end

local function bodyBox(actor: Actor, x: number, y: number, z: number, direction: Vector3?): (CFrame, Vector3)
	-- Çıkılabilir basamakları gövde engeli sayma; ayak ışınları bunların yüksekliğini izler.
	-- Uzun kuyruğun arkasındaki alçak platform, bütün peti platform kenarında kilitlememeli.
	local bottom = MAX_STEP + 0.1
	local height = math.max(0.5, actor.height + 0.35 - bottom)
	local center = Vector3.new(actor.center.X, bottom + height / 2, actor.center.Z)
	return CFrame.new(x, y, z) * heading(actor, direction) * CFrame.new(center),
		Vector3.new(actor.width, height, actor.length)
end

local function supportAt(actor: Actor, x: number, z: number, direction: Vector3?): number?
	queryWorld(actor)
	local level: number? = nil
	-- Tek merkez rayı bir ayağı kıyıdan veya köprüden düşürmesin.
	local side, front = actor.width * 0.35, actor.length * 0.3
	local rotation = heading(actor, direction)
	for _, offset in
		{
			Vector2.zero,
			Vector2.new(side, 0),
			Vector2.new(-side, 0),
			Vector2.new(0, front),
			Vector2.new(0, -front),
		}
	do
		local worldOffset = rotation * Vector3.new(offset.X, 0, offset.Y)
		local origin = Vector3.new(x + worldOffset.X, actor.y + MAX_STEP + 0.1, z + worldOffset.Z)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -MAX_STEP * 2 - 0.4, 0), rayParams)
		if not hit or hit.Normal.Y < MIN_NORMAL or math.abs(hit.Position.Y - actor.y) > MAX_STEP then
			return nil
		end
		level = math.max(level or hit.Position.Y, hit.Position.Y)
	end
	return level
end

local function canStand(
	actor: Actor,
	x: number,
	z: number,
	cache: { [string]: number | boolean }?,
	direction: Vector3?
): number?
	local key = `{x}:{z}:{if direction then direction.Unit else actor.cf.LookVector}`
	local cached = if cache then cache[key] else nil
	if cached ~= nil then
		return if typeof(cached) == "number" then cached else nil
	end
	local y = supportAt(actor, x, z, direction)
	if not y then
		if cache then
			cache[key] = false
		end
		return nil
	end
	local cf, size = bodyBox(actor, x, y, z, direction)
	for _, part in Workspace:GetPartBoundsInBox(cf, size, overlapParams) do
		if part.Anchored and part.CanCollide then
			if cache then
				cache[key] = false
			end
			return nil
		end
	end
	if cache then
		cache[key] = y
	end
	return y
end

local function canTravel(
	actor: Actor,
	x: number,
	z: number,
	nx: number,
	nz: number,
	cache: { [string]: number | boolean }?
): boolean
	local direction = Vector3.new(nx - x, 0, nz - z)
	local length = direction.Magnitude
	if length < 1e-4 then
		return canStand(actor, nx, nz, cache) ~= nil
	end
	if not canStand(actor, nx, nz, cache, direction) or not canStand(actor, x, z, cache, direction) then
		return false
	end
	queryWorld(actor)
	local cf, size = bodyBox(actor, x, actor.y, z, direction)
	local hit = Workspace:Blockcast(cf, size, direction, rayParams)
	if hit and hit.Instance.Anchored and hit.Instance.CanCollide then
		return false
	end
	-- Uzun bağlantı kıyı/köprü boşluklarından kestirme yapamaz.
	local samples = math.ceil(length / math.max(1, actor.radius))
	for index = 1, samples - 1 do
		local alpha = index / samples
		if not canStand(actor, x + direction.X * alpha, z + direction.Z * alpha, cache, direction) then
			return false
		end
	end
	return true
end

local function safeDestination(actor: Actor, target: Vector3): Vector3?
	local y = canStand(actor, target.X, target.Z)
	if y then
		return Vector3.new(target.X, y, target.Z)
	end
	-- Sandık/tesis çapasının içinde durmak yerine en yakın boş teslim noktasına yaklaşır.
	local toward = actor.cf.Position - target
	local startAngle = math.atan2(toward.X, toward.Z)
	for ring = 1, 4 do
		local radius = ring * math.max(1.5, actor.radius)
		for index = 0, 11 do
			local angle = startAngle + index * math.pi / 6
			local x, z = target.X + math.sin(angle) * radius, target.Z + math.cos(angle) * radius
			local level = canStand(actor, x, z)
			if level then
				return Vector3.new(x, level, z)
			end
		end
	end
	return nil
end

-- Yalnızca görünmeyen uzak yardımcı, kontrol edilmiş boş ve destekli hedefe ışınlanabilir.
local function walk(actor: Actor, requested: Vector3): boolean
	local target = safeDestination(actor, requested)
	if not target then
		task.wait(RETRY_SECONDS)
		return false
	end
	if PetMotion.teleports(cameraDistance(actor)) then
		actor.y = target.Y
		place(actor, CFrame.lookAt(target, target + actor.cf.LookVector))
		task.wait(FAR_TELEPORT_SECONDS)
		return alive(actor)
	end
	local function plan(): { PetMotion.Point }?
		local position = actor.cf.Position
		local cache: { [string]: number | boolean } = {}
		local checks = 0
		return PetMotion.detour(
			position.X,
			position.Z,
			target.X,
			target.Z,
			function(x: number, z: number, nx: number, nz: number): boolean
				checks += 1
				-- Yol araması kare başına yığılmaz; önbellek aynı zemin hücresini tekrar taramaz.
				if checks % 16 == 0 then
					RunService.Heartbeat:Wait()
				end
				return alive(actor) and canTravel(actor, x, z, nx, nz, cache)
			end,
			math.max(2.5, actor.radius * 1.5),
			256
		)
	end
	local route = plan()
	if not route then
		task.wait(RETRY_SECONDS)
		return false
	end
	local pending = 0
	local index = 1
	while index <= #route do
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
		local point = route[index]
		local nextX, nextZ, arrived = PetMotion.advance(position.X, position.Z, point.x, point.z, SPEED, dt)
		if arrived then
			index += 1
			continue
		end
		-- Streaming veya yeni bina rotayı kapatırsa son güvenli konumda durup yeniden arar.
		if not canTravel(actor, position.X, position.Z, nextX, nextZ) then
			task.wait(RETRY_SECONDS)
			route = plan()
			if not route then
				return false
			end
			index = 1
			continue
		end
		local support = supportAt(actor, nextX, nextZ, Vector3.new(nextX - position.X, 0, nextZ - position.Z))
		if not support then
			return false
		end
		actor.y = support
		actor.t += dt
		local bob = if PetMotion.animates(EffectSettings.quality(), EffectSettings.reducedMotion())
			then math.abs(math.sin(actor.t * 9)) * 0.25
			else 0
		local flat = Vector3.new(nextX, actor.y + bob, nextZ)
		place(actor, CFrame.lookAt(flat, flat + Vector3.new(nextX - position.X, 0, nextZ - position.Z)))
	end
	return true
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
local function bridgeEnds(island: Instance, home: Vector3): (Vector3?, Vector3?, number)
	local decks: { BasePart } = {}
	local legacy = island:FindFirstChild("Bridge")
	if legacy and legacy:IsA("BasePart") then
		table.insert(decks, legacy)
	end
	for _, child in island:GetChildren() do
		if child.Name == "BridgeModule_8" or child.Name == "BridgeModule_2" then
			local deck = child:FindFirstChild("Deck")
			if deck and deck:IsA("BasePart") then
				table.insert(decks, deck)
			end
		end
	end
	if #decks == 0 then
		return nil, nil, 0
	end
	table.sort(decks, function(a: BasePart, b: BasePart): boolean
		return (a.Position - home).Magnitude < (b.Position - home).Magnitude
	end)
	local first, last = decks[1], decks[#decks]
	local a = first.CFrame * Vector3.new(0, 0, first.Size.Z / 2)
	local b = last.CFrame * Vector3.new(0, 0, -last.Size.Z / 2)
	-- Eski tek parça köprü ters yönlendirilmişse ana ada ucu yine doğru seçilir.
	if #decks == 1 and (a - home).Magnitude > (b - home).Magnitude then
		a, b = b, a
	end
	return a, b, #decks
end

local function graphSignature(plot: Model): string
	local parts = { tostring(plot:GetAttribute("HomeFrame")), tostring(plot:GetAttribute("HomeRadius")) }
	local home = plot:GetAttribute("HomeFrame")
	local homePosition = if typeof(home) == "CFrame" then home.Position else Vector3.zero
	local islands = plot:FindFirstChild("Islands")
	if islands then
		for _, island in islands:GetChildren() do
			local a, b, count = bridgeEnds(island, homePosition)
			table.insert(
				parts,
				`{island.Name}:{a}:{b}:{count}:{island:GetAttribute("PathStart")}:{island:GetAttribute("PathEnd")}`
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
		local homeEnd, islandEnd = bridgeEnds(island, frame.Position)
		if typeof(startPoint) == "Vector3" and typeof(endPoint) == "Vector3" and homeEnd and islandEnd then
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
	for index, point in points do
		-- Yol ağı statiktir; yeni bina bir ara düğümün üstüne gelebilir. Petin son hedefi korunur,
		-- kapalı ara düğüm yerine sonraki açık düğüme güvenli çevre rotası aranır.
		if index < #points and not canStand(actor, point.x, point.z) then
			continue
		end
		if not walk(actor, Vector3.new(point.x, actor.y, point.z)) then
			return false
		end
	end
	return true
end

-- Hayvanın ağılı: yardımcının adasındaki ilk bölge (ana adada "starter")
local function penPoint(plot: Model, island: string, selectedZone: string?): Vector3?
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
			if selectedZone ~= nil and selectedZone ~= "" and zoneId == selectedZone then
				return ground.Position
			end
			if (selectedZone == nil or selectedZone == "") and zoneId == "starter" then
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

		-- Denizdeki tesis (balıkçı teknesi) ve balık kafesi suyun üstündedir: yardımcı karada, evinde durup tekneye bakar
		local animalValue = plot:GetAttribute(`PetAnimal_{suffix}`)
		local animalModel = if typeof(animalValue) == "string" then animalValue else nil
		local zoneValue = plot:GetAttribute(`PetZone_{suffix}`)
		local selectedZone = if typeof(zoneValue) == "string" then zoneValue else nil
		local onWater = spot:GetAttribute("BoatPatrolX") ~= nil or actor.island == "sea"
		local facilityPoint = if onWater then actor.home.Position else (spot.CFrame * FACILITY_OFFSET).Position
		local pen = if onWater
			then actor.home.Position
			else penPoint(plot, actor.island, selectedZone) or actor.home.Position
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
		carry(actor, "animal", animalModel)
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
		local nextJob = job()
		if nextJob ~= "" then
			local nextSpot = spotOf(plot, nextJob)
			local nextAnimal = plot:GetAttribute(`PetAnimal_{suffix}`)
			local nextZone = plot:GetAttribute(`PetZone_{suffix}`)
			local nextOnWater = actor.island == "sea"
				or (nextSpot ~= nil and nextSpot:GetAttribute("BoatPatrolX") ~= nil)
			local nextPen = if nextOnWater
				then actor.home.Position
				else penPoint(plot, actor.island, if typeof(nextZone) == "string" then nextZone else nil)
					or actor.home.Position
			local nextFacility = if nextOnWater or not nextSpot
				then actor.home.Position
				else (nextSpot.CFrame * FACILITY_OFFSET).Position
			if not goTo(actor, nextPen) then
				return
			end
			idleFor(actor, 0.3)
			carry(actor, "animal", if typeof(nextAnimal) == "string" then nextAnimal else nil)
			if not goTo(actor, nextFacility) then
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

local tracked: { [Model]: boolean } = {}

local function track(instance: Instance)
	if not instance:IsA("Model") or tracked[instance] then
		return
	end
	local model = instance
	tracked[model] = true
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
			tracked[model] = nil
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
			propModel = nil,
			radius = 1.2,
			height = 2,
			width = 2,
			length = 2,
			center = Vector3.zero,
			carryHeight = 2,
		}
		updateBodySize(actor)
		actor.carryHeight = actor.height
		local ok, err = pcall(function()
			-- Yol geçici kapalıyken yardımcı görevi tamamen bırakmaz; güvenli konumdan tekrar dener.
			while alive(actor) do
				run(actor)
				clearProps(actor)
				if alive(actor) then
					idleFor(actor, RETRY_SECONDS)
				end
			end
		end)
		clearProps(actor)
		tracked[model] = nil
		if not ok then
			warn(`[PetAnimator] {err}`)
		end
	end)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
for _, instance in CollectionService:GetTagged(TAG) do
	track(instance)
end
