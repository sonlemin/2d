extends Node
## The accessibility gate on the real shaft (Story 1.16): screen shake off means the camera never
## shakes while the pogo's freeze frame and sparks stay (FR38, UX-DR128, D7), and reduce flashing
## turns the invulnerability blink into steady transparency (UX-DR126, D4). Each case runs at the
## default too, so a check can't pass on an effect that never plays.
## The harness has no World, so the pogo → kick wire is made here, as world.gd makes it.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_a11y.gd

const RoomHarness := preload("res://tests/room_harness.gd")

var _fail := 0
var _parts: Dictionary
var _room: Room
var _player: Player
var _camera: CameraRig


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func run() -> void:
	Game.reset_for_tests()
	_parts = RoomHarness.build(self, &"m1_shaft")
	_room = _parts.room
	_player = _parts.player
	_camera = _parts.camera
	_player.pogo_hit.connect(_camera.kick.bind(CameraRig.POGO_SHAKE))  # as world.gd wires it
	for n in _room.get_children():
		if n is Lurker:
			n.set_physics_process(false)  # no lurker may notice the chain-light here
	await frames(2)
	await test_pogo_shake_on()
	await test_pogo_shake_off()
	await test_shake_off_mid_shake()
	await test_blink_default()
	await test_blink_reduced()
	RoomHarness.free_all(_parts)
	Game.reset_for_tests()
	print("SMOKE %s" % ("PASS" if _fail == 0 else "FAILED (%d)" % _fail))


func place(pos: Vector2) -> void:
	_player.global_position = pos
	_player.velocity = Vector2.ZERO
	_player.reset_physics_interpolation()
	_camera.snap()


## Live crawlers of one kind, sorted by row then column, never by group order.
func _crawlers(hover: bool) -> Array[Crawler]:
	var out: Array[Crawler] = []
	for n in _room.get_children():
		if n is Crawler and n.hover == hover and not n.is_queued_for_deletion():
			out.append(n)
	out.sort_custom(func(a: Crawler, b: Crawler) -> bool:
		return a.position.y < b.position.y or (a.position.y == b.position.y and a.position.x < b.position.x))
	return out


func _sparks() -> int:
	return _room.get_children().filter(func(n: Node) -> bool: return n is CPUParticles2D and not n.is_queued_for_deletion()).size()


## A real pogo on the highest hoverer (as smoke_moves does). Returns true on the hit frame, with
## the sparks counted and the hitstop seen on that frame.
func _pogo() -> Dictionary:
	var hovers := _crawlers(true)
	if hovers.is_empty():
		return {hit = false}
	var target := hovers[0]
	await frames(30)  # the last swing's cooldown (game time) has run out
	place(target.global_position + Vector2(0, -40))
	var sparks_before := _sparks()
	var hits := [0]
	var on_hit := func() -> void: hits[0] += 1
	_player.pogo_hit.connect(on_hit)
	var pressed := false
	var out := {hit = false}
	for i in 60:
		if not pressed and is_instance_valid(target) and target.global_position.y - _player.global_position.y < 26:
			Input.action_press("attack")
			await frames(1)
			Input.action_release("attack")
			pressed = true
		if hits[0] > 0:
			out = {hit = true, sparks = _sparks() - sparks_before, hitstop = Game.clock.is_active(&"hitstop"), offset = _camera.offset}
			break
		await frames(1)
	_player.pogo_hit.disconnect(on_hit)
	return out


func test_pogo_shake_on() -> void:
	Game.reset_for_tests()
	var got := await _pogo()
	check(got.hit, "setup: a pogo hit on the highest hoverer (shake on)")
	check(got.hitstop, "...with its freeze frame (Clock hitstop active on the hit)")
	# The real pogo, hitstop included: the rig used to read delta / time_scale on the hit tick, after
	# the hitstop request, and killed the shake at once (Story 1.16, probed on 4.7.2).
	var moved := 0
	for i in 6:
		await frames(1)
		if _camera.offset != Vector2.ZERO:
			moved += 1
	check(moved >= 4, "shake on (default): a pogo hit with its hitstop shakes the camera for several ticks (AC8; %d of 6)" % moved)


## FR38: shake off, the camera stays still and the pogo still freezes and sparks.
func test_pogo_shake_off() -> void:
	Game.settings.set_value(&"shake", false)
	var got := await _pogo()
	check(got.hit, "setup: a pogo hit on the next hoverer (shake off)")
	if not got.hit:
		return
	check(got.hitstop, "shake off: the pogo's freeze frame still plays (Clock hitstop active on the hit)")
	check(got.sparks >= 1, "...and its sparks appear under the room (%d)" % got.sparks)
	var still := true
	for i in 30:
		still = still and _camera.offset == Vector2.ZERO
		await frames(1)
	check(still, "...and the camera offset stays zero for 30 ticks (UX-DR128)")
	_camera.kick(6.0)
	check(_camera.get("_shake") == 0.0, "...and a direct kick() stores no shake (D7: refused at the door, not only zeroed each tick)")
	await frames(2)
	check(_camera.offset == Vector2.ZERO, "...nor moves the camera")
	Game.reset_for_tests()


## D7: turning shake off while a shake runs leaves no offset frozen on screen.
func test_shake_off_mid_shake() -> void:
	Game.reset_for_tests()
	place(_room.entry_position(&"spawn"))
	_camera.kick(6.0)
	await frames(2)
	check(_camera.offset != Vector2.ZERO, "setup: a 6 px kick shakes the camera (offset %s)" % _camera.offset)
	var steady := _camera.play_rect()
	Game.settings.set_value(&"shake", false)
	await frames(1)
	check(_camera.offset == Vector2.ZERO, "turning shake off mid-shake zeroes the offset the next tick (got %s)" % _camera.offset)
	check(_camera.play_rect().is_equal_approx(steady), "...and play_rect() never read the shake")
	Game.reset_for_tests()


## A real crawler contact on the lowest walker; samples the sprite every tick of the
## invulnerability that follows. Returns {knocked, alphas, visible}.
func _knock() -> Dictionary:
	var walkers := _crawlers(false)
	if walkers.is_empty():
		return {knocked = false}
	var w := walkers[walkers.size() - 1]
	var sprite := _player.get_node("Sprite") as Sprite2D
	place(w.global_position + Vector2(-4, -2))
	var knocked := false
	for i in 20:
		await frames(1)
		if _player.get("_invuln") > 0.0:
			knocked = true
			break
	if not knocked:
		return {knocked = false}
	var alphas := {}
	var always_visible := true
	var ticks := 0
	while _player.get("_invuln") > 0.0 and ticks < 120:
		alphas[sprite.modulate.a] = true
		always_visible = always_visible and sprite.visible
		ticks += 1
		await frames(1)
	return {knocked = true, alphas = alphas.keys(), visible = always_visible, ticks = ticks, after = sprite.modulate.a}


func test_blink_default() -> void:
	Game.reset_for_tests()
	var got := await _knock()
	check(got.knocked, "setup: a crawler contact knocks the player (default)")
	if got.knocked:
		check(0.0 in got.alphas and 1.0 in got.alphas, "default: the invulnerability blinks between 0 and 1 (AC8; got %s over %d ticks)" % [got.alphas, got.ticks])


func test_blink_reduced() -> void:
	Game.reset_for_tests()
	await frames(5)
	Game.settings.set_value(&"reduce_flashing", true)
	var got := await _knock()
	check(got.knocked, "setup: a crawler contact knocks the player (reduce flashing)")
	if got.knocked:
		check(got.alphas == [Fx.STEADY_ALPHA] and got.ticks >= 30, "reduce flashing: steady transparency (%s) for the whole invulnerability (got %s over %d ticks)" % [Fx.STEADY_ALPHA, got.alphas, got.ticks])
		check(got.visible, "...and the player stays visible throughout (UX-DR126)")
		check(got.after == 1.0, "...and fully drawn once it ends (got %s)" % got.after)
	Game.reset_for_tests()
