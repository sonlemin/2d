# Story 1.6: The World scene replaces the M1 shaft

Status: ready-for-dev

**Type:** dev · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP1 Foundations (1.1–1.15) · **Branch:** `feat/m2-e1`

## Story

As a player,
I want death to put me straight back in the shaft without a reload, with the play area framed between the HUD gutters,
so that respawns are instant and the HUD has its own space.

## Acceptance Criteria

1. **The World scene boots the game.** `scenes/world/world.tscn` + `scripts/world/world.gd` (`class_name World`, group `world`) is `run/main_scene`. Its tree is `Darkness` (CanvasModulate), `RoomHolder`, the `Player` (spawned at runtime, D3), `Camera` (`Camera2D` with `scripts/world/camera_rig.gd`, `class_name CameraRig`) and `UI` (`CanvasLayer`, `PROCESS_MODE_ALWAYS`) holding `Gutters` (`ui/gutters.gd`: two flat 60 px strips in a placeholder dark colour, D7) then `ScreenRouter` (`ui/screen_router.gd`: one screen at a time; opening replaces, never stacks). On boot, `m1_shaft` loads into `RoomHolder`. The 360 px play area sits centred between the gutters, the usable gutter width is 58 px, and menus will use the x 60–420 column. Camera limits come from the room bounds. The UI layers keep the depth order world → gutters and in-world UI → full-screen menus. (AR19, AR39, UX-DR18, UX-DR23)
2. **`World.play_rect()` is "on screen".** The lurker checks whether it is on screen through `World.play_rect()`, the play area inside the gutters in world coordinates, never the viewport. `get_viewport_rect()` is gone from `lurker.gd`. A test proves that a lurker inside the viewport but behind a gutter never notices the player, while a control lurker in the play area at the same distance does. (AR20, D5)
3. **Death without a reload.** M1 rules still apply until Story 1.19. When the player dies, `World` waits `RESPAWN_DELAY` and then re-instances `Player` at the `DiveState` respawn point without `reload_current_scene()`. It emits `player_spawned(player)` and clears Clock requests. Enemies killed this dive stay dead (`DiveState.killed`): in this story the room is not rebuilt (D4). The respawn point is the room's spawn until stations and anchors set it (Story 1.24), and M1's per-frame last-ledge checkpoint no longer moves it. A lurker never carries a hunt over to the new player (D6). (AR25)
4. **The camera.** Camera shake lives only in `camera_rig.gd`, the only `randf` use under `game/scripts/`. The rig keeps M1's 70 px downward lead and its smoothing, and follows the player that `World` gives it. `player.gd` and `player.tscn` no longer have a camera. (FR3, AR27, UX-DR123)
5. **The shaft stays, unused.** `shaft.gd` and `shaft.tscn` stay in the project, loaded by neither the game nor any test, until Story 1.7 deletes them. `smoke_shaft_state.gd` is replaced by `tests/smoke_world.gd`, which checks the same session-state wiring on `World` (D9).
6. **Runtime spawns stay in the room.** The player's popups (chain, banked, lost) are parented to the current room, never to `World` (project-context: "Never parent flares/FX to `World`"; D8).
7. **Done means green.** `cd game && ./run_tests.sh` ends in `== ALL GREEN`, with `smoke_world` in the `for t in …` list in place of `smoke_shaft_state`. Report "tests green; needs a feel check on the laptop", never "feels the same".

## Tasks / Subtasks

Run everything from `game/` and wrap every Godot run in `timeout`.

- [ ] **Task 1: Baseline** (AC: 7)
  - [ ] Run `timeout 600 ./run_tests.sh` on `4c5929e`. Expected (re-run at story creation, 2026-11-13): `test_chain_state` `ALL PASS (69 checks)`; `test_log`, `test_clock`, `test_tuning`, `test_state`, `test_room_loader` (57 `ok`) and `test_deferred_owners` `PASS`; `smoke_shaft` `SMOKE PASS` (30 `ok`) and `smoke_shaft_state` `SMOKE PASS` (14 `ok`); `== ALL GREEN`.
- [ ] **Task 2: The camera rig** (AC: 4, 1)
  - [ ] `scripts/world/camera_rig.gd` as in D2.
  - [ ] Take the camera out of `player.gd` and `player.tscn` (D2). The player gains `signal pogo_hit`.
- [ ] **Task 3: World, gutters, router** (AC: 1, 3, 6)
  - [ ] `scripts/world/world.gd` + `scenes/world/world.tscn` (D1, D3, D4).
  - [ ] `scripts/ui/gutters.gd`, `scripts/ui/screen_router.gd` (D7). Build the nodes in the scene or in code, but keep the tree and its order as in D1.
  - [ ] `project.godot`: `run/main_scene="res://scenes/world/world.tscn"`.
  - [ ] Player popups go to the current room (D8).
  - [ ] Run `godot --headless --path . --import` after adding the `class_name`s. Commit the generated `.gd.uid` files and never write one by hand.
- [ ] **Task 4: The lurker reads the play rect** (AC: 2, 3)
  - [ ] `lurker.gd` `_on_screen()` reads `World.play_rect()` (D5).
  - [ ] The lurker drops a dead or freed target at once (D6).
- [ ] **Task 5: Tests** (AC: 2, 3, 4, 5, 6, 7)
  - [ ] `tests/room_harness.gd`: a `CameraRig` instead of the player's camera, and a stub `current_room()` (D9).
  - [ ] `tests/smoke_shaft.gd` and `tests/screenshot.gd` follow the camera move (D9). `smoke_shaft` keeps its 30 checks word for word.
  - [ ] New `tests/smoke_world.gd` (D10). Delete `tests/smoke_shaft_state.gd` and its `.uid` with `git rm`.
  - [ ] `run_tests.sh`: replace `smoke_shaft_state` with `smoke_world` in the `for t in …` list.
  - [ ] Run `screenshot.gd` under `xvfb-run` and look at both PNGs: gutters on both sides, the room centred between them, the darkness.
- [ ] **Task 6: Docs** (AC: 1)
  - [ ] Update the facts that change (D11). Facts only.
- [ ] **Task 7: Verify** (AC: 7, 4, 5)
  - [ ] `timeout 600 ./run_tests.sh` → `== ALL GREEN`.
  - [ ] `grep -rn "randf" scripts/` lists only `scripts/world/camera_rig.gd`.
  - [ ] `grep -rn "get_viewport_rect" scripts/actors/` finds nothing.
  - [ ] `grep -rln "shaft.tscn\|shaft.gd" tests/ project.godot` finds nothing.
  - [ ] `grep -rn "reload_current_scene" scripts/ --include=*.gd | grep -v "^scripts/shaft.gd"` finds nothing.
  - [ ] Every new `.gd` has its `.gd.uid` staged.
  - [ ] Report "tests green; needs a feel check on the laptop" and give sonlm D12's list of what to look at.

## Dev Notes

### What this story is (and isn't)

It moves the game from `shaft.tscn` onto the architecture's `World` scene. World owns the room, the player, the camera, the darkness and the UI layer. Death respawns a fresh `Player` in place, and "on screen" now means the play rect between the gutters.

It does **not**:
- **Swap rooms, wire exits, rebuild the room on death, call `mark_killed`, or turn on physics interpolation** (1.7). In this story, falling out of the room still kills the player (D4).
- **Delete `shaft.gd` / `shaft.tscn`, or touch F1–F3** (1.7). Don't edit `shaft.gd`. Once the camera leaves `player.tscn`, its `_player.get_node("Camera")` would fail if anyone ran it, but nothing does (D11 notes it).
- **Draw a HUD in the gutters** (1.25, 1.26). The gutters are flat strips. M1's debug label HUD is not carried over: project-context says "there is no debug label HUD" (D7).
- **Add a brightness key or any function key** (DevTools in 1.11). See D7.
- **Build screens, the UI kit, the death card or pause** (1.29, 1.31, 1.34). `ScreenRouter` only gets the replace-never-stack mechanism and its test.
- **Add `Sensing` or `LightSource`** (1.20). The lurker still finds the player through the `player` group; only its on-screen test changes, plus D6's guard.
- **Add a shake setting** (1.16 adds `Settings.shake` and the gate). The rig's `kick()` is the single place that gate will read.
- **Add `request_respawn()` or `fast_travel()`** (AR19's other commands arrive with hazards in E4 and the hub in E5).

### Current state (read before changing)

- **`scripts/shaft.gd`** (interim game, 107 lines):
  - In `_ready()` it calls `Game.boot()` only when it is the current scene. It applies the ambient from `Settings.brightness` and connects `Game.settings.changed`.
  - It loads `m1_shaft`, moves it before `$Player`, places the player at `entry_position(&"spawn")`, wires `died`, `chain.banked` → `Game.dive.add_carried` and `chain.changed` → `Game.slot.record_chain`, and centres the camera limits on the room.
  - In `_physics_process` it kills the player once `y > bounds.end.y + 32`.
  - `_process` writes the debug label.
  - On death it calls `Game.slot.record_death()`, waits `RESPAWN_DELAY` 0.6 s on `create_timer(0.6, true, false, true)` (note `process_always = true`), then reloads the scene if it is current.
  - Its consts: `AMBIENT_LEVELS [0.07, 0.16, 0.28, 0.45]` and `AMBIENT_TINT (1.0, 0.86, 1.57)`.
  - **Port its behaviour into `world.gd` except the label, F1/F3 and the reload.**
- **`scripts/actors/player.gd`:**
  - Consts `SHAKE := 2.5` and `LOOK_AHEAD := 70.0`, already commented "moves to camera_rig.gd in 1.6".
  - `_process` (real time, `delta / maxf(Engine.time_scale, 0.001)`):
    - decays `_shake` at 20 px/s;
    - sets `_camera.offset` to `randf_range(±_shake)` on both axes;
    - eases `_camera.position.y` toward `LOOK_AHEAD` at 140 px/s while `velocity.y > 40 and not is_on_floor()`, else toward 0.
  - `_on_pogo_hit()` sets `_shake = SHAKE` and calls `Fx.chain_popup(get_parent(), …)`. `_on_banked` and `die()` also call `Fx.popup(get_parent(), …)`.
  - `die()` sets `is_dead`, ends the cling, calls `Game.clock.clear()` and `chain.lose()` (with a popup), zeroes the velocity and emits `died`.
- **`scenes/actors/player.tscn`:** `Camera` is a `Camera2D` child with `position_smoothing_enabled = true`, `position_smoothing_speed = 8.0`. Nothing else in the scene changes.
- **`scripts/actors/lurker.gd`:**
  - `_on_screen()` is `get_viewport_rect().grow(-SCREEN_MARGIN).has_point(get_global_transform_with_canvas().origin)`.
  - `_physics_process` re-fetches `_player` from group `player` only when it is null or freed.
  - `senses()` returns false for a dead player.
  - In HUNT, `monitorable = sensed`, and the lurker goes to RETURN after `lurker_lose_track_time` (0.6 s) of not sensing.
- **`scripts/actors/crawler.gd`:** `take_hit()` → `Fx.pop(get_parent(), …)` and `queue_free()`. Its parent is the room, which is correct already.
- **`DiveState`** (`rules/dive_state.gd`): `respawn_room` / `respawn_entry` are empty until set ("Empty: none set yet, so the dive's start room spawn (Story 1.6)"). `mark_killed` / `is_killed` exist with no caller yet (1.7).
- **`Game`:** `boot()` is called once by the entry scene (1.4 D6; the comment says "The call moves to world.gd in Story 1.6"). `reset_for_tests()` resets state and the Clock and disarms writes. `Game.clock.clear()` clears every request.
- **`tests/room_harness.gd`** (1.5):
  - `build(parent, room_id, entry := &"spawn")` adds the room, a test player and a `WorldStub` (group `world`) with `play_rect()` built from the player's camera (`PLAY_WIDTH := 360.0`).
  - `centre_camera(cam, room)` copies `shaft.gd`'s centring.
  - `free_all(parts)`.
- **Tests that touch the camera:**
  - `smoke_shaft.gd:53` `place()` calls `(_player.get_node("Camera") as Camera2D).reset_smoothing()`.
  - `smoke_shaft.gd:63` `test_world_stub()` checks the stub's 360 px rect.
  - `screenshot.gd:48` frames the shots with the player's camera and copies the ambient formula (1.5 review dismissed the duplication because 1.6 moves the ambient into World).
- **`project.godot`:** `run/main_scene="res://scenes/shaft.tscn"`, viewport 480×270, stretch `viewport` + `integer`, `snap_2d_transforms_to_pixel=true`. Autoloads: `Game` only.

### Decisions

These are story-author decisions; sonlm can veto any of them before dev. **D7's brightness gap is the one to look at.**

- **D1, the World tree.** `World` (`Node2D`, `world.gd`, `class_name World`, adds itself to group `world`):
  ```
  World
  ├── Darkness      CanvasModulate: the ambient from Settings.brightness (moved from shaft.tscn)
  ├── RoomHolder    Node2D at the origin, so room-local = world coordinates
  ├── Player        spawned by world.gd (D3); kept right after RoomHolder so it draws on top of the room
  ├── Camera        Camera2D + camera_rig.gd
  └── UI            CanvasLayer, layer 10, PROCESS_MODE_ALWAYS
      ├── Gutters       Control, full rect, mouse_filter IGNORE
      └── ScreenRouter  Control, full rect; later children draw on top, so menus sit above the gutters (UX-DR23)
  ```
  - `Darkness` is not in the architecture's tree. It belongs to `World` because brightness is a world setting that never touches the UI layer: a `CanvasModulate` tints only canvas layer 0, so the gutters and menus stay unaffected, as the architecture's UI → Brightness rule requires. Record this as a variance.
  - The player is **not** a node in `world.tscn`. `world.gd` spawns it in `_ready()` through the same `_spawn_player()` that respawns it, so first spawn and respawn are one path and both emit `player_spawned`.
  - `World` API:
    - `play_rect() -> Rect2`, which delegates to the camera (D2).
    - `current_room() -> Room` (D8).
    - `signal player_spawned(player: Player)`.
    - `const START_ROOM := &"m1_shaft"`, with a comment saying the slot's resume point replaces it in 1.21/1.38.
- **D2, `camera_rig.gd`** (`class_name CameraRig extends Camera2D`, a direct child of `World`):
  - **Consts:** `GUTTER_WIDTH := 60.0` and `PLAY_WIDTH := 360.0` (UX DESIGN.md Layout & Spacing; `gutters.gd` reads them from here). `LOOK_AHEAD := 70.0` (FR3, moved from `player.gd` with its comment). `LEAD_SPEED := 140.0` px/s and `SHAKE_DECAY := 20.0` px/s (M1 values). `POGO_SHAKE := 2.5` (was `player.SHAKE`).
  - `position_smoothing_enabled = true`, `position_smoothing_speed = 8.0`, set in the scene, as M1 had them.
  - `follow(target: Node2D)`: the body whose `velocity` and `is_on_floor()` drive the lead (duck typing, no `Player` type needed).
  - `snap()`: puts the camera on the target with no lead or shake left, then calls `reset_smoothing()`. `World` calls it on every (re)spawn, so a respawn cuts to the spawn instead of sliding across the room.
  - `kick(amount)`: `_shake = maxf(_shake, amount)`. **The only shake entry point:** Story 1.16 puts the `Settings.shake` gate here. `World` connects `player.pogo_hit` to `kick.bind(POGO_SHAKE)`.
  - `apply_limits(bounds: Rect2)`. **Top/bottom:** from `bounds`. **Horizontal:**
    - when `bounds.size.x <= PLAY_WIDTH`, centre the room in the view: `limit_left = int(bounds.position.x - (view_w - bounds.size.x) / 2.0)` and `limit_right = limit_left + int(view_w)`, with `view_w = get_viewport_rect().size.x`. This gives −64 / 416 for `m1_shaft`, where the room never scrolls sideways.
    - otherwise (the arena and hub later), `limit_left = int(bounds.position.x - GUTTER_WIDTH)` and `limit_right = int(bounds.end.x + GUTTER_WIDTH)`, so the play area can reach both room edges.
    - Replaces 1.5 D2's centring in `shaft.gd` and the harness.
  - `play_rect() -> Rect2`: `Rect2(get_screen_center_position() - Vector2(PLAY_WIDTH, view_h) / 2.0, Vector2(PLAY_WIDTH, view_h))`, the same formula as the harness stub, now in one place. For `m1_shaft` its x span is −4 … 356.
  - **`_process(delta)`, real time** (`delta / maxf(Engine.time_scale, 0.001)`, so the lead and the shake decay keep moving during hitstop, as in M1):
    - decay `_shake`, and set `offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))`, the only `randf` in `scripts/`;
    - ease `_lead` toward `LOOK_AHEAD` when `target.velocity.y > 40.0 and not target.is_on_floor()`, else toward 0;
    - set `global_position = target.global_position + Vector2(0, _lead)`.
    - With no valid target it does nothing.
  - **`player.gd`:**
    - Remove `SHAKE`, `LOOK_AHEAD`, `_shake`, `_camera` and the two camera blocks in `_process` (keep the squash), and add `signal pogo_hit`, emitted in `_on_pogo_hit()`.
    - Remove the `Camera` node from `player.tscn` and fix its `load_steps` if the count changes.
    - The file header comment stays true. Update the "Local consts" note in `docs/component-inventory.md`.
- **D3, spawn and respawn** (`world.gd`):
  - **`_ready()`:**
    - `add_to_group("world")`.
    - If `get_tree().current_scene == self`, call `Game.boot()` (moved from `shaft.gd` with its comment; a test adds `World` by hand, so it never boots).
    - Apply the ambient and connect `Game.settings.changed` to a method.
    - Load `START_ROOM` with `RoomLoader.load_room()` and `assert` that it isn't null (the loader has already `push_error`ed the content errors). Add it to `RoomHolder` and call `_camera.apply_limits(room.bounds())`.
    - Then `_spawn_player()`.
  - **`_spawn_player()`:**
    - If an old player exists: `remove_child()` it (it leaves group `player` now, not at the end of the frame, as the architecture asks for rooms), then `queue_free()` it.
    - Instance `player.tscn`, set `position = room.entry_position(entry)`, `add_child`, and `move_child` it to just after `RoomHolder`.
    - Bind it: `died` → `_on_player_died`, `chain.banked` → `Game.dive.add_carried`, `chain.changed` → `Game.slot.record_chain`, `pogo_hit` → `_camera.kick.bind(CameraRig.POGO_SHAKE)`. Use methods or bound callables, never lambdas that capture the player: a lambda capturing a RefCounted leaks (1.4 review fact).
    - `_camera.follow(player)`, `_camera.snap()`, then `player_spawned.emit(player)`.
  - **The respawn point:** `room = Game.dive.respawn_room`, or the current room's id when that is empty; `entry = Game.dive.respawn_entry`, or `&"spawn"` when that is empty. Assert that `room` is the current room's id, with the message "cross-room respawn goes through enter_room() from Story 1.7". Assert `has_entry(entry)`.
  - **`_on_player_died()`:**
    - Call `Game.slot.record_death()`.
    - Start `get_tree().create_timer(RESPAWN_DELAY, false, false, true)`: `process_always = false`, so a pause freezes it (AR36), and `ignore_time_scale = true`.
    - Connect its `timeout` to `_respawn` (a method, so the connection dies with `World`; **don't `await`** in a node that a test may free first).
  - **`_respawn()`:** `Game.clock.clear()` (AC3; `player.die()` already clears at the moment of death, which is kept because the harness tests rely on it), then `_spawn_player()`.
  - Keep `RESPAWN_DELAY := 0.6` (M1 value; the death card replaces this wait in 1.29), with a `##` comment.
  - **The out-of-room death moves to `world.gd` `_physics_process`:** `y > room.bounds().end.y + 32` → `die()`, with the comment "until 1.7 wires the bottom exit (R16 loop)".
- **D4, killed enemies stay dead because the room stays.**
  - In this story a death does not rebuild the room. Only the player is re-instanced, so a crawler killed this dive is already freed and stays gone, and live enemies keep their state.
  - Story 1.7 replaces this with `enter_room(respawn room, respawn object)` + `mark_killed` + the build skipping killed cells.
  - Don't call `mark_killed` here: 1.7's AC owns it and its test.
  - The test kills a crawler, dies and checks that the crawler count stayed one lower (D10).
- **D5, the lurker's on-screen test** (AR20):
  - `_on_screen()` gets the first node in group `world`. With none, it returns `false`: no World means no screen, so the lurker never notices, which errs on Pillar 2's side.
  - Otherwise it returns `world.play_rect().grow(-SCREEN_MARGIN).has_point(global_position)`. Both are world coordinates, so the canvas-transform maths goes away.
  - Keep `SCREEN_MARGIN` and update its comment ("inside the play rect", not "the visible screen").
- **D6, a lurker never carries a hunt over a death** (Pillar 2; "retargeting onto the player needs a fresh telegraph"):
  - **Why:** the old player stays in the tree during `RESPAWN_DELAY`. A HUNTing lurker that loses it would otherwise refetch the new player after the free and could keep HUNT (and `monitorable`) on a target that never saw a telegraph. Today only the timing hides this: lose-track 0.6 s against a respawn delay of 0.6 s.
  - **The fix:** in `_physics_process`, when `state` is TELEGRAPH or HUNT and the target is freed or dead (`get("is_dead")`), `_enter(State.RETURN)` at once. `_enter` already sets `monitorable = false`. Then refetch as today.
  - Tested in `smoke_world`.
- **D7, gutters, router and what the player loses for now.**
  - **`gutters.gd`:**
    - Two `ColorRect` children, x 0–60 and x 420–480, the full 270 px high, `mouse_filter` IGNORE.
    - Their colour is `const PLACEHOLDER := Color("#07060b")`, DESIGN.md's `gutter-violet` (`m1_shaft` is `zone=violet`). Its comment says the palette tokens and per-zone fill arrive in 1.18, and the 1 px rules and HUD in 1.25.
    - Widths come from `CameraRig.GUTTER_WIDTH`.
    - No HUD, no bindings: 1.25 adds `player_spawned` rebinding.
  - **`screen_router.gd`:**
    - `open(screen: Control)` removes and `queue_free()`s the current screen, then adds the new one. `close()` does the same with nothing to add. `current() -> Control`.
    - No screens exist yet; its test uses two plain `Control`s.
  - **Lost until later stories (tell sonlm at the feel check):**
    - **The debug label** (embers, chain, light, depth, alert, deaths). The chain popups still show the count in the world; the gutter HUD comes in 1.25/1.26 and the FPS/request overlay in 1.11.
    - **F1 brightness:** there is no in-game way to change it until DevTools (1.11), which 1.7's AC already assumes. The level saved in `user://settings.json` still applies at boot.
    - **F3 restart:** gone; restart by relaunching.
    - If sonlm wants F1 kept until 1.11, that breaks project-context's "no function keys" rule and needs his explicit call.
- **D8, popups go to the room.**
  - The player is a `World` child now, so `get_parent()` is `World`.
  - Add `func _fx_parent() -> Node` to `player.gd`. It returns the first `world` node's `current_room()` when there is one (duck typed: `has_method("current_room")`), else `get_parent()`. The fallback is for tests that add a bare player.
  - Use it in the three `Fx` calls.
  - The harness stub implements `current_room()` too, so the smoke tests behave like the game.
- **D9, the test harness and the ported tests.**
  - **`room_harness.gd`:**
    - Replace `centre_camera()` and the player-camera lookup with a `CameraRig` added under `parent` (`CameraRig.new()`, smoothing 8 as in the scene). Call `apply_limits(room.bounds())`, `follow(player)` and `snap()`.
    - Return it as `parts.camera` and free it in `free_all()`.
    - `WorldStub.play_rect()` returns `camera.play_rect()`; add `current_room()` returning the room.
    - Update the header comment.
  - **`smoke_shaft.gd`:** `place()` calls `_parts.camera.snap()` instead of the player camera's `reset_smoothing()`. `test_world_stub()` and every other check stay word for word: still 30 `ok`.
  - **`screenshot.gd`:**
    - Instance `world.tscn` by hand instead of the harness, so the shots show the real gutters, darkness and framing. Delete the copied ambient formula, which also resolves the 1.5 review's duplication note.
    - Get the player through `player_spawned` or the `player` group, and frame it with the world's camera (`snap()`).
    - Keep the two shots (the spawn and the second-highest lurker by y).
- **D10, `tests/smoke_world.gd`** (replaces `smoke_shaft_state.gd`; same frame, temp-folder and teardown rules as that file):
  - **Setup:** point `Game.store.dir` at `user://smoke_world_tmp`, instance `world.tscn`, `add_child` it, then wait 2 frames. Pause the room's lurkers except where a case needs them. Tear down with `queue_free`, then `Game.reset_for_tests()`, then remove the temp folder.
  - **Cases:**
    1. **No boot:** a World added by hand is not the current scene, so `Game._booted` and `_settings_armed` stay false.
    2. **The tree:**
       - `World` is in group `world`.
       - `RoomHolder` holds one `Room` with id `m1_shaft`.
       - `Camera` is a `CameraRig`.
       - `UI` is a `CanvasLayer` with `process_mode == PROCESS_MODE_ALWAYS`, its children `Gutters` then `ScreenRouter` in that order.
       - The player's index is right after `RoomHolder`.
       - `get_tree().current_scene` is unchanged (the runner's).
    3. **Framing:**
       - The camera limits are −64 / 416 / 0 / 1680.
       - `play_rect().size == Vector2(360, 270)`, its x span is −4 … 356, and it contains the room's full width.
       - The gutter strips are 60 px wide at screen x 0 and 420.
       - Compare against the UX numbers here (360, 60), not against the rig's consts.
    4. **State wiring** (from `smoke_shaft_state`, same checks): a chain of 3 records `best_chain` 3; a break banks 6 as carried; brightness `set_value` repaints `Darkness` for every level.
    5. **Popups in the room:** a bank adds a node under the room and none under `World` (AC6).
    6. **Death and respawn:**
       - Request a Clock hitstop; kill the topmost crawler by y (`take_hit()`); hold 2 links; move the player 160 px down; `die()`.
       - Right away: `deaths == 1`, carried kept, held lost, and the Clock has no active request.
       - After `RESPAWN_DELAY + 0.1` s:
         - **World:** the same `World` instance is still in the tree.
         - **Player:** a new player exists that isn't the old one, and the old one is freed or out of the tree. The new player is at `entry_position(&"spawn")`, not where the old one died.
         - **Signal:** `player_spawned` fired once, with the new player.
         - **Camera:** its target is the new player.
         - **Rebinding:** the new player's chain is bound (`add_hit()` ×4 records `best_chain` 4).
         - **Crawlers:** the count is still one lower.
    7. **Behind the gutter (AC2):**
       - Freeze the player (`set_physics_process(false)`) at world (24, y) in the open column, give it 4 links (radius ≈ 84 px), and pause the room's own lurkers.
       - `room.spawn()` lurker A at (−24, y) and lurker B at (72, y), 48 px either side. A is at screen x ≈ 40: inside the viewport, behind the left gutter and outside the play rect.
       - Assert A's precondition: inside `get_viewport_rect()` by its canvas transform, outside `play_rect()`.
       - After 0.3 s, B is in TELEGRAPH (the control: proves the test can fail) and A is still IDLE.
       - Free both before B can hunt.
    8. **Hunt over a death (D6):** a lurker in HUNT on the player; `die()`; one physics frame later the lurker is in RETURN with `monitorable == false`.
    9. **ScreenRouter:** `open(a)`, `open(b)` → `current() == b` and `a` is out of the router; `close()` → `current() == null`.
    10. **Source checks for AC2 and AC4**, until the lint lands in 1.9: `lurker.gd`'s text has no `get_viewport_rect`; scanning `res://scripts/` (recursively, `.gd` files) for `randf` finds only `world/camera_rig.gd`.
- **D11, docs** (facts only):
  - **`docs/architecture.md`:**
    - the scene diagram (World instead of `shaft.tscn`);
    - the camera/real-time note;
    - the integration-test rows (`smoke_world` replaces `smoke_shaft_state`);
    - the "Play width" and "Scene structure" rows of the gap table: gutters in, one room, swaps from 1.7.
  - **`docs/component-inventory.md`:**
    - Player: no Camera, `pogo_hit`, local consts;
    - new World, CameraRig, Gutters and ScreenRouter entries;
    - Shaft marked "unused, deleted in 1.7; its camera lookup no longer matches `player.tscn`";
    - the test table.
  - **`docs/development-guide.md`:** the main scene is `scenes/world/world.tscn`; the test commands.
  - **`docs/source-tree-analysis.md`:** entry point and tree.
  - **`docs/index.md`:** if it names the entry scene.
  - **`docs/rooms.md`:** the harness paragraph (camera rig, `current_room()`).
  - **`game/README.md`:**
    - controls: no F1/F3 for now, a death respawns you at the top without a reload;
    - the test list: `smoke_world` replaces `smoke_shaft_state`;
    - the HUD note (no label until the gutter HUD).
  - **`_bmad-output/project-context.md` → *Current State vs Target*:** one sentence for Story 1.6. Also change "`shaft.gd`/`shaft.tscn` at the top level (F1/F3, scene reload, the out-of-room death; retired in 1.7)" so it says the shaft is unused and the out-of-room death now lives in `world.gd` until 1.7.
- **D12, the feel check (for the report).** sonlm plays `world.tscn` (F5) on the laptop and checks:
  - the gutters frame the 352 px shaft;
  - the camera lead and the pogo shake feel as in M1;
  - a death cuts back to the spawn without a reload, carried embers kept;
  - a crawler killed before a death is still gone after it;
  - the lurkers near the walls still telegraph on screen.
  - The losses in D7 are expected.

### Project Structure Notes

- **New:**
  - `game/scripts/world/world.gd`, `game/scripts/world/camera_rig.gd`, `game/scenes/world/world.tscn`;
  - `game/scripts/ui/gutters.gd`, `game/scripts/ui/screen_router.gd` (the first files in `ui/`);
  - `game/tests/smoke_world.gd`.
  - `scenes/ui/` stays empty: the gutters and router are built in code or in `world.tscn`.
- **Changed:** `player.gd`, `player.tscn`, `lurker.gd`, `project.godot`, `run_tests.sh`, `tests/room_harness.gd`, `tests/smoke_shaft.gd`, `tests/screenshot.gd`, the docs in D11.
- **Deleted:** `tests/smoke_shaft_state.gd` (+ `.uid`), with `git rm`.
- **Untouched:** `shaft.gd`, `shaft.tscn`, everything in `rules/`, `room*.gd`, `crawler.gd`, `fx.gd`.
- **Dependencies:**
  - `world/` uses `actors/` scenes, and `ui/` reads `CameraRig` consts (`ui` may depend on `world`).
  - `rules/` gains nothing.
  - Nothing references `dev/` (it doesn't exist until 1.11).
- **Variance from the architecture's tree:** `Darkness` under `World` (D1), and the player spawned in code rather than placed in the scene.

### Project Context Rules (that apply here)

- **State lives in `Game` refs, untouched.**
  - Death does not reload the scene: `World` spawns a fresh `Player` and emits `player_spawned(player)`, and anything bound to `player.chain` rebinds there.
  - Never replace `Game.slot` / `Game.dive`.
- **Time:**
  - Only `Game.clock` writes `Engine.time_scale`.
  - Real-time visuals use `delta / Engine.time_scale` in `_process`.
  - Pause is `SceneTree.paused`, and the respawn timer pauses with the tree.
- **Movement stays in `_physics_process`.** `_process` is visuals only: the camera rig is visuals.
- **Groups:**
  - Actors find each other by group and duck typing, never node paths: World by `world`, the player by `player`, `has_method("current_room")`.
  - "On screen" always means `World.play_rect()`, never the viewport.
- **A predator kills only while `monitorable` and only while the player is its target.** Never add a kill path, and D6 removes one.
- **Runtime spawns:** go through `room.spawn()`, and never parent flares or FX to `World` (D8).
- **Randomness:** `randf` is for camera shake only (D2). No randomness in level behaviour.
- **Errors:**
  - Programmer errors → `assert`.
  - Never `.free()`; use `remove_child()` + `queue_free()`.
  - No bare `print()` in game code; tests print `ok`/`FAIL`.
  - No logging in hot paths.
- **No function keys** and no raw keycodes in new code (D7).
- **No addons, no `.tres`.** The TileSet and materials are in code; `world.tscn` holds only nodes and plain properties.
- **Comments explain why and cite the design:** "AR20", "UX-DR18", "FR3", "Pillar 2", "D6".
- **Commit `.gd.uid` and `.import` files.** Re-import after new `class_name`s.
- **Tests:**
  - Name them to match the glob (`smoke_world`), and add them to the `for t in …` list until 1.9's glob runner.
  - Targets are picked by position, never `get_nodes_in_group()[i]`.
  - The runner fails on any `ERROR:` line: a leaked lambda or a freed-instance access shows up there.
- **Report** "tests green; needs a feel check on the laptop".

### Previous story intelligence (1.5 and its review)

- **The room API to use:**
  - `RoomLoader.load_room(id)` (the index of `res://rooms/`; test rooms under `tests/rooms/` are **not** indexed, and 1.7 decides how they will be).
  - `room.entry_position(entry)`, `has_entry()`, `bounds()`, `spawn(scene, pos, args)` and `cell_centre(cell)`.
- **Facts from the 1.5 review:**
  - `entry_position(&"down")` puts a player over the exit hole (deferred to 1.7, not used here).
  - `RoomHarness.build()` takes an `entry`.
  - The validator rejects corner exits and solid entry cells.
- **Fixed geometry:**
  - `m1_shaft` is 352 × 1680, and `P` is at col 3, row 5 (`entry_position(&"spawn") == (56, 84)`).
  - The in-wall lurkers are at (8, 28·16+8), (344, 55·16+8), (8, 70·16+8), and one free lurker is at col 16, row 92.
  - The crawlers are at rows 40, 84 and 102 (pick by position).
- **1.4 facts that bite here:**
  - A lambda connected to a RefCounted's signal that captures that object leaks both, and the leak prints an engine `ERROR:` after the runner exits 0, so grep the raw output.
  - `process_frame` fires before nodes' `_process`, so wait two frames before reading what `_process` wrote.
  - Each test file runs in its own process.
- **1.2 fact:** the runner waits 2 frames before `run()`. Never remove that.

### Git intelligence

- `98a18df`, `0e3079b`, `30a96c2` (1.5): the room files, loader, harness and the shaft port.
- `e11203c` (1.5 review fixes) and `4c5929e` (review record): 1.6 starts from `4c5929e`.
- **Commit pattern:** `feat:` for code, `refactor:` for moves, `docs:` for docs and records. End messages with the session attribution lines.

### Cross-story context (Epic 1)

- **1.7:**
  - `enter_room()`, exit triggers, a respawn through `enter_room()` that rebuilds the room, `mark_killed`, physics interpolation (`reset_physics_interpolation()` on every spawn; leave a `# 1.7:` marker where `_spawn_player` places the player).
  - It deletes `shaft.*` and the out-of-room death, and decides how arrival from below works (deferred item).
- **1.8:** `PlayerInput`. The rig reads only `velocity` / `is_on_floor()`, so it is unaffected.
- **1.9:** the lint takes over D10's source checks (`randf` only in `camera_rig.gd`, no `get_viewport_rect` outside the UI), plus `Spec`.
- **1.11:** DevTools is added by `world.gd` through a path-string `load()` inside `if OS.is_debug_build()`. Brightness, `--room=` and the overlays (overlay 1 draws `play_rect()` and the gutters).
- **1.16:** the `Settings.shake` gate goes in `CameraRig.kick()`.
- **1.18:** palettes. The gutter fill comes from the zone's `gutter-*` token.
- **1.19:** Health. `died` and the respawn stay, at full HP.
- **1.20:** `Sensing` + `LightSource` replace the lurker's `player` group lookup. `play_rect()` is the screen test.
- **1.21 / 1.38:** the resume point replaces `START_ROOM`.
- **1.24:** anchors and stations set `Game.dive.set_respawn()`.
- **1.25 / 1.26:** the gutter HUD binds on `player_spawned`.
- **1.29:** the death card goes through `ScreenRouter`, replacing `RESPAWN_DELAY`.
- **1.31:** the UI kit.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.6, AR2, AR3, AR19, AR20, AR25, AR27, AR36, AR39, FR3, UX-DR18, UX-DR23, UX-DR123]
- [Source: _bmad-output/game-architecture.md#Scene Structure and Rooms, #Time Control, #UI, #Event System, #Debug Tools, #3. Safe-Cut Room Flow]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/DESIGN.md#Layout & Spacing (gutter-width 60, gutter-usable 58, gutter-violet #07060b)]
- [Source: _bmad-output/project-context.md (all sections)]
- [Source: _bmad-output/implementation-artifacts/1-5-rooms-as-text-the-m1-shaft-at-22-tiles.md#Cross-story context, #Review Findings]
- [Source: _bmad-output/implementation-artifacts/m1-playtest-findings.md (camera lead and shake values are M1's, unchanged)]
- [Source: game/scripts/shaft.gd, game/scripts/actors/player.gd, game/scripts/actors/lurker.gd, game/scenes/actors/player.tscn, game/tests/room_harness.gd, game/tests/smoke_shaft_state.gd]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

- Story context created by gds-create-story on 2026-11-13. Ultimate context engine analysis completed - comprehensive developer guide created. Baseline re-run at `4c5929e`: `== ALL GREEN`.

### File List
