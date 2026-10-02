--!strict
-- Mevsim ilerlemesine bağlı, yalnızca yerel bitki örtüsü ve küçük parçacıklar.
-- Dünya bir kez taranır; streaming olayları kayıtları günceller. Havuzlar sabit üst sınırlıdır.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local SeasonVisuals = require(Shared:WaitForChild("Modules"):WaitForChild("SeasonVisuals"))
local player = Players.LocalPlayer
local SeasonalScenery = {}
local started = false
local SNOW = Color3.fromRGB(238, 243, 247)
local PETAL = Color3.fromRGB(255, 198, 219)
local AUTUMN = { Color3.fromRGB(207, 104, 37), Color3.fromRGB(179, 68, 40), Color3.fromRGB(224, 163, 47) }
local TRANSITION = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local MAX_FRAGMENTS = 36
local MAX_BRANCH_TREES = 12
local BRANCHES_PER_TREE = 4

type Source = {
	part: BasePart,
	kind: string,
	color: Color3,
	material: Enum.Material,
	modifier: number,
	size: Vector3,
	phase: number,
	tween: Tween?,
	targetColor: Color3?,
	targetModifier: number?,
	targetSize: Vector3?,
	connections: { RBXScriptConnection },
}
type Fragment = { part: BasePart, born: number, life: number, start: Vector3, drift: Vector3, phase: number }

local function stablePhase(position: Vector3): number
	return math.abs(math.sin(position.X * 1.73 + position.Y * 5.19 + position.Z * 3.11))
end

function SeasonalScenery.start(): () -> ()
	if started then
		return function() end
	end
	started = true
	local active = true
	local sources: { [BasePart]: Source } = {}
	local trunks: { [BasePart]: boolean } = {}
	local emitters: { Source } = {}
	local fragments: { Fragment } = {}
	local branches: { BasePart } = {}
	local connections: { RBXScriptConnection } = {}
	local random = Random.new()
	local folder = Instance.new("Folder")
	folder.Name = "SeasonalScenery"
	folder.Parent = Workspace
	local function cosmetic(name: string): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = 1
		part.Parent = folder
		return part
	end
	for _ = 1, MAX_FRAGMENTS do
		local part = cosmetic("SeasonFragment")
		part.Size = Vector3.new(0.22, 0.04, 0.42)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
		table.insert(
			fragments,
			{ part = part, born = -math.huge, life = 0, start = Vector3.zero, drift = Vector3.zero, phase = 0 }
		)
	end
	for _ = 1, MAX_BRANCH_TREES * BRANCHES_PER_TREE do
		local part = cosmetic("WinterTwig")
		part.Material = Enum.Material.Wood
		table.insert(branches, part)
	end

	local function apply(source: Source, color: Color3, modifier: number, size: Vector3?)
		local part = source.part
		-- Çok küçük adımlar için aynı renge yeniden tween oluşturma.
		color = Color3.fromRGB(math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255))
		local reduced = player:GetAttribute("ReducedMotion") == true
		if
			source.targetColor == color
			and source.targetModifier == modifier
			and source.targetSize == size
			and not (reduced and source.tween)
		then
			return
		end
		source.targetColor, source.targetModifier, source.targetSize = color, modifier, size
		if source.tween then
			source.tween:Cancel()
			source.tween = nil
		end
		-- Görünür küme kendi özgün opaklığını korur; dökülen küme anında tamamen gizlenir.
		-- Saydamlık tween'i özellikle çalılarda cam/hayalet görünümü oluşturur.
		part.LocalTransparencyModifier = modifier
		if reduced then
			part.Color = color
			if size then
				part.Size = size
			end
		else
			local goal: { [string]: any } = { Color = color }
			if size then
				goal.Size = size
			end
			local tween = TweenService:Create(part, TRANSITION, goal)
			source.tween = tween
			tween:Play()
		end
	end

	local currentSeason = Environment.getSeason().id
	local currentSample = SeasonVisuals.sample(currentSeason, Environment.getSeasonProgress())
	local function refresh()
		if not active then
			return
		end
		currentSeason = Environment.getSeason().id
		currentSample = SeasonVisuals.sample(currentSeason, Environment.getSeasonProgress())
		local sample = currentSample
		local camera = Workspace.CurrentCamera
		local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
		table.clear(emitters)
		for part, source in sources do
			local color = source.color
			local visible = true
			local size: Vector3? = nil
			if source.kind == "snowprop" then
				-- Parçanın kendi Transparency'si sunucuda 1'dir; karlı mevsimde 0 olur, yaprak dökülmeden önce görünmez
				part.Transparency = if sample.snow >= 0.45 then 0 else 1
				continue
			elseif source.kind == "snowcapDeciduous" then
				part.Transparency = if sample.snow >= 0.45 and sample.foliage >= 0.5 then 0 else 1
				continue
			end
			if source.kind == "ground" or source.kind == "zoneground" then
				if part:GetAttribute("Locked") == true then
					if source.tween then
						source.tween:Cancel()
						source.tween = nil
					end
					source.targetColor = nil
					continue
				end
				local original = part:GetAttribute("OpenColor")
				if typeof(original) == "Color3" then
					color = original
				end
				local warmth = sample.autumn * (1 - sample.snow)
				color = color:Lerp(Color3.fromRGB(165, 146, 80), warmth * 0.45):Lerp(SNOW, sample.snow * 0.94)
				part.Material = if sample.snow > 0.35
					then Enum.Material.Snow
					elseif source.kind == "zoneground" then source.material
					else Enum.Material.Grass
			elseif source.kind == "evergreen" then
				color = color:Lerp(SNOW, sample.snow * 0.65)
			elseif source.kind == "flower" then
				visible = sample.foliage * (1 - sample.snow) >= 0.2 + source.phase * 0.6
			elseif source.kind == "berry" then
				visible = sample.foliage >= 0.45 + source.phase * 0.3
			else
				-- Kümeler farklı sırada dökülür; ilkbaharda aynı dallarda geri çıkar.
				if source.kind == "bush" then
					-- Kışın yatayda daralan opak çalı; özgün yükseklik tabanı yerde tutar.
					local scale = 0.55 + 0.45 * math.clamp(sample.foliage, 0, 1)
					local horizontalScale = math.clamp(math.round(scale * 128) / 128, 0.55, 1)
					size = Vector3.new(source.size.X * horizontalScale, source.size.Y, source.size.Z * horizontalScale)
				else
					visible = sample.foliage >= 0.08 + source.phase * 0.84
				end
				local autumnColor = AUTUMN[math.floor(source.phase * #AUTUMN) % #AUTUMN + 1]
				color = color:Lerp(autumnColor, sample.autumn * 0.88)
				if source.kind == "deciduous" then
					color = color:Lerp(PETAL, sample.bloom * 0.38)
					if camera and (part.Position - cameraPosition).Magnitude < 100 then
						table.insert(emitters, source)
					end
				else
					color = color:Lerp(SNOW, sample.snow * 0.78)
				end
			end
			apply(source, color, if visible then source.modifier else 1, size)
		end
		-- Çıplak ağaçların yakın plandaki ince dalları: en fazla 12 ağaç / 48 parça.
		local nearest: { BasePart } = {}
		if camera and sample.foliage < 0.7 then
			for trunk in trunks do
				if (trunk.Position - cameraPosition).Magnitude < 130 then
					table.insert(nearest, trunk)
				end
			end
			table.sort(nearest, function(a, b)
				return (a.Position - cameraPosition).Magnitude < (b.Position - cameraPosition).Magnitude
			end)
		end
		local quality = player:GetAttribute("EffectsQuality")
		local treeBudget = if quality == "low" then 4 elseif quality == "high" then MAX_BRANCH_TREES else 8
		for index, branch in branches do
			local treeIndex = math.ceil(index / BRANCHES_PER_TREE)
			local trunk = if treeIndex <= treeBudget then nearest[treeIndex] else nil
			if not trunk then
				branch.Transparency = 1
				continue
			end
			local twigIndex = (index - 1) % BRANCHES_PER_TREE + 1
			local height = math.max(trunk.Size.X, trunk.Size.Y, trunk.Size.Z)
			local angle = twigIndex / BRANCHES_PER_TREE * math.pi * 2 + stablePhase(trunk.Position) * 6
			local origin = trunk.Position + Vector3.new(0, height * 0.35, 0)
			local tip = origin
				+ Vector3.new(
					math.cos(angle) * height * 0.42,
					height * (0.26 + twigIndex * 0.035),
					math.sin(angle) * height * 0.42
				)
			branch.Size = Vector3.new(0.22, (tip - origin).Magnitude, 0.22)
			branch.CFrame = CFrame.lookAt((origin + tip) / 2, tip) * CFrame.Angles(math.pi / 2, 0, 0)
			branch.Color = trunk.Color:Lerp(SNOW, sample.snow * 0.4)
			branch.Transparency = if sample.foliage < 0.15 + twigIndex / BRANCHES_PER_TREE * 0.5 then 0 else 1
		end
	end

	local scheduled = false
	local function scheduleRefresh()
		if scheduled or not active then
			return
		end
		scheduled = true
		task.defer(function()
			scheduled = false
			refresh()
		end)
	end
	local function discover(instance: Instance)
		if not instance:IsA("BasePart") or sources[instance] then
			return
		end
		local parent = instance.Parent
		if not parent then
			return
		end
		if instance.Name == "Trunk" and (parent.Name == "OakTree" or parent.Name == "BirchTree") then
			trunks[instance] = true
			scheduleRefresh()
			return
		end
		local kind: string? = nil
		if parent.Name == "SnowCap" or parent.Name == "Snowman" then
			-- Kar başlığı ve kardan adam (SeasonModels): sunucu gizli kurar, karlı mevsimde burada açılır.
			-- Meşe/huş başlığı yalnızca yapraklar yerindeyse açılır (yaprak dökülünce havada kalan taç karı olmaz).
			local tree = parent.Parent
			kind = if parent.Name == "SnowCap"
					and tree
					and (tree.Name == "OakTree" or tree.Name == "BirchTree")
				then "snowcapDeciduous"
				else "snowprop"
		elseif instance.Name == "PlotBase" or instance.Name == "IslandBase" then
			kind = "ground"
		elseif
			instance.Name == "Ground"
			and instance.Transparency < 1
			and parent.Parent ~= nil
			and parent.Parent.Name == "Zones"
			and (
				instance.Material == Enum.Material.Grass
				or instance.Material == Enum.Material.Sand
				or instance.Material == Enum.Material.Ground
			)
		then
			-- Bölge zeminleri (küçük adalarda yüzeyin çoğunu kaplar) ada tabanıyla birlikte karlanır.
			kind = "zoneground"
		elseif instance.Name == "Needles" and parent.Name == "PineTree" then
			kind = "evergreen"
		elseif
			(
				instance.Name == "Leaves"
				and (parent.Name == "OakTree" or parent.Name == "BirchTree" or parent.Name == "Orchard")
			)
			-- kiraz anıtı: çiçekler yaprak gibi dökülür/geri gelir
			or (
				(instance.Name == "Blossom" or instance.Name == "Petals")
				and parent.Name == "Landmark"
				and parent:GetAttribute("Kind") == "cherry"
			)
		then
			kind = "deciduous"
		elseif instance.Name == "Leaves" and parent.Name == "Bush" then
			kind = "bush"
		elseif
			(instance.Name == "Berry" and parent.Name == "Bush") -- çalı meyvesi
			or (instance.Name == "Fruit" and parent.Name == "Orchard") -- meyve bahçesi
		then
			kind = "berry"
		elseif (instance.Name == "Bloom" or instance.Name == "Stem") and parent.Name == "Flowers" then
			kind = "flower"
		end
		if not kind then
			return
		end
		local source: Source = {
			part = instance,
			kind = kind,
			color = instance.Color,
			material = instance.Material,
			modifier = instance.LocalTransparencyModifier,
			size = instance.Size,
			-- Aynı çiçeğin sapı ve başı aynı X/Z'dedir; birlikte kaybolup geri gelmelidir.
			phase = stablePhase(
				if kind == "flower" then Vector3.new(instance.Position.X, 0, instance.Position.Z) else instance.Position
			),
			tween = nil,
			targetColor = nil,
			targetModifier = nil,
			targetSize = nil,
			connections = {},
		}
		if kind == "ground" then
			table.insert(source.connections, instance:GetAttributeChangedSignal("Locked"):Connect(scheduleRefresh))
			table.insert(source.connections, instance:GetAttributeChangedSignal("OpenColor"):Connect(scheduleRefresh))
		end
		sources[instance] = source
		scheduleRefresh()
	end
	local function remove(instance: Instance)
		if not instance:IsA("BasePart") then
			return
		end
		local wasTrunk = trunks[instance]
		trunks[instance] = nil
		local source = sources[instance]
		if not source then
			if wasTrunk then
				scheduleRefresh()
			end
			return
		end
		if source.tween then
			source.tween:Cancel()
		end
		for _, connection in source.connections do
			connection:Disconnect()
		end
		instance.LocalTransparencyModifier = source.modifier
		if source.kind == "bush" then
			instance.Size = source.size
		end
		-- Aynı Instance geri stream edilirse client'ın son rengi 'orijinal' sanılmasın.
		if source.kind ~= "ground" then
			instance.Color = source.color
			instance.Material = source.material
		elseif instance:GetAttribute("Locked") ~= true then
			local original = instance:GetAttribute("OpenColor")
			instance.Color = if typeof(original) == "Color3" then original else source.color
			instance.Material = Enum.Material.Grass
		end
		sources[instance] = nil
		scheduleRefresh()
	end
	table.insert(connections, Workspace.DescendantAdded:Connect(discover))
	table.insert(connections, Workspace.DescendantRemoving:Connect(remove))
	table.insert(connections, player:GetAttributeChangedSignal("EffectsQuality"):Connect(scheduleRefresh))
	table.insert(connections, player:GetAttributeChangedSignal("ReducedMotion"):Connect(scheduleRefresh))
	for _, instance in Workspace:GetDescendants() do
		discover(instance)
	end

	local refreshElapsed, animationElapsed, emission = 0, 0, 0
	local hasFragments = false
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			refreshElapsed += dt
			if refreshElapsed >= 1 then
				refreshElapsed = 0
				refresh()
			end
			animationElapsed += dt
			if animationElapsed < 1 / 30 then
				return
			end
			dt = math.min(animationElapsed, 0.1)
			animationElapsed = 0
			local quality = player:GetAttribute("EffectsQuality")
			local budget = if quality == "low" then 6 elseif quality == "high" then MAX_FRAGMENTS else 18
			local reduced = player:GetAttribute("ReducedMotion") == true
			local season = currentSeason
			local sample = currentSample
			local intensity = if season == "autumn" then sample.autumn * sample.foliage else sample.bloom
			local now = os.clock()
			emission += dt * intensity * (if quality == "low" then 1 elseif quality == "high" then 6 else 3)
			if reduced or not Workspace.CurrentCamera then
				emission = 0
				if hasFragments then
					for _, fragment in fragments do
						fragment.part.Transparency = 1
						fragment.life = 0
					end
					hasFragments = false
				end
				return
			end
			if intensity <= 0 and not hasFragments then
				emission = 0
				return
			end
			hasFragments = false
			for index, fragment in fragments do
				if reduced or index > budget then
					fragment.part.Transparency = 1
					fragment.life = 0
					continue
				end
				local age = now - fragment.born
				if age >= fragment.life then
					fragment.part.Transparency = 1
					if emission < 1 or #emitters == 0 then
						continue
					end
					local source = emitters[random:NextInteger(1, #emitters)]
					if not source.part:IsDescendantOf(Workspace) then
						continue
					end
					emission -= 1
					fragment.born, fragment.life = now, random:NextNumber(3, 5)
					fragment.start = source.part.Position
						+ Vector3.new(random:NextNumber(-2, 2), 0, random:NextNumber(-2, 2))
					fragment.drift = Vector3.new(
						random:NextNumber(-0.8, 1.5),
						-random:NextNumber(1.5, 2.1),
						random:NextNumber(-0.6, 0.6)
					)
					fragment.phase = random:NextNumber(0, math.pi * 2)
					fragment.part.Color = if season == "autumn" then AUTUMN[random:NextInteger(1, #AUTUMN)] else PETAL
					age = 0
				end
				local camera = Workspace.CurrentCamera
				if not camera or (fragment.start - camera.CFrame.Position).Magnitude > 130 then
					fragment.life = 0
					fragment.part.Transparency = 1
					continue
				end
				local position = fragment.start
					+ fragment.drift * age
					+ Vector3.new(math.sin(age * 2 + fragment.phase) * 0.6, 0, math.cos(age + fragment.phase) * 0.4)
				fragment.part.CFrame = CFrame.new(position)
					* CFrame.Angles(
						math.sin(age * 3 + fragment.phase) * 0.6,
						age + fragment.phase,
						math.cos(age * 2) * 0.5
					)
				fragment.part.Transparency = math.clamp((age / fragment.life - 0.7) / 0.3, 0, 1)
				hasFragments = true
			end
			emission = math.min(emission, 2)
		end)
	)
	refresh()
	return function()
		if not active then
			return
		end
		active = false
		started = false
		for _, connection in connections do
			connection:Disconnect()
		end
		for part in sources do
			remove(part)
		end
		folder:Destroy()
	end
end

return SeasonalScenery
