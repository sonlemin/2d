---
title: "The Unbroken Chain — Game Design Document"
game_type: metroidvania (descent; action-platformer feel conventions)
platforms: [PC Windows, PC Linux, web/itch.io for playtests]
created: 2026-11-10
updated: 2026-11-22
status: final
inputs:
  - _bmad-output/planning-artifacts/briefs/brief-pixel_art_game-2026-11-08/
  - _bmad-output/implementation-artifacts/m1-playtest-findings.md
  - _bmad-output/brainstorming-session-2026-11-07.md
  - _bmad-output/planning-artifacts/research/domain-indie-pixel-art-pogo-descent-platformer-research-2026-11-07.md
  - _bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/DESIGN.md
  - _bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/EXPERIENCE.md
  - _bmad-output/narrative-design.md
---

# The Unbroken Chain - Game Design Document

**Author:** sonlm
**Game Type:** Metroidvania (descent), with action-platformer feel conventions
**Target Platform(s):** PC (Windows, Linux); web/itch.io for playtests

---

## Executive Summary

### Core Concept

A 2D descent Metroidvania. The pogo chain is your light. Chaining hits without landing makes you stronger (Blade Bloom), brighter (Chain-Light) and richer (embers), and it draws the predators that hunt by light. You descend seven hand-built layers below a small island hub; each layer has its own sky, rule twist and boss. Along the way you learn you are not discovering the abyss: you are coming home to it.

**Core fantasy:** *Burn bright to dive deeper than anyone has, knowing that every flash of skill draws the abyss closer.*
**Target feeling:** *Daring mastery*: "I pushed my luck, kept the chain alive, and got away with it." Discovery (new layers, secrets, your origin) is the reward for daring, not the reason to play.

### Target Audience

- **Primary:** Metroidvania regulars, adults who finished *Hollow Knight* or *Celeste*.
- **Secondary:** precision-platformer and arcade-descent fans (*Downwell*, *Celeste*).
- **Sessions:** 20–45 min.
- **Difficulty:** Normal is hard but fair, around *Hollow Knight* level, with bosses that take 3–8 attempts. Easy opens the game to players who mainly want to explore. Hard raises the stakes of death (see Economy).

### Unique Selling Points (USPs)

1. **Your skill is the light source.** "Light attracts monsters" already exists (*Last Light*, *Oshi*, *In The Shadows*), but making the combo itself the light, so mastery *is* the danger, does not.
2. **A pogo chain in a hand-built world.** Research found no pogo-chain game with a fixed, interconnected world; the genre is dominated by procedural runs (*Downwell*).
3. **Depth ≠ darkness.** Each layer has its own sky and palette; the chain-light is the one colour that never changes.

Positioning rule: lead with chain-as-light. Never market it as a "roguelike" or "Downwell-like".

---

## Goals and Context

### Project Goals

- **Creative:** a game that delivers *daring mastery* across 7 layers (8–12 h).
- **Commercial target:** **$15–20 premium** (research-advised). The full game needs 8–12 h: 7 layers at 45–60 min of spine, plus bosses and side areas, to justify the price. No marketing work before M2 (designer's call); the store and marketing plan is decided in E7.
- **Personal:** a passion and learning project. Solo, 5–10 h/week, no deadline. The full game likely takes 5 or more years, and that is accepted.
- **Milestone 2 (this GDD's immediate target):** a vertical slice. Layer 1 fully connected, a Lift Station, the first hub NPCs, the Weaver boss and Flare Toss. It is the first build to share, and the Steam vs itch.io decision is made with it.

### Background and Rationale

- **M1 (done 2026-11-10):** one shaft asked "does a long chain feel both tempting and dangerous?" The verdict was **yes**, after three playtest fixes:
  - the chain had to *pay* (embers);
  - escapes had to always work;
  - wall cling had to exist where no ledge is in reach.
- Record: `_bmad-output/implementation-artifacts/m1-playtest-findings.md`.
- Where this GDD and the game brief (2026-11-08) differ, the M1 findings win.

---

## Core Gameplay

### Game Pillars

In priority order. When two conflict, the higher one wins unless a ruling says otherwise.

1. **Chain = Light = Danger.** Chaining hits without landing makes you stronger, brighter, richer and hunted. Every feature must feed this tension or at least not weaken it. *This pillar survives any cut.*
2. **Every death teaches.** Failure is fair and readable. Predators always telegraph (a sound, eyes in the dark, a glow at the screen edge). An escape taken in time (landing, Snuff, cling) always works. Darkness creates tension, not confusion. *Ruling: this pillar beats off-screen ambushes.*
3. **Knowledge is power.** The abyss is fixed and hand-built, with no procedural generation. You progress by gaining skills, not XP. Knowing the world tells you *where* to be daring; it never replaces daring. *Ruling: key gates and shortcuts open only with a long chain.*
4. **Few buttons, deep play.** Movement plus 4 buttons (Attack, Jump, Dash, Light). The same 4 buttons all game: each layer changes how the verbs are used, and new abilities reuse the same buttons (Swing is a hold on Dash).

### Core Gameplay Loop

**Moment to moment: *burn bright → cash out → hide → burn again.***

1. Drop into a shaft.
2. Pogo off enemies and hazards to build the chain. You grow brighter, stronger and carry more held embers.
3. Your light draws predators. Their eyes open in the dark: a telegraph of at least 0.75 s.
4. Decide when to cash out. Each way out ends or pauses the chain:
   - **Land:** breaks the chain and banks embers.
   - **Wall cling:** pauses the chain and hides the light, for 1 s per chain.
   - **Snuff:** goes dark, breaks the chain and banks embers.
   - **Flare Toss:** spends part of the chain to lure predators away (M2).
5. Recover, then dive again.

*Why the hundredth loop:* each extra link pays more than the last, so "one more hit" is always tempting, and the predators make it always costly.

**Session:** leave a Lift Station → push into the layer → find routes, secrets and chain gates → reach the next Lift Station, or die and learn → return to the hub to spend your haul.

### Win/Loss Conditions

- **Win (full game):** reach The Bottom (Layer 7) and finish **The Final Chain**, a playable, unbroken descent with your light at full strength. **M2 win:** defeat the Weaver and gain Swing.
- **Loss:** none permanent. Death costs held embers, carried embers (dropped as a cache) and the distance back from the last lantern anchor. World progress (opened gates, repaired stations, abilities, deposited embers, map reveals, journal entries, defeated bosses) is never lost. *This is not a roguelike.*
- **Per dive:** success is reaching the next Lift Station or home with your embers. Failure is a death that the Field Journal explains (Pillar 2).

---

## Game Mechanics

### Primary Mechanics

All values are at 480×270, 1 tile = 16 px. Values marked **M1** were playtested; the rest are starting values to tune.

The HUD sits in two side gutters of about 60 px each, so the visible play area is about 360 px wide (UX, 2026-11-10). See Level Design Framework.

#### Movement (M1)

| Parameter | Value |
|---|---|
| Run speed | 110 px/s; ground accel 900 px/s², air accel 1500 px/s² |
| Jump | −330 px/s, apex ≈ 60 px (3.75 tiles); release early = velocity ×0.45 |
| Gravity | 900 px/s² rising; ×0.6 falling; max fall 210 px/s |
| Coyote time / jump buffer | 0.08 s / 0.10 s |
| Air dash | 260 px/s for 0.15 s (9 ticks, ≈ 39 px; the last tick already falls), horizontal, ignores gravity. Once per airtime; refreshed by landing or a pogo hit. *CP1 gate, 2026-11-21:* the felt dash is kept (was written as 0.12 s / ≈ 31 px; M1 always ran 9 ticks) |
| Camera | leads 70 px downward while falling |

#### Attack, pogo and chain (M1)

- **Slash** (Attack on the ground): active 0.12 s, cooldown 0.22 s.
- **Pogo** (Attack in the air, any direction held): a downward strike, armed 0.22 s, hitbox 26×24 px below the feet.
  - A hit bounces you up at −300 px/s (apex ≈ 50 px) and adds **1 link**.
  - Each hit freezes the game for a 75 ms hitstop.
  - A pogo landing on the same frame you touch the ground adds nothing.
- **Boxes (M1):**
  - Player body: 10×20 px.
  - Player hurtbox: 8×18 px, smaller than the body, so grazes don't count.
  - Slash hitbox: 22×16 px, in front.
  - Pogo hitbox: 26×24 px, below the feet.
  - Blade Bloom scales both hitboxes, never the hurtbox.
- **Chain:** +1 link per pogo hit without touching the ground, capped at 20 links.
  - **Chain-Light radius** = 40 + 22·√links px, so 40 px at 0 links, 84 at 4, 110 at 10 and 138 at 20.
  - **Blade Bloom:** the slash and pogo hitboxes scale ×(1 + 0.18·√links), up to ×1.8.
  - **Embers:** see Economy.
- **What ends or pauses a chain:**

| Action | Chain | Held embers | Light |
|---|---|---|---|
| Landing | breaks | → carried | → 40 px |
| Snuff (hold Light past the tap window; default 0.12 s) | breaks | → carried | → 12 px while held |
| Wall cling | **paused**, 1.0 s per chain (a pogo hit refills it), then breaks | kept, then → carried | → 40 px while clinging |
| Any hit (crawler, spiderling, boss, lurker, spikes) | breaks | → carried | → 40 px |
| Flare Toss | −half (see below) | share → carried | shrinks to the new chain |
| Crossing a room exit (backstop; architecture ADR-2) | breaks, exactly like a landing | → carried | → 40 px |
| Death | breaks | **lost** | n/a |

The room-exit row is a runtime backstop: level design places exits behind a landing (no exit inside a chain run, bot-checked), so it should rarely fire. The Fall is the one scripted exception that keeps the chain across rooms.

*Why Snuff is a button despite the research's "no hide button" advice:* *Last Light* testers found a light toggle on top of platforming overwhelming. Snuff is not a toggle you leave on: it **ends your chain**, so it works as a cash-out. The light stays automatic; Snuff is only an emergency exit (the brief's decision log also kept it). Two things to watch in playtests: whether tap vs hold on Light feels overwhelming mid-chain (E1), and whether an instant mid-air Snuff becomes a free bank every time a telegraph starts (see Risks).

#### Wall cling (M1)

- **Start:** hold Jump while touching a side wall and falling (vertical speed ≥ 0).
- **While clinging:** you slide down at 18 px/s. Clinging never climbs; climbing is a later earned upgrade.
- **Release Jump:** kicks you off at (150 away, −260 up) px/s, with no steering for 0.15 s.
- **Down:** drops you straight off the wall.

#### Flare Toss (M2)

- **Input:** tap Light (released inside the Light tap window, the Snuff threshold). The window is a player setting: 0.12 s (default), 0.2 s or 0.3 s (UX, 2026-11-11).
- **Requirement:** at least 2 links.
- **Cost:** half the chain, rounded up. Example: 8 → 4, 5 → 2.
  - Held embers move to carried in proportion to the links spent.
  - The remaining chain keeps going.
- **Throw:** an arc in the facing direction, 180 px/s forward and −160 px/s up, under normal gravity. It sticks to the first surface it hits.
- **The flare:** burns for **4.0 s** with a radius equal to your light radius *before* the toss.
  - Predators that can sense the flare treat it as the player: lurkers telegraph and hunt it.
  - **Exception:** the light-shy Weaver is *repelled* by a flare and flees from it (see Combat System).
  - In its last 1.0 s it fades out smoothly, with no flashing.

#### Swing (M2, unlocked by Weaver Silk)

- **Input:** press Dash within 56 px of a **silk anchor** (a placed level object, visible at base light) to grab the rope. Hold Dash to stay on. Out of range, Dash is the normal air dash.
- **The rope:** attaches at its current distance, clamped to 32–96 px. You swing like a pendulum, with left/right adding pump.
- **Release Dash:** launches you with your current velocity ×1.1.
- **Chain:** swinging does not touch the ground, so the chain continues. You stay bright, so predators keep hunting you. Swinging buys position, not safety.
- **Gating:** 3 silk anchors in Layer 1 (in A, S2 and C) each guard one secret that opens only with Swing (see Ability-Gating).

#### Health and damage (M2; replaces M1's one-touch death)

| Source | Damage | Notes |
|---|---|---|
| Crawler contact | 1 | knockback (150 px/s, −150 px/s), 0.6 s invulnerable (blinking at 2.5 Hz), chain breaks |
| Boss attack | 1 | |
| Hunting lurker | 2 | only while it hunts; idle or returning lurkers are harmless; it loses you the moment it can't sense you |
| Spikes and hazards | 1 | respawn at the last safe ledge in the same room; while invulnerable, no damage, still returned (sonlm, 2026-11-22) |

- **Any hit** breaks the chain and moves held embers to carried. Only death loses held embers: pain costs health, not embers.
- **Health:** 4 HP. Masks to raise the maximum are Layer 2+ exploration rewards and out of scope for M2.
- **Healing:** full at a Lift Station; +1 HP when you bank a chain of 10 or more (the threshold is `Tuning` `bank_heal_min`). [ASSUMPTION: the bank-heal threshold needs a playtest.]
- **0 HP:** death. You respawn at the last lit lantern anchor or Lift Station with full HP, and embers follow the Economy rules.

#### Predators: Lurker (M1)

- **Wakes:** when your light radius is ≥ 80 px (4 links), it is within radius × 1.6 of you, and it is **on screen**.
- **Stirs (off screen):** if it would wake but sits just off screen (within 96 px of the edge), you hear a quiet stirring panned to that side. At the play-area edge, level with the lurker, a half-open eye appears and opens wider as it stirs, with a red glow that has a minimum strength. A faint glow alone is not enough (UX, 2026-11-11). It can't hunt until it is on screen and has telegraphed. You are warned, never ambushed (Pillar 2: *hear it before you see it*).
- **Telegraph:** 0.9 s (never below 0.75 s). Its eyes open with an animation and pulse at 2 Hz, cast red light on the wall. Both HUD gutters show a pulsing red frame (≤ 2 Hz) and a small eye icon. HUD values are not recoloured (UX, 2026-11-11).
- **Hunt:** 95 px/s straight at you, passing through walls. It **senses** you while your light radius is ≥ 80 px and you are within radius × 1.6. Once it can't sense you, it stops at once and is harmless, waits 0.6 s, then returns home.
- **Retargeting:** if a lurker hunting a flare or the Ember Cache switches to you, it telegraphs again from the start (≥ 0.75 s) before it can hurt you. Every hunt of the player is telegraphed (Pillar 2). Switching from you to a flare needs no telegraph.

### Controls and Input

Keyboard and gamepad, both from M2. Every action is a single button (no chords). Default gamepad: left stick/d-pad = move, A = jump, X = attack, RB = dash, B = light (tap: Flare Toss, hold: Snuff), Start = pause.

| Action | Default key | Tap | Hold |
|---|---|---|---|
| Move | Arrow keys | Run. ↓ drops off a wall. **↓ on the ground: interact** (rest at a station, talk, read) | — |
| Jump | Z or ↑ | Jump (hold for full height) | At a wall while falling: **cling**; release to **kick off** |
| Attack | X | Ground: slash. Air: **pogo** | — |
| Dash | C | Air dash; within 56 px of a silk anchor: **grab** the rope (after the Weaver) | Stay on the rope: **swing** |
| Light | V | **Flare Toss** (released inside the tap window; default 0.12 s) | **Snuff** (held past the tap window) |
| Pause | Esc or P | Open the Pause menu. P is the web fallback, since Esc can leave browser fullscreen | — |

- **Options rollout** (UX, 2026-11-10/11). A small Options screen ships from E1, opened from the Pause menu, and grows by epic. Tabs that have not landed are hidden.
  - **E1, Game:** difficulty, changeable any time.
  - **E1, Accessibility:** reduce flashing; screen shake on/off; reduced motion (follows the OS setting on web); Light tap window (0.12 / 0.2 / 0.3 s); hold→press toggles for Cling and Snuff; Brightness (4 levels), which replaces the M1 F1 brightness hotkey that E1 removes (decided 2026-11-12). Snuff toggle: when On, Light only throws Flare Tosses (any press, no tap window) and Snuff moves to its own key (default Shift; pad LB), pressed once to start and again to end. Snuff still ends the chain, so this is not a light you leave on. Quick Wick has no extra effect in this mode.
  - **E3, Audio:** volume sliders.
  - **E7:** Video (Brightness, moved here from Accessibility; fullscreen; scale); Controls (rebinding); large HUD, text scale, timing assists and visual sound cues.
- **Rebinding:** every action, keyboard and gamepad, can be rebound in Options > Controls (E7).

---

## Metroidvania Specific Design

*Action-platformer feel conventions (the movement-feel table, hit/hurt boxes, coyote time and buffers, checkpoint cadence) are covered under Game Mechanics.*

### Interconnected World Map

**Structure (whole game):** the hub (Abyss Island) sits above one pit with 7 stacked layers. A layer is a **spine**, the main descent shaft, with **side branches** at depth. Layers connect only downward through their boss and upward through Lift Stations.

**Base rule: the ground is a sanctuary.** Landing ends the chain and puts you out of reach of light-hunters. Each layer can twist one rule; Freezing Magma flips this one, because light is warmth there and going dark costs you.

| # | Layer | Rule twist | Boss | Lesson |
|---|---|---|---|---|
| 1 | Edge of the Abyss | the tutorial; the daylight fades as you descend | Weaver | restraint |
| 2 | Bright Moon | predators always see you up close; there is a force field [open] | Moon-Eyed Stalker | [open; brainstorm: spacing] |
| 3 | Inverted Trees | [open] | Rootmother | [open; brainstorm: the environment as a weapon] |
| 4 | Great Mountain | [open] | Mountain-That-Walks | [open; brainstorm: endurance and flow] |
| 5 | Whirlstorm Hell | flares are carried far | Eye of the Storm | [open; brainstorm: companions and patience] |
| 6 | Freezing Magma | light is warmth: the sanctuary rule flips | Hollow Furnace | commitment (the counterpart to the Weaver's restraint) |
| 7 | The Bottom | everything | The Last Explorer | a mirror fight |

*"Layer 7 for now":* the game could be extended later.

**Layer 1: Edge of the Abyss** (M2 scope)
- Near the surface: scaffolds, ropes, the last daylight. It is the tutorial layer.
- **Size:** about 23 screens of spine plus 3 side areas (1 screen = 30×17 tiles).
- **First playthrough:** 45–60 min to the Weaver. This runs over the brief's 20–45 min session target, so quitting at an anchor saves your position. Later dives using the gate-2 shortcut fit one session.

| Segment | Screens | Teaches / tests | Contents |
|---|---|---|---|
| **S1 The Lip** | 0–3 | run, jump, slash, first pogo over safety nets; landing banks embers | ◆ **Lip Station** (lift to the hub); no lurkers |
| **S2 Scaffold Drop** | 4–9 | first lurker, with its eyes opening right above a ledge (the cash-out lesson); **wall cling** in a narrow stretch with no ledges; **Flare Toss** taught in a lurker pocket | branch to **[A] Rope Works**; ⟡ 1 Swing secret |
| **S3 The Lantern Door** | 10–12 | **chain gate 1 (≥ 4 links)** on the main path; a row of hoverers above it teaches the run-up | |
| **S4 Explorers' Grave** | 13–18 | lurker rooms that test Flare Toss and cling under pressure; ***The Last Entry***: Oda's camp, whose cold lantern is a lantern anchor you relight | branches to **[B] Old Mine** and **[C] Sky Ledge** |
| **S5 Weaver's Hollow** | 19–22 | the restraint lesson begins: the Weaver is heard and glimpsed before the arena | ◆ **Hollow Station** before the arena; ☠ **Weaver** |
| **Layer 2 landing arena** | 1 | Weaver phase 2 under the Bright Moon sky | ◆ broken station, repaired free on victory |

**Side areas (all optional):**

| Area | Off | Theme | Rewards |
|---|---|---|---|
| **[A] Rope Works** | S2 | an old rope yard | Ember Hoard (≈ 60), 2 journal entries, ⟡ 1 Swing secret |
| **[B] Old Mine** | S4 | dark galleries with ≥ 1 lurker per screen | Ember Hoard (≈ 80), 1 Cartographer hint, 1 journal entry |
| **[C] Sky Ledge** | S4 | an open cliff under daylight | behind **chain gate 2 (≥ 8 links)**: a **shortcut** back up to the hub, the only safe deposit mid-layer; Ember Hoard (≈ 100); ⟡ 1 Swing secret |

**Respawn and rest points:**

| Point | Count in Layer 1 | Respawn | Heals | Deposits embers | Fast travel |
|---|---|---|---|---|---|
| **Lantern anchor** | 1 every 4–6 screens (about 5); lit by touch | ✓ | — | — | — |
| **Lift Station** | 2 (Lip, Hollow), plus 1 in the landing arena | ✓ | full | ✓ | ✓ between repaired stations and the hub |

- You respawn at the last lit anchor or station, whichever is deeper, with full HP. Carried embers drop where you died (see Economy).

**Map:**
- The map fills in screens as you visit them.
- The Cartographer's Layer 1 map (60 embers) also reveals unvisited screens, gate locations and secret markers.
- Lift Stations and lit anchors are always shown.

#### Hub: Abyss Island (M2)

A small walkable village around the mouth of the pit. It is **2 screens wide**, on flat ground with no platforming, enemies or chain. It is where you come home, deposit, shop and read the story. Daylight and a warm palette set it against the dark below.

```
[Smith]  [Cartographer]   (LIFT)   [Naturalist]  [Guild + Memorial Wall]  [Oda's house]
==========================================================================
                               pit below
```

| NPC | Sells / does | M2 contents |
|---|---|---|
| **Cartographer** | maps and hints | Layer 1 map (60); 3 hints (25 each) that point to a side area, gate 2 and a Swing secret |
| **Smith** | gear that **bends a rule** (always on; no slots or charms) | **Quick Wick:** instant Snuff. The light starts dimming the moment Light is pressed; if Light is released inside the tap window, the press becomes a Flare Toss as usual. The tap window itself does not change (200). **Long Wick:** flare burns 4 → 6 s (250). **Steady Grip:** cling slide 18 → 10 px/s (300). Silk Grip (+0.25 s cling grace) is found in a Swing secret, not sold |
| **Naturalist** | reads journal entries | **copies** each new entry and pays **10 embers** for the copy (originals stay with you); sells 2 cosmetic palettes (75, 150) |
| **Guild + Memorial Wall** | records and story, no shop | records: deepest depth, best chain, most embers banked in one chain, deaths. The Memorial Wall lists lost explorers' names, Oda Vell (the Last Explorer) among them; the Layer 1 Memorial clue (a Swing secret, E6) is the Guild tag of **Oda's dive partner**, which adds the partner's name to the Wall (narrative, 2026-11-12) |

- **Oda's house** (narrative, 2026-11-12): a small interior beside the Guild where Glim lives — bed, Oda's empty chair, her gear wall, where found pages of her journal are pinned as flag-gated props. Props and lines only; **not** a save or rest point. A new game opens here (from E5; until the hub exists, New Game starts in S1).
- **The lift** links the hub to every repaired Lift Station (fast travel).
- **Arrival:** arriving home **deposits all carried embers** and heals you fully.

#### Lift Station

- **Touch:** lights the station, which becomes your respawn point.
- **Press ↓ (interact) to rest.** Resting:
  - heals you fully;
  - **deposits** carried embers (safe forever);
  - opens the fast-travel menu (hub and repaired stations);
  - **respawns the layer's enemies**, so you get chain fuel back but the threats return too.
- **Leaving by lift:** riding a lift up plays **The Watching Departure**, where creatures gather at the edge of your light to watch you go (brainstorm). The ride up has a **fixed duration** that covers the full gathering, so it never adds time. The full gathering plays once per station layer, and only after you have met a lurker; later rides show a few eyes. Fast travel down or sideways has none (narrative, 2026-11-12).
- **Interact key:** ↓ while standing still on the ground also talks to NPCs and reads journal objects. ↑ stays Jump.

### Ability-Gating System

Pillar 3: progress through skills and chain mastery, never XP.

| Gate | Type | Needs | Opens |
|---|---|---|---|
| Chain gate 1 (S3) | hard, on the main path | arriving with a chain of ≥ 4 | the way to S4 |
| Chain gate 2 (Sky Ledge) | hard, optional | arriving with a chain of ≥ 8 | the shortcut to the hub |
| Silk anchors (×3) | ability gate, optional | Swing (Weaver Silk) | the secrets in A, S2 and C |
| Layer 2 descent | story gate | out of scope for M2 | sealed |

- **Chain gate rule:** a lantern door reads your chain when you touch it. If it is high enough, the door opens for good. If not, it stays shut, glows the required number and bounces you off; your chain is not broken.
- **Starting kit:** move, jump, slash, pogo, air dash, Snuff, wall cling and Flare Toss. Swing is the only ability unlocked in M2.

### Backtracking Design

- **After the Weaver:** the free landing-arena station returns you to the hub. From there, the Lip Station puts you back at the top of Layer 1. Descend to collect the **3 Swing secrets** (S2, A, C), then take the gate-2 shortcut or the Hollow Station home.
- **Fast travel:** between the hub and every repaired Lift Station. There is no fast travel to lantern anchors.
- **Enemies** respawn when you rest at a station or leave the layer. Chain fuel must always be there.
- **Changed world:** opened gates and repaired stations stay that way for good. World progress is never lost (brainstorm #23).

### Exploration Rewards

| Reward | Layer 1 count | Where |
|---|---|---|
| Ember Hoards | 4 | A, B, C, a Swing secret |
| Journal entries | 3 | A ×2, B |
| Cartographer hint | 1 | B |
| Gear: Silk Grip (+0.25 s cling grace) | 1 | Swing secret |
| Memorial clue (the Last Explorer) | 1 | Swing secret |

- **Completion:** the map screen shows how many of each have been found per layer. No overall percentage in M2.

### Combat System

**Attacks:**
- Slash (ground) and pogo (air), both scaled by Blade Bloom.
- No ranged attack. Flare Toss deals no damage.

**Defense:**
- Ways to end or pause the chain: landing and Snuff break it, cling pauses it, Flare Toss halves it (see the chain table).
- 0.6 s of invulnerability after a hit.
- No block or parry in M2. The lurker parry is a candidate for after M2.

**Enemies in Layer 1 (M2):**

| Enemy | Role | Behaviour | HP | Damage |
|---|---|---|---|---|
| Crawler (walker) | chain fuel | patrols a ledge and turns at edges | 1 | 1 (contact) |
| Crawler (hoverer) | chain fuel in open shafts | drifts 10 px side to side over 2.4 s | 1 | 1 (contact) |
| Lurker | light predator | see Game Mechanics | not killable in M2 | 2 (while hunting) |
| Spiderling | Weaver-fight fuel | drops from the Weaver while you are bright; falls slowly, then crawls | 1 | 1 |

[NOTE FOR DESIGNER: Layer 1 may need a third regular enemy, for example one that is only hittable from above or a hazard you can pogo, so mid-layer chains stay varied. Decide while walking Level Design.]

#### Boss: the Weaver (Layer 1)

**Lesson:** *restraint.* Chaining brute force fails here. You read the fight, then go dark, herd and strike.

**Arena:**
- A shaft section 30 tiles wide and 34 tall (two screens tall). It is wider than the ~360 px view, so the camera scrolls horizontally.
- **4 web strands** span it from wall to wall at different heights. Strands can be pogoed: each bounce adds 1 link and deals no damage.
- Each strand has an **anchor** on both ends. Slashing an anchor 2 times **weakens** that strand, shown by a frayed sprite and a sag.
- **HP:** 12. The Fall triggers at 6.
- **No health bar.** Health reads in the world: segments fray and fall off, and threads sag (UX, 2026-11-11).

**The loop (Snuff → Herd → Strike;** the brief's "Snuff, Lure, Strike", where going dark is the lure**):**

| Your state | Weaver does | Numbers |
|---|---|---|
| **Bright** (light ≥ 80 px) | retreats up to the ceiling anchor, out of reach; drops spiderlings | retreats at 120 px/s; 1 spiderling every 2.0 s, at most 3 alive |
| **Dark** (light ≤ 40 px: base, Snuff or cling) | descends toward you along the strands and bites | descends at 70 px/s; bite telegraph 0.9 s (legs rear up, eyes glow); bite deals 1 |
| **Strike: light burst** | if you reach chain 3 within 96 px of it, the sudden light **stuns** it | stun 2.5 s; your hits deal 1 each, at most 3 per stun |
| **Herd: flare** | flees the flare; flees along strands to the farthest point inside the flare's radius × 1.5. Any burning flare counts (no 80 px minimum), and a flare cancels a bite in telegraph (readiness, 2026-11-12) | flee speed 110 px/s |
| **Strand drop** | if it stands on a *weakened* strand and you slash the second anchor, the strand drops; with the Weaver elsewhere nothing drops, so strands can't be wasted (readiness, 2026-11-12) | 2 damage plus a stun of 2.5 s (hits during it count) |

**Phase events:**
- **The Re-Weave (at 9 HP):**
  - Over a 3.0 s telegraph (silk threads glow along the new paths), it rebuilds every strand in a new pattern.
  - Weakened strands are restored.
  - You are not harmed. Spiderlings keep dropping.
- **The Fall (at 6 HP):**
  - It cuts its anchors, and the arena floor of webs gives way.
  - About 6 s of **free fall** with debris and web clumps to pogo off: a bonus chain section that pays embers.
  - You land in the **Layer 2 landing arena**, under a new sky: Bright Moon palette, one screen.

**Phase 2 (6 → 0 HP, landing arena):** the Bright Moon rule ("predators always see you up close") is **off** in the landing arena. It first applies in Layer 2 proper, so going dark still lures the Weaver.

- **2 strands** only. Faster: bite telegraph 0.75 s (the minimum), descent 90 px/s.
- **Re-Weave at 3 HP:** rebuilds the 2 strands.
- **On defeat:**
  - It drops **Weaver Silk** (Swing unlocked).
  - A broken **Lift Station** in the landing arena is repaired for free and returns you to the hub.
  - The way down into Layer 2 stays sealed in M2.
  - **Presentation** (narrative, 2026-11-12): the defeat reads as a win first (slow-mo, a burst of light, the station repairing); then, as a coda, the Weaver dims and withdraws downward into the dark in sparks. Bosses are never shown dying.

**Death:** you respawn at the Lift Station before the arena, with full HP and the fight reset. If you died in phase 2, the fight resumes from **phase 2** in the landing arena, so you never replay a phase you've beaten.

### Sequence Breaking

- **Stance:** a skip is allowed if it takes skill and leaves the game finishable. Chain gates can't be skipped: they read the chain.
- **Known skips to allow:** a cling-kick plus air dash can reach the [A] Rope Works and [B] Old Mine entrances early. That's fine, since they're optional.
- **Softlock prevention:**
  - Layer 1 is a one-way descent between stations, so every drop leads on to the Weaver or a station.
  - Gate 2's shortcut goes up to the hub only.
  - The Weaver arena can't be left mid-fight, but it can always be won with the starting kit; Flare Toss is optional there.
  - Every pit of hazards has a ledge or wall to cling to within a 210 px/s fall of 1.5 s.

---

## Progression and Balance

### Player Progression

Three tracks, none of them XP (Pillar 3):

| Track | What grows | How it feeds the loop | M2 |
|---|---|---|---|
| **Skill** | your chain length, reading telegraphs, cash-out timing | the main track: longer chains pay quadratically more embers | a best-chain record at the Guild |
| **Abilities** | new uses of the 4 buttons, earned from bosses or world finds | each one reopens earlier layers (backtracking) | Swing (from the Weaver) |
| **Gear** | small rule-bends bought with embers | each bend moves a number the player already knows | 3 sold, 1 found |

- **Out of scope for M2:** raising max HP (masks), more ability unlocks, and Mentor techniques (from the brainstorm: retired explorers who teach techniques).

### Difficulty Curve

**Within a layer: teach safe → test committed.**
- Each new move first appears with a safe exit in view: a ledge under the first lurker, a short cling stretch.
- 2–4 screens later it is tested where you must commit.

**Layer 1 target struggle points:**
- **Gate 1 (chain 4):** most players need 1–3 tries.
- **Old Mine (optional):** ≥ 1 lurker per screen.
- **The Weaver:** Normal difficulty, *Hollow Knight*-level; most players need 3–8 attempts.

**Layer 1 coast points:** S1, the hub, and every Lift Station approach.

**Across layers:** each layer twists a rule (depth ≠ darkness) rather than raising the numbers. Layer 2 is Bright Moon, where predators always see you up close. Freezing Magma flips the sanctuary rule: light is warmth.

**Difficulty settings:** Easy, Normal and Hard change *only* what death costs you (see Economy). They never change damage, telegraph times or chain rules, so every player learns the same game. Difficulty is chosen at New Game and can be changed any time in Options.

**Timing assists are separate settings, not difficulty** (UX, 2026-11-10). Game speed and timing assists live in Options > Accessibility (E7). They never change the difficulty rule above. Runs that use them are kept out of Guild records.

[ASSUMPTION: attempt counts are targets to check in the M2 playtest, not measurements.]

### Economy and Resources

**Embers are the one currency.** They replace the brief's "haul" and "currency".

**Earning:** each pogo hit pays embers equal to its link number: link *k* pays *k*, so a chain of *n* pays n(n+1)/2. A chain of 5 pays 15 and a chain of 10 pays 55.
- The cap at 20 links stops the light from growing, but hits keep paying.
- This curve is the temptation lever. M1 confirmed it works ("Yes, I want to keep the chain going").

**Three risk stages (Normal difficulty):**

| Stage | How embers get here | On death |
|---|---|---|
| **Held** | Pogo hits on the current chain | **Lost** |
| **Carried** | The chain ends safely (landing, Snuff, cling timeout, a crawler knock) | **Dropped** as an Ember Cache where you died. Touch it to recover it. If you die again before then, the cache is gone. The cache glows amber and **draws nearby lurkers**, so recovering it is a risk (Pillar 1). |
| **Deposited** | Rest at a Lift Station, or return to the hub | **Safe forever** |

*Why three stages:* held embers make "one more hit" costly (Pillar 1). Carried embers make "can I reach the next station?" a real choice between stations (the session loop). A death always leaves a way back (Pillar 2).

**Difficulty tiers:**

| Tier | Held on death | Carried on death |
|---|---|---|
| Easy | moved to carried (nothing lost) | kept |
| Normal | lost | dropped (recoverable once) |
| Hard | lost | lost |

**Sinks** (all at the hub, one NPC per sink):

| Sink | NPC | What it buys | Pillar |
|---|---|---|---|
| Maps and hints | Cartographer | layer maps, secret and gate hints | 3: you buy *where* to be daring |
| Lift Station repairs | Guild | restores deeper stations as shortcuts and fast travel. **Layer 2 onward:** Layer 1 has no broken station in M2 | session loop |
| Gear | Smith | small upgrades that *bend* chain rules (e.g. Quick Wick, Long Wick, Steady Grip; see Hub). **Rule: gear bends a rule, it never adds raw power.** | 1, within 3's "skills, not XP" |
| Cosmetics | Naturalist | cosmetic palettes. The Naturalist also *pays* 10 embers per new journal entry, a small source of embers rather than a sink | none: a safe sink |

**Starting prices** (to tune in the M2 playtest):

| Item | Price |
|---|---|
| Map | 60 |
| Hint | 25 |
| Station repair | 150 |
| Gear | 200–300 (M2 items) |
| Cosmetic | 75–150 |

[ASSUMPTION: a Layer 1 dive between stations earns about 100–250 embers for a competent player. M2 playtests set the real prices.]

**Ember Cache glow** (decided in UX, 2026-11-10; was a designer note). The dropped cache glows like a small light and draws nearby lurkers, so recovering it is itself a daring move (Pillar 1). The cache wakes lurkers by the same rule as your light: its glow radius must be **≥ 80 px**, and the lurker must be within radius × 1.6 and on screen (architecture, 2026-11-11). [ASSUMPTION: the glow radius itself is tuned in the E1 playtest; below 80 px the cache draws nothing.]

---

## Level Design Framework

### Level Types

| Type | Purpose | Rules |
|---|---|---|
| **Spine shaft** | the main descent; 22 tiles (352 px) wall to wall, side walls included, so both walls stay in view for cling; so it fits the ~360 px view with no sideways scrolling; hoverers in rows with left/right choices; ledges every ≤ 1.5 s of fall; lurkers set in the walls |
| **Narrow stretch** | the cling lesson | 6–10 tiles wide; no ledges; walls always within reach |
| **Gate room** | chain gate | a run-up of hoverers placed so the required chain is reachable on the first try with plain movement (no dash) |
| **Side area** | exploration and rewards | optional; may hold dense lurkers (Old Mine); always ends in a reward |
| **Station room** | rest | no enemies within 2 screens; a lit lantern visible from the shaft above |
| **Boss arena** | lesson test | one-way in; built by the boss (Weaver strands) |
| **Hub** | home | no enemies, no chain, no platforming |

**Framing for the gutters** (UX, 2026-11-10). The side gutters leave about 360 px (22.5 tiles) of visible width. Rooms are framed for 360 px; wider rooms scroll horizontally. The M1 shaft was built for a 480 px view, so the camera and room widths must account for the gutters. Spine shafts are 22 tiles (352 px) wide wall to wall, side walls included, and never scroll sideways. The Weaver arena stays 30 tiles (480 px) wide and scrolls horizontally with the camera.

### Level Progression

- **Order:** Layer 1 runs in a fixed order: S1 → S2 (A) → S3 gate 1 → S4 (B, C) → S5 Weaver → Layer 2 landing arena.
- **Rhythm:** a new idea every 4–6 screens, and a lantern anchor at about the same rate.
- **Hard rule from M1:** every lurker telegraph must be on screen, and every predator-heavy stretch must have an escape (a ledge, a wall to cling to, or room to Snuff) within reach.
- **Level validation:** an automated bot must reach a chain of ≥ 5 in every spine shaft and the required chain at every gate, using plain movement and no dash. M1 already runs this test. M2 keeps this check in the automated suite for every room and gate.

---

## Art and Audio Direction

### Art Style

**Format:**
- 480×270 at integer scale.
- Sprites of 16–24 px; bosses are built from segments.
- Each palette zone has **4 colours**, plus the 2 reserved colours. Sprites are text pixel grids fed to the M1 pipeline.
- **HUD:** two side gutters of about 60 px, tinted from the zone palette; the play area between them is about 360 px wide. Layout and colours: UX `DESIGN.md`.
- **UI font:** Fusion Pixel Font 8px, proportional (latin build), OFL 1.1, on an 8 px grid (UX, 2026-11-11). Ship its licence files with the game.

**Two reserved colours, used the same in every layer:**

| Colour | Hex | Means | Rule |
|---|---|---|---|
| **Chain-light amber** | `#ffd27a` | *you*: light, embers, the flare, chain popups; in menus, the selection cursor (menu light is your lantern, UX 2026-11-10). In-world, ember lanterns burn amber only in the hub and on lantern anchors; old lamps in the layers are dead or a cold tint. Hit creatures burst into sparks in their own tint that turn amber as they fade (narrative, 2026-11-12) | never used for anything else |
| **Predator red** | `#d9473f` | *danger that hunts by light*: lurker eyes, telegraphs, the HUD alert frame and eye | never used for anything else |

- **Colour-blind safety:** every telegraph also has a shape and motion cue (eyes opening, a pulse, a shiver) and a sound. Colour is never the only signal.

**Layer 1: the daylight fades as you descend.** The palette shifts down the spine, so depth shows on screen and the amber light stands out more the deeper you go.

| Zone | Mood | Palette (dark → light) |
|---|---|---|
| S1 The Lip, A | last dusk; scaffolds and rope | `#2b1d14` `#6b4a2f` `#b08a5a` `#d8c3a0` |
| S2–S3 | muted umber | `#1e1714` `#4a3a33` `#7d6a5c` `#a99a8c` |
| S4–S5, B, C | cold violet (the M1 palette) | `#0d0b14` `#2a2440` `#4f5d75` `#a9b4c2` |
| Layer 2 landing (Bright Moon) | silver moonlight | [ASSUMPTION: to design with Layer 2; a cool silver-blue] |
| Hub, Abyss Island | warm daylight, home | [ASSUMPTION: to design; bright, warm, low contrast] |

**Readability rules (from M1):**
- Ledge rims glow faintly.
- Predators and the effects of your light ignore the darkness, so they always read.
- The world gets darker; the player never loses track of themselves.

**Feel rules (addendum):**
- Freeze frames and sparks on every pogo hit.
- **Slow motion only at boss climaxes:** The Fall begins with 0.5 s at ×0.3, and so does the Weaver's defeat.
- Screen shake can be turned off.
- Creature deaths dissolve into sparks, never blood (keeps age ratings low).

### Audio and Music

**Style: organic world, synthetic light.**
- The world sounds physical: creaking rope, wind, dripping, wood and stone.
- Everything that belongs to *your light* (the chain, embers, flares) uses soft synth tones, so you can hear the difference between you and the abyss.

**Chain-reactive music.** At rest in a layer, only the ambient soundscape plays. The chain then adds music:

| Chain | Music layer fades in (0.5 s) |
|---|---|
| 3 links | a soft pulse |
| 6 links | a melody |
| 10 links | the full layer theme |

- **When the chain breaks safely** (bank): the music resolves on a chord within 0.3 s.
- **On death:** it cuts with a muffled, dissonant tail.
- **Effect:** the music itself becomes the "one more hit" temptation (Pillar 1).
- **Own themes:** the hub, the Weaver fight and The Fall.

**Key sound effects:**

| Event | Sound | Rule |
|---|---|---|
| Pogo hit | a soft synth strike | **pitch rises one semitone per link**, up to +12 at 12 links (the brief's chain-pitch crescendo) |
| Embers banked | a chime | grows longer with the amount |
| Lurker telegraph | a low breath or growl as the eyes open, panned to its side | **always mixed above the music** (music ducks by 6 dB); Pillar 2 needs a sound telegraph |
| Hunting lurker | a rising hiss that follows its position | |
| Snuff | the light blown out, then muffled silence | |
| Cling | rope or wood creak | |
| Flare Toss | whoosh, then a sizzle while it burns | |
| Weaver | strands twang; a hiss when the light makes it retreat | |
| Chain gate | a resonant tone that **rises to the required count** and opens with a chord, or a dull thud if the chain is too short | |

**Production:**
- **Sound effects:** a script pipeline. Text parameter files → Python → WAV, kept in git and built on the server, alongside the sprite pipeline.
- **Music:** composed on the laptop as **stems** (pulse, melody, full) per layer, so the game can bring them in with the chain.
- **Mix rules:** predator cues have the highest priority. No sound effect may come close to clipping during a 75 ms hitstop.

---

## Narrative and Tone

**Premise:** you aren't discovering the abyss; you're **coming home to it**.

**Tone:** the mood of layered-abyss adventure fiction: wonder, melancholy, danger at the edge of the light. **The world, creatures and story are original.** No names, creatures, places or plot beats are borrowed from any existing work.

**Three reveals at most** (brief): *origin, theft, cycle*. They land across the 7 layers. Layer 1 holds only **deniable early clues**: exactly three pointed clues in M2 — Old Tessaly's First Dive line, The Watching Departure, and Tessaly's "luck" line after the Weaver (brainstorm #103, #112: "deniable early, undeniable deep"; narrative, 2026-11-12).

**How the story is told:**
- mostly through the environment, the journal and the Memorial Wall;
- brief conversations with hub NPCs.

**Story reasons for systems:**
- **The Anchor** (brainstorm #111): a lantern binds your spark to the island, and death snaps you back to it. This is why lantern anchors and Lift Stations respawn you.
- **The Last Explorer** holds the island's all-time depth record, shown on the Guild board as the target to beat (#108).
- **Creatures** are hungry, not hateful: predators crave your light, they do not hate you (#109).
- **Embers** are scraps of the abyss's light: the island's coin and its fuel (lanterns, lift winches). Every pogo hit takes light from a creature — *you take too*. Depositing is, in-world, feeding the island.

**Cast (narrative, 2026-11-12):** **Glim**, the silent protagonist (never gendered); **Oda Vell** (she/her), the Last Explorer, who raised Glim; **Old Tessaly** (he/him), the Guild keeper.

**Ending:** *The Final Chain*, a playable, unbroken descent with your light at full strength.

**Layer 1 set-piece, *The Last Entry* (#56):** in S4 Explorers' Grave, Oda's unsigned camp and a half-written journal ("going deeper"). Her cold lantern is a lantern anchor you relight. It also counts as a journal entry.

**Narrative design:** `_bmad-output/narrative-design.md` (complete 2026-11-12) holds the full arc, reveal placement, characters, world, dialogue rules, the M2 clue budget, story flags and the content-by-epic map. It is the source of truth for all story text. No NPC or death-card lines are written until sonlm approves 3 voice-anchor lines per speaker.

---

## Technical Specifications

### Performance Requirements

- **60 FPS sustained** at 480×270 scaled ×3 (1440×810) on the developer laptop and on an Intel HD Graphics 620-class integrated GPU. Measured over a 10-minute Layer 1 run, including the Weaver fight.
- **Hitstop and input:** input is read every frame; no frame of input is dropped during a 75 ms hitstop.
- **Load time:** under 2 s from the hub to a Lift Station on the laptop.
- **Memory:** ≤ 512 MB RAM on desktop, ≤ 300 MB in a web tab.
- **Web build:** 60 FPS in desktop Chrome or Firefox on the laptop, at the 960×540 (×2) embed; download under 30 MB; playable within 10 s on a 50 Mbps link; pauses when the tab loses focus.

### Platform-Specific Details

- **Engine:** Godot 4.7 (GDScript only), with the Compatibility renderer so web builds work.
- **Targets:** PC Windows and Linux. Web/itch.io builds for playtests. The Steam vs itch.io decision is made with the M2 build.
- **Input:** keyboard and gamepad from M2 (default mapping in E1). Every action is one button (no chords). Rebinding arrives in M2.
- **Web baseline:** the itch.io embed is 960×540 (×2). If the window is still below ×2, the click-to-play gate suggests fullscreen (UX, 2026-11-11).
- **Steam Deck:** a Deck-size legibility check in E1 (passed with notes 2026-11-22, Story 1.18; the notes are deferred-work items for Stories 1.25, 1.26 and 1.29 and the M2 retrospective), done while choosing the font (UX, 2026-11-11); the full test pass in E7. At ×2 integer scaling (960×540, letterboxed) the HUD and text must be readable. "Verified" is the goal if Steam is chosen.
- **Display:** integer scaling only (×2, ×3, ×4), nearest filtering, letterboxed.
- **Saves:** automatic at every Lift Station rest, on the hub, and **when you quit at a lit lantern anchor**. Quitting at an anchor saves your position, so a long first descent can span two sessions. Carried embers stay at risk until a station. Progress moments (a difficulty change, a purchase, a story flag, the Weaver phase checkpoint and its defeat) also save world progress without moving where you wake (readiness, 2026-11-12). **3 save slots** (UX, 2026-11-10): the slot picker shows depth, best chain, play time and difficulty; Continue loads the most recent slot; Load on the title opens the picker. A failed save is shown to the player.
- **Flash safety:** no more than 3 flashes per second anywhere. A flash is a change in brightness: effects that only move or scale a sprite (the lurker's warning shiver, the pogo squash) are declared with the other effects but don't count against the cap. The hit flash shows at most once per second, so it and the 2.5 Hz blink stay within 3 flashes/s (sonlm, 2026-11-22). Settings include "reduce flashing", a screen-shake toggle, reduced motion and 4 brightness levels (see Options rollout in Controls and Input).

### Asset Requirements

**M2 sprite counts** (at 16–24 px):

| Asset | Count | Notes |
|---|---|---|
| Player | 1 set | 10 animations: idle, run, jump, fall, pogo, slash, dash, cling, swing, hurt |
| Enemies | crawler walker, crawler hoverer, lurker, spiderling | +1 if the third regular enemy is added |
| Weaver | 1 boss | built from segments: body, 8 legs, strands |
| NPCs | 4 | |
| Layer 1 tileset | 1 | with a ledge-rim variant |
| Layer 2 landing tileset | 1 | small |
| Hub tileset | 1 | |
| Objects | lantern anchor, Lift Station, chain gate, Ember Cache, flare, silk anchor | |

- **Pipeline:** text pixel grids → Python/Pillow → PNG, kept in git (the M1 pipeline). Layer palettes are swapped per layer.
- **AI-assisted art** is disclosed on store pages; its provenance is kept in git.
- **Audio:** see Audio and Music.

---

## Development Epics

### Epic Structure

**Milestone 2 (the vertical slice), in risk-first order.** As in M1, the riskiest design is proven before content is built on it. Each epic ends in something playable and one playtest question. Details: `epics.md`.

| # | Epic | Playable deliverable | Playtest question | Size |
|---|---|---|---|---|
| E1 | Kit v2 | the M1 shaft with the full M2 move set | Do HP, Flare Toss and lantern anchors keep deaths fair? | L |
| E2 | Weaver prototype | a rough Weaver fight in a test arena | Is the restraint fight (dark → herd → strike) fun? | M |
| E3 | Audio | the shaft with SFX and chain-reactive music | Does sound make the pogo feel great and telegraphs readable? | M |
| E4 | Layer 1 world | Layer 1 from the Lip to the Weaver's door | Do players learn each move, and want gates and side areas? | L |
| E5 | Hub | dive → home → spend | Do the three ember stages and the shops make diving home feel worth it? | L |
| E6 | Weaver final | the complete slice | Does the Weaver teach restraint? Does Swing make backtracking rewarding? | L |
| E7 | Slice polish and ship | the first shared build (web plus desktop) | Pillar metrics (see Success Metrics) with about 5 testers | M |

**Sequence:** E1 → E2 → E3 → E4 → E5 → E6 → E7. E3 can run alongside E4 if motivation calls for it.

**Dependencies:** E1 → every epic · E2 → E3 (the Weaver sounds and the test-arena theme) and E6 · E4 → E5, E6 · E5 → E6 · E1–E6 → E7. E3 blocks nothing before E7, so it can interleave with E4, and an E3 "no" becomes fix work at the head of E7's music.

**Rule:** a playtest "no" blocks only the epics that build on that answer (see Dependencies). Its fix becomes the first story of the next dependent epic; independent epics may proceed.

[ASSUMPTION: size S ≈ 2–4 weeks, M ≈ 4–8 weeks, L ≈ 8–16 weeks at 5–10 h/week. With four L epics and three M, that puts M2 at roughly 44–88 weeks (about 10–20 months). No epic is size S.]

---

## Success Metrics

### Technical Metrics

- 60 FPS sustained (see Performance): no frame over 20 ms outside the intentional 75 ms hitstop, measured in the 10-minute run.
- Zero softlocks in M2, checked by the reachability bot and the playtest.
- Automated tests stay green on every commit: chain rules, gate reachability, lurker escape rules (M1 suite).

### Gameplay Metrics

Solo project, so these come from playtest notes, not telemetry. For the M2 shared build (about 5 testers):

| Pillar | What shows it works | Target |
|---|---|---|
| 1. Chain = Light = Danger | testers say they pushed for "one more hit"; best chain ≥ 8 by the Weaver | 4 of 5 testers |
| 2. Every death teaches | testers can name what killed them and how to avoid it | ≥ 80% of deaths |
| 3. Knowledge is power | testers open gate 2 or buy a map or hint | 3 of 5 testers |
| 4. Few buttons | testers use Flare Toss and cling unprompted after S2 | 4 of 5 testers |
| Story clues (deniable early) | asked "Where do you think Glim comes from?": some suspect the abyss, none are certain | ≥ 1 suspects, 0 certain |
| Weaver | wins within 8 attempts; testers describe it as "about restraint" without being told | 4 of 5 testers |

---

## Out of Scope

**Not in M2** (planned for later):
- Layers 2–7, apart from the Weaver's landing arena; bosses 2–7.
- Masks (max HP), Mentor techniques, abilities other than Swing.
- Lift Station repairs (start in Layer 2), Docks, Gallery and the other hub NPCs.
- The lurker parry, phase dash, cashing in chain, more pogo directions, climbing as an upgrade (ideas list, `deferred-work.md`). Reviewed at the M2 retrospective, before the Layer 2 GDD update; at most one per layer milestone, each its own experiment. Per-run "chain-bending upgrades" are absorbed by Smith gear and the parked Dive Boons.
- A leaderboard, Steam Cloud saves (only if Steam is chosen in E7).

**Parked** (full-vision tier only): Roaming Ecology, The Abyss Breathes, Crafting, Food Chain, Dive Boons.

**Cut:** The Climb Back, the Boon Deck.

---

## Risks

| Risk | Mitigation |
|---|---|
| **Burnout** on a solo project lasting years | every epic ends playable; post a short devlog or private build after each epic, and share publicly at M2 (brief: "each milestone is a finished thing") |
| **The loop stops being fun** as systems pile up | each epic carries one playtest question; a "no" blocks the epics that build on it until it is fixed |
| **Snuff weakens greed:** an instant mid-air Snuff banks held embers, so it could become a free cash-out the moment eyes open | watch for it in the E1 playtest. If players Snuff on every telegraph, add a cost (for example, Snuff banks only half the held embers) |
| **Scope creep:** M2 adds many systems at once | the brief's rule: anything the current epic's question doesn't need waits for a later epic |
| **Flash safety** | ≤ 3 flashes/s cap and the "reduce flashing" toggle from **E1** (brief: "from day one"), with a check for every new effect |
| **AI-art perception** | disclose on every store page, covering art, audio and text pipelines; keep provenance in git |
| **Differentiation** (Downwell comparisons) | lead with chain-as-light and the fixed world; show the hub, map and journal within the first 5 minutes |

---

## Open Questions

Not blocking M2 architecture; each is decided by the epic or pass named.

| Question | Decide in |
|---|---|
| The Bright Moon force field; predator telegraphs per layer; lessons for bosses 2–5 | each layer's own milestone |
| Do bosses react to "what you are"? What does "breaking the cycle" mean? Layer 7's Truth; the island economy after the ending | the narrative pass |
| Which meta systems are core? Living Map, Field Journal, Depth Record and Lift Stations are core in M2. Expedition Loadout is **replaced by always-on gear** (revisit if gear grows). Relic Haul is replaced by embers; "relic" stays a story motif | confirmed here; revisit after M2 |
| Weaver details: behaviour at 62–78 px of light (1–3 links); the exact flee target of the herd | E2 prototype |
| How each side area exits back to the spine | E4 |
| Respawn point for a phase-2 death (the landing station is broken until victory) | E6 |
| Hub and Layer 2 landing palettes | E5 / E6 |
| Lighting and bloom under the Compatibility renderer (the brief wants bloom within the flash limits). *Architecture, 2026-11-11:* bloom stays off until the E1 worst-case perf scene holds 60 FPS on web and the HD 620 target; otherwise it is faked with unshaded sprites. **Decided (CP1 gate, 2026-11-21, sonlm): engine glow no-go; bloom = unshaded additive sprites** | E1 perf scene (decided) |
| A cap on simultaneous flares. The light budget is ≤ 6 `PointLight2D` on screen and flares always keep theirs, so repeated tosses could crowd it (architecture, 2026-11-11). **CP1 gate, 2026-11-21, sonlm: no cap needed** (perf_worst held at 6/6 lights with a flare on screen, desktop and Firefox on the Intel iGPU); Story 1.23 makes the cap a `Tuning` value and re-checks it with real flares | Story 1.23 |
| Ways to fail: Hard Landing and Grip Gives Out are dropped by M1 tuning (slow max fall, cling without stamina); Running Dry needs crafting (parked); Prey (a capture becomes an escape) | a later layer |
| Peak moments: The Speck, Riding the Giant, Felling the Canopy, The Curious Companion | their layers |

---

## Assumptions and Dependencies

- **Team:** solo, 5–10 h/week. M2 is a multi-month milestone.
- **Tools:** Godot 4.7; a headless server for tests and the sprite pipeline; builds played on a laptop through git.
- **Starting values from M1:** M1 tuning values carry over. Every new number in this GDD is a starting value to tune in the M2 playtest.
- **Playtesters:** about 5 external testers are available for the M2 shared build. [ASSUMPTION]

**Assumption index:**
1. The bank-heal threshold (Health).
2. Weaver attempt counts (Difficulty).
3. Ember earnings per dive (Economy).
4. The Layer 2 landing palette (Art).
5. The hub palette (Art).
6. Epic sizes and M2 duration (Epic Structure).
7. Tester availability (above).
8. Ember Cache glow radius and lurker pull (Economy).
