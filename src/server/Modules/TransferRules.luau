--!strict
-- Oyuncudan oyuncuya para gönderme kuralları (saf mantık). Tutar, bakiye ve alıcı sınırı sunucuda burada doğrulanır;
-- istemci yalnızca hedef ve tutar önerir. Para yok olmaz/çoğalmaz: gönderenden düşen tutar alıcıya aynen eklenir.
local TransferRules = {}

TransferRules.MIN_AMOUNT = 1
TransferRules.MAX_AMOUNT = 1e12
TransferRules.CASH_CAP = 1e15 -- PlayerDataService bakiye tavanı ile aynı
TransferRules.COOLDOWN = 2 -- aynı oyuncunun iki gönderimi arası (sn)

function TransferRules.validAmount(value: unknown): boolean
	return typeof(value) == "number"
		and value == value
		and value >= TransferRules.MIN_AMOUNT
		and value <= TransferRules.MAX_AMOUNT
		and value % 1 == 0
end

function TransferRules.validUserId(value: unknown): boolean
	return typeof(value) == "number" and value == value and value >= 1 and value <= 2 ^ 53 and value % 1 == 0
end

-- (izin, hata metni). Bakiyeler aynı adımda okunmuş olmalı (önce kazanç kapanır, sonra çağır).
function TransferRules.check(senderCash: number, receiverCash: number, amount: number): (boolean, string?)
	if amount > senderCash then
		return false, "Bakiyen yetmiyor"
	end
	if receiverCash + amount > TransferRules.CASH_CAP then
		return false, "Alıcının kasası bu tutarı alamaz"
	end
	return true, nil
end

return TransferRules
