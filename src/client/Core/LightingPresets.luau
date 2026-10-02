--!strict
-- Işık preset'leri: gündüz/gece/hava/mevsim değerleri Studio'da düzenlenen `Lighting.Presets` klasöründedir
-- (kaynak dosya: src/lighting/Presets.rbxmx; Rojo Lighting altına koyar). Kod yalnızca bu değerler arasında geçiş yapar.
-- Değer okunamazsa (silinmiş/yanlış adlı) bir kez uyarılır ve nötr değer döner; efekt çökmez.
local Lighting = game:GetService("Lighting")

local LightingPresets = {}

local root: Instance? = Lighting:WaitForChild("Presets", 10)
local warned: { [string]: boolean } = {}

local function find(path: string): Instance?
	local current: Instance? = root
	for _, name in string.split(path, "/") do
		current = if current then current:FindFirstChild(name) else nil
	end
	return current
end

local function missing(path: string)
	if not warned[path] then
		warned[path] = true
		warn(`[LightingPresets] Lighting.Presets/{path} bulunamadı; nötr değer kullanılıyor`)
	end
end

-- Örn. number("Day/Brightness"), number("Weather/rain/Fog")
function LightingPresets.number(path: string): number
	local value = find(path)
	if value and value:IsA("NumberValue") then
		return value.Value
	end
	missing(path)
	return 0
end

function LightingPresets.color(path: string): Color3
	local value = find(path)
	if value and value:IsA("Color3Value") then
		return value.Value
	end
	missing(path)
	return Color3.new(1, 1, 1)
end

-- Bir klasördeki ad listesi (örn. hava kimlikleri)
function LightingPresets.names(path: string): { string }
	local folder = find(path)
	local list: { string } = {}
	if folder then
		for _, child in folder:GetChildren() do
			table.insert(list, child.Name)
		end
	end
	return list
end

return LightingPresets
