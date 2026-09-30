--!strict
-- Para ve hız biçimlendirme (formatMoney: 10.000'e kadar tam, üstü kısaltılır).
-- FarmMath cephesi (init.luau) bunları birleştirir; her zaman `FarmMath.<ad>` ile kullan.

local Format = {}

local MONEY_SUFFIXES = { "K", "M", "B", "T", "Qa" }

local MONEY_ABBREVIATE_FROM = 10000

-- 9999 -> "$9,999" · 12400 -> "$12.4K" · 3100000 -> "$3.1M" · 250000 -> "$250K"
-- 10.000'e kadar tam sayı okunur; üstü kısaltılır. Bir basamak ondalık yalnızca 100'ün altında gösterilir.
function Format.formatMoney(amount: number): string
	if amount ~= amount then
		return "$0"
	end
	local value = math.floor(amount)
	local sign = if value < 0 then "-" else ""
	local absolute = math.abs(value)
	if absolute < MONEY_ABBREVIATE_FROM then
		local formatted = tostring(absolute)
		while true do
			local replaced, count = string.gsub(formatted, "^(%d+)(%d%d%d)", "%1,%2")
			formatted = replaced
			if count == 0 then
				break
			end
		end
		return `{sign}${formatted}`
	end
	local scaled = absolute
	local index = 0
	while scaled >= 1000 and index < #MONEY_SUFFIXES do
		scaled /= 1000
		index += 1
	end
	-- Yuvarlama 999.95K -> 1000K gibi taşmalara yol açmasın: bir üst birime geç.
	local text = if scaled < 100 then string.format("%.1f", scaled) else string.format("%.0f", scaled)
	if tonumber(text) :: number >= 1000 and index < #MONEY_SUFFIXES then
		scaled /= 1000
		index += 1
		text = string.format("%.1f", scaled)
	end
	text = (string.gsub(text, "%.0$", ""))
	return `{sign}${text}{MONEY_SUFFIXES[index]}`
end

-- 2 -> "2", 2.345 -> "2.3"
function Format.formatRate(rate: number): string
	if rate == math.floor(rate) then
		return tostring(rate)
	end
	return string.format("%.1f", rate)
end

return Format
