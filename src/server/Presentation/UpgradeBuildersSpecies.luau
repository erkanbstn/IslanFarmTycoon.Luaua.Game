--!strict
-- Hayvan türü tablosundaki (Config/Species.luau) her fabrika ve ürün merkezi binası: yükseltme kimliği -> kurucu.
-- Her kurucu `function(model, base)`: model içine parçalar kurar (base = yapı noktasının CFrame'i, pivot zemine oturur).
-- Henüz yazılmamış bina için kayıt yoktur; UpgradeVisualService o binayı çizmez (yapım alanı da çıkmaz).

local UpgradeParts = require(script.Parent:WaitForChild("UpgradeParts"))

local builders: { [string]: UpgradeParts.Builder } = {}

return builders
