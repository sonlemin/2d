---
name: server-suspected-compromise
description: "2026-11-22 the dev server showed SSH-backdoor signs and broken /etc/passwd; repo had no git remote, bundle sent to sonlm"
metadata:
  node_type: memory
  type: project
  originSessionId: fdf79c9d-1f5f-478d-afcc-c7594804d85d
  modified: 2026-11-22T16:06:46.627Z
---

On 2026-11-22 a read-only check of the headless dev server (see [[dev-environment-headless-server]]) found:
- a root `apt install` of the toolchain at 16:27 (gcc, linux-headers, libpam-dev and so on);
- `/etc/rpm/*OLD` copies of the SSH binaries;
- `ssh-keysign` failing `dpkg -V`, with a faked mtime;
- `EnableSSHKeysign yes` in `ssh_config`;
- `/etc/passwd` rewritten at 20:08 with CR-only line endings, adding user `carol`, so every name lookup fails and sudo and new SSH logins are broken;
- `sshd_config` allowing a root password login since 21 Jul.

sonlm had not yet confirmed whether any of it was their own doing.

The repo had **no git remote**. Story 1.20's Tasks 1–11 were committed as 84df0b7. A `git bundle --all` (sha256 26edfbd1…9a997217) was sent to sonlm through SendUserFile.

**Why:** a future session may be on a rebuilt server or a restored clone. Credentials from this server (GitHub, id_ecdsa, Claude login, API keys) were advised for rotation.

**How to apply:** before relying on this server, ask whether it was rebuilt. Suggest adding a git remote so work isn't held only on one machine. Story 1.20 Task 12 (the laptop look) is still pending.

2026-11-22, at sonlm's request: I deleted the two `.env` files (GH_TOKEN in project/godot, HF_TOKEN in project/airesearch), `~/.ssh/id_ecdsa` and its `.pub`, and the two Antigravity IDE server tokens. I kept the Claude login so the session stays alive. Revoking each one at its service is sonlm's job.

2026-11-22: pushed all 4 branches to the private GitHub repo sonlemin/2d (remote `origin`, HTTPS). The token sonlm pasted was used only through GIT_ASKPASS and never stored, and sonlm was told to revoke it. Pushing needed "Block command line pushes that expose my email" turned off in their GitHub settings.
