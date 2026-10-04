--!strict
-- Gerçek pano kaynağı: tamamlanan sipariş kalan stoğu yeni teslim gereksinimi gibi göstermez.
return function(createBoard: any)
	local callbacks = {}
	local function node(): any
		return {
			WaitForChild = function(self: any): any
				return self
			end,
			Activated = {
				Connect = function(_self: any, callback: any)
					table.insert(callbacks, callback)
				end,
			},
		}
	end
	local root = node()
	root.GetServerTimeNow = function(): number
		return 100
	end
	local game = {
		GetService = function(): any
			return root
		end,
	}
	local card: any
	local ui = {
		Color = {},
		sectionHeader = function(): any
			return node(), node()
		end,
		disclosure = function(): any
			return { frame = node(), body = node() }
		end,
		text = node,
		autoGrid = node,
		autoTile = function(): any
			card = { frame = node(), title = node(), detail = node(), icon = node(), action = node() }
			return card
		end,
		setVariant = function(button: any, variant: string)
			button.variant = variant
			button.Active = variant == "primary"
		end,
	}
	local offer =
		{ key = "0:1:fish", reward = 26900, displayName = "Toptan", lines = { { goodsId = "fish", amount = 1 } } }
	local farmMath = {
		getContractOffers = function(): any
			return { offer }
		end,
		getContractSecondsLeft = function(): number
			return 100
		end,
		getGoodsAmount = function(state: any): number
			return state.fish
		end,
		canFulfillContract = function(state: any): boolean
			return state.fish >= 1
		end,
		isContractDone = function(state: any): boolean
			return state.done
		end,
		formatMoney = function(amount: number): string
			return `$ {amount}`
		end,
	}
	local submissions = 0
	local pending = false
	local purchases = {
		isPending = function(): boolean
			return pending
		end,
		submit = function(remote: string, key: string)
			assert(remote == "RequestFulfillContract" and key == offer.key, "delivery uses the active server offer key")
			submissions += 1
		end,
	}
	local board = createBoard(
		game,
		{
			GOODS_CONTRACTS = { slots = 1 },
			GOODS = { fish = { displayName = "Balık", icon = "fish" } },
		},
		farmMath,
		{
			getSeason = function(): any
				return {}
			end,
		},
		ui,
		purchases
	)
	local update = board.create(root)
	local state = { done = false, fish = 0 }
	update(state)
	assert(card.action.Text == "Yeterli ürün yok" and not card.action.Active, "fresh empty order is never delivered")
	assert(string.find(card.detail.Text, "0/1", 1, true), "an undelivered order shows actual stock")
	state.fish = 1
	update(state)
	assert(card.action.Text == "Teslim et" and card.action.Active, "sufficient stock enables delivery")
	callbacks[1]()
	assert(submissions == 1, "delivery sends the selected offer key")
	pending = true
	update(state)
	assert(not card.action.Active, "a pending request cannot be resubmitted")
	state.done, state.fish, pending = true, 0, false
	update(state)
	assert(card.action.Text == "Teslim edildi" and card.action.variant == "owned", "completion stays visible")
	assert(not string.find(card.detail.Text, "0/1", 1, true), "consumed stock is not presented as missing delivery")
	assert(not string.find(card.detail.Text, "Ödül:", 1, true), "completed slots do not advertise a future reward")
	callbacks[1]()
	assert(submissions == 1, "completed orders cannot be resubmitted")
	offer.key, offer.reward = "0:1:new", 50000
	update(state)
	assert(not string.find(card.detail.Text, "50000", 1, true), "a changed quote in a used slot is not claimed as paid")
	state.done = false
	update(state)
	assert(card.action.Text == "Yeterli ürün yok", "a refreshed window clears completion")
	print("PASS board UI: fresh, ready, pending, completed, consumed stock and refreshed quote")
end
