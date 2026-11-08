---
title: "Game Brief: The Unbroken Chain (working title)"
status: final
created: 2026-11-08
updated: 2026-11-08
inputs:
  - _bmad-output/brainstorming-session-2026-11-07.md
  - _bmad-output/planning-artifacts/research/domain-indie-pixel-art-pogo-descent-platformer-research-2026-11-07.md
companions:
  - addendum.md
  - .decision-log.md
---

# Game Brief: The Unbroken Chain (working title)

## Executive Summary

*The Unbroken Chain* is a 2D pixel-art descent Metroidvania set in a hand-built abyss. Its one original idea is that **your pogo chain is your light.**

Every hit you chain without landing makes your blade bigger and your light brighter. Brighter light draws the predators of the dark to you, so playing well is what puts you in danger. The game is about *daring mastery*: deciding how long to keep the chain going before landing, clinging to a wall, snuffing your light, or spending it.

You descend through seven layers below a small island hub. Each layer has its own sky, its own rules and its own boss. Along the way you learn that you aren't discovering the abyss; you're coming home to it.

This is a solo passion project with no deadline, made in Godot. The first goal is one playable shaft that answers a single question: *does a long chain feel both tempting and dangerous?*

## Vision

**Core fantasy:** Burn bright to dive deeper than anyone has, knowing that every flash of skill draws the abyss closer.

**Elevator pitch:** A descent Metroidvania where your pogo chain is your weapon, your light and your danger. The longer you chain without landing, the brighter you glow, and the more the abyss hunts you.

**Target feeling:** *Daring mastery.* After a good session the player thinks: "I pushed my luck, kept the chain alive, and got away with it."

Discovery comes second. New layers, secrets and the story of your origin are the **reward** for being daring, not the reason to keep playing.

## Gameplay Pillars

The pillars are listed in priority order. When two of them conflict, the higher one wins unless a specific ruling is noted.

1. **Chain = Light = Danger.**
   - Chaining hits without landing makes you stronger (Blade Bloom), brighter (Chain-Light) and hunted (predators are drawn to light).
   - Every feature must feed this tension or at least not weaken it.
   - *This pillar survives any cut.*
2. **Every death teaches.**
   - Failure has to be fair and readable.
   - Predators always signal their approach (a sound, eyes in the dark, a glow at the edge of the screen), including those drawn in from the dark. *Ruling: this pillar beats off-screen ambushes.*
   - Darkness creates tension, not confusion.
3. **Knowledge is power.**
   - The abyss is fixed and hand-built, with no procedural generation.
   - You progress by gaining skills, not XP.
   - Knowing the world tells you **where** to be daring; it never replaces daring. *Ruling: key gates and shortcuts open only with a long chain.*
4. **Few buttons, deep play.**
   - A 4-button kit: Attack, Jump, Dash and Light, plus movement.
   - Each layer changes how the same verbs are used instead of adding new ones.

## Core Loop

**Genre:** A 2D descent Metroidvania with light-based tension. It is *not* a roguelike: you never lose the world or your progress.

**Moment to moment:** *Burn bright → land → hide → burn again.*

1. Drop into a shaft.
2. Pogo off enemies and hazards to build the chain, growing brighter and stronger.
3. Decide when to cash out before the predators your light draws catch up. There are four ways out:
   - **land**, which breaks the chain
   - **wall cling**, which pauses the chain briefly
   - **Snuff**, which goes dark and breaks the chain
   - **Flare Toss**, which spends part of the chain as a thrown light that can lure predators away
4. Recover and dive again.

**Session:** Leave a Lift Station (a checkpoint, shortcut and fast-travel point in one) → push into the layer → find routes, secrets and skill gates → reach the next Lift Station or die and learn → return to the hub to spend your haul.

**Death:** The cost depends on the difficulty tier:

| Tier | What you lose |
|---|---|
| Easy | Nothing |
| Normal | Your currency drops where you died, and you can go back for it |
| Hard | Everything you were carrying |

In every tier you respawn at the last Lift Station, and the death is written into the Field Journal.

The full controls, chain rules and tuning constants are in the addendum.

## Target Players

**Primary: Metroidvania regulars.** Adults who have played games like *Hollow Knight* or *Celeste* and buy several Metroidvanias a year. They want tight, fair challenge and a world worth learning.

- **Session length:** 20–45 minutes, roughly one dive out and back.
- **Difficulty:** Normal is *Hollow Knight*-level, meaning hard but fair, with bosses that take several attempts. Easy opens the game to players who mainly want to explore.

**Secondary:** fans of precision platformers such as *Downwell* and *Celeste*, who come for the chain and stay for the world.

## References & Differentiation

| Title | What we take | What we deliberately leave |
|---|---|---|
| *Downwell* | The chain that lasts until you land; vertical descent | Procedural levels, arcade-length runs, the "Downwell-like" label |
| *Hollow Knight* | A hand-built interconnected world, the pogo, a map you have to earn, dropping currency and recovering it after death | Charm builds, deep combat systems, a large cast |
| *Spelunky* | Danger that comes from systems interacting; deaths that tell a story | Procedural generation, permadeath |
| *Celeste* | Few buttons with deep play, fair and instant failure, assist options | Room-by-room puzzles, collectibles as the main goal |

"Light attracts monsters" is **not new**: *Last Light*, *Oshi* and *In The Shadows* already do it. **What is new is that your skill is the light source.** Playing well makes you more visible, and research found no pogo-chain game with a hand-built world. Beyond that idea, the advantage is execution and feel.

## Scope & MVP

- **Team:** solo, about 5–10 hours a week, no deadline. This is a passion and learning project.
  - The full 7 layers (8–12 hours of play) is the goal.
  - At this pace that likely means 5 or more years, and that is accepted.
- **Platforms:**
  - PC (Windows and Linux) on Steam, if the game is released.
  - itch.io and web builds for playtests.
  - Keyboard first, with a controller mapping added later.
- **Technical constraints:**
  - Godot 4.7 with GDScript only.
  - A headless server runs tests and the sprite pipeline; builds are played on a laptop.
  - **Flash safety from day one:** no more than 3 flashes per second, plus a "reduce flashing" toggle.

**Milestone 1, the MVP:** one vertical shaft using the Edge of the Abyss palette.

- It includes the pogo, the chain, Blade Bloom, Chain-Light and Snuff.
- It has two enemies, one of them drawn to light, and one Field Journal line written on death.
- It answers one question: *does a long chain feel both tempting and dangerous?* Fix the loop before building anything else.

**Milestone 2: a vertical slice.**

- Layer 1 with a Lift Station, the first hub NPCs and the Weaver boss (a fight built on Snuff, Lure, Strike).
- Flare Toss joins the kit.
- This is the first build to share. The decision between Steam and itch.io is made here.

**After that:** build one layer at a time toward all 7.

## Content & Direction

- **World:** Abyss Island, a small hub built around a vast pit.
  - The pit has 7 layers, from Edge of the Abyss down to The Bottom.
  - Each layer has its own sky ("depth ≠ darkness"), its own rule twist and a boss that teaches one lesson.
- **Narrative:**
  - Told mostly through the environment, the Field Journal and the Memorial Wall, with brief conversations with hub NPCs.
  - There are at most three reveals: *origin, theft, cycle*.
  - It ends with **The Final Chain**, a playable unbroken descent with your light at full strength.
  - The tone takes its mood from layered-abyss adventure fiction. The world, creatures and story are original.
- **Art:**
  - 480×270 pixel art with sprites of about 16–24 px.
  - Each layer uses a palette of 4–6 colours. **The chain-light is the one colour that stays constant.**
  - Sprites are generated from code (text grids → Python/Pillow → spritesheets). The pipeline is **AI-assisted, and this is disclosed.**
- **Audio:**
  - A sparse ambient soundscape for each layer.
  - Music and a rising pitch that build with the chain, so a long chain *sounds* dangerous.
  - Each predator has a distinct sound cue so you can hear it before you see it.

## Risks

| Risk | Mitigation |
|---|---|
| **Losing momentum or burning out** over 5+ solo years | Share an itch.io build or devlog at every milestone, so each one is a finished thing |
| **The chain-light loop isn't fun** | The MVP tests exactly this; tune it before building anything else |
| **Snuff weakens the greed tension** | Snuff already breaks the chain. Test it in the MVP and add a further cost if needed |
| **Scope creep** (6 meta systems, 7 bosses, the hub) | Add meta systems one milestone at a time. Anything the current milestone's question doesn't need waits |

Smaller risks: flash safety (capped from day one), how players perceive AI-assisted art (disclose it and keep the provenance), and differentiation (lead with chain-as-light, never with "roguelike"). Open questions and parked features are listed in the addendum.
