extends Node
## Headless smoke test of the shaft's session-state wiring (Story 1.4 AC3 and D10). Added by the
## 1.4 review: until then the only run-time evidence was a probe that was deleted.
## The shaft keeps no state of its own. A bank goes to Game.dive, the best chain and the deaths go
## to Game.slot, and the darkness follows Game.settings.brightness. All of it survives a new shaft,
## which is what a death's scene reload gives the game.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_shaft_state.gd
## The harness adds the shaft by hand, so the shaft is never the current scene: it must not boot
## Game, and settings writes stay disarmed. The store still points at a temp folder, so a bug
## that armed them could only write there.
## The chain is driven through ChainState with no frame in between, so no landing can change it
## mid-check, and the lurkers are paused so none can kill the player.

const ShaftScene := preload("res://scenes/shaft.tscn")
const Shaft := preload("res://scripts/shaft.gd")
const TMP := "user://smoke_shaft_state_tmp"

var _fail := 0
var _shaft: Node2D
var _player: Player
var _spawn: Vector2


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
	_add_shaft()
	_spawn = _player.position  # where _build() put the player: on the P tile
	await frames(2)
	test_no_boot()
	test_chain_and_bank()
	await test_hud_reads_game()
	test_brightness()
	await test_death()
	await test_new_shaft_keeps_the_state()
	await get_tree().process_frame  # a queued settings write would land here
	check(not FileAccess.file_exists(TMP.path_join("settings.json")), "nothing was written: settings writes are disarmed in a test")
	Game.reset_for_tests()
	DirAccess.remove_absolute(TMP.path_join("settings.json"))  # silent when missing
	DirAccess.remove_absolute(TMP)
	print("SMOKE %s" % ("PASS" if _fail == 0 else "FAILED (%d)" % _fail))


func _add_shaft() -> void:
	_shaft = ShaftScene.instantiate()
	add_child(_shaft)
	_player = _shaft.get_node("Player")
	for l in get_tree().get_nodes_in_group("predator"):
		l.set_physics_process(false)


func _hud() -> String:
	return (_shaft.get_node("Debug/Label") as Label).text


## D6: only the entry scene boots. A shaft that booted here would load the real settings.json.
func test_no_boot() -> void:
	check(not Game._booted and not Game._settings_armed, "a shaft added by a harness is not the current scene: Game is not booted and writes are not armed")


func test_chain_and_bank() -> void:
	for i in 3:
		_player.chain.add_hit()
	check(Game.slot.best_chain == 3, "a chain of 3 records best_chain 3 on the slot (got %d)" % Game.slot.best_chain)
	var held := _player.chain.held
	_player.chain.break_chain()
	check(held == 6 and Game.dive.carried == 6, "a safe break banks the 6 held embers as carried (held %d, carried %d)" % [held, Game.dive.carried])
	check(Game.slot.best_chain == 3, "...and the best chain stays when the chain resets")


## process_frame fires before the nodes' _process, so the label is current after the second one.
func test_hud_reads_game() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	check(_hud().begins_with("embers 6 ") and _hud().contains("(best 3)") and _hud().contains("deaths 0"), "the HUD label reads Game (got '%s')" % _hud())


## The shaft repaints from Settings' `changed` signal, never from the key press itself.
func test_brightness() -> void:
	var darkness: CanvasModulate = _shaft.get_node("Darkness")
	var choices: Array = Settings.SCHEMA[&"brightness"].choices
	check(choices.size() == Shaft.AMBIENT_LEVELS.size(), "every brightness choice has an ambient level (%d choices, %d levels)" % [choices.size(), Shaft.AMBIENT_LEVELS.size()])
	var got := []
	var want := []
	for level: int in [3, 0, 2, 1, 3]:  # each differs from the one before, so each emits
		Game.settings.set_value(&"brightness", level)
		got.append(snappedf(darkness.color.r, 0.001))
		want.append(snappedf(Shaft.AMBIENT_LEVELS[level] * Shaft.AMBIENT_TINT.r, 0.001))
	check(got == want, "set_value(brightness, n) repaints the darkness at once, for every level (got %s, want %s)" % [got, want])


func test_death() -> void:
	for i in 2:
		_player.chain.add_hit()
	_player.global_position += Vector2(0, 160)  # die away from P
	_player.die()
	check(Game.slot.deaths == 1, "a death records one death on the slot (got %d)" % Game.slot.deaths)
	check(Game.dive.carried == 6 and _player.chain.held == 0, "...keeps the carried embers and loses the held ones (carried %d, held %d)" % [Game.dive.carried, _player.chain.held])
	# Past RESPAWN_DELAY, so the shaft's reload check runs while the shaft still exists.
	await seconds(Shaft.RESPAWN_DELAY + 0.1)
	check(is_instance_valid(_shaft) and _shaft.is_inside_tree(), "...and a shaft that isn't the current scene doesn't reload it")


## A death reloads the scene, which builds a new shaft. Everything above must still be there,
## because none of it lives on the shaft any more.
func test_new_shaft_keeps_the_state() -> void:
	_shaft.queue_free()
	await frames(1)
	_add_shaft()
	check(_player.position == _spawn, "a new shaft (what a death's reload gives) spawns the player at P, not where it died (got %s, P is %s)" % [_player.position, _spawn])
	var darkness: CanvasModulate = _shaft.get_node("Darkness")
	check(is_equal_approx(darkness.color.r, Shaft.AMBIENT_LEVELS[3] * Shaft.AMBIENT_TINT.r), "...is painted at the brightness in Game.settings from the start")
	await get_tree().process_frame
	await get_tree().process_frame
	check(_hud().begins_with("embers 6 ") and _hud().contains("(best 3)") and _hud().contains("deaths 1"), "...and its HUD still shows the carried embers, the best chain and the death (got '%s')" % _hud())
