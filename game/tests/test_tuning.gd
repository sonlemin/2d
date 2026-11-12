extends Node
## Tuning (AR15) and Gear (AR16): the API, the fixed set → add → mul order, and rules/ purity.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_tuning.gd
## Each API case builds a fresh Tuning; only the Game case reads Game.tuning.
## Not tested here, because a failed assert aborts the test: the unknown-key, unknown-flag,
## malformed-row and double-set asserts. Code review checks them, as with Log's category assert.

const STAT := &"cling_slide"
## Fixture gear while Gear.TABLE is empty (E5): one modifier per id on STAT, plus a rule flag.
const FIXTURE: Array[Dictionary] = [
	{id = &"g_set", stat = STAT, op = &"set", value = 1.0},
	{id = &"g_add", stat = STAT, op = &"add", value = 2.0},
	{id = &"g_mul", stat = STAT, op = &"mul", value = 3.0},
	{id = &"g_flag", stat = &"instant_snuff", op = &"flag", value = true},
]
const PURE := ["res://scripts/rules/tuning.gd", "res://scripts/rules/gear.gd"]

var _fail := 0


func run() -> void:
	_test_base()
	_test_order()
	_test_other_stats_untouched()
	_test_unknown_gear_ignored()
	_test_flags()
	_test_changed_once()
	_test_reset_in_place()
	_test_gear_table_empty()
	_test_game_holds_tuning()
	_test_purity()
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func _ids(list: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(list)
	return out


## Keys whose value differs from BASE, for "nothing else moved" checks.
func _moved(t: Tuning) -> Array:
	return Tuning.BASE.keys().filter(func(k: StringName) -> bool: return t.f(k) != Tuning.BASE[k])


func _test_base() -> void:
	check(Tuning.BASE.size() == 34, "BASE has the 34 keys from the M1 exports (got %d)" % Tuning.BASE.size())
	var t := Tuning.new()
	check(_moved(t).is_empty(), "a fresh Tuning returns every BASE value (moved: %s)" % [_moved(t)])


## AR16: set → add → mul whatever order the gear comes in. Any other order gives 3, 5 or 7.
func _test_order() -> void:
	var perms := [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
	for p: Array in perms:
		var ids: Array[StringName] = []
		var table: Array[Dictionary] = []
		for i: int in p:
			ids.append(FIXTURE[i].id)
			table.append(FIXTURE[i])  # the table order changes too, not just the owned ids
		var t := Tuning.new()
		t.apply_gear(ids, table)
		check(is_equal_approx(t.f(STAT), 9.0), "set 1, add 2, mul 3 in order %s gives (1 + 2) x 3 = 9 (got %s)" % [ids, t.f(STAT)])


func _test_other_stats_untouched() -> void:
	var t := Tuning.new()
	t.apply_gear(_ids([&"g_set", &"g_add", &"g_mul"]), FIXTURE)
	check(_moved(t) == [STAT], "modifiers on %s leave every other key at base (moved: %s)" % [STAT, _moved(t)])


## D5: an id the table doesn't know (an old save, a typo) changes nothing.
func _test_unknown_gear_ignored() -> void:
	var t := Tuning.new()
	t.apply_gear(_ids([&"no_such_gear"]), FIXTURE)
	check(_moved(t).is_empty() and not t.flag(&"instant_snuff"), "unknown gear ids change nothing")


func _test_flags() -> void:
	var t := Tuning.new()
	check(not t.flag(&"instant_snuff"), "instant_snuff is off by default")
	t.apply_gear(_ids([&"g_flag"]), FIXTURE)
	check(t.flag(&"instant_snuff"), "...on with a flag modifier")
	check(_moved(t).is_empty(), "...and a flag moves no value")
	t.apply_gear([])
	check(not t.flag(&"instant_snuff"), "...and off again after apply_gear([])")


func _test_changed_once() -> void:
	var t := Tuning.new()
	var n := [0]
	t.changed.connect(func() -> void: n[0] += 1)
	t.apply_gear(_ids([&"g_set", &"g_add", &"g_mul", &"g_flag"]), FIXTURE)
	check(n[0] == 1, "apply_gear emits changed exactly once, however many modifiers apply (got %d)" % n[0])
	t.apply_gear([])
	check(n[0] == 2, "...and once per call (got %d)" % n[0])


## D6: Game keeps one instance all session, so apply_gear([]) must restore it in place.
func _test_reset_in_place() -> void:
	var t := Tuning.new()
	t.apply_gear(_ids([&"g_set", &"g_add", &"g_mul", &"g_flag"]), FIXTURE)
	t.apply_gear([])
	check(_moved(t).is_empty() and not t.flag(&"instant_snuff"), "apply_gear([]) restores every base value on the same instance")


func _test_gear_table_empty() -> void:
	check(Gear.TABLE.is_empty(), "Gear.TABLE is empty until E5")


## AR11: Game holds the session's one Tuning; this reads it, never replaces it.
func _test_game_holds_tuning() -> void:
	check(Game.tuning is Tuning, "Game.tuning is a Tuning")
	check(Game.tuning.f(&"cling_grace") == 1.0, "...holding the base values (cling_grace 1.0, got %s)" % Game.tuning.f(&"cling_grace"))


## AR58: rules/ never mentions the scene tree, raw input, the engine or the autoload. An
## unreadable file must fail, never pass as "no match" (Story 1.1 review).
func _test_purity() -> void:
	var re := RegEx.create_from_string("\\b(Node|Input|Engine)\\b|\\bGame\\.")
	for path: String in PURE:
		var src := FileAccess.get_file_as_string(path)
		var err := FileAccess.get_open_error()
		check(err == OK and src != "", "%s is readable (error %d)" % [path, err])
		var hit := re.search(src)
		check(hit == null, "%s mentions no Node, Input, Engine or Game. (found: %s)" % [path, hit.get_string() if hit else ""])
