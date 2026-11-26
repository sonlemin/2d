extends Node
## DevTools in a real World (Story 1.11 D14): inert without args, the real command line, each
## entry arg applied and each bad one warned, the overlay key and its four modes, the light count,
## the Clock rows and "no function key"; and the boot marker the web smoke waits for (Story 1.13).
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_dev_tools.gd
## A test World is never the current scene, so DevTools never reads the command line here: each
## case sets its tokens from World's child_entered_tree, which fires before DevTools' _ready (D3).
## test_real_tokens and test_smoke_marker alone make their World the current scene, to run the
## real path.
## One World at a time (two would put two nodes in groups world and player); each case starts with
## the store on TMP (reset_for_tests() points it home) and ends in _teardown().
## UX numbers are written out (the 60 px gutter is CameraRig's, checked in smoke_world).

const Spec := preload("res://tests/spec.gd")
const WorldScene := preload("res://scenes/world/world.tscn")
const PlayerScene := preload("res://scenes/actors/player.tscn")
const Overlays := preload("res://scripts/dev/overlays.gd")
const LightTexture := preload("res://art/light.png")
const TMP := "user://smoke_dev_tools_tmp"

var _fail := 0
var _tokens := PackedStringArray()
var _world: World
var _spawned: Array[Player] = []
var _spawned_at: Array[Vector2] = []
var _banked: Array[int] = []
var _draws := {}  # drawer name -> draw count
var _warnings := Warnings.new()
var _stand_in: Player  # test_chain_mid_tick_spawn's second player, added inside a tick
var _room_at_marker: Array[bool] = []  # test_smoke_marker: whether World had its room as each marker printed
var _entered := 0  # test_smoke_marker: room_entered emissions, so "no second marker" can't pass vacuously


## Collects DevTools' push_warning texts (they arrive as `code`, probed on 4.7.2, as test_state's
## WarningCounter reads them), and the `[room] SMOKE …` marker lines (Story 1.13 D9). The runner
## ignores warnings and `[category]` lines; this is how the test sees them.
class Warnings extends Logger:
	var _lock := Mutex.new()
	var _got: Array[String] = []
	var _markers: Array[String] = []
	var _summaries: Array[String] = []  # `[room] dev: …`, DevTools' one summary line per run
	## Called as each marker prints, on the printing thread (the main thread: Log.info), so the
	## test can look at World at that instant. Must not print.
	var at_marker := Callable()

	func _log_error(_function: String, _file: String, _line: int, code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING or not code.begins_with("DevTools:"):
			return
		_lock.lock()
		_got.append(code)
		_lock.unlock()

	## The prefix, not "contains SMOKE": this logger also sees the test's own `ok …` lines and its
	## final `SMOKE PASS`.
	func _log_message(message: String, _error: bool) -> void:
		if message.begins_with("[room] dev: "):
			_lock.lock()
			_summaries.append(message.trim_suffix("\n"))
			_lock.unlock()
			return
		if not message.begins_with("[room] SMOKE "):
			return
		if at_marker.is_valid():
			at_marker.call()
		_lock.lock()
		_markers.append(message.trim_suffix("\n"))
		_lock.unlock()

	## The warnings since the last take().
	func take() -> Array[String]:
		_lock.lock()
		var out := _got.duplicate()
		_got.clear()
		_lock.unlock()
		return out

	## DevTools' summary lines since the last take_summaries().
	func take_summaries() -> Array[String]:
		_lock.lock()
		var out := _summaries.duplicate()
		_summaries.clear()
		_lock.unlock()
		return out

	## The marker lines since the last take_markers().
	func take_markers() -> Array[String]:
		_lock.lock()
		var out := _markers.duplicate()
		_markers.clear()
		_lock.unlock()
		return out


## Runs `job` once, inside a physics tick: after the players (priority 0), before DevTools (100).
class MidTick extends Node:
	var job: Callable

	func _init(j: Callable) -> void:
		job = j
		process_physics_priority = 50

	func _physics_process(_delta: float) -> void:
		if job.is_valid():
			var j := job
			job = Callable()
			j.call()


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func run() -> void:
	# Once: it walks swap/, input/ and dev_tools/ too. Adding a subfolder as well would index the
	# same files twice, and _scan push_errors every duplicate id.
	RoomLoader.add_root("res://tests/rooms")
	DirAccess.make_dir_recursive_absolute(TMP)
	OS.add_logger(_warnings)
	await test_no_tokens()
	await test_real_tokens()
	await test_smoke_marker()
	await test_room()
	await test_bad_room()
	await test_detach()
	await test_bad_args()
	await test_chain_every_life()
	await test_chain_falling_spawn()
	await test_chain_paused_spawn()
	await test_chain_mid_tick_spawn()
	await test_hp_every_life()
	await test_bad_hp()
	await test_difficulty()
	await test_bad_difficulty()
	await test_log()
	await test_set()
	await test_overlay_cycle()
	await test_overlay_play_rect_steady()
	await test_overlay_light()
	test_overlay_light_pure()
	await test_overlay_light_respawn()
	await test_clock_rows()
	await test_lights()
	await test_room_items()
	test_actions()
	OS.remove_logger(_warnings)
	var left := Array(DirAccess.get_files_at(TMP))
	left.erase("settings.json")  # the real-run cases boot, and a boot may write the default settings
	check(left.is_empty(), "no slot file was written by any case (TMP also holds %s)" % [left])
	DirAccess.remove_absolute(TMP.path_join("settings.json"))  # silent when missing
	DirAccess.remove_absolute(TMP)
	print("SMOKE %s" % ("PASS" if _fail == 0 else "FAILED (%d)" % _fail))


# --- Building and tearing down ----------------------------------------------------------------------

## A World whose DevTools gets `tokens`, as a real run would get them from the command line.
func _build(tokens: Array) -> void:
	Game.store.dir = TMP
	_tokens = PackedStringArray(tokens)
	_spawned.clear()
	_spawned_at.clear()
	_banked.clear()
	_world = WorldScene.instantiate()
	_world.child_entered_tree.connect(_on_world_child)
	_world.player_spawned.connect(_on_spawned)  # before add_child: the first spawn is inside it
	add_child(_world)


## A method, not a lambda (D3). Fires for every child (Darkness, RoomHolder, each Player…).
func _on_world_child(node: Node) -> void:
	if node is DevTools:
		node.tokens = _tokens


func _on_spawned(player: Player) -> void:
	_spawned.append(player)
	_spawned_at.append(player.position)


func _on_banked(amount: int) -> void:
	_banked.append(amount)


func _teardown() -> void:
	for action: StringName in [&"move_right", &"dev_overlay"]:
		Input.action_release(action)
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


func _room() -> Room:
	return _world.current_room()


## The overlay key, pressed for one frame. DevTools polls is_action_just_pressed() in _process, so
## press inside a process frame (process_frame fires just before the nodes' _process).
func _press_overlay() -> void:
	await get_tree().process_frame
	Input.action_press(&"dev_overlay")
	await get_tree().process_frame
	Input.action_release(&"dev_overlay")
	await get_tree().process_frame


## Waits until the overlay rebuilds its readout (last_refresh_ms changes), at most `cap` frames.
func _await_refresh(cap := 120) -> bool:
	var ov := _dev().overlays
	var before: int = ov.last_refresh_ms
	for i in cap:
		await get_tree().process_frame
		if ov.last_refresh_ms != before:
			return true
	return false


# --- Cases --------------------------------------------------------------------------------------

## AC9: no tokens, no change.
func test_no_tokens() -> void:
	Log.set_enabled([Log.SAVE])  # so a stray set_enabled() call would show (teardown clears it)
	_build([])
	await frames(2)
	var dev := _dev()
	check(dev != null and dev.process_mode == Node.PROCESS_MODE_ALWAYS and dev.process_physics_priority == 100,
			"a World in a debug build has a DevTools child that always processes, after the player each tick")
	if dev == null:
		await _teardown()
		return
	check(dev.tokens.is_empty(), "...with no tokens (World is not the current scene)")
	check(_room().id == &"m1_shaft" and _world.start_room == &"m1_shaft" and _world.start_entry == &"spawn"
			and _spawned_at == ([_room().entry_position(&"spawn")] as Array[Vector2]),
			"no args: the dive starts in m1_shaft at its spawn (got %s at %s)" % [_room().id, _spawned_at])
	check(_spawned[0].chain.count == 0 and _spawned[0].chain.held == 0, "...with chain 0")
	check(Log.CATEGORIES.all(func(c: StringName) -> bool: return Log.enabled(c) == (c == Log.SAVE)),
			"...Log untouched: save, on before the build, is still the only category on (no Log.set_enabled() call)")
	check(Game.clock.active().is_empty(), "...no Clock request")
	check(Game.settings.brightness == 1 and Game._overrides.is_empty() and not Game._settings_armed, "...settings untouched: no override, writes not armed")
	check(not Game._slot_detached and not Game._slot_armed, "...and the slot untouched: not detached, and saves not armed by a test World (Story 1.21)")
	check(dev.overlays.mode == 0, "...and no overlay until the key is pressed")
	var ui := _world.get_node("UI").get_children().map(func(c: Node) -> String: return String(c.name))
	check(ui == ["Gutters", "ScreenRouter"], "UI's children are unchanged (got %s)" % [ui])
	check(_world.get_node("RoomHolder").get_child_count() == 1, "RoomHolder holds one Room")
	var names := _world.get_children().filter(func(c: Node) -> bool: return not c is Player).map(func(c: Node) -> String: return String(c.name))
	check(names == ["Darkness", "RoomHolder", "Camera", "UI", "DevTools", "LightBudget"],
			"World's children: the scene's, the player, DevTools first of the added ones, then LightBudget (1.12 D5; got %s)" % [names])
	var tree := _subtree(dev)
	check(tree == ["Overlays", "Overlays/Screen", "Overlays/Screen/ScreenMarks", "Overlays/WorldMarks"],
			"DevTools' own subtree is Overlays with WorldMarks and Screen/ScreenMarks, built in _ready (got %s)" % [tree])
	check(_warnings.take().is_empty(), "...and no warning")
	await _teardown()


func _subtree(root: Node) -> Array[String]:
	var out: Array[String] = []
	for n in root.find_children("*", "", true, false):
		out.append(String(root.get_path_to(n)))
	out.sort()
	return out


## AC2: a real run reads its own command line. Off the web real_tokens() is the command line after
## `--` and nothing else (the JavaScriptBridge stub adds nothing); under the runner that is the
## test's own path, which isn't a `--` arg, so nothing applies. This World is made the current scene
## from child_entered_tree, before DevTools' _ready, as it is in a real run.
func test_real_tokens() -> void:
	_warnings.take_markers()
	var user_args := OS.get_cmdline_user_args()
	var got := DevTools.real_tokens()
	check(got == user_args and not user_args.is_empty(), "off the web, real_tokens() is the command line after -- (got %s)" % [got])
	var runner := get_tree().current_scene
	Game.store.dir = TMP
	# Story 1.21: this is the process's one boot (the first World that is the current scene), so a
	# slot planted here is what a real launch would find. Its respawn point is the top entry.
	var slot_file := TMP.path_join("slot_1.json")
	var planted := '{"version": 1, "meta": {}, "slot": {"cache": null, "deposited": 0, "best_chain": 7, "deaths": 1, "depth": 2, "difficulty": "hard", "flags": [], "play_time": 300, "resume_entry": "up", "resume_room": "m1_shaft", "visited": ["m1_shaft"]}, "dive": {"carried": 5, "respawn_entry": "up", "respawn_room": "m1_shaft"}}'
	var f := FileAccess.open(slot_file, FileAccess.WRITE)
	f.store_string(planted)
	f.close()
	check(not Game._booted, "(this World's boot is the process's first)")
	_spawned.clear()
	_spawned_at.clear()
	_world = WorldScene.instantiate()
	_world.child_entered_tree.connect(_make_current)
	_world.player_spawned.connect(_on_spawned)  # before add_child: the first spawn is inside it
	get_tree().root.add_child(_world)  # the current scene must be a child of root
	get_tree().current_scene = runner
	var dev := _dev()
	check(dev != null and dev.tokens == user_args, "a World that is the current scene reads them itself (got %s)" % [dev.tokens if dev else "no DevTools"])
	check(Game._booted and not Game._slot_detached and Game._slot_armed, "...boots Game, and with no dev arg the slot stays attached and saves are armed (Story 1.21)")
	check(Game.slot.best_chain == 7 and Game.slot.difficulty == &"hard" and Game.dive.carried == 5, "...the boot loaded slot 1 from the store's folder: best chain 7, hard, 5 carried (got %d, %s, %d)" % [Game.slot.best_chain, Game.slot.difficulty, Game.dive.carried])
	check(_spawned_at == ([_room().entry_position(&"up")] as Array[Vector2]) and _spawned_at != ([_room().entry_position(&"spawn")] as Array[Vector2]),
			"...and the player wakes at the saved respawn point, m1_shaft's top entry, not at P (got %s)" % [_spawned_at])
	check(FileAccess.get_file_as_string(slot_file) == planted, "...the load left the file byte for byte as it was")
	DirAccess.remove_absolute(slot_file)
	check(_room().id == &"m1_shaft" and _warnings.take().is_empty(), "...and the runner's own args change nothing, with no warning")
	var markers := _warnings.take_markers()
	check(markers == (["[room] SMOKE boot ok"] as Array[String]), "...and, as a real run, prints the boot marker once (got %s)" % [markers])
	await _teardown()


func _make_current(node: Node) -> void:
	if node is DevTools:
		get_tree().current_scene = _world


## AC7 (Story 1.13 D9): the web smoke's "the game booted" line. A real run prints
## `[room] SMOKE boot ok` once, on World's first room_entered, with the room built and the player
## in; a test World prints none (not the current scene, like the args), and a respawn's rebuild
## of the room prints no second one.
func test_smoke_marker() -> void:
	_warnings.take_markers()
	_build([])
	await frames(2)
	var markers := _warnings.take_markers()
	check(_room() != null and markers.is_empty(), "a test World (not the current scene) prints no SMOKE marker (got %s)" % [markers])
	await _teardown()

	var runner := get_tree().current_scene
	Game.store.dir = TMP
	_spawned.clear()
	_room_at_marker.clear()
	_entered = 0
	_warnings.at_marker = _note_marker
	_world = WorldScene.instantiate()
	_world.child_entered_tree.connect(_make_current)
	_world.player_spawned.connect(_on_spawned)  # before add_child: the first spawn is inside it
	_world.room_entered.connect(_on_room_entered)
	get_tree().root.add_child(_world)
	get_tree().current_scene = runner
	markers = _warnings.take_markers()
	check(markers == (["[room] SMOKE boot ok"] as Array[String]),
			"a real-run World prints exactly one `[room] SMOKE boot ok`, inside its _ready (got %s)" % [markers])
	check(_room_at_marker == ([true] as Array[bool]), "...after its first room is built and the player spawned (got %s)" % [_room_at_marker])
	if _spawned.is_empty():
		_warnings.at_marker = Callable()
		await _teardown()
		return
	_spawned[0].die()
	for i in int((World.RESPAWN_DELAY + 1.0) * Engine.physics_ticks_per_second):
		if _spawned.size() > 1:
			break
		await frames(1)
	markers = _warnings.take_markers()
	check(_spawned.size() == 2 and _entered == 2 and markers.is_empty(),
			"...and a respawn, which rebuilds the room and emits room_entered again, prints no second marker (spawns %d, room_entered %d, got %s)" % [_spawned.size(), _entered, markers])
	_warnings.at_marker = Callable()
	await _teardown()


func _on_room_entered(_id: StringName) -> void:
	_entered += 1


## Runs inside the marker's print (Warnings.at_marker): never print here.
func _note_marker() -> void:
	_room_at_marker.append(is_instance_valid(_world) and _room() != null and not _spawned.is_empty())


## AC3: --room= with a P starts there; without one it starts at the up entry, falling; a death
## comes back to it while no respawn point is set, and DevTools never sets one.
func test_room() -> void:
	_build(["--room=t_swap_a"])
	await frames(2)
	check(_room().id == &"t_swap_a" and _spawned_at == ([_room().entry_position(&"spawn")] as Array[Vector2]),
			"--room=t_swap_a starts at its P (got %s at %s)" % [_room().id, _spawned_at])
	_spawned[0].die()
	for i in int((World.RESPAWN_DELAY + 1.0) * Engine.physics_ticks_per_second):
		if _spawned.size() > 1:
			break
		await frames(1)
	check(_spawned.size() == 2 and _room().id == &"t_swap_a" and _spawned_at[-1] == _room().entry_position(&"spawn"),
			"...and a death respawns there, while no respawn point is set (got %s at %s)" % [_room().id, _spawned_at])
	check(Game.dive.respawn_room == &"" and Game.dive.respawn_entry == &"", "...DevTools never writes the respawn point")
	await _teardown()

	_build(["--room=t_swap_b"])
	var room := _room()  # null when the room failed to build (a wrong entry asserts in World)
	check(room != null and room.id == &"t_swap_b" and _world.start_entry == &"up" and _spawned_at == ([room.entry_position(&"up")] as Array[Vector2]),
			"--room=t_swap_b (no P) starts at its up entry (got %s, %s at %s)" % [room.id if room else &"no room", _world.start_entry, _spawned_at])
	if room == null or _spawned.is_empty():
		await _teardown()
		return
	await frames(3)
	check(_spawned[0].velocity.y > 0.0 and not _spawned[0].is_on_floor(), "...falling (vy %.1f)" % _spawned[0].velocity.y)
	check(_warnings.take().is_empty(), "good --room= args give no warning")
	await _teardown()


## AC3: an unknown id or an invalid room is a warning and the default start room, never an
## error or an assert (the runner fails on those, so staying green is the "no error" check).
func test_bad_room() -> void:
	_build(["--room=nope"])
	var w := _warnings.take()
	check(_room().id == &"m1_shaft" and _world.start_room == &"m1_shaft" and _spawned.size() == 1,
			"--room=nope: m1_shaft loads (got %s)" % _room().id)
	check(w.size() == 1 and w[0].contains("no room 'nope' (known: ") and w[0].contains("m1_shaft") and w[0].contains("t_dev_room"),
			"...with one warning listing the known ids (got %s)" % [w])
	await _teardown()
	_build(["--room=bad_edge_hole"])
	w = _warnings.take()
	check(_room().id == &"m1_shaft" and _spawned.size() == 1, "--room=bad_edge_hole: m1_shaft loads (got %s)" % _room().id)
	check(w.size() == 1 and w[0].contains("'bad_edge_hole' is invalid:") and w[0].contains("hole in the room's edge"),
			"...with one warning giving its validation errors (got %s)" % [w])
	await _teardown()


## Story 1.21 AC7, D12 (sonlm, 2026-11-25): a session that applied --room, --chain, --hp or --perf
## loads no slot and saves none; --log, --set and --glow leave the slot alone; an arg that was
## refused detaches nothing. The summary line says so.
func test_detach() -> void:
	var cases := [
		[["--room=t_swap_a"], true, "[room] dev: room t_swap_a@spawn, no slot loaded or saved"],
		[["--chain=3"], true, "[room] dev: chain 3, no slot loaded or saved"],
		[["--hp=2"], true, "[room] dev: hp 2, no slot loaded or saved"],
		[["--difficulty=hard"], true, "[room] dev: difficulty hard, no slot loaded or saved"],
		[["--log=save"], false, "[room] dev: log save"],
		[["--set=brightness:0"], false, "[room] dev: set brightness=0"],
		[["--glow=on"], false, "[room] dev: glow on"],
		[["--log=save", "--room=t_swap_a", "--chain=3"], true, "[room] dev: log save, room t_swap_a@spawn, chain 3, no slot loaded or saved"],
	]
	for c: Array in cases:
		_warnings.take_summaries()
		_build(c[0])
		var lines := _warnings.take_summaries()
		check(Game._slot_detached == c[1], "%s %s the slot (detached: %s)" % [" ".join(c[0]), "detaches" if c[1] else "leaves", Game._slot_detached])
		check(lines == ([c[2]] as Array[String]), "...and its summary line is '%s' (got %s)" % [c[2], lines])
		if c[1]:
			check(Game.load_slot(1) == SaveStore.Found.MISSING and not Game._slot_armed and Game.save_now() == ERR_UNCONFIGURED, "...so a load reads nothing and a save writes nothing for the rest of the session")
		_warnings.take()
		await _teardown()
		check(not Game._slot_detached, "...and reset_for_tests() (the teardown) attaches the slot again")
	# A --room with a bad value is a warning and is not applied: a normal session.
	_warnings.take_summaries()
	_build(["--room=nope"])
	var w := _warnings.take()
	check(w.size() == 1 and not Game._slot_detached and _warnings.take_summaries().is_empty(), "--room=nope (a warning, not applied) detaches nothing and prints no summary (warnings %d, detached %s)" % [w.size(), Game._slot_detached])
	await _teardown()
	_warnings.take_summaries()
	_build(["--room=nope", "--chain=99", "--hp=9", "--log=save"])
	w = _warnings.take()
	check(w.size() == 3 and not Game._slot_detached and _warnings.take_summaries() == (["[room] dev: log save"] as Array[String]), "three refused args beside a good --log: still attached (warnings %d, detached %s)" % [w.size(), Game._slot_detached])
	await _teardown()
	# --perf detaches too; it locks the player on its path, so the World is freed at once.
	_build(["--perf=1"])
	check(Game._slot_detached, "--perf=1 detaches the slot")
	_warnings.take()  # m1_shaft is not the perf room: the run warns that its path is blocked
	await _teardown()


## AC2, AC4, AC5: every bad arg reaches the developer as a DevTools warning, and the game starts
## with the good ones: an unknown arg, a repeated single-valued one, a bad --chain and a bad --log
## name, in one run.
func test_bad_args() -> void:
	_build(["--foo=1", "--chain=99", "--log=nope,save", "--room=t_swap_a", "--room=t_dev_room"])
	var w := _warnings.take()
	var has := func(part: String) -> bool: return w.any(func(t: String) -> bool: return t.contains(part))
	check(w.size() == 4 and has.call("unknown arg --foo (known: chain, difficulty, glow, hp, log, perf, room, set)") and has.call("--room given 2 times; using the last ('t_dev_room')")
			and has.call("--chain=99 is outside 0..%d" % ChainState.MAX_CHAIN) and has.call("--log: no category 'nope'"),
			"bad args: one warning each for --foo, the repeated --room, --chain=99 and --log=nope (got %s)" % [w])
	check(_room().id == &"t_dev_room" and Log.enabled(Log.SAVE) and not Log.enabled(Log.LURKER),
			"...and the good parts apply: the last --room, --log's save (got %s)" % _room().id)
	var dev := _dev()
	check(dev._chain == 0 and not _world.player_spawned.is_connected(dev._on_player_spawned), "...a bad --chain arms nothing")
	await _teardown()


## Story 1.19 D8: --hp=1 starts every life at 1 HP: the first and the respawned one.
func test_hp_every_life() -> void:
	_build(["--room=t_dev_room", "--hp=1"])
	var p := _spawned[0]
	check(p.health.hp == 1, "--hp=1: the first life has 1 HP (got %d)" % p.health.hp)
	var dev := _dev()
	check(_world.player_spawned.is_connected(dev._on_player_spawned_hp) and not _world.player_spawned.is_connected(dev._on_player_spawned),
			"...through its own spawn handler; --chain's is not connected")
	p.die()
	for i in int((World.RESPAWN_DELAY + 1.0) * Engine.physics_ticks_per_second):
		if _spawned.size() > 1:
			break
		await frames(1)
	var q: Player = _spawned[-1]
	check(_spawned.size() == 2 and q != p and q.health.hp == 1, "...and so does the respawned one (got %d)" % q.health.hp)
	await _teardown()


## Story 1.22 D10: --difficulty sets the tier on every spawn (the first and a respawn) and detaches
## the slot. A test World never boots, so smoke_dev_boot checks the real order (the boot's reset).
func test_difficulty() -> void:
	_build(["--room=t_dev_room", "--difficulty=easy"])
	var dev := _dev()
	check(Game.slot.difficulty == &"easy" and Game._slot_detached, "--difficulty=easy: the tier is easy and the slot is detached (got %s, %s)" % [Game.slot.difficulty, Game._slot_detached])
	check(_world.player_spawned.is_connected(dev._on_player_spawned_difficulty), "...through its own spawn handler")
	Game.slot.set_difficulty(&"hard")  # stands for anything that reset the tier between lives
	_spawned[0].die()
	for i in int((World.RESPAWN_DELAY + 1.0) * Engine.physics_ticks_per_second):
		if _spawned.size() > 1:
			break
		await frames(1)
	check(_spawned.size() == 2 and Game.slot.difficulty == &"easy", "...and the respawn sets it again (got %s)" % Game.slot.difficulty)
	await _teardown()


func test_bad_difficulty() -> void:
	_build(["--room=t_dev_room", "--difficulty=Hard"])
	var w := _warnings.take()
	var dev := _dev()
	check(w.size() == 1 and w[0].contains("--difficulty=Hard is not one of easy, normal, hard"), "a bad --difficulty is one warning (got %s)" % [w])
	check(not _world.player_spawned.is_connected(dev._on_player_spawned_difficulty) and Game.slot.difficulty == &"normal",
			"...connects nothing and leaves the tier normal (got %s)" % Game.slot.difficulty)
	await _teardown()
	_build(["--difficulty=medium"])
	_warnings.take()
	check(not Game._slot_detached, "--difficulty=medium alone (refused) detaches nothing")
	await _teardown()


func test_bad_hp() -> void:
	_build(["--room=t_dev_room", "--hp=0"])
	var w := _warnings.take()
	var dev := _dev()
	check(w.size() == 1 and w[0].contains("--hp=0 is outside 1..%d" % Spec.MAX_HP), "a bad --hp is one warning (got %s)" % [w])
	check(not _world.player_spawned.is_connected(dev._on_player_spawned_hp) and _spawned[0].health.hp == Spec.MAX_HP,
			"...connects nothing, and the life starts at full HP (got %d)" % _spawned[0].health.hp)
	await _teardown()


## AC4, D6 (sonlm, 2026-11-19): armed on every spawn, paid as 8 pogo hits on the first airborne
## tick, then broken and banked like any chain. t_dev_room, never m1_shaft: walking off m1_shaft's
## ledge ends in a hoverer knock in mid-air, so a "banked on landing" check there passes wrongly.
func test_chain_every_life() -> void:
	_build(["--room=t_dev_room", "--chain=8"])
	var p := _spawned[0]
	await frames(2)
	check(p.is_on_floor() and p.chain.count == 0, "(premise) --chain=8 in t_dev_room: the player stands at P with chain 0")
	await _stays_at_zero(p, "first life")
	var carried := Game.dive.carried
	p.chain.banked.connect(_on_banked)
	await _walk_off(p, "first life")
	check(Game.slot.best_chain == 8, "...and the slot's best chain is 8 (got %d)" % Game.slot.best_chain)
	# Landing: the tick before, the chain is still 8 (no knock or other break in the air); the
	# landing tick banks the 36 once.
	var before := {count = p.chain.count, banked = _banked.size()}
	var landed := false
	for i in 120:
		before = {count = p.chain.count, banked = _banked.size()}
		await frames(1)
		if p.is_on_floor():
			landed = true
			break
	check(landed and before.count == 8 and before.banked == 0, "...it lands with the chain still 8 on the tick before (got %s)" % [before])
	check(_banked == ([36] as Array[int]) and p.chain.count == 0 and Game.dive.carried == carried + 36,
			"...and the landing banks 36 once: chain 0, carried +36 (banked %s, carried %d -> %d)" % [_banked, carried, Game.dive.carried])
	# Every life: the respawned player is armed again. Picked by player_spawned, not by group.
	p.die()
	for i in int((World.RESPAWN_DELAY + 1.0) * Engine.physics_ticks_per_second):
		if _spawned.size() > 1:
			break
		await frames(1)
	var q: Player = _spawned[-1]
	check(_spawned.size() == 2 and q != p and is_instance_valid(q) and _spawned_at[-1] == _room().entry_position(&"spawn"),
			"(premise) after a death a different player spawns at P (spawned %d)" % _spawned.size())
	await frames(2)
	check(q.is_on_floor() and q.chain.count == 0, "(premise) ...standing, chain 0")
	await _stays_at_zero(q, "second life")
	await _walk_off(q, "second life")
	await _teardown()


func _stays_at_zero(p: Player, life: String) -> void:
	var counts: Array[int] = []
	for i in 10:
		await frames(1)
		counts.append(p.chain.count)
	check(counts.all(func(c: int) -> bool: return c == 0) and p.is_on_floor(), "%s: chain 0 for 10 standing ticks: armed, not lost (got %s)" % [life, counts])


## Holds right until the first tick that ends off the floor, then releases.
func _walk_off(p: Player, life: String) -> void:
	Input.action_press(&"move_right")
	var off := false
	for i in 120:
		await frames(1)
		if not p.is_on_floor():
			off = true
			break
	Input.action_release(&"move_right")
	check(off and p.chain.count == 8 and p.chain.held == 36, "%s: on the first airborne tick the chain is 8, held 36 (got %d, %d)" % [life, p.chain.count, p.chain.held])


## AC4: a spawn that is already falling (t_swap_b's up entry) gets the chain on its first tick.
func test_chain_falling_spawn() -> void:
	_build(["--room=t_swap_b", "--chain=8"])
	if _spawned.is_empty():
		check(false, "--chain=8 at an up entry: no player spawned")
		await _teardown()
		return
	var p := _spawned[0]
	var ran := false
	for i in 10:
		await frames(1)
		if p.velocity.y > 0.0:  # the player has run a tick
			ran = true
			break
	check(ran and p.chain.count == 8 and p.chain.held == 36, "--chain=8 at an up entry: 8 (held 36) on the player's first tick (got %d, %d)" % [p.chain.count, p.chain.held])
	await _teardown()


## D6: DevTools always processes, but a player spawned while paused has run no tick, and
## is_on_floor() is false until its first move_and_slide() (probed): the chain waits for a tick the
## player ran, or it would be paid at spawn and lost on the first floor tick.
func test_chain_paused_spawn() -> void:
	get_tree().paused = true
	_build(["--room=t_dev_room", "--chain=8"])
	var p := _spawned[0]
	await frames(5)
	check(not p.is_on_floor() and p.chain.count == 0, "--chain=8, spawned while paused: still 0 after 5 paused ticks (got %d)" % p.chain.count)
	get_tree().paused = false
	await frames(2)
	check(p.is_on_floor() and p.chain.count == 0, "...unpaused, the player stands at P with chain 0")
	await _walk_off(p, "spawned while paused")
	await _teardown()


## D6: a player added inside a tick (a later story's synchronous respawn) first ticks on the next
## one, while DevTools, already listed, still runs in this one (probed): is_on_floor() is false
## there, so paying then would hand the chain to a player that is standing, and its first floor
## tick would bank it. A stand-in player emits player_spawned from a helper at priority 50.
func test_chain_mid_tick_spawn() -> void:
	_build(["--room=t_dev_room", "--chain=8"])
	await frames(2)
	var helper := MidTick.new(_spawn_stand_in)
	add_child(helper)
	for i in 10:
		await frames(1)
		if is_instance_valid(_stand_in) and _stand_in.is_on_floor():
			break
	var q := _stand_in
	check(is_instance_valid(q) and q.is_on_floor() and q.chain.count == 0 and _banked.is_empty(),
			"--chain=8, a player spawned inside a tick: standing after its first tick, chain 0, nothing banked (got %s, banked %s)" % [q.chain.count if is_instance_valid(q) else -1, _banked])
	if is_instance_valid(q):
		await _walk_off(q, "spawned inside a tick")
	helper.queue_free()
	_stand_in = null
	await _teardown()


func _spawn_stand_in() -> void:
	_stand_in = PlayerScene.instantiate()
	_stand_in.position = _room().entry_position(&"spawn")
	_stand_in.chain.banked.connect(_on_banked)
	_world.add_child(_stand_in)
	_world.player_spawned.emit(_stand_in)


## AC5: names any case, against Log.CATEGORIES.
func test_log() -> void:
	_build(["--log=lurker,CLOCK"])
	check(Log.enabled(Log.LURKER) and Log.enabled(Log.CLOCK) and not Log.enabled(Log.SAVE), "--log=lurker,CLOCK turns on lurker and clock, nothing else")
	await _teardown()
	check(not Log.enabled(Log.LURKER), "(teardown) Log categories off again")
	# D7: one Log.set_enabled() call with every value merged, so the first --log isn't replaced.
	_build(["--log=lurker", "--log=CLOCK"])
	check(Log.enabled(Log.LURKER) and Log.enabled(Log.CLOCK) and not Log.enabled(Log.SAVE), "--log=lurker --log=CLOCK: both on, merged into one set")
	await _teardown()
	# No valid category is a bad value: a warning, and Log is left as it was.
	for args: Array in [["--log="], ["--log=nope"]]:
		Log.set_enabled([Log.SAVE])
		_build(args)
		var w := _warnings.take()
		check(w.size() == 1 and Log.CATEGORIES.all(func(c: StringName) -> bool: return Log.enabled(c) == (c == Log.SAVE)),
				"%s: one warning, and Log left as it was (got %s)" % [args[0], w])
		await _teardown()


## AC6, D8 (sonlm, 2026-11-19): --set goes through Game.override_setting(). The order copies a
## real run: DevTools applies before boot(). A test World never boots, so the test runs boot()'s
## load itself, arming writes first so the file check could fail.
func test_set() -> void:
	Game.store.dir = TMP
	DirAccess.remove_absolute(TMP.path_join("settings.json"))
	var err := Game.store.write_settings(Settings.new().to_dict())
	Game.load_settings()
	check(err == OK and Game._settings_armed and _file_brightness() == 1, "(premise) a clean settings.json holds brightness 1, and writes are armed")
	_build(["--set=brightness:3"])
	var darkness := _world.get_node("Darkness") as CanvasModulate
	var v := World.AMBIENT_LEVELS[3]
	check(Game.settings.brightness == 3 and not Game._settings_armed, "--set=brightness:3: brightness 3, and writes disarmed")
	check(darkness.color.is_equal_approx(Color(v * World.AMBIENT_TINT.r, v * World.AMBIENT_TINT.g, minf(v * World.AMBIENT_TINT.b, 1.0))),
			"...the dark is at level 3 (got %s)" % darkness.color)
	# A write is deferred: look before the load below, which disarms writes and would hide it.
	await get_tree().process_frame
	await get_tree().process_frame
	check(_file_brightness() == 1, "...and settings.json still holds 1 two frames later: the override wrote nothing")
	Game.load_settings()  # what boot() does next in a real run
	check(Game.settings.brightness == 3, "...and it survives the load boot() runs")
	await get_tree().process_frame
	await get_tree().process_frame
	check(_file_brightness() == 1, "...and the load wrote nothing either")
	check(_warnings.take().is_empty(), "...with no warning")
	await _teardown()
	_build(["--set=brightness:9", "--set=nope:1"])
	var w := _warnings.take()
	check(Game.settings.brightness == 1 and Game._overrides.is_empty() and w.size() == 2, "bad --set values: two warnings, nothing overridden (got %s)" % [w])
	await _teardown()
	DirAccess.remove_absolute(TMP.path_join("settings.json"))


## The brightness in the temp settings.json, or -1.
func _file_brightness() -> int:
	var path := TMP.path_join("settings.json")
	if not FileAccess.file_exists(path):
		return -1
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or not j.get_data() is Dictionary:
		return -1
	var s: Variant = (j.get_data() as Dictionary).get("settings")
	return int(s.brightness) if s is Dictionary and s.get("brightness") is float else -1


## AC7: four overlays, then off; cycles while paused; readable in the dark; never under UI or the room.
func test_overlay_cycle() -> void:
	_build([])
	await frames(1)
	var ov := _dev().overlays
	var marks := ov.get_node("WorldMarks") as Node2D
	var screen_marks := ov.get_node("Screen/ScreenMarks") as Node2D
	_draws = {}
	marks.draw.connect(_on_draw.bind("world"))
	screen_marks.draw.connect(_on_draw.bind("screen"))
	var modes: Array[int] = []
	var drawn: Array[String] = []
	for i in 5:
		await _press_overlay()
		modes.append(ov.mode)
		_draws.clear()
		await get_tree().process_frame
		await get_tree().process_frame
		drawn.append("%d:%d/%d" % [ov.mode, _draws.get("world", 0), _draws.get("screen", 0)])
	check(modes == ([1, 2, 3, 4, 0] as Array[int]), "the overlay key cycles 1, 2, 3, 4, then off (got %s)" % [modes])
	check(drawn.slice(0, 4).all(func(d: String) -> bool: return not d.contains(":0/") and not d.ends_with("/0")),
			"...each mode draws both layers in a rendered frame, with no error (got %s)" % [drawn])
	get_tree().paused = true
	await _press_overlay()
	check(ov.mode == 1, "...and it still cycles while the tree is paused (got %d)" % ov.mode)
	get_tree().paused = false
	var m := marks.material as CanvasItemMaterial
	check(m != null and m.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED, "WorldMarks draws unshaded: readable under the darkness")
	var screen := ov.get_node("Screen") as CanvasLayer
	check(screen.layer > (_world.get_node("UI") as CanvasLayer).layer, "the screen marks' CanvasLayer is above UI (%d > %d)" % [screen.layer, (_world.get_node("UI") as CanvasLayer).layer])
	var ui := _world.get_node("UI").get_children().map(func(c: Node) -> String: return String(c.name))
	check(ui == ["Gutters", "ScreenRouter"] and _world.get_node("RoomHolder").get_child_count() == 1,
			"after every mode, UI and RoomHolder are unchanged (got %s)" % [ui])
	await _teardown()
	_build([])
	var m2: Material = _dev().overlays.get_node("WorldMarks").material
	check(m2 == m, "a second World's WorldMarks shares the same cached material")
	await _teardown()


func _on_draw(which: String) -> void:
	_draws[which] = _draws.get(which, 0) + 1


## Mode 1 during a fall (sonlm, laptop 2026-11-19: the play rect shook while falling). The engine
## draws the view interpolated between physics ticks, while play_rect() moves only on ticks, so a
## frame drawn in world space was off by up to a tick of camera travel, a different amount every
## frame. On screen the play rect must sit still: sampled every rendered frame, several per tick,
## while the player falls down m1_shaft's open centre (x 176 is clear down to row 85).
func test_overlay_play_rect_steady() -> void:
	_build([])
	await frames(2)
	var ov := _dev().overlays
	await _press_overlay()
	var p := _spawned[0]
	p.global_position = Vector2(176, 120)
	p.reset_physics_interpolation()  # AR6: a teleport
	var want := Rect2(Vector2(CameraRig.GUTTER_WIDTH, 0.0), Vector2(CameraRig.PLAY_WIDTH, 270.0))
	var view_y := _world.light_rect().position.y
	var start_tick := Engine.get_physics_frames()
	var samples := 0
	var off: Array[Rect2] = []
	while Engine.get_physics_frames() - start_tick < 30 and samples < 100_000:
		await get_tree().process_frame
		samples += 1
		var r: Rect2 = ov.play_rect_on_screen()
		if r != want and off.size() < 3:
			off.append(r)
	var fell := _world.light_rect().position.y - view_y
	check(ov.mode == 1 and fell > 30.0 and samples > 30, "(premise) mode 1 while the camera falls %.0f px, %d frames over 30 ticks" % [fell, samples])
	check(off.is_empty(), "mode 1's play rect sits still on screen at %s every frame of the fall (got %s)" % [want, off])
	await _teardown()


## AC7 mode 2 past the notice radius, beside a lurker that notices the player (the cycle test's
## chain-0 spawn reaches only the dashed branch), plus a flare stand-in (Story 1.20 D10): every lit
## light gets its DevLightMarks and every predator its DevPredatorMarks, each a child the engine
## interpolates with it; the rings, labels and the sense line draw with no error; leaving mode 2
## frees them all. The player is held still with its physics off, as the screenshot script does;
## the lurker is the second from the top.
func test_overlay_light() -> void:
	_build([])
	await frames(2)
	var p := _spawned[0]
	var lurkers: Array[Node] = get_tree().get_nodes_in_group("predator").filter(func(n: Node) -> bool: return n is Lurker)
	lurkers.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.y < b.global_position.y)
	var lurker := lurkers[1] as Lurker if lurkers.size() > 1 else null
	if lurker == null:
		check(false, "(premise) m1_shaft has at least two lurkers")
		await _teardown()
		return
	p.set_physics_process(false)
	p.global_position = lurker.global_position + Vector2(-120, 10)
	p.velocity = Vector2.ZERO
	p.reset_physics_interpolation()
	for i in 10:
		p.chain.add_hit()
	(_world.get_node("Camera") as CameraRig).snap()
	await get_tree().process_frame
	var m := Overlays.light_marks(p.light_radius())
	check(lurker.notices(p.light_source) and m.noticeable and p.global_position.distance_to(lurker.global_position) <= m.reach,
			"(premise) at chain 10, 120 px from a lurker: it notices the player, and light_marks says noticeable within reach (got %s)" % [m])
	var o := Vector2(100, 100)
	for r: float in [Sensing.NOTICE_MIN_RADIUS - 0.1, Sensing.NOTICE_MIN_RADIUS]:
		check(Overlays.light_marks(r).noticeable == Sensing.can_sense(o, r, o) and Overlays.light_marks(r).reach == r * Sensing.NOTICE_FACTOR,
				"light_marks(%.1f) agrees with Sensing: noticeable %s, reach radius × NOTICE_FACTOR" % [r, Sensing.can_sense(o, r, o)])
	# A decoy beside the player, a child of the room (AR23): its own marks, as the cache's and the
	# flare's will have (1.22, 1.23).
	var flare := LightSource.new()
	flare.kind = Sensing.KIND_FLARE
	flare.fixed_radius = 60.0  # under the notice radius: the lurker keeps the player
	flare.position = p.global_position + Vector2(-30, -20)
	_world.current_room().add_child(flare)
	var ov := _dev().overlays
	_draws = {}
	ov.mode = 2
	await get_tree().process_frame
	# sonlm, laptop 2026-11-19: marks drawn in world space at a tick position trail and shake
	# against the interpolated sprite while it falls. On a child, the engine interpolates them with it.
	var pm := p.light_source.get_node_or_null(^"DevLightMarks") as Node2D
	var fm := flare.get_node_or_null(^"DevLightMarks") as Node2D
	var lm: Array[Node2D] = []
	for l: Node in lurkers:
		var x := l.get_node_or_null(^"DevPredatorMarks") as Node2D
		if x != null:
			lm.append(x)
	check(pm != null and pm.position == Vector2.ZERO and pm.material == Overlays.unshaded_material() and fm != null,
			"mode 2 puts DevLightMarks on the player's LightSource and on the stand-in's, each at its origin, unshaded (got %s, %s)" % [pm, fm])
	check(lm.size() == lurkers.size() and lm.all(func(x: Node2D) -> bool: return x.position == Vector2.ZERO and x.material == Overlays.unshaded_material()),
			"...and a DevPredatorMarks child on each of the %d lurkers (got %d)" % [lurkers.size(), lm.size()])
	if pm != null and fm != null and not lm.is_empty():
		pm.draw.connect(_on_draw.bind("player"))
		fm.draw.connect(_on_draw.bind("flare"))
		lurkers[1].get_node(^"DevPredatorMarks").draw.connect(_on_draw.bind("lurker"))
	# The top lurker sits far above the view: an open eye there draws mode 2's stir marker on screen.
	var top := lurkers[0] as Lurker
	top.stir = 2
	(ov.get_node("Screen/ScreenMarks") as Node2D).draw.connect(_on_draw.bind("screen"))
	for i in 3:
		await frames(1)
	await get_tree().process_frame
	await get_tree().process_frame
	check(lurker.state == Lurker.State.TELEGRAPH and lurker.target == p.light_source, "(premise) the lurker telegraphs at the player, so its sense line draws (state %s)" % Lurker.State.keys()[lurker.state])
	check(_draws.get("player", 0) > 0 and _draws.get("flare", 0) > 0 and _draws.get("lurker", 0) > 0,
			"mode 2 draws the rings and labels on both lights and the label and sense line on the lurker, with no error (got %s)" % [_draws])
	check(top.stir > 0 and not _world.play_rect().has_point(top.global_position) and _draws.get("screen", 0) > 0,
			"...and the stir marker for the open-eyed lurker off screen, with no error (stir %d)" % top.stir)
	var made: Array = ov.mark_nodes()
	ov.mode = 3
	await get_tree().process_frame
	await get_tree().process_frame
	check(made.size() >= 2 + lurkers.size() and made.all(func(x: Variant) -> bool: return not is_instance_valid(x)) and ov.mark_nodes().is_empty(),
			"...and leaving mode 2 frees every mark (%d)" % made.size())
	flare.queue_free()
	await _teardown()


## The pure pieces of mode 2: a predator's label and where its stir marker goes.
func test_overlay_light_pure() -> void:
	check(Overlays.predator_label("IDLE", &"", 0) == "IDLE" and Overlays.predator_label("TELEGRAPH", &"flare", 0) == "TELEGRAPH flare"
			and Overlays.predator_label("HUNT", &"player", 0) == "HUNT player" and Overlays.predator_label("IDLE", &"", 2) == "IDLE stir 2",
			"predator labels: IDLE, TELEGRAPH flare, HUNT player, IDLE stir 2")
	var play := Rect2(0, 100, 360, 270)
	check(Overlays.stir_marker_at(play, Vector2(8, 60)) == Vector2(8, 104) and Overlays.stir_marker_at(play, Vector2(200, 450)) == Vector2(200, 366),
			"the stir marker sits level with the lurker, 4 px inside the play rect's top or bottom edge")


## Mode 2 across a death: the marks go with the old player's light (extinguished, D5), and the next
## frame puts new ones on the respawned player's.
func test_overlay_light_respawn() -> void:
	_build([])
	await frames(2)
	var ov := _dev().overlays
	ov.mode = 2
	await get_tree().process_frame  # resumes before this frame's _process: the marks come in it
	await get_tree().process_frame
	var first := _spawned[0].light_source.get_node_or_null(^"DevLightMarks") as Node2D
	check(first != null, "(premise) mode 2's marks ride on the first player's light")
	_spawned[0].die()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(first), "a death takes the marks off at once: the light is out (D5)")
	var start_ms := Time.get_ticks_msec()
	while _spawned.size() < 2 and Time.get_ticks_msec() - start_ms < 3000:
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var q: Player = _spawned[1] if _spawned.size() == 2 else null
	check(q != null and q.light_source.get_node_or_null(^"DevLightMarks") != null,
			"...and the respawned player's light gets its own")
	await _teardown()


## AC7 mode 4: a 75 ms hitstop is sampled every frame and listed greyed for 0.5 s after it ends.
func test_clock_rows() -> void:
	_build([])
	var ov := _dev().overlays
	ov.mode = 4
	var rebuilt: bool = await _await_refresh()
	check(rebuilt, "(premise) mode 4 rebuilds its readout")
	Game.clock.request(&"hitstop", 0.05, 0.075)  # right after a rebuild: the next one is 250 ms away
	await get_tree().process_frame
	check(ov.clock_seen.has(&"hitstop"), "a hitstop requested right after a rebuild is seen one frame later (got %s)" % [ov.clock_seen])
	await get_tree().create_timer(0.3, true, false, true).timeout
	check(not Game.clock.is_active(&"hitstop"), "(premise) 0.3 s later the hitstop has ended")
	var rows: Array = ov.clock_list.filter(func(r: Dictionary) -> bool: return r.id == &"hitstop")
	check(rows.size() == 1 and not rows[0].live and is_equal_approx(rows[0].scale, 0.05), "...and the readout still lists it, greyed (got %s)" % [ov.clock_list])
	Game.clock.clear()
	await _teardown()


## 1.11 D10, moved by 1.12 D8: overlay 4 counts what the light budget counts, BudgetLight.counts()
## on World.light_rect() (the per-light rule's stand-in cases moved to test_light_budget). The count
## at m1_shaft's spawn is the player's light; code-built BudgetLights under the room count by D2's
## rect, the whole view, gutters included; a raw PointLight2D is not the budget's, so not counted.
## Then the frame-time rows, and cycle() resetting the worst frame.
func test_lights() -> void:
	_build([])
	var ov := _dev().overlays
	ov.mode = 4
	await _await_refresh()
	check(ov.light_count == 1, "m1_shaft at spawn: 1 light on screen, the player's (got %d)" % ov.light_count)
	# Lights built in code under the room, with no owner, as flares will be: one by the player
	# counts; one under the left gutter counts too (D2: the budget is a cost rule, and a light
	# under an opaque gutter still costs a lit pass); one wholly outside the view doesn't.
	var play := _world.play_rect()
	var view := _world.light_rect()
	_code_light(_spawned[0].global_position)
	_code_light(Vector2(play.position.x - 30.0, play.get_center().y))
	_code_light(view.get_center() + Vector2(-300.0, 0.0))
	var raw := PointLight2D.new()  # tests aren't linted; game code can't build one (raw_light)
	raw.texture = LightTexture
	raw.texture_scale = 0.2
	raw.energy = 1.0
	raw.global_position = _spawned[0].global_position
	_room().add_child(raw)
	await _await_refresh()
	check(ov.light_count == 3, "...plus a code-built light by the player and one under a gutter count, one outside the view doesn't: 3 (got %d)" % ov.light_count)
	check(raw.is_visible_in_tree() and BudgetLight.lit_on_screen(raw, view), "(premise) the raw PointLight2D is lit in the view")
	check(ov.light_count == 3, "...and the raw PointLight2D beside the player isn't counted: the overlay shows what the budget sees")
	var rows := Array(ov.readout)
	check(rows.any(func(r: String) -> bool: return r.begins_with("lights 3/6")), "the readout has a row 'lights 3/6…' (got %s)" % [rows])
	check(rows.any(func(r: String) -> bool: return r.begins_with("frame ")), "...and a 'frame … ms, worst … ms' row")
	check(ov.worst_frame_ms > 0.0, "(premise) the worst frame since mode 4 opened is above 0 (got %.2f ms)" % ov.worst_frame_ms)
	for i in 5:
		ov.cycle()
	check(ov.mode == 4 and ov.worst_frame_ms == 0.0 and ov.frame_ms == 0.0, "five cycles back into mode 4 reset the frame times before any frame passes (got %.2f)" % ov.worst_frame_ms)
	await _teardown()


## A 25.6 px light (light.png is 128 px), so one centred 30 px into a 60 px gutter stays under it.
## A BudgetLight of rank GLOW, as every light in game code must be (lint raw_light).
func _code_light(pos: Vector2) -> void:
	var light := BudgetLight.new()
	light.texture = LightTexture
	light.texture_scale = 0.2
	light.energy = 1.0
	light.global_position = pos
	_room().add_child(light)


## AC7 mode 3: exits with their targets, the entries and the obj= ids, from the Room.
func test_room_items() -> void:
	_build(["--room=t_dev_room"])
	var ov := _dev().overlays
	ov.mode = 3
	var items: Array[Dictionary] = ov.room_items()
	var exits := items.filter(func(i: Dictionary) -> bool: return i.kind == &"exit").map(func(i: Dictionary) -> String: return "%s>%s" % [i.side, i.target])
	var entries := items.filter(func(i: Dictionary) -> bool: return i.kind == &"entry").map(func(i: Dictionary) -> String: return i.text)
	var objs := items.filter(func(i: Dictionary) -> bool: return i.kind == &"obj")
	exits.sort()
	entries.sort()
	check(exits == ["down>t_dev_room", "up>t_dev_room"], "mode 3 lists both exits with their target (got %s)" % [exits])
	check(entries == ["down", "spawn", "up"], "...the spawn, up and down entries (got %s)" % [entries])
	check(objs.size() == 1 and objs[0].text == "lamp_t_dev_room_1" and objs[0].cell == Vector2i(5, 7) and objs[0].pos == _room().cell_centre(Vector2i(5, 7)),
			"...and the obj= id at its cell (got %s)" % [objs])
	var safe := items.filter(func(i: Dictionary) -> bool: return i.kind == &"safe")
	check(safe.size() == 1 and safe[0].pos == _world.last_safe_position(), "...and the safe ground, World.last_safe_position() (Story 1.19; got %s)" % [safe])
	var up: Array = items.filter(func(i: Dictionary) -> bool: return i.kind == &"exit" and i.side == &"up")
	check(up.size() == 1 and up[0].rect == Rect2(128, 0, 16, 16), "...the up exit's opening is its one open cell in row 0 (got %s)" % [up[0].rect if up.size() == 1 else up])
	_draws = {}
	(ov.get_node("WorldMarks") as Node2D).draw.connect(_on_draw.bind("world"))
	await get_tree().process_frame
	await get_tree().process_frame
	check(_draws.get("world", 0) > 0, "...and mode 3 draws them, the obj= mark included, with no error")
	await _teardown()


## AC8, D13: no project action has a function key, and dev_overlay is the backquote alone. The
## engine's own ui_* actions are skipped: ui_filedialog_refresh is F5 in every runtime InputMap.
func test_actions() -> void:
	var bad: Array[String] = []
	var checked := 0
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue
		checked += 1
		for e in InputMap.action_get_events(action):
			var k := e as InputEventKey
			if k != null and ((k.keycode >= KEY_F1 and k.keycode <= KEY_F35) or (k.physical_keycode >= KEY_F1 and k.physical_keycode <= KEY_F35)):
				bad.append("%s: %s" % [action, k.as_text()])
	check(checked >= 9 and InputMap.has_action(&"jump") and InputMap.has_action(&"dev_overlay"), "(premise) the project's actions were checked (%d)" % checked)
	check(bad.is_empty(), "no project action is bound to a function key (got %s)" % [bad])
	var ev := InputMap.action_get_events(&"dev_overlay")
	var k := ev[0] as InputEventKey if ev.size() == 1 else null
	check(k != null and k.physical_keycode == KEY_QUOTELEFT and k.keycode == KEY_NONE
			and not (k.shift_pressed or k.ctrl_pressed or k.alt_pressed or k.meta_pressed),
			"dev_overlay has exactly one event: the physical backquote, no modifier (got %s)" % [ev])
