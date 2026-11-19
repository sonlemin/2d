extends Node
## DevTools' pure parts (Story 1.11 D4, D5, D8, D9; Story 1.12 D1, D7, D8): the URL query, the arg
## grammar and registry, each arg's validator, the `--room=` entry pick, the overlay's Clock rows,
## mode 2's light marks and the summary rows, the glow environment, and the perf run's path and
## frame stats. Static calls only:
## no World, and no Game state changes.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_dev_args.gd
## Expected lists are written out here (the known args, Log's categories, the settings keys), so a
## wrong sort or a lost row shows; every "known: …" list is alphabetical (D4).

const Overlays := preload("res://scripts/dev/overlays.gd")
const PerfRun := preload("res://scripts/dev/perf_run.gd")
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
	_test_glow_values()
	_test_perf_seconds()
	_test_glow_environment()
	_test_path_point()
	_test_stats()
	_test_summary_rows()
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
	check(r.errors == ["unknown arg --foo (known: chain, glow, log, perf, room, set)"] and r.values.is_empty(),
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
	check(DevTools.ARGS.keys() == ["log", "set", "room", "chain", "glow", "perf"], "ARGS apply in the order log, set, room, chain, glow, perf (1.11 D4, 1.12 D1; got %s)" % [DevTools.ARGS.keys()])
	check(DevTools.ARGS["set"].repeat and DevTools.ARGS["log"].repeat and not DevTools.ARGS["room"].repeat and not DevTools.ARGS["chain"].repeat
			and not DevTools.ARGS["glow"].repeat and not DevTools.ARGS["perf"].repeat,
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


# --- Story 1.12: --glow, --perf and the perf run's pure parts ----------------------------------------

## D7: only `on` / `off`, lowercase; anything else is an error listing both.
func _test_glow_values() -> void:
	var r := DevTools.glow_value("on")
	check(r == [true, ""], "--glow=on is true (got %s)" % [r])
	r = DevTools.glow_value("off")
	check(r == [false, ""], "--glow=off is false (got %s)" % [r])
	for bad in ["", "ON", "yes", "1"]:
		r = DevTools.glow_value(bad)
		check(r[0] == false and r[1].contains("on") and r[1].contains("off") and r[1].contains("--glow=%s" % bad),
				"--glow=%s is an error naming on and off (%s)" % [bad, r[1]])


## D1: "" is the 60 s default; a whole number 1-600; the 4-character cap goes first, so a 20-digit
## string never reaches to_int() (which would print an engine ERROR and fail the runner).
func _test_perf_seconds() -> void:
	var r := DevTools.perf_seconds("")
	check(r == [60, ""], "--perf alone is 60 s (got %s)" % [r])
	for ok_text in ["1", "60", "600"]:
		r = DevTools.perf_seconds(ok_text)
		check(r == [ok_text.to_int(), ""], "--perf=%s is %s s (got %s)" % [ok_text, ok_text, r])
	for bad in ["0", "601", "-5", "x", "12345", "12345678901234567890", "6.0"]:
		r = DevTools.perf_seconds(bad)
		check(r[1] != "" and r[0] == 0, "--perf=%s is an error (%s)" % [bad, r[1]])


## D7's starting values: BG_CANVAS (2D glow needs the canvas as the background), glow on, bloom 0
## (bloom 1.0 lifted the whole frame in the probe, breaking the darkness pillar).
func _test_glow_environment() -> void:
	var env := DevTools.glow_environment()
	check(env != null and env.background_mode == Environment.BG_CANVAS, "glow_environment(): background BG_CANVAS")
	check(env.glow_enabled and is_equal_approx(env.glow_intensity, DevTools.GLOW_INTENSITY) and is_equal_approx(env.glow_strength, 1.0),
			"...glow on, intensity %.1f, strength 1.0 (got %s, %.2f, %.2f)" % [DevTools.GLOW_INTENSITY, env.glow_enabled, env.glow_intensity, env.glow_strength])
	check(is_equal_approx(env.glow_bloom, 0.0) and is_equal_approx(env.glow_hdr_threshold, DevTools.GLOW_THRESHOLD)
			and env.glow_blend_mode == Environment.GLOW_BLEND_MODE_ADDITIVE,
			"...bloom 0, threshold %.1f, additive blend (got %.2f, %.2f, %d)" % [DevTools.GLOW_THRESHOLD, env.glow_bloom, env.glow_hdr_threshold, env.glow_blend_mode])
	check(DevTools.glow_environment() != env, "...a fresh Environment per call (one WorldEnvironment per run)")


## D1: a vertical ping-pong from a tick counter, never the wall clock. top 48, bottom 148, 100 px/s
## at 60 ticks/s: the bottom at tick 60, the top again at tick 120.
func _test_path_point() -> void:
	var p := PerfRun.path_point(0, 48.0, 148.0, 100.0, 60)
	check(is_equal_approx(p.x, 48.0) and p.y > 0.0, "path_point: tick 0 is the top, going down (got %s)" % [p])
	p = PerfRun.path_point(30, 48.0, 148.0, 100.0, 60)
	check(is_equal_approx(p.x, 98.0) and is_equal_approx(p.y, 100.0), "...half a second later, 50 px down at +100 px/s (got %s)" % [p])
	p = PerfRun.path_point(60, 48.0, 148.0, 100.0, 60)
	check(is_equal_approx(p.x, 148.0) and p.y > 0.0, "...after span / speed (1 s) it is at the bottom (got %s)" % [p])
	p = PerfRun.path_point(61, 48.0, 148.0, 100.0, 60)
	check(p.x < 148.0 and p.x > 146.0 and is_equal_approx(p.y, -100.0), "...one tick later it is going up (got %s)" % [p])
	p = PerfRun.path_point(120, 48.0, 148.0, 100.0, 60)
	check(is_equal_approx(p.x, 48.0) and p.y > 0.0, "...after 2 × span / speed it is back at the top, going down (got %s)" % [p])
	check(PerfRun.path_point(7, 100.0, 100.0, 100.0, 60) == Vector2(100, 0) and PerfRun.path_point(7, 100.0, 40.0, 100.0, 60) == Vector2(100, 0),
			"...a span of 0 or less stays at the top, still")


func _frames(stats: Dictionary, n: int, dt: int) -> void:
	for i in n:
		PerfRun.add_frame(stats, dt, stats.sum_usec)


## D1: counters and per-second buckets, never a per-frame array. A frame counts in the second it
## starts in; min_fps is the fewest frames in any whole second of the run.
func _test_stats() -> void:
	var st := PerfRun.new_stats(1)
	_frames(st, 60, 16_667)
	var s := PerfRun.summary(st)
	check(s.frames == 60 and absf(s.avg_fps - 60.0) <= 0.5 and s.min_fps == 60 and absf(s.worst_ms - 16.667) < 0.01 and s.slow_frames == 0,
			"60 frames of 16 667 µs: avg ≈ 60, min 60, worst 16.7 ms, none slow (got %s)" % [s])
	st = PerfRun.new_stats(1)
	_frames(st, 30, 16_667)
	PerfRun.add_frame(st, 25_000, 500_000)
	s = PerfRun.summary(st)
	check(s.slow_frames == 1 and is_equal_approx(s.worst_ms, 25.0) and is_equal_approx(s.worst_at_s, 0.5),
			"one 25 000 µs frame at 0.5 s: 1 over 20 ms, the worst 25.0 ms at 0.5 s (got %s)" % [s])
	PerfRun.add_frame(st, 20_000, 525_000)
	check(PerfRun.summary(st).slow_frames == 1, "...a frame of exactly 20 ms is not over (NFR1: no frame over 20 ms)")
	st = PerfRun.new_stats(2)
	_frames(st, 60, 16_667)
	_frames(st, 30, 33_334)
	s = PerfRun.summary(st)
	check(s.frames == 90 and s.min_fps == 30, "a second with only 30 frames gives min 30 fps, by time, not by frame count (got %s)" % [s])
	check(Array(st.buckets) == [60, 30], "...60 frames in second 0 and 30 in second 1 (got %s)" % [st.buckets])
	# At exactly 60 fps, buckets by frame count (every 60 frames) coincide with buckets by time, so
	# the case above can't tell them apart (red check 19). A 50 fps second then a 70 fps one can.
	st = PerfRun.new_stats(2)
	_frames(st, 50, 20_000)
	_frames(st, 70, 14_286)
	s = PerfRun.summary(st)
	check(s.min_fps == 50 and Array(st.buckets) == [50, 70], "a 50 fps second then a 70 fps one: min 50 fps, buckets [50, 70] (counting 60 frames per bucket would say 60; got %s, %s)" % [s.min_fps, st.buckets])
	st = PerfRun.new_stats(1)
	PerfRun.add_frame(st, 16_667, 2_000_000)
	check(Array(st.buckets) == [0], "a frame starting past the run's last second lands in no bucket (got %s)" % [st.buckets])


## D1's summary line, exactly, and D8's rows: split at `;` into at most three, so it fits the
## 480 px screen at size 8.
func _test_summary_rows() -> void:
	var result := {seconds = 60, frames = 3598, avg_fps = 59.93, min_fps = 58, worst_ms = 21.42, worst_at_s = 12.31,
			slow_frames = 2, max_lit = 6, max_sprites = 5, max_over = 0, chain = 20, breaks = 0, deaths = 0, glow = false,
			window = Vector2i(1440, 810), os = "Linux", adapter = "Mesa Intel(R) HD Graphics 620"}
	var text := PerfRun.summary_text(result)
	var want := "perf 60 s: 3598 frames, avg 59.9 fps, min 58 fps, worst 21.4 ms at 12.3 s, 2 over 20 ms; lights max 6/6, sprites max 5, over 0; chain 20, breaks 0, deaths 0; glow off; window 1440x810; Linux, Mesa Intel(R) HD Graphics 620"
	check(text == want, "summary_text is exactly D1's format (got '%s')" % text)
	var rows := Overlays.summary_rows(text)
	check(rows.size() >= 2 and rows.size() <= 3 and "; ".join(rows) == text, "summary_rows: 2-3 rows that rejoin to the whole line (got %s)" % [rows])
	check(rows[0].begins_with("perf 60 s") and Array(rows).all(func(r: String) -> bool: return r.length() <= Overlays.SUMMARY_ROW_CHARS),
			"...the first row starts 'perf 60 s', and each fits %d characters (got %s)" % [Overlays.SUMMARY_ROW_CHARS, Array(rows).map(func(r: String) -> int: return r.length())])
	result.glow = true
	check(PerfRun.summary_text(result).contains("; glow on;"), "...and glow on reads 'glow on'")
	# Review 2026-11-19: Chrome's WebGL adapter name and a 600 s run make parts too long for any
	# `; ` split; overlong rows wrap at a space, and no character is lost.
	result.merge({seconds = 600, frames = 215998, worst_at_s = 512.3, slow_frames = 22, os = "Web",
			adapter = "ANGLE (Intel, Intel(R) UHD Graphics 620 (0x00005917) Direct3D11 vs_5_0 ps_5_0, D3D11)"}, true)
	text = PerfRun.summary_text(result)
	rows = Overlays.summary_rows(text)
	var squash := func(s: String) -> String: return s.replace(";", "").replace(" ", "")
	check(Array(rows).all(func(r: String) -> bool: return r.length() <= Overlays.SUMMARY_ROW_CHARS) and squash.call("".join(rows)) == squash.call(text),
			"summary_rows: a web adapter name and a 600 s run wrap at a space, each row ≤ %d characters, nothing lost (got %s)" % [Overlays.SUMMARY_ROW_CHARS, Array(rows).map(func(r: String) -> int: return r.length())])
	check(Overlays.summary_rows("x".repeat(Overlays.SUMMARY_ROW_CHARS + 5)) == PackedStringArray(["x".repeat(Overlays.SUMMARY_ROW_CHARS), "xxxxx"]),
			"...and a single word wider than a row is cut at %d characters" % Overlays.SUMMARY_ROW_CHARS)
