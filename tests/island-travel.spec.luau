--!strict
return function(createService: any, config: any)
	-- CFrame arithmetic keeps the originating marker identity; no Roblox transform behavior is reimplemented.
	local frameMeta: any = {}
	frameMeta.__mul = function(left: any, _right: any): any
		return left
	end
	frameMeta.__add = function(left: any, _right: any): any
		return left
	end
	local function frame(id: string): any
		return setmetatable({ id = id }, frameMeta)
	end
	local vectors = {
		new = function(): any
			return {}
		end,
	}
	local frames = {
		new = function(): any
			return {}
		end,
		Angles = function(): any
			return {}
		end,
	}
	local function part(id: string): any
		return {
			CFrame = frame(id),
			IsA = function(_self: any, name: string): boolean
				return name == "BasePart"
			end,
		}
	end
	local function island(id: string, marker: string): any
		return {
			GetAttribute = function(): string
				return id
			end,
			FindFirstChild = function(_self: any, name: string): any
				return if name == "IslandSign" then part(marker) else nil
			end,
		}
	end
	local function plot(index: number): any
		return {
			Name = `Plot{index}`,
			children = {},
			attributes = { PlotId = tostring(index) },
			IsA = function(_self: any, name: string): boolean
				return name == "Model"
			end,
			GetAttribute = function(self: any, name: string): any
				return self.attributes[name]
			end,
			SetAttribute = function(self: any, name: string, value: any)
				self.attributes[name] = value
			end,
			FindFirstChild = function(self: any, name: string): any
				return self.children[name]
			end,
		}
	end
	local plots = { plot(1), plot(2) }
	local data: any = nil
	local owner: any = nil
	local node: any = {
		WaitForChild = function(): any
			return {}
		end,
	}
	local gameMock = {
		GetService = function(_self: any, name: string): any
			if name == "Players" then
				return { MaxPlayers = config.MAP_PLOT_COUNT }
			end
			if name == "Workspace" then
				return {
					FindFirstChild = function(): any
						return {
							GetChildren = function(): any
								return plots
							end,
						}
					end,
				}
			end
			return node
		end,
	}
	local noop = function() end
	local service = createService(
		gameMock,
		noop,
		{},
		{ setTag = noop, setSignText = noop },
		{
			tryGet = function(player: any): any
				return if player == owner then data else nil
			end,
		},
		{ ensure = noop, validate = noop },
		{ clear = noop, refresh = noop },
		{ applyForPlayer = noop },
		{ apply = noop },
		{ apply = noop },
		vectors,
		frames
	)
	local function player(id: number): any
		return {
			UserId = id,
			Name = tostring(id),
			DisplayName = tostring(id),
			attributes = { WorldReady = true, SelectedFarmIsland = "home" },
			GetAttribute = function(self: any, key: string): any
				return self.attributes[key]
			end,
			SetAttribute = function(self: any, key: string, value: any)
				self.attributes[key] = value
			end,
			CharacterAdded = {
				Connect = function(): any
					return { Disconnect = noop }
				end,
			},
		}
	end
	owner = player(1)
	local other = player(2)
	service.init()
	assert(service.assign(owner) and service.assign(other), "fixture must allocate separate plots")
	local visited: { string } = {}
	owner.Character = {
		Parent = {},
		PivotTo = function(_self: any, target: any)
			table.insert(visited, target.id)
		end,
	}
	plots[1].children.Spawn = part("own-home")
	plots[2].children.Spawn = part("other-home")
	plots[1].children.Islands = {
		GetChildren = function(): any
			return { island("poultry", "own-poultry"), island("horse", "own-horse") }
		end,
	}
	plots[2].children.Islands = {
		GetChildren = function(): any
			return { island("goat", "other-goat") }
		end,
	}
	assert(not service.teleportToIsland(owner, "home"), "unloaded profile cannot travel")
	data = { unlockedIslands = { home = true } }
	for _, invalid in { {}, 42, "", "2", "unknown", string.rep("x", 100) } do
		assert(not service.teleportToIsland(owner, invalid), "invalid id cannot select a plot or arbitrary target")
	end
	assert(
		not service.teleportToIsland(owner, "poultry") and #visited == 0,
		"locked specialist island cannot be visited"
	)
	assert(not service.selectIsland(owner, "poultry"), "selection cannot bypass island lock")
	data.unlockedIslands.poultry = true
	assert(service.teleportToIsland(owner, "poultry"), "unlocked specialist island can be visited")
	assert(
		visited[1] == "own-poultry" and owner.attributes.SelectedFarmIsland == "poultry",
		"travel uses own marker and publishes selected island"
	)
	data.unlockedIslands.goat = true
	assert(
		not service.teleportToIsland(owner, "goat") and #visited == 1,
		"missing own marker never falls back to another player's island"
	)
	owner.attributes.WorldReady = false
	assert(not service.teleportToIsland(owner, "home"), "world preparation must complete before travel")
	owner.attributes.WorldReady = true
	assert(service.teleportToIsland(owner, "home") and visited[2] == "own-home", "home goes to own spawn")
	local character = owner.Character
	owner.Character = nil
	assert(
		not service.teleportToIsland(owner, "poultry") and owner.attributes.SelectedFarmIsland == "home",
		"missing character cannot falsely acknowledge arrival"
	)
	local beforeSelection = #visited
	assert(
		service.selectIsland(owner, "poultry") and owner.attributes.SelectedFarmIsland == "poultry",
		"valid owned island can be selected without a character"
	)
	assert(#visited == beforeSelection, "selection-only never pivots the character")
	owner.Character = character
	assert(service.teleportToIsland(owner, "poultry"), "subsequent specialist visit succeeds")
	service.teleportHome(owner)
	assert(
		owner.attributes.SelectedFarmIsland == "home" and visited[#visited] == "own-home",
		"home shortcut resets selected island"
	)
	assert(not service.teleportToIsland(player(3), "home"), "unassigned stranger cannot access an owned plot")
	print(
		"PASS island travel: actual service locked/profile/world guards, own safe marker, invalid IDs, missing character and selected island state"
	)
end
