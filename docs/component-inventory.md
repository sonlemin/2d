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
| Camera | Camera2D | smoothing 8; limits set by Shaft |

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

**Local consts** (no system bends them): `SHAKE` 2.5, `LOOK_AHEAD` 70 (both move to `camera_rig.gd` in 1.6), `LIGHT_KICK` 18, `LIGHT_LERP` 10, `SNUFF_HOLD` 0.12 (becomes `Settings.light_tap_window` in 1.8), `HITSTOP_SCALE` 0.05, `LIGHT_TEXTURE_HALF` 64.

### Crawler — `scripts/actors/crawler.gd` + `scenes/actors/crawler.tscn` (`CharacterBody2D`, `class_name Crawler`)

"Chain fuel." Layer 4, mask 1, body 14×8, `EdgeRay` 10 px down. **Group:** `enemy`. **API:** `take_hit()` (spark burst + free), `reset_phase()`. **Per instance:** `hover` (set by the spawner before `add_child`).

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

- **Senses** when: the player is alive, `light_radius() ≥ 80`, the distance is ≤ radius × 1.6, and the lurker is inside the viewport minus an 8 px margin.
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

### Shaft — `scripts/shaft.gd` + `scenes/shaft.tscn` (`Node2D`, main scene)

Builds the level from `LAYOUT`, draws the debug HUD from `Game` state and handles hotkeys. It has no session statics: what survives a death lives in `Game` (Story 1.4). See [Architecture → Level Data](./architecture.md#level-data) and [State Management](./architecture.md#state-management).

| Node | Type | Role |
|---|---|---|
| Darkness | CanvasModulate | Ambient darkness: 4 levels, picked by `Settings.brightness` (F1 cycles it) |
| Background | ColorRect | 480×1680, z −10, palette `#2a2440` |
| Walls | TileMapLayer | Tileset assigned in code |
| Player | player.tscn | Spawned at `P` |
| Debug/Label | Label | HUD: `embers, held, chain (best), light, SNUFF, depth, alert, deaths`; turns red while a lurker is awake |

**Hotkeys:** F1 brightness (saved in `settings.json`) · F3 restart from the top. **Constants:** `TILE` 16, `RESPAWN_DELAY` 0.6, `AMBIENT_LEVELS` [0.07, 0.16, 0.28, 0.45].

### Core — `scripts/core/`

| Script | Kind | Role |
|---|---|---|
| `game.gd` | autoload `Game` (no `class_name`) | Holds refs to session state, never rules: `settings`, `slot`, `dive`, `tuning`, `clock` (same instances all session; replacing one asserts) and `store`. `boot()` (once, from the entry scene) loads `settings.json` and arms its writes, at most one per frame; `reset_for_tests()` resets everything in place |
| `save_store.gd` | `class_name SaveStore` (`RefCounted`), at `Game.store` | The only code that reads or writes the player's files: `read_settings()` / `write_settings()` for `user://settings.json` (`{"version": 1, "settings": {…}}`, `.tmp` then rename). Redirectable `dir`; never creates folders |
| `clock.gd` | `class_name Clock`, child of `Game` | The only writer of `Engine.time_scale`. `request(id, scale, seconds)` multiplies with other ids, refreshes its own id, times out on real time and pauses with the tree; `clear()`, `is_active(id)` |
| `log.gd` | static `class_name Log` | `Log.info(cat, msg)` / `Log.debug(cat, msg)` print `[cat] msg`, silent in release; `Log.enabled(cat)` guards hot paths. Categories `SAVE ROOM INPUT CLOCK LURKER WEAVER AUDIO UI` |
| `rules/tuning.gd` | `class_name Tuning` (`RefCounted`, pure); one instance at `Game.tuning` | 34 gameplay consts listed in `BASE`. `f(&"key")` returns the current value; `flag(&"key")` a gear rule switch; `apply_gear(ids)` recomputes set → add → mul and emits `changed`; `apply_gear([])` resets in place |
| `rules/gear.gd` | `class_name Gear` (pure data) | `TABLE` of `{id, stat, op, value}` rows (`set` / `add` / `mul` / `flag`); empty until E5 |
| `rules/settings.gd` | `class_name Settings` (`RefCounted`, pure); `Game.settings` | Global settings: `brightness` so far. `set_value(&"key", v)` emits `changed(key)` on a change; `SCHEMA` lists each key, its default and its choices |
| `rules/slot_state.gd` | `class_name SlotState` (`RefCounted`, pure); `Game.slot` | Per-slot state: `best_chain`, `deaths`, `difficulty` (`&"easy"`/`&"normal"`/`&"hard"`), story flags (`set_flag()` / `has_flag()`). `to_dict()` becomes save format `slot_v1` at 1.41 |
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

Keyboard only, bound by physical keycode. F1 and F3 are read directly in `Shaft._unhandled_input`, not through actions.

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
| `tests/test_tuning.gd` | Tuning API (set → add → mul in every gear order, flags, `changed`, reset in place), `rules/` purity, and the regression fixture: all 44 M1 exports keep their value, plus the boxes, chain curve, bloom and hitstop depth | headless |
| `tests/test_deferred_owners.gd` | Ledger scan rules, then every item in `deferred-work.md` has an owner (fails on a ledger edit, not only a code change) | headless |
| `tests/smoke_shaft.gd` | 9 scenario tests (≈ 28 checks) on the real shaft, including a pathing bot | headless |
| `tests/screenshot.gd` | 2 screenshots | needs a renderer |

Helpers in `smoke_shaft.gd` worth reusing: `place(pos)` (teleport and snap the camera), `frames(n)` / `seconds(s)` (physics-frame waits), `set_lurkers_active(on)`, `_hovers()` (hovering crawlers sorted by depth).
