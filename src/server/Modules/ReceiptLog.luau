--!strict
-- Satın alma makbuz günlüğü (saf): Roblox aynı makbuzu birden fazla kez gönderebilir; ödül yalnızca bir kez
-- verilmelidir. Günlük kayıtta tutulur ve sınırlıdır (en eski silinir).

local ReceiptLog = {}

ReceiptLog.MAX = 200

function ReceiptLog.has(save: any, id: string): boolean
	local receipts = save.receipts
	return receipts ~= nil and table.find(receipts, id) ~= nil
end

-- Yeni makbuzu ekler; zaten varsa false döner (tekrar ödül verilmez).
function ReceiptLog.add(save: any, id: string): boolean
	if #id == 0 or #id > 40 then
		return false
	end
	local receipts = save.receipts
	if not receipts then
		receipts = {}
		save.receipts = receipts
	end
	if table.find(receipts, id) then
		return false
	end
	table.insert(receipts, id)
	while #receipts > ReceiptLog.MAX do
		table.remove(receipts, 1)
	end
	return true
end

return ReceiptLog
