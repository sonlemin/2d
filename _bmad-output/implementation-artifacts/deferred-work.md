# Deferred Work

## From spec-m1-core-loop-prototype (2026-11-08)

- **Field Journal death line** — on death, write one journal line naming the cause (Hard Landing / Prey). Milestone 1 scope; deferred from the core-loop slice.
  → **Owner: E1** (2026-11-12). Causes are now the M2 damage sources (cause + how to avoid; Hard Landing and Prey were dropped by M1 tuning); voice per `narrative-design.md`.
- **HUD polish** — styled chain counter, light meter, flash-safety "reduce flashing" toggle in a settings menu.
  → **Owner: E1** (HUD v2 in the gutters, reduce-flashing toggle in Options); final polish E7.

## Mechanic ideas — after the M1 playtest (2026-11-10)

Rule: add these one at a time, each as its own experiment, only after M1 answers
"does a long chain feel tempting and dangerous?". Mixing them in earlier would hide that answer.

**Owner (2026-11-12): the M2 retrospective**, before the Layer 2 GDD update — review this list there and
promote at most one idea per layer milestone. None are in M2 (GDD Out of Scope: "No block or parry in M2").

- **Lurker parry (top candidate after M2)** — a tightly timed attack into a hunting lurker makes it recoil;
  the chain survives (maybe +1 link). Turns the danger into temptation. Needs a big flash/freeze payoff.
  → **Owner (2026-11-12): the M2 retrospective**
- **Phase dash** — the air dash passes through enemies briefly, at a cost (light or one link).
  → **Owner (2026-11-12): the M2 retrospective**
- **Cash in the chain** — spend links to heal or open sealed doors: bank it now or keep it growing.
  → **Owner (2026-11-12): the M2 retrospective**
- **Chain-bending upgrades** — power-ups per run that change chain rules
  (e.g., "survive one landing", "Snuff doesn't break the chain").
  → **Closed (2026-11-12): absorbed.** Rule-bending moved to always-on Smith gear (GDD); per-run power-ups
  are the parked "Dive Boons". "Snuff doesn't break the chain" contradicts Snuff as a cash-out.
- **More pogo directions** — diagonal pogo; pogo off spikes and lurker projectiles, not only crawlers.
  → **Owner (2026-11-12): the M2 retrospective**
- **Wall-jump climbing (earned upgrade)** — M1 cling only slides down (a pause, not a route).
  Climbing comes back later as an ability you find, gating areas in Metroidvania style
  (Pillar 3: progress by skills, not XP). Variant to test: climbing costs chain links.
  → **Owner (2026-11-12): the M2 retrospective**

## Deferred from: code review of 1-1-move-m1-into-the-m2-folder-layout.md (2026-11-12)

- **Dev guide "Writing tests" is M1 guidance** — `docs/development-guide.md:53-54` says tests are `extends SceneTree` and pure rules go into `test_chain_state.gd`; project-context says a new `tests/test_<subject>.gd` run through `tests/runner.tscn`. Pre-existing; agents that read `docs/` first would put unrelated rules into the chain test.
  → **Owner: Story 1.2** (confirmed by sonlm 2026-11-12) — it moves every test onto `runner.tscn`, so it rewrites this section anyway.
  → **Closed (2026-11-12): rewritten in Story 1.2.**
- **bmad-loop's canonical ledger format would switch off the owner gate** — `### DW-n` headings with `status:` lines contain no `- ` items, so after a `bmad-loop sweep --migrate` the scan in `tests/test_deferred_owners.gd` sees 0 items and prints PASS. Latent: only matters if bmad-loop is adopted.
  → **Owner: Story 1.9** — it builds the glob runner and the lint, where ledger-format checks belong.
  → **Closed (Story 1.9 and its code review): `test_deferred_owners.gd` `unknown_format()` fails the run on a `### DW-n` heading, a `status:` line (any case, bulleted or bold), a table row, or a ledger with text under its sections but no list items; samples, plus a DW block appended to the real ledger.**

## Deferred from: code review of 1-2-log-and-a-clock-that-owns-time.md (2026-11-12)

- **A pause mid-request holds `Engine.time_scale` at the reduced value** — `game/scripts/core/clock.gd`: AR36 makes requests freeze with the pause, so the scale stays at 0.05 (hitstop) or 0.3 (E6 slow-mo) for the whole pause. `PROCESS_MODE_ALWAYS` UI (pause tab, menus, focus-loss pause) then runs its default Tweens and AnimationPlayers 3–20× slower. Latent: nothing pauses until the UI stories.
  → **Owner: Story 1.31** — the UI kit builds the shared easing and tweens, so it can make them ignore the time scale (as AR44's audio tweens already do).

## Deferred from: code review of 1-3-tuning-as-data.md (2026-11-12)

- **No floor holds once gear bends a tuning value** — `game/scripts/rules/tuning.gd` `apply_gear()`: the M1 `@export_range(0.75, 3.0)` on the lurker telegraph was editor-only and is gone, so a gear `set` / `mul` row could push `lurker_telegraph_time` under 0.75 s (Pillar 2) or `crawler_hover_period` to 0 (NaN hover drift). Latent: `Gear.TABLE` is empty until E5, and no planned gear targets either key.
  → **Owner: Story 1.9** — its `Spec.TELEGRAPH_MIN` check should compare `Game.tuning.f(&"lurker_telegraph_time")` with every `Gear.TABLE` row applied, so a future gear that breaks the floor fails the suite.
  → **Closed (Story 1.9 and its code review): `test_tuning.gd` `stat_floor_errors()` tries every combination of the gear rows that bend a stat: `lurker_telegraph_time` ≥ `Spec.TELEGRAPH_MIN` and `crawler_hover_period` > 0. Probe gears prove both fire (a pair that only goes under together included), and two rows that both `set` a stat are reported.**

## Deferred from: code review of 1-4-state-objects-in-the-game-autoload.md (2026-11-12)

- **Settings writes skip the checks that slot saves get** — `game/scripts/core/save_store.gd` `write_settings()` writes `.tmp` and renames it with no read-back, so a write that fails at close can replace a good file with a truncated one. `game/scripts/core/game.gd` `_write_settings()` only warns on an error: there is no signal, so no "Not saved" state. On Windows the engine's rename deletes the target before it moves the file (4.7 source), so only a `.bak` made before the rename survives a crash there. `_bmad-output/game-architecture.md:530` still shows a static `SaveStore.write(…)`; the store is an instance at `Game.store`. Latent: only `brightness` is in the file.
  → **Owner: Story 1.21** — it adds `.tmp` → re-read → rename, `.bak` and `save_failed` to `SaveStore`, so settings can go through the same write path and failure signal.
- **The `rules/` purity check has holes, and nothing stops a direct write to a state field** — `game/tests/test_state.gd:351` and `game/tests/test_tuning.gd:185` scan a hand-kept file list with `\b(Node|Input|Engine)\b`, which misses `Node2D`, `InputEventKey`, `OS`, `Time` and `load(`. The state fields are public (the spec's choice), so `Game.settings.brightness = 2` compiles, emits nothing and is never saved.
  → **Owner: Story 1.9** — `test_lint.gd` takes over `rules/` purity: glob `scripts/rules/*.gd`, match the prefixes, and add a rule against assigning to a `Game.settings` / `Game.slot` / `Game.dive` field outside `rules/`.
  → **Closed (Story 1.9 and its code review): `test_lint.gd` rules `rules_purity` (every `rules/` file: Node classes, `Input*` / `Engine*` / `OS` / `Time` / file access / `load(`, the autoloads and every class from `core/` up) and `state_write` (assignments, nested fields, container mutators, `.set(`); the old purity scans are gone.** Not deferred work: what a text scan can't see by design (aliasing through a local, a write through a call's result) is listed in the lint's header, and every code review checks it.

## Deferred from: code review of 1-5-rooms-as-text-the-m1-shaft-at-22-tiles.md (2026-11-12)

- **Exit targets are never checked to exist** — `game/scripts/world/room_loader.gd` `validate()` only checks the `exits=` shape, so `exits=down:m1_shatf@x1` validates clean, passes the export gate and fails only at runtime when 1.7 swaps rooms. `validate()` is per-file and pure; the check needs every room id. It must also check that the target has the arrival entry: crossing `down` arrives at the target's `up` entry and vice versa (World `push_error`s and cancels a swap into a room without it, Story 1.7).
  → **Owner: Story 1.10** — `smoke_rooms` already checks ids unique across all files; it can check every exit target resolves through `RoomLoader`'s index the same way.
  → **Closed (Story 1.10): `smoke_rooms` runs `room_sweep.gd`'s `link_errors()` over every room file (`rooms/dev/` included): each exit target must be a room, and a `down` exit's target must have an `up` exit (an `up` exit's, a `down` one), each failure a named `FAIL`; room and obj ids are unique across files (`duplicate_id_errors()`).**
- **A `down` entry puts the player over the exit hole** — `game/scripts/world/room.gd` `entry_position(&"down")` uses cell `(col, h-2)` with "feet on the tile below", but `validate()` requires that bottom-row tile to be open, so a player arriving from below (crossing an `up` exit arrives at the target's `down` entry) falls straight back out, and could loop between two rooms. `tests/test_room_loader.gd` pins the current value (`Vector2(88, 84)` in `ok_min`). Latent: nothing arrives from below until room swaps.
  → **Closed (Story 1.7): arrival stands on the floor beside the opening (D3), and the validator requires that floor.**

## Deferred from: code review of 1-6-the-world-scene-replaces-the-m1-shaft.md (2026-11-13)

- **`CameraRig.apply_limits()` doesn't centre a room shorter than the view** — `game/scripts/world/camera_rig.gd` `apply_limits()` centres a narrow room horizontally, but sets `limit_top` / `limit_bottom` straight from the bounds, so a room under 270 px tall pins to one limit and shows void on the other side. Every room so far is a tall spine room.
  → **Owner: Story 2.1** — the Weaver test arena is the first non-spine room; centre vertically the same way if it is shorter than the view.

## Deferred from: dev of 1-7-room-swaps-physics-interpolation-and-retiring-shaft-gd.md (2026-11-14)

- **No bank popup at a room cut** — crossing an exit with a live chain banks it (`break_chain()` in `World._on_exit_reached()`), and the "+N banked" popup spawns into the old room, which the swap frees at the end of the frame, so the bank is invisible. Runtime spawns belong to the room (AR23), so the popup isn't moved.
  → **Owner: Story 1.25** — the gutter HUD's ember counter shows a bank at a cut; decide there whether a cut needs its own cue.

## Deferred from: code review of 1-7-room-swaps-physics-interpolation-and-retiring-shaft-gd.md (2026-11-14)

- **Arriving from below can land next to an enemy** — `game/scripts/world/room_loader.gd` `down_entry_cell()` checks only that the stand cell is open, not what spawns on that floor. In `m1_shaft` the stand cell (3, 102) is beside the walker at (4, 102). A probe with no input: the walker knocks the player into the hole and they loop to the top. Latent: `m1_shaft`'s ceiling gap is out of reach in play (P's ledge is ~84 px below it, the jump reaches 60 px), so only tests and DevTools arrive from below.
  → **Owner: Story 1.10** — its `smoke_rooms` / bot pass checks every arrival entry is safe (no enemy on the arrival floor, or a grace on arrival), with exit targets resolved across files.
  → **Closed (Story 1.10): `arrival_errors()` in `smoke_rooms` fails any enemy spawn within 3 cells (Chebyshev, ≈ 1.9 s of walker travel) of a swept room's `down` entry stand cell; `m1_shaft`'s walker moved from (4, 102) to (8, 102) (D11 option A, approved by sonlm 2026-11-18).**


## Deferred from: dev of 1-10-room-smoke-tests-and-the-reachability-bot.md (2026-11-19)

- **`smoke_bot` and `smoke_rooms` run every room in one runner process** — `game/tests/smoke_bot.gd` takes ≈ 28 s per spine room (`m1_shaft`) and `smoke_rooms.gd` ≈ 10 s per room with 4 lurkers, under the runner's 120 s watchdog (150 s in `run_tests.sh`), so Layer 1's rooms push them over it at about four spine rooms. Both sentinels also name `rooms/l1/m1_shaft.txt`, which Story 4.9 moves to `rooms/dev/` (validated only, never swept or botted).
  → **Owner: Story 4.9** — the first Layer 1 room, which moves `m1_shaft` to `rooms/dev/`: point both sentinels at `s1_lip`, re-time the two files, and split them per room (a room-path argument or one file per layer) before either nears 60 s; never skip a room or a lurker to fit.


## Deferred from: code review of 1-8-playerinput-intents.md (2026-11-18)

- **The air dash runs longer than FR2 says** — `game/scripts/actors/player.gd` checks the dash timer before it counts it down, so a 0.12 s `DASH_TIME` dashes for 8–9 ticks (≈ 0.15 s, ≈ 39 px at 260 px/s), not FR2's 0.12 s / 31 px. That is M1's behaviour and `smoke_player_input` pins it (dx 31–40, 8–9 dashing ticks); the laptop feel checks have all been on the longer dash.
  → **Owner: Story 1.15** — the CP1 feel gate decides: fix the off-by-one (the dash becomes 31 px) or change the GDD to the felt 39 px, then tighten the pin.
- **The raw-`Input` source check is a substring regex** — `game/tests/smoke_player_input.gd` `test_sources` greps `Input\.` outside `player_input.gd`, so it misses event reads (`_input(event)`, `event.is_action_pressed(...)`) and aliasing (`var i := Input`), and flags `Input.` in comments.
  → **Owner: Story 1.9** — `test_lint.gd` takes over the "no raw Input outside PlayerInput / the UI kit" rule and should cover event-based reads; `test_sources` can then drop its regex.
  → **Closed (Story 1.9): `test_lint.gd` rule `raw_input` (`Input` / `InputMap` as identifiers, `InputEvent*`, the `_input` / `_gui_input` callbacks and the `gui_input` signal; comments and strings ignored); `test_sources` dropped its regex.**
- **`lock()` mid-move: a clinging player is kicked off the wall, and a jump keeps full height** — `game/scripts/actors/player_input.gd` `_clear()` sets `cling_held = false`, which `player.gd` `_handle_cling` reads as "Jump released", so one locked tick fires a wall kick (probe: `velocity (-150, -260)`); `jump_released` is not sampled while locked, so a jump released during a lock is never cut. Latent: nothing calls `lock()` yet. Reason (sonlm): decide it with the first scripted moment.
  → **Owner: Story 1.24** — the first `lock()` caller (station rest); decide what a lock does to a cling or a rising jump (likely a drop with no kick, and a cut on unlock) and test it.
