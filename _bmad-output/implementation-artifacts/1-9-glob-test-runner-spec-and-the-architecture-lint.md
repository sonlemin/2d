---
baseline_commit: b901497
---
# Story 1.9: Glob test runner, Spec and the architecture lint

Status: done

**Type:** dev · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP1 Foundations (1.1–1.15) · **Branch:** `feat/m2-e1`

## Story

As the developer,
I want tests discovered by name and the architecture's rules enforced automatically,
so that no test silently stops running and the M2 patterns hold as the code grows.

## Acceptance Criteria

1. **Glob runner.** `game/run_tests.sh` runs every `tests/test_*.gd` and then every `tests/smoke_*.gd`, found by glob (no hand-kept list), each through `tests/runner.tscn` (Story 1.2). It:
   - fails a test with no `PASS` line or running longer than 120 s, and fails on any `SCRIPT ERROR` or `ERROR:` line (the runner already does all three; keep it);
   - keeps the `ok …` / `FAIL …` + `PASS` / `FAILED` format;
   - fails the run if the glob finds no tests;
   - ends with `== ALL GREEN` when everything passes.

   A new test file is picked up with no edit to `run_tests.sh`. (AR47; D1)
2. **Spec.** `game/tests/spec.gd` (no `class_name`; tests `preload` it) holds `TELEGRAPH_MIN := 0.75`, `BOT_MIN_CHAIN := 5`, `BASE_LIGHT := 40.0` and `NOTICE_MIN_RADIUS := 80.0`, each with a `## GDD …` citation. Every existing check of one of these guarantees compares against `Spec`, never against the tuning value under test:
   - the bot's chain;
   - the lurker telegraph, including with every `Gear.TABLE` row applied;
   - base light never noticed;
   - the notice floor.

   (AR49; D5, D6)
3. **Architecture lint.** `game/tests/test_lint.gd` scans every `.gd` under `game/scripts/` and fails on each rule in D3. Each hit prints `FAIL lint <file>:<line> <rule>`. The rules:
   - `Engine.time_scale =` outside `core/clock.gd`;
   - `Input.` (and event-based input) outside `actors/player_input.gd`, `core/devices.gd` and `ui/kit/`;
   - bare `print(` outside `core/log.gd`;
   - `.free()`;
   - `"/root/`;
   - `KEY_F` and other raw keycodes;
   - `randf` / `randi` outside camera shake;
   - `Node` / `Input` / `Engine` / `Game.` in `rules/`;
   - upper-layer class names in `core/`;
   - `DevTools` outside `dev/` and `tests/`;
   - a direct write to a `Game.settings` / `Game.slot` / `Game.dive` field.

   (AR48; D2, D3, D4)
4. **The lint is green on today's code, and every rule is proven.** The lint passes on the migrated code. For each rule, a sample-line test proves that it fires, that it stays silent on an allowed path, and that it stays silent when the match is only in a comment (and, for identifier rules, only in a string). (AR48; D4)
5. **The lint takes over the old ad-hoc checks.** The `rules/` purity scans in `test_state.gd` and `test_tuning.gd` and the `Input.` regex in `smoke_player_input.gd` are removed, because the lint covers them more strictly. `test_deferred_owners.gd` fails on a ledger written in a format it can't read, instead of passing it as "0 items". This closes four deferred items owned by 1.9. (D7, D8)
6. **Done means green.** `cd game && ./run_tests.sh` ends in `== ALL GREEN`. Each new check is red-checked (D9). Docs and `project-context.md` say how tests are found now. (D10)

## Tasks / Subtasks

- [x] **Task 1: Glob runner (AC: 1).**
  - [x] Rewrite the loop in `game/run_tests.sh` per D1. Keep the import step, the 150 s wall-clock `timeout` and the error-line grep.
  - [x] Red-check it with scratch files in `game/tests/`, removing each afterwards:
    - a `test_zz_probe.gd` that prints a `FAIL` line → the run fails without editing `run_tests.sh`;
    - a `smoke_zz_probe.gd` with only `ok` lines → `FAILED (runner: no PASS line)`;
    - an empty glob (point it at an empty folder) → the run fails.
  - [x] Confirm the green run lists the same 11 tests as before, plus `test_lint`.
- [x] **Task 2: Spec (AC: 2).**
  - [x] Add `game/tests/spec.gd` per D5.
  - [x] Switch the existing checks per D6: `smoke_shaft` (bot, telegraph, base light, the notice floor) and `test_tuning` (the telegraph floor with every `Gear.TABLE` row applied, and a probe table proving that check fires).
- [x] **Task 3: The lint (AC: 3, 4).**
  - [x] Add `game/tests/test_lint.gd` per D2–D4: a pure `lint_text()`, the rule table, the sample-line tests, and the scan of the real `scripts/` tree.
  - [x] Also check that every `const` in `spec.gd` carries a `## GDD` citation (D5).
  - [x] It must be green on today's code. If a rule hits real code, check whether the hit is a true violation. If it is, fix the code and record the fix. If it isn't, the rule is wrong: fix the rule. Never add an allow-list entry to get green.
- [x] **Task 4: Retire the ad-hoc checks (AC: 5).**
  - [x] Delete `_test_purity()` (and its `PURE` lists, if nothing else uses them) from `test_state.gd` and `test_tuning.gd`.
  - [x] Delete the `Input.` regex part of `test_sources()` in `smoke_player_input.gd`; keep its `SNUFF_HOLD` and `PlayerInput`-node checks.
  - [x] Add the ledger-format check to `test_deferred_owners.gd` per D8.
- [x] **Task 5: Docs and ledger (AC: 6).** Per D10.
  - [x] Close the four 1.9-owned items in `deferred-work.md` with `→ **Closed (Story 1.9): …**` lines.
- [x] **Task 6: Verify (AC: 6).**
  - [x] `./run_tests.sh` → `== ALL GREEN`.
  - [x] Run the D9 red checks and record each in the Debug Log.
  - [x] Every new `.gd.uid` is staged.
  - [x] No `ERROR:` lines in the raw output.
  - [x] Report "tests green"; no feel check is needed, because no gameplay changes.

### Review Findings

Code review 2026-11-18 (Blind Hunter, Edge Case Hunter, Acceptance Auditor). 0 decision, 20 patch, 0 defer, 2 dismissed (`keycode` firing on a project const named `KEY_*`: none exist, and the failure would be loud, not silent; a Spec citation on the line above: D5 puts it on the same line).

- [x] [Review][Patch] `strip()` ignores `\` escapes inside `"""` strings, and drops a single-quoted string continued with a trailing `\` onto the next line, so code after it is hidden (or string text is linted) [game/tests/test_lint.gd:99]
- [x] [Review][Patch] `time_scale` misses compound writes (`*=`, `+=`) and `Engine.set(&"time_scale", …)` [game/tests/test_lint.gd:28]
- [x] [Review][Patch] `state_write` misses nested fields and indexes, container mutators (`.append/.erase/.clear…`), `.set(`, and writes to `Game.tuning` internals; it also has no "quiet in a string" sample (AC4, D4(d)) [game/tests/test_lint.gd:69]
- [x] [Review][Patch] `random` misses `pick_random()`, `shuffle()`, `seed()`, `rand_from_seed()` and `@GlobalScope.randf()` [game/tests/test_lint.gd:50]
- [x] [Review][Patch] `print` misses `print_verbose`, `print_stack`, `print_tree*` [game/tests/test_lint.gd:37]
- [x] [Review][Patch] `free` misses `call_deferred("free")` and `free.call_deferred()` [game/tests/test_lint.gd:40]
- [x] [Review][Patch] `root_path` misses `$/root/…` and `get_tree().root.get_node(…)` [game/tests/test_lint.gd:43]
- [x] [Review][Patch] `raw_input` misses `_gui_input` and the `gui_input` signal [game/tests/test_lint.gd:33]
- [x] [Review][Patch] `rules_purity` misses most Node classes (`Timer`, `CharacterBody2D`), `get_tree`, `ResourceSaver`/`ConfigFile`, the `Audio` autoload and core/upper class names; and it fires on a sibling `preload("tuning.gd")` [game/tests/test_lint.gd:54]
- [x] [Review][Patch] `core_layer` misses upper-layer autoloads (`Audio`) and annotated `class_name` lines (`@abstract class_name X`) [game/tests/test_lint.gd:350]
- [x] [Review][Patch] Nothing stops `scripts/` from loading `res://tests/` (release exports exclude `tests/*`); add a `tests_ref` rule [game/tests/test_lint.gd:26]
- [x] [Review][Patch] `uncited_consts` accepts `## GDD ` inside a string and never checks `var` lines in `spec.gd` [game/tests/test_lint.gd:375]
- [x] [Review][Patch] Sample gaps: no comment-quiet sample for the `code` patterns (`core_layer`, `dev_ref`, `rules_purity` paths), no literal `PlayerInput.` near-miss (D4) [game/tests/test_lint.gd:213]
- [x] [Review][Patch] `lint_text` is not static as D4 says (instance regex cache); the row shape and `strip(line, triple)` differ from D2/D3 unrecorded [game/tests/test_lint.gd:148]
- [x] [Review][Patch] `telegraph_floor_errors` tries only none / each / all gear (A+B can go under the floor), crashes on two `set` rows, and the `crawler_hover_period` → 0 half of the closed ledger item is left with no owner [game/tests/test_tuning.gd:189]
- [x] [Review][Patch] The ledger guard catches only two foreign formats; any other format with no list items still passes as "0 items"; D9 #12 (a DW block appended to the real ledger) was never run [game/tests/test_deferred_owners.gd:118]
- [x] [Review][Patch] `smoke_shaft`: the telegraph is probed 50 ms under the floor, the hunt check depends on the tuning value (fails above ~1.07 s), and the chain-3 notice-floor check mixes its premise with its verdict and has no positive control [game/tests/smoke_shaft.gd:257]
- [x] [Review][Patch] Stale docs: the `smoke_player_input` rows still claim the `Input.` check; D3 variances missing from architecture.md / component-inventory.md; game-architecture.md lines ~870 and ~1272 and project-context's `KEY_F` predate the wider rules; the Enforcement summary omits the `random` widening; "in a string" claim; `TESTS_DIR` must be relative [docs/architecture.md:194]
- [x] [Review][Patch] The ledger's "aliasing through a local" closure reads as open work with no owner [_bmad-output/implementation-artifacts/deferred-work.md:209]
- [x] [Review][Patch] Dev record says 89 samples (there are 87) and repeats the gds-create-story sentence [_bmad-output/implementation-artifacts/1-9-glob-test-runner-spec-and-the-architecture-lint.md:348]

## Dev Notes

### What this story is (and isn't)

It is test infrastructure only. **No gameplay script changes behaviour.** A lint hit in real code is either a real violation, which you fix and record, or a broken rule, which you fix in the rule. It adds three things:
- glob discovery in `run_tests.sh`;
- the `Spec` thresholds, with the existing checks switched to them;
- the architecture lint.

**Not in this story** (each has its own owner):
- **`smoke_rooms.gd`, `smoke_bot.gd`** and the per-room guarantees (every room, ids across files, exit targets, safe arrivals): 1.10. It will use `Spec.TELEGRAPH_MIN` and `Spec.BOT_MIN_CHAIN` from here. Don't move or rename `smoke_shaft` now.
- **DevTools** (`scripts/dev/dev_tools.gd`) and the one allowed `load()` line in `world.gd`: 1.11 adds them, and widens the `dev_ref` rule's allow-list to exactly that line, with a test.
- **`core/devices.gd`** (1.14) and **`ui/kit/`** (1.31). Neither exists yet. The lint allows raw input there in advance, as AR48 says.
- **String-key and room-content checks:** 1.10 and 1.17.

### Current state (read before changing)

- **`game/run_tests.sh`.**
  - Imports once.
  - Then runs a hand-kept list: `for t in test_chain_state test_log test_clock test_tuning test_state test_room_loader test_deferred_owners smoke_shaft smoke_world smoke_room_swap smoke_player_input`.
  - Each run is wrapped in `timeout 150` (`LIMIT`). The runner's own 120 s watchdog is a `SceneTreeTimer`, so it can't fire if the main loop blocks (1.2 review).
  - It greps `^(ok|FAIL)|PASS|FAILED|SCRIPT ERROR|ERROR:|^ +at: `, prints `FAILED (run_tests.sh: killed after 150 s)` on rc 124, and ends with `== ALL GREEN` or `== SOMETHING FAILED` (exit 1).
- **`game/tests/runner.gd`** (Story 1.2): already fails on no `PASS` line, on `FAIL`/`FAILED`, on any engine error (via a `Logger`), on 120 s, and on a test that calls `quit()`. **Don't change it.** AC1's runner duties are already met here; this story only replaces the list.
- **Files in `game/tests/`:**
  - **tests:** `test_chain_state`, `test_log`, `test_clock`, `test_tuning`, `test_state`, `test_room_loader`, `test_deferred_owners`, `smoke_shaft`, `smoke_world`, `smoke_room_swap`, `smoke_player_input`;
  - **helpers, never globbed:** `runner.gd`, `room_harness.gd`, `screenshot.gd`, `rooms/`.

  The names already match the glob.
- **Purity checks to retire:**
  - `test_state.gd` `_test_purity()` (≈ line 465) scans `PURE` (`settings.gd`, `slot_state.gd`, `dive_state.gd`) with `\b(Node|Input|Engine)\b|\bGame\.|FileAccess|DirAccess`. It scans comments too.
  - `test_tuning.gd` `_test_purity()` (≈ line 185) scans `tuning.gd` and `gear.gd` with `\b(Node|Input|Engine)\b|\bGame\.`.
  - Both miss `Node2D`, `InputEventKey`, `OS`, `Time` and `load(`, and neither covers `chain_state.gd`. That's the deferred item.
- **`smoke_player_input.gd` `test_sources()`:** a `(?<![A-Za-z0-9_])Input\.` regex over `res://scripts/**` except `player_input.gd`, plus a `SNUFF_HOLD` / `_light_held` substring check and the `PlayerInput`-node check.
- **Design thresholds in tests today:**
  - `smoke_shaft.gd:241` `check(best >= 5, "bot chains 5+ …")`;
  - `smoke_shaft.gd:257` waits `seconds(0.7)` and expects TELEGRAPH (">= 0.75 s rule");
  - `smoke_shaft.gd:271` "base light is never noticed, even point-blank";
  - `test_tuning.gd:273` pins `ChainState.BASE_RADIUS == 40.0` as an M1 fixture value. That one stays a fixture pin; it is not a guarantee check.
- **`test_tuning.gd`'s M1 fixture rows pin values.** `{m1 = "lurker.telegraph_time", value = 0.9, …}` and `{… NOTICE_MIN_RADIUS = 80.0 …}` pin M1 values. They are not Spec checks: leave them.
- **Gear:**
  - `rules/gear.gd` `const TABLE: Array[Dictionary] = []` is empty until E5.
  - `Tuning.apply_gear(gear_ids: Array[StringName], table := Gear.TABLE)` applies set → add → mul, and `f(key)` reads.
  - `_check_row()` asserts each row's shape. Read `tuning.gd:112-175` before writing the gear-floor check.
- **`tests/test_deferred_owners.gd`.**
  - `static func scan(text) -> {items, unowned, proposed}`, with sample-text tests in `_test_scan_rules()` and the real-ledger check in `_test_real_ledger()`.
  - A ledger with no `- ` items gives `items == 0` and passes. That is the bmad-loop hole: its `### DW-n` + `status:` format would switch the gate off.
- **Today's scripts against the D3 rules.** Scanned 2026-11-18, comments stripped; 22 files.
  - The only rule with a hit is `randf_range`, in `world/camera_rig.gd:101`, which is allowed.
  - Comments mention `DevTools` in `world.gd:21,26,118`, `core/log.gd:7` and `rules/slot_state.gd:18`. A `rules/` comment says "New Game".
  - So the lint **must strip comments**, or it fails on day one.
  - Code strings include colours like `"#07060b"`, so comment stripping must respect strings (D2).
- **`class_name`s per layer (for the `core_layer` rule):**
  - `world/`: World, Room, RoomLoader, RoomLegend, CameraRig;
  - `actors/`: Player, PlayerInput, Crawler, Lurker;
  - `ui/`: Gutters, ScreenRouter;
  - `core/`: Clock, Log, Fx, SaveStore, and `game.gd`, which is an autoload with no `class_name`;
  - `rules/`: ChainState, SlotState, DiveState, Settings, Gear, Tuning.

### Decisions

- **D1, `run_tests.sh`.**
  - Build the list with bash globs, in this order: `tests/test_*.gd` sorted, then `tests/smoke_*.gd` sorted. Unit tests run first; they are fast and fail early.
  - Use `shopt -s nullglob`. Sort with `LC_ALL=C` so the order doesn't depend on the locale.
  - Pass each file as `res://tests/<name>.gd`. Top level only: helpers and `tests/rooms/` never match.
  - If the list is empty, print `== NO TESTS FOUND` and exit 1.
  - Keep everything else as it is: the import, `LIMIT=150` + `timeout`, the grep and the `== name` headers.
  - At the end, after `== SOMETHING FAILED`, add one line listing the failed test names. It is cheap and saves scrolling.
  - Allow an optional `TESTS_DIR` env override (default `tests`), used **only** for the empty-glob red check. Document it in the header comment. Don't add other flags.
- **D2, how the lint reads a file.**
  - `static func strip(line: String, in_string: bool) -> Dictionary` is pure. It returns `{code, bare, in_string}`:
    - `code` is the line with the `#` comment removed. It handles `"…"`, `'…'`, `\` escapes and `"""` blocks that span lines, which is why the in-string state is carried between lines;
    - `bare` is `code` with every string's contents blanked to spaces (the quotes stay), so column positions don't move.
  - **Identifier rules** match `bare`. **String rules** (`"/root/`, path strings) match `code`. Comment-only lines and `##` doc comments never hit.
  - `StringName` (`&"…"`) and `NodePath` (`^"…"`) literals are strings.
- **D3, the rules.** Each rule is a row in `const RULES` in `test_lint.gd`: `{id, re, on (&"bare" or &"code"), only (path prefixes or []), allow (path prefixes)}`. Paths are relative to `scripts/` (`actors/player.gd`). Use the ids below exactly; they appear in `FAIL lint` lines and in later stories (1.11).

  | id | pattern (on) | applies to | allowed in |
  |---|---|---|---|
  | `time_scale` | `\bEngine\s*\.\s*(time_scale\s*=(?!=)\|set_time_scale\s*\()` (bare) | all | `core/clock.gd` |
  | `raw_input` | `\b(Input\|InputMap)\s*\.` or `\bInputEvent\w*` or `func\s+_(unhandled_)?(input\|key_input)\s*\(` or `func\s+_shortcut_input\s*\(` (bare) | all | `actors/player_input.gd`, `core/devices.gd`, `ui/kit/` |
  | `print` | `(?<![\w.])(print\|print_rich\|printerr\|printraw\|prints\|printt\|print_debug)\s*\(` (bare) | all | `core/log.gd` |
  | `free` | `\.free\s*\(\s*\)` or `(?<![\w.])free\s*\(\s*\)` (bare) | all | — |
  | `root_path` | `\^?["']/root(/\|["'])` (code) | all | — |
  | `keycode` | `\bKEY_[A-Z0-9_]+\b` (bare) | all | `ui/kit/` (glyphs and rebinding, E1.31/E7) |
  | `random` | `(?<![\w.])(randf\|randi\|randf_range\|randi_range\|randfn\|randomize)\s*\(` or `\bRandomNumberGenerator\b` (bare) | all | `world/camera_rig.gd` |
  | `rules_purity` | `\b(Node\w*\|Input\w*\|Engine\w*\|OS\|Time\|SceneTree\|FileAccess\|DirAccess\|ResourceLoader\|ProjectSettings\|DisplayServer\|Game)\b` or `(?<![\w.])load\s*\(` (bare); and `preload\s*\(\s*["'](?!res://scripts/rules/)` (code) | `rules/` | — |
  | `core_layer` | any upper-layer `class_name` as a whole word (bare), or `res://(scripts\|scenes)/(world\|actors\|objects\|moments\|ui\|audio\|dev)/` (code) | `core/` | — |
  | `dev_ref` | `\bDevTools\b` (bare) or `res://(scripts\|scenes)/dev/` (code) | all but `dev/` | — (1.11 adds `world.gd`'s one line) |
  | `state_write` | `\bGame\s*\.\s*(settings\|slot\|dive\|tuning\|clock\|store)\s*=(?!=)` or `\bGame\s*\.\s*(settings\|slot\|dive)\s*\.\s*\w+(\s*\[[^\]]*\])*\s*([-+*/%]\|<<\|>>\|&\|\\\|\|\^)?=(?!=)` (bare) | all but `rules/` | — |

  - **Upper-layer class names** come from `class_name` lines in `scripts/{world,actors,objects,moments,ui,audio,dev}/**`, collected when the lint runs. A new class is covered with no edit, and the list is never hand-kept. `lint_text()` takes them as a parameter, so the samples can pass a fixed list.
  - **Variances from AR48's wording, all stricter:**
    - `keycode` flags every `KEY_*` constant, not only `KEY_F*`, because project-context says "no function keys or raw keycodes";
    - `raw_input` adds `InputMap`, `InputEvent*` and the `_input` callbacks, which is the 1.8 deferred item;
    - `rules_purity` adds the deferred prefixes plus `OS`, `Time`, file access and `load(`;
    - `random` adds `randfn` / `randomize` / `RandomNumberGenerator`;
    - `state_write` is new, from the 1.4 deferred item. It also forbids replacing a `Game.*` instance, a project-context rule.

    Record each one in the architecture doc (D10).
  - **What the lint can't see (say so in its header):** aliasing (`var s := Game.settings; s.brightness = 2`), `Input` reached through `Engine.get_singleton()`, code in `.tscn` files (none today). Review covers these.
- **D4, `test_lint.gd`'s shape.**
  - `extends Node`, `run()`, and the usual `check()` / `ok`/`FAIL` / `PASS` helpers.
  - **Pure core:** `static func lint_text(rel_path: String, text: String, upper_classes: PackedStringArray) -> Array[Dictionary]` returns hits `{line (1-based), rule}`, sorted by line. No file I/O in it.
  - **Samples first** (`_test_rules()`): for each rule, at least:
    - (a) a violating line on a covered path → exactly one hit with that rule id;
    - (b) the same line on an allowed path → no hit (rules that have an allow-list);
    - (c) the same text inside a `#` comment → no hit;
    - (d) for `bare` rules, the token inside a string literal → no hit.

    Plus the cases that keep the rules honest:
    - `PlayerInput.` never matches `raw_input`;
    - `queue_free()` never matches `free`;
    - `my_print(` and `x.print(` never match `print`;
    - `Game.slot.best_chain == 3` and `Game.dive.carried >= 2` never match `state_write`;
    - `"#07060b"` in code isn't treated as a comment;
    - a `"""` string that spans lines hides a `print(` inside it;
    - `preload("res://scripts/rules/gear.gd")` in `rules/` is allowed, and `preload("res://scenes/…")` isn't.
  - **Real tree** (`_test_tree()`):
    - walk `res://scripts/` recursively for `.gd`;
    - fail if 0 files are found, if any file is unreadable, or if a sentinel file (`actors/player_input.gd`, `core/clock.gd`) is missing, so a wrong root can't pass as "clean";
    - print each hit as `FAIL lint <rel_path>:<line> <rule>` (e.g. `FAIL lint actors/player.gd:88 print`);
    - on success print one `ok   lint: <n> files, <r> rules, 0 hits`.
  - **No per-file `ok` lines** (22 files × 11 rules would be noise).
- **D5, `tests/spec.gd`.**
  - `extends RefCounted`, no `class_name`. Tests do `const Spec := preload("res://tests/spec.gd")`.
  - One const per guarantee, each with a `##` comment that starts with `GDD <section>:` and quotes the promise:
    - `TELEGRAPH_MIN := 0.75`: GDD Predators: Lurker, "Telegraph: 0.9 s (never below 0.75 s)"; Core Gameplay Loop step 3; Pillar 2.
    - `BOT_MIN_CHAIN := 5`: GDD Level Progression, "Level validation: an automated bot must reach a chain of ≥ 5 in every spine shaft".
    - `BASE_LIGHT := 40.0`: GDD Attack, pogo and chain, "40 px at 0 links". It is never noticed, because a lurker wakes only at ≥ 80 px.
    - `NOTICE_MIN_RADIUS := 80.0`: GDD Predators: Lurker, "Wakes: when your light radius is ≥ 80 px (4 links)".
  - `test_lint` checks that every `const` line in `spec.gd` has `## GDD` (rule id `spec_citation`, scanned separately, since `spec.gd` is outside `scripts/`).
- **D6, switching the checks to Spec.** Never compare a guarantee against the tuning value under test.
  - **`smoke_shaft.gd`:**
    - bot: `check(best >= Spec.BOT_MIN_CHAIN, …)`. The bot's best is 8 today.
    - telegraph: add `check(Game.tuning.f(&"lurker_telegraph_time") >= Spec.TELEGRAPH_MIN, …)`, and wait `Spec.TELEGRAPH_MIN - 0.05` (instead of the literal 0.7) before "still telegraphing".
    - base light: before the point-blank check, add `check(_player.light_radius() <= Spec.BASE_LIGHT, …)`.
    - notice floor: add a point-blank check with a chain of 3 (light ≈ 78 px < 80): `check(_player.light_radius() < Spec.NOTICE_MIN_RADIUS and not lurker.senses(_player), …)`. Then check `Lurker.NOTICE_MIN_RADIUS >= Spec.NOTICE_MIN_RADIUS`, which is a floor: a lurker may wake later, never earlier.
    - Keep each existing check's meaning; only the threshold source changes.
  - **`test_tuning.gd`, the gear floor** (the 1.3 deferred item). Add a pure helper `static func telegraph_floor_errors(table: Array[Dictionary]) -> Array[String]`. For a fresh `Tuning`, it checks the base value, each gear id in `table` alone, and all ids together, against `Spec.TELEGRAPH_MIN`, and returns one message per breach. Then:
    - `check(telegraph_floor_errors(Gear.TABLE).is_empty(), …)` (empty today, so it checks the base);
    - **prove it fires:** a probe table `[{id = &"probe_short_wick", stat = &"lurker_telegraph_time", op = &"mul", value = 0.5}]` → exactly 1 error.

    Use real row shapes (`_check_row` asserts them).
- **D7, retiring the old checks.**
  - The lint's `rules_purity` covers every `rules/` file by glob, so delete both `_test_purity()`s. Also delete the `PURE` consts unless something else uses them (check).
  - Delete `test_sources`' `Input.` regex. Its header comment points to the lint now.
  - The counts drop; record before → after in the Debug Log (`test_state` 171, `test_tuning` 85, `smoke_player_input` 60 today).
- **D8, the ledger format.**
  - In `test_deferred_owners.gd`, add `static func unknown_format(text) -> Array[String]`. It returns one reason per line that shows a ledger format the scan can't read: a heading matching `^#{2,4}\s+DW-\d+` or a line matching `^status:\s`. Fenced code is skipped, as `scan()` does.
  - `_test_real_ledger()` fails with `deferred-work.md:<line> ledger format not readable by this check (bmad-loop DW-n?): convert it or teach scan()`.
  - Add samples in `_test_scan_rules()`: a DW-format snippet → reasons and 0 items; the real format → no reasons.
- **D9, red checks** (record each in the Debug Log, then revert):
  1. a scratch `tests/test_zz_probe.gd` that prints `FAIL` → the glob runs it and the suite fails;
  2. a scratch `tests/smoke_zz_probe.gd` with no `PASS` → it fails;
  3. `TESTS_DIR` pointed at an empty folder → `== NO TESTS FOUND`, exit 1;
  4. a `print("x")` added to `actors/player.gd` → `FAIL lint actors/player.gd:<n> print`;
  5. `Engine.time_scale = 1.0` added to `world/camera_rig.gd` → `time_scale`;
  6. `var e: InputEventKey` added to `actors/player.gd` → `raw_input`;
  7. a `Node` reference added to `rules/gear.gd` → `rules_purity`;
  8. `Game.settings.brightness = 2` added to `world/world.gd` → `state_write`;
  9. one rule's regex broken (for example, `print` matching nothing) → its sample test fails;
  10. a const without `## GDD` added to `spec.gd` → `spec_citation`;
  11. `TELEGRAPH_MIN` raised to 1.0 → the gear-floor check and smoke_shaft's telegraph check fail (0.9 < 1.0);
  12. a DW-format block appended to a copy of the ledger fed to `unknown_format()` → reasons (sample-level; never edit the real ledger).
- **D10, docs and ledger.**
  - **`_bmad-output/project-context.md` → Current State:**
    - replace "a hand-kept `for t in …` list in `run_tests.sh` … add new test files to the `for t in …` loop" with a 1.9 sentence: tests are found by glob; `tests/spec.gd`; `test_lint.gd` with its rule ids;
    - make "Rules below that name files which don't exist yet (`tests/spec.gd`, `test_lint.gd`)" name only what is still missing (`smoke_rooms.gd`, `smoke_bot.gd`);
    - set Last Updated.
  - **`docs/development-guide.md`:** how tests are found (name it `test_*` / `smoke_*`, no list), Spec (`preload`, cite the GDD), and the lint (what fails, how to read `FAIL lint`, and to fix the code, never the lint).
  - **`docs/architecture.md` and `docs/component-inventory.md`:** test table rows for `test_lint`, `spec.gd` and the glob, and the D3 variances.
  - **`docs/source-tree-analysis.md`:** the new files.
  - **`_bmad-output/game-architecture.md` Enforcement section:** align with the D3 rule list. It still says "`Input.is_action` / `Input.is_key`"; epics.md's resolved note says "lint matches `Input.` broadly". List the variances.
  - **`deferred-work.md`:** add `→ **Closed (Story 1.9): …**` under each of the four 1.9 items: ledger format, gear floor, `rules/` purity + state writes, raw-Input source check.

### Verified facts

- Godot's `RegEx` is PCRE2: lookbehind (`(?<!…)`) and lookahead work. `smoke_player_input.gd` already uses `(?<![A-Za-z0-9_])`.
- `DirAccess.get_files_at()` / `get_directories_at()` on `res://` work in the runner; `smoke_player_input._gd_files()` already walks `res://scripts` this way. Reuse that walker.
- `FileAccess.get_file_as_string()` returns `""` on error. Check `FileAccess.get_open_error()`, as the old purity tests did; an unreadable file must fail, never pass.
- Tests can `preload("res://tests/…")`: the runner runs them as scenes (R17).

### Project Structure Notes

- New:
  - `game/tests/test_lint.gd` (+ `.uid`);
  - `game/tests/spec.gd` (+ `.uid`), a helper, so its name must not start with `test_`/`smoke_`.
- Modified:
  - tests: `game/run_tests.sh`, `game/tests/smoke_shaft.gd`, `test_tuning.gd`, `test_state.gd`, `smoke_player_input.gd`, `test_deferred_owners.gd`;
  - docs and records: `docs/development-guide.md`, `docs/architecture.md`, `docs/component-inventory.md`, `docs/source-tree-analysis.md`, `_bmad-output/project-context.md`, `_bmad-output/game-architecture.md` (Enforcement section only), `_bmad-output/implementation-artifacts/deferred-work.md`.
- **No change** under `game/scripts/` or `game/scenes/` unless the lint finds a real violation (D3 note in Task 3).

### Project Context Rules (that apply here)

- **Done means green:**
  - `./run_tests.sh` → `== ALL GREEN`;
  - the runner fails on `SCRIPT ERROR` / `ERROR:`;
  - keep the `ok …` / `FAIL …` + `PASS` / `FAILED` format.
- **Validators are pure and return error lists.** This is why `lint_text()`, `telegraph_floor_errors()` and `unknown_format()` return lists and do no I/O.
- **Never loosen a threshold to pass.** Spec values come from the GDD. Changing one means changing the GDD first, with sonlm.
- **Fix the code, not the lint.** That rule starts with this story.
- **No `print(` outside `Log` in game code.** Tests print their `ok`/`FAIL` lines; the lint scans `scripts/` only.
- **Commit `.gd.uid` files** with their scripts.
- **Every deferred item needs an owner**, assigned by the agent that defers it, with no "(proposed)".
- **Comments explain *why*,** citing the design.

### Previous story intelligence (1.8 and its review)

- **Red-check every new check.** In 1.8, two checks passed with their code broken:
  - the lock test, first version;
  - the cling-consume check.

  Both turned out vacuous. For the lint, the sample tests are the red check per rule (D4), and D9 adds real-tree ones.
- **Frame-math surprises came from assuming instead of measuring.** For lint regexes, the samples are the measurement: write them before the rule.
- **1.8's code review:**
  - flagged `p.free()` in a test; the lint covers `scripts/` only (AR48), so tests stay review-checked;
  - deferred the raw-Input event reads to this story (D3 `raw_input`);
  - noted the source regex flagged `Input.` in comments (D2 fixes that).
- **The dash-length item went to 1.15, not here.** Don't touch `smoke_player_input`'s dash pins.

### Git intelligence

- `e31f793` / `fa48694` / `f9fce9b`: 1.8 (PlayerInput, docs, record).
- Commit split that has worked: code + tests, then docs, then the story record. sonlm asks for commits explicitly.
- The repo has no remote, so nothing is pushed.

### Cross-story context (Epic 1)

- **1.10** builds `smoke_rooms.gd` / `smoke_bot.gd` on `Spec` (and closes the two 1.10-owned deferred items).
- **1.11** adds DevTools and one allowed `dev_ref` line.
- **1.14** adds `core/devices.gd`; **1.31** adds `ui/kit/`. Both are pre-allowed by `raw_input`.
- **1.15** is the CP1 gate. It decides the dash length (deferred from 1.8).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.9]: ACs.
- [Source: _bmad-output/planning-artifacts/epics.md AR47–AR49, AR54; "Architecture-doc inconsistencies" note ("lint matches `Input.` broadly")].
- [Source: _bmad-output/game-architecture.md#Enforcement]: the lint list and test discovery.
- [Source: _bmad-output/game-architecture.md#Implementation Patterns → 5. Design Guarantees as Tests]: Spec, its rules and the implementation guide.
- [Source: _bmad-output/game-architecture.md#Consistency Rules].
- [Source: _bmad-output/game-architecture.md, layer rules ("Enforced by tests/test_lint.gd")].
- [Source: _bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md]:
  - Core Gameplay Loop step 3 (telegraph ≥ 0.75 s);
  - Attack, pogo and chain (40 px at 0 links);
  - Predators: Lurker (wakes ≥ 80 px; telegraph never below 0.75 s);
  - Level Progression (bot ≥ 5 in every spine shaft).
- [Source: _bmad-output/implementation-artifacts/deferred-work.md]: the four `Owner: Story 1.9` items (ledger format; gear telegraph floor; `rules/` purity + state writes; raw-Input source check).
- [Source: _bmad-output/implementation-artifacts/1-2-log-and-a-clock-that-owns-time.md]: the runner contract and its review.
- [Source: _bmad-output/implementation-artifacts/1-8-playerinput-intents.md#Review Findings].
- [Source: _bmad-output/project-context.md#Testing Rules, #Code Organization Rules].

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), gds-dev-story, 2026-11-18.

### Debug Log References

- **Baseline** `b901497`: `./run_tests.sh` → `== ALL GREEN`, 11 tests from the hand-kept list.
- **Task 1, glob runner:** the green run lists the same 11 tests (now in C sort order, unit first). Red checks:
  1. a scratch `tests/test_zz_probe.gd` printing `FAIL` ran with no edit to `run_tests.sh`, and the suite failed (`== failed: test_zz_probe …`);
  2. a scratch `tests/smoke_zz_probe.gd` with only `ok` lines → `FAILED (runner: no PASS line)`;
  3. `TESTS_DIR` at an empty folder → `== NO TESTS FOUND …`, exit 1.

  The probes and their `.uid` files were removed.
- **Task 2, Spec:** `smoke_shaft` 30 → 34 `ok` (the telegraph vs Spec, base light ≤ `Spec.BASE_LIGHT`, chain 3 at 78.1 px never noticed, `Lurker.NOTICE_MIN_RADIUS` ≥ the floor). The bot's best chain is 8. `test_tuning`: the gear floor holds on the empty `Gear.TABLE`, and the probe table (`mul` 0.5) gives exactly 1 error (0.45 s < 0.75 s).
- **Task 3, lint:** green on the first run, with no code changes needed: 22 files, 11 rules, 0 hits. 110 `ok`:
  - 4 `strip` cases;
  - 87 rule samples;
  - 11 "has a firing sample" checks;
  - the tree sentinels;
  - the upper-class list (11 names collected);
  - 2 `spec_citation` checks.
- **Task 4, retired checks:**
  - `test_state` 171 → 165 (the purity scan of 3 files);
  - `test_tuning` 85 → 83 (−4 purity, +2 gear floor);
  - `smoke_player_input` 60 → 59 (the `Input.` regex; its `_gd_files` walker went with it);
  - `test_deferred_owners` 19 → 21 (the DW-format sample and the real-format negative).
- **Task 6, D9 red checks.** Each was reverted after the run; `git status` showed only the intended files.
  4. `print("x")` in `actors/player.gd` → `FAIL lint actors/player.gd:330 print`;
  5. `Engine.time_scale = 1.0` in `world/camera_rig.gd` → `time_scale`;
  6. `var _zz_e: InputEventKey` in `actors/player.gd` → `raw_input`;
  7. `var _zz_n: Node` in `rules/gear.gd` → `rules_purity`;
  8. `Game.settings.brightness = 2` in `world/world.gd` → `state_write`;
  9. the `print` pattern broken (`zzprint|…`) → its "fires" sample fails;
  10. an uncited const in `spec.gd` → `FAIL lint tests/spec.gd:12 spec_citation`;
  11. `TELEGRAPH_MIN` 1.0 → `test_tuning`'s floor fails (0.900 < 1.00), and `smoke_shaft`'s telegraph checks fail (2);
  12. `unknown_format()` returning `[]` → the DW sample fails.

  Extra: `BOT_MIN_CHAIN` 9 → the bot check fails (best 8).
- **Final:** `./run_tests.sh` → `== ALL GREEN (12 tests)`:
  - `test_chain_state` 69, `test_clock` 15, `test_deferred_owners` 21, `test_lint` 110, `test_log` 7, `test_room_loader` 64, `test_state` 165, `test_tuning` 83;
  - `smoke_player_input` 59, `smoke_room_swap` 39, `smoke_shaft` 34, `smoke_world` 60.

  No `SCRIPT ERROR` / `ERROR:` lines.
- **Code review (2026-11-18), 20 patches applied:**
  - **`test_lint`** 110 → 162 `ok`:
    - `strip()` handles `\` escapes in every string kind and carries a `\`-continued string to the next line;
    - rules widened: `time_scale` compound and `Engine.set`; `state_write` nested fields and indexes, mutators, `.set(`, `tuning`; `random`; `print`; `free`; `root_path`; `raw_input` `_gui_input`;
    - `rules_purity` and `core_layer` get run-time class names from `layer_names()` (annotated `class_name`, autoloads, ClassDB Node classes for `rules/`);
    - new rule `tests_ref` (12 rules);
    - `uncited_consts` reads the comment only and flags `var`;
    - `lint_text` is static (D4);
    - 132 samples, plus the comment-quiet `code` samples and the literal `PlayerInput.` near-miss.
  - **`test_tuning`** 83 → 87: `stat_floor_errors()` tries every combination of gear rows, reports two `set` rows instead of crashing, and also floors `crawler_hover_period` > 0. Probes: a pair, two sets, zeroed hover.
  - **`test_deferred_owners`** 21 → 25: `unknown_format()` also reports `status:` in any case, bulleted or bold, table rows, and a ledger with text under its sections but no items. D9 #12 is now a check on the real ledger with a DW block appended.
  - **`smoke_shaft`** 34 → 36:
    - the telegraph is measured (54 frames), no longer probed at 0.70 s, and the hunt check no longer depends on the tuning value;
    - the notice floor finds the largest chain under 80 px (chain 3, 78.1 px) as its own setup check, and a control proves chain 4 (84 px) is noticed from the same spot.
  - **Red checks, each reverted:**
    - planted `pick_random()`, `Game.slot.flags.erase()`, a `res://tests/` preload, a `Timer` in `rules/`, `Player` in `core/` and a `static var` in Spec → `random`, `state_write`, `tests_ref`, `rules_purity`, `core_layer`, `spec_citation`;
    - escapes disabled in `strip()` → 3 strip samples fail;
    - singletons-only gear sets → the pair and two-set probes fail;
    - the no-items guard disabled → its sample fails;
    - telegraph 0.6 s → both telegraph checks fail;
    - telegraph 1.5 s → passes (the old 0.35 s follow-up wait failed here);
    - `Lurker.NOTICE_MIN_RADIUS` 70 → the verdict and the floor check fail.
  - **Docs:** rule table, architecture and component rows, D3 variances, `game-architecture.md` layer and Input rows, project-context lint bullet, `run_tests.sh` `TESTS_DIR` note, four ledger closures (the hover half is now closed by a check; the aliasing note is a documented boundary, not deferred work).
  - **Final:** `== ALL GREEN (12 tests)`:
    - `test_chain_state` 69, `test_clock` 15, `test_deferred_owners` 25, `test_lint` 162, `test_log` 7, `test_room_loader` 64, `test_state` 165, `test_tuning` 87;
    - `smoke_player_input` 59, `smoke_room_swap` 39, `smoke_shaft` 36, `smoke_world` 60.

### Completion Notes List

- **AC1:** `run_tests.sh` builds its list from `test_*.gd` then `smoke_*.gd` (`nullglob`, `LC_ALL=C sort`); an empty glob fails; the runner (unchanged) still fails on no PASS, 120 s and engine errors; the 150 s wall-clock `timeout` stays. The final line is `== ALL GREEN (N tests)`, and a failure lists the failed tests. `TESTS_DIR` exists only for the empty-glob red check (header comment).
- **AC2:** `tests/spec.gd` has the four consts with `## GDD` citations. `smoke_shaft` compares the bot, the telegraph, base light and the notice floor against `Spec`; `test_tuning`'s `telegraph_floor_errors()` covers every gear row (each alone and all together).
- **AC3/AC4:** `tests/test_lint.gd` has a pure `strip()` and `lint_text()`, 11 data rules with stable ids, 87 sample lines (fires, allowed path, comment, string, near-misses), a real-tree scan with sentinels, upper-layer class names read from `class_name` lines, and `spec_citation`. It was green on today's 22 scripts with no code change.
- **AC5:** the purity scans and the `Input.` regex are gone. `test_deferred_owners` fails on a DW-format ledger. All four 1.9-owned ledger items are closed.
- **AC6:** all green; 12 red checks recorded above; the docs and `project-context.md` are updated (glob, Spec, lint rule table in the development guide, Enforcement section in `game-architecture.md`).
- **D3 variances, all stricter than AR48:**
  - `keycode` = every `KEY_*`;
  - `raw_input` adds `InputMap`, `InputEvent*`, the `_input` callbacks and `Input` used as a value (this covers aliasing of `Input` itself);
  - `rules_purity` adds the deferred prefixes plus `OS`, `Time`, file access and `load(`;
  - `random` adds `randfn`, `randomize` and `RandomNumberGenerator`;
  - `state_write` is new.
- **Deviations from D2–D4, kept and recorded:**
  - `strip(line, open)` returns `{code, bare, open}`, because a bool can't say which delimiter closes a carried string;
  - rule rows are `{id, bare, code, only, skip, allow}`, so one rule can check identifiers and path strings;
  - `lint_text(rel, text, names)` takes per-rule class names.
- **Nothing deferred.** No gameplay script changed, so no feel check is needed.
- Story context created by gds-create-story on 2026-11-18. Today's `game/scripts/` was scanned against every D3 rule with comments stripped (one allowed hit: `randf_range` in `camera_rig.gd`).

### File List

- game/run_tests.sh (modified: glob discovery, empty-glob failure, failed-test list)
- game/tests/spec.gd (new)
- game/tests/spec.gd.uid (new)
- game/tests/test_lint.gd (new)
- game/tests/test_lint.gd.uid (new)
- game/tests/smoke_shaft.gd (modified: bot, telegraph, base light and notice floor against Spec)
- game/tests/test_tuning.gd (modified: purity removed, telegraph floor under every gear)
- game/tests/test_state.gd (modified: purity removed)
- game/tests/smoke_player_input.gd (modified: Input regex and its walker removed)
- game/tests/test_deferred_owners.gd (modified: unknown_format())
- docs/development-guide.md (modified: glob, Spec, lint rule table)
- docs/architecture.md (modified)
- docs/component-inventory.md (modified)
- docs/source-tree-analysis.md (modified)
- _bmad-output/project-context.md (modified: Current State, Last Updated)
- _bmad-output/game-architecture.md (modified: Enforcement section)
- _bmad-output/implementation-artifacts/deferred-work.md (modified: four 1.9 items closed)
- _bmad-output/implementation-artifacts/1-9-glob-test-runner-spec-and-the-architecture-lint.md (this file)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified: 1-9 → review)

### Change Log

- 2026-11-18: Story 1.9 implemented. Glob test discovery in run_tests.sh; tests/spec.gd with the four GDD guarantees, used by smoke_shaft and test_tuning (telegraph floor under every gear); tests/test_lint.gd with 11 rules, samples and a Spec citation check; old purity scans and the Input regex retired; the ledger-format check. Status → review.
- 2026-11-18: Code review: 20 patches applied (lint escapes and continuations, wider rules, run-time layer names, `tests_ref`, gear floors over every combination and the hover period, the ledger no-items guard, measured telegraph and a notice-floor control, docs). Status → done.
