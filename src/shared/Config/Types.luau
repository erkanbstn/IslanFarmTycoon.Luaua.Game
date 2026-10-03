--!strict
-- Config tablolarının tip tanımları (Config/init.luau bunları yeniden dışa aktarır).

export type ZoneConfig = {
	id: string,
	displayName: string,
	icon: string,
	island: string, -- Hangi çiftlik adasında (FARM_ISLANDS id)
	capacity: number,
	allowedAnimals: { string },
	upgradeProfile: string?, -- BUILD_UPGRADES.profiles anahtarı (yoksa "barn")
	themed: boolean?, -- true: bölgenin hayvanı temanın ana ada hayvanıdır (homeAnimal)
}

-- Yapı geliştirme: her bölge (ahır, ağıl, kafes) ve her üretim tesisi 5 seviyelik bir yoldur; her seviye işlevine uygun bir fayda demeti verir.
-- Bölge: capacity (adım sayısı), growthSpeed (çarpan), incomeBonus (toplanır), seasonAffinity (olumlu mevsim/hava etkileri büyür, olumsuzlar küçülür).
-- Tesis: speed (süre çarpanı), yield (satış ödülü artışı), thrift (başlatma maliyeti indirimi).
export type BuildLevelEffects = {
	capacity: number?,
	growthSpeed: number?,
	incomeBonus: number?,
	seasonAffinity: number?,
	speed: number?,
	yield: number?,
	thrift: number?,
}

-- Para tesisinin parti seçeneği: kaç yetişkin hayvan ister, ne kadar sürer, ne öder (başlatma ücretsizdir).
-- Daha çok hayvan isteyen seçenek hayvan başına daha çok kazandırır; returnMultiplier kaçırılan gelirin en az kaç katı ödeneceğidir.
export type ProductionOptionConfig = {
	id: string,
	displayName: string,
	requiredAdults: number,
	duration: number,
	reward: number,
	returnMultiplier: number,
}

export type ProductionRecipeConfig = {
	id: string,
	displayName: string,
	description: string,
	icon: string,
	island: string,
	upgradeId: string,
	animalId: string,
	animalIds: { string },
	requiredAdults: number,
	duration: number,
	cost: number,
	reward: number,
	output: "cash" | "chicken" | "goods", -- "goods": ahır deposuna ürün (goodsId/goodsAmount)
	goodsId: string?, -- output == "goods": Config.GOODS anahtarı
	goodsAmount: number?, -- output == "goods": temel ürün miktarı (yetişkin bonusu/tesis verimi ve ödül tabanı uygulanır)
	upgradeProfile: string?, -- BUILD_UPGRADES.profiles anahtarı (yoksa "factory")
	optionId: string?, -- yalnızca FarmMath.resolveRecipe kopyalarında: seçilen parti
	returnMultiplier: number?, -- yalnızca çözülmüş kopyalarda: seçilen partinin ödül tabanı çarpanı
	options: { ProductionOptionConfig }?, -- para tesisi: parti seçenekleri (ilki varsayılan); yoksa tarifin kendi alanları geçerli
}

export type AnimalConfig = {
	id: string,
	displayName: string,
	icon: string,
	product: string, -- Ürettiği şey (arayüzde gösterilir)
	price: number, -- İlk hayvanın fiyatı; her sahip olunan aynı türle ANIMAL_PRICE_GROWTH kadar artar
	baseIncomePerSecond: number,
}

-- Ahır siparişi kademesi: kaç farklı ürün (lines) ve her üründen kaç birim (units, ± variation) ister. Ödül FarmMath/Contracts.reward ile
-- ürün değeri x rewardFactor (gelire bağlı değil).
export type GoodsContractTierConfig = {
	id: string,
	displayName: string,
	lines: number,
	units: number,
	rewardFactor: number,
	weight: number, -- Panoda çıkma ağırlığı (büyüğü seyrek)
}

export type GoodConfig = {
	id: string,
	displayName: string,
	icon: string,
	animalId: string, -- ürünü veren hayvan türü
	value: number, -- bir birimin para değeri (dengeleme; sipariş ödülü)
}

export type BarnLevelConfig = {
	level: number,
	displayName: string,
	barnScale: number,
	storageCap: number, -- Depoda birikebilecek en fazla para
	goodsCap: number, -- Ahır deposunda her ürün türünden biriktirilebilecek en fazla miktar
	incomeMultiplier: number, -- Tüm gelire uygulanır
}

-- Oyuncunun takımadasındaki adalar. "home" herkese ücretsiz; diğerleri yol haritasından açılır
-- ve her biri yeni bir hayvanı + kendine özel bir bonusu getirir.
-- Ada teması: her ana çiftlik numarasının (= fiziksel ada numarası) kendi 3 küçük adası vardır.
-- satellites sırası = harita yuvası sırası (erken, orta, geç); hepsi FARM_ISLANDS'ta tanımlı olmalıdır.
-- Balık görünümü (çiftliğe göre değişir): oyun mantığı/fiyat `anchovy` (küçük) ve `seabass` (büyük) kimliklerinde kalır, görünen ad/simge/ürün
-- adı ve model çiftlik temasına göre değişir. id = model dosyası (assets/Animals/<id>.rbxmx).
export type FishSkin = { id: string, displayName: string, icon: string, product: string }

export type ThemeConfig = {
	id: string,
	displayName: string,
	homeAnimal: string, -- Ana adanın ağıl ve otlağında yaşayan hayvan
	landmark: string, -- Ana adada doğu kıyıdaki tema işaret yapısı (HomeBuildings.landmark türü)
	satellites: { string }, -- Çiftliğin 3 küçük adası (FARM_ISLANDS id); her adada tek hayvan yaşar (FARM_ISLANDS[ada].animalId)
	fish: { [string]: FishSkin }?, -- anchovy (küçük) / seabass (büyük) balığın bu çiftlikteki görünümü; yoksa ANIMALS'taki varsayılan (Hamsi/Levrek)
}

-- Çiftlik zorluğu (Config/Difficulty.luau): tier = çiftliğin alım sırası (1..MAIN_FARM_LIMIT).
export type DifficultyTier = {
	tier: number,
	targetMinutes: number, -- Çiftlik tek başına, ideal oyuncu tüm yükseltmeleri bu sürede (dk) bitirir
	costMultiplier: number, -- Yükseltme, hayvan ve yapı geliştirme fiyatlarını çarpar
	maxPrice: number, -- Bu çiftlikteki en pahalı tek kalemin tavanı (uçuk büyüklük denetimi; oyun mantığında kullanılmaz)
}
-- Ada açılış primi: prim = 1 + perTier x (tier - 1) ^ power. Çiftlik 2+'da ilk ada alınır alınmaz açılmasın, orta/geç ada kademeyle birlikte geç açılsın
-- (Çiftlik 1'in ~%4 / %16 / %42 ritmi: ilk / orta / geç ada tamamlama süresinin payı olarak). Tier 1'de prim yoktur.
export type DifficultyPremium = { perTier: number, power: number }
export type DifficultyConfig = {
	referenceMinutes: number,
	timeGrowth: number,
	tiers: { DifficultyTier },
	slotSpread: number, -- Ada sırası çarpanı: 1 + slotSpread x (tier - 1) x (sıra - 1)
	islandPremium: { DifficultyPremium }, -- Ada AÇILIŞ bedeli primi (ritim): sıra (erken/orta/geç ada) başına; yalnızca "island" yükseltmesini çarpar
	animalGrowthPerTier: number, -- Hayvan n. alım eğrisine çiftlik başına eklenen pay
	goods: DifficultyGoods,
}
-- Açılış gereksinimi (ürün) miktarı: değer payı x stepBase[adım] x (1 + tierGrowth x (tier - 1)) / ürün birim değeri, kapasiteye sığar.
export type DifficultyGoods = {
	stepBase: { number }, -- adım (1 erken, 2 orta, 3 geç) çarpanı
	tierGrowth: number, -- kademe başına artış
	tutorialSteps: number, -- Çiftlik 1'de bu adıma kadar (1 erken, 2 orta, 3 geç) açılışlar ürün istemez (öğretici; 0 = hepsi ister)
	capShare: number, -- bir ürün kalemi, açılışın gerektirdiği ahır seviyesinin ürün kapasitesinin en çok bu payı olur (deadlock olmasın)
}

-- Eşyalar (envanter): slotlara takılır, satın alma kalıcıdır. effects = takılıyken geçerli kalıcı faydalar (FarmMath),
-- power = asa gücü (Inventory), look = karakterde görünen modelin bağlanma noktası (InventoryService). Vector3 yerine düz {x, y, z} tabloları.
export type ItemSlotConfig = { id: string, displayName: string, icon: string }
export type ItemLook = { attach: string } -- attach: head | back | hip | chest | hand (geometri `assets/Items/<id>` modelindedir)
export type ItemEffects = {
	upgradeDiscount: number?, -- Bütün yükseltme maliyetlerinden indirim (0.1 = %10)
	storageBonus: number?, -- Depo kapasitesi (0.15 = +%15)
	growthSpeed: number?, -- Büyüme hızı çarpanı (1.15 = %15 daha hızlı)
	incomeBonus: number?, -- Bütün gelir (0.03 = +%3)
	contractBonus: number?, -- Ahır siparişi ödülü (0.06 = +%6)
	goodsYield: number?, -- Ürün merkezlerinin teslim miktarı (0.1 = +%10)
	facilitySpeed: number?, -- Üretim tesisi süreleri kısalır (0.05 = %5)
	sellBonus: number?, -- Hayvan satış geliri (0.05 = +%5)
	offlineBonus: number?, -- Çevrimdışı kazanç (0.1 = +%10)
	expansionDiscount: number?, -- Bölge/tesis geliştirme maliyeti indirimi (0.03 = -%3)
}
export type ItemPower = { kind: string, usesPerDay: number? } -- kind: season | weather; usesPerDay nil = sınırsız
export type ItemConfig = {
	id: string,
	displayName: string,
	icon: string,
	slot: string,
	price: number,
	effects: ItemEffects?,
	power: ItemPower?,
	look: ItemLook?,
}

export type FarmIslandConfig = {
	id: string,
	displayName: string,
	icon: string,
	trait: string, -- Adanın özelliği (tabelada ve arayüzde yazar)
	upgradeId: string?, -- Adayı açan yol haritası öğesi (home için nil)
	animalId: string?, -- Adada yaşayan tek hayvan türü (home için nil: ana adada çiftliğin ana hayvanı yaşar); hayvan -> ada eşlemesi buradan türer
	buildUpgradeId: string?, -- Haritada adanın yapı noktasına (SATELLITE_TYPES.buildSpot) kurulan para fabrikası/güçlendirme yükseltmesi
	itemUpgradeId: string?, -- Adanın ürün merkezi yükseltmesi (SATELLITE_TYPES.itemSpot)
}

-- Mevsim ve hava: hayvan türlerine göre gelir değişimi (0.2 = +%20, -0.1 = -%10)
export type SeasonConfig = {
	id: string,
	displayName: string,
	icon: string,
	incomeModifiers: { [string]: number },
	weather: { [string]: number }, -- Bu mevsimde görülebilecek havalar ve ağırlıkları
	eventName: string?, -- Mevsim etkinliği adı (sipariş ödülüne bonus verir)
	orderBonus: number?, -- Sipariş ödülü bonusu (0.3 = +%30)
	grassColor: Color3,
}

export type WeatherConfig = {
	id: string,
	displayName: string,
	icon: string,
	incomeModifiers: { [string]: number },
}

-- Yol haritası aşaması: bir adaya (island) ya da bağımsız bir dala (ör. Deniz) ait olabilir
export type RoadmapStage = {
	name: string,
	island: string?, -- FARM_ISLANDS id; varsa arayüz adanın özelliğini gösterir
	description: string?, -- Adası olmayan aşamanın açıklaması
}

-- Açılış gereksinimi (ürün): para fiyatının yanında ahır deposundan ürün düşer. `shares[kaynak]` = temel para fiyatının bu payı kadar DEĞERDE
-- (ürün birim değeri `Config.GOODS[x].value`) ürün; kaynak ürünü temaya göre çözülür (`Config.resolveGoodsSource`): "home" (çiftliğin ana hayvanının
-- ürünü), "sea" (balık), "slot1".."slot3" (temanın o sıradaki küçük adasının ürünü), "previous" (bu öğenin adasından bir önceki ada; ilk adada ve
-- ana adada ana hayvanın ürünü). `step`: adım (1 erken, 2 orta, 3 geç ada/aşama); miktar kademe ve adıma göre `FarmMath.getGoodsCost`.
export type GoodsCostConfig = {
	step: number,
	shares: { [string]: number },
}

-- Yol haritasındaki satın alınabilir her şey. Oyuncu sırayı kendisi seçer;
-- sadece "requires" içindekilere önce sahip olmak gerekir.
export type UpgradeConfig = {
	id: string,
	displayName: string,
	description: string,
	icon: string,
	stage: number, -- Yol haritasında hangi aşamada (ROADMAP_STAGES) gösterilir
	cost: number,
	requires: { string },
	kind: string, -- "barn" | "zone" | "island" | "boost" | "extension" | "level"
	leveled: boolean?, -- kind == "level": seviyeli zincir; yol haritası "tamamlandı" sayımına girmez
	barnLevel: number?, -- kind == "barn"
	zoneId: string?, -- kind == "zone"
	islandId: string?, -- kind == "island"
	incomeBoost: { [string]: number }?, -- animalId -> ek gelir (0.5 = +%50)
	growthSpeed: number?, -- Tüm hayvanların büyüme hızı çarpanı
	growthBoost: { [string]: number }?, -- animalId -> büyüme hızı çarpanı
	storageBonus: number?, -- Depo kapasitesine ek (0.25 = +%25)
	-- Genel kalıcı fayda anahtarları (yükseltme alınınca geçerli; takılı eşya etkileriyle toplanır: Core.getBonus)
	facilitySpeed: number?, -- Üretim tesisi süreleri kısalır (0.12 = %12)
	contractBonus: number?, -- Ahır siparişi ödülü (0.08 = +%8)
	goodsYield: number?, -- Ürün merkezi teslim miktarı (0.1 = +%10)
	sellBonus: number?, -- Hayvan satış geliri (0.15 = +%15)
	offlineBonus: number?, -- Çevrimdışı kazanç (0.25 = +%25)
	expansionDiscount: number?, -- Bölge/tesis geliştirme maliyeti indirimi (0.08 = -%8)
	autoCollect: boolean?, -- Depo yerine para doğrudan kasaya
	extensionId: string?, -- kind == "extension" → Config.EXTENSIONS; kind == "level" ile eklenti kapasite yükseltmesi
	extensionCapacity: number?, -- Eklenti kapasite yükseltmesi: +1 hayvan (kind == "level", extensionId ile)
	goodsCost: GoodsCostConfig?, -- Açılış gereksinimi: para + ürün (Config/Difficulty.luau, FarmMath.getGoodsCost)
	island: string?, -- Yükseltmenin adası (verilmezse Config.getUpgradeIsland ada/bölge/aşamadan bulur)
	homeAnimal: string?, -- Ana ada fabrikası: yalnızca ana hayvanı (THEMES.homeAnimal) bu olan çiftliklerde vardır (Config.upgradeInTheme)
}

export type AchievementConfig = {
	id: string,
	displayName: string,
	description: string,
	icon: string,
	metric: string, -- "home" (çiftliğin ana ada hayvanı) | "animals" | "islands" | "purchases" | "earned" | "orders" | "animal:<id>" | "fish" | "species" | "zones" | "barn" | "expansions" | "facilities" | "centers" | "goods" | "items"
	target: number,
	reward: number,
}

-- Oyun geçidi (gamepass) ve tek seferlik ürün (developer product). id = 0 → henüz Roblox'ta oluşturulmadı:
-- ürün mağazada gizlenir ve satın alınamaz. Fiyat Roblox tarafında belirlenir; burada yalnızca etki vardır.
export type ProductConfig = {
	id: number,
	displayName: string,
	description: string,
	icon: string,
	incomeMultiplier: number?, -- Geçit: tüm hayvan gelirine çarpan
	storageBonus: number?, -- Geçit: depo kapasitesine ek (0.5 = +%50)
	autoCollect: boolean?, -- Geçit: baştan otomatik toplayıcı
	effect: string?, -- Ürün: "instantProduction" | "incomePack"
	incomeHours: number?, -- Ürün: "incomePack" kaç saatlik gelir verir
	goldAmount: number?, -- Ürün: kalıcı altın paketi
	offerId: string?, -- Ürün: kalıcı ekipman/kolaylık teklifi
	lifetime: string?, -- Kalıcı veya bu tur; ödeme türü kalıcılığı belirlemez.
}

export type SoundConfig = { id: string, volume: number, pitch: number? }

export type ExtensionConfig = {
	id: string,
	displayName: string,
	description: string,
	icon: string,
	island: string,
	sourceZoneId: string,
	animalId: string,
	capacity: number, -- Aynı anda eklentide durabilecek hayvan (taban); kapasite yükseltmeleriyle artar
	incomeBonus: number, -- 1 = +%100 gelir (eklentide duran hayvanlar); toplam bonus = incomeBonus x stayDuration
	stayDuration: number, -- Bir hayvanın eklentide kalma süresi (saniye); sonra ana bölgesine döner
}

return {}
