---
baseline_commit: 21e15df
---

# Story 1.13: Export pipeline and web boot smoke

Status: ready-for-dev

**Type:** dev · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP1 Foundations (1.1–1.15) · **Branch:** `feat/m2-e1`

## Story

As the developer,
I want one server command that validates content, exports every target and smoke-tests the web build,
so that every build I play on the laptop is known to boot.

## Acceptance Criteria

1. **`game/export_presets.cfg` is committed, with four presets.**
   - The presets, named exactly as below because `tools/export.sh` calls them by name:

     | Name | Platform | Kind |
     |---|---|---|
     | `Windows` | `Windows Desktop`, x86_64 | release |
     | `Linux` | `Linux`, x86_64 | release |
     | `Web` | `Web` | release |
     | `Web debug` | `Web` | debug |

     Number them `[preset.0]` to `[preset.3]` with no gaps.
   - **Every preset:**
     - `export_filter="all_resources"`;
     - the room include filter `rooms/*.txt` (D2: in Godot's matcher `*` crosses `/` and `**` is a plain `*`, so this is the pattern that means "every room file at any depth", which the epic wrote as `rooms/**/*.txt`).
   - **The three release presets** have `exclude_filter="rooms/dev/*, tests/*, scripts/dev/*"`.
   - **`Web debug`** excludes `tests/*` only. It keeps every `rooms/dev/*` file, `perf_worst.txt` included (Story 1.12), and `scripts/dev/*`, because DevTools' path-string `load()` has no null check (1.11 D2).
   - **Web presets** are single-threaded: `variant/thread_support=false`, `variant/extensions_support=false` and `progressive_web_app/enabled=false`, all written explicitly. So they use the `web_nothreads_*` templates.
   - **Desktop presets** use `binary_format/embed_pck=false`, so the PCK the release check lists sits beside the binary.
   - **No preset sets** a `custom_template/*` path, an encryption key, or an absolute `export_path`. The renderer stays GL Compatibility; `project.godot` is not touched.
   - **"Templates pinned to 4.7.2"** means `export.sh` refuses to run unless both are true:
     - `godot --version` starts with `4.7.2.stable`;
     - `export_templates/4.7.2.stable/` holds each template it uses, with a `version.txt` of `4.7.2.stable`.
   - **The new `tests/test_export_presets.gd` checks all of the above** (D2), so a laptop editor re-save that drops a filter fails the suite. It also runs `String.matchn()`, the matcher the exporter uses, over the real files under `res://rooms/`, `res://tests/` and `res://scripts/dev/`.

   (AR51, NFR7; D2)
2. **`tools/export.sh` builds every target with one command, and stops at the first failure.**
   - **Preflight:**
     - Godot is 4.7.2.
     - Every template it needs is installed: `linux_release.x86_64`, `windows_release_x86_64.exe`, `web_nothreads_release.zip`, `web_nothreads_debug.zip`.
     - Node is 24 or later.
     - `tools/web_smoke/node_modules/@playwright/test/package.json` has version `1.65.1`.
     - The browser is installed: `(cd tools/web_smoke && node -e "process.exit(require('fs').existsSync(require('playwright-core').chromium.executablePath()) ? 0 : 1)")` succeeds. If `executablePath()` points at the full Chromium rather than the headless shell, check the shell's path instead and record which.

     Each missing item is named, and the script exits non-zero before it builds anything.
   - **Content:**
     - `godot --headless --path game --import`, then `tests/smoke_rooms.gd` through `tests/runner.tscn`. That covers every room file: validation, unique ids and exit links, and the per-room guarantees.
     - A non-zero exit, a `FAIL` line or an `ERROR` line stops the build before any export (D12).
     - Later stories add their validators here: string keys (1.17), flags and lengths (5.7).
   - **Output:**
     - Everything goes to `builds/<version>/` (D3). `builds/` is gitignored.
     - A rebuild of the same version replaces the folder.
     - Each step's log goes to `builds/<version>/logs/`.
   - **Exports:**
     - `Windows`, `Linux` and `Web` with `--export-release`; `Web debug` with `--export-debug`; all headless.
     - Every path handed to Godot is **absolute**. Godot resolves a relative export path against `game/`, not the shell's folder (validated on 4.7.2: exit 1, "The given export path doesn't exist").
     - Each output folder is created first, because Godot refuses a missing one.
     - An export fails on a non-zero exit **or** any `ERROR:` / `SCRIPT ERROR` line in its log, with ANSI colours stripped first. Godot exits 0 on some errors (verified).
   - **End line:** `== BUILD OK builds/<version> …` with the web download size, or `== BUILD FAILED: <step>`, and the matching exit code.

   (AR52; D1, D3, D5, D12, D13)
3. **No release PCK carries dev or test content.**
   - `export.sh` lists every release PCK (Windows, Linux, Web) and the `Web debug` PCK with the new `tools/pck_list.gd`, run as `godot --headless --main-pack <pck> -s <abs path>` (D4).
   - It fails if a release listing has any path under `res://rooms/dev/`, `res://tests/` or `res://scripts/dev/`.
   - **So the check can't pass on an empty or wrong listing**, it also requires:
     - every release PCK has `res://rooms/l1/m1_shaft.txt` and a `res://scripts/world/world.gd…` entry;
     - the `Web debug` PCK has `res://rooms/dev/perf_worst.txt` and a `res://scripts/dev/dev_tools.gd…` entry.
   - The listings are kept in `logs/`.

   (AR53, AR51; D4)
4. **Every release build the server can run proves that `world.gd` loads without `scripts/dev/`.**
   - **Linux release:** `export.sh` runs it headless for 5 s. It passes only if `timeout` ends it (exit 124: still running, no crash) and its output has no `ERROR` / `SCRIPT ERROR` line. The D5 probe shows the failure this catches: a `world.gd` that preloads DevTools prints `SCRIPT ERROR: Parse Error: Preload file "res://scripts/dev/dev_tools.gd" does not exist` in a release build, while its export exits 0 with no error.
   - **Web release:** the boot-only Playwright check (AC6).
   - **Windows:** it can't run on the server. Its PCK is checked (AC3) and is built from the same filters as Linux; the boot is deferred (AC9).

   (AR53; D5)
5. **The web download is under 30 MB.**
   - The download is the **compressed** size of the release `web/` folder: the sum of each file's `gzip -9` size. That is what itch.io's CDN sends, since it gzips `html`, `js`, `wasm` and `pck` (D6).
   - The raw size is printed beside it, for information. A Godot 4.7 web build's `index.wasm` alone is 39.5 MB raw and about 10 MB compressed.
   - A total of 30,000,000 bytes or more fails the build.

   (NFR5, AR52; D6, decided by sonlm)
6. **`tools/web_smoke/` boots both web builds in headless Chromium.**
   - **Setup:**
     - `package.json` pins `@playwright/test` to exactly `1.65.1` and sets `engines.node` to `>=24`; `package-lock.json` is committed and `node_modules/` is not.
     - A dependency-free `serve.js` (Node's `http` module) serves a build folder on `127.0.0.1`, with `.wasm` as `application/wasm` (D8).
     - `playwright.config.js` starts it as the `webServer`, with Chromium only and headless.
   - **Every page, both builds:**
     - The console shows `Godot Engine v4.7.2.stable` (the pinned templates, checked on the web).
     - The shell's `#status` overlay is removed and `#status-notice` stays empty.
     - There is no page error, and no `console.error` message beyond an allowlist. The allowlist starts empty, and every entry needs a reason. Godot sends warnings and errors to `console.error`; Chromium's own `warning`-type messages are ignored.
   - **`Web debug` (`/web_debug/index.html`):** `SMOKE boot ok` appears (AC7). Booted again as `?room=perf_worst`:
     - both `SMOKE boot ok` and DevTools' `[room] dev: room perf_worst@spawn` appear;
     - no `dev: perf` line appears: it is the plain room, as Story 1.12 noted;
     - no `WARNING: DevTools:` line appears.
   - **`Web` (release, `/web/index.html`): the boot-only check.** The checks above, then 5 s more with no error. A release web build prints parse and load errors but never runtime script errors (D5), so the debug run is the one that catches those.
   - **Running it:** `export.sh` runs it after the exports, as `BUILD_DIR=<abs> npx playwright test`. It also runs alone (`docs/build.md`).
   - It checks correctness only: headless WebGL runs on SwiftShader, so it says nothing about performance.

   (AR53; D7, D8)
7. **Debug builds print `SMOKE boot ok` once, when the first room is in.**
   - DevTools prints `Log.info(Log.ROOM, "SMOKE boot ok")` once, on World's first `room_entered`, in a real run only: the same `current_scene == World` gate as the args.
   - The line reads `[room] SMOKE boot ok`.
   - Release builds print nothing, because DevTools is absent and `Log` is silent there.
   - `smoke_dev_tools` checks three things:
     - a real-run World prints exactly one marker, after its room exists;
     - a test World (not the current scene) prints none;
     - a respawn prints no second marker.

   (AR53, AR54; D9)
8. **The ledger's foreign-query-parameter item is closed.**
   - The smoke passes only `ARGS` keys (`room`), so no foreign parameter appears, and AC6 asserts that no `WARNING: DevTools:` line appears.
   - The item closes as not triggered. 1.11 AC2's warning on an unknown arg stays as it is (D10).

   (Ledger)
9. **The docs, the engine upgrade checklist and the ledger match what was built.**
   - **New `docs/build.md`:**
     - how to set up the server (templates, Node, Playwright) and run `tools/export.sh`;
     - what each step checks, and the output layout;
     - how to play each build on the laptop (rsync, or the web build through an SSH tunnel to `serve.js`);
     - the **engine upgrade checklist** (AR7).
   - `docs/perf.md`'s web section points at it.
   - **Doc lines that say "no presets yet" or "Story 1.13" are updated:**
     - `docs/index.md`, `development-guide.md`, `architecture.md`, `source-tree-analysis.md`, `component-inventory.md`, `rooms.md`, `project-overview.md`;
     - `game/README.md`;
     - `project-context.md`, `game-architecture.md`;
     - AR51 in `epics.md` (D11).
   - **The ledger:**
     - the 1.11 foreign-parameter item is closed (AC8);
     - a new item, "the Windows build is never booted on the server", is owned by Story 7.15.

   (AR7; D10, D11)
10. **Done means green and run.**
    - `cd game && ./run_tests.sh` gives `== ALL GREEN` (21 tests).
    - `tools/export.sh` runs green end to end on the server, and its `== BUILD OK` line is recorded.
    - Every D14 red check is run and recorded.
    - The report says: "export green; needs a 5-minute look on the laptop" (D14).

## Tasks / Subtasks

- [ ] **Task 1: Baseline (AC: 10).** `cd game && ./run_tests.sh` gives `== ALL GREEN (20 tests)`, 1261 `ok` (baseline `21e15df`). The engine and browser facts this story relies on are probed already (see "Verified facts").
- [ ] **Task 2: The server's toolchain (AC: 2, 6), D1.**
  - Install the two web templates by D1's procedure: download the `.tpz`, check its SHA-512, extract the two zips, delete the `.tpz`. Record the checked hash and the two zip sizes in the Debug Log.
  - In `tools/web_smoke/`:
    1. Write `package.json` first: `"name": "web-smoke"`, `"private": true`, `"engines": {"node": ">=24"}`, `"scripts": {"test": "playwright test"}`.
    2. Run `npm install -D --save-exact @playwright/test@1.65.1`. Writing `package.json` after the install would desync the lock's root entry.
    3. Run `npx playwright install --only-shell --no-remove chromium`. `--no-remove` keeps revision 1217, which the Playwright MCP plugin uses. If the flag is rejected, use `PLAYWRIGHT_SKIP_BROWSER_GC=1 npx playwright install --only-shell chromium`.
  - Record the versions in the Debug Log.
- [ ] **Task 3: The presets and their test (AC: 1), D2.**
  - Write `game/export_presets.cfg` from D2's text.
  - Write `tests/test_export_presets.gd` (D2).
  - Red-check it (D14 1–3).
- [ ] **Task 4: The boot marker (AC: 7), D9.**
  - In `scripts/dev/dev_tools.gd`'s real-run branch, connect to World's `room_entered` once (`CONNECT_ONE_SHOT`, a method, not a lambda) and print the marker.
  - Add `smoke_dev_tools`'s `test_smoke_marker`.
- [ ] **Task 5: `tools/pck_list.gd` (AC: 3), D4.**
- [ ] **Task 6: `tools/web_smoke/` (AC: 6, 8), D7, D8.** Write `package.json`, the lock file, `playwright.config.js`, `serve.js` and `smoke.spec.js`.
- [ ] **Task 7: `tools/export.sh` (AC: 2–6), D3, D5, D6, D12, D13.** Make it executable (`git update-index --chmod=+x` if needed).
- [ ] **Task 8: `.gitignore`** gets:
  - `/builds/` (anchored: only the repo-root output folder)
  - `tools/web_smoke/node_modules/`
  - `tools/web_smoke/test-results/`
  - `tools/web_smoke/playwright-report/`
- [ ] **Task 9: The ledger (AC: 8, 9), D10.**
  - Close the 1.11 item with a `→ **Closed (Story 1.13): …**` line.
  - Add the Windows-boot item with its `→ **Owner: Story 7.15** — …` line.
  - `tests/test_deferred_owners.gd` stays green.
- [ ] **Task 10: Docs (AC: 9), D11.**
- [ ] **Task 11: Verify (AC: 10), D14.**
  - `./run_tests.sh` gives `== ALL GREEN (21 tests)` with no `ERROR:` lines.
  - `tools/export.sh` gives `== BUILD OK`. Record the end line, the sizes and the PCK file counts.
  - Run every D14 red check, each in a detached git worktree in the scratchpad, and record each one's failing line.
  - Stage the new files, with `.gd.uid` files beside any new `.gd` under `game/`. `tools/pck_list.gd` is outside the project and gets no `.uid`.
- [ ] **Task 12: Report:** "export green; needs a 5-minute look on the laptop". The look:
  - pull the branch;
  - rsync `builds/<version>/linux` (or `windows`) and run it;
  - open the web debug build through the tunnel (`docs/build.md`), plain and with `?room=perf_worst`;
  - then the release web build.

## Dev Notes

### What this story is (and isn't)

It is the build pipeline: four committed presets, one script that validates content, exports, checks and smoke-tests, and a Playwright harness that later stories extend. The only change to the game is one debug-only console line, `SMOKE boot ok`, printed by DevTools. Release builds don't change at all; they simply start being made.

**Not in this story:**
- **The DPR scale check and keys that must not scroll the page:** Story 1.14 adds them to this smoke (`test.describe` blocks in `smoke.spec.js`).
- **The browser and laptop measurements:** Story 1.15 runs `docs/perf.md` against this story's `web_debug` build.
- **Copying licences into each build** (`OFL.txt`, `LICENSES/`, `GODOT_LICENSES.txt`) and **validating string keys:** Story 1.17 adds both steps to `export.sh`.
- **The click-to-play gate and the title:** Story 1.33. From then on the smoke must pass the gate (a click on the canvas), and `?room=` must still boot straight into the room (ledger, owner 1.33).
- **`SMOKE save ok` and the save/reload check:** Story 1.39.
- **The pogo pitch check:** Story 3.3. **Throttled load and memory sampling:** Story 7.13.
- **Booting the Windows build:** Story 7.15 (AC9's new ledger item).
- **A custom web template with 3D disabled** (the architecture's plan B for 30 MB): not needed, since the compressed download is about 10 MB (D6).
- **Desktop debug presets:** not in the AC. Debug runs on the laptop are editor runs.
- **CI:** none. The server runs `export.sh` by hand.

### Current state (read before changing)

- **Nothing exists yet:** `game/export_presets.cfg`, `tools/export.sh` and `tools/web_smoke/`. `.gitignore` ignores `game/.godot/`, `game/export/`, `*.tmp` and the BMAD caches, but not `builds/`.
- **`scripts/world/world.gd` `_ready()` (`:42-59`):**
  - It first adds DevTools by a path-string `load()` inside `if OS.is_debug_build()` (the lint's one guarded `dev_ref` line).
  - Then it adds `LightBudget`, calls `Game.boot()` only when World is the current scene, and builds the first room with `_swap_room(point[0], point[1], true)`.
  - `_swap_room` emits `player_spawned`, then `room_entered` (`:163`), **synchronously inside World's `_ready()`**.
  - **Don't touch any of this.** The marker hangs off `room_entered`.
- **`scripts/dev/dev_tools.gd`:**
  - `_ready()` (`:64-73`): `_world = get_parent()`; when `get_tree().current_scene == _world` it sets `tokens = real_tokens()`; then it builds `Overlays` and calls `_apply(tokens)`.
  - DevTools is World's first child, so its `_ready()` runs before the first room is built (1.11 D3), and a `room_entered` connection made there sees the first room.
  - `real_tokens()` (`:108`): `OS.get_cmdline_user_args()` plus `query_tokens(window.location.search)` through `JavaScriptBridge.eval`, which returns null off the web.
  - `_apply()` logs its one summary as `Log.info(Log.ROOM, "dev: " + …)`, for example `[room] dev: room perf_worst@spawn` (probed in a desktop debug export). Its comment explains why: "AR55's category list is fixed (no DEV)". The marker uses `Log.ROOM` for the same reason.
  - The real-run gate is tested by `smoke_dev_tools` `test_real_tokens` (`:230-249`). It adds a World to root and makes it the current scene through `child_entered_tree` (`_make_current`). Reuse that pattern for the marker test.
- **`scripts/core/log.gd`:** `Log.info()` prints `[cat] msg` in every debug build, ungated by category, and **is silent in release** (`:23-26`). The runner never reads a line starting with `[` as a PASS/FAIL verdict (`runner.gd:42-45`); engine errors reach it through its logger, not through printed lines.
- **`scripts/core/game.gd`:** `_init()` only adds the Clock and connects a signal. Disk access happens in `boot()`, which World calls only as the current scene. So D4's `--main-pack` listing, which instances the pack's autoloads, has no side effects.
- **`tests/runner.tscn` / `run_tests.sh`:**
  - The runner exits non-zero on any `FAIL` or engine error. `run_tests.sh` uses that exit code (`rc`).
  - `export.sh` runs `smoke_rooms` the same way, and keeps `run_tests.sh` unchanged.
  - `smoke_rooms` takes about 12 s; the full suite takes about 122 s (measured at baseline).
- **`project.godot`:**
  - `run/main_scene` is `world.tscn`, and the renderer is `gl_compatibility`.
  - It has no `config/version`, and `Game` is the only autoload.
  - `dev_overlay` is bound in every build (ledger, owner 1.34).
  - **Don't touch it.**
- **`rooms/`:** `rooms/l1/m1_shaft.txt` and `rooms/dev/perf_worst.txt`. Test rooms are under `tests/rooms/`. No room sits directly in `rooms/`.

### Decisions

**D1: The web templates (decided by sonlm, 2026-11-19: the full download, checked by SHA-512).** The server has only the Linux and Windows 4.7.2 templates (`~/.local/share/godot/export_templates/4.7.2.stable/`: `linux_*`, `windows_*`, `version.txt` = `4.7.2.stable`). A Web export fails with `No export template found at the expected path: …/web_nothreads_release.zip`.
- **The procedure:**
  1. Download the official `Godot_v4.7.2-stable_export_templates.tpz` (1,281,349,702 bytes) from https://github.com/godotengine/godot/releases/download/4.7.2-stable/.
  2. Check its SHA-512 against `SHA512-SUMS.txt` from the same release: `ca4d71c4…ccb84079`. The full hash is under "Latest tech notes".
  3. Extract only the two zips with `unzip -j <tpz> 'templates/web_nothreads_release.zip' 'templates/web_nothreads_debug.zip' -d ~/.local/share/godot/export_templates/4.7.2.stable/`.
  4. Delete the `.tpz`.
- **Not chosen:**
  - Fetching only the two zips by HTTP range requests on the same archive (their CRC32s match its central directory: release `0x795d38e9`, debug `0x964423d9`). Faster, but checked by a CRC rather than a SHA-512.
  - sonlm copies them from the laptop.
- The same procedure becomes the template step in `docs/build.md`'s upgrade checklist.

**D2: The presets.**
- **A minimal hand-written file works** (probed with Linux and Windows presets; the research probed Web too). Every `[preset.N]` needs `name`, `platform`, `export_filter`, `include_filter` and `exclude_filter`.
- **Every `[preset.N.options]` section needs at least one key.** A missing or empty one prints `ERROR: Cannot get keys from nonexistent section` and still exits 0.
- **Presets are numbered from 0 with no gaps**, because loading stops at the first missing number.
- **4.7 moved "runnable"** into a `[runnable_presets]` section. Leave it out; nothing here is a one-click deploy.
- `script_export_mode` defaults to 2: binary tokens, so scripts ship as `.gdc` plus `.gd.remap` and no source. Keep the default.
- **The file:**
  ```ini
  [preset.0]

  name="Windows"
  platform="Windows Desktop"
  export_filter="all_resources"
  include_filter="rooms/*.txt"
  exclude_filter="rooms/dev/*, tests/*, scripts/dev/*"
  export_path=""

  [preset.0.options]

  binary_format/embed_pck=false
  binary_format/architecture="x86_64"

  [preset.1]

  name="Linux"
  platform="Linux"
  export_filter="all_resources"
  include_filter="rooms/*.txt"
  exclude_filter="rooms/dev/*, tests/*, scripts/dev/*"
  export_path=""

  [preset.1.options]

  binary_format/embed_pck=false
  binary_format/architecture="x86_64"

  [preset.2]

  name="Web"
  platform="Web"
  export_filter="all_resources"
  include_filter="rooms/*.txt"
  exclude_filter="rooms/dev/*, tests/*, scripts/dev/*"
  export_path=""

  [preset.2.options]

  variant/extensions_support=false
  variant/thread_support=false
  progressive_web_app/enabled=false

  [preset.3]

  name="Web debug"
  platform="Web"
  export_filter="all_resources"
  include_filter="rooms/*.txt"
  exclude_filter="tests/*"
  export_path=""

  [preset.3.options]

  variant/extensions_support=false
  variant/thread_support=false
  progressive_web_app/enabled=false
  ```
  - Other options keep their 4.7.2 defaults:
    - web: `html/canvas_resize_policy=2` (Adaptive), `html/focus_canvas_on_start=true`, `html/export_icon=true`, `vram_texture_compression/for_desktop=true`;
    - Windows: `application/modify_resources=true`.
  - Story 1.14 may set web display options.
  - A laptop editor that opens Project → Export rewrites the file with every key. That is fine as long as the test still passes; commit it only if the diff holds no machine path.
- **How the filters match** (ref: `editor/export/editor_export_platform.cpp:691-756`, `String::matchn`; verified):
  - Patterns are comma-separated and trimmed.
  - Each pattern is tested against both `res://path` and `path`.
  - Matching is case-insensitive and starts at the beginning of the path.
  - `*` crosses `/`, and `**` is the same as `*`. So `rooms/**/*.txt` would skip a room placed directly in `rooms/`, while `rooms/*.txt` takes every depth and never matches `tests/rooms/…`.
  - Include runs first and exclude second, so exclude wins.
  - Folders starting with `.` and folders holding a `.gdignore` are skipped.
- **Record the deviation:** the epic and architecture text say `rooms/**/*.txt` for the export filter (D11 corrects exactly those mentions).
- **`tests/test_export_presets.gd`** (unit, extends `Node`, runs through the runner):
  - It reads `res://export_presets.cfg` with `ConfigFile`.
  - **Always pass a default to `get_value()`, and use `has_section()` / `has_section_key()`.** A `get_value()` with no default on a missing key prints an engine `ERROR`, which fails the runner; that is why project-context prefers `JSON.new().parse()` for JSON.
  - It checks:
    - four presets, `preset.0`–`preset.3` and no `preset.4`, with the names and platforms of AC1;
    - `export_filter` is `all_resources`;
    - `include_filter` holds `rooms/*.txt`;
    - the exclude lists are AC1's sets, compared as trimmed sets;
    - the web options are `false` and the PC `embed_pck` is `false`;
    - every `[preset.N.options]` section exists with at least one key (D2: a missing one prints `ERROR`, and the export still exits 0);
    - there is no non-empty `custom_template/*`, and no `export_path` for which `is_absolute_path()` is true (`C:/…` from a Windows editor counts).
  - **Filter semantics, with the real matcher:**
    1. Walk `res://rooms/`, `res://tests/` and `res://scripts/dev/` with `DirAccess`, skipping dot folders. **First assert the walk found its sentinels:** `rooms/l1/m1_shaft.txt`, `rooms/dev/perf_worst.txt`, `scripts/dev/dev_tools.gd` and `tests/runner.gd`. An empty walk would pass every check vacuously (the house pattern: `test_lint.gd`'s `SENTINELS`).
    2. For each preset, model the exporter with `path.matchn(pattern)`, tested on both the `res://` and plain forms. The rule differs by kind:
       - a non-resource file (a room `.txt`) is in when an include pattern matches;
       - a script or scene (`.gd`, `.tscn`) is in through `all_resources`;
       - either is out when an exclude pattern matches;
       - leave `.gd.uid` and `.import` files out of the model, since the engine handles them itself.
    3. Assert:
       - every `rooms/**.txt` outside `rooms/dev/` is in every preset;
       - every `rooms/dev/*.txt` is in `Web debug` only;
       - no `tests/**.gd`, `tests/**.tscn` or `tests/**.txt` is in any preset;
       - every `scripts/dev/*.gd` is out of every release preset and in `Web debug`.
  - The test's `matchn` model must agree with the real PCK listings in AC3. Task 11 compares them once and records the result.

**D3: The version and the output layout (decided by sonlm, 2026-11-19: date plus commit).**
- **The rule:** `<version>` = `$(date +%Y%m%d)-$(git rev-parse --short=7 HEAD)`, plus `-dirty` when `git status --porcelain` is not empty.
  - It sorts by date and points at its commit.
  - It needs no manual bump.
  - It is computed **before** the export, which can create `.godot/` and `.uid` files.
- **Not chosen:** the short SHA only, or an `application/config/version` in `project.godot`, bumped by hand.
- The playtest records' "build version" (epics Playtest rules) is this string.
- **Layout:**
  ```
  builds/<version>/
    windows/unbroken_chain.exe, unbroken_chain.pck
    linux/unbroken_chain.x86_64, unbroken_chain.pck
    web/index.html, index.js, index.wasm, index.pck, index.audio.worklet.js, index.audio.position.worklet.js, index.png, index.icon.png, index.apple-touch-icon.png
    web_debug/(the same names)
    logs/import.log, content.log, export_{windows,linux,web,web_debug}.log, pck_{windows,linux,web,web_debug}.txt, boot_linux.log, web_smoke.log, summary.txt
  ```
  - The web output must be named `index.html`. Its base name names every web file, and itch.io wants `index.html` at the zip's top level.
  - `summary.txt` holds the end line, the sizes and the PCK file counts.

**D4: How a PCK is listed.**
- **`tools/pck_list.gd`:**
  - an `extends SceneTree` script;
  - in `_initialize()` it walks `res://` with `DirAccess`, `include_hidden = true`, prints one `res://…` path per line, then calls `quit()`;
  - it lives outside `game/`, so it is never exported or linted (it may `print`).
- **Run it as** `godot --headless --main-pack <pck> -s "$ROOT/tools/pck_list.gd"`, with an absolute path; a relative one resolves inside the pack.
- **Probed on 4.7.2:**
  - It lists exactly the files the export's own log stores (74 in a release PCK, 81 in a debug one, no difference).
  - The release listing has no `rooms/dev/`, `scripts/dev/` or `tests/` paths. The debug listing has `rooms/dev/perf_worst.txt` and `scripts/dev/dev_tools.gdc` / `.gd.remap`.
  - The release listing has `rooms/l1/m1_shaft.txt`.
- **Caveat:** `--script` still instances the pack's autoloads. `Game._init()` only builds the Clock, and disk access is in `boot()` (World only), so the listing touches nothing. A future autoload must keep disk and network out of `_init()` / `_ready()`. Note this in `docs/build.md`.
- **Rejected:**
  - *Parsing the export log's `Storing File:` lines:* that is progress output, not a contract.
  - *A Python reader:* the format is undocumented, and PCK v4 is new in 4.7 (v3 in 4.5–4.6), so it would break silently on an engine upgrade. The engine reads its own packs in any version.
- **`export.sh` checks the paths by prefix** (`res://scripts/dev/`), not by extension: scripts ship as `.gdc` plus `.gd.remap`.
- **The listing starts with the engine banner** and a blank line. Keep only lines matching `^res://` for the checks and the file counts.
- **The web PCK is not probed yet** (the web templates were missing). In Task 5, list `web/index.pck` once before relying on it, and record the count.

**D5: What proves a release build boots.**
- **What each build prints** (probed: Linux exports of this project; research: a web export of a probe project):
  - A Linux release build run headless prints **nothing**, not even the engine banner. A release web build prints the banner, `Godot Engine v4.7.2.stable.official.ed1daf0bf …`.
  - **Parse and load errors print in release**, and runtime script errors do not:
    - A `world.gd` that preloads DevTools, exported release, prints `SCRIPT ERROR: Parse Error: Preload file "res://scripts/dev/dev_tools.gd" does not exist.` and `ERROR: Failed to load script "res://scripts/world/world.gd" with error "Parse error".`, while the export itself exits 0 with no error.
    - The VM's runtime error report is debug-only (`modules/gdscript/gdscript_vm.cpp`). In the research's runs, a release web build skipped a null call silently, and a native Linux release build segfaulted on it.
- **So:**
  - **Linux release:** `timeout 5 builds/<v>/linux/unbroken_chain.x86_64 --headless`. Pass when the exit code is 124 (still running at 5 s: no crash and no early quit) and the output has no `ERROR` or `SCRIPT ERROR` line.
    - It runs with the game's real `user://` on the server, and `Game.boot()` may write a default `settings.json` there. That is harmless on the server: tests use temp folders.
  - **Web release:** AC6's boot-only check. The banner, `#status` removed and `#status-notice` empty, then 5 s with no `console.error`.
  - **Web debug:** `SMOKE boot ok` plus no `console.error` is the strong check: debug builds print runtime `SCRIPT ERROR`s.
- `world.gd`'s guarded line stays exactly as it is. The `dev_ref` lint protects it statically, and these checks protect it at runtime.

**D6: The size measure.**
- **The numbers:**
  - NFR5 says "download under 30 MB".
  - A 4.7.2 web release folder is 39.85 MB raw, of which `index.wasm` is 39,514,754 bytes, and 10.2 MB zipped (research, empty project). This project adds well under 1 MB of PCK.
  - itch.io's CDN gzips `html`, `js`, `wasm` and `pck`, so the transfer is about 10 MB.
- **The measure:** the sum over `web/*` of `gzip -9 -c "$f" | wc -c`, which is the download.
  - A raw measure could never pass without the architecture's plan B (a custom web template with 3D disabled), a template build nobody needs at 10 MB.
- **Decided by sonlm, 2026-11-19:** NFR5's "download" is the compressed size.
- `export.sh` prints both: `web download 10.4 MB (gzip; raw 40.3 MB)` (example numbers, never record them as measured).
- The limit is `WEB_DOWNLOAD_MAX_BYTES=30000000` in `export.sh`, citing NFR5.

**D7: Playwright.**
- **The pin:** exactly `@playwright/test@1.65.1`, the latest stable (2026-11-13). It pins `chromium-headless-shell` revision 1255 (Chrome for Testing 159.0.8154.6).
- **Node 24.14 is supported:** Playwright 1.62+ requires Node ≥ 20 and lists 22, 24 and 26.
- **Install** with `npx playwright install --only-shell --no-remove chromium`:
  - `--only-shell` takes the headless shell only, which is all a headless run uses (Playwright 1.57+ runs headless on Chrome for Testing's `chrome-headless-shell`);
  - `--no-remove` (1.63+) stops the install from deleting revision 1217, which the Playwright MCP plugin on this server still uses.
- **WebGL works headless with no flags:**
  - Playwright adds `--enable-unsafe-swiftshader` to every Chromium launch (headless runs also get `--mute-audio`);
  - verified on this server with the cached shell 1217: WebGL2 on `ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero)…))`.
  - So add no launch args. If 1255 behaves differently, record it and add only the flag that fixes it.
- **The test file `smoke.spec.js`:**
  - One `test.describe` per build, using `@playwright/test`'s `test` / `expect`.
  - **Collect** `page.on('console')` as `{type, text}` and `page.on('pageerror')`.
  - **Register the `console` and `pageerror` listeners before `page.goto()`.**
  - **Wait for:**
    - the `Godot Engine v4.7.2.stable` line;
    - `#status` detached (`page.locator('#status').waitFor({state: 'detached'})`);
    - for debug, `SMOKE boot ok`.

    Use a 60 s budget per page. The research's empty project booted in 2–4 s headless.
  - **Fail fast on a boot failure.** `#status-notice` sits inside `#status`, so it is gone after a good boot, and a failed boot fills it. Race "`#status` detached" against "`#status-notice` has text", and fail at once with that text instead of a 60 s timeout.
  - Wait on the collected messages with `expect.poll`, never `waitForEvent` after `goto` (the line may already have arrived).
  - **Assert:**
    - no `pageerror`;
    - no `type === 'error'` message outside `ALLOWED_CONSOLE_ERRORS` (exact regexes, each with a comment giving its reason; start empty);
    - `#status-notice` empty or absent.
  - **Godot's console output:** it prints each line as its own console message. `print` goes to `console.log`. `push_warning` (`WARNING: …`), `push_error` (`ERROR: …`), `printerr` and `SCRIPT ERROR` all go to `console.error`, each followed by `   at: …` lines; Godot never uses `console.warn`.
  - **Chromium's own `warning` messages** (for example `GL Driver Message … GPU stall due to ReadPixels` under SwiftShader) are ignored but kept in the attached log.
  - **On failure,** attach the whole console to the report, so `logs/web_smoke.log` shows it.
- **`playwright.config.js`:**
  - `testDir: '.'`, `workers: 1`, `retries: 0`, `reporter: 'line'`;
  - `timeout: 150_000` and `expect: { timeout: 60_000 }`. Playwright's 30 s default test timeout would otherwise cut the 60 s per-page budget;
  - `use: { headless: true, baseURL: 'http://127.0.0.1:' + PORT }`;
  - one project, `chromium`, with no `channel`: the shell-only install has no full Chromium;
  - `webServer: { command: 'node serve.js', url: 'http://127.0.0.1:' + PORT + '/web/index.html', reuseExistingServer: false, env: { BUILD_DIR, PORT } }`. A `/` that returns 404 would hang the wait.
  - `PORT` defaults to `8061`, and `export.sh` uses 8061. That leaves 8060 for the laptop tunnel (D8), so a build never fails because a tunnel server is up.

  `BUILD_DIR` is required: fail fast with a clear message when it is unset or has no `web/` and `web_debug/`.

**D8: The static server.**
- **`tools/web_smoke/serve.js`:** Node's built-in `http`, `fs` and `path` only.
  - It serves `BUILD_DIR` on `127.0.0.1:${PORT:-8060}`, so `/web/…` and `/web_debug/…` are both reachable.
  - MIME types: `.html` `text/html`, `.js` `text/javascript`, `.wasm` `application/wasm` (needed for streaming compilation), `.pck` `application/octet-stream`, `.png` `image/png`.
  - It drops the query string first: `decodeURIComponent(new URL(req.url, 'http://x').pathname)`. Otherwise `/web_debug/index.html?room=perf_worst` is a 404.
  - It rejects any resolved path outside `BUILD_DIR` (`..`), and answers 404 for anything missing.
- **No COOP/COEP headers:** a single-threaded build needs none. Godot's shell checks only WebGL2, Fetch and a secure context, and `127.0.0.1` is secure.
- **Why not `python3 -m http.server`:** it knows `.wasm` but not `.pck`, and a second runtime adds nothing.
- **Laptop viewing** goes through the same script, for 1.15's browser runs (`docs/build.md`):
  1. On the server: `node tools/web_smoke/serve.js` with `BUILD_DIR=builds/<v> PORT=8060`.
  2. On the laptop: `ssh -L 8060:127.0.0.1:8060 <server>`.
  3. Open `http://localhost:8060/web_debug/index.html?room=perf_worst&perf` in the laptop browser.

  `localhost` on the laptop is a secure context. A LAN IP over plain HTTP would fail Godot's secure-context check.

**D9: The boot marker.**
- **In `dev_tools.gd`:**
  - inside the existing `if get_tree().current_scene == _world:` branch of `_ready()`, add `_world.room_entered.connect(_on_first_room, CONNECT_ONE_SHOT)`;
  - `_on_first_room(_id: StringName)` calls `Log.info(Log.ROOM, "SMOKE boot ok")`;
  - a method, not a lambda (the house rule: a connection drops with its object).
- **Why the first `room_entered`:**
  - it fires at the end of World's first `_swap_room()`, after the room is built and the player spawned, still inside World's `_ready()`;
  - a broken room or player script means no marker, or a `SCRIPT ERROR` before it;
  - a bad `--room` falls back to the start room and still prints it.
- **Where it prints:** every real debug run (editor F5, a desktop debug export, the web debug build). That is one console line. Tests never print it, because they are not the current scene.
- **1.39** adds `SMOKE save ok` the same way.
- **The test, `smoke_dev_tools` `test_smoke_marker`:**
  - Give smoke_dev_tools' `Logger` a `_log_message` capture for `message.begins_with("[room] SMOKE ")` only, stored with `trim_suffix("\n")`, plus a `take_markers()` that returns the buffer and clears it. smoke_perf's `Warnings._log_message` shows the pattern, including the mutex (logger callbacks can come from other threads).
    - Match the prefix, not "contains SMOKE": the logger also receives the test's own `ok …` lines and its final `SMOKE PASS`.
  - `test_real_tokens` (which runs earlier) now prints one marker too. Call `take_markers()` right before each build in `test_smoke_marker`, and optionally assert that one marker in `test_real_tokens`.
  - (a) `_build([])`, a test World: two frames pass and no `SMOKE` line appears;
  - (b) a real-run World, as `test_real_tokens` builds it: exactly one line, `[room] SMOKE boot ok`, and `_room()` is not null when it arrives;
  - (c) a respawn in the real-run World (`die()`, then wait for the second spawn) prints no second marker. Connect `player_spawned` before `add_child`, as `_build()` does (`smoke_dev_tools.gd:121`).

**D10: The foreign-parameter ledger item.**
- **It closes as not triggered.** The item asked to "apply only the `ARGS` keys from the URL … if either adds its own query parameter".
- **Why nothing adds one:**
  - `serve.js` and the Playwright test add none;
  - Godot's shell adds none;
  - itch.io's embed is a host page around the build, and its "click to play" is an itch frame setting. No foreign parameter was observed.
- **The check stays:** AC6 fails on any `WARNING: DevTools:` line, so a harness that starts adding one fails the smoke instead of hiding it.
- **What stays as it is:** 1.11 AC2's warning on an unknown arg, which is how a mistyped `?rom=` is noticed. No code change.
- **The closing line:** `→ **Closed (Story 1.13): not triggered — the web smoke (tools/web_smoke/) passes only ARGS keys and fails on any "WARNING: DevTools:" line; Godot's shell and serve.js add no query parameters.**`

**D11: Docs, the upgrade checklist and the ledger.**
- **New `docs/build.md`:**
  - One-time server setup: the templates by D1, `cd tools/web_smoke && npm ci && npx playwright install --only-shell --no-remove chromium`, Node 24.
  - `tools/export.sh` and what each step checks.
  - The layout, the version string and the size measure.
  - Running the smoke alone, from the repo root: `B="$PWD/builds/<v>"; (cd tools/web_smoke && BUILD_DIR="$B" npx playwright test)`.
  - Playing builds on the laptop: rsync a desktop folder, or tunnel the web build (D8).
  - itch.io:
    - upload `web/` as a zip with `index.html` at its top level;
    - embed at 960 × 540;
    - leave "SharedArrayBuffer support" off: a non-threaded build doesn't need it, and the setting changes the origin, which loses saves;
    - limits are 1,000 files, 500 MB extracted and 200 MB per file.
  - **The engine upgrade checklist (AR7)**, for 4.7.x maintenance only:
    1. update the editor and the templates on the laptop and the server together (templates by D1's procedure, with the new version's SHA-512);
    2. re-import;
    3. `run_tests.sh` green;
    4. `tools/export.sh` green, which is the web smoke;
    5. a manual web look on the laptop;
    6. commit the changed `.import` files.

    Add one line: a PCK format change (v4 in 4.7) needs nothing here, because `pck_list.gd` uses the engine's own reader.
- **Update** every line the sweep found (see "Docs lines to update").
- **`project-context.md`:**
  - add a Story 1.13 sentence to Current State;
  - in Platform & Build Rules, the export include filter `rooms/**/*.txt` becomes `rooms/*.txt` (`*` crosses `/`; see the next bullet's list);
  - add: "A release web build prints parse and load errors but no runtime script errors, so the debug web smoke is the runtime check";
  - Last Updated.
- **`game-architecture.md`:**
  - Build and Export as built: the four preset names, the release checks (PCK listing, Linux headless boot, web boot-only), the gzip size measure, the layout and version;
  - the Debug Tools "Smoke markers" row: `[room] SMOKE boot ok` on the first `room_entered`, real runs only;
  - Setup Commands: `--only-shell --no-remove`;
  - the Directory Structure `tools/` lines: `pck_list.gd`, `web_smoke/serve.js`, `smoke.spec.js`, `playwright.config.js`;
- **Correct the export include filter only where it describes the preset:**
  - `epics.md:284` (AR51) and `:1662` (Story 1.13 AC);
  - `game-architecture.md:693` (the `export_presets.cfg` line in Directory Structure);
  - project-context's Platform & Build Rules.

  **Leave every `rooms/**/*.txt` that describes `smoke_rooms`' walk unchanged,** because there it is a glob in the shell sense and correct: `game-architecture.md:1159` and `:1179`, project-context's Story 1.10 sentence, `docs/rooms.md:101`, `development-guide.md:106`, `docs/architecture.md:205`. No blanket replace.
- **`epics.md` AR51** also adds `scripts/dev/*` to the release exclusions (the AC, project-context and 7.15 already list it).
- **Ledger:**
  - Close the 1.11 item (D10).
  - Add, under "Deferred from: dev of 1-13-export-pipeline-and-web-boot-smoke.md (<date>)":
    - **The Windows build is never booted on the server.** `tools/export.sh` exports and PCK-checks it, but the server has no Windows or wine to run it. Its PCK comes from the same filters as Linux's (byte-identical in the probe).
    - Owner line: `→ **Owner: Story 7.15** — it ships the final Windows build; boot it there on Windows (or under wine on the server) before the tester round.`

**D12: Content validation is `smoke_rooms`, not the whole suite.**
- AR52 asks to "validate every room file and string key".
- `smoke_rooms` validates every `rooms/**/*.txt` and runs the per-room guarantees, in about 12 s. The whole suite takes about 2 minutes, and its bot and feel checks are not content validation.
- `export.sh` runs `"$GODOT" --headless --path game res://tests/runner.tscn -- res://tests/smoke_rooms.gd` under `timeout 150`. It fails on a non-zero exit, and also on any `FAIL` or `ERROR` line as a second net.
- The runner's exit code is what `run_tests.sh` trusts. **Don't change `run_tests.sh`.**
- `docs/build.md` says: run `run_tests.sh` before building a build you will share.

**D13: The shape of `export.sh`.**
- `#!/usr/bin/env bash`, `set -euo pipefail`, and `ROOT="$(cd "$(dirname "$0")/.." && pwd)"`, then `cd "$ROOT"`.
- **Every path given to Godot is absolute:** `--export-release Linux "$ROOT/builds/$V/linux/unbroken_chain.x86_64"`, and likewise for `--main-pack` and `-s`. Godot resolves a relative export path against `game/` (the `--path`), not the shell's folder; the validator probed this on 4.7.2 (exit 1, "The given export path doesn't exist"). **Never create `game/builds/`.**
- `GODOT="${GODOT:-$(command -v godot || echo "$HOME/.local/bin/godot")}"`, as in `run_tests.sh`.
- `TEMPLATES="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.7.2.stable"`.
- **Steps in order**, each a `step <name>` banner:
  1. preflight;
  2. version;
  3. import;
  4. content;
  5. the four exports;
  6. PCK checks;
  7. size;
  8. Linux boot;
  9. web smoke;
  10. summary.
- **Errors:**
  - Each failure calls `fail "<step>: <reason>"`, which prints `== BUILD FAILED: …` and the log path, then exits 1.
  - **Scan logs from a file, never a pipe into `grep -q`.** Under `set -o pipefail`, `sed … | grep -q` can return 141 when `grep` quits early and `sed` gets SIGPIPE, which reads as "no match": a false green.
    1. Strip the colours into a file: `sed -r 's/\x1b\[[0-9;]*m//g' x.log > x.clean.log`.
    2. Then `grep -En '^FAIL|FAILED|SCRIPT ERROR|ERROR:' x.clean.log`, and fail when it prints anything.
  - Capture expected non-zero exits with `cmd || rc=$?`, so `set -e` doesn't end the script. The Linux boot's 124 is the main case.
  - The import step fails like an export: on a non-zero exit or any `ERROR:` line.
  - Every Godot call runs under `timeout` (600 s for exports, 150 s for content, 60 s for listings).
- No flags and no partial modes. Later stories add steps.
- **Never `rm -rf` anything outside `builds/<version>/`.** Guard the delete with a non-empty `<version>` check.

**D14: Red checks, and the human look.**
- **Where:** each red check runs in a detached worktree that carries **the current, uncommitted work**, never in the real tree. At red-check time HEAD holds none of this story.
  1. `git worktree add --detach <scratch>/wt HEAD`.
  2. Bring the changes in: `git diff HEAD --binary | git -C <scratch>/wt apply`, then copy the untracked files with `git ls-files -o --exclude-standard -z | rsync -a --from0 --files-from=- ./ <scratch>/wt/`. `.gitignore` already keeps `builds/`, `node_modules/` and `.godot/` out of that list.
  3. Apply the one red edit, run `npm ci` in `<scratch>/wt/tools/web_smoke`, and run the check.
  4. Remove the worktree with `git worktree remove --force`.
- **Each red check must fail at the named step, with its line recorded:**
  1. The `Linux` preset without `scripts/dev/*` in its exclude filter: `test_export_presets` FAILs, and `export.sh` stops at the PCK check naming `res://scripts/dev/`.
  2. The include filter back to `rooms/**/*.txt` with a scratch room `rooms/zz_top.txt`: `test_export_presets` FAILs ("every room in every preset").
  3. `Web debug` excluding `rooms/dev/*`: `test_export_presets` FAILs, and the PCK check fails on the missing `perf_worst.txt`.
  4. `world.gd` preloading DevTools (the D5 probe's edit): the Linux boot step fails on `SCRIPT ERROR`, and the release web smoke fails on `console.error`. Run the web smoke alone against that build to see the second.
  5. The marker removed from `dev_tools.gd`: `test_smoke_marker` FAILs, and the debug web smoke times out waiting for `SMOKE boot ok`.
  6. A broken room file (an unknown legend char in a copy of `m1_shaft.txt`): `export.sh` stops at content, before any export.
  7. `WEB_DOWNLOAD_MAX_BYTES=1000`, edited in the worktree's `export.sh` (there are no env overrides, by D13): the size step fails with both numbers.
  8. `TEMPLATES` edited in the worktree's `export.sh` to a folder without the web zips: preflight fails, naming both zips.
  9. An unknown `?foo=1` added to the debug `?room=` URL in the spec: the smoke fails on `WARNING: DevTools: unknown arg --foo` (this proves AC8's check).
- **The human look** (Task 12; a 5-minute look, not a playtest):
  - the Linux or Windows build runs on the laptop;
  - the web debug build boots through the tunnel, plain and with `?room=perf_worst`;
  - the release web build boots.

  Record the result as sonlm reports it.

### Verified facts (probes 2026-11-19, Godot 4.7.2.stable.official.ed1daf0bf on the server, unless marked "research")

- **Exports from hand-written presets:**
  - A Linux release, a Linux debug and a Windows release export each exit 0 with 0 `ERROR` lines.
  - The Windows export needs no rcedit or wine, and prints no warning.
  - Windows and Linux release PCKs from the same filters are byte-identical (99,476 bytes).
- **The output folder must exist.** A missing one gives `ERROR: Prepare Template: The given export path doesn't exist.` and exit 1. The web equivalent is `Target folder does not exist or is inaccessible` (research).
- **A wrong preset name** gives `ERROR: Invalid export preset name: …` plus the list of names, and exit 1 (research). **A missing `[preset.N.options]` section** prints `ERROR: Cannot get keys from nonexistent section` and exits 0 (research). So `export.sh` scans the logs as well as the exit codes.
- **`--export-*` implies `--import` since 4.3** (PR #90431). It can create `.godot/` and missing `.uid` files (research). `export.sh` imports first anyway, because the content step needs it.
- **Filter results:**
  - `include_filter="rooms/**/*.txt"` plus the release excludes put `rooms/l1/m1_shaft.txt` in the release PCK, and left `rooms/dev/`, `scripts/dev/` and `tests/` out.
  - The debug preset (excluding `tests/*`) kept `rooms/dev/perf_worst.txt` and `scripts/dev/*.gdc` / `.gd.remap`.
  - `rooms/**/*.txt` does not match `rooms/top.txt`, while `rooms/*.txt` matches both depths (research).
- **The listings:** `godot --headless --main-pack <pck> -s <abs>.gd` walking `res://` lists exactly the export log's `Storing File:` set: 74 release files, 81 debug files.
- **Boot output:**
  - A release Linux binary run headless prints nothing.
  - A debug one prints the banner and `[room] dev: room perf_worst@spawn`.
  - A release build whose `world.gd` preloads DevTools prints `SCRIPT ERROR: Parse Error: Preload file "res://scripts/dev/dev_tools.gd" does not exist.` and `ERROR: Failed to load script "res://scripts/world/world.gd" with error "Parse error".`, with an export that exited 0.
- **Headless Chromium** (cached Chrome for Testing 147, revision 1217, Playwright 1.59.1) gives WebGL2 with no flags. A Godot web build rendered there (research).
- **Research, Godot 4.7.2 web:**
  - The template names follow `web[_dlink][_nothreads]_{debug|release}.zip`.
  - `variant/thread_support=false` is the default.
  - The shell calls `engine.startGame()` on load, removes `#status` once the engine has started, and fills `#status-notice` on failure.
  - The release web banner prints unless `application/run/print_header=false`.
  - An empty-project release folder holds 9 files, 39.85 MB raw; `index.wasm` is 39,514,754 bytes; zipped it is 10.2 MB.
- **Timings:** `smoke_rooms` took 11.6 s and the full suite 121.8 s.

### Docs lines to update (from the sweep; recheck each before editing)

- **`docs/index.md`:**
  - `:6` Last Updated;
  - `:19` "Deployment: none yet";
  - `:31` "deployment guide" is not generated, so link `build.md` instead;
  - `:58-65` prerequisites and run;
  - `:94` "Build/deploy: no config yet".
- **`docs/development-guide.md`:**
  - `:12` the server row now includes exports;
  - `:17-23` the prerequisites table: add Node 24, Playwright and the templates; "No package manager…" is no longer true;
  - `:32` the 1.13 future tense becomes present;
  - `:155-163` add a "Make a build" row;
  - `:167-169` "## Build and Deploy" now points at `build.md`;
  - `:175` the ignored folders.
- **`docs/architecture.md`:**
  - `:3` scope;
  - `:33` the CI / export presets row;
  - `:126` the 1.13 tense;
  - `:226-228` Deployment;
  - `:259` the Builds gap row.
- **`docs/source-tree-analysis.md`:**
  - `:7`, `:59`;
  - `:96-102` the `tools/` tree, plus `game/export_presets.cfg`;
  - `:122`;
  - `:150-159` add a build entry point;
  - `:170-176` config files: `.gitignore` and "There is no `export_presets.cfg`".
- **`docs/component-inventory.md`:**
  - `:3` scope;
  - `:191`, `:195` DevTools: the marker;
  - add a `tools/` section: `export.sh`, `pck_list.gd`, `web_smoke/*`;
  - add the new test.
- **`docs/rooms.md`:**
  - `:108`, `:121`: the release exclusion is now real;
  - mention `rooms/*.txt`.
- **`docs/perf.md`:** `:39-44`, the web runs: the `builds/<v>/web_debug/` path through the tunnel (D8), linking `build.md`.
- **`docs/project-overview.md`:** `:50-54`, add a Build line.
- **`game/README.md`:**
  - `:5` debug exports;
  - `:33-54` add `test_export_presets` and the new `smoke_dev_tools` case to the test list.

### Project Structure Notes

- **New files:**
  - `game/export_presets.cfg`;
  - `game/tests/test_export_presets.gd` and its `.gd.uid`;
  - `tools/export.sh`;
  - `tools/pck_list.gd`;
  - `tools/web_smoke/package.json`, `package-lock.json`, `playwright.config.js`, `serve.js`, `smoke.spec.js`;
  - `docs/build.md`.
- **Updated files:**
  - `game/scripts/dev/dev_tools.gd` (the marker);
  - `game/tests/smoke_dev_tools.gd`;
  - `.gitignore`;
  - the docs listed above;
  - `_bmad-output/project-context.md`, `game-architecture.md`, `planning-artifacts/epics.md` (AR51);
  - `implementation-artifacts/deferred-work.md`.
- **Matches the architecture's tree:** `tools/export.sh` and `tools/web_smoke/` sit outside `game/`, so Godot never scans `node_modules`, and `builds/` is gitignored.
- **New against the tree:**
  - `tools/pck_list.gd` (D4);
  - `serve.js` and `playwright.config.js` beside `smoke.spec.js` (D7, D8).

  Add them to the architecture's Directory Structure.
- **Variance:** the include filter is `rooms/*.txt`, not `rooms/**/*.txt` (D2). Record it in the Deviations and fix the docs.

### Project Context Rules (that apply here)

- **Tests:**
  - `cd game && ./run_tests.sh` gives `== ALL GREEN`, and the runner fails on any `SCRIPT ERROR` or `ERROR:` line.
  - New tests match `tests/test_*.gd` / `tests/smoke_*.gd`.
  - Keep the `ok …` / `FAIL …` / `PASS` output format.
- **Code:**
  - No `print(` in game code: the marker goes through `Log.info`, and only `tools/pck_list.gd` (outside `game/`) prints.
  - Comments explain why, citing the design ("AR53: …", "probed 4.7.2: …").
  - **Nothing outside `dev/` and `tests/` references `dev/`.** `tools/` is outside `game/` and only names `scripts/dev/` as a path to check.
- **Saves and settings:** parse JSON with `JSON.new().parse()`. For `ConfigFile`, always pass `get_value()` a default (D2).
- **Platform & Build Rules:**
  - Builds come from the server.
  - Release presets exclude `rooms/dev/*`, `tests/*` and `scripts/dev/*`; debug presets keep `scripts/dev/`, because DevTools' `load()` has no null check.
  - Branch on `OS.has_feature("web")` only in the listed places; this story adds none.
- **Deferred items:** every one needs an owner. The agent assigns it as an indented `→ **Owner: …** — why` line, with no `(proposed)`, and names it in the report.
- **Feel:** headless tests can't judge feel. Report "export green; needs a look on the laptop", never "works in the browser" from headless runs.
- **Git:** commit `.gd.uid` files with their scripts. Never commit `builds/` or `node_modules/`.

### Previous story intelligence (1.11, 1.12 and their reviews)

- **Probe engine claims before acting on them.** In 1.12's review, three reviewers agreed that moving a node under an out-of-tree parent prints `ERROR`. A probe on 4.7.2 showed it doesn't (memory: probe-engine-claims-in-review). This story's engine facts are all probed or sourced; anything new, probe in the scratchpad first.
- **Red checks, run in scratch copies and recorded with their failing line,** are how every check here is shown to fail when it must. 1.11 and 1.12 each recorded 20 or more.
- **1.11:**
  - DevTools is debug-only and loaded by path string.
  - URL query tokens come through `JavaScriptBridge.eval`, which returns null off the web.
  - Args apply only when World is the current scene.
  - `_apply()` logs one `[room] dev: …` line.
  - The web query path first runs on web in this story.
- **1.12:**
  - `--room=perf_worst` alone is the plain room: chain 0, no stand-ins, no `dev: perf` line.
  - `?perf=5` would add the run, but the smoke doesn't need it.
  - D15's scratch-preset desktop export worked and was never committed: this story owns the file.
- **Baseline:** 20 tests, 1261 `ok` after `5ac0bd9` (overlay fix) and `21e15df`.
- **Records:** every story records deviations and the red checks in the Dev Agent Record. Review findings land in `### Review Findings` under Tasks.

### Git intelligence

- **Recent commits:**
  - `21e15df` docs: 1.12 laptop look passed; ledger items to 4.5 and 1.20
  - `5ac0bd9` fix: overlays 1 and 2 steady while falling
  - `acd3b92` docs: 1.12 review record, status done
  - `7097fd5` fix: 1.12 review fixes
  - `25da8d4` docs: 1.12 dev record
  - `4dfc340` feat: the light budget and the perf kit
- **The house pattern:** a `feat:` commit for code and tests, then a `docs:` commit for the docs and the story record.

### Latest tech notes

- **Godot 4.7.2:**
  - `export_presets.cfg` keys and defaults are in D2.
  - PCK format v4 (a new `dir_offset` header); research ref `core/io/file_access_pack.cpp`.
  - The templates archive: https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz (1,281,349,702 bytes). Its SHA-512 is `ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079`, as listed on 2026-11-19; still verify against the release's `SHA512-SUMS.txt`.
  - Inside it: `templates/web_nothreads_release.zip` is 10,245,903 bytes and `templates/web_nothreads_debug.zip` is 10,232,720 bytes.
- **Playwright:**
  - 1.65.1 is the latest stable (npm `latest`, 2026-11-13); `next` is 1.66 alpha.
  - Browser revisions: 1217 = 1.59.x, 1255 = 1.65.1.
  - Installing a version garbage-collects unused revisions unless `--no-remove` or `PLAYWRIGHT_SKIP_BROWSER_GC=1`.
  - Docs: https://playwright.dev/docs/browsers, https://playwright.dev/docs/release-notes.
- **itch.io HTML5** (https://itch.io/docs/creators/html5):
  - `index.html` at the top of the zip;
  - limits: 1,000 files, 500 MB extracted, 200 MB per file, 240-character paths;
  - the CDN gzips `wasm`, `js` and `pck`;
  - click to play is on by default (an itch frame option);
  - the SharedArrayBuffer option is not needed without threads, and changes the origin (saves lost).
- **Godot web docs:** https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html. COOP/COEP are needed only with threads; localhost is a secure context.

### Cross-story context (Epic 1 and beyond)

- **1.14:** DPR scale under a simulated `devicePixelRatio`, and keys that must not scroll the page. Both go into this smoke. It may set web display options in the presets; `test_export_presets` must keep passing.
- **1.15:** runs `docs/perf.md` in Chrome and Firefox against `builds/<v>/web_debug/` through the tunnel (D8), and records the Compatibility glow parity there.
- **1.17:** `export.sh` validates string keys, and copies `OFL.txt`, `LICENSES/` and `GODOT_LICENSES.txt` into each build folder.
- **1.21:** a saved respawn point beats `--room` (ledger). Playwright's fresh browser profile has no save, so the smoke is unaffected until 1.39.
- **1.33:** the click-to-play gate and the title. The smoke then clicks the canvas to pass the gate, and `?room=` must still go straight in (ledger, owner 1.33). Revisit where `SMOKE boot ok` fires if World stops being the first scene.
- **1.39:** `SMOKE save ok` and the reload check.
- **2.1:** keep `weaver_test.txt` and its `.tscn` overlay under `rooms/dev/`, so `rooms/dev/*` excludes both from release.
- **3.3:** the pogo pitch check on web.
- **3.9, 7.12:** the 30 MB check with the music.
- **5.7:** the flag and length validators join the content step.
- **7.13:** throttled load and memory on the release web build.
- **7.15:** the final builds, and the Windows boot (new ledger item).
- **1.41:** `export.sh` green for all three targets, including the web smoke, is part of closing E1.

### References

- `_bmad-output/planning-artifacts/epics.md`:
  - Story 1.13 (`:1650-1673`);
  - AR5, AR7, AR8, AR51–AR54 (`:202-290`);
  - NFR5–NFR7 (`:176-178`);
  - Stories 1.14, 1.15, 1.17, 1.33, 1.39, 1.41, 7.15 (per the sweep).
- `_bmad-output/game-architecture.md`:
  - Development Environment (`:40-81`);
  - Selected Engine, the upgrade checklist and the web smoke (`:203-251`);
  - Build and Export (`:461-466`);
  - Debug Tools (`:611-637`);
  - Enforcement (`:650-677`);
  - Directory Structure (`:687-810`).
- `_bmad-output/project-context.md`: Platform & Build Rules, Testing Rules, Code Organization Rules.
- GDD (`gdds/gdd-pixel_art_game-2026-11-10/gdd.md`): `:661` web build budget, `:665-670` platforms.
- UX `EXPERIENCE.md`: `:56`, `:210`, `:327` web gate, embed and HiDPI. These belong to later stories, so read them only for context.
- `_bmad-output/implementation-artifacts/`:
  - `deferred-work.md` `:140-141` (the foreign-parameter item);
  - `1-11-devtools-entry-args-and-overlays.md` (D2, D3, the forward notes at `:855`);
  - `1-12-worst-case-performance-scene.md` (D15, the cross-story notes at `:983-990`).
- Code:
  - `game/scripts/dev/dev_tools.gd` (`:64-73`, `:108-127`);
  - `game/scripts/world/world.gd` (`:43-60`, `:163`);
  - `game/scripts/core/log.gd`;
  - `game/scripts/core/game.gd` (`:40-44`);
  - `game/tests/smoke_dev_tools.gd` (`test_real_tokens`, `:230-249`);
  - `game/tests/smoke_perf.gd` (its `Warnings` logger);
  - `game/run_tests.sh`.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

- Ultimate context engine analysis completed: comprehensive developer guide created (create-story, 2026-11-19).

### File List
