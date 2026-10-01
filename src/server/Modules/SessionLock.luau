--!strict
-- Saf DataStore dönüşümleri: callback tekrar çalışabilir; hiçbir yordam yield etmez.
local SessionLock = {}

export type RawSave = { [string]: any }
local VERSION = 4
SessionLock.VERSION = VERSION -- kayıt şema sürümünün tek kaynağı (SaveCodec de bunu kullanır)
local MAX_REVISION = 9007199254740990
-- acquire'ın "kilit başka sunucuda" reddi; çağıran bunu bekleyip yeniden deneyebilir.
SessionLock.HELD = "Profil başka bir sunucuda açık"

function SessionLock.isFinite(value: unknown): boolean
	return typeof(value) == "number" and value == value and math.abs(value :: number) < math.huge
end

function SessionLock.validate(raw: unknown): string?
	if raw == nil then
		return nil
	end
	if typeof(raw) ~= "table" then
		return "Kayıt biçimi geçersiz"
	end
	local version = (raw :: RawSave).version
	if
		version ~= nil and (not SessionLock.isFinite(version) or version % 1 ~= 0 or version < 1 or version > VERSION)
	then
		return "Kayıt sürümü desteklenmiyor"
	end
	local session = (raw :: RawSave)._session
	if
		session ~= nil
		and (
			typeof(session) ~= "table"
			or typeof(session.owner) ~= "string"
			or not SessionLock.isFinite(session.expiresAt)
		)
	then
		return "Kayıt oturumu geçersiz"
	end
	local revision = (raw :: RawSave)._revision
	if
		revision ~= nil
		and (not SessionLock.isFinite(revision) or revision < 0 or revision > MAX_REVISION or revision % 1 ~= 0)
	then
		return "Kayıt revizyonu geçersiz"
	end
	return nil
end

function SessionLock.owns(raw: unknown, owner: string, now: number): boolean
	if typeof(raw) ~= "table" then
		return false
	end
	local session = (raw :: RawSave)._session
	return typeof(session) == "table"
		and session.owner == owner
		and SessionLock.isFinite(session.expiresAt)
		and session.expiresAt > now
end

-- Kira süresi dolmuş olsa bile kilit hâlâ bizim mi? Başka sunucu ancak `_session.owner`'ı değiştirerek devralabilir
-- (acquire), bu yüzden sahip + revizyon eşleşiyorsa yazmak güvenlidir.
function SessionLock.holds(raw: unknown, owner: string): boolean
	if typeof(raw) ~= "table" then
		return false
	end
	local session = (raw :: RawSave)._session
	return typeof(session) == "table" and session.owner == owner
end

function SessionLock.acquire(raw: unknown, owner: string, now: number, leaseSeconds: number): (RawSave?, string?)
	local problem = SessionLock.validate(raw)
	if problem then
		return nil, problem
	end
	local current: RawSave = if typeof(raw) == "table" then raw :: RawSave else {}
	local session = current._session
	if session and session.owner ~= owner and session.expiresAt > now then
		return nil, SessionLock.HELD
	end
	local result = table.clone(current)
	result._session = { owner = owner, expiresAt = now + leaseSeconds }
	result._revision = current._revision or 0
	return result, nil
end

-- Aynı token ile cevabı kaybolan yazma tekrarlandığında ikinci kez revizyon artırılmaz.
function SessionLock.commit(
	raw: unknown,
	owner: string,
	revision: number,
	token: string,
	payload: RawSave,
	now: number,
	leaseSeconds: number,
	release: boolean
): (RawSave?, string?)
	local problem = SessionLock.validate(raw)
	if problem or typeof(raw) ~= "table" then
		return nil, problem or "Kayıt bulunamadı"
	end
	local current = raw :: RawSave
	if current._lastWrite == token then
		return current, nil
	end
	if (current._revision or 0) >= MAX_REVISION then
		return nil, "Kayıt revizyon sınırına ulaştı"
	end
	if not SessionLock.holds(current, owner) or (current._revision or 0) ~= revision then
		return nil, "Kayıt oturumunun sahipliği kaybedildi"
	end
	local result = table.clone(payload)
	result.version = VERSION
	result._revision = revision + 1
	result._lastWrite = token
	result._session = if release then nil else { owner = owner, expiresAt = now + leaseSeconds }
	return result, nil
end

return SessionLock
