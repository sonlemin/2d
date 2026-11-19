---
baseline_commit: 1afcc65
---

# Story 1.14: Display scaling and web input

Status: review

**Type:** dev · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP1 Foundations (1.1–1.15) · **Branch:** `feat/m2-e1`

## Story

As a player on any screen,
I want the game scaled crisply to my window or browser,
so that pixels stay sharp and the page never scrolls under me.

## Acceptance Criteria

1. **`scripts/core/display.gd` owns the scale rule and is the only code that touches the stretch or the window.**
   - **Where it lives:** `class_name Display extends Node`. It is a child of `Game` named `Display` and held as `Game.display`, like `Game.clock`:
     - the same instance all session, and replacing it asserts;
     - `test_lint`'s `state_write` instance-replacement pattern lists `display` (D2).
   - **The rule** is a pure static, `Display.scale_for(window: Vector2i) -> float`, in physical pixels (D3):
     - `s = min(window.x / 480.0, window.y / 270.0)`;
     - `s ≥ 1`: the whole-number scale `floor(s)`, which is what the engine's integer stretch draws (F2);
     - `s < 1` (either side below 480×270): `s` itself, the fractional fit;
     - a window with no area asserts.
   - **`Display.stretch_for(window)`** returns `Window.CONTENT_SCALE_STRETCH_INTEGER` when `s ≥ 1`, else `Window.CONTENT_SCALE_STRETCH_FRACTIONAL`.
   - **`apply(window: Vector2i)`:**
     - sets `get_window().content_scale_stretch` to `stretch_for(window)` and the public `scale` to `scale_for(window)`;
     - only when `scale` changes, emits `scale_changed(scale: float)` and logs one line (D6): `[ui] display: scale 3 in 1440x810` or `[ui] display: scale 0.833 (fit) in 400x225`;
     - applying the same size again changes nothing and logs nothing.
   - **`start()`, called once by `Game.boot()`:**
     - applies `get_window().size`;
     - connects `get_window().size_changed` (to a method, not a lambda);
     - on PC, sets up the window (AC3).
     - Under the headless display server (`DisplayServer.get_name() == "headless"`: every test, and `export.sh`'s Linux boot) it does nothing, and `scale` stays `0.0`, meaning "no window" (D2, F9).
   - **Nothing else moves:**
     - `project.godot` is not edited: `viewport` stretch, `integer` scale mode, `keep` aspect, the 480×270 viewport, the 1440×810 window override, nearest filtering and pixel snap all stay (D3);
     - the game's view stays 480×270 in every mode, so `World.play_rect()`, `World.light_rect()`, `Gutters` and `CameraRig` are untouched.

   (AR8, NFR6; D2, D3, D6)

2. **On web, the scale comes from physical pixels. Below 480×270 physical pixels the view fits the window instead of being cropped.**
   - **The engine already does the HiDPI part (F1).** Godot 4.7.2's web build makes the canvas backing size the CSS size × devicePixelRatio, through `display/window/dpi/allow_hidpi` (default true) and `html/canvas_resize_policy=2` (Adaptive). So the integer stretch picks the scale from physical pixels: a 960×540 embed at DPR 1.5 is a 1440×810 window and runs at ×3 (F2). No JavaScriptBridge is needed (D1).
   - **Pinned:**
     - both `Web` presets write `html/canvas_resize_policy=2` and `html/focus_canvas_on_start=true` explicitly, and `test_export_presets` checks them;
     - `test_display` checks that the effective `allow_hidpi` is true (D1).
   - **The fit:** below 480×270 physical pixels, `Display` switches to the fractional stretch, a nearest-neighbour downscale that stays letterboxed (F3, F5). From 480×270 up it switches back to the integer stretch.
   - **The letterbox** stays pure black (F4).

   (AR8, UX-DR147, NFR6; D1, D3)

3. **On PC the window opens at ×3, or at the largest whole scale that fits the screen, and never shrinks below 480×270.**
   - **At `start()` on PC, `Display` (D4):**
     - sets `get_window().min_size = Vector2i(480, 270)`;
     - if the window plus its decorations doesn't fit the usable rect of its screen, shrinks it to the largest whole scale that does (×2, 960×540, on a 1366×768 screen), never below ×1, then centres it. It only ever shrinks a window that doesn't fit, so a `--resolution` that fits is kept.
   - **When it skips:** not on web, not when embedded in the editor, and not when the window started fullscreen or maximised. On web or when embedded it also leaves `min_size` alone.
   - **The pure rule:** `Display.window_scale_for(usable: Vector2i, decorations: Vector2i) -> int`, capped at `DEFAULT_WINDOW_SCALE` (3).
   - **The log:** `[ui] display: window x2 960x540 (screen 1366x768)`, only when it resizes the window.
   - **Fullscreen** (`--fullscreen` on the command line, or a maximised window) is just a bigger window under the same rule: integer scale, black letterbox. The fullscreen toggle is Story 7.2's.
   - **HiDPI desktops** use physical pixels (`allow_hidpi`, AC2).

   (UX-DR148, AR8; D4)

4. **On web, arrows, Space, the page keys and the function keys never scroll or act on the page, even after the canvas loses focus.**
   - **Today's gap:**
     - Godot already calls `preventDefault()` on every key the focused canvas receives (F6).
     - When focus is elsewhere in the game's page, keys go to the browser. In an itch-style embed they scrolled the host page by 619 px (F7).
   - **The guard (D5):** both `Web` presets' `html/head_include` holds the same script, a capture-phase `keydown` listener on `window`. For `ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight`, `Space`, `PageUp`, `PageDown`, `Home`, `End` and `F1`–`F12`, it:
     - calls `preventDefault()`;
     - focuses the canvas if it isn't focused, so the next key reaches the game.
   - `test_export_presets` checks that both web presets carry the same guard.
   - **F11 and F12:** the guard treats them as Godot does on the canvas. Whether the browser still honours them (fullscreen, DevTools) is up to the browser; check it on the laptop (Task 10).

   (UX-DR122; D5)

5. **The web smoke checks the scale at simulated devicePixelRatios, and the keys in an itch-style embed.**
   - **New `tools/web_smoke/embed.html`, an itch-style host page:**
     - a 100 px header, then the game in a borderless 960×540 iframe, then 3000 px of page;
     - `?build=web` or `?build=web_debug` picks the build (default `web`);
     - `serve.js` serves it at `/embed.html`, its one path outside `BUILD_DIR` (D7).
   - **`test.describe('Display scale')`**, on `Web debug`. One context per devicePixelRatio; each boots once, then resizes the viewport (D7):

     | DPR | CSS viewport steps | Physical | Expected scale |
     |---|---|---|---|
     | 1 | 960×540 → 1000×600 → 400×225 → 1000×600 | the same | ×2, ×2 letterboxed, fit 0.833, ×2 again |
     | 1.5 | 960×540 → 1000×600 | 1440×810 → 1500×900 | ×3 (the epic's example), ×3 letterboxed |
     | 2 | 960×540 → 320×180 | 1920×1080 → 640×360 | ×4, ×1 (integer: physical pixels decide, not CSS) |

     - **Each step is measured from a device-pixel screenshot**, which is the engine's real output, not the game's own report:
       - the box of non-black pixels is `480·s × 270·s` (±1 px for the fit), centred to within 1 px;
       - its leftmost and rightmost columns at mid-height are the same non-black colour (both gutters show, so nothing is cropped).
     - The newest `[ui] display:` line names the same scale.
     - Each test ends with `expectClean`.
   - **`test.describe('Web input')`**, on the release build inside `embed.html`, because the build that ships is the one that must not scroll the page:
     - **canvas focused:** every guarded key except F11 and F12 reaches the frame's `window` with `defaultPrevented`, and the host stays at `scrollY 0`;
     - **canvas blurred inside the frame:** after `document.activeElement.blur()`, the same keys leave the host at `scrollY 0`, and the canvas is focused again after the first key.
   - **Unchanged:**
     - the three existing tests;
     - `export.sh`, which already requires every test to pass and prints the count.

   (AR53, UX-DR122; D7)

6. **Tests pin it.**
   - **New `tests/test_display.gd` (D8):**
     - the `scale_for` / `stretch_for` table, with both sides of every boundary;
     - `window_scale_for`;
     - `apply()` switching the stretch both ways and emitting `scale_changed` only on a change;
     - `Game.display` staying inert until `start()`;
     - the effective project display settings.
   - **`test_export_presets`** gains the three web keys (AC2, AC4).
   - **`test_lint`'s `state_write`** covers `Game.display`.
   - Every other test passes unchanged.

   (D8)

7. **The docs match what was built.**
   - `docs/build.md`:
     - the presets;
     - the web smoke;
     - playing in `embed.html` on the laptop;
     - an engine upgrade checklist step that rechecks F1–F7.
   - `docs/architecture.md`, `component-inventory.md`, `source-tree-analysis.md`, `perf.md`.
   - `project-context.md`, `game-architecture.md`, and AR8 in `epics.md` (D9).

   (D9)

8. **Done means green and run.**
   - `cd game && ./run_tests.sh` gives `== ALL GREEN (22 tests)`.
   - `tools/export.sh` gives `== BUILD OK`, with `7 passed` from the web smoke: the 3 existing tests, 3 `Display scale` tests (one per DPR) and 1 `Web input` test.
   - Every D10 red check is run and recorded.
   - The report says "export green; needs a 5-minute look on the laptop" (Task 10).

## Tasks / Subtasks

- [x] **Task 1: Baseline (AC: 8).**
  - `cd game && ./run_tests.sh` should give `== ALL GREEN (21 tests)`, 1326 `ok` at `1afcc65` (the 1.13 review record). Record the number you get.
  - `tools/export.sh` should give `== BUILD OK`, about 81 s, `3 passed`.
  - The engine and browser facts this story relies on are already probed ("Verified facts").
- [x] **Task 2: `Display` and `Game` (AC: 1, 3), D2, D3, D4, D6.**
  - Write `scripts/core/display.gd`.
  - In `scripts/core/game.gd`:
    - add `var display := Display.new():` with the same assert setter as `clock`;
    - name it and `add_child` it in `_init()`;
    - call `display.start()` at the end of `boot()`, after `load_settings()`, so 7.2's display settings are already loaded when it runs;
    - update the header comment and `boot()`'s doc.
  - Add `display` to `test_lint`'s `state_write` instance-replacement pattern, `(settings|slot|dive|tuning|clock|store|display)`.
- [x] **Task 3: `tests/test_display.gd` (AC: 6), D8.**
- [x] **Task 4: The presets (AC: 2, 4), D1, D5.**
  - Add `html/canvas_resize_policy=2`, `html/focus_canvas_on_start=true` and D5's `html/head_include` to `[preset.2.options]` and `[preset.3.options]`.
  - Extend `test_export_presets` (D8).
  - Red-check it (D10 1, 5).
- [x] **Task 5: `embed.html` and its route (AC: 5), D7.** Write `tools/web_smoke/embed.html`, then add the one exact-path route to `serve.js`.
- [x] **Task 6: The smoke (AC: 5), D7.**
  - Add the `Display scale` and `Web input` blocks to `smoke.spec.js`.
  - Update its header comment: 1.14 is done, 1.33, 1.39 and 3.3 are still to come.
  - Run it alone against a fresh build (`docs/build.md`).
- [x] **Task 7: Check the desktop under Xvfb (AC: 3), D4.**
  - Run `godot --path game --rendering-driver opengl3 --audio-driver Dummy` under `xvfb-run -a -s '-screen 0 WxHx24'`:
    - at 1366×768: the window comes out 960×540 and centred, with the `window x2` line;
    - at 1920×1080: it stays 1440×810, with no window line;
    - with `--resolution 300x200`: it comes out 480×270;
    - with `--fullscreen`: no window line, and the scale line shows the screen's whole scale.
  - Record each line.
- [x] **Task 8: Docs (AC: 7), D9.**
- [x] **Task 9: Verify (AC: 8), D10.**
  - `./run_tests.sh` gives `== ALL GREEN (22 tests)` with no `ERROR:` lines.
  - `tools/export.sh` gives `== BUILD OK` with `7 passed`; record the end line.
  - Run every D10 red check in a detached worktree and record each failing line.
  - Stage the new files, each `.gd.uid` beside its `.gd`.
- [x] **Task 10: Report:** "export green; needs a 5-minute look on the laptop". The look:
  - **Desktop:**
    - the window opens at ×3, or ×2 on a small screen, centred;
    - drag-resizing steps through whole scales with black bars and stops at 480×270;
    - maximise, then `--fullscreen`: whole scale, letterboxed.
  - **Web,** through the tunnel:
    - `web_debug/index.html` with the console open: the `[ui] display:` line matches the window;
    - browser zoom (Ctrl + / Ctrl −) changes devicePixelRatio and the scale follows;
    - a window narrower than 480 CSS px at zoom 100% fits, with both gutters showing;
    - F11 still gives browser fullscreen (letterboxed). If it doesn't, the guard took it: say so.
  - **`embed.html?build=web`:**
    - arrows, Space, PageDown and F5 never scroll or reload the host page, also after clicking the game, then the header text, then the game again;
    - with the header clicked, arrows scroll the host. That is correct: the game doesn't have focus.

## Dev Notes

### What this story is (and isn't)

It is three small things:
- **a `Display` node** that knows the scale, fits sub-×1 windows and sizes the PC window;
- **a key guard** in the web shell;
- **two new smoke blocks** that measure what the engine really draws.

The probes below show the engine already does most of AR8: HiDPI canvas sizing, integer scaling from physical pixels, black letterboxing and nearest-neighbour blits. So the story mostly pins that behaviour, then fills the three gaps: the sub-×1 crop (F3), the oversized PC window (F8) and keys that escape when the canvas isn't focused (F7).

**Not in this story:**
- **The fullscreen toggle and the scale setting:** Options > Video, Story 7.2 (UX-DR78). `Display.start()` will read those settings; `window_scale_for`'s cap becomes the setting.
- **The "Small window. Try fullscreen." line:**
  - on the gate, Story 1.33 (UX-DR58), from `Game.display.scale < 2.0` (and `> 0.0`);
  - on the Pause tab below ×1, Story 1.34 (UX-DR147).
  This story only provides `scale` and `scale_changed`.
- **Auto-pause on focus loss:** the Pause story (1.34, FR32). The guard here only keeps keys off the page.
- **Gamepads in the browser:** Story 1.37.
- **The Steam Deck legibility check** at ×2: Story 1.18.
- **Measuring web performance at the ×2 embed:** Story 1.15, which runs `docs/perf.md` on a build that has this story in it.
- **A custom HTML shell:** not needed (D5).

### Current state (read before changing)

- **`project.godot` `[display]`:**
  - `viewport_width/height` 480×270, `window_width/height_override` 1440×810, `stretch/mode="viewport"`, `stretch/scale_mode="integer"`.
  - `stretch/aspect` and `dpi/allow_hidpi` are at their defaults (`keep`, `true`), so they are not in the file.
  - `[rendering]`: `default_texture_filter=0` (nearest) and `snap_2d_transforms_to_pixel=true`.
  - **Don't edit it** (D3).
- **No script touches the window or the stretch.**
  - `perf_run.gd:204` only records `get_window().size` in its summary.
  - `gutters.gd:24` and `camera_rig.gd:35,127` read `get_viewport_rect().size`, which stays 480×270 in viewport stretch (F9 shows it headless; check that it holds at the fit too).
  - `Gutters._ready()` sets the clear colour to `#07060b`. The letterbox is drawn black regardless (F4).
- **`scripts/core/game.gd`:**
  - `_init()` adds `clock` (`clock.name = "Clock"; add_child(clock)`) and connects settings.
  - Each session-long ref has a setter that asserts. Copy that for `display`.
  - `boot()` runs once, from the entry scene (`World._ready()`, only when World is the current scene), and calls `load_settings()`.
  - `test_state` boots on a temp folder as its last case. That runs headless, so `display.start()` must stay inert there (D2).
- **`scripts/core/log.gd`:**
  - the categories are fixed (AR55), and `UI` is one of them;
  - `Log.info()` prints in every debug build regardless of category, and is silent in release.
- **`game/export_presets.cfg`:**
  - `[preset.2]` `Web` and `[preset.3]` `Web debug` each have an `.options` section holding only `variant/extensions_support=false`, `variant/thread_support=false` and `progressive_web_app/enabled=false`;
  - every other web option is at its default: `canvasResizePolicy` 2 and `focusCanvas` true, as the exported `index.html` config shows (F10).
- **`tests/test_export_presets.gd`:**
  - `WEB_FALSE` lists the three keys that must be "written explicitly";
  - `_test_preset()` (`:125-146`) checks them for `platform == "Web"`;
  - extend it in the same style.
- **`tools/web_smoke/smoke.spec.js`:**
  - the `seen` fixture;
  - `boot(page, seen, url)`, which returns `left` (one 60 s deadline per page);
  - `expectClean`, `expectMarker`, `texts`;
  - the describes `Web debug` (2 tests) and `Web (release)` (1 test);
  - the header comment already names "the DPR scale and keys that must not scroll (1.14)".
  - `playwright.config.js`: `workers: 1`, `forbidOnly`, a 150 s per-test timeout, the default viewport (1280×720, DPR 1) and Chromium headless shell only. No change needed.
- **`tools/web_smoke/serve.js`:**
  - serves `BUILD_DIR` only and ignores the query;
  - redirects a folder URL without its slash with a 301;
  - realpath-checks every file against `BUILD_DIR`, and pipes it with `stream.pipeline`;
  - `PORT` defaults to 8061 (the build's), and 8060 is the laptop tunnel's.
- **`tools/export.sh` step `web_smoke`:**
  - runs the whole spec under `timeout -k 5 600`;
  - fails on any skipped, flaky, did-not-run or interrupted line;
  - needs an `N passed` line, which it prints and puts in the summary.
  - **It needs no change:** the new tests are just more tests.
- **Baseline:** 21 tests, 1326 `ok` (1.13 review). `export.sh` BUILD OK in about 81 s; the smoke is `3 passed` in about 21 s.

### Decisions

**D1: No JavaScriptBridge, because the engine already works in physical pixels.**
- **Why:** AR8 and the architecture (Engine-Provided Architecture, the tree comment for `display.gd`) say "DPR-based integer scale via JavaScriptBridge". F1 shows the engine already does it:
  - the canvas backing store is CSS size × devicePixelRatio, and that is the window size Godot sees;
  - the integer stretch then picks the scale from physical pixels (F2).
  Reading devicePixelRatio ourselves would duplicate the engine. It would also add a JavaScript round trip and a second source of truth.
- **So `display.gd` has no JavaScriptBridge.** Its one `OS.has_feature("web")` branch only skips the PC window step. `display.gd` is one of the five places the architecture allows that branch.
- **What it depends on, pinned:**
  - `display/window/dpi/allow_hidpi`: the editor never writes a default into `project.godot`, so `test_display` reads the effective value through `ProjectSettings.get_setting()`, not the file;
  - `html/canvas_resize_policy=2` and `html/focus_canvas_on_start=true`, written explicitly in both web presets, so a laptop re-save that changes them fails `test_export_presets`.
- **Docs:** the architecture's JavaScriptBridge mentions and AR8 get "as built (Story 1.14)" wording (D9).

**D2: `Display` is a child node of `Game`, started by `boot()`, and inert under headless.**
- **Why a node:** it needs the tree for `get_window()` and `size_changed`.
- **Why in `Game`:** it must exist before any screen. The gate (1.33) may show before World does. A third autoload is an architecture change (AR9), and `Clock` already sets the "Node child of `Game`" pattern.
- **`game.gd`:**
  - `var display := Display.new():` with the assert setter;
  - `display.name = "Display"; add_child(display)` in `_init()`;
  - `display.start()` at the end of `boot()`.
  - `reset_for_tests()` doesn't change: each test file runs in its own process, and `test_display` restores the root window itself.
- **Why `start()` is inert under headless:**
  - F9: there `get_window().size` reports 64×64 and the screen is empty, so applying would pick a 0.133 fit and log it;
  - `boot()` runs headless in `test_state` and in `export.sh`'s Linux release boot, and both must stay silent.
  So `start()` returns at once when `DisplayServer.get_name() == "headless"`.
- **`scale` starts at `0.0`**, meaning "no window". 1.33 and 1.34 treat 0 as "no suggestion".
- **Public surface:**
  - `scale: float` (read it, never set it from outside);
  - `signal scale_changed(scale: float)`;
  - `start()`, `apply(window: Vector2i)`;
  - the statics `scale_for()`, `stretch_for()`, `window_scale_for()`;
  - `const BASE := Vector2i(480, 270)`, `const DEFAULT_WINDOW_SCALE := 3`.
  A comment says `BASE` must equal `project.godot`'s viewport size, and `test_display` checks it.
- **Lint:**
  - `core_layer`: `display.gd` names no class from world/, ui/ or the layers above them;
  - `state_write`: add `display` to the first, instance-replacement pattern only. It holds no rule state, so the field patterns don't apply.

**D3: The rule. The integer case stays the engine's.**
- **The engine's half:**
  - `scale_mode="integer"` with `aspect="keep"` already floors `min(w/480, h/270)`, centres the view and paints the bars black (F2, F4);
  - `Display.scale_for()` mirrors it so the game knows the number for its log, the gate and the Pause tab;
  - the smoke's screenshots check that the game's number and the engine's output agree.
- **Our half, the fit:** below 480×270 on either side the engine stays at ×1 and crops the right and bottom (F3). UX-DR147 wants a fit, so `apply()` sets `content_scale_stretch` to `FRACTIONAL`. The fit is then `min(w/480, h/270)`, letterboxed and nearest-neighbour (F5).
- **No feedback loop:**
  - switching the stretch doesn't change the window size;
  - `apply()` compares the new size and scale with the last ones, so a `size_changed` the engine re-emits after a stretch change does nothing (check whether it re-emits; it mustn't matter).
- **No cap:**
  - 2560×1440 → ×5, 3840×2160 → ×8;
  - UX's "×2, ×3, ×4" are examples, and every whole scale keeps pixels square;
  - 7.2's Scale setting caps the *window*, not this rule.
- **Who reaches the fit:** PC never does, because of the minimum size. Web can, and so can the editor's embedded Game view.
- **The `test_display` boundaries** (`window → scale, stretch`):

  | Window | Scale | Stretch |
  |---|---|---|
  | 480×270 | 1 | integer |
  | 479×270 | 0.99792 | fractional |
  | 480×269 | 0.99630 | fractional |
  | 959×540 | 1 | integer |
  | 960×540 | 2 | integer |
  | 960×539 | 1 | integer |
  | 1439×810 | 2 | integer |
  | 1440×810 | 3 | integer |
  | 1440×809 | 2 | integer |
  | 1500×900 | 3 | integer |
  | 1920×1080 | 4 | integer |
  | 2560×1440 | 5 | integer |
  | 3840×2160 | 8 | integer |
  | 2000×540 | 2 | integer (wide) |
  | 640×360 | 1 | integer |
  | 400×225 | 0.83333 | fractional |
  | 320×180 | 0.66667 | fractional |

  Compare floats with `is_equal_approx` or to 1e-4.

**D4: The PC window.**
- **The ×3 default stays the project's window override** (1440×810), which the engine opens before any script runs. Moving it into code would open the window at 480×270 and then jump.
- **Why a check is needed:** F8 shows Godot doesn't clamp the window to the screen. On a 1366×768 screen it opened at 1440×810, partly off screen.
- **The check in `start()`, on PC only:**
  ```gdscript
  var win := get_window()
  win.min_size = BASE
  if win.mode == Window.MODE_WINDOWED:
      var usable := DisplayServer.screen_get_usable_rect(win.current_screen).size
      var deco := win.get_size_with_decorations() - win.size
      var s := window_scale_for(usable, deco)
      # Only shrink a window that doesn't fit: a --resolution that fits (1.18's 960x540) is kept.
      if win.size.x > BASE.x * s or win.size.y > BASE.y * s:
          win.size = BASE * s
          win.move_to_center()
          Log.info(Log.UI, "display: window x%d %dx%d (screen %dx%d)" % [s, win.size.x, win.size.y, usable.x, usable.y])
  ```
  This is a sketch. Keep its order: set the minimum size first, then the window, then apply the scale.
- **`window_scale_for(usable, deco)`:**
  - returns the largest `s` in `1..DEFAULT_WINDOW_SCALE` with `480·s + deco.x ≤ usable.x` and `270·s + deco.y ≤ usable.y`, else 1;
  - an empty usable rect (a display server that can't tell) returns `DEFAULT_WINDOW_SCALE`, which leaves the window alone.
  - `test_display` table:

    | Usable | Decorations | Scale |
    |---|---|---|
    | 1920×1040 | 0×30 | 3 |
    | 1366×728 | 0×30 | 2 |
    | 1440×900 | 2×32 | 2 (1442 > 1440) |
    | 1600×860 | 0×30 | 3 (840 ≤ 860) |
    | 800×500 | 0×30 | 1 |
    | 400×200 | 0×0 | 1 |
    | 0×0 | 0×0 | 3 |
- **Skipped:**
  - **web** (`OS.has_feature("web")`): the page sizes the canvas;
  - **embedded in the editor** (`Engine.is_embedded_in_editor()`): the editor's Game view owns the size, and sonlm runs builds in the laptop editor;
  - **a window that isn't windowed** (`--fullscreen`, `--maximized`, or exclusive fullscreen): the window step is skipped, though `min_size` is still set;
  - **headless** (D2).
- **`min_size = BASE`** on every PC window except an embedded one. F8 shows it clamps a smaller size request. It is in physical pixels, like the window.
- **Not here:**
  - a scale setting or fullscreen toggle (7.2);
  - remembering the window's size or position;
  - re-fitting after a move to another screen: the size is kept, and the integer rule still applies.

**D5: The key guard is in `html/head_include`, the same text in both web presets.**
- **Why there:**
  - not a custom HTML shell: that would fork Godot's `godot.html` and need re-merging on every engine upgrade;
  - not `JavaScriptBridge.eval` from GDScript: that would run only once the engine has booted, so it would miss the loading screen, and it would put a web branch in game code.
  - The shell places `$GODOT_HEAD_INCLUDE` at the end of `<head>` (F10), before the canvas exists. So the listener sits on `window`, and the canvas is looked up when a key arrives.
- **The value**, on one line so the cfg holds a plain string. Use single quotes in the JavaScript, so the cfg value needs no `\"` escapes:
  ```ini
  html/head_include="<script>/* Story 1.14 (UX-DR122): arrows, Space, page keys and F-keys never scroll or act on the page, even when the canvas has lost focus. Godot's own listener sits on the canvas. */ addEventListener('keydown', function (e) { if (/^(Arrow(Up|Down|Left|Right)|Space|Page(Up|Down)|Home|End|F([1-9]|1[0-2]))$/.test(e.code)) { e.preventDefault(); var c = document.getElementById('canvas'); if (c && document.activeElement !== c) c.focus(); } }, true);</script>"
  ```
  Check that the exported `index.html` holds it verbatim. Check also that `ConfigFile` reads back the `\d`-free regex unchanged: it has no backslashes on purpose.
- **How it behaves:**
  - It runs in the capture phase on `window`, so it fires before Godot's canvas listener.
  - It doesn't stop propagation, so the game still gets every key.
  - On the canvas it repeats Godot's own `preventDefault()`, which is harmless. Off the canvas it is the only thing that stops the scroll.
  - Refocusing is safe: the game's document holds only the canvas and the status overlay, with no text fields, and the gate (1.33) is a Godot screen, not DOM.
- **Only `keydown`:** scrolling, find (F3), reload (F5) and caret browsing (F7) all fire on keydown.
- **Not guarded:** the wheel needs nothing, since Godot already prevents it over the canvas (F7). Neither does a click on the host page outside the iframe: focus has then left the game, and arrows rightly scroll the host. Clicking the game again refocuses the canvas (F6).
- **F11 and F12** are in the list, as they are for Godot's own canvas listener. Browsers keep some shortcuts reserved whatever a page asks. The laptop look records whether F11 fullscreen still works.
- **`test_export_presets`** checks that the value is identical in both web presets and that it contains `addEventListener('keydown'`, `preventDefault()`, `focus()` and each guarded code group. The smoke is the real test (AC5).

**D6: The log lines.**
- **Category:** `Log.UI`. AR55's list is fixed, there is no `DISPLAY`, and the scale is presentation.
- **`info`, not `debug`:** these are milestones. There is one at start and one per change of whole scale or fit: a drag-resize logs once per step, not once per pixel. They are silent in release.
- **Exact formats:**
  - `display: scale %d in %dx%d` for the integer case;
  - `display: scale %.3f (fit) in %dx%d` for the fit;
  - `display: window x%d %dx%d (screen %dx%d)` for the PC window, only when it is resized.
- The smoke reads only the scale token (`/^\[ui\] display: scale (\S+)/`, newest line). A whole-scale step with no change, like 960×540 → 1000×600 at DPR 1, prints nothing new, and the newest line still names `2`.

**D7: The smoke.**
- **`embed.html`:**
  - Static, with no dependencies.
  - Its script reads `new URLSearchParams(location.search).get('build')`; only `web` and `web_debug` are accepted, anything else falls back to `web`. It then sets the iframe's `src` to `/<build>/index.html`.
  - Styles: `body { margin: 0 }`, a 100 px header with plain text (the laptop look clicks it), the iframe at `width=960 height=540 style="border:0;display:block"`, then a 3000 px block.
  - Title: `Embed test (itch-style)`.
- **`serve.js`:** before the `BUILD_DIR` lookup, an exact `url.pathname === '/embed.html'` serves `path.join(__dirname, 'embed.html')` as `text/html; charset=utf-8`, through the same `pipeline` path and `Cache-Control: no-store`. Nothing else outside `BUILD_DIR` becomes reachable, and the 1.13 traversal and symlink behaviour must stay as it is (red check D10 6).
- **`Display scale`:**
  - one `test.describe` per DPR row, each with `test.use({ viewport: { width, height }, deviceScaleFactor })`, and one test that boots `/web_debug/index.html` with the existing `boot()`;
  - it waits for the first `[ui] display:` line, then walks the steps with `page.setViewportSize()`.
  - **Expected values are written in the table,** not computed by a JavaScript copy of the rule. The rule has one home, `display.gd`, and the test is the spec.
  - **Measuring a step:**
    - `const png = await page.screenshot()`: device pixels by default (`scale: 'device'`), so a 1.5 DPR 960×540 page gives a 1440×810 image;
    - decode it in the page:
      ```js
      page.evaluate(async (b64) => {
        const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
        const bmp = await createImageBitmap(new Blob([bytes], { type: 'image/png' }));
        const c = new OffscreenCanvas(bmp.width, bmp.height).getContext('2d');
        c.drawImage(bmp, 0, 0);
        const d = c.getImageData(0, 0, bmp.width, bmp.height).data;
        // ...bbox of pixels with any channel > 0, and the RGB at its left and right columns at mid-height...
      }, png.toString('base64'))
      ```
    - the browser's own PNG decoder means no npm dependency;
    - letterbox pixels are exactly `(0,0,0)` (F4).
  - **Polling:** wrap each step's measurement in `expect.poll(..., { timeout: 10_000 })`, since a resize lands a frame or two later. Assert width, height, centring and the matching edge colours.
  - **The scale line:** the newest display line's scale token equals the expected `2`, `3`, `4`, `1` or `0.833`.
  - **`page.setViewportSize()` reaches the engine** (F11): Godot resizes on `window` `resize`. If a step still never lands, fall back to a fresh page per size and say so.
  - **Note for 1.25:** the edge-colour sample assumes the outermost gutter columns match at mid-height. If 1.25's HUD puts different pixels there, move the sample row.
- **`Web input`:**
  - **Boot in the frame.** A small `bootFrame(page, seen, path)`:
    - `page.goto('/embed.html?build=web')` gives status 200;
    - `const frame = page.frames().find((f) => new URL(f.url()).pathname === '/web/index.html')`, polled until it exists;
    - then the same `#status` race as `boot()` in that frame, and the banner from `seen`.
    - The page's `console` event carries the iframe's messages (F11), so `seen` and `expectClean` work unchanged.
  - `const KEYS = ['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space', 'PageUp', 'PageDown', 'Home', 'End', 'F1', …, 'F10']`.
  - **Focused phase:**
    - the frame's `document.activeElement` is the canvas (`focusCanvas`, F6);
    - install a bubble-phase `keydown` recorder on the frame's `window` (`code:defaultPrevented`);
    - `page.keyboard.press()` each key;
    - expect every one prevented and the host's `window.scrollY` at 0.
  - **Blurred phase:**
    - `frame.evaluate(() => document.activeElement.blur())`, then expect `document.activeElement === document.body`;
    - press `ArrowDown`: the host's `scrollY` is 0 and the canvas is active again;
    - press the rest: `scrollY` stays 0, and every key is prevented.
    - Without the guard this phase scrolled the host by 619 px (F7), so it can fail.
  - F11 and F12 are never pressed: they are browser-reserved, and the headless shell isn't the real browser for them.
  - It ends with `expectClean`.
- **Unchanged:** the three existing tests, their helpers, `ALLOWED_CONSOLE_ERRORS` (still empty) and `playwright.config.js`.
- **Time:** four more boots, about 30–40 s. `export.sh`'s 600 s cap is far off.

**D8: The tests.**
- **New `tests/test_display.gd`** (extends `Node`, `run()`, `ok`/`FAIL` lines, `PASS`/`FAILED`, like the others):
  - D3's table through `scale_for` and `stretch_for`;
  - a zero-area window: not passed, because it asserts. Note that in a comment;
  - D4's table through `window_scale_for`;
  - `Display.BASE` equals `ProjectSettings` `display/window/size/viewport_width/height`, and `DEFAULT_WINDOW_SCALE * BASE` equals the window override, 1440×810;
  - the effective settings, through `ProjectSettings.get_setting()`: `stretch/mode == "viewport"`, `stretch/scale_mode == "integer"`, `stretch/aspect == "keep"`, `dpi/allow_hidpi == true`, `rendering/textures/canvas_textures/default_texture_filter == 0`, `rendering/2d/snap/snap_2d_transforms_to_pixel == true`;
  - **inert before start:**
    - `Game.display` exists, is named `Display` and is a child of `Game`;
    - `Game.display.scale == 0.0`;
    - `get_window().size_changed` has no connection to it;
    - `get_window().content_scale_stretch` is `INTEGER`;
  - **`apply()`,** on `Game.display`, counting `scale_changed` with a method:
    - `apply(Vector2i(400, 225))` sets `FRACTIONAL`, scale ≈ 0.8333, one emit;
    - the same again: no emit;
    - `apply(Vector2i(960, 540))` sets `INTEGER`, scale 2, one emit;
    - `apply(Vector2i(1000, 600))`: scale still 2, no emit;
    - `apply(Vector2i(1440, 810))`: scale 3, one emit;
    - at the end, restore `INTEGER` and disconnect;
  - **`start()` under headless:** scale stays 0.0 and `size_changed` stays unconnected. The runner is headless, so this is the real case.
- **`test_export_presets`:**
  - for both web presets: `html/canvas_resize_policy == 2` and `html/focus_canvas_on_start == true`, each written explicitly;
  - `html/head_include` is non-empty, identical in `Web` and `Web debug`, and contains `addEventListener('keydown'`, `preventDefault()`, `.focus()`, `Arrow(Up|Down|Left|Right)`, `Space`, `Page(Up|Down)`, `Home`, `End` and `F([1-9]|1[0-2])`.
  - Keep the "written explicitly" message style. The check count grows from 60; record the new count.
- **`test_lint`:** add `display` to `state_write`'s first pattern. Its self-test samples, if there are any for that pattern, gain `Game.display = x`.
- **No `smoke_display.gd`:** the runner is headless, so the real window is the web smoke's job (and Task 7's on the desktop).

**D9: The docs.** See "Docs lines to update" below.

**D10: Red checks.** Each runs in a detached git worktree in the scratchpad that carries the uncommitted work, as 1.13 D14 did:
- `git diff HEAD --binary | git apply`;
- the untracked files copied in;
- `npm ci` in `tools/web_smoke`;
- one at a time, since they share port 8061.

Record each failing line:
1. **Delete `html/head_include` from `Web` only.**
   - `test_export_presets` fails: missing, and the presets differ.
   - `export.sh` fails at `web_smoke`: the blurred phase scrolls the host (F7 probed 619 px).
2. **Make `apply()` always set `INTEGER`.**
   - `test_display` fails.
   - The smoke's DPR 1 test fails at 400×225: the edge colours differ, because the view is cropped (F3).
3. **Make `scale_for` round instead of floor.** `test_display` fails (1439×810 gives 3).
4. **Make `start()` run under headless** (drop the guard). `test_state` or `test_display` prints a `[ui] display: scale 0.133 (fit) in 64x64` line, and `test_display`'s inert check fails. Record what fails.
5. **Set `html/canvas_resize_policy=0`** in both web presets. `test_export_presets` fails.
6. **`serve.js`:** `/embed.html` gives 200. `/embed.html/../web/index.html`, `/%2e%2e/tools/web_smoke/serve.js` and a symlink in `BUILD_DIR` still give 404 as in 1.13. `/web_debug` still gives a 301.

### Verified facts (probes 2026-11-19, Godot 4.7.2.stable.official.ed1daf0bf on the server; the web build `builds/20261119-1afcc65/web_debug` in Playwright 1.65.1's headless Chromium shell, SwiftShader)

- **F1: The web canvas is in physical pixels already.**
  - Backing size by CSS viewport and DPR:

    | CSS viewport | DPR | Backing size |
    |---|---|---|
    | 960×540 | 1 | 960×540 |
    | 960×540 | 1.5 | 1440×810 |
    | 960×540 | 2 | 1920×1080 |
    | 1000×600 | 1 | 1000×600 |
    | 400×225 | 1 | 400×225 |
    | 320×180 | 2 | 640×360 |

    The canvas's `style.width/height` stays the CSS size.
  - The exported config has `canvasResizePolicy: 2` and `focusCanvas: true` (the defaults), and `allow_hidpi` is true by default.
- **F2: The integer stretch works on those pixels.**
  - 960×540 at DPR 1.5 fills the 1440×810 screenshot, so it is ×3;
  - 1000×600 at DPR 1 draws its non-black box at (20, 30)–(980, 570): ×2, centred;
  - 640×360 (320×180 at DPR 2) draws ×1 with black bars of 80 and 45 px.
- **F3: Below 480×270 the integer stretch stays at ×1 and crops.** At 400×225:
  - the view is anchored top-left;
  - the left gutter band is 64 px wide, its ×1 width (60 + 4 px of clear colour);
  - the right gutter doesn't show at all.
- **F4: The letterbox is pure black.** Pixels outside the view are `(0,0,0)`, and the gutter and clear colour `#07060b` = `(7,6,11)` never reach them.
- **F5: The fractional stretch downscales with nearest-neighbour.**
  - Under Xvfb, X11, `--rendering-driver opengl3`, a 480×270 one-pixel checkerboard of two colours in a 400×225 window with `CONTENT_SCALE_STRETCH_FRACTIONAL` shows exactly those 2 colours, and `get_viewport().get_final_transform()` is ×0.8333. In integer mode at 1000×600 it shows 3 colours, black bars included, at ×2.
  - The web build uses the same GLES3 renderer; the smoke's 400×225 step confirms it there.
- **F6: Keys on the canvas.**
  - The canvas has `tabIndex` 0 and is focused at boot.
  - Every key pressed on it reached `window` with `defaultPrevented`: ArrowDown, ArrowUp, Space, PageDown, F1, F3, F5, F7, Tab, Backquote.
  - With the body focused instead (after `blur()`), ArrowDown was not prevented.
  - A click on the canvas refocused it.
- **F7: An itch-style embed** (a tall host page with the game in a 960×540 iframe):
  - with the canvas focused, the host never scrolled;
  - the wheel over the game didn't scroll the host;
  - **with the canvas blurred inside the frame** (focus on the frame's body), ArrowDown ×2, Space and PageDown scrolled the host to `scrollY 619`.
- **F8: The desktop window** (Xvfb, X11):
  - on a 1366×768 screen the window opens at 1440×810, larger than the screen, not clamped;
  - `screen_get_usable_rect()` gives 1366×768 there, and 1920×1080 on a 1920×1080 screen;
  - setting `min_size = Vector2i(480, 270)`, then `size = Vector2i(300, 200)`, gives 480×270;
  - `get_viewport().get_final_transform()` reports the applied scale (×3 at 1440×810, ×1 at 480×270).
- **F9: Headless:**
  - `DisplayServer.get_name()` is `headless`, `window_get_size()` is (0, 0), `get_window().size` is (64, 64), and the usable rect is empty;
  - setting `min_size`, `size` and `content_scale_stretch` prints no error;
  - the viewport's visible rect is 480×270.
  - The API names exist on 4.7.2 (checked with `ClassDB`):
    - `Window`: `content_scale_stretch` (`CONTENT_SCALE_STRETCH_FRACTIONAL` = 0, `INTEGER` = 1), `min_size`, `mode` (`MODE_WINDOWED` 0, `MAXIMIZED` 2, `FULLSCREEN` 3, `EXCLUSIVE_FULLSCREEN` 4), `current_screen`, `size_changed`, `get_size_with_decorations()`, `move_to_center()`;
    - `Viewport.get_final_transform()`;
    - `DisplayServer.screen_get_usable_rect()`, `DisplayServer.get_name()`;
    - `Engine.is_embedded_in_editor()`, which is false outside the editor.
  - The project's stretch reads back as mode 2 (viewport), aspect 1 (keep) and size 480×270.
- **F10: The web export's options in 4.7.2** are `html/canvas_resize_policy`, `html/custom_html_shell`, `html/experimental_virtual_keyboard`, `html/export_icon`, `html/focus_canvas_on_start` and `html/head_include`.
  - The template's `godot.html` puts `$GODOT_HEAD_INCLUDE` last in `<head>`, after its `<style>` and before `<body>` and the canvas.
  - The `body` has `overflow: hidden` and a black background.
- **F11: Playwright behaviour the smoke relies on:**
  - The page's `console` event carries the iframe's messages: the release banner arrived through it, from `/web/index.js`, about 0.8 s after `goto` of a host page.
  - `page.frames()` finds the game's frame by pathname.
  - In a DPR 1.5 context, `page.setViewportSize({1000, 600})` keeps `devicePixelRatio` 1.5, and the canvas backing follows to 1500×900.
  - `page.screenshot()` returns a 1500×900 PNG, in device pixels.
  - `ClassDB.class_exists("Display")` is false, and no global class uses the name.

### Docs lines to update (from the sweep; recheck each before editing)

- **`docs/build.md`:**
  - **The presets:** add the three web keys and why each is pinned (D1, D5).
  - **The web smoke:** add the `Display scale` and `Web input` blocks and how they measure.
  - **Playing builds on the laptop:** add `http://localhost:8060/embed.html?build=web` (or `web_debug`) for the key look.
  - **`serve.js`:** say it serves `/embed.html`.
  - **The engine upgrade checklist:** add "recheck F1–F7 against the new templates (canvas backing = CSS × DPR, the integer stretch on physical pixels, the sub-×1 crop or fit, the black letterbox, the nearest blit, the canvas key `preventDefault`, `$GODOT_HEAD_INCLUDE` still in `<head>`)". The web smoke covers most of it.
- **`docs/architecture.md`:**
  - `:26` (Resolution): add `Game.display`, the sub-×1 fit, the PC minimum and the ×3 fit;
  - `:260`: move "DPR scaling and web input (1.14)" from the gaps to the done column.
- **`docs/component-inventory.md`:**
  - Core table: a new `display.gd` row, and `game.gd`'s list gains `display`;
  - the test table gains `test_display` and the new `test_export_presets` count;
  - Build Tools gains `embed.html` and the two smoke blocks.
- **`docs/source-tree-analysis.md`:**
  - add `core/display.gd`, `tests/test_display.gd` and `tools/web_smoke/embed.html`;
  - `game.gd`'s comment lists `display`.
- **`docs/perf.md:39`:** drop "(once Story 1.14 has landed too)".
- **`docs/development-guide.md` and `docs/index.md`:** recheck for "1.14", "DPR" or test counts.
- **`_bmad-output/project-context.md`:**
  - **Current State:** add a Story 1.14 sentence: `Game.display` (`core/display.gd`) holds the scale rule; the integer stretch stays the engine's (physical pixels on web through Godot's HiDPI canvas, no JavaScriptBridge); the sub-×1 fractional nearest fit; PC ×3 or the largest fit with a 480×270 minimum; the `html/head_include` key guard in both web presets; `test_display`; the smoke's `Display scale` and `Web input` blocks with `embed.html`.
  - **Platform & Build Rules:** add one rule. Only `Display` touches the stretch, the window size or the minimum size. The web key guard lives in the presets, and a new web export option goes in the presets **and** `test_export_presets`.
  - Update the Last Updated line.
- **`_bmad-output/game-architecture.md`:**
  - `:134`: the Display line, as built;
  - `:230`: "the DPR scale (1.14)" has joined the smoke;
  - `:241` (Engine-Provided Architecture → Pixel display): "DPR-based scale choice and sub-×1 fit are ours (JavaScriptBridge)" becomes "as built (1.14): the engine's HiDPI canvas gives physical pixels; the sub-×1 fit, the PC window and the web key guard are ours";
  - the tree comments at `:708` (`game.gd`: add `display`) and `:711` (`display.gd`: drop "JavaScriptBridge");
  - the table row at `:839`;
  - `:592`'s platform-branch row stays.
- **`_bmad-output/planning-artifacts/epics.md` AR8 (`:208`):** add an "as built (Story 1.14)" clause, as 1.13 did for AR51: the engine's HiDPI canvas gives the physical-pixel scale with no JavaScriptBridge; the fit, the PC window and the key guard are `display.gd` and the presets.
- **`tools/web_smoke/smoke.spec.js`'s header comment** (Task 6).

### Project Structure Notes

- **New:**
  - `game/scripts/core/display.gd` and its `.gd.uid`;
  - `game/tests/test_display.gd` and its `.gd.uid`;
  - `tools/web_smoke/embed.html`.
- **Modified:**
  - `game/scripts/core/game.gd`;
  - `game/export_presets.cfg` (both web `.options` sections only);
  - `game/tests/test_export_presets.gd`, `game/tests/test_lint.gd`;
  - `tools/web_smoke/serve.js`, `tools/web_smoke/smoke.spec.js`;
  - the docs in D9.
- **Not touched:**
  - `game/project.godot` (D3);
  - `world.gd`, `gutters.gd`, `camera_rig.gd`, `dev_tools.gd`;
  - `tools/export.sh`, `playwright.config.js`, `package.json` and the lock file (no new dependency).
- **Layering:**
  - `display.gd` is `core/`: it may use `Log` and engine classes, but no class from world/, ui/ or anything above them (`core_layer` lint);
  - it is not dev, so it ships in release builds, and the release PCK checks still pass unchanged;
  - it has no `class_name` clash: `Display` is unused on 4.7.2 (F11). Godot has `DisplayServer`, not `Display`.
- **`.uid` files:** generate them with `godot --headless --path game --import` and commit them beside their scripts.

### Project Context Rules (that apply here)

- **The platform branch** `OS.has_feature("web")` is allowed only in boot, `core/display.gd`, the storage check, the quit button and the audio gate. `display.gd` uses it once, to skip the PC window step.
- **Autoloads are `Game` and `Audio` only.** `Display` is a child of `Game`, not an autoload.
- **`Game` keeps the same instances all session.** `display` gets the assert setter, and the lint pattern covers it.
- **No addons, no `.tres`, no new npm dependency.** The PNG is decoded by the browser.
- **No bare `print()`.** Use `Log.info(Log.UI, …)`. No logging in hot paths: the display lines fire only on a change.
- **Input goes through actions only, with no raw keycodes** in game code. The JavaScript guard is web shell text, not game code, so the `keycode` lint has nothing to say. Nothing in GDScript reads keys here.
- **Tests:**
  - `./run_tests.sh` must give `== ALL GREEN`;
  - a new test's name must match `tests/test_*.gd`;
  - output is `ok` / `FAIL` lines plus `PASS` / `FAILED`;
  - validators are pure, and a test that touches `Game` ends with `Game.reset_for_tests()` and leaves the root window as it found it.
- **Headless tests can't judge the look.** Report "export green; needs a 5-minute look on the laptop", never "scales correctly in the browser".
- **Builds come from the server.** A new web export option goes in the presets **and** `test_export_presets`. Every claim about engine behaviour is probed on 4.7.2 before you rely on it.

### Previous story intelligence (1.13 and its review)

- **The smoke's conventions:**
  - the `seen` fixture collects from before `goto`, and dumps the whole console on a failure;
  - one `BOOT_MS` deadline per page, which `boot()` returns as `left`;
  - poll over collected messages, never `waitForEvent` after `goto`;
  - check that `response.status()` is 200;
  - `ALLOWED_CONSOLE_ERRORS` stays empty;
  - `forbidOnly`;
  - `export.sh` fails on a skipped, flaky, did-not-run or interrupted test, and needs `N passed`.
  Follow every one in the new blocks.
- **The review's main lesson:** a check must be able to fail. 1.13's first `expectMarker` polled for "1" and passed the moment the first marker arrived. Here:
  - the screenshot measure is designed to fail on the crop (F3) and on a wrong scale;
  - the blurred-key phase fails without the guard (F7);
  - D10 proves both.
- **Probe engine claims before relying on them** (sonlm's standing rule from the 1.12 review). F1–F11 are probed. Probe anything new before you depend on it, in particular:
  - whether a stretch change re-emits `size_changed`;
  - whether the viewport rect stays 480×270 at the fit.
- **Explicit keys in `export_presets.cfg`:** 1.13 D2 found that a missing or empty `.options` section prints an engine `ERROR:` and still exits 0. Adding keys to the existing sections is safe. A laptop editor re-save rewrites the file with every key, which is fine as long as `test_export_presets` passes and the diff holds no machine path.
- **Bash and red checks:** 1.13 D14's worktree method works. Run one red check at a time, since they share port 8061.
- **1.12:** `perf_run` records `get_window().size`, which this story leaves alone. `docs/perf.md`'s web runs wait on this story.
- **1.11:** DevTools reads the URL query through `JavaScriptBridge.eval`, a stub off the web, with no `has_feature` branch. `Display` needs neither.

### Git intelligence

Recent commits are all Story 1.13, in the house pattern of one feature commit, then docs, then review fixes, then the review record:
- `1afcc65` docs: review record;
- `e3f8c74` fix: review fixes (`export.sh`, `pck_list.gd`, `serve.js`, `smoke.spec.js`, `test_export_presets`);
- `8ab866e` docs: export pipeline;
- `ed19526` feat: presets, `export.sh`, web smoke;
- `372cc32` docs: story file.

This story's work touches those same files: `serve.js`, `smoke.spec.js`, `test_export_presets.gd` and `export_presets.cfg`. Read the current versions first; the review rewrote parts of each.

### Latest tech notes

- **Godot 4.7.2 is frozen for M2** (project-context).
  - Context7 needs `/mcp` authentication; every API used here was checked on the server's 4.7.2 instead (F9).
  - `Window.content_scale_stretch` arrived in 4.2; `Engine.is_embedded_in_editor()` and the editor's embedded Game view in 4.4.
- **Playwright 1.65.1 is pinned exactly.** What this story uses, from its documented API:
  - `test.use({ viewport, deviceScaleFactor })` per describe;
  - `page.setViewportSize()`, which keeps the context's `deviceScaleFactor`;
  - `page.screenshot()`, whose `scale` defaults to `'device'`;
  - `page.frames()`, `frame.evaluate()`, `page.keyboard.press()`, which goes to the focused frame.
  The F1–F7 and F11 probes used exactly these calls.
- **The browser:** `createImageBitmap(Blob)` and `OffscreenCanvas` 2D `getImageData` are standard in Chromium and need no flags.

### Cross-story context (Epic 1 and beyond)

- **1.15 (CP1 gate):** runs the web perf at the ×2 embed on a build that has this story, and reads `docs/perf.md`.
- **1.18 (Deck-size check):** ×2 = 960×540. Use `--resolution 960x540` on the desktop: above `min_size`, so the integer rule gives ×2.
- **1.25 (gutter HUD):** may need the smoke's edge-colour sample row moved (D7).
- **1.33 (the gate):**
  - shows "Small window. Try fullscreen." when `0.0 < Game.display.scale < 2.0`, and connects `scale_changed` so it updates when the window does;
  - its "first click or key gives focus" is helped by the guard's refocus;
  - the smoke must then pass the gate, and `?room=` must still boot straight in (ledger, 1.33).
- **1.34 (Pause tab):** suggests fullscreen below ×1 (`scale < 1.0`). It also owns auto-pause on focus loss.
- **7.2 (Options > Video):**
  - Fullscreen and Scale settings;
  - `Display.start()` reads them after `load_settings()` (why `start()` runs after it), and the window cap becomes the setting;
  - on web, Fullscreen sits beside itch's button.
- **7.15:** the Windows boot (ledger).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.14: Display scaling and web input] (`:1675-1692`)
- [Source: _bmad-output/planning-artifacts/epics.md] AR8 (`:208`), AR53 (`:286`), NFR6 (`:177`), UX-DR122 (`:910`), UX-DR146–148 (`:970-986`), UX-DR58 (`:606`), Story 1.33 (`:2170`), Story 7.2 (`:4050`)
- [Source: _bmad-output/game-architecture.md] Technical Requirements → Display (`:134`), Testing → web smoke (`:221-230`), Engine-Provided Architecture → Pixel display (`:241`), platform branches (`:592`), tree (`:708-711`), component table (`:839`)
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/EXPERIENCE.md] Input Schemes → Rules ("Web keys"), Responsive & Platform (`:323-331`), D15
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/DESIGN.md] native canvas, embed 960×540, black letterboxing and the gutter outer rule (`:563-564`), the gate (`:704`)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md] Platform-Specific Details (`:669-670`), Performance (`:657`)
- [Source: _bmad-output/project-context.md] Platform & Build Rules, Testing Rules
- [Source: _bmad-output/implementation-artifacts/1-13-export-pipeline-and-web-boot-smoke.md] D2, D7, D8, D14, Review Findings
- [Source: docs/build.md] The web smoke, Playing builds on the laptop, Engine upgrade checklist

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), gds-dev-story, 2026-11-19.

### Debug Log References

- **Baseline (Task 1):** `./run_tests.sh` → `== ALL GREEN (21 tests)`, 1326 `ok`. `tools/export.sh` → `== BUILD OK builds/20261119-4f72f08-dirty … 84 s`, `3 passed (28.6s)`. It was dirty only from the story and sprint-status edits; `display.gd` was created mid-run, which is why Windows packed 74 files and Linux 76.
- **F12, new probe (4.7.2 web debug, headless Chromium):** on a browser resize `get_window().size` and `DisplayServer.window_get_size()` follow the canvas backing (DPR 1: 1000×600, 400×225, 320×180; DPR 2: 2000×1200, 800×450, 640×360), and the viewport's visible rect stays 480×270 at every size, the fit included. **But `Window.size_changed` never fires** (no line in 8 resizes). The first smoke run failed because of it: `2 failed, 5 passed`, at DPR 1 400×225 (no fit, cropped) and DPR 2 320×180 (no new `scale 1` line). Fix: `start()` keeps the `size_changed` connection and also turns on a per-frame size check in `_process` (`PROCESS_MODE_ALWAYS`, off until `start()`). `apply()` returns early on a size it has seen.
- **Probe: a stretch change re-emits `size_changed`?** It doesn't matter: `apply()` compares sizes first, and on web the signal never fires at all.
- **`ConfigFile.get_value(sec, key, null)`** treats `null` as "no default" and prints an engine `ERROR:` when the key is missing (seen in red 1's first run). The new preset checks call `has_section_key()` first.
- **Task 7 (Xvfb, `--rendering-driver opengl3 --audio-driver Dummy`, geometry from `xwininfo`):**
  - 1366×768: `[ui] display: window x2 960x540 (screen 1366x768)`, `[ui] display: scale 2 in 960x540`, window 960x540+203+114 (centred);
  - 1920×1080: `[ui] display: scale 3 in 1440x810`, no window line, 1440x810+240+135;
  - `--resolution 300x200`: `[ui] display: scale 1 in 480x270`, window 480x270 (min_size grew it; no window line, since it only shrinks);
  - `--fullscreen`: the server's Xvfb has no window manager, so the fullscreen request is never honoured. The window stays 1440×810 (`scale 3 in 1440x810`). At 1366×768 the window step is correctly skipped (no window line, mode not windowed). The real fullscreen look moves to the laptop (Task 10).
- **Task 9:** `./run_tests.sh` → `== ALL GREEN (22 tests)`, 1381 `ok`, no `ERROR:` lines. `tools/export.sh` → `== BUILD OK builds/20261119-4f72f08-dirty, web download 10.3 MB (gzip; raw 40.0 MB), PCK files windows 76 / linux 76 / web 76 / web_debug 83, 119 s`, `7 passed (1.0m)`.
- **D10 red checks** (detached worktree in the scratchpad with the uncommitted work applied, one at a time):
  1. no `html/head_include` in `Web`: `FAIL preset.2 (Web): html/head_include holds the key guard (missing ["the key"])`, `FAIL Web and Web debug carry the same html/head_include`; export.sh `BUILD FAILED: web_smoke` with `Web input … Error: blurred: ArrowDown leaves the host page at scrollY 0`.
  2. `apply()` always INTEGER: `FAIL apply 400x225: below 480x270 switches to the fit (… got 0.83333, integer …)` (2 FAILs); export.sh `BUILD FAILED`, `Display scale › DPR 1 … Error: 400x225 CSS at DPR 1: the engine draws x0.833, centred, both gutters showing`.
  3. `scale_for` rounds: `FAIL scale_for 1439x810 = 2.00000, integer (got 3.00000, integer)`, plus 959×540, 960×539 and 1440×809 (FAILED (4)).
  4. no headless guard in `start()`: `test_display` prints `[ui] display: scale 1 in 480x270` (min_size grows the 64×64 headless window first, so not the 0.133 fit D10 predicted) and fails `start() under headless leaves scale 0.0 (got 1.0)`, `...and connects nothing to size_changed`, `...and leaves the per-frame size check off`. `test_state` stays green.
  5. `html/canvas_resize_policy=0`: `FAIL preset.2 (Web): html/canvas_resize_policy=2, written explicitly (got 0)` and the same for preset.3.
  6. `serve.js` (port 8071 on the baseline build): `/embed.html` 200 `text/html`, `/embed.html?build=web_debug` 200, `/%2e%2e/tools/web_smoke/serve.js` 404, a symlink `web/evil.txt` → `/etc/hostname` 404, `/serve.js` 404, `/embed%2ehtml` 404, `/web_debug` 301. **`/embed.html/../web/index.html` gives 200**, not the 404 D10 expected. URL parsing collapses `..` to `/web/index.html`, a file inside `BUILD_DIR`, byte-identical to it (`cmp`). 1.13's `serve.js` gives the same 200, so this is unchanged behaviour, and nothing outside `BUILD_DIR` is reachable.
  7. (added) no per-frame size check: export.sh `BUILD FAILED`, `2 failed`: DPR 1 at 400×225 and DPR 2 `the newest "[ui] display:" line names scale 1`.

### Completion Notes List

- **`Display`** (`scripts/core/display.gd`, child of `Game` as `Game.display`, assert setter, `state_write` lint): `scale_for` / `stretch_for` / `window_scale_for` statics, `apply()` (stretch + `scale`, emit and one `Log.UI` line only on change), `start()` (inert under headless; on PC not web/embedded, `min_size` 480×270 and the shrink-to-fit plus centre for a windowed window; then apply, `size_changed`, and the per-frame check). `Game.boot()` calls `display.start()` after `load_settings()`. `project.godot` untouched.
- **Deviation from AC1's mechanism, from probe F12:** AC1 names only the `size_changed` connection. On web that signal never fires, so `Display` also checks `get_window().size` each frame (one compare; nothing logs unless the scale changes). The connection stays, per AC1. The behaviour AC1/AC2 ask for is met, and the smoke proves it (red 7).
- **Presets:** both web `.options` gained `html/canvas_resize_policy=2`, `html/focus_canvas_on_start=true` and D5's `html/head_include`, verbatim. `test_export_presets` checks them (60 → 67 checks), plus that the guard is identical in both presets.
- **Smoke:** `embed.html` and its one exact `serve.js` route; `Display scale` (3 tests, screenshots measured in the browser, expected values from a table) and `Web input` (1 test, release in the embed, focused and blurred phases). A measure failure prints the whole measurement as JSON. Header comment updated.
- **Tests:** new `test_display` (47 checks); `test_lint` sample `Game.display = x`. 22 tests, 1381 `ok`.
- **Docs (D9):** `docs/build.md`, `architecture.md`, `component-inventory.md`, `source-tree-analysis.md`, `perf.md`, `development-guide.md` (run line, "add a web export option" row), `project-context.md` (Current State, one Platform rule, Last Updated), `game-architecture.md` (`:134`, `:230`, `:241`, tree, table), `epics.md` AR8 as built. `docs/index.md` needed nothing.
- **Not verifiable on the server:** real fullscreen (no WM under Xvfb), F11/F12 in a real browser, browser zoom. These are in the laptop look (Task 10).
- Report: **export green; needs a 5-minute look on the laptop.**

### File List

- `game/scripts/core/display.gd` (new)
- `game/scripts/core/display.gd.uid` (new)
- `game/tests/test_display.gd` (new)
- `game/tests/test_display.gd.uid` (new)
- `tools/web_smoke/embed.html` (new)
- `game/scripts/core/game.gd`
- `game/export_presets.cfg`
- `game/tests/test_export_presets.gd`
- `game/tests/test_lint.gd`
- `tools/web_smoke/serve.js`
- `tools/web_smoke/smoke.spec.js`
- `docs/build.md`
- `docs/architecture.md`
- `docs/component-inventory.md`
- `docs/source-tree-analysis.md`
- `docs/perf.md`
- `docs/development-guide.md`
- `_bmad-output/project-context.md`
- `_bmad-output/game-architecture.md`
- `_bmad-output/planning-artifacts/epics.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/1-14-display-scaling-and-web-input.md`

## Change Log

- 2026-11-19: Story created (create-story). Engine and browser behaviour probed on the server (F1–F11). Status ready-for-dev.
- 2026-11-19: Implemented (dev-story). `Game.display`, the web presets' keys and key guard, `embed.html`, the `Display scale` and `Web input` smoke blocks, `test_display`, docs. New probe F12: the web root window never emits `size_changed` on a browser resize, so `Display` also checks the size each frame. 22 tests green (1381 ok); export BUILD OK, 7 passed; D10 red checks recorded. Status review.
