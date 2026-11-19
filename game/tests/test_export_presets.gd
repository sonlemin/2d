extends Node
## The committed export presets (AR51, NFR7; Story 1.13 D2). tools/export.sh calls the presets by
## name, and a laptop editor that opens Project → Export rewrites the whole file, so this pins
## what must survive a re-save: the four names and platforms, the filters, single-threaded web,
## the PCK beside the desktop binary, and no machine paths or custom templates.
## The filter checks run the exporter's own matcher, String.matchn(), over the real files under
## rooms/, tests/ and scripts/dev/, reading the filters from the file itself, so a filter edit
## changes what the model exports. tools/export.sh lists the real PCKs (AC3); the two agree.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_export_presets.gd

const PATH := "res://export_presets.cfg"
## AC1, in [preset.N] order. `release` presets drop the dev and test content (AR51).
const PRESETS: Array[Dictionary] = [
	{name = "Windows", platform = "Windows Desktop", release = true},
	{name = "Linux", platform = "Linux", release = true},
	{name = "Web", platform = "Web", release = true},
	{name = "Web debug", platform = "Web", release = false},
]
## D2: in matchn `*` crosses `/` and `**` is a plain `*`, so this is "every room file at any
## depth"; `rooms/**/*.txt` would skip a room placed directly in rooms/.
const ROOM_INCLUDE := "rooms/*.txt"
const RELEASE_EXCLUDES := ["rooms/dev/*", "scripts/dev/*", "tests/*"]
## Web debug keeps rooms/dev/ (perf_worst, Story 1.12) and scripts/dev/: DevTools' path-string
## load() in world.gd has no null check (1.11 D2).
const DEBUG_EXCLUDES := ["tests/*"]
## Single-threaded web (no SharedArrayBuffer, so no COOP/COEP and no itch.io origin change):
## these pick the web_nothreads_* templates. Written explicitly, never left to a default.
const WEB_FALSE := ["variant/extensions_support", "variant/thread_support", "progressive_web_app/enabled"]
const WALK_ROOTS := ["res://rooms", "res://tests", "res://scripts/dev"]
## Files the walk must find, so an empty or wrong walk can't pass every filter check vacuously.
const SENTINELS := ["rooms/l1/m1_shaft.txt", "rooms/dev/perf_worst.txt", "scripts/dev/dev_tools.gd", "tests/runner.gd"]
## The files the model judges: room text (a non-resource, in only through the include filter)
## and scripts and scenes (resources, in through all_resources). .uid and .import files are the
## engine's own business.
const MODELLED := ["txt", "gd", "tscn"]

var _fail := 0


func run() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(PATH)
	check(err == OK, "%s loads (%s)" % [PATH, error_string(err)])
	if err != OK:
		print("FAILED (%d)" % _fail)
		return
	_test_numbering(cfg)
	for i in PRESETS.size():
		_test_preset(cfg, i)
	_test_model()
	_test_filters(cfg)
	if _fail == 0:
		print("PASS")
	else:
		print("FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


# --- Pure: the exporter's filter rule (D2; editor_export_platform.cpp, String::matchn) ----------

## Comma-separated, trimmed, empty parts dropped.
static func patterns(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for p in text.split(","):
		var t := p.strip_edges()
		if t != "":
			out.append(t)
	return out


## The exporter tries each pattern on both `res://path` and `path` (probed: "res://rooms/dev/x.txt"
## does not matchn "rooms/dev/*", the plain form does).
static func matches_any(rel: String, list: PackedStringArray) -> bool:
	for p in list:
		if ("res://" + rel).matchn(p) or rel.matchn(p):
			return true
	return false


## Whether `rel` (a path under res://, without the prefix) lands in an all_resources PCK: a
## resource is in already, any other file only when an include pattern takes it; the exclude
## filter runs second and wins.
static func exported(rel: String, include: PackedStringArray, exclude: PackedStringArray) -> bool:
	var taken := rel.get_extension() != "txt" or matches_any(rel, include)
	return taken and not matches_any(rel, exclude)


# --- Cases ------------------------------------------------------------------------------------

## D2: loading stops at the first missing number, so a gap hides every later preset.
func _test_numbering(cfg: ConfigFile) -> void:
	var present := []
	for i in PRESETS.size():
		present.append(cfg.has_section("preset.%d" % i))
	check(present.all(func(p: bool) -> bool: return p) and not cfg.has_section("preset.%d" % PRESETS.size()),
			"four presets, preset.0 to preset.3, and no preset.4 (got %s, preset.4 %s)" % [present, cfg.has_section("preset.4")])


func _test_preset(cfg: ConfigFile, i: int) -> void:
	var want: Dictionary = PRESETS[i]
	var sec := "preset.%d" % i
	var opt := sec + ".options"
	var label := "preset.%d (%s)" % [i, want.name]
	if not cfg.has_section(sec):
		check(false, "%s exists" % label)
		return
	var name_got: String = str(cfg.get_value(sec, "name", ""))
	var platform_got: String = str(cfg.get_value(sec, "platform", ""))
	check(name_got == want.name and platform_got == want.platform,
			"%s: export.sh calls it by name; platform %s (got '%s', '%s')" % [label, want.platform, name_got, platform_got])
	var filter_got: String = str(cfg.get_value(sec, "export_filter", ""))
	check(filter_got == "all_resources", "%s: export_filter is all_resources (got '%s')" % [label, filter_got])
	var include := patterns(str(cfg.get_value(sec, "include_filter", "")))
	check(ROOM_INCLUDE in include, "%s: include_filter holds %s (got %s)" % [label, ROOM_INCLUDE, include])
	var exclude := Array(patterns(str(cfg.get_value(sec, "exclude_filter", ""))))
	exclude.sort()
	var want_ex: Array = RELEASE_EXCLUDES if want.release else DEBUG_EXCLUDES
	check(exclude == want_ex, "%s: exclude_filter is exactly %s (got %s)" % [label, want_ex, exclude])
	# D2: a missing or empty options section prints an engine ERROR and the export still exits 0.
	var has_opts := cfg.has_section(opt)
	var keys := cfg.get_section_keys(opt) if has_opts else PackedStringArray()
	check(not keys.is_empty(), "%s: [%s] exists with at least one key (got %d keys)" % [label, opt, keys.size()])
	if want.platform == "Web":
		for key: String in WEB_FALSE:
			var v: Variant = cfg.get_value(opt, key, null) if has_opts else null
			check(v is bool and v == false, "%s: %s=false, written explicitly (got %s)" % [label, key, v])
	else:
		var v: Variant = cfg.get_value(opt, "binary_format/embed_pck", null) if has_opts else null
		check(v is bool and v == false, "%s: embed_pck=false, so the PCK sits beside the binary for the release check (got %s)" % [label, v])
	_test_no_machine_paths(cfg, label, sec, opt)


## AC1: builds come from the server's pinned templates and its builds/ folder, never a path
## on the machine that last saved the file (C:/… from a Windows editor counts).
func _test_no_machine_paths(cfg: ConfigFile, label: String, sec: String, opt: String) -> void:
	var path_got: String = str(cfg.get_value(sec, "export_path", ""))
	check(not path_got.is_absolute_path(), "%s: no absolute export_path (got '%s')" % [label, path_got])
	var custom := []
	var keys_found := []
	for s in [sec, opt]:
		if not cfg.has_section(s):
			continue
		for key in cfg.get_section_keys(s):
			var v: Variant = cfg.get_value(s, key, null)
			if key.begins_with("custom_template/") and str(v) != "":
				custom.append("%s=%s" % [key, v])
			if (key.ends_with("encryption_key") and str(v) != "") or (key in ["encrypt_pck", "encrypt_directory"] and v is bool and v):
				keys_found.append("%s=%s" % [key, v])
	check(custom.is_empty(), "%s: no custom_template/* path (got %s)" % [label, custom])
	check(keys_found.is_empty(), "%s: no encryption (got %s)" % [label, keys_found])


## The model on samples, so a broken model can't make _test_filters pass (D2's rules).
func _test_model() -> void:
	var inc := patterns(" rooms/*.txt ,")
	var rel := patterns("rooms/dev/*, tests/*, scripts/dev/*")
	check(inc == PackedStringArray(["rooms/*.txt"]), "model: patterns are comma-separated, trimmed, empties dropped")
	check(exported("rooms/zz_top.txt", inc, rel) and exported("rooms/l1/m1_shaft.txt", inc, rel),
			"model: rooms/*.txt takes a room at any depth, directly in rooms/ too")
	check(not exported("rooms/zz_top.txt", patterns("rooms/**/*.txt"), rel),
			"model: rooms/**/*.txt skips a room directly in rooms/ (** is a plain *)")
	check(not exported("tests/rooms/swap/t_swap_a.txt", inc, PackedStringArray()),
			"model: matching starts at the path's start, so rooms/*.txt never takes tests/rooms/…")
	check(not exported("rooms/dev/perf_worst.txt", inc, rel) and exported("rooms/dev/perf_worst.txt", inc, patterns("tests/*")),
			"model: exclude runs after include and wins")
	check(exported("scripts/world/world.gd", PackedStringArray(), PackedStringArray()) and not exported("scripts/dev/dev_tools.gd", inc, rel),
			"model: a script is in through all_resources, out when an exclude pattern matches")
	check(exported("ROOMS/L1/X.TXT", inc, PackedStringArray()), "model: matching ignores case")


## D2 3.: every room in every preset, dev rooms in Web debug only, no test file anywhere, and
## DevTools out of every release preset but in Web debug.
func _test_filters(cfg: ConfigFile) -> void:
	var files: Array[String] = []
	for root: String in WALK_ROOTS:
		_walk(root, files)
	var missing := SENTINELS.filter(func(s: String) -> bool: return not s in files)
	check(missing.is_empty(), "the walk sees its sentinels, so it is looking at the real files (missing %s)" % [missing])
	var rooms := files.filter(func(f: String) -> bool: return f.begins_with("rooms/") and not f.begins_with("rooms/dev/") and f.get_extension() == "txt")
	var dev_rooms := files.filter(func(f: String) -> bool: return f.begins_with("rooms/dev/") and f.get_extension() == "txt")
	var tests := files.filter(func(f: String) -> bool: return f.begins_with("tests/"))
	var dev_scripts := files.filter(func(f: String) -> bool: return f.begins_with("scripts/dev/") and f.get_extension() == "gd")
	var bad := {rooms = [], dev_rooms = [], tests = [], dev_scripts = []}
	for i in PRESETS.size():
		var sec := "preset.%d" % i
		var name_i: String = PRESETS[i].name
		var release: bool = PRESETS[i].release
		var inc := patterns(str(cfg.get_value(sec, "include_filter", "")))
		var exc := patterns(str(cfg.get_value(sec, "exclude_filter", "")))
		for f: String in rooms:
			if not exported(f, inc, exc):
				bad.rooms.append("%s: %s" % [name_i, f])
		for f: String in dev_rooms:
			if exported(f, inc, exc) == release:
				bad.dev_rooms.append("%s: %s %s" % [name_i, f, "in" if release else "out"])
		for f: String in tests:
			if exported(f, inc, exc):
				bad.tests.append("%s: %s" % [name_i, f])
		for f: String in dev_scripts:
			if exported(f, inc, exc) == release:
				bad.dev_scripts.append("%s: %s %s" % [name_i, f, "in" if release else "out"])
	check(not rooms.is_empty() and bad.rooms.is_empty(),
			"every room outside rooms/dev/ (%d) is in every preset (out: %s)" % [rooms.size(), bad.rooms])
	check(not dev_rooms.is_empty() and bad.dev_rooms.is_empty(),
			"every rooms/dev/ room (%d) is in Web debug only (wrong: %s)" % [dev_rooms.size(), bad.dev_rooms])
	check(not tests.is_empty() and bad.tests.is_empty(),
			"no tests/ script, scene or room (%d) is in any preset (in: %s)" % [tests.size(), bad.tests])
	check(not dev_scripts.is_empty() and bad.dev_scripts.is_empty(),
			"every scripts/dev/ script (%d) is out of every release preset and in Web debug (wrong: %s)" % [dev_scripts.size(), bad.dev_scripts])


## Every modelled file under `dir`, as a path without res://. Dot folders are skipped, as the
## exporter skips them (and folders holding a .gdignore, of which there are none here).
func _walk(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in MODELLED:
			out.append(dir.path_join(f).trim_prefix("res://"))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_walk(dir.path_join(d), out)
