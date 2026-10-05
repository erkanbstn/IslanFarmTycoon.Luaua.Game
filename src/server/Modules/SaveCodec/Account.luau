--!strict
-- Hesap düzeyi alanlar (hepsi isteğe bağlı): dil, grafik, ses/hareket tercihleri, ömür boyu kazanç, günlük seri,
-- mevsim hedefi, gezgin tüccar, altın hayvan, başarımlar ve makbuzlar. Bozuk alan sessizce atılır.
local SessionLock = require(script.Parent.Parent.SessionLock)
local Preferences = require(script.Parent.Parent.Preferences)
local Common = require(script.Parent.Common)

local Account = {}

local function decodeDaily(daily: any, config: any): any?
	if
		typeof(daily) == "table"
		and SessionLock.isFinite(daily.day)
		and SessionLock.isFinite(daily.streak)
		and daily.day >= 0
		and daily.day <= 1e7
		and daily.day % 1 == 0
		and daily.streak >= 1
		and daily.streak <= #config.DAILY_REWARD_MULTIPLIERS
		and daily.streak % 1 == 0
	then
		return { day = daily.day, streak = daily.streak }
	end
	return nil
end

-- Mevsim hedefi: bozuk kayıt sessizce atılır, yeni mevsimde yenisi oluşur
local function decodeSeasonal(seasonal: any): any?
	if
		typeof(seasonal) == "table"
		and SessionLock.isFinite(seasonal.key)
		and seasonal.key >= 0
		and seasonal.key <= 1e9
		and seasonal.key % 1 == 0
		and SessionLock.isFinite(seasonal.progress)
		and seasonal.progress >= 0
		and seasonal.progress <= 1e15
		and SessionLock.isFinite(seasonal.target)
		and seasonal.target > 0
		and seasonal.target <= 1e15
		and SessionLock.isFinite(seasonal.base)
		and seasonal.base >= 0
		and seasonal.base <= 1e18
		and typeof(seasonal.claimed) == "boolean"
	then
		return {
			key = seasonal.key,
			progress = math.min(seasonal.progress, seasonal.target),
			target = seasonal.target,
			base = seasonal.base,
			claimed = seasonal.claimed,
		}
	end
	return nil
end

-- Gezgin tüccar: yalnızca geçerli döngü numarası ve alındı işareti kabul edilir
local function decodeMerchant(merchant: any): any?
	if
		typeof(merchant) == "table"
		and SessionLock.isFinite(merchant.key)
		and merchant.key >= 0
		and merchant.key <= 1e9
		and merchant.key % 1 == 0
		and typeof(merchant.bought) == "boolean"
	then
		return { key = merchant.key, bought = merchant.bought }
	end
	return nil
end

-- Altın hayvan: yalnızca geçerli döngü numarası kabul edilir
local function decodeGolden(golden: any): any?
	if
		typeof(golden) == "table"
		and SessionLock.isFinite(golden.key)
		and golden.key >= 0
		and golden.key <= 1e9
		and golden.key % 1 == 0
	then
		return { key = golden.key }
	end
	return nil
end

-- Öğretici aşaması: sonlu sayı -> 0..sınır arası tam sayı; başka her şey nil (alan yoksa 0 sayılır). Kayda yazarken
-- (`encodeStage`) yalnız sonlu, negatif olmayan tam sayı ve sert üst sınır uygulanır; asıl sınır okurken Config'ten gelir.
function Account.decodeStage(value: unknown, total: number): number?
	if typeof(value) ~= "number" or not SessionLock.isFinite(value) then
		return nil
	end
	return math.clamp(math.floor(value), 0, total)
end

function Account.encodeStage(value: unknown): number?
	return Account.decodeStage(value, 100)
end

-- `source` ham kök kayıt; sonuçlar `data` köküne yazılır.
function Account.decode(source: any, data: any, config: any)
	-- Arayüz dili: yalnızca Config.LANGUAGES'taki kodlar kabul edilir; bilinmeyen değer yok sayılır.
	if typeof(source.language) == "string" and config.LANGUAGES and config.LANGUAGES[source.language] then
		data.language = source.language
	end
	-- Grafik tercihi: yalnızca bilinen modlar kabul edilir
	if typeof(source.graphics) == "string" and config.GRAPHICS_MODES and config.GRAPHICS_MODES[source.graphics] then
		data.graphics = source.graphics
	end
	-- Ses düzeyleri ve hareket azaltma: yalnızca geçerli değerler; bozuk alan yok sayılır
	data.audio, data.reducedMotion = Preferences.decode(source)
	-- Hesap düzeyi ilerleme: ömür boyu kazanç, günlük ödül serisi ve alınmış başarımlar (hepsi isteğe bağlı).
	data.lifetimeEarned = Common.amount(source.lifetimeEarned, 0)
	-- Öğretici: işaret yoksa ve hesap temel adımları çoktan geçmişse (öğretici işaretinden önceki kayıt) bitmiş sayılır.
	-- Açık true/false korunur; bozuk değer yok sayılır (yeni hesap ve eşik altı eski kayıt etkilenmez). Sürüm artmaz.
	local tutorialDone = Preferences.decodeTutorialDone(source)
	if tutorialDone == nil and data.lifetimeEarned >= config.ONBOARDING.SKIP_BASICS_EARNED then
		tutorialDone = true
	end
	data.tutorialDone = tutorialDone
	data.tutorialStage = Account.decodeStage(source.tutorialStage, config.ONBOARDING.TOTAL_STEPS)
	local daily = decodeDaily(source.daily, config)
	if daily then
		data.daily = daily
	end
	local seasonal = decodeSeasonal(source.seasonal)
	if seasonal then
		data.seasonal = seasonal
	end
	local merchant = decodeMerchant(source.merchant)
	if merchant then
		data.merchant = merchant
	end
	local golden = decodeGolden(source.golden)
	if golden then
		data.golden = golden
	end
end

-- Başarımlar ve makbuzlar (Inventory'den sonra, kök kayda yazılır).
function Account.decodeLedger(source: any, data: any, config: any)
	local achievements: { [string]: boolean } = {}
	if typeof(source.achievements) == "table" then
		for _, achievement in config.ACHIEVEMENTS do
			if source.achievements[achievement.id] == true then
				achievements[achievement.id] = true
			end
		end
	end
	data.achievements = achievements
	-- Eski geçerli kimlikler kırpılmaz: silinmiş makbuzun yeniden gelmesi ikinci ödül üretir.
	local receipts: { string } = {}
	local seen: { [string]: boolean } = {}
	if typeof(source.receipts) == "table" then
		for _, id in source.receipts do
			if typeof(id) == "string" and #id > 0 and #id <= 40 and not seen[id] then
				seen[id] = true
				table.insert(receipts, id)
			end
		end
	end
	data.receipts = receipts
end

return Account
