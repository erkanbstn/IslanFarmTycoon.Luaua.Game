--!strict
-- Konma ve ürkme sınırları görsel kalitesinden bağımsızdır.
local BirdBehavior = {}

function BirdBehavior.safeSurface(normalY: number, water: boolean, solid: boolean, transparency: number): boolean
	return normalY >= 0.72 and not water and solid and transparency < 0.9
end

function BirdBehavior.shouldFlee(distance: number, speed: number): boolean
	return distance < 4 or (distance < 13 and speed > 4)
end

function BirdBehavior.progress(elapsed: number, duration: number): number
	local alpha = math.clamp(elapsed / math.max(duration, 0.01), 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

return BirdBehavior
