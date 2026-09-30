--!strict
-- Ses çalma: tüm sesler tek "SfxMaster" SoundGroup'undan geçer; Ayarlar'daki ses düzeyi bunu ölçekler.
-- Kimlik boşsa ya da dosya bulunamazsa ses sessizce atlanır (oyun bozulmaz).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local DEFAULT_VOLUME = 0.5
local MIN_GAP = 0.05 -- Aynı ses bu kadar sıklıktan fazla üst üste çalmaz

local Sfx = {}

local existing = SoundService:FindFirstChild("SfxMaster")
local master: SoundGroup
if existing and existing:IsA("SoundGroup") then
	master = existing
else
	master = Instance.new("SoundGroup")
	master.Name = "SfxMaster"
	master.Parent = SoundService
end

if player:GetAttribute("SoundVolume") == nil then
	player:SetAttribute("SoundVolume", DEFAULT_VOLUME)
end
local function applyVolume()
	local value = player:GetAttribute("SoundVolume")
	master.Volume = if typeof(value) == "number" then math.clamp(value, 0, 1) else DEFAULT_VOLUME
end
applyVolume()
player:GetAttributeChangedSignal("SoundVolume"):Connect(applyVolume)

local lastPlayed: { [string]: number } = {}

function Sfx.group(): SoundGroup
	return master
end

-- Ortak yapılandırma: Config.SOUNDS'taki adla çal. pitchJitter: 0.1 -> ±%10 rastgele perde.
function Sfx.play(name: string, pitchJitter: number?)
	local config = Config.SOUNDS[name]
	if not config or config.id == "" then
		return
	end
	local now = os.clock()
	if now - (lastPlayed[name] or 0) < MIN_GAP then
		return
	end
	lastPlayed[name] = now
	local sound = Instance.new("Sound")
	sound.SoundId = config.id
	sound.Volume = config.volume
	local jitter = if pitchJitter then 1 + (math.random() * 2 - 1) * pitchJitter else 1
	sound.PlaybackSpeed = (config.pitch or 1) * jitter
	sound.SoundGroup = master
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 6)
end

-- Bir parçadan (3B) çalınan ses; uzaklaştıkça kısılır.
function Sfx.playAt(part: BasePart, config: Config.SoundConfig, pitchJitter: number?)
	if config.id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = config.id
	sound.Volume = config.volume
	sound.PlaybackSpeed = 1 + (math.random() * 2 - 1) * (pitchJitter or 0)
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = 45
	sound.SoundGroup = master
	sound.Parent = part
	sound:Play()
	Debris:AddItem(sound, 8)
end

return Sfx
