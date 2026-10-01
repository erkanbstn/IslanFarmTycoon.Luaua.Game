--!strict
-- Hayvan türü tablosundaki (Config/Species.luau) küçük adaların bölge görselleri: bölge kimliği ("<tür>_pen") -> kurucu.
-- Her kurucu `function(decor, o, size)`: decor içine yapıları kurar (o = bölge zemininin merkez CFrame'i; -Z ön, +Z arka).

local ZoneParts = require(script.Parent:WaitForChild("ZoneParts"))

local builders: { [string]: ZoneParts.Builder } = {}

return builders
