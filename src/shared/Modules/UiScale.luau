--!strict
-- Ekran boyutuna bağlı kök arayüz ölçeği (saf; istemci `UiKit/Kit/Screen` kullanır).
-- Ölçü kısa kenara bakar: telefon (dikey ya da yatay) küçültülür, 1440p ve üstü büyütülür.
-- Kademeler tek yerde durur; denge değil görünüm ayarıdır, bu yüzden Config'te değil burada.

local UiScale = {}

-- { kısa kenar bu değere kadar (dahil), ölçek }
local TIERS: { { maxShortSide: number, scale: number } } = {
	{ maxShortSide = 480, scale = 0.85 }, -- telefon
	{ maxShortSide = 680, scale = 0.8 }, -- alçak pencere (ör. Studio testi): sol panel ve sağ menü Roblox'un kendi arayüzüne taşmasın
	{ maxShortSide = 1100, scale = 1 }, -- tablet, 768p-1080p
	{ maxShortSide = 1700, scale = 1.25 }, -- 1440p
	{ maxShortSide = math.huge, scale = 1.5 }, -- 4K
}

function UiScale.forViewport(width: number, height: number): number
	local shortSide = math.min(width, height)
	if shortSide ~= shortSide or shortSide <= 0 then
		return 1
	end
	for _, tier in TIERS do
		if shortSide <= tier.maxShortSide then
			return tier.scale
		end
	end
	return 1
end

return UiScale
