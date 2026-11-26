class_name SlotState
extends RefCounted
## Per-slot state (AR10, AR14): what one save slot remembers. New Game and Load reset it in place
## with `reset()` / `from_dict()`, because subscribers hold on to it. The session's instance lives
## in `core/game.gd`. Written only through methods that emit a typed signal (AR18).
## `to_dict()` becomes save format slot_v1 at Story 1.41, when its key names freeze; until then a
## key may still change, after it never.
## Story 1.21 added play time, depth and the resume point, and `Game` saves the whole of it as the
## `slot` part of `user://slot_N.json`.
## Story 1.22 added deposited embers, the Ember Cache and the death cost by tier (apply_death()):
## embers go held (ChainState, per life) → carried (DiveState, per dive) → deposited (here, safe
## forever), and the cache lives here because it survives rests and saves (AR14).
## Not here yet, each added by its story: gear (E5), the death log and its cause ids (Story 1.29,
## from `player.death_cause`), abilities and the journal (E4–E7).

signal flag_set(id: StringName, value: bool)
signal records_changed
signal difficulty_changed(difficulty: StringName)
## A room was visited for the first time, or the visits were loaded or reset (the map, FR60).
signal visits_changed
## A whole second of play was added, or the slot was loaded or reset: about once a second, never
## per frame (Story 1.21).
signal play_time_changed(play_time: int)
signal resume_changed(room_id: StringName, entry: StringName)
signal deposited_changed(deposited: int)
## The Ember Cache was dropped, destroyed, recovered, loaded or reset: `(&"", 0)` when there is none.
## A load and a reset emit it too, so a listener that animates a drop reads apply_death()'s report.
signal cache_changed(room_id: StringName, amount: int)

## Difficulty changes only what a death costs (GDD Difficulty, FR25): DEATH_COST, read only by
## apply_death() (Story 1.22). StringName ids match DevTools' --difficulty and the TIER_* string keys (D8).
const DIFFICULTIES: Array[StringName] = [&"easy", &"normal", &"hard"]
const DEFAULT_DIFFICULTY := &"normal"
## 2^53. Above it a float no longer holds every whole number, so a JSON number that large was
## never a count this game wrote, and `int()` of a float beyond the int range differs by
## platform (1.4 review).
const WHOLE_FLOAT_MAX := 9007199254740992.0
## The `to_dict()` keys a progress save must not move (R14, Story 1.21 D6): `Game.save_progress()`
## writes the last resume save's values for them. The cache (Story 1.22 D5): a progress save never
## clears a cache the last resume save still holds, and never keeps one dropped since.
const RESUME_KEYS: Array[String] = ["resume_room", "resume_entry", "cache"]
## GDD Economy "Difficulty tiers": what a death costs. Nothing else reads the tier (FR25).
## held: carry (into the dive's carried) or lose. carried: keep, cache (the Ember Cache) or lose.
const DEATH_COST := {
	&"easy": {held = &"carry", carried = &"keep"},
	&"normal": {held = &"lose", carried = &"cache"},
	&"hard": {held = &"lose", carried = &"lose"},
}

var best_chain := 0  ## longest chain on this slot (Guild records, GDD Hub)
var deaths := 0  ## deaths on this slot (Guild records, GDD Hub)
var difficulty: StringName = DEFAULT_DIFFICULTY
var play_time := 0  ## whole seconds played on this slot, unpaused (the slot picker's line, Story 1.38)
var depth := 0  ## the deepest screen row reached; 0 = the top screen. A record: it only rises (1.21 D9)
## Where a load wakes the player, as `enter_room(room_id, entry)` takes it (1.21 D5): the dive's
## respawn point at the last resume save. Empty = the dive's start.
var resume_room: StringName = &""
var resume_entry: StringName = &""
var deposited := 0  ## embers safe forever (GDD Economy): only a rest or the hub adds them (Story 1.24, E5)
## The Ember Cache (FR24, Story 1.22 D2): at most one, held as value fields so no reader can change
## it past a rule method. Empty room = none.
var cache_room: StringName = &""
var cache_pos := Vector2.ZERO  ## room-local, on clean floor (Room.floor_spot(), D6)
var cache_amount := 0
var _play_fraction := 0.0  # the part of a second not yet in play_time; never saved
var _flags: Dictionary[StringName, bool] = {}  # only the flags that are set
var _visited: Dictionary[StringName, bool] = {}  # room ids entered on this slot


## Story progress and lit anchors; the first callers are the anchors and stations (Story 1.24).
## Flag ids are save data: never rename one.
func set_flag(id: StringName, value := true) -> void:
	if _flags.has(id) == value:
		return
	if value:
		_flags[id] = true
	else:
		_flags.erase(id)
	flag_set.emit(id, value)


func has_flag(id: StringName) -> bool:
	return _flags.has(id)


## World calls it on every room entry (AR24); the map fills in from it (FR60, E4). Room ids are
## save data from here: never rename a room once testers have saves.
func visit(room_id: StringName) -> void:
	if _visited.has(room_id):
		return
	_visited[room_id] = true
	visits_changed.emit()


func has_visited(room_id: StringName) -> bool:
	return _visited.has(room_id)


func record_chain(count: int) -> void:
	if count <= best_chain:
		return
	best_chain = count
	records_changed.emit()


## Story 1.29 adds the cause and the room, for the death log, from `player.death_cause`.
func record_death() -> void:
	deaths += 1
	records_changed.emit()


## Doesn't save: the progress save on a difficulty change is `Game.set_difficulty()`'s (Story 1.21;
## Options calls that in 1.36).
func set_difficulty(tier: StringName) -> void:
	assert(tier in DIFFICULTIES, "SlotState: unknown difficulty '%s'" % tier)
	if tier == difficulty:
		return
	difficulty = tier
	difficulty_changed.emit(tier)


## Real seconds of play, from World each frame (1.21 D8). Whole seconds move into `play_time`; a
## call that moved any emits once, however many it moved.
func add_play_time(seconds: float) -> void:
	assert(seconds >= 0.0, "SlotState.add_play_time(%s): time played is never negative" % seconds)
	_play_fraction += seconds
	if _play_fraction < 1.0:
		return
	var whole := floori(_play_fraction)
	_play_fraction -= whole
	play_time += whole
	play_time_changed.emit(play_time)


## World calls it with the player's screen row each tick; only a deeper row is a record.
func record_depth(row: int) -> void:
	if row <= depth:
		return
	depth = row
	records_changed.emit()


## Doesn't save: only `Game.save_now()`, the resume save, moves the resume point (R14).
func set_resume(room_id: StringName, entry: StringName) -> void:
	if room_id == resume_room and entry == resume_entry:
		return
	resume_room = room_id
	resume_entry = entry
	resume_changed.emit(room_id, entry)


func has_cache() -> bool:
	return cache_room != &""


## A rest (Story 1.24) or the hub (E5): every carried ember is safe from here. Returns the amount;
## emits once when it is > 0. Never touches the cache: a rest leaves it where it lies (AR14).
func deposit_from(dive: DiveState) -> int:
	var n := dive.take_carried()
	if n > 0:
		deposited += n
		deposited_changed.emit(deposited)
	return n


## The death cost (FR23, D3): the one rule a tier changes. World calls it with the held embers the
## dying player's chain lost (Player.held_at_death) and the drop spot, room-local. Any earlier cache
## is destroyed first, on every tier (D4, sonlm 2026-11-26), so at most one ever exists. Writes the
## dive only through its own methods, and never ends a chain: a death is never a bank, so it never
## bank-heals (FR12). Returns a plain report for the popup and the death card (Story 1.29).
func apply_death(dive: DiveState, held: int, room_id: StringName, pos: Vector2) -> Dictionary:
	assert(held >= 0, "SlotState.apply_death(): held embers are never negative (%d)" % held)
	var cost: Dictionary = DEATH_COST[difficulty]
	var report := {tier = difficulty, held_lost = 0, held_carried = 0, carried_cached = 0, carried_lost = 0,
			cache_destroyed = cache_amount if has_cache() else 0}
	var cache_moved := has_cache()
	cache_room = &""
	cache_pos = Vector2.ZERO
	cache_amount = 0
	if cost.held == &"carry":
		dive.add_carried(held)  # never break_chain(): that would emit `ended` and could bank-heal a dead life
		report.held_carried = held
	else:
		report.held_lost = held
	if cost.carried == &"cache" and dive.carried > 0:
		assert(room_id != &"", "SlotState.apply_death(): a cache needs a room")
		# The fields first, then the dive's own signal (D2, as _assign() does): a carried_changed
		# listener that looks here finds the embers in the cache, never nowhere.
		cache_amount = dive.carried
		cache_room = room_id
		cache_pos = pos
		report.carried_cached = dive.take_carried()
		cache_moved = true
	elif cost.carried == &"lose":
		report.carried_lost = dive.take_carried()
	if cache_moved:
		cache_changed.emit(cache_room, cache_amount)
	return report


## The player touched the cache (FR24): its embers are carried again, at risk until a rest. Returns
## the amount; with no cache, 0 and no signal. Both objects change before cache_changed goes out
## (D2), so its listeners find the embers carried, never nowhere.
func recover_cache(dive: DiveState) -> int:
	if not has_cache():
		return 0
	var n := cache_amount
	cache_room = &""
	cache_pos = Vector2.ZERO
	cache_amount = 0
	dive.add_carried(n)
	cache_changed.emit(&"", 0)
	return n


## The slot picker's line (Story 1.38): `Game` writes it as the save file's `meta`, with the time
## of the save, so the picker lists a slot without loading it. Nothing loads state from it.
func meta() -> Dictionary:
	return {"depth": depth, "best_chain": best_chain, "play_time": play_time, "difficulty": String(difficulty)}


## JSON-ready (D4). Flags and visited rooms are the ids, sorted as Strings (see _sorted_ids()).
## The fraction of a second of play time is not saved.
func to_dict() -> Dictionary:
	return {"best_chain": best_chain, "deaths": deaths, "difficulty": String(difficulty),
			"flags": _sorted_ids(_flags), "visited": _sorted_ids(_visited),
			"play_time": play_time, "depth": depth,
			"resume_room": String(resume_room), "resume_entry": String(resume_entry),
			"deposited": deposited, "cache": _cache_dict()}


## The save's "cache" (D5): always present, so Game._resume_part() can index it; null when none.
func _cache_dict() -> Variant:
	if not has_cache():
		return null
	return {"room": String(cache_room), "x": cache_pos.x, "y": cache_pos.y, "amount": cache_amount}


## Save data may be hand-edited or corrupt, an environment error, so this never asserts (D3): a
## missing or bad field takes its default, and a bad flag entry is skipped. The resume point is one
## value, like DiveState's respawn point: when either half is bad, both are cleared. Returns true
## when every field was present and valid.
func from_dict(d: Dictionary) -> bool:
	var best := _count(d.get("best_chain"))
	var died := _count(d.get("deaths"))
	var played := _count(d.get("play_time"))
	var deep := _count(d.get("depth"))
	var tier: Variant = d.get("difficulty")
	var tier_ok := (tier is String or tier is StringName) and StringName(tier) in DIFFICULTIES
	var room: Variant = d.get("resume_room")
	var entry: Variant = d.get("resume_entry")
	var point_ok := (room is String or room is StringName) and (entry is String or entry is StringName)
	var safe := _count(d.get("deposited"))
	var flags: Array[StringName] = []
	var visited: Array[StringName] = []
	var cache := {}
	var clean := best >= 0 and died >= 0 and played >= 0 and deep >= 0 and tier_ok and point_ok and safe >= 0
	clean = _read_ids(d.get("flags"), flags) and clean
	clean = _read_ids(d.get("visited"), visited) and clean
	clean = d.has("cache") and _read_cache(d.get("cache"), cache) and clean
	_assign(maxi(best, 0), maxi(died, 0), StringName(tier) if tier_ok else DEFAULT_DIFFICULTY, flags, visited,
			maxi(played, 0), maxi(deep, 0), StringName(room) if point_ok else &"", StringName(entry) if point_ok else &"",
			maxi(safe, 0), cache.get("room", &""), cache.get("pos", Vector2.ZERO), cache.get("amount", 0))
	return clean


func reset() -> void:
	_assign(0, 0, DEFAULT_DIFFICULTY, [], [], 0, 0, &"", &"", 0, &"", Vector2.ZERO, 0)


## Sets every field first, then emits (D2): flag_set per flag whose value changed, and
## records_changed, difficulty_changed, visits_changed, play_time_changed, resume_changed,
## deposited_changed and cache_changed once each, so a subscriber always refreshes. The fraction of
## a second starts again from 0.
func _assign(best: int, died: int, tier: StringName, flags: Array[StringName],
		visited: Array[StringName], played: int, deep: int, room_id: StringName, entry: StringName,
		safe: int, c_room: StringName, c_pos: Vector2, c_amount: int) -> void:
	var old := _flags.duplicate()
	best_chain = best
	deaths = died
	difficulty = tier
	play_time = played
	_play_fraction = 0.0
	depth = deep
	resume_room = room_id
	resume_entry = entry
	deposited = safe
	cache_room = c_room
	cache_pos = c_pos
	cache_amount = c_amount
	_flags.clear()
	for id in flags:
		_flags[id] = true
	_visited.clear()
	for id in visited:
		_visited[id] = true
	for id: StringName in old:
		if not _flags.has(id):
			flag_set.emit(id, false)
	# keys() is a copy: a handler may set a flag, and a key added mid-loop would be walked too
	# and emit twice.
	for id: StringName in _flags.keys():
		if not old.has(id):
			flag_set.emit(id, true)
	records_changed.emit()
	difficulty_changed.emit(difficulty)
	visits_changed.emit()
	play_time_changed.emit(play_time)
	resume_changed.emit(resume_room, resume_entry)
	deposited_changed.emit(deposited)
	cache_changed.emit(cache_room, cache_amount)


## Reads a saved cache into `into` ({room, pos, amount}); true when it is clean. null is no cache,
## clean. Anything else that isn't a whole cache (a wrong type, a missing field, an empty room, a
## coordinate that isn't a finite number, an amount under 1) is no cache and unclean: half a cache
## never loads. The position is judged as the Vector2 it becomes: a JSON double beyond the 32-bit
## range is finite as read and inf once stored (review of Story 1.22, probed).
static func _read_cache(v: Variant, into: Dictionary) -> bool:
	if v == null:
		return true
	if not v is Dictionary:
		return false
	var room: Variant = v.get("room")
	var x: Variant = v.get("x")
	var y: Variant = v.get("y")
	var n := _count(v.get("amount"))
	if not (room is String or room is StringName) or String(room).is_empty() or n < 1 \
			or not _finite_number(x) or not _finite_number(y):
		return false
	var pos := Vector2(float(x), float(y))
	if not pos.is_finite():
		return false
	into.room = StringName(room)
	into.pos = pos
	into.amount = n
	return true


static func _finite_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or (typeof(v) == TYPE_FLOAT and is_finite(v))


## Ids as Strings, sorted as Strings: Array.sort() on StringNames is not alphabetical, and a
## stable order keeps save diffs readable.
static func _sorted_ids(ids: Dictionary) -> Array:
	var out := []
	for id: StringName in ids:
		out.append(String(id))
	out.sort()
	return out


## Appends every good id in `list` to `into`; false when the list is missing or not an Array, or
## an entry is bad (skipped). An empty id names nothing, and a loaded id is save data from then on.
static func _read_ids(list: Variant, into: Array[StringName]) -> bool:
	if not list is Array:
		return false
	var clean := true
	for id: Variant in list:
		if (id is String or id is StringName) and not String(id).is_empty():
			into.append(StringName(id))
		else:
			clean = false
	return clean


## A whole number ≥ 0, or -1. JSON numbers come back as floats, so a whole float counts, up to
## WHOLE_FLOAT_MAX.
static func _count(v: Variant) -> int:
	if typeof(v) == TYPE_FLOAT and v == floorf(v) and absf(v) <= WHOLE_FLOAT_MAX:
		v = int(v)
	return v if typeof(v) == TYPE_INT and v >= 0 else -1
