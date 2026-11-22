---
baseline_commit: 18fde0a
---

# Story 1.18: Palette tokens, contrast and the Deck-size check

Status: ready-for-dev

**Type:** dev (with one human gate: sonlm's Deck-size sign-off, Task 9) · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP2 Kit (1.16–1.30) · **Branch:** `feat/m2-e1`

## Story

As a player,
I want HUD colours that stay readable in every zone and at Deck size,
so that I can read the game at ×2 on a small screen.

## Acceptance Criteria

1. **`core/palettes.gd` holds every UI colour token, once.**
   - New `scripts/core/palettes.gd`: `class_name Palettes extends RefCounted` (D1, D3).
   - Reserved colours, the same in every zone:
     - `Palettes.AMBER` = `#ffd27a` (UX-DR1);
     - `Palettes.RED` = `#d9473f` (UX-DR2).
   - Per zone (`&"dusk"`, `&"umber"`, `&"violet"`):
     - the four world colours, index 0–3 (UX-DR3);
     - the six UI roles `HP / LABEL / EMPTY / RULE / SURFACE / GUTTER` (UX-DR5, UX-DR6), with the UX-DR7 overrides already applied;
     - the edge-cue glow floor colour (UX-DR9).
   - Every hex is DESIGN.md's token, written as a literal with a comment naming the token. Overrides also give their blend step (for example `+41%`).
   - Static readers:
     - `role_in(zone, role)`, `world_in(zone, index)` and `glow_floor(zone)`;
     - `zones()`, which returns the ids in DESIGN order;
     - `has_zone(zone)`.
   - `enum Role { HP, LABEL, EMPTY, RULE, SURFACE, GUTTER }`.
   - `RoomLoader` validates a room's `zone=` against `Palettes.zones()`. Its own `ZONES` const goes, so zone ids have one home (D9). The validator's error text is unchanged.

   (UX-DR1–UX-DR6, UX-DR9; D1, D3, D9)
2. **The active zone is one object that UI reads by role.**
   - `Game.palette` is a session-long `Palettes` instance, guarded against replacement like `Game.display` (D1, D2).
   - It has:
     - `zone() -> StringName`;
     - `color(role) -> Color`, the active zone's role colour;
     - `set_zone(zone)`, which emits `changed` only when the zone differs;
     - `reset()`, back to `DEFAULT_ZONE = &"dusk"` (UX D13: menus outside play use Dusk).
   - `World._swap_room()` calls `Game.palette.set_zone(room.zone)` on every room build (boot, exit, respawn), after the room is placed and before `room_entered` (D2). E1 snaps; the 500 ms cross-fade is E4's.
   - `Game.reset_for_tests()` calls `palette.reset()`.
   - Lint `state_write` covers `palette`: replacing it and writing a field on it fail, while `Game.palette.set_zone(…)` passes (D11).

   (UX-DR5; D1, D2, D11)
3. **The gutters, the clear colour and the play-area outline follow the active zone.**
   - `Gutters` fills its two strips and sets `RenderingServer.set_default_clear_color()` from `Game.palette.color(Palettes.Role.GUTTER)`.
     - It does this in `_ready()`, then again on every `Game.palette.changed`.
     - `Gutters.PLACEHOLDER` goes (D7).
   - `Fx.popup()` and `Fx.warm_up()` outline their text in `Game.palette.color(Palettes.Role.SURFACE)`, read when the popup is made. `TextStyle.PLACEHOLDER_SURFACE` goes, which closes the ledger item that Story 1.17 left with 1.18 (D8).
   - `Fx.SPARK` becomes `Palettes.AMBER` (exactly `#ffd27a`; it was `#ffd17a`) (D8).
   - The Theme stays colourless: UI reads `Game.palette` by role, never a theme colour (D6).
   - In `m1_shaft` (`zone=violet`) nothing on screen changes: the violet gutter and surface are the old placeholders.

   (UX-DR4, UX-DR5, UX-DR15; D6, D7, D8)
4. **A contrast test checks every role in every zone.** New `tests/test_palettes.gd` carries its own WCAG 2.x contrast function and its own copy of DESIGN's tables; it never reads expected values back from `Palettes` (D4, D5).
   - **Tokens:** every `Palettes` colour equals DESIGN.md's hex (the front-matter `colors` and `components.zone-roles`).
   - **Derived:**
     - HP is index 3, RULE is index 1, SURFACE is index 0;
     - GUTTER is index 0 × 0.55 per 8-bit channel, rounded half up (A2, UX-DR4).
   - **Floors:** each role, plus the two reserved colours, is checked against both the zone's gutter fill and its play area (index 0):
     - HP and LABEL ≥ 4.5 (text);
     - EMPTY ≥ 3.0 (shapes, and the chain number at 0 as large text);
     - AMBER ≥ 4.5;
     - RED ≥ 3.0 (shapes only);
     - RULE is exempt (decorative, DESIGN assumption A15) and is checked to be index 1 instead.
   - **Overrides:** LABEL and EMPTY are their base index (2 and 1) blended toward index 3 by the *smallest* whole percent that passes both floors. The test proves that step passes and the step 1% lower fails (Dusk LABEL: 0%, no override).
   - **Glow floor:** `glow_floor(zone)` is index 0 blended toward `RED` by the smallest whole percent that reaches 3.0 against index 0: 83% Dusk `#bb4038`, 79% Umber `#b23d36`, 75% Cold violet `#a63834`.
   - **Known answers** for the contrast function: white on black 21.0; `#767676` on white 4.54; `#777777` on white 4.48.
   - The floor validator is a pure function that returns an error list. It has a firing sample (Umber LABEL left at index 2: 3.76 / 3.44) and a near-miss (the real override).

   (UX-DR7–UX-DR9, UX-DR130; D4, D5)
5. **A ×2 Deck-size mock is rendered for every zone.**
   - New helper `tests/deck_mock.gd` builds a 480×270 `Control` for a given zone at DESIGN's coordinates (D12):
     - flat gutters and play area;
     - the HUD mock values: four pips (three full, one empty), the held `+1240`, a carried count, and chain number and meter stand-ins;
     - the chain digits 0–20, in Fusion at 24 and 32 px as stand-ins;
     - a `body-line` sample block with the play-area outline.
   - `tests/screenshot.gd` also saves `deck_dusk_x2.png`, `deck_umber_x2.png` and `deck_violet_x2.png`. Each is the 480×270 render resized ×2 with `Image.INTERPOLATE_NEAREST` to exactly 960×540, which is what an integer ×2 window shows (D12).
   - `test_palettes` (headless) builds the mock for each zone and checks that every element sits inside its region: the left gutter's usable x 1–58, the right gutter's x 421–478, or the play area x 60–420.

   (UX-DR131, NFR12; D12)
6. **sonlm signs off Deck-size legibility (human gate).**
   - sonlm views the three ×2 shots at Deck size, by the procedure in Task 9. Then sonlm either signs off that the text and HUD are legible, or the font choice is revisited before Story 1.25.
   - The dev agent HALTs and asks at Task 9. It never assumes or fills in the outcome.
   - The answer is recorded in the Dev Agent Record and in DESIGN.md Typography ("The Deck-size check still runs in E1 with this face").
   - A "no" blocks 1.25 until sonlm decides on the font.

   (UX-DR131, NFR12; D13)
7. **World art and later stories' colours are fenced off (D10).**
   - `RoomLoader.BACKDROP` (`#2a2440`, M1's violet index 1) and `World.AMBIENT_TINT` stay as they are. Their comments point to E4, and a ledger entry owned by E4 records that world art ignores the room's zone.
   - The bank and loss popups' M1 colours stay: Story 1.26 owns the bank popup, and Story 1.27 owns removing the M1 red.
   - No cross-fade (E4).
   - No HUD element beyond the gutter fill (1.25–1.27).
8. **Done means green.**
   - `cd game && ./run_tests.sh` gives `== ALL GREEN`.
   - Every new check is red-checked: break the code, see `FAIL`, restore (D14).
   - The docs are updated (D15).
   - Task 9's sign-off is recorded.

## Tasks / Subtasks

- [ ] **Task 1: Baseline (AC: 8).**
  - At story creation on `18fde0a` (2026-11-22), `cd game && ./run_tests.sh` gave `== ALL GREEN (25 tests)`, 1715 `ok`, 0 `FAIL`.
  - Re-run it and record the result in the Dev Agent Record.
- [ ] **Task 2: `core/palettes.gd` (AC: 1, 2).**
  - [ ] `class_name Palettes extends RefCounted`.
  - [ ] Declarations:
    - `signal changed`;
    - `enum Role { HP, LABEL, EMPTY, RULE, SURFACE, GUTTER }`;
    - `const AMBER`, `const RED`, `const DEFAULT_ZONE := &"dusk"`;
    - `const ZONES := { &"dusk": {world = [...4], roles = [...6 in Role order], glow = Color(...)}, &"umber": …, &"violet": … }`, holding the hexes in Verified facts. Write each as `Color("#rrggbb")` with a trailing comment naming the DESIGN token. Overrides carry their `+N%` and the old index, for example `# ui-label-umber: index 2 +41% toward index 3 (UX-DR7)`.
  - [ ] Statics:
    - `role_in(zone: StringName, role: Role) -> Color`;
    - `world_in(zone: StringName, index: int) -> Color`;
    - `glow_floor(zone: StringName) -> Color`;
    - `zones() -> Array[StringName]`, in DESIGN order: dusk, umber, violet;
    - `has_zone(zone: StringName) -> bool`.
    - Each asserts on an unknown zone or a bad index (a programmer error).
  - [ ] Instance:
    - `var _zone: StringName = DEFAULT_ZONE`;
    - `zone() -> StringName`;
    - `color(role: Role) -> Color` (it reads `role_in(_zone, role)`);
    - `set_zone(zone: StringName)`: it asserts `has_zone`, returns if the zone is the same, otherwise sets it and emits `changed`;
    - `reset()`, which is `set_zone(DEFAULT_ZONE)`.
  - [ ] Header `##` comment:
    - this is the one home for UI colours (AR27, DESIGN Colors);
    - UI reads roles from `Game.palette` and re-reads on `changed`, never caching by zone id, because E4's cross-fade will emit `changed` with blended colours (D2);
    - menus outside play (title, slot picker, gate) read `role_in(DEFAULT_ZONE, …)` (UX D13).
  - [ ] Nothing in `palettes.gd` names `World`, `Room` or any upper layer (lint `core_layer`).
- [ ] **Task 3: `Game.palette` and World (AC: 2).**
  - [ ] `core/game.gd`: `var palette := Palettes.new():` with the same replace-guard setter as `display` (assert message "Game.palette is session-long: set_zone() changes it, never replace it"). It is a RefCounted, not a child node. Header comment: "`palette` (Story 1.18): the active zone's UI colours; presentation, not save data".
  - [ ] `reset_for_tests()` adds `palette.reset()`.
  - [ ] `world/world.gd` `_swap_room()`: after `_camera.snap()` and before `_swap_pending = false` / the signals, call `Game.palette.set_zone(room.zone)` with one `#` line: the zone is the room's until E4 adds in-room boundaries and the cross-fade.
  - [ ] `test_lint.gd` `state_write`:
    - add `palette` to the first pattern's list (replace: `settings|slot|dive|tuning|clock|store|display|palette`);
    - add it to the second (field write: `settings|slot|dive|tuning|display|palette`).
    - Samples: `\tGame.palette = Palettes.new()` fires; `\tGame.palette._zone = &"umber"` fires; `\tGame.palette.set_zone(room.zone)` is quiet.
    - Update the `state_write` row in `docs/development-guide.md`.
- [ ] **Task 4: Gutters, Fx and TextStyle (AC: 3).**
  - [ ] `ui/gutters.gd`:
    - keep the two strips in a member array;
    - add `_apply_palette()`, which sets both strips' `color` and the clear colour from `Game.palette.color(Palettes.Role.GUTTER)`;
    - call it at the end of `_ready()`, then connect `Game.palette.changed` to it (a method, never a lambda);
    - delete `PLACEHOLDER`;
    - update the header comment: the fill and the clear colour follow the zone (1.18); the 1 px rules and the HUD come in 1.25.
    - On first-colour order: Gutters is World's child, so its `_ready` runs before World's. It paints the current (default or last) zone, then World's first `_swap_room` (inside World's `_ready`) calls `set_zone`, and `changed` repaints before the first frame is drawn.
  - [ ] `core/fx.gd`:
    - `SPARK := Palettes.AMBER` (comment: the reserved amber, one home; was `Color(1.0, 0.82, 0.48)`, `#ffd17a`);
    - `popup()` and `warm_up()` use `TextStyle.play_text(color, Game.palette.color(Palettes.Role.SURFACE))`;
    - the header line says the popup outline is the active zone's surface.
    - Fx already reads `Game` (the a11y gate), so this adds no new dependency.
  - [ ] `core/text_style.gd`: delete `PLACEHOLDER_SURFACE` and its comment, and say in the `play_text` doc that callers pass the active zone's surface (`Game.palette`). `play_text`'s cache stays keyed by the colour pair; three zones add at most three entries per glyph colour.
  - [ ] `ui/theme_builder.gd` header: "Colours are not here: UI reads `Game.palette` by role (Story 1.18 D6)".
- [ ] **Task 5: Zones have one home (AC: 1).**
  - `world/room_loader.gd`: delete `ZONES`; the validator checks `Palettes.has_zone(StringName(h.value))`, and the error lists `", ".join(Palettes.zones())`. The text is unchanged: "zone '…' is not one of dusk, umber, violet".
  - `BACKDROP`'s comment becomes "M1's violet index 1 in every zone until E4 applies the zone palettes to world art (ledger)". `world.gd`'s `AMBIENT_TINT` comment says the same (D10).
- [ ] **Task 6: `tests/test_palettes.gd` (AC: 4, 5).**
  - [ ] Its own helpers, written in the test (never `Palettes`):
    - `lum(c8: Array[int]) -> float` (sRGB linearisation: `v/12.92` at or below 0.04045, else `((v+0.055)/1.055)^2.4`; weights 0.2126 / 0.7152 / 0.0722);
    - `contrast(a, b) -> float` = `(Lhi + 0.05) / (Llo + 0.05)`;
    - `blend8(a, b, pct) -> Array[int]` (per channel `roundi(a + (b - a) * pct / 100.0)`);
    - `hex8(Color) -> Array[int]`, through `Color.r8/g8/b8`.
    - Do the maths on 8-bit ints: Umber's gutter (30 × 0.55 = 16.5) only gives DESIGN's `#110d0b` when rounded half up, and `roundi` does that (probed).
  - [ ] Known answers (AC4).
  - [ ] A `DESIGN` table const: per zone, the four world hexes, the six role hexes, the glow hex and the DESIGN ratios. Each line cites DESIGN.md (Colors and the front-matter tokens).
  - [ ] Checks:
    - tokens equal;
    - the derived relations;
    - the floors through a pure `floor_errors(table) -> Array[String]`, with its firing sample and near-miss;
    - the minimal override step;
    - the glow-floor minimal step;
    - the reserved colours on all six backgrounds;
    - the computed ratios match DESIGN's two-decimal values (a sanity check on the function: `snappedf(x, 0.01)`).
    - Floors are local consts citing DESIGN Colors > Contrast floors (`TEXT_MIN := 4.5`, `SHAPE_MIN := 3.0`). They are not in `spec.gd`: the GDD has no contrast line, and `spec_citation` requires one (D4).
  - [ ] `Game.palette`:
    - the default is dusk;
    - `set_zone(&"umber")` emits `changed` once, and the same zone again emits nothing;
    - `color(r) == role_in(zone, r)` for every role;
    - `reset()` goes back to dusk;
    - `Game.reset_for_tests()` resets it.
    - End with `Game.reset_for_tests()`.
  - [ ] Zones:
    - `RoomLoader.validate()` accepts a room for each of `Palettes.zones()` and rejects `zone=sepia` with the unchanged error text. Use `RoomLoader.parse` + `validate` on an in-memory grid, as `smoke_rooms` does;
    - every `res://rooms/**` file's zone is in `Palettes.zones()`.
  - [ ] Fx: `Fx.SPARK == Color("#ffd27a")` (a DESIGN literal).
  - [ ] The Deck mock (AC5): for each zone, build `deck_mock.gd`'s Control under the test, wait a frame, and check each element's rect lies inside its region. Also check `+1240` ends by x 46 (DESIGN's measured width). Free it.
- [ ] **Task 7: `smoke_palettes.gd` (AC: 2, 3).**
  - [ ] New fixtures `tests/rooms/zones/t_zone_a.txt` (`zone=dusk`, P, a floor hole down to B) and `t_zone_b.txt` (`zone=umber`, a ceiling gap up to A). Copy `tests/rooms/swap/`'s grids, without the walkers, and add a header comment "Story 1.18 zone-change test room. Not a level."
  - [ ] Set up as `smoke_room_swap` does:
    - `Game.store.dir` points at a temp folder;
    - `RoomLoader.add_root("res://tests/rooms/zones")`;
    - `World.start_room = &"t_zone_a"` before `add_child`.
  - [ ] Checks (gutter colours as DESIGN literals: dusk `#18100b`, umber `#110d0b`; surfaces `#2b1d14`, `#1e1714`):
    1. After boot: the zone is dusk. Both strips, picked by x position (0 and 420), and `RenderingServer.get_default_clear_color()` are the dusk gutter (probed: headless reads back what was set).
    2. `enter_room(&"t_zone_b", &"up")`: the zone is umber, and the strips and the clear colour are umber. `changed` fired exactly once for the swap.
    3. An `Fx.popup` made in room B has `label_settings == TextStyle.play_text(c, Color("#1e1714"))`.
    4. `player.die()` in B: the respawn rebuilds A (the start room), so the zone is dusk again.
    5. Re-entering a room of the same zone emits no `changed`.
  - [ ] End with `world.queue_free()`, a frame, then `Game.reset_for_tests()`.
- [ ] **Task 8: `deck_mock.gd` and the screenshot (AC: 5).**
  - [ ] `tests/deck_mock.gd`:
    - `extends RefCounted`, no `class_name` (tests preload helpers);
    - `static func build(zone: StringName) -> Control` returns a 480×270 `Control` with `theme = ThemeBuilder.theme()`.
    - It draws with `ColorRect`s and `Label`s only, every colour from `Palettes.role_in(zone, …)` / `AMBER`.
    - The layout table is in D12.
  - [ ] `tests/screenshot.gd`: after the two shaft shots, for each of `Palettes.zones()`:
    - add the mock to the test (it sits over the freed World, or alone);
    - wait 3 frames;
    - take `get_viewport().get_texture().get_image()` and check it is 480×270;
    - `resize(960, 540, Image.INTERPOLATE_NEAREST)`;
    - save `deck_<zone>_x2.png`;
    - free the mock.
    - Update the header comment.
  - [ ] Run it: `xvfb-run -a godot --path game --rendering-driver opengl3 res://tests/runner.tscn -- res://tests/screenshot.gd /home/sonlm/project/pixel_art_game/builds/shots-1.18` (`builds/` is git-ignored). Then open the PNGs with Pillow (`python3`, not `-I`):
    - each is 960×540;
    - every 2×2 block is one colour (an exact ×2);
    - a pixel in each gutter is the zone's gutter hex;
    - a play-area pixel away from text is its surface hex.
    - Record the result in the Debug Log.
- [ ] **Task 9: HALT for sonlm: Deck-size legibility sign-off (AC: 6). Human gate.**
  - [ ] Hand sonlm the shots with the exact laptop line (memory: laptop commands). Run it in PowerShell from the `0_ssh` folder:
    `scp -i .\sonlm2026-private.pem -r sonlm@123.31.11.131:/home/sonlm/project/pixel_art_game/builds/shots-1.18 .\uc-1.18-shots`
    If `SendUserFile` is available, also send the three PNGs, so sonlm can check them on a phone.
  - [ ] The procedure, written for sonlm:
    - **Size.** A Steam Deck LCD is 7.0" at 1280×800, about 216 PPI, so the 960×540 image shows at about **113 × 64 mm** (OLED: 7.4", about 120 mm wide).
    - **On the laptop.** Open each PNG in a viewer that scales with nearest neighbour (a browser is fine). Zoom until the image is 11.3 cm wide, measured with a ruler. Don't use 100% zoom: on the laptop that is larger than a Deck, and it makes the check too easy.
    - **Or on a phone.** In landscape, full width, on a 6–7" phone.
    - **Distance.** Look from handheld distance, about 30–40 cm.
  - [ ] The questions, for all three zones:
    1. Can you read the four pips (three full, one empty)?
    2. Can you read `+1240` and the carried count?
    3. Can you read every chain digit 0–20?
    4. Can you read the body-line sample and the meter?
    5. Is any role colour hard to tell from its background?
    - The chain numerals are stand-ins: Fusion at ×3 and ×4. The final hand-pixelled digits are 1.26's, and this sign-off doesn't cover them.
  - [ ] **HALT** and ask sonlm. Record the answer verbatim (date, device or method, per-zone notes) in the Dev Agent Record.
    - **Yes:** edit DESIGN.md Typography: "The Deck-size check still runs in E1 with this face." becomes "The Deck-size check passed with this face (Story 1.18, <date>, sonlm; ×2 shots of a HUD mock at Deck size).". Edit the GDD Platform line (`gdd.md` "Steam Deck: a Deck-size legibility check in E1…") the same way: "… in E1 (passed <date>, Story 1.18) …".
    - **No:** record what failed, and add a ledger item "Deck-size check failed: <what>" → **Owner: Story 1.25** (blocked until sonlm picks the font fix). Stop there: no font change in this story.
- [ ] **Task 10: Docs, ledger, red-checks (AC: 7, 8).**
  - [ ] Ledger (`deferred-work.md`):
    - close 1.17's "Play-area text outline uses `TextStyle.PLACEHOLDER_SURFACE`" item with `→ **Closed (Story 1.18): Fx popups and the warm-up outline in Game.palette's surface; the const is gone; smoke_palettes checks a popup in an Umber room.**`;
    - add the E4 world-art item (D10) under a new "Deferred from: dev of 1-18-…" section, with its owner line.
  - [ ] Docs (D15).
  - [ ] Red-checks (D14), each recorded in the Debug Log.
  - [ ] `./run_tests.sh` → `== ALL GREEN`, with the `ok` count recorded.

## Dev Notes

### What exists today (read before editing)

- **No palette code exists.** UI colours today:
  - `ui/gutters.gd` `PLACEHOLDER := Color("#07060b")` (DESIGN `gutter-violet`) fills both strips and is the clear colour, so the 4 px bands either side of a 352 px room merge with the gutters (`docs/architecture.md:158`);
  - `core/text_style.gd` `PLACEHOLDER_SURFACE := Color("#0d0b14")` (violet index 0) outlines every popup (`fx.gd:155`, `:186`).
  - Both are pinned in tests: `test_theme.gd:162` (the const) and `:176` (the popup's settings). Update both: 162 goes; 176 compares with `TextStyle.play_text(Color.WHITE, Game.palette.color(Palettes.Role.SURFACE))`, after setting the zone to umber and with `Color("#1e1714")` as the literal, then `Game.palette.reset()`.
  - `test_theme.gd:125` asserts the theme carries no colours, with the message "palette roles are Story 1.18's". Keep the check and change the message to "UI reads Game.palette by role (Story 1.18 D6)".
- **Room zones.**
  - `room.gd` has `var zone: StringName`, set from the required `zone=` header.
  - `room_loader.gd:9` `ZONES` validates it (`:171`).
  - `m1_shaft` and `perf_worst` are violet. Every test room is dusk. No room is umber.
- **World art (not this story's):**
  - `room_loader.gd:15` `BACKDROP = Color(0.164706, 0.141176, 0.25098)` is exactly `#2a2440`, violet index 1. Its comment says "until the zone palettes (1.18)".
  - `world.gd:26` `AMBIENT_TINT` keeps "the violet cast of the Edge palette".
  - Sprites have one palette (`tools/sprites/palette_edge.txt`).
- **Reserved-colour literals today:**
  - `Fx.SPARK = Color(1.0, 0.82, 0.48)` = `#ffd17a`, one step off amber in green;
  - `player.tscn` `Light` colour `Color(1, 0.823529, 0.478431)` is exact `#ffd27a`; leave it;
  - the bank popup `Color(1, 0.93, 0.7)` (1.26 owns it);
  - the loss popup `Color(1, 0.35, 0.3)` (1.27's AC removes it and `#ff594d`);
  - `lurker.tscn` glow light `Color(1, 0.25, 0.2)` (world light, not UI; 1.27 decides);
  - `palette_edge.txt` `E #d9473f` (eyes).
  - Only `SPARK` moves here.
- **Order of `_ready`:** World's children (Darkness, RoomHolder, Camera, UI/Gutters, UI/ScreenRouter) run `_ready` before World's own. `World._ready` builds the first room synchronously (`_swap_room(…, true)`, not deferred) before `add_to_group("world")` has any effect for children. So Gutters can't find World by group in its `_ready`. With `Game.palette` it doesn't need to.
- **Screenshot:** `tests/screenshot.gd` saves `get_viewport().get_texture().get_image()`. With `window/stretch/mode="viewport"` that image is **480×270**, measured at story creation (the two shaft shots were 480×270, gutter pixel `(7, 6, 11)` = `#07060b`). The ×2 is a nearest resize, which is exactly what integer ×2 scaling shows.
- **Baseline:** 25 tests, 1715 `ok` (Task 1).

### Decisions

- **D1: One file, static data plus one instance on `Game`.** `Palettes` holds the tables as consts with static readers. Its instance holds the active zone, and `Game.palette` is that instance. Every alternative fails one of four constraints:
  1. `Fx.popup()` is static in `core/` and needs the active surface (the ledger item). It can't name `World` / `Room` (`core_layer`), and a `static var` zone breaks "state in pure objects, not statics".
  2. Popups also draw with no World (standalone room tests), so the zone needs a default and a reset.
  3. Gutters' `_ready` runs before World's, and World isn't findable from it then.
  4. E4 cross-fades, so readers must ask by role and hear one change signal.

  A World-owned zone fails 1 and 2 unless every popup caller passes the surface. `Game.palette` mirrors `Game.display` (presentation, held by `Game`, no rules). It is a RefCounted, not a child node: it needs no tree. It is not save data and has no `to_dict()`. Architecture AR27 already places "zone palettes, UI role colours, zone cross-fade data" in `core/palettes.gd`. **Flagged for sonlm at story creation** (new `Game` ref): see Questions.
- **D2: The zone is the room's, set by World, snapped.**
  - `World._swap_room()` is the only room path, so boot, exits and respawns all pass through `set_zone()`.
  - `changed` fires only on a real change, so a same-zone swap redraws nothing.
  - E4 adds in-room boundaries ("the camera centre crosses a palette-zone boundary") and the 500 ms cross-fade, which snaps under reduced motion. It will change how `color()` is computed, not who reads it. That is why the signal is `changed` (colours changed), not `zone_changed(zone)`.
  - A snap at a room cut is not an `Fx.EFFECTS` row: it is one colour change on the same frame as the cut, not a flash pattern.
- **D3: API shape.**
  - `Role` is an enum, so a typo is a compile error.
  - Per-zone data is one `ZONES` dictionary keyed by `StringName`, so `zones()` keeps DESIGN order (GDScript dictionaries keep insertion order).
  - Hub and Layer 2 palettes are UX-DR10 (E5/E6): a new row in `ZONES`, and the test checks it automatically.
- **D4: The contrast test is independent of the code.** It has its own WCAG function, checked on known answers, and its own copy of DESIGN's hexes and ratios. It compares `Palettes` against those; it never derives expected values from `Palettes`.
  - The floors are local consts citing DESIGN Colors > Contrast floors. `spec.gd` would need a `## GDD` citation (`spec_citation` lint), and the GDD has no contrast line; this follows 1.17's rule of "local with its citation".
  - Story 1.27's edge-cue test will need the 3.0 floor and `glow_floor()`. It can share the helper then.
- **D5: Floor per role** (DESIGN Colors > Contrast floors, UX-DR7, UX-DR8):

  | Role | Floor | Why |
  |---|---|---|
  | HP, LABEL | 4.5 | text: bank values, menu items |
  | EMPTY | 3.0 | outlines; the chain number at 0 counts as large text |
  | RULE | exempt | decorative (A15); asserted to be index 1 |
  | SURFACE, GUTTER | — | they are the backgrounds |
  | AMBER | 4.5 | text and shapes |
  | RED | 3.0 | shapes only (3.82 on Dusk play) |

- **D6: The Theme stays colourless.** One cached Theme with zone colours baked in would need rewriting on every zone change. Which role a Label uses also depends on what it shows (held = amber, carried = HP, idle menu = LABEL, selected = HP). So 1.25 / 1.31 set colours per element from `Game.palette` and re-apply them on `changed`.
- **D7: Gutters own the clear colour** (kept from 1.6 / 1.17: "the colour has one home; when the fill turns per-zone, set it with the fill"). The 1 px inner and outer rules in RULE colour are 1.25's AC. Don't draw them here, except in the Deck mock.
- **D8: Popups read the surface at creation.** A popup lives about 0.85 s, and zones change only at a cut in E1, so it never needs to rebind. `SPARK` points at `Palettes.AMBER`: amber has one home, and the visible change is one 8-bit step of green. Nothing pins `SPARK`'s value (grep: only `test_lint` sample text names it).
- **D9: Zone ids have one home.** `RoomLoader` asks `Palettes` (a world → core dependency, which is allowed). `docs/rooms.md`'s `zone` row says the list is `Palettes.zones()`.
- **D10: World art stays violet; owner E4.**
  - UX-DR3 is "E1 (tokens); E4 (applied across zones)".
  - The tile sprites have one palette.
  - The only real rooms (`m1_shaft`, `perf_worst`) are violet.
  - Recolouring only the backdrop in a dusk room would mix a brown backdrop with violet tiles.
  - Ledger text: "**World art ignores the room's zone** — `RoomLoader.BACKDROP` is violet index 1 (`#2a2440`) and `World.AMBIENT_TINT` keeps the violet cast in every zone; sprites have one palette (`palette_edge.txt`). Story 1.18 gave the UI per-zone colours only. → **Owner: E4** — its Dusk and Umber rooms are the first real non-violet rooms; apply the zone palettes to the backdrop, ambient tint and sprites there (UX-DR3 'applied across zones')."
- **D11: `state_write` covers `palette`,** as it covers `display`: no replacing it, no field writes. `set_zone()` is the write path, and it emits `changed`.
- **D12: The Deck mock layout.** Native px, DESIGN Layout & Spacing. Labels sit at `y - CAP_TOP` so their cap top lands on DESIGN's y. CAP_TOP scales with size: 3 at 8, 6 at 16, 9 at 24, 12 at 32. Measure 24 and 32 once with `get_ascent()`; this assumes ascent = size × 9/8 and cap = size × 6/8.

  | Element | Where | Colour |
  |---|---|---|
  | Play area fill | x 60–420, y 0–270 | SURFACE (index 0, the floor test's play area) |
  | Gutter fills | x 0–60, x 420–480 | GUTTER |
  | 1 px rules | x 0, 59, 420, 479, full height | RULE |
  | Heart icon 7×7 (DESIGN Shapes art) | left x 27, top y 10 | LABEL |
  | Chain-link icon 7×7 | left x 447, top y 10 | LABEL |
  | HP pips 7×7 | x 26, y 24 + 10·n; n 0–2 full, n 3 a 1 px outline | full HP, outline EMPTY |
  | Held ember 5×5 blob (rows 3-5-5-5-3) | x 14, y 96 | AMBER |
  | Held text `+1240` (`HudValue`) | x 22, cap top y 95 | AMBER |
  | Carried ember 5×5 | x 14, y 108 | HP |
  | Carried text `386` (`HudValue`) | x 22, cap top y 107 | HP |
  | Chain number stand-in `20`, Fusion size 32 | centred x 450, cap top y 24 | AMBER |
  | Meter: 20 segments 12×6, segment n top at y 258 − 9·(n − 1) | x 444; n 1–12 filled, 13–20 1 px outlines | AMBER / EMPTY |
  | Flare notch 3×6 | x 458, y 249 | LABEL |
  | Digits 0–9 at size 24, spaced | play area, row 1 | `0` EMPTY, 1–9 AMBER |
  | Digits 10–15, then 16–20, at size 32 | play area, rows 2–3 | AMBER |
  | Body-line block, 328 px wide (x 76–404), `TextStyle.play_text` outline in SURFACE, 12 px pitch | play area below the digits | lines alternate HP / LABEL |

  - **Sample text** (a test literal, never in `strings.csv`, never story copy; NR2):
    - `Sphinx of black quartz, judge my vow.`
    - `The five boxing wizards jump quickly.`
    - `Depth S3 · Best chain 17 · 2:14 · Normal`
    - `0123456789 +1240 x12 +24 ÆØÅ éèê ñ ß`
    - The third line is DESIGN's slot-detail format, as a sample of a real line length. The last line covers digits and Latin-1.
  - Fusion's digit advance is 5 px at size 8, so 15 at 24 and 20 at 32. `20` at size 32 is 40 px wide and fits the 58 px usable gutter.
  - The mock is a picture, not the HUD. Story 1.25 builds the real one, and nothing in `scripts/` may use `deck_mock.gd`.
- **D13: The sign-off is sonlm's, at Deck size.** DESIGN and EXPERIENCE both call this "the Deck-size check … with Fusion Pixel Font 8px", which is a check of the font choice. That is why a "no" goes back to the font before 1.25 and changes nothing in this story.
- **D14: Red-checks.** Break each once, see `FAIL`, restore:
  - an override hex one step darker (for example Umber LABEL `#8e7d6f`): the token check and the minimal-step check;
  - the Dusk gutter `#170f0b` (truncated, not rounded): the derived check;
  - `floor_errors` fed Umber LABEL at index 2: the firing sample (it already is one);
  - `set_zone()` without the same-zone return: `changed` fires twice;
  - World without the `set_zone` call: `smoke_palettes` step 2;
  - Gutters not connected to `changed`: `smoke_palettes` step 2;
  - `Fx.popup` back on a fixed violet surface: step 3;
  - a `Game.palette._zone = …` line in `gutters.gd`: lint `state_write`;
  - a mock element moved to x 59: the region check.
- **D15: Docs.**
  - `docs/component-inventory.md`:
    - a new `palettes.gd` row (`Palettes`: tables, statics, the instance, `Game.palette`);
    - the `gutters.gd`, `text_style.gd` and `theme_builder.gd` rows (no placeholders, colours from `Game.palette`);
    - `fx.gd` (`SPARK` = `Palettes.AMBER`, the popup outline);
    - `game.gd` (`palette`).
  - `docs/architecture.md:158`: the clear colour is the active zone's gutter fill, set by `Gutters` on `Game.palette.changed`.
  - `docs/development-guide.md`:
    - the `state_write` row;
    - a "UI colours" line in the task table: read `Game.palette.color(Palettes.Role.X)` and re-apply on `changed`; amber and red are `Palettes.AMBER` / `RED`; never a colour literal for UI;
    - `test_palettes` / `smoke_palettes` in the test list.
  - `docs/rooms.md`: the `zone` row (the ids are `Palettes.zones()`).
  - `docs/source-tree-analysis.md`: `core/palettes.gd`, `tests/deck_mock.gd`, `tests/rooms/zones/`.
  - `game/README.md`: the test list.
  - `project-context.md`: one sentence in the Story list for what 1.18 added. Under Engine-Specific Rules or Code Organization: "UI colours come only from `Game.palette` by role (`Palettes`), re-read on `changed`; amber and red are `Palettes.AMBER` / `RED`". Update the Last Updated line.
  - `game-architecture.md`:
    - State Management: "`Game` holds … and `palette` (the active zone's UI colours, Story 1.18)";
    - the System Location Mapping row for palettes: as built, UI roles and glow floor; the cross-fade is E4.
  - After Task 9, DESIGN.md Typography and the GDD Platform line (Task 9).

### Questions for sonlm (asked at story creation; record the answers here)

- **Q1 (D1): where the active zone lives.** Recommended: `Game.palette` (a `Palettes` instance, like `Game.display`). Alternative: `World` owns the zone, and every popup caller passes the outline colour. That avoids a new `Game` ref, but then each popup caller (and later the cling cue and the death card) has to find the zone itself.
- **Q2 (D10): world art stays violet until E4.** Recommended: yes, with a ledger item owned by E4. Alternative: switch only `BACKDROP` to the zone's index 1 now. No real room changes (both are violet), but dusk test rooms get a brown backdrop under violet tiles.

### Testing standards

- Tests extend `Node` and run through `tests/runner.tscn`. They print `ok …` / `FAIL …` and a final `PASS` / `FAILED`. Any `SCRIPT ERROR` / `ERROR:` line fails the run.
- Name tests `test_*.gd` / `smoke_*.gd` so the glob finds them; `deck_mock.gd` is a helper and is not matched.
- Validators are pure and return error lists, with a firing sample and a near-miss.
- Expected values come from DESIGN.md (hexes, ratios, percentages) as literals in the test, never from `Palettes`. Compare colours as 8-bit ints or `to_html(false)` strings, never float `==` on computed blends.
- A test that touches `Game.palette` ends with `Game.reset_for_tests()`.
- Headless can check colours, rects and signals, but can't judge legibility. That is Task 9, sonlm's. Report "tests green; Deck-size legibility needs sonlm's look".
- Screenshots need `xvfb-run` and `--rendering-driver opengl3`. `run_tests.sh` never runs `screenshot.gd`.

### Project Structure Notes

- **New:**
  - `scripts/core/palettes.gd` (+ `.gd.uid`);
  - `tests/test_palettes.gd`, `tests/smoke_palettes.gd`, `tests/deck_mock.gd` (+ uids);
  - `tests/rooms/zones/t_zone_a.txt`, `t_zone_b.txt`.
- **Changed:**
  - `core/game.gd`, `core/fx.gd`, `core/text_style.gd`;
  - `ui/gutters.gd`, `ui/theme_builder.gd` (comment);
  - `world/world.gd`, `world/room_loader.gd`;
  - `tests/test_theme.gd`, `tests/test_lint.gd`, `tests/screenshot.gd`;
  - the docs and the ledger.
- **Layering:**
  - `palettes.gd` is `core/` and names nothing above it;
  - `RoomLoader` (world) and `Gutters` (ui) read it, which points down;
  - `rules/` never reads it.
- No autoload, addon or `.tres`. No scene file changes: Gutters builds its strips in code.
- Export: `tests/*` is excluded from release, so `deck_mock.gd` never ships; `palettes.gd` ships with `scripts/`. `test_export_presets` needs no change.

### Project Context Rules (from `project-context.md`)

- Godot 4.7.2, GDScript only, GL Compatibility, 480×270 at integer scale, nearest filter. No addons, **no `.tres`**, autoloads `Game` only (+ `Audio` in E3).
- **State in pure objects, not statics.** `Game` holds refs only and keeps the same instances all session (reset in place, never replaced; setter guards). Write state only through methods that emit signals (lint `state_write`).
- **Dependencies point one way:** `rules ← core ← world/actors/… ← ui ← dev`. `core/` names no upper layer (lint `core_layer`). UI writes only `Settings`.
- **Reserved colours (NFR9):** amber `#ffd27a` is only the player's light; red `#d9473f` is only light-hunting danger, on shapes, never text. Every other UI colour comes from the active zone (DESIGN Do's and Don'ts).
- **Brightness** scales only the world's ambient level, never the UI `CanvasLayer` or the reserved colours, so the contrast floors hold at every level (architecture UI). Nothing here may route UI colours through `CanvasModulate`.
- Cache shared resources as statics. `play_text`'s cache keyed by colour pair stays.
- Comments explain *why*, citing the design ("UX-DR7: …", "DESIGN A2 …").
- Headless tests can't judge looks. Human gates are HALTs.
- Every deferred item gets an owner line, set by the agent that defers it.
- Commit `.gd.uid` files with their scripts.

### Previous story intelligence (1.16–1.17)

- **1.17 left this story two placeholders** (`Gutters.PLACEHOLDER`, `TextStyle.PLACEHOLDER_SURFACE`), the ledger item, and the rule that the theme has no colours. It also set the patterns used here:
  - `TextStyle.play_text(color, outline)` is cached per pair;
  - Labels sit at `y - CAP_TOP`;
  - widths measured at size 8: `+1240` is 24 px, ending at x 46 from x 22; digits are 5 px.
- **1.17's review lessons:**
  - pin behaviour against the design's numbers, not the code's own consts (1.16 found tests comparing consts with themselves);
  - probe engine claims on 4.7.2 before acting on them (memory);
  - a check that can't fire is worthless, so red-check every new one.
- **1.16:** `Fx` is the accessibility gate and reads `Game.settings`. `test_fx`'s reflection check fails on a public static effect function without an `EFFECTS` row. This story adds no public static to `Fx`.
- **1.14:** `Display` is the precedent for a `Game` ref that is presentation, not rules. Its notes name the Deck check: ×2 = 960×540, and `--resolution 960x540` on the desktop gives ×2 (an optional extra look; the HUD doesn't exist yet, so the mock is the check).
- **Git:** the last five commits are 1.17's feature, build records, laptop look and review fix (`52ae0cb` … `18fde0a`). Docs, the ledger and `project-context.md` move with each story; keep that habit.

### Verified facts (probed 2026-11-22 at story creation)

- **DESIGN's tokens reproduce exactly** with WCAG 2.x maths on 8-bit ints and half-up rounding (Python check, mirrored by `roundi`):

  | Zone | 0 · 1 · 2 · 3 | Gutter | HP | Label (step) | Empty (step) | Rule | Glow floor |
  |---|---|---|---|---|---|---|---|
  | dusk | `#2b1d14` `#6b4a2f` `#b08a5a` `#d8c3a0` | `#18100b` | `#d8c3a0` 10.94 / 9.49 | `#b08a5a` (0%) 5.93 / 5.14 | `#836548` (+22%) 3.51 / 3.04 | `#6b4a2f` 2.37 / 2.05 | 83% `#bb4038` 3.03 |
  | umber | `#1e1714` `#4a3a33` `#7d6a5c` `#a99a8c` | `#110d0b` | `#a99a8c` 7.08 / 6.47 | `#8f7e70` (+41%) 4.96 / 4.53 | `#726258` (+42%) 3.32 / 3.03 | `#4a3a33` 1.79 / 1.64 | 79% `#b23d36` 3.04 |
  | violet | `#0d0b14` `#2a2440` `#4f5d75` `#a9b4c2` | `#07060b` | `#a9b4c2` 9.61 / 9.30 | `#6e7b8f` (+34%) 4.71 / 4.55 | `#5c5c73` (+39%) 3.11 / 3.01 | `#2a2440` 1.37 / 1.33 | 75% `#a63834` 3.01 |

  - Ratios are on the gutter / on the play area (index 0). Before the overrides:
    - Umber label: 3.76 / 3.44;
    - Violet label: 3.03 / 2.93;
    - Dusk empty: 2.37 / 2.05;
    - Umber empty: 1.79 / 1.64;
    - Violet empty: 1.37 / 1.33.
  - Amber (gutter / play): 13.20 / 11.45, 13.58 / 12.42, 14.19 / 13.72.
  - Red (gutter / play): 4.40 / 3.82, 4.53 / 4.14, 4.73 / 4.58.
  - Every override and glow step is the smallest whole percent that passes.
- **Rounding:** Umber's gutter is 30 × 0.55 = 16.5 in red. Half up gives `#110d0b` (DESIGN); banker's rounding or truncation gives `#100d0b` / `#100c0b`. On 4.7.2, `roundi(16.5) == 17` (probed).
- **Known answers:** white/black 21.0; `#767676`/white 4.5422; `#777777`/white 4.4781.
- **`RenderingServer.set_default_clear_color(Color("#110d0b"))` then `get_default_clear_color()`** reads back `110d0b` under `--headless` (probed).
- **`Color("#8f7e70").r8 == 143`** and `to_html(false) == "8f7e70"` (probed).
- **Screenshots** under `xvfb-run … --rendering-driver opengl3` are 480×270 (probed: both shaft shots), so the ×2 is a resize.
- **Deck geometry:** 7.0" diagonal at 1280×800 is about 215.6 PPI, so 960×540 px is about 113 × 64 mm. The 7.4" OLED is about 204 PPI, about 120 mm wide.

### References

- Story source: `_bmad-output/planning-artifacts/epics.md` → Story 1.18 (UX-DR1–UX-DR9, UX-DR130, UX-DR131, NFR12); AR27 (`core/palettes.gd`); Story 1.27's AC (red migration, `palettes.gd`); Story 1.25 (rules, HUD).
- UX `DESIGN.md`:
  - front-matter `colors` and `components.zone-roles`;
  - Colors (Reserved, Layer 1 zones, Zone-matched UI roles, Contrast floors);
  - Typography (Deck check line, measured widths);
  - Layout & Spacing (Gutter HUD coordinates);
  - Shapes (icon art);
  - Components (Gutter, Menu screen D13);
  - Do's and Don'ts.
- UX `EXPERIENCE.md`: Accessibility Floor (Contrast), Responsive & Platform (Steam Deck), State Patterns (Zone change), Game Feel & Juice (zone boundary), Open Questions (D13, O4, A2).
- GDD: Art Style (reserved colours, zone table, HUD "Layout and colours: UX DESIGN.md"); Platform-Specific Details (Steam Deck check in E1).
- Architecture: `game-architecture.md` → State Management, UI (Brightness never touches the UI layer), Directory Structure (`core/palettes.gd`), System Location Mapping (Palette zones).
- Previous story: `1-17-string-table-pixel-font-and-theme.md` (D6, D15; Review Findings).
- Ledger: `deferred-work.md` → "Play-area text outline uses `TextStyle.PLACEHOLDER_SURFACE`" (owner Story 1.18).

## Dev Agent Record

### Agent Model Used

### Debug Log References

- Story creation (2026-11-22, `18fde0a`): `./run_tests.sh` → `== ALL GREEN (25 tests)`, 1715 `ok`, 0 `FAIL`.

### Completion Notes List

- Ultimate context engine analysis completed; comprehensive developer guide created.

### File List

## Change Log

- 2026-11-22: Story created (ready-for-dev).
