--!strict
-- Gelir: hayvanlar her saniye depoya para üretir (depo dolarsa üretim durur).
-- Oyuncu adasındaki yeşil platforma basınca depo kasaya aktarılır.
-- "Otomatik Toplayıcı" alınmışsa para doğrudan kasaya gider.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local TelemetryService = require(script.Parent:WaitForChild("TelemetryService"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))
local Metrics = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Metrics"))

local EconomyService = {}

local lastIncomeAt: { [Player]: number } = {}

local function setCollectorText(plot: Model, text: string, icon: string, tint: Color3)
	local collector = plot:FindFirstChild("Collector")
	WorldUi.setTag(collector and collector:FindFirstChild("CollectorBillboard"), text, icon, tint)
end

local function updateCollector(player: Player)
	for farmId, plot in PlotService.getAllOwned(player) do
		local data = PlayerDataService.getFarmView(player, farmId)
		if not data then
			continue
		end
		if FarmMath.hasAutoCollect(data) then
			setCollectorText(plot, "Otomatik", "🤖", UiTheme.Color.Blue)
			continue
		end
		local cap = FarmMath.getStorageCap(data)
		if data.stored >= cap then
			setCollectorText(plot, `Depo dolu · {FarmMath.formatMoney(cap)}`, "💰", UiTheme.Color.Red)
		else
			setCollectorText(
				plot,
				`{FarmMath.formatMoney(data.stored)} / {FarmMath.formatMoney(cap)}`,
				"💰",
				UiTheme.Color.Gold
			)
		end
	end
end

-- Platformda iki toplama arası en az Config.COLLECT_COOLDOWN_SECONDS geçer; oyuncu platformda durarak da toplar.
local lastCollectAt: { [Player]: number } = {}

function EconomyService.collect(player: Player)
	if not RateLimiter.allow(player, "collect", 0.5) then
		return
	end
	local last = lastCollectAt[player]
	if last and os.clock() - last < Config.COLLECT_COOLDOWN_SECONDS then
		return
	end

	local data = PlayerDataService.tryGet(player)
	local plot = PlotService.getPlot(player)
	local collector = plot and plot:FindFirstChild("Collector")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not data
		or not plot
		or PlotService.getOwner(plot) ~= player
		or not collector
		or not collector:IsA("BasePart")
		or not root
		or not root:IsA("BasePart")
		or not humanoid
		or humanoid.Health <= 0
	then
		return
	end
	-- Platform yerel uzayında sınır kontrolü: döndürülmüş/geniş platformları da destekler.
	local offset = collector.CFrame:PointToObjectSpace(root.Position)
	local halfSize = collector.Size * 0.5
	if
		math.abs(offset.X) > halfSize.X + 4
		or math.abs(offset.Z) > halfSize.Z + 4
		or math.abs(offset.Y) > halfSize.Y + 8
	then
		return
	end
	EconomyService.settlePlayer(player)
	local amount = math.floor(data.stored)
	if amount <= 0 then
		return
	end
	data.stored -= amount
	lastCollectAt[player] = os.clock()
	PlayerDataService.addCash(player, amount, "collect")
	TelemetryService.funnel(player, "first_collect")
	Metrics.increment("Collections")
	updateCollector(player)
	Remotes.get("Notify"):FireClient(player, `+{FarmMath.formatMoney(amount)} toplandı`, "money", amount)
end

function EconomyService.startPlayer(player: Player)
	lastIncomeAt[player] = os.clock()
end

function EconomyService.settlePlayer(player: Player)
	local data = PlayerDataService.tryGet(player)
	local previous = lastIncomeAt[player]
	if not data or not previous or not PlotService.getPlot(player) then
		return
	end
	local now = os.clock()
	lastIncomeAt[player] = now
	-- Uzun sunucu duraksaması sınırsız bir ödemeye dönüşmesin; normal tick gecikmesi telafi edilir.
	local elapsed = math.clamp(now - previous, 0, Config.MAX_INCOME_CATCHUP_SECONDS)
	local wallNow = DateTime.now().UnixTimestampMillis / 1000
	-- Depo doluyken geçen süre (etkin çiftlik, Otomatik Toplayıcı yokken): telemetri oturum toplamı.
	if not FarmMath.hasAutoCollect(data) and data.stored >= FarmMath.getStorageCap(data) then
		TelemetryService.storageFull(player, elapsed)
	end
	-- Her kayıt kendi kapasitesini ve yükseltmelerini kullanır; fiziksel ada park edilmiş olsa da üretir.
	for _, farmId in PlayerDataService.getFarmIds(player) do
		local farm = PlayerDataService.getFarmView(player, farmId)
		if not farm then
			continue
		end
		local earned = FarmMath.computeIncomeOverInterval(farm, wallNow - elapsed, wallNow)
		if FarmMath.hasAutoCollect(farm) then
			local collected = earned + farm.stored
			data.cash = math.min(1e15, data.cash + collected)
			data.lifetimeEarned = math.min(1e18, (data.lifetimeEarned or 0) + collected)
			farm.stored = 0
			if collected > 0 then
				TelemetryService.economy(player, "autoCollect", collected, data.cash)
				TelemetryService.funnel(player, "first_collect")
			end
		else
			farm.stored = math.min(farm.stored + earned, FarmMath.getStorageCap(farm))
		end
	end
	PlayerDataService.pushEconomy(player)
	updateCollector(player)
end

function EconomyService.stopPlayer(player: Player)
	local ok, err = pcall(EconomyService.settlePlayer, player)
	lastIncomeAt[player] = nil
	if not ok then
		warn(`[Economy] Son gelir hesaplanamadı: {err}`)
	end
end

-- Tek oyuncunun hatası döngüyü (herkesin gelirini) durdurmasın.
function EconomyService.tick()
	for _, player in Players:GetPlayers() do
		local ok, err = pcall(function()
			EconomyService.settlePlayer(player)
			EconomyService.collect(player)
		end)
		if not ok then
			warn(`[Economy] {err}`)
			Metrics.increment("LoopError")
			TelemetryService.custom(player, "LoopError")
		end
	end
	for player in lastCollectAt do
		if player.Parent == nil then
			lastCollectAt[player] = nil
		end
	end
end

function EconomyService.init()
	for _, plot in PlotService.getAllPlots() do
		local collector = plot:FindFirstChild("Collector")
		if not collector or not collector:IsA("BasePart") then
			continue
		end
		collector.Touched:Connect(function(hit: BasePart)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			-- Sadece adanın sahibi toplayabilir
			if player and PlotService.getOwner(plot) == player and PlotService.getPlot(player) == plot then
				EconomyService.collect(player)
			end
		end)
	end

	task.spawn(function()
		while true do
			task.wait(Config.INCOME_TICK_SECONDS)
			EconomyService.tick()
		end
	end)
end

return EconomyService
