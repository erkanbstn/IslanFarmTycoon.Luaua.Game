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
export type PlayerSave = {
	activeMainFarmId: string,
	language: string?, -- Seçilen arayüz dili (Config.LANGUAGES kodu); nil = Roblox dilinden algıla
	mainFarmOffers: { { id: string, name: string, icon: string, ownerUserId: number? } }?,
	mainFarms: { [string]: any },
	mainFarmSummaries: { MainFarmSummary }?,
	production: { [string]: ProductionJob },
	cash: number,
	stored: number, -- Depoda biriken, henüz toplanmamış para
	purchased: { [string]: boolean }, -- Yol haritasından alınanlar (Config.UPGRADES id'leri)
	animals: { AnimalRecord },
	ordersCompleted: number,
	order: OrderRecord?,

	-- Aşağıdakiler kaydedilmez; purchased'dan / oturumdan türetilir
	barnLevel: number,
	unlockedIslands: { [string]: boolean },
	unlockedZones: { [string]: boolean },
}

return {}
