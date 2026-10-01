--!strict
-- Hayvanın süreli görevi (üretim/eklenti) için şema sınırı.
local SessionLock = require(script.Parent.Parent.SessionLock)

local Tasks = {}
local MAX_TASK_SECONDS = 86400

-- Bozuk ya da tanınmayan kayıt görev yok sayılır (hayvan korunur).
function Tasks.decodeTask(value: any, config: any): any?
	if typeof(value) ~= "table" then
		return nil
	end
	local kind, id = value.kind, value.id
	if (kind ~= "production" and kind ~= "extension") or typeof(id) ~= "string" then
		return nil
	end
	if
		(kind == "production" and not config.PRODUCTION_RECIPES[id])
		or (kind == "extension" and not config.getExtension(id))
	then
		return nil
	end
	local startedAt, endsAt = value.startedAt, value.endsAt
	if
		not SessionLock.isFinite(startedAt)
		or not SessionLock.isFinite(endsAt)
		or startedAt < 0
		or endsAt <= startedAt
		or endsAt > 1e12
		or endsAt - startedAt > MAX_TASK_SECONDS
	then
		return nil
	end
	return { kind = kind, id = id, startedAt = startedAt, endsAt = endsAt }
end

return Tasks
