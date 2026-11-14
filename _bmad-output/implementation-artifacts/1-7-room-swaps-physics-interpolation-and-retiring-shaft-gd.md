# Story 1.7: Room swaps, physics interpolation and retiring `shaft.gd`

Status: ready-for-dev

**Type:** dev · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP1 Foundations (1.1–1.15) · **Branch:** `feat/m2-e1`

## Story

As a player,
I want to cross from one room to the next without a hitch or a smear,
so that the shaft, and later the whole layer, feels continuous.

## Acceptance Criteria

1. **`enter_room(room_id, entry)` swaps rooms.** It is exercised with two rooms in `tests/rooms/swap/` (D6). When the player crosses an exit:
   - the swap is deferred;
   - the old room is removed from the tree before `queue_free()`;
   - the player is placed at the arrival entry (D3), the camera limits update, and `reset_physics_interpolation()` runs;
   - `Game.slot.visit(id)` and `World.room_entered(id)` fire;
   - crossing with `chain.count > 0` calls `chain.break_chain()` first, so the held embers become carried exactly as on a landing.

   (FR6, AR24; D1, D2)
2. **Physics interpolation is on.** `physics/common/physics_interpolation = true` in `project.godot`, at 60 ticks, with `snap_2d_transforms_to_pixel` kept. Every teleport calls `reset_physics_interpolation()` on what it moves: the player on a placement or spawn, and the camera on a snap. The camera rig moves on the physics tick and owns its smoothing and clamping, so `play_rect()` stays exact (D8). (AR6)
3. **The R16 loop.** Crossing `m1_shaft`'s bottom exit runs `enter_room(&"m1_shaft", &"up")`, which places the player at the top entry. A live chain is banked first, exactly like a landing. A test crosses with a chain and checks the carried total. (R16; D3)
4. **Death rebuilds the respawn room.** When `World` respawns the player, it goes through the same swap: `enter_room(respawn room, respawn entry)` rebuilds the room, so the killed-enemy rule applies (cells in `DiveState.killed` are skipped). The persistent-object and Ember Cache rules have no content yet (1.22 / 1.24); D4 leaves the hook. An enemy the player kills calls `Game.dive.mark_killed(room_id, cell)` (D5). A test kills a crawler, dies, and finds the crawler still gone. Separately, a test kills a crawler, loops through the bottom exit, and finds it still gone. (AR24, AR25)
5. **`shaft.gd` is retired.** `scripts/shaft.gd` (+ `.uid`) and `scenes/shaft.tscn` are deleted, along with the M1 patterns they still hold (AR3: statics, scene reload, viewport-based notice). The F1/F2/F3 hotkeys are gone: no `KEY_F` under `game/scripts/`. The brightness level applies from `Settings`; World already does this since 1.6, and DevTools changes it from 1.11 until Options lands in 1.36. (AR2; D10)
6. **Arriving from below is safe.** A `down` entry stands the player on the floor beside the opening, never over it. The validator rejects a down exit that has no such floor. This closes the deferred item from the 1.5 review. (D3)
7. **Done means green.** `cd game && ./run_tests.sh` ends in `== ALL GREEN`, with `smoke_room_swap` in the `for t in …` list. Report "tests green; needs a feel check on the laptop" (D13), never "feels the same".

## Tasks / Subtasks

Run everything from `game/` and wrap every Godot run in `timeout`.

- [ ] **Task 1: Baseline** (AC: 7)
  - [ ] Run `timeout 600 ./run_tests.sh` on the story-file commit. Expected (re-run at story creation, 2026-11-14, on `29d8cde`):
    - `test_chain_state`: `ALL PASS (69 checks)`.
    - These print `PASS` with the given `ok` counts: `test_log` 7, `test_clock` 15, `test_tuning` 85, `test_state` 145, `test_room_loader` 57, `test_deferred_owners` 19.
    - `smoke_shaft` 30 `ok` and `smoke_world` 49 `ok`, both `SMOKE PASS`.
    - `== ALL GREEN`.
- [ ] **Task 2: Prototype the camera under interpolation first** (AC: 2) — **gate**
  - [ ] Turn on `physics/common/physics_interpolation` and build the D8 rig. Prove three things in `smoke_world` and `smoke_shaft` before anything else:
    - `play_rect()` spans x −4 … 356 straight after the spawn;
    - it is on the player in the same frame as a `snap()`;
    - a shake never moves it.
  - [ ] The engine `WARNING: Camera2D overridden to physics process mode` must not appear in any test output.
  - [ ] If the rig can't pass these with interpolation on, **HALT and ask sonlm.** Never turn interpolation off on your own: keep-or-drop is 1.15's recorded decision (AR6).
- [ ] **Task 3: Room identity and arrival in the loader** (AC: 4, 6)
  - [ ] `room_legend.gd`: `killable = true` on `c` and `h` (D5).
  - [ ] `room_loader.gd`:
    - `load_room(id, dive: DiveState = null)` skips killed cells;
    - killable spawns get `room_id` + `cell`;
    - every exit gets its `entry_cell` from one shared static, which the validator also uses;
    - new validator error for a down exit with no floor beside it;
    - `add_root(dir)` (D3, D5, D6).
  - [ ] `room.gd`: `entry_position()` reads `entry_cell`; add `exit(side)` (D2, D3).
  - [ ] `crawler.gd`: `room_id` / `cell` vars; `take_hit()` marks the kill (D5).
- [ ] **Task 4: Visits** (AC: 1)
  - [ ] `slot_state.gd`: `visit()`, `has_visited()`, `visits_changed`, plus `visited` in `to_dict` / `from_dict` / `reset` (D7).
- [ ] **Task 5: World swaps rooms** (AC: 1, 3, 4)
  - [ ] `world.gd`:
    - `enter_room()` and the one `_swap_room()` path for boot, exits and respawns;
    - the polled exits replace the out-of-room death;
    - `start_room`;
    - `room_entered` (D1, D2, D4).
- [ ] **Task 6: Physics interpolation and the rig** (AC: 2)
  - [ ] `project.godot`: `[physics]` `common/physics_interpolation=true` (the section doesn't exist yet).
  - [ ] `camera_rig.gd` as in D8; `world.tscn` Camera without engine smoothing; `room_harness.gd` to match.
- [ ] **Task 7: Retire the shaft** (AC: 5)
  - [ ] `git rm scripts/shaft.gd scripts/shaft.gd.uid scenes/shaft.tscn` (D10).
  - [ ] Fix the comments that name them, e.g. `crawler.gd`'s "shaft.gd now".
- [ ] **Task 8: Tests** (AC: 1–7)
  - [ ] `tests/rooms/swap/t_swap_a.txt` and `t_swap_b.txt` (D6, exactly as given).
  - [ ] New `tests/smoke_room_swap.gd` (D11).
  - [ ] `smoke_world.gd`, `test_room_loader.gd`, `test_state.gd` as in D11.
  - [ ] `smoke_shaft` keeps its 30 checks word for word.
  - [ ] `run_tests.sh`: add `smoke_room_swap` to the `for t in …` list.
  - [ ] Red-check every new test: break the code it guards and see it fail.
  - [ ] Re-shoot `screenshot.gd` under `xvfb-run` and look at both PNGs.
- [ ] **Task 9: Ledger and docs** (AC: 6)
  - [ ] `deferred-work.md`:
    - close the 1.5 "down entry over the hole" item;
    - widen the 1.10 exit-target item (D12).
  - [ ] Docs, facts only (D12).
- [ ] **Task 10: Verify** (AC: 7, 5)
  - [ ] `timeout 600 ./run_tests.sh` → `== ALL GREEN`.
  - [ ] Each grep below finds nothing:
    - `grep -rn "KEY_F" scripts/`
    - `grep -rn "reload_current_scene" scripts/`
    - `grep -rln "shaft.gd\|shaft.tscn" scripts/ scenes/ tests/ project.godot` (the false positive is gone too: `smoke_shaft.gd`'s own name contains `shaft.gd`, so check its lines, not just its name)
    - `grep -rn "get_screen_center_position\|position_smoothing" scripts/`
  - [ ] Every new `.gd` has its `.gd.uid` staged; run `godot --headless --path . --import` after adding scripts.
  - [ ] Report "tests green; needs a feel check on the laptop" with D13's list.

## Dev Notes

### What this story is (and isn't)

It makes rooms real places. You leave one through an exit and arrive in the next, with no reload, the chain banked at the cut and the camera cut clean. A death rebuilds the room you respawn in. It turns on 2D physics interpolation, and the camera has to change for it (D8, the risky part, so prototype it first). Finally, it deletes the M1 shaft scene.

**Out of scope:**
- **`scripted_cut()`** (E6, the Fall).
- **Persistent objects, the Ember Cache and anchors/stations** (1.22, 1.24). The hooks are D4's comments only.
- **DevTools / `--room=`** (1.11). `start_room` is the var it will set.
- **The exit-target check across files** (1.10, D12).
- **The keep-or-drop decision on interpolation** (1.15).
- **Hazard respawn** (1.19).
- **The death card** (1.29: `RESPAWN_DELAY` stays).
- **Any new legend char, or any change to `m1_shaft.txt`** (its bottom floor already has the landing beside the hole).

### Current state (read before changing)

- **`world.gd`** (1.6, reviewed):
  - **`_ready`:** boots `Game` if it is the current scene, applies the ambient, `RoomLoader.load_room(START_ROOM)` into `RoomHolder`, `apply_limits`, then `_spawn_player()`.
  - **`_physics_process`:** the out-of-room death, `position.y > bounds().end.y + 32` → `die()`. This story replaces it with the exit poll (D2).
  - **`_spawn_player()`:**
    - frees the old player with `remove_child` + `queue_free`;
    - resolves `Game.dive.respawn_room` / `respawn_entry`, else the current room and `&"spawn"`;
    - **asserts the same room** ("cross-room respawn goes through enter_room() from Story 1.7"), which D4 removes;
    - places the new player with a `# 1.7: reset_physics_interpolation() here` marker;
    - binds `died`, `chain.banked` → `Game.dive.add_carried`, `chain.changed` → `Game.slot.record_chain`, and `pogo_hit` → `_camera.kick.bind(CameraRig.POGO_SHAKE)`;
    - calls `follow` + `snap`, then emits `player_spawned`.
  - **`_on_player_died`:** `record_death()`, then a `SceneTreeTimer(RESPAWN_DELAY, process_always=false, physics=false, ignore_time_scale=true)` → `_respawn()` (a method, never an `await`).
  - **`_respawn()`:** `Game.clock.clear()` + `_spawn_player()`.
  - **Must keep:**
    - every 1.6 behaviour and its tests (`smoke_world`), except the "room was not rebuilt" check, which flips (D11);
    - the brightness ambient;
    - the `Game.boot()` guard;
    - `play_rect()` / `current_room()`.
- **`camera_rig.gd`** (1.6 + review):
  - moves in `_process` on real time;
  - Camera2D's own `position_smoothing` (speed 8, set in `world.tscn` and the harness) does the smoothing;
  - `play_rect()` = `get_screen_center_position() - offset`;
  - `snap()` = `reset_smoothing()` + `force_update_scroll()`.

  **All three fail under interpolation (D8 has the probe results).** Keep the API (`follow`, `snap`, `kick`, `apply_limits`, `play_rect`, `target`) and the consts.
- **`room.gd`:**
  - `exits: Array[Dictionary]` holds `{side, target, col}`;
  - `entry_position(entry)` uses `(col, 1)` for `up` and `(col, h-2)` for `down`, with "feet on the tile below": the down value is the deferred bug;
  - `_exit(side)` is private;
  - `spawn(scene, pos, args)` asserts each arg is a property of the node.
- **`room_loader.gd`:**
  - `load_room(id)` reads an index of `res://rooms` (static, built once by `_scan`; a duplicate id is a `push_error`);
  - `_build()` spawns `RoomLegend.SPAWNS` with their static `args`;
  - `validate()` exit rules:
    - inner column;
    - the opening cell is not solid;
    - the "entry cell" `(col, 1 / h-2)` is not solid, which D3 changes for `down`;
    - the opening runs right from `col` while open;
    - the edge rule.
- **`crawler.gd`:** `take_hit()` = `Fx.pop` + `queue_free`. `hover` is a spawn arg. Its comment still says "shaft.gd now".
- **`lurker.gd`:** never dies in E1, so it is not killable.
- **`DiveState`:**
  - `mark_killed(room_id, cell)` / `is_killed()` exist with no caller;
  - `killed_marked` exists with no subscriber;
  - `reset()` / `from_dict()` clear the killed set.
- **`SlotState`:** no visits yet; its header comment lists "map visits (1.7)".
- **`m1_shaft.txt`:**
  - `exits=up:m1_shaft@x3, down:m1_shaft@x1`;
  - the floor is 2 rows thick (rows 103–104), with the hole at cols 1–2;
  - row 102 is open (`#...c..............c.#`, a walker at col 4);
  - the ceiling gap is at col 3.
- **`room_harness.gd`:** `build()` adds `CameraRig.new()` with `position_smoothing_enabled = true` and speed 8, then calls `apply_limits`, `follow`, `snap`.

### Decisions

- **D1, `enter_room()` and the one swap path** (AR24 order).
  - **`enter_room(room_id, entry)`** is public. It sets `_swap_pending`, then calls `_swap_room.call_deferred(room_id, entry, false)`. While a swap is pending it does nothing more.
  - **`_swap_room(room_id, entry, respawn: bool)`** is the only place a room is built, for boot, exits and respawns. In order:
    1. `RoomLoader.load_room(room_id, Game.dive)`. If that returns null (a content error, already pushed), or the room lacks `entry` (`push_error("…has no entry…")`, free the room): clear `_swap_pending` and keep the current room.
       - On an exit, also `die()` the player, who would otherwise fall out of the room forever.
       - On a respawn with no current room, it's a programmer error: `assert`.
       - On a respawn with a current room, spawn in the current room at its `spawn`.
    2. If there is a current room: `_room_holder.remove_child(_room)` then `_room.queue_free()`. Add the new room and set `_room`.
    3. **Respawn or boot:** `_spawn_player(entry)`, which frees any old player, instantiates, binds, places, calls `reset_physics_interpolation()` and `follow`.
       **Exit:** place the living player with `position = room.entry_position(entry)`, apply D3's velocity rule, then `_player.reset_physics_interpolation()`. If `_player.is_dead`, don't place them: the pending respawn rebuilds the respawn room.
    4. `_camera.apply_limits(room.bounds())`, then `_camera.snap()`.
    5. `player_spawned.emit(_player)`, only when a new player was spawned.
    6. `Game.slot.visit(room_id)`, then `room_entered.emit(room_id)`, then clear `_swap_pending`.
  - **Signals:** `signal room_entered(room_id: StringName)` on World (architecture naming).
  - **The player node survives an exit swap** (it is World's child, not the room's). Its chain, flags and velocity carry over. Only a death makes a new `Player`.
  - **`_ready`:** after the ambient and the settings connection, it calls `_swap_room(<respawn point>, entry, true)` directly. `_ready` is not a physics callback, so it needn't be deferred.
- **D2, exits are polled, not overlapped.** This is a variance from the architecture's "player overlaps"; record it in `docs/architecture.md`. It follows the project rule that contact is polled (crawler), adds no nodes, and replaces the out-of-room death on the same line.
  - **In `World._physics_process`:** skip if `_swap_pending`, `not is_instance_valid(_player)`, or `_player.is_dead`. Then:
    - `side = &"down"` when `_player.position.y > _room.bounds().end.y`, i.e. the body centre is past the floor;
    - `side = &"up"` when `_player.position.y < 0.0`.
  - **Then:** `var exit := _room.exit(side)`.
    - **Empty:** only a body that tunnelled through a closed edge gets here, since the validator's edge rule closes every other hole. `_player.die()` with the comment "a closed edge was crossed (tunnelling): never fall forever".
    - **Otherwise:** `_on_exit_reached(exit.target, &"up" if side == &"down" else &"down")`. Crossing a floor opening arrives at the target's top entry, and crossing a ceiling opening arrives at the target's bottom entry.
  - **`_on_exit_reached(target, entry)`:** if `_player.chain.count > 0`, then `_player.chain.break_chain()` (the ADR-2 backstop: it banks like a landing). Then `enter_room(target, entry)`. Use the architecture's implementation guide, with `_swap_room` as above.
  - **`Room.exit(side) -> Dictionary`** is public and replaces `_exit()`; keep "at most one exit per side".
- **D3, arrival.** The deferred item (sonlm chose 1.7 as owner): "arrive moving up, or on a landing beside the opening". **Decision: a landing beside the opening.**
  - **Why:** it is deterministic and needs no input. Arriving moving up would drop a player who doesn't steer straight back through the hole, so a two-room pair could loop.
  - **`up` entry** (arriving from above, after crossing a floor opening): cell `(col, 1)`, one cell inside the top opening, as today. **The player keeps their velocity**, so the fall carries on across the cut. The camera snaps (D8).
  - **`down` entry** (arriving from below, after crossing a ceiling opening): the player stands on the floor beside the bottom opening, with **velocity zeroed**. Find the cell with one static used by both `_build` and `validate`, e.g. `RoomLoader.down_entry_cell(grid, col) -> Vector2i` (returns `(-1, -1)` when there is none):
    - The opening runs from `col` right while the bottom-row cell is open, ending at `end_col`, its last open column.
    - Try the column just right of it (`end_col + 1`), then the one just left (`col - 1`). Skip column 0 and column `w-1`: they are the room's side edges.
    - For a candidate column, scan up from the bottom row while `solid_at`. The first open cell above that run is the stand cell, provided its row is ≥ 1.
    - The first candidate with a stand cell wins.
    - `m1_shaft`: the hole is cols 1–2, so col 3 → rows 104 and 103 are solid → stand cell (3, 102) → position (56, 1636).
    - `ok_min`: the hole is col 5, col 6 is the edge, so col 4 → (4, 5) → position **(72, 84)** (was (88, 84)).
  - **`spawn`:** unchanged; velocity zero.
  - **Storing the cell:** the loader stores it in the exit dict as `entry_cell`. `up` gets `(col, 1)` and `down` gets the stand cell. `entry_position()` reads it with the same "feet on the tile below" formula: `(cell.x*16 + 8, (cell.y + 1)*16 - 12)`.
  - **The validator:**
    - The current "down exit's entry cell `(col, h-2)` is solid" check is replaced by `"%s exit has no floor beside its opening to arrive on" % e.side`, reported when `down_entry_cell` returns `(-1, -1)`.
    - The `up` check stays.
    - Add a fixture case for the new error in `test_room_loader`, built inline from ok_min's text: `#.....#` as the bottom row makes the opening run from col 1 to the side wall.
  - **The velocity rule in `_swap_room`:** keep the velocity only for `&"up"`; zero it for every other entry.
- **D4, a death goes through the swap.**
  - **`_respawn()`:** `Game.clock.clear()`, then `_swap_pending = true` and `_swap_room.call_deferred(room, entry, true)` for the respawn point below.
  - **The respawn point:** `Game.dive.respawn_room` if set, else `start_room`; the entry is `Game.dive.respawn_entry` if set, else `&"spawn"`.
    - This is what `DiveState`'s comment already promises ("Empty: none set yet, so the dive's start room spawn").
    - Remove the same-room assert: a cross-room respawn works now.
    - A death in room B respawns at the start room's `P` (tested, D11).
  - **The room is always rebuilt,** even when the respawn room is the current room. That is the rule that skips killed cells. Living enemies go back to their start cells.
  - **Hooks:** two comments where the hooks will go, with no code: "1.24: persistent objects (header ids) skip by SlotState flag here" and "1.22: spawn the Ember Cache here when slot.cache.room == room_id". Put them in `RoomLoader._build`, not World, since AR24 puts that skip in the build.
  - **`start_room`:** `var start_room: StringName = START_ROOM`, set before `add_child`. Tests set it, and 1.11's `--room=` will. 1.21/1.38's resume point replaces its default.
- **D5, enemy identity.**
  - **`RoomLegend.SPAWNS`:** `c` and `h` get `killable = true`; `L` doesn't. Lurkers can't be killed in E1, and M2 gives them HP in E2.
  - **`RoomLoader._build`,** for each spawn cell of kind `kind`:
    - If `kind.get("killable")` and `dive != null and dive.is_killed(room.id, cell)`, skip it.
    - Otherwise spawn with `kind.args` merged with `{room_id = room.id, cell = cell}` for killable kinds. `merged()`: never mutate the shared const dict.
    - The header loop sets `room.id` before the grid loop: keep that order.
  - **`crawler.gd`:** `var room_id: StringName = &""` and `var cell := Vector2i(-1, -1)`, with a comment that the room build sets them before `add_child`, and a crawler spawned any other way has none and is never remembered.
    - `take_hit()` calls `Game.dive.mark_killed(room_id, cell)` when `cell != Vector2i(-1, -1)`, before `queue_free()`.
    - `actors/` → `Game` is allowed (actors depend on core).
  - **`load_room(id: StringName, dive: DiveState = null)`:** `null` (tests, the harness, `smoke_rooms` in 1.10) builds every enemy, so a standalone room stays standalone. World passes `Game.dive`.
  - `load_room_from_path(path, dive = null)` takes the same arg.
- **D6, test rooms.**
  - **`static func add_root(dir_path: String) -> void`:** scans `dir_path` into the same index (after building the default one), so a duplicate id is still reported. Comment: "tests only: release exports exclude tests/*" (1.9's lint can enforce it).
  - **Put the swap rooms in `tests/rooms/swap/`, not `tests/rooms/`.** The validator fixtures there include `bad_duplicate_id.txt`, which would `push_error` and fail the runner.
  - **`t_swap_a.txt`:** P on a ledge, a walker on the floor, and the bottom hole at cols 1–2. Arriving from B's ceiling stands the player at (3, 6) → (56, 100).
    ```
    ; Story 1.7 swap test room A: P, a walker, a floor hole down to B. Not a level.
    id=t_swap_a
    zone=dusk
    exits=down:t_swap_b@x1
    ---
    ##########
    #........#
    #.P......#
    #####....#
    #........#
    #........#
    #......c.#
    #..#######
    ```
  - **`t_swap_b.txt`:** no P, a walker on a closed floor (col 7, away from the arrival column), and a ceiling gap at col 4. Arriving from A's hole puts the player at (4, 1) → (72, 20), falling.
    ```
    ; Story 1.7 swap test room B: a ceiling gap up to A, a walker. Not a level.
    id=t_swap_b
    zone=dusk
    exits=up:t_swap_a@x4
    ---
    ####.#####
    #........#
    #........#
    #......c.#
    ##########
    ```
  - **Validate both** with `RoomLoader.validate()` before writing tests. If a rule rejects them, fix the room, not the rule, and say so in the Debug Log.
- **D7, visits** (AR14; FR60's map reads them in E4).
  - **`SlotState`:**
    - `signal visits_changed`;
    - `var _visited: Dictionary[StringName, bool] = {}`;
    - `visit(id)` is a no-op if the room is already visited, else it adds the room and emits;
    - `has_visited(id) -> bool`.
  - **`to_dict()`:** `"visited"` is the ids as Strings, sorted (the flags pattern). Visit ids are save data: room ids are never renamed once testers have saves.
  - **`from_dict()`:** parses `"visited"` exactly like `"flags"` (a missing or non-Array value or a bad entry → `clean = false`; an empty id is skipped).
  - **`_assign()`:** gains the list and emits `visits_changed` once. Update `reset()` and the header comment, which drops "map visits (1.7)".
  - **No save happens:** saving is 1.21.
- **D8, physics interpolation and the camera rig** (the risky part; Task 2 gates it).

  **Verified on 4.7.2 at story creation** (`--headless`, probes in a scratch copy, nothing committed). With `physics/common/physics_interpolation = true`:
  - **Every test runs green except the camera.** `smoke_world` fails 4 checks:
    - `play_rect()` spans −42.7 … 317.3, not −4 … 356;
    - the same-frame snap check fails;
    - the shake check fails.

    `smoke_shaft` fails 3 lurker checks, because the harness camera's `play_rect()` is wrong too.
  - **The engine prints `WARNING: Camera2D overridden to physics process mode due to use of physics interpolation`** and runs the Camera2D on the physics tick.
  - **The screen centre is only computed on physics ticks.** It reads (0, 0) until the first tick, then converges through the engine smoothing (163.8 → 176.0).
  - **The 1.6 snap no longer cuts.** After moving the camera, `reset_smoothing()` + `force_update_scroll()` leave the old centre, and adding `reset_physics_interpolation()` gives 192.8, then 249.1 on the next tick. It is still sliding.
  - **There is no `Node2D.get_global_transform_interpolated()` in 4.7.2** (3D only). Don't plan around reading interpolated 2D positions.
  - `Node.reset_physics_interpolation()` and `is_physics_interpolated()` exist.

  **Decision: the rig owns its smoothing and its clamp, on the physics tick.** The engine's are turned off.
  - **`world.tscn` Camera:** remove `position_smoothing_enabled` / `position_smoothing_speed` (engine smoothing off).
  - **`CameraRig._init()`:**
    - sets `process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS` before it enters the tree, which covers the harness's `CameraRig.new()` too;
    - verify the WARNING is gone from every test.

    The harness drops its two smoothing lines.
  - **Consts:** add `SMOOTH_SPEED := 8.0` (the old `position_smoothing_speed`; presentation), with a `##` comment.
  - **State:**
    - `_smoothed: Vector2` is the unclamped follow point, as the engine did it;
    - `_centre: Vector2` is the clamped view centre;
    - `_view: Vector2` is the viewport size. Read `get_viewport_rect().size` when the rig enters the tree, and again in `apply_limits()` / `snap()` if it is still zero. The harness calls `apply_limits` + `snap` straight after `add_child`, before any physics tick.
  - **`_physics_process(delta)`** replaces `_process`. The rig is after the Player in World's tree, so it runs after the player has moved this tick. Keep `real = delta / maxf(Engine.time_scale, 0.001)` for the shake decay and the lead, as now.
    1. Return early when there is no target (zero `offset`, as the 1.6 review fix does).
    2. Decay the shake and the lead with `real`, as today.
    3. `want = target.global_position + Vector2(0, _lead)`.
    4. `_smoothed += (want - _smoothed) * minf(SMOOTH_SPEED * delta, 1.0)`. Use the scaled `delta`: engine smoothing used the scaled delta, so a hitstop slows the follow, as in M1.
    5. `_centre = _clamp(_smoothed)`.
    6. `global_position = _centre`.
    7. `offset = shake` (the only `randf`).
  - **`_clamp(p)`:** `x` into `[limit_left + _view.x/2, limit_right - _view.x/2]` and `y` into `[limit_top + _view.y/2, limit_bottom - _view.y/2]`. When a span is smaller than the view, use its centre; a short room is the deferred 2.1 item, so don't solve it beyond not crashing. Keep setting the Camera2D `limit_*` in `apply_limits` (`smoke_world` checks them, and the engine clamp then agrees).
  - **`snap()`:**
    - zero the lead, the shake and `offset`;
    - set `_smoothed` to the target's position;
    - `_centre = _clamp(_smoothed)` and `global_position = _centre`;
    - `reset_physics_interpolation()`.

    No engine calls: drop `reset_smoothing()` and `force_update_scroll()`.
  - **`play_rect()`:** `Rect2(Vector2(_centre.x - PLAY_WIDTH / 2.0, _centre.y - _view.y / 2.0), Vector2(PLAY_WIDTH, _view.y))`. It never reads the engine, so it is deterministic and never includes the shake.
  - **Comments:** update the class comment and the `play_rect` / `snap` comments; they explain the 1.6 behaviour that this replaces.
  - **The shake-check test** awaits physics frames now, not `process_frame` (D11).
  - **Other `_process` movers:** `player.gd` `_process` lerps `_sprite.scale` (a squash) and `Fx` tweens a `Label`'s position. Neither is a gameplay transform.
    - Leave them as they are, and list "pogo squash and popups" in D13's feel check.
    - If either visibly stutters on the laptop, the fix is `physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF` on that node (1.15 or a follow-up), not here.
- **D9, the bank popup on a crossing.** `break_chain()` at the crossing pops "+N banked" into the **old** room, which the swap frees at the end of the frame, so the popup vanishes.
  - **Accepted:** the bank still happens, and the gutter HUD (1.25/1.26) shows the carried total.
  - **Don't move the popup:** runtime spawns belong to the room (AR23).
  - Note it in D13's feel check, and record it in `deferred-work.md` with **Owner: Story 1.25** ("the ember counter shows a bank at a room cut; decide there whether a cut needs its own cue").
- **D10, retiring the shaft.**
  - `git rm scripts/shaft.gd scripts/shaft.gd.uid scenes/shaft.tscn`.
  - Nothing loads them: `run/main_scene` is `world.tscn` since 1.6, and no test does.
  - F1/F3 and `reload_current_scene()` go with `shaft.gd`, and F2 went in 1.4.
  - Brightness: `world.gd` already applies `Settings.brightness` and repaints on `changed` (1.6, tested).
  - Grep `game/` and `docs/` for `shaft.gd` / `shaft.tscn`, and fix each mention by fact. Keep `m1_shaft` (the room) and `smoke_shaft` (the room's test).
- **D11, tests.**
  - **New `tests/smoke_room_swap.gd`** (a `smoke_*` that extends `Node`, runs with `run()`, and prints `SMOKE PASS` / `FAILED`).
    - **Setup:**
      - `RoomLoader.add_root("res://tests/rooms/swap")`;
      - `Game.store.dir` → a temp folder, as `smoke_world` does;
      - instantiate `world.tscn`, set `start_room = &"t_swap_a"`, `add_child`;
      - connect `room_entered` and `player_spawned` to recorders;
      - `await frames(2)`.

      Cases, in order:
    1. **Boot:**
       - the current room is `t_swap_a`;
       - the player is at A's P;
       - `Game.slot.has_visited(&"t_swap_a")`.
    2. **Deferred:**
       - `enter_room(&"t_swap_b", &"up")` leaves `current_room().id == &"t_swap_a"` immediately;
       - after `await get_tree().process_frame`, it is `t_swap_b`;
       - then `enter_room(&"t_swap_a", &"down")` and wait a frame to come back.

       Or test this on a fresh World; choose whichever keeps later cases clean.
    3. **Kill:** take the walker in A by its position, not group index, and `take_hit()` it. Check `Game.dive.is_killed(&"t_swap_a", Vector2i(7, 6))`.
    4. **Down through the hole with a chain:**
       - `add_hit()` ×3 (held 6), note the carried total and the player instance;
       - put the player at (24, 120) with `velocity = Vector2(0, 150)`;
       - wait until `room_entered` fires, capped at 60 frames.

       In the `room_entered` handler, record:
       - the old room's `is_inside_tree()`, which must be false, and its `is_instance_valid()`, which must be true: removed before the free;
       - the chain count (0);
       - the carried total (+6);
       - the player's position (72, 20) and `velocity.y` (> 0, kept);
       - the predator/enemy groups, which hold nothing from A.

       Then, after the swap:
       - the room is `t_swap_b` and the player is the same instance;
       - the camera limits are B's;
       - `has_visited(&"t_swap_b")`;
       - `room_entered` fired once, with `t_swap_b`;
       - a frame later, the old room is freed.
    5. **Up through B's ceiling:** put the player at (72, −2) with `velocity = Vector2(0, -100)`; one physics frame, then the swap. Check:
       - the room is `t_swap_a` and the player is at (56, 100) with velocity zero;
       - after 30 frames it is still in A and `is_on_floor()`: it didn't fall back through the hole;
       - A has no walker: the killed cell was skipped and the room rebuilt.
    6. **Cross-room respawn:**
       - drop back down to B (as in case 4);
       - `die()`, then `await seconds(World.RESPAWN_DELAY + 0.1)`.

       Then check:
       - the room is `t_swap_a`, rebuilt;
       - the player is a new instance, at A's P;
       - `player_spawned` fired;
       - A still has no walker.
    7. **Interpolation:**
       - `ProjectSettings.get_setting("physics/common/physics_interpolation") == true`;
       - `get_tree().physics_interpolation == true`.

       Plus source checks, until 1.9's lint:
       - `world.gd` contains `reset_physics_interpolation()` in both `_spawn_player` and the exit placement;
       - `camera_rig.gd` contains it in `snap()`.

       Teardown: free World, `Game.reset_for_tests()`, remove the temp folder.
  - **`smoke_world.gd`:**
    - **`test_death_and_respawn`:** the check "the crawler killed before the death stays dead: the room was not rebuilt" becomes two checks:
      - the room after the respawn is a **new** `Room` instance;
      - the killed crawler is still gone, by count and by its cell no longer holding a crawler.
    - **New `test_bottom_loop`:**
      - kill a crawler (record its cell);
      - `add_hit()` ×3;
      - put the player in the bottom hole at (24, 1650), falling;
      - wait for `room_entered`.

      Then check:
      - carried +6 and chain 0 (banked first);
      - the player is at `m1_shaft`'s top entry (56, 20), in a new `m1_shaft` instance;
      - the killed crawler is still gone.

      This is AC3 and AC4's loop case.
    - **`test_sources`:**
      - no `KEY_F` and no `reload_current_scene` under `res://scripts`;
      - `FileAccess.file_exists` is false for `res://scripts/shaft.gd` and `res://scenes/shaft.tscn`.
    - **The shake check:** await 2 **physics** frames (D8).
    - **Lurkers come back on a rebuild.** `run()` turns the room's lurkers off once with `_set_room_lurkers_active(false)`, but every respawn and loop now builds a fresh room with active lurkers. Turn them off again after each rebuild, from a `room_entered` handler or straight after each wait. Otherwise a later case can be hunted and killed at random.
    - **Recount enemies after each rebuild.** Counts taken before a death compare against a different `Room` instance now.
    - Keep every other check as it is.
  - **`test_room_loader.gd`:**
    - the down-entry pin becomes (72, 84);
    - the new fixture error (D3);
    - `load_room(&"ok_min", dive)` with `dive.mark_killed(&"ok_min", Vector2i(1, 5))` builds no crawler at that cell, but still builds the hoverer at (4, 2);
    - without a dive, it builds both;
    - a built walker has `room_id == &"ok_min"` and `cell == Vector2i(1, 5)`;
    - a lurker has no `cell` property (not killable);
    - `entry_cell` is present on both exits.
  - **`test_state.gd`:**
    - `visit()` emits once per new room and never for a repeat;
    - `has_visited`;
    - `to_dict()` holds `visited`, sorted;
    - `from_dict()` round-trips it and rejects bad entries;
    - `reset()` clears it and emits `visits_changed` once.
  - **`smoke_shaft.gd`:** no edits beyond what the harness change forces. Its 30 checks pass word for word; they are the D8 proof for the harness camera.
  - **`screenshot.gd`:** unchanged. Re-shoot and check the gutters, the bands at x 60–63 / 416–419 reading (7, 6, 11), and the room centred.
- **D12, ledger and docs.**
  - **`deferred-work.md`:**
    - The 1.5-review item "A `down` entry puts the player over the exit hole": replace its owner line with `→ **Closed (Story 1.7): arrival stands on the floor beside the opening (D3); the validator requires that floor.**`.
    - The 1.5-review item "Exit targets are never checked to exist" (owner 1.10): append to its text "…and that the target has the arrival entry (crossing `down` arrives at the target's `up` entry and vice versa)". Keep the owner.
    - Add D9's item.
    - Every new item gets an owner (project-context).
  - **Docs** (facts only):
    - **`docs/architecture.md`:**
      - the swap flow;
      - the polled exits as a variance;
      - interpolation on, with the rig's own smoothing;
      - the shaft gone.
    - **`docs/rooms.md`:**
      - arrival rules;
      - the new validator error;
      - `add_root` and test rooms;
      - `load_room(id, dive)`;
      - killable kinds.
    - **`docs/component-inventory.md`:** World, CameraRig, Room, RoomLoader, Crawler, SlotState.
    - **`docs/development-guide.md`:** test rooms, and `--import` after pulling.
    - **`docs/source-tree-analysis.md`:** remove the shaft; add `tests/rooms/swap/` and `smoke_room_swap`.
    - **`game/README.md`.**
    - **`_bmad-output/project-context.md`:**
      - **Current State:** one sentence for 1.7. Remove the shaft and the out-of-room-death clauses.
      - **Technology Stack → Display:** "2D physics interpolation on since 1.7 (1.15 decides keep or drop)".
      - **A new Engine-Specific rule:** "With physics interpolation on, move gameplay `Node2D`s only in `_physics_process`, and call `reset_physics_interpolation()` after every teleport. 4.7 has no 2D `get_global_transform_interpolated()`. `CameraRig` smooths and clamps itself on the physics tick, so `play_rect()` never reads the engine camera."
- **D13, the feel check (for the report).** sonlm pulls, runs `--import`, and plays `world.tscn` (F5) on the laptop, at 60 Hz and on a high-refresh display if he has one. Check:
  - **Interpolation:**
    - falling, running and the camera are smooth;
    - nothing feels soft or late;
    - no smear on a respawn or a cut.
  - **The bottom hole:**
    - it loops to the top;
    - the fall continues;
    - the camera cuts instead of sliding;
    - a crawler killed before the loop is still gone.
  - **Death:** a crawler killed before the death is still gone after the respawn, and the others are back at their start spots.
  - **Camera:** the lead and the pogo shake feel as in 1.6.
  - **Pogo squash and popups:** they don't stutter.
  - **Expected:** no "+N banked" popup at the loop when crossing with a chain (D9).

### Project Structure Notes

- **New files:**
  - `game/tests/smoke_room_swap.gd` + `.uid`;
  - `game/tests/rooms/swap/t_swap_a.txt`, `t_swap_b.txt`.
- **Modified:**
  - `world.gd`, `camera_rig.gd`, `room.gd`, `room_loader.gd`, `room_legend.gd`, `crawler.gd`, `slot_state.gd`;
  - `world.tscn`, `project.godot`, `run_tests.sh`;
  - `room_harness.gd`, `smoke_world.gd`, `test_room_loader.gd`, `test_state.gd`;
  - the docs.
- **Deleted:** `scripts/shaft.gd` + `.uid`, `scenes/shaft.tscn`.
- **Untouched:**
  - `m1_shaft.txt`;
  - `player.gd`, except an `entry_*` read if it needs one, which it shouldn't (World places it);
  - `lurker.gd`, `chain_state.gd`, `dive_state.gd`. `mark_killed` / `is_killed` already exist; at most, update the `killed_marked` comment, which still says "the room build skips killed cells from Story 1.7".
- **Dependencies:**
  - `world/` reads `rules/` (`DiveState` type in `load_room`);
  - `actors/crawler.gd` → `Game` (core). Both are allowed.
  - Nothing new references `ui/` or `dev/`.

### Project Context Rules (that apply here)

- **Room swaps:**
  - deferred, through `World`;
  - remove the old room from the tree before `queue_free()`;
  - crossing with a live chain banks it.

  Never `free()` a node.
- **Runtime spawns:** go through `room.spawn(scene, pos, args)`, with args set before `add_child`. Never parent anything to World.
- **Physics:** gameplay movement in `_physics_process`; `_process` is visuals only. With interpolation on, teleports call `reset_physics_interpolation()`.
- **Randomness:** `randf` only for the camera shake (`camera_rig.gd`); no randomness in level behaviour. Hover phase comes from position.
- **Signals:** methods and bound callables only; never a lambda that captures a RefCounted (it leaks and prints `ERROR:` at exit).
- **Errors:** programmer errors → `assert`; content errors → pure validator + `push_error` + refuse to build. The runner fails on any `ERROR:` line, so never test a `push_error` path by triggering it.
- **Test targets:** pick by position or sort order, never `get_nodes_in_group(...)[i]`.
- **Done:** `cd game && ./run_tests.sh` → `== ALL GREEN`. Headless tests can't judge feel.
- **Deferred items:** every one has an owner. The agent that defers an item assigns it, without "(proposed)", and names it in its report.
- **No function keys or raw keycodes.** Debug tools wait for DevTools (1.11).

### Previous story intelligence (1.6 and its review)

- **The review's camera fixes are superseded here:** `play_rect()` minus `offset`, and `force_update_scroll()` in `snap()`. Keep the **tests** they added (same-frame snap, shake-free `play_rect`); they are D8's acceptance.
- **Red checks found real gaps** in 1.6 (World's own Clock clear, the router). Red-check every new check here.
- **A death clears the Clock twice:** `die()` clears it, then `_respawn()` does. Keep both.
- **`xvfb-run` prints one ALSA `ERROR: … ERR_CANT_OPEN`** before the runner starts. It is not ours.
- **Engine timing:**
  - `process_frame` fires before nodes' `_process`, so await two frames before reading what `_process` wrote;
  - a test's first frame includes its load time, which is why the runner waits 2 frames;
  - SceneTreeTimers that expire in the same pass fire in creation order.
- **`test_tuning`'s M1 fixture** pins `POGO_SHAKE` / `LOOK_AHEAD` on `camera_rig.gd` through an optional `home` field. Don't rename those consts.
- **Leaks:** a lambda connected to a RefCounted's signal that captures that object leaks, and prints `ERROR:` after the runner exits 0, so grep the raw output.

### Git intelligence

- **Recent commits:**
  - `29d8cde` feel checks 1.2–1.6 passed;
  - `a29da6b` / `6ee741c` 1.6 review (camera, router, clear colour in `Gutters`);
  - `2674abd` / `96e1ae8` / `29b8f3c` 1.6 (World);
  - `4c5929e` / `e11203c` 1.5 review (validator rules, `RoomHarness.build(parent, id, entry)`).
- **Pattern:** `feat:` code, `docs:` docs, and the story record as its own `docs:` commit.

### Cross-story context (Epic 1)

- **1.8:** `PlayerInput` intents. Untouched here.
- **1.9:**
  - the glob runner, `spec.gd` and `test_lint.gd`, which takes over the source checks (`randf`, `KEY_F`, `reset_physics_interpolation` in teleports, `add_root` only in tests);
  - `smoke_room_swap` must match the glob, and it does.
- **1.10:** `smoke_rooms` + the bot. It checks exit targets and arrival entries across files (D12's widened item) and calls `load_room(id)` without a dive.
- **1.11:** DevTools sets `World.start_room` from `--room=` and changes brightness.
- **1.15:** sonlm's feel check decides whether interpolation stays, and records it.
- **1.19:** Health; hazard respawn in the current room.
- **1.21 / 1.38:** saves; the resume point replaces `START_ROOM`. `SlotState.to_dict()` now holds `visited`.
- **1.22:** the Ember Cache spawn at room build (D4's hook); deposits.
- **1.24:** anchors/stations call `Game.dive.set_respawn()`, and a rest calls `dive.reset()` + `enter_room(current room, station)`, so killed enemies come back. Persistent objects get their skip at build (D4's hook).
- **1.25:** the gutter HUD (D9's item).
- **E6:** `World.scripted_cut()` for the Fall, the only swap without the backstop.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.7; AR2, AR3, AR6, AR14, AR24, AR25; FR6; FR60]
- [Source: _bmad-output/game-architecture.md#Scene Structure and Rooms, #Frame Pacing, #3 Room swaps (data flow + implementation guide), #State Management]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md#Chain-end table (room-exit row)]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md#Deferred from: code review of 1-5 (down entry over the hole; exit targets)]
- [Source: _bmad-output/implementation-artifacts/1-6-the-world-scene-replaces-the-m1-shaft.md#Cross-story context, #Review Findings]
- [Source: _bmad-output/implementation-artifacts/1-5-rooms-as-text-the-m1-shaft-at-22-tiles.md#Cross-story context (1.7: test rooms, enemy identity)]
- [Source: _bmad-output/implementation-artifacts/1-4-state-objects-in-the-game-autoload.md#Cross-story context (1.7: visit, mark_killed, F1/F3)]
- [Source: game/scripts/world/{world,camera_rig,room,room_loader,room_legend}.gd, game/scripts/actors/crawler.gd, game/scripts/rules/{dive_state,slot_state}.gd, game/rooms/l1/m1_shaft.txt, game/tests/{room_harness,smoke_world,smoke_shaft,test_room_loader}.gd]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

- Story context created by gds-create-story on 2026-11-14. Ultimate context engine analysis completed - comprehensive developer guide created. Baseline re-run at `29d8cde`: `== ALL GREEN`. Interpolation probes (D8) were run on 4.7.2 against a temporary `project.godot` change, which was reverted.

### File List
