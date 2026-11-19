extends Node
## The four DevTools overlays (AR54, Story 1.11 D9-D11), cycled by the `dev_overlay` action:
## 1 play rect and gutters, 2 light radii and notice rings, 3 room exits, entries and object ids,
## 4 FPS, on-screen lights and active Clock requests, then off. Debug builds only; no class_name, so
## dev/ adds one global name (DevTools preloads this script).
## Every mark reads the value the game uses (World.play_rect(), Player.light_radius(), Lurker's
## sensing constants, the Room's exits), never a copied number. Two drawers, both under DevTools:
## - WorldMarks draws in world space on World's canvas. The Darkness CanvasModulate would dim it to
##   a tenth (probed: light_mask = 0 doesn't escape it), so it uses one cached unshaded material.
##   It never moves, so it stays registered with the room tiles under physics interpolation; a mark
##   at an actor sits at its tick position, up to one tick off the interpolated sprite (accepted).
## - ScreenMarks draws in screen pixels on its own CanvasLayer above the UI, over the gutters.
## Nothing pulses or blinks (NFR8), and no colour is the reserved amber or red (NFR9).

const MODES := 4  ## 0 is off
const REFRESH_MS := 250  ## the readout text rebuilds at 4 Hz, not per frame
const CLOCK_LINGER_MS := 500  ## an ended Clock request stays listed (greyed) this long: nothing blinks faster than 2 Hz
const LAYER := 11  ## above World's UI layer (10), so screen marks draw over the opaque gutters
const FONT_SIZE := 8
const USABLE_INSET := 1.0  ## px: a gutter's usable band is 58 of its 60 px (UX DESIGN.md gutter-usable)
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
var light_count := 0  ## on-screen PointLight2Ds at the latest rebuild (mode 4)
var clock_seen := {}  ## StringName -> {scale, ms}: every Clock request seen this frame or within the linger
var clock_list: Array[Dictionary] = []  ## the readout's Clock rows at the latest rebuild: {id, scale, live}

var _world_marks: Node2D
var _screen_marks: Node2D
var _readout := PackedStringArray()  # mode 4's first lines: FPS, lights


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
	clock_seen.clear()
	clock_list.clear()
	last_refresh_ms = -1
	_redraw()  # also clears the last mode's marks when switching off


func _process(_delta: float) -> void:
	if mode == 0:
		return
	if mode == 4:
		_sample_clock()
		var now := Time.get_ticks_msec()
		if last_refresh_ms < 0 or now - last_refresh_ms >= REFRESH_MS:
			_rebuild_readout(now)
	_redraw()


func _redraw() -> void:
	_world_marks.queue_redraw()
	_screen_marks.queue_redraw()


# --- Mode 4: readout ----------------------------------------------------------------------------

## Every frame, not at the rebuild: a 75 ms hitstop falls between two 250 ms rebuilds most of the
## time, so a rebuild-time sample would almost never show it.
func _sample_clock() -> void:
	var now := Time.get_ticks_msec()
	var live := Game.clock.active()
	for id: StringName in live:
		clock_seen[id] = {scale = live[id], ms = now}


func _rebuild_readout(now: int) -> void:
	last_refresh_ms = now
	light_count = _count_lights()
	_readout = PackedStringArray([
			"FPS %d" % Engine.get_frames_per_second(),
			"lights %d" % light_count])
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


## D10: the PointLight2Ds under World that light the play rect. `owned = false`: the default skips
## nodes built in code (probed). Story 1.12 moves this rule into game code for the light budget.
func _count_lights() -> int:
	if not is_instance_valid(world):
		return 0
	var rect := world.play_rect()
	var n := 0
	for light: Node in world.find_children("*", "PointLight2D", true, false):
		if counts_on_screen(light as PointLight2D, rect):
			n += 1
	return n


## A light counts when it is shown, on and has energy and a texture, and its texture rect meets
## `rect` (AR20: on screen means the play rect). Idle lurker glows have energy 0 and are hidden.
static func counts_on_screen(light: PointLight2D, rect: Rect2) -> bool:
	if not (light.is_visible_in_tree() and light.enabled and light.energy > 0.0 and light.texture != null):
		return false
	var size := light.texture.get_size() * light.texture_scale * light.global_scale.abs()
	return Rect2(light.to_global(light.offset) - size / 2.0, size).intersects(rect)


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
		1:
			var r := world.play_rect()
			_world_marks.draw_rect(r, WHITE, false, 1.0)
			_dashed_rect(_world_marks, r.grow(-Lurker.SCREEN_MARGIN), GREY)
			_text(_world_marks, r.position + Vector2(4, 2), "play rect %d x %d" % [r.size.x, r.size.y], WHITE)
			_text(_world_marks, r.position + Vector2(4, 12), "notice: %d px inside" % Lurker.SCREEN_MARGIN, GREY)
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


## A light that can't be noticed has its reach ring drawn dashed and dim, which shows the 40 px
## base light as safe.
func _draw_light() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var alive := is_instance_valid(player) and not player.is_dead
	if alive:
		var c := player.global_position
		var m := light_marks(player.light_radius())
		_world_marks.draw_arc(c, m.radius, 0.0, TAU, 48, CYAN, 1.0)
		# Labels by the player, whom the camera keeps near the middle: at a ring's edge they would
		# fall under a gutter once the light grows.
		_text(_world_marks, c + Vector2(8, 4), "light %d px" % m.radius, CYAN)
		if not m.noticeable:
			_dashed_circle(_world_marks, c, m.reach, DIM)
			_text(_world_marks, c + Vector2(8, 14), "reach %d px: below notice (< %d px)" % [m.reach, Lurker.NOTICE_MIN_RADIUS], DIM)
		else:
			_world_marks.draw_arc(c, m.reach, 0.0, TAU, 64, CYAN, 1.0)
			_text(_world_marks, c + Vector2(8, 14), "notice reach %d px" % m.reach, CYAN)
	for p: Node in get_tree().get_nodes_in_group("predator"):
		if not is_instance_valid(p) or not ("state" in p) or not p is Node2D:
			continue
		var pos: Vector2 = p.global_position
		var state_name: String = Lurker.State.keys()[p.state] if p is Lurker else str(p.state)
		_beside(pos.x - 8, pos.x + 8, pos.y - 10, state_name, MAGENTA)  # lurkers sit in the walls, by the gutters
		if alive and p.has_method(&"senses") and p.senses(player):
			_world_marks.draw_line(pos, player.global_position, MAGENTA, 1.0)


func _draw_screen() -> void:
	match mode:
		1:
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
			for line in _readout:
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
