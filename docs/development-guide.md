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

There are no debug hotkeys until DevTools (Story 1.11): brightness keeps the level saved in `user://settings.json`, and you restart by relaunching. A death respawns you at the top without a reload, in a rebuilt room (crawlers you killed stay gone); falling through the floor hole loops you back to the top.

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
godot --headless --path game res://tests/runner.tscn -- res://tests/test_deferred_owners.gd  # every deferred-work.md item has an owner
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_shaft.gd           # integration smoke test on m1_shaft
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_world.gd           # World: tree, framing, state wiring, respawn without a reload, R16 loop
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_room_swap.gd       # room swaps on the test rooms in tests/rooms/swap/
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
- **Behaviour in the level → `smoke_shaft.gd`.** It loads `m1_shaft` standalone through `tests/room_harness.gd` (room, test player, `CameraRig`, stub `World`); World itself (spawn, respawn, framing, the R16 loop) is tested in `smoke_world.gd`, which instances `world.tscn`, and room swaps in `smoke_room_swap.gd`, on its own rooms in `tests/rooms/swap/` (`RoomLoader.add_root()`, `World.start_room` set before `add_child`); a respawn or loop builds a fresh room, so re-take references and turn its lurkers off again after each one; find positions through the room API (`entry_position()`, `is_solid()`, `cell_centre()`), never literal tile coordinates, and pick targets by position, never by group index. Add an `async` test, `await` it from `run()`, and drive it with `Input.action_press/release` (pass a `strength` for analog input; it skips the action deadzone, which `PlayerInput` applies itself). Gameplay reads `player.input` intents, never `Input` (Story 1.8). Frame math measured on 4.7.2: a press made after an `await` is first seen by the player two ticks later, and a read after an `await` sees the last tick the player ran (see `smoke_player_input.gd`). Use `place()` to teleport, and wait with `frames()` / `seconds()` (physics frames).
- Order matters in the smoke test because it shares one room and player. Reset what you touch: `chain.break_chain()`, `set_lurkers_active(true)`, `set_physics_process(true)`, `Game.clock.clear()`; a test that changes `Game` state ends with `Game.reset_for_tests()`. A test never calls `Game.boot()` against the real folder, so tests never load or write the real `user://settings.json`: a test that checks the file first points `Game.store.dir` at a temp folder it creates and removes (see `test_state.gd`). Only `test_state.gd` boots, on that temp folder and as its last case, because `reset_for_tests()` leaves the process booted. A test that leaves the player dead must be followed by a fresh room (`RoomHarness.free_all()` then `build()`, see `test_snuff_needs_hold`). Free every node a test builds: an exit-time leak prints an engine `ERROR:`.
- **Tests are found by name** (Story 1.9): `run_tests.sh` runs every `tests/test_*.gd`, then every `tests/smoke_*.gd`, in C sort order. Name a new test to match and it runs; there is no list to edit, and a helper must not use either prefix (`runner.gd`, `room_harness.gd`, `spec.gd`, `screenshot.gd`). An empty glob fails the run. `run_tests.sh` greps for lines that start with `ok`/`FAIL` or contain `PASS`/`FAILED` (plus error lines and their `at:` traces), so keep that output format. It also kills a run after 150 s of wall-clock time, which catches a test that blocks the main loop, where the runner's watchdog can't fire.

### Design guarantees: `tests/spec.gd`

A guarantee the GDD promises (telegraph ≥ 0.75 s, bot chain ≥ 5, base light 40 px never noticed, the 80 px notice floor) is a `Spec` const with its `## GDD …` citation. Tests `const Spec := preload("res://tests/spec.gd")` and compare against it, never against the tuning value under test, so loosening tuning fails the suite (`smoke_shaft.gd`, `test_tuning.gd`'s `stat_floor_errors()`, which tries every combination of gear rows). A new guarantee gets a `Spec` const and a test before the feature is done; changing one means changing the GDD first, with sonlm. `test_lint` fails a `Spec` const without a `## GDD` citation.

### The architecture lint: `tests/test_lint.gd`

A text scan of every `.gd` under `game/scripts/` (comments dropped, string contents ignored by the identifier rules; escapes, `"""` blocks and `\`-continued strings handled). A hit prints `FAIL lint <file>:<line> <rule>`, with the path relative to `scripts/` (`spec_citation` names `tests/spec.gd`). Two rules also get class names built at run time by `layer_names()`: the `class_name` lines (annotated ones too) and autoloads of each layer, and ClassDB's Node classes for `rules/`.

| Rule | Fails on | Allowed in |
|---|---|---|
| `time_scale` | `Engine.time_scale =` (or `*=`, `+=`, …), `Engine.set_time_scale(`, `Engine.set("time_scale", …)` | `core/clock.gd` |
| `raw_input` | `Input`, `InputMap`, `InputEvent*`, `func _input` / `_unhandled_input` / `_unhandled_key_input` / `_shortcut_input` / `_gui_input`, the `gui_input` signal | `actors/player_input.gd`, `core/devices.gd`, `ui/kit/` |
| `print` | `print(` and its family (`printerr`, `print_rich`, `print_verbose`, `print_stack`, `print_tree`, …), `@GlobalScope.print(` | `core/log.gd` |
| `free` | `.free()`, bare `free()`, `free.call_deferred()`, `call_deferred("free")` | — |
| `root_path` | `"/root/` node paths, `$/root/…`, `get_tree().root.get_node(` | — |
| `keycode` | any `KEY_*` constant | `ui/kit/` |
| `random` | `randf`, `randi`, `randf_range`, `randi_range`, `randfn`, `randomize`, `seed`, `rand_from_seed`, `.pick_random()`, `.shuffle()`, `RandomNumberGenerator` | `world/camera_rig.gd` (shake) |
| `rules_purity` | in `rules/`: `Node*` and every other Node class (ClassDB), `Input*`, `Engine*`, `OS`, `Time`, `SceneTree`, `get_tree(`, file access (`FileAccess`, `DirAccess`, `ResourceLoader`, `ResourceSaver`, `ConfigFile`), `ProjectSettings`, `DisplayServer`, `Game`, `Audio`, any class or autoload from `core/` or above, `load(`, a `preload` other than `scripts/rules/` or a sibling `name.gd` | — |
| `core_layer` | in `core/`: a `class_name` or autoload from `world/ actors/ objects/ moments/ ui/ audio/ dev/` (collected at run time), or a path into them | — |
| `dev_ref` | `DevTools` or a `scripts/dev/` / `scenes/dev/` path outside `dev/` | 1.11 adds `world.gd`'s one `load()` line |
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

The level is `game/rooms/l1/m1_shaft.txt`: a header, `---`, then the grid (`#` wall, `.` empty, `P` spawn, `c` walker, `h` hoverer, `L` lurker; the full format and legend are in [rooms.md](./rooms.md)). It is a spine room, so it must stay 22 columns wide including the walls. Edit the text and run the tests: `test_room_loader` validates the file (errors print as `file:row:col`) and checks no fall between ledge rows is over 19 rows (FR57), and the smoke test's bot checks the long run (rows 44–84) is still chainable (≥ 5). A bad file never builds: the loader prints its errors, and `World` stays in the current room (a bad start room is an assert; a bad respawn point falls back to the start room's `P`).

## Common Tasks

| Task | Where |
|---|---|
| Tune movement or combat feel | consts in `scripts/rules/tuning.gd` (read through `Game.tuning`; the Player node's Inspector no longer shows them). Change the matching GDD table too. Light presentation consts stay in `player.gd`; camera ones are in `scripts/world/camera_rig.gd` |
| Tune the chain, light, bloom or embers curve | constants and `ember_value()` in `chain_state.gd`, plus unit tests |
| Tune a lurker | the `LURKER_*` consts in `scripts/rules/tuning.gd`; change the matching GDD table too, and keep `LURKER_TELEGRAPH_TIME ≥ 0.75`. The sensing consts stay in `lurker.gd` until 1.20 |
| Add an enemy that can be pogoed | A body on layer 3 (value 4) with a `take_hit()` method; add it to group `enemy` if contact should knock back |
| Add a predator | An `Area2D` on layer 4 (value 8) in group `predator`; `monitorable` only while it may kill |
| New effect | A static function in `fx.gd`; unshaded so it reads in the dark |
| Add an input action | `project.godot` `[input]` (Project Settings → Input Map) and `game/README.md` |

After any rule change, update the matching GDD table. Note playtest-driven changes in `_bmad-output/implementation-artifacts/`.

## Build and Deploy

No export presets or CI yet. M1 is played from the editor. The GDD targets Windows, Linux and web/itch.io (960×540 embed) for M2; see [Architecture → Gaps](./architecture.md#gaps-against-the-m2-design).

## Git

- Work happens on feature branches (`feat/m1-prototype` now); `main` is the PR base.
- Planning commits use the `docs:` prefix (Conventional Commits style).
- `game/.godot/` and `game/export/` are ignored. `.uid` and `.import` files are committed.
