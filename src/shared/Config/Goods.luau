--!strict
-- Ürünler (ahır deposu): ürün merkezlerinde (fabrikalar) üretilir, ahırdaki depoda birikir.
-- Ahır siparişleri (GOODS_CONTRACTS) bu depoyu tüketir; GOODS_SELL/GOODS_BARTER yığılmayı hızlı boşaltma ve takasla azaltır; `value` bir birimin para değeridir (dengeleme ve sipariş ödülü).
--
-- DEĞER KURALI (ürün değerleri hesapla bulunur, gelişigüzel yazılmaz): tam yükseltilmiş çiftlikte ürün merkezinin asgari parti getirisi
-- `(kaçırılan gelir + başlatma) x PRODUCTION_MIN_RETURN` (scripts/audit-economy.py bölüm D "taban") x ECONOMY_LIMITS.valueToFloor (~2,3; testte 1,8-3,2 bandı: tek ürün 1M gibi uçuk olmaz, en pahalısı ~130K).
-- Böylece (1) parti hep küçük sayıdır (taban miktar 2, en çok `PRODUCTION_MAX_BATCH_UNITS`), (2) asgari getiri miktarı şişirerek değil değerle sağlanır
-- (tek birim bile tabanı aşar), (3) sipariş ödülü (değer x 1,05-2) hem ürün değerine bağlı hem de geç oyunda anlamlıdır (sipariş payı sim'de ~%5).
-- Yeni ürün/hayvan eklerken ya da gelir dengesi değişirken bölüm D'yi çalıştır, değeri yeniden hesapla; `tests/goods.spec.luau` "ekonomi değişmezleri" korur.
-- Ürün merkezi tarifinin `reward` alanı (tesis ölçeği = geliştirme fiyatı tabanı) değerden bağımsızdır: değer ayarı fiyat temposunu bozmaz.
-- Gizli bilgi koyma: ReplicatedStorage client'a da gider.

local Types = require(script.Parent:WaitForChild("Types"))
local Species = require(script.Parent:WaitForChild("Species"))

local data = {
	GOODS = {
		milk = { id = "milk", displayName = "Süt", icon = "🥛", animalId = "cow", value = 7100 },
		egg = { id = "egg", displayName = "Yumurta", icon = "🥚", animalId = "chicken", value = 14000 },
		down = { id = "down", displayName = "Tüy", icon = "🪶", animalId = "duck", value = 38000 },
		cheese = { id = "cheese", displayName = "Peynir", icon = "🧀", animalId = "goat", value = 92000 },
		wool = { id = "wool", displayName = "Yün", icon = "🧶", animalId = "sheep", value = 45000 },
		meat = { id = "meat", displayName = "Et", icon = "🥩", animalId = "pig", value = 130000 },
		horseshoe = { id = "horseshoe", displayName = "Nal", icon = "🧲", animalId = "horse", value = 15000 },
		fish = { id = "fish", displayName = "Balık", icon = "🐟", animalId = "seabass", value = 18000 },
	} :: { [string]: Types.GoodConfig },

	-- Depo ve arayüzde gösterim sırası (hayvan türlerinin sırasıyla aynı)
	GOODS_ORDER = { "milk", "egg", "down", "cheese", "wool", "meat", "horseshoe", "fish" },

	-- Ahır siparişleri: pano `seconds` saniyede bir yenilenir; 8 kademe (1-6 ürün çeşidi; "toptan" tek üründen çok ister). Satır başına birim sayısı
	-- kademe değeridir (`units`, ± `variation`; pahalı üründe küçülür), depo büyüklüğüne ya da gelire bağlı DEĞİL: sayılar küçük kalır (satır en çok `maxLineUnits`).
	-- Brüt ödül = ürünlerin değeri x kademe çarpanı x sipariş bonusu; ödeme referans gelirin rewardCapMinutes sınırını aşamaz. Ürün
	-- değerleri (aşağıda, `GOODS`/`Species`) ürün merkezi partisinin asgari getirisine göre ölçülüdür (`scripts/audit-economy.py` bölüm D),
	-- bu yüzden küçük sayılar geç oyunda da anlamlı para eder.
	GOODS_CONTRACTS = {
		seconds = 420,
		-- Pano ızgara biçimindedir: her pencerede `slots` teklif, her biri ağırlıklı rastgele kademe + rastgele ürünler
		-- (pencere numarası ve sıra ile türetilir; sunucu ve client aynı sonucu bulur). Birim sayısı kademe değerinin
		-- ± variation oranında değişir.
		slots = 12,
		-- `slots` YALNIZ üst sınırdır: panodaki teklif sayısı şu an üretilebilen ürün sayısına bağlıdır (`ceil(ürün x slotsPerGoods)`, en az `minSlots`,
		-- en çok `slots`). Az üründe 12 teklif az çeşide yığılıp ürün başına talebi şişiriyordu (1 ürün 6, 2+ ürün 12). 4/4 (1 ürün 4, 2 ürün 8) denendi: idle oyuncuda Tema 2 süresi Tema 1'e eşitlenip simulate-tiers monotonluğunu bozdu, 6/6 bozmaz.
		slotsPerGoods = 6,
		minSlots = 6,
		-- Toplam sipariş bonusu (eşya + ada + yükseltme + kalıcı etki + kilometre taşı + mevsim) bu değeri aşamaz: en yüksek kademe (rewardFactor 2) x (1 + 0,6)
		-- = 3,2 = ECONOMY_LIMITS.maxRewardRatio; yani bonuslar dahil de ödül/değer sınırı korunur (tests/contracts.spec "bonus tavanı").
		maxBonus = 0.6,
		-- Pano başına ödeme bütçesi (referans gelirin dakikası): penceredeki tekliflerin ödül toplamı bunu aşmaz (slot sırasıyla, sığmayan teklif panoya girmez; ilk teklif
		-- her zaman kalır). Ürün değeri TAM yükseltilmiş çiftliğe göre ölçülü olduğundan erken evrede pano gelirin katlarıydı (ilk saat siparişler gelirin ~%60'ı).
		-- Bütçe evreye bağlıdır: referans gelir (sn başına) `lowIncome` ve altındaysa `lowMinutes`, `highIncome` ve üstündeyse `highMinutes` (log ölçekte `curve` üssüyle
		-- artar). `graceIncome` (sn başına) altında bütçe yoktur: ilk ürün merkezlerinin kurulum evresinde (hardcore ~ilk 40 dk) erken ilerleme siparişlerle hızlanır, keçi adası ~55 dk'da açılır; bu eşiği ~950'ye çekmek keçi adasını 45,5 dk'ya iter ama ilk saat payı ~%52'ye çıkar. Tam yükseltilmiş çiftlikte pano toplamı ~5-6 dk olduğundan `highMinutes` orada bağlamaz. Ölçüm: docs/URETIM_VE_UZMAN_ADALAR.md "Sipariş bütçesi".
		windowBudget = {
			lowMinutes = 2.5,
			highMinutes = 12,
			lowIncome = 500,
			highIncome = 5000,
			curve = 2,
			graceIncome = 900,
		},
		guaranteedTier = "quick", -- her üretilebilir ürün için bir erişilebilir teklif; kalan slotlar ağırlıklı dağıtılır
		reserveBatches = 2, -- ürün yardımcısı kalan siparişler ve bu kadar yedek parti için üretir
		variation = 0.34,
		-- Pahalı üründe satır birimi `unitRefValue / değer` ile küçülür (en az 1): tek satırın değeri ürünler arasında benzer kalır.
		unitRefValue = 15000,
		-- Bir satırın adet aralığının ÜST sınırının tabanı: her kademede ve pahalı üründe de 1..4 birim istenebilir (kademenin `units` değeri bu
		-- yüzden yalnızca ucuz üründe toptan/tüccar toptan kademelerini büyütür; hızlı/küçük aynı aralıktadır). Gelir tavanı aşılıyorsa önce adet
		-- düşürülür, tek birim de pahalıysa ödül sınırlanır.
		minHighUnits = 4,
		-- Bir siparişin ödülü gelirin en çok bu kadar dakikasıdır (ECONOMY_LIMITS.maxRewardMinutes'tan küçük: test sınırı aşılmaz).
		-- Sınır TEK SİPARİŞ içindir; pano toplamını (12 slot) sınırlamaz: ürün değeri tam yükseltilmiş çiftliğe göre ölçülü olduğundan erken evrede
		-- (ilk ürün merkezleri) pano geliri çiftlik gelirinin katlarına çıkabilir, bkz. docs/URETIM_VE_UZMAN_ADALAR.md "Denetim (5 Ekim 2026)".
		rewardCapMinutes = 6,
		-- Bir satırdaki en çok birim (okunabilirlik); en küçük ahır deposu (BARN_LEVELS[1].goodsCap) bundan küçük olamaz (tests/goods.spec)
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
	-- Oran ürün değerinin asgari getiriye göre ölçeğini yansıtır: tam parti (6 birim) satılınca kaçırılan gelir + başlatmanın ~1,1 katı gelir (ölçüm:
	-- scripts/audit-economy.py bölüm F); taban partide (2 birim) yalnızca ~%37'si: ürünün değeri siparişle çıkar, satış taşan fazlanın çıkışıdır.
	GOODS_SELL = {
		rate = 0.06,
	},

	-- Ürünle takas ("Ürünle satın al"): depodaki ürünler, değerinin `rate` katı üzerinden hayvan fiyatına sayılır. Oran satış oranını
	-- AŞAMAZ (ürünü satıp hayvan almaktan daha kârlı olmasın; config.spec denetler): takas yalnızca tek adımlık kolaylıktır.
	GOODS_BARTER = {
		rate = 0.06,
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
