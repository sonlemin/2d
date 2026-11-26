---
baseline_commit: 749753c
---

# Story 1.23: Flare Toss

Status: review

**Type:** dev, with a laptop feel check (Task 12): Flare Toss is half of the epic's playtest question ("do HP and Flare Toss keep deaths fair?") · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP2 Kit (1.16–1.30) · **Branch:** `feat/m2-e1`

## Story

As a player,
I want to spend half my chain on a flare that lures predators away,
so that I can keep diving bright when the eyes open.

## Acceptance Criteria

1. **The toss is one `ChainState` rule method.** (`scripts/rules/chain_state.gd`; FR14, AR12, D2)
   - `const FLARE_MIN_LINKS := 2` (`##` comment: links a toss needs, GDD Flare Toss "Requirement: at least 2 links").
   - `static func flare_cost(links: int) -> int`: the links a toss spends: half, rounded up (8 → 4, 5 → 3, 3 → 2, 2 → 1); 0 below `FLARE_MIN_LINKS`. Story 1.27's cost hatch reads it.
   - `func toss_flare() -> float`: with `count >= FLARE_MIN_LINKS`:
     - `spent = flare_cost(count)`; `share = held * spent / count` floored (whole embers; the rest stays held);
     - returns the radius the flare burns at: `radius_for(count)` **before** the toss. This is the chain's own light, never `light_radius()`: a cling only shields the light (40 px), it does not shrink the chain (D3);
     - sets `held` and `count` first, then emits `banked(share)` when `share > 0`, then `changed(count)` once (1.22 review: every field before any signal);
     - **never emits `ended`** and never calls `_end()`: a toss is a partial bank, not a chain end, so it can never bank-heal (FR12; Story 1.19 AC "spent by a Flare Toss never triggers bank-heal").
   - Below `FLARE_MIN_LINKS` it returns `0.0`, changes nothing and emits nothing.
   - A toss never ends a chain: the count after it is ≥ 1 (2 → 1, 3 → 1).
   - While snuffed the count is always 0 (`set_snuffed(true)` breaks the chain, a snuffed `add_hit()` adds no link), so a snuffed toss is always refused. No `snuffed` check is written; a test pins it (D4).
   - `clinging` is not read: the rule is the same on and off a wall (D3, Q1).
   - The header comment says what a Flare Toss does to the chain and the held embers.

2. **`tests/test_chain_state.gd` gains the toss's edge cases** (it is the chain's spec; read it first). New cases, each on a fresh `ChainState`:
   - the GDD's examples by literal: 8 → 4 and 5 → 2 left; then 2 → 1, 3 → 1, 20 → 10; 1 and 0 refused (`0.0`, no signal, count and held untouched);
   - the share: at chain 8 with held 36, a toss banks 18 and keeps 18; at chain 5 with held 15 it banks 9 (floor(15 × 3 / 5)) and keeps 6; at chain 3 with held 6 it banks 4 and keeps 2; `banked + held` after always equals `held` before;
   - at the cap with extra held (25 hits: count 20, held 310): a toss banks 155, count 10;
   - signals: one `banked` with the share, exactly one `changed` with the new count, **no `ended`**. Through the public API the share is always ≥ 1 (held ≥ count holds from the first hit and survives a toss), so the `share > 0` guard is covered by setting `held = 0` on the test's own `ChainState` before the toss: no `banked`, one `changed`;
   - the returned radius is `radius_for()` of the count before the toss (8 → 102.2 px), also with `set_clinging(true)` (where `light_radius()` is 40);
   - after a toss `light_radius()` and `bloom_scale()` follow the new count;
   - snuffed: `set_snuffed(true)` then `toss_flare()` → `0.0`, count 0;
   - a chain that goes on: toss, then `add_hit()` pays `ember_value(count + 1)` on top of the held that stayed;
   - `flare_cost()` for 0–20: 0, 0, 1, 2, 2, 3, 3, … (`(n + 1) / 2` from 2), against a literal list.

3. **A tap throws; nothing else does.** (`scripts/actors/player.gd`; FR9, FR14, D5)
   - `_handle_flare()`, called right after `_handle_snuff()` and before `_handle_cling()`: on `input.light_tap`, when the player has a room (`_fx_parent() as Room`; always in play and under RoomHarness) and `chain.toss_flare()` returns a radius > 0, it trims the flares to the cap (AC7) and spawns one flare through `room.spawn(FlareScene, room.to_local(global_position), {radius = <returned>, velocity = Vector2(dir * t.f(&"flare_throw_x"), t.f(&"flare_throw_y"))})`.
   - `dir` is `_facing`; while clinging (`_clinging` is true at the start of the tick) it is `-_cling_side`, away from the wall (D3).
   - The origin is the player's centre, never a point ahead of it: the body's own space is always open air, so a flare thrown while hugging a wall starts outside the wall and sticks on its first tick.
   - With fewer than 2 links the tap does nothing at all: no flare, no popup, chain and held untouched. On the ground the chain is always 0, so no floor check is written.
   - No buffer and no cooldown: `light_tap` is an edge sampled on real ticks (physics ticks run at 60 per real second through a hitstop), so a tap released in a hitstop tosses on that tick (1.8 left this choice to 1.23; D5).
   - **A tap never breaks the chain and never Snuffs** (FR9): after a tap `chain.count >= 1` when it was ≥ 2, `chain.snuffed` is false, `ended` did not fire. **Snuff is unchanged**: a hold past the tap window still breaks and banks, and its release is not a tap (`PlayerInput`, untouched).
   - The light shrinks to the new chain through what exists: `LightSource` eases the shown radius to `chain.light_radius()`; `_on_chain_changed()` re-applies Blade Bloom. No new code for either.
   - The share reaches `Game.dive.carried` through the existing wiring (`chain.banked` → `Game.dive.add_carried`, World's spawn) and shows the M1 "+N banked" popup through `_on_banked()` (1.26 replaces the popups).
   - A cling goes on after a toss: the grace timer is not refilled or reset, the light stays at 40 px until the cling ends (D3, Q1).
   - `player.gd`'s header and the `_handle_snuff()` comment ("A tap is Flare Toss (1.23)") say what is true now.

4. **`actors/flare.gd`: a thrown light that sticks, burns and fades.** (`scripts/actors/flare.gd`, `scenes/actors/flare.tscn`; FR15, AR23, AR28, AR33, AR46, D6–D9)
   - `class_name Flare extends CharacterBody2D`; `collision_layer = 0` (nothing can touch it: not pogo-able, never blocks a body, in no Hurtbox mask), `collision_mask = 1` (world only). Scene tree:
     - `Shape`: `CollisionShape2D`, a 4 × 4 rect;
     - `Sprite`: `art/flare.png`, `material = Fx.unshaded()` set in `_ready()` (shared, already warmed by `Fx.warm_up()`);
     - `LightSource` (`light_source.gd`, `kind = &"flare"`) with child `Light`: `PointLight2D` + `budget_light.gd`, `rank = 0` (ALWAYS), `texture = art/light.png`, `color = Color(1, 0.823529, 0.478431)` (`#ffd27a`, chain-amber: GDD "the flare" is the player's light), `energy = 1.4` (the player's).
   - Public, set by `room.spawn()` args before `add_child`: `var radius := 0.0` (px, the pre-toss radius) and the body's own `velocity`.
   - `const GROUP := &"flare"`; `enum State { FLYING, STUCK }`, public `state`, one `_enter(state)` (project FSM rule).
   - `_ready()`: joins `GROUP`; `light_source.fixed_radius = radius`; sizes the light to `radius` at once (so the first drawn frame is not the scene's default size); `_left = Game.tuning.f(&"flare_burn")` (a countdown may start from the current value, AR15); `reset_physics_interpolation()` (AR6: a spawn is a teleport).
   - **Flight** (`FLYING`, `_physics_process`): `velocity.y = minf(velocity.y + Game.tuning.f(&"gravity") * delta, Game.tuning.f(&"max_fall"))` (the full gravity, never `fall_gravity_scale`; capped at the terminal fall, D7, Q3), `velocity.x` unchanged, then `move_and_collide(velocity * delta)`; any collision → `_enter(State.STUCK)`. It sticks to the **first** surface: a wall, a floor, a ceiling or a ledge's side. It passes through enemies, predators, the player, spikes (not solid) and other flares.
   - **Stuck:** it never moves again (`velocity = Vector2.ZERO`, no `move_and_collide`).
   - **Leaving the room:** while `FLYING`, when its parent is a `Room` and its position is outside `room.bounds().grow(Room.TILE)` (an open top or bottom exit, `m1_shaft`'s floor hole), it burns out at once.
   - **Burn** (both states, game time: `delta`, so it pauses with the tree and stretches with a hitstop like every other gameplay timer): `_left -= delta`; at `_left <= 0` → `burn_out()`. The clock starts at the throw, not at the stick.
   - **Fade:** `const FADE_TIME := 1.0` (`##`: s; presentation; GDD Flare Toss "In its last 1.0 s it fades out smoothly"; `Spec.FLARE_FADE`). The light's `energy` and the sprite's `modulate.a` are their full values × `clampf(_left / FADE_TIME, 0.0, 1.0)`: full until the last second, then a straight line down. It never rises again. **The rule radius does not fade:** `light_source.radius()` stays `radius` until `burn_out()` (D8).
   - `burn_out()`: once only: `light_source.extinguish()` (a lurker hunting it heads home on its next tick, row H1), `visible = false` and out of `GROUP` at once, then `queue_free()`. `queue_free()` alone leaves the node in the tree until the end of the frame, and the budget's pass (priority 50, after the player) would still count its light on the tick the cap swapped it out: hidden, `wants_light()` is false, so the swap never shows 7 ALWAYS lights.
   - `stick()`: public seam: `_enter(State.STUCK)` where it is (the perf run and tests).
   - `burn_left() -> float`.
   - `static func trim(tree: SceneTree, keep: int) -> void`: burns out flares until at most `keep` are left in `GROUP` (not counting any queued for deletion), the one with the least `burn_left()` first, a tie to the earlier in group order (AC7).
   - **No damage, ever:** no `contact_cause()`, not in group `enemy` or `predator`, no `take_hit()`, layer 0. It never writes `enabled` on its light (the budget's) and never queries the player (lint `light_query`).
   - The sprite comes from the pipeline: `tools/sprites/flare.txt` (about 5 × 5, `L` for the ember, palette chars only) → `python3 tools/build_sprites.py` → re-import; commit `art/flare.png` and its `.import`. Placeholder art.

5. **`Tuning` gains the flare's numbers; `Spec` gains the GDD's.** (`scripts/rules/tuning.gd`, `tests/spec.gd`, `tests/test_tuning.gd`; AR15, D10)
   - A new `# --- Flare Toss (GDD Flare Toss (M2), FR14–FR15) ---` section, each const with its `##` unit + intent + source comment and a `BASE` row:
     - `FLARE_BURN := 4.0` / `&"flare_burn"`: s a flare burns from the throw. Long Wick sets 6 (E5).
     - `FLARE_THROW_X := 180.0` / `&"flare_throw_x"`: px/s forward, in the facing direction.
     - `FLARE_THROW_Y := -160.0` / `&"flare_throw_y"`: px/s, the upward part of the throw.
     - `FLARE_MAX := 5.0` / `&"flare_max"`: flares burning at once; with the player's light that is the 6-light budget (AC7).
   - The flare's fall reads the existing `gravity` and `max_fall` (D7).
   - `Spec` (each with its `## GDD` citation, `test_lint` checks it): `FLARE_MIN_LINKS := 2`, `FLARE_BURN := 4.0`, `FLARE_FADE := 1.0`, `FLARE_THROW := Vector2(180.0, -160.0)`.
   - `test_tuning.gd`: `M2_KEYS` gains the four keys; the `BASE` count goes 36 → 40 (its message names the new keys); `Tuning.FLARE_BURN == Spec.FLARE_BURN`, the throw against `Spec.FLARE_THROW`; `Tuning.FLARE_MAX + 1 <= Spec.LIGHTS_ON_SCREEN_MAX` (the player's light and every flare fit the budget); a gear floor: `flare_burn` stays above `Spec.FLARE_FADE` under every combination of `Gear.TABLE` rows (`stat_floor_errors(…, false)`), with a probe gear that sets it to 1.0 caught; its "every key is read" check finds the reads in `flare.gd` and `player.gd`.
   - `ChainState.FLARE_MIN_LINKS == Spec.FLARE_MIN_LINKS` (in `test_chain_state` or `test_tuning`'s `_test_fr_values`).

6. **Lurkers treat a flare as the player, through the rules that exist.** (FR16, FR21; `lurker.gd` is **not edited** for this, D11)
   - A flare is a `LightSource` of kind `flare` with a set radius, so `Sensing` and the lurker's FSM (Story 1.20 rows T1–T5, H1–H5) already do everything the epic asks: a telegraph at the player that meets a larger flare keeps its timer and hunts the flare (T4); a hunt of the player switches to a larger flare in reach on that tick with no telegraph, harmless (H4); a flare that burns out sends it home at once (H1), and it owes the player a full telegraph before it can hurt again (I1 / H3, ≥ `Spec.TELEGRAPH_MIN`).
   - **A flare lures only if a lurker can sense it:** the radius is the pre-toss one, so a toss at chain 2 or 3 burns at 71.1 or 78.1 px, under the 80 px notice floor, and no lurker goes for it (readiness R20; the Weaver, E2, flees any burning flare). A toss at chain 4 (84 px) lures. And the lurker must be within radius × 1.6 of the flare, wherever the player is.
   - The new smoke (AC9) proves it end to end with a real tap and a real flare.

7. **The flare cap is a `Tuning` value, and at the cap the oldest goes out.** (GDD Open Questions "A cap on simultaneous flares"; architecture Lighting; D12, Q2)
   - Before a toss spawns its flare, `Flare.trim(get_tree(), maxi(int(Game.tuning.f(&"flare_max")) - 1, 0))`: with 5 burning, the one with the least time left burns out on that tick and the new one takes its place. A toss is never refused for the cap: the chain was already spent.
   - With `flare_max` 5, the player's light and every flare are at most 6 ALWAYS lights, so `BudgetLight.counts().over` stays 0 in play, on the tick of a swap too (`burn_out()` hides the old flare at once, AC4).
   - Every flare keeps its `PointLight2D` (rank ALWAYS: never demoted, no fallback sprite), and overlay 4's `lights n/6` counts it through group `budget_light` with no overlay change; overlay 2 draws its radius and reach rings through group `light_source`, labelled `flare <n> px`.

8. **The light budget holds a relit light back: closes the view-edge ledger item.** (`scripts/core/budget_light.gd`; NFR8, D13)
   - `const RELIGHT_HOLD_TICKS := 21` (`##`: physics ticks, 0.35 s, a demoted light stays a sprite before the budget may relight it, so one light ↔ sprite cycle takes at least 0.35 s: 2.86 a second, under NFR8's 3 flashes/s, however often an ALWAYS light's rect crosses the view's edge).
   - `apply()` gains `now := Engine.get_physics_frames()` and hands it to `set_demoted(on, now)`, which records it on a demotion (the same `now`, so a test's own tick numbers line up); `apply()` skips a relight (`keep` true, `demoted` true) until `now - demoted_at >= RELIGHT_HOLD_TICKS`. A light never demoted relights at once. A demotion is never delayed (the budget is a cost rule). `static func may_relight(demoted_at: int, now: int) -> bool` is the pure rule; `choose()` is unchanged.
   - `test_light_budget.gd`: the pure rule at 20 and 21 ticks (near-miss, firing); a node case with the budget full and one ALWAYS light crossing the rect's edge every tick for 120 ticks: no GLOW light is relit more than `Spec.FLASH_HZ_MAX` times in any 60 ticks, and the lit count never exceeds `Spec.LIGHTS_ON_SCREEN_MAX`; existing cases that demote and relight inside one physics frame pass `now` (find them: every `_apply(` / `BudgetLight.apply(` call).
   - **The hold reaches every test that runs the real `LightBudget` node**, not only `test_light_budget`: grep `game/tests/` for `demoted`, `set_demoted` and `BudgetLight.counts(` and re-read each hit: a case that expects a glow relit on the tick a slot frees now sees it up to 21 ticks later. Likely hits at story creation: `smoke_perf`'s per-tick budget checks and `smoke_lurker`'s `test_demoted`. List every hit in the Debug Log.
   - Red-check: with the hold removed, the node case fails.

9. **Tests: a new `tests/smoke_flare.gd`** (its own process; RoomHarness unless a case says World; `Game.reset_for_tests()` at the end). Frame maths as `development-guide.md` says: a change made after an await is seen by the next tick; counts take ± 1 tick where a flare's first tick is in doubt (Risks).
   - **The toss** (a ticking player in open air on `tests/rooms/input/t_input.txt` or `t_sensing`, chain built with `add_hit()`, a real `Input.action_press("light")` / release inside the window):
     - chain 8 → 4 and 5 → 2 (GDD literals); held splits as AC2 says; one flare in group `flare`, a child of the room, its `radius` the pre-toss `radius_for()`; the player's `light_source.radius()` is the new chain's on that tick and the shown radius eases down to it (never jumps up);
     - chain 1 and chain 0 (in the air and on the ground): no flare, chain and held untouched;
     - a Snuff hold (past the window) with chain 5: chain 0, no flare, and no flare on its release;
     - a tap never Snuffs: `chain.snuffed` false on every tick around a toss; no `ended`;
     - facing: a tap facing left throws left (`velocity.x < 0` on the flare's first tick).
   - **The flight** (flares spawned with `room.spawn()` and the two args, positions written out for the room):
     - the first ticks follow the throw: x moves `Spec.FLARE_THROW.x / 60` px a tick; the apex is 14 px above the origin, within 2 px (160² / (2 × 900) = 14.2); the fall speed never passes `Game.tuning.f(&"max_fall")`;
     - it sticks to a wall, to a floor and to a ceiling: in each case `state == STUCK`, the position does not change over the next 30 ticks, and the flare's 4 × 4 rect lies in open cells touching the surface (never inside a solid cell);
     - thrown from a spot hugging a wall, toward it: `STUCK` within two ticks, in the open cell;
     - it passes through a crawler and a lurker without sticking, and neither changes;
     - through an open bottom exit (`tests/rooms/embers/t_cache_drop.txt`, the open column): freed within a tick of leaving `bounds().grow(Room.TILE)`, long before its burn ends.
   - **The burn:** freed `Spec.FLARE_BURN × 60` ticks after the spawn (± 1); for the first `(Spec.FLARE_BURN − Spec.FLARE_FADE) × 60` ticks the light's energy is its full value; over the last `Spec.FLARE_FADE × 60` it falls on every tick and never rises (count the rises: 0), ending under 5 % of full; `light_source.radius()` is the pre-toss radius on every tick until the last; `light_source.is_lit()` false after. With `flare_burn` set to 6.0 through the gear seam (`Game.tuning.apply_gear([&"t_wick"], [{id = &"t_wick", stat = &"flare_burn", op = &"set", value = 6.0}])`, then `apply_gear([])`, as `smoke_lurker`'s `_cache_radius()` does): 360 ticks, the fade still the last 60.
   - **No damage:** a ticking player standing in a stuck flare for 60 ticks: HP unchanged, no `damaged`; the flare has no `contact_cause`, is in neither `enemy` nor `predator`, `collision_layer == 0`.
   - **The lure, end to end** (`t_sensing`, its lurker at `LURKER_AT` (8, 200); copy `smoke_lurker`'s `place()` / `_lurkers()` helpers; the player's physics is on only for the ticks of the tap, then off again and re-placed, so the play rect holds still):
     - the lurker forced to `HUNT` at the player (chain 10, `BESIDE`), monitorable (premise); a tap facing **left** (toward the lurker's wall; hold `move_left` over the tap's ticks to face it): chain 5, the flare at 109.6 px; within 2 ticks the lurker is in `HUNT` at the flare, **never a `TELEGRAPH` tick**, never monitorable while the flare is its target (FR16);
     - the flare burns out with the player's light still noticed (chain 5, 89.2 px, `BESIDE`): the lurker's next tick is `RETURN`, then a telegraph at the player of at least `Spec.TELEGRAPH_MIN` (count the ticks from the first `TELEGRAPH` one, exact, as `smoke_lurker`'s `_floor_ticks()` does), harmless throughout, then `HUNT` monitorable (FR21);
     - a telegraph at the player (not forced: let it wake) that meets a tossed flare keeps its timer and ends in a hunt of the flare, harmless;
     - **the 80 px floor:** a toss at chain 3 (flare 78.1 px, the player then at chain 1): the lurker stays or returns to rest and never targets the flare; at chain 4 (84 px) it does. The boundary is asserted against `Spec.NOTICE_MIN_RADIUS`, never the flare's own number.
   - **The cling toss** (Q1; `t_input`'s tall right wall): clinging with chain 6, a tap: chain 3, the flare's radius `radius_for(6)` (93.9 px, not 40), `velocity.x` away from the wall, the player still clinging on the next tick with `light_source.radius() == 40`, and the grace timer neither refilled nor reset (the cling still times out 1.0 s after it began).
   - **The cap:** six flares thrown one after another with `Player`'s own path (or `Flare.trim` + `room.spawn` as the player calls them): 5 in group `flare`, the first one gone, `BudgetLight.counts(…).over == 0` with the player's light on screen, read on the tick of the sixth throw (before the old flare is freed) and on the next. With `flare_max` set to 2 through the gear seam: 2.
   - **In a real World** (`world.tscn` on `m1_shaft`, as `smoke_embers` builds one): a toss at chain 8: `Game.dive.carried` rises by the share and a "+N banked" popup shows; the flare is a child of `World.current_room()`; `BudgetLight.counts()` counts it lit; a death (`player.die()`) with a flare burning: after the respawn's rebuild no flare is left, and no script error fires from a freed flare (a lurker hunting it included).
   - Red-checks, recorded in the Debug Log: `toss_flare()` calling `_end()` → `test_chain_state` and the bank-heal case fail; the flare's kind set to `player` → the lure case fails (monitorable); the rule radius fading with the energy → the burn case fails; the cap removed → the cap case fails.

10. **Existing tests follow the toss.** (D14)
    - **First, find them all:** grep `game/tests/` for `light_tap`, `action_press("light")`, `stand_ins` and `PerfFlare`, and fix each hit. At story creation:
      - `smoke_player_input.gd` `test_light_windows` (about line 290) and `test_light_across_hitstop` (about line 383) assert `count == 5` after a tap at chain 5: both become the GDD's 5 → 2, and each says a flare was thrown and no Snuff happened. `test_light_latch_and_resume` and `test_lock`: check whether a chain ≥ 2 is live at any tap there.
      - `smoke_moves.gd` (about 164), `smoke_health.gd` (about 484) and `smoke_rooms.gd` (about 484) hold Light past the window (Snuff): no change expected; confirm.
      - A case that leaves flares burning in a shared room lets them light the next case for 4 s: free them (`get_tree().call_group(&"flare", &"burn_out")`) where a later case reads lurkers or light counts.
    - `test_light_budget.gd`: `scenes/actors/flare.tscn` is in the scene audit's premise list, the sentinel is `lights >= 4`, and `_test_scene_ranks` gains the flare (`LightSource/Light` a `BudgetLight` of rank ALWAYS).
    - `test_fx.gd`: the new `EFFECTS` rows pass `_test_table` (AC11).
    - `smoke_dev_tools.gd`: one check that overlay 2 marks a burning flare's `LightSource` (label `flare <n> px`) and overlay 4's count includes its light.

11. **`Fx.EFFECTS` declares what a toss shows.** (`scripts/core/fx.gd`; NFR8, AR57, D9)
    - `&"flare_fade"`: `kind = Kind.ONCE, hz = 0.0, fn = "", reduced = ""`, with a `why`: a flare's light and sprite fall in a straight line over its last 1.0 s and never rise (flare.gd); one per flare, and a fade is not a flash, so reduce flashing leaves it (GDD "fades out smoothly, with no flashing").
    - `&"flare_light"`: `kind = Kind.ONCE, hz = 0.0, fn = "", reduced = ""`, with a `why`: a toss adds one steady light at the pre-toss radius where the player's own light already is, while the player's eases down to the new chain: brightness steps once and never blinks; the cap's swap removes one light as it adds one.
    - No new `Fx` function, no new material: the sprite uses `Fx.unshaded()`, already drawn by `Fx.warm_up()`, so nothing new is warmed.

12. **The perf run rides a real flare: closes the ALWAYS-light ledger item.** (`scripts/dev/perf_run.gd`, `tests/smoke_perf.gd`; D15)
    - The `PerfFlare` stand-in and `stand_ins` go. A typed `var flare: Flare` holds a real one: `room.spawn(FlareScene, _inside(player.global_position + FLARE_OFFSET), {radius = player.light_radius()})`, then `flare.stick()` and `reset_physics_interpolation()`; moved each tick at `FLARE_OFFSET` as the cache is.
    - It is made on any tick it is missing (never spawned, burnt out, freed with the room), but not until this life's chain has been seen held once (`_player.chain.count == hold_chain`; a per-spawn flag, cleared on every spawn), at `player.light_radius()` of that tick: in a clean run every flare burns at the held chain's radius. After a break (a blocked path, as in `m1_shaft`) the chain is gone and never re-paid, so the next flare burns at whatever the light is then (40 px); the summary's `breaks` already marks that run. It burns out every `flare_burn` seconds and the next tick makes a new one: the fade is in the measured window, as in play.
    - At chain 20 the flare ties the player's 138.4 px, and a tie goes to the non-player light: lurkers in reach now hunt the flare (harmlessly) or the cache. The header comment says so.
    - `smoke_perf.gd` pins the stand-in in about six places (lines 158–168, 189–223, 281–289): each becomes the real flare (a `Flare` child of the room, kind `flare`, in `light_source`, its `Light` rank ALWAYS and never demoted, radius the held chain's; after a death a new one in the rebuilt room, read only once the new life's chain is held: `test_death_mid_run` reads the stand-in right after the respawn today and must wait those ticks; after a burn-out a new one within a tick).
    - One headless `godot --headless --path game -- --room=perf_worst --perf=20` summary (max lights / sprites / over) is recorded in the Dev Agent Record beside 1.22's (`6/6`, `7`, `0`); the laptop run is Task 12.

13. **Docs, ledger and project-context move with the code.** (D16)
    - **GDD** (`gdd.md`, bump `updated`): Flare Toss names the `Tuning` keys (`flare_burn`, `flare_throw_x` / `_y`, `flare_max`) and gains: the fall is the full gravity capped at the terminal fall (Q3); the clock starts at the throw; the light predators sense keeps its full radius until the flare is out; a toss from a cling (Q1); no toss while snuffed (the chain is 0); at the cap the oldest goes out (Q2). The Open Questions flare-cap row is answered. **Decision log:** a 2026-11-26 Story 1.23 entry with Q1–Q3 and D7, D8, D12.
    - **`game-architecture.md`:** Lighting (the cap line; the relight hold in the `BudgetLight` paragraph); Light Sensing / the component table (`Flare`); State Management (`ChainState.toss_flare()` / `flare_cost()`); the Perf run paragraph and the tree comment for `perf_run.gd`; the `Tuning` example if it differs.
    - **UX** `EXPERIENCE.md` lines 107, 231 and 389 ("dims over its 4 s"): the flare burns 4 s and fades over its last 1 s (the GDD's and the epic's wording).
    - **`docs/`:** `component-inventory.md` (ChainState, Player, Flare, LightSource's comment, BudgetLight's hold, PerfRun, the new and changed tests, the `light_tap` row), `architecture.md` (the Light key row, line 290; BudgetLight; ChainState), `development-guide.md` (the run list gains `smoke_flare`; overlay 2's flares; the `--perf` row), `source-tree-analysis.md` (`flare.gd`, `flare.tscn`, `perf_run.gd`'s comment), `perf.md` (the stand-in is a real flare; the re-run's numbers).
    - **`project-context.md`:** a Story 1.23 sentence in Current State; Performance Rules gain the relight hold and the flare cap; the date line.
    - **Ledger** (`deferred-work.md`): close "A flare's light is a `BudgetLight` of rank ALWAYS" and "The light budget has no hysteresis at the view edge" with `→ **Closed (Story 1.23): …**` lines; "A hunting lurker swings through a light that stands still" is closed at Task 12 with sonlm's verdict (or re-owned with an owner line if the verdict is a change this story does not make). Any new deferred item gets an owner line (`test_deferred_owners`).
    - Stale comments: `light_source.gd` ("flares (1.23) next"; `fixed_radius`'s comment), `lurker.gd`'s header ("flares in 1.23"), `player_input.gd` ("Flare Toss (1.23) … decide what a tap … does"), `budget_light.gd`'s header.

14. **Verify.** `cd game && ./run_tests.sh` → `== ALL GREEN`; `tools/export.sh` → `BUILD OK` (Node 24 from nvm on PATH); the laptop feel check (Task 12) recorded. Report "tests green; needs a feel check on the laptop", never "feels right".

## Tasks / Subtasks

- [x] **Task 1: The chain rule** (AC1, AC2)
  - [x] Read `tests/test_chain_state.gd` whole. Add `FLARE_MIN_LINKS`, `flare_cost()`, `toss_flare()`; the header comment.
  - [x] The new `test_chain_state` cases; run it alone. Red-check: `toss_flare()` through `_end()`.
- [x] **Task 2: Tuning and Spec** (AC5)
  - [x] The four consts and `BASE` rows; `Spec`'s four; `test_tuning` (`M2_KEYS`, the count, the Spec checks, the gear floor).
  - [x] GDD Flare Toss names the keys ("change a value → update the GDD"; the rest of the GDD edits are Task 10).
- [x] **Task 3: The flare** (AC4)
  - [x] `tools/sprites/flare.txt` → `python3 tools/build_sprites.py` → `godot --headless --path game --import`; commit `art/flare.png` + `.import`.
  - [x] `scripts/actors/flare.gd` (+ `.gd.uid`), `scenes/actors/flare.tscn`. Probe the two engine points in Risks before relying on them.
- [x] **Task 4: The toss on the player** (AC3, AC7)
  - [x] `_handle_flare()`, the throw direction, the cap's trim; the comments.
- [x] **Task 5: The budget's relight hold** (AC8)
  - [x] `RELIGHT_HOLD_TICKS`, `may_relight()`, `apply(…, now)`; `test_light_budget` (the rule, the edge-crossing node case, the calls that need `now`, the scene audit and ranks of AC10).
- [x] **Task 6: `Fx.EFFECTS` rows** (AC11); `test_fx` green.
- [x] **Task 7: `tests/smoke_flare.gd`** (AC9), every block; the red-checks.
- [x] **Task 8: Existing tests** (AC10)
  - [x] First: the grep; list every hit in the Debug Log and fix each.
- [x] **Task 9: Perf run** (AC12): `perf_run.gd`, `smoke_perf.gd`, the headless summary.
- [x] **Task 10: Docs, ledger, project-context** (AC13).
- [x] **Task 11: Verify** (AC14): `./run_tests.sh` → `== ALL GREEN`; `tools/export.sh` → `BUILD OK`.
- [x] **Task 12: Laptop feel check (sonlm)** — a debug build; `--chain=8` gives a chain at take-off:
  - [x] Tap Light with a chain: the flare arcs, sticks and burns; the light shrinks; "+N banked" shows. Tap with chain 0 or 1: nothing.
  - [x] A lurker telegraphing or hunting, chain ≥ 4: toss toward its side: it goes for the flare; when the flare ends it telegraphs again before it can hurt.
  - [x] Toss **away** from a lurker in the wide shaft: the flare lands out of its reach (radius × 1.6 of the flare) and it keeps hunting you. Is that fair to read, or should a flare lure from further? (a feel note for 1.30, not a change here)
  - [x] The arc and the fall (Q3): does the flare land where you expect, on screen?
  - [x] The fade over the last second: smooth, no flashing. Four fast taps from chain 20: no strobe.
  - [x] Tap against hold mid-chain: does a tap ever Snuff, or a Snuff ever toss? (GDD's watch item: "whether tap vs hold on Light feels overwhelming mid-chain")
  - [x] Toss from a cling (Q1).
  - [x] **The ledger's decision:** watch a lurker on a stuck flare, and on an Ember Cache: it swings through the light about ± 21 px. Keep it ("worrying at it"), or have it settle on a still light? If "settle": the patch in Dev Notes → "If sonlm says settle" is applied before the review.
  - [x] `--room=perf_worst --perf` (tab in front for the whole run): the summary with the real flare beside 1.22's (`docs/perf.md`); lurker glows near the view's edge with flares about: no flicker.
  - [x] Record the verdict and notes; feel notes go to 1.30 with owner lines.

## Dev Notes

### What this story is (and isn't)

It makes the Light tap do something: spend half the chain on a flare. After it, a tap with 2 or more links throws a light that sticks, burns 4 s and draws lurkers that can sense it, and the chain goes on at half. It also closes the three ledger items that waited for a real flare: the ALWAYS light and the perf stand-in, the budget's view edge, and (at the laptop) the lurker on a still light.

**Not here, each with its owner:** the chain meter's drop and the flare notch (1.26); the flare-cost hatch (1.27; `ChainState.flare_cost()` is ready for it); the whoosh and sizzle (E3, FR76); the Snuff toggle, where any Light press throws (1.35: it calls the same path and inherits "nothing while snuffed"); Long Wick (E5; the `flare_burn` key and its gear floor are ready); the Weaver fleeing flares (E2: it reads the same `light_source` group; `Flare` needs nothing more); teaching the toss in a lurker pocket (E4, S2).

### What exists today (read before editing)

- **`rules/chain_state.gd`:** `count`, `held`, `snuffed`, `clinging`; `add_hit()` (returns at once while snuffed; pays `ember_value(next)` even at the cap); `break_chain()` / `break_by_hit()` → `_end(by_hit)`: `banked(amount)`, then the count reset (`changed`), then `ended(links, by_hit)` for a chain > 0; `lose()` (death: no `banked`, no `ended`); `set_snuffed(true)` breaks the chain; `light_radius()`: 12 snuffed, 40 clinging, else `radius_for(count)` = 40 + 22·√links; `bloom_scale()`. **`tests/test_chain_state.gd` is its spec** (15 cases; the new ones join the list in `run()`).
- **`actors/player_input.gd`:** `light_tap` is an edge, true for the one sample in which Light was released inside the window (`not snuff_active`); a hold that became a Snuff releases with no tap. Sampled once per physics tick by the Player, on real ticks. `consume(&"light_tap")` exists; an edge needs no consume. **Untouched by this story.**
- **`actors/player.gd`:** tick order: `_tick_flash`, `_recover_squash`, (dead → return), `input.sample()`, `_tick_timers`, `_handle_snuff()`, `_handle_cling()` (returns true while clinging, skipping horizontal / vertical / attack), `move_and_slide()`, the floor block (`chain.break_chain()` on every floor tick), `_process_swing()`, `_poll_contacts()`. `_facing` (±1), `_clinging`, `_cling_side`, `_cling_left`. `_fx_parent()` returns World's (or the RoomHarness stub's) `current_room()`, else the parent. `_on_banked()` → `popup_banked()` unless dead. `light_source` is the `LightSource` child; its radius is `chain.light_radius`.
- **`actors/light_source.gd`:** `kind` (no default; `&"flare"` is in `Sensing.KINDS`), `radius_fn` / `fixed_radius`, `radius()`, `extinguish()`, `is_lit()`, static `live()`, `sensed()`; it eases its child `Light`'s `texture_scale` toward `radius()` and snaps on its first tick; `light` is the child `BudgetLight`. Its `_ready()` runs before its parent's, so the parent sets `fixed_radius` in its own `_ready()` (as `EmberCache` sets `radius_fn`).
- **`rules/sensing.gd`:** `can_sense()` (radius ≥ 80, distance ≤ radius × 1.6), `can_notice()` (plus the notice rect), `pick_target()`: the largest radius, an exact tie to the non-player light, two decoys keep the earlier.
- **`actors/lurker.gd`:** reads every lit `LightSource` each tick; rows T3 / T4 (telegraph retarget), H1 (target gone → RETURN), H3 (onto the player → full telegraph, only where noticed), H4 (onto a decoy → no telegraph); `_harmful()` is true only in a hunt of a `player`-kind light it senses. **Do not edit it for AC6.** Lurkers are room children and tick before the Player, so a flare spawned on a tick is first read by them on the next.
- **`objects/ember_cache.gd` + `.tscn`:** the shape to copy for `X/LightSource/Light`: the scene sets `kind`, `rank`, texture, colour; the script wires the radius in `_ready()` and `extinguish()`es before `queue_free()`.
- **`core/budget_light.gd`:** `Rank { ALWAYS, CACHE, GLOW }` (set before `add_child`; an ALWAYS light builds no fallback sprite); `wants_light()` (shown, energy > 0, a texture); `set_demoted()` (only the budget); statics `choose()` (pure), `apply(lights, rect, budget)`, `counts()`, `texture_rect()`. `world/light_budget.gd` calls `apply()` once per physics tick at priority 50.
- **`world/room.gd`:** `spawn(scene, pos, args)` asserts every arg key is a property of the node, sets them and `position`, then `add_child`; `bounds()`; `TILE` 16; `is_solid(cell)`; walls are one `TileMapLayer` with full-square collision on physics layer 1.
- **`world/world.gd`:** wires `chain.banked` → `Game.dive.add_carried` at every spawn; a room swap or a respawn frees the old room with everything spawned in it. **Untouched by this story.**
- **`dev/perf_run.gd`:** `stand_ins` (the `PerfFlare` plain `BudgetLight`), `cache` (a real `EmberCache`), `_place()` moves both each tick, `_build_stand_ins()` on every spawn, `_measuring` starts when `chain.count == hold_chain`.
- **`rules/tuning.gd`:** 36 `BASE` keys; `f(&"key")`; `apply_gear(ids, table)` is the test seam for a bent value. **`tests/spec.gd`:** thresholds with `## GDD` citations.
- **`core/fx.gd`:** `EFFECTS` rows `{kind, hz, fn, reduced[, why]}`; `Kind { ONCE, PULSE, BLINK, MOTION }`; `unshaded()`; `warm_up()`.
- **Sprite pipeline:** `tools/sprites/<name>.txt` grids with chars from `palette_edge.txt` (`.` transparent, `0`–`3`, `L` `#ffd27a`); `python3 tools/build_sprites.py` globs every grid and writes `game/art/<name>.png`. Never hand-make a PNG.
- **Strings:** `POPUP_BANKED` exists. This story adds no key, so no `.translation` changes.

### Decisions

Story-author decisions; sonlm can veto any before dev. Q1–Q3 below were answered by sonlm on 2026-11-26 with the defaults the story uses.

- **D1: Scope.** In: the chain rule, the tap, the flare actor, its `Tuning` keys and cap, the budget's relight hold, the perf run's real flare, tests, docs, and the three ledger items. Out: see "What this story is (and isn't)".
- **D2: The rule lives in `ChainState` and reuses `banked`.** One method spends the links and splits the embers, so the HUD, the popup and `Game.dive` hear about it through the signals they already use. It never emits `ended`: that signal means "a chain is over", and the bank-heal (1.19), 1.26's bank burst and E3's bank chime all hang on it. `banked` with no `ended` is how a later reader tells a toss's share from a chain end.
- **D3 (Q1): a toss works from a cling, and the cling goes on.** One rule for the player to learn: with 2 or more links, a tap throws. The flare burns at the chain's own radius, not the shielded 40 px, or it would lure nothing; it is thrown away from the wall, or it would stick beside you. Hidden on the wall with a decoy out is the strongest thing the kit can do, and it costs half the chain. The alternative (a tap does nothing on a wall) needs the notch and the hatch to hide during a cling, and reads as a dropped input. UX J2 walks the same play: Son clings (step 3), the lurker telegraphs, and he taps for a flare (step 5).
- **D4: no toss while snuffed, by the chain's own rule.** The epic asks whether a Snuff-toggle player can throw while snuffed. A Snuff breaks the chain and a snuffed hit adds no link, so the count is 0 for as long as the Snuff lasts and the "≥ 2 links" rule already refuses. Nothing is written for it; a test pins it; 1.35 inherits it. Throwing with no chain would be a new mechanic (a free flare), which FR14 rules out.
- **D5: no buffer, no cooldown.** The tap edge is sampled on real ticks, so a hitstop can't eat it. A cooldown isn't in the GDD; four taps from chain 20 (20 → 10 → 5 → 2 → 1) are allowed, and every toss after that needs a pogo.
- **D6: the flare is a `CharacterBody2D` on layer 0 with mask 1, moved by `move_and_collide()`.** The engine sweeps the shape, so a fast flare can't tunnel through a 16 px wall, and "the first surface" is the first collision. Layer 0 makes "deals no damage" and "can't be pogoed" structural.
- **D7 (Q3): "normal gravity" is `gravity` (900 px/s², never the player's × 0.6 fall float) capped at `max_fall` (210 px/s).** Without a cap a flare thrown across the 22-tile shaft lands up to about 980 px below the throw (3.6 screens), far from every lurker near you and often through the floor hole. With the cap it lands 0–275 px below (about 110 px from the middle of the shaft), and a flare thrown in a dive falls level with you. Both read existing keys; the laptop check judges the feel.
- **D8: the fade is presentation; the sensed radius stays whole until the flare is out.** The GDD gives one radius for the whole burn and a fade for its last second. Lurkers leave on the tick it goes out and owe the player a full telegraph (≥ 0.75 s), so the fade is the player's warning, a second long, and the rule stays "a flare is a light of this size for `flare_burn` seconds". A radius that shrank with the fade would hand lurkers back up to a second early, at a time no one can see.
- **D9: the fade is a straight line and needs no reduced variant.** It only ever dims, once per flare: not a flash. `Fx.EFFECTS` declares it and the light a toss adds, by hand (they are drawn in `flare.gd`).
- **D10: the throw and the burn are `Tuning` keys; the fade length is a local const.** Gear bends the burn (Long Wick) and may bend a throw; nothing bends the fade, and since D8 it changes no rule. `Spec` holds the GDD's numbers so the tests never compare a value with itself.
- **D11: `lurker.gd` is not touched for the lure.** Story 1.20 built and tested every retarget row with stand-in lights for exactly this. The work here is the real light and a smoke that proves the rows with a real tap.
- **D12 (Q2): the cap is `flare_max` 5, and at the cap the oldest flare goes out.** The CP1 gate found no cap was needed for speed; the GDD still asks this story to make it a `Tuning` value. Halving alone doesn't bound the count: toss, pogo, toss at chain 2 can pass 6 lights inside one burn. Five flares plus the player's light is exactly the budget, so ALWAYS lights can never exceed it, and in normal play the cap is never met. Refusing the tap instead would make Light do nothing with a full meter; the oldest flare is the one with the least left to lose.
- **D13: the budget's fix is a hold in time, not a band in space.** The ledger sketched a 16 px band at the view's edge. A band only moves the edge: a view that bobs further than the band still swaps a glow at the bob's rate. A demoted light that waits 0.35 s before it may be relit can't cycle more than 2.86 times a second whatever crosses the edge, which is the guarantee NFR8 asks for (the stir step's reasoning, `Lurker.STIR_STEP_TIME`). Demotions stay instant: the budget is a cost rule.
- **D14: shared-room tests leave no flare behind.** A burning flare is a light for 4 s: later cases that count lights or read lurkers burn the flares out first.
- **D15: the perf run rides a stuck real flare, remade when it burns out.** It keeps the worst case (a flare on screen for the whole run) and now includes what a real flare costs: the `LightSource`, the fade, an instance every 4 s. `stick()` is the one seam it needs.
- **D16: docs move with the code** (the 1.19 / 1.21 / 1.22 practice).

### What the rules already imply (so the dev doesn't "fix" them)

- **The flare normally out-shines you:** it has the pre-toss radius, you have the halved chain's. Pogo back up to the pre-toss count and you tie it (a tie goes to the flare); one link more and a lurker that notices you owes you a telegraph and comes back.
- **A toss at chain 4–7 leaves you at 2–3 links, under 80 px:** lurkers can't sense you at all until you build back to 4. At chain 8 or more you stay sensed and the flare holds them by being larger.
- **A toss at chain 2 or 3 lures no lurker** (71.1 / 78.1 px). It still costs the links. That is R20, decided by sonlm; the Weaver (E2) reacts to those flares.
- **A flare lures only lurkers within its own radius × 1.6.** Thrown across a wide room, away from a lurker, it can land out of that lurker's reach. Task 12 looks at it; it is a note for 1.30, not a bug.
- **A toss on the tick a lurker touches you doesn't save you:** predators tick before the player and the contact poll reads `monitorable` as they left it (1.19 D3's "in time" rule, unchanged). The flare takes the hunt from the next tick.
- **The remaining chain banks normally:** toss at 20, land at 10 → `ended(10, false)` → the bank-heal applies (10 ≥ `bank_heal_min`). Correct: a chain of 10 was banked.

### Risks and traps

- **`banked` fires on a toss.** Anything that treats `banked` as "the chain is over" is wrong from now on. Today: `Player._on_banked()` (a popup: fine), World's `add_carried` (fine), `perf_run`'s `breaks` (no toss in a perf run: input is locked). 1.26 must hang its bank burst on `ended`.
- **`held * spent / count` is integer division** in GDScript (and floors for positive ints, which is the rule). If the project treats the `INTEGER_DIVISION` warning as noise, add `@warning_ignore("integer_division")`; never switch to floats and `floor()` on values near 2^53.
- **Probe on 4.7.2, don't assume** (a third point, the cap's swap, is settled by `burn_out()` hiding the flare, AC4; the smoke reads `over` on the swap tick to prove it): (a) whether a node added to the tree inside another node's `_physics_process` gets its own `_physics_process` on that same tick (the flare's burn and first move may start one tick later than the toss: the smoke's counts take ± 1); (b) what `move_and_collide()` returns for a 4 × 4 body that starts flush against a wall and moves into it (expected: a collision with almost no travel, so `STUCK` on the first tick), and that the body is never pushed into the wall's cell. Record both in the Debug Log.
- **A freed flare in a typed variable is a script error on 4.7.2** (project-context): the lurker already reads targets through `LightSource.live()`; tests and `perf_run` hold a flare behind `is_instance_valid()`.
- **`BudgetLight.rank` asserts when set after `_ready()`:** it is `rank = 0` in `flare.tscn`, never set in code.
- **The relight hold breaks tests that relight inside one frame.** `test_light_budget`'s node cases call `apply()` several times in one physics frame; they need `now`.
- **`smoke_player_input` counts on "a tap keeps the chain at 5".** That was true only while a tap did nothing (AC10).
- **A flare burning across cases** lights the next case (D14); a cap of 5 also means six leftover flares never exist, which can hide a leak. Assert the group is empty at the start of a case that counts.
- **The lure smoke needs the play rect still.** A ticking player falls and the camera follows; `smoke_lurker` keeps the player's physics off for that reason. Turn it on only for the tap's ticks, then off and `place()` again; throw toward the lurker's wall so the flare sticks inside its reach.
- **Don't offset the throw origin forward.** A point ahead of a player hugging a wall is inside the wall.
- **Don't write `enabled` on the flare's light** (only the budget does) and don't fade by `visible`: fade `energy`. At energy 0 `wants_light()` is false; the flare is freed on that tick anyway.
- **`World.light_rect()` vs `play_rect()`:** the budget counts the whole view; the lure's "on screen" is the play rect. A flare under a gutter still takes a light slot.
- **Lint:** `flare.gd` must not look for the player (`light_query`), build a raw light (`raw_light`), call `free()` or `print(`, or use randomness (the arc is the same every time).

### If sonlm says "settle" at Task 12

Only then, and before the review: in `Lurker._hunt()`, when the target is not a `player`-kind light, the wanted speed scales down inside a short distance (a local const, about 24 px: `speed * minf(1.0, dist / ARRIVE)`), so it comes to rest on a still light. The player-hunt path must stay byte-for-byte: `smoke_lurker`'s M1 trace (`tests/fixtures/lurker_trace_m1.json`) proves it. Add a smoke case (a lurker on a stuck flare for 4 s: its speed inside 4 px of the flare falls under 10 px/s) and an `Fx`-free note in the ledger's closing line. If the verdict is "keep", close the ledger item with the verdict and change nothing.

### From Story 1.22 and the recent commits

- **The 1.22 review's patches are this story's checklist:** set every field on every object before the first signal (AC1); a smoke judges the world by the room's own cells (`room.is_solid()`), never by the function under test (AC9's "in open cells"); a "no X" check counts every X (labels, flares), not the first; a stated behaviour with no assertion is a finding; docs that still say the old thing are a finding (AC13's list).
- **Engine claims are probed, not believed** (the 1.20 and 1.22 reviews each dismissed or confirmed reviewer claims by a 4.7.2 probe in a scratch copy of `game/`). The two in Risks are this story's.
- **Red-checks are recorded** in the Debug Log with the mutant and the count of failing checks (AC9's four, AC8's one).
- **`Area2D` overlaps lag a tick** after a spawn or a move; a flare is a body, not an area, but the player-in-a-flare case still waits two physics frames before it reads anything.
- **Where the suite stands:** `== ALL GREEN (36 tests)`, 2770 `ok`, `BUILD OK` at `0596143` (1.22's review); this story adds one test file (37).
- **Commits on `feat/m2-e1`** follow `feat: story 1.23 …` for the implementation and `fix: story 1.23 code review, …` after the review; the export needs nvm's Node 24 on PATH.

### Project Structure Notes

- New: `game/scripts/actors/flare.gd` (+ `.gd.uid`), `game/scenes/actors/flare.tscn`, `tools/sprites/flare.txt`, `game/art/flare.png` (+ `.import`), `game/tests/smoke_flare.gd` (+ `.gd.uid`). The architecture's layout already names `actors/flare.gd` and `flare.tscn`.
- Changed: `rules/chain_state.gd`, `rules/tuning.gd`, `actors/player.gd`, `core/budget_light.gd`, `core/fx.gd`, `dev/perf_run.gd`; comments in `actors/light_source.gd`, `actors/lurker.gd`, `actors/player_input.gd`; tests `test_chain_state`, `test_tuning`, `spec`, `test_light_budget`, `test_fx` (rows only), `smoke_player_input`, `smoke_perf`, `smoke_dev_tools`.
- Not changed: `world/world.gd`, `actors/player_input.gd`'s logic, `rules/sensing.gd`, `lurker.gd`'s logic (unless Task 12 says settle), the save format, `strings.csv`, `export_presets.cfg` (release presets export all resources; nothing new is excluded).
- Dependencies point one way: `actors/flare.gd` uses `rules/` (through `Game.tuning`), `core/` (Fx, BudgetLight) and `actors/light_source.gd`; `rules/chain_state.gd` mentions no `Node`, `Game` or `Engine`; `core/budget_light.gd` mentions nothing from `world/` (the hold is in ticks, not tiles).
- Commit `.gd.uid` and `.import` files with their sources.

### Project Context Rules

- State in pure objects; write only through rule methods that emit (`chain.toss_flare()`, never `chain.count = …`; lint `state_write`).
- Gameplay reads `PlayerInput` intents, never `Input`; gameplay movement lives in `_physics_process`; `reset_physics_interpolation()` after every teleport (a spawn is one).
- Runtime spawns go through `room.spawn(scene, pos, args)` (args before `add_child`); the room owns and frees them. Never parent a flare to World.
- Predators sense light only through `LightSource` + `Sensing` (lint `light_query`); a predator damages only while `monitorable`, only while the player is its target. A flare adds a `light_source` of kind `flare`, never a damage path.
- Every `PointLight2D` is a `BudgetLight` with a rank (lint `raw_light`, `test_light_budget`'s scene audit); the flare is ALWAYS. Only the budget writes `enabled`.
- FSMs: `enum State` + `match` + one `_enter(state)`; `state` public for tests.
- Tuning is data: a `const` with a `##` unit + intent + source comment, listed in `BASE`; change a value → update the GDD.
- No randomness in level behaviour; no `free()`; no `print(`; code-built FX free themselves; cached shared materials only (`Fx.unshaded()`).
- Every new effect adds an `Fx.EFFECTS` row; flashing honours the gate (lint `a11y_gate`).
- Sprites only through `tools/build_sprites.py`.
- Tests: `test_*` / `smoke_*` names, `ok` / `FAIL` lines, no `ERROR:` line; guarantees compare with `Spec`, never the tuning value under test; pick targets by position, not group index; "tests green; needs a feel check on the laptop".
- Every deferred item gets an owner line, assigned by the agent that defers it.
- No tool or library is added; Godot 4.7.2 only (for an API in doubt, Context7 or a probe, not memory).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.23] (FR14–FR16, FR21, AR33, UX-DR140); FR6, FR9, FR12, FR34, NFR8; neighbours 1.19 (a toss never bank-heals), 1.20 (retarget rows), 1.22 (the cache as the other decoy), 1.26 (meter, notch), 1.27 (cost hatch), 1.30 (CP2 feel), 1.35 (Snuff toggle)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md#Flare Toss (M2), #Predators: Lurker (M1), the chain-end table, Open Questions (flare cap)]; decision-log.md (2026-11-10 Flare Toss; R19, R20)
- [Source: _bmad-output/game-architecture.md#Lighting, #Light Sensing, #State Management, #Debug Tools (Perf run)]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/EXPERIENCE.md] lines 102–107 (flare notch, hatch, burn), 231 (Flare thrown), J2 step 5
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] "A flare's light is a `BudgetLight` of rank ALWAYS"; "The light budget has no hysteresis at the view edge"; "A hunting lurker swings through a light that stands still"
- [Source: _bmad-output/implementation-artifacts/1-20-light-sensing-for-predators.md] D6 (the FSM rows), D7 (`_harmful()`), the decoy kept off screen
- [Source: _bmad-output/implementation-artifacts/1-22-three-ember-stages-the-ember-cache-and-difficulty-tiers.md] the `EmberCache` shape; the review's "set every field before any signal"
- [Source: _bmad-output/implementation-artifacts/1-12-worst-case-performance-scene.md] D4 (the budget rule), the view-edge decision
- [Source: _bmad-output/implementation-artifacts/1-8-playerinput-intents.md] D4 (`light_tap`), "Flare Toss decides its own buffer in 1.23"

## Questions for sonlm (answered 2026-11-26)

- **Q1 (the epic's "Decide before dev"): can a Flare Toss be thrown while clinging, and does the cling continue?** Default (D3): yes, and the cling goes on; the flare burns at the chain's own radius and is thrown away from the wall. Alternatives: no toss on a wall; or a toss that ends the cling.
  **sonlm 2026-11-26: yes, and the cling goes on** (D3 stands).
- **Q2: the flare cap.** Default (D12): `flare_max` 5, and at the cap the oldest flare goes out as the new one is thrown. Alternatives: refuse the tap at the cap; a lower cap (3, leaving slots for the cache and lurker glows); no cap.
  **sonlm 2026-11-26: 5, the oldest goes out** (D12 stands).
- **Q3: the flare's fall ("under normal gravity").** Default (D7): full gravity, capped at the player's terminal fall (210 px/s), so it lands 0–275 px below the throw. Alternatives: no cap (up to about 980 px below in the wide shaft); the player's own floaty fall.
  **sonlm 2026-11-26: gravity, capped at 210 px/s** (D7 stands; the feel is judged at Task 12).
- **Answered by the rules, not asked (D4):** no toss while snuffed in Snuff-toggle mode: the chain is 0 for as long as a Snuff lasts.

## Dev Agent Record

### Agent Model Used

Claude Fable 5.2 (claude-fable-5-2), gds-dev-story, 2026-11-26.

### Debug Log References

- **Task 1 red-check (AC1, AC9):** `toss_flare()` ending through `_end(false)` instead of the partial bank → `test_chain_state` fails 21 of 113 checks (links left, the share, the signals, the cap, the chain going on). Restored: `ALL PASS (113 checks)` (76 before the story).
- **Task 1 note:** a test lambda that captured its own `ChainState` (`d.banked.connect(func … d.count)`) leaked 5 objects at exit and printed `ERROR: 2 resources still in use`; the case reads it through a `WeakRef` instead.
- **Probe (a), 4.7.2 (Risks):** a node added with `room.spawn()` inside another node's `_physics_process` does **not** get its own `_physics_process` on that tick, whichever side of the room the spawning node sits in tree order: spawned in physics frame 11, its first tick is frame 12 (a spawner after the room saw `burn_left` 3.9833 and one step of movement on its own tick 12; a spawner before the room saw 4.0 and no movement on its tick 16 after a spawn in 15). So on the toss tick the flare stands at the player's centre, sized and at full energy (its `_ready()` ran), and its first move and its burn start on the next tick; lurkers (room children, ahead of the player) first read it on the next tick too. The smoke's counts are written for that and take ± 1 only where a float sum decides the last tick.
- **Probe (b), 4.7.2 (Risks):** a 4 × 4 flare thrown into a wall it already touches (`t_input`'s right wall, face at x 336): from x 334.0 (flush) it is `STUCK` on its first tick at x 334.028; from 333.9 at 333.9996; from 333.0 at 333.996; dropped on the floor (top 208) it rests with its bottom at 207.990. One started **inside** the wall (x 340) is pushed out to 334.026 and stuck. So `move_and_collide()` reports the collision with almost no travel, never pushes the body into the wall's cell, and leaves it within the body's safe margin (0.08 px) of the face, up to 0.03 px either side. The smoke asserts "the rect shrunk by 0.1 px lies in open cells, and within 1 px of a solid cell", judged by `room.is_solid()`.
- **Task 5 (AC8), the hold's reach in `game/tests/`** (grep `demoted`, `set_demoted`, `BudgetLight.counts(`, `BudgetLight.apply(`, `_apply(`): `test_light_budget` (every `_apply()` now takes its tick: 100 / 101 / 120 / 121 in `_test_nodes`, 100 in the ALWAYS × 7 and no-slot cases; the recovery case gained the 20-tick near-miss); `smoke_perf` lines 127–219 and 392 (per-tick `lit ≤ 6`, the always-lights never demoted, some tick shows a sprite, every demoted light is a GLOW, nothing demoted at `m1_shaft`'s spawn: none expects a relight on the tick a slot frees, no change); `smoke_lurker` `test_demoted` (calls `set_demoted(true)` by hand in a harness with no `LightBudget`, nothing relights it: no change); `smoke_dev_tools` `test_lights` (three lights, never over budget: no change).
- **Task 5 red-check (AC8):** the relight hold removed from `apply()` → `test_light_budget` fails 2 checks: the edge-crossing node case (a GLOW relit 30 times in 60 ticks, against 3) and the 20-tick near-miss of the recovery case. With the hold: relit at ticks 1022, 1044, 1066, 1088, 1110 (one cycle per 22 ticks; 3 in the worst 60-tick window, the cap itself, so the check is `<=`).
- **Task 7 red-checks (AC9), each on `smoke_flare` (113 checks green, about 28 s):** (1) `toss_flare()` through `_end(false)` → 22 fail, the bank-heal case among them ("a toss at chain 20 … heals nothing": chain 0, HP 4), with the links, the split, `ended([8, false])`, the lure, the cling and the World's carried share; `test_chain_state` fails 21 (Task 1). (2) `flare.tscn`'s kind set to `player` → 7 fail: the lurker telegraphs at the flare instead of hunting it at once, is monitorable on 238 of the 239 ticks it burns, and the kept timer restarts (74 ticks against the 64 bound). (3) the rule radius fading with the energy (`fixed_radius = radius * k`) → 5 fail: the sensed radius is off on the last 60 ticks of both burns, and the lurker leaves the flare 48 ticks early and telegraphs at the player before the flare is out. (4) the cap's `Flare.trim()` line removed → 6 fail: 6 flares after six tosses, 7 lights lit and `over` 1 on the tick of the sixth throw, and 4 flares with `flare_max` 2. Restored after each: `SMOKE PASS`.
- **Task 7 notes:** the burn ends on the flare's 241st tick, not the 240th (4.0 − 240 × 1/60 lands a hair above 0 in floats), inside AC9's ± 1: one more tick at energy 0. A freed object compares equal to `null` on 4.7.2, so the cap case holds "the first flare was set" in a bool. A cling's grace refills only on the floor or on a pogo hit, so the cling case lands between its two runs.
- **Task 8 (AC10), the grep** (`light_tap`, `action_press("light")`, `stand_ins`, `PerfFlare` in `game/tests/`): `smoke_player_input` `test_light_windows` (6 tap rows) and `test_light_across_hitstop` (1) failed on "chain kept" as expected and now assert the toss (chain 5 → 2, one flare, no Snuff; in the hitstop case the toss lands on the tap's own tick), each burning its flare out after (`_burn_flares()`); `_hold_light()`'s Snuff rows gained "no flare". `test_light_latch_and_resume` (every release there follows a Snuff, or the press is held: no tap with a chain) and `test_lock` (its taps are on the floor at chain 0 or while locked): no change. `smoke_moves` 164, `smoke_health` 484 and `smoke_rooms` 485 hold Light past the window (Snuffs): no change, confirmed green; `smoke_moves`' comment "a tap keeps the chain" now says a tap is a Flare Toss. `test_state`, `test_dev_args`, `test_tuning` name only the `light_tap_window` setting. `stand_ins` / `PerfFlare`: `smoke_perf` only (Task 9). `smoke_dev_tools` gained `test_overlay_flare` (overlay 4 `lights 2/6` with a real flare, overlay 2's marks on its `LightSource`) and the label became the pure `Overlays.light_label()` so the test can read `flare 102 px`.
- **Task 9 (AC12), the perf run:** headless `timeout 45 godot --headless --path game -- --room=perf_worst --perf=20` (the run never quits by itself) with the real flare: `perf 20 s: 2901 frames, avg 145.0 fps, min 144 fps, worst 13.1 ms at 10.6 s, 0 over 20 ms; lights max 6/6, sprites max 5, over 0; chain 20, breaks 0, deaths 0; glow off; window 64x64; Linux`. Beside 1.22's (`6/6`, `7`, `0`): the lit count and `over` are the same; sprites max is 5, not 7, since the flare is now a light lurkers sense: at chain 20 it ties the player's 138.4 px and the tie goes to it, so lurkers in reach leave their walls to hunt it and fewer glows stand in the view at once. Headless frame times mean nothing for the GPU; the laptop run is Task 12.
- **Task 9, the remake's place in the tick (found before writing it, then red-checked):** `PerfRun` ticks at priority 100, after the light budget (50). A flare remade there would be a new always-light beside a glow the budget had just relit on that tick: 7 lit for one drawn frame, and `lights max 7/6` in the summary. The remake runs in a child node, `FlareKeeper`, at priority 25: after the actors (a flare burns out in its own tick) and before the budget, as a real toss lands. `smoke_perf` `test_flare_remade` burns the riding flare out by hand once a glow has been a sprite for longer than the relight hold. Red-check: `KEEPER_PRIORITY` 110 → that case fails with `lit 7`; at 25 it shows 6.
- **Task 9, `smoke_perf` hits:** the header; `test_perf_run` (no flare before the chain is held; once held a real `Flare`: child of the room, `STUCK`, kind `flare`, in `light_source`, `Light` rank ALWAYS, radius the held chain's; the per-tick "never demoted" reads its `Light`; the radius / offset check after the run); `test_death_mid_run` (waits 14 ticks so the first life rides a flare, then after the respawn: a new cache at once, no flare riding until the new life's chain is held, then a new instance in the rebuilt room); the new `test_flare_remade`; `test_room_alone` ("no riding lights", no flare in group `flare`).

- **Probe, the perf summary's sprites max 5 against 1.22's 7** (two things changed at once, the flare being sensed and the relight hold, so the cause was probed, three headless `--perf=20` runs): the riding flare at 60 px, which no lurker senses, with the hold on → `sprites max 7`; the real flare with `RELIGHT_HOLD_TICKS` 0 → `sprites max 5`; restored → `sprites max 5`. So it is the flare luring lurkers out of their walls, not the hold.
- **Task 12, first laptop notes (sonlm, 2026-11-26, build `20261126-749753c-dirty`):** part 1 (the toss, the arc, the fade, taps with no chain) "seems good so far". A Chrome perf run, pasted: `perf 60 s: 2516 frames, avg 41.9 fps, min 23 fps, worst 222.1 ms at 1.0 s, 1408 over 20 ms; lights max 6/6, sprites max 5, over 0; chain 20, breaks 0, deaths 0; glow off; window 4358x6762; Web, WebKit WebGL`. Valid (no hidden-tab frame) but with no Chrome baseline to compare with; the row is in `docs/perf.md`. The Firefox run, the lure, the cling toss and the keep / settle verdict are still open.
- **Task 12, the rest (sonlm, 2026-11-26, same build):** part 2 (a toss toward a lurker, the burn-out and its telegraph, a toss away from one, the toss from a cling) "seems fine", with no feel note for 1.30. **The ledger's decision: keep** (the lurker's swing on a still light stays; no patch). Firefox on the Intel iGPU, pasted: `perf 60 s: 3558 frames, avg 59.3 fps, min 17 fps, worst 726.0 ms at 0.0 s, 3 over 20 ms; lights max 6/6, sprites max 5, over 0; chain 20, breaks 0, deaths 0; glow off; window 3330x1087; Web, ANGLE (Intel, Intel(R) HD Graphics Direct3D11 vs_5_0 ps_5_0), or similar`. Beside 1.22's (59.2 / 13 / 791.0 at 0.0 s / 80): the average holds and the frames over 20 ms went from 80 to 3. The edge-glow look, in the web debug build's perf run (sonlm): "looks fine", no flicker between light and sprite.
- **Full run (Task 11):** `./run_tests.sh` → `== ALL GREEN (37 tests)`, 2928 `ok` lines (1.22's review: 36 tests, 2770), plus `test_chain_state`'s `ALL PASS (113 checks)`, which prints no `ok` lines. `tools/export.sh` (Node 24.22.3 from nvm) → `== BUILD OK builds/20261126-749753c-dirty, web download 11.0 MB (gzip; raw 40.8 MB), licences in 4 folders, PCK files windows 108 / linux 108 / web 108 / web_debug 116, 99 s`. The build is `-dirty` because nothing is committed yet (below).

### Completion Notes List

- **The chain rule (AC1, AC2):** `ChainState.FLARE_MIN_LINKS` 2, `flare_cost()` (half, rounded up; 0 under 2) and `toss_flare()`: it sets `held` and `count`, then emits `banked(share)` (when the share is > 0) and `changed(count)`, never `ended`, and returns `radius_for()` of the count before. No `snuffed` or `clinging` check is written; tests pin both. `test_chain_state` gained 9 cases (113 checks, from 76).
- **Tuning and Spec (AC5):** `flare_burn` 4.0, `flare_throw_x` 180, `flare_throw_y` −160, `flare_max` 5 (BASE 36 → 40); `Spec.FLARE_MIN_LINKS` / `FLARE_BURN` / `FLARE_FADE` / `FLARE_THROW`; `test_tuning` holds them to Spec, `flare_max + 1` to the light budget, and `flare_burn` above the fade under every gear.
- **The flare (AC4):** `actors/flare.gd` + `flare.tscn` as the AC lists them; placeholder art `tools/sprites/flare.txt` (5 × 5, all `L`) through the pipeline. The body rests within the engine's safe margin of the surface (probe (b)), so the smoke's "in open cells" allows 0.1 px.
- **The toss (AC3, AC7):** `Player._handle_flare()` after `_handle_snuff()`. One thing the AC's wording left open: the room is checked **before** `toss_flare()`, so a player with no `Room` never spends links for a flare that can't be spawned.
- **The relight hold (AC8):** `RELIGHT_HOLD_TICKS` 21, `may_relight()`, `apply(…, now)`, `set_demoted(on, now)` recording `demoted_at`. A held light keeps the slot `choose()` gave it, as a sprite, so the lit count only runs under the budget meanwhile; `choose()` is unchanged.
- **`Fx.EFFECTS` (AC11):** `flare_fade` and `flare_light`, both `ONCE` with a `why`; no new `Fx` function or material.
- **`smoke_flare` (AC9):** 15 cases, 113 checks, about 28 s. Beyond the AC's blocks it has a bank-heal case (a toss at chain 20 with 3 HP heals nothing; landing the 10 links left heals 1), which the AC's red-check list names but its blocks did not. The cap case reads the budget **inside** the tick of the sixth toss through a sampler node at priority 60, with the swapped-out flare still queued in the tree.
- **Existing tests (AC10):** as the Debug Log lists. One small change outside the AC's list: overlay 2's label text moved into a pure `Overlays.light_label()` (same text) so `smoke_dev_tools` can read `flare 102 px`; the AC expected no overlay change.
- **The perf run (AC12):** `stand_ins` / `PerfFlare` are gone; `perf.flare` is a real stuck `Flare`. **A deviation from the AC's wording, on purpose:** the AC says "the next tick makes a new one" after a burn-out; the remake runs on the **same** tick, in a child node at priority 25 (after the actors, before the light budget). Made from `PerfRun`'s own tick (priority 100, after the budget) the new always-light stood beside a glow the budget had just relit: 7 lit for a drawn frame and `lights max 7/6` in the summary (red-checked). Headless summary: lights max 6/6, sprites max 5, over 0.
- **Docs (AC13):** GDD Flare Toss (the keys, the capped fall, the clock from the throw, the whole sensed radius, the cling toss, no toss while snuffed, the cap) and its Open Questions row; `decision-log.md` (a 2026-11-26 Story 1.23 entry: Q1–Q3, D8); `game-architecture.md` (Lighting's cap and relight hold, Light Sensing's `Flare`, State Management's `toss_flare()`, the Perf run, the tree, the `Tuning` example); EXPERIENCE.md's three "dims over its 4 s" lines; `docs/` (component inventory, architecture, development guide, source tree, perf.md with a 1.23 results section; the asset table also gained 1.22's `ember_cache.png`, which was missing); project-context (Current State, Performance Rules, the date line); the stale comments in `light_source.gd`, `lurker.gd`, `player_input.gd`, `budget_light.gd`.
- **Ledger:** closed "A flare's light is a `BudgetLight` of rank ALWAYS" and "The light budget has no hysteresis at the view edge". "A hunting lurker swings through a light that stands still" stays open, **owner Story 1.23, Task 12** (sonlm's verdict at the laptop; `lurker.gd` is unchanged, the "settle" patch is not applied). No new deferred item.
- **Not committed:** commits wait for sonlm's word, as in 1.22; the export above is therefore a `-dirty` build of `749753c`.
- **Status:** Tasks 1–11 done; **Task 12 (the laptop feel check) is sonlm's**, so the story stayed `in-progress` until it was done. **Task 12 done (sonlm, 2026-11-26, build `20261126-749753c-dirty`):** the toss, the lure and the cling toss pass with no feel note for 1.30; the lurker on a still light: keep (no patch); Firefox on the Intel iGPU 59.3 fps with 3 frames over 20 ms, lights 6/6, sprites 5, over 0; no edge-glow flicker. Status `review`.

### File List

- `game/scripts/rules/chain_state.gd` (modified: `FLARE_MIN_LINKS`, `flare_cost()`, `toss_flare()`)
- `game/scripts/rules/tuning.gd` (modified: the four flare keys)
- `game/scripts/actors/flare.gd` (new), `game/scripts/actors/flare.gd.uid` (new)
- `game/scenes/actors/flare.tscn` (new)
- `game/scripts/actors/player.gd` (modified: `_handle_flare()`, `FlareScene`)
- `game/scripts/core/budget_light.gd` (modified: the relight hold)
- `game/scripts/core/fx.gd` (modified: two `EFFECTS` rows)
- `game/scripts/dev/perf_run.gd` (modified: the real flare, `FlareKeeper`)
- `game/scripts/dev/overlays.gd` (modified: `light_label()`, the label's text unchanged)
- `game/scripts/actors/light_source.gd`, `game/scripts/actors/lurker.gd`, `game/scripts/actors/player_input.gd` (comments only)
- `tools/sprites/flare.txt` (new)
- `game/art/flare.png` (new, built), `game/art/flare.png.import` (new)
- `game/tests/smoke_flare.gd` (new), `game/tests/smoke_flare.gd.uid` (new)
- `game/tests/spec.gd` (modified: four consts)
- `game/tests/test_chain_state.gd`, `test_tuning.gd`, `test_light_budget.gd` (modified)
- `game/tests/smoke_player_input.gd`, `smoke_perf.gd`, `smoke_dev_tools.gd` (modified), `smoke_moves.gd` (a comment)
- `_bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md` (modified)
- `_bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/decision-log.md` (modified)
- `_bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/EXPERIENCE.md` (modified)
- `_bmad-output/game-architecture.md` (modified)
- `_bmad-output/project-context.md` (modified)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/1-23-flare-toss.md` (this file)
- `docs/component-inventory.md`, `docs/architecture.md`, `docs/development-guide.md`, `docs/source-tree-analysis.md`, `docs/perf.md` (modified)

### Change Log

- 2026-11-26: Story 1.23 implemented (Tasks 1–11): `ChainState.toss_flare()`, the `Flare` actor and its sprite, the toss on a Light tap with the cap, the four flare `Tuning` keys and `Spec` numbers, the light budget's relight hold, the two `Fx.EFFECTS` rows, the perf run's real flare, `smoke_flare` and the tests that followed the toss, docs and ledger (two items closed). ALL GREEN (37 tests, 2928 ok), BUILD OK (`20261126-749753c-dirty`). Task 12 (the laptop feel check) pending sonlm; not committed.
- 2026-11-26: Task 12, the laptop feel check (sonlm, build `20261126-749753c-dirty`): the toss, the lure and the cling toss pass with no feel note; the lurker on a still light: **keep** (ledger item closed, `lurker.gd` unchanged); the Firefox perf run recorded (59.3 fps, 3 over 20 ms, 6/6 / 5 / 0). The edge-glow flicker look: fine. All tasks done; Status → review.
