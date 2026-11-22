---
name: laptop-web-tunnel-one-liner
description: The exact commands sonlm runs from the Windows laptop for a build look - ssh tunnel + serve.js for web, scp + Start-Process for the desktop build
metadata:
  node_type: memory
  type: reference
  originSessionId: d3cb2b38-d418-4101-9f92-d557392d629b
  modified: 2026-11-21T18:21:12.812Z
---

sonlm looks at builds from the Windows laptop (PowerShell), always from `C:\Son OneDrive\OneDrive\Documents\0_ssh` (where the .pem lives). Web: one command serves the build on the server and tunnels it:

```
ssh -i .\sonlm2026-private.pem -t -L 8060:127.0.0.1:8060 sonlm@123.31.11.131 "cd project/pixel_art_game && BUILD_DIR=builds/<version> PORT=8060 ~/.nvm/versions/node/v24.14.0/bin/node tools/web_smoke/serve.js"
```

Then `http://localhost:8060/web_debug/index.html` (or `/web/`, `/embed.html?build=web`). Ctrl-C stops both.

Desktop (Windows release build): copy it down with scp, then start it without blocking the terminal:

```
scp -i .\sonlm2026-private.pem -r sonlm@123.31.11.131:/home/sonlm/project/pixel_art_game/builds/<version>/windows .\uc-<story>
Start-Process .\uc-<story>\unbroken_chain.exe
```

**Why:** sonlm expects these exact lines (absolute node path, since a non-login ssh shell lacks nvm on PATH; scp, not rsync; the build lands in the 0_ssh folder, not $HOME), not docs/build.md's generic versions.
**How to apply:** whenever handing over a build for a laptop look, give these lines with the version and story filled in. See [[dev-environment-headless-server]].
