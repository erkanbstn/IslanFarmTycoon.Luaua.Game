--!strict
-- Yol, çit, fıçı, sandık, posta kutusu, saman balyası, korkuluk, el arabası ve toplu optimizasyon.
-- Eşyalar hazır modellerden gelir (assets/CommonDecor); yol kodla çizilir (uzunluğu/yönü değişken).
-- WorldDecor cephesi bunları birleştirir; her zaman `WorldDecor.<ad>` ile kullan.

local ModelAssets = require(script.Parent:WaitForChild("ModelAssets"))
local Parts = require(script.Parent:WaitForChild("DecorParts"))

local part = Parts.part

local Props = {}

-- Taş yol: zeminin hemen üstünde ince parça. Kesişen yollar aynı yükseklikte olursa titrer (z-fighting),
-- bu yüzden her yol bir öncekinden birkaç milim yüksek.
local pathLayer = 0

function Props.path(parent: Instance, from: Vector3, to: Vector3, width: number)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	if length < 0.1 then
		return
	end
	pathLayer = (pathLayer + 1) % 6
	local y = from.Y + 0.08 + pathLayer * 0.03
	local a = Vector3.new(from.X, y, from.Z)
	local cf = CFrame.lookAt(a + flat / 2, a + flat)
	local p = part(
		parent,
		"Path",
		Vector3.new(width, 0.16, length + width * 0.6),
		cf,
		Color3.fromRGB(150, 145, 135),
		Enum.Material.Cobblestone
	)
	p.CastShadow = false
end

-- Çapraz iki ince levhadan oluşan çim tutamları ve ara sıra çiçekler. Çarpışmaz, sorgulanmaz.
-- base: ada/bölge yüzeyinde (Y yüzeyde) CFrame. Sabit tohum: aynı harita her seferinde aynı çıkar.
-- Çizim maliyeti: küçük süs parçaları gölge düşürmez; çarpışmayan parçalar ışın sorgularına girmez.
-- Kurulum/dekor bittikten sonra bir kez çağrılır (gölge haritası ve Raycast maliyetini düşürür).
function Props.optimize(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			if not descendant.CanCollide then
				descendant.CanQuery = false
			end
			local size = descendant.Size
			if descendant.CastShadow and math.max(size.X, size.Y, size.Z) < 1.6 then
				descendant.CastShadow = false
			end
		end
	end
end

local FOLDER = "CommonDecor"
local missingWarned: { [string]: boolean } = {}

-- Hazır süs modelini kopyalar; yoksa bir kez uyarır. `scale` verilirse model o oranda ölçeklenir.
local function placeDecor(parent: Instance, name: string, base: CFrame, scale: number?): Model?
	local model = ModelAssets.clone(FOLDER, name)
	if not model then
		if not missingWarned[name] then
			missingWarned[name] = true
			warn(`[DecorProps] assets/{FOLDER}/{name}.rbxmx bulunamadı; süs çizilmedi`)
		end
		return nil
	end
	if scale and math.abs(scale - 1) > 0.01 then
		model:ScaleTo(scale)
	end
	model:PivotTo(base)
	model.Parent = parent
	return model
end

Props.placeDecor = placeDecor

function Props.barrel(parent: Instance, base: CFrame)
	placeDecor(parent, "Barrel", base)
end

-- Sandık: kenarı 1.6 / 2 / 2.4 stud'luk üç model; istenen boyuta en yakını seçilir, kalan fark ölçekle kapanır
local CRATES = { { edge = 1.6, name = "Crate_16" }, { edge = 2, name = "Crate_20" }, { edge = 2.4, name = "Crate_24" } }
function Props.crate(parent: Instance, base: CFrame, size: number)
	local best = CRATES[1]
	for _, crate in CRATES do
		if math.abs(crate.edge - size) < math.abs(best.edge - size) then
			best = crate
		end
	end
	placeDecor(parent, best.name, base, size / best.edge)
end

function Props.mailbox(parent: Instance, base: CFrame)
	placeDecor(parent, "Mailbox", base)
end

-- Alçak ahşap çit: iki nokta arası, 8 stud'luk çit modelleri uç uca (model +X yönünde uzanır, pivot başlangıçta)
function Props.fenceRun(parent: Instance, from: Vector3, to: Vector3)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	if length < 1 then
		return
	end
	local dir = flat.Unit
	local count = math.max(1, math.round(length / 8))
	local segment = length / count
	for i = 0, count - 1 do
		local start = from + dir * (segment * i)
		placeDecor(parent, "Fence_8", CFrame.fromMatrix(start, dir, Vector3.yAxis), segment / 8)
	end
end

-- Saman balyası (küçük yığınlar için); stack: üstüne konacak ikinci bale
function Props.hayBale(parent: Instance, base: CFrame, stack: boolean?)
	placeDecor(parent, if stack then "HayBale_Stack" else "HayBale_Single", base)
end

function Props.scarecrow(parent: Instance, base: CFrame)
	placeDecor(parent, "Scarecrow", base)
end

function Props.wheelbarrow(parent: Instance, base: CFrame)
	placeDecor(parent, "Wheelbarrow", base)
end

return Props
