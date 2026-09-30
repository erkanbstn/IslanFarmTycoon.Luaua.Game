--!strict
-- Kare başı döngülerde kullanılan efekt ayarlarının önbelleği.
-- `ReducedMotion` ve `EffectsQuality` Player özniteliğidir; her karede GetAttribute çağırmak yerine
-- değişince güncellenen bu değerleri oku.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local reduced = player:GetAttribute("ReducedMotion") == true
local quality: string = tostring(player:GetAttribute("EffectsQuality") or "medium")

player:GetAttributeChangedSignal("ReducedMotion"):Connect(function()
	reduced = player:GetAttribute("ReducedMotion") == true
end)
player:GetAttributeChangedSignal("EffectsQuality"):Connect(function()
	quality = tostring(player:GetAttribute("EffectsQuality") or "medium")
end)

local EffectSettings = {}

function EffectSettings.reducedMotion(): boolean
	return reduced
end

-- "low" | "medium" | "high" (öznitelik yazılmadıysa "medium")
function EffectSettings.quality(): string
	return quality
end

return EffectSettings
