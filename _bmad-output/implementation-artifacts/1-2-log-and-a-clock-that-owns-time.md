---
baseline_commit: 8961a22
---

# Story 1.2: Log and a Clock that owns time

Status: ready-for-dev

**Type:** dev (no human gate; done when every AC passes and `run_tests.sh` is green) · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP1 Foundations (1.1–1.15) · **Branch:** `feat/m2-e1`

## Story

As the developer,
I want one logger and one owner of `Engine.time_scale`,
so that hitstop and later slow-mo stack predictably and freeze with the pause.

## Acceptance Criteria

1. **Log** (AR55). `scripts/core/log.gd` is a static `Log` class: not an autoload, and it depends on nothing (no `Game`, no `Settings`).
   - `Log.info(cat, msg)` and `Log.debug(cat, msg)` print `[category] message`.
   - The categories are the constants `SAVE ROOM INPUT CLOCK LURKER WEAVER AUDIO UI`. An unknown category asserts.
   - `info` and `debug` are silent in release builds. `Log.enabled(cat)` guards hot paths.
2. **Game and Clock** (AR36, AR9). `scripts/core/game.gd` (no `class_name`) is registered as the project's first `[autoload]`, named `Game`. It holds a `clock` child (`scripts/core/clock.gd`).
   - While `Game.clock.request(&"hitstop", 0.05, 0.075)` is active, `Engine.time_scale` equals the product of all active requests, times an assist of 1.0.
   - The request ends after 0.075 s of real, unpaused time, timed with `create_timer(t, false, false, true)`.
   - While `SceneTree.paused` is true, requests don't count down.
   - Player death and the Clock's `_exit_tree` clear every request.
   - `Game` is the only autoload until `Audio` arrives in E3.
3. **Hitstop through the Clock** (FR4). `player.gd`'s four direct `Engine.time_scale` writes (lines 85, 270, 272 and 338) are replaced with Clock calls.
   - A pogo hit still freezes for 75 ms.
   - No script outside `clock.gd` writes `Engine.time_scale`.
   - Re-requesting an id that is already active refreshes its duration and never stacks with itself.
   - `tests/test_clock.gd` covers stacking of different ids, re-requesting the same id, real-time expiry, the pause freeze and clear-on-death.
4. **Scene runner** (R17). Each test is a script extending `Node`, run as a scene by `tests/runner.tscn`: `godot --headless --path . res://tests/runner.tscn -- res://tests/<test>.gd`. That way `Game`, `preload` and `class_name` work as they do in game code. Under `--script`, a test that touches `Game` fails to compile, and it can hang or exit 0 with no output.
   - The runner prints the test's `ok` / `FAIL` lines and `PASS` / `FAILED`, and exits non-zero on a failure.
   - It fails a test that prints no `PASS` line, or that runs longer than 120 s.
   - It also fails a test whose run printed any `SCRIPT ERROR` or `ERROR:` line (D3, decided by sonlm 2026-11-12). Story 1.9's shell check still covers errors outside the runner's lifetime.
5. **Ported tests.** `test_chain_state.gd`, `test_deferred_owners.gd`, `smoke_shaft.gd` and `screenshot.gd` move onto the runner in this story with no assertion changes. `run_tests.sh` runs its listed tests through it.

## Tasks / Subtasks

Run everything from `game/` and wrap every Godot run in `timeout`. Story 1.1 found that a missed path can hang a test instead of failing it.

- [ ] **Task 1: Baseline** (AC: 5)
  - [ ] Run `timeout 300 ./run_tests.sh` and expect:
    - `test_chain_state`: `ALL PASS (69 checks)`
    - `test_deferred_owners`: 20 `ok` lines and `PASS` (18 rule checks, 1 proposed owner, the summary)
    - `smoke_shaft`: 28 `ok` lines and `SMOKE PASS`
    - the last line: `== ALL GREEN`
  - [ ] Record the counts in the Debug Log. They are the regression bar for Task 2 and Task 7.
- [ ] **Task 2: The runner, and the four tests ported onto it** (AC: 4, 5). Do this **before** anything references `Game`. Once `player.gd` names `Game`, `--script` can't compile `smoke_shaft` (verified), so the suite has to be on the runner first.
  - [ ] Create `tests/runner.gd` and `tests/runner.tscn` per Dev Notes → *The scene runner*. Write the `.tscn` by hand, without `uid=`, like the M1 scenes. Don't save it in the editor.
  - [ ] Port the four tests with exactly the harness edits in Dev Notes → *Porting table*. Every `check(...)` call keeps its condition and message byte for byte.
  - [ ] In `run_tests.sh`, change `--script "res://tests/$t.gd"` to `res://tests/runner.tscn -- "res://tests/$t.gd"`. Change nothing else yet; Task 3 and Task 4 add their tests to the list.
  - [ ] Run `timeout 300 ./run_tests.sh`. It must show the Task 1 counts exactly, ending `== ALL GREEN`. **Checkpoint:** the runner works on unchanged M1 code.
  - [ ] Prove the runner's failure paths with throwaway tests named `tests/neg_*.gd`. That name is outside 1.9's `test_*` / `smoke_*` glob. Delete them, and their `.uid` files, before committing. Each case must exit 1:
    - a test with no `PASS` line
    - a runtime error before `PASS`
    - a missing file
    - a parse error
    - a runtime error inside a helper, after which `run()` still prints `PASS` (D3)
    - a hang (temporarily set `TIMEOUT` to 3 s, then set it back to 120)
- [ ] **Task 3: `Log`** (AC: 1)
  - [ ] Create `scripts/core/log.gd` per Dev Notes → *Log*.
  - [ ] Create `tests/test_log.gd`. It covers:
    - `format()` gives `[clock] msg`
    - every listed category is accepted
    - `enabled()` is false by default and true after `set_enabled([Log.CLOCK])`
    - `set_enabled([])` turns it off again
    - the test resets the enabled set before it finishes
    - the unknown-category `assert` is **not** unit-tested, because a failed assert would abort the test; code review checks it
  - [ ] Add `test_log` to the `run_tests.sh` list.
- [ ] **Task 4: `Game` and `Clock`** (AC: 2, 3)
  - [ ] Create `scripts/core/clock.gd` and `scripts/core/game.gd` per Dev Notes → *Clock* and *Game*.
  - [ ] Register the autoload by hand-editing `project.godot`: add `[autoload]` with `Game="*res://scripts/core/game.gd"` between `[application]` and `[display]`. That is the only `project.godot` change.
  - [ ] Create `tests/test_clock.gd` per Dev Notes → *test_clock*. Use a fresh `Clock` per case, so no request leaks into the next case.
  - [ ] Add `test_clock` to the `run_tests.sh` list.
- [ ] **Task 5: Hitstop through the Clock** (AC: 2, 3)
  - [ ] `player.gd` hitstop: `_freeze_frame()` becomes `Game.clock.request(&"hitstop", 0.05, hitstop)`. Keep its `if hitstop <= 0.0: return`. Drop the `await`: the Clock owns the timer now.
  - [ ] `player.gd:338`: in `die()`, `Engine.time_scale = 1.0` becomes `Game.clock.clear()`.
  - [ ] `player.gd:84-85`: delete `_exit_tree()`. M1 reset the time scale there because the hitstop timer lived in the player's own coroutine and died with it. Now the timer lives in the Clock, so a hitstop always ends by itself within 75 ms of real time. Death clears explicitly, and the Clock's own `_exit_tree` covers the rest.
  - [ ] `tests/smoke_shaft.gd:230`: `Engine.time_scale = 1.0` becomes `Game.clock.clear()`. It is setup, not an assertion.
  - [ ] Add the clear-on-death case to `test_clock.gd`. It instantiates `res://scenes/actors/player.tscn`, calls `Game.clock.request(&"hitstop", 0.05, 5.0)`, then `player.die()`, and expects `Engine.time_scale == 1.0`.
  - [ ] Check: `grep -rn "Engine.time_scale *=" scripts tests` finds only `scripts/core/clock.gd`. Reads such as `delta / maxf(Engine.time_scale, 0.001)` in `player.gd:116` stay.
- [ ] **Task 6: Docs, project-context and the deferred item** (fix paths and facts only; the docs get regenerated later)
  - [ ] `docs/development-guide.md`:
    - The run commands at lines 41–43 and 49 use the runner.
    - Rewrite the "Writing tests" section for the runner contract: `extends Node`, `func run()` that may `await`, `ok` / `FAIL` lines plus a final `PASS` / `FAILED` line, never `quit()`, and add the file to the `for t in …` list until 1.9's glob. Pure rules go in a new `tests/test_<subject>.gd`, never into `test_chain_state.gd`.
  - [ ] `docs/source-tree-analysis.md`:
    - In the tree block, add `scripts/core/{log,clock,game}.gd` and `tests/{runner.gd,runner.tscn,test_clock.gd,test_log.gd}`. The `test_chain_state.gd` line no longer says "SceneTree script".
    - Line 89 describes the runner instead of `--script`.
    - Line 108 says `Game` is the one autoload, instead of "No autoloads".
  - [ ] `docs/architecture.md`:
    - The table at lines 30 and 32: the test runner is `tests/runner.tscn`, and the autoload is `Game`.
    - Lines 128 and 198: hitstop is `Game.clock.request(&"hitstop", 0.05, 0.075)`, and death clears it.
  - [ ] `docs/project-overview.md:26`: tests are Node scripts run by `tests/runner.tscn`.
  - [ ] `docs/component-inventory.md`: add rows for `Game`, `Clock` and `Log` where the core scripts are listed, and for `test_clock.gd` / `test_log.gd` in the tests table.
  - [ ] Header comments: each ported test's `## Run:` line (and `screenshot.gd`'s usage line) names the runner command.
  - [ ] `_bmad-output/project-context.md` → "Current State vs Target": tests now run through `tests/runner.tscn`; `Game`, `clock.gd` and `log.gd` exist. Remove those three from the "don't exist yet" list. The rest of the paragraph stays as it is.
  - [ ] `_bmad-output/implementation-artifacts/deferred-work.md`: under "Dev guide 'Writing tests' is M1 guidance", add `  → **Closed (<date>): rewritten in Story 1.2.**`, and name it in your report.
- [ ] **Task 7: Verify** (AC: 1–5). Every grep below must print nothing.
  ```bash
  godot --headless --path . --import 2>&1 | grep -E 'SCRIPT ERROR|ERROR:'
  timeout 60 godot --headless --path . --quit-after 120 2>&1 | grep -E 'SCRIPT ERROR|ERROR:'   # main scene boot with the Game autoload
  for t in test_chain_state test_log test_clock test_deferred_owners smoke_shaft; do
    timeout 150 godot --headless --path . res://tests/runner.tscn -- res://tests/$t.gd 2>&1 | grep -E 'SCRIPT ERROR|ERROR:'; done
  grep -rn "Engine.time_scale *=" scripts tests | grep -v scripts/core/clock.gd
  timeout 300 ./run_tests.sh     # Task 1 counts + test_log + test_clock, ends "== ALL GREEN"
  timeout 120 xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/runner.tscn -- res://tests/screenshot.gd /tmp/shots   # exit 0, two PNGs
  ```
  - [ ] The runner now fails on errors (D3), but `run_tests.sh` still hides `ERROR:` lines printed outside the runner, at engine start or exit, until Story 1.9. That is why the raw greps above exist.
  - [ ] Check that every ported test's diff touches only the harness lines in the porting table: `git diff -U0 tests/` and look for any changed `check(` line. There must be none.
- [ ] **Task 8: Commit.** Use conventional prefixes, and leave `run_tests.sh` green at every commit. Suggested split:
  - `test:` the runner, the four ports and `run_tests.sh` (Task 2)
  - `feat:` `Log` (Task 3)
  - `feat:` `Game`, `Clock`, the hitstop and `test_clock` (Tasks 4–5)
  - `docs:` (Task 6)
  - Commit every new `.gd.uid` that the import generates beside its script.

## Dev Notes

### What this story is (and isn't)

It adds the first three foundations (AR4 order: `Log` → `Clock` → … → `Game`). `Game` arrives here holding only `clock`, so that the Clock has an owner. It also moves the test harness off `--script` before anything references `Game` (R17).

**Do not, in this story:**
- Add `settings`, `slot`, `dive`, `tuning`, `devices` or `reset_for_tests()` to `Game`. They arrive in 1.3 (Tuning) and 1.4 (state objects).
- Parse `--log=` arguments. DevTools does that in Story 1.11 and calls `Log.set_enabled()`. Add `Clock.set_assist()` in E7, not now; just keep the `_assist := 1.0` factor in the product.
- Make `run_tests.sh` glob, or fail on `ERROR:` lines. That is Story 1.9 (but see D3).
- Touch the other M1 patterns: `@export` tuning (1.3), `shaft.gd` statics (1.4), `Input` reads (1.8), the `randf_range` camera shake in `player.gd:119` (1.6), or the `get_nodes_in_group(...)[i]` target picks in the ported tests (1.5 ports them by position).
- Move `0.05` (the hitstop scale) or the `hitstop` duration into data. Story 1.3 decides which values move into `Tuning`.
- Re-save any scene in the editor, which adds `uid=` noise.

### Current state (read before changing)

- **`player.gd` time writes:**
  - Line 85: `_exit_tree()` sets `Engine.time_scale = 1.0`. The comment says it keeps the world from staying frozen if the player vanishes mid-hitstop.
  - Lines 268–272: `_freeze_frame()` sets 0.05, then `await get_tree().create_timer(hitstop, true, false, true).timeout`, then sets 1.0.
  - Line 338: `die()` sets 1.0.
  - Line 116: `_process` reads `delta / maxf(Engine.time_scale, 0.001)` for real-time juice. Leave it.
  - Hitstop is `@export var hitstop := 0.075` (line 32).
- **M1 behaviour differences the Clock introduces:**
  - The old timer was `process_always = true`. The Clock's is pausable, which is fine because nothing pauses in M1.
  - In M1, a second pogo within 75 ms was cut short by the first timer's reset to 1.0. The Clock refreshes instead. Smoke pogos are ~0.5 s apart, so smoke counts don't change.
- **`shaft.gd`:** its death flow reloads the scene only `if get_tree().current_scene == self`. Under the runner the current scene is the runner, so smoke tests never reload. The `Game` autoload survives reloads, and `die()` has already cleared the Clock by then. Its F3 `reload_current_scene()` is retired in 1.7.
- **Tests today:** all four are `extends SceneTree` and run with `--script`. `test_chain_state` prints only `FAIL: …` (through `printerr`) and `ALL PASS (69 checks)`. `screenshot.gd` reads `args[0]` as its output folder and prints no `PASS` line. `run_tests.sh` greps only `^(ok|FAIL)|PASS|FAILED`, so it hides engine errors.
- **`project.godot`** has no `[autoload]` section. The main scene is still `res://scenes/shaft.tscn`, which stays until 1.6.

### The scene runner (`tests/runner.gd` + `tests/runner.tscn`)

- **Scene:** a root `Node` named `Runner` with `runner.gd`. The hand-written tscn is verified to load:
  ```
  [gd_scene load_steps=2 format=3]

  [ext_resource type="Script" path="res://tests/runner.gd" id="1_runner"]

  [node name="Runner" type="Node"]
  script = ExtResource("1_runner")
  ```
- **Contract for tests** (document it in `runner.gd`'s header):
  - `extends Node` and implements `func run() -> void`, which may `await`.
  - Prints `ok …` / `FAIL …` lines and a final line containing `PASS` or `FAILED`.
  - Never calls `quit()`.
  - Extra arguments after the test path reach the test as `OS.get_cmdline_user_args()[1..]`; `screenshot.gd` uses this for its output folder.
- **How the runner sees output:** it can't capture stdout, so it registers a Godot `Logger` (`OS.add_logger()`, available in 4.7.2) that sees every `print` and `printerr`.
  - Compile the regexes once.
  - Logger callbacks can come from any thread, so guard its state with a `Mutex`.
  - A line that doesn't start with `ok` and contains the word `PASS` (`\bPASS\b`) marks a pass.
  - A line starting with `FAIL`, or containing the word `FAILED`, marks a failure.
  - `_log_error` counts every error whose type is not `ERROR_TYPE_WARNING`, which covers `SCRIPT ERROR`, `push_error` and engine `ERROR:` lines. Any count above 0 fails the test (D3). `push_warning` stays allowed, as the Error Handling rules use it for environment errors.
- **`_ready()` order:**
  1. `OS.add_logger(capture)`.
  2. Read the path from `OS.get_cmdline_user_args()[0]`. If `ResourceLoader.exists(path)` fails, or the script can't instantiate, or the instance isn't a `Node`, or it lacks `run`, finish FAILED with the reason.
  3. Start the watchdog: `get_tree().create_timer(120.0, true, false, true)`. With `process_always` and `ignore_time_scale`, it fires even while the test has paused the tree or frozen time (verified).
  4. `add_child(test)`, then `await test.run()`.
  5. Finish PASS only if the run completed, a PASS line was seen, no failure line was seen and no engine error was logged. Otherwise finish FAILED with the reason: `FAILED (runner: no PASS line)`, `FAILED (runner: N engine error(s))` or `FAILED (runner: no result after 120 s)`.
- **`_finish(ok, why)`:**
  - Guard it with a `_done` flag, because the watchdog and a late completion can both arrive.
  - Print the reason line, if any.
  - Call `OS.remove_logger(capture)`, then `get_tree().quit(0 if ok else 1)`.
  - On a pass the runner prints nothing extra; the test's own `PASS` line is the output.

### Porting table (harness edits only; verified in the prototype)

Every `## Run:` line becomes `## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/<file>.gd`.

| File | Edits |
|---|---|
| `test_chain_state.gd` | `extends SceneTree` → `extends Node`; the `## Run:` line → the runner command; `func _init()` → `func run()`; delete `quit(0)` and `quit(1)` (the `ALL PASS` / `FAILED of` prints stay) |
| `test_deferred_owners.gd` | the same four edits (its `## Run:` comment is line 7) |
| `smoke_shaft.gd` | `extends Node`; `## Run:` line; delete `_initialize()` (lines 13–14); `func _run()` → `func run()`; `await physics_frame` → `await get_tree().physics_frame`; `root.add_child(_shaft)` → `add_child(_shaft)` (×2); `get_nodes_in_group(` → `get_tree().get_nodes_in_group(` (×6); delete the `quit(...)` line; line 230 → `Game.clock.clear()` (Task 5) |
| `screenshot.gd` | `extends Node`; usage comment → `xvfb-run -a godot --path game --rendering-driver opengl3 res://tests/runner.tscn -- res://tests/screenshot.gd <out_dir>`; delete `_initialize()`; `func _run()` → `func run()`; `root.get_texture()` → `get_viewport().get_texture()`; `await process_frame` → `await get_tree().process_frame`; `args[0]` / `size() > 0` → `args[1]` / `size() > 1` (args[0] is now the test path); `root.add_child(shaft)` → `add_child(shaft)`; `get_nodes_in_group(` → `get_tree().get_nodes_in_group(`; `quit(0)` → `print("PASS")` (it is a helper, but the runner needs a verdict; a failed save already prints a `FAILED …` line) |

### Clock (`scripts/core/clock.gd`, `class_name Clock`, `extends Node`)

- **State:** `_requests: Dictionary`, mapping id → `{scale, serial}`, plus `_serial: int` and `_assist := 1.0`.
- **`request(id: StringName, scale: float, seconds: float)`:**
  - `assert(scale > 0.0 and seconds > 0.0)` and `assert(is_inside_tree())`.
  - Bump `_serial` and store `{scale, serial}` under `id`. This replaces any earlier request with that id, which is the refresh: the latest scale and duration win, and the id never multiplies with itself.
  - Start `get_tree().create_timer(seconds, false, false, true)` and connect its `timeout` with `CONNECT_ONE_SHOT` to `_on_expired.bind(id, serial)`.
  - Call `_apply()`.
  - Bind the **serial, not the timer**. A `SceneTreeTimer` can't be cancelled, so a refreshed request's old timer still fires, and the serial check makes it a no-op. Binding the timer to its own signal would also hold a reference to itself.
- **`_on_expired(id, serial)`:** erase the entry only if its stored serial matches, then call `_apply()`.
- **`clear()`:** empty `_requests`, then call `_apply()`. **`_exit_tree()`:** call `clear()`.
- **`is_active(id) -> bool`:** used by tests now and by the 1.11 overlay later.
- **`_apply()`:** `Engine.time_scale = _assist × product of every request's scale`. This is the **only** `Engine.time_scale =` in the codebase (the Story 1.9 lint).
- **Logging:** requests happen per pogo hit, which is a hot path, so log only inside `if Log.enabled(Log.CLOCK):`.
- **Pausable timers:** the architecture's Time Control says "the Clock's timers run with `PROCESS_MODE_ALWAYS`". AR36 superseded that: requests use `process_always = false`, so they pause with the tree. The Clock node's own `process_mode` doesn't matter, because `SceneTreeTimer`s belong to the tree, not the node.

### Game (`scripts/core/game.gd`, autoload, no `class_name`)

- `extends Node`.
- `var clock := Clock.new()`, then in `_init()`: `clock.name = "Clock"` and `add_child(clock)`. Adding a child before `Game` itself is in the tree works, and was verified.
- It holds refs only and no rules (AR11). Its header comment says that 1.3 and 1.4 add the remaining refs.

### Log (`scripts/core/log.gd`, `class_name Log`, static only)

- **Category constants:** `SAVE := &"save"`, `ROOM := &"room"`, `INPUT := &"input"`, `CLOCK := &"clock"`, `LURKER := &"lurker"`, `WEAVER := &"weaver"`, `AUDIO := &"audio"`, `UI := &"ui"`, plus `CATEGORIES` listing them. The output is lowercase, as in the architecture's example `[save] slot 2 written (4182 bytes)`.
- **`info(cat, msg)`:** checks the category, then prints `format(cat, msg)` when `OS.is_debug_build()`. Info lines are milestones, never hot paths.
- **`debug(cat, msg)`:** prints only when `enabled(cat)` is true.
- **`enabled(cat) -> bool`:** checks the category, then returns `OS.is_debug_build() and _debug_on.has(cat)`.
- **`set_enabled(cats: Array[StringName])`:** replaces the set and checks each category. DevTools calls it from `--log=` in 1.11.
- **`format(cat, msg) -> String`:** returns `"[%s] %s" % [cat, msg]`. It is pure, so tests can check it.
- **Category check:** `assert(cat in CATEGORIES, …)`. Release builds strip asserts, so a disabled `enabled()` costs one call plus one dictionary lookup.
- `log.gd` is the one place a bare `print(` is allowed (the 1.9 lint).

### test_clock (`tests/test_clock.gd`)

Use the same `check()` helper style, and end with a `PASS` / `FAILED (n)` line.

- **Waits:** wait in real time with `await get_tree().create_timer(s, true, false, true).timeout`. It must be `process_always`, so it still runs while the test has paused the tree.
- **Margins:** expiry is checked with wide margins (active at 0.03 s, gone by 0.15 s for a 0.075 s request), because headless frame timing jitters.
- **Cases** (each was verified in the prototype):
  - `Game.clock is Clock` and its parent is `Game`.
  - Different ids multiply: 0.5 × 0.2 = 0.1.
  - Hitstop 0.05 for 0.075 s is still active at 0.03 s of real time and gone, with scale 1.0, by 0.15 s. A game-time timer at ×0.05 would last 1.5 s, so this proves the request runs on real time.
  - A re-request at 0.06 s keeps the scale at 0.5 (no stacking) and is still active at 0.13 s (refreshed), then ends.
  - With the tree paused for 0.3 s of real time, a 0.1 s request is still active. After unpausing it ends. Unpause before the case finishes.
  - `remove_child(clock)` with an active request leaves the scale at 1.0 (`_exit_tree`).
  - Clear-on-death (Task 5).

### Verified on the server (Godot 4.7.2.stable, prototype in a scratch copy of `8961a22`, 2026-11-12)

- **APIs:** `Logger` (`_log_message`, `_log_error`), `OS.add_logger` / `remove_logger`, `SceneTree.create_timer(time, process_always, process_in_physics, ignore_time_scale)` and `Timer.ignore_time_scale` all exist.
- **The design above, runner first:**
  - `test_chain_state` gave `ALL PASS (69 checks)`, `smoke_shaft` gave 28 `ok` and `SMOKE PASS`, and `test_deferred_owners` gave `PASS`.
  - The Logger counted 0 engine errors, and the raw output had 0 `ERROR:` / `WARNING:` lines.
  - `--import` and a 120-frame main-scene boot with the `Game` autoload printed nothing.
  - `screenshot.gd` through the runner under `xvfb-run` exited 0 and rendered both PNGs.
- **Runner failure paths, all exit 1:**
  - a test with only `ok` lines → `FAILED (runner: no PASS line)`
  - a runtime error before `PASS`, sync or after an `await` → no `PASS` line
  - a parse error or a missing file → "cannot load test"
  - a test that pauses the tree, sets time to ×0.05 and never returns → the watchdog fired on time (with the 3 s test value)
- **Clock:**
  - 0.5 × 0.2 → 0.100.
  - Hitstop active at 0.03 s and gone by 0.15 s.
  - A re-request keeps 0.5 and extends the duration.
  - A paused request survives 0.3 s and ends after unpausing.
  - `remove_child` gives 1.0, and `player.die()` with a 5 s request gives 1.0.
- **R17 confirmed:** once `player.gd` names `Game`, `--script res://tests/smoke_shaft.gd` fails with `Compile Error: Identifier not found: Game`.
- **Why D3:** a runtime error inside a helper that `run()` calls aborts only that helper. `run()` carries on and prints `PASS`. The code review of 1.1 reproduced this with an out-of-bounds index. The prototype's Logger counted the error (`errors: 1`), which is the signal D3 now fails on. The 4 real tests logged 0 errors, so D3 doesn't break the regression bar.

### Decisions

- **D1, test verdict via `Logger`** (story author): tests keep their own `PASS` / `FAILED` lines, and the runner checks that it saw them. That literally implements "fails a test that prints no `PASS` line", and the ported output stays byte-identical. The alternative (`run()` returns a failure count and the runner prints `PASS`) would hide `test_chain_state`'s "69 checks" line.
- **D2, `player.gd` `_exit_tree` is deleted rather than rewritten** (story author): the reasoning is in Task 5. AC2's "`_exit_tree` clears" is the Clock's own `_exit_tree`, which is tested.
- **D3, the runner fails on engine errors** (decided by sonlm 2026-11-12, added to AC4 and to epics.md): the runner's `Logger` sees every `SCRIPT ERROR` / `ERROR:` through `_log_error`, so a test fails on any error type other than `ERROR_TYPE_WARNING`. This closes the "helper error, still `PASS`" hole from the first story that touches `Game`. Story 1.9 still adds its `run_tests.sh` check, for errors at engine start or exit, outside the runner's lifetime.

### Project Structure Notes

- New files:
  - `scripts/core/log.gd`, `clock.gd` and `game.gd`. `core/` is session plumbing with no gameplay rules, and depends only on `rules/`; `Clock` and `Log` reference no actor class (AR58).
  - `tests/runner.gd`, `tests/runner.tscn`, `tests/test_clock.gd` and `tests/test_log.gd`.
- `runner.gd` is a helper. It doesn't match `test_*` / `smoke_*`, so 1.9's glob won't run it as a test.
- Naming: `Clock` and `Log` are PascalCase `class_name`s. The autoload has none (AR9).

### Project Context Rules (that apply here)

- **Stack and versions:** Godot 4.7.2 and GDScript only. No addons, no `.tres`. Autoloads are `Game` and `Audio` only; this story adds `Game`.
- **Time:**
  - Only `Game.clock` writes `Engine.time_scale`. Requests multiply, ignore the time scale and pause with the tree.
  - Pause is `SceneTree.paused`.
  - Real-time visuals use `delta / Engine.time_scale` in `_process`.
- **Code and logging:**
  - No `print()` in game code (use `Log`). Tests keep their `ok` / `FAIL` + `PASS` / `FAILED` lines.
  - Programmer errors are `assert`s.
  - Never `free()`; use `queue_free()`.
  - Comments explain *why*, citing the design ("ADR-4", "R17", "FR4: 75 ms"), and never restate *what*.
- **Tests:**
  - Until 1.9's glob exists, add every new test file to the `for t in …` list.
  - Report "tests green". The hitstop path is feel-critical, so add "the pogo hitstop needs a quick feel check on the laptop (no change intended)" and never claim it feels the same.
  - Commit `.gd.uid` files with their scripts.

### Previous story intelligence (1.1 and its review)

- **From 1.1:**
  - Hand-edit paths and `.tscn` files, and never re-save in the editor (it adds `uid=` noise).
  - Wrap Godot runs in `timeout`.
  - `run_tests.sh` hides `ERROR:` lines, so grep the raw output.
  - On the laptop, re-run `--import` after pulling moved or new scripts, because the `class_name` cache goes stale. `docs/development-guide.md` now says so.
- **From the 1.1 review (`52f92b9`):**
  - A GDScript runtime error under `--script` aborts only the current function. The caller continues and can still print `PASS`, which is the D3 hole.
  - `FileAccess.get_file_as_string()` returns `""` on error; use `get_open_error()`.
  - The deferred item "Dev guide 'Writing tests' is M1 guidance" has **Owner (proposed): Story 1.2**, and Task 6 closes it.

### Git intelligence

`feat/m2-e1` holds, in order:
- `aaf5f22`: the 1.1 move.
- `9ecb68c`: the ledger owner test.
- `52f92b9`: its review fixes.
- `04f0924` and `8961a22`: story and status docs.

No game behaviour has changed since the M1 playtest, so Task 1's counts are M1's behaviour.

### Cross-story context (Epic 1, CP1)

- **1.3** moves `@export` tuning (including `hitstop`) into `Tuning`, read through `Game.tuning`.
- **1.4** adds the state objects and `Game.reset_for_tests()`.
- **1.6** makes `World` clear Clock requests on respawn.
- **1.8** adds real-time input buffers, so presses during hitstop are kept (NFR2).
- **1.9** adds the glob, fails on error lines, and lints `Engine.time_scale =` outside `clock.gd` and `print(` outside `log.gd`.
- **1.11** connects `--log=` to `Log.set_enabled()` and lists active Clock requests in an overlay.
- **E6** uses `request(&"slowmo", 0.3, 0.5)`. **E7** adds `set_assist()`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.2: Log and a Clock that owns time]
- [Source: _bmad-output/planning-artifacts/epics.md#Additional Requirements: AR4, AR9, AR11, AR36, AR47, AR55, AR58; R17]
- [Source: _bmad-output/game-architecture.md#Time Control, #Logging, #Error Handling (test runner rule), #State Management, ADR-4, #Directory Structure]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md:133 ("Each hit freezes the game for a 75 ms hitstop"), :658 (no input dropped during hitstop)]
- [Source: _bmad-output/project-context.md#Engine-Specific Rules, #Testing Rules, #Current State vs Target]
- [Source: _bmad-output/planning-artifacts/implementation-readiness-report-2026-11-12.md (F1 → R17)]
- [Source: _bmad-output/implementation-artifacts/1-1-move-m1-into-the-m2-folder-layout.md#Review Findings]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

- Story context created by gds-create-story on 2026-11-12. Ultimate context engine analysis completed - comprehensive developer guide created. The design was dry-run on Godot 4.7.2 in a scratch copy before writing (see "Verified on the server").

### File List
