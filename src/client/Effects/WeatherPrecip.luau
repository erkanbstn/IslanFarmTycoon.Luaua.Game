--!strict
-- Yerel yağış ve uzaktaki şimşek. Dokular Roblox Player/Studio ile gelir;
-- asset yükleme izni veya harici ağ isteği gerekmez.
-- Yağış bütün haritada görünür: kameranın etrafında üç halka vardır. Yakın halka kameraya yakın küçük bir hacim (çatı/içeri
-- denetimli); orta ve uzak halka kameranın XZ'sinde duran, harita üstünde ince bir "tavan" levhasından yağar (tane boyutu
-- uzaklıkla büyür). Taneler yere ulaşınca yaşam süresiyle biter. Parçacık sayısı kaliteyle ölçeklenir (düşükte uzak halka yok).
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Environment =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Environment"))

local WeatherPrecip = {}
-- Player/Studio içeriğinde doğrulanmış 64px daire, 44 alfa seviyesi ve şeffaf köşeler.
-- İki yağış da yuvarlaktır; yağmur daha küçük ve çok daha hızlı düşer.
local RAIN_TEXTURE = "rbxasset://textures/smallWhiteCircle.png"
local SNOW_TEXTURE = "rbxasset://textures/smallWhiteCircle.png"
type Budget = { rain: number, storm: number, snow: number }
local QUALITY: { [string]: { near: Budget, mid: Budget, far: Budget } } = {
	low = {
		near = { rain = 70, storm = 95, snow = 22 },
		mid = { rain = 80, storm = 110, snow = 28 },
		far = { rain = 0, storm = 0, snow = 0 },
	},
	medium = {
		near = { rain = 160, storm = 230, snow = 45 },
		mid = { rain = 140, storm = 200, snow = 50 },
		far = { rain = 90, storm = 130, snow = 40 },
	},
	high = {
		near = { rain = 300, storm = 390, snow = 75 },
		mid = { rain = 240, storm = 330, snow = 70 },
		far = { rain = 150, storm = 220, snow = 60 },
	},
}
-- Orta/uzak halka levhaları: harita zemini ~4 stud; levha yüksekliği ve yere düşme süresi (yaşam süresi) buradan gelir.
local GROUND_Y = 4
local MID_SLAB_Y = 80
local FAR_SLAB_Y = 100
local RAIN_FALL_SPEED = 80
local SNOW_FALL_SPEED = 12
local PRECIP_MAX_CAMERA_Y = 70 -- Kamera bunun üstündeyse yağış çizilmez
local MAIN_SEGMENTS = 12
local BRANCH_SEGMENTS = 4

function WeatherPrecip.start(): () -> ()
	local player = Players.LocalPlayer
	local active = true
	local random = Random.new()
	local connections: { RBXScriptConnection } = {}
	local folder = Instance.new("Folder")
	folder.Name = "LocalWeather"
	folder.Parent = Workspace
	local function cosmetic(name: string): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.CastShadow = false
		part.Transparency = 1
		part.Parent = folder
		return part
	end
	type Ring = { name: string, part: Part, rain: ParticleEmitter, snow: ParticleEmitter }

	local function makeRain(
		parent: Part,
		size: number,
		lifetime: number,
		speed: number,
		transparency: number
	): ParticleEmitter
		local rain = Instance.new("ParticleEmitter")
		rain.Name = "Rain"
		rain.Texture = RAIN_TEXTURE
		rain.Shape = Enum.ParticleEmitterShape.Box
		rain.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		rain.EmissionDirection = Enum.NormalId.Bottom
		rain.Orientation = Enum.ParticleOrientation.FacingCamera
		rain.Speed = NumberRange.new(speed * 0.92, speed * 1.08)
		rain.Lifetime = NumberRange.new(lifetime * 0.92, lifetime)
		rain.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, size, size * 0.15),
			NumberSequenceKeypoint.new(1, size * 0.85, size * 0.1),
		})
		-- Kamera yönüne bakan daire: açıya bağlı yatay levha veya uzun çizgi oluşmaz.
		rain.Squash = NumberSequence.new(0)
		rain.Rotation = NumberRange.new(0)
		rain.RotSpeed = NumberRange.new(0)
		rain.SpreadAngle = Vector2.new(2, 2)
		rain.Color = ColorSequence.new(Color3.fromRGB(208, 222, 237))
		rain.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, math.min(1, transparency + 0.35)),
			NumberSequenceKeypoint.new(0.1, transparency),
			NumberSequenceKeypoint.new(0.8, math.min(1, transparency + 0.12)),
			NumberSequenceKeypoint.new(1, 1),
		})
		rain.LightInfluence = 0
		rain.LightEmission = 0
		rain.LockedToPart = false
		rain.VelocityInheritance = 0
		rain.Enabled = false
		rain.Rate = 0
		rain.Parent = parent
		return rain
	end
	local function makeSnow(
		parent: Part,
		size: number,
		lifetime: number,
		speed: number,
		transparency: number
	): ParticleEmitter
		local snow = Instance.new("ParticleEmitter")
		snow.Name = "Snow"
		snow.Texture = SNOW_TEXTURE
		snow.Shape = Enum.ParticleEmitterShape.Box
		snow.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		snow.EmissionDirection = Enum.NormalId.Bottom
		snow.Orientation = Enum.ParticleOrientation.FacingCamera
		snow.Speed = NumberRange.new(speed * 0.85, speed * 1.15)
		snow.Lifetime = NumberRange.new(lifetime * 0.9, lifetime * 1.1)
		snow.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, size, size * 0.25),
			NumberSequenceKeypoint.new(0.5, size * 1.2, size * 0.28),
			NumberSequenceKeypoint.new(1, size * 0.95, size * 0.22),
		})
		snow.Squash = NumberSequence.new(0)
		snow.SpreadAngle = Vector2.new(12, 12)
		snow.Acceleration = Vector3.new(0.5, -0.08, 0.2)
		snow.Rotation = NumberRange.new(0, 360)
		snow.RotSpeed = NumberRange.new(0)
		snow.Color = ColorSequence.new(Color3.fromRGB(245, 249, 255))
		snow.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, math.min(1, transparency + 0.3)),
			NumberSequenceKeypoint.new(0.08, transparency),
			NumberSequenceKeypoint.new(0.85, math.min(1, transparency + 0.05)),
			NumberSequenceKeypoint.new(1, 1),
		})
		snow.LightInfluence = 0
		snow.LightEmission = 0
		snow.Enabled = false
		snow.Rate = 0
		snow.Parent = parent
		return snow
	end

	-- Yakın: kameraya yakın küçük hacim. Orta/uzak: harita üstünde ince levha (yere inene kadar yaşar).
	local nearPart = cosmetic("WeatherNear")
	nearPart.Size = Vector3.new(28, 12, 28) -- Yağış görüş alanının içinde doğar.
	local midPart = cosmetic("WeatherMid")
	midPart.Size = Vector3.new(170, 2, 170)
	local farPart = cosmetic("WeatherFar")
	farPart.Size = Vector3.new(440, 2, 440)
	local rings: { near: Ring, mid: Ring, far: Ring } = {
		near = {
			name = "near",
			part = nearPart,
			rain = makeRain(nearPart, 0.14, 0.55, 76, 0.3),
			snow = makeSnow(nearPart, 0.2, 5, 5, 0.05),
		},
		mid = {
			name = "mid",
			part = midPart,
			rain = makeRain(midPart, 0.5, (MID_SLAB_Y - GROUND_Y) / RAIN_FALL_SPEED, RAIN_FALL_SPEED, 0.5),
			snow = makeSnow(midPart, 0.5, (MID_SLAB_Y - GROUND_Y) / SNOW_FALL_SPEED, SNOW_FALL_SPEED, 0.3),
		},
		far = {
			name = "far",
			part = farPart,
			rain = makeRain(farPart, 1.8, (FAR_SLAB_Y - GROUND_Y) / RAIN_FALL_SPEED, RAIN_FALL_SPEED, 0.62),
			snow = makeSnow(farPart, 1.6, (FAR_SLAB_Y - GROUND_Y) / SNOW_FALL_SPEED, SNOW_FALL_SPEED, 0.45),
		},
	}
	local ringList: { Ring } = { rings.near, rings.mid, rings.far }

	-- Bir kez oluşturulan 20 fizik dışı segment; ekranı beyaza çeviren çift flaş yok.
	local bolts: { Part } = {}
	for _ = 1, MAIN_SEGMENTS + BRANCH_SEGMENTS * 2 do
		local bolt = cosmetic("LightningSegment")
		bolt.Material = Enum.Material.Neon
		bolt.Color = Color3.fromRGB(224, 237, 255)
		table.insert(bolts, bolt)
	end
	local cloudFlash = Instance.new("ColorCorrectionEffect")
	cloudFlash.Name = "LightningCloudGlow"
	cloudFlash.Brightness = 0
	cloudFlash.Parent = Lighting
	local lightningTweens: { Tween } = {}
	local lightningGeneration = 0
	local function hideLightning()
		lightningGeneration += 1
		for _, tween in lightningTweens do
			tween:Cancel()
		end
		table.clear(lightningTweens)
		for _, bolt in bolts do
			bolt.Transparency = 1
		end
		cloudFlash.Brightness = 0
	end
	local roofParams = RaycastParams.new()
	roofParams.FilterType = Enum.RaycastFilterType.Exclude
	roofParams.IgnoreWater = true
	roofParams.RespectCanCollide = true
	local strikeParams = RaycastParams.new()
	strikeParams.FilterType = Enum.RaycastFilterType.Exclude
	strikeParams.IgnoreWater = false
	local covered = true
	local lastPosition: Vector3? = nil
	local roofElapsed = 0
	local currentWeather = ""
	local nextLightning = os.clock() + random:NextNumber(3, 5)
	local function lightningAllowed(): boolean
		return currentWeather == "storm"
			and player:GetAttribute("ReducedMotion") ~= true
			and player:GetAttribute("EffectsQuality") ~= "low"
	end
	local function updateRoof()
		local exclusions: { Instance } = { folder }
		if player.Character then
			table.insert(exclusions, player.Character)
		end
		roofParams.FilterDescendantsInstances = exclusions
		strikeParams.FilterDescendantsInstances = exclusions
		local camera = Workspace.CurrentCamera
		local blocked = camera == nil
		local submerged = player:GetAttribute("Submerged") == true
		if camera then
			-- Yakın halka: su altında, çatı altında ya da çok yüksekten bakarken (ada üstü genel bakış) kapanır
			local cameraY = camera.CFrame.Position.Y
			if submerged or cameraY > PRECIP_MAX_CAMERA_Y then
				blocked = true
			else
				blocked = Workspace:Raycast(
					camera.CFrame.Position + Vector3.new(0, 0.2, 0),
					Vector3.new(0, 80, 0),
					roofParams
				) ~= nil
			end
		end
		if blocked ~= covered then
			rings.near.rain:Clear()
			rings.near.snow:Clear()
			covered = blocked
		end
		-- Orta/uzak halka bütün haritayı kaplar: yalnızca su altında kapanır, çatı denetimi yoktur
		local farVisible = camera ~= nil and not submerged
		for _, ring in ringList do
			local visible = if ring.name == "near" then not covered else farVisible
			ring.rain.Enabled = visible and ring.rain.Rate > 0
			ring.snow.Enabled = visible and ring.snow.Rate > 0
		end
	end
	local function positionEmitter()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local position = camera.CFrame.Position
		if lastPosition and (position - lastPosition).Magnitude > 50 then
			for _, ring in ringList do
				ring.rain:Clear()
				ring.snow:Clear()
			end
			updateRoof()
		end
		lastPosition = position
		local look = camera.CFrame.LookVector
		local forward = Vector3.new(look.X, 0, look.Z)
		forward = if forward.Magnitude > 0.01 then forward.Unit else Vector3.new(0, 0, -1)
		rings.near.part.CFrame = CFrame.new(position + forward * 16 + Vector3.new(0, 10, 0)) -- Kameraya yapışık büyük taneler olmasın
		rings.mid.part.CFrame = CFrame.new(position.X, MID_SLAB_Y, position.Z)
		rings.far.part.CFrame = CFrame.new(position.X, FAR_SLAB_Y, position.Z)
	end
	local function configure()
		local weather = Environment.getWeather().id
		if weather ~= currentWeather then
			for _, ring in ringList do
				ring.rain:Clear()
				ring.snow:Clear()
			end
			hideLightning()
			nextLightning = os.clock() + random:NextNumber(3, 5)
		end
		currentWeather = weather
		local quality = player:GetAttribute("EffectsQuality")
		local tier = if quality == "low" then QUALITY.low elseif quality == "high" then QUALITY.high else QUALITY.medium
		local factor = if player:GetAttribute("ReducedMotion") == true then 0.35 else 1
		for _, ring in ringList do
			local budget: Budget = (tier :: any)[ring.name]
			ring.rain.Rate = (if weather == "storm" then budget.storm elseif weather == "rain" then budget.rain else 0)
				* factor
			ring.snow.Rate = (if weather == "snow" then budget.snow else 0) * factor
			ring.rain.Acceleration = if weather == "storm" then Vector3.new(12, -8, 3) else Vector3.new(2, -4, 0)
		end
		if not lightningAllowed() then
			hideLightning()
		end
		positionEmitter()
		updateRoof()
	end
	local function setSegment(index: number, from: Vector3, to: Vector3, width: number)
		local bolt = bolts[index]
		bolt.Size = Vector3.new(width, width, (to - from).Magnitude)
		bolt.CFrame = CFrame.lookAt((from + to) / 2, to)
		bolt.Transparency = 0.05
	end
	local function strike()
		local camera = Workspace.CurrentCamera
		if not camera or covered or not lightningAllowed() then
			return
		end
		hideLightning()
		local view = camera.CFrame
		local forward = Vector3.new(view.LookVector.X, 0, view.LookVector.Z)
		forward = if forward.Magnitude > 0.01 then forward.Unit else Vector3.new(0, 0, -1)
		local center = view.Position
			+ forward * random:NextNumber(95, 150)
			+ view.RightVector * random:NextNumber(-55, 55)
		local start = Vector3.new(center.X, math.max(view.Position.Y + 90, 140), center.Z)
		local hit = Workspace:Raycast(start, Vector3.new(0, -250, 0), strikeParams)
		local finish = if hit then hit.Position else Vector3.new(center.X, 5, center.Z)
		local points: { Vector3 } = { start }
		for index = 1, MAIN_SEGMENTS do
			local point = start:Lerp(finish, index / MAIN_SEGMENTS)
			if index < MAIN_SEGMENTS then
				point += Vector3.new(random:NextNumber(-7, 7), 0, random:NextNumber(-7, 7))
			end
			setSegment(index, points[index], point, 0.32)
			table.insert(points, point)
		end
		for branch = 1, 2 do
			local origin = points[branch * 3 + 1]
			local tip = origin + Vector3.new(random:NextNumber(-25, 25), -22, random:NextNumber(-25, 25))
			local previous = origin
			for index = 1, BRANCH_SEGMENTS do
				local point = origin:Lerp(tip, index / BRANCH_SEGMENTS)
				if index < BRANCH_SEGMENTS then
					point += Vector3.new(random:NextNumber(-3, 3), 0, random:NextNumber(-3, 3))
				end
				setSegment(MAIN_SEGMENTS + (branch - 1) * BRANCH_SEGMENTS + index, previous, point, 0.14)
				previous = point
			end
		end
		cloudFlash.Brightness = 0.055 -- Ayrı efekt: WeatherGrade'ın altı saniyelik geçişine dokunmaz.
		local generation = lightningGeneration
		task.delay(0.12, function()
			if not active or generation ~= lightningGeneration then
				return
			end
			local fade = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			for _, bolt in bolts do
				local tween = TweenService:Create(bolt, fade, { Transparency = 1 })
				table.insert(lightningTweens, tween)
				tween:Play()
			end
			local tween = TweenService:Create(cloudFlash, fade, { Brightness = 0 })
			table.insert(lightningTweens, tween)
			tween:Play()
		end)
	end
	table.insert(connections, RunService.RenderStepped:Connect(positionEmitter))
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			roofElapsed += dt
			if roofElapsed < 0.2 then
				return
			end
			roofElapsed = 0
			updateRoof()
			if lightningAllowed() and os.clock() >= nextLightning then
				nextLightning = os.clock() + random:NextNumber(8, 16)
				strike()
			end
		end)
	)
	Environment.onChanged(configure) -- dünya havası ve oyuncunun asa geçersiz kılması
	table.insert(connections, player:GetAttributeChangedSignal("EffectsQuality"):Connect(configure))
	table.insert(connections, player:GetAttributeChangedSignal("ReducedMotion"):Connect(configure))
	configure()
	return function()
		if not active then
			return
		end
		active = false
		for _, connection in connections do
			connection:Disconnect()
		end
		hideLightning()
		for _, ring in ringList do
			ring.rain:Clear()
			ring.snow:Clear()
		end
		cloudFlash:Destroy()
		folder:Destroy()
	end
end

return WeatherPrecip
