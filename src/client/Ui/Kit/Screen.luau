--!strict
-- Ekran kökü: güvenli alan (çentik/ada) ve ekran boyutuna bağlı tek kök ölçek.
-- Her tam ekran ScreenGui bunu `UiKit.screenRoot(gui)` ile kurar ve pencereleri/panelleri dönen kökün altına koyar.
-- UIScale çocukların ölçek tabanlı konumlarını da küçülteceği için kök kare 1/ölçek büyüklüğündedir;
-- sağ/alt kenara yaslı öğeler yerinde kalır.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UiScale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("UiScale"))

local Screen = {}

local FALLBACK_VIEWPORT = Vector2.new(1920, 1080)

local function cameraViewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else FALLBACK_VIEWPORT
end

-- Geçerli kök ölçek (ekran boyutundan; tüm ScreenGui'ler aynı değeri kullanır)
function Screen.scale(): number
	local viewport = cameraViewport()
	return UiScale.forViewport(viewport.X, viewport.Y)
end

-- Arayüz piksellerinde etkin ekran boyutu (ölçek uygulanmış): sığdırma/kompakt kararları bunu kullanır.
function Screen.viewport(): Vector2
	return cameraViewport() / Screen.scale()
end

-- ScreenGui'yi güvenli alana oturtur ve ölçekli kök çerçeveyi döndürür.
-- Üst çubuk kenardan kenara kalabilsin diye Roblox üst şeridinin altına uzanır (eski IgnoreGuiInset = true);
-- yalnızca cihazın güvenli alanı (çentik, ev çubuğu) dışarıda bırakılır.
function Screen.root(gui: ScreenGui): Frame
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root

	local function apply()
		local value = Screen.scale()
		scale.Scale = value
		root.Size = UDim2.fromScale(1 / value, 1 / value)
	end
	local cameraConnection: RBXScriptConnection? = nil
	local function watchCamera()
		if cameraConnection then
			cameraConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		if camera then
			cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
		end
		apply()
	end
	local cameraChanged = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	root.Destroying:Connect(function()
		cameraChanged:Disconnect()
		if cameraConnection then
			cameraConnection:Disconnect()
		end
	end)
	watchCamera()
	return root
end

return Screen
