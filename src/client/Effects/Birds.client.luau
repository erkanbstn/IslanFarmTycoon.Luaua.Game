--!strict
-- Gökyüzünde süzülen kuş sürüleri: martılar denizin üstünde, küçük kuşlar adaların üstünde.
-- Kanat çırpar, arada süzülür. Sadece görsel, sadece bu oyuncunun ekranında; uzaktakiler güncellenmez.
-- Fırtınada ve karda kuşlar azalır (sığınırlar).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EffectSettings = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("EffectSettings"))
local ClientModelAssets = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientModelAssets"))
local BirdBehavior = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("BirdBehavior"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local StartupGate = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("StartupGate"))
StartupGate.wait(1.5)

local FLOCK_COUNT = 10
local UPDATE_DISTANCE = 320
local MAP_RADIUS = 380
local LAND_CHECK_INTERVAL = 0.4
local PLAYER_CHECK_INTERVAL = 0.25

type Bird = {
	model: Model,
	parts: { BasePart },
	body: BasePart,
	leftWing: BasePart,
	rightWing: BasePart,
	offset: Vector3,
	phase: number,
	flapSpeed: number,
	mode: string,
	frame: CFrame,
	from: CFrame,
	target: CFrame,
	elapsed: number,
	duration: number,
	nextLanding: number,
	perch: BasePart?,
	perchLocal: CFrame?,
	groundOffset: number,
}

type Flock = {
	center: Vector3,
	radius: number,
	height: number,
	angle: number,
	speed: number,
	birds: { Bird },
	gull: boolean,
}

local random = Random.new()
local folder = Instance.new("Folder")
folder.Name = "Birds"
folder.Parent = Workspace
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false
rayParams.RespectCanCollide = true
local nearbyPlayers: { BasePart } = {}
local playerElapsed = PLAYER_CHECK_INTERVAL
local landingElapsed = 0
local frameElapsed = 0

-- Kuş modeli: client-assets/Birds/Gull | Songbird (Body, LeftWing, RightWing, Head, Beak, Tail); boyut/renk modelden gelir.
-- Hareket kodda: gövde modelle birlikte taşınır, kanatlar ayrıca çırpılır.
local missingWarned = false
local function makeBird(gull: boolean): Bird?
	local model = ClientModelAssets.clone("Birds", if gull then "Gull" else "Songbird")
	local body = if model then model:FindFirstChild("Body") else nil
	local leftWing = if model then model:FindFirstChild("LeftWing") else nil
	local rightWing = if model then model:FindFirstChild("RightWing") else nil
	if
		not (
			model
			and body
			and body:IsA("BasePart")
			and leftWing
			and leftWing:IsA("BasePart")
			and rightWing
			and rightWing:IsA("BasePart")
		)
	then
		if model then
			model:Destroy()
		end
		if not missingWarned then
			missingWarned = true
			warn(
				"[Birds] client-assets/Birds/Gull|Songbird.rbxmx bulunamadı ya da Body/LeftWing/RightWing eksik; kuşlar çizilmedi"
			)
		end
		return nil
	end
	local scale = if gull then random:NextNumber(1.2, 1.5) else random:NextNumber(0.7, 0.9)
	model:ScaleTo(scale)
	local parts: { BasePart } = {}
	local minimumY = math.huge
	local pivot = model:GetPivot()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			table.insert(parts, descendant)
			if descendant ~= leftWing and descendant ~= rightWing then
				local relative = pivot:ToObjectSpace(descendant.CFrame)
				local half = descendant.Size / 2
				local extentY = math.abs(relative.RightVector.Y) * half.X
					+ math.abs(relative.UpVector.Y) * half.Y
					+ math.abs(relative.LookVector.Y) * half.Z
				minimumY = math.min(minimumY, relative.Position.Y - extentY)
			end
		end
	end
	model.Parent = folder

	return {
		model = model,
		parts = parts,
		body = body :: BasePart,
		leftWing = leftWing :: BasePart,
		rightWing = rightWing :: BasePart,
		offset = Vector3.new(random:NextNumber(-5, 5), random:NextNumber(-1.5, 1.5), random:NextNumber(-5, 5)),
		phase = random:NextNumber(0, math.pi * 2),
		flapSpeed = if gull then random:NextNumber(5, 7) else random:NextNumber(10, 14),
		mode = "flight",
		frame = CFrame.identity,
		from = CFrame.identity,
		target = CFrame.identity,
		elapsed = 0,
		duration = 0,
		nextLanding = os.clock() + random:NextNumber(6, 24),
		perch = nil,
		perchLocal = nil,
		groundOffset = math.max(0, -minimumY) + 0.08,
	}
end

local flocks: { Flock } = {}

for i = 1, FLOCK_COUNT do
	-- Martılar dış halkada (deniz), küçük kuşlar içeride (adalar)
	local gull = i % 2 == 0
	local angle = random:NextNumber(0, math.pi * 2)
	local distance = if gull then random:NextNumber(200, MAP_RADIUS) else random:NextNumber(40, 260)
	local birds: { Bird } = {}
	for _ = 1, if gull then random:NextInteger(2, 4) else random:NextInteger(4, 7) do
		local bird = makeBird(gull)
		if bird then
			table.insert(birds, bird)
		end
	end
	table.insert(flocks, {
		center = Vector3.new(math.sin(angle) * distance, 0, math.cos(angle) * distance),
		radius = random:NextNumber(25, 60),
		height = if gull then random:NextNumber(22, 35) else random:NextNumber(30, 55),
		angle = random:NextNumber(0, math.pi * 2),
		speed = random:NextNumber(0.12, 0.22) * (if random:NextNumber() < 0.5 then -1 else 1),
		birds = birds,
		gull = gull,
	})
end

local function setVisible(flock: Flock, visible: boolean)
	for _, bird in flock.birds do
		local transparency = if visible then 0 else 1
		if bird.body.Transparency ~= transparency then
			for _, part in bird.parts do
				part.Transparency = transparency
			end
		end
	end
end

local function updatePlayers()
	table.clear(nearbyPlayers)
	local excluded: { Instance } = { folder }
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if character then
			table.insert(excluded, character)
		end
		if root and root:IsA("BasePart") then
			table.insert(nearbyPlayers, root)
		end
	end
	rayParams.FilterDescendantsInstances = excluded
end

local function threatAt(position: Vector3): Vector3?
	for _, root in nearbyPlayers do
		if
			root.Parent
			and BirdBehavior.shouldFlee((root.Position - position).Magnitude, root.AssemblyLinearVelocity.Magnitude)
		then
			return root.Position
		end
	end
	return nil
end

local function takeOff(bird: Bird, threat: Vector3?)
	local away = if threat then bird.frame.Position - threat else bird.frame.LookVector
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 0.01 then
		away = Vector3.xAxis
	end
	local destination = bird.frame.Position + away.Unit * 20 + Vector3.new(0, 12, 0)
	bird.mode = "leaving"
	bird.from = bird.frame
	bird.target = CFrame.lookAt(destination, destination + away.Unit)
	bird.elapsed = 0
	bird.duration = 1.8
	bird.perch = nil
	bird.perchLocal = nil
	bird.nextLanding = os.clock() + random:NextNumber(20, 45)
end

local function tryLanding(bird: Bird, now: number)
	bird.nextLanding = now + random:NextNumber(12, 25)
	local start = bird.frame.Position
	local result = Workspace:Raycast(start, Vector3.new(0, -100, 0), rayParams)
	if not result or not result.Instance:IsA("BasePart") then
		return
	end
	local surface = result.Instance
	local ancestor: Instance? = surface.Parent
	while ancestor and ancestor ~= Workspace do
		if
			ancestor:IsA("Model")
			and (
				ancestor:FindFirstChildOfClass("Humanoid")
				or CollectionService:HasTag(ancestor, "Animal")
				or CollectionService:HasTag(ancestor, "HubNpc")
				or ancestor:GetAttribute("PetKind") ~= nil
			)
		then
			return
		end
		ancestor = ancestor.Parent
	end
	if
		not BirdBehavior.safeSurface(
			result.Normal.Y,
			result.Material == Enum.Material.Water,
			surface.CanCollide,
			surface.Transparency
		) or start.Y - result.Position.Y < 3
	then
		return
	end
	local position = result.Position + Vector3.new(0, bird.groundOffset, 0)
	local perched = 0
	for _, flock in flocks do
		for _, other in flock.birds do
			if other.mode == "landing" or other.mode == "perched" then
				perched += 1
				if (other.target.Position - position).Magnitude < 4 then
					return
				end
			end
		end
	end
	if perched >= (if EffectSettings.quality() == "low" then 2 else 6) then
		return
	end
	if threatAt(position) then
		return
	end
	local look = bird.frame.LookVector
	local target = CFrame.lookAt(position, position + Vector3.new(look.X, 0, look.Z))
	bird.mode = "landing"
	bird.from = bird.frame
	bird.target = target
	bird.elapsed = 0
	bird.duration = random:NextNumber(2, 3)
	bird.perch = surface
	bird.perchLocal = surface.CFrame:ToObjectSpace(target)
end

local heartbeat = RunService.Heartbeat:Connect(function(dt: number)
	frameElapsed += dt
	local quality = EffectSettings.quality()
	local interval = if quality == "low" then 1 / 20 else 1 / 30
	if frameElapsed < interval then
		return
	end
	dt = math.min(frameElapsed, 0.15)
	frameElapsed = 0
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPos = camera.CFrame.Position
	local now = os.clock()
	local reduced = EffectSettings.reducedMotion()
	local weather = Environment.getWeather().id
	local night = Environment.getNightFactor(Environment.getClockTime()) > 0.7
	playerElapsed += dt
	if playerElapsed >= PLAYER_CHECK_INTERVAL then
		playerElapsed = 0
		updatePlayers()
	end
	landingElapsed += dt
	local mayLand = landingElapsed >= LAND_CHECK_INTERVAL and weather ~= "storm" and weather ~= "snow" and not night
	if mayLand then
		landingElapsed = 0
	end
	-- Kötü havada sürülerin çoğu görünmez
	local activeCount = if weather == "storm"
		then 2
		elseif weather == "snow" or weather == "rain" then 5
		else FLOCK_COUNT

	for index, flock in flocks do
		local qualityCount = if quality == "low" then 2 elseif quality == "high" then FLOCK_COUNT else 5
		local active = index <= math.min(activeCount, qualityCount)
			and not night
			and not reduced
			and (flock.center - Vector3.new(cameraPos.X, 0, cameraPos.Z)).Magnitude <= UPDATE_DISTANCE
		setVisible(flock, active)
		if not active then
			for _, bird in flock.birds do
				bird.mode = "flight"
				bird.perch = nil
				bird.perchLocal = nil
			end
			continue
		end

		flock.angle += flock.speed * dt
		local direction = math.sign(flock.speed)
		local position = flock.center
			+ Vector3.new(math.cos(flock.angle) * flock.radius, flock.height, math.sin(flock.angle) * flock.radius)
		local tangent = Vector3.new(-math.sin(flock.angle), 0, math.cos(flock.angle)) * direction
		-- Dönüşe doğru hafif yatış
		local base = CFrame.lookAt(position, position + tangent) * CFrame.Angles(0, 0, direction * 0.25)

		for _, bird in flock.birds do
			local bob = math.sin(now * 0.8 + bird.phase) * 0.8
			local cf = base * CFrame.new(bird.offset + Vector3.new(0, bob, 0))
			if bird.mode == "flight" then
				bird.frame = cf
				if mayLand and now >= bird.nextLanding then
					mayLand = false
					tryLanding(bird, now)
				end
			else
				bird.elapsed += dt
				local perch, perchLocal = bird.perch, bird.perchLocal
				if bird.mode == "landing" or bird.mode == "perched" then
					local threat = threatAt(bird.target.Position)
					if
						threat
						or not perch
						or not perch:IsDescendantOf(Workspace)
						or not perchLocal
						or not perch.CanCollide
						or perch.Transparency >= 0.9
					then
						takeOff(bird, threat)
					else
						bird.target = perch.CFrame * perchLocal
					end
				end
				if bird.mode == "landing" then
					cf = bird.from:Lerp(bird.target, BirdBehavior.progress(bird.elapsed, bird.duration))
					if bird.elapsed >= bird.duration then
						bird.mode = "perched"
						bird.elapsed = 0
						bird.duration = random:NextNumber(7, 16)
					end
				elseif bird.mode == "perched" then
					cf = bird.target * CFrame.new(0, math.max(0, math.sin(now * 2 + bird.phase)) * 0.04, 0)
					if bird.elapsed >= bird.duration then
						takeOff(bird, nil)
					end
				elseif bird.mode == "leaving" then
					cf = bird.from:Lerp(bird.target, BirdBehavior.progress(bird.elapsed, bird.duration))
					if bird.elapsed >= bird.duration then
						bird.mode = "returning"
						bird.from = cf
						bird.elapsed = 0
						bird.duration = 3
					end
				elseif bird.mode == "returning" then
					cf = bird.from:Lerp(cf, BirdBehavior.progress(bird.elapsed, bird.duration))
					if bird.elapsed >= bird.duration then
						bird.mode = "flight"
					end
				end
			end
			bird.frame = cf
			bird.model:PivotTo(cf)
			-- Çırp–süzül döngüsü: bir süre çırpar, bir süre kanatlar açık süzülür
			local gliding = math.sin(now * 0.5 + bird.phase) > 0.3
			local flap = if gliding and bird.mode == "flight"
				then 0.1
				else math.sin(now * bird.flapSpeed + bird.phase) * 0.6
			local half = bird.leftWing.Size.X / 2
			if bird.mode == "perched" then
				local side = bird.body.Size.X * 0.5
				bird.leftWing.CFrame = cf
					* CFrame.new(-side, 0, 0)
					* CFrame.Angles(0, math.pi / 2, 0)
					* CFrame.new(-half, 0, -0.1)
				bird.rightWing.CFrame = cf
					* CFrame.new(side, 0, 0)
					* CFrame.Angles(0, -math.pi / 2, 0)
					* CFrame.new(half, 0, -0.1)
			else
				bird.leftWing.CFrame = cf * CFrame.Angles(0, 0, flap) * CFrame.new(-half, 0, 0.1)
				bird.rightWing.CFrame = cf * CFrame.Angles(0, 0, -flap) * CFrame.new(half, 0, 0.1)
			end
		end
	end
end)

local destroying: RBXScriptConnection? = nil
destroying = script.Destroying:Connect(function()
	heartbeat:Disconnect()
	if destroying then
		destroying:Disconnect()
	end
	table.clear(nearbyPlayers)
	table.clear(flocks)
	folder:Destroy()
end)
