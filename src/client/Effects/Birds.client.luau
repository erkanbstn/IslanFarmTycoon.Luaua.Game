--!strict
-- Gökyüzünde süzülen kuş sürüleri: martılar denizin üstünde, küçük kuşlar adaların üstünde.
-- Kanat çırpar, arada süzülür. Sadece görsel, sadece bu oyuncunun ekranında; uzaktakiler güncellenmez.
-- Fırtınada ve karda kuşlar azalır (sığınırlar).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EffectSettings = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("EffectSettings"))
local ClientModelAssets = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientModelAssets"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local StartupGate = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("StartupGate"))
StartupGate.wait(1.5)

local FLOCK_COUNT = 10
local UPDATE_DISTANCE = 320
local MAP_RADIUS = 380

type Bird = {
	model: Model,
	parts: { BasePart },
	body: BasePart,
	leftWing: BasePart,
	rightWing: BasePart,
	offset: Vector3,
	phase: number,
	flapSpeed: number,
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

-- Kuş modeli: client-assets/Birds/Gull | Songbird (Body, LeftWing, RightWing, Head, Beak, Tail); boyut/renk modelden gelir.
-- Hareket kodda: gövde modelle birlikte taşınır, kanatlar ayrıca çırpılır.
local missingWarned = false
local function makeBird(gull: boolean): Bird?
	local model = ClientModelAssets.clone("Birds", if gull then "Gull" else "Songbird")
	local body = if model then model:FindFirstChild("Body") else nil
	local leftWing = if model then model:FindFirstChild("LeftWing") else nil
	local rightWing = if model then model:FindFirstChild("RightWing") else nil
	if not (model and body and leftWing and rightWing) then
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
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			table.insert(parts, descendant)
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

RunService.Heartbeat:Connect(function(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPos = camera.CFrame.Position
	local now = os.clock()
	local weather = Environment.getWeather().id
	-- Kötü havada sürülerin çoğu görünmez
	local activeCount = if weather == "storm"
		then 2
		elseif weather == "snow" or weather == "rain" then 5
		else FLOCK_COUNT

	for index, flock in flocks do
		local quality = EffectSettings.quality()
		local qualityCount = if quality == "low" then 2 elseif quality == "high" then FLOCK_COUNT else 5
		local active = index <= math.min(activeCount, qualityCount)
			and not EffectSettings.reducedMotion()
			and (flock.center - Vector3.new(cameraPos.X, 0, cameraPos.Z)).Magnitude <= UPDATE_DISTANCE
		setVisible(flock, active)
		if not active or (flock.center - Vector3.new(cameraPos.X, 0, cameraPos.Z)).Magnitude > UPDATE_DISTANCE then
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
			bird.model:PivotTo(cf)
			-- Çırp–süzül döngüsü: bir süre çırpar, bir süre kanatlar açık süzülür
			local gliding = math.sin(now * 0.5 + bird.phase) > 0.3
			local flap = if gliding then 0.1 else math.sin(now * bird.flapSpeed + bird.phase) * 0.6
			local half = bird.leftWing.Size.X / 2
			bird.leftWing.CFrame = cf * CFrame.Angles(0, 0, flap) * CFrame.new(-half, 0, 0.1)
			bird.rightWing.CFrame = cf * CFrame.Angles(0, 0, -flap) * CFrame.new(half, 0, 0.1)
		end
	end
end)
