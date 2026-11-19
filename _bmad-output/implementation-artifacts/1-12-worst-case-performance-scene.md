# Story 1.12: Worst-case performance scene

Status: ready-for-dev

**Type:** dev · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP1 Foundations (1.1–1.15) · **Branch:** `feat/m2-e1`

## Story

As the developer,
I want the heaviest Layer 1 situation measured early on my weakest targets,
so that the light budget and bloom are decided on data before any art depends on them.

## Acceptance Criteria

1. **`rooms/dev/perf_worst.txt` is the Old Mine at its worst.**
   - 30 × 68 cells (480 px wide, four screens tall), `zone=violet`, not a spine room, no exits.
   - At least 1 lurker per screen, and 4 on the first screen. Every lurker sits in a wall stub inside the play rect, so it can wake.
   - Hoverer rows of 4 every 3–7 rows (8 hoverers on screen 1 and 12 on each later screen), and walkers on side ledges.
   - The centre corridor (columns 13–16) is open from row 1 to row 66. This is the perf run's path.
   - Placeholder art only: the existing sprites, no new PNG.
   - It validates. `smoke_rooms` validates it as a dev room, never sweeping or botting it. `--room=perf_worst` starts there, at its `P`.
   - The epic's "the player at chain 20" and its stand-ins come with `--perf` (AC7). `--room=perf_worst` alone is the plain room, at chain 0 with no stand-ins. 1.13's Playwright boot with `?room=perf_worst` should expect only the room.
   - It runs in the editor and in a desktop debug export. Check that export from a scratch preset outside the repo, and never commit the preset. Its web debug run and its exclusion from release presets arrive with 1.13's presets.

   (AR5, AR26; D9, D15)
2. **Every `PointLight2D` is a `BudgetLight` that shares `art/light.png`.**
   - `scripts/core/budget_light.gd` declares `class_name BudgetLight extends PointLight2D`, in group `budget_light`, with `rank` ALWAYS, CACHE or GLOW.
   - The player's `Light` is ALWAYS. The lurker's `Glow` is GLOW.
   - Size comes from `texture_scale` only.
   - A test reads every `res://scenes/**/*.tscn` through `SceneState`, without instancing. It fails on any `PointLight2D` that is not a `BudgetLight` or does not use `light.png`.
   - The lint's new `raw_light` rule fails on `PointLight2D.new(` or `extends PointLight2D` in `scripts/` outside `core/budget_light.gd`.
   - Small glows stay unshaded sprites: the lurker's eyes and the ledge rims. This is already true; the test checks the eyes' material.

   (AR46; D3, D11)
3. **At most 6 lights stay lit on screen. Lurker glows fall back first; the player's and flares' lights never do.**
   - World's `LightBudget` child applies the budget on every physics tick, after every actor has moved and set its light (priority 50). So a glow that wakes on a tick is never drawn lit past the budget, not even for one frame.
   - A light *wants* light when it is shown, has energy above 0 and has a texture. On-screen lights that want light keep their `PointLight2D` up to `BudgetLight.MAX_ON_SCREEN`, which is 6, equal to the new `Spec.LIGHTS_ON_SCREEN_MAX`. Slots go in this order:
     - ALWAYS lights first. They are never demoted, even past the budget; that excess is reported as `over`.
     - then CACHE;
     - then GLOW.
   - Within a rank, a light that is already lit keeps its slot (so nothing flickers), then the light nearest the centre of the rect wins.
   - A demoted light's `PointLight2D` is disabled. Its own additive, unshaded sprite shows instead, with the same texture, colour and size. The sprite's alpha follows the light's energy.
   - Off-screen lights are left as they are.
   - Tests:
     - **8 light sources on screen** (the player, 2 flares, a cache and 4 lurker glows): 6 stay lit, the 2 lurker glows farthest from the centre show sprites, and the player's and flares' lights never change.
     - **The player and 6 flares, plus a glow:** all 7 always-lights stay lit, over the budget, and the glow still drops.
     - **Jitter:** no light changes state more than once while nothing enters, leaves or changes rank (≤ 3 flashes/s).

   (AR46, NFR8; D3, D4)
4. **"On screen" for the budget is the whole 480 × 270 view, gutters included, as one rule in game code** (D2, decided by sonlm on 2026-11-19).
   - `World.light_rect()` is the rect the budget counts. It returns `CameraRig.view_rect()`.
   - Overlay 4's light count and the perf run's stats call `BudgetLight.counts()` with that same rect. So the overlay shows exactly what the budget counts. This closes ledger item 2 from 1.11.
   - AR20's "on screen" stays `play_rect()`: notice, stir, edge cues and the guarantees.

   (AR20, AR46; D2, D5)
5. **`Fx` builds each material once.**
   - `Fx.unshaded()` and `Fx.additive()` return cached statics.
   - `pop()` and `popup()` use `unshaded()`. `BudgetLight`'s sprites use `additive()`.
   - M1's per-effect `_unshaded()` is gone.

   (AR46; D6)
6. **`--glow=on|off` switches engine glow, in debug builds only.**
   - The arg also works as `?glow=on` on a web debug build. It is one new DevTools row.
   - `on` adds a `WorldEnvironment` under DevTools, with a code-built `Environment`: `BG_CANVAS`, glow on, the D7 values.
   - `off`, or no arg, adds none. Anything else gives a warning.
   - Game code gets no glow until 1.15's verdict.

   (AR5, AR54; D7)
7. **`--perf[=<s>]` runs a timed, repeatable perf run that holds the chain** (D1, decided by sonlm on 2026-11-19: the autopilot).
   - The default length is 60 s; `<s>` may be 1–600. It is one new DevTools row, and works as `?perf` on web.
   - **On every spawn**, the run takes the player:
     - its input is locked;
     - its hurtbox is masked off, so no hit, kill or knock can break the chain;
     - it is held at `--chain`'s n, or at `ChainState.MAX_CHAIN` (20) without `--chain`, paid through 1.11's take-off arming;
     - it is moved every physics tick along a fixed vertical ping-pong down the room's centre, starting from the tick counter, never the wall clock.
   - **Two stand-in `BudgetLight`s ride along, children of the room:**
     - a flare: ALWAYS, at the player's light radius (FR15);
     - an Ember Cache: CACHE, 80 px (FR24).
   - **What it measures:** the wall-clock time between frames (`Time.get_ticks_usec()`, never `delta`). It also samples `BudgetLight.counts()` every tick.
   - **At the end** it freezes one summary, logs it once (`[room] dev: perf …`) and shows it in overlay 4. The summary holds:
     - frames; average and minimum FPS;
     - the worst frame and when it happened;
     - the number of frames over 20 ms;
     - the most lights lit, the most sprites and the most `over`;
     - chain breaks and deaths, both expected 0;
     - the glow setting, the window size and the GPU adapter.
   - This closes ledger item 1 from 1.11.

   (AR5, NFR1, NFR5; D1, D8)
8. **Overlay 4 reads the budget and frame times.** Its rows, in order:
   - `FPS`;
   - `lights n/6`, then `, sprites m`, then `, over k` when k > 0;
   - `frame x.x ms, worst y.y ms`, measured since mode 4 opened, in wall time;
   - the perf run's progress, then its summary once it is done;
   - the Clock rows, as before.

   It still rebuilds at 4 Hz, and nothing blinks. (AR54, NFR8; D8)
9. **`docs/perf.md` holds the measurement procedure, ready to run.** It covers:
   - a 60 s `--perf` run at ×3 on the laptop;
   - the same run at the ×2 embed in desktop Chrome and Firefox (from 1.13's debug web build);
   - each run with glow off and on;
   - an HD 620-class machine if one is available; if not, the gap is recorded;
   - what to record, how to read it, and the look check with glow on;
   - an empty results table.

   The agent records **no numbers**. sonlm takes the measurements in Story 1.15: a human gate, since the server is headless. (NFR1, NFR5; D10)
10. **Play is unchanged unless the new args are given.**
    - Without `--glow` or `--perf`, there is no `WorldEnvironment` and no PerfRun.
    - In `m1_shaft` the budget never demotes anything: at most 5 lights want light there, the player's plus 4 lurker glows.
    - Every existing test stays green. The only edits to them are the ones D12 lists for `smoke_dev_tools`, `test_dev_args` and `test_lint`: the moved light rule, the new arg rows and the new lint rule.

    (D12)
11. **Done means green.**
    - `cd game && ./run_tests.sh` ends in `== ALL GREEN (20 tests)`: the 17 existing tests plus `test_fx`, `test_light_budget` and `smoke_perf`.
    - Every new check is red-checked (D14).
    - The desktop debug export check is recorded (D15).
    - The docs, `project-context.md`, the architecture and the ledger say how the budget and the perf run work (D13).
    - Game code changes outside `scripts/dev/` only in these places:
      - `core/budget_light.gd` (new) and `core/fx.gd`;
      - `world/world.gd` (`light_rect()` and adding the `LightBudget` node), `world/light_budget.gd` (new) and `world/camera_rig.gd` (`view_rect()`);
      - `scenes/actors/player.tscn` and `lurker.tscn` (the script and the rank);
      - the new room `rooms/dev/perf_worst.txt`.

## Tasks / Subtasks

- [ ] **Task 1: Baseline (AC: 11).** `cd game && ./run_tests.sh` gives `== ALL GREEN (17 tests)`, 1086 `ok`. The per-test counts are under "Previous story intelligence". The engine facts this story relies on are already probed (see "Verified facts").
- [ ] **Task 2: `Fx` materials (AC: 5).** `Fx.unshaded()` and `Fx.additive()` (D6), plus the new `tests/test_fx.gd`.
- [ ] **Task 3: `BudgetLight` (AC: 2, 3).**
  - Write `scripts/core/budget_light.gd` (D3, D4) and add `Spec.LIGHTS_ON_SCREEN_MAX` (D11).
  - In `player.tscn`, `Light` gets the script with `rank = 0` (ALWAYS). In `lurker.tscn`, `Glow` gets the script with GLOW, the default.
  - Write the new `tests/test_light_budget.gd` (D12).
- [ ] **Task 4: World runs the budget (AC: 3, 4).**
  - Add `CameraRig.view_rect()`, and `World.light_rect()` returning it.
  - Write `scripts/world/light_budget.gd` (no `class_name`). `World._ready()` adds it as a child named `LightBudget`, with physics priority 50 (D2, D5).
- [ ] **Task 5: The lint (AC: 2).** Add the `raw_light` row, its samples, and the docs table row (D11).
- [ ] **Task 6: `rooms/dev/perf_worst.txt` (AC: 1).** Start from the validated D9 grid, and keep its properties if you change it.
- [ ] **Task 7: DevTools (AC: 6–8).**
  - Add the `glow` and `perf` rows with their pure validators (D7, D1).
  - Write `scripts/dev/perf_run.gd`, with no `class_name` (D1, D8).
  - Point overlay 4 at the budget and add its new rows (D8).
- [ ] **Task 8: Tests (AC: 1–8, 10).**
  - Write the new `tests/smoke_perf.gd`.
  - Edit `test_dev_args`, `smoke_dev_tools` and `test_lint` as D12 says.
- [ ] **Task 9: Docs and ledger (AC: 9, 11).** Write `docs/perf.md` (D10) and every doc D13 lists. Close ledger items 1 and 2, and add the four new items, each with its owner line.
- [ ] **Task 10: Verify (AC: 11).**
  - `./run_tests.sh` gives `== ALL GREEN (20 tests)`, with no `ERROR:` lines. Also grep the raw output for any `ERROR:` printed after the runner exits.
  - Run the D14 red checks, each in a scratch copy of `game/` with its own `config/name`, as 1.11 did. Record each one with its failing line.
  - Do the D15 desktop debug export check and record its summary line.
  - Take xvfb screenshots of `perf_worst` mid-run, with glow off and on, and with overlay 4 shown. Use a scratch script outside the repo, run by its absolute path through the runner (1.11 Task 8 pattern). Look at each and record what you see: sprite glows next to lit ones, and the glow halo. Never commit the script, and never put it under `tests/`.
  - Stage every new `.gd` with its `.gd.uid`, and the room file.
  - Report: "tests green; needs a 5-minute look on the laptop". The look:
    - Run `godot --path game -- --room=perf_worst --perf=20`, then the same with `--glow=on`.
    - Cycle the overlays to mode 4 with the backquote key.
    - Watch the lurker glows turn into sprites past 6 lights, and read the summary.
    - The measurements themselves are 1.15's.

## Dev Notes

### What this story is (and isn't)

It is the measuring kit that CP1's performance verdict (Story 1.15) runs. It has four parts:
- a worst-case room;
- the ≤ 6 light budget, enforced in game code;
- an engine-glow switch;
- a repeatable, timed perf run with a summary.

The only change to how the game plays or looks is the budget. It demotes lurker glows to sprite glows only when more than 6 lights want light on screen at once, which never happens in `m1_shaft`. Everything else is debug-only: it lives in `dev/`, behind `--glow` and `--perf`.

**Not in this story:**
- **Taking or recording any measurement.** That is Story 1.15, sonlm on the laptop: a human gate. The agent never writes an FPS number into a doc.
- **Export presets, web templates, the release exclusion of `rooms/dev/*`, `SMOKE boot ok` and Playwright `?room=perf_worst`:** Story 1.13. D15 checks the desktop debug export from a scratch preset only.
- **Integer scaling and the ×2 web embed:** Story 1.14. `docs/perf.md`'s web runs need 1.13 and 1.14. 1.15 runs after both.
- **Engine glow in game code, or as a setting:** only if 1.15 says go. Then the follow-up story it creates moves it out of `dev/` (ledger item D13-4).
- **Effect warm-up at room load, flash-rate declarations and the reduce-flashing variants:** Story 1.16. Its AC owns warm-up, and `test_fx.gd`, created here, grows there.
- **`LightSource`, `rules/sensing.gd` and sensing by stand-ins:** Story 1.20. The perf run's stand-ins are lights only; they wake no lurker. Ledger item D13-1.
- **The real Ember Cache and real flares:** Stories 1.22 and 1.23. Each must build its light as a `BudgetLight` of the right rank (ledger items D13-2 and D13-3). 1.23's AC already says "each flare keeps its `PointLight2D`, the overlay counts it".
- **A flare cap:** 1.15 recommends one, and 1.23 makes it a `Tuning` value if it was recommended.
- **No `ChainState` change and no pinned chain.** The perf run holds the chain by never letting it break, never by a rules hook (1.11 D6: "never pins the chain").
- **No `lurker.gd` or `player.gd` change.** The budget works through the scene's `Glow` and `Light` nodes, which become `BudgetLight`s.

### Current state (read before changing)

- **`scripts/core/fx.gd`** (static, `class_name Fx`):
  - `_unshaded()` (`:7-10`) builds a new `CanvasItemMaterial` on every call.
  - `pop()` (`:14-33`, `CPUParticles2D`, frees itself on `finished`) and `popup()` (`:41-55`, a `Label` with a tween) each call it.
  - Callers: `player.gd` (`:235` chain popup, `:254` banked, `:325` lost) and `crawler.gd` `take_hit()` (`Fx.pop`). They pass the room as the parent (AR23).
  - It doesn't read the accessibility gate yet; that is Story 1.16.
- **`scenes/actors/player.tscn`:** node `Light` is a `PointLight2D`: `color` `(1, 0.8235, 0.4784)` (#ffd27a), `energy 1.4`, `texture light.png`, `texture_scale 0.625`, no script. Its `Slash`/`Sprite` and `Pogo`/`Sprite` use a scene-local unshaded sub-resource.
- **`scripts/actors/player.gd`:**
  - `@onready var _light: PointLight2D = $Light` (`:41`) keeps working, since a `BudgetLight` *is* a `PointLight2D`.
  - `_update_light()` (`:279-282`) sets `texture_scale = _shown_radius / LIGHT_TEXTURE_HALF` (64.0, `:18`).
  - `light_radius()` (`:59-60`) is the sensing radius, `chain.light_radius()`. At chain 20 it is 40 + 22·√20 ≈ 138.4 px.
  - The hurtbox is node `Hurtbox`, `collision_mask = 12`:
    - `area_entered` → `_on_hurt_area` → `die()` for a predator;
    - `_check_contact()` polls `_hurtbox.get_overlapping_bodies()` for crawlers and knocks the player back, which breaks the chain.
  - On a floor tick, `chain.break_chain()` runs every tick (`:74-80`).
- **`scenes/actors/lurker.tscn`:**
  - `Glow` is a `PointLight2D`: `position (0, -4)`, `color (1, 0.25, 0.2)`, `energy 0`, `texture light.png`, `texture_scale 0.8`.
  - `Eyes` is a `Sprite2D` with a scene-local unshaded material.
- **`scripts/actors/lurker.gd`:** `_update_look()` (`:116-118`) sets `_glow.energy = eye alpha × GLOW_ENERGY (1.3)` and `_glow.visible = energy > 0.01` on every physics tick. Idle glows are dark and hidden. Nothing sets `enabled`, so the budget owns it.
- **`scripts/world/world.gd`:**
  - `_physics_process()` (`:78`) returns early while a swap is pending or the player is dead. The budget must run before that return.
  - `play_rect()` (`:58`) delegates to the rig.
  - World is pausable and is the parent of the room, so it ticks **before** the room's actors (tree order, priority 0). A probe showed `physics_frame` firing before any node's physics. In `perf_worst` at chain 20, all four screen-1 glows went from 0 to lit within one tick, *after* World had run. That is why the budget can't live in `World._physics_process()` (D5).
  - `_ready()`'s first statement adds DevTools (1.11). The lint pins that it stays first.
- **`scripts/world/camera_rig.gd`:**
  - `play_rect()` (`:81-83`) is `PLAY_WIDTH` × view height around the rig's own `_centre`, never the engine camera (1.7 D8). `_view_size()` (`:116`) is 480 × 270.
  - `apply_limits()`: in a room wider than 360 px, the limits are bounds ± `GUTTER_WIDTH`. For a 480-wide room at x = 240, that puts the view at x 0–480 and the play rect at x 60–420.
- **`scripts/world/room_loader.gd`:** ledge rims are `ColorRect`s with one static unshaded `_rim_material` (`_rim()`, `:386-396`). That is already cached; leave it.
- **`scripts/dev/dev_tools.gd`:**
  - `ARGS` (`:20-25`) is `log`, `set`, `room`, `chain`, applied in that order by `_apply()` (`:241`).
  - `--chain` arms on every `player_spawned` (`_on_player_spawned`, `:316`). It pays n `add_hit()` calls in `_physics_process` (`:73`, priority 100) on the first tick the player ran that ends off the floor. It skips while paused and in the spawn frame.
  - The URL query becomes tokens, so `?glow=on&perf` works with no new code.
  - `real_tokens()` is gated on `current_scene == World`; tests inject `tokens` through World's `child_entered_tree` (1.11 D3).
- **`scripts/dev/overlays.gd`:**
  - `light_count` (`:34`) comes from `_count_lights()` (`:138`), which runs `world.find_children("*", "PointLight2D", true, false)` and filters with the static `counts_on_screen(light, rect)` (`:151`) against `world.play_rect()`.
  - `_rebuild_readout()` (`:104`) runs at 4 Hz: `FPS`, `lights n`, then the Clock rows.
  - Mode 4 is drawn in `_draw_screen()` (`:252`).
  - 1.11 D9: "Rows are a list, so 1.12 appends the worst frame".
- **`tests/smoke_dev_tools.gd` `test_lights` (`:606-641`):**
  - Calls `Overlays.counts_on_screen()` on plain `PointLight2D` stand-ins.
  - Expects `light_count == 1` at `m1_shaft`'s spawn.
  - Then adds two `_code_light()`s (plain `PointLight2D.new()`): one by the player, and one 30 px into the left gutter. It expects 2.
- **`tests/smoke_dev_tools.gd`, two more pins:**
  - `:206-207`, the no-token case, pins World's children (without the player) to exactly `["Darkness", "RoomHolder", "Camera", "UI", "DevTools"]`.
  - `:304`, `test_bad_args`, pins the warning text `unknown arg --foo (known: chain, log, room, set)`.
- **`tests/smoke_world.gd`:** `:164-170` pins only that World's child count is *unchanged* across a bank popup. A new World child built in `_ready` keeps that green.
- **`tests/test_dev_args.gd`:**
  - `:60` pins `unknown arg --foo (known: chain, log, room, set)`.
  - `:80` pins `ARGS.keys() == ["log", "set", "room", "chain"]`.
  - `:81` pins the `repeat` flags.
- **`tests/smoke_rooms.gd` / `tests/room_sweep.gd`:**
  - Files under `rooms/dev/` are validated ("validates clean (a dev room: validated only, never swept or botted)"), and they count for unique ids and `link_errors`.
  - `smoke_bot` plays only spine rooms outside `rooms/dev/`.
  - `smoke_rooms` prints two `ok` lines per valid file, dev rooms included: "validates clean" (`:93`), then `_check_record()`'s "the sweeps read the same exits and obj ids" (`:143`). So `perf_worst` takes `smoke_rooms` from 90 to 92 `ok`, and adds nothing to the bot.
- **`tests/spec.gd`:** each const needs a `## GDD …` citation; `test_lint` checks it.
- **`project.godot`:**
  - The renderer is `gl_compatibility`; `snap_2d_transforms_to_pixel` and physics interpolation are on.
  - The window override is 1440 × 810, so a desktop run opens at ×3.
  - `rendering/viewport/hdr_2d` is false, and there is no `WorldEnvironment` anywhere.
- **Source scans outside the lint:** `smoke_world.gd` scans raw text (comments included) for `randf` (only `camera_rig.gd` may hold it), `KEY_F` and `reload_current_scene`. Never write those strings in a new file, not even in a comment.

### Decisions

These are story-author decisions; sonlm can veto any before dev. D1 and D2 settle the two items 1.11 left to this story (ledger items 1 and 2). sonlm chose between options for both on 2026-11-19. Names in code sketches may change; record the final ones.

**D1 (decided by sonlm, 2026-11-19: the autopilot): The light stays at chain 20 through a `--perf` autopilot.**
- **The problem:** 1.11's `--chain` pays at take-off and ends on the first break. A 60 s run needs the chain-20 light for the whole run. It also needs to be **repeatable**, so that glow off/on, laptop, Chrome, Firefox and HD 620 can be compared.
- **The args:**
  - The row is `"perf": {help = "--perf[=<s>]: a timed perf run (default 60 s): the player locked on a fixed path, untouchable, holding --chain's n (default 20); the summary goes to the log and overlay 4", apply = &"_apply_perf", repeat = false}`.
  - Add it after a new `glow` row (D7), so `ARGS` is `log, set, room, chain, glow, perf`.
  - Pure validator `perf_seconds(text) -> [int, error]`: `""` gives 60. A whole number from 1 to 600 (≤ 4 characters, as `MAX_INT_CHARS`) is accepted. Anything else is an error, and no run starts.
  - The held chain is `--chain`'s n if a valid `--chain` was given (0–20), else `ChainState.MAX_CHAIN`.
  - `_chain` alone can't tell "no `--chain`" from `--chain=0` or a rejected `--chain=99`, since all three leave it at 0. So `_apply_chain` sets a new `_chain_given = true` only when it accepts a value.
  - When `_chain_given` is false, `_apply_perf` sets `_chain = ChainState.MAX_CHAIN` and connects `_on_player_spawned` itself, if it isn't connected yet. So the payment is exactly 1.11's take-off arming: no new pay path.
- **`scripts/dev/perf_run.gd`:**
  - It has no `class_name`. DevTools preloads it, as it does `overlays.gd` (`const PerfRun := preload("perf_run.gd")`), so `dev/` still adds one global name.
  - It is a `Node` child of DevTools, `name = "PerfRun"`, with `process_physics_priority = 100`. It inherits ALWAYS.
  - DevTools and PerfRun have the same priority, so tree order runs DevTools first: DevTools pays the chain on a tick, then PerfRun moves the player.
  - It connects its own method to `world.player_spawned`; never use a lambda.
  - DevTools keeps it as `perf` (null without `--perf`) and hands it to the overlays (`overlays.perf`).
- **On every `player_spawned`, PerfRun takes the player:**
  1. `player.input.lock()` (Story 1.8).
  2. `player.get_node(^"Hurtbox").collision_mask = 0`. This makes the player untouchable, so no predator kill and no crawler knock can break the chain.
     - Don't set `monitoring = false`: `get_overlapping_bodies()` then prints an engine `ERROR:`.
     - `dev/` may touch anything. `smoke_perf` pins this line, so a renamed node fails a named check.
  3. Teleport the player to the path start, then call `reset_physics_interpolation()` (AR6), then the rig's `snap()` (`get_viewport().get_camera_2d() as CameraRig`).
     - World snapped the rig to `P` before it emitted `player_spawned`. Without a second snap, the rig would slide about 60 px for about 0.5 s inside the measured window.
  4. Build the stand-ins (below).
  5. Count a death for every `player_spawned` after the first.
- **The path:**
  - Run it each physics tick, after the player and DevTools. Skip it while `get_tree().paused`, and in the spawn frame (`Engine.get_physics_frames() <= spawn_frame`), as DevTools does.
  - `x` is the room's centre: `room.bounds().get_center().x`, which is 240 in `perf_worst`.
  - `y` ping-pongs between `top = 3 × TILE` and `bottom = bounds.end.y − 3 × TILE` at `PATH_SPEED` (100 px/s), starting downward.
  - Set `player.global_position = Vector2(x, y)` and `player.velocity = Vector2(0, ±PATH_SPEED)`. The camera reads that velocity, so it leads on the way down, as in a real dive.
  - Drive it from a **tick counter** (ticks the player has run), never wall time, so every run sees the same states in the same order.
  - It is a pure static: `path_point(tick, top, bottom, speed, tps) -> Vector2(y, vy)`.
  - In `perf_worst`, one pass is 992 px, about 9.9 s, so a 60 s run makes about six passes.
- **Path check:** at the first placement, test the cells under the player's body columns from `top` to `bottom` with `room.is_solid()`. If any is solid, warn once: `--perf: room 'x' blocks the path at row r; the chain will break there`. The run still goes ahead, and the summary's `breaks` shows the damage. In `m1_shaft`, row 100's middle ledge blocks it, which is fine: `docs/perf.md` uses `perf_worst`.
- **Why the chain never breaks:** the path never touches a floor (no landing), the hurtbox is masked (no knock), the input is locked (no Snuff, no cling) and the path stays inside the room (no exit). So the light holds at chain n for the whole run. `breaks` counts `player.chain.banked` emissions after the run starts, and should be 0.
- **The stand-ins:**
  - Two `BudgetLight.new()`, built in code. Set `rank`, `texture`, `color`, `energy` and `texture_scale` **before** `add_child`: `_ready()` builds the fallback sprite from them. They are children of `world.current_room()`: the room owns them (AR23) and frees them on a rebuild, and the next `player_spawned` builds new ones.
  - Texture, `color` and `energy` are copied from the player's `Light` at spawn (`player.get_node(^"Light")`), never typed in.
  - `texture_scale = radius / (texture.get_width() / 2.0)`.
  - **flare:** ALWAYS. Its radius is `player.light_radius()`, re-read every tick: FR15's flare burns at the pre-toss radius, 138.4 px at chain 20.
  - **cache:** CACHE. Its radius is 80 px (`CACHE_RADIUS`): FR24's floor, and 1.22's starting value.
  - Each tick they ride at fixed offsets from the player, `FLARE_OFFSET` (−112, −32) and `CACHE_OFFSET` (+112, +40), clamped one tile inside the room. Call `reset_physics_interpolation()` on their first placement.
  - Real flares stick and caches lie still. Riding along keeps both on screen for the whole run, which is the worst case the budget must hold. Write that in `docs/perf.md`.
  - They wake no lurker: there is no `LightSource` until 1.20.
  - Expose them for tests as `stand_ins`, flare first.
- **The measurement:**
  - It starts on the first physics tick that ends with the player's `chain.count == n`, in the frame after that tick. Before that, the room build and the first frames are not measured; the camera is already snapped (step 3).
  - The first demotion is also the additive material's first use, which can hitch, and it happens inside the measured window. Warm-up is 1.16's job. `docs/perf.md` warns that a worst frame in the first second may be that hitch.
  - Then each `_process` frame records `dt = now − last` from `Time.get_ticks_usec()`. Never `delta`, which `Engine.time_scale` scales (a hitstop would make it look fast).
  - At `elapsed ≥ seconds` it builds the summary: `done = true`, `result = {…}`. It logs `Log.info(Log.ROOM, "dev: " + summary_text(result))` once.
  - The autopilot keeps going after that, so the scene stays under the same load while sonlm reads the summary.
- **The pure stats functions** (tested in `test_dev_args`):
  - `new_stats(seconds) -> Dictionary`: counters plus a `PackedInt32Array` of per-second buckets. No per-frame arrays, because a headless run makes thousands of frames.
  - `add_frame(stats, dt_usec, at_usec)`, where `at_usec` is the frame's **start**, counted from the run's start (the previous frame's end):
    - frames += 1, and add `dt_usec` to the sum;
    - track the worst `dt_usec` and its `at`;
    - `slow += 1` when `dt_usec > SLOW_FRAME_USEC` (20 000, NFR1: "no frame over 20 ms");
    - `buckets[at_usec / 1_000_000] += 1` when the bucket is inside the run.
    - Because frames are counted by their start, 60 frames of 16 667 µs all land in bucket 0. The run ends at the first frame whose end is ≥ `seconds`, so buckets `0 … seconds − 1` are whole seconds.
  - `summary(stats) -> Dictionary`:
    - `frames`;
    - `avg_fps = frames / elapsed`;
    - `min_fps` = the fewest frames in any whole second (buckets `0 … seconds − 1`);
    - `worst_ms`, `worst_at_s`;
    - `slow_frames`.
- **Every physics tick during the run,** PerfRun samples `BudgetLight.counts(get_tree().get_nodes_in_group(BudgetLight.GROUP), world.light_rect())` and keeps `max_lit`, `max_sprites` and `max_over`.
- **`summary_text(result) -> String`, one line:**

  `perf 60 s: 3598 frames, avg 59.9 fps, min 58 fps, worst 21.4 ms at 12.3 s, 2 over 20 ms; lights max 6/6, sprites max 5, over 0; chain 20, breaks 0, deaths 0; glow off; window 1440x810; Linux, <adapter>`

  The window is `get_window().size`. The adapter is `RenderingServer.get_video_adapter_name()`, and the OS is `OS.get_name()`.
- **The options sonlm weighed:**
  - **A, this autopilot (chosen):** repeatable across machines and browsers, with one summary per run. It needs the most code, about 150 lines in `dev/`.
  - **B, `--hold` and play by hand:** `--chain=20` is re-paid at every take-off and sonlm plays for 60 s. The light is 40 px while standing, and the numbers change from run to run.
  - **C, a camera tour with stand-ins only:** no live player, and the camera pans down. It is repeatable, but no lurker wakes from the real player and no player light moves.

**D2 (decided by sonlm, 2026-11-19: the whole view): what the budget counts as on screen.**
- **The view (chosen):**
  - `CameraRig.view_rect()` is `Rect2(_centre − _view_size() / 2, _view_size())`: the whole 480 × 270 view around the rig's own centre, gutters included, without the shake offset (≤ 2.5 px).
  - Like `play_rect()`, it never reads the engine camera (1.7 D8).
  - `World.light_rect()` returns it.
  - Why the view: the budget is a **cost** rule. The engine draws and culls lights against the whole viewport, and a light under an opaque gutter still costs a lit pass.
  - AR20's "on screen" is a **fairness** rule (notice, stir, edge cues) and stays `play_rect()`. Record the distinction in the architecture's Lighting section, the "Visible play rect" bullet, and in `project-context.md`.
- **The play rect (not chosen):** `World.light_rect()` would have returned `play_rect()`. It keeps AR20's word, but it under-counts what renders beneath the gutters.
- **Where it matters:** in spine rooms (352 px wide) both give the same count, because nothing lit lies wholly under a gutter. They differ in rooms wider than 360 px: `perf_worst`, the Weaver arena (E2) and the hub (E5).
- **The 1.11 smoke case changes:** "a code-built light 30 px into the gutter doesn't count: 2" becomes "counts: 3", plus a new light wholly outside the view (centred 300 px left of the view's centre) that doesn't.

**D3: `BudgetLight` (`scripts/core/budget_light.gd`).**
```gdscript
class_name BudgetLight
extends PointLight2D
## Every PointLight2D in the game (AR46, Story 1.12): lights × lit canvas items is the cost at
## 480×270, so at most MAX_ON_SCREEN keep their PointLight2D on screen; World demotes the rest to
## an additive sprite glow each physics tick. The player and flares are never demoted (ALWAYS).

enum Rank { ALWAYS, CACHE, GLOW }  ## slots go in this order; GLOW (lurker wall glow) is demoted first
const GROUP := &"budget_light"
const MAX_ON_SCREEN := 6  ## AR46 budget, until the CP1 perf verdict (1.15) confirms or tightens it; the guarantee is Spec.LIGHTS_ON_SCREEN_MAX
const SPRITE_ALPHA := 0.35  ## additive sprite alpha per unit of energy: about a dark wall's share of the light it replaces; presentation, judged by eye in 1.15

@export var rank := Rank.GLOW  ## a light that forgets its rank is demoted first, never kept over budget
var demoted := false  ## read-only outside; set through set_demoted()
```
- **`_ready()`:**
  - `add_to_group(GROUP)`.
  - If `rank != ALWAYS`, build the fallback: a `Sprite2D` child named `"Fallback"`, with `texture = texture`, `material = Fx.additive()`, `position = offset` and `visible = false`.
  - ALWAYS lights get no sprite.
- **`wants_light() -> bool`:** `is_visible_in_tree() and energy > 0.0 and texture != null`. It doesn't check `enabled`, which the budget owns.
- **`set_demoted(on)`:**
  - `assert(not on or rank != Rank.ALWAYS)`;
  - `demoted = on`; `enabled = not on`; then sync the sprite at once.
  - Only the budget calls it, and only the budget writes `enabled` on a `BudgetLight`. Say so in the doc comment.
- **`_process(_delta)`,** presentation only (the light is a gameplay node's child, but this is visuals):
  - If there is no sprite, return.
  - `_sprite.visible = demoted and energy > 0.0`.
  - When shown: `texture = texture` (so a light textured after `_ready()` still gets a full sprite), `modulate = Color(color.r, color.g, color.b, clampf(energy * SPRITE_ALPHA, 0.0, 1.0))`, `scale = Vector2.ONE * texture_scale`, `position = offset`.
  - The sprite is a child, so it hides with the light (the lurker sets `visible`) and follows the interpolated transform. `enabled = false` does **not** hide children (probed), which is why the fallback works.
- **Statics** (pure, so tests call them on stand-ins):
  - `texture_rect(light: PointLight2D) -> Rect2`: 1.11's formula moved from `overlays.gd`. The size is `texture.get_size() * texture_scale * global_scale.abs()`, centred on `light.to_global(light.offset)`.
  - `lit_on_screen(light: PointLight2D, rect) -> bool`: 1.11's `counts_on_screen()` moved verbatim (`is_visible_in_tree() and enabled and energy > 0.0 and texture != null`, and `texture_rect` meets `rect`).
  - `choose(entries: Array[Dictionary], budget := MAX_ON_SCREEN) -> Array[bool]` (D4).
  - `apply(lights: Array, rect: Rect2, budget := MAX_ON_SCREEN) -> Dictionary`:
    - for each `BudgetLight` that `wants_light()`, build `{rank, on_screen = texture_rect(l).intersects(rect), lit = not l.demoted, dist = texture_rect(l).get_center().distance_to(rect.get_center())}`;
    - `choose()`, then `set_demoted(not keep[i])` on each one whose state changes. ALWAYS lights are always kept;
    - return `counts(lights, rect)`.
  - `counts(lights, rect) -> Dictionary`, `{lit, sprites, over}`:
    - `lit`: the `BudgetLight`s that are `lit_on_screen`;
    - `sprites`: the ones that want light, are demoted and whose rect meets `rect`;
    - `over`: `max(0, ALWAYS on screen − budget)`.
- **Depends only on `core/` (`Fx`):** no upper-layer class, so `core_layer` passes. It doesn't touch `Game` or any state.

**D4: The rule, `choose()`.**
- **An entry that is off screen** returns its current `lit` unchanged. It costs nothing (the engine culls it), and leaving it alone means a light near the edge can't toggle as it crosses.
- **An on-screen ALWAYS entry** is `true`, and takes a slot. If ALWAYS alone exceeds the budget, slots go negative and every other light drops.
- **The other on-screen entries** are sorted by:
  1. `rank` ascending (CACHE before GLOW);
  2. currently lit first (sticky);
  3. `dist` ascending;
  4. index ascending, for determinism (group order is tree order).

  The first `max(slots, 0)` are kept.
- **Why sticky:** distance alone can swap two similar lurkers every tick, and a light ↔ sprite swap flickering at 60 Hz would break the ≤ 3 flashes/s cap (NFR8). With stickiness, a light changes state only when something enters or leaves the screen, starts or stops wanting light, or a higher rank needs its slot.
- **A light that stops wanting light** (energy 0) isn't an entry. It keeps its state and frees its slot; its sprite hides because the energy is 0.
- **Cases for `test_light_budget`:**
  - 8 on screen (ALWAYS ×3, CACHE ×1, GLOW ×4, distinct distances): exactly 6 kept, both demoted ones are the farthest GLOWs, every ALWAYS kept.
  - ALWAYS ×7 + GLOW ×1: 7 kept, the GLOW dropped, `over` 1.
  - ALWAYS ×1 + CACHE ×1 + GLOW ×6, with the CACHE placed **farthest** from the centre (or a distance-only sort would also keep it): the CACHE and the nearest 4 GLOWs kept.
  - A GLOW nearer than the CACHE still ranks below it.
  - Sticky: a lit far GLOW keeps its slot against an unlit near one.
  - A slot frees (a lit GLOW leaves the screen): the nearest demoted GLOW is relit.
  - Off-screen entries keep `lit` as given, both true and false.
  - Budget 0 with no ALWAYS: everything on screen drops.
  - **Jitter:** ALWAYS ×5 + GLOW ×2 (one slot left), 120 passes. Each pass feeds the previous pass's output back as `lit`, and swaps the two GLOWs' distances. The first pass demotes the farther one; after that, no entry changes state again. Each entry changes at most once.

**D5: A `LightBudget` child of World runs it, after the actors.**
- **Why not in `World._physics_process()`:** World ticks before its descendants (tree order). A lurker that wakes on a tick raises its glow's energy *after* World has run, and its light defaults to lit, so it would be drawn past the budget for one frame. In `perf_worst` that is 7 lights at the first wake, and a light → sprite pop the next frame. The reviewer's probe in `perf_worst` saw four glows go from 0 to lit inside one tick.
  - `smoke_perf`'s "lit ≤ Spec on every tick" would fail, and so would PerfRun's `max_lit`.
  - Moving World's own priority would also move its exit polling, which `smoke_room_swap` times.
- **`scripts/world/light_budget.gd`:** no `class_name`; World preloads it.
```gdscript
extends Node
## AR46, Story 1.12 D5: applies the ≤ 6 light budget once per physics tick, after every actor has
## moved and set its light (priority 0) and the camera rig has moved (so light_rect() is this
## tick's), and before DevTools and its perf run (100), which read the result. Pausable with World.

const PRIORITY := 50

var world: World  ## set by World before add_child


func _init() -> void:
	name = "LightBudget"
	process_physics_priority = PRIORITY


func _physics_process(_delta: float) -> void:
	BudgetLight.apply(get_tree().get_nodes_in_group(BudgetLight.GROUP), world.light_rect())
```
- **World:**
  - `const LightBudgetNode := preload("res://scripts/world/light_budget.gd")`.
  - In `_ready()`, straight after `add_to_group("world")` (the DevTools hook stays first), build it: set `world = self` and `add_child`.
  - Add:
    ```gdscript
    ## The rect the light budget counts as on screen (D2): the whole view, gutters included. A cost
    ## rule (the engine draws and culls lights against the viewport), not AR20's fairness rule.
    func light_rect() -> Rect2:
    	return _camera.view_rect()
    ```
  - `World._physics_process()` is unchanged.
- **It runs regardless of the player:** as its own node it still runs while the player is dead or a swap waits. It is not World's early-returning tick.
- **Cost:** every tick, a handful of nodes and one small sort, with no allocation beyond the group array and no `find_children`.
- **Children change:** World's children become `Darkness, RoomHolder, Camera, UI, DevTools, LightBudget`, plus the player. Update the `smoke_dev_tools` pin (D12).
- **Standalone rooms** (RoomHarness, `smoke_rooms`) have no World, so no budget runs there. Every glow stays lit, and their behaviour is unchanged.

**D6: `Fx` materials.**
```gdscript
static var _unshaded_material: CanvasItemMaterial
static var _additive_material: CanvasItemMaterial

## Shared by every code-built effect (project-context: cache materials as statics; AR46).
static func unshaded() -> CanvasItemMaterial:  # lazily built once: LIGHT_MODE_UNSHADED, reads in the dark

## Sprite glows (BudgetLight's fallback): added onto the dark, unshaded.
static func additive() -> CanvasItemMaterial:  # once: BLEND_MODE_ADD + LIGHT_MODE_UNSHADED
```
- `pop()` and `popup()` use `unshaded()`. `_unshaded()` is deleted, and nothing else called it.
- `test_fx.gd`:
  - same instance twice, for each getter;
  - the right `light_mode` and `blend_mode`;
  - the two are different instances;
  - `pop(parent, …)`'s `CPUParticles2D` child and `popup(parent, …)`'s `Label` child have `material == Fx.unshaded()`;
  - the `pop` node is gone after its lifetime (await 0.6 s): it frees itself (AR46).

**D7: `--glow=on|off`.**
- **The row:** `"glow": {help = "--glow=on|off: engine glow (a WorldEnvironment) for the perf check; off unless given", apply = &"_apply_glow", repeat = false}`.
- **Pure validator `glow_value(text) -> [bool, error]`:** only `on` / `off`, lowercase. Anything else, including `""` and `ON`, is an error that lists both.
- **Pure builder `glow_environment() -> Environment`,** which `test_dev_args` checks:
  - `background_mode = Environment.BG_CANVAS`, `glow_enabled = true`;
  - `glow_intensity = GLOW_INTENSITY` (1.0), `glow_strength = 1.0`;
  - `glow_bloom = 0.0`. Bloom 1.0 lifts the whole frame (probed), which breaks the darkness pillar;
  - `glow_hdr_threshold = GLOW_THRESHOLD` (0.5);
  - `glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE`;
  - the default glow levels.

  These are starting values for seeing the cost and the look. If glow goes, the follow-up story tunes them.
- **`_apply_glow`, for `on`:** `add_child` a `WorldEnvironment` named `"Glow"` with that environment, under DevTools. Keep `glow_on = true` for the summary.
  - One `WorldEnvironment` per viewport. If a later story puts one in World, it removes this one.
- **What the probe found:**
  - Glow renders in the Compatibility renderer in 2D without `hdr_2d`.
  - It **darkens the dark ambient** (0.039 → 0.016) on Mesa llvmpipe. `docs/perf.md`'s look check makes sonlm compare the brightness levels with glow off and on.

**D8: Overlay 4 rows (`overlays.gd`).**
- **Counts come from the budget:**
  - `_rebuild_readout()` sets `light_count`, `sprite_count` and `over_count` from `BudgetLight.counts(get_tree().get_nodes_in_group(BudgetLight.GROUP), world.light_rect())`.
  - Delete `_count_lights()` and `counts_on_screen()`; their rule now lives in `BudgetLight`.
  - A raw `PointLight2D`, which only tests can make (lint `raw_light`), is no longer counted. That is the point: the overlay shows what the budget sees.
- **Frame times (overlays only, mode 4):**
  - In `_process`, while mode 4 is on, record `Time.get_ticks_usec()` intervals.
  - `frame_ms` is the latest. `worst_frame_ms` is the max since mode 4 opened; `cycle()` resets both.
  - Rebuild the text at 4 Hz with the rest.
- **The rows** (a public `readout: PackedStringArray`, renamed from `_readout` for tests):
  1. `FPS %d`
  2. `lights %d/%d` with `BudgetLight.MAX_ON_SCREEN`, + `, sprites %d` + (`, over %d` if > 0)
  3. `frame %.1f ms, worst %.1f ms`
  4. If `perf` (D1) exists and isn't done: `perf %d / %d s`. Once done: `summary_text()` split over at most three rows at `;` boundaries, so it fits the 480 px screen at size 8.
  5. Then the Clock rows, unchanged.
- Nothing blinks, and the colours are as before. Never the reserved amber or red (NFR9).

**D9: `rooms/dev/perf_worst.txt`.**
- This grid validated clean on 2026-11-19 (`RoomLoader.validate()` gave `[]`), and a second, independent check confirmed it.
  - It builds 10 lurkers at x = 120 / 344 and y = 88, 200, 424, 616, 824: 4 on screen 1, then 2 per screen.
  - It builds 44 hoverers, in rows of 4 at rows 8, 15, 18, 23, 29, 35, 41, 47, 54, 60 and 63 (8 on screen 1, 12 on each later screen), and 4 walkers.
  - Spawn is `(3, 4)`; bounds are 480 × 1088.
- **The lurkers sit in wall stubs** (in-wall rule) at columns 7 and 21. That puts them inside the play rect shrunk by the notice margin (x 68–412 when the camera is centred), so they wake.
  - Lurkers in the edge columns of a 480-wide room sit under the gutters and would never wake (AR20).
  - Screen 1's four are within the chain-20 notice reach (138.4 × 1.6 ≈ 221 px) of the path's start (240, 48), so the budget is exceeded within the first seconds: player + flare + cache + 4 glows = 7.
- **Header comment:** say what it is. For example: "; Story 1.12 worst-case perf scene (AR5): Old Mine density, never a level. 30 wide, so lit tiles fill the whole view; lurkers in wall stubs inside the play rect; columns 13-16 stay open for `--perf`'s path. Validated only (`rooms/dev/`)."
  - Keep `randf` and other scanned words out of it, even though `smoke_world` only scans `scripts/`.
- **The grid** (after the header lines `id=perf_worst` and `zone=violet`, then `---`):
```
##############################
#............................#
#............................#
#............................#
#..P.........................#
#######L.............L########
#............................#
#............................#
#...h....h..........h....h...#
#............................#
#............................#
#............................#
#######L.............L########
#............................#
#............................#
#.....h....h......h....h.....#
#............................#
#............................#
#...h....h..........h....h...#
#..c.........................#
#######......................#
#............................#
#............................#
#.....h....h......h....h.....#
#............................#
#............................#
#######L.............L########
#............................#
#............................#
#...h....h..........h....h...#
#............................#
#............................#
#..........................c.#
#......................#######
#............................#
#.....h....h......h....h.....#
#............................#
#............................#
#######L.............L########
#............................#
#............................#
#...h....h..........h....h...#
#............................#
#............................#
#..c.........................#
#######......................#
#............................#
#.....h....h......h....h.....#
#............................#
#............................#
#............................#
#######L.............L########
#............................#
#............................#
#...h....h..........h....h...#
#............................#
#............................#
#..........................c.#
#......................#######
#............................#
#.....h....h......h....h.....#
#............................#
#............................#
#...h....h..........h....h...#
#............................#
#............................#
#............................#
##############################
```
- It is not a level. sonlm doesn't approve it as content: dev rooms are validated only, and the fairness rules don't apply.
- If you change it, keep:
  - ≥ 1 lurker per screen, with 4 in screen 1's reach;
  - every lurker inside the play rect;
  - columns 13–16 open in rows 1–66;
  - 30 columns;
  - `P` with solid below it;
  - no exits.

  Then re-validate.

**D10: `docs/perf.md`.**
- **Purpose:** AR5, NFR1, NFR5. What it decides in 1.15: the engine-glow go/no-go, whether ≤ 6 `PointLight2D` holds 60 FPS, Compatibility glow parity on web, and a flare-cap recommendation.
- **The scene:**
  - what `perf_worst` holds, and what `--perf` does;
  - that the stand-ins ride along on purpose;
  - that each pass wakes the lurkers as their screen comes into reach. Hunting lurkers (95 px/s) trail the 100 px/s path and fall away rather than pile up. Screen 1's four push the lights past the budget whenever the path passes the top, so the sprite fallback is exercised on every pass.
- **Known first-second hitch:** the first demotion is the additive material's first use. A worst frame within the first second may be that shader warm-up, which is 1.16's job, not steady-state cost. Record `worst_at` with the number.
- **How to run:**
  - **Desktop:** `godot --path game -- --room=perf_worst --perf` (the window opens at ×3, 1440 × 810), then add `--glow=on`. In the editor: Debug → Customize Run Instances. Never `editor/run/main_run_args`, which writes `project.godot`.
  - **Web**, once 1.13 and 1.14 have landed: the debug web build at the ×2 embed (960 × 540) with `?room=perf_worst&perf` and `&glow=on`, in Chrome and Firefox, with hardware acceleration on.
  - **HD 620-class machine**, if one is available, the same two runs. If none is, record the gap.
- **Conditions:** vsync on (the default); note the display's refresh rate (60 FPS is the target, so a 120 Hz screen shows ~120); mains power; other heavy apps closed; overlays off during the run (they cost a little). Read the summary from the terminal or the browser console (`[room] dev: perf …`), or cycle to overlay 4 after the run.
- **What to record per run:** the date, the build or commit, the machine and adapter (from the summary), the window size and scale, the refresh rate, glow, then avg and min FPS, the worst frame and when, slow frames, the max lights, sprites and over, breaks and deaths (both expected 0), and notes.
- **The look check (glow on vs off):** at each brightness (`--set=brightness:0` … `3`), compare the darkness and the halo. The 2026-11-19 probe saw glow darken the dark ambient on a software renderer, so check on the laptop's GPU whether glow keeps the darkness readable (Pillar 2). Also check that a sprite glow beside a lit glow doesn't read as a different thing.
- **Decision guide for 1.15** (a guide, not a rule; sonlm decides):
  - glow off fails anywhere → tighten the budget, and re-run at 5;
  - glow on holds 60 FPS with no slow frames on every target and passes the look check → go;
  - otherwise no-go, and fake bloom with unshaded additive sprites.
  - A flare cap follows from the slots left after the player (1), the cache (1) and a minimum of lurker glows.
- **An empty results table,** with the columns above, under "Results (Story 1.15)", plus one line: "No numbers are recorded by the agent; sonlm fills this in Story 1.15."
- Link it from `docs/index.md` and from the development guide's DevTools section.

**D11: Spec, scenes and the lint.**
- **Spec:** `tests/spec.gd` gets `const LIGHTS_ON_SCREEN_MAX := 6  ## GDD Open Questions: "The light budget is ≤ 6 \`PointLight2D\` on screen and flares always keep theirs" (architecture AR46); a ceiling: 1.15 may tighten it, never loosen it without the GDD.`
  - Budget tests compare the lit count against `Spec.LIGHTS_ON_SCREEN_MAX`, never against `BudgetLight.MAX_ON_SCREEN`.
  - The one test that names `MAX_ON_SCREEN` checks it is ≤ the Spec value.
- **Scenes:**
  - In `player.tscn`, add an `ext_resource` for `res://scripts/core/budget_light.gd`, set `script = ExtResource(...)` and `rank = 0` on `Light`.
  - In `lurker.tscn`, set the same script on `Glow` and leave `rank` at its default (GLOW), or write `rank = 2` explicitly. Either is fine; say which.
  - Keep each scene's existing properties. M1 scenes carry no `uid=` attributes (architecture, M1 migration), so don't add any by hand. Re-save through `godot --headless --path game --import` if the import complains.
- **The scene audit** (in `test_light_budget`):
  - Walk `res://scenes/` recursively for `*.tscn`. For each, take `(load(path) as PackedScene).get_state()`, and for every node whose `get_node_type(i) == "PointLight2D"`, check:
    - a stored `script` property whose `resource_path` is `res://scripts/core/budget_light.gd`;
    - a stored `texture` whose `resource_path` is `res://art/light.png`.
  - Sentinel: the audit found ≥ 2 lights (player and lurker), so a broken walk can't pass as "no lights".
  - Then instantiate `player.tscn` and `lurker.tscn` only (both are side-effect-free standalone), and check:
    - `$Light is BudgetLight` and `$Glow is BudgetLight` first, as their own checks. Read `rank` only when that holds, so an unscripted light is a named FAIL, never a SCRIPT ERROR;
    - `$Light.rank == BudgetLight.Rank.ALWAYS` and `$Glow.rank == BudgetLight.Rank.GLOW`;
    - the lurker's `$Eyes.material` is a `CanvasItemMaterial` with `LIGHT_MODE_UNSHADED`.

    `queue_free` both.
  - Never instance `world.tscn` in this test: its `_ready` builds a room and DevTools.
- **The lint row** `raw_light`, after `dev_ref`:
  ```gdscript
  # AR46 (Story 1.12): every 2D light is a BudgetLight, or the ≤ 6 budget can't see it.
  {id = &"raw_light", bare = [r"\bPointLight2D\s*\.\s*new\s*\(", r"\bextends\s+PointLight2D\b"], code = [],
  	only = [], skip = [], allow = ["core/budget_light.gd"]},
  ```
- **Samples:**

  | Text | Path | Expected |
  |---|---|---|
  | `var l := PointLight2D.new()` | `actors/flare.gd` | fires |
  | `extends PointLight2D` | `objects/ember_cache.gd` | fires |
  | `var l := PointLight2D.new()` | `dev/perf_run.gd` | fires (stand-ins are `BudgetLight`s too) |
  | `extends PointLight2D` | `core/budget_light.gd` | quiet |
  | `var l := BudgetLight.new()` | `dev/perf_run.gd` | quiet |
  | `# PointLight2D.new()` | `actors/flare.gd` | quiet (comment) |
  | `var s := "PointLight2D.new()"` | `actors/flare.gd` | quiet (string) |
  | `@onready var _light: PointLight2D = $Light` | `actors/player.gd` | quiet (a type is fine) |

- The real tree has 0 hits; the full lint run already proves it. Add the row to `docs/development-guide.md`'s lint table and to the architecture's Enforcement paragraph. `.tscn` files are never linted (a header blind spot), which is why the scene audit exists.

**D12: Tests.**

*`tests/test_light_budget.gd` (new).*
- The D4 `choose()` cases.
- **Nodes:** `BudgetLight.new()` under the test node, `texture = preload("res://art/light.png")`, energy 1.0, `rank` set before `add_child`.
  - **(premise)** after `add_child`, every one is in group `budget_light`, and every non-ALWAYS one has a `Fallback` sprite whose material is `Fx.additive()`.
  - **The 8-light case:** player-like ALWAYS ×1, flares ALWAYS ×2, CACHE ×1, GLOW ×4. All inside `Rect2(0, 0, 480, 270)`, the glows at distinct distances from (240, 135).
    - `apply()` returns `lit == Spec.LIGHTS_ON_SCREEN_MAX` and `sprites == 2`.
    - The two farthest GLOWs have `demoted == true`, `enabled == false`, and after a `process_frame` their sprite is visible.
    - Every ALWAYS light is enabled.
    - `over == 0`.
  - **ALWAYS ×7 + GLOW ×1:** `lit == 7`, `over == 1`, the GLOW demoted, no ALWAYS disabled. This is the AC's "never".
  - **Recovery:** move one lit GLOW wholly outside the rect and `apply()` again. The nearest demoted GLOW is relit, and the moved one keeps its state (off screen: unchanged).
  - **Sprite sync:** a demoted GLOW's sprite alpha follows its energy (`energy 1.0 → alpha 0.35`, `0.5 → 0.175`, within 0.01, after a `process_frame`). It hides at energy 0. `scale == texture_scale`.
  - **Hidden** (`visible = false`) and **energy 0** lights take no slot. Pin it with 6 wanting plus 1 hidden: none demoted.
  - **`lit_on_screen` and `texture_rect` cases:** move 1.11's `test_lights` stand-in cases here (inside, hidden, disabled, energy 0, no texture, wholly outside, straddling), plus a scaled parent (`global_scale` 2).
- The D11 scene audit and the Spec check.

*`tests/test_fx.gd` (new):* the D6 cases.

*`tests/smoke_perf.gd` (new, scene).* Build World as `smoke_dev_tools` does: inject tokens through `child_entered_tree`, which matches `node is DevTools`.
- **Setup:** each case ends with `Game.reset_for_tests()`, `Log.set_enabled([])`, `get_tree().paused = false` and World freed. Never keep two Worlds alive.
- **`--room=perf_worst --perf=3`:**
  - **(premise)** the room is `perf_worst`, `DevTools.perf` exists, and the player is locked (`input.is_locked()`) with `Hurtbox.collision_mask == 0`.
  - Within 10 ticks the chain is 20. Then on **every** physics tick until `perf.done`:
    - the chain is 20;
    - `is_dead` is false;
    - `x == 240`;
    - `BudgetLight.counts(...)` (with `world.light_rect()`) has `lit ≤ Spec.LIGHTS_ON_SCREEN_MAX`;
    - the player's `Light` and the flare stand-in are never `demoted`.

    Sample on `get_tree().physics_frame`, which fires before the next tick's physics, so it sees what was drawn: every actor moved and `LightBudget` applied. Cap the run at 6 s. Guard a missing player or room as a named FAIL.
  - **(premise for D5)** at the first tick where screen 1's glows wake, the sample already shows `lit ≤ Spec`. With the budget run before the actors, this check fails at the first wake (red check 20).
  - **(premise)** the budget was exercised: at some tick `sprites ≥ 1`, and every demoted light that tick has rank GLOW.
  - After the first 60 ticks, the player's `y` has grown by about 100 px (`PATH_SPEED`, ± 4).
  - `stand_ins` are a flare of rank ALWAYS and a cache of rank CACHE, both children of the current room. The flare's radius matches `player.light_radius()`.
  - When done: `result.frames > 0`, `result.breaks == 0`, `result.deaths == 0`, `result.max_lit ≤ Spec`, `result.max_sprites ≥ 1`, `result.chain == 20`, `result.glow == false`, and `summary_text()` contains `perf 3 s`.
  - Overlay 4's readout then holds a row starting `perf 3 s` (set `overlays.mode = 4` and await a rebuild).
- **`--room=perf_worst` alone:** no PerfRun; the player is not locked and its mask is 12; no stand-ins (no `BudgetLight` under the room besides lurker glows); no `Glow` child.
- **`--glow=on`:** DevTools has a `WorldEnvironment` named `Glow` whose environment has `glow_enabled` and `BG_CANVAS`. `--glow=off`: none. `--glow=yes`: none, with a warning; the runner stays green.
- **Bad `--perf`:** `--perf=0`, `--perf=601` and `--perf=x` each warn, and no PerfRun is built.
- **View rect** (D2): `world.light_rect()` is 480 × 270, centred on `world.play_rect()`'s centre, and contains it.
- **`m1_shaft`, no args (AC10):** the `BudgetLight`s in the tree (the player's plus the room's lurker glows) number at most `Spec.LIGHTS_ON_SCREEN_MAX` (5 today), so the budget can never demote there. At spawn, `counts().sprites == 0`.

*`tests/test_dev_args.gd` (edits):*
- The unknown-arg message becomes `unknown arg --foo (known: chain, glow, log, perf, room, set)`.
- `ARGS.keys() == ["log", "set", "room", "chain", "glow", "perf"]`, and `glow`/`perf` are not `repeat`.
- **`glow_value`:** `on`/`off` give true/false; `""`, `ON`, `yes` and `1` are errors.
- **`perf_seconds`:** `""` gives 60; `1`, `60` and `600` are ok; `0`, `601`, `-5`, `x`, `12345` and a 20-digit string are errors (the 4-character cap goes first).
- **`glow_environment()`:** the D7 properties.
- **`PerfRun.path_point`:**
  - tick 0 is `top`, going down;
  - after `span / speed` seconds it is `bottom`;
  - one tick later it is going up;
  - after `2 × span / speed` it is back at `top`;
  - `span ≤ 0` gives `top` and 0.
- **Stats:**
  - 60 frames of 16 667 µs (`at` increasing) give `avg_fps` ≈ 60 (±0.5), `min_fps == 60`, worst ≈ 16.7 ms, slow 0.
  - Add one 25 000 µs frame at 0.5 s: slow 1, worst 25.0 ms at 0.5 s.
  - A second with only 30 frames gives `min_fps == 30`.
  - `summary_text` of a fixed result is exactly the D1 format.

*`tests/smoke_dev_tools.gd` (edits):*
- `test_lights`: the per-light stand-in cases move to `test_light_budget`; call `BudgetLight.lit_on_screen` there.
- Keep the `m1_shaft` count of 1. `_code_light()` builds a `BudgetLight` (rank GLOW) instead of `PointLight2D.new()`. Tests aren't linted, but only group members are counted now.
- The gutter case follows D2: the light under the gutter now counts (3), and a new light wholly outside the view doesn't.
- Add: a raw `PointLight2D` (not a `BudgetLight`) inside the rect is **not** counted. The overlay shows what the budget sees.
- Readout: after a rebuild in mode 4, `readout` has a row starting `lights 1/6` and one starting `frame `.
  - **(premise)** `worst_frame_ms > 0`.
  - Then `cycle()` 5 times, back into mode 4. Before any frame passes, `worst_frame_ms == 0`: it was reset.
- **The two pins (AC10):**
  - The no-token case's World children (`:206-207`) become `["Darkness", "RoomHolder", "Camera", "UI", "DevTools", "LightBudget"]` (D5). DevTools stays first among the added ones, because its hook is `_ready()`'s first statement.
  - `test_bad_args` (`:304`) expects `unknown arg --foo (known: chain, glow, log, perf, room, set)`.

*`tests/test_lint.gd`:* the D11 samples.

*Counts:* note every test's `ok` count before and after in the Debug Log, as 1.11 did.

**D13: Docs and ledger.**
- **`docs/perf.md`** (new, D10).
- **`docs/development-guide.md`:**
  - DevTools section: `--glow`, `--perf` and the new overlay 4 rows, with a link to `perf.md`;
  - the Testing list: the three new tests;
  - the lint table: `raw_light`;
  - Common Tasks: "add a light: build a `BudgetLight` and set its `rank` (ALWAYS only for the player and flares)".
- **`docs/architecture.md`:**
  - Rendering and Light: `BudgetLight`, the budget each tick, the sprite fallback, the light rect;
  - Component Overview;
  - Testing Strategy rows, and "Last run" (20 tests);
  - the Gaps table's Builds row: the perf scene exists, the presets come in 1.13.
- **`docs/component-inventory.md`:**
  - Core: `BudgetLight`, and `Fx.unshaded()` / `additive()`;
  - the Player Light row and the Lurker look: the glow is a `BudgetLight` with a sprite fallback;
  - World: `light_rect()`, and its `LightBudget` child applying the budget each tick at priority 50;
  - CameraRig: `view_rect()`;
  - Dev Tools: `--glow`, `--perf`, `PerfRun`, overlay 4;
  - Asset Inventory, the `light.png` row: "every `PointLight2D` and the sprite glows";
  - Test Components.
- **`docs/source-tree-analysis.md`:** `core/budget_light.gd`, `world/light_budget.gd`, `dev/perf_run.gd`, `rooms/dev/perf_worst.txt` and the new tests.
- **`docs/rooms.md`:** the `rooms/dev/` line (`:121`) names `perf_worst` and the run.
- **`docs/index.md`:** link `perf.md`, and update Last Updated.
- **`game/README.md`:** the Tests list and a run note for the perf run.
- **`_bmad-output/project-context.md`:**
  - Current State: append a 1.12 sentence.
  - Performance Rules:
    - "every `PointLight2D` is a `BudgetLight` (lint `raw_light`); World's `LightBudget` child demotes over-budget lights each physics tick, after the actors (priority 50), GLOW first, then CACHE, ALWAYS never";
    - the budget counts the whole view, `World.light_rect()`: a cost rule, not AR20's play rect;
    - replace "(current `Fx._unshaded()` does: fix when touched)" with "`Fx.unshaded()` / `additive()` are the shared ones".
  - Testing Rules: the lint list gains `raw_light`.
  - Last Updated.
- **`_bmad-output/game-architecture.md`:**
  - Lighting: `BudgetLight`, the rule (ranks, stickiness, off-screen left as is), the D2 rect and why;
  - the Technical Requirements "Visible play rect" bullet: "(the light budget, a cost rule, counts the whole view)";
  - Debug Tools: the args row (`--glow`, `--perf`), the overlay 4 row, and a "Perf run" paragraph;
  - Enforcement: `raw_light`;
  - Directory Structure: `core/budget_light.gd` and `dev/perf_run.gd`;
  - System Location Mapping: a Light budget row.
- **Ledger** (`implementation-artifacts/deferred-work.md`):
  - **Close 1.11's items 1 and 2.** Under each one's owner line add `→ **Closed (Story 1.12): …**`, saying how: the `--perf` run holds the chain (D1), and `BudgetLight` plus `World.light_rect()`, with overlay 4 pointed at `BudgetLight.counts()` (D2–D5, D8).
  - **Add under a "Deferred from: dev of 1-12-…" heading,** each with its `→ **Owner: …** — why` line:
    1. "`LightSource` drives its light through the owner's `BudgetLight`. The budget, not `LightSource`, decides light or sprite, and `LightSource` never writes `enabled`" → **Owner: Story 1.20** — it adds `LightSource` (architecture: "drives its `PointLight2D` (or sprite glow)").
    2. "The Ember Cache's glow is a `BudgetLight` of rank CACHE, and the perf run's cache stand-in matches its radius from `Tuning`" → **Owner: Story 1.22**.
    3. "A flare's light is a `BudgetLight` of rank ALWAYS, and the perf run's flare stand-in is then compared with a real thrown flare" → **Owner: Story 1.23**.
    4. "Engine glow lives only in DevTools (`--glow`). If 1.15 says go, a follow-up moves it into game code, and re-checks the brightness levels and contrast floors: the 2026-11-19 probe saw glow darken the dark ambient. If it says no-go, bloom is faked with unshaded additive sprites (architecture Lighting)" → **Owner: Story 1.15** — the CP1 verdict decides and creates the follow-up story.
  - Name all six (2 closed, 4 new) in your report.

**D14: Red checks.** For each: break it, see the named check fail, revert. Record each with its failing line.
1. `choose()` sorting by distance only, ignoring rank: the "CACHE kept before GLOWs" and "nearer GLOW ranks below the CACHE" cases fail.
2. `choose()` with no ALWAYS special case: the ALWAYS ×7 case fails (an ALWAYS dropped).
3. No stickiness: the jitter case fails (more than one change).
4. Off-screen entries counted as on screen: the off-screen and recovery cases fail.
5. World's budget call removed: `smoke_perf`'s "lit ≤ Spec on every tick" fails, along with the "sprites ≥ 1" premise.
6. `MAX_ON_SCREEN = 8`: the 8-light case fails against `Spec` (lit 8 > 6), and so does the Spec check.
7. `Fx.unshaded()` returning a new material: `test_fx` "same instance" fails.
8. `player.tscn`'s `Light` without the script: the scene audit's named "is a `BudgetLight`" check fails (guarded, so no SCRIPT ERROR), and `smoke_dev_tools`' `m1_shaft` count of 1 fails (0).
9. A `PointLight2D.new()` in a game script: `FAIL lint <file>:<line> raw_light`.
10. PerfRun without the hurtbox mask: `smoke_perf`'s mask premise fails.
11. The PerfRun path driven by wall time: there's no headless check for this. Record it as not red-checkable, and keep the tick counter as a reviewed rule.
12. `--glow=on` without `BG_CANVAS`: the environment check fails.
13. D2 swapped (the other rect): `smoke_dev_tools`' gutter case and `smoke_perf`'s view-rect check fail.
14. The overlay counting with `find_children` again: the "raw `PointLight2D` not counted" check fails.
15. The sprite alpha not following energy (a fixed 1.0): the sprite sync case fails.
16. `set_demoted()` not touching `enabled`: the 8-light case's `enabled == false` and `lit == 6` checks fail.
17. The flare stand-in built with rank CACHE: `smoke_perf`'s stand-in rank check fails.
18. `perf_seconds("")` returning 0: the `test_dev_args` default case fails, and `smoke_perf`'s `--perf=3` still passes, so record both.
19. The stats bucketed by frame count instead of time: the "30 frames in a second gives min 30" case fails.
20. `LightBudget` at priority 0, or the call moved into `World._physics_process()`, so it runs before the actors: `smoke_perf`'s per-tick "lit ≤ Spec" fails at screen 1's first wake (7 lit), and so does `result.max_lit ≤ Spec`.
21. `_chain_given` ignored (`--perf` uses `_chain` whatever it holds): a `smoke_perf` case with `--chain=99 --perf=1` (a rejected chain) holds 20, not 0. Add that case; it fails with the break.
22. No `snap()` after the teleport: there's no headless check for the camera slide. Record it as not red-checkable, beside 11.

**D15: The desktop debug export check (AC1).**
- Work in a scratch copy of `game/` outside the repo with its own `config/name`, as 1.11's probes did. Write a minimal `export_presets.cfg` with one Linux preset and an include filter that covers `rooms/` (for example `include_filter="rooms/*"`).
- Run `godot --headless --path <copy> --export-debug "<preset>" <out>/perf.x86_64`, then `timeout 20 <out>/perf.x86_64 --headless -- --room=perf_worst --perf=3`.
  - The autopilot keeps running after the summary (D1), so the binary never exits on its own; `timeout` ends it (exit code 124, expected).
- Expect the `[room] dev: perf 3 s: …` line and no `ERROR:` lines. Headless, the adapter reads `''` and the window `64x64` (reviewer probe), so the line ends `window 64x64; Linux, `. Record it in the Debug Log.
- The server has Linux and Windows templates, not web (1.11). Delete the scratch copy and never commit the preset: 1.13 owns `export_presets.cfg`.

### Verified facts (probes 2026-11-19, Godot 4.7.2.stable.official.ed1daf0bf, xvfb + Mesa llvmpipe for rendering)

- **Engine glow in GL Compatibility 2D works** with a `WorldEnvironment` whose `Environment` has `background_mode = BG_CANVAS` and `glow_enabled = true`. No `rendering/viewport/hdr_2d` is needed.
  - Test scene: a 30 px unshaded white square on a 0.4 grey under a 0.1 `CanvasModulate`, with intensity 2.0 and threshold 0.5.
  - The halo raised pixels 1–4 px from the square from 0.039 to 0.10–0.125, and faded out by about 10 px.
  - `set_glow_level()` on all 7 levels changed nothing visible at that size.
  - With `hdr_2d` on, the results were about the same.
- **Glow on darkens the dark ambient.** In the same scene, the far background went from 0.039 to 0.016 with glow on. An `Environment` with glow **off** changed nothing (0.039).
  - Seen on a software renderer. Re-check on real GPUs (`docs/perf.md`'s look check).
  - `glow_bloom = 1.0` lifted the whole frame (far background 0.039 → 0.106).
- **An additive sprite glow works under the darkness.** A `Sprite2D` with `light.png`, a `CanvasItemMaterial` with `BLEND_MODE_ADD` + `LIGHT_MODE_UNSHADED`, `modulate (1, 0.25, 0.2, 1)` and scale 0.8 rendered its centre at (1.0, 0.29, 0.24) over a 0.04 background under a 0.1 `CanvasModulate`. It escapes the darkness and adds.
- **`PackedScene.get_state()` lists nodes without instancing.**
  - `get_node_type(i)` gives `"PointLight2D"`, and `get_node_property_name/value` give only the **stored** (non-default) properties.
  - `player.tscn ./Light`: `color, energy, texture, texture_scale`.
  - `lurker.tscn ./Glow`: those plus `position`.
  - `world.tscn` has no `PointLight2D`.
  - A node with `script = ExtResource(…)` stores `script` as a property, as any non-default property is stored. Confirm it in the audit's first run.
- **A `Sprite2D` child of a `PointLight2D` stays visible** (`is_visible_in_tree()`) when the light's `enabled = false`. So `enabled` disables only the light, and the fallback can live as its child.
- **Frame time:** `get_process_delta_time()` is not wall time; it is scaled by `Engine.time_scale` and was 0.061 at time scale 0.5 while the real interval was 0.0006 s. Measure frames with `Time.get_ticks_usec()` differences.
- **Project settings:** `rendering/viewport/hdr_2d = false`. `rendering/limits/opengl/max_renderable_lights = 32` and `max_lights_per_object = 8` (GLES3 limits); the 6-light budget is under both, whatever they cover. `rendering/environment/glow/upscale_mode = 1`.
- **The D9 grid** validates clean. It builds 10 lurkers (positions in D9), 44 hoverers and 4 walkers, with spawn `(3, 4)` and bounds `(0, 0, 480, 1088)`.
- **Facts from 1.11 to reuse:**
  - `process_physics_priority`: higher runs later, across the tree.
  - A `CharacterBody2D`'s `is_on_floor()` is false until its first `move_and_slide()`.
  - `find_children(…, owned = false)` is needed for code-built nodes.
  - A `PointLight2D.new()` outside the tree is never `is_visible_in_tree()`.
  - `push_warning` is tolerated by the runner; `push_error`, `assert` and engine `ERROR:` fail it.
  - `Array.sort()` on StringNames is pointer order.
  - `JavaScriptBridge.eval` returns null off the web.
  - The runner loads a test script by absolute path (scratch scripts).

### Project Structure Notes

- **New:**
  - `game/scripts/core/budget_light.gd`, `game/scripts/world/light_budget.gd` (no `class_name`, World preloads it) and `game/scripts/dev/perf_run.gd`;
  - `game/rooms/dev/perf_worst.txt`, a new folder (AR26 names it);
  - `game/tests/test_fx.gd`, `game/tests/test_light_budget.gd` and `game/tests/smoke_perf.gd`;
  - `docs/perf.md`.

  Every `.gd` comes with its `.gd.uid`, staged.
- **Changed game code:**
  - `scripts/core/fx.gd`;
  - `scripts/world/world.gd` and `scripts/world/camera_rig.gd` (D2);
  - `scenes/actors/player.tscn` and `scenes/actors/lurker.tscn`.

  Nothing in `actors/*.gd` changes.
- **Changed dev code:** `scripts/dev/dev_tools.gd` (two rows, validators, `glow_environment()`, `perf`) and `scripts/dev/overlays.gd` (counts, frame rows, perf rows).
- **Changed tests:** `spec.gd`, `test_dev_args.gd`, `smoke_dev_tools.gd` and `test_lint.gd`.
- **No `.tscn` or `.tres`** for the stand-ins, the glow environment or `BudgetLight`'s sprite. Everything is built in code, as the project requires.
- **Layers:**
  - `BudgetLight` is in `core/` and names only `Fx`, so `core_layer` passes.
  - World's `LightBudget` node (`world/light_budget.gd`) calls it.
  - `dev/` reaches into the player (`Hurtbox`, `Light`), which is allowed in `dev/` only.
- **`rooms/dev/perf_worst.txt` is a real room under `res://rooms/`.** The index walks `rooms/**`, so `--room=perf_worst` works with no `add_root`. Never put it under `tests/rooms/`: 1.13's debug web preset exports `rooms/dev/perf_worst.txt`, and release presets exclude `rooms/dev/*`.

### Project Context Rules (that apply here)

- **Lights are the cost centre.** ≤ 6 `PointLight2D` on screen; the player and flares keep theirs; lurker wall glow falls back to a sprite first. Reuse `art/light.png` via `texture_scale`. Engine glow stays off until the E1 perf scene passes on web.
- **Cache materials and shared resources as statics.** Never one `Material` per effect. Code-built FX free themselves. Use `CPUParticles2D`, never GPU particles. No `Thread`.
- **Debug tools live only in `dev/`,** added only when `OS.is_debug_build()`. Nothing debug ships. No function keys.
- **"On screen" means `World.play_rect()` for fairness** (notice, stir, edge cues, guarantees). The light budget's rect is D2's documented exception, for cost only.
- **Physics interpolation is on:** move gameplay nodes only in `_physics_process` (the autopilot and the stand-ins), and call `reset_physics_interpolation()` after every teleport (the first placement).
- **`Game` holds refs only.** State is written only through rule methods: the chain through `add_hit()` via 1.11's arming, never pinned.
- **No logging in hot paths** unless guarded. The perf summary is one `Log.info` at the end. Never use bare `print`.
- **No randomness in level behaviour:** the path comes from a tick counter. ≤ 3 flashes/s: the budget is sticky, and nothing blinks.
- **Tests:**
  - `tests/test_*.gd` / `tests/smoke_*.gd`, each `extends Node` with `run()`, printing `ok` / `FAIL` and then `PASS` / `FAILED`.
  - Design guarantees compare against `Spec`.
  - Pick targets by position or by the signal that made them.
  - Report "tests green; needs a look on the laptop", never "runs at 60 FPS".
- **Every deferred item gets an owner line,** written by the agent that defers it (D13). Comments explain *why*, citing the design ("AR46: …", "NFR1: …").

### Previous story intelligence (1.7–1.11 and their reviews)

- **Red-check every new check.** Every review from 1.8 to 1.11 found vacuous checks. Each pure function needs a firing sample and a near-miss. Keep premise, verdict and positive control as separate checks. 1.11's review found three checks that couldn't fail. Here, `smoke_perf`'s "sprites ≥ 1" premise is what stops "lit ≤ 6" passing because nothing ever wanted 7.
- **Named FAILs, never engine errors.** Guard missing nodes in smoke cases: read a null player or room as a named FAIL, never a SCRIPT ERROR (1.11 red check 10).
- **Docs drift** in every review: update every row D13 lists, the dates and "Last run", and count the tests exactly. Record every deviation from these Dev Notes in the Completion Notes. Don't add `project-context.md` rules beyond D13's list without proposing them.
- **1.11's test seam and teardown:**
  - inject tokens through World's `child_entered_tree` with a method, never a capturing lambda;
  - end each case with `Game.reset_for_tests()`, `Log.set_enabled([])`, `get_tree().paused = false`, and World freed;
  - never two Worlds alive at once, because there would be two `world` / `player` group members.
- **1.11 review patch:** `--chain` skips the spawn's own physics frame and paused ticks. PerfRun uses the same guard.
- **Red checks run in scratch copies of `game/`,** each with its own `config/name` (its own `user://`). The real `settings.json` stays untouched (dated 2026-11-12).
- **The baseline** (2026-11-19, `6c0daa2`) is `== ALL GREEN (17 tests)`, 1086 `ok`, 1 m 48 s:

  | Test | `ok` lines |
  |---|---|
  | test_chain_state | 0 (prints "ALL PASS (69 checks)") |
  | test_clock | 21 |
  | test_deferred_owners | 25 |
  | test_dev_args | 75 |
  | test_lint | 179 |
  | test_log | 7 |
  | test_room_loader | 79 |
  | test_room_sweep | 74 |
  | test_state | 180 |
  | test_tuning | 87 |
  | smoke_bot | 6 |
  | smoke_dev_tools | 88 |
  | smoke_moves | 17 |
  | smoke_player_input | 59 |
  | smoke_room_swap | 39 |
  | smoke_rooms | 90 (92 with `perf_worst`: "validates clean" and its `_check_record` line) |
  | smoke_world | 60 |

- **Runtime:** the suite takes about 1 m 48 s. `smoke_perf`'s 3 s run plus four quick World builds adds about 10 s. Keep it under the runner's 120 s watchdog by a wide margin.

### Git intelligence

- **Recent commits** (`feat/m2-e1`, no remote):
  - `6c0daa2` docs: the 1.11 dev and review record, status done;
  - `f2b25e4` feat: DevTools entry args and overlays;
  - `65849f1` docs: the 1.11 story file;
  - `75055f3` docs: the 1.10 review record and laptop check;
  - `f897eb2` test: the 1.10 review fixes.
- **Each story commits in this order:**
  1. `docs: story 1.N file, ready for dev`;
  2. `feat:` / `test:` code (here `feat:` for the budget and the dev tools, `content:` for `perf_worst.txt` if split);
  3. `docs:` (docs + dev record, status review);
  4. the review fixes;
  5. `docs:` review record, status done.
- **Messages** have a prose body and end with the Co-Authored-By and Claude-Session lines. sonlm asks for commits.

### Latest tech notes (Godot 4.7.2)

- **`Environment`:**
  - `background_mode` (`BG_CANVAS` = use the 2D canvas as the background, which 2D glow needs);
  - `glow_enabled`, `glow_intensity`, `glow_strength`, `glow_bloom`, `glow_hdr_threshold`;
  - `glow_blend_mode` (`GLOW_BLEND_MODE_ADDITIVE`, `SCREEN`, `SOFTLIGHT`, `REPLACE`, `MIX`);
  - `set_glow_level(idx, intensity)`.

  `WorldEnvironment.environment`. One per viewport.
- **`CanvasItemMaterial`:** `light_mode` (`LIGHT_MODE_UNSHADED`); `blend_mode` (`BLEND_MODE_ADD`).
- **`PointLight2D` / `Light2D`:** `enabled`, `energy`, `color`, `texture`, `texture_scale`, `offset`. `enabled = false` disables only the light, not its children.
- **Hardware info:** `RenderingServer.get_video_adapter_name()` / `get_video_adapter_vendor()`; `OS.get_name()`; `get_window().size`. `Engine.get_frames_per_second()` updates about once a second.
- **Wall time:** `Time.get_ticks_usec()`.
- **`SceneState`:** `PackedScene.get_state()` → `SceneState.get_node_count()`, `get_node_type(i)`, `get_node_path(i)`, `get_node_property_count(i)`, `get_node_property_name(i, j)`, `get_node_property_value(i, j)`.
- **Context7** needs `/mcp` auth, which subagents don't have. The facts above come from the 4.7.2 API and the local probes.

### Cross-story context (Epic 1 and beyond)

- **1.13:**
  - The presets: the debug web preset includes `rooms/dev/perf_worst.txt`; the release presets exclude `rooms/dev/*`, `tests/*` and `scripts/dev/*`.
  - Playwright boots `?room=perf_worst`, and may add `&perf=5` to get a summary line in the console.
  - The ledger's foreign-query-param item is 1.13's.
- **1.14:** the ×2 web embed scale. `docs/perf.md`'s browser runs wait for it.
- **1.15:** sonlm runs `docs/perf.md`, records the numbers, and decides glow go/no-go, the budget (confirm or tighten `MAX_ON_SCREEN` and `Spec`, GDD first), the flare-cap recommendation, and the glow-darkening look (ledger D13-4).
- **1.16:** the accessibility gate in `Fx`, warm-up at room load and flash-rate declarations. `test_fx.gd` grows there. If the sprite fallback ever animates, it declares its rate there.
- **1.19:** Health replaces one-touch death. `smoke_perf` pins the hurtbox mask, so a renamed or reworked hurtbox fails a named check, not the run.
- **1.20:** `LightSource` drives the owner's `BudgetLight` (D13-1). Overlay 2's rings: 1.11 ledger.
- **1.22 / 1.23:** the cache (CACHE) and the flare (ALWAYS) are `BudgetLight`s (D13-2, D13-3). 1.23: "the overlay counts it" holds automatically through the group.
- **1.33:** boot screens must not swallow `--room` / `--perf` (1.11 ledger item, owner 1.33).
- **E2 (the Weaver arena):** wider than 360 px, so D2's rect matters there. Weaver eye glows probably rank GLOW, or a new rank decided there.
- **E7:** the 10-minute Layer 1 performance pass (NFR1) can reuse `--perf`'s summary with a longer `<s>`, or by hand.

### References

- `epics.md`:
  - Story 1.12 (≈ `:1627-1648`), Story 1.13 (≈ `:1650`), Story 1.15 (≈ `:1694`), Story 1.16 (≈ `:1717`), Story 1.20 (≈ `:1822`), Stories 1.22–1.23 (≈ `:1888-1948`);
  - AR5 (`:202`), AR6, AR20, AR26 (`:232`), AR46 (`:273`), AR51 (`:284`), AR53–AR54;
  - NFR1, NFR5 (`:172`, `:176`), NFR8–NFR9.
- `game-architecture.md`:
  - Technical Requirements (≈ `:126-150`, "Visible play rect");
  - Technical Risks (≈ `:177-190`);
  - Engine-Provided Architecture, Rendering (≈ `:233`);
  - Decision Summary row 14 (≈ `:285`);
  - Lighting (≈ `:438-443`);
  - Debug Tools (≈ `:608-632`);
  - Enforcement (≈ `:645-670`);
  - Directory Structure (≈ `:680-790`);
  - System Location Mapping (≈ `:801-828`).
- GDD:
  - Technical Specifications, Performance Requirements (≈ `:653-662`);
  - Open Questions (≈ `:786-787`: bloom, flare cap);
  - Difficulty Curve (≈ `:455`: Old Mine ≥ 1 lurker per screen);
  - Level Types (≈ `:521-531`);
  - Art Style (reserved colours, ledge rims).
- `project-context.md`: Performance Rules, Engine-Specific Rules (play rect, physics interpolation), Code Organization (`dev/`), Testing Rules.
- `deferred-work.md`: "Deferred from: dev of 1-11-…", items 1 and 2 (Owner: Story 1.12).
- Prior stories:
  - `1-11-…md` (D6 `--chain`, D9–D10 overlays and light count, D15 ledger items 1–2, red-check pattern);
  - `1-7-…md` (D8, CameraRig and play rect, physics interpolation);
  - `1-10-…md` (dev rooms validated only).
- **Code:**
  - `game/scripts/core/fx.gd`;
  - `game/scripts/world/world.gd`, `camera_rig.gd`, `room.gd`, `room_loader.gd`;
  - `game/scripts/actors/player.gd`, `lurker.gd`, `player_input.gd` (`lock()`);
  - `game/scripts/dev/dev_tools.gd`, `overlays.gd`;
  - `game/scenes/actors/player.tscn`, `lurker.tscn`;
  - `game/tests/spec.gd`, `test_lint.gd`, `test_dev_args.gd`, `smoke_dev_tools.gd`, `smoke_rooms.gd`, `room_sweep.gd`.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

- Story context created by gds-create-story on 2026-11-19. Ultimate context engine analysis completed: a comprehensive developer guide. Engine probes (glow, additive sprite glow, SceneState, frame timing) and a validated `perf_worst` grid are in "Verified facts" and D9. sonlm decided D1 (the `--perf` autopilot) and D2 (the budget counts the whole view) on 2026-11-19.
- A fresh-context adversarial review of the draft (code accuracy, feasibility, test design, coverage; probes in a scratch copy) found 1 critical, 3 should-fix and 7 minor issues, each verified and folded in before ready-for-dev:
  - The critical one: the budget ran before the actors, so a waking glow drew past the budget for a frame. It moved to the `LightBudget` node at priority 50 (D5).
  - The others:
    - two more `smoke_dev_tools` pins;
    - the hoverer wording;
    - `timeout` on the export check;
    - `smoke_rooms` +2;
    - stats buckets by frame start;
    - `_chain_given`;
    - stand-in texture before `add_child`;
    - the camera `snap()`;
    - guarded scene-audit reads;
    - the CACHE placed farthest;
    - the plain `--room=perf_worst`;
    - the first-second hitch.

### File List
