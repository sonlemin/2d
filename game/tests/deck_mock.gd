extends RefCounted
## The ×2 Deck-size mock (Story 1.18 D12, UX-DR131, NFR12): a 480×270 picture of the gutter HUD
## and the play-area text at DESIGN's coordinates (Layout & Spacing, Shapes), in one zone's
## colours. screenshot.gd saves it ×2 for sonlm's Deck-size look; test_palettes checks every
## element sits in its region. A picture, not the HUD: Story 1.25 builds the real one, and nothing
## under scripts/ may use this. ColorRects and Labels only; every colour from Palettes.
## A helper, not a test (no test_/smoke_ prefix), and no class_name:
##   const DeckMock := preload("res://tests/deck_mock.gd")

## The meta key each element carries: &"left", &"right" or &"play". Fills and rules carry none:
## they draw the regions themselves.
const REGION := &"region"
const CHAIN_PEAK_SIZE := 32  ## DESIGN chain-number-peak; Fusion ×4 stands in for 1.26's hand-pixelled digits
const CHAIN_BASE_SIZE := 24  ## DESIGN chain-number (0–2 links); Fusion ×3 stands in
## DESIGN Shapes default icon art, X = drawn pixel.
const HEART := [".XX.XX.", "XXXXXXX", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."]
const LINK := ["..XXX..", ".X...X.", ".X...X.", ".X...X.", ".X...X.", ".X...X.", "..XXX.."]
const EMBER := [".XXX.", "XXXXX", "XXXXX", "XXXXX", ".XXX."]  ## the 5×5 blob, rows 3-5-5-5-3
## A test literal, never in strings.csv and never story copy (NR2): two pangrams, DESIGN's
## slot-detail format at a real line length, and the digits with Latin-1.
const BODY_LINES := [
	"Sphinx of black quartz, judge my vow.",
	"The five boxing wizards jump quickly.",
	"Depth S3 · Best chain 17 · 2:14 · Normal",
	"0123456789 +1240 x12 +24 ÆØÅ éèê ñ ß",
]


static func build(zone: StringName) -> Control:
	var root := Control.new()
	root.name = "DeckMock_%s" % zone
	root.theme = ThemeBuilder.theme()
	root.size = Vector2(480, 270)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var role := func(r: Palettes.Role) -> Color: return Palettes.role_in(zone, r)
	var surface: Color = role.call(Palettes.Role.SURFACE)
	var gutter: Color = role.call(Palettes.Role.GUTTER)
	var hp: Color = role.call(Palettes.Role.HP)
	var label: Color = role.call(Palettes.Role.LABEL)
	var empty: Color = role.call(Palettes.Role.EMPTY)
	var rule: Color = role.call(Palettes.Role.RULE)

	# Regions: the play area is zone index 0 (SURFACE), the floor test's play area.
	_rect(root, Rect2(60, 0, 360, 270), surface, &"")
	_rect(root, Rect2(0, 0, 60, 270), gutter, &"")
	_rect(root, Rect2(420, 0, 60, 270), gutter, &"")
	for x: int in [0, 59, 420, 479]:  # the inner and outer 1 px rules (O17)
		_rect(root, Rect2(x, 0, 1, 270), rule, &"")

	# Left gutter: heart centred x 30 at icon-top 10; pips x 26, y 24 + 10·n; held and carried rows.
	_bitmap(root, Vector2(27, 10), HEART, label, &"left")
	for n in 4:
		var pip := Rect2(26, 24 + 10 * n, 7, 7)
		if n < 3:
			_rect(root, pip, hp, &"left")
		else:
			_outline(root, pip, empty, &"left")
	_bitmap(root, Vector2(14, 96), EMBER, Palettes.AMBER, &"left")
	_text(root, "+1240", Vector2(22, 95), Palettes.AMBER, &"left")
	_bitmap(root, Vector2(14, 108), EMBER, hp, &"left")
	_text(root, "386", Vector2(22, 107), hp, &"left")

	# Right gutter: chain link centred x 450; the chain number centred x 450 at value-top 24; the
	# meter at x 444, segment n top y 258 − 9·(n − 1), 12 lit; the flare notch beside segment 2.
	_bitmap(root, Vector2(447, 10), LINK, label, &"right")
	var w := TextStyle.font().get_string_size("20", HORIZONTAL_ALIGNMENT_LEFT, -1, CHAIN_PEAK_SIZE).x
	_text(root, "20", Vector2(450 - w / 2.0, 24), Palettes.AMBER, &"right", CHAIN_PEAK_SIZE)
	for n in range(1, 21):
		var seg := Rect2(444, 258 - 9 * (n - 1), 12, 6)
		if n <= 12:
			_rect(root, seg, Palettes.AMBER, &"right")
		else:
			_outline(root, seg, empty, &"right")
	_rect(root, Rect2(458, 249, 3, 6), label, &"right")

	# Play area: every chain digit, 0–9 at 24 px (0 in EMPTY, as the chain at 0), 10–20 at 32 px.
	for i in 10:
		_text(root, str(i), Vector2(76 + 32 * i, 16), empty if i == 0 else Palettes.AMBER, &"play", CHAIN_BASE_SIZE)
	for i in range(10, 21):
		var k := i - 10 if i <= 15 else i - 16
		var top := 56 if i <= 15 else 96
		_text(root, str(i), Vector2(76 + 56 * k, top), Palettes.AMBER, &"play", CHAIN_PEAK_SIZE)

	# A body-line block (death-text-width 328 px, x 76–404, 12 px pitch) outlined in the surface,
	# as text over the play area is (UX-DR15); lines alternate HP / LABEL.
	for i in BODY_LINES.size():
		var l := Label.new()
		l.text = BODY_LINES[i]
		l.label_settings = TextStyle.play_text(hp if i % 2 == 0 else label, surface)
		l.position = Vector2(76, 144 + TextStyle.BODY_PITCH * i - TextStyle.CAP_TOP)
		l.size = Vector2(328, 0)
		l.set_meta(REGION, &"play")
		root.add_child(l)
	return root


## Cap top for a Fusion Label at `font_size`: ascent − cap, where cap is 6/8 of the size (DESIGN
## typography: cap 6 at 8). Probed on 4.7.2: ascent is 9/8 of the size at 8, 16, 24 and 32, so 3,
## 6, 9 and 12 (TextStyle.CAP_TOP and CAP_TOP_LARGE at 8 and 16).
static func cap_top(font_size: int) -> int:
	return roundi(TextStyle.font().get_ascent(font_size)) - font_size * 3 / 4


static func _rect(root: Control, r: Rect2, c: Color, region: StringName) -> ColorRect:
	var cr := ColorRect.new()
	cr.position = r.position
	cr.size = r.size
	cr.color = c
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if region != &"":
		cr.set_meta(REGION, region)
	root.add_child(cr)
	return cr


## DESIGN Shapes: an empty pip or segment is a 1 px outline of its full size, never a dim fill.
static func _outline(root: Control, r: Rect2, c: Color, region: StringName) -> void:
	_rect(root, Rect2(r.position, Vector2(r.size.x, 1)), c, region)
	_rect(root, Rect2(r.position.x, r.end.y - 1, r.size.x, 1), c, region)
	_rect(root, Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), c, region)
	_rect(root, Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), c, region)


## Icon art as one ColorRect per run of X in a row.
static func _bitmap(root: Control, at: Vector2, rows: Array, c: Color, region: StringName) -> void:
	for y in rows.size():
		var row: String = rows[y]
		var x := 0
		while x < row.length():
			if row[x] != "X":
				x += 1
				continue
			var start := x
			while x < row.length() and row[x] == "X":
				x += 1
			_rect(root, Rect2(at.x + start, at.y + y, x - start, 1), c, region)


## A Label whose cap top lands on `cap_at` (Story 1.17: Labels sit at y − CAP_TOP). Size 8 uses the
## HudValue variation (DESIGN hud-value); larger sizes stand in for the chain numerals.
static func _text(root: Control, s: String, cap_at: Vector2, c: Color, region: StringName, font_size := TextStyle.SIZE) -> Label:
	var l := Label.new()
	l.text = s
	if font_size == TextStyle.SIZE:
		l.theme_type_variation = ThemeBuilder.HUD_VALUE
	else:
		l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", c)
	l.position = Vector2(cap_at.x, cap_at.y - cap_top(font_size))
	l.set_meta(REGION, region)
	root.add_child(l)
	return l
