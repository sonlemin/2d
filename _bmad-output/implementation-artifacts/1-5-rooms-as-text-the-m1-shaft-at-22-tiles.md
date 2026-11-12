---
baseline_commit: 656a7a2
---

# Story 1.5: Rooms as text, the M1 shaft at 22 tiles

Status: done

**Type:** dev, content (human gate: sonlm plays the 22-column layout on the laptop and approves it **before the story goes to `review`**; see D1) · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP1 Foundations (1.1–1.15) · **Branch:** `feat/m2-e1`

## Story

As the level designer,
I want rooms written as text files that are validated before they build,
so that every room is reviewable in git, testable on its own, and fits the 360 px play area.

## Acceptance Criteria

1. **The room file.** `game/rooms/l1/m1_shaft.txt` has a `key=value` header (`id=m1_shaft`, `zone=violet`, `spine=true`, `exits=up:m1_shaft@x3, down:m1_shaft@x1`), then `---`, then the grid in Dev Notes → *The approved layout*: 105 equal-width rows of 22 columns including the walls, 1 char = 16 px. Its bottom exit leads to its own top entry (R16). `RoomLoader.load_room_from_path("res://rooms/l1/m1_shaft.txt")` gets no errors from the pure validator, and the room builds with the TileSet and ledge rims made in code (AR21, AR22, FR39).
2. **The layout keeps the M1 shaft's intent within 352 px:** hoverer rows with left/right choices, lurker pockets with an escape in reach, and ledges every ≤ 1.5 s of fall (≤ 19 rows between ledge rows, FR57). The 22-column layout is level design: it is the draft in Dev Notes, and **sonlm approves it after playing it on the laptop** (D1). He plays from the pushed branch, so the layout is committed as a draft first; the story cannot go to `review` until he says yes. The dev agent HALTs at that gate and never marks it done itself.
3. **The ported tests.** `tests/smoke_shaft.gd` and `tests/screenshot.gd` load `m1_shaft` through `RoomLoader` with a test player and a stub node in group `world` that provides `play_rect()`. M1's hard-coded coordinates (the spawn ledge, the 2-tile walls, rows 44–84) are retargeted by position through the room API. Every M1 smoke check passes against the 22-column layout, and neither file loads `shaft.tscn` any more. `smoke_shaft_state.gd` is the one test that still loads `shaft.tscn`; it tests the shaft's own wiring until Story 1.6 retires it (D2).
4. **The validator.** A room file with unequal rows, an unknown char or a duplicate id (fixtures in `tests/rooms/`) gets `Array[String]` errors from the pure validator, as `file:row:col` messages. The loader `push_error`s each one and returns null. Tests inspect the list and never trigger `push_error`.
5. **The legend.** `world/room_legend.gd` is the single definition of every grid char (`#` wall, `.` empty, `P` spawn, `c` walking crawler, `h` hovering crawler, `L` lurker). It is documented in the new `docs/rooms.md`, and a new char is added there first.
6. **The room node.** In `world/room.gd` (`class_name Room`), `spawn(scene, pos, args := {})` sets the args before `add_child`, and `entry_position(entry)` and `bounds()` exist (AR23). The room builds headless without `World`, a save or the hub. `RoomLoader.load_room(id)` resolves an id to its file under `res://rooms/`.
7. **The playable game builds the room (D2).** `shaft.gd` loses `LAYOUT` and its builder. It builds `m1_shaft` through `RoomLoader`, places its player at `entry_position(&"spawn")`, and centres the 352 px room in the 480 px view. Everything else it does stays as it is (HUD label, F1/F3, `Game` wiring, the reload on death) until Stories 1.6 and 1.7.
8. **Done means green.** `cd game && ./run_tests.sh` ends in `== ALL GREEN`, with the new `test_room_loader` in the `for t in …` list. Report "tests green; needs a feel check on the laptop", never "feels the same".

## Tasks / Subtasks

Run everything from `game/` and wrap every Godot run in `timeout`.

- [x] **Task 1: Baseline** (AC: 8)
  - [x] Run `timeout 600 ./run_tests.sh` on `656a7a2`. Expected (re-run at story creation): `test_chain_state` `ALL PASS (69 checks)`, then `test_log`, `test_clock`, `test_tuning`, `test_state`, `test_deferred_owners` `PASS`, then `smoke_shaft` `SMOKE PASS` (29 `ok`) and `smoke_shaft_state` `SMOKE PASS` (14 `ok`), and `== ALL GREEN`.
- [x] **Task 2: Legend, loader, room** (AC: 1, 4, 5, 6)
  - [x] `scripts/world/room_legend.gd` (`class_name RoomLegend`): the char table (D4).
  - [x] `scripts/world/room_loader.gd` (`class_name RoomLoader`, static functions only): `parse()`, the pure `validate()`, `load_room_from_path()`, `load_room()` and the build (D3, D5, D6).
  - [x] `scripts/world/room.gd` (`class_name Room`, `extends Node2D`): the API in D7.
  - [x] Run `godot --headless --path . --import` after adding the `class_name`s. Commit the generated `.gd.uid` files and never write one by hand.
- [x] **Task 3: The room file** (AC: 1, 2)
  - [x] Write `game/rooms/l1/m1_shaft.txt` from Dev Notes → *The approved layout*: the header as in AC1, then the grid byte for byte. Check that the grid's md5 matches the one given there.
  - [x] Commit it with the shaft port (Task 6) in one commit whose message ends `(layout draft: awaiting sonlm's play approval)`.
- [x] **Task 4: Validator tests** (AC: 4, 1)
  - [x] `tests/rooms/`: the fixtures in D8.
  - [x] `tests/test_room_loader.gd`: D8's cases. Add it to `run_tests.sh`'s `for t in …` list, after `test_state`.
- [x] **Task 5: Port the tests** (AC: 3)
  - [x] `tests/room_harness.gd`: the shared helper in D9 (not run by the runner; its name matches neither `test_*` nor `smoke_*`).
  - [x] `tests/smoke_shaft.gd` on the harness: every M1 check kept, coordinates retargeted (D9). Every check message stays word for word, except where it names a tile or row.
  - [x] `tests/screenshot.gd` on the harness (D9). Run it once under `xvfb-run` and look at both PNGs.
- [x] **Task 6: The shaft builds the room** (AC: 7, 3)
  - [x] `shaft.gd` / `shaft.tscn` as in D2. `smoke_shaft_state.gd` changes only where the shaft's node tree changed.
- [x] **Task 7: Gate: sonlm plays the layout** (AC: 2)
  - [x] Ask sonlm before pushing `feat/m2-e1` (a push is outward-facing), push, then HALT. Ask him to pull and play `shaft.tscn` on the laptop (F5). Give him the draft's facts: the rows of the three new wall ledges, the exit hole, and the bot's best chain from `smoke_shaft`.
  - [x] Record his answer and the date in the Dev Agent Record. If he asks for changes, edit the grid, re-run Task 4's layout checks and `smoke_shaft`, commit the change as a follow-up, and ask again. Set the story to `review` only after a yes.
- [x] **Task 8: Docs** (AC: 5)
  - [x] New `docs/rooms.md` (D10).
  - [x] Update the facts that change: `docs/development-guide.md` §Edit the Level and its test list; `docs/architecture.md` §Level Data and the play-width / scene-structure rows of the gap table; `docs/component-inventory.md` (Shaft, the new world scripts, the test table); `docs/source-tree-analysis.md`; `docs/index.md`; `game/README.md` (the test list); `_bmad-output/project-context.md` → *Current State vs Target* (one sentence for Story 1.5). Facts only.
- [x] **Task 9: Verify** (AC: 8)
  - [x] `timeout 600 ./run_tests.sh` → `== ALL GREEN`.
  - [x] `grep -rn "shaft.tscn" tests/` lists only `smoke_shaft_state.gd`.
  - [x] `grep -rn "LAYOUT" scripts/` finds nothing.
  - [x] Every new `.gd` has its `.gd.uid` staged.

### Review Findings

Code review 2026-11-12 (Blind Hunter, Edge Case Hunter, Acceptance Auditor; 10 findings dismissed as noise or matching the spec).

- [x] [Review][Defer] A `down` entry puts the player over the exit hole — `entry_position(&"down")` uses `(col, h-2)` with "feet on the tile below", but that bottom-row tile is always open, so a player arriving there falls straight back out [game/scripts/world/room.gd:50] — deferred (sonlm): 1.7 wires room swaps and owns the arrival rules
- [x] [Review][Decision] The in-wall rule checks for a `#` neighbour, while D5 said "solid" — resolved (sonlm): D5 amended to "wall"; code and `docs/rooms.md` stay
- [x] [Review][Patch] Validator doesn't check the entry cell just inside an exit (row 1 / row h-2 at the exit column); a wall there validates clean and `entry_position()` places the player inside it [game/scripts/world/room_loader.gd:173]
- [x] [Review][Patch] An exit opening can run through a corner cell (`##.....` with `up@x2`), opening the side edge; the opening must stop before column w-1 [game/scripts/world/room_loader.gd:177]
- [x] [Review][Patch] With three or more `P`s only the second is reported; report every extra one (D5 "every error") [game/scripts/world/room_loader.gd:154]
- [x] [Review][Patch] Unbounded `\d+` in the exit/obj regexes: `obj=a@4294967297,1` wraps to (1,1) and validates; 20 digits print an engine `ERROR:` from `to_int()`. Bound the digit count [game/scripts/world/room_loader.gd:15]
- [x] [Review][Patch] A blank line right after `---` reports "grid is smaller than 3 x 3" on a full-size grid and hides every other grid error; report the empty row instead [game/scripts/world/room_loader.gd:136]
- [x] [Review][Patch] `_scan()` is silent when `res://rooms` can't be opened, and the empty index is cached, so every `load_room()` only says "no room"; push_error the root cause [game/scripts/world/room_loader.gd:305]
- [x] [Review][Patch] Stale "draft, awaiting sonlm's play approval" comments after the D1 approval [game/rooms/l1/m1_shaft.txt header; game/tests/test_room_loader.gd:148]
- [x] [Review][Patch] `RoomHarness.build()` always places the player at `&"spawn"`, but a room without `P` validates clean, so the harness asserts on most future rooms; take an `entry` argument (default `&"spawn"`) [game/tests/room_harness.gd:29]
- [x] [Review][Defer] Exit targets are never checked to exist (`exits=down:m1_shatf@x1` validates clean); a cross-file check, like id uniqueness [game/scripts/world/room_loader.gd:111] — deferred, cross-file check belongs to the smoke_rooms sweep

## Dev Notes

### What this story is (and isn't)

It turns the level from a `const` array into a text file that a pure validator checks and a loader builds, and it rebuilds the M1 shaft at 22 columns. `RoomLoader`, `Room` and the legend are what `World` (1.6), room swaps (1.7), the room sweep and bot (1.10), DevTools `--room=` (1.11), the perf scene (1.12) and every Layer 1 room (E4) build on.

**Do not, in this story:**
- **Add `World`, `camera_rig.gd`, gutters or `play_rect()` in game code** (1.6). The stub `play_rect()` exists only in the test harness. `lurker.gd` still uses `get_viewport_rect()` until 1.6.
- **Add exit triggers, `enter_room()`, room swaps or the exit backstop** (1.7). This story parses and validates `exits=` and exposes the entries; nothing crosses an exit yet. A player who walks into the bottom hole falls out of the room (D2 says what happens).
- **Give spawned enemies identity (`room_id` + cell) or skip killed cells** (1.7). Room objects (`obj=`) are parsed and validated; no persistent object char exists until 1.24.
- **Add `map=`** (E4), zone palettes or tinting (1.18 / E4), or `Spec` and the fall-gap sweep in `smoke_rooms.gd` (1.9 / 1.10). Task 4's layout check is a local test of this one file (D8).
- **Delete `shaft.gd` / `shaft.tscn`, F1 or F3** (1.7), or move the camera lead or shake out of `player.gd` (1.6).
- **Change a tuning value, an actor script or any `test_chain_state` check.**

### Current state (read before changing)

- **`scripts/shaft.gd` (275 lines)** at `656a7a2`:
  - `LAYOUT` (lines 21–127): 105 rows × 30 columns, 2-tile side walls, ledge rows 6, 41, 85 and the floor at 103–104. Gaps between ledges are 35 and 44 rows.
  - `_ready()` (142–160): boots `Game` behind `current_scene == self`, applies the ambient, connects `Game.settings.changed`, builds the TileSet, calls `_build()`, connects the player's `died` / `banked` / `changed`, and sets the player camera's limits to the layout (0, 0, 480, 1680).
  - `_make_tileset()` (163–178): one atlas tile from `res://art/tile.png`, physics layer 0 on collision layer 1, a full 16×16 square.
  - `_build()` (181–206):
    - `#` sets a wall cell. It adds a ledge rim when the cell above is neither `#` nor `L`.
    - `P` puts the player at `(centre.x, (y + 1) * 16 - 12)`, so its feet are on the tile below.
    - `c` / `h` instance `crawler.tscn` with `hover` set before `add_child`.
    - `L` instances `lurker.tscn`. When the left or right neighbour is a wall, the cell also gets a wall tile, so the wall has no hole.
  - `_add_ledge_rim()` (210–217): an unshaded 16×1 `ColorRect` in `LEDGE_RIM`, with `mouse_filter` set to ignore.
  - `_rim_material` is built per shaft by `_unshaded_material()` (272–275), which project-context says to replace with a cached static when touched.
  - The rest stays: F1 / F3, `_apply_ambient()`, `_on_banked`, `_on_chain_changed`, the HUD label in `_process()`, and the reload in `_on_player_died()`.
- **`scenes/shaft.tscn`:** `Darkness` (CanvasModulate), `Background` (a 480×1680 `ColorRect`, z −10, `Color(0.164706, 0.141176, 0.25098)`), `Walls` (TileMapLayer), `Player` (an instance of `player.tscn`), and `Debug/Label`.
- **`tests/smoke_shaft.gd` (295 lines):** 9 scenarios and 29 `ok` lines. It instances `shaft.tscn` and takes `$Player`. Hard-coded positions:
  - `test_wall_cling`: `Vector2(2 * 16 + 5.5, y)`, the body touching the inner face of the 2-tile left wall.
  - `test_landing_breaks_chain`: `Vector2(5 * 16 + 8, 3 * 16)`, above the spawn ledge.
  - `_measure_jump`: `Vector2(5 * 16 + 8, 6 * 16 - 12)`, standing on the spawn ledge.
  - `test_bot_chains_long_run`: the hoverers with `44 * 16 < y < 84 * 16`.
  - `test_snuff_needs_hold` frees the shaft and instances a fresh one, because the lurker test left the player dead.
- **`tests/screenshot.gd`:** instances `shaft.tscn`, then shoots the spawn and a chain-10 telegraph next to `get_nodes_in_group("predator")[1]`. That index pick breaks the project rule (pick by position); fix it while porting.
- **`tests/smoke_shaft_state.gd`** (14 `ok`): instances `shaft.tscn`, records `_spawn = _player.position` after `add_child`, and reads `Darkness`, `Debug/Label` and `Shaft.AMBIENT_LEVELS` / `AMBIENT_TINT` / `RESPAWN_DELAY`.
- **Actors:**
  - `Crawler.hover` is a plain var that `_ready()` reads, so it must be set before `add_child`.
  - `Crawler._home = position` (local), and the hover phase comes from `_home`, so a hoverer's phase depends on its cell. Moving hoverers changes their phases deterministically, with no randomness.
  - `Lurker._home = global_position`.
  - `Player` camera: smoothing 8, limits set by whoever builds the level.
- **`project.godot`:** viewport 480×270, `run/main_scene` is `scenes/shaft.tscn`, and `Game` is the only autoload.
- **No `game/rooms/` folder exists yet.** `.txt` files are not imported resources; the editor and headless runs read them with `FileAccess`. Export include filters are Story 1.13.

### The approved layout (draft; sonlm plays it before review, D1)

Made from M1's `LAYOUT` by these rules, so every relationship M1's playtest approved is kept:
- **Side walls are 1 tile** (M1: 2), leaving 20 open tiles (M1: 26).
- **Every hoverer and the open-air lurker moves 4 columns left** (the centre of M1's open span, 14.5, to the new one, 10.5). Every row, every pair spacing (7 tiles) and the left/right choices are unchanged.
- **Wall-attached ledges are scaled ×20/26:** the spawn ledge has 6 open tiles (was 8); the row-41 ledges have 5 each with a 10-tile gap (was 7 / 12); the centre platform at row 85 is 8 wide (was 10).
- **`P` stays 2 tiles in from the left wall** (col 3). Walkers stay on their ledges and floor.
- **In-wall lurkers move into the 1-tile walls** (cols 0 and 21).
- **New:** 2-tile wall ledges at row 24 (right), 57 (left) and 72 (right), each on the wall opposite the nearest lurker. With them, the ledge rows are 6, 24, 41, 57, 72, 85 and 103, with gaps of 18, 17, 16, 15, 13 and 18 rows. That is ≤ 19 rows = 304 px < 315 px (1.5 s at 210 px/s, FR57). M1 had gaps of 35 and 44.
- **New (R16):** a 2-tile hole at cols 1–2 of the floor (rows 103–104) for the `down` exit, set behind the floor landing and against the wall, out of the fall line. A 1-tile gap in the ceiling at col 3 is the `up` exit; that is where the loop drops the player back in, above the spawn ledge (1.7 wires it).

**Dry run at story creation** (a scratch copy of `game/` at `656a7a2`, with this grid pasted into `shaft.gd`'s `LAYOUT` and `smoke_shaft`'s three hard-coded positions moved to the 1-tile wall and col 3): all 29 checks pass. The bot chains **8** through the long run (it needs ≥ 5) and survives. The jump peaks at 63.3 px. The scratch copy built in-wall lurkers with the old neighbour rule, which leaves a hole at the room edge; D5's edge rule fixes that.

Grid (105 rows; md5 of the 105 lines, each ending in `\n`: `171cbe01dca4fc15ee183d0825d815b4`). The block is the file's grid exactly; row *n* in these notes is its *n*-th line counting from 0 (the ceiling is row 0):

```
###.##################
#....................#
#....................#
#....................#
#....................#
#..P.................#
#######..............#
#....................#
#....................#
#....................#
#....................#
#........h......h....#
#....................#
#....................#
#....................#
#....................#
#.....h......h.......#
#....................#
#....................#
#....................#
#....................#
#........h......h....#
#....................#
#....................#
#..................###
#....................#
#......h......h......#
#....................#
L....................#
#....................#
#....................#
#.........h......h...#
#....................#
#....................#
#....................#
#....................#
#.......h......h.....#
#....................#
#....................#
#....................#
#..c..............c..#
######..........######
#....................#
#....................#
#....................#
#....................#
#.........h......h...#
#....................#
#....................#
#....................#
#....................#
#.....h......h.......#
#....................#
#....................#
#....................#
#....................L
#...h......h.........#
###..................#
#....................#
#....................#
#....................#
#......h......h......#
#....................#
#....................#
#....................#
#....................#
#....h......h........#
#....................#
#....................#
#....................#
L....................#
#.......h......h.....#
#..................###
#....................#
#....................#
#....................#
#.....h......h.......#
#....................#
#....................#
#....................#
#....................#
#........h......h....#
#....................#
#....................#
#.......c............#
#......########......#
#....................#
#....................#
#....................#
#.h......h...........#
#....................#
#....................#
#...............L....#
#.....h......h.......#
#....................#
#....................#
#....................#
#..........h......h..#
#....................#
#....................#
#......h......h......#
#....................#
#...c..............c.#
#..###################
#..###################
```

### Decisions

These are story-author decisions; sonlm can veto any of them before dev. D1 and D2 are sonlm's (2026-11-12, during story creation).

- **D1 (sonlm), layout gate.** The draft above is the layout. sonlm plays it on the laptop through `shaft.tscn` (D2 makes the playable game build it) and approves it before the story goes to `review` (Task 7). The laptop plays the pushed branch, so the epic's "approves before commit" becomes "committed as a draft, approved before review". A change he asks for is a content edit: the dev agent edits the grid, re-runs the layout checks and `smoke_shaft`, and asks again.
- **D2 (sonlm), the interim game and `smoke_shaft_state`.** `shaft.gd` builds `m1_shaft` through `RoomLoader` now, so the laptop plays the 22-column layout before World arrives.
  - Remove `LAYOUT`, `_make_tileset()`, `_build()`, `_add_ledge_rim()`, `_is_wall()`, `_rim_material`, `_unshaded_material()`, `LEDGE_RIM` and `TileTexture` / `CrawlerScene` / `LurkerScene`, and drop the `Walls` and `Background` nodes from `shaft.tscn` (the room draws its own backdrop, D6).
  - `_ready()` does `RoomLoader.load_room(&"m1_shaft")`, then `assert(room != null, …)` (a content error has already been pushed). It adds the room and moves it before `Player`, so the player draws on top, then sets `_player.position = room.entry_position(&"spawn")`.
  - **Camera:** centre the room in the 480 px view. `limit_left = bounds.position.x - (480 - bounds.size.x) / 2`, `limit_right = limit_left + 480`, and top/bottom from `bounds()`. The 64 px bands on each side show the clear colour, where the gutters will go in 1.6. Read the 480 from the viewport (`get_viewport_rect().size.x`), never a literal.
  - **The bottom hole:** a player who walks in falls out of the room. Exits arrive in 1.7, so until then the shaft calls `_player.die()` when `_player.position.y > bounds().end.y + 32`. That is one guarded line in `_physics_process`, with a comment that 1.7 replaces it with the loop. Without it a fall out of the room never ends.
  - `smoke_shaft_state.gd` keeps loading `shaft.tscn`; it is the shaft's wiring test, and 1.6 retires it with the shaft's role. Change it only where the node tree changed. It must stay 14 checks, green.
  - The epic's line "no test loads `shaft.tscn` any more" predates `smoke_shaft_state` (added by the 1.4 review). AC3 records the exception.
- **D3, the file format** (AR21; `docs/rooms.md` documents it):
  - The header comes first: `key=value` lines up to a line that is exactly `---`. Blank header lines and lines starting with `;` are ignored. Strip `\r` and trailing spaces from every line, then drop trailing blank lines after the grid.
  - Keys:
    - `id=` (required; snake_case; must equal the file's base name).
    - `zone=` (required; one of `dusk`, `umber`, `violet`, the GDD's Layer 1 zones; `m1_shaft` is `violet`, M1's "Edge of the Abyss" palette).
    - `spine=` (`true` / `false`, default `false`; a spine room must be exactly 22 columns wide).
    - `exits=` (optional, comma-separated `<side>:<target_id>@x<col>`; side is `up` or `down`; left/right with `@y<row>` waits for E4).
    - `obj=<id>@<col>,<row>` (repeatable).
  - Any other key is an error, so a typo can't pass silently. `map=` is added with E4.
  - **Grid:** every line after `---`, at least 3 rows of at least 3 columns.
  - **Exits:** `@x<col>` names the leftmost column of an opening in the top row (`up`) or the bottom row (`down`). The opening is that cell plus the open cells to its right in that edge row. At most one exit per side, so a side name is also its entry name. Crossing a `down` exit arrives at the target room's `up` exit, and the reverse (1.7). For `m1_shaft`, both exits target `m1_shaft`, which is the R16 loop.
- **D4, the legend** (`world/room_legend.gd`, `class_name RoomLegend`, the only place chars are defined):
  - `const WALL := "#"`, `const EMPTY := "."`, `const SPAWN := "P"`.
  - `const SPAWNS := {"c": {scene = preload(crawler.tscn), args = {hover = false}}, "h": {…hover = true}, "L": {scene = preload(lurker.tscn), args = {}}}`.
  - `static func is_known(ch) -> bool`.
  - "Solid" means `#`, plus an `L` that the in-wall rule turns solid (D5).
  - A persistent kind (`persistent = true`) arrives with its first char in 1.24 (`A` anchor). Keep the field name ready, but add no entry.
- **D5, the validator** (pure static `RoomLoader.validate(path, parsed) -> Array[String]`, no nodes and no `push_error`):
  - Every message is `"<path>:<row>:<col> <what>"`. `row` is the 1-based **file line** and `col` the 1-based char, so an editor jumps straight to it. Header errors use column 1.
  - Errors:
    - no `---` line
    - a missing `id` or `zone`
    - `id` ≠ file base name
    - an unknown key
    - a repeated non-repeatable key (`id`, `zone`, `spine`, `exits`)
    - a bad `zone` or `spine` value
    - a malformed exit or `obj`
    - two exits on one side
    - an exit column outside the grid, or on a solid cell
    - a duplicate `obj` id **within the file** (cross-file uniqueness is the 1.10 sweep)
    - an `obj` cell outside the grid
    - unequal rows (reported against row 1's width)
    - an unknown char
    - more than one `P`
    - a `P` with no solid cell below it
    - a spine room not 22 wide
  - **The edge rule:** every cell in the top row, the bottom row and the left and right columns must be solid, or part of a declared exit opening. Otherwise the player could leave the room through a hole. An `L` in an edge column counts as solid: **the in-wall rule** is that an `L` whose left or right neighbour is a wall (`#`) *or the room edge* gets a wall tile (amended at code review 2026-11-12, sonlm: "wall", not "solid"; an `L` beside another `L` doesn't chain) (M1 checked only the neighbours; with 1-tile walls a lurker sits in the edge column).
  - It reports every error, not just the first. Test fixtures only need to check that the expected message is in the list.
- **D6, the build** (`RoomLoader._build(parsed) -> Room`, after a clean validation):
  - A `Room` node named after the id, holding:
    - `Backdrop`: a `ColorRect` the size of `bounds()`, z −10, M1's `Color(0.164706, 0.141176, 0.25098)` until the palette tokens (1.18), mouse ignored.
    - `Walls`: a `TileMapLayer` with the **cached static** TileSet. It is built once, exactly as `shaft.gd` built it, and stays one tile with a full-square collision on world layer 1.
    - The rims.
    - The spawned entities.
  - **Rims:** an unshaded 16×1 `ColorRect` in `LEDGE_RIM` (`Color(0.66, 0.71, 0.76, 0.45)`, moved from `shaft.gd` with its comment), on every solid cell whose upper neighbour is in the grid and is neither solid nor `L`. The material is **one cached static `CanvasItemMaterial`** (fixing the M1 per-instance build).
  - **Entities** go through `room.spawn(scene, cell_centre, args)`, in grid order (row, then column), so the order is deterministic. The spawn cell is kept for `entry_position(&"spawn")`; nothing else is spawned for `P`.
  - `room.id`, `zone`, `spine`, `exits` (Array of `{side, target, col}`) and `objects` (`{id: Vector2i}`) are set before `return`.
  - `load_room_from_path(path)`:
    - On a missing file, return the error `"<path>:0:0 file not found"` through the same `push_error` path. Check `FileAccess.file_exists()` first, because `get_file_as_string()` on a missing file prints an engine error.
    - Otherwise read the file, parse, validate, `push_error` each error and return null, or build.
  - `load_room(id)` resolves `id` → path from a static index made once by walking `res://rooms/` recursively for `*.txt` files. An id found twice is `push_error`ed, naming both paths. An unknown id is `push_error`ed and returns null.
- **D7, `Room` API** (`world/room.gd`, `class_name Room`, `extends Node2D`):
  - `const TILE := 16`.
  - `spawn(scene: PackedScene, pos: Vector2, args := {}) -> Node2D`: sets every arg with `set()` before `add_child` and returns the node. The room owns it (AR23).
  - `bounds() -> Rect2`: room-local `(0, 0, cols × 16, rows × 16)`. `m1_shaft` is `(0, 0, 352, 1680)`.
  - `entry_position(entry: StringName) -> Vector2`, room-local:
    - `&"spawn"` → the `P` cell, feet on the tile below (`(col * 16 + 8, (row + 1) * 16 - 12)`, M1's formula).
    - `&"up"` / `&"down"` → the cell one inside the exit opening's first column (row 1 / row rows−2), with the same feet formula.
    - `has_entry(entry) -> bool`.
    - `entry_position()` asserts on an unknown entry (a programmer error: entries come from validated content). Anchor and station ids join the entries in 1.24 (Story 1.4 D9).
  - `is_solid(cell: Vector2i) -> bool` and `cell_centre(cell) -> Vector2`, for tests and the 1.10 sweep.
- **D8, `tests/test_room_loader.gd` + `tests/rooms/`:**
  - **Fixtures**, each a full room file with one fault, whose `id=` matches its file name so that only the intended error fires:
    - `bad_unequal_rows.txt`
    - `bad_unknown_char.txt`
    - `bad_duplicate_id.txt` (two `obj=` with the same id)
    - `bad_edge_hole.txt`
    - `ok_min.txt` (a minimal valid room with a `P`, one `c`, one `h`, one edge `L`, an `up` and a `down` exit)
  - **Cases:**
    - Each bad fixture's validator list contains its `path:row:col` message, at the exact row and column.
    - `ok_min` validates clean and builds. Check the spawn count per legend char, `hover` true/false on the crawlers, the edge lurker's cell set as a wall, the rims under open cells, `bounds()`, `entry_position(&"spawn" / &"up" / &"down")` and `has_entry(&"nope") == false`.
    - Inline-text cases for the other D5 errors (missing `---`, unknown key, repeated key, bad zone, `id` ≠ file name, two `P`s, `P` in mid-air, spine width, exit on a solid cell, two `up` exits).
    - `spawn()` sets args before `_ready()`: a tiny script whose `_ready` records a var.
    - **`m1_shaft`:**
      - It validates clean (the real file).
      - It builds 36 hoverers, 5 walkers and 4 lurkers.
      - Its `bounds()` is 352 × 1680.
      - Its ledge rows (solid cells, outside the outer walls, with an open cell above) are exactly `[6, 24, 41, 57, 72, 85, 103]`, and no gap between consecutive ledge rows is over 19 rows. Cite FR57 here; 1.10's `Spec.LEDGE_FALL_MAX` takes this check over.
      - Its exits are up@3 and down@1 targeting `m1_shaft`.
    - `load_room(&"m1_shaft")` resolves through the index.
  - Free every node a test builds (exit-time leaks print an engine `ERROR:`). Never call `load_room_from_path()` on a bad fixture, because its `push_error` fails the runner.
- **D9, the test harness and the ports** (`tests/room_harness.gd`, a helper with `extends RefCounted` or a static script, preloaded by tests):
  - `build(parent: Node, room_id: StringName) -> Dictionary`, returning `{room, player, world}`:
    - It loads the room with `RoomLoader.load_room()` and adds it.
    - It instances `player.tscn` as a **sibling** of the room under `parent` (in game, `World` holds the player), at `entry_position(&"spawn")`.
    - It sets the player camera's limits centred as in D2.
    - It adds a stub `Node2D` in group `world` whose `play_rect()` returns the 360 × 270 rect centred on the camera's screen centre (`get_screen_center_position()`), which is the play area inside the 60 px gutters. Nothing in game code calls it until 1.6. The test checks it exists and is 360 wide.
  - **`smoke_shaft.gd` retargets:**
    - Wall cling at `Vector2(Room.TILE + 5.5, y)`, the body touching the 1-tile left wall's face. Assert first that the cell `(0, row)` is solid and `(1, row)` is open.
    - Landing above `entry_position(&"spawn") + Vector2(0, -40)`.
    - The jump from `entry_position(&"spawn")`.
    - The bot's long run is the hoverers between the row-41 ledge and the row-85 platform. Keep `44 * 16 < y < 84 * 16`; the rows didn't change, so name the two rows in one commented const.
    - The fresh-room rebuild in `test_snuff_needs_hold` goes through the harness.
    - Lurker picks stay sorted by position, never `[0]`. Sort the predators by `y`; the M1 test's `[0]` was the first-added lurker, which is the top one (row 28) in both layouts.
  - **`screenshot.gd`:**
    - It uses the harness, plus a `CanvasModulate` at the default brightness. Copy `shaft.gd`'s level-1 formula with a comment that `World` owns the ambient from 1.6/1.7, and **don't preload `shaft.gd`**.
    - The telegraph shot picks the second-highest lurker by `y`.
- **D10, `docs/rooms.md`:**
  - The format (D3), the legend table (D4), the validator's errors (D5), the in-wall and edge rules, and the entries (D7).
  - How to add a char: legend first, then this doc, then a fixture case.
  - How to run the checks.
  - The rule "ids are global and never renamed once testers have saves" (project-context).

### Verified on the server (Godot 4.7.2.stable, 2026-11-12)

- **The full suite on `656a7a2`** is ALL GREEN, with the counts in Task 1.
- **The layout dry run** (scratch copy, its own `config/name`, so its `user://` is separate): every `smoke_shaft` check passes on the 22-column grid. The bot reaches best chain 8 and ends at row 80, alive. Lurker tests: telegraph ≥ 0.75 s, hunt, Snuff loses track, base light never noticed, no off-screen notice, point-blank Snuff saves.
- **The camera with limits narrower than the view** (the dry run left `limit_right = 352`): the tests still passed, but Godot then shows the room against one side. D2's centring sets the limits exactly 480 wide.
- **From Story 1.4's probes, still true:**
  - `FileAccess.get_file_as_string()` on a missing file prints an error (check `file_exists()` first).
  - A scratch copy of `game/` with the same `config/name` shares the real `user://`.
  - A lambda that captures a state object and is connected to its signal leaks and prints an `ERROR:` after the runner exits.

### Project Structure Notes

- **New:**
  - `scripts/world/room.gd`, `room_loader.gd` and `room_legend.gd`, plus their `.gd.uid` files. These are the architecture's `world/` files (Project Structure; System Location Mapping: "World and rooms").
  - `rooms/l1/m1_shaft.txt` (rooms are `rooms/<layer>/<room_id>.txt`).
  - `tests/test_room_loader.gd`, `tests/room_harness.gd`, `tests/rooms/*.txt` (test-only rooms; never exported, 1.13).
  - `docs/rooms.md`.
- **Changed:**
  - `scripts/shaft.gd`, `scenes/shaft.tscn`
  - `tests/smoke_shaft.gd`, `tests/screenshot.gd`, `tests/smoke_shaft_state.gd` (only as needed)
  - `run_tests.sh`
  - the docs in Task 8
- **Dependencies point one way:**
  - `world/` uses `actors/` scenes (the legend preloads them) and `core/` (`Log` if used).
  - `world/` never references `ui/` or `dev/`.
  - `rules/` is untouched.
  - The validator is pure, but it lives in `world/room_loader.gd` as the architecture names it.
- **Naming:**
  - `RoomLoader`, `Room` and `RoomLegend` match their files.
  - Ids are snake_case `StringName`s (`&"m1_shaft"`, `&"spawn"`, `&"up"`).
  - Never name a method `f` (`test_tuning`'s literal scan reads `f(&"…")` calls).
- No addon, no `.tres` (the TileSet is built in code) and no new autoload.

### Project Context Rules (that apply here)

- **Levels are text:**
  - `game/rooms/<layer>/<room_id>.txt` (header + `---` + grid).
  - Spine rooms are 22 columns **including** walls.
  - The legend lives only in `world/room_legend.gd` and `docs/rooms.md`.
  - Persistent ids are global and never renamed once testers have saves.
- **Runtime spawns go through `room.spawn(scene, pos, args)`** (args set before `add_child`). The room owns and frees them.
- **Content errors:** a pure validator returns a list, the loader `push_error`s each one and refuses to build, and tests inspect the list. Programmer errors are `assert`s.
- **Performance:**
  - Cache materials and shared resources as statics: the rim material and the TileSet.
  - No threads, and no threaded loading.
  - Rims are unshaded, so they don't count against the light budget.
- **Things that must read in the dark** use `LIGHT_MODE_UNSHADED` (the rims).
- **No randomness** in level behaviour: hover phase comes from position.
- **Physics layers:** walls on layer 1 (value 1).
- **Tests:**
  - Add `test_room_loader` to the `for t in …` list (1.9's glob comes later).
  - Keep the `ok` / `FAIL` + `PASS` / `FAILED` format.
  - Pick targets by position, never by group index.
  - Never loosen a threshold to pass.
  - A test that changes `Game` state ends with `Game.reset_for_tests()`.
- **Comments explain why and cite the design:** "FR57", "R16", "AR22", "D5", "M1 finding 7 (ledge rims)".
- **Feel:** "tests green; needs a feel check on the laptop (22-column shaft, three new wall ledges, 64 px dark bands until the gutters in 1.6, falling into the floor hole kills until the loop in 1.7)".
- **Commits:**
  - Commit the `.gd.uid` files with their scripts.
  - Use `feat:` / `refactor:` / `test:` / `docs:` commits, each leaving the suite green.
  - Order the commits so each one is green: first the loader, the room, the legend and the fixtures with `test_room_loader` (`ok_min` only, no `m1_shaft` cases yet); then `m1_shaft.txt` with the shaft and test port and the `m1_shaft` cases, marked as the layout draft (Task 3); then the docs. A layout change sonlm asks for is a follow-up commit.

### Previous story intelligence (1.4 and its review)

- `Game` is booted only by the entry scene (`current_scene == self`). Harness-added scenes never boot, and tests never touch the real `user://settings.json`. Nothing in this story writes a file.
- **The review's lessons:**
  - Each check must be able to fail for what its message says (mutant thinking). For example, the ledge-row check must fail if one wall ledge is removed.
  - Headers must not overclaim.
  - Facts in docs must be updated when they change (1.4's Task 5 list was long because earlier stories left stale lines).
- **Test hygiene:**
  - Free every node you build.
  - `ok` lines and `[category]` lines never count as a verdict.
  - Warnings are allowed, and errors fail the test.
  - The runner frees the test and watches two more frames.
- **The purity regex in `test_state` / `test_tuning` only scans `rules/`;** `world/` is free to use nodes.
- `reset_for_tests()` leaves `_booted` alone. Only `test_state` boots, on a temp folder.

### Git intelligence

Recent commits on `feat/m2-e1`:
- `15d6a2e` / `31cb44c`: the 1.4 feats
- `48397af`: the 1.4 shaft refactor
- `44a6a89`: the 1.4 docs
- `4079fae`: the 1.4 review fixes
- `656a7a2`: the review record, which is this story's baseline

The pattern: one `feat:` / `refactor:` / `docs:` commit per task, each green, with the `.gd.uid` files committed beside new scripts.

### Cross-story context (Epic 1)

- **1.6:**
  - `World` becomes the main scene, holds `RoomHolder` and the player, and calls `RoomLoader.load_room(&"m1_shaft")`.
  - `camera_rig.gd` takes the limits from `room.bounds()` and frames the play area between the gutters (it replaces D2's centring).
  - `World.play_rect()` replaces `get_viewport_rect()` in `lurker.gd`.
  - The respawn point resolves through `entry_position()`.
  - `shaft.gd` stops being loaded, and `smoke_shaft_state`'s wiring checks move onto `World`.
- **1.7:**
  - Exit triggers are built from `room.exits`, and `enter_room(&"m1_shaft", &"up")` is the R16 loop. It removes D2's out-of-bounds death.
  - Enemies get `room_id` + cell from the loader (`mark_killed`), and the build skips killed cells.
  - Test rooms in `tests/rooms/` for swaps: `load_room()` will need to find them. Story 1.7 decides how (an index root a test can add). Keep the index code simple so it can take one.
  - `shaft.gd` and `shaft.tscn` are deleted.
- **1.9:** `spec.gd`. The lint will scan `world/` too: no `print(`, no `.free()`, no `randf`.
- **1.10:**
  - `smoke_rooms.gd` loads every `rooms/**/*.txt` file standalone (through this story's API), checks ids are unique across files, and sweeps the fall gaps against `Spec.LEDGE_FALL_MAX`.
  - The bot ports onto `RoomLoader`.
- **1.11:** `--room=<id>` goes through `load_room(id)`.
- **1.12:** `rooms/dev/perf_worst.txt`.
- **1.18 / E4:** zone palettes from `zone=`, and `map=`.
- **1.24:**
  - The first persistent char (`A` anchor) with `obj=`.
  - Anchor and station ids become entries.
  - The placeholder station sits at the top of `m1_shaft`, above the spawn ledge.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.5: Rooms as text, the M1 shaft at 22 tiles]
- [Source: _bmad-output/planning-artifacts/epics.md#Requirements: FR3, FR39, FR57, NFR10, AR2, AR3, AR21, AR22, AR23, AR24, AR58; R16 (decision table)]
- [Source: _bmad-output/game-architecture.md#Scene Structure and Rooms, #Level Authoring, #Error Handling, #Safe-Cut Room Flow, #Design Guarantees as Tests, #Entity Patterns, #Project Structure, #Naming Conventions (Game Assets and Data), #Architectural Boundaries]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md#Level Types, #Level Progression, #Movement (M1), #Predators: Lurker (M1)]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/decision-log.md (spine width 22 wall to wall; R16 E1 shaft loop)]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/DESIGN.md#Layout & Spacing (gutters, 360 px play area); zone tokens dusk / umber / violet]
- [Source: _bmad-output/implementation-artifacts/m1-playtest-findings.md (7: ledge rims; finding 6: respawn)]
- [Source: _bmad-output/project-context.md#Code Organization Rules (Levels are text), #Testing Rules, #Performance Rules]
- [Source: _bmad-output/implementation-artifacts/1-4-state-objects-in-the-game-autoload.md#Decisions (D6, D9), #Review Findings, #Cross-story context]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), gds-dev-story, 2026-11-12.

### Debug Log References

- Task 1 baseline (`c7a2f9d`, docs-only on top of `656a7a2`): `== ALL GREEN`. M1's `smoke_shaft.gd` has **28** `check(` calls, not 29 as the story says; a line-by-line diff of the check calls shows all 28 kept word for word, plus 2 new ones (the stub World, the 1-tile wall row), so the port prints 30 `ok`.
- Final run: `test_chain_state` 69, `test_log` 7, `test_clock` 15, `test_tuning` 85, `test_state` 145, `test_room_loader` 48, `test_deferred_owners` 24, `smoke_shaft` 30, `smoke_shaft_state` 14 (unchanged, 0 edits needed); `== ALL GREEN`.
- `smoke_shaft` on the 22-column room: bot best chain **8**, ends at row 80 alive; held jump 63.3 px, tap 26.1 px (same as the story's dry run).
- `screenshot.gd` under `xvfb-run`: both PNGs saved and inspected (room centred, 64 px bands, ceiling gap above the spawn ledge; the row-55 right-wall lurker telegraphing beside the row-57 left ledge). The one `ERROR:` line is the server's missing ALSA device, printed before the runner's logger attaches (exit 0); `--audio-driver Dummy` silences it.
- Two parse errors on the way, both `x == [..] as Array[T]` precedence (`as` binds looser than `==`); parenthesised.
- Task 7: `git push` failed: the repo has **no remote** (`git remote -v` is empty; memory says none was ever set up). The three commits are on local `feat/m2-e1`; sonlm pulls them from this server over SSH.

### Completion Notes List

- `RoomLegend` / `RoomLoader` / `Room` (D3–D7). The legend's `L` carries `in_wall = true`, so the loader never names a char: solid = `#` or an in-wall char beside a `#` or the room edge (`RoomLoader.solid_at()`, shared by the validator and the build). The validator reports every header and char error; the cell checks (P below, obj/exit cells, the edge rule) run only once every row has the same width, since they need a rectangle (documented in rooms.md). TileSet and rim material are cached statics; no exit-time leak.
- Room children: `Backdrop`, `Walls`, `Rims` (a `Node2D` holding the rim `ColorRect`s, so tests can find them), then the spawned entities in grid order.
- `shaft.gd`: `LAYOUT`, the builder, `_rim_material`, `_unshaded_material()`, `LEDGE_RIM`, the preloads and `TILE` removed (`Room.TILE` used for the HUD depth); `Walls`/`Background` dropped from `shaft.tscn`. Camera centred from `get_viewport_rect().size.x`; out-of-room death in `_physics_process` (1.7 replaces it with the loop).
- `tests/room_harness.gd` (D9): `build()` → `{room, player, world}`, `centre_camera()`, `free_all()`; `WorldStub.play_rect()` is 360 × viewport height centred on the camera's screen centre. `smoke_shaft` picks lurkers sorted by `y` (`_lurkers()`), including the IDLE search in `test_lurker_kills`; `screenshot` picks the second-highest lurker.
- `test_room_loader` (48 checks): 4 bad fixtures (exact single message each), 21 inline error cases incl. CRLF, the edge-L rule and "every error reported", ok_min build (counts, hover args, edge lurker solid, rims at exact cells, bounds, entries, `cell_centre`), `spawn()` args before `_ready`, and m1_shaft (validates, index lookup, counts 36/5/4, ledge rows `[6, 24, 41, 57, 72, 85, 103]`, worst gap 18 ≤ 19 (FR57), exits, floor hole).
- **Gate (Task 7) passed:** the layout was committed as a draft (`0e3079b`). sonlm played it on the laptop and approved it: "Yes" (2026-11-12). No grid changes; story set to `review`.

- Story context created by gds-create-story on 2026-11-12. Ultimate context engine analysis completed - comprehensive developer guide created. The 22-column layout was drafted from M1's and dry-run against every `smoke_shaft` check in a scratch copy (bot best chain 8). sonlm chose D1 (approve after playing) and D2 (the shaft builds the room now; `smoke_shaft_state` stays on `shaft.tscn` until 1.6).

### File List

New:
- game/scripts/world/room_legend.gd (+ .gd.uid)
- game/scripts/world/room_loader.gd (+ .gd.uid)
- game/scripts/world/room.gd (+ .gd.uid)
- game/rooms/l1/m1_shaft.txt
- game/tests/test_room_loader.gd (+ .gd.uid)
- game/tests/room_harness.gd (+ .gd.uid)
- game/tests/rooms/ok_min.txt, bad_unequal_rows.txt, bad_unknown_char.txt, bad_duplicate_id.txt, bad_edge_hole.txt
- docs/rooms.md

Modified:
- game/scripts/shaft.gd, game/scenes/shaft.tscn
- game/tests/smoke_shaft.gd, game/tests/screenshot.gd
- game/run_tests.sh
- docs/architecture.md, docs/component-inventory.md, docs/source-tree-analysis.md, docs/index.md, docs/development-guide.md
- game/README.md
- _bmad-output/project-context.md
- _bmad-output/implementation-artifacts/sprint-status.yaml

## Change Log

- 2026-11-12: Rooms as text: legend, pure validator, loader and Room (`30a96c2`); m1_shaft as a 22-column room file, the shaft and its tests build it, layout draft (`0e3079b`); docs (`98a18df`). sonlm approved the layout after playing it (Task 7, 2026-11-12); status review.
- 2026-11-13: Code review: 8 patches applied (validator: exit entry cells, corner columns, every extra `P`, 4-digit coordinates, blank first row; `_scan()` reports an unopenable root; `RoomHarness.build()` takes an entry; stale draft comments). Down-entry arrival deferred to 1.7 (sonlm); D5 amended to "wall" (sonlm); exit-target existence deferred to 1.10 (proposed). `test_room_loader` 57 checks; `== ALL GREEN`. Status done.
