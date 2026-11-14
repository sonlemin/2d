class_name Room
extends Node2D
## One room, built by RoomLoader from its text file (AR21–AR23). It owns everything spawned in it,
## so freeing the room frees its enemies, flares and FX. It builds headless, without World, a save
## or the hub, so tests load any room standalone.

const TILE := 16

## Set by RoomLoader before the room is returned.
var id: StringName
var zone: StringName
var spine := false
var exits: Array[Dictionary] = []  ## {side: &"up"/&"down", target: StringName, col: int, entry_cell: Vector2i}
var objects := {}  ## obj id (StringName) -> cell (Vector2i)
var size_cells := Vector2i.ZERO  ## columns, rows
var spawn_cell := Vector2i(-1, -1)  ## the `P` cell; (-1, -1) when the room has none
var walls: TileMapLayer


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
