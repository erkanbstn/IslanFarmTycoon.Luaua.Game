--!strict
-- Meydan sıralama tabloları için saf mantık (Roblox'a dokunmaz): değer hesabı, sıralama, ad temizliği ve zamanlama.
-- Değerler yalnızca sunucudaki kayıttan hesaplanır; istemciden değer alınmaz. Yönetici hesabı hiç listelenmez.
-- Genel (tüm sunucular) tablolar OrderedDataStore'a SaveStore üzerinden yazılır/okunur; burası yalnızca karar verir.

local Leaderboard = {}

-- Genel tablolar: kimlik -> kayıtlı değerin anlamı. Yeni tablo eklemek SaveStore.RANK_BOARDS listesini de gerektirir.
Leaderboard.BOARDS = { "rebirth", "farms" }
Leaderboard.MAX_SCORE = 1e9
Leaderboard.NAME_MAX = 16
Leaderboard.FALLBACK_NAME = "Oyuncu"

-- Zamanlama (saniye): yazma, aynı değeri tekrar yazmaz ve en az bu aralıkla yapılır; okuma önbelleklidir.
Leaderboard.PUBLISH_INTERVAL = 120
Leaderboard.READ_INTERVAL = 90
Leaderboard.BACKOFF_MAX = 600

function Leaderboard.isBoard(id: unknown): boolean
	return id == "rebirth" or id == "farms"
end

-- Sonlu, negatif olmayan tam sayı (üst sınırlı); NaN/inf/negatif/yanlış tür nil.
function Leaderboard.sanitizeScore(value: unknown): number?
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	local score = math.floor(value)
	if score < 0 then
		return nil
	end
	return math.min(score, Leaderboard.MAX_SCORE)
end

-- Tablo değeri: rebirth = tamamlanan tur sayısı; farms = tamamlanmış çiftlik toplamı (her tur `farmsTotal` çiftlik + bu turdaki).
-- `userId` yönetici/hariç tutulan hesapta nil döner. `progress` Progression.progress(kayıt) sonucudur (farmsComplete/farmsTotal).
function Leaderboard.score(boardId: unknown, save: any, progress: any, excluded: boolean?): number?
	if excluded == true or typeof(save) ~= "table" then
		return nil
	end
	local count = 0
	if typeof(save.progression) == "table" then
		count = Leaderboard.sanitizeScore(save.progression.count) or 0
	end
	if boardId == "rebirth" then
		return count
	elseif boardId == "farms" then
		if typeof(progress) ~= "table" then
			return nil
		end
		local total = Leaderboard.sanitizeScore(progress.farmsTotal)
		local complete = Leaderboard.sanitizeScore(progress.farmsComplete)
		if total == nil or complete == nil then
			return nil
		end
		return Leaderboard.sanitizeScore(count * total + math.min(complete, total))
	end
	return nil
end

-- Görünen ad: kontrol karakterleri/satır sonları atılır, boşluklar sadeleşir, NAME_MAX karaktere (UTF-8 güvenli) kısaltılır.
function Leaderboard.cleanName(name: unknown): string
	if typeof(name) ~= "string" then
		return Leaderboard.FALLBACK_NAME
	end
	local text = string.gsub(name, "[%c]", " ")
	text = string.gsub(text, "%s+", " ")
	text = string.match(text, "^%s*(.-)%s*$") or ""
	if text == "" or not utf8.len(text) then
		return Leaderboard.FALLBACK_NAME
	end
	local length = utf8.len(text) :: number
	if length <= Leaderboard.NAME_MAX then
		return text
	end
	local cut = utf8.offset(text, Leaderboard.NAME_MAX) :: number
	return string.sub(text, 1, cut - 1) .. "…"
end

export type Entry = { userId: number, name: string, score: number }

local function validUserId(value: unknown): boolean
	return typeof(value) == "number" and value == value and value >= 1 and value <= 2 ^ 53 and value % 1 == 0
end

-- Aynı kullanıcıyı tek satıra indirir (en yüksek değer), geçersiz satırı atar; değer azalan, eşitlikte ad (harf büyüklüğüne bakmadan)
-- ve kimlik artan sıralanır. En fazla `limit` satır döner.
function Leaderboard.rank(entries: { any }, limit: number): { Entry }
	local best: { [number]: Entry } = {}
	for _, raw in entries do
		if typeof(raw) == "table" and validUserId(raw.userId) then
			local score = Leaderboard.sanitizeScore(raw.score)
			if score ~= nil then
				local current = best[raw.userId]
				if not current or score > current.score then
					best[raw.userId] = { userId = raw.userId, name = Leaderboard.cleanName(raw.name), score = score }
				end
			end
		end
	end
	local list: { Entry } = {}
	for _, entry in best do
		table.insert(list, entry)
	end
	table.sort(list, function(a: Entry, b: Entry): boolean
		if a.score ~= b.score then
			return a.score > b.score
		end
		local an, bn = string.lower(a.name), string.lower(b.name)
		if an ~= bn then
			return an < bn
		end
		return a.userId < b.userId
	end)
	local maxRows = math.max(0, math.floor(limit))
	while #list > maxRows do
		table.remove(list)
	end
	return list
end

-- Kayıtlı (genel) satırları sunucudaki canlı değerlerle birleştirir: sunucudaki oyuncunun canlı değeri kayıtlıyı ezer
-- (düşüş de yansır; ör. sıfırlanmış hesap). `names` kimlik -> görünen ad.
function Leaderboard.merge(stored: { any }, live: { [number]: number }, names: { [number]: string }): { Entry }
	local merged: { any } = {}
	for _, row in stored do
		if typeof(row) == "table" and validUserId(row.userId) and live[row.userId] == nil then
			table.insert(merged, { userId = row.userId, name = names[row.userId], score = row.score })
		end
	end
	for userId, score in live do
		table.insert(merged, { userId = userId, name = names[userId], score = score })
	end
	return Leaderboard.rank(merged, math.huge)
end

-- Yayın zamanlaması: aynı değer yazılmaz; değişimde en az aralık beklenir; hatada üstel geri çekilme.
export type Schedule = {
	due: (now: number) -> boolean,
	success: (now: number, value: unknown?) -> (),
	failure: (now: number) -> (),
	lastValue: () -> unknown,
	failures: () -> number,
}

function Leaderboard.newSchedule(interval: number): Schedule
	local lastAt = -math.huge
	local failures = 0
	local nextAt = -math.huge
	local lastValue: unknown = nil
	local function due(now: number): boolean
		return now >= nextAt and now - lastAt >= interval
	end
	return {
		due = due,
		success = function(now: number, value: unknown?)
			lastAt = now
			failures = 0
			nextAt = now + interval
			lastValue = value
		end,
		failure = function(now: number)
			failures += 1
			nextAt = now + math.min(Leaderboard.BACKOFF_MAX, interval * 2 ^ (failures - 1))
		end,
		lastValue = function(): unknown
			return lastValue
		end,
		failures = function(): number
			return failures
		end,
	}
end

-- Yazma gerekli mi: değer değişmiş ve zamanlama uygunsa
function Leaderboard.shouldPublish(schedule: Schedule, value: number, now: number): boolean
	return value ~= schedule.lastValue() and schedule.due(now)
end

return Leaderboard
