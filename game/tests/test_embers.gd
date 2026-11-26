extends Node
## The three ember stages and the death cost by tier (Story 1.22, FR22–FR25): held (ChainState, per
## life) → carried (DiveState, per dive) → deposited (SlotState, per slot), the Ember Cache in the
## slot, apply_death()'s report per tier, the cache's save shape and its fallbacks, and FR25 by source
## (nothing but SlotState reads the tier). Pure: fresh SlotState / DiveState per case, no scene. The
## numbers are UX J3's (held 30, carried 40) and an earlier cache of 25.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_embers.gd
## Not tested here, because a failed assert aborts the test: a negative held amount, a cache with no
## room, an unknown tier (set_difficulty() asserts; DEATH_COST covers every tier it accepts).

const Lint := preload("res://tests/test_lint.gd")
const HELD := 30
const CARRIED := 40
const OLD := 25
const ROOM := &"m1_shaft"
const SPOT := Vector2(56, 1404)
const OLD_ROOM := &"a_side"
const OLD_SPOT := Vector2(24, 52)

var _fail := 0


func run() -> void:
	_test_take_carried()
	_test_deposit()
	_test_tier_table()
	_test_death_per_tier()
	_test_normal_with_nothing_carried()
	_test_recover()
	_test_emit_order()
	_test_rest_keeps_the_cache()
	_test_round_trips()
	_test_fallbacks()
	_test_load_signals()
	_test_fr25_by_source()
	print("PASS" if _fail == 0 else "FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


## Every cache_changed a slot emits, as [room, amount].
func _caches(s: SlotState) -> Array:
	var got := []
	s.cache_changed.connect(func(room: StringName, amount: int) -> void: got.append([room, amount]))
	return got


func _dive(carried: int) -> DiveState:
	var d := DiveState.new()
	d.add_carried(carried)
	return d


## A slot holding a cache of OLD in OLD_ROOM, dropped by a Normal death, then set to `tier`.
func _slot_with_cache(tier: StringName) -> SlotState:
	var s := SlotState.new()
	s.apply_death(_dive(OLD), 0, OLD_ROOM, OLD_SPOT)
	s.set_difficulty(tier)
	return s


func _test_take_carried() -> void:
	var d := DiveState.new()
	var got := []
	d.carried_changed.connect(func(c: int) -> void: got.append(c))
	check(d.take_carried() == 0 and got == [], "take_carried() with nothing carried returns 0 and emits nothing (got %s)" % [got])
	d.add_carried(CARRIED)
	got.clear()
	var n := d.take_carried()
	check(n == CARRIED and d.carried == 0 and got == [0], "take_carried() with 40 returns 40, carried 0, carried_changed(0) once (got %d, %d, %s)" % [n, d.carried, got])


func _test_deposit() -> void:
	var s := _slot_with_cache(&"normal")
	var d := _dive(CARRIED)
	var deposits := []
	var caches := _caches(s)
	s.deposited_changed.connect(func(v: int) -> void: deposits.append(v))
	var n := s.deposit_from(d)
	check(n == CARRIED and s.deposited == CARRIED and d.carried == 0, "deposit_from() moves the 40 carried into deposited and returns 40 (got %d, %d, %d)" % [n, s.deposited, d.carried])
	check(deposits == [CARRIED], "...emitting deposited_changed(40) once (got %s)" % [deposits])
	check(caches == [] and s.cache_room == OLD_ROOM and s.cache_amount == OLD and s.cache_pos == OLD_SPOT, "...and never touches the cache (AR14; got %s, %s %d)" % [caches, s.cache_room, s.cache_amount])
	n = s.deposit_from(d)
	check(n == 0 and s.deposited == CARRIED and deposits == [CARRIED], "a deposit of nothing returns 0 and emits nothing (got %d, %s)" % [n, deposits])
	d.add_carried(5)
	s.deposit_from(d)
	check(s.deposited == CARRIED + 5 and deposits == [CARRIED, CARRIED + 5], "deposits add up: 40 + 5 = 45 (got %d)" % s.deposited)


func _test_tier_table() -> void:
	var tiers: Array = SlotState.DEATH_COST.keys()
	check(tiers == Array(SlotState.DIFFICULTIES), "DEATH_COST has exactly one row per tier, in DIFFICULTIES order (got %s)" % [tiers])
	var report := SlotState.new().apply_death(DiveState.new(), 0, ROOM, SPOT)
	var keys := report.keys().map(func(k: Variant) -> String: return String(k))
	keys.sort()
	check(keys == ["cache_destroyed", "carried_cached", "carried_lost", "held_carried", "held_lost", "tier"], "the report has exactly tier, held_lost, held_carried, carried_cached, carried_lost, cache_destroyed (got %s)" % [keys])
	check(typeof(report.tier) == TYPE_STRING_NAME and report.tier == &"normal", "...the tier a StringName, normal by default (got %s)" % [report.tier])


## Per tier, with and without an earlier cache: [tier, earlier, report, carried after, cache after
## (room, amount), cache_changed].
func _test_death_per_tier() -> void:
	var cases := [
		[&"easy", false, {held_lost = 0, held_carried = HELD, carried_cached = 0, carried_lost = 0, cache_destroyed = 0}, HELD + CARRIED, [&"", 0], []],
		[&"easy", true, {held_lost = 0, held_carried = HELD, carried_cached = 0, carried_lost = 0, cache_destroyed = OLD}, HELD + CARRIED, [&"", 0], [[&"", 0]]],
		[&"normal", false, {held_lost = HELD, held_carried = 0, carried_cached = CARRIED, carried_lost = 0, cache_destroyed = 0}, 0, [ROOM, CARRIED], [[ROOM, CARRIED]]],
		[&"normal", true, {held_lost = HELD, held_carried = 0, carried_cached = CARRIED, carried_lost = 0, cache_destroyed = OLD}, 0, [ROOM, CARRIED], [[ROOM, CARRIED]]],
		[&"hard", false, {held_lost = HELD, held_carried = 0, carried_cached = 0, carried_lost = CARRIED, cache_destroyed = 0}, 0, [&"", 0], []],
		[&"hard", true, {held_lost = HELD, held_carried = 0, carried_cached = 0, carried_lost = CARRIED, cache_destroyed = OLD}, 0, [&"", 0], [[&"", 0]]],
	]
	for c: Array in cases:
		var tier: StringName = c[0]
		var s := _slot_with_cache(tier) if c[1] else SlotState.new()
		if not c[1]:
			s.set_difficulty(tier)
		var d := _dive(CARRIED)
		var caches := _caches(s)
		var report := s.apply_death(d, HELD, ROOM, SPOT)
		var want: Dictionary = c[2].duplicate()
		want.tier = tier
		var what := "%s, %s" % [tier, "an earlier cache of 25" if c[1] else "no earlier cache"]
		check(report == want, "apply_death() on %s, held 30 / carried 40: the report (got %s)" % [what, report])
		check(d.carried == c[3], "...%s: carried %d after (got %d)" % [what, c[3], d.carried])
		check([s.cache_room, s.cache_amount] == c[4] and s.has_cache() == (c[4][1] > 0), "...%s: the cache is %s (got %s %d)" % [what, c[4], s.cache_room, s.cache_amount])
		check(caches == c[5], "...%s: cache_changed %s (got %s)" % [what, c[5], caches])
		if s.has_cache():
			check(s.cache_pos == SPOT, "...%s: the cache lies at the drop spot (got %s)" % [what, s.cache_pos])


func _test_normal_with_nothing_carried() -> void:
	var s := SlotState.new()
	var caches := _caches(s)
	var report := s.apply_death(DiveState.new(), HELD, ROOM, SPOT)
	check(not s.has_cache() and report.carried_cached == 0 and report.held_lost == HELD and caches == [], "Normal with 0 carried makes no cache and emits nothing (got %s, %s)" % [report, caches])
	s = _slot_with_cache(&"normal")
	caches = _caches(s)
	report = s.apply_death(DiveState.new(), 0, ROOM, SPOT)
	check(not s.has_cache() and report.cache_destroyed == OLD and caches == [[&"", 0]], "...and still destroys an earlier cache: cache_destroyed 25, cache_changed('', 0) once (D4; got %s, %s)" % [report, caches])


func _test_recover() -> void:
	var s := SlotState.new()
	var d := _dive(CARRIED)
	s.apply_death(d, HELD, ROOM, SPOT)
	d.add_carried(7)
	var caches := _caches(s)
	var n := s.recover_cache(d)
	check(n == CARRIED and d.carried == 7 + CARRIED, "recover_cache() returns 40 and carried goes up by 40 (got %d, %d)" % [n, d.carried])
	check(not s.has_cache() and s.cache_amount == 0 and s.cache_pos == Vector2.ZERO and caches == [[&"", 0]], "...the slot has no cache and cache_changed('', 0) fired once (got %s)" % [caches])
	n = s.recover_cache(d)
	check(n == 0 and d.carried == 7 + CARRIED and caches.size() == 1, "a second recover_cache() returns 0 and emits nothing (got %d, %s)" % [n, caches])


## D2, review of Story 1.22: both objects hold their new values before either signal goes out, so a
## listener that reads the other object never finds the embers nowhere. Each entry: [signal, its
## value, what the other object held at that moment].
func _test_emit_order() -> void:
	var s := SlotState.new()
	var d := _dive(CARRIED)
	var seen := []
	var on_carried := func(c: int) -> void: seen.append(["carried", c, s.cache_amount])
	var on_cache := func(_room: StringName, amount: int) -> void: seen.append(["cache", amount, d.carried])
	d.carried_changed.connect(on_carried)
	s.cache_changed.connect(on_cache)
	s.apply_death(d, 0, ROOM, SPOT)
	check(seen == [["carried", 0, CARRIED], ["cache", CARRIED, 0]], "apply_death(): carried_changed(0) already finds the 40 in the cache, cache_changed(40) finds 0 carried (got %s)" % [seen])
	seen.clear()
	s.recover_cache(d)
	check(seen == [["carried", CARRIED, 0], ["cache", 0, CARRIED]], "recover_cache(): carried_changed(40) finds no cache left, cache_changed(0) finds the 40 carried (got %s)" % [seen])
	# Each handler holds the other object: disconnect, or the two RefCounteds keep each other alive
	# and Godot reports the leak as an ERROR: line at exit.
	d.carried_changed.disconnect(on_carried)
	s.cache_changed.disconnect(on_cache)


func _test_rest_keeps_the_cache() -> void:
	var s := _slot_with_cache(&"normal")
	var d := _dive(CARRIED)
	var caches := _caches(s)
	s.deposit_from(d)  # 1.24's order: heal → deposit_from → dive.reset() → rebuild → save
	d.reset()
	check(s.has_cache() and s.cache_room == OLD_ROOM and s.cache_amount == OLD and caches == [], "a rest (deposit_from(), then dive.reset()) leaves the cache where it lies (AR14; got %s %d, %s)" % [s.cache_room, s.cache_amount, caches])


## What a save file gives back: JSON.stringify, then the silent parser (R15).
func _through_json(d: Dictionary) -> Dictionary:
	var j := JSON.new()
	var err := j.parse(JSON.stringify(d, "\t"))
	check(err == OK and j.get_data() is Dictionary, "the dict survives JSON (error %d)" % err)
	return j.get_data() if j.get_data() is Dictionary else {}


func _test_round_trips() -> void:
	var s := _slot_with_cache(&"hard")
	s.deposit_from(_dive(15))
	var d := s.to_dict()
	check(d.deposited == 15 and typeof(d.deposited) == TYPE_INT, "to_dict() writes deposited as an int (got %s)" % [var_to_str(d.deposited)])
	check(d.cache is Dictionary and d.cache == {"room": "a_side", "x": 24.0, "y": 52.0, "amount": OLD}, "...and the cache as {room, x, y, amount} (D5; got %s)" % [d.cache])
	check(typeof(d.cache.room) == TYPE_STRING and typeof(d.cache.amount) == TYPE_INT, "...with a String room and an int amount, JSON-ready")
	var u := SlotState.new()
	var clean := u.from_dict(_through_json(d))
	check(clean and u.deposited == 15 and typeof(u.deposited) == TYPE_INT, "from_dict() through JSON is clean and deposited comes back as the int 15 (got %s)" % [var_to_str(u.deposited)])
	check(u.cache_room == OLD_ROOM and typeof(u.cache_room) == TYPE_STRING_NAME and u.cache_pos == OLD_SPOT and u.cache_amount == OLD and typeof(u.cache_amount) == TYPE_INT, "...the cache back as a StringName room, a Vector2 and an int (got %s %s %s)" % [var_to_str(u.cache_room), u.cache_pos, var_to_str(u.cache_amount)])
	var none := SlotState.new().to_dict()
	check(none.has("cache") and none.cache == null and none.deposited == 0, "with no cache, to_dict() still holds the key \"cache\": null (Game._resume_part() indexes it; got %s)" % [none.get("cache", "missing")])
	var v := _slot_with_cache(&"normal")
	check(v.from_dict(_through_json(none)) and not v.has_cache() and v.cache_amount == 0 and v.cache_pos == Vector2.ZERO, "...and loading it clears a cache the slot held (clean)")
	# Whole-number coordinates come back as floats from JSON; an int written by hand loads too.
	var w := SlotState.new()
	check(w.from_dict(_with_cache({"room": "m1_shaft", "x": 8, "y": 1404, "amount": 3.0})) and w.cache_pos == Vector2(8, 1404) and w.cache_amount == 3, "an int x / y and a whole-float amount load clean (got %s %d)" % [w.cache_pos, w.cache_amount])


## A whole, clean slot dictionary with `cache` set; erase_key drops one top-level key instead.
func _with_cache(cache: Variant, erase_key := "") -> Dictionary:
	var d := SlotState.new().to_dict()
	d["cache"] = cache
	if erase_key != "":
		d.erase(erase_key)
	return d


func _test_fallbacks() -> void:
	var good := {"room": "m1_shaft", "x": 56.0, "y": 1404.0, "amount": 40}
	var bad := {
		"a number": 5,
		"a string": "m1_shaft",
		"an array": [good],
		"an empty dictionary": {},
		"an empty room": _over(good, {"room": ""}),
		"a room that isn't a string": _over(good, {"room": 12}),
		"a missing room": _without(good, "room"),
		"an x that isn't a number": _over(good, {"x": "56"}),
		"an infinite y": _over(good, {"y": INF}),
		"an x beyond the 32-bit range, finite as a JSON double and inf in a Vector2": _over(good, {"x": 1e39}),
		"a NaN x": _over(good, {"x": NAN}),
		"a missing y": _without(good, "y"),
		"amount 0": _over(good, {"amount": 0}),
		"a negative amount": _over(good, {"amount": -4}),
		"a fractional amount": _over(good, {"amount": 2.5}),
		"a missing amount": _without(good, "amount"),
	}
	for what: String in bad:
		var s := _slot_with_cache(&"normal")
		var caches := _caches(s)
		var clean := s.from_dict(_with_cache(bad[what]))
		check(not clean and not s.has_cache() and s.cache_amount == 0 and s.cache_pos == Vector2.ZERO, "a cache that is %s is no cache and unclean (got %s, %s %d)" % [what, clean, s.cache_room, s.cache_amount])
		check(caches == [[&"", 0]], "...and emits cache_changed('', 0) once (got %s)" % [caches])
	var t := _slot_with_cache(&"normal")
	check(t.from_dict(_with_cache(null)) and not t.has_cache(), "cache null is no cache, clean")
	var u := _slot_with_cache(&"normal")
	u.deposit_from(_dive(9))
	check(not u.from_dict(_with_cache(null, "cache")) and not u.has_cache(), "a missing \"cache\" key is no cache and unclean (a file from before Story 1.22)")
	check(not u.from_dict(_with_cache(null, "deposited")) and u.deposited == 0, "a missing \"deposited\" key is 0 and unclean (got %d)" % u.deposited)
	var w := SlotState.new()
	var d := _with_cache(null)
	d["deposited"] = -3
	check(not w.from_dict(d) and w.deposited == 0, "a negative deposited is 0 and unclean (got %d)" % w.deposited)
	d["deposited"] = 12.0
	check(w.from_dict(d) and w.deposited == 12 and typeof(w.deposited) == TYPE_INT, "a whole-float deposited (JSON) loads as the int 12 (got %s)" % [var_to_str(w.deposited)])


func _over(base: Dictionary, over: Dictionary) -> Dictionary:
	var d := base.duplicate()
	d.merge(over, true)
	return d


func _without(base: Dictionary, key: String) -> Dictionary:
	var d := base.duplicate()
	d.erase(key)
	return d


## 1.4 D2: reset() and from_dict() emit deposited_changed and cache_changed once each, changed or not.
func _test_load_signals() -> void:
	var s := _slot_with_cache(&"normal")
	s.deposit_from(_dive(9))
	var caches := _caches(s)
	var deposits := []
	s.deposited_changed.connect(func(v: int) -> void: deposits.append(v))
	s.reset()
	check(caches == [[&"", 0]] and deposits == [0] and not s.has_cache() and s.deposited == 0, "reset() clears both and emits cache_changed('', 0) and deposited_changed(0) once each (got %s, %s)" % [caches, deposits])
	caches.clear()
	deposits.clear()
	s.reset()
	check(caches == [[&"", 0]] and deposits == [0], "...and again on a reset that changes nothing (got %s, %s)" % [caches, deposits])
	caches.clear()
	deposits.clear()
	var d := _with_cache({"room": "a_side", "x": 24.0, "y": 52.0, "amount": 25})
	d["deposited"] = 9
	s.from_dict(d)
	check(caches == [[OLD_ROOM, OLD]] and deposits == [9], "from_dict() emits cache_changed(a_side, 25) and deposited_changed(9) once each (got %s, %s)" % [caches, deposits])


## FR25: difficulty changes only what a death costs, so nothing but SlotState reads the tier. Code
## only (comments dropped by test_lint's strip()): a comment may say why something is not a tier.
## Every folder under scripts/ is scanned, so a new one (moments/, audio/) is covered the day it
## appears (review of Story 1.22); FR25_MAY_NAME_IT lists who may name the tier, and why.
const FR25_MAY_NAME_IT := {
	"res://scripts/rules/slot_state.gd": "holds the tier and the death cost",
	"res://scripts/core/game.gd": "the set_difficulty() command, which saves progress",
	"res://scripts/dev/": "DevTools' --difficulty",
	"res://scripts/ui/": "Options and the slot picker show and set it (Stories 1.36, 1.38)",
}


func _test_fr25_by_source() -> void:
	var hits := []
	var scanned := 0
	for path in _gd_files("res://scripts/"):
		if FR25_MAY_NAME_IT.keys().any(func(allowed: String) -> bool: return path.begins_with(allowed)):
			continue
		scanned += 1
		hits.append_array(_difficulty_lines(path))
	check(hits.is_empty(), "FR25: 'difficulty' appears in no code under scripts/ outside %s (got %s)" % [FR25_MAY_NAME_IT.keys(), hits])
	for dir in ["actors", "world", "objects", "rules", "core"]:
		check(not _gd_files("res://scripts/%s/" % dir).is_empty(), "...and scripts/%s/ holds scripts, so the scan reached it" % dir)
	check(scanned > 20 and not _difficulty_lines("res://scripts/rules/slot_state.gd").is_empty(), "...and the scan can fire: it finds the word in slot_state.gd (%d files scanned)" % scanned)
	var keys := Tuning.BASE.keys().filter(func(k: StringName) -> bool: return String(k).contains("difficulty"))
	check(keys.is_empty(), "...and no Tuning key names it: difficulty is never a modifier (got %s)" % [keys])


## "path:line" for every line of code in `path` that names the tier.
func _difficulty_lines(path: String) -> Array:
	var out := []
	var open := ""
	var n := 0
	for line in FileAccess.get_file_as_string(path).split("\n"):
		n += 1
		var s: Dictionary = Lint.strip(line, open)
		open = s.open
		if s.code.to_lower().contains("difficulty"):
			out.append("%s:%d" % [path, n])
	return out


func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out  # the caller's "holds scripts" check reports it; get_files_at() would print an engine ERROR
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + f)
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir + sub + "/"))
	return out
