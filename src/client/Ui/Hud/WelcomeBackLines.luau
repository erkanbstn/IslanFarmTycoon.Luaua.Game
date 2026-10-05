--!strict
-- Dönüş özeti satırları (saf, Roblox'a dokunmaz): hangi satırlar hangi sırayla görünür. Boş satır yoktur;
-- pencere kompakt kalsın diye en çok MAX_LINES (= tüm olası satırlar) satır döner (sıra: kazanç, büyüme, üretim, günlük, sipariş, tüccar, altın hayvan).
-- Ek alanlar sunucudan isteğe bağlı gelir (eski sunucuda yok); biçimlendirme/ikon seçimi çağıran tarafındadır.

export type Line = { icon: string, text: string, detail: string? }

export type Extras = { daily: boolean?, orders: number?, merchant: boolean?, golden: boolean? }

export type Input = {
	earned: number,
	earnedText: string, -- önceden biçimlendirilmiş tutar (FarmMath.formatMoney)
	grown: number,
	animalIcon: string,
	recipes: { string }, -- hazır üretim adları
	daily: boolean?,
	orders: number?,
	merchant: boolean?,
	golden: boolean?,
}

local WelcomeBackLines = {}

WelcomeBackLines.MAX_LINES = 7
-- Satır sayısı bunu aşarsa ayrıntı satırları gizlenir (pencere dar telefonda kompakt kalsın).
WelcomeBackLines.DETAIL_LIMIT = 4

function WelcomeBackLines.showDetails(lineCount: number): boolean
	return lineCount <= WelcomeBackLines.DETAIL_LIMIT
end

-- Sunucudan gelen isteğe bağlı üçüncü bağımsız değişken: tablo değilse boş; yanlış türlü alan atılır (sınırlar sunucununkiyle aynı).
function WelcomeBackLines.readExtras(value: unknown): Extras
	if typeof(value) ~= "table" then
		return {}
	end
	local raw = value :: any
	local orders = raw.orders
	local extras: Extras = {}
	if raw.daily == true then
		extras.daily = true
	end
	if typeof(orders) == "number" and orders == orders and orders >= 1 and orders < math.huge then
		extras.orders = math.min(99, math.floor(orders))
	end
	if raw.merchant == true then
		extras.merchant = true
	end
	if raw.golden == true then
		extras.golden = true
	end
	return extras
end

function WelcomeBackLines.build(input: Input): { Line }
	local lines: { Line } = {}
	if input.earned > 0 then
		table.insert(lines, { icon = "💰", text = `+{input.earnedText} kazandın`, detail = "Kasana eklendi" })
	end
	if input.grown > 0 then
		table.insert(lines, {
			icon = input.animalIcon,
			text = `{input.grown} hayvan büyüdü`,
			detail = "Yetişkin hayvanlar daha çok kazandırır",
		})
	end
	if #input.recipes > 0 then
		table.insert(lines, {
			icon = "🏭",
			text = `{table.concat(input.recipes, ", ")} hazır`,
			detail = "Üretim menüsünden topla",
		})
	end
	if input.daily == true then
		table.insert(lines, { icon = "🎁", text = "Günlük ödülün hazır", detail = "Ödüller menüsünden al" })
	end
	local orders = input.orders
	if typeof(orders) == "number" and orders >= 1 then
		table.insert(lines, {
			icon = "📦",
			text = `{math.floor(orders)} sipariş teslime hazır`,
			detail = "Siparişler menüsünden teslim et",
		})
	end
	if input.merchant == true then
		table.insert(
			lines,
			{ icon = "🧳", text = "Gezgin tüccar meydanda", detail = "İndirimli eşyalara göz at" }
		)
	end
	if input.golden == true then
		table.insert(lines, { icon = "⭐", text = "Altın hayvan parlıyor", detail = "Dokunup ödülünü al" })
	end
	while #lines > WelcomeBackLines.MAX_LINES do
		table.remove(lines)
	end
	return lines
end

return WelcomeBackLines
