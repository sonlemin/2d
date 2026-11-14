---
baseline_commit: 85bb1ed
---

# Story 1.3: Tuning as data

Status: done

**Type:** dev (no human gate; done when every AC passes and `run_tests.sh` is green) · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP1 Foundations (1.1–1.15) · **Branch:** `feat/m2-e1`

## Story

As the developer,
I want every number a rule could bend to live in `rules/tuning.gd`,
so that gear, assists and playtests change values in one place that matches the GDD tables.

## Acceptance Criteria

1. **The 44 exports migrate** (AR3, AR15). The 44 `@export` vars on `player.gd` (28), `crawler.gd` (5) and `lurker.gd` (11) each get a new home, per Dev Notes → *Migration map*:
   - Each bendable value becomes a `const` in `scripts/rules/tuning.gd` with a `##` comment giving its unit, its intent and "was X", and is listed in `BASE`.
   - Values no system will bend stay local consts on their actor: presentation numbers, the sensing rule that Story 1.20 moves into `Sensing`, and the Snuff hold that becomes a `Settings` value in Story 1.8.
   - `crawler.hover` stays a per-instance property, because the spawner sets it.
   - The chain-curve consts that `test_chain_state` reads (`MAX_CHAIN`, `BASE_RADIUS`, `RADIUS_GAIN`, `SNUFF_RADIUS`, `BASE_BLOOM`, `BLOOM_GAIN`) stay in `ChainState`. No gear bends them in M2, and that test must stay unchanged.
   - No `@export` remains in `scripts/`.
2. **Regression fixture** (FR1–FR8, FR58). `tests/test_tuning.gd` iterates over a fixture of all 44 M1 `@export` defaults:
   - Each row is marked as moved to `Tuning` (with its key or keys) or kept local (with its new home).
   - Every value must still equal its M1 default.
   - A moved property must be gone from its actor script.
   - The fixture also pins the playtested FR values that live outside the exports:
     - the player's body, hurtbox, slash and pogo boxes (10×20, 8×18, 22×16, 26×24)
     - the chain cap (20) and the light curve (40 + 22·√links: 40 / 84 / 110 / 138 px at 0 / 4 / 10 / 20 links)
     - Blade Bloom ×(1 + 0.18·√links), up to ×1.8
     - Snuff light 12 px
     - the hitstop depth ×0.05
3. **The `Tuning` API** (AR15, AR16):
   - `f(&"key")` returns the current value and asserts on an unknown key.
   - `flag(&"key")` returns a gear rule switch and asserts on an unknown flag.
   - `apply_gear(ids)` applies modifiers in the fixed order set → add → mul, whatever order the gear comes in, then emits `changed`.
   - The gear table (`rules/gear.gd`) is empty until E5.
   - `tests/test_tuning.gd` covers the ordering with fixture modifiers.
   - `rules/tuning.gd` and `rules/gear.gd` mention no `Node`, `Input`, `Engine` or `Game.`.
4. **`Game.tuning`** (AR11). `Game` holds one `Tuning` instance for the whole session.
   - Actors read `Game.tuning.f(&"key")` each tick and never cache a value across frames.
   - Every Story 1.2 regression count still holds. `smoke_shaft` changes only its two harness lines that read a moved export, and no `check(` line changes.

## Tasks / Subtasks

Run everything from `game/` and wrap every Godot run in `timeout`.

- [x] **Task 1: Baseline** (AC: 4)
  - [x] Run `timeout 400 ./run_tests.sh` and expect:
    - `test_chain_state`: `ALL PASS (69 checks)`
    - `test_log`: 7 `ok` + `PASS`
    - `test_clock`: 15 `ok` + `PASS`
    - `test_deferred_owners`: 21 `ok` + `PASS`
    - `smoke_shaft`: 28 `ok` + `SMOKE PASS`
    - the last line: `== ALL GREEN`
  - [x] Record the counts in the Debug Log. They are the regression bar for Task 4 and Task 6.
- [x] **Task 2: `Tuning` and `Gear`** (AC: 1, 3)
  - [x] Create `scripts/rules/gear.gd` per Dev Notes → *Gear*.
  - [x] Create `scripts/rules/tuning.gd` per Dev Notes → *Tuning* and *Migration map*: 34 keys in `BASE`, each const commented per *Const comments*.
  - [x] Create `tests/test_tuning.gd` with the API and purity cases from Dev Notes → *test_tuning*. Its regression fixture comes in Task 4, because the "moved property is gone" checks fail until the actors migrate.
  - [x] Add `test_tuning` to the `for t in …` list in `run_tests.sh`, after `test_clock`.
- [x] **Task 3: `Game.tuning`** (AC: 4)
  - [x] In `scripts/core/game.gd`, add `var tuning := Tuning.new()` beside `clock`, and update the header comment: 1.4 still adds settings, slot, dive and devices.
  - [x] Add the `Game.tuning` case to `test_tuning.gd` (Dev Notes → *test_tuning*). It can't land in Task 2, because `Game.tuning` doesn't exist yet.
- [x] **Task 4: Migrate the actors** (AC: 1, 2, 4). Use one actor at a time and run `run_tests.sh` after each.
  - [x] `player.gd`: delete the 28 exports. Add the 5 local consts from the map, plus `HITSTOP_SCALE := 0.05` (Dev Notes → D3). Replace every use with `Game.tuning.f(&"…")` per the map. The two `Vector2` exports become two keys each.
  - [x] `crawler.gd`: delete the 5 exports. `hover` becomes `var hover := false` (per instance). The other 4 values read `Tuning`.
  - [x] `lurker.gd`: delete the 11 exports. Add the 6 local consts. The other 5 values read `Tuning`.
  - [x] `tests/smoke_shaft.gd`, harness lines only:
    - line 95: `_player.cling_time` → `Game.tuning.f(&"cling_grace")`
    - line 267: `lurker.hunt_speed` → `Game.tuning.f(&"lurker_hunt_speed")`
  - [x] Add the regression fixture and the FR-values case to `test_tuning.gd` (Dev Notes → *test_tuning*).
- [x] **Task 5: Docs and project-context** (fix facts only; the docs get regenerated later)
  - [x] `docs/component-inventory.md`:
    - The player's "Exported tuning" table becomes a "Tuning keys (`rules/tuning.gd`)" table with the new key names, plus a line naming the local consts.
    - Do the same for the crawler's and the lurker's tuning tables.
    - Add rows for `Tuning` and `Gear` to the Core table that 1.2 added.
  - [x] `docs/development-guide.md` → Common Tasks:
    - "Tune movement or combat feel" and "Tune a lurker" now point to the consts in `scripts/rules/tuning.gd`, and say: change the matching GDD table too, and keep `LURKER_TELEGRAPH_TIME ≥ 0.75`.
    - The Player node's Inspector no longer shows them.
  - [x] `docs/source-tree-analysis.md`:
    - In the tree block, add `scripts/rules/{tuning,gear}.gd` and `tests/test_tuning.gd`.
    - Line 115 ("Tuning lives in code: `@export` vars …") says tuning is consts in `rules/tuning.gd`, read through `Game.tuning`. Chain-curve consts stay in `ChainState`, and presentation consts stay on their actors.
  - [x] `docs/architecture.md`: add a `test_tuning.gd` row to the Testing Strategy table. Line 204 ("Tuning names match the GDD tables") gains "keys live in `rules/tuning.gd`".
  - [x] `game/README.md` → Tests: add a `test_tuning.gd` line.
  - [x] `_bmad-output/project-context.md` → "Current State vs Target": add one sentence after the 1.2 sentence: "Story 1.3 moved the M1 `@export` tuning into `scripts/rules/tuning.gd` (read through `Game.tuning`) and added an empty `rules/gear.gd`." Remove nothing else.
- [x] **Task 6: Verify** (AC: 1–4). Every grep below must print nothing.
  ```bash
  godot --headless --path . --import 2>&1 | grep -E 'SCRIPT ERROR|ERROR:'
  timeout 60 godot --headless --path . --quit-after 120 2>&1 | grep -E 'SCRIPT ERROR|ERROR:'   # main-scene boot
  for t in test_chain_state test_log test_clock test_tuning test_deferred_owners smoke_shaft; do
    timeout 150 godot --headless --path . res://tests/runner.tscn -- res://tests/$t.gd 2>&1 | grep -E 'SCRIPT ERROR|ERROR:'; done
  grep -rn "@export" scripts/
  grep -nE '\b(Node|Input|Engine)\b|\bGame\.' scripts/rules/tuning.gd scripts/rules/gear.gd
  git diff -U0 85bb1ed -- tests/smoke_shaft.gd tests/test_chain_state.gd | grep -E '^[-+].*check\('
  timeout 400 ./run_tests.sh     # Task 1 counts + test_tuning, ends "== ALL GREEN"
  timeout 120 xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy res://tests/runner.tscn -- res://tests/screenshot.gd /tmp/shots   # exit 0, two PNGs
  ```
  - [x] The raw per-test greps also cover exit-time errors. A test that creates a node and never frees it leaks RIDs, and the engine prints `ERROR: … leaked at exit` after the runner has finished (verified; see *Verified on the server*). Story 1.9's gate will fail on those lines.
- [x] **Task 7: Commit.** Use conventional prefixes, and leave `run_tests.sh` green at every commit. Suggested split:
  - `feat:` `Tuning`, `Gear`, `Game.tuning` and the API half of `test_tuning` (Tasks 2–3)
  - `refactor:` the actor migration, the two `smoke_shaft` lines and the regression fixture (Task 4)
  - `docs:` (Task 5)
  - Commit each new `.gd.uid` beside its script.

### Review Findings

Code review 2026-11-12 (gds-code-review; Blind Hunter, Edge Case Hunter, Acceptance Auditor) of `6b7ca37..9fa8ba3`. The story record and the sprint status were excluded.
- The Auditor found no AC violation and re-ran the Task 6 checks green.
- The findings are validation and test-strength gaps, plus doc accuracy.
- sonlm chose "apply every patch". All six were fixed in `feb14e5`, and `run_tests.sh` stays ALL GREEN (`test_tuning` 85 checks, `test_deferred_owners` 22).
- A probe confirmed that an id-less gear row now raises one clear `_check_row` assert. Mutation checks confirmed that a misspelled key fails both literal-scan checks.
- 17 were dismissed: spec decisions, non-issues verified by grep, or items owned by later stories.

- [x] [Review][Patch] A gear row is validated only when owned, and a row with no `id` never reaches the check [game/scripts/rules/tuning.gd:121-124,161-170]
  - **Cause:** the filter reads `row.id` before `_check_row()` runs.
  - **Effect:** an id-less row prints a SCRIPT ERROR and is silently dropped (Auditor probe on 4.7.2). A malformed row in `Gear.TABLE` stays hidden until someone owns that gear.
  - **Fix:** run `_check_row()` over every row of `table` before filtering. `Game.tuning`'s `_init` calls `apply_gear([])`, so a bad `Gear.TABLE` row then fails every debug run at boot, test runner included, and can't reach a release build.
- [x] [Review][Patch] 23 of the 34 const comments have no intent clause [game/scripts/rules/tuning.gd:18-63]
  - **Rule:** Dev Notes → *Const comments* requires `## <unit>; <intent> (<source>). Was X.`
  - **Examples:** `RUN_SPEED`, `GRAVITY`, `WALL_KICK_Y`, `SLASH_ACTIVE`, `HITSTOP`, `KNOCKBACK_X` / `_Y`, `CRAWLER_HOVER_PERIOD` and `LURKER_HUNT_SPEED` only name the quantity. Units, sources and was-values are correct on all 34.
  - **Fix:** add the `; intent` part, taken from the GDD or the M1 comments, never invented.
- [x] [Review][Patch] The `Tuning` header overclaims [game/scripts/rules/tuning.gd:3-13]
  - "Never keep a value across frames" contradicts the countdowns the spec allows: `_coyote`, `_buffer`, `_dash_left`, `_cling_left` and the rest start from a value.
  - "Every gameplay number a rule could bend" isn't true while the spec keeps M1 literals in place: the crawler's 400 px/s fall cap and the lurker's ×2 lost-scent brake.
  - **Fix:** say "read where used; a countdown may start from the current value, but no value is kept for reuse", and list the unmoved literals under "Not here". The Dev record's countdown list also misses `_coyote` and `_buffer`.
- [x] [Review][Patch] Nothing checks the `f(&"…")` key literals [game/scripts/actors/*.gd, game/tests/test_tuning.gd]
  - The refactor swapped compile-checked identifiers for `StringName` literals.
  - A typo or an unwired key in a branch no test drives (dash, knockback, coyote, jump buffer) fails only when played, and only in a debug build.
  - **Fix:** a `test_tuning` case that scans `res://scripts/` for `f(&"…")`. Every literal must be a `BASE` key, and every `BASE` key must be read at least once.
- [x] [Review][Patch] The order comment's arithmetic is wrong [game/tests/test_tuning.gd:116]
  - From base 18, the five wrong orders give 5, 3, 1, 3, 1, not "3, 5 or 7" (the spec's wording, copied).
  - **Fix:** "Any other order gives 1, 3 or 5."
- [x] [Review][Patch] `game-architecture.md` still names the removed `lurker.telegraph_time` [_bmad-output/game-architecture.md:1134,1154]
  - Story 1.9 builds its Spec check from these lines.
  - **Fix:** use `Game.tuning.f(&"lurker_telegraph_time")`.
- [x] [Review][Defer] No floor holds once gear bends a value [game/scripts/rules/tuning.gd:126-145] — deferred, latent.
  - The editor-only `@export_range(0.75, 3.0)` was the telegraph's only guard.
  - A gear `set` / `mul` row could push `lurker_telegraph_time` under 0.75 s (Pillar 2), or `crawler_hover_period` to 0 (NaN drift).
  - Unreachable while `Gear.TABLE` is empty.
  - Proposed owner: Story 1.9 (see `deferred-work.md`).

## Dev Notes

### What this story is (and isn't)

It moves the M1 tuning out of the Inspector and into one pure, testable table. It is a **pure refactor**: every value keeps its M1 number, so the game must play exactly the same. The regression fixture proves the values are the same, and the smoke test proves the behaviour is.

**Do not, in this story:**
- **Change any value.** Each number equals its M1 default, so no GDD table changes. If a value looks wrong, note it in the Debug Log for the CP1/CP2 gates.
- **Add gear entries.** `Gear.TABLE` stays empty until E5. Long Wick, Steady Grip, Silk Grip and Quick Wick arrive with their stories.
- **Wire `Game.tuning` to `Game.slot.gear`.** `SlotState` arrives in Story 1.4. `Game` only creates the instance here.
- **Add keys for later features**, such as `flare_burn` (1.23), `bank_heal_min` (1.19) or the cache glow radius (1.22). Each story adds its own keys.
- **Move the camera code** (`_process`'s lead, shake and `randf_range`) into `camera_rig.gd` (1.6), **replace `Input` reads** (1.8), or **replace `get_viewport_rect()` / `get_first_node_in_group("player")`** in the lurker (1.20). Only the numbers move here.
- **Touch `ChainState`**, or any literal that isn't one of the 44 exports (the crawler's `400.0` fall cap, `7.0` ray offset, `0.37`/`0.11` phase seeds, the player's `12.0`/`20.0`/`140.0` easing rates). The single exception is `HITSTOP_SCALE` (D3).
- **Re-save any scene in the editor.** No `.tscn` changes in this story.

### Current state (read before changing)

- **`player.gd` (339 lines)**:
  - Lines 10–39 hold 28 `@export`s in two groups ("Movement tuning", "Combat tuning").
  - `const LIGHT_TEXTURE_HALF := 64.0` stays.
  - The values are read in `_ready` (`cling_time`), `_physics_process`, `_process` (`look_ahead`), `_handle_*`, `_on_pogo_hit`, `_freeze_frame` (`hitstop`, plus the literal `0.05`), `_update_light` and `_take_knockback`.
  - `_handle_cling` uses `wall_kick.x` / `.y`; `_take_knockback` uses `knockback.x` / `.y`.
- **`crawler.gd` (48 lines)**:
  - `hover` is set per instance by `shaft.gd:198` (`crawler.hover = row[x] == "h"`, before `add_child`) and read by `smoke_shaft.gd:60` (`if e.hover`).
  - `reset_phase()` seeds `_t` from `hover_period` once, in `_ready`.
- **`lurker.gd` (123 lines)**:
  - `telegraph_time` is `@export_range(0.75, 3.0)`. That range guard was editor-only; Story 1.9's `Spec.TELEGRAPH_MIN` test takes over, and this story's fixture pins 0.9.
  - `_enter(TELEGRAPH)` starts `_timer = telegraph_time`, a countdown taken at entry, not a cached tuning value.
- **No scene overrides any of the 44.** `player.tscn`, `crawler.tscn`, `lurker.tscn` and `shaft.tscn` set none of them (checked), so a const with the script default keeps the exact runtime value.
- **Readers outside the actors:**
  - `smoke_shaft.gd:95` reads `_player.cling_time`.
  - `smoke_shaft.gd:267` reads `lurker.hunt_speed`.
  - `shaft.gd:198` writes and `smoke_shaft.gd:60` reads `crawler.hover`.
  - Nothing else reads the exports (`grep` over `tests/`, `scripts/shaft.gd` and `scripts/core/`).
- **`Game`** (`core/game.gd`) holds only `clock` today.

### Migration map (the 44, with key names)

The 34 `Tuning` keys come from 32 exports, because the two `Vector2`s each split into `_x` / `_y` (`f()` returns a float, and a gear `add` or `mul` acts on one axis). There are 12 local homes. The const name is the key in UPPER_SNAKE (`run_speed` → `RUN_SPEED`).

**`player.gd` (28): 23 → `Tuning` (25 keys), 5 local.**

| M1 export | Value | Home | GDD / FR |
|---|---|---|---|
| `run_speed` | 110.0 | `run_speed` | Movement · FR1 |
| `run_accel` | 900.0 | `run_accel` | Movement ("ground accel") · FR1 |
| `air_accel` | 1500.0 | `air_accel` | Movement · FR1 |
| `gravity` | 900.0 | `gravity` | Movement · FR1 |
| `max_fall` | 210.0 | `max_fall` | Movement · FR1 (was 330) |
| `fall_gravity_scale` | 0.6 | `fall_gravity_scale` | Movement · FR1 |
| `jump_velocity` | -330.0 | `jump_velocity` | Movement · FR1 (was -270) |
| `jump_cut` | 0.45 | `jump_cut` | Movement ("release early ×0.45") · FR1 |
| `coyote_time` | 0.08 | `coyote_time` | Movement · FR1 |
| `jump_buffer` | 0.10 | `jump_buffer` | Movement · FR1 |
| `dash_speed` | 260.0 | `dash_speed` | Movement · FR2 |
| `dash_time` | 0.12 | `dash_time` | Movement · FR2 |
| `cling_time` | 1.0 | **`cling_grace`** | Chain-end table + Wall cling · FR6, FR7 (AR16 gear name: Silk Grip +0.25) |
| `cling_slide` | 18.0 | `cling_slide` | Wall cling · FR7 (Steady Grip → 10) |
| `wall_kick` | (150, -260) | **`wall_kick_x`, `wall_kick_y`** | Wall cling · FR7 |
| `kick_lock` | 0.15 | `kick_lock` | Wall cling · FR7 |
| `pogo_velocity` | -300.0 | `pogo_velocity` | Attack, pogo · FR4 (was -260) |
| `swing_active` | 0.12 | **`slash_active`** | Attack · FR4 |
| `air_swing_active` | 0.22 | **`pogo_armed`** | Attack ("armed 0.22 s") · FR4 |
| `swing_cooldown` | 0.22 | **`attack_cooldown`** | Attack · FR4 (the code applies it to both slash and pogo) |
| `hitstop` | 0.075 | `hitstop` | Attack ("75 ms") · FR4 (was 0.045) |
| `knockback` | (150, -150) | **`knockback_x`, `knockback_y`** | Health and damage · Story 1.19 |
| `invuln_time` | 0.6 | `invuln_time` | Health and damage · Story 1.19 |
| `shake` | 2.5 | local `SHAKE` | presentation; moves to `camera_rig.gd` in 1.6 |
| `look_ahead` | 70.0 | local `LOOK_AHEAD` | camera pixel offset (FR3, GDD Movement "Camera"); moves to `camera_rig.gd` in 1.6 |
| `light_kick` | 18.0 | local `LIGHT_KICK` | presentation: the visible light only. Sensing reads `chain.light_radius()`, not `_shown_radius` |
| `light_lerp` | 10.0 | local `LIGHT_LERP` | presentation easing |
| `snuff_hold` | 0.12 | local `SNUFF_HOLD` | **never a `Tuning` key**: it is `Settings.light_tap_window` (architecture → Input; GDD "default 0.12 s"). Story 1.8's `PlayerInput` replaces it |

Plus one new local const that isn't an export: `HITSTOP_SCALE := 0.05` (D3).

**`crawler.gd` (5): 4 → `Tuning`, 1 per-instance.**

| M1 export | Value | Home | GDD / FR |
|---|---|---|---|
| `hover` | false | `var hover := false` (per instance; no `@export`) | set by the spawner: `shaft.gd` now, room spawn args from 1.5/1.6 |
| `walk_speed` | 25.0 | `crawler_walk_speed` | Combat (walker); no number in the GDD yet |
| `gravity` | 900.0 | `crawler_gravity` | not in the GDD |
| `hover_drift` | 10.0 | `crawler_hover_drift` | Combat ("drifts 10 px side to side") · FR58 |
| `hover_period` | 2.4 | `crawler_hover_period` | Combat ("over 2.4 s") · FR58 |

**`lurker.gd` (11): 5 → `Tuning`, 6 local.**

| M1 export | Value | Home | GDD / FR |
|---|---|---|---|
| `telegraph_time` | 0.9 | `lurker_telegraph_time` | Lurker ("0.9 s, never below 0.75") |
| `lose_track_time` | 0.6 | `lurker_lose_track_time` | Lurker ("waits 0.6 s") |
| `hunt_speed` | 95.0 | `lurker_hunt_speed` | Lurker ("95 px/s") |
| `hunt_accel` | 220.0 | `lurker_hunt_accel` | not in the GDD |
| `return_speed` | 40.0 | `lurker_return_speed` | not in the GDD |
| `notice_min_radius` | 80.0 | local `NOTICE_MIN_RADIUS` | the sensing rule: the architecture puts it in `rules/sensing.gd` (`Sensing.NOTICE_MIN_RADIUS`), and Story 1.20 moves it there |
| `notice_factor` | 1.6 | local `NOTICE_FACTOR` | the same (`Sensing.NOTICE_FACTOR`, 1.20) |
| `screen_margin` | 8.0 | local `SCREEN_MARGIN` | the same: the play rect "shrunk by the screen margin" (1.20) |
| `eye_pulse_hz` | 2.0 | local `EYE_PULSE_HZ` | presentation, and capped by accessibility (≤ 2 Hz pulses), so no system may raise it |
| `glow_energy` | 1.3 | local `GLOW_ENERGY` | presentation |
| `eye_open_time` | 0.2 | local `EYE_OPEN_TIME` | presentation |

Totals: `Tuning` 23 + 4 + 5 = 32 exports (34 keys); local 5 + 6 = 11 consts; per-instance 1. That makes 44.

### Decisions

- **D1, what goes into `Tuning`** (story author): **gameplay numbers** (movement, combat, timing, damage and enemy behaviour) go into `Tuning`, whether or not gear bends them in M2. That is the epic's "playtests change values in one place that matches the GDD tables", and AR3 sends the M1 `@export` tuning there. Local consts keep the rest:
  - **presentation numbers** (camera kick and lead, light easing and flare, eye animation and glow), the AC's "pixel offsets"
  - **the sensing rule**, which the architecture assigns to `Sensing` (1.20)
  - **`snuff_hold`**, which the architecture rules is never a `Tuning` key
  - The architecture's stricter wording ("any number that gear, a later ability or an assist might change") would leave almost nothing in `Tuning` in M2, which contradicts AR3/AR15 and the AC's list.
- **D2, key names** (story author): M1 names are kept unless one of these applies:
  - **`cling_time` → `cling_grace`**: the AR16 gear table and the architecture's examples already use `cling_grace` (Silk Grip `add 0.25`).
  - **`swing_active` / `air_swing_active` / `swing_cooldown` → `slash_active` / `pogo_armed` / `attack_cooldown`**: in M2, "Swing" is the rope ability (FR51, E6). These names match the GDD's wording ("Slash active 0.12 s", "Pogo armed 0.22 s").
  - **The `Vector2` exports split into `_x` / `_y`**, since `f()` returns floats.
  - **Enemy keys get a `crawler_` / `lurker_` prefix.** Player keys stay bare, as the architecture's `cling_slide` / `flare_burn` do.
- **D3, the hitstop depth `0.05` stays local** as `const HITSTOP_SCALE := 0.05` in `player.gd`. Story 1.2 left this decision to 1.3.
  - The GDD specifies the 75 ms duration, which is tunable and becomes `Tuning` `hitstop`.
  - ×0.05 only makes the freeze a freeze, and no system bends it.
  - `_freeze_frame()` becomes `Game.clock.request(&"hitstop", HITSTOP_SCALE, Game.tuning.f(&"hitstop"))`, keeping its `<= 0.0` guard.
- **D4, `f()` reads precomputed values** (deviation from the architecture's sample, same semantics):
  - The architecture's sample loops over every modifier on each `f()` call, but actors call `f()` many times per tick (hot path).
  - Instead, `apply_gear()` computes the effective values once into `_values`, so `f()` is one assert plus one dictionary lookup.
- **D5, `apply_gear(gear_ids, table := Gear.TABLE)`** (story author):
  - The optional `table` lets `test_tuning` inject fixture modifiers while the real table is empty (the AC's "fixture modifiers").
  - Gear ids not in the table are ignored. E5 decides how a save's unknown gear id is reported, once the table has entries.
  - A malformed modifier (unknown stat, unknown op, or a `flag` modifier naming an unknown flag) is a programmer error in a code table, so it asserts.
  - **Two `set` modifiers on one stat assert**: otherwise the result would depend on gear order, which AR16 forbids.
- **D6, `Tuning` has no `to_dict()` / `from_dict()`** (story author): its state is derived from `SlotState.gear`, which is what gets saved. `apply_gear([])` is its reset in place. Story 1.4's `Game.reset_for_tests()` calls it, and 1.4/E5 rebuild it when the slot's gear changes, on the same instance.

### Tuning (`scripts/rules/tuning.gd`, `class_name Tuning`, `extends RefCounted`)

- **Header comment:**
  - Name AR15/AR16 and the rule "change a value → update the matching GDD table".
  - Say that the consts are the playtested M1 values unless noted.
  - Don't mention the autoload by name. Write "the session's instance lives in `core/game.gd`", because AC3 and the 1.9 lint forbid `Game.` in `rules/`.
- **Consts:** 34, grouped by subject (Movement, Dash, Cling, Attack, Damage, Crawler, Lurker), in the order of the map. See *Const comments*.
- **`const BASE := {&"run_speed": RUN_SPEED, …}`**: all 34, keyed by `StringName`. This form was verified on 4.7.2.
- **`const FLAGS: Array[StringName] = [&"instant_snuff"]`**: the one rule switch AR16 defines (Quick Wick). Nothing reads it before E5/E6, but it gives `flag()` a known set to assert against.
- **`const OPS: Array[StringName] = [&"set", &"add", &"mul"]`**: the fixed order.
- **`signal changed`.**
- **State:** `var _values := {}` and `var _flags := {}`. `_init()` calls `apply_gear([])`, so a fresh `Tuning` holds the base values.
- **`apply_gear(gear_ids: Array[StringName], table: Array[Dictionary] = Gear.TABLE) -> void`:**
  - Filter `table` to the rows whose `id` is in `gear_ids`.
  - Start from `_values = BASE.duplicate()`, because a const dictionary is read-only.
  - For each op in `OPS`, apply that op's modifiers: `set` → `value`, `add` → `v + value`, `mul` → `v * value`. Assert as in D5.
  - Then set `_flags[stat] = true` for each `flag` row.
  - Emit `changed` once.
- **`f(key: StringName) -> float`:** `assert(_values.has(key), "Tuning: unknown key '%s'" % key)`, then return `_values[key]`.
- **`flag(key: StringName) -> bool`:** `assert(key in FLAGS, …)`, then return `_flags.has(key)`.
- **No `class_name` or method mentions `Node`, `Input`, `Engine` or `Game.`.** Comments included, because the purity test scans the whole source.

### Const comments

Write one line per const, `## <unit>; <intent> (<source>). Was X.` Rules for the parts:
- **The "was" part** is the history from the M1 comments: `max_fall` was 330, `jump_velocity` was -270, `pogo_velocity` was -260, `hitstop` was 0.045. For every other const, write "M1 value, unchanged".
- **The source** names the GDD section, the FR and the M1 export it came from, so the fixture and the GDD can be cross-read.

Examples:
```gdscript
const MAX_FALL := 210.0  ## px/s terminal fall; slowed so a dive reads and ledges come in time (GDD Movement, FR1; M1 player.max_fall). Was 330.
const CLING_GRACE := 1.0  ## s of paused chain per cling; a pogo hit refills it (GDD Wall cling, FR6/FR7; M1 player.cling_time). Silk Grip +0.25 (E6). M1 value, unchanged.
const LURKER_TELEGRAPH_TIME := 0.9  ## s of eyes-open warning before a hunt; never below 0.75 (Pillar 2, GDD Lurker; Spec.TELEGRAPH_MIN from 1.9; M1 lurker.telegraph_time). M1 value, unchanged.
const CRAWLER_GRAVITY := 900.0  ## px/s² for walkers; not in a GDD table yet (M1 crawler.gravity). M1 value, unchanged.
```
Local consts on actors get the same `##` style, with the reason they are local: "presentation", "moves to camera_rig.gd in 1.6", "Sensing in 1.20", or "Settings.light_tap_window in 1.8".

### Gear (`scripts/rules/gear.gd`, `class_name Gear`)

- No `extends` is needed (pure data). The header cites AR16: `{id, stat, op, value}`, `op` is one of `set` / `add` / `mul` / `flag`, and gear bends rules and never adds raw power.
- `const TABLE: Array[Dictionary] = []`, with a comment saying that E5/E6 add Long Wick, Steady Grip, Silk Grip and Quick Wick.

### Reading `Tuning` in the actors

- **Each tick, never cached across frames:** inside a function, `var t := Game.tuning` and then `t.f(&"…")` several times is fine. Storing a value in a member var to reuse next frame is not.
- **Allowed exceptions, because they are timers and seeds, not cached tuning:**
  - `_cling_left = …f(&"cling_grace")` on land, pogo and `_ready`
  - `_dash_left = …f(&"dash_time")`, `_swing_left`, `_swing_cd`, `_invuln`, `_kick_left` and the lurker's `_timer`: countdowns started from the value at that moment
  - the crawler's `reset_phase()` seed
- **Vectors:**
  - `velocity = Vector2(-_cling_side * t.f(&"wall_kick_x"), t.f(&"wall_kick_y"))`
  - `velocity = Vector2(t.f(&"knockback_x") * (away if away != 0.0 else -_facing), t.f(&"knockback_y"))`
- **The "Movement tuning" / "Combat tuning" comment headers go.** Local consts sit together under the class's other consts, each with its `##` reason.

### test_tuning (`tests/test_tuning.gd`)

Same harness as `test_clock`: `extends Node`, `func run()`, a local `check()`, and a final `PASS` / `FAILED (n)`. Build a fresh `Tuning.new()` per case. Never use `Game.tuning` for the API cases.

- **API cases (Task 2):**
  - A fresh `Tuning` returns each `BASE` value, and `BASE.size() == 34`.
  - **Ordering:** with fixture modifiers on one stat (`set 1.0`, `add 2.0`, `mul 3.0`, each on its own gear id), every one of the 6 orders of the 3 ids gives `(1 + 2) × 3 = 9`. A wrong order gives 3, 5 or 7, so this case also catches add/mul swaps.
  - Modifiers on one stat leave the other stats at base.
  - Unknown gear ids change nothing.
  - **Flags:** `flag(&"instant_snuff")` is false by default, true with a fixture `flag` modifier, and false again after `apply_gear([])`.
  - **`changed`:** emitted exactly once per `apply_gear()` (count through a lambda that captures an array, as the prototype did).
  - **Reset in place:** after a modded `apply_gear`, `apply_gear([])` restores every base value on the same instance.
  - `Gear.TABLE.is_empty()` (empty until E5).
  - `Game.tuning is Tuning` and returns the base values (`cling_grace` 1.0). This case lands with Task 3.
  - **Purity:** read `res://scripts/rules/tuning.gd` and `gear.gd` with `FileAccess.get_file_as_string()` and check `FileAccess.get_open_error() == OK`; an unreadable file must fail, never pass (the 1.1 review lesson). Then check that `\b(Node|Input|Engine)\b|\bGame\.` finds nothing.
  - **Not unit-tested,** because a failed assert would abort the test: the unknown-key, unknown-flag, malformed-modifier and double-`set` asserts. Code review checks them, as with `Log`'s category assert.
- **Regression fixture (Task 4):** a `const M1` array with one dictionary per export, all 44, copied from the map above. Values come from the M1 code, never from `Tuning`.
  - A moved row: `{m1 = "player.run_speed", value = 110.0, keys = [&"run_speed"]}`. A `Vector2` row has two keys and a `Vector2` value.
  - A local row: `{m1 = "player.shake", value = 2.5, local = "SHAKE"}`.
  - The `hover` row: `{m1 = "crawler.hover", value = false, instance = true}`.
- **Checks over the fixture:**
  - It has 44 rows: 28 player, 5 crawler, 11 lurker.
  - Every moved row's key or keys give the M1 value from a fresh `Tuning`, and the M1 property is gone from the actor script. Check it with `load(script).get_script_property_list()`, which lists script vars; verified.
  - Every local row's const exists with the M1 value. Use `get_script_constant_map()` (verified).
  - `hover` defaults to false on `Crawler.new()`, freed with `queue_free()`. Don't use `get_property_default_value()`: it returns `null` for a non-exported var (verified).
  - Every `BASE` key appears in exactly one fixture row, so no key lacks an M1 source.
- **FR values outside the exports:**
  - `ChainState.MAX_CHAIN == 20`, `SNUFF_RADIUS == 12.0` and `BASE_RADIUS == 40.0`.
  - `radius_for(0/4/10/20)` ≈ 40 / 84 / 110 / 138 (tolerance 0.5; the GDD rounds, giving 109.6 and 138.4).
  - `bloom_for(0) == 1.0` and `bloom_for(20)` ≈ 1.8 (tolerance 0.01; it is 1.805).
  - `Player`'s `HITSTOP_SCALE == 0.05`.
  - Instantiate `player.tscn`, read the four `RectangleShape2D` sizes (`Body`, `Hurtbox/Shape`, `Slash/Shape`, `Pogo/Shape`), then `queue_free()` it. An instance left unfreed leaks RIDs and prints `ERROR:` at exit (verified).

### Verified on the server (Godot 4.7.2.stable, prototype in a scratch copy of `85bb1ed`, 2026-11-12)

- **`Tuning` as designed (D4/D5):**
  - A const `BASE` keyed by `StringName` that references other consts works.
  - `BASE.duplicate()` gives a mutable copy.
  - `apply_gear(ids, table: Array[Dictionary] = Gear.TABLE)` accepts a const default.
  - `Array.filter` with a lambda works.
  - The set → add → mul fixture gave 9.0 in two different orders.
  - `changed` fired once per call; `flag()` and the reset in place worked.
- **`Game` with `var tuning := Tuning.new()`:** `Game.tuning.f(&"cling_grace")` returned 1.0 in a runner test.
- **Introspection:**
  - `get_script_property_list()` lists an actor's script vars (`run_speed` present before migration).
  - `get_script_constant_map()` returns const values (`LIGHT_TEXTURE_HALF` → 64.0).
  - `get_property_default_value(&"hover")` returns `null` once `@export` is removed, so read `hover` from an instance.
  - `Player.LIGHT_TEXTURE_HALF` is readable from a test.
- **Purity regex:** `\b(Node|Input|Engine)\b|\bGame\.` found nothing in the prototype `tuning.gd`.
- **Scene reads:** the shape sizes are readable from an instance (`Slash/Shape` → 22×16).
- **Leak:** an instantiated, unfreed `player.tscn` printed 6 `ERROR: … leaked at exit` lines after `PASS`, and the run still exited 0. With `queue_free()`: 0 lines.
- **Not prototyped:** the actor migration itself. The smoke test and the fixture are its proof.

### Project Structure Notes

- New files:
  - `scripts/rules/tuning.gd` and `scripts/rules/gear.gd`: `rules/` is pure, depends on nothing, and is unit-tested (AR58).
  - `tests/test_tuning.gd`.
- `core/game.gd` gains one ref. `Game` holds refs only, never rules (AR11).
- Naming: `Tuning` and `Gear` are PascalCase `class_name`s; keys are `StringName` snake_case (`&"cling_grace"`); consts are UPPER_SNAKE.
- No addon, no `.tres`, no new autoload.

### Project Context Rules (that apply here)

- **Tuning:**
  - It is data in `rules/tuning.gd`: one `const` per value with a `##` unit, intent and "was X" comment, listed in `BASE`. Actors read `Game.tuning.f(&"key")`.
  - Gear is data in `rules/gear.gd`; never write `if has_gear`.
  - Change a value → update the matching GDD table (none change here).
- **State:** it lives in pure objects; `Game` keeps the same instances all session and resets them in place. Never replace `Game.tuning`; call `apply_gear()` on it.
- **Dependencies point one way:** `rules/` never mentions `Node`, `Input`, `Engine` or `Game` (the 1.9 lint will enforce it; the purity case enforces it now).
- **Code:**
  - Programmer errors are `assert`s.
  - Comments explain *why* and cite the design ("FR7", "AR16", "Pillar 2", "M1 playtest").
  - No bare `print(` in game code.
  - `queue_free()`, never `free()`.
- **Tests:**
  - Add `test_tuning` to the `for t in …` list (1.9's glob comes later).
  - Fresh state objects per test.
  - Keep the `ok` / `FAIL` + `PASS` / `FAILED` format.
  - Never loosen a threshold to pass.
- **Feel:** this is a refactor. Report "tests green; needs a quick feel check on the laptop (no change intended)" and never claim it feels the same.
- **Commits:** commit `.gd.uid` files with their scripts. Never hand-create `.uid` files; `--import` generates them.

### Previous story intelligence (1.2 and its review)

- **Runner contract** (`tests/runner.gd`):
  - `extends Node`, with `func run()` that may `await`.
  - `ok` lines and `[category]` `Log` lines never count as a verdict.
  - Never call `quit()`; the runner fails a test that does.
  - The runner frees the test after `run()` and watches two more frames, so teardown errors fail it.
  - `run()` starts two frames after the test enters the tree.
- **`run_tests.sh`** kills each run after 150 s and shows error lines with their `at:` traces. It still doesn't fail on `ERROR:` outside the runner; that is 1.9's job, hence the raw greps in Task 6.
- **Process:**
  - Wrap every Godot run in `timeout`.
  - Hand-edit and never re-save scenes in the editor.
  - Re-run `--import` after adding a `class_name` (1.1: the cache goes stale).
- **`FileAccess.get_file_as_string()` returns `""` on error**, so check `get_open_error()` (1.1 review).
- **Free every node a test creates.** The 1.2 runner frees the test's own children; a node built outside the tree (`Crawler.new()`) needs `queue_free()`.
- **The pogo hitstop path:**
  - `test_clock._test_pogo_requests_hitstop` calls `player._on_pogo_hit()` and expects `Game.clock` at ×0.05 for about 75 ms.
  - After D3 it must still pass unchanged: it is the behavioural check that `HITSTOP_SCALE` and `Tuning` `hitstop` are wired.
- **Deferred:** the 1.2 review left one ledger item (pause holds the time scale; Owner proposed 1.31). This story doesn't touch it.

### Git intelligence

Recent commits on `feat/m2-e1`:
- `afae546` runner and ports, `03881df` `Log`, `ac637ae` `Game`, `Clock` and hitstop, `4809027` docs, `202666d` the 1.2 record
- `a79ebb6` the 1.2 review fixes (runner blind spots, `test_clock` probes, pogo hitstop check)
- `85bb1ed` the review record, which is this story's baseline

The pattern: `feat:` / `refactor:` / `test:` / `docs:` commits, each leaving `run_tests.sh` green, with `.gd.uid` files committed beside new scripts. No game behaviour has changed since the M1 playtest, so the Task 1 counts are M1's behaviour.

### Cross-story context (Epic 1)

- **1.4:**
  - Adds `Settings`, `SlotState` and `DiveState`.
  - Its AC requires `Game.tuning` to exist and stay the same instance; `reset_for_tests()` should call `tuning.apply_gear([])`.
  - `SlotState.gear` drives `apply_gear` from there (rebuild on change: 1.4 or E5).
- **1.5:** ports the M1 tests and picks targets by position. `smoke_shaft`'s two Tuning reads carry over.
- **1.6:** `camera_rig.gd` takes `SHAKE`, `LOOK_AHEAD` and the `randf_range` shake (FR3, AR27).
- **1.8:** `PlayerInput` takes over the Light tap/hold machine with `Settings.light_tap_window`, which retires `SNUFF_HOLD`. Its real-time jump buffer reads `Tuning` `jump_buffer`.
- **1.9:**
  - `tests/spec.gd` adds `TELEGRAPH_MIN := 0.75`, compared against `Game.tuning.f(&"lurker_telegraph_time")`. The architecture's example still says `lurker.telegraph_time`, which no longer exists after this story.
  - The lint enforces `rules/` purity.
- **1.19 Health:** reads `knockback_x` / `knockback_y` / `invuln_time` and adds `bank_heal_min`.
- **1.20 Sensing:** moves `NOTICE_MIN_RADIUS`, `NOTICE_FACTOR` and `SCREEN_MARGIN` into `rules/sensing.gd`.
- **1.22:** adds the cache glow radius. **1.23:** adds `flare_burn` (4.0 s), plus a flare cap if CP1 recommends one.
- **E5/E6:** fill `Gear.TABLE` (Long Wick `flare_burn` set 6.0, Steady Grip `cling_slide` set 10.0, Silk Grip `cling_grace` add 0.25, Quick Wick flag `instant_snuff`).
- **E7:** timing assists use `Clock.set_assist()`, not `Tuning`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.3: Tuning as data]
- [Source: _bmad-output/planning-artifacts/epics.md#Additional Requirements: AR3, AR4, AR10, AR11, AR15, AR16, AR58; FR1–FR8, FR58]
- [Source: _bmad-output/game-architecture.md#Gameplay Rules and Tuning, #2. Rule-Bending Gear (Tuning), #1. Light-as-Signal (Sensing consts), #Data Patterns, #Consistency Rules, #Input (tap window is a Settings value)]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md#Movement (M1), #Attack, pogo and chain (M1), #Wall cling (M1), #Health and damage, #Predators: Lurker (M1), #Combat System (crawler table)]
- [Source: _bmad-output/implementation-artifacts/m1-playtest-findings.md#Tuning snapshot]
- [Source: _bmad-output/project-context.md#Code Organization Rules, #Testing Rules, #Engine-Specific Rules]
- [Source: _bmad-output/implementation-artifacts/1-2-log-and-a-clock-that-owns-time.md#Review Findings, #Dev Agent Record]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (`claude-opus-5-5`), gds-dev-story, 2026-11-12.

### Debug Log References

- **Task 1 baseline (85bb1ed + story file):** `test_chain_state` ALL PASS (69 checks); `test_log` 7 ok + PASS; `test_clock` 15 ok + PASS; `test_deferred_owners` 21 ok + PASS; `smoke_shaft` 28 ok + SMOKE PASS; `== ALL GREEN`. Matches the story exactly.
- **After each actor migration** (player, then crawler, then lurker): `run_tests.sh` ALL GREEN, with the same counts each time. `test_clock` stayed at 15 ok, including `_test_pogo_requests_hitstop`, which checks the `HITSTOP_SCALE` + Tuning `hitstop` wiring end to end.
- **Task 6 (final):**
  - Import, main-scene boot and the six raw per-test runs printed no `SCRIPT ERROR` / `ERROR:` lines, exit-time leaks included.
  - `grep -rn "@export" scripts/` printed nothing, and so did the purity grep.
  - The `check(` diff against 85bb1ed printed nothing. `smoke_shaft`'s diff is exactly lines 95 and 267.
  - `run_tests.sh`: ALL GREEN with 69 / 7 / 15 / **83** (`test_tuning`) / 21 / 28.
  - The screenshot run exited 0 with two PNGs (chain 10: light 109, lurker telegraph visible). The output went to the session scratchpad instead of `/tmp/shots` (agent sandbox rule); the command is otherwise the same.
- **Red phase:**
  - `test_tuning` was written after `tuning.gd`, so both halves were mutation-tested.
  - OPS swapped to add → set → mul made all 6 order checks fail (got 3.0).
  - Re-adding `@export var run_speed` to `player.gd` and setting `CRAWLER_HOVER_PERIOD` to 2.5 failed exactly those two fixture rows.
  - The `Game.tuning` case was added before the field existed: the runner failed it on the engine error even though the test printed PASS. This shows the 1.2 D3 net working.
  - Every mutation was reverted, and the files were checked afterwards.
- **`assert` messages are evaluated eagerly in debug builds** (probe on 4.7.2: the message expression ran on all 1000 passing asserts). With the formatted message, `f()` costs about 0.25 µs instead of 0.13 µs per call on the server; release builds strip both. I kept the story's form, which `Log.enabled()` already uses. If the CP1 perf scene ever shows `f()` in a debug profile, the fix is `if not _values.has(key): assert(false, …)`.
- **No value looked wrong**, so there is nothing to raise at CP1/CP2.
- **Things left alone on purpose (out of scope):**
  - The `ChainState` header still says "All tuning constants live here" (the story says don't touch `ChainState`).
  - `project-context.md`'s 1.2 sentence still says "(holding only `clock`)". I followed "Remove nothing else", and the new 1.3 sentence names `Game.tuning`.
  - `docs/architecture.md`'s hitstop line still shows `Game.clock.request(&"hitstop", 0.05, 0.075)` as an example call. It is still a valid call.

### Completion Notes List

- Story context created by gds-create-story on 2026-11-12. Ultimate context engine analysis completed - comprehensive developer guide created. The `Tuning` / `Gear` API and the test's introspection were dry-run on Godot 4.7.2 in a scratch copy first (see "Verified on the server").
- **`rules/tuning.gd`** (`class_name Tuning`, `RefCounted`, pure):
  - 34 consts in the map's order and groups, each with a `## unit; intent (source). Was X.` comment, all listed in `BASE`.
  - `FLAGS = [&"instant_snuff"]`, `OPS = [&"set", &"add", &"mul"]` and `signal changed`.
  - `apply_gear(gear_ids, table := Gear.TABLE)` precomputes `_values` (D4) and asserts on a malformed row, an unknown key or flag, and a double `set` (D5). It ignores unknown gear ids and emits `changed` once. `apply_gear([])` is the reset in place (D6).
  - `f()` and `flag()` assert on an unknown key.
  - Small additions beyond the spec, both inside D5:
    - `_check_row()` also asserts that `id` / `stat` / `op` are present and `value` is a number.
    - Ids, stats and ops go through `StringName()`, so a row written with `"strings"` behaves like one written with `&"names"`.
- **`rules/gear.gd`:** `class_name Gear` with an empty `const TABLE: Array[Dictionary]` and an AR16 header naming the four E5/E6 items.
- **`Game.tuning`:** one `Tuning.new()` beside `clock`. The header says 1.4 adds settings, slot, dive and devices, and that gear changes call `apply_gear()`, never a new `Tuning`.
- **Actor migration** (D1–D3), with no value changed:
  - `player.gd`: 28 exports gone. It reads 25 Tuning keys and has 6 local consts: `SHAKE`, `LOOK_AHEAD`, `LIGHT_KICK`, `LIGHT_LERP`, `SNUFF_HOLD` and the new `HITSTOP_SCALE`. `_freeze_frame()` keeps its `<= 0.0` guard.
  - `crawler.gd`: 5 exports gone; `hover` is a plain per-instance var.
  - `lurker.gd`: 11 exports gone; 6 local consts, 5 Tuning keys.
  - Functions take `var t := Game.tuning` and read keys each tick. Only timers and seeds are taken at a moment: `_cling_left`, `_coyote`, `_buffer`, `_dash_left`, `_swing_left`, `_swing_cd`, `_invuln`, `_kick_left`, the lurker's `_timer` and the crawler phase seed (`_coyote` and `_buffer` added by the code review).
  - Group notes above the local consts are plain `#` comments. A `##` block above a member would become that member's doc comment.
- **`tests/test_tuning.gd`** (83 checks):
  - API: BASE size and values, all 6 gear orders = 9 (the table order is permuted along with the ids, because `apply_gear` filters the table in table order), other stats untouched, unknown ids ignored, flag on/off/reset, one `changed` per call, reset in place, an empty `Gear.TABLE`, and `Game.tuning`.
  - Purity, with an open-error check.
  - The 44-row M1 fixture: values, moved properties gone, local consts present, `hover` per instance, and each BASE key from exactly one row.
  - The FR values: the chain cap 20, 40 / 12 px light, the radius curve at 0 / 4 / 10 / 20, bloom 1.0 → 1.805 and clamped, `HITSTOP_SCALE` 0.05, and the four player boxes read from a freed `player.tscn` instance.
- **Docs:** component inventory, dev guide, source tree, architecture, README and the project-context sentence (Task 5).
- **Commits:** `b4f9fac` feat (Tasks 2–3), `cf1bb64` refactor (Task 4), `120f9bd` docs (Task 5), each green; this record and the sprint status in a final docs commit.
- **Feel:** this is a pure refactor. Tests are green; it needs a quick feel check on the laptop (no change intended).
- **Feel check passed (sonlm, laptop, 2026-11-14):** plays as in M1; no change felt from the refactor.

### File List

- `game/scripts/rules/tuning.gd` (new)
- `game/scripts/rules/tuning.gd.uid` (new)
- `game/scripts/rules/gear.gd` (new)
- `game/scripts/rules/gear.gd.uid` (new)
- `game/tests/test_tuning.gd` (new)
- `game/tests/test_tuning.gd.uid` (new)
- `game/scripts/core/game.gd`
- `game/scripts/actors/player.gd`
- `game/scripts/actors/crawler.gd`
- `game/scripts/actors/lurker.gd`
- `game/tests/smoke_shaft.gd`
- `game/run_tests.sh`
- `game/README.md`
- `docs/component-inventory.md`
- `docs/development-guide.md`
- `docs/source-tree-analysis.md`
- `docs/architecture.md`
- `_bmad-output/project-context.md`
- `_bmad-output/game-architecture.md` (code review: Spec example reads `Game.tuning`)
- `_bmad-output/implementation-artifacts/deferred-work.md` (code review: one deferred item)
- `_bmad-output/implementation-artifacts/1-3-tuning-as-data.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-11-12: Story 1.3 created (ready-for-dev).
- 2026-11-12: Implemented (gds-dev-story). Added `Tuning` and `Gear` in `rules/` and `Game.tuning`; migrated the 44 M1 exports (34 Tuning keys, 11 local consts, 1 per-instance var); added `test_tuning` (API, purity, M1 regression fixture, FR values); updated the docs. No value changed. Status → review.
- 2026-11-12: Code review (gds-code-review): 6 patches applied (`feb14e5`), 1 item deferred to Story 1.9 (proposed), 17 dismissed. Status → done.
