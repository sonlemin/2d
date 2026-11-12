extends Node
## Pure checks for the static Log (AR55).
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_log.gd
## The unknown-category assert is not tested here: a failed assert aborts the test. Code review checks it.

var _fail := 0


func run() -> void:
	_test_format()
	_test_categories()
	_test_enabled()
	Log.set_enabled([])  # static state outlives this test: leave it as found
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func _test_format() -> void:
	check(Log.format(Log.CLOCK, "msg") == "[clock] msg", "format gives [clock] msg (got %s)" % Log.format(Log.CLOCK, "msg"))


func _test_categories() -> void:
	var want: Array[StringName] = [&"save", &"room", &"input", &"clock", &"lurker", &"weaver", &"audio", &"ui"]
	check(Log.CATEGORIES == want, "the categories are SAVE ROOM INPUT CLOCK LURKER WEAVER AUDIO UI, lowercase")
	for cat in Log.CATEGORIES:
		Log.enabled(cat)  # asserts on an unknown category, which the runner would count as an error
		Log.format(cat, "")
	check(true, "every listed category is accepted")
	Log.info(Log.CLOCK, "test_log: an info line")  # visible in the raw output; must not error


func _test_enabled() -> void:
	Log.set_enabled([])
	check(not Log.enabled(Log.CLOCK), "debug categories are off by default")
	Log.set_enabled([Log.CLOCK])
	check(Log.enabled(Log.CLOCK), "set_enabled([CLOCK]) turns CLOCK on")
	check(not Log.enabled(Log.LURKER), "...and only CLOCK")
	Log.set_enabled([])
	check(not Log.enabled(Log.CLOCK), "set_enabled([]) turns it off again")
