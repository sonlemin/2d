extends Node
## The perf kit in a real World (Story 1.12 D12): `--room=perf_worst --perf=3` holds chain 20 on its
## path with the light budget applied on every tick (never more than Spec.LIGHTS_ON_SCREEN_MAX lit,
## the player's light and the flare never demoted), then freezes one summary, logs it once and shows
## it in overlay 4; the plain room, --glow, bad --perf values, the view rect, and m1_shaft unchanged.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_perf.gd
## As smoke_dev_tools: tokens reach DevTools through World's child_entered_tree (1.11 D3); one World
## at a time; each case ends in _teardown(). Samples are taken on get_tree().physics_frame, which
## fires before the next tick's physics, so they see what was drawn: every actor moved and
## LightBudget applied.

const WorldScene := preload("res://scenes/world/world.tscn")
const Spec := preload("res://tests/spec.gd")
const PerfRun := preload("res://scripts/dev/perf_run.gd")
const TMP := "user://smoke_perf_tmp"
const PERF_CAP_MS := 6000  ## the 3 s run must finish well inside this

var _fail := 0
var _tokens := PackedStringArray()
var _world: World
var _spawned: Array[Player] = []
var _warnings := Warnings.new()


## Collects DevTools' push_warning texts and the `[room] dev: perf` log lines.
class Warnings extends Logger:
	var _lock := Mutex.new()
	var _got: Array[String] = []
	var _perf_lines: Array[String] = []

	func _log_error(_function: String, _file: String, _line: int, code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING or not code.begins_with("DevTools:"):
			return
		_lock.lock()
		_got.append(code)
		_lock.unlock()

	func _log_message(message: String, _error: bool) -> void:
		if not message.begins_with("[room] dev: perf "):
			return
		_lock.lock()
		_perf_lines.append(message.trim_suffix("\n"))  # only the newline: headless, the line ends "Linux, " (no adapter name)
		_lock.unlock()

	func take() -> Array[String]:
		_lock.lock()
		var out := _got.duplicate()
		_got.clear()
		_lock.unlock()
		return out

	func take_perf_lines() -> Array[String]:
		_lock.lock()
		var out := _perf_lines.duplicate()
		_perf_lines.clear()
		_lock.unlock()
		return out


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func run() -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	OS.add_logger(_warnings)
	await test_perf_run()
	await test_held_chain()
	await test_death_mid_run()
	await test_breaks()
	await test_blocked_path()
	await test_room_alone()
	await test_glow()
	await test_bad_perf()
	await test_m1_shaft()
	OS.remove_logger(_warnings)
	DirAccess.remove_absolute(TMP.path_join("settings.json"))
	DirAccess.remove_absolute(TMP)
	print("SMOKE %s" % ("PASS" if _fail == 0 else "FAILED (%d)" % _fail))


# --- Building and tearing down ----------------------------------------------------------------------

func _build(tokens: Array) -> void:
	Game.store.dir = TMP
	_tokens = PackedStringArray(tokens)
	_spawned.clear()
	_world = WorldScene.instantiate()
	_world.child_entered_tree.connect(_on_world_child)
	_world.player_spawned.connect(_on_spawned)
	add_child(_world)


## A method, not a lambda (1.11 D3).
func _on_world_child(node: Node) -> void:
	if node is DevTools:
		node.tokens = _tokens


func _on_spawned(player: Player) -> void:
	_spawned.append(player)


func _teardown() -> void:
	get_tree().paused = false
	if is_instance_valid(_world):
		_world.queue_free()
	_world = null
	await get_tree().process_frame
	await get_tree().process_frame
	Game.reset_for_tests()
	Log.set_enabled([])


func _dev() -> DevTools:
	return _world.get_node_or_null("DevTools") as DevTools


func _lights() -> Array[Node]:
	return get_tree().get_nodes_in_group(BudgetLight.GROUP)


func _counts() -> Dictionary:
	return BudgetLight.counts(_lights(), _world.light_rect())


## Screen 1's lurkers: the four in the top 270 px of perf_worst.
func _screen1_glows() -> Array[BudgetLight]:
	var out: Array[BudgetLight] = []
	for n in _lights():
		var l := n as BudgetLight
		if l.get_parent() is Lurker and l.global_position.y < 270.0:
			out.append(l)
	return out


# --- Cases --------------------------------------------------------------------------------------

## AC1, AC3, AC7: the run, tick by tick.
func test_perf_run() -> void:
	_warnings.take_perf_lines()
	_build(["--room=perf_worst", "--perf=3"])
	var dev := _dev()
	var room := _world.current_room()
	var p: Player = _spawned[0] if _spawned.size() == 1 else null
	var perf: Node = dev.perf if dev != null else null
	check(room != null and room.id == &"perf_worst" and p != null and perf != null,
			"(premise) --room=perf_worst --perf=3 builds perf_worst, a player and a PerfRun (room %s, perf %s)" % [room.id if room else &"none", perf])
	if room == null or p == null or perf == null:
		await _teardown()
		return
	var hurtbox := p.get_node_or_null(^"Hurtbox") as Area2D
	check(p.input.is_locked() and hurtbox != null and hurtbox.collision_mask == 0,
			"(premise) the run took the player: input locked, Hurtbox mask 0 (got locked %s, mask %s)" % [p.input.is_locked(), hurtbox.collision_mask if hurtbox else -1])
	check(perf.stand_ins.size() == 2 and perf.stand_ins[0].rank == BudgetLight.Rank.ALWAYS and perf.stand_ins[1].rank == BudgetLight.Rank.CACHE,
			"two stand-ins ride along: a flare of rank ALWAYS, then a cache of rank CACHE")
	check(perf.stand_ins.all(func(l: BudgetLight) -> bool: return l.get_parent() == room), "...both children of the current room (AR23: the room owns them)")
	var player_light := p.get_node(^"Light") as BudgetLight
	var flare: BudgetLight = perf.stand_ins[0]
	var to_twenty := -1
	for i in 10:
		await get_tree().physics_frame
		if p.chain.count == ChainState.MAX_CHAIN:
			to_twenty = i
			break
	check(to_twenty >= 0, "(premise) within 10 ticks the chain is 20 (paid at take-off; tick %d)" % to_twenty)
	# Every tick until done: the chain held, alive, on the centre line, the budget held, the
	# always-lights never demoted. Counted, then reported once per property.
	var start_ms := Time.get_ticks_msec()
	var ticks := 0
	var bad := {chain = 0, dead = 0, x = 0, lit = 0, always = 0}
	var worst_lit := 0
	var first_wake_lit := -1
	var exercised := false
	var sprites_not_glow := 0
	var y_first := 0.0
	var y_after_60 := 0.0
	while not perf.done and Time.get_ticks_msec() - start_ms < PERF_CAP_MS:
		await get_tree().physics_frame
		if not is_instance_valid(p) or not is_instance_valid(flare):
			break
		ticks += 1
		if ticks == 1:
			y_first = p.global_position.y
		elif ticks == 61:
			y_after_60 = p.global_position.y
		var c := _counts()
		worst_lit = maxi(worst_lit, c.lit)
		bad.chain += int(p.chain.count != ChainState.MAX_CHAIN)
		bad.dead += int(p.is_dead)
		bad.x += int(p.global_position.x != 240.0)
		bad.lit += int(c.lit > Spec.LIGHTS_ON_SCREEN_MAX)
		bad.always += int(player_light.demoted or flare.demoted)
		if first_wake_lit < 0 and _screen1_glows().any(func(l: BudgetLight) -> bool: return l.wants_light()):
			first_wake_lit = c.lit
		if c.sprites >= 1:
			exercised = true
			for n in _lights():
				var l := n as BudgetLight
				if l.demoted and l.wants_light() and l.rank != BudgetLight.Rank.GLOW:
					sprites_not_glow += 1
	check(perf.done, "(premise) the 3 s run finished within %d ms (%d ticks)" % [PERF_CAP_MS, ticks])
	check(bad.chain == 0, "on every tick the chain is 20 (%d ticks off)" % bad.chain)
	check(bad.dead == 0, "...the player is never dead (%d ticks)" % bad.dead)
	check(bad.x == 0, "...it stays on the centre line, x 240 (%d ticks off)" % bad.x)
	check(bad.lit == 0, "...at most %d lights are lit in the view (%d ticks over; worst %d)" % [Spec.LIGHTS_ON_SCREEN_MAX, bad.lit, worst_lit])
	check(bad.always == 0, "...and the player's light and the flare are never demoted (%d ticks)" % bad.always)
	check(first_wake_lit >= 0 and first_wake_lit <= Spec.LIGHTS_ON_SCREEN_MAX,
			"(premise for D5) at the tick screen 1's glows first wake, the sample already shows ≤ %d lit (got %d): the budget ran after the actors" % [Spec.LIGHTS_ON_SCREEN_MAX, first_wake_lit])
	check(exercised and sprites_not_glow == 0, "(premise) the budget was exercised: some tick showed a sprite glow, and every demoted light was a GLOW (%d not)" % sprites_not_glow)
	check(absf(y_after_60 - y_first - PerfRun.PATH_SPEED) <= 4.0, "60 ticks in, the player has moved %.1f px down the path (%.0f px/s, ± 4)" % [y_after_60 - y_first, PerfRun.PATH_SPEED])
	if is_instance_valid(flare):
		check(absf(flare.texture_scale * flare.texture.get_width() / 2.0 - p.light_radius()) < 0.01,
				"the flare stand-in burns at the player's light radius, %.1f px (FR15)" % p.light_radius())
	var r: Dictionary = perf.result
	check(r.get("frames", 0) > 0 and r.get("breaks", -1) == 0 and r.get("deaths", -1) == 0,
			"the summary: frames > 0, breaks 0, deaths 0 (got %s)" % [r])
	check(r.get("max_lit", 99) <= Spec.LIGHTS_ON_SCREEN_MAX and r.get("max_sprites", 0) >= 1 and r.get("chain", 0) == ChainState.MAX_CHAIN and r.get("glow", true) == false,
			"...lights max ≤ %d, sprites max ≥ 1, chain 20, glow off" % Spec.LIGHTS_ON_SCREEN_MAX)
	var text: String = PerfRun.summary_text(r) if not r.is_empty() else ""
	check(text.begins_with("perf 3 s: "), "...and its line reads 'perf 3 s: …' (got '%s')" % text)
	await get_tree().process_frame
	var lines := _warnings.take_perf_lines()
	check(lines.size() == 1 and lines[0] == "[room] dev: " + text, "...logged once as [room] dev: perf … (got %s)" % [lines])
	var ov := dev.overlays
	ov.mode = 4
	var before: int = ov.last_refresh_ms
	for i in 60:
		await get_tree().process_frame
		if ov.last_refresh_ms != before:
			break
	check(Array(ov.readout).any(func(row: String) -> bool: return row.begins_with("perf 3 s")), "overlay 4 then shows the summary (got %s)" % [ov.readout])
	check(_warnings.take().is_empty(), "...and perf_worst gives no path warning")
	await _teardown()


## D1: the held chain is --chain's n when a valid one is given, else 20; a rejected --chain=99 is
## not "given" (D14 red check 21).
func test_held_chain() -> void:
	for c: Array in [[["--chain=99", "--perf=1"], ChainState.MAX_CHAIN], [["--chain=5", "--perf=1"], 5]]:
		_build(["--room=perf_worst"] + c[0])
		var perf: Node = _dev().perf if _dev() != null else null
		var p: Player = _spawned[0] if _spawned.size() == 1 else null
		if perf == null or p == null:
			check(false, "(premise) %s builds a PerfRun and a player" % [c[0]])
			await _teardown()
			continue
		for i in 10:
			await get_tree().physics_frame
		check(perf.hold_chain == c[1] and p.chain.count == c[1], "%s holds chain %d (got hold %d, chain %d)" % [" ".join(c[0]), c[1], perf.hold_chain, p.chain.count])
		_warnings.take()
		await _teardown()


## Review 2026-11-19: a death mid-run (none happens in perf_worst today: the Hurtbox is masked).
## The run takes the new player, rebuilds the stand-ins in the rebuilt room and counts the death.
## The last life's stand-ins are moved once more before that, in a room World already took out of
## the tree; probed on 4.7.2, that prints no engine error (the runner would fail on one).
func test_death_mid_run() -> void:
	_build(["--room=perf_worst", "--perf=3"])
	var perf: Node = _dev().perf if _dev() != null else null
	var p: Player = _spawned[0] if _spawned.size() == 1 else null
	if perf == null or p == null:
		check(false, "(premise) --room=perf_worst --perf=3 builds a PerfRun and a player")
		await _teardown()
		return
	for i in 5:
		await get_tree().physics_frame
	p.die()
	var start_ms := Time.get_ticks_msec()
	while _spawned.size() < 2 and Time.get_ticks_msec() - start_ms < 3000:
		await get_tree().physics_frame
	var q: Player = _spawned[1] if _spawned.size() == 2 else null
	check(q != null and perf.deaths == 1, "a death mid-run: a fresh player, and the run counts 1 death (got %d)" % perf.deaths)
	if q != null:
		var room := _world.current_room()
		check(q.input.is_locked() and (q.get_node(^"Hurtbox") as Area2D).collision_mask == 0, "...the run takes the new player: locked, Hurtbox mask 0")
		check(perf.stand_ins.size() == 2 and perf.stand_ins.all(func(l: BudgetLight) -> bool: return l.is_inside_tree() and l.get_parent() == room),
				"...and rides two new stand-ins in the rebuilt room")
	_warnings.take()
	await _teardown()


## Review 2026-11-19: a chain break while measuring counts in `breaks` and the summary.
func test_breaks() -> void:
	_build(["--room=perf_worst", "--perf=1"])
	var perf: Node = _dev().perf if _dev() != null else null
	var p: Player = _spawned[0] if _spawned.size() == 1 else null
	if perf == null or p == null:
		check(false, "(premise) --room=perf_worst --perf=1 builds a PerfRun and a player")
		await _teardown()
		return
	for i in 10:
		await get_tree().physics_frame
	check(p.chain.count == ChainState.MAX_CHAIN and p.chain.held > 0 and perf.breaks == 0, "(premise) measuring at chain 20 with embers held, 0 breaks")
	p.chain.break_chain()  # banks the held embers, as a landing would
	check(perf.breaks == 1, "a break while measuring counts 1 (got %d)" % perf.breaks)
	var start_ms := Time.get_ticks_msec()
	while not perf.done and Time.get_ticks_msec() - start_ms < PERF_CAP_MS:
		await get_tree().physics_frame
	check(perf.done and perf.result.get("breaks", -1) == 1, "...and the summary says breaks 1 (got %s)" % [perf.result.get("breaks")])
	_warnings.take()
	await _teardown()


## D1: --perf on a room whose centre line meets a solid cell (m1_shaft, the default room: its
## middle ledge) warns once at the first spawn, and the run still starts.
func test_blocked_path() -> void:
	_build(["--perf=1"])
	var w := _warnings.take()
	check(_world.current_room().id == &"m1_shaft" and w.size() == 1 and w[0].begins_with("DevTools: --perf: room 'm1_shaft' blocks the path at row "),
			"--perf on m1_shaft: one path warning (got %s)" % [w])
	check(_dev().perf != null and _dev().get_node_or_null(^"PerfRun") != null, "...and the run still starts")
	await _teardown()


## AC1: --room=perf_worst alone is the plain room: no run, no stand-ins, no glow.
func test_room_alone() -> void:
	_build(["--room=perf_worst"])
	var dev := _dev()
	var p: Player = _spawned[0] if _spawned.size() == 1 else null
	check(_world.current_room().id == &"perf_worst" and dev != null and dev.perf == null and dev.get_node_or_null(^"PerfRun") == null,
			"--room=perf_worst alone starts there, with no PerfRun")
	if p != null:
		var hurtbox := p.get_node(^"Hurtbox") as Area2D
		check(not p.input.is_locked() and hurtbox.collision_mask == 12, "...the player is not locked and its Hurtbox mask is 12 (got %d)" % hurtbox.collision_mask)
		var at := _world.current_room().entry_position(&"spawn")
		check(p.global_position == at and p.chain.count == 0, "...at its P %s with chain 0 (got %s, chain %d)" % [at, p.global_position, p.chain.count])
	await get_tree().physics_frame
	var others := _lights().filter(func(n: Node) -> bool: return not (n.get_parent() is Lurker or n.get_parent() is Player))
	check(others.is_empty(), "...no stand-ins: every BudgetLight is a lurker glow or the player's light (got %s)" % [others])
	check(dev.get_node_or_null(^"Glow") == null and not dev.glow_on, "...and no Glow WorldEnvironment")
	check(_warnings.take().is_empty(), "...with no warning")
	await _teardown()


## AC6: --glow=on adds the code-built WorldEnvironment; off and a bad value add none.
func test_glow() -> void:
	_build(["--glow=on"])
	var env := _dev().get_node_or_null(^"Glow") as WorldEnvironment
	check(env != null and env.environment != null and env.environment.glow_enabled and env.environment.background_mode == Environment.BG_CANVAS and _dev().glow_on,
			"--glow=on: DevTools has a WorldEnvironment named Glow, glow on, BG_CANVAS")
	await _teardown()
	_build(["--glow=off"])
	check(_dev().get_node_or_null(^"Glow") == null and _world.find_children("*", "WorldEnvironment", true, false).is_empty() and not _dev().glow_on,
			"--glow=off: no WorldEnvironment anywhere")
	check(_warnings.take().is_empty(), "...and no warning")
	await _teardown()
	_build(["--glow=yes"])
	var w := _warnings.take()
	check(_dev().get_node_or_null(^"Glow") == null and w.size() == 1 and w[0].contains("--glow=yes"), "--glow=yes: none, with one warning (got %s)" % [w])
	await _teardown()


## AC7: a bad --perf warns and starts no run.
func test_bad_perf() -> void:
	for bad in ["0", "601", "x"]:
		_build(["--room=perf_worst", "--perf=" + bad])
		var w := _warnings.take()
		var dev := _dev()
		check(dev.perf == null and dev.get_node_or_null(^"PerfRun") == null and w.size() == 1 and w[0].contains("--perf=" + bad),
				"--perf=%s: one warning and no PerfRun (got %s)" % [bad, w])
		if not _spawned.is_empty():
			check(not _spawned[0].input.is_locked(), "...and the player is not taken")
		await _teardown()


## AC4 (D2) and AC10: m1_shaft with no args. The light rect is the whole view around the play
## rect; the budget can never demote anything there; the plain play needs no new node but
## LightBudget.
func test_m1_shaft() -> void:
	_build([])
	await get_tree().physics_frame
	var view := _world.light_rect()
	var play := _world.play_rect()
	check(view.size == Vector2(480, 270) and view.get_center().is_equal_approx(play.get_center()) and view.encloses(play),
			"light_rect() is the whole 480 × 270 view, centred on the play rect and containing it (got %s around %s)" % [view, play])
	check(view.size.x > play.size.x, "(premise) ...wider than the play rect: the gutters count for the budget (D2)")
	var lights := _lights()
	check(lights.size() >= 2 and lights.size() <= Spec.LIGHTS_ON_SCREEN_MAX,
			"m1_shaft holds %d BudgetLights (the player's and the lurker glows): never more than %d, so the budget can't demote anything" % [lights.size(), Spec.LIGHTS_ON_SCREEN_MAX])
	check(_counts().sprites == 0 and lights.all(func(n: Node) -> bool: return not (n as BudgetLight).demoted), "...at spawn no sprite glow and nothing demoted")
	check(_dev().perf == null and _world.find_children("*", "WorldEnvironment", true, false).is_empty() and _dev().get_node_or_null(^"PerfRun") == null,
			"no args: no PerfRun and no WorldEnvironment (AC10)")
	# D5: after every actor (priority 0) and before DevTools (100), by priority, never by tree order
	# alone: at priority 0 it runs after the room only because World adds it after RoomHolder.
	var budget := _world.get_node_or_null(^"LightBudget")
	var p: int = budget.process_physics_priority if budget != null else -1
	check(budget != null and p > 0 and p < _dev().process_physics_priority and budget.process_mode == Node.PROCESS_MODE_INHERIT,
			"World's LightBudget ticks after the actors and before DevTools by priority (got %d), pausable with World" % p)
	await _teardown()
