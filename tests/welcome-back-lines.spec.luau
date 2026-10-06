--!strict
-- Dönüş özeti satırları (saf): hangi satırlar görünür, boş satır yok, kompakt kalır ve ek alanlar güvenle okunur.
return function(Lines: any)
	local function input(overrides: any?): any
		local base: any = {
			earned = 0,
			earnedText = "0",
			grown = 0,
			animalIcon = "🐄",
			recipes = {},
		}
		for key, value in overrides or {} do
			base[key] = value
		end
		return base
	end
	local function texts(lines: any): string
		local parts = {}
		for _, line in lines do
			table.insert(parts, line.text)
		end
		return table.concat(parts, "|")
	end

	-- Boş özet: satır yok
	assert(#Lines.build(input()) == 0, "hiçbir bilgi yoksa satır yok")

	-- Eski sunucu uyumu: yalnız kazanç, büyüme ve üretim eski üç satırla aynı sırada
	local old = Lines.build(input({ earned = 1500, earnedText = "1,5K", grown = 3, recipes = { "Peynir" } }))
	assert(texts(old) == "+1,5K kazandın|3 hayvan büyüdü|Peynir hazır", `eski satırlar: {texts(old)}`)
	assert(old[1].icon == "💰" and old[2].icon == "🐄" and old[3].icon == "🏭", "eski ikonlar")

	-- Ek satırlar yalnızca ilgiliyse görünür
	local only = Lines.build(input({ daily = true }))
	assert(#only == 1 and only[1].text == "Günlük ödülün hazır", "yalnız günlük ödül")
	local mixed = Lines.build(input({ daily = false, orders = 0, merchant = false, golden = false }))
	assert(#mixed == 0, "false/0 alanlar satır üretmez")
	local orders = Lines.build(input({ orders = 4 }))
	assert(#orders == 1 and orders[1].text == "4 sipariş teslime hazır", "sipariş sayısı metinde")
	local trader = Lines.build(input({ merchant = true, golden = true }))
	assert(texts(trader) == "Gezgin tüccar meydanda|Altın hayvan parlıyor", "tüccar ve altın hayvan")

	-- Hiçbir satırın metni boş değil; hepsinin ikonu var; ayrıntı varsa dolu
	local full = Lines.build(input({
		earned = 10,
		earnedText = "10",
		grown = 1,
		recipes = { "A" },
		daily = true,
		orders = 2,
		merchant = true,
		golden = true,
	}))
	for _, line in full do
		assert(#line.text > 0 and #line.icon > 0 and (line.detail == nil or #line.detail > 0), "boş satır yok")
	end
	assert(#full <= Lines.MAX_LINES, "satır sayısı sınırlı")
	assert(full[1].text == "+10 kazandın" and full[#full].text == "Altın hayvan parlıyor", "öncelik sırası")

	-- Kompakt: çok satır varsa ayrıntılar gizlenir; az satırda gösterilir
	assert(Lines.showDetails(#only) and Lines.showDetails(Lines.DETAIL_LIMIT), "az satırda ayrıntı görünür")
	assert(not Lines.showDetails(#full), "çok satırda ayrıntı gizlenir")
	assert(Lines.DETAIL_LIMIT < Lines.MAX_LINES, "kompakt eşik sınırdan küçük")

	-- Ek alanlar güvenle okunur: tablo değilse boş; yanlış tür atılır; sınırlar
	assert(next(Lines.readExtras(nil)) == nil and next(Lines.readExtras("x")) == nil, "tablo olmayan değer boş")
	local read = Lines.readExtras({ daily = true, orders = 3.7, merchant = "yes", golden = 1, extra = {} })
	assert(read.daily == true and read.orders == 3, "geçerli alanlar okunur")
	assert(
		read.merchant == nil and read.golden == nil and read.extra == nil,
		"yanlış türlü ve bilinmeyen alan atılır"
	)
	assert(Lines.readExtras({ orders = 0 / 0 }).orders == nil, "NaN sipariş atılır")
	assert(Lines.readExtras({ orders = -2 }).orders == nil, "negatif sipariş atılır")
	assert(Lines.readExtras({ orders = math.huge }).orders == nil, "sonsuz sipariş atılır")
	assert(Lines.readExtras({ orders = 100000 }).orders == 99, "sipariş üst sınırlı")

	-- Sınır ipucu: yalnızca sunucu `capped = true` derse kazanç satırında görünür; yanlış türlü değer atılır
	assert(Lines.readExtras({ capped = true }).capped == true, "capped okunur")
	assert(Lines.readExtras({ capped = "yes" }).capped == nil, "yanlış türlü capped atılır")
	local plainLine = Lines.build({ earned = 10, earnedText = "10", grown = 0, animalIcon = "🐄", recipes = {} })[1]
	local cappedLine =
		Lines.build({ earned = 10, earnedText = "10", grown = 0, animalIcon = "🐄", recipes = {}, capped = true })[1]
	assert(plainLine.detail == "Kasana eklendi", "sınır yokken ayrıntı kısa kalır")
	assert(
		cappedLine.text == plainLine.text and cappedLine.detail ~= plainLine.detail,
		"sınırda aynı kazanç satırı, ek açıklamayla"
	)
end
