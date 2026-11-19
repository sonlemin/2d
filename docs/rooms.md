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
| `exits` | no | Comma-separated `<side>:<target_id>@x<col>`, side `up` or `down`, `col` in `1..width-2` (never a corner). At most one exit per side. |
| `obj` | no, repeatable | `<id>@<col>,<row>`: a persistent object's id and cell. Ids are unique across every room file: the validator checks one file, `smoke_rooms` checks across files (Story 1.10). |
| `cling` | no, repeatable | `<from>-<to>`: a **narrow cling stretch**, 0-based grid rows, inclusive (`from < to`, both inside the grid; stretches may overlap). Every row of it counts as somewhere to land for the spine-fall check, and every open run in those rows must be 6–10 tiles wide (GDD Narrow stretch). The build ignores it; only the room checks read it (Story 1.10). |

Any other key is an error, so a typo can't pass silently. `map=` and left/right exits (`@y<row>`) arrive with E4.

Columns and rows in `@x<col>`, `obj=` and `cling=` are **0-based grid cells**. Validator messages use **1-based file positions** (see below).

### Exits

`@x<col>` names the leftmost column of an opening in the top row (`up`) or the bottom row (`down`). The opening is that cell plus the open cells to its right in that row. `World` polls the player each physics frame (Story 1.7): when the body centre is past the floor (or above the ceiling), it crosses that side's exit. A live chain is banked first, exactly like a landing, then `World.enter_room(target, entry)` swaps rooms at the end of the frame. Crossing a `down` exit arrives at the target's `up` entry: one cell inside the top opening, **still falling**. Crossing an `up` exit arrives at the target's `down` entry: **standing still on the floor beside the bottom opening**, never over it, so the player can't drop straight back out (see the validator rule below). `m1_shaft`'s two exits both target `m1_shaft`: falling out of the floor hole loops back in at the top (R16). Every swap rebuilds the room; enemies killed this dive are skipped.

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
- **Hazards:** `RoomLegend.HAZARDS` lists the tile chars that hurt on contact. It is empty until Story 1.19 adds the spike. A hazard is never a ledge, and neither is a floor cell whose open top is a hazard. Story 1.19 adds the spike to the legend (so the validator knows the char) and to `HAZARDS`; the room checks below then cover it with no test edit.
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
- a malformed exit or `obj` (coordinates are at most 4 digits); two exits on one side; a duplicate `obj` id in the file
- a malformed `cling` (not `<from>-<to>`, rows at most 4 digits); a `cling` whose `<from>` is not less than its `<to>`; a `cling` whose `<to>` is outside the grid (checked whenever the grid has rows, even if they are unequal)
- an empty first grid row (a blank line right after `---`, reported alone); a grid smaller than 3 × 3; unequal rows (against row 1's width); an unknown char
- a spine room that isn't 22 wide; every `P` after the first
- **(only when every row has the same width)** a `P` with nothing solid below it; an `obj` cell outside the grid; an exit column on a corner (0 or width−1), outside the grid or on a solid cell; for `up`, a solid **entry cell** (one cell inside the opening, where an arriving player appears); for `down`, **no floor beside the opening to arrive on**: neither the column right of the opening nor the one left of it (side-edge columns don't count) has a solid run from the bottom row with two open cells above it (the stand cell and headroom for the body)
- **the edge rule:** every cell in the top and bottom rows and the left and right columns must be solid or part of a declared exit opening, or the player could leave the room through a hole. An opening is the exit cell plus the open cells right of it, stopping before the corner, so an open corner is always a hole

A missing file is `"<path>:0:0 file not found"`.

## The Room API

`Room` (`class_name Room`, `extends Node2D`) builds headless, without `World`, a save or the hub. Its children are `Backdrop` (a `ColorRect` the size of the room, z −10), `Walls` (a `TileMapLayer` with a TileSet built once in code and cached), `Rims`, and the spawned entities.

| Member | What it gives |
|---|---|
| `id`, `zone`, `spine`, `exits` (`{side, target, col, entry_cell}`), `objects` (`{id: Vector2i}`), `size_cells` | the header and grid size |
| `bounds()` | room-local `Rect2(0, 0, cols × 16, rows × 16)`; `m1_shaft` is 352 × 1680 |
| `entry_position(entry)` | room-local. `&"spawn"`: the `P` cell with feet on the tile below. `&"up"`: one cell inside the top opening's first column (row 1). `&"down"`: the stand cell beside the bottom opening (`RoomLoader.down_entry_cell()`; `m1_shaft`: cell (3, 102)). Both with feet on the tile below. Asserts on an unknown entry. Anchors and stations join in 1.24. |
| `has_entry(entry)` | whether that entry exists |
| `exit(side)` | the exit dict on that side, or `{}` |
| `spawn(scene, pos, args := {})` | instances `scene`, sets each arg before `add_child` (so `_ready` sees it), and returns the node |
| `is_solid(cell)`, `cell_centre(cell)` | for tests and the room sweep |

`RoomLoader.load_room(id, dive = null)` resolves an id through an index of every `*.txt` under `res://rooms/`, built once (an id in two files is an error naming both). `load_room_from_path(path, dive = null)` loads one file directly. With a `DiveState`, killable spawns (`c`, `h`) whose cell it marked killed are not built; without one (tests, the harness) every enemy is. Killable spawns get `room_id` and `cell`, and a crawler's `take_hit()` marks its cell. Tests index their own rooms with `RoomLoader.add_root(dir)`: the swap rooms live in `tests/rooms/swap/` and DevTools' `t_dev_room` in `tests/rooms/dev_tools/`, apart from the validator fixtures in `tests/rooms/` (one of which repeats an id on purpose).

## Room checks

Adding a room file adds its checks, with no edit to any test (Story 1.10, AR50). `smoke_rooms.gd` walks every `res://rooms/**/*.txt` itself, sorted by path (it needs at least one file, and `rooms/l1/m1_shaft.txt` among them). The pure sweeps live in `tests/room_sweep.gd`, unit-tested on inline grids in `test_room_sweep.gd`.

**Every file:** `RoomLoader.parse()` + `validate()`; each error is one `FAIL`, and a file with errors is never built (so it never `push_error`s). Rooms are built by path, never through the id index, so a duplicate id is a named `FAIL` too. Each valid file is also built once to check that the sweeps read the same exits and obj ids the loader builds (the sweeps parse the header themselves).

**Across files (every file, `rooms/dev/` included):**
- room ids (base names) and `obj=` ids are unique;
- every exit target is a room, and has the entry the crossing arrives at: a `down` exit needs the target to have an `up` exit, an `up` exit a `down` one;
- a room outside `rooms/dev/` never exits into one (release exports exclude it, and it is never swept).

**Every swept room** (outside `rooms/dev/`):
- **spine falls** (`spine=true` only): no fall is over 19 rows, `Spec.LEDGE_FALL_MAX` (315 px: 1.5 s at the 210 px/s max fall, FR57): between consecutive safe rows; from the top (with an `up` exit) to the first safe row; from the last safe row to the floor (with a `down` exit). Safe rows are ledge rows (a solid inner cell, not a hazard, with **two** open, non-hazard cells above, since the body is 20 px tall) plus every row of a `cling=` stretch. A spine room with no safe row fails. The fall out of a `down` exit into a spine target counts as one fall: rows from the last safe row to the floor, plus the target's first safe row;
- **cling stretches:** every open run in each declared row is `Spec.NARROW_MIN`–`NARROW_MAX` (6–10) tiles wide;
- **hazard pits:** every hazard cell that can be fallen onto has a safe row in the 19 rows above it (GDD Sequence Breaking);
- **arrival from below:** no enemy spawn (a `RoomLegend.SPAWNS` char that isn't persistent) within 3 cells (Chebyshev) of the `down` entry's stand cell, about 1.9 s of walker travel (1.7 review, decided by sonlm 2026-11-18). `m1_shaft`'s bottom-left walker starts at column 8 for this;
- **lurkers**, each sorted by position: base light (40 px) is never noticed point-blank; the largest light under 80 px is never noticed point-blank, while the first light at the lurker's own notice floor is (a control; chain 4 today); the biggest light never wakes a lurker just outside the play rect (the player above, below or beside it), though it is in reach, while the same light at the same distance with the lurker on screen does (a control); the telegraph lasts at least 0.75 s (measured in frames), then it hunts and closes in. For the first lurker in each room, each scenario on a fresh room: an IDLE or a TELEGRAPHING lurker is harmless on contact and a HUNTING one, lethal at contact, kills; a Snuff, a landing and a cling (at either wall face with two empty columns beside it), each in time against a lurker hunting 48 px away, and a point-blank Snuff 18 px away (M1's case, where the braking lurker does reach the player), make it harmless (`monitorable` off) on the escape frame or the one after, the player is alive 1.2 s later, and it leaves HUNT within the lose-track time + 0.2 s and within 1 s whatever the tuning. A room with no stand cell or cling wall prints an `ok … skipped` line saying so.

Plus, once per run: the tuned max fall can't stretch `Spec.LEDGE_FALL_MAX` past 1.5 s, and the tuned telegraph and the lurker's notice floor are at least their `Spec` values.

**`smoke_bot.gd`** plays every `spine=true` room outside `rooms/dev/`, sorted by path, from its `up` entry (else `P`) down to its `down` exit: plain movement, Attack, a hop only when blocked, never Dash, all lurkers paused. It aims for the nearest crawler in a row below the last one it swung at, pogoes it, walks off a ledge at the edge nearest its next target, and slashes a walker on its floor within 24 px. Per room it must reach a chain of `Spec.BOT_MIN_CHAIN` (5; `m1_shaft`: 8), have chain 0 whenever its body crosses an exit (the World backstop never fires on its line), reach the `down` exit (or, with none, the bottom ledge), and be alive. A spine room with neither an `up` exit nor `P` is a named `FAIL` (nowhere to start). It prints a `bot <id>: frame …, best …` trace line.

**`rooms/dev/`** (the perf scene, Story 1.12) is validated and counts for unique ids and links, but is never swept or botted. Test-only rooms live in `game/tests/rooms/` and are never swept or exported.

```bash
cd game && ./run_tests.sh       # everything
godot --headless --path game res://tests/runner.tscn -- res://tests/test_room_loader.gd   # the validator, the build and m1_shaft's pins
godot --headless --path game res://tests/runner.tscn -- res://tests/test_room_sweep.gd    # the pure sweeps on inline grids
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_rooms.gd        # every room file: validation, sweeps, lurkers
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_bot.gd          # the descent bot in every spine room (~28 s on m1_shaft)
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_moves.gd        # the M1 move checks on m1_shaft
```

To play a room by hand, start any room with `-- --room=<id>` in a debug build (`godot --path game -- --room=m1_shaft`; `?room=<id>` in a web debug build): it starts at the `P`, else the `up` entry, else `down`, and an unknown or invalid room warns and loads `m1_shaft` ([development guide → DevTools](./development-guide.md#devtools-debug-builds-only)).

To try a room in a test, use `tests/room_harness.gd`: `RoomHarness.build(self, &"m1_shaft")` (or `build_from_path(self, path)` for a file you have validated) returns `{room, player, camera, world}` (the room at the origin, a test player at an entry, `&"spawn"` by default (pass `&"up"` for a room without `P`), a `CameraRig` following it with limits from the room, and a stub in group `world` with `play_rect()` and `current_room()`); free them with `RoomHarness.free_all()`.
