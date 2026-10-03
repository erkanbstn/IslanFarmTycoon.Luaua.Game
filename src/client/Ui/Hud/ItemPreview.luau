--!strict
-- Eşya karolarında oyundaki modelin sabit önizlemesi; aynı kimlik için yeniden klonlanmaz.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))

local ItemPreview = {}

function ItemPreview.mount(icon: TextLabel, itemId: string?)
	local previous = icon:FindFirstChild("ItemPreview")
	if previous and previous:GetAttribute("ItemId") == itemId then
		icon.Text = ""
		return
	end
	if previous then
		previous:Destroy()
	end
	if not itemId then
		icon.Size = UDim2.fromOffset(42, 42)
		return
	end
	local templates = ReplicatedStorage:FindFirstChild("ItemPreviews")
	local template = if templates then templates:FindFirstChild(itemId) else nil
	if not template or not template:IsA("Model") then
		return
	end
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "ItemPreview"
	viewport:SetAttribute("ItemId", itemId)
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = UiKit.Color.Text
	viewport.LightColor = UiKit.Color.Cream
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Parent = icon
	icon.Size = UDim2.new(1, 0, 0, 52)
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local model = template:Clone()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	model.Parent = world
	local bounds, size = model:GetBoundingBox()
	model:PivotTo(CFrame.new(-bounds.Position) * model:GetPivot())
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	local direction = if template:GetAttribute("Attach") == "back"
		then Vector3.new(0.5, 0.2, 1)
		else Vector3.new(0.5, 0.2, -1)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local rotation = CFrame.lookAt(direction.Unit, Vector3.zero).Rotation
	local function fitCamera()
		local extent = viewport.AbsoluteSize
		local aspect = if extent.Y > 0 then math.max(extent.X / extent.Y, 0.1) else 2.5
		local vertical = math.tan(math.rad(camera.FieldOfView * 0.5))
		local horizontal = vertical * aspect
		local distance = 0.2
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local corner = bounds.Rotation:VectorToWorldSpace(size * Vector3.new(x, y, z) * 0.5)
					local projected = rotation:VectorToObjectSpace(corner)
					distance = math.max(
						distance,
						projected.Z + math.max(math.abs(projected.X) / horizontal, math.abs(projected.Y) / vertical)
					)
				end
			end
		end
		camera.CFrame = CFrame.new(direction.Unit * distance * 1.12) * rotation
	end
	fitCamera()
	viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCamera)
	icon.Text = ""
end

return ItemPreview
