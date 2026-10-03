--!strict
return function(startLocalizer: any)
	local function signal(): any
		local callbacks = {}
		return {
			Connect = function(_self: any, callback: any)
				table.insert(callbacks, callback)
			end,
			fire = function(...: any)
				for _, callback in callbacks do
					callback(...)
				end
			end,
			count = function(): number
				return #callbacks
			end,
		}
	end
	local function instance(className: string, properties: any?, descendants: any?): any
		local values = properties or {}
		local changed = {}
		local node: any = {
			ClassName = className,
			DescendantAdded = signal(),
			GetDescendants = function(): any
				return descendants or {}
			end,
			IsA = function(_self: any, name: string): boolean
				return className == name
			end,
			GetPropertyChangedSignal = function(_self: any, property: string): any
				if not changed[property] then
					changed[property] = signal()
				end
				return changed[property]
			end,
		}
		return setmetatable(node, {
			__index = function(_self: any, key: string): any
				return values[key]
			end,
			__newindex = function(_self: any, key: string, value: any)
				local previous = values[key]
				values[key] = value
				if previous ~= value and changed[key] then
					changed[key].fire()
				end
			end,
		})
	end
	local prompt = instance("ProximityPrompt", { ActionText = "Al", ObjectText = "Pazar" })
	local label = instance("TextLabel", { Text = "Pazar" })
	local gui = instance("BillboardGui", nil, { label })
	local playerGui = instance("PlayerGui")
	local world = instance("Workspace", nil, { prompt, gui, label })
	local node: any = {
		WaitForChild = function(self: any): any
			return self
		end,
	}
	local engine = {
		GetService = function(_self: any, name: string): any
			if name == "Workspace" then
				return world
			elseif name == "Players" then
				return { LocalPlayer = {
					WaitForChild = function(): any
						return playerGui
					end,
				} }
			end
			return node
		end,
	}
	local languageChanged = signal()
	local language = "en"
	local dictionaries = {
		en = { ["Al"] = "Buy", ["Pazar"] = "Market", ["Topla"] = "Collect" },
		de = { ["Al"] = "Kaufen", ["Pazar"] = "Markt", ["Topla"] = "Sammeln" },
	}
	startLocalizer(engine, {
		tr = function(source: string): string
			return dictionaries[language][source] or source
		end,
		onChanged = function(callback: any)
			languageChanged:Connect(callback)
		end,
	})
	assert(prompt.ActionText == "Buy" and prompt.ObjectText == "Market", "initial world prompts translate both fields")
	assert(label.Text == "Market", "world signs retain translation")
	prompt.ActionText = "Topla"
	assert(prompt.ActionText == "Collect", "source changes translate without recursion")
	language = "de"
	languageChanged.fire()
	assert(
		prompt.ActionText == "Sammeln" and prompt.ObjectText == "Markt",
		"language changes use original prompt source"
	)
	assert(label.Text == "Markt", "language changes use original sign source")
	local latePrompt = instance("ProximityPrompt", { ActionText = "Al", ObjectText = "Pazar" })
	world.DescendantAdded.fire(latePrompt)
	assert(latePrompt.ActionText == "Kaufen", "streamed prompts translate on arrival")
	for _ = 1, 100 do
		world.DescendantAdded.fire(gui)
		world.DescendantAdded.fire(latePrompt)
	end
	assert(gui.DescendantAdded.count() == 1, "reparenting world signs keeps one descendant listener")
	assert(
		latePrompt:GetPropertyChangedSignal("ActionText").count() == 1,
		"repeated streaming events keep one text listener"
	)
	local lateLabel = instance("TextLabel", { Text = "Al" })
	gui.DescendantAdded.fire(lateLabel)
	assert(lateLabel.Text == "Kaufen", "late sign labels translate")
	print("PASS client localizer: initial/streamed prompts, live text/language changes, idempotent sign watchers")
end
