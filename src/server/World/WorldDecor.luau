--!strict
-- Doğal görünüm: Terrain ile kıyı (su altı kayalık, kum plaj, kıyı kayaları) ve detaylı süs eşyaları
-- (ağaç çeşitleri, çalı, çiçek, fener, fıçı, sandık, posta kutusu, iskele).
-- MapBuilder bunları çağırır; PlotService kilitli uzman adaların zeminini buradan değiştirir.
--
-- Not: Ada ÜSTÜ Terrain değil, düz bir parçadır (MapBuilder). Terrain yüzeyi 4 stud'luk ızgaraya
-- oturduğu için hesaplanandan 1-2 stud yukarıda çıkıp yerdeki ince parçaları (yol, platform, ağıl
-- zemini) gömüyordu. Kum, üst parçanın altında kalacak şekilde alçak tutulur.

-- Parçalar: DecorParts, DecorProps, DecorShore, DecorNature, DecorLights.

local Props = require(script.Parent:WaitForChild("DecorProps"))
local Shore = require(script.Parent:WaitForChild("DecorShore"))
local Nature = require(script.Parent:WaitForChild("DecorNature"))
local Lights = require(script.Parent:WaitForChild("DecorLights"))

export type GrassRect = Nature.GrassRect
export type GrassSpec = Nature.GrassSpec

local WorldDecor = {}

-- DecorProps
WorldDecor.path = Props.path
WorldDecor.optimize = Props.optimize
WorldDecor.barrel = Props.barrel
WorldDecor.crate = Props.crate
WorldDecor.mailbox = Props.mailbox
WorldDecor.fenceRun = Props.fenceRun
WorldDecor.hayBale = Props.hayBale
WorldDecor.scarecrow = Props.scarecrow
WorldDecor.wheelbarrow = Props.wheelbarrow
-- DecorShore
WorldDecor.terrainIsland = Shore.terrainIsland
WorldDecor.shoreRocks = Shore.shoreRocks
WorldDecor.pierPile = Shore.pierPile
WorldDecor.dock = Shore.dock
-- DecorNature
WorldDecor.oakTree = Nature.oakTree
WorldDecor.pineTree = Nature.pineTree
WorldDecor.birchTree = Nature.birchTree
WorldDecor.bush = Nature.bush
WorldDecor.flowerPatch = Nature.flowerPatch
WorldDecor.grassTufts = Nature.grassTufts
WorldDecor.grassPatches = Nature.grassPatches
-- DecorLights
WorldDecor.lamp = Lights.lamp
WorldDecor.markNightWindow = Lights.markNightWindow
WorldDecor.smallLamp = Lights.smallLamp

return WorldDecor
