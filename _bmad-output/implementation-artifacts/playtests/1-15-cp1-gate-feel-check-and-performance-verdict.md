# Playtest: CP1 gate (Story 1.15)

**Build:** 20261121-e304d31 · **Date:** · **Played by:** sonlm (not blind) · **Machines:** laptop (Windows, <GPU>, <refresh> Hz); high-refresh display: <Hz>; HD 620: <yes/not available>; Linux desktop: not available (sonlm, 2026-11-21)

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
| 1. Feel, desktop ×3 and browser ×2 | | |
| 2. Physics interpolation | | |
| 3. Perf, glow, budget, flare cap | | |
| 4. Air dash | | |

## Evidence

(feel notes, deaths and attempts, perf summary lines verbatim)

## Decisions and follow-ups

(each decision with its date; follow-up stories with keys; ledger items closed)

## Devlog / private build
