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

Open `game/` in Godot 4.7 and press **F5**. The main scene is `scenes/shaft.tscn`. The controls are in [`game/README.md`](../game/README.md).

Debug hotkeys in M1: **F1** brightness (4 levels, saved in `user://settings.json` and remembered between launches), **F3** restart from the top.

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
godot --headless --path game res://tests/runner.tscn -- res://tests/test_deferred_owners.gd  # every deferred-work.md item has an owner
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_shaft.gd           # integration smoke test
godot --headless --path game res://tests/runner.tscn -- res://tests/smoke_shaft_state.gd     # the shaft's state lives in Game
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
- **Behaviour in the level → `smoke_shaft.gd`.** Add an `async` test, `await` it from `run()`, and drive it with `Input.action_press/release`. Use `place()` to teleport, and wait with `frames()` / `seconds()` (physics frames).
- Order matters in the smoke test because it shares one shaft instance. Reset what you touch: `chain.break_chain()`, `set_lurkers_active(true)`, `set_physics_process(true)`, `Game.clock.clear()`; a test that changes `Game` state ends with `Game.reset_for_tests()`. A test never calls `Game.boot()` against the real folder, so tests never load or write the real `user://settings.json`: a test that checks the file first points `Game.store.dir` at a temp folder it creates and removes (see `test_state.gd`). Only `test_state.gd` boots, on that temp folder and as its last case, because `reset_for_tests()` leaves the process booted. A test that leaves the player dead must be followed by a fresh shaft (see `test_snuff_needs_hold`).
- Add every new test file to the `for t in …` list in `run_tests.sh` until Story 1.9's glob runs `tests/test_*.gd` and `tests/smoke_*.gd` itself. `run_tests.sh` greps for lines that start with `ok`/`FAIL` or contain `PASS`/`FAILED` (plus error lines and their `at:` traces), so keep that output format. It also kills a run after 150 s of wall-clock time, which catches a test that blocks the main loop, where the runner's watchdog can't fire.

## Edit Art

1. Edit or add a grid in `tools/sprites/<name>.txt`. One char = one pixel, `.` = transparent, keys from `palette_edge.txt`.
2. From the repo root: `python3 tools/build_sprites.py`
3. Re-import: open the project, or run `godot --headless --path game --import`.
4. Commit the `.txt`, the `.png` and any new `.png.import`.

Never hand-edit `game/art/*.png`; the next build overwrites them. Do not name a grid `light.txt`.

## Edit the Level

The shaft is the `LAYOUT` array in `game/scripts/shaft.gd` (`#` wall, `.` empty, `P` spawn, `c` walker, `h` hoverer, `L` lurker). Every row must have the same width; an `assert` checks this at build time. After moving crawlers in the long run (rows 44–84), run the smoke test: the bot checks the run is still chainable (≥ 5).

## Common Tasks

| Task | Where |
|---|---|
| Tune movement or combat feel | consts in `scripts/rules/tuning.gd` (read through `Game.tuning`; the Player node's Inspector no longer shows them). Change the matching GDD table too. Camera and light presentation consts stay in `player.gd` |
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
