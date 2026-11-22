extends Node
## Headless smoke test of World (Story 1.6 D10): its tree and framing, the session-state wiring it
## took over from the shaft (replaces smoke_shaft_state), popups in the room, a death that
## respawns a fresh player without a reload, the play rect as "on screen", and the
## ScreenRouter's replace-never-stack.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_world.gd
## The test adds World by hand, so World is never the current scene: it must not boot Game, and
## settings writes stay disarmed. The store still points at a temp folder, so a bug that armed
## them could only write there.
## UX numbers (360, 60) are written out here, never read from CameraRig: the test checks the
## layout against the design, not against the code under test.

const WorldScene := preload("res://scenes/world/world.tscn")
const LurkerScene := preload("res://scenes/actors/lurker.tscn")
const TMP := "user://smoke_world_tmp"
const Spec := preload("res://tests/spec.gd")
const Rate := preload("res://tests/rate.gd")

var _fail := 0
var _world: World
var _spawned: Array[Player] = []
var _spawned_at: Array[Vector2] = []
var _warm_counts: Array[int] = []  # warm-up items under the room at each room_entered


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
	DirAccess.make_dir_recursive_absolute(TMP)
	Game.store.dir = TMP
	var scene_before := get_tree().current_scene
	_world = WorldScene.instantiate()
	add_child(_world)
	_world.player_spawned.connect(_on_spawned)  # after the first spawn: counts respawns only
	await frames(2)
	_set_room_lurkers_active(false)
	# Every respawn and loop builds a fresh room with live lurkers (1.7): keep them off, or a later
	# case could be hunted at random.
	_world.room_entered.connect(_on_room_entered)
	test_no_boot()
	test_tree(scene_before)
	test_framing()
	test_chain_and_bank()
	test_brightness()
	test_popups_in_room()
	await test_death_and_respawn()
	await test_pogo_wire()
	await test_behind_the_gutter()
	await test_hunt_over_death()
	await test_bottom_loop()
	test_warm_up_at_room_load()
	test_screen_router()
	test_sources()
	await get_tree().process_frame  # a queued settings write would land here
	check(not FileAccess.file_exists(TMP.path_join("settings.json")), "nothing was written: settings writes are disarmed in a test")
	_world.queue_free()
	await frames(1)
	Game.reset_for_tests()
	DirAccess.remove_absolute(TMP.path_join("settings.json"))  # silent when missing
	DirAccess.remove_absolute(TMP)
	print("SMOKE %s" % ("PASS" if _fail == 0 else "FAILED (%d)" % _fail))


func _on_room_entered(_id: StringName) -> void:
	_set_room_lurkers_active(false)
	# room_entered is emitted inside _swap_room(), after Fx.warm_up(): its items are still there.
	_warm_counts.append(_room().get_children().filter(func(n: Node) -> bool:
		return n is CanvasItem and is_equal_approx(n.modulate.a, Fx.WARM_ALPHA)).size())


func _on_spawned(player: Player) -> void:
	_spawned.append(player)
	_spawned_at.append(player.position)


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _room() -> Room:
	return _world.current_room()


func _camera() -> CameraRig:
	return _world.get_node("Camera") as CameraRig


## The room's own lurkers; lurkers this test spawns are driven case by case.
func _set_room_lurkers_active(on: bool) -> void:
	for l in get_tree().get_nodes_in_group("predator"):
		l.set_physics_process(on)


## Sorted by height, never by group order.
func _crawlers() -> Array:
	var out := get_tree().get_nodes_in_group("enemy").filter(func(e): return not e.is_queued_for_deletion())
	out.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
	return out


## Story 1.4 D6: only the entry scene boots. A World that booted here would load the real settings.json.
func test_no_boot() -> void:
	check(not Game._booted and not Game._settings_armed, "a World added by hand is not the current scene: Game is not booted and writes are not armed")


func test_tree(scene_before: Node) -> void:
	check(_world.is_in_group("world"), "World is in group world")
	var holder := _world.get_node("RoomHolder")
	check(holder.get_child_count() == 1 and holder.get_child(0) is Room and (holder.get_child(0) as Room).id == &"m1_shaft", "RoomHolder holds one Room, m1_shaft")
	check(_world.get_node("Camera") is CameraRig, "Camera is a CameraRig")
	var ui := _world.get_node("UI")
	check(ui is CanvasLayer and ui.process_mode == Node.PROCESS_MODE_ALWAYS, "UI is a CanvasLayer that always processes")
	var names := ui.get_children().map(func(c): return String(c.name))
	check(names == ["Gutters", "ScreenRouter"], "UI holds Gutters then ScreenRouter, so screens draw over the gutters (got %s)" % [names])
	check(ui.get_node("Gutters").theme == ThemeBuilder.theme() and ui.get_node("ScreenRouter").theme == ThemeBuilder.theme(),
			"Gutters and ScreenRouter carry ThemeBuilder.theme(), so every HUD element and screen inherits the game font (AR40)")
	check(_player() != null and _player().get_parent() == _world and _player().get_index() == holder.get_index() + 1, "the player is spawned right after RoomHolder, so it draws on top of the room")
	check(get_tree().current_scene == scene_before, "the current scene is still the runner's")


func test_framing() -> void:
	var cam := _camera()
	check([cam.limit_left, cam.limit_right, cam.limit_top, cam.limit_bottom] == [-64, 416, 0, 1680], "camera limits -64 / 416 / 0 / 1680: the 352 px room centred in the view (got %s)" % [[cam.limit_left, cam.limit_right, cam.limit_top, cam.limit_bottom]])
	var r := _world.play_rect()
	check(r.size == Vector2(360, 270), "play_rect() is 360 × 270 (got %s)" % r.size)
	check(is_equal_approx(r.position.x, -4.0) and is_equal_approx(r.end.x, 356.0), "play_rect() spans x -4 … 356 (got %.1f … %.1f)" % [r.position.x, r.end.x])
	check(r.position.x <= 0.0 and r.end.x >= _room().bounds().end.x, "...which holds the room's full width")
	var strips := _world.get_node("UI/Gutters").get_children().map(func(s: Control): return s.get_global_rect())
	var want := [Rect2(0, 0, 60, 270), Rect2(420, 0, 60, 270)]
	check(strips == want, "two 60 px gutter strips at screen x 0 and 420 (got %s)" % [strips])


func test_chain_and_bank() -> void:
	var p := _player()
	for i in 3:
		p.chain.add_hit()
	check(Game.slot.best_chain == 3, "a chain of 3 records best_chain 3 on the slot (got %d)" % Game.slot.best_chain)
	var held := p.chain.held
	p.chain.break_chain()
	check(held == 6 and Game.dive.carried == 6, "a safe break banks the 6 held embers as carried (held %d, carried %d)" % [held, Game.dive.carried])
	check(Game.slot.best_chain == 3, "...and the best chain stays when the chain resets")


## World repaints from Settings' `changed` signal.
func test_brightness() -> void:
	var darkness: CanvasModulate = _world.get_node("Darkness")
	var choices: Array = Settings.SCHEMA[&"brightness"].choices
	check(choices.size() == World.AMBIENT_LEVELS.size(), "every brightness choice has an ambient level (%d choices, %d levels)" % [choices.size(), World.AMBIENT_LEVELS.size()])
	var got := []
	var want := []
	for level: int in [3, 0, 2, 1, 3]:  # each differs from the one before, so each emits
		Game.settings.set_value(&"brightness", level)
		got.append(snappedf(darkness.color.r, 0.001))
		want.append(snappedf(World.AMBIENT_LEVELS[level] * World.AMBIENT_TINT.r, 0.001))
	check(got == want, "set_value(brightness, n) repaints the darkness at once, for every level (got %s, want %s)" % [got, want])


## AC6: runtime spawns belong to the room, never to World.
func test_popups_in_room() -> void:
	var p := _player()
	var in_room := _room().get_child_count()
	var in_world := _world.get_child_count()
	p.chain.add_hit()
	p.chain.break_chain()  # banks 1: the "+1 banked" popup
	var added := _room().get_child(_room().get_child_count() - 1)
	check(_room().get_child_count() == in_room + 1 and added is Label, "a bank's popup (a Label) goes under the room (room children %d -> %d, last is %s)" % [in_room, _room().get_child_count(), added.get_class()])
	check(_world.get_child_count() == in_world, "...and nothing goes under World")
	check(added is Label and (added as Label).text == "+1 banked", "...and reads '+1 banked': tr() resolves POPUP_BANKED through the registered table (got '%s')" % added.get(&"text"))


func test_death_and_respawn() -> void:
	var old := _player()
	var spawn := _room().entry_position(&"spawn")
	var crawlers := _crawlers().size()
	Game.clock.request(&"hitstop", 0.05, 0.075)
	var old_room := _room()
	var victim: Crawler = _crawlers()[0]  # the topmost crawler, killed this dive
	var victim_cell := victim.cell
	victim.take_hit()
	var carried := Game.dive.carried
	for i in 2:
		old.chain.add_hit()
	old.global_position += Vector2(0, 160)  # die away from P
	old.die()
	check(Game.slot.deaths == 1, "a death records one death on the slot (got %d)" % Game.slot.deaths)
	check(Game.dive.carried == carried and old.chain.held == 0, "...keeps the carried embers and loses the held ones (carried %d, held %d)" % [Game.dive.carried, old.chain.held])
	check(not Game.clock.is_active(&"hitstop") and is_equal_approx(Engine.time_scale, 1.0), "...and clears the Clock: no hitstop survives a death")
	# AC3 is World's own clear at the respawn: die() already cleared, so a request made during
	# the delay is the only thing that fails without it. Longer than the delay, so it can't expire.
	Game.clock.request(&"smoke_hold", 0.5, 30.0)
	await seconds(World.RESPAWN_DELAY + 0.1)
	check(not Game.clock.is_active(&"smoke_hold") and is_equal_approx(Engine.time_scale, 1.0), "the respawn clears the Clock again: a request made during the delay ends with it")
	check(is_instance_valid(_world) and _world.is_inside_tree(), "after the respawn delay, the same World is still in the tree: no reload")
	var p := _player()
	check(p != null and p != old, "a new player exists")
	check(not is_instance_valid(old) or not old.is_inside_tree(), "...and the old one is gone")
	check(_spawned.size() == 1 and _spawned[0] == p, "player_spawned fired once, with the new player (fired %d)" % _spawned.size())
	check(_spawned_at.size() == 1 and _spawned_at[0] == spawn, "...spawned at P, not where it died (got %s, P is %s)" % [_spawned_at, spawn])
	check(_camera().target == p, "the camera follows the new player")
	for i in 4:
		p.chain.add_hit()
	check(Game.slot.best_chain == 4, "the new player's chain is bound: a chain of 4 records best_chain 4 (got %d)" % Game.slot.best_chain)
	p.chain.break_chain()
	check(is_instance_valid(_room()) and _room() != old_room, "the respawn rebuilt the room: a new Room instance (AR25)")
	check(Game.dive.is_killed(&"m1_shaft", victim_cell), "the kill was marked on the dive (room m1_shaft, cell %s)" % victim_cell)
	check(_crawlers().size() == crawlers - 1 and not _has_crawler_at(victim_cell), "...and the crawler killed before the death stays dead in it (%d -> %d)" % [crawlers, _crawlers().size()])


## A free row whose two left tiles are wall then open, with room to the right: the player hangs
## in the open column at x 24, against the 1-tile wall.
func _gutter_row() -> int:
	for row in range(10, _room().size_cells.y - 10):
		if not _room().is_solid(Vector2i(0, row)):
			continue
		var open := true
		for col in range(1, 6):
			open = open and not _room().is_solid(Vector2i(col, row))
		if open:
			return row
	return -1


## Code review 1.16: World makes the pogo → shake wire on every spawn (_swap_room), and no test
## failed without it (smoke_a11y wires its own harness). The signal a real pogo emits, on the
## player World respawned, must reach the rig.
func test_pogo_wire() -> void:
	var p := _player()
	_camera().snap()
	await frames(1)
	check(_camera().offset == Vector2.ZERO, "setup: the camera is still before the hit (offset %s)" % _camera().offset)
	p.pogo_hit.emit()
	var moved := false
	for i in 3:
		await frames(1)
		moved = moved or _camera().offset != Vector2.ZERO
	check(moved, "World wires pogo_hit to the camera's kick on the respawned player: the hit shakes the view")
	_camera().snap()


## Code review 1.16, AC6: World._swap_room() calls Fx.warm_up() after the room enters the tree, so
## the four items are under the room when room_entered fires (death, respawn and the bottom loop
## above each load a room).
func test_warm_up_at_room_load() -> void:
	check(not _warm_counts.is_empty() and _warm_counts.all(func(n: int) -> bool: return n == 4),
			"every room load warms up: four items at Fx.WARM_ALPHA under the room at room_entered (got %s over %d loads)" % [_warm_counts, _warm_counts.size()])


## AC2: a lurker inside the viewport but behind a gutter never notices; a control lurker in the
## play area at the same distance does (so this test can fail).
func test_behind_the_gutter() -> void:
	var p := _player()
	var row := _gutter_row()
	check(row >= 0, "found a row with a 1-tile left wall and open tiles beside it (row %d)" % row)
	var y := row * Room.TILE + 8.0
	p.set_physics_process(false)
	p.global_position = Vector2(24, y)
	p.velocity = Vector2.ZERO
	_camera().snap()
	var steady := _world.play_rect()
	check(is_equal_approx(steady.get_center().y, y), "play_rect() is on the player the same frame as the snap, not a frame late (centre y %.1f, player %.1f)" % [steady.get_center().y, y])
	_camera().kick(6.0)
	await frames(2)  # the rig moves on the physics tick (Story 1.7 D8)
	check(_camera().offset != Vector2.ZERO and _world.play_rect().is_equal_approx(steady), "a shake moves the view but never play_rect(): noticing has no randomness (offset %s)" % _camera().offset)
	_camera().snap()
	for i in 4:
		p.chain.add_hit()  # light ~84 px: noticed from up to ~134 px
	_set_room_lurkers_active(false)
	var a: Lurker = _room().spawn(LurkerScene, Vector2(-24, y))
	var b: Lurker = _room().spawn(LurkerScene, Vector2(72, y))
	await frames(2)
	var canvas_x := a.get_global_transform_with_canvas().origin
	check(get_viewport().get_visible_rect().has_point(canvas_x) and canvas_x.x < 60.0, "lurker A is inside the viewport, behind the left gutter (screen %s)" % canvas_x)
	check(not _world.play_rect().has_point(a.global_position), "...and outside play_rect()")
	# Lurker B's eyes are sampled every tick of its telegraph (code review 1.16: the rate the game
	# runs, measured on a real lurker and not read back from Fx.EFFECTS).
	var eyes := b.get_node("Eyes") as Sprite2D
	var alphas: Array[float] = []
	for i in int(ceil(0.3 * Engine.physics_ticks_per_second)):
		await frames(1)
		if b.state == Lurker.State.TELEGRAPH:
			alphas.append(eyes.modulate.a)
	check(b.state == Lurker.State.TELEGRAPH, "control: lurker B in the play area, 48 px away, telegraphs (state %d)" % b.state)
	check(a.state == Lurker.State.IDLE, "lurker A behind the gutter, 48 px away, never notices (state %d)" % a.state)
	for i in 120:
		if b.state != Lurker.State.TELEGRAPH:
			break  # it hunts from here: removed below, 48 px from the player
		await frames(1)
		alphas.append(eyes.modulate.a)
	# Peak to trough is half a cycle. Each turn is read within half a tick, so a telegraph of under a
	# second tells about 2.2 Hz from 2.0; the 10 s sample in test_fx is the fine check.
	var turns := Rate.turns(alphas)
	var band := Rate.hz_band(turns, Engine.physics_ticks_per_second, 2)
	check(turns.size() >= 3 and band.x <= Spec.PULSE_HZ_MAX, "a real lurker's eyes pulse at no more than %s Hz through its telegraph (Spec.PULSE_HZ_MAX; at least %.2f Hz from %d turns in %d ticks)" % [Spec.PULSE_HZ_MAX, band.x, turns.size(), alphas.size()])
	_room().remove_child(a)
	_room().remove_child(b)
	a.queue_free()
	b.queue_free()
	p.chain.break_chain()
	p.set_physics_process(true)


## D6, Pillar 2: a hunt never carries over a death onto the respawned player.
func test_hunt_over_death() -> void:
	var p := _player()
	p.set_physics_process(false)
	for i in 8:
		p.chain.add_hit()
	var c: Lurker = _room().spawn(LurkerScene, p.global_position + Vector2(70, 0))
	await frames(1)
	c.force(Lurker.State.HUNT, p.light_source)
	await frames(1)
	check(c.state == Lurker.State.HUNT, "precondition: the lurker hunts the player")
	p.die()
	await frames(1)
	# The state is the proof: without D6 it stays in HUNT for lurker_lose_track_time (0.6 s), so a
	# refetch after the respawn would keep hunting the new player with no telegraph. RETURN, or
	# already IDLE: it hunted from home, so RETURN reaches home in the same frame.
	var dropped := c.state == Lurker.State.RETURN or c.state == Lurker.State.IDLE
	check(dropped, "one frame after the death the lurker drops the hunt (state %d)" % c.state)
	await seconds(World.RESPAWN_DELAY + 0.1)
	check(_spawned.size() == 2 and _player() == _spawned[1], "a second death respawns again")
	check(not is_instance_valid(c), "...and the rebuild took the hunting lurker away with the old room")


func _has_crawler_at(cell: Vector2i) -> bool:
	return _crawlers().any(func(c: Crawler) -> bool: return c.cell == cell)


## R16 (AC3, AC4): the bottom exit loops to the top entry of m1_shaft. A live chain is banked first,
## like a landing, and a crawler killed before the loop is still gone in the rebuilt room.
func test_bottom_loop() -> void:
	var p := _player()
	var victim: Crawler = _crawlers()[-1]  # the lowest
	var victim_cell := victim.cell
	victim.take_hit()
	await frames(1)
	var crawlers := _crawlers().size()
	var old_room := _room()
	var carried := Game.dive.carried
	for i in 3:
		p.chain.add_hit()  # held 1 + 2 + 3 = 6
	var seen := []
	_world.room_entered.connect(_record_entry.bind(seen), CONNECT_ONE_SHOT)
	p.global_position = Vector2(24, _room().bounds().end.y - 8)  # in the floor hole (cols 1-2)
	p.velocity = Vector2(0, 150)
	for i in 60:
		if not seen.is_empty():
			break
		await frames(1)
	check(seen.size() == 1 and seen[0].id == &"m1_shaft", "falling through the floor hole enters m1_shaft again (got %s)" % [seen])
	if seen.is_empty():
		return
	check(seen[0].count == 0 and seen[0].carried == carried + 6, "...with the chain of 3 banked first: carried +6, chain 0 when the room is entered (carried %d -> %d)" % [carried, seen[0].carried])
	check(seen[0].position == Vector2(56, 20) and seen[0].vy > 0.0, "...placed at the top entry (56, 20), still falling (got %s, vy %.1f)" % [seen[0].position, seen[0].vy])
	check(_player() == p and _room() != old_room, "...the same player, in a rebuilt room")
	check(_crawlers().size() == crawlers and not _has_crawler_at(victim_cell), "...and the crawler killed before the loop is still gone (%d crawlers)" % _crawlers().size())


func _record_entry(id: StringName, out: Array) -> void:
	var p := _player()
	out.append({id = id, count = p.chain.count, carried = Game.dive.carried, position = p.position, vy = p.velocity.y})


func test_screen_router() -> void:
	var router: ScreenRouter = _world.get_node("UI/ScreenRouter")
	var a := Control.new()
	var b := Control.new()
	router.open(a)
	router.open(b)
	check(router.current() == b and a.get_parent() == null and router.get_child_count() == 1, "open(a) then open(b): b replaces a, never stacks")
	router.open(b)
	check(router.current() == b and is_instance_valid(b) and not b.is_queued_for_deletion() and b.get_parent() == router, "open(b) while b is open keeps b: replacing a screen with itself never frees it")
	router.close()
	check(router.current() == null and router.get_child_count() == 0, "close() leaves no screen")
	var c := Control.new()
	router.open(c)
	router.remove_child(c)
	add_child(c)  # someone moved it away
	router.close()
	check(router.current() == null and is_instance_valid(c) and not c.is_queued_for_deletion(), "close() after the screen moved elsewhere forgets it without freeing it")
	c.queue_free()


## AC2 and AC4 by source, until the lint takes them over in 1.9.
func test_sources() -> void:
	var lurker := FileAccess.get_file_as_string("res://scripts/actors/lurker.gd")
	check(not lurker.is_empty() and not lurker.contains("get_viewport_rect"), "lurker.gd never reads the viewport rect")
	var hits: Array[String] = []
	_scan("res://scripts", hits)
	check(hits == ["res://scripts/world/camera_rig.gd"], "randf appears only in world/camera_rig.gd (got %s)" % [hits])
	# AC5 (Story 1.7): the M1 shaft is gone, and with it the function keys and the scene reload.
	check(not FileAccess.file_exists("res://scripts/shaft.gd") and not FileAccess.file_exists("res://scenes/shaft.tscn"), "shaft.gd and shaft.tscn are deleted")
	for needle in ["KEY_F", "reload_current_scene"]:
		var found: Array[String] = []
		_scan("res://scripts", found, needle)
		check(found.is_empty(), "no %s under scripts/ (got %s)" % [needle, found])


func _scan(dir: String, hits: Array[String], needle := "randf") -> void:
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(sub), hits, needle)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") and FileAccess.get_file_as_string(dir.path_join(f)).contains(needle):
			hits.append(dir.path_join(f))
