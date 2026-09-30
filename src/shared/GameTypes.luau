--!strict

export type AnimalStage = "calf" | "young" | "adult"

export type AnimalRecord = {
	uid: string,
	animalId: string,
	zoneId: string,
	stage: AnimalStage,
	bornAt: number, -- os.time(); evre buradan hesaplanır (oyuncu çevrimdışıyken de büyür)
	extensionId: string?, -- Doluysa hayvan eklentide; zoneId ana bölgeyi tutar (kapasite sayımı)
}

export type OrderRecord = {
	uid: string,
	animalId: string,
	progress: number,
	target: number,
	rewardFactor: number?, -- Sipariş panosundaki seçeneğin ödül çarpanı (yoksa 1)
}

export type ProductionJob = { uid: string, readyAt: number }

export type MainFarmSummary = {
	id: string,
	plotId: string?,
	active: boolean,
	animalCount: number,
	purchasedCount: number,
	stored: number,
}
export type SeasonalGoal = { key: number, progress: number, target: number, base: number, claimed: boolean }

export type EnvOverride = { seasonId: string?, seasonEndsAt: number?, weatherId: string?, weatherEndsAt: number? }

export type InventoryData = {
	items: { [string]: boolean },
	equipped: { [string]: string },
	uses: { [string]: { day: number, count: number, last: number } },
}

export type PlayerSave = {
	activeMainFarmId: string,
	farmId: string?, -- Yalnızca etkin olmayan çiftlik görünümlerinde: o çiftliğin numarası (tema için)
	adminForce: { [string]: any }?, -- Yönetici olay test araçları (çalışma anı; kaydedilmez)
	passes: { [string]: boolean }?, -- Doğrulanmış oyun geçitleri (kaydedilmez; sunucu MarketplaceService'ten yazar)
	receipts: { string }?, -- İşlenmiş satın alma makbuz kimlikleri (çift ödemeyi önler)
	lifetimeEarned: number?, -- Ömür boyu kazanç (başarımlar için)
	daily: { day: number, streak: number }?, -- Günlük ödül: son alınan gün (UTC gün numarası) ve seri
	achievements: { [string]: boolean }?, -- Ödülü alınmış başarımlar
	envOverride: EnvOverride?, -- Asa ile oyuncuya özel mevsim/hava (çalışma anı; kaydedilmez)
	inventory: InventoryData?, -- Envanter (hesap düzeyi): sahip olunan, takılı eşyalar ve asa hakları
	golden: { key: number }?, -- Altın hayvan: ödülü alınan son pencerenin döngü numarası
	merchant: { key: number, bought: boolean }?, -- Gezgin tüccar: son teklifin döngü numarası ve alınıp alınmadığı
	seasonal: SeasonalGoal?, -- Şu anki mevsim hedefi (hesap düzeyi; key = mevsim numarası)
	graphics: string?, -- Grafik tercihi (Config.GRAPHICS_MODES); nil = otomatik
	language: string?, -- Seçilen arayüz dili (Config.LANGUAGES kodu); nil = Roblox dilinden algıla
	mainFarmOffers: { { id: string, name: string, icon: string, ownerUserId: number? } }?,
	mainFarms: { [string]: any },
	mainFarmSummaries: { MainFarmSummary }?,
	production: { [string]: ProductionJob },
	cash: number,
	stored: number, -- Depoda biriken, henüz toplanmamış para
	purchased: { [string]: boolean }, -- Yol haritasından alınanlar (Config.UPGRADES id'leri)
	expansions: { [string]: number }?, -- Yapı geliştirme seviyeleri (bölge ya da tesis kimliği -> 1..Config.BUILD_UPGRADES.maxLevel); yoksa 0
	lineage: { [string]: number }?, -- Irk geliştirme seviyeleri (animalId -> 1..Config.LINEAGE.maxLevel); yoksa 0
	animals: { AnimalRecord },
	ordersCompleted: number,
	order: OrderRecord?,

	-- Aşağıdakiler kaydedilmez; purchased'dan / oturumdan türetilir
	barnLevel: number,
	unlockedIslands: { [string]: boolean },
	unlockedZones: { [string]: boolean },
}

return {}
