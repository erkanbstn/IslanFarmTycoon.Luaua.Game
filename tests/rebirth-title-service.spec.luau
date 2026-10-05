--!strict
-- Rebirth ünvanı servisi (sahte oyuncu/karakter): doğma, sayı değişimi, yeniden doğma, ayrılma temizliği, 0'da gizli.
return function(createService: any, RebirthTitles: any)
	local function signal(): any
		local callbacks: { any } = {}
		local self: any = { live = 0 }
		function self.Connect(_s: any, callback: any): any
			table.insert(callbacks, callback)
			self.live += 1
			local connection = { connected = true }
			function connection.Disconnect(c: any)
				if c.connected then
					c.connected = false
					self.live -= 1
					local index = table.find(callbacks, callback)
					if index then
						table.remove(callbacks, index)
					end
				end
			end
			return connection
		end
		function self.fire(...: any)
			for _, callback in table.clone(callbacks) do
				callback(...)
			end
		end
		return self
	end

	local playersService: any = {
		PlayerAdded = signal(),
		PlayerRemoving = signal(),
		list = {} :: { any },
	}
	function playersService.GetPlayers(self: any): { any }
		return self.list
	end
	local node: any = {}
	function node.WaitForChild(self: any): any
		return self
	end
	local gameMock: any = {}
	function gameMock.GetService(_self: any, name: string): any
		return if name == "Players" then playersService else node
	end
	local taskMock = {
		spawn = function(callback: any, ...: any)
			callback(...)
		end,
	}
	local vectorMock = {
		new = function(x: number, y: number, z: number): any
			return { X = x, Y = y, Z = z }
		end,
	}

	local tags: { any } = {}
	local worldUi = {
		tag = function(parent: any, name: string, options: any): any
			local tag: any = { Parent = parent, Name = name, options = options, destroyed = false }
			function tag.Destroy(self: any)
				self.destroyed = true
				self.Parent = nil
			end
			table.insert(tags, tag)
			parent.children[name] = tag
			return tag
		end,
		setTag = function(tag: any, text: string)
			tag.options.text = text
			tag.updates = (tag.updates or 0) + 1
		end,
	}
	local function liveTags(): number
		local count = 0
		for _, tag in tags do
			if not tag.destroyed then
				count += 1
			end
		end
		return count
	end

	local counts: { [any]: number? } = {}
	local function newCharacter(hasHead: boolean): any
		local character: any = { Parent = {}, children = {} }
		local head: any = { children = {}, Parent = character }
		function head.IsA(_self: any, className: string): boolean
			return className == "BasePart"
		end
		if hasHead then
			character.children.Head = head
		end
		function character.FindFirstChild(self: any, name: string): any
			return self.children[name]
		end
		function character.WaitForChild(self: any, name: string): any
			return self.children[name]
		end
		character.head = head
		return character
	end
	local function newPlayer(): any
		local player: any = {
			CharacterAdded = signal(),
			CharacterRemoving = signal(),
			attributeSignal = signal(),
		}
		function player.GetAttributeChangedSignal(self: any, _name: string): any
			return self.attributeSignal
		end
		return player
	end
	local function spawnCharacter(player: any, hasHead: boolean?): any
		local character = newCharacter(hasHead ~= false)
		player.Character = character
		player.CharacterAdded.fire(character)
		return character
	end
	local function tagOf(character: any): any
		local tag = character.head.children.RebirthTitle
		return if tag and not tag.destroyed then tag else nil
	end

	local service = createService(gameMock, taskMock, vectorMock, RebirthTitles, worldUi)
	local alice = newPlayer()
	counts[alice] = 0
	-- Zaten sahnede olan oyuncu ve karakteri
	local existing = newCharacter(true)
	alice.Character = existing
	table.insert(playersService.list, alice)
	service.init(function(player: any): number?
		return counts[player]
	end)
	assert(tagOf(existing) == nil and liveTags() == 0, "zero rebirths shows no tag")

	-- Rebirth: etiket anında görünür
	counts[alice] = 1
	service.refresh(alice)
	local tag = tagOf(existing)
	assert(tag and tag.options.text == "R1 · Çırak", "first rebirth shows R1 title")
	assert(tag.options.maxDistance == 60, "tag distance is bounded")
	assert(tag.AlwaysOnTop == false, "tag is not always on top")
	assert(tag.options.worldOffset.Y > 2, "tag floats above the head")
	assert(tag.Parent == existing.head, "tag attaches to the head")

	-- Aynı metin: yeni yazım yok; değişince yerinde güncellenir (yeniden kurulmaz)
	service.refresh(alice)
	assert(tag.updates == nil and liveTags() == 1, "unchanged text does not rewrite or recreate")
	counts[alice] = 3
	service.refresh(alice)
	assert(tagOf(existing) == tag and tag.options.text == "R3 · Çiftçi", "tag updates in place on rebirth")
	assert(tag.updates == 1, "exactly one update was written")

	-- Geçersiz/yüklenmemiş sayı etiketi kaldırır; sonra geri gelir
	counts[alice] = nil
	service.refresh(alice)
	assert(liveTags() == 0, "missing save data hides the tag")
	counts[alice] = 0 / 0
	service.refresh(alice)
	assert(liveTags() == 0, "NaN hides the tag")
	counts[alice] = 30
	service.refresh(alice)
	assert(tagOf(existing).options.text == "R30 · Takımada Şampiyonu", "final tier is shown")

	-- Yeniden doğma: eski etiket gider, yeni karakterde kurulur
	assert(liveTags() == 1, "one live tag before respawn")
	alice.CharacterRemoving.fire(existing)
	assert(liveTags() == 0, "removing the character destroys the tag")
	local respawned = spawnCharacter(alice)
	assert(
		tagOf(respawned) and tagOf(respawned).options.text == "R30 · Takımada Şampiyonu",
		"respawn rebuilds the tag"
	)
	assert(liveTags() == 1, "only one tag after respawn")

	-- Eski karakter olayı yeni karakteri etkilemez
	alice.CharacterRemoving.fire(existing)
	assert(liveTags() == 1, "stale character removal is ignored")

	-- WorldReady değişimi (veri sonradan yüklendi)
	local late = newPlayer()
	counts[late] = nil
	playersService.PlayerAdded.fire(late)
	local lateCharacter = spawnCharacter(late)
	assert(tagOf(lateCharacter) == nil, "no tag before save data exists")
	counts[late] = 2
	late.attributeSignal.fire()
	assert(tagOf(lateCharacter) and tagOf(lateCharacter).options.text == "R2 · Çırak", "WorldReady builds the tag")

	-- Head olmayan karakter: etiket yok, hata yok
	local headless = newPlayer()
	counts[headless] = 5
	playersService.PlayerAdded.fire(headless)
	local headlessCharacter = spawnCharacter(headless, false)
	assert(tagOf(headlessCharacter) == nil, "no head means no tag")

	-- Veri kaybolunca etiket düşer
	local flaky = newPlayer()
	playersService.PlayerAdded.fire(flaky)
	counts[flaky] = 4
	local flakyCharacter = spawnCharacter(flaky)
	assert(tagOf(flakyCharacter) ~= nil, "flaky player starts with a tag")
	counts[flaky] = nil
	service.refresh(flaky)
	assert(tagOf(flakyCharacter) == nil, "tag removed when data disappears")

	-- Sayı okuyucusu hata verirse servis çökmez
	local broken = newPlayer()
	playersService.PlayerAdded.fire(broken)
	counts[broken] = 7
	local brokenCharacter = spawnCharacter(broken)
	assert(tagOf(brokenCharacter) ~= nil, "broken player starts with a tag")
	counts[broken] = nil

	-- Ayrılma: etiket yok edilir, bağlantılar kopar, sonraki refresh etkisiz
	local live = liveTags()
	playersService.PlayerRemoving.fire(late)
	assert(liveTags() == live - 1, "leaving destroys the player's tag")
	assert(late.CharacterAdded.live == 0 and late.CharacterRemoving.live == 0, "character connections released")
	assert(late.attributeSignal.live == 0, "attribute connection released")
	service.refresh(late)
	late.attributeSignal.fire()
	assert(liveTags() == live - 1, "refresh after leaving does nothing")
	late.CharacterAdded.fire(newCharacter(true))
	assert(liveTags() == live - 1, "no tag is built for a player who left")

	for _, player in { alice, headless, flaky, broken } do
		playersService.PlayerRemoving.fire(player)
		assert(
			player.CharacterAdded.live == 0 and player.CharacterRemoving.live == 0 and player.attributeSignal.live == 0,
			"all connections released"
		)
	end
	assert(liveTags() == 0, "no tags remain after everyone left")

	-- init ikinci kez çağrılırsa çift bağlantı kurmaz
	local addedLive = playersService.PlayerAdded.live
	service.init(function(): number?
		return 1
	end)
	assert(playersService.PlayerAdded.live == addedLive, "init is idempotent")
	print("PASS rebirth title service: bind, update, respawn, leave cleanup and hidden at zero")
end
