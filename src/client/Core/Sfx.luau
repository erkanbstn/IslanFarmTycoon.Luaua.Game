--!strict
-- Ses çalma: sesler üç SoundGroup'tan geçer (efekt / ortam / müzik); Ayarlar'daki üç sürgü bunları ölçekler.
-- Kimlik boşsa ya da dosya bulunamazsa ses sessizce atlanır (oyun bozulmaz).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local MIN_GAP = 0.12
-- Bazı sesler daha seyrek çalar: kutlama sesi (yapı belirmesi) art arda çok sayıda yapı kurulsa da 30 saniyede bir çalar
local NAME_GAPS: { [string]: number } = { build = 30 } -- Aynı ses bu kadar sıklıktan fazla üst üste çalmaz

local Sfx = {}

-- Üç SoundGroup: efektler ("SfxMaster"), ortam döngüleri ve hayvan sesleri ("AmbienceMaster"), müzik ("MusicMaster").
-- Düzeyleri Player öznitelikleri belirler (Ayarlar'daki sürgüler; kayıt Core/Preferences.client yapar):
-- SoundVolume (efekt, eski ad korunur), AmbienceVolume, MusicVolume.
local function ensureGroup(name: string): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Parent = SoundService
	return group
end

local master = ensureGroup("SfxMaster")
local ambience = ensureGroup("AmbienceMaster")
local music = ensureGroup("MusicMaster")

local function bindVolume(group: SoundGroup, attribute: string, fallback: number)
	if player:GetAttribute(attribute) == nil then
		player:SetAttribute(attribute, fallback)
	end
	local function apply()
		local value = player:GetAttribute(attribute)
		group.Volume = if typeof(value) == "number" then math.clamp(value, 0, 1) else fallback
	end
	apply()
	player:GetAttributeChangedSignal(attribute):Connect(apply)
end
bindVolume(master, "SoundVolume", Config.AUDIO_DEFAULTS.sfx)
bindVolume(ambience, "AmbienceVolume", Config.AUDIO_DEFAULTS.ambience)
bindVolume(music, "MusicVolume", Config.AUDIO_DEFAULTS.music)

local lastPlayed: { [string]: number } = {}

function Sfx.group(): SoundGroup
	return master
end

function Sfx.ambienceGroup(): SoundGroup
	return ambience
end

function Sfx.musicGroup(): SoundGroup
	return music
end

-- Ortak yapılandırma: Config.SOUNDS'taki adla çal. pitchJitter: 0.1 -> ±%10 rastgele perde.
function Sfx.play(name: string, pitchJitter: number?)
	local config = Config.SOUNDS[name]
	if not config or config.id == "" then
		return
	end
	local now = os.clock()
	if now - (lastPlayed[name] or 0) < (NAME_GAPS[name] or MIN_GAP) then
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

-- Bir parçadan (3B) çalınan ses; uzaklaştıkça kısılır. `group` verilmezse efekt grubu (hayvan sesleri ortam grubunu verir).
function Sfx.playAt(part: BasePart, config: Config.SoundConfig, pitchJitter: number?, group: SoundGroup?)
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
	sound.SoundGroup = group or master
	sound.Parent = part
	sound:Play()
	Debris:AddItem(sound, 8)
end

return Sfx
