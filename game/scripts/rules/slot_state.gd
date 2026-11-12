class_name SlotState
extends RefCounted
## Per-slot state (AR10, AR14): what one save slot remembers. New Game and Load reset it in place
## with `reset()` / `from_dict()`, because subscribers hold on to it. The session's instance lives
## in `core/game.gd`. Written only through methods that emit a typed signal (AR18).
## `to_dict()` becomes save format slot_v1 at Story 1.41, when its key names freeze; until then a
## key may still change, after it never.
## Not here yet, each added by its story: deposited embers and the Ember Cache (1.22), map visits
## (1.7), gear (E5), the death log and cause ids (1.19 / 1.29), play time and the resume point
## (1.21), abilities and the journal (E4–E7).

signal flag_set(id: StringName, value: bool)
signal records_changed
signal difficulty_changed(difficulty: StringName)

## Difficulty changes only what a death costs (GDD Difficulty, FR25); the rules arrive in
## Story 1.22. StringName ids match DevTools' --difficulty and the TIER_* string keys (D8).
const DIFFICULTIES: Array[StringName] = [&"easy", &"normal", &"hard"]
const DEFAULT_DIFFICULTY := &"normal"

var best_chain := 0  ## longest chain on this slot (Guild records, GDD Hub)
var deaths := 0  ## deaths on this slot (Guild records, GDD Hub)
var difficulty: StringName = DEFAULT_DIFFICULTY
var _flags: Dictionary[StringName, bool] = {}  # only the flags that are set


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


func record_chain(count: int) -> void:
	if count <= best_chain:
		return
	best_chain = count
	records_changed.emit()


## Story 1.19 adds the cause and the room, for the death log.
func record_death() -> void:
	deaths += 1
	records_changed.emit()


## Doesn't save: the progress save on a difficulty change belongs to its caller (Story 1.21 / 1.36).
func set_difficulty(tier: StringName) -> void:
	assert(tier in DIFFICULTIES, "SlotState: unknown difficulty '%s'" % tier)
	if tier == difficulty:
		return
	difficulty = tier
	difficulty_changed.emit(tier)


## JSON-ready (D4). Flags are the set ids, sorted as Strings: Array.sort() on StringNames is not
## alphabetical, and a stable order keeps save diffs readable.
func to_dict() -> Dictionary:
	var flags := []
	for id: StringName in _flags:
		flags.append(String(id))
	flags.sort()
	return {"best_chain": best_chain, "deaths": deaths, "difficulty": String(difficulty), "flags": flags}


## Save data may be hand-edited or corrupt, an environment error, so this never asserts (D3): a
## missing or bad field takes its default, and a bad flag entry is skipped. Returns true when every
## field was present and valid.
func from_dict(d: Dictionary) -> bool:
	var best := _count(d.get("best_chain"))
	var died := _count(d.get("deaths"))
	var tier: Variant = d.get("difficulty")
	var tier_ok := (tier is String or tier is StringName) and StringName(tier) in DIFFICULTIES
	var list: Variant = d.get("flags")
	var clean := best >= 0 and died >= 0 and tier_ok and list is Array
	var flags: Array[StringName] = []
	if list is Array:
		for id: Variant in list:
			if id is String or id is StringName:
				flags.append(StringName(id))
			else:
				clean = false
	_assign(maxi(best, 0), maxi(died, 0), StringName(tier) if tier_ok else DEFAULT_DIFFICULTY, flags)
	return clean


func reset() -> void:
	_assign(0, 0, DEFAULT_DIFFICULTY, [])


## Sets every field first, then emits (D2): flag_set per flag whose value changed, and
## records_changed and difficulty_changed once each, so a subscriber always refreshes.
func _assign(best: int, died: int, tier: StringName, flags: Array[StringName]) -> void:
	var old := _flags.duplicate()
	best_chain = best
	deaths = died
	difficulty = tier
	_flags.clear()
	for id in flags:
		_flags[id] = true
	for id: StringName in old:
		if not _flags.has(id):
			flag_set.emit(id, false)
	for id: StringName in _flags:
		if not old.has(id):
			flag_set.emit(id, true)
	records_changed.emit()
	difficulty_changed.emit(difficulty)


## A whole number ≥ 0, or -1. JSON numbers come back as floats, so a whole float counts.
static func _count(v: Variant) -> int:
	if typeof(v) == TYPE_FLOAT and v == floorf(v):
		v = int(v)
	return v if typeof(v) == TYPE_INT and v >= 0 else -1
