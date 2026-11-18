# The Unbroken Chain — Component Inventory

**Date:** 2026-11-11 · **Scope:** every script, scene and asset in `game/` and `tools/`

Tuning values are the M1 playtested values. The GDD Game Mechanics tables mirror them. When you change one, change both.

## Gameplay Components

### ChainState — `scripts/rules/chain_state.gd` (`RefCounted`, pure logic)

The core rules: chain count, light radius, Blade Bloom and embers. It has no scene dependencies.

| Member | Kind | Notes |
|---|---|---|
| `changed(count)` | signal | Emitted only when the count really changes |
| `banked(amount)` | signal | Emitted by `break_chain()` when `held > 0` |
| `count`, `held`, `snuffed`, `clinging` | state | |
| `add_hit()` | method | No-op while snuffed; caps at `MAX_CHAIN`; always pays `ember_value` |
| `break_chain()` | method | Safe end: bank, then reset |
| `lose() -> int` | method | Death: drop held, reset, return the amount lost |
| `set_snuffed(bool)` | method | `true` also breaks the chain |
| `set_clinging(bool)` | method | Pauses: count and held kept, light → base |
| `light_radius()`, `bloom_scale()` | query | |
| `ember_value(link)`, `radius_for(n)`, `bloom_for(n)` | static | The curves (testable without an instance) |

| Constant | Value |
|---|---|
| `MAX_CHAIN` | 20 |
| `BASE_RADIUS` / `RADIUS_GAIN` / `SNUFF_RADIUS` | 40 / 22 per √link / 12 px |
| `BASE_BLOOM` / `BLOOM_GAIN` | 1.0 / 0.18 per √link |

### Player — `scripts/actors/player.gd` + `scenes/actors/player.tscn` (`CharacterBody2D`, `class_name Player`)

**Signals:** `died`, `chain_changed(count)`. **Public:** `chain`, `is_dead`, `light_radius()`, `die()`. **Group:** `player`.

**Scene nodes:**

| Node | Type | Setup |
|---|---|---|
| Sprite | Sprite2D | `player.png` 16×24 |
| Body | CollisionShape2D | 10×20, offset y +2; layer 2, mask 1 |
| Light | PointLight2D | amber `#ffd27a`, energy 1.4, `light.png` |
| Slash | Area2D | 22×16 box at x +14; mask 4 (enemies); unshaded `slash.png` |
| Pogo | Area2D | 26×24 box at y +18; mask 4; the slash sprite rotated 90° |
| Hurtbox | Area2D | 8×18; mask 12 (enemies + predators) |

**Tuning keys (`rules/tuning.gd`)**, read each tick through `Game.tuning.f(&"key")`:

| Group | Values |
|---|---|
| Run | `run_speed` 110, `run_accel` 900, `air_accel` 1500 |
| Gravity | `gravity` 900, `fall_gravity_scale` 0.6, `max_fall` 210 |
| Jump | `jump_velocity` −330, `jump_cut` 0.45, `coyote_time` 0.08, `jump_buffer` 0.10 |
| Dash | `dash_speed` 260, `dash_time` 0.12 (air only, once per airtime; a pogo refills it) |
| Cling | `cling_grace` 1.0, `cling_slide` 18, `wall_kick_x` / `wall_kick_y` 150 / −260, `kick_lock` 0.15 |
| Combat | `pogo_velocity` −300, `slash_active` 0.12, `pogo_armed` 0.22, `attack_cooldown` 0.22, `hitstop` 0.075 |
| Damage | `knockback_x` / `knockback_y` 150 / −150, `invuln_time` 0.6 |

No camera: `World`'s `CameraRig` follows the player (Story 1.6). **Signals:** `died`, `chain_changed(count)`, `pogo_hit` (World kicks the camera). `Fx` popups go to `World.current_room()` (falling back to the parent when there is no World).

**Local consts** (no system bends them): `LIGHT_KICK` 18, `LIGHT_LERP` 10, `HITSTOP_SCALE` 0.05, `LIGHT_TEXTURE_HALF` 64. M1's `SNUFF_HOLD` 0.12 is now the default of `Settings.light_tap_window` (Story 1.8).

**Input:** the player reads only its `PlayerInput` child (`player.input`), never `Input`, and calls `input.sample()` first each tick.

### PlayerInput — `scripts/actors/player_input.gd` (`Node`, `class_name PlayerInput`, child of `Player`)

The only gameplay reader of `Input` (Story 1.8, AR34). It has no `_physics_process` of its own (a child ticks after its parent, which would lag every press a tick): `Player` calls `sample()`. It times everything in real ticks (`1 / physics_ticks_per_second` per sample), so a hitstop never stretches a buffer or the Light window, and a pause freezes them.

| Intent | Meaning |
|---|---|
| `move` | `Vector2` of raw left/right and up/down strengths, each zeroed below `MOVE_DEADZONE` 0.2 |
| `jump_held`, `dash_held`, `cling_held` | key down this tick (`cling_held` = `jump_held` until the 1.35 toggle) |
| `down_held` | ↓ at or past 0.2 on its own, for the wall drop (↑ is also Jump, so `move.y` would cancel while clinging on ↑) |
| `jump_released` | Jump went up this tick: the jump cut keeps M1's release edge |
| `snuff_active` | Light held past `Settings.light_tap_window` (0.12 / 0.2 / 0.3 s: held tick 8 / 12 / 18), on until release. A hold starts on any held tick, so Light held through a pause or a respawn still Snuffs |
| `jump_pressed` | a press waiting `jump_buffer` (0.10 s) of real time, until `consume(&"jump_pressed")` |
| `attack_pressed` | a press waiting `ATTACK_BUFFER` (0.10 s) of real time for the cooldown, until consumed. The cooldown runs on game time, so a press in a pogo's hitstop still runs out first, as in M1 |
| `dash_pressed`, `light_tap`, `interact` | edges, true for one sample. `light_tap` is a release inside the window (Flare Toss in 1.23); `interact` is ↓ crossing 0.6 (`INTERACT_FIRE`) on the ground with sideways < 0.2, re-armed below 0.3 (`INTERACT_REARM`) |

`consume(intent)` clears a waiting press or an edge (the Player consumes the Jump press that starts a cling); `lock()` turns every intent off and clears buffers and the Light machine (a held Snuff ends); `unlock()` lets held keys count again, while a press, a Light hold and interact need a fresh press; `is_locked()`.

### Crawler — `scripts/actors/crawler.gd` + `scenes/actors/crawler.tscn` (`CharacterBody2D`, `class_name Crawler`)

"Chain fuel." Layer 4, mask 1, body 14×8, `EdgeRay` 10 px down. **Group:** `enemy`. **API:** `take_hit()` (marks its cell killed on `Game.dive` when it has one, spark burst, free), `reset_phase()`. **Per instance:** `hover`, `room_id`, `cell` (set by the room build before `add_child`; a crawler spawned any other way has no cell and is never remembered).

| Mode | Behaviour | Tuning keys (`rules/tuning.gd`) |
|---|---|---|
| Walker (`c`) | Gravity; turns at a wall or a missing floor | `crawler_walk_speed` 25, `crawler_gravity` 900 |
| Hoverer (`h`) | Ignores physics; sine drift around home; phase from position | `crawler_hover_drift` 10 px, `crawler_hover_period` 2.4 s |

### Lurker — `scripts/actors/lurker.gd` + `scenes/actors/lurker.tscn` (`Area2D`, `class_name Lurker`)

The light-drawn predator. Layer 8, circle radius 7, `monitoring = false`. **Group:** `predator`. **Public:** `state`, `senses(player)`.

```
IDLE ──sensed──► TELEGRAPH ──timer 0.9 s──► HUNT ──unsensed 0.6 s──► RETURN ──at home──► IDLE
                    │ lost scent                                       │ sensed
                    └──► IDLE / RETURN                                 └──► TELEGRAPH
```

- **Senses** when: the player is alive, `light_radius() ≥ 80`, the distance is ≤ radius × 1.6, and the lurker is inside `World.play_rect()` (the play area between the gutters) minus an 8 px margin; with no World it never notices.
- **Drops a dead target:** a telegraph or hunt on a dead or freed player goes to RETURN at once (Pillar 2: a hunt never carries over a death).
- **Lethal** only when `monitorable` is true, which is HUNT *and* sensed. Losing the scent is harmless at once.
- **Look:** unshaded eyes open from a slit over 0.2 s, pulse at 2 Hz, and the body shivers. A red `PointLight2D` glow follows the eye alpha.

| Tuning keys (`rules/tuning.gd`) | Value |
|---|---|
| `lurker_telegraph_time` | 0.9 s (never below 0.75; `Spec.TELEGRAPH_MIN` checks it from 1.9) |
| `lurker_lose_track_time` | 0.6 s |
| `lurker_hunt_speed` / `lurker_hunt_accel` / `lurker_return_speed` | 95 / 220 / 40 |

| Local const | Value |
|---|---|
| `NOTICE_MIN_RADIUS` / `NOTICE_FACTOR` / `SCREEN_MARGIN` | 80 px / 1.6 / 8 px (the sensing rule; moves to `rules/sensing.gd` in 1.20) |
| `EYE_PULSE_HZ`, `EYE_OPEN_TIME`, `GLOW_ENERGY` | 2.0, 0.2, 1.3 (presentation) |

### World — `scripts/world/world.gd` + `scenes/world/world.tscn` (`Node2D`, `class_name World`, main scene)

The game scene (Story 1.6). Group `world`. Boots `Game` when it is the current scene and applies the ambient from `Settings.brightness`. Every room goes through one swap path (Story 1.7): `RoomLoader.load_room(id, Game.dive)` (killed cells skipped), the old room `remove_child` + `queue_free`, the player placed (or spawned), camera limits + `snap()`, `Game.slot.visit(id)`, `room_entered`. The first room is the respawn point (`Game.dive.respawn_room`/`respawn_entry`, else `start_room`'s `spawn`). Exits are polled in `_physics_process`: the body centre past the floor or ceiling crosses that side's exit; a live chain is banked first (`break_chain()`), then `enter_room(target, entry)` (deferred). Arriving from above keeps the velocity; from below stands still beside the hole. A death waits `RESPAWN_DELAY` 0.6 s (pauses with the tree, ignores the time scale), clears the Clock and rebuilds the respawn room with a fresh player, with no reload; a bad respawn point falls back to `start_room`'s `P`. A swap queued before the player died is cancelled (no build, visit or `room_entered`), and `enter_room()` is ignored while the player is dead.

| Node | Type | Role |
|---|---|---|
| Darkness | CanvasModulate | `AMBIENT_LEVELS` [0.07, 0.16, 0.28, 0.45] × `AMBIENT_TINT`, picked by `Settings.brightness` |
| RoomHolder | Node2D | At the origin; holds the current room |
| Player | player.tscn | Spawned in code, kept right after `RoomHolder` |
| Camera | Camera2D + `camera_rig.gd` | Engine smoothing off; the rig smooths (8/s) on the physics tick |
| UI | CanvasLayer (layer 10, `PROCESS_MODE_ALWAYS`) | `Gutters` then `ScreenRouter`, so screens draw over the gutters |

**API:** `enter_room(room_id, entry)`, `play_rect()`, `current_room()`, `var start_room` (set before `add_child`), `signal player_spawned(player)`, `signal room_entered(room_id)`. **Consts:** `START_ROOM`, `RESPAWN_DELAY`, `AMBIENT_LEVELS`, `AMBIENT_TINT`.

### CameraRig — `scripts/world/camera_rig.gd` (`Camera2D`, `class_name CameraRig`)

`follow(body: CharacterBody2D)`, `snap()` (on the target at once, no lead or shake, `reset_physics_interpolation()`), `kick(amount)` (the only shake entry; the `Settings.shake` gate arrives in 1.16), `apply_limits(bounds)`, `play_rect()` (from the rig's own clamped centre, never the shake). Physics interpolation runs a Camera2D on the physics tick, so the rig does too (`process_callback` PHYSICS from `_init`) and does its own smoothing (`SMOOTH_SPEED` 8, scaled delta) and clamping; the lead and shake decay run on real time. The only `randf` in `scripts/`.

| Const | Value |
|---|---|
| `GUTTER_WIDTH` / `PLAY_WIDTH` | 60 / 360 px (UX DESIGN.md) |
| `LOOK_AHEAD` / `LEAD_SPEED` | 70 px / 140 px/s (FR3, M1) |
| `POGO_SHAKE` / `SHAKE_DECAY` | 2.5 px / 20 px/s (M1) |

### UI — `scripts/ui/`

| Script | Role |
|---|---|
| `gutters.gd` (`Gutters`, Control) | Two flat `ColorRect` strips at screen x 0–60 and 420–480, `PLACEHOLDER` `#07060b` (DESIGN.md `gutter-violet`) until the palettes (1.18) and the HUD (1.25) |
| `screen_router.gd` (`ScreenRouter`, Control) | `open(screen)` replaces the current screen, never stacks; `close()`; `current()`. No screens yet |

### Rooms — `scripts/world/`

Rooms as text (Story 1.5). The format, legend, validator errors and Room API are in [rooms.md](./rooms.md).

| Script | Role |
|---|---|
| `room_legend.gd` (`RoomLegend`) | The one definition of every grid char: `#` `.` `P`, and `SPAWNS` (`c`, `h`, `L` with their scene and args; `c` and `h` are `killable`, `L` is `in_wall`) |
| `room_loader.gd` (`RoomLoader`, static) | `parse()`, the pure `validate()` (errors as `file:row:col`), `load_room_from_path(path, dive)`, `load_room(id, dive)` through an index of `res://rooms/**/*.txt` (tests add roots with `add_root(dir)`), `down_entry_cell()`, and the build (killable spawns get `room_id` + `cell`; with a `dive`, its killed cells are skipped). Caches the TileSet and the unshaded rim material as statics |
| `room.gd` (`Room`, `Node2D`) | One built room: `Backdrop`, `Walls` (TileMapLayer), `Rims`, spawned entities. `spawn(scene, pos, args)`, `bounds()`, `entry_position()` / `has_entry()` / `exit(side)` (exits carry `entry_cell`), `is_solid()`, `cell_centre()` |

### Core — `scripts/core/`

| Script | Kind | Role |
|---|---|---|
| `game.gd` | autoload `Game` (no `class_name`) | Holds refs to session state, never rules: `settings`, `slot`, `dive`, `tuning`, `clock` (same instances all session; replacing one asserts) and `store`. `boot()` (once, from the entry scene) loads `settings.json` and arms its writes, at most one per frame (a file that can't be opened or is from a newer build is left untouched, and writes stay off for the session); `reset_for_tests()` resets everything in place |
| `save_store.gd` | `class_name SaveStore` (`RefCounted`), at `Game.store` | The only code that reads or writes the player's files: `read_settings()` / `write_settings()` for `user://settings.json` (`{"version": 1, "settings": {…}}`, `.tmp` then rename). `read_settings()` returns `{found, settings}`; `found` is a `SaveStore.Found` (USABLE, MISSING, CORRUPT, UNREADABLE, NEWER), which tells `Game` whether it may rewrite the file. Redirectable `dir`; never creates folders |
| `clock.gd` | `class_name Clock`, child of `Game` | The only writer of `Engine.time_scale`. `request(id, scale, seconds)` multiplies with other ids, refreshes its own id, times out on real time and pauses with the tree; `clear()`, `is_active(id)` |
| `log.gd` | static `class_name Log` | `Log.info(cat, msg)` / `Log.debug(cat, msg)` print `[cat] msg`, silent in release; `Log.enabled(cat)` guards hot paths. Categories `SAVE ROOM INPUT CLOCK LURKER WEAVER AUDIO UI` |
| `rules/tuning.gd` | `class_name Tuning` (`RefCounted`, pure); one instance at `Game.tuning` | 34 gameplay consts listed in `BASE`. `f(&"key")` returns the current value; `flag(&"key")` a gear rule switch; `apply_gear(ids)` recomputes set → add → mul and emits `changed`; `apply_gear([])` resets in place |
| `rules/gear.gd` | `class_name Gear` (pure data) | `TABLE` of `{id, stat, op, value}` rows (`set` / `add` / `mul` / `flag`); empty until E5 |
| `rules/settings.gd` | `class_name Settings` (`RefCounted`, pure); `Game.settings` | Global settings: `brightness` and `light_tap_window` (0.12 / 0.2 / 0.3 s, Story 1.8) so far. `set_value(&"key", v)` emits `changed(key)` on a change; `SCHEMA` lists each key, its default and its choices |
| `rules/slot_state.gd` | `class_name SlotState` (`RefCounted`, pure); `Game.slot` | Per-slot state: `best_chain`, `deaths`, `difficulty` (`&"easy"`/`&"normal"`/`&"hard"`), story flags (`set_flag()` / `has_flag()`), visited rooms (`visit()` / `has_visited()`, `visits_changed`; Story 1.7). `to_dict()` becomes save format `slot_v1` at 1.41 |
| `rules/dive_state.gd` | `class_name DiveState` (`RefCounted`, pure); `Game.dive` | Per-dive state: `carried` embers (`add_carried()`), the respawn point (`set_respawn()`), killed enemies (`mark_killed()` / `is_killed()`, never saved) |

### Fx — `scripts/core/fx.gd` (static, `class_name Fx`)

| Function | Effect |
|---|---|
| `pop(parent, pos, amount=14)` | One-shot amber `CPUParticles2D` burst (0.35 s) |
| `chain_popup(parent, pos, count, embers)` | Floating text like `x5  +5`; bigger from chain 5 |
| `popup(parent, pos, text, color, size=8)` | Floating label with an outline; rises 14 px and fades over 0.6 s |

Everything is unshaded and frees itself.

## Input Actions (`project.godot`)

| Action | Key(s) |
|---|---|
| `move_left` / `move_right` / `move_up` / `move_down` | ← → ↑ ↓ |
| `jump` | Z, ↑ |
| `attack` | X |
| `dash` | C |
| `light` | V |

Keyboard only, bound by physical keycode. No function keys (the M1 shaft and its F1/F3 were deleted in Story 1.7).

## Asset Inventory

| PNG (`game/art/`) | Size | Source grid | Used by |
|---|---|---|---|
| `player.png` | 16×24 | `player.txt` | Player/Sprite |
| `crawler.png` | 16×16 | `crawler.txt` | Crawler/Sprite |
| `lurker.png` | 24×24 | `lurker.txt` | Lurker/Sprite |
| `lurker_eyes.png` | 24×24 | `lurker_eyes.txt` | Lurker/Eyes (unshaded) |
| `slash.png` | 24×16 | `slash.txt` | Player Slash and Pogo sprites |
| `tile.png` | 16×16 | `tile.txt` | Walls tileset |
| `light.png` | 128×128 | generated (radial gradient) | Player light, lurker glow |

Total: 7 PNGs, about 5.6 KB. No audio, fonts, shaders or 3D assets. The HUD uses Godot's default font.

**Palette (`tools/sprites/palette_edge.txt`, "Edge of the Abyss", layer 1):**

| Key | Hex | Role |
|---|---|---|
| `0` | `#0d0b14` | deepest dark |
| `1` | `#2a2440` | outline / background violet |
| `2` | `#4f5d75` | body mid-tone |
| `3` | `#a9b4c2` | highlight (also the ledge-rim colour) |
| `L` | `#ffd27a` | chain-light amber — the same in every layer |
| `E` | `#d9473f` | lurker red |
| `e` | `#ffb08a` | lurker eye hot core |

## Test Components

| Script | Tests | Run |
|---|---|---|
| `tests/test_chain_state.gd` | 10 test functions on ChainState | headless |
| `tests/test_log.gd` | `Log.format`, the category list, `enabled` / `set_enabled` | headless |
| `tests/test_clock.gd` | Clock: ids multiply, re-request refreshes, real-time expiry, pause freeze, `_exit_tree` and player death clear | headless |
| `tests/test_tuning.gd` | Tuning API (set → add → mul in every gear order, flags, `changed`, reset in place), the telegraph floor and the hover period under every combination of gear (`Spec`), and the regression fixture: all 44 M1 exports keep their value, plus the boxes, chain curve, bloom and hitstop depth | headless |
| `tests/test_state.gd` | Settings, SlotState and DiveState (signals, fallbacks, save shapes, JSON round trips), the `Game` refs and `reset_for_tests()`, and `settings.json` through `SaveStore` (≈ 165 checks) | headless |
| `tests/test_room_loader.gd` | The room validator (fixtures in `tests/rooms/` and inline texts, the `cling=` key), the build and the `Room` API, and the real `m1_shaft`'s pins (counts, ledge rows, exits) | headless |
| `tests/test_room_sweep.gd` | The pure room sweeps on inline grids, each with a sample that fires and a near-miss (58 checks) | headless |
| `tests/test_deferred_owners.gd` | Ledger scan rules, then every item in `deferred-work.md` has an owner (fails on a ledger edit, not only a code change), and fails on a ledger format it can't read (bmad-loop's `### DW-n`, `status:` lines, tables, or sections with no list items) | headless |
| `tests/test_lint.gd` | The architecture lint over `scripts/` (12 rules, each with sample lines; stricter than AR48 on purpose: every `KEY_*`, wider `raw_input`, `random` and `rules_purity`, new `tests_ref` and `state_write`) and the `spec.gd` citations; see the development guide | headless |
| `tests/smoke_rooms.gd` | Every room file: validation, unique ids, exit links, spine falls, cling stretches, hazard pits, the arrival from below, and the lurker guarantees (per lurker and per room) against `Spec` (76 checks on `m1_shaft`) | headless |
| `tests/smoke_bot.gd` | The descent bot in every spine room: chain ≥ 5, no live chain at an exit, reaches the down exit alive (~28 s on `m1_shaft`) | headless |
| `tests/smoke_moves.gd` | The M1 move checks on `m1_shaft`: pogo, landing, jump height, wall cling, the Snuff ending on release (15 checks) | headless |
| `tests/smoke_world.gd` | World: no boot, the tree, framing (limits, play rect, gutters), state wiring, popups in the room, death and respawn without a reload, a lurker behind a gutter, a hunt over a death, the R16 bottom loop, `ScreenRouter`, source checks | headless |
| `tests/smoke_room_swap.gd` | Room swaps between `tests/rooms/swap/t_swap_a` and `t_swap_b`: deferral, the chain backstop, arrival from above and below, killed cells across swaps and a cross-room respawn, interpolation on | headless |
| `tests/smoke_player_input.gd` | `tests/rooms/input/t_input.txt`: M1 movement pinned (run, coyote, jump buffer, air dash), the Light windows on both sides of each boundary, the Snuff latch, Light across a pause and a hitstop, real-time buffers, the attack buffer, ↓ interact, the wall drop on ↑, the cling press, `lock()` / `unlock()` | headless |
| `tests/screenshot.gd` | 2 screenshots of `world.tscn` (gutters, darkness, framing) | needs a renderer |
| `tests/spec.gd` | Not a test: the GDD's guarantees as constants (`TELEGRAPH_MIN`, `BOT_MIN_CHAIN`, `BASE_LIGHT`, `NOTICE_MIN_RADIUS`, `LEDGE_FALL_TIME`, `LEDGE_FALL_MAX`); tests `preload` it | — |
| `tests/room_harness.gd` | Not a test: `build(parent, room_id)` (or `build_from_path(parent, path)`) loads a room standalone with a test player, a `CameraRig` and a stub `World` (`play_rect()`, `current_room()`); `free_all()` | — |
| `tests/room_sweep.gd` | Not a test: the pure room sweeps (`room_files`, `is_dev`, `record`, `ledge_rows`, `safe_rows`, `spine_gap_errors`, `exit_fall_errors`, `stretch_width_errors`, `hazard_pit_errors`, `duplicate_id_errors`, `link_errors`, `arrival_errors`) | — |

Helpers worth reusing: `place(pos)` (teleport and snap the camera) and `frames(n)` / `seconds(s)` (physics-frame waits) in every smoke test; `smoke_rooms.gd`'s `_build(rec)` / `_free()` (a fresh room per scenario, waiting until the old stub `World` is gone), `_lurkers()` (this room's lurkers sorted by row, then column) and `_only(lurker)` (pause every other lurker); `smoke_moves.gd`'s `_hovers()` (hovering crawlers sorted by depth).
