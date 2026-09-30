--!strict
-- Sunucu oturumu sayaçları. Oyuncu adı/kimliği veya kayıt içeriği saklanmaz.
local ServerStorage = game:GetService("ServerStorage")
local Metrics = {}
local folder = Instance.new("Folder")
folder.Name = "Diagnostics"
folder.Parent = ServerStorage

function Metrics.increment(name: string, amount: number?)
	local current = folder:GetAttribute(name)
	folder:SetAttribute(name, (if typeof(current) == "number" then current else 0) + (amount or 1))
end

function Metrics.set(name: string, value: number)
	folder:SetAttribute(name, value)
end

function Metrics.max(name: string, value: number)
	local current = folder:GetAttribute(name)
	folder:SetAttribute(name, math.max(if typeof(current) == "number" then current else 0, value))
end

function Metrics.duration(name: string, seconds: number)
	Metrics.increment(`{name}Count`)
	Metrics.increment(`{name}Seconds`, seconds)
	local maximum = folder:GetAttribute(`{name}MaxSeconds`)
	folder:SetAttribute(`{name}MaxSeconds`, math.max(if typeof(maximum) == "number" then maximum else 0, seconds))
end

return Metrics
