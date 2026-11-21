---
title: 'Game Architecture'
project: 'pixel_art_game'
date: '2026-11-11'
author: 'sonlm'
version: '1.0'
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8, 9]
status: 'complete'
engine: 'Godot 4.7.2 (GDScript, GL Compatibility)'
platform: 'PC (Windows, Linux), Web/itch.io'

# Source Documents
gdd: '_bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md'
epics: '_bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/epics.md'
brief: '_bmad-output/planning-artifacts/briefs/brief-pixel_art_game-2026-11-08/brief.md'
---

# Game Architecture

## Executive Summary

**The Unbroken Chain** architecture is designed for **Godot 4.7.2** (GDScript, GL Compatibility renderer) targeting **PC (Windows, Linux) and web/itch.io**, for the M2 vertical slice (Layer 1, hub, Weaver). It replaces the M1 single-scene prototype patterns with a small, testable structure a solo developer can grow epic by epic.

**Key Architectural Decisions:**

- **State as pure objects** across four lifetimes (per-life, per-dive, per-slot, global), held by a thin `Game` autoload; only `Game` and `Audio` are autoloads (ADR-1).
- **Big rooms from text files, cut only at chain-safe points;** crossing an exit with a live chain banks it; rooms load standalone for tests (ADR-2, ADR-3).
- **One Clock owns time;** `PlayerInput` turns actions into intents; 2D physics interpolation feel-checked in E1 (ADR-4).
- **Light-as-Signal:** every light is a `LightSource`; predators sense through pure `Sensing` maths inside the visible play rect, preserving the Pillar 2 guarantees.
- **JSON saves** with atomic writes, versioning, migrations and a fixture test; web storage checked with `OS.is_userfs_persistent()` (ADR-6).
- **Web-safe audio and lighting:** per-player volume mixing, no bus effects (ADR-5); ≤ 6 `PointLight2D` on screen, engine glow only after the E1 perf scene passes.
- **Server builds, laptop plays:** `tools/export.sh` validates content, exports three targets, ships licences, checks size and runs a Playwright web smoke check.

**Project Structure:** hybrid organization (type folders, then domains: `core/`, `rules/`, `world/`, `actors/`, `objects/`, `moments/`, `ui/`, `audio/`, `dev/`) covering 22 core systems.

**Implementation Patterns:** 5 novel patterns (Light-as-Signal, rule-bending `Tuning`, Safe-Cut Room Flow, Chain-Reactive Music, Design Guarantees as Tests), 4 standard patterns and 15 consistency rules, several enforced by an architecture lint test.

**Ready for:** epic and story creation (`gds-create-epics-and-stories`).

## Development Environment

### Prerequisites

| Tool | Where | Version |
|---|---|---|
| Godot editor + export templates | laptop and server | 4.7.2 stable (must match) |
| Python 3 + Pillow | server | Pillow 12 (sprite pipeline; SFX pipeline from E3) |
| Node.js + Playwright (Chromium headless) | server | Node 24; `@playwright/test` pinned to exactly 1.65.1 in `tools/web_smoke/package.json` (Story 1.13; headless shell revision 1255) |
| xvfb (`xvfb-run`) | server | for `tests/screenshot.gd` |
| Fusion Pixel Font 8px proportional (latin) | repo `game/fonts/` | GitHub release tag pinned at download (E1), with `OFL.txt` + `LICENSES/` |
| git | both | — |

### AI Tooling (MCP Servers)

| MCP Server | Purpose | Install Type |
|---|---|---|
| Context7 (adopted) | current Godot 4.7 documentation lookups | Claude Code plugin (installed); authenticate via `/mcp` |
| Godot MCP (deferred to E4) | scene/node editing if level authoring moves to scene files | Coding-Solo/godot-mcp or bradypp/godot-mcp, Node server, no addon |

Addon-based Godot MCPs are out (need a running editor and addon approval).

### Setup Commands

```bash
# server, from the repo root
godot --version                                   # expect 4.7.2.stable
python3 tools/build_sprites.py                    # sprites → game/art/
godot --headless --path game --import             # re-import after pipeline runs
(cd game && ./run_tests.sh)                       # expect: == ALL GREEN
(cd tools/web_smoke && npm ci && npx playwright install --only-shell --no-remove chromium)   # once (Story 1.13); --no-remove keeps other tools' browser revisions
tools/export.sh                                   # expect: == BUILD OK builds/<yyyymmdd>-<sha7>, … (docs/build.md)
```

### First Steps

1. E1 opens with the **M1 migration**: move scripts into the domain folders with `git mv`, retire `shaft.gd` into `rooms/l1/m1_shaft.txt` (22 columns), re-import, tests green.
2. Add the **foundations** in this order: `Log`, `Clock`, state objects (`Settings`, `SlotState`, `DiveState`, `Tuning`), `Game`; then `RoomLoader` + `World`; then `PlayerInput`; update `run_tests.sh` (glob discovery, fail on engine errors) and add `test_lint.gd`.
3. Configure MCP servers: authenticate Context7 via `/mcp`.
4. Build the **E1 worst-case perf scene** (`rooms/dev/perf_worst.txt`) early and check it on the laptop and in a web debug build.
5. Update `project-context.md` and the GDD notes listed under Validation → Follow-ups.

## Project Context

### Game Overview

**The Unbroken Chain** — a 2D descent Metroidvania where the pogo chain is your light. Chaining
hits without landing makes you stronger (Blade Bloom), brighter (Chain-Light) and richer (embers),
and draws predators that hunt by light. Seven hand-built layers below an island hub; M2 is the
Layer 1 vertical slice.

### Technical Scope

**Platform:** PC (Windows, Linux) and web/itch.io (960×540 embed, ×2); Steam Deck legibility at ×2
**Genre:** Metroidvania (descent) with precision action-platformer feel
**Project Level:** Medium — brownfield. M1 prototype (single scene, pure-logic `ChainState`,
headless tests) is proven; M2 adds world, persistence, UI, audio and a boss.
**Engine (fixed):** Godot 4.7.2, GDScript only, GL Compatibility renderer, 480×270 integer-scaled.
**Networking:** none (single-player, offline).

### Core Systems

| System | Complexity | GDD reference | Epic |
|---|---|---|---|
| Player kit v2 (move set, Light tap/hold, Flare Toss, Swing) | Medium | Primary Mechanics, Controls | E1, E6 |
| Chain + ember rules (held → carried → deposited, difficulty tiers) | Medium | Chain table, Economy | E1 |
| Health / damage / invulnerability / respawn points | Medium | Health and damage, Respawn | E1 |
| Light sensing (player, flare, Ember Cache as sensed lights; Weaver inverse) | High (novel) | Lurker, Flare Toss, Weaver, Economy | E1, E2 |
| Predators & enemies (lurker FSM, off-screen stirring, crawlers, spiderlings) | Medium | Predators, Enemies | E1, E2 |
| World structure: rooms, transitions, camera framing, multi-screen authoring | High | World Map, Level Design Framework | E1 (shaft resize), E4 |
| World state & persistence (four lifetimes: per-life, per-dive (enemy deaths until rest/leave layer), per-slot world state, global settings; 3 slots; autosave; visible failure; save schema versioning across builds) | High | Saves, Backtracking, UX save notes | E1, E4–E6 |
| Weaver boss (light-reactive FSM, strands/anchors, Re-Weave, The Fall across rooms, phase checkpoint) | High | Boss: the Weaver | E2, E6 |
| Scripted moments (The Fall, The Watching Departure, Weaver reveal, *The Last Entry*, defeat slow-mo) — one-off scripts vs. a small sequence runner **decided in step 4** | Medium | Weaver, Lift Station, Narrative | E4–E6 |
| Input layer (actions, gamepad, tap window, hold↔toggle modes, hitstop buffering, glyph swap, disconnect pause, rebinding later) | Medium-High | Controls, UX Input Schemes | E1, E7 |
| Time control (hitstop, boss slow-mo, pause, focus/disconnect pause, later game-speed assist) | Medium | Feel rules, Performance, UX State Patterns | E1, E6, E7 |
| UI: gutter HUD, zone tinting, menus, death card, Options, slot picker, string table | High (breadth) | UX DESIGN/EXPERIENCE | E1 → E7 |
| Accessibility gating (reduce flashing, shake, reduced motion via one switch) | Medium | Flash safety, UX Accessibility Floor | E1 |
| Audio: SFX pipeline, chain-reactive music stems, ducking, web audio gate | Medium | Audio and Music | E3 |
| Hub, NPCs, shops, map, journal | Medium | Hub, Exploration Rewards | E4, E5 |
| Gear / rule modifiers over base tuning | Low-Medium | Hub (Smith), Exploration Rewards | E5, E6 |
| Content pipelines (sprites, SFX, palettes per zone) | Low-Medium (exists) | Asset Requirements | all |
| Build & export (presets, single-threaded web, licence files, size budget) | Low-Medium | Platform-Specific Details | E1 (web embed), E7 |
| Test harness (rule unit tests, smoke tests, reachability bot per room) | Medium | Level validation, Technical Metrics | all |

Dev-only debug entry points and hotkeys are a pattern rule (see Implementation Patterns), not a system.

### Technical Requirements

- **Performance:** 60 FPS sustained (no frame > 20 ms outside the intentional 75 ms hitstop) on an
  Intel HD 620-class iGPU and in desktop Chrome/Firefox web builds; measured over a 10-minute Layer 1 run
  including the Weaver.
- **Input:** no input lost during hitstop (`Engine.time_scale` 0.05 for 75 ms).
- **Load:** < 2 s hub → Lift Station (laptop). Web: < 30 MB download, playable < 10 s at 50 Mbps.
- **Memory:** ≤ 512 MB desktop, ≤ 300 MB web tab.
- **Display:** 480×270 native, integer scale only (×2/×3/×4), letterboxed; scale chosen from physical
  pixels (devicePixelRatio) on web; ~60 px HUD gutters each side → ~360 px play view. As built
  (Story 1.14): `Game.display` (`core/display.gd`) holds the rule; the engine's HiDPI canvas gives
  physical pixels and its integer stretch draws the whole scale; below ×1 `Display` switches to a
  fractional nearest fit (letterboxed) instead of the engine's crop; the PC window is ×3 or the
  largest whole scale that fits the screen, minimum 480×270.
- **Visible play rect:** one shared definition of the visible play area (inside the gutters). Lurker
  notice ("on screen"), off-screen stirring distance, edge cues, glyph-prompt clamps and the guarantee
  tests all use it — never the raw viewport. (M1's viewport check would let a lurker wake unseen behind a gutter: a Pillar 2 break.)
  (The light budget, a cost rule, counts the whole view instead: `World.light_rect()`, Story 1.12 D2; see Lighting.)
- **Standalone rooms:** every room loads and runs headless on its own (no world, save or hub needed), so
  the reachability bot and smoke tests can exercise each room in isolation.
- **Web:** single-threaded export, click-to-play gate before audio, auto-pause on focus loss,
  no F-keys, Esc/P pause.
- **Saves:** 3 slots in `user://`; autosave at station rest, hub arrival, quit at a lit anchor;
  failure surfaced to UI with retry at next rest; slot delete.
- **Save compatibility:** saves carry a schema version; a newer build migrates or clearly rejects
  older saves — testers keep progress across builds through M2. A checked-in old-save fixture is loaded by every later build's tests.
- **Data scopes:** settings are per-machine; progress, records and journal are per-slot.
- **Determinism:** no randomness in level behaviour (camera shake only).
- **Licensing:** Fusion Pixel Font OFL files ship in every build.

### Complexity Drivers

**High complexity**
1. **State ownership & lifetimes.** Per-life, per-dive, per-slot and global state need clear owners
   so saves, death, rest and tests agree. Every system writes into one of these; getting it wrong
   means E4 rewrites E1.
2. **From one scene to a world.** Rooms/transitions, persistent world flags, enemy respawn on rest,
   respawn at anchors vs. hazard respawn at the last safe ledge — M1's "reload scene + statics"
   cannot carry this.
3. **Weaver boss.** A light-reactive FSM, a strand/anchor sub-system, and a phase transition that
   crosses into another room (The Fall → landing arena) with its own checkpoint.
4. **UI breadth.** ~15 surfaces across 7 epics, zone-tinted, gamepad/keyboard, string table,
   accessibility switches.
5. **Time authority.** Hitstop, boss slow-mo, pause and (E7) game-speed assist all touch time;
   one owner must arbitrate, and UI must keep running while gameplay is frozen.

**Novel concepts (no stock pattern)**
1. **Light as a sensed signal.** Multiple emitters (player, flare, Ember Cache) with predators
   choosing a target; the Weaver flees light instead of seeking it.
2. **Chain-reactive music.** Stems fade in at 3/6/10 links, resolve on bank, cut on death — music
   state driven by `ChainState`, robust to hitstop.
3. **Gear that bends rules.** Always-on modifiers (Quick Wick, Long Wick, Steady Grip, Silk Grip) that
   change existing tuning numbers or input responses, not stats.
4. **Design guarantees as tests.** Telegraph ≥ 0.75 s, no off-screen ambush, escape-in-time always
   saves, reachability bot ≥ 5 per spine shaft and at every gate — must scale to every room.

### Technical Risks

| Risk | Why it matters |
|---|---|
| Lighting cost on HD 620 / web (Compatibility renderer) | `PointLight2D` count grows with flares, caches, lurker glows, Weaver; bloom wanted but unproven on Compatibility (GDD Open Question → architecture) |
| Hitstop side effects | `Engine.time_scale` affects timers, tweens, audio, UI animation; every new system must choose real vs game time |
| Web storage | `user://` maps to IndexedDB; can be blocked/full → must fail visibly, not silently |
| Level authoring at scale | ~26 screens of content; M1's ASCII `LAYOUT` const may not scale, and addons need approval |
| Test isolation | Static state leaks between tests in one process; more global state = more leaks |
| Viewport vs play rect | Gutters hide part of the viewport; any "on screen" check against the viewport breaks the no-ambush guarantee while tests still pass |
| Save format churn over a long M2 | Testers lose progress every build without versioning/migration |
| Late performance discovery | Perf checked only in E7; worst case is Old Mine (dense lurker glows) + flare + cache on web |
| UI and autoload sprawl | Ad-hoc menus per epic; singletons growing without ownership rules |
| Solo capacity (5–10 h/week) | Architecture must stay small and incremental per epic; over-engineering is a real risk |

### Assumptions (to verify)

- Compatibility-renderer glow/bloom is adequate on web; fallback is sprite-based glow (verify in decisions).
- A light budget of ~6 `PointLight2D` on screen holds 60 FPS on HD 620 / web — verified by an **E1 worst-case perf scene** (Old Mine density + flare + cache + player, placeholder art).
- NPC dialogue is linear lines gated by flags — no branching trees. The narrative pass works inside this box.
- Physics is deterministic at 60 ticks with no randomness in level behaviour (the reachability bot depends on it).
- Level authoring stays in-house unless an addon is approved (decided in step 4).

## Engine & Framework

### Selected Engine

**Godot 4.7.2 stable** (GDScript only, GL Compatibility renderer)

**Rationale:** proven in M1; the only Godot renderer that targets web (the primary playtest
platform); free/open-source fits a solo, no-deadline project; strong 2D tooling; headless mode runs
the test suite and exports on the dev server. Export templates must match 4.7.2.

**Version policy:** freeze on **4.7.x for all of M2**. 4.7.x maintenance releases may be taken after the
upgrade checklist passes. A minor upgrade (4.8+) is only *considered* at an epic boundary, never mid-epic.

**Engine upgrade checklist (4.7.x):** update editor + export templates on laptop and server together →
re-import → `run_tests.sh` green → web smoke check → commit changed `.import` files. As built (Story 1.13),
the full procedure is `docs/build.md` → Engine upgrade checklist: templates from the release's `.tpz`,
checked against its SHA-512; the web smoke check is `tools/export.sh` green; then a manual web look on the laptop.
Guarantee tests run on desktop headless; the web build is covered by the web smoke check.

**Web smoke check** (two layers):
- **Automated (server):** export the web build headless, boot it in headless Chromium (Playwright),
  pass the click-to-play gate, confirm the game starts, write a save, reload the page, confirm the save
  persists; check the chosen scale for a simulated DPR. Correctness only: headless Chromium renders
  WebGL in software, so it says nothing about performance or feel.
- **Manual (laptop browser, every epic end and every engine upgrade):** boot/gate, audio, save survives
  reload, DPR scale (×2 embed and fullscreen), gamepad connect/disconnect, 60 FPS feel.
- **As built (Story 1.13):** `tools/web_smoke/` boots the `Web debug` and `Web` builds in headless Chromium
  (Playwright 1.65.1, served by `serve.js` on 127.0.0.1): the engine banner, the shell's `#status` gone, no page
  error and no `console.error`; the debug build must print `SMOKE boot ok` (also with `?room=perf_worst`), the
  release build is boot-only. The DPR scale and the web keys (1.14: `Display scale`, `Web input` in `embed.html`) have joined it; the gate (1.33) and the save/reload (1.39) join it later.

### Project Initialization

None — brownfield. Project root is `game/`; no starter template; no addons (adding one needs approval).

### Engine-Provided Architecture

| Component | Solution | Notes |
|---|---|---|
| Rendering | CanvasItem 2D on GL Compatibility (OpenGL 3.3 / WebGL 2); renders at native 480×270, then upscales | Post passes (glow) are cheap at native res; the cost driver is lights × lit canvas items. Glow listed as supported in Compatibility — web parity verified in the E1 perf scene |
| Pixel display | Viewport stretch, integer scale, nearest filter, `snap_2d_transforms_to_pixel`; web canvas via `html/canvas_resize_policy` | As built (1.14): the engine's HiDPI canvas (`allow_hidpi`, `canvas_resize_policy=2`) gives physical pixels, with no JavaScriptBridge; the sub-×1 fit, the PC window and the web key guard (`html/head_include`) are ours, verified by the web smoke |
| Physics | Godot 2D physics, 60 ticks/s | `CharacterBody2D`, `Area2D`; deterministic enough for the bot (no randomness in level behaviour) |
| Input | `InputMap` actions, physical keycodes, joypad API, runtime remapping | Browser pads appear only after a press; hold/tap logic, buffering, glyph swap are ours |
| Scene management | `SceneTree`, `PackedScene`, autoloads, groups | Room/world model is ours |
| Time | `Engine.time_scale`, `SceneTree.paused` + `process_mode`, timers with `ignore_time_scale` | Arbitration between hitstop / slow-mo / pause is ours |
| Audio | `AudioServer` buses, `AudioStreamPlayer(2D)`; web = Web Audio, Sample playback by default | On web, bus effects don't apply in Sample mode (docs) and non-Master buses are reported unreliable → ducking and stem fades are per-player volume tweens; pitch per link verified on web |
| UI | `Control` nodes, `Theme`, `FontFile` (Fusion Pixel 8px), `TranslationServer` (CSV string table) | Gutter layout and UI kit are ours |
| Persistence I/O | `FileAccess` / `ConfigFile` / JSON in `user://` (IndexedDB on web) | `OS.is_userfs_persistent()` gates web saves; schema, slots, versioning, failure reporting are ours |
| Build | Export presets + 4.7.2 templates; headless `--export-release` | Windows, Linux, Web (single-threaded); licence files packaged. Plan B for the 30 MB budget: custom web template with 3D disabled |
| Tests | Headless `SceneTree` scripts | No framework (decided in M1) |

### Development Tooling

- **Context7** (adopted): current Godot 4.7 documentation lookups for agents. Authenticate via `/mcp`.
- **Godot MCP** (deferred to E4): Coding-Solo/godot-mcp or bradypp/godot-mcp (Node, no addon), only if
  level authoring moves to scene files. Addon-based MCPs are out (need a running editor + addon approval).
- **Playwright** (server): drives the automated web smoke check.

### Remaining Architectural Decisions

Taken in dependency order in step 4:

| Tier | Decisions |
|---|---|
| 1 | State lifetimes and ownership; which autoloads exist and what each owns |
| 2 | World/room model (format, transitions, camera framing, standalone loading); level authoring format |
| 3 | Save system (format, slots, schema version + migration, failure reporting, web storage) |
| 4 | Time authority and UI process modes; input architecture (Light tap/hold + toggles, buffering, glyphs); frame pacing (physics interpolation vs pixel snapping) |
| 5 | Light-emitter model, predator sensing, visible play rect; gameplay rules layer (embers, HP, gear modifiers); event/communication pattern |
| 6 | UI architecture (HUD, UI kit, menus, string table, accessibility switch); audio architecture; lighting budget and glow; scripted moments |
| 7 | Build/export pipeline (lean: the server builds, the laptop plays) |

## Architectural Decisions

### Decision Summary

| # | Category | Decision | Version | Rationale |
|---|---|---|---|---|
| 1 | State management | Pure state objects (node-free `RefCounted`) per lifetime; one thin `Game` autoload holds refs | Godot 4.7.2 | Extends the proven `ChainState` pattern; testable without scenes; saves fall out of `to_dict` |
| 2 | Scene structure | Persistent `World` scene; big rooms (one per spine segment / side area / arena); transitions only at chain-safe points | — | A cut mid-chain breaks the core loop; ~10–14 rooms is small enough for a solo dev |
| 3 | Level authoring | Text room files (ASCII grid + header), built at load in code | — | Diffable, agent-authorable on the headless server; same text→asset spirit as sprites |
| 4 | Data persistence | JSON slot files, atomic write + `.bak`, schema `version` + migration chain; settings in JSON (R15) | — | Readable fixtures, no code execution on load, versioned across builds |
| 5 | Anchor quit | Save anchor id + carried embers + Ember Cache; killed enemies reset | — | Smallest snapshot that keeps the GDD rule "carried stays at risk until a station" |
| 6 | Time | One `Clock` (in `Game`) is the only writer of `Engine.time_scale`; scale = product of active requests; pause = `SceneTree.paused` | — | Hitstop × slow-mo × assist compose instead of fighting |
| 7 | Input | `PlayerInput` node turns actions into per-tick intents (Light tap/hold, toggles, real-time buffers) | — | Keeps the player script lean; tests can inject exact timings |
| 8 | Frame pacing | 2D physics interpolation **on**, with pixel snapping; **kept at the CP1 gate (1.15, 2026-11-21)**: no visible difference at 60 Hz, no high-refresh display to test on, and on is already built and tested | Godot 4.7.2 | Smooth on 120/144 Hz displays without changing 60-tick tuning |
| 9 | Light sensing | `LightSource` node on player / flare / cache; pure sensing helper; all checks use the shared play rect | — | One model for lurkers (seek) and the Weaver (flee); fixes the gutter blind spot |
| 10 | Rules layer | Pure rules classes (chain, health, embers) + `Tuning` object (base values + gear modifiers) | — | Gear bends numbers in one place; rules stay unit-tested |
| 11 | Communication | Typed signals on state objects; groups + duck typing between actors; **no global event bus** | — | Every connection traceable to its owner |
| 12 | UI | Persistent UI `CanvasLayer` in `World`: gutter HUD + one `ScreenRouter` (replace, never stack); E1 UI kit; CSV string table; one accessibility gate | — | Matches UX rules; menus stay consistent across 7 epics |
| 13 | Audio | `Audio` autoload; all mixing by per-player volume tweens on Master; no bus effects | Godot 4.7.2 (web Sample playback) | Behaves the same on web and desktop |
| 14 | Lighting | ≤ 6 `PointLight2D` on screen (confirmed at the CP1 gate, 2026-11-21); small glows are unshaded sprites; **engine glow: no-go (CP1, 2026-11-21)**, bloom = unshaded additive sprites | — | Lights × lit items is the cost driver at 480×270 |
| 15 | Scripted moments | One-off scripts on shared primitives (Clock, input lock, camera hooks, audio cues); no sequence runner in M2 | — | Cheap now; consistent behaviour; revisit at Layer 2 |
| 16 | Asset loading | Per-room load on transition (behind the cut); small assets preloaded; no threaded loading | — | Content is tiny; web export is single-threaded |
| 17 | Build pipeline | Server builds all targets headless via `tools/export.sh`; laptop plays | Godot 4.7.2 templates; `@playwright/test` 1.65.1, exact pin (Story 1.13); Node 24 on server | One reproducible build machine; runs the web smoke check |
| 18 | UI font | Fusion Pixel Font 8px proportional (latin), OFL 1.1 | Pin the GitHub release tag at download (E1) | UX decision O1; licence files ship in every build |

### State Management

**Approach:** pure state objects per lifetime, owned by a thin `Game` autoload.

| Lifetime | Owner | Holds | Reset by |
|---|---|---|---|
| Per-life | `Player` instance → `ChainState`, `Health`, `PlayerInput` | links, held embers, HP, invulnerability, input buffers | death (player re-instanced) |
| Per-dive | `Game.dive : DiveState` | carried embers, killed enemies per room, current respawn point | rest at a Lift Station, arriving home, leaving the layer |
| Per-slot | `Game.slot : SlotState` | world flags (gates, stations, anchors, hoards, secrets), Ember Cache (room, position, amount; survives rests and saves until recovered or the next death), deposited embers, abilities, gear owned, map visits, journal, records, death log (cause id + room id per death), difficulty, play time, resume point | New Game / Load |
| Global | `Game.settings : Settings` | accessibility, tap window, toggles, volumes, video, bindings (E7), last-used slot | never (per machine) |

- All four classes are `RefCounted`, node-free, with typed signals and `to_dict()` / `from_dict()`. Rules on them are unit-tested in `tests/test_<subject>.gd`, like `ChainState` (`tests/test_chain_state.gd`).
- `Game` (autoload) holds `settings`, `slot`, `dive`, `tuning` (rebuilt when the slot's gear changes), the `Clock`, the `SaveStore` (`store`, Story 1.4) and device tracking. It contains **no gameplay rules**.
- **Allowed autoloads:** `Game`, `Audio` (from E3). Adding another autoload is an architecture change.
- **Death no longer reloads the scene.** `World` applies the death cost (difficulty tier rules on `DiveState`), rebuilds the respawn room and spawns a fresh `Player`. The M1 `static var`s on `shaft.gd` are retired when E1 touches them.
- **Entity identity:** persistent world objects (gates, anchors, stations, hoards, secrets, journal objects) carry **explicit ids declared in the room header**; saves reference only these ids, so editing a room's layout never orphans a flag. Enemies use `room_id + grid cell` (per-dive only, never in long-term saves).
- **Tests:** each test builds fresh state objects (`SlotState.new()`); `Game` exposes `reset_for_tests()` for smoke tests.

### Scene Structure and Rooms

**Approach:** a persistent `World` scene swaps one room at a time; rooms are big and transitions sit only at chain-safe points.

```
World (Node2D, world.gd)            # group "world"
├── RoomHolder                       # current Room instance
├── Player                           # re-instanced on death
├── Camera2D                         # limits from the room; play area centred between gutters
└── UI (CanvasLayer, PROCESS_MODE_ALWAYS)
    ├── Gutters (HUD)
    └── ScreenRouter
```

- **Room size:** each spine segment (S1–S5), side area (A, B, C), the Weaver arena and the landing arena is one room (~10–14 in Layer 1). Spine rooms are 22 tiles (352 px) wide and never scroll sideways; the arena (30 tiles) and the hub scroll horizontally.
- **Transitions:** only at doors, landings and stations, where the chain is already broken. **Level rule (bot-checked):** no room exit lies inside a chain run. The Fall is a scripted exception (see Scripted Moments).
- **Play rect:** `World.play_rect()` returns the visible play area inside the gutters, in world coordinates. Lurker notice ("on screen"), stirring distance, edge cues, glyph-prompt clamps and guarantee tests all use it, never the viewport.
- **Standalone rooms:** a room builds from its file alone. Test harnesses instance a `Room` plus a test player without `World`, a save or the hub.
- **Hazard respawn** (spikes): last safe ledge in the current room, tracked by `World` (per-life, not saved).
- **Transient entities** (flares, FX, spiderlings, popups) are children of the current room and are freed with it. The Ember Cache is stored in `SlotState` and spawned when its room is built.
- **Exit backstop:** crossing a room exit with an active chain **banks it, exactly like a landing**, before the cut. Level design still places exits behind a landing so this rarely fires; it guarantees ADR-2 at runtime. (New rule: note it in the GDD chain table.)

### Level Authoring

**Approach:** one text file per room in `game/rooms/`, built at load by `Room` (TileSet built in code, ledge rims, as in M1).

```
# game/rooms/s2_scaffold.txt
id=s2_scaffold
zone=umber
exits=up:s1_lip@x12, down:s3_gate@x9
---
######################
#....h......h........#
#..c......L..........#
#####..........#######
#A.......h..h........#
```

- Header: `key=value` lines, then `---`, then the grid (equal-width rows, 1 char = 16 px).
- **Spine width:** a spine room is **22 columns including its side walls** (352 px), so both walls stay visible inside the ~360 px play area (cling needs them). [GDD note: "22 tiles of open space" should read "22 tiles wall to wall".]
- The legend (chars → tiles/entities) lives in one place in code and is documented in `docs/`; new chars are added there first.
- Persistent objects are declared in the header with an id and a cell, e.g. `obj=hoard_a1@14,32`, `obj=anchor_s2a@3,58`; the grid char marks the kind.
- The room builder rejects unequal rows or unknown chars with `file:row:col` (same as the sprite pipeline).
- Set pieces (Weaver arena strands, *The Last Entry* camp) may add an optional `<id>.tscn` overlay instanced on top of the built room.
- **Export gotcha:** `.txt` and `.json` are not resources; export presets must include `rooms/*.txt` (and test fixtures stay out of builds).
- The reachability bot runs per room and per gate on these files.

### Data Persistence

**Save system:** local files in `user://`, JSON per slot, atomic writes, versioned.

```
user://
├── settings.json         Settings (JSON, parsed with JSON.new().parse())
├── slot_1.json           {"version": N, "meta": {...}, "slot": {...}, "dive": {...}|null}
├── slot_1.json.bak       previous good save
└── slot_2.json, slot_3.json
```

- **Write:** `slot_N.json.tmp` → re-read and parse to verify → rename over `slot_N.json`, keeping the previous file as `.bak`. Load falls back to `.bak` if the main file fails to parse.
- **Version:** an integer `version`. Older saves go through `migrate_vN_to_vN1()` functions in order; a newer-than-known save is rejected and left untouched. A checked-in old-save fixture (`tests/fixtures/slot_v1.json`) is loaded by every later build's tests.
- **Meta** (for the slot picker without a full load): depth, best chain, play time, difficulty, last saved.
- **Triggers** (readiness R14, 2026-11-12): **resume saves** at a Lift Station rest, arriving home and quitting at a lit anchor. Anchor quit also writes `dive` (anchor id, carried embers); the Ember Cache is already in `slot`; killed enemies are not saved. **Progress saves** (`Game.save_progress()`) at progress moments (difficulty change, purchase, story flag, phase checkpoint, boss defeat) rewrite the slot's world progress but keep the last resume point and `dive` snapshot unchanged, so they never move where you wake or make carried embers safe.
- **Failure:** the save call returns an `Error`; `Game` emits `save_failed` / `save_succeeded`; the UI shows the crossed icon and "Not saved", and the next rest retries. On web, `OS.is_userfs_persistent()` is checked at boot and before each save; if false, the failure state shows immediately.
- **New Game** writes the slot immediately after the difficulty step (an overwrite takes effect at once).
- **Retry:** a failed save retries at the next autosave trigger and on quit to title.
- **Web limit:** verify-after-write proves integrity, not persistence (it reads the in-memory filesystem). Persistence is covered by `OS.is_userfs_persistent()` and the automated reload smoke test.
- `settings.json` carries its own `version`; a corrupt or missing file falls back to defaults and is rewritten; a file that can't be opened, or that a newer build wrote, also falls back to defaults but is left untouched, and settings writes stay off for that session (Story 1.4 review, the same rule as a newer or damaged slot) (readiness R15: JSON instead of `ConfigFile`, because `ConfigFile.load()`/`parse()` and `JSON.parse_string()` print an engine `ERROR:` on bad input, which fails the test runner; all JSON is parsed with the silent `JSON.new().parse()`). `Game.boot()`, called once by the entry scene (`shaft.gd` until 1.6, then `world.gd`), loads it and arms its writes; a test never boots against the real folder, and points `Game.store.dir` at a temp folder before it tests the file. A DevTools `--set` session (Story 1.11) overrides values in memory through `Game.override_setting()` and writes no settings.json at all: not the override, not a load's rewrite, not a later change of another key. The overrides survive `boot()`'s load, and `reset_for_tests()` clears them (`user://` is shared by editor runs and exports, so a dev value must never reach the file the release builds read).
- **Slot delete** removes `slot_N.json` and `.bak`.
- Each death appends `{cause, room}` (a cause id, not text) to `SlotState.death_log` from E1, for the E7 Journal; the death card renders `DEATH_<CAUSE>_LINE` / `_TIP` from the cause id.

### Time Control

- `Game.clock` is the **only** code that writes `Engine.time_scale`. Callers request named effects: `clock.request(&"hitstop", 0.05, 0.075)`, `clock.request(&"slowmo", 0.3, 0.5)`, `clock.set_assist(0.8)` (E7). Durations are real time and pausable: `create_timer(t, false, false, true)` (`process_always = false`, `ignore_time_scale = true`). `Clock` is a `Node` child of `Game`, so it can own timers.
- `Engine.time_scale` = product of active requests × assist. Death and `_exit_tree` clear all requests.
- Clock requests count down **only while the tree is not paused**: pause freezes slow-mo and hitstop where they are. (Supersedes M1's `process_always` hitstop timer.)
- Pause is `SceneTree.paused`, never the time scale. UI, HUD and the death card run with `PROCESS_MODE_ALWAYS`; the Clock's timers pause (above).
- Real-time visuals keep using `delta / Engine.time_scale` in `_process` (M1 rule). Story 1.16 found its limit, probed on 4.7.2: a frame's delta is scaled before a Clock request made in that frame, so the formula reads about 0.33 s on the frame a hitstop starts. A visual that starts on a hit tick must not use it; on the physics tick, real time is one tick (1 / 60 s), as `CameraRig` counts it.

### Input

- `PlayerInput` (child of `Player`) samples `InputMap` actions once per physics tick and produces intents: `move`, `jump_pressed`/`jump_held`, `attack_pressed`, `dash_pressed`/`dash_held`, `light_tap`, `snuff_active`, `cling_held`, `interact`.
- It owns the **Light tap/hold machine** (tap window from `Settings`: 0.12 / 0.2 / 0.3 s) and the **Cling/Snuff toggle modes**. Quick Wick changes the Snuff response through `Tuning`, not the tap window.
- **Buffers use real time**, so presses during hitstop are kept (GDD: no input lost).
- `PlayerInput.lock()` / `unlock()` for scripted moments; menus never read gameplay intents.
- `Game` tracks the last-used device (glyph swap) and the gamepad that was active this session (disconnect pause only for a pad that was in use).
- Actions use physical keycodes, one button per action, no chords. Rebinding (E7) edits `InputMap` and is stored in `Settings`.

### Frame Pacing

- `physics/common/physics_interpolation = true`, physics at 60 ticks/s, `snap_2d_transforms_to_pixel` kept.
- **Kept (CP1 gate, Story 1.15, 2026-11-21, sonlm):** on the laptop at 60 Hz, on and off (`override.cfg`) showed no visible difference, and no high-refresh display was available; on is already built and tested, so it stays. The high-refresh check is deferred to Story 7.14 (Steam Deck OLED, 90 Hz).
- Teleports (respawn, room entry) call `reset_physics_interpolation()`.

### Light Sensing

- `LightSource` node (group `light_source`) on the player, a thrown flare and the Ember Cache. It exposes `radius()`, `kind` (`player`, `flare`, `cache`) and `global_position`.
- `Sensing` is a node-free helper with the pure maths: notice (radius ≥ 80 px, distance ≤ radius × 1.6, inside the play rect), sense, and target choice. It is unit-tested.
- Lurkers query `light_source` each physics tick and hunt the chosen target; the lethal-only-while-`monitorable` rule is unchanged. A flare is sensed like the player; the cache's glow radius is a tuning value (E1 playtest).
- The Weaver uses the same query and flees the brightest burning flare whose radius × 1.5 reaches it, with no 80 px notice minimum (readiness R20); a flare cancels a bite in telegraph (R19). It ignores Ember Caches; its bright/dark bands read the player's radius directly.

### Gameplay Rules and Tuning

- Pure rules classes: `ChainState` (+ Flare halving, any hit → carried), `Health` (4 HP, damage table, 0.6 s invulnerability, bank-heal), ember-stage rules on `DiveState`/`SlotState` (bank, deposit, death cost per difficulty). **At most one Ember Cache:** a new death replaces it (no cache if carried is 0).
- **`Tuning`**: base values (with their `##` unit/intent comments and GDD history) plus active modifiers from gear → effective values. Actors read `tuning.get(&"cling_slide")`; they never check `has_gear`. Gear entries are data: `{id, stat, op, value}` (e.g. Long Wick: `flare_burn`, `set`, 6.0).
- Changing a base value still means updating the matching GDD table.

### Communication

- State objects emit typed signals (`chain.changed`, `health.damaged`, `dive.carried_changed`, `slot.flag_set`, `game.save_failed`); HUD and audio subscribe through `Game`.
- Actors keep the M1 contract: groups (`player`, `enemy`, `predator`, `light_source`, `world`) and duck typing (`take_hit()`); no node paths.
- No global event bus.

### UI

- `World/UI` is a `CanvasLayer` with `PROCESS_MODE_ALWAYS`: **Gutters** (HUD, bound to state signals) and **ScreenRouter**, which shows exactly one screen at a time (Pause, Options, Death card, Station menu, Slot picker, Title…). Opening a screen replaces the current one.
- **UI kit (E1):** MenuList, TabBar, EmberCursor, ConfirmStep, Toggle, Slider, GlyphPrompt; one Theme built in code (no `.tres`, consistent with M1).
- **Strings:** every player-facing string goes through `tr()` from `game/text/strings.csv` (English only in M2). Commit the generated `.translation` and `.import` files with it. As built (Story 1.17): `tests/test_strings.gd` checks the table, that the committed `.translation` is current, and every key reference in `scripts/` and `scenes/` (literal keys in `tr()` / `TranslationServer.translate()` and listed-key literals held as data; no composed key, no dead key), and `tools/export.sh` runs it before any export. The font and sizes live in `core/text_style.gd` (`TextStyle`, so `Fx`'s popups can use them; `play_text()` is the play-area outline), and `ui/theme_builder.gd` builds the Theme from it.
- **Accessibility gate:** `Settings` exposes `reduce_flashing`, `shake`, `reduced_motion`; `Fx`, camera shake, invulnerability blink and UI easing read only these flags. No per-effect toggles. `Fx` is the gate (Story 1.16): only it names the keys (`Fx.reduce_flashing()` / `shake_on()` / `reduced_motion()`, lint `a11y_gate`), and `Fx.EFFECTS` declares every effect's flash rate and reduced variant.
- **Brightness** (readiness U2, 2026-11-12): `Settings.brightness` (4 levels; Options > Accessibility from E1, Video from E7; replaces M1's F1 `ambient_index`) scales only the world's ambient level (the darkness the lights cut through). It never changes light radii, `Sensing`, the reserved colours or anything on the UI `CanvasLayer`, so the gameplay rules and the contrast floors hold at every level.

### Audio (E3)

- `Audio` autoload: a small pool of SFX players, positional players for lurker cues, and the music stems (pulse, melody, full) started together and kept in sync.
- **All mixing is per-player volume:** stem layers fade in at 3/6/10 links, the bank resolve, the death cut, the 6 dB predator ducking, and the volume sliders (category volume × master). Everything plays on Master; no bus effects.
- Pogo pitch (+1 semitone per link, max +12) is set per play; verified in the web smoke check.
- No audio before the click-to-play gate on web.

### Lighting

- Budget: **≤ 6 `PointLight2D` on screen** (player, flare, lurker glows), all sharing `light.png` via `texture_scale`.
- **Priority over budget:** the player and flares always keep a `PointLight2D`; lurker wall glow falls back to a sprite glow first. Flare cap: none needed (CP1 gate, 2026-11-21, sonlm); Story 1.23 makes it a `Tuning` value and re-checks it with real flares.
- Small glows (lurker eye cores, cache core, embers, ledge rims) are unshaded sprites.
- **Engine glow: no-go (CP1, 2026-11-21); bloom = unshaded additive sprites.** `--glow` stays a DevTools-only option. The budget of 6 is confirmed: `perf_worst` held on the laptop desktop and in Firefox on the laptop's Intel iGPU (`docs/perf.md` → Results).
- **`BudgetLight`** (`scripts/core/budget_light.gd`, Story 1.12): every `PointLight2D` is one (lint `raw_light`; the scenes are audited by `test_light_budget`), with a `rank`: ALWAYS (the player, flares), CACHE (the Ember Cache), GLOW (lurker glows and anything else; the default, so a light that forgets its rank is demoted first). World's `LightBudget` child applies the budget once per physics tick at priority 50, after every actor has moved and set its light and before DevTools (100), so a glow that wakes on a tick is never drawn past the budget. The rule: a light *wants* light when it is shown, has energy and a texture; on-screen lights that want light keep their `PointLight2D` up to `MAX_ON_SCREEN` (6, ≤ `Spec.LIGHTS_ON_SCREEN_MAX`): ALWAYS first, never demoted even past the budget (that excess is reported as `over`), then CACHE, then GLOW; within a rank an already-lit light keeps its slot (sticky, so nothing flickers: ≤ 3 flashes/s), then the light nearest the centre. Off-screen lights are left as they are (the engine culls them, and a light at the edge can't toggle as it crosses). A demoted light's `PointLight2D` is disabled and its additive, unshaded `Fallback` sprite (`Fx.additive()`, same texture, colour and size, alpha following energy) shows instead. Only the budget writes `enabled`.
- **The budget's "on screen" is the whole view** (`World.light_rect()` = `CameraRig.view_rect()`, 480 × 270, gutters included; decided by sonlm, 2026-11-19): the budget is a cost rule, and the engine draws and culls lights against the whole viewport, so a light under an opaque gutter still costs a lit pass. AR20's "on screen" (notice, stir, edge cues, the guarantees) stays `play_rect()`. The two differ only in rooms wider than 360 px (`perf_worst`, the Weaver arena, the hub).

### Scripted Moments

- Each moment (The Fall, The Watching Departure, the Weaver reveal, *The Last Entry*, defeat slow-mo) is its own script.
- All of them use the same primitives: `Game.clock` requests, `PlayerInput.lock()`, camera hooks on `World`, `Audio` cues. A moment never writes `Engine.time_scale` or reads `Input` itself.
- **The Fall** crosses rooms: the arena script requests slow-mo, keeps the chain alive and hands off to the landing-arena room through a scripted transition (the one allowed mid-chain cut).
- A sequence runner is reconsidered when the Layer 2 boss is designed.

### Asset Management

- Rooms load when entered, behind the transition. Sprites, the shared light texture and fonts are preloaded; total content is small.
- No `ResourceLoader` threaded loading (single-threaded web).
- Sprites still come only from `tools/build_sprites.py`; audio from the E3 SFX pipeline and composed stems.

### Build and Export

- Export presets (Windows, Linux, Web single-threaded) are committed. Export templates are pinned to 4.7.2 on the server.
- `tools/export.sh`: headless `--export-release` for all three targets → copy `OFL.txt` + `LICENSES/` into each build → check the web download < 30 MB → run the Playwright web smoke check → `builds/<version>/`.
- The laptop downloads or pulls builds to play. Manual web smoke check at each epic end.
- **As built (Story 1.13; `docs/build.md`):**
  - `game/export_presets.cfg` has four presets, called by name: `Windows`, `Linux`, `Web` (release) and `Web debug`. All use `all_resources` plus the include filter `rooms/*.txt` (in Godot's matcher `*` crosses `/`, so that is every room file at any depth). The release three exclude `rooms/dev/*, tests/*, scripts/dev/*`; `Web debug` excludes `tests/*` only, keeping `perf_worst` and DevTools. Web is single-threaded (`web_nothreads_*` templates); desktop PCKs sit beside the binary. `tests/test_export_presets.gd` pins all of it.
  - `tools/export.sh` (no flags): preflight (Godot 4.7.2, the four templates, Node ≥ 24, Playwright 1.65.1 and its headless shell) → version → import → content (`smoke_rooms`, then `test_strings` from 1.17) → the four exports → licences (from 1.17: `game/fonts/OFL.txt`, `LICENSES/` and a `GODOT_LICENSES.txt` written by `tools/godot_licenses.gd` copied beside each build; fails if any is missing or empty in any folder) → PCK checks → size → Linux boot → web smoke → summary. Every Godot step runs under `timeout` and fails on a non-zero exit or any `ERROR:` / `SCRIPT ERROR` / `FAIL` line, because Godot exits 0 on some errors.
  - **Release checks:** every PCK is listed with `tools/pck_list.gd` (the engine's own reader, `--main-pack`); no PCK may hold a `res://tests/` path, a release PCK fails on any `res://rooms/dev/`, `res://scenes/dev/` or `res://scripts/dev/` path and must hold `world.gd`, the `Web debug` PCK must hold `dev_tools.gd`, and each must hold every room file it should (all of them in `Web debug`, all outside `rooms/dev/` in a release). The Linux release build runs headless for 5 s, with a fresh `user://` per build (`XDG_DATA_HOME` under `logs/`), and must still be running (exit 124) with no error line: a release build prints parse and load errors but no runtime script errors, so this proves `world.gd` loads without `scripts/dev/`. The release web build gets the boot-only smoke; the debug web build is the runtime check. The Windows build is exported and PCK-checked but never booted on the server (ledger, Story 7.15).
  - **Size:** the web download is the sum of each `web/` file's `gzip -9` size (what itch.io's CDN sends), under 30,000,000 bytes (NFR5; decided by sonlm 2026-11-19). 4.7.2's release folder is about 10 MB compressed, 40 MB raw, so plan B (a custom web template) is not needed.
  - **Layout and version:** `builds/<yyyymmdd>-<sha7>[-dirty]/{windows,linux,web,web_debug,logs}`, the version computed before the export; the playtest records' "build version" is this string. A rebuild of the same version replaces its folder.

### Architecture Decision Records

**ADR-1 — Pure state objects over manager autoloads.**
Context: M2 needs four state lifetimes; M1's statics leak between tests and can't be saved cleanly. Decision: node-free `RefCounted` state per lifetime, held by one thin `Game` autoload; only `Game` and `Audio` are autoloads. Consequences: saves are `to_dict`; tests build fresh state; any new global needs an architecture change.

**ADR-2 — Big rooms, cuts only at chain-safe points.**
Context: a descent game breaks if a transition lands mid-chain; seamless neighbour streaming is costly for a solo dev. Decision: ~10–14 large rooms per layer, transitions at doors/landings/stations, bot-checked; crossing an exit with an active chain banks it like a landing (runtime backstop); The Fall is the single scripted exception. Consequences: simple room swap; level design must place exits on safe ground; revisit if layers need seamless flow.

**ADR-3 — Text room files.**
Context: the server is headless and agents author content; addons need approval. Decision: ASCII grid + header per room, built in code. Consequences: diffable, reviewable rooms; no visual editor; optional `.tscn` overlays for set pieces; Godot MCP reconsidered only if this changes.

**ADR-4 — One Clock owns time.**
Context: hitstop, boss slow-mo, pause and the game-speed assist all touch time. Decision: only `Game.clock` writes `Engine.time_scale` (product of requests); pause uses `SceneTree.paused`. Consequences: overlaps compose; UI runs while paused; no system restores time scale by itself.

**ADR-5 — Player-volume mixing, no bus effects.**
Context: on web, bus effects don't apply in Sample playback and non-Master buses are reported unreliable. Decision: all layering and ducking by per-player volume on Master. Consequences: identical behaviour on web and desktop; no reverb or compression effects in M2.

**ADR-6 — JSON saves with atomic write and versioning.**
Context: testers play successive builds over a long M2; web storage can fail silently. Decision: JSON per slot, tmp→verify→rename with `.bak`, integer version + migrations + fixture test, `OS.is_userfs_persistent()` gate. Consequences: inspectable saves; every format change ships a migration and a fixture.

## Cross-cutting Concerns

These patterns apply to ALL systems and must be followed by every implementation.

### Error Handling

**Strategy:** three error classes, each with one handling rule. The game never shows an error dialog; the only player-visible failure is the save-failure UX state.

| Class | Examples | Rule |
|---|---|---|
| **Programmer error** | negative link count, null state ref, impossible FSM state | `assert(cond, "message")`. Debug builds and tests only (asserts are stripped from release). |
| **Content error** | malformed room file, unknown legend char, missing string key, missing sprite, unknown gear stat | Validators are pure and **return a list of errors**; the loader calls `push_error()` for each (with `file:row:col` where it applies) and **refuses to build** the thing. Works in release builds too. Tests catch these before a build ships. |
| **Environment error** | save write/read fails, web storage not persistent, corrupt `settings.json`, gamepad lost | Return `Error` / `bool`; never crash, and never pause *because of an error* (the pauses UX defines, like "Controller disconnected", still happen). Surface through a state signal to the UX state that owns it (crossed save icon, "Controller disconnected" pause, settings defaults). `push_warning()` once per occurrence for discrete failures (each failed save), once per session for standing conditions (non-persistent web storage). |

**Content errors never reach players:** `tools/export.sh` validates every room file and every string key first; any error stops the build. At runtime, a room that fails to build cancels the swap and the player stays in the current room.

**Missing string keys are content errors:** `tr()` silently returns the key, so a test scans scripts for `tr("…")` keys and fails if any is missing from `strings.csv`.

**Freeing nodes:** never `free()`; always `queue_free()` (a handler may be running on the node).

**Save triggers:** the resume saves (autosave points and the Quit menu) and the progress saves listed under Data Persistence (R14). Closing the window or tab is not a save trigger; on desktop, `NOTIFICATION_WM_CLOSE_REQUEST` runs the Quit path (including the anchor save).

**Test runner rule:** `run_tests.sh` fails the run when Godot prints any `SCRIPT ERROR` or `ERROR:` line, not only on `FAIL`. Tests that check validators call the pure validator and inspect the returned list, so they never trigger `push_error()`. Tests are scripts extending `Node`, run as scenes by `tests/runner.tscn` (readiness R17: under `--script`, a test touching the `Game` autoload fails to compile and can hang or exit 0 silently); the runner also fails a test that prints no `PASS` line or runs longer than 120 s.

**Example:**

```gdscript
# 1. Programmer error
assert(links >= 0, "ChainState: links went negative")

# 2. Content error — pure validator returns errors, loader pushes and refuses
static func validate(path: String, rows: PackedStringArray) -> Array[String]:
	var errors: Array[String] = []
	for y in rows.size():
		if rows[y].length() != rows[0].length():
			errors.append("%s:%d:1 row width %d, expected %d" % [path, y + 1, rows[y].length(), rows[0].length()])
	return errors

static func load_room(path: String) -> Room:
	var rows := _read_rows(path)
	var errors := validate(path, rows)
	for e in errors:
		push_error(e)
	return null if not errors.is_empty() else _build(rows)

# 3. Environment error — return Error, surface via signal
var err := SaveStore.write(n, Game.slot.to_dict())
if err != OK:
	push_warning("save slot %d failed: %s" % [n, error_string(err)])
	Game.save_failed.emit(n, err)   # UI: crossed icon + "Not saved"; retry at next trigger
```

### Logging

**Format:** plain text, `[category] message`.
**Destination:** engine-native. Editor output and stderr; desktop file logging in `user://logs/` (Godot default); browser console on web.

**Levels:**

| Level | Call | Release builds | Use for |
|---|---|---|---|
| Error | `push_error()` | shown | content errors (see above) |
| Warning | `push_warning()` | shown | environment errors, fallbacks taken |
| Info | `Log.info(&"category", msg)` | silent | milestones: room loaded, slot saved, settings applied |
| Debug | `Log.debug(&"category", msg)` | silent | diagnostics, only when the category is enabled |

- `Log` is a **static helper class** (`log.gd`), not an autoload, and depends on nothing (no `Game`, no `Settings`), so it is safe in any `_init`. Categories are constants on `Log`: `Log.SAVE`, `Log.ROOM`, `Log.INPUT`, `Log.CLOCK`, `Log.LURKER`, `Log.WEAVER`, `Log.AUDIO`, `Log.UI`; an unknown category asserts.
- Debug categories are enabled with a command-line arg in debug builds: `-- --log=lurker,clock`.
- **Hot paths** (`_physics_process`, `_process`, per-hit code): no logging at all unless wrapped in `if Log.enabled(Log.LURKER):`, so a disabled category costs one dictionary lookup.
- Never log every frame by default. Never use bare `print()` in game code (tests keep their `ok`/`FAIL` lines).

**Example:**

```gdscript
Log.info(Log.SAVE, "slot %d written (%d bytes)" % [n, size])
if Log.enabled(Log.LURKER):
	Log.debug(Log.LURKER, "%s notice r=%d d=%d in_rect=%s" % [name, r, d, in_rect])
# output: [save] slot 2 written (4182 bytes)
```

### Configuration

**Approach:** each kind of value has exactly one home.

| Kind | Home | Access |
|---|---|---|
| Engine and project settings (display, physics 60 ticks, interpolation, default input map) | `project.godot` | Project Settings; changed deliberately, never at runtime |
| Balancing / tuning values | `tuning.gd`: `const` base values, each with a `##` unit + intent comment and "was X" history; GDD table updated with any change | `Tuning` → effective values after gear modifiers |
| Gear definitions | data in `tuning.gd` / gear table: `{id, stat, op, value}` | `Tuning` applies them |
| Level data | `game/rooms/*.txt` | `Room` builder |
| Player settings | `Settings` → `user://settings.json` (versioned; a bad or missing key falls back to its default, then the file is rewritten; a DevTools `--set` session overrides values in memory and writes no settings.json) | `Game.settings` + its signals |
| Player progress | `SlotState` / `DiveState` → `user://slot_N.json` (versioned) | `Game.slot`, `Game.dive` |
| Player-facing text | `game/text/strings.csv` | `tr()` |
| Platform differences | `OS.has_feature("web")` branches, only in boot, display scale, storage check, quit button and audio gate | — |

No remote configuration. No `.tres` until a decision adds one.

### Event System

**Pattern:** typed Godot signals on the owning object (decision 11). No global event bus.

**Naming:** `snake_case`, past tense or state-noun + `_changed`, typed parameters. On state objects the owner gives the context, so short names are fine (`chain.changed`, `chain.banked`); on nodes, be explicit (`player.died`, `world.room_entered`).

- **Who connects:** the subscriber connects to the owner's signal through `Game` refs or a direct child reference. Never by node path.
- **Stable instances:** `Game` keeps the same `Settings`, `SlotState` and `DiveState` instances for the whole session and resets them in place (`from_dict()` / `reset()` emit their change signals), so subscriptions never point at a stale object. Tests construct their own fresh instances.
- **Sync only:** signals are processed immediately. Anything that changes the scene tree from a signal handler (room swap, freeing nodes) uses `call_deferred`.
- **No signals for actor contact:** actors keep groups + duck typing (`take_hit()`) and polling where M1 tests depend on it (crawler contact).

**Example:**

```gdscript
# dive_state.gd (RefCounted)
signal carried_changed(carried: int)
signal cache_changed(room_id: StringName, amount: int)

# gutters.gd (HUD)
func _ready() -> void:
	Game.dive.carried_changed.connect(_on_carried_changed)

# world.gd — tree change from a handler is deferred
func _on_exit_reached(target: StringName) -> void:
	_swap_room.call_deferred(target)
```

### Debug Tools

**Available tools** (debug builds only):

| Tool | What it does |
|---|---|
| **Entry args** | `godot --path game -- --room=weaver_test --chain=8 --hp=1 --difficulty=hard` starts straight into a room with state set (E2's "debug entry into the Weaver arena": `weaver_test` is E2's dev arena, Story 2.1; `weaver_arena` stays E4's final room). Story 1.11 added `--room`, `--chain`, `--log` and `--set`; Story 1.12 added `--glow=on\|off` (a code-built `WorldEnvironment` under DevTools, for the perf check only) and `--perf[=<s>]` (the perf run, below); `--hp` (1.19) and `--difficulty` (1.22) each add one row to DevTools' `ARGS` registry |
| **Session settings** | `-- --set=brightness:0` sets any `Settings` key for this session only (typed by its default: int, float, bool `true`/`false`; repeatable) through `Game.override_setting()`; a session with any override writes no settings.json at all. Until Options (1.36) it is how brightness changes |
| **Overlays** (one dev action cycles them) | 1: play rect + notice rect + gutters · 2: the player's light radius + notice reach, predator states (sense/stir rings with 1.20) · 3: room exits, entries + persistent object ids · 4: FPS, `lights n/6, sprites m` (+ `over k`) from `BudgetLight.counts()` on `World.light_rect()` (what the budget counts, Story 1.12), wall-clock frame and worst-frame times, the perf run's progress and summary, active Clock requests |
| **Log categories** | `-- --log=lurker,clock` (names from `Log.CATEGORIES`, any case) |
| **Smoke markers** | debug web exports print console markers (`SMOKE boot ok`, `SMOKE save ok`) that the Playwright smoke check reads; the release web export gets a boot-only check. As built (Story 1.13): DevTools prints `[room] SMOKE boot ok` (`Log.ROOM`) once, on World's first `room_entered` (one-shot), in real runs only (the current-scene gate the args use), so tests never print it; `SMOKE save ok` comes with 1.39 |
| **Tests and bot** | `./run_tests.sh`, the reachability bot, `screenshot.gd` (unchanged) |

**Args source:** `OS.get_cmdline_user_args()` on desktop; in web debug builds the URL query (`?room=s3_gate&chain=4`) through `JavaScriptBridge.eval("window.location.search")`, which returns null off the web, so there is no `OS.has_feature("web")` branch. Args apply only when World is the current scene (a real run); a test injects tokens through World's `child_entered_tree`, so every other test gets an inert DevTools. A bad arg is a `push_warning`, never an error: the game still starts (an unknown or invalid `--room` loads the default start room).

**Arg phases:** the hook is the first statement of `World._ready()`, so DevTools applies `--log`, then `--set`, then `--room` at once, before `Game.boot()` and the first room (which is why `--set` must survive `boot()`'s load). `--chain` arms on every `player_spawned` and is paid as n `ChainState.add_hit()` calls on the first physics tick that ends with that player off the floor; it then breaks and banks like any chain, never pinned. `--room` sets `World.start_room` / `start_entry` (the `P`, else the up entry, else down) and never writes `Game.dive`'s respawn point.

**Perf run** (Story 1.12, decided by sonlm 2026-11-19: the autopilot): `--perf[=<s>]` (60 s by default, 1–600; `?perf` on web) adds `dev/perf_run.gd` under DevTools. On every spawn it locks the player's input, masks its `Hurtbox` off, holds `--chain`'s n (else 20) paid through `--chain`'s take-off arming (never pinned), and moves it every physics tick along a vertical ping-pong down the room's centre at 100 px/s from a tick counter (repeatable across machines and browsers). Two stand-in `BudgetLight`s ride along under the room: a flare (ALWAYS, at the player's light radius) and an Ember Cache (CACHE, 80 px). It measures wall-clock frame times (`Time.get_ticks_usec()`, never `delta`) and samples `BudgetLight.counts()` every tick, then freezes one summary (frames, avg/min FPS, the worst frame and when, frames over 20 ms, max lights/sprites/over, breaks and deaths, glow, window, adapter), logs it once and shows it in overlay 4. The scene is `rooms/dev/perf_worst.txt`; the procedure, `docs/perf.md`, is run in Story 1.15.

**Activation:** `World` adds a `DevTools` node only when `OS.is_debug_build()` is true (editor runs and debug exports). Release exports never contain it. The overlay toggle is a dev-only input action, `dev_overlay`, on the backquote key (`` ` ``, physical keycode 96); DevTools is `PROCESS_MODE_ALWAYS`, so it cycles while paused. **No function keys.**

```gdscript
# world.gd
func _ready() -> void:
	if OS.is_debug_build():
		add_child(load("res://scripts/dev/dev_tools.gd").new())  # path string, never preload: release exports exclude scripts/dev/
```

### Other Cross-cutting Rules

These come from earlier decisions; listed here so every agent sees them together.

- **Time:** only `Game.clock` writes `Engine.time_scale`; real-time visuals use `delta / Engine.time_scale` (never for a visual that starts on a hit tick: see Time and pause); UI runs with `PROCESS_MODE_ALWAYS`.
- **Accessibility:** all flashing, shaking, pulsing and easing read `Settings.reduce_flashing`, `shake`, `reduced_motion` through `Fx`, camera shake, the invulnerability blink and UI easing. No per-effect toggles. Every effect respects ≤ 3 flashes/s.
- **Strings:** all player-facing text through `tr()`; copy names shapes, never colours (UX O16).
- **Play rect:** "on screen" always means `World.play_rect()`, never the viewport (the light budget's cost rule counts the whole view, `World.light_rect()`; see Lighting).
- **Determinism:** no randomness in level behaviour (camera shake only).
- **Input:** gameplay reads `PlayerInput` intents; menus read menu actions; nothing reads raw keycodes.

### Enforcement

Rules nobody checks get broken quietly. These checks run in `./run_tests.sh`:

- **Architecture lint** (`tests/test_lint.gd`, a plain text scan of `game/scripts/`, comments dropped):
  fails on a time-scale write outside `clock.gd`; raw input (`Input`, `InputMap`, `InputEvent*`, the
  `_input`/`_gui_input` callbacks) outside `player_input.gd`, `core/devices.gd`, the UI kit and `dev/`
  (DevTools reads only its own `dev_*` action, ships in no release build and must work while the
  player is dead, locked or absent); any `print(` family call outside `core/log.gd`; `free()` in any
  form; absolute node paths; any `KEY_*` keycode outside the UI kit; any randomness (`randf`/`randi`/
  `seed`/`pick_random`/`shuffle`/`RandomNumberGenerator`, …) outside camera shake; the `rules/`
  purity and `core/` layer rules below; `DevTools`, any `class_name` declared under `dev/`, or a
  `res://scripts/dev/` / `res://scenes/dev/` path outside `dev/` (`dev_ref`), except `world.gd`'s one guarded
  `load()` line: exactly that line, once, right under its `if OS.is_debug_build():` (a tree check
  proves the real `world.gd` holds it exactly once, so a stale exemption fails); `PointLight2D.new(`
  or `extends PointLight2D` outside `core/budget_light.gd` (`raw_light`, Story 1.12: every light is a
  `BudgetLight`; `.tscn` files are audited by `test_light_budget` instead); any `res://tests/`
  path in game code (release exports drop `tests/*`); writes to `Game.settings` / `slot` / `dive` /
  `tuning` state that skip a rule method (assignments, nested fields, container mutators, `.set(`) or
  replace a `Game` instance, outside `rules/`. Each hit prints `FAIL lint <file>:<line> <rule>`; every
  `tests/spec.gd` const must cite the GDD. Story 1.9 and its code review widened the original list
  (all keycodes, event-based input, more randomness, Node classes / `OS` / `Time` / file access /
  `load(` / upper-layer classes in `rules/`, `tests_ref`, state writes), and Story 1.11 added the
  `dev/` allowance and `dev_ref`'s guarded line; the rule ids and samples live in `test_lint.gd`, the
  table in `docs/development-guide.md`.
- **Test discovery:** `run_tests.sh` runs every `tests/test_*.gd` and `tests/smoke_*.gd` by glob, so a
  new test file can never be silently skipped (replaces the hand-maintained `for t in …` list).
- **String keys, room files:** validated as content (see Error Handling).

## Project Structure

### Organization Pattern

**Pattern:** hybrid. Type folders at the top of `game/` (as in M1), the same domain subfolders inside `scripts/` and `scenes/`.

**Rationale:** keeps M1's type layout and the pipelines' single output folders (`art/`, `audio/sfx/`), while ~50–70 scripts by E7 stay findable by domain. Replaces the M1 rule "scripts flat in `game/scripts/`".

### Directory Structure

```
pixel_art_game/
├── game/                              # Godot project root (res://)
│   ├── project.godot                  # autoloads: Game, Audio (E3) — nothing else
│   ├── export_presets.cfg             # Windows, Linux, Web, Web debug; include filter rooms/*.txt (`*` crosses `/`); test_export_presets pins it
│   ├── run_tests.sh                   # globs tests/test_*.gd + tests/smoke_*.gd, each run via tests/runner.tscn
│   ├── scripts/
│   │   ├── core/                      # session plumbing, no gameplay rules
│   │   │   ├── game.gd                # autoload Game: settings, slot, dive, tuning, clock, display, devices
│   │   │   ├── clock.gd               # Node child of Game; only writer of Engine.time_scale
│   │   │   ├── display.gd             # Node child of Game: integer scale rule, sub-×1 fit, PC window, min window (fullscreen: 7.2)
│   │   │   ├── devices.gd             # last-used device, glyph swap, active pad
│   │   │   ├── save_store.gd          # JSON slots, atomic write, .bak, migrations
│   │   │   ├── log.gd                 # static Log, category consts
│   │   │   ├── palettes.gd            # zone palettes + UI role colours (data from DESIGN.md tokens)
│   │   │   ├── budget_light.gd        # BudgetLight: every PointLight2D, its rank, the ≤ 6 budget rule, sprite fallback (1.12)
│   │   │   ├── text_style.gd          # TextStyle: font, sizes, line metrics, CAP_TOP, play_text() outline (1.17; core/ so Fx can use it)
│   │   │   └── fx.gd                  # code-built effects, cached materials (unshaded(), additive()), reads the accessibility gate
│   │   ├── rules/                     # pure RefCounted / static, unit-tested
│   │   │   ├── chain_state.gd
│   │   │   ├── health.gd
│   │   │   ├── dive_state.gd          # carried, killed enemies, respawn point
│   │   │   ├── slot_state.gd          # world flags, Ember Cache, deposited, records, journal, map, death log
│   │   │   ├── settings.gd
│   │   │   ├── tuning.gd              # base consts (## units, GDD history) + gear modifiers
│   │   │   ├── gear.gd                # gear table as data {id, stat, op, value}
│   │   │   ├── sensing.gd             # notice / stir / sense / target choice maths
│   │   │   ├── economy.gd             # prices, ember_value curve (GDD citations)
│   │   │   ├── dialogue.gd            # per-NPC ordered {key, requires_flag} line lists (linear, flag-gated)
│   │   │   └── migrations.gd          # migrate_vN_to_vN1 functions
│   │   ├── world/
│   │   │   ├── world.gd               # room swap, respawn, play_rect(), light_rect(), exit backstop
│   │   │   ├── light_budget.gd        # World's LightBudget child: applies the light budget each tick, priority 50 (1.12)
│   │   │   ├── room.gd                # built room node; owns transient entities
│   │   │   ├── room_loader.gd         # parse + pure validate + build (TileSet in code, rims)
│   │   │   ├── room_legend.gd         # char → tile/entity table (single source)
│   │   │   └── camera_rig.gd          # limits, downward lead, shake, gutter framing
│   │   ├── actors/                    # things that move and fight
│   │   │   ├── player.gd
│   │   │   ├── player_input.gd        # intents, Light tap/hold, toggles, buffers, lock()
│   │   │   ├── light_source.gd
│   │   │   ├── flare.gd
│   │   │   ├── crawler.gd
│   │   │   ├── lurker.gd
│   │   │   ├── spiderling.gd          # E2
│   │   │   └── weaver/                # E2, E6
│   │   │       ├── weaver.gd
│   │   │       ├── strand.gd
│   │   │       └── strand_anchor.gd
│   │   ├── objects/                   # placed interactables (persistent ids)
│   │   │   ├── lantern_anchor.gd
│   │   │   ├── lift_station.gd
│   │   │   ├── chain_gate.gd          # E4
│   │   │   ├── ember_cache.gd
│   │   │   ├── ember_hoard.gd         # E4
│   │   │   ├── journal_object.gd      # E4
│   │   │   ├── silk_anchor.gd         # E6
│   │   │   └── npc.gd                 # E5
│   │   ├── moments/                   # scripted one-offs on shared primitives
│   │   │   ├── the_fall.gd            # E6
│   │   │   ├── watching_departure.gd  # E5
│   │   │   ├── weaver_reveal.gd       # E4/E6
│   │   │   └── last_entry.gd          # E4
│   │   ├── ui/
│   │   │   ├── gutters.gd             # HUD, binds to state signals
│   │   │   ├── screen_router.gd       # one screen at a time, replace never stack
│   │   │   ├── theme_builder.gd       # Theme built in code, Fusion Pixel 8px
│   │   │   ├── kit/                   # E1: menu_list, tab_bar, ember_cursor, confirm_step,
│   │   │   │                          #     toggle, slider, glyph_prompt
│   │   │   └── screens/               # web_gate, title, slot_picker, difficulty_step, pause,
│   │   │                              # options, death_card, station_menu, credits (E1–E7);
│   │   │                              # map_tab (E4); speech_box, shop_list, journal_tab (E5)
│   │   ├── audio/
│   │   │   ├── audio.gd               # autoload Audio (E3): SFX pool, positional cues
│   │   │   └── music_stems.gd         # stem sync, chain layers, ducking (volume tweens)
│   │   └── dev/                       # debug builds only; nothing depends on dev/
│   │       ├── dev_tools.gd           # entry args (CLI / URL query), smoke markers
│   │       ├── overlays.gd            # play rect, light rings, exits/ids, perf
│   │       └── perf_run.gd            # --perf: the autopilot perf run, stand-in lights, frame stats, summary (1.12)
│   ├── scenes/                        # mirrors scripts/ domains; thin prefabs
│   │   ├── world/world.tscn
│   │   ├── actors/                    # player.tscn, crawler.tscn, lurker.tscn, flare.tscn, weaver/
│   │   ├── objects/
│   │   └── ui/                        # gutters.tscn, screens/*.tscn (if a screen needs a scene)
│   ├── rooms/                         # level data (exported via include filter)
│   │   ├── l1/                        # s1_lip.txt … s5_hollow.txt, a_rope_works.txt,
│   │   │                              # b_old_mine.txt, c_sky_ledge.txt, weaver_arena.txt (+ .tscn overlay)
│   │   ├── l2/                        # landing_arena.txt (E6)
│   │   ├── hub/                       # island.txt (E5)
│   │   └── dev/                       # perf_worst.txt; exported by debug presets only (release excludes rooms/dev/*)
│   ├── art/                           # BUILD OUTPUT of tools/build_sprites.py (+ .import). Never hand-edit.
│   ├── audio/
│   │   ├── sfx/                       # BUILD OUTPUT of tools/build_sfx.py (E3)
│   │   └── music/                     # composed stems: l1_pulse.ogg, l1_melody.ogg, l1_full.ogg …
│   ├── fonts/
│   │   ├── fusion-pixel-8px-proportional-latin.otf
│   │   ├── OFL.txt
│   │   └── LICENSES/                  # upstream licence folder, shipped in every build
│   ├── text/
│   │   └── strings.csv                # + generated .translation files (committed)
│   └── tests/
│       ├── test_*.gd                  # unit: pure rules (test_chain_state, test_health, test_saves …)
│       ├── smoke_*.gd                 # scene: real rooms + input (smoke_shaft → smoke_rooms, smoke_bot …)
│       ├── test_lint.gd               # architecture lint (text scan of scripts/)
│       ├── screenshot.gd              # manual visual check (needs xvfb)
│       ├── rooms/                     # test-only rooms: bot and validator fixtures (not exported)
│       └── fixtures/                  # slot_v1.json and later save fixtures (not exported)
├── tools/
│   ├── build_sprites.py               # existing; sprites/*.txt + palette_edge.txt
│   ├── sprites/
│   ├── build_sfx.py                   # E3; sfx/*.txt parameter files
│   ├── sfx/
│   ├── export.sh                      # validate content → export 3 targets (+ Web debug) → PCK checks → size check → Linux boot → web smoke (licences from 1.17)
│   ├── pck_list.gd                    # lists a PCK through the engine's own reader (--main-pack); export.sh's release check
│   └── web_smoke/                     # Playwright (package.json + lock, playwright.config.js, serve.js, smoke.spec.js); outside game/ so Godot never scans node_modules
├── builds/                            # export output (gitignored)
├── docs/                              # as-built docs; docs/rooms.md documents the room format + legend
└── _bmad-output/                      # planning artefacts (GDD, UX, this document)
```

**M1 migration (done in E1, with `git mv` so `.gd.uid` files move with their scripts):**
`chain_state.gd` → `rules/`; `player.gd`, `crawler.gd`, `lurker.gd` → `actors/`; `fx.gd` → `core/`; `shaft.gd` is retired (its LAYOUT becomes `rooms/l1/m1_shaft.txt` at 22 tiles, its statics move into state objects); `scenes/enemies/*` → `scenes/actors/`; `tests/run_tests.gd` → `tests/test_chain_state.gd`.
Do the moves in one commit, then rewrite every moved `res://` path by hand (the M1 scenes carry no `uid=` attributes) and run `godot --headless --path game --import`; update the autoload paths in `project.godot`; `run_tests.sh` must be green before anything else changes.

### System Location Mapping

| System | Location | Responsibility |
|---|---|---|
| Session state holder | `scripts/core/game.gd` (autoload `Game`) | holds `settings`, `slot`, `dive`, `tuning`, `clock`, `store`, `devices`; new game / load / save commands; no gameplay rules |
| Time authority | `scripts/core/clock.gd` | named time-scale requests, pause-aware |
| Saves | `scripts/core/save_store.gd`, `scripts/rules/migrations.gd` | slot files, atomic write, `.bak`, versioning |
| Logging | `scripts/core/log.gd` | static `Log` |
| Effects | `scripts/core/fx.gd` | code-built FX, cached materials, accessibility gate |
| Light budget | `scripts/core/budget_light.gd`, `scripts/world/light_budget.gd` | every `PointLight2D` as a ranked `BudgetLight`; ≤ 6 lit in `World.light_rect()` each physics tick, sprite fallback (Story 1.12) |
| Palette zones | `scripts/core/palettes.gd` | Layer 1 zone palettes and UI role colours (DESIGN.md tokens), zone cross-fade data; read by world tint and gutters |
| Chain, health, embers, gear rules | `scripts/rules/` | pure rules + `Tuning`, unit-tested |
| Light sensing maths | `scripts/rules/sensing.gd` | notice / stir / sense / target choice |
| Economy data | `scripts/rules/economy.gd` | prices (map 60, hint 25, gear 200–300, cosmetics 75–150), ember curve, journal payout |
| NPC dialogue data | `scripts/rules/dialogue.gd` + `text/strings.csv` | per-NPC ordered line keys gated by slot flags; the narrative pass writes the strings |
| Display scaling | `scripts/core/display.gd` | Integer scale from physical pixels (the engine's HiDPI canvas on web), sub-×1 fit, PC window fit and minimum; fullscreen in 7.2 |
| World and rooms | `scripts/world/` + `rooms/` | room load/validate/build, swap, respawn, play rect, camera |
| Player kit | `scripts/actors/player.gd`, `player_input.gd` | movement, attacks, Light, cling, Flare Toss, Swing |
| Enemies and predators | `scripts/actors/` (`weaver/` for the boss) | crawler, lurker, spiderling, Weaver parts |
| Light emitters | `scripts/actors/light_source.gd`, `flare.gd`; `objects/ember_cache.gd` | sensed lights |
| Placed interactables | `scripts/objects/` | anchors, stations, gates, hoards, journal objects, silk anchors, NPCs |
| Scripted moments | `scripts/moments/` | The Fall, Watching Departure, Weaver reveal, Last Entry |
| HUD and menus | `scripts/ui/` | gutters, screen router, UI kit, screens, theme |
| Audio | `scripts/audio/` + `audio/` | autoload `Audio`, stems, SFX |
| Strings | `text/strings.csv` | every player-facing string, including NPC lines (`NPC_SMITH_GREET_1`) and journal text (`JOURNAL_A_1_BODY`) written by the narrative pass |
| Dev tools | `scripts/dev/` | debug-build-only entry args, overlays, the perf run (`perf_run.gd`), smoke markers |
| Sprites / SFX pipelines | `tools/` → `game/art/`, `game/audio/sfx/` | text sources → build output |
| Builds | `tools/export.sh`, `tools/pck_list.gd`, `tools/web_smoke/` → `builds/` | validate, export, PCK checks, size, boot, smoke (licences from 1.17) |
| Tests | `game/tests/` | unit, smoke, bot, lint, fixtures |

### Naming Conventions

#### Files

- Scripts and scenes: `snake_case`; a scene shares its script's base name (`lurker.gd` / `lurker.tscn`).
- Every script with a `class_name` uses the PascalCase form of its file name (`chain_state.gd` → `ChainState`). Autoload scripts have no `class_name` (the autoload name is the global).
- Tests: `test_<subject>.gd` (unit), `smoke_<subject>.gd` (scene). Anything else in `tests/` is a helper and is not run by the glob.
- Rooms: `rooms/<layer>/<room_id>.txt`; an optional set-piece overlay is `<room_id>.tscn` beside it.

#### Code Elements

| Element | Convention | Example |
|---|---|---|
| Classes | PascalCase | `DiveState`, `PlayerInput` |
| Functions, variables | snake_case | `add_hit()`, `carried` |
| Private members | `_` prefix | `_swap_room()`, `_grace_left` |
| Constants | UPPER_SNAKE | `MAX_LINKS`, `SNUFF_HOLD` |
| Signals | snake_case, past tense or `_changed` | `banked`, `carried_changed`, `room_entered` |
| Enums | PascalCase type, UPPER_SNAKE values | `enum State { IDLE, TELEGRAPH, HUNT, RETURN }` |
| Ids (rooms, objects, tuning keys, clock requests) | `StringName` literals, snake_case | `&"s2_scaffold"`, `&"anchor_s2_1"`, `&"cling_slide"`, `&"hitstop"` |
| Groups | lowercase singular | `player`, `enemy`, `predator`, `light_source`, `world` |
| Input actions | snake_case verbs; menus use their own `menu_*` actions (not Godot's `ui_*` defaults) | `jump`, `light`, `snuff_toggle`, `interact`, `menu_confirm`, `menu_back`, `menu_tab_next` |
| String keys | UPPER_SNAKE, domain prefix | `MENU_RESUME`, `DEATH_LURKER_LINE`, `DEATH_LURKER_TIP`, `TIER_NORMAL` |
| Log categories | consts on `Log` | `Log.SAVE` |

#### Game Assets and Data

- **Uniqueness:** room ids and persistent object ids are unique across the whole game, not per layer; a test loads every room file and fails on duplicates.
- **Map placement:** each room header declares its map box in screens (`map=x,y,w,h`), so the Map tab (E4) and the per-layer reward counts come from room files, not a separate map file.
- **Room ids:** `<segment>_<name>` for the spine (`s1_lip`, `s3_gate`), `<letter>_<name>` for side areas (`a_rope_works`), descriptive for others (`weaver_arena`, `landing_arena`, `island`).
- **Persistent object ids:** `<kind>_<room short>_<n>`: `anchor_s2_1`, `hoard_a_1`, `gate_s3_1`, `journal_b_1`, `station_lip`. Ids never change once a build has shipped to testers; renaming one needs a save migration.
- **Sprites:** `tools/sprites/<subject>[_<variant>].txt` → `game/art/<same>.png` (`lurker_eyes`, `ember_cache`).
- **SFX:** `tools/sfx/<event>.txt` → `game/audio/sfx/<event>.wav` (`pogo_hit`, `bank_chime`, `lurker_growl`).
- **Music stems:** `<layer>_<stem>.ogg` (`l1_pulse`, `l1_melody`, `l1_full`, `hub_theme`, `weaver_theme`).

### Architectural Boundaries

Dependencies point one way:

```
rules/  ←  core/  ←  world/, actors/, objects/, moments/  ←  ui/, audio/  ←  dev/
(pure)    (Game)     (scene code)                            (presentation)  (debug only)
```

- **`rules/`** never references nodes, scenes, `Input`, `Engine` or `Game`. It may use other `rules/` files and `Log`.
- **`core/`** may use `rules/`; it never references `world/`, `actors/`, `objects/`, `ui/` or `audio/` types.
- **Scene code** (`world/`, `actors/`, `objects/`, `moments/`) reads `Game` state and `Tuning`, and changes state only through rule methods (`Game.slot.set_flag(id)`, `Game.dive.add_carried(n)`). Actors reach `World` only through the `world` group (duck-typed `play_rect()`, `request_respawn()`), never by path.
- **`ui/`** subscribes to state signals and sends commands (`Game.save_now()`, `Game.load_slot(n)`, `world.fast_travel(id)`); it writes only `Settings` directly and never mutates gameplay state.
- **`audio/`** only listens.
- **`dev/`** may touch anything; nothing outside `dev/` and `tests/` may reference `dev/`, except `world.gd`'s one guarded path-string `load()` that adds DevTools (Story 1.11).
- **`tools/`** live outside `game/` and write only into `game/art/` and `game/audio/sfx/`.
- **Tests** may use anything; test-only data (`tests/rooms/`, `tests/fixtures/`) is never exported (export presets exclude `tests/*`).
- **Enforced by `tests/test_lint.gd`:** files in `rules/` must not mention any Node class, `Input*`, `Engine*`, `OS`, `Time`, file access, the autoloads (`Game`, `Audio`) or any class from `core/` and above (`rules_purity`); files in `core/` must not mention the class names, autoloads or paths of `world/`, `actors/`, `objects/`, `moments/`, `ui/`, `audio/` or `dev/` (`core_layer`); nothing outside `dev/` and `tests/` references `DevTools`, a `class_name` declared under `dev/` or a `res://` path into `dev/`, except that one guarded line (`dev_ref`).

## Implementation Patterns

These patterns ensure consistent implementation across all AI agents.

### Novel Patterns

#### 1. Light-as-Signal

**Purpose:** Pillar 1 (Chain = Light = Danger). Several things emit light, predators react to light, and the reactions differ: lurkers seek it, the Weaver flees it, the Ember Cache lures. One model keeps the rules in one place and keeps the Pillar 2 guarantees (telegraph, no off-screen notice) true for every light.

**Components:**

| Component | Location | Responsibility |
|---|---|---|
| `LightSource` (Node2D) | `actors/light_source.gd` | group `light_source`; `kind` (`&"player"`, `&"flare"`, `&"cache"`); `radius() -> float`; drives its `PointLight2D` (or sprite glow) |
| `Sensing` (static) | `rules/sensing.gd` | pure maths: `can_notice()`, `can_sense()`, `pick_target()`; unit-tested |
| `World.play_rect()` | `world/world.gd` | visible play area inside the gutters, world coordinates |
| Lurker / Weaver | `actors/` | query lights each physics tick, apply their own response |

**Data flow (each physics tick):**

```
Player.chain.light_radius() ─┐
Flare.radius (pre-toss, 4 s) ─┼─> LightSource.radius()
Cache glow radius (tuning) ───┘          │
                                         ▼
Lurker: lights = get_tree().get_nodes_in_group("light_source")
        rect   = world.play_rect()
        sensed = lights.filter(Sensing.can_sense(l, self, rect))
        target = Sensing.pick_target(sensed)        # brightest; ties → non-player
        FSM uses target (IDLE → TELEGRAPH → HUNT → RETURN)
Weaver: same query; flees the brightest flare; bright/dark from the player's radius
```

**Rules:**
- **Notice:** radius ≥ 80 px **and** distance ≤ radius × 1.6 **and** the predator is inside `play_rect()` (shrunk by the screen margin). The same rule for every kind, so a cache wakes lurkers only if its glow radius is ≥ 80 px (tuning note for the E1 playtest).
- **Target choice:** the sensed light with the largest radius; on a tie, a non-player light wins (a flare is a lure). A fresh flare carries the pre-toss radius, so it normally out-shines the halved chain.
- **Stirring (off-screen warning, GDD Lurker):** `Sensing.can_stir()` is true when the lurker *would* sense the light but sits outside the play rect, within 96 px of its edge. The lurker stays in `IDLE`, exposes `stir` (`0` closed, `1` half, `2` open, rising while the condition holds), and never telegraphs or hunts while stirring. The gutter edge cue reads `predator` nodes and shows the eye level with the lurker's height; the stirring sound (E3) uses the same value. A guarantee test checks that stirring never leads to a hunt without an on-screen telegraph.
- **Retargeting onto the player needs a fresh telegraph:** if a lurker's target changes from a flare or cache to the player, it re-enters `TELEGRAPH` (≥ 0.75 s). Pillar 2: every hunt of the player is telegraphed. Retargeting from the player to a flare needs no telegraph.
- **Lethality is unchanged:** `monitorable` is true only in `HUNT` while the **player** is the sensed target. A lurker sitting on a cache or a flare is harmless until it telegraphs at the player.
- **Weaver:** bright = player radius ≥ 80 px, dark = ≤ 40 px; flees along strands to the farthest point inside the flare's radius × 1.5 (E2 decides the exact flee target; GDD open question).

**Implementation guide:**

```gdscript
# rules/sensing.gd
class_name Sensing
## Pure light-sensing maths shared by every predator (GDD Lurker; Pillar 2).

const NOTICE_MIN_RADIUS := 80.0  ## px: chain ≈ 4; base light (40) is never noticed
const NOTICE_FACTOR := 1.6       ## reach = radius × 1.6

static func can_sense(light_pos: Vector2, light_radius: float, pred_pos: Vector2, play_rect: Rect2) -> bool:
	if light_radius < NOTICE_MIN_RADIUS:
		return false
	if pred_pos.distance_to(light_pos) > light_radius * NOTICE_FACTOR:
		return false
	return play_rect.has_point(pred_pos)  # Pillar 2: only notice where the telegraph is seen

## lights: Array of {kind: StringName, radius: float, pos: Vector2}; returns the index or -1.
static func pick_target(lights: Array[Dictionary]) -> int:
	var best := -1
	for i in lights.size():
		if best == -1 or lights[i].radius > lights[best].radius \
				or (lights[i].radius == lights[best].radius and lights[i].kind != &"player"):
			best = i
	return best
```

**Usage:** any new predator or light-reactive object (Layer 2+ bosses) uses `LightSource` + `Sensing`. Never call `get_first_node_in_group("player")` to sense light.

#### 2. Rule-Bending Gear (`Tuning`)

**Purpose:** gear "bends a rule, never adds raw power" (GDD). Every gameplay number lives once, with its GDD citation, and gear changes it in one place, so actors never contain `if has_gear(...)`.

**Components:**

| Component | Location | Responsibility |
|---|---|---|
| Base constants | `rules/tuning.gd` | `const` per value, each with a `##` unit + intent + "was X" comment; a `BASE` map from key to const |
| Gear table | `rules/gear.gd` | data: `{id, stat, op, value}`; `op` is `&"set"`, `&"add"` or `&"mul"`; flags use `&"flag"` |
| `Tuning` instance | `Game.tuning` | rebuilt from `Game.slot.gear` when gear changes; `f(key)` for numbers, `flag(key)` for rule switches |

**Data flow:** `SlotState.gear` changes → `Game` rebuilds `tuning` → `Tuning.changed` → actors re-read on their next tick (they never cache across frames).

**Rules:**
- Modifiers apply in a fixed order regardless of gear order: all `set`, then all `add`, then all `mul`.
- Input-response changes are **flags**, not numbers. Quick Wick sets `&"instant_snuff"`; `PlayerInput` reads it to start dimming on press. The tap window stays a `Settings` value, never a `Tuning` key.
- Difficulty is **not** a modifier: it only changes death cost (GDD) and lives in `SlotState`.

**Implementation guide:**

```gdscript
# rules/tuning.gd
class_name Tuning
extends RefCounted

signal changed

const CLING_SLIDE := 18.0   ## px/s slide while clinging (M1). Steady Grip → 10.
const CLING_GRACE := 1.0    ## s of paused chain per cling; a pogo hit refills it (M1). Silk Grip +0.25.
const FLARE_BURN := 4.0     ## s a flare burns (GDD Flare Toss). Long Wick → 6.

const BASE := {
	&"cling_slide": CLING_SLIDE,
	&"cling_grace": CLING_GRACE,
	&"flare_burn": FLARE_BURN,
}

var _mods: Array[Dictionary] = []
var _flags: Dictionary = {}

func apply_gear(gear_ids: Array[StringName]) -> void:
	_mods = Gear.mods_for(gear_ids)
	_flags = Gear.flags_for(gear_ids)
	changed.emit()

func f(key: StringName) -> float:
	assert(BASE.has(key), "Tuning: unknown key %s" % key)
	var v: float = BASE[key]
	for op in [&"set", &"add", &"mul"]:
		for m in _mods:
			if m.stat == key and m.op == op:
				v = m.value if op == &"set" else (v + m.value if op == &"add" else v * m.value)
	return v

func flag(key: StringName) -> bool:
	return _flags.get(key, false)

# rules/gear.gd (data)
const TABLE := [
	{id = &"long_wick",   stat = &"flare_burn",    op = &"set",  value = 6.0},
	{id = &"steady_grip", stat = &"cling_slide",   op = &"set",  value = 10.0},
	{id = &"silk_grip",   stat = &"cling_grace",   op = &"add",  value = 0.25},
	{id = &"quick_wick",  stat = &"instant_snuff", op = &"flag", value = true},
]

# actors/player.gd — reading tuning
velocity.y = minf(velocity.y, Game.tuning.f(&"cling_slide"))
```

**Usage:** any gameplay number that gear, a later ability or an assist might change goes into `Tuning`. Numbers no system will ever bend (physics layer values, UI pixel positions) stay local consts.

#### 3. Safe-Cut Room Flow

**Purpose:** move between big rooms without ever cutting a live chain, keep world progress stable across builds, and make every room testable on its own.

**Components:** `World` (swap, respawn, backstop), `RoomLoader` (parse, validate, build), `Room` (owns spawned and transient nodes), `room_legend.gd`, `SlotState` / `DiveState`.

**Data flow:**

```
enter_room(room_id, entry)
  RoomLoader.load("rooms/<layer>/<room_id>.txt")
    parse header + grid → validate() → errors? push_error, cancel swap, stay in current room
    build tiles + rims (TileSet in code)
    for each legend spawn cell:
      persistent object (header id)  → skip if SlotState flag says taken/opened; else instance with id
      enemy (room_id + cell)         → skip if DiveState.killed has it; else instance
    Ember Cache                      → spawn if SlotState.cache.room == room_id
  World: free old room (queue_free) → add new room → place player at entry/anchor
         → camera limits → reset_physics_interpolation() → SlotState.visit(room_id) → room_entered

exit trigger (built from header `exits=`)
  player overlaps → if chain.count > 0: chain.break_chain()   # backstop: banks like a landing
  → World._swap_room.call_deferred(target, entry)

death
  Player.died → DiveState/SlotState apply death cost by difficulty (held lost; carried → cache / kept / lost)
  → SlotState.death_log.append({cause, room}) → ScreenRouter shows the death card
  → on advance: enter_room(respawn room, respawn object) → new Player (full HP)

rest at a Lift Station
  heal → deposit (dive.carried → slot.deposited) → dive.reset() → enter_room(current room, station) (killed enemies respawn)
  → save (autosave) → station menu
```

**Rules:**
- Enemies killed this dive stay dead until a rest, arriving home or leaving the layer (GDD); death does not respawn them.
- The Ember Cache lives in `SlotState`: it survives rests and saves until it is recovered or the player dies again.
- Transient nodes (flares, FX, spiderlings, popups) are spawned with `room.spawn(scene, pos)` and die with the room.
- Room swaps are always deferred and never happen inside a physics callback. The old room is removed from the tree before it is freed, so its predators and lights leave their groups immediately.
- **Per-life rebinding:** the player is re-instanced on death, so `World` emits `player_spawned(player)`; the HUD and audio rebind to the new `player.chain` / `player.health` there. Nothing keeps a reference to a previous player.
- Every room loads standalone: tests call `RoomLoader.load()` + a test player, without `World`.

**Implementation guide:**

```gdscript
# world/world.gd
func _on_exit_reached(target: StringName, entry: StringName) -> void:
	var chain: ChainState = _player.chain
	if chain.count > 0:
		chain.break_chain()  # ADR-2 backstop: a cut never lands mid-chain
	_swap_room.call_deferred(target, entry)

func _swap_room(target: StringName, entry: StringName) -> void:
	var room := RoomLoader.load_room(target)
	if room == null:
		return  # content error already pushed; the player stays in the current room
	_room_holder.remove_child(_current_room)  # leave groups now, not at end of frame
	_current_room.queue_free()
	_room_holder.add_child(room)
	_current_room = room
	_player.global_position = room.entry_position(entry)
	_player.reset_physics_interpolation()
	_camera.apply_limits(room.bounds())
	Game.slot.visit(target)
	room_entered.emit(target)
```

**Usage:** all level content (Layer 1, the hub, the arenas, later layers) goes through this flow. The Fall is the only cut that keeps a chain: its moment script calls a dedicated `World.scripted_cut(target, entry)` that skips the backstop.

#### 4. Chain-Reactive Music (E3)

**Purpose:** the music is the "one more hit" temptation (GDD Audio): stems fade in at 3 / 6 / 10 links, resolve on a bank, cut on death, and duck under predator cues, identically on web and desktop.

**Components:** `Audio` autoload (`audio/audio.gd`), `MusicStems` (`audio/music_stems.gd`), stem files `<layer>_pulse/melody/full.ogg` of equal length.

**Data flow:** `Game` state signals → `MusicStems`:
- `chain.changed(count)` → wanted layers = (count ≥ 3) + (count ≥ 6) + (count ≥ 10) → per-stem volume tween over 0.5 s.
- `chain.banked` → resolve chord SFX, stems fade to 0 within 0.3 s.
- `player.died` → cut stems, play the dissonant tail.
- predator cue starts / ends → duck factor 0.5 (−6 dB) on all stems, restored after.

**Rules:**
- All stems start together and loop forever; a "silent" stem plays at −80 dB so the layers stay in sync.
- Stem volume = layer target × duck factor × music volume × master volume. All on Master; no bus effects (ADR-5).
- Fades use tweens with `set_ignore_time_scale(true)`, so they don't freeze during the 75 ms hitstop.
- Pogo SFX pitch = `pow(2.0, mini(link, 12) / 12.0)` (+1 semitone per link, cap +12), set before `play()`.
- Tweens animate only the **layer level**; the final volume is recomputed from layer × duck × music × master, so a duck during a fade never makes the stem jump.
- `Audio` runs with `PROCESS_MODE_ALWAYS` so music and menu sounds keep playing while paused; gameplay SFX players are pausable children, so a lurker hiss stops with the game.

**Implementation guide:**

```gdscript
# audio/music_stems.gd
var _layer: Array[float] = [0.0, 0.0, 0.0]  # per-stem layer level 0..1 (what tweens animate)

func _on_chain_changed(count: int) -> void:
	var wanted := int(count >= 3) + int(count >= 6) + int(count >= 10)
	for i in _stems.size():
		_fade_layer(i, 1.0 if i < wanted else 0.0, 0.5)

func _fade_layer(i: int, target: float, time: float) -> void:
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_method(func(v: float) -> void: _layer[i] = v; _apply(i), _layer[i], target, time)

# duck, music and master volumes change through the same function, so no tween fights another
func _apply(i: int) -> void:
	_stems[i].volume_db = linear_to_db(maxf(_layer[i] * _duck * _music_vol * _master_vol, 0.0001))
```

**Usage:** hub, Weaver and Fall themes are single-stem cases of the same player set.

#### 5. Design Guarantees as Tests

**Purpose:** the GDD's promises (Pillar 2 telegraphs, escapes that work, chain fuel everywhere) stay true as content grows. A guarantee is a test, and its threshold comes from the design, not from the tuning it checks.

**Components:**

| Component | Location | Responsibility |
|---|---|---|
| Spec constants | `tests/spec.gd` | each guarantee's threshold with its GDD citation (`TELEGRAPH_MIN := 0.75 ## GDD Lurker`) |
| Rule tests | `tests/test_*.gd` | pure rules: chain, embers, health, sensing, tuning, saves, migrations |
| Room sweep | `tests/smoke_rooms.gd` | loads **every** `rooms/**/*.txt` standalone and runs the per-room guarantees |
| Bot | `tests/smoke_bot.gd` | plain movement, no dash: chain ≥ 5 in every spine room, the required chain at every gate, the exit backstop never fires on the bot's line |

**Rules:**
- Tests compare against `spec.gd`, never against the tuning value under test (`assert(Game.tuning.f(&"lurker_telegraph_time") >= Spec.TELEGRAPH_MIN)`), so loosening tuning fails the suite.
- Changing a guarantee means changing the GDD first, with the user, then `spec.gd`.
- Per-room guarantees run on every room automatically; adding a room adds its checks.

**Per-room guarantees (`smoke_rooms.gd`):** file validates; ids are unique; every lurker's telegraph ≥ 0.75 s; no lurker notices outside the play rect; a Snuff/landing/cling in time drops a hunting lurker's lethality; base light (40 px) is never noticed; every hazard pit has a ledge or wall within a 1.5 s fall.

**Implementation guide:**

```gdscript
# tests/spec.gd  (tests preload it: const Spec := preload("res://tests/spec.gd"))
const TELEGRAPH_MIN := 0.75  ## GDD Predators: telegraph never below 0.75 s (Pillar 2)
const BOT_MIN_CHAIN := 5     ## GDD Level validation: bot reaches ≥ 5 in every spine shaft
const BASE_LIGHT := 40.0     ## GDD Chain: base light, never noticed

# tests/smoke_rooms.gd (excerpt; Story 1.10). Validate first: a bad file is a FAIL per error and is
# never built, so it never push_errors (which would fail the runner with an engine error instead).
for path in RoomSweep.room_files():  # every res://rooms/**/*.txt, sorted; sentinel: m1_shaft
	var parsed := RoomLoader.parse(FileAccess.get_file_as_string(path))
	var errors := RoomLoader.validate(path, parsed)
	for e in errors:
		check(false, e)
	if errors.is_empty() and not RoomSweep.is_dev(path):
		swept.append(RoomSweep.record(path, parsed))  # pure sweeps, then lurker scenarios on a fresh harness each
```

**Usage:** every new design guarantee in the GDD gets a `Spec` constant and a test before the feature is called done.

### Communication Patterns

**Pattern:** typed signals on state owners; groups + duck typing between actors; direct calls parent → child. No event bus, no node paths (decision 11; Cross-cutting: Event System).

```gdscript
# actor → actor: group + duck typing (M1 contract)
for body in _pogo_area.get_overlapping_bodies():
	if body.has_method("take_hit"):
		body.take_hit(self)

# actor → world: group, duck-typed
var world := get_tree().get_first_node_in_group("world")
var rect: Rect2 = world.play_rect()

# state → presentation: signal
Game.slot.flag_set.connect(_on_flag_set)
```

### Entity Patterns

**Creation:** rooms spawn from the legend table; runtime spawns go through the room. No factory, no pooling (except the `Audio` SFX players) until profiling shows a hitch.

```gdscript
# world/room_legend.gd
const SPAWNS := {
	"c": {scene = preload("res://scenes/actors/crawler.tscn"), args = {hover = false}},
	"h": {scene = preload("res://scenes/actors/crawler.tscn"), args = {hover = true}},
	"L": {scene = preload("res://scenes/actors/lurker.tscn"), args = {}},
	"A": {scene = preload("res://scenes/objects/lantern_anchor.tscn"), args = {}, persistent = true},
}

# world/room.gd
func spawn(scene: PackedScene, pos: Vector2, args := {}) -> Node2D:
	var n: Node2D = scene.instantiate()
	for k in args:
		n.set(k, args[k])
	n.position = pos
	add_child(n)  # the room owns it and frees it on swap
	return n
```

- Scenes are thin prefabs; behaviour is in scripts. A spawned entity reads its configuration from `args` set **before** `add_child` (so `_ready` sees it).
- Spawned entities get their identity (`room_id`, `cell` or persistent `id`) from the loader and never invent one.

### State Patterns

**Pattern:** `enum` + `match` in the script (as M1's lurker). One `_enter(state)` sets up each state; timers are float countdowns in physics time; the current state is a public `state` field so tests can read it.

```gdscript
enum State { IDLE, TELEGRAPH, HUNT, RETURN }
var state: State = State.IDLE
var _timer := 0.0

func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			if _target != null:
				_enter(State.TELEGRAPH)
		State.TELEGRAPH:
			_timer -= delta
			if _target == null:
				_enter(State.RETURN)
			elif _timer <= 0.0:
				_enter(State.HUNT)
		State.HUNT:
			pass  # move toward target; lethality per Light-as-Signal rules
		State.RETURN:
			pass

func _enter(next: State) -> void:
	state = next
	monitorable = next == State.HUNT and _target_is_player
	match next:
		State.TELEGRAPH:
			_timer = telegraph_time
```

- The Weaver uses the same style (`BRIGHT_RETREAT`, `DARK_DESCEND`, `BITE_TELEGRAPH`, `STUNNED`, `FLEE`, `RE_WEAVE`, `FALL`), with strands and anchors as helper nodes it owns.
- The player stays flag-based on top of `PlayerInput` intents (grounded, clinging, dashing, swinging), as in M1.
- Global flow states (title / playing / paused / dead) are not an FSM class: they are the `ScreenRouter`'s current screen plus `SceneTree.paused`.

### Data Patterns

**Access:** through `Game` refs and rule methods, never by reading files directly outside `core/` and `world/room_loader.gd`.

```gdscript
# read
var deposited := Game.slot.deposited
var grace := Game.tuning.f(&"cling_grace")
var window := Game.settings.light_tap_window

# write: always a rule method that emits its signal
Game.slot.set_flag(&"gate_s3_1", true)
Game.dive.add_carried(amount)
Game.settings.set_value(&"reduce_flashing", true)   # emits changed; core/ persists settings.json

# save/load: only Game commands
Game.save_now()            # resume-save triggers call this
Game.save_progress()       # progress moments call this (R14)
Game.load_slot(2)
```

### Consistency Rules

| Pattern | Convention | Enforcement |
|---|---|---|
| Time scale | only `clock.gd` writes `Engine.time_scale` | `test_lint.gd` |
| Input | gameplay reads `PlayerInput` intents; menus read `menu_*` actions | `test_lint.gd` (`raw_input`: `Input`, `InputMap`, `InputEvent*`, input callbacks outside allowed files) |
| Rules purity | `rules/` has no Node class, `Input`, `Engine`, `Game`, or class from a layer above | `test_lint.gd` |
| Light sensing | predators sense through `LightSource` + `Sensing` only | review; `smoke_rooms.gd` guarantees |
| Gear and tunable numbers | read `Game.tuning.f(key)`; never `has_gear` | review; `Tuning.f` asserts unknown keys |
| Room swaps | deferred; through `World`; backstop banks the chain | `smoke_rooms.gd`, bot |
| Spawning | legend table or `room.spawn()`; the room owns runtime nodes | review |
| FSMs | `enum State` + `match` + `_enter()`; public `state` | review |
| State writes | rule methods that emit signals; same instances all session | review; unit tests |
| Guarantees | thresholds from `tests/spec.gd` (preloaded, not `class_name`) with GDD citations | test suite; GDD-first rule |
| Per-life objects | rebind on `world.player_spawned`; never hold an old player | review; smoke test (HUD after a death) |
| Strings | `tr("UPPER_SNAKE_KEY")`; key exists in `strings.csv` | string-key test |
| Logging | `Log.<level>(Log.CATEGORY, …)`; no `print(` | `test_lint.gd` |
| Freeing | `queue_free()` only | `test_lint.gd` |
| Platform branches | `OS.has_feature("web")` only in the five named places | review |

## Architecture Validation

### Validation Summary

| Check | Result | Notes |
|---|---|---|
| Decision Compatibility | PASS | Clock timer flags made pause-aware (V1); cache ownership and lint file name fixed earlier |
| GDD Coverage | PASS | 22/22 systems after adding lurker stirring (V2); phase-2 respawn route (E6) and Weaver flee target (E2) deferred to their epics as GDD open questions |
| Pattern Completeness | PASS | creation, communication, state, errors, data access, events; API/auth not applicable (offline single-player) |
| Epic Mapping | PASS | E1–E7 each map to locations and patterns |
| Document Completeness | PASS | no placeholders; Godot 4.7.2 verified 2026-11-11; Playwright and Fusion Pixel Font pinned at setup with the reason recorded |

### Coverage Report

**Systems Covered:** 22/22
**Patterns Defined:** 5 novel + 4 standard + 15 consistency rules
**Decisions Made:** 18 (6 ADRs)

### Issues Resolved

- V1 Clock timers: `create_timer(t, false, false, true)`; `Clock` is a Node child of `Game`.
- V2 Lurker off-screen stirring added to Light-as-Signal (`Sensing.can_stir()`, `stir` level, edge cue, guarantee test).
- V3 NPC dialogue data (`rules/dialogue.gd`) and economy data (`rules/economy.gd`) given homes.
- V4 Display scaling given a home (`core/display.gd`).
- V5 Perf scene moved to `rooms/dev/` (debug presets only) so it runs in web debug builds.
- V6 Spine width clarified: 22 columns including walls.
- Earlier steps: Ember Cache moved to `SlotState`; `Game.tuning` added; lint test renamed to match the test glob.

### Follow-ups Outside This Document

- **project-context.md:** replace the [M1] rules this architecture supersedes (flat scripts, `@export` tuning on actors, statics + scene reload on death, F-key hotkeys, hand-kept test list).
- **GDD:** exit crossing banks the chain; retargeting onto the player needs a fresh telegraph; cache glow ≥ 80 px to wake lurkers; spine width wording; open question on a cap for simultaneous flares.

### Validation Date

2026-11-11
