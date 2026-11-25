---
baseline_commit: c73eeda
---

# Story 1.22: Three ember stages, the Ember Cache and difficulty tiers

Status: ready-for-dev

**Type:** dev, with a laptop look (Task 11): the cache is the first new thing on screen since 1.19's spikes · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP2 Kit (1.16–1.30) · **Branch:** `feat/m2-e1`

## Story

As a player,
I want embers to move from held to carried to deposited, and a dropped cache I can win back,
so that "one more hit" and "can I reach the station?" are both real choices.

## Acceptance Criteria

1. **The three stages are rule methods that emit.** (`scripts/rules/dive_state.gd`, `scripts/rules/slot_state.gd`; FR22, AR13, D2)
   - Held → carried already works and is unchanged: `ChainState.banked` → `Game.dive.add_carried` (World's spawn wiring) on a landing, a Snuff, a cling timeout, a hit (`break_by_hit()`) and a room exit (World's backstop).
   - `DiveState.take_carried() -> int`: carried goes to 0 and the old amount is returned; emits `carried_changed(0)` only when it was > 0. `add_carried()`'s assert message no longer says "losses arrive in Story 1.22".
   - `SlotState` gains `var deposited := 0` (embers safe forever, GDD Economy), `signal deposited_changed(deposited: int)` and `deposit_from(dive: DiveState) -> int`: `dive.take_carried()` into `deposited`; emits once when the amount is > 0; returns the amount. Its first caller is 1.24's rest (heal → `deposit_from` → `dive.reset()` → rebuild → save); hub arrival is E5's. It never touches the cache.

2. **Death cost by tier, one rule, one report.** (`SlotState.apply_death()`; FR23, FR25, AR13, D3, D4)
   - The tier table is data on `SlotState`:

     ```gdscript
     ## GDD Economy "Difficulty tiers": what a death costs. Nothing else reads the tier (FR25).
     const DEATH_COST := {
     	&"easy": {held = &"carry", carried = &"keep"},
     	&"normal": {held = &"lose", carried = &"cache"},
     	&"hard": {held = &"lose", carried = &"lose"},
     }
     ```

   - `apply_death(dive: DiveState, held: int, room_id: StringName, pos: Vector2) -> Dictionary` applies it to `dive` and the slot and returns a plain report for the popup now and the death card later (1.29):
     `{tier, held_lost, held_carried, carried_cached, carried_lost, cache_destroyed}` (ints, plus the tier `StringName`).
     - **Any earlier cache is destroyed first, on every tier** (D4; Q1): `cache_destroyed` is its amount, 0 when there was none. At most one cache ever exists.
     - Easy: `dive.add_carried(held)` (`held_carried`); carried kept; no cache.
     - Normal: held lost (`held_lost`); when `dive.carried > 0`, `dive.take_carried()` becomes the new cache at `room_id` / `pos` (`carried_cached`); with 0 carried no cache is made.
     - Hard: held lost; `dive.take_carried()` lost (`carried_lost`); no cache.
     - asserts `held >= 0`, and `room_id != &""` when it drops a cache (programmer errors).
     - Emits `cache_changed` once when the cache changed (one destroyed, one dropped, or both); never otherwise.
   - It never calls `ChainState.break_chain()` and never emits `ChainState.ended`: a death is never a bank, so it can never bank-heal (FR12; `test_chain_state` `test_lose_emits_no_ended`).

3. **The cache lives in `SlotState`.** (AR13, AR14, D2, D5)
   - Fields, value types only (so no reader can mutate them past a rule method): `cache_room: StringName = &""` (empty = no cache), `cache_pos := Vector2.ZERO` (room-local, D6's spot), `cache_amount := 0`; `has_cache() -> bool` (`cache_room != &""`).
   - `signal cache_changed(room_id: StringName, amount: int)`: `(&"", 0)` when there is none.
   - `recover_cache(dive: DiveState) -> int`: with a cache, clears it, emits `cache_changed(&"", 0)`, `dive.add_carried(amount)` and returns the amount; with none, returns 0 and emits nothing.
   - The cache survives a rest and a save: `deposit_from()` and `dive.reset()` leave it alone; only `apply_death()`, `recover_cache()`, `reset()` and `from_dict()` change it.

4. **The save carries both, with no version bump.** (`SlotState.to_dict()` / `from_dict()`, `core/game.gd`; AR37, R14, D5)
   - `to_dict()` gains `"deposited": int` and `"cache"`: `null` when there is none, else `{"room": String, "x": float, "y": float, "amount": int}`. The key is always present: `Game._resume_part()` indexes it.
   - `from_dict()` (never asserts, 1.4 D3): `deposited` through `_count()`; `cache` `null` → none, clean; a Dictionary with a non-empty `room` String, finite `x` / `y` numbers (int or float) and an `amount` that `_count()` reads as ≥ 1 → that cache; anything else (wrong type, a missing field, amount 0, a missing key) → no cache and unclean. `_assign()` takes the new fields and emits `deposited_changed` and `cache_changed` once each, changed or not (1.4 D2).
   - `SlotState.RESUME_KEYS` becomes `["resume_room", "resume_entry", "cache"]`: a progress save writes the last resume save's cache, so it never clears a cache that save still holds, and never keeps one dropped since (1.21 D6). `deposited` is progress (it moves only at a rest, itself a resume save).
   - `meta()` is unchanged (the picker shows depth, best chain, play time and difficulty).
   - `Migrations.VERSION` stays 1: keys freeze at 1.41, and until then a story may add a key (1.21 D1). Every planted slot JSON in the tests gains `"deposited": 0, "cache": null` so it still loads clean (AC10).

5. **The death flow: Player hands over the held embers, World applies the cost.** (`scripts/actors/player.gd`, `scripts/world/world.gd`; AR25, D3)
   - `Player.die()` keeps `chain.lose()` and stores its result in a new public `var held_at_death := 0`; it no longer shows the "lost" popup itself.
   - The two M1 popups become Player methods, colours unchanged (they stay in `player.gd`, where 1.26/1.27 remove them): `popup_banked(amount: int)` (`_on_banked()` calls it) and `popup_lost(amount: int)`. Both parent through `_fx_parent()`.
   - `World._on_player_died()`, before `record_death()`:
     `var cost := Game.slot.apply_death(Game.dive, _player.held_at_death, _room.id, _room.floor_spot(_safe_pos))`; keeps it in `_last_death` with a getter `last_death_cost() -> Dictionary` for the death card (1.29); then `_player.popup_lost(cost.held_lost + cost.carried_lost)` when that is > 0. Easy shows nothing; Normal shows the held loss only (the carried went to the cache, not lost).
   - Without World (RoomHarness) a death applies no cost and shows no popup: the rule lives in World's handler.

6. **The cache sits on clean floor, always.** (`Room.floor_spot()`; D6; closes the 1.19 ledger item "The Ember Cache when `ground_below()` falls back to a mid-air entry")
   - `Room.floor_spot(pos: Vector2) -> Vector2` (room-local, the player-centre convention of `entry_position()`: the floor's top is at `pos.y + 12`):
     - when `pos` stands on clean floor (the cell holding the feet is in bounds, not solid, not a hazard; the cell below is solid; and `absf(pos.y + 12 - floor_top) <= 1.0`), it returns `pos` unchanged;
     - otherwise it returns the spot of the nearest clean standing cell (`Vector2(c.x * TILE + TILE / 2.0, (c.y + 1) * TILE - 12)`), by distance to `pos`, ties to the lower row then the lower column (scan rows, then columns, keep only a strictly smaller distance);
     - a room with no clean standing cell returns `pos` (a valid room always has one).
   - It covers every way the tracker can leave a bad spot: the `ground_below()` fallback to a mid-air `up` entry, a centre hanging past a ledge's edge on a floor tick, a hand-edited save, a room edited since the save.
   - World uses it at the drop (AC5) and again at the spawn (AC7).
   - `test_room_loader.gd` covers it on a small text room: a spot on clean floor is kept exactly (near-miss); mid-air, over a `^`, past a ledge's edge and outside the room each move to the nearest clean spot (firing); a tie picks the lower row, then the lower column.

7. **`objects/ember_cache.gd`: an amber light that lures and gives back.** (`scripts/objects/ember_cache.gd`, `scenes/objects/ember_cache.tscn`; FR24, AR24, AR28, AR46, D7, D8)
   - `class_name EmberCache extends Area2D`; `collision_layer = 0`, `collision_mask = 2` (the player), `monitorable = false`. Scene tree:
     - `Shape`: `CollisionShape2D`, a small rect on the floor (about 12 × 10, bottom at y + 12);
     - `Sprite`: `art/ember_cache.png`, sitting on the floor (bottom at y + 12), `material = Fx.unshaded()` set in `_ready()` (shared, warmed by `Fx.warm_up()`; "small glows … cache core … are unshaded sprites");
     - `LightSource` (`light_source.gd`, `kind = &"cache"`) at the sprite's centre, with child `Light`: `PointLight2D` + `budget_light.gd`, `rank = 1` (CACHE), `texture = art/light.png`, `color = Color(1, 0.823529, 0.478431)` (`#ffd27a`, `chain-amber`), a steady energy (no flicker, no pulse: no `Fx.EFFECTS` row).
   - `_ready()`: `$LightSource.radius_fn = _radius` (children are ready before the parent, as on the player); `Game.slot.cache_changed.connect(_on_cache_changed)` (a method: dropped with the node).
   - `_radius() -> float`: `Game.tuning.f(&"cache_radius")`, read on every call (AR15). New `Tuning` key: `const CACHE_RADIUS := 80.0` in a new `# --- Economy (GDD Economy, FR24) ---` section, `##` comment: px; the cache's glow and the light predators sense, so at ≥ 80 px it wakes lurkers like the player's light (GDD Economy "Ember Cache glow"); [ASSUMPTION: tuned at the CP2 gate, 1.30]; GDD Economy, new in M2. Listed in `BASE` as `&"cache_radius"`.
   - `_physics_process()`: polled, never `body_entered` (AR30): the first overlapping body in group `player` that is not `is_dead` takes it: `var n := Game.slot.recover_cache(Game.dive)`, then `player.popup_banked(n)` when `n > 0` (duck typing, `has_method`). At most once per node.
   - `_on_cache_changed(_room_id, _amount)`: any change means this node no longer stands for the slot's cache: `$LightSource.extinguish()` (a lurker hunting it returns home at once, H1) and `queue_free()`. The next room build spawns whatever the slot holds. So a second death, a recovery, a load and `reset_for_tests()` each leave no stale glow.
   - Wakes lurkers only by the shared rule (AR29, `Sensing`): tested at 79 and 80 px of radius (AC9 test seam); a lurker that telegraphs at and hunts the cache stays `monitorable == false` throughout, and a player inside it takes no damage (`Lurker._harmful()`, 1.20 D7).
   - The sprite comes from the pipeline: `tools/sprites/ember_cache.txt` (palette chars only, `L` for the embers) → `python3 tools/build_sprites.py` → re-import; commit the `.png` and its `.import`. Placeholder art; 4.6 makes Layer 1's object sprites.

8. **World spawns the cache when it builds its room.** (`World._swap_room()`; AR24, D7)
   - Right after `_room_holder.add_child(room)` and before the palette and `Fx.warm_up()`: when `Game.slot.has_cache()` and `Game.slot.cache_room == room_id`, `room.spawn(EmberCacheScene, room.floor_spot(Game.slot.cache_pos))` (AR23: the room owns and frees it). `RoomLoader` stays slot-free: rooms still load standalone.
   - On every build: the first, an exit, a respawn's rebuild. A cache on the respawn spot is taken on the first tick that the new player overlaps it (accepted, D7).
   - `last_safe_position()`'s comment says the cache drops at `floor_spot()` of it.

9. **Tests.**
   - **New `tests/test_embers.gd`** (pure: fresh `SlotState` / `DiveState`, no scene), every stage transition and tier:
     - `take_carried()` and `deposit_from()`: amounts, the signals (one emit each, none at 0), the cache untouched;
     - `apply_death()` with UX J3's numbers (held 30, carried 40), per tier, with and without an earlier cache of 25: the report, `dive.carried`, the cache fields, `cache_changed` count; Normal with 0 carried makes no cache and still destroys an earlier one; an unknown tier is impossible (`set_difficulty()` asserts);
     - `recover_cache()`: returns 40 and carried +40, then 0 with no emit;
     - a rest's order (`deposit_from()` then `dive.reset()`) leaves the cache;
     - `to_dict()` / `from_dict()` round trip with and without a cache (types back: `StringName` room, `Vector2`, `int`); each bad cache shape → none and unclean; `null` → none and clean; a missing `cache` or `deposited` key → default and unclean;
     - FR25 by source: `difficulty` appears in no file under `scripts/actors/`, `scripts/world/` or `scripts/objects/`, and under `scripts/rules/` only in `slot_state.gd`; `Tuning.BASE` has no key containing `difficulty`.
   - **New `tests/smoke_embers.gd`** (its own process; a real `world.tscn`, `Game.store.dir` at a temp folder with `Game.load_slot(1)` only where a save is checked, `reset_for_tests()` at the end):
     - **The epic's smoke:** in `m1_shaft` on Normal, bank a chain (carried > 0), die away from `P`; after `RESPAWN_DELAY` the respawn rebuilt the room through the swap path, an `EmberCache` stands in it at the drop spot with the right amount, carried is 0, held was lost; walk or place the player onto it: carried is back, the slot has no cache, the node is gone.
     - **Where it drops** (on `tests/rooms/hazards/t_spikes.txt`): a ground death (standing on the `P` ledge) → exactly the last safe position; a mid-air death (off the ledge, before landing) → on the ledge it left, on clean floor; a hazard death (1 HP, into the spikes) → on clean floor before the spikes, never over a `^`.
     - **The fallback:** a new `tests/rooms/embers/t_cache_drop.txt` whose `up` column is open to its bottom exit, so `ground_below(&"up")` falls back to the mid-air entry (firing): a death on the first tick after an `up` arrival drops the cache on the nearest clean floor, not at the entry. The near-miss: an `up` arrival in `t_spikes` (its column lands on clean floor) drops it at `ground_below(&"up")` exactly.
     - Easy and Hard deaths in the same room: no cache; carried as the tier says; the popup's text (`-N lost` on Hard with held + carried, none on Easy).
     - A second Normal death before recovery: the first cache node goes dark and is freed at once (before the respawn), and the rebuilt room holds only the new one.
     - Survives saves: with a cache, `Game.save_now()`, `reset_for_tests()`, the store back at the temp folder, `Game.load_slot(1)`: the cache is back; a World built then spawns it. A progress save (`Game.set_difficulty()`) after a recovery writes the last resume save's cache (R14).
     - The light: the cache's `LightSource` is in group `light_source` with kind `cache`, its `Light` a `BudgetLight` of rank CACHE.
   - **`smoke_lurker.gd`** gains a cache case (RoomHarness on `t_sensing`; its player's physics is off and the play rect follows the player, so the player stands at `BESIDE` with chain 0, whose 40 px light is never sensed, which keeps the lurker on screen; an `EmberCache` spawned with `room.spawn()` at `DECOY_AT`): with `cache_radius` set to `Spec.NOTICE_MIN_RADIUS - 1` the lurker stays IDLE for a full telegraph time; at `Spec.NOTICE_MIN_RADIUS` it telegraphs (target kind `cache`) and hunts it; `monitorable` stays false through both. The seam: `Game.tuning.apply_gear([&"t_cache"], [{id = &"t_cache", stat = &"cache_radius", op = &"set", value = …}])`, then `apply_gear([])`.
   - **No damage from a cache hunt, with a ticking player** (the harness player's `_poll_contacts()` never runs, so the check above can't show it): in `smoke_embers` (or `smoke_health`'s `test_lurker_harmless` pattern), a lurker hunting a cache with the player overlapping it: no `damaged`, HP unchanged.
   - **`test_light_budget.gd`**: `objects/ember_cache.tscn` is in its scene audit (it already walks `scenes/`; check the new folder is reached) and its light is rank CACHE.

10. **Existing tests follow the new death.** (D9)
    - **First, find them all:** grep `game/tests/` for `.die(`, lethal `hurt(`, `--hp=1`, `stand_ins`, `PerfCache` and `CACHE_RADIUS`, and fix each hit. At story creation `.die(` / the stand-ins appear in `smoke_world`, `smoke_dev_tools`, `smoke_palettes`, `smoke_room_swap`, `smoke_perf`, `smoke_lurker` and `test_clock`; `smoke_health` kills through hits. A death in a real World on Normal with carried > 0 now drops a cache.
    - `smoke_world.gd` `test_death_and_respawn`: carried is > 0 there on Normal (`test_chain_and_bank` and `test_popups_in_room` bank before it; read the value), so carried now goes to a cache of that amount; assert that and recover it at the end. **Every `smoke_world` case that kills the player ends with no cache in the slot** (touch it, or `Game.slot.recover_cache(Game.dive)`), or later cases (`test_hunt_over_death`, `test_bottom_loop`, `test_sources`) meet an 80 px light in `m1_shaft`.
    - `smoke_health.gd` `test_death_and_respawn` (carried may be > 0 from `test_crawler_contact`): the same; and every other death there.
    - Planted slot JSON gains `"deposited": 0, "cache": null`: `test_saves.gd` (`GOOD`, the strings at about lines 569, 576, 682 and 715, the exact `want_slot`), `smoke_dev_boot.gd` (`PLANTED`), `smoke_dev_tools.gd` (`planted`). `test_state.gd`'s exact key list gains `cache` and `deposited`, and its filled / same-slot helpers the new fields.
    - `test_tuning.gd`: `M2_KEYS` gains `&"cache_radius"`, and the `BASE` count goes from 35 to 36 (its message names the new key); its "every key is read" check finds the read in `ember_cache.gd`.
    - Any test that read the lost popup from `Player.die()` without World reads it from World now (none found at story creation).

11. **DevTools `--difficulty=easy|normal|hard`.** (`scripts/dev/dev_tools.gd`; D10)
    - One `ARGS` row after `hp`: `"difficulty": {help = "--difficulty=easy|normal|hard: the tier for this session; no slot is loaded or saved", apply = &"_apply_difficulty", repeat = false, detach = true}`.
    - `static func difficulty_value(text: String) -> Array`: `[tier, ""]` for a value in `SlotState.DIFFICULTIES` (exact, lower case), else `[&"", <warning>]`.
    - **Applied on every `player_spawned`, never in `_apply()`**: DevTools runs before `Game.boot()`, and a detached boot's `load_slot()` resets the slot, tier included. The handler calls `Game.slot.set_difficulty(tier)` (no save: the session is detached).
    - `test_dev_args.gd`: the values and the `detach` row. `smoke_dev_tools.gd`: applied, detaches, a bad value warns and detaches nothing. `smoke_dev_boot.gd` (the real boot, once per process): add `--difficulty=easy` to its tokens beside `--room`; its check at about line 46 (`Game.slot.difficulty == &"normal"` after boot) becomes `&"easy"`: neither the planted `hard` nor the reset's `normal`, since the first spawn runs inside World's `_ready()`.

12. **The perf run uses the real cache.** (`scripts/dev/perf_run.gd`; closes the 1.12 ledger item "The Ember Cache's glow is a `BudgetLight` of rank CACHE")
    - The `PerfCache` stand-in becomes an `EmberCache` instance (`ember_cache.tscn`) under the room, moved each tick at `CACHE_OFFSET` as now; `CACHE_RADIUS` is removed (the radius is `Tuning`'s). The flare stand-in stays until 1.23. `stand_ins` keeps the flare; a separate typed var holds the cache, re-made on every spawn (a death frees it through `cache_changed`).
    - It now wakes lurkers in `perf_worst` (harmless: they hunt a cache). `smoke_perf` pins the two stand-ins (`stand_ins.size() == 2`, ranks, parents, at about lines 158–162 and 281): update it to the flare stand-in plus the real cache (rank CACHE, a child of the room, kind `cache`), and it stays green; one headless `--perf=20` run's summary (max lights / sprites / over) is recorded in the Dev Agent Record beside 1.15's, and the laptop run is in Task 11.

13. **Docs, ledger and project-context.** (D11)
    - GDD Economy: the cache radius is `Tuning` `cache_radius` (80 px to start); any death destroys an unrecovered cache, on every tier (or Q1's answer). Decision log: Q1 / Q2 answers.
    - `game-architecture.md`: the State Management example puts `cache_changed` on `SlotState`, not `DiveState`; the data flow says World spawns the cache after the room is built (RoomLoader stays slot-free) at `Room.floor_spot()`; the death flow names `SlotState.apply_death()` and its report.
    - `DESIGN.md` line 480 ("Nothing else in the world is amber"): the Ember Cache burns amber because it holds your embers (Q2).
    - `docs/`: `component-inventory.md` (SlotState, DiveState, Room, EmberCache, World, DevTools' `--difficulty`, the new tests), `architecture.md`, `development-guide.md` where they list state, args or tests; `source-tree-analysis.md` (the new `objects/` folders); `perf.md` (the cache stand-in is now the real cache, and the re-run's numbers). The architecture's Perf run paragraph (Debug Tools) says the same.
    - `project-context.md`: a Story 1.22 sentence in Current State, and the date line.
    - Ledger: close the two 1.22 items (the CACHE light, the mid-air fallback) with `→ **Closed (Story 1.22): …**` lines; append to the 1.23 item "A hunting lurker swings through a light that stands still" that the cache is the first still light a lurker hunts from 1.22, so 1.23's choice covers both. Any new deferred item gets an owner line (`test_deferred_owners`).

14. **Verify.** `cd game && ./run_tests.sh` → `== ALL GREEN`; `tools/export.sh` → `BUILD OK` (Node 24 from nvm on PATH); the laptop look (Task 11) recorded. Report "tests green; needs the laptop look".

## Tasks / Subtasks

- [ ] **Task 1: Stage rules on `DiveState` / `SlotState`** (AC1–AC4)
  - [ ] `DiveState.take_carried()`; the assert message.
  - [ ] `SlotState`: `deposited`, the cache fields, `has_cache()`, the two signals, `deposit_from()`, `DEATH_COST`, `apply_death()`, `recover_cache()`; `to_dict()` / `from_dict()` / `_assign()` / `reset()`; `RESUME_KEYS`. Header comments: drop "deposited embers and the Ember Cache (1.22)" from the "Not here yet" list; DiveState's "the death cost and the deposit arrive in Story 1.22" becomes what is true.
  - [ ] `tests/test_embers.gd` (AC9, pure); `test_state.gd` key list and helpers (AC10). Run both alone.
- [ ] **Task 2: `Room.floor_spot()`** (AC6)
  - [ ] The method; its cases in `test_room_loader.gd`.
- [ ] **Task 3: The death flow** (AC5)
  - [ ] `Player.held_at_death`, `popup_banked()`, `popup_lost()`; `die()` stops popping.
  - [ ] `World._on_player_died()`: the cost, `_last_death` / `last_death_cost()`, the popup.
- [ ] **Task 4: The Ember Cache** (AC7)
  - [ ] `Tuning.CACHE_RADIUS` / `cache_radius`; GDD Economy names the key (AC13, "change a value → update the GDD").
  - [ ] `tools/sprites/ember_cache.txt` → `python3 tools/build_sprites.py` → `godot --headless --path game --import`; commit `art/ember_cache.png` + `.import`.
  - [ ] `scripts/objects/ember_cache.gd`, `scenes/objects/ember_cache.tscn` (+ `.gd.uid`).
- [ ] **Task 5: World spawns it** (AC8)
- [ ] **Task 6: Smokes** (AC9, AC10)
  - [ ] First: the grep in AC10 over `game/tests/`; list every hit in the Debug Log and fix each.
  - [ ] `tests/rooms/embers/t_cache_drop.txt` (validate it: exits link, the `up` entry cell is no hazard).
  - [ ] `tests/smoke_embers.gd`; the cache case in `smoke_lurker.gd`; `test_light_budget.gd`.
  - [ ] `smoke_world.gd`, `smoke_health.gd`, the planted JSON strings; red-check: with `apply_death()`'s Normal branch keeping carried, `smoke_embers` and `test_embers` fail; with World not spawning the cache, the epic's smoke fails.
- [ ] **Task 7: DevTools `--difficulty`** (AC11)
- [ ] **Task 8: Perf run** (AC12)
- [ ] **Task 9: Docs, ledger, project-context** (AC13)
- [ ] **Task 10: Verify** (AC14): `./run_tests.sh` → `== ALL GREEN`; `tools/export.sh` → `BUILD OK`.
- [ ] **Task 11: Laptop look (sonlm)** — a debug build:
  - [ ] Normal: bank a chain, die away from the top, respawn: the cache reads as yours (amber, steady) where you died, on the floor; lurkers near it stir or wake; touch it: "+N banked" and the glow goes.
  - [ ] A second death before recovering: the old glow goes at once.
  - [ ] `--difficulty=easy` and `--difficulty=hard`: no cache.
  - [ ] `--room=perf_worst --perf`: the summary with the real cache (lurkers now wake for it) beside 1.15's numbers (`docs/perf.md`).
  - [ ] Record the verdict and any notes; feel notes go to 1.30 with owner lines.

## Dev Notes

### What this story is (and isn't)

It gives embers their M2 lifecycle: held (per life, `ChainState`) → carried (per dive, `DiveState`) → deposited (per slot, `SlotState`), and a death that costs what the tier says, with the Ember Cache as Normal's way back. After it, a Normal death in play drops a cache that glows, lures and gives the embers back. **Nothing deposits in play yet**: the rest that calls `deposit_from()` is 1.24's, the hub E5's. **Nothing shows carried or deposited on the HUD yet** (1.25), and the death card that reads the report is 1.29's.

### What exists today (read before editing)

- **`rules/chain_state.gd`:** `held` embers per chain; `add_hit()` pays `ember_value(link)`; `break_chain()` / `break_by_hit()` → `_end()` emits `banked(amount)` then `ended(links, by_hit)`; **`lose()` zeroes held and count and returns the held amount, emitting neither `banked` nor `ended`** (`test_chain_state` `test_lose_emits_no_ended`: a death can never bank-heal). Read `tests/test_chain_state.gd` before touching it; this story doesn't need to.
- **`rules/dive_state.gd`:** `carried`, `respawn_room` / `respawn_entry`, `_killed`; `add_carried(n)` asserts `n >= 0`; `to_dict()` → `{carried, respawn_room, respawn_entry}`; `from_dict()` never asserts; `reset()` / `_assign()` emit every value signal once.
- **`rules/slot_state.gd`:** `best_chain`, `deaths`, `difficulty` (`DIFFICULTIES`, `DEFAULT_DIFFICULTY`), `play_time`, `depth`, `resume_room` / `resume_entry`, flags, visited; `RESUME_KEYS = ["resume_room", "resume_entry"]`; `_assign()` sets every field then emits; `_count()` reads whole floats up to 2^53; `WHOLE_FLOAT_MAX`. `set_difficulty()` asserts a known tier and doesn't save.
- **`core/game.gd`:** `save_now()` (resume) / `save_progress()` (progress: live slot with `_resume.slot[key]` for each `RESUME_KEYS` key and `_resume.dive`); `_resume_part(slot_dict)` indexes `slot_dict[key]` for every resume key, so `"cache"` must always be in `to_dict()`; `set_difficulty()` saves progress on a change; `reset_for_tests()` resets `slot` and `dive` (so `cache_changed` fires and live cache nodes free themselves).
- **`actors/player.gd`:** `die(cause)` sets `death_cause`, `is_dead`, extinguishes the light, clears the Clock, `var lost := chain.lose()`, shows `POPUP_LOST` (`Color(1, 0.35, 0.3)`), emits `died`. `_on_banked(amount)` shows `POPUP_BANKED` (`Color(1, 0.93, 0.7)`) unless dead. `_fx_parent()` returns World's current room (or the parent, without World). Body: `CollisionShape2D` 10 × 20 at (0, 2), so the body's bottom is at y + 12; layer 2.
- **`world/world.gd`:** `_safe_pos` (room-local) is set on every floor tick that touches no hazard and seeded with `room.ground_below(entry)` at every build; `last_safe_position()` returns it. `_on_player_died()` → `Game.slot.record_death()` and the respawn timer; `_respawn()` → `_swap_room(point, true)` (always a rebuild). `_spawn_player()` wires `chain.banked` → `Game.dive.add_carried`. `_swap_room()`: load → retire the old player (respawn) → remove + free the old room → add the new → `Game.palette.set_zone()` → `Fx.warm_up()` → place / spawn the player → seed `_safe_pos` → camera → `player_spawned` → `visit()` → `room_entered`.
- **`world/room.gd`:** `TILE` 16; `spawn(scene, pos, args)` (args before `add_child`); `bounds()`; `entry_position()` (feet formula: `(cell.y + 1) * TILE - 12`); `ground_below(entry)` (falls back to the entry itself when the column ends on spikes or in an open bottom: the ledger item AC6 closes); `is_solid(cell)`; `hazards` (Vector2i → true); `touches_hazard(rect)`.
- **`actors/light_source.gd`:** `kind` (must be in `Sensing.KINDS`; `&"cache"` exists), `radius_fn` / `fixed_radius`, `extinguish()`, `live()`; it eases its child `Light`'s `texture_scale` and snaps on the first tick.
- **`actors/lurker.gd`:** reads every lit `LightSource`; `_harmful()` is true only while it hunts a `player`-kind light it senses (1.20 D7), so a cache hunt is harmless already; H1: a target that goes out → RETURN at once.
- **`core/budget_light.gd`:** `Rank { ALWAYS, CACHE, GLOW }`; set `rank` before `add_child` (in the `.tscn` it is, as `rank = 1`); builds its additive fallback sprite in `_ready()`.
- **`dev/dev_tools.gd`:** `ARGS` rows `{help, apply, repeat, detach}`; `_apply()` runs from `_ready()`, **before `Game.boot()`**; `--hp` applies on every `player_spawned` through its own handler (`_on_player_spawned_hp`): the pattern for `--difficulty`.
- **`dev/perf_run.gd`:** two stand-in `BudgetLight`s (`PerfFlare` ALWAYS, `PerfCache` CACHE at `CACHE_RADIUS` 80) at `FLARE_OFFSET` / `CACHE_OFFSET` from the player, clamped one tile inside the room, rebuilt on every spawn.
- **Sprite pipeline:** `tools/sprites/<name>.txt` grids with chars from `palette_edge.txt` (`.` transparent, `0`–`3` the Edge ramp, `L` `#ffd27a` the chain-light amber, `E` / `e` lurker reds); `python3 tools/build_sprites.py` writes `game/art/<name>.png`. Never hand-make a PNG.
- **Strings:** `POPUP_BANKED` ("+%d banked") and `POPUP_LOST` ("-%d lost") exist. This story adds no key, so no `.translation` changes.

### Decisions

Story-author decisions; sonlm can veto any before dev. Q1 and Q2 below were answered by sonlm on 2026-11-26 with the defaults the story uses.

- **D1: Scope.**
  - In: the three stages as rule methods, the death cost per tier and its report, the cache (state, save, object, spawn, drop spot, recovery), `--difficulty`, the perf stand-in, tests, docs.
  - Out, each with its owner: the rest that deposits (1.24); hub arrival (E5); carried / deposited on the HUD (1.25; deposited never shows on the dive HUD, UX); the death card, its tier line and its cache-gone line (1.29, from `last_death_cost()`); the Options difficulty choice (1.36) and the difficulty step (1.38); the map's cache mark (UX-DR87, 4.20); `death_log` (1.29).
- **D2: Where each stage lives.** Held: per life (`ChainState`). Carried: per dive (`DiveState`). Deposited and the cache: per slot (`SlotState`, AR14: the cache survives rests and saves). Every write is a rule method that emits (AR18); no reader gets a mutable container (the cache is three value fields, not a Dictionary).
- **D3: The death cost is one `SlotState` method with a report.** The tier lives on `SlotState`, and so does the cache, so the rule sits there and writes the dive through the dive's own methods. It returns a plain report because the death card (1.29) needs "what was lost, dropped, destroyed" and can't rebuild it after the fact. World calls it, because the drop spot needs the room and the safe-ground tracker (and without World there is no cost, which keeps RoomHarness tests as they were). `Player.die()` keeps `chain.lose()`: a dying player's chain must stop at once; the amount reaches the rule through `held_at_death`.
- **D4 (Q1, sonlm 2026-11-26): any death destroys an unrecovered cache, on every tier.** "If you die again before then, the cache is gone" is the cache's own rule, and it keeps "at most one cache" trivially true. The case only arises when the tier changed while a cache was out (Options, 1.36). The report's `cache_destroyed` lets 1.29 say so on every tier.
- **D5: Save shape and resume key.** `"cache"` is always present (`null` or the four fields), so `_resume_part()` and old-file loads stay simple. It is a resume key, so a progress save never moves it (1.21 D6). No version bump before 1.41.
- **D6: The drop spot is `floor_spot(last_safe_position())`.** The tracker is the AC's "last safe ground the player stood on in that room"; `floor_spot()` is the backstop that makes "never floating, never out of reach" hold for every input, including the `ground_below()` fallback the 1.19 ledger item names. Nearest clean floor, by distance, deterministic ties.
- **D7: World spawns the cache; the node is disposable.** The architecture's data flow put the spawn in `RoomLoader`, but rooms must load standalone without a save, so World spawns it after the build through `room.spawn()`. The node never decides anything about the slot: on any `cache_changed` it goes dark and frees itself, and each build spawns what the slot holds. A cache on the respawn spot is recovered on the first overlapping tick: a touch is a touch.
- **D8: The cache's look.** Amber (Q2), steady, on the floor; its glow is the light lurkers sense, sized by `Tuning` `cache_radius` (80 px, the notice floor, so it lures from the start; 1.30 tunes it). No flicker or pulse, so no `Fx.EFFECTS` row and nothing to hold to NFR8. Recovery reuses "+N banked"; the death shows "-N lost" for what was really lost. No new string keys.
- **D9: Shared-World smokes leave no cache behind.** `smoke_world` and `smoke_health` run many cases in one World; an 80 px cache left in `m1_shaft` would wake lurkers in later cases. Each death case recovers its cache before it ends.
- **D10: `--difficulty` applies on spawn.** The detached boot resets the slot after DevTools' `_apply()`, so an immediate `set_difficulty()` would be undone. `detach = true` as 1.21 decided: a dev tier never reaches a save.
- **D11: Docs move with the code** (the 1.19 / 1.21 practice): GDD, architecture, DESIGN's amber line, `docs/`, project-context, the ledger.

### Risks and traps

- **`--difficulty` set in `_apply()` passes `smoke_dev_tools` and fails in a real run**: a test World never boots. Only `smoke_dev_boot` exercises the real order; that case is the one that matters.
- **A cache left in a shared smoke World** changes later lurker cases silently (D9).
- **Easy through `break_chain()`** would emit `banked` (a popup on a dead player is suppressed, but `ended` would fire and could bank-heal a dead life). Use `dive.add_carried(held)` in `apply_death()` only.
- **`cache_changed` from `_assign()`** fires on every load and reset: correct for the node (it frees), but a future HUD that animates on it must tell a load from a drop (1.25 / 1.29's concern; the report is the drop).
- **`floor_spot()` on the exact boundary**: the feet sit at `pos.y + 12`, on a tile edge; find the standing row with `floori((pos.y + 12.0 - 0.5) / TILE)` and check the 1 px tolerance, so float drift on a floor tick neither moves a good spot nor accepts a floating one.
- **`Area2D` overlaps lag a tick** after a spawn or a move (Godot updates them in the physics step): a test that places the player on the cache waits two physics frames before asserting.
- **The light budget's view edge** (ledger, owner 1.23): a CACHE light lying still meets the same edge as a stuck flare; not this story's.

### Project Structure Notes

- New: `game/scripts/objects/ember_cache.gd` (+ `.uid`), `game/scenes/objects/ember_cache.tscn`, `tools/sprites/ember_cache.txt`, `game/art/ember_cache.png` (+ `.import`), `game/tests/test_embers.gd`, `game/tests/smoke_embers.gd`, `game/tests/rooms/embers/t_cache_drop.txt`. The `objects/` domain folders are new; the architecture's layout already names `objects/ember_cache.gd`.
- Dependencies point one way: `objects/` may use `rules/` and `core/` (Fx, BudgetLight) and `actors/light_source.gd` (same layer as actors); `rules/` never mentions `Node`, `Game` or `Engine` (`Vector2` is fine).
- Commit `.gd.uid` and `.import` files with their sources.

### Project Context Rules

- State in pure objects; `Game` keeps the same instances and resets them in place; write only through rule methods that emit (lint `state_write` catches `Game.slot.cache_room = …`).
- Death does not reload the scene; World applies the death cost, rebuilds the respawn room, spawns a fresh Player and emits `player_spawned`.
- Predators sense light only through `LightSource` + `Sensing` (lint `light_query`); a predator damages only while `monitorable`, only while the player is its target. The cache adds a `light_source` of kind `cache`, never a damage path.
- Every `PointLight2D` is a `BudgetLight` with a rank (lint `raw_light`, `test_light_budget`'s scene audit); the cache is CACHE.
- Runtime spawns go through `room.spawn()`; the room owns and frees them. Contact is polled, not `body_entered`.
- Tuning is data: a `const` with a `##` unit + intent + source comment, listed in `BASE`; change a value → update the GDD table.
- Difficulty is not a modifier: it lives in `SlotState` and changes only death cost.
- Text through `tr()` keys (lint `raw_text`); no new keys here.
- Sprites only through `tools/build_sprites.py`.
- Saves: only `Game` commands save; format number only in `Migrations.VERSION`; parse with `JSON.new().parse()`; a test that saves points `Game.store.dir` at a temp folder and calls `Game.load_slot(1)` first (again after every `reset_for_tests()`).
- Tests: `test_*` / `smoke_*` names, `ok` / `FAIL` lines, no `ERROR:` line; compare guarantees with `Spec`, never the tuning value under test; pick targets by position, not group index; "tests green; needs the laptop look", never "feels right".
- Every deferred item gets an owner line, assigned by the agent that defers it.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.22] (FR22–FR25, AR13, AR24, UX-DR67); neighbours 1.21 (RESUME_KEYS, detach), 1.24 (rest), 1.25 (ember rows), 1.29 (death card, UX-DR82/83), 1.30 (cache radius, CP2), 1.36 / 1.38 (difficulty UI)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md#Economy and Resources] (three stages, tiers, cache glow)
- [Source: _bmad-output/game-architecture.md#State Management, #Scene Structure and Rooms (data flow), #Light Sensing, #Lighting]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/EXPERIENCE.md#Death card by difficulty, #J3 — Death and cache run]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/DESIGN.md] line 480 (amber)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] the two 1.22 items; the 1.23 swing item
- [Source: _bmad-output/implementation-artifacts/1-21-save-store.md] D6 (progress save), D12 (detach), the 1.22 notes
- [Source: _bmad-output/implementation-artifacts/1-19-health-4-hp-and-the-damage-table.md] D6 (safe ground)
- [Source: _bmad-output/implementation-artifacts/1-20-light-sensing-for-predators.md] D7 (`_harmful()`)

## Questions for sonlm (answered 2026-11-26)

- **Q1: Does an Easy or Hard death destroy an unrecovered cache?** FR23 and the epic only cover Normal, and the tier can change while a cache is out (Options, 1.36). Default (D4): yes, on every tier: "die again before you recover it and it's gone" is the cache's own rule. Alternative: Easy keeps an old cache, since Easy loses nothing.
  **sonlm 2026-11-26: yes, every tier** (D4 stands).
- **Q2: The cache burns amber.** DESIGN line 480 says nothing else in the world is amber, but the GDD and the epic say the cache glows amber. Default: amber, because it holds your embers (your spark), as a lit anchor does; DESIGN gets the note.
  **sonlm 2026-11-26: amber** (D8 stands).

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created

### File List
