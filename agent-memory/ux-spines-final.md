---
name: ux-spines-final
description: gds-ux finished 2026-11-11 — DESIGN.md/EXPERIENCE.md final; key UX choices and notes owed to GDD/architecture
metadata:
  type: project
---

gds-ux finished on 2026-11-11. Workspace: `_bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/` (DESIGN.md, EXPERIENCE.md, .decision-log.md, mockups/). Both spines have `status: final`.

Choices that shape everything downstream:
- Downwell-style side gutters, 60 px each, used everywhere, so rooms are framed for 360 px of visible width.
- HUD colours match the current zone. Amber = player (menus too), red = predators.
- Keyboard-first with full gamepad support. The web build is primary.
- 3 save slots.

**Why:** the spines win over the GDD on UX. The UX run also changed GDD-owned rules, and those changes still have to be carried back into the GDD.

**How to apply:**
- Before `gds-game-architecture` or E1 stories, read EXPERIENCE.md "Notes for Other Docs" and "Epic Rollout". These cover the architecture needs (3 save slots, storing death lines, DPR scaling, a 360 px camera).
- The font is Fusion Pixel 8px (OFL). Spine shafts are 22 tiles (352 px), and E1 rebuilds the 30-tile M1 shaft at that width.
- The GDD was patched with the UX notes on 2026-11-11. The architecture notes were addressed in game-architecture.md (2026-11-11), see [[architecture-done]].
- E4 and E5 screens must be mocked via gds-ux Update before they are built.

Related: [[m1-done-m2-planning]], [[prefers-option-lists]].
