# The Unbroken Chain — Source Tree Analysis

**Date:** 2026-11-11 (updated through Story 1.13, 2026-11-19) · **Branch:** `feat/m1-prototype` · **Scan:** exhaustive

## Overview

A single repository holding one Godot 4.7 game (`game/`), the tools around it (`tools/`: the Python sprite pipeline that produces its art, and the export pipeline with its web boot smoke), and BMAD planning output (`_bmad-output/`). The code is the **M1 core-loop prototype**: one hand-built shaft, two enemy types and the chain/light/embers loop.

**Size:** 6 gameplay scripts (943 lines), 3 test scripts (502 lines), 4 scenes, 7 PNGs, 1 Python tool (99 lines) and 7 sprite text files.

## Complete Directory Structure

```
pixel_art_game/
├── game/                         # Godot 4.7 project root (open this folder in the editor)
│   ├── project.godot             # ★ Config: main scene, 480×270 viewport, input map, physics layer names
│   ├── export_presets.cfg        # The four export presets (Windows, Linux, Web, Web debug; Story 1.13), pinned by test_export_presets
│   ├── README.md                 # Controls, loop rules and how to run tests (player-facing)
│   ├── run_tests.sh              # ★ Test entry point: imports, then runs every tests/test_*.gd and tests/smoke_*.gd (glob)
│   ├── fonts/                    # Fusion Pixel Font 8px proportional latin .otf (+ .import: AA, hinting, subpixel off, no system fallback), OFL.txt, LICENSES/ (Story 1.17; docs/build.md)
│   ├── text/                     # strings.csv (keys,en) + its .import and the generated strings.en.translation (committed; Story 1.17)
│   ├── rooms/
│   │   ├── l1/m1_shaft.txt       # ★ The level: M1's shaft at 22 columns (header + --- + grid; docs/rooms.md)
│   │   └── dev/perf_worst.txt    # The worst-case perf scene (Story 1.12): 30 × 68, validated only, never a level (docs/perf.md)
│   ├── scenes/
│   │   ├── world/
│   │   │   └── world.tscn        # ★ ENTRY: main scene (run/main_scene). Darkness, RoomHolder, Camera, UI (gutters, router)
│   │   └── actors/
│   │       ├── player.tscn       # Player prefab: body, light, slash/pogo/hurt areas
│   │       ├── crawler.tscn      # Crawler prefab (CharacterBody2D + edge ray)
│   │       └── lurker.tscn       # Lurker prefab (Area2D + eyes + red glow light)
│   ├── scripts/
│   │   ├── rules/
│   │   │   ├── chain_state.gd    # ★ Pure chain/light/bloom/embers rules + all chain tuning constants
│   │   │   ├── tuning.gd         # ★ Tuning: every gameplay number as a const in BASE; f(&"key"), apply_gear()
│   │   │   ├── gear.gd           # Gear: the {id, stat, op, value} table (empty until E5)
│   │   │   ├── settings.gd       # Settings: global settings (brightness so far), set_value() + changed
│   │   │   ├── slot_state.gd     # SlotState: per-slot records, difficulty, story flags
│   │   │   └── dive_state.gd     # DiveState: carried embers, respawn point, killed enemies
│   │   ├── world/
│   │   │   ├── world.gd          # ★ World: the game scene; room, player spawn/respawn, play_rect(), light_rect()
│   │   │   ├── light_budget.gd   # LightBudget: World's child that applies the ≤ 6 light budget each physics tick (priority 50); no class_name
│   │   │   ├── camera_rig.gd     # CameraRig: follow, downward lead, shake, limits, play_rect(), view_rect()
│   │   │   ├── room_legend.gd    # RoomLegend: the one definition of every grid char
│   │   │   ├── room_loader.gd    # ★ RoomLoader: parse, pure validate (file:row:col errors), load, build
│   │   │   └── room.gd           # Room: a built room; spawn(), bounds(), entry_position()
│   │   ├── ui/
│   │   │   ├── gutters.gd        # Gutters: the two flat 60 px HUD strips
│   │   │   ├── screen_router.gd  # ScreenRouter: one full-screen UI screen at a time
│   │   │   └── theme_builder.gd  # ThemeBuilder: the one Theme in code (font, size 8, Label variations), play_text for UI over the play area
│   │   ├── actors/
│   │   │   ├── player.gd         # Movement, cling, attack/pogo, hitstop, light, contact and death
│   │   │   ├── player_input.gd   # PlayerInput: the only Input reader; intents, Light tap/hold, real-time buffers, lock()
│   │   │   ├── crawler.gd        # "Chain fuel": walker or hoverer, dies to any hit
│   │   │   └── lurker.gd         # Predator FSM: IDLE → TELEGRAPH → HUNT → RETURN
│   │   ├── core/
│   │   │   ├── game.gd           # The Game autoload: refs to session state (`settings`, `slot`, `dive`, `tuning`, `clock`, `display`, `palette`, `store`), boot(), no rules
│   │   │   ├── clock.gd          # Clock: the only writer of Engine.time_scale (hitstop requests)
│   │   │   ├── display.gd        # Display: the scale rule, the sub-×1 fit, the PC window; the only code touching the stretch or window (Story 1.14)
│   │   │   ├── log.gd            # Static Log: `[category] message`, silent in release
│   │   │   ├── save_store.gd     # SaveStore: the only reader/writer of the player's files (settings.json)
│   │   │   ├── budget_light.gd   # BudgetLight: every PointLight2D (rank ALWAYS/CACHE/GLOW), the budget rule, the sprite fallback
│   │   │   ├── palettes.gd       # Palettes: the one home for UI colours (zone tables, roles, glow floors); Game.palette is the active zone
│   │   │   ├── text_style.gd     # TextStyle: font, sizes, line metrics, CAP_TOP, the play-area outline (play_text LabelSettings, cached)
│   │   │   └── fx.gd             # Static code-built juice: spark burst, chain popup, floating text; the shared unshaded/additive materials
│   │   ├── dev/                  # Debug builds only: World's one guarded load() adds DevTools; the release presets exclude it (export.sh checks)
│   │   │   ├── dev_tools.gd      # DevTools: entry args (--room, --chain, --log, --set, --glow, --perf; ?… on web), the overlay key
│   │   │   ├── overlays.gd       # The four overlays (play rect, light/notice, exits/ids, FPS/light budget/frames/perf/Clock); no class_name
│   │   │   └── perf_run.gd       # PerfRun: the --perf autopilot, stand-in lights, frame stats and summary (docs/perf.md); no class_name
│   │   └── **/*.gd.uid           # Godot 4.4+ resource UIDs (committed; keep next to their script)
│   ├── tests/
│   │   ├── runner.gd / runner.tscn # Runs one test as a scene; fails on no PASS, a timeout or any engine error
│   │   ├── test_chain_state.gd   # Unit tests for ChainState
│   │   ├── test_log.gd           # Unit tests for Log
│   │   ├── test_clock.gd         # Clock: stacking, refresh, real-time expiry, pause, clear on death
│   │   ├── test_display.gd       # Display: the scale table, window_scale_for, project display settings, inert until start() (Story 1.14)
│   │   ├── test_tuning.gd        # Tuning API, gear order, floors under every gear combination, the 44 M1 exports fixture
│   │   ├── test_state.gd         # Settings/SlotState/DiveState, Game refs, settings.json fallbacks
│   │   ├── test_room_loader.gd   # Room validator, build, Room API, and the real m1_shaft
│   │   ├── test_room_sweep.gd    # The pure room sweeps on inline grids (fires + near-miss per rule)
│   │   ├── test_deferred_owners.gd # Fails while an item in deferred-work.md has no owner
│   │   ├── test_lint.gd          # Architecture lint over scripts/ (FAIL lint <file>:<line> <rule>)
│   │   ├── test_export_presets.gd # The export presets and their filters, through the exporter's own matcher (Story 1.13)
│   │   ├── test_dev_args.gd      # DevTools' pure parts: URL query, arg grammar, validators, entry pick, Clock rows, --glow/--perf, perf stats
│   │   ├── test_fx.gd            # Fx: the shared materials built once; effects free themselves; the gate, the EFFECTS table, the sampled rates
│   │   ├── test_light_budget.gd  # BudgetLight: the rule, jitter, apply() on nodes, sprite fallback, scene audit
│   │   ├── test_strings.gd       # The string table: shape, registered and current, en fallback, key scan, dead keys, copy rules, scene text
│   │   ├── test_palettes.gd      # Palettes against DESIGN: tokens, derived gutter, contrast floors, minimal overrides, ratios, mock regions
│   │   ├── test_theme.gd         # Font import pins, coverage, widths, Theme variations and pitches, CAP_TOP, play_text, popups at 8 px
│   │   ├── spec.gd               # Helper: the GDD's guarantees as constants, preloaded by tests
│   │   ├── strings_check.gd      # Helper: the pure string-table checks (table, glyphs, registered, copy, key refs, scene text)
│   │   ├── room_sweep.gd         # Helper: the pure room sweeps (falls, stretches, hazards, ids, links, arrival)
│   │   ├── rate.gd               # Helper: a rate in Hz from values sampled once per tick (turns, the span between events)
│   │   ├── smoke_rooms.gd        # Every room file: validation, cross-file checks, sweeps, lurker guarantees
│   │   ├── smoke_bot.gd          # The descent bot in every spine room: chain ≥ 5, no live chain at an exit
│   │   ├── smoke_moves.gd        # The M1 move checks on m1_shaft: pogo, landing, jump, cling, Snuff release
│   │   ├── smoke_world.gd        # World: tree, framing, state wiring, respawn without a reload, play rect, R16 loop
│   │   ├── smoke_room_swap.gd    # Room swaps on tests/rooms/swap/ (t_swap_a, t_swap_b): backstop, arrival, killed cells
│   │   ├── smoke_player_input.gd # Movement pinned from M1 + PlayerInput intents on tests/rooms/input/t_input.txt
│   │   ├── smoke_dev_tools.gd    # DevTools in world.tscn: inert without args, the SMOKE boot marker, each arg, the overlay cycle, no F-key
│   │   ├── smoke_a11y.gd         # The accessibility gate on m1_shaft: shake off, blink and steady variant, look-ahead on a pogo
│   │   ├── smoke_palettes.gd     # The active zone in world.tscn on tests/rooms/zones/: boot, exit, respawn, same zone; gutters and popup
│   │   ├── smoke_perf.gd         # The perf kit in world.tscn: --perf=3 in perf_worst, budget held every tick, the summary
│   │   ├── screenshot.gd         # Renders 2 PNG screenshots + the ×2 Deck mock per zone (needs a real renderer: xvfb-run)
│   │   ├── deck_mock.gd          # Helper (not a test): the 480×270 gutter-HUD mock for the Deck-size check, one zone's colours
│   │   ├── room_harness.gd       # Helper (not a test): a room standalone + test player + CameraRig + stub World
│   │   └── rooms/                # Test-only room fixtures (ok_min, bad_*, swap/, input/, zones/, dev_tools/t_dev_room.txt); never exported
│   └── art/                      # ⚠ GENERATED by tools/build_sprites.py — do not hand-edit
│       ├── player.png  crawler.png  lurker.png  lurker_eyes.png  slash.png  tile.png
│       ├── light.png             # 128×128 radial gradient used by every PointLight2D
│       └── *.png.import          # Godot import settings (committed)
│
├── tools/                        # Run outside the game: never exported, never linted
│   ├── build_sprites.py          # ★ Text pixel grids + palette → game/art/*.png (needs Pillow)
│   ├── sprites/
│   │   ├── palette_edge.txt      # "Edge of the Abyss" palette: one `char #hex` per line
│   │   └── player.txt crawler.txt lurker.txt lurker_eyes.txt slash.txt tile.txt
│   │                             # One char = one pixel; '.' = transparent
│   ├── export.sh                 # ★ Builds every target into builds/<version>/ and checks each one (Story 1.13; docs/build.md)
│   ├── godot_licenses.gd         # Writes GODOT_LICENSES.txt (Godot's licence, third-party components, licence texts) for export.sh (Story 1.17)
│   ├── pck_list.gd               # Lists a PCK's files through the engine's own reader (export.sh's release check)
│   └── web_smoke/                # The web boot smoke: Playwright 1.65.1 (exact pin), Chromium headless
│       ├── embed.html            # An itch-style host page with the game in a 960×540 iframe (Story 1.14's Web input test)
│       ├── package.json  package-lock.json   # node_modules/ is ignored; npm ci
│       ├── playwright.config.js  # Chromium only, serve.js as the webServer on 127.0.0.1:8061
│       ├── serve.js              # Dependency-free static server for a build folder, plus /embed.html (also the laptop tunnel's, on 8060)
│       └── smoke.spec.js         # Both web builds boot; the debug one prints SMOKE boot ok, also with ?room=perf_worst; Display scale, Web input (1.14)
│
├── builds/                       # tools/export.sh output, one folder per version (gitignored)
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

★ = start here. Ignored by git: `game/.godot/` (import cache), `game/export/`, `/builds/` and the web smoke's `node_modules/`, `test-results/` and `playwright-report/`.

## Critical Directories

### `game/scripts/`

All gameplay code. Every script declares a `class_name` (`ChainState`, `Player`, `Crawler`, `Lurker`, `Fx`, `Room`, `RoomLoader`, `RoomLegend`, …) except the `Game` autoload, `dev/overlays.gd` and `dev/perf_run.gd` (DevTools preloads them) and `world/light_budget.gd` (World preloads it), so other scripts and tests use the types directly. `dev/` is debug-only: nothing outside `dev/` and `tests/` names it, except `world.gd`'s one guarded line (the lint's `dev_ref`).

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
| Dev args (debug builds) | `godot --path game -- --room=m1_shaft --chain=8 --set=brightness:0` → `scripts/dev/dev_tools.gd` |
| Perf run (debug builds) | `godot --path game -- --room=perf_worst --perf` (add `--glow=on`) → `scripts/dev/perf_run.gd`; procedure in [perf.md](./perf.md) |
| Tests | `game/run_tests.sh` → `tests/runner.tscn` → every `tests/test_*.gd`, then `tests/smoke_*.gd` |
| Screenshots | `tests/screenshot.gd` (manual, needs a display or xvfb) |
| Sprites | `python3 tools/build_sprites.py` (from the repo root) |
| Builds (server) | `tools/export.sh` → `builds/<yyyymmdd>-<sha7>[-dirty]/`; the web smoke alone: `cd tools/web_smoke && BUILD_DIR=<abs build folder> npx playwright test` ([build.md](./build.md)) |

## File Organization Patterns

- **Script per scene:** `scenes/<domain>/X.tscn` ↔ `scripts/<domain>/X.gd`. Both trees use the same domain folder names; scripts live under `scripts/`, not next to their scene, and `scenes/` has only the domains that have scenes.
- **Enemies** live with the player in `scenes/actors/` and `scripts/actors/`.
- **One autoload (`Game`), no addons, no resources (`.tres`).** Tilesets and materials are built in code. `Audio` is the only other autoload the architecture allows (E3).
- **Tuning lives in code:** gameplay numbers are `const`s in `rules/tuning.gd`, read through `Game.tuning.f(&"key")` (Story 1.3; no `@export` remains). The chain-curve consts stay in `ChainState`, presentation consts stay on their actors, and `Shaft` keeps its own `const`s until 1.7.

## Configuration Files

| File | Purpose |
|---|---|
| `game/project.godot` | Main scene, window/stretch, input actions, physics layer names, renderer, pixel snap, the project font (`gui/theme/custom_font`) and the registered string table (`internationalization/locale/translations`) |
| `game/art/*.png.import` | Per-texture import settings |
| `game/fonts/*.otf.import` | The font's import settings: antialiasing, hinting and subpixel positioning off, no system fallback (pinned; `test_theme` reads them) |
| `game/text/strings.csv.import` | The string table's import settings (`compress=1`, `unescape_keys=false`, `unescape_translations=true`) |
| `tools/sprites/palette_edge.txt` | The colour palette for the sprite pipeline |
| `game/export_presets.cfg` | The four export presets `tools/export.sh` calls by name (Story 1.13); `test_export_presets` pins them |
| `tools/web_smoke/package.json` + `package-lock.json` | The web smoke's one dependency, `@playwright/test` pinned exactly; Node ≥ 24 |
| `.gitignore` | Ignores `game/.godot/`, `game/export/`, `/builds/`, the web smoke's `node_modules/` and Playwright output, BMAD loop caches, `__pycache__/` |

There is no CI configuration or `.env`. The string table is `game/text/` (Story 1.17); M2 ships English only.
