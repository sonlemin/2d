extends Node
## The Clock owns Engine.time_scale (ADR-4, AR36): requests multiply, run on real time, pause
## with the tree, and clear on death and on _exit_tree.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_clock.gd
## Each case uses a fresh Clock so no request leaks into the next. Expiry is checked with wide
## margins because headless frame timing jitters.

const EPS := 0.0001
const PlayerScene := preload("res://scenes/actors/player.tscn")

var _fail := 0


func run() -> void:
	_test_game_holds_clock()
	_test_ids_multiply()
	await _test_hitstop_runs_on_real_time()
	await _test_rerequest_refreshes()
	await _test_pause_freezes_requests()
	_test_exit_tree_clears()
	await _test_death_clears()
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


## Real-time wait that also runs while a case has paused the tree.
func wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _fresh() -> Clock:
	var c := Clock.new()
	add_child(c)
	return c


func _drop(c: Clock) -> void:
	remove_child(c)
	c.queue_free()


func _test_game_holds_clock() -> void:
	check(Game.clock is Clock, "Game.clock is a Clock")
	check(Game.clock.get_parent() == Game, "...and a child of Game")
	check(is_equal_approx(Engine.time_scale, 1.0), "time scale starts at 1.0")


func _test_ids_multiply() -> void:
	var c := _fresh()
	c.request(&"a", 0.5, 1.0)
	c.request(&"b", 0.2, 1.0)
	check(absf(Engine.time_scale - 0.1) < EPS, "different ids multiply: 0.5 x 0.2 = 0.1 (got %.4f)" % Engine.time_scale)
	_drop(c)


## FR4: 75 ms of real time. A game-time timer at x0.05 would last 1.5 s instead.
func _test_hitstop_runs_on_real_time() -> void:
	var c := _fresh()
	c.request(&"hitstop", 0.05, 0.075)
	await wait(0.03)
	check(c.is_active(&"hitstop") and absf(Engine.time_scale - 0.05) < EPS, "hitstop is active at 0.03 s, scale 0.05")
	await wait(0.12)
	check(not c.is_active(&"hitstop") and absf(Engine.time_scale - 1.0) < EPS, "hitstop is gone by 0.15 s of real time, scale 1.0 (got %.4f)" % Engine.time_scale)
	_drop(c)


## The first timer still fires at 0.15 s; its stale serial must not end the refreshed request.
func _test_rerequest_refreshes() -> void:
	var c := _fresh()
	c.request(&"hitstop", 0.5, 0.15)
	await wait(0.10)
	c.request(&"hitstop", 0.5, 0.15)
	check(absf(Engine.time_scale - 0.5) < EPS, "re-requesting an id keeps 0.5, never 0.25 (got %.4f)" % Engine.time_scale)
	await wait(0.10)
	check(c.is_active(&"hitstop"), "...and refreshes it: still active at 0.20 s, after the first expiry")
	await wait(0.20)
	check(not c.is_active(&"hitstop") and absf(Engine.time_scale - 1.0) < EPS, "...then ends")
	_drop(c)


## AR36: requests pause with the tree, so a pause mid-hitstop resumes the freeze after.
func _test_pause_freezes_requests() -> void:
	var c := _fresh()
	c.request(&"p", 0.5, 0.1)
	get_tree().paused = true
	await wait(0.3)
	check(c.is_active(&"p"), "a 0.1 s request survives 0.3 s of pause")
	get_tree().paused = false
	await wait(0.25)
	check(not c.is_active(&"p") and absf(Engine.time_scale - 1.0) < EPS, "...and ends after unpausing")
	_drop(c)


func _test_exit_tree_clears() -> void:
	var c := _fresh()
	c.request(&"hitstop", 0.05, 5.0)
	remove_child(c)
	check(absf(Engine.time_scale - 1.0) < EPS, "leaving the tree clears every request (_exit_tree)")
	c.queue_free()


## A death mid-hitstop must not leave the respawned world frozen.
func _test_death_clears() -> void:
	var player: Player = PlayerScene.instantiate()
	add_child(player)
	await get_tree().physics_frame
	Game.clock.request(&"hitstop", 0.05, 5.0)
	player.die()
	check(not Game.clock.is_active(&"hitstop") and absf(Engine.time_scale - 1.0) < EPS, "player death clears every request (got %.4f)" % Engine.time_scale)
	Game.clock.clear()  # leave the session clock clean even if the check failed
	player.queue_free()
