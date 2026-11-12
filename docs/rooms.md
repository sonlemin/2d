# Rooms

Every room is a text file, `game/rooms/<layer>/<room_id>.txt`: a header, a `---` line, then the grid, one char per 16 px tile (Architecture → Level Authoring, AR21). `RoomLoader` (`scripts/world/room_loader.gd`) parses it, checks it with a pure validator and builds a `Room` node (`scripts/world/room.gd`). The chars are defined only in `scripts/world/room_legend.gd` and in this doc.

The first room is `rooms/l1/m1_shaft.txt`, the M1 shaft at spine width (Story 1.5).

## File format

```
; m1_shaft: comment lines start with ';'
id=m1_shaft
zone=violet
spine=true
exits=up:m1_shaft@x3, down:m1_shaft@x1
---
###.##################
#....................#
#..P.................#
...
```

- **Header:** `key=value` lines up to a line that is exactly `---`. Blank lines and lines starting with `;` are ignored. `\r` and trailing spaces are stripped from every line, and trailing blank lines after the grid are dropped.
- **Grid:** every line after `---`, at least 3 × 3, all rows the same width. Row 0 is the ceiling.

| Key | Required | Value |
|---|---|---|
| `id` | yes | snake_case, equal to the file's base name. Ids are global and **never renamed once testers have saves**. |
| `zone` | yes | `dusk`, `umber` or `violet` (the GDD's Layer 1 zones) |
| `spine` | no (`false`) | `true` / `false`. A spine room must be exactly **22 columns wide, walls included** (352 px in the 360 px play area). |
| `exits` | no | Comma-separated `<side>:<target_id>@x<col>`, side `up` or `down`. At most one exit per side. |
| `obj` | no, repeatable | `<id>@<col>,<row>`: a persistent object's id and cell. Ids are unique within the file here; across files from Story 1.10. |

Any other key is an error, so a typo can't pass silently. `map=` and left/right exits (`@y<row>`) arrive with E4.

Columns and rows in `@x<col>` and `obj=` are **0-based grid cells**. Validator messages use **1-based file positions** (see below).

### Exits

`@x<col>` names the leftmost column of an opening in the top row (`up`) or the bottom row (`down`). The opening is that cell plus the open cells to its right in that row. Crossing a `down` exit arrives at the target room's `up` entry, and the reverse (wired in Story 1.7). `m1_shaft`'s two exits both target `m1_shaft`: falling out of the floor hole loops back in at the top (R16). Until 1.7, `shaft.gd` kills a player who falls out of the room.

## Legend

| Char | Meaning | Spawns |
|---|---|---|
| `#` | wall (solid, world layer 1) | — |
| `.` | empty | — |
| `P` | the player's start (`entry_position(&"spawn")`); at most one, with something solid below it | — |
| `c` | walking crawler | `crawler.tscn`, `hover = false` |
| `h` | hovering crawler | `crawler.tscn`, `hover = true` |
| `L` | lurker; may sit in a wall (in-wall rule) | `lurker.tscn` |

Entities spawn through `room.spawn(scene, cell_centre, args)` in grid order (row, then column), so a build is deterministic. The room owns them.

- **In-wall rule:** an `L` whose left or right neighbour is a wall **or the room edge** also gets a wall tile, so a lurker hiding in a wall leaves no hole. (M1 checked only the neighbours; with 1-tile walls a lurker sits in the edge column.) Such an `L` counts as solid everywhere below.
- **Solid** means `#`, plus an `L` that the in-wall rule turns solid.
- **Ledge rims:** every solid cell whose upper neighbour is in the grid and is neither solid nor `L` gets a faint unshaded 16 × 1 line, so places to land read in the dark (M1 finding 7).

### Adding a char

1. Add it to the legend table here first.
2. Add it to `RoomLegend` (`SPAWNS` for an entity, with its scene and its `args`; `in_wall = true` if it hides in walls). A persistent kind will carry `persistent = true` (the first is `A`, the anchor, in Story 1.24).
3. Add a case to `tests/test_room_loader.gd` (a fixture in `tests/rooms/` or an inline text).

## Validator errors

`RoomLoader.validate(path, parsed)` is pure: it returns an `Array[String]` of every error (not just the first) as `"<path>:<row>:<col> <what>"`, where `row` is the 1-based **file line** and `col` the 1-based char, so an editor jumps straight there. Header errors use column 1. `load_room_from_path()` `push_error`s each one and returns null; nothing builds from a bad file.

- no `---` line (reported alone)
- a missing `id` or `zone`; `id` not snake_case or not the file's base name
- an unknown key; a repeated `id`, `zone`, `spine` or `exits`
- a bad `zone` or `spine` value
- a malformed exit or `obj`; two exits on one side; a duplicate `obj` id in the file
- a grid smaller than 3 × 3; unequal rows (against row 1's width); an unknown char
- a spine room that isn't 22 wide; more than one `P`
- **(only when every row has the same width)** a `P` with nothing solid below it; an `obj` cell outside the grid; an exit column outside the grid or on a solid cell
- **the edge rule:** every cell in the top and bottom rows and the left and right columns must be solid or part of a declared exit opening, or the player could leave the room through a hole

A missing file is `"<path>:0:0 file not found"`.

## The Room API

`Room` (`class_name Room`, `extends Node2D`) builds headless, without `World`, a save or the hub. Its children are `Backdrop` (a `ColorRect` the size of the room, z −10), `Walls` (a `TileMapLayer` with a TileSet built once in code and cached), `Rims`, and the spawned entities.

| Member | What it gives |
|---|---|
| `id`, `zone`, `spine`, `exits` (`{side, target, col}`), `objects` (`{id: Vector2i}`), `size_cells` | the header and grid size |
| `bounds()` | room-local `Rect2(0, 0, cols × 16, rows × 16)`; `m1_shaft` is 352 × 1680 |
| `entry_position(entry)` | room-local. `&"spawn"`: the `P` cell with feet on the tile below. `&"up"` / `&"down"`: one cell inside the exit opening's first column (row 1 / the second-to-last row). Asserts on an unknown entry. Anchors and stations join in 1.24. |
| `has_entry(entry)` | whether that entry exists |
| `spawn(scene, pos, args := {})` | instances `scene`, sets each arg before `add_child` (so `_ready` sees it), and returns the node |
| `is_solid(cell)`, `cell_centre(cell)` | for tests and the room sweep |

`RoomLoader.load_room(id)` resolves an id through an index of every `*.txt` under `res://rooms/`, built once (an id in two files is an error naming both). `load_room_from_path(path)` loads one file directly.

## Running the checks

```bash
cd game && ./run_tests.sh       # everything; test_room_loader covers the validator, the build and m1_shaft
godot --headless --path game res://tests/runner.tscn -- res://tests/test_room_loader.gd
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_shaft.gd   # plays m1_shaft; the bot needs chain ≥ 5
```

`test_room_loader.gd` checks `m1_shaft`'s ledge rows: no fall between two of them is over 19 rows (FR57: a ledge every ≤ 1.5 s of fall). From Story 1.10, `smoke_rooms.gd` loads every room file and sweeps this for all of them. Test-only rooms live in `game/tests/rooms/` and are never exported.

To try a room in a test, use `tests/room_harness.gd`: `RoomHarness.build(self, &"m1_shaft")` returns `{room, player, world}` (the room at the origin, a test player at `spawn`, the camera centred, and a stub in group `world` with `play_rect()`); free them with `RoomHarness.free_all()`.
