--!strict
-- Ürün silme saf kuralları: sunucu doğrulaması (validAmount) ve istemci miktar seçici (clamp/parseText/quick).
return function(goodsDiscard: any)
	-- Sunucu doğrulaması: yalnız sonlu, tam sayı, 1..mevcut kabul edilir
	assert(goodsDiscard.validAmount(1, 5) == 1 and goodsDiscard.validAmount(5, 5) == 5, "bounds are inclusive")
	assert(goodsDiscard.validAmount(3, 5) == 3, "a partial amount is valid")
	for _, bad in { 0, -1, -0.5, 0.5, 1.5, 6, 1e9, math.huge, -math.huge, 0 / 0, "3", "", true, {}, false } do
		assert(goodsDiscard.validAmount(bad, 5) == nil, "invalid amount is refused")
	end
	assert(goodsDiscard.validAmount(nil, 5) == nil, "a missing amount is refused")
	assert(goodsDiscard.validAmount(1, 0) == nil, "nothing can be discarded from an empty stack")

	-- İstemci sıkıştırma: 1..mevcut tam sayı, NaN/sayı değil -> 1, ürün yoksa 0
	assert(goodsDiscard.clamp(0, 8) == 1 and goodsDiscard.clamp(-4, 8) == 1, "low values clamp to one")
	assert(goodsDiscard.clamp(99, 8) == 8 and goodsDiscard.clamp(math.huge, 8) == 8, "high values clamp to the stock")
	assert(goodsDiscard.clamp(3.9, 8) == 3, "fractions are floored")
	assert(goodsDiscard.clamp(0 / 0, 8) == 1 and goodsDiscard.clamp("x", 8) == 1, "non numbers fall back to one")
	assert(goodsDiscard.clamp(5, 0) == 0, "an empty stack has no valid amount")
	assert(goodsDiscard.parseText("12", 8) == 8 and goodsDiscard.parseText(" 4 ", 8) == 4, "typed text is clamped")
	assert(goodsDiscard.parseText("abc", 8) == nil and goodsDiscard.parseText("", 8) == nil, "unreadable text is nil")
	assert(goodsDiscard.parseText("-3", 8) == 1, "a negative typed value clamps to one")

	-- Hızlı düğmeler
	assert(goodsDiscard.quick("one", 9) == 1 and goodsDiscard.quick("ten", 9) == 9, "10 never exceeds the stock")
	assert(goodsDiscard.quick("ten", 25) == 10, "ten is ten when stocked")
	assert(goodsDiscard.quick("half", 11) == 6 and goodsDiscard.quick("half", 1) == 1, "half rounds up like quick sell")
	assert(goodsDiscard.quick("all", 7) == 7, "all is the whole stack")
	assert(goodsDiscard.quick("all", 0) == 0, "empty stack selects nothing")
	print("PASS goods discard: server validation and client amount chooser rules")
end
