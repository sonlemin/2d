---
baseline_commit: 6801e99
---

# Story 1.21: Save store

Status: done

**Type:** dev (no human gate: nothing on screen changes, and nothing in play saves until Story 1.24's rest) · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP2 Kit (1.16–1.30) · **Branch:** `feat/m2-e1`

## Story

As a player,
I want my progress written to disk safely,
so that a crash or a bad write never costs me my save.

## Acceptance Criteria

1. **`SlotState` holds play time, depth and the resume point.** (`scripts/rules/slot_state.gd`; AR14, D5, D8, D9)
   - New fields, each with a `##` comment:
     - `play_time := 0`: whole seconds played on this slot, unpaused;
     - `depth := 0`: the deepest screen row reached (0 = the top screen);
     - `resume_room: StringName = &""`, `resume_entry: StringName = &""`: where a load wakes the player. Empty = the dive's start.
   - New rule methods (a write emits only on a change, 1.4 D2):
     - `add_play_time(seconds: float)`: asserts `seconds >= 0.0`. It adds to a private `_play_fraction`; whole seconds move into `play_time`, and a call that moved any emits `play_time_changed(play_time)` once (one emit even when it moved several). So the signal fires about once a second, never per frame.
     - `record_depth(row: int)`: raises `depth` when `row` is larger and emits `records_changed`; otherwise nothing.
     - `set_resume(room_id: StringName, entry: StringName)`: emits `resume_changed(room_id, entry)` on a change.
     - `meta() -> Dictionary`: `{"depth": int, "best_chain": int, "play_time": int, "difficulty": String}`, the slot picker's line (Story 1.38).
   - `const RESUME_KEYS: Array[String] = ["resume_room", "resume_entry"]`: the `to_dict()` keys a progress save must not move (AC5). Story 1.22 adds `"cache"` here.
   - `to_dict()` gains `"play_time"`, `"depth"`, `"resume_room"`, `"resume_entry"`. The fraction of a second is not saved.
   - `from_dict()` (1.4 D3: never asserts, a bad or missing field takes its default and makes the result unclean):
     - `play_time` and `depth` go through `_count()`;
     - the resume point is one value, like `DiveState`'s respawn point: when either half is not a `String` / `StringName`, both are cleared.
   - `reset()` and `from_dict()` clear `_play_fraction`, and emit `play_time_changed` and `resume_changed` once each, changed or not (1.4 D2).
   - `test_state.gd` is updated: the defaults, `_filled_slot()`, `_same_slot()`, the round trips, the exact key list (`best_chain, deaths, depth, difficulty, flags, play_time, resume_entry, resume_room, visited`), the fallbacks (a bad `play_time`, a bad `depth`, half a resume point) and the load signals.

2. **`rules/migrations.gd`: the migration scaffold.** (AR37, D10)
   - New `scripts/rules/migrations.gd`: `class_name Migrations extends RefCounted`, static functions only, pure (lint `rules_purity`: no file access, no `Time`, no `Game`).
   - `const VERSION := 1`: the slot format this build writes. It is the one home of the number; `SaveStore` reads it.
   - `static func steps() -> Dictionary`: `{from_version: Callable}`; `{}` today. E4 adds `1: migrate_v1_to_v2` (Story 4.1).
   - `static func migrate(data: Dictionary, to: int = VERSION, table: Dictionary = steps()) -> Dictionary`:
     - works on a deep copy of the whole file dictionary (`version`, `meta`, `slot`, `dive`), so a step may change any part;
     - runs `table[v]` for `v` = the data's version up to `to - 1`, in order; each step must leave `version == v + 1`;
     - returns `{}` when a step is missing or didn't bump the version; returns the copy unchanged when the version already equals `to`.
     - The caller has already checked that the version is a whole number in `1..to`. Look steps up with `int(version)`: a JSON number is a float, and `{1: f}.has(1.0)` is false (probed).
   - A passed `to` / `table` is only ever a test's (as with `Settings.is_valid()`'s `schema`).
   - `tests/test_migrations.gd` (pure) covers: two fake steps run in order (v1 → v3) and the source dictionary is untouched; a missing step → `{}`; a step that doesn't bump → `{}`; already current → unchanged; and the real table: `steps()` has exactly the keys `1 .. VERSION - 1` (holds trivially today; from E4 it fails a version bump with no step).

3. **`SaveStore` reads a slot: main file, then `.bak`, never an engine error.** (`scripts/core/save_store.gd`; AR37, R15, D2, D3)
   - `const SLOTS := 3`. `slot_path(n: int) -> String`: `dir.path_join("slot_%d.json" % n)`; asserts `n` in `1..SLOTS`. The backup is `slot_path(n) + ".bak"`, the temp file `slot_path(n) + ".tmp"`.
   - `var version := Migrations.VERSION` and `var steps := Migrations.steps()`: what `read_slot()` migrates to and with. Only a test changes them (to load a v1 file as v3 through fake steps).
   - `read_slot(n: int) -> Dictionary`: `{found: Found, from_bak: bool, why: String, version: int, meta: Dictionary, slot: Dictionary, dive: Variant}`. `dive` is a `Dictionary` or `null`. It prints nothing and pushes no warning: `why` says what was wrong, and `Game` warns.
   - Each file is judged alone (the same `Found` enum the settings use):
     - it doesn't exist → `MISSING`;
     - it exists but `FileAccess.open()` returns null → `UNREADABLE`;
     - it isn't valid JSON, isn't an object, `version` isn't a whole number ≥ 1, `slot` isn't a `Dictionary`, or `dive` is neither a `Dictionary` nor `null` (a missing `dive` key counts as `null`) → `CORRUPT`;
     - a `meta` that is missing or not a `Dictionary` reads as `{}` and the file stays usable: `meta` is only a copy for the picker, so it never costs a good slot;
     - `version` > the store's `version` → `NEWER`;
     - `version` < the store's `version`: `Migrations.migrate(data, version, steps)`; `{}` → `CORRUPT`;
     - otherwise `USABLE`.
   - The slot's result, from the two files:

     | Main file | `.bak` | Result |
     |---|---|---|
     | USABLE | (not read) | USABLE |
     | NEWER | (not read) | NEWER |
     | UNREADABLE | (not read) | UNREADABLE |
     | MISSING or CORRUPT | USABLE | USABLE, `from_bak = true` |
     | MISSING or CORRUPT | NEWER | NEWER |
     | MISSING or CORRUPT | UNREADABLE | UNREADABLE |
     | MISSING | MISSING | MISSING (an empty slot) |
     | MISSING | CORRUPT | CORRUPT (damaged) |
     | CORRUPT | MISSING or CORRUPT | CORRUPT (damaged) |

   - A missing main file with a usable `.bak` loads the `.bak`: that is what a crash between the backup and the rename leaves on Windows (D4).
   - Parse with `JSON.new().parse()` only. Check a value's type before comparing it: on 4.7.2 `"1" == 1` is a SCRIPT ERROR, not false.
   - **Amended at the code review (sonlm 2026-11-25, departure 2):** a file's version is judged before the rest of its shape, so a version above the store's reads `NEWER` whatever else the file holds, and a version above 2^53 is `CORRUPT`. The shape is checked before a migration and again after it.

4. **`SaveStore` writes a slot: `.tmp` → re-read → `.bak` → rename.** (AR37, D4)
   - `write_slot(n: int, data: Dictionary) -> Error`, in this order:
     1. `read_slot(n)`. If it is `CORRUPT`, `UNREADABLE` or `NEWER`, return `ERR_FILE_CORRUPT`, `ERR_FILE_CANT_OPEN` or `ERR_FILE_UNRECOGNIZED` and touch nothing: a damaged or newer slot is never written over.
     2. Write `JSON.stringify(data, "\t")` to `.tmp`. A null `FileAccess.open()` returns `FileAccess.get_open_error()`; a false `store_string()` returns `ERR_FILE_CANT_WRITE`.
     3. Re-read `.tmp`: its text must equal what was written and parse as JSON (`static func verify_file(path: String, text: String) -> bool`). If not: remove `.tmp`, return `ERR_FILE_CANT_WRITE`.
     4. Only when the main file itself was USABLE in step 1 (not when the slot loaded from `.bak`, and not on a first save): copy the main file's current bytes to `.bak` with `FileAccess` (read, then `store_buffer()` or `store_string()`). If that write fails: remove `.tmp`, return the error.
        **Amended at the code review (sonlm 2026-11-25):** the copy is never written in place. The bytes go to `.bak.tmp`, are read back and compared, then renamed over `.bak`; a failure removes `.bak.tmp` and `.tmp` and leaves the old `.bak` as it was. A failed rename in step 5 removes `.tmp` too.
     5. `DirAccess.rename_absolute(tmp, main)`; return its result. On `OK`: `Log.info(Log.SAVE, "slot %d written (%d bytes)" % …)`.
   - **Never call `DirAccess.copy_absolute()`.** It prints an engine `ERROR:` whenever the source or the destination can't be opened (probed on 4.7.2: a missing source, an unreadable source, a read-only folder), which fails the test runner. That is the epic's "the first save skips the copy so no engine error prints", made true for every failure.
   - A corrupt main file is never copied into `.bak`: the good backup the slot just loaded from stays.
   - The store never creates a folder (1.4 D5).
   - `delete_slot(n: int) -> Error`: removes the main file, `.bak` and `.tmp`; a missing file is not an error (`DirAccess.remove_absolute()` returns `FAILED` silently for one, so check `FileAccess.file_exists()` first); returns the first real error.
   - `write_settings()` goes through the same private write (steps 2, 3 and 5; no `.bak`, D11).

5. **`Game` commands and signals.** (`scripts/core/game.gd`; AR11, AR38, R14, D5–D7)
   - Signals: `save_succeeded(n: int)`, `save_failed(n: int, err: Error)`, `settings_save_failed(err: Error)`.
   - `var active_slot := 1`: the slot this session plays. Only `load_slot()` and `new_game()` change it.
   - **Arming (D7):** slot saves write only after `boot()`, `load_slot()` or `new_game()` ran in this process. Unarmed, `save_now()` and `save_progress()` return `ERR_UNCONFIGURED` first thing: no state change (not even the resume point), no file, no signal, no warning. `reset_for_tests()` disarms, sets `active_slot = 1`, clears the detach flag (AC7) and takes a fresh resume snapshot.
   - **A fresh resume snapshot** is the `RESUME_KEYS` values of a new `SlotState`'s `to_dict()` and a `null` dive. `Game` starts with one.
   - `load_slot(n: int) -> SaveStore.Found`: reads through the store, sets `active_slot = n`, arms, and always leaves `slot` and `dive` defined, in place:
     - `USABLE`: `slot.from_dict(read.slot)`; then `dive.from_dict(read.dive)` when it is a `Dictionary`, else `dive.reset()` followed by `dive.set_respawn(slot.resume_room, slot.resume_entry)`. One `push_warning` if it came from `.bak`, and one if either `from_dict()` was unclean. `Log.info(Log.SAVE, …)` on a clean load.
     - `MISSING`: `slot.reset()`, `dive.reset()`. Silent (a first launch).
     - `CORRUPT`, `UNREADABLE`, `NEWER`: `slot.reset()`, `dive.reset()`, one `push_warning` naming the slot and `why`; the file is left as it is.
     - It then takes the **resume snapshot**: the `RESUME_KEYS` values of `slot.to_dict()` and the dive part (`dive.to_dict()` when the file had one, else `null`).
   - `save_now() -> Error`, the **resume save** (a station rest, arriving home, a quit at a lit anchor; their callers arrive in 1.24, 1.34 and E5):
     - `slot.set_resume(dive.respawn_room, dive.respawn_entry)`;
     - writes `{"version": Migrations.VERSION, "meta": …, "slot": slot.to_dict(), "dive": dive.to_dict()}`, where `meta` is `slot.meta()` plus `"saved_at": int(Time.get_unix_time_from_system())`;
     - on `OK`: retakes the resume snapshot from what it wrote, emits `save_succeeded(active_slot)`;
     - on an error: `push_warning` once, emits `save_failed(active_slot, err)`, leaves the snapshot alone. It never crashes, pauses or asserts.
   - `save_progress() -> Error`, the **progress save** (R14):
     - writes the same shape, but in `"slot"` every `RESUME_KEYS` value is the snapshot's, and `"dive"` is the snapshot's dive (or `null` when there is none);
     - `meta` is live (`saved_at` is now);
     - same signals and warning as `save_now()` ("shows the icon or the failure state exactly like `save_now()`": the icon and "Not saved" are UI that subscribes to these two signals in Stories 1.25 and 1.39).
   - `set_difficulty(tier: StringName)`: `slot.set_difficulty(tier)`; if the tier changed, `save_progress()`. It is E1's one progress moment; Options calls it in 1.36. `Game` does **not** subscribe to `slot.difficulty_changed` for this: a load and a reset emit it too.
   - `new_game(n: int, tier: StringName = SlotState.DEFAULT_DIFFICULTY) -> Error`: `store.delete_slot(n)` (so an overwritten game's `.bak` can never load later), `slot.reset()`, `dive.reset()`, `slot.set_difficulty(tier)`, `active_slot = n`, arm, a fresh snapshot, then `save_now()`. It is the only way to write over a damaged or newer slot. Its callers arrive in 1.33 / 1.38.
   - `delete_slot(n: int) -> Error`: `store.delete_slot(n)`; when `n == active_slot`, a fresh snapshot.
   - **Amended at the code review (sonlm 2026-11-25):** a successful delete of the active slot also resets `slot` and `dive` in place and disarms saves until `load_slot()` or `new_game()`; a failed delete changes nothing in memory. `store.delete_slot()` removes the main file last and stops at the first error. `Game` keeps the verdict of a load that found the slot damaged, unopenable or newer, and of a `new_game()` whose delete failed, and refuses every save itself until `new_game()` or a load that reads the slot. Saves are off while `load_slot()` and `new_game()` replace the state. `save_now()` moves `slot.resume_*` only once the write succeeded. Detached, `delete_slot()` returns `ERR_UNCONFIGURED` (departure 4).
   - `boot()` adds, after `load_settings()`: `load_slot(active_slot)`. So until the slot picker (1.38) the game uses slot 1 and loads it at boot if present.
   - A failed settings write now also emits `settings_save_failed(err)` (still one `push_warning`, still no crash).

6. **World: play time, depth and a saved respawn point it can't use.** (`scripts/world/world.gd`; D8, D9, D13)
   - `_process(delta)`: `Game.slot.add_play_time(minf(delta / Engine.time_scale, PLAY_TIME_STEP_MAX))`, with `const PLAY_TIME_STEP_MAX := 0.25` (s; a stalled or backgrounded frame is not play). World is pausable (the default process mode), so play time stops with `SceneTree.paused`. Real seconds: hitstop and E7's speed assist don't change it.
   - **Amended at the code review (sonlm 2026-11-25, departure 1):** play time is the wall clock between frames (`Time.get_ticks_usec()`), never `delta / Engine.time_scale`, which over-counts on every frame a hitstop starts (probed twice: 5.59 s and 7.81 s counted for 4 s real). The cap stays; `NOTIFICATION_UNPAUSED` restarts the clock; the exact cases call the seam `World._count_play_time(real_seconds)`.
   - `_physics_process()`, on a tick with a living player and no swap pending, after the exit poll: `Game.slot.record_depth(row)` with `row = maxi(floori(_player.position.y / Display.BASE.y), 0)`. One comment says E4 adds the room's `map=` row to it.
   - `_ready()`, before the first room is built: when `Game.dive` holds a respawn point, check it with `RoomLoader.inspect(room_id)`: the room is known, has no errors, and lists the entry. If not: one `push_warning`, then `Game.dive.set_respawn(&"", &"")`, so this dive starts and respawns at the start room. A bad point in save data is an environment error and must not reach `RoomLoader`'s `push_error`.
   - `smoke_world.gd` gains:
     - play time, with no `await` between the calls (the engine also calls `_process` every real frame, so only a difference taken inside one frame is exact): eight calls of `_world._process(0.25)` raise `Game.slot.play_time` by exactly 2; then one call of `_world._process(5.0)` and three of `_world._process(0.25)` raise it by exactly 1 (the long frame counted 0.25 s);
     - with `get_tree().paused = true`, `_world.can_process()` is false (unpause again right after);
     - the player placed (`place_at()`) on a free spot with y = 600 in `m1_shaft` gives `Game.slot.depth == 2` after a physics tick (600 / 270 → row 2), and placing it back near the top never lowers it;
     - a World added with `Game.dive.set_respawn(&"no_such_room", &"spawn")` starts in `m1_shaft`, clears the point, warns once and prints no `ERROR:` line; the same with a known room and an unknown entry;
     - `test_no_boot` also checks that slot saves are unarmed.

7. **A dev session never loads or writes a slot.** (`scripts/dev/dev_tools.gd`; D12, closes the ledger item "A dev session meets the save")
   - `Game.detach_slot()`: for the rest of the process no `Game` command reads or writes a slot file. `load_slot()` resets `slot` and `dive`, reads nothing and returns `Found.MISSING`; `new_game()` resets them and returns `ERR_UNCONFIGURED`; neither arms; saves stay unarmed. So `boot()` needs no branch. `Log.info(Log.SAVE, …)` once.
   - DevTools' `ARGS` rows gain `detach` (bool): true for `room`, `chain`, `hp` and `perf`; false for `log`, `set` and `glow`. `_apply()` calls `Game.detach_slot()` once when any applied arg has `detach = true`, and its summary line says so. Story 1.22's `difficulty` row is `detach = true`.
   - DevTools applies its args before `Game.boot()` (the hook is the first statement of `World._ready()`), so the flag is set in time.
   - `smoke_dev_tools.gd` checks: `--room=…` detaches; `--log=save` alone doesn't; a `--room` with a bad value (a warning, not applied) doesn't; `reset_for_tests()` clears the flag.

8. **`tests/test_saves.gd`** covers, on a temp folder it creates and removes, with no `ERROR:` line in the output:
   - **Round trip:** fill `Game.slot` and `Game.dive`, `save_now()`, `reset_for_tests()` (then point the store at the temp folder again), `load_slot(1)`: every field is back with its type (`int` counts, `StringName` ids); the file is `{"dive", "meta", "slot", "version"}` with `version` 1 and `meta` = depth, best chain, play time, difficulty and a `saved_at` not before the test started.
   - **Through `.tmp`:** a marker `.tmp` planted before the save is used up (as `test_state` does for settings); after a save no `.tmp` is left.
   - **`.bak`:** the first save writes no `.bak`; the second leaves a `.bak` equal to the first file's text.
   - **`.bak` fallback:** a corrupt main file with a good `.bak` loads the `.bak` (one warning); the next save replaces the main file and leaves that `.bak` byte for byte. A missing main file with a good `.bak` loads it too.
   - **Damaged:** both files corrupt → `CORRUPT`, the defaults in memory, one warning; `save_now()` and `save_progress()` each return an error, emit `save_failed(1, err)` once, warn once, and leave both files byte for byte. After `new_game(1)` the slot saves and loads again, and no old `.bak` is left.
   - **Newer:** a `version` 2 main file → `NEWER`; saves fail the same way; the file is byte for byte as it was, and no `.tmp` or `.bak` appears.
   - **Corrupt shapes**, each giving `CORRUPT` for that file: not JSON, an empty file, a top-level array, no `version`, a string `version`, `version` 0, `version` 1.5, `slot` not an object, `dive` a number. A file whose only fault is a missing `meta` is `USABLE` with `meta == {}`.
   - **Unclean:** a usable file with one bad slot field loads with that field's default, the good fields kept, one warning.
   - **Older version (the scaffold through the store):** with `store.version = 3` and two fake steps, a v1 file loads as v3 with both steps applied, and a v4 file is `NEWER`; with a step missing the file is `CORRUPT`.
   - **Progress save (R14):**
     - set a respawn point, `save_now()`; then add carried embers, move the respawn point, change the difficulty through `Game.set_difficulty()` and set a flag; reload: the difficulty and the flag are kept, carried is what the resume save held, and the respawn and resume points are the resume save's.
     - `Game.set_difficulty()` alone wrote the file (one `save_succeeded`); the same tier again saves nothing.
     - A progress save with no resume save before it writes `"dive": null`, and it loads as a fresh dive.
     - A failed `save_now()` (the store pointed at a missing folder for that one call) followed by a good `save_progress()` leaves the old resume point and the old dive in the file.
   - **Failure signal:** with the store pointed at a folder that doesn't exist, `save_now()` returns an error, emits `save_failed(1, err)` once and `save_succeeded` never, warns once, and creates no folder. Where a read-only folder can be made (not Windows, not root; skip otherwise, as `test_state._lock_tmp()` does), a save into it fails the same way and the existing slot file is byte for byte as it was.
   - **`verify_file()`:** true for the written text; false for a truncated file, for text that isn't JSON and for a missing file.
   - **Unarmed:** after `reset_for_tests()`, `save_now()` returns `ERR_UNCONFIGURED`, emits nothing and writes nothing.
   - **`delete_slot()`:** removes all three files; on an empty slot it returns `OK`.
   - **Detached (AC7):** arm with `load_slot(1)` on a good file, then `detach_slot()`: `save_now()` returns `ERR_UNCONFIGURED` and the file is byte for byte as it was; `load_slot(1)` returns `MISSING`, leaves the defaults in memory and stays unarmed; `reset_for_tests()` attaches again.
   - **Boot:** as the last case (boot runs once per process, and the process stays booted): with a slot file in the temp folder, `Game.boot()` loads it and arms saves. (`test_state.gd`'s own boot case still passes: its temp folder holds no slot.)
   - **The player's files:** `user://slot_1..3.json`, their `.bak` and `.tmp`, and `user://settings.json` are exactly as before the run: same existence, text and modified time.
   - **Settings (D11):** a failed settings write emits `settings_save_failed` once; `test_state.gd`'s settings cases pass unchanged through the shared write.

9. **Docs, ledger and green.**
   - `cd game && ./run_tests.sh` → `== ALL GREEN`; `tools/export.sh` → `BUILD OK` (the release Linux boot now runs the slot load on a fresh `user://`).
   - `deferred-work.md`: the two items owned by Story 1.21 are closed with a `→ **Closed (Story 1.21): …**` line each ("Settings writes skip the checks that slot saves get", "A dev session meets the save"). Anything this story defers gets its owner line from the dev agent.
   - Updated: `docs/architecture.md` (the state and persistence sections, the test table), `docs/component-inventory.md` (`save_store.gd`, `game.gd`, `slot_state.gd`, `migrations.gd`, the tests), `docs/source-tree-analysis.md`, `docs/development-guide.md` (the arming rule for tests), `_bmad-output/game-architecture.md` (Data Persistence: "as built (Story 1.21)" for the write order, the read table, arming and the snapshot; the error-handling sample's static `SaveStore.write(…)` becomes `Game.store.write_slot(…)`; `save_succeeded(n)`), `_bmad-output/project-context.md` (one sentence in the story list, the Saves rule, Last Updated), and the header comments of `slot_state.gd`, `dive_state.gd`, `save_store.gd` and `game.gd` that still say "Story 1.21 adds …".

## Tasks / Subtasks

- [x] **Task 1: `SlotState`** (AC1)
  - [x] Add the fields, signals, `add_play_time()`, `record_depth()`, `set_resume()`, `meta()`, `RESUME_KEYS`; extend `to_dict()`, `from_dict()`, `reset()` and `_assign()`.
  - [x] Update `test_state.gd`'s slot cases; run it alone: `godot --headless --path game res://tests/runner.tscn -- res://tests/test_state.gd`.
- [x] **Task 2: `Migrations`** (AC2)
  - [x] `scripts/rules/migrations.gd` + `tests/test_migrations.gd`; `test_lint` stays green (`rules_purity`).
- [x] **Task 3: `SaveStore` slots** (AC3, AC4)
  - [x] One private judged read per file; `read_slot()` combines the two by the table.
  - [x] One private verified write (`.tmp` → `verify_file()` → rename) shared by slots and settings; `write_slot()` adds the guard and the `.bak` step; `delete_slot()`.
  - [x] `write_settings()` moves onto the shared write; `test_state.gd`'s settings cases pass unchanged.
- [x] **Task 4: `Game`** (AC5, AC7)
  - [x] Signals, `active_slot`, arming, the resume snapshot, `load_slot()`, `save_now()`, `save_progress()`, `set_difficulty()`, `new_game()`, `delete_slot()`, `detach_slot()`; `boot()` and `reset_for_tests()`; `settings_save_failed`.
- [x] **Task 5: `tests/test_saves.gd`** (AC8)
  - [x] Write it case by case against AC8; state each check's proof with exact expected values.
  - [x] Red-check the guards with mutants on a scratch copy (the 1.4 review's method): no `.bak` step; the `.bak` step copying a corrupt main; the damaged guard removed; `save_progress()` writing the live dive; saves armed by default. Each must fail the suite.
- [x] **Task 6: World** (AC6)
  - [x] `_process()` play time, the depth record, the respawn-point check in `_ready()`; `smoke_world.gd` cases.
- [x] **Task 7: DevTools** (AC7)
  - [x] `detach` on the `ARGS` rows, `_apply()`, the summary; tests.
- [x] **Task 8: Docs, ledger, project-context** (AC9)
- [x] **Task 9: Verify** (AC9)
  - [x] `cd game && ./run_tests.sh` → `== ALL GREEN`; `tools/export.sh` → `BUILD OK`.
  - [x] Report "tests green; no laptop look needed: nothing on screen changes and nothing in play saves until Story 1.24".

### Review Findings

Code review 2026-11-25 over `6801e99..afcfa86`, the code half (`game/` + `tools/`, 17 files, 2555 diff lines; the docs and ledger half went to the Acceptance Auditor as context). Three layers: Blind Hunter (18 findings), Edge Case Hunter (15), Acceptance Auditor (13); 46 raw. Outcome: 3 decisions, 13 patches, 4 deferred, 10 dismissed. The suite on that commit, re-run for this review, is `== ALL GREEN (33 tests)`, 2484 `ok`. AC1, AC2 and AC8 are fully met. Nothing in play saves yet, so no finding can cost a tester a save today; the findings matter from Story 1.24's first rest.

The serious ones share one cause: `Game` arms saves and then forgets what the load found, so the "never written over" rule rests on the files reading the same way twice. Probes on 4.7.2 (the Edge Case Hunter's unless marked):

- **An unopenable slot that opens later (confirmed).** `chmod 0` before `load_slot(1)`, `chmod 644` before `save_now()`: save 1 leaves the defaults as the main file and the real save as `.bak`; save 2 leaves the defaults in both. The real save is gone.
- **A save from a signal handler during a load or a new game (confirmed).** With a `flag_set` handler that calls `save_progress()`: `load_slot(2)` rewrote `slot_2.json` with slot 1's dive, and `new_game(2)` wrote blank progress over `slot_1.json`. No such handler exists today.
- **`new_game()` after a failed delete (confirmed).** A read-only folder during `new_game(1)` returns `FAILED` with saves armed; once the folder is writable, `Game.set_difficulty()` writes the new game as the main file and keeps the old game as `.bak`.
- **A failed `save_now()` (confirmed).** `slot.resume_entry` is `down` while the file and the snapshot still hold `spawn`.
- **A failed rename (confirmed for `.tmp`).** With the target a non-empty directory the save fails and `slot_1.json.tmp` stays. The Windows half (main file deleted, then the move fails) is read from the engine source and was not run.
- **A newer `.bak` beside an older main file (confirmed, dismissed).** `save_now()` returns `OK` and the `.bak` becomes the v1 file. Only a hand-placed file gives that pair: no build writes it.
- **Invalid UTF-8 in a slot file (probed at triage).** It reads `CORRUPT`, as it should, but the engine prints `Unicode parsing error…` lines to stderr. They are not `ERROR:` lines, so the runner stays green; `read_slot()`'s "prints nothing" is not quite true. An all-NUL file reads as empty text, `CORRUPT`, silently; a BOM parses.
- **`delta / Engine.time_scale` over-counts (confirmed again).** 12 hitstops in 4.02 s of wall time summed to 7.81 s, so deviation 1 (the wall clock) stands.

- [x] [Review][Decision] Deleting the active slot leaves its game in memory with saves armed — `Game.delete_slot(n)` removed the files and, for the active slot, only took a fresh snapshot, so the next save wrote `slot_N.json` again with the deleted game's records, flags and play time. AC5 asked for exactly that and `_test_delete_slot` pinned it. **sonlm 2026-11-25: (a) reset and disarm.** A successful delete of the active slot resets `slot` and `dive` in place and turns saves off until `load_slot()` or `new_game()`; AC5 is amended and the test rewritten (the deleted game leaves memory, neither save writes it back, `new_game(1)` arms again). The picker's rule is on the 1.38 ledger item. (Blind + Edge; probed)
- [x] [Review][Decision] The `.bak` is rewritten in place and never read back — `_copy()` opened the old `.bak` for writing, which cuts it to 0 bytes before the new bytes land (probed at triage on 4.7.2), ignored a short read and did not compare the result, so a save that failed there destroyed the last good backup. **sonlm 2026-11-25: (a) fix now.** `SaveStore._backup()` copies the main file to `slot_N.json.bak.tmp`, reads it back, compares the bytes and renames it over `.bak`; any failure removes `.bak.tmp` and leaves the old `.bak` as it was; `delete_slot()` removes the fourth name. A read-only `.bak` no longer fails the save (the rename replaces it), which also answers the dismissed "an auxiliary file blocks every save". The 1.41 ledger item is closed. The comparison's own call site has no failing test (a mutant without it stays green, like the `.tmp` read-back): it joins the 1.39 seam item. (Blind + Edge + Auditor; probed)
- [x] [Review][Decision] The seven departures from the story text were unconfirmed — **sonlm 2026-11-25: (a) all seven confirmed.** (1) Play time from the wall clock: AC6 is amended. (2) Version judged before shape: AC3 is amended, and the cost is accepted: a damaged main file that still parses and carries a whole version above 1 reads `NEWER` and blocks a good `.bak` until New Game exists (1.38). (3) `new_game()` on a failed delete does not save; it now also leaves the session refused (patch below). (4), (5), (6) as built. (7) The web smoke's pinned summary line stands; the note that called it "the first proof on the web that `--room` detaches" is reworded: it shows the detach branch ran, on empty storage. `smoke_dev_boot` is the proof off the web that the slot is not read.
- [x] [Review][Patch] `Game` forgot that a load was refused: a slot that read `CORRUPT`, `UNREADABLE` or `NEWER` armed saves, and `write_slot()` judged the files afresh, so an unopenable slot that opened later was written over with the defaults, and its `.bak` on the save after. `Game._slot_refused` holds the load's verdict (the store's own error codes); `save_now()` and `save_progress()` then warn, emit `save_failed` and touch no file until `new_game()` or a `load_slot()` that reads usable or missing. `_test_read_table` unlocks the file and saves twice: both refused, both files byte for byte; a load then lifts it. The commit's claim that a progress save writes "the resume keys and dive of the last successful resume save" holds again. (Blind + Edge; probed; red-checked) [game/scripts/core/game.gd]
- [x] [Review][Patch] Saves stayed armed while `load_slot()` and `new_game()` replaced the state. Both now disarm first and set `active_slot`, the refusal and the arming only after the snapshot is assigned. `_test_no_save_while_replacing`: a `flag_set` handler that calls `save_progress()` gets `ERR_UNCONFIGURED` during `load_slot(2)` and `new_game(3)`, and no other slot's file changes. (Blind + Edge; probed; red-checked, one mutant per function) [game/scripts/core/game.gd]
- [x] [Review][Patch] `new_game()` armed the session when the delete failed. It now leaves the session refused with the delete's error. `_test_read_only`: in a read-only folder one warning, one `save_failed`, no `save_succeeded`; with the folder writable again a progress save and a resume save are still refused and the old file is byte for byte, alone; `new_game(1)` again then writes with no `.bak`. The dev's note that the branch could not be tested was wrong. (Blind + Edge + Auditor; probed; red-checked) [game/scripts/core/game.gd]
- [x] [Review][Patch] `SaveStore.delete_slot()` removed the main file first and carried on past an error. It now removes `.bak.tmp`, `.tmp`, `.bak`, then the main file, and stops at the first error. Tested through a store whose `_remove()` refuses one file (the new seam; no permission on Linux makes one file undeletable beside its neighbours): the main file is still whole and loads from itself. (Blind + Edge; red-checked, order and stop separately) [game/scripts/core/save_store.gd]
- [x] [Review][Patch] `Game.delete_slot()` dropped the snapshot even when the delete failed. It changes memory only on `OK`: a failed delete in a read-only folder leaves the game and its snapshot, and the next progress save still writes 5 carried at spawn. (Blind + Edge; red-checked) [game/scripts/core/game.gd]
- [x] [Review][Patch] `save_now()` moved `slot.resume_*` and emitted `resume_changed` before the write. It now writes the dictionary with the new point, and `_write_slot()` calls `slot.set_resume()` once the file holds it, before `save_succeeded`. `_test_failed_resume_then_progress` checks `Game.slot.resume_entry` and counts `resume_changed`. It departs from D5's wording ("`save_now()` sets `slot.resume_*` …"), not its rule. (Blind + Edge; probed; red-checked both ways) [game/scripts/core/game.gd]
- [x] [Review][Patch] A failed rename left `.tmp` behind. `_write()` retries the move once when the main file is gone (Windows: deleted, then the move failed; unprobed) and removes `.tmp` on every failure exit. Tested with a non-empty folder at the main file's path. "A failed write changes nothing" / "nothing on disk changed" are reworded in the store, `save_failed`'s doc and both architecture files to what holds: after a failed write the slot still loads what it held; what a failure can cost is the older generation, once the backup is made. (Blind + Edge + Auditor; probed; red-checked) [game/scripts/core/save_store.gd; game/scripts/core/game.gd; _bmad-output/game-architecture.md; docs/architecture.md]
- [x] [Review][Patch] A dive snapshot with an empty or bad respawn point threw away the slot's good resume point. `load_slot()` now wakes such a dive at the slot's point, as a null dive does. `_test_dive_point`: an empty point (clean) and `"dive": {}` (one warning) both wake at `m1_shaft` / `up`, and the next resume save keeps it. (Blind; red-checked) [game/scripts/core/game.gd]
- [x] [Review][Patch] World's backstop now clears a respawn point that failed to build, so a later death doesn't push the same error again. Not tested: reaching it needs `RoomLoader`'s `push_error`, which fails the runner. `test_bad_respawn_point` gained the "room is invalid" case (`bad_edge_hole`), red-checked with a check that accepts an invalid room. (Edge + Auditor) [game/scripts/world/world.gd; game/tests/smoke_world.gd]
- [x] [Review][Patch] `detach_slot()` now resets `slot`, `dive` and the snapshot when it detaches a session that had loaded a slot; a detached `load_slot(2)` is checked to leave `active_slot` at 1. New `tests/smoke_dev_boot.gd` (its own process: boot runs once) boots a World that is the current scene with `--room=t_swap_a` and a planted slot: the slot is not loaded, the dev room wins, no file changes. Red-checked by moving the DevTools hook below `Game.boot()` in `World._ready()`. (Blind + Edge + Auditor) [game/scripts/core/game.gd; game/tests/smoke_dev_boot.gd; game/tests/test_saves.gd]
- [x] [Review][Patch] The migration step contract: `Migrations` and `_read_slot_file()` now say only `slot` is sure to be a Dictionary, and that a step tests `dive` and `meta` before reading them. The model step in `test_migrations` does so, and a `"dive": null`, no-`meta` file migrates through both steps. (Blind) [game/scripts/rules/migrations.gd; game/scripts/core/save_store.gd; game/tests/test_migrations.gd]
- [x] [Review][Patch] Checks weaker than their messages: the hitstop case's text now says what it tests (1 to 3 s, against the 5 or more a stretched frame gives), and why the bound is wide; `_test_bak` reads `best_chain` from the parsed `slot` part and from `meta`; the pause case accepts the cap itself (`<= World.PLAY_TIME_STEP_MAX`); the corrupt corpus gained bytes that are not UTF-8 and an all-NUL file, and `read_slot()`'s doc says what the probe showed (no `ERROR:` line, but the engine's `Unicode parsing error` lines on stderr). (Blind + Edge + Auditor) [game/tests/smoke_world.gd; game/tests/test_saves.gd; game/scripts/core/save_store.gd]
- [x] [Review][Patch] Doc drift and the missing ledger lines: `project-context.md` says `_process` is visuals and bookkeeping, and carries the two new save rules; `world.gd`'s boot comment names the slot and the DevTools order; the architecture's slot delete lists every file and the order; the ledger has "Windows and the browser have never run a save" (→ 1.24) and "the play-time cases read the wall clock" (→ 1.41), and the 1.39 seam item names the two exits no test reaches. (Auditor) [_bmad-output/project-context.md; game/scripts/world/world.gd; _bmad-output/game-architecture.md; docs/; _bmad-output/implementation-artifacts/deferred-work.md]
- [x] [Review][Defer] A load from `.bak`, or one that fell back to defaults for bad fields, reaches the caller as plain `USABLE`: only a warning says so, and the next save drops the defaulted fields for good [game/scripts/core/game.gd] — deferred to Story 1.38, whose slot picker is the first UI that can show it
- [x] [Review][Defer] A slot loaded mid-session skips `_check_respawn_point()`, which runs only in `World._ready()` [game/scripts/world/world.gd] — deferred to Story 1.33, the first caller of `load_slot()` outside boot
- [x] [Review][Defer] On Windows a crash after the rename's delete leaves a verified `.tmp` holding the newest save, and `read_slot()` loads the older `.bak`: one save is rolled back silently; Windows and the browser have never run a save [game/scripts/core/save_store.gd] — deferred to Story 1.24, the first real save and the first run on both
- [x] [Review][Defer] Nothing asks the OS to put a save on the disk before the rename: at a power cut the fresh main file and the fresh `.bak` may both be short, and the read-back reads the OS cache [game/scripts/core/save_store.gd] — deferred to Story 1.39, which owns persistence; whether `FileAccess.flush()` reaches the disk is unprobed

Dismissed (10): the "no slot file" checks in `smoke_world` and `smoke_dev_tools` look only in their temp folder (saves are unarmed there, and `test_saves` holds the player's own files to their text and modified time); a missing migration step reads `CORRUPT` and falls back to an older `.bak` (`test_migrations` fails a version bump with no step, so no build ships one); a `.bak` that can't be written fails the save (AC4 step 4 as written; the `.bak` decision then removed the case for a read-only `.bak`); a corrupt main file beside a usable `.bak` is replaced by the next save (D3, tested); a newer `.bak` beside an older main file (hand-placed files only); the slot number is guarded only by an assert (a programmer error, the project's rule); the permission cases print `ok` when the runner can open a mode-0 file (the server's runner can't, so they run); `load_slot()` logs "loaded" only for a clean load from the main file (the other loads warn); an unclean load arms saves (R15); `new_game()` deletes before its first write (the player chose to overwrite).

After the patches: `cd game && ./run_tests.sh` → `== ALL GREEN (34 tests)`, 2541 `ok` (`test_saves` 254, `test_migrations` 23, `smoke_world` 97, the new `smoke_dev_boot` 8). Red-checks on a scratch copy of `game/`: 18 mutants, one per new guard; 17 fail the suite, and the one that stays green is the backup's byte comparison (ledgered to 1.39 with the `.tmp` read-back's call site). `tools/export.sh` → `BUILD OK builds/20261126-afcfa86-dirty` (web smoke 7 passed). No laptop look needed: nothing on screen changes, and nothing in play saves until Story 1.24.

## Dev Notes

### What this story is (and isn't)

It makes a slot a file: the format, the safe write, the safe read, the commands and the two signals. After it, **nothing in real play calls a save yet**: the rest arrives in 1.24, the difficulty option in 1.36, New Game in 1.33 / 1.38, the anchor quit in 1.34. Play time and depth do tick in memory from this story. So the proof here is the test suite.

### What exists today (read before editing)

- **`core/save_store.gd` (86 lines):** an instance at `Game.store` with a redirectable `dir`. `enum Found { USABLE, MISSING, CORRUPT, UNREADABLE, NEWER }`. `read_settings()` returns `{found, settings}` and warns through `_unusable()`. `write_settings()` writes `.tmp` and renames it, with **no read-back** (the ledger item this story closes). It never creates folders.
- **`core/game.gd` (150 lines):**
  - the refs with assert-only setters (never replace `settings`, `slot`, `dive`, …);
  - `boot()` (once per process; called by World only when it is the current scene): `load_settings()`, `display.start()`; its comment says "Story 1.21 adds: load slot 1 if present";
  - `_settings_armed` / `_queue_settings_write()` / `_write_settings()`: at most one settings write per frame, off until `load_settings()`; `override_setting()` (DevTools' `--set`) turns settings writes off for the session;
  - `reset_for_tests()` restores defaults in place and points `store.dir` home. It leaves `_booted` alone.
- **`rules/slot_state.gd`:** `best_chain`, `deaths`, `difficulty`, `_flags`, `_visited`; `set_flag()`, `visit()`, `record_chain()`, `record_death()`, `set_difficulty()` ("Doesn't save: the progress save on a difficulty change belongs to its caller"); `to_dict()` → `{best_chain, deaths, difficulty, flags, visited}`; `_assign()` sets every field, then emits; `_count()` accepts whole floats up to 2^53; `_sorted_ids()` / `_read_ids()`.
- **`rules/dive_state.gd`:** `carried`, `respawn_room`, `respawn_entry`, `_killed`; `to_dict()` → `{carried, respawn_room, respawn_entry}`, "the dive snapshot of Story 1.21's save"; killed enemies are never saved.
- **`world/world.gd`:**
  - `_ready()`: DevTools hook first, then `Game.boot()` behind `if get_tree().current_scene == self:`, then `_respawn_point()` → `_swap_room(…, true)`;
  - `_respawn_point()`: the dive's respawn point, else `start_room` / `start_entry`;
  - `_swap_room()` already falls back to the start when a respawn room fails to load, but only after `RoomLoader` or World **`push_error`s** (AC6 puts a warning in front of that);
  - `_physics_process()` returns early while a swap is pending or the player is dead; it polls exits, then the hazards. There is no `_process()` yet.
- **`dev/dev_tools.gd`:** the `ARGS` registry (`log`, `set`, `room`, `chain`, `hp`, `glow`, `perf`; each row `{help, apply, repeat}`), applied by `_apply()` in `_ready()`, before `Game.boot()`. `_apply_room()` sets `World.start_room` / `start_entry` and never writes the respawn point.
- **Tests that already redirect the store:** `test_state.gd` (the settings file cases; `WriteCounter` and `WarningCounter` loggers; `_lock_tmp()`; the real-file check by text and modified time; the boot case, kept last) and the World smokes (`Game.store.dir = TMP` before adding a World).
- **`core/display.gd`:** `Display.BASE == Vector2i(480, 270)`: the screen height the depth row uses.
- **`m1_shaft`:** 105 rows = 1680 px, so screen rows 0–6; `P` is in row 0.

### Decisions

Story-author decisions; sonlm can veto any before dev. D12 is sonlm's answer to Q1 below.

- **D1: Scope.**
  - In: the slot file format, `SaveStore` slot read / write / delete, `Migrations`, the `Game` commands and signals, play time, depth, the resume point, the verified settings write, the dev-session rule, tests, docs.
  - Out, each with its owner:
    - `OS.is_userfs_persistent()` and `SMOKE save ok` (1.39);
    - the autosave icon, "Not saved" and the pause note (1.25, 1.39);
    - the title, Continue, the picker, "Damaged" / "Empty" rows, the most-recent-slot rule, a `last_slot` setting (1.33, 1.38);
    - rebuilding the room after a load made mid-session (1.33: the first caller of `load_slot()` outside boot);
    - the rest, anchors, the anchor quit (1.24, 1.34);
    - `deposited`, the Ember Cache, `death_log` (1.22, 1.29);
    - `tests/fixtures/slot_v1.json` and the schema guard (1.41).
  - Until the freeze at 1.41, a story may add a `to_dict()` key with no version bump: a missing key takes its default and the load warns once as unclean.
- **D2: The file.** `JSON.stringify(data, "\t")` sorts keys (probed), so a slot reads:

  ```json
  {
  	"dive": {"carried": 12, "respawn_entry": "anchor_m1_1", "respawn_room": "m1_shaft"},
  	"meta": {"best_chain": 17, "depth": 4, "difficulty": "normal", "play_time": 8040, "saved_at": 1795618269},
  	"slot": {"best_chain": 17, "deaths": 3, "depth": 4, "difficulty": "normal", "flags": [], "play_time": 8040, "resume_entry": "anchor_m1_1", "resume_room": "m1_shaft", "visited": ["m1_shaft"]},
  	"version": 1
  }
  ```

  - `meta` is a copy for the picker, so it can list three slots without loading them. Nothing ever loads state from `meta`.
  - `saved_at` is whole Unix seconds; 1.38's "most recent slot" compares it.
  - Every number is written as an int and comes back as a float; `_count()` already turns a whole float back.
- **D3: The read never guesses.** Unreadable and newer files may be whole, so they are never replaced and never bypassed for an older `.bak` (the 1.4 review's rule for settings, and the epic's "rejected and left untouched"). A partly bad slot still loads (1.4 D3), with one warning.
- **D4: The write order, and why.**
  - `.tmp` is verified before anything else is touched, so a failed write changes nothing.
  - `.bak` is a copy of the current main file, written just before the rename, and only when that main file is known good.
  - On Linux the rename replaces the main file in one step, so a whole main file exists at every moment. On Windows the engine deletes the target, then moves (4.7 source, 1.4 review): a crash between the two leaves no main file, a whole `.bak` and a whole `.tmp`. The read table's "MISSING + USABLE `.bak`" row covers it.
  - Web: verify-after-write proves integrity, not persistence (it reads the in-memory filesystem). Persistence is 1.39's.
- **D5: The resume point follows the dive's respawn point.**
  - `save_now()` sets `slot.resume_*` from `dive.respawn_*` and writes `dive.to_dict()`. A load puts the dive back, so World's existing `_respawn_point()` wakes the player there with no change to World.
  - `"dive": null` means "no dive snapshot": only a progress save made before any resume save writes it. A load then starts a fresh dive at the slot's resume point.
  - At a rest (1.24) the caller resets the dive and sets the station as its respawn point before `save_now()`. An anchor quit (1.34) decides there whether the anchor first becomes the respawn point.
- **D6: A progress save is live progress plus the last resume snapshot.**
  - The snapshot (the `RESUME_KEYS` values and the dive part) is taken in memory at each load and each **successful** resume save. `save_progress()` overlays it on `slot.to_dict()`.
  - So a progress save never moves where you wake, never makes carried embers safe, and (once 1.22 adds `"cache"` to `RESUME_KEYS`) never clears a cache that the last resume save still holds.
  - Not re-read from disk: the snapshot is what this session last loaded or wrote, and the store's guard already refuses a slot that turned bad on disk.
- **D7: Saves are armed, like settings writes.** A World added by a test never boots, and from 1.24 a rest calls `Game.save_now()` inside smoke tests. Unarmed saves do nothing, so no test can reach the player's `user://slot_1.json` by accident. A test that wants a real save points `Game.store.dir` at a temp folder and calls `Game.load_slot(1)` or `Game.new_game(1)` first.
- **D8: Play time.** Counted by World on `_process` in real seconds, capped at 0.25 s a frame, as whole seconds plus a private fraction. It counts through the death wait and (later) menus that don't pause the tree. Story 1.33 must keep the title from counting.
- **D9: Depth** is a slot record like `best_chain`: it only rises. In E1 it is the shaft's own screen row; the bottom-exit loop doesn't add rows.
- **D10: `Migrations` takes the whole file dictionary**, so a step can move data between `slot`, `dive` and `meta` (4.1 remaps ids in all three). `VERSION` lives in `rules/` because the steps and the number must change together.
- **D11: Settings share the verified write, and get no `.bak`.** A lost `settings.json` falls back to the defaults and is rewritten; that was accepted at the 1.4 review and stays. A failed write now has a signal, `settings_save_failed(err)`; whether the UI shows it is 1.39's call.
- **D12: A dev session is detached from the slot (Q1, sonlm 2026-11-25).** The same rule as `--set` and `settings.json` (1.11 D8): a dev value must never reach the file a normal run reads. `--room` then always wins, because no respawn point is loaded, and `--chain`'s best chain and a dev room's visit stay in memory. Only an arg that was applied detaches: a refused `--room=typo` leaves a normal session.
- **D13: A saved respawn point World can't use is a warning**, checked with `RoomLoader.inspect()` before the first build. Today `inspect().entries` lists `spawn` and the exit sides. **Story 1.24 must add anchor and station ids to it**, or this check will reject every saved anchor.

### Probed on Godot 4.7.2 at story creation (Linux, headless)

- `DirAccess.copy_absolute()` prints an engine `ERROR:` when the source is missing or unreadable, or the destination can't be opened. It overwrites an existing destination.
- `DirAccess.rename_absolute()` replaces an existing target on Linux and returns `OK`; on a failure (a missing folder, a read-only folder) it returns `FAILED` and prints nothing.
- `FileAccess.open()` for writing in a missing or read-only folder returns null and prints nothing (`get_open_error()`: `ERR_FILE_NOT_FOUND` / `ERR_FILE_CANT_OPEN`).
- `DirAccess.remove_absolute()` on a missing file returns `FAILED` and prints nothing.
- `store_string()` returns a `bool`.
- `JSON.new().parse()` on an empty or truncated text returns error 43 and prints nothing; `"null"` parses to `null`.
- `JSON.stringify()` sorts keys, writes `null` for `null`, and an int as `1795000000`; it parses back as a float with `has("dive") == true` and the value `null`.
- A file with invalid UTF-8 makes `get_as_text()` print `Unicode parsing error, …` (not an `ERROR:` line); the parse then fails. A test of it is optional.
- A static function is a valid `Callable` in a dictionary (`{1: Migrations.migrate_v1_to_v2}`), and `{1: f}.has(1.0)` is false.
- The server's test user is uid 1000, so a folder with permissions `0555` refuses a new file; root and Windows don't (skip there).

### Calls made at story creation without a question (sonlm may veto)

- **A partly bad slot loads** with defaults for the bad fields and one warning, and may be saved again (1.4 D3).
- **An unreadable or newer main file blocks the slot** even when an older `.bak` would load.
- **New Game deletes the slot's old files first**, so an overwritten game's `.bak` can never come back.
- **A resume save always writes the dive** (even an empty one); `null` is only "never resume-saved".
- **Play time is real time**, capped per frame, and counts while dead.
- **`save_succeeded` carries the slot number**, like `save_failed`.
- **Settings get the read-back and a signal, but no `.bak`.**
- **A damaged slot 1 can't be saved to until 1.38** brings overwrite and delete: the game plays from defaults and every save fails with a warning. Only dev builds exist until then.

### Questions for sonlm (answered at story creation, 2026-11-25)

- **Q1 (D12, the ledger item "A dev session meets the save"): what may a dev session write?**
  - (a) **Recommended:** a session started with `--room`, `--chain`, `--hp` or `--perf` loads no slot and saves none.
  - (b) It loads the slot and never saves.
  - (c) It loads and saves like a normal run; a saved respawn point beats `--room`.
  - **Answer (sonlm, 2026-11-25): (a), no load and no save.**
- **Q2: a DevTools `--save` arg, to see one real save on Windows and in the browser before 1.24?**
  - (a) **Recommended:** no. The first real save arrives with 1.24's rest and its laptop look; 1.39 adds the browser reload check.
  - (b) Yes: `--save` saves once at the first room and logs the result.
  - **Answer (sonlm, 2026-11-25): (a), no `--save` arg; the first real save is 1.24's.**

### Testing standards

- Tests extend `Node` and run through `tests/runner.tscn`; `ok …` / `FAIL …` lines and a final `PASS` / `FAILED`. Any `SCRIPT ERROR` / `ERROR:` line fails the run. Name new tests `test_*.gd` (the runner globs them).
- **`test_migrations.gd` is pure**: fresh dictionaries, no `Game`.
- **`test_saves.gd` uses `Game`** on `const TMP := "user://test_saves_tmp"`: create it, point `Game.store.dir` at it, and after **every** `Game.reset_for_tests()` point it there again (the reset points the store home). End with the reset, remove the folder, then check the player's files.
- **Count warnings and signals, don't assume them.** Copy `test_state.gd`'s `WarningCounter` (filter on this story's prefixes); collect signal emits in an array and disconnect the handler at the end. A lambda connected to a `Game` signal that captures a state object keeps it alive, and the leak prints an engine `ERROR:` after the runner exits (1.4 review).
- **Compare files byte for byte** (`FileAccess.get_file_as_string()`, only on a file that exists: it prints an error on a missing one) for every "left as it was" check.
- **A check whose expected value comes from the code under test proves nothing** (1.16 review): write expected dictionaries by hand, and build the corrupt and newer files as literal strings.
- Validators and reads return data; tests inspect it and never trigger `push_error`.
- Headless tests can't judge feel; this story has none to judge.

### Project Structure Notes

- **New:** `scripts/rules/migrations.gd`, `tests/test_migrations.gd`, `tests/test_saves.gd` (+ `.gd.uid` each).
- **Changed:** `scripts/rules/slot_state.gd`, `scripts/core/save_store.gd`, `scripts/core/game.gd`, `scripts/world/world.gd`, `scripts/dev/dev_tools.gd`; `tests/test_state.gd`, `tests/smoke_world.gd`, `tests/smoke_dev_tools.gd` (or `test_dev_args.gd`); comment-only in `scripts/rules/dive_state.gd`; docs, the ledger, `project-context.md`, `game-architecture.md`.
- **Layering:** `migrations.gd` is `rules/` (pure). `save_store.gd` and `game.gd` are `core/` and read only `rules/` (`Migrations`, the state classes). `Time.get_unix_time_from_system()` is called in `core/`, never in `rules/`. World calls `Game.slot` rule methods (lint `state_write` allows method calls, never assignments).
- **No** autoload, addon, `.tres`, Tuning key, string key, input action or export-preset change. No fixture file: 1.41 captures `slot_v1.json`.

### Project Context Rules (from `project-context.md`)

- Godot 4.7.2, GDScript only. `Game` and `Audio` are the only autoloads; `Game` holds refs and commands, **no rules**.
- **`Game` keeps the same state instances all session**: load and New Game go through `from_dict()` / `reset()`, never a new `SlotState` / `DiveState` (the setters assert).
- **Write state only through rule methods that emit signals**; no event bus. UI writes only `Settings` and changes gameplay state through `Game` commands (hence `Game.set_difficulty()`).
- **Saves:** `user://slot_N.json`, `.tmp` → verify → rename, keep `.bak`, integer `version` + migrations; parse all JSON with `JSON.new().parse()` (`JSON.parse_string()` and `ConfigFile` print engine `ERROR:` lines). Failures surface as a state signal; never crash or pause on them. Resume saves vs progress saves as in R14.
- **Errors:** programmer errors → `assert` (a slot number outside `1..3`, a negative play-time step); environment errors (every file problem, every bad value in a file) → return `Error` / `Found`, `push_warning`, a signal. Never `push_error` for save data.
- **`rules/` never mentions `Node`, `Input`, `Engine`, `Game`, `OS`, `Time` or file access** (lint `rules_purity`); `core/` never names a class or path from a layer above (`core_layer`).
- **No bare `print()`**: `Log.info(Log.SAVE, …)` for milestones (a slot written, a slot loaded); nothing per frame.
- **`_process` is visuals and bookkeeping only**; gameplay stays in `_physics_process`. Only `Game.clock` writes `Engine.time_scale` (World only reads it).
- **Branch with `OS.has_feature("web")` only in the five named places**; this story adds none.
- **Nothing outside `dev/` references `dev/`**: `Game.detach_slot()` is a `core/` method DevTools calls, like `override_setting()`.
- **Every deferred item needs an owner**, set by the agent that defers it (`test_deferred_owners`).
- Commit `.gd.uid` files with their sources. Comments explain why and cite the design.

### Previous story intelligence

- **1.4 (state objects, `SaveStore`, `settings.json`)** is this story's base. Its review found checks that could not fail ("through `.tmp`" passed for a direct write; "one warning" was never counted; a failed write passed when no write was tried). AC8 asks for the marker `.tmp`, counted warnings and byte comparisons for that reason. It also set: an unopenable or newer file is never written over; half a respawn point never loads; a float above 2^53 is not a count.
- **1.11 (DevTools):** `--set` already makes a session write no `settings.json` (D8, sonlm). D12 gives slots the same shape. Args apply only when World is the current scene; tests inject `tokens`.
- **1.13:** `tools/export.sh` boots the Linux release build for 5 s on a fresh `user://` (`XDG_DATA_HOME` per build), so boot's slot load meets a missing file there. Any `ERROR:` in that boot fails the build.
- **1.19 / 1.20 reviews:** state every tick or order claim exactly; a doc sentence that overstates what the code does gets flagged. Each story's commits carry docs, the ledger and `project-context.md` with the code (`84df0b7`, `6801e99`).
- **Memory: probe engine claims before acting on them.** The file calls above were probed; probe again before relying on anything not in that list (Windows and web behaviour were not probed here: the Windows rename is from the 4.7 source).

### What later stories take from this

- **1.22:** add `"cache"` to `SlotState.RESUME_KEYS`; `deposited` is progress; `--difficulty` gets `detach = true`.
- **1.24:** the rest sets the station as the dive's respawn point, then calls `Game.save_now()`; `RoomLoader.inspect().entries` must list anchor and station ids (D13); smoke tests arm saves on a temp folder (D7). Its laptop look is the first real save on Windows and web.
- **1.33 / 1.38:** `Game.load_slot(n)` and `Game.new_game(n, tier)` exist; World must rebuild after either when called mid-session; `Game.store.read_slot(n)` gives `found` and `meta` for the picker; the title must not count play time.
- **1.34:** the anchor quit is `Game.save_now()`; quit elsewhere needs no save (progress saves already ran).
- **1.36:** Options calls `Game.set_difficulty(tier)`.
- **1.39:** `OS.is_userfs_persistent()` goes in front of `Game`'s slot write; the UI binds `save_succeeded` / `save_failed` (and may bind `settings_save_failed`); "is a save still failing" is UI state built from the two signals.
- **1.41 / 4.1:** the fixture, the schema guard, then `Migrations.VERSION = 2` with `steps()` returning `{1: migrate_v1_to_v2}`.

### References

- Story source: `_bmad-output/planning-artifacts/epics.md` → Story 1.21 (AR11, AR14, AR37, AR38, R14, R15; FR29, FR30, NFR13). Neighbours: 1.22, 1.24, 1.33, 1.34, 1.36, 1.38, 1.39, 1.41, 4.1.
- Architecture `_bmad-output/game-architecture.md`: Data Persistence; State Management; Error Handling (environment errors); Logging; Data Patterns ("save/load: only Game commands"); ADR-6; Debug Tools (arg phases).
- GDD `gdd.md` → Platform-Specific Details → Saves; `decision-log.md` → R14 Progress saves.
- UX `EXPERIENCE.md`: State Patterns (Autosave, Save failed, Empty slot), Component Patterns (Slot picker, Autosave icon). No UI is built here.
- Ledger `deferred-work.md`: "Settings writes skip the checks that slot saves get" (from the 1.4 review) and "A dev session meets the save" (from 1.11), both owned by this story.
- Previous stories: `1-4-state-objects-in-the-game-autoload.md` (D2–D7, Review Findings), `1-11-devtools-entry-args-and-overlays.md` (D8, ledger item 4), `1-13-export-pipeline-and-web-boot-smoke.md` (the fresh `user://`).
- Code: `game/scripts/core/save_store.gd`, `game/scripts/core/game.gd`, `game/scripts/rules/slot_state.gd`, `game/scripts/rules/dive_state.gd`, `game/scripts/world/world.gd`, `game/scripts/dev/dev_tools.gd`, `game/tests/test_state.gd`.

## Dev Agent Record

### Agent Model Used

Claude Fable 5.2 (claude-fable-5-2), gds-dev-story, 2026-11-25.

### Debug Log References

- `cd game && ./run_tests.sh` → `== ALL GREEN (33 tests)`, 2484 `ok` lines (2142 after Story 1.20). New: `test_migrations` 22, `test_saves` 211. Grown: `test_state` 256, `test_dev_args` 138, `smoke_world` 92, `smoke_dev_tools` 147.
- `tools/export.sh` → `== BUILD OK builds/20261125-6801e99-dirty, web download 11.0 MB (gzip; raw 40.8 MB), licences in 4 folders, PCK files windows 96 / linux 96 / web 96 / web_debug 104, 99 s`. It needs Node 24 on `PATH` (`~/.nvm/versions/node/v24.22.3/bin`); the agent's shell found the system Node 18 first and the preflight refused it.
- Probes on 4.7.2 (scratch project, headless), beyond the story's list:
  - `FileAccess.open()` for writing on a read-only file (0444) and in a read-only folder (0555) returns null with error 12 and prints nothing; `set_unix_permissions()` works on a folder; `DirAccess.remove_absolute()` in a read-only folder returns `FAILED` silently.
  - **`delta / Engine.time_scale` in `_process` over-counts real time on every frame a hitstop lands.** A scene that requested a ×0.05 hitstop every 20 physics ticks counted 5.59 s over 4.00 s of wall time (12 hits; each landing frame read 0.139 s for a 0.007 s frame, 0.25 s with the cap at 60 fps). The wall clock between frames counted 4.00 s.
- Real runs, headless, on a scratch `XDG_DATA_HOME` (never the player's folder), `--quit-after 120`:
  - with a slot file and no args: `[save] slot 1 loaded`, then `[room] SMOKE boot ok`; the file byte for byte afterwards;
  - `-- --room=m1_shaft --log=save`: `[save] slot: detached for this session; no slot file is read or written`, `[room] dev: log save, room m1_shaft@spawn, no slot loaded or saved`, no `slot 1 loaded` line: DevTools applies before `Game.boot()`;
  - `-- --log=save`: `[room] dev: log save`, then `[save] slot 1 loaded`;
  - a fresh folder: no slot line, no warning, no slot file created.
- Mutants, each on a scratch copy of `game/` with its own `user://`, each failing the named suite (the unmutated copy passes):
  - `test_saves`: no `.bak` step; the `.bak` step copying a corrupt main file; the damaged guard removed; `save_progress()` writing the live dive; saves armed by default (the story's five); the snapshot retaken by a failed resume save; the newer guard removed; a write straight to the file (also fails `test_state`); `reset_for_tests()` not disarming; `reset_for_tests()` not attaching; `set_difficulty()` always saving; `new_game()` keeping the old files; a detached `load_slot()` reading; a newer main file bypassed for its `.bak`; the shape judged before the version; `save_now()` not moving the resume point; a `null` dive ignoring the resume point; no `settings_save_failed`; `boot()` not loading the slot.
  - `smoke_world`: the story's `delta / Engine.time_scale` formula; no clock restart after a pause; no cap; no depth record; no respawn-point check; the check not clearing the point.
  - `smoke_dev_tools`: never detaching; a refused arg detaching; `boot()` not loading the slot.

### Completion Notes List

**Built**

- **AC1 `SlotState`:** `play_time`, `depth`, `resume_room` / `resume_entry`, `add_play_time()`, `record_depth()`, `set_resume()`, `meta()`, `RESUME_KEYS`, signals `play_time_changed` / `resume_changed`; `to_dict()` / `from_dict()` / `reset()` / `_assign()` extended. `test_state`'s fallback cases now start from one whole clean dictionary with a single fault each (`_slot_dict()`): with four new keys, the old hand-written cases would have been unclean whatever they tested.
- **AC2 `Migrations`:** `rules/migrations.gd` (`VERSION` 1, `steps()`, `migrate()`), pure; `test_migrations`.
- **AC3 / AC4 `SaveStore`:** `SLOTS`, `slot_path()`, `read_slot()`, `write_slot()`, `delete_slot()`, `verify_file()`, `version` / `steps`; one private `_write(path, text, backup)` for slots and settings; `_copy()` with `FileAccess`.
- **AC5 / AC7 `Game`:** the three signals, `active_slot`, arming, the resume snapshot, `load_slot()`, `save_now()`, `save_progress()`, `set_difficulty()`, `new_game()`, `delete_slot()`, `detach_slot()`; `boot()` loads the active slot after the settings; `reset_for_tests()` disarms, attaches, resets `active_slot` and the snapshot.
- **AC6 World:** play time, the depth record, the respawn-point check.
- **AC7 DevTools:** `detach` on every `ARGS` row; `_apply()` detaches once and ends its summary line with `no slot loaded or saved`.
- **AC8:** `tests/test_saves.gd`, every listed case, plus the read table row by row.
- **AC9:** docs, both ledger items closed, five deferred items with owners, green suite, `BUILD OK`.

**Departures from the story text (each for sonlm and the reviewer to confirm or veto)**

1. **AC6: play time is counted from the wall clock, not `delta / Engine.time_scale`.** The AC gives that formula and also says "Real seconds: hitstop … don't change it". On 4.7.2 the two disagree: the formula reads a frame about 20 times too long whenever a Clock request lands in it (project-context already warns of this for visuals), which is every pogo hit. Probed: 5.59 s counted for 4.00 s real. World now measures `Time.get_ticks_usec()` between frames (as `dev/overlays.gd` and `perf_run.gd` already do), keeps the 0.25 s cap, and restarts the clock on `NOTIFICATION_UNPAUSED` so the paused time is never counted. The AC's test calls move to a seam, `World._count_play_time(real_seconds)` (eight of 0.25 → exactly 2; 5.0 then three of 0.25 → exactly 1), and `smoke_world` adds a case the formula fails: 20 hitstops over 2.4 s add 2–3 s (the formula adds 5).
2. **AC3: a file's version is judged before the rest of its shape.** A version-2 file with no `slot` object reads `NEWER`, not `CORRUPT`: a newer build may change the shape, and `CORRUPT` would let an older `.bak` load and the next save replace the newer file (D3 forbids exactly that). The `slot` / `dive` shape is then checked before a migration runs (so a step may rely on it) and again after it. A version above 2^53 is `CORRUPT` (never a number a build wrote; the same rule as `_count()`).
3. **`Game.new_game()`:** when `store.delete_slot()` fails, it warns once, emits `save_failed(n, err)` and returns that error without saving: an old file is still there, so the slot is not the new game. Detached, it also sets the asked tier in memory (the AC says only "resets them"), so a dev session still plays the tier it was asked for. The delete-failure path has no test (nothing here can make a delete fail without also failing the write).
4. **`Game.delete_slot()` detached returns `ERR_UNCONFIGURED`** and removes nothing ("no `Game` command reads or writes a slot file"). A detached `load_slot()` leaves `active_slot` as it was.
5. **`Game.reset_for_tests()` also restores `store.version` and `store.steps`,** so a test of the migration path can't leak its fake steps.
6. **`SaveStore._write()` removes `.tmp` when `store_string()` fails too,** not only when the read-back fails.
7. **`tools/web_smoke/smoke.spec.js` and `docs/build.md`** pin DevTools' summary line for `?room=perf_worst`; it is now `[room] dev: room perf_worst@spawn, no slot loaded or saved`. The export's web smoke failed on the old line and passes on the new one. (Reworded at the code review: the line shows the detach branch ran, on empty browser storage; it does not show that no slot was read. `smoke_dev_boot` shows that off the web, and the reload check is Story 1.39's.)

**What the tests can't show**

- The read-back's call site inside `_write()`: nothing can make `.tmp` come back short, so a build without that call passes `test_saves`. `verify_file()` itself is tested. Ledgered to Story 1.39.
- Windows and the browser: the rename's delete-then-move and persistence were not run here. The read table's "missing main file + usable `.bak`" row is tested as files, on Linux. The first real save on Windows and web is Story 1.24's laptop look.
- The play-time cases in `smoke_world` use the wall clock (`OS.delay_msec`, a 2.4 s loop). Their bounds are wide (1–3 s for 2.4 s), but a machine that stalls for seconds could still fail them.

**Deferred (owners assigned in `deferred-work.md`)**

- A saved anchor or station is not yet an entry World accepts → **Story 1.24**.
- A load or a new game made mid-session leaves the old room standing; the title must not count play time → **Story 1.33**.
- A damaged or newer slot 1 can't be saved to until overwrite and delete exist → **Story 1.38**.
- The read-back's call site has no failing test → **Story 1.39**.
- A failed `.bak` copy is seen only through `store_buffer()`'s result (no read-back of the `.bak`) → **Story 1.41**.

**Verdict:** tests green (33 tests, 2484 checks) and `BUILD OK`. No laptop look needed: nothing on screen changes and nothing in play saves until Story 1.24.

### File List

New:

- `game/scripts/rules/migrations.gd` (+ `.gd.uid`)
- `game/tests/test_migrations.gd` (+ `.gd.uid`)
- `game/tests/test_saves.gd` (+ `.gd.uid`)

Changed:

- `game/scripts/rules/slot_state.gd`
- `game/scripts/rules/dive_state.gd` (comment only)
- `game/scripts/core/save_store.gd`
- `game/scripts/core/game.gd`
- `game/scripts/world/world.gd`
- `game/scripts/dev/dev_tools.gd`
- `game/tests/test_state.gd`
- `game/tests/test_dev_args.gd`
- `game/tests/smoke_world.gd`
- `game/tests/smoke_dev_tools.gd`
- `tools/web_smoke/smoke.spec.js`
- `docs/architecture.md`
- `docs/component-inventory.md`
- `docs/source-tree-analysis.md`
- `docs/development-guide.md`
- `docs/build.md`
- `_bmad-output/game-architecture.md`
- `_bmad-output/project-context.md`
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/1-21-save-store.md`

Code review (2026-11-25), new: `game/tests/smoke_dev_boot.gd` (+ `.uid`). Changed: `game/scripts/core/game.gd`, `game/scripts/core/save_store.gd`, `game/scripts/rules/migrations.gd`, `game/scripts/world/world.gd`, `game/tests/test_saves.gd`, `game/tests/test_migrations.gd`, `game/tests/smoke_world.gd`, `docs/architecture.md`, `docs/component-inventory.md`, `docs/source-tree-analysis.md`, `_bmad-output/game-architecture.md`, `_bmad-output/project-context.md`, `_bmad-output/implementation-artifacts/deferred-work.md`, `_bmad-output/implementation-artifacts/sprint-status.yaml`, this file.

## Change Log

- 2026-11-25: Story created (gds-create-story). Ultimate context engine analysis completed: comprehensive developer guide created. Q1 and Q2 answered by sonlm (a dev session loads and saves no slot; no `--save` arg). Status ready-for-dev.
- 2026-11-25: Implemented (gds-dev-story), Tasks 1–9. Slot saves through `SaveStore` and `Game`, `Migrations`, play time, depth, the resume point, the saved respawn point check, the dev-session detach rule; `test_migrations` and `test_saves` added. Seven departures from the story text are listed in the Completion Notes, the main one being play time counted from the wall clock (the AC's `delta / Engine.time_scale` over-counts on every hitstop frame, probed). Two ledger items closed, five deferred with owners. 33 tests, 2484 checks, `BUILD OK`. Status review.
- 2026-11-25: Code review (gds-code-review; Blind Hunter, Edge Case Hunter, Acceptance Auditor; 46 raw findings). 3 decisions answered by sonlm (a deleted active slot is reset and disarmed; the `.bak` is copied through `.bak.tmp`, compared and renamed; the seven departures confirmed), 13 patches applied, 4 deferred with owners (1.24, 1.33, 1.38, 1.39) plus one ledger line from a patch (the wall-clock test cases, 1.41), 10 dismissed. `Game` now remembers a refused load, disarms while a load or a new game replaces the state, and moves the resume point only after a successful save; the store deletes the main file last and leaves no `.tmp` after any failure. 34 tests, 2541 `ok`. Status done.
