--!strict
-- Ortam sesleri: mevsime, havaya ve geceye göre kuş, rüzgâr, yağmur ve gece döngüleri; yakındaki
-- hayvanların ara sıra çıkardığı sesler (ortam grubu) ve müzik döngüsü (müzik grubu).
-- Kimlikler Config.AMBIENCE / Config.ANIMAL_SOUNDS / Config.MUSIC içindedir;
-- boş kimlikli katman hiç kurulmaz, dolayısıyla kimlik girilmemişken bu script neredeyse hiçbir şey yapmaz.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local Sfx = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Sfx"))

local player = Players.LocalPlayer
local UPDATE_SECONDS = 1
local FADE = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local ANIMAL_NEAR = 35
local ANIMAL_GAP = NumberRange.new(6, 14)

type Layer = { sound: Sound, base: number }
local layers: { [string]: Layer } = {}
for name, config in Config.AMBIENCE do
	if config.id ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = `Ambience_{name}`
		sound.SoundId = config.id
		sound.Looped = true
		sound.Volume = 0
		sound.SoundGroup = Sfx.ambienceGroup()
		sound.Parent = SoundService
		sound:Play()
		layers[name] = { sound = sound, base = config.volume }
	end
end

-- Müzik: Config.MUSIC yuvaları kendi grubunda döngüyle çalar (boş kimlik = müzik yok); düzeyi "Müzik" sürgüsü belirler.
local musicSounds: { Sound } = {}
for name, config in Config.MUSIC do
	if config.id ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = `Music_{name}`
		sound.SoundId = config.id
		sound.Looped = true
		sound.Volume = config.volume
		sound.SoundGroup = Sfx.musicGroup()
		sound.Parent = SoundService
		sound:Play()
		table.insert(musicSounds, sound)
	end
end

local function fadeTo(name: string, wanted: number)
	local layer = layers[name]
	if not layer then
		return
	end
	local target = layer.base * wanted
	if math.abs(layer.sound.Volume - target) > 0.01 then
		TweenService:Create(layer.sound, FADE, { Volume = target }):Play()
	end
end

local function updateAmbience()
	local season = Environment.getSeason().id
	local weather = Environment.getWeather().id
	local night = Environment.getNightFactor(Environment.getClockTime())
	local raining = weather == "rain"
	local storming = weather == "storm"
	local calm = not raining and not storming
	local warmSeason = season == "spring" or season == "summer"

	fadeTo("birds", if warmSeason and calm and night < 0.3 then 1 else 0)
	fadeTo("wind", if weather == "cloudy" or storming or (not warmSeason and weather ~= "snow") then 1 else 0.3)
	fadeTo("rain", if raining then 1 elseif storming and not layers.storm then 1 else 0)
	fadeTo("storm", if storming then 1 else 0)
	fadeTo("night", if night > 0.5 and not storming then 1 else 0)
end

local function animalId(model: Model): string?
	return string.match(model.Name, "^([^_]+)_")
end

local function isOwnAdult(model: Model): boolean
	if model:GetAttribute("Stage") ~= "adult" then
		return false
	end
	local plot: Instance? = model.Parent
	while plot and (not plot.Parent or plot.Parent.Name ~= "Plots") do
		plot = plot.Parent
	end
	return plot ~= nil and plot:GetAttribute("OwnerUserId") == player.UserId
end

local hasAnimalSounds = false
for _, config in Config.ANIMAL_SOUNDS do
	if config.id ~= "" then
		hasAnimalSounds = true
	end
end

local random = Random.new()
local nextAnimalAt = os.clock() + random:NextNumber(ANIMAL_GAP.Min, ANIMAL_GAP.Max)
local function updateAnimals()
	if not hasAnimalSounds or os.clock() < nextAnimalAt then
		return
	end
	nextAnimalAt = os.clock() + random:NextNumber(ANIMAL_GAP.Min, ANIMAL_GAP.Max)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local nearby: { Model } = {}
	for _, instance in CollectionService:GetTagged("Animal") do
		if
			instance:IsA("Model")
			and instance:IsDescendantOf(Workspace)
			and (instance:GetPivot().Position - camera.CFrame.Position).Magnitude <= ANIMAL_NEAR
			and isOwnAdult(instance)
		then
			table.insert(nearby, instance)
		end
	end
	if #nearby == 0 then
		return
	end
	local model = nearby[random:NextInteger(1, #nearby)]
	local id = animalId(model)
	local config = if id then Config.ANIMAL_SOUNDS[id] else nil
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if config and anchor then
		Sfx.playAt(anchor, config, 0.1, Sfx.ambienceGroup())
	end
end

local elapsed = UPDATE_SECONDS
local connection = RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed < UPDATE_SECONDS then
		return
	end
	elapsed = 0
	updateAmbience()
	updateAnimals()
end)
script.Destroying:Connect(function()
	connection:Disconnect()
	for _, layer in layers do
		layer.sound:Destroy()
	end
	for _, sound in musicSounds do
		sound:Destroy()
	end
end)
