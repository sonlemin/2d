extends Node
## Headless integration smoke test: loads m1_shaft standalone (RoomLoader + a test player, Story
## 1.5), drives inputs, and checks the loop. Positions come from the room API, never literals.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_shaft.gd
## Exits 0 on pass. (Import the project once first so textures resolve.)

const RoomHarness := preload("res://tests/room_harness.gd")
const Spec := preload("res://tests/spec.gd")
## The long run: the hoverers between the row-41 ledge and the row-85 platform (M1's rows, kept).
const LONG_RUN_ROWS := Vector2i(44, 84)

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
	_build()
	await frames(2)
	test_world_stub()
	await test_pogo_builds_chain()
	await test_landing_breaks_chain()
	await test_jump_height()
	await test_wall_cling()
	await test_bot_chains_long_run()
	await test_lurker_telegraph_hunt_lose()
	await test_snuff_escape_point_blank()
	await test_lurker_kills()
	await test_snuff_needs_hold()
	RoomHarness.free_all(_parts)
	print("SMOKE %s" % ("PASS" if _fail == 0 else "FAILED (%d)" % _fail))


## Teleport the player and snap the camera, so on-screen checks see the real view.
func place(pos: Vector2) -> void:
	_player.global_position = pos
	_player.velocity = Vector2.ZERO
	_parts.camera.snap()


func _build() -> void:
	_parts = RoomHarness.build(self, &"m1_shaft")
	_room = _parts.room
	_player = _parts.player


## The stub World the lurkers will read from 1.6: the play area between the gutters.
func test_world_stub() -> void:
	var w := get_tree().get_first_node_in_group("world")
	check(w != null and w.has_method("play_rect") and w.play_rect().size.x == 360.0, "a stub World in group world gives a 360 px play_rect()")


## Sorted by height, never by group order: [0] is the top lurker (row 28).
func _lurkers() -> Array:
	var out := get_tree().get_nodes_in_group("predator")
	out.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
	return out


func set_lurkers_active(on: bool) -> void:
	for l in get_tree().get_nodes_in_group("predator"):
		l.set_physics_process(on)


func _hovers() -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.hover:
			out.append(e)
	out.sort_custom(func(a, b): return a.position.y < b.position.y)
	return out


## A tap or brush of Light (V is next to Dash) must never break the chain; a real hold Snuffs.
func test_snuff_needs_hold() -> void:
	RoomHarness.free_all(_parts)  # the lurker test left the player dead: use a fresh room
	await frames(1)
	_build()
	await frames(2)
	place(_hovers()[0].global_position + Vector2(40, -60))
	await frames(1)
	for i in 5:
		_player.chain.add_hit()
	Input.action_press("light")
	await frames(4)  # ~0.07 s: a misclick
	Input.action_release("light")
	await frames(1)
	check(_player.chain.count == 5 and not _player.chain.snuffed, "tapping Light keeps the chain (got %d)" % _player.chain.count)
	Input.action_press("light")
	await frames(18)  # 0.3 s: a deliberate hold
	check(_player.chain.snuffed and _player.chain.count == 0, "holding Light Snuffs and breaks the chain")
	Input.action_release("light")
	await frames(1)
	check(not _player.chain.snuffed, "releasing Light ends the Snuff")


## Wall cling: hold Jump at a wall while falling -> chain paused + hidden; grace ends -> banks;
## releasing Jump kicks you away from the wall.
func test_wall_cling() -> void:
	var y: float = _hovers()[2].global_position.y
	var row := int(y / Room.TILE)
	check(_room.is_solid(Vector2i(0, row)) and not _room.is_solid(Vector2i(1, row)), "row %d: the left wall is 1 tile, open beside it" % row)
	place(Vector2(Room.TILE + 5.5, y))  # body (10 px wide) touching the 1-tile left wall, mid-air
	_player._cling_left = Game.tuning.f(&"cling_grace")
	for i in 6:
		_player.chain.add_hit()
	var held: int = _player.chain.held
	Input.action_press("move_left")
	await frames(2)
	Input.action_release("move_left")
	Input.action_press("jump")
	await seconds(0.4)
	check(_player._clinging, "holding Jump at a wall while falling clings")
	check(_player.chain.count == 6 and _player.chain.held == held, "cling keeps the chain (got %d)" % _player.chain.count)
	check(is_equal_approx(_player.light_radius(), ChainState.BASE_RADIUS), "cling hides the chain-light")
	await seconds(0.8)
	check(_player.chain.count == 0 and _player.chain.held == 0, "grace runs out -> the chain breaks (banks)")
	Input.action_release("jump")
	await frames(2)
	check(not _player._clinging and _player.velocity.x > 0.0, "releasing Jump kicks off the wall")
	await seconds(0.3)


func test_pogo_builds_chain() -> void:
	var target: Node2D = _hovers()[0]
	place(target.global_position + Vector2(0, -40))
	var hit := false
	for i in 60:
		if not hit and target.global_position.y - _player.global_position.y < 26:
			Input.action_press("attack")
			await frames(1)
			Input.action_release("attack")
			hit = true
		await frames(1)
		if _player.chain.count > 0:
			break
	check(_player.chain.count == 1, "X alone in the air pogoes -> chain 1 (got %d)" % _player.chain.count)
	check(_player.velocity.y < 0.0, "pogo bounces the player up")
	check(_player.chain.light_radius() > ChainState.BASE_RADIUS, "chain grows the light")


func test_landing_breaks_chain() -> void:
	_player.chain.add_hit()
	_player.chain.add_hit()
	place(_room.entry_position(&"spawn") + Vector2(0, -40))  # above the spawn ledge
	await seconds(1.0)
	check(_player.is_on_floor(), "player landed on the spawn ledge")
	check(_player.chain.count == 0, "landing breaks the chain")


## Measures a real jump from the spawn ledge: holding Jump peaks about 60 px up (3.8 tiles);
## tapping it cuts the jump short (variable height).
func test_jump_height() -> void:
	var full := await _measure_jump(true)
	var tap := await _measure_jump(false)
	check(full >= 55.0 and full <= 66.0, "held jump peaks ~60 px (got %.1f)" % full)
	check(tap < full * 0.6, "tapped jump is much lower than held (tap %.1f vs held %.1f)" % [tap, full])


func _measure_jump(hold: bool) -> float:
	place(_room.entry_position(&"spawn"))  # standing on the spawn ledge
	await frames(5)
	var start_y := _player.global_position.y
	var top := start_y
	Input.action_press("jump")
	for i in 90:
		await frames(1)
		if not hold and i == 2:
			Input.action_release("jump")
		top = minf(top, _player.global_position.y)
		if i > 5 and _player.is_on_floor():
			break
	Input.action_release("jump")
	await frames(2)
	return start_y - top


## Level-design reachability: a simple bot drops into the long run (chain run 2) and
## steers toward the next hover crawler below. It must reach a chain of 5+, which
## proves the spacing is pogo-able with plain run speed (no dash needed).
## Lurkers are paused: this checks reachability, not survival.
func test_bot_chains_long_run() -> void:
	var run := _hovers().filter(func(h): return h.position.y > LONG_RUN_ROWS.x * Room.TILE and h.position.y < LONG_RUN_ROWS.y * Room.TILE)
	set_lurkers_active(false)
	_player.chain.break_chain()
	for h in run:
		h.reset_phase()  # same drift every run, whatever ran before (test order must not matter)
	await frames(1)
	place(run[0].global_position + Vector2(0, -48))
	var best := 0
	var swung_for: Node2D = null
	var last_row_y := -INF  # the hit crawler is freed, so remember its row as a number
	var i_end := 0
	for i in 600:
		i_end = i
		if _player.is_dead or (i > 5 and _player.is_on_floor()):  # is_on_floor is stale until the next move
			break
		# Like a player: aim for the nearest target below (rows now offer a left/right choice).
		var next: Node2D = null
		# ...in a row below the one just pogoed (not its partner in the same row).
		var floor_y := maxf(_player.global_position.y + 4, last_row_y + 8)
		for h in run:
			if not is_instance_valid(h) or h.global_position.y <= floor_y:
				continue
			if next == null or h.global_position.distance_to(_player.global_position) < next.global_position.distance_to(_player.global_position):
				next = h
		if next == null:
			break
		var dx := next.global_position.x - _player.global_position.x
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(dx) > 3.0:
			Input.action_press("move_right" if dx > 0 else "move_left")
		var dy := next.global_position.y - _player.global_position.y
		if dy < 28 and absf(dx) < 12 and _player.velocity.y > 0 and swung_for != next:
			swung_for = next
			last_row_y = next.global_position.y
			Input.action_press("attack")
			await frames(1)
			Input.action_release("attack")
		await frames(1)
		best = maxi(best, _player.chain.count)
	for a in ["move_left", "move_right"]:
		Input.action_release(a)
	print("     bot ended: frame %d, dead=%s, floor=%s, y=%d" % [i_end, _player.is_dead, _player.is_on_floor(), int(_player.global_position.y / 16)])
	check(best >= Spec.BOT_MIN_CHAIN, "bot chains %d+ pogos through the long run (Spec.BOT_MIN_CHAIN; best %d)" % [Spec.BOT_MIN_CHAIN, best])
	check(not _player.is_dead, "bot survived the reachability run (lurkers paused)")
	set_lurkers_active(true)
	_player.chain.break_chain()


func test_lurker_telegraph_hunt_lose() -> void:
	var lurker: Lurker = _lurkers()[0]
	Game.clock.clear()
	_player.set_physics_process(false)  # freeze the player so only the lurker acts
	place(lurker.global_position + Vector2(100, 0))
	for i in 8:
		_player.chain.add_hit()
	for i in 10:
		await frames(1)
		if lurker.state == Lurker.State.TELEGRAPH:
			break
	check(lurker.state == Lurker.State.TELEGRAPH, "big light in range -> lurker telegraphs")
	var telegraph := Game.tuning.f(&"lurker_telegraph_time")
	check(telegraph >= Spec.TELEGRAPH_MIN, "the telegraph lasts at least Spec.TELEGRAPH_MIN %.2f s (tuning %.2f s)" % [Spec.TELEGRAPH_MIN, telegraph])
	# Measure it, rather than probe at a guess: frames seen in TELEGRAPH until it ends (it may
	# have started up to a frame before we saw it, so the floor is checked to within one frame).
	var held := 0
	while lurker.state == Lurker.State.TELEGRAPH and held < 600:
		await frames(1)
		held += 1
	var floor_frames := int(ceil(Spec.TELEGRAPH_MIN * Engine.physics_ticks_per_second))
	check(held + 1 >= floor_frames, "the telegraph lasted %d frames, at least Spec.TELEGRAPH_MIN %.2f s (%d frames, to within one)" % [held, Spec.TELEGRAPH_MIN, floor_frames])
	check(lurker.state == Lurker.State.HUNT, "hunting after the telegraph")
	var d0 := lurker.global_position.distance_to(_player.global_position)
	await seconds(0.3)
	check(lurker.global_position.distance_to(_player.global_position) < d0, "hunting lurker closes in")
	_player.chain.set_snuffed(true)
	await seconds(1.0)
	check(lurker.state == Lurker.State.RETURN or lurker.state == Lurker.State.IDLE, "Snuff -> loses track within 1 s")
	_player.chain.set_snuffed(false)
	# Small light (no chain) must never be noticed, even point-blank.
	_player.chain.break_chain()
	place(lurker.global_position)
	await frames(1)
	check(_player.light_radius() <= Spec.BASE_LIGHT, "base light is at most Spec.BASE_LIGHT %.0f px (got %.1f)" % [Spec.BASE_LIGHT, _player.light_radius()])
	check(not lurker.senses(_player), "base light is never noticed, even point-blank")
	# The largest light under the notice floor is never noticed either, even point-blank; one more
	# link (over the lurker's own floor) is, from the same spot, so "never noticed" is not just
	# "never on screen" or "never in range". The lurker is paused so it only answers senses().
	set_lurkers_active(false)
	var under := 0
	while under < 30 and ChainState.radius_for(under + 1) < Spec.NOTICE_MIN_RADIUS:
		under += 1
	for i in under:
		_player.chain.add_hit()
	await frames(1)
	check(under > 0 and _player.light_radius() < Spec.NOTICE_MIN_RADIUS, "setup: chain %d gives %.1f px, the largest light under Spec.NOTICE_MIN_RADIUS %.0f px" % [under, _player.light_radius(), Spec.NOTICE_MIN_RADIUS])
	check(not lurker.senses(_player), "light under Spec.NOTICE_MIN_RADIUS is never noticed, even point-blank (chain %d)" % under)
	while _player.light_radius() < Lurker.NOTICE_MIN_RADIUS and _player.chain.count < 30:
		_player.chain.add_hit()
	await frames(1)
	check(lurker.senses(_player), "control: chain %d (%.1f px, over the lurker's floor) is noticed from the same spot" % [_player.chain.count, _player.light_radius()])
	check(Lurker.NOTICE_MIN_RADIUS >= Spec.NOTICE_MIN_RADIUS, "a lurker never wakes below Spec.NOTICE_MIN_RADIUS (Lurker.NOTICE_MIN_RADIUS %.0f)" % Lurker.NOTICE_MIN_RADIUS)
	_player.chain.break_chain()
	set_lurkers_active(true)
	# A big light whose lurker is off-screen must not be noticed (no off-screen ambush).
	for i in 20:
		_player.chain.add_hit()
	place(lurker.global_position + Vector2(0, 200))
	await frames(1)
	check(not lurker.senses(_player), "off-screen lurker can't notice (would telegraph unseen)")
	_player.chain.break_chain()


## Playtest: "saw it, couldn't escape". A Snuff in time must save you even with the lurker
## at full speed a body-length away: it is harmless the moment it loses the scent.
func test_snuff_escape_point_blank() -> void:
	var lurker: Lurker = _lurkers()[0]
	_player.set_physics_process(false)
	place(lurker.global_position + Vector2(60, 0))
	for i in 10:
		_player.chain.add_hit()
	lurker.global_position = _player.global_position + Vector2(-18, 0)
	lurker._enter(Lurker.State.HUNT)
	lurker._velocity = Vector2(Game.tuning.f(&"lurker_hunt_speed"), 0)
	await frames(1)
	_player.chain.set_snuffed(true)
	await seconds(1.2)
	check(not _player.is_dead, "Snuff with a hunting lurker 18 px away still saves you")
	check(lurker.state != Lurker.State.HUNT, "and the lurker gives up")
	_player.chain.set_snuffed(false)


func test_lurker_kills() -> void:
	var lurker: Lurker = _lurkers()[0]
	var died := [false]
	_player.died.connect(func(): died[0] = true)
	_player.set_physics_process(true)
	# An idle lurker is harmless: it has not telegraphed yet.
	var idle: Lurker = null
	for l in _lurkers():
		if l.state == Lurker.State.IDLE:
			idle = l
			break
	place(idle.global_position)
	await frames(3)
	check(not died[0], "touching an IDLE lurker does not kill (no telegraph yet)")
	for i in 10:
		_player.chain.add_hit()  # a big light: the lurker still has the scent
	lurker._enter(Lurker.State.HUNT)
	place(lurker.global_position)
	await frames(3)
	check(died[0] and _player.is_dead, "a HUNTING lurker kills on contact")
