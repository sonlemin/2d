extends Node
## DevTools' pure parts (Story 1.11 D4, D5, D8, D9): the URL query, the arg grammar and registry,
## each arg's validator, the `--room=` entry pick, the overlay's Clock rows and mode 2's light
## marks. Static calls only:
## no World, and no Game state changes.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_dev_args.gd
## Expected lists are written out here (the known args, Log's categories, the settings keys), so a
## wrong sort or a lost row shows; every "known: …" list is alphabetical (D4).

const Overlays := preload("res://scripts/dev/overlays.gd")
const Spec := preload("res://tests/spec.gd")

var _fail := 0


func run() -> void:
	_test_query_tokens()
	_test_parse()
	_test_chain_values()
	_test_log_names()
	_test_set_values()
	_test_room_entry()
	_test_clock_rows()
	_test_light_marks()
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func _test_query_tokens() -> void:
	for q in ["", "?", "&&", "?&"]:
		check(DevTools.query_tokens(q).is_empty(), "query_tokens('%s') is empty" % q)
	var got := DevTools.query_tokens("?room=perf_worst&chain=5&set=brightness:0&log=lurker%2Cclock")
	check(Array(got) == ["--room=perf_worst", "--chain=5", "--set=brightness:0", "--log=lurker,clock"],
			"query_tokens: the D4 example gives the command-line tokens, %%2C decoded (got %s)" % [got])
	got = DevTools.query_tokens("room=a%3Db&set=x%26y")
	check(Array(got) == ["--room=a=b", "--set=x&y"], "query_tokens: %%3D and %%26 decode inside the value, after the split (got %s)" % [got])
	got = DevTools.query_tokens("?room=a+b")
	check(Array(got) == ["--room=a b"], "query_tokens: + decodes to a space (got %s)" % [got])
	got = DevTools.query_tokens("?chain&room=x")
	check(Array(got) == ["--chain", "--room=x"], "query_tokens: a bare key gives --key (got %s)" % [got])
	got = DevTools.query_tokens("?set=a:1&room=r&set=b:2")
	check(Array(got) == ["--set=a:1", "--room=r", "--set=b:2"], "query_tokens: a repeated set= keeps its order (got %s)" % [got])
	got = DevTools.query_tokens("?=x&a&&b=")
	check(Array(got) == ["--=x", "--a", "--b="], "query_tokens: malformed parts still become tokens, for parse() to report (got %s)" % [got])


func _test_parse() -> void:
	var reg := {
		"room": {help = "", apply = &"", repeat = false},
		"set": {help = "", apply = &"", repeat = true},
	}
	var r := DevTools.parse(PackedStringArray(["res://tests/x.gd", "out.png", "--room=a"]), reg)
	check(r.values == {"room": ["a"]} and r.errors.is_empty(), "parse: tokens without -- are skipped, the runner's test path too (got %s)" % [r])
	r = DevTools.parse(PackedStringArray(["--foo=1"]))
	check(r.errors == ["unknown arg --foo (known: chain, log, room, set)"] and r.values.is_empty(),
			"parse: an unknown arg on ARGS is one error listing the known ones alphabetically (got %s)" % [r.errors])
	r = DevTools.parse(PackedStringArray(["--room=a=b"]), reg)
	check(r.values["room"] == ["a=b"], "parse: --room=a=b splits on the first = only (got %s)" % [r.values])
	r = DevTools.parse(PackedStringArray(["--chain"]))
	check(r.values.get("chain") == [""] and r.errors.is_empty(), "parse: --chain alone has an empty value (got %s)" % [r])
	r = DevTools.parse(PackedStringArray(["--set=a:1", "--set=b:2"]), reg)
	check(r.values["set"] == ["a:1", "b:2"] and r.errors.is_empty(), "parse: a repeated --set keeps both, in order, with no error (got %s)" % [r])
	r = DevTools.parse(PackedStringArray(["--room=a", "--room=b"]), reg)
	check(r.values["room"] == ["b"] and r.errors.size() == 1 and r.errors[0].contains("--room") and r.errors[0].contains("'b'"),
			"parse: a repeated --room keeps the last, with exactly one error naming it (got %s)" % [r])
	r = DevTools.parse(PackedStringArray([]), reg)
	check(r.values.is_empty() and r.errors.is_empty(), "parse: no tokens, no values and no errors")
	check(DevTools.ARGS.keys().all(func(k: Variant) -> bool: return k is String), "ARGS keys are Strings, as the tokens are")
	var script: Script = load("res://scripts/dev/dev_tools.gd")
	var methods := script.get_script_method_list().map(func(m: Dictionary) -> String: return m.name)
	for arg: String in DevTools.ARGS:
		var row: Dictionary = DevTools.ARGS[arg]
		check(row.help is String and row.help != "" and row.repeat is bool and row.apply is StringName and String(row.apply) in methods,
				"ARGS '%s' has help, repeat and an apply method that exists (%s)" % [arg, row.apply])
	check(DevTools.ARGS.keys() == ["log", "set", "room", "chain"], "ARGS apply in the order log, set, room, chain (D4; got %s)" % [DevTools.ARGS.keys()])
	check(DevTools.ARGS["set"].repeat and DevTools.ARGS["log"].repeat and not DevTools.ARGS["room"].repeat and not DevTools.ARGS["chain"].repeat,
			"only set and log may repeat")


func _test_chain_values() -> void:
	for ok_text in ["0", "8", str(ChainState.MAX_CHAIN)]:
		var r := DevTools.chain_value(ok_text)
		check(r[1] == "" and r[0] == ok_text.to_int(), "--chain=%s is %d" % [ok_text, ok_text.to_int()])
	# The 20-digit string must be refused before to_int(), which would print an engine ERROR and
	# fail the runner (the runner is the check for that).
	for bad in ["-1", str(ChainState.MAX_CHAIN + 1), "8x", "x8", "", "12345", "12345678901234567890", "8.0"]:
		var r := DevTools.chain_value(bad)
		check(r[1] != "" and r[0] == 0, "--chain=%s is an error (%s)" % [bad, r[1]])


func _test_log_names() -> void:
	var r := DevTools.log_names("lurker,CLOCK")
	check(r[0] == [Log.LURKER, Log.CLOCK] and r[1].is_empty(), "--log=lurker,CLOCK gives both, any case (got %s)" % [r])
	r = DevTools.log_names(" room , room ")
	check(r[0] == [Log.ROOM] and r[1].is_empty(), "--log: spaces trimmed, a repeat kept once (got %s)" % [r])
	r = DevTools.log_names("nope")
	check(r[0].is_empty() and r[1].size() == 1 and r[1][0].ends_with("(valid: audio, clock, input, lurker, room, save, ui, weaver)"),
			"--log=nope is one error listing the categories alphabetically (got %s)" % [r[1]])
	r = DevTools.log_names("")
	check(r[0].is_empty() and r[1].is_empty(), "--log= gives nothing and no error")
	r = DevTools.log_names("save,,nope,ui")
	check(r[0] == [Log.SAVE, Log.UI] and r[1].size() == 1, "--log: an unknown name is skipped, the valid ones kept (got %s)" % [r])


func _test_set_values() -> void:
	var fake := Settings.SCHEMA.duplicate(true)
	fake[&"fake_bool"] = {default = false, choices = [false, true]}
	var r := DevTools.set_value_of("brightness:3")
	check(r[2] == "" and r[0] == &"brightness" and r[1] == 3 and typeof(r[1]) == TYPE_INT, "--set=brightness:3 gives int 3 (got %s)" % [r])
	for bad in ["brightness:3.0", "brightness:7", "brightness:", "brightness:12345678901234567890", "light_tap_window:0.25", "light_tap_window:x"]:
		r = DevTools.set_value_of(bad)
		check(r[2] != "" and r[0] == &"", "--set=%s is an error (%s)" % [bad, r[2]])
	r = DevTools.set_value_of("light_tap_window:0.2")
	check(r[2] == "" and typeof(r[1]) == TYPE_FLOAT and r[1] == 0.2, "--set=light_tap_window:0.2 gives float 0.2 (got %s)" % [r])
	r = DevTools.set_value_of("light_tap_window:0.20")
	check(r[2] == "" and r[1] == 0.2, "...and 0.20 is the same value")
	for b in ["true", "false"]:
		r = DevTools.set_value_of("fake_bool:" + b, fake)
		check(r[2] == "" and typeof(r[1]) == TYPE_BOOL and r[1] == (b == "true"), "--set=fake_bool:%s gives a bool, with a schema that has it (got %s)" % [b, r])
	r = DevTools.set_value_of("fake_bool:1", fake)
	check(r[2] != "", "--set=fake_bool:1 is an error: a bool is only true or false (%s)" % r[2])
	r = DevTools.set_value_of("fake_bool:true")
	check(r[2].begins_with("--set: no setting 'fake_bool'"), "...and with the real schema fake_bool is an unknown key (%s)" % r[2])
	r = DevTools.set_value_of("nope:1")
	check(r[2] != "" and r[2].ends_with("(keys: brightness (0, 1, 2, 3), light_tap_window (0.12, 0.2, 0.3))"),
			"--set=nope:1 is an error listing every key and its choices, sorted (got %s)" % r[2])
	r = DevTools.set_value_of("brightness")
	check(r[2] != "" and r[2].contains("<key>:<value>"), "--set=brightness (no ':') is an error (%s)" % r[2])
	var odd := {&"name": {default = "x", choices = ["x"]}}
	r = DevTools.set_value_of("name:x", odd)
	check(r[2].contains("can't be set from the command line"), "a String setting can't be set from the command line (%s)" % r[2])


func _test_room_entry() -> void:
	var picks := [
		[[&"spawn", &"down"], &"spawn"],
		[[&"down", &"spawn", &"up"], &"spawn"],
		[[&"up", &"down"], &"up"],
		[[&"down", &"up"], &"up"],
		[[&"down"], &"down"],
	]
	for p: Array in picks:
		var r := DevTools.pick_entry(p[0])
		check(r[0] == p[1] and r[1] == "", "pick_entry(%s) is %s" % [p[0], p[1]])
	var none := DevTools.pick_entry([])
	check(none[0] == &"" and none[1] != "", "pick_entry([]) is an error (%s)" % none[1])
	var known := [&"t_swap_b", &"m1_shaft", &"a_room"]
	var r := DevTools.room_entry("nope", {known = false, entries = [], errors = []}, known)
	check(r[1] == "--room: no room 'nope' (known: a_room, m1_shaft, t_swap_b)", "an unknown id lists the known ids alphabetically (got %s)" % r[1])
	r = DevTools.room_entry("bad", {known = true, entries = [], errors = ["e1", "e2", "e3", "e4"]}, known)
	check(r[1] == "--room: room 'bad' is invalid: e1; e2; e3", "an invalid room gives its first 3 errors (got %s)" % r[1])
	r = DevTools.room_entry("t_swap_b", {known = true, entries = [&"up"], errors = []}, known)
	check(r == [&"up", ""], "a valid room with only an up exit starts at up (got %s)" % [r])


func _test_clock_rows() -> void:
	var now := 10_000
	var rows := Overlays.clock_rows({&"hitstop": {scale = 0.05, ms = now}}, {&"hitstop": 0.05}, now)
	check(rows == [{id = &"hitstop", scale = 0.05, live = true}], "clock_rows: a live id is a normal row (got %s)" % [rows])
	rows = Overlays.clock_rows({&"hitstop": {scale = 0.05, ms = now - 499}}, {}, now)
	check(rows == [{id = &"hitstop", scale = 0.05, live = false}], "clock_rows: not live, seen 499 ms ago: a greyed row (got %s)" % [rows])
	rows = Overlays.clock_rows({&"hitstop": {scale = 0.05, ms = now - 500}}, {}, now)
	check(rows.is_empty(), "clock_rows: seen 500 ms ago: no row (got %s)" % [rows])
	check(Overlays.clock_rows({}, {}, now).is_empty(), "clock_rows: nothing seen, no rows")
	rows = Overlays.clock_rows({&"zeta": {scale = 0.5, ms = now}, &"alpha": {scale = 0.2, ms = now - 100}}, {&"zeta": 0.5}, now)
	check(rows.map(func(r: Dictionary) -> String: return String(r.id)) == ["alpha", "zeta"] and not rows[0].live and rows[1].live,
			"clock_rows: ids sorted as Strings, each live or greyed on its own (got %s)" % [rows])
	rows = Overlays.clock_rows({&"hitstop": {scale = 0.05, ms = now - 200}}, {&"hitstop": 0.5}, now)
	check(rows == [{id = &"hitstop", scale = 0.5, live = true}], "clock_rows: a live id shows its live scale (got %s)" % [rows])


## Mode 2 draws Lurker.senses()'s rule (review of 1.11): reach = radius × NOTICE_FACTOR, and only a
## light at or past NOTICE_MIN_RADIUS can be noticed. The base light is safe by the GDD (Spec).
func _test_light_marks() -> void:
	var m := Overlays.light_marks(Spec.BASE_LIGHT)
	check(not m.noticeable and is_equal_approx(m.reach, Spec.BASE_LIGHT * Lurker.NOTICE_FACTOR),
			"light_marks: the %d px base light can't be noticed, reach %d px (got %s)" % [Spec.BASE_LIGHT, Spec.BASE_LIGHT * Lurker.NOTICE_FACTOR, m])
	m = Overlays.light_marks(Lurker.NOTICE_MIN_RADIUS - 0.5)
	check(not m.noticeable, "light_marks: half a pixel below the notice radius can't be noticed (got %s)" % [m])
	m = Overlays.light_marks(Lurker.NOTICE_MIN_RADIUS)
	check(m.noticeable and is_equal_approx(m.radius, Lurker.NOTICE_MIN_RADIUS) and is_equal_approx(m.reach, Lurker.NOTICE_MIN_RADIUS * Lurker.NOTICE_FACTOR),
			"light_marks: at the notice radius it can, reach radius × %.1f (got %s)" % [Lurker.NOTICE_FACTOR, m])
	check(Lurker.NOTICE_MIN_RADIUS >= Spec.NOTICE_MIN_RADIUS, "(premise) the lurker's notice radius is the GDD floor or later (%d >= %d)" % [Lurker.NOTICE_MIN_RADIUS, Spec.NOTICE_MIN_RADIUS])
