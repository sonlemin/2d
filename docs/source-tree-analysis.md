# The Unbroken Chain — Source Tree Analysis

**Date:** 2026-11-11 · **Branch:** `feat/m1-prototype` · **Scan:** exhaustive

## Overview

A single repository holding one Godot 4.7 game (`game/`), the Python sprite pipeline that produces its art (`tools/`), and BMAD planning output (`_bmad-output/`). The code is the **M1 core-loop prototype**: one hand-built shaft, two enemy types and the chain/light/embers loop.

**Size:** 6 gameplay scripts (943 lines), 3 test scripts (502 lines), 4 scenes, 7 PNGs, 1 Python tool (99 lines) and 7 sprite text files.

## Complete Directory Structure

```
pixel_art_game/
├── game/                         # Godot 4.7 project root (open this folder in the editor)
│   ├── project.godot             # ★ Config: main scene, 480×270 viewport, input map, physics layer names
│   ├── README.md                 # Controls, loop rules and how to run tests (player-facing)
│   ├── run_tests.sh              # ★ Test entry point: imports, then runs every headless test
│   ├── rooms/
│   │   └── l1/m1_shaft.txt       # ★ The level: M1's shaft at 22 columns (header + --- + grid; docs/rooms.md)
│   ├── scenes/
│   │   ├── shaft.tscn            # Unused since Story 1.6 (deleted in 1.7)
│   │   ├── world/
│   │   │   └── world.tscn        # ★ ENTRY: main scene (run/main_scene). Darkness, RoomHolder, Camera, UI (gutters, router)
│   │   └── actors/
│   │       ├── player.tscn       # Player prefab: body, light, slash/pogo/hurt areas
│   │       ├── crawler.tscn      # Crawler prefab (CharacterBody2D + edge ray)
│   │       └── lurker.tscn       # Lurker prefab (Area2D + eyes + red glow light)
│   ├── scripts/
│   │   ├── shaft.gd              # Unused since Story 1.6 (deleted in 1.7)
│   │   ├── rules/
│   │   │   ├── chain_state.gd    # ★ Pure chain/light/bloom/embers rules + all chain tuning constants
│   │   │   ├── tuning.gd         # ★ Tuning: every gameplay number as a const in BASE; f(&"key"), apply_gear()
│   │   │   ├── gear.gd           # Gear: the {id, stat, op, value} table (empty until E5)
│   │   │   ├── settings.gd       # Settings: global settings (brightness so far), set_value() + changed
│   │   │   ├── slot_state.gd     # SlotState: per-slot records, difficulty, story flags
│   │   │   └── dive_state.gd     # DiveState: carried embers, respawn point, killed enemies
│   │   ├── world/
│   │   │   ├── world.gd          # ★ World: the game scene; room, player spawn/respawn, play_rect()
│   │   │   ├── camera_rig.gd     # CameraRig: follow, downward lead, shake, limits, play_rect()
│   │   │   ├── room_legend.gd    # RoomLegend: the one definition of every grid char
│   │   │   ├── room_loader.gd    # ★ RoomLoader: parse, pure validate (file:row:col errors), load, build
│   │   │   └── room.gd           # Room: a built room; spawn(), bounds(), entry_position()
│   │   ├── ui/
│   │   │   ├── gutters.gd        # Gutters: the two flat 60 px HUD strips
│   │   │   └── screen_router.gd  # ScreenRouter: one full-screen UI screen at a time
│   │   ├── actors/
│   │   │   ├── player.gd         # Movement, cling, attack/pogo, hitstop, light, contact and death
│   │   │   ├── crawler.gd        # "Chain fuel": walker or hoverer, dies to any hit
│   │   │   └── lurker.gd         # Predator FSM: IDLE → TELEGRAPH → HUNT → RETURN
│   │   ├── core/
│   │   │   ├── game.gd           # The Game autoload: refs to session state (`settings`, `slot`, `dive`, `tuning`, `clock`, `store`), boot(), no rules
│   │   │   ├── clock.gd          # Clock: the only writer of Engine.time_scale (hitstop requests)
│   │   │   ├── log.gd            # Static Log: `[category] message`, silent in release
│   │   │   ├── save_store.gd     # SaveStore: the only reader/writer of the player's files (settings.json)
│   │   │   └── fx.gd             # Static code-built juice: spark burst, chain popup, floating text
│   │   └── **/*.gd.uid           # Godot 4.4+ resource UIDs (committed; keep next to their script)
│   ├── tests/
│   │   ├── runner.gd / runner.tscn # Runs one test as a scene; fails on no PASS, a timeout or any engine error
│   │   ├── test_chain_state.gd   # Unit tests for ChainState
│   │   ├── test_log.gd           # Unit tests for Log
│   │   ├── test_clock.gd         # Clock: stacking, refresh, real-time expiry, pause, clear on death
│   │   ├── test_tuning.gd        # Tuning API, gear order, rules/ purity, the 44 M1 exports regression fixture
│   │   ├── test_state.gd         # Settings/SlotState/DiveState, Game refs, settings.json fallbacks
│   │   ├── test_room_loader.gd   # Room validator, build, Room API, and the real m1_shaft
│   │   ├── test_deferred_owners.gd # Fails while an item in deferred-work.md has no owner
│   │   ├── smoke_shaft.gd        # Integration smoke test: m1_shaft via the room harness, simulated input, bot run
│   │   ├── smoke_world.gd        # World: tree, framing, state wiring, respawn without a reload, play rect
│   │   ├── screenshot.gd         # Renders 2 PNG screenshots (needs a real renderer: xvfb-run)
│   │   ├── room_harness.gd       # Helper (not a test): a room standalone + test player + CameraRig + stub World
│   │   └── rooms/                # Test-only room fixtures (ok_min, bad_*); never exported
│   └── art/                      # ⚠ GENERATED by tools/build_sprites.py — do not hand-edit
│       ├── player.png  crawler.png  lurker.png  lurker_eyes.png  slash.png  tile.png
│       ├── light.png             # 128×128 radial gradient used by every PointLight2D
│       └── *.png.import          # Godot import settings (committed)
│
├── tools/                        # Asset pipeline (runs outside Godot)
│   ├── build_sprites.py          # ★ Text pixel grids + palette → game/art/*.png (needs Pillow)
│   └── sprites/
│       ├── palette_edge.txt      # "Edge of the Abyss" palette: one `char #hex` per line
│       └── player.txt crawler.txt lurker.txt lurker_eyes.txt slash.txt tile.txt
│                                 # One char = one pixel; '.' = transparent
│
├── docs/                         # Generated project documentation (this folder)
│
├── _bmad-output/                 # Planning and implementation artifacts (BMAD)
│   ├── brainstorming-session-2026-11-07.md
│   ├── planning-artifacts/
│   │   ├── briefs/brief-pixel_art_game-2026-11-08/     # Game brief + addendum + decision log
│   │   ├── research/                                    # Domain research (pogo-descent platformers)
│   │   ├── gdds/gdd-pixel_art_game-2026-11-10/          # ★ GDD v1.0 (M2 target) + epics + decision log
│   │   └── ux-designs/ux-pixel_art_game-2026-11-10/     # ★ DESIGN.md, EXPERIENCE.md, mockups, reviews
│   ├── implementation-artifacts/
│   │   ├── spec-m1-core-loop-prototype.md               # The spec the M1 code implements
│   │   ├── m1-playtest-findings.md                      # Verdict + design deltas + tuning snapshot
│   │   └── deferred-work.md                             # Deferred features and post-M1 mechanic ideas
│   └── test-artifacts/                                  # (empty)
│
├── _bmad/                        # BMAD framework install (skills config, scripts) — not game code
└── .claude/                      # Claude Code skills for this repo — not game code
```

★ = start here. Ignored by git: `game/.godot/` (import cache) and `game/export/`.

## Critical Directories

### `game/scripts/`

All gameplay code. Every script declares a `class_name` (`ChainState`, `Player`, `Crawler`, `Lurker`, `Fx`, `Room`, `RoomLoader`, `RoomLegend`, …) except the unused `shaft.gd` and the `Game` autoload, so other scripts and tests use the types directly.

- **Entry point:** `world/world.gd` runs on the main scene and loads the room through `world/room_loader.gd`.
- **Key file:** `chain_state.gd` — the one place the core rules and their constants live.

### `game/scenes/`

Thin prefabs: node trees, collision shapes and textures. Behaviour lives in the scripts. `world.tscn` holds no player (World spawns it) and no room; the room (walls, rims, crawlers and lurkers) is built at runtime by `RoomLoader` from `rooms/l1/m1_shaft.txt`.

### `game/rooms/`

Levels as text, `rooms/<layer>/<room_id>.txt`: a header, `---`, then the grid (one char per 16 px tile). Read with `FileAccess`, not imported. See [rooms.md](./rooms.md).

### `game/tests/`

`extends Node` scripts, each run as a scene by `tests/runner.tscn` (`godot --headless --path game res://tests/runner.tscn -- res://tests/<test>.gd`), so the `Game` autoload works in tests. There is no test framework (no GUT, no gdUnit). See [Development Guide](./development-guide.md#testing).

### `game/art/` and `tools/sprites/`

Source of truth for art is `tools/sprites/*.txt`; `game/art/*.png` is build output that is committed so the project opens without Python. See [Architecture → Asset pipeline](./architecture.md#asset-pipeline).

## Entry Points

| What | Where |
|---|---|
| Game | `game/scenes/world/world.tscn` (`run/main_scene`) → `scripts/world/world.gd::_ready()` |
| Tests | `game/run_tests.sh` → `tests/runner.tscn` → each test in its `for t in …` list |
| Screenshots | `tests/screenshot.gd` (manual, needs a display or xvfb) |
| Sprites | `python3 tools/build_sprites.py` (from the repo root) |

## File Organization Patterns

- **Script per scene:** `scenes/<domain>/X.tscn` ↔ `scripts/<domain>/X.gd`. Both trees use the same domain folder names; scripts live under `scripts/`, not next to their scene, and `scenes/` has only the domains that have scenes. `shaft.gd`/`shaft.tscn` stay at the top level until Story 1.7.
- **Enemies** live with the player in `scenes/actors/` and `scripts/actors/`.
- **One autoload (`Game`), no addons, no resources (`.tres`).** Tilesets and materials are built in code. `Audio` is the only other autoload the architecture allows (E3).
- **Tuning lives in code:** gameplay numbers are `const`s in `rules/tuning.gd`, read through `Game.tuning.f(&"key")` (Story 1.3; no `@export` remains). The chain-curve consts stay in `ChainState`, presentation consts stay on their actors, and `Shaft` keeps its own `const`s until 1.7.

## Configuration Files

| File | Purpose |
|---|---|
| `game/project.godot` | Main scene, window/stretch, input actions, physics layer names, renderer, pixel snap |
| `game/art/*.png.import` | Per-texture import settings |
| `tools/sprites/palette_edge.txt` | The colour palette for the sprite pipeline |
| `.gitignore` | Ignores `game/.godot/`, `game/export/`, BMAD loop caches, `__pycache__/` |

There is no `export_presets.cfg`, CI configuration, `.env` or localisation folder.
