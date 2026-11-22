---
name: do-git-yourself
description: "Don't hand git commands back to sonlm — run local git ops (branch, switch, commit when asked) yourself"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 7345e958-42d6-4343-a883-7cf4f7fa8786
  modified: 2026-11-12T05:25:05.964Z
---

Run local git steps yourself instead of telling sonlm to type them. Example: after committing I suggested "run `git switch -c feat/m2-e1`" and they replied "can't you do git yourself".

**Why:** sonlm works over SSH on a headless server and expects the agent to handle routine repo plumbing.

**How to apply:** if a branch or switch is the obvious next step, do it and say so. Commits still need sonlm's request, and pushes stay explicit. Never ask sonlm to run a command you can run. Related: [[dev-environment-headless-server]].
