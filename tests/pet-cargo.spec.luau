--!strict
return function(PetCargo: any)
	local turkey = { id = "turkey_goods", animalId = "turkey" }
	local animalId, zoneId = PetCargo.select({
		{ animalId = "cow", zoneId = "starter", task = { kind = "production", id = "milk" } },
		{ animalId = "turkey", zoneId = "turkey_pen", task = { kind = "production", id = "turkey_goods" } },
	}, turkey)
	assert(
		animalId == "turkey" and zoneId == "turkey_pen",
		"Başka üretimin ineği yerine görevdeki hindi taşınmalı"
	)
	local fish = { id = "fish_goods", animalId = "anchovy" }
	animalId, zoneId = PetCargo.select({
		{ animalId = "seabass", zoneId = "fishpen", task = { kind = "production", id = "fish_goods" } },
	}, fish)
	assert(animalId == "seabass" and zoneId == "fishpen", "Çok tür kabul eden tarif gerçek levreği göstermeli")
	animalId, zoneId = PetCargo.select({}, turkey)
	assert(animalId == "turkey" and zoneId == "", "Eski görevde tarif türü kullanılmalı")
	animalId = PetCargo.select({
		{ animalId = "cow", zoneId = "starter", task = { kind = "extension", id = "turkey_goods" } },
	}, turkey)
	assert(animalId == "turkey", "Aynı kimlikli eklenti görevi üretim sanılmamalı")
	animalId, zoneId = PetCargo.select({}, fish, { cargoAnimalId = "seabass", cargoZoneId = "fishpen" })
	assert(
		animalId == "seabass" and zoneId == "fishpen",
		"Yeniden bağlanmada bitmiş işin gerçek balığı korunmalı"
	)
	animalId = PetCargo.select({
		{ animalId = "turkey", zoneId = "turkey_pen", task = { kind = "production", id = "turkey_goods" } },
	}, turkey, { cargoAnimalId = "cow", cargoZoneId = "starter" })
	assert(animalId == "turkey", "Çalışan gerçek görev metadata'dan öncelikli olmalı")
	local model, zone = PetCargo.resolve("anchovy", "", false, "batch-1", "batch-1", "seabass", "fishpen")
	assert(model == "seabass" and zone == "fishpen", "Görevi biten aynı partinin levreği korunmalı")
	model, zone = PetCargo.resolve("turkey", "turkey_pen", true, "batch-1", "batch-1", "cow", "starter")
	assert(model == "turkey" and zone == "turkey_pen", "Gerçek görev eski türü değiştirmeli")
	model, zone = PetCargo.resolve("turkey", "", false, "batch-2", "batch-1", "cow", "starter")
	assert(model == "turkey" and zone == "", "Yeni parti eski hayvan veya ağılı devralmamalı")
	print("Pet cargo checks passed")
end
