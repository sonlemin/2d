class_name ThemeBuilder
## The game's one Theme, built in code from TextStyle (AR40, Story 1.17; no .tres). Gutters and
## ScreenRouter set it as their `theme`, so every HUD element and screen under them inherits it.
## Label type variations carry the DESIGN typography tokens: set `theme_type_variation` to one of
## the names below. Colours are not here: the palette roles are Story 1.18's.

const HUD_VALUE := &"HudValue"  ## DESIGN typography hud-value: size 8, 8 px rows
const HUD_VALUE_LARGE := &"HudValueLarge"  ## DESIGN hud-value-large: size 16, 16 px rows
const MENU_ITEM := &"MenuItem"  ## DESIGN menu-item: size 8, 8 px rows
const BODY_LINE := &"BodyLine"  ## DESIGN body-line: size 8, 12 px rows

static var _theme: Theme


## Built once and shared: every root that sets it holds the same instance, so a later change to
## it (Options' text size, if one ever lands) reaches every screen at once.
static func theme() -> Theme:
	if _theme == null:
		var t := Theme.new()
		t.default_font = TextStyle.font()
		t.default_font_size = TextStyle.SIZE
		t.set_constant(&"line_spacing", &"Label", TextStyle.LINE_SPACING_BODY)
		for row: Array in [
				[HUD_VALUE, TextStyle.SIZE, TextStyle.LINE_SPACING_SINGLE],
				[HUD_VALUE_LARGE, TextStyle.SIZE_LARGE, TextStyle.LINE_SPACING_LARGE],
				[MENU_ITEM, TextStyle.SIZE, TextStyle.LINE_SPACING_SINGLE],
				[BODY_LINE, TextStyle.SIZE, TextStyle.LINE_SPACING_BODY]]:
			t.set_type_variation(row[0], &"Label")
			t.set_font_size(&"font_size", row[0], row[1])
			t.set_constant(&"line_spacing", row[0], row[2])
		_theme = t
	return _theme


## UI-layer text drawn over the play area (the death card, the "Not saved" note): the same 1 px
## four-side outline as the popups (UX-DR15). Gutter and menu text use the theme, never this.
static func play_text(color: Color, outline_color: Color) -> LabelSettings:
	return TextStyle.play_text(color, outline_color)
