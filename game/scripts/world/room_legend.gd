class_name RoomLegend
## The one definition of every room grid char (AR21, Story 1.5 D4). `docs/rooms.md` documents it.
## A new char is added to docs/rooms.md first, then here, then as a case in test_room_loader.gd.

const WALL := "#"
const EMPTY := "."
const SPAWN := "P"  ## the player's start; nothing is spawned for it (Room.entry_position(&"spawn"))
## Tile chars that hurt on contact; 1.19 adds the spike. A hazard is never a ledge, and the room
## sweep (Story 1.10) checks every hazard pit has a ledge or cling stretch within a 1.5 s fall above it.
const HAZARDS: Array[String] = []

## Chars that spawn an entity through Room.spawn(): `args` are set before add_child (AR23).
## `in_wall = true`: next to a wall or the room edge, the cell also gets a wall tile, so a lurker
## hiding in a wall leaves no hole in it (M1's rule, plus the edge for 1-tile walls, D5).
## `killable = true`: the player can kill it, so the build gives it `room_id` + `cell` and skips it
## once DiveState marks that cell killed (AR24). Lurkers can't be killed in E1.
## `persistent = true` will mark a kind that needs an `obj=` id; the first is `A` (anchor, 1.24).
const SPAWNS := {
	"c": {scene = preload("res://scenes/actors/crawler.tscn"), args = {hover = false}, killable = true},
	"h": {scene = preload("res://scenes/actors/crawler.tscn"), args = {hover = true}, killable = true},
	"L": {scene = preload("res://scenes/actors/lurker.tscn"), args = {}, in_wall = true},
}


static func is_known(ch: String) -> bool:
	return ch == WALL or ch == EMPTY or ch == SPAWN or SPAWNS.has(ch)


static func is_in_wall(ch: String) -> bool:
	return SPAWNS.has(ch) and SPAWNS[ch].get("in_wall", false)
