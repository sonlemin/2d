class_name DiveState
extends RefCounted
## Per-dive state (AR10, AR14): what one dive from the hub carries. It resets in place on a rest,
## on arriving home and on leaving the layer, because subscribers hold on to it. The session's
## instance lives in `core/game.gd`. Written only through methods that emit a typed signal (AR18).
## Carried embers stay at risk until a station (GDD Economy); the death cost and the deposit arrive
## in Story 1.22. M1's "banked" embers are M2's carried ones.
## Killed enemies are never saved (architecture decision 5): `to_dict()` leaves them out, and a
## load or a reset brings every enemy back.

signal carried_changed(carried: int)
signal respawn_changed(room_id: StringName, entry: StringName)
## No subscriber: the room build reads is_killed() when it builds (Story 1.7); it exists because
## every write emits (AR18).
signal killed_marked(room_id: StringName, cell: Vector2i)

var carried := 0
## Where a death respawns you (D9), as `enter_room(room_id, entry)` takes it; an anchor or station
## id is an entry (Story 1.24). Empty: none set yet, so the dive's start room spawn (Story 1.6).
var respawn_room: StringName = &""
var respawn_entry: StringName = &""
var _killed := {}  # room id -> {Vector2i grid cell: true}


func add_carried(n: int) -> void:
	assert(n >= 0, "DiveState.add_carried(%d): an amount is never negative; losses arrive in Story 1.22" % n)
	if n == 0:
		return
	carried += n
	carried_changed.emit(carried)


func set_respawn(room_id: StringName, entry: StringName) -> void:
	if room_id == respawn_room and entry == respawn_entry:
		return
	respawn_room = room_id
	respawn_entry = entry
	respawn_changed.emit(room_id, entry)


func mark_killed(room_id: StringName, cell: Vector2i) -> void:
	if is_killed(room_id, cell):
		return
	if not _killed.has(room_id):
		_killed[room_id] = {}
	_killed[room_id][cell] = true
	killed_marked.emit(room_id, cell)


func is_killed(room_id: StringName, cell: Vector2i) -> bool:
	return _killed.has(room_id) and _killed[room_id].has(cell)


## JSON-ready (D4): the `dive` part of `user://slot_N.json` (Story 1.21), written whole by a resume
## save and kept as it was by a progress save. No killed enemies (decision 5).
func to_dict() -> Dictionary:
	return {"carried": carried, "respawn_room": String(respawn_room), "respawn_entry": String(respawn_entry)}


## Save data may be hand-edited or corrupt, an environment error, so this never asserts (D3): a
## missing or bad field takes its default. The respawn point is one value: when either half is
## bad, both are cleared, so half a point never loads. Always clears the killed enemies. Returns
## true when every field was present and valid.
func from_dict(d: Dictionary) -> bool:
	var n := _count(d.get("carried"))
	var room: Variant = d.get("respawn_room")
	var entry: Variant = d.get("respawn_entry")
	var point_ok := (room is String or room is StringName) and (entry is String or entry is StringName)
	_assign(maxi(n, 0), StringName(room) if point_ok else &"", StringName(entry) if point_ok else &"")
	return n >= 0 and point_ok


func reset() -> void:
	_assign(0, &"", &"")


## Sets every field first, then emits each value signal once, changed or not (D2). Clearing the
## killed enemies emits nothing: the room is rebuilt after a reset or a load.
func _assign(n: int, room_id: StringName, entry: StringName) -> void:
	carried = n
	respawn_room = room_id
	respawn_entry = entry
	_killed.clear()
	carried_changed.emit(carried)
	respawn_changed.emit(respawn_room, respawn_entry)


## A whole number ≥ 0, or -1. JSON numbers come back as floats, so a whole float counts, up to
## 2^53 (see SlotState.WHOLE_FLOAT_MAX).
static func _count(v: Variant) -> int:
	if typeof(v) == TYPE_FLOAT and v == floorf(v) and absf(v) <= SlotState.WHOLE_FLOAT_MAX:
		v = int(v)
	return v if typeof(v) == TYPE_INT and v >= 0 else -1
