--!strict
-- Yardımcılar (pet): her oyuncunun bütün çiftliklerinde (etkin ya da park edilmiş) hazır partileri teslim alır ve
-- "otomatik tekrar" açıksa yenisini başlatır. Çekirdek kural ProductionLogic.runPets'te (saf, testli); burası yalnızca
-- sunucu döngüsü, bildirim ve kayıt isteğidir. Yalnızca çevrimiçi oyuncu için çalışır.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local ProductionLogic = require(script.Parent.Parent.Modules.ProductionLogic)

local PetService = {}

local TICK_SECONDS = 2
local initialized = false

-- Yardımcıların görünür hareketi istemcide (PetAnimator); burada yalnızca plot özniteliklerine iş ve tur sayısı yazılır.
-- Her (tür, ada) yuvası için: PetJob_<tür>_<ada> = çalışan partinin tesis kimliği ("" = iş yok),
-- PetCycle_<tür>_<ada> = yardımcının teslim ettiği toplam parti (her artışta teslim turu oynar).
local function attributeKey(kind: string, island: string): string
	return `{kind}_{island}`
end

local function publish(player: Player, data: any, claims: { [string]: number }?)
	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end
	local jobs: { [string]: string } = {}
	for _, slot in ProductionLogic.petSlots(data, Config.PRODUCTION_ORDER, FarmMath, Config) do
		jobs[`{slot.kind}:{slot.island}`] = ""
	end
	for _, recipeId in Config.PRODUCTION_ORDER do
		local recipe = Config.PRODUCTION_RECIPES[recipeId]
		local kind = ProductionLogic.petKind(recipe, FarmMath)
		if kind then
			local petIsland = FarmMath.petIsland(recipe)
			local key = `{kind}:{petIsland}`
			if jobs[key] == "" and data.production[recipeId] then
				jobs[key] = recipe.upgradeId
			end
			plot:SetAttribute(`PetJob_{attributeKey(kind, petIsland)}`, jobs[key] or "")
		end
	end
	if claims then
		for key, count in claims do
			local kind, island = string.match(key, "^(%w+):(%w+)$")
			if kind and island then
				local attribute = `PetCycle_{attributeKey(kind, island)}`
				plot:SetAttribute(attribute, ((plot:GetAttribute(attribute) or 0) :: number) + count)
			end
		end
	end
end

local function tick(player: Player)
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true then
		return
	end
	local hooks: ProductionLogic.Hooks = {
		settle = function()
			EconomyService.settlePlayer(player)
		end,
		trySpend = function(amount: number): boolean
			return PlayerDataService.trySpend(player, amount, "facility")
		end,
		addCash = function(amount: number)
			PlayerDataService.addCash(player, amount, "production")
		end,
		newUid = function(): string
			return HttpService:GenerateGUID(false)
		end,
	}
	local now = DateTime.now().UnixTimestampMillis / 1000
	local summary = ProductionLogic.runPets(data, PlayerDataService.getFarmIds(player), function(farmId: string): any
		return PlayerDataService.getFarmView(player, farmId)
	end, Config.PRODUCTION_ORDER, now, FarmMath, Config, hooks)
	publish(player, data, summary.claims[data.activeMainFarmId])
	if next(summary.changedFarms) == nil then
		return
	end
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	if summary.changedFarms[data.activeMainFarmId] then
		-- Etkin çiftlikte hayvanlar tesise girdi/döndü ve bina üstündeki çubuk değişti
		local ok, err = pcall(function()
			PlotService.refreshPlayerWorld(player)
		end)
		if not ok then
			warn(`[Pet] Görünüm yenilenemedi: {err}`)
		end
	end
	for index, message in summary.messages do
		if index > 4 then
			break
		end
		Remotes.get("Notify"):FireClient(player, message, "info")
	end
end

function PetService.init()
	if initialized then
		return
	end
	initialized = true
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(tick, player)
				if not ok then
					warn(`[Pet] {err}`)
				end
			end
		end
	end)
end

return PetService
