--!strict
-- Küçük adaların görünümü (veri): zemin ve bölge rengi, bölge zemin dokusu, arkada ayrılan şerit ve süs listesi.
-- Anahtar = Config.FARM_ISLANDS kimliği. Yeni ada = bir satır (oyun verisi Config/Species.luau'da); World katmanı yalnızca bu tabloyu okur.
-- Süs türleri: oak, pine, bush, flowers, hay, scarecrow, barrel, crate, wheelbarrow. Konumlar ada yerel koordinatındadır (+Z ada merkezinden köprünün
-- tersine): köprü yolu (x ~ 0, z < -11), bölge (30x24, merkez z = 2), yapı yerleri (x = ±18, z = 37) ve lambalar boş bırakılır.

export type Prop = { kind: string, x: number, z: number, seed: number?, size: number? }
export type IslandLook = {
	ground: Color3, -- ada zemini
	zone: Color3, -- bölge zemini
	backReserve: number, -- bölgenin arkasında hayvan konmayan şerit
	material: Enum.Material?, -- bölge zemini dokusu (varsayılan çim)
	props: { Prop }?, -- verilmezse eski ada türleri için SatelliteBuilder'ın elle yazılı süsleri kullanılır
}

local function prop(kind: string, x: number, z: number, seed: number?, size: number?): Prop
	return { kind = kind, x = x, z = z, seed = seed, size = size }
end

local LOOKS: { [string]: IslandLook } = {
	-- Çiftlik 1 (ilk üç ada elle yazılı süslerle çizilir; yalnızca renk ve doku buradadır)
	poultry = {
		ground = Color3.fromRGB(150, 165, 80),
		zone = Color3.fromRGB(205, 185, 125),
		backReserve = 8,
		material = Enum.Material.Sand,
	},
	horse = {
		ground = Color3.fromRGB(90, 150, 70),
		zone = Color3.fromRGB(145, 110, 80),
		backReserve = 8,
		material = Enum.Material.Sand,
	},
	goat = { ground = Color3.fromRGB(120, 140, 95), zone = Color3.fromRGB(130, 150, 90), backReserve = 5 },
	-- Çiftlik 2
	rabbit = {
		ground = Color3.fromRGB(128, 176, 96),
		zone = Color3.fromRGB(150, 188, 108),
		backReserve = 6,
		props = {
			prop("flowers", -36, 8, 3),
			prop("flowers", 37, 5, 5),
			prop("bush", -38, 28, 11),
			prop("bush", 35, 31, 13),
			prop("hay", -39, -14),
			prop("hay", 41, -12),
			prop("scarecrow", 37, -24),
			prop("oak", -41, 17, 17),
		},
	},
	sheep = { ground = Color3.fromRGB(118, 172, 88), zone = Color3.fromRGB(122, 168, 88), backReserve = 6 },
	pig = {
		ground = Color3.fromRGB(112, 128, 82),
		zone = Color3.fromRGB(118, 92, 64),
		backReserve = 6,
		material = Enum.Material.Ground,
	},
	-- Çiftlik 3: ayçiçeği tarlası, kuru ve sıcak tonlar
	bee = {
		ground = Color3.fromRGB(170, 178, 84),
		zone = Color3.fromRGB(198, 188, 96),
		backReserve = 6,
		props = {
			prop("flowers", -38, 8, 21),
			prop("flowers", 38, 10, 23),
			prop("flowers", -34, -14, 25),
			prop("flowers", 35, -18, 27),
			prop("oak", -41, 17, 19),
			prop("oak", 41, 17, 29),
			prop("bush", 35, 30, 31),
		},
	},
	camel = {
		ground = Color3.fromRGB(196, 170, 108),
		zone = Color3.fromRGB(214, 190, 128),
		backReserve = 8,
		material = Enum.Material.Sand,
		props = {
			prop("hay", -38, 10),
			prop("hay", 39, 12),
			prop("barrel", -40, -10),
			prop("crate", 41, -8, nil, 2.4),
			prop("crate", 40, -11, nil, 1.8),
			prop("bush", 35, 30, 41),
			prop("wheelbarrow", -36, 26),
		},
	},
	peacock = {
		ground = Color3.fromRGB(104, 168, 110),
		zone = Color3.fromRGB(96, 160, 120),
		backReserve = 8,
		props = {
			prop("oak", -41, 17, 51),
			prop("oak", 41, 17, 53),
			prop("oak", -39, -14, 55),
			prop("oak", 40, -16, 57),
			prop("flowers", -36, 30, 59),
			prop("flowers", 36, 28, 61),
			prop("flowers", 30, -24, 63),
		},
	},
	-- Çiftlik 4: gül vadisi, serin yeşil ve gül rengi toprak
	quail = {
		ground = Color3.fromRGB(150, 168, 90),
		zone = Color3.fromRGB(176, 170, 104),
		backReserve = 8,
		props = {
			prop("hay", -38, 10),
			prop("hay", -38, 14),
			prop("hay", 39, 8),
			prop("scarecrow", 37, -22),
			prop("bush", -37, 30, 71),
			prop("bush", 36, 31, 73),
			prop("flowers", -35, -16, 75),
		},
	},
	pigeon = {
		ground = Color3.fromRGB(122, 156, 110),
		zone = Color3.fromRGB(150, 140, 128),
		backReserve = 8,
		material = Enum.Material.Sand,
		props = {
			prop("pine", -41, 18, 81),
			prop("pine", 41, 18, 83),
			prop("crate", -38, -12, nil, 2.2),
			prop("barrel", 39, -12),
			prop("mailbox", 30, -26),
			prop("bush", 35, 30, 85),
		},
	},
	snail = {
		ground = Color3.fromRGB(96, 150, 96),
		zone = Color3.fromRGB(88, 138, 90),
		backReserve = 6,
		props = {
			prop("bush", -38, 8, 91),
			prop("bush", 38, 10, 93),
			prop("bush", -36, 28, 95),
			prop("bush", 36, 29, 97),
			prop("flowers", 36, -16, 99),
			prop("oak", -41, -14, 101),
		},
	},
	-- Çiftlik 5: dağ ve orman, koyu yeşil ve kayalık
	llama = {
		ground = Color3.fromRGB(128, 148, 100),
		zone = Color3.fromRGB(150, 150, 110),
		backReserve = 6,
		props = {
			prop("pine", -41, 14, 111),
			prop("pine", 41, 12, 113),
			prop("pine", 38, -20, 115),
			prop("bush", -34, 30, 117),
			prop("hay", -38, -12),
		},
	},
	deer = {
		ground = Color3.fromRGB(88, 130, 82),
		zone = Color3.fromRGB(100, 120, 78),
		backReserve = 6,
		material = Enum.Material.Ground,
		props = {
			prop("pine", -6, 49, 121),
			prop("pine", 8, 50, 123),
			prop("pine", -41, 14, 125),
			prop("pine", 41, 10, 127),
			prop("pine", -38, -10, 129),
			prop("pine", 36, -18, 131),
			prop("flowers", -34, 30, 133),
		},
	},
	falcon = {
		ground = Color3.fromRGB(122, 132, 98),
		zone = Color3.fromRGB(138, 126, 104),
		backReserve = 8,
		material = Enum.Material.Ground,
		props = {
			prop("pine", -41, 18, 141),
			prop("pine", 41, 14, 143),
			prop("crate", -38, -12, nil, 2.4),
			prop("barrel", -40, -9),
			prop("barrel", 40, -10),
			prop("bush", 33, -28, 145),
		},
	},
	-- Çiftlik 6: meyve bahçesi, açık ve renkli
	silkworm = {
		ground = Color3.fromRGB(132, 176, 100),
		zone = Color3.fromRGB(150, 180, 104),
		backReserve = 6,
		props = {
			prop("oak", -41, 17, 151),
			prop("oak", 41, 17, 153),
			prop("oak", -37, -14, 155),
			prop("bush", 35, 30, 157),
			prop("bush", -35, 31, 159),
			prop("flowers", 36, -16, 161),
		},
	},
	parrot = {
		ground = Color3.fromRGB(92, 168, 110),
		zone = Color3.fromRGB(84, 158, 118),
		backReserve = 8,
		props = {
			prop("flowers", -38, 8, 171),
			prop("flowers", 38, 10, 173),
			prop("flowers", -35, -16, 175),
			prop("flowers", 35, -20, 177),
			prop("oak", -41, 18, 179),
			prop("oak", 41, 17, 181),
		},
	},
	tortoise = {
		ground = Color3.fromRGB(128, 170, 120),
		zone = Color3.fromRGB(110, 150, 118),
		backReserve = 6,
		props = {
			prop("bush", -38, 8, 191),
			prop("bush", 38, 10, 193),
			prop("bush", -36, 30, 195),
			prop("flowers", 36, 28, 197),
			prop("barrel", -40, -12),
			prop("barrel", 40, -14),
		},
	},
}

return LOOKS
