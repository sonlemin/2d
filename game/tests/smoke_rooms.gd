extends Node
## Every room file, checked (Story 1.10, AR50, NFR10): adding a room adds its checks, with no edit
## here (Architecture → Design Guarantees as Tests).
## - Every res://rooms/**/*.txt is validated; each error is a FAIL and the file is never built.
## - Across files: unique room and obj ids, exit targets that exist and have the arrival entry.
## - Per swept room (outside rooms/dev/): spine falls, cling stretches, hazard pits, a safe arrival
##   from below, and the lurker guarantees (Pillar 2: every hunt is telegraphed and escapable).
## smoke_bot plays every spine room top to bottom; room_sweep.gd holds the pure sweeps.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_rooms.gd

const RoomHarness := preload("res://tests/room_harness.gd")
const RoomSweep := preload("res://tests/room_sweep.gd")
const Spec := preload("res://tests/spec.gd")
## A sentinel: a wrong root or a broken walk must not pass as "no rooms, nothing to check".
const M1_SHAFT := "res://rooms/l1/m1_shaft.txt"
## D9: the chain the escape scenarios hold (109.6 px, sensed from 175 px), as M1's tests did.
const ESCAPE_CHAIN := 10
## D9: how far beside the player a forced hunt starts: about half a second at hunt speed.
const ESCAPE_GAP := 48.0
## D9: the telegraph check's light: chain 10, 100 px from the lurker (in reach, on screen).
const TELEGRAPH_GAP := 100.0
const CLING_ROWS := 6  ## D9: the open fall beside the cling wall, so the setup never lands

var _fail := 0
var _parts: Dictionary
var _room: Room
var _player: Player


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func seconds(s: float) -> void:
	await frames(int(ceil(s * Engine.physics_ticks_per_second)))


func run() -> void:
	var swept := _check_files()
	_check_tuning()
	var first := true
	for rec: Dictionary in swept:
		if first:
			await _test_world_stub(rec)
			first = false
		await _test_lurkers(rec)
	print("SMOKE %s" % ("PASS" if _fail == 0 else "FAILED (%d)" % _fail))


# --- Files, validation and the sweeps (D3–D8, D11) -------------------------------------------

## Validates every file, runs the cross-file and per-room sweeps, and returns the records of the
## rooms to play (valid, outside rooms/dev/), sorted by path.
func _check_files() -> Array[Dictionary]:
	var files := RoomSweep.room_files()
	check(not files.is_empty(), "found %d room files under %s" % [files.size(), RoomSweep.ROOT])
	check(M1_SHAFT in files, "sentinel: %s is among them" % M1_SHAFT)
	var all: Array[Dictionary] = []  # every readable file, for ids and links
	var swept: Array[Dictionary] = []
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		var err := FileAccess.get_open_error()
		if err != OK:
			check(false, "%s is unreadable (%s)" % [path, error_string(err)])
			continue
		var parsed := RoomLoader.parse(text)
		var errors := RoomLoader.validate(path, parsed)
		for e in errors:
			check(false, e)
		var rec := RoomSweep.record(path, parsed)
		all.append(rec)
		if not errors.is_empty():
			continue
		if RoomSweep.is_dev(path):
			check(true, "%s validates clean (a dev room: validated only, never swept or botted)" % path)
		else:
			check(true, "%s validates clean" % path)
			swept.append(rec)
	_fail_each(RoomSweep.duplicate_id_errors(all), "room ids and obj ids are unique across all %d files" % all.size())
	var every := {}
	for rec in all:
		every[rec.id] = rec
	_fail_each(RoomSweep.link_errors(every), "every exit targets a room that has the arrival entry")
	var max_rows := floori(Spec.LEDGE_FALL_MAX / Room.TILE)
	var hazards := RoomLegend.HAZARDS
	var by_id := {}
	for rec in swept:
		by_id[rec.id] = rec
		var id: String = rec.id
		if rec.spine:
			var rows := RoomSweep.safe_rows(rec.grid, rec.clings, hazards)
			var worst := 0
			for i in range(1, rows.size()):
				worst = maxi(worst, rows[i] - rows[i - 1])
			_fail_each(RoomSweep.spine_gap_errors(id, rec.grid, rec.clings, hazards, max_rows),
					"%s: no fall between ledge rows (or cling stretches) is over %d rows, Spec.LEDGE_FALL_MAX (worst %d)" % [id, max_rows, worst])
		_fail_each(RoomSweep.stretch_width_errors(id, rec.grid, rec.clings),
				"%s: its %d cling stretches are 6-10 tiles wide (GDD Narrow stretch)" % [id, rec.clings.size()])
		_fail_each(RoomSweep.hazard_pit_errors(id, rec.grid, rec.clings, hazards, max_rows),
				"%s: every hazard pit has a ledge or cling stretch within %d rows above it (%d hazard chars today)" % [id, max_rows, hazards.size()])
		_fail_each(RoomSweep.arrival_errors(id, rec.grid, rec.exits, RoomSweep.ARRIVAL_CLEAR_CELLS),
				"%s: no enemy spawns within %d cells of the arrival from below" % [id, RoomSweep.ARRIVAL_CLEAR_CELLS])
	_fail_each(RoomSweep.exit_fall_errors(by_id, hazards, max_rows),
			"no fall through a down exit into a spine room is over %d rows" % max_rows)
	return swept


## One FAIL per error, or one ok line naming what held.
func _fail_each(errors: Array[String], ok_msg: String) -> void:
	for e in errors:
		check(false, e)
	if errors.is_empty():
		check(true, ok_msg)


## Spec, not tuning, is the design (AR49); the tuning must not break it from the other side.
func _check_tuning() -> void:
	var max_fall := Game.tuning.f(&"max_fall")
	check(Spec.LEDGE_FALL_MAX / max_fall <= Spec.LEDGE_FALL_TIME + 1e-6,
			"Spec.LEDGE_FALL_MAX %.0f px at the tuned max fall %.0f px/s takes %.2f s, at most Spec.LEDGE_FALL_TIME %.2f s" % [Spec.LEDGE_FALL_MAX, max_fall, Spec.LEDGE_FALL_MAX / max_fall, Spec.LEDGE_FALL_TIME])
	var telegraph := Game.tuning.f(&"lurker_telegraph_time")
	check(telegraph >= Spec.TELEGRAPH_MIN, "the tuned telegraph %.2f s is at least Spec.TELEGRAPH_MIN %.2f s" % [telegraph, Spec.TELEGRAPH_MIN])
	check(Lurker.NOTICE_MIN_RADIUS >= Spec.NOTICE_MIN_RADIUS, "a lurker never wakes below Spec.NOTICE_MIN_RADIUS (Lurker.NOTICE_MIN_RADIUS %.0f)" % Lurker.NOTICE_MIN_RADIUS)


# --- The harness ------------------------------------------------------------------------------

## D3: the player starts where a diver would: `P`, else the top entry, else the bottom one.
func _entry(rec: Dictionary) -> StringName:
	for row: String in rec.grid:
		if row.contains(RoomLegend.SPAWN):
			return &"spawn"
	for e: Dictionary in rec.exits:
		if e.side == "up":
			return &"up"
	return &"down" if not rec.exits.is_empty() else &""


func _build(rec: Dictionary) -> void:
	_parts = RoomHarness.build_from_path(self, rec.path, _entry(rec))
	_room = _parts.room
	_player = _parts.player
	Game.clock.clear()
	await frames(2)


## Frees the room and waits until it is gone, so the next build never sees its lurkers or its
## stub World (lurkers take the first node in group `world`).
func _free() -> void:
	RoomHarness.free_all(_parts)
	await get_tree().process_frame
	await get_tree().process_frame
	await frames(1)


## Teleport the player and snap the camera, so on-screen checks see the real view.
func place(pos: Vector2) -> void:
	_player.global_position = pos
	_player.velocity = Vector2.ZERO
	_parts.camera.snap()


## This room's lurkers by position (row, then column), never by group order.
func _lurkers() -> Array[Lurker]:
	var out: Array[Lurker] = []
	for n in _room.get_children():
		if n is Lurker:
			out.append(n)
	out.sort_custom(func(a: Lurker, b: Lurker) -> bool:
		return a.global_position.y < b.global_position.y or (a.global_position.y == b.global_position.y and a.global_position.x < b.global_position.x))
	return out


## Only `keep` acts; every other lurker in the room is paused.
func _only(keep: Lurker) -> void:
	for l in _lurkers():
		l.set_physics_process(l == keep)


func _add_links(n: int) -> void:
	for i in n:
		_player.chain.add_hit()


## The stub World the lurkers read from: the play area between the gutters (AR20).
func _test_world_stub(rec: Dictionary) -> void:
	await _build(rec)
	var w := get_tree().get_first_node_in_group("world")
	check(w == _parts.world and w.has_method("play_rect") and w.play_rect().size.x == CameraRig.PLAY_WIDTH,
			"the harness's stub World is the one node in group world, with a 360 px play_rect()")
	await _free()


# --- Lurker guarantees (D9) -------------------------------------------------------------------

func _test_lurkers(rec: Dictionary) -> void:
	if _entry(rec) == &"":
		check(true, "%s: skipped: no entry to load the room at" % rec.id)
		return
	await _build(rec)
	var count := _lurkers().size()
	await _free()
	if count == 0:
		check(true, "%s: no lurkers, so no lurker checks" % rec.id)
		return
	for i in count:
		await _test_lurker(rec, i)
	await _test_contact(rec)
	for kind in ["Snuff", "landing", "cling"]:
		await _test_escape(rec, kind)


## The per-lurker checks, on a fresh room so one lurker's hunt never leaks into the next.
func _test_lurker(rec: Dictionary, index: int) -> void:
	await _build(rec)
	var lurker := _lurkers()[index]
	var who := "%s lurker %d at %s" % [rec.id, index, Vector2i(lurker.global_position / Room.TILE)]
	_only(null)  # paused: senses() is only asked
	_player.set_physics_process(false)
	# 1. Base light, point-blank.
	_player.chain.break_chain()
	place(lurker.global_position)
	await frames(1)
	check(_player.light_radius() <= Spec.BASE_LIGHT, "%s: base light is at most Spec.BASE_LIGHT %.0f px (got %.1f)" % [who, Spec.BASE_LIGHT, _player.light_radius()])
	check(not lurker.senses(_player), "%s: base light is never noticed, even point-blank" % who)
	# 2. The notice floor: the largest light under it is never noticed point-blank; one more link
	# (over the lurker's own floor) is, from the same spot, so "never" is not "never on screen".
	var under := 0
	while under < 30 and ChainState.radius_for(under + 1) < Spec.NOTICE_MIN_RADIUS:
		under += 1
	_add_links(under)
	check(under > 0 and _player.light_radius() < Spec.NOTICE_MIN_RADIUS, "%s: setup: chain %d gives %.1f px, the largest light under Spec.NOTICE_MIN_RADIUS %.0f px" % [who, under, _player.light_radius(), Spec.NOTICE_MIN_RADIUS])
	check(not lurker.senses(_player), "%s: light under Spec.NOTICE_MIN_RADIUS is never noticed, even point-blank (chain %d)" % [who, under])
	while _player.light_radius() < Lurker.NOTICE_MIN_RADIUS and _player.chain.count < 30:
		_player.chain.add_hit()
	check(lurker.senses(_player), "%s: control: chain %d (%.1f px) is noticed from the same spot" % [who, _player.chain.count, _player.light_radius()])
	# 3. Off-screen: the biggest light, the lurker just outside the play rect but in its reach.
	_player.chain.break_chain()
	_add_links(ChainState.MAX_CHAIN)
	var side := _place_off_screen(lurker)
	if side == "":
		check(true, "%s: off-screen skipped: no room above or below to put the lurker off screen within reach" % who)
	else:
		var reach := _player.light_radius() * Lurker.NOTICE_FACTOR
		var d := lurker.global_position.distance_to(_player.global_position)
		check(d <= reach and not _parts.world.play_rect().has_point(lurker.global_position),
				"%s: premise: the player %s it, %.0f px away (reach %.0f px), and it is just outside the play rect" % [who, side, d, reach])
		check(not lurker.senses(_player), "%s: a lurker outside the play rect never notices, whatever the light (chain %d)" % [who, _player.chain.count])
	# 4. The telegraph, measured: frames seen in TELEGRAPH until it ends (it may have started up to a
	# frame before we saw it, so the floor is checked to within one frame).
	_player.chain.break_chain()
	_add_links(ESCAPE_CHAIN)
	var toward := signf(_room.bounds().get_center().x - lurker.global_position.x)
	place(lurker.global_position + Vector2((toward if toward != 0.0 else 1.0) * TELEGRAPH_GAP, 0))
	check(lurker.senses(_player), "%s: setup: chain %d, %.0f px away on screen, is noticed" % [who, ESCAPE_CHAIN, TELEGRAPH_GAP])
	_only(lurker)
	for i in 10:
		await frames(1)
		if lurker.state == Lurker.State.TELEGRAPH:
			break
	check(lurker.state == Lurker.State.TELEGRAPH, "%s: a big light in range -> it telegraphs" % who)
	var held := 0
	while lurker.state == Lurker.State.TELEGRAPH and held < 600:
		await frames(1)
		held += 1
	var floor_frames := int(ceil(Spec.TELEGRAPH_MIN * Engine.physics_ticks_per_second))
	check(held + 1 >= floor_frames, "%s: the telegraph lasted %d frames, at least Spec.TELEGRAPH_MIN %.2f s (%d frames, to within one)" % [who, held, Spec.TELEGRAPH_MIN, floor_frames])
	check(lurker.state == Lurker.State.HUNT, "%s: hunting after the telegraph" % who)
	var d0 := lurker.global_position.distance_to(_player.global_position)
	await seconds(0.3)
	check(lurker.global_position.distance_to(_player.global_position) < d0, "%s: the hunting lurker closes in" % who)
	await _free()


## Straight below the lurker, else straight above, at the first distance where it leaves the play
## rect (AR20: "on screen" is the play rect, so the lurker's own SCREEN_MARGIN is what is tested).
## The player stays inside the room and inside the light's reach. Returns "is below" / "is above",
## or "" when neither side has such a spot.
func _place_off_screen(lurker: Lurker) -> String:
	var reach := _player.light_radius() * Lurker.NOTICE_FACTOR
	for dir: float in [1.0, -1.0]:
		var d := 0.0
		while d <= reach:
			var pos := lurker.global_position + Vector2(0, dir * d)
			if not _room.bounds().has_point(pos):
				break
			place(pos)
			if not _parts.world.play_rect().has_point(lurker.global_position):
				return "is below" if dir > 0.0 else "is above"
			d += 1.0
	return ""


## Contact (the first lurker by position): an IDLE lurker is harmless, a HUNTING one kills. Both
## in mid-air in the open, the lurker moved onto the player: in its wall pocket the body would be
## pushed out of the tile, and a floor contact breaks the chain (the ground is a sanctuary).
func _test_contact(rec: Dictionary) -> void:
	await _build(rec)
	var spot := _open_spot(rec)
	if spot == Vector2.INF:
		check(true, "%s: contact skipped: no open 3 x 4 cells to touch a lurker in" % rec.id)
		await _free()
		return
	var lurker := _lurkers()[0]
	_only(lurker)
	var died := [false]
	_player.died.connect(func() -> void: died[0] = true)
	place(spot)
	lurker.global_position = _player.global_position
	await frames(3)
	check(lurker.state == Lurker.State.IDLE and not died[0], "%s: touching an IDLE lurker does not kill (no telegraph yet)" % rec.id)
	_add_links(ESCAPE_CHAIN)  # a big light: the lurker keeps the scent
	lurker._enter(Lurker.State.HUNT)
	lurker.global_position = _player.global_position
	await frames(3)
	check(died[0] and _player.is_dead, "%s: control: a HUNTING lurker kills on contact, in the same spot" % rec.id)
	await _free()


## The first open 3 x 4 block (row, then column) from the top: room for the body to hang in the air
## for a few frames. Its centre cell's centre, or Vector2.INF.
func _open_spot(rec: Dictionary) -> Vector2:
	var g: Array[String] = rec.grid
	for r in range(1, g.size() - 3):
		for c in range(2, g[r].length() - 2):
			var clear := true
			for dy in 4:
				for dx in [-1, 0, 1]:
					clear = clear and not RoomLoader.solid_at(g, Vector2i(c + dx, r + dy)) and g[r + dy][c + dx] == RoomLegend.EMPTY
			if clear:
				return _room.cell_centre(Vector2i(c, r + 1))
	return Vector2.INF


## Pillar 2 (M1 playtest: "saw it, couldn't escape"): a Snuff, a landing or a cling in time saves you
## from a hunting lurker at full speed a body-length or two away. Each on a fresh room.
func _test_escape(rec: Dictionary, kind: String) -> void:
	await _build(rec)
	var lurker := _lurkers()[0]
	_only(null)
	var who := "%s %s escape" % [rec.id, kind]
	var start := Vector2.ZERO
	match kind:
		"Snuff":
			_player.set_physics_process(false)  # state level, as M1 tested it: the input can't undo it
			start = _player.global_position
		"landing":
			var stand := _stand_position(rec)
			if stand == Vector2.INF:
				check(true, "%s: skipped: no stand cell in %s" % [who, rec.id])
				await _free()
				return
			start = stand + Vector2(0, -6)
		"cling":
			var wall := _cling_start(rec)
			if wall == Vector2.INF:
				check(true, "%s: skipped: no cling wall in %s" % [who, rec.id])
				await _free()
				return
			start = wall
	place(start)
	if kind == "cling":
		# Fall clear of coyote time first, holding toward the wall, so Jump clings, never jumps.
		Input.action_press("move_left")
		await frames(8)
	_add_links(ESCAPE_CHAIN)
	if kind == "landing":
		_player.velocity.y = 60.0  # falling
	var toward := signf(_room.bounds().get_center().x - _player.global_position.x)
	lurker.global_position = _player.global_position + Vector2((toward if toward != 0.0 else 1.0) * ESCAPE_GAP, 0)
	lurker._enter(Lurker.State.HUNT)
	lurker._velocity = lurker.global_position.direction_to(_player.global_position) * Game.tuning.f(&"lurker_hunt_speed")
	_only(lurker)
	await frames(1)
	var before := lurker.monitorable
	match kind:
		"Snuff":
			_player.chain.set_snuffed(true)
		"cling":
			Input.action_press("jump")
	# The escape frame: the Snuff's next tick, the first on the floor, the first clinging.
	var waited := 0
	while waited < 30:
		await frames(1)
		waited += 1
		if kind == "Snuff" or (kind == "landing" and _player.is_on_floor()) or (kind == "cling" and _player._clinging):
			break
		before = lurker.monitorable
	var escaped := kind == "Snuff" or (kind == "landing" and _player.is_on_floor()) or (kind == "cling" and _player._clinging)
	check(escaped and before, "%s: premise: it escapes on frame %d, and the hunting lurker was lethal the frame before" % [who, waited])
	var since := 0  # frames since the escape frame
	var harmless := not lurker.monitorable
	if not harmless:
		await frames(1)
		since += 1
		harmless = not lurker.monitorable
	check(harmless, "%s: the lurker is harmless (monitorable off) on the escape frame or the one after" % who)
	var lose := int(ceil((Game.tuning.f(&"lurker_lose_track_time") + 0.2) * Engine.physics_ticks_per_second))
	var total := int(ceil(1.2 * Engine.physics_ticks_per_second))
	var left := 0 if lurker.state != Lurker.State.HUNT else -1
	while since < maxi(total, lose):
		await frames(1)
		since += 1
		if left < 0 and lurker.state != Lurker.State.HUNT:
			left = since
		if since == total:
			check(not _player.is_dead, "%s: still alive 1.2 s later" % who)
	check(left >= 0 and left <= lose, "%s: the lurker leaves HUNT within lose-track + 0.2 s (%d frames; left after %d)" % [who, lose, left])
	for a in ["move_left", "jump"]:
		Input.action_release(a)
	await _free()


## D9: where a landing ends: the room's `P`, else its down entry, else the first ledge cell (row,
## then column) with two open cells above. Vector2.INF when there is none.
func _stand_position(rec: Dictionary) -> Vector2:
	if _room.has_entry(&"spawn"):
		return _room.entry_position(&"spawn")
	if _room.has_entry(&"down"):
		return _room.entry_position(&"down")
	var g: Array[String] = rec.grid
	for r in range(2, g.size()):
		for c in range(1, g[r].length() - 1):
			if RoomLoader.solid_at(g, Vector2i(c, r)) and not RoomLoader.solid_at(g, Vector2i(c, r - 1)) and not RoomLoader.solid_at(g, Vector2i(c, r - 2)):
				return Vector2(c * Room.TILE + Room.TILE / 2.0, r * Room.TILE - 12)
	return Vector2.INF


## D9: falling beside the 1-tile left wall: the first row (from the top) where column 0 is solid and
## columns 1–2 are open for CLING_ROWS rows. The body (10 px wide) touches the wall. Vector2.INF when none.
func _cling_start(rec: Dictionary) -> Vector2:
	var g: Array[String] = rec.grid
	for r in range(1, g.size() - CLING_ROWS):
		var clear := true
		for k in CLING_ROWS:
			var row := r + k
			clear = clear and RoomLoader.solid_at(g, Vector2i(0, row)) and not RoomLoader.solid_at(g, Vector2i(1, row)) and not RoomLoader.solid_at(g, Vector2i(2, row))
		if clear:
			return Vector2(Room.TILE + 5.5, (r + 1) * Room.TILE)
	return Vector2.INF
