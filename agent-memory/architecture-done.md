---
name: architecture-done
description: gds-game-architecture finished 2026-11-11 — _bmad-output/game-architecture.md complete; follow-ups owed to project-context.md and GDD
metadata:
  node_type: memory
  type: project
  originSessionId: 2d92c17c-e03b-4fb8-b397-905248a688b1
  modified: 2026-11-11T16:38:29.018Z
---

Game architecture finished 2026-11-11: `_bmad-output/game-architecture.md` (status complete, 18 decisions, 6 ADRs, 5 novel patterns). It supersedes several [M1] rules in project-context.md (flat scripts, @export tuning on actors, statics + scene reload, F-key hotkeys, hand-kept test list).

**Why:** the user ran every step with "A auto apply continue" — they trust recommended options and want momentum, but each step got an elicitation pass.

**How to apply:**
- project-context.md was updated from the architecture on 2026-11-11 (67 rules; has a "Current State vs Target" section because the code is still M1 until the E1 migration story).
- GDD follow-ups applied 2026-11-12 (exit backstop row, retarget telegraph, cache ≥ 80 px, spine width wording, flare-cap open question); logged in the GDD decision-log.
- Agreed order: architecture → narrative (gds-create-narrative, linear flag-gated lines only) → epics & stories → readiness → sprint planning.

Related: [[ux-spines-final]], [[m1-done-m2-planning]], [[prefers-option-lists]].
