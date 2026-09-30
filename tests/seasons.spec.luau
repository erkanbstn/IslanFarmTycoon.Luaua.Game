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
	-- Işıklar gökyüzü karardıkça yanar; aydınlık gökyüzünde asla yanmaz.
	assert(environment.getLightFactor(12) == 0 and environment.getLightFactor(19) == 1, "Lights: day off, evening on")
	assert(environment.getLightFactor(3) == 1 and environment.getLightFactor(5) == 1, "Lights stay on before dawn")
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
