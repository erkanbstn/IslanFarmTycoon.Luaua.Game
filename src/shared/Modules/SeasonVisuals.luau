--!strict
-- Ekonomiden bağımsız, döngü sınırlarında devamlı görsel mevsim eğrileri.
local SeasonVisuals = {}

export type State = {
	snow: number,
	ice: number,
	foliage: number,
	autumn: number,
	bloom: number,
}

local function smooth(start: number, finish: number, progress: number): number
	local t = math.clamp((progress - start) / (finish - start), 0, 1)
	return t * t * (3 - 2 * t)
end

function SeasonVisuals.sample(season: string, progress: number): State
	local p = if progress == progress then math.clamp(progress, 0, 1) else 0
	local state: State = { snow = 0, ice = 0, foliage = 1, autumn = 0, bloom = 0 }
	if season == "autumn" then
		state.autumn = smooth(0, 0.4, p)
		state.foliage = 1 - smooth(0.35, 1, p)
	elseif season == "winter" then
		local thaw = smooth(0.7, 1, p)
		state.snow = smooth(0, 0.25, p) * (1 - 0.8 * thaw)
		state.ice = smooth(0, 0.4, p) * (1 - 0.8 * thaw)
		state.foliage = 0
		state.autumn = 1
	elseif season == "spring" then
		state.snow = 0.2 * (1 - smooth(0, 0.2, p))
		state.ice = state.snow
		state.foliage = smooth(0, 0.35, p)
		state.autumn = 1 - smooth(0, 0.35, p)
		state.bloom = smooth(0.1, 0.4, p) * (1 - smooth(0.7, 1, p))
	end
	return state
end

return SeasonVisuals
