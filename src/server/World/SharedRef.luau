--!strict
-- World dosyalarının `Shared` klasörüne tek ulaşma yeri (diğer World dosyaları buraya `require` eder).
-- Studio harita eklentisi (plugin/MapTool) World ve Shared'ı bir kum havuzu klasörüne kopyalayıp çalıştırır; o durumda
-- yanımızdaki (kopyadaki) "Shared" kullanılır, aksi halde canlı ReplicatedStorage.Shared. Bu dosya World klasörüyle
-- birlikte kopyalandığından `script.Parent.Parent` iki durumda da doğru kökü verir.
-- Tip analizi (luau-lsp) `Shared:WaitForChild("Config")` zincirini yalnızca kullanım yerindeki `:: typeof(game.ReplicatedStorage.Shared)`
-- dönüşümüyle çözer; bu yüzden World dosyaları `require(...)` sonucunu aynı dönüşümle alır (çalışma anında etkisi yok).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = script.Parent.Parent:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")

return shared :: typeof(ReplicatedStorage.Shared)
