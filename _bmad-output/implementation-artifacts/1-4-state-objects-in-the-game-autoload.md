---
baseline_commit: d71497d
---

# Story 1.4: State objects in the Game autoload

Status: review

**Type:** dev (no human gate; done when every AC passes and `run_tests.sh` is green) · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP1 Foundations (1.1–1.15) · **Branch:** `feat/m2-e1`

## Story

As the developer,
I want `Settings`, `SlotState` and `DiveState` as pure objects that `Game` holds for the whole session,
so that global, per-slot and per-dive state each have exactly one home.

## Acceptance Criteria

1. **Three pure state classes** (AR10, AR14). `scripts/rules/settings.gd` (`Settings`), `slot_state.gd` (`SlotState`) and `dive_state.gd` (`DiveState`):
   - Each `extends RefCounted` and has typed signals, `to_dict()`, `from_dict()` and `reset()`.
   - None mentions `Node`, `Input`, `Engine` or `Game.`, and none does file I/O (`rules/` does none; R15).
   - Fields and API follow Dev Notes → *Settings*, *SlotState* and *DiveState*.
2. **`Game` holds them for the whole session** (AR11).
   - `Game.settings`, `Game.slot`, `Game.dive`, `Game.tuning` and `Game.clock` exist from start-up and stay the same instances all session. Replacing one is an assert (D7).
   - `reset()` and `from_dict()` reset in place and emit their change signals (D2).
   - `Game.reset_for_tests()` restores defaults in place: the three state objects, `tuning.apply_gear([])`, `clock.clear()` and the settings store (D6).
3. **`shaft.gd`'s six statics move into the state objects** (AR2):
   - `best_chain` and `deaths` become `SlotState` records.
   - `checkpoint` becomes the `DiveState` respawn point, which no longer follows M1's per-frame "last ledge stood on". In this story the shaft always respawns at its spawn (`P`). Stations and anchors set the respawn point from Story 1.24. The last-ledge tracker returns only for hazard respawn (Story 1.19).
   - `banked_embers` becomes `DiveState` carried embers.
   - `ambient_index` becomes `Settings` `brightness`.
   - `show_controls` is dropped. The M1 controls bar (`Debug/Controls`) and its F2 key are removed (UX-DR26).
   - `shaft.gd` keeps no `static var`. Until Story 1.7 retires it, it reads and writes this state only through `Game`.
4. **`SlotState.difficulty` and `DiveState`'s killed enemies** (AR13, AR14, AR24):
   - `SlotState` holds `difficulty`, default `&"normal"`. Its death-cost rules arrive in Story 1.22.
   - `DiveState` holds the killed enemies (room id + grid cell), with `mark_killed(room_id, cell)` and `is_killed(room_id, cell)`. `reset()` clears them.
   - They are never saved: `to_dict()` leaves them out and `from_dict()` clears them (architecture decision 5).
5. **Settings persist to `user://settings.json`** (AR14, AR37, R15):
   - `Settings.set_value(&"key", v)` emits `changed(key)` when the value changes.
   - `core/save_store.gd` (`SaveStore`, held as `Game.store`) writes `settings.json` as `{"version": 1, "settings": {…}}`. It writes at most once per frame, into `Game.store.dir`. Tests redirect that folder, so they never touch the real file.
   - A missing or corrupt file, a wrong `version`, or a missing or bad key falls back to the default, and the file is rewritten.
   - Parsing uses `JSON.new().parse()`, which prints no engine error. A corrupt file gives one `push_warning`, never an `ERROR:` line.
   - The game loads the file through `Game.boot()`. The entry scene calls it once (`shaft.gd` for now). Tests never call it (D6).
6. **State is written only through rule methods that emit typed signals** (AR18):
   - `SlotState.set_flag(id, value)` emits `flag_set`, and `DiveState.add_carried(n)` emits `carried_changed`.
   - Reads go through `Game` refs. There is no event bus and no node path.
7. **`tests/test_state.gd`** builds fresh instances per test. It covers round-trips (in memory and through JSON), the killed enemies, the corrupt-file fallback and the other file cases in Dev Notes → *test_state*. No `ERROR:` line appears in the output.
   - Every existing test stays green with its Story 1.3 count, and no existing test file changes.

## Tasks / Subtasks

Run everything from `game/` and wrap every Godot run in `timeout`.

- [x] **Task 1: Baseline** (AC: 7)
  - [x] Run `timeout 500 ./run_tests.sh`. Expect these results (re-run at story creation on `d71497d`):
    - `test_chain_state`: `ALL PASS (69 checks)`
    - `test_log`: 7 `ok` + `PASS`
    - `test_clock`: 15 `ok` + `PASS`
    - `test_tuning`: 85 `ok` + `PASS`
    - `test_deferred_owners`: 22 `ok` + `PASS`
    - `smoke_shaft`: 28 `ok` + `SMOKE PASS`
    - the last line: `== ALL GREEN`
  - [x] Record the counts in the Debug Log.
  - [x] Record whether the real settings file exists: `ls "$HOME/.local/share/godot/app_userdata/The Unbroken Chain (M1 prototype)/"`. At story creation there was none.
- [x] **Task 2: The three state classes** (AC: 1, 4, 6)
  - [x] Create `scripts/rules/settings.gd`, `slot_state.gd` and `dive_state.gd` per Dev Notes → *Settings*, *SlotState*, *DiveState* and D1–D4, D8, D9.
  - [x] Run `godot --headless --path . --import` so the new `class_name`s register (1.1 lesson: the cache goes stale).
  - [x] Create `tests/test_state.gd` with the pure cases and the purity case (Dev Notes → *test_state*).
  - [x] Add `test_state` to the `for t in …` list in `run_tests.sh`, after `test_tuning`.
- [x] **Task 3: `SaveStore` and `Game`** (AC: 2, 5)
  - [x] Create `scripts/core/save_store.gd` per Dev Notes → *SaveStore* (D5).
  - [x] Update `scripts/core/game.gd` per Dev Notes → *Game* (D6, D7).
  - [x] Add the `Game` cases and the settings-file cases to `test_state.gd`.
- [x] **Task 4: Migrate `shaft.gd`** (AC: 3)
  - [x] Follow Dev Notes → *shaft.gd migration* (D10).
  - [x] Hand-edit `scenes/shaft.tscn` to delete the `Controls` label node. Never re-save the scene in the editor.
  - [x] Run `run_tests.sh`. Expect the Task 1 counts plus `test_state`.
- [x] **Task 5: Docs and project-context** (fix facts only; the docs get regenerated later)
  - [x] `docs/architecture.md`:
    - Line 32: `Game` holds `clock`, `tuning`, `settings`, `slot`, `dive` and `store`.
    - Lines 44, 50 and 59: the Debug layer has no Controls hint. `chain.banked` now calls `Game.dive.add_carried()`, and the Communication table row says so.
    - Lines 74–82, "Session state (survives death)": the statics table becomes the `Game` state objects (`Settings.brightness`, `SlotState.best_chain` / `deaths`, `DiveState.carried` and its respawn point), plus `settings.json`.
    - Line 105: Shaft's hotkeys are F1 and F3, and there is no checkpointing.
    - Line 132: a death respawns at `P` with carried embers kept; held embers are still lost.
    - Line 159: F1 cycles `Settings.brightness`, which persists.
    - Gap table, lines 216–222: fix only the M1-column facts (respawn, F2, persistence is `settings.json` only).
  - [x] `docs/component-inventory.md`:
    - Shaft section (lines 98–109): no session statics; the `Debug/Controls` row is gone; the Player row says "spawned at `P`"; the hotkeys are F1 (brightness, saved in `settings.json`) and F3 (restart from the top).
    - Line 141: "F1–F3" becomes "F1 and F3".
    - Core table (line 115): update the `game.gd` row, and add rows for `Settings`, `SlotState`, `DiveState` and `SaveStore`.
  - [x] `docs/development-guide.md`:
    - Line 28: the hotkeys (F2 is gone; F1 now persists).
    - The test list (around line 43): add `test_state.gd`.
    - Line 63, "Reset what you touch": add `Game.reset_for_tests()`. Also say that tests never call `Game.boot()`, and that a test that checks files points `Game.store.dir` at a temp folder it removes.
  - [x] `docs/source-tree-analysis.md`:
    - The tree block: add `scripts/rules/{settings,slot_state,dive_state}.gd`, `scripts/core/save_store.gd` and `tests/test_state.gd`.
    - Line 26: drop "session statics" from `shaft.gd`.
    - Line 36: list `game.gd`'s refs.
  - [x] `docs/index.md` line 17 and `docs/project-overview.md` line 16: "static session state" becomes "session state in pure objects held by the `Game` autoload".
  - [x] `game/README.md`:
    - Controls table: delete the F2 row. F1 reads "Cycle brightness (4 levels; remembered between launches)".
    - Line 27: dying respawns you at the top of the shaft, and F3 also restarts from the top.
    - Tests: add a `test_state.gd` line.
  - [x] `_bmad-output/project-context.md` → "Current State vs Target":
    - Add one sentence after the 1.3 sentence: "Story 1.4 added `Settings`, `SlotState` and `DiveState` in `rules/` and `core/save_store.gd` (`settings.json`), held by `Game` (`boot()`, `reset_for_tests()`); `shaft.gd`'s statics moved into them, and its controls bar and F2 are gone."
    - In the next sentence, "(LAYOUT, statics, F1–F3, scene reload; retired in 1.7)" becomes "(LAYOUT, F1/F3, scene reload; retired in 1.7)".
    - Remove nothing else.
  - [x] `_bmad-output/game-architecture.md` → Data Persistence, the `settings.json` bullet (line 377). Append: "`Game.boot()`, called once by the entry scene (`shaft.gd` until 1.6, then `world.gd`), loads it and arms its writes; tests never boot, and point `Game.store.dir` at a temp folder when they test the file."
- [x] **Task 6: Verify** (AC: 1–7). Every grep below must print nothing, except the two `ls` lines and the final `cat`.
  ```bash
  REAL="$HOME/.local/share/godot/app_userdata/The Unbroken Chain (M1 prototype)/settings.json"
  godot --headless --path . --import 2>&1 | grep -E 'SCRIPT ERROR|ERROR:'
  ls -la "$REAL"                    # before the tests
  for t in test_chain_state test_log test_clock test_tuning test_state test_deferred_owners smoke_shaft; do
    timeout 150 godot --headless --path . res://tests/runner.tscn -- res://tests/$t.gd 2>&1 | grep -E 'SCRIPT ERROR|ERROR:'; done
  ls -la "$REAL"                    # identical: the tests never touched it
  timeout 500 ./run_tests.sh        # Task 1 counts + test_state, ends "== ALL GREEN"
  grep -n "static var" scripts/shaft.gd     # any leftover use of a static is already a parse error above
  grep -nE '\b(Node|Input|Engine)\b|\bGame\.|FileAccess|DirAccess' scripts/rules/settings.gd scripts/rules/slot_state.gd scripts/rules/dive_state.gd
  grep -rnE 'parse_string|ConfigFile|make_dir' scripts/
  grep -nE 'name="Controls"|KEY_F2|_controls' scripts/shaft.gd scenes/shaft.tscn
  git diff --stat d71497d -- tests/test_chain_state.gd tests/test_log.gd tests/test_clock.gd tests/test_tuning.gd tests/test_deferred_owners.gd tests/smoke_shaft.gd tests/screenshot.gd
  # The game's own boot now writes the real file once (that is the game, not a test):
  timeout 60 godot --headless --path . --quit-after 120 2>&1 | grep -E 'SCRIPT ERROR|ERROR:'
  cat "$REAL"                       # {"settings": {"brightness": 1}, "version": 1}, tab-indented
  timeout 120 xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy res://tests/runner.tscn -- res://tests/screenshot.gd <scratchpad>/shots   # exit 0, two PNGs as before
  ```
  - [x] The raw per-test greps also catch exit-time leaks (`ERROR: … leaked at exit`), which print after the runner has finished.
- [x] **Task 7: Commit.** Use conventional prefixes, and leave `run_tests.sh` green at every commit. Suggested split:
  - `feat:` the three state classes and the pure half of `test_state` (Task 2)
  - `feat:` `SaveStore`, the `Game` refs, `boot()` and `settings.json`, with the `Game` and file cases (Task 3)
  - `refactor:` the shaft statics move into `Game`, and the controls bar and F2 go (Task 4)
  - `docs:` (Task 5)
  - Commit each new `.gd.uid` beside its script.

## Dev Notes

### What this story is (and isn't)

It gives every kind of session state one home: pure objects that `Game` holds all session. It moves the six M1 statics into them. It also writes the game's first file, `settings.json`. Gameplay rules don't change, with one intended exception: a death now respawns at the top of the shaft instead of on the last ledge stood on (AC3). M1 finding 6 said stations and anchors should replace the last-ledge respawn, and they arrive in Story 1.24.

**Do not, in this story:**
- **Add slot saves.** That means `slot_N.json`, `.bak`, `meta`, migrations, `save_now()`, `save_progress()`, `new_game`, `load_slot()` and the `save_failed` / `save_succeeded` signals (all Story 1.21). Only `settings.json` is written.
- **Add `SlotState` fields that later stories own:**
  - `deposited` and the Ember Cache (1.22)
  - `visit()` and the map visits (1.7)
  - `gear` and the `Tuning` rebuild (E5)
  - `death_log` and cause ids (1.19 / 1.29)
  - play time and the resume point (1.21)
  - abilities and the journal (E4–E7)
- **Add ember rules beyond `add_carried()`.** Death cost, deposit and the cache are Story 1.22.
- **Add `Settings` keys other than `brightness`** (D1):
  - `light_tap_window` (1.8)
  - `reduce_flashing`, `shake` and `reduced_motion` (1.16)
  - the Cling and Snuff toggles (1.35)
  - volumes (E3)
  - video and bindings (E7)
  - the last slot (1.21 / 1.38)
- **Add `Game.devices`** (1.37: "`core/devices.gd` (held by `Game`)"), DevTools or `--set=` (1.11), or `World` (1.6).
- **Wire `mark_killed()` into the crawler, or skip killed enemies at build** (1.6 / 1.7). The shaft still reloads on death and rebuilds every enemy.
- **Remove F1, F3 or `reload_current_scene()`** (1.7). Only F2 goes, with the controls bar.
- **Change a tuning value or any existing test.**

### Current state (read before changing)

- **`core/game.gd` (13 lines):**
  - `var clock := Clock.new()`, added as a child named `"Clock"` in `_init()`, and `var tuning := Tuning.new()`.
  - Its header says "Story 1.4 adds settings, slot, dive and devices". `devices` belongs to Story 1.37 (AR35), so fix the header.
- **`shaft.gd` (270 lines), the six statics at lines 18–23:**
  - `ambient_index`: `_apply_ambient()` (line 240) and F1 (line 229).
  - `show_controls`: `_ready` (line 149) and F2 (lines 232–233). It toggles the `Debug/Controls` label in `shaft.tscn`, read through `@onready var _controls`.
  - `best_chain`: `_process` takes the max every frame (line 246), and the HUD label shows it (lines 253–255).
  - `deaths`: `_on_player_died` (line 260) and the HUD.
  - `checkpoint`:
    - `_ready` places the player there if it is finite (lines 152–153).
    - `_process` overwrites it every frame the player stands on the floor (lines 247–248).
    - F3 clears it (line 235).
  - `banked_embers`: a lambda on `chain.banked` in `_ready` (line 155), and the HUD.
  - **Death:** `_on_player_died` adds a death and waits 0.6 s of real time. It reloads only if the shaft is the current scene; test harnesses add the shaft by hand.
- **Nothing outside `shaft.gd` reads the statics** (grep over `tests/` and `scripts/` at `d71497d`).
  - `smoke_shaft.gd` and `screenshot.gd` instance `shaft.tscn` under `tests/runner.tscn`, so there `get_tree().current_scene` is the runner, not the shaft.
- **`ChainState` signals:** `changed(count)` fires on every count change. `banked(amount)` fires on a safe break with `held > 0`. `lose()` emits neither.
- **`Player.die()`** calls `Game.clock.clear()` and `chain.lose()`, then emits `died`.
- **`Tuning`** has no `to_dict()` (Story 1.3 D6). Its reset in place is `apply_gear([])`.
- **No `user://settings.json` exists on the server.**

### Decisions

These are story-author decisions; sonlm can veto any of them before dev.

- **D1, `Settings` holds only `brightness` in this story.** Each later story adds its own key (the Story 1.3 rule: "Each story adds its own keys"), as one `SCHEMA` entry plus one typed var. A new key needs no version bump, because a missing key falls back to its default.
- **D2, signal semantics.** One rule for all three classes:
  - **A write emits only when the value changes.** For example, `set_value()` with the current value, `set_flag()` on a set flag, `add_carried(0)`, or `record_chain()` below the best all emit nothing.
  - **`reset()` and `from_dict()` emit every value signal once, with the new value, whether or not it changed.** A subscriber therefore always refreshes after a load. Examples: `Settings.changed(key)` per key, `records_changed`, `difficulty_changed`, `carried_changed` and `respawn_changed`.
  - **Per-id signals fire for each id whose value changed.** `flag_set(id, false)` fires for each flag a reset clears, and `flag_set(id, true)` for each flag a load adds.
  - **Clearing the killed enemies emits nothing.** Nothing draws them: the room is rebuilt after a reset (1.24) or a load.
- **D3, `from_dict()` never asserts on data.** File data can be hand-edited or corrupt, so it is an environment error, not a programmer error.
  - A missing or bad field takes its default. Unknown keys are ignored.
  - It returns `bool`: `true` when every field was present and valid. `Game` uses it to decide on a rewrite. 1.21 can use it to warn about a slot.
  - **JSON numbers come back as `float`** (verified). An int field accepts a float only if it is whole (`v == floorf(v)`), stored as `int(v)`.
  - String fields accept `String` or `StringName` and are stored as `StringName`.
  - Programmer errors in writes are asserts: `set_value()` with an unknown key or a bad value, `set_difficulty()` with an unknown tier, `add_carried()` with a negative amount, and replacing a `Game` ref.
- **D4, `to_dict()` shapes.** They are JSON-ready and become the start of save format `slot_v1`, which freezes at Story 1.41. Until then the key names may still change; after it, never.
  - `SlotState`: `{"best_chain": int, "deaths": int, "difficulty": "normal", "flags": ["anchor_m1_1", …]}`. Flags are a list of the ids that are set, **sorted as `String`s**. `Array.sort()` on `StringName`s is not alphabetical (verified: `beta, anchor_m1_1, mid, anchor_m1_2, zeta`).
  - `DiveState`: `{"carried": int, "respawn_room": "", "respawn_entry": ""}`. **No killed enemies** (decision 5: an anchor quit saves the anchor and carried embers, and enemies come back).
  - `Settings`: `{"brightness": 1}`. `SaveStore` wraps it as `{"version": 1, "settings": {…}}`.
- **D5, `SaveStore`** is the architecture's `core/save_store.gd` (AR37). Story 1.21 adds the slot files to it instead of creating another file.
  - It is an instance with a redirectable `dir`, which 1.21's "save directory is injectable" also needs.
  - It reads and writes JSON and returns errors. It never decides when to write; `Game` does.
  - It **never creates folders**. A failed `DirAccess.make_dir_recursive_absolute()` prints an engine `ERROR:` (verified), and `user://` always exists.
- **D6, boot and arming.** `Game` doesn't touch files when it starts up.
  - `Game.boot()` runs once per session. It loads `settings.json` and arms its writes, and Story 1.21 adds the slot load to it.
  - The game's entry scene calls it first thing in `_ready()`, behind `if get_tree().current_scene == self:` (verified true in the main scene's `_ready()`). Test harnesses that instance the shaft are never the current scene, so tests can't touch the real file even through the shaft.
  - Until `load_settings()` runs, settings changes write nothing. `reset_for_tests()` disarms the writes again and points the store back at `user://`.
  - *Why not load in `Game._ready()`:* autoloads are ready before the test runner exists, so the runner could not redirect the folder in time. A missing file would also be rewritten into the real `user://` on every test run.
- **D7, the `Game` refs refuse replacement.** Each of `settings`, `slot`, `dive`, `tuning` and `clock` gets a setter that only asserts: `set(_value): assert(false, "Game.slot is session-long: reset it in place, never replace it")`.
  - A member's initializer doesn't call its setter (verified), so the instance created at start-up stays. An assignment from outside fails loudly in debug and is ignored in release.
  - This guards the one mistake project-context warns about: subscribers would keep listening to the old object.
- **D8, difficulty ids** are `StringName`s: `&"easy"`, `&"normal"` and `&"hard"` (`SlotState.DIFFICULTIES`). They read well in the JSON, and they match DevTools' `--difficulty=easy|normal|hard` (1.22) and the `TIER_*` string keys (1.36 / 1.38).
- **D9, the respawn point** is `respawn_room` + `respawn_entry`, two `StringName`s, set by `set_respawn(room_id, entry)`.
  - They match 1.7's `enter_room(room_id, entry)` and 1.5's `room.entry_position(entry)`. An anchor or station id is an entry (1.24).
  - Empty means none is set yet: the dive's start room spawn. 1.6 decides how that resolves.
  - Nothing calls `set_respawn()` in this story, because the shaft only has its spawn.
- **D10, the shaft's behaviour after this story:**
  - Death respawns at `P`.
  - Carried embers and the records survive the reload, because `Game` does; held embers are still lost.
  - F1 cycles `Settings.brightness`, which is now saved between launches.
  - F3 just reloads, which is still "restart from the top".
  - F2 and the controls bar are gone.
  - The HUD label reads `Game`.

### Settings (`scripts/rules/settings.gd`, `class_name Settings`, `extends RefCounted`)

- **Header:**
  - Global, per-machine settings (AR14). The values are read directly (`Game.settings.brightness`) and written only through `set_value()`.
  - `rules/` does no file I/O. `core/save_store.gd` persists the settings, and the session's instance in `core/game.gd` decides when (R15).
  - Write "the session's instance lives in `core/game.gd`", never the autoload's name.
- **`signal changed(key: StringName)`.**
- **`const SCHEMA := {&"brightness": {default = 1, choices = [0, 1, 2, 3]}}`**, commented as "every key, its default and the values it may take; a later story adds its key here plus a typed var of the same name."
- **`var brightness := 1`**, commented as: the index of the world's ambient level (4 levels, UX A1 / R1); 1 is the M1 default (`shaft.gd`'s `ambient_index := 1`); it changes only the world's ambient level, never light radii or what predators sense (architecture → UI → Brightness).
- **`set_value(key: StringName, v: Variant) -> void`:**
  - Assert the key is in `SCHEMA` and `_valid(key, v)`.
  - If `get(key) == v`, return.
  - Otherwise `set(key, v)` and `changed.emit(key)`.
- **`to_dict() -> Dictionary`:** `{key: value}` for each `SCHEMA` key.
- **`from_dict(d: Dictionary) -> bool`:**
  - For each `SCHEMA` key, read `d.get(key)`. A `StringName` lookup finds a `String` key (verified).
  - Coerce a whole float to `int` when the default is an int.
  - If the value is missing or `_valid()` fails, use the default and remember that the data wasn't clean.
  - Set every key first, then emit `changed(key)` for each key, and return whether the data was clean.
- **`reset()`:** every key to its default, then `changed(key)` for each.
- **`_valid(key, v)`:** `typeof(v) == typeof(default) and v in choices`. The `typeof` check comes first, so `true` never passes for `1` (they are different types; verified).

### SlotState (`scripts/rules/slot_state.gd`, `class_name SlotState`, `extends RefCounted`)

- **Header:**
  - Per-slot state, reset by New Game / Load (AR10, AR14).
  - List the fields later stories add (see "Do not").
  - Note that `to_dict()` becomes save format `slot_v1` at Story 1.41, when its key names freeze.
- **Signals:** `flag_set(id: StringName, value: bool)`, `records_changed`, `difficulty_changed(difficulty: StringName)`.
- **`const DIFFICULTIES: Array[StringName] = [&"easy", &"normal", &"hard"]`.** Difficulty changes only what death costs (GDD Difficulty; FR25). The rules arrive in 1.22.
- **Fields:**
  - `var best_chain := 0` and `var deaths := 0` (Guild records, GDD Hub)
  - `var difficulty: StringName = &"normal"`
  - `var _flags: Dictionary[StringName, bool] = {}`, holding only the flags that are set
- **`set_flag(id: StringName, value := true) -> void`:**
  - If there is no change, return.
  - `true` stores the id and `false` erases it.
  - Emit `flag_set(id, value)`.
  - Its first callers are the lit anchors and stations (1.24).
- **`has_flag(id: StringName) -> bool`.**
- **`record_chain(count: int)`:** if `count > best_chain`, set it and emit `records_changed`.
- **`record_death()`:** `deaths += 1`, then emit `records_changed`. Story 1.19 adds the cause and room for `death_log`.
- **`set_difficulty(tier: StringName)`:**
  - Assert that `tier` is in `DIFFICULTIES`.
  - If there is no change, return.
  - Otherwise set it and emit `difficulty_changed(tier)`.
  - It doesn't save. The progress save on a difficulty change belongs to its caller (1.21 / 1.36).
- **`to_dict()`, `from_dict(d) -> bool` and `reset()`** follow D2–D4. On a bad field, `from_dict()` falls back like this:
  - `best_chain` / `deaths`: a whole number ≥ 0, else 0.
  - `difficulty`: one of the three, else `&"normal"`.
  - `flags`: an `Array`; a non-string entry is skipped, and a non-array means no flags. Either one makes the data unclean.

### DiveState (`scripts/rules/dive_state.gd`, `class_name DiveState`, `extends RefCounted`)

- **Header:**
  - Per-dive state, reset on a rest, on arriving home and on leaving the layer (AR10, AR14).
  - Killed enemies are never saved (decision 5).
  - Carried embers stay at risk until a station (GDD Economy; the rules arrive in 1.22).
- **Signals:** `carried_changed(carried: int)`, `respawn_changed(room_id: StringName, entry: StringName)` and `killed_marked(room_id: StringName, cell: Vector2i)`. `killed_marked` has no subscriber yet; it exists because every write emits (AR18).
- **Fields:**
  - `var carried := 0`
  - `var respawn_room: StringName = &""` and `var respawn_entry: StringName = &""` (D9)
  - `var _killed := {}`: room id → `{Vector2i: true}`. A `Vector2i` works as a dictionary key (verified).
- **`add_carried(n: int)`:**
  - Assert `n >= 0`, and return on 0.
  - Otherwise `carried += n` and emit `carried_changed(carried)`.
  - M1's `banked` is M2's carried (project-context vocabulary).
- **`set_respawn(room_id: StringName, entry: StringName)`:** if there is no change, return. Otherwise set both and emit `respawn_changed`.
- **`mark_killed(room_id: StringName, cell: Vector2i)`:** if the cell is already marked, return. Otherwise store it and emit `killed_marked`.
- **`is_killed(room_id: StringName, cell: Vector2i) -> bool`.**
- **`to_dict()`** has no killed enemies (D4).
- **`from_dict(d) -> bool`** clears the killed enemies. `carried` must be a whole number ≥ 0, and the respawn fields are strings.
- **`reset()`** sets carried to 0 and clears the respawn point and the killed enemies. It emits `carried_changed(0)` and `respawn_changed(&"", &"")` (D2).

### SaveStore (`scripts/core/save_store.gd`, `class_name SaveStore`, `extends RefCounted`)

- **Header:**
  - The only code that reads or writes the player's files. AR18: nothing reads files outside `core/` and `world/room_loader.gd`.
  - In this story it handles `settings.json`. Story 1.21 adds the slots.
  - Parse with `JSON.new().parse()` only. `JSON.parse_string()` and `ConfigFile` print an engine `ERROR:` on bad input (R15).
- **Consts and fields:**
  - `const SETTINGS_VERSION := 1`
  - `const DEFAULT_DIR := "user://"`
  - `var dir := DEFAULT_DIR`, the folder it reads and writes. Tests point it at a temp folder they create and remove.
- **`settings_path() -> String`:** `dir.path_join("settings.json")`.
- **`read_settings() -> Variant`:** returns the inner `settings` dictionary, or `null` when nothing usable is there.
  - Check `FileAccess.file_exists()` first. A missing file means first launch: return `null` silently. Never use `FileAccess.get_file_as_string()`, which prints an error on a missing file.
  - Open with `FileAccess.open()`. `null` → one `push_warning`, then return `null`.
  - `push_warning` once and return `null` when the text doesn't parse, the top level isn't a `Dictionary`, `version` isn't a number equal to `SETTINGS_VERSION`, or `settings` isn't a `Dictionary`. `version` arrives as `1.0` (a float).
  - A newer `version` is treated like a corrupt file: defaults, then a rewrite. There is no settings migration yet; the first change to a key's meaning bumps the version and adds one.
- **`write_settings(data: Dictionary) -> Error`:**
  - Write `JSON.stringify({"version": SETTINGS_VERSION, "settings": data}, "\t")` to `settings_path() + ".tmp"`.
  - Then call `DirAccess.rename_absolute(tmp, settings_path())`, which replaces the old file (verified), so a crash mid-write leaves the old file whole.
  - Return the first error: `FileAccess.get_open_error()` when the open returns `null`, or the rename's error.
  - On success, `Log.info(Log.SAVE, "settings written")`.

### Game (`scripts/core/game.gd`, the autoload, no `class_name`)

- **Header:** refs to session-long state and the commands that load it, never rules (AR11). Keep the existing note that gear changes call `tuning.apply_gear()`. `devices` arrives with Story 1.37.
- **Refs**, in this order, each guarded per D7:
  - `settings := Settings.new()`
  - `slot := SlotState.new()`
  - `dive := DiveState.new()`
  - `tuning := Tuning.new()`
  - `clock := Clock.new()`
  - then `var store := SaveStore.new()`, which is not guarded: tests change its `dir`, never the instance.
- **Private state:** `_booted`, `_settings_armed` and `_settings_write_queued` (bools).
- **`_init()`:** keep the Clock child, and connect `settings.changed` to `_on_settings_changed`.
- **`boot() -> void`:** if already booted, return; otherwise set `_booted` and call `load_settings()`. The comment says Story 1.21 adds "load slot 1 if present".
- **`load_settings() -> void`:**
  1. Disarm writes, so `from_dict()`'s own `changed` signals queue nothing.
  2. `var stored: Variant = store.read_settings()`.
  3. `var clean := settings.from_dict(stored if stored is Dictionary else {})`.
  4. Arm writes.
  5. If `stored == null or not clean`, queue a write.
  - Decide the rewrite with `from_dict()`'s result, never by comparing dictionaries: `{"a": 1} == {"a": 1.0}` is false (verified).
- **`_on_settings_changed(_key)`:** if armed, queue a write.
- **Queue a write:** if one is already queued, return. Otherwise mark it queued and call `_write_settings.call_deferred()`, so there is at most one write per frame.
- **`_write_settings()`:**
  - Clear the queued flag. If writes are disarmed, return: `reset_for_tests()` may have disarmed them after the queue.
  - Call `store.write_settings(settings.to_dict())`. On an error, `push_warning` once per failed write (Architecture → Error Handling: environment errors), and never crash or pause.
- **`reset_for_tests() -> void`, in this order:**
  1. Disarm writes.
  2. `settings.reset()`, `slot.reset()`, `dive.reset()`.
  3. `tuning.apply_gear([])` and `clock.clear()`.
  4. `store.dir = SaveStore.DEFAULT_DIR`.
  - It leaves `_booted` alone, because tests never boot.

### shaft.gd migration

- **Delete** the six statics (lines 18–23) and `@onready var _controls`.
  - Keep `AMBIENT_LEVELS` and `AMBIENT_TINT`. They are presentation: the world applies the level and takes the consts in 1.6 / 1.7.
  - Its comment becomes: "`Settings.brightness` picks the level; F1 cycles it until Options (1.36)".
  - Update the class header: session state lives in `Game` now.
- **`_ready()`:**
  - Start with `if get_tree().current_scene == self: Game.boot()`. The comment explains why (D6): the entry scene boots once, and a test harness that adds the shaft by hand never does, so tests can't touch the real `settings.json`.
  - Then `_apply_ambient()`, and `Game.settings.changed.connect(_on_setting_changed)`. Connect a method, not a lambda: the connection drops when the shaft is freed (verified).
  - Delete `_controls.visible = show_controls` and the checkpoint placement (lines 152–153). The player stays where `_build()` put it, at `P`.
  - `_player.chain.banked.connect(_on_banked)`, which calls `Game.dive.add_carried(amount)`.
  - `_player.chain.changed.connect(_on_chain_changed)`, which calls `Game.slot.record_chain(count)`. That replaces the per-frame `maxi`.
- **`_on_setting_changed(key)`:** if `key == &"brightness"`, call `_apply_ambient()`.
- **`_apply_ambient()`:** use `AMBIENT_LEVELS[Game.settings.brightness]`.
- **`_unhandled_input()`:**
  - F1 is `Game.settings.set_value(&"brightness", (Game.settings.brightness + 1) % AMBIENT_LEVELS.size())`. The signal applies it; don't call `_apply_ambient()` directly.
  - Delete the F2 branch.
  - F3 is `get_tree().reload_current_scene()` alone, with the comment "restart from the top".
- **`_process()`:**
  - Delete the `best_chain` and `checkpoint` lines.
  - The label reads `Game.dive.carried`, `Game.slot.best_chain` and `Game.slot.deaths`.
  - Keep `_deepest` (an instance var, as in M1).
- **`_on_player_died()`:** call `Game.slot.record_death()` first. The rest is unchanged.
- **`scenes/shaft.tscn`:** delete the 8-line `[node name="Controls" type="Label" parent="Debug"]` block. No `ext_resource` changes, so `load_steps` stays the same.
- **Behaviour check (feel):**
  - Respawn is now at the top. That is intended (AC3).
  - Brightness survives a restart of the game.
  - The bottom controls hint is gone; its contents move to the Pause tab in 1.34.

### test_state (`tests/test_state.gd`)

Use the same harness as `test_tuning`: `extends Node`, `func run()`, a local `check()`, and a final `PASS` / `FAILED (n)`. Build fresh `Settings.new()`, `SlotState.new()` and `DiveState.new()` for each pure case. Count signals with lambdas that capture an array, as `test_tuning` does. Only the `Game` and file cases use `Game`, and they end with `Game.reset_for_tests()`.

- **`Settings`:**
  - Defaults: `brightness == 1`, and `to_dict()` is `{brightness: 1}`.
  - `set_value(&"brightness", 3)` sets 3 and emits `changed` once, with `&"brightness"`. The same value again emits nothing.
  - `reset()` restores 1 on the same instance and emits.
  - Round trip in memory: `from_dict(to_dict())` returns true and keeps the value.
  - Round trip through JSON: `JSON.stringify`, then `JSON.new().parse()`, then `from_dict()`. It returns true, the value is kept, and `typeof(brightness) == TYPE_INT`.
  - Fallbacks: `{}`, `{brightness: "bright"}`, `7`, `2.5` and `true` each return false and give the default.
  - A valid value plus an unknown key returns true.
  - `from_dict()` emits `changed` for every key.
- **`SlotState`:**
  - Defaults: 0 / 0 / `&"normal"`, no flags.
  - `set_flag(&"anchor_m1_1")` makes `has_flag()` true and emits `(id, true)` once. Setting it again emits nothing. `set_flag(id, false)` clears it and emits `(id, false)`.
  - `record_chain(5)` raises the best and emits once. `record_chain(3)` emits nothing. `record_death()` twice gives 2.
  - `set_difficulty(&"hard")` emits once; the same tier again emits nothing.
  - Round trips in memory and through JSON keep the flags, records and difficulty. After JSON, `typeof(difficulty) == TYPE_STRING_NAME` and the flags still answer `has_flag()`.
  - `to_dict().flags` is sorted: set `zeta` then `anchor_m1_1`, and get `["anchor_m1_1", "zeta"]`.
  - Fallbacks: a `"medium"` difficulty, a `-1` or `"x"` record, and a `flags` value that isn't an array each return false and give the default.
  - D2 signals:
    - `reset()` and `from_dict()` emit `records_changed` and `difficulty_changed` once each.
    - A reset emits `flag_set(id, false)` for each flag it clears.
    - A load emits `(id, true)` for each new flag, and nothing for a flag it doesn't change.
- **`DiveState`:**
  - `add_carried(5)` gives 5 and emits `carried_changed(5)`. `add_carried(0)` emits nothing. `add_carried(3)` emits 8.
  - Killed enemies:
    - after `mark_killed(&"m1_shaft", Vector2i(3, 4))`, `is_killed()` is true for that cell
    - false for the same cell in `&"other_room"` and for `Vector2i(4, 3)`
    - `killed_marked` fires once; marking the cell again emits nothing
  - `reset()` on the same instance:
    - carried becomes 0, and the respawn point and killed enemies are cleared
    - it emits `carried_changed(0)` and `respawn_changed`
  - `to_dict()` has no key holding the killed enemies.
  - `from_dict(to_dict())` keeps carried and the respawn point (set with `set_respawn`) and clears the killed enemies.
  - The JSON round trip gives the same result.
  - Fallbacks: a negative or fractional `carried` returns false and gives 0.
- **`Game`:**
  - `Game.settings is Settings`, `Game.slot is SlotState`, `Game.dive is DiveState` and `Game.store is SaveStore`. The `tuning` and `clock` types are already covered.
  - Same instances: keep refs to all five, call `reset_for_tests()`, then `from_dict()` on each state object, and check `is_same()` for all five.
  - `reset_for_tests()` restores defaults in place. Change each of these first:
    - the brightness
    - a flag, a record and the difficulty
    - carried, a killed cell and the respawn point
    - a Clock request (`Game.clock.request(&"probe", 0.5, 1.0)`)
  - After the reset, check: all defaults back, `Engine.time_scale == 1.0`, `not Game.clock.is_active(&"probe")`, and `Game.store.dir == SaveStore.DEFAULT_DIR`.
- **Settings file** (through `Game`, with `Game.store.dir = TMP` and `const TMP := "user://test_state_tmp"`):
  - **Setup:**
    - Remove any leftovers from an aborted run.
    - `DirAccess.make_dir_recursive_absolute(TMP)` (it succeeds, so it prints nothing).
    - Record whether the real `user://settings.json` exists, and its text.
  - **Read files only after `FileAccess.file_exists()`.**
  - The cases:
    - **Missing file:** `Game.load_settings()` gives the defaults. Nothing is written in the same frame. After `await get_tree().process_frame`, the file parses with `version` 1 and `brightness` 1.
    - **Corrupt file** (`{not json`): defaults, then a valid rewrite after a frame. The one `WARNING:` is allowed. The runner fails the test on any `ERROR:`, which proves the parse is silent.
    - **Wrong version** (`{"version": 2, "settings": {"brightness": 2}}`): defaults, then rewritten as version 1.
    - **Missing key** (`{"version": 1, "settings": {}}`) and **bad key** (`"brightness": "bright"`): the default, then rewritten with the key.
    - **A valid file is kept.** For `{"version": 1, "settings": {"brightness": 3}, "keep": true}`: brightness is 3 (an int), and after a frame the file still contains `"keep"`, so it was not rewritten.
    - **One write per frame:** two `set_value` calls in one frame write nothing in that frame. After a frame the file holds the second value. Delete it; after another frame it is still gone, so only one write was queued.
    - **Failed write:** writes are still armed from the cases above. Set `Game.store.dir = TMP.path_join("missing")` (a folder that doesn't exist), then call `set_value()` and wait a frame. Expect no crash, no `ERROR:` and nothing created, and the value is still set in memory. `FileAccess.open()` for writing in a missing folder returns `null` silently (verified).
    - **Unarmed:** call `Game.reset_for_tests()`, then point `Game.store.dir` back at `TMP` *without* loading. Delete the temp file and call `set_value()`. After a frame, nothing was written. This shows that tests that never load settings write nothing. Re-pointing the folder first means a bug here writes into the temp folder, never the real one.
    - **`boot()` runs once:** with `Game.store.dir = TMP` and a file holding `brightness` 2, `Game.boot()` loads 2. Rewrite the file with 3 and call `boot()` again: still 2. A test process may boot, because each test runs in its own Godot process and the folder is redirected first.
  - **Teardown:**
    - `Game.reset_for_tests()`.
    - Remove the temp files, including any `.tmp`, and the folder; check that it is gone.
    - Check that the real `user://settings.json` is exactly as it was at the start (same existence, same text).
- **Purity:** read the three `rules/` files with `FileAccess.get_file_as_string()`, and check that `get_open_error() == OK` (an unreadable file must fail, never pass). Check that they contain nothing matching:
  - `\b(Node|Input|Engine)\b|\bGame\.` (the `test_tuning` regex)
  - `FileAccess|DirAccess` (no file I/O in `rules/`). "JSON" in a comment is fine, for example "JSON numbers come back as floats".
  - The scan covers comments too: write "node-free", never "Node".
- **Not unit-tested,** because a failed assert aborts the test: the unknown-key, bad-value, unknown-tier and negative-carried asserts, and the `Game` ref guards. Code review checks them, as with `Tuning`'s asserts.

### Verified on the server (Godot 4.7.2.stable, probes plus a prototype in a scratch copy of `game/` at `d71497d`, 2026-11-12)

- **JSON:**
  - `JSON.new().parse("{not json")` and `parse("")` return `ERR_PARSE_ERROR` (43) and print nothing.
  - Numbers come back as `float`: `{"a": 1}` gives `1.0`, and `int(2.0) == 2`.
  - `JSON.stringify(d, "\t")` sorts keys and writes `StringName` keys as strings, an int as `1` and a float as `2.0`. Typed dictionaries stringify fine.
- **Dictionaries:**
  - `String` and `StringName` keys are interchangeable: `{"a": 1}.has(&"a")` and the reverse are both true, so `from_dict()` can look up parsed JSON with `&"key"`.
  - **`{"a": 1} == {"a": 1.0}` is false.** Never decide on a rewrite by comparing a parsed dictionary with `to_dict()`.
  - A `Vector2i` key works, including when nested under a `StringName` room key.
  - **`Array.sort()` on `StringName`s is not alphabetical.** Sort flag ids as `String`s.
- **Files:**
  - On a missing file, `FileAccess.file_exists()` returns false, and `FileAccess.open(…, READ)` returns `null` with `ERR_FILE_NOT_FOUND` (7), silently.
  - Opening for write inside a missing folder returns `null` with error 12, silently.
  - `DirAccess.rename_absolute(tmp, existing)` replaces the target (Linux).
  - `DirAccess.remove_absolute()` on a missing path returns `FAILED` silently, and removes an empty folder.
  - **A failed `DirAccess.make_dir_recursive_absolute()` prints an engine `ERROR:`.**
- **GDScript:**
  - A member var's initializer doesn't call its setter; an outside assignment does.
  - `get_tree().current_scene == self` is true in the main scene's `_ready()`.
  - A signal connected to a node's method is dropped when the node is freed. Emitting afterwards prints nothing, and the connection count is 0.
  - A `call_deferred` write queued twice behind a flag runs once, before the next `process_frame` await returns.
  - `typeof(true) != typeof(1)`.
  - `Settings`, `SlotState`, `DiveState` and `SaveStore` aren't engine class names.
- **Prototype**, through `tests/runner.tscn`: a `Game` with a guarded `settings` and a `SaveStore` redirected to `user://test_state_tmp`.
  - The corrupt file gave the defaults and one `WARNING:`, with no `ERROR:`. The rewrite landed one frame later.
  - A valid file with an extra key was not rewritten.
  - Two changes in one frame made one write, and after `reset_for_tests()` nothing was written.
  - The temp folder was removed, the real `user://settings.json` was untouched, and the runner exited 0.
  - The prototype was only the `brightness` path; `SlotState`, `DiveState` and the shaft migration were not prototyped.
- **A scratch copy of `game/` shares the real `user://` folder** (`~/.local/share/godot/app_userdata/The Unbroken Chain (M1 prototype)/`), because its `config/name` is the same. Prototype only against a redirected `store.dir`.

### Project Structure Notes

- **New files:**
  - `scripts/rules/settings.gd`, `slot_state.gd` and `dive_state.gd`: pure and unit-tested (AR10, AR58).
  - `scripts/core/save_store.gd` (AR37).
  - `tests/test_state.gd`.
  - The `.gd.uid` files from `--import`. Never hand-create a `.uid` file.
- **Changed files:** `scripts/core/game.gd`, `scripts/shaft.gd`, `scenes/shaft.tscn` (the Controls node, removed by hand) and `run_tests.sh`.
- **Dependencies point one way:**
  - `rules/` ← `core/` (`Game`, `SaveStore`) ← `shaft.gd`.
  - `SaveStore` names no class above `core/`.
  - `rules/` has no file I/O.
- **Naming:**
  - PascalCase `class_name` matching each file.
  - `StringName` ids (`&"brightness"`, `&"normal"`, `&"anchor_m1_1"`).
  - Signals in past tense or ending in `_changed`.
  - Private members start with `_`.
- **`Game.store` is an addition** to AR11's list of refs (`settings, slot, dive, tuning, clock, devices`). It is core plumbing, not state, so it holds no rules and has no setter guard.
- No addon, no `.tres` and no new autoload.

### Project Context Rules (that apply here)

- **State:**
  - It lives in pure objects, never in nodes or statics.
  - `Game` keeps the same instances all session and resets them in place with `from_dict()` / `reset()`. Never replace `Game.slot` or `Game.dive`.
  - `Game` holds refs only, never rules.
- **Writes:**
  - State is written only through rule methods that emit typed signals (`Game.slot.set_flag(id)`, `Game.dive.add_carried(n)`).
  - There is no event bus. UI writes only `Settings`.
- **Saves:**
  - Parse all JSON with `JSON.new().parse()`. `JSON.parse_string()` and `ConfigFile` print engine `ERROR:` lines, which fail the runner.
  - `settings.json` is separate from the slots and has its own `version`.
  - Failures never crash or pause; they surface as a warning here, and as UX states later.
- **Dependencies:** `rules/` never mentions `Node`, `Input`, `Engine` or `Game`. Story 1.9's lint will enforce it; `test_state` enforces it now.
- **Errors:**
  - Programmer errors are `assert`s.
  - Environment errors return an `Error`, then `push_warning` (allowed by the runner).
  - `queue_free()`, never `free()`.
  - No bare `print(`: use `Log.info(Log.SAVE, …)`.
- **Comments** explain *why* and cite the design: "AR14", "R15", "decision 5", "M1 finding 6", "D6".
- **Tests:**
  - Add `test_state` to the `for t in …` list (1.9's glob comes later).
  - Fresh state objects per test.
  - Keep the `ok` / `FAIL` + `PASS` / `FAILED` format.
  - Never loosen a threshold to pass.
- **Vocabulary:** M1 "banked" is M2 "carried", and M2 adds "deposited" (1.22).
- **Feel:** report "tests green; needs a feel check on the laptop (death now respawns at the top until anchors land in 1.24; brightness persists; the controls hint is gone)". Never claim it feels the same.
- **Commits:** commit `.gd.uid` files with their scripts.

### Previous story intelligence (1.3 and its review)

- **`Tuning`:**
  - `apply_gear([])` is its reset in place (1.3 D6). `reset_for_tests()` calls it.
  - Its gear ids will live in `SlotState.gear` from E5, which is not this story.
- **The review's lessons:**
  - Validate every row of a table, not only the rows in use.
  - Comments carry an intent clause.
  - Headers must not overclaim; say exactly what the class does now and which story adds the rest.
- **`test_tuning`'s literal scan:**
  - `\bf\(&"(\w+)"\)` over `scripts/`: every match must be a `BASE` key. Never name a method `f` on the new classes.
  - Its file count check (`>= 6`) only grows with new files.
- **The purity regex matches words in comments.** Write "node-free" and "the session's instance lives in `core/game.gd`", never "Node" or "Game.".
- **`assert` messages are evaluated eagerly in debug builds** (1.3 Debug Log). None of these writes is a hot path. `record_chain` runs once per chain change, which is fine.
- **Test hygiene:**
  - Free every node a test creates. Exit-time leaks print `ERROR: … leaked at exit` after the runner finishes, and only the raw greps in Task 6 catch them.
  - `FileAccess.get_file_as_string()` returns `""` and prints an error on a missing file, so call `file_exists()` first. Use `get_open_error()` for the purity read (1.1 review).
  - Re-run `--import` after adding a `class_name`.
- **Runner contract** (`tests/runner.gd`):
  - `run()` starts two frames after the test enters the tree.
  - `ok` lines and `[category]` `Log` lines never count as a verdict.
  - Warnings are allowed; any error fails the test.
  - The runner frees the test and watches two more frames.

### Git intelligence

Recent commits on `feat/m2-e1`:
- `b4f9fac`: `Tuning`, `Gear` and `Game.tuning` (feat)
- `cf1bb64`: the actor migration (refactor)
- `120f9bd`: the docs (docs)
- `9fa8ba3`: the 1.3 dev record
- `feb14e5`: the 1.3 review fixes
- `d71497d`: the review record, which is this story's baseline

The pattern: `feat:` / `refactor:` / `docs:` commits, each leaving `run_tests.sh` green, with `.gd.uid` files committed beside new scripts. The game has played the same since the M1 playtest, so the Task 1 counts describe M1's behaviour.

### Cross-story context (Epic 1)

- **1.5:** room ids (`m1_shaft`) and `room.entry_position(entry)`, which are the values `respawn_room` / `respawn_entry` will hold.
- **1.6:** `World` becomes the main scene.
  - It calls `Game.boot()` in `_ready()`, with the same `current_scene == self` guard; the call moves there from `shaft.gd`.
  - It respawns at the `DiveState` respawn point, emits `player_spawned`, and keeps killed enemies dead.
- **1.7:**
  - `enter_room()` calls `Game.slot.visit(id)`, which adds visits to `SlotState`.
  - Crawler kills call `Game.dive.mark_killed(room_id, cell)`, and the room build skips killed cells.
  - It deletes `shaft.gd`, so F1 and F3 go. The world applies `Settings.brightness`, changed through DevTools until 1.36.
- **1.8:** adds `light_tap_window` (default 0.12, choices 0.12 / 0.2 / 0.3) and retires `SNUFF_HOLD`.
- **1.11:** `--set=<key>:<value>` overrides a setting for the session only and never writes it. It needs a path that doesn't go through the armed write (D6), designed there.
- **1.16:** adds `reduce_flashing`, `shake` and `reduced_motion`.
- **1.19:** cause ids and `death_log` (`record_death` gains the cause and room); the hazard-respawn tracker in `World`.
- **1.21:**
  - `SaveStore` gains the slots (`.tmp` → verify → rename, `.bak`, meta, migrations).
  - `Game` gains `save_now()`, `save_progress()`, `load_slot()`, `new_game` and the save signals.
  - `boot()` loads slot 1 if it exists.
  - The dive snapshot is `DiveState.to_dict()`, and play time and the resume point join `SlotState`.
- **1.22:** deposited embers and the Ember Cache in `SlotState`; the death cost by `SlotState.difficulty`; `--difficulty`.
- **1.24:**
  - Anchors and stations call `set_respawn()`, and a lit anchor is a `SlotState` flag (`set_flag(&"anchor_m1_1")`).
  - A rest calls `Game.dive.reset()` and then rebuilds the room.
- **1.35:** the Cling and Snuff toggle settings.
- **1.36:** the Options UI writes through `set_value()`; Reduced motion follows the OS on web.
- **1.37:** `core/devices.gd`, held by `Game`.
- **1.38:** the slot picker.
- **1.41:** freezes the `SlotState.to_dict()` and `DiveState.to_dict()` keys as `slot_v1`, with a schema guard.
- **E5:** `SlotState.gear`, and `Game.tuning.apply_gear(slot.gear)` when it changes.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.4: State objects in the Game autoload]
- [Source: _bmad-output/planning-artifacts/epics.md#Additional Requirements: AR2, AR4, AR10, AR11, AR13, AR14, AR18, AR24, AR37, AR38; R15; UX-DR26]
- [Source: _bmad-output/game-architecture.md#State Management, #Data Persistence, #Error Handling, #Event System, #Data Patterns, #Architectural Boundaries, #Consistency Rules, ADR-1, ADR-6, decision 5 (anchor quit)]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/EXPERIENCE.md#Options tabs, #Accessibility Floor (Brightness 4 levels, A1/R1), #Input Schemes > Rules (UX-DR26, debug keys)]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md#Controls and Input (Options rollout), #Difficulty, #Hub (Guild records), #Saves]
- [Source: _bmad-output/implementation-artifacts/m1-playtest-findings.md#What the playtest changed (6: respawn on the last ledge; 1: banked embers)]
- [Source: _bmad-output/project-context.md#Engine-Specific Rules, #Code Organization Rules, #Testing Rules, #Platform & Build Rules (Saves)]
- [Source: _bmad-output/implementation-artifacts/1-3-tuning-as-data.md#Decisions (D6), #Review Findings, #Dev Agent Record]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (`claude-opus-5-5`) via gds-dev-story, 2026-11-12.

### Debug Log References

- **Baseline (Task 1, on `fb4ab8f`, i.e. `d71497d` + the story file):** `test_chain_state` ALL PASS (69 checks), `test_log` 7, `test_clock` 15, `test_tuning` 85, `test_deferred_owners` 22, `smoke_shaft` 28 + SMOKE PASS, `== ALL GREEN`. The real user folder held `logs/`, `objectdb_snapshots/` and `shader_cache/`, with **no `settings.json`**.
- **Probes on 4.7.2 before writing `Game`:**
  - `debug/gdscript/warnings/assert_always_false` exists at level 1 (warn). A bare `assert(false, …)` in each D7 setter would show 5 editor warnings, so each one carries `@warning_ignore("assert_always_false")`.
  - `FileAccess.store_string()` returns `bool` (true), so `write_settings()` returns `ERR_FILE_CANT_WRITE` when it fails.
- **Red phases:**
  - `test_state.gd` failed to parse before each class existed (`SlotState`, `DiveState`, then `SaveStore` unknown).
  - That is a weak red, so four mutants of `game.gd` were run against the finished test:
    1. **`reset_for_tests()` without the disarm:** caught (2 FAIL). **It also created the real `user://settings.json`.** Teardown's `reset_for_tests()` pointed the store home while the mutant's write was still queued, and the write landed a frame later. The file was inspected (the defaults, written 20:06 by this run) and deleted, since the baseline had none. Teardown now keeps the store on `TMP` for a frame after the reset and checks that nothing was written. Re-run: caught (2 FAIL), and the real folder stayed clean.
    2. **The one-write-per-frame guard removed:** **passed every spec'd check.** Both deferred writes flush in the same frame and leave the same file, so "delete it; a frame later it is still gone" can't see them. Added a `WriteCounter` Logger that counts `Log.format(Log.SAVE, "settings written")` lines. Re-run: caught (`2 writes`).
    3. **`load_settings()` without the disarm:** caught (2 FAIL: the valid file is rewritten, and two changes write in the same frame).
    4. **`load_settings()` ignoring `from_dict()`'s clean flag:** caught (2 FAIL). It also showed that `_tmp_holds()` compared `"bright" == 1`, which is a **SCRIPT ERROR on 4.7.2, not `false`**. The helper now checks types first.
- **Runtime probe of D10** (a throwaway `tests/zz_probe_shaft.gd`, deleted, never committed): the shaft was made the current scene with `Game.store.dir` on a temp folder.
  - The spawn at `P` is (72, 84). F1 changed the brightness from 1 to 2, the darkness changed, and the file was written.
  - The player was moved to (200, 700), then `die()` → reload → the new shaft's player at (72, 84) == `P`.
  - Deaths 1, carried 4 and best 3 all survive. The brightness stays 2, and the HUD label reads `Game`.
  - `settings.changed` has 2 connections: `Game`'s own plus the new shaft's. The freed shaft's connection dropped.
- **Task 6:**
  - Import: clean.
  - `REAL` absent before and after the seven raw per-test runs, and no `SCRIPT ERROR`/`ERROR:` line in any of them (so no exit-time leak).
  - `run_tests.sh`: 69 / 7 / 15 / 85 / **test_state 111** / 22 / 28, `== ALL GREEN`.
  - The `static var`, purity, `Controls`/`KEY_F2`/`_controls` and existing-tests greps print nothing.
  - **The `parse_string|ConfigFile|make_dir` grep prints 2 lines, both `##` comments in `save_store.gd`** naming those APIs as the trap. That is the header text Dev Notes → *SaveStore* and D5 ask for. A code-only variant (comment lines dropped) prints nothing.
  - `--quit-after 120`: no error, and it wrote `REAL` as `{"settings": {"brightness": 1}, "version": 1}`, tab-indented. That is the game's own boot, as expected, so **the server now has a real `settings.json`**.
  - Screenshot: exit 0, two PNGs. The HUD reads `embers 0 (held +0) chain 0 (best 0) … deaths 0`, and the bottom controls bar is gone.

### Completion Notes List

- Story context created by gds-create-story on 2026-11-12. Ultimate context engine analysis completed - comprehensive developer guide created. The settings persistence path (`Game` + `SaveStore` + a `brightness`-only `Settings`) and every engine behaviour it relies on were dry-run on Godot 4.7.2 first (see "Verified on the server").
- **Implemented as specified, with D1–D10 applied as written** (no veto came in):
  - `Settings` (brightness only; `SCHEMA`, `set_value`, `_valid` with the type check first), `SlotState` (records, difficulty ids, sorted String flags) and `DiveState` (carried, the respawn point, killed enemies never saved), all pure `RefCounted`.
  - `from_dict()` never asserts, returns whether the data was clean and takes whole floats as ints.
  - Each class sets every field before emitting. A load or reset emits every value signal once, and `flag_set` fires per changed id.
  - `SaveStore` (`Game.store`): `.tmp` then rename, never creates a folder, one warning on unusable data.
  - `Game`: five guarded refs plus `store`; `boot()` once; `load_settings()` decides the rewrite from `from_dict()`'s result; at most one write per frame; `reset_for_tests()` in the spec's order.
  - `shaft.gd` has no statics. It boots behind `current_scene == self`, records through `Game`, respawns at `P`, and F2 and the controls bar are gone.
- **Beyond the letter of the spec (each one closes a gap found while testing):**
  - `@warning_ignore("assert_always_false")` on the five D7 asserts.
  - In `test_state`:
    - the `WriteCounter` check ("written once, not once per change")
    - teardown holds the store on `TMP` for a frame ("after reset_for_tests() nothing is written")
    - `_tmp_holds()` checks types before comparing
    - `(setup: …)` checks that make sure the probe request and gear really were active before the reset
    - DiveState: a respawn room that isn't a string falls back
  - The corrupt-file warning drops `get_error_line()`, which printed `line 0` for a one-line file.
- **Commits** were made at each task boundary, so each one is green and `test_state.gd` grows in two steps:
  - `15d6a2e` feat (Task 2)
  - `31cb44c` feat (Task 3)
  - `48397af` refactor (Task 4)
  - `44a6a89` docs (Task 5)
  - Every new `.gd.uid` is committed beside its script.
- **Docs:**
  - Every line listed in Task 5 was fixed.
  - The `docs/architecture.md` diagram line lost its controls hint and is now 95 characters wide like its neighbours (it was 96 before).
  - `docs/project-scan-report.json` still says "shaft statics". It is a dated scan log and isn't in Task 5, so it was left alone.
  - The development guide's test list was already missing `test_tuning.gd` before this story; only `test_state.gd` was added.
- **For the next story:** the real `user://settings.json` now exists on the server (Task 6's game boot). Tests never touch it.
- **Tests green; needs a feel check on the laptop:** death now respawns at the top until anchors land in 1.24, brightness persists between launches, and the controls hint is gone. Gameplay numbers are unchanged.

### File List

New:
- `game/scripts/rules/settings.gd`, `game/scripts/rules/settings.gd.uid`
- `game/scripts/rules/slot_state.gd`, `game/scripts/rules/slot_state.gd.uid`
- `game/scripts/rules/dive_state.gd`, `game/scripts/rules/dive_state.gd.uid`
- `game/scripts/core/save_store.gd`, `game/scripts/core/save_store.gd.uid`
- `game/tests/test_state.gd`, `game/tests/test_state.gd.uid`

Modified:
- `game/scripts/core/game.gd`
- `game/scripts/shaft.gd`
- `game/scenes/shaft.tscn` (the `Controls` node removed by hand)
- `game/run_tests.sh`
- `game/README.md`
- `docs/architecture.md`, `docs/component-inventory.md`, `docs/development-guide.md`, `docs/index.md`, `docs/project-overview.md`, `docs/source-tree-analysis.md`
- `_bmad-output/project-context.md`
- `_bmad-output/game-architecture.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/1-4-state-objects-in-the-game-autoload.md`

## Change Log

- 2026-11-12: Story 1.4 created (ready-for-dev).
- 2026-11-12: Implemented (`15d6a2e`, `31cb44c`, `48397af`, `44a6a89`). `Settings`, `SlotState` and `DiveState` added; `SaveStore` and `settings.json` added; `Game` holds the session state with guarded refs, `boot()` and `reset_for_tests()`; the shaft statics moved into `Game`; F2 and the controls bar are gone; the shaft respawns at `P`; docs updated. `test_state` (111 checks), hardened by four mutants. Status: review.
