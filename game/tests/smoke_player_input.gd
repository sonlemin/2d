extends Node
## Headless smoke test of the player's input (Story 1.8) on tests/rooms/input/t_input.txt.
## Movement group (D11, AC6): run speed, coyote time, jump buffer and air dash, pinned against the
## M1 input path before PlayerInput existed, and kept green after the switch.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_player_input.gd
## Frame math (measured on 4.7.2): a press made after an `await` is first seen by the player two
## ticks later, so its effect is read after `await frames(2)`. Reads after an `await` see the
## state of the last tick the player ran.

const RoomHarness := preload("res://tests/room_harness.gd")
const ROOM := &"t_input"
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"jump",
		&"attack", &"dash", &"light"]
## A cell of open air well away from every wall: drops and dashes start here.
const AIR_CELL := Vector2i(12, 3)
## A floor cell in the middle of the long floor (row 12 stands on row 13).
const FLOOR_CELL := Vector2i(12, 12)

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
	RoomLoader.add_root("res://tests/rooms/input")
	_build()
	await frames(2)
	await test_run_speed()
	await test_coyote_time()
	await test_jump_buffer()
	await test_air_dash()
	await test_light_windows()
	await test_light_latch_and_resume()
	await test_light_across_hitstop()
	await test_jump_in_hitstop()
	await test_attack_in_hitstop()
	await test_buffers_on_real_time()
	await test_attack_buffer()
	await test_interact()
	await test_cling_uses_the_press()
	await test_lock()
	test_sources()
	_release_all()
	Game.clock.clear()
	Game.reset_for_tests()
	RoomHarness.free_all(_parts)
	await frames(1)
	print("SMOKE %s" % ("PASS" if _fail == 0 else "FAILED (%d)" % _fail))


func _build() -> void:
	_parts = RoomHarness.build(self, ROOM)
	_room = _parts.room
	_player = _parts.player


## Teleport the player and snap the camera.
func place(pos: Vector2) -> void:
	_player.global_position = pos
	_player.velocity = Vector2.ZERO
	_player.reset_physics_interpolation()
	_parts.camera.snap()


func _release_all() -> void:
	for a in ACTIONS:
		Input.action_release(a)


## Where a body stands on the floor below `cell` (the same offset Room.entry_position() uses).
func _stand(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * Room.TILE + Room.TILE / 2.0, (cell.y + 1) * Room.TILE - 12)


## Stands the player still on the long floor and waits for it to settle.
func _settle_on_floor() -> void:
	_release_all()
	place(_stand(FLOOR_CELL))
	await frames(4)


## Waits until the player is on the floor, at most `limit` frames. Returns the frames waited.
func _wait_floor(limit := 120) -> int:
	for i in limit:
		if _player.is_on_floor():
			return i
		await frames(1)
	return limit


# --- Movement group (Task 1: written and green against the M1 input path) ---------------------

## FR1: run 110 px/s. Half a second of → from a standstill reaches top speed (900 px/s² takes
## 0.12 s), and the last 10 ticks cover 110 × 10/60 px.
func test_run_speed() -> void:
	await _settle_on_floor()
	place(_stand(Vector2i(3, 12)))
	await frames(2)
	Input.action_press("move_right")
	await seconds(0.5)
	var vx := _player.velocity.x
	var x0 := _player.global_position.x
	await frames(10)
	var dx := _player.global_position.x - x0
	Input.action_release("move_right")
	check(absf(vx - Game.tuning.f(&"run_speed")) < 0.01 and absf(vx - 110.0) < 0.01, "run reaches 110 px/s (got %.2f)" % vx)
	check(absf(dx - 110.0 * 10.0 / 60.0) < 0.5, "...and covers 18.3 px in 10 ticks (got %.2f)" % dx)
	await frames(10)


## Walks off the ledge's edge holding →, and presses Jump `ticks_after` ticks after the first tick
## off the ground. Returns the vertical velocity the press produced (negative = it jumped).
func _coyote_jump(ticks_after: int) -> float:
	_release_all()
	place(_room.entry_position(&"spawn"))
	await frames(4)
	Input.action_press("move_right")
	var left := false
	for i in 120:
		await frames(1)
		if not _player.is_on_floor():
			left = true
			break
	if not left:
		Input.action_release("move_right")
		return INF
	# Here the last tick run was the first off the ground; a press made now acts two ticks later.
	await frames(ticks_after - 2)
	Input.action_press("jump")
	await frames(2)
	var vy := _player.velocity.y
	Input.action_release("jump")
	Input.action_release("move_right")
	await _wait_floor()
	await frames(2)
	return vy


## FR1: coyote time 0.08 s. A press acted on 3 ticks (0.05 s) after leaving the ledge still
## jumps; one 8 ticks (0.13 s) after doesn't. Well inside and outside 0.08 s (4.8 ticks).
func test_coyote_time() -> void:
	var vy_in := await _coyote_jump(3)
	check(vy_in < -300.0, "Jump 3 ticks after leaving a ledge still jumps (coyote 0.08 s; vy %.1f)" % vy_in)
	var vy_out := await _coyote_jump(8)
	check(is_finite(vy_out) and vy_out >= 0.0, "Jump 8 ticks after leaving a ledge does not (vy %.1f)" % vy_out)


## Drops from AIR_CELL and presses (and holds) Jump `early` ticks before the landing tick measured
## by a dry drop. Returns the lowest vertical velocity seen in the ticks after landing.
func _buffered_drop(land_tick: int, early: int) -> float:
	_release_all()
	place(_room.cell_centre(AIR_CELL))
	await frames(land_tick - early)
	Input.action_press("jump")
	var lowest := INF
	for i in early + 6:
		await frames(1)
		lowest = minf(lowest, _player.velocity.y)
	Input.action_release("jump")
	await _wait_floor()
	await frames(2)
	return lowest


## FR1: jump buffer 0.10 s. A press made 3 ticks before the landing tick (seen 2 ticks, 0.03 s,
## before it) jumps on landing; one made 9 ticks before (seen 0.13 s before) is lost. Holding Jump in open air never clings (no wall within reach).
func test_jump_buffer() -> void:
	_release_all()
	place(_room.cell_centre(AIR_CELL))
	await frames(1)
	var land := await _wait_floor()
	check(land > 12 and land < 100, "a dry drop from the open air lands (after %d ticks)" % land)
	await frames(2)
	var vy_in := await _buffered_drop(land, 3)
	check(vy_in < -300.0, "Jump pressed 3 ticks before landing jumps on landing (buffer 0.10 s; vy %.1f)" % vy_in)
	var vy_out := await _buffered_drop(land, 9)
	check(vy_out > -1.0, "Jump pressed 9 ticks before landing is lost (vy %.1f)" % vy_out)


## FR2: air dash 260 px/s, horizontal, no gravity, once per airtime, refreshed by landing. FR2 says
## 0.12 s (31 px); M1's dash runs 8-9 ticks (≈ 39 px), pinned here as is (deferred to 1.15).
func test_air_dash() -> void:
	_release_all()
	place(_room.cell_centre(AIR_CELL))
	await frames(2)
	var facing: int = _player._facing
	Input.action_press("dash")
	await frames(1)
	Input.action_release("dash")
	var straight := 0  # ticks at exactly (260 × facing, 0): the dash ignoring gravity
	var dashing := 0  # ticks at 260 px/s sideways
	var prev := _player.global_position
	var dx := 0.0  # sideways distance covered on the dashing ticks only
	var dy := 0.0  # vertical distance covered on the straight ticks only
	for i in 16:
		await frames(1)
		var pos := _player.global_position
		if is_equal_approx(_player.velocity.x, 260.0 * facing):
			dashing += 1
			dx += absf(pos.x - prev.x)
			if _player.velocity.y == 0.0:
				straight += 1
				dy += absf(pos.y - prev.y)
		prev = pos
	# 0.12 s is 7.2 ticks; M1 checks the timer before counting it down, so the dash runs on the
	# start tick plus 8 more, the last of them already falling.
	check(straight >= 7 and straight <= 8, "air dash holds (260 × facing, 0) for 7-8 ticks, 0.12 s with no gravity (got %d)" % straight)
	check(dashing >= 8 and dashing <= 9, "...at 260 px/s sideways for 8-9 ticks (got %d)" % dashing)
	check(dx >= 31.0 and dx <= 40.0, "...covering at least 260 × 0.12 = 31 px (got %.1f)" % dx)
	check(dy < 0.01, "...with no vertical drift while it ignores gravity (got %.2f px)" % dy)
	Input.action_press("dash")
	await frames(1)
	Input.action_release("dash")
	await frames(2)
	check(not is_equal_approx(absf(_player.velocity.x), 260.0), "a second dash in the same airtime does nothing (vx %.1f)" % _player.velocity.x)
	await _wait_floor()
	await frames(2)
	Input.action_press("jump")
	await frames(12)
	Input.action_press("dash")
	await frames(2)
	Input.action_release("dash")
	check(is_equal_approx(absf(_player.velocity.x), 260.0), "after landing, the dash is back (vx %.1f)" % _player.velocity.x)
	Input.action_release("jump")
	await _wait_floor()
	await frames(2)


# --- Intent group (Task 5: PlayerInput) --------------------------------------------------------

## Drops the player from AIR_CELL with a chain of 5: about 50 ticks of air before it lands.
func _airborne_with_chain() -> void:
	_release_all()
	_player.chain.break_chain()
	place(_room.cell_centre(AIR_CELL))
	await frames(1)
	for i in 5:
		_player.chain.add_hit()


## Holds Light for `ticks` (the latency is the same for the press and the release, so the player
## sees it held for exactly that many ticks), then watches 5 more. Returns what was seen.
func _hold_light(ticks: int) -> Dictionary:
	await _airborne_with_chain()
	var seen := {taps = 0, snuff = false}
	Input.action_press("light")
	for i in ticks:
		await frames(1)
		seen.snuff = seen.snuff or _player.input.snuff_active
	Input.action_release("light")
	for i in 5:
		await frames(1)
		seen.snuff = seen.snuff or _player.input.snuff_active
		if _player.input.light_tap:
			seen.taps += 1
	seen.count = _player.chain.count
	await _wait_floor()
	await frames(2)
	return seen


## FR9, UX-DR119: a release inside the window is a tap (Flare Toss in 1.23) and never Snuffs;
## held past it is Snuff. Each window Snuffs on held tick ⌈w × 60⌉ (8, 12 and 18 ticks), so each
## is held for one tick short of that and for exactly that, plus 6 and 21 ticks (0.10 / 0.35 s).
func test_light_windows() -> void:
	var holds := {0.12: [6, 7, 8, 21], 0.2: [6, 11, 12, 21], 0.3: [6, 17, 18, 21]}
	for w: float in holds:
		Game.settings.set_value(&"light_tap_window", w)
		for i in holds[w].size():
			var ticks: int = holds[w][i]
			var tap := ticks < roundi(ceilf(w * 60.0 - 0.001))
			var seen := await _hold_light(ticks)
			if tap:
				check(seen.taps == 1 and not seen.snuff and seen.count == 5, "window %.2f s: a %d-tick press is one light_tap, never Snuff, chain kept (taps %d, snuff %s, chain %d)" % [w, ticks, seen.taps, seen.snuff, seen.count])
			else:
				check(seen.snuff and seen.taps == 0 and seen.count == 0, "window %.2f s: a %d-tick hold Snuffs and breaks the chain, no tap on release (taps %d, snuff %s, chain %d)" % [w, ticks, seen.taps, seen.snuff, seen.count])
	Game.settings.set_value(&"light_tap_window", 0.12)


## D4: a Snuff lasts until release. Raising the window mid-hold (Options, 1.36) never un-Snuffs
## it or turns the release into a tap; a release and re-press inside one tick (key chatter) keeps
## it; and Light held through a pause, where the press was never sampled, still Snuffs (as in M1).
func test_light_latch_and_resume() -> void:
	var input: PlayerInput = _player.input
	await _airborne_with_chain()
	Input.action_press("light")
	await frames(12)
	var snuffed := input.snuff_active
	Game.settings.set_value(&"light_tap_window", 0.3)
	var kept := true
	for i in 4:
		await frames(1)
		kept = kept and input.snuff_active
	Input.action_release("light")
	var taps := 0
	for i in 4:
		await frames(1)
		taps += int(input.light_tap)
	Game.settings.set_value(&"light_tap_window", 0.12)
	check(snuffed and kept and taps == 0, "a window raised to 0.3 s mid-Snuff keeps the Snuff, and the release is no tap (snuffed %s, kept %s, taps %d)" % [snuffed, kept, taps])
	await _airborne_with_chain()
	Input.action_press("light")
	await frames(12)
	Input.action_release("light")
	Input.action_press("light")  # released and pressed again inside one tick
	var steady := input.snuff_active
	for i in 6:
		await frames(1)
		steady = steady and input.snuff_active
	Input.action_release("light")
	check(steady, "Light released and pressed again inside one tick keeps the Snuff on every tick")
	await _wait_floor()
	await frames(2)
	await _airborne_with_chain()
	get_tree().paused = true
	Input.action_press("light")
	await frames(3)
	get_tree().paused = false
	var resumed := false
	for i in 12:
		await frames(1)
		resumed = resumed or input.snuff_active
	Input.action_release("light")
	check(resumed and _player.chain.count == 0, "Light pressed during a pause and held after it Snuffs (snuff %s, chain %d)" % [resumed, _player.chain.count])
	await _wait_floor()
	await frames(2)


## The Light timer counts real ticks, so a 75 ms hitstop (time scale 0.05) never stretches the
## window: Snuff comes on the 8th held tick, as without a hitstop. M1's scaled timer took ~12.
func test_light_across_hitstop() -> void:
	await _airborne_with_chain()
	Input.action_press("light")
	Game.clock.request(&"hitstop", 0.05, 0.075)
	var first_down := -1
	var first_snuff := -1
	var in_hitstop := false
	for i in 16:
		await frames(1)
		if first_down < 0 and _player.input.snuff_active == false and _player.input._light_down:
			first_down = i
			in_hitstop = Game.clock.is_active(&"hitstop")
		if first_snuff < 0 and _player.input.snuff_active:
			first_snuff = i
	Input.action_release("light")
	check(in_hitstop, "the Light press was first seen during the hitstop")
	check(first_down >= 0 and first_snuff - first_down == 7, "held across a 75 ms hitstop, Light Snuffs on its 8th held tick, on real time (down at %d, Snuff at %d)" % [first_down, first_snuff])
	await frames(3)
	# A tap released inside the hitstop is still a tap. 0.15 s, so the release (seen on tick 4)
	# is well inside it.
	_player.chain.break_chain()
	for i in 5:
		_player.chain.add_hit()
	Input.action_press("light")
	Game.clock.request(&"hitstop", 0.05, 0.15)
	await frames(2)
	Input.action_release("light")
	var taps := 0
	var snuff := false
	var tap_in_hitstop := false
	for i in 5:
		await frames(1)
		if _player.input.light_tap:
			taps += 1
			tap_in_hitstop = Game.clock.is_active(&"hitstop")
		snuff = snuff or _player.input.snuff_active
	check(taps == 1 and tap_in_hitstop and not snuff and _player.chain.count == 5, "a Light tap released inside a hitstop is one light_tap and keeps the chain (taps %d, in hitstop %s, chain %d)" % [taps, tap_in_hitstop, _player.chain.count])
	Game.clock.clear()
	await _wait_floor()
	await frames(2)


## NFR2: Jump pressed during a hitstop is acted on; ticks keep running under the time scale.
func test_jump_in_hitstop() -> void:
	await _settle_on_floor()
	Game.clock.request(&"hitstop", 0.05, 0.075)
	Input.action_press("jump")
	var jumped_in := false
	for i in 6:
		await frames(1)
		if _player.velocity.y < -300.0:
			jumped_in = Game.clock.is_active(&"hitstop")
			break
	Input.action_release("jump")
	check(jumped_in, "Jump pressed during a 75 ms hitstop jumps, inside the hitstop")
	Game.clock.clear()
	await _wait_floor()
	await frames(2)


## NFR2: an Attack tapped inside one tick of a hitstop starts a swing.
func test_attack_in_hitstop() -> void:
	_release_all()
	place(_room.cell_centre(AIR_CELL))
	await frames(16)  # past any earlier swing's 0.22 s cooldown
	Game.clock.request(&"hitstop", 0.05, 0.075)
	Input.action_press("attack")
	await frames(1)
	Input.action_release("attack")
	var swung := false
	for i in 5:
		await frames(1)
		swung = swung or _player._swing_left > 0.0
	check(swung, "Attack tapped during a hitstop starts a swing")
	Game.clock.clear()
	await _wait_floor()
	await frames(2)


## Counts the ticks `intent` reads true after `action` is tapped, watching `n` ticks.
func _buffered_ticks(action: StringName, intent: StringName, n: int) -> int:
	Input.action_press(action)
	await frames(1)
	Input.action_release(action)
	var live := 0
	for i in n:
		await frames(1)
		live += int(_player.input.get(intent))
	return live


## D3: the Jump and Attack buffers count real ticks, so a hitstop never stretches them: blocked
## in a long hitstop (Jump in the air with no coyote, Attack during the cooldown), each press
## waits its 0.10 s, 7 ticks as M1 counted it, then is gone. A scaled timer would wait ~20× longer.
## Also pins sonlm's 2026-11-18 call: an Attack in a pogo-length (75 ms) hitstop right after a
## swing is lost, as in M1, because the cooldown runs on game time.
func test_buffers_on_real_time() -> void:
	_release_all()
	place(_room.cell_centre(AIR_CELL))
	await frames(12)  # coyote spent, any earlier cooldown over
	Game.clock.request(&"hitstop", 0.05, 0.5)
	var jump_live := await _buffered_ticks(&"jump", &"jump_pressed", 20)
	check(Game.clock.is_active(&"hitstop") and jump_live == 7, "a blocked Jump pressed in a 0.5 s hitstop waits 7 real ticks (got %d)" % jump_live)
	Game.clock.clear()
	await frames(2)
	Input.action_press("attack")
	await frames(1)
	Input.action_release("attack")
	await frames(2)
	var cd := _player._swing_cd
	Game.clock.request(&"hitstop", 0.05, 0.5)
	var attack_live := await _buffered_ticks(&"attack", &"attack_pressed", 20)
	check(cd > 0.1 and Game.clock.is_active(&"hitstop") and attack_live == 7, "an Attack pressed during the cooldown in a 0.5 s hitstop waits 7 real ticks (cd %.2f, got %d)" % [cd, attack_live])
	Game.clock.clear()
	await _wait_floor()
	await frames(2)
	place(_room.cell_centre(AIR_CELL))
	await frames(16)
	Input.action_press("attack")
	await frames(1)
	Input.action_release("attack")
	await frames(2)
	cd = _player._swing_cd
	Game.clock.request(&"hitstop", 0.05, 0.075)
	Input.action_press("attack")
	await frames(1)
	Input.action_release("attack")
	var again := false
	for i in 30:
		await frames(1)
		if _player._swing_cd > cd + 0.001:
			again = true
		cd = _player._swing_cd
	check(not again, "an Attack pressed in a 75 ms hitstop right after a swing is lost, as in M1 (sonlm, 2026-11-18)")
	await _wait_floor()
	await frames(2)


## D9: an Attack pressed while the cooldown runs waits ATTACK_BUFFER (0.10 s, 7 ticks as counted) of real
## time. Pressed so it is seen 3 ticks before the cooldown ends, it swings at the end; seen 11
## ticks before (0.18 s), it has expired. M1 dropped both.
func _second_swing(press_at: int) -> bool:
	_release_all()
	place(_room.cell_centre(AIR_CELL))
	await frames(16)
	Input.action_press("attack")
	await frames(1)
	Input.action_release("attack")
	for i in 6:  # until the first swing has started
		await frames(1)
		if _player._swing_left > 0.0:
			break
	var cd := _player._swing_cd
	var again := false
	for i in 24:
		if i == press_at:
			Input.action_press("attack")
		if i == press_at + 1:
			Input.action_release("attack")
		await frames(1)
		if _player._swing_cd > cd + 0.001:
			again = true
		cd = _player._swing_cd
	await _wait_floor()
	await frames(2)
	return again


func test_attack_buffer() -> void:
	var late := await _second_swing(9)
	check(late, "Attack pressed 3 ticks before the cooldown ends swings when it ends (buffer 0.10 s)")
	var early := await _second_swing(1)
	check(not early, "Attack pressed 0.18 s before the cooldown ends has expired: no second swing")


## Counts the interact intents seen over `n` ticks.
func _interacts(n := 4) -> int:
	var got := 0
	for i in n:
		await frames(1)
		got += int(_player.input.interact)
	return got


## FR26, UX-DR118: ↓ standing still on the ground fires interact once; sideways input at or above
## the 0.2 deadzone, the air or a wall never; 0.6 fires and only a drop below 0.3 re-arms.
func test_interact() -> void:
	await _settle_on_floor()
	Input.action_press("move_down")
	check(await _interacts() == 1, "↓ standing still on the ground: interact fires exactly once")
	Input.action_release("move_down")
	await frames(3)
	Input.action_press("move_right")
	await frames(2)
	Input.action_press("move_down")
	check(await _interacts() == 0, "↓ while moving sideways: no interact")
	await _settle_on_floor()
	Input.action_press("move_right", 0.15)
	Input.action_press("move_down")
	check(await _interacts() == 1, "↓ with sideways tilt 0.15, under the 0.2 deadzone: interact fires")
	await _settle_on_floor()
	Input.action_press("move_down", 0.5)
	check(await _interacts() == 0, "↓ at 0.5 tilt: no interact")
	Input.action_press("move_down", 0.6)
	check(await _interacts() == 1, "...pushed on to 0.6 it fires")
	Input.action_press("move_down", 0.4)
	await frames(3)
	Input.action_press("move_down", 0.7)
	check(await _interacts() == 0, "back to 0.4 and up to 0.7 again: not re-armed, no interact")
	Input.action_press("move_down", 0.2)
	await frames(3)
	Input.action_press("move_down", 0.7)
	check(await _interacts() == 1, "down to 0.2 re-arms: 0.7 fires again")
	_release_all()
	place(_room.cell_centre(AIR_CELL))
	await frames(3)
	Input.action_press("move_down")
	check(await _interacts() == 0, "↓ in the air: no interact")
	_release_all()
	await _wait_floor()
	await frames(2)
	# ↓ on a wall drops off it (FR7) and is never an interact.
	var at_wall := Vector2((Room.TILE * 21) - 6.0, _room.cell_centre(AIR_CELL).y)
	place(at_wall)
	await frames(2)
	Input.action_press("jump")
	await frames(4)
	check(_player._clinging, "holding Jump at the right wall while falling clings")
	Input.action_press("move_down")
	var got := await _interacts(4)
	check(not _player._clinging and got == 0, "↓ on the wall drops off it, with no interact (clinging %s, interacts %d)" % [_player._clinging, got])
	_release_all()
	await _wait_floor()
	await frames(2)
	# ↑ is Jump too: clinging on ↑ (jump + move_up) and pressing ↓ still drops, as in M1.
	place(at_wall)
	await frames(2)
	Input.action_press("jump")
	Input.action_press("move_up")
	await frames(4)
	var clung := _player._clinging
	Input.action_press("move_down")
	await frames(3)
	check(clung and not _player._clinging, "clinging on ↑ and pressing ↓ drops off the wall (clung %s, clinging %s)" % [clung, _player._clinging])
	_release_all()
	await _wait_floor()
	await frames(2)


## The Jump press that starts a cling is used by it, as in M1 (where it was never buffered): it
## is not left waiting to turn the kick into a coyote jump.
func test_cling_uses_the_press() -> void:
	_release_all()
	place(Vector2((Room.TILE * 21) - 6.0, _room.cell_centre(AIR_CELL).y))
	await frames(6)  # falling, coyote spent
	Input.action_press("jump")
	var waiting := false
	var clung := 0
	for i in 10:
		await frames(1)
		if _player._clinging:
			clung += 1
			waiting = waiting or _player.input.jump_pressed
	check(clung >= 8 and not waiting, "a Jump press that starts a cling is consumed by it, never left waiting (clinging ticks %d, waiting %s)" % [clung, waiting])
	_release_all()
	await _wait_floor()
	await frames(2)


## AR34, D7: lock() turns every intent off and clears what was waiting; after unlock() held keys
## count again, but a press or a Light hold needs a fresh press.
func test_lock() -> void:
	var input: PlayerInput = _player.input
	_release_all()
	place(_room.cell_centre(AIR_CELL))
	await frames(1)
	# Sampled first, in the air: → held, Light held into a Snuff, a Jump press waiting in its buffer.
	Input.action_press("move_right")
	Input.action_press("light")
	await frames(12)
	Input.action_press("jump")
	await frames(2)
	var before := input.move.x > 0.9 and input.snuff_active and input.jump_held
	input.lock()
	await frames(1)
	var all_off := (input.move == Vector2.ZERO and not input.jump_held and not input.jump_released
			and not input.dash_held and not input.cling_held and not input.down_held and not input.snuff_active
			and not input.jump_pressed and not input.attack_pressed and not input.dash_pressed
			and not input.light_tap and not input.interact)
	check(before and input.is_locked() and all_off,
			"lock() turns every intent off, including what was sampled: move, Jump held and waiting, the Snuff (before %s; move %s, held %s, waiting %s, snuff %s)" % [before, input.move, input.jump_held, input.jump_pressed, input.snuff_active])
	await _wait_floor()
	var jumped := false
	for i in 6:
		await frames(1)
		jumped = jumped or _player.velocity.y < -1.0
	check(not jumped and not _player.chain.snuffed, "locked: landing with Jump held and buffered does not jump, and the light is back (jumped %s, snuffed %s)" % [jumped, _player.chain.snuffed])
	Input.action_release("jump")
	Input.action_release("light")
	Input.action_press("attack")
	await frames(1)
	Input.action_release("attack")
	await frames(2)
	input.unlock()
	var swung := false
	var moved := false
	for i in 6:
		await frames(1)
		swung = swung or _player._swing_left > 0.0
		moved = moved or input.move.x > 0.9
	check(not swung, "an Attack pressed during the lock is not acted on after unlock()")
	check(moved and not input.is_locked(), "after unlock(), the held → reads again (move %s)" % input.move)
	await _settle_on_floor()
	# A Light press the machine has already seen, released while locked: no tap after unlock.
	Input.action_press("light")
	await frames(3)
	var timing := input._light_down
	input.lock()
	Input.action_release("light")
	await frames(3)
	input.unlock()
	var late_taps := 0
	for i in 5:
		await frames(1)
		late_taps += int(input.light_tap)
	check(timing and late_taps == 0, "a Light press released while locked gives no light_tap after unlock() (timing %s, taps %d)" % [timing, late_taps])
	# Held through lock and unlock (seen before the lock): never Snuffs until a fresh press.
	Input.action_press("light")
	await frames(3)
	input.lock()
	await frames(3)
	input.unlock()
	var snuffed := false
	for i in 20:
		await frames(1)
		snuffed = snuffed or input.snuff_active
	check(not snuffed, "a Light held through lock and unlock never Snuffs on its own")
	Input.action_release("light")
	await frames(3)
	Input.action_press("light")
	for i in 14:
		await frames(1)
		snuffed = snuffed or input.snuff_active
	Input.action_release("light")
	check(snuffed, "...a fresh hold after unlock() Snuffs again")
	await _settle_on_floor()


## AC1: M1's Snuff hold is gone and the scene carries the sampler. "No Input. outside PlayerInput"
## is test_lint's raw_input rule since Story 1.9 (wider: InputEvent, the _input callbacks).
func test_sources() -> void:
	var player_src := FileAccess.get_file_as_string("res://scripts/actors/player.gd")
	check(not player_src.contains("SNUFF_HOLD") and not player_src.contains("_light_held"), "player.gd has no SNUFF_HOLD or _light_held left")
	var p: Player = load("res://scenes/actors/player.tscn").instantiate()
	var node := p.get_node_or_null("PlayerInput")
	check(node is PlayerInput, "player.tscn has a PlayerInput child (got %s)" % node)
	p.queue_free()

