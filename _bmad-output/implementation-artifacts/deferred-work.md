# Deferred Work

## From spec-m1-core-loop-prototype (2026-11-08)

- **Field Journal death line** — on death, write one journal line naming the cause (Hard Landing / Prey). Milestone 1 scope; deferred from the core-loop slice.
  → **Owner: E1** (2026-11-12). Causes are now the M2 damage sources (cause + how to avoid; Hard Landing and Prey were dropped by M1 tuning); voice per `narrative-design.md`.
- **HUD polish** — styled chain counter, light meter, flash-safety "reduce flashing" toggle in a settings menu.
  → **Owner: E1** (HUD v2 in the gutters, reduce-flashing toggle in Options); final polish E7.

## Mechanic ideas — after the M1 playtest (2026-11-10)

Rule: add these one at a time, each as its own experiment, only after M1 answers
"does a long chain feel tempting and dangerous?". Mixing them in earlier would hide that answer.

**Owner (2026-11-12): the M2 retrospective**, before the Layer 2 GDD update — review this list there and
promote at most one idea per layer milestone. None are in M2 (GDD Out of Scope: "No block or parry in M2").

- **Lurker parry (top candidate after M2)** — a tightly timed attack into a hunting lurker makes it recoil;
  the chain survives (maybe +1 link). Turns the danger into temptation. Needs a big flash/freeze payoff.
  → **Owner (2026-11-12): the M2 retrospective**
- **Phase dash** — the air dash passes through enemies briefly, at a cost (light or one link).
  → **Owner (2026-11-12): the M2 retrospective**
- **Cash in the chain** — spend links to heal or open sealed doors: bank it now or keep it growing.
  → **Owner (2026-11-12): the M2 retrospective**
- **Chain-bending upgrades** — power-ups per run that change chain rules
  (e.g., "survive one landing", "Snuff doesn't break the chain").
  → **Closed (2026-11-12): absorbed.** Rule-bending moved to always-on Smith gear (GDD); per-run power-ups
  are the parked "Dive Boons". "Snuff doesn't break the chain" contradicts Snuff as a cash-out.
- **More pogo directions** — diagonal pogo; pogo off spikes and lurker projectiles, not only crawlers.
  → **Owner (2026-11-12): the M2 retrospective**
- **Wall-jump climbing (earned upgrade)** — M1 cling only slides down (a pause, not a route).
  Climbing comes back later as an ability you find, gating areas in Metroidvania style
  (Pillar 3: progress by skills, not XP). Variant to test: climbing costs chain links.
  → **Owner (2026-11-12): the M2 retrospective**

## Deferred from: code review of 1-1-move-m1-into-the-m2-folder-layout.md (2026-11-12)

- **Dev guide "Writing tests" is M1 guidance** — `docs/development-guide.md:53-54` says tests are `extends SceneTree` and pure rules go into `test_chain_state.gd`; project-context says a new `tests/test_<subject>.gd` run through `tests/runner.tscn`. Pre-existing; agents that read `docs/` first would put unrelated rules into the chain test.
  → **Owner: Story 1.2** (confirmed by sonlm 2026-11-12) — it moves every test onto `runner.tscn`, so it rewrites this section anyway.
  → **Closed (2026-11-12): rewritten in Story 1.2.**
- **bmad-loop's canonical ledger format would switch off the owner gate** — `### DW-n` headings with `status:` lines contain no `- ` items, so after a `bmad-loop sweep --migrate` the scan in `tests/test_deferred_owners.gd` sees 0 items and prints PASS. Latent: only matters if bmad-loop is adopted.
  → **Owner (proposed): Story 1.9** — it builds the glob runner and the lint, where ledger-format checks belong.

## Deferred from: code review of 1-2-log-and-a-clock-that-owns-time.md (2026-11-12)

- **A pause mid-request holds `Engine.time_scale` at the reduced value** — `game/scripts/core/clock.gd`: AR36 makes requests freeze with the pause, so the scale stays at 0.05 (hitstop) or 0.3 (E6 slow-mo) for the whole pause. `PROCESS_MODE_ALWAYS` UI (pause tab, menus, focus-loss pause) then runs its default Tweens and AnimationPlayers 3–20× slower. Latent: nothing pauses until the UI stories.
  → **Owner (proposed): Story 1.31** — the UI kit builds the shared easing and tweens, so it can make them ignore the time scale (as AR44's audio tweens already do).
