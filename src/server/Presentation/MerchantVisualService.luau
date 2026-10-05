--!strict
-- Aktif ziyaret varken NPC kurulur; son ziyaret bitince model ve etkileşimi kaldırılır.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local HubNpcs = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("HubNpcs"))
local MapLayout = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("MapLayout"))
local MerchantVisualService = {}
local currentModel: Model? = nil
local initialized = false

function MerchantVisualService.update(active: boolean)
	local world = Workspace:FindFirstChild("World")
	local hub = world and world:FindFirstChild("Hub")
	if currentModel and (not hub or currentModel.Parent ~= hub) then
		currentModel:Destroy()
		currentModel = nil
	end
	if not hub then
		return
	end
	local existing = hub:FindFirstChild("TravelingMerchant")
	if not active then
		if existing then
			existing:Destroy()
		end
		currentModel = nil
		return
	end
	local existingAnchor = existing and existing:FindFirstChild("VendorPromptAnchor")
	if existing and existing:IsA("Model") and existingAnchor and existingAnchor:IsA("BasePart") then
		-- Kaydedilmiş/önceden kurulmuş NPC de mesafe kontrolüne dahil edilmeli.
		currentModel = existing
		existing.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		return
	end
	if existing then
		-- Eksik etkileşim noktası olan eski görünümü çalışır NPC ile yenile.
		existing:Destroy()
	end
	local center = Vector3.new(0, MapLayout.SURFACE_Y, 0)
	local position = MapLayout.HUB_MERCHANT_POSITION
	-- Etiket, prompt ve Atomic ayarı tamamlanmadan istemciye kısmi bir satıcı yayınlama.
	local staging = Instance.new("Folder")
	local model = HubNpcs.vendor(staging, CFrame.lookAt(position, center), {
		name = "Gezgin Tüccar",
		title = "Gezgin Tüccar",
		icon = "🧳",
		action = "merchant",
		blurb = "İndirimli tur eşyaları",
		prompt = "Tekliflere bak",
		modelName = "Vendor_store",
	})
	if not model then
		staging:Destroy()
		return
	end
	model.Name = "TravelingMerchant"
	currentModel = model
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	-- Kaybolan kişisel tezgâh hiçbir oyuncunun yolunu veya ışınını engellemez.
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			child.CanCollide, child.CanTouch, child.CanQuery = false, false, false
		end
	end
	model.Parent = hub
	staging:Destroy()
end

function MerchantVisualService.init(visitActive: () -> boolean)
	if initialized then
		return
	end
	initialized = true
	local lastError: string? = nil
	local function refresh()
		local ok, err = pcall(function()
			MerchantVisualService.update(visitActive())
		end)
		if ok then
			lastError = nil
		elseif tostring(err) ~= lastError then
			lastError = tostring(err)
			warn(`[Merchant] NPC güncellenemedi: {lastError}`)
		end
	end
	refresh()
	task.spawn(function()
		while true do
			task.wait(1)
			refresh()
		end
	end)
end

function MerchantVisualService.isNear(player: Player): boolean
	local model = currentModel
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- Görsel pivot yerine oyuncunun E etkileşiminde yaklaştığı aynı noktayı kullan.
	local anchor = model and model:FindFirstChild("VendorPromptAnchor")
	return model ~= nil
		and model.Parent ~= nil
		and root ~= nil
		and root:IsA("BasePart")
		and humanoid ~= nil
		and humanoid.Health > 0
		and anchor ~= nil
		and anchor:IsA("BasePart")
		and (root.Position - anchor.Position).Magnitude <= Config.MERCHANT.buyRadius
end

return MerchantVisualService
