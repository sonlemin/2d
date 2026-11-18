---
baseline_commit: 9a55dc4
---
# Story 1.10: Room smoke tests and the reachability bot

Status: done

**Type:** dev · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** CP1 Foundations (1.1–1.15) · **Branch:** `feat/m2-e1`

## Story

As the level designer,
I want every room checked for fairness and reachability automatically,
so that a layout change can never quietly break a guarantee.

## Acceptance Criteria

1. **Every room file is found and validated.** `tests/smoke_rooms.gd` walks every `res://rooms/**/*.txt` itself, sorted by path. It needs at least one file and must see `rooms/l1/m1_shaft.txt`. For each file it runs `RoomLoader.parse()` + `validate()`, prints one `FAIL` per error, and builds only valid files, so a bad file never triggers `push_error`. Rooms under `rooms/dev/` are only validated, never swept for fairness and never run by the bot. (AR50; D3)
2. **Cross-file checks.**
   - Room ids (file base names) are unique across all files, and so are `obj=` ids.
   - Every exit target names a room that exists, and that room has the arrival entry: a `down` exit needs the target to have an `up` exit, and an `up` exit needs a `down` exit.
   - Every arrival from below (a room's `down` entry) is safe, per D11.

   This closes the two ledger items owned by 1.10. (AR50; D4, D11)
3. **Spine falls and hazard pits.** In every `spine=true` room (outside `rooms/dev/`), no fall between consecutive ledge rows is longer than `Spec.LEDGE_FALL_MAX`. That is 1.5 s at 210 px/s = 315 px (GDD Level Types), measured as the vertical gap between consecutive ledge rows across all columns, unless the stretch is declared a narrow cling stretch in the room header (`cling=<from>-<to>`). The fall through a `down` exit into a spine target counts too. A declared cling stretch must really be narrow: every open run in each of its rows is 6–10 tiles wide (GDD Narrow stretch). In every swept room, every hazard pit has a ledge or a cling stretch within a 1.5 s fall above it; no hazard char exists until 1.19, so this is proven on inline samples. `Spec.LEDGE_FALL_MAX` divided by the tuned max fall is never more than `Spec.LEDGE_FALL_TIME`. (AR50, NFR10, FR57; D5–D8)
4. **Lurker guarantees in every swept room.** The room is loaded standalone through `tests/room_harness.gd`, with its stub node in group `world` that provides `play_rect()`.
   - **For every lurker, sorted by position:**
     - base light (`Spec.BASE_LIGHT`) is never noticed, even point-blank;
     - the largest light under `Spec.NOTICE_MIN_RADIUS` is never noticed, while one more link is noticed from the same spot (a control);
     - a big light is never noticed while the lurker is outside the play rect, though it is within light reach (a premise check);
     - the telegraph lasts at least `Spec.TELEGRAPH_MIN` (measured to within one frame) before the hunt.
   - **For the first lurker in each room:**
     - an IDLE lurker is harmless on contact, and a HUNTING one kills;
     - a Snuff, a landing and a cling, each taken in time against a hunting lurker, drop its lethality (`monitorable` off) on the escape frame. The player is still alive 1.2 s later, and the lurker leaves HUNT.

   (AR50, NFR10; D9)
5. **The bot.** `tests/smoke_bot.gd` runs every `spine=true` room (outside `rooms/dev/`), sorted by path, from its top entry down to its `down` exit. It uses plain movement and no dash, with lurkers paused. In each room:
   - it reaches a chain of at least `Spec.BOT_MIN_CHAIN` (`m1_shaft` today);
   - the exit backstop never fires on its line: the chain is 0 whenever the body crosses an exit;
   - it reaches the `down` exit when the room has one, alive.

   Targets are picked by position, never by group index. (AR50; D10)
6. **`smoke_shaft.gd` is gone, and none of its checks is lost.** Each check moves to `smoke_rooms`, `smoke_bot` or a new `smoke_moves.gd`, or is dropped where `smoke_player_input` already covers it; D1 lists where each goes. `test_room_loader`'s FR57 gap check moves to the sweep, and its ledge-row pin stays. (D1, D12)
7. **Done means green.** `cd game && ./run_tests.sh` ends in `== ALL GREEN` with 15 tests. Every new check is red-checked (D14). `docs/rooms.md`, the development guide, the architecture and component docs, `project-context.md` and the ledger say how rooms are checked now. No gameplay script changes behaviour (D13). The only game-code edits are:
   - `RoomLegend.HAZARDS`;
   - the `cling=` header key in `RoomLoader`;
   - the `m1_shaft` walker move in D11 (approved by sonlm).

## Tasks / Subtasks

- [x] **Task 1: Spec, legend and header (AC: 3).**
  - [x] Add `LEDGE_FALL_TIME` and `LEDGE_FALL_MAX` to `tests/spec.gd` with `## GDD` citations (D8). `test_lint`'s `spec_citation` must stay green.
  - [x] Add `const HAZARDS: Array[String] = []` to `scripts/world/room_legend.gd` (D7).
  - [x] `RoomLoader`: accept `cling=<from>-<to>` (repeatable) and validate it (D6). Add the validator cases to `test_room_loader.gd`.
- [x] **Task 2: The pure sweeps (AC: 2, 3).**
  - [x] Create `tests/room_sweep.gd` (helper: `extends RefCounted`, no `class_name`, static functions only) per D2 and D4–D7, plus D11 as decided.
  - [x] Create `tests/test_room_sweep.gd`. Inline-grid samples prove each function fires and stays quiet where it must, including near-misses.
- [x] **Task 3: `smoke_rooms.gd` (AC: 1–4).**
  - [x] The file walk, validation, cross-file and per-room sweeps (D3–D8, D11), and the `LEDGE_FALL_MAX` / max-fall check.
  - [x] The per-lurker and per-room lurker scenarios (D9), on a fresh harness per scenario where a death or state could leak.
- [x] **Task 4: `smoke_bot.gd` (AC: 5).** The full-room descent bot (D10).
- [x] **Task 5: Retire `smoke_shaft.gd` (AC: 6).**
  - [x] Create `tests/smoke_moves.gd` with the M1 move checks (D1).
  - [x] `git rm` `smoke_shaft.gd` and its `.uid`.
  - [x] Drop the FR57 gap check (and `LEDGE_GAP_MAX_ROWS`) from `test_room_loader.gd`; keep its ledge-row pin.
- [x] **Task 6: `m1_shaft` arrival (AC: 2).** Apply D11 option A (sonlm approved the edit, 2026-11-18): move the walker at (4, 102) to (8, 102). Red-check `arrival_errors` against the old position first (D14 #12).
- [x] **Task 7: Docs and ledger (AC: 7).** Per D13. Close the two 1.10-owned items in `deferred-work.md` with `→ **Closed (Story 1.10): …**` lines.
- [x] **Task 8: Verify (AC: 7).**
  - [x] `./run_tests.sh` → `== ALL GREEN (15 tests)`, with no `ERROR:` lines.
  - [x] Run the D14 red checks, and record each in the Debug Log.
  - [x] Every new `.gd.uid` is staged.
  - [x] Report "tests green; needs a 1-minute look at the shaft's bottom on the laptop". D11 moved a walker: fall to the bottom, land, and walk to the hole.

### Review Findings

Code review 2026-11-19 (Blind Hunter, Edge Case Hunter, Acceptance Auditor; scope `9a55dc4..cada033`).

- [x] [Review][Decision] The lose-track bound moves with tuning — `smoke_rooms` checks "leaves HUNT within `lurker_lose_track_time` + 0.2 s" (D9), so raising the tuning value raises the bound and still passes. The deleted M1 check was a fixed "loses track within 1 s", and the Debug Log's "stricter" holds only at today's 0.6 s. Options: keep D9's bound and restore M1's fixed 1 s next to it (nothing lost, no new guarantee); add a cited `Spec.LOSE_TRACK_MAX` (GDD line first, with sonlm); or keep D9's bound alone and fix the wording. **Resolved (sonlm, 2026-11-19): keep both** (patch below).
- [x] [Review][Decision] A testing rule was added to `project-context.md` beyond D13 — "a new per-room rule is a pure function in `tests/room_sweep.gd` with a firing sample and a near-miss, never a test on one room", plus the gate clause "(and, from E4, …)". The file says to *propose* rule changes. Keep or drop? **Resolved (sonlm, 2026-11-19): keep it**, no change.
- [x] [Review][Patch] Restore M1's fixed "loses track within 1 s" next to D9's tuning-relative bound, and correct the Debug Log's "stricter" wording (decision above) [game/tests/smoke_rooms.gd:405]
- [x] [Review][Patch] The point-blank Snuff escape was lost: M1 forced the hunt 18 px away, now every escape starts 48 px away, where a braking lurker (≈ 10 px coast) can't reach, so "alive 1.2 s later" can't fail through a lethality bug (AC6). Add the 18 px Snuff case [game/tests/smoke_rooms.gd:19]
- [x] [Review][Patch] The notice-floor control loop can hang: it stops on `chain.count < 30`, but the chain caps at 20, so a lurker floor above 138.4 px never ends it [game/tests/smoke_rooms.gd:241]
- [x] [Review][Patch] The off-screen verdict has no positive control at the same distance on screen, and the placement probes only up/down (a wider room's gutter case is never swept) [game/tests/smoke_rooms.gd:286]
- [x] [Review][Patch] Contact never checks that a TELEGRAPHING lurker is harmless, and the HUNT control doesn't check the lurker was lethal (monitorable) at contact [game/tests/smoke_rooms.gd:304]
- [x] [Review][Patch] The bot's no-down-exit "floor" ending is off by one: it uses feet = y + 12, a resting body sits at 83.993 and floors to the row above; `_drop_x` uses + 13. The branch never runs on m1_shaft; prove it on a scratch room [game/tests/smoke_bot.gd:117]
- [x] [Review][Patch] A valid room with no `P` and no up exit asserts in `entry_position()` (engine error, not a named FAIL): the bot builds at `&"spawn"` unguarded, and `smoke_rooms` runs the world-stub check on the first swept room whatever its entry [game/tests/smoke_bot.gd:69]
- [x] [Review][Patch] `record()` re-parses the header with its own regex copies and silently drops what doesn't match; nothing ties it to what the loader builds (E4's left/right exits would vanish from the link and arrival sweeps). Cross-check `record()` exits and obj ids against the built `Room` [game/tests/room_sweep.gd:54]
- [x] [Review][Patch] Spine falls from the top entry to the first safe row, and from the last safe row to the down hole, are never measured unless the neighbour is a swept spine room (FR57 is any fall) [game/tests/room_sweep.gd:120]
- [x] [Review][Patch] A production room may link into `rooms/dev/`, which release exports exclude and the sweeps skip [game/tests/room_sweep.gd:224]
- [x] [Review][Patch] A notch counts as a ledge: one open cell above a solid one, with a wall right above that; the body needs two open cells (`down_entry_cell`'s rule) [game/tests/room_sweep.gd:90]
- [x] [Review][Patch] The cling escape searches only a 1-tile left wall; a room whose only cling wall is on the right, or thicker, skips it; the cling and stand cells use `solid_at`, which treats a crawler cell as open [game/tests/smoke_rooms.gd:438]
- [x] [Review][Patch] `NARROW_MIN` / `NARROW_MAX` are GDD guarantees living outside `Spec` (project rule: guarantees compare against `tests/spec.gd`; the citation lint can't see them) [game/tests/room_sweep.gd:17]
- [x] [Review][Patch] The stub check compares against `CameraRig.PLAY_WIDTH`; M1 pinned 360 px and `smoke_world` writes UX numbers out, never reading them from CameraRig [game/tests/smoke_rooms.gd:196]
- [x] [Review][Patch] `smoke_moves`: built through the id index (a duplicate id push_errors), no setup check before the landing, the cling grace check can't tell a bank from a loss, the Snuff release has no "still held" control and reads after one frame, and the comment names the wrong hoverer row [game/tests/smoke_moves.gd:32]
- [x] [Review][Patch] The ledge rule's "a hazard tile is never a ledge" clause has no sample (only "hazard above" is exercised) [game/tests/test_room_sweep.gd:81]
- [x] [Review][Patch] Docs: the development guide still names `set_lurkers_active`; rooms.md says "one more link" (the code adds links up to the lurker's floor) and that a new HAZARDS char needs "no edit" (it must also become a known legend char); README says every lurker gets the escapes (the first per room does); the last-run date and the bot's timing disagree; `project-context.md` Last Updated [docs/development-guide.md:71]
- [x] [Review][Patch] AC7 "every new check is red-checked": no recorded red check for the invalid-file path (FAIL, never built, no `ERROR:`), the walk sentinels, the bot's "alive", the escapes' "alive" and "leaves HUNT", or the bot's floor ending [_bmad-output/implementation-artifacts/1-10-room-smoke-tests-and-the-reachability-bot.md]

## Dev Notes

### What this story is (and isn't)

It is test infrastructure. It turns `smoke_shaft.gd`, which was written for one shaft, into checks that run over **every room file**. Adding a room then adds its checks, with no edit to any test (Architecture → Design Guarantees as Tests). **No gameplay script changes behaviour.** The game-code edits are:
- `RoomLegend.HAZARDS`, an empty list until 1.19;
- the `cling=` header key, which the validator must accept or it is "unknown key";
- one walker moved in `m1_shaft` (D11, approved by sonlm).

**Not in this story:**
- **Chain gates** and "the required chain at every gate" (AR50): E4 builds gate rooms and adds that bot check.
- **The spike char** (a `hazard` tile, 1 damage, back to the last safe ledge): Story 1.19. It adds the char to `RoomLegend.HAZARDS` and a fixture; the sweep here then covers it with no edit.
- **"Stirring never leads to a hunt without an on-screen telegraph"** (AR50): Story 1.27.
- **`rooms/dev/perf_worst.txt`:** Story 1.12. The walk must already treat `rooms/dev/` as validate-only, though the folder doesn't exist yet.
- **`Sensing` / `LightSource`:** Story 1.20 moves the lurker's rule into `rules/sensing.gd`. Here, call `lurker.senses(player)` as `smoke_shaft` does.
- **Cleaning up the old source checks in `smoke_world`** ("randf only in camera_rig", "no KEY_F"). They duplicate the lint but aren't part of this story; leave them.

### Current state (read before changing)

- **`tests/smoke_shaft.gd`** (350 lines, 36 `ok`) loads `m1_shaft` once through `RoomHarness.build(self, &"m1_shaft")` and runs, in order:
  - `test_world_stub`;
  - `test_pogo_builds_chain`;
  - `test_landing_breaks_chain`;
  - `test_jump_height`;
  - `test_wall_cling`;
  - `test_bot_chains_long_run`;
  - `test_lurker_telegraph_hunt_lose`;
  - `test_snuff_escape_point_blank`;
  - `test_lurker_kills`;
  - `test_snuff_needs_hold`, which rebuilds the room because the previous test left the player dead.

  Its helpers are worth keeping:
  - `frames(n)` / `seconds(s)`: `seconds` is `ceil(s × 60)` physics frames;
  - `place(pos)`: teleport, zero the velocity, `camera.snap()`;
  - `_lurkers()`, sorted by y; `set_lurkers_active(on)`; `_hovers()`, sorted by y.

  Since the 1.9 review, the telegraph is **measured**: it polls until TELEGRAPH, counts frames until the state changes, and checks `held + 1 >= ceil(TELEGRAPH_MIN × 60)`. The notice floor has a setup check, a verdict and a chain-4 positive control, with lurkers paused while `senses()` is asked. Keep both patterns.
- **The M1 bot** (`test_bot_chains_long_run`):
  - It starts only in the "long run" (`LONG_RUN_ROWS := Vector2i(44, 84)`, an `m1_shaft` literal), placed 48 px above the first hoverer there, with lurkers paused. It calls `reset_phase()` on each hoverer so the drift is the same whatever ran before.
  - Each frame it steers (`move_left`/`move_right` while |dx| > 3) toward the nearest hoverer below `max(player.y + 4, last_row_y + 8)`, and presses Attack for one frame when `dy < 28 && |dx| < 12 && falling && target != swung_for`.
  - It stops on landing or death, prints `bot ended: frame …`, and checks `best >= Spec.BOT_MIN_CHAIN` and alive. Today's best is **8**.
- **`tests/room_harness.gd`:** `build(parent, room_id, entry := &"spawn")` returns `{room, player, camera, world}`. The room sits at the origin (room-local = global). The `WorldStub` (group `world`) gives `play_rect()` (the camera's, 360 px wide) and `current_room()`. `free_all(parts)` `queue_free`s all four. Pass `&"up"` for a room without `P`.
- **`scripts/world/room_loader.gd`:**
  - `parse(text)` returns `{header: [{key, value, line, ok}], grid, grid_line}`.
  - `validate(path, parsed)` is pure and returns `"<path>:<row>:<col> <what>"` errors.
  - `SINGLE_KEYS = ["id", "zone", "spine", "exits"]`; `obj` is the one repeatable key; **any other key is an error**.
  - `solid_at(grid, cell)`: `#`, or an `L` in the in-wall position.
  - `down_entry_cell(grid, col)` gives the stand cell beside a bottom opening.
  - `load_room(id)` uses an index of `res://rooms/**` (a duplicate id `push_error`s); `load_room_from_path(path)` `push_error`s each validation error.
  - `_build()` ignores header keys it doesn't use (its `match` has no default), so a new `cling` key needs no build change.
- **`scripts/world/room_legend.gd`:** chars `#`, `.`, `P`, and the `SPAWNS` `c` (walker), `h` (hoverer) and `L` (lurker, `in_wall`). No hazard char yet.
- **`rooms/`** holds only `rooms/l1/m1_shaft.txt`: 22 × 105, `spine=true`, `exits=up:m1_shaft@x3, down:m1_shaft@x1`.
  - Ledge rows (solid with open above, columns 1..20): **6, 24, 41, 57, 72, 85, 103**. The worst gap is 18 rows (85 → 103), against the 19 allowed.
  - Arrival from below stands at (3, 102), and **a walker spawns at (4, 102)**, right beside it (the ledger item).
  - 36 hoverers, 5 walkers, 4 lurkers: (0, 28) left wall, (21, 55) right wall, (0, 70) left wall, and **(16, 92) in open air** (not in a wall; the per-lurker checks must still hold for it). The counts are pinned in `test_room_loader`.
- **`tests/test_room_loader.gd`:** a `LEDGE_GAP_MAX_ROWS` (19) FR57 check on `m1_shaft`; its comment says 1.10 takes it over. It also pins the ledge rows, counts and exits. Test rooms live in `tests/rooms/`: validator fixtures (one repeats an obj id on purpose), `swap/`, `input/`. **They are not under `res://rooms/` and must never be swept.**
- **`scripts/actors/lurker.gd`:**
  - States IDLE → TELEGRAPH → HUNT → RETURN.
  - `monitorable` is true only in HUNT while sensed: "lost the scent → harmless at once".
  - `senses(p)`: radius ≥ `NOTICE_MIN_RADIUS` (80), distance ≤ radius × `NOTICE_FACTOR` (1.6), and on screen (`play_rect().grow(-SCREEN_MARGIN 8)`).
  - Tests force a hunt with `lurker._enter(Lurker.State.HUNT)` and `lurker._velocity`, as `smoke_shaft` does.
- **`scripts/actors/crawler.gd`:** a walker walks at `crawler_walk_speed` 25 px/s, starting **left** (`_dir = -1`), and turns at walls and edges. A hoverer drifts ±`crawler_hover_drift` around home. Contact knocks the player back (150, −150) and breaks the chain, with no damage until 1.19. `take_hit()` marks `Game.dive` killed.
- **Light curve:** `ChainState.radius_for(n) = 40 + 22·√n`, capped at `MAX_CHAIN` 20 (138.4 px, reach 221 px). Chain 3 is 78.1 px; chain 4 is 84.0 px.
- **`scripts/world/world.gd`:** the exit backstop is in `_on_exit_reached()`: chain > 0 → `break_chain()` before `enter_room()`. Exits are polled: body centre y past `bounds().end.y` → `down`; y < 0 → `up`. The harness has no `World`, so the bot detects crossings itself (D10).
- **`tests/spec.gd`:** `TELEGRAPH_MIN` 0.75, `BOT_MIN_CHAIN` 5, `BASE_LIGHT` 40.0, `NOTICE_MIN_RADIUS` 80.0. `test_lint`'s `uncited_consts` requires a `## GDD ` comment on every `const` line, and flags any `var`.
- **`run_tests.sh`** globs `test_*.gd` then `smoke_*.gd`, so new files run with no edit. Today it runs 12 tests; after this story, 15 (+`test_room_sweep`, `smoke_rooms`, `smoke_bot`, `smoke_moves`; −`smoke_shaft`).

### Decisions

**D1: Where each `smoke_shaft` check goes.**

| `smoke_shaft` test | New home | Notes |
|---|---|---|
| `test_world_stub` | `smoke_rooms` (harness sanity, once) | the stub gives a 360 px `play_rect()` |
| `test_lurker_telegraph_hunt_lose` | `smoke_rooms` per lurker (D9) | the measured telegraph, notice floor and off-screen checks keep their 1.9-review form |
| `test_snuff_escape_point_blank` | `smoke_rooms` per room (D9 escapes) | extended to landing and cling |
| `test_lurker_kills` | `smoke_rooms` per room (D9 contact) | |
| `test_bot_chains_long_run` | `smoke_bot` (D10) | generalized to full descent |
| `test_pogo_builds_chain`, `test_landing_breaks_chain`, `test_jump_height`, `test_wall_cling` | **new `smoke_moves.gd`** on `m1_shaft` | move checks, not room guarantees; `t_input` has no hoverers, so they stay on the shaft. Pick targets by position (`_hovers()` sorted); no row literals except through the room API |
| `test_snuff_needs_hold` | **dropped** | `smoke_player_input` `test_light_windows` covers tap keeps the chain / hold Snuffs and breaks it at every window boundary |

Every `smoke_shaft` check is accounted for. Record the before → after `ok` counts.

**D2: Pure sweeps in a helper.** `tests/room_sweep.gd` (`extends RefCounted`, no `class_name`, not globbed) holds static, pure functions over a parsed grid (`Array[String]`) and header data. Each returns an `Array[String]` of errors in the validator's style, `"<id>: <what>"`, with rows 0-based and named. `smoke_rooms` and `smoke_bot` preload it, and `tests/test_room_sweep.gd` unit-tests it with inline grids. Suggested API (names may change; record the final ones):
- `room_files(root := "res://rooms") -> Array[String]`: a sorted recursive walk, `.txt` only;
- `is_dev(path) -> bool`;
- `ledge_rows(grid, hazards) -> Array[int]`;
- `cling_stretches(header) -> Array[Vector2i]`;
- `spine_gap_errors(id, grid, stretches, hazards, max_rows) -> Array[String]`;
- `exit_fall_errors(rooms_by_id, max_rows) -> Array[String]`;
- `stretch_width_errors(id, grid, stretches) -> Array[String]`;
- `hazard_pit_errors(id, grid, stretches, hazards, max_rows) -> Array[String]`;
- `duplicate_id_errors(files) -> Array[String]`;
- `link_errors(rooms_by_id) -> Array[String]`;
- `arrival_errors(id, grid, exits, clear_cells) -> Array[String]`.

`max_rows = floori(Spec.LEDGE_FALL_MAX / Room.TILE)` = 19.

**D3: Finding and loading rooms.**
- `smoke_rooms` walks `res://rooms` itself. It doesn't use `RoomLoader`'s index, which `push_error`s on a duplicate and would fail the run with an engine error instead of a named `FAIL`.
- **Sentinels:** at least one file, and `rooms/l1/m1_shaft.txt` is in the list, so a wrong root can't pass as empty.
- **For each file:** `FileAccess.get_file_as_string` (check `get_open_error()`) → `RoomLoader.parse` → `RoomLoader.validate(path, parsed)`. Each error is a `FAIL`. A file with errors is never built.
- **Dev rooms:** under `res://rooms/dev/` → validated only. Not swept, not in the cross-file fairness checks (it does count for unique ids), and not botted.
- **Building swept rooms:** through `RoomHarness.build(self, id, entry)`, with entry `&"spawn"` when the room has `P`, else `&"up"`.

**D4: Cross-file checks (pure, over every file including dev).**
- **Duplicate ids:** the same room id (base name) in two paths names both paths. The same `obj=` id in two files names both.
- **Links:** for each exit `{side, target}`:
  - the target must exist;
  - a `down` exit needs the target to have an `up` exit (arrival at its `up` entry);
  - an `up` exit needs the target to have a `down` exit.

  This matches `World._physics_process` → `_on_exit_reached(target, "up" if side == "down" else "down")`, and `World._swap_room`'s "no entry" `push_error`.

**D5: Spine falls.**
- **Ledge rows:** a row r in 1..h−1 where some column c in 1..w−2 has `RoomLoader.solid_at(grid, (c, r))`, the cell is not a hazard char, and `(c, r−1)` is not solid. This is `test_room_loader`'s definition on the parsed grid.
- **Safe rows** = ledge rows ∪ every row inside a declared cling stretch (D6). Clinging is possible anywhere in one.
- **Error:** for consecutive safe rows a < b, `b − a > max_rows`. Name the two rows and the gap.
- **Fall through an exit:** for a spine room with a `down` exit whose target is also spine, `(h − last_ledge_row) + first_safe_row(target) > max_rows` is an error. `m1_shaft` → itself: (105 − 103) + 6 = 8.
- **Scope:** only `spine=true` rooms outside `rooms/dev/`.

**D6: The `cling=` header key.**
- **Format:** `cling=<from>-<to>`, 0-based grid rows, inclusive, repeatable like `obj`. The validator checks:
  - `^(\d{1,4})-(\d{1,4})$` ("cling '…' is not <from>-<to>");
  - from < to;
  - to < the grid's row count ("cling rows … are outside the grid");
  - overlapping stretches are allowed.

  Document it in `docs/rooms.md` (key table, validator list).
- **Narrow (sweep, swept rooms):** in every row of a stretch, every maximal run of non-solid cells (`solid_at` false) is 6–10 cells wide, per the GDD's "6–10 tiles wide; walls always within reach". The error names the row and the run width.
- No room declares one today. Prove it on samples.

**D7: Hazard pits.**
- `RoomLegend.HAZARDS: Array[String] = []` (doc comment: "tile chars that hurt on contact; 1.19 adds the spike"). A hazard never counts as a ledge.
- **Error (every swept room, spine or not):** a hazard cell (c, r) with a non-solid cell above it has no safe row (D5) in `[r − max_rows, r − 1]`.
- `test_room_sweep` passes a sample hazard set (e.g. `["x"]`), since the real list is empty. `smoke_rooms` passes `RoomLegend.HAZARDS`.
- 1.19 adds the char, its fixture and a sample; this sweep needs no edit.

**D8: Spec.**
- **Two new consts** (keep the `## GDD ` citation on each line; `test_lint` checks it):
  - `const LEDGE_FALL_TIME := 1.5  ## GDD Level Types: spine shaft "ledges every ≤ 1.5 s of fall"; Sequence Breaking: "a ledge or wall to cling to within a 210 px/s fall of 1.5 s".`
  - `const LEDGE_FALL_MAX := 315.0  ## GDD Level Types / Sequence Breaking: 1.5 s at 210 px/s = 315 px; spine ledges and hazard pits are measured in rows against it.`
- **A tuning check in `smoke_rooms`:** `Spec.LEDGE_FALL_MAX / Game.tuning.f(&"max_fall") <= Spec.LEDGE_FALL_TIME + 1e-6`. This catches a slower fall that would make a legal 19-row gap last longer than 1.5 s. The tuned `max_fall` is 210, so the ratio is 1.5 exactly.

**D9: Lurker guarantees (`smoke_rooms`, every swept room with lurkers).**
- **Per lurker** (sorted by position; the others paused while one is tested; the player's physics off for the `senses()` checks):
  1. **Base light point-blank:** break the chain, `place(lurker.global_position)`, wait 1 frame. Check `light_radius() <= Spec.BASE_LIGHT`, then `not senses()`.
  2. **Notice floor:**
     - setup: the largest chain n with `ChainState.radius_for(n) < Spec.NOTICE_MIN_RADIUS` (n > 0);
     - verdict: not sensed point-blank;
     - control: add links until `light_radius() >= Lurker.NOTICE_MIN_RADIUS`, and it **is** sensed from the same spot. Keep `Lurker.NOTICE_MIN_RADIUS >= Spec.NOTICE_MIN_RADIUS` once per run.
  3. **Off-screen:**
     - set `MAX_CHAIN` links, and place the player straight above or below the lurker (whichever the room bounds allow; skip with an explicit `ok … no room above or below` line only if neither) so the lurker is just outside `play_rect().grow(-SCREEN_MARGIN)` after `camera.snap()`;
     - premise check: the distance ≤ `light_radius() × Lurker.NOTICE_FACTOR` and the lurker is not in the grown play rect;
     - verdict: `not senses()`.
  4. **Telegraph:** the lurker active, a big light in range on screen. Poll ≤ 10 frames for TELEGRAPH, count frames until it leaves, check `held + 1 >= ceil(Spec.TELEGRAPH_MIN × 60)`, then state == HUNT. Also check `Game.tuning.f(&"lurker_telegraph_time") >= Spec.TELEGRAPH_MIN` once per run.

  Each lurker costs about 1 s of game time for (4). `m1_shaft` has 4 lurkers. If the total grows past roughly 60 s in E4, split the file by room; don't skip lurkers.
- **Per room** (the first lurker by position; a fresh harness per scenario, because a death or a forced hunt must not leak):
  - **Contact:**
    - an IDLE lurker touched (player physics on) → `died` not emitted;
    - force HUNT with chain 10 and touch → died.
  - **Escapes:** set chain 10 (sensed). Force HUNT with the lurker 48 px beside the player and `_velocity` toward it at `lurker_hunt_speed`. **Premise:** `monitorable` true on the frame before the escape. Then:
    - **Snuff:** `chain.set_snuffed(true)`, at state level as M1 tested it (the point-blank playtest fix);
    - **Landing:** the player starts 6 px above a stand cell (the room's `P`, else its `down` entry cell, else the first ledge cell by row then column with two open cells above), falling. The escape frame is the first with `is_on_floor()`;
    - **Cling:** the player is falling beside a 1-tile wall (the first row from the top where column 0 is solid and columns 1–2 are open for 6 rows), holding toward the wall, then Jump. The escape frame is the first with `_clinging`.

    **Verdicts:** `monitorable` false on the escape frame or the one after; `not is_dead` 1.2 s later; the lurker leaves HUNT within `lurker_lose_track_time + 0.2` s.

  If a room has no stand cell or no cling wall, print an explicit `ok … skipped: no <thing> in <id>` line, so the reason is visible.

**D10: The bot (`smoke_bot`).**
- **Rooms:** each `spine=true` room outside `rooms/dev/`, sorted by path. For each, a fresh harness at `&"up"` if the room has an `up` exit, else `&"spawn"`, so it starts where a diver arrives. All lurkers paused, `reset_phase()` on every hoverer, chain broken.
- **Policy (plain movement: `move_left`, `move_right`, `attack`, and `jump` only to hop a walker; never `dash`):**
  - **Target:** the nearest crawler (hoverer or walker), by distance, whose y is below `max(player.y + 4, last_row_y + 8)`, using the M1 bot's row rule. With no target left, the target is the `down` exit opening's first column; with no `down` exit, stop when standing on the bottom-most ledge.
  - **Steering:** press toward the target x while |dx| > 3 (as M1).
  - **Airborne:** swing (Attack, one frame) when `dy < 28 && |dx| < 12 && velocity.y > 0 && target != swung_for`, as M1.
  - **On the floor:**
    - steer toward the target, which walks off the ledge edge;
    - if a walker is ahead on the same floor within 24 px (any direction), slash it, since Attack on the floor slashes;
    - if blocked (|dx| > 3 but x unchanged for 20 frames), jump once.
  - **Stop when:**
    - the body centre crosses `bounds().end.y` (the `down` exit) or y < 0;
    - death;
    - no y progress (max y) for 5 s;
    - 60 s of game time.
- **Checks per room:**
  - `best >= Spec.BOT_MIN_CHAIN`;
  - `chain.count == 0` on the frame the body crosses an exit (the backstop never fires on the bot's line);
  - reached the `down` exit if the room has one;
  - alive.

  Print one trace line, as M1 does: `bot <id>: frame N, best B, exit/floor/stuck, y=row`. Release every action at the end.
- On `m1_shaft` the bot must clear the bottom floor's walkers to reach the hole at columns 1–2. That is why it slashes ahead.

**D11 (decided by sonlm, 2026-11-18: option A): safe arrival from below.**
- **The problem:** the ledger item (1.7 review) says the arrival cell beside a bottom exit can have an enemy next to it. In `m1_shaft`, the walker at (4, 102) starts walking left into a player arriving at (3, 102), and knocks them into the hole.
- **In play today:** nobody arrives from below. Layer 1 is a one-way descent, and `m1_shaft`'s ceiling gap is out of jump reach. Only tests and 1.11's DevTools do.
- **The options:**
  - **A (chosen by sonlm, 2026-11-18; the layout edit is approved):** the sweep fails any `down` entry stand cell with an enemy spawn (`RoomLegend.SPAWNS` char) within `ARRIVAL_CLEAR_CELLS = 3` cells (Chebyshev), which is about 1.9 s of walker travel at 25 px/s. `m1_shaft` moves the walker from (4, 102) to (8, 102). That is a layout edit sonlm approves; the counts and every pin stay the same.
  - **B:** the same rule, but `m1_shaft` drops that walker (5 → 4 walkers; update `test_room_loader`'s count pin).
  - **C:** defer the arrival check to E4 (owner E4, when Lift Stations and reachable up exits exist), with `m1_shaft` unchanged. Only D4's link check closes here.
- **Do:**
  - `arrival_errors()` with `ARRIVAL_CLEAR_CELLS := 3` (a `room_sweep.gd` const with a comment citing the 1.7 review), run on every swept room's `down` entry;
  - in `rooms/l1/m1_shaft.txt` row 102, `#...c..............c.#` → `#.......c..........c.#` (the walker from column 4 to column 8);
  - update the header comment's note on the layout;
  - `test_room_loader`'s counts (5 walkers) and the `down` entry (3, 102) stay unchanged.

**D12: `test_room_loader.gd`.**
- **Remove:** the FR57 `worst <= LEDGE_GAP_MAX_ROWS` check and the const. The sweep owns it now, for every spine room.
- **Keep:** the ledge-row pin `[6, 24, 41, 57, 72, 85, 103]`; it pins the layout sonlm approved.
- **Add:** the `cling=` validator cases (good, bad format, reversed, outside the grid, repeated). Record the count change.

**D13: Docs.**
- **`docs/rooms.md`:**
  - the `cling` key row and its validator errors;
  - "obj ids unique across files (1.10)";
  - a "Room checks" section listing what `smoke_rooms` and `smoke_bot` guarantee, the `rooms/dev/` rule, and `HAZARDS`;
  - the run commands, with `smoke_shaft` replaced.
- **`docs/development-guide.md`:** the test-type table (`smoke_shaft` → `smoke_rooms` / `smoke_bot` / `smoke_moves`), the run lines, and "Edit the level" (the sweep and bot replace the hand-run checks).
- **`docs/architecture.md`** and **`docs/component-inventory.md`:** the test rows, counts and last run.
- **`docs/source-tree-analysis.md`:** the tests list.
- **`_bmad-output/project-context.md`:**
  - Current State gets a 1.10 sentence;
  - drop "Rules below that name files which don't exist yet (`smoke_rooms.gd`, `smoke_bot.gd`) describe the target; Story 1.10 creates them";
  - Last Updated.
- **`_bmad-output/game-architecture.md`:** only if a statement there becomes false; its testing section already names `smoke_rooms`/`smoke_bot`.
- **GDD:** no change. D11's arrival rule is a level-authoring rule, documented in `docs/rooms.md` ("Room checks"); the Spec values come from GDD lines that already exist.

**D14: Red checks (break, see the named check fail, revert; record each).**
1. **Unique ids:** a duplicate room id and a duplicate obj id across two inline files → `duplicate_id_errors` samples. A scratch copy of `m1_shaft.txt` as `rooms/l1/zz_dup.txt` with the same `obj`/`id` → `smoke_rooms` fails by name (no engine `ERROR:`, because the walk is its own). Remove the copy.
2. **Links:** an exit to a typo'd room, and a `down` exit to a room with no `up` exit → link samples.
3. **Spine gap:** a scratch edit of `m1_shaft` removing the row-57 ledge (gap 41 → 72 = 31 rows) → the spine sweep fails. Revert.
4. **Cling stretch:** a sample stretch 11 wide → width error. A sample 25-row gap covered by a stretch → passes; uncovered → fails.
5. **Hazard pit:** a sample hazard 25 rows below the last ledge → error; with a ledge 10 rows above → quiet.
6. **Fall time:** `MAX_FALL` 150 in `tuning.gd` → the `LEDGE_FALL_MAX / max_fall` check fails. Revert.
7. **Telegraph:** `LURKER_TELEGRAPH_TIME` 0.6 → every lurker's telegraph check fails, and the tuning check fails.
8. **Off-screen:** `Lurker.SCREEN_MARGIN` −200 → the off-screen verdict fails while its premise holds.
9. **Escapes:** in `lurker.gd` HUNT, `monitorable = sensed` → `monitorable = true` → all three escape verdicts fail.
10. **Bot chain:** `Spec.BOT_MIN_CHAIN` 9 → fails (best 8 today).
11. **Backstop:** a scratch `m1_shaft` whose bottom floor (row 103, columns 3–20) is opened into the exit, a legal wide opening → the bot falls through with a live chain → the backstop check fails. Revert.
12. **Arrival (if D11 A/B):** the walker put back at (4, 102) → `arrival_errors` fails.
13. **Moves:** `CLING_GRACE` 3.0 → `smoke_moves`' grace check fails.

### Verified facts

- `RoomLoader.solid_at`, `down_entry_cell`, `parse` and `validate` are static and pure. A test can call them on inline grids with no files (`test_room_loader` already does).
- **The 1.8 frame math holds for the bot:** a press made after an `await` is first seen by the player two ticks later. Read its effect after `await frames(2)`.
- `ChainState.radius_for(3) = 78.1`, `radius_for(4) = 84.0`, `radius_for(20) = 138.4` (reach 221 px). Off-screen placement 135 + 8 + 2 px from the lurker is inside that reach, so only the screen rule can block the notice.
- **`m1_shaft`:**
  - ledge rows 6, 24, 41, 57, 72, 85, 103; the worst gap is 18 rows;
  - `down` entry (3, 102); the walker at (4, 102) walks left first;
  - the bottom-row opening is columns 1–2.
- **Bot today:** best chain 8 (the 1.9 run).

### Project Structure Notes

- **New files:**
  - `game/tests/room_sweep.gd` (helper);
  - `game/tests/test_room_sweep.gd`;
  - `game/tests/smoke_rooms.gd`;
  - `game/tests/smoke_bot.gd`;
  - `game/tests/smoke_moves.gd`;
  - each with its `.gd.uid`, staged.
- **Deleted:** `game/tests/smoke_shaft.gd` (+ `.uid`), with `git rm`.
- **Game code:**
  - `scripts/world/room_legend.gd` (`HAZARDS`);
  - `scripts/world/room_loader.gd` (`cling` key);
  - `rooms/l1/m1_shaft.txt`: the one walker move per D11.
- **Placement:**
  - test data stays in `tests/rooms/`; nothing new goes under `rooms/` (exported);
  - helpers have no `test_`/`smoke_` prefix, so the runner never globs them;
  - `room_sweep.gd` has no `class_name`, like `spec.gd` and `room_harness.gd`.

### Project Context Rules (that apply here)

- **Done:** `cd game && ./run_tests.sh` → `== ALL GREEN`. The runner fails on any `ERROR:` line, so content errors must be **returned and printed as `FAIL`**, never `push_error`ed (pure validators return lists).
- **Guarantees:**
  - design guarantees compare against `tests/spec.gd`, never against the tuning value under test;
  - every new `Spec` const carries a `## GDD` citation;
  - never loosen a threshold to pass; the GDD changes first, with sonlm.
- **Targets:** pick them by position/sort order, never `get_nodes_in_group(...)[i]`. Drive input with intents or `Input.action_press`, counting physics frames.
- **Rooms:** load them **standalone** with `RoomLoader` + a test player (the harness). Test rooms live in `game/tests/rooms/` and are never exported.
- **Level design:** sonlm approves any layout change before commit (Story 1.5). That covers `m1_shaft` under D11.
- **Text and ids:** levels are text, and the legend lives only in `room_legend.gd` and `docs/rooms.md`, so a new legend constant goes to both. Ids are never renamed.
- **No randomness** in level behaviour. The bot is deterministic: positions, `reset_phase()`, sorted targets.
- **Feel and the ledger:**
  - headless tests can't judge feel;
  - every deferred item needs an owner, assigned by whoever defers it (no "(proposed)");
  - output format: `ok …` / `FAIL …` + `PASS` / `FAILED`.
- **Commits:** commit `.gd.uid` files with their sources. Tests are not linted (`test_lint` scans `scripts/` only), but follow the same rules.

### Previous story intelligence (1.9 and its review)

- **Red-check every new check.** In 1.8 two checks passed with their code broken, and in 1.9 the review found checks that couldn't fail on some inputs. Each pure function needs a sample that fires **and** a near-miss that stays quiet.
- **Premise and verdict are separate checks,** with a positive control. 1.9's notice-floor rewrite is the pattern: setup → verdict → control from the same spot.
- **Measure; don't probe at a guess.** The telegraph is timed in frames, and the hunt check doesn't depend on the tuning value.
- **Walks need sentinels** (`test_lint`'s `SENTINELS`), so an empty or wrong root can't pass.
- **Keep Dev Agent Record counts exact,** test by test (the 1.9 review caught "89" for 87).
- **`Spec` lines need `## GDD ` in the comment**, not in a string; `uncited_consts` now reads the comment only.

### Git intelligence

- **Recent commits:**
  - `d390dd0` test: glob runner, Spec, lint (1.9);
  - `04e4b1e` / `fa2a598` docs and record;
  - `9c32602` 1.8 post-review feel check.
- **Commit style:** `test:` for test-only work, `docs:` for docs and records, `feat:` for game code. 1.10 is mainly `test:`; if D11 edits `m1_shaft`, use a separate `feat:` (or `content:`) commit, after sonlm approves.

### Cross-story context (Epic 1)

- **1.11** DevTools `--room=<id>` (any entry). 1.12 adds `rooms/dev/perf_worst.txt`, which the walk must validate but not sweep.
- **1.19** spikes (`HAZARDS`), HP and contact damage. When crawler contact costs 1 HP, D9's contact checks still hold; the bot is unaffected because lurkers are paused and it slashes walkers.
- **1.20** `Sensing`: swap `lurker.senses()` for the new API, with the same checks.
- **1.22** Ember Cache (an 80 px light): another light source the sweeps may cover.
- **1.24** anchors (`obj=` with `A`): cross-file obj-id uniqueness matters from then on.
- **E4** real rooms, gates (the bot's required chain), reachable up exits and Lift Stations.

### References

- `_bmad-output/planning-artifacts/epics.md`: Story 1.10 (≈ line 1584), AR50 (≈ line 280), FR57 (≈ line 135), NFR10 (≈ line 181), Epic 1 preamble.
- `_bmad-output/game-architecture.md` → Design Guarantees as Tests (≈ lines 1130–1165; the `smoke_rooms` excerpt), Room transitions / exit backstop (≈ 329, 1040–1070).
- GDD `gdds/gdd-pixel_art_game-2026-11-10/gdd.md` → Level Types (≈ 521), Level Progression "Level validation" (≈ 537), Sequence Breaking "Every pit of hazards…" (≈ 429).
- `_bmad-output/implementation-artifacts/deferred-work.md`: the 1.5-review "exit targets" item (≈ line 66) and the 1.7-review "arriving from below next to an enemy" item (≈ line 83), both `Owner: Story 1.10`.
- Code:
  - `game/tests/smoke_shaft.gd`, `room_harness.gd`, `test_room_loader.gd`, `spec.gd`, `test_lint.gd` (`uncited_consts`);
  - `game/scripts/world/room_loader.gd`, `room_legend.gd`, `room.gd`, `world.gd` (exit polling, backstop);
  - `game/scripts/actors/lurker.gd`, `crawler.gd`, `player.gd` (`_clinging`, swing);
  - `game/rooms/l1/m1_shaft.txt`;
  - `docs/rooms.md`.
- `_bmad-output/implementation-artifacts/m1-playtest-findings.md`: Pillar 2 escapes ("a Snuff, landing or cling in time always saves you").

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), gds-dev-story, 2026-11-18 → 2026-11-19.

### Debug Log References

- **Baseline** `9a55dc4`: `./run_tests.sh` → `== ALL GREEN (12 tests)`, 719 `ok`, 1 m 16 s.
- **Final:** `== ALL GREEN (15 tests)`, 846 `ok`, 1 m 39 s, no `SCRIPT ERROR` / `ERROR:` lines; the same 9 `push_warning` lines as the baseline (`test_state`'s deliberate warnings).
- **`ok` counts, test by test (before → after):** `smoke_shaft` 36 → deleted; `test_room_loader` 64 → 72 (+9 `cling=` cases, −1 FR57 gap check); new `test_room_sweep` 58, `smoke_rooms` 76, `smoke_bot` 6, `smoke_moves` 15. Unchanged: `test_clock` 15, `test_deferred_owners` 25, `test_lint` 162, `test_log` 7, `test_state` 165, `test_tuning` 87, `smoke_player_input` 59, `smoke_room_swap` 39, `smoke_world` 60. `smoke_rooms` 76 = 10 file/sweep checks + 3 tuning + 1 harness stub + 4 lurkers × 12 + 2 contact + 3 escapes × 4.
- **D1, where each of `smoke_shaft`'s 36 checks went:** stub (1) → `smoke_rooms`; pogo (3), landing (2), jump (2), cling (6) → `smoke_moves`; bot (2) → `smoke_bot` (now the full descent); telegraph/hunt/lose (13) → `smoke_rooms` per lurker (telegraph seen, tuning ≥ Spec, measured frames, HUNT, **closes in** (added here, it had no other home), base ≤ 40, base never noticed, notice-floor setup/verdict/control, `Lurker.NOTICE_MIN_RADIUS` ≥ Spec, off-screen; "Snuff → loses track within 1 s" was first mapped to the Snuff escape's "leaves HUNT within lose-track + 0.2 s", which is 0.8 s only at today's tuning, so the code review restored M1's fixed 1 s next to it); Snuff escape (2) and lurker kills (2) → `smoke_rooms` per room; Snuff needs a hold (3): tap keeps the chain and hold Snuffs are covered by `smoke_player_input`'s `test_light_windows`, but **"releasing Light ends the Snuff" is not checked there**, so it moved to `smoke_moves` (with its setup check) instead of being dropped.
- **Task 1:** the 9 `cling=` validator cases failed first on "unknown key 'cling'", then passed.
- **Task 2:** `test_room_sweep` red first (the helper didn't exist), then 55/55; 8 mutations of `room_sweep.gd` each caught by a named sample (gap off by one, ledge ignores hazard cover, hazard window off by one, arrival rows narrowed, narrow max off by one, link entry side swapped, exit fall ignores the target, obj dedupe removed). A 9th rule found on review: a spine room with **no** safe row passed vacuously → sentinel added, red first (58 checks).
- **Task 3:** first run of `smoke_rooms` had two FAILs: the arrival (expected, D14 #12) and the contact control (a HUNTING lurker didn't kill). Cause: the first lurker sits in the left wall, so placing the player on it embedded the body in a tile; the push-out registered a floor contact and broke the chain, so the lurker lost the scent. (M1's check passed only because earlier tests had dragged that lurker into open air.) Fix: contact in mid-air in the first open 3 × 4 block, the lurker moved onto the player.
- **Task 4:** first bot run: best 7, stuck at row 40. Cause (trace): after pogoing the row-40 right walker it landed on the row-41 right ledge, directly above its next target (the column-17 hoverer under that ledge), and stood still with |dx| ≤ 3. Fix: on the floor it aims at the ledge's drop-off column nearest the target (`_drop_x()`). Then: frame 1628 (≈ 27 s), best 8, exit down with chain 0, alive; trace showed the floor slash firing on the row-84 walker and the bottom-floor walker; no hop needed.
- **D14 red checks** (break → the named check fails → restore; restores verified by `diff` / `md5sum`, scratch files removed):
  1. Unique ids: samples in `test_room_sweep` (room id and obj id across files). Scratch `rooms/l9/m1_shaft.txt` (+ `obj=dup_obj@3,3`) and `rooms/l9/zz_a.txt` (same obj) → `FAIL room id 'm1_shaft' is in both res://rooms/l1/m1_shaft.txt and res://rooms/l9/m1_shaft.txt`, `FAIL obj id 'dup_obj' is in both …`; no `ERROR:` line (rooms are built by path, never through the index).
  2. Links: samples (a typo'd target; a down exit into a room with no up exit; an up exit into a room with no down exit).
  3. Spine gap: row-57 ledge removed → `FAIL m1_shaft: the fall from row 41 to row 72 is 31 rows, over 19`.
  4. Cling stretch: samples (11 wide → error; a 25-row gap covered by a stretch passes, uncovered fails; a partly covered gap fails from the stretch's last row).
  5. Hazard pit: samples (25 rows below the last ledge → error; a ledge 10 rows above → quiet; 19 rows → quiet; 20 → error).
  6. `MAX_FALL` 150 → `FAIL Spec.LEDGE_FALL_MAX 315 px at the tuned max fall 150 px/s takes 2.10 s …`.
  7. `LURKER_TELEGRAPH_TIME` 0.6 → the tuning check and all 4 lurkers' measured telegraphs fail (36 frames < 45).
  8. `Lurker.SCREEN_MARGIN` −200 → all 4 off-screen verdicts fail while their premises pass.
  9. HUNT `monitorable = true` → the Snuff, landing and cling "harmless on the escape frame or the one after" verdicts all fail.
  10. `Spec.BOT_MIN_CHAIN` 9 → `FAIL m1_shaft: the bot chains 9+ … (best 8)`.
  11. Scratch `m1_shaft` with rows 103–104 opened at columns 1–18 (a legal wide opening, floor kept at 19–20) → `FAIL … the chain is 0 when the bot crosses an exit … (chain 1)`.
  12. Arrival: before Task 6 the walker at (4, 102) gave `FAIL m1_shaft: arriving from below at (3, 102), a 'c' spawns at (4, 102), within 3 cells`.
  13. `CLING_GRACE` 3.0 → `FAIL grace runs out -> the chain breaks (banks)`.
  14. (extra) `Lurker._ready()` `monitorable = true` → `FAIL m1_shaft: touching an IDLE lurker does not kill` (plus 24 knock-on failures).

- **Code review 2026-11-19** (three layers; 2 decisions, 18 patches, 12 dismissed). Before the fixes, two scratch rooms reproduced the bugs: `rooms/l9/zz_floor.txt` (`m1_shaft` with no down exit) → `FAIL … with no down exit, the bot reaches the bottom ledge, row 103 (ended: stuck)` (+12 feet row), and `rooms/a0/zz_noentry.txt` (spine, no `P`, no exits) → `SCRIPT ERROR: Assertion failed: Room zz_noentry has no entry 'spawn'`. After them: `zz_floor` ends `floor`, `zz_noentry` is `FAIL zz_noentry: the bot has nowhere to start`, and `smoke_rooms` runs its stub check on `m1_shaft` with no engine error. Scratch rooms removed. Counts: `test_room_sweep` 58 → 74, `smoke_rooms` 76 → 90, `smoke_moves` 15 → 17; suite 846 → 878 `ok`, ALL GREEN (15 tests), the same 9 warnings.
- **Review red checks** (break → named FAIL → restore; `md5sum` verified):
  - R1 HUNT `monitorable = true` → the four "harmless" verdicts and **the point-blank Snuff's "still alive 1.2 s later"** fail (the 48 px cases can't fail "alive": the braking lurker stops short, the review's point).
  - R2 `LURKER_LOSE_TRACK_TIME` 3.0 → M1's "loses track within 1.0 s" fails on all four escapes while D9's tuning-relative bound passes; R2b the lurker never gives up (`× 10`) → both bounds fail.
  - R3 `Lurker._on_screen()` always false → the four off-screen **controls** fail while the verdicts pass.
  - R4 TELEGRAPH monitorable → `FAIL … touching a TELEGRAPHING lurker does not kill`.
  - R5 `record()`'s exit regex without `up` → `FAIL res://rooms/l1/m1_shaft.txt: the sweeps read the same exits and obj ids the loader builds …`.
  - R6 the cling timeout calls `lose()` → `FAIL grace runs out -> the chain breaks and banks its 21 held embers … (banked 0)`.
  - R7–R14 (`test_room_sweep`): notch clause removed, hazard-tile clause removed, top-entry and down-hole falls unmeasured, links into `rooms/dev/` allowed, cling wall ignoring crawlers, cling wall left-only, `Spec.NARROW_MAX` 11 → each fails its named sample.
  - G1+G2 an invalid `rooms/l9/zz_bad.txt` (unknown char) with `m1_shaft` moved to `rooms/l2/` → `smoke_rooms`: `FAIL sentinel: …`, `FAIL res://rooms/l9/zz_bad.txt:20:3 unknown char 'x'` and nothing else for it (never built, no `ERROR:`); `smoke_bot`: `FAIL … zz_bad.txt: can't play it …`, `FAIL sentinel: …`.
  - G3 the bot dies at frame 300 → `FAIL m1_shaft: the bot is alive at the end` (and the chain and exit checks).

### Completion Notes List

- Story context created by gds-create-story on 2026-11-18. D11 decided by sonlm: option A (arrival rule, 3 cells; `m1_shaft` walker (4, 102) → (8, 102), layout edit approved).
- **AC1:** `smoke_rooms` walks `res://rooms` itself (`RoomSweep.room_files()`, sorted), with sentinels (≥ 1 file, `m1_shaft` present); each validator error is a `FAIL`, a bad file is never built, `rooms/dev/` is validated only.
- **AC2:** `duplicate_id_errors()` and `link_errors()` over every file; `arrival_errors()` on every swept room. Both 1.10-owned ledger items are closed.
- **AC3:** `Spec.LEDGE_FALL_TIME` 1.5 and `LEDGE_FALL_MAX` 315 (cited); spine gaps, the fall through a down exit, cling widths and hazard pits over `RoomLegend.HAZARDS` (empty, proven on samples); the tuned max-fall check. `m1_shaft`'s worst gap is 18 rows.
- **AC4:** per lurker (all 4, sorted by row then column): base light, notice floor with control, off-screen with premise, measured telegraph (54 frames), hunt and closes in; per room: contact and the three escapes, each on a fresh harness.
- **AC5:** `smoke_bot` plays `m1_shaft` from its up entry to its down exit: best 8, chain 0 at the exit, alive.
- **AC6:** `smoke_shaft.gd` and its `.uid` are `git rm`ed; every check is accounted for in the Debug Log; `test_room_loader` lost the FR57 check and kept the ledge-row pin.
- **AC7:** 15 tests green; the red checks above; docs (`rooms.md`, development guide, architecture, component inventory, source tree, `game/README.md`), `project-context.md`, the `game-architecture.md` excerpt and the ledger updated. Game-code edits: `RoomLegend.HAZARDS`, the `cling=` key (`REPEAT_KEYS`), and the `m1_shaft` walker move. No gameplay script changes behaviour.
- **Final `room_sweep.gd` API (D2):** `room_files(root)`, `is_dev(path, root)`, `record(path, parsed)` → `{id, path, grid, spine, exits, objs, clings}`, `cling_stretches(header)`, `ledge_rows(grid, hazards)`, `safe_rows(grid, stretches, hazards)`, `spine_gap_errors(id, grid, stretches, hazards, max_rows)`, `exit_fall_errors(rooms_by_id, hazards, max_rows)`, `stretch_width_errors(id, grid, stretches)`, `hazard_pit_errors(id, grid, stretches, hazards, max_rows)`, `duplicate_id_errors(files)`, `link_errors(rooms_by_id)`, `arrival_errors(id, grid, exits, clear_cells)`; consts `ARRIVAL_CLEAR_CELLS` 3, `NARROW_MIN` 6, `NARROW_MAX` 10.
- **Deviations from the Dev Notes, kept and recorded:**
  - **D9 off-screen:** the lurker is placed just outside `play_rect()` itself, not `play_rect().grow(-SCREEN_MARGIN)`. AC4 says "outside the play rect", and with the grown rect D14 #8 (margin −200) could never place it within reach and would skip instead of failing.
  - **D9 contact:** in mid-air in the open with the lurker moved onto the player (see Debug Log, Task 3).
  - **D10 floor policy:** the bot walks to the ledge's drop-off column nearest its target (`_drop_x()`), not straight at the target (see Debug Log, Task 4).
  - **D5:** a floor cell whose open top is a hazard is not a ledge either ("a hazard never counts as a ledge"); `spine_gap_errors` fails a spine room with no safe row; the exit fall uses the last **safe** row (ledge or cling), consistent with D5's safe rows.
  - **D11:** "enemy" = any `RoomLegend.SPAWNS` char that isn't `persistent`, so 1.24's anchor won't trip the rule.
  - **D1:** "hunting lurker closes in" kept per lurker and "releasing Light ends the Snuff" kept in `smoke_moves` (neither had another home).
  - **New harness entry point:** `RoomHarness.build_from_path()`, so a duplicate room id is a named `FAIL`, never the index's `push_error`.
  - `NARROW_MIN` / `NARROW_MAX` / `ARRIVAL_CLEAR_CELLS` live in `room_sweep.gd` (the story named only two new Spec consts); the narrow width cites the GDD there.
  - `smoke_moves` pauses the lurkers (M1 left them active), so a move check never depends on a lurker.
  - Task 6 ran before Task 4: its red check (#12) was captured first, and it was the only thing between `smoke_rooms` and green.
- **Deferred, with owner:** one item (Story 4.9): `smoke_bot` (≈ 28 s per spine room) and `smoke_rooms` (≈ 10 s per room) run every room in one runner process under the 120 s watchdog, and both sentinels name `rooms/l1/m1_shaft.txt`, which 4.9 moves to `rooms/dev/`.
- **Code review 2026-11-19:** sonlm kept the added project-context rule and chose to keep D9's lose-track bound with M1's fixed 1 s beside it. All 18 patches applied: the point-blank (18 px) Snuff escape; M1's 1 s lose-track bound; the notice-floor loop bounded by its own counter; an on-screen control for the off-screen verdict, probing above, below and beside; TELEGRAPH contact harmless and HUNT lethal at contact; the bot's feet row (+13, one helper) and a named FAIL for a spine room with no `up` exit or `P`; the stub check on the first room with an entry; `record()` cross-checked against the built `Room`; FR57 from the top entry and to the down hole; no exit from a layer room into `rooms/dev/`; a ledge needs two open cells above; the cling escape at either wall face, any thickness, crawler-free (`RoomSweep.cling_wall()`, unit-tested); `Spec.NARROW_MIN` / `NARROW_MAX`; the stub's 360 px written out; `smoke_moves` by path, with a landing setup check, a real bank check and a Snuff-release control; a sample for the hazard-tile ledge clause; docs. Nothing deferred by the review.
- **Laptop feel check passed (sonlm, 2026-11-19):** D11 moved the bottom-left walker from column 4 to column 8. Played down to the bottom of the shaft, landed and walked to the hole: the walker felt fine, and the hole still loops to the top (R16).

### File List

- game/tests/room_sweep.gd (new)
- game/tests/room_sweep.gd.uid (new)
- game/tests/test_room_sweep.gd (new)
- game/tests/test_room_sweep.gd.uid (new)
- game/tests/smoke_rooms.gd (new)
- game/tests/smoke_rooms.gd.uid (new)
- game/tests/smoke_bot.gd (new)
- game/tests/smoke_bot.gd.uid (new)
- game/tests/smoke_moves.gd (new)
- game/tests/smoke_moves.gd.uid (new)
- game/tests/smoke_shaft.gd (deleted)
- game/tests/smoke_shaft.gd.uid (deleted)
- game/tests/room_harness.gd (modified: `build_from_path()`)
- game/tests/spec.gd (modified: `LEDGE_FALL_TIME`, `LEDGE_FALL_MAX`; review: `NARROW_MIN`, `NARROW_MAX`)
- game/tests/test_room_loader.gd (modified: `cling=` cases; FR57 gap check removed)
- game/scripts/world/room_legend.gd (modified: `HAZARDS`; review: its comment says 1.19 must also make the char known)
- game/scripts/world/room_loader.gd (modified: `cling=` key, `REPEAT_KEYS`)
- game/rooms/l1/m1_shaft.txt (modified: walker (4, 102) → (8, 102), header note)
- game/README.md (modified: test list)
- docs/rooms.md (modified: `cling` key, obj ids across files, `HAZARDS`, validator list, Room checks)
- docs/development-guide.md (modified)
- docs/architecture.md (modified)
- docs/component-inventory.md (modified)
- docs/source-tree-analysis.md (modified)
- _bmad-output/project-context.md (modified: Current State)
- _bmad-output/game-architecture.md (modified: the `smoke_rooms` excerpt)
- _bmad-output/implementation-artifacts/deferred-work.md (modified: two 1.10 items closed, one item owned by Story 4.9)
- _bmad-output/implementation-artifacts/1-10-room-smoke-tests-and-the-reachability-bot.md (this file)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified: 1-10 → review → done)

### Change Log

- 2026-11-19: Story 1.10 implemented. `smoke_rooms` checks every room file (validation, unique ids, exit links, spine falls, cling stretches, hazard pits, a safe arrival from below, the lurker guarantees); `smoke_bot` plays every spine room top to bottom; pure sweeps in `room_sweep.gd` with `test_room_sweep`; `smoke_moves` keeps the M1 move checks; `smoke_shaft` deleted. `Spec.LEDGE_FALL_TIME` / `LEDGE_FALL_MAX`, `RoomLegend.HAZARDS`, the `cling=` key; `m1_shaft`'s bottom-left walker moved to column 8 (D11). Status → review.
- 2026-11-19: Code review (Blind Hunter, Edge Case Hunter, Acceptance Auditor): 2 decisions (keep D9's lose-track bound plus M1's fixed 1 s; keep the project-context rule), 18 patches applied and red-checked, 12 dismissed, nothing deferred. ALL GREEN (15 tests, 878 ok). Status → done.
- 2026-11-19: Laptop feel check passed (sonlm): the moved bottom-floor walker feels fine, and the R16 loop still works.
