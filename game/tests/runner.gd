extends Node
## Runs one test script as a scene, so `Game`, `preload` and `class_name` work as in game code.
## R17: under `--script`, a test that names `Game` fails to compile, and can hang or exit 0 silently.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/<test>.gd [extra args]
##
## Contract for a test script:
## - `extends Node` and implements `func run() -> void`, which may `await`.
## - Prints `ok …` / `FAIL …` lines and a final line containing `PASS` or `FAILED`.
##   `ok` lines and `[category]` Log lines never count as a verdict.
## - Never calls `quit()`: the runner decides the exit code, and fails a test that quits itself.
## - Extra arguments after the test path reach it as `OS.get_cmdline_user_args()[1..]`.
## - `run()` starts two frames after the test enters the tree (its `_ready` runs before that).
## - The runner frees the test after `run()` returns and watches two more frames, so errors in
##   its teardown count too.
##
## Exits 1 when the test printed a failure, printed no PASS line, ran longer than TIMEOUT, or
## logged any error (D3: a runtime error inside a helper aborts only the helper, so `run()`
## carries on and prints PASS; the error count is the only signal). Warnings are allowed:
## environment errors use `push_warning` (Architecture → Error Handling).
## TIMEOUT is a SceneTreeTimer, so it can't fire if a test blocks the main loop; run_tests.sh
## adds a wall-clock `timeout` around each run for that.

const TIMEOUT := 120.0  ## seconds of real time, counted even while the test pauses the tree or freezes time

var _capture := Capture.new()
var _done := false


## Sees every print, printerr, push_error and engine error line. Engine logging can arrive
## from any thread, hence the mutex.
class Capture extends Logger:
	var _lock := Mutex.new()
	var _pass_re := RegEx.create_from_string("\\bPASS\\b")
	var _failed_re := RegEx.create_from_string("\\bFAILED\\b")
	var _passed := false
	var _failed := false
	var _errors := 0

	func _log_message(message: String, _error: bool) -> void:
		_lock.lock()
		for line in message.split("\n", false):
			# An `ok` line is a passed check whatever its text says, and a `[category]` line is Log
			# output from game code: a "[save] … PASS" must not pass a test that returned early.
			if line.begins_with("ok") or line.begins_with("["):
				continue
			if line.begins_with("FAIL") or _failed_re.search(line) != null:
				_failed = true
			elif _pass_re.search(line) != null:
				_passed = true
		_lock.unlock()

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_lock.lock()
		_errors += 1
		_lock.unlock()

	## [passed, failed, errors], read under the lock.
	func result() -> Array:
		_lock.lock()
		var r := [_passed, _failed, _errors]
		_lock.unlock()
		return r


func _ready() -> void:
	OS.add_logger(_capture)
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		_finish(false, "no test path after --")
		return
	var path := args[0]
	if not ResourceLoader.exists(path):
		_finish(false, "cannot load test %s" % path)
		return
	var script := load(path) as Script
	if script == null or not script.can_instantiate():
		_finish(false, "cannot load test %s" % path)
		return
	var test: Object = script.new()
	if not test is Node or not test.has_method("run"):
		if test is Node:
			test.queue_free()
		_finish(false, "%s must extend Node and implement run()" % path)
		return
	get_tree().create_timer(TIMEOUT, true, false, true).timeout.connect(
			_finish.bind(false, "no result after %d s" % int(TIMEOUT)))
	test.name = path.get_file().get_basename()
	add_child(test)
	# Start on the second frame. The first frame's delta carries the time spent loading the test
	# and its preloads (~80 ms with player.tscn), and process_frame fires before that frame's
	# timers advance, so a timer the test makes there would jump by the whole load time.
	await get_tree().process_frame
	await get_tree().process_frame
	await test.run()
	# The test's last frame may have queued frees and deferred calls: let them run while the
	# logger still watches, so a teardown error fails the test (D3) instead of slipping past.
	if is_instance_valid(test):
		test.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var r := _capture.result()
	var passed: bool = r[0]
	var failed: bool = r[1]
	var errors: int = r[2]
	if errors > 0:
		_finish(false, "%d engine error(s)" % errors)
	elif failed:
		_finish(false, "")  # the test already printed its own FAIL / FAILED lines
	elif not passed:
		_finish(false, "no PASS line")
	else:
		_finish(true, "")


## A test that calls quit() itself (as every pre-runner test did) would otherwise exit with its
## own code and skip the PASS, failure and error checks.
func _exit_tree() -> void:
	_finish(false, "the test quit on its own; the runner sets the exit code")


## Both the watchdog and a late completion can arrive; only the first one counts.
func _finish(ok: bool, why: String) -> void:
	if _done:
		return
	_done = true
	if why != "":
		print("FAILED (runner: %s)" % why)
	OS.remove_logger(_capture)
	get_tree().quit(0 if ok else 1)
