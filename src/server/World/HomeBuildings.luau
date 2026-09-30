--!strict
-- Genel (ana) adanın zenginleştirilmesi: çiftlik evi, yel değirmeni, kuyu, sebze bahçesi, meyve bahçesi,
-- arı kovanları, ambar ve pazar tezgâhı (sipariş panosu). Haritaya kaydedilir (MapBuilder çağırır).
-- Her yapı yerel çerçevede kurulur: -Z ön (kapı yönü), taban zemin yüzeyindedir.
-- Karakterin girebilmesi için kapılar >= 4.6 x 6.6 stud'dur (kümes/ahır ile aynı ölçü kuralı).
-- Parçalar: HomeParts (renkler/yapı taşları), HomeHouses, HomeFarmland, HomeMarket, HomeLandmarks.

local Houses = require(script.Parent:WaitForChild("HomeHouses"))
local Farmland = require(script.Parent:WaitForChild("HomeFarmland"))
local Market = require(script.Parent:WaitForChild("HomeMarket"))
local Landmarks = require(script.Parent:WaitForChild("HomeLandmarks"))

local HomeBuildings = {}

HomeBuildings.farmhouse = Houses.farmhouse
HomeBuildings.windmill = Houses.windmill
HomeBuildings.well = Houses.well
HomeBuildings.granary = Houses.granary
HomeBuildings.vegetableGarden = Farmland.vegetableGarden
HomeBuildings.orchard = Farmland.orchard
HomeBuildings.beehives = Farmland.beehives
HomeBuildings.market = Market.market
HomeBuildings.landmark = Landmarks.landmark

return HomeBuildings
