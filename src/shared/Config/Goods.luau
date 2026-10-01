--!strict
-- Ürünler (ahır deposu): ürün merkezlerinde (fabrikalar) üretilir, ahırdaki depoda birikir.
-- Ahır siparişleri (GOODS_CONTRACTS) bu depoyu tüketir; GOODS_SELL/GOODS_BARTER yığılmayı hızlı boşaltma ve takasla azaltır; `value` bir birimin para değeridir (dengeleme ve sipariş ödülü).
--
-- DEĞER KURALI (ürün değerleri hesapla bulunur, gelişigüzel yazılmaz): tam yükseltilmiş çiftlikte ürün merkezinin asgari parti getirisi
-- `(kaçırılan gelir + başlatma) x PRODUCTION_MIN_RETURN` (scripts/audit-economy.py bölüm D "taban") x ECONOMY_LIMITS.valueToFloor (~9; testte 6-14 bandı).
-- Böylece (1) parti hep küçük sayıdır (taban miktar 2, en çok `PRODUCTION_MAX_BATCH_UNITS`), (2) asgari getiri miktarı şişirerek değil değerle sağlanır
-- (tek birim bile tabanı aşar), (3) sipariş ödülü (değer x 1,05-2) hem ürün değerine bağlı hem de geç oyunda anlamlıdır (sipariş payı sim'de ~%9).
-- Yeni ürün/hayvan eklerken ya da gelir dengesi değişirken bölüm D'yi çalıştır, değeri yeniden hesapla; `tests/goods.spec.luau` "ekonomi değişmezleri" korur.
-- Ürün merkezi tarifinin `reward` alanı (tesis ölçeği = geliştirme fiyatı tabanı) değerden bağımsızdır: değer ayarı fiyat temposunu bozmaz.
-- Gizli bilgi koyma: ReplicatedStorage client'a da gider.

local Types = require(script.Parent:WaitForChild("Types"))
local Species = require(script.Parent:WaitForChild("Species"))

local data = {
	GOODS = {
		milk = { id = "milk", displayName = "Süt", icon = "🥛", animalId = "cow", value = 43000 },
		egg = { id = "egg", displayName = "Yumurta", icon = "🥚", animalId = "chicken", value = 82000 },
		down = { id = "down", displayName = "Tüy", icon = "🪶", animalId = "duck", value = 230000 },
		cheese = { id = "cheese", displayName = "Peynir", icon = "🧀", animalId = "goat", value = 550000 },
		wool = { id = "wool", displayName = "Yün", icon = "🧶", animalId = "sheep", value = 270000 },
		meat = { id = "meat", displayName = "Et", icon = "🥩", animalId = "pig", value = 750000 },
		horseshoe = { id = "horseshoe", displayName = "Nal", icon = "🧲", animalId = "horse", value = 90000 },
		fish = { id = "fish", displayName = "Balık", icon = "🐟", animalId = "seabass", value = 110000 },
	} :: { [string]: Types.GoodConfig },

	-- Depo ve arayüzde gösterim sırası (hayvan türlerinin sırasıyla aynı)
	GOODS_ORDER = { "milk", "egg", "down", "cheese", "wool", "meat", "horseshoe", "fish" },

	-- Ahır siparişleri: pano `seconds` saniyede bir yenilenir; 8 kademe (1-6 ürün çeşidi; "toptan" tek üründen çok ister). Satır başına birim sayısı
	-- kademe değeridir (`units`, ± `variation`; pahalı üründe küçülür), depo büyüklüğüne ya da gelire bağlı DEĞİL: sayılar küçük kalır (satır en çok `maxLineUnits`).
	-- Ödül = ürünlerin değeri x kademe çarpanı (`rewardFactor` 1,05-2) x sipariş bonusu; oyuncunun gelirine bağlı bir taban yoktur. Ürün
	-- değerleri (aşağıda, `GOODS`/`Species`) ürün merkezi partisinin asgari getirisine göre ölçülüdür (`scripts/audit-economy.py` bölüm D),
	-- bu yüzden küçük sayılar geç oyunda da anlamlı para eder.
	GOODS_CONTRACTS = {
		seconds = 420,
		-- Pano ızgara biçimindedir: her pencerede `slots` teklif, her biri ağırlıklı rastgele kademe + rastgele ürünler
		-- (pencere numarası ve sıra ile türetilir; sunucu ve client aynı sonucu bulur). Birim sayısı kademe değerinin
		-- ± variation oranında değişir.
		slots = 12,
		variation = 0.34,
		-- Pahalı üründe satır birimi `unitRefValue / değer` ile küçülür (en az 1): tek satırın değeri ürünler arasında benzer kalır.
		unitRefValue = 60000,
		-- Bir satırdaki en çok birim (okunabilirlik)
		-- Her satırın en az bu kadar adede kadar çıkabilmesi (pahalı üründe de 1-3 arası rastgele); ödül gelir tavanını (aşağıdaki) aşarsa adet düşer
		minHighUnits = 3,
		-- Bir siparişin ödülü gelirin en çok bu kadar dakikasıdır (ECONOMY_LIMITS.maxRewardMinutes'tan küçük: test sınırı aşılmaz)
		rewardCapMinutes = 12,
		maxLineUnits = 12,
		tiers = {
			{
				id = "quick",
				displayName = "Hızlı",
				lines = 1,
				units = 1,
				rewardFactor = 1.05,
				weight = 3,
			},
			{
				id = "small",
				displayName = "Küçük",
				lines = 1,
				units = 2,
				rewardFactor = 1.1,
				weight = 3,
			},
			{
				id = "medium",
				displayName = "Orta",
				lines = 2,
				units = 2,
				rewardFactor = 1.25,
				weight = 2,
			},
			{
				id = "bulk",
				displayName = "Toptan",
				lines = 1,
				units = 4,
				rewardFactor = 1.3,
				weight = 1.5,
			},
			{
				id = "large",
				displayName = "Büyük",
				lines = 3,
				units = 2,
				rewardFactor = 1.5,
				weight = 1,
			},
			{
				id = "grand",
				displayName = "Dev",
				lines = 4,
				units = 2,
				rewardFactor = 1.7,
				weight = 0.7,
			},
			{
				id = "wholesale",
				displayName = "Tüccar Toptan",
				lines = 1,
				units = 5,
				rewardFactor = 1.4,
				weight = 0.9,
			},
			{
				id = "mega",
				displayName = "Dev Karma",
				lines = 6,
				units = 2,
				rewardFactor = 2,
				weight = 0.4,
			},
		} :: { Types.GoodsContractTierConfig },
	},

	-- Ahır deposu uyarısı: bir ürün kapasitenin bu oranına ulaşınca Envanter menüsünde rozet ve hedef kartında "dolmak üzere" satırı çıkar
	-- (üretim zaten yer yoksa başlamaz; oyuncu görmeden takılı kalmasın).
	GOODS_FULL_WARNING = 0.9,

	-- Hızlı boşaltma ("Hepsini sat" / "Yarısını sat"): depodaki ürün, değerinin `rate` katına paraya çevrilir. Sipariş ödülü her zaman en az
	-- değer x 1.05 olduğundan sipariş hâlâ en iyi seçenektir; üretimin depoya sığmayan fazlası da aynı oranla paraya çevrilir (kaçak olmasın).
	-- Oran ürün değerinin asgari getiriye göre ölçeğini yansıtır: bir parti (2 birim) satılınca ~asgari getiri (PRODUCTION_MIN_RETURN) kadar para gelir.
	GOODS_SELL = {
		rate = 0.015,
	},

	-- Ürünle takas ("Ürünle satın al"): depodaki ürünler, değerinin `rate` katı üzerinden hayvan fiyatına sayılır. Oran satış oranını
	-- AŞAMAZ (ürünü satıp hayvan almaktan daha kârlı olmasın; config.spec denetler): takas yalnızca tek adımlık kolaylıktır.
	GOODS_BARTER = {
		rate = 0.015,
	},
}

-- Hayvan türü tablosundan gelen ürünler (Config/Species.luau)
local species = Species.get()
for id, good in species.goods do
	data.GOODS[id] = good
end
for _, id in species.goodsOrder do
	table.insert(data.GOODS_ORDER, id)
end

return data
