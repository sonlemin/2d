extends Node
## The string table (Story 1.17 AC5, AC6; AR41, AR52, NFR17): the table's shape, that every key is
## registered and current, the English fallback under other locales, every key reference in
## scripts/ and scenes/, the copy rules (UX-DR54–56) and raw text in scenes. tools/export.sh runs
## it in its content step, so a key problem blocks the build. The validators are pure
## (tests/strings_check.gd); each is proven here on a firing sample and a near-miss first.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_strings.gd

const StringsCheck := preload("res://tests/strings_check.gd")
const CSV := "res://text/strings.csv"
const SCRIPTS := "res://scripts"
const SCENES := "res://scenes"
## Non-English locales a player's machine may report (D10): the laptop or a browser may not be en.
const OTHER_LOCALES := ["vi", "de"]

var _fail := 0


func run() -> void:
	_test_samples()
	var rows := _read_csv(CSV)
	check(rows.size() >= 2, "the table reads: %s has a header and rows (%d rows)" % [CSV, rows.size()])
	_report("table", StringsCheck.check_table(rows))
	_report("glyphs", StringsCheck.check_glyphs(rows, TextStyle.font()))
	_report("registered and current", StringsCheck.check_registered(rows, TranslationServer.translate))
	_test_locales(rows)
	_report("copy rules", StringsCheck.check_copy(rows))
	_test_tree(rows)
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func _report(what: String, errors: Array[String]) -> void:
	for e in errors:
		check(false, "%s: %s" % [what, e])
	if errors.is_empty():
		check(true, "%s: no errors" % what)


## FileAccess.get_csv_line() handles quoted commas and newlines, as the importer does. Never
## ConfigFile or JSON.parse_string(): they print ERROR lines that fail the runner.
static func _read_csv(path: String) -> Array:
	var rows := []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return rows
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() == 1 and row[0] == "":
			continue  # the empty line after the last newline
		rows.append(row)
	return rows


## AC6: a key translates to English under each non-English locale, then the locale is restored.
func _test_locales(rows: Array) -> void:
	var was := TranslationServer.get_locale()
	for loc: String in OTHER_LOCALES:
		TranslationServer.set_locale(loc)
		var bad := StringsCheck.check_registered(rows, TranslationServer.translate)
		check(bad.is_empty(), "locale %s: every key still translates to English (%s)" % [loc, bad])
	TranslationServer.set_locale(was)
	check(TranslationServer.get_locale() == was, "the locale is restored (%s)" % was)


func _test_tree(rows: Array) -> void:
	var keys := []
	for i in range(1, rows.size()):
		keys.append(rows[i][0])
	var gd := StringsCheck.files_under(SCRIPTS, ".gd")
	var tscn := StringsCheck.files_under(SCENES, ".tscn")
	# So the scan can't pass on a wrong root or an empty walk.
	check(SCRIPTS + "/actors/player.gd" in gd and SCENES + "/world/world.tscn" in tscn,
			"the scan sees the real tree (%d scripts, %d scenes)" % [gd.size(), tscn.size()])
	var refs := {}
	var scene_errors: Array[String] = []
	for path in gd + tscn:
		var text := FileAccess.get_file_as_string(path)
		if FileAccess.get_open_error() != OK:
			check(false, "scan: %s is unreadable" % path)
			continue
		refs[path] = StringsCheck.refs_in(text, path.ends_with(".gd"))
		if path.ends_with(".tscn"):
			scene_errors.append_array(StringsCheck.check_scene_text(path, text))
	var calls := 0
	for path: String in refs:
		calls += (refs[path] as Array).filter(func(r: Dictionary) -> bool: return r.kind == "call").size()
	check(calls >= 2, "the scan finds the tr() calls (%d)" % calls)
	_report("code scan", StringsCheck.check_refs(refs, keys))
	_report("scene text", scene_errors)


# --- Samples: every validator fires on a sample, and stays quiet on its near-miss ----------------

func _test_samples() -> void:
	var good: Array = [PackedStringArray(["keys", "en"]), PackedStringArray(["POPUP_BANKED", "+%d banked"]),
			PackedStringArray(["MENU_RESUME", "Resume"])]
	check(StringsCheck.check_table(good).is_empty(), "table: a good table passes (%s)" % [StringsCheck.check_table(good)])
	for bad: Array in [
			[["key", "en"], "a wrong header"],
			[["keys", "en", "vi"], "an extra column in the header"],
			[["keys", "en"], "a lower-case key", ["popup_banked", "x"]],
			[["keys", "en"], "a one-segment key", ["POPUP", "x"]],
			[["keys", "en"], "an unlisted prefix", ["SHOP_BUY", "Buy"]],
			[["keys", "en"], "a repeated key", ["MENU_RESUME", "Resume"], ["MENU_RESUME", "Go on"]],
			[["keys", "en"], "an empty en", ["MENU_RESUME", ""]],
			[["keys", "en"], "a trailing space", ["MENU_RESUME", "Resume "]],
			[["keys", "en"], "a missing cell", ["MENU_RESUME"]]]:
		var rows := [PackedStringArray(bad[0])]
		for r in bad.slice(2):
			rows.append(PackedStringArray(r))
		var errs := StringsCheck.check_table(rows)
		check(errs.size() == 1, "table fires on %s (%s)" % [bad[1], errs])

	var font := TextStyle.font()
	var glyphs_ok := [PackedStringArray(["keys", "en"]), PackedStringArray(["MENU_X", "Ça déjà\\nŁódź"])]
	check(StringsCheck.check_glyphs(glyphs_ok, font).is_empty(), "glyphs: Latin-1, Extended-A and an escaped newline pass (%s)" % [StringsCheck.check_glyphs(glyphs_ok, font)])
	var glyphs_bad := [PackedStringArray(["keys", "en"]), PackedStringArray(["MENU_X", "Tiếp tục"]), PackedStringArray(["MENU_Y", "Жить"])]
	var ge := StringsCheck.check_glyphs(glyphs_bad, font)
	check(ge.size() == 6, "glyphs fire on each of ế ụ (stacked Vietnamese marks) and Ж и т ь (Cyrillic) (%d errors: %s)" % [ge.size(), ge])

	var table := {"MENU_A": "Line one\nline two", "MENU_B": "Tab\there"}
	var lookup := func(k) -> String: return table.get(String(k), String(k))
	var reg_rows := [PackedStringArray(["keys", "en"]), PackedStringArray(["MENU_A", "Line one\\nline two"]), PackedStringArray(["MENU_B", "Tab\\there"])]
	check(StringsCheck.check_registered(reg_rows, lookup).is_empty(), "registered: unescaped CSV text equals the translation (%s)" % [StringsCheck.check_registered(reg_rows, lookup)])
	var stale := [PackedStringArray(["keys", "en"]), PackedStringArray(["MENU_A", "Line one\\nline 2"]), PackedStringArray(["MENU_C", "New"])]
	var se := StringsCheck.check_registered(stale, lookup)
	check(se.size() == 2, "registered fires on an edited row (stale .translation) and an unregistered key (%s)" % [se])

	var copy_ok := [PackedStringArray(["keys", "en"]), PackedStringArray(["MENU_RESUME", "Resume"]),
			PackedStringArray(["DEATH_LURKER", "Its eyes were on the ledge"]), PackedStringArray(["NPC_ODA_1", "The red rope holds"]),
			PackedStringArray(["MENU_REDO", "Credits"]), PackedStringArray(["POPUP_BANKED", "+%d banked"])]
	check(StringsCheck.check_copy(copy_ok).is_empty(), "copy: shapes, narrative colour, 'Credits'/'REDO' (not 'red') and %%d pass (%s)" % [StringsCheck.check_copy(copy_ok)])
	for bad: Array in [["MENU_X", "A roguelike descent"], ["MENU_X", "Downwell-like"], ["MENU_X", "100%% done"],
			["MENU_X", "50 percent"], ["DEATH_X", "The red eyes"], ["MENU_X", "Grey ledge"], ["MENU_BLUE_DOOR", "Door"]]:
		var ce := StringsCheck.check_copy([PackedStringArray(["keys", "en"]), PackedStringArray(bad)])
		check(ce.size() == 1, "copy fires on %s = '%s' (%s)" % [bad[0], bad[1], ce])

	var keys := ["POPUP_BANKED", "MENU_RESUME"]
	var gd := "\tFx.popup(p, pos, tr(\"POPUP_BANKED\") % amount, c)\n\t# tr(\"MENU_GONE\") in a comment\n\tconst LINES := {&\"lurker\": \"MENU_RESUME\"}\n\tvar s := str(\"POPUP_X\".length())"
	var refs := StringsCheck.refs_in(gd, true)
	check(refs.map(func(r: Dictionary) -> String: return "%d %s %s" % [r.line, r.kind, r.key]) == ["1 call POPUP_BANKED", "3 data MENU_RESUME", "4 data POPUP_X"],
			"refs_in: a tr() key, a data-table key and any listed-key literal; never a comment or a lower-case literal (%s)" % [refs])
	check(StringsCheck.check_refs({"a.gd": StringsCheck.refs_in(gd.get_slice("\n", 0) + "\n" + gd.get_slice("\n", 2), true)}, keys).is_empty(),
			"check_refs: every reference exists and every key is used")
	for bad: Array in [
			["\tl.text = tr(\"POPUP_BANKD\")\n\tl.text = tr(\"MENU_RESUME\") + tr(\"POPUP_BANKED\")", "a misspelt key"],
			["\tl.text = tr(\"DEATH_%s_LINE\" % cause)\n\tvar a := [\"POPUP_BANKED\", \"MENU_RESUME\"]", "a composed key"],
			["\tl.text = TranslationServer.translate(&\"MENU_NOPE\")\n\tvar a := [\"POPUP_BANKED\", \"MENU_RESUME\"]", "a missing key in TranslationServer.translate()"],
			["\tl.text = tr_n('MENU_RESUME', \"POPUP_BANKED\", n)\n\tvar d := {\"x\": \"DEATH_FALL\"}", "a missing key held as data"],
			["\tl.text = atr(\"POPUP_BANKED\")", "a dead key (MENU_RESUME unused)"]]:
		var ce := StringsCheck.check_refs({"a.gd": StringsCheck.refs_in(bad[0], true)}, keys)
		check(ce.size() == 1, "check_refs fires on %s (%s)" % [bad[1], ce])
	var near := StringsCheck.check_refs({"a.gd": StringsCheck.refs_in("\tl.text = tr(key)\n\tl.text = tr(LINES[cause])\n\tvar a := [\"POPUP_BANKED\", \"MENU_RESUME\"]", true)}, keys)
	check(near.is_empty(), "check_refs: tr() of a variable passes (the data literals carry the keys) (%s)" % [near])
	var tscn_refs := StringsCheck.refs_in("[node name=\"L\" type=\"Label\"]\ntext = \"MENU_RESUME\"\n# not a comment in a scene: \"POPUP_BANKED\"", false)
	check(tscn_refs.size() == 2, "refs_in: a scene's lines are read whole (%s)" % [tscn_refs])

	check(StringsCheck.check_scene_text("a.tscn", "[node name=\"Title\" type=\"Label\"]\ntext = \"Resume\"").size() == 1,
			"scene text fires on text = \"Resume\"")
	check(StringsCheck.check_scene_text("a.tscn", "text = \"x\"\ntext = \"MENU_RESUME\"\ntext = \"+1\"\nname = \"Resume\"\n[node name=\"Resume\" type=\"Label\"]").is_empty(),
			"scene text: one letter, a key, digits and node names pass")
