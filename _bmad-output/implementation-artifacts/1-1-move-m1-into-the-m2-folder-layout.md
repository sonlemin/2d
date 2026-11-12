---
baseline_commit: ec561bb03864f238a5176736746b25b6a3c620fb
---

# Story 1.1: Move M1 into the M2 folder layout

Status: done

**Type:** dev (no human gate; done when every AC passes and `run_tests.sh` is green)
**Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP1 Foundations (1.1–1.15) · **Branch:** `feat/m2-e1`

## Story

As the developer,
I want the M1 scripts, scenes and tests moved into the M2 domain folders with no behaviour change,
so that every later story builds on the architecture's layout instead of extending M1 patterns.

## Acceptance Criteria

1. **Moves.** Given the M1 tree, when the migration commit lands, then:
   - `chain_state.gd` is in `scripts/rules/`
   - `player.gd`, `crawler.gd` and `lurker.gd` are in `scripts/actors/`
   - `fx.gd` is in `scripts/core/`
   - `scenes/enemies/*` and `player.tscn` are in `scenes/actors/`
   - `tests/run_tests.gd` is now `tests/test_chain_state.gd` (AR1)

   Every move is a `git mv` in **one commit**, with each `.gd.uid` moved beside its script. `scripts/` and `scenes/` use the same domain folder names: `core/ rules/ world/ actors/ objects/ moments/ ui/ audio/ dev/` (AR58; see Decisions D1).
2. **Paths.** Given the moved files, when every `res://` path that points at a moved file is rewritten by hand (the full list goes in the commit message) and `godot --headless --path game --import` runs, then loading the project and every moved scene prints no `SCRIPT ERROR` or `ERROR:` line.
3. **Green before anything else.** Given `run_tests.sh` updated only for the renamed test, when it runs, then:
   - it is green
   - `test_chain_state` is unchanged except its preload path, and `smoke_shaft` still passes
   - this holds before any other change is made
   - `shaft.gd` and `shaft.tscn` stay where they are until Story 1.7 retires them

## Tasks / Subtasks

- [x] **Task 1: Baseline** (AC: 3)
  - [x] `cd game && timeout 300 ./run_tests.sh` → expect `ALL PASS (69 checks)`, 28 `ok` lines, `SMOKE PASS`, `== ALL GREEN`. Record the counts in the Debug Log. They are the regression bar.
- [x] **Task 2: Moves, all with `git mv`** (AC: 1). Run from `game/` and create the target folders first, because `git mv` won't create them:
  ```bash
  mkdir -p scripts/rules scripts/actors scripts/core scenes/actors
  git mv scripts/chain_state.gd scripts/chain_state.gd.uid scripts/rules/
  git mv scripts/player.gd scripts/player.gd.uid scripts/crawler.gd scripts/crawler.gd.uid \
         scripts/lurker.gd scripts/lurker.gd.uid scripts/actors/
  git mv scripts/fx.gd scripts/fx.gd.uid scripts/core/
  git mv scenes/enemies/crawler.tscn scenes/enemies/lurker.tscn scenes/player.tscn scenes/actors/
  git mv tests/run_tests.gd tests/test_chain_state.gd
  git mv tests/run_tests.gd.uid tests/test_chain_state.gd.uid
  ```
  - [x] If `scenes/enemies/` still exists on disk, remove it with `rmdir`. It must be gone.
  - [x] `git status --short` shows **15 renames**: 5 scripts, 5 `.gd.uid` files, 2 test files and 3 scenes. Nothing is deleted and re-added.
- [x] **Task 3: Rewrite the paths by hand** (AC: 2). "By hand" means editing the text (with the Edit tool or `sed`), never the Godot editor's FileSystem dock. Make exactly these edits:

  | # | File:line (after the move) | Old | New |
  |---|---|---|---|
  | 1 | `scenes/actors/player.tscn:3` | `res://scripts/player.gd` | `res://scripts/actors/player.gd` |
  | 2 | `scenes/actors/crawler.tscn:3` | `res://scripts/crawler.gd` | `res://scripts/actors/crawler.gd` |
  | 3 | `scenes/actors/lurker.tscn:3` | `res://scripts/lurker.gd` | `res://scripts/actors/lurker.gd` |
  | 4 | `scenes/shaft.tscn:4` | `res://scenes/player.tscn` | `res://scenes/actors/player.tscn` |
  | 5 | `scripts/shaft.gd:9` | `res://scenes/enemies/crawler.tscn` | `res://scenes/actors/crawler.tscn` |
  | 6 | `scripts/shaft.gd:10` | `res://scenes/enemies/lurker.tscn` | `res://scenes/actors/lurker.tscn` |
  | 7 | `tests/test_chain_state.gd:6` | `res://scripts/chain_state.gd` | `res://scripts/rules/chain_state.gd` |
  | 8 | `tests/test_chain_state.gd:3` (the `## Run:` comment) | `res://tests/run_tests.gd` | `res://tests/test_chain_state.gd` |

  - [x] Leave these alone, because they point at files that don't move: `project.godot` `run/main_scene="res://scenes/shaft.tscn"`, `scenes/shaft.tscn:3` (`res://scripts/shaft.gd`), the `res://scenes/shaft.tscn` preloads in `tests/smoke_shaft.gd:6` and `tests/screenshot.gd:6`, and every `res://art/*` path.
  - [x] Check for leftovers: `grep -rnE 'res://scripts/(chain_state|player|crawler|lurker|fx)\.gd|res://scenes/(enemies|player\.tscn)|run_tests\.gd' --include=*.gd --include=*.tscn --include=*.godot .` → no hits.
- [x] **Task 4: `run_tests.sh`** (AC: 3)
  - [x] Line 8: `for t in run_tests smoke_shaft; do` → `for t in test_chain_state smoke_shaft; do`. Change nothing else; the glob runner arrives in Story 1.9.
- [x] **Task 5: Verify** (AC: 2, 3). Run from `game/`. Every grep must print nothing:
  ```bash
  godot --headless --path . --import 2>&1 | grep -E 'SCRIPT ERROR|ERROR:'
  for s in scenes/actors/player.tscn scenes/actors/crawler.tscn scenes/actors/lurker.tscn scenes/shaft.tscn; do
    timeout 60 godot --headless --path . --quit-after 5 "res://$s" 2>&1 | grep -E 'SCRIPT ERROR|ERROR:'; done
  timeout 60 godot --headless --path . --quit-after 30 2>&1 | grep -E 'SCRIPT ERROR|ERROR:'   # main scene boot
  for t in test_chain_state smoke_shaft; do
    timeout 120 godot --headless --path . --script res://tests/$t.gd 2>&1 | grep -E 'SCRIPT ERROR|ERROR:'; done
  timeout 300 ./run_tests.sh      # same counts as Task 1, ends "== ALL GREEN"
  grep -o 'res://[^"]*' .godot/global_script_class_cache.cfg   # 5 classes, all at the new paths
  ```
  - [x] `git diff -M --stat HEAD` shows only the 15 renames, edits 1–8, `run_tests.sh` and the D2 doc edits. `art/`, `*.import`, `project.godot` and `tools/` are untouched.
- [x] **Task 6: Fix the doc paths** (D2: paths and file names only, no rewording)
  - [x] `_bmad-output/project-context.md` → "Current State vs Target": the scripts now live in domain folders, the chain test is `tests/test_chain_state.gd`, and `shaft.gd`/`shaft.tscn` stay until 1.7. Keep the rest of the paragraph as it is.
  - [x] `game/README.md:34`: `tests/run_tests.gd` → `tests/test_chain_state.gd`.
  - [x] `docs/`: `architecture.md:181`; `component-inventory.md:9,32,62,71,108,160`; `development-guide.md:41,54`; `index.md:16,79`; `source-tree-analysis.md:34,96,103` plus its tree block. Point each one at the new path. `shaft.gd`/`shaft.tscn` references stay as they are.
- [x] **Task 7: One commit** (AC: 1, 2). Put everything from Tasks 2–6 in one commit:
  - [x] Subject: `refactor: move M1 into the M2 folder layout`. The body lists the 15 moves and rewrites 1–8 from Task 3, so AC2's full path list is in the commit message.
  - [x] Before committing, confirm the staged diff still shows the 15 files as renames: `git diff --cached -M --name-status`.

### Review Findings

Code review 2026-11-12 (gds-code-review; Blind Hunter, Edge Case Hunter, Acceptance Auditor) of `ec561bb..9ecb68c`. The story's own move (`aaf5f22`) passes every AC. Most findings are in `9ecb68c` (`tests/test_deferred_owners.gd`), which the review covered at sonlm's request. Every false pass below was reproduced in a scratch probe.

- [x] [Review][Patch] Items appended at the end of the ledger inherit the last section's owner [game/tests/test_deferred_owners.gd:54-69] — `scan()` gives any column-0 marker line in a section to every item in that section, wherever the line sits. `deferred-work.md` ends with "Mechanic ideas", which has a section-level owner paragraph, so anything `bmad-build` (flat `- source_spec:` blocks) or `gds-quick-dev` appends without a heading counts as owned (probe: 9 items, 0 unowned, PASS). A column-0 `**Closed…**` note placed after a list owns the whole list the same way. **Decided by sonlm 2026-11-12: per-item owners only.** Remove section-level ownership from `scan()`, and give each of the 5 open Mechanic ideas its own `→ **Owner (2026-11-12): the M2 retrospective**` line (the sixth is already Closed). The section-owner test case becomes "a paragraph owner covers nothing".
- [x] [Review][Patch] Owner markers match in the wrong places and miss `(proposed)` [game/tests/test_deferred_owners.gd:38-39,56-61] — four cases: a bold title like `**Closed captions: Deck**` or a backticked `` `**Owner: TBD**` `` makes an item own itself; placeholder values `**Owner: TBD**`, `none` and `?` count as owned; `**Owner: E3 (proposed)**` and `**Closed (proposed): x**` count as confirmed; and the common `**Owner:** E3` style is reported as unowned. Fix: accept a marker only at the start of a line (indent, optional `→`), ignore backticked text, reject placeholder values, detect `(proposed` anywhere inside an Owner or Closed marker, and accept the value after the bold.
- [x] [Review][Patch] Items in other list styles are invisible [game/tests/test_deferred_owners.gd:47-55] — `* `, `+ ` and `1. ` bullets are never counted (items=0, PASS). Lines starting with `#` or `- ` inside fenced code blocks become fake headings and items. Fix: treat `^([-*+]|\d+[.)])\s` as an item, skip fenced blocks, and detect headings with `^#{1,6}\s`.
- [x] [Review][Patch] An unreadable ledger passes [game/tests/test_deferred_owners.gd:118-130] — `get_file_as_string` returns `""` (Edge reproduced this with `chmod 000`), so the scan finds 0 items and the test prints PASS. Also: the not-found message prints `res://../_bmad-output/…`, which is not a real path, and `FAILED (n)` counts one extra failure because the summary check fails as well. Fix: check `FileAccess.get_open_error()`, print the globalized path, and run the summary check only when the list is clean.
- [x] [Review][Patch] A parser regression can skip the rule checks and still pass [game/tests/test_deferred_owners.gd:93,103] — `r.unowned[0]` and `r.unowned[1]` are indexed without a size check. Probe: an out-of-bounds index aborts `_test_scan_rules`, `_test_real_ledger` still runs, the test prints `PASS` and exits 0, and `run_tests.sh` hides the `SCRIPT ERROR` line. Fix: guard both indexes with the list size.
- [x] [Review][Patch] Rewritten layout bullet is garbled and contradicts D1 [docs/source-tree-analysis.md:102] — "share domain folders (`core/ rules/ actors/` …), not next to each other". The original said "not next to their scene", and listing `core/ rules/` implies a `scenes/rules/` folder, which D1 rules out. The "(retired in Story 1.7)" notes on the shaft lines are accurate, so leave them.
- [x] [Review][Patch] Running a single suite after pulling the move fails on a stale cache [docs/development-guide.md:41] — the guide says to run `--import` "once, so textures resolve". With a pre-move `.godot/` cache, a direct `--script` run fails with "Could not find script for class Player" (reproduced by Edge). Fix the comment: re-run the import after pulling moved or renamed scripts, because it rebuilds the `class_name` cache.
- [x] [Review][Patch] The docs don't list `test_deferred_owners.gd` [docs/development-guide.md:39-43, game/README.md:34] — `run_tests.sh` now runs it and it can fail on a ledger edit alone, but no test table or run command names it. Add one row and the single-suite command.
- [x] [Review][Defer] The dev guide's "Writing tests" section is M1 guidance [docs/development-guide.md:53-54] — deferred, pre-existing. It says tests are `extends SceneTree` and that pure rules go into `test_chain_state.gd`; project-context says `tests/test_<subject>.gd` on `runner.tscn`.
- [x] [Review][Defer] The bmad-loop canonical ledger format would switch the gate off [game/tests/test_deferred_owners.gd:47-55] — deferred, latent. `### DW-n` headings with `status:` lines contain no `- ` items, so a `bmad-loop sweep --migrate` leaves 0 items and the test prints PASS.

## Dev Notes

### What this story is (and isn't)

A **pure move**. No logic, tuning, class names or test assertions change. The only content edits are the 8 path lines, one `run_tests.sh` line and the doc path fixes. Every later E1 story assumes this layout. Story 1.2 is next and adds `scripts/core/log.gd`, `clock.gd` and `game.gd`, then moves the tests onto `tests/runner.tscn`.

**Do not, in this story:**
- Add `[autoload]` or `Game`, or change `project.godot` at all. `Game` arrives in 1.2. The architecture's "update the autoload paths in `project.godot`" doesn't apply here, because M1 has no autoloads (AR1).
- Convert tests to `extends Node` or `tests/runner.tscn`. They stay `extends SceneTree` and run with `--script`; 1.2 changes that.
- Move, edit or delete `shaft.gd` or `shaft.tscn`, except rewrites 4–6. Story 1.7 retires them.
- Fix `Fx._unshaded()`. project-context says "fix when touched", but moving a file isn't touching it, and AR3 assigns that work to a later story.
- Re-save any scene in the Godot editor. It adds `uid=` attributes and other noise to the diff. The AC's procedure is hand edits plus `--import`.
- Extract tuning (1.3), replace `Engine.time_scale` writes (1.2) or replace `Input` reads (1.8).

### Current state (read before moving)

- **Code in `game/`:** `scripts/{chain_state,player,crawler,lurker,fx,shaft}.gd`, each with a `.gd.uid`; `scenes/{player,shaft}.tscn`; `scenes/enemies/{crawler,lurker}.tscn`; `tests/{run_tests,smoke_shaft,screenshot}.gd`, each with a `.gd.uid`; `run_tests.sh`; `project.godot`; `README.md`. The rest of `game/` is `art/` (sprite build output plus `.import` files).
- **Class names:** `ChainState` (RefCounted), `Player`, `Crawler` (CharacterBody2D), `Lurker` (Area2D), `Fx` (static). `shaft.gd` and the tests have no `class_name`. `smoke_shaft.gd` and `screenshot.gd` use `Player`, `Lurker` and `ChainState` by class name. That works after the move because `--import` rebuilds `.godot/global_script_class_cache.cfg`, which was verified.
- **No uids in scenes:** the `.tscn` headers are `[gd_scene load_steps=N format=3]` with no `uid=`, and every `ext_resource` is path-only. Godot finds the scripts by path alone, so each path in Task 3 must be exact.
- **Layer boundaries are already clean.** `chain_state.gd` never mentions `Node`, `Input`, `Engine` or `Game`, so it fits `rules/` purity. `fx.gd` references no actor class, so it fits `core/`. Nothing needs changing for the Story 1.9 lint.
- **`run_tests.sh` today:** it re-imports, runs `for t in run_tests smoke_shaft` with `--script`, and greps only the `ok|FAIL|PASS|FAILED` lines. It **hides `ERROR:` lines**, which is why Task 5 greps the raw output separately. Failing on error lines arrives with the 1.9 runner.

### Verified on the server (Godot 4.7.2.stable, dry run in a scratch copy, 2026-11-12)

- Doing this exact procedure, starting from a **stale** `.godot/` cache, gave a clean `--import`: no `ERROR` or `WARNING` lines, and all 5 class-cache entries rewritten to the new paths. `run_tests.sh` was green with the same counts (69 / 28 + SMOKE PASS), the 4 moved or edited scenes and the main-scene boot printed no error lines, and the import modified no tracked file.
- **Missed preload in `shaft.gd`:** smoke fails loudly (`SCRIPT ERROR: Parse Error: Preload file … does not exist`) and `run_tests.sh` prints `== SOMETHING FAILED`.
- **Missed script path in a `.tscn`** (for example `player.tscn`): `smoke_shaft` **hangs** and `run_tests.sh` never finishes. The only evidence is in the raw output: `ERROR: … [ext_resource] referenced non-existent resource`. **Always wrap the runs in `timeout`** (Task 5). A hang means a path was missed; it doesn't mean a slow test.
- A `.gitkeep` file inside `res://` imports without errors. That's relevant only if D1 changes.

### Decisions

- **D1, empty domain folders** (decided by sonlm, 2026-11-12): create only the folders that receive files now (`scripts/rules/`, `scripts/actors/`, `scripts/core/`, `scenes/actors/`). Git can't track empty folders. The architecture's tree also shows that `scenes/` mirrors only the domains that have scenes (`world/ actors/ objects/ ui/`); a `scenes/rules/` folder would never be used. So AC1's folder list is read as the shared naming, and each later story creates its folder when it adds the first file. No `.gitkeep` placeholders.
- **D2, doc paths** (decided by sonlm, 2026-11-12): fix stale paths in the same commit (Task 6). `CLAUDE.md` sends agents to `docs/index.md`, and `project-context.md`'s "Current State" is loaded into every session. If they still named `scripts/chain_state.gd` and `tests/run_tests.gd`, they would mislead Story 1.2's dev agent. Fix paths only; the docs get regenerated later.

### Project Structure Notes

- Target layout: Architecture → Project Structure → Directory Structure. `game/` is `res://`. `scripts/` and `scenes/` share domain folder names, with dependencies `rules/ ← core/ ← world, actors, objects, moments ← ui, audio ← dev` (AR58).
- Naming stays as it is: snake_case files and PascalCase `class_name` matching the file name (`chain_state.gd` → `ChainState`). A scene shares its script's base name (`lurker.gd` / `lurker.tscn`). Tests are named `test_<subject>.gd` (unit) or `smoke_<subject>.gd` (scene); `screenshot.gd` is a helper, not a test.
- Rule from project-context: "Commit `.gd.uid` and `.import` files with their sources; move scripts with `git mv`, then re-import." Its "and re-save moved scenes" part is **replaced for this story** by AC2's hand edits, because the M1 scenes carry no uids. Don't open the editor to re-save them.
- No conflicts with the architecture. The architecture's "update the autoload paths" note doesn't apply (no autoloads in M1; see AR1).

### Project Context Rules (that apply here)

- Godot **4.7.2 stable**, GDScript only, project root `game/`. The editor and templates match on the laptop and the server. No addons, no `.tres`.
- **Before calling it done:** `cd game && ./run_tests.sh` → `== ALL GREEN`. Keep the `ok …` / `FAIL …` + `PASS` / `FAILED` output format. Until the glob runner exists, tests are listed in the `for t in …` loop.
- **Report honestly:** headless tests can't judge feel. This story has no feel change, so the report says "tests green, no behaviour change" and makes no feel claims. sonlm plays builds on the laptop; the server is headless.
- **Never build new M2 work on M1 patterns.** This story only relocates them; their retirement is scheduled in 1.2, 1.3, 1.7 and 1.8 (AR2, AR3).
- **Commit messages:** follow the repo's conventional prefixes (`feat:`, `fix:`, `docs:`, `refactor:`). Comments explain *why*, never restate *what*. This story adds no code comments.

### Git intelligence

- The branch `feat/m2-e1` was cut from `ec561bb` (sprint status). Every commit since M1's last code change (`0e197ca fix: controls bar fits 480 px again`) is planning docs. The M1 code is exactly as playtested on 2026-11-10 (findings: `implementation-artifacts/m1-playtest-findings.md`), so the baseline counts in Task 1 are the M1 behaviour this move must preserve.
- `.godot/` is gitignored, so on the laptop the editor rebuilds its caches on the next open. Nothing to commit for that.

### Cross-story context (Epic 1, CP1)

- **1.2** adds `Log`, `Clock` and `Game` (the first autoload) and moves `test_chain_state.gd`, `smoke_shaft.gd` and `screenshot.gd` onto `tests/runner.tscn` with no assertion changes. It relies on this story's names and paths.
- **1.3** builds `Tuning` from the 44 `@export` vars in the moved `actors/` scripts. **1.5** ports `smoke_shaft` and `screenshot` off `shaft.tscn`. **1.7** deletes `shaft.gd` and `shaft.tscn`. **1.9** adds the glob runner and `test_lint.gd`, which scans `game/scripts/` by these domain folders.
- `tests/test_chain_state.gd` is the spec for chain edge cases (project-context). Its assertions must stay byte-identical.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.1: Move M1 into the M2 folder layout]
- [Source: _bmad-output/planning-artifacts/epics.md#Additional Requirements: AR1, AR2, AR3, AR4, AR58]
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 1 (CP1 Foundations; story types and human gates)]
- [Source: _bmad-output/game-architecture.md#Project Structure: Directory Structure, the "M1 migration" paragraph, Naming Conventions, Architectural Boundaries]
- [Source: _bmad-output/project-context.md#Current State vs Target, Code Organization Rules, Testing Rules]
- [Source: _bmad-output/implementation-artifacts/m1-playtest-findings.md (the M1 behaviour this move must preserve)]
- [Source: _bmad-output/planning-artifacts/implementation-readiness-report-2026-11-12.md#Remediation Log (R17 test runner: why the tests stay on `--script` until 1.2)]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (`claude-opus-5-5`) via gds-dev-story, 2026-11-12.

### Debug Log References

- **Baseline (Task 1, at `ec561bb`):** `run_tests.sh` → `ALL PASS (69 checks)`, 28 `ok` lines, `SMOKE PASS`, `== ALL GREEN`, exit 0.
- **After the moves (Task 2):** `git status` showed 15 `R` entries. `git mv` left an empty `scenes/enemies/` on disk, which was removed with `rmdir`.
- **Verification (Task 5), Godot 4.7.2.stable:** `--import` printed 0 error lines. Each of the 4 scenes loaded with `--quit-after 5`, exit 0, 0 error lines. The main-scene boot (`--quit-after 30`) exited 0 with 0 error lines. Raw `test_chain_state` and `smoke_shaft` runs exited 0 with 0 error lines. The class cache lists all 5 classes at their new paths.
- **After the commit (`aaf5f22`):** `run_tests.sh` → 69 checks, 28 `ok`, 0 `FAIL`, `== ALL GREEN`, exit 0, identical to the baseline.

### Completion Notes List

- Story context created by gds-create-story on 2026-11-12. The analysis covered the epics, the architecture, project-context, the M1 code and a dry run of the procedure on Godot 4.7.2. It is written as a full guide for the dev agent.
- **What was done:** a pure move in one commit (`aaf5f22`): 15 `git mv` renames (5 scripts, 5 `.gd.uid` files, the chain test and its uid, 3 scenes), the 8 hand-edited path lines from the Task 3 table, the `run_tests.sh` loop name, and the D2 doc path fixes. No logic, tuning, class name or assertion changed. `test_chain_state.gd` differs from `run_tests.gd` only in its preload and its `## Run:` comment (97% similarity).
- **Decisions applied:** D1, only the 4 folders that receive files were created (no `.gitkeep`). D2, doc paths were fixed in the same commit; `source-tree-analysis.md`'s tree block and its two layout bullets were updated to the new layout.
- **No new tests, on purpose:** this story adds no behaviour, and AC3 requires `test_chain_state` to stay unchanged. The regression bar is the existing suite at identical counts, plus the raw-output error grep that `run_tests.sh` doesn't do yet (Story 1.9).
- **Left uncommitted on purpose:** this story file and `sprint-status.yaml`. They are tracking artifacts that keep changing through review, and Task 7 scopes the migration commit to Tasks 2–6.
- **Feel:** no behaviour change, so there is nothing to feel-check. sonlm should still open the project once in the laptop editor so its `.godot/` cache rebuilds. Don't re-save the scenes there, which would add `uid=` noise.

### File List

All under the repo root; committed in `aaf5f22` unless marked.

- `game/scripts/rules/chain_state.gd`, `game/scripts/rules/chain_state.gd.uid` (moved from `game/scripts/`)
- `game/scripts/actors/player.gd`, `.gd.uid`; `crawler.gd`, `.gd.uid`; `lurker.gd`, `.gd.uid` (moved from `game/scripts/`)
- `game/scripts/core/fx.gd`, `game/scripts/core/fx.gd.uid` (moved from `game/scripts/`)
- `game/scenes/actors/player.tscn` (moved from `game/scenes/`; script path edited)
- `game/scenes/actors/crawler.tscn`, `game/scenes/actors/lurker.tscn` (moved from `game/scenes/enemies/`; script paths edited)
- `game/tests/test_chain_state.gd`, `game/tests/test_chain_state.gd.uid` (renamed from `run_tests.gd`; preload and comment edited)
- `game/scenes/shaft.tscn` (modified: player scene path)
- `game/scripts/shaft.gd` (modified: two enemy preloads)
- `game/run_tests.sh` (modified: test list)
- `game/README.md`, `docs/index.md`, `docs/component-inventory.md`, `docs/development-guide.md`, `docs/architecture.md`, `docs/source-tree-analysis.md` (modified: paths)
- `_bmad-output/project-context.md` (modified: "Current State vs Target")
- `_bmad-output/implementation-artifacts/1-1-move-m1-into-the-m2-folder-layout.md` (this story; uncommitted)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (status updates; uncommitted)

### Change Log

- 2026-11-12: implemented Story 1.1. M1 moved into the M2 domain folders in one commit (`aaf5f22`) with no behaviour change. Tests are green at the baseline counts. Status set to review.
- 2026-11-12: code review (`ec561bb..9ecb68c`). 1 decision (per-item owners only) and 7 patches applied, nearly all to `tests/test_deferred_owners.gd`: owner markers anchored to the line start, placeholders and `(proposed)` anywhere, all bullet styles, fenced code, unreadable ledger, guarded indexes. Also 5 owner lines added to `deferred-work.md` and 3 doc fixes. 2 items deferred with proposed owners (Stories 1.2 and 1.9). `run_tests.sh` → 69 checks, 21 owner checks, `SMOKE PASS`, `== ALL GREEN`. Status set to done.
