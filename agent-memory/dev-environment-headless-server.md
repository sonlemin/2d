---
name: dev-environment-headless-server
description: "User works over SSH from a laptop on a headless server; builds are played in Godot on the laptop, not on the server"
metadata:
  node_type: memory
  type: project
  originSessionId: 5e47409c-9211-48fe-a830-6fa4b8e46b56
  modified: 2026-11-08T08:33:56.866Z
---

The user connects to this server from a laptop over SSH. The server has no display (DISPLAY empty), Godot 4.7.2 at ~/.local/bin/godot (headless use only), and Python with Pillow.

Decided 2026-11-07: the user plays and tests builds with **Godot installed on the laptop**, syncing the project through a git remote. A web (HTML5) export over an SSH tunnel is only a fallback. The server handles headless tests and the code-generated sprite pipeline (text pixel-grids → Pillow → PNG).

**Why:** a native build gives better input feel for frame-sensitive pogo/hit-pause tuning, and the editor is available on the laptop.

2026-11-08: Xvfb installed (user approved). Real renders work via `xvfb-run -a godot --path game --rendering-driver opengl3 --audio-driver Dummy res://tests/runner.tscn -- res://tests/screenshot.gd <out_dir>` (Mesa software GL; since Story 1.2 tests run through the scene runner, and `--audio-driver Dummy` silences the no-sound-card ALSA ERROR); `--headless` cannot render. Still no git remote as of then, and still none on 2026-11-12 (Story 1.5's gate said "push, then sonlm pulls"; `git push origin` failed). Before planning a push step, check `git remote -v`; if it's empty, tell sonlm the commits are local on the server.

**How to apply:** don't assume the user can see anything rendered on the server. To verify visuals, capture screenshots headless. When setting up the game project, plan for a git remote so the laptop can pull it.

2026-11-20: the laptop is **Windows** (PowerShell). sonlm logs in with `ssh -i .\sonlm2026-private.pem sonlm@123.31.11.131` (key file in the PowerShell working folder). Give laptop commands in that form: `scp -i … -r` (no rsync), `ssh -i … -t -L 8060:127.0.0.1:8060 … "<cmd>"` for the web tunnel. Non-interactive ssh may lack nvm's PATH, so call Node by its full path `~/.nvm/versions/node/v24.14.0/bin/node`.
