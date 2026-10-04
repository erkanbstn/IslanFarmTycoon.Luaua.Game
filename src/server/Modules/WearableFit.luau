--!strict
local WearableFit = {}

-- Şablonlar normal avatarın arka yüzeyi Z=0.5 için çizilmiştir; kalın gövdeye gömülmesin.
function WearableFit.backOffset(rear: number): number
	return math.max(0, rear - 0.5)
end

return WearableFit
