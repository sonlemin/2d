extends Node
## The M1 move checks on the real shaft (Story 1.10 D1, from smoke_shaft.gd): pogo builds the chain,
## landing breaks it, the jump's height, wall cling, and releasing Light ends a Snuff. These are
## move checks, not room guarantees (smoke_rooms and smoke_bot hold those), and they need m1_shaft's
## hoverers. Targets come from sorted positions and the room API, never row literals.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_moves.gd

const RoomHarness := preload("res://tests/room_harness.gd")
## By path, as smoke_rooms builds: a duplicate room id is smoke_rooms' named FAIL, never an index
## push_error here.
const M1_SHAFT := "res://rooms/l1/m1_shaft.txt"

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
	_parts = RoomHarness.build_from_path(self, M1_SHAFT)
	_room = _parts.room
	_player = _parts.player
	for n in _room.get_children():
		if n is Lurker:
			n.set_physics_process(false)  # move checks: no lurker may notice the chain-light
	await frames(2)
	await test_pogo_builds_chain()
	await test_landing_breaks_chain()
	await test_jump_height()
	await test_wall_cling()
	await test_snuff_release()
	RoomHarness.free_all(_parts)
	print("SMOKE %s" % ("PASS" if _fail == 0 else "FAILED (%d)" % _fail))


## Teleport the player and snap the camera.
func place(pos: Vector2) -> void:
	_player.global_position = pos
	_player.velocity = Vector2.ZERO
	_parts.camera.snap()


## This room's hoverers sorted by height (row, then column), never by group order.
func _hovers() -> Array[Crawler]:
	var out: Array[Crawler] = []
	for n in _room.get_children():
		if n is Crawler and n.hover:
			out.append(n)
	out.sort_custom(func(a: Crawler, b: Crawler) -> bool:
		return a.position.y < b.position.y or (a.position.y == b.position.y and a.position.x < b.position.x))
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
	check(_player.chain.count >= 2, "setup: a chain of %d before the landing" % _player.chain.count)
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


## Wall cling: hold Jump at a wall while falling -> chain paused + hidden; grace ends -> banks;
## releasing Jump kicks you away from the wall. The row is _hovers()[2]'s: sorted by row then column
## with two hoverers a row, that is the first hoverer of the second hoverer row (row 16).
func test_wall_cling() -> void:
	var y: float = _hovers()[2].global_position.y
	var row := int(y / Room.TILE)
	check(_room.is_solid(Vector2i(0, row)) and not _room.is_solid(Vector2i(1, row)), "row %d: the left wall is 1 tile, open beside it" % row)
	place(Vector2(Room.TILE + 5.5, y))  # body (10 px wide) touching the 1-tile left wall, mid-air
	_player._cling_left = Game.tuning.f(&"cling_grace")
	for i in 6:
		_player.chain.add_hit()
	var held: int = _player.chain.held
	var banked := [0]
	var on_bank := func(amount: int) -> void: banked[0] += amount
	_player.chain.banked.connect(on_bank)
	Input.action_press("move_left")
	await frames(2)
	Input.action_release("move_left")
	Input.action_press("jump")
	await seconds(0.4)
	check(_player._clinging, "holding Jump at a wall while falling clings")
	check(_player.chain.count == 6 and _player.chain.held == held, "cling keeps the chain (got %d)" % _player.chain.count)
	check(is_equal_approx(_player.light_radius(), ChainState.BASE_RADIUS), "cling hides the chain-light")
	await seconds(0.8)
	check(_player.chain.count == 0 and _player.chain.held == 0 and held > 0 and banked[0] == held,
			"grace runs out -> the chain breaks and banks its %d held embers, never loses them (banked %d)" % [held, banked[0]])
	_player.chain.banked.disconnect(on_bank)
	Input.action_release("jump")
	await frames(2)
	check(not _player._clinging and _player.velocity.x > 0.0, "releasing Jump kicks off the wall")
	await seconds(0.3)


## From smoke_shaft's test_snuff_needs_hold: smoke_player_input covers "a tap keeps the chain" and
## "a hold Snuffs and breaks it" at every window (D1), but not that the Snuff ends on release.
func test_snuff_release() -> void:
	place(_hovers()[0].global_position + Vector2(40, -60))
	await frames(1)
	for i in 5:
		_player.chain.add_hit()
	Input.action_press("light")
	await frames(18)  # 0.3 s: past the default 0.12 s tap window
	check(_player.chain.snuffed and _player.chain.count == 0, "setup: holding Light Snuffs and breaks the chain")
	await frames(2)
	check(_player.chain.snuffed, "control: still holding Light, the Snuff holds")
	Input.action_release("light")
	await frames(2)  # a release after an await is first seen within two ticks (Story 1.8 frame math)
	check(not _player.chain.snuffed, "releasing Light ends the Snuff")
