--!strict
-- Ana ada pazar tezgâhı (sipariş panosu ve Hayvan Pazarı).
-- Her yapı yerel çerçevede kurulur: -Z ön (kapı yönü), taban zemin yüzeyindedir.

-- Studio harita eklentisi modülleri kopyalayıp çalıştırır; Shared araması SharedRef'te (kopyadaki Shared'ı bulur).
local Shared = require(script.Parent:WaitForChild("SharedRef")) :: typeof(game.ReplicatedStorage.Shared)
local WorldUi = require(Shared:WaitForChild("WorldUi"))
local HomeParts = require(script.Parent:WaitForChild("HomeParts"))

local WOOD = HomeParts.WOOD
local DARK_WOOD = HomeParts.DARK_WOOD
local CREAM = HomeParts.CREAM
local part = HomeParts.part
local ball = HomeParts.ball
local model = HomeParts.model

local Market = {}

---------------------------------------------------------------------------
-- Pazar tezgâhı: hayvan pazarına erişim (MarketPrompt; client Pazar penceresini açar)
---------------------------------------------------------------------------

function Market.market(parent: Instance, base: CFrame)
	local stall = model(parent, "MarketStall")
	part(stall, "Counter", Vector3.new(9, 2.4, 2.6), base * CFrame.new(0, 1.2, 0), WOOD, Enum.Material.WoodPlanks)
	part(
		stall,
		"CounterTop",
		Vector3.new(9.4, 0.3, 3),
		base * CFrame.new(0, 2.55, -0.1),
		DARK_WOOD,
		Enum.Material.WoodPlanks,
		false
	)
	for _, x in { -4.4, 4.4 } do
		part(stall, "Post", Vector3.new(0.5, 7, 0.5), base * CFrame.new(x, 3.5, 1.5), DARK_WOOD, Enum.Material.Wood)
		part(
			stall,
			"FrontPost",
			Vector3.new(0.5, 6.4, 0.5),
			base * CFrame.new(x, 3.2, -1.6),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end
	-- Yan ve arka paneller: tezgâhın içine girilmesin
	for _, x in { -4.6, 4.6 } do
		part(
			stall,
			"SidePanel",
			Vector3.new(0.4, 3.2, 3.6),
			base * CFrame.new(x, 1.6, 0.1),
			WOOD,
			Enum.Material.WoodPlanks
		)
	end
	part(stall, "BackPanel", Vector3.new(9.4, 3.2, 0.4), base * CFrame.new(0, 1.6, 1.9), WOOD, Enum.Material.WoodPlanks)
	-- Çizgili tente: kırmızı ve krem şeritler öne doğru eğimli
	for index = 1, 6 do
		part(
			stall,
			"Awning",
			Vector3.new(1.55, 0.25, 4.6),
			base * CFrame.new(-3.9 + (index - 1) * 1.56, 6.7, -0.1) * CFrame.Angles(math.rad(-12), 0, 0),
			if index % 2 == 0 then CREAM else Color3.fromRGB(190, 60, 55),
			Enum.Material.Fabric,
			false
		)
	end
	-- Tezgâhta ürünler
	local produce: { { color: Color3, x: number } } = {
		{ color = Color3.fromRGB(210, 55, 50), x = -3.2 },
		{ color = Color3.fromRGB(240, 190, 60), x = -1.6 },
		{ color = Color3.fromRGB(120, 180, 90), x = 0 },
		{ color = Color3.fromRGB(240, 130, 40), x = 1.6 },
		{ color = Color3.fromRGB(150, 90, 170), x = 3.2 },
	}
	for _, entry in produce do
		part(
			stall,
			"Crate",
			Vector3.new(1.3, 0.6, 1.3),
			base * CFrame.new(entry.x, 2.95, -0.2),
			WOOD,
			Enum.Material.WoodPlanks,
			false
		)
		for fruit = 1, 3 do
			ball(
				stall,
				"Produce",
				0.55,
				base * CFrame.new(entry.x + (fruit - 2) * 0.3, 3.45, -0.2 + (fruit % 2) * 0.2),
				entry.color,
				Enum.Material.SmoothPlastic
			)
		end
	end
	-- Tabela: sipariş panosu
	local board = part(
		stall,
		"MarketSign",
		Vector3.new(6.2, 1.6, 0.3),
		base * CFrame.new(0, 5.6, -2.3),
		DARK_WOOD,
		Enum.Material.WoodPlanks,
		false
	)
	WorldUi.sign(board, Enum.NormalId.Front, { icon = "🐄", title = "Pazar", text = "Hayvan pazarı" })
	-- Etkileşim: tezgâhın önünde, tabelayı kapatmayan alçak nokta
	local anchor = part(
		stall,
		"MarketPromptAnchor",
		Vector3.one,
		base * CFrame.new(0, 2, -3.2),
		WOOD,
		Enum.Material.SmoothPlastic,
		false
	)
	anchor.Transparency = 1
	anchor.CanQuery = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MarketPrompt"
	prompt.ActionText = "Hayvan al"
	prompt.ObjectText = "Pazar"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Locked", true) -- IslandPrompts: yalnızca sahibine görünür
	prompt.Parent = anchor
end

return Market
