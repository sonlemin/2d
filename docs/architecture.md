# The Unbroken Chain — Architecture (as built, M1)

**Date:** 2026-11-11 · **Branch:** `feat/m1-prototype` · **Scope:** the code in `game/` and `tools/`

This document describes the M1 prototype **as it is**. The design target for M2 lives in the [GDD](../_bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md) and the [UX spines](../_bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/). Where the code and those documents differ, see [Gaps against the M2 design](#gaps-against-the-m2-design). That section lists observations, not decisions.

## Executive Summary

A single-scene Godot 4.7 prototype that answers one question: *does a long pogo chain feel tempting and dangerous?* (Answered **yes** on 2026-11-10; see the [playtest findings](../_bmad-output/implementation-artifacts/m1-playtest-findings.md).)

The architecture is deliberately small:

- One **pure-logic class** (`ChainState`) holds the core rules, so they can be unit-tested with no scene.
- Rooms are **text files** (`rooms/<layer>/<id>.txt`) that `RoomLoader` validates and builds into a `Room` node; one **interim level script** (`shaft.gd`) loads `m1_shaft` and runs the M1 loop around it. Session state lives in `Game`.
- Three **actor scripts** (Player, Crawler, Lurker) talk to each other only through physics overlaps, groups and duck-typed methods.
- One **static helper** (`Fx`) makes effects in code.
- Art comes from a **text-to-PNG pipeline** outside Godot.

## Technology Stack

| Category | Technology | Version / setting | Why |
|---|---|---|---|
| Engine | Godot | 4.7 (`config/features`) | GDD platform decision |
| Language | GDScript | typed where practical | GDD: GDScript only |
| Renderer | GL Compatibility | desktop and mobile | Required for web builds |
| Resolution | 480×270 viewport | `stretch/mode=viewport`, `scale_mode=integer`, window 1440×810 (×3) | Crisp pixel art |
| Pixel rules | nearest filter, `snap_2d_transforms_to_pixel` | project-wide | No sub-pixel shimmer |
| Lighting | `PointLight2D` + `CanvasModulate` | one shared 128 px gradient texture | The "light in the dark" pillar |
| Physics | Godot 2D built-in | default 60 ticks/s | `CharacterBody2D` for actors |
| Test runner | Godot headless + `tests/runner.tscn` (each test is a `Node` script) | no framework | Runs on the headless dev server |
| Asset tool | Python 3 + Pillow | `tools/build_sprites.py` | Art as reviewable text |
| Addons / autoloads | autoload `Game` (holds `clock`, `tuning`, `settings`, `slot`, `dive` and `store`); no addons | — | `Audio` joins in E3 |
| CI / export presets | none | — | Builds are made from the editor on the laptop |

## Architecture Pattern

**Scene-tree composition with a pure-logic core.**

```
              ┌──────────────────────── shaft.tscn (Node2D, shaft.gd) ───────────────────────┐
              │  Darkness (CanvasModulate)                                                    │
              │  m1_shaft (Room, built by RoomLoader from rooms/l1/m1_shaft.txt at _ready)    │
              │    Backdrop (ColorRect)  Walls (TileMapLayer)  Rims (ColorRect × N)           │
              │    Crawler × N, Lurker × N   (spawned through room.spawn())                   │
              │  Player (player.tscn) ── owns ──► ChainState (RefCounted)                     │
              │  Debug (CanvasLayer: Label HUD)                                               │
              └───────────────────────────────────────────────────────────────────────────────┘
```

- **ChainState** is a `RefCounted` with no node dependencies. It owns the count, snuffed/clinging flags and held embers. It computes the light radius and Blade Bloom, and emits `changed(count)` and `banked(amount)`.
- **Player** owns one `ChainState` (`player.chain`) and turns input and collisions into calls on it (`add_hit`, `break_chain`, `set_snuffed`, `set_clinging`, `lose`). It then applies the results to its nodes (light texture scale, hitbox scale).
- **Shaft** reads the player's state for the HUD. On `chain.banked` it calls `Game.dive.add_carried()`, and on `chain.changed` `Game.slot.record_chain()`, so the haul and the records live in `Game`.
- **Lurkers** poll the player each physics frame through `player.light_radius()`.

### Communication between parts

| From → To | Mechanism |
|---|---|
| Player → ChainState | direct method calls |
| ChainState → Player | signals `changed`, `banked` |
| ChainState → Shaft | signal `banked` (calls `Game.dive.add_carried()`); signal `changed` (calls `Game.slot.record_chain()`) |
| Player → Shaft | signal `died` (`Game.slot.record_death()`, then respawn); Shaft polls `chain` and `position` every frame for the HUD |
| Player → Crawler | `Pogo`/`Slash` area overlap → duck-typed `body.take_hit()` |
| Crawler → Player | Player's `Hurtbox` polls overlapping bodies in group `enemy` → knockback |
| Lurker → Player | `get_first_node_in_group("player")` → `light_radius()`, `is_dead`, position |
| Lurker → Player (kill) | Lurker becomes `monitorable` only while hunting with the scent → Player's `Hurtbox.area_entered` → `die()` |
| Anyone → Fx | static calls `Fx.pop / chain_popup / popup(parent, …)` |

**Groups used:** `player`, `enemy` (crawlers), `predator` (lurkers).

## State Management

There are three kinds of state. Only `Settings` is saved to disk, as `user://settings.json`.

1. **Chain state (per life):** `ChainState` on the player — `count`, `held`, `snuffed`, `clinging`. Reset by the scene reload on death.
2. **Session state (survives death):** pure objects held by the `Game` autoload (Story 1.4). A death calls `reload_current_scene()`, which rebuilds every node, but `Game` and its objects live all session and are reset in place, never replaced:

   | State | Meaning |
   |---|---|
   | `Game.dive.carried` (`DiveState`) | the haul: embers banked so far (M1 "banked" = M2 "carried") |
   | `Game.dive.respawn_room` / `respawn_entry` | the respawn point; nothing sets it until anchors and stations (Story 1.24), so the shaft respawns at `P` |
   | `Game.slot.best_chain`, `Game.slot.deaths` (`SlotState`) | records shown on the HUD |
   | `Game.settings.brightness` (`Settings`) | F1 brightness level (index into `AMBIENT_LEVELS`), saved in `user://settings.json` by `core/save_store.gd`; `Game.boot()` (called once by the shaft as the entry scene) loads it |

3. **Actor state:** private vars on each node (timers, the lurker's FSM `state`). Each reload resets it.

### Chain rules (ChainState)

| Event | Call | Count | Held embers | Light radius |
|---|---|---|---|---|
| Pogo hit | `add_hit()` | +1 (cap 20); no change while snuffed | `+= ember_value(link)` (pays even at the cap) | `40 + 22·√n` |
| Landing, crawler knock, cling timeout | `break_chain()` | → 0 | **banked** (emits `banked`) | → 40 |
| Snuff (hold V ≥ 0.12 s) | `set_snuffed(true)` | → 0 (breaks) | banked | → 12 while held |
| Wall cling | `set_clinging(true)` | kept (paused) | kept | → 40 while clinging |
| Death | `lose()` | → 0 | **lost** | — |

`ember_value(link) = link`, so a chain of *n* pays n(n+1)/2. Blade Bloom scales the slash and pogo areas by `1 + 0.18·√n` (never the hurtbox).

## Component Overview

Full catalogue with fields and tuning: [Component Inventory](./component-inventory.md). In short:

- **Player** (`CharacterBody2D`) — run, variable jump, coyote/buffer, air dash, wall cling and kick, ground slash, air pogo, hitstop, light easing, camera shake and look-ahead, knockback and death.
- **Crawler** (`CharacterBody2D`) — walker (patrols, turns at walls and edges) or hoverer (sine drift, phase set by position for determinism). Dies to any hit.
- **Lurker** (`Area2D`) — `IDLE → TELEGRAPH (0.9 s) → HUNT → RETURN`. It notices only a light ≥ 80 px, within radius × 1.6, **and** while on screen. It is lethal only while it is hunting *and* has the scent.
- **Shaft** — level builder, HUD, input hotkeys (F1 and F3), respawn at `P`. No checkpointing.
- **Fx** — unshaded particles and labels that read in the dark.

## Key Runtime Flows

### Physics frame (Player)

```
_tick_timers → _handle_snuff → _handle_cling ─(not clinging)→ _handle_horizontal, _handle_vertical, _handle_attack
→ move_and_slide → if on floor: end cling, refill cling/coyote/dash, chain.break_chain()
→ _process_swing (pogo hit → _on_pogo_hit) → _check_contact (crawler knockback) → _update_light
```

`_process` runs on **real time** (`delta / Engine.time_scale`) so squash, shake and camera lead keep moving during hitstop.

### Pogo hit

`_process_swing` finds an overlapping body with `take_hit()`. The crawler dies (`Fx.pop`, `queue_free`). If the swing is a pogo and the player is not on the floor, `_on_pogo_hit` then:

1. Sets velocity.y to −300 and refreshes dash and cling grace.
2. Calls `chain.add_hit()` and flares the light by 18 px.
3. Adds 2.5 px of shake and a stretch squash.
4. Shows `Fx.chain_popup`.
5. Freezes for 75 ms: `Game.clock.request(&"hitstop", 0.05, 0.075)`. The Clock times it in real time and is the only writer of `Engine.time_scale`.

### Death and respawn

`die()` → `chain.lose()` (a "−N lost" popup) → `died` → Shaft records a death (`Game.slot.record_death()`) and waits 0.6 s (real time). If it is still the current scene, it calls `reload_current_scene()`. `Game` survives the reload, so the player respawns at `P` with carried embers kept; held embers are still lost.

## Level Data

The level is a room file, `game/rooms/l1/m1_shaft.txt` (Story 1.5): a `key=value` header, `---`, then 105 rows × 22 columns (352 × 1680 px, walls included), one char per 16 px tile. It holds 1 spawn, 5 walking crawlers, 36 hovering crawlers (in pairs per row) and 4 lurkers, with ledge rows 6, 24, 41, 57, 72, 85 and 103 (no fall between ledges over 19 rows, FR57) and a floor hole for the `down` exit that loops to its own top (R16, wired in Story 1.7).

`RoomLoader` (`scripts/world/room_loader.gd`) parses the file, checks it with a pure validator (every error as `file:row:col`; a bad file never builds) and builds a `Room` (`scripts/world/room.gd`): a backdrop, a `TileMapLayer` with a TileSet built once in code from `art/tile.png` (no `.tres`), an unshaded 1 px **ledge rim** on every wall tile with open space above, and the entities spawned through `room.spawn()`. The chars are defined in `scripts/world/room_legend.gd`; the format, legend, validator errors and Room API are in [rooms.md](./rooms.md). `shaft.gd` centres the 352 px room in the 480 px view; the 64 px bands on each side stay empty until the gutters (Story 1.6).

## Physics Layers

| Layer | Name | Used by |
|---|---|---|
| 1 | world | wall tiles; mask of player and crawlers |
| 2 | player | player body |
| 3 (value 4) | enemies | crawlers; mask of the Slash and Pogo areas |
| 4 (value 8) | predators | lurkers; Hurtbox mask = 12 (enemies + predators) |

## Rendering and Light

- `CanvasModulate` darkens everything. Its colour is `AMBIENT_LEVELS[i] × AMBIENT_TINT` (violet cast), with 4 levels. F1 cycles `Settings.brightness`, which persists in `settings.json`.
- The player's `PointLight2D` uses `light.png` (128 px). Its `texture_scale = shown_radius / 64`, and `shown_radius` eases toward `chain.light_radius()`.
- The lurker's eyes and the slash/pogo sprites, Fx and ledge rims use `LIGHT_MODE_UNSHADED`, so they read at any brightness. The lurker's red `PointLight2D` glow tracks the eye alpha.
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
| Unit | `tests/test_clock.gd` | `Clock`: ids multiply, a re-request refreshes (latest scale wins, never stacks), real-time expiry, pause freezes requests, `_exit_tree` and player death clear them, a pogo hit requests the 75 ms hitstop |
| Unit | `tests/test_tuning.gd` | `Tuning`: `f()` / `flag()`, gear modifiers apply set → add → mul in every order, one `changed` per `apply_gear()`, reset in place, `rules/` purity; a regression fixture pins all 44 M1 `@export` defaults in their new homes, plus the player boxes, the chain curve, Blade Bloom and the hitstop depth |
| Unit | `tests/test_state.gd` | `Settings`, `SlotState` and `DiveState`: the signal rules, the fallbacks on bad data, the `to_dict()` shapes, round trips in memory and through JSON, `rules/` purity. `Game`: the same instances all session, `reset_for_tests()`. `settings.json` through `SaveStore`: a missing, corrupt or partly bad file is rewritten, a file that can't be opened or is from a newer build is left untouched, one write per frame, and the warnings are counted |
| Unit | `tests/test_room_loader.gd` | The room validator (each error at its file line and column, from fixtures in `tests/rooms/` and inline texts), the build (spawn counts, `hover` args, in-wall lurkers, rims) and the `Room` API; `m1_shaft` validates, holds 36 hoverers, 5 walkers and 4 lurkers, and has no ledge gap over 19 rows (FR57) |
| Integration (headless) | `tests/smoke_shaft.gd` | Loads `m1_shaft` standalone through `tests/room_harness.gd` (a test player and a stub `World` with `play_rect()`) and drives `Input.action_press`. Covers: pogo builds the chain; landing breaks it; jump height (held ≈ 60 px, tap < 60 %); wall cling/timeout/kick; a **bot** chaining ≥ 5 through the long run (proves spacing); lurker telegraph ≥ 0.75 s → hunt → lose track; base light never noticed; no off-screen notice; point-blank Snuff escape; idle lurker harmless; hunting lurker kills; Snuff needs a hold |
| Integration (headless) | `tests/smoke_shaft_state.gd` | Loads the real shaft and checks its state wiring: a bank raises `Game.dive.carried`, a chain raises `Game.slot.best_chain`, a death raises `Game.slot.deaths`, `Settings.brightness` repaints the darkness, a shaft added by a test never boots `Game`, and a new shaft keeps all of it and spawns at `P` |
| Visual (manual) | `tests/screenshot.gd` | Two PNGs (spawn; chain 10 with a telegraph). Needs a renderer: `xvfb-run` on the server |

Design rules are encoded as tests: the telegraph is never under 0.75 s, there is no off-screen ambush, and a Snuff in time always saves you. Change these rules in the GDD first, then in the test.

Last run: 2026-11-11, **ALL GREEN** (bot best chain 8).

## Deployment

No export presets or CI. Builds are played in the Godot editor on the laptop (F5). The dev server runs tests and the sprite pipeline headless.

## Conventions and Gotchas (for anyone changing the code)

- **Keep ChainState free of nodes.** It is the unit-tested core. New chain rules (Flare Toss halving, hit → "carried") belong there, with tests.
- **Session state lives in `Game`, never in statics.** Anything that must survive a death goes into `Game.slot`, `Game.dive` or `Game.settings`, through their methods. A test that changes them ends with `Game.reset_for_tests()`.
- **`reload_current_scene()` only when the shaft is the current scene.** Test harnesses add the shaft by hand, and `_on_player_died` checks this.
- **Hitstop goes through `Game.clock`.** Request it with `Game.clock.request(&"hitstop", 0.05, 0.075)`; never write `Engine.time_scale` yourself. Use timers with `ignore_time_scale = true` for anything that must run during it. `die()` calls `Game.clock.clear()`.
- **Determinism:** no randomness in level behaviour. Hover phase comes from position, and `reset_phase()` exists so tests do not depend on order. Only the camera shake uses `randf`.
- **Lurker lethality is `monitorable`.** It is false except in HUNT with the scent. Do not add other kill paths that skip this, or the rule "Snuff/landing in time always saves you" breaks.
- **Polling, not `body_entered`, for crawler contact**, so a crawler still overlapping when invulnerability ends still hurts.
- **Tuning names match the GDD tables; keys live in `rules/tuning.gd`.** When you change a value, update the GDD tuning table (M1 values are marked there).

## Gaps Against the M2 Design

Observations from comparing this code with GDD v1.0 and the UX spines (2026-11-11). They are inputs for the architecture notes, not decisions.

| Area | M1 as built | M2 target (source) | Likely impact |
|---|---|---|---|
| Play width | Shaft is 22 tiles (352 px) since Story 1.5, centred in the 480 px view with empty 64 px bands; no gutters yet | ~60 px HUD gutters, ~360 px view; spine shafts 22 tiles (352 px); wider rooms scroll horizontally (GDD Level Design, UX) | Camera limits/viewport split and the gutters (Story 1.6) |
| Scene structure | One scene (`shaft.tscn`) that loads one room file through `RoomLoader` (Story 1.5) | Hub + Layer 1 spine and branches, rooms, Weaver arena (GDD World Map) | `World` and room swaps (Stories 1.6–1.7) |
| Damage | Crawler = knockback only; hunting lurker = instant death | 4 HP; crawler 1, lurker 2, spikes 1; heal at stations (GDD Health) | Health component; lurker contact deals damage instead of calling `die()` |
| Embers | held → banked (`Game.dive.carried`) → held lost on death | held → **carried** → **deposited** at a Lift Station/hub (GDD Economy) | Rename and extend ChainState/economy; deposit flow |
| Respawn | The shaft's spawn `P` (`DiveState` has an unused respawn point) | Lantern anchors and Lift Stations; hazards respawn at the last safe ledge in the room | Anchors and stations call `DiveState.set_respawn()` (Story 1.24); a last-safe-ledge tracker for hazards (Story 1.19) |
| Light key | Hold V = Snuff; a tap does nothing | Tap = Flare Toss (needs ≥ 2 links, halves the chain); tap window 0.12/0.2/0.3 s setting; optional Snuff toggle key (GDD Controls) | Light input state machine; Flare entity that predators sense |
| Input | Keyboard only; F1 and F3 debug hotkeys | Gamepad from M2; Pause (Esc/P); rebinding in E7; F1 goes with the shaft in Story 1.7, then DevTools sets brightness until Options (Story 1.36) | Input map + settings; remove the debug hotkeys |
| HUD | Debug `Label` line | Gutter HUD, Fusion Pixel Font 8px (OFL files must ship), alert frame in the gutters (UX DESIGN) | Real HUD scene; font licence files in builds |
| Lurker warning | On-screen telegraph only | Off-screen "stir": panned audio + half-open eye at the edge (GDD Lurker) | Needs audio and an edge indicator |
| Persistence | `settings.json` only (brightness); session state in `Game`, not saved | 3 save slots, autosave at stations/hub/anchor quit, visible save failure (GDD Saves, UX) | Save system |
| Audio | None | SFX + chain-reactive music (E3) | Audio bus layout |
| Death feedback | "−N lost" popup | Death card lines stored from E1 for the E7 Journal (UX); Field Journal line (deferred-work) | Record the death cause |
| Builds | Editor only | Windows, Linux, web/itch.io 960×540; 60 FPS on HD 620 class (GDD Performance) | Export presets; a perf test |
