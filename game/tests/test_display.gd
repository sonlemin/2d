extends Node
## The display scale rule (AR8, NFR6, UX-DR147/148; Story 1.14 D8): `Display.scale_for()` /
## `stretch_for()` on both sides of every boundary, `window_scale_for()`, the project display
## settings the rule depends on, `Game.display` staying inert until `start()`, and `apply()`
## switching the stretch both ways while emitting `scale_changed` only on a change.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_display.gd
## The runner is headless, so `start()` must stay inert here: that is the real case, not a stub.
## The real window is the web smoke's (`Display scale`) and Task 7's desktop check.
## Not tested, because a failed assert aborts the test: a window with no area, and replacing
## `Game.display` (test_lint's `state_write` covers the second).

const EPS := 0.0001
const INT := Window.CONTENT_SCALE_STRETCH_INTEGER
const FRAC := Window.CONTENT_SCALE_STRETCH_FRACTIONAL
## D3: window → scale, stretch. Both sides of every boundary.
const SCALES := [
	[Vector2i(480, 270), 1.0, INT],
	[Vector2i(479, 270), 479.0 / 480.0, FRAC],
	[Vector2i(480, 269), 269.0 / 270.0, FRAC],
	[Vector2i(959, 540), 1.0, INT],
	[Vector2i(960, 540), 2.0, INT],
	[Vector2i(960, 539), 1.0, INT],
	[Vector2i(1439, 810), 2.0, INT],
	[Vector2i(1440, 810), 3.0, INT],
	[Vector2i(1440, 809), 2.0, INT],
	[Vector2i(1500, 900), 3.0, INT],
	[Vector2i(1920, 1080), 4.0, INT],
	[Vector2i(2560, 1440), 5.0, INT],
	[Vector2i(3840, 2160), 8.0, INT],
	[Vector2i(2000, 540), 2.0, INT],
	[Vector2i(640, 360), 1.0, INT],
	[Vector2i(400, 225), 0.83333, FRAC],
	[Vector2i(320, 180), 0.66667, FRAC],
]
## D4: usable screen, decorations → window scale.
const WINDOW_SCALES := [
	[Vector2i(1920, 1040), Vector2i(0, 30), 3],
	[Vector2i(1366, 728), Vector2i(0, 30), 2],
	[Vector2i(1440, 900), Vector2i(2, 32), 2],  # 1442 > 1440
	[Vector2i(1600, 860), Vector2i(0, 30), 3],  # 840 ≤ 860
	[Vector2i(800, 500), Vector2i(0, 30), 1],
	[Vector2i(400, 200), Vector2i(0, 0), 1],
	[Vector2i(0, 0), Vector2i(0, 0), 3],  # a server that can't tell: leave the window alone
]

var _fail := 0
var _emits: Array[float] = []


func run() -> void:
	_test_scale_for()
	_test_window_scale_for()
	_test_project_settings()
	_test_inert_before_start()
	_test_apply()
	_test_start_headless()
	Game.reset_for_tests()
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func _test_scale_for() -> void:
	for row: Array in SCALES:
		var w: Vector2i = row[0]
		var got := Display.scale_for(w)
		var stretch := Display.stretch_for(w)
		check(absf(got - row[1]) < EPS and stretch == row[2],
				"scale_for %dx%d = %.5f, %s (got %.5f, %s)" % [w.x, w.y, row[1], _name(row[2]), got, _name(stretch)])


func _test_window_scale_for() -> void:
	for row: Array in WINDOW_SCALES:
		var got := Display.window_scale_for(row[0], row[1])
		check(got == row[2], "window_scale_for usable %s, decorations %s = x%d (got x%d)" % [row[0], row[1], row[2], got])


## D1, D3: the rule leans on these; the editor never writes a default into project.godot, so the
## effective values are read, not the file.
func _test_project_settings() -> void:
	var vw: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var vh: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	check(Display.BASE == Vector2i(vw, vh), "Display.BASE %s is project.godot's viewport size (got %dx%d)" % [Display.BASE, vw, vh])
	var ow: int = ProjectSettings.get_setting("display/window/size/window_width_override")
	var oh: int = ProjectSettings.get_setting("display/window/size/window_height_override")
	check(Display.BASE * Display.DEFAULT_WINDOW_SCALE == Vector2i(ow, oh),
			"DEFAULT_WINDOW_SCALE x BASE is the window override, 1440x810 (got %dx%d)" % [ow, oh])
	var want := {
		"display/window/stretch/mode": "viewport",
		"display/window/stretch/scale_mode": "integer",
		"display/window/stretch/aspect": "keep",
		"display/window/dpi/allow_hidpi": true,
		"rendering/textures/canvas_textures/default_texture_filter": 0,
		"rendering/2d/snap/snap_2d_transforms_to_pixel": true,
	}
	for key: String in want:
		var got: Variant = ProjectSettings.get_setting(key)
		check(typeof(got) == typeof(want[key]) and got == want[key], "%s is %s (got %s)" % [key, want[key], got])


func _test_inert_before_start() -> void:
	var d: Display = Game.display
	check(d is Display and d.name == &"Display" and d.get_parent() == Game,
			"Game.display is a Display named Display, a child of Game")
	check(d.scale == 0.0, "Game.display.scale is 0.0 (no window) before start() (got %s)" % d.scale)
	check(not get_window().size_changed.is_connected(d._on_size_changed), "size_changed is not connected before start()")
	check(not d.is_processing(), "the per-frame size check is off before start()")
	check(d.process_mode == Node.PROCESS_MODE_ALWAYS, "...and set to run through a pause once it is on")
	check(get_window().content_scale_stretch == INT, "the stretch starts integer (got %s)" % _name(get_window().content_scale_stretch))


func _test_apply() -> void:
	var d: Display = Game.display
	d.scale_changed.connect(_on_scale_changed)
	_step(d, Vector2i(400, 225), 0.83333, FRAC, 1, "below 480x270 switches to the fit")
	_step(d, Vector2i(400, 225), 0.83333, FRAC, 0, "the same size again changes nothing")
	_step(d, Vector2i(960, 540), 2.0, INT, 1, "back to whole scales switches to integer")
	_step(d, Vector2i(1000, 600), 2.0, INT, 0, "a new size at the same whole scale emits nothing")
	_step(d, Vector2i(1440, 810), 3.0, INT, 1, "the next whole scale emits once")
	d.scale_changed.disconnect(_on_scale_changed)
	get_window().content_scale_stretch = INT


func _step(d: Display, w: Vector2i, want: float, stretch: Window.ContentScaleStretch, emits: int, what: String) -> void:
	_emits.clear()
	d.apply(w)
	var got_stretch := get_window().content_scale_stretch
	check(absf(d.scale - want) < EPS and got_stretch == stretch and _emits.size() == emits
			and (emits == 0 or absf(_emits[0] - want) < EPS),
			"apply %dx%d: %s (scale %.5f, %s, %d emit; got %.5f, %s, %s)" % [
				w.x, w.y, what, want, _name(stretch), emits, d.scale, _name(got_stretch), _emits])


## D2, F9: the runner is headless, the case every test and export.sh's Linux boot run in.
func _test_start_headless() -> void:
	check(DisplayServer.get_name() == "headless", "the runner is headless (got %s)" % DisplayServer.get_name())
	var d := Display.new()
	add_child(d)
	d.start()
	check(d.scale == 0.0, "start() under headless leaves scale 0.0 (got %s)" % d.scale)
	check(not get_window().size_changed.is_connected(d._on_size_changed), "...and connects nothing to size_changed")
	check(not d.is_processing(), "...and leaves the per-frame size check off")
	remove_child(d)
	d.queue_free()


func _on_scale_changed(s: float) -> void:
	_emits.append(s)


func _name(stretch: int) -> String:
	return "integer" if stretch == INT else "fractional"
