---
title: 'M1 core-loop prototype: one shaft, pogo chain = light = danger'
type: 'feature'
created: '2026-11-08'
status: 'done'
baseline_commit: '49a17a3169f0b3ac1cb90c308757fe4297c5214c'
context:
  - '{project-root}/_bmad-output/planning-artifacts/briefs/brief-pixel_art_game-2026-11-08/addendum.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Nothing is built yet, so the brief's core hypothesis ("does a long chain feel both tempting and dangerous?") is untested.

**Approach:** Create a Godot 4.7 project with one vertical shaft where the player pogos off enemies to build a chain that grows the slash (Blade Bloom) and the light radius (Chain-Light). A light-drawn predator telegraphs and then hunts large light. Snuff and landing break the chain. Placeholder sprites come from a tiny text-grid → Pillow pipeline.

## Boundaries & Constraints

**Always:** GDScript only. Internal resolution 480×270 with integer scaling and nearest filtering. Keys: arrows move, Z jump, X attack, Down+X pogo, C dash, V (hold) Snuff. Chain logic lives in a pure, scene-free class so headless tests can cover it. All tuning constants are exported or grouped in one place. The predator always telegraphs before attacking (an eye-glow and sound placeholder; a visible cue is enough). No more than 3 flashes per second.

**Ask First:** Adding any third-party addon (GUT etc.). Changing the key layout. Adding mechanics outside the list (Flare Toss, wall cling, swing, currency).

**Never:** Flare Toss, wall cling, Field Journal, HUD polish, Lift Stations, procedural generation, controller mapping. Do not commit generated build exports.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Pogo hit | Airborne, Down+X connects with enemy/hazard | chain +1, player bounces up, Bloom and light grow | N/A |
| Land | chain > 0, touches floor | chain → 0, light and Bloom reset | N/A |
| Snuff | Hold V while chain > 0 | chain → 0, light shrinks to minimum while held; predators lose track | N/A |
| Snuff at 0 | Hold V, chain = 0 | light dims; no error | N/A |
| Chain cap | chain at max (e.g. 20) | further pogos keep bouncing; radius and Bloom clamp | N/A |
| Predator notice | light radius ≥ notice threshold | predator telegraphs ≥ 0.75 s, then pursues | Returns to idle if light drops below the threshold |
| Predator hit | Predator touches player | player dies, respawns at shaft top, chain 0 | N/A |

</frozen-after-approval>

## Code Map

- `game/project.godot` -- Godot project root (480×270, `viewport` stretch with integer scale for pixel-perfect output, input map, GL Compatibility renderer).
- `game/scripts/chain_state.gd` -- pure `RefCounted` chain logic: count, break, curves for radius and Bloom.
- `game/scenes/player.tscn` + `game/scripts/player.gd` -- CharacterBody2D: run, jump, dash, slash, pogo, Snuff, PointLight2D.
- `game/scenes/enemies/crawler.tscn` + `game/scripts/crawler.gd` -- walking (`c`) or hovering (`h`) pogo target, killed by slash or pogo.
- `game/scenes/enemies/lurker.tscn` + `game/scripts/lurker.gd` -- light-drawn predator with idle → telegraph → hunt → lose-track states.
- `game/scenes/shaft.tscn` + `game/scripts/shaft.gd` -- the test level: TileMapLayer walls, crawlers placed down the shaft, CanvasModulate darkness, respawn point, debug chain label.
- `tools/sprites/*.txt`, `tools/sprites/palette_edge.txt`, `tools/build_sprites.py` -- text grids → PNG in `game/art/`.
- `game/tests/run_tests.gd` -- headless SceneTree test runner for `chain_state.gd`.
- `game/tests/smoke_shaft.gd` -- headless integration test: real pogo input, landing, a pogo bot proving 5+ chain reachability, lurker telegraph/hunt/lose/kill.
- `game/tests/screenshot.gd` -- renders under `xvfb-run` and saves PNGs for visual review.

## Tasks & Acceptance

**Execution:**
- [x] `tools/build_sprites.py` + `tools/sprites/` -- Pillow script turns char-grid files plus a palette into PNGs (player 16×24, crawler 16×16, lurker 24×24, tile 16×16, light gradient) -- starts the brief's art pipeline.
- [x] `game/project.godot` -- project settings, input actions, main scene `shaft.tscn` -- foundation.
- [x] `game/scripts/chain_state.gd` -- `add_hit()`, `break_chain()`, `count`, `light_radius()`, `bloom_scale()`, signal `changed` -- testable core.
- [x] `game/tests/run_tests.gd` -- assert the I/O matrix rows that belong to chain logic (hit, land, snuff, cap, curves monotonic) -- regression net.
- [x] `game/scripts/player.gd` + scene -- movement, pogo bounce, slash hitbox scaled by Bloom, light scaled by radius, Snuff hold, death/respawn signal -- the loop.
- [x] `game/scripts/crawler.gd` + scene -- pogo-able enemy -- chain fuel.
- [x] `game/scripts/lurker.gd` + scene -- predator states, notice-radius check against the player's light, telegraph cue -- danger.
- [x] `game/scripts/shaft.gd` + scene -- tall shaft (about 6 screens), enemy placement, darkness, camera follow, debug label -- playable whole.
- [x] `.gitignore` -- ignore `game/.godot/` and exports.

**Acceptance Criteria:**
- Given the project, when `godot --headless --path game --import` then the test runner runs, then it exits 0 with all tests passing.
- Given the player at the shaft top, when they pogo through 5+ crawlers without landing, then the slash and light visibly grow with each hit.
- Given a large light radius, when a lurker is within notice range, then a visible telegraph plays before it moves toward the player.
- Given the lurker is hunting, when the player lands or Snuffs, then the lurker loses track within ~1 s.
- Given a headless screenshot capture, when the shaft loads, then the PNG shows a darkened scene with a lit player.

## Design Notes

The chain → radius and chain → Bloom curves are the main tuning knobs (addendum: "tuning constants to set in the MVP"). Keep them as small pure functions in `chain_state.gd` so tuning is a one-line change. The default is a diminishing-returns curve, e.g. `base + k * sqrt(chain)`, clamped at the cap.

The lurker's notice check uses distance ≤ player light radius × factor, so a bigger light literally reaches farther into the dark.

## Verification

**Commands:**
- `~/.local/bin/godot --headless --path game --script res://tests/smoke_shaft.gd` -- expected: "SMOKE PASS", exit 0.
- `xvfb-run -a ~/.local/bin/godot --path game --rendering-driver opengl3 --script res://tests/screenshot.gd -- <out_dir>` -- expected: two PNGs saved.
- `~/.local/bin/godot --headless --path game --import` -- expected: no errors.
- `~/.local/bin/godot --headless --path game --script res://tests/run_tests.gd` -- expected: "ALL PASS", exit 0.
- `python3 tools/build_sprites.py` -- expected: PNGs written to `game/art/`.

**Manual checks (if no CLI):**
- On the laptop: pull, open `game/` in Godot, and play the shaft; check the feel of the pogo chain and the predator.

## Suggested Review Order

**Chain = Light = Danger (the core rule)**

- Start here: scene-free chain rules; landing/Snuff break it, snuffed hits add nothing.
  [`chain_state.gd:41`](../../game/scripts/chain_state.gd#L41)

- The two tuning curves: diminishing-returns light and Bloom, clamped at the cap.
  [`chain_state.gd:54`](../../game/scripts/chain_state.gd#L54)

- Notice rule: big light AND inside its reach AND on-screen (Pillar 2).
  [`lurker.gd:43`](../../game/scripts/lurker.gd#L43)

- Contact kills only while hunting; idle lurkers are harmless until telegraphed.
  [`lurker.gd:100`](../../game/scripts/lurker.gd#L100)

- Hunt keeps closing only while sensed, so landing/Snuff feel safe immediately.
  [`lurker.gd:76`](../../game/scripts/lurker.gd#L76)

**Pogo feel**

- Swing resolution: landing-frame pogo becomes a plain slash, one link per swing.
  [`player.gd:150`](../../game/scripts/player.gd#L150)

- Pogo hit: bounce, dash refresh, link, freeze frame.
  [`player.gd:168`](../../game/scripts/player.gd#L168)

- Hitstop via global time_scale; restored on exit so the world never stays frozen.
  [`player.gd:177`](../../game/scripts/player.gd#L177)

- Landing breaks the chain each floor frame — the ground is sanctuary.
  [`player.gd:85`](../../game/scripts/player.gd#L85)

- Crawler contact polled per frame; an active pogo on that crawler wins.
  [`player.gd:209`](../../game/scripts/player.gd#L209)

**Level assembly**

- Hand-built ASCII layout is the level; tiles/entities spawn from it.
  [`shaft.gd:14`](../../game/scripts/shaft.gd#L14)

- TileSet built in code: one stone tile with a full-square collider.
  [`shaft.gd:140`](../../game/scripts/shaft.gd#L140)

- In-wall lurkers keep their wall tile; respawn = scene reload.
  [`shaft.gd:176`](../../game/scripts/shaft.gd#L176)

**Peripherals**

- Bot proves the long run chains 8/8 with deterministic hover phases.
  [`smoke_shaft.gd:100`](../../game/tests/smoke_shaft.gd#L100)

- Idle-vs-hunting lurker contact regression.
  [`smoke_shaft.gd:176`](../../game/tests/smoke_shaft.gd#L176)

- Text grid → PNG pipeline, plus generated light gradient.
  [`build_sprites.py:79`](../../tools/build_sprites.py#L79)

- Input map, 480×270 integer viewport, nearest filtering.
  [`project.godot:1`](../../game/project.godot#L1)
