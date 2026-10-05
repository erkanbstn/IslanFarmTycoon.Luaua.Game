--!strict
-- Servis spec'leri için ortak sahte dünya: oyuncu/kayıt, Remote'lar, hız sınırlayıcı, saat, döngü (task.spawn) ve sayaçlar.
-- Gerçek servis kaynağı çalışır; yalnızca Roblox'a dokunan sınırlar (game, Remotes, PlayerDataService...) sahtedir.
return function(createLimiter: any, codec: any, config: any, farmMath: any, createGuard: any)
	local function signal(): any
		local callbacks: { any } = {}
		return {
			Connect = function(_self: any, callback: any)
				table.insert(callbacks, callback)
			end,
			fire = function(...: any)
				for _, callback in callbacks do
					callback(...)
				end
			end,
		}
	end

	local harness = {}

	-- options.unlockAll: kaydın kalıcı yükseltmelerinin hepsi alınmış gelir
	function harness.new(options: { unlockAll: boolean? }?): any
		local h: any = {
			now = 600000 * 9 + 10,
			clockNow = 0,
			worldReady = true,
			active = true,
			hasPlot = true,
			saveOk = true,
			requestId = 0,
			sent = {},
			spawned = {},
			playersList = {},
			waitBudget = 0,
			counters = { pushes = 0, saves = 0, refreshes = 0, settles = 0 },
			metricCounts = {},
		}
		local serial = 0
		local function uid(): string
			serial += 1
			return `service-test-{serial}`
		end
		local data: any = assert(codec.decode(nil, config, farmMath, h.now, uid), "fixture decode failed")
		if options and options.unlockAll then
			for _, upgrade in config.UPGRADES do
				if not upgrade.leveled then
					data.purchased[upgrade.id] = true
				end
			end
			farmMath.applyDerived(data)
		end
		data.cash = 0
		h.data = data

		local function attribute(_self: any, name: string): any
			return if name == "WorldReady" then h.worldReady else nil
		end
		h.player = { UserId = 4242, GetAttribute = attribute, CharacterAdded = signal() }
		h.stranger = { UserId = 7, GetAttribute = attribute, CharacterAdded = signal() }

		local node: any = {}
		function node:WaitForChild(_name: string): any
			return self
		end
		function node:GetAttribute(_name: string): any
			return nil
		end
		h.node = node
		h.services = {
			Players = {
				PlayerRemoving = signal(),
				PlayerAdded = signal(),
				GetPlayers = function(_self: any): { any }
					return h.playersList
				end,
				GetPlayerByUserId = function(_self: any, userId: number): any
					return if userId == h.player.UserId then h.player else nil
				end,
			},
			HttpService = {
				GenerateGUID = function(_self: any): string
					return uid()
				end,
			},
			ProximityPromptService = { PromptTriggered = signal() },
			Workspace = {
				GetServerTimeNow = function(_self: any): number
					return h.now
				end,
			},
		}
		h.game = {
			GetService = function(_self: any, name: string): any
				return h.services[name] or node
			end,
		}
		-- Spam sınırlayıcı: her fire() saati ilerletir; fireRaw() ilerletmez (hız sınırı testi).
		h.osFake = {
			clock = function(): number
				return h.clockNow
			end,
			time = function(): number
				return h.now
			end,
		}
		h.limiter = createLimiter(h.game, h.osFake)
		h.dateTime = {
			now = function(): any
				return { UnixTimestamp = h.now, UnixTimestampMillis = h.now * 1000 }
			end,
		}
		-- task.spawn çalıştırılmaz, saklanır: runSpawned bir döngüyü tek tur çalıştırıp wait'te durdurur.
		h.delays = {}
		h.task = {
			spawn = function(callback: any, ...: any)
				local args = { ... }
				table.insert(h.spawned, function()
					callback(table.unpack(args))
				end)
			end,
			wait = function()
				if h.waitBudget <= 0 then
					error("loop-stop")
				end
				h.waitBudget -= 1
			end,
			delay = function(seconds: number, callback: any, ...: any)
				table.insert(h.delays, { seconds = seconds, callback = callback, args = { ... } })
			end,
		}
		function h.runSpawned(index: number, budget: number?)
			h.waitBudget = budget or 1
			local ok, err = pcall(h.spawned[index])
			assert(not ok and string.find(tostring(err), "loop-stop", 1, true), `loop did not stop cleanly: {err}`)
		end
		h.warn = function() end

		local events: { [string]: any } = {}
		h.remotes = {
			get = function(name: string): any
				local event = events[name]
				if not event then
					event = {
						OnServerEvent = signal(),
						FireClient = function(_self: any, target: any, ...: any)
							local args = { ... }
							table.insert(h.sent, {
								remote = name,
								target = target,
								args = args,
								id = args[1],
								ok = args[2],
								message = args[3],
							})
						end,
					}
					events[name] = event
				end
				return event
			end,
		}
		h.metrics = {
			increment = function(name: string, amount: number?)
				h.metricCounts[name] = (h.metricCounts[name] or 0) + (amount or 1)
			end,
		}
		h.dataService = {
			tryGet = function(target: any): any
				return if h.active and target == h.player then data else nil
			end,
			-- Gerçek PlayerDataService.trySpend gibi: goodsCost verilirse para ve ürün tek adımda düşer
			trySpend = function(target: any, amount: number, _reason: any, _sku: any, goodsCost: any): boolean
				if target ~= h.player or data.cash < amount then
					return false
				end
				if goodsCost ~= nil and next(goodsCost) ~= nil and not farmMath.removeGoodsBundle(data, goodsCost) then
					return false
				end
				data.cash -= amount
				return true
			end,
			addCash = function(_target: any, amount: number)
				data.cash += amount
			end,
			addRefund = function(_target: any, amount: number)
				data.cash += amount
			end,
			pushState = function()
				h.counters.pushes += 1
			end,
			requestSave = function()
				h.counters.saves += 1
			end,
			save = function(): boolean
				h.counters.saves += 1
				return h.saveOk
			end,
			getFarmIds = function(): { string }
				return { data.activeMainFarmId }
			end,
			getFarmView = function(): any
				return data
			end,
		}
		local plot: any = {
			FindFirstChild = function(): any
				return nil
			end,
		}
		h.plot = plot
		h.plotService = {
			getPlot = function(target: any): any
				return if h.hasPlot and target == h.player then plot else nil
			end,
			getAllPlots = function(): { any }
				return { plot }
			end,
			getOwner = function(target: any): any
				return if target == plot then h.player else nil
			end,
			isNearPlot = function(): boolean
				return h.near ~= false
			end,
			refreshPlayerWorld = function()
				h.counters.refreshes += 1
			end,
		}
		h.collectAmount = 0
		h.economyService = {
			startPlayer = function() end,
			collectRemote = function(): number
				local amount = h.collectAmount
				h.collectAmount = 0
				return amount
			end,
			settlePlayer = function()
				h.counters.settles += 1
			end,
		}
		h.dataService.transactAccount = function(target: any, mutate: any, after: any): (boolean, string?)
			local current = h.dataService.tryGet(target)
			if not current then
				return false, "inactive"
			end
			local ok, message = mutate(current)
			if not ok then
				return false, message
			end
			if h.dataService.markDirty then
				h.dataService.markDirty(target)
			end
			if not h.dataService.save(target) then
				return false, "save_pending"
			end
			if after then
				after()
			end
			return true, message
		end

		-- Gerçek RequestGuard, aynı sahte sınırlarla (Remotes, kayıt servisi, sınırlayıcı, sayaçlar)
		h.guard = createGuard(h.game, h.remotes, h.dataService, h.limiter, h.metrics)

		function h.nextId(): number
			h.requestId += 1
			return h.requestId
		end
		-- Remote'u tetikler ve bu çağrıda istemciye giden son cevabı (yoksa nil) döndürür.
		function h.fireRaw(target: any, name: string, ...: any): any
			local before = #h.sent
			h.remotes.get(name).OnServerEvent.fire(target, ...)
			return if #h.sent > before then h.sent[#h.sent] else nil
		end
		function h.fireAs(target: any, name: string, ...: any): any
			h.clockNow += 10
			return h.fireRaw(target, name, ...)
		end
		function h.fire(name: string, ...: any): any
			return h.fireAs(h.player, name, ...)
		end
		function h.sentCount(): number
			return #h.sent
		end
		return h
	end

	return harness
end
