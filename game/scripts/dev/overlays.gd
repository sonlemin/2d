extends Node
## The four DevTools overlays (AR54, Story 1.11 D9-D11), cycled by the `dev_overlay` action:
## 1 play rect and gutters, 2 light radii and notice rings, 3 room exits, entries and object ids,
## 4 FPS, the light budget, frame times, the perf run and active Clock requests, then off. Debug
## builds only; no class_name, so dev/ adds one global name (DevTools preloads this script).
## Every mark reads the value the game uses (World.play_rect(), Player.light_radius(), Lurker's
## sensing constants, the Room's exits), never a copied number. Two drawers, both under DevTools:
## - WorldMarks draws in world space on World's canvas. The Darkness CanvasModulate would dim it to
##   a tenth (probed: light_mask = 0 doesn't escape it), so it uses one cached unshaded material.
##   It never moves, so it stays registered with the room tiles under physics interpolation. A
##   predator's label sits at its tick position, up to a tick of its travel off its interpolated
##   sprite (at most 1.6 px at a hunt's 95 px/s; accepted).
## - Mode 2's light marks ride on the player instead, on a child the engine interpolates with its
##   sprite: at its tick position they shook while it fell (sonlm, laptop 2026-11-19).
## - ScreenMarks draws in screen pixels on its own CanvasLayer above the UI, over the gutters. Mode
##   1's play rect is here too: it moves with the camera, so in world space it shook while falling.
## Nothing pulses or blinks (NFR8), and no colour is the reserved amber or red (NFR9).

const PerfRun := preload("perf_run.gd")
const MODES := 4  ## 0 is off
const REFRESH_MS := 250  ## the readout text rebuilds at 4 Hz, not per frame
const CLOCK_LINGER_MS := 500  ## an ended Clock request stays listed (greyed) this long: nothing blinks faster than 2 Hz
const LAYER := 11  ## above World's UI layer (10), so screen marks draw over the opaque gutters
const FONT_SIZE := 8
const USABLE_INSET := 1.0  ## px: a gutter's usable band is 58 of its 60 px (UX DESIGN.md gutter-usable)
const SUMMARY_ROW_CHARS := 90  ## the perf summary's rows: the project font, Fusion 8 (Story 1.17): an 88-character row is 403 px, inside the 480 px screen (1.12 D8)
const SUMMARY_ROWS := 3  ## at most, split at `; `; the last row takes the rest, and an overlong row then wraps at a space
# Never #ffd27a (Light) or #d9473f (danger), NFR9.
const WHITE := Color(1, 1, 1, 0.9)
const GREY := Color(0.75, 0.75, 0.78, 0.9)
const DIM := Color(0.6, 0.6, 0.65, 0.55)
const CYAN := Color(0.35, 0.9, 1.0, 0.9)
const MAGENTA := Color(1.0, 0.4, 1.0, 0.9)
const GREEN := Color(0.4, 1.0, 0.5, 0.9)

static var _unshaded: CanvasItemMaterial

var mode := 0  ## 0 off, 1-4; public for tests
var world: World  ## set by DevTools before add_child; never found through get_parent()
var last_refresh_ms := -1  ## Time.get_ticks_msec() of the latest readout rebuild
var light_count := 0  ## lit BudgetLights in World.light_rect() at the latest rebuild (mode 4): what the budget counts (1.12 D8)
var sprite_count := 0  ## demoted BudgetLights showing their sprite glow, likewise
var over_count := 0  ## ALWAYS lights past the budget, likewise
var frame_ms := 0.0  ## the latest frame, in wall time (mode 4)
var worst_frame_ms := 0.0  ## the worst frame since mode 4 opened, in wall time; cycle() resets it
var perf: Node  ## perf_run.gd, set by DevTools for --perf; else null
var readout := PackedStringArray()  ## mode 4's rows before the Clock rows; public for tests
var clock_seen := {}  ## StringName -> {scale, ms}: every Clock request seen this frame or within the linger
var clock_list: Array[Dictionary] = []  ## the readout's Clock rows at the latest rebuild: {id, scale, live}
var player_marks: Node2D  ## mode 2's light marks, a child of the live player; else null. Public for tests

var _world_marks: Node2D
var _screen_marks: Node2D
var _last_frame_usec := 0  # Time.get_ticks_usec() at the previous mode-4 frame; 0 after cycle()


func _ready() -> void:
	_world_marks = Node2D.new()
	_world_marks.name = "WorldMarks"
	_world_marks.z_index = 100
	_world_marks.material = unshaded_material()
	_world_marks.draw.connect(_draw_world)
	add_child(_world_marks)
	var screen := CanvasLayer.new()
	screen.name = "Screen"
	screen.layer = LAYER
	add_child(screen)
	_screen_marks = Node2D.new()
	_screen_marks.name = "ScreenMarks"
	_screen_marks.draw.connect(_draw_screen)
	screen.add_child(_screen_marks)


## Shared by every World in the session (project-context: cache materials as statics).
static func unshaded_material() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED  # must read in the dark
	return _unshaded


## Off -> 1 -> 2 -> 3 -> 4 -> off.
func cycle() -> void:
	mode = (mode + 1) % (MODES + 1)
	frame_ms = 0.0
	worst_frame_ms = 0.0
	_last_frame_usec = 0
	clock_seen.clear()
	clock_list.clear()
	last_refresh_ms = -1
	_redraw()  # also clears the last mode's marks when switching off


func _process(_delta: float) -> void:
	_place_player_marks()
	if mode == 0:
		return
	if mode == 4:
		_sample_clock()
		_sample_frame()
		var now := Time.get_ticks_msec()
		if last_refresh_ms < 0 or now - last_refresh_ms >= REFRESH_MS:
			_rebuild_readout(now)
	_redraw()


func _redraw() -> void:
	_world_marks.queue_redraw()
	if is_instance_valid(player_marks):
		player_marks.queue_redraw()
	_screen_marks.queue_redraw()


# --- Mode 4: readout ----------------------------------------------------------------------------

## Every frame, not at the rebuild: a 75 ms hitstop falls between two 250 ms rebuilds most of the
## time, so a rebuild-time sample would almost never show it.
func _sample_clock() -> void:
	var now := Time.get_ticks_msec()
	var live := Game.clock.active()
	for id: StringName in live:
		clock_seen[id] = {scale = live[id], ms = now}


## Wall time between frames (Time.get_ticks_usec(), never delta, which the time scale bends).
func _sample_frame() -> void:
	var now := Time.get_ticks_usec()
	if _last_frame_usec > 0:
		frame_ms = (now - _last_frame_usec) / 1000.0
		worst_frame_ms = maxf(worst_frame_ms, frame_ms)
	_last_frame_usec = now


## D8: the light counts are BudgetLight.counts() on World.light_rect(), the budget's own rule and
## rect, so the overlay shows exactly what the budget counts (a raw PointLight2D is not counted).
func _rebuild_readout(now: int) -> void:
	last_refresh_ms = now
	var c := {lit = 0, sprites = 0, over = 0}
	if is_instance_valid(world):
		c = BudgetLight.counts(get_tree().get_nodes_in_group(BudgetLight.GROUP), world.light_rect())
	light_count = c.lit
	sprite_count = c.sprites
	over_count = c.over
	var lights := "lights %d/%d, sprites %d" % [light_count, BudgetLight.MAX_ON_SCREEN, sprite_count]
	if over_count > 0:
		lights += ", over %d" % over_count
	readout = PackedStringArray([
			"FPS %d" % Engine.get_frames_per_second(),
			lights,
			"frame %.1f ms, worst %.1f ms" % [frame_ms, worst_frame_ms]])
	if is_instance_valid(perf):
		if perf.done:
			readout.append_array(summary_rows(PerfRun.summary_text(perf.result)))
		else:
			readout.append("perf %d / %d s" % [perf.elapsed_s(), perf.seconds])
	clock_list = clock_rows(clock_seen, Game.clock.active(), now)
	for id: StringName in clock_seen.keys():
		if now - int(clock_seen[id].ms) >= CLOCK_LINGER_MS:
			clock_seen.erase(id)


## The readout's Clock rows, ids sorted as Strings: {id, scale, live}. A live request is a normal
## row; one seen less than CLOCK_LINGER_MS ago is a greyed row; older ones are dropped.
static func clock_rows(seen: Dictionary, live: Dictionary, now_ms: int) -> Array[Dictionary]:
	var ids := {}
	for id: Variant in seen:
		ids[String(id)] = true
	for id: Variant in live:
		ids[String(id)] = true
	var names := PackedStringArray(ids.keys())
	names.sort()
	var rows: Array[Dictionary] = []
	for n in names:
		var id := StringName(n)
		if live.has(id):
			rows.append({id = id, scale = live[id], live = true})
		elif seen.has(id) and now_ms - int(seen[id].ms) < CLOCK_LINGER_MS:
			rows.append({id = id, scale = seen[id].scale, live = false})
	return rows


## The perf summary in rows of at most SUMMARY_ROW_CHARS. First split at its `; ` boundaries into at
## most SUMMARY_ROWS rows, each part joined onto the row while it fits, the last row taking the
## rest; then any row still too long wraps at its last space that fits. Chrome's WebGL adapter name
## ("ANGLE (Intel, … Direct3D11 vs_5_0 ps_5_0, D3D11)") alone is about 90 characters.
static func summary_rows(text: String) -> PackedStringArray:
	var rows := PackedStringArray()
	for part in text.split("; "):
		if rows.is_empty():
			rows.append(part)
		elif rows.size() < SUMMARY_ROWS and (rows[-1] + "; " + part).length() > SUMMARY_ROW_CHARS:
			rows.append(part)
		else:
			rows[-1] += "; " + part
	var out := PackedStringArray()
	for row in rows:
		var rest := row
		while rest.length() > SUMMARY_ROW_CHARS:
			var cut := rest.rfind(" ", SUMMARY_ROW_CHARS)
			if cut <= 0:
				cut = SUMMARY_ROW_CHARS  # one word wider than a row: cut inside it
			out.append(rest.substr(0, cut))
			rest = rest.substr(cut).lstrip(" ")
		out.append(rest)
	return out


# --- Mode 3: room items -----------------------------------------------------------------------------

## What mode 3 draws, in world space: {kind (exit, entry, obj), text, pos, rect (exits), target
## (exits)}. Public for tests. Anchors and stations join the entries in Story 1.24.
func room_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var room := world.current_room() if is_instance_valid(world) else null
	if room == null:
		return items
	var t := float(Room.TILE)
	for e: Dictionary in room.exits:
		var row: int = 0 if e.side == &"up" else room.size_cells.y - 1
		var c: int = e.col
		while c < room.size_cells.x - 1 and not room.is_solid(Vector2i(c, row)):
			c += 1
		var rect := Rect2(Vector2(e.col, row) * t, Vector2(maxi(c - e.col, 1), 1) * t)
		items.append({kind = &"exit", text = "%s -> %s" % [e.side, e.target], pos = rect.position,
				rect = rect, side = e.side, target = e.target})
	for entry in [&"spawn", &"up", &"down"]:
		if room.has_entry(entry):
			items.append({kind = &"entry", text = String(entry), pos = room.entry_position(entry)})
	for id: StringName in room.objects:
		var cell: Vector2i = room.objects[id]
		items.append({kind = &"obj", text = String(id), pos = room.cell_centre(cell), cell = cell})
	return items


# --- Drawing ------------------------------------------------------------------------------------------

func _draw_world() -> void:
	if not is_instance_valid(world):
		return
	match mode:
		2:
			_draw_light()
		3:
			for item in room_items():
				match item.kind:
					&"exit":
						var rect: Rect2 = item.rect
						_world_marks.draw_rect(rect, GREEN, false, 1.0)
						_beside(rect.position.x, rect.end.x, rect.position.y + 2, item.text, GREEN)
					&"entry":
						var p: Vector2 = item.pos
						_world_marks.draw_line(p + Vector2(-3, -3), p + Vector2(3, 3), GREEN)
						_world_marks.draw_line(p + Vector2(-3, 3), p + Vector2(3, -3), GREEN)
						_beside(p.x - 3, p.x + 3, p.y - 6, item.text, GREEN)
					&"obj":
						var o: Vector2 = item.pos
						_world_marks.draw_rect(Rect2(o - Vector2(2, 2), Vector2(4, 4)), GREY, false, 1.0)
						_beside(o.x - 2, o.x + 2, o.y + 2, item.text, GREY)


## Mode 2's numbers for a light of radius `r`, by Lurker.senses()'s rule: a lurker notices it from
## up to `reach` px, and only when `noticeable` (Pillar 2: below the notice radius, never). Public
## and pure, so the 80 px boundary is tested without drawing.
static func light_marks(r: float) -> Dictionary:
	return {radius = r, reach = r * Lurker.NOTICE_FACTOR, noticeable = r >= Lurker.NOTICE_MIN_RADIUS}


## Mode 2 in world space: each predator's state beside it. The player's marks are drawn on the
## player itself (_draw_player_marks()).
func _draw_light() -> void:
	for p: Node in get_tree().get_nodes_in_group("predator"):
		if not is_instance_valid(p) or not ("state" in p) or not p is Node2D:
			continue
		var pos: Vector2 = p.global_position
		var state_name: String = Lurker.State.keys()[p.state] if p is Lurker else str(p.state)
		_beside(pos.x - 8, pos.x + 8, pos.y - 10, state_name, MAGENTA)  # lurkers sit in the walls, by the gutters


## Mode 2's marks ride on the live player: a child at its origin, which the engine interpolates
## with its sprite. At the player's tick position they trailed and shook against the sprite while
## it fell (sonlm, laptop 2026-11-19). The Player node never mirrors (only its sprite flips), so
## the labels read the right way round. After a respawn the old marks go with the old player and
## the next frame puts new ones on; outside mode 2 there are none.
func _place_player_marks() -> void:
	var player: Player = (get_tree().get_first_node_in_group("player") as Player) if mode == 2 else null
	if is_instance_valid(player_marks) and player_marks.get_parent() == player:
		return
	if is_instance_valid(player_marks):
		player_marks.queue_free()
	player_marks = null
	if player == null:
		return
	player_marks = Node2D.new()
	player_marks.name = "DevLightMarks"
	player_marks.z_index = 100
	player_marks.material = unshaded_material()  # must read under the darkness, like WorldMarks
	# Bound to its own node: a draw already queued on old marks runs after the field moved on.
	player_marks.draw.connect(_draw_player_marks.bind(player_marks))
	player.add_child(player_marks)


## In the player's own space (the origin is the player). A light that can't be noticed has its
## reach ring drawn dashed and dim, which shows the 40 px base light as safe. A sense line's
## player end is exact; its far end is the predator's tick offset, so it can sit up to a tick of
## their relative travel off the predator's sprite.
func _draw_player_marks(marks: Node2D) -> void:
	var player := marks.get_parent() as Player
	if not is_instance_valid(player) or player.is_dead:
		return
	var m := light_marks(player.light_radius())
	marks.draw_arc(Vector2.ZERO, m.radius, 0.0, TAU, 48, CYAN, 1.0)
	# Labels by the player, whom the camera keeps near the middle: at a ring's edge they would
	# fall under a gutter once the light grows.
	_text(marks, Vector2(8, 4), "light %d px" % m.radius, CYAN)
	if not m.noticeable:
		_dashed_circle(marks, Vector2.ZERO, m.reach, DIM)
		_text(marks, Vector2(8, 14), "reach %d px: below notice (< %d px)" % [m.reach, Lurker.NOTICE_MIN_RADIUS], DIM)
	else:
		marks.draw_arc(Vector2.ZERO, m.reach, 0.0, TAU, 64, CYAN, 1.0)
		_text(marks, Vector2(8, 14), "notice reach %d px" % m.reach, CYAN)
	for p: Node in get_tree().get_nodes_in_group("predator"):
		if is_instance_valid(p) and p is Node2D and p.has_method(&"senses") and p.senses(player):
			marks.draw_line(Vector2.ZERO, marks.to_local((p as Node2D).global_position), MAGENTA, 1.0)


## Mode 1's play rect in screen pixels: World.play_rect() placed by its offset inside the view of
## the same tick (World.light_rect()), so it is the game's own rect yet sits still on screen. Never
## drawn in world space: the engine draws the view interpolated between physics ticks while
## play_rect() moves only on ticks, so a world-space frame shook by up to a tick of camera travel
## while falling (sonlm, laptop 2026-11-19; probed: 4-12 px at 400 px/s). Public for tests.
func play_rect_on_screen() -> Rect2:
	var play := world.play_rect()
	return Rect2(play.position - world.light_rect().position, play.size)


func _draw_screen() -> void:
	match mode:
		1:
			if is_instance_valid(world):
				var r := play_rect_on_screen()
				_screen_marks.draw_rect(r, WHITE, false, 1.0)
				_dashed_rect(_screen_marks, r.grow(-Lurker.SCREEN_MARGIN), GREY)
				_text(_screen_marks, r.position + Vector2(4, 2), "play rect %d x %d" % [r.size.x, r.size.y], WHITE)
				_text(_screen_marks, r.position + Vector2(4, 12), "notice: %d px inside" % Lurker.SCREEN_MARGIN, GREY)
			var h := _screen_marks.get_viewport_rect().size.y
			var g := CameraRig.GUTTER_WIDTH
			for x in [0.0, g + CameraRig.PLAY_WIDTH]:
				var gutter := Rect2(x, 0.0, g, h)
				_screen_marks.draw_rect(gutter, WHITE, false, 1.0)
				_screen_marks.draw_rect(gutter.grow_individual(-USABLE_INSET, 0.0, -USABLE_INSET, 0.0), GREY, false, 1.0)
				_text(_screen_marks, Vector2(x + 3, h - 22), "gutter %d" % g, WHITE)
				_text(_screen_marks, Vector2(x + 3, h - 12), "usable %d" % (g - 2.0 * USABLE_INSET), GREY)
		4:
			var y := 2.0
			for line in readout:
				_text(_screen_marks, Vector2(3, y), line, WHITE)
				y += 10.0
			for row in clock_list:
				_text(_screen_marks, Vector2(3, y), "%s ×%s" % [row.id, row.scale], WHITE if row.live else DIM)
				y += 10.0


## World text beside a mark spanning `left`..`right`, on the side that faces the middle of the play
## rect, so it never sits under a gutter (marks near a wall are next to one).
func _beside(left: float, right: float, top: float, s: String, colour: Color) -> void:
	var w := ThemeDB.fallback_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var x := right + 3.0 if (left + right) / 2.0 < world.play_rect().get_center().x else left - 3.0 - w
	_text(_world_marks, Vector2(x, top), s, colour)


## `top_left` is where the text's top edge goes; draw_string takes the baseline.
func _text(item: CanvasItem, top_left: Vector2, s: String, colour: Color) -> void:
	var font := ThemeDB.fallback_font
	item.draw_string(font, top_left + Vector2(0, font.get_ascent(FONT_SIZE)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, colour)


func _dashed_rect(item: CanvasItem, r: Rect2, colour: Color) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		item.draw_dashed_line(corners[i], corners[(i + 1) % 4], colour, 1.0, 4.0)


func _dashed_circle(item: CanvasItem, c: Vector2, r: float, colour: Color) -> void:
	var segments := 32
	for i in segments:
		if i % 2 == 0:
			item.draw_arc(c, r, TAU * i / segments, TAU * (i + 1) / segments, 4, colour, 1.0)
