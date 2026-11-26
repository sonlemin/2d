class_name DevTools
extends Node
## Debug-only tools (AR54, Story 1.11): entry args and the overlays. `World._ready()` adds this node
## with one path-string `load()` inside `if OS.is_debug_build()`, and release exports exclude
## scripts/dev/*, so nothing here ships. Nothing outside dev/ and tests/ may name this class (the
## lint's dev_ref rule); dev/ may touch anything.
## - Args, desktop: `godot --path game -- --room=m1_shaft --chain=8 --set=brightness:0`.
##   Web debug build: `?room=m1_shaft&chain=8`. Applied only when World is the current scene (a
##   real run, the same gate as `Game.boot()`); a test sets `tokens` from World's
##   `child_entered_tree`, which fires before this node's `_ready()` (D3).
## - Overlays: the `dev_overlay` action (backquote) cycles four overlays, then off (overlays.gd).
## - Perf (Story 1.12): `--glow=on` adds engine glow for the perf check; `--perf[=<s>]` starts the
##   timed autopilot run (perf_run.gd). Both are dev-only until 1.15's verdict (docs/perf.md).
## - A bad arg is a warning, never an error or an assert: the game still starts (D4).

const Overlays := preload("overlays.gd")
const PerfRun := preload("perf_run.gd")

## One row per arg (D4): name -> {help, apply (the method that applies its values), repeat (may be
## given more than once), detach}. Rows apply in this order: log first, so the rest can log; set and
## room at once; chain, hp and difficulty on every spawn; glow before perf, so the run's summary
## knows it; perf last, since it reads --chain. Later stories add one row each.
## `detach` (Story 1.21 D12, sonlm 2026-11-25): an arg that changes the play itself. A session
## that applied one loads no slot and saves none (`Game.detach_slot()`), so a dev room, chain or
## HP or tier never reaches the file a normal run reads, and `--room` always wins over a saved respawn
## point. log, set and glow change only what is shown or logged: the slot loads and saves as usual.
const ARGS := {
	"log": {help = "--log=<cat>,<cat>: turn on Log categories", apply = &"_apply_log", repeat = true, detach = false},
	"set": {help = "--set=<key>:<value>: a setting for this session only; nothing is saved", apply = &"_apply_set", repeat = true, detach = false},
	"room": {help = "--room=<id>: start the dive in that room; no slot is loaded or saved", apply = &"_apply_room", repeat = false, detach = true},
	"chain": {help = "--chain=<n>: every life takes off with that chain; no slot is loaded or saved", apply = &"_apply_chain", repeat = false, detach = true},
	"hp": {help = "--hp=<n>: every life starts with n HP (1–4); no slot is loaded or saved", apply = &"_apply_hp", repeat = false, detach = true},
	"difficulty": {help = "--difficulty=easy|normal|hard: the tier for this session; no slot is loaded or saved", apply = &"_apply_difficulty", repeat = false, detach = true},
	"glow": {help = "--glow=on|off: engine glow (a WorldEnvironment) for the perf check; off unless given", apply = &"_apply_glow", repeat = false, detach = false},
	"perf": {help = "--perf[=<s>]: a timed perf run (default 60 s): the player locked on a fixed path, untouchable, holding --chain's n (default 20); the summary goes to the log and overlay 4; no slot is loaded or saved", apply = &"_apply_perf", repeat = false, detach = true},
}
## The entry `--room=` starts at, by preference: the `P`, else arriving from above, else from below
## (D5; Story 2.1's weaver_test has no `P` and is entered from the top).
const ENTRY_ORDER: Array[StringName] = [&"spawn", &"up", &"down"]
## Integers longer than this are refused before to_int(): a 20-digit string passes is_valid_int()
## but makes to_int() print an engine ERROR (probed; room_loader.gd caps coordinates the same way).
const MAX_INT_CHARS := 4
const PERF_DEFAULT_S := 60  ## `--perf` alone: 60 s, the measurement procedure's run (docs/perf.md)
const PERF_MAX_S := 600  ## 10 minutes: E7's Layer 1 performance pass (NFR1) can reuse the run
const GLOW_INTENSITY := 1.0  ## D7 starting value for seeing glow's cost and look; the follow-up story tunes it if glow goes
const GLOW_THRESHOLD := 0.5  ## D7: only bright pixels (lights, unshaded glows) bloom; the dark stays dark

## The args to apply. A real run replaces them with the command line and the URL query in
## `_ready()`; a test sets them before that.
var tokens := PackedStringArray()
var overlays: Node  ## overlays.gd; public for tests
var perf: Node  ## perf_run.gd while --perf runs, else null; public for tests and the overlay
var glow_on := false  ## --glow=on applied

var _world: World
var _chain := 0  # --chain's n, armed on every spawn (D6)
var _chain_given := false  # a valid --chain was accepted: 0 alone can't tell it from none or a rejected one (1.12 D1)
var _armed: Player  # the player still owed the chain; only read behind is_instance_valid()
var _armed_frame := 0  # Engine.get_physics_frames() when _armed spawned
var _hp := 0  # --hp's n, applied on every spawn (Story 1.19 D8); 0 when not given
var _difficulty: StringName = &""  # --difficulty's tier, set on every spawn (Story 1.22 D10); &"" when not given


func _init() -> void:
	name = "DevTools"  # before the tree: child_entered_tree handlers see the name (D3)
	# The overlay key works while paused, dead or locked (D9), and the chain check runs after the
	# player's move_and_slide() each tick: a higher priority runs later, across the tree (probed).
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 100


func _ready() -> void:
	_world = get_parent() as World
	assert(_world != null, "DevTools: only World adds DevTools")
	if get_tree().current_scene == _world:
		tokens = real_tokens()
		# AR53 (Story 1.13 D9): the web smoke's "booted" line. World's _ready() adds this node
		# before it builds its first room, so the connection sees that room; one-shot, so a
		# respawn's rebuild prints no second line. A method, not a lambda: it drops with this node.
		_world.room_entered.connect(_on_first_room, CONNECT_ONE_SHOT)
	overlays = Overlays.new()
	overlays.name = "Overlays"
	overlays.world = _world
	add_child(overlays)
	_apply(tokens)


## AC7: edge-triggered and polled, never an input callback: Input.action_press() (tests) reaches
## is_action_just_pressed() but never _unhandled_input (probed). Key echo can't cycle twice.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"dev_overlay"):
		overlays.cycle()


## D6: the chain is paid on the first tick that ends with the armed player off the floor, so a
## grounded spawn keeps it until take-off (a landing breaks a chain on every floor tick).
func _physics_process(_delta: float) -> void:
	if _armed == null:
		return
	# is_on_floor() is false until the player's first move_and_slide(), so read it only on ticks the
	# player ran (D6): none while paused, and none in its spawn frame. A player added during a tick
	# first ticks on the next one, but this node, already listed, still runs in this one (probed).
	if get_tree().paused or Engine.get_physics_frames() <= _armed_frame:
		return
	if not is_instance_valid(_armed) or _armed.is_dead:
		_armed = null
		return
	if _armed.is_on_floor():
		return
	# Exactly what n pogo hits leave: count n, held n(n+1)/2, `changed` n times (best chain, bloom,
	# light). It breaks and banks like any chain: never pinned (Snuff / land / cling in time saves).
	for i in _chain:
		_armed.chain.add_hit()
	_armed = null


## The command line after `--`, then the URL query. Off the web JavaScriptBridge is a stub that
## returns null with no error (probed in the editor and both Linux templates), so this needs no
## OS.has_feature("web") branch; on the web the command line is empty.
static func real_tokens() -> PackedStringArray:
	var out := OS.get_cmdline_user_args()
	var query: Variant = JavaScriptBridge.eval("window.location.search", true)
	if query is String and query != "":
		out.append_array(query_tokens(query))
	return out


# --- Pure: parsing and validation (test_dev_args) ---------------------------------------------

## A URL query ("?room=a&chain=5") as the same `--key=value` tokens the command line gives. It
## can't fail: a malformed part becomes a token that parse() reports. Each part is split on its
## first `=` before decoding, so an encoded `%3D` or `%26` stays inside the value.
static func query_tokens(query: String) -> PackedStringArray:
	var out := PackedStringArray()
	for part in query.trim_prefix("?").split("&", false):
		var kv := part.split("=", true, 1)
		out.append("--" + kv[0].uri_decode() + ("=" + kv[1].uri_decode() if kv.size() > 1 else ""))
	return out


## {values = {name: Array[String]}, errors = Array[String]}. Tokens that don't start with `--` are
## skipped (the runner's own test path, the screenshot's out path). `--name=value` splits on the
## first `=`; `--name` alone has the value "". A `repeat` arg keeps every value in order; any other
## arg given twice keeps the last, with one error.
static func parse(list: PackedStringArray, registry: Dictionary = ARGS) -> Dictionary:
	var known := {}
	for key: Variant in registry:
		known[String(key)] = registry[key]
	var values := {}
	var counts := {}
	var errors: Array[String] = []
	for t in list:
		if not t.begins_with("--"):
			continue
		var kv := t.substr(2).split("=", true, 1)
		var arg := kv[0]
		var value := kv[1] if kv.size() > 1 else ""
		if not known.has(arg):
			errors.append("unknown arg --%s (known: %s)" % [arg, ", ".join(sorted_names(known.keys()))])
			continue
		counts[arg] = counts.get(arg, 0) + 1
		if not values.has(arg) or not known[arg].repeat:
			var fresh: Array[String] = []
			values[arg] = fresh
		values[arg].append(value)
	for arg: String in counts:
		if counts[arg] > 1 and not known[arg].repeat:
			errors.append("--%s given %d times; using the last ('%s')" % [arg, counts[arg], values[arg][0]])
	return {values = values, errors = errors}


## [n, error] for `--chain=<n>`: an integer from 0 to ChainState.MAX_CHAIN.
static func chain_value(text: String) -> Array:
	if not text.is_valid_int() or text.length() > MAX_INT_CHARS:
		return [0, "--chain=%s is not a whole number from 0 to %d" % [text, ChainState.MAX_CHAIN]]
	var n := text.to_int()
	if n < 0 or n > ChainState.MAX_CHAIN:
		return [0, "--chain=%s is outside 0..%d" % [text, ChainState.MAX_CHAIN]]
	return [n, ""]


## [n, error] for `--hp=<n>`: an integer from 1 to Health.MAX (Story 1.19 D8), capped at MAX_INT_CHARS
## before to_int(), as --chain is.
static func hp_value(text: String) -> Array:
	if not text.is_valid_int() or text.length() > MAX_INT_CHARS:
		return [0, "--hp=%s is not a whole number from 1 to %d" % [text, Health.MAX]]
	var n := text.to_int()
	if n < 1 or n > Health.MAX:
		return [0, "--hp=%s is outside 1..%d" % [text, Health.MAX]]
	return [n, ""]


## [tier, error] for `--difficulty=`: a SlotState.DIFFICULTIES id, exact and lower case (Story 1.22).
static func difficulty_value(text: String) -> Array:
	if StringName(text) in SlotState.DIFFICULTIES:
		return [StringName(text), ""]
	return [&"", "--difficulty=%s is not one of %s" % [text, ", ".join(SlotState.DIFFICULTIES.map(func(t: StringName) -> String: return String(t)))]]


## [on, error] for `--glow=`: only `on` or `off`, lowercase (1.12 D7).
static func glow_value(text: String) -> Array:
	match text:
		"on":
			return [true, ""]
		"off":
			return [false, ""]
	return [false, "--glow=%s is not on or off" % text]


## [seconds, error] for `--perf[=<s>]`: "" is PERF_DEFAULT_S; else a whole number from 1 to
## PERF_MAX_S, capped at MAX_INT_CHARS before to_int() (1.12 D1).
static func perf_seconds(text: String) -> Array:
	if text == "":
		return [PERF_DEFAULT_S, ""]
	if not text.is_valid_int() or text.length() > MAX_INT_CHARS:
		return [0, "--perf=%s is not a whole number of seconds from 1 to %d" % [text, PERF_MAX_S]]
	var n := text.to_int()
	if n < 1 or n > PERF_MAX_S:
		return [0, "--perf=%s is outside 1..%d s" % [text, PERF_MAX_S]]
	return [n, ""]


## The --glow=on Environment, built in code (no .tres): BG_CANVAS, which 2D glow needs; glow on at
## the D7 values; bloom 0, because bloom 1.0 lifted the whole frame in the probe (Pillar 2: the
## dark must stay dark). Default glow levels. Probed in GL Compatibility 2D without hdr_2d.
static func glow_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = GLOW_INTENSITY
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = GLOW_THRESHOLD
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	return env


## [categories, errors] for one `--log=` value: comma-separated, any case, matched against
## Log.CATEGORIES. Empty names are skipped; each unknown one is an error listing the valid ones.
static func log_names(text: String) -> Array:
	var cats: Array[StringName] = []
	var errors: Array[String] = []
	for raw in text.split(",", false):
		var cat := raw.strip_edges().to_lower()
		if cat == "":
			continue
		if StringName(cat) in Log.CATEGORIES:
			if not StringName(cat) in cats:
				cats.append(StringName(cat))
		else:
			errors.append("--log: no category '%s' (valid: %s)" % [cat, ", ".join(sorted_names(Log.CATEGORIES))])
	return [cats, errors]


## [key, value, error] for `--set=<key>:<value>`, typed by the key's default in `schema`: int,
## float or bool (`true`/`false` only). Any other type can't be set from the command line. The
## value must then pass Settings.is_valid() against the same schema (D8). Every error lists the
## schema's keys with their choices.
static func set_value_of(text: String, schema: Dictionary = Settings.SCHEMA) -> Array:
	var kv := text.split(":", true, 1)
	if kv.size() < 2:
		return [&"", null, "--set=%s is not <key>:<value> (%s)" % [text, schema_help(schema)]]
	var key := StringName(kv[0].strip_edges())
	var raw := kv[1].strip_edges()
	if not schema.has(key):
		return [&"", null, "--set: no setting '%s' (%s)" % [key, schema_help(schema)]]
	var v: Variant = null
	match typeof(schema[key].default):
		TYPE_INT:
			if raw.is_valid_int() and raw.length() <= MAX_INT_CHARS:
				v = raw.to_int()
		TYPE_FLOAT:
			if raw.is_valid_float():
				v = raw.to_float()
		TYPE_BOOL:
			if raw == "true" or raw == "false":
				v = raw == "true"
		_:
			return [&"", null, "--set: '%s' can't be set from the command line (%s)" % [key, schema_help(schema)]]
	if v == null or not Settings.is_valid(key, v, schema):
		return [&"", null, "--set: '%s' is not a value for '%s' (%s)" % [raw, key, schema_help(schema)]]
	return [key, v, ""]


## "keys: brightness (0, 1, 2, 3), light_tap_window (0.12, 0.2, 0.3)", sorted as Strings.
static func schema_help(schema: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in sorted_names(schema.keys()):
		parts.append("%s (%s)" % [key, ", ".join(schema[StringName(key)].choices.map(func(c: Variant) -> String: return str(c)))])
	return "keys: " + ", ".join(parts)


## [entry, error] for `--room=<id>`, from RoomLoader.inspect(id) and every known id.
static func room_entry(id: String, info: Dictionary, known_ids: Array) -> Array:
	if not info.known:
		return [&"", "--room: no room '%s' (known: %s)" % [id, ", ".join(sorted_names(known_ids))]]
	if not info.errors.is_empty():
		return [&"", "--room: room '%s' is invalid: %s" % [id, "; ".join(info.errors.slice(0, 3))]]
	return pick_entry(info.entries)


## [entry, error]: `spawn` when the room has a `P`, else `up`, else `down`, by membership.
static func pick_entry(entries: Array) -> Array:
	for e in ENTRY_ORDER:
		if e in entries:
			return [e, ""]
	return [&"", "--room: the room has no P and no exit to start at"]


## Names sorted as Strings: Array.sort() on StringNames is pointer order, not alphabetical (probed).
static func sorted_names(names: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for n: Variant in names:
		out.append(String(n))
	out.sort()
	return out


# --- Applying (impure: warnings, never errors) ----------------------------------------------------

func _apply(list: PackedStringArray) -> void:
	var parsed := parse(list)
	for e: String in parsed.errors:
		_warn(e)
	var done := PackedStringArray()
	var detach := false
	for arg: String in ARGS:
		if parsed.values.has(arg):
			var summary: String = call(ARGS[arg].apply, parsed.values[arg])
			if summary != "":
				done.append(summary)
				# Only an arg that was applied: a refused --room=typo leaves a normal session.
				detach = detach or ARGS[arg].detach
	if detach:
		# Story 1.21 D12. Before Game.boot(): World adds this node first thing in its _ready().
		Game.detach_slot()
		done.append("no slot loaded or saved")
	if not done.is_empty():
		# AR55's category list is fixed (no DEV): the room category carries the one summary line.
		Log.info(Log.ROOM, "dev: " + ", ".join(done))


## D7: one Log.set_enabled() call, made only when --log names a valid category (it replaces the
## set). With none, it is a bad value like any other: a warning, and Log is left as it was.
func _apply_log(values: Array[String]) -> String:
	var cats: Array[StringName] = []
	var warned := false
	for text in values:
		var r := log_names(text)
		for e: String in r[1]:
			_warn(e)
			warned = true
		for cat: StringName in r[0]:
			if not cat in cats:
				cats.append(cat)
	if cats.is_empty():
		if not warned:
			_warn("--log needs a category (valid: %s)" % ", ".join(sorted_names(Log.CATEGORIES)))
		return ""
	Log.set_enabled(cats)
	return "log %s" % ",".join(sorted_names(cats))


## D8: through Game.override_setting(), so the value survives boot()'s load and nothing is saved.
func _apply_set(values: Array[String]) -> String:
	var done := PackedStringArray()
	for text in values:
		var r := set_value_of(text)
		if r[2] != "":
			_warn(r[2])
			continue
		Game.override_setting(r[0], r[1])
		done.append("%s=%s" % [r[0], r[1]])
	return "set %s" % ",".join(done) if not done.is_empty() else ""


## D5: checked before World builds anything, so a bad id or room never reaches RoomLoader's
## push_error or World's assert; the default start room loads instead. The respawn point is never
## written (it is save data), and none is loaded either: an applied --room detaches the slot
## (Story 1.21 D12), so the start room always wins.
func _apply_room(values: Array[String]) -> String:
	var id: String = values[-1]
	var r := room_entry(id, RoomLoader.inspect(StringName(id)), RoomLoader.room_ids())
	if r[1] != "":
		_warn("%s; starting in %s" % [r[1], _world.start_room])
		return ""
	_world.start_room = StringName(id)
	_world.start_entry = r[0]
	return "room %s@%s" % [id, r[0]]


## D6 (sonlm, 2026-11-19): armed on every spawn, paid at take-off as n pogo hits.
func _apply_chain(values: Array[String]) -> String:
	var r := chain_value(values[-1])
	if r[1] != "":
		_warn(r[1])
		return ""
	_chain = r[0]
	_chain_given = true
	if _chain > 0:
		_world.player_spawned.connect(_on_player_spawned)  # a method: dropped with World
	return "chain %d" % _chain


## Story 1.19 D8: like --chain, every life (the first and each respawn) starts with n HP, so E2's
## Weaver work can start each life at 1 HP. Its own spawn handler, so --chain's stays as it is.
func _apply_hp(values: Array[String]) -> String:
	var r := hp_value(values[-1])
	if r[1] != "":
		_warn(r[1])
		return ""
	_hp = r[0]
	_world.player_spawned.connect(_on_player_spawned_hp)  # a method: dropped with World
	return "hp %d" % _hp


## Story 1.22 D10: the tier is set on every spawn, never here. This runs before Game.boot(), and a
## detached boot's load_slot() resets the slot, tier included; the first spawn runs inside World's
## _ready(), after the boot. No save: the session is detached (Game.set_difficulty() would save).
func _apply_difficulty(values: Array[String]) -> String:
	var r := difficulty_value(values[-1])
	if r[1] != "":
		_warn(r[1])
		return ""
	_difficulty = r[0]
	_world.player_spawned.connect(_on_player_spawned_difficulty)  # a method: dropped with World
	return "difficulty %s" % _difficulty


## D7: `on` adds a WorldEnvironment (one per viewport; a later story that puts one in World
## removes this one); `off` adds none. Game code gets no glow until 1.15's verdict.
func _apply_glow(values: Array[String]) -> String:
	var r := glow_value(values[-1])
	if r[1] != "":
		_warn(r[1])
		return ""
	if not r[0]:
		return "glow off"
	var env := WorldEnvironment.new()
	env.name = "Glow"
	env.environment = glow_environment()
	add_child(env)
	glow_on = true
	return "glow on"


## D1 (sonlm, 2026-11-19: the autopilot): the run holds --chain's n, or ChainState.MAX_CHAIN
## without one, paid through the same take-off arming as --chain: no new pay path.
func _apply_perf(values: Array[String]) -> String:
	var r := perf_seconds(values[-1])
	if r[1] != "":
		_warn(r[1])
		return ""
	if not _chain_given:
		_chain = ChainState.MAX_CHAIN
		if not _world.player_spawned.is_connected(_on_player_spawned):
			_world.player_spawned.connect(_on_player_spawned)
	perf = PerfRun.new()
	perf.seconds = r[0]
	perf.hold_chain = _chain
	perf.glow = glow_on
	perf.world = _world
	add_child(perf)
	overlays.perf = perf
	return "perf %d s, chain %d" % [r[0], _chain]


func _on_player_spawned(player: Player) -> void:
	_armed = player
	_armed_frame = Engine.get_physics_frames()


func _on_player_spawned_hp(player: Player) -> void:
	player.health.reset(_hp)


func _on_player_spawned_difficulty(_player: Player) -> void:
	Game.slot.set_difficulty(_difficulty)


## D9: World emits room_entered after the room is built and the player spawned, so a broken room
## or player script means no marker (or a SCRIPT ERROR first). The room category, like _apply()'s
## summary: AR55's category list is fixed (no DEV). Release builds print nothing: DevTools is
## absent there and Log is silent.
func _on_first_room(_id: StringName) -> void:
	Log.info(Log.ROOM, "SMOKE boot ok")


## The runner tolerates warnings; an error or an assert would fail it and stop a real run.
func _warn(msg: String) -> void:
	push_warning("DevTools: " + msg)
