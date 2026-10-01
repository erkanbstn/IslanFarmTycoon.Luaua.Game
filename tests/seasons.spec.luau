--!strict
return function(visuals: any, createEnvironment: any, config: any)
	local seasons = { "spring", "summer", "autumn", "winter" }
	for index, season in seasons do
		for step = 0, 100 do
			for _, value in visuals.sample(season, step / 100) do
				assert(value >= 0 and value <= 1, "Visual curve must remain bounded")
			end
		end
		local finish = visuals.sample(season, 1)
		local nextStart = visuals.sample(seasons[index % #seasons + 1], 0)
		for key, value in finish do
			assert(math.abs(value - nextStart[key]) < 0.000001, `Season seam discontinuity: {season}/{key}`)
		end
	end
	assert(visuals.sample("winter", 0.5).snow == 1, "Midwinter must have full snow")
	assert(visuals.sample("winter", 0.9).snow < visuals.sample("winter", 0.7).snow, "Late winter must thaw")
	assert(visuals.sample("spring", 0.25).ice == 0, "Spring ice must finish melting")
	assert(visuals.sample("autumn", 0.9).foliage < visuals.sample("autumn", 0.4).foliage, "Autumn sheds leaves")
	assert(visuals.sample("spring", 0.5).bloom > 0.9, "Spring blossoms must peak")
	assert(visuals.sample("summer", 0).foliage == 1, "Summer foliage must regrow")
	local attributes: { [string]: any } = {}
	local now = config.SEASON_SECONDS * 3
	local storage = {
		GetAttribute = function(_self: any, name: string): any
			return attributes[name]
		end,
	}
	local workspace = {
		GetServerTimeNow = function(): number
			return now
		end,
	}
	local environment = createEnvironment({
		GetService = function(_self: any, name: string): any
			return if name == "Workspace" then workspace else storage
		end,
	})
	assert(config.SEASON_SECONDS == 900, "Season duration must be 15 minutes")
	assert(environment.getSeason().id == "winter", "Late join must use server time")
	assert(environment.getNextSeason().id == "spring", "Winter must wrap to spring")
	assert(environment.getSeasonProgress() == 0, "Missing attributes must not yield an expired timer")
	attributes.Season = "winter"
	attributes.SeasonEndsAt = now + config.SEASON_SECONDS
	assert(environment.getSeasonProgress(now + config.SEASON_SECONDS / 2) == 0.5, "Progress midpoint")
	assert(environment.getSeasonProgress(now - 10) == 0, "Progress lower clamp")
	assert(environment.getSeasonProgress(now + config.SEASON_SECONDS + 10) == 1, "Progress upper clamp")
	-- Oyuncuya özel ortam katmanı (asa): yalnızca verilen oyuncunun kaydı etkilenir, dünya aynı kalır
	local summer = { seasonId = "summer", seasonEndsAt = now + 100 }
	assert(environment.getSeason(summer).id == "summer", "an active season override wins")
	assert(
		environment.getSeason().id == "winter" and environment.getSeason(nil).id == "winter",
		"the world season is untouched"
	)
	local summerWeather = environment.getWeather(summer)
	assert(config.SEASONS[2].weather[summerWeather.id], "an overridden season gets weather from its own pool")
	assert(environment.getWeather(summer).id == summerWeather.id, "the overridden weather is stable within a window")
	assert(environment.getSeasonEndsAt(summer) == now + 100, "the override carries its own timer")
	-- Mevsim uyumu (bölge geliştirmesi): olumlu etkiler büyür, olumsuzlar küçülür, hiçbiri zarar vermez
	for _, season in config.SEASONS do
		local override = { seasonId = season.id, seasonEndsAt = now + 100 }
		for animalId, mod in season.incomeModifiers do
			local plain = environment.getIncomeMultiplier(animalId, override)
			local tuned = environment.getIncomeMultiplier(animalId, override, 0.3)
			assert(tuned >= plain - 1e-9, "season affinity must never hurt")
			if mod ~= 0 and plain > 0.2 then
				assert(tuned ~= plain, "season affinity must change a non-neutral season")
			end
		end
	end
	-- Hayvan başına sinyal: işaret etkiyle uyumlu; bölge uyumu olumsuzu küçültür, olumluyu büyütür
	do
		local threshold = config.SEASON_SIGNAL_THRESHOLD
		assert(threshold > 0 and threshold < 0.2, "signal threshold must be a small positive fraction")
		local sawUp, sawDown, sawNeutral = false, false, false
		for _, season in config.SEASONS do
			for weatherId in config.WEATHER do
				local override = {
					seasonId = season.id,
					seasonEndsAt = math.huge,
					weatherId = weatherId,
					weatherEndsAt = math.huge,
				}
				for _, animalId in config.ANIMAL_ORDER do
					local base = environment.getSeasonEffect(animalId, override)
					assert(
						math.abs(base.percent - (environment.getIncomeMultiplier(animalId, override) - 1)) < 1e-9,
						"effect percent matches the income multiplier"
					)
					local expected = if base.percent >= threshold then 1 elseif base.percent <= -threshold then -1 else 0
					assert(base.signal == expected, `signal sign mismatch {season.id}/{weatherId}/{animalId}`)
					sawUp = sawUp or base.signal == 1
					sawDown = sawDown or base.signal == -1
					sawNeutral = sawNeutral or base.signal == 0
					local tuned = environment.getSeasonEffect(animalId, override, 0.65)
					if base.percent > 0 then
						assert(tuned.percent > base.percent, "affinity must enlarge a positive effect")
					elseif base.percent < 0 then
						assert(tuned.percent > base.percent, "affinity must shrink a negative effect")
					end
					assert(tuned.signal >= base.signal, "affinity never turns a signal worse")
				end
			end
		end
		assert(sawUp and sawDown and sawNeutral, "config must contain rising, falling and neutral animals")
	end
	assert(environment.getNextSeason(summer).id == "autumn", "the next season follows the overridden one")
	assert(
		environment.getSeason({ seasonId = "summer", seasonEndsAt = now - 1 }).id == "winter",
		"an expired override is ignored"
	)
	local rain = { weatherId = "rain", weatherEndsAt = now + 50 }
	assert(
		environment.getWeather(rain).id == "rain" and environment.getSeason(rain).id == "winter",
		"a weather override keeps the world season"
	)
	assert(
		environment.getWeather({ weatherId = "rain", weatherEndsAt = now - 1 }).id == environment.getWeather().id,
		"an expired weather override is ignored"
	)
	local expected = math.max(
		1 + (config.SEASONS[2].incomeModifiers.goat or 0) + (config.WEATHER[summerWeather.id].incomeModifiers.goat or 0),
		0.2
	)
	assert(
		math.abs(environment.getIncomeMultiplier("goat", summer) - expected) < 1e-9,
		"income uses the overridden environment"
	)
	-- Gün-gece: sunucu saatinden türetilir, sınırlı, sürekli; yönetici seçimi saati sabitler.
	local dayLength = config.DAY_SECONDS
	for step = 0, 200 do
		local clock = environment.getClockTime(step / 200 * dayLength)
		assert(clock >= 0 and clock < 24, "Clock must stay within 24 hours")
		local night = environment.getNightFactor(clock)
		assert(night >= 0 and night <= 1, "Night factor must stay bounded")
	end
	assert(math.abs(environment.getClockTime(0) - config.DAY_START_HOUR) < 0.000001, "Day starts at configured hour")
	assert(
		math.abs(environment.getClockTime(dayLength) - config.DAY_START_HOUR) < 0.000001,
		"Clock must repeat after one day"
	)
	assert(environment.getNightFactor(12) == 0 and environment.getNightFactor(23) == 1, "Noon is day, 23:00 is night")
	assert(environment.getNightFactor(2) == 1 and environment.getNightFactor(8) == 0, "Night ends after dawn")
	assert(
		environment.getNightFactor(18.5) > 0 and environment.getNightFactor(18.5) < 1,
		"Dusk must be a gradual transition"
	)
	assert(math.abs(environment.getNightFactor(24) - environment.getNightFactor(0)) < 0.000001, "Midnight seam")
	-- Şafak erken başlar: 04:25'te gökyüzü artık tam gece değildir ve eğri sabaha kadar tek yönde aydınlanır.
	assert(environment.getNightFactor(4.4) < 1 and environment.getNightFactor(3.4) == 1, "Dawn begins after 03:30")
	assert(environment.getNightFactor(4.4) > 0.6, "04:25 is still dim, not bright")
	assert(environment.getNightFactor(7) == 0 and environment.getNightFactor(17) == 0, "Full day 07:00-17:00")
	assert(environment.getNightFactor(20.5) == 1, "Full night from 20:30")
	local previousNight = environment.getNightFactor(3.5)
	for step = 1, 140 do
		local value = environment.getNightFactor(3.5 + step * 0.025)
		assert(value <= previousNight + 1e-9, "Night factor must fall monotonically through dawn")
		previousNight = value
	end
	previousNight = environment.getNightFactor(17)
	for step = 1, 140 do
		local value = environment.getNightFactor(17 + step * 0.025)
		assert(value >= previousNight - 1e-9, "Night factor must rise monotonically through dusk")
		previousNight = value
	end
	for _, key in environment.NIGHT_CURVE do
		assert(math.abs(environment.getNightFactor(key[1]) - key[2]) < 1e-9, "Curve passes through its keys")
	end
	assert(environment.getNightFactor(28) == environment.getNightFactor(4), "Clock wraps past 24")
	-- Işık rampası gökyüzüyle senkron: parlak gökyüzünde 0, derin gecede 1, sabah/akşam yalnızca bir kez geçiş.
	local flips = 0
	local lastLit = environment.getLightFactor(0) > 0
	for step = 1, 480 do
		local lit = environment.getLightFactor(step * 0.05) > 0
		if lit ~= lastLit then
			flips += 1
			lastLit = lit
		end
	end
	assert(flips == 2, "Lights switch on once at dusk and off once at dawn")
	assert(environment.getLightFactor(17.5) == 0 and environment.getLightFactor(18.7) > 0.95, "Dusk light ramp")
	assert(environment.getLightFactor(4.9) > 0.9 and environment.getLightFactor(6.1) == 0, "Dawn light ramp")
	-- Işıklar gökyüzü karardıkça yanar; aydınlık gökyüzünde asla yanmaz.
	assert(environment.getLightFactor(12) == 0 and environment.getLightFactor(19) == 1, "Lights: day off, evening on")
	assert(environment.getLightFactor(3) == 1 and environment.getLightFactor(4.5) > 0.9, "Lights stay on before dawn")
	assert(environment.getLightFactor(6.5) == 0 and environment.getLightFactor(17.5) == 0, "No lights in daylight")
	for step = 0, 480 do
		local clock = step * 0.05
		if environment.getNightFactor(clock) < 0.15 then
			assert(environment.getLightFactor(clock) == 0, `Lights must be off in a bright sky ({clock})`)
		end
	end
	assert(
		environment.getLightFactor(18.3) > 0 and environment.getLightFactor(18.3) < 1,
		"Lights fade in gradually at dusk"
	)
	assert(
		environment.getLightFactor(5.6) > 0 and environment.getLightFactor(5.6) < 1,
		"Lights fade out gradually at dawn"
	)
	assert(environment.getLightFactor(24) == environment.getLightFactor(0), "Light factor midnight seam")
	attributes.AdminClockId = "night"
	assert(environment.getClockTime(0) == 23, "Admin night preset freezes the clock")
	attributes.AdminClockId = "not_a_preset"
	assert(math.abs(environment.getClockTime(0) - config.DAY_START_HOUR) < 0.000001, "Unknown preset is ignored")
	attributes.AdminClockId = nil
	assert(environment.getLightsOverride() == nil and environment.getLightMultiplier() == 1, "Lights default to auto/1")
	attributes.AdminLightsId = "on"
	attributes.AdminLightLevelId = "dim"
	assert(environment.getLightsOverride() == "on" and environment.getLightMultiplier() < 1, "Light overrides apply")
	attributes.AdminLightsId = "bogus"
	attributes.AdminLightLevelId = "bogus"
	assert(
		environment.getLightsOverride() == nil and environment.getLightMultiplier() == 1,
		"Unknown light ids ignored"
	)
	print("PASS seasons: duration, synchronized timer, cycle boundaries, shedding, accumulation and thaw")
end
