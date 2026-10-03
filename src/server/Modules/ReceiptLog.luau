--!strict
-- Satın alma makbuz günlüğü (saf): Roblox aynı makbuzu birden fazla kez gönderebilir; ödül yalnızca bir kez
-- verilmelidir. Eski kimlikler silinmez; kapasite dolduğunda yeni ödül kayıt büyütmeden bekletilir.

local ReceiptLog = {}

-- En uzun kimliklerde yaklaşık 860 KB JSON: çiftlik verisi için kayıt bütçesi bırakır.
ReceiptLog.MAX = 20000

function ReceiptLog.isFull(save: any): boolean
	return save.receipts ~= nil and #save.receipts >= ReceiptLog.MAX
end

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
	if ReceiptLog.isFull(save) then
		return false
	end
	table.insert(receipts, id)
	return true
end

-- Eklenen makbuzu geri alır (ödül verilemediğinde Roblox'un yeniden denemesinde ödül verilebilsin).
function ReceiptLog.remove(save: any, id: string)
	local receipts = save.receipts
	local index = if receipts then table.find(receipts, id) else nil
	if receipts and index then
		table.remove(receipts, index)
	end
end

-- Makbuzu yazar ve ödülü uygular. "duplicate": zaten işlenmiş; "granted": ödül verildi; "full": kapasite dolu;
-- "failed": ödül verilemedi
-- (makbuz günlükten çıkarılır, ödülsüz "işlenmiş" görünmez).
function ReceiptLog.grant(save: any, id: string, apply: () -> boolean): string
	if ReceiptLog.has(save, id) then
		return "duplicate"
	end
	if ReceiptLog.isFull(save) then
		return "full"
	end
	if not ReceiptLog.add(save, id) then
		return "failed"
	end
	local ok, applied = pcall(apply)
	if ok and applied == true then
		return "granted"
	end
	ReceiptLog.remove(save, id)
	return "failed"
end

return ReceiptLog
