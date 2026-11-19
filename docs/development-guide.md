# The Unbroken Chain — Development Guide

**Date:** 2026-11-11

## Environment

Development is split across two machines:

| Machine | Used for |
|---|---|
| **Laptop** (Godot editor with a display) | Playing builds (F5), feel tuning, editor work |
| **Headless server** (SSH) | Headless tests, the sprite pipeline, git, docs |

## Prerequisites

| Tool | Version seen | Needed for |
|---|---|---|
| Godot | 4.7.2 stable | Everything in `game/` |
| Python 3 + Pillow | Pillow 12.1.1 | `tools/build_sprites.py` only |
| `xvfb-run` (optional) | — | `tests/screenshot.gd` on the headless server |

No package manager, addons or environment variables are needed. Optional: set `GODOT=/path/to/godot` if `godot` is not on your PATH. `run_tests.sh` falls back to `~/.local/bin/godot`.

## Run the Game

Open `game/` in Godot 4.7 and press **F5**. The main scene is `scenes/world/world.tscn`. The controls are in [`game/README.md`](../game/README.md).

Brightness keeps the level saved in `user://settings.json` unless the run passes `--set=brightness:N` (below), and you restart by relaunching. A death respawns you at the top without a reload, in a rebuilt room (crawlers you killed stay gone); falling through the floor hole loops you back to the top.

### DevTools (debug builds only)

`World._ready()` adds `DevTools` (`scripts/dev/dev_tools.gd`) in its first statement: `if OS.is_debug_build(): add_child(load("res://scripts/dev/dev_tools.gd").new())`, a path string, never `preload`. From Story 1.13 the release presets exclude `scripts/dev/*`, so none of it ships (until then a release build simply never loads it); editor runs and debug exports have it. It builds its nodes in code (no `.tscn`), and in a run with no args it changes nothing.

**Entry args** go after `--`:

```bash
godot --path game -- --room=m1_shaft --chain=8 --set=brightness:0
```

In the editor, use Debug → Customize Run Instances and its per-instance arguments (stored in `.godot/`, never committed). **Never** set Project Settings `editor/run/main_run_args`: it is written into the committed `project.godot`. A web debug build reads the URL query instead (`?room=m1_shaft&chain=8`) through `JavaScriptBridge.eval("window.location.search")`, which returns null off the web, so there is no `OS.has_feature("web")` branch.

| Arg | Does |
|---|---|
| `--room=<id>` | Starts the dive in that room, at its `P`, else its `up` entry (arriving from above, falling), else `down`. A death respawns there while no respawn point is set; DevTools never writes `Game.dive`'s respawn point (`World.start_room` / `start_entry`). An unknown id or an invalid room is a warning, and the default start room (`m1_shaft`) loads |
| `--chain=<n>` | 0–20 (`ChainState.MAX_CHAIN`), armed on every spawn (every life). Paid on the first physics tick that ends with the player off the floor, as n `ChainState.add_hit()` calls (count n, held n(n+1)/2, best chain n); then it breaks and banks like any chain |
| `--log=<cat>,<cat>` | Turns on those `Log` categories (names from `Log.CATEGORIES`, any case). An unknown name warns and is skipped. `Log.set_enabled()` is called once, with every `--log` value merged, and only if they name at least one valid category (none, or `--log=` alone, warns and leaves `Log` as it was) |
| `--set=<key>:<value>` | Any `Settings` key, typed by its default (int, float, bool `true`/`false`); repeatable. Goes through `Game.override_setting()`: the value survives `Game.boot()`'s load, and a session with any override writes no `settings.json` at all (not even a rewrite or another key's change). `--set=brightness:0`…`3` is how brightness changes until Options (Story 1.36) |
| `--glow=on\|off` | Story 1.12: `on` adds a `WorldEnvironment` named `Glow` under DevTools, with a code-built `Environment` (`BG_CANVAS`, glow on, intensity 1.0, strength 1.0, bloom 0, threshold 0.5, additive). `off`, or no arg, adds none; anything else (`ON`, `yes`) warns. Engine glow is for the perf check only until Story 1.15's verdict |
| `--perf[=<s>]` | Story 1.12: a timed perf run, 60 s by default, `<s>` 1–600. On every spawn it locks the player's input, masks its `Hurtbox` off (no kill or knock can break the chain), holds `--chain`'s n (or 20 without one) paid through `--chain`'s take-off arming, and moves it every physics tick along a vertical ping-pong down the room's centre at 100 px/s, from a tick counter. A flare stand-in (ALWAYS, at the player's light radius) and an Ember Cache stand-in (CACHE, 80 px) ride along. It measures wall-clock frame times from the frame after the chain reaches n, then logs one summary line, `[room] dev: perf …`, and shows it in overlay 4; the autopilot keeps going after it. Built for `perf_worst`; the procedure is [perf.md](./perf.md) |

Args apply in the order `log`, `set`, `room`, `chain`, `glow`, `perf`, and only when World is the current scene (a real run). A bad arg is a `push_warning` and the game still starts; never an error. A test that instances `world.tscn` gets an inert DevTools; to test an arg, set its `tokens` from World's `child_entered_tree`, connected before `add_child` (see `smoke_dev_tools.gd`).

**Overlays:** the backquote key (`` ` ``, action `dev_overlay`, physical keycode 96; no project action is bound to a function key) cycles, from off:

1. the play rect (`World.play_rect()`), the notice rect (the play rect shrunk by `Lurker.SCREEN_MARGIN`, 8 px), and both 60 px gutters with their 58 px usable bands;
2. the player's light radius and its notice reach (× 1.6), the reach dashed and dim with "below notice" while the light is under 80 px, plus each predator's state and a line to the player while it senses them;
3. each exit (`side -> target`), the `spawn` / `up` / `down` entries, and each `obj=` id at its cell;
4. the readout, rebuilt at 4 Hz: `FPS`; `lights n/6, sprites m` (plus `, over k` when the always-lights alone exceed the budget), from `BudgetLight.counts()` on `World.light_rect()`, so it shows exactly what the light budget counts; `frame x.x ms, worst y.y ms` in wall time since mode 4 opened; with `--perf`, the run's progress, then its summary over up to three rows; then the active `Clock` requests (each stays listed, greyed, 0.5 s after it ends);

then off. It works while paused (DevTools is `PROCESS_MODE_ALWAYS`). World marks use one cached unshaded `CanvasItemMaterial`, so they read under the darkness; screen marks sit on DevTools' own CanvasLayer 11, above the UI (10). A mark at an actor can sit up to one physics tick off the interpolated sprite (accepted for a dev overlay). Nothing blinks.

## Testing

```bash
cd game
./run_tests.sh                 # imports, then runs unit + smoke tests; prints "== ALL GREEN" or exits 1
```

Run one suite on its own. Every test runs as a scene through `tests/runner.tscn`, so the `Game` autoload, `preload` and `class_name` all work:

```bash
godot --headless --path game --import                                # first, and again after pulling moved or renamed scripts (rebuilds the class_name cache)
godot --headless --path game res://tests/runner.tscn -- res://tests/test_chain_state.gd      # ChainState unit tests
godot --headless --path game res://tests/runner.tscn -- res://tests/test_log.gd              # Log
godot --headless --path game res://tests/runner.tscn -- res://tests/test_clock.gd            # Game.clock and the hitstop
godot --headless --path game res://tests/runner.tscn -- res://tests/test_state.gd            # Settings, SlotState, DiveState, Game and settings.json
godot --headless --path game res://tests/runner.tscn -- res://tests/test_room_loader.gd      # room validator, build, Room API and m1_shaft
godot --headless --path game res://tests/runner.tscn -- res://tests/test_room_sweep.gd       # the pure room sweeps on inline grids
godot --headless --path game res://tests/runner.tscn -- res://tests/test_deferred_owners.gd  # every deferred-work.md item has an owner
godot --headless --path game res://tests/runner.tscn -- res://tests/test_dev_args.gd         # DevTools' pure parts: URL query, arg grammar, validators, entry pick, Clock rows, mode 2's light marks, --glow/--perf, the perf run's path, stats and summary
godot --headless --path game res://tests/runner.tscn -- res://tests/test_fx.gd               # Fx's shared materials, built once; effects free themselves
godot --headless --path game res://tests/runner.tscn -- res://tests/test_light_budget.gd     # BudgetLight: the rule, apply() on nodes, the sprite fallback, the scene audit
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_rooms.gd           # every room file: validation, cross-file links, sweeps, lurker guarantees
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_bot.gd             # the descent bot in every spine room
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_moves.gd           # the M1 move checks on m1_shaft
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_world.gd           # World: tree, framing, state wiring, respawn without a reload, R16 loop
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_room_swap.gd       # room swaps on the test rooms in tests/rooms/swap/
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_dev_tools.gd       # DevTools in World: inert without args, the real command line, each arg and bad arg, the overlay modes, light count, Clock rows, no function key
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
| `state_write` | outside `rules/`: `Game.settings/slot/dive/tuning.<field>…` assigned (any assignment operator, nested fields and indexes), a container mutator on one (`.append`, `.erase`, `.clear`, …), reflective `.set(`, or replacing a `Game.*` instance | — |

**Fix the code, never the lint.** A rule that hits correct code is a broken rule: fix its pattern in `RULES` and add a sample that shows why. Every rule has sample lines in `SAMPLES` (fires; quiet on an allowed path, in a comment and, for identifier rules, in a string). It can't see aliasing through a local, a write through a call's result, a singleton or method reached by name, or script inside `.tscn` files; review covers those.

## Edit Art

1. Edit or add a grid in `tools/sprites/<name>.txt`. One char = one pixel, `.` = transparent, keys from `palette_edge.txt`.
2. From the repo root: `python3 tools/build_sprites.py`
3. Re-import: open the project, or run `godot --headless --path game --import`.
4. Commit the `.txt`, the `.png` and any new `.png.import`.

Never hand-edit `game/art/*.png`; the next build overwrites them. Do not name a grid `light.txt`.

## Edit the Level

The level is `game/rooms/l1/m1_shaft.txt`: a header, `---`, then the grid (`#` wall, `.` empty, `P` spawn, `c` walker, `h` hoverer, `L` lurker; the full format and legend are in [rooms.md](./rooms.md)). It is a spine room, so it must stay 22 columns wide including the walls. Edit the text and run the tests: `smoke_rooms` validates every room file (errors print as `file:row:col`), checks ids and exit links across files, sweeps each room (no fall between ledges over 19 rows (FR57), cling stretches 6–10 wide, hazard pits, no enemy within 3 cells of the arrival from below) and runs the lurker guarantees; `smoke_bot` plays each spine room from the top to its down exit and needs a chain ≥ 5. A new room file gets all of this with no test edit ([rooms.md → Room checks](./rooms.md#room-checks)). `test_room_loader` pins `m1_shaft`'s counts, ledge rows and exits, so a change there is a deliberate edit of those pins. A bad file never builds: the loader prints its errors, and `World` stays in the current room (a bad start room is an assert; a bad respawn point falls back to the dive's start, `World.start_room` at `start_entry`; DevTools checks a `--room=` room before it sets them, so a bad one warns and `m1_shaft` loads).

## Common Tasks

| Task | Where |
|---|---|
| Tune movement or combat feel | consts in `scripts/rules/tuning.gd` (read through `Game.tuning`; the Player node's Inspector no longer shows them). Change the matching GDD table too. Light presentation consts stay in `player.gd`; camera ones are in `scripts/world/camera_rig.gd` |
| Tune the chain, light, bloom or embers curve | constants and `ember_value()` in `chain_state.gd`, plus unit tests |
| Tune a lurker | the `LURKER_*` consts in `scripts/rules/tuning.gd`; change the matching GDD table too, and keep `LURKER_TELEGRAPH_TIME ≥ 0.75`. The sensing consts stay in `lurker.gd` until 1.20 |
| Add an enemy that can be pogoed | A body on layer 3 (value 4) with a `take_hit()` method; add it to group `enemy` if contact should knock back |
| Add a predator | An `Area2D` on layer 4 (value 8) in group `predator`; `monitorable` only while it may kill |
| New effect | A static function in `fx.gd`, drawn with the shared `Fx.unshaded()` (or `Fx.additive()` for a glow) so it reads in the dark; never a new `Material` per effect |
| Add a light | Build a `BudgetLight` (`scripts/core/budget_light.gd`), never a raw `PointLight2D` (lint `raw_light`; scenes are checked by `test_light_budget`'s audit), on the shared `art/light.png`, sized by `texture_scale`. Set its `rank`: ALWAYS only for the player and flares, CACHE for the Ember Cache, GLOW (the default) for everything else. Owners set `energy`, `color`, `texture_scale` and `visible`; only the budget writes `enabled` |
| Add an input action | `project.godot` `[input]` (Project Settings → Input Map) and `game/README.md` |
| Add a DevTools arg | one `ARGS` row in `scripts/dev/dev_tools.gd` (`{help, apply, repeat}`) + its apply method + a pure static validator + `test_dev_args` cases (+ a `smoke_dev_tools` case when it touches the scene) |
| Measure performance | [perf.md](./perf.md): `godot --path game -- --room=perf_worst --perf`, then with `--glow=on` |

After any rule change, update the matching GDD table. Note playtest-driven changes in `_bmad-output/implementation-artifacts/`.

## Build and Deploy

No export presets or CI yet. M1 is played from the editor. The GDD targets Windows, Linux and web/itch.io (960×540 embed) for M2; see [Architecture → Gaps](./architecture.md#gaps-against-the-m2-design).

## Git

- Work happens on feature branches (`feat/m1-prototype` now); `main` is the PR base.
- Planning commits use the `docs:` prefix (Conventional Commits style).
- `game/.godot/` and `game/export/` are ignored. `.uid` and `.import` files are committed.
