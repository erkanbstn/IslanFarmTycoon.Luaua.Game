--!strict
-- Genel (ana) adanın yapıları: çiftlik evi, yel değirmeni, kuyu, sebze bahçesi, meyve bahçesi, arı kovanları, ambar,
-- pazar tezgâhı ve tema işaret yapısı. Geometri hazır modellerden gelir (assets/HomeModels → ServerStorage.Assets.HomeModels);
-- burada yalnızca modelde olamayan davranış eklenir (gece ışığı, duman, değirmen kanatları, pazar etkileşimi).
-- Her yapı yerel çerçevede kurulur: -Z ön (kapı yönü), taban zemin yüzeyindedir.

local CollectionService = game:GetService("CollectionService")

-- Studio harita eklentisi modülleri kopyalayıp çalıştırır; Shared araması SharedRef'te (kopyadaki Shared'ı bulur).
local Shared = require(script.Parent:WaitForChild("SharedRef")) :: typeof(game.ReplicatedStorage.Shared)
local WorldUi = require(Shared:WaitForChild("WorldUi"))
local ModelAssets = require(script.Parent:WaitForChild("ModelAssets"))
local WorldDecor = require(script.Parent:WaitForChild("WorldDecor"))

local FOLDER = "HomeModels"
local missingWarned: { [string]: boolean } = {}

local HomeBuildings = {}

-- Modeli kopyalar, `base` pivotuyla `parent` içine koyar; `prepare` (varsa) yerleşmeden önce çağrılır.
local function place(parent: Instance, name: string, base: CFrame, prepare: ((Model) -> ())?): Model?
	local model = ModelAssets.clone(FOLDER, name)
	if not model then
		if not missingWarned[name] then
			missingWarned[name] = true
			warn(`[HomeBuildings] assets/{FOLDER}/{name}.rbxmx bulunamadı; yapı çizilmedi`)
		end
		return nil
	end
	if prepare then
		prepare(model)
	end
	model:PivotTo(base)
	model.Parent = parent
	return model
end

local function simple(name: string): (Instance, CFrame) -> ()
	return function(parent: Instance, base: CFrame)
		place(parent, name, base, nil)
	end
end

local function addSmoke(chimney: BasePart)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, chimney.Size.Y / 2, 0)
	attachment.Parent = chimney
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(200, 200, 205))
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.2) })
	smoke.Lifetime = NumberRange.new(3, 4.5)
	smoke.Rate = 3
	smoke.Speed = NumberRange.new(2, 3)
	smoke.SpreadAngle = Vector2.new(8, 8)
	smoke.Acceleration = Vector3.new(0.6, 0.5, 0)
	smoke.LightEmission = 0
	smoke.Parent = attachment
end

local function markGlassWindows(model: Model)
	ModelAssets.eachNamed(model, { "Window" }, function(window: BasePart)
		if window.Material == Enum.Material.Glass then
			WorldDecor.markNightWindow(window)
		end
	end)
end

function HomeBuildings.farmhouse(parent: Instance, base: CFrame)
	place(parent, "Farmhouse", base, function(house: Model)
		ModelAssets.eachNamed(house, { "Chimney" }, addSmoke)
		ModelAssets.eachNamed(house, { "HouseLantern" }, ModelAssets.markLantern)
		markGlassWindows(house)
	end)
end

function HomeBuildings.windmill(parent: Instance, base: CFrame)
	place(parent, "Windmill", base, function(mill: Model)
		markGlassWindows(mill)
		-- Kanatlar (Hub, Arm, Sail) tek Model olur; client Windmill.client onu yerel Z ekseninde döndürür
		local blades = Instance.new("Model")
		blades.Name = "Blades"
		local hub: BasePart? = nil
		for _, child in mill:GetChildren() do
			if child:IsA("BasePart") and (child.Name == "Hub" or child.Name == "Arm" or child.Name == "Sail") then
				child.Parent = blades
				if child.Name == "Hub" then
					hub = child
				end
			end
		end
		blades.PrimaryPart = hub
		blades:SetAttribute("Speed", 0.7)
		CollectionService:AddTag(blades, "Windmill")
		blades.Parent = mill
	end)
end

HomeBuildings.well = simple("Well")
HomeBuildings.granary = function(parent: Instance, base: CFrame)
	place(parent, "Granary", base, markGlassWindows)
end
HomeBuildings.vegetableGarden = simple("VegetableGarden")
HomeBuildings.orchard = simple("Orchard")
HomeBuildings.beehives = simple("Beehives")

-- Pazar tezgâhı: tabela yazısı ve etkileşim noktası (MarketPrompt; client Pazar penceresini açar)
function HomeBuildings.market(parent: Instance, base: CFrame)
	place(parent, "MarketStall", base, function(stall: Model)
		local board = stall:FindFirstChild("MarketSign")
		if board and board:IsA("BasePart") then
			WorldUi.sign(board, Enum.NormalId.Front, { icon = "🐄", title = "Pazar", text = "Hayvan pazarı" })
		end
		local anchor = Instance.new("Part")
		anchor.Name = "MarketPromptAnchor"
		anchor.Size = Vector3.one
		anchor.CFrame = stall:GetPivot() * CFrame.new(0, 2, -3.2)
		anchor.Anchored = true
		anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
		anchor.Transparency = 1
		anchor.Parent = stall
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
	end)
end

-- Doğu kıyıdaki tema işaret yapısı (Config tema `landmark` türü: daisy, tulip, sunflower, rose, pine, cherry)
function HomeBuildings.landmark(parent: Instance, base: CFrame, kind: string)
	local model = place(parent, `Landmark_{kind}`, base, nil)
	if model then
		model.Name = "Landmark"
		model:SetAttribute("Kind", kind)
	end
end

return HomeBuildings
