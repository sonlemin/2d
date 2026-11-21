---
baseline_commit: 08eb89917617f047e7593856c3d1dcd0d0b8c592
---

# Story 1.17: String table, pixel font and theme

Status: review

**Type:** dev · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP2 Kit (1.16–1.30) · **Branch:** `feat/m2-e1`

## Story

As a player,
I want crisp 8 px text in every menu and on the HUD,
so that everything I read is sharp at every integer scale.

## Acceptance Criteria

1. **The font is in the repo, pinned and imported pixel-exact.**
   - `game/fonts/` holds `fusion-pixel-8px-proportional-latin.otf`, `OFL.txt` and the upstream `LICENSES/` folder, taken unmodified from Fusion Pixel Font release **`2026.11.10`**, asset `fusion-pixel-font-8px-proportional-otf-v2026.11.10.zip` (D1). The tag, the URL and the hashes are recorded in `docs/build.md`.
   - The committed `.otf.import` pins `antialiasing=0`, `hinting=0`, `subpixel_positioning=0` and `allow_system_fallback=false`. A test loads the `FontFile` and asserts all four, so a re-import with editor defaults can't drift back.
   - `project.godot` sets `[gui] theme/custom_font` to the font, so every `Control` without its own theme draws Fusion. That includes the `Fx` popups and the dev overlays (D2).
   - The font covers Latin-1 and Latin Extended-A: a test asserts `has_char()` for U+0020–U+007E and U+00A0–U+017F, except U+00AD (soft hyphen, never drawn). The 8 px build lacks stacked Vietnamese marks and Cyrillic. M2 ships English only.

   (AR42, UX-DR11, UX-DR17; D1, D2)
2. **Text styles have one home, built in code.**
   - New `core/text_style.gd` (`TextStyle`, static, no `extends`) holds the font path, sizes, line metrics, row pitch and the play-area outline (D3).
   - New `ui/theme_builder.gd` (`ThemeBuilder`) builds one `Theme` in code from `TextStyle`, with no `.tres`. `ThemeBuilder.theme()` caches it in a static and returns the same instance on every call.
   - The theme's defaults are font Fusion at size 8. Its Label type variations:

     | Variation | Size | Line pitch | DESIGN token |
     |---|---|---|---|
     | `HudValue` | 8 | 8 | `hud-value` |
     | `HudValueLarge` | 16 | 16 | `hud-value-large` |
     | `MenuItem` | 8 | 8 | `menu-item` |
     | `BodyLine` | 8 | 12 | `body-line` |

   - `TextStyle.MENU_ROW_PITCH` is 24, for the UI kit's rows (1.31).
   - The pitches come from Label's `line_spacing` constant (D4). A test measures each: the height of a two-line Label minus the height of a one-line Label.
   - `Gutters` and `ScreenRouter` set `theme = ThemeBuilder.theme()` in `_ready()`, so every HUD element and screen added later inherits it.
   - The theme carries no colours: the palette roles are Story 1.18's.

   (AR40, UX-DR12; D3, D4)
3. **Text over the play area has the 1 px four-side outline.**
   - `TextStyle.play_text(color, outline_color)` returns a cached `LabelSettings` at size 8. The four outline copies are stacked shadows at (±1, 0) and (0, ±1), each with an outline size of 0. The result is a 1 px outline on four sides with no diagonals, drawn behind the glyph (D5, probed).
   - The outline colour is the zone surface colour. Until Story 1.18 brings `core/palettes.gd`, it is `TextStyle.PLACEHOLDER_SURFACE = #0d0b14`, Cold violet zone index 0, the zone `m1_shaft` uses (D6).
   - `ThemeBuilder` exposes the same style for UI-layer text over the play area (the death card, the "Not saved" note) by calling `TextStyle`.
   - Gutter and menu text get no outline (UX-DR15).

   (UX-DR15; D3, D5, D6)
4. **The M1 popups draw in the game font at size 8, with the outline.**
   - `Fx.popup()` gives its Label `TextStyle.play_text(color, TextStyle.PLACEHOLDER_SURFACE)`. The `size` parameter goes, and so do the `font_size`, `outline_size` and `font_outline_color` overrides. `chain_popup()` stops passing 10 at 5+ links, and `player.gd`'s bank and loss popups stop passing 10. Every popup is 8 px (D7).
   - Unchanged: the unshaded material, rise, fade, position, colours and `reduced_motion` behaviour.
   - `Fx.warm_up()`'s label uses the same `LabelSettings` as a real popup, so the warm-up draws the same font, size and outline.

   (UX-DR11, UX-DR15; D7)
5. **Player-facing text goes through the string table.**
   - `game/text/strings.csv` has the header `keys,en`. The import options are committed: `compress=1`, `unescape_keys=false`, `unescape_translations=true`.
   - Commit the generated `strings.en.translation` with its `.import`: re-import is byte-identical (probed).
   - `project.godot` registers `[internationalization] locale/translations=PackedStringArray("res://text/strings.en.translation")`. The fallback locale stays `en`.
   - Keys are UPPER_SNAKE with a domain prefix from a list kept in the test (D8). This story's only keys are the two M1 popup words, moved verbatim (D9):

     | Key | en |
     |---|---|
     | `POPUP_BANKED` | `+%d banked` |
     | `POPUP_LOST` | `-%d lost` |

   - `player.gd` shows them as `tr("POPUP_BANKED") % amount` and `tr("POPUP_LOST") % lost`. Story 1.26 deletes both popups and both keys.
   - The chain popup's `x%d  +%d` stays a numeric format string, not a key: the HUD and in-world numbers carry no localised text (UX-DR150).
   - Write no other keys: no `MENU_*` "for later". New copy needs sonlm's approval (NR2), and an unused key fails AC6.

   (AR41, NFR17, UX-DR14, UX-DR150; D8, D9)
6. **A test fails on any key problem, and `tools/export.sh` runs it.** New `tests/test_strings.gd` (D10):
   - **Table:** the header is exactly `keys,en`; every key matches the pattern and has a listed prefix; keys are unique; `en` is non-empty with no leading or trailing whitespace; every character of every `en` has a glyph in the font (newline excepted).
   - **Registered and current:** for every key, `TranslationServer.translate(key)` equals the CSV's `en` after unescaping. This catches a stale committed `.translation`.
   - **Locale fallback:** under a non-English locale (`vi`, then `de`) a key still translates to English, then the locale is restored. The laptop and browsers may not be `en`.
   - **Code scan (scripts/ and scenes/):**
     - every literal key in `tr(…)`, `tr_n(…)`, `atr(…)`, `atr_n(…)` and `TranslationServer.translate(…)` exists;
     - every string literal that matches the key pattern with a listed prefix (keys held as data, like E4/E5 dialogue tables) exists;
     - every CSV key is referenced at least once, so no dead text ships;
     - a string literal passed directly to `tr()` / `translate()` that is not key-shaped fails. This catches composed keys such as `tr("DEATH_%s_LINE" % cause)`, which the scan can't resolve. Keys built per cause live as whole literals in a data table (D10).
   - **Copy rules:**
     - no `en` contains "roguelike" or "downwell" (case-insensitive) or a `%%` / "percent" (no completion percentage; UX-DR56);
     - no colour word in a key outside the narrative prefixes (UX-DR55, scoped by D11).
   - **Scenes:** no `text = "…"` property in `scenes/**/*.tscn` holds a run of two lowercase letters (raw UI text in a scene).
   - Every validator is a pure function returning an error list, with a firing sample and a near-miss.
   - `tools/export.sh`'s content step runs `test_strings` through the runner after `smoke_rooms`, with the same verdict rules (exit 0, no error line, its `PASS` line). The header comment, the step comment and `docs/build.md` say so.

   (AR41, AR52, NFR17, UX-DR54–UX-DR56; D8, D10, D11)
7. **A lint rule stops raw player text in code.**
   - New `test_lint` rule `raw_text` (a `code` pattern). It fails on a text sink on the same line as a string literal holding two consecutive lowercase letters. The sinks:
     - `.text =`
     - `set_text(`
     - `popup(`
     - `draw_string(` / `draw_multiline_string(`
     - `add_item(`
     - `tooltip_text =` / `placeholder_text =`
     - `append_text(` / `add_text(`
   - `skip = ["dev/"]`: the overlays are debug text, never shipped.
   - Firing samples:
     - `l.text = "Resume"`
     - `Fx.popup(p, pos, "+%d banked" % n, c)`
     - `draw_string(f, v, "Paused")`
   - Near-misses:
     - `l.text = tr("MENU_RESUME")`
     - `l.text = "x"`
     - `"x%d  +%d" % [a, b]` passed to `popup(`
     - a comment
     - a non-sink line
   - Docs table row (D12).

   (AR41, AR48; D12)
8. **Every build ships the licences.**
   - A new `tools/export.sh` step, `licences`, runs right after the exports. It copies `game/fonts/OFL.txt` and `game/fonts/LICENSES/` into each of `windows/`, `linux/`, `web/` and `web_debug/`, plus `GODOT_LICENSES.txt`.
   - `GODOT_LICENSES.txt` is written once per build by a new `tools/godot_licenses.gd`, run with the pinned 4.7.2 binary. It contains:
     - the engine's MIT text (`Engine.get_license_text()`);
     - every third-party component (`Engine.get_copyright_info()`: name, files, copyright lines, licence);
     - every licence's full text (`Engine.get_license_info()`).
   - The step fails if any of the three is missing or empty in any folder. The size step counts the web folder's new top-level text files, as it already counts everything there.
   - The PCK step's required lists gain the font's import remap and its `.fontdata`, and `res://text/strings.en.translation`, for every preset.
   - Header comment, step comment, summary line and `docs/build.md` updated.

   (AR42, AR52, NFR18, UX-DR16; D13)
9. **Copy voice is recorded as a rule.** All UI copy is terse field notes, names shapes never colours, never says "roguelike" or "Downwell-like" and never shows a completion percentage. The parts a test can hold are AC6's checks. The rest is a review rule, written once in `docs/development-guide.md` under a new "Player-facing text" section, with the workflow (NR2: copy is approved by sonlm before commit). There is no voice acting, and none is added. (UX-DR54–UX-DR56, NR25)
10. **Done means green.**
    - `cd game && ./run_tests.sh` gives `== ALL GREEN`.
    - Every new check is red-checked (break the code, see `FAIL`, restore).
    - `tools/export.sh` gives `== BUILD OK` with the licences in all four folders.
    - The docs are updated (D14).
    - The laptop look (Task 10) is the human gate. It is a font look at ×3 and in the web build, not the Deck-size sign-off, which is Story 1.18's.

## Tasks / Subtasks

- [x] **Task 1: Baseline (AC: 10).** `cd game && ./run_tests.sh` → `== ALL GREEN (23 tests)`, 1565 `ok`, 0 `FAIL` (measured at story creation on `08eb899`, 2026-11-21). Re-run it and record the result in the Dev Agent Record.
- [x] **Task 2: Font files and import (AC: 1).**
  - [x] Download the release zip into an empty scratch folder and check its SHA-512 (Verified facts). Copy `fusion-pixel-8px-proportional-latin.otf`, `OFL.txt` and `LICENSES/` (four sub-folders) into `game/fonts/` unmodified. Leave out the other locale builds (`ja`, `ko`, `zh_*`).
  - [x] Run `godot --headless --path game --import`, then edit `game/fonts/fusion-pixel-8px-proportional-latin.otf.import` to set the four pinned params, then import again. Commit the `.otf`, the `.otf.import`, `OFL.txt` and `LICENSES/`. The `.txt` files are not imported (no `.import` beside them; check).
  - [x] `project.godot`: add `[gui] theme/custom_font="res://fonts/fusion-pixel-8px-proportional-latin.otf"`. Don't touch the `gui/theme/default_font_*` settings: they apply only to the engine's built-in font.
- [x] **Task 3: `core/text_style.gd` (AC: 2, 3).**
  - [x] Consts:
    - `FONT_PATH`;
    - `SIZE := 8`, `SIZE_LARGE := 16`;
    - `LINE_SPACING_SINGLE := -4`, `LINE_SPACING_BODY := 0`, `LINE_SPACING_LARGE := -8` (D4);
    - `BODY_PITCH := 12`, `MENU_ROW_PITCH := 24`;
    - `CAP_TOP := 3` and `CAP_TOP_LARGE := 6` (D4);
    - `OUTLINE_PX := 1`;
    - `PLACEHOLDER_SURFACE := Color("#0d0b14")`.
  - [x] Each const gets a `##` comment citing the DESIGN token and the probe.
  - [x] `font() -> FontFile`: one `preload`, so no file lists the path twice.
  - [x] `play_text(color: Color, outline_color: Color) -> LabelSettings`: cached in a static Dictionary keyed by the two colours (never a new resource per popup, project rule). The `LabelSettings` has `font_size = SIZE`, `font_color = color` and 4 stacked shadows at the offsets above with `outline_size` 0 and `outline_color`. `outline_size` stays 0 and `shadow_size` stays at its default; the probe drew exactly glyph, outline and background.
- [x] **Task 4: `ui/theme_builder.gd` and the UI roots (AR40) (AC: 2, 3).**
  - [x] `static func theme() -> Theme`: cached. It sets `default_font = TextStyle.font()` and `default_font_size = TextStyle.SIZE`, plus base Label `line_spacing = LINE_SPACING_BODY`. It adds type variations of `Label`: `HudValue`, `HudValueLarge`, `MenuItem` and `BodyLine`, using `set_type_variation()` + `set_font_size()` + `set_constant(&"line_spacing", …)`.
  - [x] `static func play_text(color, outline) -> LabelSettings`: delegates to `TextStyle`.
  - [x] `gutters.gd` and `screen_router.gd` set `theme = ThemeBuilder.theme()` in `_ready()`, with one `##` line each.
- [x] **Task 5: Fx popups (AC: 4).**
  - [x] Edit `Fx.popup()` and `chain_popup()` as AC4 says. `fx.gd` header line: popups draw `TextStyle.play_text`.
  - [x] `warm_up()`'s label gets `label_settings = TextStyle.play_text(SPARK, TextStyle.PLACEHOLDER_SURFACE)` and keeps `WARM_ALPHA`.
  - [x] `player.gd`: the two popups use `tr()` keys (AC5) and drop the `10`.
  - [x] The `EFFECTS` rows are unchanged: same functions, same motion.
- [x] **Task 6: String table (AC: 5).**
  - [x] Create `game/text/strings.csv` with the two rows. Import it, then set the three `.import` params (they are the defaults today; commit them explicitly).
  - [x] Add the `[internationalization]` setting. Commit the `.csv`, `.csv.import` and `strings.en.translation`.
  - [x] Check: `git status` after a second `--import` shows no change.
- [x] **Task 7: `tests/test_strings.gd` (AC: 6, 9).**
  - [x] Read the CSV with `FileAccess.get_csv_line()`, which handles quoted commas and newlines. Never use `ConfigFile` or `JSON.parse_string()` (they print `ERROR:` lines).
  - [x] Write each validator as a pure static function on a helper `tests/strings_check.gd` (not run by the glob, like `room_sweep.gd`). Each returns `Array[String]` errors and has a firing sample and a near-miss in the test.
  - [x] Unescape the CSV's `en` with `String.c_unescape()` before comparing to `translate()`. This reproduces the importer's `unescape_translations=true` (probed: `\n`, `\t`, `\\` rows all equal). Don't hand-list the escapes.
  - [x] The scan covers `res://scripts/**/*.gd` and `res://scenes/**/*.tscn`, not `tests/`. For `.gd` files, drop comments with `test_lint.gd`'s `static func strip(line, open) -> {code, bare, open}`. Preload the script and call the static; use `code` (strings kept), carrying `open` from line to line. Don't write a second stripper. For `.tscn` files, read whole lines.
  - [x] The prefix list is a const in `strings_check.gd`: `MENU`, `DEATH`, `TIER`, `NPC`, `JOURNAL`, `DEV`, `POPUP`. A story that adds a domain adds its prefix there and in the docs section.
- [x] **Task 8: `tests/test_theme.gd` (AC: 1–4).**
  - [x] Font import pins on the loaded `FontFile` (4 asserts).
  - [x] `ProjectSettings.get_setting("gui/theme/custom_font") == TextStyle.FONT_PATH`.
  - [x] `ThemeDB.fallback_font` is that font.
  - [x] Coverage loop (AC1).
  - [x] Widths against DESIGN's measured table: `0123456789` 50 px, `+1240` 24 px, `x12 +24` 33 px, and digit widths all equal (5 px) at size 8. Size 16 is exactly ×2 of size 8 for each string.
  - [x] Each variation's size and pitch (two-line minus one-line Label height, headless) against 8 / 16 / 8 / 12.
  - [x] `CAP_TOP`: `font.get_ascent(8) - 6 == TextStyle.CAP_TOP`. The cap height of 6 is DESIGN's metric, so the expected value comes from the design, not from the const.
  - [x] `ThemeBuilder.theme()` returns the same instance twice.
  - [x] `play_text()` caches: same colours give the same instance, other colours a new one. It has 4 stacked shadows at the 4 offsets, outline 0, size 8.
  - [x] The `Fx.popup` Label carries `play_text` settings, and `chain_popup` at 12 links is size 8.
  - [x] **Pixel check (D5):** there is no renderer test, because the suite runs `--headless`. After Task 5, re-run the render probe (Verified facts, last bullet) once against the real project. Use a throwaway script in the scratchpad that loads `m1_shaft` standalone and calls `Fx.popup` / `chain_popup(…, 12, …)`; don't commit it. Record in the Dev Agent Record: three colours, 4-neighbour outline, popup 8 px at 12 links. `tests/screenshot.gd` is unchanged.
  - [x] Update `test_fx`: drop any assertion on the removed overrides; the popup tests keep their rise/fade checks.
  - [x] `smoke_world`: `Gutters.theme` and `ScreenRouter.theme` are `ThemeBuilder.theme()` after World's `_ready`.
  - [x] Extend `smoke_world`'s `test_popups_in_room` (`:170`, the bank that adds a popup Label): the Label's text is `+1 banked`, not `POPUP_BANKED`. This proves `tr()` resolves through the registered table in a real node, not only in `test_strings`.
- [x] **Task 9: Lint, export and docs (AC: 7, 8, 9).**
  - [x] Add `raw_text` to `RULES` with its samples (AC7), and make the M1 popups pass.
  - [x] Write `tools/godot_licenses.gd` in `pck_list.gd`'s style: lives outside `game/`, may print. It writes to the path after `--`, quits 0, and pushes an error and quits 1 on a write failure. Run it with the project (`--headless --path "$ROOT/game" -s "$ROOT/tools/godot_licenses.gd" -- <abs out>`) or with `--main-pack` like `pck_list`. Probe which one exits cleanly with no error line, and record the result.
  - [x] `export.sh`:
    - [x] a `licences` step after `export`;
    - [x] `test_strings` in the `content` step;
    - [x] required PCK entries;
    - [x] the header's "later stories add steps (string keys and licences 1.17 …)" line becomes past tense for 1.17.
  - [x] Run `tools/export.sh` once to `== BUILD OK`. `ls` each folder for the three items.
  - [x] Docs (D14).
  - [x] Ledger entries (D15).
- [x] **Task 10: Laptop look (human gate, AC: 10).** HALT for sonlm. Look at the desktop build (×3 window) and the debug web build in `m1_shaft`:
  - pogo a chain past 5 and past 10: the chain popup stays 8 px, crisp, with a thin 1 px dark outline;
  - bank it with a landing: the "+N banked" popup;
  - die with embers held: the "-N lost" popup;
  - backquote through the dev overlays: the overlay text is now the pixel font, and the perf summary rows still fit.

  The agent records no feel and makes no "looks good" claim. Report "tests green; needs a look on the laptop". D7 is already answered (8 px always).

## Dev Notes

### What exists today (read before editing)

- **No text pipeline yet.** There is no `game/text/`, no `game/fonts/`, no `tr()` call anywhere, no `[internationalization]` or `[gui]` section in `project.godot`, and no `ThemeBuilder`. Every Control and Label draws the engine's default font (Open Sans SemiBold, default size 16).
- **The only text the player sees is `Fx` popups** (`scripts/core/fx.gd`), Labels added under the room (AR23):
  - `chain_popup()` → `popup(…, "x%d  +%d", SPARK, 8 if count < 5 else 10)`;
  - `player.gd:256` `"+%d banked"` at size 10;
  - `player.gd:328` `"-%d lost"` in `Color(1, 0.35, 0.3)` at size 10. That red is Story 1.27's to remove; leave the colour.
  - `popup()` sets `font_size`, `font_color`, `font_outline_color = Color(0.05, 0.04, 0.08)` and `outline_size = 3` as theme overrides, uses `Fx.unshaded()`, rises 14 px (`POPUP_RISE`) unless `reduced_motion()`, and fades.
  - `warm_up()` draws a one-character Label with `unshaded()` at `WARM_ALPHA`, in the default font. The ledger entry at `deferred-work.md:192` says this doesn't match the popup's font.
- **UI roots:** `World/UI` is a `CanvasLayer`. `Gutters` (`ui/gutters.gd`, a full-rect Control, two placeholder strips) and `ScreenRouter` (`ui/screen_router.gd`, one screen at a time) are Controls, so a `theme` set on them reaches their children. World-space Labels (the popups) are under a `Node2D` and never inherit a Control's theme. That is why the outline style lives in `core/` (D3).
- **Dev overlays** (`scripts/dev/overlays.gd`) draw and measure with `ThemeDB.fallback_font` at `FONT_SIZE` 8. `SUMMARY_ROW_CHARS := 90` is "about 400 px of the size-8 fallback font". With `custom_font` the fallback becomes Fusion. A real 88-character summary row measures 403 px in Fusion 8 (probed), so 90 still fits 480. Update only the comment ("the project font, Fusion 8: an 88-character row is 403 px"). `test_dev_args` checks character counts, not pixels, so nothing there moves.
- **`tools/export.sh`** (335 lines) has the steps preflight → version → import → content (`smoke_rooms`) → export → pck → size → boot → web_smoke → summary. `fail()`, `godot_run()`, `check_run()` and `errors_in()` are the helpers to reuse. The PCK step lists each pack with `tools/pck_list.gd` and checks `required=(…)` regexes per preset. Header lines 11–12 and the content comment at 187–188 promise "string keys and licences 1.17". `docs/build.md:37` says the same.
- **`tests/test_lint.gd`**: `RULES` rows `{id, bare, code, only, skip, allow}`. `code` patterns run on code with comments dropped and strings kept. Samples are per rule in `_test_rules()`.
- **Baseline:** 23 tests, 1565 `ok` (Task 1).

### Decisions

- **D1: Font release pinned at `2026.11.10`.** It was the latest on 2026-11-21 (published 2026-11-09).
  - The asset holds seven locale builds; only `-latin.otf` is used.
  - The `.otf` is 2.5 MB because the build carries the CJK glyphs too. It is not subset: subsetting is a modification under OFL, and the 30 MB web budget has room (4.7.2's web folder is ~10 MB gzip).
  - `OFL.txt` declares no Reserved Font Name (checked). UX-DR16's "a modified copy drops the Reserved Font Name" therefore doesn't bite, but we ship it unmodified anyway.
  - `LICENSES/` holds the licences of the fonts Fusion draws on: `boutique-bitmap-7x7/OFL.txt`, `galmuri/LICENSE.txt`, `misaki/misaki.txt` and `miseki-bitmap/LICENSE.txt`.
- **D2: Project-wide default font via `gui/theme/custom_font` (probed).** Setting it makes `ThemeDB.fallback_font` the Fusion `FontFile`, so every Control draws the game font without anything naming the theme. That covers world-space popups, the dev overlays and the warm-up label. The fallback size stays 16 (no project setting changes it), so text outside a themed root sets its size explicitly: the popups through `LabelSettings`, the overlays through `FONT_SIZE`. No `.tres`: the setting points at the `.otf`, a resource with an `.import`.
- **D3: `TextStyle` in `core/`, `ThemeBuilder` in `ui/`.**
  - The popups are built by `Fx` in `core/`, and lint `core_layer` forbids `core/` naming anything in `ui/`. So the font, the metrics and the play-area outline live in a new `core/text_style.gd`.
  - `ThemeBuilder` (`ui/`, as the architecture places it) builds the `Theme` from those consts and re-exposes `play_text` for UI-layer text. Dependencies still point one way (`ui → core`).
  - `TextStyle` is a new file the architecture's tree doesn't list: add it there (D14).
- **D4: Line metrics, probed on 4.7.2.**
  - At size 8 the font reports ascent 9, descent 3 and height 12; at 16, 18 / 6 / 24. Label's default `line_spacing` constant is 3.
  - Two-line Label heights at size 8 were 20 / 24 / 27 for `line_spacing` −4 / 0 / 3. The pitch (height of two lines minus one) is therefore `12 + line_spacing`: −4 gives DESIGN's 8 px row, 0 gives the 12 px `body-line` pitch, and −8 at size 16 gives 16.
  - The cap top sits `ascent − cap height` = 9 − 6 = 3 px below a Label's top. Confirmed in the render probe: label at y 10, first glyph row at y 13, baseline at y 19.
  - DESIGN's y coordinates (`value-top: 24px`, pip rows, menu rows) assume an 8 px text row. So 1.25 and 1.31 place a Label at `y − CAP_TOP` to put the cap top on the token. `TextStyle.CAP_TOP` publishes this so neither story re-derives it.
  - Note this in `TextStyle`'s header; don't move any existing node.
- **D5: The outline is stacked shadows (probed under `xvfb` + `opengl3`, 4.7.2).**
  - The probe used `LabelSettings` with `stacked_shadow_count = 4`, offsets (1, 0), (−1, 0), (0, 1), (0, −1), each `outline_size` 0, and `Fx`'s unshaded material under a `CanvasModulate` at 0.1. It drew exactly three colours: background, outline `#0d0b14` and glyph `#ffd17a`.
  - The outline was 4-neighbour with no diagonal pixels, the glyph was drawn over it, and the glyph was not darkened by the `CanvasModulate`.
  - At size 16 every glyph pixel became an exact 2×2 block (glyph pixel count 228 = 57 × 4) and the outline stayed 1 px.
  - The font's own `outline_size` is *not* used: it strokes in every direction, diagonals included, against UX-DR15's "no diagonals".
- **D6: Placeholder surface colour.** `#0d0b14` is DESIGN's Cold violet index 0, the zone `m1_shaft` declares (`zone=violet`). It is also what `Gutters.PLACEHOLDER`'s violet gutter pairs with, and nearly M1's `Color(0.05, 0.04, 0.08)` (`#0d0a14`). So the popups' outline colour barely changes; its width goes from 3 px to 1 px on four sides. Story 1.18 replaces the const with the active zone's surface from `core/palettes.gd` (ledger, D15).
- **D7: Popups at 8 px, M1's 10 px dropped (sonlm, 2026-11-21: "8 px always").**
  - Size 10 of an 8 px pixel face is ×1.25. The render probe drew `x12 +24` at 10 with uneven stroke widths: 115 glyph pixels against 57 at size 8, where a clean scale would be a whole multiple. That breaks UX-DR11 ("size 8") and DESIGN's "never scaled by fractions".
  - DESIGN's bank-popup row ("8 px, or 10 px at 10+ links. Kept from M1") contradicts its own typography rule. M1's code actually steps at 5 links, not 10.
  - This story draws every popup at 8. The alternative for a "bigger at a long chain" read is 16 (an exact ×2, `x12 +24` = 66 px wide).
  - **Answered at story creation (sonlm, 2026-11-21): 8 px at every count.** The gutter chain number carries the "long chain" read.
  - The dev corrects DESIGN.md's bank-popup row (Components → Bank popup: "8 px, or 10 px at 10+ links" becomes "8 px at every count; 10 px would scale the 8 px face by a fraction (Story 1.17 D7, sonlm 2026-11-21)").
  - The ledger entry for Story 1.26 records the answer so 1.26 keeps it (D15).
- **D8: Key shape.**
  - The pattern is `^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$` (at least two segments); the first segment is the domain prefix.
  - The listed prefixes start at the architecture's examples plus this story's own: `MENU`, `DEATH`, `TIER`, `NPC`, `JOURNAL`, `DEV`, `POPUP`. A key with an unlisted prefix fails, which forces a deliberate choice of domain.
  - Keys are save-adjacent only through the death log, which stores cause ids, not keys (Story 1.29), so keys can still be renamed freely.
- **D9: Move only the existing copy, verbatim.** The two M1 popup strings are the only player-facing words in the game today, and Story 1.26 deletes them. Routing them through `tr()` now lets the scan, the lint and the table hold from the first commit instead of waiting for 1.25.
  - `tr()` is a Node method, so it is called in `player.gd`, not inside the static `Fx`.
  - `%d` stays in the translation; GDScript's `%` formats it after lookup.
  - Inventing menu or death copy here would break NR2 and leave dead keys.
- **D10: What the key test covers, and why each part.**
  - `tr()` silently returns the key when it is missing, so a missing key shows as `POPUP_BANKED` on screen. That is why the scan exists (architecture, Error Handling).
  - Static code can't call `tr()`, and E4/E5 keep keys in data tables. So the scan also reads `TranslationServer.translate()` and bare key-shaped literals with a listed prefix.
  - The "registered and current" check is the only thing that catches a CSV edited without a re-import: the committed `.translation` would then be stale.
  - The locale check exists because `TranslationServer.get_locale()` is the OS locale (`en_US` on the server). A `vi_VN` laptop falls back to `en` only if the fallback holds.
  - Non-literal `tr(x)` calls are allowed: the data-table literals carry the keys.
  - A composed key (`tr("DEATH_%s_LINE" % cause)`) is not allowed. Its literal isn't key-shaped, so the scan would pass it while the CSV lacks the real key. The rule, also written in the docs section: every key appears whole as a literal somewhere in `scripts/`.
- **D11: Copy-rule checks that won't need loosening later.**
  - Banned everywhere: "roguelike", "downwell" (UX-DR56), and `%%` / "percent" (no completion percentage).
  - Colour words (`red`, `green`, `blue`, `yellow`, `orange`, `amber`, `purple`, `violet`, `pink`, `white`, `black`, `grey`, `gray`, whole words, case-insensitive) are banned in every key **except** the narrative prefixes `NPC_` and `JOURNAL_`. UX-DR55 binds death lines, tips and cues, while narrative prose follows `narrative-design.md` and E4/E5's validators.
  - Changing that scope is a design change made with sonlm first (project rule: never loosen a threshold to pass).
- **D12: Lint `raw_text`.**
  - The requirement: two consecutive lowercase letters **inside a string literal**, on a line with a sink, after the sink.
  - A naive `(<sink>).*["'][^"']*[a-z]{2}` is wrong: it can't tell a closing quote from an opening one. In `tr("POPUP_BANKED") % amount` it matches from the closing quote through `am`, so it fires on correct code, and only the real-tree scan would show it.
  - Pair the quotes. Either walk the literals from the sink onward (the `strip()` output tells code from string), or use a pattern that consumes whole literals: `<sink>(?:[^"']|"[^"]*"|'[^']*')*?"[^"]*[a-z]{2}` (and the `'` form). Pick one and test it on the near-misses below.
  - Near-misses that must stay green:
    - `Fx.popup(_fx_parent(), pos, tr("POPUP_BANKED") % amount, c)`
    - `l.text = tr("MENU_RESUME") + suffix`
  - Key literals are all upper case, so `tr("MENU_RESUME")` never fires, and neither do numeric formats like `"x%d  +%d"` (no two lowercase letters together).
  - A `rule` that `strip()` can serve: if `bare` blanks string contents, a `bare`-side sink match plus a `code`-side literal check on the same span is another clean split. The rule only has to fire on literal text.
  - `only = []`, `skip = ["dev/"]`, `allow = []`.
  - The lint scans only `.gd`; scenes are AC6's scene check.
  - Header comment line: what a text scan can't see (text built in a variable on an earlier line, `call("set_text", …)`). Review covers those.
- **D13: Licences.**
  - NFR18 and UX-DR16 require the font licence and Godot's MIT licence with its third-party notices in every build, web included.
  - The tool runs on the editor binary, which preflight already pins to 4.7.2. Its third-party list includes some editor-only components the templates lack. A superset notice is compliant; say so in the script's header.
  - Copied files land at each build folder's top level: `OFL.txt`, `LICENSES/`, `GODOT_LICENSES.txt`. The itch.io web zip is the `web/` folder, so they ship.
  - Credits text naming the font is Story 7.11's (UX-DR16 owner E7); not here.
- **D14: Docs.**
  - `docs/build.md`: the steps table (content gains `test_strings`; the new `licences` step), a "Third-party files" section (release tag, URL, zip SHA-512, `.otf` and `OFL.txt` SHA-256, the four pinned import params), and the new PCK required entries.
  - `docs/development-guide.md`:
    - a new "Player-facing text" section: CSV, keys, prefixes, `tr()` vs `TranslationServer.translate()`, re-import and commit the `.translation`, AC9's voice rules, NR2;
    - the lint table row `raw_text`;
    - `test_strings` / `test_theme` in the test list.
  - `docs/component-inventory.md`: `TextStyle`, `ThemeBuilder`, the `Fx.popup` change.
  - `docs/source-tree-analysis.md`: `fonts/`, `text/`, the new scripts and tools.
  - `game/README.md`: the test list.
  - `project-context.md`: one line in the Story list saying what 1.17 added. The Code Organization "All player-facing text via `tr()`" rule gains "(`tr()` in nodes, `TranslationServer.translate()` in static code; keys held as data are scanned too; lint `raw_text`)". The Testing lint summary gains `raw_text`.
  - `game-architecture.md`: the directory tree gains `core/text_style.gd`; UI → Strings gains one sentence on the scan and the export step; Build and Export → As built gains the licences step.
  - UX `DESIGN.md` → Components → Bank popup: the size sentence, per D7 (sonlm's answer).
- **D15: Ledger entries the dev adds**, each with an owner line (`→ **Owner: …** — why`):
  - "Play-area text outline uses `TextStyle.PLACEHOLDER_SURFACE` (Cold violet), not the active zone's surface" → **Story 1.18** (palettes and per-zone colours).
  - "Bank popup size: 8 px at every count (sonlm, 2026-11-21; DESIGN row corrected in 1.17)" → **Story 1.26** (owns the bank popup; keep 8 when rebuilding it).
  - "Window title `config/name` still reads 'The Unbroken Chain (M1 prototype)' and isn't a string key" → **Story 1.33** (title screen shows the name).
  - Also edit the 7.13 entry at `deferred-work.md:192`: the warm-up label now matches the popup (font, size, outline), so drop that clause. The owner stays 7.13.
- **D16: Red-checks.** Break each new check once, see `FAIL`, and restore:
  - an import param back to 1;
  - `custom_font` removed;
  - a variation's `line_spacing` changed;
  - `CAP_TOP` 4;
  - `play_text` built uncached;
  - a 3-sided outline;
  - `tr("POPUP_BANKD")`;
  - the CSV edited without re-import;
  - a dead key added;
  - a key with an unlisted prefix;
  - "roguelike" in an `en`;
  - `"+%d banked"` back as a literal (lint);
  - `export.sh`'s licence copy skipped for `web/` (run once, or prove it with a dry function test).

### Testing standards

- Tests extend `Node`, run through `tests/runner.tscn`, print `ok …` / `FAIL …` and a final `PASS` / `FAILED`. Any `SCRIPT ERROR` / `ERROR:` line fails the run. Name new tests `test_*.gd`, so the glob finds them; helpers (`strings_check.gd`) are not matched.
- Validators are pure and return error lists; tests inspect the list and never trigger `push_error`.
- Thresholds from the design (DESIGN's measured widths, cap 6, pitches 8/12/16) are written in the test with their DESIGN citation, never read back from `TextStyle`'s own consts. `CAP_TOP` is checked against `ascent − 6`, not against itself. Pitch values go in `tests/spec.gd` only if a guarantee test elsewhere needs them; otherwise keep them local with the citation.
- `TranslationServer.set_locale()` in a test is restored at the end (`en_US` or whatever `get_locale()` returned first).
- Settings and state: nothing here writes `Game` state. Call `Game.reset_for_tests()` only if a test touches the gate.
- Headless can measure fonts, Labels and `LabelSettings`, but can't see pixels. The outline and crispness are Task 10's look (plus the optional renderer smoke).

### Project Structure Notes

- New: `game/fonts/` (`.otf` + `.import`, `OFL.txt`, `LICENSES/`), `game/text/` (`strings.csv` + `.import`, `strings.en.translation`), `scripts/core/text_style.gd`, `scripts/ui/theme_builder.gd`, `tests/test_strings.gd`, `tests/strings_check.gd`, `tests/test_theme.gd`, `tools/godot_licenses.gd`. Commit every new script's `.gd.uid` with it.
- Changed: `project.godot` (`[gui]`, `[internationalization]`), `core/fx.gd`, `actors/player.gd`, `ui/gutters.gd`, `ui/screen_router.gd`, `dev/overlays.gd` (comment only), `tests/test_lint.gd`, `tests/test_fx.gd`, `tests/smoke_world.gd`, `tools/export.sh`, docs.
- Layering: `core/text_style.gd` names no upper layer. `ui/theme_builder.gd` uses `core/`. `Fx` uses `TextStyle` (core → core). Nothing in `scenes/` changes. No autoload, addon or `.tres`.
- Export: `all_resources` already ships the imported font and the `.translation`; `fonts/*.txt` and `LICENSES/` are not resources and stay out of the PCK, which is why `export.sh` copies them beside each build. `test_export_presets` needs no change.

### Project Context Rules (from `project-context.md`)

- Godot 4.7.2, GDScript only, GL Compatibility, 480×270 integer scale, nearest filter, `snap_2d_transforms_to_pixel`. No addons, **no `.tres`** (TileSet, Theme and materials built in code), autoloads `Game` only (+ `Audio` in E3).
- **UI font:** Fusion Pixel Font 8px proportional (OFL 1.1), size 8, antialiasing and hinting off. `OFL.txt` + `LICENSES/` ship in every build.
- **All player-facing text via `tr("UPPER_SNAKE_KEY")`** from `game/text/strings.csv`. Copy names shapes, never colours. Commit the generated `.translation` files.
- Cache shared resources as statics; never build a new resource per effect (the `LabelSettings` cache).
- Dependencies: `rules ← core ← world/actors/objects/moments ← ui/audio ← dev`. Lint `core_layer` holds `core/` below `ui/`.
- Content errors → a pure validator + `push_error` + refuse to build. `tools/export.sh` validates string keys before any export (AR52).
- Builds come from the server; every Godot step runs under `timeout` and is scanned for `ERROR:` lines, since Godot exits 0 on some errors. Every path handed to Godot is absolute.
- No `print(` in game code (`Log`); tools outside `game/` may print. Never `free()`.
- Story text follows `narrative-design.md`, and no line is written until sonlm approves (this story writes none).
- Headless tests can't judge feel or looks: report "tests green; needs a look on the laptop".
- Every deferred item gets an owner line, set by the agent that defers it.

### Previous story intelligence (1.13–1.16)

- 1.13 built `export.sh` with the content step reserved for this story's string keys and the licences. Follow its patterns: `godot_run` + `check_run` + a `grep -qx 'PASS'`-style line check. The step fails on any `ERROR:` line. A rebuild of the same version replaces its folder.
- 1.16 made `Fx` the accessibility gate and the owner of `popup()` and `warm_up()`. `test_fx` pins the 14 px rise and the fade, and the reflection check fails on a public static effect function without an `EFFECTS` row. `TextStyle` lives outside `Fx`, so that check is unaffected. Don't add a public static to `Fx` for the text style.
- 1.16's review found that test assertions compared consts with themselves. Here, compare against DESIGN's numbers (50 / 24 / 33 px, cap 6, pitches) and the probe, never `TextStyle` with `TextStyle`.
- Engine-behaviour claims need a 4.7.2 probe (memory). This story's probes are in Verified facts; re-probe anything new, such as how `godot_licenses.gd` exits under each invocation.
- `JSON.new().parse()` only. `ConfigFile` and `JSON.parse_string()` print `ERROR:` lines. For the CSV, use `FileAccess.get_csv_line()`.

### Verified facts (probed 2026-11-21 on the server, Godot 4.7.2.stable.official.ed1daf0bf)

- **Release:** `TakWolf/fusion-pixel-font` latest tag `2026.11.10` (published 2026-11-09T20:53Z). `fusion-pixel-font-8px-proportional-otf-v2026.11.10.zip` is 17,520,997 bytes:
  - zip SHA-512: `3b332a100518738d1acbc2beb7cefef19f1dec8e01f363f258264099d9071b2e78d1e120e49b188da83646dbaa273507bb49423b239f1d96be258b86ab9bc8d9`
  - `fusion-pixel-8px-proportional-latin.otf` (2,501,068 bytes) SHA-256: `82f1df2f423d8a4880f3dd6f1839a34855648c69e2a3652a3e8f09d665971be2`
  - `OFL.txt` SHA-256: `bc518cf64b8032c07690f33cc270c35c179255a6ac8efa7c165ebae7e8f76a63`
  - The zip holds `OFL.txt`, `LICENSES/{boutique-bitmap-7x7/OFL.txt, galmuri/LICENSE.txt, misaki/misaki.txt, miseki-bitmap/LICENSE.txt}` and seven `.otf` locale builds. The font name reads "Fusion Pixel 8px Prop latin".
- **Default font import** (`font_data_dynamic`): `antialiasing=1`, `hinting=3`, `subpixel_positioning=4`, `allow_system_fallback=true`. The loaded `FontFile` read `hinting 0` and `subpixel 0` (pixel-font auto-detect) but still `antialiasing 1`, which is why all four are pinned. With `0/0/0/false` in the `.import`, the loaded font reads `aa 0, hint 0, subpx 0, sysfb false`.
- **Metrics (size 8):** ascent 9, descent 3, height 12. Widths: `0123456789` 50, `+999` 19, `+1240` 24, `x12 +24` 33, `EMBERS` 31, `Resume` 27, `Controller disconnected` 94, `1` 5. At size 16 every width is exactly double. DESIGN's table says `+1240` "about 25"; the measured 24 is what the test pins.
- **Coverage:** U+0020–U+007E and U+00A0–U+017F all present except U+00AD. `ầ` (U+1EA7) and `Ж` (U+0416) absent.
- **Label pitch:** two-line `"Ag\nAg"` minimum height 20 / 24 / 27 at `line_spacing` −4 / 0 / 3 (size 8). The default `line_spacing` is 3.
- **CSV import** (`csv_translation`): header `keys,en` → `text/strings.en.translation` beside the CSV, plus `strings.csv.import` (`compress=1`, `delimiter=0`, `unescape_keys=false`, `unescape_translations=true`). Quoted commas survive, and `\n` in a translation becomes a newline. A missing key returns the key itself. Re-importing an unchanged CSV gives a byte-identical `.translation` (same MD5).
- **Locale:** headless server `TranslationServer.get_locale()` is `en_US`; `internationalization/locale/fallback` defaults to `en`. With only an `en` table, `set_locale("vi")`, `"vi_VN"`, `"de"` and `"ja"` all still translate to the English text (probed), so no boot-time `set_locale("en")` is needed.
- **Unescape:** for rows with `\n`, `\t` and `\\`, `row[1].c_unescape()` equals `TranslationServer.translate(key)` (probed).
- **`gui/theme/custom_font`:** set to the `.otf`, `ThemeDB.fallback_font` becomes the Fusion `FontFile`, and a bare `Label` gets it at size 16 with `line_spacing` 3. Without it, the fallback is Open Sans SemiBold.
- **`LabelSettings` (4.7.2):** has `stacked_outline_count` and `stacked_shadow_count`. `set_stacked_shadow_offset/_color/_outline_size(i, …)` work. The render result is in D5.
- **Licence APIs:** `Engine.get_license_text()` is 1,149 chars, `get_copyright_info()` has 102 components and `get_license_info()` has 19 licence texts (editor binary).
- **Overlay width:** an 88-character perf summary row is 403 px in Fusion 8.
- Render probe method, for re-use: a scratch project with the font and the pinned import, a `Node2D` scene that adds Labels then saves `get_viewport().get_texture().get_image()` after 4 frames, run `timeout 60 xvfb-run -a godot --path <dir> --rendering-driver opengl3 res://shot.tscn`, and read the pixels with Pillow (`python3`, not `-I`: Pillow is in the user site).

### References

- Story source: `_bmad-output/planning-artifacts/epics.md` → Story 1.17 (AR40–AR42, AR52, NFR17, NFR18, UX-DR11, UX-DR12, UX-DR14–UX-DR17, UX-DR54–UX-DR56, UX-DR150, NR2, NR25). Story 1.13's AC promise ("string keys and licence copy in Story 1.17").
- UX: `DESIGN.md` → Typography (face, metrics, measured widths, licence, coverage, text outline), the `typography` and `components.text-outline` tokens, Components → Bank popup, Do's and Don'ts. `EXPERIENCE.md` → Voice and Tone, Localization, Notes for Other Docs (font licence note).
- Architecture: `game-architecture.md` → Development Environment (font pinned at download), Decision 18, UI (Strings, UI kit, Theme in code), Build and Export, Error Handling (missing string keys), Configuration, Directory Structure (`ui/theme_builder.gd`, `fonts/`, `text/`), Naming (string keys), Architectural Boundaries, Consistency Rules (Strings).
- `narrative-design.md` / NR2 for any future copy (none written here).
- `deferred-work.md:192` (the 7.13 first-frame entry this story edits).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), gds-dev-story, 2026-11-21/22.

### Debug Log References

- **Task 1 baseline** (`b8f93a3`): `== ALL GREEN (23 tests)`, 1565 `ok`, 0 `FAIL`. Re-run with only `custom_font` added: still 23 green, 1565 `ok` (the dev overlays and the perf smoke don't move).
- **Font download** (scratchpad, empty folder): zip 17,520,997 bytes, SHA-512 `3b332a10…bc8d9`, `.otf` SHA-256 `82f1df2f…71be2`, `OFL.txt` SHA-256 `bc518cf6…76a63`: all three match Verified facts. First import wrote `antialiasing=1`, `hinting=3`, `subpixel_positioning=4`, `allow_system_fallback=true`; pinned to `0/0/0/false` and re-imported. No `.import` appeared beside `OFL.txt` or `LICENSES/*`.
- **String table import:** `strings.csv.import` already carries `compress=1`, `delimiter=0`, `unescape_keys=false`, `unescape_translations=true` (committed as written). A second `--import` left `strings.en.translation` byte-identical (MD5 `6630d049…1d10c` before and after).
- **Render probe (D5, Task 8 pixel check)**, throwaway `popup_probe.gd` in the scratchpad (not committed), run through `tests/runner.tscn` under `xvfb-run` + `opengl3` in the real `world.tscn` with `m1_shaft`: `chain_popup(…, 3, 6)`, `chain_popup(…, 12, 24)` and `popup("+3 banked")`, read with Pillow. For each popup: glyph pixels exactly the glyph colour (`#ffd17a` / `#ffedb2`), outline pixels exactly `#0d0b14`, 0 outline pixels without a 4-neighbour glyph, 0 glyph sides without outline, 0 diagonal-only outline pixels; caps 6 rows tall. `x12  +24` at 12 links: 57 glyph pixels and 6-row caps, the size-8 count from the story's probe (size 10 drew 115), so 8 px. Background pixels around the two left popups vary because the real room is lit behind them; around `+3 banked` the background was one colour, so that crop held exactly three colours.
- **`godot_licenses.gd` probe:** `--headless --path game -s … -- <out>` and `--headless --main-pack <linux pck> -s … -- <out>` both exit 0 with no `ERROR` / `WARN` / `SCRIPT` line and write identical files (96,747 bytes; 106 component parts, 19 licence texts). A bad path prints `ERROR: godot_licenses: cannot write … (File not found)` and exits 1. `export.sh` uses `--path game` (no built PCK needed), under `XDG_DATA_HOME=$RUN_DATA` like the listings.
- **Real PCK paths** (`pck_linux.txt` of the first build): `res://fonts/fusion-pixel-8px-proportional-latin.otf.import`, `res://.godot/imported/fusion-pixel-8px-proportional-latin.otf-f58d28e3e6e45f174646544d86e33822.fontdata`, `res://text/strings.en.translation` (plus `strings.csv.import`); the three required regexes match them.
- **Red-checks (D16)**, each broken, `FAIL` seen, restored:
  - import `antialiasing=1` (re-imported) → `FAIL font: antialiasing off (got 1)`;
  - `custom_font` removed → `FAIL project.godot gui/theme/custom_font …` and `FAIL ThemeDB.fallback_font …`;
  - `BodyLine` given `LINE_SPACING_SINGLE` → `FAIL BodyLine: size 8, line pitch 12 px (got 8, 8.0)`;
  - `CAP_TOP` 4 → `FAIL CAP_TOP is ascent - DESIGN's cap 6 (ascent 9.0, CAP_TOP 4)`;
  - `play_text` uncached → `FAIL play_text() caches…` and `FAIL Fx.popup's Label carries play_text…`;
  - 3-sided outline → `FAIL play_text: four shadows… (count 3…)`;
  - `tr("POPUP_BANKD")` → `FAIL code scan: …player.gd:256: key POPUP_BANKD is not in text/strings.csv` (and POPUP_BANKED dead);
  - CSV edited without re-import → `FAIL registered and current: row 2: POPUP_BANKED translates to '+%d banked', not the CSV's '+%d saved'`;
  - dead key `MENU_RESUME` added → `FAIL code scan: … key MENU_RESUME is referenced nowhere`;
  - `SHOP_BUY` → `FAIL table: row 4: key SHOP_BUY has an unlisted prefix`;
  - "roguelike" in an `en` → `FAIL copy rules: row 3: POPUP_LOST says 'roguelike'` (a first try with a comma tripped the cell-count check instead, also a FAIL);
  - `"+%d banked"` back as a literal → `FAIL lint actors/player.gd:256 raw_text`;
  - `export.sh` with `web` left out of the licence copy (a full run) → `== BUILD FAILED: licences: web/OFL.txt is missing or empty`.
  - `test_strings` inside `export.sh` (after the commit, on `592f068`):
    - `tr("POPUP_BANKD")` failed the content step earlier, at `smoke_rooms`: `tr()` returns the bare key, which has no `%d`, so `% amount` printed `ERROR: String formatting error` → `== BUILD FAILED: content: error lines in its log`.
    - A dead key (`MENU_RESUME,Resume` appended to the CSV) survives `export.sh`'s own re-import and reaches `test_strings` → `FAIL code scan: … MENU_RESUME is referenced nowhere` → `== BUILD FAILED: content: string keys: error lines in its log (exit 1)`, before any export.
    - Restored with `git checkout` and a re-import (`.translation` MD5 back to `6630d049…`, clean tree). The `builds/20261122-592f068-dirty` folder is this deliberately failed run.
- **Builds:** `20261121-b8f93a3-dirty` (before the commit): `== BUILD OK …, web download 11.0 MB (gzip; raw 40.8 MB), licences in 4 folders, PCK files windows 84 / linux 84 / web 84 / web_debug 91, 120 s`; `OFL.txt`, `LICENSES/` (4 files) and `GODOT_LICENSES.txt` listed in each of the four folders. The clean build after the commit is recorded in the Completion Notes.

### Completion Notes List

- Story created 2026-11-21: ultimate context engine analysis completed - comprehensive developer guide created.
- **Implemented (Tasks 1–9), 2026-11-22.** Font pinned and imported pixel-exact, and made the project font (`gui/theme/custom_font`). `core/text_style.gd` (`TextStyle`) and `ui/theme_builder.gd` (`ThemeBuilder`), with the theme set on `Gutters` and `ScreenRouter`. `Fx.popup()` draws `TextStyle.play_text` at 8 px with the 1 px four-side outline (the `size` parameter and M1's overrides are gone; `chain_popup` is 8 px at every count, per D7). `warm_up()`'s label carries a real popup's `LabelSettings`. The string table has `POPUP_BANKED` / `POPUP_LOST` (M1's copy verbatim) and `player.gd` shows them through `tr()`. `tests/test_strings.gd` + `tests/strings_check.gd`, `tests/test_theme.gd`, lint `raw_text`, `tools/godot_licenses.gd`, and the `export.sh` content and licences steps plus PCK entries. Docs per D14; ledger per D15.
- **Suite:** `== ALL GREEN (25 tests)`, 1665 `ok` (baseline 23 / 1565: +2 tests, +100 checks), 0 `FAIL`.
- **Choices inside the story's room:**
  - `raw_text` uses D12's literal-consuming pattern as one `code` regex (both quote kinds). Its `.text` sink also takes `+=` and refuses `==`; `tooltip_text` / `placeholder_text` likewise. 7 firing samples and 11 near-misses, D12's two near-misses included.
  - `check_copy` applies the colour-word rule to both the `en` text (whole words) and the key's segments, outside `NPC_` / `JOURNAL_`. AC6 says "in a key" and UX-DR55 is about the copy, so it checks both.
  - `TextStyle.play_text()` also sets `font = TextStyle.font()` on the `LabelSettings`, so the popup doesn't depend on the project fallback.
  - `test_fx` had no assertion on the removed overrides. It gained one check: the warm-up label shares a real chain popup's `LabelSettings` (AC4).
  - The size step still counts only top-level `web/` files. The three new top-level text files are in, `LICENSES/` (a subfolder, a few KB) is not, as AC8 states.
- **Deferred (D15), owners set:** the placeholder outline colour → **Story 1.18**; the bank popup stays 8 px → **Story 1.26**; the window title isn't a string key → **Story 1.33**. The 7.13 first-frame entry lost its warm-up-font clause (owner stays 7.13).
- **Clean build for the laptop look:** `builds/20261122-52ae0cb` (from commit `52ae0cb`): `== BUILD OK …, web download 11.0 MB (gzip; raw 40.8 MB), licences in 4 folders, PCK files windows 84 / linux 84 / web 84 / web_debug 91, 125 s`, web smoke 7 passed.
- **Task 10 done:** sonlm's laptop look passed all four items (below). Status → review.
- **Laptop look, desktop build (sonlm, 2026-11-22, Windows ×3, `20261122-52ae0cb`):** item 1 pass: the chain popup "is still the same" size past 9 and past 10; item 2 ("+N banked") and item 3 ("-N lost") "seem fine", and sonlm noted they look as in the previous story (expected: only their font and text source changed). Item 4 pass (web debug build, `?room=perf_worst&perf`): the overlays draw in the pixel font and the perf summary rows fit. On the web debug build, `?chain=8` looked like it failed on the first try: the arg was applied (`[room] dev: chain 8`, re-probed headless), but it is paid on a life's first take-off, so a hop that lands first banks it (1.11 D6, as designed).

### File List

- `game/fonts/fusion-pixel-8px-proportional-latin.otf` (new)
- `game/fonts/fusion-pixel-8px-proportional-latin.otf.import` (new)
- `game/fonts/OFL.txt` (new)
- `game/fonts/LICENSES/boutique-bitmap-7x7/OFL.txt`, `galmuri/LICENSE.txt`, `misaki/misaki.txt`, `miseki-bitmap/LICENSE.txt` (new)
- `game/text/strings.csv`, `strings.csv.import`, `strings.en.translation` (new)
- `game/project.godot` (`[gui]`, `[internationalization]`)
- `game/scripts/core/text_style.gd` + `.gd.uid` (new)
- `game/scripts/ui/theme_builder.gd` + `.gd.uid` (new)
- `game/scripts/core/fx.gd`
- `game/scripts/actors/player.gd`
- `game/scripts/ui/gutters.gd`
- `game/scripts/ui/screen_router.gd`
- `game/scripts/dev/overlays.gd` (comment only)
- `game/tests/strings_check.gd` + `.gd.uid` (new)
- `game/tests/test_strings.gd` + `.gd.uid` (new)
- `game/tests/test_theme.gd` + `.gd.uid` (new)
- `game/tests/test_lint.gd`
- `game/tests/test_fx.gd`
- `game/tests/smoke_world.gd`
- `game/README.md`
- `tools/godot_licenses.gd` (new)
- `tools/export.sh`
- `docs/build.md`
- `docs/development-guide.md`
- `docs/component-inventory.md`
- `docs/source-tree-analysis.md`
- `_bmad-output/project-context.md`
- `_bmad-output/game-architecture.md`
- `_bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/DESIGN.md`
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/1-17-string-table-pixel-font-and-theme.md`

## Change Log

- 2026-11-22: Tasks 1–9 implemented (font, theme, text style, popups, string table, `test_strings`, `test_theme`, lint `raw_text`, export content and licences steps, docs, ledger). 25 tests green, 1665 `ok`; build OK with the licences in all four folders. Task 10 (laptop look) pending.
- 2026-11-22: Task 10 laptop look passed (sonlm: desktop ×3 items 1–3, web debug item 4). Status → review.
