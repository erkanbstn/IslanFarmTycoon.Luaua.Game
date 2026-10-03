--!strict
-- Hayvanları kendi bölgeleri içinde yavaşça gezdirir (sadece görsel, sadece bu oyuncunun ekranında).
-- Sunucu hayvanı "Animal" etiketi ve AreaCFrame / AreaSize / HeightOffset attribute'larıyla işaretler.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EffectSettings = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("EffectSettings"))

-- Kameradan uzaktaki hayvanlar hareket etmez; düşükte menzil dar ve hareketli hayvan sayısı sınırlı.
local QUALITY = {
	low = { distance = 50, maxActive = 20 },
	medium = { distance = 140, maxActive = math.huge },
	high = { distance = 140, maxActive = math.huge },
}
local NEAR_CHECK_INTERVAL = 0.25
local WALK_SPEED = 3
local TURN_SPEED = 4

-- Yüzey desteği: hayvan düz zemin (alan düzlemi) yerine altındaki gerçek katı yüzeyde durur (kaya, teras, basamak üstü...).
-- Işın hayvanın o anki yüksekliğinin STEP_UP üstünden aşağı iner: çatı/yaprak gibi üstteki parçalar vurulmaz.
-- Çarpışmasız parçalar (hayvan, tabela, ince süs) RespectCanCollide ile geçilir; oyuncu karakteri atlanır.
local STEP_UP = 2.5 -- Mevcut yüksekliğin bu kadar üstünden ışın atılır (çıkılabilir basamak)
local STEP_DROP = 5 -- Mevcut yüksekliğin bu kadar altına kadar destek aranır
local MAX_STEP = 2.5 -- Hedef noktası mevcut yüksekliğe bundan fazla uzaksa seçilmez
local PATH_STEP = 2.4 -- Yol boyunca destek örnek aralığı; ardışık örnekler arası fark MAX_STEP'ten büyükse yol kapalıdır
local SUPPORT_INTERVAL = 0.1 -- Hareket ederken destek yüksekliği bu aralıkla okunur (her kare değil)
local SUPPORT_SMOOTH = 10 -- Yükseklik geçişi yumuşaklığı (1/sn)
local supportParams = RaycastParams.new()
supportParams.FilterType = Enum.RaycastFilterType.Exclude
supportParams.RespectCanCollide = true

type AnimalState = {
	model: Model,
	area: CFrame,
	halfSize: Vector3,
	heightOffset: number,
	position: Vector3, -- alan-yerel X/Z
	yaw: number,
	target: Vector3?,
	waitUntil: number,
	phase: number,
	track: boolean,
	trackAngle: number,
	parts: { BasePart }?, -- BulkMoveTo için model parçaları (nil = yeniden kurulacak)
	offsets: { CFrame }, -- parça CFrame'i, model pivotuna göre
	slot: number, -- Duran hayvanların yazım kareleri dağılsın diye
	swims: boolean, -- Suda yaşar (SwimDepthOffset>0): karaya çıkarılmaz, destek aranmaz
	supported: boolean, -- Başlangıç noktasında altında yüzey bulundu mu (bulunamazsa destek mantığı kapalı: eski sabit yükseklik)
	support: number, -- Alan düzlemine göre yüzey yüksekliği farkı (yumuşatılmış, yazılan)
	supportGoal: number, -- Son ölçülen yüzey farkı
	supportCheckAt: number,
	validateAt: number, -- Hareket adımının (engel + destek) bir sonraki doğrulama zamanı
	lastGood: Vector3, -- Son doğrulanmış konum (başarısız adım buraya geri alınır)
	lastGoodAngle: number,
	stallUntil: number, -- Doğrulama başarısızsa (track) bu zamana kadar bekler
	radius: number, -- Yatay ayak izi yarıçapı (model sınır kutusundan): hayvanlar birbirinden bu kadar uzak hedef seçer
}

local states: { [Model]: AnimalState } = {}
local frameCount = 0
local random = Random.new()

-- Katı dekor ("AnimalObstacle" etiketi, sunucu IslandSiteParts.markObstacles): hedef noktası ve oraya giden doğru bunların
-- (payla genişletilmiş) ayak izine düşmez. Liste hedef seçerken (nadir) tazelenir; kare başı iş yoktur.
local OBSTACLE_MARGIN = 0.4 -- + hayvanın yarıçapının %70'i (büyük türler engelden daha uzak durur)
local FOOTPRINT_FRONT = 0.8 -- Ön ayak örneği: ayak izi yarıçapının bu katı kadar ileride
local obstacleCache: { BasePart } = {}
local obstacleCacheAt = -math.huge

local function obstaclesNear(state: AnimalState): { BasePart }
	local now = os.clock()
	if now - obstacleCacheAt > 5 then
		table.clear(obstacleCache)
		for _, instance in CollectionService:GetTagged("AnimalObstacle") do
			if instance:IsA("BasePart") then
				table.insert(obstacleCache, instance)
			end
		end
		obstacleCacheAt = now
	end
	local center = state.area.Position
	local reach = state.halfSize.Magnitude + 8
	local near: { BasePart } = {}
	for _, part in obstacleCache do
		if part.Parent and (part.Position - center).Magnitude <= reach then
			table.insert(near, part)
		end
	end
	return near
end

local function blockedAt(state: AnimalState, point: Vector3, obstacles: { BasePart }): boolean
	local world = state.area:PointToWorldSpace(point)
	for _, part in obstacles do
		local localPoint = part.CFrame:PointToObjectSpace(Vector3.new(world.X, part.Position.Y, world.Z))
		local half = part.Size / 2
		local margin = OBSTACLE_MARGIN + state.radius * 0.7
		if math.abs(localPoint.X) < half.X + margin and math.abs(localPoint.Z) < half.Z + margin then
			return true
		end
	end
	return false
end

local function pathBlocked(state: AnimalState, from: Vector3, to: Vector3, obstacles: { BasePart }): boolean
	local steps = math.ceil((to - from).Magnitude / 1.2)
	for step = 1, steps do
		if blockedAt(state, from:Lerp(to, step / steps), obstacles) then
			return true
		end
	end
	return false
end

-- Aynı alandaki diğer hayvanların şu anki yeri ve hedefi: yeni hedef onların ayak izlerine (yarıçaplar toplamı + pay) girmez.
local ANIMAL_GAP = 0.6
local function crowdedAt(state: AnimalState, point: Vector3): boolean
	for other, otherState in states do
		if other ~= state.model and (otherState.area.Position - state.area.Position).Magnitude < 1 then
			local limit = state.radius + otherState.radius + ANIMAL_GAP
			local flat = point - otherState.position
			if flat.X * flat.X + flat.Z * flat.Z < limit * limit then
				return true
			end
			local target = otherState.target
			if target then
				local toTarget = point - target
				if toTarget.X * toTarget.X + toTarget.Z * toTarget.Z < limit * limit then
					return true
				end
			end
		end
	end
	return false
end

-- Alan-yerel (x, z) noktasının altındaki katı yüzeyin alan düzlemine göre yüksekliği; `reference` aramanın başladığı fark
local function supportAt(state: AnimalState, point: Vector3, reference: number): number?
	local world = state.area:PointToWorldSpace(Vector3.new(point.X, 0, point.Z))
	local originY = state.area.Position.Y + reference + STEP_UP
	local origin = Vector3.new(world.X, originY, world.Z)
	local direction = Vector3.new(0, -(STEP_UP + STEP_DROP), 0)
	local excluded: { Instance } = {}
	for _ = 1, 3 do
		supportParams.FilterDescendantsInstances = excluded
		local result = Workspace:Raycast(origin, direction, supportParams)
		if not result then
			return nil
		end
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		if model and (model:FindFirstChildWhichIsA("Humanoid") or CollectionService:HasTag(model, "Animal")) then
			table.insert(excluded, model)
		elseif result.Normal.Y < 0.6 then
			return nil -- dik duvar/direk yan yüzü: basılabilir yüzey değil
		else
			return result.Position.Y - state.area.Position.Y
		end
	end
	return nil
end

-- Gövde merkezi ve ön ayak noktası birlikte desteklenmeli: ikisinden biri boşluk/aşırı basamaksa nil; yükseklik ikisinin yükseği
local function footSupport(state: AnimalState, point: Vector3, yaw: number, reference: number): number?
	local center = supportAt(state, point, reference)
	if center == nil then
		return nil
	end
	local reach = state.radius * FOOTPRINT_FRONT
	local front = point + Vector3.new(-math.sin(yaw) * reach, 0, -math.cos(yaw) * reach)
	local ahead = supportAt(state, front, center)
	if ahead == nil or math.abs(ahead - center) > MAX_STEP then
		return nil
	end
	local back = point + Vector3.new(math.sin(yaw) * reach, 0, math.cos(yaw) * reach)
	local behind = supportAt(state, back, center)
	if behind == nil or math.abs(behind - center) > MAX_STEP then
		return nil
	end
	return math.max(center, ahead, behind)
end

-- Hedef noktasında ve oraya giden yolda hayvan basabileceği bir yüzey var mı (basamak farkı MAX_STEP içinde, boşluk yok)
local function walkable(state: AnimalState, from: Vector3, to: Vector3): boolean
	if not state.supported then
		return true
	end
	local previous = state.support
	local steps = math.max(1, math.ceil((to - from).Magnitude / PATH_STEP))
	for step = 1, steps do
		local flat = to - from
		local yaw = math.atan2(-flat.X, -flat.Z)
		local height = footSupport(state, from:Lerp(to, step / steps), yaw, previous)
		if height == nil or math.abs(height - previous) > MAX_STEP then
			return false
		end
		previous = height
	end
	return true
end

local function randomPoint(state: AnimalState): Vector3
	local obstacles = obstaclesNear(state)
	local fallback = state.position
	for _ = 1, 12 do
		local point = Vector3.new(
			random:NextNumber(-state.halfSize.X, state.halfSize.X),
			0,
			random:NextNumber(-state.halfSize.Z, state.halfSize.Z)
		)
		if
			not crowdedAt(state, point)
			and walkable(state, state.position, point)
			and (
				#obstacles == 0
				or (not blockedAt(state, point, obstacles) and not pathBlocked(state, state.position, point, obstacles))
			)
		then
			return point
		end
	end
	return fallback -- uygun nokta bulunamadı (kalabalık/engel): yerinde bekler
end

-- Hayvanın yatay ayak izi yarıçapı: model sınır kutusunun uzun yatay kenarının yarısı (kuyruk/kanat payıyla %75)
local function footprintRadius(model: Model): number
	local size = model:GetExtentsSize()
	return math.max(0.8, math.max(size.X, size.Z) * 0.5 * 0.75)
end

local function trackReady(instance: Instance)
	if not instance:IsA("Model") or instance:GetAttribute("BuildPopActive") == true then
		return
	end
	local area = instance:GetAttribute("AreaCFrame")
	local size = instance:GetAttribute("AreaSize")
	local heightOffset = instance:GetAttribute("HeightOffset")
	if typeof(area) ~= "CFrame" or typeof(size) ~= "Vector3" or typeof(heightOffset) ~= "number" then
		return
	end

	local localCf = area:ToObjectSpace(instance:GetPivot())
	local look = localCf.LookVector
	local position = Vector3.new(localCf.Position.X, 0, localCf.Position.Z)
	local yaw = math.atan2(-look.X, -look.Z)

	-- Hayvan büyüyünce sunucu modeli yeniler; yenisi eskisinin durduğu yerden devam etsin
	local uid = instance:GetAttribute("Uid")
	if uid ~= nil then
		for other, otherState in states do
			if other ~= instance and other:GetAttribute("Uid") == uid then
				position, yaw = otherState.position, otherState.yaw
				break
			end
		end
	end

	local movement = instance:GetAttribute("MovementStyle")
	local isTrack = movement == "track"
	states[instance] = {
		model = instance,
		area = area,
		halfSize = size / 2,
		heightOffset = heightOffset,
		position = if isTrack then Vector3.new(0, 0, size.Z / 2 - 2) else position,
		yaw = yaw,
		target = nil,
		waitUntil = os.clock() + random:NextNumber(0, 4),
		phase = random:NextNumber(0, math.pi * 2),
		track = isTrack,
		trackAngle = random:NextNumber(0, math.pi * 2),
		parts = nil,
		offsets = {},
		slot = random:NextInteger(0, 1),
		swims = false,
		supported = false,
		support = 0,
		supportGoal = 0,
		supportCheckAt = 0,
		validateAt = 0,
		lastGood = position,
		lastGoodAngle = 0,
		stallUntil = 0,
		radius = footprintRadius(instance),
	}
	-- Yüzme derinliği olan (suda yaşayan) hayvanlar karaya çıkarılmaz; track (daire) hareketi de sabit yükseklikte kalır
	local state = states[instance]
	state.lastGoodAngle = state.trackAngle
	local swimDepth = instance:GetAttribute("SwimDepthOffset")
	state.swims = typeof(swimDepth) == "number" and swimDepth > 0
	if not state.swims then
		local height = supportAt(state, state.position, 0)
		if height ~= nil and math.abs(height) <= MAX_STEP then
			state.supported = true
			state.support = height
			state.supportGoal = height
		end
	end
	-- İlk karede doğru yerde görünsün (yüzeyin üstünde)
	instance:PivotTo(area * CFrame.new(position.X, heightOffset + state.support, position.Z) * CFrame.Angles(0, yaw, 0))
end

local pending: { [Instance]: { RBXScriptConnection } } = {}
local function untrack(instance: Instance)
	if instance:IsA("Model") then
		states[instance] = nil
	end
	local connections = pending[instance]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
		pending[instance] = nil
	end
end

local function track(instance: Instance)
	if not instance:IsA("Model") or pending[instance] then
		return
	end
	local function retry()
		if
			not states[instance]
			and instance:IsDescendantOf(Workspace)
			and instance:FindFirstChildWhichIsA("BasePart", true)
		then
			trackReady(instance)
		end
	end
	pending[instance] = {
		instance.AttributeChanged:Connect(retry),
		instance.DescendantAdded:Connect(function()
			retry()
			-- Sonradan gelen/giden parça: parça listesi bir sonraki harekette yeniden çıkarılır
			local state = states[instance]
			if state then
				state.parts = nil
			end
		end),
		instance.DescendantRemoving:Connect(function()
			local state = states[instance]
			if state then
				state.parts = nil
			end
		end),
	}
	retry()
end
CollectionService:GetInstanceAddedSignal("Animal"):Connect(track)
CollectionService:GetInstanceRemovedSignal("Animal"):Connect(untrack)
for _, instance in CollectionService:GetTagged("Animal") do
	track(instance)
end

local function angleDelta(from: number, to: number): number
	return (to - from + math.pi) % (math.pi * 2) - math.pi
end

local function rebuildParts(state: AnimalState)
	local pivot = state.model:GetPivot()
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	for _, descendant in state.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
			table.insert(offsets, pivot:ToObjectSpace(descendant.CFrame))
		end
	end
	state.parts = parts
	state.offsets = offsets
end

-- Kameraya yakın ve (düşükte) en yakın N hayvan; her karede mesafe hesaplanmaz.
local active: { AnimalState } = {}
local nextNearCheck = 0
local ranked: { { state: AnimalState, distance: number } } = {}

local function refreshActive(cameraPos: Vector3, now: number)
	local config = QUALITY[EffectSettings.quality()] or QUALITY.medium
	table.clear(ranked)
	for model, state in states do
		if not model.Parent then
			states[model] = nil
			continue
		end
		local worldPos = state.area.Position + state.area:VectorToWorldSpace(state.position)
		local distance = (worldPos - cameraPos).Magnitude
		if distance <= config.distance then
			table.insert(ranked, { state = state, distance = distance })
		end
	end
	if #ranked > config.maxActive then
		table.sort(ranked, function(a, b)
			return a.distance < b.distance
		end)
	end
	table.clear(active)
	for index = 1, math.min(#ranked, config.maxActive) do
		active[index] = ranked[index].state
	end
	nextNearCheck = now + NEAR_CHECK_INTERVAL
end

local bulkParts: { BasePart } = {}
local bulkCFrames: { CFrame } = {}

-- Yakındaki hareket her çizim karesinde uygulanır (PreRender: kare çizilmeden hemen önce).
-- Zamanı biriktirip sıfırlayan 30 Hz kapısı değişken kare aralıklarında 20 Hz'e düşerek görünür
-- takılma yapıyordu. Tüm hayvanların parçaları tek BulkMoveTo ile taşınır (PivotTo başına bir çağrı yerine).
RunService.PreRender:Connect(function(dt: number)
	dt = math.min(dt, 1 / 15)
	if EffectSettings.reducedMotion() then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	if now >= nextNearCheck then
		refreshActive(camera.CFrame.Position, now)
	end
	frameCount += 1
	table.clear(bulkParts)
	table.clear(bulkCFrames)

	for index = #active, 1, -1 do
		local state = active[index]
		local model = state.model
		if not model.Parent then
			states[model] = nil
			table.remove(active, index)
			continue
		end
		-- ScaleTo efektinin pivotunu aynı karede geri yazma; bitince kaldığı yerden sürer.
		if model:GetAttribute("BuildPopActive") == true then
			continue
		end

		local moving = false
		if state.track then
			if now < state.stallUntil then
				continue
			end
			state.trackAngle += dt * 0.9
			local rx = math.min(state.halfSize.X, 6)
			local rz = math.min(state.halfSize.Z, 14)
			state.position = Vector3.new(math.cos(state.trackAngle) * rx, 0, math.sin(state.trackAngle) * rz)
			state.yaw = state.trackAngle + math.pi / 2
			moving = true
		elseif state.target == nil then
			if now >= state.waitUntil then
				-- Yüzey henüz bulunamadıysa (streaming) kara hayvanı güvenli biçimde yerinde bekler
				state.target = if state.supported or state.swims then randomPoint(state) else nil
				if state.target == nil then
					state.waitUntil = now + 1
				end
			end
		else
			local target = state.target :: Vector3
			local offset = target - state.position
			local distance = offset.Magnitude
			if distance < 0.3 then
				state.target = nil
				state.waitUntil = now + random:NextNumber(2, 7)
			else
				local desiredYaw = math.atan2(-offset.X, -offset.Z)
				local turn = angleDelta(state.yaw, desiredYaw)
				state.yaw += math.clamp(turn, -TURN_SPEED * dt, TURN_SPEED * dt)
				-- Önce dön, sonra yürü
				if math.abs(turn) < 0.6 then
					state.position += offset.Unit * math.min(WALK_SPEED * dt, distance)
					moving = true
				end
			end
		end

		state.phase += dt * (if moving then 10 else 2)
		local bob = if moving then math.abs(math.sin(state.phase)) * 0.25 else math.sin(state.phase) * 0.03
		if not state.swims then
			if not state.supported then
				-- İlk yüklemede/streaming'de yüzey gelmemiş olabilir: yüzey gelene kadar saniyede bir yeniden aranır
				if now >= state.supportCheckAt then
					state.supportCheckAt = now + 1
					local height = supportAt(state, state.position, 0)
					if height ~= nil and math.abs(height) <= MAX_STEP then
						state.supported = true
						state.support, state.supportGoal = height, height
						state.lastGood = state.position
					end
				end
			elseif moving and now >= state.validateAt then
				-- Atılan adımlar engel ve destek denetiminden geçer; geçemeyen adım son doğrulanmış konuma geri alınır
				state.validateAt = now + SUPPORT_INTERVAL
				local obstacles = obstaclesNear(state)
				local height = footSupport(state, state.position, state.yaw, state.support)
				if
					height ~= nil
					and math.abs(height - state.support) <= MAX_STEP
					and (#obstacles == 0 or not blockedAt(state, state.position, obstacles))
				then
					state.supportGoal = height
					state.lastGood = state.position
					state.lastGoodAngle = state.trackAngle
				else
					state.position = state.lastGood
					state.trackAngle = state.lastGoodAngle
					state.target = nil
					state.waitUntil = now + 1
					state.stallUntil = now + 1
					moving = false
				end
			end
			-- Yüzeye geçiş: inişte yumuşak, çıkışta ayak yüzeyin altında kalmaz (hayvan yüzeye girmez)
			local diff = state.supportGoal - state.support
			if diff >= 0 or math.abs(diff) < 0.01 then
				state.support = state.supportGoal
			else
				state.support += diff * math.min(1, SUPPORT_SMOOTH * dt)
			end
		end
		local localCf = CFrame.new(state.position.X, state.heightOffset + state.support + bob, state.position.Z)
			* CFrame.Angles(0, state.yaw, 0)
		-- Duran hayvanın nefes hareketi çok küçüktür: yarım hızda yazmak yeter
		if moving or (frameCount + state.slot) % 2 == 0 then
			if not state.parts then
				rebuildParts(state)
			end
			local parts = state.parts :: { BasePart }
			local pivot = state.area * localCf
			local offsets = state.offsets
			for partIndex, part in parts do
				table.insert(bulkParts, part)
				table.insert(bulkCFrames, pivot * offsets[partIndex])
			end
		end
	end

	if #bulkParts > 0 then
		Workspace:BulkMoveTo(bulkParts, bulkCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
