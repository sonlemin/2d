# Playtest: CP1 gate (Story 1.15)

**Build:** 20261121-e304d31 · **Date:** 2026-11-21 · **Played by:** sonlm (not blind) · **Machines:** laptop (Windows, NVIDIA GeForce RTX 3050 Laptop GPU + Intel HD Graphics iGPU, 60 Hz panel); high-refresh display: not available (the panel offers 60 Hz only); HD 620 machine: not available (the laptop's Intel iGPU, through Firefox, stood in); Linux desktop: not available

## Questions

1. Does the migrated shaft feel right on desktop (×3) and in the browser (×2)?
2. Physics interpolation: keep or turn off?
3. Perf scene: does it hold 60 FPS everywhere, glow off and on? Glow go or no-go? Light budget 6 or lower? Flare cap?
4. Air dash: ≈ 39 px as it is, or 31 px?

## Automated gate

Run by the agent on 2026-11-21, clean tree at `e304d31` on `feat/m2-e1`.

- **`cd game && ./run_tests.sh`:** 22 tests, 1397 `ok`, 0 `FAIL`, `== ALL GREEN (22 tests)`.
- **`test_chain_state` unchanged from M1:** `ALL PASS (69 checks)`.
  `git diff --stat feat/m1-prototype:game/tests/run_tests.gd HEAD:game/tests/test_chain_state.gd`:
  ```
  game/tests/{run_tests.gd => test_chain_state.gd} | 10 ++++------
  1 file changed, 4 insertions(+), 6 deletions(-)
  ```
  The hunks are exactly the allowed harness lines, and no `check(` line differs:
  - `extends SceneTree` → `extends Node`;
  - the `## Run:` line (`--script res://tests/run_tests.gd` → `res://tests/runner.tscn -- res://tests/test_chain_state.gd`);
  - the preload path `res://scripts/chain_state.gd` → `res://scripts/rules/chain_state.gd`;
  - `func _init()` → `func run()`;
  - `quit(0)` and `quit(1)` removed.
- **`test_lint`:** `PASS` (all rules, plus `spec_citation`: all 9 `Spec` consts cite the GDD).
- **`smoke_bot`:** `m1_shaft: the bot chains 5+ pogos with plain movement, no dash (Spec.BOT_MIN_CHAIN; best 8)`; it reaches the down exit alive. Best chain 8 (8 at 1.10).
- **`tools/export.sh`:** `== BUILD OK builds/20261121-e304d31, web download 10.3 MB (gzip; raw 40.0 MB), PCK files windows 76 / linux 76 / web 76 / web_debug 83, 117 s`. Headless Linux release boot: still running after 5 s, no error. Web smoke: `7 passed (1.0m)`.

## Commands (Windows PowerShell, from the folder that holds the `.pem`)

```powershell
# Desktop build (feel check)
scp -i .\sonlm2026-private.pem -r sonlm@123.31.11.131:/home/sonlm/project/pixel_art_game/builds/20261121-e304d31/windows $HOME\uc-cp1
# Web (feel check + Chrome/Firefox perf): keep this open while testing
ssh -i .\sonlm2026-private.pem -t -L 8060:127.0.0.1:8060 sonlm@123.31.11.131 "cd ~/project/pixel_art_game && BUILD_DIR=builds/20261121-e304d31 PORT=8060 ~/.nvm/versions/node/v24.14.0/bin/node tools/web_smoke/serve.js"
```

- Feel check (web): `http://localhost:8060/embed.html?build=web`.
- Perf (web): `http://localhost:8060/web_debug/index.html?room=perf_worst&perf`, then the same with `&glow=on`. The summary line is in DevTools → Console (`[room] dev: perf …`).
- Interpolation off (desktop): save this as `$HOME\uc-cp1\override.cfg`, beside `unbroken_chain.exe`; delete or rename it to go back to on.
  ```ini
  [physics]
  common/physics_interpolation=false
  ```
- Perf (desktop, D1): from the laptop clone, with the Godot 4.7.2 console exe.
  ```powershell
  cd $HOME\pixel_art_game
  git pull
  & "<path>\Godot_v4.7.2-stable_win64_console.exe" --path game -- --room=perf_worst --perf
  & "<path>\Godot_v4.7.2-stable_win64_console.exe" --path game -- --room=perf_worst --perf --glow=on
  ```

## Answers

| Question | Answer (yes / no / mixed) | Notes |
|---|---|---|
| 1. Feel, desktop ×3 and browser ×2 | yes | sonlm's verdict: yes; no fix named |
| 2. Physics interpolation | keep | sonlm: "I don't see the difference. It seem like normal gameplay like before this story" (on vs off at 60 Hz); no high-refresh display |
| 3. Perf, glow, budget, flare cap | yes (2 runs) | both runs hold the budget (6/6, over 0); glow no-go; budget 6 confirmed; flare cap: none needed. Only 2 of AC3's runs were made, by sonlm's choice |
| 4. Air dash | keep ≈ 39 px | sonlm kept the felt dash |

## Evidence

- **Feel:** sonlm played the release Windows exe at ×3 (60 Hz), with interpolation on and with `override.cfg` (off), and saw no difference between them. The laptop panel offers 60 Hz only (Windows "Dynamic refresh rate" not supported; "Choose a refresh rate" lists 60 Hz), so the high-refresh pass could not run.
- **Glow look check (4.5):** not run; glow was decided no-go without the glow-on runs.
- **Finding:** in the browser, F12 and Ctrl+Shift+J don't open DevTools: the 1.14 key guard prevents F1–F12 and Godot's canvas listener prevents every other key. Workaround: the browser menu (⋮ / ☰ → More tools).

### Perf summary lines (verbatim, pasted by sonlm 2026-11-21)

- Laptop desktop, glow off (editor run, debug, D1):
  `[room] dev: perf 60 s: 6924 frames, avg 115.4 fps, min 56 fps, worst 116.1 ms at 0.4 s, 16 over 20 ms; lights max 6/6, sprites max 7, over 0; chain 20, breaks 0, deaths 0; glow off; window 3456x1984; Windows, NVIDIA GeForce RTX 3050 Laptop GPU`
- Firefox, `web_debug`, glow off (laptop's Intel iGPU; tab kept in front):
  `[room] dev: perf 60 s: 3569 frames, avg 59.5 fps, min 28 fps, worst 562.0 ms at 0.0 s, 5 over 20 ms; lights max 6/6, sprites max 7, over 0; chain 20, breaks 0, deaths 0; glow off; window 3330x1087; Web, ANGLE (Intel, Intel(R) HD Graphics Direct3D11 vs_5_0 ps_5_0), or similar`
- In both, the worst frame is in the first second: the known first-second hitch (shader warm-up, Story 1.16).

### Discarded runs (tab hidden mid-run; not results)

- Chrome, glow off: `[room] dev: perf 60 s: 1343 frames, avg 7.5 fps, min 0 fps, worst 132798.6 ms at 47.2 s, 62 over 20 ms; lights max 6/6, sprites max 7, over 0; chain 20, breaks 0, deaths 0; glow off; window 3457x1822; Web, WebKit WebGL`
- Firefox, glow off: `[room] dev: perf 60 s: 1062 frames, avg 6.4 fps, min 0 fps, worst 146454.0 ms at 18.3 s, 7 over 20 ms; lights max 6/6, sprites max 5, over 0; chain 20, breaks 0, deaths 0; glow off; window 3330x1087; Web, ANGLE (Intel, Intel(R) HD Graphics Direct3D11 vs_5_0 ps_5_0), or similar (firefox)`
- Why: one frame of 132.8 s / 146.5 s means the browser stopped rendering a hidden tab; `perf_run.gd` measures wall time and skips only tree pauses, so the hidden stretch counted as one frame. Finding: the perf run should flag or exclude hidden-page time.

## Decisions and follow-ups

All by sonlm, 2026-11-21:

- **Physics interpolation: kept.** project-context (Display line, Engine rule), architecture Frame Pacing and decision row 8, AR6.
- **Engine glow: no-go.** Bloom = unshaded additive sprites; `--glow` stays DevTools-only. Architecture Lighting and row 14, the GDD bloom row, project-context Performance. No follow-up story.
- **Light budget: 6 confirmed.** Comments on `BudgetLight.MAX_ON_SCREEN` and `Spec.LIGHTS_ON_SCREEN_MAX`; architecture row 14.
- **Flare cap: none needed.** The GDD flare row and architecture Lighting; Story 1.23 makes it a `Tuning` value and re-checks it with real flares.
- **Air dash: keep ≈ 39 px.** GDD Movement and FR2 read 0.15 s (9 ticks, ≈ 39 px); code unchanged; `smoke_player_input` pinned exactly (8 gravity-free ticks, 9 dashing, 39.0 px; the same before and after).
- **Feel verdict: yes.** No fix stories, so no `gds-correct-course` run (D7).
- **Perf scope:** sonlm chose to make only the Firefox run after the laptop one (glow no-go makes the glow-on runs moot).

**Ledger** (`deferred-work.md`): closed the dash and engine glow items; the X11 decorations item → Story 7.14. New: interpolation at high refresh → 7.14; the perf run counting a hidden tab as one frame → 7.13; the web key guard swallowing the DevTools keys → 7.13; the runs not made at CP1 → 7.13.

## Devlog / private build

Devlog: `docs/devlog/cp1.md` (a note in the repo, D8), drafted by the agent, approved by sonlm.
