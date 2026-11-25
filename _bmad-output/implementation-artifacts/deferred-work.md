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
  → **Closed (Story 1.21): `write_settings()` goes through the store's one verified write (`.tmp` → `verify_file()` read-back → rename), and a failed settings write emits `Game.settings_save_failed(err)` beside its one warning. Settings get no `.bak` (D11): a lost `settings.json` falls back to the defaults and is rewritten. The architecture's error-handling sample is `Game.store.write_slot(…)`.**
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
  → **Closed (Story 1.15): sonlm kept the felt dash (CP1 gate, 2026-11-21). GDD Movement and FR2 now read 260 px/s for 0.15 s (9 ticks, ≈ 39 px); the code is unchanged so the dash plays identically, the `Tuning.DASH_TIME` comment says why, and `smoke_player_input` pins exactly 8 gravity-free ticks, 9 dashing ticks and 38.5–39.5 px (measured 8 / 9 / 39.0, before and after).**
- **The raw-`Input` source check is a substring regex** — `game/tests/smoke_player_input.gd` `test_sources` greps `Input\.` outside `player_input.gd`, so it misses event reads (`_input(event)`, `event.is_action_pressed(...)`) and aliasing (`var i := Input`), and flags `Input.` in comments.
  → **Owner: Story 1.9** — `test_lint.gd` takes over the "no raw Input outside PlayerInput / the UI kit" rule and should cover event-based reads; `test_sources` can then drop its regex.
  → **Closed (Story 1.9): `test_lint.gd` rule `raw_input` (`Input` / `InputMap` as identifiers, `InputEvent*`, the `_input` / `_gui_input` callbacks and the `gui_input` signal; comments and strings ignored); `test_sources` dropped its regex.**
- **`lock()` mid-move: a clinging player is kicked off the wall, and a jump keeps full height** — `game/scripts/actors/player_input.gd` `_clear()` sets `cling_held = false`, which `player.gd` `_handle_cling` reads as "Jump released", so one locked tick fires a wall kick (probe: `velocity (-150, -260)`); `jump_released` is not sampled while locked, so a jump released during a lock is never cut. Latent: nothing calls `lock()` yet. Reason (sonlm): decide it with the first scripted moment.
  → **Owner: Story 1.24** — the first `lock()` caller (station rest); decide what a lock does to a cling or a rising jump (likely a drop with no kick, and a cut on unlock) and test it.


## Deferred from: dev of 1-11-devtools-entry-args-and-overlays.md (2026-11-19)

- **`--chain` starts at take-off and ends on its first break** — `game/scripts/dev/dev_tools.gd` pays n `ChainState.add_hit()` calls on each life's first airborne tick, and the chain then breaks and banks like any chain (a landing, Snuff, cling grace, a knock or an exit). `perf_worst`'s 60 s run needs the light held at chain 20 for the whole run.
  → **Owner: Story 1.12** — the worst-case performance scene (`rooms/dev/perf_worst.txt`, "the player at chain 20") and its 60 s run are 1.12's; it decides how the light stays at chain 20 there.
  → **Closed (Story 1.12): `--perf[=<s>]` (`game/scripts/dev/perf_run.gd`, D1, sonlm's choice: the autopilot) holds the chain for the whole run by never letting it break: the player's input is locked, its `Hurtbox` masked off, and it rides a fixed vertical path down the room's centre that, in `perf_worst`, never touches a floor or an exit (a room whose centre line is blocked, such as m1_shaft, gets a path warning at the first spawn). The chain (`--chain`'s n, else 20) is still paid through `--chain`'s take-off arming and never pinned; the summary counts `breaks` (expected 0), and `smoke_perf` checks chain 20 on every tick of a 3 s run.**
- **The on-screen light count lives only in `dev/`** — overlay 4's count (`counts_on_screen()` in `game/scripts/dev/overlays.gd`: shown, enabled, energy > 0, a texture, and its texture rect meets `World.play_rect()`) is the only code that knows which `PointLight2D`s are on screen. The ≤ 6 budget (AR46) needs the same rule in game code, and the engine itself culls lights against the whole 480×270 viewport, gutters included.
  → **Owner: Story 1.12** — it keeps at most 6 `PointLight2D` lit on screen (lurker glows fall back to sprites first); decide there whether the budget counts the play rect or the viewport, move the rule into game code and point overlay 4 at it.
  → **Closed (Story 1.12): the rule moved into game code as `BudgetLight` (`game/scripts/core/budget_light.gd`: `lit_on_screen()`, `texture_rect()`, `choose()`, `apply()`, `counts()`), applied every physics tick by World's `LightBudget` child after the actors (D3–D5). It counts the whole view, `World.light_rect()` = `CameraRig.view_rect()` (D2, sonlm's choice: a cost rule; AR20's fairness rules keep `play_rect()`). Overlay 4 now calls `BudgetLight.counts()` with that rect, so it shows exactly what the budget counts (D8); `counts_on_screen()` is gone.**
- **Overlay 2 reads the sensing constants from `Lurker`** — `game/scripts/dev/overlays.gd` reads `Lurker.NOTICE_MIN_RADIUS`, `NOTICE_FACTOR` and `SCREEN_MARGIN`. When they move into `rules/sensing.gd`, `overlays.gd` must move in the same change, or every debug run fails to compile. Overlay 2 also gains sense/stir rings, plus a radius ring for every `light_source` (player, flare, cache), not only the player.
  → **Owner: Story 1.20** — it adds `rules/sensing.gd` (`can_notice`, `can_sense`, `can_stir`), where those constants move.
  → **Closed (Story 1.20): overlays.gd reads Sensing; overlay 2 draws rings for every light_source and a label per predator.**
- **A dev session meets the save** — `World._respawn_point()` reads `Game.dive`'s respawn point before `--room`'s start, and DevTools never writes it. From 1.21 a loaded respawn point beats `--room`, and a dev session (`--room`, `--chain`) records dev room visits (`SlotState.visit()`) and `best_chain` into the slot.
  → **Owner: Story 1.21** — the save store makes the respawn point and the slot save data; decide there what a dev session may write.
  → **Closed (Story 1.21, D12, sonlm 2026-11-25): a session that applied `--room`, `--chain`, `--hp` or `--perf` calls `Game.detach_slot()` before boot: no slot file is read or written for the rest of the process, so `--room` always wins and a dev room, chain or HP never reaches a slot. `--log`, `--set` and `--glow` leave the slot alone; a refused arg detaches nothing (`smoke_dev_tools` `test_detach`, `test_dev_args`).**
- **`dev_overlay` ships, inert, in release builds** — `game/project.godot` binds it (backquote) in every build, so a list of player actions read from `InputMap` would show it. Build one filter for player actions (it skips `dev_*` and `ui_*`) together with the controls reference, with a test that it never lists `dev_overlay`; 1.37's pad defaults and glyph tables use the same filter.
  → **Owner: Story 1.34** — the Pause controls reference (UX-DR52) is the first screen that lists bindings.
- **Rebinding must skip `dev_*` actions** — rebinding and reset to defaults offer only the actions from that player-action filter, and the clash rule ignores `dev_*` actions.
  → **Owner: Story 7.3** — rebinding (FR33, AR35) doesn't exist until E7.
- **Overlay 3 draws only the `spawn` / `up` / `down` entries** — `game/scripts/dev/overlays.gd` `room_items()`. When anchors and stations become entries (`game/scripts/world/room.gd` `entry_position()`), add them to overlay 3's item list and its `smoke_dev_tools` case.
  → **Owner: Story 1.24** — it extends `entry_position()`.
- **Boot screens must not swallow `--room`** — when the title and web gate land as boot screens, a run with `--room` / `?room=` must still start straight in that room (1.12's perf run, 1.13's Playwright `?room=perf_worst`, 2.12's `?room=weaver_test`). World must stay the main scene, so the `current_scene == World` gate in `DevTools._ready()` (`game/scripts/dev/dev_tools.gd`) still fires. 1.33 decides whether the web gate still shows (it unlocks audio).
  → **Owner: Story 1.33** — it adds the screens shown at boot.

## Deferred from: dev of 1-12-worst-case-performance-scene.md (2026-11-19)

- **`LightSource` drives its light through the owner's `BudgetLight`** — the budget, not `LightSource`, decides light or sprite, and `LightSource` never writes `enabled` (`game/scripts/core/budget_light.gd`: only `set_demoted()` writes it). Until then the perf run's stand-ins are lights only and wake no lurker.
  → **Owner: Story 1.20** — it adds `LightSource` (architecture: "drives its `PointLight2D` (or sprite glow)").
  → **Closed (Story 1.20): LightSource eases its child BudgetLight's texture_scale and never writes enabled. The perf stand-ins stay lights only; the real cache (1.22) and flare (1.23) are LightSources.**
- **The Ember Cache's glow is a `BudgetLight` of rank CACHE** — and the perf run's cache stand-in (`game/scripts/dev/perf_run.gd` `CACHE_RADIUS`, 80 px) then reads its radius from the cache's `Tuning` value instead of its own const.
  → **Owner: Story 1.22** — it builds the Ember Cache and its light radius. Story 1.20: replace the stand-in with the real LightSource; it then wakes lurkers in `perf_worst`, so re-read the summary.
- **A flare's light is a `BudgetLight` of rank ALWAYS** — and the perf run's flare stand-in (`game/scripts/dev/perf_run.gd`, at the player's light radius, riding along) is then compared with a real thrown flare, which sticks where it lands.
  → **Owner: Story 1.23** — it builds Flare Toss and the flare. Story 1.20: replace the stand-in with the real LightSource; it then wakes lurkers in `perf_worst`, so re-read the summary.
- **Engine glow lives only in DevTools (`--glow`)** — if 1.15 says go, a follow-up moves it into game code and re-checks the brightness levels and contrast floors: the 2026-11-19 probe saw glow darken the dark ambient (0.039 → 0.016 on a software renderer). If it says no-go, bloom is faked with unshaded additive sprites (architecture → Lighting).
  → **Closed (Story 1.15): no-go (sonlm, CP1 gate, 2026-11-21). Bloom is faked with unshaded additive sprites; `--glow` stays DevTools-only; architecture Lighting, decision row 14 and the GDD bloom row record it. No follow-up story.**

## Deferred from: code review of 1-11-devtools-entry-args-and-overlays.md (2026-11-19)

- **Foreign URL query parameters warn on every web load** — `game/scripts/dev/dev_tools.gd` `real_tokens()` turns the whole `window.location.search` into tokens, and AC2 makes each unknown one a `push_warning` listing the known args. A web debug build whose host or test harness adds its own query parameter (a cache-buster, an embed option) prints one `DevTools: unknown arg --<name>` per parameter on every load. Harmless (debug builds only), but it is noise in the Playwright log.
  → **Owner: Story 1.13** — it builds the web debug export and the Playwright `?room=` smoke; if either adds its own query parameter, apply only the `ARGS` keys from the URL and ignore the rest quietly, with a test.
  → **Closed (Story 1.13): not triggered — the web smoke (tools/web_smoke/) passes only ARGS keys and fails on any "WARNING: DevTools:" line; Godot's shell and serve.js add no query parameters.**

## Deferred from: code review of 1-12-worst-case-performance-scene.md (2026-11-19)

- **The light budget has no hysteresis at the view edge** — `game/scripts/core/budget_light.gd` `choose()` leaves an off-screen light's own state alone (D4), so a light can't flicker itself as it crosses. But an ALWAYS or CACHE light that crosses `World.light_rect()`'s edge still adds or frees a slot, so while the budget is full some other GLOW light swaps light ↔ sprite on every crossing. A flare stuck near the edge, with the view bobbing to the pogo, could swap several times a second (NFR8: ≤ 3 flashes/s). Unreachable in 1.12: only the perf run's stand-ins are ALWAYS/CACHE besides the player, and they ride along inside the view. A possible fix: a light already counted on screen stays counted until its rect leaves `light_rect().grow(Room.TILE)`, with a jitter test where one ALWAYS entry crosses the edge every few passes.
  → **Owner: Story 1.23** — it builds the first real flare, the first ALWAYS light that sticks anywhere, so the crossing can be checked against real flare behaviour there (sonlm, 2026-11-19: defer). 1.22's cache, a CACHE light lying still, meets the edge the same way.

## Deferred from: laptop look of 1-12-worst-case-performance-scene.md (2026-11-19)

- **The light's own shape is placeholder** — every light (the player's, lurker glows, flares, the cache, and the budget's fallback sprite, which copies the light's texture) uses one `game/art/light.png`: a 128 × 128 white disc with a smooth smoothstep falloff, generated by `light_texture()` in `tools/build_sprites.py`. sonlm on the laptop: "a bit barebone". No story changes the falloff itself. Pixel-art options: 3–5 hard brightness bands, or bands with an ordered dither between them. Either one is only a new `light_texture()`, with no runtime cost (same texture, same light count). Judge it against the zone palettes and with engine glow on and off.
  → **Owner: Story 4.5** — it sets Layer 1's look in the dark (tileset, palette zones, faint ledge rims, dead and cold lamps), so it decides how light falls on those tiles. Compare variants side by side in xvfb screenshots, then on the laptop (sonlm, 2026-11-19: leave the art for later stories).
- **Overlay 2 still drifts a little while falling** — after 5ac0bd9, overlay 2's player ring and labels ride on `DevLightMarks`, a child of the player that the engine interpolates with its sprite. Two parts of `game/scripts/dev/overlays.gd` remain at physics-tick positions:
  - the far end of each sense line, at the predator's tick offset, which can sit a tick of the player's fall travel off the lurker's sprite, several px at full fall speed;
  - the predator state labels in WorldMarks, at most 1.6 px off a hunting lurker.

  sonlm on the laptop: "still a bit shaky but better". A possible fix: put the labels on a child of each predator, and place a line's far end by interpolating both ends by hand (the previous and current tick positions plus `Engine.get_physics_interpolation_fraction()`). That fix can only be checked on the laptop, not headless.
  → **Owner: Story 1.20** — it already reworks overlay 2 (sensing moves to `rules/sensing.gd`, and overlay 2 gains sense and stir rings for every `light_source`), so it can draw the new rings and lines the steady way from the start (sonlm, 2026-11-19: log it for 1.20).
  → **Closed (Story 1.20, 2026-11-25):** labels moved onto a `DevPredatorMarks` child of each predator and the sense line's ends are interpolated by hand; sonlm's laptop look found overlay 2 steady while falling.

## Deferred from: dev of 1-13-export-pipeline-and-web-boot-smoke.md (2026-11-19)

- **The Windows build is never booted on the server** — `tools/export.sh` exports it and checks its PCK (AC3), but the server has no Windows or wine to run it, so nothing proves the `.exe` starts. Its PCK comes from the same filters as Linux's: the Windows, Linux and web release PCKs of the 2026-11-19 build are byte-identical (99,492 bytes), and the Linux build boots and the web build passes its smoke.
  → **Owner: Story 7.15** — it ships the final Windows build; boot it there on Windows (or under wine on the server) before the tester round.

## Deferred from: code review of 1-14-display-scaling-and-web-input.md (2026-11-20)

- **The first PC window fit may read the window decorations as 0** — `game/scripts/core/display.gd` `_fit_window()` reads `win.get_size_with_decorations() - win.size` once, from `Game.boot()` during World's first `_ready()`. On X11 the window manager may not have published `_NET_FRAME_EXTENTS` yet, so the decorations read (0, 0) and a borderline screen (usable 1440×830 with a 30 px title bar) picks ×3 and opens partly off it, the F8 case D4 fixes. Unverifiable under Xvfb (no window manager). A possible fix: re-fit once on the first `size_changed` or a frame later if the decorations were zero.
  → **Owner: Story 7.14** — no Linux desktop was available at CP1 (sonlm's laptop is Windows); the Steam Deck pass runs the Linux build under KDE (a real window manager): log the `display: window` line there and re-fit only if the decorations read zero.

## Deferred from: CP1 gate, Story 1.15 playtest (2026-11-21)

- **Physics interpolation was never compared at high refresh** — sonlm's laptop panel is 60 Hz only, where on and off look the same (one tick per frame). The case interpolation exists for (120/144 Hz, `CameraRig` on the physics tick) is still unseen.
  → **Owner: Story 7.14** — the Steam Deck OLED runs at 90 Hz: play on and off (`override.cfg`) there, and on any high-refresh monitor available by then; turning it off needs the `CameraRig` rework (story 1.15 D2).
- **The perf run counts a hidden browser tab as one long frame** — `game/scripts/dev/perf_run.gd` measures wall time and skips only tree pauses, so when a browser stops drawing a hidden tab the whole gap lands in one frame (1.15's discarded Chrome and Firefox runs: 132.8 s and 146.5 s). The run should flag it (or exclude it and say so) so a disturbed run can't pass as a slow GPU.
  → **Owner: Story 7.13** — the performance pass leans on long web runs; flag hidden time in the summary line before it starts.
- **The web key guard swallows the browser's DevTools keys** — F12 is in the guard's F-key list (`game/export_presets.cfg` `html/head_include`, both web presets), and Godot's canvas listener prevents every other key, so Ctrl+Shift+I/J/C never reach the browser. The 1.15 workaround is the browser menu. A fix lets them through the way F11 and zoom are (`9f9d6e1`), pinned in `test_export_presets`.
  → **Owner: Story 7.13** — its web runs read the console; fix it before them (or earlier, if a story needs the web console first).
- **CP1 measured only two perf runs** — by sonlm's choice, the laptop desktop (RTX 3050) and Firefox on the Intel iGPU, both glow off; not made: glow on (no-go), Chrome, the laptop desktop on the Intel iGPU, a separate HD 620 machine (none available).
  → **Owner: Story 7.13** — the 10-minute pass runs Chrome and the Intel iGPU desktop (Windows Graphics settings → Power saving) as part of NFR1.

## Deferred from: dev of 1-16-effects-accessibility-gate-and-flash-cap.md (2026-11-21)

- **The pogo squash is undone on the hit frame** — `game/scripts/actors/player.gd` `_process` recovers the squash with `delta / Engine.time_scale`. A pogo requests its hitstop in the physics tick that runs before `_process`, while that frame's delta was scaled at the old 1.0, so the recovery reads 1/60 / 0.05 = 0.33 s and snaps the (0.75, 1.3) squash back to 1 at once (and the frame the hitstop ends reads a tiny delta). Same trap Story 1.16 fixed in `CameraRig` (probed on 4.7.2: a time-scale change mid-tick never rescales that tick's delta). A fix: real time from `Time.get_ticks_usec()` differences, or the squash moved to the physics tick at one tick = 1/60 s.
  → **Owner: Story 1.19** — its hit flash (67 ms white, 100 ms dim under reduce flashing) is another real-time player-sprite visual triggered on a hit tick; fix the squash's clock with it, and check both on the laptop.
  → **Closed (Story 1.19): the squash recovers on the physics tick at one tick = 1/60 s; the hit flash is counted in ticks; smoke_health checks both in a hitstop.**
- **The pogo shake is barely visible** — since the 1.16 rig fix it plays (`CameraRig.POGO_SHAKE` 2.5 px, decaying at `SHAKE_DECAY` 20 px/s, so about 0.125 s), and sonlm on the laptop: "pogo yes but just a bit, barely visible". The M1 value was kept as is; a stronger kick (more px, or a slower decay) is a presentation change, and with shake off it stays zero either way.
  → **Owner: Story 1.30** — the CP2 kit playtest reviews the feel defaults (hit flash, bank burst); try 2.5 against 4–5 px there, on the laptop, side by side with `--set=shake:false`.

## Deferred from: code review of 1-16-effects-accessibility-gate-and-flash-cap.md (2026-11-21)

- **Shake turned off while paused leaves the last offset on screen** — `game/scripts/world/camera_rig.gd` zeroes `_shake` and `offset` in `_physics_process` when `Fx.shake_on()` is false (Story 1.16 D7), but a paused tree runs no physics tick. If the setting turns off while the tree is paused mid-shake, the last random offset (up to 2.5 px) stays on screen until the first unpaused tick. New in 1.16, and unreachable today: nothing pauses the tree and only `--set` changes the setting. A fix: the rig listens to `Game.settings.changed` and zeroes at once when `Fx.shake_on()` is false.
  → **Owner: Story 1.36** — Options opened from Pause is the first place the shake setting can change while the tree is paused; fix and test it there.
- **The web first-frame stall is unsolved** — `docs/perf.md`: 562 ms (1.15) and 548 ms (1.16, with `Fx.warm_up()`) worst frame at 0.0 s in Firefox on the Intel iGPU. The 1.16 run can't say whether the warm-up helps: the review found its items were freed on a 0.05 s timer and could go undrawn after a slow frame (probed on 4.7.2: 0 drawn frames; the patched version counts frames and draws twice). sonlm's re-run on the patched build (20261121-af07203) measured 634 ms at 0.0 s, so a warm-up that is drawn does not remove it either. That run also had 30 frames over 20 ms and min 24 fps, against 5 and 2 frames and min 28 and 29 before; nothing in the patch runs after the third frame, so one run can't say whether that is noise. The stall is at 0.0 s, the load itself, which a warm-up in that same frame can't remove; it will sit behind the click-to-play gate (Story 1.33). (Story 1.17: the warm-up label now draws a real popup's `LabelSettings`, the same font, size and outline, so that earlier mismatch is gone.)
  → **Owner: Story 7.13** — the full performance pass re-measures the first frame on every target, with several runs each so the over-20-ms count can be told from noise; decide there whether the warm-up stays, what it must draw, or whether a loading frame behind the gate replaces it. Open from the 1.17 code review (unverified): the warm-up label draws only `x`, so a popup's other glyphs (`+`, `-`, the digits, the letters of "banked" and "lost") may still be rasterised on their first use; measure it there before changing the label.
- **A pogo target that survives a hit plays no sparks** — FR38 "sparks on every pogo hit" holds today only because every pogo hit kills a crawler and its death calls `Fx.pop()` (Story 1.16 D6). The player's pogo itself makes no sparks, so the first pogo target with more than one hit of health breaks FR38 silently; no test checks sparks on a hit that doesn't kill.
  → **Owner: E4** — its creatures are the first new pogo targets (D6 names the creature dissolve); the story that adds one that can survive a hit adds the spark call on the hit and a smoke check for it.

## Deferred from: dev of 1-17-string-table-pixel-font-and-theme.md (2026-11-21)

- **Play-area text outline uses `TextStyle.PLACEHOLDER_SURFACE` (Cold violet), not the active zone's surface** — DESIGN's `components.text-outline.color` is the zone surface colour. Until `core/palettes.gd` exists, `Fx.popup()` outlines every popup in `#0d0b14` (zone-violet-0, the zone `m1_shaft` declares), so a popup in another zone gets the violet outline (Story 1.17 D6).
  → **Owner: Story 1.18** — it brings the palettes and the per-zone colours; replace the const with the active zone's surface and keep `TextStyle.play_text`'s cache keyed by colour pair.
  → **Closed (Story 1.18): Fx popups and the warm-up outline in Game.palette's surface; the const is gone; smoke_palettes checks a popup in an Umber room.**
- **Bank popup size: 8 px at every count** (sonlm, 2026-11-21; DESIGN's bank-popup row corrected in 1.17) — M1's 10 px from 5 links scaled the 8 px face by ×1.25 (uneven strokes in the render probe); the gutter chain number carries the long-chain read. A bigger popup, if ever wanted, is 16 px (an exact ×2), never 10.
  → **Owner: Story 1.26** — it owns and rebuilds the bank popup; keep it at 8 px at every count.
- **The window title isn't a string key** — `project.godot` `config/name` still reads "The Unbroken Chain (M1 prototype)", which shows in the desktop title bar and the web page title, outside the string table.
  → **Owner: Story 1.33** — the title screen shows the game's name; settle the shipped name and how the window title follows it there.

## Deferred from: code review of 1-17-string-table-pixel-font-and-theme.md (2026-11-22)

- **Lint `raw_text` knows only AC7's text sinks** — `game/tests/test_lint.gd:119` fires on `.text =`, `tooltip_text =`, `placeholder_text =`, `set_text(`, `popup(`, `draw_string(`, `draw_multiline_string(`, `add_item(`, `append_text(` and `add_text(`. Raw text set through `set_item_text(`, `set_tab_title(`, `add_check_item(`, `add_button(`, `title =` or `dialog_text =` passes unseen. Nothing calls these today, and adding them now would guess at controls the game may never use.
  → **Owner: Story 1.31** — the UI kit chooses the controls every menu is built from; add a sink (with a firing sample and a near-miss) for each text-setting call the kit uses.

## Deferred from: dev of 1-18-palette-tokens-contrast-and-the-deck-size-check.md (2026-11-22)

- **World art ignores the room's zone** — `Game.palette` follows each room's `zone` (gutters, clear colour, popup outline), but `game/scripts/world/room_loader.gd` `BACKDROP` (`#2a2440`, M1's violet index 1) and `LEDGE_RIM` (violet index 3, dimmed) and `World.AMBIENT_TINT` are the same in every zone, and every sprite is built from the one `tools/sprites/palette_edge.txt`. UX-DR3 is "E1 (tokens); E4 (applied across zones)". The only real rooms (`m1_shaft`, `perf_worst`) are violet, so nothing on screen is wrong today; a dusk or umber room would draw violet world art (Story 1.18 D10, sonlm's Q2).
  → **Owner: E4** — Layer 1's zones are its rooms: apply `Palettes.world_in()` to the backdrop, the ledge rim, the ambient tint and the sprites there (a palette per zone beside `palette_edge.txt`), with the 500 ms cross-fade (`changed` with blended colours). During the fade a popup takes the target zone's surface, never a blended one: `TextStyle.play_text` caches one `LabelSettings` per colour pair and has no cap (code review of 1.18).
- **Deck-size check: the carried count is harder to read than the held count** (sonlm, 2026-11-22, laptop at about 11.3 cm wide: "1240 easy, 386 harder") — in the mock, `+1240` is amber and `386` is the zone's HP role (bone/grey, dimmer), and 3, 8 and 6 are closed loops that close up at 1.4 mm.
  → **Owner: Story 1.25** — it builds the ember rows; check the carried count at Deck size there (×2 shot, same procedure), and if it still reads hard, try `HudValueLarge` (16 px) or HP-role weight first, and report the result to sonlm. A font change stays sonlm's call (Story 1.18 D13; review decision 2026-11-22).
- **Deck-size check: the dim chain 0 is hard to see** (sonlm: "maybe the the darker 0") — the chain at 0 draws in the EMPTY role, which meets the 3:1 shape floor but not 4.5:1 (Story 1.18 mock: Fusion ×3 standing in for the final digits).
  → **Owner: Story 1.26** — it hand-pixels the chain digits and owns the chain-at-0 look; decide there whether the 0 stays EMPTY (a shape, 3:1) or takes the LABEL role (text, 4.5:1), and check it at Deck size.
- **Deck-size check: body lines are readable but "quite hard"** (sonlm: "yes but quite hard") — the four 8 px lines at the death-text width (328 px). At ×2 on a Deck a 6 px cap is about 1.4 mm, which any 8 px face with a 6 px cap shares; the letter shapes are the face's own.
  → **Owner: Story 1.29** — the death card is the first screen of body lines; check it at Deck size there, and if it still reads hard, try 16 px lines (an exact ×2) first, and report the result to sonlm. A font change stays sonlm's call (Story 1.18 D13; review decision 2026-11-22).
- **Deck-size check: Latin-1 accents are unreadable at 8 px** (sonlm: "random sqibbles words at the end is unreadable", the `ÆØÅ éèê ñ ß` sample) — M2 ships English only (UX-DR17, AR41), so no shipped text uses them. UX-DR17 already names the Fusion 10/12 px builds for a later localisation.
  → **Owner: the M2 retrospective** — it decides post-M2 work; a localisation plan starts from this note and UX-DR17's larger builds.

## Deferred from: code review of 1-18-palette-tokens-contrast-and-the-deck-size-check.md (2026-11-22)

- **Nothing owns the clear colour outside play** — `Gutters._apply_palette()` is the only writer of `RenderingServer`'s default clear colour, and it runs only while a World is alive. Once World is freed, `Game.palette.reset()` moves the palette back to dusk and the clear colour stays on the last zone's gutter. No screen exists outside play today, and before Story 1.18 Gutters set the colour once in `_ready` in the same way.
  → **Owner: Story 1.33** — the title screen is the first screen outside play (UX D13: menus use Dusk); set the clear colour from `Palettes.role_in(Palettes.DEFAULT_ZONE, …)` there, or move the write to a home that outlives World.
- **The heart's x is open in DESIGN, and the mock drew it one pixel off the pips** — the Gutter HUD table gives the 7 × 7 heart as "centred x 30" and the 7 px pips as "x 26" (x 26–32). A 7 px icon can't centre exactly in the 60 px gutter: x 26 and x 27 both fit "centred x 30". `tests/deck_mock.gd` drew the heart at x 27, so the Deck-size shots show it one pixel right of the pips.
  → **Owner: Story 1.25** — it builds the heart and the pips; pick the heart's x there (x 26 lines it up with the pips) and state it as a number in DESIGN's table.
- **No lint holds "never a colour literal for UI"** — the rule (project-context, Story 1.18) relies on review, while its sibling rules each have a lint. `scripts/ui/` holds no `Color(` today, so a lint written now would have no real firing case. It must stay quiet on `Color(c, alpha)` built from a palette colour. Known exceptions outside `ui/`: `player.gd`'s two M1 popup colours, which Stories 1.26 and 1.27 remove (AC7).
  → **Owner: Story 1.25** — it adds the first coloured elements under `ui/`; add a `raw_colour` lint there with a firing sample and a near-miss from its own code.

## Deferred from: dev of 1-19-health-4-hp-and-the-damage-table.md (2026-11-22)

- **The death card has no line for a death with no cause** — `Player.die()` records `death_cause` as `&""` when it is called with no cause: World's tunnelling and failed-room backstops, and tests. Every hit that kills passes its `Health.CAUSES` id.
  → **Owner: Story 1.29** — it builds the death card and the `death_log`; give `&""` a fallback line there (and decide whether the log stores it), without adding a cause id that isn't a hit.
- **The Ember Cache when `ground_below()` falls back to a mid-air entry** — `World.last_safe_position()` is seeded with `Room.ground_below(entry)`, which falls back to the entry itself when the column below ends on spikes or in an open bottom; for an `up` entry that is in mid-air, so a death before the first floor tick would drop the cache there.
  → **Owner: Story 1.22** — its AC forbids a floating cache; refine the drop rule there (for example, the nearest clean floor in the room), with a firing room and a near-miss.
- **A spike in a perf room would hit the autopilot** — `--perf` makes the player untouchable by masking its Hurtbox, which never stops World's hazard poll (a rect test on `Room`, not a physics overlap). `perf_worst` has no spikes, so the run is unaffected today.
  → **Owner: Story 7.13** — the performance pass; if a perf room gains hazards, skip the hazard poll for the autopilot (DevTools only) or keep perf rooms hazard-free, and say which in `docs/perf.md`.
- **Spike readability in real rooms** — spikes are drawn unshaded (`art/spike.png` with `Fx.unshaded()`): lit like walls, as first chosen (Q3), they were invisible outside the player's light on the laptop (sonlm, 2026-11-22: "I can't even see it"). The art is a placeholder of thin 8 px strokes, and full brightness in every zone is untested against real room art.
  → **Owner: E4** — the first story that places a real spike (Layer 1 rooms and the tileset, 4.5/4.6) decides their final look with real rooms and the zone palettes: the art, and unshaded as now, dimmed, or a rim line.
- **The bot's HP margin on `m1_shaft`** — the bot takes three crawler knocks on its line, at (280, 744), (199, 1497) and (285, 1555), and ends at 1/4 HP (`smoke_bot`'s summary line). One more knock on the line would kill it and fail the run.
  → **Owner: Story 1.30** — the CP2 kit playtest notes whether the bot's line or the crawler placement should change; `Health.MAX` is never raised to keep the bot alive.
- **The room harness's stub World has no hazard poll** — `tests/room_harness.gd`'s `WorldStub` gives `play_rect()` and `current_room()` only, so `smoke_bot` and `smoke_rooms` (which load rooms through it) never feel a spike: a spine room with spikes on the bot's line would still pass "alive at the end". No real room has a spike today.
  → **Owner: E4** — with the first real spike (beside the readability item above): give the harness World's safe ground and hazard poll (or run the bot on `world.tscn`), and check the bot's HP through a spiked room.
- **No check stops a `down` arrival's stand cell from being a spike** — `RoomLoader.down_entry_cell()` picks the stand cell beside a bottom opening without looking at hazards. If that cell were a `^`, `Room.ground_below(&"down")` would fall back to the entry itself, in the spike, and the player would be returned there and hit again as each invulnerability ends.
  → **Owner: E4** — the first story that places real spikes adds a validator rule (a down exit's stand cell is never a hazard) with a firing sample and a near-miss in `test_room_loader`.
  → **Closed (Story 1.19 code review): `RoomLoader.validate()` refuses a hazard on a down exit's stand cell and on an up exit's entry cell, each with a firing sample and a near-miss in `test_room_loader`.**
- **Lurkers are "way too easy to dodge"** (sonlm, laptop feel check of Story 1.19, 2026-11-22, on the build where a hunting lurker's touch costs 2 HP instead of a death). Landing, Snuff or a cling in time always saves you by design (Pillar 2), and the hunt is 95 px/s with a 0.9 s telegraph.
  → **Owner: Story 1.30** — the CP2 kit playtest owns the feel defaults; try `lurker_hunt_speed`, `lurker_hunt_accel` and the lose-track time there (never the telegraph below `Spec.TELEGRAPH_MIN` or the escape guarantees), and check what Story 1.20's sensing rules change first.
  → Note (Story 1.20): sensing changed one thing for a lone player light: a hunt keeps sensing off screen (Q1). The M1 trace in tests/fixtures/lurker_trace_m1.json pins the rest.
- **The pogo squash is hard to notice** (sonlm, same check: "hard to notice, i don't think i see it"). Since Story 1.19 it eases back on the physics tick, so it does show through the 75 ms hitstop (`smoke_health`: scale.y 1.24 and 1.19 on the two ticks after a hit, where it was 1.0), but the stretch itself is small, (0.75, 1.3) easing at 12/s, about 0.25 s, on a 16 × 24 sprite.
  → **Owner: Story 1.30** — with the other feel defaults (the hit flash, the pogo shake): try a bigger stretch or a slower ease side by side on the laptop; it is a `MOTION` row, so not flash-capped.
- **A spike return can feel like "teleport back to start"** (sonlm, laptop feel check of Story 1.19, 2026-11-22: "Wju does it teleport back to start after falling"). The return goes to the last safe ground (D6), so jumping off a ledge straight onto spikes returns the player to that ledge, and with little upward movement in M2 (a 60 px jump, no climbing) that can be far above. sonlm kept the last safe ground over "the nearest clean floor on the side you came from" (option a).
  → **Owner: E4** — with the first real spike rooms: decide whether returns stay "last safe ground" or use designer-placed return points through a room (as Hollow Knight does), and lay spikes so a return never lands far from where the player fell.


## Deferred from: code review of 1-19-health-4-hp-and-the-damage-table.md (2026-11-22)

- **An `up` arrival whose straight fall ends on spikes is returned to mid-air above them** — `Room.ground_below(&"up")` falls back to the entry itself when the column below the top opening ends on a `^`. World seeds its safe ground with that, so a player who lands on those spikes before any floor tick is returned to the top opening and falls onto them again: one who does not steer loses 1 HP every 0.6 s. `t_spikes` avoids it (its `up` column lands on clean floor), and no real room has a spike. The item above for Story 1.22 covers the same fallback for the Ember Cache only.
  → **Owner: E4** — the first story that places real spikes adds a per-room rule in `tests/room_sweep.gd` (an `up` arrival's straight fall never ends on a hazard) with a firing sample and a near-miss, beside the return-rule item above.
- **Holding a direction into floor-level spikes costs 1 HP every 0.6 s** — probed on `t_spikes` at the review: from clean floor at x 70, holding right, the player is held at x ≤ 93.5 (the spike run starts at 96) and takes `damaged(1, spikes)` at ticks 16, 52, 88 and 124, dead at tick 125 (2.1 s). It follows from no knockback (D5), the return to the last safe ground (D6), which on a floor is a tick of walking away, and the return while invulnerable (Q2). sonlm (2026-11-22): leave it for now.
  → **Owner: E4** — with the return-rule item above, in the first story that places real spikes: decide there between safe ground kept a few pixels clear of a hazard, a short input hold after a return, or leaving it, with a laptop feel check.
- **A killing blow inside the white flash's gap shows no hit feedback** — the white hit flash shows at most once per second (Q1), and a dead player draws no blink, so a lethal hit under 60 ticks after the last white shows nothing on the sprite: the last of four back-to-back spike hits, or a lurker's second hit. sonlm kept it at the review (2026-11-22): a dim or a white there reaches 3.5 flashes/s, over the cap of 3. The gap now carries across a death (`Player.last_white_frame`, handed on by World).
  → **Owner: Story 1.29** — the death card is the killing blow's feedback; check on the laptop that a death reads at once with no flash on the sprite, and if the card's timing changes the 0.6 s respawn wait, update `RESPAWN_TICKS` in `test_fx`'s cap simulation.

## Deferred from: code review of 1-20-light-sensing-for-predators.md (2026-11-25)

- **A lurker on the notice edge flips between TELEGRAPH and rest with no rate limit** — a telegraph needs the lurker inside the notice rect on every tick (Q1), so a view that bobs across that edge restarts the telegraph each time: the eye snaps between the slit and its fade, on screen, 8 px inside the play area. Only `stir` is paced (0.35 s a step); `state` and the eye's alpha are not. M1 dropped a telegraph the same way, and `test_stir_pacing_edge` drives this flip every two ticks to pace `stir`. In play the view crosses the edge at the rate the player bobs, so it stays well under 3 a second; nothing holds it there.
  → **Owner: Story 1.27** — it draws the eye and glow at that same edge from `stir` and `state` and holds the cue to NFR8: check there whether the on-screen eye needs the same pacing (a short hold before a telegraph can restart, or a margin that differs going in and out), with a laptop look.
- **A hunting lurker swings through a light that stands still** — the hunt steers at full speed toward its target and turns at 220 px/s² only, so on a still decoy it overshoots and comes back: about ±21 px every 104 ticks, for as long as the light burns (the review's 1-D run of `lurker.gd:196-201`). With the player as the target a hit and its knockback ended the approach; nothing ends it on a flare or the cache.
  → **Owner: Story 1.23** — the flare is the first still light a lurker hunts: decide there whether it settles on the flare (slow down inside a few pixels) or the swing reads well as "worrying at it", with a laptop look.
- **The stir step, 0.35 s, is a first value** — `Lurker.STIR_STEP_TIME` (the GDD's Stirs line and `Spec.STIR_STEP` carry it) was chosen by sonlm at story creation (Q3) as presentation, "reviewed at the CP2 gate". The code, the GDD and the decision log all say so, and no ledger line did until this review.
  → **Owner: Story 1.30** — the CP2 kit playtest owns the feel defaults: with 1.27's eye and glow on screen, check that half-open at once and open 0.35 s later reads as a warning in time; a new value changes the GDD line, `Spec.STIR_STEP` and the const together, and stays at or over 1/3 s (NFR8: under 3 changes a second).
- **The edge cue draws only for a lurker off screen** — `stir` also rises for a lurker on screen in the 8 px strip (D3, confirmed by sonlm 2026-11-25), and it keeps falling by its clock through a telegraph (D9). Story 1.20's D9 leaves the rule to the drawing: the edge eye shows only while the lurker is outside `World.play_rect()`. The strip still feeds the flare-cost hatch and the stirring sound. The rule was written only in Story 1.20's file; the epic's 1.27 text does not carry it.
  → **Owner: Story 1.27** — put it in that story's acceptance criteria when the story is created, with a check that a telegraphing lurker on screen, its `stir` still falling, draws no edge eye.

## Deferred from: dev of 1-21-save-store.md (2026-11-25)

- **A saved anchor or station is not yet an entry World accepts** — `World._check_respawn_point()` (`game/scripts/world/world.gd`) holds a loaded respawn point to `RoomLoader.inspect(room).entries`, which lists only `spawn` and the exit sides. A save made at an anchor would load with one warning and start the dive at the start room.
  → **Owner: Story 1.24** — it makes anchor and station ids entries (`Room.entry_position()`): add them to `inspect().entries` in the same change, with a `smoke_world` case that a saved anchor point is kept (the story's D13).
- **A load or a new game made mid-session leaves the old room standing** — `Game.load_slot()` and `Game.new_game()` change `slot` and `dive` in place and build nothing; at boot World builds its first room afterwards, so nothing shows. Their first callers outside boot must rebuild the room (`World.enter_room()` or a respawn) after either. The title must also not count play time: World counts it on every frame it processes.
  → **Owner: Story 1.33** — the title screen is the first caller of `load_slot()` outside boot and the first screen shown while World runs.
- **A damaged or newer slot 1 can't be saved to** — `SaveStore.write_slot()` refuses a `CORRUPT`, `UNREADABLE` or `NEWER` slot, and only `Game.new_game()` (after `delete_slot()`) writes over one. Until the slot picker nothing calls it, so such a slot 1 plays from the defaults and every save fails with one warning and `save_failed`. Only dev builds exist until then.
  → **Owner: Story 1.38** — the slot picker brings overwrite and delete (`Game.new_game(n, tier)`, `Game.delete_slot(n)`), and its "Damaged" row reads `Game.store.read_slot(n).found`.
- **The read-back's call site has no failing test** — `SaveStore.verify_file()` is tested alone (a truncated file, text that isn't JSON, a missing file), but nothing can make `.tmp` come back short inside `_write()`, so a build that dropped the call there passes `test_saves`. Every other guard in the write was red-checked with a mutant.
  → **Owner: Story 1.39** — it puts `OS.is_userfs_persistent()` in front of the slot write and tests the failure states: give the store a seam there (a write function a test can swap for one that stores half the text) and add the case.
- **A failed `.bak` copy is seen only through `store_buffer()`'s result** — `SaveStore._copy()` does not read the `.bak` back, so a `.bak` cut short by a full disk is kept while the save goes on to replace the main file. The main file is whole either way; the cost is a bad backup if that main file is damaged later.
  → **Owner: Story 1.41** — it freezes save format v1 and closes E1's save work: decide there whether the `.bak` gets the same read-back as `.tmp`.
