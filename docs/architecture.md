# The Unbroken Chain — Architecture (as built, M1)

**Date:** 2026-11-11 (updated through Story 1.13, 2026-11-19) · **Branch:** `feat/m1-prototype` (M1), `feat/m2-e1` (Epic 1) · **Scope:** the code in `game/` and `tools/`, including the export pipeline (`tools/export.sh`, `tools/web_smoke/`)

This document describes the M1 prototype **as it is**. The design target for M2 lives in the [GDD](../_bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md) and the [UX spines](../_bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/). Where the code and those documents differ, see [Gaps against the M2 design](#gaps-against-the-m2-design). That section lists observations, not decisions.

## Executive Summary

A single-scene Godot 4.7 prototype that answers one question: *does a long pogo chain feel tempting and dangerous?* (Answered **yes** on 2026-11-10; see the [playtest findings](../_bmad-output/implementation-artifacts/m1-playtest-findings.md).)

The architecture is deliberately small:

- One **pure-logic class** (`ChainState`) holds the core rules, so they can be unit-tested with no scene.
- Rooms are **text files** (`rooms/<layer>/<id>.txt`) that `RoomLoader` validates and builds into a `Room` node; the **`World` scene** (Story 1.6) holds the room, the player, the camera rig, the darkness and the UI layer; it swaps rooms through exits (Story 1.7) and respawns a dead player without a reload, rebuilding the respawn room. Session state lives in `Game`.
- Three **actor scripts** (Player, Crawler, Lurker) talk to each other only through physics overlaps, groups and duck-typed methods.
- One **static helper** (`Fx`) makes effects in code.
- Art comes from a **text-to-PNG pipeline** outside Godot.

## Technology Stack

| Category | Technology | Version / setting | Why |
|---|---|---|---|
| Engine | Godot | 4.7 (`config/features`) | GDD platform decision |
| Language | GDScript | typed where practical | GDD: GDScript only |
| Renderer | GL Compatibility | desktop and mobile | Required for web builds |
| Resolution | 480×270 viewport | `stretch/mode=viewport`, `scale_mode=integer`, window 1440×810 (×3); `Game.display` (`core/display.gd`, Story 1.14): the fractional nearest fit below 480×270, the PC window shrunk to the largest whole scale that fits the screen, minimum 480×270 | Crisp pixel art; on web the engine's HiDPI canvas puts the scale in physical pixels |
| Pixel rules | nearest filter, `snap_2d_transforms_to_pixel` | project-wide | No sub-pixel shimmer |
| Lighting | `PointLight2D` (every one a `BudgetLight`, Story 1.12) + `CanvasModulate` | one shared 128 px gradient texture | The "light in the dark" pillar; at most 6 lights lit in the view (AR46) |
| Physics | Godot 2D built-in | default 60 ticks/s | `CharacterBody2D` for actors |
| Test runner | Godot headless + `tests/runner.tscn` (each test is a `Node` script) | no framework | Runs on the headless dev server |
| Asset tool | Python 3 + Pillow | `tools/build_sprites.py` | Art as reviewable text |
| Addons / autoloads | autoload `Game` (holds `clock`, `display`, `tuning`, `settings`, `slot`, `dive` and `store`); no addons | — | `Audio` joins in E3 |
| Export presets / builds | `game/export_presets.cfg` (`Windows`, `Linux`, `Web`, `Web debug`; Story 1.13) + `tools/export.sh` | templates 4.7.2; Node 24 + Playwright 1.65.1 for the web smoke | Builds come from the server and are boot-checked there; no CI ([build.md](./build.md)) |

## Architecture Pattern

**Scene-tree composition with a pure-logic core.**

```
              ┌──────────────── world/world.tscn (Node2D, world.gd, group world) ────────────┐
              │  Darkness (CanvasModulate: ambient from Settings.brightness)                  │
              │  RoomHolder (Node2D at the origin)                                            │
              │    m1_shaft (Room, built by RoomLoader from rooms/l1/m1_shaft.txt at _ready)  │
              │      Backdrop (ColorRect)  Walls (TileMapLayer)  Rims (ColorRect × N)         │
              │      Crawler × N, Lurker × N, Fx popups   (spawned into the room)             │
              │  Player (player.tscn, spawned by world.gd) ── owns ──► ChainState             │
              │  Camera (Camera2D + camera_rig.gd: follow, lead, shake, play/view_rect())     │
              │  UI (CanvasLayer 10, PROCESS_MODE_ALWAYS)                                     │
              │    Gutters (two 60 px strips)   ScreenRouter (one screen at a time)           │
              │  DevTools (debug builds only; dev_tools.gd, PROCESS_MODE_ALWAYS)              │
              │    Overlays: WorldMarks (unshaded)   Screen (CanvasLayer 11): ScreenMarks     │
              │    Glow (WorldEnvironment, --glow=on only)   PerfRun (--perf only)            │
              │  LightBudget (light_budget.gd, physics priority 50: the ≤ 6 light budget)     │
              └───────────────────────────────────────────────────────────────────────────────┘
```

**Variance from `game-architecture.md` → Scene Structure** (Story 1.6 D1): that tree has no `Darkness`; here the ambient `CanvasModulate` sits under `World`, first, so it tints the room and the player but not the UI layer. The player is spawned by `world.gd` (one path for spawn and respawn) instead of being placed in the scene, and draws right after `RoomHolder`.

**Variance from `game-architecture.md` → Room swaps** (Story 1.7 D2): exits are **polled**, not overlapped. `World._physics_process` checks the player's body centre against the floor and the ceiling and crosses that side's exit, as crawler contact is polled; no trigger nodes. A body past a closed edge (tunnelling) dies instead of falling forever.

**Variance from `game-architecture.md` → Input** (Story 1.8 D1, D8): `PlayerInput` does not tick itself; `Player` calls `input.sample()` first in its `_physics_process`, because a child node's physics runs after its parent's and would hand the player last tick's input. It also has one intent beyond the architecture's list, `jump_released`, so the jump cut keeps M1's release edge (a buffered jump released before landing stays a full jump).

- **ChainState** is a `RefCounted` with no node dependencies. It owns the count, snuffed/clinging flags and held embers. It computes the light radius and Blade Bloom, and emits `changed(count)` and `banked(amount)`.
- **Player** owns one `ChainState` (`player.chain`) and turns input and collisions into calls on it (`add_hit`, `break_chain`, `set_snuffed`, `set_clinging`, `lose`). It then applies the results to its nodes (light texture scale, hitbox scale).
- **World** binds each player it spawns: `chain.banked` → `Game.dive.add_carried()`, `chain.changed` → `Game.slot.record_chain()`, `died` → the respawn, `pogo_hit` → `CameraRig.kick()`. The haul and the records live in `Game`. It emits `player_spawned(player)` on every spawn. There is no HUD until the gutter HUD (Stories 1.25–1.26).
- **Lurkers** poll the player each physics frame through `player.light_radius()`.

### Communication between parts

| From → To | Mechanism |
|---|---|
| Player → ChainState | direct method calls |
| ChainState → Player | signals `changed`, `banked` |
| ChainState → World | signal `banked` (calls `Game.dive.add_carried()`); signal `changed` (calls `Game.slot.record_chain()`) |
| Player → World | signal `died` (`Game.slot.record_death()`, then the respawn); signal `pogo_hit` (kicks the camera) |
| Player → Room | `Fx` popups are parented to `World.current_room()`, never to `World` |
| Player → Crawler | `Pogo`/`Slash` area overlap → duck-typed `body.take_hit()` |
| Crawler → Player | Player's `Hurtbox` polls overlapping bodies in group `enemy` → knockback |
| Lurker → Player | `get_first_node_in_group("player")` → `light_radius()`, `is_dead`, position; a dead or freed target ends a telegraph or hunt at once |
| Lurker → World | `get_first_node_in_group("world").play_rect()`: "on screen" is the play area between the gutters |
| Lurker → Player (kill) | Lurker becomes `monitorable` only while hunting with the scent → Player's `Hurtbox.area_entered` → `die()` |
| Anyone → Fx | static calls `Fx.pop / chain_popup / popup(parent, …)` |

**Groups used:** `player`, `enemy` (crawlers), `predator` (lurkers), `world`.

## State Management

There are three kinds of state. Only `Settings` is saved to disk, as `user://settings.json`.

1. **Chain state (per life):** `ChainState` on the player — `count`, `held`, `snuffed`, `clinging`. A death spawns a fresh player, so a fresh chain.
2. **Session state (survives death):** pure objects held by the `Game` autoload (Story 1.4). A death never reloads the scene; `Game` and its objects live all session and are reset in place, never replaced:

   | State | Meaning |
   |---|---|
   | `Game.dive.carried` (`DiveState`) | the haul: embers banked so far (M1 "banked" = M2 "carried") |
   | `Game.dive.respawn_room` / `respawn_entry` | the respawn point; nothing sets it until anchors and stations (Story 1.24), so World respawns at its start: `start_room` at `start_entry`, the room's `P` unless DevTools' `--room=` picked another room and entry (Story 1.11) |
   | `Game.slot.best_chain`, `Game.slot.deaths` (`SlotState`) | records shown on the HUD |
   | `Game.settings.brightness` (`Settings`) | brightness level (index into `World.AMBIENT_LEVELS`), saved in `user://settings.json` by `core/save_store.gd`; `Game.boot()` (called once by World as the entry scene) loads it. No in-game key changes it: until Options (1.36) it changes only through `--set=brightness:N` (DevTools, debug builds), session only. A session with any `--set` writes no `settings.json` (`Game.override_setting()`, Story 1.11) |

3. **Actor state:** private vars on each node (timers, the lurker's FSM `state`). A respawn resets the player's; enemies are rebuilt with their room on every entry and respawn, and an enemy killed this dive stays dead because the build skips cells in `DiveState`'s killed set (Story 1.7).

### Chain rules (ChainState)

| Event | Call | Count | Held embers | Light radius |
|---|---|---|---|---|
| Pogo hit | `add_hit()` | +1 (cap 20); no change while snuffed | `+= ember_value(link)` (pays even at the cap) | `40 + 22·√n` |
| Landing, crawler knock, cling timeout | `break_chain()` | → 0 | **banked** (emits `banked`) | → 40 |
| Snuff (hold V past `Settings.light_tap_window`, 0.12 s by default) | `set_snuffed(true)` | → 0 (breaks) | banked | → 12 while held |
| Wall cling | `set_clinging(true)` | kept (paused) | kept | → 40 while clinging |
| Death | `lose()` | → 0 | **lost** | — |

`ember_value(link) = link`, so a chain of *n* pays n(n+1)/2. Blade Bloom scales the slash and pogo areas by `1 + 0.18·√n` (never the hurtbox).

## Component Overview

Full catalogue with fields and tuning: [Component Inventory](./component-inventory.md). In short:

- **Player** (`CharacterBody2D`) — reads only its `PlayerInput` intents (Story 1.8); run, variable jump, coyote/buffer, air dash, wall cling and kick, ground slash, air pogo, hitstop, light easing, knockback and death. It emits `pogo_hit`; the camera is not part of it.
- **Crawler** (`CharacterBody2D`) — walker (patrols, turns at walls and edges) or hoverer (sine drift, phase set by position for determinism). Dies to any hit.
- **Lurker** (`Area2D`) — `IDLE → TELEGRAPH (0.9 s) → HUNT → RETURN`. It notices only a light ≥ 80 px, within radius × 1.6, **and** while on screen. It is lethal only while it is hunting *and* has the scent.
- **World** — one swap path for the first room, an exit and a respawn (`enter_room()`, always deferred; the old room leaves the tree before `queue_free()`), polled exits with the chain backstop, `start_room` / `start_entry`, the darkness, `play_rect()`, `light_rect()`, `current_room()`, `room_entered` / `player_spawned`. In debug builds the first statement of `_ready()` adds DevTools. In every build, `_ready()` then adds the `LightBudget` child (Story 1.12), which applies the light budget every physics tick at priority 50, after the actors.
- **CameraRig** — follows the player with M1's 70 px downward lead; with physics interpolation on (Story 1.7) it smooths and clamps itself on the physics tick (engine smoothing off), so `snap()` cuts and `play_rect()` and `view_rect()` (the whole 480 × 270 view, Story 1.12) are computed, never read from the engine camera. Owns the shake (`kick()`) and the limits.
- **Gutters / ScreenRouter** — two flat 60 px strips; one full-screen UI screen at a time.
- **Fx** — unshaded particles and labels that read in the dark, drawn with two shared materials built once, `Fx.unshaded()` and `Fx.additive()` (Story 1.12).
- **BudgetLight** (`core/budget_light.gd`, Story 1.12) — every `PointLight2D` in the game: a rank (ALWAYS for the player and flares, CACHE, GLOW for lurker glows), a pure rule that keeps at most 6 lit in the view, and an additive sprite fallback for a demoted light.
- **DevTools** (`scripts/dev/`, debug builds only; Story 1.11) — entry args (`--room`, `--chain`, `--log`, `--set`, and from Story 1.12 `--glow` and `--perf`; the URL query on a web debug build), applied only when World is the current scene, and four overlays cycled by the backquote key (`dev_overlay`), also while paused. `--perf` adds `PerfRun` (`perf_run.gd`), the timed autopilot run of [perf.md](./perf.md). A bad arg is a `push_warning` and the game still starts. In a real run it prints `[room] SMOKE boot ok` once, on World's first `room_entered` (Story 1.13: the web smoke's boot marker). World adds it with one path-string `load()` under `if OS.is_debug_build():`; the release presets exclude `scripts/dev/*` (Story 1.13; `tools/export.sh` checks every release PCK and boots the Linux build), and nothing outside `dev/` and `tests/` names it.

## Key Runtime Flows

### Physics frame (Player)

```
input.sample() → _tick_timers → _handle_snuff → _handle_cling ─(not clinging)→ _handle_horizontal, _handle_vertical, _handle_attack
→ move_and_slide → if on floor: end cling, refill cling/coyote/dash, chain.break_chain()
→ _process_swing (pogo hit → _on_pogo_hit) → _check_contact (crawler knockback) → _update_light
```

`_process` runs on **real time** (`delta / Engine.time_scale`) so the squash keeps moving during hitstop. `CameraRig._process` does the same for the shake and the camera lead.

### Pogo hit

`_process_swing` finds an overlapping body with `take_hit()`. The crawler dies (`Fx.pop`, `queue_free`). If the swing is a pogo and the player is not on the floor, `_on_pogo_hit` then:

1. Sets velocity.y to −300 and refreshes dash and cling grace.
2. Calls `chain.add_hit()` and flares the light by 18 px.
3. Adds a stretch squash and emits `pogo_hit`, which kicks the camera 2.5 px.
4. Shows `Fx.chain_popup`.
5. Freezes for 75 ms: `Game.clock.request(&"hitstop", 0.05, 0.075)`. The Clock times it in real time and is the only writer of `Engine.time_scale`.

### Death and respawn

`die()` → `Game.clock.clear()`, `chain.lose()` (a "−N lost" popup) → `died` → World records a death (`Game.slot.record_death()`) and starts a 0.6 s timer that ignores the time scale and pauses with the tree. On timeout it clears the Clock again and goes through the swap path: it rebuilds the respawn room (enemies killed this dive are skipped, the rest return to their cells), frees the old player, spawns a fresh one at the respawn point (the dive's start until anchors set one: the start room's `P`, or `--room=`'s entry), snaps the camera and emits `player_spawned`, then `room_entered`. No reload: `Game` stays, so carried embers are kept and held embers are lost. A lurker drops a hunt on a dead target at once (Pillar 2).

## Level Data

The level is a room file, `game/rooms/l1/m1_shaft.txt` (Story 1.5): a `key=value` header, `---`, then 105 rows × 22 columns (352 × 1680 px, walls included), one char per 16 px tile. It holds 1 spawn, 5 walking crawlers, 36 hovering crawlers (in pairs per row) and 4 lurkers, with ledge rows 6, 24, 41, 57, 72, 85 and 103 (no fall between ledges over 19 rows, FR57) and a floor hole for the `down` exit that loops to its own top (R16, wired in Story 1.7). The bottom floor's left walker starts at column 8, 5 cells from where a player arriving from below stands (Story 1.10). `smoke_rooms` and `smoke_bot` check every room file against the design guarantees (see Testing Strategy and [rooms.md → Room checks](./rooms.md#room-checks)).

`RoomLoader` (`scripts/world/room_loader.gd`) parses the file, checks it with a pure validator (every error as `file:row:col`; a bad file never builds) and builds a `Room` (`scripts/world/room.gd`): a backdrop, a `TileMapLayer` with a TileSet built once in code from `art/tile.png` (no `.tres`), an unshaded 1 px **ledge rim** on every wall tile with open space above, and the entities spawned through `room.spawn()`. The chars are defined in `scripts/world/room_legend.gd`; the format, legend, validator errors and Room API are in [rooms.md](./rooms.md). `CameraRig.apply_limits()` centres a room no wider than the 360 px play area in the 480 px view (`m1_shaft`: limits −64 / 416), between the two 60 px gutters; a wider room scrolls until its edges reach the gutters. The 4 px either side of a 352 px room show the clear colour, which `Gutters` sets at `_ready` to its own fill, the gutter violet `#07060b`, so the bands merge with the gutters (CanvasModulate never tints the clear colour). The colour has that one home; when the gutter fill becomes per-zone (Story 1.18), it sets the clear colour with it. Before World is ready (the boot splash) the clear colour is the engine default.

## Physics Layers

| Layer | Name | Used by |
|---|---|---|
| 1 | world | wall tiles; mask of player and crawlers |
| 2 | player | player body |
| 3 (value 4) | enemies | crawlers; mask of the Slash and Pogo areas |
| 4 (value 8) | predators | lurkers; Hurtbox mask = 12 (enemies + predators) |

## Rendering and Light

- `CanvasModulate` darkens everything. Its colour is `AMBIENT_LEVELS[i] × AMBIENT_TINT` (violet cast), with 4 levels. `World` applies `Settings.brightness`, which persists in `settings.json`. The `CanvasModulate` tints only canvas layer 0, so the gutters and the UI layer are never darkened.
- The player's `PointLight2D` uses `light.png` (128 px). Its `texture_scale = shown_radius / 64`, and `shown_radius` eases toward `chain.light_radius()`.
- The lurker's eyes and the slash/pogo sprites, Fx and ledge rims use `LIGHT_MODE_UNSHADED`, so they read at any brightness. The lurker's red `PointLight2D` glow tracks the eye alpha.
- **The light budget** (AR46, Story 1.12): every `PointLight2D` is a `BudgetLight` (`core/budget_light.gd`; lint `raw_light`, and `test_light_budget` audits the scenes) on the shared `light.png`, sized by `texture_scale`. The player's `Light` is rank ALWAYS, the lurker's `Glow` GLOW. World's `LightBudget` child applies `BudgetLight.apply()` every physics tick at priority 50, after every actor has moved and set its light, so a glow that wakes on a tick is never drawn past the budget. A light *wants* light when it is shown, has energy and a texture; on-screen lights that want light keep their `PointLight2D` up to 6: ALWAYS first (never demoted, even past the budget, reported as `over`), then CACHE, then GLOW; within a rank a lit light keeps its slot (nothing flickers), then the nearest the centre wins. A demoted light's `PointLight2D` is disabled and its additive, unshaded `Fallback` sprite shows instead, same texture, colour and size, alpha following energy. Off-screen lights are left as they are.
- **On screen for the budget** is `World.light_rect()`, the rig's `view_rect()`: the whole 480 × 270 view, gutters included. A cost rule (the engine draws and culls lights against the viewport), not AR20's fairness rule, which stays `play_rect()`. In `m1_shaft` at most 5 lights ever want light, so nothing is demoted there.
- Flash safety: the invulnerability blink is 2.5 Hz and the eye pulse 2 Hz, both under the 3 flashes/s cap.

## Asset Pipeline

```
tools/sprites/palette_edge.txt ─┐
tools/sprites/<name>.txt ───────┼─► python3 tools/build_sprites.py ─► game/art/<name>.png
                                └─► (generated) ─────────────────────► game/art/light.png (128×128 radial, smoothstep falloff)
```

- Each grid char is a palette key, and `.` is transparent. Rows must be the same width. An unknown key is an error with the coordinates.
- Palette keys: `0 1 2 3` (dark → light greys/violets), `L` chain-light amber `#ffd27a` (the same in every layer), `E` lurker red, `e` hot eye core.
- `light.txt` is not allowed, because it would overwrite the generated light texture.
- The PNGs and their `.import` files are committed. After a rebuild, open the project (or run `godot --headless --import`) to re-import.

## Testing Strategy

| Layer | File | What it covers |
|---|---|---|
| Unit | `tests/test_chain_state.gd` | `ChainState`: hit/land/snuff/cap, monotonic curves, `changed` signal only on real changes, embers held → banked → lost, cling pause |
| Unit | `tests/test_log.gd` | `Log`: `[category] message` format, the fixed categories, debug categories off by default and toggled by `set_enabled()` |
| Unit | `tests/test_clock.gd` | `Clock`: ids multiply, a re-request refreshes (latest scale wins, never stacks), real-time expiry, pause freezes requests, `_exit_tree` and player death clear them, a pogo hit requests the 75 ms hitstop, `active()` is a read-only `{id: scale}` copy (Story 1.11) |
| Unit | `tests/test_tuning.gd` | `Tuning`: `f()` / `flag()`, gear modifiers apply set → add → mul in every order, one `changed` per `apply_gear()`, reset in place, the lurker telegraph ≥ `Spec.TELEGRAPH_MIN` and the crawler hover period > 0 under every combination of gear rows (probe gears prove both fire, a pair included); a regression fixture pins all 44 M1 `@export` defaults in their new homes, plus the player boxes, the chain curve, Blade Bloom and the hitstop depth |
| Unit | `tests/test_state.gd` | `Settings`, `SlotState` and `DiveState`: the signal rules, the fallbacks on bad data, the `to_dict()` shapes, round trips in memory and through JSON. `Game`: the same instances all session, `reset_for_tests()`. `settings.json` through `SaveStore`: a missing, corrupt or partly bad file is rewritten, a file that can't be opened or is from a newer build is left untouched, one write per frame, and the warnings are counted. `Settings.is_valid()` (with a passed schema) and `Game.override_setting()` (Story 1.11): an override survives the load, a session with one writes no `settings.json` (not the override, not a rewrite, not another key's change), and `reset_for_tests()` drops it |
| Unit | `tests/test_room_loader.gd` | The room validator (each error at its file line and column, from fixtures in `tests/rooms/` and inline texts), the build (spawn counts, `hover` args, in-wall lurkers, rims), the `cling=` key and the `Room` API; `m1_shaft` validates and pins its counts (36 hoverers, 5 walkers, 4 lurkers), ledge rows and exits; `room_ids()` sorted as Strings and `inspect(id)` (`known`, `entries`, `errors`, never a `push_error`; Story 1.11) |
| Unit | `tests/test_room_sweep.gd` | The pure room sweeps in `tests/room_sweep.gd` on inline grids, each with a sample that fires and a near-miss: the file walk and the `rooms/dev/` rule, ledge rows (a hazard is never a ledge), spine gaps at 19 / 20 rows and with cling stretches, the fall through a down exit, stretch widths 6–10, hazard pits, unique room and obj ids, exit links, and the safe arrival from below (3 cells, Chebyshev) |
| Unit | `tests/test_fx.gd` | `Fx` (Story 1.12): `unshaded()` and `additive()` each built once (unshaded mix / unshaded add), different instances, `pop()` and `popup()` drawn with `unshaded()`, the sparks freeing themselves |
| Unit | `tests/test_light_budget.gd` | `BudgetLight` (Story 1.12): `choose()` (8 on screen keeps 6 and drops the farthest GLOWs; 7 ALWAYS all kept over the budget; the CACHE before nearer GLOWs; stickiness; a freed slot relit; off-screen left as given; budget 0), the jitter case (120 passes, each light changes at most once), `apply()` on nodes (demotion disables the light and shows the sprite, recovery, hidden and dark lights take no slot, a raw `PointLight2D` not counted), the sprite's alpha following energy, `lit_on_screen()` / `texture_rect()` (moved from 1.11's overlay), `MAX_ON_SCREEN ≤ Spec.LIGHTS_ON_SCREEN_MAX`, and the scene audit: every `PointLight2D` under `scenes/` is a `BudgetLight` on `light.png` (read through `SceneState`), the player's ALWAYS, the lurker's GLOW, its eyes unshaded |
| Unit | `tests/test_export_presets.gd` | `game/export_presets.cfg` (Story 1.13): four presets numbered 0–3 with their names and platforms, `all_resources`, the `rooms/*.txt` include, the exact release and debug excludes, single-threaded web written explicitly, `embed_pck=false`, an options section per preset, no absolute `export_path`, custom template or encryption; then the exporter's own matcher (`String.matchn()`, on `res://path` and `path`) over the real files under `rooms/`, `tests/` and `scripts/dev/` (sentinels first): every room in every preset, `rooms/dev/` in `Web debug` only, no test file anywhere, DevTools in `Web debug` only; from Story 1.14 the web presets' `html/canvas_resize_policy=2`, `html/focus_canvas_on_start=true` and the same `html/head_include` key guard in both |
| Unit | `tests/test_display.gd` | `Display` (Story 1.14): `scale_for` / `stretch_for` on both sides of every boundary, `window_scale_for`, `BASE` and the ×3 override against `project.godot`, the effective display settings, `Game.display` inert before `start()`, `apply()` switching the stretch both ways with one `scale_changed` per change, `start()` inert under headless |
| Unit | `tests/test_dev_args.gd` | DevTools' pure parts (Story 1.11): the URL query as `--key=value` tokens (decoded after the split), the arg grammar (tokens without `--` skipped, unknown args listed, repeats) and the registry's order, each validator (`--chain` 0..20, `--log` names in any case, `--set` typed by the key's default), the `--room=` entry pick (`spawn`, else `up`, else `down`) the overlay's Clock rows (live, greyed for 0.5 s, then dropped) and mode 2's `light_marks()` (reach = radius × 1.6; noticeable from 80 px, the base light never); from Story 1.12 `--glow` (`on`/`off` only) and `--perf` (60 s by default, 1–600) values, the glow `Environment`, the perf run's `path_point()`, frame stats (per-second buckets by frame start, slow frames over 20 ms) and summary line, and the overlay's summary rows |
| Integration (headless) | `tests/smoke_rooms.gd` | Every `res://rooms/**/*.txt` (sentinel: `m1_shaft`): validated (each error a `FAIL`, never built), ids and links across files, and per swept room the spine falls (≤ `Spec.LEDGE_FALL_MAX`), cling stretches, hazard pits and the arrival from below; the tuned max fall, telegraph and notice floor against `Spec`. Loaded through `tests/room_harness.gd` (a test player, a `CameraRig` and a stub `World` with `play_rect()` and `current_room()`): per lurker, base light and the largest light under 80 px never noticed point-blank (the lurker's own floor is), no notice just outside the play rect though in reach (the same light on screen is), the telegraph measured ≥ 0.75 s then a hunt that closes in; for the first lurker, IDLE and TELEGRAPH contact harmless and HUNT contact lethal, and a Snuff (also point-blank, 18 px), a landing and a cling each make a hunting lurker harmless in time, with the player alive and the hunt over within 1 s |
| Integration (headless) | `tests/smoke_bot.gd` | A **bot** plays every spine room top to bottom with plain movement (no dash, lurkers paused): chain ≥ `Spec.BOT_MIN_CHAIN`, chain 0 whenever it crosses an exit (the backstop never fires on its line), reaches the down exit alive |
| Integration (headless) | `tests/smoke_moves.gd` | The M1 move checks on `m1_shaft`: pogo builds the chain; landing breaks it; jump height (held ≈ 60 px, tap < 60 %); wall cling/timeout/kick; releasing Light ends a Snuff |
| Integration (headless) | `tests/smoke_player_input.gd` | `tests/rooms/input/t_input.txt`: M1 movement pinned before the `PlayerInput` switch (run 110 px/s, coyote 0.08 s, jump buffer 0.10 s, air dash 260 px/s for 8–9 ticks, ≈ 39 px, as M1 measures it, once per airtime); the Light tap/Snuff windows 0.12 / 0.2 / 0.3 s on both sides of each boundary, the Snuff latch, Light across a pause and a 75 ms hitstop on real time, Jump and Attack buffers on real time, the attack buffer, the wall drop on ↑, ↓ interact thresholds, `lock()` / `unlock()` (no raw `Input` outside `player_input.gd` is `test_lint`'s `raw_input`) |
| Integration (headless) | `tests/smoke_room_swap.gd` | Two test rooms (`tests/rooms/swap/`, indexed with `RoomLoader.add_root()`): `enter_room()` is deferred; the floor hole banks the chain before the swap and arrives at the top entry still falling; the old room is out of the tree but not yet freed at `room_entered`; the ceiling gap arrives standing beside the target's floor hole; killed cells stay empty across swaps and a cross-room respawn at the start room's `P`; interpolation on |
| Integration (headless) | `tests/smoke_world.gd` | Instances `world.tscn`: a World added by a test never boots `Game`; the tree and its order; camera limits, the 360 px play rect and the 60 px gutters; a bank raises `Game.dive.carried`, a chain `Game.slot.best_chain`, `Settings.brightness` repaints the darkness; popups go under the room; a death respawns a fresh, rebound player at `P` without a reload, clears the Clock and rebuilds the room without the crawler killed before it; the bottom hole loops to the top (R16) with the chain banked first and a killed crawler still gone; a lurker behind a gutter never notices; a hunt drops on a death; `ScreenRouter` replaces, never stacks |
| Integration (headless) | `tests/smoke_dev_tools.gd` | DevTools in a real `world.tscn`, tokens injected through World's `child_entered_tree` (Story 1.11): inert with none (start room, chain, Log untouched, Clock, settings, overlay, nothing outside its subtree); a World that is the current scene reads `real_tokens()` (the command line after `--`); every bad arg warned in one run while the good ones apply; `--room=` with a `P`, without one (the up entry, falling) and a respawn there, never writing the respawn point; an unknown or invalid room warns and loads `m1_shaft`; `--chain=8` on `tests/rooms/dev_tools/t_dev_room.txt`, armed every life, paid on the first airborne tick (held 36), banked 36 on landing, and not paid while paused or to a player spawned inside a tick before it has ticked; `--log` (merged; no valid category leaves `Log` alone); `--set` survives the load and writes nothing; the overlay cycle (also while paused, unshaded, layer above UI), mode 2 past the notice radius beside a sensing lurker, the Clock rows, the light count from `BudgetLight.counts()` on `light_rect()` (a code-built light under a gutter counts, one outside the view and a raw `PointLight2D` don't; Story 1.12), the `lights n/6` and `frame` rows and `cycle()` resetting the worst frame, mode 3's items drawn; no action bound to a function key; the boot marker (Story 1.13): a real-run World prints `[room] SMOKE boot ok` exactly once with its room built, a test World none, a respawn no second one |
| Integration (headless) | `tests/smoke_perf.gd` | The perf kit in a real `world.tscn` (Story 1.12): `--room=perf_worst --perf=3` locks the player, masks its `Hurtbox`, pays chain 20 within 10 ticks, then on every tick until done holds the chain, keeps it alive on x 240, keeps ≤ `Spec.LIGHTS_ON_SCREEN_MAX` lit in the view and never demotes the player's light or the flare (sampled on `physics_frame`, so it sees what was drawn); the budget is exercised (a sprite, GLOWs only) and already holds at the first wake; 100 px per 60 ticks; the stand-ins (ALWAYS flare at the player's radius, CACHE cache, children of the room); the summary (breaks 0, deaths 0), logged once and shown in overlay 4. Also: `--chain=99 --perf` holds 20 and `--chain=5` holds 5; `--room=perf_worst` alone is the plain room; `--glow=on/off/yes`; bad `--perf` values; `light_rect()` is the 480 × 270 view around the play rect; `m1_shaft` never has more than 6 `BudgetLight`s |
| Lint (headless) | `tests/test_lint.gd` | Text scan of every `.gd` under `scripts/`: `time_scale`, `raw_input`, `print`, `free`, `root_path`, `keycode`, `random`, `rules_purity`, `core_layer`, `dev_ref`, `raw_light` (Story 1.12), `tests_ref`, `state_write` (each with sample lines that prove it fires and stays quiet where it must), and every `tests/spec.gd` const cites the GDD. `dev_ref` lets through only `world.gd`'s one guarded DevTools line, and a tree check proves the real `world.gd` holds it exactly once (Story 1.11). Prints `FAIL lint <file>:<line> <rule>` |
| Helper | `tests/spec.gd` | The GDD's guarantees as numbers (`TELEGRAPH_MIN` 0.75, `BOT_MIN_CHAIN` 5, `BASE_LIGHT` 40, `NOTICE_MIN_RADIUS` 80, `LEDGE_FALL_TIME` 1.5, `LEDGE_FALL_MAX` 315, `NARROW_MIN` 6, `NARROW_MAX` 10, `LIGHTS_ON_SCREEN_MAX` 6), each with its GDD citation; tests compare against these, never against tuning |
| Helper | `tests/room_sweep.gd` | The pure room sweeps (Story 1.10): static functions over a parsed grid that return `"<id>: <what>"` errors; `smoke_rooms` and `smoke_bot` preload it |
| Visual (manual) | `tests/screenshot.gd` | Two PNGs (spawn; chain 10 with a telegraph). Needs a renderer: `xvfb-run` on the server |

Design rules are encoded as tests, over every room file: the telegraph is never under 0.75 s, there is no off-screen ambush, a Snuff, landing or cling in time always saves you, a spine room has a ledge within every 1.5 s of fall, and the bot reaches chain 5 in every spine room. Their thresholds live in `tests/spec.gd`. Change these rules in the GDD first, then in `spec.gd`. `run_tests.sh` finds tests by glob (`test_*.gd`, then `smoke_*.gd`; Story 1.9).

The lint is stricter than AR48's list on purpose (Story 1.9 D3, widened again by its code review): every `KEY_*`, not only `KEY_F`; `raw_input` covers `InputMap`, `InputEvent*`, the input callbacks and `Input` as a value; `random` adds `randfn`, `randomize`, `seed`, `pick_random`, `shuffle` and `RandomNumberGenerator`; `rules_purity` adds Node classes from ClassDB, `OS`, `Time`, file access, `load(` and the classes of every layer above; `tests_ref` and `state_write` are new. The full table is in the development guide.

**Variance from `game-architecture.md` → Enforcement** (Story 1.11 D12): two rules are shaped by DevTools. `raw_input` also allows `dev/`: the rule keeps gameplay on `PlayerInput` intents, and DevTools reads only its own `dev_overlay` action, ships in no release build and must work while the player is dead, locked or absent. `dev_ref` is a line rule, not a file rule: outside `dev/` it fails on `DevTools`, any `class_name` declared under `dev/` (collected at run time) and any `res://scripts/dev/` or `res://scenes/dev/` path, except `world.gd`'s one line, `add_child(load("res://scripts/dev/dev_tools.gd").new())`, let through once per file and only right under `if OS.is_debug_build():`. A tree check proves the real `world.gd` holds that line exactly once, so an exemption that no longer matches the code fails.

Last run: 2026-11-20, **ALL GREEN** (22 tests, bot best chain 8 over the full `m1_shaft` descent).

## Deployment

Builds come from the headless server (Story 1.13): `tools/export.sh` validates the rooms (`smoke_rooms`), exports the four presets of `game/export_presets.cfg` to `builds/<yyyymmdd>-<sha7>[-dirty]/`, lists every PCK with `tools/pck_list.gd` (no `rooms/dev/`, `tests/` or `scripts/dev/` in a release), checks the web download (gzip, under 30 MB), boots the Linux release headless for 5 s and runs the web smoke (`tools/web_smoke/`: both web builds in headless Chromium; the debug one must print `SMOKE boot ok`; from Story 1.14 the scale at devicePixelRatio 1, 1.5 and 2, measured from device-pixel screenshots, and keys that must not scroll an itch-style host page, `embed.html`). The laptop plays the builds (rsync, or the web build through an SSH tunnel to `serve.js`) and still uses the editor (F5) for feel work. No CI. Details: [build.md](./build.md).

## Conventions and Gotchas (for anyone changing the code)

- **Keep ChainState free of nodes.** It is the unit-tested core. New chain rules (Flare Toss halving, hit → "carried") belong there, with tests.
- **Session state lives in `Game`, never in statics.** Anything that must survive a death goes into `Game.slot`, `Game.dive` or `Game.settings`, through their methods. A test that changes them ends with `Game.reset_for_tests()`.
- **A death never reloads the scene.** World rebuilds the respawn room, spawns a fresh player and emits `player_spawned(player)`; anything bound to the player or its chain rebinds there. Only the entry scene calls `Game.boot()`: a test adds World by hand, so it never boots.
- **Hitstop goes through `Game.clock`.** Request it with `Game.clock.request(&"hitstop", 0.05, 0.075)`; never write `Engine.time_scale` yourself. Use timers with `ignore_time_scale = true` for anything that must run during it. `die()` calls `Game.clock.clear()`.
- **Determinism:** no randomness in level behaviour. Hover phase comes from position, and `reset_phase()` exists so tests do not depend on order. Only the camera shake uses `randf` (`world/camera_rig.gd`).
- **Lurker lethality is `monitorable`.** It is false except in HUNT with the scent. Do not add other kill paths that skip this, or the rule "Snuff/landing in time always saves you" breaks.
- **Polling, not `body_entered`, for crawler contact**, so a crawler still overlapping when invulnerability ends still hurts.
- **Tuning names match the GDD tables; keys live in `rules/tuning.gd`.** When you change a value, update the GDD tuning table (M1 values are marked there).

## Gaps Against the M2 Design

Observations from comparing this code with GDD v1.0 and the UX spines (2026-11-11). They are inputs for the architecture notes, not decisions.

| Area | M1 as built | M2 target (source) | Likely impact |
|---|---|---|---|
| Play width | Shaft is 22 tiles (352 px), centred in the 360 px play area between two flat 60 px gutters (Story 1.6); lurkers notice only inside `World.play_rect()` | ~60 px HUD gutters, ~360 px view; spine shafts 22 tiles (352 px); wider rooms scroll horizontally (GDD Level Design, UX) | Camera limits/viewport split and the gutters (Story 1.6) |
| Scene structure | `World` (Story 1.6) holds one room at a time and swaps rooms through exits (Story 1.7) | Hub + Layer 1 spine and branches, rooms, Weaver arena (GDD World Map) | `World` and room swaps (Stories 1.6–1.7) |
| Damage | Crawler = knockback only; hunting lurker = instant death | 4 HP; crawler 1, lurker 2, spikes 1; heal at stations (GDD Health) | Health component; lurker contact deals damage instead of calling `die()` |
| Embers | held → banked (`Game.dive.carried`) → held lost on death | held → **carried** → **deposited** at a Lift Station/hub (GDD Economy) | Rename and extend ChainState/economy; deposit flow |
| Respawn | The shaft's spawn `P` (`DiveState` has an unused respawn point) | Lantern anchors and Lift Stations; hazards respawn at the last safe ledge in the room | Anchors and stations call `DiveState.set_respawn()` (Story 1.24); a last-safe-ledge tracker for hazards (Story 1.19) |
| Light key | Hold V past the tap window = Snuff; a tap is a `light_tap` intent that does nothing yet, Flare Toss in 1.23 (Story 1.8's `PlayerInput`, window in `Settings`) | Tap = Flare Toss (needs ≥ 2 links, halves the chain); tap window 0.12/0.2/0.3 s setting; optional Snuff toggle key (GDD Controls) | Light input state machine; Flare entity that predators sense |
| Input | Keyboard only; `PlayerInput` is the only gameplay reader of `Input` (Story 1.8); no function keys: DevTools (Story 1.11, debug builds) has one action, `dev_overlay` on the backquote key, and brightness changes only through `--set=brightness:N`, session only, until Options (1.36) | Gamepad from M2; Pause (Esc/P); rebinding in E7; DevTools sets brightness until Options (Story 1.36) | Input map + settings; the M1 debug hotkeys are gone |
| HUD | None since Story 1.6: two flat gutters; the chain popups still show the count in the world | Gutter HUD, Fusion Pixel Font 8px (OFL files must ship), alert frame in the gutters (UX DESIGN) | Real HUD scene; font licence files in builds |
| Lurker warning | On-screen telegraph only | Off-screen "stir": panned audio + half-open eye at the edge (GDD Lurker) | Needs audio and an edge indicator |
| Persistence | `settings.json` only (brightness); session state in `Game`, not saved | 3 save slots, autosave at stations/hub/anchor quit, visible save failure (GDD Saves, UX) | Save system |
| Audio | None | SFX + chain-reactive music (E3) | Audio bus layout |
| Death feedback | "−N lost" popup | Death card lines stored from E1 for the E7 Journal (UX); Field Journal line (deferred-work) | Record the death cause |
| Builds | Windows, Linux, web and web debug exported and boot-checked on the server (Story 1.13, [build.md](./build.md)); the perf scene exists (`rooms/dev/perf_worst.txt`, `--perf`, `--glow`; [perf.md](./perf.md), Story 1.12), measured in Story 1.15; display scaling and web input (Story 1.14: `Game.display`, the web key guard in both web presets, the smoke's `Display scale` and `Web input`) | Windows, Linux, web/itch.io 960×540; 60 FPS on HD 620 class (GDD Performance) | Licence files in builds (1.17); the Windows boot (7.15) |
