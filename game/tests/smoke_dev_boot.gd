extends Node
## The order of a real launch (Story 1.21 D12, AC7; 1.21 review): DevTools applies its args before
## `Game.boot()`, so an arg that detaches the slot is in force when the boot would load one. With
## the two swapped in `World._ready()`, a `--room` session would load the player's slot first and
## play on it.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_dev_boot.gd
## Its own file because boot runs once per process, and this process's one boot must be the one
## with a detaching arg (smoke_dev_tools' boot has none).
## A World that is the current scene reads the real command line, which here is only the test's
## own path. So the tokens are set from World's child_entered_tree (before DevTools' _ready), and
## World becomes the current scene from DevTools' `ready` signal: after DevTools applied them,
## before World's next line asks whether to boot. Swapped, World would ask before it is the
## current scene and never boot, and the first check below fails.

const WorldScene := preload("res://scenes/world/world.tscn")
const TMP := "user://smoke_dev_boot_tmp"
## A slot as an earlier session left it: best chain 7, hard, 5 carried, waking at m1_shaft's top.
const PLANTED := '{"version": 1, "meta": {}, "slot": {"best_chain": 7, "deaths": 1, "depth": 2, "difficulty": "hard", "flags": [], "play_time": 300, "resume_entry": "up", "resume_room": "m1_shaft", "visited": ["m1_shaft"]}, "dive": {"carried": 5, "respawn_entry": "up", "respawn_room": "m1_shaft"}}'

var _fail := 0
var _world: World


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func run() -> void:
	RoomLoader.add_root("res://tests/rooms/swap")
	DirAccess.make_dir_recursive_absolute(TMP)
	Game.store.dir = TMP
	var slot_file := TMP.path_join("slot_1.json")
	var f := FileAccess.open(slot_file, FileAccess.WRITE)
	f.store_string(PLANTED)
	f.close()
	check(not Game._booted, "(this World's boot is the process's first)")
	var runner := get_tree().current_scene
	_world = WorldScene.instantiate()
	_world.child_entered_tree.connect(_on_world_child)
	get_tree().root.add_child(_world)  # the current scene must be a child of root
	get_tree().current_scene = runner
	check(Game._booted, "a World that is the current scene boots Game, after DevTools is ready")
	check(Game._slot_detached and not Game._slot_armed, "...and --room was applied before that boot: the slot is detached and saves are unarmed")
	check(Game.slot.best_chain == 0 and Game.slot.difficulty == &"normal" and Game.dive.carried == 0 and Game.dive.respawn_room == &"", "...so the boot loaded no slot: the defaults, not the planted best chain 7, hard, 5 carried (got %d, %s, %d)" % [Game.slot.best_chain, Game.slot.difficulty, Game.dive.carried])
	check(_world.current_room() != null and _world.current_room().id == &"t_swap_a", "...and the dev room wins over the saved respawn point (m1_shaft's top entry)")
	Game.slot.record_chain(40)
	check(Game.save_now() == ERR_UNCONFIGURED and Game.save_progress() == ERR_UNCONFIGURED, "...and no save reaches the slot for the rest of the session")
	_world.queue_free()
	_world = null
	await get_tree().process_frame  # the boot's settings load queued a write of the defaults
	await get_tree().process_frame
	check(FileAccess.get_file_as_string(slot_file) == PLANTED, "the planted slot file is byte for byte as it was")
	var left := Array(DirAccess.get_files_at(TMP))
	left.erase("settings.json")
	check(left == ["slot_1.json"], "...alone in the folder beside the settings: no .bak, no .tmp (TMP holds %s)" % [left])
	Game.reset_for_tests()
	Log.set_enabled([])
	for file in DirAccess.get_files_at(TMP):
		DirAccess.remove_absolute(TMP.path_join(file))
	DirAccess.remove_absolute(TMP)
	print("SMOKE %s" % ("PASS" if _fail == 0 else "FAILED (%d)" % _fail))


## A method, not a lambda (1.11 D3). Fires for every child World adds.
func _on_world_child(node: Node) -> void:
	if node is DevTools:
		node.tokens = PackedStringArray(["--room=t_swap_a"])
		node.ready.connect(_make_current, CONNECT_ONE_SHOT)


func _make_current() -> void:
	get_tree().current_scene = _world
