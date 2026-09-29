--!strict
-- Arayüz dili: kaynak metin Türkçedir; diğer diller Locales/<kod>.luau sözlüklerinden çevrilir.
-- Kodun geri kalanı Türkçe yazmaya devam eder, client'taki Localizer ekrandaki yazıları çevirir.
--
-- Sözlük anahtarı Türkçe metindir:
--   ["Pazar"] = "Market"                        → tam eşleşme
--   ["Önce: {}"] = "First: {1}"                 → şablon; {} yakalanır, {1} {2}... hedefte yerine konur
-- Yakalanan parçalar da (ör. hayvan adı) ayrıca çevrilir. Eşleşme yoksa " · ", satır sonu ve ", "
-- ile bölünüp parça parça denenir; hiçbiri çevrilemezse metin olduğu gibi kalır.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(script.Parent:WaitForChild("Config"))

local SOURCE = "tr"
local MAX_DEPTH = 6
local MAX_CACHE = 3000
local STRONG_SEPARATORS = { "\n", " · " }

type Template = { prefix: string, pattern: string, count: number, target: string }
type Dictionary = {
	exact: { [string]: string },
	strong: { Template }, -- Anahtarı " · " veya satır sonu içeren şablonlar: bölmeden önce denenir
	weak: { Template },
	cache: { [string]: string },
	cacheSize: number,
}

local Localization = {}
Localization.SOURCE = SOURCE

local dictionaries: { [string]: Dictionary } = {}
local listeners: { [() -> ()]: boolean } = {}
local current = Config.DEFAULT_LANGUAGE
local remoteSetter: ((string) -> ())? = nil

local function escapePattern(text: string): string
	return (string.gsub(text, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

local function compile(source: { [string]: string }): Dictionary
	local dictionary: Dictionary = { exact = {}, strong = {}, weak = {}, cache = {}, cacheSize = 0 }
	local weights: { [Template]: number } = {}
	for key, value in source do
		if string.find(key, "{}", 1, true) then
			local literals = string.split(key, "{}")
			local escaped = {}
			local total = 0
			for index, literal in literals do
				escaped[index] = escapePattern(literal)
				total += #literal
			end
			local template: Template = {
				prefix = literals[1],
				pattern = "^" .. table.concat(escaped, "(.-)") .. "$",
				count = #literals - 1,
				target = value,
			}
			weights[template] = total
			local isStrong = string.find(key, " · ", 1, true) ~= nil or string.find(key, "\n", 1, true) ~= nil
			table.insert(if isStrong then dictionary.strong else dictionary.weak, template)
		else
			dictionary.exact[key] = value
		end
	end
	-- Uzun (özel) şablonlar önce denenir: "Önce: {}" gibi kısa şablonlar hepsini yutmasın.
	local function byWeight(a: Template, b: Template): boolean
		local wa, wb = weights[a], weights[b]
		if wa ~= wb then
			return wa > wb
		end
		return a.pattern < b.pattern
	end
	table.sort(dictionary.strong, byWeight)
	table.sort(dictionary.weak, byWeight)
	return dictionary
end

local function dictionaryFor(code: string): Dictionary?
	local existing = dictionaries[code]
	if existing then
		return existing
	end
	local folder = script.Parent:FindFirstChild("Locales")
	local module = folder and folder:FindFirstChild(code)
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, source = pcall(require, module)
	if not ok or typeof(source) ~= "table" then
		warn(`[Localization] {code} sözlüğü yüklenemedi: {source}`)
		return nil
	end
	local dictionary = compile(source :: { [string]: string })
	dictionaries[code] = dictionary
	return dictionary
end

local translateCore: (string, Dictionary, number) -> string

local function translateSplit(text: string, separators: { string }, dictionary: Dictionary, depth: number): string?
	for _, separator in separators do
		if string.find(text, separator, 1, true) then
			local parts = string.split(text, separator)
			local changed = false
			for index, part in parts do
				local translated = translateCore(part, dictionary, depth + 1)
				if translated ~= part then
					changed = true
					parts[index] = translated
				end
			end
			if changed then
				return table.concat(parts, separator)
			end
		end
	end
	return nil
end

local function translateTemplates(body: string, templates: { Template }, dictionary: Dictionary, depth: number): string?
	for _, template in templates do
		if template.prefix ~= "" and string.sub(body, 1, #template.prefix) ~= template.prefix then
			continue
		end
		local captures = { string.match(body, template.pattern) }
		if captures[1] ~= nil then
			local result = string.gsub(template.target, "{(%d)}", function(number: string)
				local capture = captures[tonumber(number) :: number]
				return if capture then translateCore(capture, dictionary, depth + 1) else ""
			end)
			return result
		end
	end
	return nil
end

-- Sıra: tam eşleşme → " · "/satır içeren şablon → " · "/satır sonuyla bölme → şablon → ", " ile bölme.
-- Ayraçlar şablondan önce bölünür ki "{}/{} levrek" gibi şablon başka parçaları yutmasın.
function translateCore(text: string, dictionary: Dictionary, depth: number): string
	if depth > MAX_DEPTH or text == "" then
		return text
	end
	local lead, body, trail = string.match(text, "^(%s*)(.-)(%s*)$")
	if not body or body == "" then
		return text
	end
	-- Harf içermeyen metinler (sayı, para, süre) çevrilmez.
	if not string.find(body, "[%a\128-\255]") then
		return text
	end
	local result = dictionary.exact[body]
		or translateTemplates(body, dictionary.strong, dictionary, depth)
		or translateSplit(body, STRONG_SEPARATORS, dictionary, depth)
		or translateTemplates(body, dictionary.weak, dictionary, depth)
		or translateSplit(body, { ", " }, dictionary, depth)
	if result then
		return lead .. result .. trail
	end
	return text
end

-- <font ...>x3</font> gibi etiketleri koruyup yalnızca aradaki yazıları çevirir.
local function translateRich(text: string, dictionary: Dictionary): string
	local out = {}
	local position = 1
	while position <= #text do
		local tagStart = string.find(text, "<", position, true)
		if not tagStart then
			table.insert(out, translateCore(string.sub(text, position), dictionary, 0))
			break
		end
		local tagEnd = string.find(text, ">", tagStart, true)
		if not tagEnd then
			table.insert(out, string.sub(text, position))
			break
		end
		if tagStart > position then
			table.insert(out, translateCore(string.sub(text, position, tagStart - 1), dictionary, 0))
		end
		table.insert(out, string.sub(text, tagStart, tagEnd))
		position = tagEnd + 1
	end
	return table.concat(out)
end

function Localization.isSupported(code: unknown): boolean
	return typeof(code) == "string" and Config.LANGUAGES[code] ~= nil
end

-- Türkçe kaynak metni verilen dile çevirir (dil verilmezse geçerli dile).
function Localization.tr(text: string, code: string?): string
	local language = code or current
	if language == SOURCE or text == "" then
		return text
	end
	local dictionary = dictionaryFor(language)
	if not dictionary then
		return text
	end
	local cached = dictionary.cache[text]
	if cached then
		return cached
	end
	local result = if string.find(text, "<", 1, true)
		then translateRich(text, dictionary)
		else translateCore(text, dictionary, 0)
	if dictionary.cacheSize >= MAX_CACHE then
		dictionary.cache = {}
		dictionary.cacheSize = 0
	end
	dictionary.cache[text] = result
	dictionary.cacheSize += 1
	return result
end

function Localization.get(): string
	return current
end

function Localization.onChanged(listener: () -> ()): () -> ()
	listeners[listener] = true
	return function()
		listeners[listener] = nil
	end
end

local function apply(code: string)
	if code == current or not Localization.isSupported(code) then
		return
	end
	current = code
	for listener in listeners do
		task.spawn(listener)
	end
end

-- Roblox dili (LocaleId, ör. "tr-tr") öncelikli; desteklenmiyorsa ülkeden, o da yoksa varsayılan dil.
function Localization.detect(localeId: string?, country: string?): string
	local language = if localeId then string.lower(string.match(localeId, "^%a+") or "") else ""
	if Config.LANGUAGES[language] then
		return language
	end
	if country then
		local upper = string.upper(country)
		for _, code in Config.LANGUAGE_ORDER do
			if table.find(Config.LANGUAGES[code].countries, upper) then
				return code
			end
		end
	end
	return Config.DEFAULT_LANGUAGE
end

-- Oyuncu dili seçti: hemen uygula, sunucuya da kaydettir (sonraki girişte aynı dil gelsin).
function Localization.set(code: string)
	if not Localization.isSupported(code) then
		return
	end
	apply(code)
	if remoteSetter then
		remoteSetter(code)
	end
end

if RunService:IsClient() then
	local player = Players.LocalPlayer
	apply(Localization.detect(player.LocaleId, nil))
	-- Ülkeye bakmak ağ isteğidir; yalnızca Roblox dili desteklenmiyorsa gerekir.
	if not Config.LANGUAGES[string.lower(string.match(player.LocaleId, "^%a+") or "")] then
		task.spawn(function()
			local ok, region = pcall(function()
				return game:GetService("LocalizationService"):GetCountryRegionForPlayerAsync(player)
			end)
			if
				ok
				and typeof(region) == "string"
				and not Localization.isSupported(player:GetAttribute("SavedLanguage"))
			then
				apply(Localization.detect(nil, region))
			end
		end)
	end

	-- Sunucudaki kayıtlı tercih (boş metin = hiç seçilmemiş) otomatik algılamanın önüne geçer.
	local function applySaved()
		local saved = player:GetAttribute("SavedLanguage")
		if typeof(saved) == "string" and Localization.isSupported(saved) then
			apply(saved)
		end
	end
	player:GetAttributeChangedSignal("SavedLanguage"):Connect(applySaved)
	applySaved()

	remoteSetter = function(code: string)
		task.spawn(function()
			local Remotes = require(script.Parent:WaitForChild("Remotes"))
			Remotes.get("RequestSetLanguage"):FireServer(code)
		end)
	end
end

return Localization
