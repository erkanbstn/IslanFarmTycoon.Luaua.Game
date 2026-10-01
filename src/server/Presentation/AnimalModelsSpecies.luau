--!strict
-- Hayvan türü tablosundaki (Config/Species.luau) hayvanların kod modelleri: tür kimliği -> kurucu.
-- Her kurucu `function(model, s)`: s = evre ölçeği; model -Z yönüne (başı) bakar, zemin y = 0, model.PrimaryPart ayarlanır.
-- Kaydı olmayan tür AnimalModels'te inek modeline düşer.
-- Ölçüler/ofsetler s'siz yazılır; yardımcılar s ile çarpar. Ofsetler gövde merkezine göredir.
-- AnimalModels bu dosyayı require eder; geri require yapma (block/eye bu yüzden burada kopyadır).

local builders: { [string]: (Model, number) -> () } = {}

local function block(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Anchored = true
	p.CanTouch = false
	p.CanCollide = false
	p.CanQuery = false
	p.Material = Enum.Material.Fabric -- mat yüzey: Future ışıkta tüyler parlamasın
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Parlak top göz + küçük ışık yansıması (AnimalModels.eye ile aynı).
local function eye(model: Model, cframe: CFrame, diameter: number, color: Color3?)
	local ball = block(model, "Eye", Vector3.one * diameter, cframe, color or Color3.fromRGB(20, 20, 25))
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.SmoothPlastic
	local glint = block(
		model,
		"EyeGlint",
		Vector3.one * diameter * 0.32,
		cframe * CFrame.new(diameter * 0.18, diameter * 0.22, -diameter * 0.36),
		Color3.fromRGB(255, 255, 255)
	)
	glint.Shape = Enum.PartType.Ball
	glint.Material = Enum.Material.SmoothPlastic
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local SIDES = { -1, 1 }
local BLACK = rgb(25, 22, 22)

-- Gövdeye göre ofsetle (s ile çarpılır) Part koyar.
local function part(model: Model, body: Part, s: number, name: string, size: Vector3, off: Vector3, color: Color3): Part
	return block(model, name, size * s, body.CFrame * CFrame.new(off * s), color)
end

-- Aynısı, ama ofset tam CFrame (döndürme dahil); konum s ile çarpılır, dönüş aynen kalır.
local function partR(model: Model, body: Part, s: number, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	return block(model, name, size * s, body.CFrame * (CFrame.new(cf.Position * s) * cf.Rotation), color)
end

local function ball(model: Model, body: Part, s: number, name: string, d: number, off: Vector3, color: Color3): Part
	local p = part(model, body, s, name, Vector3.one * d, off, color)
	p.Shape = Enum.PartType.Ball
	return p
end

-- Gövde Part'ı (PrimaryPart): merkez yüksekliği zemine göre; s ile çarpılır.
local function makeBody(model: Model, s: number, size: Vector3, centerY: number, color: Color3): Part
	local body = block(model, "Body", size * s, CFrame.new(0, centerY * s, 0), color)
	model.PrimaryPart = body
	return body
end

-- Dört bacaklı iskelet: gövde + 4 bacak (zemine oturur).
local function quad(
	model: Model,
	s: number,
	size: Vector3,
	legH: number,
	legW: number,
	bodyColor: Color3,
	legColor: Color3
): Part
	local body = makeBody(model, s, size, legH + size.Y / 2, bodyColor)
	for _, sx in SIDES do
		for _, sz in SIDES do
			part(
				model,
				body,
				s,
				"Leg",
				Vector3.new(legW, legH + 0.1, legW),
				Vector3.new(
					sx * (size.X / 2 - legW / 2 - 0.05),
					-size.Y / 2 - legH / 2 + 0.05,
					sz * (size.Z / 2 - legW / 2 - 0.1)
				),
				legColor
			)
		end
	end
	return body
end

-- Kuş bacakları (iki ince direk).
local function birdLegs(
	model: Model,
	body: Part,
	s: number,
	bodyH: number,
	legH: number,
	x: number,
	z: number,
	color: Color3
)
	for _, sx in SIDES do
		part(
			model,
			body,
			s,
			"Leg",
			Vector3.new(0.2, legH + 0.1, 0.2),
			Vector3.new(sx * x, -bodyH / 2 - legH / 2 + 0.05, z),
			color
		)
	end
end

-- İki yanda küçük top gözler (parlama yok; parça tasarrufu).
local function dotEyes(model: Model, body: Part, s: number, x: number, y: number, z: number, d: number, color: Color3?)
	for _, sx in SIDES do
		local e = ball(model, body, s, "Eye", d, Vector3.new(sx * x, y, z), color or BLACK)
		e.Material = Enum.Material.SmoothPlastic
	end
end

-- Parlamalı göz çifti.
local function eyePair(model: Model, body: Part, s: number, x: number, y: number, z: number, d: number, color: Color3?)
	for _, sx in SIDES do
		eye(model, body.CFrame * CFrame.new(sx * x * s, y * s, z * s), d * s, color)
	end
end

-- Yelpaze: tabandan (base) açılan `count` tüy; spot verilirse tek sıradaki tüylerin ucuna göz lekesi koyar.
local function fan(
	model: Model,
	body: Part,
	s: number,
	base: CFrame,
	count: number,
	spread: number,
	length: number,
	width: number,
	colors: { Color3 },
	spot: Color3?
)
	for i = 1, count do
		local t = if count > 1 then (i - 1) / (count - 1) * 2 - 1 else 0
		local rot = base * CFrame.Angles(0, 0, t * spread)
		partR(
			model,
			body,
			s,
			"Feather",
			Vector3.new(width, length, 0.12),
			rot * CFrame.new(0, length / 2, 0),
			colors[(i - 1) % #colors + 1]
		)
		if spot and i % 2 == 1 then
			local sp = partR(
				model,
				body,
				s,
				"Eyespot",
				Vector3.new(width * 0.7, width * 0.9, 0.16),
				rot * CFrame.new(0, length - width * 0.7, -0.01),
				spot
			)
			sp.Material = Enum.Material.SmoothPlastic
		end
	end
end

-- Tavşan: uzun kulaklar, tombul kuyruk topu.
builders.rabbit = function(model: Model, s: number)
	local fur = rgb(205, 190, 168)
	local white = rgb(246, 243, 238)
	local pink = rgb(238, 160, 172)
	local body = quad(model, s, Vector3.new(1.3, 1.2, 1.9), 0.35, 0.3, fur, fur)
	for _, sx in SIDES do
		part(model, body, s, "Haunch", Vector3.new(0.5, 0.9, 1.0), Vector3.new(sx * 0.62, -0.05, 0.6), fur)
		local base = CFrame.new(sx * 0.25, 0.95, -1.15) * CFrame.Angles(-0.15, 0, -sx * 0.2)
		partR(model, body, s, "Ear", Vector3.new(0.28, 1.3, 0.14), base * CFrame.new(0, 0.65, 0), fur)
		partR(model, body, s, "EarInner", Vector3.new(0.16, 1.0, 0.05), base * CFrame.new(0, 0.62, -0.08), pink)
	end
	local head = part(model, body, s, "Head", Vector3.new(0.95, 0.85, 0.95), Vector3.new(0, 0.5, -1.2), fur)
	part(model, body, s, "Muzzle", Vector3.new(0.6, 0.4, 0.3), Vector3.new(0, 0.38, -1.7), white)
	ball(model, body, s, "Nose", 0.2, Vector3.new(0, 0.48, -1.88), pink)
	ball(model, body, s, "Tail", 0.6, Vector3.new(0, 0.1, 1.15), white)
	eyePair(model, head, s, 0.4, 0.12, -0.46, 0.22)
end

-- Hindi: yelpaze gibi açılan kuyruk, kırmızı gerdan.
builders.turkey = function(model: Model, s: number)
	local brown = rgb(110, 70, 40)
	local tan = rgb(195, 150, 90)
	local red = rgb(205, 40, 50)
	local body = makeBody(model, s, Vector3.new(1.7, 1.5, 2.6), 1.0 + 0.75, brown)
	birdLegs(model, body, s, 1.5, 1.0, 0.4, 0.1, rgb(190, 110, 90))
	part(model, body, s, "Breast", Vector3.new(1.5, 1.3, 0.6), Vector3.new(0, 0.1, -1.3), tan)
	part(model, body, s, "Neck", Vector3.new(0.5, 1.3, 0.5), Vector3.new(0, 1.0, -1.2), red)
	local head =
		part(model, body, s, "Head", Vector3.new(0.55, 0.55, 0.65), Vector3.new(0, 1.8, -1.4), rgb(120, 160, 200))
	part(model, body, s, "Beak", Vector3.new(0.2, 0.18, 0.3), Vector3.new(0, 1.7, -1.85), rgb(220, 190, 80))
	part(model, body, s, "Wattle", Vector3.new(0.2, 0.55, 0.2), Vector3.new(0, 1.3, -1.75), red)
	for _, sx in SIDES do
		part(model, body, s, "Wing", Vector3.new(0.2, 1.0, 1.7), Vector3.new(sx * 0.95, 0.1, 0.1), rgb(85, 52, 30))
	end
	fan(model, body, s, CFrame.new(0, 0.5, 1.2) * CFrame.Angles(0.25, 0, 0), 7, 1.2, 2.0, 0.7, { brown, tan }, nil)
	dotEyes(model, head, s, 0.3, 0.1, -0.25, 0.14)
end

-- Arı: sarı-siyah çizgili, saydam kanatlı.
builders.bee = function(model: Model, s: number)
	local yellow = rgb(242, 192, 32)
	local body = makeBody(model, s, Vector3.new(1.2, 1.1, 1.1), 0.35 + 0.55, yellow)
	for _, sx in SIDES do
		for _, sz in SIDES do
			part(model, body, s, "Leg", Vector3.new(0.12, 0.5, 0.12), Vector3.new(sx * 0.4, -0.8, sz * 0.25), BLACK)
		end
		local base = CFrame.new(sx * 0.2, 0.35, -1.2) * CFrame.Angles(-0.7, 0, -sx * 0.2)
		partR(model, body, s, "Antenna", Vector3.new(0.07, 0.6, 0.07), base * CFrame.new(0, 0.3, 0), BLACK)
		local wing = partR(
			model,
			body,
			s,
			"Wing",
			Vector3.new(1.2, 0.05, 0.7),
			CFrame.new(sx * 0.5, 0.55, 0.05) * CFrame.Angles(0, 0, sx * 0.5) * CFrame.new(sx * 0.6, 0, 0),
			rgb(210, 235, 255)
		)
		wing.Material = Enum.Material.SmoothPlastic
		wing.Transparency = 0.5
	end
	local head = ball(model, body, s, "Head", 0.85, Vector3.new(0, 0.1, -0.95), BLACK)
	part(model, body, s, "Abdomen1", Vector3.new(1.1, 1.0, 0.6), Vector3.new(0, -0.05, 0.85), BLACK)
	part(model, body, s, "Abdomen2", Vector3.new(1.05, 0.95, 0.6), Vector3.new(0, -0.1, 1.4), yellow)
	part(model, body, s, "Abdomen3", Vector3.new(0.9, 0.85, 0.55), Vector3.new(0, -0.15, 1.95), BLACK)
	part(model, body, s, "Abdomen4", Vector3.new(0.65, 0.6, 0.4), Vector3.new(0, -0.2, 2.4), yellow)
	part(model, body, s, "Stinger", Vector3.new(0.12, 0.12, 0.4), Vector3.new(0, -0.2, 2.78), BLACK)
	eyePair(model, head, s, 0.33, 0.15, -0.3, 0.2, rgb(120, 70, 20))
end

-- Deve: iki hörgüç, uzun boyun ve uzun bacaklar.
builders.camel = function(model: Model, s: number)
	local sand = rgb(198, 152, 92)
	local dark = rgb(125, 88, 52)
	local body = quad(model, s, Vector3.new(2.2, 2.2, 4.2), 2.4, 0.5, sand, rgb(172, 128, 78))
	part(model, body, s, "Hump1", Vector3.new(1.4, 1.2, 1.3), Vector3.new(0, 1.55, -0.8), sand)
	part(model, body, s, "Hump2", Vector3.new(1.4, 1.2, 1.3), Vector3.new(0, 1.55, 1.1), sand)
	local nb = CFrame.new(0, 0.8, -1.9) * CFrame.Angles(-0.4, 0, 0)
	partR(model, body, s, "Neck", Vector3.new(0.8, 2.4, 0.8), nb * CFrame.new(0, 1.2, 0), sand)
	local head = part(model, body, s, "Head", Vector3.new(0.9, 0.8, 1.4), Vector3.new(0, 3.1, -3.4), sand)
	part(model, body, s, "Muzzle", Vector3.new(0.7, 0.55, 0.5), Vector3.new(0, 2.95, -4.25), dark)
	for _, sx in SIDES do
		part(model, body, s, "Ear", Vector3.new(0.2, 0.4, 0.2), Vector3.new(sx * 0.4, 3.6, -3.0), dark)
	end
	part(model, body, s, "Tail", Vector3.new(0.25, 1.4, 0.25), Vector3.new(0, 0.3, 2.3), dark)
	eyePair(model, head, s, 0.42, 0.15, -0.45, 0.26)
end

-- Tavus kuşu: mavi-yeşil gövde, tepelik, büyük renkli kuyruk yelpazesi.
builders.peacock = function(model: Model, s: number)
	local blue = rgb(30, 95, 190)
	local teal = rgb(20, 150, 140)
	local green = rgb(40, 140, 70)
	local body = makeBody(model, s, Vector3.new(1.3, 1.3, 2.0), 1.0 + 0.65, blue)
	birdLegs(model, body, s, 1.3, 1.0, 0.3, 0.1, rgb(120, 110, 100))
	part(model, body, s, "Neck", Vector3.new(0.45, 1.5, 0.45), Vector3.new(0, 1.2, -0.85), blue)
	local head = part(model, body, s, "Head", Vector3.new(0.55, 0.55, 0.6), Vector3.new(0, 2.05, -0.95), blue)
	part(model, body, s, "Beak", Vector3.new(0.15, 0.15, 0.32), Vector3.new(0, 1.98, -1.4), rgb(150, 125, 90))
	for i = 1, 3 do
		local t = i - 2
		local base = CFrame.new(t * 0.12, 2.3, -0.9) * CFrame.Angles(0, 0, -t * 0.4)
		partR(model, body, s, "Crest", Vector3.new(0.08, 0.5, 0.08), base * CFrame.new(0, 0.25, 0), teal)
	end
	for _, sx in SIDES do
		part(model, body, s, "Wing", Vector3.new(0.18, 0.9, 1.4), Vector3.new(sx * 0.7, 0.05, 0.1), rgb(120, 80, 40))
	end
	fan(
		model,
		body,
		s,
		CFrame.new(0, 0.2, 0.9) * CFrame.Angles(0.2, 0, 0),
		7,
		1.1,
		2.6,
		0.9,
		{ green, teal },
		rgb(25, 70, 160)
	)
	dotEyes(model, head, s, 0.26, 0.08, -0.2, 0.14)
end

-- Manda: iri koyu gövde, geriye kıvrık boynuz.
builders.buffalo = function(model: Model, s: number)
	local hide = rgb(52, 44, 42)
	local horn = rgb(205, 195, 170)
	local body = quad(model, s, Vector3.new(3.0, 2.6, 5.0), 1.4, 0.7, hide, rgb(42, 36, 34))
	part(model, body, s, "Shoulder", Vector3.new(2.3, 0.8, 1.6), Vector3.new(0, 1.5, -1.3), hide)
	local head = part(model, body, s, "Head", Vector3.new(1.8, 1.7, 1.8), Vector3.new(0, 0.1, -3.2), hide)
	part(model, body, s, "Muzzle", Vector3.new(1.4, 0.9, 0.7), Vector3.new(0, -0.5, -4.2), rgb(95, 80, 76))
	for _, sx in SIDES do
		part(model, body, s, "HornBase", Vector3.new(1.1, 0.35, 0.35), Vector3.new(sx * 1.4, 0.75, -3.1), horn)
		partR(
			model,
			body,
			s,
			"HornTip",
			Vector3.new(0.32, 1.0, 0.32),
			CFrame.new(sx * 2.0, 1.2, -2.9) * CFrame.Angles(0.5, 0, 0),
			horn
		)
		part(model, body, s, "Ear", Vector3.new(0.7, 0.25, 0.4), Vector3.new(sx * 1.3, 0.35, -2.7), rgb(70, 58, 54))
	end
	part(model, body, s, "Tail", Vector3.new(0.25, 1.8, 0.25), Vector3.new(0, -0.3, 2.7), hide)
	part(model, body, s, "TailTuft", Vector3.new(0.4, 0.5, 0.4), Vector3.new(0, -1.3, 2.7), BLACK)
	eyePair(model, head, s, 0.6, 0.35, -0.86, 0.3, rgb(30, 20, 15))
end

-- Bıldırcın: minik yuvarlak benekli kuş.
builders.quail = function(model: Model, s: number)
	local brown = rgb(150, 112, 74)
	local dark = rgb(78, 56, 38)
	local cream = rgb(232, 215, 178)
	local body = makeBody(model, s, Vector3.new(1.0, 1.0, 1.3), 0.35 + 0.5, brown)
	birdLegs(model, body, s, 1.0, 0.35, 0.25, 0.05, rgb(200, 150, 110))
	part(model, body, s, "Belly", Vector3.new(0.9, 0.4, 1.0), Vector3.new(0, -0.35, -0.05), cream)
	for i = 1, 3 do
		part(
			model,
			body,
			s,
			"Spot",
			Vector3.new(0.3, 0.06, 0.25),
			Vector3.new((i - 2) * 0.25, 0.52, 0.1 + (i % 2) * 0.3),
			dark
		)
	end
	local head = ball(model, body, s, "Head", 0.6, Vector3.new(0, 0.55, -0.65), rgb(165, 120, 80))
	part(model, body, s, "Throat", Vector3.new(0.4, 0.25, 0.3), Vector3.new(0, 0.3, -0.85), dark)
	part(model, body, s, "Brow", Vector3.new(0.5, 0.08, 0.35), Vector3.new(0, 0.82, -0.7), cream)
	part(model, body, s, "Crest", Vector3.new(0.08, 0.35, 0.08), Vector3.new(0, 1.0, -0.6), dark)
	part(model, body, s, "Beak", Vector3.new(0.15, 0.12, 0.2), Vector3.new(0, 0.5, -1.05), dark)
	part(model, body, s, "Tail", Vector3.new(0.4, 0.5, 0.3), Vector3.new(0, 0.25, 0.75), dark)
	dotEyes(model, head, s, 0.22, 0.08, -0.2, 0.12)
end

-- Güvercin: gri, parlak yeşil-mor boyun, küçük gaga.
builders.pigeon = function(model: Model, s: number)
	local gray = rgb(150, 155, 165)
	local darkGray = rgb(95, 100, 112)
	local body = makeBody(model, s, Vector3.new(1.1, 1.0, 1.8), 0.4 + 0.5, gray)
	birdLegs(model, body, s, 1.0, 0.4, 0.25, 0.05, rgb(215, 120, 130))
	for _, sx in SIDES do
		part(model, body, s, "Wing", Vector3.new(0.15, 0.7, 1.2), Vector3.new(sx * 0.58, 0.05, 0.2), darkGray)
	end
	part(model, body, s, "Rump", Vector3.new(0.8, 0.3, 0.5), Vector3.new(0, 0.3, 0.8), rgb(235, 235, 240))
	part(model, body, s, "Tail", Vector3.new(0.8, 0.15, 0.9), Vector3.new(0, 0.0, 1.5), rgb(70, 74, 86))
	part(model, body, s, "Neck", Vector3.new(0.65, 0.55, 0.6), Vector3.new(0, 0.7, -0.8), rgb(60, 160, 140))
	local head = ball(model, body, s, "Head", 0.6, Vector3.new(0, 1.0, -1.0), gray)
	part(model, body, s, "Beak", Vector3.new(0.14, 0.12, 0.25), Vector3.new(0, 0.95, -1.4), rgb(110, 105, 100))
	part(model, body, s, "Cere", Vector3.new(0.16, 0.08, 0.08), Vector3.new(0, 1.03, -1.3), rgb(240, 240, 240))
	eyePair(model, head, s, 0.24, 0.08, -0.2, 0.16, rgb(235, 130, 40))
end

-- Salyangoz: yumuşak gövde + yanlardan spiral görünen kabuk.
builders.snail = function(model: Model, s: number)
	local skin = rgb(205, 188, 140)
	local body = makeBody(model, s, Vector3.new(1.0, 0.4, 2.8), 0.2, skin)
	part(model, body, s, "Tail", Vector3.new(0.7, 0.25, 0.8), Vector3.new(0, -0.08, 1.6), skin)
	part(model, body, s, "Mantle", Vector3.new(0.95, 0.5, 0.8), Vector3.new(0, 0.4, -0.45), rgb(170, 140, 95))
	part(model, body, s, "Neck", Vector3.new(0.6, 0.9, 0.7), Vector3.new(0, 0.5, -1.1), skin)
	part(model, body, s, "Head", Vector3.new(0.75, 0.7, 0.8), Vector3.new(0, 0.95, -1.45), skin)
	for _, sx in SIDES do
		local base = CFrame.new(sx * 0.15, 1.3, -1.55) * CFrame.Angles(0, 0, -sx * 0.25)
		partR(model, body, s, "Stalk", Vector3.new(0.1, 0.9, 0.1), base * CFrame.new(0, 0.45, 0), skin)
		local tip = partR(model, body, s, "StalkTip", Vector3.one * 0.22, base * CFrame.new(0, 0.9, 0), BLACK)
		tip.Shape = Enum.PartType.Ball
	end
	-- Kabuk: iç içe silindirler (kalınlık, çap, renk); iki yandan sarmal halkalar gibi okunur.
	local rings: { { thickness: number, diameter: number, color: Color3 } } = {
		{ thickness = 0.95, diameter = 2.6, color = rgb(150, 92, 48) },
		{ thickness = 1.1, diameter = 1.9, color = rgb(200, 150, 95) },
		{ thickness = 1.25, diameter = 1.2, color = rgb(110, 62, 32) },
		{ thickness = 1.35, diameter = 0.6, color = rgb(225, 185, 130) },
	}
	for _, r in rings do
		local c = part(
			model,
			body,
			s,
			"Shell",
			Vector3.new(r.thickness, r.diameter, r.diameter),
			Vector3.new(0, 1.3, 0.45),
			r.color
		)
		c.Shape = Enum.PartType.Cylinder
	end
end

-- Yak: uzun saçaklı kürk, yatay açılıp yukarı dönen boynuz.
builders.yak = function(model: Model, s: number)
	local fur = rgb(58, 42, 34)
	local hair = rgb(40, 29, 24)
	local horn = rgb(220, 205, 170)
	local body = quad(model, s, Vector3.new(2.8, 2.5, 4.4), 1.1, 0.7, fur, hair)
	part(model, body, s, "Hump", Vector3.new(2.2, 0.9, 1.6), Vector3.new(0, 1.55, -1.1), fur)
	for _, sx in SIDES do
		part(model, body, s, "Skirt", Vector3.new(0.4, 1.5, 3.6), Vector3.new(sx * 1.5, -1.0, 0), hair)
		part(model, body, s, "HornBase", Vector3.new(1.2, 0.3, 0.3), Vector3.new(sx * 1.4, 0.55, -3.0), horn)
		part(model, body, s, "HornTip", Vector3.new(0.3, 1.0, 0.3), Vector3.new(sx * 2.1, 1.0, -3.0), horn)
		part(model, body, s, "Ear", Vector3.new(0.5, 0.25, 0.4), Vector3.new(sx * 1.0, 0.45, -2.5), hair)
	end
	local head = part(model, body, s, "Head", Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, -0.2, -3.0), fur)
	part(model, body, s, "Muzzle", Vector3.new(1.2, 0.8, 0.6), Vector3.new(0, -0.6, -3.95), rgb(110, 90, 80))
	part(model, body, s, "Forelock", Vector3.new(1.4, 0.4, 1.0), Vector3.new(0, 0.7, -3.0), rgb(110, 80, 55))
	part(model, body, s, "Tail", Vector3.new(0.5, 1.6, 0.5), Vector3.new(0, -0.5, 2.4), hair)
	dotEyes(model, head, s, 0.62, 0.2, -0.7, 0.26)
end

-- Lama: uzun boyun, muz kulak, krem yün.
builders.llama = function(model: Model, s: number)
	local wool = rgb(232, 220, 190)
	local tan = rgb(185, 150, 110)
	local body = quad(model, s, Vector3.new(1.8, 1.9, 2.8), 2.0, 0.4, wool, tan)
	part(model, body, s, "Fluff", Vector3.new(2.0, 0.6, 2.4), Vector3.new(0, 0.95, 0.1), wool)
	part(model, body, s, "Blanket", Vector3.new(1.9, 0.3, 1.2), Vector3.new(0, 1.1, 0.2), rgb(170, 60, 70))
	local nb = CFrame.new(0, 0.5, -1.2) * CFrame.Angles(-0.25, 0, 0)
	partR(model, body, s, "Neck", Vector3.new(0.7, 2.4, 0.7), nb * CFrame.new(0, 1.2, 0), wool)
	local head = part(model, body, s, "Head", Vector3.new(0.8, 0.8, 1.2), Vector3.new(0, 3.0, -1.95), wool)
	part(model, body, s, "Muzzle", Vector3.new(0.5, 0.45, 0.5), Vector3.new(0, 2.85, -2.75), tan)
	part(model, body, s, "Tuft", Vector3.new(0.6, 0.3, 0.6), Vector3.new(0, 3.5, -1.75), wool)
	for _, sx in SIDES do
		local base = CFrame.new(sx * 0.3, 3.4, -1.7) * CFrame.Angles(0, 0, -sx * 0.25)
		partR(model, body, s, "Ear", Vector3.new(0.2, 0.8, 0.25), base * CFrame.new(0, 0.4, 0), tan)
	end
	part(model, body, s, "Tail", Vector3.new(0.4, 0.5, 0.4), Vector3.new(0, 0.7, 1.5), wool)
	eyePair(model, head, s, 0.36, 0.12, -0.55, 0.2)
end

-- Geyik: ince bacaklar, dallı boynuz, benekli sırt.
builders.deer = function(model: Model, s: number)
	local coat = rgb(176, 114, 62)
	local dark = rgb(92, 58, 34)
	local white = rgb(245, 238, 225)
	local body = quad(model, s, Vector3.new(1.5, 1.5, 3.2), 2.2, 0.3, coat, dark)
	part(model, body, s, "Belly", Vector3.new(1.3, 0.3, 2.6), Vector3.new(0, -0.6, 0), white)
	for i = 1, 4 do
		part(
			model,
			body,
			s,
			"Spot",
			Vector3.new(0.3, 0.05, 0.3),
			Vector3.new(((i % 2) * 2 - 1) * 0.35, 0.76, -0.9 + i * 0.5),
			white
		)
	end
	part(model, body, s, "Tail", Vector3.new(0.4, 0.5, 0.3), Vector3.new(0, 0.4, 1.7), white)
	local nb = CFrame.new(0, 0.5, -1.4) * CFrame.Angles(-0.5, 0, 0)
	partR(model, body, s, "Neck", Vector3.new(0.6, 1.6, 0.6), nb * CFrame.new(0, 0.8, 0), coat)
	local head = part(model, body, s, "Head", Vector3.new(0.7, 0.7, 1.3), Vector3.new(0, 2.05, -2.75), coat)
	ball(model, body, s, "Nose", 0.3, Vector3.new(0, 1.95, -3.45), BLACK)
	for _, sx in SIDES do
		part(model, body, s, "Ear", Vector3.new(0.2, 0.6, 0.35), Vector3.new(sx * 0.5, 2.35, -2.4), coat)
		local beam = CFrame.new(sx * 0.25, 2.4, -2.55) * CFrame.Angles(0, 0, -sx * 0.35)
		partR(model, body, s, "Antler", Vector3.new(0.15, 1.4, 0.15), beam * CFrame.new(0, 0.7, 0), dark)
		local tine1 = beam * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, -sx * 0.7) * CFrame.new(0, 0.3, 0)
		partR(model, body, s, "Tine", Vector3.new(0.12, 0.6, 0.12), tine1, dark)
		local tine2 = beam * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, sx * 0.5) * CFrame.new(0, 0.25, 0)
		partR(model, body, s, "Tine", Vector3.new(0.12, 0.5, 0.12), tine2, dark)
	end
	eyePair(model, head, s, 0.36, 0.12, -0.5, 0.18)
end

-- Şahin: kahverengi, kıvrık gagalı, dik duran yırtıcı.
builders.falcon = function(model: Model, s: number)
	local brown = rgb(112, 76, 46)
	local dark = rgb(66, 44, 28)
	local cream = rgb(232, 210, 165)
	local body = makeBody(model, s, Vector3.new(1.1, 1.8, 1.2), 0.8 + 0.9, brown)
	birdLegs(model, body, s, 1.8, 0.8, 0.3, 0.0, rgb(230, 190, 60))
	part(model, body, s, "Chest", Vector3.new(0.95, 1.2, 0.12), Vector3.new(0, 0.1, -0.62), cream)
	for _, p in { Vector3.new(-0.2, 0.35, -0.7), Vector3.new(0.2, 0.35, -0.7), Vector3.new(0, -0.1, -0.7) } do
		part(model, body, s, "ChestSpot", Vector3.new(0.15, 0.15, 0.04), p, dark)
	end
	for _, sx in SIDES do
		part(model, body, s, "Wing", Vector3.new(0.18, 1.5, 0.95), Vector3.new(sx * 0.62, 0.0, 0.15), dark)
		part(model, body, s, "Malar", Vector3.new(0.1, 0.3, 0.1), Vector3.new(sx * 0.3, 1.0, -0.5), dark)
	end
	partR(
		model,
		body,
		s,
		"Tail",
		Vector3.new(0.7, 1.5, 0.15),
		CFrame.new(0, -0.6, 0.5) * CFrame.Angles(-0.4, 0, 0) * CFrame.new(0, -0.7, 0),
		brown
	)
	local head = part(model, body, s, "Head", Vector3.new(0.8, 0.75, 0.85), Vector3.new(0, 1.2, -0.15), brown)
	part(model, body, s, "Cap", Vector3.new(0.82, 0.2, 0.87), Vector3.new(0, 1.5, -0.15), dark)
	part(model, body, s, "Beak", Vector3.new(0.2, 0.22, 0.3), Vector3.new(0, 1.1, -0.7), rgb(70, 70, 75))
	part(model, body, s, "BeakHook", Vector3.new(0.16, 0.2, 0.14), Vector3.new(0, 0.93, -0.82), rgb(40, 40, 45))
	eyePair(model, head, s, 0.3, 0.08, -0.38, 0.2, rgb(40, 28, 15))
end

-- Sincap: iri kabarık dik kuyruk, kemirgen dişi.
builders.squirrel = function(model: Model, s: number)
	local fur = rgb(168, 98, 50)
	local light = rgb(230, 200, 150)
	local body = quad(model, s, Vector3.new(1.0, 1.0, 1.6), 0.4, 0.25, fur, fur)
	part(model, body, s, "Belly", Vector3.new(0.85, 0.2, 1.2), Vector3.new(0, -0.45, -0.05), light)
	local head = part(model, body, s, "Head", Vector3.new(0.8, 0.75, 0.85), Vector3.new(0, 0.5, -1.0), fur)
	part(model, body, s, "Snout", Vector3.new(0.4, 0.35, 0.4), Vector3.new(0, 0.38, -1.55), light)
	ball(model, body, s, "Nose", 0.16, Vector3.new(0, 0.48, -1.78), rgb(60, 36, 30))
	part(model, body, s, "Teeth", Vector3.new(0.22, 0.24, 0.05), Vector3.new(0, 0.12, -1.72), rgb(250, 248, 235))
	for _, sx in SIDES do
		part(model, body, s, "Ear", Vector3.new(0.2, 0.35, 0.15), Vector3.new(sx * 0.28, 1.0, -0.95), fur)
	end
	partR(model, body, s, "TailA", Vector3.new(0.7, 1.0, 0.7), CFrame.new(0, 0.7, 1.1) * CFrame.Angles(0.25, 0, 0), fur)
	part(model, body, s, "TailB", Vector3.new(0.95, 1.1, 0.9), Vector3.new(0, 1.5, 1.25), rgb(188, 118, 62))
	partR(
		model,
		body,
		s,
		"TailC",
		Vector3.new(0.85, 0.8, 0.8),
		CFrame.new(0, 2.3, 1.0) * CFrame.Angles(-0.3, 0, 0),
		light
	)
	eyePair(model, head, s, 0.33, 0.12, -0.4, 0.2)
end

-- İpek böceği: krem renkli bölmeli tırtıl; dizili toplar.
builders.silkworm = function(model: Model, s: number)
	local cream = rgb(238, 232, 205)
	local band = rgb(214, 205, 168)
	local dia = { 1.1, 1.2, 1.2, 1.15, 1.0, 0.8 }
	local zs = { -1.5, -0.8, 0, 0.7, 1.35, 1.9 }
	local body: Part? = nil
	for i, d in dia do
		local seg = block(
			model,
			"Segment",
			Vector3.one * d * s,
			CFrame.new(0, d / 2 * s, zs[i] * s),
			if i % 2 == 0 then band else cream
		)
		seg.Shape = Enum.PartType.Ball
		if i == 3 then
			body = seg
			seg.Name = "Body"
		end
	end
	local main = body :: Part
	model.PrimaryPart = main
	local head = ball(model, main, s, "Head", 1.0, Vector3.new(0, 0.05, -2.2), rgb(225, 205, 150))
	part(model, main, s, "Mandible", Vector3.new(0.35, 0.2, 0.2), Vector3.new(0, -0.15, -2.7), rgb(120, 80, 50))
	for _, i in { 4, 5, 6 } do
		for _, sx in SIDES do
			part(
				model,
				main,
				s,
				"Proleg",
				Vector3.new(0.25, 0.25, 0.3),
				Vector3.new(sx * 0.3, -0.45, zs[i] - 0.1),
				band
			)
		end
	end
	part(model, main, s, "Horn", Vector3.new(0.14, 0.4, 0.14), Vector3.new(0, 0.55, 2.2), rgb(70, 50, 40))
	dotEyes(model, head, s, 0.32, 0.2, -0.4, 0.16, rgb(90, 55, 35))
end

-- Papağan: canlı kırmızı-mavi-yeşil, kalın kıvrık gaga, uzun kuyruk.
builders.parrot = function(model: Model, s: number)
	local red = rgb(210, 35, 40)
	local blue = rgb(30, 90, 210)
	local body = makeBody(model, s, Vector3.new(1.2, 1.6, 1.3), 0.6 + 0.8, red)
	birdLegs(model, body, s, 1.6, 0.6, 0.3, 0.0, rgb(110, 110, 115))
	part(model, body, s, "Belly", Vector3.new(0.9, 0.8, 0.12), Vector3.new(0, -0.2, -0.68), rgb(70, 190, 90))
	local head = part(model, body, s, "Head", Vector3.new(0.95, 0.95, 0.95), Vector3.new(0, 1.2, -0.25), red)
	part(model, body, s, "BeakUpper", Vector3.new(0.4, 0.4, 0.55), Vector3.new(0, 1.05, -0.95), rgb(235, 225, 200))
	part(model, body, s, "BeakHook", Vector3.new(0.3, 0.25, 0.2), Vector3.new(0, 0.82, -1.15), rgb(60, 58, 58))
	part(model, body, s, "BeakLower", Vector3.new(0.3, 0.15, 0.35), Vector3.new(0, 0.75, -0.85), rgb(60, 58, 58))
	for _, sx in SIDES do
		part(
			model,
			body,
			s,
			"Cheek",
			Vector3.new(0.1, 0.5, 0.45),
			Vector3.new(sx * 0.49, 1.15, -0.45),
			rgb(245, 245, 240)
		)
		part(model, body, s, "Wing", Vector3.new(0.22, 1.3, 0.9), Vector3.new(sx * 0.7, -0.05, 0.15), blue)
		part(
			model,
			body,
			s,
			"WingBand",
			Vector3.new(0.24, 0.4, 0.9),
			Vector3.new(sx * 0.7, 0.55, 0.15),
			rgb(245, 205, 50)
		)
		part(model, body, s, "WingTip", Vector3.new(0.2, 0.35, 0.7), Vector3.new(sx * 0.7, -0.8, 0.2), rgb(50, 180, 90))
	end
	local tb = CFrame.new(0, -0.7, 0.9) * CFrame.Angles(0.25, 0, 0)
	partR(model, body, s, "Tail", Vector3.new(0.5, 0.18, 2.2), tb * CFrame.new(0, 0, 1.1), red)
	partR(model, body, s, "TailBlue", Vector3.new(0.35, 0.15, 1.8), tb * CFrame.new(0, -0.12, 1.0), blue)
	eyePair(model, head, s, 0.4, 0.2, -0.38, 0.22)
end

-- Kaplumbağa: kubbe kabuk, kısa bacaklar, uzun boyun.
builders.tortoise = function(model: Model, s: number)
	local skin = rgb(150, 160, 90)
	local rim = rgb(86, 78, 36)
	local shell = rgb(112, 100, 44)
	local body = makeBody(model, s, Vector3.new(3.0, 0.7, 3.8), 0.5 + 0.35, rim)
	for _, sx in SIDES do
		for _, sz in SIDES do
			part(model, body, s, "Leg", Vector3.new(0.7, 0.6, 0.8), Vector3.new(sx * 1.1, -0.45, sz * 1.2), skin)
		end
	end
	part(model, body, s, "Shell", Vector3.new(2.5, 0.6, 3.2), Vector3.new(0, 0.6, 0), shell)
	ball(model, body, s, "Dome", 1.9, Vector3.new(0, 1.0, 0), rim)
	for _, p in
		{
			Vector3.new(-0.7, 0.92, -0.8),
			Vector3.new(0.7, 0.92, -0.8),
			Vector3.new(-0.7, 0.92, 0.8),
			Vector3.new(0.7, 0.92, 0.8),
		}
	do
		part(model, body, s, "Scute", Vector3.new(0.7, 0.08, 0.7), p, rgb(160, 140, 60))
	end
	part(model, body, s, "Neck", Vector3.new(0.7, 0.7, 1.6), Vector3.new(0, 0.1, -2.6), skin)
	local head = part(model, body, s, "Head", Vector3.new(0.9, 0.8, 1.0), Vector3.new(0, 0.15, -3.6), skin)
	part(model, body, s, "Tail", Vector3.new(0.3, 0.3, 0.6), Vector3.new(0, -0.2, 2.1), skin)
	dotEyes(model, head, s, 0.4, 0.15, -0.4, 0.16)
end

return builders
