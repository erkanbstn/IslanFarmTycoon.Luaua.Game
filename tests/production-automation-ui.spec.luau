--!strict
return function(createView: any, codec: any, config: any, farmMath: any)
	local root: any = {}
	root.WaitForChild = function(): any
		return root
	end
	local automation = createView({
		GetService = function(): any
			return root
		end,
	}, config, farmMath)
	local now = 900000
	local data = assert(codec.decode(nil, config, farmMath, now, function(): string
		return "automation-animal"
	end))
	data.cash = 1e6
	for _, upgrade in config.UPGRADES do
		data.purchased[upgrade.id] = true
	end
	farmMath.applyDerived(data)
	data.animals = {}
	for index = 1, 8 do
		table.insert(
			data.animals,
			{ uid = `adult-{index}`, animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" }
		)
	end
	data.autoRepeat = {}
	local goods = config.PRODUCTION_RECIPES.milk_goods
	local cash = config.PRODUCTION_RECIPES.packed_milk
	local function view(recipe: any): any
		return automation.getView(data, recipe, now)
	end
	local off = view(goods)
	assert(off.visible and off.enabled and not off.repeating, "built helper facility exposes the control")
	assert(off.action == "Otomatik üretimi aç", "the action explains how to enable repetition")
	assert(
		off.status == "Otomatik üretim kapalı · Partiyi sen başlat; bitince yardımcı alır.",
		"off does not falsely claim automatic delivery is disabled"
	)
	data.autoRepeat.milk_goods = "default"
	local idle = view(goods)
	assert(idle.repeating and idle.action == "Otomatik üretimi kapat", "enabled state shows the opposite action")
	assert(
		idle.status == "Otomatik üretim açık · Yeni parti başlayacak.",
		"empty stock can start, including capacity-limited batches"
	)
	data.goods.milk = farmMath.getGoodsCap(data)
	assert(
		view(goods).status == "Otomatik üretim açık · Depoda yer bekliyor.",
		"a full barn reports the actual space limit"
	)
	local cap = farmMath.getGoodsCap(data)
	local units = math.min(farmMath.previewGoodsYield(data, goods, now), cap)
	data.goods.milk = farmMath.getGoodsProductionTarget(data, "milk", units, now)
	assert(
		view(goods).status == "Otomatik üretim açık · Stok yeterli, azalınca devam eder.",
		"smart mode pauses before capacity"
	)
	data.autoRepeat.milk_goods = "fill"
	assert(
		view(goods).status == "Otomatik üretim açık · Yeni parti başlayacak.",
		"fill mode ignores the smart stock target"
	)
	data.autoRepeat.milk_goods = "default"
	data.goods.milk = 0
	data.production.milk_goods = { uid = "job", readyAt = now + 30, startedAt = now, forgone = 0 }
	assert(view(goods).status == "Otomatik üretim açık · Üretiliyor.", "an unfinished job shows running")
	data.production.milk_goods.readyAt = now
	assert(
		view(goods).status == "Otomatik üretim açık · Yardımcı partiyi alacak.",
		"a ready batch waits for the helper tick"
	)
	data.goods.milk = farmMath.getGoodsCap(data)
	assert(
		view(goods).status == "Otomatik üretim açık · Depoda yer bekliyor.",
		"ready goods expose a full-storage wait"
	)
	data.autoRepeat.milk_goods = nil
	assert(
		view(goods).status == "Otomatik üretim kapalı · Depoda yer bekliyor.",
		"turning repetition off preserves the actual ready-batch wait"
	)
	data.production.milk_goods.readyAt = now + 10
	assert(
		view(goods).status == "Otomatik üretim kapalı · Üretiliyor.",
		"turning repetition off does not cancel the ongoing batch"
	)
	data.production.milk_goods.readyAt = now
	data.goods.milk = 0
	assert(
		view(goods).status == "Otomatik üretim kapalı · Yardımcı partiyi alacak.",
		"automatic delivery remains clear when repetition is off"
	)
	data.autoRepeat.milk_goods = "default"
	data.production.milk_goods = nil
	local animals = data.animals
	data.animals = {}
	assert(
		view(goods).status == "Otomatik üretim açık · Boşta yetişkin hayvan bekliyor.",
		"missing adults do not appear to disable automation"
	)
	data.animals = animals
	data.cash = 0
	assert(view(goods).status == "Otomatik üretim açık · Başlatmak için para bekliyor.", "funding is explained")
	data.cash = 1e6
	data.autoRepeat.packed_milk = "medium"
	local cashView = view(cash)
	assert(cashView.enabled and cashView.repeating, "cash helper supports automatic repetition")
	local option = farmMath.findProductionOption(cash, "medium")
	assert(string.find(cashView.status, `Parti: {option.displayName}`, 1, true), "selected cash batch is visible")
	data.purchased.pet_goods_lv1 = nil
	assert(
		not view(goods).enabled
			and view(goods).status == "Ürün Yardımcısı yok. Market veya Yükseltmeler'den alabilirsin.",
		"unowned helper is distinguished from disabled automation"
	)
	data.purchased[goods.upgradeId] = nil
	assert(not view(goods).visible, "unbuilt facilities do not advertise a usable toggle")
end
