--!strict
-- Island Farm Tycoon arayüz standardı: renkler, yazı tipleri, boyutlar ve hazır bileşenler.
-- Tüm arayüz (HUD, Pazar, Yol Haritası, Adalar menüsü) bunu kullanır; yeni UI yazarken de kullan.
--
-- Kurallar:
--  * Emoji SADECE ikon kutusunda (iconChip) kullanılır; buton ve metinlerde emoji yok.
--  * Kapat / bildirim işaretleri font karakteri değil, çizilmiş şekillerdir.
--  * Renk, yazı tipi ve boyutlar aşağıdaki tablolardan seçilir; elle değer yazma.

local Tokens = require(script.Parent:WaitForChild("Kit"):WaitForChild("Tokens"))
local Base = require(script.Parent:WaitForChild("Kit"):WaitForChild("Base"))
local Controls = require(script.Parent:WaitForChild("Kit"):WaitForChild("Controls"))
local Flags = require(script.Parent:WaitForChild("Kit"):WaitForChild("Flags"))
local Grid = require(script.Parent:WaitForChild("Kit"):WaitForChild("Grid"))
local Windows = require(script.Parent:WaitForChild("Kit"):WaitForChild("Windows"))
local Toasts = require(script.Parent:WaitForChild("Kit"):WaitForChild("Toasts"))
local Screen = require(script.Parent:WaitForChild("Kit"):WaitForChild("Screen"))

local UiKit = {}

-- Tipler
export type TextStyle = Base.TextStyle
export type Variant = Controls.Variant
export type Card = Controls.Card
export type Window = Windows.Window
export type WindowOptions = Windows.WindowOptions
export type ToastKind = Toasts.ToastKind

-- Renk, yazı tipi ve boyutlar dünyadaki tabelalarla ortak: shared/UiTheme
UiKit.Color = Tokens.Color
UiKit.Font = Tokens.Font
UiKit.TextSize = Tokens.TextSize
UiKit.Radius = Tokens.Radius
UiKit.MenuTileSize = Tokens.MenuTileSize
UiKit.MinTextSize = Tokens.MinTextSize
UiKit.TouchTarget = Tokens.TouchTarget

-- Bileşenler (gövde: Ui/Kit/*)
UiKit.colorText = Base.colorText
UiKit.corner = Base.corner
UiKit.stroke = Base.stroke
UiKit.padding = Base.padding
UiKit.textInput = Base.textInput
UiKit.list = Base.list
UiKit.text = Base.text
UiKit.setText = Base.setText
UiKit.iconChip = Base.iconChip
UiKit.panel = Base.panel
UiKit.progressBar = Base.progressBar
UiKit.sectionHeader = Base.sectionHeader
UiKit.setVariant = Controls.setVariant
UiKit.button = Controls.button
UiKit.pulse = Controls.pulse
UiKit.menuButton = Controls.menuButton
UiKit.slider = Controls.slider
UiKit.closeButton = Controls.closeButton
UiKit.badge = Controls.badge
UiKit.card = Controls.card
UiKit.grid = Grid.grid
UiKit.tile = Grid.tile
UiKit.autoGrid = Grid.autoGrid
UiKit.autoTile = Grid.autoTile
UiKit.tabs = Grid.tabs
UiKit.flag = Flags.flag
UiKit.window = Windows.window
UiKit.toastHost = Toasts.toastHost
UiKit.screenRoot = Screen.root
UiKit.screenScale = Screen.scale
UiKit.viewport = Screen.viewport

return UiKit
