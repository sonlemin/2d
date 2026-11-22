---
baseline_commit: 9a265d9
---

# Story 1.19: Health: 4 HP and the damage table

Status: review

**Type:** dev (with one human gate: sonlm's laptop feel check, Task 12) · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP2 Kit (1.16–1.30) · **Branch:** `feat/m2-e1`

## Story

As a player,
I want 4 HP, with readable knockback and a moment of invulnerability, instead of one-touch death,
so that a mistake costs me health, not the whole run.

## Acceptance Criteria

1. **`rules/health.gd` holds HP, the damage table and invulnerability, pure.**
   - New `scripts/rules/health.gd`: `class_name Health extends RefCounted`. It is per-life: `Player` has `var health := Health.new()`, beside `chain`. No `Node`, `Input`, `Engine` or `Game` (lint `rules_purity`).
   - `const MAX := 4` (GDD Health "4 HP").
   - `const DAMAGE := {&"crawler": 1, &"boss": 1, &"lurker": 2, &"hazard": 1}`: one row per GDD damage-table row (D1).
   - `const CAUSES := {&"crawler_walker": &"crawler", &"crawler_hoverer": &"crawler", &"lurker": &"lurker", &"spikes": &"hazard"}`: the one registry of cause ids, each mapped to its damage row. Cause ids are save data once Story 1.29 writes the death log, so they are never renamed (D1). `boss` has no cause yet; E2 adds the Weaver's.
   - Signals:
     - `changed(hp: int)`, on every HP change (hit, heal, reset);
     - `damaged(amount: int, cause: StringName)`, where `amount` is the HP actually lost (clamped at 0), so Story 1.25 cracks exactly that many pips, and `cause` is the cause id the death card reads (Story 1.29).
   - API, all pure:
     - `hit(cause: StringName, invuln_s: float) -> int`: refused (returns 0, emits nothing) while invulnerable or at 0 HP. Otherwise it subtracts `DAMAGE[CAUSES[cause]]`, clamped at 0, starts `invuln_s` of invulnerability, emits `damaged` then `changed`, and returns the HP lost. An unknown cause is a programmer error (`assert`);
     - `tick(delta: float)`: counts invulnerability down on game time (M1's `_invuln`, which paused under hitstop the same way);
     - `heal(n: int)`: up to `MAX`, emits `changed` only when HP moved;
     - `bank_heal(links: int, min_links: int) -> bool`: heals 1 when `links >= min_links` (FR12; the threshold comes from `Tuning`, passed in), and returns whether it did;
     - `reset(to := MAX)`: clamps to 1..`MAX`, clears invulnerability, emits `changed` (used by DevTools' `--hp`);
     - `invulnerable() -> bool`, `is_empty() -> bool`;
     - public `hp` and `invuln` (s left), for tests and the blink.

   (FR10, FR12, AR12; D1, D2)
2. **One damage path on `Player`, for every source.**
   - `Player.hurt(cause: StringName, from := Vector2.INF) -> bool` is the only way damage reaches a player (D2). In order:
     1. Return false if dead or if `health.hit(cause, Game.tuning.f(&"invuln_time"))` returns 0.
     2. If `health.is_empty()`, start the hit flash (AC8; a lethal hit flashes too, then the flash runs out while dead), call `die(cause)` and return true. A lethal hit is a death, so held embers are **lost**, not banked ("only death loses held embers").
     3. Otherwise:
        - `chain.break_by_hit()` (held → carried, AC4);
        - end any cling;
        - start the hit flash (AC8);
        - set the blink alpha on this tick's draw (as M1 did);
        - when `from` is finite, knock back away from it at (`knockback_x`, `knockback_y`) = (150, −150) px/s, cancelling any dash and jump cut (M1's `_take_knockback`).
     4. Return true.
   - **Crawler contact** stays polled with `get_overlapping_bodies()`, and an active pogo swing on the crawler still wins. A contact calls `hurt(body.contact_cause(), body.global_position)`. `Crawler.contact_cause()` returns `&"crawler_hoverer"` when `hover`, else `&"crawler_walker"`.
   - Invulnerability is `health.invuln`; `_invuln` goes from `Player`. The blink reads `Fx.blink_alpha(health.invuln)` exactly as now.
   - `die(cause := &"")` records `death_cause` (public) for Story 1.29's death card. World's tunnelling and failed-room backstops, and every test caller, keep calling `die()` with no cause (D7).

   (FR10, FR11; D2, D7)
3. **A hunting lurker deals 2; M1's one-touch death is gone.**
   - `_on_hurt_area` and the Hurtbox's `area_entered` connection are deleted.
   - Predator contact is polled each physics tick in the same poll as crawler contact, through `_hurtbox.get_overlapping_areas()`.
   - An area counts only when it is in group `predator` **and `area.monitorable` is true at the moment of the poll** (D3; probed: the overlap list lags a `monitorable` change by one physics step).
   - It calls `hurt(area.contact_cause(), area.global_position)`, giving the same knockback and the same 0.6 s invulnerability as crawler contact. `Lurker.contact_cause()` returns `&"lurker"`.
   - When a predator and a crawler both touch on one tick, the predator is taken (the larger hit; deterministic). One hit per tick, then invulnerability.
   - The poll runs after Snuff, the cling and the landing break in `_physics_process`, so it sees this tick's escape (D3).
   - A lurker in IDLE, TELEGRAPH or RETURN, or a HUNT lurker that has lost the scent (`monitorable` false), never damages.

   (FR10, NFR10; D3)
4. **Any hit breaks the chain and moves held embers to carried; ChainState says how a chain ended.**
   - `ChainState.break_by_hit()`: banks held (emits `banked(amount)`, which World already wires to `Game.dive.add_carried`) and resets the count, exactly like `break_chain()`, but reports a hit.
   - New signal `ended(links: int, by_hit: bool)`:
     - `break_chain()` emits `ended(n, false)`, and `break_by_hit()` emits `ended(n, true)`;
     - it is emitted only when the count was above 0 (`break_chain()` runs on every floor tick);
     - `lose()` emits no `ended`.
   - `set_snuffed(true)` and World's exit backstop go through `break_chain()`, so they report `by_hit == false`.
   - `tests/test_chain_state.gd` is extended (it is the chain's spec): `break_by_hit` banks held, resets the count and emits `banked` then `ended(n, true)`; `ended` is not emitted at count 0; `lose()` emits no `ended`; a Snuff emits `ended(n, false)`; a hit while clinging (count paused, held kept) banks the held embers.

   (FR11, AR12; D4)
5. **Bank-heal: +1 HP for a safely banked chain of 10 or more.**
   - New Tuning key `bank_heal_min` = 10 (`BANK_HEAL_MIN := 10.0`, GDD Health "+1 HP when you bank a chain of 10 or more [ASSUMPTION: playtest]").
   - `Player` connects `chain.ended`. When `not by_hit`, it calls `health.bank_heal(links, int(Game.tuning.f(&"bank_heal_min")))`.
   - So a landing, a Snuff, a cling timeout and a room exit count. A hit never does, and a death never does (`lose()`).
   - A Flare Toss (Story 1.23) only moves a share of held embers. It is not an `ended`, so it never heals; 1.23 keeps it off this path.
   - At `MAX` HP nothing changes and nothing is emitted.

   (FR12; D4)
6. **Spikes: a new legend char that deals 1 and returns you to the last safe ground in the same room.**
   - **Legend:** `^` = spike. It is not solid and sits on a floor. Add it to `docs/rooms.md` first, then to `RoomLegend` (`SPIKE := "^"`, and `HAZARDS = ["^"]`), so `is_known()` accepts it. The existing room checks (`ledge_rows`, `hazard_pit_errors`) then cover it with no test edit (D5).
   - **Validator:** a `^` needs something solid below it. The error text is "spike with nothing solid below it", and `test_room_loader` gets a case with a firing sample and a near-miss.
   - **Build:** `RoomLoader` draws each `^` as a `Sprite2D` of `art/spike.png` under a `Hazards` node, and records its cell in `room.hazards` (a `Dictionary` of `Vector2i` → `true`). A floor cell whose upper neighbour is a `^` gets **no ledge rim**, because it is not a ledge (`RoomSweep.ledge_rows` already says so).
   - **Art:** `tools/sprites/spike.txt` (16 × 16, spikes in the bottom 8 rows, palette chars only), built by `python3 tools/build_sprites.py`, then re-imported. Never hand-make the PNG.
   - **Hurt rect:** `Room.touches_hazard(rect: Rect2) -> bool` is true when `rect` overlaps the bottom 8 px of any hazard cell (the drawn spikes) (D5).
   - **World polls hazards like exits** (D5):
     - each physics tick, after the exit check, if `_room.touches_hazard(_player.hurt_rect())`, it calls `_player.hurt(&"spikes")` (no knockback);
     - if the player is still alive, it calls `_player.place_at(_safe_pos)` and `_camera.snap()`;
     - this happens whether or not the hit was refused by invulnerability (Q2: no damage then, but never left standing in spikes).
   - **Per-life safe-ground tracker** (D6):
     - `World._safe_pos` is updated on every physics tick where the player is on the floor and touches no hazard;
     - at every room build it is **seeded** with `room.ground_below(entry)`: the first standing spot straight below the entry cell (falling for an `up` arrival), else the entry position itself;
     - `World.last_safe_position() -> Vector2` is public for Story 1.22's Ember Cache.
   - **Fixture:** `tests/rooms/hazards/t_spikes.txt`, with a header comment "Story 1.19 hazard test room. Not a level." It has `P` on a ledge, a floor run with a `^^^^` stretch and clear floor beside it, a walker `c` on a separate ledge, an in-wall `L`, and an `up` exit that loops to itself (`exits=up:t_spikes@x<c>`, as `m1_shaft` loops). The `up` exit's column lands on clean floor, and the spikes are reachable by steering while falling from it (the seed test, Task 9). `rooms/dev/spikes.txt` is a copy for sonlm's laptop look (validated only, excluded from release by the presets).

   (FR10; D5, D6)
7. **0 HP is death; the respawn has full HP; DevTools gains `--hp=<n>`.**
   - At 0 HP `Player.die(cause)` runs (AC2). `World` respawns as now: the same World instance, no scene reload, a fresh `Player` and so a fresh `Health` at `MAX` (FR13, AR25).
   - DevTools adds an `ARGS` row: `"hp": {help = "--hp=<n>: every life starts with n HP (1–4)", apply = &"_apply_hp", repeat = false}`.
     - It is applied on every `player_spawned` through `player.health.reset(n)`, with its own handler, so `--chain`'s `_on_player_spawned` connection and its tests are untouched.
     - Pure `hp_value(s) -> [n, err]` refuses non-integers, more than `MAX_INT_CHARS` characters, and values outside 1..`Health.MAX`, with a warning, never an error.
     - The row goes after `chain` and before `glow` in `ARGS`.
   - Overlay 2 adds a line under the light readout: `hp 3/4` plus `inv 0.42 s` while invulnerable, so the laptop check can see HP before Story 1.25's pips. Overlay 3 marks `World.last_safe_position()` with a small cross.

   (FR13, AR53; D8)
8. **Hit flash, invulnerability blink and the squash, through the Fx gate.**
   - **Hit flash:** for 4 physics ticks (67 ms, starting on the hit tick), the sprite draws pure white through `Fx.flash_material()`. That is a code-built, cached `ShaderMaterial` (`shader_type canvas_item; render_mode unshaded;`, `COLOR.rgb = vec3(1.0);`). Probed: white under the dark `CanvasModulate`, transparent texels untouched, and it composes with the blink's `modulate.a`.
   - **Under reduce flashing:** instead, `self_modulate` drops to 0.6 for 6 ticks (100 ms) (UX-DR126 "a short dim").
   - `Fx.hit_flash(item: CanvasItem, tick: int) -> bool` is the one function that draws the effect and restores the item afterwards (`material = null`, `self_modulate = Color.WHITE`). It reads the gate itself, so `player.gd` never reads the setting (lint `a11y_gate`).
   - A lethal hit flashes like any other (AC2), and the flash keeps ticking while dead, so the dead sprite is restored after its 4 ticks and never stays white.
   - **Flash cap** (Q1, sonlm: once per second): a new white flash starts only if at least `Fx.HIT_FLASH_GAP_TICKS` (60) ticks have passed since the last one; the dim and the blink always run. Simulated: hits every 0.6 s with the M1 blink reach 4 flashes per second without the gap, and 3.0 with it.
   - **The squash's clock** (ledger item, owner 1.19): the pogo squash recovers on the physics tick at one tick = 1/60 s of real time (`1.0 / Engine.physics_ticks_per_second`, as `CameraRig` and `PlayerInput` count it). It never uses `delta / Engine.time_scale` in `_process`, which snapped it back on the hit frame. `Player._process` goes.
   - `Fx.EFFECTS`:
     - a new row `hit_flash` (`ONCE`, `fn = "hit_flash"`, `reduced` = the 60% dim for 100 ms, and the gap's reason);
     - `pogo_squash`'s `why` says it now runs on the physics tick.
   - `flash_material` joins `test_fx`'s `NOT_EFFECTS`.
   - `Fx.warm_up()` draws a fourth item, a `Sprite2D` with `flash_material()` at `WARM_ALPHA`, so the shader compiles at room load (AR46). `smoke_world`'s "three items" pin becomes four.
   - The defaults (white 67 ms, dim 60% for 100 ms, the gap) are reviewed at the CP2 gate (Story 1.30).

   (FR10, NFR8, UX-DR125, UX-DR126, AR46, AR57; D9, D10)
9. **Pillar 2's guarantees stay tested, now as "no damage", not "not dead".**
   - `smoke_rooms` contact test: touching an IDLE or a TELEGRAPHING lurker deals **no damage** (no `damaged` signal, HP unchanged). The control is a HUNTING lurker at contact dealing exactly 2 (`damaged(2, &"lurker")`), not a death.
   - `smoke_rooms` escape tests (landing, cling, Snuff) run with the player's physics **on** (the poll lives there). They assert no `damaged` from the escape frame until 1.2 s later, and HP still `MAX`.
     - The Snuff is a real hold of `light`, **in mid-air** (the floor block breaks the chain on every floor tick, so a grounded player has no chain to Snuff). Place the player at an open spot (`_open_spot`, as `_test_contact` does), add the links, and press `light`. On the hold's tick before it becomes a Snuff (held tick ⌈window × 60⌉ − 1, so tick 7 at 0.12 s), put the lurker into HUNT at `gap`. The existing premise "lethal the frame before" then still holds, and the Snuff lands before the player can reach a floor (check `not is_on_floor()` on the Snuff tick as a premise).
     - "Snuff point-blank" stays a lurker-level check (`monitorable` off on the frame after the Snuff, player physics off), because with physics on a HUNT lurker on the player hits before any Snuff can land. Its comment says so (D3).
   - New: **the tightest in-time escape.** The player lands on tick T while the hunting lurker reaches contact on T+1, and there is no damage. This is a guarantee check, not the `monitorable`-read red-check: a lurker that moves into overlap on T+1 has already dropped `monitorable`, so it is never listed.
   - **The `monitorable` read itself** is proven by the stale-list case (Task 9, D12). With the lurker's physics off, it sits on the player with `monitorable` true until the overlap list has it. Then, between ticks, it is set false, and that tick's poll sees it listed but not monitorable: no damage. Without the read, it fails.
   - "A predator damages only while `monitorable`" replaces "kills" in `project-context.md` and in the code comments.

   (NFR10, Pillar 2; D3)
10. **Done means green, checked, documented and looked at.**
    - `cd game && ./run_tests.sh` gives `== ALL GREEN`.
    - Every new check is red-checked (D12).
    - The ledger is updated: the squash item is closed, and new items carry owners (D13).
    - The docs are updated (D14).
    - sonlm's laptop feel check is recorded (Task 12). The report says "tests green; needs a feel check on the laptop" until then.

## Tasks / Subtasks

- [x] **Task 1: Baseline (AC: 10).**
  - At story creation on `9a265d9` (2026-11-22), `cd game && ./run_tests.sh` gave `== ALL GREEN (27 tests)`, 1825 `ok`.
  - Re-run it and record the result in the Dev Agent Record.
- [x] **Task 2: `rules/health.gd` + `tests/test_health.gd` (AC: 1, 5).**
  - [x] Write `Health` as AC1 says. Header `##`:
    - per-life (AR12): a new Player means a new Health, so a respawn is full HP (FR13);
    - the damage table is rules data, not `Tuning`, because no gear or difficulty bends it (FR25: difficulty "never … damage");
    - `CAUSES` is the cause-id registry and is save data (never renamed).
  - [x] Cite the GDD on each const ("GDD Health and damage", "GDD Combat enemy table").
  - [x] Add to `tests/spec.gd`, each with its `## GDD` citation (lint `spec_citation`):
    - `MAX_HP := 4`;
    - `DAMAGE := {&"crawler": 1, &"boss": 1, &"lurker": 2, &"hazard": 1}`;
    - `INVULN_S := 0.6`;
    - `BANK_HEAL_MIN := 10`.
    - Write each const, the dictionary too, **on one line** ending in its `## GDD …` comment: `test_lint`'s `uncited_consts` reads the citation from the `const` line itself.
  - [x] `tests/test_health.gd` (pure; fresh `Health.new()` per case). Expected values come from `Spec`, never from `Health`'s consts:
    - the table: every `Spec.DAMAGE` row equals `Health.DAMAGE`, and each cause hits for its row;
    - every `CAUSES` value is a `DAMAGE` row, and every cause id is lower snake case;
    - the start is `Spec.MAX_HP`;
    - a hit emits `damaged(amount, cause)` then `changed(hp)`;
    - an overkill (1 HP, lurker) loses 1, so `damaged(1, &"lurker")`, and `is_empty()` is true;
    - invulnerability: a second hit inside `invuln_s` returns 0 and emits nothing; `tick()` past it allows the next; `invulnerable()` matches;
    - a hit at 0 HP is refused;
    - `heal()` clamps at MAX and emits nothing at MAX;
    - `bank_heal()` at `Spec.BANK_HEAL_MIN` heals, and at one below does not (firing sample and near-miss), and never past MAX;
    - `reset(n)` clamps to 1..MAX and clears invulnerability.
  - [x] Add `bank_heal_min` to `Tuning` (`BANK_HEAL_MIN := 10.0`, `##` unit + intent + "GDD Health; new in M2"), and add it to `BASE`.
    - `test_tuning`: `_test_base`'s "BASE has the 34 keys from the M1 exports" becomes 35, and its message says `bank_heal_min` is new in M2. `_test_m1_fixture`'s last check ("every BASE key comes from exactly one M1 export") would call it an orphan. Add a test-local `M2_KEYS: Array[StringName] = [&"bank_heal_min"]` and expect `seen == 0` for those keys and `== 1` for the rest. `_test_key_literals` needs nothing: `player.gd` reads the key.
    - Add a check that `Tuning.BANK_HEAL_MIN == Spec.BANK_HEAL_MIN`.
- [x] **Task 3: ChainState (AC: 4).**
  - `break_by_hit()` and `ended(links, by_hit)` as AC4. Update the header (M1's "a knock BANKS the pile" becomes "any hit banks the pile through `break_by_hit()`").
  - Extend `test_chain_state.gd` (add the names to its `run()` list) with the AC4 cases. Read the file first: it is the spec (project-context).
- [x] **Task 4: Player (AC: 2, 3, 5, 7, 8).**
  - [x] `var health := Health.new()`. `_tick_timers` calls `health.tick(delta)` and reads the blink from `health.invuln`. `_invuln` is deleted.
  - [x] `hurt(cause, from := Vector2.INF) -> bool` (AC2). `_take_knockback` folds into it.
  - [x] Contact poll: rename `_check_contact()` to `_poll_contacts()`.
    - Predators come first, through `get_overlapping_areas()` with `area.is_in_group(&"predator") and area.monitorable and area.has_method(&"contact_cause")`.
    - Crawlers follow, as now.
    - It returns after the first hit.
    - It keeps its place at the end of `_physics_process`, after the landing break.
  - [x] Delete `_on_hurt_area` and the `area_entered` connection.
  - [x] `chain.ended.connect(_on_chain_ended)`, which bank-heals when `not by_hit` (AC5).
  - [x] `die(cause := &"")` sets `death_cause` first. Everything else in `die()` stays (Clock clear, `chain.lose()`, the lost popup, `died.emit()`).
  - [x] `hurt_rect() -> Rect2`: the Hurtbox shape's global rect, which World's hazard poll uses.
  - [x] `place_at(pos: Vector2)`: the in-room teleport.
    - It sets `position`, zeroes `velocity`, ends the cling, the dash and the swing, and resets `_coyote` / `_jumping`;
    - it then calls `reset_physics_interpolation()` (AR6: a teleport, never a smear).
  - [x] Hit flash:
    - `_flash_tick := -1` and `_last_flash_frame`;
    - on a hit that passes the Q1 gap, `_flash_tick = 0`;
    - in `_physics_process`, before the `is_dead` return, call `Fx.hit_flash(_sprite, _flash_tick)` while it is ≥ 0, and advance it.
  - [x] The squash recovers in `_physics_process` at one tick = `1.0 / Engine.physics_ticks_per_second`, before the `is_dead` return like the flash. Delete `_process`. The recovery rate is unchanged (12 per second).
  - [x] Header comment:
    - "Touching a predator kills" becomes "a hit costs HP (Health); a predator hurts only while monitorable";
    - the class comment says `hurt()` is the one damage path.
  - [x] `Crawler.contact_cause()` and `Lurker.contact_cause()` (AC2, AC3). Update the lurker's comments that say "kills" ("harmless until it hunts: contact hurts only after a telegraph").
- [x] **Task 5: Fx (AC: 8).**
  - Add:
    - `HIT_FLASH_TICKS := 4` (67 ms);
    - `HIT_DIM_TICKS := 6` (100 ms);
    - `HIT_DIM := 0.6`;
    - `HIT_FLASH_GAP_TICKS := 60` (Q1; `## ` the reason: with the M1 blink, back-to-back hits at the 0.6 s invulnerability reach 4 flashes per second without it, NFR8);
    - `flash_material()`, a cached static `ShaderMaterial` built from code (no `.tres`);
    - `hit_flash(item, tick) -> bool`.
    - Each const gets `##` with its source (epics 1.19, UX-DR126) and "reviewed at 1.30".
  - Add the `hit_flash` EFFECTS row and update `pogo_squash`'s `why`. Add `flash_material` to `test_fx.NOT_EFFECTS`.
  - Add the warm-up's fourth item (`Sprite2D`, `art/player.png`, `flash_material()`, `WARM_ALPHA`), and update `smoke_world`'s count and message to four.
  - In `test_fx`:
    - `hit_flash` draws white (`material == flash_material()`) for ticks 0–3 and restores at tick 4;
    - under reduce flashing it gives `self_modulate` 0.6 for ticks 0–5, the material stays null, and it restores at 6;
    - a setting flipped mid-flash restores cleanly.
  - **The combined-cap check:** a pure simulation that samples the player sprite's brightness per tick (white / lit / dark from `Fx.blink_alpha`, white from the gap rule) for hits every `Tuning.INVULN_TIME` seconds. In any 60-tick window it counts at most `Spec.FLASH_HZ_MAX` flashes (opposing-transition pairs). It is red-checked with the gap set to 0 (it reads 4.0).
- [x] **Task 6: Rooms: the spike (AC: 6).**
  - Legend, validator, build, art, `room.hazards`, `touches_hazard()` and the no-rim rule (AC6), in the "Adding a char" order of `docs/rooms.md`.
  - `Room.ground_below(entry: StringName) -> Vector2`:
    - scan down the entry cell's column for the first solid cell whose upper neighbour is open and not a hazard, and return the standing position on it (the same feet formula as `entry_position`);
    - else return `entry_position(entry)`.
    - In `m1_shaft` the top entry (3, 1) finds `P`'s ledge at row 5 (checked at story creation).
  - Build `t_spikes.txt` and `rooms/dev/spikes.txt`. `smoke_rooms` must stay green: the dev room is validated only.
  - `test_room_loader`:
    - `^` parses;
    - the validator case;
    - `room.hazards` has the cells;
    - a floor under `^` has no rim, while its neighbour floor does;
    - `touches_hazard` fires on the bottom 8 px and not on the top 8 px (firing sample and near-miss);
    - `ground_below` gives the scan result, the fallback when the column ends on a spiked floor, and the open bottom.
- [x] **Task 7: World (AC: 6, 7).**
  - In `_physics_process`, after the exit check:
    - the safe tracker update;
    - the hazard poll (AC6).
    - Today the function `return`s when no side is crossed (`if side == &"": return`). Restructure it so the exit branch returns only when it crossed (swap or backstop death), and the tracker and the hazard poll run on every other tick.
  - `_swap_room()` seeds `_safe_pos = room.ground_below(entry)` on every build, after the player is placed.
  - Add `last_safe_position()`.
  - Header comment: World tracks the per-life safe ground for hazards and (1.22) the Ember Cache.
  - The perf run masks only the Hurtbox. `perf_worst` has no spikes, so the run stays untouchable. Say so in `perf_run.gd`'s comment, and add a ledger line: a spike in a perf room would hit the autopilot (owner Story 7.13).
- [x] **Task 8: DevTools (AC: 7).**
  - `--hp` row, `hp_value()`, `_apply_hp`, and its own `player_spawned` handler.
  - The overlay 2 HP line, and the overlay 3 safe-ground cross.
  - `test_dev_args`: `hp_value` for "1", "4", "0", "5", "-1", "x", "99999".
  - `smoke_dev_tools`:
    - `--room=t_dev_room --hp=1`: the first life has 1 HP, and so does the respawned one;
    - a bad `--hp` warns and connects nothing.
- [x] **Task 9: `tests/smoke_health.gd`, on World with `tests/rooms/hazards/` (AC: 2–8).**
  - Set up as `smoke_room_swap` does: `Game.store.dir` points at a temp folder, `RoomLoader.add_root("res://tests/rooms/hazards")`, and `World.start_room = &"t_spikes"`. Pick nodes by position, never by group index.
  - **Crawler contact.** Drive the player into the walker:
    - exactly one `damaged(1, &"crawler_walker")`;
    - HP 3;
    - `velocity` at (±150, −150) on the hit tick, away from the walker;
    - `health.invuln` ≈ `Spec.INVULN_S`;
    - no second hit while invulnerable, though still overlapping;
    - a held 6 → carried + 6 (`Game.dive.carried`).
  - **Lurker:**
    - `_enter(HUNT)` placed on the player gives `damaged(2, &"lurker")`, HP 2, and knockback away from it;
    - IDLE, TELEGRAPH and RETURN on the player give no damage;
    - **The stale-list case** (the `monitorable` read; D3, D12):
      - with the lurker's `set_physics_process(false)`, place it on the player in HUNT with `monitorable` true, give the player `health.invuln` > 0 for that first tick so it can't hit, and wait until `_hurtbox.get_overlapping_areas()` lists it;
      - clear the invulnerability and, right after an `await` (before that tick's callbacks), set `monitorable = false`;
      - that tick's poll sees it listed but not monitorable: no `damaged`;
      - premise: the list still holds the lurker on that tick (probe t7, Verified facts).
  - **Spikes:**
    - walk off onto `^^^^`: one `damaged(1, &"spikes")`, then the player is placed at `last_safe_position()`, which is the floor beside the spikes (`touches_hazard` false there) and not the ledge they walked off;
    - `velocity` zero and the camera snapped;
    - with `health.invuln > 0`, a spike returns the player with no `damaged` (Q2).
  - **Seed, on an `up` arrival** (the case D6 exists for):
    - `t_spikes` carries `exits=up:t_spikes@x<c>` (a self-loop, as `m1_shaft` does), so its `up` entry exists;
    - the column under it lands on clean floor;
    - a spike run is reachable by steering while falling from there;
    - boot a second World with `start_entry = &"up"`: right after the build, before any floor tick, `last_safe_position() == room.ground_below(&"up")`, which is not the entry position;
    - steer into the spikes before touching any floor: the player is returned to that seed, standing, not to the top opening.
  - **Death and respawn:**
    - `--hp`-free, HP 1 via `health.reset(1)`, then a crawler hit: `died` fires once, `death_cause == &"crawler_walker"`, and held embers are lost (`Game.dive.carried` unchanged);
    - the respawn is the same World (`get_instance_id()`), a new Player with HP `Spec.MAX_HP`, and no `reload_current_scene`.
  - **Bank-heal:**
    - with HP 3, give 10 hits via `chain.add_hit()` while airborne, then land: HP 4;
    - with 9: HP stays 3;
    - with 10, then a crawler hit: HP 2 (no heal);
    - with 10, then a Snuff (real `light` hold): HP 4;
    - the room-exit backstop is `chain.break_chain()` (`world.gd` `_on_exit_reached`), the same `ended(n, false)` the landing case drives through the same handler, and `test_chain_state` proves `break_chain()` reports `by_hit == false`. No exit is added to `t_spikes` for it.
  - **Hit flash on the real player:**
    - on the hit tick and 3 more, `_sprite.material == Fx.flash_material()`; at the 4th tick after, null;
    - under `reduce_flashing`, `self_modulate` is 0.6 for 6 ticks and the material is null;
    - a second hit inside 60 ticks shows no white;
    - a lethal hit flashes white on its tick, and the dead sprite's material is null 4 ticks later.
  - **Squash:** after a pogo hit, during the 75 ms hitstop, the sprite's scale is still visibly squashed on the next 2 ticks (y > 1.15). It was snapped to 1 there before (red-check against the old `_process`).
  - End with `world.queue_free()`, a frame, then `Game.reset_for_tests()`.
- [x] **Task 10: Existing tests (AC: 9; D11).**
  - [x] `smoke_rooms` `_test_contact` and `_test_escape` as AC9. Add the tightest-escape case.
  - [x] `smoke_a11y` `_knock()`: `_player.get("_invuln")` becomes `_player.health.invuln`.
    - The walker may knock again as invulnerability ends: with 4 HP the player survives the test's knocks. If not, `health.reset()` between cases.
    - The dark-run check is unchanged. The white flash shows during the first lit phase (ticks 0–3), so it adds no dark run.
  - [x] `smoke_bot`:
    - on the current line the bot takes 3 crawler knocks in `m1_shaft` (measured at story creation: at (280, 744), (199, 1497) and (285, 1555)), so it now ends at 1 HP and alive;
    - add the bot's HP to its summary line;
    - keep "the bot is alive at the end";
    - if it dies, the line changed: report it, never raise `MAX`.
  - [x] Any other smoke whose shared player now dies from accumulated knocks gets `player.health.reset()` between cases, with a comment. Never a higher `MAX`.
  - [x] Lint:
    - `test_lint` needs no new rule;
    - check `rules_purity` stays quiet on `health.gd`;
    - check `a11y_gate` fires on a `Game.settings.reduce_flashing` read in `player.gd` (a red-check sample if none exists).
- [x] **Task 11: Docs and ledger (AC: 10; D13, D14).**
- [x] **Task 12: HALT for sonlm: the laptop feel check (AC: 10). Human gate.**
  - [x] Build with `tools/export.sh` and hand sonlm the lines (memory: laptop build-look commands).
    - Only the **Web debug** preset keeps DevTools and `rooms/dev/` (`export_presets.cfg`: it excludes `tests/*` only), so the spike look and overlay 2's HP line are on the Web debug build: `?room=spikes`, then backquote for overlay 2.
    - The Windows and Linux builds are release: no `--room`, no overlays, no `rooms/dev/`. Use the Windows build only for the plain `m1_shaft` run (crawler and lurker hits, the squash).
  - [x] Questions:
    1. Does a crawler hit read (white flash, knockback, blink)?
    2. Does a lurker hit read as worse (2 HP)?
    3. Does the spike return feel fair and clear?
    4. Does the pogo squash now show during the hitstop?
    5. With `--set=reduce_flashing:true`, does the dim read as a hit?
    6. Are the spikes readable in the dark (Q3)?
  - [x] **HALT.** Record the answers verbatim in the Dev Agent Record. Anything that fails becomes a ledger item for Story 1.30 (the CP2 kit playtest owns the feel defaults), unless sonlm asks for a change now.

## Dev Notes

### What exists today (read before editing)

- **`player.gd`:**
  - M1 crawler contact is `_check_contact()` → `_take_knockback()` (break the chain, 0.6 s `_invuln`, blink on `modulate.a` through `Fx.blink_alpha`, knockback from `Tuning`).
  - Predators kill through `_hurtbox.area_entered` → `_on_hurt_area` → `die()`.
  - `die()` clears the Clock, `chain.lose()`s the held embers (with the loss popup), and emits `died`.
  - `_process` recovers the pogo squash with `delta / Engine.time_scale` (the ledger's bug).
  - The physics order is: `input.sample()`, timers, Snuff, cling (or horizontal / vertical / attack), `move_and_slide()`, the floor block (landing break), the swing, the contact poll, the light.
  - **Keep this order.** The poll after the landing break is what makes "land in time" work (D3).
- **`chain_state.gd`:** `break_chain()` banks held (`banked`) and resets the count; `lose()` drops held; `set_snuffed(true)` calls `break_chain()`. No signal says why a chain ended.
- **`lurker.gd`:**
  - `monitorable` is true only in HUNT while sensed, and set false at once on losing the scent (`_physics_process` HUNT branch and `_enter`).
  - The lurker is a child of the room, which is under `RoomHolder` before the Player in World's tree, so **each tick the lurker updates before the player polls**.
  - Its header still says it "kills" (update it).
- **`crawler.gd`:** `take_hit()` is the player hitting the crawler. Keep it; `contact_cause()` is new and separate.
- **`world.gd`:**
  - polls exits in `_physics_process` (body centre past floor or ceiling);
  - `_swap_room()` is the only builder and places the player;
  - `_spawn_player()` wires `chain.banked` → `Game.dive.add_carried` and `chain.changed` → `Game.slot.record_chain`;
  - `_on_player_died()` → `Game.slot.record_death()` → the respawn timer (0.6 s) → `_swap_room(..., true)`;
  - the tunnelling backstop calls `_player.die()`.
- **`room_legend.gd`:** `HAZARDS: Array[String] = []`, with a comment that 1.19 adds the spike.
- **`room_loader.gd`:**
  - `solid_at()` is `#` plus an in-wall `L`, so `^` is not solid with no change;
  - `_build()` draws rims on every solid cell whose upper neighbour is open (this must skip a `^` above).
- **`room_sweep.gd`** already treats hazards: a hazard is never a ledge, a floor cell whose open top is a hazard is no ledge, and every hazard that can be fallen onto has a safe row within 19 rows above. `test_room_sweep` covers this with a stand-in `x`. Nothing to change there.
- **`tuning.gd`** already has `knockback_x/y` (150, −150) and `invuln_time` (0.6) under "Damage (… Story 1.19)". `test_tuning` pins the M1 table and "34 keys".
- **`fx.gd`:**
  - `blink_alpha(remaining)` is the 2.5 Hz blink (lit 0.25 s of 0.4 s, `STEADY_ALPHA` 0.5 under reduce flashing);
  - `EFFECTS` declares every effect;
  - `warm_up()` draws three items;
  - `test_fx` reflects over Fx's public statics (`NOT_EFFECTS` lists non-effects).
- **`slot_state.gd:8` and `:69`** say 1.19 adds the death log's cause and room. Story 1.29's AC owns `death_log`. Change both comments to "Story 1.29, from `player.death_cause`" (D7).
- **DevTools:**
  - `ARGS` is a registry, one row per arg (its comment names `hp (1.19)`);
  - `--chain` arms on `player_spawned` via `_on_player_spawned`, and `smoke_dev_tools` checks that connection;
  - overlay 2 draws the player's light lines (`overlays.gd` `_draw_player_marks`).
  - `perf_run.gd` makes the autopilot untouchable by `Hurtbox.collision_mask = 0`, which never stops World's hazard poll.
- **Tests that read the old paths:**
  - `smoke_a11y._knock()` (`_invuln`);
  - `smoke_rooms._test_contact()` (death on HUNT contact) and `_test_escape()` ("still alive"; Snuff with the player's physics off);
  - `smoke_world` (three warm-up items).
  - Many tests call `player.die()` with no argument (`smoke_dev_tools`, `smoke_palettes`, `smoke_room_swap`, `smoke_world`, `smoke_perf`, `test_clock`); they stay valid.
- **Baseline:** 27 tests, 1825 `ok` (Task 1).

### Decisions

- **D1: Health is rules data; cause ids are a registry.**
  - The damage amounts are a const table on `Health`, keyed by the GDD's rows (crawler / boss / lurker / hazard).
  - Cause ids (what the death card and the death log read) map onto those rows.
  - Why not `Tuning`: FR25 says difficulty never changes damage, and no gear bends it in M2. The chain curve stays in `ChainState` for the same reason (Story 1.3 D1).
  - Why two tables: the death card needs finer causes than the damage rows (walker vs hoverer have different avoidance tips, Story 1.28). One cause → one row keeps the amount in one place.
  - E2 adds `weaver_*` causes → `boss` and decides the spiderling's row.
  - Cause ids are save data from Story 1.29 (the death log freezes with `slot_v1`): never rename one.
- **D2: One damage path, lethal first.**
  - `hurt()` asks `Health` first, then branches: lethal → `die(cause)` (held lost); otherwise `break_by_hit()` (held → carried).
  - The other order (break, then damage) would bank the held embers of a lethal hit, against the GDD's "only death loses held embers".
  - `Health` stays ignorant of the chain; `Player` orders the two.
- **D3: Predator contact is polled, and the poll reads `monitorable` itself.**
  - `area_entered` fires once per entry. Under HP, a lurker still overlapping after the 0.6 s invulnerability would never hit again (crawler contact is polled for the same reason, project-context).
  - Probed on 4.7.2: `get_overlapping_areas()` changes only at the physics step after a `monitorable` change. A lurker that turns `monitorable` off in tick T is still listed for a reader later in T, and the list clears at T+1.
  - The poll therefore checks `area.monitorable` directly, which makes "a predator damages only while `monitorable`" exact, with no tick of lag.
  - **Tick order of an escape:**
    1. The player escapes in tick T (landing break, Snuff, cling: all before the poll in `_physics_process`).
    2. The lurker, which runs before the player each tick, re-senses at T+1 and drops `monitorable`.
    3. The player's poll at T+1 reads false.
  - So any contact from T+1 on is safe. A contact on T itself (the lurker already touching as the escape lands) is not "in time": the player was touched while lethal.
  - The point-blank Snuff case can't be a damage test with physics on, so it stays a lurker-level check. The tightest real case (escape on T, contact on T+1) is the new damage test.
- **D4: `ended(links, by_hit)` drives bank-heal.**
  - A safe bank happens in four places: the landing (player), the cling timeout (player), the Snuff (inside `ChainState`) and the exit backstop (World).
  - One signal from `ChainState` covers them all without touching World or the Snuff path. `by_hit` is the only exclusion the AC names; death goes through `lose()`.
  - The threshold rule is pure (`Health.bank_heal(links, min)`) so `test_health` covers it, as the epic AC asks.
  - Flare Toss (1.23) is a partial bank, not an end, so it never reaches this path.
- **D5: The spike is a non-solid floor hazard, polled by World.**
  - `^` sits in the cell above a floor, which is exactly the shape `room_sweep` already assumes. The validator's "something solid below" keeps that true.
  - World polls it like an exit, with no `Area2D` per cell: the exit poll's precedent, deterministic and cheap.
  - The hurt rect is the bottom half of the cell (the drawn spikes), so the head of a player beside a spike run never touches it.
  - World owns the poll because World owns the tracker and the teleport, and the teleport needs the camera snap.
  - No knockback: the GDD's spike row is a return, not a push.
  - Q2 (sonlm): an invulnerable player is still returned, without damage.
- **D6: Safe ground is the last floor tick with no hazard contact, seeded below the entry.**
  - The position is recorded exactly (verified hazard-free on that tick), not cell-snapped, so the return never lands in a spike.
  - An `up` arrival enters falling. With no seed, a spike hit before the first floor tick would return the player to the top opening, and Story 1.22's cache would float, which its AC forbids.
  - `ground_below()` gives the spot a straight fall would reach. It falls back to the entry itself when the column ends on spikes or in an open bottom: then the cache rule is 1.22's to refine (ledger, owner 1.22).
  - It is per-life, because every build (respawn or exit) reseeds it.
- **D7: The death cause.**
  - `die(cause := &"")` stores `death_cause`.
  - `died` keeps its signature: about ten tests connect zero-argument lambdas.
  - A death with no cause (World's tunnelling and failed-room backstops, a test's `die()`) is `&""`.
  - The death log and the card's fallback line for `&""` are Story 1.29's (ledger line, owner 1.29).
- **D8: `--hp` arms every life.**
  - It works like `--chain` (D6 of 1.11), so the E2 Weaver work can start each life at 1 HP.
  - It has its own handler, so the `--chain` connection checks stay true.
  - The overlay line exists because no HP HUD exists until Story 1.25 and the feel check needs one.
- **D9: The hit flash is a shader swap, counted in physics ticks.**
  - `modulate` can't make a sprite white (it multiplies), and a white silhouette sprite would need art per frame. A code-built unshaded shader does it (probed).
  - It is swapped in only for the flash, so the normal draw path and batching don't change.
  - Ticks, because physics ticks run at 60 per real second even under hitstop (Story 1.8 D3), and a hit can land in a pogo's hitstop.
  - It is the same fix the ledger asks for the squash (one tick = 1/60 s, as `CameraRig` does since 1.16).
  - The material is warmed up at room load (AR46).
- **D10: The flash cap counts the flash and the blink together (Q1).**
  - The UX lists both on the same sprite.
  - Simulated per tick at story creation: hits every 36 ticks (back-to-back at the 0.6 s invulnerability) reach 4 flashes in some 1 s window (4.0); every 40 ticks 3.5; every 48, 3.0.
  - Showing the white flash at most once per 60 ticks brings every case to ≤ 3.0. The blink and the reduced dim are unchanged.
  - A crawler re-hit as invulnerability ends happens only when the player walks back into it, but a lurker re-hits at once, so this is reachable in play.
  - sonlm chose this (Q1, answered at story creation).
- **D11: Tests change where M1's one-touch death was their premise.**
  - Every guarantee keeps its strength: "not dead" becomes "no `damaged`, HP unchanged", which is stricter (a 2-damage hit no longer slips through).
  - Never loosen a threshold; never raise `MAX` to keep a smoke alive.
- **D12: Red-checks.** Break each once, see `FAIL`, restore:
  - `hurt()` banking before damage: the lethal-hit check fails (held carried);
  - the poll without the `monitorable` read: the stale-list check fails (the tightest escape stays green; it is a guarantee, not this red-check);
  - `break_by_hit()` emitting `ended(n, false)`: the crawler bank-heal check fails;
  - the `^` rim not skipped: `test_room_loader`'s rim case;
  - `_safe_pos` not seeded: the seed check;
  - spikes skipped while invulnerable: the Q2 check;
  - `HIT_FLASH_GAP_TICKS` 0: the cap simulation and the second-hit check;
  - the flash not ticked while dead: the lethal-hit check that the sprite's material is null 4 ticks later;
  - the lethal branch skipping the flash: the lethal-hit white check;
  - the squash back in `_process`: the squash check;
  - `--hp=0` accepted: `test_dev_args`;
  - `Health.DAMAGE` lurker 1: `test_health`'s table check against `Spec`.
- **D13: Ledger** (`deferred-work.md`):
  - close "The pogo squash is undone on the hit frame" with `→ **Closed (Story 1.19): the squash recovers on the physics tick at one tick = 1/60 s; the hit flash is counted in ticks; smoke_health checks both in a hitstop.**`;
  - new items under "Deferred from: dev of 1-19-…", each with its owner line:
    - the death card's line for a death with no cause → **Owner: Story 1.29**;
    - the cache when `ground_below()` falls back to a mid-air entry → **Owner: Story 1.22**;
    - a spike in a perf room would hit the autopilot → **Owner: Story 7.13**;
    - spike readability in real rooms (art, light) → **Owner: E4** (the first story that places a real spike; Q3, sonlm: lit like walls until then);
    - the bot's HP margin (3 knocks of 4 HP in `m1_shaft`) → **Owner: Story 1.30**, for the CP2 playtest to note whether the bot line or the crawler placement should change.
- **D14: Docs.**
  - `docs/component-inventory.md`:
    - a new `health.gd` row;
    - the `player.gd` row (the `hurt()` path, the poll, `place_at`, `death_cause`, no `_process`);
    - `chain_state.gd` (`break_by_hit`, `ended`);
    - `crawler.gd` / `lurker.gd` (`contact_cause`);
    - `world.gd` (hazard poll, safe ground);
    - `room.gd` / `room_loader.gd` / `room_legend.gd` (`^`);
    - `fx.gd` (hit flash, flash material, the fourth warm-up item);
    - `dev_tools.gd` / `overlays.gd` (`--hp`, the overlay lines).
  - `docs/rooms.md`: the legend row for `^`, the Hazards paragraph (now real), the validator error, and "no rim on a spiked floor".
  - `docs/development-guide.md`:
    - the test list (`test_health`, `smoke_health`);
    - the DevTools args (`--hp`);
    - a Common Tasks row "Damage the player": `player.hurt(cause, from)`, a new cause goes in `Health.CAUSES`, never a direct `health.hit`.
  - `docs/architecture.md`: the death and hazard flow.
  - `docs/source-tree-analysis.md`: `rules/health.gd`, `tests/rooms/hazards/`, `rooms/dev/spikes.txt`, `tools/sprites/spike.txt`.
  - `game/README.md`: the test list.
  - `project-context.md`:
    - one sentence in the Story list for 1.19;
    - the predator rule: "A predator damages only while `monitorable == true` … the player's poll reads `monitorable` itself";
    - "Crawler contact is polled" becomes "Crawler and predator contact are polled";
    - the Last Updated line.
  - `game-architecture.md`: Health as built (`hurt()`, `CAUSES`, bank-heal via `ended`), and Hazard respawn (World's poll, `ground_below` seed, `last_safe_position()`); the Entry args row (`--hp` landed).
  - GDD: the Health bullet gets "the threshold is `Tuning` `bank_heal_min`", and the spike row "while invulnerable, no damage, still returned (sonlm, 2026-11-22)". The Accessibility flash line gets "the hit flash shows at most once per second, so it and the 2.5 Hz blink stay within 3 flashes/s (sonlm, 2026-11-22)".
  - `decision-log.md` (beside the GDD): a dated 2026-11-22 entry for Q1 and Q2 (Story 1.19), with the 4.0 → 3.0 simulation as the why.
  - `EXPERIENCE.md`: a dated note under Game Feel & Juice's reduce-flashing table (Hit flash row): the white flash at most once per second (Story 1.19, sonlm). Append it; don't rewrite the 2026-11-11 table.

### Questions for sonlm (answered at story creation, 2026-11-22)

- **Q1 (D10): the hit flash and the flash cap.** With the M1 blink, back-to-back hits (one as each 0.6 s invulnerability ends, which a hunting lurker can do) reach 4 flashes per second against the cap of 3.
  - (a) **Recommended:** the white flash shows at most once per second (the dim and blink unchanged), giving ≤ 3.0.
  - (b) Keep both as designed and change the GDD's cap wording to exempt the player sprite (sonlm and GDD first).
  - (c) Drop the white flash; use the dim in both modes.
  - **Answer (sonlm): (a), the white flash at most once per second.**
- **Q2 (D5): spikes while invulnerable.**
  - (a) **Recommended:** returned to safe ground, no damage.
  - (b) Damage anyway (spikes ignore invulnerability).
  - (c) Nothing happens until invulnerability ends (the player may stand in spikes for up to 0.6 s).
  - **Answer (sonlm): (a), returned, no damage.**
- **Q3 (D13): spike readability in the dark.**
  - (a) **Recommended:** the spike sprite is lit like walls now, and E4 decides with real rooms (ledger).
  - (b) Draw spikes unshaded now, like ledge rims, so they always read.
  - (c) Give the spike a faint unshaded rim line like ledges.
  - **Answer (sonlm): (a), lit like walls; E4 decides with real rooms (ledger, D13).**

### Testing standards

- Tests extend `Node` and run through `tests/runner.tscn`. They print `ok …` / `FAIL …` and a final `PASS` / `FAILED`. Any `SCRIPT ERROR` / `ERROR:` line fails the run.
- Name tests `test_*.gd` / `smoke_*.gd`.
- **Pure rules → `test_health.gd`**, never into `test_chain_state.gd`, except the chain's own cases (AC4), which belong in its spec.
- **Expected values come from `Spec`** (GDD literals with citations), never from `Health`'s or `Tuning`'s consts.
- World smoke tests:
  - set `World.start_room` before `add_child`, and add the root through `RoomLoader.add_root`;
  - pick by position;
  - a respawn rebuilds the room, so re-take references;
  - a test that changes `Game` state ends with `Game.reset_for_tests()`;
  - free every node (an exit-time leak prints an engine `ERROR:`).
- Frame maths (measured on 4.7.2, `development-guide.md`): a press made after an `await` is first seen two ticks later, and a read after an `await` sees the last tick the player ran.
- Headless can check numbers, signals and materials, but can't judge feel. Report "tests green; needs a feel check on the laptop" until Task 12.

### Project Structure Notes

- **New:**
  - `scripts/rules/health.gd` (+ `.gd.uid`);
  - `tests/test_health.gd`, `tests/smoke_health.gd` (+ uids);
  - `tests/rooms/hazards/t_spikes.txt`;
  - `rooms/dev/spikes.txt`;
  - `tools/sprites/spike.txt` → `game/art/spike.png` (+ `.import`).
- **Changed:**
  - `scripts/actors/player.gd`, `crawler.gd`, `lurker.gd`;
  - `scripts/rules/chain_state.gd`, `tuning.gd`, `slot_state.gd` (comments);
  - `scripts/core/fx.gd`;
  - `scripts/world/world.gd`, `room.gd`, `room_loader.gd`, `room_legend.gd`;
  - `scripts/dev/dev_tools.gd`, `overlays.gd`, `perf_run.gd` (comment);
  - `tests/spec.gd`, `test_chain_state.gd`, `test_tuning.gd`, `test_fx.gd`, `test_room_loader.gd`, `test_dev_args.gd`, `smoke_rooms.gd`, `smoke_a11y.gd`, `smoke_world.gd`, `smoke_bot.gd`, `smoke_dev_tools.gd`;
  - docs, ledger, GDD, `decision-log.md`, `EXPERIENCE.md` (a dated note).
- **Layering:**
  - `health.gd` is `rules/` and names nothing above it;
  - `Fx` (core) gains a material and a function;
  - World (world) reads `Room`;
  - Player (actors) reads `Health` and `Fx`.
  - No autoload, addon or `.tres`; the shader is code.
- **Export:** `rooms/dev/*` and `tests/*` are excluded from release (presets, `test_export_presets`), so the dev and fixture rooms never ship. `art/spike.png` ships (the art is loaded by `RoomLoader`). `test_export_presets` needs no change.

### Project Context Rules (from `project-context.md`)

- Godot 4.7.2, GDScript only, GL Compatibility, 480×270 at integer scale, physics 60 ticks/s, physics interpolation on (move gameplay nodes only in `_physics_process`; `reset_physics_interpolation()` after every teleport).
- **State in pure objects:** per-life on `Player` (`ChainState`, `Health`, `PlayerInput`). Death never reloads; World spawns a fresh Player and emits `player_spawned`, where anything bound to `player.health` rebinds (1.25).
- **Only `Game.clock` writes `Engine.time_scale`.** No hitstop on a hit is asked for here, so don't add one.
- **Predators sense light only through their rules; a predator damages only while `monitorable`, only while the player is its target.** Never add a hurt path around it.
- **Crawler contact is polled** (now predator contact too). Actors find each other by group and duck typing (`contact_cause()`, `take_hit()`), never node paths.
- **Tuning is data:** a `const` with a `##` unit, intent and source, listed in `BASE`. Change a value → update the GDD table.
- **Levels are text; the legend lives only in `room_legend.gd` and `docs/rooms.md`.** A new char goes to `docs/rooms.md` first.
- **Sprites:** edit `tools/sprites/*.txt`, run `python3 tools/build_sprites.py`, re-import. Never hand-make a PNG.
- **Accessibility:** every flashing or pulsing effect reads the gate through `Fx` (lint `a11y_gate`), and every new effect adds an `Fx.EFFECTS` row. ≤ 3 flashes/s anywhere; blinks at 2.5 Hz.
- **Cache materials as statics; warm up new effects at room load.**
- **No randomness in level behaviour.**
- **Errors:** programmer errors → `assert`; content errors → pure validator + `push_error`; never `free()`; no bare `print()`.
- **Every deferred item gets an owner line, set by the agent that defers it.**
- Commit `.gd.uid` and `.import` files with their sources.

### Previous story intelligence (1.16–1.18)

- **1.16** made `Fx` the accessibility gate. It left this story the squash ledger item: a real-time visual started on a hit tick can't use `delta / Engine.time_scale` (the delta was scaled before the request; probed). `CameraRig` counts one tick as 1/60 s. 1.16's review also taught that a check whose expected value comes from the code under test proves nothing.
- **1.17** owns the popups' text (`POPUP_BANKED`, `POPUP_LOST`). No new strings here.
- **1.18** set `Game.palette`. Nothing here draws UI colours: the white is the flash shader's, and spike art uses the sprite palette (world art stays violet until E4).
- **1.18's review:** the warm-up must draw what the real effect draws. The flash item uses the real material.
- **1.18's review:** state what each check proves, with exact expected counts and positions, not floors.
- **Memory:** probe engine claims before acting on them. The two D3 facts and the D9 render were probed at story creation.
- **Git:** recent commits move docs, the ledger and `project-context.md` with each story (`209e458`, `9a265d9`); keep that habit.

### Verified facts (probed 2026-11-22 at story creation)

- **Overlap lag (4.7.2, project runner):**
  - An `Area2D` turned `monitorable` in tick T is first listed by another area's `get_overlapping_areas()` in T+1.
  - Turned off in T, it is **still listed for a reader later in T** (a reader node at priority +10 after the flipper at −10) and gone from T+1.
- **Flash shader (xvfb, `--rendering-driver opengl3`):**
  - `shader_type canvas_item; render_mode unshaded; void fragment() { COLOR.rgb = vec3(1.0); }` on `player.png` under a `CanvasModulate` of (0.07, 0.06, 0.11) draws every opaque texel `#ffffff`, and transparent texels show the clear colour.
  - With `modulate.a = 0.5` it draws `#a6a6a6` over `#4d4d4d` (it composes with the blink).
  - The same sprite without the material draws `#030207`–`#120c0d`.
  - `self_modulate = 0.6` darkens it (the dim).
- **Flash count** (Python, per tick, the M1 blink's `fmod(remaining, 0.4) < 0.25`, flash 4 ticks), max flashes in a 60-tick window:

  | Hits every | No gap | With the 60-tick gap |
  |---|---|---|
  | 36 ticks | 4.0 | 3.0 |
  | 40 ticks | 3.5 | 3.0 |
  | 48 ticks | 3.0 | 3.0 |
  | 60 ticks | 2.0 | 2.0 |

  A single hit's transitions are at ticks 4 (white → lit), 12 (lit → dark) and 22 (dark → lit), so the flash sits inside the first lit phase.
- **The bot's knocks** (current tree, `smoke_bot`, `m1_shaft`): 3, at (280, 744), (199, 1497) and (285, 1555). Its best chain is 8 (no bank-heal), and it exits down alive.
- **`m1_shaft`:** the top entry is cell (3, 1), and column 3 first meets solid at row 6 under `P` (row 5), so `ground_below(&"up")` is `P`'s spot.
- **Baseline:** `== ALL GREEN (27 tests)`, 1825 `ok`.

### References

- Story source: `_bmad-output/planning-artifacts/epics.md` → Story 1.19 (FR10–FR13, AR12); neighbours 1.20 (Sensing), 1.22 (cache at the last safe ground), 1.23 (Flare Toss never bank-heals), 1.25 (pips bind to `player.health`), 1.28 (E1 causes), 1.29 (death card, `death_log`), 1.30 (feel defaults).
- GDD `gdd.md`: Health and damage (M2); Chain table ("Any hit … breaks, → carried"); Combat System (enemy table, Defense); Level Design (hazard pits); Accessibility (flash cap).
- Architecture `game-architecture.md`: State Management (per-life `Health`), Rules layer, Hazard respawn, the death flow, Debug Tools (Entry args `--hp`), Design Guarantees as Tests.
- UX `EXPERIENCE.md`: Game Feel & Juice (HP lost, Invulnerable; the reduce-flashing table "Hit flash: Flash → A short dim"); Accessibility Floor (flash cap). `DESIGN.md`: reserved red is never damage or low HP (no red here).
- Ledger: `deferred-work.md` → "The pogo squash is undone on the hit frame" (owner Story 1.19).
- Previous story: `1-18-palette-tokens-contrast-and-the-deck-size-check.md`.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), via `/gds-dev-story`.

### Debug Log References

- Story creation (2026-11-22, `9a265d9`): `./run_tests.sh` → `== ALL GREEN (27 tests)`, 1825 `ok`, 0 `FAIL`.
- Task 1 baseline (dev, 2026-11-22, `9a265d9`): `./run_tests.sh` → `== ALL GREEN (27 tests)`, 1825 `ok`, 0 `FAIL`, as at story creation.
- Order: Fx's flash API (Task 5) went in before Player's flash subtask (Task 4), and the smoke_rooms / smoke_a11y / smoke_bot edits (Task 10) went in during Task 4's gate, because Task 4 calls `Fx.hit_flash` and removes their one-touch-death premise. Each box was ticked only once its task was whole.
- `Fx.hit_flash(item, tick, white := true)`: a third parameter beyond the story's `hit_flash(item, tick)`. AC8 says the white flash is gap-limited while the dim always runs, and `player.gd` may not read the setting (lint `a11y_gate`), so the player passes whether the gap allows white (`Fx.white_flash_allowed(last, now)`, the Q1 rule, also used by `test_fx`'s cap simulation) and Fx picks white, dim or nothing. A gapped hit at the defaults shows only the blink; under reduce flashing it still dims.
- The flash tick is `Engine.get_physics_frames()` minus the hit's frame, drawn at tick 0 inside `hurt()`, so a spike hit (World's poll, before the player's tick) and a contact hit (the end of the player's tick) both show white for exactly 4 drawn ticks.
- `t_spikes` (and `rooms/dev/spikes.txt`) carry `exits=up:…@x11, down:…@x14`, a down self-loop beside the story's up one: crossing the ceiling arrives at the target's `down` entry, so `smoke_rooms`' cross-file link check (it walks `rooms/dev/`) fails on an up-only self-loop, as `m1_shaft` has both.
- `tests/rooms/ok_min.txt`'s comment now says it uses every legend char but the spike (`t_spikes` covers it): adding `^` there would move its pinned rims and every `bad_*` fixture built from it.
- `test_fx._test_warm_up` pinned three items too (the story named only `smoke_world`'s pin); both now expect four.
- `smoke_a11y._knock()` resets HP per case: the walker re-knocks as each invulnerability ends, and with HP the default case's knocks killed the player in the reduce-flashing case (a dead player's invulnerability never counts down).
- `smoke_rooms`: the escape tests clear the room's crawlers (their contact is damage now, and the checks are about the lurker); the tightest escape teleports the lurker onto the player right after the landing tick T, so its own T+1 update (it runs before the player) is the first with it touching.
- `smoke_health`'s spike return is read by a Probe node at index 0 under World (after World's poll, before the Player), and found as the first record whose velocity was zeroed after the walk got going: the return jumps back only about a tick of the walk, so a position jump is no sign of it. A body at rest sits at y 195.93 (move_and_slide's safe margin), so the floor-row check allows 0.5 px.
- Red-checks (D12), each broken once, seen `FAIL`, restored:
  - `Health.DAMAGE` lurker 1 → `test_health`: the table against `Spec` and the lurker cause both FAIL.
  - `HIT_FLASH_GAP_TICKS` 0 → `test_fx`'s cap simulation reads 4.0 (36 ticks) and 3.5 (40 ticks), FAIL; `smoke_health`'s second hit shows white, FAIL.
  - The `^` rim not skipped → `test_room_loader`'s rim case FAILs (rims at x 96–144 on row 13).
  - `--hp=0` accepted → `test_dev_args` FAILs.
  - `hurt()` banking before damage → `smoke_health`: held 6 carried on the lethal hit (216 → 222), FAIL.
  - The poll without the `monitorable` read → `smoke_health`'s stale-list case takes `[2, lurker]`, FAIL; `smoke_rooms`' tightest escape stays green (a guarantee, not this red-check, as D12 says).
  - `break_by_hit()` emitting `ended(n, false)` → `smoke_health`'s crawler bank-heal reads HP 3, not 2, FAIL.
  - `_safe_pos` not seeded → `smoke_health`'s seed checks FAIL (safe (0, 0)).
  - Spikes skipped while invulnerable → `smoke_health`'s Q2 check FAILs (never returned).
  - The flash not ticked while dead → the dead sprite's material is not restored, FAIL.
  - The lethal branch skipping the flash → the lethal white check FAILs.
  - The squash back in `_process` (`delta / Engine.time_scale`) → `scale.y` 1.0 and 1.0 on the two hitstop ticks, FAIL (the ledger's bug, reproduced).
- Lint: `test_lint` needs no new rule; `rules_purity` is quiet on `health.gd`; `a11y_gate` already has the firing sample `actors/player.gd` `if Game.settings.reduce_flashing:`.
- Tasks 1–11 done (dev, 2026-11-22): `./run_tests.sh` → `== ALL GREEN (29 tests)`, 1974 `ok`, 0 `FAIL`. `smoke_bot`: `m1_shaft` ends at `hp 1/4` and alive (3 knocks, as measured at story creation).
- Self-review before the build look: `smoke_health` gained AC3's "a predator and a crawler on one tick: the predator is taken" (red-checked: with the crawler loop first it takes `[1, crawler_walker]`, FAIL); the smokes compare HP against `Spec.MAX_HP`, never `Health.MAX`; the "kill / lethal / still alive" wording left in `architecture.md`, `rooms.md`, the development guide's `--perf` row, `perf_run.gd`, `smoke_rooms.gd`, `test_room_sweep.gd` and `project-context.md` now says damage; `component-inventory.md`'s check counts and `source-tree-analysis.md`'s `spike.txt`; two more ledger items (owner E4: the harness's stub World has no hazard poll; no check keeps a down arrival's stand cell off a spike). `./run_tests.sh` → `== ALL GREEN (29 tests)`, 1975 `ok`, 0 `FAIL`.
- A real run of the dev copy, `godot --headless --path game -- --room=spikes --hp=1`: `[room] dev: room spikes@spawn, hp 1`, `[room] SMOKE boot ok`, no error.
- Task 12 build: `tools/export.sh` → `== BUILD OK builds/20261122-9a265d9-dirty` (uncommitted tree, hence `-dirty`), web download 11.0 MB gzip, PCK files windows 90 / linux 90 / web 90 / web_debug 98, Linux release boot 5 s with no error, web smoke 7 passed, 134 s. `art/spike.png` and `rules/health.gd` are in all four PCKs; `rooms/dev/spikes.txt` only in `web_debug`.

- Task 12, laptop feel check, first pass (sonlm, 2026-11-22, build `20261122-9a265d9-dirty`), verbatim:
  1. "yes"
  2. "yes. Also it is way too easy to dodge lurker"
  3. "What spike"
  4. "I don't understand"
  5. "What"
  6. "I can't even see it."
  - Second pass, after 4 and 5 were re-asked in plainer words and the spike options were laid out (sonlm, verbatim):
    - Spikes: "a" (fix the spikes' readability now, then re-check 3 and 6).
    - 4: "hard to notice, i don't think i see it"
    - 5: "I can tell that i got hit"
  - Server render of `rooms/dev/spikes.txt` (xvfb, opengl3): the spikes draw, but as thin dark 8 px strokes, readable only inside the player's light and close to the backdrop colour outside it. 6 fails, and 3 couldn't be judged because of it. 4 and 5 were re-asked in plainer words.

- Spike fix (option a, sonlm 2026-11-22): `RoomLoader` draws each spike with `Fx.unshaded()`, so it reads in the dark like a ledge rim (render checked: visible across the room from the spawn ledge). `test_room_loader` now expects `Fx.unshaded()` (red-checked: without the material it FAILs). `rooms.md`, the inventory, the decision log (Q3 revised the same day) and the ledger's E4 spike item updated; two feel items added for Story 1.30 (lurkers "way too easy to dodge"; the squash "hard to notice"). `./run_tests.sh` → `== ALL GREEN (29 tests)`, 1975 `ok`. Rebuilt: `== BUILD OK builds/20261122-9a265d9-dirty` (same name: the commit is unchanged), 124 s.
- Spike visibility after the fix (sonlm): "Where is the spike. I can't see it". A Playwright screenshot of the served web debug build with `?room=spikes` showed the spikes clearly; sonlm was pointed to the exact URL and a cache-free reload. "Does the desktop have spikes": no (the release build has no `rooms/dev/` and no `--room`).
- Question 3 (sonlm, verbatim, in order): "Wju does it teleport back to start after falling. Can't i just stay on the spike"; then "spikes bounce you up and leave you where you are. I think other games does that too or am i wrong"; then, before any code changed, "just put back on safe ground. Why can't it be nearest safe ground. Also can i even climb up in the game. Does hollow knight allow that"; then, offered (a) keep the last safe ground as built, with the concern ledgered for E4, or (b) the nearest clean floor on the side you came from now: "a". The return stays as built (D5, D6, Q2); ledger item, owner E4.
- Question 6, re-checked after the fix (sonlm, verbatim): "yes i can see them now".
- Task 12 result: 1 pass, 2 pass (note "way too easy to dodge lurker" → ledger, owner 1.30), 3 pass as built (last safe ground kept; "nearest safe ground" → ledger, owner E4), 4 hard to notice → ledger, owner 1.30, 5 pass, 6 failed then passed after the spike fix. Final `./run_tests.sh` → `== ALL GREEN (29 tests)`, 1975 `ok`, 0 `FAIL`.

### Completion Notes List

- `rules/health.gd` (`Health`, per life on `Player.health`): `MAX` 4, `DAMAGE` by the GDD's rows, the `CAUSES` registry (`crawler_walker`, `crawler_hoverer`, `lurker`, `spikes`), `hit()` / `tick()` / `heal()` / `bank_heal()` / `reset()`, `changed` and `damaged(amount, cause)`. `Spec` gained `MAX_HP`, `DAMAGE`, `INVULN_S`, `BANK_HEAL_MIN`; `Tuning` gained `bank_heal_min` 10 (35 keys).
- `ChainState.break_by_hit()` and `ended(links, by_hit)` (not at count 0, not from `lose()`).
- `Player.hurt(cause, from)` is the one damage path (lethal first: `die(cause)`, held lost; else `break_by_hit()`, cling ended, flash, blink, knockback when `from` is finite). Crawler and predator contact are polled at the end of the tick (`_poll_contacts()`, predator first, `monitorable` read at the poll); `area_entered` and `_on_hurt_area` are gone. Bank-heal on `chain.ended` when not `by_hit`. `death_cause`, `hurt_rect()`, `place_at()`. The squash eases on the physics tick; `_process` is gone. `Crawler.contact_cause()`, `Lurker.contact_cause()`.
- `Fx`: `flash_material()` (code-built, cached, unshaded white), `white_flash_allowed()` (Q1: once per 60 ticks), `hit_flash()` (white 4 ticks, or the 0.6 dim for 6 under reduce flashing), the `hit_flash` EFFECTS row, `pogo_squash`'s `why`, the warm-up's fourth item.
- The spike `^`: `docs/rooms.md` first, `RoomLegend.SPIKE` / `HAZARDS`, the validator ("spike with nothing solid below it"), the build (`Hazards` sprites of `art/spike.png` from `tools/sprites/spike.txt`, `room.hazards`, no rim on a spiked floor), `Room.touches_hazard()` (bottom 8 px) and `Room.ground_below()`.
- World: the safe-ground tracker and the hazard poll after the exit check (exits split into `_poll_exits()`), the seed at every build, `last_safe_position()`; a spike hurts with no knockback and returns the player with a camera snap, invulnerable or not (Q2).
- DevTools: `--hp=<n>` (`hp_value()`, `_apply_hp`, its own spawn handler, after `chain` in `ARGS`), overlay 2's HP line (`hp_text()`), overlay 3's safe-ground cross.
- Tests: new `test_health` and `smoke_health`; `test_chain_state` (+5), `test_tuning`, `test_fx` (hit flash, reduced dim, mid-flash flip, the combined-cap simulation, four warm-up items), `test_room_loader` (spike validator, build, rims, `touches_hazard`, `ground_below` and its fallbacks), `test_dev_args`, `smoke_rooms` (contact and escapes as "no damage", the real mid-air Snuff, the tightest escape), `smoke_a11y`, `smoke_bot` (HP on the summary), `smoke_world`, `smoke_dev_tools`.
- Docs (D14): `component-inventory.md`, `rooms.md`, `development-guide.md`, `architecture.md`, `source-tree-analysis.md`, `game/README.md`, `project-context.md`, `game-architecture.md`, the GDD (Healing, the spikes row, Flash safety), `decision-log.md` (Q1–Q3), `EXPERIENCE.md` (a dated note). Ledger (D13): the squash item closed; five new items with owners (1.29, 1.22, 7.13, E4, 1.30).
- Tests green; sonlm's laptop feel check done (Task 12): the spikes were made unshaded after it found them invisible; the squash's visibility, lurker difficulty and spike return points are ledgered (1.30, 1.30, E4).

### File List

New:
- `game/scripts/rules/health.gd`, `game/scripts/rules/health.gd.uid`
- `game/tests/test_health.gd`, `game/tests/test_health.gd.uid`
- `game/tests/smoke_health.gd`, `game/tests/smoke_health.gd.uid`
- `game/tests/rooms/hazards/t_spikes.txt`
- `game/rooms/dev/spikes.txt`
- `tools/sprites/spike.txt`, `game/art/spike.png`, `game/art/spike.png.import`

Changed:
- `game/scripts/actors/player.gd`, `game/scripts/actors/crawler.gd`, `game/scripts/actors/lurker.gd`
- `game/scripts/rules/chain_state.gd`, `game/scripts/rules/tuning.gd`, `game/scripts/rules/slot_state.gd`
- `game/scripts/core/fx.gd`
- `game/scripts/world/world.gd`, `game/scripts/world/room.gd`, `game/scripts/world/room_loader.gd`, `game/scripts/world/room_legend.gd`
- `game/scripts/dev/dev_tools.gd`, `game/scripts/dev/overlays.gd`, `game/scripts/dev/perf_run.gd`
- `game/tests/spec.gd`, `game/tests/test_room_sweep.gd` (comment), `game/tests/test_chain_state.gd`, `game/tests/test_tuning.gd`, `game/tests/test_fx.gd`, `game/tests/test_room_loader.gd`, `game/tests/test_dev_args.gd`, `game/tests/smoke_rooms.gd`, `game/tests/smoke_a11y.gd`, `game/tests/smoke_world.gd`, `game/tests/smoke_bot.gd`, `game/tests/smoke_dev_tools.gd`, `game/tests/rooms/ok_min.txt`
- `docs/component-inventory.md`, `docs/rooms.md`, `docs/development-guide.md`, `docs/architecture.md`, `docs/source-tree-analysis.md`, `game/README.md`
- `_bmad-output/project-context.md`, `_bmad-output/game-architecture.md`
- `_bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md`, `_bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/decision-log.md`
- `_bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/EXPERIENCE.md`
- `_bmad-output/implementation-artifacts/deferred-work.md`, `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/1-19-health-4-hp-and-the-damage-table.md` (this file)

## Change Log

- 2026-11-22: Story created (ready-for-dev). Ultimate context engine analysis completed; comprehensive developer guide created.
- 2026-11-22: sonlm answered Q1 (the white flash at most once per second), Q2 (spikes while invulnerable: returned, no damage) and Q3 (spikes lit like walls; E4 decides); D5, D10 and D13 stand.
- 2026-11-22: Tasks 1–11 implemented (dev): `Health`, the one `hurt()` path with polled predator contact, bank-heal, the spike and World's safe ground, the hit flash and the squash's clock, `--hp`; tests (29, 1974 `ok`), docs, ledger. Task 12 (the laptop feel check) is the human gate.
- 2026-11-22: self-review fixes (the predator-first check, `Spec.MAX_HP` in the smokes, the wording sweep, doc counts, two E4 ledger items; 1975 `ok`), and the build `20261122-9a265d9-dirty` for the laptop look. HALT for sonlm (Task 12).
- 2026-11-22: Task 12 laptop feel check done: spikes drawn unshaded after "I can't even see it" (rebuilt, re-checked: "yes i can see them now"); answers recorded verbatim; three feel items and one return-point item ledgered (1.30, E4). Status → review (29 tests, 1975 `ok`).
