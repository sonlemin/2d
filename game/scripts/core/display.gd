class_name Display
extends Node
## The scale rule and the only code that touches the stretch or the window (AR8, NFR6; Story 1.14).
## A child of `Game`, held as `Game.display` like `Game.clock`: it needs the tree for
## `get_window()` and `size_changed`, and it must exist before any screen (the gate, 1.33, can
## show before World). `Game.boot()` calls `start()` once.
## - The integer case is the engine's (D3): `scale_mode="integer"` with `aspect="keep"` already
##   floors min(w/480, h/270), centres the view and paints the bars black. `scale_for()` mirrors it
##   so the game knows the number (the log, the gate's small-window line, the Pause tab).
## - The fit is ours (UX-DR147): below 480×270 on either side the integer stretch stays at ×1 and
##   crops the right and bottom, so `apply()` switches to the fractional stretch there.
## - Web needs no JavaScriptBridge (D1): Godot's HiDPI canvas is CSS size × devicePixelRatio, so
##   the window size here is already in physical pixels.
## - `scale` is 0.0 until a window is applied: "no window" (headless), and 1.33 / 1.34 read 0 as
##   "no suggestion".

signal scale_changed(scale: float)

## Must equal project.godot's viewport size (test_display checks it).
const BASE := Vector2i(480, 270)
## The PC window opens at ×3 (project.godot's 1440×810 override); 7.2's Scale setting replaces the cap.
const DEFAULT_WINDOW_SCALE := 3

var scale := 0.0  ## read it, never set it from outside

var _last_window := Vector2i.ZERO


func _init() -> void:
	# The resize check runs only once start() has a window (inert before it and under headless),
	# and through a pause: the gate and the Pause tab read `scale` while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func _ready() -> void:
	set_process(false)  # the tree turns processing on for a node with _process(); start() decides


## Physical pixels in, the scale the view is drawn at out (D3): the whole-number scale the
## integer stretch draws from ×1 up, the fractional fit below it.
static func scale_for(window: Vector2i) -> float:
	assert(window.x > 0 and window.y > 0, "Display.scale_for: the window %s has no area" % window)
	var s := minf(window.x / float(BASE.x), window.y / float(BASE.y))
	return floorf(s) if s >= 1.0 else s


static func stretch_for(window: Vector2i) -> Window.ContentScaleStretch:
	if scale_for(window) >= 1.0:
		return Window.CONTENT_SCALE_STRETCH_INTEGER
	return Window.CONTENT_SCALE_STRETCH_FRACTIONAL


## The largest whole scale, up to DEFAULT_WINDOW_SCALE, whose window plus decorations fits the
## usable screen; never below ×1 (D4). An empty usable rect (a display server that can't tell)
## gives the default, which leaves the window alone.
static func window_scale_for(usable: Vector2i, decorations: Vector2i) -> int:
	if usable.x <= 0 or usable.y <= 0:
		return DEFAULT_WINDOW_SCALE
	for s in range(DEFAULT_WINDOW_SCALE, 1, -1):
		if BASE.x * s + decorations.x <= usable.x and BASE.y * s + decorations.y <= usable.y:
			return s
	return 1


## Once, from `Game.boot()`, after `load_settings()` so 7.2's display settings are loaded by then.
func start() -> void:
	# D2, F9: headless reports a 64×64 window and an empty screen, which would pick a 0.133 fit
	# and log it in every test and in export.sh's Linux boot. There is no window to scale.
	if DisplayServer.get_name() == "headless":
		return
	var win := get_window()
	# Web: the page sizes the canvas. Embedded: the editor's Game view owns the size.
	if not OS.has_feature("web") and not Engine.is_embedded_in_editor():
		_fit_window(win)
	apply(win.size)
	# Probed on 4.7.2 (Story 1.14): on web the root window's size follows the browser, but
	# size_changed never fires, so a per-frame size check is what sees a resize there. The signal
	# still answers on the same frame where the engine emits it; apply() ignores a size it has seen.
	win.size_changed.connect(_on_size_changed)
	set_process(true)


## The stretch and `scale` for a window of `window` physical pixels. Emits and logs only when the
## scale changes, so a drag-resize logs once per whole-scale step, not once per pixel (D6).
func apply(window: Vector2i) -> void:
	if window == _last_window:
		return
	_last_window = window
	var s := scale_for(window)
	get_window().content_scale_stretch = stretch_for(window)
	if is_equal_approx(s, scale):
		return
	scale = s
	if s >= 1.0:
		Log.info(Log.UI, "display: scale %d in %dx%d" % [int(s), window.x, window.y])
	else:
		Log.info(Log.UI, "display: scale %.3f (fit) in %dx%d" % [s, window.x, window.y])
	scale_changed.emit(s)


## D4, PC only. F8: Godot doesn't clamp the window to the screen, so ×3 on a 1366×768 screen opens
## partly off it. Order matters: the minimum first, then the size, then (in start()) the scale.
func _fit_window(win: Window) -> void:
	win.min_size = BASE  # F8: clamps a smaller size request too
	# --fullscreen, --maximized or exclusive fullscreen: already sized by the screen.
	if win.mode != Window.MODE_WINDOWED:
		return
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen).size
	var deco := win.get_size_with_decorations() - win.size
	var s := window_scale_for(usable, deco)
	# Only shrink a window that doesn't fit: a --resolution that fits (1.18's 960×540) is kept.
	if win.size.x > BASE.x * s or win.size.y > BASE.y * s:
		win.size = BASE * s
		win.move_to_center()
		Log.info(Log.UI, "display: window x%d %dx%d (screen %dx%d)" % [s, win.size.x, win.size.y, usable.x, usable.y])


func _on_size_changed() -> void:
	apply(get_window().size)


## One Vector2i compare per frame; apply() returns at once on a size it has seen, so nothing logs.
func _process(_delta: float) -> void:
	apply(get_window().size)
