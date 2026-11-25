extends Node
## The migration scaffold (AR37, Story 1.21 AC2, D10): `Migrations.migrate()` runs the steps from a
## file's version up to the build's, in order, on a copy. Pure: fresh dictionaries, no Game, no
## files (the same steps through `SaveStore.read_slot()` are test_saves').
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_migrations.gd
## The steps here are fakes. The last case holds the real table to its rule: one step for every
## version below VERSION, so from E4 a version bump with no step fails here.

var _fail := 0
var _ran: Array[String] = []


func run() -> void:
	_test_two_steps_in_order()
	_test_missing_step()
	_test_step_that_does_not_bump()
	_test_already_current()
	_test_json_numbers()
	_test_real_table()
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


## v1 → v2: renames slot.best to slot.best_chain, the kind of change a real step makes.
func _v1_to_v2(d: Dictionary) -> void:
	_ran.append("1>2")
	d.slot["best_chain"] = d.slot["best"]
	d.slot.erase("best")
	d["version"] = 2


## v2 → v3: moves a value from the dive into the slot (a step may change any part, D10). It reads
## the key v1 → v2 made, so it fails if the steps ran out of order.
## The model a real step is copied from, so it tests `dive` and `meta` before it reads them (1.21
## review): a slot that never rested has "dive": null, and meta may be missing.
func _v2_to_v3(d: Dictionary) -> void:
	_ran.append("2>3")
	var carried := 0
	if d.get("dive") is Dictionary:
		carried = d.dive.get("carried", 0)
		d.dive.erase("carried")
	d.slot["banked"] = carried + d.slot["best_chain"]
	if d.get("meta") is Dictionary:
		d.meta["note"] = "v3"
	d["version"] = 3


func _v1_file() -> Dictionary:
	return {"version": 1, "meta": {"depth": 2}, "slot": {"best": 9, "flags": ["met_glim"]}, "dive": {"carried": 5}}


func _test_two_steps_in_order() -> void:
	_ran.clear()
	var src := _v1_file()
	var out := Migrations.migrate(src, 3, {1: _v1_to_v2, 2: _v2_to_v3})
	check(_ran == ["1>2", "2>3"], "v1 → v3 runs both steps, in order (ran %s)" % [_ran])
	var want := {"version": 3, "meta": {"depth": 2, "note": "v3"}, "slot": {"best_chain": 9, "banked": 14, "flags": ["met_glim"]}, "dive": {}}
	check(out == want, "...and gives version 3 with both changes applied, across slot, dive and meta (got %s)" % [out])
	check(src == _v1_file(), "...and the source dictionary is untouched: the steps worked on a deep copy (got %s)" % [src])
	(out.slot.flags as Array).append("x")
	check(src.slot.flags == ["met_glim"], "...deep: a nested array in the result is not the source's")
	_ran.clear()
	var one := Migrations.migrate(src, 2, {1: _v1_to_v2, 2: _v2_to_v3})
	check(_ran == ["1>2"] and one.get("version") == 2 and one.slot == {"best_chain": 9, "flags": ["met_glim"]}, "v1 → v2 runs only the first step, even with a later one in the table (ran %s)" % [_ran])
	# A slot that never rested: "dive": null and, here, no meta at all. The steps must still run.
	_ran.clear()
	var bare := Migrations.migrate({"version": 1, "slot": {"best": 9}, "dive": null}, 3, {1: _v1_to_v2, 2: _v2_to_v3})
	check(_ran == ["1>2", "2>3"] and bare == {"version": 3, "slot": {"best_chain": 9, "banked": 9}, "dive": null}, "a file with \"dive\": null and no meta migrates too: both steps run and neither part is invented (got %s)" % [bare])


func _test_missing_step() -> void:
	_ran.clear()
	var out := Migrations.migrate(_v1_file(), 3, {1: _v1_to_v2})
	check(out == {}, "v1 → v3 with no v2 step gives {} (got %s)" % [out])
	_ran.clear()
	out = Migrations.migrate(_v1_file(), 3, {2: _v2_to_v3})
	check(out == {} and _ran == [], "...and with no v1 step too, running nothing (got %s, ran %s)" % [out, _ran])
	check(Migrations.migrate(_v1_file(), 2, {}) == {}, "...and an empty table for an older file gives {}")


func _test_step_that_does_not_bump() -> void:
	var stuck := func(d: Dictionary) -> void: d.slot["touched"] = true
	check(Migrations.migrate(_v1_file(), 2, {1: stuck}) == {}, "a step that leaves the version where it was gives {}")
	var jumps := func(d: Dictionary) -> void: d["version"] = 3
	check(Migrations.migrate(_v1_file(), 3, {1: jumps}) == {}, "...so does one that skips a version (1 → 3)")
	var texty := func(d: Dictionary) -> void: d["version"] = "2"
	check(Migrations.migrate(_v1_file(), 2, {1: texty}) == {}, "...and one that writes the version as text, with no script error")
	var drops := func(d: Dictionary) -> void: d.erase("version")
	check(Migrations.migrate(_v1_file(), 2, {1: drops}) == {}, "...and one that drops the version")


func _test_already_current() -> void:
	_ran.clear()
	var src := _v1_file()
	var out := Migrations.migrate(src, 1, {1: _v1_to_v2})
	check(out == src and _ran == [], "a file already at the target version comes back unchanged, no step run (got %s)" % [out])
	check(not is_same(out, src), "...as a copy, not the caller's dictionary")
	var real := Migrations.migrate(src)
	check(real == src, "migrate(data) with the defaults: a version-%d file is current, unchanged" % Migrations.VERSION)


## What SaveStore hands over is parsed JSON: every number a float. A table keyed by ints must
## still find its steps ({1: f}.has(1.0) is false).
func _test_json_numbers() -> void:
	check(not {1: true}.has(1.0), "(premise, probed on 4.7.2: an int key is not found by the float a JSON parse gives)")
	var j := JSON.new()
	var err := j.parse(JSON.stringify(_v1_file()))
	var parsed: Dictionary = j.get_data() if err == OK else {}
	check(typeof(parsed.get("version")) == TYPE_FLOAT, "(a parsed file's version is a float)")
	_ran.clear()
	var out := Migrations.migrate(parsed, 3, {1: _v1_to_v2, 2: _v2_to_v3})
	check(_ran == ["1>2", "2>3"] and out.get("version") == 3, "a file parsed from JSON (version 1.0) still finds the int-keyed steps (ran %s)" % [_ran])


## The real table. Holds trivially while VERSION is 1; from Story 4.1 it fails a bump with no step.
func _test_real_table() -> void:
	var keys := Migrations.steps().keys()
	keys.sort()
	var want := range(1, Migrations.VERSION)
	check(keys == want, "steps() has exactly one step per version below VERSION %d: keys %s (got %s)" % [Migrations.VERSION, [want], [keys]])
	check(keys.all(func(k: Variant) -> bool: return typeof(k) == TYPE_INT), "...keyed by ints")
	check(Migrations.steps().values().all(func(s: Variant) -> bool: return s is Callable and (s as Callable).is_valid()), "...each a valid Callable")
	check(Migrations.VERSION >= 1 and typeof(Migrations.VERSION) == TYPE_INT, "VERSION is a whole number ≥ 1 (got %s)" % Migrations.VERSION)
