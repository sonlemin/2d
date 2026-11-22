class_name TextStyle
## The game's one text style (AR40, Story 1.17 D3): the font, its sizes and line metrics, the menu
## row pitch and the play-area outline. In core/ because Fx draws the popups and lint core_layer
## keeps core/ from naming ui/; ui/theme_builder.gd builds the Theme from these consts.
## Line metrics (D4, probed on 4.7.2): at size 8 the font reports ascent 9, descent 3, height 12,
## and a Label's pitch (two lines minus one) is 12 + line_spacing. A Label's cap top sits
## CAP_TOP below its top, so a story that puts text on a DESIGN y coordinate (value-top, pip and
## menu rows assume an 8 px row) places the Label at y - CAP_TOP. No existing node moved.

const FONT_PATH := "res://fonts/fusion-pixel-8px-proportional-latin.otf"  ## Fusion Pixel Font 8px proportional, latin build, release 2026.11.10 (docs/build.md); OFL 1.1
const SIZE := 8  ## DESIGN typography hud-value / menu-item / body-line fontSize 8px: the face's native size (UX-DR11)
const SIZE_LARGE := 16  ## DESIGN hud-value-large fontSize 16px: an exact x2, never a fraction (D7)
const LINE_SPACING_SINGLE := -4  ## size 8: 12 + (-4) = DESIGN's 8 px lineHeight (hud-value, menu-item); probed two-line Label 20 px
const LINE_SPACING_BODY := 0  ## size 8: 12 + 0 = DESIGN body-line lineHeight 12px; probed two-line Label 24 px
const LINE_SPACING_LARGE := -8  ## size 16: 24 + (-8) = DESIGN hud-value-large lineHeight 16px
const BODY_PITCH := 12  ## DESIGN body-line lineHeight 12px, the row pitch of body text
const MENU_ROW_PITCH := 24  ## DESIGN spacing menu-row-pitch 24px, for the UI kit's rows (Story 1.31)
const CAP_TOP := 3  ## px from a size-8 Label's top to its cap top: ascent 9 - DESIGN cap height 6 (probed: label y 10, first glyph row y 13)
const CAP_TOP_LARGE := 6  ## the same at size 16: ascent 18 - cap 12
const OUTLINE_PX := 1  ## DESIGN spacing text-outline 1px, on 4 sides, no diagonals (UX-DR15)

## The four outline copies, behind the glyph: 4-neighbour, no diagonals (D5, render-probed).
const OUTLINE_OFFSETS: Array[Vector2] = [Vector2(OUTLINE_PX, 0), Vector2(-OUTLINE_PX, 0), Vector2(0, OUTLINE_PX), Vector2(0, -OUTLINE_PX)]

const _FONT := preload(FONT_PATH)

static var _play_text := {}  # "<color>|<outline>" -> LabelSettings


static func font() -> FontFile:
	return _FONT


## Text drawn over the play area (UX-DR15): size 8 with a 1 px four-side outline in
## `outline_color`, which callers pass as the active zone's surface
## (`Game.palette.color(Palettes.Role.SURFACE)`, DESIGN components.text-outline). Four stacked shadows at OUTLINE_OFFSETS, each with outline size 0: the font's
## own outline_size strokes the diagonals too, which UX-DR15 rules out. Cached per colour pair, so
## a popup never builds a resource of its own (project rule: shared resources are statics); the
## three zones add at most three entries per glyph colour while zones snap (E4's cross-fade must
## hand a popup the target zone's surface, never a blended one, or the cache grows per step: ledger).
## A Label with label_settings takes its line spacing from the settings, never from the Theme, and
## LabelSettings defaults to 3 (a 15 px pitch, probed in code review): so the body-line pitch is
## set here, for the death card and the "Not saved" note.
static func play_text(color: Color, outline_color: Color) -> LabelSettings:
	var key := color.to_html() + "|" + outline_color.to_html()
	var s: LabelSettings = _play_text.get(key)
	if s == null:
		s = LabelSettings.new()
		s.font = _FONT
		s.font_size = SIZE
		s.font_color = color
		s.line_spacing = LINE_SPACING_BODY
		s.stacked_shadow_count = OUTLINE_OFFSETS.size()
		for i in OUTLINE_OFFSETS.size():
			s.set_stacked_shadow_offset(i, OUTLINE_OFFSETS[i])
			s.set_stacked_shadow_color(i, outline_color)
			s.set_stacked_shadow_outline_size(i, 0)
		_play_text[key] = s
	return s
