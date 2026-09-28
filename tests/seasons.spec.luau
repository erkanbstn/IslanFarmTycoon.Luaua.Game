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
	print("PASS seasons: duration, synchronized timer, cycle boundaries, shedding, accumulation and thaw")
end
