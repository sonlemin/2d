---
project_name: 'pixel_art_game'
user_name: 'sonlm'
date: '2026-11-11'
sections_completed:
  ['technology_stack', 'engine_rules', 'performance_rules', 'organization_rules', 'testing_rules', 'platform_rules', 'anti_patterns']
status: 'complete'
rule_count: 53
optimized_for_llm: true
existing_patterns_found: 14
---

# Project Context for AI Agents

_This file contains critical rules and patterns that AI agents must follow when implementing game code in this project. Focus on unobvious details that agents might otherwise miss._

---

## Technology Stack & Versions

- **Godot 4.7.2 stable**, GDScript only (no C#/GDExtension). Project root is `game/`. Export templates must match 4.7.2.
- **Renderer: GL Compatibility** (required for web). Use only features Compatibility supports; check the docs before using any rendering feature.
- **Display:** 480×270 viewport, integer scaling only, nearest filter, `snap_2d_transforms_to_pixel`. Physics at the default **60 ticks/s**; all tuning assumes it.
- **No addons, autoloads or `.tres` yet.** Tilesets/materials are built in code. Ask before adding an addon.
- **Tests:** headless `SceneTree` scripts (no GUT/gdUnit). **Art:** Python 3 + Pillow 12, `tools/build_sprites.py`.
- **UI font (M2):** Fusion Pixel Font 8px (OFL 1.1), size 8, antialiasing/hinting off.

## Critical Implementation Rules

### Scope: M1 scaffolding vs M2

- Rules tagged **[M1]** describe prototype scaffolding. Follow them when touching M1 code; **don't extend an M1 pattern into a new M2 system** (saves, rooms/levels, HUD, health, economy) before the architecture doc decides it. Ask.

### Engine-Specific Rules

- **Hitstop sets `Engine.time_scale` to 0.05 for 75 ms.** Timers that must run through it use `create_timer(t, true, false, true)`; real-time visuals use `delta / Engine.time_scale` in `_process`. Restore `time_scale = 1.0` on death and in `_exit_tree`.
- **Input during hitstop must not be lost** (GDD). Buffer gameplay presses (like the jump buffer) rather than relying on `is_action_just_pressed` alone; cover with a smoke test.
- **Gameplay movement lives in `_physics_process`**; `_process` is for visuals only.
- **[M1] Death reloads the scene.** Per-life state lives on nodes; state that survives death is a `static var` on `shaft.gd`. Statics persist across tests in one process: reset them.
- **[M1] Reload only if `get_tree().current_scene == self`** (test harnesses add the shaft by hand).
- **`ChainState` stays node-free** (`RefCounted`); rule changes go there with unit tests. Actors find each other by **group** (`player`, `enemy`, `predator`) and duck typing (`take_hit()`), never by node paths.
- **A predator kills only while `monitorable == true`** (lurker: HUNT and sensing). Never add a kill path around this: "Snuff/land/cling in time always saves you" is a design guarantee covered by tests.
- **Crawler contact is polled** (`get_overlapping_bodies`), not `body_entered`.
- **Physics layers:** 1 world · 2 player · 3 (value 4) enemies/pogo-able · 4 (value 8) predators. Slash/Pogo mask 4, Hurtbox mask 12.
- **Things that must read in the dark** use `LIGHT_MODE_UNSHADED`.

### Performance Rules

- **Target: 60 FPS on an Intel HD 620-class iGPU and in desktop browser web builds.** Profile on the weakest target, not the dev laptop. Memory/load/download budgets: GDD → Technical Specifications.
- **Lights are the cost centre.** Keep `PointLight2D` count on screen small; prefer unshaded sprites; no `LightOccluder2D` shadows without profiling. Reuse `art/light.png` via `texture_scale`.
- **Cache materials and shared resources as statics.** Never build a new `Material` per effect (current `Fx._unshaded()` does: fix when touched). Warm up new effects/shaders at scene load to avoid first-use hitches.
- **Code-built FX free themselves** (`finished` → `queue_free`, tween callback → `queue_free`).
- **Use `CPUParticles2D`**, not GPU particles (web/Compatibility).
- **No `Thread`/`WorkerThreadPool` in gameplay** (single-threaded web export).

### Code Organization Rules

- **Layout:** scripts flat in `game/scripts/` (snake_case file + PascalCase `class_name`); scenes in `game/scenes/` (enemies in `scenes/enemies/`). Scenes are thin prefabs; behaviour lives in scripts.
- **Tuning is data in code:** `@export` on actors, `const` in `ChainState`/`Shaft`, each with a `##` comment giving unit and intent (keep the "was X" history). **Change a tuning value → update the matching GDD table.**
- **Comments explain *why*, citing the design** ("Pillar 2: …", "playtest: …", "spec: ≥ 0.75 s"), never restate *what*.
- **Sprites:** source is `tools/sprites/*.txt` + `palette_edge.txt`; `game/art/*.png` is build output. Never hand-edit or hand-create sprite PNGs: edit the grid, run `python3 tools/build_sprites.py` from the repo root, re-import. `L` (#ffd27a) is constant across palettes.
- **If the pipeline doesn't support an asset type** (animation frames/sheets, UI icons), **stop and ask**; don't bypass or quietly fork it. Fonts and audio are external licensed files.
- **Commit `.gd.uid` and `.png.import`** with their sources.
- **[M1] Level:** `LAYOUT` in `shaft.gd`, 1 char = 16 px tile, equal-width rows.
- **Design source of truth:** GDD v1.0 + UX `DESIGN.md`/`EXPERIENCE.md` (`_bmad-output/planning-artifacts/`). M1 playtest findings supersede the brief on controls, cling and embers.

### Testing Rules

- **Before calling a change done: `cd game && ./run_tests.sh` → `== ALL GREEN`.** New test files **must be added to the `for t in …` loop in `run_tests.sh`**, or they never run (false green).
- **Headless tests can't judge feel.** Report "tests green; needs a feel check on the laptop", never "feels better". The user plays builds on the laptop; the server is headless.
- **Pure rules → `tests/run_tests.gd`** (add `test_*`, list it in `_init()`, preload the script rather than rely on `class_name`). **Level behaviour → `tests/smoke_shaft.gd`** (async, `Input.action_press/release`, `place()`, `frames()`/`seconds()` in physics frames).
- **Keep the output format:** `ok …` / `FAIL …` lines + final `PASS`/`FAILED`; the runner greps them.
- **Smoke tests share one shaft:** restore what you change (`chain.break_chain()`, `set_lurkers_active(true)`, `set_physics_process(true)`), use a fresh shaft after the player dies, reset statics you touch.
- **Pick test targets by position/sort order** (like `_hovers()`), not `get_nodes_in_group(...)[i]`; group order follows `LAYOUT` order. The existing `predator[0]`/`[1]` uses are fragile: fix them when you touch them.
- **Design guarantees are tests** (telegraph ≥ 0.75 s, no off-screen notice, base light never noticed, Snuff in time saves, tap never Snuffs, bot chains ≥ 5). **Never loosen a threshold to pass;** change the GDD first, with the user.
- **Screenshots** need a renderer: `xvfb-run -a godot --path game --rendering-driver opengl3 --script res://tests/screenshot.gd -- <out>`.

### Platform & Build Rules

- **Targets:** Windows, Linux, web/itch.io (960×540 ×2); Steam Deck legibility at ×2. Branch with `OS.has_feature("web")`.
- **Input only through actions** (physical keycodes), one button per action, no chords. Keyboard + gamepad from M2; rebinding in E7, so never hard-code key names in UI text.
- **No function keys or raw keycodes** for gameplay or settings (browsers take F1/F3/F5/F11). **[M1]** F1–F3 debug hotkeys are dev-only and will be removed.
- **Pause:** Esc *or* P; also on focus loss and gamepad disconnect.
- **Web:** single-threaded export; no audio before the click-to-play gate.
- **Requirements owned by the architecture** (see UX `EXPERIENCE.md` notes): 3 save slots in `user://` with visible save failure; integer scale from physical pixels; font licence (`OFL.txt` + `LICENSES/`) in every build.
- **Accessibility:** ≤ 3 flashes/s anywhere (pulses ≤ 2 Hz, blinks 2.5 Hz). **Route all flashing, shaking, pulsing and easing through one place** (`Fx`, camera shake, invuln blink) so reduce-flashing / shake-off / reduced-motion settings can gate them with one switch. Don't add per-effect toggles.

### Critical Don't-Miss Rules

- **No randomness in level behaviour** (hover phase comes from position; `randf` only for camera shake).
- **`tests/run_tests.gd` is the spec for chain edge cases** (landing-frame pogo, snuffed hits, cap still pays, cling pause/grace, bank vs lose). Read it before changing `ChainState`.
- **Light key:** hold ≥ `snuff_hold` (0.12 s) = Snuff; a tap must never break the chain (tap is reserved for Flare Toss).
- **[M1] The HUD is a debug label.** Build real UI from UX `DESIGN.md`; don't extend the label.
- **[M1] Shaft is 30 tiles (480 px).** M2 view is ~360 px between gutters; spine shafts are 22 tiles. Don't build new content at 480 px.
- **M1 → M2 vocabulary:** M1 "banked" ≈ M2 "carried"; M2 adds "deposited". M2 replaces one-touch lurker death with HP (lurker = 2). Check the GDD before reusing M1 behaviour.
- **Don't add mechanics from `deferred-work.md` unprompted;** each is its own experiment.

---

## Usage Guidelines

**For AI Agents:**

- Read this file before implementing any game code; follow every rule as written.
- When in doubt, prefer the more restrictive option, and ask before extending an [M1] pattern.
- Propose an update to this file when a new pattern emerges.

**For Humans:**

- Keep it lean: only rules agents would otherwise get wrong.
- Update after the game architecture lands (replace [M1] rules with the decided M2 ones) and when the stack changes.
- Remove rules that become obvious or obsolete.

Last Updated: 2026-11-11
