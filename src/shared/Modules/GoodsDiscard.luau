--!strict
-- Ahır deposundaki ürünü KALICI silme kuralları (saf; sunucu doğrulaması ve istemci miktar seçici aynı kaynağı kullanır).
-- Yalnız ürün ADEDİ silinir. Ekipman ve kalıcı haklar (altın/Robux ile alınanlar dahil) tek parçadır ve silinemez;
-- bunlar için silme Remote'u ve düğmesi yoktur.

local GoodsDiscard = {}

export type QuickKind = "one" | "ten" | "half" | "all"

-- Sunucu doğrulaması: sonlu, tam sayı, 1..available. Geçersizse nil (sayı olmayan, NaN, sonsuz, kesirli, <1, fazla).
function GoodsDiscard.validAmount(amount: unknown, available: number): number?
	if typeof(amount) ~= "number" or amount ~= amount or amount % 1 ~= 0 then
		return nil
	end
	if amount < 1 or amount > available or available < 1 then
		return nil
	end
	return amount
end

-- İstemci seçici: herhangi bir değeri 1..available tam sayıya sıkıştırır; hiç ürün yoksa 0.
function GoodsDiscard.clamp(value: unknown, available: number): number
	if available < 1 then
		return 0
	end
	if typeof(value) ~= "number" or value ~= value then
		return 1
	end
	return math.clamp(math.floor(value), 1, math.floor(available))
end

-- Yazılan metin (kutu); sayıya çevrilemezse nil.
function GoodsDiscard.parseText(text: string, available: number): number?
	local value = tonumber(text)
	if value == nil then
		return nil
	end
	return GoodsDiscard.clamp(value, available)
end

-- Hızlı düğmeler: 1 / 10 / yarısı (yukarı yuvarlanır, Hızlı satıştaki "yarısı" gibi) / hepsi.
-- `kind`: QuickKind değerlerinden biri (düğme tabloları metin anahtarlı olduğundan tür string kabul edilir; bilinmeyen = 1)
function GoodsDiscard.quick(kind: string, available: number): number
	if kind == "one" then
		return GoodsDiscard.clamp(1, available)
	elseif kind == "ten" then
		return GoodsDiscard.clamp(10, available)
	elseif kind == "half" then
		return GoodsDiscard.clamp(math.ceil(available / 2), available)
	elseif kind == "all" then
		return GoodsDiscard.clamp(available, available)
	end
	-- Bilinmeyen düğme türü yıkıcı işlemde en güvenli seçime (1 adet) düşer
	return GoodsDiscard.clamp(1, available)
end

return GoodsDiscard
