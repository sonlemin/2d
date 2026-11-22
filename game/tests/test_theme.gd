extends Node
## The font, the Theme and the play-area text style (Story 1.17 AC1–AC4; AR40, AR42, UX-DR11,
## UX-DR12, UX-DR15). Expected values come from DESIGN.md (Typography: the measured widths, cap 6,
## the line heights) and the 4.7.2 probes in the story, never from TextStyle's own consts.
## Headless measures fonts, Labels and LabelSettings; pixels (crispness, the outline as drawn) are
## the laptop look's, plus the story's one-off render probe.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_theme.gd

const FONT_PATH := "res://fonts/fusion-pixel-8px-proportional-latin.otf"  ## AC1
## DESIGN Typography, measured widths at size 8 (px). "+1240" was "about 25" in DESIGN's table;
## the probe measured 24, and code review corrected the table to it.
const WIDTHS_8 := {"0123456789": 50, "+1240": 24, "x12 +24": 33}
const DIGIT_W := 5  ## DESIGN: tabular digits, every digit 5 px wide at size 8
const CAP_HEIGHT := 6  ## DESIGN typography hud-value: cap 6 / x-height 4 / descender 2
## AC2: variation -> [font size, line pitch], from DESIGN's typography tokens.
const VARIATIONS := {
	&"HudValue": [8, 8],  ## hud-value: 8px / 8px
	&"HudValueLarge": [16, 16],  ## hud-value-large: 16px / 16px
	&"MenuItem": [8, 8],  ## menu-item: 8px / 8px
	&"BodyLine": [8, 12],  ## body-line: 8px / 12px
}
## AC3/D5: the outline copies, 1 px on four sides, no diagonals (DESIGN components.text-outline).
const OUTLINE_OFFSETS := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]

var _fail := 0


func run() -> void:
	Game.reset_for_tests()  # Fx.popup() reads the reduced-motion gate
	_test_font()
	_test_coverage()
	_test_widths()
	await _test_variations()
	_test_cap_top()
	_test_theme_cache()
	_test_play_text()
	_test_popups()
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


## AC1: the committed .import pins all four, so an editor re-import can't drift back to the
## defaults (antialiasing 1 survived the pixel-font auto-detect in the probe).
func _test_font() -> void:
	var f: FontFile = load(FONT_PATH)
	check(f != null, "the font loads from %s" % FONT_PATH)
	if f == null:
		return
	check(f.antialiasing == TextServer.FONT_ANTIALIASING_NONE, "font: antialiasing off (got %d)" % f.antialiasing)
	check(f.hinting == TextServer.HINTING_NONE, "font: hinting off (got %d)" % f.hinting)
	check(f.subpixel_positioning == TextServer.SUBPIXEL_POSITIONING_DISABLED, "font: subpixel positioning off (got %d)" % f.subpixel_positioning)
	check(not f.allow_system_fallback, "font: no system fallback, so a missing glyph never draws in another face")
	check(ProjectSettings.get_setting("gui/theme/custom_font") == FONT_PATH, "project.godot gui/theme/custom_font is the font (got %s)" % ProjectSettings.get_setting("gui/theme/custom_font"))
	check(ThemeDB.fallback_font == f, "ThemeDB.fallback_font is the font, so every Control draws it (D2; got %s)" % ThemeDB.fallback_font.resource_path)
	check(TextStyle.font() == f and TextStyle.FONT_PATH == FONT_PATH, "TextStyle.font() is the same font")


## AC1: Latin-1 and Latin Extended-A, except the soft hyphen (never drawn).
func _test_coverage() -> void:
	var f := TextStyle.font()
	var missing := []
	for range_: Array in [[0x20, 0x7E], [0xA0, 0x17F]]:
		for c in range(range_[0], range_[1] + 1):
			if c != 0xAD and not f.has_char(c):
				missing.append("U+%04X" % c)
	check(missing.is_empty(), "font covers U+0020–U+007E and U+00A0–U+017F but U+00AD (missing %s)" % [missing])


func _test_widths() -> void:
	var f := TextStyle.font()
	for s: String in WIDTHS_8:
		var w8 := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var w16 := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		check(w8 == WIDTHS_8[s] and w16 == 2 * w8, "'%s' is %d px at 8 and exactly x2 at 16 (got %s / %s)" % [s, WIDTHS_8[s], w8, w16])
	var digits := []
	for d in 10:
		digits.append(f.get_string_size(str(d), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	check(digits.all(func(w: float) -> bool: return w == DIGIT_W), "every digit is %d px at size 8 (got %s)" % [DIGIT_W, digits])


## AC2/D4: a variation's pitch is the height of a two-line Label minus a one-line one, under the
## built Theme (a bare Label would measure the size-16 fallback with line_spacing 3).
func _test_variations() -> void:
	var holder := Control.new()
	holder.theme = ThemeBuilder.theme()
	add_child(holder)
	for v: StringName in VARIATIONS:
		var one := Label.new()
		var two := Label.new()
		for l: Label in [one, two]:
			l.theme_type_variation = v
			holder.add_child(l)
		one.text = "Ag"
		two.text = "Ag\nAg"
		var size := one.get_theme_font_size(&"font_size")
		var pitch := two.get_minimum_size().y - one.get_minimum_size().y
		var want: Array = VARIATIONS[v]
		check(size == want[0] and pitch == want[1], "%s: size %d, line pitch %d px (got %d, %s)" % [v, want[0], want[1], size, pitch])
	var base := Label.new()
	holder.add_child(base)
	check(base.get_theme_font_size(&"font_size") == 8 and base.get_theme_font(&"font") == TextStyle.font(),
			"a plain Label under the theme draws the font at size 8 (got %d)" % base.get_theme_font_size(&"font_size"))
	check(TextStyle.MENU_ROW_PITCH == 24, "TextStyle.MENU_ROW_PITCH is DESIGN's menu-row-pitch 24px")
	holder.queue_free()
	await get_tree().process_frame


## D4: a Label's cap top sits (ascent - cap height) below its top; DESIGN's cap height is 6 at
## size 8 and 12 at the exact x2.
func _test_cap_top() -> void:
	var f := TextStyle.font()
	check(f.get_ascent(8) - CAP_HEIGHT == TextStyle.CAP_TOP, "CAP_TOP is ascent - DESIGN's cap 6 (ascent %s, CAP_TOP %d)" % [f.get_ascent(8), TextStyle.CAP_TOP])
	check(f.get_ascent(16) - 2 * CAP_HEIGHT == TextStyle.CAP_TOP_LARGE, "CAP_TOP_LARGE is ascent - cap 12 at size 16 (ascent %s, CAP_TOP_LARGE %d)" % [f.get_ascent(16), TextStyle.CAP_TOP_LARGE])


func _test_theme_cache() -> void:
	var t := ThemeBuilder.theme()
	check(t != null and t == ThemeBuilder.theme(), "ThemeBuilder.theme() returns one cached instance")
	check(t.default_font == TextStyle.font() and t.default_font_size == 8, "the theme's defaults are the font at size 8 (got %s)" % t.default_font_size)
	check(t.get_color_list(&"Label").is_empty() and t.get_color_type_list().is_empty(), "the theme carries no colours: UI reads Game.palette by role (Story 1.18 D6)")


## AC3/D5: cached per colour pair; four stacked shadows at the four offsets, each with outline 0;
## no font outline (it strokes diagonals too).
func _test_play_text() -> void:
	var c := Color("#ffd27a")
	var o := Color("#0d0b14")
	var s := TextStyle.play_text(c, o)
	check(s == TextStyle.play_text(c, o) and s == ThemeBuilder.play_text(c, o), "play_text() caches: the same colours give the same LabelSettings, through ThemeBuilder too")
	check(s != TextStyle.play_text(Color.WHITE, o) and s != TextStyle.play_text(c, Color.BLACK), "...and other colours give another one")
	check(s.font_size == 8 and s.font_color == c and s.outline_size == 0, "play_text: size 8, the glyph colour, no font outline (size %d, outline %d)" % [s.font_size, s.outline_size])
	# A Label with label_settings ignores the Theme's line_spacing (code review, probed: the
	# LabelSettings default 3 gave a 15 px pitch), so the pitch is measured, as in _test_variations.
	var holder := Control.new()
	holder.theme = ThemeBuilder.theme()
	add_child(holder)
	var one := Label.new()
	var two := Label.new()
	for l: Label in [one, two]:
		l.label_settings = s
		holder.add_child(l)
	one.text = "Ag"
	two.text = "Ag\nAg"
	var pitch := two.get_minimum_size().y - one.get_minimum_size().y
	var body: int = VARIATIONS[&"BodyLine"][1]
	check(pitch == body, "play_text: a two-line Label has DESIGN's body-line pitch, %d px (got %s)" % [body, pitch])
	holder.queue_free()
	var offsets := []
	var ok := s.stacked_shadow_count == 4
	for i in s.stacked_shadow_count:
		offsets.append(s.get_stacked_shadow_offset(i))
		ok = ok and s.get_stacked_shadow_color(i) == o and s.get_stacked_shadow_outline_size(i) == 0
	offsets.sort()
	var want := OUTLINE_OFFSETS.duplicate()
	want.sort()
	check(ok and offsets == want, "play_text: four shadows in the outline colour, outline 0, at (±1, 0) and (0, ±1) (count %d, offsets %s)" % [s.stacked_shadow_count, offsets])


## AC4: popups draw play_text at size 8, at every chain count.
func _test_popups() -> void:
	Game.palette.set_zone(&"umber")
	var parent := Node2D.new()
	add_child(parent)
	Fx.popup(parent, Vector2(10, 10), "+1", Color.WHITE)
	Fx.chain_popup(parent, Vector2(10, 10), 12, 24)
	var labels: Array = parent.get_children().filter(func(n: Node) -> bool: return n is Label)
	check(labels.size() == 2, "two popup Labels (got %d)" % labels.size())
	if labels.size() == 2:
		var a: Label = labels[0]
		var b: Label = labels[1]
		check(a.label_settings == TextStyle.play_text(Color.WHITE, Color("#1e1714")), "Fx.popup's Label carries play_text outlined in the active zone's surface (umber: DESIGN zone-umber-0 #1e1714; Story 1.18 D8)")
		check(b.label_settings == TextStyle.play_text(Color("#ffd27a"), Color("#1e1714")), "...and chain_popup's carries chain-amber #ffd27a on the same surface")
		check(b.label_settings != null and b.label_settings.font_size == 8 and b.text == "x12  +24", "chain_popup at 12 links is 8 px, not M1's 10 (D7; got %s, '%s')" % [b.label_settings.font_size if b.label_settings else -1, b.text])
		check(not a.has_theme_font_size_override(&"font_size") and not a.has_theme_constant_override(&"outline_size"), "...with no theme overrides left over from M1")
	parent.queue_free()
	Game.reset_for_tests()  # Testing standards (Story 1.18): a test that touches Game.palette ends with it
