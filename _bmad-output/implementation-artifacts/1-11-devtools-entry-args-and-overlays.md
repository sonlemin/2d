---
baseline_commit: 65849f1
---
# Story 1.11: DevTools: entry args and overlays

Status: done

**Type:** dev · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP1 Foundations (1.1–1.15) · **Branch:** `feat/m2-e1`

## Story

As the developer,
I want debug-only entry arguments and overlays,
so that I can jump straight into any room and state and see the invisible rules without any of it shipping.

## Acceptance Criteria

1. **One line adds DevTools, and only in debug builds.** `scripts/dev/dev_tools.gd` (`class_name DevTools`, extends `Node`) is added by `World._ready()` with exactly this code, as its first statement:
   ```gdscript
   if OS.is_debug_build():
       add_child(load("res://scripts/dev/dev_tools.gd").new())  # path string, never preload: release exports exclude scripts/dev/
   ```
   - It uses no `preload`, no `DevTools` identifier and no `.tscn`, so a release export without `scripts/dev/` still loads `world.gd`.
   - It is the only reference to `dev/` outside `dev/` and `tests/`.
   - The lint's `dev_ref` rule lets through exactly that line, once, under that guard, in `world/world.gd`. Every near-miss still fires, and a test proves the real `world.gd` holds it exactly once.
   - Any `class_name` declared under `dev/` is also banned outside `dev/`.

   (AR54, AR48; D1, D2, D12)
2. **Entry args, from the command line or the URL query.**
   - On desktop, DevTools reads `OS.get_cmdline_user_args()` (everything after `--`).
   - In a web debug build, it reads the URL query (`?room=<id>&chain=<n>`). A pure static `query_tokens()` turns it into the same `--key=value` tokens. It can't fail: malformed parts become tokens that `parse()` reports.
   - `parse()` is a pure static function that returns the values and an error list:
     - tokens that don't start with `--` are ignored, including the test runner's own `res://tests/…gd` path;
     - an unknown arg is an error that lists the known ones;
     - errors reach the developer as `push_warning`, never `push_error` or `assert`, and the game still starts.
   - Args are applied only when World is the current scene (a real run). A test injects tokens instead.
   - Each arg is one row in a registry in `dev_tools.gd`, so 1.12 (`--glow`), 1.19 (`--hp`) and 1.22 (`--difficulty`) each add a row.

   (AR54; D3, D4)
3. **`--room=<id>` starts the dive in that room.**
   - The dive starts in that room, and a death respawns there while no respawn point is set.
   - The entry is `spawn` when the room has a `P`, else `up`, else `down`.
   - An unknown id gives a warning that lists the known ids. An invalid room gives a warning with its first validation errors. Either way the default start room loads, with no `push_error` and no `assert`.
   - DevTools never writes `Game.dive`'s respawn point.

   (AR54; D5)
4. **`--chain=<n>` gives the player that chain.**
   - n is an integer from 0 to `ChainState.MAX_CHAIN`. Anything else is a warning, and no chain is applied.
   - The chain is armed on each spawn, every life. It is applied through `ChainState.add_hit()` n times on the first physics tick that ends with the player off the floor. A spawn that is already falling gets it on its first tick.
   - It then breaks and banks like any chain: landing, Snuff, cling grace, a knock, or an exit.
   - It never pins the chain or skips a landing break, so "Snuff / land / cling in time always saves you" still holds.

   (AR54; D6, decided by sonlm 2026-11-19)
5. **`--log=<cat>,<cat>` enables those `Log` categories.**
   - Names are matched case-insensitively against `Log.CATEGORIES`.
   - An unknown name is a warning that lists the valid ones and is skipped.
   - The valid ones go to one `Log.set_enabled()` call.
   - With no `--log`, DevTools never calls `Log.set_enabled()`.

   (AR55; D7)
6. **`--set=<key>:<value>` overrides a `Settings` value for this session only.**
   - It works for any key in `Settings.SCHEMA`, typed by that key's default: int, float or bool. It may repeat.
   - An unknown key, a bad value or a type the command line can't express is a warning listing the keys and their choices.
   - The override goes through a new `Game.override_setting()`. While any override exists:
     - the value survives `Game.boot()`'s load;
     - the session writes no `settings.json` at all: not for the override, not for a load that would rewrite the file, and not for a later change of another key;
     - `reset_for_tests()` clears it.
   - `--set=brightness:<0-3>` is how brightness changes in-game until Options (Story 1.36). It lasts for the session only.

   (AR14, AR54; D8, decided by sonlm 2026-11-19)
7. **The overlay action cycles four overlays, then off.** `dev_overlay` is a project input action bound to the backquote key (physical keycode 96) and nothing else. Each press cycles the overlays, starting from off:
   1. **Play rect and gutters.** `World.play_rect()`; the notice rect (`play_rect()` shrunk by `Lurker.SCREEN_MARGIN`); both 60 px gutters and their usable bands, in screen space.
   2. **Light radii and notice rings.** The player's sensing radius `light_radius()` and its notice reach (× `Lurker.NOTICE_FACTOR`), drawn so a radius below `Lurker.NOTICE_MIN_RADIUS` reads as "can't be noticed". Each predator's state and whether it senses the player.
   3. **Room exits and persistent object ids.** Each exit opening with its side and target; the entry points; each `obj=` id at its cell.
   4. **FPS, on-screen `PointLight2D` count and active Clock requests.** The Clock list comes from a new read-only `Clock.active()`. It is sampled every frame, and each request stays listed 0.5 s after it ends.
   5. **Off.**

   The overlays read the same values the game uses, never copied numbers. They are readable under the darkness: world marks use a cached static unshaded material, and screen marks sit on DevTools' own CanvasLayer above the UI. They still cycle while the tree is paused. They never blink, and they never add a node under `World/UI`, `RoomHolder` or the room. (AR54, AR20, AR46, NFR8; D9–D11)
8. **No function key is bound anywhere.** A test checks every project action (all actions except the engine's `ui_*` built-ins): none has an F-key event, and `dev_overlay` has exactly one event, the physical backquote with no modifiers. (AR54, NFR16; D13)
9. **Inert without args, and in every existing test.** In a run with no args, DevTools does all of this:
   - it changes no state (start room, chain, settings, Log categories, Clock);
   - it adds nothing outside its own subtree;
   - it shows no overlay until the key is pressed.

   `smoke_world` and `smoke_room_swap` stay green unchanged, with DevTools present in them. (D3, D14)
10. **Done means green.**
    - `cd game && ./run_tests.sh` ends in `== ALL GREEN (17 tests)`: 15 plus `test_dev_args` and `smoke_dev_tools`.
    - Every new check is red-checked (D16).
    - The docs, `project-context.md`, the architecture and the deferred-work ledger say how DevTools works (D15).
    - The only game-code edits, outside `scripts/dev/`, are:
      - the hook line, `start_entry` and the fallback in `world.gd`;
      - `RoomLoader.room_ids()` / `inspect()`;
      - `Settings.is_valid()` (with an optional schema);
      - `Game.override_setting()` and its load and reset handling;
      - `Clock.active()`;
      - the `dev_overlay` action in `project.godot`.

    No gameplay behaviour changes in a run without args.

## Tasks / Subtasks

- [x] **Task 1: Baseline (AC: 10).** `cd game && ./run_tests.sh` gives `== ALL GREEN (15 tests)`. Record the per-test `ok` counts, which "Previous story intelligence" lists. Every engine fact this story relies on is already probed (see "Verified facts").
- [x] **Task 2: The small APIs below `dev/` (AC: 3, 6, 7, 10).**
  - [x] Add `Clock.active() -> Dictionary` (D11). Cases go in `test_clock.gd`.
  - [x] Add `Settings.is_valid(key, v, schema := SCHEMA) -> bool`, public and static, replacing the private `_valid` (D8). Cases go in `test_state.gd`.
  - [x] Add `Game.override_setting(key, v)`, plus `load_settings()` re-applying overrides without arming, and `reset_for_tests()` clearing them (D8). Cases go in `test_state.gd`, per D14.
  - [x] Add `RoomLoader.room_ids()` and `RoomLoader.inspect(id)`, which never `push_error` (D5). Cases go in `test_room_loader.gd`.
  - [x] In `world.gd`, add the hook line, `start_entry` and the fallback using `start_entry`, and update the comments that named 1.11 (D2, D5).
  - [x] Add the `dev_overlay` action to `project.godot`, copying the existing one-line event format with `"physical_keycode":96` (D13).
- [x] **Task 3: `scripts/dev/dev_tools.gd` (AC: 2–6, 9).** Write the pure parsers, the registry and the apply phases (D3–D8).
- [x] **Task 4: `scripts/dev/overlays.gd` (AC: 7).** Write the node layout, the four modes, the light count and the Clock rows (D9–D11).
- [x] **Task 5: The lint (AC: 1, 10).** Add `dev_ref`'s exact-line exemption and `dev/` class names, and the `dev/` allowance in `raw_input`, with samples and tree checks (D12).
- [x] **Task 6: Tests (AC: 2–9).**
  - [x] Create `tests/test_dev_args.gd`, `tests/smoke_dev_tools.gd` and the fixture `tests/rooms/dev_tools/t_dev_room.txt` (D14).
  - [x] Add cases to `test_lint`, `test_clock`, `test_state` and `test_room_loader`.
- [x] **Task 7: Docs and ledger (AC: 10).** Update everything D15 lists. Add the eight ledger items D15 names, each with its owner line.
- [x] **Task 8: Verify (AC: 10).**
  - [x] `./run_tests.sh` gives `== ALL GREEN (17 tests)`, with no `ERROR:` lines. Also grep the raw output for `ERROR:` printed after the runner exits (leaks).
  - [x] Run the D16 red checks and record each in the Debug Log, restoring with `git diff` clean on the touched file.
  - [x] Take one xvfb screenshot per overlay mode at brightness 0, and look at each. Record what you see. Use a scratch script **outside the repo**, run through the runner by its absolute path (the runner loads any path; probed):

    `xvfb-run -a godot --path game --rendering-driver opengl3 res://tests/runner.tscn -- /abs/path/shot_overlays.gd <out>`

    The script copies `screenshot.gd`'s approach. It injects `--set=brightness:0` through the D3 seam, then sets the DevTools overlays' `mode` to 1–4, waiting 2 process frames before each shot. It ends with `Game.reset_for_tests()`. Never commit it, and never put it under `tests/` (the glob would run a `smoke_*`).
  - [x] Stage every new `.gd` with its `.gd.uid`, and the fixture room.
  - [x] Report: "tests green; needs a 2-minute look on the laptop". The look is `godot --path game -- --room=m1_shaft --chain=8 --set=brightness:0`, then walk off the spawn ledge and cycle the overlays with the backquote key. In m1_shaft the chain shows 8 at take-off and usually ends on the first hoverer bump, not a landing (D14).

### Review Findings

Code review 2026-11-19: five reviewer layers (blind, edge case, acceptance auditor, verification gap, docs) on Fable 5.2, each finding then checked by a refuting verifier. 31 raw: 7 merged as duplicates, 7 dismissed, 17 kept.

- [x] [Review][Decision] How far the overlay tests check what is drawn — `test_overlay_cycle` counts `draw` signals, which fire on every `queue_redraw()`, so an empty `_draw_world` / `_draw_screen` passes. Content is asserted only for mode 3's item list, mode 4's rows and the light count; mode 1's play rect and notice margin and mode 2's light ring, dashed reach below `Lurker.NOTICE_MIN_RADIUS` and predator labels are not. Options: branch coverage only (the patches below), a pure `light_marks()` for mode 2's numbers tested at the 80 px boundary, or pure builders for modes 1–3. **sonlm (2026-11-19): `light_marks()` for mode 2** (done, with the branch coverage).
- [x] [Review][Patch] `--chain` would pay a player that has not ticked yet if a later story spawns it from inside a physics tick (`is_on_floor()` is false before its first `move_and_slide()`); only pause is guarded. Also skip the spawn's own physics frame, D6's "only on ticks the player itself ran" [game/scripts/dev/dev_tools.gd:76]
- [x] [Review][Patch] `real_tokens()` and the `current_scene == World` gate never run in the suite, so a break in reading the command line ships green; test both [game/scripts/dev/dev_tools.gd:54]
- [x] [Review][Patch] `--log` with no valid category still calls `Log.set_enabled([])` and logs `dev: log `, and `--log=` gives no warning; warn and leave Log alone, like any other bad value [game/scripts/dev/dev_tools.gd:254]
- [x] [Review][Patch] The bad-arg warnings (unknown arg, a repeated single-valued arg, a bad `--chain`, a bad `--log` name) are never observed through DevTools, only as pure error lists; one smoke case [game/tests/smoke_dev_tools.gd]
- [x] [Review][Patch] AC5's "no `--log`, no `Log.set_enabled()` call" and "one merged call" pass either way; enable a category before the no-token build, and give `test_log` two `--log` tokens [game/tests/smoke_dev_tools.gd]
- [x] [Review][Patch] The light count's play-rect argument is unpinned (the viewport rect also gives 1 at the spawn); add a code-built light inside the play rect and one under a gutter [game/scripts/dev/overlays.gd:141]
- [x] [Review][Patch] Overlay 2's "can be noticed" branch and the predator sense line never run in a test; draw mode 2 past 80 px of light near a sensing lurker [game/scripts/dev/overlays.gd:233]
- [x] [Review][Patch] Mode 3's `obj` drawing branch is never proven to draw: `test_room_items` reads the item list only, and the cycle test's m1_shaft has no `obj=` [game/tests/smoke_dev_tools.gd]
- [x] [Review][Patch] AC10: new checks with no recorded red check (the shared cached material, Screen above UI, `room_items()`, the light filters other than hidden, `clock_rows` at 499/500 ms, `Settings.is_valid`, bad `--set` values); run and record them [story Debug Log]
- [x] [Review][Patch] The StringName "premise" check turns FAIL whenever an unrelated change makes the interning order alphabetical; make it a warning, the pairwise check stays [game/tests/test_room_loader.gd:262]
- [x] [Review][Patch] The lint `once` samples have no different guard (`if not OS.is_debug_build():`) and no statement between guard and line; `_test_world_hook` doesn't pin "the first statement of `_ready()`" [game/tests/test_lint.gd:371]
- [x] [Review][Patch] Task 8 "Stage every new `.gd` with its `.gd.uid`, and the fixture room" is ticked, but nothing is staged [story Tasks]
- [x] [Review][Patch] The Change Log says 11 extra red checks; the Debug Log lists 9 [story Change Log]
- [x] [Review][Patch] project-context.md's release-preset exclusions omit `scripts/dev/*`, and the `world.gd` hook comment and the dev guide state the exclusion in the present tense before Story 1.13 adds the presets [_bmad-output/project-context.md:97]
- [x] [Review][Patch] The docs say `dev_ref` catches any `scripts/dev/` path; the rule matches `res://` paths only [docs/development-guide.md:125]
- [x] [Review][Patch] The dev guide's "no function key is bound anywhere" overstates the test, which skips the engine's `ui_*` actions [docs/development-guide.md:51]
- [x] [Review][Defer] On a web debug build every foreign URL query parameter becomes an `unknown arg` warning on each load (AC2 as specified) [game/scripts/dev/dev_tools.gd:95] — deferred to Story 1.13

## Dev Notes

### What this story is (and isn't)

It is the debug toolbox the rest of E1 and E2 lean on. It gives:
- a way to start in any room with state set;
- the session-only settings switch, which is how brightness and (from 1.16) the accessibility settings change until Options in 1.36;
- the four overlays that make the invisible rules visible.

It is **debug-only**: `World` adds it inside `if OS.is_debug_build()`, and release presets (1.13) exclude `scripts/dev/*`. **No gameplay behaviour changes** in a run without args.

**Not in this story:**
- **`--glow=on|off`, the worst-frame readout, `rooms/dev/perf_worst.txt`, the light budget and `Fx`'s cached materials:** Story 1.12. Leave `fx.gd` alone; 1.12's AC fixes `_unshaded()`.
- **Export presets, the `scripts/dev/*` release exclusion, web templates, `SMOKE boot ok` markers and the Playwright `?room=perf_worst` boot:** Story 1.13. Its AC already limits the exclusion to release presets, and "Cross-story context" repeats it. The server has no web export templates yet (only linux/windows), so the URL-query path is unit-tested here and first runs on web in 1.13.
- **Page keys on web** (arrows, Space, F-keys never scroll): Story 1.14.
- **`--hp`:** Story 1.19. **`--difficulty`:** Story 1.22. Each adds one registry row.
- **Sense and stir rings, the `light_source` group, and a ring per light source:** Story 1.20 (ledger item 3).
- **Flares and the Ember Cache in the overlays:** the light count finds them on its own, because it walks World's subtree (1.23's AC: "the overlay counts it"). Their radius rings are ledger item 3.
- **Anchor and station entries in overlay 3:** Story 1.24 (ledger item 7). Their `obj=` ids already show.
- **A chain that holds on the ground for the perf run:** Story 1.12 (ledger item 1).
- **Skipping the title or web gate on `--room`:** Story 1.33 (ledger item 8).
- **Choosing the entry by hand.** Story 1.10 noted "`--room=<id>` (any entry)". Here the entry is picked automatically (D5), so arriving from below stays tests-only (`World.enter_room`). A `--room=<id>@<entry>` form would be one validator change if a later story needs it.
- **An `--overlay=` start mode, a brightness key or any other hotkey:** not requested; don't add them.

### Current state (read before changing)

- **`scripts/world/world.gd`**
  - `_ready()` (`:39-51`) runs, in order: `add_to_group("world")`; then `Game.boot()`, only when World is the current scene (`:44-45`); `_apply_ambient()`; `Game.settings.changed.connect(...)`; `_respawn_point()`; and `_swap_room(..., true)`, synchronously on the first room. The first `player_spawned` is emitted inside that call (`:146`).
  - `start_room` (`:26-28`) is public. Its comment says "Set before add_child: tests do, and DevTools' --room= will (1.11)". DevTools sets it from inside `_ready`, before `_respawn_point()`, so the comment changes.
  - `_respawn_point()` (`:157-160`) prefers `Game.dive.respawn_room`, else `start_room` + a hard-coded `&"spawn"`.
  - Failure path (`:113-122`): a bad respawn point falls back to `start_room`/`spawn`. If **that** fails, it hits `assert(false)`. So today, an unknown `--room` written into `start_room`, or a room without `P`, ends in `assert` with no room and no player. That is why D5 validates first.
  - Brightness: `AMBIENT_LEVELS` / `_apply_ambient()` (`:20-24`, `:202-204`) repaints on `settings.changed` (`:197-199`).
- **`scenes/world/world.tscn`**
  - Children in order: Darkness (`CanvasModulate`), RoomHolder, Camera (`CameraRig`), UI (`CanvasLayer`, layer 10, `process_mode` ALWAYS) holding Gutters and ScreenRouter.
  - The player is inserted at RoomHolder index + 1 (`world.gd:171`). A DevTools node added in `_ready` lands after UI.
- **`scripts/world/camera_rig.gd`:** `GUTTER_WIDTH` 60 and `PLAY_WIDTH` 360 (`:12-13`). `play_rect()` (`:81-83`) is the rig's clamped, smoothed centre on the physics tick, **without** the shake `offset`. In m1_shaft it spans x −4…356.
- **`scripts/world/room.gd`**
  - Fields: `exits` (`{side, target, col, entry_cell}`), `objects` (`{id: cell}`), `spawn_cell` ((−1,−1) without `P`), `size_cells`.
  - Methods: `has_entry()`, `entry_position()` (asserts the entry exists), `cell_centre()`, `exit(side)`. Room space is world space (RoomHolder and the room sit at the origin).
  - No room under `res://rooms/` has an `obj=` line yet. Overlay 3's id test uses the new fixture.
- **`scripts/world/room_loader.gd`**
  - `load_room(id)` calls `push_error` on an unknown id (`:37-42`). `load_room_from_path` calls `push_error` on every validation error.
  - The id index (`_get_index()`, `:376`; StringName keys from `_scan`) is private. There is no public "does this room exist / which entries" query, so D5 adds one.
  - `parse()` and `validate()` are pure. `validate()` requires solid ground under `P`.
  - `add_root(dir)` recurses into subfolders. Adding a folder and also one of its subfolders indexes the same files twice, and `_scan` calls `push_error` for each duplicate id.
- **`scripts/actors/player.gd`**
  - `if is_on_floor(): … chain.break_chain()` runs **every tick** after `move_and_slide()` (`:74-80`).
  - Every valid room's `P` stands on a floor (m1_shaft's spawn is (56, 84), feet on the tile), so a chain set at spawn breaks on tick 1 and banks its held embers.
  - `light_radius()` (`:59-60`) is the sensing radius. The visible light lerps toward it (`:279-282`); draw the sensing one.
  - Contact with a crawler knocks the player back and banks the chain in mid-air (`_check_contact` → `_take_knockback`, `:287-308`).
- **`scripts/rules/chain_state.gd`**
  - There is no count setter. `add_hit()` is the rule method: +1 link up to `MAX_CHAIN` (20), held += `ember_value(link)`, emits `changed`. A snuffed hit adds nothing.
  - `world.gd:175-176` wires `banked` to `Game.dive.add_carried` and `changed` to `Game.slot.record_chain`.
  - **`tests/test_chain_state.gd` is the spec**; this story doesn't change ChainState.
- **`scripts/actors/lurker.gd`**
  - Group `predator`; public `state` (`IDLE/TELEGRAPH/HUNT/RETURN`).
  - `senses(player)` (`:46-51`): radius ≥ `NOTICE_MIN_RADIUS` (80), distance ≤ radius × `NOTICE_FACTOR` (1.6), inside `play_rect().grow(-SCREEN_MARGIN)` (8).
  - The `Glow` `PointLight2D` (`lurker.tscn`: energy 0, `texture_scale` 0.8) gets `energy = eye alpha × 1.3` and `visible = energy > 0.01` (`:116-118`). Eye alpha is 0 while IDLE, so an idle glow is dark and hidden.
- **`scripts/core/clock.gd`:** `_requests` (`{id: {scale, serial}}`) is private. The public API is `request`, `is_active`, `clear`. The only caller today is the pogo hitstop, 75 ms on a real-time timer (`player.gd:244`). Story 1.2 promised "1.11 lists active Clock requests in an overlay".
- **`scripts/core/log.gd`**
  - Categories are lowercase StringNames (`save room input clock lurker weaver audio ui`).
  - `set_enabled(cats: Array[StringName])` **replaces** the set and **asserts** on an unknown category, so DevTools filters first.
  - `log.gd:7` already says categories stay off until DevTools reads `--log=`.
- **`scripts/core/game.gd` + `scripts/rules/settings.gd`**
  - `Settings.set_value()` asserts on an unknown key or a bad value. `_valid()` (`:77-79`) is strict on type: int ≠ float ≠ bool, and `2.0 in [0,1,2,3]` is false.
  - Once `load_settings()` arms writes, every `changed` queues one deferred write of the whole `to_dict()`.
  - `load_settings()` also queues a write itself when the file is missing or unclean.
  - `boot()`'s `from_dict()` overwrites every key.
  - `reset_for_tests()` disarms **and points `store.dir` back at `user://`** (`game.gd:86`). That is why `test_state` re-points the store at TMP straight after every reset (`test_state.gd:671-672`, `:690-691`).
  - Writes already stay off for a session whose file is unreadable or newer. That is the precedent D8 follows.
  - Current SCHEMA (`settings.gd:15-18`): `brightness` (int, 0–3, default 1) and `light_tap_window` (float, 0.12/0.2/0.3). There is no bool key yet.
- **`project.godot`:** `[input]` holds move_left/right/up/down, jump, attack, dash and light, in a one-line `Object(InputEventKey, …, "physical_keycode":88, …)` format. There are no function keys. Physics interpolation is on.
- **`tests/test_lint.gd`**
  - `dev_ref` (`:74-77`) is bare `\bDevTools\b` + code `res://(scripts|scenes)/dev/`, with `skip=["dev/"]` and `allow=[]`. `allow`/`skip` are **path-prefix** matches (`_rules_for` / `_under`, `:176-195`), so "exactly one line" needs new support.
  - The sample at `:339` (`var d = load("res://scripts/dev/dev_tools.gd").new()` in `world/world.gd`) **must keep firing**: it is not the sanctioned text.
  - `raw_input` (`:35-40`) allows only `actors/player_input.gd`, `core/devices.gd` and `ui/kit/`.
  - `layer_names()` (`:431-451`) already treats `dev` as an upper layer.
  - The header: "Fix the code, never the lint… never add an allow-list entry just to get green."
- **Source scans outside the lint:** `smoke_world.gd:345-357` scans raw text, **comments included**, for `randf` (only `camera_rig.gd` may contain it) and `KEY_F` / `reload_current_scene` (nowhere in `scripts/`). Never write those strings in a `dev/` file, not even in a comment.
- **Tests that build World,** and so get DevTools from now on (the editor binary is a debug build):
  - `smoke_world` (`:42`);
  - `smoke_room_swap` (`:41`, sets `start_room` before `add_child`);
  - `screenshot.gd` (`:26`, manual).

  Their `OS.get_cmdline_user_args()` are `["res://tests/<name>.gd"]`, plus `<out>` for the screenshot. `smoke_world` pins these:
  - UI's children are exactly `["Gutters","ScreenRouter"]` (`:118-119`);
  - RoomHolder has one Room (`:114`);
  - World's child count is unchanged across a bank popup (`:164-170`);
  - Game is not booted or armed (`:106-108`).

  It also pauses predators with `set_physics_process(false)` on group `predator` (`:46-50`).
- **The runner** (`tests/runner.gd:52-58`) fails on any non-warning error: `push_error`, `assert`, engine `ERROR:` and `SCRIPT ERROR`. **`push_warning` is allowed.** `run_tests.sh` can't pass per-test args, so tests inject them (D3). Args after the test path do reach `OS.get_cmdline_user_args()` when a test is run by hand (`runner.gd:11`).
- **StringName sorting:** `Array.sort()` on StringNames is pointer order, not alphabetical. `SlotState._sorted_ids()` (`slot_state.gd:138`) sorts them as Strings, and `test_state.gd:273` pins it.

### Decisions

These are story-author decisions; sonlm can veto any before dev. D6 (`--chain`) and D8 (`--set`) were put to sonlm as options and decided on 2026-11-19. Names in code sketches may change; record the final ones.

**D1: Two files and one class name.**
- `scripts/dev/dev_tools.gd`: `class_name DevTools`, `extends Node`. It holds the arg parsers, the registry, applying the args, the chain arming and reading the overlay key.
- `scripts/dev/overlays.gd`: **no `class_name`**. DevTools preloads it (`const Overlays := preload("overlays.gd")`), so `dev/` adds exactly one global name.
- No `.tscn`: nodes are built in code, so nothing under `scenes/dev/` or `.tres` exists, and release presets need exclude only `scripts/dev/*`.

The probe (Verified facts) showed that a release export with `scripts/dev/*` excluded boots clean, even though `DevTools` is in the global class cache. A bare `DevTools` identifier in `world.gd` breaks the release parse.

**D2: The hook line, first in `World._ready()` (as the architecture's snippet shows).**
```gdscript
func _ready() -> void:
	if OS.is_debug_build():
		add_child(load("res://scripts/dev/dev_tools.gd").new())  # path string, never preload: release exports exclude scripts/dev/
	add_to_group("world")
	…
```
- `add_child` from inside a parent's `_ready()` runs the child's `_ready()` synchronously (probed). So DevTools applies `--log`, `--set` and `--room` **before** `Game.boot()`, `_respawn_point()` and the first `_swap_room()`, and has `player_spawned` connected before the first emit.
- Being first means `--log` also covers anything boot logs (1.21's slot load).
- It works only because D8 makes `--set` survive `boot()`'s load. Don't move the line after `boot()` to "fix" a `--set` problem; fix D8.
- No null check on `load()`: only release presets exclude `scripts/dev/`, and there the branch never runs. A debug preset that excluded it would print `ERROR:` and fail on `.new()`.

**D3: Where args come from, and the test seam.**
- DevTools sets `name = "DevTools"` in `_init()`, so the name is set before it enters the tree. It holds `var tokens: PackedStringArray`, the args to apply. In `_ready()`:
  - if `get_tree().current_scene == get_parent()` (a real run, the same gate as `Game.boot()`; probed true from inside the main scene's `_ready`), it replaces `tokens` with the real source;
  - otherwise it keeps whatever was set, empty by default.
- So every existing test, where World is never the current scene, gets an inert DevTools.
- **Real source:** `OS.get_cmdline_user_args()` + `query_tokens(JavaScriptBridge.eval("window.location.search", true))` when that call returns a non-empty `String`.
  - `JavaScriptBridge` exists on every platform and returns `null` off the web with no error (probed in editor, debug and release templates).
  - So DevTools needs **no `OS.has_feature("web")` branch**, and the project-context rule ("only in boot, display, storage, quit, audio gate") holds as written.
  - On web, cmdline user args are empty (the default shell passes `[]`).
- **Test seam:** a smoke test connects World's `child_entered_tree` **before** `add_child(world)`. The handler, a method (not a lambda capturing state), sets `tokens` on the DevTools child. Probed: the signal fires before the child's `_ready()`.
  - The handler matches with `if node is DevTools:` (tests may name the class). The signal also fires for Darkness, RoomHolder, Camera, UI and every spawned Player, so ignore those.
  - Never read `res://tests/` from game code (`tests_ref`).

**D4: Grammar, registry and errors.**
- **Registry:**
  - One `const ARGS` dictionary in `dev_tools.gd`, `name → {help: String, apply: StringName, repeat: bool}`. `apply` is the method that applies the arg.
  - `repeat` is true only for `set` and `log`. Later stories add one row each (`glow` 1.12, `hp` 1.19, `difficulty` 1.22), single-valued.
  - Code outside `dev/` never registers anything, because it can't name DevTools (`dev_ref`).
  - Apply order in `_ready`: `log` → `set` → `room` → `chain`. `chain` (and later `hp`) arm on `player_spawned`; the rest act at once.
- **`parse(tokens: PackedStringArray, registry: Dictionary = ARGS) -> Dictionary`** (static, pure):
  - Tokens not starting with `--` are skipped.
  - `--name=value` splits on the first `=` only (`split("=", true, 1)`), so a value may contain `=`. `--name` alone has value `""`.
  - Returns `{values = {name: Array[String]}, errors = Array[String]}`.
  - An unknown name gives exactly `unknown arg --foo (known: chain, log, room, set)`.
  - For a `repeat` arg, `values[name]` keeps every value in order.
  - For any other arg given more than once, `values[name]` is `[last]`, and `errors` gets one entry, e.g. `--room given 2 times; using the last ('b')`.
- **`query_tokens(query: String) -> PackedStringArray`** (static, pure):
  - Trim a leading `?`, then `split("&", false)` (drops empty parts: `""`, `"?"`, `"a&&b&"`).
  - Split each part on the first `=` and `uri_decode()` both sides **after** splitting, so `%26`/`%3D` can't break the split. `+` decodes to a space.
  - Emit `--key=value`, or `--key` for a bare key.
  - Example: `?room=perf_worst&chain=5&set=brightness:0&log=lurker%2Cclock` gives `["--room=perf_worst","--chain=5","--set=brightness:0","--log=lurker,clock"]`.
- **Name lists are sorted as Strings.** Every "known: …" or "valid: …" list in a message (args, room ids, Log categories, settings keys) is built as a `PackedStringArray` and then `.sort()`ed, or with `sort_custom(func(a, b): return String(a) < String(b))`. `Array.sort()` on StringNames is pointer order (probe: `{room, chain, log, set}.keys().sort()` gives `chain, room, log, set`).
- **Validators are pure** (static, given the text plus whatever they check against) and return `[value, error]` or an error list, so `test_dev_args` inspects lists.
  - The impure apply step reports each error with `push_warning("DevTools: …")` and carries on.
  - Never call `Log.set_enabled`, `Settings.set_value`, `Game.override_setting` or `RoomLoader.load_room` with unvalidated input: they assert or `push_error`, and the runner fails on that.
- **Integers:** `is_valid_int()` and at most 4 characters, then `to_int()`.
  - `to_int()` is lax: `"8x"` → 8, `"x8"` → 8.
  - A 20-digit string passes `is_valid_int()`, but `to_int()` prints an engine `ERROR:` (probed; `room_loader.gd:21-23` caps digits for the same reason).
- **One summary line** when anything applied: `Log.info(Log.ROOM, "dev: …")`. AR55's category list is fixed, so there is no DEV category; adding one would break `test_log`'s exact list.

**D5: `--room=<id>`.**
- **New `RoomLoader` statics, which never `push_error`:**
  - `room_ids() -> Array[StringName]`: every id in the index (test roots included once added), **sorted as Strings**. Copy the keys into a `PackedStringArray`, `.sort()` it, then append each as `StringName` to the typed result.
  - `inspect(id: StringName) -> Dictionary`: returns `{known: bool, entries: Array[StringName], errors: Array[String]}`.
    - `known` is false for an id not in the index.
    - `errors` is `validate()`'s list for an invalid file.
    - `entries` is empty unless the file is valid. Then it holds `&"spawn"` if the grid has a `P`, plus each exit side, sorted as Strings, so m1_shaft gives exactly `[&"down", &"spawn", &"up"]`.
    - It reads the file through the existing pure `parse()`/`validate()`, so file reading stays in `room_loader.gd`.
- **DevTools picks the entry** by membership (`spawn`, else `up`, else `down`); it never relies on the order. Story 2.1's `weaver_test` "enters at its top entry". It warns when:
  - `known` is false: "no room 'x' (known: …)";
  - or `entries` is empty: "room 'x' is invalid: " plus the first 3 errors.
- **`World` gets `var start_entry: StringName = &"spawn"`.**
  - `_respawn_point()` uses it where it hard-codes `&"spawn"` today.
  - The fallback at `:117` compares `entry != start_entry` and retries `(start_room, start_entry)`.
  - DevTools sets `world.start_room` and `world.start_entry`. The fallback stays an `assert` for the real start room; DevTools has already validated, so it never reaches that path.
- **Respawns** come back to the `--room` room while `Game.dive` has no respawn point. DevTools never calls `DiveState.set_respawn()`: it is save data from 1.21. From 1.21, a loaded respawn point beats `--room` (ledger item 4).
- Update `world.gd`'s comments on `start_room` (`:26-27`) and on the fallback (`:118`).

**D6 (decided by sonlm, 2026-11-19: starts at take-off, as n pogo hits, every life): `--chain=<n>`.**
- **The problem:** a chain set at spawn dies on tick 1, because `player.gd:74-80` breaks it on every floor tick and every `P` stands on a floor.
- **Do:**
  - On every `player_spawned` (the first one and each respawn), DevTools arms `n` for that player.
  - On the first physics tick that **ends** with that player alive and `not is_on_floor()`, it calls `player.chain.add_hit()` n times and disarms.
  - Set `process_physics_priority` on DevTools to 100. Higher values run later, across the whole tree (probed), so DevTools ticks after the Player's `move_and_slide()`.
  - **Skip the check while `get_tree().paused`.** DevTools is `PROCESS_MODE_ALWAYS` (D9), so its physics tick still runs while paused. A player spawned while paused hasn't called `move_and_slide()` yet, and `is_on_floor()` is false until it does (probed). So read `is_on_floor()` only on ticks the player itself ran.
  - A grounded spawn arms and pays on take-off. An `up` spawn, already falling, pays on its first tick.
  - Hold the armed player only behind `is_instance_valid()`. Connect a method, not a lambda.
- **What it means:**
  - The state is exactly what n pogo hits leave: count n, held n(n+1)/2. `changed` fires n times, so `best_chain` = n and bloom and light update.
  - The first safe break (a landing, Snuff, cling grace, a knock or an exit) banks n(n+1)/2 into `Game.dive.carried`.
  - A snuffed take-off adds nothing, as for a real snuffed pogo.
  - No ChainState change and no pinned chain. A chain that can't break would break "land/Snuff in time always saves you" and hide the rules this tool exists to show.
- **The options sonlm weighed:**
  - start: at take-off (**chosen**), spawn falling at the top entry, or held while the arg is on;
  - embers: as n pogo hits (**chosen**) or light only, with a new `ChainState` method;
  - lives: every life (**chosen**) or the first spawn only.

**D7: `--log=<a>,<b>`.**
- Collect every `--log` value, split on `,`, `strip_edges().to_lower()`, and keep the names in `Log.CATEGORIES`.
- Each unknown name is a warning listing the valid ones.
- Then make one `Log.set_enabled(valid)` call, only if any `--log` was given. `set_enabled` replaces the set, so a no-arg run must not clear anything.

**D8 (decided by sonlm, 2026-11-19: save nothing): `--set=<key>:<value>` is session-only, and a `--set` session saves no settings at all.**
- **The validator** takes `schema: Dictionary = Settings.SCHEMA` as a parameter. It reads everything from that parameter, never from `Settings.SCHEMA` directly, so `test_dev_args` can pass a fake schema with a bool key.
- **Typing**, from `typeof(schema[key].default)`; the split is on the first `:`:
  - `TYPE_INT`: `is_valid_int()`, ≤ 4 chars, `to_int()`;
  - `TYPE_FLOAT`: `is_valid_float()`, `to_float()`. `"0.2"` and `"0.20"` give a float equal to `0.2`, and `"1"` gives `1.0`;
  - `TYPE_BOOL`: only `true`/`false` (1.16 adds bool keys);
  - anything else: "can't be set from the command line".
- Then check `Settings.is_valid(key, v, schema)`. The error lists every key in that schema with its choices, sorted as Strings.
- **`Settings.is_valid(key: StringName, v: Variant, schema: Dictionary = SCHEMA) -> bool`:**
  - It is public and `static`. It checks `schema.has(key)`, then `typeof(v) == typeof(schema[key].default)`, then `v in schema[key].choices`.
  - It replaces `_valid`, keeping the type check first.
  - `set_value()`, `from_dict()` and `Game.override_setting()` call it with two arguments, so they always check the real `SCHEMA`.
  - Probed: a const Dictionary default parameter compiles in a static func, and a fake key is valid only when its schema is passed.
- **`Game.override_setting(key, v)`:**
  ```gdscript
  var _overrides := {}  # StringName -> value: session-only values (DevTools' --set); none are ever saved

  func override_setting(key: StringName, v: Variant) -> void:
  	assert(Settings.is_valid(key, v), "Game.override_setting: %s is not valid for '%s'" % [v, key])
  	if _overrides.is_empty():
  		Log.info(Log.SAVE, "settings: overridden for this session; settings.json is not written")
  	_overrides[key] = v
  	_settings_armed = false  # a write already queued checks this and does nothing
  	settings.set_value(key, v)
  ```
  - `load_settings()`: after `from_dict()`, re-apply every override with `set_value`. While any override exists, return before arming. That covers both the missing-file write and a later write after another key changes.
  - `reset_for_tests()`: `_overrides.clear()`.
  - It names no `dev/` class (`core_layer`). The lint's `state_write` doesn't match `Game.override_setting(`.
- **Why not per key** (keep the rest saving, drop only overridden keys from the file): it means a merge in `_write_settings()` and more ways to leak. A dev session that saves nothing is simple and leak-proof, with a precedent: an unreadable or newer `settings.json` already makes the session write nothing.
- **Cost:** in a `--set` session, a change made in Options (1.36) isn't saved. sonlm chose this over per-key on 2026-11-19.
- `user://` is shared by editor runs and exports with the same project name, so a leak would reach the release builds sonlm plays. `test_state` (a)–(c) prove the leak paths closed in `Game`. `smoke_dev_tools`' `--set` case proves DevTools routes through `override_setting()` (D16 6, 7, 17).

**D9: Overlays: layout, input, drawing.**
- **Tree,** all under DevTools, which never parents to World, UI, RoomHolder or the room:
  - DevTools (`Node`, `name = "DevTools"`, `process_mode = PROCESS_MODE_ALWAYS`, `process_physics_priority` 100)
  - └ Overlays (`Node`, overlays.gd), with public `mode: int` (0 = off, 1–4) and `world: World` (set by DevTools)
  - &nbsp;&nbsp;├ WorldMarks (`Node2D`, `z_index` 100, `material` = **one static cached `CanvasItemMaterial` with `LIGHT_MODE_UNSHADED`**), drawing in world space on World's canvas
  - &nbsp;&nbsp;└ Screen (`CanvasLayer`, `layer` 11, above UI's 10 so it draws over the opaque gutters)
  - &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;└ ScreenMarks (`Node2D`), drawing in screen pixels (480×270)
- **Build the tree in DevTools' `_ready`**, never lazily.
- **Why:** a draw in World's canvas is darkened by the `Darkness` CanvasModulate (probed: white renders at 0.098 under a 0.1 modulate). `light_mask = 0` does **not** escape it. The unshaded material and a separate CanvasLayer both render full white (probed).
- **Physics interpolation:** WorldMarks never moves (identity transform), so it stays registered with the room tiles. Marks drawn at actors' tick positions can sit up to one tick (≈ 3.5 px at max fall) off the interpolated sprite. That is accepted for a dev overlay; write it in the docs. Never "fix" it by reading the engine camera or touching CameraRig (1.7 D8).
- **Key:**
  - In `DevTools._process`: `if Input.is_action_just_pressed(&"dev_overlay"): overlays.cycle()`. It is edge-triggered, so key echo can't cycle.
  - ALWAYS mode means it cycles while paused (probed: an ALWAYS node sees `just_pressed` with the tree paused).
  - `Input.action_press()` in tests triggers `is_action_just_pressed` but never `_unhandled_input` (probed), so poll; don't use input callbacks.
  - The `raw_input` lint allows `dev/` (D12).
- **Redraw:** while `mode != 0`, `queue_redraw()` both drawers in `_process`. Text that changes (FPS, the light count, Clock rows) is rebuilt at 4 Hz real time (`Time.get_ticks_msec()`), not per frame. Expose `last_refresh_ms`, the time of the latest rebuild. Mode 0 costs one `is_action_just_pressed` per frame.
- **Reading the world:**
  - DevTools passes World to Overlays (`overlays.world = get_parent()`). Overlays never calls `get_parent()` for World.
  - Each frame, read `world.play_rect()` and `world.current_room()`. Get the player as `get_tree().get_first_node_in_group("player")` and predators from group `predator`, read at draw time with `is_instance_valid`. Keep no references across frames.
  - Never use a `/root/` path (`root_path`).
- **Mode 1, play rect and gutters:**
  - World: the `play_rect()` outline (1 px), and `play_rect().grow(-Lurker.SCREEN_MARGIN)` dashed (where a lurker may notice).
  - Screen: both gutters, `Rect2(0, 0, CameraRig.GUTTER_WIDTH, h)` and `Rect2(CameraRig.GUTTER_WIDTH + CameraRig.PLAY_WIDTH, 0, CameraRig.GUTTER_WIDTH, h)`, outlined, with the usable band 1 px inside each (DESIGN `gutter-usable` 58 px). The gutters sit in screen space because the UI does; the play rect sits in world space because the game defines it there.
  - The two can drift by the camera shake `offset`, which `play_rect()` ignores by design.
- **Mode 2, light and notice:**
  - Player: a ring at `player.light_radius()`, labelled with the px value, and a ring at `light_radius() * Lurker.NOTICE_FACTOR`.
  - When `light_radius() < Lurker.NOTICE_MIN_RADIUS`, draw the reach ring dashed and dim with "below notice". This makes the 40 px base light visibly safe (Pillar 2).
  - Each predator (has `state`): its `State` name (`Lurker.State.keys()[state]`) next to it, and a line to the player while `senses(player)` is true.
  - Read the constants from `Lurker`, never copies. Story 1.20 moves them (ledger item 3).
- **Mode 3, exits and ids:** expose the item list it draws, for the test.
  - For each `room.exits`: mark the opening on its edge row at `col`, with the run of open cells found by `is_solid()` (the width isn't stored), labelled `up → <target>`.
  - Each entry (`spawn`, `up`, `down` that `has_entry`): a small cross at `entry_position()` with its name.
  - Each `room.objects` id: the id text at `cell_centre(cell)`.
- **Mode 4, readout** (screen, top-left; it's dev):
  - `FPS <Engine.get_frames_per_second()>`;
  - `lights <n>` (D10), exposed as a public count;
  - Clock rows, e.g. `hitstop ×0.05`.
  - **Sampling is separate from the text rebuild.** While mode 4 is on, `_process` calls `Game.clock.active()` **every frame** (a copy of a few entries, so it is cheap) and records `clock_seen[id] = {scale, ms}` for each live id.
    - Why: a 75 ms hitstop falls between two 250 ms rebuilds about 70% of the time, so sampling only at the rebuild would almost never show it.
    - A row is drawn normally while its id is live, greyed while `now - ms < 500`, and dropped after that. So nothing blinks faster than 2 Hz (≤ 3 flashes/s, NFR8).
    - Put the row rule in a static `clock_rows(seen: Dictionary, live: Dictionary, now_ms: int) -> Array`, with ids sorted as Strings. The public `clock_seen` and the row list are what the tests read.
  - Rows are a list, so 1.12 appends the worst frame and 1.23 the flares.
- **Colours and text:**
  - Never the reserved amber `#ffd27a` or the reserved red `#d9473f` (NFR9). Use, e.g., white rects, cyan player rings, magenta predators, green exits and entries, light grey ids.
  - Text uses `draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, colour)`. `pos` is the baseline, so add `font.get_ascent(8)` from a top edge.
  - Overlay text is dev-only, not player-facing: no `tr()`, no `strings.csv` keys.
  - Fusion Pixel arrives in 1.17; switching to it is optional then.
- Nothing pulses or blinks.

**D10: "On-screen `PointLight2D`" for the count.**
- Every `PointLight2D` under World, found with `world.find_children("*", "PointLight2D", true, false)`. `owned = false` is needed: the default skips code-built nodes (probed).
- A light counts when:
  - `is_visible_in_tree() and enabled and energy > 0.0 and texture != null`;
  - and its texture rect intersects `world.play_rect()` (AR20: on screen means the play rect, never the viewport). The rect is centred on `global_position + offset`, sized `texture.get_size() * texture_scale * global_scale`.
- Idle lurker glows have `energy == 0` and are hidden (`lurker.gd:117-118`), so they don't count. A glow counts only while its lurker telegraphs, hunts or returns, and only while it is on screen. At m1_shaft's spawn, all four lurkers (glow y ≥ 452) are also wholly below the play rect (y 0–270).
- Recount at the 4 Hz rebuild, only in mode 4 (`find_children` is slow).
- Put the per-light test in a static `counts_on_screen(light: PointLight2D, rect: Rect2) -> bool` that the test calls on stand-in lights.
- The engine itself culls lights against the whole 480×270 viewport, gutters included. Story 1.12 decides whether the ≤ 6 budget counts the play rect or the viewport, moves the rule into game code, and points the overlay at it (ledger item 2).

**D11: `Clock.active() -> Dictionary`.**
- Returns a **copy**, `{id: scale}`, of the active requests. Callers sort the ids as Strings for display.
- It is read-only: it never touches `Engine.time_scale` and never exposes `_requests`.
- `test_clock` cases:
  - empty at start;
  - after `request(&"hitstop", 0.05, 0.075)` it holds `{&"hitstop": 0.05}`;
  - a refresh shows the latest scale;
  - gone after expiry and after `clear()`;
  - mutating the returned dict changes nothing.

**D12: The lint.**
- **`dev_ref` exact-line exemption.**
  - The `dev_ref` row gains a field, e.g. `once = {"world/world.gd": ["if OS.is_debug_build():", "add_child(load(\"res://scripts/dev/dev_tools.gd\").new())"]}`, meaning guard text, then line text.
  - In `lint_text` (still pure), a `dev_ref` hit on a line is dropped when all of these hold:
    - the path has a `once` entry;
    - the line's `s.code.strip_edges()` equals the line text;
    - the previous non-blank code line's stripped code equals the guard;
    - the exemption hasn't been used yet in this text.
  - Every other hit fires. Read the field with `rule.get("once", {})`, since the other rows don't have it, or give every row an empty one; pick one and say which.
  - Comment text is already dropped, so the trailing `# path string…` doesn't matter.
- **SAMPLES** (multi-line text is fine: `lint_text` splits lines, and the harness counts this rule's hits):

  | Text | Path | Expected |
  |---|---|---|
  | guard + line | `world/world.gd` | quiet |
  | guard + line | `ui/gutters.gd` | fires |
  | line without guard | `world/world.gd` | fires |
  | guard + line, twice | `world/world.gd` | exactly 1 hit |
  | guard + `add_child(preload("res://scripts/dev/dev_tools.gd").new())` | `world/world.gd` | fires |
  | guard + `add_child(load("res://scripts/dev/overlays.gd").new())` | `world/world.gd` | fires |

  The existing `:338`/`:339` rows keep firing, and `:340-343` keep quiet.
- **`dev/` class names:**
  - `layer_names()` returns a `dev_ref` list: the `class_name` lines (and any autoload) under `dev/`.
  - `_rules_for()` already appends a run-time name list to any rule id in `names`. Keep the literal `\bDevTools\b` too.
  - Sample: hand-built `names.dev_ref = ["DevTools", "DevThing"]`, then `var t: DevThing` in `world/world.gd` fires.
  - Update `_test_layer_names`' expected arrays if you add a `dev/` sample source.
- **Tree checks** in `_test_tree`:
  - the real `world.gd` contains the exempt line exactly once, and lint hits for it are 0, so a stale exemption fails;
  - `names.dev_ref` contains `DevTools`, a sentinel showing `dev/` was walked.
- **`raw_input` allows `dev/`.** This is the rule's purpose, not a dodge:
  - the rule keeps gameplay on `PlayerInput` intents;
  - DevTools reads only its own `dev_*` action, ships in no release build, and must work while the player is dead, locked or absent;
  - the architecture says "`dev/` may touch anything".

  Sample: `if Input.is_action_just_pressed(&"dev_overlay"):` in `dev/dev_tools.gd` is quiet. The existing firing samples still fire. Update the comment on the row.
- `keycode` is unchanged: the key is bound in `project.godot`, never as a `KEY_*` in code. The lint never scans `.tscn` or `uid://` loads (header blind spots), so never reference `dev/` from a scene.

**D13: The `dev_overlay` action and "no function key".**
- **Name:** `dev_overlay`, snake_case, `dev_` prefixed so later binding lists can skip it.
- **project.godot entry:** append it after `light` in `[input]`, copying the `attack` entry text exactly, with `"physical_keycode":96` (backquote, `KEY_QUOTELEFT`), `"keycode":0`, `"device":-1` and no modifiers.
- **Test** (in `smoke_dev_tools`, where `KEY_*` constants are fine because tests aren't linted):
  - for every action in `InputMap.get_actions()` not starting with `ui_`, no `InputEventKey` has `keycode` or `physical_keycode` in `KEY_F1…KEY_F35` (a contiguous range; probed);
  - `dev_overlay` has exactly one event: an `InputEventKey` with `physical_keycode == KEY_QUOTELEFT` and no modifier.
  - Why skip `ui_*`: the engine's own `ui_filedialog_refresh` is bound to F5 in every runtime InputMap (probed).
- The action ships, inert, in release builds, because nothing there reads it. Every list of player actions built from `InputMap` must skip `dev_*` (and `ui_*`):
  - the Pause controls reference (1.34, UX-DR52) is the first such list;
  - then pad defaults and glyph tables (1.37);
  - then rebinding, reset to defaults and the clash rule (7.3).

  These are ledger items 5 and 6.

**D14: Tests.**

*`tests/test_dev_args.gd` (new, pure). Static calls only; no World or Game state is changed.*
- **`query_tokens`:**
  - `""`, `"?"` and `"&&"` give `[]`;
  - the D4 example;
  - `%2C`, `%3D` and `%26` inside a value;
  - `+` gives a space;
  - a bare key gives `--key`;
  - a repeated `set=` keeps its order.
- **`parse`:** cases pass a small hand-built registry, e.g. `{room = {help = "", apply = &"", repeat = false}, set = {help = "", apply = &"", repeat = true}}`, plus one case on the default `ARGS`.
  - a positional `res://tests/x.gd` is skipped;
  - an unknown arg on `ARGS` gives exactly `unknown arg --foo (known: chain, log, room, set)`;
  - `--room=a=b` keeps `a=b`;
  - `--chain` alone gives an empty value;
  - a repeated `--set` gives `values.set == ["a:1", "b:2"]` and no error;
  - a repeated `--room` gives `values.room == ["b"]` and exactly one error naming `--room`.
- **Chain values:** `"0"`, `"8"` and `str(ChainState.MAX_CHAIN)` are ok. `"-1"`, `str(MAX_CHAIN + 1)`, `"8x"`, `"x8"`, `""`, `"12345"` and a 20-digit string are errors. No `to_int()` on the 20-digit string; the 4-char cap catches it first.
- **Log names:** `"lurker,CLOCK"` gives both. `"nope"` gives an error listing the categories alphabetically. `""` gives nothing.
- **Set values.** The fake schema is `Settings.SCHEMA.duplicate(true)` plus `&"fake_bool": {default = false, choices = [false, true]}`.
  - `brightness:3` gives int 3; `brightness:3.0` and `brightness:7` are errors;
  - `light_tap_window:0.2` gives float 0.2, and `:0.25` is an error;
  - `fake_bool:true`/`false` gives a bool, and `fake_bool:1` is an error;
  - with the default schema, `fake_bool:true` is an unknown key;
  - an unknown key, and a missing `:`, are errors.
- **Room entry pick,** as a pure function of an `entries` list: `[spawn, down]` gives `spawn`; `[up, down]` gives `up`; `[down]` gives `down`; `[]` is an error.
- **`clock_rows`:**
  - an id that is live gives a normal row;
  - not live and last seen 499 ms ago gives a greyed row;
  - last seen 500 ms ago gives no row;
  - an empty `seen` gives `[]`;
  - two ids come out sorted as Strings.

*`tests/smoke_dev_tools.gd` (new, scene).*
- **Setup:**
  - `RoomLoader.add_root("res://tests/rooms")`, **once**. It recurses into `swap/` and `dev_tools/`; never also add one of its subfolders, or `_scan` calls `push_error` on duplicate ids.
  - Build World as `smoke_world` does, injecting tokens per D3.
  - At the start of **every** case, point `Game.store.dir` at `user://smoke_dev_tools_tmp`, since `reset_for_tests()` points it home.
  - End each case with `Game.reset_for_tests()`, `Log.set_enabled([])`, `get_tree().paused = false`, the actions released and World freed. Never keep two Worlds alive at once (two `world` / `player` group members).
- **The fixture `tests/rooms/dev_tools/t_dev_room.txt`:**
  - `P` on a ledge whose edge drops 3–5 rows onto a clean floor, with no `c`, `h` or `L`;
  - one `obj=` line;
  - an up exit and a down exit that target itself (as m1_shaft does), with the down hole away from the landing spot.

  It must pass `validate()`; adjust the layout until it does, keeping those properties. A starting point:
  ```
  ; Story 1.11 DevTools test room: P on a ledge with a short drop to a clean floor, no enemies,
  ; one persistent object, exits to itself. Not a level.
  id=t_dev_room
  zone=dusk
  exits=up:t_dev_room@x8, down:t_dev_room@x8
  obj=lamp_t_dev_room_1@5,7
  ---
  ########.#
  #........#
  #.P......#
  ####.....#
  #........#
  #........#
  #........#
  #........#
  ########.#
  ```
- **No tokens:**
  - a `DevTools` child exists, with `process_mode` ALWAYS;
  - the start room is m1_shaft at spawn, the chain is 0, no Log category is enabled, `Game.clock.active()` is empty, and the overlay mode is 0;
  - UI's children are unchanged, and RoomHolder holds one Room.
- **`--room=t_swap_a`:** the player starts at its `P`. **`--room=t_swap_b`:** no `P`, so it starts at the `up` entry, falling.
- **`--room=nope`:** m1_shaft loads, with a warning and no error. **`--room=bad_edge_hole`:** m1_shaft loads, with a warning. The runner staying green proves "no error".
- **`--chain=8` + `--room=t_dev_room`.** Use this fixture, not m1_shaft: m1_shaft's walk-off drops into the hoverer column, and a knock banks the chain in mid-air (probed 2026-11-19: about 100 ticks after take-off, with the landing about 315 ticks later). A "landed" check there passes for the wrong reason.
  - **(premise)** the player is on the floor after spawn. The chain is 0 and stays 0 for 10 standing ticks (armed, not lost).
  - Hold `move_right` until the first tick that ends off the floor, then release. On that tick the chain is 8, held is 36, and `best_chain` is 8.
  - Wait for `is_on_floor()` (cap 120 ticks). On the tick before, the chain is still 8, so no knock or other break happened in the air. `chain.banked` fires once, with 36, on the landing tick. After that the chain is 0, and `Game.dive.carried` went up by 36.
  - **Every life:** call `player.die()`, then wait out `World.RESPAWN_DELAY` until `player_spawned` gives the new player, picked by that signal, not by group index.
    - **(premise)** it is a different instance, standing at `P` with chain 0, and stays at 0 for 10 standing ticks.
    - Walk it off the same ledge: on its first airborne tick the chain is 8 and held is 36. This is the positive control; "chain 0 after respawn" alone would also pass if only the first spawn were armed.
- **`--chain=8` + `--room=t_swap_b`:** the chain is 8 on the first tick, and held is 36.
- **`--log=lurker,clock`:** `Log.enabled(Log.LURKER)` and `Log.enabled(Log.CLOCK)` are true, and `Log.enabled(Log.SAVE)` is false.
- **`--set=brightness:3`.** This copies the real-run order: DevTools applies before `boot()`. A test World never boots, so the test runs `boot()`'s load itself, and arms first; otherwise the file check can't fail.
  - **(setup)** In the temp folder, remove any leftover file, and write a clean `settings.json` from `Settings.new().to_dict()` with brightness 1. Call `Game.load_settings()`.
  - **(premise)** `Game._settings_armed` is true, and the file holds brightness 1.
  - Build World with `--set=brightness:3`.
  - `Game.settings.brightness == 3`, `Game._settings_armed == false`, and World's `Darkness.color` matches `AMBIENT_LEVELS[3]`.
  - Call `Game.load_settings()` again, which is what `boot()` does next in a real run. Brightness is still 3.
  - After 2 frames, the temp file still holds brightness 1 (parse it with `JSON.new().parse()`).
  - End with `Game.reset_for_tests()` and remove the temp file and folder.
- **Overlay:**
  - `Input.action_press(&"dev_overlay")` / release, with frames in between, five times gives modes 1, 2, 3, 4, 0;
  - with `get_tree().paused = true`, one press still cycles (unpause after);
  - WorldMarks' material is a `CanvasItemMaterial` with `LIGHT_MODE_UNSHADED`. Keep World 1's material, free World 1 and wait a frame, then build World 2: its material is the **same instance** (cached static);
  - the Screen CanvasLayer's `layer` is greater than UI's;
  - each mode draws without an error in one rendered frame;
  - the action check from D13 passes.
- **Clock rows in mode 4:**
  - wait until `last_refresh_ms` changes (a rebuild just happened);
  - call `Game.clock.request(&"hitstop", 0.05, 0.075)` and await one `process_frame`: `clock_seen` has `hitstop`;
  - await `get_tree().create_timer(0.3, true, false, true).timeout`. **(premise)** `Game.clock.is_active(&"hitstop")` is false. The overlay's row list holds `hitstop`, greyed.
  - end with `Game.clock.clear()`.
- **Lights:** `counts_on_screen()` on stand-in `PointLight2D`s. Add each under the test node (a node outside the tree is never `is_visible_in_tree()`), with `texture = preload("res://art/light.png")` and energy 1, then `queue_free()` it.
  - one inside the rect counts;
  - hidden, disabled, energy 0, no texture, or wholly outside: none count;
  - one straddling the edge counts.

  Then in m1_shaft at spawn, mode 4's count is 1, read from the overlay's public count after a rebuild. This is the player's light, which proves the `owned = false` search finds lights inside instanced scenes. The lurker glows are dark and off screen there, so this case doesn't test the filters; the stand-ins do.
- **Overlay 3 ids:** with `--room=t_dev_room` in mode 3, the item list holds the `obj=` id at its cell, both exits with their target, and the `spawn`, `up` and `down` entries.

*Additions to existing tests.*
- **`test_clock`:** the D11 cases.
- **`test_state`:**
  - `Settings.is_valid`:
    - a type mismatch, out of choices, and an unknown key are false; the defaults are true;
    - with a passed schema, a key the real `SCHEMA` lacks is true for a valid value and false for a wrong type;
    - the same key without the schema argument is false.
  - `Game.override_setting` cases go inside `_test_settings_file()`, after the "Tests that never load settings write nothing" case and **before the final `Game.boot()` block, which must stay last** (`test_state.gd:677-679`). There, the existing real-file snapshot and check (e) cover them.
    - Use the TMP store, `WriteCounter`, and `load_settings()` to arm.
    - **After every `Game.reset_for_tests()`, set `Game.store.dir = TMP` again** before any `load_settings()`, `set_value()` or await. Otherwise the load reads the real `user://settings.json`, and a write in (d) or in a D16 #7 mutant lands there.
    - A clean file must hold every SCHEMA key, or `from_dict()` returns false and `load_settings()` queues a rewrite. Write it from `Settings.new().to_dict()`, never a brightness-only literal, so 1.16's keys don't break it.
    - The cases:
      - (a) delete the temp file, override, then `load_settings()`: the value is kept, and after 2 frames there is no file and 0 writes;
      - (b) reset, re-point, write a clean file, `load_settings()` (armed). Override `brightness`, then `set_value(&"light_tap_window", 0.2)`. After 2 frames there are 0 writes and the file is unchanged;
      - (c) reset, re-point, write a clean file holding brightness 0, override 3, then `load_settings()`: brightness is 3, and the file still holds 0;
      - (d) the control: reset, re-point, write a clean file, `load_settings()`, `set_value()` of a key. After a frame there is exactly 1 write, in TMP;
      - (e) the real `user://settings.json` is untouched (the existing final check).
    - End with `Game.reset_for_tests()` and re-point to TMP before the `boot()` block, so `boot()`'s load re-applies no override.
- **`test_room_loader`:** call `RoomLoader.add_root("res://tests/rooms")` once.
  - **(premise)** a plain `.sort()` on `[&"t_swap_b", &"m1_shaft", &"t_swap_a"]` is **not** alphabetical. If this premise ever fails, the engine changed and the String sort is no longer needed.
  - `room_ids()` holds `m1_shaft`, `t_swap_a` and `t_swap_b`, and is alphabetical: check `String(ids[i]) < String(ids[i + 1])` for every pair. Never compare it against a `.sort()`ed copy, which is pointer order too and passes vacuously.
  - `inspect(&"m1_shaft")` gives `known` true, `entries == [&"down", &"spawn", &"up"]` exactly, and no errors.
  - `inspect(&"t_swap_b").entries == [&"up"]`.
  - `inspect(&"nope")` gives `known` false.
  - `inspect(&"bad_edge_hole")` gives `known` true, empty `entries` and non-empty `errors`, with no `push_error` (the runner proves it).
- **`test_lint`:** the D12 samples and tree checks.

**D15: Docs and ledger.**
- **`docs/development-guide.md`:**
  - "Run the Game" (`:28`): drop "no debug hotkeys until DevTools".
  - Add the args (`--room`, `--chain`, `--log`, `--set`; `?…` on web debug), how to pass them, and the backquote overlay cycle.
    - From a terminal: `godot --path game -- --room=m1_shaft --chain=8`.
    - In the editor: Debug → Customize Run Instances, per-instance arguments, stored in `.godot/`. **Never** Project Settings `editor/run/main_run_args`, which is written into the committed `project.godot`.
  - The test list: the two new files.
  - The lint table: `dev_ref` becomes "the one guarded line in world.gd + dev/ class names"; `raw_input` gains `dev/`.
  - Common Tasks: "add a DevTools arg" (one `ARGS` row with `help`, `apply`, `repeat` + a validator + `test_dev_args` cases).
- **`docs/architecture.md`:**
  - the tree diagram (DevTools under World, debug builds only);
  - the brightness row (`:94`) and the Input gaps row (`:238`): "`--set=brightness:N`, session only, until Options (1.36)";
  - Component Overview;
  - Testing Strategy rows and "Last run" (17 tests);
  - a variances paragraph for the `raw_input` `dev/` allowance and the `dev_ref` line rule.
- **`docs/component-inventory.md`:**
  - a new Dev tools section (`dev_tools.gd`, `overlays.gd`);
  - the World row (`start_entry`, the DevTools child);
  - the Core rows (`Clock.active`, `Game.override_setting`), and `Settings.is_valid`;
  - RoomLoader (`room_ids`, `inspect`);
  - Input Actions (`dev_overlay`, debug only; still no function keys);
  - Test Components.
- **`docs/source-tree-analysis.md`:** `scripts/dev/`, the new tests and `tests/rooms/dev_tools/`.
- **`docs/index.md` and `docs/project-overview.md`:** run notes and Last Updated. `project-overview.md:39` still says "debug HUD"; fix it.
- **`game/README.md`:**
  - Controls: "`` ` `` (debug builds): cycle overlays";
  - drop the `:26` note that brightness can't change;
  - the Tests list (`:33-47`): add `test_dev_args.gd` and `smoke_dev_tools.gd`, plus a one-line run-with-args note.
- **`docs/rooms.md`:** one line, "start any room with `-- --room=<id>`".
- **`_bmad-output/project-context.md`:**
  - Current State: append a 1.11 sentence;
  - Engine-Specific / Code Organization: the `raw_input` `dev/` allowance;
  - Testing Rules, the lint sentence: "no raw `Input` outside `PlayerInput`/UI kit/`dev/`";
  - the "Nothing outside `dev/`…" sentence: "(the lint checks the one guarded line and `dev/` class names)";
  - Last Updated.
- **`_bmad-output/game-architecture.md`:**
  - Debug Tools (≈ `:608-629`):
    - drop the stale "F1–F3 … removed when E1 touches `shaft.gd`" sentence (done in 1.7);
    - change the entry-arg example to `--room=weaver_test` (E2's dev arena, Story 2.1; `weaver_arena` stays E4's final room);
    - add `--set` (session-only, no file write) and the arg phases;
    - Args source: "the URL query through `JavaScriptBridge.eval`, no `has_feature` branch".
  - Enforcement (≈ `:646-653`): `raw_input` allows `dev/`, and `dev_ref`'s exact line.
  - Settings persistence (≈ `:374`) and the Configuration "Player settings" row: "a DevTools `--set` session overrides values in memory and writes no settings.json".
- **Ledger** (`implementation-artifacts/deferred-work.md`): add each item under a 1.11 heading, with its `→ **Owner: …** — why` line. Name all eight in your report.
  1. "`--chain` starts at take-off and ends on its first break; `perf_worst`'s 60 s run needs the light held at chain 20" → **Owner: Story 1.12**.
  2. "Overlay 4's on-screen light count (play rect) lives in `dev/`; the ≤ 6 budget needs the same rule in game code" → **Owner: Story 1.12**.
  3. "Overlay 2 reads `Lurker.NOTICE_MIN_RADIUS` / `NOTICE_FACTOR` / `SCREEN_MARGIN`. When they move into `rules/sensing.gd`, `overlays.gd` must move in the same change, or every debug run fails to compile. It also gains sense/stir rings, plus a radius ring for every `light_source` (player, flare, cache), not only the player" → **Owner: Story 1.20**.
  4. "From 1.21 a loaded respawn point beats `--room`, and a dev session (`--room`, `--chain`) records dev room visits and `best_chain` into the slot" → **Owner: Story 1.21**.
  5. "`dev_overlay` ships, inert, in release builds, so a list of player actions read from `InputMap` would show it. Build one filter for player actions (it skips `dev_*` and `ui_*`) together with the controls reference, with a test that it never lists `dev_overlay`. 1.37's pad defaults and glyph tables use the same filter" → **Owner: Story 1.34** — the Pause controls reference (UX-DR52) is the first screen that lists bindings.
  6. "Rebinding and reset to defaults offer only the actions from that filter, and the clash rule ignores `dev_*` actions" → **Owner: Story 7.3** — rebinding (FR33, AR35) doesn't exist until E7.
  7. "Overlay 3 draws only the `spawn`/`up`/`down` entries. When anchors and stations become entries (`room.gd:45`), add them to overlay 3's item list and its smoke case" → **Owner: Story 1.24** — it extends `entry_position()`.
  8. "When the title and web gate land as boot screens, a run with `--room` / `?room=` must still start straight in that room (1.12's perf run, 1.13's Playwright `?room=perf_worst`, 2.12's `?room=weaver_test`). World must stay the main scene, so DevTools' `current_scene == get_parent()` gate still fires. 1.33 decides whether the web gate still shows (it unlocks audio)" → **Owner: Story 1.33** — it adds the screens shown at boot.

**D16: Red checks** (break, see the named check fail, revert; record each with the failing line).
1. **Exact line:** in `world.gd`, `load` → `preload`. `dev_ref` fires and the tree check fails.
2. **Exact line, guard:** move the line out of the `if`. `dev_ref` fires.
3. **Exact line, once:** duplicate it under a second guard. One `dev_ref` hit.
4. **Stale exemption:** change the line's path text in the exemption only. The tree check "exactly once" fails.
5. **raw_input:** drop `dev/` from `allow`. The lint fails on `dev/dev_tools.gd`.
6. **`--set` load leak:** delete the "re-apply overrides" loop in `load_settings()`. `test_state` (c) fails.
7. **`--set` arm leak:** delete the "don't arm while overrides" return. `test_state` (a) or (b) fails with a write, in TMP, because the cases re-point the store.
8. **`--chain` at spawn:** apply on `player_spawned` instead of take-off. The `t_dev_room` "8 on the first airborne tick" check fails (chain 0).
9. **`--chain` every life:** arm only on the first `player_spawned`. The respawned player's "8 on its first airborne tick" check fails.
10. **`--room` P-less:** force entry `spawn`. The smoke `t_swap_b` case fails (a named FAIL after a `push_error`; record both).
11. **Inert in tests:** drop the `current_scene` gate in `DevTools._ready()`, so it always reads the real source. Then run both of these by hand:
    - `godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_world.gd --chain=3`. `test_bottom_loop`'s "…with the chain of 3 banked first: carried +6" check (`smoke_world.gd:313`) fails with carried +21. When the test moves the player into the floor hole, DevTools pays 3 more links on the first airborne tick. The `best_chain` checks (`:140`, `:144`, `:204`) stay green: the player stands at each one. Don't use them as the signal.
    - `… -- res://tests/smoke_dev_tools.gd --log=save`. The "No tokens" case's "no Log category is enabled" check fails.

    Record both FAIL lines, restore, and check that `git diff` is clean on `dev_tools.gd`.
12. **Process mode:** make DevTools pausable. The paused-cycle check fails.
13. **Unshaded:** drop the material. The material check fails.
14. **Clock copy:** return `_requests` itself. The "mutating the copy" case fails.
15. **Query decode:** drop `uri_decode()`. The `%2C` case fails.
16. **Function key:** temporarily add an F2 event to `dev_overlay` in `game/project.godot` and run `smoke_dev_tools`. Both "no F-key" and "exactly one event" fail. Restore with `git checkout game/project.godot`, and check that `git diff` is clean.
17. **Light count:** drop `is_visible_in_tree()` from `counts_on_screen()`. The stand-in "hidden" case fails. The m1_shaft count stays 1, because idle glows have energy 0 and lie below the play rect, so that case doesn't test this filter.
18. **`--set` wiring:** two breaks, each recorded with its failing line.
    - In `dev_tools.gd`, apply `--set` with `Game.settings.set_value()` instead of `Game.override_setting()`. The smoke's checks fail: `_settings_armed` stays true, and brightness is 1 after the second `load_settings()`. (`state_write` doesn't catch this: `test_lint.gd:358` keeps `set_value` quiet.)
    - Separately, delete `_settings_armed = false` from `override_setting()`. The smoke's `_settings_armed == false` check fails, alongside `test_state` (b).
19. **String sort:** in `room_ids()`, sort the StringName array with `.sort()`. The `test_room_loader` pairwise check fails.
20. **Clock sampling:** move the `active()` call inside the 4 Hz rebuild. The smoke check "seen one frame after the request" fails, because the request lands right after a rebuild.

### Verified facts (probes 2026-11-19, Godot 4.7.2.stable.official.ed1daf0bf)

- Inside a `run_tests.sh` test, `OS.get_cmdline_user_args()` is exactly `["res://tests/<name>.gd"]`, plus `<out>` for screenshot.gd. `OS.is_debug_build()` is true: the editor binary has features `editor` and `debug`. Args after the test path reach the test when it is run by hand. The runner also loads a test script by absolute path, outside the repo.
- Exported templates:
  - `OS.get_cmdline_user_args()` returns everything after `--` in debug and release templates too.
  - A release export with `exclude_filter="scripts/dev/*"` and the path-string `load()` inside `if OS.is_debug_build()` boots clean, even with `class_name DevTools`.
  - A bare `DevTools` identifier in `world.gd`, even under `if false:`, fails the release parse (`Identifier "DevTools" not declared`).
  - A debug export without `scripts/dev/` prints two `ERROR:` lines, and `load()` returns null.
- `JavaScriptBridge.eval(...)` returns `null` with no error in the editor and in debug and release Linux templates. On web, `eval("window.location.search", true)` returns the query `String` (from the engine source, not run here: no web templates).
- Adding a child inside a parent's `_ready()`:
  - `add_child()` runs the child's `_enter_tree` and `_ready` before it returns;
  - the parent's `child_entered_tree` fires **before** the child's `_ready()`, so a handler can set the child's vars, though `name` still reads `@Node@N` unless set in `_init()`;
  - in a main-scene run, `get_tree().current_scene == parent` holds inside that child's `_ready()`.
- A `CharacterBody2D` reports `is_on_floor() == false` until its first `move_and_slide()`, even after a physics frame without one.
- `process_physics_priority`: a higher value runs later, across the whole tree. The tick order was `[-5, 0, 100]`, even with the priority-100 node first in the tree.
- `Input.is_action_just_pressed()` on an action missing from the InputMap prints `ERROR: The InputMap action … doesn't exist`, which fails the runner. So the action must be in `project.godot`.
- `Input.action_press()` triggers `is_action_just_pressed` (true that frame, false the next) but never `_unhandled_input`. A `PROCESS_MODE_ALWAYS` node sees `just_pressed` while `SceneTree.paused`; a pausable node runs no frames.
- Rendering, GL Compatibility, xvfb, CanvasModulate 0.1:
  - a default draw renders at 0.098;
  - `CanvasItemMaterial.LIGHT_MODE_UNSHADED` renders at 1.0;
  - `light_mask = 0` renders at 0.098;
  - a child under a CanvasLayer renders at 1.0;
  - a child without `use_parent_material` does not inherit an unshaded parent's material.
- String parsing:
  - `"a%20b+c%2Cd".uri_decode()` gives `"a b c,d"`.
  - `"".split("&", false)` gives `[]`, and `"k=v=w".split("=", true, 1)` gives `["k","v=w"]`.
  - `"8x".to_int()` gives 8, and `"x8".to_int()` gives 8.
  - A 20-digit integer string passes `is_valid_int()`, but `to_int()` prints an engine `ERROR:`.
  - `"0.2".to_float() in [0.12, 0.2, 0.3]` is true; `2.0 in [0,1,2,3]` is false.
- `Array.sort()` on StringNames (typed, untyped, or `Dictionary.keys()`) is pointer order, not alphabetical. Sort them as Strings.
- A `static func` may take a const Dictionary as a default parameter (`schema: Dictionary = SCHEMA`).
- `Engine.get_frames_per_second()` updates about once a second. No `Performance` monitor counts 2D lights.
- Finding and testing lights:
  - `find_children("*", "PointLight2D", true, false)`: the default `owned = true` skips code-built nodes.
  - A `PointLight2D.new()` outside the tree is never `is_visible_in_tree()`.
- `push_warning` prints `WARNING:`. The runner ignores it, and `run_tests.sh` doesn't show it.
- Input map:
  - The runtime InputMap includes the engine's `ui_filedialog_refresh` (F5) and `ui_swap_input_direction` (Ctrl+`).
  - `KEY_F1…KEY_F35` are contiguous.
  - In `project.godot`, a hand-written action with `"physical_keycode":96` loads as one `InputEventKey` (physical 96, keycode 0, device −1).
- **m1_shaft walk-off.** Walking right off m1_shaft's spawn ledge at chain 8 ends in a hoverer knock in mid-air: about 100–150 ticks after take-off, holding or releasing →. The knock banks the 36, and the landing comes hundreds of ticks later. t_swap_a's walker also knocks before any landing.

### Project Structure Notes

- **New:**
  - `game/scripts/dev/dev_tools.gd` and `game/scripts/dev/overlays.gd`;
  - `game/tests/test_dev_args.gd` and `game/tests/smoke_dev_tools.gd`;
  - `game/tests/rooms/dev_tools/t_dev_room.txt`.

  Each `.gd` comes with its `.gd.uid`, staged. `scripts/dev/` is a new folder (AR58 already reserves it).
- **Changed game code:**
  - `scripts/world/world.gd` (hook line, `start_entry`, comments);
  - `scripts/world/room_loader.gd` (`room_ids`, `inspect`);
  - `scripts/rules/settings.gd` (`is_valid`);
  - `scripts/core/game.gd` (`override_setting`, load and reset);
  - `scripts/core/clock.gd` (`active`);
  - `game/project.godot` (`dev_overlay`).
- **Changed tests:** `test_lint.gd`, `test_clock.gd`, `test_state.gd`, `test_room_loader.gd`. `screenshot.gd` is unchanged: Task 8's shots use a scratch script outside the repo.
- **No `.tscn`** for DevTools or its overlays, and none under `scenes/dev/`.
- `core/` stays below the scene layers: `game.gd` and `clock.gd` gain no reference to `dev/`, `world/` or any upper class (`core_layer`).
- The fixture room lives under `tests/rooms/dev_tools/`, never `rooms/dev/`: release exports drop `tests/*`, and `rooms/dev/` is for real dev rooms such as 1.12's `perf_worst`. `smoke_rooms` walks only `res://rooms/**`, so the fixture isn't swept.

### Project Context Rules (that apply here)

- Debug tools live only in `dev/`, are added only when `OS.is_debug_build()`, and nothing debug ships in release. Nothing outside `dev/` and `tests/` references `dev/`, except `world.gd`'s one path-string `load()`.
- No function keys or raw keycodes. Input goes through actions with physical keycodes, one button per action, no chords.
- `OS.has_feature("web")` only in boot, `core/display.gd`, the storage check, the quit button and the audio gate. D3 needs none.
- State lives in pure objects and is written only through rule methods: `ChainState.add_hit()`, `Settings.set_value()`, `Game.override_setting()`. Never assign `Game.settings.x` (`state_write`). `Game` keeps the same instances (never replace them).
- "On screen" means `World.play_rect()`, never the viewport. Physics interpolation is on: move gameplay nodes only in `_physics_process`; WorldMarks never moves.
- Things that must read in the dark use `LIGHT_MODE_UNSHADED`. Cache materials as statics, never one per effect.
- No logging in hot paths unless guarded. No bare `print`: use `Log`. Never `free()`; connect methods, not capturing lambdas.
- Errors: programmer errors `assert`; pure validators return lists. Here, bad dev args are `push_warning`, so the runner tolerates them and the game starts.
- ≤ 3 flashes/s anywhere, and the reserved amber and red are never used for anything else.
- Tests: `tests/test_*.gd` / `tests/smoke_*.gd` (globbed), `extends Node`, `run()`, `ok`/`FAIL` lines, then `PASS`/`FAILED`. Pick targets by position, or by the signal that produced them. Tests never touch the real `user://settings.json`. Report "tests green; needs a look on the laptop", never "works".
- Every deferred item gets an owner line written by the agent that defers it (D15). Comments explain *why*, citing the design ("AR54: …", "Pillar 2: …").

### Previous story intelligence (1.7–1.10 and their reviews)

- **Red-check every new check** (1.8, 1.9, 1.10 reviews found vacuous ones). Each pure function needs a firing sample and a near-miss. Keep premise, verdict and positive control as separate checks (1.10 review: the off-screen verdict had no on-screen control). This story's own review caught three checks that couldn't fail: the m1_shaft landing, the unarmed `--set` file check, and the respawn re-arm. D14 now gives each a premise or a positive control.
- **Named FAILs, never engine errors.** 1.10's review caught a P-less room asserting in `entry_position()`, which is why D5 validates before World builds.
- **Guarantees compare against `Spec`, never the tuning under test.** D14 pins numbers from the design (60/360 px, `MAX_CHAIN`), never reads them back from the code under test where the design gives them.
- **Docs drift** (every review): update every row D15 lists, the dates and "Last run", and count tests exactly. **Record every deviation** from these Dev Notes in the Completion Notes.
- Don't add `project-context.md` rules beyond D15 without proposing them (1.10 review).
- **Probed engine facts** live in "Verified facts". Use them instead of re-deriving them.
- **The baseline** is `== ALL GREEN (15 tests)` in about 1 m 40 s:

  | Test | `ok` lines |
  |---|---|
  | test_chain_state | 0 (prints "ALL PASS (69 checks)") |
  | test_clock | 15 |
  | test_deferred_owners | 25 |
  | test_lint | 162 |
  | test_log | 7 |
  | test_room_loader | 72 |
  | test_room_sweep | 74 |
  | test_state | 165 |
  | test_tuning | 87 |
  | smoke_bot | 6 |
  | smoke_moves | 17 |
  | smoke_player_input | 59 |
  | smoke_room_swap | 39 |
  | smoke_rooms | 90 |
  | smoke_world | 60 |

### Git intelligence

- **Recent commits** (`feat/m2-e1`, no remote):
  - `75055f3` docs (1.10 review record + laptop check);
  - `f897eb2` test (1.10 review fixes);
  - `cada033` docs (1.10 dev record);
  - `ec075f8` test (the 1.10 code);
  - `7d4cb14` content (the `m1_shaft` walker).
- **Each story commits in this order:**
  1. `docs: story 1.N file, ready for dev`;
  2. `feat:`/`test:` code;
  3. `docs:` (docs + dev record, status review);
  4. review fixes;
  5. `docs:` review record and status done.
- **Prefixes:** `feat:` game code, `test:` tests only, `content:` rooms, `docs:`, `refactor:`.
- **Messages** have a prose body and end with the Co-Authored-By and Claude-Session lines.
- sonlm asks for commits explicitly. Commit when asked.

### Latest tech notes (Godot 4.7.2)

- `OS.get_cmdline_user_args() -> PackedStringArray` returns the args after `--` (or `++`). The editor appends its run args verbatim, so the developer must type the `--`.
- `JavaScriptBridge.eval(code: String, use_global_execution_context := false) -> Variant`: a stub returning `null` off the web. On web, a JS string comes back as `String`.
- `String.uri_decode()` (`+` becomes a space), `is_valid_int()`, `is_valid_float()`, `split(delim, allow_empty, maxsplit)`.
- `Engine.get_frames_per_second()` and `Performance.get_monitor(Performance.TIME_FPS)` return the same value, updated each second.
- `CanvasItem.draw_rect / draw_circle(pos, r, color, filled := true, width := -1.0, antialiased := false) / draw_arc / draw_dashed_line / draw_string(font, pos, text, align, width, font_size, modulate)`. `ThemeDB.fallback_font` is Open Sans, antialiased; size 8 gives ascent 9, height 12.
- `Node.find_children(pattern, type, recursive := true, owned := true)`.
- `Node.process_physics_priority`: higher runs later; default 0. `PROCESS_MODE_ALWAYS` = 3.
- Physics interpolation: `_draw` content is not interpolated, only transforms. 2D has no `get_global_transform_interpolated()`.
- Context7 needs `/mcp` auth (not available to subagents). The facts above come from the 4.7.2 class XML and local probes.

### Cross-story context (Epic 1 and beyond)

- **1.12** adds `--glow` (`?glow=`) and the worst-frame row in overlay 4, builds `perf_worst`, decides how its run holds chain 20 and how the light count rule is shared (ledger items 1–2), and fixes `Fx._unshaded()`.
- **1.13** builds the presets: release presets exclude `scripts/dev/*`, debug presets keep it (D2: no null check on the `load()`). It adds `SMOKE boot ok` (through `Log`, since the `print` lint allows only `core/log.gd`; the runner skips lines starting with `[`), the release-PCK check, and the Playwright boot with `?room=perf_worst`. The query path first runs on web there.
- **1.14:** the backquote key must not act on the page.
- **1.16 and 1.36:** new bool settings (`reduce_flashing`, `shake`, `reduced_motion`) are set with `--set` until Options. D8's bool typing exists for them.
- **1.19:** `--hp=<n>`, armed per life like `--chain`.
- **1.20:** overlay 2 moves onto `Sensing` and gains a ring per light source (ledger item 3).
- **1.21:** the respawn point and slot writes versus dev sessions (ledger item 4).
- **1.22:** `--difficulty=easy|normal|hard`, through a `SlotState` rule method, session-only like `--set`. Its AC owns that.
- **1.23:** flares appear in the light count automatically.
- **1.24:** anchor and station ids show in overlay 3 on their own; their entries need ledger item 7.
- **1.33:** `--room` must still skip the title and web gate (ledger item 8).
- **1.34 / 1.37 / 7.3:** binding lists skip `dev_*` actions through one shared filter (ledger items 5–6).
- **2.1:** `--room=weaver_test` enters at the top entry, via D5's `up` rule. **2.12:** a debug web build at `?room=weaver_test` "with the overlays off": they start off.
- **4.9:** `m1_shaft` moves to `rooms/dev/`. `--room=m1_shaft` still works, because the index walks `rooms/**`.

### References

- `epics.md`:
  - Story 1.11 (≈ `:1603`);
  - AR48 (≈ `:278`), AR53–AR55 (≈ `:286-291`), AR8 (≈ `:208`), AR20 (≈ `:226`), AR46 (≈ `:273`);
  - NFR8–NFR9, NFR16;
  - UX-DR18, UX-DR52, UX-DR76, UX-DR122–UX-DR123;
  - Stories 1.12, 1.13, 1.16, 1.19, 1.22, 1.23, 1.24, 1.33, 1.34, 2.1, 2.12, 7.3 (forward hooks).
- `game-architecture.md`:
  - Debug Tools (≈ `:608-629`);
  - Enforcement (≈ `:644-656`);
  - Project Structure (≈ `:746-748`, `:817`);
  - layer rules (≈ `:862-874`);
  - Configuration (≈ `:577`) and Consistency Rules (≈ `:1291`, the web branch);
  - Settings persistence (≈ `:374`).
- `project-context.md`: Engine-Specific Rules, Code Organization (`dev/`), Platform & Build (no function keys, web branch, saves), Testing Rules.
- **UX:** `DESIGN.md` (≈ `:93-95`: gutter 60, usable 58, play 360); `EXPERIENCE.md` (≈ `:132-161`: bindings, web keys, debug keys).
- **Prior stories:**
  - `1-2-…md` (≈ `:146`, `:223`, `:240-242`, `:342`): `--log`, Clock in the overlay;
  - `1-4-…md` (≈ `:658-660`): `--set` must bypass the armed write;
  - `1-6-…md` (≈ `:382`): overlay 1;
  - `1-7-…md` (≈ `:237`, `:559`): `start_room`, brightness;
  - `1-9-…md` (≈ `:115`, `:191`): `dev_ref`;
  - `1-10-…md` (≈ `:296`, `:410`): arrival from below, "any entry".
- **Code:**
  - `game/scripts/world/world.gd`, `camera_rig.gd`, `room.gd`, `room_loader.gd`;
  - `game/scripts/actors/player.gd`, `lurker.gd`;
  - `game/scripts/rules/chain_state.gd`, `settings.gd`, `slot_state.gd` (`_sorted_ids`);
  - `game/scripts/core/game.gd`, `clock.gd`, `log.gd`;
  - `game/project.godot`, `game/scenes/world/world.tscn`;
  - `game/tests/test_lint.gd`, `runner.gd`, `smoke_world.gd`, `smoke_room_swap.gd`, `test_state.gd`, `test_clock.gd`, `test_room_loader.gd`.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), gds-dev-story, 2026-11-19. The red checks and the doc edits ran as one workflow (5 red-check agents, each in its own copy of `game/`; 3 doc agents on disjoint files); every result and doc diff was reviewed here.

### Debug Log References

- **Baseline** `65849f1`: `./run_tests.sh` → `== ALL GREEN (15 tests)`, 878 `ok`, 1 m 41 s; the per-test counts matched "Previous story intelligence" exactly.
- **Final:** `== ALL GREEN (17 tests)`, 1065 `ok`, 1 m 47 s, no `SCRIPT ERROR` / `ERROR:` lines. The only extra output is `at: push_warning` traces, as in the baseline (9 there): `smoke_dev_tools`' four deliberate bad-arg warnings bring it to 13.
- **`ok` counts, test by test (before → after):** `test_lint` 162 → 176, `test_clock` 15 → 21, `test_room_loader` 72 → 80, `test_state` 165 → 180; new `test_dev_args` 71, `smoke_dev_tools` 73. Unchanged: `test_chain_state` (ALL PASS, 69 checks), `test_deferred_owners` 25, `test_log` 7, `test_room_sweep` 74, `test_tuning` 87, `smoke_bot` 6, `smoke_moves` 17, `smoke_player_input` 59, `smoke_room_swap` 39, `smoke_rooms` 90, `smoke_world` 60.
- **First runs:** `test_lint` and `smoke_world` passed with DevTools in the tree on the first run; `test_dev_args` needed two fixes before its first run (a `Dictionary.set` method shadows `ARGS.set` dot access, so the tests index `ARGS["set"]`; the row check reads the script's method list instead of instancing a node). `smoke_dev_tools` passed its first full run (69); its `t_dev_room` walk-off took off, paid 8 / 36 and landed with the chain still 8, as D14 predicted.
- **Task 8 screenshots** (xvfb, brightness 0, scratch script outside the repo, `Game.reset_for_tests()` at the end; 6 shots: modes 1–4, mode 2 at chain 10 by a telegraphing lurker, mode 3 in `t_dev_room`). Every mode reads at brightness 0: mode 1's play rect, dashed notice rect and both gutters with their usable bands; mode 2's 40 px ring with the dashed, dim reach ring ("below notice"), and at chain 10 the 109 / 175 px rings, `TELEGRAPH` and the magenta sense line; mode 3's exits, entries and the `lamp_t_dev_room_1` id; mode 4's `FPS 30`, `lights 1` and a greyed `hitstop ×0.05`. **The first pass showed two layout faults**, fixed in `overlays.gd` and re-shot: mode 2's reach label and the lurker's state label sat under the gutters, and mode 3's exit and entry labels overlapped at the top exit. Labels now sit beside their mark on the side facing the play rect's middle (`_beside()`), and mode 2's sit by the player.
- **Red checks** (break → the named check fails → restore; each in a scratch copy of `game/` with its own `config/name`, so no `user://` was shared; every restore `diff`-clean against the repo; baselines green in each copy first):
  1. world.gd `load` → `preload`: `FAIL lint world/world.gd:42 dev_ref`, `FAIL lint: world.gd holds the DevTools line exactly once (got 0)`.
  2. The line moved out of its `if`: `FAIL lint world/world.gd:41 dev_ref`.
  3. A second guarded copy: exactly one `FAIL lint world/world.gd:44 dev_ref` (the first copy exempt) and `… exactly once (got 2)`.
  4. The exemption's path text changed (`dev_toolz.gd`): `… exactly once (got 0)`, `FAIL lint world/world.gd:42 dev_ref`, and the three samples that rely on it.
  5. `dev/` dropped from `raw_input`'s allow: `FAIL lint dev/dev_tools.gd:66 raw_input` and the `dev/` sample.
  6. The re-apply loop removed from `load_settings()`: `test_state` `FAIL (a) … the override is kept (brightness 1)`, `FAIL (c) … brightness is 3 (got 0)`; `smoke_dev_tools` `FAIL …and it survives the load boot() runs`.
  7. The "no arming while overrides" return removed: `FAIL (a) …and the missing file is not written (1 writes)`, in TMP; (b) and (c) stay green (D16 allowed "(a) or (b)").
  8. `--chain` paid at spawn: `FAIL first life: on the first airborne tick the chain is 8, held 36 (got 0, 0)` (and the landing, second-life and paused cases).
  9. Armed on the first spawn only: `FAIL second life: on the first airborne tick the chain is 8, held 36 (got 0, 0)`, nothing else.
  10. Entry forced to `spawn`: `ERROR: World: room 't_swap_b' has no entry 'spawn'`, the start-room assert, then `FAIL --room=t_swap_b (no P) starts at its up entry (got no room, spawn at [])`. On the first run the case read `_room().id` on a null room and aborted with a SCRIPT ERROR before any named FAIL; the case (and the falling-spawn case) now guard a missing room or player, and the re-run gives the named FAIL.
  11. The `current_scene` gate dropped: `smoke_world.gd --chain=3` → `FAIL …with the chain of 3 banked first: carried +6, chain 0 when the room is entered (carried 27 -> 48)` (+21), the three `best_chain` checks still `ok`; `smoke_dev_tools.gd --log=save` → `FAIL ...no Log category is enabled` (plus 22 knock-on FAILs: the real tokens replace every case's own).
  12. DevTools pausable: `FAIL …and it still cycles while the tree is paused (got 0)` and the "always processes" check.
  13. The unshaded material removed: `FAIL WorldMarks draws unshaded: readable under the darkness`.
  14. `active()` returns `_requests`: four `active()` FAILs, among them `FAIL active(): changing the returned copy changes nothing in the Clock`, then a SCRIPT ERROR in `Clock._apply` (the test wrote a float into the live dict).
  15. `uri_decode()` dropped: `FAIL query_tokens: the D4 example gives the command-line tokens, %2C decoded …` (and the `%3D`/`%26` and `+` cases).
  16. An F2 event added to `dev_overlay` in the copy's `project.godot`: `FAIL no project action is bound to a function key (got ["dev_overlay: F2"])`, `FAIL dev_overlay has exactly one event …`.
  17. `is_visible_in_tree()` dropped: `FAIL a light hidden doesn't count`; the `m1_shaft` count stayed 1, as D16 said.
  18. `--set` through `Game.settings.set_value()`: `FAIL --set=brightness:3: brightness 3, and writes disarmed`, `FAIL …and it survives the load boot() runs`. Its after-load file check stayed `ok`: `load_settings()` disarms writes before the deferred write runs, so it couldn't fail. A file check two frames after the build, before the load, was added; re-run, it fails (`FAIL …and settings.json still holds 1 two frames later: the override wrote nothing`). Separately, `_settings_armed = false` removed from `override_setting()`: the smoke's "writes disarmed" and `test_state` `FAIL (b) … no write, the file unchanged (1 writes)`.
  19. `room_ids()` sorting StringNames: `FAIL …alphabetically, each id before the next as Strings (got [&"t_input", &"bad_unknown_char", …])`.
  20. Clock sampled only at the rebuild: `FAIL a hitstop requested right after a rebuild is seen one frame later (got {  })` (and the greyed row).
  - **Extras** for new checks D16 doesn't cover: dev/ class names not collected → `FAIL layer_names: dev_ref gets only dev/'s classes …` and the tree sentinel; `prev` updated on blank lines → the "blank line and comment between guard and line" sample fails; the paused guard removed → `FAIL --chain=8, spawned while paused: still 0 after 5 paused ticks (got 8)`; no disarm after paying → `FAIL …it lands with the chain still 8 on the tick before (got count 20)`; `ENTRY_ORDER` up first → `FAIL pick_entry([&"down", &"spawn", &"up"]) is spawn`; a single-valued arg keeping its first value → `FAIL parse: a repeated --room keeps the last …`; `.to_lower()` dropped → `FAIL --log=lurker,CLOCK gives both, any case`; ints typed through floats → `FAIL --set=brightness:3.0 is an error`; `inspect()` unsorted → `FAIL inspect(m1_shaft): … exactly down, spawn, up …`.
- **Code review fixes (2026-11-19):** 16 patches and the `light_marks()` decision. Each new check and each unrecorded one (AC10) was red-checked in its own copy of `game/` (unique `config/name`, so its own `user://`; the real `settings.json` still dated 2026-11-12), every mutation matched exactly once; 30 of 31 caught by a named check or a run-failing `SCRIPT ERROR`:
  - Older checks: `unshaded_material()` building a new material → `FAIL a second World's WorldMarks shares the same cached material`; `LAYER` 10 → `FAIL the screen marks' CanvasLayer is above UI (10 > 10)`; `room_items()` without objects → `FAIL …and the obj= id at its cell (got [])`; exit rows swapped → `FAIL …the up exit's opening …`; `counts_on_screen()` without `enabled` / `energy`, and by centre point → `FAIL a light disabled …`, `… energy 0 …`, `… straddling the edge counts`; a default size for no texture → `FAIL a light no texture …`; `return true` → `FAIL a light wholly outside …` (and the code-built count, 3); `clock_rows` with `<=` / `< 499` → `FAIL clock_rows: seen 500 ms ago …` / `… seen 499 ms ago …`; `is_valid()` without the choices / ignoring the passed schema → `FAIL is_valid: a value outside the choices …` / `… with a passed schema …`; `_apply_set()` without its warning → `FAIL bad --set values … (got [])`.
  - `is_valid()` without its type clause stayed green: GDScript's `in` on an Array is already type-strict (probed: `1.0 in [0, 1, 2, 3]` is false, `1.0 == 1` is true), so the clause is a second guard. The type-mismatch check still fails on a loose match (`choices.any(c == v)` → `FAIL is_valid: a type mismatch is false …`).
  - New checks: the spawn-frame guard removed → `FAIL --chain=8, a player spawned inside a tick: … (got 0, banked [36])`; `OS.get_cmdline_args()` → `FAIL off the web, real_tokens() is the command line after -- (got ["res://tests/runner.tscn"])`; the gate compared with `self` → `FAIL a World that is the current scene reads them itself (got [])`; parse errors, the `--chain` warning or the `--log` warning dropped → `FAIL bad args: one warning each …`; no-valid-category block removed → `FAIL --log=: one warning, and Log left as it was (got [])`; a stray `Log.set_enabled([])` in `_apply()` → `FAIL …Log untouched …`; `--log` values not merged → `FAIL --log=lurker --log=CLOCK: both on …`; the light count on the play rect plus the gutters → `FAIL …one under a gutter doesn't: 2 (got 3)`; `light_marks()` with `>` / reach × 1.5 → `FAIL light_marks: at the notice radius …` / `… the 40 px base light …`; a bad access in mode 2's notice ring, in the sense line, and in mode 3's obj label → each a `SCRIPT ERROR` that fails the run (before the review no test reached them); `_exempt()` ignoring the guard → `FAIL dev_ref fires on … if not OS.is_debug_build(): …` (and the `pass` between); the hook moved below `add_to_group()` → `FAIL lint: …under its guard, as the first statement of World._ready() …`.
- **After the review:** `== ALL GREEN (17 tests)`, 1086 `ok` (`smoke_dev_tools` 88, `test_dev_args` 75, `test_lint` 179, `test_room_loader` 79: its StringName premise is now a warning), 1 m 48 s, no `ERROR:` lines.

### Completion Notes List

- Story context created by gds-create-story on 2026-11-19. sonlm decided D6 and D8 the same day: `--chain` starts at take-off, as n pogo hits (held n(n+1)/2), on every life; a `--set` session saves no settings at all. An adversarial review of the draft (code accuracy, feasibility, requirements; each finding verified) was folded in before ready-for-dev.
- **AC1:** the hook is `World._ready()`'s first statement, exactly the D2 text. `dev_ref` lets it through once, right under its guard (`once` field, read with `rule.get("once", {})`; only `dev_ref` has it); `layer_names()` returns a `dev_ref` list (dev/ classes and autoloads); a tree check finds the real line exactly once.
- **AC2:** `DevTools.real_tokens()` (command line + `JavaScriptBridge.eval` query, gated on `current_scene == World`); pure `query_tokens()` and `parse()`; one `ARGS` row per arg. Bad args are `push_warning("DevTools: …")`.
- **AC3:** `RoomLoader.room_ids()` / `inspect()`; `World.start_entry`; `room_entry()` / `pick_entry()`. `t_swap_a` starts at `P` and respawns there; `t_swap_b` starts at `up`, falling; `nope` and `bad_edge_hole` warn and load `m1_shaft`.
- **AC4:** armed on every `player_spawned`, paid in `_physics_process` (priority 100) on the first tick the player ran that ends off the floor, skipped while paused, held behind `is_instance_valid()`.
- **AC5–AC6:** `log_names()`; `set_value_of()` typed by the schema default, then `Settings.is_valid(key, v, schema)`; `Game.override_setting()`, `load_settings()` re-applies overrides and returns before arming, `reset_for_tests()` clears them.
- **AC7:** `overlays.gd` as D9–D11 (WorldMarks unshaded, Screen on layer 11, 4 Hz readout, per-frame Clock sampling, `clock_rows()`, `counts_on_screen()`, `room_items()`); `Clock.active()`.
- **AC8–AC9:** `dev_overlay` (physical 96) in `project.godot`; `smoke_dev_tools`' `test_actions` and its no-token case; `smoke_world` and `smoke_room_swap` unchanged and green.
- **AC10:** 17 tests green, the red checks above, docs and ledger (below). Game-code edits outside `scripts/dev/` are exactly the AC10 list, plus comment updates in `world.gd` (the ambient and fallback comments that named 1.11).
- **Final names (D1–D11 sketches → code):** `DevTools.tokens`, `overlays`; statics `real_tokens()`, `query_tokens()`, `parse(list, registry := ARGS)`, `chain_value(text) → [n, error]`, `log_names(text) → [cats, errors]`, `set_value_of(text, schema := Settings.SCHEMA) → [key, value, error]`, `schema_help(schema)`, `room_entry(id, info, known_ids) → [entry, error]`, `pick_entry(entries) → [entry, error]`, `sorted_names(names)`; consts `ARGS`, `ENTRY_ORDER`, `MAX_INT_CHARS` 4. Overlays: `mode`, `world`, `last_refresh_ms`, `light_count`, `clock_seen`, `clock_list`, `cycle()`, `room_items()`, statics `clock_rows()`, `counts_on_screen()`, `unshaded_material()`.
- **Deviations from the Dev Notes, kept and recorded:**
  - **D4:** `ARGS` keys are Strings (the tokens are), and `parse()` normalises a passed registry's keys to String. The apply order is `ARGS`' own order (log, set, room, chain), not a second list a new row could miss; a test pins it.
  - **D5:** `room_entry()` has a third message for a valid room with no `P` and no exit (`inspect()` gives no errors and no entries there).
  - **D6:** `--chain=0` connects nothing (paying 0 hits is a no-op).
  - **D9:** labels sit beside their mark facing the play rect's middle, and mode 2's by the player, after the first screenshots showed them under the gutters (Debug Log). Exit labels use ASCII `->` (`up -> m1_shaft`), so the fallback font's glyph coverage never matters.
  - **D14, checks added:** a spawn while paused (D6's paused guard had no check; extra red check), bad `--set` values (two warnings, no override), `inspect(t_swap_a)`, the `ARGS` row shape and order, a premise that the action walk saw the project's actions, a world-tree and DevTools-subtree check in the no-token case, the warning texts for bad rooms, the `t_dev_room` up-exit opening rect; the `--set` file check runs both before and after the second load (red check 18); null guards so a missing room or player is a named FAIL (red check 10).
  - **D16 #16** (like every red check) ran on a scratch copy of `game/` with its own project name instead of editing the real `project.godot` and `git checkout`: the copy's InputMap comes from its own `project.godot`, so the check fails the same way, and the real tree was never touched.
  - **D12 samples added:** a blank line and a comment between guard and line stay quiet; `"DevThing"` inside a string stays quiet. `_test_layer_names` gained a `dev/` class and a `dev/` autoload, so its `core_layer` / `rules_purity` expectations grew by those two names.
- **Docs (D15):** development guide (run notes, a DevTools section with the arg table and overlay list, test list, lint table, Common Tasks), `rooms.md`, `game/README.md` (run note under "press F5", the backquote row, the brightness line, the Tests list), `architecture.md` (tree, state rows, Component Overview, Testing Strategy rows, the Enforcement variance paragraph, Last run 17 tests, the Input gaps row), `component-inventory.md` (a Dev Tools section, World, Core, RoomLoader, Input Actions, Test Components), `source-tree-analysis.md`, `index.md`, `project-overview.md` (the "debug HUD" line), `project-context.md` (the four D15 edits only), `game-architecture.md` (Debug Tools with `--room=weaver_test` and the arg phases, Enforcement, Settings persistence, Configuration). Accuracy fixes beyond D15's bullets, all caused by `start_entry` or the one-line exception: the dev guide's "Edit the Level" fallback sentence, `rooms.md`'s test-room folders, `architecture.md`'s respawn row and death flow, `component-inventory.md`'s World text, `source-tree-analysis.md`'s class_name sentence and Entry Points row, and `game-architecture.md`'s two boundary lines (≈ `:879`, `:882`). Older drift left alone (not this story's): the dev guide's and README's per-test lists still lack `test_lint`, `test_tuning` and `smoke_player_input`.
- **Deferred, with owners** (ledger section "Deferred from: dev of 1-11-…", `test_deferred_owners` PASS: 31 items, 0 unowned):
  1. `--chain` ends on its first break; `perf_worst`'s 60 s run needs chain 20 held → **Story 1.12**.
  2. The on-screen light count rule lives only in `dev/`; the ≤ 6 budget needs it in game code → **Story 1.12**.
  3. Overlay 2 reads `Lurker`'s sensing constants; they move with `rules/sensing.gd`, plus sense/stir rings and a ring per light source → **Story 1.20**.
  4. A loaded respawn point beats `--room`; a dev session writes room visits and `best_chain` to the slot → **Story 1.21**.
  5. `dev_overlay` ships inert; one player-action filter (skips `dev_*`, `ui_*`) with the controls reference → **Story 1.34**.
  6. Rebinding and its clash rule skip `dev_*` → **Story 7.3**.
  7. Overlay 3's entries gain anchors and stations → **Story 1.24**.
  8. Boot screens must not swallow `--room` / `?room=` → **Story 1.33**.
- **Tests green; needs a 2-minute look on the laptop:** `godot --path game -- --room=m1_shaft --chain=8 --set=brightness:0`, walk off the spawn ledge (the chain shows 8 at take-off and usually ends on the first hoverer bump), and cycle the overlays with the backquote key. The game has no pause key yet, so cycling while paused is covered only by `smoke_dev_tools`.

### File List

New:
- `game/scripts/dev/dev_tools.gd`, `game/scripts/dev/dev_tools.gd.uid`
- `game/scripts/dev/overlays.gd`, `game/scripts/dev/overlays.gd.uid`
- `game/tests/test_dev_args.gd`, `game/tests/test_dev_args.gd.uid`
- `game/tests/smoke_dev_tools.gd`, `game/tests/smoke_dev_tools.gd.uid`
- `game/tests/rooms/dev_tools/t_dev_room.txt`

Modified:
- `game/project.godot` (`dev_overlay`)
- `game/scripts/world/world.gd` (hook line, `start_entry`, fallback, comments)
- `game/scripts/world/room_loader.gd` (`room_ids()`, `inspect()`)
- `game/scripts/rules/settings.gd` (`is_valid()`)
- `game/scripts/core/game.gd` (`override_setting()`, load and reset)
- `game/scripts/core/clock.gd` (`active()`)
- `game/tests/test_lint.gd`, `game/tests/test_clock.gd`, `game/tests/test_state.gd`, `game/tests/test_room_loader.gd`
- `game/README.md`
- `docs/development-guide.md`, `docs/architecture.md`, `docs/component-inventory.md`, `docs/source-tree-analysis.md`, `docs/index.md`, `docs/project-overview.md`, `docs/rooms.md`
- `_bmad-output/project-context.md`, `_bmad-output/game-architecture.md`
- `_bmad-output/implementation-artifacts/deferred-work.md`, `_bmad-output/implementation-artifacts/sprint-status.yaml`, this story file

### Change Log

- 2026-11-19: Laptop look passed (sonlm), on a real launch with `-- --room=m1_shaft --chain=8 --set=brightness:0`: the args apply (the room, the darkest brightness, the chain-8 light at take-off), the backquote key cycles the four overlays and then off, and the overlays read in the dark at ×3. Nothing to fix.
- 2026-11-19: Code review (five layers on Fable 5.2, refuting verifiers): 1 decision, 16 patches, 1 deferred (to 1.13), 7 dismissed. `--chain` also skips the spawn's own physics frame; `--log` with no valid category warns and leaves `Log` alone; `Overlays.light_marks()` (mode 2's numbers, tested at 80 px); new smoke cases for the real command line, every bad-arg warning, a mid-tick spawn, merged `--log`, mode 2 past the notice radius, code-built lights and mode 3's draw; lint samples and the first-statement check; the StringName premise is a warning; docs (`scripts/dev/*` in the release exclusions, `dev_ref` matches `res://` paths, function-key wording). 31 red checks. ALL GREEN (17 tests, 1086 ok). Status → done.
- 2026-11-19: Story 1.11 implemented. Debug-only `DevTools` (`scripts/dev/dev_tools.gd`, `overlays.gd`), added by `World._ready()`'s one guarded path-string `load()`: entry args `--room`, `--chain`, `--log`, `--set` (the URL query on web debug builds) and four overlays on the backquote key (`dev_overlay`). Small APIs: `World.start_entry`, `RoomLoader.room_ids()` / `inspect()`, `Settings.is_valid()` (public, optional schema), `Game.override_setting()`, `Clock.active()`. Lint: `dev_ref`'s exact guarded line and `dev/` class names; `raw_input` allows `dev/`. New `test_dev_args`, `smoke_dev_tools` and `tests/rooms/dev_tools/t_dev_room.txt`; 20 D16 red checks plus 9 extras. Docs and 8 ledger items. ALL GREEN (17 tests, 1065 ok). Status → review.
