# The Unbroken Chain — Component Inventory

**Date:** 2026-11-11 (updated through Story 1.13, 2026-11-19) · **Scope:** every script, scene and asset in `game/` and `tools/`, including the export pipeline

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
| Light | `BudgetLight` (a `PointLight2D`, Story 1.12) | amber `#ffd27a`, energy 1.4, `light.png`; rank ALWAYS, so the light budget never demotes it |
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
- **Look:** unshaded eyes open from a slit over 0.2 s, pulse at 2 Hz, and the body shivers. A red glow follows the eye alpha: its `Glow` node is a `BudgetLight` of rank GLOW (Story 1.12), so past the light budget it is demoted to an additive sprite glow (same texture, colour and size, alpha following its energy).

| Tuning keys (`rules/tuning.gd`) | Value |
|---|---|
| `lurker_telegraph_time` | 0.9 s (never below 0.75; `Spec.TELEGRAPH_MIN` checks it from 1.9) |
| `lurker_lose_track_time` | 0.6 s |
| `lurker_hunt_speed` / `lurker_hunt_accel` / `lurker_return_speed` | 95 / 220 / 40 |

| Local const | Value |
|---|---|
| `NOTICE_MIN_RADIUS` / `NOTICE_FACTOR` / `SCREEN_MARGIN` | 80 px / 1.6 / 8 px (the sensing rule; moves to `rules/sensing.gd` in 1.20) |
| `EYE_OPEN_TIME`, `GLOW_ENERGY` | 0.2, 1.3 (presentation; the eye pulse rate and the shiver rate are `Fx.EYE_PULSE_HZ` 2.0 and `Fx.SHIVER_RATE` 40 rad/s since Story 1.16) |

### World — `scripts/world/world.gd` + `scenes/world/world.tscn` (`Node2D`, `class_name World`, main scene)

The game scene (Story 1.6). Group `world`. Boots `Game` when it is the current scene and applies the ambient from `Settings.brightness`. Every room goes through one swap path (Story 1.7): `RoomLoader.load_room(id, Game.dive)` (killed cells skipped), the old room `remove_child` + `queue_free`, the player placed (or spawned), camera limits + `snap()`, `Game.slot.visit(id)`, `room_entered`. The first room is the respawn point (`Game.dive.respawn_room`/`respawn_entry`, else `start_room` at `start_entry`, `spawn` by default). Exits are polled in `_physics_process`: the body centre past the floor or ceiling crosses that side's exit; a live chain is banked first (`break_chain()`), then `enter_room(target, entry)` (deferred). Arriving from above keeps the velocity; from below stands still beside the hole. A death waits `RESPAWN_DELAY` 0.6 s (pauses with the tree, ignores the time scale), clears the Clock and rebuilds the respawn room with a fresh player, with no reload; a bad respawn point falls back to `start_room` at `start_entry`. A swap queued before the player died is cancelled (no build, visit or `room_entered`), and `enter_room()` is ignored while the player is dead. In debug builds the first statement of `_ready()` adds [DevTools](#devtools--scriptsdev-debug-builds-only) with one path-string `load()` (Story 1.11).

| Node | Type | Role |
|---|---|---|
| Darkness | CanvasModulate | `AMBIENT_LEVELS` [0.07, 0.16, 0.28, 0.45] × `AMBIENT_TINT`, picked by `Settings.brightness` |
| RoomHolder | Node2D | At the origin; holds the current room |
| Player | player.tscn | Spawned in code, kept right after `RoomHolder` |
| Camera | Camera2D + `camera_rig.gd` | Engine smoothing off; the rig smooths (8/s) on the physics tick |
| UI | CanvasLayer (layer 10, `PROCESS_MODE_ALWAYS`) | `Gutters` then `ScreenRouter`, so screens draw over the gutters |
| DevTools | Node (`dev_tools.gd`), debug builds only | Added in code, first of the added children; holds the overlays (their screen marks on CanvasLayer 11, above UI), and the `Glow` / `PerfRun` nodes when `--glow=on` / `--perf` are given |
| LightBudget | Node (`light_budget.gd`, no `class_name`, `process_physics_priority` 50) | Added in code by `_ready()` (Story 1.12): applies `BudgetLight.apply()` to group `budget_light` against `light_rect()` every physics tick, after every actor (0) and before DevTools (100); runs while the player is dead or a swap waits; pausable |

**API:** `enter_room(room_id, entry)`, `play_rect()`, `light_rect()` (the light budget's rect: the rig's `view_rect()`, the whole 480 × 270 view, gutters included; a cost rule, not AR20's), `current_room()`, `var start_room` / `var start_entry` (default `&"spawn"`; set before `add_child`, or by DevTools' `--room=` inside `_ready`, before the first room is built), `signal player_spawned(player)`, `signal room_entered(room_id)`. **Consts:** `START_ROOM`, `RESPAWN_DELAY`, `AMBIENT_LEVELS`, `AMBIENT_TINT`.

### CameraRig — `scripts/world/camera_rig.gd` (`Camera2D`, `class_name CameraRig`)

`follow(body: CharacterBody2D)`, `snap()` (on the target at once, no lead or shake, `reset_physics_interpolation()`), `kick(amount)` (the only shake entry; adds nothing when `Fx.shake_on()` is false, and `_physics_process` then holds `offset` at zero, Story 1.16), `apply_limits(bounds)`, `play_rect()` (from the rig's own clamped centre, never the shake), `view_rect()` (the whole 480 × 270 view around the same centre, Story 1.12). Physics interpolation runs a Camera2D on the physics tick, so the rig does too (`process_callback` PHYSICS from `_init`) and does its own smoothing (`SMOOTH_SPEED` 8, scaled delta) and clamping; the lead and shake decay run on real time, one tick = 1/60 s (never `delta / Engine.time_scale`: a pogo's hitstop request lands earlier in the same tick, Story 1.16). The only `randf` in `scripts/`.

| Const | Value |
|---|---|
| `GUTTER_WIDTH` / `PLAY_WIDTH` | 60 / 360 px (UX DESIGN.md) |
| `LOOK_AHEAD` / `LEAD_SPEED` | 70 px / 140 px/s (FR3, M1) |
| `POGO_SHAKE` / `SHAKE_DECAY` | 2.5 px / 20 px/s (M1) |

### UI — `scripts/ui/`

| Script | Role |
|---|---|
| `gutters.gd` (`Gutters`, Control) | Two flat `ColorRect` strips at screen x 0–60 and 420–480, filled with the active zone's GUTTER role (`Game.palette`), which also sets the clear colour; re-applied on `Game.palette.changed` (Story 1.18). The HUD arrives in 1.25. Sets `theme = ThemeBuilder.theme()` in `_ready()` (Story 1.17), so the HUD inherits the game font |
| `screen_router.gd` (`ScreenRouter`, Control) | `open(screen)` replaces the current screen, never stacks; `close()`; `current()`. No screens yet. Sets `theme = ThemeBuilder.theme()` in `_ready()` (Story 1.17) |
| `theme_builder.gd` (`ThemeBuilder`, static, Story 1.17, AR40) | `theme()`: the one `Theme`, built in code from `TextStyle` and cached (no `.tres`): default font Fusion at size 8, base Label `line_spacing` 0, and Label type variations `HudValue` (8 / 8 px rows), `HudValueLarge` (16 / 16), `MenuItem` (8 / 8), `BodyLine` (8 / 12), named by the consts `HUD_VALUE`, `HUD_VALUE_LARGE`, `MENU_ITEM`, `BODY_LINE`. No colours: UI reads `Game.palette` by role (Story 1.18 D6). `play_text(color, outline)`: `TextStyle.play_text` for UI-layer text over the play area (the death card, the "Not saved" note) |

### Rooms — `scripts/world/`

Rooms as text (Story 1.5). The format, legend, validator errors and Room API are in [rooms.md](./rooms.md).

| Script | Role |
|---|---|
| `room_legend.gd` (`RoomLegend`) | The one definition of every grid char: `#` `.` `P`, and `SPAWNS` (`c`, `h`, `L` with their scene and args; `c` and `h` are `killable`, `L` is `in_wall`) |
| `room_loader.gd` (`RoomLoader`, static) | `parse()`, the pure `validate()` (errors as `file:row:col`), `load_room_from_path(path, dive)`, `load_room(id, dive)` through an index of `res://rooms/**/*.txt` (tests add roots with `add_root(dir)`), `room_ids()` (every indexed id, sorted as Strings) and `inspect(id)` (`{known, entries, errors}` without building the room or a `push_error`; DevTools' `--room=`, Story 1.11), `down_entry_cell()`, and the build (killable spawns get `room_id` + `cell`; with a `dive`, its killed cells are skipped). Caches the TileSet and the unshaded rim material as statics |
| `room.gd` (`Room`, `Node2D`) | One built room: `Backdrop`, `Walls` (TileMapLayer), `Rims`, spawned entities. `spawn(scene, pos, args)`, `bounds()`, `entry_position()` / `has_entry()` / `exit(side)` (exits carry `entry_cell`), `is_solid()`, `cell_centre()` |

### Core — `scripts/core/`

| Script | Kind | Role |
|---|---|---|
| `game.gd` | autoload `Game` (no `class_name`) | Holds refs to session state, never rules: `settings`, `slot`, `dive`, `tuning`, `clock`, `display`, `palette` (same instances all session; replacing one asserts) and `store`. `boot()` (once, from the entry scene) loads `settings.json` and arms its writes, at most one per frame (a file that can't be opened or is from a newer build is left untouched, and writes stay off for the session), then calls `display.start()`; `override_setting(key, v)` sets a value for this session only (DevTools' `--set`, Story 1.11): it survives `boot()`'s load, and while any override exists the session writes no `settings.json` at all; `reset_for_tests()` resets everything in place, overrides included |
| `save_store.gd` | `class_name SaveStore` (`RefCounted`), at `Game.store` | The only code that reads or writes the player's files: `read_settings()` / `write_settings()` for `user://settings.json` (`{"version": 1, "settings": {…}}`, `.tmp` then rename). `read_settings()` returns `{found, settings}`; `found` is a `SaveStore.Found` (USABLE, MISSING, CORRUPT, UNREADABLE, NEWER), which tells `Game` whether it may rewrite the file. Redirectable `dir`; never creates folders |
| `display.gd` | `class_name Display`, child of `Game` named `Display` (Story 1.14) | The scale rule and the only code that touches the stretch or the window. Statics: `scale_for(window)` (physical pixels; `floor(min(w/480, h/270))` from ×1 up, which is what the engine's integer stretch draws, the fraction itself below), `stretch_for(window)` (`INTEGER` from ×1 up, else `FRACTIONAL`: the nearest-neighbour fit, letterboxed, instead of the engine's crop), `window_scale_for(usable, decorations)` (the largest whole scale up to `DEFAULT_WINDOW_SCALE` 3 that fits; 3 for an empty rect). `apply(window)` ignores a window with no area (a hidden embed); otherwise it sets the stretch and `scale`, emits `scale_changed(scale)` on each change and logs `[ui] display: scale N in WxH` (or `scale 0.833 (fit) in 400x225`) only on a step (`logs_step()`: a whole-scale change or entering the fit, never each pixel inside it). `start()` (from `boot()`): inert under headless (`scale` stays 0.0, "no window"); on PC (not web, not embedded in the editor) sets `min_size` 480×270 and, for a windowed window that doesn't fit the screen, shrinks it to the largest whole scale and centres it (`[ui] display: window x2 960x540 (screen 1366x768)`); then applies the size, connects `size_changed` and turns on a per-frame size check (`PROCESS_MODE_ALWAYS`), because on web the root window's `size_changed` never fires on a browser resize (probed, 4.7.2). No JavaScriptBridge: the engine's HiDPI canvas already gives physical pixels |
| `clock.gd` | `class_name Clock`, child of `Game` | The only writer of `Engine.time_scale`. `request(id, scale, seconds)` multiplies with other ids, refreshes its own id, times out on real time and pauses with the tree; `clear()`, `is_active(id)`, `active()` (a copy, `{id: scale}`, of the live requests, for DevTools' overlay 4; Story 1.11) |
| `budget_light.gd` | `class_name BudgetLight extends PointLight2D` (Story 1.12, AR46) | Every `PointLight2D` in the game (lint `raw_light`). `enum Rank { ALWAYS, CACHE, GLOW }` (`@export var rank`, default GLOW, set before `add_child`: its setter asserts), group `budget_light`, `MAX_ON_SCREEN` 6, `SPRITE_ALPHA` 0.35. CACHE and GLOW lights build a hidden `Fallback` `Sprite2D` (`Fx.additive()`) in `_ready()`; `set_demoted(on)` (the budget's only write: `enabled = not on`, and the sprite at once) and `wants_light()` (shown, energy > 0, textured). Pure statics: `texture_rect()`, `lit_on_screen()`, `choose()` (the rule: ALWAYS kept, then CACHE, then GLOW; lit first, then nearest the centre; off-screen left as is), `apply()` (returns nothing; asserts that no owner wrote `enabled`), `counts()` (`{lit, sprites, over}`, BudgetLights only) |
| `text_style.gd` | static `class_name TextStyle` (Story 1.17, AR40) | The one text style, in `core/` so `Fx` can use it (lint `core_layer`). `FONT_PATH` (Fusion Pixel Font 8px proportional, latin), `SIZE` 8, `SIZE_LARGE` 16, `LINE_SPACING_SINGLE` −4 / `BODY` 0 / `LARGE` −8 (a size-8 Label's pitch is 12 + line_spacing, probed), `BODY_PITCH` 12, `MENU_ROW_PITCH` 24, `CAP_TOP` 3 / `CAP_TOP_LARGE` 6 (place a Label at `y - CAP_TOP` to put its cap top on a DESIGN y), `OUTLINE_PX` 1. `font()`; `play_text(color, outline_color)`: a `LabelSettings` cached per colour pair (callers pass the active zone's SURFACE, so three zones add at most three entries per glyph colour), size 8, four stacked shadows at (±1, 0) and (0, ±1) with outline 0, so the outline is 1 px on four sides with no diagonals (UX-DR15; the font's own outline strokes diagonals) |
| `palettes.gd` | `class_name Palettes` (`RefCounted`), one instance at `Game.palette` (Story 1.18, AR27) | The one home for UI colours. `AMBER` `#ffd27a` / `RED` `#d9473f` (reserved), `enum Role { HP, LABEL, EMPTY, RULE, SURFACE, GUTTER }`, `DEFAULT_ZONE` `&"dusk"`, and `ZONES` (`dusk`, `umber`, `violet`): per zone its four world colours, six roles (UX-DR7 overrides applied) and edge-cue glow floor, every hex DESIGN.md's. Statics `role_in(zone, role)`, `world_in(zone, i)`, `glow_floor(zone)`, `zones()` (DESIGN order; the room validator's list), `has_zone()`. The instance is the active zone: `zone()`, `color(role)`, `set_zone(zone)` (emits `changed` only on a real change; `World._swap_room()` calls it on every room build), `reset()`. UI re-reads on `changed`, never caching by zone id: E4's cross-fade will emit blended colours. Presentation, not save data |
| `log.gd` | static `class_name Log` | `Log.info(cat, msg)` / `Log.debug(cat, msg)` print `[cat] msg`, silent in release; `Log.enabled(cat)` guards hot paths. Categories `SAVE ROOM INPUT CLOCK LURKER WEAVER AUDIO UI` |
| `rules/tuning.gd` | `class_name Tuning` (`RefCounted`, pure); one instance at `Game.tuning` | 34 gameplay consts listed in `BASE`. `f(&"key")` returns the current value; `flag(&"key")` a gear rule switch; `apply_gear(ids)` recomputes set → add → mul and emits `changed`; `apply_gear([])` resets in place |
| `rules/gear.gd` | `class_name Gear` (pure data) | `TABLE` of `{id, stat, op, value}` rows (`set` / `add` / `mul` / `flag`); empty until E5 |
| `rules/settings.gd` | `class_name Settings` (`RefCounted`, pure); `Game.settings` | Global settings: `brightness`, `light_tap_window` (0.12 / 0.2 / 0.3 s, Story 1.8) and the accessibility bools `reduce_flashing` (false), `shake` (true), `reduced_motion` (false) (Story 1.16; read only through `Fx`'s gate) so far. `set_value(&"key", v)` emits `changed(key)` on a change; `SCHEMA` lists each key, its default and its choices; static `is_valid(key, v, schema := SCHEMA)` is the one validity rule (type first, then the choices), shared with DevTools' `--set` (Story 1.11) |
| `rules/slot_state.gd` | `class_name SlotState` (`RefCounted`, pure); `Game.slot` | Per-slot state: `best_chain`, `deaths`, `difficulty` (`&"easy"`/`&"normal"`/`&"hard"`), story flags (`set_flag()` / `has_flag()`), visited rooms (`visit()` / `has_visited()`, `visits_changed`; Story 1.7). `to_dict()` becomes save format `slot_v1` at 1.41 |
| `rules/dive_state.gd` | `class_name DiveState` (`RefCounted`, pure); `Game.dive` | Per-dive state: `carried` embers (`add_carried()`), the respawn point (`set_respawn()`), killed enemies (`mark_killed()` / `is_killed()`, never saved) |

### Fx — `scripts/core/fx.gd` (static, `class_name Fx`)

| Function | Effect |
|---|---|
| `pop(parent, pos, amount=SPARK_COUNT)` | One-shot amber (`SPARK` = `Palettes.AMBER`) `CPUParticles2D` burst (0.35 s, 14 sparks, 1–2 px): the pogo spark (every pogo hit kills a crawler today). Reduce flashing: 7 sparks, 1 px (the 1 px floor, Story 1.16 D5) |
| `chain_popup(parent, pos, count, embers)` | Floating text like `x5  +5`, 8 px at every count (Story 1.17 D7: M1's 10 px from chain 5 scaled the face by a fraction); numbers only, no string key |
| `popup(parent, pos, text, color)` | Floating label in `TextStyle.play_text(color, Game.palette.color(Palettes.Role.SURFACE))` (the active zone's surface, Story 1.18): the game font at size 8 with the 1 px four-side outline (Story 1.17; M1's size parameter and 3 px theme outline are gone); rises `POPUP_RISE` 14 px and fades over 0.6 s. Reduced motion: fades in place. `player.gd` passes `tr("POPUP_BANKED") % amount` / `tr("POPUP_LOST") % lost` |
| `unshaded()` | The shared unshaded `CanvasItemMaterial`, built once (Story 1.12); `pop()` and `popup()` use it |
| `additive()` | The shared additive + unshaded `CanvasItemMaterial`, built once (Story 1.12); `BudgetLight`'s sprite glows use it |
| `reduce_flashing()`, `shake_on()`, `reduced_motion()` | **The accessibility gate** (AR57, Story 1.16): read `Game.settings` live. The only code that names the three keys (lint `a11y_gate`); camera shake, the invulnerability blink and (from the UI kit) UI easing ask these |
| `blink_alpha(remaining)` | The invulnerability blink: 1.0 / 0.0 at `INVULN_BLINK_HZ` 2.5 (lit `INVULN_LIT` 0.625 of each period), `STEADY_ALPHA` 0.5 throughout under reduce flashing, 1.0 at `remaining <= 0`. `Player` writes it to its sprite's `modulate.a`; the HP pips reuse it (1.25) |
| `pulse(t, hz)` | 0..1 sine; the lurker's eye pulse at `EYE_PULSE_HZ` 2.0 |
| `warm_up(room, pos)` | Draws each cached material once at room load (Story 1.16 D10): sparks and a label with `unshaded()` (the label in a real popup's `LabelSettings`, Story 1.17), a light sprite with `additive()`, under the room at `pos` at `WARM_ALPHA` 0.01 (4.7.2 culls an item below 0.007 alpha), freed after `WARM_FRAMES` (3) process frames, which is two drawn frames whatever the frame time (the code review replaced a 0.05 s timer that could free them undrawn). The room must be in the tree. `World._swap_room()` calls it at the entry |

**`EFFECTS`** declares everything that flashes, blinks, pulses, shakes or eases: `name → {kind (ONCE / PULSE / BLINK / MOTION), hz, fn, reduced, why}` (`pogo_sparks`, `popup`, `chain_popup`, `camera_shake`, `light_kick`, `swing_arcs`, `invuln_blink`, `lurker_eye_pulse`, `lurker_eye_open`, `lurker_shiver`, `pogo_squash`). A row names its reduced variant or says `why` it has none. `MOTION` (position or scale, no brightness change) is declared, not rate-capped. A new effect adds its row; one drawn outside `Fx` is added by hand, since `test_fx`'s reflection check sees only `Fx`'s public static functions. `test_fx` holds blinks and pulses to `Spec.FLASH_HZ_MAX` / `PULSE_HZ_MAX` / `BLINK_HZ`; a one-shot's rate is its trigger's, and `smoke_bot` holds two pogo hits at least `Spec.POGO_GAP_MIN` apart.

Everything is unshaded and frees itself; no effect builds its own `Material`.

## Dev Tools

### DevTools — `scripts/dev/` (debug builds only)

Entry args and overlays (Story 1.11, AR54). `World._ready()`'s first statement is `if OS.is_debug_build(): add_child(load("res://scripts/dev/dev_tools.gd").new())`: a path string, never `preload`, so `world.gd` still loads in a release export, whose presets exclude `scripts/dev/*` (Story 1.13: `tools/export.sh` checks every release PCK for it and boots the Linux release build). No `.tscn`. Nothing outside `dev/` and `tests/` names `DevTools`, a `dev/` class or a `dev/` path (the lint's `dev_ref`).

| Script | Kind | Role |
|---|---|---|
| `dev_tools.gd` | `class_name DevTools` (`Node`, child of `World` added before `LightBudget`, `PROCESS_MODE_ALWAYS`, `process_physics_priority` 100) | Reads args only when World is the current scene (a real run): `OS.get_cmdline_user_args()`, then the URL query through `JavaScriptBridge.eval("window.location.search")`, which returns null off the web, so there is no `OS.has_feature("web")` branch. A test sets `tokens` from World's `child_entered_tree`, which fires before DevTools' `_ready()`. Pure statics: `query_tokens()`, `parse()`, `chain_value()`, `log_names()`, `set_value_of()`, `room_entry()`, `pick_entry()`, and from Story 1.12 `glow_value()`, `perf_seconds()`, `glow_environment()`. Public `perf` (the PerfRun, or null) and `glow_on`. A bad arg is a `push_warning`, never an error or an assert: the game still starts. In a real run it also connects one-shot to World's `room_entered` and prints `[room] SMOKE boot ok` (`Log.ROOM`) once, when the first room is in: the web smoke's boot marker (Story 1.13 D9); a respawn prints no second one. Polls `dev_overlay` in `_process` and cycles the overlays |
| `overlays.gd` | no `class_name` (DevTools preloads it), `Node` | The four overlays; `mode` 0 (off) to 4. `WorldMarks` (`Node2D`, `z_index` 100) draws in world space with one cached unshaded `CanvasItemMaterial`, so it reads under the darkness; `ScreenMarks` draws in screen pixels on DevTools' own CanvasLayer 11, above the UI (10). The readout text rebuilds at 4 Hz. Statics `clock_rows()`, `light_marks()`, `summary_rows()`, `unshaded_material()`; `room_items()`, `play_rect_on_screen()`, `player_marks`, `readout`, `light_count` / `sprite_count` / `over_count` and `frame_ms` / `worst_frame_ms` are public for tests |
| `perf_run.gd` | no `class_name` (DevTools preloads it), `Node` child of DevTools named `PerfRun`, `process_physics_priority` 100 | `--perf` (Story 1.12 D1): on every `player_spawned`, locks the input, masks the `Hurtbox` (0), teleports to the path start and snaps the camera, builds two stand-in `BudgetLight`s under the room (`stand_ins`: a flare ALWAYS at the player's light radius, a cache CACHE at 80 px). Each tick (not paused, not the spawn frame) moves the player along `path_point()` at 100 px/s from a tick counter; from the tick the chain reaches the held n, samples `BudgetLight.counts()` and measures wall-clock frames (`Time.get_ticks_usec()`); at the end `done`, `result` and one `[room] dev: perf …` line. Pure statics `path_point()`, `new_stats()`, `add_frame()`, `summary()`, `summary_text()` |

**Args.** One row per arg in the `ARGS` registry, `{help, apply, repeat}`, applied in this order:

| Arg | Effect |
|---|---|
| `--log=<cat>,<cat>` | Names from `Log.CATEGORIES`, any case; an unknown one warns and is skipped; repeatable. One `Log.set_enabled()` call with every value merged, made only when they name a valid category (none warns, and `Log` is left as it was) |
| `--set=<key>:<value>` | Any `Settings` key, typed by its default (int, float, bool `true`/`false`); repeatable. Goes through `Game.override_setting()`: it survives `Game.boot()`'s load, and a session with any override writes no `settings.json` at all (not even a rewrite or another key's change). `--set=brightness:0..3` is how brightness changes until Options (1.36) |
| `--room=<id>` | Starts the dive in that room, at the `P`, else the `up` entry (arriving from above), else `down`, through `World.start_room` / `start_entry`; a death respawns there while no respawn point is set. DevTools never writes `Game.dive`'s respawn point. An unknown id or an invalid room warns, and the default start room (`m1_shaft`) loads |
| `--chain=<n>` | 0..20 (`ChainState.MAX_CHAIN`). Armed on every spawn (every life); paid on the first physics tick that ends with the player off the floor, as n `ChainState.add_hit()` calls (count n, held n(n+1)/2, best chain n). It then breaks and banks like any chain |
| `--glow=on\|off` | `on` adds a `WorldEnvironment` named `Glow` under DevTools with `glow_environment()` (`BG_CANVAS`, glow on, intensity 1.0, strength 1.0, bloom 0, threshold 0.5, additive); `off` or none adds none; anything else warns (Story 1.12 D7) |
| `--perf[=<s>]` | 1..600 s, 60 by default: adds `PerfRun`, holding `--chain`'s n if a valid one was given, else 20 (paid through the same arming). A bad value warns and starts no run ([perf.md](./perf.md); Story 1.12 D1) |

On a web debug build the URL query (`?room=m1_shaft&chain=8`) gives the same tokens.

**Overlays.** Each press of `dev_overlay` cycles 1 → 2 → 3 → 4 → off, also while paused. Nothing blinks.

| Mode | Shows |
|---|---|
| 1 | `World.play_rect()`, the notice rect (the play rect shrunk by `Lurker.SCREEN_MARGIN`, 8 px), both 60 px gutters and their 58 px usable bands, all in screen pixels: the play rect is placed by its offset inside `World.light_rect()` of the same tick (`play_rect_on_screen()`), because a world-space frame shook while falling (the view is drawn interpolated between ticks) |
| 2 | The player's light radius and its notice reach (× `Lurker.NOTICE_FACTOR`, 1.6), dashed and dim with "below notice" while the light is under 80 px; each predator's state, and a line to the player while it senses them. The player's marks are drawn on `DevLightMarks`, a child of the live player that the engine interpolates with its sprite (in world space at the tick position they shook while falling); it moves to a respawned player the next frame, and there is none outside mode 2 |
| 3 | Each exit (side → target), the `spawn` / `up` / `down` entries, each `obj=` id at its cell |
| 4 | `FPS`; `lights n/6, sprites m` (`, over k` when k > 0), from `BudgetLight.counts()` on `World.light_rect()`, exactly what the budget counts; `frame x.x ms, worst y.y ms` in wall time since mode 4 opened; with `--perf`, `perf n / s s`, then the summary over up to three rows (a row over 90 characters wraps at a space); the active Clock requests (each stays listed, greyed, 0.5 s after it ends) |

Every mark reads the value the game uses, never a copied number. Marks at actors sit at the actor's tick position, up to one physics tick off the interpolated sprite (accepted for a dev overlay).

## Input Actions (`project.godot`)

| Action | Key(s) |
|---|---|
| `move_left` / `move_right` / `move_up` / `move_down` | ← → ↑ ↓ |
| `jump` | Z, ↑ |
| `attack` | X |
| `dash` | C |
| `light` | V |
| `dev_overlay` | `` ` `` (backquote, physical keycode 96). Read only by DevTools, so it does something only in debug builds (Story 1.11) |

Keyboard only, bound by physical keycode. Still no function keys (the M1 shaft and its F1/F3 were deleted in Story 1.7): `smoke_dev_tools` checks that no project action has an F-key event and that `dev_overlay` has exactly one event, the physical backquote.

## Asset Inventory

| PNG (`game/art/`) | Size | Source grid | Used by |
|---|---|---|---|
| `player.png` | 16×24 | `player.txt` | Player/Sprite |
| `crawler.png` | 16×16 | `crawler.txt` | Crawler/Sprite |
| `lurker.png` | 24×24 | `lurker.txt` | Lurker/Sprite |
| `lurker_eyes.png` | 24×24 | `lurker_eyes.txt` | Lurker/Eyes (unshaded) |
| `slash.png` | 24×16 | `slash.txt` | Player Slash and Pogo sprites |
| `tile.png` | 16×16 | `tile.txt` | Walls tileset |
| `light.png` | 128×128 | generated (radial gradient) | Every `PointLight2D` (each a `BudgetLight`, sized by `texture_scale`) and the sprite glows that stand in for demoted ones |

Total: 7 PNGs, about 5.6 KB. No audio, shaders or 3D assets. The one font is the Fusion Pixel Font 8 px (`game/fonts/`, a 2.5 MB `.otf`, OFL 1.1; Story 1.17), the project's default font.

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
| `tests/test_display.gd` | `Display` (Story 1.14): the `scale_for` / `stretch_for` table on both sides of every boundary, `window_scale_for`, `BASE` and the ×3 override against `project.godot`, the effective display settings (`viewport`, `integer`, `keep`, `allow_hidpi`, nearest, pixel snap), `Game.display` inert before `start()`, `apply()` switching the stretch both ways with one `scale_changed` per change, `start()` inert under headless (47 checks) | headless |
| `tests/test_clock.gd` | Clock: ids multiply, re-request refreshes, real-time expiry, pause freeze, `_exit_tree` and player death clear, `active()` is a copy | headless |
| `tests/test_tuning.gd` | Tuning API (set → add → mul in every gear order, flags, `changed`, reset in place), the telegraph floor and the hover period under every combination of gear (`Spec`), and the regression fixture: all 44 M1 exports keep their value, plus the boxes, chain curve, bloom and hitstop depth | headless |
| `tests/test_state.gd` | Settings, SlotState and DiveState (signals, fallbacks, save shapes, JSON round trips), the `Game` refs and `reset_for_tests()`, `settings.json` through `SaveStore`, `Settings.is_valid()` and `Game.override_setting()` (an override survives the load and nothing is written; 215 checks) | headless |
| `tests/test_room_loader.gd` | The room validator (fixtures in `tests/rooms/` and inline texts, the `cling=` key), the build and the `Room` API, the real `m1_shaft`'s pins (counts, ledge rows, exits), `room_ids()` and `inspect()` | headless |
| `tests/test_room_sweep.gd` | The pure room sweeps on inline grids, each with a sample that fires and a near-miss (74 checks) | headless |
| `tests/test_deferred_owners.gd` | Ledger scan rules, then every item in `deferred-work.md` has an owner (fails on a ledger edit, not only a code change), and fails on a ledger format it can't read (bmad-loop's `### DW-n`, `status:` lines, tables, or sections with no list items) | headless |
| `tests/test_lint.gd` | The architecture lint over `scripts/` (14 rules, each with sample lines; stricter than AR48 on purpose: every `KEY_*`, wider `raw_input`, `random` and `rules_purity`, new `tests_ref`, `state_write`, (Story 1.12) `raw_light` and (Story 1.16) `a11y_gate`; `raw_input` allows `dev/`, and `dev_ref` lets through only `world.gd`'s one guarded DevTools line, which a tree check finds exactly once) and the `spec.gd` citations; see the development guide | headless |
| `tests/test_export_presets.gd` | `game/export_presets.cfg` (Story 1.13): the four presets by number, name and platform, `all_resources`, the `rooms/*.txt` include, the exact excludes, single-threaded web, `embed_pck=false` and `x86_64` on the desktop, no dedicated-server export, an options section each, no machine path, custom template or encryption; a model of the exporter on samples; then `String.matchn()` over the real files under `rooms/`, `tests/` and `scripts/dev/` (sentinels first) for every preset (67 checks; Story 1.14 added the web presets' `html/canvas_resize_policy=2`, `html/focus_canvas_on_start=true` and the `html/head_include` key guard, the same in both) | headless |
| `tests/test_dev_args.gd` | DevTools' pure parts: the URL query, the arg grammar and registry, each validator, the `--room=` entry pick, the overlay's Clock rows and light marks; from Story 1.12 `--glow` / `--perf` values, the glow `Environment`, the perf run's path, frame stats and summary line, and the summary rows (119 checks) | headless |
| `tests/test_fx.gd` | `Fx.unshaded()` / `additive()` built once with the right modes, `pop()` / `popup()` drawn with `unshaded()`, the sparks freeing themselves (Story 1.12); the gate readers, the `EFFECTS` table against `Spec`'s flash caps (every row has a reduced variant or a `why`; `MOTION` rows are not capped), the blink and pulse rates measured over 10 s with `tests/rate.gd` (the blink's lit and dark runs against M1's 0.25 s of 0.4 s), the reduced variants of `pop()` / `popup()` / the blink, the popup's 14 px rise, the reflection check (every public effect function on `Fx` has a row), `warm_up()` and its two frames (Story 1.16) | headless |
| `tests/smoke_a11y.gd` | In `m1_shaft` (harness): a real pogo with its hitstop shakes the camera by default; with shake off it keeps its freeze frame and sparks while `offset` stays zero, and `kick()` stores nothing; turning shake off mid-shake zeroes `offset` the next tick; a crawler knock blinks by default (each dark run 9 ticks, `Spec.BLINK_HZ` with M1's lit time) and holds 0.5 alpha, visible, under reduce flashing; the camera look-ahead eases by one tick's worth on the hit tick (Story 1.16) | headless |
| `tests/test_light_budget.gd` | `BudgetLight`: the `choose()` rule and the jitter case, `apply()` on nodes (demotion, recovery, the sprite fallback and its alpha, what takes no slot, raw lights not counted), `lit_on_screen()` / `texture_rect()`, `MAX_ON_SCREEN` against `Spec`, and the scene audit of every `PointLight2D` under `scenes/` (56 checks) | headless |
| `tests/test_strings.gd` | The string table (Story 1.17): its shape, every key registered and current (a stale `.translation` the import left alone fails here; one the import repaired fails `run_tests.sh` and `export.sh`, which compare it with the commit), the English fallback under `vi` and `de`, the copy rules, every key reference in `scripts/` and `scenes/` (`tr`, `tr_n`, `atr`, `atr_n`, `TranslationServer.translate`, and listed-key literals held as data), no dead key, no composed key, no raw text in a scene; the validators live in `tests/strings_check.gd`, each with a firing sample and a near-miss. `tools/export.sh` runs it in its content step | headless |
| `tests/test_palettes.gd` | `Palettes` against DESIGN.md with its own WCAG maths on 8-bit ints (Story 1.18): known answers, every token, the derived gutter (index 0 × 0.55, half up), `floor_errors()` with a firing sample and a near-miss, each override and glow floor the smallest whole percent that passes (1% less fails), every two-decimal ratio, `Game.palette`'s signal, zone ids in `ok_min.txt` and every room, `Fx.SPARK`, and the Deck mock's elements inside their regions | headless |
| `tests/smoke_palettes.gd` | `world.tscn` on `tests/rooms/zones/` (Story 1.18): booted from violet into a dusk room, an exit into umber, a death back to dusk, a same-zone swap; the gutter strips and clear colour follow with one `changed` per real change, and a popup is outlined in the umber surface | headless |
| `tests/test_theme.gd` | The font's four import pins, `custom_font` and `ThemeDB.fallback_font`, Latin-1 + Extended-A coverage, DESIGN's measured widths (`0123456789` 50, `+1240` 24, `x12 +24` 33, digits 5; ×2 at 16), each Label variation's size and pitch under the built Theme, `CAP_TOP` against ascent − DESIGN's cap 6, the cached Theme, `play_text`'s cache and four 1 px shadows, popups at 8 px (Story 1.17) | headless |
| `tests/smoke_rooms.gd` | Every room file: validation, unique ids, exit links, spine falls, cling stretches, hazard pits, the arrival from below, and the lurker guarantees (per lurker and per room) against `Spec` (92 checks: `m1_shaft`, and `perf_worst` validated only) | headless |
| `tests/smoke_bot.gd` | The descent bot in every spine room: chain ≥ 5, no live chain at an exit, reaches the down exit alive, and its two closest pogo hits are at least `Spec.POGO_GAP_MIN` apart (Story 1.16: the per-hit effects stay under the flash cap; 1.017 s on `m1_shaft`) (~28 s on `m1_shaft`) | headless |
| `tests/smoke_moves.gd` | The M1 move checks on `m1_shaft`: pogo, landing, jump height, wall cling (its timeout banks), the Snuff ending on release (17 checks) | headless |
| `tests/smoke_world.gd` | World: no boot, the tree, framing (limits, play rect, gutters), state wiring, popups in the room, death and respawn without a reload, a lurker behind a gutter (and, from Story 1.16, a real lurker's eye pulse timed against `Spec.PULSE_HZ_MAX`), a hunt over a death, the R16 bottom loop, World's own pogo → shake wire and its warm-up at every room load, `ScreenRouter`, source checks | headless |
| `tests/smoke_room_swap.gd` | Room swaps between `tests/rooms/swap/t_swap_a` and `t_swap_b`: deferral, the chain backstop, arrival from above and below, killed cells across swaps and a cross-room respawn, interpolation on | headless |
| `tests/smoke_player_input.gd` | `tests/rooms/input/t_input.txt`: M1 movement pinned (run, coyote, jump buffer, air dash), the Light windows on both sides of each boundary, the Snuff latch, Light across a pause and a hitstop, real-time buffers, the attack buffer, ↓ interact, the wall drop on ↑, the cling press, `lock()` / `unlock()` | headless |
| `tests/smoke_dev_tools.gd` | DevTools in a real `world.tscn` (tokens injected through `child_entered_tree`): inert without args, the real command line (`real_tokens()` and the current-scene gate), each arg (`--chain` on `tests/rooms/dev_tools/t_dev_room.txt`, also for a player spawned inside a tick) and each bad one warned, the overlay cycle (paused too), mode 2 past the notice radius, the light count (from `BudgetLight.counts()` on `light_rect()`: code-built lights, a gutter light counts, a raw `PointLight2D` doesn't; the `lights n/6` and `frame` rows, `cycle()` resetting the worst frame), the Clock rows, mode 3's items, no function key; the `SMOKE boot ok` marker (one per real run with its room built, none in a test World, none on a respawn; Story 1.13) (98 checks) | headless |
| `tests/smoke_perf.gd` | The perf kit in a real `world.tscn` (Story 1.12): `--room=perf_worst --perf=3` held on every tick (chain 20, alive, x 240, ≤ `Spec.LIGHTS_ON_SCREEN_MAX` lit, the player's light and the flare never demoted; the budget exercised and holding at the first wake), the stand-ins, the summary logged once and shown in overlay 4; the held chain with `--chain`; the plain room; `--glow`; bad `--perf`; the view rect; `m1_shaft` unchanged; `LightBudget`'s priority window (44 checks) | headless |
| `tests/screenshot.gd` | 2 screenshots of `world.tscn` (gutters, darkness, framing), then the Deck mock ×2 per zone, `deck_<zone>_x2.png` (Story 1.18, sonlm's Deck-size look) | needs a renderer |
| `tests/spec.gd` | Not a test: the GDD's guarantees as constants (`TELEGRAPH_MIN`, `BOT_MIN_CHAIN`, `BASE_LIGHT`, `NOTICE_MIN_RADIUS`, `LEDGE_FALL_TIME`, `LEDGE_FALL_MAX`, `NARROW_MIN`, `NARROW_MAX`, `LIGHTS_ON_SCREEN_MAX`, `FLASH_HZ_MAX`, `POGO_GAP_MIN`, `PULSE_HZ_MAX`, `BLINK_HZ`); tests `preload` it | — |
| `tests/rate.gd` | Not a test: a rate in Hz from values sampled once per tick: `turns(values)` and `hz_band(events, ticks_per_second, per_cycle)` (Story 1.16 code review); `test_fx` and `smoke_world` `preload` it | — |
| `tests/room_harness.gd` | Not a test: `build(parent, room_id)` (or `build_from_path(parent, path)`) loads a room standalone with a test player, a `CameraRig` and a stub `World` (`play_rect()`, `current_room()`); `free_all()` | — |
| `tests/strings_check.gd` | Not a test: the pure string-table checks (`check_table`, `check_glyphs`, `check_registered`, `check_copy`, `refs_in`, `check_refs`, `check_scene_text`; `PREFIXES`, `KEY_PATTERN`) | — |
| `tests/room_sweep.gd` | Not a test: the pure room sweeps (`room_files`, `is_dev`, `record`, `ledge_rows`, `safe_rows`, `spine_gap_errors`, `exit_fall_errors`, `stretch_width_errors`, `hazard_pit_errors`, `duplicate_id_errors`, `link_errors`, `arrival_errors`, `cling_wall`) | — |

## Build Tools — `tools/` (Story 1.13)

Outside `game/`: never exported, never linted. [build.md](./build.md) has the setup and the step table.

| File | Role |
|---|---|
| `tools/export.sh` | One command, no flags: preflight (Godot 4.7.2, the four templates, Node ≥ 24, Playwright 1.65.1, its headless shell), version (`<yyyymmdd>-<sha7>[-dirty]`), import, content (`smoke_rooms`, then `test_strings`, through the runner), the four exports to `builds/<version>/`, the licences (the font's `OFL.txt` and `LICENSES/` and `GODOT_LICENSES.txt` beside each build, Story 1.17), the PCK checks, the web download size (gzip, `WEB_DOWNLOAD_MAX_BYTES` 30,000,000, NFR5), the Linux release boot (5 s, exit 124 = still running), the web smoke, `logs/summary.txt`. Each Godot step runs under `timeout` and fails on a non-zero exit or any `ERROR:` / `SCRIPT ERROR` / `FAIL` line, colours stripped. Ends with `== BUILD OK …` or `== BUILD FAILED: <step>: <reason>` |
| `tools/godot_licenses.gd` | `extends SceneTree` (Story 1.17); run as `godot --headless --path game -s <abs path> -- <abs out>`: writes `GODOT_LICENSES.txt` (Godot's MIT licence, every third-party component, every licence text) for `export.sh`'s licences step; exits 1 with an `ERROR:` line on a write failure |
| `tools/pck_list.gd` | `extends SceneTree`; run as `godot --headless --main-pack <pck> -s <abs path>`: prints every `res://…` file in the pack, through the engine's own reader (`DirAccess`, hidden files included) |
| `tools/web_smoke/serve.js` | Node `http`/`fs`/`path` only: serves `BUILD_DIR` on `127.0.0.1:$PORT` (8060 by default), plus the one exact path `/embed.html` (Story 1.14), `.wasm` as `application/wasm`, the query string ignored, nothing outside `BUILD_DIR`, `Cache-Control: no-store` |
| `tools/web_smoke/playwright.config.js` | Chromium only, headless, one worker, no retries, 150 s per test and 60 s per wait; starts `serve.js` on 8061 as the `webServer`; fails at once without a `BUILD_DIR` holding `web/` and `web_debug/` |
| `tools/web_smoke/smoke.spec.js` | Per page: the `Godot Engine v4.7.2.stable` banner, `#status` removed, `#status-notice` empty, no page error, no `console.error` outside `ALLOWED_CONSOLE_ERRORS` (empty). `Web debug`: `[room] SMOKE boot ok`, still exactly once after 5 s of play, with the console checks run after that; with `?room=perf_worst` the one DevTools summary `[room] dev: room perf_worst@spawn`, no `dev: perf` line, no `WARNING: DevTools:` line. `Web` (release): 5 s more with no error and no Log line of any category. Each page must be served (200), and its boot waits share one 60 s budget. `Display scale` (Story 1.14, `Web debug`): one test per devicePixelRatio (1, 1.5, 2) walking viewport sizes, each step measured from a device-pixel screenshot (the non-black box is 480·s × 270·s, centred, with the same colour at both outer columns) and matched by the newest `[ui] display: scale` line. `Web input` (Story 1.14, release, in `embed.html`): every guarded key except F11/F12 is prevented and the host page stays at `scrollY 0`, with the canvas focused and after `blur()` (the first key refocuses the canvas, a game key `KeyZ` too); F11 and Ctrl `=` `-` `0` pass to the browser, not prevented, while F5 and F10 stay prevented. The `Display scale` edge columns must also be non-black. On failure the whole browser console is printed into `logs/web_smoke.log` |
| `tools/web_smoke/embed.html` | An itch-style host page (Story 1.14): a 100 px header, the game in a borderless 960×540 iframe, 3000 px of page; `?build=web` (default) or `?build=web_debug` |
| `tools/web_smoke/package.json` / `package-lock.json` | `@playwright/test` pinned to exactly `1.65.1`, `engines.node` `>=24`; `npm ci` |

Helpers worth reusing: `place(pos)` (teleport and snap the camera) and `frames(n)` / `seconds(s)` (physics-frame waits) in every smoke test; `smoke_rooms.gd`'s `_build(rec)` / `_free()` (a fresh room per scenario, waiting until the old stub `World` is gone), `_lurkers()` (this room's lurkers sorted by row, then column) and `_only(lurker)` (pause every other lurker); `smoke_moves.gd`'s `_hovers()` (hovering crawlers sorted by depth); `smoke_dev_tools.gd`'s `_build(tokens)` (a `world.tscn` whose DevTools gets those tokens, as a real run gets the command line).
