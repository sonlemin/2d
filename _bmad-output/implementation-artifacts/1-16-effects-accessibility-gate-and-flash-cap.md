---
baseline_commit: c9143ca44cffd9ad5066806dac1a006838f7d661
---

# Story 1.16: Effects accessibility gate and flash cap

Status: ready-for-dev

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

- [ ] **Task 1: Baseline (AC: 9).** `cd game && ./run_tests.sh` → `== ALL GREEN (22 tests)`, 1397 `ok`, 0 `FAIL` (measured at story creation on `c9143ca`, 2026-11-21); re-run and record in the Dev Agent Record.
- [ ] **Task 2: Settings keys (AC: 1, 7).**
  - [ ] Three `SCHEMA` rows + typed vars in `rules/settings.gd`, with `##` comments citing UX-DR126/127/128 and AR57. Update the header comment ("Brightness … and the Light tap window … exist so far").
  - [ ] `test_state`: defaults, `from_dict` fallbacks for bad values (`1`, `"true"`, `null` → default, unclean), `to_dict` round-trip. Update the 1.11 comment that calls the fake bool key a stand-in "until 1.16 adds real ones"; keep the fake-schema check (it tests the passed-schema path).
  - [ ] `test_dev_args:139`: the help string now lists five keys, sorted. Add one `--set=shake:false` row (valid) and one `--set=shake:0` row (invalid).
- [ ] **Task 3: The gate and the table in `core/fx.gd` (AC: 1, 2).**
  - [ ] `reduce_flashing()`, `shake_on()`, `reduced_motion()` read `Game.settings`.
  - [ ] Consts `INVULN_BLINK_HZ := 2.5`, `EYE_PULSE_HZ := 2.0`, `STEADY_ALPHA := 0.5`; an `enum Kind { ONCE, PULSE, BLINK }`; `EFFECTS` rows for `pogo_sparks`, `popup`, `camera_shake`, `light_kick`, `invuln_blink`, `lurker_eye_pulse` (D3).
  - [ ] Helpers: `blink_alpha(remaining: float) -> float` (1.0 or 0.0 at 2.5 Hz; `STEADY_ALPHA` under reduce flashing; 1.0 at `remaining <= 0`) and `pulse(t: float, hz: float) -> float` (0..1 sine).
- [ ] **Task 4: Move the readers onto the gate (AC: 2, 3, 4, 5).**
  - [ ] `player.gd` `_tick_timers`: replace the `visible` toggle with `_sprite.modulate.a = Fx.blink_alpha(_invuln)` (D4). Keep `visible` untouched.
  - [ ] `lurker.gd`: delete `EYE_PULSE_HZ`; the telegraph uses `0.55 + 0.45 * Fx.pulse(...)`-equivalent through `Fx.EYE_PULSE_HZ` (same curve as today: `0.55 + 0.45 * sin(_t * TAU * hz)`). `test_tuning` row `lurker.eye_pulse_hz` moves `home` to `res://scripts/core/fx.gd` (D11).
  - [ ] `Fx.pop`: half count and half max scale under `reduce_flashing()` (D5).
  - [ ] `Fx.popup`: no `position:y` tween under `reduced_motion()`; the fade is unchanged.
  - [ ] `camera_rig.gd`: `kick()` returns early when `not Fx.shake_on()`; `_physics_process` zeroes `_shake` and `offset` when off (D7). Update the 1.16 comment on `kick()`.
- [ ] **Task 5: Warm-up (AC: 6).** `Fx.warm_up(room: Node)`; one call in `World._swap_room()` after `_room_holder.add_child(room)`. Probe first (D10) and record the result under Verified facts.
- [ ] **Task 6: Lint `a11y_gate` (AC: 1).** Row, firing samples (`actors/player.gd` reading `Game.settings.reduce_flashing`; `world/camera_rig.gd` reading `Game.settings.shake`; `ui/gutters.gd` naming `&"reduced_motion"`), near-misses (`core/fx.gd`, `rules/settings.gd`, `var _shake := 0.0`, `kick(`, a comment-only mention if the rule scans code only). Docs table row (D9).
- [ ] **Task 7: Tests (AC: 2–6, 8).**
  - [ ] `test_fx`: the gate readers follow `Game.settings` (set, read, `Game.reset_for_tests()` after); the `EFFECTS` table checks; the sampling checks for blink and pulse (default and reduce-flashing: steady alpha never changes); `pop` counts and scales both ways; `popup` rises by default and stays put under reduced motion; the reflection check; `warm_up` adds three children to a parent, with the three materials, all freed within a second.
  - [ ] `smoke_world` (or a new `smoke_a11y.gd`, D11): in `m1_shaft`, with `shake` false, a pogo hit leaves `offset == ZERO` for 30 ticks while a hitstop request is active and the crawler's sparks appear under the room; with `shake` true the same hit moves `offset` (existing check). Turning `shake` off mid-shake zeroes `offset` the next tick. A crawler knock with `reduce_flashing` on keeps the player sprite at `STEADY_ALPHA` and visible for the whole invulnerability.
  - [ ] Red-check every new check (D13).
- [ ] **Task 8: Docs (AC: 9; D12).**
- [ ] **Task 9: Laptop check (human gate, AC: 6).** HALT for sonlm: the debug web build (`tools/export.sh`), `?room=perf_worst&perf`, Firefox on the Intel iGPU and the laptop's Chrome, recording `worst … at … s` in `docs/perf.md` next to the 1.15 rows; plus a look with `?set=reduce_flashing:true`, `?set=shake:false` and `?set=reduced_motion:true` in `m1_shaft` (sparks smaller, steady transparency after a crawler hit, no shake, popups stay put). The agent records no numbers and claims no feel; report "tests green; needs a feel check on the laptop".

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
- To fill in during dev: the alpha-cull probe result (D10).

### References

- Story source: `_bmad-output/planning-artifacts/epics.md` → Story 1.16 (FR38, NFR8, AR46, AR57, UX-DR125–UX-DR128).
- GDD: Combat damage table (crawler contact "0.6 s invulnerable (blinking at 2.5 Hz)"), Predators → Lurker telegraph ("pulse at 2 Hz"), Feel rules ("Freeze frames and sparks on every pogo hit", "Screen shake can be turned off"), Accessibility ("Flash safety").
- UX: `EXPERIENCE.md` → Game Feel & Juice (reduce flashing and reduced motion tables), Accessibility Floor; `DESIGN.md` → Do's and Don'ts (flash cap).
- Architecture: `game-architecture.md` → UI → Accessibility gate; Consistency Rules → Accessibility; Project Structure (`core/fx.gd` reads the accessibility gate).
- `docs/perf.md` → Known first-second hitch; `docs/devlog/cp1.md`.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

- Story created 2026-11-21: ultimate context engine analysis completed - comprehensive developer guide created.

### File List
