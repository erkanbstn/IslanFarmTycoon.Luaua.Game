--!strict
return function(createAnimalModels: any, createShore: any)
	local warnings: { string } = {}
	local function warning(message: string)
		table.insert(warnings, message)
	end
	local function folder(children: any): any
		return {
			FindFirstChild = function(_self: any, name: string): any
				return children[name]
			end,
		}
	end
	local templates: any = {}
	local storage = folder({ Assets = folder({ Animals = folder(templates) }) })
	local gameMock = {
		GetService = function(_self: any, name: string): any
			return if name == "ServerStorage" then storage else folder({})
		end,
	}
	local partCreations = 0
	local instances = {
		new = function(class: string): any
			if class == "Part" then
				partCreations += 1
			end
			return { Name = class }
		end,
	}
	local colors = {
		fromRGB = function(): any
			return {}
		end,
	}
	local scales: { number } = {}
	local sanitizer = {
		clone = function(_template: any, collide: boolean): any
			assert(not collide, "animal models are noncolliding")
			return {
				GetScale = function(): number
					return 1
				end,
				ScaleTo = function(_self: any, scale: number)
					table.insert(scales, scale)
				end,
			}
		end,
	}
	local animals = createAnimalModels(gameMock, sanitizer, colors, warning, instances, {})
	assert(animals.createAnimalVisual("cow", "adult") == nil, "missing animal renders nothing")
	assert(animals.createAnimalVisual("cow", "calf") == nil and #warnings == 1, "missing animal warns once")
	assert(partCreations == 0, "missing animal cannot construct fallback parts")
	templates.cow = {
		IsA = function(_self: any, class: string): boolean
			return class == "Model"
		end,
	}
	assert(
		animals.createAnimalVisual("cow", "calf") ~= nil and scales[1] == 0.55,
		"later asset arrival is retried and scaled"
	)
	local frameMeta: any = {}
	frameMeta.__mul = function(left: any, right: any): any
		return setmetatable({
			Position = {
				X = left.Position.X + right.Position.X,
				Y = left.Position.Y + right.Position.Y,
				Z = left.Position.Z + right.Position.Z,
			},
			Rotation = right,
		}, frameMeta)
	end
	local frames = {
		new = function(x: number?, y: number?, z: number?): any
			return setmetatable({ Position = { X = x or 0, Y = y or 0, Z = z or 0 }, Rotation = {} }, frameMeta)
		end,
	}
	local vectors = {
		new = function(x: number, y: number, z: number): any
			return { X = x, Y = y, Z = z }
		end,
	}
	local template: any = nil
	local assets = {
		clone = function(): any
			return template
		end,
	}
	local shore = createShore(gameMock, {}, assets, warning, instances, vectors, frames, {}, {}, {}, {})
	local parent = {}
	local position = { X = 3, Z = 4 }
	local before = #warnings
	assert(shore.pierPile(parent, position, 1, -30) == nil, "missing pile renders nothing")
	assert(shore.pierPile(parent, position, 1, -30) == nil and #warnings == before + 1, "missing pile warns once")
	assert(partCreations == 0, "missing pile cannot construct fallback parts")
	shore.dock(parent, frames.new(), 10, 1, -30)
	assert(
		partCreations == 0 and #warnings == before + 4,
		"dock safely skips missing deck, piles, hut and tip without fallback parts or repeated warnings"
	)
	template = {
		FindFirstChildWhichIsA = function(): any
			return nil
		end,
		Destroy = function(self: any)
			self.destroyed = true
		end,
	}
	assert(shore.pierPile(parent, position, 1, -30) == nil and template.destroyed, "malformed pile clone is cleaned up")
	local pile: any = {
		Size = { Y = 1, Z = 1 },
		CFrame = { Rotation = frames.new() },
		IsA = function(_self: any, class: string): boolean
			return class == "Part"
		end,
		SetAttribute = function(self: any, name: string, value: any)
			self[name] = value
		end,
	}
	template = {
		FindFirstChildWhichIsA = function(): any
			return pile
		end,
		Destroy = function(self: any)
			self.destroyed = true
		end,
	}
	assert(
		shore.pierPile(parent, position, 1, -30) == pile and pile.Parent == parent and template.destroyed,
		"returned pile asset is placed and wrapper cleaned up"
	)
	assert(
		pile.Size.X == 31.2 and pile.SeabedY == -30 and pile.CanCollide,
		"pile keeps placement and collision contract"
	)
	print("PASS missing models: no animal/pile fallback geometry, bounded warnings, retry and malformed clone cleanup")
end
