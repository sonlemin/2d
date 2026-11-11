# The Unbroken Chain — Project Overview

**Date:** 2026-11-11 · **Type:** game (Godot 4.7) · **Architecture:** scene-tree composition with a pure-logic core

## Executive Summary

*The Unbroken Chain* is a 2D pixel-art descent Metroidvania. You pogo off enemies without landing to build a **chain**. Each link makes your blade bigger and your light brighter, and a brighter light draws **lurkers** out of the dark. Every pogo adds **embers** to a held pile. Landing or Snuffing banks them; dying loses them. Pillar 1: *Chain = Light = Danger.*

The repository holds the **M1 core-loop prototype**: one hand-built shaft with crawlers and lurkers. Its playtest on 2026-11-10 answered *yes* to "does a long chain feel tempting and dangerous?". Planning for **M2** (a vertical slice: Layer 1, a hub, Lift Stations, Flare Toss, the Weaver boss) is complete in the GDD v1.0 and the UX spines. The game architecture for M2 has not been written yet.

## Project Classification

- **Repository type:** monolith
- **Project type:** game
- **Languages:** GDScript (game), Python (asset tool)
- **Pattern:** Godot scene tree; rules in a node-free `ChainState`; level from an ASCII array; session state in static vars

## Technology Stack Summary

| Category | Technology |
|---|---|
| Engine | Godot 4.7, GL Compatibility renderer |
| Language | GDScript |
| Display | 480×270 viewport, integer scaling, pixel snap, nearest filtering |
| Lighting | `PointLight2D` + `CanvasModulate` |
| Tests | Headless Godot `SceneTree` scripts (`run_tests.sh`) |
| Art pipeline | Python 3 + Pillow: text grids → PNG |
| Targets (M2 plan) | Windows, Linux, web/itch.io |

## Key Features (implemented in M1)

- Run, variable jump, coyote time and buffer, air dash, wall cling with a kick-off
- Ground slash and air **pogo** with hitstop, shake, squash and popups
- **Chain** (cap 20) driving Chain-Light radius and Blade Bloom
- **Embers**: held → banked on a safe break, lost on death
- **Snuff** (hold Light): go dark and break the chain to escape
- **Crawlers** (walkers and hoverers) as chain fuel
- **Lurkers**: notice big lights on screen, telegraph 0.9 s, hunt, and give up when they lose the scent
- Respawn at the last ledge stood on; debug HUD; 4 brightness levels

## Architecture Highlights

- The core rules are unit-tested with no scene. The level is integration-tested by simulated input and a pathing bot.
- Design rules from the GDD are encoded as tests: telegraph ≥ 0.75 s, no off-screen ambush, a Snuff in time always saves you.
- Everything is deterministic except camera shake: hover phase comes from position.
- Art is diff-able text, so a palette change is a one-line edit.

## Development Overview

- **Prerequisites:** Godot 4.7; Python 3 + Pillow for art.
- **Run:** open `game/` in Godot and press F5.
- **Test:** `cd game && ./run_tests.sh`
- **Art:** `python3 tools/build_sprites.py`

## Documentation Map

- [Architecture](./architecture.md) — including the gaps against the M2 design
- [Component Inventory](./component-inventory.md)
- [Source Tree Analysis](./source-tree-analysis.md)
- [Development Guide](./development-guide.md)
- [Index](./index.md)
