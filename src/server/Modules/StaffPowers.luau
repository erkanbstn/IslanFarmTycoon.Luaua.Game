--!strict
-- Asa yetenekleri (saf mantık, Roblox'a dokunmaz): Yetiştirici (büyüme), Üretim (parti süresi) ve Bakıcı (süreli gelir).
-- Her işlev etkin çiftliğin kaydı üzerinde çalışır ve kaç öğenin değiştiğini döner; 0 dönerse hiçbir şey değişmemiştir ve
-- çağıran (InventoryService) günlük hakkı harcamaz. Gelir kapatma (settlePlayer), hak kaydı ve istemci güncellemesi çağıranındır.

local StaffPowers = {}

local function validFraction(value: unknown): boolean
	return typeof(value) == "number" and value == value and value > 0 and value <= 1
end

-- Yavru/genç hayvanların kalan büyüme süresini `fraction` kadar kısaltır (bornAt öne çekilir; 0 "başlangıç yetişkini" işaretidir, yazılmaz).
function StaffPowers.grow(farm: any, now: number, fraction: number, farmMath: any, config: any): number
	if not validFraction(fraction) then
		return 0
	end
	local total = config.GROWTH_SECONDS.calf + config.GROWTH_SECONDS.young
	local changed = 0
	for _, animal in farm.animals do
		if animal.bornAt == 0 then
			continue
		end
		local speed = farmMath.getGrowthSpeed(farm, animal.animalId, animal.zoneId)
		if farmMath.getStage(animal.bornAt, now, speed) == "adult" then
			continue
		end
		local age = (now - animal.bornAt) * speed
		local remaining = total - age
		if remaining <= 0 then
			continue
		end
		local bornAt = math.max(1, now - (age + remaining * fraction) / speed)
		if bornAt < animal.bornAt then
			animal.bornAt = bornAt
			animal.stage = farmMath.getStage(bornAt, now, speed)
			changed += 1
		end
	end
	return changed
end

-- Çalışan üretim partilerinin kalan süresini `fraction` kadar kısaltır. Görevdeki hayvanların bitişi aynı anda öne çekilir;
-- kaçırılan gelir tabanı (forgone) gerçekten geçecek süreyle orantılı küçülür (ödül tabanı haksız şişmez).
function StaffPowers.rush(farm: any, now: number, fraction: number): number
	if not validFraction(fraction) then
		return 0
	end
	local changed = 0
	for recipeId, job in farm.production do
		local oldReady = if typeof(job) == "table" then job.readyAt else nil
		if typeof(oldReady) == "number" and oldReady == oldReady and oldReady > now and oldReady < math.huge then
			local newReady = now + (oldReady - now) * (1 - fraction)
			local startedAt = if typeof(job.startedAt) == "number" then job.startedAt else now
			local oldDuration = oldReady - startedAt
			if typeof(job.forgone) == "number" and oldDuration > 0 then
				job.forgone *= math.clamp((newReady - startedAt) / oldDuration, 0, 1)
			end
			job.readyAt = newReady
			for _, animal in farm.animals do
				local task = animal.task
				if task and task.kind == "production" and task.id == recipeId and task.endsAt == oldReady then
					task.endsAt = newReady
				end
			end
			changed += 1
		end
	end
	return changed
end

-- Sürü bakımı: bütün hayvanlara `seconds` süreyle +bonus gelir. Etkinken yenilenmez (üst üste binmez). Kayıt çalışma anıdır.
function StaffPowers.care(root: any, now: number, seconds: number, bonus: number): number
	if
		typeof(seconds) ~= "number"
		or seconds ~= seconds
		or seconds <= 0
		or typeof(bonus) ~= "number"
		or bonus ~= bonus
		or bonus <= 0
		or bonus > 1
	then
		return 0
	end
	local current = root.careBoost
	if typeof(current) == "table" and typeof(current.endsAt) == "number" and current.endsAt > now then
		return 0
	end
	root.careBoost = { startedAt = now, endsAt = now + seconds, bonus = bonus }
	return 1
end

return StaffPowers
