--!strict
-- Sıralama mantığı (saf): değer hesabı, sıralama/eşitlik, boş liste, uzun ad, NaN/negatif, birleştirme ve zamanlama.
return function(Leaderboard: any)
	-- Tablo değerleri
	assert(Leaderboard.isBoard("rebirth") and Leaderboard.isBoard("farms"), "known boards")
	assert(
		not Leaderboard.isBoard("cash") and not Leaderboard.isBoard(nil) and not Leaderboard.isBoard(5),
		"unknown boards"
	)
	local progress = { farmsComplete = 4, farmsTotal = 6 }
	assert(Leaderboard.score("rebirth", { progression = { count = 7 } }, progress) == 7, "rebirth score is the count")
	assert(Leaderboard.score("rebirth", {}, progress) == 0, "legacy save without progression scores zero")
	assert(
		Leaderboard.score("farms", { progression = { count = 2 } }, progress) == 16,
		"farm score adds completed farms of past runs and the current run"
	)
	assert(
		Leaderboard.score("farms", {}, { farmsComplete = 3, farmsTotal = 6 }) == 3,
		"first run counts only current farms"
	)
	assert(
		Leaderboard.score("farms", { progression = { count = 0 } }, { farmsComplete = 99, farmsTotal = 6 }) == 6,
		"complete farms cannot exceed the farm total"
	)
	assert(Leaderboard.score("farms", {}, nil) == nil, "missing progress yields no farm score")
	assert(Leaderboard.score("farms", {}, { farmsComplete = "x", farmsTotal = 6 }) == nil, "bad progress is rejected")
	assert(
		Leaderboard.score("rebirth", { progression = { count = 3 } }, progress, true) == nil,
		"excluded accounts have no score"
	)
	assert(
		Leaderboard.score("cash", {}, progress) == nil and Leaderboard.score("rebirth", nil, progress) == nil,
		"bad input"
	)
	assert(
		Leaderboard.score("rebirth", { progression = { count = 0 / 0 } }, progress) == 0
			and Leaderboard.score("rebirth", { progression = { count = -5 } }, progress) == 0,
		"NaN or negative rebirth counts become zero"
	)
	assert(
		Leaderboard.score("rebirth", { progression = { count = 1e30 } }, progress) == Leaderboard.MAX_SCORE,
		"huge values clamp"
	)

	-- Değer temizliği
	assert(Leaderboard.sanitizeScore(3.9) == 3 and Leaderboard.sanitizeScore(0) == 0, "floors whole numbers")
	assert(
		Leaderboard.sanitizeScore(-1) == nil
			and Leaderboard.sanitizeScore(0 / 0) == nil
			and Leaderboard.sanitizeScore(math.huge) == nil
			and Leaderboard.sanitizeScore(-math.huge) == nil
			and Leaderboard.sanitizeScore("5") == nil
			and Leaderboard.sanitizeScore(nil) == nil,
		"negative, NaN, infinite and non-number values are rejected"
	)
	assert(Leaderboard.sanitizeScore(1e12) == Leaderboard.MAX_SCORE, "upper bound")

	-- Ad temizliği
	assert(Leaderboard.cleanName("Ada") == "Ada", "plain name unchanged")
	assert(Leaderboard.cleanName("  A\nB\tC  ") == "A B C", "control characters and spacing are normalized")
	assert(
		Leaderboard.cleanName("") == Leaderboard.FALLBACK_NAME
			and Leaderboard.cleanName("  \n ") == Leaderboard.FALLBACK_NAME,
		"empty names use the fallback"
	)
	assert(
		Leaderboard.cleanName(nil) == Leaderboard.FALLBACK_NAME
			and Leaderboard.cleanName(12) == Leaderboard.FALLBACK_NAME,
		"non-string names use the fallback"
	)
	local cut = Leaderboard.cleanName(string.rep("a", 200))
	assert(
		utf8.len(cut) == Leaderboard.NAME_MAX and string.sub(cut, -3) == "…",
		"very long names are cut to the maximum including the ellipsis"
	)
	local turkishCut = Leaderboard.cleanName(string.rep("ğüşiöç", 10))
	assert(utf8.len(turkishCut) == Leaderboard.NAME_MAX, "multibyte names are cut on character boundaries")
	assert(
		utf8.len(Leaderboard.cleanName(string.rep("a", Leaderboard.NAME_MAX))) == Leaderboard.NAME_MAX,
		"exact length is kept"
	)
	assert(
		Leaderboard.cleanName(string.char(255, 254) .. "bad") == Leaderboard.FALLBACK_NAME,
		"invalid UTF-8 falls back"
	)

	-- Sıralama
	assert(#Leaderboard.rank({}, 6) == 0, "empty list")
	local ranked = Leaderboard.rank({
		{ userId = 3, name = "Cem", score = 5 },
		{ userId = 1, name = "ada", score = 5 },
		{ userId = 2, name = "Bora", score = 9 },
		{ userId = 4, name = "Dilek", score = 0 },
	}, 10)
	assert(
		ranked[1].userId == 2 and ranked[2].userId == 1 and ranked[3].userId == 3 and ranked[4].userId == 4,
		"descending score; ties by case-insensitive name"
	)
	local tie = Leaderboard.rank({
		{ userId = 9, name = "Aynı", score = 4 },
		{ userId = 7, name = "Aynı", score = 4 },
	}, 10)
	assert(tie[1].userId == 7 and tie[2].userId == 9, "identical names break ties by user id")
	local limited = Leaderboard.rank({
		{ userId = 1, name = "a", score = 1 },
		{ userId = 2, name = "b", score = 2 },
		{ userId = 3, name = "c", score = 3 },
	}, 2)
	assert(#limited == 2 and limited[1].userId == 3 and limited[2].userId == 2, "limit keeps the highest rows")
	assert(#Leaderboard.rank({ { userId = 1, name = "a", score = 1 } }, 0) == 0, "zero limit")
	local dirty = Leaderboard.rank({
		{ userId = 1, name = "ok", score = 3 },
		{ userId = 2, name = "nan", score = 0 / 0 },
		{ userId = 3, name = "neg", score = -4 },
		{ userId = 4, name = "inf", score = math.huge },
		{ userId = "5", name = "str", score = 1 },
		{ userId = 0, name = "zero", score = 1 },
		{ userId = 1.5, name = "frac", score = 1 },
		{ name = "noid", score = 1 },
		"junk",
		{ userId = 6, name = nil, score = 2 },
	}, 10)
	assert(#dirty == 2 and dirty[1].userId == 1 and dirty[2].userId == 6, "invalid rows are dropped")
	assert(dirty[2].name == Leaderboard.FALLBACK_NAME, "missing names use the fallback")
	local deduped = Leaderboard.rank({
		{ userId = 1, name = "a", score = 2 },
		{ userId = 1, name = "a", score = 8 },
	}, 10)
	assert(#deduped == 1 and deduped[1].score == 8, "a user appears once with the highest value")

	-- Birleştirme: sunucudaki canlı değer kayıtlıyı ezer (düşüş dahil), diğerleri kayıtlıdan gelir
	local merged = Leaderboard.merge(
		{ { userId = 1, score = 30 }, { userId = 2, score = 20 }, { userId = 3, score = 10 } },
		{ [1] = 0, [4] = 15 },
		{ [1] = "Ada", [2] = "Bora", [3] = "Cem", [4] = "Dilek" }
	)
	assert(
		#merged == 4
			and merged[1].userId == 2
			and merged[2].userId == 4
			and merged[3].userId == 3
			and merged[4].userId == 1,
		"live values override stored ones, including drops after a reset"
	)
	assert(merged[4].score == 0 and merged[1].name == "Bora", "values and names carry over")
	assert(#Leaderboard.merge({}, {}, {}) == 0, "empty merge")

	-- Zamanlama: değişmeyen değer yazılmaz, aralık beklenir, hatada üstel geri çekilme
	local schedule = Leaderboard.newSchedule(100)
	assert(Leaderboard.shouldPublish(schedule, 5, 0), "first value is due immediately")
	schedule.success(0, 5)
	assert(not Leaderboard.shouldPublish(schedule, 5, 1000), "unchanged value is never rewritten")
	assert(not Leaderboard.shouldPublish(schedule, 6, 99), "changes wait for the interval")
	assert(Leaderboard.shouldPublish(schedule, 6, 100), "changes publish once the interval passes")
	schedule.failure(100)
	assert(not schedule.due(150) and schedule.failures() == 1, "a failure delays the next try")
	assert(schedule.due(200), "retry after one interval")
	schedule.failure(200)
	assert(not schedule.due(350) and schedule.due(400), "backoff doubles")
	for _ = 1, 20 do
		schedule.failure(1000)
	end
	assert(
		not schedule.due(1000 + Leaderboard.BACKOFF_MAX - 1) and schedule.due(1000 + Leaderboard.BACKOFF_MAX),
		"backoff is capped"
	)
	schedule.success(5000, 9)
	assert(schedule.failures() == 0 and schedule.lastValue() == 9, "success resets the failure count")
	print("PASS leaderboard: scores, ordering/ties, empty, long names, NaN/negative, merge and publish schedule")
end
