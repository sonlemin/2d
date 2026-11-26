class_name Room
extends Node2D
## One room, built by RoomLoader from its text file (AR21–AR23). It owns everything spawned in it,
## so freeing the room frees its enemies, flares and FX. It builds headless, without World, a save
## or the hub, so tests load any room standalone.

const TILE := 16
## The hurting part of a hazard cell: its bottom 8 px, where the spikes are drawn (Story 1.19 D5), so
## the head of a player standing beside a spike run never touches one.
const HAZARD_HURT_TOP := 8

## Set by RoomLoader before the room is returned.
var id: StringName
var zone: StringName
var spine := false
var exits: Array[Dictionary] = []  ## {side: &"up"/&"down", target: StringName, col: int, entry_cell: Vector2i}
var objects := {}  ## obj id (StringName) -> cell (Vector2i)
var size_cells := Vector2i.ZERO  ## columns, rows
var spawn_cell := Vector2i(-1, -1)  ## the `P` cell; (-1, -1) when the room has none
var walls: TileMapLayer
var hazards := {}  ## every hazard cell (`^`), Vector2i -> true (Story 1.19)


## AR23: args are set before add_child, so the node's _ready() already sees them
## (Crawler.hover is read there).
func spawn(scene: PackedScene, pos: Vector2, args := {}) -> Node2D:
	var node: Node2D = scene.instantiate()
	for key: String in args:
		assert(key in node, "Room.spawn: %s has no property '%s'" % [scene.resource_path, key])
		node.set(key, args[key])
	node.position = pos
	add_child(node)
	return node


## Room-local. m1_shaft is (0, 0, 352, 1680).
func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size_cells * TILE))


func has_entry(entry: StringName) -> bool:
	if entry == &"spawn":
		return spawn_cell != Vector2i(-1, -1)
	return exit(entry) != {}


## Room-local, feet on the tile below the entry cell (M1's P formula: body bottom = +12).
## up: one cell inside the top opening (arriving from above, still falling). down: on the floor
## beside the bottom opening (arriving from below, Story 1.7 D3). Anchors and stations join in 1.24.
func entry_position(entry: StringName) -> Vector2:
	assert(has_entry(entry), "Room %s has no entry '%s'" % [id, entry])
	var cell: Vector2i = spawn_cell if entry == &"spawn" else exit(entry).entry_cell
	return Vector2(cell.x * TILE + TILE / 2.0, (cell.y + 1) * TILE - 12)


## Whether `rect` (room-local, the player's Hurtbox; the room sits at the world origin, so
## Player.hurt_rect()'s world space is the same) overlaps the bottom 8 px of a hazard cell.
## Edges that only touch don't count (Rect2.intersects).
func touches_hazard(rect: Rect2) -> bool:
	if hazards.is_empty():
		return false
	var first := Vector2i((rect.position / TILE).floor())
	var last := Vector2i((rect.end / TILE).floor())
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if hazards.has(Vector2i(x, y)) \
					and Rect2(x * TILE, y * TILE + HAZARD_HURT_TOP, TILE, TILE - HAZARD_HURT_TOP).intersects(rect):
				return true
	return false


## Story 1.19 D6: where a straight fall from `entry`'s cell first stands on clean floor: the first
## solid cell below it, when the cell above that is no hazard, with entry_position()'s feet formula.
## Else (the column ends on spikes, or in an open bottom) entry_position(entry) itself. World seeds
## its safe ground with it, so an `up` arrival hit before its first floor tick is returned to the
## floor below, never to the top opening. The Ember Cache's spot goes through floor_spot() too, which
## also covers the fallback (Story 1.22 D6).
func ground_below(entry: StringName) -> Vector2:
	assert(has_entry(entry), "Room %s has no entry '%s'" % [id, entry])
	var cell: Vector2i = spawn_cell if entry == &"spawn" else exit(entry).entry_cell
	for y in range(cell.y + 1, size_cells.y):
		if is_solid(Vector2i(cell.x, y)):
			if hazards.has(Vector2i(cell.x, y - 1)):
				break
			return Vector2(cell.x * TILE + TILE / 2.0, y * TILE - 12)
	return entry_position(entry)


## Story 1.22 D6: where the Ember Cache may lie, room-local, with entry_position()'s feet formula
## (the floor's top at pos.y + 12). `pos` itself when it stands on clean floor (the feet's cell in
## the room, not solid, no hazard; solid below; the feet within 1 px of that floor's top), else the
## nearest clean standing spot by distance, ties to the lower row index then the lower column (the
## scan order). It covers every way a drop spot goes bad: ground_below()'s fallback to a mid-air
## entry, a centre hanging past a ledge's edge, a hand-edited save, a room edited since the save.
## A room with no clean standing cell returns `pos` (validate() makes every real room have one).
func floor_spot(pos: Vector2) -> Vector2:
	# The feet sit on a tile edge: half a pixel up finds the standing row without float drift
	# moving a good spot into the floor's own row.
	var feet := Vector2i(floori(pos.x / TILE), floori((pos.y + 12.0 - 0.5) / TILE))
	if _stands_on_clean_floor(feet) and absf(pos.y + 12.0 - (feet.y + 1) * TILE) <= 1.0:
		return pos
	var best := pos
	var best_d := INF
	for y in size_cells.y:
		for x in size_cells.x:
			var cell := Vector2i(x, y)
			if not _stands_on_clean_floor(cell):
				continue
			var spot := Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE - 12)
			var d := spot.distance_squared_to(pos)
			if d < best_d:  # strictly smaller: the first in scan order wins a tie
				best_d = d
				best = spot
	return best


## A cell a body can stand in: inside the room, open, no hazard, with solid floor right below.
func _stands_on_clean_floor(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= size_cells.x or cell.y + 1 >= size_cells.y:
		return false
	return not is_solid(cell) and not hazards.has(cell) and is_solid(cell + Vector2i.DOWN)


func is_solid(cell: Vector2i) -> bool:
	return walls.get_cell_source_id(cell) != -1


func cell_centre(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(TILE, TILE) / 2.0


## The exit on `side` ({} when none). At most one exit per side (1.5 D3), so a side name is also
## its entry name.
func exit(side: StringName) -> Dictionary:
	for e in exits:
		if e.side == side:
			return e
	return {}
