--!strict
-- Hesaba kayıtlı tercihler: üç ses düzeyi ve hareket azaltma.
-- Kayıt yüklenince sunucunun yazdığı Saved* özniteliği bir kez canlı özniteliğe uygulanır; sonra Ayarlar'dan gelen
-- değişiklikler sürgü duraklayınca (SEND_DELAY) sunucuya gönderilir. Sunucu doğrular ve kaydeder (Modules/Preferences).
-- Kayıt yüklenmeden (Saved* yokken) hiçbir şey gönderilmez: varsayılan, kayıtlı tercihi ezemez.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local SEND_DELAY = 0.6

-- Tercih türü -> canlı öznitelik (arayüzün okuduğu/yazdığı), sunucunun yazdığı kayıtlı öznitelik, değer türü
local PREFERENCES: { { kind: string, live: string, saved: string, valueType: string } } = {
	{ kind = "sfx", live = "SoundVolume", saved = "SavedSfxVolume", valueType = "number" },
	{ kind = "ambience", live = "AmbienceVolume", saved = "SavedAmbienceVolume", valueType = "number" },
	{ kind = "music", live = "MusicVolume", saved = "SavedMusicVolume", valueType = "number" },
	{ kind = "reducedMotion", live = "ReducedMotion", saved = "SavedReducedMotion", valueType = "boolean" },
}

if player:GetAttribute("ReducedMotion") == nil then
	player:SetAttribute("ReducedMotion", false)
end

for _, preference in PREFERENCES do
	local loaded = false
	local synced: unknown = nil -- sunucunun bildiği son değer; aynısı yeniden gönderilmez
	local version = 0

	local function queueSend()
		version += 1
		local mine = version
		task.delay(SEND_DELAY, function()
			if version ~= mine then
				return
			end
			local value = player:GetAttribute(preference.live)
			if typeof(value) == preference.valueType and value ~= synced then
				synced = value
				Remotes.get("RequestSetPreference"):FireServer(preference.kind, value)
			end
		end)
	end

	-- Kayıtlı değer (boş metin = hiç seçilmemiş, varsayılan kalır) yalnızca ilk görüldüğünde uygulanır.
	local function applySaved()
		if loaded then
			return
		end
		local saved = player:GetAttribute(preference.saved)
		if saved == nil then
			return
		end
		loaded = true
		if typeof(saved) == preference.valueType then
			synced = saved
			player:SetAttribute(preference.live, saved)
		end
	end

	player:GetAttributeChangedSignal(preference.saved):Connect(applySaved)
	player:GetAttributeChangedSignal(preference.live):Connect(function()
		-- Kayıt gelmeden değişen canlı değer varsayılandır (Sfx yazar); kayıt gelince ezilir, gönderilmez.
		if loaded then
			queueSend()
		end
	end)
	applySaved()
end
