extends Node
## Tuning (AR15) and Gear (AR16): the API, the fixed set → add → mul order, the telegraph floor
## under every gear (Spec, Story 1.9), and the Story 1.3 regression fixture: every M1 @export default still holds, wherever it now lives.
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
const Spec := preload("res://tests/spec.gd")
const PlayerScene := preload("res://scenes/actors/player.tscn")
const ACTORS := {
	"player": "res://scripts/actors/player.gd",
	"crawler": "res://scripts/actors/crawler.gd",
	"lurker": "res://scripts/actors/lurker.gd",
}

## The 44 M1 @export defaults (baseline 85bb1ed), copied from the M1 code, never from Tuning.
## A row is moved to Tuning (`keys`), kept as a local const (`local`), per instance (`instance`),
## or became a player setting (`setting`, Story 1.8: the Snuff hold is Settings.light_tap_window's
## default, never a Tuning key). A `local` row whose const moved to another script names it in
## `home` (Story 1.6: the camera consts moved to world/camera_rig.gd; Story 1.16: the eye pulse to core/fx.gd;
## Story 1.20: the light easing to actors/light_source.gd, the sensing consts to rules/sensing.gd).
## BASE keys new in M2, with no M1 export behind them (Story 1.19: bank_heal_min, GDD Health).
const M2_KEYS: Array[StringName] = [&"bank_heal_min", &"cache_radius"]
const M1: Array[Dictionary] = [
	{m1 = "player.run_speed", value = 110.0, keys = [&"run_speed"]},
	{m1 = "player.run_accel", value = 900.0, keys = [&"run_accel"]},
	{m1 = "player.air_accel", value = 1500.0, keys = [&"air_accel"]},
	{m1 = "player.gravity", value = 900.0, keys = [&"gravity"]},
	{m1 = "player.max_fall", value = 210.0, keys = [&"max_fall"]},
	{m1 = "player.fall_gravity_scale", value = 0.6, keys = [&"fall_gravity_scale"]},
	{m1 = "player.jump_velocity", value = -330.0, keys = [&"jump_velocity"]},
	{m1 = "player.jump_cut", value = 0.45, keys = [&"jump_cut"]},
	{m1 = "player.coyote_time", value = 0.08, keys = [&"coyote_time"]},
	{m1 = "player.jump_buffer", value = 0.10, keys = [&"jump_buffer"]},
	{m1 = "player.dash_speed", value = 260.0, keys = [&"dash_speed"]},
	{m1 = "player.dash_time", value = 0.12, keys = [&"dash_time"]},
	{m1 = "player.cling_time", value = 1.0, keys = [&"cling_grace"]},
	{m1 = "player.cling_slide", value = 18.0, keys = [&"cling_slide"]},
	{m1 = "player.wall_kick", value = Vector2(150, -260), keys = [&"wall_kick_x", &"wall_kick_y"]},
	{m1 = "player.kick_lock", value = 0.15, keys = [&"kick_lock"]},
	{m1 = "player.pogo_velocity", value = -300.0, keys = [&"pogo_velocity"]},
	{m1 = "player.swing_active", value = 0.12, keys = [&"slash_active"]},
	{m1 = "player.air_swing_active", value = 0.22, keys = [&"pogo_armed"]},
	{m1 = "player.swing_cooldown", value = 0.22, keys = [&"attack_cooldown"]},
	{m1 = "player.hitstop", value = 0.075, keys = [&"hitstop"]},
	{m1 = "player.shake", value = 2.5, local = "POGO_SHAKE", home = "res://scripts/world/camera_rig.gd"},
	{m1 = "player.look_ahead", value = 70.0, local = "LOOK_AHEAD", home = "res://scripts/world/camera_rig.gd"},
	{m1 = "player.light_kick", value = 18.0, local = "LIGHT_KICK"},
	{m1 = "player.knockback", value = Vector2(150, -150), keys = [&"knockback_x", &"knockback_y"]},
	{m1 = "player.invuln_time", value = 0.6, keys = [&"invuln_time"]},
	{m1 = "player.snuff_hold", value = 0.12, setting = &"light_tap_window", gone = "SNUFF_HOLD"},
	{m1 = "player.light_lerp", value = 10.0, local = "LIGHT_LERP", home = "res://scripts/actors/light_source.gd"},  # Story 1.20: the light eases itself
	{m1 = "crawler.hover", value = false, instance = true},
	{m1 = "crawler.walk_speed", value = 25.0, keys = [&"crawler_walk_speed"]},
	{m1 = "crawler.gravity", value = 900.0, keys = [&"crawler_gravity"]},
	{m1 = "crawler.hover_drift", value = 10.0, keys = [&"crawler_hover_drift"]},
	{m1 = "crawler.hover_period", value = 2.4, keys = [&"crawler_hover_period"]},
	{m1 = "lurker.notice_min_radius", value = 80.0, local = "NOTICE_MIN_RADIUS", home = "res://scripts/rules/sensing.gd"},  # Story 1.20: one rule for every predator
	{m1 = "lurker.notice_factor", value = 1.6, local = "NOTICE_FACTOR", home = "res://scripts/rules/sensing.gd"},
	{m1 = "lurker.telegraph_time", value = 0.9, keys = [&"lurker_telegraph_time"]},
	{m1 = "lurker.lose_track_time", value = 0.6, keys = [&"lurker_lose_track_time"]},
	{m1 = "lurker.hunt_speed", value = 95.0, keys = [&"lurker_hunt_speed"]},
	{m1 = "lurker.hunt_accel", value = 220.0, keys = [&"lurker_hunt_accel"]},
	{m1 = "lurker.return_speed", value = 40.0, keys = [&"lurker_return_speed"]},
	{m1 = "lurker.eye_pulse_hz", value = 2.0, local = "EYE_PULSE_HZ", home = "res://scripts/core/fx.gd"},  # Story 1.16: the flash-rate table owns it
	{m1 = "lurker.screen_margin", value = 8.0, local = "SCREEN_MARGIN", home = "res://scripts/rules/sensing.gd"},
	{m1 = "lurker.glow_energy", value = 1.3, local = "GLOW_ENERGY"},
	{m1 = "lurker.eye_open_time", value = 0.2, local = "EYE_OPEN_TIME"},
]

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
	_test_gear_floors()
	_test_key_literals()
	_test_m1_fixture()
	_test_fr_values()
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
	check(Tuning.BASE.size() == 36, "BASE has 36 keys: the 34 from the M1 exports, bank_heal_min and cache_radius, new in M2 (Stories 1.19, 1.22; got %d)" % Tuning.BASE.size())
	check(Tuning.BANK_HEAL_MIN == Spec.BANK_HEAL_MIN, "Tuning.BANK_HEAL_MIN is Spec.BANK_HEAL_MIN, %d links (GDD Health; got %s)" % [Spec.BANK_HEAL_MIN, Tuning.BANK_HEAL_MIN])
	# FR24, GDD Economy "Ember Cache glow": the cache lures, so its radius is never under the notice
	# floor. smoke_lurker's cache case overrides the radius, so only this holds the shipped value.
	check(Tuning.CACHE_RADIUS >= Spec.NOTICE_MIN_RADIUS, "Tuning.CACHE_RADIUS is at least Spec.NOTICE_MIN_RADIUS, %.0f px: the shipped cache wakes lurkers (FR24; got %s)" % [Spec.NOTICE_MIN_RADIUS, Tuning.CACHE_RADIUS])
	var t := Tuning.new()
	check(_moved(t).is_empty(), "a fresh Tuning returns every BASE value (moved: %s)" % [_moved(t)])


## AR16: set → add → mul whatever order the gear comes in. From base 18, any other order gives 1, 3 or 5.
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


## A floor holds whatever gear is owned: `stat` never drops under `min_value` (or to it, unless
## `inclusive`) for any combination of the gear rows that bend it, 2^k sets for k such gear (code
## review of 1.3: the M1 editor range was the only floor, and gear could bend under it; code
## review of 1.9: two rows that each pass alone can still go under together). A combination with
## two `set` rows on the stat is reported, not applied: Tuning refuses it (assert). Pure; returns
## one message per breach.
static func stat_floor_errors(table: Array[Dictionary], stat: StringName, min_value: float, inclusive: bool) -> Array[String]:
	var rows: Array[Dictionary] = []
	var ids: Array[StringName] = []
	for row in table:
		if StringName(row.stat) != stat:
			continue
		rows.append(row)
		if not StringName(row.id) in ids:
			ids.append(StringName(row.id))
	assert(ids.size() <= 12, "stat_floor_errors: %d gear bend %s; 2^n sets is too many" % [ids.size(), stat])
	var errors: Array[String] = []
	for mask in 1 << ids.size():
		var owned: Array[StringName] = []
		for b in ids.size():
			if mask & (1 << b):
				owned.append(ids[b])
		var sets := rows.filter(func(r: Dictionary) -> bool: return StringName(r.id) in owned and StringName(r.op) == &"set").size()
		if sets > 1:
			errors.append("gear %s: %d rows set %s (Tuning refuses two)" % [owned, sets, stat])
			continue
		var t := Tuning.new()
		t.apply_gear(owned, rows)
		var v := t.f(stat)
		if v < min_value or (not inclusive and v <= min_value):
			errors.append("gear %s: %s %.3f, under %s %.2f" % [owned, stat, v, "the floor" if inclusive else "just above", min_value])
	return errors


func _test_gear_floors() -> void:
	# Pillar 2: the lurker telegraph never drops under Spec.TELEGRAPH_MIN, whatever gear is owned.
	var real := stat_floor_errors(Gear.TABLE, &"lurker_telegraph_time", Spec.TELEGRAPH_MIN, true)
	check(real.is_empty(), "the lurker telegraph stays at or above Spec.TELEGRAPH_MIN under every combination of Gear.TABLE rows (%d rows; %s)" % [Gear.TABLE.size(), real])
	var probe: Array[Dictionary] = [{id = &"probe_short_wick", stat = &"lurker_telegraph_time", op = &"mul", value = 0.5}]
	var caught := stat_floor_errors(probe, &"lurker_telegraph_time", Spec.TELEGRAPH_MIN, true)
	check(caught.size() == 1, "...a probe gear halving it is caught (%s)" % [caught])
	var pair: Array[Dictionary] = [
		{id = &"probe_a", stat = &"lurker_telegraph_time", op = &"add", value = -0.1},
		{id = &"probe_b", stat = &"lurker_telegraph_time", op = &"add", value = -0.1},
		{id = &"probe_c", stat = &"lurker_telegraph_time", op = &"add", value = 0.5}]
	caught = stat_floor_errors(pair, &"lurker_telegraph_time", Spec.TELEGRAPH_MIN, true)
	check(caught.size() == 1 and caught[0].contains("probe_a") and caught[0].contains("probe_b") and not caught[0].contains("probe_c"),
			"...two gear that each pass alone but go under together are caught, though all three together pass (%s)" % [caught])
	var two_sets: Array[Dictionary] = [
		{id = &"probe_x", stat = &"lurker_telegraph_time", op = &"set", value = 1.0},
		{id = &"probe_y", stat = &"lurker_telegraph_time", op = &"set", value = 1.2}]
	caught = stat_floor_errors(two_sets, &"lurker_telegraph_time", Spec.TELEGRAPH_MIN, true)
	check(caught.size() == 1 and caught[0].contains("Tuning refuses"), "...two gear that both set it are reported, not crashed on (%s)" % [caught])
	# The crawler's hover phase is fposmod(…, period) and its drift sin(t / period): at 0 the
	# crawler goes NaN (deferred from the code review of 1.3, closed here).
	real = stat_floor_errors(Gear.TABLE, &"crawler_hover_period", 0.0, false)
	check(real.is_empty(), "the crawler hover period stays above 0 under every combination of Gear.TABLE rows (%s)" % [real])
	var flat: Array[Dictionary] = [{id = &"probe_flat", stat = &"crawler_hover_period", op = &"mul", value = 0.0}]
	caught = stat_floor_errors(flat, &"crawler_hover_period", 0.0, false)
	check(caught.size() == 1, "...and a probe gear zeroing it is caught (%s)" % [caught])


## Story 1.3 traded compile-checked export names for key literals, so a typo or a key no code reads
## would only show when that branch is played, in a debug build (code review of 1.3).
func _test_key_literals() -> void:
	var re := RegEx.create_from_string("\\bf\\(&\"(\\w+)\"\\)")
	var files := _gd_files("res://scripts")
	var used := {}
	var bad := []
	for path: String in files:
		var src := FileAccess.get_file_as_string(path)
		if FileAccess.get_open_error() != OK:
			bad.append("%s unreadable" % path)
			continue
		for line in src.split("\n"):
			for m in re.search_all(line.get_slice("#", 0)):  # code only: comments may quote f(&"key")
				used[StringName(m.get_string(1))] = true
				if not Tuning.BASE.has(StringName(m.get_string(1))):
					bad.append("%s: %s" % [path.get_file(), m.get_string(1)])
	check(files.size() >= 6 and not used.is_empty() and bad.is_empty(), "every f(&\"…\") key in scripts/ is a BASE key (%d files, %d keys; bad: %s)" % [files.size(), used.size(), bad])
	var unread := Tuning.BASE.keys().filter(func(k: StringName) -> bool: return not used.has(k))
	check(unread.is_empty(), "every BASE key is read somewhere in scripts/ (unread: %s)" % [unread])


func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir.path_join(d)))
	return out


func _script_vars(script: Script) -> Array:
	return script.get_script_property_list().map(func(p: Dictionary) -> String: return p.name)


## Story 1.3 is a pure refactor: each of the 44 M1 defaults keeps its number in its new home.
func _test_m1_fixture() -> void:
	var per_actor := {}
	for row: Dictionary in M1:
		var actor: String = row.m1.get_slice(".", 0)
		per_actor[actor] = per_actor.get(actor, 0) + 1
	check(M1.size() == 44 and per_actor == {"player": 28, "crawler": 5, "lurker": 11}, "the fixture has the 44 M1 exports: 28 player, 5 crawler, 11 lurker (got %s)" % [per_actor])
	var t := Tuning.new()
	var seen := {}  # Tuning key -> how many rows name it
	for row: Dictionary in M1:
		var actor: String = row.m1.get_slice(".", 0)
		var prop: String = row.m1.get_slice(".", 1)
		var script: Script = load(ACTORS[actor])
		var vars := _script_vars(script)
		if row.has("keys"):
			var keys: Array = row.keys
			for k: StringName in keys:
				seen[k] = seen.get(k, 0) + 1
			var got: Variant = t.f(keys[0]) if keys.size() == 1 else Vector2(t.f(keys[0]), t.f(keys[1]))
			check(got == row.value and not vars.has(prop), "%s = %s is Tuning %s (got %s) and gone from %s.gd" % [row.m1, row.value, keys, got, actor])
		elif row.has("setting"):
			var got: Variant = Settings.SCHEMA[row.setting].default
			var consts := script.get_script_constant_map()
			check(got == row.value and not vars.has(prop) and not consts.has(row.gone), "%s = %s is the Settings.%s default (got %s), with no %s const or var left in %s.gd" % [row.m1, row.value, row.setting, got, row.gone, actor])
		elif row.has("local"):
			var home: String = row.get("home", ACTORS[actor])
			var got: Variant = (load(home) as Script).get_script_constant_map().get(row.local)
			check(got == row.value and not vars.has(prop), "%s = %s stays local as %s.%s (got %s), no longer a var" % [row.m1, row.value, home.get_file().get_basename(), row.local, got])
		else:
			var c := Crawler.new()
			check(vars.has(prop) and c.hover == row.value, "%s stays a per-instance var, default %s (got %s)" % [row.m1, row.value, c.hover])
			c.queue_free()
	var orphans := Tuning.BASE.keys().filter(func(k: StringName) -> bool: return seen.get(k, 0) != (0 if k in M2_KEYS else 1))
	check(orphans.is_empty(), "every BASE key comes from exactly one M1 export, except the M2 keys %s, which come from none (not: %s)" % [M2_KEYS, orphans])


## The playtested FR numbers that never were exports: the boxes, the chain curve and the hitstop
## depth (GDD Attack, pogo and chain (M1)). The GDD rounds the curve, hence the tolerances.
func _test_fr_values() -> void:
	check(ChainState.MAX_CHAIN == 20, "the chain caps at 20 links (got %d)" % ChainState.MAX_CHAIN)
	check(ChainState.BASE_RADIUS == 40.0 and ChainState.SNUFF_RADIUS == 12.0, "light is 40 px with no chain, 12 px snuffed (got %s / %s)" % [ChainState.BASE_RADIUS, ChainState.SNUFF_RADIUS])
	var want_radius := {0: 40.0, 4: 84.0, 10: 110.0, 20: 138.0}
	for links: int in want_radius:
		var r := ChainState.radius_for(links)
		check(absf(r - want_radius[links]) < 0.5, "light radius 40 + 22·√links is %s px at %d links (got %.1f)" % [want_radius[links], links, r])
	check(ChainState.bloom_for(0) == 1.0, "Blade Bloom is x1.0 with no chain (got %s)" % ChainState.bloom_for(0))
	var top := ChainState.bloom_for(ChainState.MAX_CHAIN)
	check(absf(top - 1.8) < 0.01 and ChainState.bloom_for(ChainState.MAX_CHAIN + 5) == top, "Blade Bloom 1 + 0.18·√links tops out at x1.8 (got %.3f)" % top)
	check(Player.HITSTOP_SCALE == 0.05, "the pogo hitstop freezes time to x0.05 (got %s)" % Player.HITSTOP_SCALE)
	# Read from an instance outside the tree, so _ready never runs; freed, or its RIDs leak at exit.
	var p: Node = PlayerScene.instantiate()
	var want_box := {"Body": Vector2(10, 20), "Hurtbox/Shape": Vector2(8, 18), "Slash/Shape": Vector2(22, 16), "Pogo/Shape": Vector2(26, 24)}
	for path: String in want_box:
		var rect := (p.get_node(path) as CollisionShape2D).shape as RectangleShape2D
		var got: Variant = rect.size if rect else null
		check(got == want_box[path], "player %s box is %s px (got %s)" % [path, want_box[path], got])
	p.queue_free()
