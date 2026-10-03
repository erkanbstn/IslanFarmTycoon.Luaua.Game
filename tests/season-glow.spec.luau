--!strict
return function(SeasonGlow: any)
	local scans, writes = 0, 0
	local function part(name: string, base: number): any
		local value = base
		return setmetatable({
			Name = name,
			IsA = function(_, class: string): boolean
				return class == "BasePart"
			end,
		}, {
			__index = function(_, key)
				return if key == "Transparency" then value else nil
			end,
			__newindex = function(_, key, nextValue)
				assert(key == "Transparency", "Only the transparency property should be updated")
				value = nextValue
				writes += 1
			end,
		})
	end
	local function fixture(kind: string): (any, { any })
		local parts = { part("Glow", 0.3), part("Mark_2", 0.4), part("Ring_3", 0.2), part("Other", 0.7) }
		local model = {
			GetAttribute = function()
				return kind
			end,
			GetDescendants = function()
				scans += 1
				return parts
			end,
		}
		return SeasonGlow.capture(model :: any), parts
	end
	local function close(actual: number, expected: number)
		assert(math.abs(actual - expected) < 1e-12, `Expected {expected}, got {actual}`)
	end
	for _, kind in { "good", "bad" } do
		local glow, parts = fixture(kind)
		local before = scans
		for tick = 1, 150 do
			local now = tick / 15
			SeasonGlow.update(glow, now, false, false)
			local phase = if kind == "good" then 2 else 3
			close(parts[1].Transparency, math.clamp(0.3 + math.sin(now * 2.2) * 0.1, 0, 1))
			close(parts[2].Transparency, math.clamp(0.4 + 0.6 * (0.5 - 0.5 * math.sin(now * 3 - phase * 0.9)), 0, 1))
			close(parts[3].Transparency, math.clamp(0.2 + math.sin(now * 2.2 - 3 * 0.8) * 0.08, 0, 1))
			close(parts[4].Transparency, 0.7)
		end
		assert(scans == before, "Animation must not rescan model descendants")
		SeasonGlow.update(glow, 10, true, false)
		close(parts[2].Transparency, 1)
		close(parts[1].Transparency, 0.3)
		local previousWrites = writes
		for tick = 1, 150 do
			SeasonGlow.update(glow, tick, true, false)
		end
		assert(writes == previousWrites, "Static low quality must not repeat property writes")
		SeasonGlow.update(glow, 10, false, true)
		close(parts[2].Transparency, 0.4)
		previousWrites = writes
		SeasonGlow.update(glow, 11, false, true)
		assert(writes == previousWrites, "Reduced motion must remain static")
		SeasonGlow.update(glow, 11, false, false)
		assert(writes > previousWrites, "Animation must resume after settings change")
	end
	print("season-glow: exact animation, settings restoration and bounded scan/write regression passed")
end
