extends Node
## The session state objects (AR10, AR14, AR18): Settings, SlotState and DiveState. Their API, the
## signal rules (Story 1.4 D2), the fallbacks on bad data (D3), the to_dict() shapes (D4), the
## round trips in memory and through JSON (rules/ purity is test_lint's, Story 1.9). Then `Game` (AR11): the same
## instances all session, `reset_for_tests()`, and `settings.json` through `SaveStore` (R15).
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_state.gd
## Each pure case builds fresh state objects. Only the Game and file cases use Game, and they
## end with `Game.reset_for_tests()`. The file cases point `Game.store.dir` at TMP first and
## check at the end that the real user://settings.json is exactly as it was.
## Not tested here, because a failed assert aborts the test: the unknown-key, bad-value,
## unknown-tier and negative-carried asserts, and the Game ref guards (D7). Code review checks
## them, as with Tuning's asserts.

const TMP := "user://test_state_tmp"
const REAL := "user://settings.json"

var _fail := 0


## Counts SaveStore's "settings written" Log lines. Two writes in one frame leave the same file, so
## the count is the only way to see them (a mutant without the write guard passed every file
## check). Engine logging can arrive from any thread, hence the mutex, as in tests/runner.gd.
class WriteCounter extends Logger:
	var _lock := Mutex.new()
	var _line := Log.format(Log.SAVE, "settings written")
	var _count := 0

	func _log_message(message: String, _error: bool) -> void:
		_lock.lock()
		_count += message.split("\n", false).count(_line)
		_lock.unlock()

	func total() -> int:
		_lock.lock()
		var n := _count
		_lock.unlock()
		return n


## Counts the push_warning calls of SaveStore and of Game's settings write, so "one warning" is
## checked and not only promised (1.4 review). Other warnings don't count. A push_warning's text
## arrives as `code` (probed on 4.7.2).
class WarningCounter extends Logger:
	var _lock := Mutex.new()
	var _count := 0

	func _log_error(_function: String, _file: String, _line: int, code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			return
		if not (code.begins_with("SaveStore:") or code.begins_with("Game: settings")):
			return
		_lock.lock()
		_count += 1
		_lock.unlock()

	## How many arrived since the last take().
	func take() -> int:
		_lock.lock()
		var n := _count
		_count = 0
		_lock.unlock()
		return n


func run() -> void:
	_test_settings_defaults()
	_test_settings_schema()
	_test_settings_set_value()
	_test_settings_reset()
	_test_settings_round_trips()
	_test_settings_fallbacks()
	_test_settings_is_valid()
	_test_slot_defaults()
	_test_slot_flags()
	_test_slot_records()
	_test_slot_difficulty()
	_test_slot_round_trips()
	_test_slot_flags_sorted()
	_test_slot_visits()
	_test_slot_play_time()
	_test_slot_depth()
	_test_slot_resume()
	_test_slot_meta()
	_test_slot_fallbacks()
	_test_slot_load_signals()
	_test_slot_handler_sets_a_flag()
	_test_dive_carried()
	_test_dive_killed()
	_test_dive_reset()
	_test_dive_round_trips()
	_test_dive_fallbacks()
	_test_game_holds_state()
	_test_game_same_instances()
	_test_game_reset_for_tests()
	await _test_settings_file()
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
	check(s.light_tap_window == 0.12 and typeof(s.light_tap_window) == TYPE_FLOAT, "...and the Light tap window defaults to 0.12 s, M1's Snuff hold (Story 1.8 D5; got %s)" % s.light_tap_window)
	# Story 1.16 D2: the accessibility keys default to the full effects (UX Accessibility Floor, A11).
	check(not s.reduce_flashing and s.shake and not s.reduced_motion, "...and reduce flashing off, shake on, reduced motion off (Story 1.16 D2; got %s, %s, %s)" % [s.reduce_flashing, s.shake, s.reduced_motion])
	var want := {"brightness": 1, "light_tap_window": 0.12, "reduce_flashing": false, "shake": true, "reduced_motion": false}
	check(s.to_dict() == want, "...and to_dict() is %s (got %s)" % [want, s.to_dict()])
	# {&"k": 1} == {"k": 1} is true, so the comparison above can't tell the key type.
	check(s.to_dict().keys().all(func(k: Variant) -> bool: return k is String), "...with String keys, as SlotState and DiveState give (D4)")


## Each story adds its key as one SCHEMA entry plus a typed var of the same name. Nothing but this
## holds the two together: a key with no var would write null and be rewritten on every launch.
func _test_settings_schema() -> void:
	var s := Settings.new()
	for key: StringName in Settings.SCHEMA:
		var spec: Dictionary = Settings.SCHEMA[key]
		check(key in s and typeof(s.get(key)) == typeof(spec.default) and s.get(key) == spec.default, "SCHEMA '%s' has a var of that name holding its default, same type (got %s)" % [key, var_to_str(s.get(key))])
		check(spec.default in spec.choices, "...and its default %s is one of its choices %s" % [spec.default, spec.choices])
	check(s.to_dict().size() == Settings.SCHEMA.size(), "to_dict() has one entry per SCHEMA key")


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
	s.set_value(&"light_tap_window", 0.3)
	s.set_value(&"shake", false)
	s.reset()
	var keys: Array = Settings.SCHEMA.keys()
	check(s.brightness == 1 and s.light_tap_window == 0.12 and s.shake and got == [&"light_tap_window", &"shake"] + keys, "reset() restores brightness 1, the 0.12 s window and shake on in place and emits changed for every key (D2; got %s, %s, %s, %s)" % [s.brightness, s.light_tap_window, s.shake, got])
	got.clear()
	s.reset()
	check(got == keys, "...and a reset that changes nothing still emits (D2; got %s)" % [got])


func _test_settings_round_trips() -> void:
	var s := Settings.new()
	s.set_value(&"brightness", 2)
	var t := Settings.new()
	check(t.from_dict(s.to_dict()) and t.brightness == 2, "from_dict(to_dict()) is clean and keeps brightness 2 (got %s)" % t.brightness)
	var u := Settings.new()
	var clean := u.from_dict(_through_json(s.to_dict()))
	check(clean and u.brightness == 2 and typeof(u.brightness) == TYPE_INT, "...through JSON too, as an int (D3: JSON numbers come back as floats; got %s, type %d)" % [u.brightness, typeof(u.brightness)])
	var v := Settings.new()
	var full := Settings.new().to_dict()
	full["brightness"] = 3
	var extra := full.duplicate()
	extra["unknown_key"] = true
	check(v.from_dict(extra) and v.brightness == 3, "an unknown key is ignored and the data is still clean (D3)")
	var got := []
	v.changed.connect(func(key: StringName) -> void: got.append(key))
	v.from_dict(full)
	check(got == Settings.SCHEMA.keys(), "from_dict() emits changed for every key, changed or not (D2; got %s)" % [got])
	var old := Settings.new()
	check(not old.from_dict({"brightness": 3, "light_tap_window": 0.2}), "a file from before Story 1.16 (no accessibility keys) is unclean, so Game rewrites it with the defaults (no version bump)")
	check(old.brightness == 3 and is_equal_approx(old.light_tap_window, 0.2) and not old.reduce_flashing and old.shake and not old.reduced_motion,
			"...and it keeps what the player had set: brightness 3 and the 0.2 s tap window survive, the three new keys take their defaults (got %s)" % [old.to_dict()])
	# Story 1.16: each bool key round-trips through JSON as a bool, both ways.
	for key: StringName in [&"reduce_flashing", &"shake", &"reduced_motion"]:
		for b: bool in [false, true]:
			var a := Settings.new()
			a.set_value(key, b)
			var c := Settings.new()
			var ok := c.from_dict(_through_json(a.to_dict()))
			check(ok and c.get(key) == b and typeof(c.get(key)) == TYPE_BOOL, "%s %s survives JSON as a bool (got %s)" % [key, b, var_to_str(c.get(key))])
	check(not Settings.new().from_dict({"brightness": 3}), "a file from before Story 1.8 (no light_tap_window) is unclean, so Game rewrites it with the default")
	# Story 1.8 D5: a float setting survives JSON exactly, for every choice.
	for w: float in Settings.SCHEMA[&"light_tap_window"].choices:
		var a := Settings.new()
		a.set_value(&"light_tap_window", w)
		var b := Settings.new()
		var ok := b.from_dict(_through_json(a.to_dict()))
		check(ok and b.light_tap_window == w and typeof(b.light_tap_window) == TYPE_FLOAT, "light_tap_window %s survives JSON exactly, as a float (got %s)" % [w, b.light_tap_window])


func _test_settings_fallbacks() -> void:
	for bad: Dictionary in [{}, {"brightness": "bright"}, {"brightness": 7}, {"brightness": 2.5}, {"brightness": true}]:
		var s := Settings.new()
		s.set_value(&"brightness", 3)
		var clean := s.from_dict(bad)
		check(not clean and s.brightness == 1, "from_dict(%s) is unclean and falls back to brightness 1 (D3; got %s)" % [bad, s.brightness])
	# Story 1.8 D5: only the three windows; a whole JSON number is still a float, so 0 isn't 0.12.
	for bad: Variant in [0.15, "0.2", true, 12, 0, null]:
		var s := Settings.new()
		s.set_value(&"light_tap_window", 0.3)
		var clean := s.from_dict({"brightness": 1, "light_tap_window": bad})
		check(not clean and s.light_tap_window == 0.12, "light_tap_window %s is unclean and falls back to 0.12 (got %s)" % [var_to_str(bad), s.light_tap_window])
	# Story 1.16: a bool key takes only true or false; 1, "true" and null fall back to the default.
	for key: StringName in [&"reduce_flashing", &"shake", &"reduced_motion"]:
		var default: bool = Settings.SCHEMA[key].default
		for bad: Variant in [1, 0, "true", null]:
			var s := Settings.new()
			s.set_value(key, not default)
			var d := Settings.new().to_dict()
			d[String(key)] = bad
			var clean := s.from_dict(d)
			check(not clean and s.get(key) == default, "%s %s is unclean and falls back to %s (got %s)" % [key, var_to_str(bad), default, var_to_str(s.get(key))])


# --- SlotState ---

## Story 1.11 D8: the one validity rule, public so DevTools' --set validator can share it; a passed
## schema is only ever a test's or DevTools'. The fake bool key stays (Story 1.16 added real ones):
## it tests the passed-schema path, which the real keys can't.
func _test_settings_is_valid() -> void:
	check(Settings.is_valid(&"brightness", 1) and Settings.is_valid(&"light_tap_window", 0.12), "is_valid: the defaults are valid")
	check(not Settings.is_valid(&"brightness", 1.0) and not Settings.is_valid(&"brightness", true) and not Settings.is_valid(&"light_tap_window", 0),
			"is_valid: a type mismatch is false (1.0 and true for an int, 0 for a float)")
	check(not Settings.is_valid(&"brightness", 4) and not Settings.is_valid(&"light_tap_window", 0.25), "is_valid: a value outside the choices is false")
	check(not Settings.is_valid(&"nope", 1), "is_valid: an unknown key is false")
	check(Settings.is_valid(&"shake", false) and not Settings.is_valid(&"shake", 0) and not Settings.is_valid(&"reduce_flashing", "true"), "is_valid: a real bool key takes false, never 0 or \"true\" (Story 1.16)")
	var fake := Settings.SCHEMA.duplicate(true)
	fake[&"fake_bool"] = {default = false, choices = [false, true]}
	check(Settings.is_valid(&"fake_bool", true, fake) and Settings.is_valid(&"fake_bool", false, fake), "is_valid: with a passed schema, a key the real SCHEMA lacks is valid for its values")
	check(not Settings.is_valid(&"fake_bool", 1, fake), "is_valid: ...and false for the wrong type")
	check(not Settings.is_valid(&"fake_bool", true), "is_valid: ...and the same key without the schema argument is unknown")


func _test_slot_defaults() -> void:
	var s := SlotState.new()
	check(s.best_chain == 0 and s.deaths == 0 and s.difficulty == &"normal", "SlotState: records 0 / 0 and difficulty normal by default (got %d / %d / %s)" % [s.best_chain, s.deaths, s.difficulty])
	check(s.to_dict().flags == [] and not s.has_flag(&"anchor_m1_1"), "...and no flags")
	check(s.play_time == 0 and typeof(s.play_time) == TYPE_INT and s.depth == 0 and typeof(s.depth) == TYPE_INT, "...play time 0 s and depth 0, both ints (Story 1.21; got %s / %s)" % [var_to_str(s.play_time), var_to_str(s.depth)])
	check(s.resume_room == &"" and s.resume_entry == &"" and typeof(s.resume_room) == TYPE_STRING_NAME and typeof(s.resume_entry) == TYPE_STRING_NAME, "...and no resume point: two empty StringNames, the dive's start (1.21 D5)")
	check(SlotState.RESUME_KEYS == ["resume_room", "resume_entry", "cache"], "RESUME_KEYS is resume_room, resume_entry, cache: what a progress save must not move (R14, Story 1.22 D5; got %s)" % [SlotState.RESUME_KEYS])
	check(s.deposited == 0 and not s.has_cache() and s.cache_room == &"" and s.cache_amount == 0, "...no deposited embers and no Ember Cache (Story 1.22)")
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
	# Story 1.22: 15 deposited and a cache of 25, dropped on Normal before the tier changes.
	var dive := DiveState.new()
	dive.add_carried(15)
	s.deposit_from(dive)
	dive.add_carried(25)
	s.apply_death(dive, 0, &"m1_shaft", Vector2(40, 120))
	s.set_difficulty(&"easy")
	s.set_flag(&"anchor_m1_1")
	s.set_flag(&"met_glim")
	s.visit(&"m1_shaft")
	s.visit(&"a_side")
	s.add_play_time(8040.5)
	s.record_depth(4)
	s.set_resume(&"m1_shaft", &"anchor_m1_1")
	return s


func _same_slot(a: SlotState, b: SlotState) -> bool:
	return a.best_chain == b.best_chain and a.deaths == b.deaths and a.difficulty == b.difficulty \
			and a.to_dict().flags == b.to_dict().flags and a.to_dict().visited == b.to_dict().visited \
			and a.play_time == b.play_time and a.depth == b.depth \
			and a.resume_room == b.resume_room and a.resume_entry == b.resume_entry \
			and a.deposited == b.deposited and a.cache_room == b.cache_room and a.cache_pos == b.cache_pos \
			and a.cache_amount == b.cache_amount


## A whole, clean slot dictionary as a save file gives it, with `over` laid on top: each fallback
## case then has exactly one fault (a case missing other keys would be unclean whatever it tested).
func _slot_dict(over := {}) -> Dictionary:
	var d := {"best_chain": 4, "deaths": 2, "difficulty": "hard", "flags": [], "visited": [],
			"play_time": 90, "depth": 3, "resume_room": "m1_shaft", "resume_entry": "anchor_m1_1",
			"deposited": 0, "cache": null}
	d.merge(over, true)
	return d


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
	check(keys == ["best_chain", "cache", "deaths", "deposited", "depth", "difficulty", "flags", "play_time", "resume_entry", "resume_room", "visited"], "to_dict() has exactly best_chain, cache, deaths, deposited, depth, difficulty, flags, play_time, resume_entry, resume_room, visited (D4, 1.7 D7, Stories 1.21, 1.22; got %s)" % [keys])
	check(u.has_visited(&"m1_shaft") and u.has_visited(&"a_side"), "...and visited rooms that still answer has_visited()")
	# Story 1.21: the values written out, never read back from the object under test.
	check(u.play_time == 8040 and typeof(u.play_time) == TYPE_INT and u.depth == 4 and typeof(u.depth) == TYPE_INT, "...play time 8040 s and depth 4 back as ints (got %s / %s)" % [var_to_str(u.play_time), var_to_str(u.depth)])
	check(u.resume_room == &"m1_shaft" and u.resume_entry == &"anchor_m1_1" and typeof(u.resume_room) == TYPE_STRING_NAME and typeof(u.resume_entry) == TYPE_STRING_NAME, "...and the resume point m1_shaft / anchor_m1_1 as StringNames (got '%s' / '%s')" % [u.resume_room, u.resume_entry])
	var d := s.to_dict()
	check(typeof(d.play_time) == TYPE_INT and d.play_time == 8040 and typeof(d.resume_room) == TYPE_STRING and typeof(d.resume_entry) == TYPE_STRING, "to_dict() writes play_time as the whole seconds (8040 of 8040.5) and the resume point as Strings")
	# The half second is not saved: a loaded slot needs a whole second more, not half of one.
	var got := []
	u.play_time_changed.connect(func(t: int) -> void: got.append(t))
	u.add_play_time(0.75)
	check(u.play_time == 8040 and got == [], "the fraction of a second is not saved: 0.75 s after the load adds no second (8040.5 + 0.75 would; got %d)" % u.play_time)


## D4: StringName sort order is not alphabetical, so the save sorts flag ids as Strings.
func _test_slot_flags_sorted() -> void:
	var s := SlotState.new()
	for id: StringName in [&"zeta", &"mid", &"anchor_m1_1", &"beta"]:
		s.set_flag(id)
	var flags: Array = s.to_dict().flags
	check(flags == ["anchor_m1_1", "beta", "mid", "zeta"], "to_dict().flags lists the set ids sorted as strings (got %s)" % [flags])
	check(flags.all(func(f: Variant) -> bool: return f is String), "...as Strings, ready for JSON")


## Story 1.7 D7: World visits every room it enters; the map reads them (FR60).
func _test_slot_visits() -> void:
	var s := SlotState.new()
	var n := {v = 0}
	s.visits_changed.connect(func() -> void: n.v += 1)
	check(not s.has_visited(&"m1_shaft") and s.to_dict().visited == [], "SlotState: no room is visited by default")
	s.visit(&"m1_shaft")
	check(s.has_visited(&"m1_shaft") and n.v == 1, "visit(id) records it and emits visits_changed once (got %d)" % n.v)
	s.visit(&"m1_shaft")
	check(n.v == 1, "...and a repeat visit emits nothing")
	for id: StringName in [&"zeta", &"beta"]:
		s.visit(id)
	check(s.to_dict().visited == ["beta", "m1_shaft", "zeta"], "to_dict().visited lists the ids sorted as Strings (got %s)" % [s.to_dict().visited])
	var t := SlotState.new()
	check(SlotState.new().from_dict(_slot_dict()), "(control: the whole dictionary these fallback cases start from is clean)")
	var clean := t.from_dict(_slot_dict({"visited": ["m1_shaft", 3, ""]}))
	check(not clean and t.to_dict().visited == ["m1_shaft"], "a bad or empty visited entry is skipped and makes the data unclean (got %s)" % [t.to_dict().visited])
	var u := SlotState.new()
	var no_visits := _slot_dict()
	no_visits.erase("visited")
	check(not u.from_dict(no_visits) and u.to_dict().visited == [], "a missing visited list is unclean and loads none")
	n.v = 0
	s.reset()
	check(s.to_dict().visited == [] and n.v == 1, "reset() clears the visits and emits visits_changed once (got %d)" % n.v)


## Story 1.21 D8: whole seconds plus a private fraction, so the signal fires about once a second.
func _test_slot_play_time() -> void:
	var s := SlotState.new()
	var got := []
	s.play_time_changed.connect(func(t: int) -> void: got.append(t))
	for i in 3:
		s.add_play_time(0.25)
	check(s.play_time == 0 and got == [], "add_play_time(0.25) three times: no whole second yet, no emit (got %d, %s)" % [s.play_time, got])
	s.add_play_time(0.25)
	check(s.play_time == 1 and got == [1], "...the fourth makes one second and emits play_time_changed(1) once (got %d, %s)" % [s.play_time, got])
	s.add_play_time(0.0)
	check(s.play_time == 1 and got == [1], "add_play_time(0.0) adds and emits nothing")
	s.add_play_time(3.5)
	check(s.play_time == 4 and got == [1, 4], "add_play_time(3.5) moves three seconds with one emit, not three (got %d, %s)" % [s.play_time, got])
	s.add_play_time(0.5)
	check(s.play_time == 5 and got == [1, 4, 5], "...and keeps the half second: 0.5 more makes the fifth (got %d, %s)" % [s.play_time, got])
	s.add_play_time(0.75)
	s.reset()
	got.clear()
	s.add_play_time(0.5)
	check(s.play_time == 0 and got == [], "reset() drops the fraction too: 0.75 s before it and 0.5 s after make no second (got %d)" % s.play_time)
	s.add_play_time(0.75)
	s.from_dict(_slot_dict())
	got.clear()
	s.add_play_time(0.5)
	check(s.play_time == 90 and got == [], "...and so does from_dict(): 90 s loaded, 0.5 s after it adds none (got %d)" % s.play_time)


## Story 1.21 D9: a record like best_chain; it only rises.
func _test_slot_depth() -> void:
	var s := SlotState.new()
	var n := {v = 0}
	s.records_changed.connect(func() -> void: n.v += 1)
	s.record_depth(0)
	check(s.depth == 0 and n.v == 0, "record_depth(0) on a new slot is no record: nothing emitted")
	s.record_depth(2)
	check(s.depth == 2 and n.v == 1, "record_depth(2) raises the depth and emits records_changed once (got %d, %d emits)" % [s.depth, n.v])
	s.record_depth(2)
	s.record_depth(1)
	check(s.depth == 2 and n.v == 1, "...and a row at or above the record changes and emits nothing (got %d, %d emits)" % [s.depth, n.v])
	s.record_depth(6)
	check(s.depth == 6 and n.v == 2, "record_depth(6) raises it again (got %d, %d emits)" % [s.depth, n.v])


func _test_slot_resume() -> void:
	var s := SlotState.new()
	var got := []
	s.resume_changed.connect(func(room: StringName, entry: StringName) -> void: got.append([room, entry]))
	s.set_resume(&"m1_shaft", &"anchor_m1_1")
	check(s.resume_room == &"m1_shaft" and s.resume_entry == &"anchor_m1_1" and got == [[&"m1_shaft", &"anchor_m1_1"]], "set_resume(m1_shaft, anchor_m1_1) sets the point and emits resume_changed once (got %s)" % [got])
	s.set_resume(&"m1_shaft", &"anchor_m1_1")
	check(got.size() == 1, "...and the same point again emits nothing (D2)")
	s.set_resume(&"m1_shaft", &"anchor_m1_2")
	check(got.size() == 2 and got[1] == [&"m1_shaft", &"anchor_m1_2"], "...a new entry in the same room emits (got %s)" % [got])
	s.set_resume(&"", &"")
	check(s.resume_room == &"" and s.resume_entry == &"" and got.size() == 3, "set_resume('', '') clears it: the dive's start again")


## The slot picker's line (Story 1.38); Game adds saved_at when it writes the file.
func _test_slot_meta() -> void:
	var want := {"depth": 4, "best_chain": 12, "play_time": 8040, "difficulty": "easy"}
	var m := _filled_slot().meta()
	check(m == want, "meta() is depth, best_chain, play_time, difficulty: %s (got %s)" % [want, m])
	check(typeof(m.difficulty) == TYPE_STRING and typeof(m.play_time) == TYPE_INT and m.keys().all(func(k: Variant) -> bool: return k is String), "...JSON-ready: String keys, a String difficulty, int counts")
	check(m.size() == 4, "...and exactly those four keys (got %s)" % [m.keys()])


func _test_slot_fallbacks() -> void:
	# Each case is the whole clean dictionary with one fault, so the fault alone makes it unclean.
	var cases := [
		[{"difficulty": "medium"}, "an unknown difficulty", "difficulty"],
		[{"best_chain": -1}, "a negative record", "best_chain"],
		[{"deaths": "x"}, "a record that isn't a number", "deaths"],
		[{"best_chain": 4.5}, "a fractional record", "best_chain"],
		[{"flags": "anchor_m1_1"}, "flags that aren't an array", "flags"],
		# 1e17 is whole and fits an int, so only the 2^53 limit turns it down, on every platform.
		[{"best_chain": 1e17}, "a record too big for a JSON number to hold exactly", "best_chain"],
		# Story 1.21: play time and depth are counts like the records.
		[{"play_time": -5}, "a negative play time", "play_time"],
		[{"play_time": 12.5}, "a fractional play time", "play_time"],
		[{"play_time": "90"}, "a play time that isn't a number", "play_time"],
		[{"depth": -1}, "a negative depth", "depth"],
		[{"depth": null}, "a depth that isn't a number", "depth"],
	]
	var want := {"best_chain": 0, "deaths": 0, "difficulty": &"normal", "flags": [], "visited": [], "play_time": 0, "depth": 0}
	check(SlotState.new().from_dict(_slot_dict()), "(control: the dictionary the cases start from is clean, so each case's one fault is what makes it unclean)")
	for c: Array in cases:
		var s := _filled_slot()
		var clean := s.from_dict(_slot_dict(c[0]))
		var got: Variant = s.to_dict()[c[2]] if c[2] != "difficulty" else s.difficulty
		check(not clean and got == want[c[2]], "SlotState: %s is unclean and gives the default %s (D3; got %s)" % [c[1], c[2], got])
	# Story 1.21 D5: the resume point is one value, like the dive's respawn point: half never loads.
	var halves := {"a resume room that isn't a string": {"resume_room": 12}, "a resume entry that isn't a string": {"resume_entry": false}}
	for what: String in halves:
		var h := _filled_slot()
		var h_clean := h.from_dict(_slot_dict(halves[what]))
		check(not h_clean and h.resume_room == &"" and h.resume_entry == &"", "SlotState: %s is unclean and clears the whole point (got '%s' / '%s')" % [what, h.resume_room, h.resume_entry])
		check(h.best_chain == 4 and h.play_time == 90 and h.depth == 3, "...while the good fields still load (best chain 4, play time 90, depth 3)")
	var no_entry := _slot_dict()
	no_entry.erase("resume_entry")
	var m := _filled_slot()
	check(not m.from_dict(no_entry) and m.resume_room == &"" and m.resume_entry == &"", "...and so does a missing resume entry (got '%s' / '%s')" % [m.resume_room, m.resume_entry])
	var s := SlotState.new()
	var clean := s.from_dict(_slot_dict({"flags": ["met_glim", 7, null]}))
	check(not clean and s.to_dict().flags == ["met_glim"], "a non-string flag entry is skipped and makes the data unclean (got %s)" % [s.to_dict().flags])
	check(s.best_chain == 4 and s.deaths == 2 and s.difficulty == &"hard", "...while the good fields still load")
	var blank := SlotState.new()
	check(not blank.from_dict(_slot_dict({"flags": ["met_glim", ""]})) and blank.to_dict().flags == ["met_glim"] and not blank.has_flag(&""), "an empty flag id is skipped and makes the data unclean (got %s)" % [blank.to_dict().flags])
	var e := SlotState.new()
	check(not e.from_dict({}) and _same_slot(e, SlotState.new()), "from_dict({}) is unclean and gives the defaults")


## D2: reset() and from_dict() emit every value signal once; flag_set fires only per changed id.
func _test_slot_load_signals() -> void:
	var s := _filled_slot()
	var flags := []
	var n := {records = 0, tier = 0}
	var played := []
	var resume := []
	s.flag_set.connect(func(id: StringName, value: bool) -> void: flags.append([id, value]))
	s.records_changed.connect(func() -> void: n.records += 1)
	s.difficulty_changed.connect(func(_tier: StringName) -> void: n.tier += 1)
	s.play_time_changed.connect(func(t: int) -> void: played.append(t))
	s.resume_changed.connect(func(room: StringName, entry: StringName) -> void: resume.append([room, entry]))
	s.reset()
	flags.sort_custom(func(a: Array, b: Array) -> bool: return String(a[0]) < String(b[0]))
	check(flags == [[&"anchor_m1_1", false], [&"met_glim", false]], "reset() emits flag_set(id, false) for each flag it clears (got %s)" % [flags])
	check(n.records == 1 and n.tier == 1, "...and records_changed and difficulty_changed once each (got %d / %d)" % [n.records, n.tier])
	check(played == [0] and resume == [[&"", &""]], "...and play_time_changed(0) and resume_changed('', '') once each (Story 1.21; got %s, %s)" % [played, resume])
	check(_same_slot(s, SlotState.new()), "...leaving the defaults on the same instance")
	played.clear()
	resume.clear()
	s.reset()
	check(played == [0] and resume == [[&"", &""]], "...and both again on a reset that changes nothing (D2; got %s, %s)" % [played, resume])
	s.set_flag(&"met_glim")
	flags.clear()
	n.records = 0
	n.tier = 0
	s.from_dict(_slot_dict({"flags": ["anchor_m1_1", "met_glim"]}))
	check(flags == [[&"anchor_m1_1", true]], "from_dict() emits flag_set(id, true) for each new flag, nothing for one it keeps (got %s)" % [flags])
	check(n.records == 1 and n.tier == 1, "...and records_changed and difficulty_changed once each, even unchanged (got %d / %d)" % [n.records, n.tier])
	played.clear()
	resume.clear()
	s.from_dict(_slot_dict())
	check(played == [90] and resume == [[&"m1_shaft", &"anchor_m1_1"]], "from_dict() emits play_time_changed(90) and resume_changed(m1_shaft, anchor_m1_1) once each (got %s, %s)" % [played, resume])
	played.clear()
	resume.clear()
	s.from_dict(_slot_dict())
	check(played == [90] and resume == [[&"m1_shaft", &"anchor_m1_1"]], "...and again when the load changes neither (D2; got %s, %s)" % [played, resume])
	var v := {n = 0}
	s.visits_changed.connect(func() -> void: v.n += 1)
	s.from_dict(_slot_dict({"visited": ["m1_shaft", "a_side"]}))
	check(v.n == 1 and s.has_visited(&"a_side"), "from_dict() emits visits_changed once for a whole list of rooms (got %d)" % v.n)


## A subscriber may set a flag from its flag_set handler (a derived flag). A load walks the flags
## to emit them, so it must walk a copy: the flag added mid-walk would otherwise emit twice.
func _test_slot_handler_sets_a_flag() -> void:
	var s := SlotState.new()
	var got := []
	var handler := func(id: StringName, value: bool) -> void:
		got.append([id, value])
		if id == &"anchor_m1_1":
			s.set_flag(&"derived")
	s.flag_set.connect(handler)
	s.from_dict(_slot_dict({"flags": ["anchor_m1_1"]}))
	check(got == [[&"anchor_m1_1", true], [&"derived", true]], "a handler that sets a flag during a load: each flag_set fires once (got %s)" % [got])
	check(s.has_flag(&"anchor_m1_1") and s.has_flag(&"derived"), "...and both flags are set")
	# The handler holds `s` and `s` holds the handler: without this the pair leaks at exit, which
	# prints an engine ERROR after the runner has finished.
	s.flag_set.disconnect(handler)


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
	var carried := []
	var e := _filled_dive()
	e.mark_killed(&"m1_shaft", Vector2i(9, 9))
	e.respawn_changed.connect(func(room: StringName, entry: StringName) -> void: respawn.append([room, entry]))
	e.carried_changed.connect(func(c: int) -> void: carried.append(c))
	var clean := e.from_dict(d.to_dict())
	check(clean and e.carried == 7 and e.respawn_room == &"m1_shaft" and e.respawn_entry == &"anchor_m1_1", "from_dict(to_dict()) is clean and keeps carried and the respawn point")
	check(not e.is_killed(&"m1_shaft", Vector2i(3, 4)) and not e.is_killed(&"m1_shaft", Vector2i(9, 9)), "...and clears the killed enemies (they are never saved)")
	check(respawn == [[&"m1_shaft", &"anchor_m1_1"]] and carried == [7], "...and emits respawn_changed and carried_changed even unchanged (D2; got %s, %s)" % [respawn, carried])
	var f := _filled_dive()
	clean = f.from_dict(_through_json(d.to_dict()))
	check(clean and f.carried == 7 and typeof(f.carried) == TYPE_INT, "...through JSON too, carried as an int (got %s, type %d)" % [f.carried, typeof(f.carried)])
	check(typeof(f.respawn_room) == TYPE_STRING_NAME and f.respawn_room == &"m1_shaft" and f.respawn_entry == &"anchor_m1_1", "...and the respawn point as StringNames")
	check(not f.is_killed(&"m1_shaft", Vector2i(3, 4)), "...with no killed enemies")


func _test_dive_fallbacks() -> void:
	# 1e17 is whole and fits an int, so only the 2^53 limit turns it down, on every platform.
	for bad: Variant in [-3, 2.5, "7", null, 1e17]:
		var d := _filled_dive()
		var clean := d.from_dict({"carried": bad, "respawn_room": "m1_shaft", "respawn_entry": "anchor_m1_1"})
		check(not clean and d.carried == 0 and d.respawn_room == &"m1_shaft", "DiveState: carried %s is unclean and gives 0, the other fields still load (D3; got %s)" % [var_to_str(bad), d.carried])
	# The respawn point is one value: half of one never loads.
	var d := _filled_dive()
	check(not d.from_dict({"carried": 4, "respawn_room": 12, "respawn_entry": "anchor_m1_1"}) and d.respawn_room == &"" and d.respawn_entry == &"" and d.carried == 4, "a respawn room that isn't a string is unclean and clears the whole point (got '%s' / '%s')" % [d.respawn_room, d.respawn_entry])
	var f := _filled_dive()
	check(not f.from_dict({"carried": 4, "respawn_room": "m1_shaft"}) and f.respawn_room == &"" and f.respawn_entry == &"" and f.carried == 4, "...and so does a missing entry (got '%s' / '%s')" % [f.respawn_room, f.respawn_entry])


# --- Game (AR11) ---

func _test_game_holds_state() -> void:
	check(Game.settings is Settings and Game.slot is SlotState and Game.dive is DiveState, "Game holds a Settings, a SlotState and a DiveState")
	check(Game.store is SaveStore and Game.store.dir == SaveStore.DEFAULT_DIR, "...and a SaveStore on user:// (got %s)" % Game.store.dir)


## Subscribers hold on to these: a reset or a load must change them in place, never swap them.
func _test_game_same_instances() -> void:
	var before := [Game.settings, Game.slot, Game.dive, Game.tuning, Game.clock]
	Game.reset_for_tests()
	Game.settings.from_dict({"brightness": 2})
	Game.slot.from_dict({"best_chain": 3, "deaths": 1, "difficulty": "hard", "flags": []})
	Game.dive.from_dict({"carried": 4, "respawn_room": "", "respawn_entry": ""})
	var after := [Game.settings, Game.slot, Game.dive, Game.tuning, Game.clock]
	var same := range(before.size()).all(func(i: int) -> bool: return is_same(before[i], after[i]))
	check(same, "reset_for_tests() and from_dict() keep all five Game refs the same instances")
	Game.reset_for_tests()


func _test_game_reset_for_tests() -> void:
	Game.settings.set_value(&"brightness", 3)
	Game.slot.set_flag(&"anchor_m1_1")
	Game.slot.record_chain(9)
	Game.slot.set_difficulty(&"hard")
	Game.dive.add_carried(4)
	Game.dive.mark_killed(&"m1_shaft", Vector2i(3, 4))
	Game.dive.set_respawn(&"m1_shaft", &"anchor_m1_1")
	var gear: Array[Dictionary] = [{id = &"probe_gear", stat = &"cling_slide", op = &"set", value = 1.0}]
	Game.tuning.apply_gear([&"probe_gear"], gear)
	Game.clock.request(&"probe", 0.5, 1.0)
	Game.store.dir = TMP
	check(Engine.time_scale == 0.5 and Game.tuning.f(&"cling_slide") == 1.0, "(setup: the probe request and gear are active)")
	Game.reset_for_tests()
	check(Game.settings.brightness == 1, "reset_for_tests(): brightness back to 1")
	check(not Game.slot.has_flag(&"anchor_m1_1") and Game.slot.best_chain == 0 and Game.slot.deaths == 0 and Game.slot.difficulty == &"normal", "...the slot back to its defaults")
	check(Game.dive.carried == 0 and Game.dive.respawn_room == &"" and not Game.dive.is_killed(&"m1_shaft", Vector2i(3, 4)), "...the dive back to its defaults")
	check(Game.tuning.f(&"cling_slide") == Tuning.BASE[&"cling_slide"], "...tuning back to base (apply_gear([]))")
	check(Engine.time_scale == 1.0 and not Game.clock.is_active(&"probe"), "...the clock cleared (time scale %s)" % Engine.time_scale)
	check(Game.store.dir == SaveStore.DEFAULT_DIR, "...and the store pointed back at user:// (got %s)" % Game.store.dir)


# --- settings.json (R15, D5, D6) ---

func _tmp_file() -> String:
	return TMP.path_join("settings.json")


func _write_file(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _write_tmp(text: String) -> void:
	_write_file(_tmp_file(), text)


## Takes every permission off the temp file, so it exists but can't be opened. False where that
## can't be done (Windows has no such permissions, and root opens anything): the caller skips.
func _lock_tmp() -> bool:
	if OS.get_name() == "Windows":
		return false
	FileAccess.set_unix_permissions(_tmp_file(), 0)
	return FileAccess.open(_tmp_file(), FileAccess.READ) == null


func _unlock_tmp() -> void:
	if OS.get_name() != "Windows":
		FileAccess.set_unix_permissions(_tmp_file(), FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER)


## "" when missing: get_file_as_string() prints an error on a missing file (1.1 review).
func _read_tmp() -> String:
	return FileAccess.get_file_as_string(_tmp_file()) if FileAccess.file_exists(_tmp_file()) else ""


## True when the temp file is a valid version-1 settings file holding this brightness. Types are
## checked before comparing: on 4.7.2 `"bright" == 1` is a SCRIPT ERROR, not false.
func _tmp_holds(brightness: int) -> bool:
	var j := JSON.new()
	if j.parse(_read_tmp()) != OK or not j.get_data() is Dictionary:
		return false
	var d: Dictionary = j.get_data()
	var s: Variant = d.get("settings")
	return d.get("version") is float and d.version == 1 \
			and s is Dictionary and s.get("brightness") is float and s.brightness == brightness


## Puts `text` in the file with another brightness in memory, so a load that falls back shows.
## The await lets an armed write of that value land before the file is replaced.
func _prime(text: String, in_memory: int) -> void:
	Game.settings.set_value(&"brightness", in_memory)
	await get_tree().process_frame
	_write_tmp(text)


func _remove_tmp() -> void:
	for path: String in [_tmp_file(), _tmp_file() + ".tmp", TMP.path_join("missing"), TMP]:
		DirAccess.remove_absolute(path)  # silent when missing


func _test_settings_file() -> void:
	_remove_tmp()  # leftovers from an aborted run
	DirAccess.make_dir_recursive_absolute(TMP)
	var real_had := FileAccess.file_exists(REAL)
	var real_text := FileAccess.get_file_as_string(REAL) if real_had else ""
	var real_time := FileAccess.get_modified_time(REAL) if real_had else 0
	Game.store.dir = TMP
	var warnings := WarningCounter.new()
	OS.add_logger(warnings)

	# A first launch: no file. Writes are still disarmed, so this value is never written.
	# The marker shows the write goes through .tmp: a write straight to settings.json would leave
	# the marker where it is.
	_write_file(_tmp_file() + ".tmp", "marker")
	Game.settings.set_value(&"brightness", 3)
	Game.load_settings()
	check(Game.settings.brightness == 1, "missing file: load_settings() gives the default brightness 1")
	check(not FileAccess.file_exists(_tmp_file()), "...and writes nothing in the same frame")
	await get_tree().process_frame
	check(_tmp_holds(1), "...then a frame later writes version 1 with brightness 1 (got %s)" % _read_tmp().c_escape())
	check(not FileAccess.file_exists(_tmp_file() + ".tmp"), "...through .tmp, renamed over the file (the marker .tmp is used up)")
	check(warnings.take() == 0, "...with no warning: a first launch is not an error")

	# Unusable and safe to replace: the default, one warning, then a rewrite (R15).
	var corrupt := {
		"corrupt file": "{not json",
		"a top-level array": "[1, 2]",
		"no version": '{"settings": {"brightness": 2}}',
		"a version that isn't a number": '{"version": "1", "settings": {"brightness": 2}}',
		"a version below this build's": '{"version": 0, "settings": {"brightness": 2}}',
		"settings that are no object": '{"version": 1, "settings": [2]}',
	}
	for what: String in corrupt:
		await _prime(corrupt[what], 3)
		warnings.take()
		Game.load_settings()
		check(Game.settings.brightness == 1 and _read_tmp() == corrupt[what], "%s: the default, not yet rewritten" % what)
		check(warnings.take() == 1, "...one warning, and no ERROR (the runner checks)")
		await get_tree().process_frame
		check(_tmp_holds(1), "...then rewritten as a valid file (got %s)" % _read_tmp().c_escape())

	# Unusable but maybe whole: a newer build's file, or one that can't be opened. It is never
	# written over, and writes stay off for the session (1.4 review; the slot rule of Story 1.21).
	var newer := '{"version": 2, "settings": {"brightness": 2}}'
	await _prime(newer, 3)
	warnings.take()
	Game.load_settings()
	check(Game.settings.brightness == 1 and warnings.take() == 1, "newer version: the default and one warning")
	await get_tree().process_frame
	Game.settings.set_value(&"brightness", 0)
	await get_tree().process_frame
	check(_read_tmp() == newer and not FileAccess.file_exists(_tmp_file() + ".tmp"), "...the file is left as it was, by the load and by a later change (got %s)" % _read_tmp().c_escape())
	check(Game.settings.brightness == 0, "...and the change still holds in memory")

	var whole := '{"version": 1, "settings": {"brightness": 2}}'
	await _prime(whole, 3)
	if _lock_tmp():
		warnings.take()
		Game.load_settings()
		check(Game.settings.brightness == 1 and warnings.take() == 1, "unopenable file: the default (not the file's 2), one warning and no ERROR")
		await get_tree().process_frame
		Game.settings.set_value(&"brightness", 0)
		await get_tree().process_frame
		_unlock_tmp()
		check(_read_tmp() == whole and not FileAccess.file_exists(_tmp_file() + ".tmp"), "...the file is left as it was, by the load and by a later change (got %s)" % _read_tmp().c_escape())
	else:
		_unlock_tmp()
		print("ok   (unopenable file: not checked here; this platform or user can open a file with no permissions)")

	await _prime('{"version": 1, "settings": {}}', 3)
	Game.load_settings()
	await get_tree().process_frame
	check(Game.settings.brightness == 1 and _tmp_holds(1), "missing key: the default, rewritten with the key (got %s)" % _read_tmp().c_escape())

	await _prime('{"version": 1, "settings": {"brightness": "bright"}}', 3)
	Game.load_settings()
	await get_tree().process_frame
	check(Game.settings.brightness == 1 and _tmp_holds(1), "bad key: the default, rewritten (got %s)" % _read_tmp().c_escape())

	await _prime('{"version": 1, "settings": {"brightness": 3, "light_tap_window": 0.2, "reduce_flashing": true, "shake": false, "reduced_motion": true}, "keep": true}', 0)
	Game.load_settings()
	check(Game.settings.brightness == 3 and typeof(Game.settings.brightness) == TYPE_INT, "valid file: brightness 3, as an int")
	check(Game.settings.light_tap_window == 0.2, "...and the Light tap window 0.2 s (Story 1.8; got %s)" % Game.settings.light_tap_window)
	check(Game.settings.reduce_flashing and not Game.settings.shake and Game.settings.reduced_motion, "...and the three accessibility keys as written (Story 1.16)")
	await get_tree().process_frame
	check(_read_tmp().contains("\"keep\""), "...and the file is kept, not rewritten")

	var writes := WriteCounter.new()
	OS.add_logger(writes)
	Game.settings.set_value(&"brightness", 0)
	Game.settings.set_value(&"brightness", 2)
	check(_read_tmp().contains("\"keep\""), "two changes in one frame write nothing in that frame")
	await get_tree().process_frame
	OS.remove_logger(writes)
	check(_tmp_holds(2), "...a frame later the file holds the second value (got %s)" % _read_tmp().c_escape())
	check(writes.total() == 1, "...written once, not once per change (%d writes)" % writes.total())
	DirAccess.remove_absolute(_tmp_file())
	await get_tree().process_frame
	check(not FileAccess.file_exists(_tmp_file()), "...and nothing more is written a frame later")

	# Writes are still armed. A folder that doesn't exist: the store never creates one (D5).
	Game.store.dir = TMP.path_join("missing")
	check(Game.store.write_settings({"brightness": 1}) != OK, "failed write: write_settings() returns an error")
	warnings.take()
	Game.settings.set_value(&"brightness", 1)
	await get_tree().process_frame
	check(warnings.take() == 1, "...and Game warns once for its own failed write: no crash, no ERROR")
	check(Game.settings.brightness == 1 and not DirAccess.dir_exists_absolute(TMP.path_join("missing")), "...no folder created, the value kept in memory")

	# Tests that never load settings write nothing. Re-pointed at TMP first, so a bug here
	# writes into the temp folder, never the real one.
	Game.reset_for_tests()
	Game.store.dir = TMP
	Game.settings.set_value(&"brightness", 3)
	await get_tree().process_frame
	check(not FileAccess.file_exists(_tmp_file()), "unarmed (after reset_for_tests): a change writes nothing")

	# Story 1.11 D8 (sonlm, 2026-11-19): a DevTools --set override lasts this session only, and a
	# session with one writes no settings.json at all. The store is pointed at TMP again after every
	# reset, so a broken guard writes into the temp folder, never the real file (check (e) below).
	var o_writes := WriteCounter.new()
	OS.add_logger(o_writes)
	Game.reset_for_tests()
	Game.store.dir = TMP
	DirAccess.remove_absolute(_tmp_file())
	Game.override_setting(&"brightness", 3)
	Game.load_settings()
	check(Game.settings.brightness == 3, "(a) an override, then a load with no file: the override is kept (brightness %d)" % Game.settings.brightness)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not FileAccess.file_exists(_tmp_file()) and o_writes.total() == 0, "(a) ...and the missing file is not written (%d writes)" % o_writes.total())

	Game.reset_for_tests()
	Game.store.dir = TMP
	check(Game._overrides.is_empty() and Game.settings.brightness == 1, "reset_for_tests() drops the overrides")
	Game.store.write_settings(Settings.new().to_dict())
	Game.load_settings()
	check(Game._settings_armed and _tmp_holds(1), "(b, premise) a clean file loaded: writes are armed")
	var clean := _read_tmp()
	var w0 := o_writes.total()
	Game.override_setting(&"brightness", 3)
	Game.settings.set_value(&"light_tap_window", 0.2)
	await get_tree().process_frame
	await get_tree().process_frame
	check(o_writes.total() == w0 and _read_tmp() == clean, "(b) armed, then an override and a change to another key: no write, the file unchanged (%d writes)" % (o_writes.total() - w0))

	Game.reset_for_tests()
	Game.store.dir = TMP
	var zero := Settings.new().to_dict()  # every key, so the load is clean and queues no rewrite
	zero["brightness"] = 0
	Game.store.write_settings(zero)
	Game.override_setting(&"brightness", 3)
	Game.load_settings()
	check(Game.settings.brightness == 3, "(c) a file holding 0, an override of 3, then the load: brightness is 3 (got %d)" % Game.settings.brightness)
	await get_tree().process_frame
	await get_tree().process_frame
	check(_tmp_holds(0), "(c) ...and the file still holds 0 (got %s)" % _read_tmp().c_escape())

	Game.reset_for_tests()
	Game.store.dir = TMP
	Game.store.write_settings(Settings.new().to_dict())
	Game.load_settings()
	var w1 := o_writes.total()
	Game.settings.set_value(&"brightness", 2)
	await get_tree().process_frame
	check(o_writes.total() == w1 + 1 and _tmp_holds(2), "(d) control: with no override the same kind of change writes once, in TMP (%d writes)" % (o_writes.total() - w1))
	OS.remove_logger(o_writes)
	Game.reset_for_tests()
	Game.store.dir = TMP

	# Each test runs in its own Godot process, and the folder is redirected first, so this boot
	# reads only the temp file. Keep it the last case: reset_for_tests() leaves the process
	# booted, so a boot() after this one loads nothing.
	_write_tmp('{"version": 1, "settings": {"brightness": 2}}')
	Game.boot()
	check(Game.settings.brightness == 2, "boot() loads settings.json (brightness 2)")
	_write_tmp('{"version": 1, "settings": {"brightness": 3}}')
	Game.boot()
	check(Game.settings.brightness == 2, "...and runs once: a second boot() loads nothing (still 2)")

	# Writes are armed again since boot(). reset_for_tests() points the store home, so hold it on
	# TMP for a frame: a write that a broken reset failed to disarm then lands in the temp folder,
	# never in the real file (a mutant that skipped the disarm wrote user://settings.json here).
	Game.reset_for_tests()
	Game.store.dir = TMP
	DirAccess.remove_absolute(_tmp_file())
	await get_tree().process_frame
	check(not FileAccess.file_exists(_tmp_file()), "after reset_for_tests() nothing is written, even with writes armed before it")
	Game.store.dir = SaveStore.DEFAULT_DIR
	OS.remove_logger(warnings)
	_remove_tmp()
	check(not DirAccess.dir_exists_absolute(TMP), "the temp folder is gone")
	# The modified time too: the real file may hold exactly the defaults, and then a leaked write
	# of the defaults would leave the same text.
	var real_now := FileAccess.file_exists(REAL)
	var real_same := real_now == real_had and (not real_now or (FileAccess.get_file_as_string(REAL) == real_text and FileAccess.get_modified_time(REAL) == real_time))
	check(real_same, "the real user://settings.json is exactly as it was: same text, same modified time (exists: %s)" % real_had)
