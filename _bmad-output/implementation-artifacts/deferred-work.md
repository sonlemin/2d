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
- **A dev session meets the save** — `World._respawn_point()` reads `Game.dive`'s respawn point before `--room`'s start, and DevTools never writes it. From 1.21 a loaded respawn point beats `--room`, and a dev session (`--room`, `--chain`) records dev room visits (`SlotState.visit()`) and `best_chain` into the slot.
  → **Owner: Story 1.21** — the save store makes the respawn point and the slot save data; decide there what a dev session may write.
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
- **The Ember Cache's glow is a `BudgetLight` of rank CACHE** — and the perf run's cache stand-in (`game/scripts/dev/perf_run.gd` `CACHE_RADIUS`, 80 px) then reads its radius from the cache's `Tuning` value instead of its own const.
  → **Owner: Story 1.22** — it builds the Ember Cache and its light radius.
- **A flare's light is a `BudgetLight` of rank ALWAYS** — and the perf run's flare stand-in (`game/scripts/dev/perf_run.gd`, at the player's light radius, riding along) is then compared with a real thrown flare, which sticks where it lands.
  → **Owner: Story 1.23** — it builds Flare Toss and the flare.
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
- **The pogo shake is barely visible** — since the 1.16 rig fix it plays (`CameraRig.POGO_SHAKE` 2.5 px, decaying at `SHAKE_DECAY` 20 px/s, so about 0.125 s), and sonlm on the laptop: "pogo yes but just a bit, barely visible". The M1 value was kept as is; a stronger kick (more px, or a slower decay) is a presentation change, and with shake off it stays zero either way.
  → **Owner: Story 1.30** — the CP2 kit playtest reviews the feel defaults (hit flash, bank burst); try 2.5 against 4–5 px there, on the laptop, side by side with `--set=shake:false`.

## Deferred from: code review of 1-16-effects-accessibility-gate-and-flash-cap.md (2026-11-21)

- **Shake turned off while paused leaves the last offset on screen** — `game/scripts/world/camera_rig.gd` zeroes `_shake` and `offset` in `_physics_process` when `Fx.shake_on()` is false (Story 1.16 D7), but a paused tree runs no physics tick. If the setting turns off while the tree is paused mid-shake, the last random offset (up to 2.5 px) stays on screen until the first unpaused tick. New in 1.16, and unreachable today: nothing pauses the tree and only `--set` changes the setting. A fix: the rig listens to `Game.settings.changed` and zeroes at once when `Fx.shake_on()` is false.
  → **Owner: Story 1.36** — Options opened from Pause is the first place the shake setting can change while the tree is paused; fix and test it there.
- **The web first-frame stall is unsolved** — `docs/perf.md`: 562 ms (1.15) and 548 ms (1.16, with `Fx.warm_up()`) worst frame at 0.0 s in Firefox on the Intel iGPU. The 1.16 run can't say whether the warm-up helps: the review found its items were freed on a 0.05 s timer and could go undrawn after a slow frame (probed on 4.7.2: 0 drawn frames; the patched version counts frames and draws twice). sonlm's re-run on the patched build (20261121-af07203) measured 634 ms at 0.0 s, so a warm-up that is drawn does not remove it either. That run also had 30 frames over 20 ms and min 24 fps, against 5 and 2 frames and min 28 and 29 before; nothing in the patch runs after the third frame, so one run can't say whether that is noise. The stall is at 0.0 s, the load itself, which a warm-up in that same frame can't remove; it will sit behind the click-to-play gate (Story 1.33). (Story 1.17: the warm-up label now draws a real popup's `LabelSettings`, the same font, size and outline, so that earlier mismatch is gone.)
  → **Owner: Story 7.13** — the full performance pass re-measures the first frame on every target, with several runs each so the over-20-ms count can be told from noise; decide there whether the warm-up stays, what it must draw (the popup's own font and outline), or whether a loading frame behind the gate replaces it.
- **A pogo target that survives a hit plays no sparks** — FR38 "sparks on every pogo hit" holds today only because every pogo hit kills a crawler and its death calls `Fx.pop()` (Story 1.16 D6). The player's pogo itself makes no sparks, so the first pogo target with more than one hit of health breaks FR38 silently; no test checks sparks on a hit that doesn't kill.
  → **Owner: E4** — its creatures are the first new pogo targets (D6 names the creature dissolve); the story that adds one that can survive a hit adds the spark call on the hit and a smoke check for it.

## Deferred from: dev of 1-17-string-table-pixel-font-and-theme.md (2026-11-21)

- **Play-area text outline uses `TextStyle.PLACEHOLDER_SURFACE` (Cold violet), not the active zone's surface** — DESIGN's `components.text-outline.color` is the zone surface colour. Until `core/palettes.gd` exists, `Fx.popup()` outlines every popup in `#0d0b14` (zone-violet-0, the zone `m1_shaft` declares), so a popup in another zone gets the violet outline (Story 1.17 D6).
  → **Owner: Story 1.18** — it brings the palettes and the per-zone colours; replace the const with the active zone's surface and keep `TextStyle.play_text`'s cache keyed by colour pair.
- **Bank popup size: 8 px at every count** (sonlm, 2026-11-21; DESIGN's bank-popup row corrected in 1.17) — M1's 10 px from 5 links scaled the 8 px face by ×1.25 (uneven strokes in the render probe); the gutter chain number carries the long-chain read. A bigger popup, if ever wanted, is 16 px (an exact ×2), never 10.
  → **Owner: Story 1.26** — it owns and rebuilds the bank popup; keep it at 8 px at every count.
- **The window title isn't a string key** — `project.godot` `config/name` still reads "The Unbroken Chain (M1 prototype)", which shows in the desktop title bar and the web page title, outside the string table.
  → **Owner: Story 1.33** — the title screen shows the game's name; settle the shipped name and how the window title follows it there.
