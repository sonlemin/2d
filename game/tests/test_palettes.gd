extends Node
## The palette tokens and their contrast (Story 1.18 AC1, AC2, AC4, AC5; UX-DR1–UX-DR9, UX-DR130,
## UX-DR131). Independent of the code (D4): its own WCAG 2.x contrast function, held to known
## answers, and its own copy of DESIGN.md's tables. It compares Palettes against those and never
## derives an expected value from Palettes. Colour maths is on 8-bit ints with half-up rounding
## (DESIGN's tokens reproduce exactly that way; banker's rounding would give Umber's gutter #100d0b).
## Ratios compare as integer hundredths, DESIGN's two decimals.
## Headless checks colours, rects and signals; legibility at Deck size is sonlm's look (Task 9).
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_palettes.gd

const DeckMock := preload("res://tests/deck_mock.gd")
const RoomSweep := preload("res://tests/room_sweep.gd")

## DESIGN Colors > Contrast floors (log 2026-11-11): 4.5:1 for text, 3:1 for UI shapes. Local, not
## spec.gd: the GDD has no contrast line for spec_citation to cite (D4).
const TEXT_MIN := 4.5
const SHAPE_MIN := 3.0
const GUTTER_PCT := 55  ## DESIGN colors: "Gutter fill: zone index 0 darkened to 55%" (A2, UX-DR4)

const AMBER := "ffd27a"  ## DESIGN colors chain-amber (UX-DR1)
const RED := "d9473f"  ## DESIGN colors predator-red (UX-DR2)
## DESIGN.md per zone, in DESIGN order: the front-matter `colors` and `components.zone-roles`
## (world 0–3, gutter, the six roles), Colors > Contrast floors (every ratio as hundredths, on the
## gutter / on the play area; `was`: the base index before its override) and the edge-cue glow floor
## paragraph (glow hex, step toward predator-red, ratio on index 0). `*_step` is the override's
## "lightened N% toward index 3" (0: no override).
const DESIGN := {
	&"dusk": {
		world = ["2b1d14", "6b4a2f", "b08a5a", "d8c3a0"],  # zone-dusk-0..3
		hp = "d8c3a0", label = "b08a5a", empty = "836548", rule = "6b4a2f", surface = "2b1d14", gutter = "18100b",
		label_step = 0, empty_step = 22,  # ui-label-dusk "passes as is"; ui-empty-dusk "lightened 22%"
		ratios = {hp = [1094, 949], label = [593, 514], empty = [351, 304], amber = [1320, 1145], red = [440, 382]},
		was = {empty = [237, 205]},  # "index 1 was 2.37 / 2.05"
		glow = "bb4038", glow_step = 83, glow_ratio = 303,  # "about 83% predator red in Dusk (#bb4038, 3.03:1)"
	},
	&"umber": {
		world = ["1e1714", "4a3a33", "7d6a5c", "a99a8c"],  # zone-umber-0..3
		hp = "a99a8c", label = "8f7e70", empty = "726258", rule = "4a3a33", surface = "1e1714", gutter = "110d0b",
		label_step = 41, empty_step = 42,  # ui-label-umber "lightened 41%"; ui-empty-umber "lightened 42%"
		ratios = {hp = [708, 647], label = [496, 453], empty = [332, 303], amber = [1358, 1242], red = [453, 414]},
		was = {label = [376, 344], empty = [179, 164]},
		glow = "b23d36", glow_step = 79, glow_ratio = 304,  # "79% in Umber (#b23d36, 3.04:1)"
	},
	&"violet": {
		world = ["0d0b14", "2a2440", "4f5d75", "a9b4c2"],  # zone-violet-0..3
		hp = "a9b4c2", label = "6e7b8f", empty = "5c5c73", rule = "2a2440", surface = "0d0b14", gutter = "07060b",
		label_step = 34, empty_step = 39,  # ui-label-violet "lightened 34%"; ui-empty-violet "lightened 39%"
		ratios = {hp = [961, 930], label = [471, 455], empty = [311, 301], amber = [1419, 1372], red = [473, 458]},
		was = {label = [303, 293], empty = [137, 133]},
		glow = "a63834", glow_step = 75, glow_ratio = 301,  # "75% in Cold violet (#a63834, 3.01:1)"
	},
}
## Role -> its DESIGN key; the base index of a role that may carry an override (DESIGN Zone-matched
## UI roles: Label 2, Empty 1); its floor (D5).
const ROLE_KEYS := {Palettes.Role.HP: "hp", Palettes.Role.LABEL: "label", Palettes.Role.EMPTY: "empty",
		Palettes.Role.RULE: "rule", Palettes.Role.SURFACE: "surface", Palettes.Role.GUTTER: "gutter"}
const OVERRIDE_BASE := {"label": 2, "empty": 1}
const OVERRIDE_FLOOR := {"label": TEXT_MIN, "empty": SHAPE_MIN}

var _fail := 0
var _changed := 0


func run() -> void:
	Game.reset_for_tests()
	_test_known_answers()
	_test_tokens()
	_test_derived()
	_test_floor_errors()
	_test_overrides()
	_test_glow_floor()
	_test_ratios()
	_test_game_palette()
	_test_zones()
	_test_spark()
	await _test_deck_mock()
	Game.reset_for_tests()
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


# --- The test's own colour maths (D4): never Palettes' -------------------------------------------

static func hex8(c: Color) -> Array[int]:
	return [c.r8, c.g8, c.b8]


static func of(hex: String) -> Array[int]:
	return hex8(Color("#" + hex))


## WCAG 2.x relative luminance of an 8-bit sRGB colour.
static func lum(c8: Array[int]) -> float:
	var lin := func(v8: int) -> float:
		var v := v8 / 255.0
		return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * lin.call(c8[0]) + 0.7152 * lin.call(c8[1]) + 0.0722 * lin.call(c8[2])


static func contrast(a: Array[int], b: Array[int]) -> float:
	var la := lum(a)
	var lb := lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## As DESIGN's two decimals, in hundredths, so a ratio is compared as an int.
static func hundredths(x: float) -> int:
	return roundi(x * 100.0)


## `a` moved `pct` percent toward `b`, per channel, rounded half up (roundi: 16.5 -> 17, probed).
static func blend8(a: Array[int], b: Array[int], pct: int) -> Array[int]:
	var out: Array[int] = []
	for i in 3:
		out.append(roundi(a[i] + (b[i] - a[i]) * pct / 100.0))
	return out


## DESIGN A2: index 0 at 55% per 8-bit channel, half up, in integers so 30 x 0.55 = 16.5 is exact.
static func gutter8(c8: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for v in c8:
		out.append((v * GUTTER_PCT + 50) / 100)
	return out


static func html(c8: Array[int]) -> String:
	return Color8(c8[0], c8[1], c8[2]).to_html(false)


## Pure (D4): each row {name, fg, min} is checked against every background in `bgs` ({name: c8});
## one error per miss, "<name> on <bg>: <ratio> < <min>". [] when every row passes.
static func floor_errors(rows: Array, bgs: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for row: Dictionary in rows:
		for bg: String in bgs:
			var r := contrast(row.fg, bgs[bg])
			if r < row.min:
				errors.append("%s on %s: %.2f < %.1f" % [row.name, bg, r, row.min])
	return errors


## Palettes' colours for `zone` as floor rows: the text and shape roles plus the two reserved
## colours (D5). RULE is exempt (decorative, DESIGN A15) and checked to be index 1 instead.
static func floor_rows(zone: StringName) -> Array:
	return [
		{name = "%s hp" % zone, fg = hex8(Palettes.role_in(zone, Palettes.Role.HP)), min = TEXT_MIN},
		{name = "%s label" % zone, fg = hex8(Palettes.role_in(zone, Palettes.Role.LABEL)), min = TEXT_MIN},
		{name = "%s empty" % zone, fg = hex8(Palettes.role_in(zone, Palettes.Role.EMPTY)), min = SHAPE_MIN},
		{name = "%s amber" % zone, fg = hex8(Palettes.AMBER), min = TEXT_MIN},
		{name = "%s red" % zone, fg = hex8(Palettes.RED), min = SHAPE_MIN},
	]


## The zone's two backgrounds from DESIGN: its gutter fill and its play area (index 0).
static func backgrounds(zone: StringName) -> Dictionary:
	return {gutter = of(DESIGN[zone].gutter), play = of(DESIGN[zone].world[0])}


# --- Checks ---------------------------------------------------------------------------------------

## AC4: the contrast function, on WCAG's known answers.
func _test_known_answers() -> void:
	var white := of("ffffff")
	check(hundredths(contrast(white, of("000000"))) == 2100, "contrast: white on black is 21.00 (got %.4f)" % contrast(white, of("000000")))
	check(hundredths(contrast(of("767676"), white)) == 454, "contrast: #767676 on white is 4.54, the lightest grey that passes 4.5 (got %.4f)" % contrast(of("767676"), white))
	check(hundredths(contrast(of("777777"), white)) == 448, "contrast: #777777 on white is 4.48, one step lighter fails (got %.4f)" % contrast(of("777777"), white))
	check(contrast(white, of("000000")) == contrast(of("000000"), white), "contrast is symmetric")
	check(html(gutter8([30, 23, 20])) == "110d0b", "gutter8 rounds 30 x 0.55 = 16.5 half up, giving DESIGN's #110d0b (got #%s)" % html(gutter8([30, 23, 20])))


## AC1/AC4: every Palettes colour is DESIGN's hex.
func _test_tokens() -> void:
	check(Palettes.AMBER.to_html(false) == AMBER, "Palettes.AMBER is chain-amber #%s (got #%s)" % [AMBER, Palettes.AMBER.to_html(false)])
	check(Palettes.RED.to_html(false) == RED, "Palettes.RED is predator-red #%s (got #%s)" % [RED, Palettes.RED.to_html(false)])
	var want: Array[StringName] = [&"dusk", &"umber", &"violet"]
	check(Palettes.zones() == want, "zones() is DESIGN's order: dusk, umber, violet (got %s)" % [Palettes.zones()])
	check(Palettes.has_zone(&"umber") and not Palettes.has_zone(&"sepia"), "has_zone: umber yes, sepia no")
	check(Palettes.DEFAULT_ZONE == &"dusk", "DEFAULT_ZONE is dusk (UX D13: menus outside play use Dusk)")
	for zone: StringName in DESIGN:
		var d: Dictionary = DESIGN[zone]
		var bad := []
		for i in 4:
			if Palettes.world_in(zone, i).to_html(false) != d.world[i]:
				bad.append("world %d #%s" % [i, Palettes.world_in(zone, i).to_html(false)])
		for role: Palettes.Role in ROLE_KEYS:
			var key: String = ROLE_KEYS[role]
			if Palettes.role_in(zone, role).to_html(false) != d[key]:
				bad.append("%s #%s, DESIGN #%s" % [key, Palettes.role_in(zone, role).to_html(false), d[key]])
		if Palettes.glow_floor(zone).to_html(false) != d.glow:
			bad.append("glow #%s" % Palettes.glow_floor(zone).to_html(false))
		check(bad.is_empty(), "%s: the four world colours, six roles and glow floor are DESIGN's tokens (wrong: %s)" % [zone, bad])


## AC4: the roles that are a world index are that index; the gutter is index 0 at 55%, half up.
func _test_derived() -> void:
	for zone: StringName in DESIGN:
		var role := func(r: Palettes.Role) -> String: return Palettes.role_in(zone, r).to_html(false)
		var world := func(i: int) -> String: return Palettes.world_in(zone, i).to_html(false)
		check(role.call(Palettes.Role.HP) == world.call(3), "%s: HP is index 3 (#%s)" % [zone, role.call(Palettes.Role.HP)])
		check(role.call(Palettes.Role.RULE) == world.call(1), "%s: RULE is index 1, exempt from the floors as decorative (A15; #%s)" % [zone, role.call(Palettes.Role.RULE)])
		check(role.call(Palettes.Role.SURFACE) == world.call(0), "%s: SURFACE is index 0 (#%s)" % [zone, role.call(Palettes.Role.SURFACE)])
		var g := html(gutter8(hex8(Palettes.world_in(zone, 0))))
		check(role.call(Palettes.Role.GUTTER) == g, "%s: GUTTER is index 0 x 0.55 per channel, half up: #%s (got #%s)" % [zone, g, role.call(Palettes.Role.GUTTER)])


## AC4: the floor validator, its firing sample and its near-miss, then every zone through it.
func _test_floor_errors() -> void:
	var bgs := backgrounds(&"umber")
	var firing := floor_errors([{name = "umber label at index 2", fg = of(DESIGN[&"umber"].world[2]), min = TEXT_MIN}], bgs)
	var want_fire: Array[String] = ["umber label at index 2 on gutter: 3.76 < 4.5", "umber label at index 2 on play: 3.44 < 4.5"]
	check(firing == want_fire, "floor_errors fires on Umber LABEL left at index 2, on both backgrounds (got %s)" % [firing])
	var near := floor_errors([{name = "umber label", fg = of(DESIGN[&"umber"].label), min = TEXT_MIN}], bgs)
	check(near.is_empty(), "...and is quiet on the real override #8f7e70, 4.96 / 4.53 (got %s)" % [near])
	for zone: StringName in DESIGN:
		var errors := floor_errors(floor_rows(zone), backgrounds(zone))
		check(errors.is_empty(), "%s: HP, LABEL >= 4.5, EMPTY >= 3.0, amber >= 4.5, red >= 3.0 on the gutter and the play area (misses: %s)" % [zone, errors])


## AC4 (UX-DR7): LABEL and EMPTY are their base index blended toward index 3 by the smallest whole
## percent that passes both floors; that step is DESIGN's, it gives Palettes' colour, and one percent
## less fails.
func _test_overrides() -> void:
	for zone: StringName in DESIGN:
		var d: Dictionary = DESIGN[zone]
		var top := of(d.world[3])
		var bgs := backgrounds(zone)
		for key: String in OVERRIDE_BASE:
			var base := of(d.world[OVERRIDE_BASE[key]])
			var floor_min: float = OVERRIDE_FLOOR[key]
			var step := -1
			for pct in 101:
				if floor_errors([{name = key, fg = blend8(base, top, pct), min = floor_min}], bgs).is_empty():
					step = pct
					break
			var role: Palettes.Role = ROLE_KEYS.find_key(key)
			var got := Palettes.role_in(zone, role).to_html(false)
			check(step == d[key + "_step"], "%s %s: the smallest passing step toward index 3 is DESIGN's %d%% (got %d%%)" % [zone, key, d[key + "_step"], step])
			check(step >= 0 and html(blend8(base, top, step)) == got, "%s %s: index %d + %d%% is #%s, Palettes' colour (got #%s)" % [zone, key, OVERRIDE_BASE[key], step, html(blend8(base, top, maxi(step, 0))), got])
			if step > 0:
				var less := floor_errors([{name = key, fg = blend8(base, top, step - 1), min = floor_min}], bgs)
				check(not less.is_empty(), "%s %s: one percent less (%d%%) fails a floor (%s)" % [zone, key, step - 1, less])


## AC4 (UX-DR9): the glow floor is index 0 blended toward predator-red by the smallest whole percent
## that reaches 3.0 against index 0.
func _test_glow_floor() -> void:
	for zone: StringName in DESIGN:
		var d: Dictionary = DESIGN[zone]
		var base := of(d.world[0])
		var step := -1
		for pct in 101:
			if contrast(blend8(base, of(RED), pct), base) >= SHAPE_MIN:
				step = pct
				break
		var got := Palettes.glow_floor(zone).to_html(false)
		check(step == d.glow_step, "%s: the glow floor's smallest step toward red is DESIGN's %d%% (got %d%%)" % [zone, d.glow_step, step])
		check(html(blend8(base, of(RED), maxi(step, 0))) == got and got == d.glow, "%s: ...giving #%s, glow_floor() (got #%s)" % [zone, d.glow, got])
		check(step > 0 and contrast(blend8(base, of(RED), step - 1), base) < SHAPE_MIN, "%s: ...and %d%% stays under 3.0" % [zone, step - 1])
		var r := hundredths(contrast(of(got), base))
		check(r == d.glow_ratio, "%s: the glow floor is %.2f:1 on index 0 (got %.2f)" % [zone, d.glow_ratio / 100.0, r / 100.0])


## AC4: the function reproduces DESIGN's two-decimal table (a sanity check on the maths), the
## before-override ratios included.
func _test_ratios() -> void:
	for zone: StringName in DESIGN:
		var d: Dictionary = DESIGN[zone]
		var bgs := backgrounds(zone)
		var fg := {hp = of(d.hp), label = of(d.label), empty = of(d.empty), amber = of(AMBER), red = of(RED)}
		var bad := []
		for key: String in d.ratios:
			var got := [hundredths(contrast(fg[key], bgs.gutter)), hundredths(contrast(fg[key], bgs.play))]
			if got != d.ratios[key]:
				bad.append("%s %s, DESIGN %s" % [key, got, d.ratios[key]])
		for key: String in d.was:
			var c8 := of(d.world[OVERRIDE_BASE[key]])
			var got := [hundredths(contrast(c8, bgs.gutter)), hundredths(contrast(c8, bgs.play))]
			if got != d.was[key]:
				bad.append("%s before its override %s, DESIGN %s" % [key, got, d.was[key]])
		check(bad.is_empty(), "%s: every ratio matches DESIGN's Contrast floors tables to two decimals (wrong: %s)" % [zone, bad])


## AC2: Game.palette, the active zone.
func _test_game_palette() -> void:
	var p := Game.palette
	check(p.zone() == &"dusk", "Game.palette starts on dusk (got %s)" % p.zone())
	_changed = 0
	p.changed.connect(_on_changed)
	p.set_zone(&"umber")
	check(p.zone() == &"umber" and _changed == 1, "set_zone(umber) switches and emits changed once (got %s, %d)" % [p.zone(), _changed])
	p.set_zone(&"umber")
	check(_changed == 1, "set_zone() to the same zone emits nothing (got %d)" % _changed)
	var bad := []
	for role: Palettes.Role in ROLE_KEYS:
		if p.color(role) != Palettes.role_in(&"umber", role):
			bad.append(ROLE_KEYS[role])
	check(bad.is_empty(), "color(role) is role_in(zone, role) for every role (wrong: %s)" % [bad])
	check(p.color(Palettes.Role.SURFACE).to_html(false) == "1e1714", "...the umber surface is DESIGN's #1e1714")
	p.reset()
	check(p.zone() == &"dusk" and _changed == 2, "reset() goes back to dusk, emitting changed (got %s, %d)" % [p.zone(), _changed])
	p.set_zone(&"violet")
	Game.reset_for_tests()
	check(p.zone() == &"dusk" and Game.palette == p, "Game.reset_for_tests() resets the same instance to dusk (got %s)" % p.zone())
	p.changed.disconnect(_on_changed)


func _on_changed() -> void:
	_changed += 1


## AC1 (D9): the room validator takes its zone list from Palettes; every room file uses one.
func _test_zones() -> void:
	var ok := FileAccess.get_file_as_string("res://tests/rooms/ok_min.txt")
	var path := "res://x/ok_min.txt"
	for zone: StringName in Palettes.zones():
		var errors := RoomLoader.validate(path, RoomLoader.parse(ok.replace("zone=dusk", "zone=%s" % zone)))
		check(errors.is_empty(), "RoomLoader accepts zone=%s (got %s)" % [zone, errors])
	var bad := RoomLoader.validate(path, RoomLoader.parse(ok.replace("zone=dusk", "zone=sepia")))
	var want: Array[String] = [path + ":3:1 zone 'sepia' is not one of dusk, umber, violet"]
	check(bad == want, "...and rejects zone=sepia with the unchanged text (got %s)" % [bad])
	var files := RoomSweep.room_files()
	var off := []
	for f in files:
		var zone := ""
		for h: Dictionary in RoomLoader.parse(FileAccess.get_file_as_string(f)).header:
			if h.key == "zone":
				zone = h.value
		if not Palettes.has_zone(StringName(zone)):
			off.append("%s: '%s'" % [f, zone])
	check(not files.is_empty() and off.is_empty(), "every one of the %d files under res://rooms names a zone in Palettes.zones() (off: %s)" % [files.size(), off])


## AC3 (D8): the spark is the reserved amber exactly, not M1's #ffd17a.
func _test_spark() -> void:
	check(Fx.SPARK.to_html(false) == AMBER, "Fx.SPARK is chain-amber #ffd27a (got #%s)" % Fx.SPARK.to_html(false))


## AC5 (D12): each zone's Deck mock keeps every element inside its region: the left gutter's
## usable x 1–58, the right's x 421–478 (DESIGN spacing gutter-usable), or the play area x 60–420.
func _test_deck_mock() -> void:
	var regions := {&"left": Vector2(1, 59), &"right": Vector2(421, 479), &"play": Vector2(60, 420)}
	for zone: StringName in Palettes.zones():
		var mock := DeckMock.build(zone)
		add_child(mock)
		await get_tree().process_frame
		check(mock.size == Vector2(480, 270), "%s mock: 480x270 (got %s)" % [zone, mock.size])
		var counts := {&"left": 0, &"right": 0, &"play": 0}
		var outside := []
		var held: Label
		for n in mock.get_children():
			var c := n as Control
			if not c.has_meta(DeckMock.REGION):
				continue
			var region: StringName = c.get_meta(DeckMock.REGION)
			counts[region] += 1
			var r := c.get_rect()
			var span: Vector2 = regions[region]
			if r.position.x < span.x or r.end.x > span.y or r.position.y < 0 or r.end.y > 270 or r.size.x <= 0:
				outside.append("%s %s in %s" % [c.get_class(), r, region])
			if c is Label and (c as Label).text == "+1240":
				held = c
		check(outside.is_empty(), "%s mock: every element is inside its region (outside: %s)" % [zone, outside])
		check(counts[&"left"] >= 10 and counts[&"right"] >= 30 and counts[&"play"] >= 25, "%s mock: the check sees the HUD and the play text (left %d, right %d, play %d)" % [zone, counts[&"left"], counts[&"right"], counts[&"play"]])
		var end := held.position.x + held.get_minimum_size().x if held != null else -1.0
		check(held != null and end <= 46, "%s mock: +1240 starts at x 22 and ends by x 46, DESIGN's measured width (ends %s)" % [zone, end])
		mock.queue_free()
		await get_tree().process_frame
