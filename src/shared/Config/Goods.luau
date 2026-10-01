--!strict
-- Ürünler (ahır deposu): ürün merkezlerinde (fabrikalar) üretilir, ahırdaki depoda birikir.
-- Ahır siparişleri (GOODS_CONTRACTS) bu depoyu tüketir; GOODS_SELL/GOODS_BARTER yığılmayı hızlı boşaltma ve takasla azaltır; `value` bir birimin para değeridir (dengeleme ve sipariş ödülü).
-- Gizli bilgi koyma: ReplicatedStorage client'a da gider.

local Types = require(script.Parent:WaitForChild("Types"))
return {
	GOODS = {
		milk = { id = "milk", displayName = "Süt", icon = "🥛", animalId = "cow", value = 250 },
		egg = { id = "egg", displayName = "Yumurta", icon = "🥚", animalId = "chicken", value = 480 },
		down = { id = "down", displayName = "Tüy", icon = "🪶", animalId = "duck", value = 800 },
		cheese = { id = "cheese", displayName = "Peynir", icon = "🧀", animalId = "goat", value = 5500 },
		wool = { id = "wool", displayName = "Yün", icon = "🧶", animalId = "sheep", value = 2000 },
		meat = { id = "meat", displayName = "Et", icon = "🥩", animalId = "pig", value = 9000 },
		horseshoe = { id = "horseshoe", displayName = "Nal", icon = "🧲", animalId = "horse", value = 1300 },
		fish = { id = "fish", displayName = "Balık", icon = "🐟", animalId = "seabass", value = 500 },
	} :: { [string]: Types.GoodConfig },

	-- Depo ve arayüzde gösterim sırası (hayvan türlerinin sırasıyla aynı)
	GOODS_ORDER = { "milk", "egg", "down", "cheese", "wool", "meat", "horseshoe", "fish" },

	-- Ahır siparişleri: pano `seconds` saniyede bir yenilenir; 8 kademe (1-6 ürün çeşidi; "toptan" tek üründen çok ister). Birim sayısı kademe tabanı (`units`)
	-- ile ahır deposu kapasitesinin payının (`capShare`) büyüğüdür: depo büyüdükçe (ahır yükseltme, ek çiftlik) siparişler de büyür, ürün yığılmaz.
	-- Ucuz üründe pay tam, pahalı üründe `unitRefValue / değer` ile küçülür (sipariş değeri ürünler arasında benzer kalır). Ürün merkezi zaten kaçırılan
	-- gelirin üstünde ürün verdiği için çarpan küçüktür; büyük sipariş ürün başına daha çok öder (daha çok çeşit = daha çok emek).
	GOODS_CONTRACTS = {
		seconds = 420,
		-- Pano ızgara biçimindedir: her pencerede `slots` teklif, her biri ağırlıklı rastgele kademe + rastgele ürünler
		-- (pencere numarası ve sıra ile türetilir; sunucu ve client aynı sonucu bulur). Birim sayısı kademe değerinin
		-- ± variation oranında değişir.
		slots = 12,
		variation = 0.34,
		-- Ödül tabanı: etkin çiftliğin geliri x bu süre (sn) x (siparişin ağırlığı / floorWeight). Ağırlık = Σ birim x min(ürün değeri, unitRefValue);
		-- floorWeight = referans siparişin (3 birim x unitRefValue) ağırlığı: o boyutta taban eski "gelir x süre" ile aynıdır, büyük sipariş orantılı artar.
		-- Ödül = max(ürün değeri, taban) x kademe çarpanı x bonus.
		incomeSeconds = 110,
		floorWeight = 2400,
		unitRefValue = 800,
		-- Bir satırdaki en çok birim (okunabilirlik; "20-30 adetlik toptan" tavanı)
		maxLineUnits = 30,
		tiers = {
			{
				id = "quick",
				displayName = "Hızlı",
				lines = 1,
				units = 2,
				capShare = 0.08,
				rewardFactor = 1.05,
				weight = 3,
			},
			{
				id = "small",
				displayName = "Küçük",
				lines = 1,
				units = 3,
				capShare = 0.12,
				rewardFactor = 1.1,
				weight = 3,
			},
			{
				id = "medium",
				displayName = "Orta",
				lines = 2,
				units = 3,
				capShare = 0.12,
				rewardFactor = 1.25,
				weight = 2,
			},
			{
				id = "bulk",
				displayName = "Toptan",
				lines = 1,
				units = 6,
				capShare = 0.25,
				rewardFactor = 1.3,
				weight = 1.5,
			},
			{
				id = "large",
				displayName = "Büyük",
				lines = 3,
				units = 4,
				capShare = 0.15,
				rewardFactor = 1.5,
				weight = 1,
			},
			{
				id = "grand",
				displayName = "Dev",
				lines = 4,
				units = 3,
				capShare = 0.15,
				rewardFactor = 1.7,
				weight = 0.7,
			},
			{
				id = "wholesale",
				displayName = "Tüccar Toptan",
				lines = 1,
				units = 8,
				capShare = 0.35,
				rewardFactor = 1.4,
				weight = 0.9,
			},
			{
				id = "mega",
				displayName = "Dev Karma",
				lines = 6,
				units = 3,
				capShare = 0.12,
				rewardFactor = 2,
				weight = 0.4,
			},
		} :: { Types.GoodsContractTierConfig },
	},

	-- Hızlı boşaltma ("Hepsini sat" / "Yarısını sat"): depodaki ürün, değerinin `rate` katına paraya çevrilir. Sipariş ödülü her zaman en az
	-- değer x 1.05 olduğundan sipariş hâlâ en iyi seçenektir; üretimin depoya sığmayan fazlası da aynı oranla paraya çevrilir (kaçak olmasın).
	GOODS_SELL = {
		rate = 0.5,
	},

	-- Ürünle takas ("Ürünle satın al"): depodaki ürünler, değerinin `rate` katı üzerinden hayvan fiyatına sayılır. Oran satış oranını
	-- AŞAMAZ (ürünü satıp hayvan almaktan daha kârlı olmasın; config.spec denetler): takas yalnızca tek adımlık kolaylıktır.
	GOODS_BARTER = {
		rate = 0.5,
	},
}
