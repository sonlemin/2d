extends Node
## Headless smoke test of room swaps (Story 1.7 D11): World.enter_room() between the two test rooms
## in tests/rooms/swap/, the exit backstop, arrival from above and below, the killed-enemy rule
## across a swap and a cross-room respawn, and physics interpolation on.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_room_swap.gd
## A: P on a ledge, a walker at (7, 6), a floor hole at cols 1-2 down to B.
## B: no P, a walker at (7, 3), a ceiling gap at col 4 up to A.

const WorldScene := preload("res://scenes/world/world.tscn")
const TMP := "user://smoke_room_swap_tmp"
const A := &"t_swap_a"
const B := &"t_swap_b"
const A_WALKER := Vector2i(7, 6)

var _fail := 0
var _world: World
var _entered: Array[Dictionary] = []
var _spawned: Array[Player] = []
var _prev_room: Room  # the room before the latest entry


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
	RoomLoader.add_root("res://tests/rooms/swap")
	_world = WorldScene.instantiate()
	_world.start_room = A
	add_child(_world)
	_prev_room = _world.current_room()
	_world.room_entered.connect(_on_entered)
	_world.player_spawned.connect(_on_spawned)
	await frames(2)
	test_boot()
	await test_deferred()
	test_kill()
	await test_down_with_chain()
	await test_up_from_below()
	await test_cross_room_respawn()
	await test_chained_entry()
	await test_death_cancels_swap()
	test_interpolation()
	_world.queue_free()
	await frames(1)
	Game.reset_for_tests()
	DirAccess.remove_absolute(TMP)
	print("SMOKE %s" % ("PASS" if _fail == 0 else "FAILED (%d)" % _fail))


## Recorded at the moment of entry: what was true when room_entered fired.
func _on_entered(id: StringName) -> void:
	var p := _player()
	_entered.append({
		id = id, room = _world.current_room(), count = p.chain.count, carried = Game.dive.carried,
		position = p.position, velocity = p.velocity,
		# AR24: removed from the tree before queue_free(), so at entry it is out but not yet freed.
		prev_valid = is_instance_valid(_prev_room), prev_in_tree = is_instance_valid(_prev_room) and _prev_room.is_inside_tree(),
		# ...so its enemies and predators have already left their groups.
		stray = (get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("predator")).filter(
				func(e: Node) -> bool: return not _world.current_room().is_ancestor_of(e)).size(),
		# The engine camera draws what the rig computes, from the first frame of the room.
		engine_centre = (_world.get_node("Camera") as Camera2D).get_screen_center_position(),
		rig_centre = (_world.get_node("Camera") as CameraRig).play_rect().get_center(),
	})
	_prev_room = _world.current_room()


func _on_spawned(player: Player) -> void:
	_spawned.append(player)


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _room() -> Room:
	return _world.current_room()


func _crawlers() -> Array:
	var out := get_tree().get_nodes_in_group("enemy").filter(func(e: Node) -> bool: return not e.is_queued_for_deletion())
	out.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.y < b.global_position.y)
	return out


## Waits until room_entered has fired `n` times in all, up to `cap` physics frames.
func _until_entered(n: int, cap := 60) -> void:
	for i in cap:
		if _entered.size() >= n:
			return
		await frames(1)


func test_boot() -> void:
	check(_room() != null and _room().id == A, "World starts in its start_room, t_swap_a (got %s)" % (_room().id if _room() else &"none"))
	check(_player() != null and _player().position == _room().entry_position(&"spawn"), "...with the player at A's P")
	check(Game.slot.has_visited(A), "...and the first room counts as visited")


## AR24: enter_room() never swaps on the spot; the swap runs at the end of the frame.
func test_deferred() -> void:
	var before := _room()
	_world.enter_room(B, &"up")
	check(_room() == before, "enter_room() is deferred: the room is unchanged on the same line")
	await get_tree().process_frame
	check(_room().id == B and _entered.size() == 1, "...and swapped by the next frame (room %s)" % _room().id)
	if _entered.size() == 1:
		check(_entered[0].prev_valid and _entered[0].stray == 0, "at entry, A's live walker has already left the enemy group: the old room left the tree before queue_free() (%d left)" % _entered[0].stray)
		check(_entered[0].engine_centre.is_equal_approx(_entered[0].rig_centre), "...and the engine camera already shows the rig's centre (engine %s, rig %s)" % [_entered[0].engine_centre, _entered[0].rig_centre])
	check(not is_instance_valid(before) or not before.is_inside_tree(), "...the old room out of the tree")
	_world.enter_room(A, &"down")
	await get_tree().process_frame
	check(_room().id == A, "enter_room(A, down) brings the player back to A")
	await frames(30)  # settle on A's floor
	_entered.clear()


func test_kill() -> void:
	var walker: Crawler = null
	for c: Crawler in _crawlers():
		if c.cell == A_WALKER:
			walker = c
	check(walker != null and walker.room_id == A, "A's walker is built with its room and cell")
	if walker != null:
		walker.take_hit()
	check(Game.dive.is_killed(A, A_WALKER), "killing it marks (t_swap_a, %s) on the dive" % A_WALKER)


## AC1, AC3's rule on a test pair: the floor hole goes to B, the chain is banked first.
func test_down_with_chain() -> void:
	var p := _player()
	var old := _room()
	var carried := Game.dive.carried
	for i in 3:
		p.chain.add_hit()  # held 1 + 2 + 3 = 6
	p.global_position = Vector2(24, 120)  # in the floor hole, row 7
	p.velocity = Vector2(0, 150)
	await _until_entered(1)
	check(_entered.size() == 1 and _entered[0].id == B, "falling through A's floor hole enters t_swap_b once (got %s)" % [_entered.map(func(e: Dictionary) -> StringName: return e.id)])
	if _entered.is_empty():
		return
	var e: Dictionary = _entered[0]
	check(e.count == 0 and e.carried == carried + 6, "the chain of 3 was banked before the swap: chain 0, carried +6 (carried %d -> %d)" % [carried, e.carried])
	check(e.position == Vector2(72, 20) and e.velocity.y > 0.0, "the player arrives one cell inside B's ceiling gap, still falling (got %s, vy %.1f)" % [e.position, e.velocity.y])
	check(e.prev_valid and not e.prev_in_tree, "at the moment of entry A is out of the tree but not yet freed: removed before queue_free()")
	check(not is_instance_valid(old) or not old.is_inside_tree(), "A is out of the tree")
	check(_player() == p, "the same Player crosses: only a death makes a new one")
	var cam: CameraRig = _world.get_node("Camera")
	var want_limits := [-(480 - 160) / 2, -(480 - 160) / 2 + 480, 0, 80]
	check([cam.limit_left, cam.limit_right, cam.limit_top, cam.limit_bottom] == want_limits, "the camera limits are B's (got %s, want %s)" % [[cam.limit_left, cam.limit_right, cam.limit_top, cam.limit_bottom], want_limits])
	check(Game.slot.has_visited(B), "B counts as visited")
	await frames(1)
	check(not is_instance_valid(old), "...and A is freed a frame later")


## D3: arriving from below stands on the floor beside the hole, still, and stays there.
func test_up_from_below() -> void:
	var p := _player()
	await frames(20)  # land in B
	p.global_position = Vector2(72, -2)  # in B's ceiling gap, col 4
	p.velocity = Vector2(0, -100)
	await _until_entered(2)
	check(_entered.size() == 2 and _entered[1].id == A, "rising through B's ceiling gap enters t_swap_a")
	if _entered.size() < 2:
		return
	var e: Dictionary = _entered[1]
	check(e.position == Vector2(56, 100) and e.velocity == Vector2.ZERO, "arriving from below: standing on the floor beside A's hole at (56, 100), velocity zero (got %s, %s)" % [e.position, e.velocity])
	await frames(30)
	check(_room().id == A and p.is_on_floor() and _entered.size() == 2, "30 frames later it is still in A, on the floor: it never fell back through the hole")
	var cells := _crawlers().map(func(c: Crawler) -> Vector2i: return c.cell)
	check(not cells.has(A_WALKER), "A was rebuilt without the walker killed this dive (crawlers at %s)" % [cells])


## AR25: a death in B respawns at the start room's P, through the rebuild.
func test_cross_room_respawn() -> void:
	var p := _player()
	var players_at_add := []
	_world.get_node("RoomHolder").child_entered_tree.connect(_count_players.bind(players_at_add))
	p.global_position = Vector2(24, 120)
	p.velocity = Vector2(0, 150)
	await _until_entered(3)
	check(_room().id == B, "back down in B")
	var b_cells := _crawlers().map(func(c: Crawler) -> Vector2i: return c.cell)
	check(b_cells == [Vector2i(7, 3)], "control: a rebuilt room still builds the enemies nobody killed (B's walker; got %s)" % [b_cells])
	await frames(10)
	p.die()
	await seconds(World.RESPAWN_DELAY + 0.1)
	check(_room().id == A and _entered.size() == 4 and _entered[3].id == A, "a death in B respawns in t_swap_a, the start room (room %s)" % _room().id)
	var q := _player()
	check(q != p and _spawned.size() == 1 and _spawned[0] == q, "...as a new Player, announced by player_spawned")
	check(q.position == _room().entry_position(&"spawn"), "...at A's P (got %s)" % q.position)
	var cells := _crawlers().map(func(c: Crawler) -> Vector2i: return c.cell)
	check(not cells.has(A_WALKER), "...and A's killed walker is still gone (crawlers at %s)" % [cells])
	_world.get_node("RoomHolder").child_entered_tree.disconnect(_count_players)
	check(players_at_add.size() >= 1 and players_at_add[-1] == 0, "the dead player had left group player before the respawn room entered the tree (players at each room add: %s)" % [players_at_add])


func _count_players(_node: Node, out: Array) -> void:
	out.append(get_tree().get_nodes_in_group("player").size())


## A room_entered handler may send the player on at once (a scripted moment, a station).
func test_chained_entry() -> void:
	var n := _entered.size()
	_world.room_entered.connect(_forward_to_a, CONNECT_ONE_SHOT)
	_world.enter_room(B, &"up")
	await frames(3)
	check(_entered.size() == n + 2 and _entered[-1].id == A and _room().id == A, "enter_room() from a room_entered handler is not dropped: B, then on to A (got %s)" % [_entered.slice(n).map(func(e: Dictionary) -> StringName: return e.id)])
	await frames(20)


func _forward_to_a(_id: StringName) -> void:
	_world.enter_room(A, &"down")


## A death between the crossing and the swap: the room is never built, visited or announced.
func test_death_cancels_swap() -> void:
	var n := _entered.size()
	var before := _room()
	Game.slot.reset()  # forget the visits so far
	_world.enter_room(B, &"up")
	_player().die()
	await get_tree().process_frame
	check(_room() == before and _entered.size() == n and not Game.slot.has_visited(B), "a player who dies before the deferred swap never enters B: no swap, no visit, no room_entered")
	await seconds(World.RESPAWN_DELAY + 0.1)
	check(_room().id == A and _entered.size() == n + 1 and _player() != null and not _player().is_dead, "...and the respawn rebuilds A as usual")


## AC2: interpolation on, and every teleport resets it (by source, until 1.9's lint).
func test_interpolation() -> void:
	check(ProjectSettings.get_setting("physics/common/physics_interpolation") == true and get_tree().physics_interpolation, "2D physics interpolation is on")
	check(Engine.physics_ticks_per_second == 60, "...at 60 ticks")
	check(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel") == true, "...with snap_2d_transforms_to_pixel kept")
	var world := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	check(_body_of(world, "_spawn_player").contains("reset_physics_interpolation()") and _body_of(world, "_swap_room").contains("_player.reset_physics_interpolation()"), "world.gd resets interpolation when it spawns and when it places the player")
	var rig := FileAccess.get_file_as_string("res://scripts/world/camera_rig.gd")
	check(_body_of(rig, "snap").contains("reset_physics_interpolation()"), "camera_rig.gd resets it on a snap")


## The text of `func name(` up to the next top-level func.
func _body_of(source: String, name: String) -> String:
	var at := source.find("func %s(" % name)
	if at < 0:
		return ""
	var end := source.find("\nfunc ", at + 1)
	return source.substr(at, end - at if end > 0 else -1)
