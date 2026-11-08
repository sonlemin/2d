extends SceneTree
## Headless integration smoke test: loads the real shaft, drives inputs, and checks the loop.
## Run: godot --headless --path game --script res://tests/smoke_shaft.gd
## Exits 0 on pass. (Import the project once first so textures resolve.)

const ShaftScene := preload("res://scenes/shaft.tscn")

var _fail := 0
var _shaft: Node2D
var _player: Player


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func seconds(s: float) -> void:
	await frames(int(ceil(s * Engine.physics_ticks_per_second)))


func _run() -> void:
	_shaft = ShaftScene.instantiate()
	root.add_child(_shaft)
	_player = _shaft.get_node("Player")
	await frames(2)
	await test_pogo_builds_chain()
	await test_landing_breaks_chain()
	await test_jump_height()
	await test_bot_chains_long_run()
	await test_lurker_telegraph_hunt_lose()
	await test_lurker_kills()
	print("SMOKE %s" % ("PASS" if _fail == 0 else "FAILED (%d)" % _fail))
	quit(0 if _fail == 0 else 1)


## Teleport the player and snap the camera, so on-screen checks see the real view.
func place(pos: Vector2) -> void:
	_player.global_position = pos
	_player.velocity = Vector2.ZERO
	(_player.get_node("Camera") as Camera2D).reset_smoothing()


func set_lurkers_active(on: bool) -> void:
	for l in get_nodes_in_group("predator"):
		l.set_physics_process(on)


func _hovers() -> Array:
	var out := []
	for e in get_nodes_in_group("enemy"):
		if e.hover:
			out.append(e)
	out.sort_custom(func(a, b): return a.position.y < b.position.y)
	return out


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
	place(Vector2(5 * 16 + 8, 3 * 16))  # above the spawn ledge
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
	place(Vector2(5 * 16 + 8, 6 * 16 - 12))  # standing on the spawn ledge
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
	var run := _hovers().filter(func(h): return h.position.y > 44 * 16 and h.position.y < 84 * 16)
	set_lurkers_active(false)
	_player.chain.break_chain()
	place(run[0].global_position + Vector2(0, -48))
	var best := 0
	var swung_for: Node2D = null
	var i_end := 0
	for i in 600:
		i_end = i
		if _player.is_dead or (i > 5 and _player.is_on_floor()):  # is_on_floor is stale until the next move
			break
		var next: Node2D = null
		for h in run:
			if is_instance_valid(h) and h.global_position.y > _player.global_position.y + 4:
				next = h
				break
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
			Input.action_press("attack")
			await frames(1)
			Input.action_release("attack")
		await frames(1)
		best = maxi(best, _player.chain.count)
	for a in ["move_left", "move_right"]:
		Input.action_release(a)
	print("     bot ended: frame %d, dead=%s, floor=%s, y=%d" % [i_end, _player.is_dead, _player.is_on_floor(), int(_player.global_position.y / 16)])
	check(best >= 5, "bot chains 5+ pogos through the long run (best %d)" % best)
	check(not _player.is_dead, "bot survived the reachability run (lurkers paused)")
	set_lurkers_active(true)
	_player.chain.break_chain()


func test_lurker_telegraph_hunt_lose() -> void:
	var lurker: Lurker = get_nodes_in_group("predator")[0]
	Engine.time_scale = 1.0
	_player.set_physics_process(false)  # freeze the player so only the lurker acts
	place(lurker.global_position + Vector2(100, 0))
	for i in 8:
		_player.chain.add_hit()
	await frames(2)
	check(lurker.state == Lurker.State.TELEGRAPH, "big light in range -> lurker telegraphs")
	await seconds(0.7)
	check(lurker.state == Lurker.State.TELEGRAPH, "still telegraphing at 0.7 s (>= 0.75 s rule)")
	await seconds(0.35)
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
	check(not lurker.senses(_player), "base light is never noticed, even point-blank")
	# A big light whose lurker is off-screen must not be noticed (no off-screen ambush).
	for i in 20:
		_player.chain.add_hit()
	place(lurker.global_position + Vector2(0, 200))
	await frames(1)
	check(not lurker.senses(_player), "off-screen lurker can't notice (would telegraph unseen)")
	_player.chain.break_chain()


func test_lurker_kills() -> void:
	var lurker: Lurker = get_nodes_in_group("predator")[0]
	var died := [false]
	_player.died.connect(func(): died[0] = true)
	_player.set_physics_process(true)
	# An idle lurker is harmless: it has not telegraphed yet.
	var idle: Lurker = null
	for l in get_nodes_in_group("predator"):
		if l.state == Lurker.State.IDLE:
			idle = l
			break
	place(idle.global_position)
	await frames(3)
	check(not died[0], "touching an IDLE lurker does not kill (no telegraph yet)")
	lurker._enter(Lurker.State.HUNT)
	place(lurker.global_position)
	await frames(3)
	check(died[0] and _player.is_dead, "a HUNTING lurker kills on contact")
