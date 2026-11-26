# The Unbroken Chain — Development Guide

**Date:** 2026-11-11

## Environment

Development is split across two machines:

| Machine | Used for |
|---|---|
| **Laptop** (Godot editor with a display) | Playing builds (F5), feel tuning, editor work |
| **Headless server** (SSH) | Headless tests, the sprite pipeline, builds (`tools/export.sh`), git, docs |

## Prerequisites

| Tool | Version seen | Needed for |
|---|---|---|
| Godot | 4.7.2 stable | Everything in `game/` |
| Python 3 + Pillow | Pillow 12.1.1 | the sprite pipeline only: `tools/build_sprites.py`, `import_sprite.py`, `test_sprites.py` |
| `xvfb-run` (optional) | — | `tests/screenshot.gd` on the headless server |
| Godot export templates | 4.7.2 stable (`linux_release`, `windows_release`, `web_nothreads_*`) | `tools/export.sh`, server only |
| Node | 24.14 | `tools/web_smoke/` (the web boot smoke), server only |
| `@playwright/test` + its headless Chromium shell | 1.65.1 (exact pin), shell revision 1255 | `tools/web_smoke/`, server only |

The game itself needs no package manager, addons or environment variables. The web smoke's npm packages live in `tools/web_smoke/` (`npm ci`; setup in [build.md](./build.md)). Optional: set `GODOT=/path/to/godot` if `godot` is not on your PATH. `run_tests.sh` and `tools/export.sh` fall back to `~/.local/bin/godot`.

## Run the Game

Open `game/` in Godot 4.7 and press **F5**. The main scene is `scenes/world/world.tscn`. The controls are in [`game/README.md`](../game/README.md).

Brightness keeps the level saved in `user://settings.json` unless the run passes `--set=brightness:N` (below), and you restart by relaunching. A death respawns you at the top without a reload, in a rebuilt room (crawlers you killed stay gone); falling through the floor hole loops you back to the top.

### DevTools (debug builds only)

`World._ready()` adds `DevTools` (`scripts/dev/dev_tools.gd`) in its first statement: `if OS.is_debug_build(): add_child(load("res://scripts/dev/dev_tools.gd").new())`, a path string, never `preload`. The release presets exclude `scripts/dev/*`, so none of it ships (`tools/export.sh` checks every release PCK and boots the Linux one); editor runs and the `Web debug` export have it. In every real debug run it prints `[room] SMOKE boot ok` once, when World's first room is in (`room_entered`): the web smoke waits for that line. It builds its nodes in code (no `.tscn`), and in a run with no args it changes nothing.

**Entry args** go after `--`:

```bash
godot --path game -- --room=m1_shaft --chain=8 --set=brightness:0
```

In the editor, use Debug → Customize Run Instances and its per-instance arguments (stored in `.godot/`, never committed). **Never** set Project Settings `editor/run/main_run_args`: it is written into the committed `project.godot`. A web debug build reads the URL query instead (`?room=m1_shaft&chain=8`) through `JavaScriptBridge.eval("window.location.search")`, which returns null off the web, so there is no `OS.has_feature("web")` branch.

| Arg | Does |
|---|---|
| `--room=<id>` | Starts the dive in that room, at its `P`, else its `up` entry (arriving from above, falling), else `down`. A death respawns there while no respawn point is set; DevTools never writes `Game.dive`'s respawn point (`World.start_room` / `start_entry`). An unknown id or an invalid room is a warning, and the default start room (`m1_shaft`) loads |
| `--chain=<n>` | 0–20 (`ChainState.MAX_CHAIN`), armed on every spawn (every life). Paid on the first physics tick that ends with the player off the floor, as n `ChainState.add_hit()` calls (count n, held n(n+1)/2, best chain n); then it breaks and banks like any chain |
| `--hp=<n>` | Story 1.19: 1–4 (`Health.MAX`); every life (the first and each respawn) starts with n HP, through its own `player_spawned` handler (`health.reset(n)`), so E2's Weaver work can start each life at 1 HP. Overlay 2 shows `hp n/4` (and `inv` while invulnerable) |
| `--difficulty=easy\|normal\|hard` | Story 1.22: the tier for this session (what a death costs: Easy keeps everything, Normal drops the carried embers as an Ember Cache, Hard loses both). Set on every spawn through its own `player_spawned` handler, never at once: DevTools runs before `Game.boot()`, whose detached load resets the slot. Exact and lower case; a bad value warns. Detaches the slot |
| `--log=<cat>,<cat>` | Turns on those `Log` categories (names from `Log.CATEGORIES`, any case). An unknown name warns and is skipped. `Log.set_enabled()` is called once, with every `--log` value merged, and only if they name at least one valid category (none, or `--log=` alone, warns and leaves `Log` as it was) |
| `--set=<key>:<value>` | Any `Settings` key, typed by its default (int, float, bool `true`/`false`); repeatable. Goes through `Game.override_setting()`: the value survives `Game.boot()`'s load, and a session with any override writes no `settings.json` at all (not even a rewrite or another key's change). `--set=brightness:0`…`3` is how brightness changes until Options (Story 1.36), and so are the accessibility keys (Story 1.16): `--set=reduce_flashing:true`, `--set=shake:false`, `--set=reduced_motion:true` (on web: `?set=shake:false`) |
| `--glow=on\|off` | Story 1.12: `on` adds a `WorldEnvironment` named `Glow` under DevTools, with a code-built `Environment` (`BG_CANVAS`, glow on, intensity 1.0, strength 1.0, bloom 0, threshold 0.5, additive). `off`, or no arg, adds none; anything else (`ON`, `yes`) warns. Engine glow is for the perf check only until Story 1.15's verdict |
| `--perf[=<s>]` | Story 1.12: a timed perf run, 60 s by default, `<s>` 1–600. On every spawn it locks the player's input, masks its `Hurtbox` off (no contact can hurt it or break the chain; World's spike poll still could, and `perf_worst` has no spikes), holds `--chain`'s n (or 20 without one) paid through `--chain`'s take-off arming, and moves it every physics tick along a vertical ping-pong down the room's centre at 100 px/s, from a tick counter. Two real lights ride along: since Story 1.23 a real flare (rank ALWAYS, stuck, at the player's light radius of the tick it is made; made once the chain is held and made again on the tick it burns out, every `flare_burn` seconds, so its fade is in the measured window) and, since Story 1.22, a real Ember Cache (rank CACHE, `Tuning` `cache_radius`). Both wake lurkers, who hunt them harmlessly: at chain 20 the flare ties the player's light, and a tie goes to the flare. It measures wall-clock frame times from the frame after the chain reaches n, then logs one summary line, `[room] dev: perf …`, and shows it in overlay 4; the autopilot keeps going after it. Built for `perf_worst`; the procedure is [perf.md](./perf.md) |

**A dev session loads and saves no slot** (Story 1.21 D12, sonlm 2026-11-25). A run that applied `--room`, `--chain`, `--hp`, `--difficulty` or `--perf` calls `Game.detach_slot()` before `Game.boot()`: no `slot_N.json` is read or written for the rest of the process, so `--room` always wins over a saved respawn point, and a dev room, chain or HP never reaches the file a normal run reads. The summary line ends `no slot loaded or saved`. `--log`, `--set` and `--glow` change only what is shown or logged, so with those alone the slot loads and saves as in a normal run; an arg that was refused (a warning) detaches nothing. A new arg states its side in its `ARGS` row (`detach`), and `test_dev_args` pins the table.

Args apply in the order `log`, `set`, `room`, `chain`, `hp`, `glow`, `perf`, and only when World is the current scene (a real run). A bad arg is a `push_warning` and the game still starts; never an error. A test that instances `world.tscn` gets an inert DevTools; to test an arg, set its `tokens` from World's `child_entered_tree`, connected before `add_child` (see `smoke_dev_tools.gd`).

**Overlays:** the backquote key (`` ` ``, action `dev_overlay`, physical keycode 96; no project action is bound to a function key) cycles, from off:

1. the play rect (`World.play_rect()`), the notice rect (`Sensing.notice_rect()`: the play rect shrunk by `Sensing.SCREEN_MARGIN`, 8 px), and both 60 px gutters with their 58 px usable bands;
2. every lit `LightSource` (the player's light, an Ember Cache (1.22), every burning flare (1.23: `flare 102 px`)): its radius ring, its reach ring (× 1.6, dashed and dim with "below notice" under 80 px) and `<kind> N px`, plus the player's HP line (`hp 3/4`, plus `inv 0.42 s` while invulnerable); every predator's state and target (`HUNT player`, `TELEGRAPH flare`) and ` stir N` while its eye is open, with a sense line to its target while it telegraphs or hunts; and a magenta `stir N` at the play rect's edge for a lurker off screen with its eye open (a stand-in for 1.27's edge cue). Each mark rides on a child of the node it marks, which the engine interpolates with its sprite (Story 1.20); the sense line's ends are blended by hand;
3. each exit (`side -> target`), the `spawn` / `up` / `down` entries, each `obj=` id at its cell, and `safe` at `World.last_safe_position()`, where a spike returns the player;
4. the readout, rebuilt at 4 Hz: `FPS`; `lights n/6, sprites m` (plus `, over k` when the always-lights alone exceed the budget), from `BudgetLight.counts()` on `World.light_rect()`, so it shows exactly what the light budget counts; `frame x.x ms, worst y.y ms` in wall time since mode 4 opened; with `--perf`, the run's progress, then its summary over up to three rows (a row over 90 characters wraps at a space); then the active `Clock` requests (each stays listed, greyed, 0.5 s after it ends);

then off. It works while paused (DevTools is `PROCESS_MODE_ALWAYS`). World marks use one cached unshaded `CanvasItemMaterial`, so they read under the darkness; screen marks sit on DevTools' own CanvasLayer 11, above the UI (10). Mode 3's marks at an actor's tick position can sit up to one physics tick off its interpolated sprite (accepted for a dev overlay); mode 2's ride on the actors. Nothing blinks.

## Testing

```bash
cd game
./run_tests.sh                 # imports, then runs unit + smoke tests; prints "== ALL GREEN" or exits 1
```

Run one suite on its own. Every test runs as a scene through `tests/runner.tscn`, so the `Game` autoload, `preload` and `class_name` all work:

```bash
godot --headless --path game --import                                # first, and again after pulling moved or renamed scripts (rebuilds the class_name cache)
godot --headless --path game res://tests/runner.tscn -- res://tests/test_chain_state.gd      # ChainState unit tests
godot --headless --path game res://tests/runner.tscn -- res://tests/test_health.gd           # Health: the damage table and causes against Spec, invulnerability, heals, the bank-heal threshold
godot --headless --path game res://tests/runner.tscn -- res://tests/test_log.gd              # Log
godot --headless --path game res://tests/runner.tscn -- res://tests/test_clock.gd            # Game.clock and the hitstop
godot --headless --path game res://tests/runner.tscn -- res://tests/test_display.gd          # Game.display: the scale rule, the window fit, inert under headless
godot --headless --path game res://tests/runner.tscn -- res://tests/test_state.gd            # Settings, SlotState, DiveState, Game and settings.json
godot --headless --path game res://tests/runner.tscn -- res://tests/test_room_loader.gd      # room validator, build, Room API and m1_shaft
godot --headless --path game res://tests/runner.tscn -- res://tests/test_room_sweep.gd       # the pure room sweeps on inline grids
godot --headless --path game res://tests/runner.tscn -- res://tests/test_deferred_owners.gd  # every deferred-work.md item has an owner
godot --headless --path game res://tests/runner.tscn -- res://tests/test_export_presets.gd  # the four export presets and their filters, through the exporter's own matcher over the real files
godot --headless --path game res://tests/runner.tscn -- res://tests/test_dev_args.gd         # DevTools' pure parts: URL query, arg grammar, validators, entry pick, Clock rows, mode 2's light marks, --glow/--perf, the perf run's path, stats and summary
godot --headless --path game res://tests/runner.tscn -- res://tests/test_fx.gd               # Fx's shared materials, built once; effects free themselves; the accessibility gate, the EFFECTS table and the sampled rates
godot --headless --path game res://tests/runner.tscn -- res://tests/test_light_budget.gd     # BudgetLight: the rule, apply() on nodes, the sprite fallback, the scene audit
godot --headless --path game res://tests/runner.tscn -- res://tests/test_sensing.gd          # Sensing: the 80 px floor, the inclusive reach, the notice rect's edges, stir, pick_target
godot --headless --path game res://tests/runner.tscn -- res://tests/test_strings.gd          # the string table: shape, registered, the en fallback, formats, every key reference, no dead key, copy rules, scene text
godot --headless --path game res://tests/runner.tscn -- res://tests/test_palettes.gd         # Palettes against DESIGN: tokens, the derived gutter, contrast floors, minimal overrides, ratios, the Deck mock regions
godot --headless --path game res://tests/runner.tscn -- res://tests/test_theme.gd            # the font's import pins and coverage, measured widths, the Theme's variations and pitches, CAP_TOP, play_text's outline, popups at 8 px
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_rooms.gd           # every room file: validation, cross-file links, sweeps, lurker guarantees
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_bot.gd             # the descent bot in every spine room
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_moves.gd           # the M1 move checks on m1_shaft
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_world.gd           # World: tree, framing, state wiring, respawn without a reload, R16 loop
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_room_swap.gd       # room swaps on the test rooms in tests/rooms/swap/
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_lurker.gd          # light sensing on tests/rooms/sensing/: the M1 trace, LightSource, retargeting with a stand-in flare, stirring and its pacing, Q1/Q2
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_health.gd          # HP on World with tests/rooms/hazards/: contact damage, the monitorable read, spikes and safe ground, bank-heal, death and respawn, the hit flash, the squash
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_dev_tools.gd       # DevTools in World: inert without args, the real command line, the SMOKE boot marker, each arg and bad arg, the overlay modes, light count, Clock rows, no function key
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_a11y.gd            # the accessibility gate on m1_shaft: shake off, the blink and its steady variant, the look-ahead on a pogo
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_palettes.gd        # the active zone in world.tscn: boot, exit, respawn and same-zone swaps; gutters, clear colour, popup outline
godot --headless --path game res://tests/runner.tscn -- res://tests/test_embers.gd           # the ember stages, pure: take_carried(), deposit_from(), apply_death() per tier, recover_cache(), the emit order, the cache's save shape, FR25 by source
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_embers.gd          # the Ember Cache in World: the drop spot (ground, mid-air, hazard, the up fallback), Easy and Hard, a second death, saves, a cache in an unknown room, a cache hunt
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_flare.gd           # Flare Toss with a real tap and a real flare: the toss, the flight and the surfaces, the burn and fade, no damage, the lure, the cling toss, the cap, a real World
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_perf.gd            # the perf kit in World: --perf=3 in perf_worst holds the chain and the budget every tick, the summary; --glow, bad --perf, the view rect, m1_shaft unchanged
```

Screenshots (needs a renderer):

```bash
xvfb-run -a godot --path game --rendering-driver opengl3 res://tests/runner.tscn -- res://tests/screenshot.gd /some/out_dir
```

### Writing tests

- A test is a script that `extends Node` and implements `func run() -> void`, which may `await`. It has a local `check(cond, msg)`; there is no framework. Don't use `--script`: under it, anything that names `Game` fails to compile.
- It prints `ok …` / `FAIL …` lines and a final line containing `PASS` or `FAILED`. `ok` lines and `[category]` Log lines never count as the verdict. It never calls `quit()`; the runner sets the exit code and fails a test that quits on its own.
- The runner fails a test that prints no `PASS` line, runs longer than 120 s, or logs any `SCRIPT ERROR` / `ERROR:` line, even if it printed `PASS` (a runtime error inside a helper aborts only the helper). That includes the test's teardown: after `run()` returns, the runner frees the test and watches two more frames. `push_warning` is allowed.
- `run()` starts two frames after the test enters the tree, because the first frame's delta carries the load time. Timers that expire in the same frame fire in creation order, so a real-time probe that must see a request still active is created before the request (see `test_clock.gd`).
- Extra arguments after the test path reach the test as `OS.get_cmdline_user_args()[1..]` (`screenshot.gd` reads its output folder there).
- **Pure rules → a new `tests/test_<subject>.gd`**, never into `test_chain_state.gd`. Build fresh state objects per case.
- **A guarantee every room must keep → `smoke_rooms.gd`** (or the bot, `smoke_bot.gd`), never a test on one room: they walk every `res://rooms/**/*.txt`, so a new room gets the check for free. Put the rule as a pure function over the grid in `tests/room_sweep.gd`, with a firing sample and a near-miss in `test_room_sweep.gd` (Story 1.10; the list is in [rooms.md](./rooms.md#room-checks)).
- **A move or a mechanic in a real room → `smoke_moves.gd`** (the M1 move checks on `m1_shaft`) or a new `smoke_*.gd`. Load the room standalone through `tests/room_harness.gd` (room, test player, `CameraRig`, stub `World`); World itself (spawn, respawn, framing, the R16 loop) is tested in `smoke_world.gd`, which instances `world.tscn`, and room swaps in `smoke_room_swap.gd`, on its own rooms in `tests/rooms/swap/` (`RoomLoader.add_root()`, `World.start_room` set before `add_child`); a respawn or loop builds a fresh room, so re-take references and turn its lurkers off again after each one; find positions through the room API (`entry_position()`, `is_solid()`, `cell_centre()`), never literal tile coordinates, and pick targets by position, never by group index. Add an `async` test, `await` it from `run()`, and drive it with `Input.action_press/release` (pass a `strength` for analog input; it skips the action deadzone, which `PlayerInput` applies itself). Gameplay reads `player.input` intents, never `Input` (Story 1.8). Frame math measured on 4.7.2: a press made after an `await` is first seen by the player two ticks later, and a read after an `await` sees the last tick the player ran (see `smoke_player_input.gd`). Use `place()` to teleport, and wait with `frames()` / `seconds()` (physics frames).
- Order matters in a smoke test that shares one room and player (`smoke_moves.gd`). Reset what you touch: `chain.break_chain()`, the lurkers' `set_physics_process(true)` (or pause all but one, as `smoke_rooms.gd`'s `_only(lurker)` does), the player's `set_physics_process(true)`, `Game.clock.clear()`, any action you pressed; a test that changes `Game` state ends with `Game.reset_for_tests()`. A test never calls `Game.boot()` against the real folder, so tests never load or write the real `user://settings.json`: a test that checks the file first points `Game.store.dir` at a temp folder it creates and removes (see `test_state.gd`). Only `test_state.gd` boots, on that temp folder and as its last case, because `reset_for_tests()` leaves the process booted. A test that leaves the player dead, or a lurker hunting, must be followed by a fresh room (`RoomHarness.free_all()`, wait two process frames so the old stub `World` is gone, then `build()`; see `smoke_rooms.gd`'s `_free()`). Free every node a test builds: an exit-time leak prints an engine `ERROR:`.
- **Slot saves are unarmed in a test** (Story 1.21 D7). `Game.save_now()` and `Game.save_progress()` return `ERR_UNCONFIGURED` and write nothing until `Game.boot()`, `Game.load_slot()` or `Game.new_game()` ran in the process, and `Game.reset_for_tests()` disarms them again. So a World added by a test, or a rest inside a smoke test, can never reach the player's `user://slot_1.json`. A test that wants a real save creates a temp folder, sets `Game.store.dir` to it, and calls `Game.load_slot(1)` or `Game.new_game(1)`; it points the store there again after **every** `Game.reset_for_tests()` (the reset points it home), counts warnings and signals instead of assuming them, compares "left as it was" files byte for byte, and writes its expected values and its corrupt, newer or older files by hand (`tests/test_saves.gd`). A parsed file's numbers are floats, and `{"a": 1} != {"a": 1.0}`.
- **Tests are found by name** (Story 1.9): `run_tests.sh` runs every `tests/test_*.gd`, then every `tests/smoke_*.gd`, in C sort order. Name a new test to match and it runs; there is no list to edit, and a helper must not use either prefix (`runner.gd`, `room_harness.gd`, `spec.gd`, `screenshot.gd`). An empty glob fails the run. `run_tests.sh` greps for lines that start with `ok`/`FAIL` or contain `PASS`/`FAILED` (plus error lines and their `at:` traces), so keep that output format. It also kills a run after 150 s of wall-clock time, which catches a test that blocks the main loop, where the runner's watchdog can't fire.

### Design guarantees: `tests/spec.gd`

A guarantee the GDD promises (telegraph ≥ 0.75 s, bot chain ≥ 5, base light 40 px never noticed, the 80 px notice floor, a ledge within a 1.5 s / 315 px fall) is a `Spec` const with its `## GDD …` citation. Tests `const Spec := preload("res://tests/spec.gd")` and compare against it, never against the tuning value under test, so loosening tuning fails the suite (`smoke_rooms.gd`, `smoke_bot.gd`, `test_tuning.gd`'s `stat_floor_errors()`, which tries every combination of gear rows). A new guarantee gets a `Spec` const and a test before the feature is done; changing one means changing the GDD first, with sonlm. `test_lint` fails a `Spec` const without a `## GDD` citation.

### The architecture lint: `tests/test_lint.gd`

A text scan of every `.gd` under `game/scripts/` (comments dropped, string contents ignored by the identifier rules; escapes, `"""` blocks and `\`-continued strings handled). A hit prints `FAIL lint <file>:<line> <rule>`, with the path relative to `scripts/` (`spec_citation` names `tests/spec.gd`). Three rules also get class names built at run time by `layer_names()`: the `class_name` lines (annotated ones too) and autoloads of each layer, ClassDB's Node classes for `rules/`, and `dev/`'s own for `dev_ref`.

| Rule | Fails on | Allowed in |
|---|---|---|
| `time_scale` | `Engine.time_scale =` (or `*=`, `+=`, …), `Engine.set_time_scale(`, `Engine.set("time_scale", …)` | `core/clock.gd` |
| `raw_input` | `Input`, `InputMap`, `InputEvent*`, `func _input` / `_unhandled_input` / `_unhandled_key_input` / `_shortcut_input` / `_gui_input`, the `gui_input` signal | `actors/player_input.gd`, `core/devices.gd`, `ui/kit/`, `dev/` (DevTools reads only its own `dev_overlay` action and ships in no release build) |
| `print` | `print(` and its family (`printerr`, `print_rich`, `print_verbose`, `print_stack`, `print_tree`, …), `@GlobalScope.print(` | `core/log.gd` |
| `free` | `.free()`, bare `free()`, `free.call_deferred()`, `call_deferred("free")` | — |
| `root_path` | `"/root/` node paths, `$/root/…`, `get_tree().root.get_node(` | — |
| `keycode` | any `KEY_*` constant | `ui/kit/` |
| `random` | `randf`, `randi`, `randf_range`, `randi_range`, `randfn`, `randomize`, `seed`, `rand_from_seed`, `.pick_random()`, `.shuffle()`, `RandomNumberGenerator` | `world/camera_rig.gd` (shake) |
| `rules_purity` | in `rules/`: `Node*` and every other Node class (ClassDB), `Input*`, `Engine*`, `OS`, `Time`, `SceneTree`, `get_tree(`, file access (`FileAccess`, `DirAccess`, `ResourceLoader`, `ResourceSaver`, `ConfigFile`), `ProjectSettings`, `DisplayServer`, `Game`, `Audio`, any class or autoload from `core/` or above, `load(`, a `preload` other than `scripts/rules/` or a sibling `name.gd` | — |
| `core_layer` | in `core/`: a `class_name` or autoload from `world/ actors/ objects/ moments/ ui/ audio/ dev/` (collected at run time), or a path into them | — |
| `dev_ref` | outside `dev/`: `DevTools`, any `class_name` declared under `dev/` (collected at run time), or a `res://scripts/dev/` / `res://scenes/dev/` path | `world/world.gd`'s one guarded line, `add_child(load("res://scripts/dev/dev_tools.gd").new())` right under `if OS.is_debug_build():`, once per file (the row's `once` field); a tree check proves the real `world.gd` holds it exactly once |
| `raw_light` | `PointLight2D.new(` or `extends PointLight2D` (AR46, Story 1.12: every 2D light is a `BudgetLight`, or the ≤ 6 budget can't see it); a `PointLight2D` type annotation is fine. `.tscn` files are covered by `test_light_budget`'s scene audit instead | `core/budget_light.gd` |
| `tests_ref` | any `res://tests/` path (release exports exclude `tests/*`, Spec included) | — |
| `state_write` | outside `rules/`: a field of `Game.settings/slot/dive/tuning/display/palette` assigned (any assignment operator, nested fields and indexes) or written through reflective `.set(` / `.set_indexed(` / `.set_deferred(`; a container mutator on `settings/slot/dive/tuning` (`.append`, `.erase`, `.clear`, …; `display` and `palette` hold no mutable containers); or replacing a `Game.*` instance. A rule method such as `Game.palette.set_zone()` is the write and stays quiet | — |
| `light_query` | in `actors/`: `get_first_node_in_group(` / `get_nodes_in_group(` / `is_in_group(` with `"player"` or `&"player"`, and the type test `is Player` / `as Player` (review of 1.20). It can't see a group name held in a const, a node path to the player or a duck-typed read: review covers those (AR29, Story 1.20 D11: predators sense light through `LightSource` + `Sensing`, group `light_source`; its FAIL line says so). `player.gd`'s own `add_to_group("player")` is quiet; `dev/` and `world/` are outside it. An actor that truly needs the player later goes in `allow` with its reason | — |
| `raw_text` | a text sink (`.text =` / `+=`, `tooltip_text =`, `placeholder_text =`, `set_text(`, `popup(`, `draw_string(`, `draw_multiline_string(`, `add_item(`, `append_text(`, `add_text(`) followed on the same line by a string literal that holds two letters once its `%` conversions and escapes are taken out (AR41, Story 1.17: player text goes through `tr()`; code review, sonlm: was "two lowercase letters in a row", which let `"On"`, `"OK"` and `"PAUSED"` through). `text =` is a sink with or without a dot (a `Label` script's own `text = "Resume"`); `var text` and `const text` are declarations. Quiet on a key-shaped literal (`tr("MENU_RESUME")`), a StringName (`&"dash_speed"`) and numeric formats (`"x%d  +%d"`, `"%dx"`: one letter). The pattern consumes whole literals after the sink, so `tr("POPUP_BANKED") % amount` stays quiet. Any other text literal on a sink line fires (`add_item(tr("MENU_X"), "icon")`): hoist it into a variable. It can't see text built in a variable on an earlier line, a sink and its literal on different lines (a wrapped call) or a sink reached by name (`call("set_text", …)`). `dev/` is skipped (debug text, never shipped); scenes are `test_strings`' scene check | — |
| `a11y_gate` | the accessibility keys anywhere: `reduce_flashing` / `reduced_motion` as an identifier (not after `Fx.`), `settings.shake` on any name ending in `settings` (so `_settings.shake` too), or `"reduce_flashing"` / `"reduced_motion"` / `"shake"` as a string (AR57, Story 1.16: one gate; everything asks `Fx.reduce_flashing()` / `shake_on()` / `reduced_motion()`). `dev/` is skipped (DevTools sets keys generically through `SCHEMA`) | `core/fx.gd`, `rules/settings.gd` |

**Fix the code, never the lint.** A rule that hits correct code is a broken rule: fix its pattern in `RULES` and add a sample that shows why. Every rule has sample lines in `SAMPLES` (fires; quiet on an allowed path, in a comment and, for identifier rules, in a string). It can't see aliasing through a local, a write through a call's result, a singleton or method reached by name, or script inside `.tscn` files; review covers those.

## Player-facing text

Every word the player reads comes from `game/text/strings.csv` (AR41, NFR17; Story 1.17). M2 ships English only.

- **The table:** header `keys,en`, one row per key. Keys are UPPER_SNAKE with at least two segments, and the first is a listed domain prefix: `MENU`, `DEATH`, `TIER`, `NPC`, `JOURNAL`, `DEV`, `POPUP` (`PREFIXES` in `tests/strings_check.gd`). A story that adds a domain adds its prefix there and here. Text escapes (`\n`, `\t`) are unescaped on import (`unescape_translations=true`, committed in `strings.csv.import`). `%d` / `%s` stay in the text and are filled after the lookup: `tr("POPUP_BANKED") % amount`.
- **Re-import and commit the `.translation`.** Godot imports the CSV to `text/strings.en.translation`, registered in `project.godot` (`[internationalization] locale/translations`). Commit it with the CSV. `run_tests.sh` and `tools/export.sh` both import first, and the import regenerates the `.translation` whenever its CSV changed since the last import (an edit, or a pull). `test_strings` therefore sees a stale `.translation` only when the import left it alone (Story 1.17 code review), so both scripts also check the tree: they fail while a `.translation` differs from the commit and its CSV does not, which means the committed one is stale. Commit the regenerated file and the failure goes. `tools/export.sh` also fails when its import rewrote a tracked file on a clean tree. Re-importing an unchanged CSV gives the same bytes.
- **`tr()` in nodes, `TranslationServer.translate()` in static code** (`tr()` is an Object method; `Fx` and `rules/` have no node). Keys held as data (E4/E5 dialogue tables, death lines per cause) are whole string literals; the scan reads them too.
- **Every key appears whole as a literal somewhere in `scripts/`, or as a scene's `text` value** (a `Control` translates its own text). Never compose one (`tr("DEATH_%s_LINE" % cause)`): `tr()` returns the key itself when it is missing, so the screen would show `DEATH_FALL_LINE` and no scan could tell. `test_strings` fails a literal passed to `tr()` that is not key-shaped or is only part of the argument (`tr("MENU_ITEM" + str(i))`), a key the table lacks, and a key nothing references (no dead text). The lint `raw_text` fails raw text at a text sink, and `test_strings` fails raw text in a scene's text properties (`text`, `tooltip_text`, `placeholder_text`, `popup/item_0/text`), by the same test: two letters, not a key.
- **A formatted key lists its conversions.** `FORMATS` in `tests/strings_check.gd` maps a key to the conversions its text holds (`"POPUP_BANKED": ["%d"]`); a key not listed takes none. `test_strings` fails a row whose conversions differ, and any other `%`: when the count is off, GDScript's `%` logs an engine error and draws the text unformatted.
- **Numbers carry no key.** The HUD and in-world numbers (`x12  +24`) are format strings, not text (UX-DR150).
- **Voice** (UX-DR54–56, NR25): terse field notes; name shapes, never colours; never "roguelike" or "Downwell-like"; never a completion percentage. `test_strings` holds what a test can (the banned words, "rogue-like" included, `%%` / "percent" / a lone `%`, colour words outside `NPC_` / `JOURNAL_`, whose prose follows `narrative-design.md`); the rest is review. There is no voice acting.
- **Workflow (NR2):** sonlm approves new copy before it is committed. Story text (NPC lines, documents, death lines, Memorial names) also needs sonlm's three approved voice-anchor lines for that speaker first. Don't add keys "for later": an unused key fails the suite.
- **Font and styles:** the Fusion Pixel Font 8 px is the project's default font (`gui/theme/custom_font`), so every `Control` draws it. Text under `Gutters` or `ScreenRouter` gets `ThemeBuilder.theme()` (size 8; Label variations `HudValue`, `HudValueLarge`, `MenuItem`, `BodyLine`). Text over the play area uses `TextStyle.play_text(color, outline)` (`ThemeBuilder.play_text` in `ui/`): the 1 px four-side outline. Place a Label at `y - TextStyle.CAP_TOP` to put its cap top on a DESIGN y coordinate. Never draw the face at a fractional size (8 or 16 only).
- **UI colours:** read `Game.palette.color(Palettes.Role.X)` (`HP`, `LABEL`, `EMPTY`, `RULE`, `SURFACE`, `GUTTER`) and re-apply on `Game.palette.changed`, never caching a colour by zone id (E4's cross-fade emits blended colours). Amber and red are `Palettes.AMBER` / `RED`. Menus outside play read `Palettes.role_in(Palettes.DEFAULT_ZONE, …)`. Never a colour literal for UI; the Theme carries none.

## Edit Art

1. Edit or add a grid in `tools/sprites/<name>.txt`. One char = one pixel, `.` = transparent, keys from `palette_edge.txt`.
2. From the repo root: `python3 tools/build_sprites.py`
3. Re-import: open the project, or run `godot --headless --path game --import`.
4. Commit the `.txt`, the `.png` and any new `.png.import`.

Never hand-edit `game/art/*.png`; the next build overwrites them. Do not name a grid `light.txt`.

**Animation strips.** A grid file may hold several frames of the same size, separated by exactly one empty line. `build_sprites.py` renders them left to right, in file order, as one strip PNG (what a `Sprite2D` with `hframes` reads). A file with one frame renders as before. Frames of different sizes, a whitespace-only row, or two empty lines in a row between frames are errors naming the line, so a stray blank line can't silently cut a sprite in two.

### Art from Aseprite (or any pixel editor)

The grid stays the source; the editor's PNG is only how it gets there.

1. Load `tools/sprites/palette_edge.gpl` in Aseprite (Palette menu > Load Palette). It is committed, generated from `palette_edge.txt`; after a palette change, regenerate it with `python3 tools/import_sprite.py --gpl tools/sprites/palette_edge.gpl` (`test_sprites` fails while it is stale). Its entry 0 is a spare magenta "transparent" slot, because an Indexed Aseprite sprite treats index 0 as transparent: slot `0` (the outline colour) sits at index 1, so it never vanishes. Never paint with the magenta slot.
2. Draw with those colours only, on a transparent layer: no anti-aliasing, no partial opacity. Draw facing right; the game mirrors for left.
3. Export one frame as PNG (File > Export As), or a horizontal strip (File > Export Sprite Sheet: Horizontal Strip, no borders, padding or trim). RGBA, or Indexed with the transparent colour left at index 0. 8-bit, one image (an animated PNG and a 16-bit PNG are refused).
4. `python3 tools/import_sprite.py <png> <name>` for one frame, or add `--cell 16x24` (or `--frames N`) for a strip. `<name>` is lower snake case (`a-z`, `0-9`, `_`), never `light` or `palette_*`. It writes `tools/sprites/<name>.txt` with LF line endings, through a temp file, and refuses to overwrite an existing grid without `--force`.
5. Steps 2–4 of Edit Art above: build, re-import, commit the grid, the PNG and the `.import` together.

The importer matches every pixel to a palette colour exactly. Alpha 0 is `.` (even when its RGB is slot 0's `#0d0b14`), and alpha 255 is the colour's key. An unknown colour or a partly transparent pixel stops it, naming the frame and pixel, and nothing is written. Free art (CC0 packs) comes in the same way, after it is recoloured to the palette.

Test the pipeline: `python3 -m unittest discover -s tools -p 'test_*.py' -v` (it works in temporary folders and also checks that every committed grid rebuilds its committed PNG pixel for pixel).

## Edit the Level

The level is `game/rooms/l1/m1_shaft.txt`: a header, `---`, then the grid (`#` wall, `.` empty, `P` spawn, `c` walker, `h` hoverer, `L` lurker; the full format and legend are in [rooms.md](./rooms.md)). It is a spine room, so it must stay 22 columns wide including the walls. Edit the text and run the tests: `smoke_rooms` validates every room file (errors print as `file:row:col`), checks ids and exit links across files, sweeps each room (no fall between ledges over 19 rows (FR57), cling stretches 6–10 wide, hazard pits, no enemy within 3 cells of the arrival from below) and runs the lurker guarantees; `smoke_bot` plays each spine room from the top to its down exit and needs a chain ≥ 5. A new room file gets all of this with no test edit ([rooms.md → Room checks](./rooms.md#room-checks)). `test_room_loader` pins `m1_shaft`'s counts, ledge rows and exits, so a change there is a deliberate edit of those pins. A bad file never builds: the loader prints its errors, and `World` stays in the current room (a bad start room is an assert; a bad respawn point falls back to the dive's start, `World.start_room` at `start_entry`; DevTools checks a `--room=` room before it sets them, so a bad one warns and `m1_shaft` loads).

## Common Tasks

| Task | Where |
|---|---|
| Tune movement or combat feel | consts in `scripts/rules/tuning.gd` (read through `Game.tuning`; the Player node's Inspector no longer shows them). Change the matching GDD table too. The light's kick stays in `player.gd` (`LIGHT_KICK`) and its easing is in `scripts/actors/light_source.gd` (`LIGHT_LERP`, Story 1.20); camera consts are in `scripts/world/camera_rig.gd` |
| Tune the chain, light, bloom or embers curve | constants and `ember_value()` in `chain_state.gd`, plus unit tests |
| Tune a lurker | the `LURKER_*` consts in `scripts/rules/tuning.gd`; change the matching GDD table too, and keep `LURKER_TELEGRAPH_TIME ≥ 0.75`. The sensing consts (80 px, × 1.6, 96 px, the 8 px margin) live in `scripts/rules/sensing.gd`: they are the GDD's numbers, not tuning, and `test_sensing` holds them to `Spec` (Story 1.20). `Lurker.STIR_STEP_TIME` (0.35 s) is presentation |
| Add an enemy that can be pogoed | A body on layer 3 (value 4) with a `take_hit()` method; add it to group `enemy` and give it a `contact_cause()` if contact should hurt |
| Add a predator | An `Area2D` on layer 4 (value 8) in group `predator` with a `contact_cause()`; `monitorable` only while it may damage (the player's poll reads it every tick). It senses light only through group `light_source` and `Sensing` (notice to wake and telegraph, sense to hunt), never the player (lint `light_query`); a stored light is asked `LightSource.live()` before each use, and a function that may receive a freed one takes it untyped (Story 1.20) |
| Damage the player | `player.hurt(cause, from)` (Story 1.19): the one damage path; `from` is where the hit came from (knockback away from it), `Vector2.INF` for none. A new cause goes in `Health.CAUSES` (mapped to a `DAMAGE` row; cause ids are save data, never renamed), never a direct `health.hit()` |
| Add a hazard tile | `docs/rooms.md`'s legend first, then `RoomLegend.HAZARDS`; World's hazard poll and the room sweeps cover it (see the spike `^`) |
| New player-facing text | a row in `game/text/strings.csv` (copy approved by sonlm, NR2), re-import, commit the CSV and `strings.en.translation`, and use `tr("KEY")`; see [Player-facing text](#player-facing-text) |
| Colour a UI element | `Game.palette.color(Palettes.Role.X)`, re-applied on `Game.palette.changed` (menus outside play: `Palettes.role_in(Palettes.DEFAULT_ZONE, …)`); amber and red are `Palettes.AMBER` / `RED`; never a colour literal; see the UI colours note under [Player-facing text](#player-facing-text) |
| New effect | A static function in `fx.gd`, drawn with the shared `Fx.unshaded()` (or `Fx.additive()` for a glow) so it reads in the dark; never a new `Material` per effect |
| Add a light | Build a `BudgetLight` (`scripts/core/budget_light.gd`), never a raw `PointLight2D` (lint `raw_light`; scenes are checked by `test_light_budget`'s audit), on the shared `art/light.png`, sized by `texture_scale`. Set its `rank`: ALWAYS only for the player and flares, CACHE for the Ember Cache, GLOW (the default) for everything else. Owners set `energy`, `color`, `texture_scale` and `visible`; only the budget writes `enabled`. A demoted light is relit no sooner than 21 ticks after its demotion (Story 1.23), so a test that expects a relight passes `apply()` its own `now` or waits |
| Add an input action | `project.godot` `[input]` (Project Settings → Input Map) and `game/README.md` |
| Add a DevTools arg | one `ARGS` row in `scripts/dev/dev_tools.gd` (`{help, apply, repeat}`) + its apply method + a pure static validator + `test_dev_args` cases (+ a `smoke_dev_tools` case when it touches the scene) |
| Measure performance | [perf.md](./perf.md): `godot --path game -- --room=perf_worst --perf`, then with `--glow=on` |
| Make a build | on the server, `tools/export.sh` (after `./run_tests.sh` for a build you will share); output in `builds/<version>/`; [build.md](./build.md) |
| Exclude something from release | add it to the three release presets' `exclude_filter` in `game/export_presets.cfg` and to `RELEASE_EXCLUDES` in `tests/test_export_presets.gd`; `tools/export.sh`'s PCK check names the forbidden prefixes |
| Add a web export option | write it explicitly in both web presets (`[preset.2.options]` and `[preset.3.options]`) of `game/export_presets.cfg` and check it in `tests/test_export_presets.gd` (Story 1.14: `html/canvas_resize_policy`, `html/focus_canvas_on_start`, the `html/head_include` key guard) |

After any rule change, update the matching GDD table. Note playtest-driven changes in `_bmad-output/implementation-artifacts/`.

## Build and Deploy

Builds come from the server: `tools/export.sh` validates the rooms and the string keys, exports `Windows`, `Linux`, `Web` and `Web debug` from the committed `game/export_presets.cfg`, copies the font's and Godot's licences beside each build, checks every PCK for dev and test content, measures the web download (gzip, under 30 MB), boots the Linux release build and runs the web smoke (`tools/web_smoke/`, headless Chromium). The output is `builds/<yyyymmdd>-<sha7>[-dirty]/`. Setup, the step table, playing builds on the laptop (rsync, or the web build through an SSH tunnel), itch.io and the engine upgrade checklist are in [build.md](./build.md). There is no CI: the server runs it by hand.

## Git

- Work happens on feature branches (`feat/m1-prototype` now); `main` is the PR base.
- Planning commits use the `docs:` prefix (Conventional Commits style).
- `game/.godot/`, `game/export/`, `/builds/` and the web smoke's `node_modules/`, `test-results/` and `playwright-report/` are ignored. `.uid` and `.import` files are committed, and so is `tools/web_smoke/package-lock.json`.
