# Builds and the Export Pipeline

**Purpose:** AR51–AR53, NFR5, NFR7 (Story 1.13). Builds come from the headless server: one command validates the content, exports Windows, Linux and web, proves each build the server can run actually boots, and checks the web download size. Builds are played on the laptop.

```bash
tools/export.sh        # from the repo root; GODOT=/path/to/godot if it isn't on PATH
```

Run `cd game && ./run_tests.sh` first for any build you will share: `export.sh` validates content only, not the whole suite (below).

## One-time server setup

- **Godot 4.7.2** (`godot --version` starts with `4.7.2.stable`).
- **Export templates, 4.7.2**, in `~/.local/share/godot/export_templates/4.7.2.stable/` (or under `$XDG_DATA_HOME`), with `version.txt` = `4.7.2.stable`. `export.sh` uses four: `linux_release.x86_64`, `windows_release_x86_64.exe`, `web_nothreads_release.zip`, `web_nothreads_debug.zip`. To install or replace them (sonlm, 2026-11-19: the full archive, checked by SHA-512):
  1. download `Godot_v<version>-stable_export_templates.tpz` and `SHA512-SUMS.txt` from `https://github.com/godotengine/godot/releases/download/<version>-stable/` (4.7.2: the `.tpz` is 1,281,349,702 bytes);
  2. `grep export_templates.tpz SHA512-SUMS.txt | grep -v mono | sha512sum -c -` must print `OK`;
  3. extract only what is missing, for example the web zips: `unzip -j <tpz> 'templates/web_nothreads_release.zip' 'templates/web_nothreads_debug.zip' -d ~/.local/share/godot/export_templates/4.7.2.stable/` (all of them, for a new version, plus `templates/version.txt`);
  4. delete the `.tpz`.
- **Node 24** or later.
- **Playwright and its browser**, pinned in `tools/web_smoke/package.json` (`@playwright/test` exactly `1.65.1`):

  ```bash
  cd tools/web_smoke && npm ci && npx playwright install --only-shell --no-remove chromium
  ```

  `--only-shell` installs Chrome for Testing's headless shell, all a headless run uses. `--no-remove` keeps older browser revisions that other tools on the server use (the Playwright MCP plugin's revision 1217).

## What `tools/export.sh` does

Steps run in order and the first failure stops the build. The last line is `== BUILD OK builds/<version>, web download … MB (gzip; raw … MB), licences in 4 folders, PCK files …` (exit 0) or `== BUILD FAILED: <step>: <reason>` with the log to read (exit 1). There are no flags or partial modes.

| Step | Checks |
|---|---|
| **preflight** | Godot is 4.7.2; each of the four templates is installed with `version.txt` = `4.7.2.stable`; Node ≥ 24 and `npx`; Playwright `1.65.1` in `tools/web_smoke/node_modules` (read from its `package.json`, without Node); its headless shell is installed (by Playwright's own registry: `chromium.executablePath()` names the full Chromium, which an `--only-shell` install lacks; without Node or Playwright it is named as not checked); port 8061 is free. Every missing item is named in one run, and nothing is built |
| **version** | `<yyyymmdd>-<sha7>`, plus `-dirty` when `git status --porcelain` shows anything. Computed before the export, which can create `.godot/` and `.uid` files |
| **import** | `godot --headless --path game --import`. On a tree that was never imported (a fresh clone, no `game/.godot/`) a first import runs unscanned: the project loads its font before the import has made the font's data, which logs errors once; the scanned import follows. The import regenerates `text/strings.en.translation` whenever its CSV changed since the last import (an edit, or a pull), so a CSV committed without its re-imported `.translation` would be repaired here and ship a table that is not the commit's, under a version computed before the import (Story 1.17 code review). So the step fails when the import rewrote a tracked file on a clean tree (files it creates, `.godot/` and a new `.uid`, are untracked and don't count), and when a `.translation` differs from the commit while its CSV is as committed. Commit the regenerated file and build again |
| **content** | `tests/smoke_rooms.gd` through the runner: every `rooms/**/*.txt` file (validation, unique ids and exit links, the per-room guarantees), in about 12 s. Passes on the runner's exit 0, no error line and its `SMOKE PASS` line. Then `tests/test_strings.gd` (Story 1.17): the string table's shape, that every key is registered, the English fallback under other locales, each formatted key's conversions, every key reference in `scripts/` and `scenes/`, no dead key, the copy rules and raw text in scenes. (A stale `.translation` that the import repaired is the import step's check; `test_strings` sees only one the import left alone.) Passes the same way, on its `PASS` line. Runs before any export. Story 5.7 adds the flags and lengths |
| **export** | Deletes Godot's export cache (`game/.godot/exported/`) first, then `Windows`, `Linux`, `Web` (release) and `Web debug`, headless, to absolute paths. The cache holds each converted scene keyed on the scene file alone, and the conversion drops properties equal to the script's default, so a scene converted before an `@export` default changed would ship without its value (review of 1.20, probed on 4.7.2) |
| **licences** | Story 1.17 (NFR18, UX-DR16): the sources are checked first, by name (`LICENCE_FILES`: `OFL.txt` and the four files under `LICENSES/`, each non-empty, and no file there that the list doesn't name). `tools/godot_licenses.gd` writes `logs/GODOT_LICENSES.txt` once per build (below), then `game/fonts/OFL.txt`, `game/fonts/LICENSES/` and `GODOT_LICENSES.txt` are copied to the top level of each of `windows/`, `linux/`, `web/` and `web_debug/`. It fails if any copy is missing or differs from its source by a byte in any folder (`cmp`, `diff -r`). They are not resources, so no PCK carries them; the itch.io zip is `web/`, so they ship there too |
| **pck** | Lists each PCK with `tools/pck_list.gd` (below). No PCK may hold a path under `res://tests/`, and a release PCK (Windows, Linux, Web) none under `res://rooms/dev/`, `res://scenes/dev/` or `res://scripts/dev/` (`scenes/dev/` has no files yet; the first one fails here until its exclusion is in the presets and `test_export_presets`). So an empty or wrong listing can't pass, a release PCK must hold `res://scripts/world/world.gd…` and every room file outside `rooms/dev/`, and the `Web debug` PCK `res://scripts/dev/dev_tools.gd…` and every room file, `rooms/dev/perf_worst.txt` included. Every PCK must also hold the font's import remap `res://fonts/fusion-pixel-8px-proportional-latin.otf.import`, its imported data `res://.godot/imported/fusion-pixel-8px-proportional-latin.otf-<md5>.fontdata` and the string table `res://text/strings.en.translation` (Story 1.17) |
| **size** | The web download, NFR5: the sum of each top-level `web/` file's `gzip -9` size (the licence files included; `LICENSES/` is a few KB) must be under 30,000,000 bytes (`WEB_DOWNLOAD_MAX_BYTES`). It is what itch.io's CDN sends, since it gzips `html`, `js`, `wasm` and `pck`. The raw size is printed beside it (4.7.2's `index.wasm` alone is 39.5 MB raw, about 10 MB compressed) |
| **boot** | The Linux release build runs headless for 5 s. It passes only if `timeout` ends it (exit 124: still running) and it printed no `ERROR` / `SCRIPT ERROR` line |
| **web_smoke** | `tools/web_smoke/`: both web builds in headless Chromium (below), under a 600 s `timeout`. Passes on exit 0 with an `N passed` line and no skipped, flaky, unrun or interrupted test (`forbidOnly` in the config stops a stray `test.only`) |
| **summary** | Writes `logs/summary.txt` and prints the end line |

Every Godot step runs under `timeout` (600 s for exports, 150 s for each content run, 60 s for listings and the licence notice) and fails on a non-zero exit **or** any `ERROR:` / `SCRIPT ERROR` / `FAIL` line in its log, scanned with the colours stripped: Godot exits 0 on some errors (a missing preset options section, a parse error in a release build). A Ctrl-C or a TERM still ends with `== BUILD FAILED: <step>: interrupted` and `logs/summary.txt`.

The licence notice, the PCK listings and the Linux boot run with `XDG_DATA_HOME` set to the build's own `logs/xdg_data/`, so the game's `user://` is fresh for every build: a boot never reads what an earlier build left (an older or newer settings or save schema) and never writes the server's own. Exports keep the real `XDG_DATA_HOME`, where the templates live.

**What each build can prove.** A release build prints parse and load errors but no runtime script errors (the VM's runtime error report is debug-only), and a Linux release build prints nothing at all when it is fine. So:

- the **Linux release boot** proves `world.gd` loads without `scripts/dev/` (a `preload` of DevTools there prints `SCRIPT ERROR: Parse Error: Preload file … does not exist`, while its export exits 0);
- the **release web smoke** is boot-only: the engine starts and nothing errors for 5 s;
- the **debug web smoke** is the runtime check: `SMOKE boot ok`, then 5 s of play with no `console.error`, since debug builds print runtime `SCRIPT ERROR`s;
- the **Windows build is never booted on the server** (no Windows or wine). Its PCK is checked and is byte-identical to Linux's (ledger, owner Story 7.15).

## Output

```
builds/<version>/
  windows/unbroken_chain.exe, unbroken_chain.pck, OFL.txt, LICENSES/, GODOT_LICENSES.txt
  linux/unbroken_chain.x86_64, unbroken_chain.pck, OFL.txt, LICENSES/, GODOT_LICENSES.txt
  web/index.html, index.js, index.wasm, index.pck, index.audio.worklet.js,
      index.audio.position.worklet.js, index.png, index.icon.png, index.apple-touch-icon.png,
      OFL.txt, LICENSES/, GODOT_LICENSES.txt
  web_debug/(the same names)
  logs/import.log, content.log, content_strings.log, export_{windows,linux,web,web_debug}.log,
       licences.log, GODOT_LICENSES.txt, pck_{windows,linux,web,web_debug}.txt, boot_linux.log,
       web_smoke.log, summary.txt, xdg_data/ (the user:// of the listings and the boot)
```

- `builds/` is gitignored. A rebuild of the same version replaces its folder; nothing outside it is deleted.
- The version string is the playtest records' "build version".
- The desktop PCK sits beside the binary (`embed_pck=false`), so the release check can list it. Keep the pair together.
- The web output is named `index.html`: its base name names every web file, and itch.io wants `index.html` at the zip's top level.

## The presets

`game/export_presets.cfg` is committed, with four presets that `export.sh` calls by name: `Windows`, `Linux`, `Web` (release) and `Web debug`. `tests/test_export_presets.gd` pins them, so a laptop editor re-save that drops something fails the suite.

- Every preset: `export_filter="all_resources"` and the include filter `rooms/*.txt`. In Godot's matcher `*` crosses `/` and `**` is a plain `*`, so `rooms/*.txt` means every room file at any depth; `rooms/**/*.txt` would skip a room placed directly in `rooms/`. Matching is case-insensitive and anchored at the path's start, so it never takes `tests/rooms/…`.
- Release presets exclude `rooms/dev/*, tests/*, scripts/dev/*`. `Web debug` excludes only `tests/*`: it keeps `perf_worst.txt` and DevTools, whose path-string `load()` in `world.gd` has no null check.
- Web presets are single-threaded (`variant/thread_support=false`, `variant/extensions_support=false`, `progressive_web_app/enabled=false`), so they use the `web_nothreads_*` templates and need no COOP/COEP headers.
- Web presets also write three `html/*` keys explicitly (Story 1.14), so a re-save that changes them fails the suite:
  - `html/canvas_resize_policy=2` (Adaptive): with `display/window/dpi/allow_hidpi` (true by default; `test_display` checks the effective value) the canvas backing is the CSS size × devicePixelRatio, so the game's window is in physical pixels and the integer stretch picks the scale from them. There is no JavaScriptBridge.
  - `html/focus_canvas_on_start=true`: the canvas has focus at boot, so keys reach the game.
  - `html/head_include`: the key guard, the same text in both presets. It is a capture-phase `keydown` listener on `window` that calls `preventDefault()` for the arrows, Space, PageUp/PageDown, Home, End and F1–F12 (matched on `e.code` or `e.key`, so the numpad's navigation keys with NumLock off are caught too) and gives the canvas focus back if it lost it; any other key also gives the canvas focus back while nothing in the page has focus, so the game's own keys recover after a blur. F11 (browser fullscreen) and Ctrl/Cmd with `+`, `-` or `0` (browser zoom) are the exception: Godot's canvas listener calls `preventDefault()` on every key, so the guard stops them before it (`stopPropagation()`, no `preventDefault()`) and the browser handles them (laptop look of 1.14). F5 and the other F-keys stay blocked. Godot already prevents those keys on the focused canvas; the guard covers focus elsewhere in the game's page, where in an itch-style embed they scrolled the host page. It runs in `<head>` before the canvas exists, so it looks the canvas up when a key arrives. The JavaScript uses single quotes and no backslashes, so the cfg value needs no escapes.
- No preset sets a `custom_template/*` path, an encryption key or an absolute `export_path`. Opening Project → Export on the laptop rewrites the file with every key; commit that only if `test_export_presets` still passes and the diff holds no machine path.

## `tools/pck_list.gd`

```bash
godot --headless --main-pack /abs/path/game.pck -s /abs/path/tools/pck_list.gd
```

It prints every file in the pack, one `res://…` path per line, after the engine banner (keep only `^res://` lines). A folder it can't open prints an `ERROR:` line and makes it exit 1, so a partial listing fails the step. The engine reads its own pack, so a PCK format change (v4 in 4.7) needs nothing here. Both paths must be absolute: a relative `-s` path resolves inside the pack. Caveat: `--main-pack` still instances the pack's autoloads. `Game._init()` only builds the Clock and the Display (disk access and the window wait for `boot()`, which only World calls), so a listing touches nothing; **a future autoload must keep disk and network out of `_init()` and `_ready()`**.

## `tools/godot_licenses.gd`

```bash
godot --headless --path /abs/path/game -s /abs/path/tools/godot_licenses.gd -- /abs/out/GODOT_LICENSES.txt
```

It writes Godot's MIT licence (`Engine.get_license_text()`), every third-party component the engine was built with (`Engine.get_copyright_info()`: name, files, copyright lines, licence) and every licence's full text (`Engine.get_license_info()`), about 97 KB on 4.7.2. It runs on the editor binary, which preflight pins to 4.7.2 like the templates; the editor's component list is a superset of the templates' (it adds editor-only components), and a superset notice is compliant. A write failure prints an `ERROR:` line and exits 1. Probed on 4.7.2 (Story 1.17): with `--path game` and with `--main-pack <pck>` it exits 0 with no error line and writes the same bytes; `export.sh` uses `--path game`, so it needs no built PCK.

## Third-party files

**Fusion Pixel Font** (Story 1.17 D1; AR42, UX-DR16), OFL 1.1, by TakWolf: `game/fonts/`, taken unmodified from release **`2026.11.10`** (published 2026-11-09), the latest on 2026-11-21.

- Asset: `https://github.com/TakWolf/fusion-pixel-font/releases/download/2026.11.10/fusion-pixel-font-8px-proportional-otf-v2026.11.10.zip` (17,520,997 bytes), SHA-512 `3b332a100518738d1acbc2beb7cefef19f1dec8e01f363f258264099d9071b2e78d1e120e49b188da83646dbaa273507bb49423b239f1d96be258b86ab9bc8d9`.
- Kept from it: `fusion-pixel-8px-proportional-latin.otf` (2,501,068 bytes, SHA-256 `82f1df2f423d8a4880f3dd6f1839a34855648c69e2a3652a3e8f09d665971be2`), `OFL.txt` (SHA-256 `bc518cf64b8032c07690f33cc270c35c179255a6ac8efa7c165ebae7e8f76a63`) and `LICENSES/` (the licences of the fonts Fusion draws on; SHA-256: `boutique-bitmap-7x7/OFL.txt` `ad588b5ce58a02179b806381339fd380e5110771f2fa91279af026fd3ab97002`, `galmuri/LICENSE.txt` `86a3ee9495f942f0243f18c103da9faca27adb88142613edb8bb852e56c892c1`, `misaki/misaki.txt` `82929cc3b34c79b6a67f21fe137c7bb165589c9e34ba1441611e493afd67dfca`, `miseki-bitmap/LICENSE.txt` `e855b45b384d37c9a778119271bd9c32706e3f1f9f278de0ad47347606eea846`). The six other locale builds (`ja`, `ko`, `zh_*`) are left out. The `.otf` is not subset (that would be a modification under the OFL; the web budget has room). `OFL.txt` declares no Reserved Font Name.
- The committed `fusion-pixel-8px-proportional-latin.otf.import` pins `antialiasing=0`, `hinting=0`, `subpixel_positioning=0` and `allow_system_fallback=false` (the importer's defaults are 1 / 3 / 4 / true, and antialiasing survives Godot's pixel-font auto-detect). `tests/test_theme.gd` reads all four on the loaded font, so an editor re-import with defaults fails the suite.
- To move to a newer release: download into an empty folder, check the hashes, copy the same three items, re-import (the `.import` keeps the four pins), run the suite, and update this section.

## The web smoke

`tools/web_smoke/` (Playwright, Chromium only, headless) serves the build folder with `serve.js` and boots both web builds:

- every page: it is served (status 200); within one 60 s budget, the shell's `#status` overlay is removed and the console shows `Godot Engine v4.7.2.stable`; `#status-notice` stays empty; no page error; no `console.error` outside `ALLOWED_CONSOLE_ERRORS` (empty; every entry needs a reason). Godot sends `push_warning`, `push_error`, `printerr` and `SCRIPT ERROR` to `console.error`; Chromium's own `warning` messages (`GPU stall due to ReadPixels` under SwiftShader) are ignored;
- `Web debug`: `[room] SMOKE boot ok` appears (DevTools prints it on World's first `room_entered`, in real runs only, before the first physics tick), then the page plays 5 s more and the marker must still appear exactly once, with the checks above run after that. Then again as `?room=perf_worst`: DevTools' summary is exactly `[room] dev: room perf_worst@spawn` (a requested perf run would show in it), with no `dev: perf` line and no `WARNING: DevTools:` line;
- `Web` (release): the checks above, then 5 s more with no error, and no `[category]` Log line of any category (DevTools and `Log` are debug-only);
- `Display scale` (Story 1.14), on `Web debug`: one test per devicePixelRatio (1, 1.5, 2). Each boots once, then resizes the viewport through its steps (DPR 1: 960×540 → 1000×600 → 400×225 → 1000×600; DPR 1.5: 960×540 → 1000×600; DPR 2: 960×540 → 320×180). Each step is measured from a device-pixel screenshot, decoded by the browser itself: the box of non-black pixels must be 480·s × 270·s (±1 px for the fit), centred to within 1 px, with the same colour at its outermost columns at mid-height (both gutters show, so nothing is cropped). The newest `[ui] display: scale …` line must name the same scale. Expected values are written in the test's table, never computed by a copy of the rule;
- `Web input` (Story 1.14), on the release build inside `embed.html` (an itch-style host page: a header, the game in a 960×540 iframe, 3000 px of page): with the canvas focused, every guarded key except F11/F12 reaches the frame prevented and the host stays at `scrollY 0`; after `blur()` inside the frame, the same keys still leave the host at 0 and the first one gives the canvas focus back; after another `blur()`, a game key (`KeyZ`) gives the canvas focus back too, not prevented; with the canvas focused, F11 and Ctrl `=` `-` `0` arrive not prevented while F5 and F10 stay prevented.

On a failure the whole browser console is printed under the failing test's title, so `logs/web_smoke.log` shows it. It checks correctness only: headless WebGL runs on SwiftShader, so it says nothing about performance (that is [perf.md](./perf.md)).

Run it alone against a build, from the repo root:

```bash
B="$PWD/builds/<version>"; (cd tools/web_smoke && BUILD_DIR="$B" npx playwright test)
```

It serves on `127.0.0.1:8061` (`PORT` to change it). Seven tests: 2 `Web debug`, 1 `Web (release)`, 3 `Display scale`, 1 `Web input`.

## Playing builds on the laptop

**Desktop:** copy a build folder and run it.

```bash
rsync -a <server>:project/pixel_art_game/builds/<version>/linux/ ./uc-<version>/   # or windows/
./uc-<version>/unbroken_chain.x86_64                                                  # unbroken_chain.exe on Windows
```

**Web:** serve the build on the server and tunnel to it, so the laptop's browser sees `localhost`, a secure context (a LAN IP over plain HTTP fails Godot's secure-context check):

1. on the server: `BUILD_DIR=builds/<version> PORT=8060 node tools/web_smoke/serve.js`;
2. on the laptop: `ssh -L 8060:127.0.0.1:8060 <server>`;
3. open `http://localhost:8060/web_debug/index.html` (debug: DevTools' query args work, for example `?room=perf_worst&perf`) or `http://localhost:8060/web/index.html` (release);
4. for keys in an itch-style embed: `http://localhost:8060/embed.html?build=web` (or `?build=web_debug`). Arrows, Space, PageDown and F5 must never scroll or reload the host page while the game has focus. With the header text clicked, arrows scroll the host, which is correct: the game doesn't have focus.

`serve.js` serves `BUILD_DIR` plus one exact path beside itself, `/embed.html`. It sends `.wasm` as `application/wasm`, ignores the query string, redirects a folder URL without its trailing slash (`/web_debug` → `/web_debug/`, since the shell's files are relative), never serves outside `BUILD_DIR` (symlinks included), and sends `Cache-Control: no-store`, so a rebuilt version at the same path is never stale.

## itch.io

- Upload `web/` as a zip with `index.html` at its top level, as an HTML game; embed at **960 × 540** (×2).
- Leave **SharedArrayBuffer support** off: a non-threaded build doesn't need it, and the option changes the game's origin, which loses saves.
- itch.io's limits: 1,000 files, 500 MB extracted, 200 MB per file, 240-character paths. A build has 15 web files: 9 from the export, plus `OFL.txt`, `GODOT_LICENSES.txt` and the 4 files under `LICENSES/` (Story 1.17).
- Click-to-play is an itch.io frame option, on by default; the game's own gate is Story 1.33.

## Engine upgrade checklist (AR7)

For 4.7.x maintenance only (the engine is frozen on 4.7.x for M2; a minor upgrade is considered only at an epic boundary):

1. Update the editor and the templates on the laptop and the server together: templates by the procedure above, with the new version's SHA-512. Update `GODOT_VERSION` in `tools/export.sh`.
2. Re-import (`godot --headless --path game --import`, or open the project).
3. `cd game && ./run_tests.sh` gives `== ALL GREEN`.
4. `tools/export.sh` gives `== BUILD OK`, which includes the web smoke. Update the smoke's `BANNER` to the new version first.
5. Recheck the display and web-input facts Story 1.14 relies on (its F1–F7) against the new templates. The web smoke covers most of them:
   - the canvas backing is CSS size × devicePixelRatio;
   - the integer stretch works on physical pixels, and below 480×270 it crops (which is why `Display` switches to the fractional fit there);
   - the letterbox is pure black, and the fractional stretch blits nearest-neighbour;
   - Godot calls `preventDefault()` on the keys the focused canvas gets;
   - `$GODOT_HEAD_INCLUDE` is still in `<head>` of the template's shell;
   - on web, the root window's `size_changed` still doesn't fire on a browser resize (`Display` polls the size; if it fires now, the poll is harmless).
6. A manual web look on the laptop (the tunnel above), debug and release, and `embed.html`.
7. Commit the changed `.import` files.

A PCK format change (v4 in 4.7) needs nothing here: `pck_list.gd` uses the engine's own reader. When the Playwright pin moves, re-check `export.sh`'s browser preflight, which reads Playwright's internal registry module.
