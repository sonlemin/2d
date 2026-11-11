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

Debug hotkeys in M1: **F1** brightness (4 levels), **F2** show or hide the controls hint, **F3** restart from the top.

## Testing

```bash
cd game
./run_tests.sh                 # imports, then runs unit + smoke tests; prints "== ALL GREEN" or exits 1
```

Run one suite on its own:

```bash
godot --headless --path game --import                                # once, so textures resolve
godot --headless --path game --script res://tests/run_tests.gd       # ChainState unit tests
godot --headless --path game --script res://tests/smoke_shaft.gd     # integration smoke test
```

Screenshots (needs a renderer):

```bash
xvfb-run -a godot --path game --rendering-driver opengl3 --script res://tests/screenshot.gd -- /some/out_dir
```

### Writing tests

- Tests are plain `extends SceneTree` scripts with a local `check(cond, msg)`. There is no framework.
- **Pure rules → `run_tests.gd`.** Add a `test_*` function and list it in `_init()`. Preload the script (`ChainStateScript`) rather than rely on `class_name` in `--script` mode.
- **Behaviour in the level → `smoke_shaft.gd`.** Add an `async` test, `await` it from `_run()`, and drive it with `Input.action_press/release`. Use `place()` to teleport, and wait with `frames()` / `seconds()` (physics frames).
- Order matters in the smoke test because it shares one shaft instance. Reset what you touch: `chain.break_chain()`, `set_lurkers_active(true)`, `set_physics_process(true)`. A test that leaves the player dead must be followed by a fresh shaft (see `test_snuff_needs_hold`).
- `run_tests.sh` greps for lines that start with `ok`/`FAIL` or contain `PASS`/`FAILED`. Keep that output format.

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
| Tune movement or combat feel | `@export` vars in `player.gd` (also editable on the Player node in the editor) |
| Tune the chain, light, bloom or embers curve | constants and `ember_value()` in `chain_state.gd`, plus unit tests |
| Tune a lurker | `@export` vars in `lurker.gd` (keep `telegraph_time ≥ 0.75`) |
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
