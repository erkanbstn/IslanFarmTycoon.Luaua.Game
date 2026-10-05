--!strict
-- Rebirth ünvanı saf mantığı: kademe seçimi, metin biçimi ve güvenilmeyen sayıların sınırlanması.
return function(RebirthTitles: any)
	-- 0 rebirth: ünvan ve etiket yok
	assert(RebirthTitles.titleFor(0) == nil, "no title at zero rebirths")
	assert(RebirthTitles.label(0) == nil, "no label at zero rebirths")

	-- Kademe sınırları
	local expected = {
		{ 1, "Çırak" },
		{ 2, "Çırak" },
		{ 3, "Çiftçi" },
		{ 4, "Çiftçi" },
		{ 5, "Usta Çiftçi" },
		{ 7, "Usta Çiftçi" },
		{ 8, "Ada Kâşifi" },
		{ 11, "Ada Kâşifi" },
		{ 12, "Takımada Uzmanı" },
		{ 15, "Takımada Uzmanı" },
		{ 16, "Tüccar" },
		{ 19, "Tüccar" },
		{ 20, "Efsane" },
		{ 24, "Efsane" },
		{ 25, "Kadim Usta" },
		{ 29, "Kadim Usta" },
		{ 30, "Takımada Şampiyonu" },
		{ 31, "Takımada Şampiyonu" },
	}
	for _, row in expected do
		assert(RebirthTitles.titleFor(row[1]) == row[2], `R{row[1]} should be {row[2]}`)
	end

	-- Kademeler artan sırada, eşsiz ve R30 son kademe
	local previous = 0
	local seen: { [string]: boolean } = {}
	for _, tier in RebirthTitles.TIERS do
		assert(tier.minCount > previous, "tiers are strictly ascending")
		assert(not seen[tier.title], "tier titles are unique")
		seen[tier.title] = true
		previous = tier.minCount
	end
	assert(previous == 30, "the final tier starts at R30")
	assert(#RebirthTitles.TIERS >= 8 and #RebirthTitles.TIERS <= 10, "about 8-10 tiers")

	-- Metin biçimi: "R{n} · {Ünvan}"
	assert(RebirthTitles.label(1) == "R1 · Çırak", "label format")
	assert(RebirthTitles.label(6) == "R6 · Usta Çiftçi", "label uses count and tier")
	assert(RebirthTitles.label(30) == "R30 · Takımada Şampiyonu", "final label")

	-- Güvenilmeyen girdiler
	assert(RebirthTitles.clampCount(0 / 0) == 0, "NaN becomes zero")
	assert(RebirthTitles.clampCount(-5) == 0, "negative becomes zero")
	assert(RebirthTitles.clampCount(-math.huge) == 0, "negative infinity becomes zero")
	assert(RebirthTitles.clampCount("9") == 0, "non numbers become zero")
	assert(RebirthTitles.clampCount(nil) == 0, "nil becomes zero")
	assert(RebirthTitles.clampCount(3.9) == 3, "fractions floor")
	assert(RebirthTitles.clampCount(math.huge) == RebirthTitles.MAX_DISPLAY_COUNT, "infinity is capped")
	assert(RebirthTitles.clampCount(1e12) == RebirthTitles.MAX_DISPLAY_COUNT, "huge counts are capped")
	assert(RebirthTitles.label(0 / 0) == nil and RebirthTitles.label(-1) == nil, "invalid counts hide the label")
	assert(RebirthTitles.label(1e12) == "R999 · Takımada Şampiyonu", "huge counts stay bounded and readable")
	print("PASS rebirth titles: tiers, label format and count clamping")
end
