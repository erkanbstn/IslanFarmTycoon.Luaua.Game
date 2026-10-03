--!strict
-- Yardımcı hareketi: düşük kalite yalnızca süsü keser, yakın yardımcı asla ışınlanmaz, adım hedefi aşmaz.
return function(PetMotion: any)
	-- Işınlanma yalnızca çok uzakta; düşük kalite yakında ışınlamaz
	assert(not PetMotion.teleports(10), "near pet never teleports")
	assert(not PetMotion.teleports(PetMotion.SKIP_DISTANCE), "boundary walks")
	assert(PetMotion.teleports(PetMotion.SKIP_DISTANCE + 1), "very far pet teleports")
	assert(not PetMotion.teleports(nil), "no camera, no teleport")

	-- Güncelleme sıklığı: düşükte en az 30 Hz, uzakta en az 15 Hz, yakın orta/yüksekte her kare
	assert(PetMotion.walkInterval("medium", 20) == 0, "medium near: every frame")
	assert(PetMotion.walkInterval("high", 20) == 0, "high near: every frame")
	assert(PetMotion.walkInterval("low", 20) <= 1 / 29, "low near: at least ~30 Hz")
	assert(PetMotion.walkInterval("low", 20) > 0, "low near is throttled")
	assert(PetMotion.walkInterval("medium", 200) <= 1 / 14, "far: at least ~15 Hz")
	assert(PetMotion.walkInterval("low", 200) <= 1 / 14, "low far: at least ~15 Hz")
	assert(PetMotion.walkInterval("low", nil) <= 1 / 29, "no camera: low rate")

	-- Süs: düşükte ve hareket azaltmada kapalı
	assert(PetMotion.animates("medium", false), "medium animates")
	assert(not PetMotion.animates("low", false), "low skips bob")
	assert(not PetMotion.animates("high", true), "reduced motion skips bob")

	-- Adım: hedefe doğru, aşmadan
	local x, z, arrived = PetMotion.advance(0, 0, 10, 0, 15, 0.1)
	assert(math.abs(x - 1.5) < 1e-6 and z == 0 and not arrived, "moves speed*dt toward target")
	x, z, arrived = PetMotion.advance(0, 0, 0.8, 0, 15, 0.1)
	assert(math.abs(x - 0.8) < 1e-6 and not arrived, "does not overshoot")
	_, _, arrived = PetMotion.advance(9.7, 0, 10, 0, 15, 0.1)
	assert(arrived, "arrives within threshold")
	-- Düşük kalitede ~30 Hz adım, kare başı toplamla aynı yolu alır (zamanla orantılı, ışınlanma yok)
	local lowX = 0
	for _ = 1, 30 do
		lowX = PetMotion.advance(lowX, 0, 100, 0, 15, PetMotion.LOW_INTERVAL)
	end
	assert(math.abs(lowX - 15) < 1e-3, "one second at low rate covers speed distance")
	-- Büyük dt (takılma) sınırlanır
	x = PetMotion.advance(0, 0, 1000, 0, 15, 5)
	assert(x <= 15 * PetMotion.MAX_DT + 1e-6, "huge dt is clamped")

	-- Kapalı duvarı zorla geçmek yerine güvenli çevre yolu bulur.
	local function wallSegment(ax: number, az: number, bx: number, bz: number): boolean
		for index = 0, 100 do
			local alpha = index / 100
			local px, pz = ax + (bx - ax) * alpha, az + (bz - az) * alpha
			if px >= 3 and px <= 7 and pz >= -4 and pz <= 4 then
				return false
			end
		end
		return true
	end
	local route = PetMotion.detour(0, 0, 10, 0, wallSegment, 2, 256)
	assert(route and #route > 1, "solid building gets a detour")
	local previousX, previousZ = 0, 0
	for _, point in route do
		assert(wallSegment(previousX, previousZ, point.x, point.z), "every returned segment avoids the building")
		previousX, previousZ = point.x, point.z
	end
	assert(previousX == 10 and previousZ == 0, "detour reaches the destination")

	-- Köşegen serbest uçları bir duvarın içinden kestirme yapmak için kullanamaz.
	local blocked = PetMotion.detour(0, 0, 4, 4, function(_ax: number, _az: number, _bx: number, _bz: number): boolean
		return false
	end, 2, 20)
	assert(blocked == nil, "sealed path fails safely rather than forcing movement")
	local calls = 0
	local limited = PetMotion.detour(0, 0, 200, 0, function(ax: number, _az: number, bx: number, _bz: number): boolean
		calls += 1
		return math.abs(bx - ax) <= 2
	end, 2, 12)
	assert(limited == nil and calls < 110, "blocked/unreachable goal has bounded planning work")
	local direct = PetMotion.detour(0, 0, 10, 0, function(_ax: number, _az: number, _bx: number, _bz: number): boolean
		return true
	end)
	assert(direct and #direct == 1 and direct[1].x == 10, "clear route avoids grid planning")
end
