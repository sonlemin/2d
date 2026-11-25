extends Node
## The slot saves (AR37, AR38, R14, R15; Story 1.21 AC8): `SaveStore`'s slot read, write and delete,
## and `Game`'s commands and signals on top of them, through real files in a temp folder.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_saves.gd
## Every case starts from `_fresh()`: `Game.reset_for_tests()`, the store pointed at TMP again (the
## reset points it home) and an empty TMP. Saves are armed only by a case's own `load_slot()` or
## `new_game()`, so a broken guard writes into TMP, never the player's folder; the last check
## holds the player's own files to their text and modified time.
## Expected values are written out by hand, and the corrupt, newer and older files are literal
## strings: a value read back from the code under test proves nothing (1.16 review). A parsed
## file's numbers are floats, and {"a": 1} != {"a": 1.0}, so the expected dictionaries hold floats.
## Warnings and signals are counted, never assumed (1.4 review). Signal handlers are methods and
## are disconnected at the end: a lambda that captured a state object would leak it.
## Not tested here, because a failed assert aborts the test: a slot number outside 1..3.

const TMP := "user://test_saves_tmp"
## A whole version-1 slot file as an earlier session left it.
const GOOD := '{"version": 1, "meta": {"best_chain": 7, "depth": 2, "difficulty": "hard", "play_time": 300, "saved_at": 1795000000}, "slot": {"best_chain": 7, "deaths": 1, "depth": 2, "difficulty": "hard", "flags": ["met_glim"], "play_time": 300, "resume_entry": "spawn", "resume_room": "m1_shaft", "visited": ["m1_shaft"]}, "dive": {"carried": 5, "respawn_entry": "spawn", "respawn_room": "m1_shaft"}}'
const NEWER := '{"version": 2, "slot": {"best_chain": 9}, "dive": null, "future": true}'
const READ_KEYS := ["dive", "found", "from_bak", "meta", "slot", "version", "why"]

var _fail := 0
var _events := []  # ["ok", n] per save_succeeded, ["fail", n, err] per save_failed
var _settings_fails := []  # err per settings_save_failed
var _warnings := WarningCounter.new()


## Counts the push_warning calls of Game's slot and settings code and of SaveStore, so "one
## warning" is checked and not only promised. A push_warning's text arrives as `code` (probed on
## 4.7.2). Engine logging can arrive from any thread, hence the mutex, as in tests/runner.gd.
class WarningCounter extends Logger:
	var _lock := Mutex.new()
	var _count := 0

	func _log_error(_function: String, _file: String, _line: int, code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			return
		if not (code.begins_with("Game: slot") or code.begins_with("Game: settings") or code.begins_with("SaveStore:")):
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


## Collects the `[save] …` Log lines, to check the milestones Game and SaveStore log.
class SaveLines extends Logger:
	var _lock := Mutex.new()
	var _lines := PackedStringArray()

	func _log_message(message: String, _error: bool) -> void:
		_lock.lock()
		for line in message.split("\n", false):
			if line.begins_with("[save] "):
				_lines.append(line)
		_lock.unlock()

	## The lines since the last take().
	func take() -> PackedStringArray:
		_lock.lock()
		var out := _lines.duplicate()
		_lines.clear()
		_lock.unlock()
		return out


func run() -> void:
	var real := _real_files()
	_wipe()  # leftovers from an aborted run
	DirAccess.make_dir_recursive_absolute(TMP)
	Game.save_succeeded.connect(_on_saved)
	Game.save_failed.connect(_on_save_failed)
	Game.settings_save_failed.connect(_on_settings_save_failed)
	OS.add_logger(_warnings)
	_test_unarmed_at_start()  # keep first: before any reset_for_tests(), which disarms by itself
	_test_round_trip()
	_test_bak()
	_test_bak_fallback()
	_test_damaged()
	_test_new_game_and_slots()
	_test_newer()
	_test_shapes()
	_test_read_table()
	_test_unclean()
	_test_older_version()
	_test_progress_save()
	_test_progress_save_without_resume()
	_test_failed_resume_then_progress()
	_test_failure_signal()
	_test_read_only()
	_test_verify_file()
	_test_unarmed()
	_test_delete_slot()
	_test_detached()
	await _test_settings_signal()
	await _test_boot()  # keep last: boot runs once per process, and the process stays booted
	Game.reset_for_tests()
	Game.save_succeeded.disconnect(_on_saved)
	Game.save_failed.disconnect(_on_save_failed)
	Game.settings_save_failed.disconnect(_on_settings_save_failed)
	OS.remove_logger(_warnings)
	_wipe()
	check(not DirAccess.dir_exists_absolute(TMP), "the temp folder is gone")
	var now := _real_files()
	var changed := real.keys().filter(func(path: String) -> bool: return real[path] != now[path])
	check(changed.is_empty(), "the player's own files (user://slot_1..3.json, their .bak and .tmp, settings.json) are exactly as before: same existence, text and modified time (changed: %s)" % [changed])
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func _on_saved(n: int) -> void:
	_events.append(["ok", n])


func _on_save_failed(n: int, err: Error) -> void:
	_events.append(["fail", n, err])


func _on_settings_save_failed(err: Error) -> void:
	_settings_fails.append(err)


# --- helpers ---

## {path: [exists, text, modified time]} for every file of the player's that a save could reach.
func _real_files() -> Dictionary:
	var paths := ["user://settings.json"]
	for n in range(1, 4):
		for suffix: String in ["", ".bak", ".tmp"]:
			paths.append("user://slot_%d.json%s" % [n, suffix])
	var out := {}
	for path: String in paths:
		var there := FileAccess.file_exists(path)
		out[path] = [there, FileAccess.get_file_as_string(path) if there else "", FileAccess.get_modified_time(path) if there else 0]
	return out


func _slot(n := 1) -> String:
	return TMP.path_join("slot_%d.json" % n)


func _put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _has(path: String) -> bool:
	return FileAccess.file_exists(path)


## "" when missing: get_file_as_string() prints an error on a missing file (1.1 review). Callers
## that must tell missing from empty ask _has() too.
func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


## The file as parsed JSON, or {} when it is missing or isn't a JSON object.
func _parsed(path: String) -> Dictionary:
	var j := JSON.new()
	if not _has(path) or j.parse(_text(path)) != OK or not j.get_data() is Dictionary:
		return {}
	return j.get_data()


## Every file out of TMP (and its two sub-folders), then the folders: silent when missing.
func _wipe() -> void:
	for sub: String in ["ro", "missing", ""]:
		var folder := TMP.path_join(sub) if sub != "" else TMP
		if not DirAccess.dir_exists_absolute(folder):
			continue
		if OS.get_name() != "Windows":
			FileAccess.set_unix_permissions(folder, 493)  # rwxr-xr-x: an aborted run may have left it read-only
		for file in DirAccess.get_files_at(folder):
			if OS.get_name() != "Windows":
				FileAccess.set_unix_permissions(folder.path_join(file), 420)  # rw-r--r--
			DirAccess.remove_absolute(folder.path_join(file))
		DirAccess.remove_absolute(folder)


## A fresh session on an empty TMP: defaults in memory, saves unarmed, the slot attached, the
## store on TMP. Clears the counters, so each case counts only its own warnings and signals.
func _fresh() -> void:
	Game.reset_for_tests()
	_wipe()
	DirAccess.make_dir_recursive_absolute(TMP)
	Game.store.dir = TMP
	_events.clear()
	_warnings.take()


## The same session state every time: what the round trip expects back.
func _fill() -> void:
	Game.slot.record_chain(17)
	for i in 3:
		Game.slot.record_death()
	Game.slot.set_difficulty(&"hard")  # on the slot, not Game.set_difficulty(): that would save
	Game.slot.set_flag(&"met_glim")
	Game.slot.visit(&"m1_shaft")
	Game.slot.add_play_time(8040.5)
	Game.slot.record_depth(4)
	Game.dive.add_carried(12)
	Game.dive.set_respawn(&"m1_shaft", &"anchor_m1_1")
	Game.dive.mark_killed(&"m1_shaft", Vector2i(3, 4))


# --- cases ---

## D7: a process that never booted, loaded or started a game saves nothing. First, before any
## reset_for_tests(): the reset disarms, so after one a build that started armed would pass.
## The store is on TMP, so such a build writes there, never into the player's folder.
func _test_unarmed_at_start() -> void:
	Game.store.dir = TMP
	Game.slot.record_chain(5)
	var err := Game.save_now()
	var err_progress := Game.save_progress()
	check(err == ERR_UNCONFIGURED and err_progress == ERR_UNCONFIGURED, "a fresh process, before any load: save_now() and save_progress() return ERR_UNCONFIGURED (got %s, %s)" % [error_string(err), error_string(err_progress)])
	check(DirAccess.get_files_at(TMP).is_empty() and _events.is_empty() and _warnings.take() == 0, "...writing nothing, with no signal and no warning (TMP holds %s)" % [DirAccess.get_files_at(TMP)])
	check(Game.active_slot == 1, "...and the active slot starts as 1")


func _test_round_trip() -> void:
	_fresh()
	check(Game.load_slot(1) == SaveStore.Found.MISSING, "an empty slot: load_slot(1) is MISSING")
	check(_warnings.take() == 0 and _events.is_empty(), "...silently: a first launch is no error (no warning, no signal)")
	_fill()
	var lines := SaveLines.new()
	OS.add_logger(lines)
	var t0 := int(Time.get_unix_time_from_system())
	_put(_slot() + ".tmp", "marker")  # a write straight to slot_1.json would leave the marker
	var err := Game.save_now()
	var t1 := int(Time.get_unix_time_from_system())
	OS.remove_logger(lines)
	check(err == OK and _events == [["ok", 1]], "save_now() returns OK and emits save_succeeded(1) once (got %s, %s)" % [error_string(err), _events])
	check(_warnings.take() == 0, "...with no warning")
	check(_has(_slot()) and not _has(_slot() + ".tmp"), "...through .tmp, renamed over the file: the marker .tmp is used up and no .tmp is left")
	check(not _has(_slot() + ".bak"), "...and the first save writes no .bak: there was nothing to back up")
	var written := lines.take()
	var size := FileAccess.get_file_as_bytes(_slot()).size()
	check(written == PackedStringArray(["[save] slot 1 written (%d bytes)" % size]), "...logged once as '[save] slot 1 written (%d bytes)', the file's size (got %s)" % [size, written])
	check(Game.slot.resume_room == &"m1_shaft" and Game.slot.resume_entry == &"anchor_m1_1", "...and the slot's resume point followed the dive's respawn point (D5; got '%s' / '%s')" % [Game.slot.resume_room, Game.slot.resume_entry])

	var d := _parsed(_slot())
	var keys := d.keys()
	keys.sort()
	check(keys == ["dive", "meta", "slot", "version"], "the file is dive, meta, slot, version (got %s)" % [keys])
	check(d.get("version") is float and d.version == 1.0, "...with version 1 (got %s)" % var_to_str(d.get("version")))
	check(_text(_slot()).begins_with("{\n\t\"dive\": {\n"), "...written with tabs, keys sorted (D2; starts %s)" % _text(_slot()).left(16).c_escape())
	var want_slot := {"best_chain": 17.0, "deaths": 3.0, "depth": 4.0, "difficulty": "hard", "flags": ["met_glim"], "play_time": 8040.0,
			"resume_entry": "anchor_m1_1", "resume_room": "m1_shaft", "visited": ["m1_shaft"]}
	check(d.get("slot") == want_slot, "...slot is %s (got %s)" % [want_slot, d.get("slot")])
	var want_dive := {"carried": 12.0, "respawn_entry": "anchor_m1_1", "respawn_room": "m1_shaft"}
	check(d.get("dive") == want_dive, "...dive is %s, no killed enemies (got %s)" % [want_dive, d.get("dive")])
	var meta: Dictionary = d.get("meta") if d.get("meta") is Dictionary else {}
	var saved_at: Variant = meta.get("saved_at")
	meta.erase("saved_at")
	var want_meta := {"best_chain": 17.0, "depth": 4.0, "difficulty": "hard", "play_time": 8040.0}
	check(meta == want_meta, "...meta is depth, best chain, play time and difficulty %s (got %s)" % [want_meta, meta])
	check(saved_at is float and saved_at == floorf(saved_at) and saved_at >= t0 and saved_at <= t1, "...plus saved_at, whole Unix seconds not before the save started (%d ≤ %s ≤ %d)" % [t0, saved_at, t1])

	Game.reset_for_tests()
	Game.store.dir = TMP
	check(Game.slot.best_chain == 0 and Game.dive.carried == 0, "(the reset emptied the session, so what follows comes from the file)")
	lines = SaveLines.new()
	OS.add_logger(lines)
	var found := Game.load_slot(1)
	OS.remove_logger(lines)
	check(found == SaveStore.Found.USABLE and _warnings.take() == 0, "load_slot(1) is USABLE, with no warning")
	check(lines.take() == PackedStringArray(["[save] slot 1 loaded"]), "...logged once as '[save] slot 1 loaded'")
	var s := Game.slot
	check(s.best_chain == 17 and typeof(s.best_chain) == TYPE_INT and s.deaths == 3 and typeof(s.deaths) == TYPE_INT, "...best chain 17 and deaths 3, as ints (got %s / %s)" % [var_to_str(s.best_chain), var_to_str(s.deaths)])
	check(s.play_time == 8040 and typeof(s.play_time) == TYPE_INT and s.depth == 4 and typeof(s.depth) == TYPE_INT, "...play time 8040 and depth 4, as ints (got %s / %s)" % [var_to_str(s.play_time), var_to_str(s.depth)])
	check(s.difficulty == &"hard" and typeof(s.difficulty) == TYPE_STRING_NAME, "...difficulty hard, a StringName")
	check(s.has_flag(&"met_glim") and s.has_visited(&"m1_shaft") and s.to_dict().flags == ["met_glim"] and s.to_dict().visited == ["m1_shaft"], "...the flag and the visited room")
	check(s.resume_room == &"m1_shaft" and s.resume_entry == &"anchor_m1_1" and typeof(s.resume_room) == TYPE_STRING_NAME, "...the resume point m1_shaft / anchor_m1_1, StringNames")
	var v := Game.dive
	check(v.carried == 12 and typeof(v.carried) == TYPE_INT, "...12 carried embers, an int (got %s)" % var_to_str(v.carried))
	check(v.respawn_room == &"m1_shaft" and v.respawn_entry == &"anchor_m1_1" and typeof(v.respawn_entry) == TYPE_STRING_NAME, "...the respawn point m1_shaft / anchor_m1_1, StringNames: World wakes the player there")
	check(not v.is_killed(&"m1_shaft", Vector2i(3, 4)), "...and no killed enemy: they are never saved")
	check(Game.active_slot == 1, "...and slot 1 is the active slot")


func _test_bak() -> void:
	_fresh()
	Game.load_slot(1)
	Game.slot.record_chain(1)
	Game.save_now()
	var first := _text(_slot())
	check(first.contains("\"best_chain\": 1,") and not _has(_slot() + ".bak"), "first save: the file holds best chain 1 and there is no .bak")
	Game.slot.record_chain(2)
	Game.save_now()
	var second := _text(_slot())
	check(second.contains("\"best_chain\": 2,") and second != first, "second save: the file holds best chain 2")
	check(_has(_slot() + ".bak") and _text(_slot() + ".bak") == first, "...and .bak is the first file, byte for byte")
	check(not _has(_slot() + ".tmp"), "...and no .tmp is left")
	Game.slot.record_chain(3)
	Game.save_now()
	check(_text(_slot() + ".bak") == second and _text(_slot()).contains("\"best_chain\": 3,"), "third save: .bak is now the second file: always the file as it was before the last write")
	check(_events == [["ok", 1], ["ok", 1], ["ok", 1]] and _warnings.take() == 0, "...three saves, three save_succeeded(1), no warning (got %s)" % [_events])


func _test_bak_fallback() -> void:
	_fresh()
	_put(_slot(), "{not json")
	_put(_slot() + ".bak", GOOD)
	var read := Game.store.read_slot(1)
	check(read.found == SaveStore.Found.USABLE and read.from_bak == true and read.why != "", "a corrupt main file with a good .bak reads USABLE, from_bak, with a why (got %s, '%s')" % [read.found, read.why])
	check(_warnings.take() == 0, "...and read_slot() itself warns nothing: the caller does")
	check(Game.load_slot(1) == SaveStore.Found.USABLE and Game.slot.best_chain == 7 and Game.dive.carried == 5, "...and load_slot(1) loads the .bak: best chain 7, 5 carried (got %d, %d)" % [Game.slot.best_chain, Game.dive.carried])
	check(_warnings.take() == 1, "...with one warning: the backup was used")
	check(_text(_slot()) == "{not json" and _text(_slot() + ".bak") == GOOD, "...and the load changed neither file")
	var err := Game.save_now()
	var d := _parsed(_slot())
	check(err == OK and d.get("slot", {}).get("best_chain") == 7.0, "the next save replaces the corrupt main file with a whole one (best chain 7; got %s)" % error_string(err))
	check(_text(_slot() + ".bak") == GOOD, "...and leaves that .bak byte for byte: a corrupt main file is never copied over a good backup")
	check(not _has(_slot() + ".tmp") and _warnings.take() == 0, "...no .tmp left, no warning")

	_fresh()
	_put(_slot() + ".bak", GOOD)  # what a crash between the backup and the rename leaves on Windows (D4)
	read = Game.store.read_slot(1)
	check(read.found == SaveStore.Found.USABLE and read.from_bak == true, "a missing main file with a good .bak reads USABLE, from_bak")
	check(Game.load_slot(1) == SaveStore.Found.USABLE and Game.slot.best_chain == 7 and _warnings.take() == 1, "...and loads it, with one warning (best chain %d)" % Game.slot.best_chain)
	err = Game.save_now()
	check(err == OK and _has(_slot()) and _text(_slot() + ".bak") == GOOD, "...the next save writes the main file and leaves the .bak byte for byte")


func _test_damaged() -> void:
	_fresh()
	var main := "{not json"
	var bak := "[1, 2]"
	_put(_slot(), main)
	_put(_slot() + ".bak", bak)
	Game.slot.record_chain(9)  # in memory before the load, so the defaults after it show
	check(Game.load_slot(1) == SaveStore.Found.CORRUPT, "both files corrupt: load_slot(1) is CORRUPT")
	check(Game.slot.best_chain == 0 and Game.slot.difficulty == &"normal" and Game.dive.carried == 0, "...with the defaults in memory")
	check(_warnings.take() == 1 and _events.is_empty(), "...and one warning")
	Game.slot.record_chain(3)
	for save: Callable in [Game.save_now, Game.save_progress]:
		_events.clear()
		var err: Error = save.call()
		check(err == ERR_FILE_CORRUPT and _events == [["fail", 1, ERR_FILE_CORRUPT]], "%s() on the damaged slot returns ERR_FILE_CORRUPT and emits save_failed(1, err) once (got %s, %s)" % [save.get_method(), error_string(err), _events])
		check(_warnings.take() == 1, "...warns once")
		check(_text(_slot()) == main and _text(_slot() + ".bak") == bak and not _has(_slot() + ".tmp"), "...and leaves both files byte for byte, with no .tmp")
	_events.clear()
	var made := Game.new_game(1)
	check(made == OK and _events == [["ok", 1]] and _warnings.take() == 0, "new_game(1) writes over the damaged slot: OK, save_succeeded(1) once, no warning (got %s, %s)" % [error_string(made), _events])
	check(not _has(_slot() + ".bak") and not _has(_slot() + ".tmp"), "...and no old .bak is left, so the overwritten game can never load later")
	check(Game.slot.best_chain == 0, "...the new game starts from the defaults (best chain 0, not the 3 in memory before it)")
	Game.slot.record_chain(6)
	check(Game.save_now() == OK, "...and the slot saves again")
	Game.reset_for_tests()
	Game.store.dir = TMP
	check(Game.load_slot(1) == SaveStore.Found.USABLE and Game.slot.best_chain == 6 and _warnings.take() == 0, "...and loads again: best chain 6, no warning")


func _test_new_game_and_slots() -> void:
	_fresh()
	_put(_slot(1), GOOD)
	var err := Game.new_game(2, &"easy")
	check(err == OK and Game.active_slot == 2 and _events == [["ok", 2]], "new_game(2, easy): slot 2 is the active slot and save_succeeded(2) fired once (got %s)" % [_events])
	var d := _parsed(_slot(2))
	check(d.get("slot", {}).get("difficulty") == "easy" and d.get("meta", {}).get("difficulty") == "easy", "...slot_2.json holds the easy tier, in slot and in meta")
	check(d.has("dive") and d["dive"] == {"carried": 0.0, "respawn_entry": "", "respawn_room": ""}, "...and an empty dive: a resume save always writes the dive (got %s)" % [d.get("dive")])
	check(_text(_slot(1)) == GOOD and not _has(_slot(3)), "...and slots 1 and 3 are untouched")
	Game.slot.record_chain(4)
	Game.save_now()
	check(_parsed(_slot(2)).get("slot", {}).get("best_chain") == 4.0 and _text(_slot(1)) == GOOD, "a later save_now() writes the active slot, 2")
	check(Game.load_slot(1) == SaveStore.Found.USABLE and Game.active_slot == 1 and Game.slot.best_chain == 7, "load_slot(1) makes slot 1 active again and loads it (best chain 7)")
	Game.load_slot(3)
	Game.reset_for_tests()
	check(Game.active_slot == 1, "reset_for_tests() puts the active slot back to 1 (it was 3)")


func _test_newer() -> void:
	_fresh()
	_put(_slot(), NEWER)
	check(Game.load_slot(1) == SaveStore.Found.NEWER and Game.slot.best_chain == 0, "a version 2 file: load_slot(1) is NEWER, the defaults in memory")
	check(_warnings.take() == 1, "...one warning")
	for save: Callable in [Game.save_now, Game.save_progress]:
		_events.clear()
		var err: Error = save.call()
		check(err == ERR_FILE_UNRECOGNIZED and _events == [["fail", 1, ERR_FILE_UNRECOGNIZED]] and _warnings.take() == 1, "%s() on a newer slot returns ERR_FILE_UNRECOGNIZED, emits save_failed once and warns once (got %s, %s)" % [save.get_method(), error_string(err), _events])
		check(_text(_slot()) == NEWER and not _has(_slot() + ".tmp") and not _has(_slot() + ".bak"), "...the file is byte for byte as it was, and no .tmp or .bak appears")
	# D3: a newer file may be whole, so an older .bak never bypasses it.
	_put(_slot() + ".bak", GOOD)
	var read := Game.store.read_slot(1)
	check(read.found == SaveStore.Found.NEWER and read.from_bak == false and read.slot == {}, "a newer main file with a good older .bak is still NEWER: the .bak is not read (got %s)" % read.found)
	# A later build may change the file's shape: judged by its version first, it is kept, not "corrupt".
	_put(_slot(), '{"version": 2, "state": {"anything": 1}}')
	check(Game.store.read_slot(1).found == SaveStore.Found.NEWER, "a version 2 file with no slot object is NEWER, not CORRUPT: a newer build may have changed the shape")
	check(_warnings.take() == 0, "...and read_slot() warned nothing")


## Each file is the control with one fault, read alone (no .bak), so the fault is what makes it CORRUPT.
func _test_shapes() -> void:
	_fresh()
	_put(_slot(), '{"version": 1, "meta": {"depth": 1}, "slot": {}, "dive": null}')
	var ok := Game.store.read_slot(1)
	var ok_keys := ok.keys().map(func(k: Variant) -> String: return String(k))
	ok_keys.sort()
	check(ok.found == SaveStore.Found.USABLE and ok.why == "" and ok.from_bak == false, "(control) a whole file is USABLE, with no why")
	check(ok_keys == READ_KEYS, "read_slot() gives %s (got %s)" % [[READ_KEYS], [ok_keys]])
	check(typeof(ok.version) == TYPE_INT and ok.version == 1 and ok.meta == {"depth": 1.0} and ok.slot == {} and ok.dive == null, "...version 1 as an int, the file's meta and slot, and a null dive")
	var corrupt := {
		"not JSON": "{not json",
		"an empty file": "",
		"a top-level array": "[1, 2]",
		"no version": '{"meta": {}, "slot": {}, "dive": null}',
		"a string version": '{"version": "1", "meta": {}, "slot": {}, "dive": null}',
		"version 0": '{"version": 0, "meta": {}, "slot": {}, "dive": null}',
		"version 1.5": '{"version": 1.5, "meta": {}, "slot": {}, "dive": null}',
		"a version too big to be a whole number (1e300)": '{"version": 1e300, "meta": {}, "slot": {}, "dive": null}',
		"a slot that is not an object": '{"version": 1, "meta": {}, "slot": [1], "dive": null}',
		"no slot": '{"version": 1, "meta": {}, "dive": null}',
		"a dive that is a number": '{"version": 1, "meta": {}, "slot": {}, "dive": 3}',
	}
	for what: String in corrupt:
		_put(_slot(), corrupt[what])
		var read := Game.store.read_slot(1)
		check(read.found == SaveStore.Found.CORRUPT and read.why != "" and read.slot == {} and read.dive == null, "%s is CORRUPT, with a why (got %s, '%s')" % [what, read.found, read.why])
	var usable := {
		"a missing meta": '{"version": 1, "slot": {"best_chain": 2}, "dive": null}',
		"a meta that is not an object": '{"version": 1, "meta": 5, "slot": {"best_chain": 2}, "dive": null}',
	}
	for what: String in usable:
		_put(_slot(), usable[what])
		var read := Game.store.read_slot(1)
		check(read.found == SaveStore.Found.USABLE and read.meta == {} and read.slot == {"best_chain": 2.0}, "%s is USABLE with meta == {}: meta is only a copy for the picker (got %s, %s)" % [what, read.found, read.meta])
	_put(_slot(), '{"version": 1, "meta": {}, "slot": {}}')
	var no_dive := Game.store.read_slot(1)
	check(no_dive.found == SaveStore.Found.USABLE and no_dive.dive == null, "a missing dive key is USABLE and reads as null: no dive snapshot")
	_put(_slot(), '{"version": 1, "meta": {}, "slot": {}, "dive": {"carried": 2}}')
	check(Game.store.read_slot(1).dive == {"carried": 2.0}, "...and a dive object comes back as it is")
	check(_warnings.take() == 0, "read_slot() pushed no warning for any of them (and the runner sees no ERROR)")


## AC3's table: the slot's result from its two files.
func _test_read_table() -> void:
	var files := {"MISSING": null, "CORRUPT": "{not json", "USABLE": GOOD, "NEWER": NEWER}
	# [main, .bak, result, from_bak]
	var rows := [
		["USABLE", "CORRUPT", SaveStore.Found.USABLE, false],
		["USABLE", "NEWER", SaveStore.Found.USABLE, false],
		["NEWER", "USABLE", SaveStore.Found.NEWER, false],
		["MISSING", "USABLE", SaveStore.Found.USABLE, true],
		["CORRUPT", "USABLE", SaveStore.Found.USABLE, true],
		["MISSING", "NEWER", SaveStore.Found.NEWER, false],
		["CORRUPT", "NEWER", SaveStore.Found.NEWER, false],
		["MISSING", "MISSING", SaveStore.Found.MISSING, false],
		["MISSING", "CORRUPT", SaveStore.Found.CORRUPT, false],
		["CORRUPT", "MISSING", SaveStore.Found.CORRUPT, false],
		["CORRUPT", "CORRUPT", SaveStore.Found.CORRUPT, false],
	]
	for row: Array in rows:
		_fresh()
		if files[row[0]] != null:
			_put(_slot(), files[row[0]])
		if files[row[1]] != null:
			_put(_slot() + ".bak", files[row[1]])
		var read := Game.store.read_slot(1)
		var why_ok: bool = (read.why == "") == (row[2] == SaveStore.Found.MISSING or (row[2] == SaveStore.Found.USABLE and not row[3]))
		check(read.found == row[2] and read.from_bak == row[3] and why_ok, "main %s + .bak %s reads %s%s (got %s, from_bak %s, why '%s')" % [
				row[0], row[1], SaveStore.Found.keys()[row[2]], ", from_bak" if row[3] else "", SaveStore.Found.keys()[read.found], read.from_bak, read.why])
	# The unopenable rows need a file with no permissions: not on Windows, not as root.
	_fresh()
	_put(_slot(), GOOD)
	_put(_slot() + ".bak", GOOD)
	if _lock(_slot()):
		check(Game.store.read_slot(1).found == SaveStore.Found.UNREADABLE, "an unopenable main file is UNREADABLE even beside a good .bak: it may be whole, so it is never bypassed")
		var before := _text(_slot() + ".bak")
		Game.load_slot(1)
		var err := Game.save_now()
		check(err == ERR_FILE_CANT_OPEN and _events == [["fail", 1, ERR_FILE_CANT_OPEN]] and _warnings.take() == 2, "...load_slot() warns once and gives the defaults; save_now() returns ERR_FILE_CANT_OPEN, emits save_failed once and warns once (got %s, %s)" % [error_string(err), _events])
		_unlock(_slot())
		check(_text(_slot()) == GOOD and _text(_slot() + ".bak") == before and not _has(_slot() + ".tmp"), "...and both files are byte for byte as they were")
		for main: String in ["MISSING", "CORRUPT"]:
			_fresh()
			if files[main] != null:
				_put(_slot(), files[main])
			_put(_slot() + ".bak", GOOD)
			_lock(_slot() + ".bak")
			var read := Game.store.read_slot(1)
			_unlock(_slot() + ".bak")
			check(read.found == SaveStore.Found.UNREADABLE and read.from_bak == false, "main %s + an unopenable .bak reads UNREADABLE (got %s)" % [main, SaveStore.Found.keys()[read.found]])
	else:
		_unlock(_slot())
		print("ok   (unopenable files: not checked here; this platform or user can open a file with no permissions)")


## Takes every permission off a file, so it exists but can't be opened. False where that can't
## be done (Windows has no such permissions, and root opens anything): the caller skips.
func _lock(path: String) -> bool:
	if OS.get_name() == "Windows":
		return false
	FileAccess.set_unix_permissions(path, 0)
	return FileAccess.open(path, FileAccess.READ) == null


func _unlock(path: String) -> void:
	if OS.get_name() != "Windows":
		FileAccess.set_unix_permissions(path, 420)  # rw-r--r--


func _test_unclean() -> void:
	_fresh()
	_put(_slot(), '{"version": 1, "meta": {}, "slot": {"best_chain": "many", "deaths": 1, "depth": 2, "difficulty": "hard", "flags": ["met_glim"], "play_time": 300, "resume_entry": "spawn", "resume_room": "m1_shaft", "visited": ["m1_shaft"]}, "dive": {"carried": 5, "respawn_entry": "spawn", "respawn_room": "m1_shaft"}}')
	check(Game.load_slot(1) == SaveStore.Found.USABLE, "a usable file with one bad slot field (best_chain \"many\") still loads: USABLE")
	check(Game.slot.best_chain == 0, "...that field takes its default 0")
	check(Game.slot.deaths == 1 and Game.slot.depth == 2 and Game.slot.difficulty == &"hard" and Game.slot.has_flag(&"met_glim") and Game.slot.play_time == 300 and Game.dive.carried == 5, "...the good fields are kept (deaths 1, depth 2, hard, the flag, 300 s, 5 carried)")
	check(_warnings.take() == 1, "...with one warning")
	check(Game.save_now() == OK and _warnings.take() == 0, "...and it may be saved again (1.4 D3)")
	_fresh()
	_put(_slot(), '{"version": 1, "meta": {}, "slot": {"best_chain": 7, "deaths": 1, "depth": 2, "difficulty": "hard", "flags": [], "play_time": 300, "resume_entry": "spawn", "resume_room": "m1_shaft", "visited": []}, "dive": {"carried": -4, "respawn_entry": "spawn", "respawn_room": "m1_shaft"}}')
	check(Game.load_slot(1) == SaveStore.Found.USABLE and Game.dive.carried == 0 and Game.dive.respawn_entry == &"spawn" and Game.slot.best_chain == 7 and _warnings.take() == 1, "a bad dive field (carried -4) loads as 0 with the rest kept, one warning")
	_fresh()
	_put(_slot(), GOOD)
	check(Game.load_slot(1) == SaveStore.Found.USABLE and _warnings.take() == 0, "(control) the whole file loads with no warning")


## Fake steps: v1 → v2 adds 10 to the best chain; v2 → v3 copies it into deaths, so the result
## shows both ran, in order.
func _step_1(d: Dictionary) -> void:
	d.slot["best_chain"] = d.slot["best_chain"] + 10
	d["version"] = 2


func _step_2(d: Dictionary) -> void:
	d.slot["deaths"] = d.slot["best_chain"]
	d["version"] = 3


## The scaffold through the store (AC2's steps themselves are test_migrations').
func _test_older_version() -> void:
	_fresh()
	_put(_slot(), GOOD)
	Game.store.version = 3
	Game.store.steps = {1: _step_1, 2: _step_2}
	var read := Game.store.read_slot(1)
	check(read.found == SaveStore.Found.USABLE and read.version == 3, "with the store at version 3 and two steps, a v1 file reads USABLE as version 3 (got %s, v%s)" % [SaveStore.Found.keys()[read.found], read.version])
	check(read.slot.get("best_chain") == 17.0 and read.slot.get("deaths") == 17.0, "...with both steps applied, in order: best chain 7 + 10, then deaths = 17 (got %s / %s)" % [read.slot.get("best_chain"), read.slot.get("deaths")])
	check(Game.load_slot(1) == SaveStore.Found.USABLE and Game.slot.best_chain == 17 and Game.slot.deaths == 17 and _warnings.take() == 0, "...and load_slot() loads the migrated values, with no warning")
	check(_text(_slot()) == GOOD, "...the v1 file itself is left as it was by the read")
	_put(_slot(), '{"version": 4, "slot": {}, "dive": null}')
	check(Game.store.read_slot(1).found == SaveStore.Found.NEWER, "...and a v4 file is NEWER")
	_put(_slot(), '{"version": 2, "meta": {}, "slot": {"best_chain": 1}, "dive": null}')
	var from_2 := Game.store.read_slot(1)
	check(from_2.found == SaveStore.Found.USABLE and from_2.slot.get("deaths") == 1.0 and from_2.slot.get("best_chain") == 1.0, "...a v2 file runs only the second step (best chain 1 kept, deaths = 1)")
	_put(_slot(), GOOD)
	Game.store.steps = {1: _step_1}
	var stuck := Game.store.read_slot(1)
	check(stuck.found == SaveStore.Found.CORRUPT and stuck.why != "", "with the v2 step missing, the v1 file is CORRUPT (got %s, '%s')" % [SaveStore.Found.keys()[stuck.found], stuck.why])
	Game.reset_for_tests()
	check(Game.store.version == 1 and Game.store.steps == {}, "reset_for_tests() puts the store back on the real version and steps")


## R14, D6: a progress save keeps live progress, but never moves where you wake or makes carried
## embers safe.
func _test_progress_save() -> void:
	_fresh()
	Game.load_slot(1)
	Game.dive.set_respawn(&"m1_shaft", &"spawn")
	Game.dive.add_carried(5)
	check(Game.save_now() == OK, "(setup) a resume save: respawn m1_shaft / spawn, 5 carried")
	Game.dive.add_carried(20)
	Game.dive.set_respawn(&"m1_shaft", &"up")
	_events.clear()
	Game.set_difficulty(&"hard")
	check(_events == [["ok", 1]], "Game.set_difficulty(hard) alone wrote the file: one save_succeeded(1) (got %s)" % [_events])
	check(_parsed(_slot()).get("slot", {}).get("difficulty") == "hard", "...and the file holds the new tier")
	Game.set_difficulty(&"hard")
	check(_events == [["ok", 1]], "...the same tier again saves nothing (still one signal; got %s)" % [_events])
	Game.slot.set_flag(&"met_glim")
	check(Game.save_progress() == OK and _events == [["ok", 1], ["ok", 1]] and _warnings.take() == 0, "save_progress() returns OK and emits save_succeeded(1), like save_now()")
	check(Game.dive.carried == 25 and Game.dive.respawn_entry == &"up" and Game.slot.resume_entry == &"spawn", "...and changes nothing in memory: 25 carried, respawn at up, the slot's resume point still spawn")
	var d := _parsed(_slot())
	check(d.get("slot", {}).get("flags") == ["met_glim"] and d.get("slot", {}).get("difficulty") == "hard", "the file holds the live progress: the flag and the hard tier")
	check(d.get("slot", {}).get("resume_room") == "m1_shaft" and d.get("slot", {}).get("resume_entry") == "spawn", "...the resume point of the resume save (spawn, not up)")
	check(d.get("dive") == {"carried": 5.0, "respawn_entry": "spawn", "respawn_room": "m1_shaft"}, "...and the resume save's dive: 5 carried at spawn, not 25 at up (got %s)" % [d.get("dive")])
	check(d.get("meta", {}).get("difficulty") == "hard", "...with a live meta (the hard tier)")
	Game.reset_for_tests()
	Game.store.dir = TMP
	check(Game.load_slot(1) == SaveStore.Found.USABLE and _warnings.take() == 0, "reload: USABLE, no warning")
	check(Game.slot.difficulty == &"hard" and Game.slot.has_flag(&"met_glim"), "...the difficulty and the flag are kept")
	check(Game.dive.carried == 5, "...carried is what the resume save held: 5 (got %d)" % Game.dive.carried)
	check(Game.dive.respawn_room == &"m1_shaft" and Game.dive.respawn_entry == &"spawn" and Game.slot.resume_room == &"m1_shaft" and Game.slot.resume_entry == &"spawn", "...and the respawn and resume points are the resume save's: m1_shaft / spawn")
	# The load took the snapshot from the file, so a progress save in the next session keeps it too.
	Game.dive.add_carried(40)
	Game.dive.set_respawn(&"m1_shaft", &"down")
	Game.set_difficulty(&"easy")
	d = _parsed(_slot())
	check(d.get("dive") == {"carried": 5.0, "respawn_entry": "spawn", "respawn_room": "m1_shaft"} and d.get("slot", {}).get("resume_entry") == "spawn" and d.get("slot", {}).get("difficulty") == "easy", "a progress save after the reload still writes the loaded dive and resume point (got %s)" % [d.get("dive")])
	# A resume save then moves both.
	check(Game.save_now() == OK, "(a resume save now)")
	d = _parsed(_slot())
	check(d.get("dive") == {"carried": 45.0, "respawn_entry": "down", "respawn_room": "m1_shaft"} and d.get("slot", {}).get("resume_entry") == "down", "...and a resume save does move them: 45 carried at down (got %s)" % [d.get("dive")])
	Game.dive.add_carried(1)
	Game.save_progress()
	check(_parsed(_slot()).get("dive", {}).get("carried") == 45.0, "...which is what the next progress save keeps (45, not 46)")


func _test_progress_save_without_resume() -> void:
	_fresh()
	Game.load_slot(1)
	Game.dive.add_carried(9)
	Game.dive.set_respawn(&"m1_shaft", &"up")
	Game.set_difficulty(&"easy")
	var d := _parsed(_slot())
	check(d.has("dive") and d["dive"] == null and _text(_slot()).contains("\"dive\": null"), "a progress save with no resume save before it writes \"dive\": null")
	check(d.get("slot", {}).get("resume_room") == "" and d.get("slot", {}).get("resume_entry") == "" and d.get("slot", {}).get("difficulty") == "easy", "...and an empty resume point, with the easy tier")
	Game.reset_for_tests()
	Game.store.dir = TMP
	check(Game.load_slot(1) == SaveStore.Found.USABLE and _warnings.take() == 0, "...it loads USABLE, with no warning")
	check(Game.dive.carried == 0 and Game.dive.respawn_room == &"" and Game.dive.respawn_entry == &"" and Game.slot.difficulty == &"easy", "...as a fresh dive at the dive's start: 0 carried, no respawn point, the tier kept")
	Game.dive.add_carried(3)
	Game.save_progress()
	check(_parsed(_slot()).has("dive") and _parsed(_slot())["dive"] == null, "...and a progress save after that load still writes \"dive\": null")
	# D5: no dive snapshot, but the slot has a resume point: a fresh dive that starts there.
	_fresh()
	_put(_slot(), '{"version": 1, "meta": {}, "slot": {"best_chain": 7, "deaths": 1, "depth": 2, "difficulty": "hard", "flags": [], "play_time": 300, "resume_entry": "spawn", "resume_room": "m1_shaft", "visited": []}, "dive": null}')
	check(Game.load_slot(1) == SaveStore.Found.USABLE and _warnings.take() == 0, "a file with \"dive\": null and a resume point loads clean")
	check(Game.dive.carried == 0 and Game.dive.respawn_room == &"m1_shaft" and Game.dive.respawn_entry == &"spawn", "...as a fresh dive whose respawn point is the slot's resume point (got '%s' / '%s')" % [Game.dive.respawn_room, Game.dive.respawn_entry])


## D6: the snapshot is retaken only by a resume save that succeeded.
func _test_failed_resume_then_progress() -> void:
	_fresh()
	Game.load_slot(1)
	Game.dive.set_respawn(&"m1_shaft", &"spawn")
	Game.dive.add_carried(5)
	Game.save_now()
	Game.dive.set_respawn(&"m1_shaft", &"up")
	Game.dive.add_carried(20)
	Game.store.dir = TMP.path_join("missing")
	_events.clear()
	var err := Game.save_now()
	Game.store.dir = TMP
	check(err != OK and _events.size() == 1 and _events[0][0] == "fail" and _warnings.take() == 1, "(setup) a resume save into a missing folder fails (got %s)" % error_string(err))
	Game.slot.record_chain(8)
	check(Game.save_progress() == OK, "a progress save after it succeeds")
	var d := _parsed(_slot())
	check(d.get("slot", {}).get("best_chain") == 8.0, "...with the live progress (best chain 8)")
	check(d.get("slot", {}).get("resume_entry") == "spawn" and d.get("dive") == {"carried": 5.0, "respawn_entry": "spawn", "respawn_room": "m1_shaft"}, "...and the old resume point and the old dive: the failed resume save moved neither (got %s, %s)" % [d.get("slot", {}).get("resume_entry"), d.get("dive")])


func _test_failure_signal() -> void:
	_fresh()
	Game.load_slot(1)
	Game.slot.record_chain(2)
	var missing := TMP.path_join("missing")
	Game.store.dir = missing
	var err := Game.save_now()
	check(err != OK, "a folder that doesn't exist: save_now() returns an error (%s)" % error_string(err))
	check(_events == [["fail", 1, err]], "...emits save_failed(1, err) once, with that error, and save_succeeded never (got %s)" % [_events])
	check(_warnings.take() == 1, "...warns once")
	check(not DirAccess.dir_exists_absolute(missing), "...and creates no folder (1.4 D5)")
	_events.clear()
	err = Game.save_progress()
	check(err != OK and _events == [["fail", 1, err]] and _warnings.take() == 1, "save_progress() fails the same way: an error, save_failed(1, err) once, one warning")
	Game.store.dir = TMP
	_events.clear()
	check(Game.save_now() == OK and _events == [["ok", 1]], "...and with the folder back the next save succeeds: a failure never stops later saves")


## A folder that refuses new files, then a .bak that refuses a write: where the platform has such
## permissions and the user isn't root (skipped otherwise, as test_state's unopenable file is).
func _test_read_only() -> void:
	_fresh()
	if OS.get_name() == "Windows":
		print("ok   (read-only folder: not checked on Windows)")
		return
	var ro := TMP.path_join("ro")
	DirAccess.make_dir_recursive_absolute(ro)
	_put(ro.path_join("slot_1.json"), GOOD)
	FileAccess.set_unix_permissions(ro, 365)  # r-xr-xr-x
	if FileAccess.open(ro.path_join("probe"), FileAccess.WRITE) != null:
		FileAccess.set_unix_permissions(ro, 493)
		DirAccess.remove_absolute(ro.path_join("probe"))
		print("ok   (read-only folder: not checked here; this user can write to one)")
		return
	Game.store.dir = ro
	check(Game.load_slot(1) == SaveStore.Found.USABLE and Game.slot.best_chain == 7, "(setup) the slot in a read-only folder loads")
	Game.slot.record_chain(30)
	var err := Game.save_now()
	check(err != OK and _events == [["fail", 1, err]] and _warnings.take() == 1, "a save into a read-only folder returns an error, emits save_failed(1, err) once and warns once (got %s, %s)" % [error_string(err), _events])
	FileAccess.set_unix_permissions(ro, 493)
	check(_text(ro.path_join("slot_1.json")) == GOOD and DirAccess.get_files_at(ro) == PackedStringArray(["slot_1.json"]), "...and the existing slot file is byte for byte as it was, alone in the folder (got %s)" % [DirAccess.get_files_at(ro)])

	# The backup step fails after .tmp was written and verified: .tmp is removed, nothing else moves.
	_fresh()
	_put(_slot(), GOOD)
	_put(_slot() + ".bak", "older backup")
	FileAccess.set_unix_permissions(_slot() + ".bak", 292)  # r--r--r--
	Game.load_slot(1)
	Game.slot.record_chain(30)
	err = Game.save_now()
	check(err != OK and _events == [["fail", 1, err]] and _warnings.take() == 1, "a .bak that can't be written: the save returns an error, emits save_failed once and warns once (got %s)" % error_string(err))
	check(_text(_slot()) == GOOD and _text(_slot() + ".bak") == "older backup" and not _has(_slot() + ".tmp"), "...the main file and the .bak are byte for byte as they were, and the .tmp is removed")
	_unlock(_slot() + ".bak")


func _test_verify_file() -> void:
	_fresh()
	var path := TMP.path_join("probe.json")
	var text := '{"a": [1, 2], "b": "ember"}'
	_put(path, text)
	check(SaveStore.verify_file(path, text), "verify_file(): true for a file holding exactly the written text")
	_put(path, text.left(12))
	check(not SaveStore.verify_file(path, text), "...false for a truncated file")
	_put(path, text + " ")
	check(not SaveStore.verify_file(path, text), "...false for a file with one byte more")
	_put(path, "not json")
	check(not SaveStore.verify_file(path, "not json"), "...false for text that isn't JSON, even when the file holds exactly it")
	_put(path, "")
	check(not SaveStore.verify_file(path, ""), "...false for an empty file")
	DirAccess.remove_absolute(path)
	check(not SaveStore.verify_file(path, text), "...and false for a missing file, with no ERROR")


## D7: until boot(), load_slot() or new_game(), a save does nothing at all.
func _test_unarmed() -> void:
	_fresh()
	_fill()
	for save: Callable in [Game.save_now, Game.save_progress]:
		var err: Error = save.call()
		check(err == ERR_UNCONFIGURED, "unarmed (after reset_for_tests): %s() returns ERR_UNCONFIGURED (got %s)" % [save.get_method(), error_string(err)])
	check(_events.is_empty() and _warnings.take() == 0, "...emits nothing and warns nothing")
	check(DirAccess.get_files_at(TMP).is_empty(), "...writes nothing (TMP holds %s)" % [DirAccess.get_files_at(TMP)])
	check(Game.slot.resume_room == &"" and Game.slot.resume_entry == &"", "...and changes no state: not even the slot's resume point (the dive's respawn point is set)")
	Game.set_difficulty(&"easy")
	check(Game.slot.difficulty == &"easy" and DirAccess.get_files_at(TMP).is_empty() and _events.is_empty(), "Game.set_difficulty() unarmed changes the tier in memory and writes nothing")


func _test_delete_slot() -> void:
	_fresh()
	for suffix: String in ["", ".bak", ".tmp"]:
		_put(_slot() + suffix, GOOD)
	_put(_slot(2), GOOD)
	check(Game.delete_slot(1) == OK, "delete_slot(1) returns OK")
	check(not _has(_slot()) and not _has(_slot() + ".bak") and not _has(_slot() + ".tmp"), "...and removes the slot's three files")
	check(_text(_slot(2)) == GOOD, "...leaving slot 2 alone")
	check(Game.delete_slot(1) == OK and Game.store.delete_slot(3) == OK, "...on an empty slot it returns OK: a missing file is no error")
	check(_warnings.take() == 0 and _events.is_empty(), "...with no warning and no signal")
	# Deleting the active slot drops what its last resume save held.
	_fresh()
	_put(_slot(), GOOD)
	Game.load_slot(1)
	Game.delete_slot(1)
	Game.save_progress()
	var d := _parsed(_slot())
	check(d.has("dive") and d["dive"] == null and d.get("slot", {}).get("resume_room") == "", "deleting the active slot drops its resume snapshot: the next progress save writes \"dive\": null and no resume point")
	_fresh()
	_put(_slot(), GOOD)
	_put(_slot(2), GOOD)
	Game.load_slot(1)
	Game.delete_slot(2)
	Game.save_progress()
	check(_parsed(_slot()).get("dive") == {"carried": 5.0, "respawn_entry": "spawn", "respawn_room": "m1_shaft"}, "...deleting another slot keeps the active slot's snapshot (5 carried at spawn)")


## AC7, D12: a dev session reads and writes no slot file.
func _test_detached() -> void:
	_fresh()
	_put(_slot(), GOOD)
	check(Game.load_slot(1) == SaveStore.Found.USABLE and Game.slot.best_chain == 7, "(setup) armed on a good file: best chain 7")
	var lines := SaveLines.new()
	OS.add_logger(lines)
	Game.detach_slot()
	Game.detach_slot()
	OS.remove_logger(lines)
	check(lines.take() == PackedStringArray(["[save] slot: detached for this session; no slot file is read or written"]), "detach_slot() logs once, however often it is called")
	Game.slot.record_chain(40)
	for save: Callable in [Game.save_now, Game.save_progress]:
		var err: Error = save.call()
		check(err == ERR_UNCONFIGURED, "detached: %s() returns ERR_UNCONFIGURED (got %s)" % [save.get_method(), error_string(err)])
	check(_text(_slot()) == GOOD and DirAccess.get_files_at(TMP) == PackedStringArray(["slot_1.json"]), "...and the file is byte for byte as it was, alone in the folder")
	check(Game.load_slot(1) == SaveStore.Found.MISSING, "detached: load_slot(1) returns MISSING, though the file is there")
	check(Game.slot.best_chain == 0 and Game.dive.carried == 0 and Game.dive.respawn_room == &"", "...leaves the defaults in memory")
	check(Game.save_now() == ERR_UNCONFIGURED, "...and stays unarmed")
	var made := Game.new_game(1, &"hard")
	check(made == ERR_UNCONFIGURED and Game.slot.difficulty == &"hard" and Game.slot.best_chain == 0, "detached: new_game(1, hard) resets the session to a new hard game and returns ERR_UNCONFIGURED")
	check(Game.save_now() == ERR_UNCONFIGURED and Game.delete_slot(1) == ERR_UNCONFIGURED, "...arms nothing, and delete_slot(1) is refused too")
	check(_text(_slot()) == GOOD and DirAccess.get_files_at(TMP) == PackedStringArray(["slot_1.json"]), "...the file is still byte for byte as it was")
	check(_events.is_empty() and _warnings.take() == 0, "...and all of it without a signal or a warning")
	Game.reset_for_tests()
	Game.store.dir = TMP
	check(Game.load_slot(1) == SaveStore.Found.USABLE and Game.slot.best_chain == 7, "reset_for_tests() attaches again: load_slot(1) reads the file (best chain 7)")
	check(Game.save_now() == OK, "...and saves are armed by that load")


## D11: settings share the verified write and get a signal for a failed one.
func _test_settings_signal() -> void:
	_fresh()
	_settings_fails.clear()
	Game.load_settings()  # no file: the defaults, armed, and a write queued
	await get_tree().process_frame
	check(_has(TMP.path_join("settings.json")) and _settings_fails.is_empty(), "a settings write that succeeds emits no settings_save_failed")
	check(not _has(TMP.path_join("settings.json.tmp")) and not _has(TMP.path_join("settings.json.bak")), "...leaves no .tmp, and settings get no .bak (D11)")
	Game.store.dir = TMP.path_join("missing")
	_warnings.take()
	Game.settings.set_value(&"brightness", 3)
	await get_tree().process_frame
	check(_settings_fails.size() == 1 and _settings_fails[0] != OK, "a failed settings write emits settings_save_failed(err) once (got %s)" % [_settings_fails])
	check(_warnings.take() == 1 and _events.is_empty(), "...with one warning, and no slot signal")
	Game.store.dir = TMP


## boot() loads the slot and arms saves. Last: boot runs once per process.
func _test_boot() -> void:
	_fresh()
	_put(_slot(), GOOD)
	check(Game.save_now() == ERR_UNCONFIGURED, "(before boot: saves are unarmed)")
	Game.boot()
	check(Game.slot.best_chain == 7 and Game.dive.carried == 5 and Game.dive.respawn_room == &"m1_shaft", "boot() loads slot 1 from the folder: best chain 7, 5 carried, respawn in m1_shaft")
	check(Game.active_slot == 1 and _warnings.take() == 0, "...as the active slot, with no warning")
	Game.slot.record_chain(11)
	check(Game.save_now() == OK and _events == [["ok", 1]] and _parsed(_slot()).get("slot", {}).get("best_chain") == 11.0, "...and arms saves: save_now() writes best chain 11")
	await get_tree().process_frame  # boot's settings load queued a write of the defaults: it lands in TMP
	Game.reset_for_tests()
	Game.store.dir = TMP
	check(Game.save_now() == ERR_UNCONFIGURED, "after reset_for_tests() saves are unarmed again, even in a booted process")
	await get_tree().process_frame
