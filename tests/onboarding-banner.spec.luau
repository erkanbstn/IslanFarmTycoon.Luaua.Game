--!strict
-- İlk adımlar şeridi: dar ekranda sığma (ölçek + üst sınır), dokunma hedefi, menünün altında konum ve atla/tekrar göster akışı.
return function(createBanner: any)
	local function signal(): any
		local callbacks = {}
		return {
			Connect = function(_self: any, callback: any)
				table.insert(callbacks, callback)
			end,
			fire = function()
				for _, callback in callbacks do
					callback()
				end
			end,
		}
	end
	local created: { [string]: any } = {}
	local fakeInstance = {
		new = function(className: string): any
			local object: any = { ClassName = className, Visible = true }
			created[className] = object
			return object
		end,
	}
	local function size(xs: number, xo: number, ys: number, yo: number): any
		return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } }
	end
	local dimensions = {
		new = size,
		fromScale = function(x: number, y: number): any
			return size(x, 0, y, 0)
		end,
		fromOffset = function(x: number, y: number): any
			return size(0, x, 0, y)
		end,
	}
	local texts: { any } = {}
	local skipButton: any = nil
	local ui: any = {
		Color = { Panel = 1, Gold = 2 },
		Font = { Bold = "bold" },
		Radius = { Card = 8 },
		TextSize = { Caption = 14 },
		TouchTarget = 44,
		MenuTileSize = { Y = 56 },
		corner = function() end,
		stroke = function(): any
			return {}
		end,
		padding = function() end,
		list = function(): any
			return {}
		end,
		text = function(_parent: any, text: string): any
			local label: any = { Text = text }
			table.insert(texts, label)
			return label
		end,
		setText = function(label: any, text: string)
			label.Text = text
		end,
		button = function(): any
			skipButton = { Activated = signal() }
			return skipButton
		end,
	}
	local fakeEnum = {
		AutomaticSize = { Y = "Y" },
		HorizontalAlignment = { Center = "Center" },
		TextXAlignment = { Center = "Center" },
	}
	local skipped = 0
	local banner = createBanner(ui, fakeInstance, dimensions, {
		new = function(x: number, y: number): any
			return { X = x, Y = y }
		end,
	}, fakeEnum).create({}, function()
		skipped += 1
	end)
	local frame = banner.frame
	local limit = created.UISizeConstraint

	-- Telefon genişliğinde (320 mantıksal px) şerit ekrana sığar; masaüstünde üst sınırla kalır
	assert(frame.Size.X.Scale <= 0.9 and frame.Size.X.Offset == 0, "banner width is a screen fraction")
	assert(frame.AutomaticSize == "Y", "banner grows with wrapped text instead of clipping")
	assert(limit and limit.MaxSize.X <= 460, "banner has a desktop width cap")
	assert(frame.Size.X.Scale * 320 <= 320 and frame.AnchorPoint.X == 0.5, "banner is centered and fits a 320px screen")
	assert(
		frame.Position.Y.Offset >= ui.MenuTileSize.Y,
		"banner sits below the menu tiles so the pointer arrow stays visible"
	)
	assert(skipButton.Size.Y.Offset >= ui.TouchTarget, "skip button has a full touch target")

	-- Gösterme/gizleme ve atla/tekrar göster
	assert(not frame.Visible, "banner starts hidden")
	banner.show("İLK ADIMLAR 1/4", "Pazar'ı aç ve ilk hayvanını satın al")
	assert(frame.Visible, "show makes the banner visible")
	local shown = {}
	for _, label in texts do
		table.insert(shown, label.Text)
	end
	assert(
		table.find(shown, "İLK ADIMLAR 1/4") and table.find(shown, "Pazar'ı aç ve ilk hayvanını satın al"),
		"texts"
	)
	skipButton.Activated.fire()
	assert(not frame.Visible and skipped == 1, "skip hides the banner and notifies the server path")
	banner.show("İLK ADIMLAR 2/4", "Yeşil platforma basıp parayı topla")
	assert(frame.Visible, "banner can show again after the tutorial is replayed")
	banner.hide()
	assert(not frame.Visible, "hide removes the banner when no step remains")
	print("PASS onboarding banner: narrow-screen fit, touch target, position and skip/replay")
end
