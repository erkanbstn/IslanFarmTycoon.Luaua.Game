--!strict
-- Canlı ölçüm: Roblox AnalyticsService olayları (onboarding hunisi, ekonomi, ilerleme, özel olaylar) ve veri kaybı riski
-- taşıyan hataların Creator Hub'da görünür kaydı. Hepsi sunucuda; oyuncudan gelen hiçbir değer buraya taşınmaz.
-- Studio'da hiçbir olay gönderilmez (canlı veri kirlenmesin): yalnızca Metrics sayaçları, `Workspace.TelemetryPrint` ile print.
-- Telemetri hatası oyunu bozmaz: tüm AnalyticsService çağrıları pcall içindedir.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local AnalyticsService = game:GetService("AnalyticsService")
local Workspace = game:GetService("Workspace")

local TelemetryLogic = require(script.Parent.Parent.Modules.TelemetryLogic)
local Metrics = require(script.Parent.Parent.Modules.Metrics)

type PlayerState = {
	aggregator: TelemetryLogic.Aggregator,
	funnel: { [string]: boolean },
	joinedAt: number,
	storageFullSeconds: number,
	observed: TelemetryLogic.Observation?,
	goldSources: { [string]: number }, -- kanalların bildirdiği altın harcaması; bir sonraki observe'da tüketilir
}

export type OfflineReport = { earned: number, awaySeconds: number, capped: boolean, balance: number }

local TelemetryService = {}

-- Yeni AnalyticsService yöntemleri yerel Roblox tip tanımlarında olmayabilir; çağrılar bu yüzden `any` üzerinden.
local analytics: any = AnalyticsService
local live = not RunService:IsStudio()
local states: { [Player]: PlayerState } = {}
-- PlayerRemoving sırasında Parent hâlâ Players'tır; çıkış başlayan oyuncu için durum yeniden açılmasın (zayıf anahtar: sızıntı yok).
local leaving: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local budget = TelemetryLogic.newBudget(TelemetryLogic.EVENTS_PER_MINUTE, os.clock())
local criticalBudget = TelemetryLogic.newBudget(20, os.clock())
local initialized = false

-- Progression yolu ve ona eşlik eden özel olay: Roblox ilerleme olayını henüz grafikte göstermiyor, özel olay gösteriyor.
local PROGRESSION = {
	island = { path = "Islands", custom = "IslandUnlocked" },
	farm = { path = "Farms", custom = "FarmUnlocked" },
	barn = { path = "Barn", custom = "BarnLevel" },
} :: { [string]: { path: string, custom: string } }

local function stateFor(player: Player): PlayerState?
	local state = states[player]
	if state then
		return state
	end
	if player.Parent == nil or leaving[player] then
		return nil -- çıkmış oyuncu için durum yeniden açılmaz (sızıntı olmasın)
	end
	state = {
		aggregator = TelemetryLogic.newAggregator(),
		funnel = {},
		joinedAt = os.time(),
		storageFullSeconds = 0,
		observed = nil,
		goldSources = {},
	}
	states[player] = state
	return state
end

-- Tek çıkış noktası: sayaç, Studio'da gönderme yok, bütçe, pcall.
-- Dönüş: olay bütçe yüzünden düşmediyse true (Studio'da ve AnalyticsService hatasında da true: yeniden denemek anlamsız).
local function dispatch(kind: string, label: string, send: () -> ()): boolean
	Metrics.increment(`Telemetry{kind}`)
	if not live then
		Metrics.increment("TelemetryStudioSkipped")
		if Workspace:GetAttribute("TelemetryPrint") == true then
			print(`[Telemetry] {kind} {label}`)
		end
		return true
	end
	if not TelemetryLogic.allow(budget, os.clock()) then
		Metrics.increment("TelemetryDropped")
		return false
	end
	local ok = pcall(send)
	if not ok then
		Metrics.increment("TelemetryError")
	end
	return true
end

local function sendEconomy(
	player: Player,
	category: TelemetryLogic.EconomyCategory,
	amount: number,
	balance: number,
	sku: string?
)
	dispatch("Economy", `{category.flow} {category.transaction} {amount}`, function()
		local flow = if category.flow == "Source"
			then Enum.AnalyticsEconomyFlowType.Source
			else Enum.AnalyticsEconomyFlowType.Sink
		analytics:LogEconomyEvent(
			player,
			flow,
			TelemetryLogic.CURRENCY,
			amount,
			TelemetryLogic.roundBalance(balance),
			category.transaction,
			sku or ""
		)
	end)
end

-- Para hareketi. Yüksek frekanslı kaynaklar (toplama, otomatik toplama, üretim) oyuncu başına birikir, FLUSH_SECONDS'ta bir gider.
-- `balance`: işlem sonrası bakiye. `sku`: yalnızca sınırlı kümeden (hayvan/eşya/yükseltme kimliği; en çok 100 farklı).
function TelemetryService.economy(player: Player, key: string, amount: number, balance: number, sku: string?)
	local category = TelemetryLogic.ECONOMY[key]
	if not category then
		Metrics.increment("TelemetryUnknownEconomy")
		return
	end
	local rounded = TelemetryLogic.roundAmount(amount)
	local state = stateFor(player)
	if not rounded or not state then
		return
	end
	if category.batched then
		TelemetryLogic.add(state.aggregator, key, rounded, TelemetryLogic.roundBalance(balance))
		return
	end
	sendEconomy(player, category, rounded, balance, sku)
end

-- Onboarding hunisi adımı: oyuncu başına bir kez (kayıttan geçilmiş adımlar `onLoaded`'da işaretlenir).
function TelemetryService.funnel(player: Player, id: string)
	local step = TelemetryLogic.FUNNEL[id]
	local state = stateFor(player)
	if not step or not state or state.funnel[id] then
		return
	end
	-- İşaret yalnızca olay gerçekten gittiyse konur; bütçe yüzünden düşen adım bir sonraki fırsatta yeniden denenir.
	local sent = dispatch("Funnel", `{step.step} {step.name}`, function()
		analytics:LogOnboardingFunnelStepEvent(player, step.step, step.name)
	end)
	if sent then
		state.funnel[id] = true
	end
end

-- `fields`: isteğe bağlı özel alanlar (CustomField01..03 -> kısa metin). Alanlı gönderim reddedilirse alansız bir kez daha denenir.
function TelemetryService.custom(player: Player, name: string, value: number?, fields: TelemetryLogic.Fields?)
	if TelemetryLogic.CUSTOM_EVENTS[name] ~= true then
		Metrics.increment("TelemetryUnknownCustom")
		return
	end
	local amount = value or 1
	local label = `{name} {amount}`
	if fields then
		local parts: { string } = {}
		for key, text in fields do
			table.insert(parts, `{key}={text}`)
		end
		table.sort(parts)
		label ..= ` [{table.concat(parts, " ")}]`
	end
	dispatch("Custom", label, function()
		if fields then
			local ok = pcall(function()
				analytics:LogCustomEvent(player, name, amount, fields)
			end)
			if ok then
				return
			end
			Metrics.increment("TelemetryFieldsRejected")
		end
		analytics:LogCustomEvent(player, name, amount)
	end)
end

-- Eşya edinimi (bir edinim = bir olay; çağıran yalnızca başarılı ve kalıcı işlemden sonra çağırır).
-- channel: cash | merchant | gold | robux | reward; slot: eşyanın slotu (kimlik değil).
function TelemetryService.acquired(player: Player, channel: string, slot: string?)
	local fields = TelemetryLogic.acquiredFields(channel, slot)
	if not fields then
		Metrics.increment("TelemetryUnknownCustom")
		return
	end
	if not stateFor(player) then
		return
	end
	TelemetryService.custom(player, "ItemAcquired", 1, fields)
end

-- Altın harcaması kaynağı (item | convert | finish): işlem başarılı olunca çağrılır; GoldSpent net farkı bu tutarlarla bölünür.
-- Bildirilmeyen harcama "other" görünür. Gözlemde tüketilmeyen tutar bir sonraki pencereye kalmaz (observe sıfırlar).
function TelemetryService.goldSpent(player: Player, source: string, amount: number)
	local state = stateFor(player)
	if not state or typeof(amount) ~= "number" or amount ~= amount or amount < 1 then
		return
	end
	local known = false
	for _, name in TelemetryLogic.GOLD_SOURCES do
		known = known or name == source
	end
	if not known then
		Metrics.increment("TelemetryUnknownCustom")
		return
	end
	state.goldSources[source] = (state.goldSources[source] or 0) + math.floor(amount)
end

-- Rebirth hunisi ve altın akışı: çağıran (EngagementService) birkaç saniyede bir anlık görüntü verir, farklar özel olay olur.
function TelemetryService.observe(player: Player, observation: TelemetryLogic.Observation)
	local state = stateFor(player)
	if not state then
		return
	end
	local previous = state.observed
	state.observed = observation
	local sources = state.goldSources
	state.goldSources = {}
	for _, event in TelemetryLogic.progressEvents(previous, observation, sources) do
		TelemetryService.custom(player, event.name, event.value, event.fields)
	end
end

-- Ada / çiftlik / ahır seviyesi açılışı. kind: "island" | "farm" | "barn"; level: sıra (ada/çiftlik sayısı, ahır seviyesi).
function TelemetryService.progression(player: Player, kind: string, level: number, levelName: string)
	local entry = PROGRESSION[kind]
	if not entry then
		return
	end
	dispatch("Progression", `{entry.path} {level} {levelName}`, function()
		analytics:LogProgressionCompleteEvent(player, entry.path, level, levelName)
	end)
	TelemetryService.custom(player, entry.custom, level)
end

-- Etkin çiftlikte deponun dolu kaldığı süre (oturum başına toplanır, çıkışta gönderilir).
function TelemetryService.storageFull(player: Player, seconds: number)
	local state = stateFor(player)
	if state and seconds > 0 then
		state.storageFullSeconds += seconds
	end
end

-- Kayıt yüklenince: hunide zaten geçilmiş adımları işaretle (tekrar gönderilmesin) ve çevrimdışı dönüşü bildir.
function TelemetryService.onLoaded(player: Player, views: { any }, offline: OfflineReport?)
	local state = stateFor(player)
	if not state then
		return
	end
	for id, reached in TelemetryLogic.funnelReached(TelemetryLogic.factsFromViews(views)) do
		if reached then
			state.funnel[id] = true
		end
	end
	if offline then
		TelemetryService.economy(player, "offline", offline.earned, offline.balance)
		local away = TelemetryLogic.roundAmount(offline.awaySeconds)
		if away then
			TelemetryService.custom(player, "OfflineSeconds", away)
			if offline.capped then
				TelemetryService.custom(player, "OfflineCapped", 1)
			end
		end
	end
end

local function flush(player: Player, state: PlayerState)
	for _, batch in TelemetryLogic.drain(state.aggregator) do
		local category = TelemetryLogic.ECONOMY[batch.key]
		local amount = TelemetryLogic.roundAmount(batch.amount)
		if category and amount then
			sendEconomy(player, category, amount, batch.balance, nil)
		end
	end
end

function TelemetryService.flushAll()
	for player, state in states do
		local ok = pcall(flush, player, state)
		if not ok then
			Metrics.increment("TelemetryError")
		end
	end
end

-- Oyuncu çıkarken: birikenleri gönder, oturum ve depo-dolu sürelerini bildir.
function TelemetryService.onLeaving(player: Player)
	local state = states[player]
	if not state then
		return
	end
	states[player] = nil
	leaving[player] = true
	pcall(flush, player, state)
	local session = TelemetryLogic.roundAmount(os.time() - state.joinedAt)
	if session then
		TelemetryService.custom(player, "SessionSeconds", session)
	end
	local full = TelemetryLogic.roundAmount(state.storageFullSeconds)
	if full then
		TelemetryService.custom(player, "StorageFullSeconds", full)
	end
end

-- Veri kaybı riski taşıyan hata: warn Creator Hub'da görünmez, hata (error) görünür. Ayrı iş parçacığında atılır,
-- çağıranın akışı (kayıt döngüsü, oyuncu çıkışı) bozulmaz. Sel olmasın diye dakikada en çok 20.
function TelemetryService.critical(message: string)
	Metrics.increment("CriticalLogged")
	if TelemetryLogic.allow(criticalBudget, os.clock()) then
		task.spawn(error, message)
	else
		warn(message)
	end
end

function TelemetryService.init()
	if initialized then
		return
	end
	initialized = true
	Players.PlayerAdded:Connect(function(player: Player)
		stateFor(player)
	end)
	for _, player in Players:GetPlayers() do
		stateFor(player)
	end
	task.spawn(function()
		while true do
			task.wait(TelemetryLogic.FLUSH_SECONDS)
			TelemetryService.flushAll()
		end
	end)
end

return TelemetryService
