--!strict
-- Kayıt yedeği ve boyut ölçümü için saf yardımcılar. Yedek, asıl kayıttan ayrı iki anahtara (dönüşümlü) yazılır;
-- oturum kilidi ve revizyon içermez. Bozuk asıl kayıt yedekten kurtarılırken önce "karantina" anahtarına kopyalanır.
local SaveBackup = {}

export type RawSave = { [string]: any }

SaveBackup.SLOTS = 2
SaveBackup.INTERVAL_SECONDS = 600
-- DataStore değer sınırı 4.194.304 bayttır; uyarı eşikleri buna göre seçilir.
SaveBackup.SIZE_WARN_BYTES = 3000000
SaveBackup.SIZE_CRITICAL_BYTES = 3800000

function SaveBackup.slotKey(baseKey: string, slot: number): string
	return `{baseKey}_backup{slot}`
end

function SaveBackup.quarantineKey(baseKey: string): string
	return `{baseKey}_quarantine`
end

function SaveBackup.sizeLevel(bytes: number): string
	if bytes >= SaveBackup.SIZE_CRITICAL_BYTES then
		return "critical"
	elseif bytes >= SaveBackup.SIZE_WARN_BYTES then
		return "warn"
	end
	return "ok"
end

function SaveBackup.due(now: number, lastBackupAt: number): boolean
	return now - lastBackupAt >= SaveBackup.INTERVAL_SECONDS
end

function SaveBackup.nextSlot(current: number): number
	return current % SaveBackup.SLOTS + 1
end

-- Yazılan kayıttan yedek: oturum/revizyon alanları atılır, yedek zamanı eklenir.
function SaveBackup.stamp(payload: RawSave, now: number): RawSave
	local copy = table.clone(payload)
	copy._session = nil
	copy._lastWrite = nil
	copy._revision = nil
	copy._backupAt = now
	return copy
end

-- En yeniden eskiye: geçerli (tablo) adaylar `_backupAt`'e göre sıralanır.
function SaveBackup.newestFirst(candidates: { unknown }): { RawSave }
	local valid: { RawSave } = {}
	for _, candidate in candidates do
		if typeof(candidate) == "table" then
			table.insert(valid, candidate :: RawSave)
		end
	end
	table.sort(valid, function(a: RawSave, b: RawSave): boolean
		local left = if typeof(a._backupAt) == "number" then a._backupAt else 0
		local right = if typeof(b._backupAt) == "number" then b._backupAt else 0
		return left > right
	end)
	return valid
end

return SaveBackup
