--!strict
-- Dönüş özeti: oyuna girince "Sen yokken" penceresi. Sunucu para ve büyüyen hayvan sayısını (ve isteğe bağlı günlük ödül,
-- hazır sipariş, gezgin tüccar, altın hayvan bilgisini) gönderir (OfflineSummary); hazır üretim partileri client'ta
-- kayıttan sayılır. Satır seçimi Ui/Hud/WelcomeBackLines'tadır (boş satır gösterilmez). Bildirim yerine tek pencere.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local ClientState = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientState"))
local UiKit = require(script.Parent.Parent:WaitForChild("Ui"):WaitForChild("UiKit"))
local WelcomeBackLines =
	require(script.Parent.Parent:WaitForChild("Ui"):WaitForChild("Hud"):WaitForChild("WelcomeBackLines"))

local player = Players.LocalPlayer

-- Çiftlik durumu gelene kadar en fazla bu kadar bekle; gelmezse özet üretim satırı olmadan gösterilir.
local STATE_WAIT_SECONDS = 6

local function readyRecipes(): { string }
	local state = ClientState.get()
	local result: { string } = {}
	if state and state.production then
		local now = Workspace:GetServerTimeNow()
		for recipeId, job in state.production do
			local recipe = Config.PRODUCTION_RECIPES[recipeId]
			if recipe and job.readyAt <= now then
				table.insert(result, recipe.displayName)
			end
		end
	end
	table.sort(result)
	return result
end

local function show(earned: number, grown: number, extras: WelcomeBackLines.Extras)
	local gui = Instance.new("ScreenGui")
	gui.Name = "WelcomeBack"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	local window = UiKit.window(UiKit.screenRoot(gui), {
		title = "Tekrar hoş geldin",
		icon = "🌅",
		tint = UiKit.Color.Gold,
		width = 340,
		maxHeight = 360,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	UiKit.text(window.list, "Sen yokken çiftliğinde olanlar", "Caption").LayoutOrder = 1

	local order = 2
	local summaryState = ClientState.get()
	local lines = WelcomeBackLines.build({
		earned = earned,
		earnedText = FarmMath.formatMoney(earned),
		grown = grown,
		animalIcon = Config.getHomeAnimalIcon(if summaryState then summaryState.activeMainFarmId else nil),
		recipes = readyRecipes(),
		daily = extras.daily,
		orders = extras.orders,
		merchant = extras.merchant,
		golden = extras.golden,
	})
	local details = WelcomeBackLines.showDetails(#lines)
	for _, entry in lines do
		local card = UiKit.card(window.list, order, entry.icon)
		card.title.Text = entry.text
		card.detail.Text = entry.detail or ""
		card.detail.Visible = details and entry.detail ~= nil
		card.action.Visible = false
		order += 1
	end

	local close = UiKit.button(window.list, "Devam et", "primary")
	close.Size = UDim2.new(1, 0, 0, 40)
	close.LayoutOrder = order
	close.Activated:Connect(function()
		window.close()
		task.delay(0.5, function()
			gui:Destroy()
		end)
	end)
	window.open()
end

Remotes.get("OfflineSummary").OnClientEvent:Connect(function(earned: unknown, grown: unknown, extras: unknown)
	if typeof(earned) ~= "number" or typeof(grown) ~= "number" then
		return
	end
	-- Üretim satırı için çiftlik durumunun gelmesini kısa süre bekle
	local waited = 0
	while not ClientState.get() and waited < STATE_WAIT_SECONDS do
		task.wait(0.25)
		waited += 0.25
	end
	show(earned, grown, WelcomeBackLines.readExtras(extras))
end)
