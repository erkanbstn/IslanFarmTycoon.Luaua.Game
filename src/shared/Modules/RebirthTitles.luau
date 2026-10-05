--!strict
-- Rebirth ünvanları: kayıttaki rebirth sayısından kafa üstü etiket metni ("R3 · Usta Çiftçi").
-- Saf mantık; sayı yalnızca sunucu kaydından gelir. Sayı güvenli sınırlanır (NaN, negatif, kesirli, çok büyük).
-- Yeni ünvan = TIERS'a bir satır (minCount artan sırada) + beş dilde çeviri anahtarı.

local RebirthTitles = {}

-- Gösterilecek en büyük sayı: etiket genişliği ve metin uzunluğu sınırlı kalsın.
RebirthTitles.MAX_DISPLAY_COUNT = 999

export type Tier = { minCount: number, title: string }

-- Artan minCount; en yüksek eşik (R30) son kademedir.
local TIERS: { Tier } = {
	{ minCount = 1, title = "Çırak" },
	{ minCount = 3, title = "Çiftçi" },
	{ minCount = 5, title = "Usta Çiftçi" },
	{ minCount = 8, title = "Ada Kâşifi" },
	{ minCount = 12, title = "Takımada Uzmanı" },
	{ minCount = 16, title = "Tüccar" },
	{ minCount = 20, title = "Efsane" },
	{ minCount = 25, title = "Kadim Usta" },
	{ minCount = 30, title = "Takımada Şampiyonu" },
}
RebirthTitles.TIERS = table.freeze(TIERS)

-- Güvenilmeyen değeri 0..MAX_DISPLAY_COUNT arası tam sayıya çevirir (sayı değilse/NaN/negatifse 0).
function RebirthTitles.clampCount(value: unknown): number
	if typeof(value) ~= "number" or value ~= value or value <= 0 then
		return 0
	end
	return math.floor(math.min(value, RebirthTitles.MAX_DISPLAY_COUNT))
end

-- Sayıya uyan ünvan; 0 rebirth'te ünvan yoktur (nil).
function RebirthTitles.titleFor(value: unknown): string?
	local count = RebirthTitles.clampCount(value)
	local found: string? = nil
	for _, tier in TIERS do
		if count >= tier.minCount then
			found = tier.title
		else
			break
		end
	end
	return found
end

-- Etiket metni: "R{n} · {Ünvan}". Localizer " · " ile böler; "R{}" ve ünvan ayrı anahtarlardır.
-- 0 rebirth'te nil: etiket gösterilmez.
function RebirthTitles.label(value: unknown): string?
	local count = RebirthTitles.clampCount(value)
	local title = RebirthTitles.titleFor(count)
	if not title then
		return nil
	end
	return `R{count} · {title}`
end

return RebirthTitles
