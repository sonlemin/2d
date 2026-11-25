---
baseline_commit: c40e75f
---

# Story 1.20: Light sensing for predators

Status: done

**Type:** dev (with one human gate: sonlm's laptop look, Task 12) · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP2 Kit (1.16–1.30) · **Branch:** `feat/m2-e1`

## Story

As a player,
I want lurkers to sense light by one fair rule that only works on screen,
so that I always know what wakes them and I'm never hunted from the dark.

## Acceptance Criteria

1. **`rules/sensing.gd`: one pure rule for every predator.**
   - New `scripts/rules/sensing.gd`: `class_name Sensing extends RefCounted`, static functions only. It holds no state and names no `Node`, `Input`, `Engine`, `Game` or actor class (lint `rules_purity`). It takes plain values (`Vector2`, `float`, `Rect2`, `Dictionary`).
   - Constants, each with `##` unit, intent and source:
     - `NOTICE_MIN_RADIUS := 80.0` (GDD Lurker "≥ 80 px (4 links)");
     - `NOTICE_FACTOR := 1.6` (GDD Lurker "within radius × 1.6");
     - `SCREEN_MARGIN := 8.0` (M1 `lurker.screen_margin`; no GDD line: a margin can only shrink where a lurker notices, D3);
     - `STIR_REACH := 96.0` (GDD Lurker "within 96 px of the edge");
     - `KIND_PLAYER := &"player"`, `KIND_FLARE := &"flare"`, `KIND_CACHE := &"cache"`, `KINDS` (the three).
   - Functions, exactly these signatures (D2; they supersede the architecture's sample, which had one `can_sense()` with the rect):
     - `can_sense(light_pos: Vector2, light_radius: float, pred_pos: Vector2) -> bool`: `light_radius >= NOTICE_MIN_RADIUS` and `pred_pos.distance_to(light_pos) <= light_radius * NOTICE_FACTOR`. No screen test.
     - `notice_rect(play_rect: Rect2) -> Rect2`: `play_rect.grow(-SCREEN_MARGIN)`.
     - `can_notice(light_pos, light_radius, pred_pos, play_rect: Rect2) -> bool`: `can_sense(...)` and `notice_rect(play_rect).has_point(pred_pos)`.
     - `can_stir(light_pos, light_radius, pred_pos, play_rect: Rect2) -> bool`: `can_sense(...)`, **not** in `notice_rect(play_rect)`, and inside `play_rect.grow(STIR_REACH)`. So every spot within 96 px of the play area either notices or stirs, with no dead band (D3).
     - `pick_target(lights: Array[Dictionary]) -> int`: each entry is `{kind: StringName, radius: float, pos: Vector2}`. It returns the index of the largest radius; on an exact tie a non-player light beats the player; between two non-player lights the earlier index stays. It returns −1 for an empty array.
   - `tests/test_sensing.gd` (pure; expected values from `Spec`, never from `Sensing`'s consts) covers:
     - the radius floor: 79.9 px never senses, even at distance 0; 80 px does;
     - the reach: at radius 100, distance 159 senses, 160 senses (the limit is inclusive), 161 does not;
     - the notice rect, on each of its four edges, with samples 0.5 px inside and 0.5 px outside. One exact-edge sample per axis documents `Rect2.has_point()`'s half-open rule (probed on 4.7.2: the left and top edges count, the right and bottom edges do not);
     - stir: 0.5 px inside the notice rect notices and doesn't stir; 0.5 px outside it stirs (inside the 8 px band, and just outside the play rect); 95.5 px outside the play rect stirs; 96.5 px does not; a light under 80 px never stirs;
     - `pick_target`: the largest radius; a player/flare tie goes to the flare and a player/cache tie to the cache; a flare/cache tie keeps the earlier; empty → −1; one entry → 0.
   - `Spec` gains `NOTICE_FACTOR := 1.6` and `STIR_REACH := 96.0`, each on one line with its `## GDD` citation (lint `spec_citation`, `uncited_consts`).

   (FR17, FR18, FR20, AR29; D2, D3)

2. **`actors/light_source.gd`: every sensed light is a `LightSource`, and the player carries one.**
   - New `scripts/actors/light_source.gd`: `class_name LightSource extends Node2D`.
     - `@export var kind: StringName = Sensing.KIND_PLAYER`. `_ready()` asserts `kind in Sensing.KINDS` and joins group `light_source`.
     - `radius() -> float`, the **rule** value predators read. When `radius_fn` is valid it returns `radius_fn.call()`; otherwise it returns `fixed_radius`. It is never the shown (eased, kicked) radius.
     - `var radius_fn := Callable()`: the player sets it to `chain.light_radius`.
     - `var fixed_radius := 0.0`: in px, for a light with a set radius (a flare's pre-toss radius in 1.23, the cache's `Tuning` value in 1.22, a test's stand-in).
     - `extinguish()`: leaves group `light_source` for good, so no predator senses it again (a dead player, D5). `is_lit() -> bool`: inside the tree and in the group. `static func live(s: Object) -> bool`: `is_instance_valid(s)` and `s.is_lit()`.
     - `sensed() -> Dictionary`: `{kind, radius = radius(), pos = global_position}`, the plain entry `Sensing` reads.
     - **It drives its light (D4).** `light: BudgetLight` is its child `Light` if one exists, else null (a test stand-in has none). Each physics tick, while lit, it eases a shown radius toward `radius()` at `LIGHT_LERP` (10/s, moved from `player.gd`). It then sets `light.texture_scale = shown / (light.texture.get_width() / 2.0)`. `kick(px)` adds to the shown radius (the pogo flare). It never writes `enabled` or `visible`: the light budget alone decides light or sprite (lint `raw_light` is untouched, and `test_light_budget` still sees one BudgetLight per scene light).
   - **The player scene:** `player.tscn` gains `LightSource` (a `Node2D` with this script, kind `player`) at the player's origin, and the existing `Light` (a `BudgetLight`, rank ALWAYS) moves under it unchanged: `Player/LightSource/Light`.
   - **The player script:**
     - `@onready var light_source: LightSource = $LightSource` (public);
     - `_ready()` sets `light_source.radius_fn = chain.light_radius`;
     - `_update_light()`, `_shown_radius`, `_light`, `LIGHT_LERP` and `LIGHT_TEXTURE_HALF` go from `player.gd`, and the pogo hit calls `light_source.kick(LIGHT_KICK)` (`LIGHT_KICK` stays a player const);
     - `die()` calls `light_source.extinguish()`;
     - `light_radius()` stays and still returns `chain.light_radius()`.
   - **Tests for the light itself** (in `smoke_lurker`, D4):
     - `radius()` equals `chain.light_radius()` through a pogo hit, a Snuff and a cling, and still on the tick right after `kick()` (the shown radius moved, the rule value didn't);
     - after `die()`, the light is not in group `light_source` and `is_lit()` is false;
     - a light the budget demoted (`BudgetLight.set_demoted(true)`) stays demoted over 10 ticks of easing (the harness has no `LightBudget`, so only `LightSource` could undo it);
     - the shown radius starts at `radius()` on the first tick, never eased in from 0 at a spawn. Children run `_ready()` before their parent, so `radius_fn` is set after `LightSource._ready()`: snap the shown radius on the first physics tick, not in `_ready()`.
   - **Paths that name `Light`** become `LightSource/Light`:
     - `scripts/dev/perf_run.gd:160`;
     - `tests/smoke_perf.gd:161`;
     - `tests/test_light_budget.gd:326`;
     - `tests/screenshot.gd:47`. It also used `Player.LIGHT_TEXTURE_HALF`; read the texture width instead.
   - **Checks on a light's parent** follow the move: `tests/smoke_perf.gd:333` filters on `n.get_parent() is Player`, which is now a `LightSource` (accept a `LightSource` parent whose own parent is the Player). `smoke_perf.gd:135` (`get_parent() is Lurker`) is unchanged.

   (FR5, AR28; D4, D5)

3. **The lurker FSM reads lights only through `LightSource` + `Sensing` (D6, the table below).**
   - `lurker.gd` keeps `enum State { IDLE, TELEGRAPH, HUNT, RETURN }`, one `match`, one `_enter(state)` and a public `state`. It gains:
     - a public `target: LightSource`;
     - public `stir: int` and `stirring: bool` (AC5);
     - a public test seam `force(next: State, source: LightSource = null)`, which sets `target = source`, then calls `_enter(next)`.
   - Its own `NOTICE_MIN_RADIUS`, `NOTICE_FACTOR`, `SCREEN_MARGIN`, `senses()`, `_on_screen()` and `_player` go. It never looks up group `player` (a new lint rule, AC7).
   - Public wrappers, the exact calls the FSM makes, which tests and overlays use:
     - `notices(source: LightSource) -> bool`: `Sensing.can_notice(source.global_position, source.radius(), global_position, rect)`, where `rect` is the `world` node's `play_rect()`. No `world` node (or one without `play_rect`) means no screen, so it never notices (as `_on_screen()` does today).
     - `senses(source: LightSource) -> bool`: `Sensing.can_sense(...)`, for the hunt (Q1).
     - `stirs_for(source: LightSource) -> bool`: `Sensing.can_stir(...)`.
     - Each returns false for a source that is not `LightSource.live()`.
   - Each physics tick the lurker builds its candidate list from `get_tree().get_nodes_in_group(&"light_source")`. It keeps the live ones, filters them with the state's rule, and calls `Sensing.pick_target()` on their `sensed()` entries. The rows of D6's table are the behaviour.
   - **`monitorable` has one rule** (D7): `_harmful(sensed_now: bool) -> bool` returns `state == HUNT and sensed_now and LightSource.live(target) and target.kind == Sensing.KIND_PLAYER`. Each tick's update assigns `monitorable` from it. `_enter()` assigns `_harmful(true)`, so a forced HUNT at the player is lethal until its first tick re-senses, exactly as M1's `_enter(HUNT)` was. A lurker hunting a flare or a cache is never `monitorable`.
   - **Telegraph and hunt numbers are unchanged:** 0.9 s (`lurker_telegraph_time`, ≥ `Spec.TELEGRAPH_MIN`), 95 px/s through walls, the ×2 brake on losing the scent, 0.6 s wait, return home. Presentation (eye pulse, shiver, eye open, glow energy) is unchanged.
   - **A lone player light behaves as before** (D8). With only the player's light, every M1 guarantee in `smoke_rooms`, `smoke_world` and `smoke_health` passes with only the seam change (`force()` in place of `_enter()`), with no threshold or expected value touched. The one deliberate difference is Q1's: a hunt keeps sensing off screen. A trace recorded on the baseline tree before any edit (Task 1) must match the new code tick for tick on an all-on-screen scenario.

   (FR17, FR19, FR20, FR21, AR30, AR31; D6, D7, D8)

4. **Target choice and retargeting (FR16, FR21), proven with a stand-in `LightSource`.**
   - Among the sensed lights the lurker takes `Sensing.pick_target()`'s choice: the largest radius, a tie going to the non-player light.
   - **A non-player light to the player** (in TELEGRAPH or HUNT, and also a new life's light, which is a different node) re-enters `TELEGRAPH` for the full `lurker_telegraph_time`, and it is never `monitorable` until that telegraph ends.
   - **The player to a non-player light** switches the target with no telegraph: HUNT stays HUNT, and `monitorable` turns false on that tick.
   - **Identity is the node, never the kind** (D6).
   - `tests/smoke_lurker.gd` (new; fixture room `tests/rooms/sensing/t_sensing.txt`) proves each switch with a stand-in: a `LightSource` of kind `flare` with `fixed_radius` and no `Light` child, added under the room with `room.spawn()`-style ownership (a child of the room).

   (FR16, FR21, AR29; D6)

5. **Off-screen stirring: `stir` rises while the condition holds, and it never leads to a hunt.**
   - `stirring` is true on a tick when the lurker is in IDLE or RETURN and some live light `stirs_for()` it. It is false in TELEGRAPH and HUNT.
   - `stir` (0 closed, 1 half, 2 open) moves one step toward its goal **at most once per `STIR_STEP_TIME`, in every state, with no exception** (Q3, sonlm: 0.35 s, a lurker const, presentation reviewed at 1.30). The goal is 2 while `stirring`, else 0, so in TELEGRAPH and HUNT it falls by the same clock. The first step from 0 happens on the first stirring tick if no step happened in the last `STIR_STEP_TIME`.
   - The step limit holds the value Story 1.27's eye and glow draw to at most 1 / 0.35 ≈ 2.9 changes per second, under `Spec.FLASH_HZ_MAX`, whatever the condition and the state do (D9). A test toggles the condition every tick for 3 s, both by the light and across the notice-rect edge, and counts at most `Spec.FLASH_HZ_MAX` changes of `stir` in every 60-tick window.
   - A stirring lurker stays IDLE (or keeps returning) and never telegraphs or hunts. `smoke_lurker` proves the guarantee: from a stirring start, every HUNT of the player is preceded by at least `Spec.TELEGRAPH_MIN` of TELEGRAPH, spent inside the play rect on every tick (Q1). Story 1.27 adds the edge cue and repeats this check with its drawing (AR50).
   - Nothing is drawn for stirring in play in this story. Story 1.27 draws the cue, and E3 plays the sound. Only overlay 2 shows it (AC6).

   (FR18, AR30; D3, D9)

6. **Overlay 2 reads `Sensing`, shows every light and every predator, and stops drifting** (three ledger items, D10).
   - `overlays.gd` reads `Sensing.NOTICE_MIN_RADIUS`, `NOTICE_FACTOR` and `SCREEN_MARGIN`; nothing reads them from `Lurker` (they no longer exist there). `light_marks(r)` keeps its shape and uses `Sensing`.
   - **Every live `light_source`** gets mode 2's marks on a child of its own (`DevLightMarks`, engine-interpolated with it, as the player's marks are today):
     - its radius ring;
     - its reach ring (dashed and dim below the notice radius);
     - a label `"<kind> %d px"`.
     - The player's light also keeps the HP line (Story 1.19 D8).
   - **Every predator** gets its label on a child of its own (`DevPredatorMarks`), so it rides the predator's interpolated sprite: `"IDLE"`, `"TELEGRAPH flare"`, `"HUNT player"` (state plus target kind), and `" stir N"` while `stir > 0`. This fixes the ledger's "labels in WorldMarks, at most 1.6 px off".
   - **A sense line** from each TELEGRAPH or HUNT predator to its `target` is drawn on the predator's child. Its far end is the target's position minus the predator's, both interpolated by hand: overlays record each predator's and each light's previous and current tick positions in a `_physics_process` that runs after the actors (DevTools' priority, 100) and blend them with `Engine.get_physics_interpolation_fraction()`. This fixes the ledger's "far end a tick of the fall off". It is drawn only when the target is live.
   - **A stirring predator off screen** also gets a small marker (magenta, never the reserved red) at the play-rect edge on screen, level with it and clamped inside, labelled `"stir N"`. This is a debug stand-in until 1.27's cue, so the laptop look can see stirring.
   - Nothing pulses or blinks; colours stay off `#ffd27a` and `#d9473f` (NFR9).
   - Mode 1's dashed notice rect reads `Sensing.notice_rect(play)`.

   (AR54; D10)

7. **A lint rule keeps actors off the player group.**
   - `test_lint` gains rule `light_query`: in `actors/`, a lookup of group `player` (`get_first_node_in_group` / `get_nodes_in_group` / `is_in_group` with `"player"` or `&"player"`) fires. Its message: "predators sense light through LightSource + Sensing (AR28, AR29)".
   - It gets one firing sample and two near-misses in the samples table: a `light_source` lookup and `player.gd`'s own `add_to_group("player")` do not fire.
   - `allow` is empty; `dev/` and `world/` are outside its `only`.

   (AR29: "Never call `get_first_node_in_group("player")` to sense light"; D11)

8. **Done means green, checked, documented and looked at.**
   - `cd game && ./run_tests.sh` gives `== ALL GREEN`, and the `smoke_rooms` guarantees stay green.
   - Every new check is red-checked (D12).
   - The three ledger items owned by 1.20 are closed, and new items carry owners (D13).
   - The docs are updated (D14).
   - sonlm's laptop look is recorded (Task 12). Until then the report says "tests green; needs a look on the laptop".

## Tasks / Subtasks

- [x] **Task 1: Baseline and the M1 trace (AC: 3, 8).** Do this **before editing any game file**.
  - [x] At story creation on `c40e75f` (2026-11-22), `cd game && ./run_tests.sh` gave `== ALL GREEN (29 tests)`, 2005 `ok`. Re-run it and record the result in the Dev Agent Record.
  - [x] Record the M1 trace (D8). Write a throwaway script outside the repo that builds `m1_shaft` with `RoomHarness` and picks the second lurker from the top by position. It then holds the player with its physics off at chain 10 at fixed positions, all with the lurker inside `play_rect().grow(-8)`:
    - 100 px beside it for 1.5 s (a telegraph, then a hunt);
    - then `chain.break_chain()` (the light drops; the lurker loses the scent);
    - then 1.5 s more (the wait, then the return).
    - Log per tick `[state, monitorable, roundi(pos.x), roundi(pos.y)]`.
    - Run it through the runner (`godot --headless --path game res://tests/runner.tscn -- <script>`): under `--script`, anything that touches `Game` fails to compile.
  - [x] Save it as `game/tests/fixtures/lurker_trace_m1.json` with a header field naming the commit (`c40e75f`) and the scenario. `smoke_lurker` replays the same scenario on the new code (with `force()` never used: the lurker notices on its own) and compares tick for tick. Read the fixture with `JSON.new().parse()` (never `JSON.parse_string()`, which prints engine `ERROR:` lines).
- [x] **Task 2: `rules/sensing.gd` + `tests/test_sensing.gd` + Spec (AC: 1).**
  - [x] Write `Sensing` as AC1. Header `##`: the one rule for every predator (Pillar 2: notice only where the telegraph is seen; the hunt follows the light, Q1); a pure helper, so `test_sensing` tests the boundaries without a scene.
  - [x] Add `Spec.NOTICE_FACTOR` and `Spec.STIR_REACH`, one line each with the GDD quote.
  - [x] `test_sensing.gd`: the AC1 cases. Expected numbers come from `Spec` (`Spec.NOTICE_MIN_RADIUS`, `Spec.NOTICE_FACTOR`, `Spec.STIR_REACH`). The margin is the one value with no GDD line: read `Sensing.SCREEN_MARGIN`, but first check `Sensing.SCREEN_MARGIN >= 0.0` and that `notice_rect(r)` is inside `r` (a margin may only shrink the notice region, D3).
  - [x] Also check `Sensing.NOTICE_MIN_RADIUS == Spec.NOTICE_MIN_RADIUS`, `NOTICE_FACTOR == Spec.NOTICE_FACTOR` and `STIR_REACH == Spec.STIR_REACH`. These are exact, because the GDD gives exact values. `smoke_rooms._check_tuning()`'s `Lurker.NOTICE_MIN_RADIUS` line reads `Sensing` now.
- [x] **Task 3: `actors/light_source.gd` and the player (AC: 2).**
  - [x] Write `LightSource` as AC2. Header `##`: AR28; `radius()` is the rule value, the shown radius is presentation; it drives its BudgetLight's size and never its `enabled` (the budget's, Story 1.12); `extinguish()` is for a death (D5).
  - [x] `player.tscn`:
    - add `LightSource` (Node2D, `light_source.gd`, `kind = &"player"`, no offset);
    - reparent `Light` under it with every property unchanged (colour, energy 1.4, texture, `texture_scale`, the BudgetLight script, `rank = 0`);
    - re-save in the editor or by hand with the same `ext_resource` ids;
    - commit the new `.gd.uid`.
  - [x] `player.gd`: as AC2. The pogo's `_shown_radius += LIGHT_KICK` (line 251) becomes `light_source.kick(LIGHT_KICK)`. Update the header line "Pogo hits feed the ChainState, which drives … Chain-Light (light radius)" to name `LightSource`.
  - [x] Update the four `Light` paths (AC2). In `perf_run.gd` keep the stand-ins as plain BudgetLights: they stay lights only and wake no lurker (D13; 1.22 and 1.23 replace them with the real cache and flare, which are LightSources). Change its header comment from "there is no LightSource until 1.20" to say that.
  - [x] **Q1 changes `perf_worst`:** hunters that trail out of view now keep hunting while in reach. `perf_run.gd`'s `PATH_SPEED` comment ("hunters trail and fall away") still holds, since they fall out of reach, but check it. If `smoke_perf`'s counts or the perf summary move, report the numbers to sonlm; never retune the path or the lurker to restore them.
  - [x] `World._retire_player()`'s comment ("out of groups `player` / `light_source` now") stays true: the LightSource is a child of the removed Player. Leave it.
- [x] **Task 4: The lurker (AC: 3, 4, 5).**
  - [x] Rewrite `_physics_process` from D6's table. Keep the presentation code (`_update_look`, the eye pulse, the shiver) and the movement code (accel, brake ×2, return speed) as they are.
  - [x] Delete the M1 D6 block that refetches `_player`. D6 is now row T1/H1: the target is not live → RETURN at once.
  - [x] `force()`, `notices()`, `senses()`, `stirs_for()`, `_harmful()`, `target`, `stir`, `stirring`, `STIR_STEP_TIME` (AC3, AC5).
  - [x] Header `##` rewrite: it senses light through `LightSource` + `Sensing`; it notices only on screen; it hunts while it senses (Q1); it retargets per FR16/FR21; it stirs off screen.
  - [x] The comment "The sensing rule stays here until Story 1.20" goes.
  - [x] Optional, cheap: one guarded log line per state change: `if Log.enabled(Log.LURKER): Log.debug(Log.LURKER, …)`. Nothing unguarded in the tick.
- [x] **Task 5: Migrate every caller in one change (AC: 3, 6; D8).** None of these may outlive the lurker edit (the debug build won't compile):
  - [x] `scripts/dev/overlays.gd`: `Lurker.NOTICE_FACTOR` / `NOTICE_MIN_RADIUS` / `SCREEN_MARGIN` (lines 274, 326, 361, 363) and `p.senses(player)` (line 337) move to `Sensing` and `notices()`.
  - [x] `tests/smoke_rooms.gd`:
    - `lurker.senses(_player)` becomes `lurker.notices(_player.light_source)` (lines 266, 274, 279, 291, 295, 304);
    - `Lurker.NOTICE_*` and `SCREEN_MARGIN` become `Sensing.*` (lines 162, 276, 287, 329, 353);
    - each `lurker._enter(Lurker.State.HUNT)` / `TELEGRAPH` (lines 382, 387, 495, 573, 623) becomes `lurker.force(state, _player.light_source)`.
  - [x] `tests/smoke_health.gd`: `l._enter(Lurker.State.HUNT)` (lines 275, 336, 366) becomes `force(HUNT, p.light_source)`. `test_lurker_harmless`' IDLE, TELEGRAPH and RETURN go through `force(s, p.light_source)`, and its `_enter(IDLE)` resets go through `force(IDLE)`.
  - [x] `tests/smoke_world.gd` `test_hunt_over_death` (line 323): `c.force(Lurker.State.HUNT, p.light_source)`. Its check, "one frame after the death the lurker drops the hunt", must pass unchanged. It is now row H1 (the target was extinguished).
  - [x] `tests/smoke_dev_tools.gd:723`: `lurker.senses(p)` becomes `lurker.notices(p.light_source)`.
  - [x] `grep -rn "senses(\|NOTICE_\|SCREEN_MARGIN\|_enter(Lurker" game/` is empty outside `sensing.gd` and `lurker.gd`, and every hit inside them is the new code.
- [x] **Task 6: `tests/smoke_lurker.gd` + `tests/rooms/sensing/t_sensing.txt` (AC: 3, 4, 5).**
  - [x] **The fixture room.** Header comment: "Story 1.20 sensing test room. Not a level." It is 22 columns wide (spine width, so the play rect covers it sideways), about 40 rows tall (so the camera scrolls and a lurker can sit above or below the view), with:
    - one in-wall `L` on the left wall about 12 rows down;
    - `P` on a ledge near the bottom, and open air between them;
    - no crawlers;
    - exits as `t_spikes` has them (self-loops), only if `RoomLoader.validate()` needs them.
  - [x] Load it with `RoomLoader.add_root("res://tests/rooms/sensing")` and `RoomHarness.build(self, &"t_sensing")`.
  - [x] Drive the player with its physics off, placing it by hand, and the camera with `cam.snap()` after each placement, so the play rect is exact.
  - [x] Cases (each prints `ok`/`FAIL`, picks nodes by position, and frees what it spawns):
    1. **The M1 trace** (Task 1): replay it, and match every tick (state, monitorable, position rounded).
    2. **Target choice:** with the player (chain 10, ~110 px) and a flare stand-in at 120 px both noticed, the lurker telegraphs at the flare (`target.kind == &"flare"`), then hunts it, and is never `monitorable` on any tick of that telegraph or hunt (the player's poll reads `monitorable` itself, so that is "no damage"; `smoke_health` proves the poll). A tie (the stand-in's `fixed_radius` = the player's `radius()`) goes to the flare.
    3. **Flare → player:** while it hunts the flare, drop the stand-in's `fixed_radius` to 60 (under the notice radius). On the next tick the state is TELEGRAPH at the player, and it holds TELEGRAPH for at least `ceil(Spec.TELEGRAPH_MIN × 60)` ticks (to within one, as `smoke_rooms` counts) with `monitorable` false throughout, then HUNT and `monitorable`.
    4. **Player → flare:** while it hunts the player, add a stand-in at 130 px radius in reach. The same tick shows HUNT with `target.kind == &"flare"` (never a TELEGRAPH tick) and `monitorable` false.
    5. **The light went out:** a stand-in `queue_free()`d while it is the hunted target gives RETURN on the next tick (not HUNT, not TELEGRAPH). A player `die()` while hunted does the same, and an IDLE lurker never notices a dead player's light (the light is extinguished, though the player is still in the tree).
    6. **Stirring:** player at chain 20 near the lurker's wall, the lurker 40 px above the play rect. Premise: it is outside `play_rect()` and within the reach (√(dx² + dy²) ≤ 138.4 × 1.6 ≈ 221 px). It stays IDLE; `stirring` is true; `stir` is 1 on the first tick and 2 after `STIR_STEP_TIME`; it never enters TELEGRAPH over 2 s. Inside the 8 px band (on screen, not in the notice rect), it stirs and doesn't notice. The 96 px limit itself is `test_sensing`'s: with the camera centred on the player, the reach (≤ 221 px) minus half the view (135 px) is at most 86 px, so no spot in a spine room is in reach and 96 px out.
    7. **Stir pacing (D9):** two runs of 3 s each, counting `stir` changes in every 60-tick window (at most `Spec.FLASH_HZ_MAX`):
       - by the light: the player at chain 0 (never sensed) and a flare stand-in beside the off-screen lurker, its `fixed_radius` toggled between 100 and 60 every tick (the camera never moves);
       - across the edge: the player bright and in reach, the lurker's position set 1 px either side of the notice rect's edge on alternate ticks, so it flips between noticing (TELEGRAPH) and stirring (back to IDLE or RETURN).
    8. **Stir to hunt (the guarantee):** from a stirring start, scroll the camera so the lurker enters the notice rect. Record every tick until the first HUNT. The HUNT comes after at least `Spec.TELEGRAPH_MIN` of TELEGRAPH, the lurker is inside `play_rect()` on every one of those ticks, `stirring` is false from the first TELEGRAPH tick, and `stir` reaches 0 within two steps.
    9. **Q1, off screen:** a HUNT lurker whose target is sensed but which has left the play rect keeps hunting (still HUNT and `monitorable` after 0.3 s). A TELEGRAPH lurker that leaves the notice rect drops to IDLE or RETURN on that tick.
    10. **Q2, re-sense in the wait:** HUNT at the player, then the light under 80 px for 0.3 s (under the 0.6 s wait), then back. The lurker is HUNT and `monitorable` again on the next tick, with no TELEGRAPH (M1 behaviour, kept).
    11. **No world node:** with the stub removed from group `world`, a lurker never notices (the AR20 fallback).
- [x] **Task 7: Overlays (AC: 6).**
  - [x] Move the player's marks code into a per-light version, plus the per-predator label child, plus the hand-interpolated sense line and the stirring edge marker, as AC6.
  - [x] Keep `light_marks()`, `hp_text()` and `play_rect_on_screen()` public and pure.
  - [x] `smoke_dev_tools`:
    - its mode-2 tests (lines 699–767) pin today's drawers: `ov.player_marks` (a child of the player, lines 733, 745, 758, 767) and the `_draws` keys `"player"` and `"world"` (line 740, "lurker labels in the world"). They move with AC6: the player's marks now sit on its `LightSource`, and the lurker labels sit on `DevPredatorMarks`. Rewrite these checks to the new drawers, keeping what each proves (marks follow the live player across a respawn; leaving mode 2 frees them);
    - it still draws with no error;
    - with a flare stand-in present, mode 2 puts a `DevLightMarks` child on both the player's and the stand-in's `LightSource`, and a `DevPredatorMarks` child on each lurker;
    - leaving mode 2 frees them all;
    - `light_marks()` agrees with `Sensing` at 79.9 and 80.
  - [x] The steadiness itself can only be judged on the laptop (Task 12).
- [x] **Task 8: Lint (AC: 7).** Add `light_query` with its samples. Confirm `rules_purity` and `core_layer` stay quiet on `sensing.gd` (it names no Node, no Game, no actor class) and that the lint passes on the new `lurker.gd`.
- [x] **Task 9: Red-checks (AC: 8; D12).** Break each once, see `FAIL`, restore, and list them in the Completion Notes.
- [x] **Task 10: Docs and ledger (AC: 8; D13, D14).**
- [x] **Task 11: Full run.** `cd game && ./run_tests.sh` → `== ALL GREEN`; record the counts. Then `tools/export.sh` → `BUILD OK` (the web debug smoke boots with no `console.error`).
- [x] **Task 12: HALT for sonlm: the laptop look (AC: 8). Human gate.**
  - [x] Hand sonlm the build lines (memory: laptop build-look commands).
    - **Web debug** (`?room=m1_shaft`, backquote to overlay 2) for the overlay and stirring.
    - **Windows** release for a plain run.
  - [x] Questions:
    1. Does overlay 2 stay steady while falling: the labels on the lurkers, the sense line's far end, the light rings? (Ledger item from 1.12.)
    2. Do the `stir N` markers show while a lurker sits just above or below the view?
    3. Do lurkers feel the same as before when you play plainly? The one intended change is Q1: a hunt keeps going off screen.
    4. Anything that feels unfair?
  - [x] **HALT.** Record the answers verbatim in the Dev Agent Record. A failure becomes a ledger item for Story 1.30 (feel) or Story 1.27 (the cue), unless sonlm asks for a change now.

### Review Findings

Code review 2026-11-25 over `6dacb7d..` the working tree on `8eaf14a` (commit `84df0b7` plus the uncommitted Task 12 notes; Blind Hunter, Edge Case Hunter, Acceptance Auditor; 42 raw findings). The suite on that tree is `== ALL GREEN (31 tests)`, 2120 `ok`. No acceptance criterion is broken in game code, and no reviewer found a way to be hurt without a telegraph. The findings are two rules that need sonlm's call, one small FSM fix, weak or missing tests, and doc drift. sonlm answered both decisions (the recommended option each time) and chose "apply every patch"; all are applied, with eight red-checks, and the export run found one more (the last patch below). After the patches: `== ALL GREEN (31 tests)`, 2142 `ok`; `tools/export.sh` **BUILD OK**. Four probes ran on 4.7.2 headless (a scratch script through `tests/runner.tscn`):

- **Velocity through a retarget telegraph (confirmed).** A lurker hunting a flare stand-in at 95 px/s, retargeted onto the player (row H3), stands still for the 54-tick telegraph and then starts the hunt at 95 px/s on the old heading (velocity (81, −49) with the player at heading (0.94, 0.34)).
- **Row H3 off screen (confirmed).** A lurker hunting a decoy 40 px above the play rect, when the player's light passes the decoy's (138.4 px against 120 px), is in TELEGRAPH for one tick off screen and then rests, although it still senses the decoy.
- **The cost of a lurker tick (measured).** In `perf_worst` (10 lurkers) one lurker tick takes 18 µs of script time, 0.18 ms for all ten. The per-tick arrays and group lookups are not a cost.
- **A freed object passed to a typed parameter (confirmed).** It is a script error on 4.7.2 ("The Object-derived class of argument 1 (previously freed) is not a subclass of the expected argument class"), so the untyped `live()`, `notices()`, `senses()` and `stirs_for()` are right and AC2/AC3's typed signatures could not be built.

- [x] [Review][Decision] A lurker hunting a decoy off screen drops it when the player's light becomes the largest — Row H3 picks with `senses` (no screen test) and enters TELEGRAPH; on the next tick nothing is noticed off screen, so row T2 sends it home. It spends one tick in TELEGRAPH where it can't be seen (the GDD: "The lurker must stay on screen for every tick of it"), and the decoy stops working the moment the player outshines it, although the lurker still senses it. Safe for the player either way. D6 has no row for it. It can't happen until flares exist (1.23): today the only light is the player's. Options: (a) off screen, keep hunting the decoy: H3 fires only when the lurker notices the player, otherwise it goes for the largest non-player light it senses; (b) keep it as built (it goes home), and say so in D6 and the GDD; (c) leave it to Story 1.23 with a ledger line. (Blind + Edge; probed) [game/scripts/actors/lurker.gd:181-184] **sonlm: (a), keep chasing the flare.** Applied: `Lurker._hunt_pick()`, `test_off_screen_decoy` (1 s on the decoy off screen, never TELEGRAPH, never monitorable; on screen a full telegraph inside the notice rect, then a harmful hunt), D6 row H3, the GDD's Retargeting line, the decision log.
- [x] [Review][Decision] The three calls made at story creation are still unconfirmed — "The 8 px band stirs", "stirring runs in RETURN as well as IDLE" and "a telegraph switching between two decoys keeps its timer" are built and tested (the third has no test, see below), but the decision log says "No GDD change until sonlm confirms them", and nobody owns the confirmation. The GDD's Stirs line still says "just off screen" only. Options: (a) confirm all three, and the GDD's Stirs line and the decision log say so; (b) veto one or more (which?); (c) leave them open until the CP2 playtest, with a ledger line owned by Story 1.30. (Auditor) [_bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/decision-log.md] **sonlm: (a), confirm all three.** Applied: the GDD's Stirs line (the 8 px strip, a lurker on its way home) and Retargeting line (decoy to decoy keeps the timer), the decision log, `game-architecture.md`.
- [x] [Review][Patch] A hunt that follows a retarget telegraph starts at the old hunt's speed and heading: `_enter()` zeroes `_velocity` only for RETURN, and row H3 goes HUNT → TELEGRAPH → HUNT. Before this story a telegraph was reached only from IDLE or RETURN, so every hunt began from rest. Zero `_velocity` on entering TELEGRAPH, and check it in `test_target_choice` (velocity zero on the first HUNT tick's entry). (Edge; probed) [game/scripts/actors/lurker.gd:247-257]
- [x] [Review][Patch] `LightSource.kind` defaults to `player`, the one kind that makes a hunt harmful: a flare or cache built in code that forgets `kind` is a decoy that damages, and the `_ready()` assert accepts it. Default to no kind (`&""`), so a debug build asserts and a release build treats it as a harmless non-player light; `player.tscn` already sets `kind = &"player"`. It departs from AC2's literal default. Add a `test_light_budget`-style check that the player scene's `LightSource` is kind `player`. (Blind + Edge) [game/scripts/actors/light_source.gd:17]
- [x] [Review][Patch] The three telegraph-floor checks pass one tick short: `held + 1 >= _floor_ticks()` and `tele.size() + 1 >= _floor_ticks()` accept 44 ticks (0.733 s) against `Spec.TELEGRAPH_MIN` 0.75 s. Here the first TELEGRAPH tick is observed, so the count is exact and needs no allowance (unlike `smoke_rooms`, whose start may be a frame unseen). Drop the `+ 1` and red-check with a 44-tick telegraph. (Blind + Edge) [game/tests/smoke_lurker.gd:324, 351, 540]
- [x] [Review][Patch] The stir step is compared against itself: both `step` values come from `Lurker.STIR_STEP_TIME`, so any step time passes, and only the 3/s ceiling is independent. The GDD's Stirs line now says "fully open 0.35 s later". Add `Spec.STIR_STEP := 0.35` with that citation and compare to it. (Blind + Edge + Auditor) [game/tests/smoke_lurker.gd:444, 543; game/tests/spec.gd]
- [x] [Review][Patch] The pogo's `light_source.kick(LIGHT_KICK)` is not tested: `test_light_source` calls `chain.add_hit()` and `ls.kick()` by hand, so deleting `player.gd:251` fails nothing. Call `_p._on_pogo_hit()` there instead, and check the shown radius rose and `radius()` is still the chain's. (Blind + Auditor) [game/tests/smoke_lurker.gd:222-223]
- [x] [Review][Patch] AC4's "identity is the node, never the kind" and row T4 have no test: every retarget case has one player light and one flare, so T3/H3 comparing kinds would pass. Add (a) a hunt of one player-kind light switching to a second, larger player-kind stand-in: a full telegraph; (b) row T4: a telegraph at one decoy switching to a larger decoy keeps its timer (HUNT on the same tick as without the switch). (Blind + Auditor) [game/tests/smoke_lurker.gd]
- [x] [Review][Patch] Lint `light_query` sees only the literal lookup (`get_first_node_in_group` / `get_nodes_in_group` / `is_in_group` with a quoted `player`). Add `\b(is|as)\s+Player\b` for `actors/` except `player.gd` (no actor uses it today), with a firing sample and a near-miss, and list in the rule's comment what it still can't see (a group name held in a const, a node path), as `raw_text` does. (Blind + Edge) [game/tests/test_lint.gd:133-136]
- [x] [Review][Patch] Small code tidy-ups: (a) `lurker.gd:74` says "tests and overlay 2 call these", but overlay 2 reads only `state`, `target` and `stir`; (b) `screenshot.gd:47-48` still sets `light.texture_scale` by hand, which `LightSource` overwrites on the next tick; (c) `Fx.EFFECTS[&"light_kick"]` says the swell is in `player.gd`, and it now lives in `light_source.gd`; (d) `Spec.NOTICE_MIN_RADIUS` is commented "a floor", while `test_sensing` holds it exact (79.9 never, 80 does): say both uses; (e) `test_dev_args:208-209` takes the expected reach from `Sensing.NOTICE_FACTOR`, and `Spec.NOTICE_FACTOR` now exists. (Blind + Auditor) [game/scripts/actors/lurker.gd:74; game/tests/screenshot.gd:47; game/scripts/core/fx.gd:57; game/tests/spec.gd:11; game/tests/test_dev_args.gd:208]
- [x] [Review][Patch] Docs still describe the M1 lurker or contradict themselves: (a) `docs/architecture.md:64, 66, 79, 121, 177` (lurkers poll the player through `get_first_node_in_group("player")`, the player eases its own light, "notices while on screen" with no notice/sense split or stirring), and its `spec.gd` row and test table lack the new entries; (b) `game-architecture.md` Stirring bullet says both "It runs in `RETURN` as well as `IDLE`" and "The lurker stays in `IDLE`", and Debug Tools still says "(sense/stir rings with 1.20)"; (c) `docs/development-guide.md` "Add a predator" says nothing of `LightSource` + `Sensing`, and "Light presentation consts stay in `player.gd`" is half true (`LIGHT_LERP` moved); (d) `docs/component-inventory.md:144` says a telegraph whose light went out goes to RETURN, and the code and the diagram above it say IDLE or RETURN; (e) `game/README.md:59` gives the 8 px margin two meanings in one sentence; (f) this story's D6 row I1 still says `stir = 0`, which D9 and the code reject; (g) `sprint-status.yaml`'s header comment date is behind its `last_updated` field. (Blind + Auditor)
- [x] [Review][Patch] Two hand-offs to later stories have no ledger line: `STIR_STEP_TIME` is "reviewed at the CP2 gate (1.30)" in the code, the GDD and the decision log; and D9's rule for Story 1.27 (the cue shows only for a lurker off screen, although `stir` also rises in the on-screen 8 px band) exists only in this story file. Add both to `deferred-work.md` with their owners (Story 1.30, Story 1.27). (Auditor) [_bmad-output/implementation-artifacts/deferred-work.md]
- [x] [Review][Patch] Found by the review's own export run: Godot's export cache ships a stale scene when a script's `@export` default changes. `game/.godot/exported/` holds each converted scene keyed on the scene file alone, and the conversion drops properties equal to the script's default. With `LightSource.kind`'s default changed (the patch above), the cached `player.scn` carried no `kind`: the web debug smoke failed on the `_ready()` assert, and a release build would have shipped a player light no lurker can hurt, with no error. Probed on 4.7.2 (the packed scene's `LightSource` has `script` only; after clearing the cache it has `kind = player`). `tools/export.sh` now deletes the cache before every export (about 8 s); `docs/build.md` and `project-context.md` say why. Proven by restoring the stale cache and building: BUILD OK, `kind` in the pack. [tools/export.sh]
- [x] [Review][Defer] A lurker on the notice edge flips between TELEGRAPH and rest with no rate limit [game/scripts/actors/lurker.gd:161-165] — deferred, pre-existing (M1 dropped a telegraph the same way; only `stir` is paced). Owner: Story 1.27.
- [x] [Review][Defer] A hunting lurker swings through a light that stands still [game/scripts/actors/lurker.gd:196-201] — deferred, pre-existing (M1's steering; no still light exists until flares). Owner: Story 1.23.

Dismissed (13): rows H1/T1 running before the retarget rows (D6 on purpose: "one row per tick", home at once); the per-tick cost (measured, above); `Rect2.has_point()`'s half-open edge at exactly 96 px (AC1 documents the rule for the notice rect; an exact edge lasts one tick of a moving view); `LightSource` with a `Light` child that is no `BudgetLight`, and a kick before the first tick (`test_light_budget` audits the scenes; no pogo lands on a life's first tick); the overlay's `TELEPORT_PX` guess (dev only, looked at on the laptop); two overlay checks that restate `Sensing` (the overlay is meant to draw the rule's own numbers) or count draws (dev only; sonlm: "yes it shows"); the trace fixture's rounding and its throwaway recorder (the baseline tree it recorded is `c40e75f`); `RULES.filter(...)[0]` in the lint (every hit's id comes from `RULES`); the across-the-edge pacing run flipping every two ticks (a per-tick flip can never stir under D6, as the Completion Notes say); the untyped signatures (probed, above); the drift item closed on "Everything else work" (sonlm's own answer to the list that held the question); the commit message's "Task 12 still pending" (true when written).

## Dev Notes

### What exists today (read before editing)

- **`lurker.gd` (M1, moved in 1.1, HP in 1.19):**
  - `senses(player)` = radius ≥ 80 and distance ≤ r × 1.6 and `_on_screen()` (the `world` node's `play_rect().grow(-8)`). **Every state uses that one rule**: so today a telegraphing or hunting lurker that leaves the notice rect loses you (Q1 changes the hunt).
  - It finds the player with `get_tree().get_first_node_in_group("player")` and refetches it when the old one is gone.
  - M1 D6 drops a TELEGRAPH or HUNT whose `_player` is gone or `is_dead` to RETURN at once (`smoke_world.test_hunt_over_death`).
  - HUNT sets `monitorable = sensed` every tick, `_enter()` sets `monitorable = next == HUNT`, the ×2 brake applies when not sensed, and `lurker_lose_track_time` (0.6 s) unsensed → RETURN.
  - **Re-sensing within the wait resumes the hunt with no telegraph** (`_unsensed = 0`; Q2 keeps it).
  - RETURN → TELEGRAPH on sense; RETURN reaches home → IDLE; TELEGRAPH loses the scent → IDLE at home, else RETURN.
  - Lurkers sit in the room, which is before the Player in World's tree, so **each tick a lurker runs before the player** (1.19 D3: the escape tick order). That is unchanged: the lurker reads the light as of the player's last tick.
- **`player.gd`:** `_update_light()` eases `_shown_radius` toward `chain.light_radius()` at `LIGHT_LERP`, sets `$Light.texture_scale`, and runs last in `_physics_process` (after the contact poll); the pogo hit adds `LIGHT_KICK`. Dead → `_physics_process` returns early, so the light holds. `LightSource` as a child keeps that order: a parent's `_physics_process` runs before its children's at the same priority.
- **`chain_state.gd`:** `light_radius()` = 12 (`SNUFF_RADIUS`) while snuffed, 40 (`BASE_RADIUS`) while clinging, else `radius_for(count)` = 40 + 22·√n (84 at 4, 109.6 at 10, 138.4 at 20).
- **`world.gd`:** `play_rect()` = `CameraRig.play_rect()` (the 360 px between the gutters, world coords). It joins group `world`. `_retire_player()` removes the old Player from the tree before the new room's predators run `_ready`.
- **`room_harness.gd`:** a `WorldStub` in group `world` with `play_rect()` from a real `CameraRig`.
- **`overlays.gd`:**
  - mode 2 puts `DevLightMarks` on the player only (radius ring, reach ring, HP line, a line to every predator that `senses()` it);
  - predator labels draw in `WorldMarks` at tick positions (the drift ledger item);
  - mode 1 draws the notice rect from `Lurker.SCREEN_MARGIN`.
- **`perf_run.gd`:** two stand-in BudgetLights (flare ALWAYS, cache CACHE) ride along. They are lights only, and the player at chain 20 wakes lurkers itself.
- **Tests that force lurker states:** `smoke_rooms` (lines 382, 387, 495, 573, 623), `smoke_health` (275, 336, 366, plus `test_lurker_harmless`), `smoke_world` (323). Several run the lurker with its physics **off**, so `_enter()` alone must set `monitorable` (D7).
- **`Rect2.has_point()`** on 4.7.2 (probed at story creation): `position` edges inclusive, `end` edges exclusive. `Rect2(0,0,100,50)`: (0, 0) true, (100, 10) false, (10, 50) false.

### D6: the lurker's state table

Each tick, after the M1 movement and presentation inputs:
- `live` = the nodes in group `light_source` that are `LightSource.live()`;
- `noticed` = `live` filtered by `notices()`, `sensed` = `live` filtered by `senses()`;
- `pick_n` = `pick_target(noticed)` and `pick_s` = `pick_target(sensed)` (as nodes; null for −1);
- `tgt_live` = `LightSource.live(target)`.

The first matching row wins.

| Row | State | Condition | Result |
|---|---|---|---|
| I1 | IDLE / RETURN | `pick_n` exists | `target = pick_n`; `_enter(TELEGRAPH)` (full timer, from rest; `stir` falls by its own clock, D9: no reset, corrected at the review) |
| I2 | IDLE / RETURN | otherwise | `stirring` = any live light `stirs_for()` this lurker; step `stir` (AC5). IDLE: eyes close. RETURN: drift home, at home → IDLE. `target = null` |
| T1 | TELEGRAPH | not `tgt_live` | RETURN (IDLE if within 1 px of home), at once: the light went out (M1 D6) |
| T2 | TELEGRAPH | `pick_n` is null (Q1: the telegraph is watched on screen) | IDLE at home, else RETURN (M1) |
| T3 | TELEGRAPH | `pick_n != target` and `pick_n.kind == player` | `target = pick_n`; `_enter(TELEGRAPH)` again: the full telegraph (FR21) |
| T4 | TELEGRAPH | `pick_n != target` (non-player) | `target = pick_n`; the timer runs on |
| T5 | TELEGRAPH | `pick_n == target` | the timer runs; at ≤ 0 → `_enter(HUNT)` |
| H1 | HUNT | not `tgt_live` | RETURN at once (M1 D6; a flare burnt out, the cache taken, a death) |
| H2 | HUNT | `pick_s` is null | lost the scent: `monitorable` false at once, ×2 brake, `_unsensed += delta`; at ≥ `lurker_lose_track_time` → RETURN |
| H3 | HUNT | `pick_s != target` and `pick_s.kind == player` | `target = pick_s`; `_enter(TELEGRAPH)` (FR21: every hunt of the player is telegraphed; a new life's light is a new node). Review (sonlm, 2026-11-25): `pick_s` comes from `_hunt_pick()`, which leaves out a player light the lurker isn't hunting and doesn't notice, so off screen the hunt stays on the largest of its target and the decoys (rows H4/H5) and no telegraph runs unseen |
| H4 | HUNT | `pick_s != target` (non-player) | `target = pick_s`; stays HUNT, no telegraph (FR16); `_unsensed = 0` |
| H5 | HUNT | `pick_s == target` | `_unsensed = 0`; close in at hunt speed (M1); this includes a re-sense inside the wait (Q2) |

- In every HUNT row, `monitorable = _harmful(pick_s == target)` (D7).
- Movement aims at `target.global_position`.
- `stirring` is false outside I2; `stir` steps toward 0 there by the same clock (AC5).

**Why the notice rule in TELEGRAPH (T2) and the sense rule in HUNT (H2–H5) — Q1, sonlm's answer (b).** The GDD's Hunt line has no screen test ("It senses the player while the light radius is ≥ 80 px and within radius × 1.6"), and the epic AC puts the play rect only on *notice*. The telegraph is the warning, so every tick of it stays watched on screen: the player sees all of it. Once the player has seen it, a hunt isn't dropped just because the view scrolled. For a lone player light the only difference from M1 is a lurker that trails out of view while hunting: it keeps hunting while in reach (at most 138 × 1.6 ≈ 221 px) instead of giving up at the screen edge. Landing, Snuff and cling still save you (they shrink the light, H2).

### Decisions

- **D1: Scope.**
  - In: `Sensing`, `LightSource` on the player, the lurker rewrite, `stir`, overlay 2, the lint rule, Spec, docs, ledger.
  - Out: the edge cue and the alert frame (Story 1.27), the stirring sound (E3), flares (Story 1.23), the Ember Cache (Story 1.22), the Weaver (E2).
  - The stand-in `LightSource` in tests is the only non-player light until 1.22 and 1.23.
- **D2: `Sensing` takes plain values.**
  - `rules/` is the bottom layer (`rules_purity`), so it can't take a `LightSource` or a `Lurker`.
  - `pick_target()` keeps the architecture's `Array[Dictionary]` shape; `LightSource.sensed()` builds the entries. The kinds live in `Sensing` (`KIND_*`), because `rules/` can't read `actors/`; `LightSource` uses them.
  - The four signatures in AC1 are the as-built API. `game-architecture.md`'s sample (one `can_sense()` with the rect) gets an "as built (Story 1.20)" note.
- **D3: The regions.**
  - Notice: inside `play_rect.grow(-8)`. Stir: inside `play_rect.grow(96)` and outside the notice rect, so the 8 px band inside the play area stirs too.
  - Why not "stir only outside the play rect": then a lurker in the 8 px band would sense, but neither notice nor stir. That is a silent gap where nothing warns, and Pillar 2 is "warned, never ambushed".
  - `grow()` makes a rectangle, so "within 96 px of the edge" is measured along each axis; the corners reach a little further. In spine shafts (352 px wide inside a 360 px play rect) stirring happens only above and below the view.
  - `SCREEN_MARGIN` has no GDD line. It may only shrink the notice region, so tests hold it ≥ 0, never to a value. The "no lurker notices outside the play rect" guarantee uses `play_rect()` itself (as `smoke_rooms` does).
- **D4: `LightSource` owns the light's size; the budget owns whether it is lit.**
  - The architecture says `LightSource` "drives its `PointLight2D` (or sprite glow)", and the 1.12 ledger item says it drives through the BudgetLight and never writes `enabled`.
  - Moving `Light` under `LightSource` gives 1.22's cache and 1.23's flare the same shape (`X/LightSource/Light`), so each reuses the easing and the size maths instead of copying `player.gd`'s.
  - The pogo kick stays the player's call (`LIGHT_KICK`), because only the player's light flares on a hit.
  - The budget's fallback sprite already copies the light's `texture_scale` (Story 1.12), so a demoted light still follows the eased size.
- **D5: A dead player's light is extinguished, not zeroed.**
  - `die()` → `light_source.extinguish()` leaves the group. Nothing senses it, overlay 2 stops drawing it, and a lurker whose target it was goes to RETURN at once (rows T1 and H1, M1's D6 kept).
  - The new life's `LightSource` is a different node. So even if a lurker saw both, switching onto it is row T3 or H3 (a fresh telegraph), and no HUNT can carry over a death.
  - The lurker no longer reads `is_dead` or the `player` group at all.
- **D6: The state table above.** Identity is the node, so a flare and the player at the same radius are two targets; ties use `pick_target()`'s rule.
- **D7: `monitorable` has one rule.**
  - `_harmful()` is the one expression: HUNT, sensed this tick, a live player target. The tick and `_enter()` both assign from it.
  - `_enter(HUNT)` passes `sensed_now = true`, so a forced hunt is lethal until its first tick, as M1's was. The escape tests' premise "harmful the frame before" and `smoke_health`'s physics-off cases depend on this.
  - `force(state, source)` is the test seam. It replaces the tests' private `_enter()` calls, which would now hunt with no target (harmless) and pass "no damage" for the wrong reason.
- **D8: A lone player light behaves as before** (sonlm's 1.19 feel check: "too easy to dodge", owner 1.30, "check what Story 1.20's sensing rules change first").
  - The trace (Task 1) pins it tick for tick on an all-on-screen scenario.
  - Q1 is the one deliberate change, and it is stated in the 1.30 ledger item.
- **D9: The stir step limit.**
  - The condition can flicker every tick: a lurker at the reach limit while the view bobs with the pogo. Story 1.27 draws `stir` as an eye with a glow, so a value that flips each tick would be a flash at 30 Hz (NFR8).
  - Limiting the value itself to one step per 0.35 s, in every state with no reset outside the clock, holds any drawing of it to ≤ 2.9 changes per second, under `Spec.FLASH_HZ_MAX`, with no rule left for 1.27 to remember. A reset to 0 on entering TELEGRAPH was rejected: a lurker flickering across the notice-rect edge would go 0 → 1 → 0 about 5.7 times per second.
  - 1.27 shows the cue only for a lurker off screen, so a `stir` still falling during a telegraph draws nothing.
  - The first step comes at once (GDD: "a half-open eye appears"), and the eye opens fully one step later (GDD: "opens wider as it stirs").
  - The value 0.35 s is presentation, a lurker const like `EYE_OPEN_TIME`, reviewed at the CP2 gate with the HUD defaults (Q3).
- **D10: Overlay 2 per node.**
  - Marks on a child of each light and each predator are engine-interpolated, which is the fix 5ac0bd9 proved for the player's ring.
  - The one line between two moving nodes is placed by hand with the interpolation fraction (the ledger's suggested fix).
  - The off-screen stir marker is a debug stand-in for 1.27's cue, so the laptop look can see stirring before the cue exists.
- **D11: The lint rule.**
  - The architecture's line "Never call `get_first_node_in_group("player")` to sense light" becomes a check once `lurker.gd` no longer does it.
  - It is scoped to `actors/`, where predators live. `dev/` (overlays) and `world/` may still find the player. An actor that truly needs the player later adds itself to `allow` with a reason.
- **D12: Red-checks.** Break each once, see `FAIL`, restore:
  - `Sensing.can_sense` with `<` for the reach: the 160 px "inclusive" check;
  - `NOTICE_MIN_RADIUS` 79: the 79.9 px check;
  - `pick_target` letting the player win ties: the tie checks (test and smoke);
  - `can_stir` without the notice-rect exclusion: the "0.5 px inside notices and doesn't stir" check;
  - T3 continuing the timer: the flare → player full-telegraph count;
  - H4 entering TELEGRAPH: the player → flare "never a TELEGRAPH tick" check;
  - `_harmful` without the kind test: "never monitorable while hunting the flare";
  - `extinguish()` removed from `die()`: `smoke_world`'s death check and `smoke_lurker` case 5;
  - `stir` with no step limit, and separately a reset to 0 on entering TELEGRAPH: the two pacing counts (by the light, across the edge);
  - `LightSource.radius()` returning the shown radius: the check on the tick after `kick()`;
  - `LightSource` setting `light.enabled = true` each tick: the demoted-light check;
  - T2 using the sense rule: case 9's telegraph half;
  - the lint rule's pattern emptied: its firing sample.
- **D13: Ledger** (`deferred-work.md`):
  - close "Overlay 2 reads the sensing constants from `Lurker`" (line 114) with `→ **Closed (Story 1.20): overlays.gd reads Sensing; overlay 2 draws rings for every light_source and a label per predator.**`;
  - close "`LightSource` drives its light through the owner's `BudgetLight`" (line 129): `→ **Closed (Story 1.20): LightSource eases its child BudgetLight's texture_scale and never writes enabled. The perf stand-ins stay lights only; the real cache (1.22) and flare (1.23) are LightSources.**`. Append to the 1.22 (line 131) and 1.23 (line 133) items: "replace the stand-in with the real LightSource; it then wakes lurkers in `perf_worst`, so re-read the summary";
  - close "Overlay 2 still drifts a little while falling" (line 153) **only after sonlm's look passes** (Task 12); otherwise re-own it with the answer;
  - add a note under "Lurkers are 'way too easy to dodge'" (line 252, owner 1.30): `→ Note (Story 1.20): sensing changed one thing for a lone player light: a hunt keeps sensing off screen (Q1). The M1 trace in tests/fixtures/lurker_trace_m1.json pins the rest.`;
  - new items, each with an owner line: anything found and not fixed. Expected: none.
- **D14: Docs.**
  - `docs/component-inventory.md`:
    - new rows `sensing.gd` and `light_source.gd`;
    - the `lurker.gd` row (public `state`, `target`, `stir`, `stirring`, `force()`, `notices()`, `senses()`, `stirs_for()`; "Senses when" replaced by the notice/sense/stir split; the consts row moves to `sensing.gd`);
    - the `player.gd` row (`light_source`, no `_update_light`);
    - `player.tscn` (`LightSource/Light`);
    - the overlays rows (1 and 2);
    - the tests (`test_sensing`, `smoke_lurker`, the fixture room, the trace fixture).
  - `docs/development-guide.md`:
    - overlays 1 and 2 (lines 59–60);
    - the "Tune a lurker" row (line 186: the sensing consts live in `rules/sensing.gd` and are GDD values, not tuning);
    - the lint table (`light_query`);
    - the test list.
  - `docs/architecture.md`: the Gaps table row "Lurker warning" (line 267): stirring is exposed (1.20), drawn in 1.27, heard in E3.
  - `docs/source-tree-analysis.md`: `rules/sensing.gd`, `actors/light_source.gd`, `tests/rooms/sensing/`, `tests/fixtures/lurker_trace_m1.json`.
  - `game/README.md`: the test list.
  - `game-architecture.md`:
    - Light-as-Signal: the as-built signatures (D2), the notice/sense split (Q1), stir regions (D3) and step limit (D9), the state table (link to this story);
    - AR28/AR29 wording where it says "drives its PointLight2D" (through the BudgetLight).
  - GDD: the Lurker bullets get one dated line each, only where Q1–Q3 decide something the GDD doesn't say (the telegraph stays on screen; the hunt senses off screen; re-sense in the wait resumes; the stir step). `decision-log.md`: a dated 2026-11-22 entry for the answers.
  - `project-context.md`:
    - one sentence in the story list for 1.20;
    - the Predators rule: "Predators sense light only through `LightSource` + `Sensing` (group `light_source`; lint `light_query`)";
    - the Last Updated line.

### Calls made at story creation without a question (sonlm may veto)

**Confirmed by sonlm at the code review, 2026-11-25 (all three); the GDD's Stirs and Retargeting lines and the decision log now carry them.**

- **The 8 px band stirs** (D3): a lurker on screen but inside the notice margin stirs rather than staying silent. Story 1.27's flare-cost hatch and E3's stirring sound will read it there too.
- **Stirring runs in RETURN as well as IDLE** (row I2): a returning lurker just off screen that would notice warns like an idle one.
- **A telegraph switching between two non-player lights keeps its timer** (row T4): only a switch onto the player restarts it (FR21).

### Questions for sonlm (answered at story creation, 2026-11-22)

- **Q1 (D6): where may a lurker sense you once it has noticed you?**
  - (a) GDD literal: notice needs on screen; the telegraph and the hunt then need only light and distance.
  - (b) **Recommended:** the telegraph needs on screen on every tick (the whole warning is seen), and the hunt needs only light and distance (the GDD's Hunt line).
  - (c) M1 as built: on screen for everything; a hunter that leaves the view gives up.
  - **Answer (sonlm, 2026-11-22): (b), the telegraph on screen on every tick; the hunt by light and distance alone.**
- **Q2 (row H5): you re-brighten within the 0.6 s wait (e.g. kick off a cling).**
  - (a) **Recommended:** M1 as built: the hunt resumes at once, no new telegraph (it was telegraphed less than a second ago).
  - (b) It telegraphs again from the start.
  - **Answer (sonlm, 2026-11-22): (a), the hunt resumes at once (M1 as built).**
- **Q3 (D9): the stir step.**
  - (a) **Recommended:** half-open at once, open after 0.35 s, closing one step per 0.35 s (≤ 2.9 changes/s), reviewed at 1.30.
  - (b) A slower 0.5 s step.
  - (c) No limit here; 1.27 handles the flicker when it draws.
  - **Answer (sonlm, 2026-11-22): (a), a 0.35 s step, half-open at once; reviewed at 1.30.**

### Testing standards

- Tests extend `Node` and run through `tests/runner.tscn`. They print `ok …` / `FAIL …` and a final `PASS` / `FAILED`. Any `SCRIPT ERROR` / `ERROR:` line fails the run. Name new tests `test_*.gd` / `smoke_*.gd` (the runner globs them).
- **Pure rules → `test_sensing.gd`.** Expected values come from `Spec`, never from `Sensing`'s consts (the margin is the one exception, D3).
- **Room behaviour → `smoke_lurker.gd`**, on the fixture room through `RoomHarness`. Pick nodes by position. Free everything you spawn: an exit-time leak prints an engine `ERROR:`.
- Frame maths (`development-guide.md`, measured on 4.7.2): a press made after an `await` is first seen two ticks later; a read after an `await` sees the last tick the player ran. Lurkers run before the player each tick.
- State every check's proof with exact expected values (1.18 review); a check whose expected value comes from the code under test proves nothing (1.16 review).
- Headless can check states, signals and numbers; it can't judge feel or steadiness. Report "tests green; needs a look on the laptop" until Task 12.

### Project Structure Notes

- **New:**
  - `scripts/rules/sensing.gd`, `scripts/actors/light_source.gd` (+ `.gd.uid` each);
  - `tests/test_sensing.gd`, `tests/smoke_lurker.gd` (+ uids);
  - `tests/rooms/sensing/t_sensing.txt`;
  - `tests/fixtures/lurker_trace_m1.json`.
- **Changed:**
  - `scenes/actors/player.tscn` (`LightSource/Light`);
  - `scripts/actors/player.gd`, `lurker.gd`;
  - `scripts/dev/overlays.gd`, `perf_run.gd`;
  - `tests/spec.gd`, `test_lint.gd`, `test_light_budget.gd`, `smoke_rooms.gd`, `smoke_health.gd`, `smoke_world.gd`, `smoke_dev_tools.gd`, `smoke_perf.gd`, `screenshot.gd`;
  - docs, the ledger, `project-context.md`, `game-architecture.md`, the GDD and the decision log (Q answers only).
- **Layering:**
  - `sensing.gd` is `rules/` and names nothing above it;
  - `light_source.gd` is `actors/` and reads `Sensing` (rules) and `BudgetLight` (core);
  - `lurker.gd` reads `LightSource` and `Sensing` and the `world` group, never `player`.
  - No autoload, addon or `.tres`. No new Tuning key (`test_tuning`'s count is unchanged).
- **Export:** `tests/*` is excluded from release, so the fixture room and the trace never ship. No preset change.

### Project Context Rules (from `project-context.md`)

- Godot 4.7.2, GDScript only, GL Compatibility, physics 60 ticks/s, physics interpolation on.
  - Move gameplay nodes only in `_physics_process`; the lurker moves itself there.
  - `reset_physics_interpolation()` after a teleport. Tests that `place()` call it already.
- **Predators sense light only through `LightSource` + `Sensing`** (group `light_source`), never `get_first_node_in_group("player")`. "On screen" is always `World.play_rect()` (never the viewport) for notice, stir and the guarantees; the light budget's `light_rect()` is a cost rule only.
- **A predator damages only while `monitorable == true`, and only while the player is its target**; the player's poll reads `monitorable` itself. Retargeting from a flare/cache onto the player needs a fresh telegraph (≥ 0.75 s). Never add a damage path around this: "Snuff/land/cling in time always saves you" is a tested guarantee.
- **FSMs:** `enum State` + `match` + one `_enter(state)`; `state` public.
- **Every `PointLight2D` is a `BudgetLight`**; only the budget writes `enabled` (lint `raw_light`, `test_light_budget`'s scene audit).
- **Actors find each other by group and duck typing**, never node paths (the `$LightSource/Light` path inside the player scene is the scene's own structure, which is fine).
- **No randomness in level behaviour.**
- **No logging in hot paths** unless wrapped in `if Log.enabled(Log.LURKER):`.
- **Accessibility:** nothing here flashes in play. `stir`'s step limit keeps 1.27's cue under the cap (D9). The overlay is dev-only, and nothing in it pulses or blinks.
- **Errors:** programmer errors → `assert` (an unknown `kind`); never `free()`, always `queue_free()`; no bare `print()`.
- **Design guarantees compare against `tests/spec.gd`**; never loosen a threshold to pass.
- **Every deferred item needs an owner**, set by the agent that defers it (`test_deferred_owners`).
- Commit `.gd.uid` files with their sources; re-save moved scenes.

### Previous story intelligence (1.12, 1.19)

- **1.19 D3** set the escape tick order (lurker before player; an escape on T is safe from T+1; a contact already listed on T still hurts), and the poll reads `monitorable` itself. Nothing here may change that order or the poll. The `_harmful()` rule only changes *what* `monitorable` is.
- **1.19's review** caught checks that could not fail. The physics-off "no damage" cases depend on `_enter(HUNT)` arming `monitorable`. Keep that (D7), or they pass vacuously.
- **1.19's review:** "the poll sees this tick's escape" was wrong in docs. Word any tick-order claim as D3 does.
- **1.12** made every light a BudgetLight and moved overlay 2's player marks onto an interpolated child (5ac0bd9). The laptop said "still a bit shaky but better"; this story finishes it (D10).
- **Memory: probe engine claims before acting on them.** Probed at story creation: `Rect2.has_point()` is half-open; `grow(-8)` of (0, 0, 100, 50) is (8, 8, 84, 34); `radius_for(4)` = 84.0 and `radius_for(3)` = 78.1. The parent-before-child physics order is Godot's documented default. Probe it once if `LightSource`'s easing reads a stale chain.
- **Git:** each story's commits move docs, the ledger and `project-context.md` with it (`9e8051d`, `c40e75f`).

### References

- Story source: `_bmad-output/planning-artifacts/epics.md` → Story 1.20 (FR5, FR16–FR21, AR28–AR31). Neighbours: 1.22 (the cache as a `LightSource`, kind `cache`), 1.23 (the flare, kind `flare`; FR16 switch smoke), 1.27 (draws `stir`; AR50 stir guarantee), 1.30 (feel defaults; "too easy to dodge").
- GDD `gdd.md`:
  - Predators: Lurker (M1): Wakes, Stirs, Telegraph, Hunt, Retargeting;
  - Flare Toss ("Predators that can sense the flare treat it as the player");
  - Economy: Ember Cache glow (≥ 80 px to wake).
- Architecture `game-architecture.md`:
  - Novel Patterns → Light-as-Signal (data flow, rules, the `Sensing` sample);
  - State Patterns (FSM);
  - Design Guarantees as Tests;
  - Debug Tools (overlay 2);
  - the Light budget (BudgetLight).
- UX `EXPERIENCE.md`: Off-screen edge cue (line 199); Stirring (line 227). `DESIGN.md`: Off-screen edge cue (lines 282, 594, 689); predator-red is reserved (no red in the overlay).
- Ledger `deferred-work.md`: lines 114, 129, 131, 133, 153–158, 252.
- Previous story: `1-19-health-4-hp-and-the-damage-table.md` (D3, D11, D12; Review Findings).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (`claude-opus-5-5`), gds-dev-story, 2026-11-22.

### Debug Log References

- **Task 1 baseline** (tree `6dacb7d`, whose `game/` differs from `c40e75f` only in `art/player.png`): `./run_tests.sh` → `== ALL GREEN (29 tests)`, 2005 `ok`, matching the story's record.
- **The M1 trace** was recorded by a throwaway script in the session scratchpad (run through the runner with an absolute path) before any game file was edited. Saved as `game/tests/fixtures/lurker_trace_m1.json`, 180 ticks: TELEGRAPH from tick 0, HUNT at 54 (`monitorable`), the chain break at 90 (harmless at once), RETURN at 125, still returning at 180. It was re-run after each step: identical after the light move (Task 3) and after the lurker rewrite (Tasks 4–5).
- **Probe (4.7.2): freed objects and typed parameters.** Passing a `queue_free()`d `LightSource` to any typed parameter, `Object` included, is a `SCRIPT ERROR` ("previously freed … not a subclass of the expected argument class") before the body runs. A `Variant` parameter works, and `is_instance_valid()` is false. So `LightSource.live(s)` and the lurker's `notices()` / `senses()` / `stirs_for()` take an untyped source: a deviation from AC2/AC3's typed signatures, needed so each one answers false for a freed light, as the ACs require.
- **Probe (4.7.2): when `queue_free()` lands.** A node freed after an `await physics_frame` is still valid for that same tick's callbacks and gone by the next tick. `smoke_lurker` case 5 waits for `is_instance_valid()` to turn false, then reads the state one tick later.
- **Debugging during dev:** `var made := ov.mark_nodes()` failed type inference in a test (an untyped `Array` return), fixed with `var made: Array`. A `RETURN`-row ordering detail: M1 read the light before the step home, so the new `RETURN` computes its pick and stir before moving.

### Completion Notes List

- **Sensing (AC1):** `rules/sensing.gd` as specified. `pick_target()` uses one `_beats()` comparison (a strictly larger radius, or a non-player light tying the player), so a tie between two decoys keeps the earlier index. `Spec` gained `NOTICE_FACTOR` and `STIR_REACH` with GDD quotes. `test_sensing` has 43 checks, with expected values from `Spec` and only the margin read from `Sensing` (after the ≥ 0 and "inside the play rect" checks).
- **LightSource (AC2):** `player.tscn` has `LightSource` (kind `player`) at `Light`'s old slot, with `Light` under it unchanged. `player.gd` lost `_update_light`, `_shown_radius`, `_light`, `LIGHT_LERP` and `LIGHT_TEXTURE_HALF`, and gained the public `light_source`. The pogo calls `kick(LIGHT_KICK)` and `die()` calls `extinguish()`. `LIGHT_LERP` moved to `light_source.gd` (`test_tuning`'s M1 row now names that home, and the three sensing rows name `rules/sensing.gd`). `LightSource` keeps ticking with the player's physics off: presentation only, and no lurker reads it. Paths updated: `perf_run.gd` (its stand-ins stay plain BudgetLights, and the header says so), `smoke_perf.gd` (path and the parent filter), `test_light_budget.gd`, and `screenshot.gd` (the texture width replaces `Player.LIGHT_TEXTURE_HALF`).
- **Lurker (AC3–AC5):** rewritten per D6, row by row, with one row per tick (no fall-through from the light-out rows). `force()`, `notices()`, `senses()`, `stirs_for()`, `_harmful()`, `target`, `stir`, `stirring`, `STIR_STEP_TIME` 0.35 s, plus a guarded `Log.LURKER` line per state change. **One contradiction in the story, resolved by AC5:** row I1 says `_enter(TELEGRAPH)` sets `stir = 0`, but AC5, D9 and D12 say `stir` never resets outside its clock (a reset on TELEGRAPH is one of D12's red-checks). The build follows AC5: `stir` steps on one clock in every state, and nothing else writes it. A `STIR_CLOCK_SLACK` of 1e-6 keeps the step on tick 21: 21 × 1/60 sums to a hair under 0.35.
- **Callers migrated in the same change (Task 5):** `overlays.gd`, `smoke_rooms.gd`, `smoke_health.gd`, `smoke_world.gd`, `smoke_dev_tools.gd`, plus `test_dev_args.gd`, which the story's list missed (it read `Lurker.NOTICE_*`). Every M1 guarantee in `smoke_rooms`, `smoke_world` and `smoke_health` passed with only the seam change; no threshold or expected value was touched.
- **smoke_lurker (Tasks 1, 6):** all 11 cases. Two additions beyond the list: a **T3 case** (a switch from the flare onto the player mid-telegraph restarts the telegraph in full). Case 3 drops the flare while the lurker *hunts* it, which is row H3, so D12's "T3 continuing the timer" red-check had nothing to fail without it. Also a separate **first-tick** case on a freshly spawned player at chain 10. The across-the-edge pacing run alternates **two ticks a side**: a lurker stirs only on a tick it starts in IDLE or RETURN, so flipping every tick only swapped TELEGRAPH and RETURN, and `stir` never moved (a vacuous count; the premise check caught it).
- **Overlays (AC6):** per-node `DevLightMarks` on every lit `LightSource` (radius ring, reach ring, `<kind> N px`, and the HP line for the player's) and `DevPredatorMarks` on every predator (`IDLE` / `TELEGRAPH flare` / `HUNT player`, ` stir N`). The sense line's ends are blended by hand from positions recorded at physics priority 100; a jump over 32 px counts as a teleport and snaps. The magenta stir marker sits at the play rect's edge in screen pixels. `player_marks` is gone; `mark_nodes()`, `predator_label()` and `stir_marker_at()` are new (public). `smoke_dev_tools`' mode-2 tests were rewritten to the new drawers, keeping what each proved, plus a stir-marker draw.
- **Lint (AC7):** `light_query` (`code` pattern, `only = ["actors/"]`, `allow` empty), with 3 firing samples and 5 near-misses. The rule's `why` is printed on each FAIL line (a small `test_lint` change: rows may now carry `why`). `rules_purity` and `core_layer` are quiet on `sensing.gd`: lint 34 files, 16 rules, 0 hits.
- **Perf (Task 3, Q1):** `smoke_perf` stays green. Its 3 s summary moved one number, `sprites max` from 1 to 3 (`lights max 6/6`, `over 0` unchanged), as Q1 predicted: hunters that trail out of view keep hunting, so more lurker glows are lit at once and the budget demotes more of them to sprites. Frame times are server noise (worst 10.6 → 12.0 ms, 0 over 20 ms). Nothing was retuned.
- **Ledger (D13):** closed the overlay-constants item and the `LightSource`-drives-`BudgetLight` item; appended to the 1.22 and 1.23 items; added the Q1 note under "way too easy to dodge". The drift item stays open until the laptop look (Task 12). No new items.
- **Docs (D14):** `component-inventory.md` (new Sensing and LightSource sections; the Player, Lurker, overlays and test rows), `development-guide.md` (overlays 1 and 2, "Tune a lurker", `light_query`, the test list), `architecture.md` (the Lurker warning gap), `source-tree-analysis.md`, `game/README.md`, `game-architecture.md` (Light-as-Signal: the table, data flow, the notice/sense split, stir regions and step, the "as built" note, the lint), the GDD's Lurker bullets (dated lines for Q1–Q3 only; the three veto-able calls stay in the decision log), `decision-log.md` (the 2026-11-22 entry), and `project-context.md`.

- **Red-checks (Task 9, D12):** each mutation applied by a script, its test run, the file restored. Every one turned red:
  - `can_sense` with `<`: `test_sensing` "160 px … inclusive" (and straight up).
  - `NOTICE_MIN_RADIUS` 79: `test_sensing` "79.9 px never sensed / noticed / stirs" and the Spec equality.
  - `pick_target` letting the player win ties: `test_sensing`'s three tie checks and `smoke_lurker`'s tie ("target player").
  - `can_stir` without the notice-rect exclusion: "0.5 px inside the notice rect: notices and does not stir".
  - T3 continuing the timer: the new mid-telegraph case ("24 ticks, at least 45").
  - H3 staying in HUNT (an extra, not in D12): case 3 ("state HUNT", "1 ticks").
  - H4 entering TELEGRAPH: case 4 ("state TELEGRAPH"; "never a TELEGRAPH tick").
  - `_harmful` without the kind test: "never monitorable … of that telegraph or hunt" and case 4's "monitorable true".
  - `extinguish()` removed from `die()`: `smoke_lurker` (the group check, "next tick is RETURN" got HUNT, "never notices a dead player's light") and `smoke_world`'s "one frame after the death the lurker drops the hunt (state 2)".
  - `stir` with no step limit: "stir 2 after 21 ticks (got 1)", the pacing counts by the light (60) and across the edge (30).
  - `stir` reset to 0 on entering TELEGRAPH: the across-the-edge count (6 > 3).
  - `LightSource.radius()` returning the shown radius: the tick after `kick()` (and 28 other checks, the M1 trace included).
  - `LightSource` setting `light.enabled = true` each tick: "a demoted light stays demoted".
  - T2 using the sense rule: case 9's telegraph half ("got TELEGRAPH"), plus the edge-pacing premise.
  - The lint pattern emptied: `light_query`'s three firing samples.
- **Full run (Task 11):** `cd game && ./run_tests.sh` gave `== ALL GREEN (31 tests)`, 2120 `ok` (from 29 and 2005). `smoke_rooms`' guarantees are unchanged and green. `xvfb-run … screenshot.gd` renders both shots and the three Deck mocks with no error (the chain-10 light and the lurker's telegraph show). `tools/export.sh` gave **BUILD OK** `builds/20261122-6dacb7d-dirty` (uncommitted tree): web 11.0 MB gzip (raw 40.8 MB), PCK files 94 / 94 / 94 / 102, the Linux release boot clean, the web smoke 7 passed, 149 s.
- **Laptop look (Task 12, 2026-11-25):** on a new server (10.5.5.193, reached through a jump server; toolchain reinstalled, re-run on the committed tree `8eaf14a`: `== ALL GREEN (31 tests)`, 2120 `ok`; `tools/export.sh` **BUILD OK** `builds/20261125-8eaf14a`, web 11.0 MB gzip, web smoke 7 passed, 93 s). sonlm looked at the web debug build (`?room=m1_shaft`, overlay 2) and the Windows release build. Answers, verbatim:
  - Q1 (overlay 2 steady while falling), Q3 (lurkers feel the same in plain play), Q4 (anything unfair): "Everything else work".
  - Q2 (`stir N` markers show for a lurker just above or below the view), after the marker was explained: "yes it shows".
  - No failures, so no new ledger items. The 1.12 drift item ("Overlay 2 still drifts a little while falling") is closed.
- **Code review (2026-11-25, `gds-code-review`):** 42 raw findings; 2 decisions (sonlm: keep chasing the flare off screen; confirm the three calls), 11 patches applied, 2 deferred (Story 1.27, Story 1.23), 13 dismissed. Details and probes are in Review Findings.
  - Game code: `Lurker._hunt_pick()` (a decoy kept off screen), `_velocity` zeroed on entering TELEGRAPH (every hunt starts from rest), `LightSource.kind` with no default, the `light_kick` row in `Fx.EFFECTS`.
  - Tests: `smoke_lurker` gained `test_identity`, `test_decoy_to_decoy` and `test_off_screen_decoy`, the exact telegraph floor (no one-tick allowance), `Spec.STIR_STEP`, the pogo's own `_on_pogo_hit()`, the from-rest and default-kind checks; lint `light_query` also fires on `is Player` / `as Player`.
  - Red-checks (each broken once, `FAIL` seen, restored): velocity kept through the telegraph; the hunt pick ignoring the screen; a 44-tick telegraph (the three old floor checks and the three new ones); a 0.5 s stir step; the pogo without its kick; H3 comparing kinds; T4 restarting the timer; the default kind back to `player`.
  - Build: `tools/export.sh` clears Godot's export cache before exporting (the stale `player.scn`, above). On this server Node 24 comes from nvm (`~/.nvm/versions/node/v24.22.3/bin` on `PATH`); a non-interactive shell otherwise finds the system Node 18 and the preflight stops.
  - Full run: `== ALL GREEN (31 tests)`, 2142 `ok` (from 2120). `tools/export.sh` **BUILD OK** `builds/20261125-8eaf14a-dirty` (uncommitted tree): web 11.0 MB gzip, web smoke 7 passed, 95 s. `screenshot.gd` renders both shots and the three Deck mocks.
  - Nothing a player can see changed with the lone player light (the M1 trace still matches tick for tick), so no new laptop look is needed; the decoy rules are felt first in Story 1.23.
- **Status:** tests green, looked at on the laptop, reviewed; status `done`.

### File List

**New**
- `game/scripts/rules/sensing.gd`, `game/scripts/rules/sensing.gd.uid`
- `game/scripts/actors/light_source.gd`, `game/scripts/actors/light_source.gd.uid`
- `game/tests/test_sensing.gd`, `game/tests/test_sensing.gd.uid`
- `game/tests/smoke_lurker.gd`, `game/tests/smoke_lurker.gd.uid`
- `game/tests/rooms/sensing/t_sensing.txt`
- `game/tests/fixtures/lurker_trace_m1.json`

**Changed**
- `game/scenes/actors/player.tscn`
- `game/scripts/actors/player.gd`, `game/scripts/actors/lurker.gd`
- `game/scripts/dev/overlays.gd`, `game/scripts/dev/perf_run.gd`
- `game/scripts/core/fx.gd` (review)
- `tools/export.sh`, `docs/build.md` (review)
- `game/tests/spec.gd`, `game/tests/test_lint.gd`, `game/tests/test_light_budget.gd`, `game/tests/test_tuning.gd`, `game/tests/test_dev_args.gd`, `game/tests/smoke_rooms.gd`, `game/tests/smoke_health.gd`, `game/tests/smoke_world.gd`, `game/tests/smoke_dev_tools.gd`, `game/tests/smoke_perf.gd`, `game/tests/screenshot.gd`
- `game/README.md`, `docs/component-inventory.md`, `docs/development-guide.md`, `docs/architecture.md`, `docs/source-tree-analysis.md`
- `_bmad-output/game-architecture.md`, `_bmad-output/project-context.md`
- `_bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md`, `_bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/decision-log.md`
- `_bmad-output/implementation-artifacts/deferred-work.md`, `_bmad-output/implementation-artifacts/sprint-status.yaml`, `_bmad-output/implementation-artifacts/1-20-light-sensing-for-predators.md`

## Change Log

- 2026-11-22: story created (`gds-create-story`), status ready-for-dev; Q1–Q3 answered by sonlm at creation (all three recommended options).
- 2026-11-22: implemented (`gds-dev-story`), Tasks 1–11 done: `Sensing`, `LightSource` on the player, the lurker rewrite (D6, Q1–Q3), overlay 2 per light and per predator, lint `light_query`, `test_sensing` and `smoke_lurker` (the M1 trace fixture); 31 tests, 2120 ok; BUILD OK `20261122-6dacb7d-dirty`. HALT at Task 12 for sonlm's laptop look.
- 2026-11-25: Task 12 laptop look passed (sonlm: Q1, Q3, Q4 "Everything else work"; Q2 "yes it shows"); overlay drift ledger item closed; status review.
- 2026-11-25: code review (`gds-code-review`): 2 decisions (sonlm: a decoy is kept off screen; the three story-creation calls confirmed), 11 patches applied with 8 red-checks (hunt from rest after a retarget telegraph, `LightSource.kind` without a default, exact telegraph floor, `Spec.STIR_STEP`, new retarget cases, lint `light_query` on `is Player`, doc drift, `export.sh` clearing Godot's export cache), 2 deferred (Story 1.27, Story 1.23), 13 dismissed; 31 tests, 2142 ok; BUILD OK `20261125-8eaf14a-dirty`; status done.
