--!strict
-- Hayvan türü tablosu (veri odaklı): her satır bir hayvanın bütün içeriğini üretir (hayvan, ürün, ada, bölge, yükseltmeler, tarifler,
-- yol haritası aşaması, mevsim/hava etkisi). Yeni hayvan = bu tabloya bir satır + görsel modeller (`assets/Animals`, `assets/Buildings`, `assets/ZoneDecor`; `scripts/check-assets.py`) + `World/IslandLooks`.
-- Rakamlar Çiftlik 1 ölçeğindedir ve ada sırasının PROFİLİNDEN gelir (home/early/mid/late): mevcut hayvanlarla aynı bantta durur, böylece
-- sim ayarı bozulmaz; çiftlik çarpanı `FarmMath.getPrice` ile uygulanır (elle çarpma yok). Tasarım: docs/ADA_TASARIMI.md.
-- Elle yazılan eski türler (inek, tavuk, at, keçi, ördek, koyun, domuz, balık) kendi dosyalarındadır; hayvan -> ada -> çiftlik eşlemesi THEMES + FARM_ISLANDS.animalId.
-- Gizli bilgi koyma: ReplicatedStorage client'a da gider.

local Types = require(script.Parent:WaitForChild("Types"))

type Slot = "home" | "early" | "mid" | "late"
type Perk =
	"storageBonus"
	| "facilitySpeed"
	| "offlineBonus"
	| "sellBonus"
	| "contractBonus"
	| "goodsYield"
	| "expansionDiscount"

export type SpeciesRow = {
	id: string, -- hayvan türü kimliği; ada kimliği de budur (home satırlarında ada yoktur)
	slot: Slot, -- home: çiftliğin ana ada hayvanı; early/mid/late: THEMES.satellites sırası
	name: string,
	icon: string,
	product: string, -- hayvanın ürettiği şey (arayüz)
	price: number, -- ilk hayvanın fiyatı (Çiftlik 1 ölçeği)
	income: number, -- yetişkinin saniyelik geliri
	island: { name: string, flavor: string, perk: Perk, amount: number }?,
	zone: { name: string, profile: string }?,
	goods: { id: string, name: string, icon: string, value: number, scale: number }, -- value: birim değer (sipariş/satış); scale: ürün merkezinin tesis ölçeği (geliştirme fiyatı tabanı)
	cash: { recipe: string, recipeName: string, factory: string, factoryName: string },
	center: { recipe: string, recipeName: string, building: string, buildingName: string },
	seasons: { spring: number?, summer: number?, autumn: number?, winter: number? },
	weather: { sunny: number?, rain: number?, storm: number?, snow: number? }?,
}

-- Ada sırası profilleri: mevcut hayvanlardan türetildi (ana ada: ördek paketleme, erken: ördek adası, orta: koyun adası, geç: domuz adası).
local PROFILES = {
	home = {
		factory = { cost = 6000, boost = 1.5, step = 2, shares = { home = 0.03, slot1 = 0.03 } },
		center = { cost = 1500 },
		cash = {
			reward = 900,
			options = {
				{ adults = 1, duration = 40, reward = 330, returns = 1.5 },
				{ adults = 2, duration = 70, reward = 1390, returns = 1.8 },
				{ adults = 4, duration = 100, reward = 4400, returns = 2 },
			},
		},
		goods = { adults = 3, duration = 105, cost = 130, amount = 2 },
	},
	early = {
		barn = "barn_2",
		island = { cost = 900, step = 1, shares = { home = 0.05 } },
		factory = { cost = 2600, boost = 0.6, step = 1, shares = { previous = 0.04 } },
		center = { cost = 2000 },
		capacity = 10,
		cash = {
			reward = 900,
			options = {
				{ adults = 1, duration = 40, reward = 330, returns = 1.5 },
				{ adults = 2, duration = 70, reward = 1390, returns = 1.8 },
				{ adults = 4, duration = 100, reward = 4400, returns = 2 },
			},
		},
		goods = { adults = 2, duration = 120, cost = 80, amount = 2 },
	},
	mid = {
		barn = "barn_3",
		island = { cost = 3600, step = 2, shares = { home = 0.04, previous = 0.04 } },
		factory = { cost = 8500, boost = 0.75, step = 2, shares = { home = 0.03, previous = 0.03 } },
		center = { cost = 6500 },
		capacity = 8,
		cash = {
			reward = 2100,
			options = {
				{ adults = 1, duration = 55, reward = 1070, returns = 1.5 },
				{ adults = 2, duration = 90, reward = 4210, returns = 1.8 },
				{ adults = 4, duration = 125, reward = 13000, returns = 2 },
			},
		},
		goods = { adults = 2, duration = 135, cost = 350, amount = 2 },
	},
	late = {
		barn = "barn_4",
		island = { cost = 6400, step = 3, shares = { home = 0.03, previous = 0.03, slot1 = 0.03 } },
		factory = { cost = 12500, boost = 1, step = 3, shares = { previous = 0.02, slot1 = 0.02 } },
		center = { cost = 9500 },
		capacity = 8,
		cash = {
			reward = 3700,
			options = {
				{ adults = 1, duration = 65, reward = 2540, returns = 1.5 },
				{ adults = 2, duration = 110, reward = 10300, returns = 1.8 },
				{ adults = 4, duration = 155, reward = 32240, returns = 2 },
			},
		},
		goods = { adults = 2, duration = 165, cost = 650, amount = 2 },
	},
}

-- Etki açıklamaları: şablon başına tek çeviri (anahtar "{}: ..." biçimindedir; ilk {} adanın özellik adı, ikincisi yüzde).
local PERK_TEXT: { [Perk]: string } = {
	storageBonus = "depo kapasitesi +%",
	facilitySpeed = "üretim tesisleri %", -- perkText "%N daha hızlı" biçimini ayrıca kurar
	offlineBonus = "çevrimdışı kazanç +%",
	sellBonus = "hayvan satış geliri +%",
	contractBonus = "ahır siparişi ödülü +%",
	goodsYield = "ürün merkezi verimi +%",
	expansionDiscount = "geliştirme maliyetleri -%",
}

local function perkText(island: { name: string, flavor: string, perk: Perk, amount: number }): string
	local percent = math.floor(island.amount * 100 + 0.5)
	if island.perk == "facilitySpeed" then
		return `{island.flavor}: üretim tesisleri %{percent} daha hızlı`
	end
	return `{island.flavor}: {PERK_TEXT[island.perk]}{percent}`
end

local SPECIES: { SpeciesRow } = {
	-- Çiftlik 2 (Göl ve Yün): ördek ana ada, tavşan erken ada
	{
		id = "rabbit",
		slot = "early",
		name = "Tavşan",
		icon = "🐇",
		product = "Angora",
		price = 350,
		income = 5,
		island = { name = "Tavşan Adası", flavor = "Havadar kafesler", perk = "storageBonus", amount = 0.15 },
		zone = { name = "Tavşan Yuvası", profile = "coop" },
		goods = { id = "angora", name = "Angora", icon = "🧶", value = 84000, scale = 1040 },
		cash = {
			recipe = "angora_spinning",
			recipeName = "Angora Eğirme",
			factory = "angora_mill",
			factoryName = "Angora Değirmeni",
		},
		center = {
			recipe = "angora_goods",
			recipeName = "Angora Tarama",
			building = "angora_loom",
			buildingName = "Angora Tezgâhı",
		},
		seasons = { spring = 0.25, winter = -0.1 },
		weather = { snow = -0.1 },
	},
	-- Çiftlik 3 (Güneşli Tarla)
	{
		id = "turkey",
		slot = "home",
		name = "Hindi",
		icon = "🦃",
		product = "Hindi Füme",
		price = 450,
		income = 6,
		goods = { id = "smoked_turkey", name = "Hindi Füme", icon = "🍗", value = 220000, scale = 1600 },
		cash = {
			recipe = "turkey_packing",
			recipeName = "Hindi Paketleme",
			factory = "turkey_packer",
			factoryName = "Hindi Paketleme Fabrikası",
		},
		center = {
			recipe = "turkey_goods",
			recipeName = "Hindi Füme Hazırlama",
			building = "turkey_center",
			buildingName = "Hindi Füme Atölyesi",
		},
		seasons = { autumn = 0.25, summer = -0.1 },
	},
	{
		id = "bee",
		slot = "early",
		name = "Arı",
		icon = "🐝",
		product = "Bal",
		price = 380,
		income = 5.2,
		island = { name = "Arı Adası", flavor = "Çiçek mevsimi", perk = "facilitySpeed", amount = 0.1 },
		zone = { name = "Arı Kovanları", profile = "coop" },
		goods = { id = "honey", name = "Bal", icon = "🍯", value = 79000, scale = 1200 },
		cash = {
			recipe = "honey_bottling",
			recipeName = "Bal Şişeleme",
			factory = "honey_mill",
			factoryName = "Bal Şişeleme Atölyesi",
		},
		center = {
			recipe = "honey_goods",
			recipeName = "Bal Süzme",
			building = "honey_extractor",
			buildingName = "Bal Süzme Evi",
		},
		seasons = { spring = 0.2, summer = 0.25, winter = -0.3 },
		weather = { sunny = 0.1, rain = -0.15, storm = -0.2 },
	},
	{
		id = "camel",
		slot = "mid",
		name = "Deve",
		icon = "🐪",
		product = "Deve Sütü",
		price = 1300,
		income = 12.5,
		island = { name = "Deve Adası", flavor = "Çöl kervanı", perk = "offlineBonus", amount = 0.2 },
		zone = { name = "Deve Ağılı", profile = "stable" },
		goods = { id = "camel_milk", name = "Deve Sütü", icon = "🥛", value = 240000, scale = 1700 },
		cash = {
			recipe = "camel_caravan",
			recipeName = "Kervan Seferi",
			factory = "caravan_post",
			factoryName = "Kervan Postası",
		},
		center = {
			recipe = "camel_goods",
			recipeName = "Deve Sütü Sağımı",
			building = "camel_dairy",
			buildingName = "Deve Süthanesi",
		},
		seasons = { summer = 0.25, winter = -0.1 },
		weather = { sunny = 0.08 },
	},
	{
		id = "peacock",
		slot = "late",
		name = "Tavus Kuşu",
		icon = "🦚",
		product = "Tavus Tüyü",
		price = 2100,
		income = 25,
		island = { name = "Tavus Adası", flavor = "Gösteriş pazarı", perk = "sellBonus", amount = 0.15 },
		zone = { name = "Tavus Bahçesi", profile = "fold" },
		goods = { id = "peacock_feather", name = "Tavus Tüyü", icon = "🪶", value = 650000, scale = 6000 },
		cash = {
			recipe = "peacock_show",
			recipeName = "Tavus Gösterisi",
			factory = "peacock_pavilion",
			factoryName = "Gösteri Köşkü",
		},
		center = {
			recipe = "peacock_goods",
			recipeName = "Tüy Ayıklama",
			building = "peacock_atelier",
			buildingName = "Süs Atölyesi",
		},
		seasons = { spring = 0.2, autumn = 0.1, winter = -0.1 },
	},
	-- Çiftlik 4 (Gül Vadisi)
	{
		id = "buffalo",
		slot = "home",
		name = "Manda",
		icon = "🐃",
		product = "Kaymak",
		price = 500,
		income = 6.5,
		goods = { id = "buffalo_cream", name = "Kaymak", icon = "🧈", value = 270000, scale = 1400 },
		cash = {
			recipe = "buffalo_packing",
			recipeName = "Kaymak Paketleme",
			factory = "buffalo_packer",
			factoryName = "Kaymak Fabrikası",
		},
		center = {
			recipe = "buffalo_goods",
			recipeName = "Kaymak Yapımı",
			building = "buffalo_center",
			buildingName = "Kaymak Toplama Merkezi",
		},
		seasons = { summer = 0.15, winter = -0.1 },
		weather = { rain = 0.1 },
	},
	{
		id = "quail",
		slot = "early",
		name = "Bıldırcın",
		icon = "🐦",
		product = "Bıldırcın Yumurtası",
		price = 360,
		income = 5,
		island = { name = "Bıldırcın Adası", flavor = "Verimli tarla", perk = "storageBonus", amount = 0.15 },
		zone = { name = "Bıldırcın Kümesi", profile = "coop" },
		goods = { id = "quail_egg", name = "Bıldırcın Yumurtası", icon = "🥚", value = 84000, scale = 920 },
		cash = {
			recipe = "quail_packing",
			recipeName = "Yumurta Kolileme",
			factory = "quail_hatchery",
			factoryName = "Bıldırcın Kuluçkası",
		},
		center = {
			recipe = "quail_goods",
			recipeName = "Bıldırcın Toplama",
			building = "quail_coop",
			buildingName = "Bıldırcın Toplama Merkezi",
		},
		seasons = { autumn = 0.2, winter = -0.15 },
	},
	{
		id = "pigeon",
		slot = "mid",
		name = "Güvercin",
		icon = "🕊️",
		product = "Posta",
		price = 1200,
		income = 12,
		island = { name = "Güvercin Adası", flavor = "Posta yolu", perk = "contractBonus", amount = 0.1 },
		zone = { name = "Güvercinlik", profile = "stable" },
		goods = { id = "pigeon_post", name = "Posta", icon = "✉️", value = 250000, scale = 1400 },
		cash = {
			recipe = "pigeon_courier",
			recipeName = "Posta Seferi",
			factory = "pigeon_loft",
			factoryName = "Posta Kulesi",
		},
		center = {
			recipe = "pigeon_goods",
			recipeName = "Mektup Dağıtımı",
			building = "pigeon_office",
			buildingName = "Posta Ofisi",
		},
		seasons = { spring = 0.15, autumn = 0.05 },
		weather = { storm = -0.2 },
	},
	{
		id = "snail",
		slot = "late",
		name = "Salyangoz",
		icon = "🐌",
		product = "Kaviyar",
		price = 2000,
		income = 24,
		island = { name = "Salyangoz Adası", flavor = "Nemli bahçe", perk = "goodsYield", amount = 0.12 },
		zone = { name = "Salyangoz Çiftliği", profile = "fold" },
		goods = { id = "snail_caviar", name = "Kaviyar", icon = "🥄", value = 690000, scale = 5000 },
		cash = {
			recipe = "snail_gourmet",
			recipeName = "Gurme Servis",
			factory = "snail_bistro",
			factoryName = "Salyangoz Bistrosu",
		},
		center = {
			recipe = "snail_goods",
			recipeName = "Kaviyar Hazırlama",
			building = "snail_cellar",
			buildingName = "Kaviyar Mahzeni",
		},
		seasons = { spring = 0.1, summer = -0.2, autumn = 0.15 },
		weather = { rain = 0.3, sunny = -0.12 },
	},
	-- Çiftlik 5 (Dağ ve Orman)
	{
		id = "yak",
		slot = "home",
		name = "Yak",
		icon = "🐂",
		product = "Yak Kürkü",
		price = 550,
		income = 7,
		goods = { id = "yak_fur", name = "Yak Kürkü", icon = "🧣", value = 290000, scale = 1600 },
		cash = {
			recipe = "yak_packing",
			recipeName = "Kürk Paketleme",
			factory = "yak_packer",
			factoryName = "Kürk Fabrikası",
		},
		center = {
			recipe = "yak_goods",
			recipeName = "Kürk Tarama",
			building = "yak_center",
			buildingName = "Kürk Toplama Merkezi",
		},
		seasons = { winter = 0.3, summer = -0.15 },
		weather = { snow = 0.1 },
	},
	{
		id = "llama",
		slot = "early",
		name = "Lama",
		icon = "🦙",
		product = "Lama Kumaşı",
		price = 400,
		income = 5.5,
		island = { name = "Lama Adası", flavor = "Dağ yolu", perk = "goodsYield", amount = 0.1 },
		zone = { name = "Lama Yaylası", profile = "coop" },
		goods = { id = "llama_cloth", name = "Lama Kumaşı", icon = "🧵", value = 92000, scale = 1400 },
		cash = {
			recipe = "llama_weaving",
			recipeName = "Kumaş Dokuma",
			factory = "llama_loom",
			factoryName = "Dokuma Tezgâhı",
		},
		center = {
			recipe = "llama_goods",
			recipeName = "Kumaş Biçme",
			building = "llama_workshop",
			buildingName = "Kumaş Atölyesi",
		},
		seasons = { autumn = 0.2, winter = 0.1 },
	},
	{
		id = "deer",
		slot = "mid",
		name = "Geyik",
		icon = "🦌",
		product = "Boynuz",
		price = 1450,
		income = 13.5,
		island = { name = "Geyik Adası", flavor = "Orman açıklığı", perk = "expansionDiscount", amount = 0.07 },
		zone = { name = "Geyik Ormanı", profile = "stable" },
		goods = { id = "antler", name = "Boynuz", icon = "🦴", value = 280000, scale = 2200 },
		cash = {
			recipe = "deer_carving",
			recipeName = "Boynuz Oymacılığı",
			factory = "deer_lodge",
			factoryName = "Oymacı Kulübesi",
		},
		center = {
			recipe = "deer_goods",
			recipeName = "Boynuz Toplama",
			building = "deer_forge",
			buildingName = "Boynuz Deposu",
		},
		seasons = { autumn = 0.25, spring = 0.1 },
	},
	{
		id = "falcon",
		slot = "late",
		name = "Şahin",
		icon = "🦅",
		product = "Av Ödülü",
		price = 2300,
		income = 27,
		island = { name = "Şahin Adası", flavor = "Zirve avı", perk = "contractBonus", amount = 0.1 },
		zone = { name = "Şahin Tüneği", profile = "fold" },
		goods = { id = "falcon_trophy", name = "Av Ödülü", icon = "🏅", value = 780000, scale = 8000 },
		cash = {
			recipe = "falcon_hunt",
			recipeName = "Av Seferi",
			factory = "falcon_perch",
			factoryName = "Şahin Kalesi",
		},
		center = {
			recipe = "falcon_goods",
			recipeName = "Ödül Hazırlama",
			building = "falcon_hall",
			buildingName = "Ödül Salonu",
		},
		seasons = { autumn = 0.15, winter = 0.1 },
		weather = { storm = -0.1 },
	},
	-- Çiftlik 6 (Meyve Bahçesi)
	{
		id = "squirrel",
		slot = "home",
		name = "Sincap",
		icon = "🐿️",
		product = "Fındık",
		price = 620,
		income = 7.5,
		goods = { id = "hazelnut", name = "Fındık", icon = "🌰", value = 270000, scale = 1800 },
		cash = {
			recipe = "squirrel_packing",
			recipeName = "Fındık Paketleme",
			factory = "squirrel_packer",
			factoryName = "Fındık Fabrikası",
		},
		center = {
			recipe = "squirrel_goods",
			recipeName = "Fındık Toplama",
			building = "squirrel_center",
			buildingName = "Fındık Deposu",
		},
		seasons = { autumn = 0.3, winter = -0.15 },
	},
	{
		id = "silkworm",
		slot = "early",
		name = "İpek Böceği",
		icon = "🐛",
		product = "İpek",
		price = 420,
		income = 5.6,
		island = { name = "İpek Böceği Adası", flavor = "Dut bahçesi", perk = "facilitySpeed", amount = 0.12 },
		zone = { name = "Dut Bahçesi", profile = "coop" },
		goods = { id = "silk", name = "İpek", icon = "🧵", value = 83000, scale = 1600 },
		cash = {
			recipe = "silk_spinning",
			recipeName = "İpek Eğirme",
			factory = "silk_mill",
			factoryName = "İpek Değirmeni",
		},
		center = {
			recipe = "silk_goods",
			recipeName = "Koza Toplama",
			building = "silk_loft",
			buildingName = "Koza Sarayı",
		},
		seasons = { spring = 0.25, summer = 0.1, winter = -0.25 },
	},
	{
		id = "parrot",
		slot = "mid",
		name = "Papağan",
		icon = "🦜",
		product = "Gösteri Bileti",
		price = 1350,
		income = 13,
		island = { name = "Papağan Adası", flavor = "Tropik sahne", perk = "sellBonus", amount = 0.15 },
		zone = { name = "Papağan Sahnesi", profile = "stable" },
		goods = { id = "parrot_ticket", name = "Gösteri Bileti", icon = "🎟️", value = 240000, scale = 2000 },
		cash = {
			recipe = "parrot_show",
			recipeName = "Papağan Gösterisi",
			factory = "parrot_theatre",
			factoryName = "Tropik Tiyatro",
		},
		center = {
			recipe = "parrot_goods",
			recipeName = "Bilet Basımı",
			building = "parrot_box",
			buildingName = "Bilet Gişesi",
		},
		seasons = { summer = 0.2, winter = -0.15 },
		weather = { rain = -0.1 },
	},
	{
		id = "tortoise",
		slot = "late",
		name = "Kaplumbağa",
		icon = "🐢",
		product = "Hediyelik Kabuk",
		price = 2200,
		income = 26,
		island = { name = "Kaplumbağa Adası", flavor = "Sakin lagün", perk = "offlineBonus", amount = 0.3 },
		zone = { name = "Kaplumbağa Lagünü", profile = "fold" },
		goods = { id = "tortoise_shell", name = "Hediyelik Kabuk", icon = "🐚", value = 660000, scale = 7000 },
		cash = {
			recipe = "tortoise_craft",
			recipeName = "Kabuk İşleme",
			factory = "tortoise_workshop",
			factoryName = "Kabuk Atölyesi",
		},
		center = {
			recipe = "tortoise_goods",
			recipeName = "Kabuk Toplama",
			building = "tortoise_vault",
			buildingName = "Kabuk Kasası",
		},
		seasons = { summer = 0.15, winter = -0.2 },
	},
}

local Species = {}
Species.SPECIES = SPECIES
Species.PROFILES = PROFILES
-- Elle yazılan yol haritası aşamaları (Islands.luau ROADMAP_STAGES: Ana Ada, Deniz, Tavuk, At, Keçi, Koyun, Domuz); türlerin ada aşamaları bunların arkasına eklenir.
-- Islands.luau sayıyı doğrular (uyuşmazlık açılışta hata verir).
Species.BASE_STAGES = 7

function Species.zoneId(row: SpeciesRow): string
	return `{row.id}_pen`
end

local function goodsCostFor(step: number, shares: { [string]: number }): Types.GoodsCostConfig
	return { step = step, shares = table.clone(shares) }
end

-- Bütün türlerden türeyen veri (bir kez hesaplanır; Animals/Islands/Goods/Production/Upgrades dosyaları kendi parçasını alır).
local built: any = nil
local function build()
	local animals: { [string]: Types.AnimalConfig } = {}
	local animalOrder: { string } = {}
	local zones: { [string]: Types.ZoneConfig } = {}
	local zoneOrder: { string } = {}
	local goods: { [string]: Types.GoodConfig } = {}
	local goodsOrder: { string } = {}
	local islands: { [string]: Types.FarmIslandConfig } = {}
	local islandOrder: { string } = {}
	local stages: { Types.RoadmapStage } = {}
	local upgrades: { Types.UpgradeConfig } = {}
	local recipes: { [string]: Types.ProductionRecipeConfig } = {}
	local recipeOrder: { string } = {}

	local nextStage = Species.BASE_STAGES
	for _, row in SPECIES do
		local profile = PROFILES[row.slot]
		local islandId = if row.island then row.id else "home"
		local stage = 3 -- ana ada fabrikaları (milk_factory gibi) 3. aşamada gösterilir
		if row.island then
			nextStage += 1
			stage = nextStage
		end
		animals[row.id] = {
			id = row.id,
			displayName = row.name,
			icon = row.icon,
			product = row.product,
			price = row.price,
			baseIncomePerSecond = row.income,
		}
		table.insert(animalOrder, row.id)
		goods[row.goods.id] = {
			id = row.goods.id,
			displayName = row.goods.name,
			icon = row.goods.icon,
			animalId = row.id,
			value = row.goods.value,
		}
		table.insert(goodsOrder, row.goods.id)

		local islandUpgradeId = `island_{row.id}`
		if row.island and row.zone then
			islands[row.id] = {
				id = row.id,
				displayName = row.island.name,
				icon = row.icon,
				trait = perkText(row.island),
				upgradeId = islandUpgradeId,
				animalId = row.id,
				buildUpgradeId = row.cash.factory,
				itemUpgradeId = row.center.building,
			}
			table.insert(islandOrder, row.id)
			stages[#stages + 1] = { name = row.island.name, island = row.id }
			zones[Species.zoneId(row)] = {
				id = Species.zoneId(row),
				displayName = row.zone.name,
				icon = row.icon,
				island = row.id,
				capacity = profile.capacity,
				allowedAnimals = { row.id },
				upgradeProfile = row.zone.profile,
			}
			table.insert(zoneOrder, Species.zoneId(row))
			local islandUpgrade: Types.UpgradeConfig = {
				id = islandUpgradeId,
				displayName = row.island.name,
				description = `{row.name} açılır · {perkText(row.island)}`,
				icon = row.icon,
				stage = stage,
				cost = profile.island.cost,
				requires = { profile.barn },
				kind = "island",
				goodsCost = goodsCostFor(profile.island.step, profile.island.shares),
				islandId = row.id,
			};
			-- Ada özelliği: mevcut etki anahtarı (yeni etki kodu yok)
			(islandUpgrade :: any)[row.island.perk] = row.island.amount
			table.insert(upgrades, islandUpgrade)
		end

		-- Para fabrikası (gelir artışı + parti üretimi) ve ürün merkezi: yalnızca kendi adasında/ana hayvanıyla kurulur
		local requiresFactory: { string } = if row.island then { islandUpgradeId } else { "milk_machine", "barn_3" }
		local factory: Types.UpgradeConfig = {
			id = row.cash.factory,
			displayName = row.cash.factoryName,
			description = if row.island
				then `{row.name} geliri +%{math.floor(profile.factory.boost * 100 + 0.5)} · {row.cash.recipeName}`
				else `Ana ada hayvanlarının geliri +%150 · {row.cash.recipeName}`,
			icon = row.icon,
			stage = stage,
			cost = profile.factory.cost,
			requires = requiresFactory,
			kind = "boost",
			goodsCost = goodsCostFor(profile.factory.step, profile.factory.shares),
			incomeBoost = if row.island then { [row.id] = profile.factory.boost } else { home = profile.factory.boost },
			island = islandId,
			homeAnimal = if row.island then nil else row.id,
		}
		table.insert(upgrades, factory)
		table.insert(
			upgrades,
			{
				id = row.center.building,
				displayName = row.center.buildingName,
				description = `Ürünü depoya topla; ahır deposuna {row.goods.name} ekler`,
				icon = row.goods.icon,
				stage = if row.island then stage else 1,
				cost = profile.center.cost,
				requires = if row.island then { islandUpgradeId } else { "barn_2" },
				kind = "boost",
				island = islandId,
				homeAnimal = if row.island then nil else row.id,
			} :: Types.UpgradeConfig
		)

		local options: { Types.ProductionOptionConfig } = {}
		for index, option in profile.cash.options do
			table.insert(options, {
				id = ({ "small", "medium", "large" })[index],
				displayName = ({ "Küçük parti", "Standart parti", "Büyük parti" })[index],
				requiredAdults = option.adults,
				duration = option.duration,
				reward = option.reward,
				returnMultiplier = option.returns,
			})
		end
		recipes[row.cash.recipe] = {
			id = row.cash.recipe,
			displayName = row.cash.recipeName,
			description = `{row.goods.name} ürünlerini işle ve kazancı topla.`,
			icon = row.goods.icon,
			island = islandId,
			upgradeId = row.cash.factory,
			animalId = row.id,
			animalIds = { row.id },
			requiredAdults = profile.cash.options[1].adults,
			duration = profile.cash.options[1].duration,
			cost = 0,
			reward = profile.cash.reward,
			output = "cash",
			upgradeProfile = "cashFactory",
			options = options,
		}
		recipes[row.center.recipe] = {
			id = row.center.recipe,
			displayName = row.center.recipeName,
			description = `{row.goods.name} topla ve ahır deposuna koy.`,
			icon = row.goods.icon,
			island = islandId,
			upgradeId = row.center.building,
			animalId = row.id,
			animalIds = { row.id },
			requiredAdults = profile.goods.adults,
			duration = profile.goods.duration,
			cost = profile.goods.cost,
			reward = row.goods.scale, -- tesis ölçeği (geliştirme fiyatı tabanı); ürünün birim değerinden bağımsız, böylece değer ayarı fiyat temposunu bozmaz
			output = "goods",
			goodsId = row.goods.id,
			goodsAmount = profile.goods.amount,
		}
		table.insert(recipeOrder, row.cash.recipe)
		table.insert(recipeOrder, row.center.recipe)
	end

	return {
		animals = animals,
		animalOrder = animalOrder,
		zones = zones,
		zoneOrder = zoneOrder,
		goods = goods,
		goodsOrder = goodsOrder,
		islands = islands,
		islandOrder = islandOrder,
		stages = stages,
		upgrades = upgrades,
		recipes = recipes,
		recipeOrder = recipeOrder,
	}
end

function Species.get()
	if not built then
		built = build()
	end
	return built
end

-- Mevsim/hava etkileri (Weather.luau mevcut tablolara ekler)
function Species.seasonModifiers(seasonId: string): { [string]: number }
	local result: { [string]: number } = {}
	for _, row in SPECIES do
		local value = (row.seasons :: any)[seasonId]
		if typeof(value) == "number" then
			result[row.id] = value
		end
	end
	return result
end

function Species.weatherModifiers(weatherId: string): { [string]: number }
	local result: { [string]: number } = {}
	for _, row in SPECIES do
		local value = if row.weather then (row.weather :: any)[weatherId] else nil
		if typeof(value) == "number" then
			result[row.id] = value
		end
	end
	return result
end

return Species
