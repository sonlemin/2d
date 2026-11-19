extends Node
## The Clock owns Engine.time_scale (ADR-4, AR36): requests multiply, run on real time, pause
## with the tree, and clear on death and on _exit_tree.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_clock.gd
## Each case uses a fresh Clock so no request leaks into the next. Expiry is checked with wide
## margins because headless frame timing jitters. Timers that expire in the same frame fire in
## creation order, so a probe that must see a request still active is created before it.

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
	await _test_pogo_requests_hitstop()
	await _test_death_clears()
	await _test_active()
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


## Real-time wait that also runs while a case has paused the tree.
func wait(s: float) -> void:
	await probe(s).timeout


## A real-time timer to await later. Create it before a request it must outlast: on a long frame
## both expire in the same pass, and the earlier-created one fires first.
func probe(s: float) -> SceneTreeTimer:
	return get_tree().create_timer(s, true, false, true)


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
	var early := probe(0.03)
	c.request(&"hitstop", 0.05, 0.075)
	await early.timeout
	check(c.is_active(&"hitstop") and absf(Engine.time_scale - 0.05) < EPS, "hitstop is active at 0.03 s, scale 0.05")
	await wait(0.12)
	check(not c.is_active(&"hitstop") and absf(Engine.time_scale - 1.0) < EPS, "hitstop is gone by 0.15 s of real time, scale 1.0 (got %.4f)" % Engine.time_scale)
	_drop(c)


## The first timer still fires at 0.15 s; its stale serial must not end the refreshed request.
## Both probes are created first, so even a frame long enough to tie them with a Clock timer
## re-requests before the first expiry and checks before the refreshed one.
func _test_rerequest_refreshes() -> void:
	var c := _fresh()
	var mid := probe(0.10)
	c.request(&"hitstop", 0.5, 0.15)
	await mid.timeout
	var late := probe(0.10)
	c.request(&"hitstop", 0.25, 0.15)
	check(absf(Engine.time_scale - 0.25) < EPS, "re-requesting an id takes the latest scale: 0.25, never 0.125 or 0.5 (got %.4f)" % Engine.time_scale)
	await late.timeout
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


## FR4: the real hit path, not just the Clock, must freeze the world for the 75 ms.
func _test_pogo_requests_hitstop() -> void:
	var player: Player = PlayerScene.instantiate()
	add_child(player)
	await get_tree().physics_frame
	var early := probe(0.03)
	player._on_pogo_hit()
	await early.timeout
	check(Game.clock.is_active(&"hitstop") and absf(Engine.time_scale - 0.05) < EPS, "a pogo hit requests the hitstop through Game.clock, scale 0.05 (got %.4f)" % Engine.time_scale)
	await wait(0.12)
	check(not Game.clock.is_active(&"hitstop") and absf(Engine.time_scale - 1.0) < EPS, "...and the freeze ends by 0.15 s of real time")
	Game.clock.clear()  # leave the session clock clean even if a check failed
	player.queue_free()


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


## Story 1.11 D11: active() is a read-only copy for DevTools' overlay, {id: scale}.
func _test_active() -> void:
	var c := _fresh()
	check(c.active().is_empty(), "active(): empty at start")
	var early := probe(0.03)
	c.request(&"hitstop", 0.05, 0.075)
	check(c.active() == {&"hitstop": 0.05}, "active(): after a hitstop request it holds {hitstop: 0.05} (got %s)" % [c.active()])
	c.request(&"hitstop", 0.5, 0.075)
	check(c.active() == {&"hitstop": 0.5}, "active(): a refresh shows the latest scale (got %s)" % [c.active()])
	var copy := c.active()
	copy[&"hitstop"] = 0.9
	copy[&"other"] = 0.1
	copy.erase(&"hitstop")
	check(c.active() == {&"hitstop": 0.5} and c.is_active(&"hitstop") and not c.is_active(&"other") and absf(Engine.time_scale - 0.5) < EPS,
			"active(): changing the returned copy changes nothing in the Clock (got %s, scale %.4f)" % [c.active(), Engine.time_scale])
	await early.timeout
	await wait(0.15)
	check(c.active().is_empty(), "active(): empty again after the request expires (got %s)" % [c.active()])
	c.request(&"a", 0.5, 5.0)
	c.clear()
	check(c.active().is_empty(), "active(): empty after clear()")
	_drop(c)
