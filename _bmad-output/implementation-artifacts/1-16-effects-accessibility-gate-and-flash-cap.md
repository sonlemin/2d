---
baseline_commit: c9143ca44cffd9ad5066806dac1a006838f7d661
---

# Story 1.16: Effects accessibility gate and flash cap

Status: done

**Type:** dev · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP2 Kit (1.16–1.30), first story · **Branch:** `feat/m2-e1`

## Story

As a player sensitive to flashing or motion,
I want every effect to respect reduce flashing, screen shake and reduced motion,
so that the game is safe to play from the first kit build.

## Acceptance Criteria

1. **Three new settings, read through one gate.**
   - `Settings.SCHEMA` gains `reduce_flashing` (default `false`), `shake` (default `true`) and `reduced_motion` (default `false`), each `choices = [false, true]`, with a typed var of the same name. No file version bump: a missing key takes its default (Story 1.4's rule).
   - `Fx` is the gate. It exposes three static readers, `Fx.reduce_flashing()`, `Fx.shake_on()` and `Fx.reduced_motion()`, which read `Game.settings`. Nothing else in `scripts/` names the three keys: camera shake, the invulnerability blink and (from the UI kit on) UI easing call `Fx`. There are no per-effect toggles.
   - A new lint rule `a11y_gate` fails on the three key names anywhere in `scripts/` outside `core/fx.gd` and `rules/settings.gd` (`dev/` skipped: DevTools sets keys generically through `SCHEMA`). Firing samples and near-misses as for every rule.
   - The web OS default for reduced motion is Story 1.36's (Options); here every default is fixed.

   (AR57, NFR8; D1, D2, D9)
2. **Every effect declares its flash rate, and a test holds the cap.**
   - `Fx.EFFECTS` is the one table of everything in the game that flashes, blinks, pulses, shakes or eases: `name → {kind, hz, reduced}`. Kinds: `ONCE` (one rise and fall per trigger), `PULSE` (smooth periodic) and `BLINK` (on/off periodic). `reduced` names the reduce-flashing or reduced-motion variant in words (or `""` with a `##` reason).
   - The rates the game runs are the declared ones: the invulnerability blink and the lurker's eye pulse take their hz from `Fx` (`Fx.INVULN_BLINK_HZ`, `Fx.EYE_PULSE_HZ`) and draw through `Fx` helpers (`Fx.blink_alpha()`, `Fx.pulse()`), never a local copy.
   - `tests/spec.gd` gains `FLASH_HZ_MAX := 3.0`, `PULSE_HZ_MAX := 2.0` and `BLINK_HZ := 2.5`, each citing the GDD.
   - `test_fx` asserts, for every entry: a `BLINK` is exactly `Spec.BLINK_HZ`, a `PULSE` is ≤ `Spec.PULSE_HZ_MAX`, nothing is above `Spec.FLASH_HZ_MAX`. It also **samples the helpers** over 2 s at 60 ticks/s and counts what a player would see: the blink's dark-to-lit transitions and the pulse's peaks, per second, against the same Spec values.
   - `test_fx` fails when a public static effect function on `Fx` has no `EFFECTS` entry (reflection over `Fx`'s method list, with a short allow-list for the non-effects: the materials, the gate readers, the helpers, `warm_up`).

   (NFR8, UX-DR125; D3, D4)
3. **Reduce flashing changes what exists today.**
   - **Pogo sparks** (`Fx.pop`, the sparks every pogo hit makes; D6): half the count (14 → 7) and half the size (scale max 2 → 1; the min stays at the 1 px floor, D5).
   - **Invulnerability blink** (the player sprite, 0.6 s after a crawler hit): the 2.5 Hz blink becomes steady transparency (`Fx.STEADY_ALPHA`, 0.5) for the same time. The player stays visible throughout.
   - The hit flash (Story 1.19), the HP-pip blink (1.25), the bank burst (1.26) and the alert frame (1.27) are new effects that add their `EFFECTS` row and their reduced variant through this gate when they land.

   (UX-DR126; D4, D5, D6)
4. **Screen shake off means the camera never shakes; the pogo feel stays.**
   - With `shake` false, `CameraRig.kick()` adds nothing and the rig's `offset` stays `Vector2.ZERO` on every tick, including a shake already running when the setting turns off.
   - The pogo freeze frame (`Game.clock` hitstop request) and the sparks still play on every hit.
   - `play_rect()` and `view_rect()` are unchanged (they never read the shake).

   (FR38, UX-DR128; D7)
5. **Reduced motion stops rising popups.** Under `reduced_motion`, `Fx.popup()` (and so `chain_popup()` and the bank/loss popups) fades in place without rising. UI easing has no consumer yet; the menu kit reads `Fx.reduced_motion()` when it lands. (UX-DR127; D8)
6. **Code-built effects free themselves, share cached materials, and warm up at room load.**
   - Unchanged and still tested: `finished` → `queue_free`, `CPUParticles2D`, `Fx.unshaded()` / `Fx.additive()` built once.
   - New: `Fx.warm_up(room)` draws each cached material once at room load: one `CPUParticles2D` with `unshaded()`, one `Label` with `unshaded()`, one `Sprite2D` with `additive()` and `art/light.png`. Each is a child of the room (AR23), drawn at an alpha no one sees, and frees itself within a few frames. `World._swap_room()` calls it right after the room enters the tree.
   - The point is the first-second hitch `docs/perf.md` records (562 ms worst frame at 0.0 s on web, Intel iGPU, build `20261121-e304d31`). Whether warm-up removes it is measured on the laptop (Task 9), never claimed from headless tests.

   (AR46, NFR1; D10)
7. **DevTools and tests can set all three now.** `--set=reduce_flashing:true`, `--set=shake:false` and `--set=reduced_motion:true` work through the existing `--set` path (bools are already supported), session-only, no `settings.json` write. Until Options lands (1.36) this is the only way in.
8. **Play is unchanged at the defaults.** With every setting at its default, the blink, pulse, sparks, popups and shake behave exactly as before (same counts, same scales, same 2.5 Hz / 2 Hz, same 14 px rise). Every existing test stays green, edited only where D11 lists.
9. **Done means green.** `cd game && ./run_tests.sh` → `== ALL GREEN`; every new check red-checked (break the code, see `FAIL`, restore); docs updated (D12).

## Tasks / Subtasks

- [x] **Task 1: Baseline (AC: 9).** `cd game && ./run_tests.sh` → `== ALL GREEN (22 tests)`, 1397 `ok`, 0 `FAIL` (measured at story creation on `c9143ca`, 2026-11-21); re-run and record in the Dev Agent Record.
- [x] **Task 2: Settings keys (AC: 1, 7).**
  - [x] Three `SCHEMA` rows + typed vars in `rules/settings.gd`, with `##` comments citing UX-DR126/127/128 and AR57. Update the header comment ("Brightness … and the Light tap window … exist so far").
  - [x] `test_state`: defaults, `from_dict` fallbacks for bad values (`1`, `"true"`, `null` → default, unclean), `to_dict` round-trip. Update the 1.11 comment that calls the fake bool key a stand-in "until 1.16 adds real ones"; keep the fake-schema check (it tests the passed-schema path).
  - [x] `test_dev_args:139`: the help string now lists five keys, sorted. Add one `--set=shake:false` row (valid) and one `--set=shake:0` row (invalid).
- [x] **Task 3: The gate and the table in `core/fx.gd` (AC: 1, 2).**
  - [x] `reduce_flashing()`, `shake_on()`, `reduced_motion()` read `Game.settings`.
  - [x] Consts `INVULN_BLINK_HZ := 2.5`, `EYE_PULSE_HZ := 2.0`, `STEADY_ALPHA := 0.5`; an `enum Kind { ONCE, PULSE, BLINK }`; `EFFECTS` rows for `pogo_sparks`, `popup`, `camera_shake`, `light_kick`, `invuln_blink`, `lurker_eye_pulse` (D3).
  - [x] Helpers: `blink_alpha(remaining: float) -> float` (1.0 or 0.0 at 2.5 Hz; `STEADY_ALPHA` under reduce flashing; 1.0 at `remaining <= 0`) and `pulse(t: float, hz: float) -> float` (0..1 sine).
- [x] **Task 4: Move the readers onto the gate (AC: 2, 3, 4, 5).**
  - [x] `player.gd` `_tick_timers`: replace the `visible` toggle with `_sprite.modulate.a = Fx.blink_alpha(_invuln)` (D4). Keep `visible` untouched.
  - [x] `lurker.gd`: delete `EYE_PULSE_HZ`; the telegraph uses `0.55 + 0.45 * Fx.pulse(...)`-equivalent through `Fx.EYE_PULSE_HZ` (same curve as today: `0.55 + 0.45 * sin(_t * TAU * hz)`). `test_tuning` row `lurker.eye_pulse_hz` moves `home` to `res://scripts/core/fx.gd` (D11).
  - [x] `Fx.pop`: half count and half max scale under `reduce_flashing()` (D5).
  - [x] `Fx.popup`: no `position:y` tween under `reduced_motion()`; the fade is unchanged.
  - [x] `camera_rig.gd`: `kick()` returns early when `not Fx.shake_on()`; `_physics_process` zeroes `_shake` and `offset` when off (D7). Update the 1.16 comment on `kick()`.
- [x] **Task 5: Warm-up (AC: 6).** `Fx.warm_up(room: Node)`; one call in `World._swap_room()` after `_room_holder.add_child(room)`. Probe first (D10) and record the result under Verified facts.
- [x] **Task 6: Lint `a11y_gate` (AC: 1).** Row, firing samples (`actors/player.gd` reading `Game.settings.reduce_flashing`; `world/camera_rig.gd` reading `Game.settings.shake`; `ui/gutters.gd` naming `&"reduced_motion"`), near-misses (`core/fx.gd`, `rules/settings.gd`, `var _shake := 0.0`, `kick(`, a comment-only mention if the rule scans code only). Docs table row (D9).
- [x] **Task 7: Tests (AC: 2–6, 8).**
  - [x] `test_fx`: the gate readers follow `Game.settings` (set, read, `Game.reset_for_tests()` after); the `EFFECTS` table checks; the sampling checks for blink and pulse (default and reduce-flashing: steady alpha never changes); `pop` counts and scales both ways; `popup` rises by default and stays put under reduced motion; the reflection check; `warm_up` adds three children to a parent, with the three materials, all freed within a second.
  - [x] `smoke_world` (or a new `smoke_a11y.gd`, D11): in `m1_shaft`, with `shake` false, a pogo hit leaves `offset == ZERO` for 30 ticks while a hitstop request is active and the crawler's sparks appear under the room; with `shake` true the same hit moves `offset` (existing check). Turning `shake` off mid-shake zeroes `offset` the next tick. A crawler knock with `reduce_flashing` on keeps the player sprite at `STEADY_ALPHA` and visible for the whole invulnerability.
  - [x] Red-check every new check (D13).
- [x] **Task 8: Docs (AC: 9; D12).**
- [x] **Task 9: Laptop check (human gate, AC: 6).** HALT for sonlm: the debug web build (`tools/export.sh`), `?room=perf_worst&perf`, Firefox on the Intel iGPU and the laptop's Chrome, recording `worst … at … s` in `docs/perf.md` next to the 1.15 rows; plus a look with `?set=reduce_flashing:true`, `?set=shake:false` and `?set=reduced_motion:true` in `m1_shaft` (sparks smaller, steady transparency after a crawler hit, no shake, popups stay put). The agent records no numbers and claims no feel; report "tests green; needs a feel check on the laptop".

### Review Findings

Code review 2026-11-21 over `c9143ca..HEAD` (Blind Hunter, Edge Case Hunter, Acceptance Auditor). No acceptance criterion or threshold changed after ready-for-dev. 2 decisions, 13 patches, 1 deferred, 8 dismissed. All decisions resolved and all patches applied the same day (see Review resolution below).

- [x] [Review][Decision] One-shot effects are never held to the 3 flashes/s cap — every `ONCE` row declares `hz = 0.0` and `test_fx` asserts exactly that, so nothing bounds how often the sparks, the light kick, the chain popup or the shake fire. The `light_kick` comment argues from the 0.22 s attack cooldown, which is 4.5 per second (about 3.4 per real second with the 75 ms freeze), above `Spec.FLASH_HZ_MAX`. The real bound for pogo effects is the bounce between hits, which no test measures. The ground slash arc (`player.gd:249-251`, unshaded, 0.12 s on in each 0.22 s cooldown) has no bounce bound and no row. Wording that waits on this decision: `fx.gd:5-6` and `:32-33`, `project-context.md:101`. [`game/scripts/core/fx.gd:28-34`, `game/tests/test_fx.gd:94-101`] (blind+edge+auditor; NFR8, AC2)
- [x] [Review][Decision] `Fx.EFFECTS` is not "everything that flashes, blinks, pulses, shakes or eases" — no row for the lurker's telegraph shiver (`lurker.gd:85`, `sin(_t * 40.0) * 0.5`, about 6.4 Hz), the pogo squash and its ease back (`player.gd:235`, `:87-89`), the eye-open ease (`lurker.gd:120`) or the slash and pogo arcs (`player.gd:249-251`). The Dev Notes scoped the shiver out ("not flashing") while AC2, the table's heading and `project-context.md` say everything; none of these reads a setting. `test_fx`'s reflection check sees only public static functions on `Fx`, so its "no effect ships undeclared" comment claims more than it checks. [`game/scripts/core/fx.gd:22-39`, `game/tests/test_fx.gd:108-122`] (blind+edge+auditor; AC2)
- [x] [Review][Patch] Warm-up nodes are freed on a 0.05 s tween, not on drawn frames: a first tween step of 0.05 s or more frees the label and sprite undrawn, and the comment says "Two frames". Free after two drawn frames; probe on 4.7.2 first that the signal counted fires under `--headless`. The `docs/perf.md` "no change" row stays provisional until a laptop `--perf` re-run after this patch. [`game/scripts/core/fx.gd:175-179`] (edge+auditor)
- [x] [Review][Patch] `test_pogo_shake_on` reads `got.hitstop` with no guard when the setup pogo misses; add `if not got.hit: return`, as `test_pogo_shake_off` has. [`game/tests/smoke_a11y.gd:104-105`] (blind+edge)
- [x] [Review][Patch] The rates the game runs are not held by a test: `test_fx.gd:104-105` compares the rows with the consts they are built from, and `Fx.pulse(t, hz)` takes any rate. Drop the tautology; in `smoke_a11y` measure a real lurker's eye-pulse interval and a real knock's blink rate against `Spec` (state the ±1 tick allowance); measure the sampled rates by mean interval, not a count over 2 s (which reads 2.1 Hz as 2.0). [`game/tests/test_fx.gd:104-105`, `:146-175`, `game/tests/smoke_a11y.gd:185`] (blind+auditor; AC2)
- [x] [Review][Patch] AC values are checked loosely or against themselves: the popup rise passes anywhere from 10 to 14 px, `STEADY_ALPHA` is compared with itself and a 0.3–1.0 window (AC3 says 0.5), `INVULN_LIT` (0.25 s of 0.4 s, AC8) is pinned by nothing, and the alpha read back from a `Color` is compared exactly. Pin 14 px at the end of the rise, 0.5 and 0.25 s with their AC citations (14 px is M1's value by AC8, not in the design docs), use `is_equal_approx`, await `tree_exited` for "frees itself", call `Game.reset_for_tests()` at the top of `run()`, and correct the header's "thresholds come from Spec" line. [`game/tests/test_fx.gd:13`, `:19-21`, `:153-154`, `:210-218`, `game/tests/smoke_a11y.gd:195`] (blind+edge+auditor; AC3, AC8)
- [x] [Review][Patch] World's own wiring is untested: deleting `world.gd:148` (the warm-up call) or `world.gd:193` (the `pogo_hit` → `kick` wire) fails nothing, since `smoke_a11y` connects the wire itself and `smoke_world` calls `kick(6.0)` directly. Add both checks to `smoke_world`. [`game/scripts/world/world.gd:148`, `:193`] (blind+edge+auditor; AC6)
- [x] [Review][Patch] The camera look-ahead changed with the real-time fix and no test reads `_lead`: on a pogo hit it used to drop by up to 46.7 px in one tick and now eases at 140 px/s. This is a second deliberate change at the defaults beside the shake (AC8's text is left as written). Add a `_lead` check across a real pogo with its hitstop; needs a laptop feel look. [`game/scripts/world/camera_rig.gd:108-111`] (edge+auditor; AC8)
- [x] [Review][Patch] Lint `a11y_gate` misses `_settings.shake`: `\bsettings` needs a word boundary and `_` is a word character. Widen the pattern and add firing samples. [`game/tests/test_lint.gd:108`] (blind; AC1)
- [x] [Review][Patch] The pre-1.16 settings check asserts only "unclean", not that brightness and the tap window survive and the three new keys take their defaults. [`game/tests/test_state.gd:178`] (blind; AC1)
- [x] [Review][Patch] `Fx.pop()` floors the particle count at 1 only under reduce flashing; `amount <= 0` at the defaults reaches `CPUParticles2D.amount` (no caller passes one today). [`game/scripts/core/fx.gd:107`] (edge)
- [x] [Review][Patch] The warm-up is still described as the hitch fix after the laptop measured no change (562 → 548 ms, one run): reword the comments and the `docs/perf.md` paragraph, and say that the Chrome row's elided figures are not in the story record. [`game/scripts/core/fx.gd:147-151`, `game/scripts/world/world.gd:148`, `docs/perf.md:26`, `:104-105`] (blind+auditor; AC6, D10)
- [x] [Review][Patch] Two hand-ons have no ledger entry: the first-frame stall ("→ 7.13" in the story record and `docs/perf.md`; note there that the warm-up label does not match the popup's font size and outline), and D6's obligation that a pogo target which survives a hit adds its own spark call. Add both to `deferred-work.md` with owner lines. [`_bmad-output/implementation-artifacts/deferred-work.md`] (blind+auditor)
- [x] [Review][Patch] The standing rule "real-time visuals use `delta / Engine.time_scale` in `_process`" is unqualified, while this story's own ledger entry says it misreads on the frame a Clock request lands; Story 1.19's hit flash will read the rule as written. Add the caveat, and correct `docs/architecture.md:138`, which still says `CameraRig._process` uses the formula. [`_bmad-output/project-context.md:39`, `_bmad-output/game-architecture.md:398`, `:659`, `docs/architecture.md:138`] (blind+edge+auditor)
- [x] [Review][Patch] Docs out of step: `EYE_PULSE_HZ` is still listed as a lurker const; the lint row says 13 rules (14 with `a11y_gate`); the `test_dev_args` check count (take it from the `ok` lines); the lint summary in `project-context.md` omits `a11y_gate`; `smoke_a11y` is missing from the test lists; the dated last-run line (update from the post-patch run). [`docs/component-inventory.md:115`, `:282`, `:284`, `_bmad-output/project-context.md:84`, `docs/development-guide.md`, `docs/source-tree-analysis.md`, `docs/architecture.md:226`, `game/README.md`] (blind+edge+auditor; D12)
- [x] [Review][Defer] Shake turned off while the tree is paused leaves the last random offset on screen until the first unpaused tick [`game/scripts/world/camera_rig.gd:117-121`] — deferred, new in this diff but unreachable until Options opens from Pause (owner Story 1.36)

### Review resolution (2026-11-21)

**sonlm's laptop looks (build `20261121-22fa2af`, web debug):**
- Slash arc mashed on the ground, and pogo effects on a fast chain: "Feels like norm. Doesn't flash. Seems like before."
- Camera on a pogo chain (the eased look-ahead, shake off then on): "Shake feels better." Taken as no objection to the eased look-ahead.
- Lurker shiver: not a valid look. `chain=20` is paid at take-off and banks on the first landing, so the lurker most likely never woke; sonlm: "I don't think it jitter". The decision below does not depend on it.

**Decision 1 (sonlm: option 1): measure the pogo gap, declare the slash arc.**
- `Spec.POGO_GAP_MIN` = 1 / `FLASH_HZ_MAX` (1/3 s, from NFR8's 3 flashes per second). `smoke_bot` times its pogo hits in every spine room: closest 1.017 s over 19 hits in `m1_shaft`. This is the bot's line, not every line a player can find; the attack cooldown alone allows about 0.29 s, so the bounce between targets (the layout) is what holds it.
- `Fx.EFFECTS` gains `swing_arcs` (ONCE) with its written reason: a player-paced attack sprite, not a flash. The `light_kick` comment's wrong arithmetic is gone; both rows say why in a `why` field.
- This amends AC2's design note (D3) that a one-shot's cap "is its trigger rate": the trigger rate is now measured.

**Decision 2 (sonlm: option 1): declare the motion effects, no behaviour change.**
- New kind `Fx.Kind.MOTION`: position or scale only, no brightness change; declared, not rate-capped. Rows `lurker_shiver` (6.37 Hz, from the new `Fx.SHIVER_RATE` that `lurker.gd` now reads; same value as before), `lurker_eye_open`, `pogo_squash`.
- This amends AC2 bullet 4 ("nothing is above `Spec.FLASH_HZ_MAX`") for `MOTION` rows only, by sonlm's decision. The design text now says so (sonlm, 2026-11-21): the GDD's Flash safety bullet defines a flash as a change in brightness, and NFR8 in `epics.md` exempts warning and hit-feedback sprite motion from reduced motion. `test_fx` requires every row to name a reduced variant or a `why`.

**Patches applied:**
- Warm-up frees after `Fx.WARM_FRAMES` (3) process frames, not a 0.05 s tween; the particle no longer finishes first. `test_fx` checks the items are still there two frames later.
- `smoke_a11y`: the missing guard; the look-ahead read across a real pogo (25.67 px before the hit, dropped 2.33 px on the hit tick, one tick's worth); each dark run of a real knock's blink is 9 ticks; the steady alpha against AC3's 0.5 with `is_equal_approx`.
- `test_fx`: the tautology removed; blink and pulse rates measured over 10 s by the span between events (`tests/rate.gd`), with a 2.1 Hz sample that fires; lit 15 and dark 9 ticks against M1's 0.25 s of 0.4 s; the popup's rise pinned at 14 px at the end of the rise; `pop()` with a count of 0; reset at the top of `run()`.
- `smoke_world`: World's own pogo → shake wire on the respawned player; three warm-up items under the room at every `room_entered`; a real lurker's eye pulse timed through its telegraph (at least 1.96 Hz from 4 turns in 53 ticks, cap 2.0).
- Lint `a11y_gate` catches `_settings.shake`; `test_state` asserts a pre-1.16 file keeps brightness and the tap window; `Fx.pop()` floors the count at 1 in both branches.
- Ledger: the first-frame stall (owner Story 7.13) and D6's spark obligation (owner E4).
- Docs: the warm-up wording (`fx.gd`, `world.gd`, `docs/perf.md`), the real-time caveat (`project-context.md`, `game-architecture.md`, `docs/architecture.md`), and the drift listed in the finding.

**AC8, recorded:** the eased camera look-ahead on a pogo hit is a second deliberate change at the defaults, beside the shake now showing. Both come from the `CameraRig` real-time fix. AC8's text is left as written.

**Red-checks (D13), each broken once and seen to FAIL, then restored:** `WARM_FRAMES` 1; the `pop()` floor removed; `EYE_PULSE_HZ` 2.2 (`test_fx` and `smoke_world`); `INVULN_LIT` 0.5 (`test_fx` and `smoke_a11y`); `POPUP_RISE` 12 and `STEADY_ALPHA` 0.6; a `why` removed; the rig reading `delta / Engine.time_scale` again (the look-ahead and the shake checks); World without its warm-up call; World without its pogo wire; the bot gap against 2 s. The lint's new samples are their own red-check.

**Result:** `cd game && ./run_tests.sh` → `== ALL GREEN (23 tests)`, 1565 `ok`, 0 `FAIL`, 0 error lines.

**The perf re-run (sonlm, 2026-11-21, build `20261121-af07203`, Firefox on the Intel iGPU), pasted:** `[room] dev: perf 60 s: 357 frames, avg 2.5 fps, min 0 fps, worst 95438.0 ms at 48.3 s, 15 over 20 ms; lights max 6/6, sprites max 5, over 0; chain 20, breaks 0, deaths 0; glow off; window 3330x1087; Web, ANGLE (Intel, Intel(R) HD Graphics Direct3D11 vs_5_0 ps_5_0), or similar` → **void**: a 95 s frame is a hidden or covered tab, and the summary reports only the worst frame, so the first-frame figure can't be read from it. sonlm: the story is done. The 1.16 row in `docs/perf.md` stays provisional and the first-frame stall is Story 7.13's (ledgered).

## Dev Notes

### What exists today (read before editing)

- **`scripts/core/fx.gd`** (static `class_name Fx`, no `extends`): `SPARK` colour; cached `unshaded()` / `additive()` (Story 1.12 D6); `pop(parent, pos, amount := 14)` (a `CPUParticles2D`, one-shot, lifetime 0.35, scale 1–2, `finished` → `queue_free`); `chain_popup()` → `popup()`; `popup()` (a `Label`, a parallel tween rising 14 px over 0.6 s and fading from 0.25 s, then `queue_free`). It reads no settings yet.
- **`scripts/world/camera_rig.gd`**: `kick(amount)` is the only shake entry (`_shake = maxf(_shake, amount)`); `_physics_process` decays `_shake` on real time (`SHAKE_DECAY` 20 px/s) and sets `offset` from `randf_range` (the only `randf` in `scripts/`; lint `random` allows it). `snap()` zeroes it. `play_rect()` / `view_rect()` read `_centre`, never `offset`. `World` wires `_player.pogo_hit` → `_camera.kick.bind(CameraRig.POGO_SHAKE)` (`world.gd:192`).
- **`scripts/actors/player.gd`**: `_tick_timers()` (physics, game time) sets `_sprite.visible = _invuln <= 0.0 or fmod(_invuln, 0.4) < 0.25`: a 0.4 s period = 2.5 Hz. `_invuln` is set only by `_take_knockback()` (crawler contact; predators kill). `_on_pogo_hit()`: `chain.add_hit()`, light kick (`_shown_radius += LIGHT_KICK`, 18 px, eased back by `LIGHT_LERP`), squash, `pogo_hit.emit()` (→ shake), `Fx.chain_popup()`, `_freeze_frame()` (Clock `hitstop` 0.05 × for Tuning `hitstop` 75 ms). Bank/loss popups through `Fx.popup()` under `_fx_parent()` (the room).
- **`scripts/actors/crawler.gd` `take_hit()`**: marks the kill, `Fx.pop(get_parent(), global_position)`, `queue_free()`. The crawler is the only pogo target in E1 (lurkers are on layer value 8; Pogo masks 4), and it dies on any hit, so this pop *is* the pogo spark today (D6).
- **`scripts/actors/lurker.gd`**: `const EYE_PULSE_HZ := 2.0`; TELEGRAPH sets `_eyes.modulate.a = 0.55 + 0.45 * sin(_t * TAU * EYE_PULSE_HZ)` and a 0.5 px shiver (`sin(_t * 40.0)`, presentation; not in scope: it is not flashing, and reduced motion's scope is UI-side, UX-DR127). `_glow.energy` follows `_eyes.modulate.a`.
- **`scripts/rules/settings.gd`**: `SCHEMA` (brightness int, light_tap_window float), `set_value()` emits `changed(key)`; `from_dict()` falls back per key; `is_valid()` checks type first (so `1` never passes for `true`). `Game.override_setting()` (1.11) for DevTools.
- **`scripts/core/budget_light.gd`**: demoted lights show an `Fx.additive()` sprite; sticky slots keep swaps ≤ 3/s (`test_light_budget` jitter check). Out of scope here beyond warm-up; its edge-hysteresis gap is already ledgered to 1.23.

### Decisions

- **D1: The gate is `Fx`.** AR57 names four readers (Fx, camera shake, invulnerability blink, UI easing) and "one gate". Making `Fx` the only script that names the keys lets one lint rule enforce it; the camera, the player and the future UI kit ask `Fx`. `Fx` is `core/` and may read `Game` (the `core_layer` lint forbids only scene-layer names and paths). Read the settings live on each call (no caching), so a DevTools `--set` or a later Options change applies at once.
- **D2: Defaults** `reduce_flashing = false`, `shake = true`, `reduced_motion = false`, per UX Accessibility Floor and A11 (reduced motion off on PC). The web OS default is 1.36's, because `rules/` can't ask the OS and Options owns that first-run choice; leave a `##` note on the var.
- **D3: The `EFFECTS` table** (in `Fx`, consts only):

  | name | kind | hz | reduced (words) |
  |---|---|---|---|
  | `pogo_sparks` | ONCE | 0 | reduce flashing: half count, half size |
  | `popup` | ONCE | 0 | reduced motion: fades in place, no rise |
  | `camera_shake` | ONCE | 0 | shake off: none |
  | `light_kick` | ONCE | 0 | none: an 18 px swell eased back, one per pogo hit (pogo hits are ≥ the 0.22 s cooldown apart and need a bounce between them) |
  | `invuln_blink` | BLINK | `INVULN_BLINK_HZ` 2.5 | reduce flashing: steady transparency |
  | `lurker_eye_pulse` | PULSE | `EYE_PULSE_HZ` 2.0 | none: the telegraph must read by motion, not colour alone (UX-DR129), and 2 Hz is within the pulse cap |

  The light kick has no `Fx` function (it lives in `player.gd`); its row is a declaration only, which the reflection check allows. A row's `hz` for ONCE is 0: the cap for one-shots is their trigger rate, one per pogo hit or per bank.
- **D4: Blink as alpha, not visibility.** `blink_alpha()` returns 1.0/0.0 on the same 0.4 s period, dark for 0.15 s of each (so it matches today's `fmod(_invuln, 0.4) < 0.25`), or `STEADY_ALPHA` under reduce flashing. Writing `modulate.a` instead of `visible` keeps one code path for both variants; the pips (1.25) reuse it. `player.tscn`'s `Sprite` has no modulate override (verified), so 1.0 is a no-op.
- **D5: "Half the size" has a 1 px floor.** Particles are untextured 1 × 1 quads scaled by `scale_amount`; at 480 × 270 with nearest filter a 0.5 px quad drops in and out between pixel centres, which is itself a flicker. So under reduce flashing: `amount` halves, `scale_amount_max` 2 → 1, `scale_amount_min` stays 1. Note this in the `##` comment. If sonlm wants a true half (min 0.5), it is a one-line change after the laptop look.
- **D6: `Fx.pop` is the pogo spark.** FR38 "sparks on every pogo hit" holds today because every pogo hit kills a crawler, and its death pop plays. Keep the name `pop` (no churn). E4's creature dissolve (tint → amber, Story 4.x) builds on it; any later pogo target that survives a hit must add its own spark call, which that story owns.
- **D7: Shake off is checked twice.** `kick()` refuses new shake, and `_physics_process` forces `_shake = 0.0; offset = ZERO` while off, so turning shake off mid-shake (Options later, a test now) can't leave a random offset frozen. The `randf_range` call is skipped while off (no draw needed).
- **D8: Reduced motion, scope now.** Only `Fx.popup()` rises today. The cursor easing, pip shake and zone cross-fade arrive with the UI kit, HUD v2 and E4; they call `Fx.reduced_motion()`.
- **D9: Lint `a11y_gate`.** `bare` patterns on code (strings stripped as the other rules do): `\breduce_flashing\b`, `\breduced_motion\b`, and the shake key in its two shapes, `\bsettings\s*\.\s*shake\b` and `&\s*["']shake["']` (a `code` pattern, since it is a string). `only = []`, `skip = ["dev/"]`, `allow = ["core/fx.gd", "rules/settings.gd"]` (prefix matches; the RULES header comment explains `skip` vs `allow`). `bare` patterns see code with comments dropped and string contents blanked, which is why the string shape needs a `code` pattern. `var _shake` and `kick(` must not fire.
- **D10: Warm-up, probed.** The hitch the 1.15 runs saw sits in the first second, when the first lurker glow is demoted (the additive material's first draw) and the first particles and labels are drawn. Godot compiles a GL Compatibility shader variant on first draw, so a warm-up only helps if the item is actually drawn: off-screen items are culled, and the canvas renderer may skip an item whose modulate alpha is 0. **Probe on 4.7.2 before relying on it** (memory: probe engine claims): read `servers/rendering/renderer_canvas_cull.cpp` for the alpha cull threshold, and use `Color(1, 1, 1, 1.0 / 255.0)` if 0 is culled. Place the three items at the room's player entry (`room.entry_position(entry)`, inside the first view), one frame of particles (`amount = 1`, `lifetime` ≈ 0.05) and a one-character label freed on a one-frame timer. Headless can't show a hitch; the laptop run (Task 9) is the measure, and a "no change" result is recorded honestly with a next step for E7's performance pass.
- **D11: Test edits allowed:** `test_state` (new keys, the 1.11 comment), `test_dev_args` (help string, new rows), `test_tuning` (the eye-pulse row's `home`), `test_lint` (new rule rows), `test_fx` (grows, as its header promised), `smoke_world` (new checks, or put them in a new `smoke_a11y.gd`, which the runner's glob finds). `smoke_world:169` counts room children around a bank popup: warm-up children are added at room load and freed frames later, so make sure the count there is taken after they're gone or is still relative within one frame (it is today: verify after Task 5).
- **D12: Docs.** `docs/development-guide.md` (lint table row `a11y_gate`; the three `--set` keys under DevTools), `docs/component-inventory.md` (Fx: the gate, `EFFECTS`, helpers, `warm_up`; CameraRig: the gate is in; Settings: the keys; the `test_fx` row), `docs/perf.md` (the hitch paragraph points to warm-up and the Task 9 rows), `project-context.md` (one line in the Story list: what 1.16 added; the Platform "Accessibility" rule gains "through `Fx`'s gate; every new effect adds an `Fx.EFFECTS` row"). Architecture: one sentence under UI → Accessibility gate naming `Fx` as the gate and `EFFECTS` as the declaration.
- **D13: Red-checks.** For each new check, break the code once (e.g. `INVULN_BLINK_HZ = 3.5`, `EYE_PULSE_HZ = 2.5`, drop the `kick()` guard, skip the halving, remove an `EFFECTS` row, name `reduce_flashing` in `player.gd`) and see the `FAIL`; restore.

### Testing standards

- Tests extend `Node`, run through `tests/runner.tscn`, print `ok …` / `FAIL …` and a final `PASS` / `FAILED`; any `SCRIPT ERROR` / `ERROR:` line fails the run.
- Thresholds come from `tests/spec.gd`, never from `Fx`'s own consts (compare `Fx.INVULN_BLINK_HZ` to `Spec.BLINK_HZ`, not to itself).
- Settings changes in tests go through `Game.settings.set_value()`; restore with `Game.reset_for_tests()` (it resets in place; never replace `Game.settings`). Settings writes are disarmed in tests (smoke_world checks this).
- Smoke tests load rooms standalone (`RoomLoader` + test player or the World harness already used by `smoke_world`), count physics frames, and drive input with intents or `Input.action_press`.
- Pick targets by position/sort order, never `get_nodes_in_group(...)[i]`.

### Project Structure Notes

- Game code touched: `rules/settings.gd`, `core/fx.gd`, `world/camera_rig.gd`, `world/world.gd` (one warm-up call), `actors/player.gd` (blink), `actors/lurker.gd` (pulse source). Nothing in `scenes/` changes. No new autoload, addon or `.tres`.
- Dependency direction holds: `actors/` and `world/` call `core/` (`Fx`), `Fx` reads `Game` (core). `rules/settings.gd` stays pure.

### Project Context Rules (from `project-context.md`)

- Godot 4.7.2, GDScript, GL Compatibility; physics 60 ticks/s; interpolation on (the rig moves on the physics tick).
- Only `Game.clock` writes `Engine.time_scale`; the pogo freeze is `Game.clock.request(&"hitstop", …)` and stays untouched.
- Visuals in `_process` use `delta / Engine.time_scale`; the blink is game-time (physics) today and stays so (it measures invulnerability, which is game time).
- Cache materials as statics; never a new `Material` per effect; code-built FX free themselves; `CPUParticles2D` only; no threads; no pooling.
- `randf` only for camera shake. No `print(`; use `Log`. Never `free()`.
- State writes only through rule methods (`set_value()`); never replace `Game.settings`.
- Accessibility rule: ≤ 3 flashes/s anywhere (pulses ≤ 2 Hz, blinks 2.5 Hz); all flashing, shaking, pulsing and easing read the three settings through `Fx`, camera shake, the invulnerability blink and UI easing; no per-effect toggles.
- Comments explain why and cite the design (UX-DR126, AR57, NFR8), never restate what.
- Headless tests can't judge feel: report "tests green; needs a feel check on the laptop".
- Every deferred item gets an owner line in `deferred-work.md`, set by the agent that defers it.

### Previous story intelligence (1.12–1.15)

- 1.12 built `Fx.unshaded()` / `additive()` and `test_fx` (8 checks), and named this story as the place for the gate, warm-up and flash-rate declarations (`test_fx` header, `camera_rig.gd:58`).
- 1.15's CP1 gate (done 2026-11-21): interpolation kept, engine glow no-go (bloom = unshaded additive sprites), budget 6 confirmed, feel yes. Its web run on the Intel iGPU had min FPS 28 and a 562 ms worst frame at 0.0 s, both put down to the first-second hitch and handed to 1.16 (`docs/perf.md`, `docs/devlog/cp1.md`).
- Reviewers' engine-behaviour claims (ERROR lines, culling) have been wrong before: probe on 4.7.2 before patching (D10).
- `JSON.new().parse()` only; `ConfigFile` and `JSON.parse_string()` print `ERROR:` lines that fail the runner (relevant if a test writes a settings file).

### Verified facts

- DevTools `--set` already parses bools (`dev_tools.gd` `set_value_of`, `TYPE_BOOL`: `true`/`false` only) and validates against `Settings.is_valid()`, so AC7 needs no DevTools code.
- `test_dev_args.gd:139` hard-codes the `schema_help` string (`keys: brightness (0, 1, 2, 3), light_tap_window (0.12, 0.2, 0.3)`); it changes with the new keys.
- `test_tuning` keeps the M1 `lurker.eye_pulse_hz = 2.0` row as a `local` constant read through `get_script_constant_map()` of `home`; a `home` of `fx.gd` with `local = "EYE_PULSE_HZ"` works the same way.
- **Alpha-cull probe (D10), 4.7.2-stable source:** `RendererCanvasCull::_cull_canvas_item` returns early when `(ci->modulate * p_modulate).a < 0.007`, so `1/255` (0.0039) is culled (line 329, re-checked with curl). `Fx.WARM_ALPHA` is 0.01; `test_fx` checks it against 0.007.
- **Warm-up draw probe (code review, 4.7.2, `xvfb-run` with `opengl3`):** items created on a physics tick and counted at `RenderingServer.frame_post_draw`. The 0.05 s tween: drawn once after a normal frame, **0 times** when the frame before took 120 ms. `Fx.warm_up()` counting three process frames: drawn twice in both cases. Under `--headless`, `frame_post_draw` never fires (0 times over the same probe; 164 times under the renderer), which is why the warm-up counts `process_frame` and not drawn frames.
- **`_process` delta probe (code review, 4.7.2, headless and under a renderer):** a hitstop requested from a physics tick (`Game.clock.request(&"hitstop", 0.05, 0.075)`) leaves that same frame's `_process` delta scaled at the old 1.0 (0.0068 s, like the frames before it) while `Engine.time_scale` already reads 0.05, so `delta / Engine.time_scale` reads 0.136 s, 20 times too long. From the next frame the delta is scaled (0.00035 s) and the formula is right again (0.0070 s). So the dev's physics-tick finding holds for `_process` too, which is what the caveat in `project-context.md`, `game-architecture.md` and `docs/architecture.md` and the squash entry in the ledger (Story 1.19) say.
- **Bot pogo gap (code review):** `m1_shaft`, closest two pogo hits 61 ticks apart (1.017 s) over 19 hits, counted in physics ticks (60 per real second under a hitstop, Story 1.8 D3).

### References

- Story source: `_bmad-output/planning-artifacts/epics.md` → Story 1.16 (FR38, NFR8, AR46, AR57, UX-DR125–UX-DR128).
- GDD: Combat damage table (crawler contact "0.6 s invulnerable (blinking at 2.5 Hz)"), Predators → Lurker telegraph ("pulse at 2 Hz"), Feel rules ("Freeze frames and sparks on every pogo hit", "Screen shake can be turned off"), Accessibility ("Flash safety").
- UX: `EXPERIENCE.md` → Game Feel & Juice (reduce flashing and reduced motion tables), Accessibility Floor; `DESIGN.md` → Do's and Don'ts (flash cap).
- Architecture: `game-architecture.md` → UI → Accessibility gate; Consistency Rules → Accessibility; Project Structure (`core/fx.gd` reads the accessibility gate).
- `docs/perf.md` → Known first-second hitch; `docs/devlog/cp1.md`.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), 2026-11-21

### Debug Log References

- Baseline (Task 1) on `0316d42`: `== ALL GREEN (22 tests)`, 1397 `ok`, 0 `FAIL`. After: `== ALL GREEN (23 tests)`, 1526 `ok`, 0 `FAIL`.
- D10 probe: see Verified facts (culled below 0.007 alpha; `WARM_ALPHA` 0.01).
- **Pre-existing bug found and fixed (sonlm chose "fix it here", 2026-11-21):** the pogo shake has not shown since 1.7. On a pogo hit the player requests the hitstop earlier in the same physics tick, but that tick's `delta` was already scaled at 1.0. Probed on 4.7.2: `dt` stays 1/60 on the tick `time_scale` drops to 0.05, and is 1/1200 on the tick it returns to 1.0. So `CameraRig`'s `delta / Engine.time_scale` read 0.33 s and zeroed the 2.5 px shake at once (and could move the lead up to 46 px). The rig now counts one tick as 1/60 s of real time (PlayerInput's Story 1.8 D3 rule). `smoke_a11y` drives a real pogo with its hitstop and checks the shake; reverting the line turns it red (0 of 6 ticks shaken).
- Same trap in `player.gd` `_process` (the pogo squash): deferred, owner Story 1.19.
- Red-checks (D13). Each broke one thing, saw `FAIL` and was restored:
  - `INVULN_BLINK_HZ` 3.5 and `EYE_PULSE_HZ` 2.5 (test_fx)
  - the `kick()` guard removed, then the `_physics_process` guard removed (smoke_a11y)
  - the rig back to `delta / time_scale` (smoke_a11y)
  - the `pop` count or size not halved (test_fx)
  - the `pogo_sparks` row deleted (test_fx reflection)
  - the popup rise not gated (test_fx)
  - `WARM_ALPHA` 1/255 (test_fx)
  - the blink's reduce-flashing branch removed (test_fx, smoke_a11y)
  - the warm-up sprite dropped (test_fx)
  - `shake` default false (test_state)
  - `Game.settings.reduce_flashing` read in `player.gd` (test_lint `a11y_gate`)
  - the knock-tick alpha write removed (smoke_a11y)
- D11: the room child count at `smoke_world:169` is compared within one frame, so it stays green while the warm-up children exist.
- `smoke_a11y`'s knock covers two invulnerabilities back to back (72 ticks): the player still touches the walker when the first one ends. Both hold steady.

### Completion Notes List

- Story created 2026-11-21: ultimate context engine analysis completed - comprehensive developer guide created.
- AC1/AC7: three `Settings` keys, defaulting to off / on / off. No version bump: an older file is unclean and gets rewritten with the defaults. `Fx.reduce_flashing()` / `shake_on()` / `reduced_motion()` read them live. Lint `a11y_gate` (5 firing samples, 10 near-misses) keeps the key names inside `core/fx.gd` and `rules/settings.gd`. `--set=` takes them through the existing bool path (`test_dev_args`).
- AC2: `Fx.EFFECTS` has 7 rows: D3's six plus `chain_popup`, so the reflection check covers every public effect function. Each row names its `fn`. `Spec.FLASH_HZ_MAX` / `PULSE_HZ_MAX` / `BLINK_HZ` cite the GDD. `test_fx` checks the table, samples the blink (2.5 rises/s) and the pulse (2 peaks/s) at 60 ticks/s, and fails on an undeclared public static function.
- AC3: `pop()` halves the count and the max size under reduce flashing, keeping the 1 px floor (D5). `Player` writes `Fx.blink_alpha(_invuln)` to `_sprite.modulate.a` every tick, and once more on the knock tick itself (without that, the knock frame drew at 1.0 before going steady). `visible` is no longer touched.
- AC4: `kick()` refuses shake while it is off, and `_physics_process` zeroes `_shake` / `offset` while it is off (no `randf` draw). AC4/AC8's "the same hit moves offset" also needed the real-time fix above.
- AC5: `popup()` skips the rise under reduced motion; the fade is unchanged.
- AC6: `Fx.warm_up(room, pos)`. The `pos` argument is new to D10's sketch: it is the entry position, which puts the items inside the first view. `World._swap_room()` calls it once, after the room enters the tree. Whether it removes the hitch is Task 9's laptop run.
- AC8: the defaults are unchanged: 14 sparks at 1–2 px, the 2.5 Hz blink with M1's 0.25 of 0.4 s lit, the eye curve `0.1 + 0.9 * pulse` (= M1's `0.55 + 0.45 * sin`) and the 14 px rise. The one deliberate change at the defaults is that the pogo shake now shows (the fix above).
- **Task 9 (laptop, human gate) is open.** Tests green; needs a feel check on the laptop:
  - the debug web build with `?room=perf_worst&perf` on Firefox (Intel iGPU) and Chrome, with `worst … at … s` recorded in `docs/perf.md`
  - `m1_shaft` with `?set=reduce_flashing:true`, then `?set=shake:false`, then `?set=reduced_motion:true`
  - the pogo shake at the defaults, new to anyone who played since 1.7
  - the fall lead on a pogo: it used to snap up to 46 px back in one tick on every pogo hit mid-fall, and now eases at 140 px/s (the same rig fix). The 1.15 "feel yes" was given with the snap.

- **Task 9 result (sonlm, laptop, 2026-11-21), build `20261121-22fa2af`:**
  - Firefox / Intel iGPU, pasted: `[room] dev: perf 60 s: 3570 frames, avg 59.5 fps, min 29 fps, worst 548.0 ms at 0.0 s, 2 over 20 ms; lights max 6/6, sprites max 7, over 0; chain 20, breaks 0, deaths 0; glow off; window 3330x1870; Web, ANGLE (Intel, Intel(R) HD Graphics Direct3D11 vs_5_0 ps_5_0), or similar` → warm-up made **no change** (562 → 548 ms, noise). At 0.0 s the stall is the first frame itself, which a warm-up in the same frame can't remove; it is load time, before any input, and will sit behind the click-to-play gate (1.33). Not chased further; the performance pass is 7.13 (already owns the web runs). `Fx.warm_up()` stays: it is cheap and covers later first draws (a later room's first demotion).
  - Chrome, pasted: `[room] dev: perf 60 s: 844 frames, avg 4.1 fps, min 0 fps, worst 159886.3 ms at 46.8 s, 160 over 20 ms; …; window 4358x6762; Web, WebKit WebGL` → **void** (a 160 s frame is a hidden tab, the known 7.13 item).
  - Settings looks: sonlm "settings look right" (reduce flashing, shake off, reduced motion in `m1_shaft`).
  - Pogo feel with the shake back and the eased lead: "pogo yes but just a bit, barely visible" → the 2.5 px shake strength is deferred to the 1.30 feel review (ledger, owner 1.30).

### File List

- `game/scripts/rules/settings.gd`
- Code review: `game/scripts/actors/lurker.gd`, `game/tests/rate.gd` (+ `.uid`, new), `game/tests/smoke_bot.gd`, `game/tests/smoke_world.gd`, `game/tests/spec.gd`, `game/tests/test_state.gd`, `game/tests/test_lint.gd`, `docs/architecture.md`, `docs/source-tree-analysis.md`, `game/README.md`, `_bmad-output/game-architecture.md` (the other files below were touched again)
- `game/scripts/core/fx.gd`
- `game/scripts/world/camera_rig.gd`
- `game/scripts/world/world.gd`
- `game/scripts/actors/player.gd`
- `game/scripts/actors/lurker.gd`
- `game/tests/spec.gd`
- `game/tests/test_fx.gd`
- `game/tests/test_lint.gd`
- `game/tests/test_state.gd`
- `game/tests/test_dev_args.gd`
- `game/tests/test_tuning.gd`
- `game/tests/smoke_a11y.gd` (new)
- `game/tests/smoke_a11y.gd.uid` (new)
- `docs/development-guide.md`
- `docs/component-inventory.md`
- `docs/perf.md`
- `_bmad-output/project-context.md`
- `_bmad-output/game-architecture.md`
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

### Change Log

- 2026-11-21: Tasks 1–8 implemented: the accessibility gate in `Fx`, `EFFECTS` with the flash-cap tests, the reduced variants, the shake gate, warm-up, lint `a11y_gate`, `smoke_a11y` and the docs. Also fixed the pre-existing hitstop/real-time bug in `CameraRig` (sonlm's call). Status stays in-progress until Task 9's laptop check.
- 2026-11-21: Task 9 done (sonlm on the laptop): warm-up no change to the first-frame stall (recorded in `docs/perf.md`), Chrome run void, settings looks right, pogo feel yes (shake barely visible → 1.30). Status → review.
- 2026-11-21: Code review (3 layers): 2 decisions resolved by sonlm (measure the pogo gap and declare the slash arc; declare motion effects as `MOTION` rows), 13 patches applied, 1 item deferred to Story 1.36, 2 ledger entries added (7.13, E4), 8 findings dismissed. 23 tests, 1565 `ok`. Status → done; the laptop perf re-run on the patched build is still open.
