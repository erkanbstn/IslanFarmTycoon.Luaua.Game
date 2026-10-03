--!strict
-- Meydandaki satıcı NPC'ler, çeşme, bankler ve çiçeklikler. Geometri hazır modellerden gelir (assets/HubProps);
-- burada yalnızca tabela yazısı, etkileşim noktası ve etiketler eklenir.
-- Her NPC bir "VendorPrompt" taşır; `Action` özniteliği client'ta hangi pencerenin açılacağını belirler.
-- Haritaya kaydedilir (MapBuilder çağırır). Yerel çerçeve: -Z ön, taban zemin yüzeyinde.

local CollectionService = game:GetService("CollectionService")

-- Studio harita eklentisi modülleri kopyalayıp çalıştırır; Shared araması SharedRef'te (kopyadaki Shared'ı bulur).
local Shared = require(script.Parent:WaitForChild("SharedRef")) :: typeof(game.ReplicatedStorage.Shared)
local WorldUi = require(Shared:WaitForChild("WorldUi"))
local ModelAssets = require(script.Parent:WaitForChild("ModelAssets"))

local FOLDER = "HubProps"
local missingWarned: { [string]: boolean } = {}

local HubNpcs = {}

export type NpcSpec = {
	name: string,
	title: string,
	icon: string,
	action: string, -- "orders" | "store" | "roadmap" | "upgrades" | "travel"
	blurb: string, -- Tabelada görünen tek satır işlev açıklaması (NPC adı etkileşim ipucunda)
	prompt: string,
}

local BLOOM_COLORS = {
	Color3.fromRGB(240, 90, 120),
	Color3.fromRGB(250, 210, 70),
	Color3.fromRGB(245, 245, 250),
	Color3.fromRGB(190, 110, 220),
}

local function place(parent: Instance, name: string, base: CFrame): Model?
	local model = ModelAssets.clone(FOLDER, name)
	if not model then
		if not missingWarned[name] then
			missingWarned[name] = true
			warn(`[HubNpcs] assets/{FOLDER}/{name}.rbxmx bulunamadı; meydan yapısı çizilmedi`)
		end
		return nil
	end
	model:PivotTo(base)
	model.Parent = parent
	return model
end

function HubNpcs.vendor(parent: Instance, base: CFrame, spec: NpcSpec)
	local model = place(parent, `Vendor_{spec.action}`, base)
	if not model then
		return
	end
	model:SetAttribute("Action", spec.action)
	-- Client (HubNpcs.client) etiketli satıcıları canlandırır: göz teması, el sallama, konuşma balonu
	CollectionService:AddTag(model, "HubNpc")

	local board = model:FindFirstChild("Sign")
	if board and board:IsA("BasePart") then
		WorldUi.sign(board, Enum.NormalId.Front, { icon = spec.icon, title = spec.title, text = spec.blurb })
	end
	local anchor = Instance.new("Part")
	anchor.Name = "VendorPromptAnchor"
	anchor.Size = Vector3.one
	anchor.CFrame = base * CFrame.new(0, 3, -3.6)
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
	anchor.Transparency = 1
	anchor.Parent = model
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "VendorPrompt"
	prompt.ActionText = spec.prompt
	prompt.ObjectText = spec.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Action", spec.action)
	prompt.Parent = anchor
end

function HubNpcs.fountain(parent: Instance, base: CFrame)
	local model = place(parent, "Fountain", base)
	if model then
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
end

function HubNpcs.bench(parent: Instance, base: CFrame)
	place(parent, "Bench", base)
end

-- Çiçeklik: çiçek renkleri tohuma göre değişir
function HubNpcs.planter(parent: Instance, base: CFrame, seed: number)
	local model = place(parent, "Planter_seed2", base)
	if not model then
		return
	end
	model.Name = "Planter" -- model dosya adı (Planter_seed2) değil, tür adı: test ve sayımlar buna bakar
	local index = 0
	ModelAssets.eachNamed(model, { "Bloom" }, function(bloom: BasePart)
		bloom.Color = BLOOM_COLORS[(seed + index) % #BLOOM_COLORS + 1]
		index += 1
	end)
end

return HubNpcs
