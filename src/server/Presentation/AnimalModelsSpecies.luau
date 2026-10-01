--!strict
-- Hayvan türü tablosundaki (Config/Species.luau) hayvanların kod modelleri: tür kimliği -> kurucu.
-- Her kurucu `function(model, s)`: s = evre ölçeği; model -Z yönüne (başı) bakar, zemin y = 0, model.PrimaryPart ayarlanır.
-- Kaydı olmayan tür AnimalModels'te inek modeline düşer.

local builders: { [string]: (Model, number) -> () } = {}

return builders
