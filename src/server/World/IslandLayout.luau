--!strict
-- Uzman adalar ve eklentiler için sabit yerleşim verisi: eklenti alanları, üretim alanı yerleri ve yükseltme eşlemesi.
-- IslandSpecialization bunları yeniden dışa aktarır (IslandSpecialization.EXTENSIONS / SITES / SITE_UPGRADE_ID).

local IslandLayout = {}

export type Site = { island: string, offset: Vector3, footprint: Vector2, title: string, icon: string }
-- Ada eklentileri: haritada yalnızca slot; görünüm satın alınca ExtensionVisualService kurar.
export type ExtensionLayout = {
	id: string,
	island: string,
	areaOffset: Vector3,
	areaSize: Vector3,
	signOffset: Vector3,
	title: string,
	icon: string,
	movement: string, -- "wander" | "track"
}

IslandLayout.EXTENSIONS = {
	folluk_garden = {
		id = "folluk_garden",
		island = "poultry",
		areaOffset = Vector3.new(25, 0, 3),
		areaSize = Vector3.new(14, 0, 25),
		signOffset = Vector3.new(25, 0, -14),
		title = "Folluk bahçesi",
		icon = "🐔",
		movement = "wander",
	},
	training_course = {
		id = "training_course",
		island = "horse",
		areaOffset = Vector3.new(-26, 0, 0),
		areaSize = Vector3.new(20, 0, 32),
		signOffset = Vector3.new(-23, 0, -24),
		title = "Koşu parkuru",
		icon = "🐎",
		movement = "track",
	},
	rocky_terraces = {
		id = "rocky_terraces",
		island = "goat",
		areaOffset = Vector3.new(-26, 0, 0),
		areaSize = Vector3.new(16, 0, 28),
		signOffset = Vector3.new(-24, 0, -22),
		title = "Kayalık otlak terasları",
		icon = "🐐",
		movement = "wander",
	},
	-- Keçi adasının ikinci eklentisi: doğu kıyıdaki kaya tırmanışı (kayalık teraslar batıda)
	goat_cliffs = {
		id = "goat_cliffs",
		island = "goat",
		areaOffset = Vector3.new(29, 0, 2),
		areaSize = Vector3.new(8, 0, 22),
		signOffset = Vector3.new(27, 0, -18),
		title = "Kaya tırmanışı",
		icon = "🐐",
		movement = "wander",
	},
	hillside_pasture = {
		id = "hillside_pasture",
		island = "sheep",
		areaOffset = Vector3.new(26, 0, 0),
		areaSize = Vector3.new(16, 0, 26),
		signOffset = Vector3.new(24, 0, -20),
		title = "Yün yamacı",
		icon = "🐑",
		movement = "wander",
	},
	truffle_grove = {
		id = "truffle_grove",
		island = "pig",
		areaOffset = Vector3.new(-26, 0, 0),
		areaSize = Vector3.new(16, 0, 26),
		signOffset = Vector3.new(-24, 0, -20),
		title = "Trüf korusu",
		icon = "🐖",
		movement = "wander",
	},
} :: { [string]: ExtensionLayout }

IslandLayout.SITES = {
	milk_factory = {
		island = "home",
		offset = Vector3.new(43, 0, -21),
		footprint = Vector2.new(20, 14),
		title = "Süt işleme alanı",
		icon = "🥛",
	},
	hatchery = {
		island = "poultry",
		offset = Vector3.new(-25, 0, 5),
		footprint = Vector2.new(14, 16),
		title = "Kuluçka alanı",
		icon = "🥚",
	},
	horse_training = {
		island = "horse",
		offset = Vector3.new(25, 0, 0),
		footprint = Vector2.new(14, 18),
		title = "Antrenman merkezi",
		icon = "🐎",
	},
} :: { [string]: Site }

-- Üretim alanı görünümü için alınmış olması gereken yol haritası öğesi
IslandLayout.SITE_UPGRADE_ID = {
	milk_factory = "milk_factory",
	hatchery = "hatchery",
	horse_training = "horse_training",
} :: { [string]: string }

return IslandLayout
