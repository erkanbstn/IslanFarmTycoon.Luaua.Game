--!strict
-- Yeni modelleri küçükten büyütür. Animator, BuildPopActive boyunca pivotu değiştirmez.
-- Yeniden stream edilen eski modeller oynatılmaz; parıltılar sabit bir geometri havuzudur.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))
local EffectSettings = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("EffectSettings"))
local Sfx = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Sfx"))
local localPlayer = Players.LocalPlayer
local POP_TIME = 0.5
local FRESH_SECONDS = 3
local MAX_POPS = 8
local MAX_SPARKLES = 60
local MAX_DUST = 36
local DUST_LIFE = 0.9

type Pop = { scale: number, pivot: CFrame, changedPivot: boolean, started: number, watch: RBXScriptConnection? }
type Candidate = { stableFrames: number, expiresAt: number, connections: { RBXScriptConnection } }
type Spark = { part: BasePart, origin: Vector3, velocity: Vector3, born: number, life: number }
type Dust = { part: BasePart, origin: Vector3, velocity: Vector3, born: number, startSize: number }
local pops: { [Model]: Pop } = {}
local candidates: { [Model]: Candidate } = {}
local played: { [Model]: boolean } = setmetatable({}, { __mode = "k" })
local activePops = 0
local random = Random.new()
local sparkleFolder = Instance.new("Folder")
sparkleFolder.Name = "BuildSparkles"
sparkleFolder.Parent = Workspace
local sparks: { Spark } = {}
for _ = 1, MAX_SPARKLES do
	local part = Instance.new("Part")
	part.Name = "Spark"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * 0.22
	part.Color = UiTheme.Color.Gold
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = sparkleFolder
	table.insert(sparks, { part = part, origin = Vector3.zero, velocity = Vector3.zero, born = -math.huge, life = 0 })
end

local dustFolder = Instance.new("Folder")
dustFolder.Name = "BuildDust"
dustFolder.Parent = Workspace
local dustPuffs: { Dust } = {}
for _ = 1, MAX_DUST do
	local part = Instance.new("Part")
	part.Name = "Dust"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one
	part.Color = Color3.fromRGB(214, 200, 176)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = dustFolder
	table.insert(
		dustPuffs,
		{ part = part, origin = Vector3.zero, velocity = Vector3.zero, born = -math.huge, startSize = 1 }
	)
end

-- Kurulum tozu: yapının zeminine halka biçiminde yayılıp sönen toz bulutları
local function dustRing(position: Vector3, radius: number)
	local quality = localPlayer:GetAttribute("EffectsQuality")
	local count = if quality == "low" then 6 elseif quality == "high" then 18 else 12
	local now = os.clock()
	local slot = 0
	for _, puff in dustPuffs do
		if now - puff.born < DUST_LIFE then
			continue
		end
		local angle = slot / count * math.pi * 2 + random:NextNumber(-0.2, 0.2)
		slot += 1
		local speed = math.clamp(radius, 2, 10) * random:NextNumber(0.9, 1.5)
		puff.origin = position + Vector3.new(math.cos(angle) * radius * 0.5, 0.4, math.sin(angle) * radius * 0.5)
		puff.velocity = Vector3.new(math.cos(angle) * speed, random:NextNumber(0.8, 2), math.sin(angle) * speed) * 0.7
		puff.born = now
		puff.startSize = random:NextNumber(0.9, 1.6)
		puff.part.Size = Vector3.one * puff.startSize
		puff.part.CFrame = CFrame.new(puff.origin)
		puff.part.Transparency = 0.35
		if slot >= count then
			break
		end
	end
end

local function sparkle(position: Vector3, size: number)
	local quality = localPlayer:GetAttribute("EffectsQuality")
	local count = if quality == "low" then 6 elseif quality == "high" then 20 else 12
	local speed = math.clamp(size, 3, 12)
	local now = os.clock()
	for _, spark in sparks do
		if now - spark.born < spark.life then
			continue
		end
		local angle = random:NextNumber(0, math.pi * 2)
		spark.origin, spark.born, spark.life = position, now, random:NextNumber(0.5, 0.85)
		spark.velocity = Vector3.new(math.cos(angle) * speed, random:NextNumber(2, 6), math.sin(angle) * speed)
		spark.part.CFrame = CFrame.new(position)
		spark.part.Transparency = 0
		count -= 1
		if count <= 0 then
			break
		end
	end
end

local function finishPop(model: Model)
	local pop = pops[model]
	if not pop then
		return
	end
	pops[model] = nil
	activePops -= 1
	if pop.watch then
		pop.watch:Disconnect()
	end
	-- Model stream-out sırasında da eski ölçeğine dönsün; sonraki stream-in küçülmüş başlamasın.
	pcall(function()
		model:ScaleTo(pop.scale)
		if pop.changedPivot then
			model.WorldPivot = pop.pivot
		end
	end)
	model:SetAttribute("BuildPopActive", nil)
end

local quietUntil = 0
local lastFarmId: unknown = localPlayer:GetAttribute("ActiveMainFarmId")
localPlayer:GetAttributeChangedSignal("ActiveMainFarmId"):Connect(function()
	local current = localPlayer:GetAttribute("ActiveMainFarmId")
	if lastFarmId ~= nil and current ~= lastFarmId then
		quietUntil = os.clock() + 10
	end
	lastFarmId = current
end)

local function popIn(model: Model): boolean
	if activePops >= MAX_POPS or pops[model] then
		return false
	end
	if
		localPlayer:GetAttribute("WorldReady") ~= true
		or localPlayer:GetAttribute("ClientStateReady") ~= true
		or localPlayer:GetAttribute("ReducedMotion") == true
	then
		return false
	end
	local created = model:GetAttribute("VisualCreatedAt")
	if typeof(created) ~= "number" or Workspace:GetServerTimeNow() - created > FRESH_SECONDS then
		return false
	end
	if not model:IsDescendantOf(Workspace) or not model:FindFirstChildWhichIsA("BasePart", true) then
		return false
	end
	-- ScaleTo, sonradan gelen (henüz çoğalmamış) parçaları yanlış ölçekler; dev hayvanların nedeni buydu.
	-- Sunucu parça sayısını yazar; model tamamen gelmeden efekt başlamaz, sayı yoksa efekt oynatılmaz.
	local expected = model:GetAttribute("PartCount")
	if typeof(expected) ~= "number" then
		return false
	end
	local parts = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			parts += 1
		end
	end
	if parts ~= expected then
		return false
	end
	local camera = Workspace.CurrentCamera
	if not camera or (model:GetPivot().Position - camera.CFrame.Position).Magnitude > 100 then
		return false
	end
	local plot: Instance? = model.Parent
	while plot and (not plot.Parent or plot.Parent.Name ~= "Plots") do
		plot = plot.Parent
	end
	if not plot or plot:GetAttribute("OwnerUserId") ~= localPlayer.UserId then
		return false
	end

	local boxCf, boxSize = model:GetBoundingBox()
	local pop: Pop = {
		scale = model:GetScale(),
		pivot = model:GetPivot(),
		changedPivot = model.PrimaryPart == nil and model:GetAttribute("Uid") == nil,
		started = os.clock(),
	}
	pops[model] = pop
	activePops += 1
	pop.watch = model.DescendantAdded:Connect(function(added: Instance)
		if added:IsA("BasePart") then
			finishPop(model)
		end
	end)
	model:SetAttribute("BuildPopActive", true)
	local ok = pcall(function()
		if pop.changedPivot then
			model.WorldPivot = CFrame.new(boxCf.Position - Vector3.new(0, boxSize.Y / 2, 0))
		end
		model:ScaleTo(pop.scale * 0.05)
	end)
	if not ok then
		finishPop(model)
		return false
	end
	local radius = math.max(boxSize.X, boxSize.Z) / 2
	sparkle(boxCf.Position, radius)
	-- Hayvanlar küçük bir toz alır; binalar ve dekor tam kurulum tozu + kutlama sesi
	local isAnimal = model.Parent ~= nil and model.Parent.Name == "Animals"
	dustRing(boxCf.Position - Vector3.new(0, boxSize.Y / 2, 0), if isAnimal then math.min(radius, 2.5) else radius)
	-- Kutlama sesi yalnızca girişte/yapı alımında; çiftlik (ada teması) değişince yeniden kurulan adada çalmaz
	if not isAnimal and os.clock() >= quietUntil then
		Sfx.play("build")
	end
	return true
end

local function removeCandidate(model: Model)
	local candidate = candidates[model]
	if not candidate then
		return
	end
	for _, connection in candidate.connections do
		connection:Disconnect()
	end
	candidates[model] = nil
end

local function discover(instance: Instance)
	if not instance:IsA("Model") or candidates[instance] or played[instance] then
		return
	end
	local parent = instance.Parent
	if
		not parent
		or not (
			parent.Name == "Animals"
			or parent.Name == "Upgrades"
			or instance.Name == "Decor"
			or instance.Name == "Barn"
		)
	then
		return
	end
	local candidate: Candidate = { stableFrames = 0, expiresAt = os.clock() + FRESH_SECONDS, connections = {} }
	candidates[instance] = candidate
	local function changed()
		candidate.stableFrames = 0
	end
	candidate.connections = { instance.AttributeChanged:Connect(changed), instance.DescendantAdded:Connect(changed) }
	-- DescendantAdded toplu çoğalmanın ortasında gelebilir; en az sonraki turu bekle.
	task.defer(changed)
end
local connections: { RBXScriptConnection } = {}
table.insert(connections, Workspace.DescendantAdded:Connect(discover))
table.insert(
	connections,
	Workspace.DescendantRemoving:Connect(function(instance: Instance)
		if not instance:IsA("Model") then
			return
		end
		removeCandidate(instance)
		finishPop(instance)
		played[instance] = nil
	end)
)
for _, instance in Workspace:GetDescendants() do
	discover(instance)
end

table.insert(
	connections,
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local reduced = EffectSettings.reducedMotion()
		for model, candidate in candidates do
			if now >= candidate.expiresAt or not model:IsDescendantOf(Workspace) then
				removeCandidate(model)
				continue
			end
			candidate.stableFrames += 1
			if candidate.stableFrames >= 2 and popIn(model) then
				-- Yalnızca gerçekten başlayan efekt tüketilir; kamera/hazırlık bekleyenler tekrar denenir.
				played[model] = true
				removeCandidate(model)
			end
		end
		for model, pop in pops do
			local t = math.min((now - pop.started) / POP_TIME, 1)
			if reduced or t >= 1 or not model:IsDescendantOf(Workspace) then
				finishPop(model)
				continue
			end
			local eased = TweenService:GetValue(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			local ok = pcall(function()
				model:ScaleTo(pop.scale * math.max(eased, 0.05))
			end)
			if not ok then
				finishPop(model)
			end
		end
		for _, puff in dustPuffs do
			local age = now - puff.born
			if reduced or age >= DUST_LIFE then
				if puff.part.Transparency ~= 1 then
					puff.part.Transparency = 1
				end
				continue
			end
			local t = age / DUST_LIFE
			puff.part.Size = Vector3.one * (puff.startSize * (1 + t * 2.2))
			puff.part.CFrame = CFrame.new(puff.origin + puff.velocity * age * (1 - t * 0.5))
			puff.part.Transparency = 0.35 + t * 0.65
		end
		for _, spark in sparks do
			local age = now - spark.born
			if reduced or age >= spark.life then
				if spark.part.Transparency ~= 1 then
					spark.part.Transparency = 1
				end
				if reduced then
					spark.life = 0
				end
				continue
			end
			local position = spark.origin + spark.velocity * age + Vector3.new(0, -6 * age * age, 0)
			spark.part.CFrame = CFrame.new(position)
			spark.part.Transparency = math.clamp(age / spark.life, 0, 1)
		end
	end)
)
script.Destroying:Connect(function()
	for _, connection in connections do
		connection:Disconnect()
	end
	for model in candidates do
		removeCandidate(model)
	end
	for model in pops do
		finishPop(model)
	end
	sparkleFolder:Destroy()
	dustFolder:Destroy()
end)
