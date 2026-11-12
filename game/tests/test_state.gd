extends Node
## The session state objects (AR10, AR14, AR18): Settings, SlotState and DiveState. Their API, the
## signal rules (Story 1.4 D2), the fallbacks on bad data (D3), the to_dict() shapes (D4), the
## round trips in memory and through JSON, and rules/ purity.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_state.gd
## Each pure case builds fresh state objects.
## Not tested here, because a failed assert aborts the test: the unknown-key, bad-value,
## unknown-tier and negative-carried asserts. Code review checks them, as with Tuning's asserts.

const PURE := [
	"res://scripts/rules/settings.gd",
	"res://scripts/rules/slot_state.gd",
	"res://scripts/rules/dive_state.gd",
]

var _fail := 0


func run() -> void:
	_test_settings_defaults()
	_test_settings_set_value()
	_test_settings_reset()
	_test_settings_round_trips()
	_test_settings_fallbacks()
	_test_slot_defaults()
	_test_slot_flags()
	_test_slot_records()
	_test_slot_difficulty()
	_test_slot_round_trips()
	_test_slot_flags_sorted()
	_test_slot_fallbacks()
	_test_slot_load_signals()
	_test_dive_carried()
	_test_dive_killed()
	_test_dive_reset()
	_test_dive_round_trips()
	_test_dive_fallbacks()
	_test_purity()
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


## What a save file gives back: JSON.stringify, then the silent parser (R15).
func _through_json(d: Dictionary) -> Dictionary:
	var j := JSON.new()
	var err := j.parse(JSON.stringify(d, "\t"))
	check(err == OK and j.get_data() is Dictionary, "the dict survives JSON (error %d)" % err)
	return j.get_data() if j.get_data() is Dictionary else {}


# --- Settings ---

func _test_settings_defaults() -> void:
	var s := Settings.new()
	check(s.brightness == 1, "Settings: brightness defaults to 1, the M1 level (got %s)" % s.brightness)
	check(s.to_dict() == {&"brightness": 1}, "...and to_dict() is {brightness: 1} (got %s)" % s.to_dict())


func _test_settings_set_value() -> void:
	var s := Settings.new()
	var got := []
	s.changed.connect(func(key: StringName) -> void: got.append(key))
	s.set_value(&"brightness", 3)
	check(s.brightness == 3 and got == [&"brightness"], "set_value(brightness, 3) sets it and emits changed(brightness) once (got %s, %s)" % [s.brightness, got])
	s.set_value(&"brightness", 3)
	check(got.size() == 1, "...and the same value again emits nothing (D2; %d emits)" % got.size())


func _test_settings_reset() -> void:
	var s := Settings.new()
	s.set_value(&"brightness", 0)
	var got := []
	s.changed.connect(func(key: StringName) -> void: got.append(key))
	s.reset()
	check(s.brightness == 1 and got == [&"brightness"], "reset() restores brightness 1 in place and emits changed (D2; got %s, %s)" % [s.brightness, got])


func _test_settings_round_trips() -> void:
	var s := Settings.new()
	s.set_value(&"brightness", 2)
	var t := Settings.new()
	check(t.from_dict(s.to_dict()) and t.brightness == 2, "from_dict(to_dict()) is clean and keeps brightness 2 (got %s)" % t.brightness)
	var u := Settings.new()
	var clean := u.from_dict(_through_json(s.to_dict()))
	check(clean and u.brightness == 2 and typeof(u.brightness) == TYPE_INT, "...through JSON too, as an int (D3: JSON numbers come back as floats; got %s, type %d)" % [u.brightness, typeof(u.brightness)])
	var v := Settings.new()
	check(v.from_dict({"brightness": 3, "unknown_key": true}) and v.brightness == 3, "an unknown key is ignored and the data is still clean (D3)")
	var got := []
	v.changed.connect(func(key: StringName) -> void: got.append(key))
	v.from_dict({"brightness": 3})
	check(got == [&"brightness"], "from_dict() emits changed for every key, changed or not (D2; got %s)" % [got])


func _test_settings_fallbacks() -> void:
	for bad: Dictionary in [{}, {"brightness": "bright"}, {"brightness": 7}, {"brightness": 2.5}, {"brightness": true}]:
		var s := Settings.new()
		s.set_value(&"brightness", 3)
		var clean := s.from_dict(bad)
		check(not clean and s.brightness == 1, "from_dict(%s) is unclean and falls back to brightness 1 (D3; got %s)" % [bad, s.brightness])


# --- SlotState ---

func _test_slot_defaults() -> void:
	var s := SlotState.new()
	check(s.best_chain == 0 and s.deaths == 0 and s.difficulty == &"normal", "SlotState: records 0 / 0 and difficulty normal by default (got %d / %d / %s)" % [s.best_chain, s.deaths, s.difficulty])
	check(s.to_dict().flags == [] and not s.has_flag(&"anchor_m1_1"), "...and no flags")
	check(SlotState.DIFFICULTIES == [&"easy", &"normal", &"hard"], "the difficulty ids are easy, normal, hard (D8)")


func _test_slot_flags() -> void:
	var s := SlotState.new()
	var got := []
	s.flag_set.connect(func(id: StringName, value: bool) -> void: got.append([id, value]))
	s.set_flag(&"anchor_m1_1")
	check(s.has_flag(&"anchor_m1_1") and got == [[&"anchor_m1_1", true]], "set_flag(id) sets it and emits flag_set(id, true) once (got %s)" % [got])
	s.set_flag(&"anchor_m1_1")
	check(got.size() == 1, "...and setting it again emits nothing (D2)")
	s.set_flag(&"anchor_m1_1", false)
	check(not s.has_flag(&"anchor_m1_1") and got.size() == 2 and got[1] == [&"anchor_m1_1", false], "set_flag(id, false) clears it and emits flag_set(id, false) (got %s)" % [got])
	s.set_flag(&"anchor_m1_1", false)
	check(got.size() == 2, "...and clearing a clear flag emits nothing")


func _test_slot_records() -> void:
	var s := SlotState.new()
	var n := [0]
	s.records_changed.connect(func() -> void: n[0] += 1)
	s.record_chain(5)
	check(s.best_chain == 5 and n[0] == 1, "record_chain(5) raises the best and emits records_changed once (got %d, %d emits)" % [s.best_chain, n[0]])
	s.record_chain(3)
	s.record_chain(5)
	check(s.best_chain == 5 and n[0] == 1, "...and a chain at or below the best emits nothing (got %d, %d emits)" % [s.best_chain, n[0]])
	s.record_death()
	s.record_death()
	check(s.deaths == 2 and n[0] == 3, "record_death() twice gives 2 deaths, one emit each (got %d, %d emits)" % [s.deaths, n[0]])


func _test_slot_difficulty() -> void:
	var s := SlotState.new()
	var got := []
	s.difficulty_changed.connect(func(tier: StringName) -> void: got.append(tier))
	s.set_difficulty(&"hard")
	check(s.difficulty == &"hard" and got == [&"hard"], "set_difficulty(hard) sets it and emits once (got %s)" % [got])
	s.set_difficulty(&"hard")
	check(got.size() == 1, "...and the same tier again emits nothing (D2)")


func _filled_slot() -> SlotState:
	var s := SlotState.new()
	s.record_chain(12)
	s.record_death()
	s.record_death()
	s.record_death()
	s.set_difficulty(&"easy")
	s.set_flag(&"anchor_m1_1")
	s.set_flag(&"met_glim")
	return s


func _same_slot(a: SlotState, b: SlotState) -> bool:
	return a.best_chain == b.best_chain and a.deaths == b.deaths and a.difficulty == b.difficulty \
			and a.to_dict().flags == b.to_dict().flags


func _test_slot_round_trips() -> void:
	var s := _filled_slot()
	var t := SlotState.new()
	check(t.from_dict(s.to_dict()) and _same_slot(s, t), "SlotState from_dict(to_dict()) is clean and keeps records, difficulty and flags (got %s)" % t.to_dict())
	var u := SlotState.new()
	var clean := u.from_dict(_through_json(s.to_dict()))
	check(clean and _same_slot(s, u), "...through JSON too (got %s)" % u.to_dict())
	check(typeof(u.best_chain) == TYPE_INT and typeof(u.deaths) == TYPE_INT, "...with int records (types %d / %d)" % [typeof(u.best_chain), typeof(u.deaths)])
	check(typeof(u.difficulty) == TYPE_STRING_NAME and u.has_flag(&"anchor_m1_1") and u.has_flag(&"met_glim"), "...a StringName difficulty, and flags that still answer has_flag()")
	var keys := s.to_dict().keys()
	keys.sort()
	check(keys == ["best_chain", "deaths", "difficulty", "flags"], "to_dict() has exactly best_chain, deaths, difficulty, flags (D4; got %s)" % [keys])


## D4: StringName sort order is not alphabetical, so the save sorts flag ids as Strings.
func _test_slot_flags_sorted() -> void:
	var s := SlotState.new()
	for id: StringName in [&"zeta", &"mid", &"anchor_m1_1", &"beta"]:
		s.set_flag(id)
	var flags: Array = s.to_dict().flags
	check(flags == ["anchor_m1_1", "beta", "mid", "zeta"], "to_dict().flags lists the set ids sorted as strings (got %s)" % [flags])
	check(flags.all(func(f: Variant) -> bool: return f is String), "...as Strings, ready for JSON")


func _test_slot_fallbacks() -> void:
	var cases := [
		[{"best_chain": 4, "deaths": 2, "difficulty": "medium", "flags": []}, "an unknown difficulty", "difficulty"],
		[{"best_chain": -1, "deaths": 2, "difficulty": "hard", "flags": []}, "a negative record", "best_chain"],
		[{"best_chain": 4, "deaths": "x", "difficulty": "hard", "flags": []}, "a record that isn't a number", "deaths"],
		[{"best_chain": 4.5, "deaths": 2, "difficulty": "hard", "flags": []}, "a fractional record", "best_chain"],
		[{"best_chain": 4, "deaths": 2, "difficulty": "hard", "flags": "anchor_m1_1"}, "flags that aren't an array", "flags"],
	]
	var want := {"best_chain": 0, "deaths": 0, "difficulty": &"normal", "flags": []}
	for c: Array in cases:
		var s := _filled_slot()
		var clean := s.from_dict(c[0])
		var got: Variant = s.to_dict()[c[2]] if c[2] != "difficulty" else s.difficulty
		check(not clean and got == want[c[2]], "SlotState: %s is unclean and gives the default %s (D3; got %s)" % [c[1], c[2], got])
	var s := SlotState.new()
	var clean := s.from_dict({"best_chain": 4, "deaths": 2, "difficulty": "hard", "flags": ["met_glim", 7, null]})
	check(not clean and s.to_dict().flags == ["met_glim"], "a non-string flag entry is skipped and makes the data unclean (got %s)" % [s.to_dict().flags])
	check(s.best_chain == 4 and s.deaths == 2 and s.difficulty == &"hard", "...while the good fields still load")
	var e := SlotState.new()
	check(not e.from_dict({}) and _same_slot(e, SlotState.new()), "from_dict({}) is unclean and gives the defaults")


## D2: reset() and from_dict() emit every value signal once; flag_set fires only per changed id.
func _test_slot_load_signals() -> void:
	var s := _filled_slot()
	var flags := []
	var n := {records = 0, tier = 0}
	s.flag_set.connect(func(id: StringName, value: bool) -> void: flags.append([id, value]))
	s.records_changed.connect(func() -> void: n.records += 1)
	s.difficulty_changed.connect(func(_tier: StringName) -> void: n.tier += 1)
	s.reset()
	flags.sort_custom(func(a: Array, b: Array) -> bool: return String(a[0]) < String(b[0]))
	check(flags == [[&"anchor_m1_1", false], [&"met_glim", false]], "reset() emits flag_set(id, false) for each flag it clears (got %s)" % [flags])
	check(n.records == 1 and n.tier == 1, "...and records_changed and difficulty_changed once each (got %d / %d)" % [n.records, n.tier])
	check(_same_slot(s, SlotState.new()), "...leaving the defaults on the same instance")
	s.set_flag(&"met_glim")
	flags.clear()
	n.records = 0
	n.tier = 0
	s.from_dict({"best_chain": 0, "deaths": 0, "difficulty": "normal", "flags": ["anchor_m1_1", "met_glim"]})
	check(flags == [[&"anchor_m1_1", true]], "from_dict() emits flag_set(id, true) for each new flag, nothing for one it keeps (got %s)" % [flags])
	check(n.records == 1 and n.tier == 1, "...and records_changed and difficulty_changed once each, even unchanged (got %d / %d)" % [n.records, n.tier])


# --- DiveState ---

func _test_dive_carried() -> void:
	var d := DiveState.new()
	var got := []
	d.carried_changed.connect(func(c: int) -> void: got.append(c))
	check(d.carried == 0, "DiveState: carried starts at 0")
	d.add_carried(5)
	check(d.carried == 5 and got == [5], "add_carried(5) gives 5 and emits carried_changed(5) (got %d, %s)" % [d.carried, got])
	d.add_carried(0)
	check(got.size() == 1, "...add_carried(0) emits nothing (D2)")
	d.add_carried(3)
	check(d.carried == 8 and got == [5, 8], "...add_carried(3) emits 8 (got %s)" % [got])


func _test_dive_killed() -> void:
	var d := DiveState.new()
	var got := []
	d.killed_marked.connect(func(room: StringName, cell: Vector2i) -> void: got.append([room, cell]))
	d.mark_killed(&"m1_shaft", Vector2i(3, 4))
	check(d.is_killed(&"m1_shaft", Vector2i(3, 4)), "mark_killed(m1_shaft, (3, 4)) makes is_killed() true for that cell")
	check(not d.is_killed(&"other_room", Vector2i(3, 4)), "...false for the same cell in another room")
	check(not d.is_killed(&"m1_shaft", Vector2i(4, 3)), "...and false for another cell in the room")
	check(got == [[&"m1_shaft", Vector2i(3, 4)]], "...and killed_marked fires once (got %s)" % [got])
	d.mark_killed(&"m1_shaft", Vector2i(3, 4))
	check(got.size() == 1, "marking the same cell again emits nothing (D2)")


func _filled_dive() -> DiveState:
	var d := DiveState.new()
	d.add_carried(7)
	d.set_respawn(&"m1_shaft", &"anchor_m1_1")
	d.mark_killed(&"m1_shaft", Vector2i(3, 4))
	return d


func _test_dive_reset() -> void:
	var d := _filled_dive()
	var carried := []
	var respawn := []
	d.carried_changed.connect(func(c: int) -> void: carried.append(c))
	d.respawn_changed.connect(func(room: StringName, entry: StringName) -> void: respawn.append([room, entry]))
	d.reset()
	check(d.carried == 0 and d.respawn_room == &"" and d.respawn_entry == &"", "reset() clears carried and the respawn point in place")
	check(not d.is_killed(&"m1_shaft", Vector2i(3, 4)), "...and the killed enemies")
	check(carried == [0] and respawn == [[&"", &""]], "...emitting carried_changed(0) and respawn_changed (D2; got %s, %s)" % [carried, respawn])


func _test_dive_round_trips() -> void:
	var d := _filled_dive()
	var keys := d.to_dict().keys()
	keys.sort()
	check(keys == ["carried", "respawn_entry", "respawn_room"], "to_dict() is carried + the respawn point, no killed enemies (D4, decision 5; got %s)" % [keys])
	var respawn := []
	var e := _filled_dive()
	e.mark_killed(&"m1_shaft", Vector2i(9, 9))
	e.respawn_changed.connect(func(room: StringName, entry: StringName) -> void: respawn.append([room, entry]))
	var clean := e.from_dict(d.to_dict())
	check(clean and e.carried == 7 and e.respawn_room == &"m1_shaft" and e.respawn_entry == &"anchor_m1_1", "from_dict(to_dict()) is clean and keeps carried and the respawn point")
	check(not e.is_killed(&"m1_shaft", Vector2i(3, 4)) and not e.is_killed(&"m1_shaft", Vector2i(9, 9)), "...and clears the killed enemies (they are never saved)")
	check(respawn == [[&"m1_shaft", &"anchor_m1_1"]], "...and emits respawn_changed even unchanged (D2; got %s)" % [respawn])
	var f := _filled_dive()
	clean = f.from_dict(_through_json(d.to_dict()))
	check(clean and f.carried == 7 and typeof(f.carried) == TYPE_INT, "...through JSON too, carried as an int (got %s, type %d)" % [f.carried, typeof(f.carried)])
	check(typeof(f.respawn_room) == TYPE_STRING_NAME and f.respawn_room == &"m1_shaft" and f.respawn_entry == &"anchor_m1_1", "...and the respawn point as StringNames")
	check(not f.is_killed(&"m1_shaft", Vector2i(3, 4)), "...with no killed enemies")


func _test_dive_fallbacks() -> void:
	for bad: Variant in [-3, 2.5, "7", null]:
		var d := _filled_dive()
		var clean := d.from_dict({"carried": bad, "respawn_room": "m1_shaft", "respawn_entry": "anchor_m1_1"})
		check(not clean and d.carried == 0 and d.respawn_room == &"m1_shaft", "DiveState: carried %s is unclean and gives 0, the other fields still load (D3; got %s)" % [var_to_str(bad), d.carried])
	var d := _filled_dive()
	check(not d.from_dict({"carried": 4, "respawn_room": 12, "respawn_entry": "anchor_m1_1"}) and d.respawn_room == &"" and d.carried == 4, "a respawn room that isn't a string is unclean and gives none")


# --- rules/ purity ---

## AR58 + R15: rules/ never mentions the scene tree, raw input, the engine or the autoload, and
## does no file I/O. The scan covers comments too. An unreadable file must fail, never pass.
func _test_purity() -> void:
	var re := RegEx.create_from_string("\\b(Node|Input|Engine)\\b|\\bGame\\.|FileAccess|DirAccess")
	for path: String in PURE:
		var src := FileAccess.get_file_as_string(path)
		var err := FileAccess.get_open_error()
		check(err == OK and src != "", "%s is readable (error %d)" % [path, err])
		var hit := re.search(src)
		check(hit == null, "%s mentions no Node, Input, Engine, Game. or file access (found: %s)" % [path, hit.get_string() if hit else ""])
