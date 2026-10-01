--!strict
-- Hayvan türü tablosundaki (Config/Species.luau) her fabrika ve ürün merkezi binası: yükseltme kimliği -> kurucu.
-- Her kurucu `function(model, base)`: model içine parçalar kurar (base = yapı noktasının CFrame'i, pivot zemine oturur, ön yüz -Z).
-- Fabrikalar gösterişli (10x6x8 gövde + çatı amblemi), ürün merkezleri mütevazı depo görünümlüdür. Bina başına ~35 parça sınırı.

local WorldDecor = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("WorldDecor"))
local UpgradeParts = require(script.Parent:WaitForChild("UpgradeParts"))

local makePart = UpgradeParts.makePart
local makeColumn = UpgradeParts.makeColumn
local makeBall = UpgradeParts.makeBall
local GOLD = UpgradeParts.GOLD
local METAL = UpgradeParts.METAL

local v3 = Vector3.new
local rgb = Color3.fromRGB
local M = Enum.Material

type ShellCfg = {
	wall: Color3,
	wallMat: Enum.Material,
	roof: Color3,
	roofMat: Enum.Material,
	door: Color3,
	glass: Color3,
	trim: Color3?,
	gable: boolean?,
}

-- Yerel koordinatta (base'e göre) parça; rot derece cinsinden (X, Y, Z)
local function put(
	model: Model,
	base: CFrame,
	name: string,
	size: Vector3,
	pos: Vector3,
	color: Color3,
	material: Enum.Material?,
	rot: Vector3?
): Part
	local cf = base * CFrame.new(pos)
	if rot then
		cf = cf * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	end
	return makePart(model, name, size, cf, color, material)
end

-- Silindir: eksen "Y" dik, "X" yatay (sağ-sol), "Z" yatay (ön-arka)
local function cyl(
	model: Model,
	base: CFrame,
	name: string,
	diameter: number,
	length: number,
	pos: Vector3,
	color: Color3,
	material: Enum.Material?,
	axis: "X" | "Y" | "Z"
): Part
	local cf = base * CFrame.new(pos)
	if axis == "Y" then
		return makeColumn(model, name, diameter, length, cf, color, material)
	end
	if axis == "Z" then
		cf = cf * CFrame.Angles(0, math.rad(90), 0)
	end
	local part = makePart(model, name, v3(length, diameter, diameter), cf, color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Elipsoit (yassı/uzun top)
local function blob(
	model: Model,
	base: CFrame,
	name: string,
	size: Vector3,
	pos: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = makeBall(model, name, size.X, base * CFrame.new(pos), color, material)
	part.Size = size
	return part
end

-- Cam pencere: adında "Window" geçer, gece ışığına bağlanır
local function windowAt(model: Model, base: CFrame, pos: Vector3, size: Vector3, color: Color3)
	local window = put(model, base, "Window", size, pos, color, M.Glass)
	WorldDecor.markNightWindow(window)
end

-- Fabrika iskeleti: 10x6x8 gövde, düz ya da çatılı tavan, kapı, iki pencere
local function shell(model: Model, base: CFrame, c: ShellCfg)
	put(model, base, "Building", v3(10, 6, 8), v3(0, 3, 0), c.wall, c.wallMat)
	if c.gable then
		for _, s in { -1, 1 } do
			put(model, base, "Roof", v3(6.6, 0.7, 9.6), v3(s * 2.9, 7.3, 0), c.roof, c.roofMat, v3(0, 0, -s * 22))
		end
		put(model, base, "RoofRidge", v3(0.8, 0.6, 9.8), v3(0, 8.5, 0), c.trim or c.roof, c.roofMat)
	else
		put(model, base, "Roof", v3(11, 0.9, 9), v3(0, 6.45, 0), c.roof, c.roofMat)
	end
	put(model, base, "Door", v3(2.8, 4.4, 0.3), v3(0, 2.2, -4.1), c.door, M.Wood)
	for _, x in { -3.2, 3.2 } do
		windowAt(model, base, v3(x, 3.6, -4.05), v3(1.8, 1.6, 0.2), c.glass)
	end
end

-- Ürün merkezi iskeleti: 9x4.5x6.4 alçak depo, hafif eğimli çatı, kapı (x=1.6) ve pencere (x=-2.4)
local function depot(model: Model, base: CFrame, c: ShellCfg)
	put(model, base, "Building", v3(9, 4.5, 6.4), v3(0, 2.25, 0), c.wall, c.wallMat)
	put(model, base, "Roof", v3(10, 0.6, 7.4), v3(0, 4.8, 0), c.roof, c.roofMat, v3(0, 0, 3))
	put(model, base, "Door", v3(2.4, 3.2, 0.3), v3(1.6, 1.6, -3.25), c.door, M.Wood)
	windowAt(model, base, v3(-2.4, 2.8, -3.25), v3(1.6, 1.4, 0.2), c.glass)
end

-- Yelpaze: pivottan açılan ince tüyler/dilimler (Z çevresinde döner)
local function fan(
	model: Model,
	base: CFrame,
	name: string,
	pivot: Vector3,
	length: number,
	width: number,
	angles: { number },
	colors: { Color3 },
	material: Enum.Material
)
	for i, deg in angles do
		local rad = math.rad(deg)
		local pos = pivot + v3(-math.sin(rad) * length / 2, math.cos(rad) * length / 2, 0)
		put(model, base, name, v3(width, length, 0.3), pos, colors[(i - 1) % #colors + 1], material, v3(0, 0, deg))
	end
end

-- Altıgen (petek) amblem: 0/60/120 derece dönmüş üç dikdörtgen, ön yüze (-Z) bakar
local function hex(
	model: Model,
	base: CFrame,
	name: string,
	center: Vector3,
	side: number,
	color: Color3,
	material: Enum.Material?
)
	for _, deg in { 0, 60, 120 } do
		put(model, base, name, v3(side * 1.732, side, 0.4), center, color, material, v3(0, 0, deg))
	end
end

local function barrel(model: Model, base: CFrame, pos: Vector3, color: Color3)
	cyl(model, base, "Barrel", 2, 2.4, pos, color, M.Wood, "Y")
	cyl(model, base, "BarrelBand", 2.15, 0.25, pos, METAL, M.Metal, "Y")
end

local function crate(model: Model, base: CFrame, pos: Vector3, size: Vector3, color: Color3)
	put(model, base, "Crate", size, pos, color, M.WoodPlanks)
end

local builders: { [string]: UpgradeParts.Builder } = {
	-- ===== Çiftlik 2: Göl ve Yün =====

	-- Angora Değirmeni: krem taş değirmen, çatıda yün yumakları, yanda su çarkı
	angora_mill = function(model, base)
		shell(model, base, {
			wall = rgb(238, 232, 220),
			wallMat = M.Concrete,
			roof = rgb(110, 130, 155),
			roofMat = M.Slate,
			door = rgb(120, 90, 70),
			glass = rgb(170, 205, 235),
			trim = rgb(235, 240, 245),
			gable = true,
		})
		local wool = rgb(250, 250, 250)
		blob(model, base, "WoolBall", v3(2.6, 2.6, 2.6), v3(-1.8, 9.4, 0), wool, M.Fabric)
		blob(model, base, "WoolBall", v3(3, 3, 3), v3(1.6, 9.5, 0), wool, M.Fabric)
		blob(model, base, "WoolBall", v3(2.6, 2.6, 2.6), v3(0, 10.9, 0), wool, M.Fabric)
		cyl(model, base, "WaterWheel", 5.2, 0.8, v3(5.6, 3, 0), rgb(130, 90, 55), M.Wood, "X")
		put(model, base, "WheelSpoke", v3(0.5, 5, 0.5), v3(5.6, 3, 0), rgb(95, 65, 40), M.Wood)
		put(model, base, "WheelSpoke", v3(0.5, 0.5, 5), v3(5.6, 3, 0), rgb(95, 65, 40), M.Wood)
		put(model, base, "Trough", v3(1.4, 0.8, 6), v3(5.6, 0.4, 0), rgb(80, 140, 190), M.SmoothPlastic)
	end,

	-- Angora Tezgâhı: lavanta depo, yan tarafta yün balyaları ve iplik makaraları
	angora_loom = function(model, base)
		depot(model, base, {
			wall = rgb(205, 195, 225),
			wallMat = M.Concrete,
			roof = rgb(150, 130, 180),
			roofMat = M.Slate,
			door = rgb(110, 85, 100),
			glass = rgb(190, 215, 240),
		})
		local wool = rgb(248, 246, 242)
		put(model, base, "WoolBale", v3(2.4, 1.6, 1.8), v3(6, 0.8, -1), wool, M.Fabric)
		put(model, base, "WoolBale", v3(2.4, 1.6, 1.8), v3(6, 0.8, 1.2), wool, M.Fabric)
		put(model, base, "WoolBale", v3(2.2, 1.4, 1.8), v3(6, 2.3, 0.1), wool, M.Fabric)
		cyl(model, base, "Spool", 1, 1.6, v3(-5.6, 0.8, -1.2), rgb(240, 150, 170), M.Fabric, "Y")
		cyl(model, base, "Spool", 1, 1.6, v3(-5.6, 0.8, 0.4), rgb(150, 190, 235), M.Fabric, "Y")
		cyl(model, base, "Spool", 1, 1.6, v3(-5.6, 2.4, -0.4), rgb(200, 170, 235), M.Fabric, "Y")
	end,

	-- ===== Çiftlik 3: Güneşli Tarla (sıcak, kumlu) =====

	-- Hindi Paketleme Fabrikası: kırmızı ambar, çatıda hindi kuyruğu yelpazesi
	turkey_packer = function(model, base)
		shell(model, base, {
			wall = rgb(165, 60, 45),
			wallMat = M.WoodPlanks,
			roof = rgb(80, 55, 40),
			roofMat = M.WoodPlanks,
			door = rgb(235, 220, 190),
			glass = rgb(255, 210, 140),
			trim = rgb(235, 225, 200),
			gable = true,
		})
		fan(
			model,
			base,
			"TailFeather",
			v3(0, 8.8, -1),
			4.6,
			1.5,
			{ -72, -36, 0, 36, 72 },
			{ rgb(225, 120, 40), rgb(120, 75, 45), rgb(180, 50, 40), rgb(230, 170, 50), rgb(120, 75, 45) },
			M.SmoothPlastic
		)
		blob(model, base, "TurkeyBody", v3(3, 2.8, 3), v3(0, 9.4, -1.6), rgb(135, 85, 50), M.Fabric)
		blob(model, base, "TurkeyHead", v3(1.4, 1.6, 1.4), v3(0, 11.2, -2.6), rgb(200, 60, 55), M.SmoothPlastic)
		put(model, base, "TurkeyBeak", v3(0.4, 0.4, 0.7), v3(0, 11.0, -3.4), rgb(240, 180, 50), M.SmoothPlastic)
	end,

	-- Hindi Füme Atölyesi: kahverengi füme deposu, tüten baca, varil ve kasalar
	turkey_center = function(model, base)
		depot(model, base, {
			wall = rgb(120, 80, 55),
			wallMat = M.WoodPlanks,
			roof = rgb(60, 45, 35),
			roofMat = M.Slate,
			door = rgb(80, 55, 40),
			glass = rgb(255, 205, 130),
		})
		put(model, base, "Chimney", v3(1.4, 3.4, 1.4), v3(-3, 6.3, 1), rgb(140, 70, 50), M.Brick)
		for i, y in { 8.4, 9.6 } do
			local puff = blob(
				model,
				base,
				"Smoke",
				v3(1.6 - i * 0.3, 1.2, 1.6 - i * 0.3),
				v3(-3, y, 1),
				rgb(175, 175, 175),
				M.Fabric
			)
			puff.Transparency = 0.45
		end
		crate(model, base, v3(5.8, 0.9, -1), v3(2, 1.8, 2), rgb(150, 105, 60))
		crate(model, base, v3(5.8, 0.9, 1.4), v3(2, 1.8, 2), rgb(135, 95, 55))
		barrel(model, base, v3(-5.8, 1.2, -1), rgb(105, 70, 45))
		barrel(model, base, v3(-5.8, 1.2, 1.2), rgb(105, 70, 45))
	end,

	-- Bal Şişeleme Atölyesi: sarı-kahverengi gövde, petek amblemi, damlayan bal, dev kavanoz
	honey_mill = function(model, base)
		shell(model, base, {
			wall = rgb(225, 170, 60),
			wallMat = M.WoodPlanks,
			roof = rgb(120, 70, 35),
			roofMat = M.WoodPlanks,
			door = rgb(110, 65, 35),
			glass = rgb(255, 225, 130),
			gable = true,
		})
		hex(model, base, "HoneyComb", v3(0, 10.2, -0.5), 1.9, rgb(255, 195, 40), M.SmoothPlastic)
		put(model, base, "HoneyDrip", v3(10.6, 0.5, 0.5), v3(0, 5.95, -4.3), rgb(245, 165, 30), M.SmoothPlastic)
		for _, x in { -3.6, -1.2, 1.8, 3.9 } do
			put(model, base, "HoneyDrip", v3(0.5, 1.2, 0.4), v3(x, 5.3, -4.3), rgb(245, 165, 30), M.SmoothPlastic)
		end
		cyl(model, base, "HoneyJar", 2.4, 3, v3(6, 1.5, -1), rgb(230, 150, 30), M.Glass, "Y")
		cyl(model, base, "JarLid", 2.6, 0.5, v3(6, 3.2, -1), rgb(120, 70, 35), M.Wood, "Y")
	end,

	-- Bal Süzme Evi: amber depo, paslanmaz süzgeç tankı, arı kovanı kutuları
	honey_extractor = function(model, base)
		depot(model, base, {
			wall = rgb(235, 200, 90),
			wallMat = M.WoodPlanks,
			roof = rgb(130, 80, 40),
			roofMat = M.WoodPlanks,
			door = rgb(115, 70, 40),
			glass = rgb(255, 225, 140),
		})
		cyl(model, base, "Extractor", 3.2, 4, v3(5.8, 2, 0.5), rgb(200, 200, 205), M.Metal, "Y")
		blob(model, base, "ExtractorLid", v3(3.4, 1.2, 3.4), v3(5.8, 4.1, 0.5), GOLD, M.Metal)
		put(model, base, "Spigot", v3(0.5, 0.5, 1), v3(5.8, 0.8, -1.6), rgb(90, 90, 95), M.Metal)
		local hive = { rgb(240, 200, 70), rgb(215, 160, 45), rgb(240, 200, 70) }
		for i, color in hive do
			put(model, base, "Hive", v3(2.2, 1.1, 2.2), v3(-5.6, 0.55 + (i - 1) * 1.1, -1.2), color, M.WoodPlanks)
		end
		put(model, base, "HiveRoof", v3(2.7, 0.4, 2.7), v3(-5.6, 3.5, -1.2), rgb(110, 75, 45), M.Wood)
		barrel(model, base, v3(-5.6, 1.2, 1.6), rgb(225, 150, 40))
	end,

	-- Kervan Postası: kumtaşı kaide üzerinde çizgili çöl çadırı, bayrak ve ön avluda deve
	caravan_post = function(model, base)
		put(model, base, "Building", v3(10, 4, 8), v3(0, 2, 0), rgb(225, 195, 145), M.Sandstone)
		put(model, base, "Tent", v3(6.2, 0.4, 9.6), v3(-2.7, 5.3, 0), rgb(200, 60, 50), M.Fabric, v3(0, 0, -35))
		put(model, base, "Tent", v3(6.2, 0.4, 9.6), v3(2.7, 5.3, 0), rgb(240, 225, 190), M.Fabric, v3(0, 0, 35))
		put(model, base, "TentRidge", v3(0.7, 0.5, 9.8), v3(0, 7.1, 0), GOLD, M.Metal)
		put(model, base, "Door", v3(2.8, 3.2, 0.3), v3(0, 1.6, -4.1), rgb(60, 40, 30), M.Wood)
		for _, x in { -3.2, 3.2 } do
			windowAt(model, base, v3(x, 2.8, -4.05), v3(1.4, 1.4, 0.2), rgb(255, 205, 120))
		end
		put(model, base, "FlagPole", v3(0.3, 2.6, 0.3), v3(0, 8.4, -4.4), rgb(110, 75, 45), M.Wood)
		put(model, base, "Flag", v3(1.6, 0.9, 0.1), v3(0.9, 9.2, -4.4), rgb(200, 60, 50), M.Fabric)
		-- Deve heykeli (+X'e bakar)
		local fur = rgb(205, 160, 100)
		put(model, base, "CamelBody", v3(3.4, 1.5, 1.3), v3(-4, 2.5, -6.3), fur, M.Fabric)
		blob(model, base, "CamelHump", v3(1.3, 1.3, 1.2), v3(-4.7, 3.6, -6.3), fur, M.Fabric)
		blob(model, base, "CamelHump", v3(1.3, 1.3, 1.2), v3(-3.3, 3.6, -6.3), fur, M.Fabric)
		put(model, base, "CamelNeck", v3(0.6, 1.9, 0.6), v3(-2.2, 3.2, -6.3), fur, M.Fabric)
		put(model, base, "CamelHead", v3(1.3, 0.7, 0.6), v3(-1.8, 4.2, -6.3), fur, M.Fabric)
		for _, x in { -5.3, -2.7 } do
			for _, z in { -6.0, -6.6 } do
				put(model, base, "CamelLeg", v3(0.4, 1.9, 0.4), v3(x, 0.95, z), fur, M.Fabric)
			end
		end
	end,

	-- Deve Süthanesi: kumtaşı depo, süt güğümleri, hurma ağacı
	camel_dairy = function(model, base)
		depot(model, base, {
			wall = rgb(232, 208, 160),
			wallMat = M.Sandstone,
			roof = rgb(190, 140, 90),
			roofMat = M.Slate,
			door = rgb(120, 85, 55),
			glass = rgb(255, 220, 150),
		})
		cyl(model, base, "PalmTrunk", 0.7, 5.5, v3(5.8, 2.75, 1.5), rgb(130, 90, 55), M.Wood, "Y")
		for _, deg in { 0, 45, 90, 135 } do
			put(model, base, "PalmLeaf", v3(4.4, 0.2, 1), v3(5.8, 5.7, 1.5), rgb(70, 150, 70), M.Grass, v3(0, deg, 0))
		end
		local can = rgb(205, 205, 210)
		cyl(model, base, "MilkCan", 1.3, 2, v3(-5.4, 1, -1.5), can, M.Metal, "Y")
		cyl(model, base, "MilkCan", 1.3, 2, v3(-5.4, 1, 0), can, M.Metal, "Y")
		cyl(model, base, "MilkCan", 1.3, 2, v3(-6.5, 1, -0.7), can, M.Metal, "Y")
		put(model, base, "Trough", v3(2.4, 0.8, 1), v3(-5.6, 0.4, 2), rgb(150, 110, 70), M.Wood)
	end,

	-- ===== Çiftlik 4: Gül Vadisi (gül, pembe-beyaz) =====

	-- Gösteri Köşkü: beyaz mermer açık köşk, kademeli mavi-yeşil çatı, arkada dev renkli tavus yelpazesi
	peacock_pavilion = function(model, base)
		put(model, base, "Building", v3(10, 0.6, 8), v3(0, 0.3, 0), rgb(245, 235, 240), M.Marble)
		for _, x in { -4.4, 4.4 } do
			for _, z in { -3.4, 3.4 } do
				cyl(model, base, "Column", 1, 5.6, v3(x, 3.4, z), rgb(250, 245, 245), M.Marble, "Y")
			end
		end
		put(model, base, "Roof", v3(10.6, 0.7, 8.6), v3(0, 6.5, 0), rgb(30, 140, 150), M.Slate)
		put(model, base, "Roof", v3(7.2, 0.6, 5.8), v3(0, 7.1, 0), rgb(40, 170, 120), M.Slate)
		put(model, base, "Roof", v3(3.4, 0.6, 3), v3(0, 7.7, 0), rgb(45, 100, 190), M.Slate)
		put(model, base, "Finial", v3(0.5, 1.2, 0.5), v3(0, 8.6, 0), GOLD, M.Metal)
		put(model, base, "StageWall", v3(10, 5.6, 0.5), v3(0, 3.4, 3.8), rgb(240, 200, 215), M.Concrete)
		local longFeather = { rgb(30, 140, 150), rgb(40, 90, 190), rgb(60, 170, 90) }
		fan(
			model,
			base,
			"PeacockFeather",
			v3(0, 1.4, 3.3),
			5.2,
			1.1,
			{ -80, -60, -40, -20, 0, 20, 40, 60, 80 },
			longFeather,
			M.SmoothPlastic
		)
		fan(model, base, "PeacockEye", v3(0, 1.4, 3.1), 3, 0.9, { -60, -30, 0, 30, 60 }, { GOLD }, M.SmoothPlastic)
		for _, x in { -3.2, 3.2 } do
			windowAt(model, base, v3(x, 4.6, -3.2), v3(1.2, 1.6, 0.2), rgb(150, 215, 225))
		end
	end,

	-- Süs Atölyesi: pembe depo, vazoda tavus tüyleri, renkli kumaş makaraları
	peacock_atelier = function(model, base)
		depot(model, base, {
			wall = rgb(240, 205, 215),
			wallMat = M.Concrete,
			roof = rgb(50, 140, 150),
			roofMat = M.Slate,
			door = rgb(150, 90, 110),
			glass = rgb(190, 225, 235),
		})
		cyl(model, base, "Vase", 0.9, 1.4, v3(5.4, 0.7, -2), rgb(40, 150, 170), M.Glass, "Y")
		put(
			model,
			base,
			"Feather",
			v3(0.5, 3, 0.15),
			v3(5.4, 2.6, -2),
			rgb(30, 150, 140),
			M.SmoothPlastic,
			v3(0, 0, 12)
		)
		put(model, base, "Feather", v3(0.5, 3, 0.15), v3(5.4, 2.7, -2), rgb(40, 90, 190), M.SmoothPlastic)
		put(model, base, "Feather", v3(0.5, 3, 0.15), v3(5.4, 2.6, -2), GOLD, M.SmoothPlastic, v3(0, 0, -12))
		cyl(model, base, "FabricRoll", 1.3, 2.4, v3(-5.2, 0.65, 0), rgb(200, 50, 130), M.Fabric, "Z")
		cyl(model, base, "FabricRoll", 1.3, 2.4, v3(-6.5, 0.65, 0), rgb(40, 150, 170), M.Fabric, "Z")
		cyl(model, base, "FabricRoll", 1.3, 2.4, v3(-5.85, 1.8, 0), rgb(240, 190, 60), M.Fabric, "Z")
	end,

	-- Bıldırcın Kuluçkası: kumlu kuluçka evi, çatıda benekli dev yumurta, yerde küçük yumurtalar
	quail_hatchery = function(model, base)
		shell(model, base, {
			wall = rgb(215, 185, 135),
			wallMat = M.Sandstone,
			roof = rgb(150, 100, 65),
			roofMat = M.WoodPlanks,
			door = rgb(110, 75, 50),
			glass = rgb(255, 190, 110),
		})
		blob(model, base, "Egg", v3(4.6, 5.8, 4.6), v3(0, 9.3, 0), rgb(245, 235, 210), M.SmoothPlastic)
		local speck = rgb(120, 80, 50)
		for _, p in
			{ v3(-0.8, 10, -2), v3(0.9, 9.2, -2.05), v3(-0.3, 8.4, -2.1), v3(1, 10.4, -1.7), v3(-1.2, 9, -2.05) }
		do
			blob(model, base, "EggSpeck", v3(0.7, 0.7, 0.4), p, speck, M.SmoothPlastic)
		end
		for _, x in { -6, 6 } do
			blob(model, base, "SmallEgg", v3(1.2, 1.6, 1.2), v3(x, 0.8, -2), rgb(235, 220, 190), M.SmoothPlastic)
		end
	end,

	-- Bıldırcın Toplama Merkezi: ahşap depo, yumurta kasaları ve küçük kümes
	quail_coop = function(model, base)
		depot(model, base, {
			wall = rgb(190, 150, 100),
			wallMat = M.WoodPlanks,
			roof = rgb(100, 70, 45),
			roofMat = M.Slate,
			door = rgb(95, 65, 40),
			glass = rgb(255, 205, 130),
		})
		crate(model, base, v3(5.6, 0.5, -1.2), v3(2.4, 1, 1.6), rgb(215, 190, 140))
		for _, z in { -1.7, -0.9 } do
			blob(model, base, "Egg", v3(0.7, 0.9, 0.7), v3(5.6, 1.4, z), rgb(245, 235, 210), M.SmoothPlastic)
		end
		for _, z in { -0.4, 0.4 } do
			blob(model, base, "Egg", v3(0.7, 0.9, 0.7), v3(5.6, 1.4, z + 1.2), rgb(235, 215, 185), M.SmoothPlastic)
		end
		put(model, base, "CoopLeg", v3(0.3, 1, 0.3), v3(-5.6, 0.5, -0.8), rgb(95, 65, 40), M.Wood)
		put(model, base, "CoopLeg", v3(0.3, 1, 0.3), v3(-5.6, 0.5, 1.2), rgb(95, 65, 40), M.Wood)
		put(model, base, "Coop", v3(2.6, 1.8, 2.4), v3(-5.6, 1.9, 0.2), rgb(165, 120, 75), M.WoodPlanks)
		put(model, base, "CoopRoof", v3(3, 0.4, 2.8), v3(-5.6, 3, 0.2), rgb(100, 70, 45), M.Slate)
		put(model, base, "CoopRamp", v3(0.8, 0.2, 2), v3(-4.1, 0.8, -1.2), rgb(130, 90, 55), M.Wood, v3(25, 0, 0))
	end,

	-- Kaymak Fabrikası: krem beyaz fabrika, kırmızı kiremit, çatıda manda boynuzları ve süt silosu
	buffalo_packer = function(model, base)
		shell(model, base, {
			wall = rgb(240, 238, 225),
			wallMat = M.Concrete,
			roof = rgb(170, 70, 60),
			roofMat = M.Slate,
			door = rgb(70, 100, 150),
			glass = rgb(175, 210, 235),
			trim = rgb(235, 225, 205),
			gable = true,
		})
		put(model, base, "BlueBand", v3(10.2, 0.5, 8.2), v3(0, 4.7, 0), rgb(50, 90, 160), M.SmoothPlastic)
		local bone = rgb(235, 225, 200)
		put(model, base, "HornBase", v3(2.4, 1.4, 1.8), v3(0, 9.2, -0.2), rgb(60, 50, 45), M.Fabric)
		for _, s in { -1, 1 } do
			put(model, base, "Horn", v3(1.2, 2.6, 1.2), v3(s * 2.2, 10, -0.2), bone, M.SmoothPlastic, v3(0, 0, -s * 22))
			put(model, base, "Horn", v3(0.9, 2, 0.9), v3(s * 3.5, 11.6, -0.2), bone, M.SmoothPlastic, v3(0, 0, -s * 55))
		end
		cyl(model, base, "Silo", 3, 9, v3(6.4, 4.5, 1), rgb(235, 240, 245), M.Metal, "Y")
		blob(model, base, "SiloDome", v3(3, 1.8, 3), v3(6.4, 9.2, 1), rgb(235, 240, 245), M.Metal)
	end,

	-- Kaymak Toplama Merkezi: beyaz depo, mavi çatı, süt güğümleri ve yatay kaymak tankı
	buffalo_center = function(model, base)
		depot(model, base, {
			wall = rgb(235, 235, 230),
			wallMat = M.Concrete,
			roof = rgb(60, 100, 165),
			roofMat = M.Slate,
			door = rgb(70, 100, 150),
			glass = rgb(175, 210, 235),
		})
		for i = 1, 3 do
			local z = -1.6 + (i - 1) * 1.6
			cyl(model, base, "Churn", 1.5, 2.2, v3(5.8, 1.1, z), rgb(205, 208, 212), M.Metal, "Y")
			cyl(model, base, "ChurnLid", 1.7, 0.3, v3(5.8, 2.35, z), rgb(60, 100, 165), M.Metal, "Y")
		end
		cyl(model, base, "CreamTank", 2.6, 4, v3(-5.8, 1.8, 0), rgb(240, 235, 215), M.Metal, "Z")
		put(model, base, "TankStand", v3(2, 0.5, 4.4), v3(-5.8, 0.25, 0), rgb(110, 110, 115), M.Metal)
	end,

	-- ===== Çiftlik 5: Dağ ve Orman (taş, koyu yeşil, kürk) =====

	-- Kürk Fabrikası: koyu taş yapı, çatıda yak boynuzları, önde kürk kurutma askısı
	yak_packer = function(model, base)
		shell(model, base, {
			wall = rgb(95, 98, 100),
			wallMat = M.Slate,
			roof = rgb(50, 90, 55),
			roofMat = M.Grass,
			door = rgb(85, 60, 40),
			glass = rgb(200, 220, 240),
			trim = rgb(70, 55, 45),
			gable = true,
		})
		local bone = rgb(230, 225, 205)
		put(model, base, "Skull", v3(2.4, 2, 2), v3(0, 9.5, -0.5), rgb(60, 40, 30), M.Fabric)
		for _, s in { -1, 1 } do
			put(model, base, "Horn", v3(0.8, 3, 0.8), v3(s * 2, 10.6, -0.5), bone, M.SmoothPlastic, v3(0, 0, -s * 35))
			put(
				model,
				base,
				"Horn",
				v3(0.6, 1.8, 0.6),
				v3(s * 3.3, 12.1, -0.5),
				bone,
				M.SmoothPlastic,
				v3(0, 0, -s * 10)
			)
		end
		put(model, base, "Chimney", v3(1.4, 3, 1.4), v3(-3.4, 8.2, 1.8), rgb(80, 82, 85), M.Cobblestone)
		for _, x in { -3.6, 3.6 } do
			put(model, base, "RackPost", v3(0.4, 4.6, 0.4), v3(x, 2.3, -6.3), rgb(85, 60, 40), M.Wood)
		end
		put(model, base, "RackBeam", v3(7.8, 0.4, 0.4), v3(0, 4.5, -6.3), rgb(85, 60, 40), M.Wood)
		local pelt = { rgb(110, 75, 50), rgb(70, 50, 40), rgb(140, 100, 65) }
		for i, color in pelt do
			put(model, base, "Pelt", v3(1.5, 2.6, 0.2), v3(-1.9 + (i - 1) * 1.9, 3.0, -6.3), color, M.Fabric)
		end
	end,

	-- Kürk Toplama Merkezi: koyu yeşil kütük depo, kürk balyaları ve odun yığını
	yak_center = function(model, base)
		depot(model, base, {
			wall = rgb(60, 85, 60),
			wallMat = M.WoodPlanks,
			roof = rgb(55, 45, 40),
			roofMat = M.Slate,
			door = rgb(80, 60, 40),
			glass = rgb(200, 220, 240),
		})
		local fur = rgb(110, 75, 50)
		local rope = rgb(190, 160, 100)
		for _, p in { v3(5.8, 0.7, -1.2), v3(5.8, 0.7, 0.6), v3(5.8, 2.1, -0.3) } do
			put(model, base, "FurBale", v3(2.2, 1.4, 1.6), p, fur, M.Fabric)
			put(model, base, "BaleRope", v3(2.3, 0.2, 1.7), p, rope, M.Fabric)
		end
		cyl(model, base, "Log", 1, 2.4, v3(-5.9, 0.5, -0.9), rgb(120, 85, 55), M.Wood, "Z")
		cyl(model, base, "Log", 1, 2.4, v3(-5.9, 0.5, 0.3), rgb(110, 75, 50), M.Wood, "Z")
		cyl(model, base, "Log", 1, 2.4, v3(-5.9, 1.35, -0.3), rgb(125, 90, 58), M.Wood, "Z")
	end,

	-- Oymacı Kulübesi: kütük kulübe, yosun yeşili çatı, çatıda geyik boynuzu
	deer_lodge = function(model, base)
		shell(model, base, {
			wall = rgb(115, 80, 50),
			wallMat = M.WoodPlanks,
			roof = rgb(65, 100, 70),
			roofMat = M.Slate,
			door = rgb(80, 55, 35),
			glass = rgb(255, 215, 140),
			trim = rgb(55, 80, 55),
			gable = true,
		})
		local bone = rgb(225, 210, 175)
		put(model, base, "Plaque", v3(2.2, 1.6, 0.4), v3(0, 9.3, -0.2), rgb(95, 65, 40), M.Wood)
		for _, s in { -1, 1 } do
			put(
				model,
				base,
				"Antler",
				v3(0.35, 3.4, 0.35),
				v3(s * 1.5, 11.6, -0.2),
				bone,
				M.SmoothPlastic,
				v3(0, 0, -s * 28)
			)
			put(
				model,
				base,
				"Antler",
				v3(0.3, 1.5, 0.3),
				v3(s * 1.1, 11.9, -0.2),
				bone,
				M.SmoothPlastic,
				v3(0, 0, s * 10)
			)
			put(
				model,
				base,
				"Antler",
				v3(0.3, 1.7, 0.3),
				v3(s * 2.6, 12.5, -0.2),
				bone,
				M.SmoothPlastic,
				v3(0, 0, -s * 10)
			)
		end
		put(model, base, "Chimney", v3(1.4, 3.2, 1.4), v3(3.4, 8.3, 1.8), rgb(140, 75, 55), M.Brick)
		cyl(model, base, "Log", 1, 2.4, v3(-5.9, 0.5, -0.9), rgb(120, 85, 55), M.Wood, "Z")
		cyl(model, base, "Log", 1, 2.4, v3(-5.9, 0.5, 0.3), rgb(110, 75, 50), M.Wood, "Z")
		cyl(model, base, "Log", 1, 2.4, v3(-5.9, 1.35, -0.3), rgb(125, 90, 58), M.Wood, "Z")
	end,

	-- Boynuz Deposu: taş depo, parlayan ocak, yan tarafta boynuz askısı
	deer_forge = function(model, base)
		depot(model, base, {
			wall = rgb(125, 115, 105),
			wallMat = M.Cobblestone,
			roof = rgb(80, 60, 50),
			roofMat = M.Slate,
			door = rgb(75, 55, 40),
			glass = rgb(255, 200, 130),
		})
		put(model, base, "Chimney", v3(1.6, 4, 1.6), v3(-3, 6.3, 1.2), rgb(95, 85, 80), M.Brick)
		put(model, base, "ForgeGlow", v3(1.8, 1.3, 0.3), v3(-0.3, 1.2, -3.3), rgb(255, 120, 30), M.Neon)
		for _, z in { -2, 2 } do
			put(model, base, "RackPost", v3(0.35, 4, 0.35), v3(5.3, 2, z), rgb(85, 60, 40), M.Wood)
		end
		put(model, base, "RackBeam", v3(0.35, 0.35, 4.4), v3(5.3, 3.8, 0), rgb(85, 60, 40), M.Wood)
		local bone = rgb(225, 210, 175)
		for _, z in { -1.5, -0.5, 0.5, 1.5 } do
			put(model, base, "Antler", v3(0.3, 1.8, 0.3), v3(5.3, 2.8, z), bone, M.SmoothPlastic)
			put(model, base, "Antler", v3(0.25, 1, 0.25), v3(5.3, 3.0, z), bone, M.SmoothPlastic, v3(0, 0, 30))
		end
		crate(model, base, v3(-5.8, 0.8, -1), v3(1.8, 1.6, 1.8), rgb(110, 85, 60))
		crate(model, base, v3(-5.8, 0.8, 1), v3(1.8, 1.6, 1.8), rgb(95, 75, 55))
	end,

	-- Şahin Kalesi: kaya kale, yuvarlak kuleler, mazgal dişleri, tepede kanat açmış şahin
	falcon_perch = function(model, base)
		put(model, base, "Building", v3(10, 6.4, 8), v3(0, 3.2, 0), rgb(110, 115, 120), M.Cobblestone)
		for i = 1, 5 do
			put(model, base, "Merlon", v3(1.2, 1, 1), v3(-4 + (i - 1) * 2, 6.9, -3.6), rgb(95, 100, 105), M.Cobblestone)
		end
		put(model, base, "Roof", v3(10, 0.5, 8), v3(0, 6.65, 0.2), rgb(80, 85, 90), M.Slate)
		put(model, base, "Door", v3(2.8, 4.2, 0.3), v3(0, 2.1, -4.1), rgb(70, 50, 35), M.Wood)
		for _, x in { -3.2, 3.2 } do
			windowAt(model, base, v3(x, 4, -4.05), v3(0.9, 1.8, 0.2), rgb(255, 205, 130))
			cyl(model, base, "Tower", 3.2, 8.2, v3(x * 1.7, 4.1, -3.4), rgb(100, 105, 110), M.Cobblestone, "Y")
			cyl(model, base, "TowerCap", 3.6, 0.8, v3(x * 1.7, 8.6, -3.4), rgb(70, 75, 80), M.Slate, "Y")
			cyl(model, base, "TowerSpire", 1.2, 1.6, v3(x * 1.7, 9.8, -3.4), rgb(70, 75, 80), M.Slate, "Y")
		end
		local feather = rgb(120, 85, 50)
		put(model, base, "FalconPole", v3(0.4, 2.4, 0.4), v3(0, 8.4, 0), rgb(90, 65, 45), M.Wood)
		blob(model, base, "FalconBody", v3(1.4, 1.4, 2.4), v3(0, 10.2, 0), feather, M.Fabric)
		blob(model, base, "FalconHead", v3(1, 1, 1), v3(0, 11.2, -1.1), rgb(235, 225, 205), M.Fabric)
		for _, s in { -1, 1 } do
			put(
				model,
				base,
				"FalconWing",
				v3(3.2, 0.4, 1.6),
				v3(s * 2.2, 10.7, 0.2),
				feather,
				M.Fabric,
				v3(0, 0, -s * 20)
			)
		end
	end,

	-- Ödül Salonu: taş salon, altın şerit, yanda üç kademeli podyum ve kupa
	falcon_hall = function(model, base)
		depot(model, base, {
			wall = rgb(100, 105, 115),
			wallMat = M.Cobblestone,
			roof = rgb(60, 65, 80),
			roofMat = M.Slate,
			door = rgb(80, 60, 45),
			glass = rgb(210, 225, 245),
		})
		put(model, base, "GoldBand", v3(9.2, 0.4, 6.6), v3(0, 4.3, 0), GOLD, M.Metal)
		put(model, base, "PodiumBronze", v3(1.8, 1.1, 1.8), v3(5.6, 0.55, -2), rgb(190, 120, 60), M.Metal)
		put(model, base, "PodiumGold", v3(1.8, 2.2, 1.8), v3(5.6, 1.1, 0), GOLD, M.Metal)
		put(model, base, "PodiumSilver", v3(1.8, 1.6, 1.8), v3(5.6, 0.8, 2), rgb(200, 205, 210), M.Metal)
		cyl(model, base, "CupStem", 0.4, 0.8, v3(5.6, 2.6, 0), GOLD, M.Metal, "Y")
		cyl(model, base, "CupBowl", 1.3, 0.9, v3(5.6, 3.4, 0), GOLD, M.Metal, "Y")
		local feather = rgb(120, 85, 50)
		blob(model, base, "FalconBody", v3(1.4, 1.4, 2.2), v3(-3, 5.7, 0), feather, M.Fabric)
		blob(model, base, "FalconHead", v3(0.9, 0.9, 0.9), v3(-3, 6.6, -1), rgb(235, 225, 205), M.Fabric)
		for _, s in { -1, 1 } do
			put(
				model,
				base,
				"FalconWing",
				v3(1.4, 0.3, 1.4),
				v3(-3 + s * 1.2, 6, 0.1),
				feather,
				M.Fabric,
				v3(0, 0, -s * 15)
			)
		end
	end,

	-- ===== Çiftlik 6: Meyve Bahçesi (canlı renkler) =====

	-- Fındık Fabrikası: sıcak kahve ambar, çatıda dev fındık, huni
	squirrel_packer = function(model, base)
		shell(model, base, {
			wall = rgb(150, 100, 60),
			wallMat = M.WoodPlanks,
			roof = rgb(110, 65, 45),
			roofMat = M.WoodPlanks,
			door = rgb(235, 215, 170),
			glass = rgb(255, 215, 150),
			trim = rgb(235, 215, 170),
			gable = true,
		})
		blob(model, base, "Hazelnut", v3(3.6, 4, 3.6), v3(0, 10.3, -0.5), rgb(195, 135, 70), M.SmoothPlastic)
		blob(model, base, "HazelnutCap", v3(4.1, 2, 4.1), v3(0, 11.7, -0.5), rgb(105, 65, 40), M.Wood)
		put(model, base, "HazelnutStem", v3(0.4, 0.8, 0.4), v3(0, 12.9, -0.5), rgb(80, 50, 30), M.Wood)
		put(model, base, "Chimney", v3(1.4, 3, 1.4), v3(-3.6, 8.2, 1.6), rgb(140, 75, 55), M.Brick)
		cyl(model, base, "Hopper", 3, 1.2, v3(6, 3.4, 0), rgb(120, 120, 125), M.Metal, "Y")
		cyl(model, base, "HopperNeck", 1.2, 2.4, v3(6, 1.2, 0), rgb(120, 120, 125), M.Metal, "Y")
	end,

	-- Fındık Deposu: kütük silo (ağaç gövdesi), çuvallar
	squirrel_center = function(model, base)
		depot(model, base, {
			wall = rgb(160, 110, 70),
			wallMat = M.WoodPlanks,
			roof = rgb(100, 65, 45),
			roofMat = M.Slate,
			door = rgb(95, 65, 40),
			glass = rgb(255, 215, 150),
		})
		cyl(model, base, "TrunkSilo", 3, 5.5, v3(5.8, 2.75, 0), rgb(115, 80, 50), M.Wood, "Y")
		put(model, base, "TrunkHole", v3(1.1, 1.5, 0.3), v3(5.8, 3.4, -1.45), rgb(35, 25, 20), M.SmoothPlastic)
		blob(model, base, "TrunkCap", v3(3.6, 1.8, 3.6), v3(5.8, 5.8, 0), rgb(75, 130, 65), M.Grass)
		local sack = rgb(205, 170, 115)
		local spots =
			{ v3(-5.5, 1.1, -1.4), v3(-5.5, 1.1, 0.4), v3(-5.5, 1.1, 2), v3(-5.5, 2.9, -0.5), v3(-5.5, 2.9, 1.2) }
		for _, p in spots do
			blob(model, base, "NutSack", v3(2, 2.2, 1.6), p, sack, M.Fabric)
		end
	end,

	-- Posta Kulesi: taş posta evi, tünekli güvercin kulesi, çatıda zarf
	pigeon_loft = function(model, base)
		put(model, base, "Building", v3(10, 4, 8), v3(0, 2, 0), rgb(170, 180, 195), M.Concrete)
		put(model, base, "Roof", v3(10.6, 0.6, 8.6), v3(0, 4.3, 0), rgb(70, 85, 110), M.Slate)
		put(model, base, "Door", v3(2.4, 3.2, 0.3), v3(1, 1.6, -4.1), rgb(150, 50, 45), M.Wood)
		windowAt(model, base, v3(4, 2.6, -4.05), v3(1.4, 1.4, 0.2), rgb(190, 220, 245))
		windowAt(model, base, v3(-4, 2.6, -4.05), v3(1.4, 1.4, 0.2), rgb(190, 220, 245))
		put(model, base, "Tower", v3(4, 11, 4), v3(-3, 5.5, 0.5), rgb(190, 195, 205), M.Brick)
		for _, x in { -4, -2 } do
			for _, y in { 6.5, 8, 9.5 } do
				put(model, base, "Pigeonhole", v3(0.9, 0.9, 0.3), v3(x, y, -1.6), rgb(40, 40, 50), M.SmoothPlastic)
			end
		end
		for _, y in { 5.9, 7.4, 8.9 } do
			put(model, base, "Perch", v3(3.6, 0.2, 0.5), v3(-3, y, -2), rgb(110, 80, 55), M.Wood)
		end
		put(model, base, "TowerRoof", v3(4.8, 0.5, 4.8), v3(-3, 11.2, 0.5), rgb(70, 85, 110), M.Slate)
		put(model, base, "TowerRoof", v3(3.4, 0.8, 3.4), v3(-3, 11.8, 0.5), rgb(70, 85, 110), M.Slate)
		put(model, base, "TowerRoof", v3(1.8, 0.9, 1.8), v3(-3, 12.6, 0.5), rgb(60, 75, 100), M.Slate)
		makeBall(model, "Finial", 0.8, base * CFrame.new(-3, 13.4, 0.5), GOLD, M.Metal)
		put(model, base, "Envelope", v3(3, 2, 0.4), v3(3, 5.6, -3), rgb(240, 235, 215), M.SmoothPlastic)
		put(model, base, "EnvelopeSeal", v3(3, 0.4, 0.45), v3(3, 6.4, -3), rgb(200, 50, 50), M.SmoothPlastic)
	end,

	-- Posta Ofisi: depo, kırmızı posta kutuları, direkte güvercin kümesi, mektup kasaları
	pigeon_office = function(model, base)
		depot(model, base, {
			wall = rgb(200, 205, 215),
			wallMat = M.Brick,
			roof = rgb(80, 95, 120),
			roofMat = M.Slate,
			door = rgb(150, 50, 45),
			glass = rgb(190, 220, 245),
		})
		for _, z in { -1.2, 1 } do
			put(model, base, "MailBox", v3(1.4, 2, 1.2), v3(5.6, 1, z), rgb(195, 45, 45), M.Metal)
			cyl(model, base, "MailBoxTop", 1.4, 1.2, v3(5.6, 2, z), rgb(195, 45, 45), M.Metal, "Z")
		end
		cyl(model, base, "DovePole", 0.5, 4.5, v3(-5.6, 2.25, 0), rgb(110, 80, 55), M.Wood, "Y")
		put(model, base, "Dovecote", v3(1.8, 1.6, 1.8), v3(-5.6, 5.1, 0), rgb(225, 215, 190), M.WoodPlanks)
		put(model, base, "DovecoteRoof", v3(2.4, 0.4, 2.4), v3(-5.6, 6.1, 0), rgb(120, 70, 60), M.Wood)
		put(model, base, "DovecoteHole", v3(0.6, 0.6, 0.2), v3(-5.6, 5.2, -0.95), rgb(40, 35, 35), M.SmoothPlastic)
		for i = 1, 3 do
			local y = 0.35 + (i - 1) * 0.7
			put(
				model,
				base,
				"Letters",
				v3(2, 0.7, 1.4),
				v3(-5.6 + (i - 2) * 0.2, y, 2.6),
				rgb(245, 240, 225),
				M.SmoothPlastic
			)
		end
	end,

	-- Salyangoz Bistrosu: nemli taş bistro, yosunlu çatı, çatıda kabuk amblemi, dışarıda masalar
	snail_bistro = function(model, base)
		shell(model, base, {
			wall = rgb(110, 118, 108),
			wallMat = M.Cobblestone,
			roof = rgb(60, 100, 65),
			roofMat = M.Grass,
			door = rgb(80, 50, 40),
			glass = rgb(255, 220, 150),
			trim = rgb(95, 80, 60),
			gable = true,
		})
		put(model, base, "Awning", v3(4, 0.3, 1.8), v3(0, 4.9, -4.9), rgb(190, 60, 60), M.Fabric, v3(-12, 0, 0))
		cyl(model, base, "ShellOuter", 4.2, 0.6, v3(0, 10.2, -0.5), rgb(215, 150, 70), M.SmoothPlastic, "Z")
		cyl(model, base, "ShellMid", 3, 0.7, v3(0, 10.2, -0.85), rgb(150, 95, 45), M.SmoothPlastic, "Z")
		cyl(model, base, "ShellCore", 1.8, 0.8, v3(0, 10.2, -1.2), rgb(225, 175, 105), M.SmoothPlastic, "Z")
		put(model, base, "Chimney", v3(1.4, 3, 1.4), v3(-3.4, 8, 1.5), rgb(100, 105, 100), M.Cobblestone)
		for _, x in { -6.4, 6.4 } do
			cyl(model, base, "TableLeg", 0.4, 1.3, v3(x, 0.65, -3), rgb(80, 60, 45), M.Wood, "Y")
			cyl(model, base, "TableTop", 1.8, 0.2, v3(x, 1.4, -3), rgb(235, 225, 205), M.Wood, "Y")
		end
	end,

	-- Kaviyar Mahzeni: toprağa gömülü koyu taş mahzen, çimenli tepe, varil ve kavanozlar
	snail_cellar = function(model, base)
		depot(model, base, {
			wall = rgb(62, 72, 88),
			wallMat = M.Slate,
			roof = rgb(70, 120, 70),
			roofMat = M.Grass,
			door = rgb(70, 50, 40),
			glass = rgb(150, 220, 230),
		})
		put(model, base, "Lintel", v3(3.4, 0.5, 0.5), v3(1.6, 3.4, -3.35), rgb(95, 105, 120), M.Cobblestone)
		cyl(model, base, "Barrel", 2, 2.2, v3(5.6, 1, -1.2), rgb(95, 65, 45), M.Wood, "Z")
		cyl(model, base, "Barrel", 2, 2.2, v3(5.6, 1, 1.2), rgb(95, 65, 45), M.Wood, "Z")
		cyl(model, base, "Barrel", 2, 2.2, v3(5.6, 2.7, 0), rgb(110, 75, 50), M.Wood, "Z")
		put(model, base, "Shelf", v3(2.6, 1, 1.4), v3(-5.7, 0.5, -1), rgb(75, 60, 50), M.Wood)
		for _, z in { -1.4, -0.6 } do
			cyl(model, base, "CaviarJar", 0.7, 0.9, v3(-5.7, 1.45, z), rgb(25, 30, 50), M.Glass, "Y")
			cyl(model, base, "JarLid", 0.8, 0.2, v3(-5.7, 2, z), GOLD, M.Metal, "Y")
		end
	end,

	-- Dokuma Tezgâhı: pişmiş kil yapı, renkli şeritler, çatıda lama silueti, yanda dokuma çerçevesi
	llama_loom = function(model, base)
		shell(model, base, {
			wall = rgb(200, 105, 70),
			wallMat = M.Concrete,
			roof = rgb(215, 185, 110),
			roofMat = M.WoodPlanks,
			door = rgb(95, 60, 40),
			glass = rgb(255, 225, 150),
			trim = rgb(190, 45, 50),
			gable = true,
		})
		put(model, base, "Stripe", v3(9.8, 0.4, 0.15), v3(0, 5.5, -4.05), rgb(240, 190, 50), M.SmoothPlastic)
		put(model, base, "Stripe", v3(9.8, 0.4, 0.15), v3(0, 5.0, -4.05), rgb(30, 150, 150), M.SmoothPlastic)
		local fur = rgb(240, 225, 200)
		put(model, base, "LlamaBody", v3(2.4, 1.8, 3.6), v3(0, 9.4, 0.3), fur, M.Fabric)
		put(model, base, "LlamaNeck", v3(1, 3.2, 1), v3(0, 11, -1.2), fur, M.Fabric)
		put(model, base, "LlamaHead", v3(1, 1, 1.9), v3(0, 12.8, -1.7), fur, M.Fabric)
		put(model, base, "LlamaEar", v3(0.3, 0.9, 0.3), v3(-0.3, 13.6, -1.1), fur, M.Fabric)
		put(model, base, "LlamaEar", v3(0.3, 0.9, 0.3), v3(0.3, 13.6, -1.1), fur, M.Fabric)
		-- Yan dokuma çerçevesi
		for _, x in { 5.9, 8.1 } do
			put(model, base, "LoomPost", v3(0.4, 5.4, 0.4), v3(x, 2.7, -1), rgb(95, 65, 40), M.Wood)
		end
		put(model, base, "LoomBeam", v3(2.6, 0.4, 0.4), v3(7, 5.2, -1), rgb(95, 65, 40), M.Wood)
		local threads = { rgb(190, 45, 50), rgb(240, 190, 50), rgb(30, 150, 150), rgb(120, 60, 150), rgb(60, 130, 60) }
		for i, color in threads do
			put(model, base, "Thread", v3(0.2, 4.2, 0.15), v3(6.2 + (i - 1) * 0.4, 2.9, -1), color, M.Fabric)
		end
		put(model, base, "Weft", v3(2, 0.5, 0.2), v3(7, 2, -1.05), rgb(190, 45, 50), M.Fabric)
		put(model, base, "Weft", v3(2, 0.5, 0.2), v3(7, 3, -1.05), rgb(30, 150, 150), M.Fabric)
	end,

	-- Kumaş Atölyesi: kerpiç depo, renkli kumaş balyaları, iki boya kazanı
	llama_workshop = function(model, base)
		depot(model, base, {
			wall = rgb(238, 220, 190),
			wallMat = M.Concrete,
			roof = rgb(190, 90, 60),
			roofMat = M.Slate,
			door = rgb(95, 60, 40),
			glass = rgb(255, 225, 150),
		})
		put(model, base, "RedBand", v3(9.2, 0.5, 6.6), v3(0, 4.1, 0), rgb(190, 45, 50), M.SmoothPlastic)
		cyl(model, base, "FabricBolt", 1.2, 2.4, v3(5.2, 0.6, 0), rgb(190, 45, 50), M.Fabric, "Z")
		cyl(model, base, "FabricBolt", 1.2, 2.4, v3(6.4, 0.6, 0), rgb(30, 150, 150), M.Fabric, "Z")
		cyl(model, base, "FabricBolt", 1.2, 2.4, v3(5.8, 1.7, 0), rgb(240, 190, 50), M.Fabric, "Z")
		cyl(model, base, "FabricBolt", 1.2, 2.4, v3(5.8, 2.9, 0), rgb(120, 60, 150), M.Fabric, "Z")
		cyl(model, base, "DyeVat", 2.2, 1.6, v3(-5.6, 0.8, -0.6), rgb(170, 100, 60), M.Wood, "Y")
		cyl(model, base, "Dye", 1.9, 0.1, v3(-5.6, 1.65, -0.6), rgb(190, 45, 50), M.SmoothPlastic, "Y")
		cyl(model, base, "DyeVat", 2.2, 1.6, v3(-5.6, 0.8, 1.8), rgb(170, 100, 60), M.Wood, "Y")
		cyl(model, base, "Dye", 1.9, 0.1, v3(-5.6, 1.65, 1.8), rgb(40, 100, 190), M.SmoothPlastic, "Y")
	end,

	-- İpek Değirmeni: dut yaprağı yeşili, çatıda koza kümesi ve yaprak süsleri, yanda ipek makarası
	silk_mill = function(model, base)
		shell(model, base, {
			wall = rgb(175, 210, 140),
			wallMat = M.Concrete,
			roof = rgb(95, 150, 80),
			roofMat = M.Slate,
			door = rgb(235, 235, 215),
			glass = rgb(210, 235, 200),
			trim = rgb(240, 240, 225),
			gable = true,
		})
		local cocoon = rgb(250, 248, 235)
		blob(model, base, "Cocoon", v3(2.6, 3.4, 2.6), v3(-1.6, 9.8, -0.4), cocoon, M.Fabric)
		blob(model, base, "Cocoon", v3(2.4, 3.2, 2.4), v3(1.5, 9.6, 0.3), cocoon, M.Fabric)
		blob(model, base, "Cocoon", v3(1.8, 2.4, 1.8), v3(0.1, 9, -2), cocoon, M.Fabric)
		for _, s in { -1, 1 } do
			put(
				model,
				base,
				"Leaf",
				v3(1.4, 2, 0.12),
				v3(s * 3.9, 5.2, -4.2),
				rgb(80, 150, 60),
				M.Grass,
				v3(0, 0, s * 20)
			)
		end
		cyl(model, base, "SilkReel", 4.6, 0.5, v3(5.6, 3.2, 0), rgb(240, 240, 225), M.SmoothPlastic, "X")
		cyl(model, base, "ReelHub", 1, 1, v3(5.6, 3.2, 0), GOLD, M.Metal, "X")
		put(model, base, "ReelSpoke", v3(0.3, 4.4, 0.3), v3(5.6, 3.2, 0), GOLD, M.Metal)
		put(model, base, "ReelSpoke", v3(0.3, 0.3, 4.4), v3(5.6, 3.2, 0), GOLD, M.Metal)
	end,

	-- Koza Sarayı: krem depo, koza dolu raflar, yaprak sepeti
	silk_loft = function(model, base)
		depot(model, base, {
			wall = rgb(240, 235, 210),
			wallMat = M.Concrete,
			roof = rgb(180, 200, 140),
			roofMat = M.Slate,
			door = rgb(150, 130, 90),
			glass = rgb(210, 235, 200),
		})
		for _, z in { -2.4, 2.4 } do
			for _, x in { 5.2, 6.4 } do
				put(model, base, "RackPost", v3(0.3, 4.4, 0.3), v3(x, 2.2, z), rgb(130, 95, 60), M.Wood)
			end
		end
		for _, y in { 1.2, 2.8 } do
			put(model, base, "Shelf", v3(1.6, 0.2, 5.2), v3(5.8, y, 0), rgb(150, 110, 70), M.WoodPlanks)
			for _, z in { -1.5, 0, 1.5 } do
				blob(model, base, "Cocoon", v3(1, 1.3, 1), v3(5.8, y + 0.75, z), rgb(250, 248, 235), M.Fabric)
			end
		end
		cyl(model, base, "LeafBasket", 1.8, 0.8, v3(-5.6, 0.4, 0.5), rgb(190, 150, 90), M.Wood, "Y")
		blob(model, base, "LeafPile", v3(1.7, 0.8, 1.7), v3(-5.6, 1, 0.5), rgb(90, 160, 65), M.Grass)
	end,

	-- Tropik Tiyatro: turkuaz tiyatro, kırmızı perdeler, flamalar, çatıda kırmızı papağan
	parrot_theatre = function(model, base)
		shell(model, base, {
			wall = rgb(35, 160, 160),
			wallMat = M.WoodPlanks,
			roof = rgb(215, 60, 60),
			roofMat = M.Slate,
			door = rgb(230, 180, 50),
			glass = rgb(255, 230, 120),
			trim = rgb(240, 200, 60),
			gable = true,
		})
		for _, x in { -1.95, 1.95 } do
			put(model, base, "Curtain", v3(1, 4.8, 0.3), v3(x, 2.4, -4.2), rgb(200, 30, 50), M.Fabric)
		end
		put(model, base, "BuntingLine", v3(9.6, 0.1, 0.1), v3(0, 5.6, -4.4), rgb(240, 235, 220), M.Fabric)
		local flags = { rgb(235, 60, 60), rgb(250, 200, 50), rgb(60, 170, 80), rgb(60, 110, 220), rgb(220, 90, 190) }
		for i = 0, 7 do
			put(
				model,
				base,
				"Bunting",
				v3(0.7, 0.9, 0.1),
				v3(-4.2 + i * 1.2, 5.1, -4.4),
				flags[i % #flags + 1],
				M.Fabric
			)
		end
		blob(model, base, "ParrotBody", v3(2.6, 3.2, 2.2), v3(0, 10.1, 0), rgb(215, 40, 50), M.SmoothPlastic)
		blob(model, base, "ParrotHead", v3(1.7, 1.7, 1.7), v3(0, 12.1, -0.9), rgb(240, 200, 40), M.SmoothPlastic)
		put(model, base, "ParrotBeak", v3(0.5, 0.8, 0.7), v3(0, 11.8, -1.9), rgb(40, 40, 40), M.SmoothPlastic)
		for _, s in { -1, 1 } do
			put(
				model,
				base,
				"ParrotWing",
				v3(0.4, 2.6, 1.6),
				v3(s * 1.4, 10.2, 0.2),
				rgb(40, 90, 200),
				M.SmoothPlastic,
				v3(0, 0, s * 10)
			)
		end
		put(
			model,
			base,
			"ParrotTail",
			v3(0.5, 2.8, 0.5),
			v3(-0.3, 8.9, 1.5),
			rgb(50, 170, 70),
			M.SmoothPlastic,
			v3(20, 0, 0)
		)
		put(
			model,
			base,
			"ParrotTail",
			v3(0.5, 2.8, 0.5),
			v3(0.4, 8.9, 1.5),
			rgb(250, 200, 50),
			M.SmoothPlastic,
			v3(20, 0, 0)
		)
	end,

	-- Bilet Gişesi: sarı kiosk, kırmızı-beyaz tente, bilet tabelası, tünekte küçük papağan, halat direkleri
	parrot_box = function(model, base)
		put(model, base, "Building", v3(6.4, 4.4, 5), v3(0, 2.2, 0), rgb(245, 200, 50), M.WoodPlanks)
		put(model, base, "Roof", v3(7, 0.5, 5.8), v3(0, 4.65, 0), rgb(40, 160, 110), M.Slate)
		windowAt(model, base, v3(0, 3, -2.55), v3(3.2, 1.6, 0.2), rgb(255, 230, 150))
		put(model, base, "Counter", v3(4, 0.3, 1), v3(0, 2.1, -3), rgb(130, 85, 55), M.Wood)
		for i = 0, 5 do
			local color = if i % 2 == 0 then rgb(215, 50, 50) else rgb(245, 240, 230)
			put(
				model,
				base,
				"Awning",
				v3(1.1, 0.2, 2.2),
				v3(-2.75 + i * 1.1, 4.6, -3.1),
				color,
				M.Fabric,
				v3(-20, 0, 0)
			)
		end
		put(model, base, "TicketSign", v3(3, 1.3, 0.2), v3(0, 5.9, -2.2), rgb(245, 235, 210), M.SmoothPlastic)
		put(model, base, "TicketStripe", v3(3, 0.3, 0.25), v3(0, 6.3, -2.2), rgb(215, 50, 50), M.SmoothPlastic)
		put(model, base, "SideDoor", v3(0.3, 3.2, 1.8), v3(3.25, 1.6, 0.5), rgb(130, 85, 55), M.Wood)
		blob(model, base, "ParrotBody", v3(1.2, 1.5, 1), v3(2.4, 5.8, 0), rgb(215, 40, 50), M.SmoothPlastic)
		blob(model, base, "ParrotHead", v3(0.8, 0.8, 0.8), v3(2.4, 6.7, -0.35), rgb(240, 200, 40), M.SmoothPlastic)
		put(model, base, "ParrotBeak", v3(0.25, 0.3, 0.35), v3(2.4, 6.6, -0.85), rgb(40, 40, 40), M.SmoothPlastic)
		for _, x in { -2.5, 2.5 } do
			put(model, base, "RopePost", v3(0.3, 1.6, 0.3), v3(x, 0.8, -5.5), GOLD, M.Metal)
		end
		put(model, base, "Rope", v3(5, 0.12, 0.12), v3(0, 1.4, -5.5), rgb(190, 40, 50), M.Fabric)
	end,

	-- Kabuk Atölyesi: yarım kabuk kubbe atölye, kabuk plakaları ve kaplumbağa ayakları
	tortoise_workshop = function(model, base)
		blob(model, base, "Building", v3(10.5, 6.4, 8.6), v3(0, 3.2, 0), rgb(95, 130, 70), M.Slate)
		local plate = rgb(110, 85, 50)
		put(model, base, "ShellPlate", v3(2.6, 0.3, 2.6), v3(0, 6.35, 0), plate, M.Slate)
		for _, s in { -1, 1 } do
			put(model, base, "ShellPlate", v3(2.2, 0.3, 2.6), v3(s * 2.8, 5.7, 0), plate, M.Slate, v3(0, 0, -s * 28))
			put(model, base, "ShellPlate", v3(2.6, 0.3, 2), v3(0, 5.7, s * 2.6), plate, M.Slate, v3(s * 28, 0, 0))
		end
		put(model, base, "Door", v3(2.6, 3.4, 0.3), v3(0, 1.9, -4.1), rgb(75, 50, 35), M.Wood)
		for _, x in { -2.4, 2.4 } do
			windowAt(model, base, v3(x, 4.2, -3.75), v3(1.5, 1.4, 0.3), rgb(255, 215, 140))
		end
		for _, x in { -4, 4 } do
			for _, z in { -3, 3 } do
				put(model, base, "TortoiseLeg", v3(2, 1.4, 2), v3(x, 0.7, z), rgb(120, 140, 80), M.Fabric)
			end
		end
	end,

	-- Kabuk Kasası: çelik kasa depo, altın kasa kapağı, kubbe, yanda kabuk yığını
	tortoise_vault = function(model, base)
		depot(model, base, {
			wall = rgb(80, 85, 95),
			wallMat = M.Metal,
			roof = rgb(60, 65, 75),
			roofMat = M.Metal,
			door = rgb(55, 55, 60),
			glass = rgb(170, 200, 230),
		})
		blob(model, base, "VaultDome", v3(7, 3, 5.5), v3(0, 4.6, 0), rgb(100, 125, 70), M.Slate)
		cyl(model, base, "VaultRing", 3.4, 0.3, v3(1.6, 2, -3.4), rgb(120, 125, 135), M.Metal, "Z")
		cyl(model, base, "VaultDoor", 3, 0.5, v3(1.6, 2, -3.55), rgb(200, 160, 60), M.Metal, "Z")
		put(model, base, "VaultHandle", v3(2, 0.25, 0.3), v3(1.6, 2, -3.95), METAL, M.Metal)
		put(model, base, "VaultHandle", v3(0.25, 2, 0.3), v3(1.6, 2, -3.95), METAL, M.Metal)
		local shellColor = rgb(110, 130, 70)
		local plate = rgb(95, 75, 45)
		blob(model, base, "Shell", v3(2.6, 1.5, 2.4), v3(-5.8, 0.75, -0.8), shellColor, M.Slate)
		blob(model, base, "Shell", v3(2.6, 1.5, 2.4), v3(-5.8, 0.75, 1.4), shellColor, M.Slate)
		blob(model, base, "Shell", v3(2.4, 1.4, 2.2), v3(-5.8, 2.0, 0.3), shellColor, M.Slate)
		put(model, base, "ShellPlate", v3(1.2, 0.2, 1.2), v3(-5.8, 1.5, -0.8), plate, M.Slate)
		put(model, base, "ShellPlate", v3(1.2, 0.2, 1.2), v3(-5.8, 1.5, 1.4), plate, M.Slate)
		put(model, base, "ShellPlate", v3(1.1, 0.2, 1.1), v3(-5.8, 2.7, 0.3), plate, M.Slate)
	end,
}

return builders
