--!strict
-- Kişisel ziyaretin görünürlüğü istemcide belirlenir; tezgâh yalnızca mevcut modelden kurulur.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local HubNpcs = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("HubNpcs"))
local MapLayout = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("MapLayout"))
local MerchantVisualService = {}
local currentModel: Model? = nil

function MerchantVisualService.init()
	local world = Workspace:FindFirstChild("World")
	local hub = world and world:FindFirstChild("Hub")
	if not hub or hub:FindFirstChild("TravelingMerchant") then
		return
	end
	local center = Vector3.new(0, MapLayout.SURFACE_Y, 0)
	local position = center + Vector3.new(math.sin(math.rad(30)), 0, math.cos(math.rad(30))) * 24
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

function MerchantVisualService.isNear(player: Player): boolean
	local model = currentModel
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return model ~= nil
		and model.Parent ~= nil
		and root ~= nil
		and root:IsA("BasePart")
		and (root.Position - model:GetPivot().Position).Magnitude <= Config.MERCHANT.buyRadius
end

return MerchantVisualService
