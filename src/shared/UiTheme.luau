--!strict
-- Ortak görsel dil: renkler, yazı tipleri, yazı boyutları.
-- Ekran arayüzü (client/UiKit) ve dünyadaki tabelalar (shared/WorldUi) bu tabloları kullanır.

local BUILDER_SANS = "rbxasset://fonts/families/BuilderSans.json"
local FREDOKA = "rbxasset://fonts/families/FredokaOne.json"

local UiTheme = {}

UiTheme.Color = {
	Panel = Color3.fromRGB(230, 247, 240),
	Surface = Color3.fromRGB(216, 242, 235),
	SurfaceRaised = Color3.fromRGB(184, 230, 218),
	Stroke = Color3.fromRGB(46, 133, 124),
	Text = Color3.fromRGB(22, 61, 63),
	TextMuted = Color3.fromRGB(58, 93, 95),
	OnAccent = Color3.fromRGB(255, 255, 252),
	WorldPanel = Color3.fromRGB(26, 48, 53),
	WorldText = Color3.fromRGB(250, 250, 255),
	WorldGold = Color3.fromRGB(255, 205, 60),
	Cream = Color3.fromRGB(241, 240, 219),
	Gold = Color3.fromRGB(153, 96, 11),
	GoldLight = Color3.fromRGB(255, 212, 100),
	Teal = Color3.fromRGB(21, 125, 113),
	Plum = Color3.fromRGB(117, 66, 139),
	PreviewMint = Color3.fromRGB(134, 226, 199),
	PreviewSky = Color3.fromRGB(148, 214, 246),
	PreviewLavender = Color3.fromRGB(207, 182, 243),
	PreviewSun = Color3.fromRGB(250, 217, 128),
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
