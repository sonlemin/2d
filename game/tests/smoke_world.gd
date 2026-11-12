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

var _fail := 0
var _world: World
var _spawned: Array[Player] = []
var _spawned_at: Array[Vector2] = []


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
	test_no_boot()
	test_tree(scene_before)
	test_framing()
	test_chain_and_bank()
	test_brightness()
	test_popups_in_room()
	await test_death_and_respawn()
	await test_behind_the_gutter()
	await test_hunt_over_death()
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
	check(_room().get_child_count() == in_room + 1, "a bank's popup goes under the room (room children %d -> %d)" % [in_room, _room().get_child_count()])
	check(_world.get_child_count() == in_world, "...and nothing goes under World")


func test_death_and_respawn() -> void:
	var old := _player()
	var spawn := _room().entry_position(&"spawn")
	var crawlers := _crawlers().size()
	Game.clock.request(&"hitstop", 0.05, 0.075)
	_crawlers()[0].take_hit()  # the topmost crawler, killed this dive
	var carried := Game.dive.carried
	for i in 2:
		old.chain.add_hit()
	old.global_position += Vector2(0, 160)  # die away from P
	old.die()
	check(Game.slot.deaths == 1, "a death records one death on the slot (got %d)" % Game.slot.deaths)
	check(Game.dive.carried == carried and old.chain.held == 0, "...keeps the carried embers and loses the held ones (carried %d, held %d)" % [Game.dive.carried, old.chain.held])
	check(not Game.clock.is_active(&"hitstop") and is_equal_approx(Engine.time_scale, 1.0), "...and clears the Clock: no hitstop survives a death")
	await seconds(World.RESPAWN_DELAY + 0.1)
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
	check(_crawlers().size() == crawlers - 1, "the crawler killed before the death stays dead: the room was not rebuilt (%d -> %d)" % [crawlers, _crawlers().size()])


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
	for i in 4:
		p.chain.add_hit()  # light ~84 px: noticed from up to ~134 px
	_set_room_lurkers_active(false)
	var a: Lurker = _room().spawn(LurkerScene, Vector2(-24, y))
	var b: Lurker = _room().spawn(LurkerScene, Vector2(72, y))
	await frames(2)
	var canvas_x := a.get_global_transform_with_canvas().origin
	check(get_viewport().get_visible_rect().has_point(canvas_x) and canvas_x.x < 60.0, "lurker A is inside the viewport, behind the left gutter (screen %s)" % canvas_x)
	check(not _world.play_rect().has_point(a.global_position), "...and outside play_rect()")
	await seconds(0.3)
	check(b.state == Lurker.State.TELEGRAPH, "control: lurker B in the play area, 48 px away, telegraphs (state %d)" % b.state)
	check(a.state == Lurker.State.IDLE, "lurker A behind the gutter, 48 px away, never notices (state %d)" % a.state)
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
	c._enter(Lurker.State.HUNT)
	await frames(1)
	check(c.state == Lurker.State.HUNT, "precondition: the lurker hunts the player")
	p.die()
	await frames(1)
	# RETURN, or already IDLE: it hunted from home, so RETURN reaches home in the same frame.
	# Without D6 it would stay in HUNT for lurker_lose_track_time (0.6 s).
	var dropped := c.state == Lurker.State.RETURN or c.state == Lurker.State.IDLE
	check(dropped and not c.monitorable, "one frame after the death the lurker drops the hunt and is harmless (state %d, monitorable %s)" % [c.state, c.monitorable])
	await seconds(World.RESPAWN_DELAY + 0.1)
	check(_spawned.size() == 2 and _player() == _spawned[1], "a second death respawns again")
	check(c.state != Lurker.State.HUNT and not c.monitorable, "...and the lurker is not hunting the new player")
	_room().remove_child(c)
	c.queue_free()


func test_screen_router() -> void:
	var router: ScreenRouter = _world.get_node("UI/ScreenRouter")
	var a := Control.new()
	var b := Control.new()
	router.open(a)
	router.open(b)
	check(router.current() == b and a.get_parent() == null and router.get_child_count() == 1, "open(a) then open(b): b replaces a, never stacks")
	router.close()
	check(router.current() == null and router.get_child_count() == 0, "close() leaves no screen")


## AC2 and AC4 by source, until the lint takes them over in 1.9.
func test_sources() -> void:
	var lurker := FileAccess.get_file_as_string("res://scripts/actors/lurker.gd")
	check(not lurker.is_empty() and not lurker.contains("get_viewport_rect"), "lurker.gd never reads the viewport rect")
	var hits: Array[String] = []
	_scan("res://scripts", hits)
	check(hits == ["res://scripts/world/camera_rig.gd"], "randf appears only in world/camera_rig.gd (got %s)" % [hits])


func _scan(dir: String, hits: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(sub), hits)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") and FileAccess.get_file_as_string(dir.path_join(f)).contains("randf"):
			hits.append(dir.path_join(f))
