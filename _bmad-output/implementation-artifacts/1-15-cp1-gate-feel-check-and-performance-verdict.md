---
baseline_commit: ccc8ac4
---

# Story 1.15: CP1 gate: feel check and performance verdict

Status: ready-for-dev

**Type:** playtest · **Epic:** 1, Kit v2: Fair Deaths, Full Move Set · **Checkpoint:** closes CP1 Foundations (1.1–1.15) · **Branch:** `feat/m2-e1`

## Story

As the designer,
I want to play the migrated shaft on my laptop and in the browser and record the verdicts,
so that the kit is built on foundations I trust.

## Acceptance Criteria

1. **Automated gate (agent).** On the CP1 build:
   - `test_chain_state` passes unchanged from M1, except its preload path and its move onto the scene runner (Stories 1.1, 1.2), with no assertion changes;
   - `test_lint` is green;
   - the bot reaches a chain of 5 or more in the 22-tile shaft (`smoke_bot`);
   - the web debug build boots in the Playwright check (`tools/export.sh`: `BUILD OK`, smoke all passed).

   The evidence goes in the playtest record. [epics 1.15 AC1; CP1 gate]
2. **Feel check (sonlm, human gate).** sonlm plays the desktop build at ×3, at 60 Hz and also on a high-refresh display if one is available, with physics interpolation on and off (D2). He decides whether **physics interpolation is kept or turned off**. The decision and its reason are recorded in `project-context.md` and the architecture (Frame Pacing, decision row 8; AR6). [epics 1.15 AC2]
3. **Performance runs (sonlm, human gate).** sonlm runs the `docs/perf.md` procedure, with engine glow off and on, in each of these:
   - the laptop at ×3;
   - desktop Chrome and Firefox at the ×2 embed;
   - an HD 620-class machine if one is available. If not, the gap is recorded.

   For each run, min/avg FPS and the worst frame time go in `docs/perf.md` → Results, copied from the run's summary line. [epics 1.15 AC3; NFR1, NFR5]
4. **Lighting verdicts (sonlm).** These go into the architecture (Lighting, decision row 14) and the GDD Open Questions rows (bloom, flare cap) (AR5):
   - the engine-glow go/no-go;
   - the light budget: confirmed at 6, or tightened and re-run;
   - a flare-cap recommendation for Story 1.23.
5. **Deferred items owned by 1.15** (`deferred-work.md`). Each is closed with its outcome:
   - **air dash length:** keep the felt ≈ 39 px and change the GDD, or fix the off-by-one to FR2's 31 px; then tighten the pin (D4);
   - **engine glow:** go → a follow-up story is created; no-go → sprite bloom (AC4);
   - **X11 window decorations at the first fit:** checked on a Linux desktop, or given a new owner (D5).
6. **Close-out.**
   - The playtest record `implementation-artifacts/playtests/1-15-cp1-gate-feel-check-and-performance-verdict.md` holds the questions, who played, the build version, the answers (yes / no / mixed), the evidence and the follow-up stories (epics "Playtest records").
   - A devlog or private build is posted (sonlm, human gate).
   - A "no" on the feel check becomes fix stories before CP2 (Story 1.16), added through `gds-correct-course` (D7).
   - `cd game && ./run_tests.sh` ends `== ALL GREEN` after any change this story makes.

## Tasks / Subtasks

Tasks marked **(sonlm)** are human gates: the dev agent HALTs, asks and waits. It never fills them in, assumes them or marks them done itself (epics "Human gates").

- [ ] **Task 1: Automated gate (AC: 1)** (agent)
  - [ ] 1.1 Start from a clean tree on `feat/m2-e1`. Run `cd game && ./run_tests.sh` and record the test count, the `ok` total and `== ALL GREEN`.
  - [ ] 1.2 Prove that `test_chain_state` is unchanged from M1:
    ```bash
    git diff feat/m1-prototype:game/tests/run_tests.gd HEAD:game/tests/test_chain_state.gd
    ```
    The only allowed hunks are:
    - `extends SceneTree` → `Node`;
    - the `## Run:` line;
    - the preload path `scripts/` → `scripts/rules/`;
    - `_init` → `run`;
    - the two `quit()` lines removed.

    Paste the diff stat and that list into the record. If any `check(` line differs, stop: the gate fails.
  - [ ] 1.3 From the same run, record `test_lint`'s `PASS` and `smoke_bot`'s best chain in `m1_shaft`. It was 8 at 1.10; 5 or more passes.
  - [ ] 1.4 Run `tools/export.sh` on the clean tree. Record the version (`<yyyymmdd>-<sha7>`, never `-dirty`), `BUILD OK`, the web gzip size and the smoke result (`7 passed`).
- [ ] **Task 2: Play kit and record (AC: 6)** (agent)
  - [ ] 2.1 Create `implementation-artifacts/playtests/` and the record from **Record template** below. Fill in:
    - the build version;
    - the Task 1 evidence;
    - the commands, with the real version in each path (**Commands for sonlm** below).
  - [ ] 2.2 Commit the record. Builds are gitignored, so they stay on the server.
  - [ ] 2.3 Report to sonlm. Give him the commands, the play checklist and the decisions to make (Task 5), then **HALT**.
- [ ] **Task 3: Feel check (AC: 2, 5)** (sonlm)
  - [ ] 3.1 Play the release Windows exe at ×3, at 60 Hz: the shaft top to bottom, a few deaths and respawns, and room exits.
  - [ ] 3.2 Run the same build with `override.cfg` (interpolation off, D2) and compare. If a high-refresh display is available, play both again on it.
  - [ ] 3.3 Air dash: does it feel right as it is (≈ 39 px)? (D4)
  - [ ] 3.4 Play the shaft in the browser at the ×2 embed (`embed.html?build=web`): one descent; note anything that feels different from desktop.
  - [ ] 3.5 Linux desktop with a window manager, if one is available: launch the Linux build and paste the `[ui] display: window …` line, if it prints (D5).
- [ ] **Task 4: Performance runs (AC: 3, 4)** (sonlm)
  - [ ] 4.1 Laptop desktop, glow off, then glow on: 60 s runs from the clone through the Godot console exe (D1). Paste both summary lines.
  - [ ] 4.2 Chrome, glow off and on, at `web_debug` through the tunnel. Paste the console summary lines.
  - [ ] 4.3 Firefox: the same two runs.
  - [ ] 4.4 HD 620-class machine: the same runs, or "not available".
  - [ ] 4.5 Glow look check at brightness 0–3 (`docs/perf.md` → The look check): is the darkness readable, the halo right, and does a sprite glow read the same as a lit glow?
- [ ] **Task 5: Decisions (AC: 2, 4, 5, 6)** (sonlm)
  - [ ] 5.1 Physics interpolation: keep or turn off, with the reason.
  - [ ] 5.2 Engine glow: go or no-go.
  - [ ] 5.3 Light budget: confirm 6, or tighten (then re-run Task 4 at the new budget).
  - [ ] 5.4 Flare cap recommendation (a number, or "none needed", with the reason).
  - [ ] 5.5 Air dash: keep ≈ 39 px, or fix to 31 px.
  - [ ] 5.6 Feel check verdict: yes, no or mixed. Any "no" names what to fix.
  - [ ] 5.7 Devlog or private build: where it was posted (link or note).
- [ ] **Task 6: Record and apply (AC: 2–6)** (agent, after Task 5)
  - [ ] 6.1 Fill in the playtest record: the answers, the evidence and the follow-ups. Copy sonlm's summary lines into `docs/perf.md` → Results, one row per run, numbers verbatim (D3).
  - [ ] 6.2 Interpolation:
    - **Kept:** `project-context.md` (Technology Stack "Display" line: "kept since 1.15", the reason, and the Physics interpolation rule); architecture Frame Pacing and decision row 8 (decided, dated); AR6 in `epics.md`.
    - **Turned off:** HALT. Show sonlm the change before making it: `project.godot`, `smoke_room_swap.gd:245`, and `CameraRig`, which runs on the physics tick only because interpolation forces it (D2). If the rig needs more than a flag, it goes in a fix story (D7).
  - [ ] 6.3 Light budget:
    - **Confirmed:** update the comments on `BudgetLight.MAX_ON_SCREEN` and `Spec.LIGHTS_ON_SCREEN_MAX` (drop "until 1.15").
    - **Tightened:** change the GDD first, then `Spec.LIGHTS_ON_SCREEN_MAX`, `BudgetLight.MAX_ON_SCREEN`, architecture Lighting and the `docs/perf.md` numbers; `test_light_budget` must stay green; sonlm re-runs Task 4.
  - [ ] 6.4 Glow:
    - **Go:** draft the follow-up story through `gds-correct-course` with sonlm. It moves glow into game code and re-checks the brightness levels and contrast floors.
    - **No-go:** architecture Lighting reads "engine glow: no-go (CP1, <date>); bloom = unshaded additive sprites"; `--glow` stays a DevTools-only option.

    Either way, update the GDD Open Questions bloom row (decided, dated).
  - [ ] 6.5 Flare cap: the GDD Open Questions flare row and architecture Lighting line 452 get the recommendation. Story 1.23 makes it a `Tuning` value (epics 1.23).
  - [ ] 6.6 Air dash (D4):
    - **Keep:** the GDD Movement row (line 125) becomes "260 px/s for 0.15 s (≈ 39 px; 8–9 ticks)"; FR2 in `epics.md` changes to match; the `Tuning.DASH_TIME` comment is updated. Then either set `DASH_TIME` to the true length and make the timer honest (count down before the check), with `smoke_player_input` pinning the exact ticks and distance, or keep the code and pin it as it is. Pick the change that leaves the dash identical in play; prove it with the before/after tick count.
    - **Fix to 31 px:** count down before the check in `player.gd` `_physics_process` (lines 160–162), and pin `smoke_player_input` to 7–8 ticks and ≈ 31 px. Re-run `smoke_bot` (the bot uses no dash, but check its best chain). sonlm does a short re-feel (a human gate).
  - [ ] 6.7 Ledger: close the three 1.15 items with their outcomes. For X11, if no Linux desktop was available, change its owner to **Story 7.14** (D5).
  - [ ] 6.8 A feel "no", or a fix story from 6.2 or 6.4: run `gds-correct-course` to add each before 1.16 (D7). HALT for sonlm's approval.
  - [ ] 6.9 `cd game && ./run_tests.sh` → `== ALL GREEN`. Then commit: code, docs, the record, `sprint-status.yaml` (`done`), and this story (Change Log, status `done`).

## Dev Notes

### What this story is (and isn't)

A **playtest** story (epics "Story types"): sonlm plays and decides, and the agent prepares and records. The only code this story may change is what a decision calls for: the dash timer, the budget constant, or the interpolation flag. Every other finding becomes a follow-up story.

**Not in this story:**
- **The 10-minute Layer 1 run** that NFR1 measures. That is Story 7.13, the performance pass. CP1 measures only the worst-case perf scene.
- **Moving glow into game code** (a follow-up story if it's a go).
- **The flare cap as code:** Story 1.23.
- **The shader warm-up for the first-second hitch:** Story 1.16 (`docs/perf.md` → Known first-second hitch).
- **A Windows debug export** (D1).
- **Booting the final Windows build:** Story 7.15. The 1.14 laptop look already ran a Windows exe (`builds/20261120-317fd60`), but that ledger item is about the final build.

### Current state (read before changing)

- **Physics interpolation is on** (`game/project.godot:85` `common/physics_interpolation=true`), pinned by `game/tests/smoke_room_swap.gd:245`.
  - `CameraRig` (`scripts/world/camera_rig.gd`) sets `process_callback` to PHYSICS in `_init`, smooths itself (`SMOOTH_SPEED` 8) and clamps on the physics tick. Godot 4.7 forces a `Camera2D` onto the physics tick under interpolation, and has no 2D `get_global_transform_interpolated()` (project-context, Engine rules).
  - Teleports call `reset_physics_interpolation()` in `world.gd`, `camera_rig.gd` and `dev/perf_run.gd`.
- **The light budget:** `BudgetLight.MAX_ON_SCREEN := 6` (`scripts/core/budget_light.gd:14`) ≤ `Spec.LIGHTS_ON_SCREEN_MAX := 6` (`tests/spec.gd:16`). Ranks are ALWAYS, CACHE and GLOW; World's `LightBudget` runs at priority 50. Procedure and decision guide: `docs/perf.md`.
- **The perf kit (1.12):**
  - `--room=perf_worst --perf[=<s>]` and `--glow=on|off`; on web, `?room=perf_worst&perf&glow=on`.
  - DevTools exists **only in debug builds**: the release Windows exe and the `web` build can't run `--perf`; `web_debug` can.
  - Overlay 4 (backquote) shows the frozen summary.
  - The summary line format is in `docs/perf.md` → What to record.
- **The air dash:** `player.gd:160-162` checks `_dash_left > 0.0` before subtracting `delta`, so `DASH_TIME` 0.12 s (`rules/tuning.gd:34`) runs 8–9 ticks, ≈ 39 px. `smoke_player_input.gd:196-224` pins it as it is (`straight` 7–8 ticks, `dashing` 8–9).
- **`test_chain_state`:** `git diff feat/m1-prototype:game/tests/run_tests.gd HEAD:game/tests/test_chain_state.gd` was checked while writing this story (2026-11-21). Only the harness lines differ (Task 1.2 list); no `check(` line changed. Its history: `aaf5f22` (1.1 rename and preload) and `afae546` (1.2 runner).
- **The latest build** is `builds/20261120-9f9d6e1` (1.14 plus the F11/zoom fix). The re-check passed on 2026-11-21. Task 1.4 makes a fresh build anyway, so the record names the exact build played.
- **The laptop** runs Windows (PowerShell) and logs in with `ssh -i .\sonlm2026-private.pem sonlm@123.31.11.131`.
  - It can clone the repo over SSH (`git clone -b feat/m2-e1 sonlm@123.31.11.131:/home/sonlm/project/pixel_art_game`, with `GIT_SSH_COMMAND`/`core.sshCommand` set to the key). That is how 1.12's `godot --path game -- --room=perf_worst --perf` run was done.
  - **There is no git remote**, so nothing is pushed.

### Decisions

These are the story author's calls. sonlm can veto any of them before dev.

- **D1: desktop perf runs come from the laptop clone, run by Godot 4.7.2's console exe, not from the release exe.**
  - The release exe has no DevTools, so it has no `--perf`. The run looks like:
    ```powershell
    cd $HOME\pixel_art_game
    git pull
    & "<path>\Godot_v4.7.2-stable_win64_console.exe" --path game -- --room=perf_worst --perf
    ```
    Use the `_console` exe so the summary prints in the terminal. Overlay 4 shows it too.
  - Running from the command line opens a real ×3 window; the editor's embedded Game view would skip `Display`'s window fit (1.14).
  - This is a debug run, so it costs a little more than release. That's fine for a worst-case verdict: a pass in debug is a pass. Note "debug (editor exe)" in the Notes column.
  - Not chosen: adding a Windows debug export preset. It's a new preset, plus `test_export_presets` and the PCK checks, for one measurement.
- **D2: compare interpolation on and off with `override.cfg`, on the same release build, with no rebuild.**
  - Godot reads `override.cfg` from the folder that holds the exe. This was probed on 4.7.2 (2026-11-21):
    - an `override.cfg` beside the exported Linux binary changed its `application/run/main_scene`;
    - `[physics] common/physics_interpolation=false` in `override.cfg` gave `ProjectSettings` false and `SceneTree.physics_interpolation` false.
  - The file, saved as `override.cfg` beside `unbroken_chain.exe`:
    ```ini
    [physics]
    common/physics_interpolation=false
    ```
    Delete or rename it to go back to on.
  - The "off" run uses today's `CameraRig`, which stays on the physics tick. That is what turning it off means with no other change. At 120 Hz or more, expect the camera to move only every other frame. If sonlm prefers off anyway, the rig rework goes to a fix story (6.2, D7).
  - Web has no `override.cfg`, so the A/B is desktop only.
- **D3: the agent never writes a number or a verdict itself** (1.12 rule; epics "Human gates"). sonlm pastes each summary line, and the agent copies it into `docs/perf.md`. If a line is missing, ask for it; never estimate.
- **D4: the dash question is about what sonlm felt**, not about the GDD text. Every feel check since 1.8 used the ≈ 39 px dash.
  - **Keep:** the GDD follows the game, and the code's numbers get honest.
  - **Fix:** the dash gets shorter (31 px) and needs a short re-feel.

  There is no default; sonlm decides in 5.5.
- **D5: X11 decorations.**
  - sonlm's laptop is Windows. The item needs a Linux desktop with a real window manager, which Xvfb doesn't have.
  - If one is available, run the Linux build there and read the `[ui] display: window` line. It prints only when the window was shrunk.
  - Otherwise, change the ledger owner to **Story 7.14**, the Steam Deck and accessibility test passes. Steam Deck desktop mode is KDE on X11/Wayland: a real window manager on the Linux target.
- **D6: the playtest record** lives at `implementation-artifacts/playtests/<story-key>.md` with the epics' fields. This is the first one, so it sets the format for 1.30, 2.x and the rest.
- **D7: new stories come from `gds-correct-course`.** A failed feel check, an interpolation-off rig rework or a glow go each needs one.
  - Sprint keys must match `number-number-name`, so a "1.15a" can't be added by hand.
  - Correct-course places the story before 1.16 and updates `epics.md` and `sprint-status.yaml` with sonlm.

### Commands for sonlm (fill in `<v>` in Task 2.1)

Windows PowerShell, from the folder that holds the `.pem`.

```powershell
# Desktop build (feel check)
scp -i .\sonlm2026-private.pem -r sonlm@123.31.11.131:/home/sonlm/project/pixel_art_game/builds/<v>/windows $HOME\uc-cp1
# Web (feel check + Chrome/Firefox perf): keep this open while testing
ssh -i .\sonlm2026-private.pem -t -L 8060:127.0.0.1:8060 sonlm@123.31.11.131 "cd ~/project/pixel_art_game && BUILD_DIR=builds/<v> PORT=8060 ~/.nvm/versions/node/v24.14.0/bin/node tools/web_smoke/serve.js"
```

URLs:
- Feel check: `http://localhost:8060/embed.html?build=web`.
- Perf: `http://localhost:8060/web_debug/index.html?room=perf_worst&perf`, then the same with `&glow=on`.

Read the summary line from DevTools → Console (`[room] dev: perf …`).

### Record template (Task 2.1)

```markdown
# Playtest: CP1 gate (Story 1.15)

**Build:** <v> · **Date:** · **Played by:** sonlm (not blind) · **Machines:** laptop (Windows, <GPU>, <refresh> Hz); HD 620: <yes/not available>; Linux desktop: <yes/not available>

## Questions
1. Does the migrated shaft feel right on desktop (×3) and in the browser (×2)?
2. Physics interpolation: keep or turn off?
3. Perf scene: does it hold 60 FPS everywhere, glow off and on? Glow go or no-go? Light budget 6 or lower? Flare cap?
4. Air dash: ≈ 39 px as it is, or 31 px?

## Automated gate
(Task 1 evidence: test count and ok total, the test_chain_state diff, test_lint, smoke_bot best chain, export.sh line)

## Answers
| Question | Answer (yes / no / mixed) | Notes |
|---|---|---|

## Evidence
(feel notes, deaths and attempts, perf summary lines verbatim)

## Decisions and follow-ups
(each decision with its date; follow-up stories with keys; ledger items closed)

## Devlog / private build
```

### Project Structure Notes

- New: `_bmad-output/implementation-artifacts/playtests/1-15-cp1-gate-feel-check-and-performance-verdict.md`.
- Changed: `docs/perf.md` (Results), `_bmad-output/project-context.md`, `_bmad-output/game-architecture.md`, the GDD (`planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md`, Open Questions and maybe Movement), `planning-artifacts/epics.md` (AR6, maybe FR2), `deferred-work.md`, `sprint-status.yaml`.
- Code only if a decision calls for it: `scripts/actors/player.gd` and `rules/tuning.gd` with `tests/smoke_player_input.gd` (dash); `core/budget_light.gd` with `tests/spec.gd` (budget); `project.godot` with `tests/smoke_room_swap.gd` (interpolation, after a HALT).
- Never `game/override.cfg` in the repo. It would override the project for everyone (the editor reads it from the project root). It lives only beside sonlm's exe.

### Project Context Rules (that apply here)

- **Headless tests can't judge feel.** Never write "feels better" or "runs at 60 FPS". Report what sonlm said, in his words.
- **Change a value → update the matching GDD table** (the dash, the budget). **Never loosen a threshold to pass:** `Spec.LIGHTS_ON_SCREEN_MAX` can only go down, and only after the GDD changes.
- Tuning `const`s keep their `##` unit, intent and "was X" comment (dash, if it changes).
- **Every deferred item needs an owner**; `test_deferred_owners` fails otherwise. Closing an item uses the `→ **Closed (Story 1.15): …**` line, as at 1.9 and 1.12.
- Physics interpolation rules (project-context, Engine) stay true if it's kept. If it's turned off, the "Physics interpolation is on (Story 1.7)" rule and the Display stack line change with it.
- **Do git yourself.** Commit with the attribution lines. Builds aren't committed.
- Every test run: `cd game && ./run_tests.sh` → `== ALL GREEN`.

### Previous story intelligence (1.12–1.14)

- **1.12 perf look (2026-11-19):** the run holds, the sprite fallback reads alright, and glow is "passable". That was a first impression, not the verdict. The light art is "a bit barebone" (deferred to 4.5).
  - The D7 probe saw glow darken the dark ambient on llvmpipe, `(6,5,16)` → `(0,0,11)`; the look check confirms it on a real GPU.
  - Overlay 2 is "still a bit shaky" while falling (deferred to 1.20). Keep overlays off during runs anyway.
- **1.13:** `export.sh` makes `builds/<yyyymmdd>-<sha7>`, with a fresh `user://` per build. Builds from a dirty tree get `-dirty`, so build from a clean tree.
- **1.14:**
  - `Display` opens the PC window at ×3 or the largest scale that fits; the web scale follows physical pixels, so browser zoom doesn't change it (re-check 2026-11-21).
  - The web key guard passes F11 and Ctrl +/−/0 through to the browser.
  - Desktop and web looks passed on the Windows laptop.
- **1.10:** the bot's best chain in `m1_shaft` was 8, and a full descent takes about 28 s.

### Git intelligence

```
ccc8ac4 docs: story 1.14 laptop re-check passed
9f9d6e1 fix: web guard passes F11 and browser zoom to the browser (story 1.14 laptop look)
42f7129 docs: story 1.14 review record, status done
473244c fix: story 1.14 code review fixes
317fd60 docs: display and web input, story 1.14 dev record, status review
```

The tree is clean on `feat/m2-e1`.

### Latest tech notes (Godot 4.7.2, verified 2026-11-21)

- `override.cfg` beside an exported binary is read at startup and overrides project settings. `physics/common/physics_interpolation=false` there turns `SceneTree.physics_interpolation` off (probed, D2).
- The Windows editor ships a `_console.exe` twin. Use it to see stdout (the perf summary).

### Cross-story context

- **1.16:** the effects accessibility gate and the shader warm-up (the first-second hitch).
- **1.20:** `LightSource` and `Sensing`.
- **1.22:** the cache glow (CACHE rank).
- **1.23:** Flare Toss and the flare cap as `Tuning`; budget hysteresis at the view edge.
- **1.30:** the CP2 gate, which uses this story's record format.
- **7.13:** the 10-minute perf pass (NFR1).
- **7.14:** Steam Deck and the accessibility passes.

### References

- `_bmad-output/planning-artifacts/epics.md` → Story 1.15 (l.1694); Epic 1 checkpoints (l.1263); "Story types and human gates" and "Playtest records" (l.1246–1250); AR5, AR6 (l.202–203); FR2 (l.47); NFR1, NFR5 (l.172, 176).
- `_bmad-output/game-architecture.md` → decision rows 8 and 14 (l.290, 296); Frame Pacing (l.409–413); Lighting (l.451–455); Perf run (l.644).
- GDD → Movement, air dash (l.125); Performance (l.657–661); Open Questions, bloom and flare cap (l.786–787).
- `docs/perf.md` (procedure, decision guide, Results table); `docs/build.md` → Playing builds on the laptop.
- `_bmad-output/implementation-artifacts/deferred-work.md` → the items owned by Story 1.15 (dash, glow, X11 decorations).
- `_bmad-output/implementation-artifacts/1-12-worst-case-performance-scene.md` (Change Log, laptop look) and `1-14-display-scaling-and-web-input.md`.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

## Change Log

- 2026-11-21: Story created (gds-create-story). Ultimate context engine analysis completed - comprehensive developer guide created. D1–D7 are the story author's calls. Probes: `override.cfg` beside an exported binary is read, and it turns physics interpolation off; the `test_chain_state` diff against M1 shows harness lines only.
