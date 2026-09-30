--!strict
-- Pencere açıkken de fare tekerleğiyle kamera yakınlaştırma/uzaklaştırma.
-- Arayüz tekerlek olayını yuttuğunda (gameProcessed) kamera normalde kıpırdamaz; burada aynı etki verilir.
-- İmleç kaydırılabilir bir listenin üzerindeyse tekerlek listeyi kaydırır, kameraya dokunulmaz.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local STEP = 0.14 -- tekerlek adımı başına yüzde
local RESTORE_SECONDS = 0.35
local MIN_OUT_STEP = 2.5 -- uzaklaşırken adım başına en az bu kadar stud
local MIN_THIRD_PERSON = 2 -- pencere açıkken yakınlaşma bu mesafenin altına inmez
local defaultMin = player.CameraMinZoomDistance
local defaultMax = player.CameraMaxZoomDistance
local restoreAt = 0
local restoring = false

local function overScrollable(position: Vector2): boolean
	local inset = GuiService:GetGuiInset()
	for _, object in playerGui:GetGuiObjectsAtPosition(position.X, position.Y - inset.Y) do
		if
			object:IsA("ScrollingFrame")
			and object.Visible
			and object.AbsoluteCanvasSize.Y > object.AbsoluteSize.Y + 1
		then
			return true
		end
	end
	return false
end

-- Zoom mesafesini bir süre sabitleyip sonra normal aralığa döndürür (oyuncu yine normal zoom yapabilir).
local function restoreLater()
	restoreAt = os.clock() + RESTORE_SECONDS
	if restoring then
		return
	end
	restoring = true
	task.spawn(function()
		while os.clock() < restoreAt do
			RunService.Heartbeat:Wait()
		end
		player.CameraMinZoomDistance = defaultMin
		player.CameraMaxZoomDistance = defaultMax
		restoring = false
	end)
end

UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
	if input.UserInputType ~= Enum.UserInputType.MouseWheel or not processed then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera or overScrollable(UserInputService:GetMouseLocation()) then
		return
	end
	local distance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
	local zoomIn = input.Position.Z > 0
	-- Yakınlaşırken ilk kişi moduna girmez (fare kilitlenir); uzaklaşırken küçük mesafeden de en az MIN_OUT_STEP açılır.
	local target = if zoomIn then distance * (1 - STEP) else math.max(distance * (1 + STEP), distance + MIN_OUT_STEP)
	target =
		math.clamp(target, math.max(defaultMin, if zoomIn then MIN_THIRD_PERSON else 0.5), math.min(defaultMax, 120))
	if zoomIn and distance <= MIN_THIRD_PERSON then
		return
	end
	player.CameraMinZoomDistance = target
	player.CameraMaxZoomDistance = target
	restoreLater()
end)
