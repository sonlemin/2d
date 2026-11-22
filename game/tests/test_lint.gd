extends Node
## Architecture lint (AR48, Story 1.9): a text scan of every .gd under game/scripts/ that fails on
## the patterns the architecture forbids. A rule nobody checks gets broken quietly
## (Architecture → Enforcement). Each hit prints `FAIL lint <file>:<line> <rule>`.
## Fix the code, never the lint: a rule that hits correct code is a broken rule, fixed in RULES
## with a sample that shows why; never add an allow-list entry just to get green.
## What a text scan can't see (review covers it): aliasing through a local
## (`var s := Game.settings; s.brightness = 2`), a write through a call's result
## (`Game.slot.room(id).seen = true`), a singleton or method reached by name
## (`Engine.get_singleton("Input")`, `call(name)`), and script embedded in .tscn files (none today).
## Comments never hit: `#` to the end of the line is dropped (outside strings). Identifier rules
## also ignore string contents, so "New Game" in a message or "#07060b" never trips them.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_lint.gd

const ROOT := "res://scripts"
const SPEC := "res://tests/spec.gd"
## Layers above core/ (Architecture → layer rules): core/ never names their classes or paths.
const UPPER_DIRS := ["world", "actors", "objects", "moments", "ui", "audio", "dev"]
## Files that must exist, so a wrong root or an empty walk can't pass as "clean".
const SENTINELS := ["actors/player_input.gd", "core/clock.gd", "rules/tuning.gd"]

## One row per rule. `bare` patterns run on code with comments dropped and string contents blanked;
## `code` patterns run on code with comments dropped and strings kept. Paths are relative to
## scripts/; `only` limits a rule to path prefixes, `skip` exempts prefixes from it, and `allow`
## lists the files or folders where the pattern is the rule's purpose (all prefix matches).
## `rules_purity` and `core_layer` also get a bare pattern of class names built at run time
## (`layer_names()`). Ids are stable: FAIL lines and later stories (1.11's dev_ref line) name them.
## `once` (only dev_ref has it; read with `rule.get("once", {})`) maps a path to [guard, line]: that
## one line is let through once per file, and only right under that guard (Story 1.11 D12).
## (Story D3 sketched rows as {id, re, on, only, allow}; the two pattern lists and `skip` replaced
## `re`/`on` so one rule can check identifiers and path strings together.)
const RULES: Array[Dictionary] = [
	# ADR-4: only Clock writes the time scale (requests multiply, pause with the tree).
	{id = &"time_scale", bare = [r"\bEngine\s*\.\s*(time_scale\s*([-+*/%]|\*\*)?=(?!=)|set_time_scale\s*\()"],
		code = [r"\bEngine\s*\.\s*set(_deferred|_indexed)?\s*\(\s*&?[\x22\x27]time_scale[\x22\x27]"],
		only = [], skip = [], allow = ["core/clock.gd"]},
	# AR34/AR35: gameplay reads PlayerInput intents; raw input only in the sampler, device tracking
	# (1.14) and the UI kit (1.31). Wider than `Input.` (code review of 1.8): InputMap, InputEvent*,
	# the _input callbacks (and Control's gui_input), and `Input` passed around as a value.
	# dev/ too (Story 1.11 D12): DevTools reads only its own dev_* action, ships in no release build
	# and must work while the player is dead, locked or absent; the architecture lets dev/ touch anything.
	{id = &"raw_input", bare = [r"\b(Input|InputMap)\b", r"\bInputEvent\w*",
			r"\bfunc\s+_(input|unhandled_input|unhandled_key_input|shortcut_input|gui_input)\s*\(", r"\bgui_input\b"], code = [],
		only = [], skip = [], allow = ["actors/player_input.gd", "core/devices.gd", "ui/kit/", "dev/"]},
	# AR55: one logger, silent in release builds.
	{id = &"print", bare = [r"(?<![\w.])(@GlobalScope\s*\.\s*)?(print|print_rich|printerr|printraw|prints|printt|print_debug|print_verbose|print_stack)\s*\(",
			r"\bprint_(tree|tree_pretty|orphan_nodes)\s*\("], code = [],
		only = [], skip = [], allow = ["core/log.gd"]},
	# project-context: never free() nodes, always queue_free(); deferred or by name too.
	{id = &"free", bare = [r"\.\s*free\s*\(\s*\)", r"(?<![\w.])free\s*\(\s*\)", r"\bfree\s*\.\s*call"],
		code = [r"\bcall(_deferred)?\s*\(\s*&?[\x22\x27]free[\x22\x27]"],
		only = [], skip = [], allow = []},
	# Actors find each other by group, never by absolute node path.
	{id = &"root_path", bare = [r"\$\s*/root\b", r"\.\s*root\s*\.\s*(get_node|get_node_or_null|find_child|find_children)\s*\("],
		code = [r"[\x22\x27]/root(/|[\x22\x27])"],
		only = [], skip = [], allow = []},
	# project-context: no function keys or raw keycodes (input through actions only; F1/F2/F3 were
	# M1's). Every KEY_*, wider than AR48's KEY_F; glyph tables and rebinding live in the UI kit.
	{id = &"keycode", bare = [r"\bKEY_[A-Z0-9_]+\b"], code = [],
		only = [], skip = [], allow = ["ui/kit/"]},
	# No randomness in level behaviour; camera shake is presentation.
	{id = &"random", bare = [r"(?<![\w.])(@GlobalScope\s*\.\s*)?(randf|randi|randf_range|randi_range|randfn|randomize|seed|rand_from_seed)\s*\(",
			r"\.\s*(pick_random|shuffle)\s*\(", r"\bRandomNumberGenerator\b"], code = [],
		only = [], skip = [], allow = ["world/camera_rig.gd"]},
	# AR58: rules/ is pure: no scene tree, input, engine, OS, clock, files, audio or the autoloads, and
	# no loading except another rules/ script (deferred from 1.4: Node2D, InputEventKey, OS, Time, load).
	# rules/ is the bottom layer, so it also never names a Node class or a class from core/ or above
	# (built at run time from ClassDB and the class_name lines: `layer_names()`).
	{id = &"rules_purity", bare = [
			r"\b(Node\w*|Input\w*|Engine\w*|OS|Time|SceneTree|FileAccess|DirAccess|ResourceLoader|ResourceSaver|ConfigFile|ProjectSettings|DisplayServer|Game|Audio)\b",
			r"(?<![\w.])load\s*\(", r"\bget_tree\s*\("],
		code = [r"\bpreload\s*\(\s*[\x22\x27](?!res://scripts/rules/|\w+\.gd[\x22\x27])"],
		only = ["rules/"], skip = [], allow = []},
	# core/ sits under the scene layers: it never names their classes or autoloads (the bare pattern
	# is built at run time: `layer_names()`) or their paths.
	{id = &"core_layer", bare = [], code = [r"res://(scripts|scenes)/(world|actors|objects|moments|ui|audio|dev)/"],
		only = ["core/"], skip = [], allow = []},
	# AR54: nothing outside dev/ (and tests/, which the lint doesn't scan) references dev/: its
	# paths, DevTools, or any class_name declared under dev/ (`layer_names()`). The one exception
	# is world.gd's guarded path-string load(), exactly that line, once, right under its guard
	# (Story 1.11 D12); _test_tree checks the real world.gd holds it, so a stale entry fails.
	{id = &"dev_ref", bare = [r"\bDevTools\b"], code = [r"res://(scripts|scenes)/dev/"],
		only = [], skip = ["dev/"], allow = [],
		once = {"world/world.gd": ["if OS.is_debug_build():", "add_child(load(\"res://scripts/dev/dev_tools.gd\").new())"]}},
	# AR46 (Story 1.12): every 2D light is a BudgetLight, or the ≤ 6 budget can't see it. A type
	# annotation (`var l: PointLight2D`) is fine; building or extending a raw one is not.
	# .tscn files are never linted, so test_light_budget's scene audit covers the scenes.
	{id = &"raw_light", bare = [r"\bPointLight2D\s*\.\s*new\s*\(", r"\bextends\s+PointLight2D\b"], code = [],
		only = [], skip = [], allow = ["core/budget_light.gd"]},
	# Release exports exclude tests/* (Platform & Build), so game code that loads a test file
	# (Spec included) breaks only in the shipped build (code review of 1.9).
	{id = &"tests_ref", bare = [], code = [r"res://tests/"],
		only = [], skip = [], allow = []},
	# Write state only through rule methods that emit signals, and never replace Game's instances
	# (deferred from 1.4: `Game.settings.brightness = 2` compiled, emitted nothing, never saved).
	# Covers nested fields and indexes, container mutators and reflective `set()` (code review of 1.9).
	{id = &"state_write", bare = [
			r"\bGame\s*\.\s*(settings|slot|dive|tuning|clock|store|display)\s*=(?!=)",
			r"\bGame\s*\.\s*(settings|slot|dive|tuning|display)(\s*\.\s*\w+|\s*\[(?:[^\[\]]|\[[^\[\]]*\])*\])+\s*([-+*/%]|\*\*|<<|>>|&|\||\^)?=(?!=)",
			r"\bGame\s*\.\s*(settings|slot|dive|tuning)(\s*\.\s*\w+|\s*\[(?:[^\[\]]|\[[^\[\]]*\])*\])+\s*\.\s*(append|append_array|push_back|push_front|insert|erase|remove_at|clear|merge|assign|fill|resize|sort|sort_custom|shuffle|reverse|pop_back|pop_front|pop_at)\s*\(",
			r"\bGame\s*\.\s*(settings|slot|dive|tuning)(\s*\.\s*\w+|\s*\[(?:[^\[\]]|\[[^\[\]]*\])*\])*\s*\.\s*set(_indexed|_deferred)?\s*\("],
		code = [], only = [], skip = ["rules/"], allow = []},
	# AR57 (Story 1.16 D9): one accessibility gate. Only Fx (and Settings, which declares them) names
	# the three keys; everything else asks Fx.reduce_flashing() / shake_on() / reduced_motion(), so
	# no effect grows its own toggle. `shake` alone is too common a word (`_shake`, `kick()`), so it
	# is matched only as a settings field or a key string. dev/ is skipped: DevTools sets keys
	# generically through SCHEMA and never names one.
	{id = &"a11y_gate", bare = [r"(?<!Fx\.)\b(reduce_flashing|reduced_motion)\b", r"settings\s*\.\s*shake\b"],
		code = [r"[\x22\x27](reduce_flashing|reduced_motion|shake)[\x22\x27]"],
		only = [], skip = ["dev/"], allow = ["core/fx.gd", "rules/settings.gd"]},
	# AR41 (Story 1.17 D12): player text goes through tr(), so the string table and its scan see it.
	# Fires on a text sink followed, on the same line, by a string literal that holds two letters
	# once its % conversions and escapes are taken out (code review, sonlm: "two lowercase letters in
	# a row" let "On", "OK" and "PAUSED" through and fired on "%dx"). Quiet on a key-shaped literal
	# (UPPER_SNAKE, two segments: `tr("MENU_RESUME")`), on a StringName (`&"dash_speed"` is an id,
	# never text) and on numeric formats ("x%d  +%d", "%dx": one letter). `text =` is a sink with or
	# without a dot, so a Label script's own `text = "Resume"` fires; `var text` / `const text` are
	# declarations. The pattern consumes whole literals after the sink, so a closing quote is never
	# read as an opening one (`tr("POPUP_BANKED") % amount` stays quiet), and reads each conversion
	# atomically, so the `d` of `%d` is never counted as a letter. Any other text literal on a sink
	# line fires (`add_item(tr("MENU_X"), "icon")`): hoist it into a variable. What a text scan
	# can't see (review covers it): text built in a variable on an earlier line, a sink and its
	# literal on different lines (a wrapped call), and a sink reached by name
	# (`call("set_text", …)`). dev/ is skipped: the overlays are debug text, never shipped.
	{id = &"raw_text", bare = [], code = [
			r"(?:(?<!\w)(?<!var\s)(?<!const\s)text\s*\+?=(?!=)|\b(?:tooltip_text|placeholder_text)\s*\+?=(?!=)|\b(?:set_text|popup|draw_string|draw_multiline_string|add_item|append_text|add_text)\s*\()(?:[^\x22\x27]|\x22(?:\\.|[^\x22\\])*\x22|\x27(?:\\.|[^\x27\\])*\x27)*?(?:(?<!&)\x22(?![A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+\x22)(?>%[-+0-9.*]*[sdcfvxXo]|\\.|[^\x22\\\p{L}])*+\p{L}(?>%[-+0-9.*]*[sdcfvxXo]|\\.|[^\x22\\\p{L}])*+\p{L}|(?<!&)\x27(?![A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+\x27)(?>%[-+0-9.*]*[sdcfvxXo]|\\.|[^\x27\\\p{L}])*+\p{L}(?>%[-+0-9.*]*[sdcfvxXo]|\\.|[^\x27\\\p{L}])*+\p{L})"],
		only = [], skip = ["dev/"], allow = []},
]

var _fail := 0
static var _compiled := {}  # pattern String -> RegEx


func run() -> void:
	_test_strip()
	_test_rules()
	_test_layer_names()
	_test_tree()
	_test_spec_citations()
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


# --- The pure core ------------------------------------------------------------------------------

## Drops the `#` comment from one line and blanks string contents, respecting quotes and `\`
## escapes (in every string kind, raw `r"…"` included: an escaped quote never closes it).
## `open` carries a string still open at the end of a line into the next: a `"""` / `'''` block,
## or a `"…\` continued onto the next line. Returns {code, bare, open}: `code` keeps strings,
## `bare` turns their contents into spaces (quotes stay) so columns don't move. `&"…"` and `^"…"`
## are strings like any other. (Story D2 sketched `in_string: bool`; a bool can't say which
## delimiter closes the string.)
static func strip(line: String, open: String) -> Dictionary:
	var code := ""
	var bare := ""
	var i := 0
	var n := line.length()
	while i < n:
		if open != "":
			if line[i] == "\\":
				var step := mini(2, n - i)  # a `\` last on the line continues the string
				code += line.substr(i, step)
				bare += " ".repeat(step)
				i += step
			elif line.substr(i, open.length()) == open:
				code += open
				bare += open
				i += open.length()
				open = ""
			else:
				code += line[i]
				bare += " "
				i += 1
			continue
		var c := line[i]
		if c == "#":
			break
		if c == "\"" or c == "'":
			open = c + c + c if line.substr(i, 3) == c + c + c else c
			code += open
			bare += open
			i += open.length()
			continue
		code += c
		bare += c
		i += 1
	return {code = code, bare = bare, open = open}


## Every rule hit in one file's text, as [{line (1-based), rule}], sorted by line then rule.
## `rel_path` is relative to scripts/ ("actors/player.gd"); `names` maps a rule id to the class
## names it also forbids (`layer_names()`). Pure: no file access, so samples test it directly.
static func lint_text(rel_path: String, text: String, names: Dictionary) -> Array[Dictionary]:
	var rules := _rules_for(rel_path, names)
	var hits: Array[Dictionary] = []
	var open := ""
	var prev := ""  # the previous non-blank line's code, stripped: the guard a `once` line needs
	var used := {}  # rule id -> true once its `once` line has been let through in this text
	var lines := text.replace("\r", "").split("\n")
	for i in lines.size():
		var s := strip(lines[i], open)
		open = s.open
		var code: String = s.code.strip_edges()
		for rule in rules:
			if _matches(rule.bare, s.bare) or _matches(rule.code, s.code):
				if not used.has(rule.id) and _exempt(rule, rel_path, code, prev):
					used[rule.id] = true
					continue
				hits.append({line = i + 1, rule = rule.id})
		if code != "":
			prev = code
	return hits


## Story 1.11 D12: true when this is the rule's one `once` line for this path, right under its
## guard. Both compare stripped code, so indentation and a trailing comment don't matter.
static func _exempt(rule: Dictionary, rel_path: String, code: String, prev: String) -> bool:
	var once: Dictionary = rule.get("once", {})
	if not once.has(rel_path):
		return false
	var pair: Array = once[rel_path]
	return prev == pair[0] and code == pair[1]


## The rules that apply to this path, each with a bare pattern for its run-time class names.
static func _rules_for(rel_path: String, names: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rule in RULES:
		if not rule.only.is_empty() and not _under(rel_path, rule.only):
			continue
		if _under(rel_path, rule.skip) or _under(rel_path, rule.allow):
			continue
		var r: Dictionary = rule.duplicate()
		var extra: PackedStringArray = names.get(rule.id, PackedStringArray())
		if not extra.is_empty():
			r.bare = rule.bare + [r"\b(" + "|".join(extra) + r")\b"]
		out.append(r)
	return out


static func _under(rel_path: String, prefixes: Array) -> bool:
	for p: String in prefixes:
		if rel_path.begins_with(p):
			return true
	return false


static func _matches(patterns: Array, line: String) -> bool:
	for p: String in patterns:
		if not _compiled.has(p):
			var re := RegEx.create_from_string(p)
			assert(re.is_valid(), "test_lint: bad pattern %s" % p)
			_compiled[p] = re
		if (_compiled[p] as RegEx).search(line) != null:
			return true
	return false


# --- Samples: every rule proven to fire, and to stay quiet where it must ------------------------

func _test_strip() -> void:
	var s := strip("var c := \"#07060b\"  # a colour", "")
	check(s.code == "var c := \"#07060b\"  " and s.bare == "var c := \"       \"  ", "strip: a '#' inside a string is not a comment (code '%s', bare '%s')" % [s.code, s.bare])
	s = strip("x = \"a\\\"b\" # c", "")
	check(s.code == "x = \"a\\\"b\" ", "strip: an escaped quote doesn't end the string (code '%s')" % s.code)
	s = strip("var t := \"\"\"print(", "")
	var s2 := strip("still print(1)\"\"\" + print(2)", s.open)
	check(s.open == "\"\"\"" and s2.open == "" and s2.bare.find("print(1)") < 0 and s2.bare.find("print(2)") >= 0,
			"strip: a \"\"\" string spans lines and hides what's inside it, not what follows")
	s = strip("var s := \"\"\"x\\\"\"\"\"; print(1)", "")
	check(s.open == "" and s.bare.find("print(1)") >= 0, "strip: an escaped quote inside \"\"\" doesn't close it early, so the code after it is seen (bare '%s')" % s.bare)
	s = strip("var t := \"abc\\", "")
	s2 = strip("\tprint(1)\"; free()", s.open)
	check(s.open == "\"" and s2.open == "" and s2.bare.find("print(1)") < 0 and s2.bare.find("free()") >= 0,
			"strip: a string continued with a trailing \\ carries into the next line, and ends there")
	s = strip("var r := r\"\\\"\" + str(randf())", "")
	check(s.open == "" and s.bare.find("randf()") >= 0, "strip: in a raw string an escaped quote doesn't close it either (bare '%s')" % s.bare)
	s = strip("## doc comment with print(x)", "")
	check(s.code == "" and s.bare == "", "strip: a doc comment is all comment")


## [rule id, rel path, line, hits?]. For each rule: fires on a covered path, quiet on an allowed
## path, quiet in a comment, and (bare rules) quiet in a string; plus the near-misses that keep
## each pattern honest.
const SAMPLES: Array = [
	[&"time_scale", "world/camera_rig.gd", "\tEngine.time_scale = 1.0", true],
	[&"time_scale", "actors/player.gd", "\tEngine.set_time_scale(0.5)", true],
	[&"time_scale", "actors/player.gd", "\tEngine.time_scale *= 0.5", true],
	[&"time_scale", "actors/player.gd", "\tEngine.set(&\"time_scale\", 0.5)", true],
	[&"time_scale", "core/clock.gd", "\tEngine.time_scale = scale", false],
	[&"time_scale", "actors/player.gd", "\tvar real := delta / maxf(Engine.time_scale, 0.001)", false],
	[&"time_scale", "actors/player.gd", "\tif Engine.time_scale == 1.0:", false],
	[&"time_scale", "actors/player.gd", "\t# Engine.time_scale = 1.0", false],
	[&"time_scale", "actors/player.gd", "\tvar s := \"Engine.time_scale = 1\"", false],
	[&"raw_input", "actors/player.gd", "\tif Input.is_action_pressed(\"jump\"):", true],
	[&"raw_input", "actors/player.gd", "\tvar e: InputEventKey", true],
	[&"raw_input", "ui/screen_router.gd", "func _unhandled_input(event: InputEvent) -> void:", true],
	[&"raw_input", "world/world.gd", "\tInputMap.action_get_events(&\"jump\")", true],
	[&"raw_input", "actors/lurker.gd", "\tvar i := Input", true],
	[&"raw_input", "ui/gutters.gd", "func _gui_input(event):", true],
	[&"raw_input", "ui/gutters.gd", "\tbutton.gui_input.connect(_on_gui)", true],
	[&"raw_input", "actors/player_input.gd", "\tjump_held = Input.is_action_pressed(\"jump\")", false],
	[&"raw_input", "core/devices.gd", "\tvar e: InputEvent", false],
	[&"raw_input", "ui/kit/menu_list.gd", "func _unhandled_input(event: InputEvent) -> void:", false],
	[&"raw_input", "dev/dev_tools.gd", "\tif Input.is_action_just_pressed(&\"dev_overlay\"):", false],
	[&"raw_input", "actors/player.gd", "@onready var input: PlayerInput = $PlayerInput", false],
	[&"raw_input", "actors/player.gd", "\tvar w := PlayerInput.BUFFER_TIME", false],
	[&"raw_input", "actors/player.gd", "\t# Input.is_action_pressed(\"jump\")", false],
	[&"raw_input", "actors/player.gd", "\tLog.info(Log.INPUT, \"Input.is_action\")", false],
	[&"print", "actors/player.gd", "\tprint(\"x\")", true],
	[&"print", "world/world.gd", "\tprinterr(\"x\")", true],
	[&"print", "world/world.gd", "\tprint_rich(\"[b]x\")", true],
	[&"print", "world/world.gd", "\tprint_verbose(\"x\")", true],
	[&"print", "world/world.gd", "\t@GlobalScope.print(\"x\")", true],
	[&"print", "world/world.gd", "\tprint_tree_pretty()", true],
	[&"print", "core/log.gd", "\t\tprint(format(cat, msg))", false],
	[&"print", "actors/player.gd", "\tmy_print(\"x\")", false],
	[&"print", "actors/player.gd", "\tdoc.print(\"x\")", false],
	[&"print", "actors/player.gd", "\t# print(\"debug\")", false],
	[&"print", "actors/player.gd", "\tvar s := \"print(x)\"", false],
	[&"free", "world/world.gd", "\troom.free()", true],
	[&"free", "world/room.gd", "\tfree()", true],
	[&"free", "world/world.gd", "\troom.call_deferred(\"free\")", true],
	[&"free", "world/world.gd", "\troom.free.call_deferred()", true],
	[&"free", "world/world.gd", "\troom.queue_free()", false],
	[&"free", "world/world.gd", "\troom.queue_free.call_deferred()", false],
	[&"free", "world/world.gd", "\t# never room.free()", false],
	[&"free", "world/world.gd", "\tvar s := \".free()\"", false],
	[&"root_path", "actors/lurker.gd", "\tvar w = get_node(\"/root/World\")", true],
	[&"root_path", "actors/lurker.gd", "\tvar w = get_node(^\"/root/World\")", true],
	[&"root_path", "actors/lurker.gd", "\tvar w = get_node('/root')", true],
	[&"root_path", "actors/lurker.gd", "\tvar w = $/root/World", true],
	[&"root_path", "actors/lurker.gd", "\tvar w = get_tree().root.get_node(\"World\")", true],
	[&"root_path", "world/world.gd", "\tget_tree().root.add_child(n)", false],
	[&"root_path", "actors/lurker.gd", "\t# not get_node(\"/root/World\")", false],
	[&"root_path", "core/save_store.gd", "\tvar p := \"user://root/x\"", false],
	[&"keycode", "world/world.gd", "\tif event.keycode == KEY_F1:", true],
	[&"keycode", "world/world.gd", "\tvar k := KEY_ESCAPE", true],
	[&"keycode", "ui/kit/glyph_prompt.gd", "\tKEY_ESCAPE: \"esc\",", false],
	[&"keycode", "world/world.gd", "\t# F1 was KEY_F1 in M1", false],
	[&"keycode", "world/world.gd", "\tvar s := \"KEY_F1\"", false],
	[&"keycode", "world/world.gd", "\tvar MONKEY_FACE := 1", false],
	[&"random", "actors/crawler.gd", "\tvar r := randf()", true],
	[&"random", "actors/crawler.gd", "\tvar r := randi_range(0, 3)", true],
	[&"random", "actors/crawler.gd", "\tvar rng := RandomNumberGenerator.new()", true],
	[&"random", "actors/crawler.gd", "\tvar d = DIRS.pick_random()", true],
	[&"random", "actors/crawler.gd", "\tcells.shuffle()", true],
	[&"random", "actors/crawler.gd", "\tseed(42)", true],
	[&"random", "actors/crawler.gd", "\tvar r := @GlobalScope.randf()", true],
	[&"random", "world/camera_rig.gd", "\toffset = Vector2(randf_range(-_shake, _shake), 0)", false],
	[&"random", "actors/crawler.gd", "\tvar r := my_randf()", false],
	[&"random", "actors/crawler.gd", "\t# randf() would break determinism", false],
	[&"random", "actors/crawler.gd", "\tvar s := \"randf()\"", false],
	[&"rules_purity", "rules/gear.gd", "\tvar n: Node", true],
	[&"rules_purity", "rules/gear.gd", "\tvar n: Node2D", true],
	[&"rules_purity", "rules/gear.gd", "\tvar e: InputEventKey", true],
	[&"rules_purity", "rules/gear.gd", "\tvar t := Time.get_ticks_msec()", true],
	[&"rules_purity", "rules/gear.gd", "\tif OS.is_debug_build():", true],
	[&"rules_purity", "rules/gear.gd", "\tvar x := Engine.time_scale", true],
	[&"rules_purity", "rules/gear.gd", "\tvar s := Game.settings", true],
	[&"rules_purity", "rules/gear.gd", "\tvar src := FileAccess.get_file_as_string(p)", true],
	[&"rules_purity", "rules/gear.gd", "\tvar r := load(path)", true],
	[&"rules_purity", "rules/gear.gd", "const S := preload(\"res://scenes/actors/player.tscn\")", true],
	[&"rules_purity", "rules/gear.gd", "extends Timer", true],
	[&"rules_purity", "rules/gear.gd", "\tget_tree().paused = true", true],
	[&"rules_purity", "rules/gear.gd", "\tResourceSaver.save(r, p)", true],
	[&"rules_purity", "rules/gear.gd", "\tAudio.play(&\"hit\")", true],
	[&"rules_purity", "rules/gear.gd", "\tLog.info(Log.SAVE, \"x\")", true],
	[&"rules_purity", "rules/gear.gd", "\tvar p: Player", true],
	[&"rules_purity", "rules/gear.gd", "const U := preload(\"uid://b3k2\")", true],
	[&"rules_purity", "rules/gear.gd", "const G := preload(\"res://scripts/rules/gear.gd\")", false],
	[&"rules_purity", "rules/gear.gd", "const T := preload(\"tuning.gd\")", false],
	[&"rules_purity", "rules/gear.gd", "## never preload(\"res://scenes/x.tscn\") here", false],
	[&"rules_purity", "rules/gear.gd", "\tvar timer_left := 0.0", false],
	[&"rules_purity", "rules/slot_state.gd", "## New Game and Load reset it in place", false],
	[&"rules_purity", "rules/slot_state.gd", "\tvar label := \"New Game\"", false],
	[&"rules_purity", "rules/gear.gd", "\tvar input_count := 0", false],
	[&"rules_purity", "actors/player.gd", "\tvar n: Node2D", false],
	[&"core_layer", "core/fx.gd", "\tvar p: Player", true],
	[&"core_layer", "core/game.gd", "\tconst W := preload(\"res://scenes/world/world.tscn\")", true],
	[&"core_layer", "core/game.gd", "\tvar s := load(\"res://scripts/actors/player.gd\")", true],
	[&"core_layer", "core/fx.gd", "\tAudio.play(&\"hit\")", true],
	[&"core_layer", "world/world.gd", "\tvar p: Player", false],
	[&"core_layer", "core/fx.gd", "\t# the Player calls this", false],
	[&"core_layer", "core/fx.gd", "\tLog.info(Log.FX, \"Player hit\")", false],
	[&"core_layer", "core/fx.gd", "\tvar player_count := 0", false],
	[&"core_layer", "core/fx.gd", "\tvar s: SaveStore", false],
	[&"core_layer", "core/fx.gd", "# loaded from res://scripts/actors/player.gd", false],
	[&"dev_ref", "world/world.gd", "\tvar d := DevTools.new()", true],
	[&"dev_ref", "world/world.gd", "\tvar d = load(\"res://scripts/dev/dev_tools.gd\").new()", true],
	[&"dev_ref", "dev/overlays.gd", "\tvar d: DevTools", false],
	[&"dev_ref", "world/world.gd", "## DevTools sets it from 1.11", false],
	[&"dev_ref", "core/log.gd", "\tLog.warn(Log.CORE, \"DevTools missing\")", false],
	[&"dev_ref", "world/world.gd", "# see res://scripts/dev/dev_tools.gd", false],
	# Story 1.11 D12: world.gd's one guarded line, and every near-miss of it.
	[&"dev_ref", "world/world.gd", "\tif OS.is_debug_build():\n\t\tadd_child(load(\"res://scripts/dev/dev_tools.gd\").new())  # path string", false],
	[&"dev_ref", "ui/gutters.gd", "\tif OS.is_debug_build():\n\t\tadd_child(load(\"res://scripts/dev/dev_tools.gd\").new())", true],
	[&"dev_ref", "world/world.gd", "\tadd_child(load(\"res://scripts/dev/dev_tools.gd\").new())", true],
	[&"dev_ref", "world/world.gd", "\tif OS.is_debug_build():\n\t\tadd_child(load(\"res://scripts/dev/dev_tools.gd\").new())\n\tif OS.is_debug_build():\n\t\tadd_child(load(\"res://scripts/dev/dev_tools.gd\").new())", true],
	[&"dev_ref", "world/world.gd", "\tif OS.is_debug_build():\n\t\tadd_child(preload(\"res://scripts/dev/dev_tools.gd\").new())", true],
	[&"dev_ref", "world/world.gd", "\tif OS.is_debug_build():\n\t\tadd_child(load(\"res://scripts/dev/overlays.gd\").new())", true],
	[&"dev_ref", "world/world.gd", "\tif OS.is_debug_build():\n\n\t\t# DevTools, debug only\n\t\tadd_child(load(\"res://scripts/dev/dev_tools.gd\").new())", false],
	[&"dev_ref", "world/world.gd", "\tif not OS.is_debug_build():\n\t\tadd_child(load(\"res://scripts/dev/dev_tools.gd\").new())", true],
	[&"dev_ref", "world/world.gd", "\tif OS.is_debug_build():\n\t\tpass\n\t\tadd_child(load(\"res://scripts/dev/dev_tools.gd\").new())", true],
	[&"dev_ref", "world/world.gd", "\tvar t: DevThing", true],
	[&"dev_ref", "world/world.gd", "\tvar s := \"DevThing\"", false],
	# Story 1.12 D11: raw lights, anywhere but BudgetLight itself; dev/ too (the perf run's stand-ins
	# are BudgetLights).
	[&"raw_light", "actors/flare.gd", "\tvar l := PointLight2D.new()", true],
	[&"raw_light", "objects/ember_cache.gd", "extends PointLight2D", true],
	[&"raw_light", "dev/perf_run.gd", "\tvar l := PointLight2D.new()", true],
	[&"raw_light", "core/budget_light.gd", "extends PointLight2D", false],
	[&"raw_light", "dev/perf_run.gd", "\tvar l := BudgetLight.new()", false],
	[&"raw_light", "actors/flare.gd", "\t# PointLight2D.new()", false],
	[&"raw_light", "actors/flare.gd", "\tvar s := \"PointLight2D.new()\"", false],
	[&"raw_light", "actors/player.gd", "@onready var _light: PointLight2D = $Light", false],
	[&"tests_ref", "world/world.gd", "const S := preload(\"res://tests/spec.gd\")", true],
	[&"tests_ref", "core/game.gd", "\tvar p := \"res://tests/fixtures/slot_v1.json\"", true],
	[&"tests_ref", "world/world.gd", "## the spec lives in res://tests/spec.gd", false],
	[&"tests_ref", "world/world.gd", "\tvar p := \"res://rooms/l1/x.txt\"", false],
	[&"state_write", "world/world.gd", "\tGame.settings.brightness = 2", true],
	[&"state_write", "world/world.gd", "\tGame.dive.carried += 3", true],
	[&"state_write", "ui/gutters.gd", "\tGame.slot.flags[\"met_oda\"] = true", true],
	[&"state_write", "world/world.gd", "\tGame.slot = SlotState.new()", true],
	[&"state_write", "ui/gutters.gd", "\tGame.display = x", true],
	[&"state_write", "ui/gutters.gd", "\tGame.display.scale = 2.0", true],
	[&"state_write", "ui/gutters.gd", "\tGame.display.scale_changed.connect(_on_scale)", false],
	[&"state_write", "ui/gutters.gd", "\tif Game.display.scale >= 1.0:", false],
	[&"state_write", "world/world.gd", "\tGame.slot.cache.embers = 3", true],
	[&"state_write", "ui/gutters.gd", "\tGame.slot.flags[ids[0]] = true", true],
	[&"state_write", "world/world.gd", "\tGame.slot.flags.erase(&\"met_oda\")", true],
	[&"state_write", "world/world.gd", "\tGame.dive.killed.clear()", true],
	[&"state_write", "ui/gutters.gd", "\tGame.settings.set(&\"brightness\", 2)", true],
	[&"state_write", "world/world.gd", "\tGame.tuning._values[&\"lurker_telegraph_time\"] = 0.1", true],
	[&"state_write", "world/world.gd", "\tGame.settings.set_value(&\"brightness\", 2)", false],
	[&"state_write", "world/world.gd", "\tif Game.slot.best_chain == 3:", false],
	[&"state_write", "world/world.gd", "\tif Game.dive.carried >= 2 and Game.dive.carried <= 9 or Game.dive.carried != 1:", false],
	[&"state_write", "world/world.gd", "\tvar b := Game.settings.brightness", false],
	[&"state_write", "world/world.gd", "\tLog.info(Log.SAVE, \"Game.settings.brightness = 2\")", false],
	[&"state_write", "world/world.gd", "\tif Game.slot.flags.has(&\"met_oda\"):", false],
	[&"state_write", "world/world.gd", "\tGame.slot.set_flag(&\"met_oda\")", false],
	[&"state_write", "world/world.gd", "\tvar n := Game.dive.killed.size()", false],
	[&"state_write", "world/world.gd", "\t# Game.settings.brightness = 2 compiles, so the lint stops it", false],
	[&"state_write", "rules/slot_state.gd", "\tGame.slot.best_chain = 3", false],
	[&"a11y_gate", "actors/player.gd", "\tif Game.settings.reduce_flashing:", true],
	[&"a11y_gate", "world/camera_rig.gd", "\tif not Game.settings.shake:", true],
	[&"a11y_gate", "world/camera_rig.gd", "\tif not _settings.shake:", true],
	[&"a11y_gate", "ui/gutters.gd", "\tvar on: bool = my_settings . shake", true],
	[&"a11y_gate", "world/camera_rig.gd", "\t_settings.shake_time = 0.2", false],
	[&"a11y_gate", "ui/gutters.gd", "\tif Game.settings.get(&\"reduced_motion\"):", true],
	[&"a11y_gate", "ui/gutters.gd", "\tGame.settings.changed.connect(func(k): if k == &\"shake\": _redraw())", true],
	[&"a11y_gate", "actors/lurker.gd", "\tvar reduced_motion := false", true],
	[&"a11y_gate", "core/fx.gd", "\treturn Game.settings.reduce_flashing", false],
	[&"a11y_gate", "rules/settings.gd", "\t&\"shake\": {default = true, choices = [false, true]},", false],
	[&"a11y_gate", "dev/dev_tools.gd", "\tGame.override_setting(&\"shake\", false)", false],
	[&"a11y_gate", "actors/player.gd", "\tif Fx.reduce_flashing():", false],
	[&"a11y_gate", "ui/gutters.gd", "\tvar t := 0.0 if Fx.reduced_motion() else 0.2", false],
	[&"a11y_gate", "world/camera_rig.gd", "\tif not Fx.shake_on():", false],
	[&"a11y_gate", "world/camera_rig.gd", "\tvar _shake := 0.0", false],
	[&"a11y_gate", "world/world.gd", "\t_player.pogo_hit.connect(_camera.kick.bind(CameraRig.POGO_SHAKE))", false],
	[&"a11y_gate", "actors/player.gd", "\t# steady under reduce_flashing (Fx decides)", false],
	[&"a11y_gate", "actors/player.gd", "\tvar s := \"shake it\"", false],
	# Story 1.17 D12: raw player text after a sink, and the near-misses that must stay quiet.
	[&"raw_text", "ui/gutters.gd", "\tl.text = \"Resume\"", true],
	[&"raw_text", "actors/player.gd", "\tFx.popup(p, pos, \"+%d banked\" % n, c)", true],
	[&"raw_text", "ui/gutters.gd", "\tdraw_string(f, v, \"Paused\")", true],
	[&"raw_text", "ui/gutters.gd", "\tl.set_text('Resume')", true],
	[&"raw_text", "ui/gutters.gd", "\tb.tooltip_text = \"Hold to snuff\"", true],
	[&"raw_text", "ui/gutters.gd", "\tl.text += \" more\"", true],
	[&"raw_text", "ui/gutters.gd", "\tlist.add_item(tr(\"MENU_RESUME\"), \"icon\")", true],
	# Code review (sonlm): two letters, whatever their case; a Label script's own `text`.
	[&"raw_text", "ui/gutters.gd", "\tl.text = \"On\"", true],
	[&"raw_text", "ui/gutters.gd", "\tl.text = \"OK\"", true],
	[&"raw_text", "ui/gutters.gd", "\tl.text = 'PAUSED'", true],
	[&"raw_text", "ui/gutters.gd", "\tl.text = \"POPUP\"", true],
	[&"raw_text", "ui/kit/menu_row.gd", "\ttext = \"Resume\"", true],
	[&"raw_text", "ui/kit/menu_row.gd", "\tif open: text = \"Resume\"", true],
	[&"raw_text", "ui/kit/menu_row.gd", "\tvar text := \"Resume\"", false],
	[&"raw_text", "ui/kit/menu_row.gd", "\tconst text = \"Resume\"", false],
	[&"raw_text", "ui/kit/menu_row.gd", "\tcontext = \"Resume\"", false],
	[&"raw_text", "ui/gutters.gd", "\tl.text = \"%dx\" % n", false],
	[&"raw_text", "ui/gutters.gd", "\tl.text = \"%.1fx\" % n", false],
	[&"raw_text", "ui/gutters.gd", "\tl.text = \"x%d%%\" % n", false],
	[&"raw_text", "ui/gutters.gd", "\tl.text = \"\\n\"", false],
	[&"raw_text", "ui/gutters.gd", "\tl.text = tr(\"MENU_X\") % Game.tuning.f(&\"dash_speed\")", false],
	[&"raw_text", "ui/gutters.gd", "\tl.text = tr_n('MENU_ONE', \"MENU_MANY\", n)", false],
	[&"raw_text", "ui/gutters.gd", "\tl.text = tr(\"MENU_RESUME\")", false],
	[&"raw_text", "ui/gutters.gd", "\tl.text = \"x\"", false],
	[&"raw_text", "actors/player.gd", "\tFx.popup(p, pos, \"x%d  +%d\" % [a, b], SPARK)", false],
	[&"raw_text", "actors/player.gd", "\tFx.popup(_fx_parent(), pos, tr(\"POPUP_BANKED\") % amount, c)", false],
	[&"raw_text", "ui/gutters.gd", "\tl.text = tr(\"MENU_RESUME\") + suffix", false],
	[&"raw_text", "ui/gutters.gd", "\tif l.text == \"Resume\":", false],
	[&"raw_text", "ui/gutters.gd", "\t# l.text = \"Resume\"", false],
	[&"raw_text", "ui/gutters.gd", "\tvar s := \"Resume\"", false],
	[&"raw_text", "actors/player.gd", "\tFx.chain_popup(p, pos, n, e)", false],
	[&"raw_text", "ui/gutters.gd", "\ts.texture = load(\"res://art/light.png\")", false],
	[&"raw_text", "dev/overlays.gd", "\titem.draw_string(font, p, \"perf summary\")", false],
]


func _test_rules() -> void:
	var names := {
		core_layer = PackedStringArray(["Audio", "Lurker", "Player", "PlayerInput", "Room", "World"]),
		rules_purity = PackedStringArray(["Log", "Player", "Timer", "World"]),
		dev_ref = PackedStringArray(["DevThing", "DevTools"]),
	}
	var covered := {}
	for row: Array in SAMPLES:
		var rule: StringName = row[0]
		var want: bool = row[3]
		var hits := lint_text(row[1], row[2], names)
		var got := hits.filter(func(h: Dictionary) -> bool: return h.rule == rule).size()
		check(got == (1 if want else 0), "%s %s on %s: %s (got %d hits: %s)" % [rule, "fires" if want else "quiet", row[1], row[2].strip_edges(), got, hits])
		if want:
			covered[rule] = true
	for rule in RULES:
		check(covered.has(rule.id), "rule %s has a sample that makes it fire" % rule.id)


# --- The real tree --------------------------------------------------------------------------------

func _test_tree() -> void:
	var files := _gd_files(ROOT)
	var rels: Array[String] = []
	for f in files:
		rels.append(f.trim_prefix(ROOT + "/"))
	check(not files.is_empty(), "lint: found .gd files under %s (%d)" % [ROOT, files.size()])
	for s: String in SENTINELS:
		check(s in rels, "lint: the walk sees %s, so it is looking at the real scripts/" % s)
	var sources := {}
	for i in files.size():
		var src := FileAccess.get_file_as_string(files[i])
		var err := FileAccess.get_open_error()
		if err != OK:
			check(false, "lint: %s is unreadable (%s)" % [rels[i], error_string(err)])
			continue
		sources[rels[i]] = src
	var autoloads := {}
	for p: Dictionary in ProjectSettings.get_property_list():
		var key: String = p.name
		if key.begins_with("autoload/"):
			autoloads[key.trim_prefix("autoload/")] = ProjectSettings.get_setting(key)
	var names := layer_names(sources, autoloads, ClassDB.get_inheriters_from_class(&"Node"))
	check(names.core_layer.size() >= 5, "lint: upper-layer class names collected for core_layer (%s)" % [names.core_layer])
	check(names.rules_purity.has("Timer") and names.rules_purity.has("Log") and names.rules_purity.has("Player") and names.rules_purity.has("Game"),
			"lint: rules_purity knows the Node classes, core/ and the layers above (%d names)" % names.rules_purity.size())
	check(names.dev_ref.has("DevTools"), "lint: dev_ref knows the class names declared under dev/, so dev/ was walked (%s)" % [names.dev_ref])
	_test_world_hook(sources.get("world/world.gd", ""), names)
	var total := 0
	for rel: String in sources:
		for h in lint_text(rel, sources[rel], names):
			print("FAIL lint %s:%d %s" % [rel, h.line, h.rule])
			_fail += 1
			total += 1
	if total == 0:
		check(true, "lint: %d files, %d rules, 0 hits" % [sources.size(), RULES.size()])


## Class names a layer must not use, by rule id, so a new class or autoload is covered with no
## edit here. core_layer gets the class_name lines and autoloads of the layers above core/;
## rules_purity gets those, core/'s, and every engine Node class (`node_classes`, from ClassDB);
## dev_ref gets dev/'s (Story 1.11 D12: code outside dev/ never names them).
## `sources` maps a path under scripts/ to its text; `autoloads` maps a name to its project.godot
## value ("*res://scripts/core/game.gd"). `class_name` may follow annotations (`@abstract`, `@icon(…)`).
static func layer_names(sources: Dictionary, autoloads: Dictionary, node_classes: PackedStringArray) -> Dictionary:
	var re := RegEx.create_from_string(r"(?m)^(?:@\w+(?:\([^)\n]*\))?\s+)*class_name\s+(\w+)")
	var upper := PackedStringArray()
	var core := PackedStringArray()
	var dev := PackedStringArray()
	for rel: String in sources:
		var dir := rel.get_slice("/", 0)
		for m in re.search_all(sources[rel]):
			if dir in UPPER_DIRS:
				upper.append(m.get_string(1))
			elif dir == "core":
				core.append(m.get_string(1))
			if dir == "dev":
				dev.append(m.get_string(1))
	for name: String in autoloads:
		var dir := String(autoloads[name]).trim_prefix("*").trim_prefix(ROOT + "/").get_slice("/", 0)
		if dir in UPPER_DIRS:
			upper.append(name)
		elif dir == "core":
			core.append(name)
		if dir == "dev":
			dev.append(name)
	var below := upper + core + node_classes
	upper.sort()
	below.sort()
	dev.sort()
	return {core_layer = upper, rules_purity = below, dev_ref = dev}


func _test_layer_names() -> void:
	var n := layer_names({
			"world/enemy.gd": "@abstract class_name EnemyBase\nextends Node",
			"ui/thing.gd": "@icon(\"res://i.svg\") class_name IconThing",
			"dev/tool.gd": "class_name DevThing",
			"core/log.gd": "class_name Log",
			"rules/gear.gd": "class_name Gear"},
		{"Game": "*res://scripts/core/game.gd", "Audio": "*res://scripts/audio/audio.gd", "DevAuto": "*res://scripts/dev/dev_auto.gd"},
		PackedStringArray(["Timer"]))
	check(Array(n.core_layer) == ["Audio", "DevAuto", "DevThing", "EnemyBase", "IconThing"], "layer_names: core_layer gets upper classes (annotated too, dev/ included) and upper autoloads (%s)" % [n.core_layer])
	check(Array(n.rules_purity) == ["Audio", "DevAuto", "DevThing", "EnemyBase", "Game", "IconThing", "Log", "Timer"], "layer_names: rules_purity also gets core/, its autoload and the Node classes, never rules/ (%s)" % [n.rules_purity])
	check(Array(n.dev_ref) == ["DevAuto", "DevThing"], "layer_names: dev_ref gets only dev/'s classes and autoloads (%s)" % [n.dev_ref])


## Story 1.11 D12: the real world.gd holds dev_ref's `once` line exactly once, as the first
## statement of _ready() (AC1), and the lint lets it through, so an exemption whose text no longer
## matches the code fails here, not silently.
func _test_world_hook(src: String, names: Dictionary) -> void:
	var pair: Array = (_rule(&"dev_ref").once as Dictionary)["world/world.gd"]
	var line: String = pair[1]
	var codes: Array[String] = []  # every non-blank line's code, stripped
	var open := ""
	for text in src.replace("\r", "").split("\n"):
		var s := strip(text, open)
		open = s.open
		var code: String = s.code.strip_edges()
		if code != "":
			codes.append(code)
	var count := codes.count(line)
	check(count == 1, "lint: world.gd holds the DevTools line exactly once (got %d)" % count)
	var at := codes.find(line)
	check(at >= 2 and codes[at - 1] == pair[0] and codes[at - 2] == "func _ready() -> void:",
			"lint: ...under its guard, as the first statement of World._ready() (got %s)" % [codes.slice(maxi(at - 2, 0), at + 1)])
	var hits := lint_text("world/world.gd", src, names).filter(func(h: Dictionary) -> bool: return h.rule == &"dev_ref")
	check(count == 1 and hits.is_empty(), "lint: ...and dev_ref lets it through (hits %s)" % [hits])


static func _rule(id: StringName) -> Dictionary:
	for rule in RULES:
		if rule.id == id:
			return rule
	return {}


func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir.path_join(d)))
	out.sort()
	return out


# --- Spec citations (AR49) ---------------------------------------------------------------------

## Every Spec value is a const carrying the GDD line it guards in its own `##` comment (D5).
## Pure: returns the 1-based lines that break this: a const whose comment has no `## GDD ` (a
## marker inside a string doesn't count), and any `var` (a Spec value never changes).
static func uncited_consts(text: String) -> Array[int]:
	var decl_re := RegEx.create_from_string(r"^\s*(static\s+)?(const|var)\s+\w+")
	var out: Array[int] = []
	var open := ""
	var lines := text.replace("\r", "").split("\n")
	for i in lines.size():
		var was_open := open != ""
		var s := strip(lines[i], open)
		open = s.open
		var m := decl_re.search(s.code)
		if was_open or m == null:
			continue
		var comment := lines[i].substr(s.code.length())
		if m.get_string(2) == "var" or comment.find("## GDD ") < 0:
			out.append(i + 1)
	return out


func _test_spec_citations() -> void:
	check(uncited_consts("const A := 1  ## GDD Lurker: \"x\"\nconst B := 2  ## why\nconst C := 3\nconst D := \"## GDD fake\"\nstatic var E := 1.0  ## GDD x") == [2, 3, 4, 5], "spec_citation: a const without `## GDD`, a marker inside a string and a var are caught")
	var src := FileAccess.get_file_as_string(SPEC)
	var err := FileAccess.get_open_error()
	if err != OK or src == "":
		check(false, "spec_citation: %s is unreadable (%s)" % [SPEC, error_string(err)])
		return
	var bad := uncited_consts(src)
	for line in bad:
		print("FAIL lint tests/spec.gd:%d spec_citation" % line)
		_fail += 1
	var count := RegEx.create_from_string(r"(?m)^const\s+\w+").search_all(src).size()
	if bad.is_empty():
		check(count >= 4, "spec_citation: all %d Spec consts cite the GDD" % count)
