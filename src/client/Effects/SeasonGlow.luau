--!strict
-- Klonun değişmeyen parça verisini bir kez toplar; nabızda ağaç taraması yapılmaz.
export type GlowPart = { part: BasePart, base: number, kind: string, phase: number }
export type Glow = { model: Model, parts: { GlowPart }, mode: string? }

local SeasonGlow = {}

function SeasonGlow.capture(model: Model): Glow
	local parts: { GlowPart } = {}
	local rising = model:GetAttribute("Kind") == "good"
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local name = part.Name
			local kind = if name == "Glow" then "Glow" else name:sub(1, 5)
			local index = tonumber(name:sub(6)) or 1
			table.insert(parts, {
				part = part,
				base = part.Transparency,
				kind = kind,
				phase = if kind == "Mark_" then (if rising then index else 5 - index) * 0.9 else index * 0.8,
			})
		end
	end
	return { model = model, parts = parts, mode = nil }
end

function SeasonGlow.update(glow: Glow, now: number, low: boolean, reduced: boolean)
	local mode = if low then "low" elseif reduced then "reduced" else "animated"
	if mode ~= "animated" and glow.mode == mode then
		return
	end
	glow.mode = mode
	for _, item in glow.parts do
		if mode ~= "animated" then
			item.part.Transparency = if low and item.kind == "Mark_" then 1 else item.base
		elseif item.kind == "Glow" then
			item.part.Transparency = math.clamp(item.base + math.sin(now * 2.2) * 0.1, 0, 1)
		elseif item.kind == "Mark_" then
			item.part.Transparency =
				math.clamp(item.base + (1 - item.base) * (0.5 - 0.5 * math.sin(now * 3 - item.phase)), 0, 1)
		elseif item.kind == "Ring_" then
			item.part.Transparency = math.clamp(item.base + math.sin(now * 2.2 - item.phase) * 0.08, 0, 1)
		end
	end
end

return SeasonGlow
