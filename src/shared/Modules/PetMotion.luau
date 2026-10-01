--!strict
-- Yardımcı (pet) hareketinin saf hesabı: ne zaman ışınlanır, güncelleme aralığı, bir adım ilerleme.
-- Kalite yalnızca pahalı işi (bacak/zıplama, bekleme sallanması) keser; konum akıcı ilerler. Işınlanma yalnızca çok uzakta olur.
-- `ReducedMotion` ayrı bir konudur (zıplamayı keser), buradaki kalite kararlarına karışmaz.

local PetMotion = {}

PetMotion.SKIP_DISTANCE = 350 -- bu uzaklıktan ötede yürütülmez, ışınlanır
PetMotion.FAR_DISTANCE = 150 -- bu uzaklıktan ötede güncelleme seyrelir (ışınlanma yok)
PetMotion.NEAR_INTERVAL = 0 -- orta/yüksek kalite: her kare
PetMotion.LOW_INTERVAL = 1 / 30 -- düşük kalite: en az 30 Hz
PetMotion.FAR_INTERVAL = 1 / 15 -- uzakta en az 15 Hz
PetMotion.MAX_DT = 0.25 -- tek adımda en çok bu kadar süre ilerler (takılma sonrası sıçrama sınırı)
PetMotion.ARRIVE_DISTANCE = 0.4

-- Kameraya uzaklık (distance) için yürüyüş ışınlanır mı? Kamera yoksa asla.
function PetMotion.teleports(distance: number?): boolean
	return distance ~= nil and distance > PetMotion.SKIP_DISTANCE
end

-- İki konum güncellemesi arasındaki en kısa süre (kare başı beklemek 0).
function PetMotion.walkInterval(quality: string, distance: number?): number
	local far = distance ~= nil and distance > PetMotion.FAR_DISTANCE
	local interval = if quality == "low" then PetMotion.LOW_INTERVAL else PetMotion.NEAR_INTERVAL
	if far then
		interval = math.max(interval, PetMotion.FAR_INTERVAL)
	end
	return interval
end

-- Yürüyüş zıplaması / bekleme sallanması yalnızca düşük olmayan kalitede ve hareket azaltma kapalıyken.
function PetMotion.animates(quality: string, reducedMotion: boolean): boolean
	return quality ~= "low" and not reducedMotion
end

-- (x, z) konumundan hedefe `speed * dt` kadar ilerler, hedefi aşmaz. Dönüş: yeni x, z, vardı mı.
function PetMotion.advance(
	x: number,
	z: number,
	targetX: number,
	targetZ: number,
	speed: number,
	dt: number
): (number, number, boolean)
	local dx, dz = targetX - x, targetZ - z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < PetMotion.ARRIVE_DISTANCE then
		return x, z, true
	end
	local step = math.min(distance, speed * math.min(dt, PetMotion.MAX_DT))
	return x + dx / distance * step, z + dz / distance * step, false
end

return PetMotion
