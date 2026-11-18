---
baseline_commit: e0d21eb
---
# Story 1.8: PlayerInput intents

Status: done

**Type:** dev · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP1 Foundations (1.1–1.15) · **Branch:** `feat/m2-e1`

## Story

As a player,
I want every press read once per tick and kept through hitstop,
so that no input is ever dropped and a tap on Light never breaks my chain.

## Acceptance Criteria

1. **One sampler, intents only.** `scripts/actors/player_input.gd` (`class_name PlayerInput`, a `Node` child of `Player` in `player.tscn`) samples `InputMap` once per physics tick into intents:
   - `move`;
   - `jump_pressed` / `jump_held`;
   - `attack_pressed`;
   - `dash_pressed` / `dash_held`;
   - `light_tap`, `snuff_active`;
   - `cling_held`;
   - `interact`;
   - plus `jump_released` (D8).

   `player.gd` reads only these intents: no `Input.` remains in it or anywhere under `game/scripts/` except `player_input.gd`. (AR34, AR3; D1, D2)
2. **Light: a tap never Snuffs.** Light pressed and released inside `Settings.light_tap_window` (0.12 s default) gives `light_tap` and never `snuff_active`. Held past the window, it gives `snuff_active` until release.
   - A test covers each window: 0.12, 0.2 and 0.3 s.
   - The Light timer runs on real time, so a hitstop never stretches the window. A test holds Light across a 75 ms hitstop.
   - `light_tap_window` is a new `Settings` key with choices 0.12 / 0.2 / 0.3 (D5).

   (FR9, UX-DR119; D4, D5)
3. **Presses survive a hitstop.** With a 75 ms hitstop active (`Engine.time_scale` 0.05, via `Game.clock`), Jump or Attack pressed during it is buffered on real time and acted on: in the same tick if nothing blocks it, otherwise when the block ends inside the buffer window. A press is never dropped because the world is frozen. (NFR2; D3, D9)
4. **↓ interact.**
   - **Fires:** ↓ pressed while standing still on the ground. Standing still means sideways input below the 0.2 deadzone. On a stick it fires at ≥ 0.6 down with < 0.2 sideways, and re-arms below 0.3.
   - **Doesn't fire:** in the air, while moving sideways, or on a wall. ↓ on a wall still drops off it.
   - Nothing consumes `interact` yet (stations arrive in 1.24); the intent is tested directly.

   (FR26, UX-DR118; D6)
5. **`lock()` / `unlock()`** suppress every intent for scripted moments:
   - while locked, every intent reads false or zero, and a press made during the lock is never acted on after it;
   - after `unlock()`, held intents follow the keys again at once;
   - press intents and the Light machine need a fresh press after `unlock()`.

   (AR34; D7)
6. **M1 movement is pinned before the switch.**
   - **Before** any player code changes, new smoke checks run against the M1 input path: run 110 px/s, coyote time 0.08 s, jump buffer 0.10 s, and air dash 260 px/s for 0.12 s (M1 has no tests for these).
   - They pass on M1 code. After the switch, they pass again, together with the existing jump-height and cling / kick-off checks in `smoke_shaft`.

   (FR1, FR2, FR7, AR3; D11)
7. **Done means green.** `cd game && ./run_tests.sh` ends in `== ALL GREEN`, with the new smoke test in the `for t in …` list. Report "tests green; needs a feel check on the laptop" (D13), never "feels the same".

## Tasks / Subtasks

- [x] **Task 1: Pin M1 movement first (AC: 6).** No player code changes in this task.
  - [x] Add `game/tests/rooms/input/t_input.txt` (D11 layout).
  - [x] Add `game/tests/smoke_player_input.gd` with the movement group only: run speed, coyote in/out, jump buffer in/out, air dash (speed, duration, gravity ignored, once per airtime, refreshed on landing). Add it to `run_tests.sh`.
  - [x] Run it against the unchanged M1 `player.gd`: every check `ok`. Record the counts in the Debug Log. If a check fails on M1, the test is wrong, not M1: fix the test.
  - [x] Red-check each movement check by breaking the value it guards (e.g. `coyote_time` 0 in a scratch edit), then revert.
- [x] **Task 2: `Settings.light_tap_window` (AC: 2).**
  - [x] Add the SCHEMA entry `{default = 0.12, choices = [0.12, 0.2, 0.3]}` and `var light_tap_window := 0.12` (D5).
  - [x] Update `test_state.gd`:
    - the `to_dict()` checks (now two keys);
    - a JSON round trip for each choice (floats stay exact through `JSON.stringify` → `JSON.new().parse()`);
    - bad values fall back to 0.12 and are unclean: `0.15`, `"0.2"`, `true`, `12`.
- [x] **Task 3: `PlayerInput` (AC: 1–5).**
  - [x] Create `scripts/actors/player_input.gd` (+ `.uid`) per D1–D8.
  - [x] Add a `PlayerInput` node (type `Node`, that script) to `scenes/actors/player.tscn`.
- [x] **Task 4: Switch `player.gd` to intents (AC: 1, 3).** Per D9:
  - `input.sample()` first in `_physics_process`;
  - every `Input.` read becomes an intent;
  - the jump `_buffer` timer moves into `PlayerInput`;
  - drop `SNUFF_HOLD` and `_light_held`.

  Keep every other line of M1 behaviour. Run the movement group, `smoke_shaft` and `test_chain_state`: all green, unchanged.
- [x] **Task 5: Intent tests (AC: 2–5).** Add the intent group to `smoke_player_input.gd` (D11):
  - Light taps at three windows;
  - Light across a hitstop;
  - Jump and Attack in a hitstop;
  - the attack buffer;
  - interact with its thresholds;
  - lock / unlock;
  - the source checks.

  Red-check each one.
- [x] **Task 6: `test_tuning` fixture (AC: 1).** The `player.snuff_hold` row moves to a new `setting` kind: `{m1 = "player.snuff_hold", value = 0.12, setting = &"light_tap_window"}`. It checks that `Settings.SCHEMA[&"light_tap_window"].default == 0.12` and that `player.gd` has no `SNUFF_HOLD` const or var.
- [x] **Task 7: Docs and ledger (D12).**
- [x] **Task 8: Verify (AC: 7).**
  - [x] `./run_tests.sh` → `== ALL GREEN`.
  - [x] `grep -rn 'Input\.' game/scripts` shows only `actors/player_input.gd`.
  - [x] No `ERROR:` or leak lines in the raw smoke output.
  - [x] Every new `.gd.uid` is staged.
  - [x] Report "tests green; needs a feel check on the laptop" with D13's list.

### Review Findings

Code review 2026-11-18 (gds-code-review, scope `e0d21eb..working tree`; Blind Hunter, Edge Case Hunter, Acceptance Auditor). The Edge Case Hunter checked its findings with probes run through `tests/runner.tscn`.

- [x] [Review][Patch] (decided by sonlm: keep M1; make the comment, the AC3 note and a test say so) An Attack pressed during a pogo hitstop is still lost — `_swing_cd` (0.22 s) counts down on the scaled delta, so it barely moves during the 75 ms hitstop, while the 0.10 s `ATTACK_BUFFER` counts real time and runs out about 25 ms after the hitstop ends. Probe: a press in a hitstop swings only if the hitstop started ≥ ~10 ticks into the swing. M1 lost these presses too (not a regression), but the `ATTACK_BUFFER` comment and AC3's "never dropped because the world is frozen" claim otherwise, and `test_attack_in_hitstop` runs with the cooldown at 0, so it never sees the gap. Options: keep M1 behaviour and make the comment, the AC3 note and the test honest; or make a press in a hitstop wait for the cooldown (a feel change).
- [x] [Review][Defer] `lock()` on a clinging player fires a wall kick, and a Jump release while locked loses the jump cut — `_clear()` sets `cling_held = false`, which `_handle_cling` reads as "Jump released" (probe: one locked tick → `velocity (-150, -260)`); `jump_released` is not sampled while locked, so a rising jump keeps full height after unlock. Nothing calls `lock()` yet. Options: defer to 1.24, the first caller; or fix now (a lock ends a cling as a drop, no kick). — deferred (sonlm): 1.24 is the first `lock()` caller and decides what a scripted moment does to a move in progress
- [x] [Review][Patch] ↓ no longer drops off a wall while ↑ is held: `jump` is bound to Z and ↑, and ↑ is also `move_up`, so `input.move.y` (↓ − ↑) is 0. M1 read `move_down` alone. Add a `down_held` intent on the raw `move_down` strength, and a test that clings on ↑ + `jump` and then presses ↓ [game/scripts/actors/player.gd:128]
- [x] [Review][Patch] Snuff is not latched: raising `light_tap_window` mid-hold (Pause → Options, 1.36) turns a Snuff off while Light is held and then emits a tap on release (probe: true → false, tap true). The comment says a change "applies to the next hold" [game/scripts/actors/player_input.gd:146]
- [x] [Review][Patch] Light held through a pause or a respawn never Snuffs until it is pressed again, because the machine starts only on `is_action_just_pressed` (probe: pressed in pause, held 20 ticks after resume → no Snuff; M1 Snuffed). A release and re-press inside one tick mid-Snuff restarts the timer and lights you for 7 ticks. Start the machine on "held and not yet timing", and keep the fresh-press rule for `unlock()` only (D7) [game/scripts/actors/player_input.gd:139]
- [x] [Review][Patch] Summing 1/60 makes 12 ticks 0.19999…, so the 0.2 s window Snuffs on tick 13 while 0.3 Snuffs on exactly 18: compare with a small epsilon so each window starts on tick ⌈w·60⌉ (8 / 12 / 18), and test both sides of each boundary. Fix the test comments that say the attack buffer is 6 ticks (it is 7, like M1's jump buffer, which stays as is) [game/scripts/actors/player_input.gd:146]
- [x] [Review][Patch] The Jump press that starts a cling is now buffered (M1's wasn't), so a quick release within coyote time can turn the kick into a full jump. Consume `jump_pressed` when a cling starts: the press was used [game/scripts/actors/player.gd:118]
- [x] [Review][Patch] Nothing tests that the Jump and Attack buffers run on real time: both hitstop tests act on the press tick, and the M1 path passes them. Add checks that a buffered press made in a long hitstop, with its action blocked, expires within 7 real ticks [game/tests/smoke_player_input.gd]
- [x] [Review][Patch] The lock test is partly vacuous: Light is locked before the press is sampled (2-tick latency), no check asserts that no `light_tap` fires after `unlock()`, and only 4 of the 11 intents are checked while locked [game/tests/smoke_player_input.gd]
- [x] [Review][Patch] Test assertions that are missing: the "tap released in a hitstop" check never asserts that the hitstop was still active at release, `tap_while_snuffed` is computed but never asserted, and `_coyote_jump` returning `INF` satisfies the "out" check [game/tests/smoke_player_input.gd]
- [x] [Review][Patch] `p.free()` in `test_sources`: use `queue_free()` (project rule; the 1.9 lint will forbid `.free()`) [game/tests/smoke_player_input.gd:544]
- [x] [Review][Patch] `consume()` clears edges, although D2 calls it a no-op for an edge, and the `PRESSES` comment says all five are buffered (only Jump and Attack are). Keep the behaviour and fix the comments [game/scripts/actors/player_input.gd:16]
- [x] [Review][Patch] `DASH_TIME`'s comment says ≈ 31 px, and the architecture test row says "0.12 s"; the measured M1 dash is 8–9 ticks, ≈ 39 px. Make both state the measured numbers [game/scripts/rules/tuning.gd:34]
- [x] [Review][Patch] D12 docs gaps: the architecture.md Light key row lacks "Flare Toss in 1.23", component-inventory.md's tests table has no `smoke_player_input` row, the source-tree-analysis.md `rooms/` comment omits `input/`; and the Change Log has no entry for the 2026-11-18 feel check [docs/architecture.md]
- [x] [Review][Defer] The air dash lasts 8–9 ticks (≈ 0.15 s, 39 px), not FR2's 0.12 s / 31 px, because the timer is checked before it counts down [game/scripts/actors/player.gd] — deferred, pre-existing (M1)
- [x] [Review][Defer] The `Input.` source check misses event reads (`_input(event)`, `event.is_action_pressed`) and aliasing, and flags comments [game/tests/smoke_player_input.gd] — deferred: `test_lint.gd` (1.9) owns the raw-Input rule

## Dev Notes

### What this story is (and isn't)

It moves every raw `Input.*` read out of `player.gd` into one `PlayerInput` node. It adds the Light tap/hold machine on real time, real-time press buffers, ↓ interact and `lock()`. The player's feel must not change, apart from the small, listed differences in D9.

**Not in this story** (each has its own owner; no deferral needed):
- **Cling and Snuff toggle modes:** 1.35. `cling_held` and `snuff_active` are already separate intents, so 1.35 changes only `PlayerInput`.
- **Quick Wick `instant_snuff`:** E5 gear. The flag already exists in `Tuning.FLAGS`; don't read it yet.
- **Flare Toss**, the consumer of `light_tap`: 1.23.
- **Interact consumers** (stations, anchors): 1.24.
- **Gamepad bindings:** 1.37. The stick thresholds are implemented and tested now through `Input.action_press(action, strength)`.
- **Pause:** 1.34.
- **The architecture lint:** 1.9. This story's source check is a stopgap that 1.9's `test_lint.gd` replaces.

### Current state (read before changing)

**`scripts/actors/player.gd`** (325 lines) reads `Input` in 9 places:

| Line | Read | Becomes |
|---|---|---|
| 101 | `is_action_pressed("light")` → `_light_held += delta` (scaled), Snuff at `SNUFF_HOLD` 0.12 | `snuff_active` |
| 113, 120 | `is_action_pressed("jump")` (cling start, kick-off on release) | `cling_held` |
| 128 | `is_action_pressed("move_down")` (drop off the wall) | `move.y > 0.0` |
| 154 | `get_axis("move_left", "move_right")` | `move.x` |
| 163 | `is_action_just_pressed("dash")` | `dash_pressed` + `consume` |
| 183 | `is_action_just_pressed("jump")` → `_buffer = jump_buffer` (scaled) | `jump_pressed` + `consume` |
| 190 | `is_action_just_released("jump")` → jump cut | `jump_released` |
| 195 | `is_action_just_pressed("attack")`, dropped while `_swing_cd > 0` | `attack_pressed` + `consume` |

**Tick order** (keep it): `_tick_timers` → `_handle_snuff` → `_handle_cling` → (not clinging) `_handle_horizontal`, `_handle_vertical`, `_handle_attack` → `move_and_slide` → floor reset → `_process_swing` → `_check_contact` → `_update_light`. Timers (`_coyote`, `_swing_cd`, `_invuln`, `_dash_left`, `_cling_left`, `_kick_left`) use the scaled `delta`, and that stays: they are game time.

**Must preserve:**
- **Cling:** start when falling at a wall with Jump held; Release = kick (150, −260) + 0.15 s lock; ↓ = drop; grace 1 s, refilled by a pogo.
- **Jump:** the cut on release applies only to a real jump that is still rising.
- **Attack:** in the air it always pogoes; the landing-frame pogo is a plain slash.
- **Dash:** air only, once per airtime, refreshed by landing or a pogo; the direction locks when the dash starts.
- **Every test** that pokes private fields (`_clinging`, `_cling_left`, `_swing_left`) keeps working.

**`player.tscn`** children: Sprite, Body, Light, Slash (+Shape, Sprite), Pogo (+Shape, Sprite), Hurtbox (+Shape). Add `PlayerInput` (type `Node`) last.

**Input map** (`project.godot`):
- `move_left/right/up/down` = arrows;
- `jump` = Z **and ↑** (so ↑ is both `move_up` and `jump`; `move.y < 0` is never read);
- `attack` = X, `dash` = C, `light` = V;
- keyboard only, physical keycodes, action deadzone 0.2;
- there is **no `interact` action**: interact is ↓ (`move_down`) by rule, so don't add one.

**`Settings`** (`rules/settings.gd`): `SCHEMA` + a typed var per key; `set_value()` asserts and emits `changed`; `from_dict()` never asserts and turns whole JSON floats into ints only for int defaults. A float key needs no change to that code: `typeof(0.12) == TYPE_FLOAT` and `v in choices` compares exactly.

**Tests touching this:**
- `smoke_shaft.gd`:
  - `test_snuff_needs_hold`: 4 frames = tap keeps the chain; 18 frames = Snuff; release ends it;
  - `test_jump_height`: held 55–66 px; tap < 60 %;
  - `test_wall_cling`: cling and kick;
  - the bot.
- `test_tuning.gd`: the `player.snuff_hold` row pins `SNUFF_HOLD` (Task 6).
- `test_state.gd`: lines ~119–178 assume `brightness` is the only key (Task 2).
- All of them drive `Input.action_press/release`, which `PlayerInput` samples like the engine did, so they need no rewrite.

### Verified engine facts (4.7.2 probes, 2026-11-14)

- **Physics ticks keep running at 60 per real second under `Engine.time_scale` 0.05**; only the `delta` passed in is scaled (61 ticks in 1.009 s real, delta 0.00083). So a hitstop never skips sampling, and the M1 hitstop "drop" was never a missed edge: it was `_swing_cd` stalling on scaled time.
- **A press and release between two ticks** shows `is_action_just_pressed == true` with `is_action_pressed == false` on the next tick. A tap shorter than one tick still produces both edges.
- **`Input.action_press(action, strength)` bypasses the action deadzone:** strength 0.1 gives `get_axis` 0.1 and `is_action_pressed` true. So `PlayerInput` applies its own `MOVE_DEADZONE` 0.2 and its own ↓ thresholds, both on `get_action_raw_strength()`. The same code then serves keyboard (0 / 1), pads (1.37) and test strengths.
- **`await get_tree().physics_frame` resumes before the nodes' `_physics_process` for that tick.** A test reading intents right after the await sees the **previous** tick's sample. Write the frame counts with that in mind.

### Decisions

- **D1, the node and its call order.** `PlayerInput extends Node` has **no `_physics_process`**. `Player._physics_process` calls `input.sample()` as its first line after the `is_dead` check.
  - **Why:** a child's `_physics_process` runs **after** its parent's, so a self-ticking `PlayerInput` would hand the player last tick's input (one frame of lag on every press). An explicit call also makes "once per tick" a fact, not a convention.
  - **Access:** `Player` holds `@onready var input: PlayerInput = $PlayerInput`, public for tests and for scripted moments (`player.input.lock()`).
  - **The body:** `PlayerInput` finds its body with `get_parent() as CharacterBody2D` in `_ready()`, asserting it is not null, and reads `is_on_floor()` from it for `interact`. Any `CharacterBody2D` works, so no `Player` type dependency.
- **D2, the intent API.** Everything is readable between ticks.

  | Intent | Type | Meaning |
  |---|---|---|
  | `move` | `Vector2` | `get_axis` of left/right and up/down on raw strengths, each zeroed below `MOVE_DEADZONE` 0.2 |
  | `jump_held`, `dash_held` | bool | the key is down this tick |
  | `cling_held` | bool | = `jump_held` in hold mode (1.35 adds the press-toggle) |
  | `snuff_active` | bool | the Light machine is past the window (D4) |
  | `jump_released` | bool | Jump went up this tick (D8) |
  | `jump_pressed`, `attack_pressed` | bool | a press is waiting: true from its press until `consume()` or until its buffer runs out on real time (D3) |
  | `dash_pressed`, `light_tap`, `interact` | bool | an edge: true for the one sample it happened in |

  - `consume(intent: StringName)` clears a waiting press. It asserts the name is one of the five press intents, and is a no-op for an edge, which is already one tick long.
  - Buffer windows:
    - `jump_pressed`: `Game.tuning.f(&"jump_buffer")` (0.10 s, FR1), read at the press;
    - `attack_pressed`: local `const ATTACK_BUFFER := 0.10` (D9);
    - edges get no buffer: `dash_pressed` keeps M1's just-pressed rule (an air-only dash pressed on the ground is lost, as in M1); `light_tap`'s consumer, Flare Toss, decides its own buffer in 1.23; `interact` fires once.
  - **Every const carries a `##` comment** with unit + intent + source:
    - `MOVE_DEADZONE` (UX-DR118, D7);
    - `INTERACT_FIRE` 0.6, `INTERACT_REARM` 0.3 (UX-DR118);
    - `ATTACK_BUFFER` (NFR2, D9).
- **D3, real time is one tick.** `PlayerInput` advances its timers by `REAL_TICK = 1.0 / Engine.physics_ticks_per_second` per `sample()`, **not** `delta / Engine.time_scale`.
  - **Why:** the probe shows ticks stay at a fixed real rate, and the `Clock` can change `time_scale` between the step and the read, which makes `delta / time_scale` wrong by up to a tick at a hitstop's edges.
  - **Pause:** `SceneTree.paused` stops `Player`, so buffers and the Light timer freeze with the pause, as the Clock's do (AR36).
  - `CameraRig` keeps its own formula; it isn't timing input.
- **D4, the Light machine.**
  - **On press** (the just-pressed edge, including a press and release inside one tick): start `_light_time = 0`.
  - **Every sampled tick the key is down:** `_light_time += REAL_TICK`, and set `snuff_active` once `_light_time >= window`.
  - **On release:** if `snuff_active` was false, emit `light_tap` for that sample; clear `snuff_active`.
  - **Timing:** this accumulates exactly as M1 did, so at 0.12 s Snuff starts on the 8th held tick, as now (`smoke_shaft`'s 4-frame tap and 18-frame hold keep passing).
  - **The window:** read `Game.settings.light_tap_window` each tick, so an Options change (1.36) applies to the next hold.
  - **The player** calls `chain.set_snuffed(input.snuff_active)` only on a change (same as now).
  - `light_tap` does nothing in the player yet (1.23).
- **D5, the setting.** `Settings.SCHEMA[&"light_tap_window"] = {default = 0.12, choices = [0.12, 0.2, 0.3]}` and `var light_tap_window := 0.12`.
  - **Key, not Tuning:** it's a player setting (UX-DR119; architecture → "the tap window stays a `Settings` value, never a `Tuning` key"), so `SNUFF_HOLD` goes away, never to `Tuning`.
  - **No migration:** no version bump; a missing key takes its default (Settings' own rule).
  - **No UI:** Options > Accessibility shows it in 1.36.
- **D6, interact.** It fires on the tick the raw `move_down` strength crosses up to `INTERACT_FIRE` 0.6 while armed. The crossing **uses up the arm** whether or not it fires, and the arm returns below `INTERACT_REARM` 0.3.
  - **It fires only if** at that tick:
    - the body `is_on_floor()`;
    - `absf(raw right − raw left) < MOVE_DEADZONE`.
  - **Why the arm is used up:** holding ↓ while running and then stopping must not fire, nor must landing with ↓ held. That keeps the press deliberate, as UX-DR118's re-arm means it to be.
  - **↓ still drops off a wall** through `move.y > 0.0`, as M1's `is_action_pressed("move_down")` did.
- **D7, lock.**
  - **`lock()`:**
    - sets `_locked`;
    - clears every intent, every buffer and the Light machine (so a held Snuff ends: the light returns, the chain stays broken);
    - `sample()` then keeps everything false or zero.
  - **`unlock()`:**
    - held intents read the keys again on the next sample;
    - press intents need a new just-pressed edge;
    - the Light machine starts only on a new press, so a Light held through a cutscene never Snuffs on unlock;
    - the interact arm resets to "not armed until ↓ is released below 0.3".
  - **`is_locked()`** for tests.
  - Nothing calls `lock()` yet (1.24 rest, E4–E6 moments).
- **D8, the jump cut keeps M1's edge.** `jump_released` is an extra intent beyond AR34's list. M1 cuts on the release **edge**, so a buffered jump whose key was already released before landing is a full jump.
  - **The alternative:** deriving the cut from `not jump_held` would turn that into a tiny hop, a feel change this story must not make.
  - **Record:** note the extra intent in the architecture variance list (D12).
- **D9, the switch in `player.gd`.**
  - **Jump buffering moves into `PlayerInput`:**
    - `_buffer`'s timer is gone;
    - `_handle_vertical` jumps when `input.jump_pressed and _coyote > 0.0`, then calls `input.consume(&"jump_pressed")`;
    - **new: a jump press made during a dash or a cling is now kept up to 0.10 s.** In M1, `_handle_vertical` returned before reading it, so a jump pressed mid-dash just before landing was lost; now it jumps on landing.
  - **Attack:** starts a swing when `input.attack_pressed and _swing_cd <= 0.0`, then consumes.
    - **New:** an Attack pressed up to 0.10 s before the cooldown ends now swings when it ends; M1 dropped it.
    - A press made during a pogo's hitstop usually still finds most of the 0.22 s cooldown ahead. It expires 0.10 s real after the press. The cooldown is the rule; the input was not lost.
  - **Dash:** reads `input.dash_pressed` exactly where M1 read `just_pressed`; no consume needed (edge).
  - **Snuff:** `_handle_snuff` becomes `if input.snuff_active != chain.snuffed: chain.set_snuffed(input.snuff_active)`.
  - Delete `SNUFF_HOLD` and `_light_held`. Update the class `##` header ("Landing or holding Light past the tap window (Snuff)").
- **D10, no new `Log` lines.** The INPUT category exists; per-tick logging is a hot path. Only wrap one in `if Log.enabled(Log.INPUT):` if debugging needs it.
- **D11, tests.** New `tests/smoke_player_input.gd`, with the `check` / `frames` / `seconds` helpers copied from `smoke_shaft.gd`.
  - **The room:** it loads `tests/rooms/input/t_input.txt` through `RoomLoader.add_root("res://tests/rooms/input")` + `RoomHarness.build(self, &"t_input")`, and `RoomHarness.free_all()` at the end.
  - **Teardown:**
    - release every action it pressed;
    - `Game.clock.clear()` after hitstop tests;
    - `Game.reset_for_tests()` after touching `Game.settings`.
  - **Room `t_input`.** No enemies, no lurkers, no exits; the header is like `t_swap_a`'s, with `id=t_input`.
    - a raised ledge with `P` on it, 3–4 tiles above a long floor, so walking right falls off the ledge edge (coyote) and drops in open air (buffer);
    - open air above the floor for the dash;
    - a tall side wall reachable from the floor for the ↓-on-wall drop;
    - keep the drop path ≥ 2 tiles from any wall, or held Jump clings.

    The dev picks exact cells and finds positions through `entry_position()` / `cell_centre()` / `is_solid()`, never literals. The room is shorter than the view; the camera centres it (the deferred 2.1 item doesn't matter to a test).
  - **Movement group** (Task 1, must pass on M1). Pick frames well inside or outside each limit, never on the boundary:
    - **run:** hold → from standstill on the floor for 0.5 s, then `absf(velocity.x − 110) < 0.01` and the last 10 ticks moved ≈ 18.3 px (± 0.5);
    - **coyote:** walk off the ledge; at the first tick not on the floor, press Jump after ≤ 0.05 s → `velocity.y == jump_velocity` next tick; a second run pressing at ≥ 0.12 s → no jump (`velocity.y >= 0`);
    - **jump buffer:**
      - a dry drop from the ledge measures the landing tick T;
      - pressing Jump (and holding it) at T − 3 ticks jumps on landing; at T − 9 ticks it doesn't;
      - drop from the same spot each time;
    - **air dash:**
      - from a jump at its apex, press C;
      - for the next ticks `velocity == (260 × facing, 0)`, held for 7–8 ticks (0.12 s);
      - the body moves ≈ 31 px (± 3) sideways with no vertical drift during the dash;
      - a second C in the same airtime does nothing;
      - after landing, a jump and a C dash again.
  - **Intent group** (Task 5):
    - **Light windows:** for each window in `[0.12, 0.2, 0.3]` (via `Game.settings.set_value`), with a chain of 5, holds of 0.10 / 0.15 / 0.25 / 0.35 s give tap/tap/tap/snuff at 0.3, tap/tap/snuff/snuff at 0.2, tap/snuff/snuff/snuff at 0.12.
      - On a tap: `light_tap` seen once, never `snuff_active`, chain still 5.
      - On a hold: `snuff_active` and the chain broken.
      - Use 6 / 9 / 15 / 21 ticks.
    - **Light across a hitstop:** press Light, then `Game.clock.request(&"hitstop", 0.05, 0.075)`:
      - `snuff_active` is true by tick 8 of the hold (M1's scaled timer would need ~1.5 s);
      - a separate press released at tick 4, inside the hitstop, gives `light_tap`.
    - **Jump in a hitstop:** standing on the floor, request a hitstop, press Jump during it → the player jumps (`velocity.y < 0`) before the hitstop ends + 1 tick.
    - **Attack in a hitstop:** in the air with `_swing_cd == 0`, request a hitstop, press and release Attack inside one tick → a swing starts (`_swing_left > 0`).
    - **Attack buffer:** start a swing, then press Attack when `_swing_cd` has ≈ 0.05 s left → a second swing starts when the cooldown ends. Pressed with ≈ 0.18 s left, it doesn't (the buffer expired).
    - **Interact:**
      - standing still on the floor, `action_press("move_down")` → `interact` true for exactly one sample;
      - with `move_right` at 1.0 → never;
      - `move_right` at 0.15 → fires;
      - `move_down` at 0.5 → no; at 0.6 → yes;
      - held at 0.6, then 0.4, then 0.7 → no (not re-armed);
      - 0.2, then 0.7 → yes;
      - in the air → no;
      - clinging + ↓ → the cling ends (drop) and `interact` stays false.
    - **Lock:**
      - `lock()` with Jump held → `jump_held` false, no jump;
      - a press during the lock is not acted on after `unlock()`;
      - a Light held through lock + unlock never Snuffs until released and re-held;
      - `move` is zero while locked.
    - **Source checks:**
      - no `Input.` in any `.gd` under `res://scripts/` except `actors/player_input.gd`;
      - `player.gd` source has no `SNUFF_HOLD` and no `_light_held`;
      - `player.tscn`'s `PlayerInput` node exists and is a `PlayerInput`.
  - **`smoke_shaft`**'s `test_snuff_needs_hold`, `test_jump_height` and `test_wall_cling` stay untouched and green; that is AC6's "still pass after the switch".
  - **Watch the bot.** `smoke_shaft`'s bot taps Attack on a schedule, so D9's attack buffer can shift when its swings start. It must still reach chain ≥ 5. If its best chain changes, record before → after in the Debug Log; never loosen the ≥ 5 threshold. If it drops below 5, the buffer is the suspect: stop and report.
  - **`smoke_world` and `smoke_room_swap`** spawn the player through `world.tscn` → `player.tscn`, so they exercise `PlayerInput` with no change; they must stay green.
  - **Red-check every new check** by breaking what it guards, then revert. A check that can't fail is a bug (1.7 review lesson).
- **D12, docs and ledger.**
  - **`docs/component-inventory.md`:**
    - a new PlayerInput section (intents table, `consume`, `lock`, consts);
    - Player's local consts lose `SNUFF_HOLD`;
    - Settings gains `light_tap_window`.
  - **`docs/architecture.md`:**
    - the tick-order diagram (line ~125) starts with `input.sample()`;
    - the Snuff row (line ~102) reads "hold Light past `Settings.light_tap_window` (0.12 s)";
    - the integration-tests table gains `smoke_player_input.gd`;
    - the comparison row "Light key" notes that the machine landed in 1.8 (Flare Toss in 1.23);
    - add to the variance list: `jump_released` (D8), and no self-ticking `PlayerInput` (D1).
  - **`docs/development-guide.md`:**
    - gameplay reads `player.input` intents;
    - tests still drive `Input.action_press`, with `strength` for analog;
    - a test reads the previous tick's sample after `await physics_frame`.
  - **`docs/source-tree-analysis.md`:** the new files.
  - **`game/README.md`:** the Snuff row says "hold V past the tap window (0.12 s by default)"; a ↓ note: "↓ on the ground does nothing yet (stations come later)".
  - **`project-context.md`** → Current State: append the 1.8 sentence.
  - **`deferred-work.md`:** only if something is deferred. Every item gets its `→ **Owner: …**` line from the agent that defers it (project rule; never ownerless).
- **D13, the feel check (for the report).** sonlm pulls, runs `--import`, plays `world.tscn`:
  1. Run, jump (tap = short hop, hold = full), coyote off a ledge edge, the air dash, and cling / kick / ↓ drop all feel like 1.7.
  2. A quick tap on V does nothing; a hold Snuffs at the same moment as before.
  3. Mashing X through pogo chains feels the same or better: an early press may now swing at the end of the cooldown (D9).
  4. ↓ standing on the ground does nothing visible (no stations yet).

### Project Structure Notes

- **New:**
  - `game/scripts/actors/player_input.gd` (+ `.gd.uid`): `actors/` per the architecture tree ("player_input.gd # intents, Light tap/hold, toggles, buffers, lock()");
  - `game/tests/smoke_player_input.gd` (+ `.uid`);
  - `game/tests/rooms/input/t_input.txt`.
- **Modified:**
  - `scripts/actors/player.gd`;
  - `scenes/actors/player.tscn`;
  - `scripts/rules/settings.gd`;
  - `tests/test_state.gd`, `tests/test_tuning.gd`;
  - `run_tests.sh`;
  - the docs listed in D12.
- **Dependencies stay one way:**
  - `PlayerInput` (actors/) reads `Game.settings` and `Game.tuning` (core/rules) and `Engine.physics_ticks_per_second`;
  - `rules/settings.gd` gains data only: no `Input`, `Engine` or `Node`.
- **Variances to record (D12):** the extra `jump_released` intent (D8), and the sampler being called by `Player` rather than ticking itself (D1).

### Project Context Rules (that apply here)

- **Input:** gameplay reads `PlayerInput` intents, never `Input`. `PlayerInput` owns the Light tap/hold machine (window from `Settings`), the Cling/Snuff toggles (1.35) and real-time buffers, so presses during hitstop are kept.
- **Light key:** hold past the tap window (default 0.12 s; 0.12 / 0.2 / 0.3) = Snuff; a tap must never break the chain.
- **Gameplay movement** lives in `_physics_process`; physics interpolation is on, but `PlayerInput` moves nothing.
- **Pause** is `SceneTree.paused`; real-time logic must pause with the tree (D3 does, by counting ticks).
- **Tuning:** gameplay numbers stay in `rules/tuning.gd` (`jump_buffer` is read, not copied). Input-response values are local consts with `##` unit + intent + source, or a `Settings` value (the tap window), never a `Tuning` key.
- **No raw keycodes,** no new actions (interact is ↓ by rule), physical keycodes only. No `print(`: use `Log` behind `Log.enabled()`.
- **Tests:**
  - `./run_tests.sh` → `== ALL GREEN`; it fails on any `ERROR:` line, so never trigger `push_error` or an assert on purpose;
  - new test files go into the `for t in …` list (no glob until 1.9);
  - pick targets by position; free every node built;
  - a test touching `Game` ends with `Game.reset_for_tests()`.
- **Never loosen a threshold to pass.** The M1 numbers come from the GDD (FR1/FR2/FR7); if a movement check fails on M1, the test's frame math is wrong.
- **Comments explain why,** citing the design (FR/NFR/UX-DR/D-numbers).
- **Commit `.gd.uid` files** with their sources.
- **Report** "tests green; needs a feel check on the laptop".

### Previous story intelligence (1.7 and its review)

- **The review found vacuous checks:** checks that could not fail. Every new check here is red-checked by breaking the code it guards (D11).
- **`check()` messages with an Array argument** need `str()` / `%s` with `[x]` wrapping ("not all arguments converted" bit 1.7).
- **Rooms for tests** live in `tests/rooms/<topic>/` and load through `RoomLoader.add_root()`; ids must be unique across all roots (`t_input` is).
- **`smoke_*` tests share one room per file:** reset what a test touches; a test that leaves the player dead is followed by a fresh `RoomHarness.build()`.
- **Physics interpolation is on:** `place()` in tests teleports, which is fine in headless. `PlayerInput` moves nothing, so no `reset_physics_interpolation()` concerns.
- **1.7's feel check passed on 2026-11-14,** so interpolation stays on until 1.15's verdict.
- **sonlm finds the pogo-only loop "a bit boring" (2026-11-14).** Not this story's job; don't add mechanics. Keep feel exactly M1 except D9's listed differences.

### Git intelligence

Recent commits on `feat/m2-e1`:
- `ff76abb` feat (1.7 room swaps, interpolation, shaft retired);
- `fe6d2ad` docs;
- `4911432` story record;
- `7924ec7` 1.7 feel check.

The pattern per story is feat → docs → record (story file + sprint status + deferred ledger). The repo has **no git remote**: commits stay local until sonlm adds one.

### Cross-story context (Epic 1)

- **1.9:** `test_lint.gd` makes the `Input.` rule a lint (outside `player_input.gd` and the UI kit), plus `tests/spec.gd`. This story's source check is its precursor.
- **1.11:** DevTools entry args.
- **1.15:** the CP1 gate feel check, which includes this story's input.
- **1.23:** Flare Toss consumes `light_tap` (needs ≥ 2 links, halves the chain).
- **1.24:** interact consumers (rest at a station, anchors) and the first `lock()` user.
- **1.34:** Pause (Esc/P).
- **1.35:** the Cling and Snuff press-toggles inside `PlayerInput` (Snuff toggle: Light = Flare Toss only, Snuff on its own key Shift/LB).
- **1.36:** Options shows `light_tap_window`.
- **1.37:** gamepad bindings, glyph swap, disconnect pause; the stick thresholds here are already in place for it.
- **E5:** the Quick Wick `instant_snuff` flag, read by `PlayerInput` ("start dimming on press; a release inside the window is still a Flare Toss").

### References

- Story source: `_bmad-output/planning-artifacts/epics.md` → Story 1.8 (line ~1532).
- Requirements:
  - FR1, FR2, FR7, FR9, FR26, NFR2: epics.md lines 46–173;
  - AR3, AR34, AR35, AR36: epics.md lines 200–251.
- UX:
  - UX-DR114 (bindings), UX-DR118 (interact), UX-DR119 (tap window), UX-DR120 (toggles, 1.35): epics.md ~870–903;
  - `EXPERIENCE.md` → Input Schemes > Rules (line ~150), Interaction Primitives (line ~260).
- GDD:
  - Controls table (line ~217);
  - Movement table "Coyote time / jump buffer" (line ~124);
  - "Hitstop and input" (line ~658);
  - Smith / Quick Wick (line ~304).
- Architecture: `_bmad-output/game-architecture.md`:
  - → Input (line ~389);
  - → Tuning rules (line ~953: tap window is `Settings`, Quick Wick is a flag);
  - → Data Patterns example `Game.settings.light_tap_window` (line ~1248);
  - → Consistency Rules (line ~1266).
- M1 values: `_bmad-output/implementation-artifacts/m1-playtest-findings.md` (Snuff 0.12 s hold, attack in the air always pogoes).
- Code:
  - `game/scripts/actors/player.gd`, `game/scripts/rules/settings.gd`, `game/scripts/rules/tuning.gd` (`JUMP_BUFFER`, `FLAGS`);
  - `game/scripts/core/clock.gd`;
  - `game/tests/smoke_shaft.gd`, `game/tests/room_harness.gd`, `game/tests/test_tuning.gd` (fixture row kinds), `game/tests/test_state.gd`.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), gds-dev-story, 2026-11-14.

### Debug Log References

- **Task 1 baseline (M1 `player.gd`, before any player change):** `smoke_player_input` movement group 13 `ok`. Red-checked one by one in scratch edits, each reverted:
  - `RUN_SPEED` 100 → both run checks fail;
  - `COYOTE_TIME` 0 → the coyote-in check fails (and the buffer and dash-refill checks, which need coyote to jump);
  - `COYOTE_TIME` 0.2 → the coyote-out check fails;
  - `JUMP_BUFFER` 0 → the buffer-in check fails; `JUMP_BUFFER` 0.2 → the buffer-out check fails;
  - `DASH_SPEED` 200 and `DASH_TIME` 0.06 → the dash checks fail;
  - removing `_can_dash = false` → "a second dash in the same airtime" fails;
  - removing the dash's gravity skip → the no-gravity check fails.
- **Frame-math correction to "Verified engine facts":** measured in this suite, a press made after `await get_tree().physics_frame` is first seen by the player **two** ticks later, not in the coming tick. The first coyote check failed for that reason (the press acted at 0.05 s, not 0.033 s). The tests use the measured latency, and `docs/development-guide.md` records it. The latency is the same for a press and its release, so hold lengths are exact.
- **The air dash runs 8–9 ticks** (39 px), not 0.12 s / 31 px: M1 checks `_dash_left > 0` before counting it down, so the dash lasts the start tick plus 8. This is M1 behaviour, pinned as 8–9 ticks and ≥ 31 px; no code change. The `DASH_TIME` comment's "≈ 31 px" understates it by one tick.
- **After the switch (Task 4):** movement 13 `ok` unchanged; `smoke_shaft` 30 `ok`; bot best chain **8 → 8** (same on M1 and after, so D9's attack buffer did not move it); `test_chain_state` 69. Only `test_tuning`'s `snuff_hold` row failed, as expected until Task 6.
- **Task 2:** `test_state` 154 → 171 `ok`. Red-check: allowing 0.15 as a choice fails "light_tap_window 0.15 is unclean".
- **Task 6:** the `setting` row passes; re-adding `const SNUFF_HOLD` to `player.gd` fails it.
- **Task 5 red checks** (scratch edits of `player_input.gd`, each reverted and `cmp`-checked):
  1. the scaled delta instead of real ticks → the hitstop Snuff lands on the 12th held tick, not the 8th: fails;
  2. a window hard-coded to 0.12 → the 0.2 and 0.3 tap checks fail;
  3. a tap on every release → the six hold checks fail ("no tap on release");
  4. `ATTACK_BUFFER` 0 → Attack in a hitstop and the late attack-buffer check fail;
  5. `ATTACK_BUFFER` 0.3 → the early (expired) check fails;
  6. no arm use-up → five interact checks fail;
  7. no floor check → the air and wall interact checks fail;
  8. no sideways check → "↓ while moving sideways" fails;
  9. `lock()` without `_clear()` → **failed nothing at first**: the test locked before anything was sampled. Strengthened (sample move, a Snuff and a buffered Jump in the air, then lock); now 2 checks fail;
  10. a Light held through unlock counting → "never Snuffs on its own" fails;
  11. sampling skipped while `time_scale < 1` → five hitstop checks fail;
  12. sampling while locked → three lock checks fail;
  13. an `Input.` line added to `lurker.gd` → the source check fails.
- **Final:** `./run_tests.sh` → `== ALL GREEN`:
  - `test_chain_state` 69, `test_log` 7, `test_clock` 15, `test_tuning` 85, `test_state` 171, `test_room_loader` 64, `test_deferred_owners` 19;
  - `smoke_shaft` 30, `smoke_world` 60, `smoke_room_swap` 39, `smoke_player_input` 51 (new).
  - No `ERROR:`, leak or orphan lines in any raw output; the only `WARNING:` lines are `test_state`'s counted SaveStore warnings.
  - `grep -rn 'Input\.' game/scripts` finds only `actors/player_input.gd`.
- **Code review 2026-11-18, patches.** Each new or strengthened check was red-checked by breaking the line it guards (all fail as expected):
  1. wall drop back on `move.y > 0` → "clinging on ↑ and pressing ↓ drops" fails;
  2. Snuff not latched → the "window raised mid-Snuff" check fails (Snuff off, tap 1);
  3. hold started on the press edge only → the 8 / 12 / 18-tick holds and "Light pressed during a pause" fail;
  4. no `TIME_EPSILON` → the 12-tick hold at 0.2 s fails;
  5. no cling consume → "a Jump press that starts a cling is consumed" fails. A first version consumed only on the tick the cling started and passed broken: in a test the press edge arrives one tick after "held", so the buffer filled on the next tick. The Player now consumes the press on every clinging tick (Jump is held all through a cling, so only the starting press can be waiting);
  6. / 7. Jump or Attack buffer on scaled time → the 0.5 s hitstop checks fail (20 ticks, not 7);
  8. `_clear()` without `_light_down = false` → "a Light press released while locked gives no light_tap" fails;
  9. `unlock()` without the wait-for-release → "Light held through lock and unlock never Snuffs" fails;
  10. `ATTACK_BUFFER` 0.30 → the real-time, M1 hitstop and expired-buffer checks fail.
- **Frame math found in the review:** a test press is "held" one tick before its press edge is seen. The 1.8 Light machine started on the edge, so in tests a hold was counted from its second tick; it now starts on the first held tick, as M1 counted it. In play the edge and "held" arrive on the same tick, so feel is unchanged.
- **After the review:** `./run_tests.sh` → `== ALL GREEN`; `smoke_player_input` 51 → 60, every other count unchanged; bot best chain 8; `Input.` only in `player_input.gd`.

### Completion Notes List

- **AC1:**
  - `PlayerInput` (`scripts/actors/player_input.gd`, a `Node` child of `Player` in `player.tscn`) samples once per tick when `Player` calls `input.sample()` first in `_physics_process` (D1).
  - Intents: `move`, `jump_pressed` / `jump_held` / `jump_released`, `attack_pressed`, `dash_pressed` / `dash_held`, `light_tap`, `snuff_active`, `cling_held`, `interact`; `consume()`.
  - `player.gd` reads only intents; no `Input.` remains under `scripts/` outside `player_input.gd` (tested).
- **AC2:**
  - `Settings.light_tap_window` (0.12 / 0.2 / 0.3, default 0.12) replaces `SNUFF_HOLD`.
  - The Light machine counts real ticks; taps and Snuffs are tested at all three windows and across a 75 ms hitstop (Snuff on the 8th held tick either way).
  - A settings.json written before 1.8 lacks the key, so it loads the default and is rewritten once (the existing missing-key rule).
- **AC3:**
  - Jump and Attack presses wait in real-time buffers (`jump_buffer` 0.10 s, `ATTACK_BUFFER` 0.10 s) until consumed.
  - Jump and Attack pressed in a hitstop act inside it.
  - An Attack seen 3 ticks before the cooldown ends swings at its end; one seen 11 ticks before expires.
- **AC4:** ↓ interact per D6 (0.6 fire, 0.3 re-arm, sideways < 0.2, on the floor, arm used up by the crossing); ↓ on a wall still drops, with no interact. Nothing consumes it yet (1.24).
- **AC5:** `lock()` clears every intent, buffer and the Light machine; `unlock()` needs fresh presses and a fresh Light hold; `is_locked()`.
- **AC6:** movement pinned on M1 first (13 checks) and unchanged after; `smoke_shaft` jump height and cling / kick still green.
- **AC7:** `== ALL GREEN`.
- **Small, intended feel differences (D9):** an Attack pressed up to 0.10 s before the cooldown ends now swings; a Jump pressed during a dash or a cling is kept 0.10 s; a Light hold across a hitstop Snuffs on real time.
- **Nothing deferred at dev time.** The code review deferred three items, each with an owner in `deferred-work.md`: the dash length vs FR2 (1.15), the raw-Input source check (1.9), `lock()` mid-move (1.24).
- **Code review 2026-11-18:** 2 decisions (sonlm: keep M1's lost Attack in a pogo hitstop, made honest in comments and pinned by a test; `lock()` mid-move deferred to 1.24), 13 patches applied, 3 deferred, 9 dismissed. Changes: the wall drop reads the new `down_held` (↑ is also Jump); a Snuff lasts until release; a Light hold starts on any held tick, so a pause or a respawn no longer loses it and only `unlock()` asks for a fresh press; windows start on held tick 8 / 12 / 18 (`TIME_EPSILON`); the Player consumes the Jump press while clinging; tests for real-time buffers, the lock, boundaries and the hitstop tap; doc fixes.
- **Tests green; needs a feel check on the laptop (D13):**
  1. run, jump (tap = short hop, hold = full), coyote off a ledge, air dash, and cling / kick / ↓ drop feel like 1.7;
  2. a quick tap on V does nothing; a hold Snuffs at the same moment as before;
  3. mashing X through pogo chains feels the same or better;
  4. ↓ standing on the ground does nothing visible.
- **Feel check passed (sonlm, laptop, 2026-11-18), D13:** all four checks passed: movement feels like 1.7, a V tap does nothing while a held V Snuffs at the same moment as before and breaks the chain (by design, FR9), mashing X through pogo chains feels the same or better, ↓ on the ground does nothing. The 0.12 s default tap window stays.
- Story context created by gds-create-story on 2026-11-14. Ultimate context engine analysis completed - comprehensive developer guide created. Engine facts in "Verified engine facts" were probed on 4.7.2 in a scratch project, not in `game/`.

### File List

- game/scripts/actors/player_input.gd (new)
- game/scripts/actors/player_input.gd.uid (new)
- game/scripts/actors/player.gd (modified: reads only PlayerInput intents; SNUFF_HOLD, _light_held and the _buffer timer removed)
- game/scenes/actors/player.tscn (modified: PlayerInput child node)
- game/scripts/rules/settings.gd (modified: light_tap_window key)
- game/tests/smoke_player_input.gd (new)
- game/tests/smoke_player_input.gd.uid (new)
- game/tests/rooms/input/t_input.txt (new)
- game/tests/test_state.gd (modified: light_tap_window checks)
- game/tests/test_tuning.gd (modified: `setting` row kind for player.snuff_hold)
- game/run_tests.sh (modified: smoke_player_input added)
- game/README.md (modified: Snuff row, ↓ interact row)
- docs/architecture.md (modified)
- docs/component-inventory.md (modified)
- docs/development-guide.md (modified)
- docs/source-tree-analysis.md (modified)
- _bmad-output/project-context.md (modified: Current State, Last Updated)
- _bmad-output/implementation-artifacts/1-8-playerinput-intents.md (this file)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified: 1-8 → review, then done)
- game/scripts/rules/tuning.gd (modified in review: DASH_TIME comment states the measured dash)
- _bmad-output/implementation-artifacts/deferred-work.md (modified in review: three items with owners)

### Change Log

- 2026-11-14: Story 1.8 implemented. PlayerInput intents with the Light tap/hold machine on real time, real-time Jump/Attack buffers, ↓ interact and lock(); Settings.light_tap_window; M1 movement pinned by smoke_player_input before the switch. Status → review.
- 2026-11-18: Laptop feel check passed (all four D13 checks).
- 2026-11-18: Code review: 13 patches applied (wall drop on ↑, Snuff latch, Light across pause/respawn, window boundaries, cling press, test gaps, docs), 3 items deferred with owners (1.15, 1.9, 1.24). Status → done.
