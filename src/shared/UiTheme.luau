--!strict
-- Ortak görsel dil: renkler, yazı tipleri, yazı boyutları.
-- Ekran arayüzü (client/UiKit) ve dünyadaki tabelalar (shared/WorldUi) bu tabloları kullanır.

local BUILDER_SANS = "rbxasset://fonts/families/BuilderSans.json"
local FREDOKA = "rbxasset://fonts/families/FredokaOne.json"

local UiTheme = {}

UiTheme.Color = {
	Panel = Color3.fromRGB(255, 249, 236),
	Surface = Color3.fromRGB(255, 255, 252),
	SurfaceRaised = Color3.fromRGB(223, 239, 230),
	Stroke = Color3.fromRGB(98, 143, 129),
	Text = Color3.fromRGB(35, 63, 57),
	TextMuted = Color3.fromRGB(78, 102, 94),
	OnAccent = Color3.fromRGB(255, 255, 252),
	WorldPanel = Color3.fromRGB(26, 48, 53),
	WorldText = Color3.fromRGB(250, 250, 255),
	WorldGold = Color3.fromRGB(255, 205, 60),
	Cream = Color3.fromRGB(255, 244, 222),
	Gold = Color3.fromRGB(153, 96, 11),
	GoldLight = Color3.fromRGB(255, 212, 100),
	Teal = Color3.fromRGB(21, 125, 113),
	Plum = Color3.fromRGB(117, 66, 139),
	PreviewMint = Color3.fromRGB(176, 230, 207),
	PreviewSky = Color3.fromRGB(172, 213, 249),
	PreviewLavender = Color3.fromRGB(223, 197, 243),
	PreviewSun = Color3.fromRGB(255, 224, 151),
	PreviewAmbient = Color3.fromRGB(190, 196, 210),
	Green = Color3.fromRGB(23, 135, 86),
	GreenDark = Color3.fromRGB(34, 120, 76),
	Orange = Color3.fromRGB(178, 91, 18),
	Red = Color3.fromRGB(185, 48, 67),
	Blue = Color3.fromRGB(37, 102, 176),
	Disabled = Color3.fromRGB(220, 229, 221),
}

UiTheme.Font = {
	Display = Font.new(FREDOKA),
	Body = Font.new(BUILDER_SANS, Enum.FontWeight.Medium),
	Bold = Font.new(BUILDER_SANS, Enum.FontWeight.Bold),
}

UiTheme.TextSize = {
	Display = 26,
	Title = 20,
	Heading = 16,
	Body = 14,
	Caption = 12,
	LoadingTitle = 40,
	LoadingStatus = 18,
}

return UiTheme
