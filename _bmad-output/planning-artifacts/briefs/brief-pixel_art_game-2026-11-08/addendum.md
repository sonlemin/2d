---
title: "Addendum: Game Brief, The Unbroken Chain"
status: final
created: 2026-11-08
updated: 2026-11-08
companion_to: brief.md
---

# Addendum: The Unbroken Chain

The brief keeps only the vision, pillars and scope. This file holds the detail that `gds-gdd` needs and the brief does not. Decisions and their reasons are recorded in `.decision-log.md`.

## Controls (4-button kit)

The kit is designed for the keyboard first. A controller mapping comes later, so the GDD should not use button combinations that a gamepad can't reproduce.

| Input | Tap / basic | Modifier / hold |
|---|---|---|
| Move | Run, aim the pogo | — |
| Attack | Slash | Down + Attack = **pogo** |
| Jump | Jump | Hold at a wall = **cling** |
| Dash | Air dash | Hold = **swing** |
| Light | **Flare Toss** (spend chain to throw light) | Hold = **Snuff** (go dark, breaks the chain) |

## Chain rules and tuning constants

- The **chain** goes up by one for each pogo hit without landing.
  - It powers **Blade Bloom**, which makes the slash bigger.
  - It powers **Chain-Light**, which makes the light radius bigger.
- **Ways a chain ends or changes:**

| Action | Effect on the chain |
|---|---|
| Landing | Breaks the chain |
| Wall Cling | Pauses the chain for a grace window (*~1 s, to tune*), then it breaks |
| Snuff | Breaks the chain |
| Flare Toss | Spends part of the chain (*the cost formula is an open question*) |

- Light attracts predators.
  - The ground is a sanctuary, except in layers that flip the rule (Freezing Magma: light is warmth).
  - Predators drawn by light must always **telegraph** their approach (sound, eyes in the dark, a glow at the edge of the screen). This comes from Pillar 2.
- **Skill gates:** key gates and shortcuts need a minimum chain length to open. This comes from Pillar 3's ruling. Each major gate needs a "min chain" property.
- **Tuning constants to set in the MVP:**
  - the chain → light radius curve
  - the chain → Blade Bloom curve
  - the radius at which predators notice the light
  - the wall-cling grace time
  - the Flare Toss cost

## World

| # | Layer | Boss | Boss lesson | Notes |
|---|---|---|---|---|
| 1 | Edge of the Abyss | Weaver | Restraint (Snuff, Lure, Strike) | MVP palette; milestone 2 slice |
| 2 | Bright Moon | Moon-Eyed Stalker | *open* | Predators always see you up close; force field *open* |
| 3 | Inverted Trees | Rootmother | *open* | |
| 4 | Great Mountain | Mountain-That-Walks | *open* | |
| 5 | Whirlstorm Hell | Eye of the Storm | *open* | |
| 6 | Freezing Magma | Hollow Furnace | Commitment | Light is warmth; the sanctuary rule flips |
| 7 | The Bottom | The Last Explorer | Mirror fight | "Layer 7 for now"; the game could be extended later |

- **Island hub NPCs:** Guild, Cartographer, Naturalist, Smith, Memorial Wall, Docks, Gallery, Mentors.
- **Meta systems:**
  - Living Map
  - Field Journal (deaths become entries)
  - Depth Record
  - Relic Haul
  - Lift Stations (camp, shortcut and fast travel in one)
  - Expedition Loadout
- **Peak moments from the brainstorm:**
  - The Speck (awe)
  - Riding the Giant (thrill)
  - The Last Entry (melancholy)
  - Felling the Canopy (chaos)
  - The Curious Companion (wonder)
  - The Watching Departure
- **Ways to fail:** Hard Landing, Grip Gives Out, Running Dry, Prey.

## Art pipeline notes

- **Resolution:** 480×270, with sprites of about 16–24 px. *This replaces the brainstorm's 12×12 "Tiny Explorer"*, for readability and boss detail.
- **Sprites:** text pixel grids and palette files → Python/Pillow → PNG spritesheets, kept in git. Layer palettes are swapped with a shader. Bosses are built from segments.
- **AI-assisted pipeline:** disclose it on every store page, and keep the commit history as proof of provenance.
- **Light effects:** Godot's PointLight2D and CanvasModulate for the light radius. HDR bloom stays within the flash limits: no more than 3 flashes per second, plus a "reduce flashing" toggle.
- **Feel effects:** freeze frames and sparks on hits, slow motion only at boss climaxes, and screen shake that can be turned off.

## Market context (from the domain research, for reference only)

This is a passion project, so these numbers are **context, not constraints**. They matter only if the release plan changes.

- **Price band:** comparable titles sell at $15–20. Of Metroidvanias priced $15–19.99, 14.3% reached 1,000 reviews (about $150k gross). None priced under $10 did.
- **Genre performance:** 6.2% of Metroidvanias reach 1,000 reviews, against 4.2% across Steam. The median 2026 Steam release earns about $1.7k gross.
- **Saturation:**
  - 291 Metroidvanias released in 2025.
  - The "roguelike" tag is crowded.
  - Next Fest had 4,382 demos.
- **If the game goes to Steam:**
  - About 7k wishlists are needed to reach Popular Upcoming.
  - Release a demo about 5 months before launch.
  - Complete the Steam content survey.
  - Show the world, map and story in the first 5 minutes.
- **Comparable solo projects:** Pseudoregalia (200k+), Haiku the Robot (about 15k copies in 6 weeks), Extraneum (about $12k net).

## Open questions (full list)

- **Chain tuning:** skill-gate thresholds, the wall-cling grace time, the Flare Toss cost formula, and whether Snuff needs an extra cost on top of breaking the chain.
- **Layers:** what the Bright Moon force field is, and how predators telegraph in each layer.
- **Bosses:** the lessons for bosses 2–5, and whether bosses react to *what you are*.
- **Story:** what "breaking the cycle" means in practice, the content of Layer 7 and the Truth, and the island's economy after the ending.
- **Meta systems:** which are core and which are optional.
- **Input:** the keyboard layout, then the controller mapping.
- **Release:** Steam or itch-only, decided at milestone 2. Whether to add a "longest chain" leaderboard (low priority, since the game is exploration-first).

## Parked and cut features

- **Parked:**
  - Roaming Ecology
  - The Abyss Breathes
  - Crafting
  - Food Chain (all four only in the full-vision tier)
  - Dive Boons (likely to be cut; conflicts with exploration-first)
- **Cut:**
  - The Climb Back
  - The Boon Deck ("too many competing progression systems")
