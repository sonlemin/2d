---
name: epics-done
description: "gds-create-epics-and-stories complete 2026-11-12 — planning-artifacts/epics.md, 137 typed stories E1–E7; conventions, key decisions and pending follow-ups"
metadata:
  node_type: memory
  type: project
  originSessionId: 0f86f983-75f1-4f0b-b7aa-9f67416209f6
  modified: 2026-11-12T03:36:59.294Z
---

`_bmad-output/planning-artifacts/epics.md` finished 2026-11-12 (status complete): 333 requirements (81 FR, 19 NFR, 58 AR, 150 UX-DR, 25 NR), 137 stories (E1 41, E2 12, E3 9, E4 26, E5 17, E6 15, E7 17), all IDs cited, all FR numbers carried into stories. Validated by an independent subagent (1 blocker, 3 major, 18 minor, all fixed).

**Why:** the user approved every recommended option. Elicitation and two party rounds added the structure that matters downstream.

**How to apply:**
- Story conventions: `**Type:**` line (dev / content / designer / playtest / ux-update). Human gates: the dev agent HALTs and never fakes a sign-off. "Decide before dev (sonlm)" is asked in gds-create-story. "Tune after play (sonlm)" means a default plus tests; sonlm picks after playing. Playtest records go in `implementation-artifacts/playtests/<story-key>.md`.
- Key decisions: E1 has CP1/CP2/CP3 (gates 1.15, 1.30, 1.41); brightness ships in E1; the flag registry starts in E4 (`set_story_flag` is separate from world `set_flag`); E3 sketches the motif and placeholder stems; a playtest "no" blocks only dependent epics; save v1 freezes at E1 close and every later epic starts with a migration; v2 remaps `m1_shaft` saves to `station_lip`; flare embers use floor(held×spent/n); the Naturalist pays 10 for any new entry; dependencies include E2→E3 and soft 3.2→4.11.
- Follow-ups in epics.md under "Follow-ups before gds-check-implementation-readiness", BOTH DONE 2026-11-12: (1) ✅ gds-gdd update: E1 M→L, M2 = 44–88 weeks (user picked the band sum over the stale 40–80), dependents-only "no" rule + dependency line, E2→E3, Brightness in E1 Accessibility → Video in E7. Known gap left open: UX EXPERIENCE.md still lists Brightness as E7 assumption A1 (lines ~84/313/532) — expect the readiness check to flag it; (2) ✅ DONE 2026-11-12: `_bmad/custom/gds-create-story.toml` adds a persistent_fact path map (exact paths, SELECTIVE_LOAD; user chose path map over full `file:` load to avoid ~85k tokens/run) + `file:` m1-playtest-findings. If the dated GDD/UX folders are renamed, update that file.
- Deferred-item sweep 2026-11-12: cache glow radius (A8) and bank-heal threshold (A1) are owned by the CP2 gate 1.30; hub ambience by 5.3; O8 for The Fall by 5.2/6.6. Conditional or post-M2 only: UX O18 (CJK), Godot MCP, the sequence runner.
- Next: readiness ran 2026-11-12 (NEEDS WORK) — see [[readiness-needs-work]]; fix E1, then gds-sprint-planning.

Related: [[narrative-done]], [[architecture-done]], [[prefers-option-lists]].
