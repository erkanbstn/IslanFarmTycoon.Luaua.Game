--!strict
-- SaveCodec parçaları için ortak sınırlar.
local SessionLock = require(script.Parent.Parent.SessionLock)

local Common = {}

Common.MAX_MONEY = 1e15

-- Sonlu sayıyı 0..MAX_MONEY'e sıkıştırır; geçersizse yedek değer.
function Common.amount(value: unknown, fallback: number): number
	return if SessionLock.isFinite(value) then math.clamp(value :: number, 0, Common.MAX_MONEY) else fallback
end

return Common
