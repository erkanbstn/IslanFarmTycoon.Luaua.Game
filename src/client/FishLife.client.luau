--!strict
-- Denizde yaşam: adaların çevresinde sürü halinde yüzen balıklar; ara sıra biri sudan sıçrar.
-- Sadece görsel ve sadece bu oyuncunun ekranında (sunucuya yük yok). Uzaktaki sürüler güncellenmez.

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WATER_Y = 0 -- Deniz yüzeyi (MapBuilder: su bloğunun üstü)
local UPDATE_DISTANCE = 170 -- Kameradan bu uzaklıktaki sürüler hareket eder
local FISH_PER_SCHOOL = 5
local JUMP_INTERVAL = NumberRange.new(3, 7)

local FISH_COLORS = {
	Color3.fromRGB(240, 140, 50), -- turuncu
	Color3.fromRGB(190, 200, 215), -- gümüş
	Color3.fromRGB(70, 130, 205), -- mavi
	Color3.fromRGB(245, 205, 70), -- sarı
}

type Fish = {
	body: BasePart,
	tail: BasePart,
	offset: Vector3, -- Sürü merkezine göre
	phase: number,
	jumping: boolean,
}

type School = {
	anchor: Vector3,
	radius: number,
	angle: number,
	speed: number, -- rad/sn (işaret yönü belirler)
	depth: number,
	fish: { Fish },
	center: Vector3,
	heading: Vector3,
}

local random = Random.new()
local folder = Instance.new("Folder")
folder.Name = "FishLife"
folder.Parent = Workspace

local function makeFish(color: Color3, size: number): (BasePart, BasePart)
	local body = Instance.new("Part")
	body.Name = "Fish"
	body.Size = Vector3.new(0.55, 0.5, 1.4) * size
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.CastShadow = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	body.Transparency = 1
	body.Parent = folder

	local tail = Instance.new("WedgePart")
	tail.Name = "Tail"
	tail.Size = Vector3.new(0.08, 0.55, 0.5) * size
	tail.Color = color
	tail.Material = Enum.Material.SmoothPlastic
	tail.Anchored = true
	tail.CanCollide = false
	tail.CanQuery = false
	tail.CanTouch = false
	tail.CastShadow = false
	tail.Transparency = 1
	tail.Parent = folder
	return body, tail
end

local function splash(position: Vector3)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = Vector3.new(position.X, WATER_Y + 0.1, position.Z)
	attachment.Parent = Workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0.2)
	emitter.Lifetime = NumberRange.new(0.4, 0.7)
	emitter.Speed = NumberRange.new(4, 7)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, -25, 0)
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(18)
	task.delay(1, function()
		attachment:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Sürülerin yerleri: her adanın etrafındaki suda
---------------------------------------------------------------------------

type IslandCircle = { center: Vector3, radius: number }

local function collectIslands(): { IslandCircle }
	local circles: { IslandCircle } = {}
	local plots = Workspace:FindFirstChild("Plots")
	if plots then
		for _, desc in plots:GetDescendants() do
			if desc:IsA("BasePart") and (desc.Name == "PlotBase" or desc.Name == "IslandBase") then
				-- Silindirin çapı Size.Y (ekseni X)
				table.insert(circles, { center = desc.Position, radius = desc.Size.Y / 2 })
			elseif desc:IsA("BasePart") and desc:GetAttribute("SwimDepth") then
				-- Balık kafesi: süs balıkları kafesin içine/üstüne denk gelmesin
				table.insert(circles, { center = desc.Position, radius = math.max(desc.Size.X, desc.Size.Z) / 2 - 6 })
			end
		end
	end
	table.insert(circles, { center = Vector3.zero, radius = 40 }) -- Meydan
	return circles
end

local function isOpenWater(point: Vector3, circles: { IslandCircle }): boolean
	for _, circle in circles do
		local flat = Vector3.new(point.X - circle.center.X, 0, point.Z - circle.center.Z)
		if flat.Magnitude < circle.radius + 12 then
			return false
		end
	end
	return true
end

local schools: { School } = {}

local function createSchool(anchor: Vector3)
	local fish: { Fish } = {}
	local color = FISH_COLORS[random:NextInteger(1, #FISH_COLORS)]
	local size = random:NextNumber(0.8, 1.3)
	for _ = 1, FISH_PER_SCHOOL do
		local body, tail = makeFish(color, size * random:NextNumber(0.85, 1.1))
		table.insert(fish, {
			body = body,
			tail = tail,
			offset = Vector3.new(random:NextNumber(-2, 2), random:NextNumber(-0.4, 0.4), random:NextNumber(-2, 2)),
			phase = random:NextNumber(0, math.pi * 2),
			jumping = false,
		})
	end
	table.insert(schools, {
		anchor = anchor,
		radius = random:NextNumber(4, 9),
		angle = random:NextNumber(0, math.pi * 2),
		speed = random:NextNumber(0.25, 0.45) * (if random:NextNumber() < 0.5 then -1 else 1),
		depth = random:NextNumber(1.4, 2.6),
		fish = fish,
		center = anchor,
		heading = Vector3.new(0, 0, -1),
	})
end

local function spawnSchools()
	local circles = collectIslands()
	for _, circle in circles do
		local count = if circle.radius > 50 then 4 elseif circle.radius > 30 then 2 else 2
		for _ = 1, count do
			-- Birkaç deneme: adaların dışındaki açık suya denk gelen bir nokta bul
			for _ = 1, 8 do
				local angle = random:NextNumber(0, math.pi * 2)
				local distance = circle.radius + random:NextNumber(18, 34)
				local point = circle.center + Vector3.new(math.sin(angle) * distance, 0, math.cos(angle) * distance)
				point = Vector3.new(point.X, WATER_Y, point.Z)
				if isOpenWater(point, circles) then
					createSchool(point)
					break
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Sıçrama
---------------------------------------------------------------------------

local function jump(school: School, fish: Fish)
	fish.jumping = true
	local start = fish.body.Position
	local forward = school.heading
	local duration = 1.1
	local height = random:NextNumber(2.2, 3.5)
	local length = random:NextNumber(4, 7)
	local started = os.clock()
	local splashedOut, splashedIn = false, false

	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - started) / duration
		if t >= 1 or not fish.body.Parent then
			fish.jumping = false
			if connection then
				connection:Disconnect()
			end
			return
		end
		-- Parabol: suyun altından çıkıp geri girer
		local y = WATER_Y - school.depth + (school.depth + height) * 4 * t * (1 - t)
		local position = Vector3.new(start.X, 0, start.Z) + forward * (length * t) + Vector3.new(0, y, 0)
		local pitch = math.rad(-60 + 120 * t) -- burun önce yukarı, sonra aşağı
		local cf = CFrame.lookAt(position, position + forward) * CFrame.Angles(-pitch, 0, 0)
		fish.body.CFrame = cf
		fish.tail.CFrame = cf * CFrame.new(0, 0, fish.body.Size.Z / 2 + fish.tail.Size.Z / 2 - 0.1)

		if not splashedOut and y > WATER_Y then
			splashedOut = true
			splash(position)
		elseif splashedOut and not splashedIn and y < WATER_Y then
			splashedIn = true
			splash(position)
		end
	end)
end

local nextJumpAt = os.clock() + random:NextNumber(JUMP_INTERVAL.Min, JUMP_INTERVAL.Max)

local function tryJump(cameraPos: Vector3)
	if os.clock() < nextJumpAt then
		return
	end
	nextJumpAt = os.clock() + random:NextNumber(JUMP_INTERVAL.Min, JUMP_INTERVAL.Max)
	-- Kameraya yakın bir sürüden bir balık
	local candidates = {}
	for _, school in schools do
		if (school.center - cameraPos).Magnitude < 90 then
			table.insert(candidates, school)
		end
	end
	if #candidates == 0 then
		return
	end
	local school = candidates[random:NextInteger(1, #candidates)]
	local fish = school.fish[random:NextInteger(1, #school.fish)]
	if not fish.jumping and fish.body.Transparency == 0 then
		jump(school, fish)
	end
end

---------------------------------------------------------------------------
-- Döngü
---------------------------------------------------------------------------

local function update(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPos = camera.CFrame.Position
	local now = os.clock()
	local quality = localPlayer:GetAttribute("EffectsQuality")
	local reduced = localPlayer:GetAttribute("ReducedMotion") == true

	for _, school in schools do
		local visible = not reduced
			and (school.anchor - cameraPos).Magnitude <= (if quality == "low" then 90 else UPDATE_DISTANCE)
		for index, fish in school.fish do
			local showFish = visible
				and index <= (if quality == "low" then 2 elseif quality == "high" then FISH_PER_SCHOOL else 3)
			local transparency = if showFish then 0 else 1
			if fish.body.Transparency ~= transparency then
				fish.body.Transparency = transparency
				fish.tail.Transparency = transparency
			end
		end
		if not visible then
			continue
		end
		school.angle += school.speed * dt
		local center = school.anchor
			+ Vector3.new(math.cos(school.angle) * school.radius, 0, math.sin(school.angle) * school.radius)
		-- Dairesel yüzüşün teğet yönü
		local tangent = Vector3.new(-math.sin(school.angle), 0, math.cos(school.angle)) * math.sign(school.speed)
		school.center = center
		school.heading = tangent

		local base = CFrame.lookAt(center, center + tangent)
		for _, fish in school.fish do
			if fish.jumping then
				continue
			end
			local wobble = math.sin(now * 2 + fish.phase) * 0.35
			local position = (base * CFrame.new(fish.offset.X + wobble, 0, fish.offset.Z)).Position
			position = Vector3.new(position.X, WATER_Y - school.depth + fish.offset.Y, position.Z)
			local cf = CFrame.lookAt(position, position + tangent)
				* CFrame.Angles(0, math.sin(now * 3 + fish.phase) * 0.15, 0)
			fish.body.CFrame = cf
			-- Kuyruk sallanır
			fish.tail.CFrame = cf
				* CFrame.new(0, 0, fish.body.Size.Z / 2 + fish.tail.Size.Z / 2 - 0.1)
				* CFrame.Angles(0, math.sin(now * 12 + fish.phase) * 0.5, 0)
		end
	end

	if not reduced and quality ~= "low" then
		tryJump(cameraPos)
	end
end

-- Geç çoğalan/stream edilen adalar geldiğinde dekoratif sürüleri yeniden kur.
-- Bekleme bir yükleme varsayımı değil, aynı karedeki parça olaylarını birleştirmedir.
local rebuildScheduled = false
local function scheduleRebuild(instance: Instance)
	if
		not instance:IsA("BasePart")
		or (instance.Name ~= "PlotBase" and instance.Name ~= "IslandBase" and instance.Name ~= "Ground")
	then
		return
	end
	if rebuildScheduled then
		return
	end
	rebuildScheduled = true
	task.defer(function()
		rebuildScheduled = false
		folder:ClearAllChildren()
		table.clear(schools)
		spawnSchools()
	end)
end
Workspace.DescendantAdded:Connect(scheduleRebuild)
Workspace.DescendantRemoving:Connect(scheduleRebuild)
spawnSchools()
RunService.Heartbeat:Connect(update)
