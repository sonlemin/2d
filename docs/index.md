# The Unbroken Chain — Documentation Index

**Type:** monolith (one Godot game + an asset tool)
**Primary Language:** GDScript
**Architecture:** scene-tree composition with a pure-logic core
**Last Updated:** 2026-11-19 (DevTools, Story 1.11; initial scan 2026-11-11, exhaustive)

## Project Overview

A 2D pixel-art descent Metroidvania built in Godot 4.7. You pogo off enemies to build a chain; a bigger chain means a bigger blade, a brighter light, more embers, and lurkers that hunt the light. The code is the **M1 core-loop prototype** (one shaft, verdict *yes* on 2026-11-10). **M2** (vertical slice) is fully planned in the GDD and UX spines; its game architecture is not written yet.

## Quick Reference

- **Tech stack:** Godot 4.7 · GDScript · GL Compatibility · 480×270 integer-scaled · Python/Pillow sprite pipeline
- **Entry point:** `game/scenes/world/world.tscn` → `game/scripts/world/world.gd`
- **Core rules:** `game/scripts/rules/chain_state.gd` (pure, unit-tested)
- **Architecture pattern:** scene tree + node-free rules class + rooms as text files (`game/rooms/`, built by `RoomLoader`) + session state in pure objects held by the `Game` autoload
- **Database / API:** none
- **Deployment:** none yet (played from the editor); M2 targets Windows, Linux, web/itch.io

## Generated Documentation

- [Project Overview](./project-overview.md) — summary, stack, features
- [Architecture](./architecture.md) — structure, state, flows, level data, physics layers, testing, **gaps against the M2 design**
- [Component Inventory](./component-inventory.md) — every script, node, tuning value, input action and asset
- [Source Tree Analysis](./source-tree-analysis.md) — annotated directory tree
- [Development Guide](./development-guide.md) — run, test, edit art and levels, common tasks
- [Rooms](./rooms.md) — the room file format, legend, validator errors and `Room` API

Not generated (nothing to document): API contracts, data models, deployment guide, contribution guide, integration architecture.

## Existing Documentation

**Code**

- [game/README.md](../game/README.md) — controls, loop rules, how to run tests

**Planning** (`_bmad-output/planning-artifacts/`)

- [GDD v1.0](../_bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md) — the M2 design: mechanics, world, economy, tuning tables, platform and performance targets
- [Epics](../_bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/epics.md) — E1… development epics
- [GDD decision log](../_bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/decision-log.md)
- [UX DESIGN.md](../_bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/DESIGN.md) — how it looks: gutters, palette, font, HUD
- [UX EXPERIENCE.md](../_bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/EXPERIENCE.md) — how it behaves: journeys, screens, notes for architecture
- [UX mockups](../_bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/mockups/) and [validation report](../_bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/validation-report.md)
- [Game brief](../_bmad-output/planning-artifacts/briefs/brief-pixel_art_game-2026-11-08/brief.md) and [addendum](../_bmad-output/planning-artifacts/briefs/brief-pixel_art_game-2026-11-08/addendum.md) — partly superseded by the playtest findings
- [Domain research](../_bmad-output/planning-artifacts/research/domain-indie-pixel-art-pogo-descent-platformer-research-2026-11-07.md) — pogo-descent platformer research
- [Brainstorming session](../_bmad-output/brainstorming-session-2026-11-07.md)

**Implementation** (`_bmad-output/implementation-artifacts/`)

- [M1 spec](../_bmad-output/implementation-artifacts/spec-m1-core-loop-prototype.md) — what the current code was built to
- [M1 playtest findings](../_bmad-output/implementation-artifacts/m1-playtest-findings.md) — verdict, design deltas, tuning snapshot
- [Deferred work](../_bmad-output/implementation-artifacts/deferred-work.md) — deferred features and post-M1 mechanic ideas

## Getting Started

### Prerequisites

Godot 4.7 (Python 3 + Pillow only to rebuild art).

### Run

Open `game/` in Godot and press F5.

Debug runs take DevTools args (Story 1.11):

```bash
godot --path game -- --room=m1_shaft --chain=8 --set=brightness:0   # also --log=<cat>,<cat>; ?room=…&chain=… on a web debug build
```

In the editor, set them in Debug → Customize Run Instances (per-instance arguments, stored in `.godot/`), never in Project Settings `editor/run/main_run_args`, which is written into the committed `project.godot`. The backquote key (`` ` ``) cycles the four overlays, then off. Details: [Development Guide](./development-guide.md).

### Run Tests

```bash
cd game && ./run_tests.sh      # GODOT=/path/to/godot if not on PATH
```

### Rebuild Art

```bash
python3 tools/build_sprites.py
```

## For AI-Assisted Development

- **Gameplay rule change** (chain, light, embers, Flare Toss): `architecture.md` → State Management, then `rules/chain_state.gd` and `tests/test_chain_state.gd`. Keep `ChainState` free of nodes.
- **Feel or tuning:** `component-inventory.md` tuning tables; keep the GDD tables in sync.
- **New enemy or predator:** `component-inventory.md` (Crawler/Lurker) and `development-guide.md` → Common Tasks. Respect the layers, groups and the `monitorable` kill rule.
- **Level work:** `rooms.md` (format, legend, validator) and `architecture.md` → Level Data. Edit `game/rooms/l1/m1_shaft.txt`; run `test_room_loader` and the smoke test's bot after changing it.
- **M2 architecture** (`gds-game-architecture`): start from `architecture.md` → *Gaps against the M2 design*, the GDD and UX `EXPERIENCE.md`'s `[NOTE FOR ARCHITECTURE]` items.
- **Build/deploy:** no config yet; see the GDD Platform-Specific Details.

---

_Documentation generated by the BMAD `gds-document-project` workflow._
