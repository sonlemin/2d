---
project_name: 'pixel_art_game'
user_name: 'sonlm'
date: '2026-11-11'
sections_completed:
  ['technology_stack', 'engine_rules', 'performance_rules', 'organization_rules', 'testing_rules', 'platform_rules', 'anti_patterns']
status: 'complete'
rule_count: 67
optimized_for_llm: true
architecture: '_bmad-output/game-architecture.md'
---

# Project Context for AI Agents

_Critical rules and patterns for implementing game code in this project. Focus on unobvious details agents might otherwise miss. The full design is `_bmad-output/game-architecture.md`; section names below point there._

---

## Technology Stack & Versions

- **Godot 4.7.2 stable**, GDScript only (no C#/GDExtension). Project root is `game/`. Editor and export templates must match 4.7.2 on laptop and server. **Frozen on 4.7.x for M2**; a minor upgrade is considered only at an epic boundary (Architecture → Engine upgrade checklist).
- **Renderer: GL Compatibility** (required for web). Check the docs before using any rendering feature; use Context7 (authenticate via `/mcp`) for current 4.7 APIs.
- **Display:** 480×270 viewport, integer scaling only, nearest filter, `snap_2d_transforms_to_pixel`, 2D physics interpolation **on since Story 1.7**, kept only if the laptop feel check passes (Story 1.15 records the decision). Physics at **60 ticks/s**; all tuning assumes it.
- **No addons. No `.tres`** (TileSet, Theme and materials are built in code). **Autoloads: `Game` and `Audio` only**; a third is an architecture change. Ask before adding an addon.
- **Tests:** headless test scripts extending `Node`, run as scenes by `tests/runner.tscn` (no GUT/gdUnit; under `--script` anything that touches the `Game` autoload fails to compile). **Art:** Python 3 + Pillow 12, `tools/build_sprites.py`. **Web smoke:** Node 24 + Playwright (`tools/web_smoke/`, version pinned in its `package.json`).
- **UI font:** Fusion Pixel Font 8px proportional (OFL 1.1), size 8, antialiasing/hinting off; `OFL.txt` + `LICENSES/` ship in every build.

## Current State vs Target

**Story 1.1 moved the M1 files into the domain folders** (`scripts/rules/chain_state.gd`, `scripts/actors/{player,crawler,lurker}.gd`, `scripts/core/fx.gd`, `scenes/actors/`). **Story 1.2 added the `Game` autoload (holding only `clock`), `scripts/core/{clock,log}.gd`, and runs every test through `tests/runner.tscn`.** **Story 1.3 moved the M1 `@export` tuning into `scripts/rules/tuning.gd` (read through `Game.tuning`) and added an empty `rules/gear.gd`.** **Story 1.4 added `Settings`, `SlotState` and `DiveState` in `rules/` and `core/save_store.gd` (`settings.json`), held by `Game` (`boot()`, `reset_for_tests()`); `shaft.gd`'s statics moved into them (the last-ledge checkpoint was dropped: a death respawns at `P` until 1.24), and its controls bar and F2 are gone.** **Story 1.5 added `world/{room_legend,room_loader,room}.gd` and `rooms/l1/m1_shaft.txt` (the M1 shaft at 22 columns, built by `RoomLoader`); `shaft.gd` lost `LAYOUT` and loads that room, and `smoke_shaft`/`screenshot` load it standalone through `tests/room_harness.gd`.** **Story 1.6 made `scenes/world/world.tscn` (`World`, `CameraRig`, `ui/{gutters,screen_router}.gd`) the main scene: a death respawns a fresh `Player` without a reload, lurkers read `World.play_rect()`, and `smoke_world` replaced `smoke_shaft_state`.** **Story 1.7 added room swaps (`World.enter_room()`, polled exits with the chain backstop, a death rebuilds the respawn room, killed cells skipped through `load_room(id, Game.dive)`, `SlotState.visit()`), turned on physics interpolation (`CameraRig` smooths and clamps itself on the physics tick), and deleted `shaft.gd`/`shaft.tscn`; test rooms live in `tests/rooms/swap/` and `smoke_room_swap` tests them.** **Story 1.8 added `actors/player_input.gd` (`PlayerInput`, child of `Player`, sampled by `Player` first each tick on real ticks): `player.gd` reads only its intents, `Settings.light_tap_window` (0.12 / 0.2 / 0.3 s) replaced `SNUFF_HOLD`, Jump and Attack presses wait in real-time buffers, ↓ interact, `lock()`; `smoke_player_input` pins the M1 movement numbers.** **Story 1.9 made `run_tests.sh` find tests by glob** (`tests/test_*.gd`, then `tests/smoke_*.gd`; no list to edit), **added `tests/spec.gd`** (the GDD thresholds) and **`tests/test_lint.gd`** (rule ids `time_scale`, `raw_input`, `print`, `free`, `root_path`, `keycode`, `random`, `rules_purity`, `core_layer`, `dev_ref`, `tests_ref`, `state_write`, plus `spec_citation`). **Story 1.10 added the room checks:** `tests/smoke_rooms.gd` walks every `res://rooms/**/*.txt` (validation, unique ids and exit links across files, spine falls ≤ `Spec.LEDGE_FALL_MAX`, `cling=` stretches 6–10 wide, hazard pits over `RoomLegend.HAZARDS`, no enemy within 3 cells of the arrival from below, and the lurker guarantees per lurker and per room), `tests/smoke_bot.gd` plays every spine room top to bottom, the pure sweeps live in `tests/room_sweep.gd`, and `smoke_moves.gd` took the M1 move checks when `smoke_shaft.gd` was deleted; `rooms/dev/` is validated only. **Story 1.11 added DevTools** (`scripts/dev/dev_tools.gd` + `overlays.gd`, no `.tscn`; debug builds only, added by `World._ready()`'s one guarded line): entry args after `--` (the URL query on a web debug build) `--room=<id>` (sets `World.start_room` / `start_entry`), `--chain=<n>` (paid as n hits on each life's first airborne tick), `--log=<cat>,<cat>` and `--set=<key>:<value>` (session-only through `Game.override_setting()`; a session with any override writes no `settings.json`; `--set=brightness:N` until Options, 1.36), the `dev_overlay` action (backquote) cycling four overlays, then off, plus `Clock.active()`, `Settings.is_valid()` and `RoomLoader.room_ids()` / `inspect()`; `test_dev_args` and `smoke_dev_tools` test it. **Story 1.12 added the light budget and the perf kit:** every `PointLight2D` is a `BudgetLight` (`core/budget_light.gd`; the player's `Light` ALWAYS, the lurker's `Glow` GLOW), World's `LightBudget` child (`world/light_budget.gd`) applies it each physics tick against `World.light_rect()` (the rig's `view_rect()`), `Fx.unshaded()` / `additive()` replaced `_unshaded()`, `rooms/dev/perf_worst.txt` is the worst-case scene, and DevTools gained `--glow=on|off` and `--perf[=<s>]` (`dev/perf_run.gd`, the autopilot run; overlay 4 shows the budget, frame times and the summary; procedure in `docs/perf.md`); `test_fx`, `test_light_budget` and `smoke_perf` test it. **Story 1.13 added the build pipeline:** `game/export_presets.cfg` (presets `Windows`, `Linux`, `Web`, `Web debug`; `tests/test_export_presets.gd` pins them), `tools/export.sh` (preflight, version `<yyyymmdd>-<sha7>[-dirty]`, import, content = `smoke_rooms`, the four exports to `builds/<version>/`, the PCK checks through `tools/pck_list.gd`, the gzip web size, a 5 s headless Linux release boot, the web smoke) and `tools/web_smoke/` (Playwright 1.65.1, `serve.js`, `smoke.spec.js`); DevTools prints `[room] SMOKE boot ok` once on World's first `room_entered` in real runs; setup and the engine upgrade checklist are `docs/build.md`. **Story 1.14 added `Game.display`** (`core/display.gd`, a child of `Game` like `Clock`): it holds the scale rule (`scale_for()`, `stretch_for()`, `window_scale_for()`, `scale` 0.0 = no window, `scale_changed`), and the integer stretch stays the engine's. On web the scale is in physical pixels through Godot's HiDPI canvas, with no JavaScriptBridge, and since the web root window never emits `size_changed` on a browser resize, `Display` also checks the size each frame. Below 480×270 it switches to the fractional nearest fit; on PC the window is ×3 or the largest whole scale that fits the screen, minimum 480×270; `start()` is inert under headless. Both web presets carry `html/canvas_resize_policy=2`, `html/focus_canvas_on_start=true` and the `html/head_include` key guard; `test_display` tests it, plus the smoke's `Display scale` and `Web input` blocks with `tools/web_smoke/embed.html`. Never build new M2 work on the M1 patterns.

## Critical Implementation Rules

### Engine-Specific Rules

- **State lives in pure objects, not nodes or statics** (Architecture → State Management): per-life on the `Player` (`ChainState`, `Health`, `PlayerInput`); per-dive `Game.dive`; per-slot `Game.slot`; global `Game.settings`; plus `Game.tuning`. `Game` holds refs only, no rules.
- **`Game` keeps the same state instances all session** and resets them in place (`from_dict()` / `reset()`). Never replace `Game.slot` / `Game.dive`; subscribers would keep listening to the old object.
- **Death does not reload the scene.** `World` applies the death cost, rebuilds the respawn room and spawns a fresh `Player`, then emits `player_spawned(player)`: anything bound to `player.chain` / `player.health` rebinds there.
- **Only `Game.clock` writes `Engine.time_scale`.** Request effects: `clock.request(&"hitstop", 0.05, 0.075)`. Requests multiply, ignore time scale and **pause with the tree**. Pause is `SceneTree.paused`; UI runs `PROCESS_MODE_ALWAYS`. Real-time visuals use `delta / Engine.time_scale` in `_process`.
- **Gameplay reads `PlayerInput` intents, never `Input`.** It owns the Light tap/hold machine (tap window from `Settings`), the Cling/Snuff toggles and real-time buffers, so presses during hitstop are kept (an Attack still waits for a cooldown that runs on game time). Menus read `menu_*` actions. `dev/` reads its own `dev_*` actions raw (the `raw_input` lint allows `dev/`).
- **Gameplay movement lives in `_physics_process`**; `_process` is visuals only.
- **Physics interpolation is on (Story 1.7):** move gameplay `Node2D`s only in `_physics_process`, and call `reset_physics_interpolation()` after every teleport (spawn, room entry, camera snap). Godot 4.7 has no 2D `get_global_transform_interpolated()`, and it forces a `Camera2D` onto the physics tick, where its own smoothing and `reset_smoothing()` no longer cut. So `CameraRig` smooths and clamps itself, and `play_rect()` never reads the engine camera.
- **Predators sense light only through `LightSource` + `Sensing`** (group `light_source`), never `get_first_node_in_group("player")`. "On screen" always means `World.play_rect()` (inside the gutters), never the viewport, for every fairness rule; the one exception is the light budget's cost rect, `World.light_rect()` (Performance Rules).
- **A predator kills only while `monitorable == true`**, and only while the **player** is its target (lurker: HUNT). Retargeting from a flare/cache onto the player needs a fresh telegraph (≥ 0.75 s). Never add a kill path around this: "Snuff/land/cling in time always saves you" is a tested guarantee.
- **Room swaps are deferred and go through `World`.** Crossing an exit with a live chain **banks it** (like a landing). Remove the old room from the tree before `queue_free()`. Only `the_fall.gd` uses `World.scripted_cut()` to keep a chain.
- **Runtime spawns go through `room.spawn(scene, pos, args)`** (args set before `add_child`); the room owns and frees them. Never parent flares/FX to `World`.
- **Actors find each other by group** (`player`, `enemy`, `predator`, `light_source`, `world`) and duck typing (`take_hit()`), never node paths. **Crawler contact is polled** (`get_overlapping_bodies`), not `body_entered`.
- **FSMs:** `enum State` + `match` + one `_enter(state)`; `state` is public for tests.
- **Physics layers:** 1 world · 2 player · 3 (value 4) enemies/pogo-able · 4 (value 8) predators. Slash/Pogo mask 4, Hurtbox mask 12.
- **Things that must read in the dark** use `LIGHT_MODE_UNSHADED`.

### Performance Rules

- **Target: 60 FPS on an Intel HD 620-class iGPU and in desktop browser web builds.** Profile on the weakest target. Budgets: GDD → Technical Specifications.
- **Lights are the cost centre** (rendering is at 480×270, so cost = lights × lit canvas items): **≤ 6 `PointLight2D` on screen**; player and flares keep theirs; lurker wall glow falls back to a sprite first. Reuse `art/light.png` via `texture_scale`. Engine glow stays off until the E1 perf scene (`rooms/dev/perf_worst.txt`) passes on web.
- **Every `PointLight2D` is a `BudgetLight`** (lint `raw_light`; `test_light_budget` audits the scenes), with a `rank`: ALWAYS only for the player and flares, CACHE for the Ember Cache, GLOW otherwise. World's `LightBudget` child demotes over-budget lights each physics tick, after the actors (priority 50), GLOW first, then CACHE, ALWAYS never; a demoted light shows its additive sprite instead. Only the budget writes `enabled` on one.
- **The budget counts the whole view, `World.light_rect()`** (gutters included): a cost rule, not AR20's "on screen", which stays `play_rect()` for notice, stir, edge cues and the guarantees.
- **Cache materials and shared resources as statics.** Never build a new `Material` per effect (`Fx.unshaded()` / `additive()` are the shared ones). Warm up new effects at room load.
- **Code-built FX free themselves** (`finished` → `queue_free`). **`CPUParticles2D`**, not GPU particles. **No `Thread`/`WorkerThreadPool`** and no threaded resource loading (single-threaded web).
- **No pooling** except the `Audio` SFX players, until profiling shows a hitch.
- **No logging in hot paths** unless wrapped in `if Log.enabled(Log.X):`.

### Code Organization Rules

- **Layout** (Architecture → Project Structure): `game/scripts/` and `game/scenes/` share domain folders `core/ rules/ world/ actors/ objects/ moments/ ui/ audio/ dev/`. snake_case file + PascalCase `class_name` (autoloads have none). Scenes are thin prefabs; behaviour lives in scripts.
- **Dependencies point one way:** `rules/ ← core/ ← world, actors, objects, moments ← ui, audio ← dev`. `rules/` never mentions `Node`, `Input`, `Engine` or `Game`. UI writes only `Settings`; it changes gameplay state through `Game` / `World` commands. Nothing outside `dev/` and `tests/` references `dev/`, except `world.gd`'s one path-string `load()` of DevTools inside `if OS.is_debug_build()` (the lint checks the one guarded line and `dev/` class names).
- **Write state only through rule methods that emit signals** (`Game.slot.set_flag(id)`, `Game.dive.add_carried(n)`). Typed signals on the owner; **no event bus**.
- **Tuning is data in `rules/tuning.gd`:** a `const` per value with a `##` unit + intent + "was X" comment, listed in `BASE`; actors read `Game.tuning.f(&"key")`. Gear is data in `rules/gear.gd` (`{id, stat, op, value}`); never `if has_gear`. Prices live in `rules/economy.gd`. **Change a value → update the matching GDD table.**
- **Levels are text:** `game/rooms/<layer>/<room_id>.txt` (header + `---` + grid; spine rooms are 22 columns **including** walls). The legend lives only in `world/room_legend.gd` and `docs/rooms.md`. Persistent objects carry explicit header ids (`obj=anchor_s2_1@x,y`); ids are globally unique and never renamed once testers have saves.
- **All player-facing text via `tr("UPPER_SNAKE_KEY")`** from `game/text/strings.csv`; copy names shapes, never colours. Commit the generated `.translation` files.
- **Comments explain *why*, citing the design** ("Pillar 2: …", "playtest: …", "spec: ≥ 0.75 s"), never restate *what*.
- **Sprites:** source is `tools/sprites/*.txt` + `palette_edge.txt`; `game/art/*.png` is build output. Never hand-edit or hand-create PNGs: edit the grid, run `python3 tools/build_sprites.py`, re-import. `L` (#ffd27a) is constant across palettes. **If a pipeline doesn't support an asset type, stop and ask.**
- **Commit `.gd.uid` and `.import` files** with their sources; move scripts with `git mv`, then re-import and re-save moved scenes.
- **Design source of truth:** GDD v1.0 + UX `DESIGN.md`/`EXPERIENCE.md` (`_bmad-output/planning-artifacts/`) + this architecture. M1 playtest findings supersede the brief on controls, cling and embers.
- **Story text** (NPC lines, documents, death lines, Memorial names) follows `_bmad-output/narrative-design.md`: island dialect in word choice, never phonetic spelling; Glim is never gendered; Layer 1 has exactly three pointed clues. **No line is written until sonlm has approved 3 voice-anchor lines for that speaker.** Story flag ids live in one registry in `rules/` and are save data (never renamed).

### Testing Rules

- **Before calling a change done: `cd game && ./run_tests.sh` → `== ALL GREEN`.** The runner globs `tests/test_*.gd` and `tests/smoke_*.gd` and **fails on any `SCRIPT ERROR` / `ERROR:` line**. Name new tests to match the glob or they never run.
- **Headless tests can't judge feel.** Report "tests green; needs a feel check on the laptop", never "feels better". The user plays builds on the laptop; the server is headless.
- **Pure rules → `tests/test_<subject>.gd`** (build fresh state objects per test; each test extends `Node` and runs through `tests/runner.tscn`, so `preload`, `class_name` and `Game` all work). **Room behaviour → `tests/smoke_*.gd`**, loading rooms **standalone** with `RoomLoader` + a test player; drive input with intents or `Input.action_press`, counting physics frames.
- **Design guarantees compare against `tests/spec.gd`** (thresholds with GDD citations), never against the tuning value under test. `smoke_rooms.gd` checks every room file; the bot checks chain ≥ 5 per spine room (and, from E4, the required chain at every gate). A new per-room rule is a pure function in `tests/room_sweep.gd` with a firing sample and a near-miss, never a test on one room. **Never loosen a threshold to pass;** change the GDD first, with the user.
- **Every deferred item needs an owner.** `tests/test_deferred_owners.gd` fails while any item in `implementation-artifacts/deferred-work.md` has none (code review appends items without one). Fix the ledger, never the check: the agent that defers an item assigns its owner itself, as an indented `→ **Owner: E3** — <why>` line (no `(proposed)`, no asking sonlm), and names it in its report. Never leave a deferred item ownerless.
- **`tests/test_lint.gd` enforces architecture rules** (no `Engine.time_scale` write outside `clock.gd`, no raw `Input` outside `PlayerInput`/UI kit/`dev/`, no `print(`, `free()`, `"/root/`, any `KEY_*`, stray randomness, `res://tests/` in game code, state writes that skip a rule method, `rules/` purity, the `core/` layer and raw lights (`raw_light`: no `PointLight2D.new(` or `extends PointLight2D` outside `BudgetLight`); table in `docs/development-guide.md`). Fix the code, not the lint.
- **Validators are pure and return error lists;** tests inspect the list instead of triggering `push_error`.
- **Keep the output format:** `ok …` / `FAIL …` lines + final `PASS`/`FAILED`.
- **Pick test targets by position/sort order**, not `get_nodes_in_group(...)[i]`.
- **Save format changes ship a migration and a fixture** (`tests/fixtures/slot_vN.json`) that every later build must load.
- **Screenshots** need a renderer: `xvfb-run -a godot --path game --rendering-driver opengl3 res://tests/runner.tscn -- res://tests/screenshot.gd <out>`.

### Platform & Build Rules

- **Targets:** Windows, Linux, web/itch.io (960×540, ×2); Steam Deck legibility at ×2. Branch with `OS.has_feature("web")` only in boot, `core/display.gd`, the storage check, the quit button and the audio gate.
- **Input only through actions** (physical keycodes), one button per action, no chords; keyboard + gamepad; rebinding in E7, so never hard-code key names in UI text (use glyph prompts).
- **No function keys or raw keycodes.** Debug tools live in `dev/DevTools`, added only when `OS.is_debug_build()`: entry args (`-- --room=… --chain=…`, URL query on web), overlays on backquote. Nothing debug ships in release exports.
- **Pause:** Esc *or* P (Start on pad); also on focus loss and on disconnect of a pad that was in use.
- **Saves** (Architecture → Data Persistence): `user://slot_N.json`, write `.tmp` → verify → rename, keep `.bak`, integer `version` + migrations; `settings.json` separate; parse all JSON with `JSON.new().parse()` (`JSON.parse_string()` and `ConfigFile` print engine `ERROR:` lines that fail the test runner). On web, check `OS.is_userfs_persistent()`. Failures surface as the UX "Not saved" state; never crash or pause on them. Save triggers: **resume saves** (station rest, hub arrival, Quit menu / quit at a lit anchor) and **progress saves** (difficulty change, purchase, story flag, phase checkpoint, boss defeat), which never move the resume point or make carried embers safe.
- **Audio** mixes by per-player volume tweens on Master (`set_ignore_time_scale(true)`); **no bus effects** (unreliable on web). No audio before the click-to-play gate.
- **Only `Display` (`core/display.gd`) touches the stretch, the window size or the minimum size.** The web key guard lives in the presets' `html/head_include`; a new web export option goes in both web presets **and** `test_export_presets`.
- **Builds come from the server:** `tools/export.sh` validates rooms (string keys from 1.17; any content error blocks the build), exports the three targets, copies the font licences (from 1.17), checks the web size (< 30 MB, measured gzip: what itch.io's CDN sends) and runs the Playwright smoke check. Export presets include `rooms/*.txt` (in Godot's export matcher `*` crosses `/` and `**` is a plain `*`, so this is every room at any depth); release presets exclude `rooms/dev/*`, `tests/*` and `scripts/dev/*` (debug presets keep `scripts/dev/`: DevTools' `load()` has no null check). A new release exclusion goes in the presets **and** `test_export_presets`. **A release web build prints parse and load errors but no runtime script errors, so the debug web smoke (`SMOKE boot ok`, no `console.error`) is the runtime check.** Every path handed to Godot's exporter is absolute (a relative one resolves against `game/`); Godot exits 0 on some errors, so scan logs too.
- **Accessibility:** ≤ 3 flashes/s anywhere (pulses ≤ 2 Hz, blinks 2.5 Hz). **All flashing, shaking, pulsing and easing read `Settings.reduce_flashing` / `shake` / `reduced_motion`** through `Fx`, camera shake, the invulnerability blink and UI easing. No per-effect toggles.

### Critical Don't-Miss Rules

- **No randomness in level behaviour** (hover phase comes from position; `randf` only for camera shake).
- **`tests/test_chain_state.gd` is the spec for chain edge cases** (landing-frame pogo, snuffed hits, cap still pays, cling pause/grace, bank vs lose). Read it before changing `ChainState`.
- **Light key:** hold past the tap window (default 0.12 s; setting 0.12/0.2/0.3) = Snuff; a tap must never break the chain (tap = Flare Toss). With the Snuff toggle on, Light only throws flares and Snuff is a press-toggle on its own key.
- **Errors:** programmer errors → `assert`; content errors → pure validator + `push_error` + refuse to build; environment errors → return `Error` and surface via a state signal. Never `free()` nodes, always `queue_free()`. No bare `print()`; use `Log.info(Log.CATEGORY, …)`.
- **The HUD is the gutters + `ScreenRouter`** (one screen at a time, replace, never stack). Build UI from UX `DESIGN.md` with the E1 UI kit; there is no debug label HUD.
- **M1 → M2 vocabulary:** M1 "banked" ≈ M2 "carried"; M2 adds "deposited". The Ember Cache lives in `SlotState`; at most one. M2 replaces one-touch lurker death with HP (lurker = 2).
- **Migrating M1 code:** `shaft.gd` (F1 and F3, scene reload) is retired in E1. When touching M1 code, move it to the architecture's pattern rather than extending it.
- **Don't add mechanics from `deferred-work.md` unprompted;** each is its own experiment.

---

## Usage Guidelines

**For AI Agents:**

- Read this file before implementing any game code; follow every rule as written. For the *why* and the full patterns, read `_bmad-output/game-architecture.md`.
- When in doubt, prefer the more restrictive option and ask.
- Propose an update to this file when a new pattern emerges.

**For Humans:**

- Keep it lean: only rules agents would otherwise get wrong.
- Update it when the architecture or the stack changes; remove rules that become obvious or obsolete.

Last Updated: 2026-11-19 (Story 1.14: display scaling and the web key guard)
