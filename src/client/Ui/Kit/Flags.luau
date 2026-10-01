--!strict
-- Şekillerle çizilmiş bayraklar (Roblox yazı tipleri bayrak emojisini göstermez).
-- UiKit cephesi bunları birleştirir; bileşenleri `UiKit.<ad>` ile kullan.

local Tokens = require(script.Parent:WaitForChild("Tokens"))
local Base = require(script.Parent:WaitForChild("Base"))

local Flags = {}

---------------------------------------------------------------------------
-- Bayraklar: Roblox yazı tipleri bayrak emojisini göstermez, bu yüzden şekillerle çizilir (3:2 oran).
---------------------------------------------------------------------------

local function flagPart(
	parent: Instance,
	color: Color3,
	position: Vector2,
	size: Vector2,
	rotation: number?,
	round: boolean?
): Frame
	local part = Instance.new("Frame")
	part.BorderSizePixel = 0
	part.BackgroundColor3 = color
	part.AnchorPoint = Vector2.new(0.5, 0.5)
	part.Position = UDim2.fromScale(position.X, position.Y)
	part.Size = UDim2.fromScale(size.X, size.Y)
	part.Rotation = rotation or 0
	part.Parent = parent
	if round then
		local roundCorner = Instance.new("UICorner")
		roundCorner.CornerRadius = UDim.new(0.5, 0)
		roundCorner.Parent = part
	end
	return part
end

local FLAG_RED_TR = Color3.fromRGB(227, 10, 23)

local FLAG_WHITE = Color3.fromRGB(255, 255, 255)

local FLAG_BLUE_UK = Color3.fromRGB(1, 33, 105)

local FLAG_RED_UK = Color3.fromRGB(200, 16, 46)

local FLAG_DIAGONAL = math.deg(math.atan2(2, 3)) -- 3:2 bayrakta köşegenin açısı

local flagPainters: { [string]: (Frame) -> () } = {
	-- Kırmızı zemin, beyaz hilal (iki daire) ve yıldız (iki döndürülmüş kare)
	tr = function(flag: Frame)
		flag.BackgroundColor3 = FLAG_RED_TR
		flagPart(flag, FLAG_WHITE, Vector2.new(0.36, 0.5), Vector2.new(0.333, 0.5), 0, true)
		flagPart(flag, FLAG_RED_TR, Vector2.new(0.405, 0.5), Vector2.new(0.267, 0.4), 0, true)
		flagPart(flag, FLAG_WHITE, Vector2.new(0.585, 0.5), Vector2.new(0.1, 0.15), 0)
		flagPart(flag, FLAG_WHITE, Vector2.new(0.585, 0.5), Vector2.new(0.1, 0.15), 45)
	end,
	-- Birleşik Krallık bayrağı (Union Jack)
	en = function(flag: Frame)
		flag.BackgroundColor3 = FLAG_BLUE_UK
		flagPart(flag, FLAG_WHITE, Vector2.new(0.5, 0.5), Vector2.new(1.4, 0.2), FLAG_DIAGONAL)
		flagPart(flag, FLAG_WHITE, Vector2.new(0.5, 0.5), Vector2.new(1.4, 0.2), -FLAG_DIAGONAL)
		flagPart(flag, FLAG_RED_UK, Vector2.new(0.5, 0.5), Vector2.new(1.4, 0.07), FLAG_DIAGONAL)
		flagPart(flag, FLAG_RED_UK, Vector2.new(0.5, 0.5), Vector2.new(1.4, 0.07), -FLAG_DIAGONAL)
		flagPart(flag, FLAG_WHITE, Vector2.new(0.5, 0.5), Vector2.new(1, 0.34))
		flagPart(flag, FLAG_WHITE, Vector2.new(0.5, 0.5), Vector2.new(0.227, 1))
		flagPart(flag, FLAG_RED_UK, Vector2.new(0.5, 0.5), Vector2.new(1, 0.2))
		flagPart(flag, FLAG_RED_UK, Vector2.new(0.5, 0.5), Vector2.new(0.133, 1))
	end,
	-- Siyah / kırmızı / altın yatay şeritler
	de = function(flag: Frame)
		flag.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		flagPart(flag, Color3.fromRGB(221, 0, 0), Vector2.new(0.5, 0.5), Vector2.new(1, 0.334))
		flagPart(flag, Color3.fromRGB(255, 206, 0), Vector2.new(0.5, 0.833), Vector2.new(1, 0.334))
	end,
	-- Beyaz / mavi / kırmızı yatay şeritler
	ru = function(flag: Frame)
		flag.BackgroundColor3 = FLAG_WHITE
		flagPart(flag, Color3.fromRGB(0, 57, 166), Vector2.new(0.5, 0.5), Vector2.new(1, 0.334))
		flagPart(flag, Color3.fromRGB(213, 43, 30), Vector2.new(0.5, 0.833), Vector2.new(1, 0.334))
	end,
	-- Kırmızı / sarı (iki kat geniş) / kırmızı yatay şeritler
	es = function(flag: Frame)
		flag.BackgroundColor3 = Color3.fromRGB(170, 21, 27)
		flagPart(flag, Color3.fromRGB(241, 191, 0), Vector2.new(0.5, 0.5), Vector2.new(1, 0.5))
	end,
	-- Yeşil zemin, sarı baklava (45° döndürülmüş kare) ve mavi daire
	pt = function(flag: Frame)
		flag.BackgroundColor3 = Color3.fromRGB(0, 156, 59)
		flagPart(flag, Color3.fromRGB(255, 223, 0), Vector2.new(0.5, 0.5), Vector2.new(0.36, 0.54), 45)
		flagPart(flag, Color3.fromRGB(0, 39, 118), Vector2.new(0.5, 0.5), Vector2.new(0.2, 0.3), 0, true)
	end,
}

-- Ülke/dil kodundan (tr, en, de, ru, es, pt) çizilmiş bayrak; genişlik piksel, yükseklik 2/3'ü.
function Flags.flag(parent: Instance, code: string, width: number): Frame
	local flag = Instance.new("Frame")
	flag.Name = "Flag"
	flag.Size = UDim2.fromOffset(width, math.floor(width * 2 / 3))
	flag.BackgroundColor3 = Tokens.Color.SurfaceRaised
	flag.BorderSizePixel = 0
	flag.ClipsDescendants = true
	flag.Parent = parent
	Base.corner(flag, math.max(2, math.floor(width / 10)))
	local paint = flagPainters[code]
	if paint then
		paint(flag)
	end
	Base.stroke(flag, 0.6)
	return flag
end

return Flags
