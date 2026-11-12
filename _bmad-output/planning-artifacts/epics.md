---
stepsCompleted: [1, 2, 3, 4]
status: complete
completed: 2026-11-12
inputDocuments:
  - _bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md
  - _bmad-output/game-architecture.md
  - _bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/DESIGN.md
  - _bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/EXPERIENCE.md
  - _bmad-output/narrative-design.md
  - _bmad-output/project-context.md
  - _bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/epics.md
  - _bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/decision-log.md
  - _bmad-output/implementation-artifacts/m1-playtest-findings.md
  - _bmad-output/implementation-artifacts/deferred-work.md
excludedDocuments:
  - _bmad-output/planning-artifacts/briefs/brief-pixel_art_game-2026-11-08/ (superseded by GDD v1.0 + M1 findings)
  - _bmad-output/implementation-artifacts/spec-m1-core-loop-prototype.md (superseded)
---

# The Unbroken Chain (pixel_art_game) - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for The Unbroken Chain, Milestone 2 (the vertical slice), decomposing the requirements from the GDD, the UX Design spines (DESIGN + EXPERIENCE), the narrative design and the game architecture into implementable stories.

### Source documents

Story-file creation must load these by path. `gds-create-story`'s default globs (`{planning_artifacts}/*architecture*.md`, `*gdd*.md`, `*gdd*/*.md`) miss the architecture at the output root and the nested GDD and UX folders.

- GDD: `_bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md` (+ `decision-log.md`, high-level `epics.md`)
- Architecture: `_bmad-output/game-architecture.md`
- UX: `_bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/DESIGN.md` and `EXPERIENCE.md`
- Narrative: `_bmad-output/narrative-design.md`
- Implementation rules: `_bmad-output/project-context.md`
- M1 findings and deferred work: `_bmad-output/implementation-artifacts/m1-playtest-findings.md`, `deferred-work.md`

Tags: `[E#]` is the epic that owns the requirement in the GDD's high-level `epics.md` (risk-first order E1 → E7). `[M1]` means it already exists in the M1 prototype and must survive the E1 migration unchanged unless a later FR changes it. Values are starting values to tune unless marked M1 (playtested).

## Requirements Inventory

### Functional Requirements

**Movement and core kit (M1, carried into M2)**

FR1: Movement uses the M1 tuning: run 110 px/s (ground accel 900 px/s², air accel 1500 px/s²); jump −330 px/s (apex ≈ 60 px), early release = velocity ×0.45; gravity 900 px/s² rising, ×0.6 falling, max fall 210 px/s; coyote time 0.08 s; jump buffer 0.10 s. [M1]
FR2: Air dash: 260 px/s for 0.12 s, horizontal, ignores gravity; once per airtime, refreshed by landing or a pogo hit. [M1]
FR3: The camera leads 70 px downward while falling. [M1]
FR4: Slash (Attack on the ground): active 0.12 s, cooldown 0.22 s, hitbox 22×16 px in front. Attack in the air always pogoes: armed 0.22 s, hitbox 26×24 px below the feet; a hit bounces the player at −300 px/s, adds 1 link and freezes 75 ms (hitstop); a pogo on the same frame as touching the ground adds nothing. Player body 10×20 px, hurtbox 8×18 px. [M1]
FR5: Chain: +1 link per pogo hit without touching the ground, capped at 20. Chain-Light radius = 40 + 22·√links px. Blade Bloom scales slash and pogo hitboxes ×(1 + 0.18·√links), max ×1.8, never the hurtbox. [M1]
FR6: Chain-end rules: landing breaks (held → carried, light → 40 px); Snuff (hold Light past the tap window) breaks (held → carried, light 12 px while held); wall cling pauses the chain for 1.0 s per chain (a pogo hit refills it), then breaks (held kept, then → carried; light 40 px while clinging); any hit breaks (held → carried); Flare Toss halves (FR14); crossing a room exit with a live chain banks it exactly like a landing (ADR-2 backstop; The Fall is the only exception); death breaks and held embers are lost. [M1 + E1]
FR7: Wall cling: hold Jump while touching a side wall and falling (vy ≥ 0); slide 18 px/s, never climbs; release Jump kicks off at (150 away, −260 up) px/s with no steering for 0.15 s; Down drops straight off. [M1]
FR8: Embers: pogo link *k* pays *k* embers (a chain of *n* pays n(n+1)/2); hits past the 20-link cap keep paying. [M1]
FR9: Light: holding Light past the tap window is Snuff; a tap must never break the chain (a tap is Flare Toss). [M1, window setting E1]

**Health and damage (E1)**

FR10: The player has 4 HP. Damage: crawler contact 1 (knockback 150 px/s, −150 px/s), boss attack 1, hunting lurker 2 (only while it hunts the player), spikes/hazards 1 (respawn at the last safe ledge in the same room). After a hit: 0.6 s invulnerability, blinking at 2.5 Hz. [E1]
FR11: Any hit breaks the chain and moves held embers to carried; only death loses held embers. [E1]
FR12: Healing: full at a Lift Station rest and on arriving home; +1 HP (up to max) when banking a chain of ≥ 10 (threshold is an assumption to playtest). [E1]
FR13: At 0 HP the player dies and respawns, with full HP, at the deeper of the last lit lantern anchor or Lift Station. Death does not reload the scene. [E1]

**Flare Toss (E1)**

FR14: Tap Light (released inside the tap window; default 0.12 s, setting 0.12 / 0.2 / 0.3 s) with ≥ 2 links throws a flare. Cost: half the chain rounded up (8 → 4, 5 → 2); held embers move to carried in proportion to the links spent; the remaining chain keeps going; the light shrinks to the new chain. [E1]
FR15: The flare flies in an arc in the facing direction (180 px/s forward, −160 px/s up, normal gravity), sticks to the first surface hit, burns 4.0 s with a radius equal to the player's light radius before the toss, and fades out smoothly over its last 1.0 s with no flashing. It deals no damage. [E1]
FR16: Predators that sense a flare treat it as the player (lurkers telegraph and hunt it); the Weaver is repelled instead (FR45). A lurker switching from the player to a flare needs no telegraph. [E1]

**Lurker (M1, changed in E1)**

FR17: A lurker wakes when the light radius is ≥ 80 px (4 links), it is within radius × 1.6, and it is on screen (inside the play area between the gutters). [M1]
FR18: Off-screen stirring: a lurker that would wake but sits just off screen (within 96 px of the play-area edge) shows a half-open eye at the play-area edge, level with the lurker, that opens wider as it stirs, plus a red glow with a minimum strength. It cannot hunt until it is on screen and has telegraphed. (Its panned sound arrives in E3.) [E1]
FR19: Telegraph: 0.9 s (never below 0.75 s); eyes open with an animation, pulse at 2 Hz and cast red light on the wall; both HUD gutters show a pulsing red frame (≤ 2 Hz) and a small eye icon; HUD values are not recoloured. [M1 + E1]
FR20: Hunt: 95 px/s straight at its target, through walls. It senses the player while the light radius is ≥ 80 px and within radius × 1.6. When it can't sense its target it stops at once and is harmless, waits 0.6 s, then returns home. A Snuff, landing or cling taken in time always saves the player. [M1]
FR21: Retargeting: a lurker hunting a flare or the Ember Cache that switches to the player telegraphs again from the start (≥ 0.75 s) before it can hurt the player. Lurkers are not killable in M2. [E1]

**Embers, Ember Cache, difficulty (E1)**

FR22: Three ember stages: held (current chain) → carried (the chain ended safely: landing, Snuff, cling timeout, a hit, a room exit) → deposited (Lift Station rest or arriving at the hub; safe forever). [E1]
FR23: On death (Normal): held embers are lost; carried embers drop as an Ember Cache where the player died; touching it returns them to carried; dying again before recovering it destroys it. At most one cache exists. [E1]
FR24: The Ember Cache glows amber and wakes lurkers by the same rule as the player's light (glow radius ≥ 80 px, lurker within radius × 1.6 and on screen). The glow radius is tuned in the E1 playtest; below 80 px it draws nothing. [E1]
FR25: Difficulty tiers change only the cost of death: Easy (held → carried, carried kept), Normal (held lost, carried dropped as a cache), Hard (both lost). Never damage, telegraphs or chain rules. Chosen at New Game, changeable any time in Options. [E1]

**Interact, anchors, stations (E1 placeholder, E4 final)**

FR26: ↓ while standing still on the ground is interact: rest at a station, talk to an NPC, read a journal object. ↓ on a wall still drops; ↑ stays Jump. [E1]
FR27: Lantern anchors are lit by touch and become the respawn point (respawn only: no heal, no deposit). About one every 4–6 screens (≈ 5 in Layer 1). [E1, placed in E4]
FR28: Lift Station: touching it lights it (respawn point). ↓ to rest: full heal, deposit carried embers, open the fast-travel menu (hub and repaired stations), respawn the layer's enemies, autosave. A placeholder station in E1; the final one in E4. [E1 → E4]

**Saving (E1)**

FR29: Autosave at every Lift Station rest, on arriving at the hub, and when the player quits at a lit lantern anchor (position saved; carried embers stay at risk until a station). Progress moments (difficulty change, purchases, story flags, the Weaver phase checkpoint and defeat) also save world progress without moving the resume point (R14). [E1]
FR30: Three save slots. The slot picker shows depth, best chain, play time and difficulty; Continue loads the most recent slot; Load on the title opens the picker; New Game picks a slot and a difficulty. A failed save is shown to the player ("Not saved") and never crashes or pauses the game. [E1]

**Controls, pause and options**

FR31: Default keyboard: arrows move, Z or ↑ jump, X attack, C dash, V light, Esc or P pause. Default gamepad: left stick / d-pad move, A jump, X attack, RB dash, B light (tap Flare Toss, hold Snuff), Start pause. Every action is one button; no chords. [E1]
FR32: The game pauses on Esc / P / Start, when the window loses focus, and when a gamepad that was in use disconnects. [E1]
FR33: Options open from the Pause menu; tabs that have not landed are hidden. E1: Game (difficulty) and Accessibility (reduce flashing; screen shake on/off; reduced motion, following the OS setting on web; Light tap window 0.12 / 0.2 / 0.3 s; hold→press toggles for Cling and Snuff). E1 also adds a 4-level Brightness choice (UX A1, decided 2026-11-12), since the M1 F1 brightness hotkey is removed in E1. E3: Audio (volume sliders). E7: Video (Brightness moves here beside fullscreen and scale) and Controls (rebind every action, keyboard and gamepad); Accessibility adds large HUD, text scale, timing assists and visual sound cues. [E1 / E3 / E7]
FR34: Snuff toggle mode (Accessibility): Light only throws Flare Tosses (any press, no tap window); Snuff moves to its own key (default Shift; pad LB), pressed once to start and again to end. Snuff still ends the chain. Quick Wick has no extra effect in this mode. [E1]
FR35: Timing assists and game speed (E7) are separate from difficulty; runs that use them are kept out of Guild records. [E7]

**HUD and feedback (E1)**

FR36: HUD v2 lives in two ~60 px side gutters (play area ~360 px): HP, held and carried embers, chain number and meter, lurker alert (pulsing red frame + eye icon). [E1]
FR37: Field Journal death line: on death, one line naming what killed the player and how to avoid it. The cause may carry island idiom; the avoidance is always plain. Written in the narrative voice after sonlm approves the death-card voice anchors. [E1]
FR38: Feel rules: freeze frames and sparks on every pogo hit; creature deaths dissolve into sparks in their own tint that turn amber as they fade, never blood; slow motion only at boss climaxes (The Fall start and the Weaver's defeat: 0.5 s at ×0.3); screen shake can be turned off. [E1 / E4 / E6]
FR39: The M1 shaft is rebuilt at 22 tiles (352 px) wall to wall, side walls included, with camera limits that keep it inside the play area; E1's playable is that shaft with a placeholder station at the top, two anchors and the full kit. [E1]

**The Weaver (E2 prototype → E6 final)**

FR40: Arena: 30 × 34 tiles (two screens tall), scrolling horizontally inside the ~360 px view; 4 web strands span it wall to wall at different heights. Strands can be pogoed (+1 link, no damage). Each strand has an anchor at both ends; slashing an anchor twice weakens that strand (frayed sprite, sag). [E2 → E6]
FR41: Light-shy states: Bright (light ≥ 80 px) → retreats to the ceiling anchor at 120 px/s and drops a spiderling every 2.0 s (at most 3 alive). Dark (light ≤ 40 px: base, Snuff or cling) → descends along the strands at 70 px/s and bites (0.9 s telegraph: legs rear up, eyes glow; 1 damage). Behaviour at 62–78 px of light (1–3 links) is decided in the E2 prototype. [E2]
FR42: Light-burst stun: reaching chain 3 within 96 px of the Weaver stuns it for 2.5 s; hits deal 1 each, at most 3 per stun. [E2]
FR43: Strand drop: if the Weaver stands on a weakened strand and the player slashes its second anchor, the strand drops: 2 damage plus a 2.5 s stun (hits during it count). [E2]
FR44: HP 12. Re-Weave at 9 HP: a 3.0 s telegraph (silk threads glow along the new paths), then every strand is rebuilt in a new pattern and weakened strands are restored; the player is not harmed; spiderlings keep dropping. No health bar: health reads in the world (segments fray and fall off, threads sag). E2 stubs The Fall: the fight ends at 6 HP. [E2]
FR45: Flare herding: the Weaver flees a flare along the strands to the farthest point inside the flare's radius × 1.5, at 110 px/s (exact flee target decided in E2). [E2]
FR46: Spiderling: drops from the Weaver while the player is bright; falls slowly, then crawls; 1 HP, 1 contact damage; chain fuel. [E2]
FR47: The Fall (at 6 HP): the Weaver cuts its anchors and the web floor gives way; 0.5 s at ×0.3; about 6 s of free fall with debris and web clumps to pogo (the chain is kept across the room change: the one scripted exception; it pays embers); the player lands in the Layer 2 landing arena (one screen, Bright Moon palette). [E6]
FR48: Phase 2 (6 → 0 HP, landing arena): 2 strands; bite telegraph 0.75 s; descent 90 px/s; Re-Weave at 3 HP rebuilds the 2 strands. The Bright Moon rule is off in the landing arena. [E6]
FR49: Weaver deaths: dying respawns the player at the Hollow Station (the station before the arena) with full HP and the fight reset. Dying in phase 2 resumes the fight from phase 2 in the landing arena (respawn point decided in E6). The arena can't be left mid-fight and can always be won with the starting kit; Flare Toss is optional. [E2 / E6]
FR50: Defeat: reads as a win first (0.5 s at ×0.3, a burst of light, the landing-arena Lift Station repairs for free), then a coda where the Weaver dims and withdraws downward into the dark in sparks (bosses are never shown dying). It drops Weaver Silk (Swing unlocked); the repaired station returns the player to the hub; the way down into Layer 2 stays sealed; sets `weaver_defeated`. [E6]

**Swing (E6)**

FR51: Swing: with Swing unlocked, pressing Dash within 56 px of a silk anchor (a level object visible at base light) grabs the rope; holding Dash stays on; the rope attaches at the current distance clamped to 32–96 px; the player swings like a pendulum, left/right adds pump; releasing Dash launches with the current velocity ×1.1. Out of range, Dash is the air dash (no hold threshold, no delay). Swinging doesn't touch the ground, so the chain continues and the player stays bright. [E6]
FR52: Three silk anchors (in A, S2 and C) each guard one Swing-only secret: Silk Grip gear (+0.25 s cling grace), the Memorial clue (the Guild tag of Oda's dive partner, which adds the partner's name to the Memorial Wall) and an Ember Hoard. [E6]

**Layer 1 world (E4)**

FR53: Rooms and screen transitions: levels are text room files; spine shafts are 22 tiles (352 px) wall to wall and never scroll sideways; wider rooms scroll horizontally; the camera leads downward and its limits keep each room inside the play area. [E4]
FR54: The Layer 1 spine, about 23 screens, in fixed order: S1 The Lip (screens 0–3: run, jump, slash, first pogo over safety nets, landing banks embers; Lip Station; no lurkers); S2 Scaffold Drop (4–9: the first lurker with its eyes opening right above a ledge; wall cling in a narrow stretch with no ledges; Flare Toss taught in a lurker pocket; branch to A); S3 The Lantern Door (10–12: chain gate 1 ≥ 4 on the main path, a row of hoverers above it teaches the run-up); S4 Explorers' Grave (13–18: lurker rooms testing Flare Toss and cling under pressure; The Last Entry; branches to B and C); S5 Weaver's Hollow (19–22: the Weaver is heard and glimpsed before the arena; Hollow Station before the arena). [E4]
FR55: Side areas (optional, each ends in a reward): [A] Rope Works off S2 (old rope yard; Ember Hoard ≈ 60, 2 journal entries, a Swing secret); [B] Old Mine off S4 (dark galleries with ≥ 1 lurker per screen; Ember Hoard ≈ 80, 1 Cartographer hint, 1 journal entry); [C] Sky Ledge off S4 (open cliff in daylight; behind chain gate 2 ≥ 8: a shortcut up to the hub, the only safe mid-layer deposit; Ember Hoard ≈ 100; a Swing secret). How each side area exits back to the spine is decided in E4. [E4]
FR56: Chain gate (a lantern door): reads the chain when touched; if it is high enough the door opens for good; if not, it stays shut, glows the required number and bounces the player off without breaking the chain. Gate 1 ≥ 4, gate 2 ≥ 8. Gate rooms have a hoverer run-up that makes the required chain reachable on the first try with plain movement and no dash. [E4]
FR57: Level rules: ledges every ≤ 1.5 s of fall in spine shafts; narrow stretches 6–10 tiles wide with no ledges and walls always in reach; station rooms have no enemies within 2 screens and a lit lantern visible from the shaft above; every lurker telegraph happens on screen; every predator-heavy stretch has an escape (ledge, wall, room to Snuff) in reach; every hazard pit has a ledge or wall within a 1.5 s fall at 210 px/s; exits sit behind a landing, never inside a chain run; each new move appears first with a safe exit in view and is tested 2–4 screens later. [E4]
FR58: Enemies: crawler walker (patrols a ledge, turns at edges; 1 HP, 1 contact damage); crawler hoverer (drifts 10 px side to side over 2.4 s, phase from position; 1 HP, 1 damage); lurkers set in the walls. Enemies respawn on a station rest or on leaving the layer. A third regular enemy is added only if the E4 walk-through shows the need. [E4]
FR59: Palette zones down the spine: S1 + A dusk (`#2b1d14 #6b4a2f #b08a5a #d8c3a0`); S2–S3 umber (`#1e1714 #4a3a33 #7d6a5c #a99a8c`); S4–S5 + B + C cold violet (`#0d0b14 #2a2440 #4f5d75 #a9b4c2`). Ledge rims glow faintly; old lamps in the layers are dead or a cold tint (amber burns only in the hub and on lantern anchors). [E4]
FR60: Map screen: fills in screens as they are visited; Lift Stations and lit anchors are always shown; the Cartographer's Layer 1 map also reveals unvisited screens, gate locations and secret markers; it shows per-layer counts of each reward type found (no overall percentage in M2). [E4 / E5]
FR61: Journal objects: 3 entries by the island's lost (A ×2, B) plus *The Last Entry* in S4 (Oda's unsigned camp and half-written journal; her cold lantern is the lantern anchor `anchor_s4_oda`; it counts as a journal entry). ↓ reads; reading a document pauses play. The Memorial Wall name list is written in E4 alongside the documents so names match. [E4]
FR62: Ember Hoards: 4 in Layer 1 (A ≈ 60, B ≈ 80, C ≈ 100, one in a Swing secret). [E4 / E6]
FR63: Story flags `last_entry_read` and `lurker_met` are set from E4 and saved until the hub shows their payoff. [E4]

**Hub: Abyss Island (E5)**

FR64: The hub is a walkable village 2 screens wide on flat ground (no enemies, chain or platforming), laid out Smith, Cartographer, Lift, Naturalist, Guild + Memorial Wall, Oda's house; relic crates stamped for shipping sit by the lift. Arriving home deposits all carried embers, heals fully and autosaves. [E5]
FR65: Fast travel by lift between the hub and every repaired Lift Station; none to lantern anchors. [E5]
FR66: The Watching Departure: riding the lift up has a fixed duration; the full gathering (creatures at the edge of the light, watching) plays once per station layer and only after `lurker_met` (`departure_l1_seen`, `departure_l2_seen`); later rides show a few eyes; fast travel down or sideways has none. [E5]
FR67: Cartographer: Layer 1 map (60 embers); 3 hints (25 each) pointing to a side area, gate 2 and a Swing secret. [E5]
FR68: Smith gear, always on (no slots), as data: Quick Wick (200: instant Snuff; the light starts dimming the moment Light is pressed, and a release inside the tap window still throws a flare; the window doesn't change); Long Wick (250: flare 4 → 6 s); Steady Grip (300: cling slide 18 → 10 px/s). Silk Grip is found, not sold. Gear bends a rule, never adds raw power. [E5]
FR69: Naturalist: copies each new journal entry and pays 10 embers for the copy (originals stay with the player); sells 2 cosmetic palettes (75, 150). [E5]
FR70: Guild records and Memorial Wall: deepest depth, best chain, most embers banked in one chain, deaths; Oda's all-time depth record shown as the target; the Memorial Wall lists lost explorers' names, Oda Vell among them; the partner's name is added after the Memorial clue (E6). [E5 / E6]
FR71: Minimal Journal tab: creature entries with "new" marks, so the Naturalist payout reads. [E5]
FR72: Oda's house: a small interior beside the Guild (bed, Oda's empty chair, her gear wall with flag-gated pinned pages such as `prop_house_page_last_entry`); props and lines only, not a save or rest point. A new game opens here: Glim wakes beside the empty chair, ↓ is taught on the door, and Tessaly's First Dive registration is the only required talk. Until E5, New Game starts in S1. [E5]
FR73: NPC dialogue framework: ≤ 3 lines per flag, one idle line, then the shop; a per-NPC `{seen, idle}` record in `SlotState`; one story-flag registry in `rules/` with a validator for every `requires_flag`; a length validator that measures speech lines in the UI font (≤ 2 rows). [E5]
FR74: M2 closing beat: the first ride up from the landing arena plays the full Watching Departure; at home Old Tessaly logs the player's depth, still short of Oda's record. [E6]

**Audio (E3, composed music E7)**

FR75: SFX script pipeline: text parameter files → Python → WAV, kept in git and built on the server alongside the sprite pipeline. [E3]
FR76: Core SFX set: pogo hit (soft synth strike; pitch +1 semitone per link up to +12 at 12 links); embers banked (a chime that grows longer with the amount); lurker telegraph (low breath or growl as the eyes open, panned to its side, always above the music); off-screen stirring (quiet, panned); hunting lurker (rising hiss that follows its position); Snuff (light blown out, then muffled silence); cling (rope or wood creak); Flare Toss (whoosh, then a sizzle while it burns); Weaver (strands twang; a hiss when light makes it retreat); chain gate (a resonant tone that rises to the required count and opens on a chord, or a dull thud if the chain is too short). [E3]
FR77: Chain-reactive music: at rest only the ambient soundscape; stems fade in over 0.5 s at 3 links (pulse), 6 (melody) and 10 (full layer theme); a safe chain break resolves on a chord within 0.3 s; death cuts the music with a muffled, dissonant tail. The hub, the Weaver fight and The Fall get their own themes. E3 sketches the shared abyss motif as a placeholder hub stem so layer stems can quote it (narrative: "compose the hub theme first"); composed hub, Weaver and Fall themes land in E7. [E3 → E7]

**Slice polish and ship (E7)**

FR78: Full Field Journal: death log, lore, records and polish (the death line ships in E1, the minimal Journal tab in E5). [E7]
FR79: Title screen logo art replaces the E1 text placeholder. [E7]
FR80: Art pass: about 10 player animations (idle, run, jump, fall, pogo, slash, dash, cling, swing, hurt); hub and Layer 2 landing palettes; HUD polish. [E7]
FR81: First shared build (web + Windows + Linux), a playtest round with about 5 testers against the GDD Success Metrics, and the Steam vs itch.io decision. [E7]

### NonFunctional Requirements

NFR1: Performance: 60 FPS sustained at 480×270 scaled ×3 (1440×810) on the developer laptop and on an Intel HD Graphics 620-class iGPU, measured over a 10-minute Layer 1 run including the Weaver fight; no frame over 20 ms outside the intentional 75 ms hitstop.
NFR2: Input is read every frame; no input is dropped during a 75 ms hitstop (presses during hitstop are buffered).
NFR3: Load time under 2 s from the hub to a Lift Station on the laptop.
NFR4: Memory ≤ 512 MB RAM on desktop, ≤ 300 MB in a web tab.
NFR5: Web build: 60 FPS in desktop Chrome or Firefox on the laptop at the 960×540 (×2) embed; download under 30 MB; playable within 10 s on a 50 Mbps link; pauses when the tab loses focus.
NFR6: Display: 480×270 viewport, integer scaling only (×2, ×3, ×4), nearest filtering, letterboxed; on web, if the window is below ×2 the click-to-play gate suggests fullscreen.
NFR7: Platforms: Windows and Linux desktop, web/itch.io for playtests; Godot 4.7.2, GDScript only, GL Compatibility renderer.
NFR8: Flash safety: no more than 3 flashes per second anywhere (pulses ≤ 2 Hz, blinks 2.5 Hz); every flashing, shaking, pulsing or easing effect honours reduce flashing, screen shake and reduced motion; the cap is checked for every new effect from E1 on.
NFR9: Colour is never the only signal: every telegraph also has a shape, a motion and a sound cue. Reserved colours: chain-light amber `#ffd27a` (the player's light, embers, flare, chain popups, the menu cursor; nothing else) and predator red `#d9473f` (light-hunting danger only).
NFR10: Pillar 2 fairness guarantees (tested): every predator hunt of the player is telegraphed on screen for ≥ 0.75 s; an escape taken in time (landing, Snuff, cling) always works; no off-screen ambush.
NFR11: Determinism: no randomness in level behaviour (only camera shake may use `randf`).
NFR12: Steam Deck legibility: at ×2 (960×540, letterboxed) the HUD and all text are readable; checked in E1 with the font choice, full pass in E7.
NFR13: World progress is never lost (opened gates, stations, abilities, deposited embers, map, journal, bosses); saves are atomic and a failure is surfaced, never a crash.
NFR14: Zero softlocks in M2, checked by the reachability bot and the playtest; automated tests stay green on every commit.
NFR15: Audio mix: predator cues have the highest priority (music ducks 6 dB under them); no sound effect comes close to clipping during a 75 ms hitstop.
NFR16: Accessibility of input: fully playable on keyboard and on gamepad, one button per action, no chords; UI shows glyph prompts, never hard-coded key names; every action rebindable (E7).
NFR17: All player-facing text is localisable (string keys), names shapes rather than colours, and fits the 8 px UI font.
NFR18: Licences and provenance: the font licence (OFL 1.1) and Godot's MIT licence with its third-party notices ship in every build; AI-assisted art, audio and text pipelines are disclosed on store pages with provenance kept in git.
NFR19: Originality: no names, creatures, places or plot beats borrowed from any existing work. Creature deaths dissolve into sparks, never blood (low age rating).

### Additional Requirements

Source: `game-architecture.md` (2026-11-11) + `project-context.md`. **No starter template: brownfield.** E1 story 1 is the M1 migration (AR1–AR3), and the foundations follow in the architecture's stated order (AR4).

**Migration and foundations (E1 story 1 impact)**

AR1: M1 migration, in **one commit** with `git mv` (so `.gd.uid` files move with their scripts): `chain_state.gd` → `scripts/rules/`; `player.gd`, `crawler.gd`, `lurker.gd` → `scripts/actors/`; `fx.gd` → `scripts/core/`; `scenes/enemies/*` → `scenes/actors/`; `tests/run_tests.gd` → `tests/test_chain_state.gd`. Then rewrite every moved `res://` path by hand (the M1 scenes carry no uids) and run `godot --headless --path game --import`; the first `[autoload]` section (M1 has none) arrives with `Game` in Story 1.2. `run_tests.sh` must be green before anything else changes. [E1]
AR2: Retire `shaft.gd`: its LAYOUT becomes `rooms/l1/m1_shaft.txt` (22 columns including walls); its statics (`ambient_index`, `show_controls`, `best_chain`, `deaths`, `checkpoint`, `banked_embers`) move into state objects; the F1/F2/F3 hotkeys and `reload_current_scene()` on death are removed (F1 brightness becomes the Brightness setting, in Options > Accessibility from E1 and Options > Video from E7; R1); `run/main_scene` becomes `scenes/world/world.tscn`. [E1]
AR3: Retire the other M1 patterns: `player.gd`'s four `Engine.time_scale` writes (→ `Clock`), raw `Input.*` reads (→ `PlayerInput`), `randf_range` camera shake (→ `camera_rig.gd`), 44 `@export` tuning vars on player/crawler/lurker (28 / 5 / 11; → `Tuning`); `lurker.gd`'s `get_viewport_rect()` and `get_first_node_in_group("player")` (→ `World.play_rect()` + `Sensing`); `Fx._unshaded()` building a material per effect (→ cached static). [E1]
AR4: Foundations in the architecture's order: `Log` → `Clock` → state objects (`Settings`, `SlotState`, `DiveState`, `Tuning`) → `Game` → `RoomLoader` + `World` → `PlayerInput` → `run_tests.sh` glob runner + `test_lint.gd`. The lint can only go green once Clock, PlayerInput, the F-key removal and the camera-shake move have landed. [E1]
AR5: Build the worst-case perf scene `rooms/dev/perf_worst.txt` **early in E1** (Old Mine density + flare + cache + player, placeholder art; debug presets only) and check it on the laptop and in a web debug build. It decides: engine glow/bloom go/no-go (fallback: unshaded additive sprites), whether ≤ 6 `PointLight2D` holds 60 FPS, Compatibility glow web parity, and informs the flare cap question. [E1]
AR6: Enable 2D physics interpolation (`physics/common/physics_interpolation = true`, 60 ticks, keep `snap_2d_transforms_to_pixel`); teleports (respawn, room entry) call `reset_physics_interpolation()`. Keep it only if the laptop feel check (60 Hz and high-refresh) passes; otherwise turn it off and record why. [E1]

**Engine, display, platform**

AR7: Godot 4.7.2 frozen for M2 (4.7.x maintenance only after the upgrade checklist; 4.8+ considered only at an epic boundary). Upgrade checklist: update editor + templates on laptop and server together → re-import → tests green → web smoke → commit changed `.import` files. [all]
AR8: `core/display.gd`: 480×270, integer scale only, letterboxed, nearest; DPR-based integer scale via JavaScriptBridge on web with sub-×1 fit; fullscreen; PC minimum window. Verified in the E1 web build at the ×2 embed (960×540) and fullscreen. `OS.has_feature("web")` only in boot, `display.gd`, the storage check, the quit button and the audio gate. [E1]
AR9: Autoloads: only `Game` (E1) and `Audio` (E3); no `class_name` on autoloads; a third autoload, an addon or a `.tres` is an architecture change. [E1 / E3]

**State objects and rules**

AR10: Four pure `RefCounted` state classes in `scripts/rules/` (`Settings`, `SlotState`, `DiveState`, `Tuning`) with typed signals and `to_dict()` / `from_dict()`. Lifetimes: per-life on `Player` (`ChainState`, `Health`, `PlayerInput`; reset by re-instancing on death); per-dive `Game.dive` (reset on rest, arriving home, leaving the layer); per-slot `Game.slot` (New Game / Load); global `Game.settings`. [E1]
AR11: `Game` autoload (`core/game.gd`) holds refs only (`settings`, `slot`, `dive`, `tuning`, `clock`, `devices`), commands `new_game`, `load_slot(n)`, `save_now()`, `save_progress()` (R14), signals `save_failed(n, err)` / `save_succeeded`, and `reset_for_tests()`. It keeps the same state instances all session and resets them in place (`from_dict()` / `reset()` emit change signals); never replaces them. [E1]
AR12: `ChainState` (moves to `rules/`) gains Flare halving and "any hit → carried"; signals `changed(count)`, `banked`; API `count`, `break_chain()`, `light_radius()`. `tests/test_chain_state.gd` stays its spec. `Health` (`rules/health.gd`): 4 HP, damage table, 0.6 s invulnerability, bank-heal; signal `damaged`; `test_health.gd`. [E1]
AR13: Ember rule methods on `DiveState`/`SlotState`: bank held → carried; deposit `dive.carried` → `slot.deposited`; death cost by difficulty. At most one Ember Cache, stored in `SlotState` (room, position, amount); a new death replaces it; no cache when carried is 0; it survives rests and saves. [E1]
AR14: `DiveState`: carried embers (`add_carried(n)` → `carried_changed`), killed enemies keyed `room_id` + grid cell (never saved long-term), current respawn point; `reset()` respawns enemies. `SlotState`: world flags (gates, stations, anchors, hoards, secrets), cache, deposited embers, abilities, gear, map visits (`visit(room_id)`), journal, records, `death_log` (appended from E1), difficulty, play time, resume point; `set_flag(id, value)` emits `flag_set`. `Settings`: accessibility flags, brightness, `light_tap_window`, Cling/Snuff toggle modes, volumes, video, bindings, last slot; `set_value(&"key", v)` emits `changed`, and `core/` persists it to `user://settings.json` (R15; `rules/` does no file I/O). `DiveState` also holds `killed` (room_id + grid cell) with `mark_killed()`; `reset()` clears it. [E1, extended E4–E7]
AR15: `Tuning` (`rules/tuning.gd`): one `const` per value with a `##` unit + intent + "was X" comment, listed in `BASE`; `f(key)` asserts on unknown keys, `flag(key)`, `apply_gear(ids)`, `changed`; rebuilt from `Game.slot.gear`; actors re-read each tick. All M1 `@export` tuning migrates here; values no system bends stay local consts. Changing a value updates the matching GDD table. [E1]
AR16: Gear as data (`rules/gear.gd`, `{id, stat, op, value}`, ops `set` / `add` / `mul` / `flag`, applied set → add → mul regardless of gear order): `long_wick` flare_burn set 6.0; `steady_grip` cling_slide set 10.0; `silk_grip` cling_grace add 0.25; `quick_wick` flag `instant_snuff`. Never `if has_gear`. The tap window stays a `Settings` value; difficulty is not a modifier. [E5 / E6]
AR17: `rules/economy.gd` holds prices (map 60, hint 25, gear 200–300, cosmetics 75–150), the ember curve and the journal payout, with GDD citations. `rules/dialogue.gd` holds per-NPC `{key, requires_flag}` lists. [E4 / E5]
AR18: Data access: reads through `Game` refs; writes only through rule methods that emit signals; nothing reads files outside `core/` and `world/room_loader.gd`. Typed signals on the owner, connected through `Game` refs or a direct child; no event bus, no node paths; tree changes from handlers are deferred. [all]

**World, rooms, level authoring**

AR19: `scenes/world/world.tscn` + `world/world.gd` (group `world`) with `RoomHolder`, `Player` (re-instanced on death), `Camera2D` (limits from the room, play area centred between the gutters), `UI` (`CanvasLayer`, `PROCESS_MODE_ALWAYS` → `Gutters`, `ScreenRouter`). Duck-typed API: `play_rect()`, `request_respawn()`, `fast_travel(id)`. [E1]
AR20: `World.play_rect()` is the single definition of "on screen" (inside the gutters, world coordinates), used by lurker notice, stirring distance, edge cues, glyph-prompt clamps and guarantee tests; never the viewport. [E1]
AR21: Room text format `game/rooms/<layer>/<room_id>.txt`: `key=value` header (`id=`, `zone=`, `exits=up:s1_lip@x12, …`, `obj=<id>@<col>,<row>` per persistent object, `map=x,y,w,h`), `---`, grid of equal-width rows (1 char = 16 px). `world/room_legend.gd` is the single char → tile/entity source, documented in `docs/rooms.md` (new chars there first). Optional set-piece overlay `<room_id>.tscn` beside the file. [E1; `map=` E4]
AR22: `world/room_loader.gd` parses → pure validator (returns `Array[String]` errors `file:row:col`: unequal rows, unknown chars, duplicate ids) → builds the TileSet and ledge rims in code. On errors it `push_error()`s each and returns null; at runtime a failed build cancels the swap and the player stays put. API names: `load_room(id)` + `load_room_from_path(path)`. Every room builds standalone and runs headless without `World`, a save or the hub. [E1]
AR23: `world/room.gd` owns transient entities: `spawn(scene, pos, args := {})` sets args before `add_child`; `entry_position(entry)`, `bounds()`. Flares, FX, spiderlings and popups are room children and die with the room. [E1]
AR24: `enter_room(room_id, entry)`: skip persistent objects flagged taken/opened, skip enemies in `DiveState.killed`, spawn the Ember Cache if `slot.cache.room == room_id`; `remove_child` + `queue_free` the old room → add the new → place the player → camera limits → `reset_physics_interpolation()` → `Game.slot.visit(id)` → `room_entered.emit(id)`. Always `call_deferred`, never inside a physics callback. Exit backstop: crossing an exit with `chain.count > 0` calls `chain.break_chain()` first. `World.scripted_cut(target, entry)` skips the backstop and is used only by `the_fall.gd`. [E1; scripted_cut E6]
AR25: Death flow: `Player.died` → death cost by difficulty → `slot.death_log.append({cause, room})` → ScreenRouter death card → on advance `enter_room(respawn room, respawn object)` → new `Player` at full HP → `World.player_spawned(player)` so HUD and audio rebind (smoke test "HUD after a death"). No scene reload; enemies killed this dive stay dead. Hazard respawn: last safe ledge in the current room, tracked by `World`, per-life. Rest: heal → deposit → `dive.reset()` → rebuild the room (`enter_room(current room, station)`, so killed enemies are back) → autosave → station menu. [E1]
AR26: Naming: room ids `<segment>_<name>` (`s1_lip`), `<letter>_<name>` (`a_rope_works`); persistent ids `<kind>_<room short>_<n>` (`anchor_s2_1`, `hoard_a_1`, `gate_s3_1`, `journal_b_1`, `station_lip`); unique game-wide, never changed once shipped to testers (a rename needs a save migration). Room set: E1 `l1/m1_shaft`, `dev/perf_worst`; E4 `l1/s1_lip` … `s5_hollow`, `a_rope_works`, `b_old_mine`, `c_sky_ledge`, `weaver_arena` (+ `.tscn`); E5 `hub/island`; E6 `l2/landing_arena`. [E1 / E4–E6]
AR27: `world/camera_rig.gd`: limits, downward lead, shake (the only allowed `randf`), gutter framing, scripted-moment hooks. `core/palettes.gd`: Layer 1 zone palettes, UI role colours (DESIGN.md tokens), zone cross-fade data. Rooms load on entry behind the transition; sprites, the shared light texture and fonts are preloaded; no threaded loading. [E1 / E4]

**Actors, light sensing, predators**

AR28: `actors/light_source.gd` (`LightSource`, group `light_source`, `kind` = `&"player"` / `&"flare"` / `&"cache"`, `radius()`), attached to the player, flares and the Ember Cache; drives its `PointLight2D` or sprite glow. [E1]
AR29: `rules/sensing.gd` (`Sensing`, static, pure, unit-tested): `can_notice()`, `can_sense()`, `can_stir()`, `pick_target()`; `NOTICE_MIN_RADIUS := 80.0`, `NOTICE_FACTOR := 1.6`; notice requires the predator inside `play_rect()` shrunk by the screen margin. Target = sensed light with the largest radius; ties go to the non-player light. [E1]
AR30: Lurker FSM `IDLE → TELEGRAPH → HUNT → RETURN`, querying `light_source` + `world.play_rect()` each tick. Stirring keeps it `IDLE` and exposes `stir` (0 closed, 1 half, 2 open) read by the gutter edge cue (and the E3 sound). `monitorable` is true only in `HUNT` with the player as target. Retarget flare/cache → player re-enters `TELEGRAPH`. [E1]
AR31: FSM convention: `enum State` + `match` + one `_enter(state)`, float countdowns in physics time, public `state`, UPPER_SNAKE values. Player stays flag-based (grounded, clinging, dashing, swinging) on `PlayerInput` intents. Actor contract: groups `player` / `enemy` / `predator` / `light_source` / `world`, `take_hit()` duck typing, crawler contact polled. Physics layers 1 world · 2 player · 3 (value 4) enemies/pogo-able · 4 (value 8) predators; Slash/Pogo mask 4, Hurtbox mask 12. [all]
AR32: Weaver: same light query; FSM `BRIGHT_RETREAT`, `DARK_DESCEND`, `BITE_TELEGRAPH`, `STUNNED`, `FLEE`, `RE_WEAVE`, `FALL`; owns `strand.gd` / `strand_anchor.gd` helper nodes (`actors/weaver/`). [E2 / E6]
AR33: Actor and object scripts: `actors/flare.gd`, `actors/spiderling.gd` (E2); `objects/lantern_anchor.gd`, `lift_station.gd`, `ember_cache.gd` (E1); `chain_gate.gd`, `ember_hoard.gd`, `journal_object.gd` (E4); `npc.gd` (E5); `silk_anchor.gd` (E6). [E1–E6]

**Input and devices**

AR34: `actors/player_input.gd` (`PlayerInput`, child of `Player`) samples `InputMap` once per physics tick into intents (`move`, `jump_pressed/held`, `attack_pressed`, `dash_pressed/held`, `light_tap`, `snuff_active`, `cling_held`, `interact`); owns the Light tap/hold machine (window from `Settings`), the Cling/Snuff toggle modes, the Quick Wick `instant_snuff` flag and real-time buffers so presses during hitstop are kept; `lock()` / `unlock()` for scripted moments. Lint matches `Input.` broadly outside `PlayerInput` and the UI kit. [E1]
AR35: Input actions use physical keycodes, snake_case verbs, one button per action, keyboard + gamepad; menus use `menu_confirm`, `menu_back`, `menu_tab_next` (not `ui_*`). `core/devices.gd` tracks the last-used device (glyph swap) and the session's active pad (disconnect-pause only for a pad in use; browser pads appear after a press). Window close (`NOTIFICATION_WM_CLOSE_REQUEST`) runs the Quit path. Rebinding edits `InputMap`, stored in `Settings` (E7). [E1 / E7]

**Clock, pause**

AR36: `core/clock.gd` (child of `Game`) is the only writer of `Engine.time_scale` = product of active requests × assist. `request(&"hitstop", 0.05, 0.075)`, `request(&"slowmo", 0.3, 0.5)`, `set_assist(0.8)` (E7). Requests use `create_timer(t, false, false, true)`: real time, counted down only while the tree is not paused (resolves the doc's `PROCESS_MODE_ALWAYS` wording in favour of V1). Death and `_exit_tree` clear all requests. Pause is `SceneTree.paused`; UI, HUD and the death card run `PROCESS_MODE_ALWAYS`; real-time visuals use `delta / Engine.time_scale`. [E1]

**Save and persistence**

AR37: `core/save_store.gd`: `user://slot_1..3.json` + `.bak`, `settings.json` (R15). All JSON is parsed with `JSON.new().parse()`, which prints no engine `ERROR:` on bad input (`JSON.parse_string()` and `ConfigFile` do, and would fail the test runner). Slot JSON `{"version", "meta", "slot", "dive"|null}`; meta = depth, best chain, play time, difficulty, last saved. Atomic write `.tmp` → re-read/parse → rename, keep `.bak`; load falls back to `.bak`. Integer version, `rules/migrations.gd` (`migrate_vN_to_vN1()` in order), newer-than-known saves rejected untouched; fixture `tests/fixtures/slot_v1.json` loaded by every later build; every format change ships a migration + fixture. [E1, every later epic]
AR38: Save triggers (R14): **resume saves** at a Lift Station rest, arriving home, and quitting at a lit anchor (writes `dive`: anchor id + carried; killed enemies not saved); **progress saves** at progress moments (difficulty change, purchase, story flag, phase checkpoint, boss defeat), which rewrite the slot's world progress but keep the last resume point and dive snapshot unchanged, so they never move where you wake or make carried embers safe. New Game writes the slot right after the difficulty step; slot delete removes `.json` + `.bak`. Failure: `Error` → `save_failed` → crossed save icon + "Not saved"; never crash or pause; retry at the next trigger and on quit to title; `push_warning` once per failure. Web: `OS.is_userfs_persistent()` at boot and before each save. `settings.json` carries its own version; corrupt/missing keys fall back to defaults and are rewritten. [E1]

**UI architecture**

AR39: `ui/screen_router.gd`: exactly one screen at a time, opening replaces, never stacks; global flow states (title / playing / paused / dead) are the current screen + `SceneTree.paused`. `ui/gutters.gd` binds to state signals and rebinds on `player_spawned`. UI writes only `Settings`; gameplay changes go through commands (`Game.save_now()`, `Game.load_slot(n)`, `world.fast_travel(id)`). [E1]
AR40: UI kit (`ui/kit/`, E1): MenuList, TabBar, EmberCursor, ConfirmStep, Toggle, Slider, GlyphPrompt. Theme built in code (`ui/theme_builder.gd`), no `.tres`. Screens (`ui/screens/`): `web_gate`, `title`, `slot_picker`, `difficulty_step`, `pause`, `options`, `death_card`, `station_menu`, `credits` (E1–E7); `map_tab` (E4); `speech_box`, `shop_list`, `journal_tab` (E5). [E1 → E7]
AR41: Strings: every player-facing string via `tr()` from `game/text/strings.csv` (English only in M2); commit the generated `.translation` + `.import`; keys UPPER_SNAKE with a domain prefix (`MENU_RESUME`, `DEATH_LURKER_LINE`, `TIER_NORMAL`). A test fails on any `tr()` key missing from `strings.csv`; `tools/export.sh` validates too. [E1]
AR42: Font: `game/fonts/fusion-pixel-8px-proportional-latin.otf` + `OFL.txt` + `LICENSES/`, release tag pinned at download, size 8, antialiasing/hinting off; licences ship in every build. [E1]

**Audio (E3)**

AR43: `Audio` autoload (`audio/audio.gd`, `PROCESS_MODE_ALWAYS`): a small SFX player pool (the only pooling allowed), positional players for lurker cues (pausable children), music stems. `audio/music_stems.gd`: `<layer>_pulse/melody/full.ogg` equal length, started together, looping, with a silent stem at −80 dB for sync; single-stem themes (`hub_theme`, `weaver_theme`) use the same player set. [E3]
AR44: Chain-reactive mixing: `chain.changed(count)` → layers (≥ 3, ≥ 6, ≥ 10) tween over 0.5 s; `chain.banked` → resolve chord, stems to 0 within 0.3 s; `player.died` → cut + dissonant tail; predator cue ducks ×0.5 (−6 dB). Final volume = layer × duck × music × master recomputed in one `_apply(i)`; tweens `set_ignore_time_scale(true)`. Pogo pitch `pow(2.0, mini(link, 12) / 12.0)` set before `play()`, verified in the web smoke. No bus effects (ADR-5); no audio before the web click-to-play gate. [E3]
AR45: SFX pipeline `tools/build_sfx.py` + `tools/sfx/<event>.txt` → `game/audio/sfx/<event>.wav` (build output). `tools/` writes only into `game/art/` and `game/audio/sfx/`. [E3]

**Lighting and performance**

AR46: ≤ 6 `PointLight2D` on screen, all sharing `art/light.png` via `texture_scale`; player and flares always keep theirs; lurker wall glow falls back to a sprite glow first; small glows (eye cores, cache core, embers, ledge rims) are unshaded sprites. Engine glow off until AR5 passes. `core/fx.gd` builds effects in code with cached materials, frees them on `finished`, uses `CPUParticles2D`, warms new effects at room load, and reads the accessibility gate. No pooling (except Audio), no `Thread`/threaded loading. [E1]

**Testing infrastructure**

AR47: `run_tests.sh` globs `tests/test_*.gd` + `tests/smoke_*.gd` and runs each through the scene runner `tests/runner.tscn` (tests extend `Node`, so autoloads, `preload` and `class_name` work; R17); it fails a test with no `PASS` line or running > 120 s, and fails on any `SCRIPT ERROR` / `ERROR:` line, keeps the `ok` / `FAIL` + `PASS` / `FAILED` format; other files in `tests/` are helpers. [E1]
AR48: `tests/test_lint.gd` (text scan of `game/scripts/`) fails on: `Engine.time_scale =` outside `clock.gd`; `Input.` outside `player_input.gd` and the UI kit; bare `print(` outside `core/log.gd`; `.free()`; `"/root/`; `KEY_F`; `randf`/`randi` outside camera shake; `Node` / `Input` / `Engine` / `Game.` in `rules/`; upper-layer class names in `core/`; `DevTools` outside `dev/` and `tests/`. Output `FAIL lint <file>:<line> <rule>`. [E1]
AR49: `tests/spec.gd` (preloaded, no `class_name`): `TELEGRAPH_MIN := 0.75`, `BOT_MIN_CHAIN := 5`, `BASE_LIGHT := 40.0` …, each with a GDD citation. Tests compare against Spec, never the tuning value under test; every new GDD guarantee gets a Spec const + test before the feature is done. [E1, every epic]
AR50: `tests/smoke_rooms.gd` (replaces `smoke_shaft`) loads every `rooms/**/*.txt` standalone and checks: validates; ids unique across all files; every lurker telegraph ≥ 0.75 s; no notice outside the play rect; Snuff/landing/cling in time drops a hunting lurker's lethality; base light 40 px never noticed; every hazard pit has a ledge or wall within a 1.5 s fall. `tests/smoke_bot.gd`: plain movement, no dash, chain ≥ 5 in every spine room, required chain at every gate, the exit backstop never fires on the bot's line. Also: stirring never leads to a hunt without an on-screen telegraph; HUD rebinds after death; unit tests `test_chain_state`, `test_health`, `test_sensing`, `test_tuning`, `test_saves`, migrations. Test data in `tests/rooms/` and `tests/fixtures/`, never exported; targets picked by position. [E1 harness; E4 content]

**Build, export, CI**

AR51: Committed `game/export_presets.cfg`: Windows, Linux, Web (single-threaded), templates pinned to 4.7.2; include filter `rooms/**/*.txt`; release presets exclude `rooms/dev/*` and `tests/*`; a debug web preset for the full smoke (save/reload markers) and `perf_worst`. [E1]
AR52: `tools/export.sh`: validate every room file and string key (any error stops the build) → headless export of the 3 targets → copy `OFL.txt` + `LICENSES/` → web download < 30 MB (plan B: custom web template with 3D disabled) → Playwright web smoke → `builds/<version>/` (gitignored). [E1, E7]
AR53: `tools/web_smoke/` (outside `game/`; `package.json` with Playwright pinned; Node 24; headless Chromium): boot → click-to-play gate → game starts → write a save → reload → save persists; check the scale for a simulated DPR; pogo pitch (E3). Debug web exports print `SMOKE boot ok` / `SMOKE save ok`; release gets a boot-only check. Manual web smoke on the laptop at every epic end and engine upgrade. [E1]

**Dev tools, logging, errors, scripted moments**

AR54: `scripts/dev/dev_tools.gd` (`DevTools`) added by `World._ready()` only when `OS.is_debug_build()`; entry args `-- --room=… --chain=… --hp=… --difficulty=…` (URL query on web debug); `scripts/dev/overlays.gd` on the backquote action cycles play rect + gutters / light radii + notice rings / exits + object ids / FPS + light count + Clock requests. No function keys. Nothing outside `dev/` and `tests/` references it. [E1; Weaver-arena entry E2]
AR55: `core/log.gd` static `Log` (not an autoload): `info` / `debug` / `enabled(cat)`, `[category] message`, categories `SAVE ROOM INPUT CLOCK LURKER WEAVER AUDIO UI` (unknown asserts), silent in release, enabled by `-- --log=lurker,clock`; hot paths log only inside `if Log.enabled(...)`. Errors: programmer → `assert`; content → pure validator + `push_error` + refuse to build; environment → `Error` + state signal, never a crash, pause or dialog. Never `free()`. [E1]
AR56: One script per scripted moment in `scripts/moments/` (`last_entry.gd` E4, `weaver_reveal.gd` E4/E6, `watching_departure.gd` E5, `the_fall.gd` E6, defeat slow-mo E6), using only Clock requests, `PlayerInput.lock()`, `World` camera hooks and `Audio` cues; no sequence runner in M2. [E4–E6]
AR57: Accessibility gate: `Settings.reduce_flashing` / `shake` / `reduced_motion` are read by `Fx`, camera shake, the invulnerability blink and UI easing only; no per-effect toggles. [E1]
AR58: Layout and boundaries: `scripts/` and `scenes/` share `core/ rules/ world/ actors/ objects/ moments/ ui/ audio/ dev/`; dependencies `rules/ ← core/ ← world, actors, objects, moments ← ui, audio ← dev`; snake_case files, PascalCase `class_name`, `_private`, UPPER_SNAKE consts, past-tense signals, `StringName` snake_case ids. [all]

**Architecture-doc inconsistencies to settle in the stories that touch them** (resolution proposed): Clock timers pausable per V1 (AR36); DevTools path `scripts/dev/dev_tools.gd`; RoomLoader API `load_room(id)` / `load_room_from_path(path)`; Tuning accessor `f()` / `flag()` (not `get`, which collides with `Object.get`); gear data in `rules/gear.gd`; export filter `rooms/**/*.txt`; cache signal on `SlotState`, not `DiveState`; lint matches `Input.` broadly; header id examples follow `<kind>_<room>_<n>`; a debug web preset exists; physics layers documented in the architecture.

### UX Design Requirements

Source: UX `DESIGN.md` + `EXPERIENCE.md` (2026-11-10/11). "The spines win": if a mock disagrees, the spine is the contract. D1–D15 are E1 defaults tagged `[ASSUMPTION — default, review]`.

#### Tokens

- UX-DR1: Reserved colour `chain-amber` = `#ffd27a`. It stays the same in every zone and is used only for the chain number, filled meter segments, the held ember icon and count, the bank popup and the ember cursor. Menu selection counts as the player's lantern, so amber is allowed in menus. Never use it for anything that is not the player's light. [UX: DESIGN → Colors > Reserved] [Owner: E1]
- UX-DR2: Reserved colour `predator-red` = `#d9473f`. It stays the same in every zone and is used only for the alert frame, the alert eye and the off-screen edge cue, and only on shapes. Never use it for damage, errors, low HP, decoration or text. The M1 alert colour `#ff594d` must be migrated to `#d9473f`. [UX: DESIGN → Colors > Reserved] [Owner: E1]
- UX-DR3: Layer 1 zone palettes, index 0 (darkest) to 3 (lightest), plus gutter:
  - Dusk (S1, A): `#2b1d14` `#6b4a2f` `#b08a5a` `#d8c3a0`, gutter `#18100b`.
  - Umber (S2–S3): `#1e1714` `#4a3a33` `#7d6a5c` `#a99a8c`, gutter `#110d0b`.
  - Cold violet (S4–S5, B, C): `#0d0b14` `#2a2440` `#4f5d75` `#a9b4c2`, gutter `#07060b`.
  [UX: DESIGN → Colors > Layer 1 zones] [Owner: E1 (tokens); E4 (applied across zones)]
- UX-DR4: Gutter fill = zone index 0 darkened to 55% (A2, mock value). [UX: DESIGN → front-matter colors; Assumptions A2] [Owner: E1]
- UX-DR5: Zone-role UI tokens, one map per zone (`components.zone-roles.<zone>`) with six roles: hp / label / empty / rule / surface / gutter.
  - Dusk: `#d8c3a0` / `#b08a5a` / `#836548` / `#6b4a2f` / `#2b1d14` / `#18100b`.
  - Umber: `#a99a8c` / `#8f7e70` / `#726258` / `#4a3a33` / `#1e1714` / `#110d0b`.
  - Violet: `#a9b4c2` / `#6e7b8f` / `#5c5c73` / `#2a2440` / `#0d0b14` / `#07060b`.
  - At runtime the code swaps in the active zone's map. These are UI only, never world art. Only amber and red stay constant.
  [UX: DESIGN → Colors > Zone-matched UI roles; components.zone-roles] [Owner: E1]
- UX-DR6: What each role is used for:
  - HP (index 3): full HP pips, carried count and icon, selected menu item, active tab, bank values.
  - Label (index 2, lightened where needed): gutter icons, idle menu items, idle tabs, bank labels, flare notch.
  - Empty (index 1, lightened): empty pip and segment outlines, chain number at 0.
  - Rule (index 1): 1 px rules and dividers.
  - Surface (index 0): menu background.
  - Gutter: gutter fill.
  [UX: DESIGN → Colors > Zone-matched UI roles] [Owner: E1]
- UX-DR7: Contrast floors are 4.5:1 for text and 3:1 for UI shapes.
  - Every role is checked against both the zone's gutter fill and its play area (zone index 0, which is also the menu surface).
  - A role that misses gets a UI-only override: blend toward index 3 by the smallest step that passes both, keeping the hue.
  - Required overrides (on gutter / on play area):
    - Umber label `#8f7e70`: +41%, 4.96 / 4.53.
    - Violet label `#6e7b8f`: +34%, 4.71 / 4.55.
    - Dusk empty `#836548`: +22%, 3.51 / 3.04.
    - Umber empty `#726258`: +42%, 3.32 / 3.03.
    - Violet empty `#5c5c73`: +39%, 3.11 / 3.01.
  - Unchanged roles that pass:
    - Dusk HP: 10.94 / 9.49.
    - Dusk label: 5.93 / 5.14.
    - Umber HP: 7.08 / 6.47.
    - Violet HP: 9.61 / 9.30.
  - Should be checked by an automated contrast test.
  [UX: DESIGN → Colors > Contrast floors; EXPERIENCE → Accessibility Floor] [Owner: E1]
- UX-DR8: Contrast of the constant colours (gutter / play):
  - `chain-amber` passes for text and shapes: 13.20 / 11.45 Dusk, 13.58 / 12.42 Umber, 14.19 / 13.72 Violet.
  - `predator-red` is for shapes only: 4.40 / 3.82, 4.53 / 4.14, 4.73 / 4.58.
  - The chain number at 0 (Empty colour, ≥ 24 px) counts as large text, so 3:1 applies.
  - Rules and dividers (index 1, 1.3–2.4:1) are decorative and exempt (A15).
  [UX: DESIGN → Colors > Contrast floors] [Owner: E1]
- UX-DR9: Edge-cue glow floor: at its peak the glow must reach 3:1 against zone index 0. That is about 83% predator red in Dusk (`#bb4038`, 3.03:1), 79% in Umber (`#b23d36`, 3.04:1) and 75% in Cold violet (`#a63834`, 3.01:1). The eye itself is solid predator red. [UX: DESIGN → Colors > Contrast floors] [Owner: E1]
- UX-DR10: Hub and Layer 2 palettes are still open. When they exist, add their UI role tokens; they must pass the same floors (O9). [UX: DESIGN → Colors > Layer 1 zones; EXPERIENCE → Open Q O9] [Owner: E5/E6]
- UX-DR11: UI font is Fusion Pixel Font 8px, proportional (latin build), SIL OFL 1.1.
  - Godot font size 8, antialiasing off, hinting off.
  - Metrics: cap 6 / x-height 4 / descender 2.
  - Digits are 5 px and uniform width, so counters don't jitter.
  - One pixel font for the HUD and all menus.
  [UX: DESIGN → Typography] [Owner: E1]
- UX-DR12: Type styles:
  - `hud-value`: 8 px / 8 px line.
  - `hud-value-large`: 16 / 16.
  - `menu-item`: 8 / 8, rows at 24 px pitch.
  - `body-line`: 8 px glyphs on a 12 px line pitch. Used by the death card, speech box, journal entries, slot details, controls reference and credits.
  [UX: DESIGN → Typography] [Owner: E1]
- UX-DR13: Chain numerals are hand-pixelled digits 0–9 at four heights, matched to Fusion:
  - 24 px for 0–2 links, 26 px for 3–5, 28 px for 6–9, 32 px for 10+.
  - Never scaled by fractions. Two digits at 32 px are about 42 px wide and must fit the 58 px usable gutter.
  - At a size step, the new size replaces the old in one frame, then the pop runs (D1).
  [UX: DESIGN → Typography] [Owner: E1]
- UX-DR14: Text placement:
  - No text in the gutters except numbers. Icons replace the old HP / EMBERS / CHAIN labels.
  - No text baked into sprites.
  - All player-facing text is rendered from the string table, from day one.
  [UX: DESIGN → Typography; EXPERIENCE → Voice and Tone, Localization] [Owner: E1]
- UX-DR15: Text outline (D2): 1 px on 4 sides (no diagonals), in the zone surface colour.
  - Only for text and cues drawn over the play area: bank popup, death card text, "Not saved" note, cling cue.
  - Glyph prompts are exempt because they have a backing.
  - Gutter and menu text get no outline.
  [UX: DESIGN → Typography, components.text-outline] [Owner: E1]
- UX-DR16: Font licence:
  - Every build, web included, ships `OFL.txt` and the upstream `LICENSES/` folder.
  - The credits name the font.
  - The font is never sold on its own, and a modified copy drops the Reserved Font Name.
  [UX: DESIGN → Typography; EXPERIENCE → Notes for Other Docs] [Owner: E1 (shipping files); E7 (credits text)]
- UX-DR17: Font coverage is Latin-1 + Latin Extended-A. It lacks stacked Vietnamese marks and Cyrillic. M2 ships English only; a later localisation could use the Fusion 10/12 px builds. [UX: DESIGN → Typography; EXPERIENCE → Localization] [Owner: E1]
- UX-DR18: Canvas and grid:
  - Native 480×270, whole-number scaling only (×2, ×3, ×4), nearest filtering, letterboxed. 8 px grid.
  - Two 60 px side gutters frame a 360 px play area.
  - Usable gutter width is 58 px: left gutter x 1–58, right gutter x 421–478.
  - Menus use the same 360 px column, x 60–420.
  [UX: DESIGN → Layout & Spacing] [Owner: E1]
- UX-DR19: HUD spacing tokens:
  - Icons and values: icon-top 10, value-top 24, gutter-icon 7, ember-icon 5.
  - Pips and embers: pip-size 7, pip-pitch 10, ember-row-pitch 12, ember-text-offset 8.
  - Meter: segment 12×6, pitch 9, base-y 258.
  - Notch 3×6, notch-offset 2. Grace bar width 2, gap 2.
  - Alert: frame 1, eye-top 68, eye 7×5.
  - Edge cue: inset 2, margin 8. Cling cue 2×8, gap 2. Hatch pitch 3.
  - Glyph: size 12, max-width 32, lift 4, clamp 4.
  - Autosave icon 7 at top 252. Chain pop 1. Text outline 1. Popup lift 6.
  - Large HUD: large-icon 14, large-ember-icon 10, large-stack-top 120.
  [UX: DESIGN → front-matter spacing] [Owner: E1]
- UX-DR20: Menu spacing tokens:
  - Rows and text: menu-row-pitch 24, menu-text-x 64, cursor-gap 9, menu-top 64, title-menu-top 104, line-pitch 12.
  - Tabs: left 60, top 18, pitch 70, underline-y 30, divider-y 36.
  - Bank summary: summary-row-pitch 14, bank-left 280, bank-right 420, bank-top 72, bank-divider-y 118, bank-stats-top 126.
  - Controls reference: top 172, glyph-x 120, row-pitch 14.
  - Pause note: top 136, width 208.
  - Options: value-right 412, toggle-x 387, toggle-box 7, toggle-text-width 15, control-text-gap 3, slider segment 4×6 at pitch 5.
  - Other: slot-row-pitch 40, death-text-width 328, station-text-x 80, station-total-top 40.
  [UX: DESIGN → front-matter spacing] [Owner: E1]
- UX-DR21: Shape rules:
  - All corners square (radius 0). Shapes are whole-pixel rectangles. Rules and outlines are 1 px.
  - The ember is a 5×5 blob with rows 3-5-5-5-3.
  - Empty states are always a 1 px outline of the full shape in the zone Empty colour, never a dim fill.
  - No shadows, gradients or rounded corners. The only glow is the off-screen edge cue.
  - The menu's "lantern glow" is the ember cursor alone: no halo, no light band.
  [UX: DESIGN → Shapes, Elevation & Depth, Do's and Don'ts] [Owner: E1]
- UX-DR22: Default icon art (D4), `X` = drawn pixel:
  - Heart 7×7: `.XX.XX.|XXXXXXX|XXXXXXX|XXXXXXX|.XXXXX.|..XXX..|...X...`
  - Chain link 7×7: `..XXX..|.X...X.` ×5 `|..XXX..`
  - Eye open 7×5: `..XXX..|.X...X.|X..X..X|.X...X.|..XXX..`
  - Eye half 7×3: `.XXXXX.|X..X..X|.XXXXX.`
  - Eye closed 7×1: `XXXXXXX`
  - Lantern 7×7: `..XXX..|.X...X.|.X.X.X.|.X.X.X.|.X...X.|.XXXXX.|..X.X..`
  - Crossed lantern: adds a 1 px diagonal from top-left to bottom-right.
  - The art may be redrawn to match Fusion.
  [UX: DESIGN → Shapes] [Owner: E1]
- UX-DR23: Depth layers:
  1. World (play area).
  2. Gutters and in-world UI: glyph prompts, cling cue, off-screen edge cue.
  3. Full-screen menus, which replace the view and never stack.
  - The speech box sits inside the play area.
  - The station menu and the death card replace or dim only the play area, and the gutters stay.
  [UX: DESIGN → Elevation & Depth] [Owner: E1]
- UX-DR24: Motion and timing values the UI uses:
  - Chain pop: 1 px up for 67 ms (4 frames).
  - Ember cursor ease: 120 ms.
  - Zone cross-fade: 500 ms.
  - Bank popup rise and fade: 600 ms.
  - Death-card ember count: 500 ms.
  - Menu repeat: 400 ms, then every 80 ms.
  - Alert pulse ≤ 2 Hz, and at least 400 ms per alert.
  - Invulnerability blink: 2.5 Hz for 0.6 s.
  - Autosave icon: at least 1000 ms.
  - "Not saved" note: 3 s.
  - Death card: skip lockout 0.6 s, auto-advance about 3 s.
  [UX: EXPERIENCE → Game Feel & Juice, Component/State Patterns; DESIGN → Typography] [Owner: E1]
- UX-DR25: Menu screens fill with the current zone's surface. Outside play they use Dusk: title, Options opened from the title, slot picker, credits, click-to-play gate (D13). [UX: DESIGN → Components > Menu screen] [Owner: E1]

#### Components

##### HUD-wide rules
- UX-DR26: HUD posture: always visible, compact, non-diegetic, in the side gutters. It never fades and nothing hides during play. The M1 bottom controls bar is removed; its contents move to the Pause tab controls reference. [UX: EXPERIENCE → Foundation, HUD & Diegetic UI] [Owner: E1]
- UX-DR27: Every HUD element stays inside the gutters. Only these may cover the play area:
  - in-world UI: glyph prompts, cling cue, off-screen edge cue, bank popup, "Not saved" note;
  - the speech box;
  - the death card;
  - the station menu.
  [UX: DESIGN → Do's and Don'ts] [Owner: E1]
- UX-DR28: HUD hierarchy is chain number first, then HP, then embers. Deposited embers never show on the dive HUD; they show only at Lift Stations, in shops and in the Pause tab bank summary. [UX: EXPERIENCE → HUD & Diegetic UI] [Owner: E1]
- UX-DR29: HUD values are never recoloured for alerts. Pips, numbers and meter keep their colours; the alert is shown by the gutter frame and eye only. [UX: DESIGN → Do's and Don'ts; EXPERIENCE → Component Patterns] [Owner: E1]

##### Gutter HUD components
- UX-DR30: Gutter:
  - A flat strip 60 px wide in the zone gutter colour.
  - An inner 1 px rule on the play-area edge and an outer 1 px rule on the letterbox edge (O17), both in the zone rule colour (index 1).
  - Present in every scene, including the hub and the Weaver arena.
  [UX: DESIGN → Components > Gutter, Layout & Spacing; EXPERIENCE → Component Patterns] [Owner: E1 (arena E2, hub E5)]
- UX-DR31: Gutter icons, static, in the label colour:
  - Heart: left gutter, 7×7, centred x 30, top y 10.
  - Chain link: right gutter, 7×7, centred x 450, top y 10.
  - No ember section icon: y 80 stays empty, and the held/carried row icons act as the header.
  [UX: DESIGN → Layout & Spacing > Gutter HUD coordinates] [Owner: E1]
- UX-DR32: HP pips:
  - 4 vertical 7×7 squares at 10 px pitch: x 26, y 24 + 10·n for n = 0–3, ending at y 60.
  - Full = filled in the HP colour. Empty = 1 px outline in the Empty colour.
  - Updates on hit and heal; a lost pip becomes an outline.
  [UX: DESIGN → Components > HP pip; EXPERIENCE → Component Patterns] [Owner: E1]
- UX-DR33: Ember counter, two rows in the left gutter:
  - Held row: icon at x 14, y 96, `+N` text at x 22, y 95, both amber. The icon flickers while held > 0. Held counts up with hits.
  - Carried row: solid icon (no flicker) at x 14, y 108, count at x 22, y 107, both in the HP colour.
  - On bank, held moves to carried. On rest, carried flies to the bank.
  - Must fit `+999` (about 20 px, x 22–42) and `+1240` (about 25 px, to x 47).
  [UX: DESIGN → Components > Ember counter, Typography > Measured widths; EXPERIENCE → Component Patterns] [Owner: E1]
- UX-DR34: Chain number:
  - Right gutter, centred x 450, top y 24; ends by y 56 at 32 px.
  - Amber digits; 0 shows in the Empty colour.
  - Sizes step 24 → 26 → 28 → 32 px at chain 3 / 6 / 10.
  [UX: DESIGN → Components > Chain number, Layout & Spacing] [Owner: E1]
- UX-DR35: Chain meter:
  - 20 vertical 12×6 segments at 9 px pitch, at x 444. Segment n top = y 258 − 9·(n − 1): segment 1 spans y 258–263, segment 20's top is y 87.
  - Fills bottom to top, one segment per link, up to the cap of 20.
  - Filled = amber. Empty = 1 px outline in the Empty colour.
  - Links stay lit during cling.
  [UX: DESIGN → Components > Chain meter, Layout & Spacing] [Owner: E1]
- UX-DR36: Cling grace bar (D3):
  - A 2 px vertical bar at x 440–441, 2 px left of the meter, alongside the lit segments, in the HP colour.
  - Shown only while clinging. It appears full and drains top-down over the cling grace (GDD 1.0 s per link).
  - A pogo hit refills it. When it empties, the chain breaks and banks.
  [UX: DESIGN → Components > Cling grace bar; EXPERIENCE → Component Patterns] [Owner: E1]
- UX-DR37: Flare notch:
  - A static 3×6 mark in the label colour at x 458, beside segment 2 (y 249–254), 2 px right of the meter.
  - Once the meter reaches it (chain ≥ 2), Flare Toss is allowed. It stays visible at chain 0.
  [UX: DESIGN → Components > Flare notch; EXPERIENCE → Component Patterns, State Patterns] [Owner: E1]
- UX-DR38: Flare cost hatch:
  - 1 px diagonal lines (top-left to bottom-right) every 3 px, in the zone gutter colour, over the lit segments a toss would remove (the top half of the lit stack, rounded per GDD Flare Toss).
  - Shown only while a lurker is stirring or hunting AND the chain is ≥ 2. Hides at once when either stops being true.
  - There is no "show while V held" variant.
  [UX: DESIGN → Components > Flare cost hatch; EXPERIENCE → Component Patterns] [Owner: E1]
- UX-DR39: Alert frame:
  - A 1 px predator-red border around each gutter's edges, on both gutters, drawn over the inner and outer rules.
  - Shows while a lurker telegraph runs, pulsing at 2 Hz or slower, for at least 400 ms.
  - Overlapping telegraphs merge: the frame stays until the last one ends, and the pulse does not restart (D8).
  - Under reduce flashing it is solid with no pulse.
  [UX: DESIGN → Components > Alert frame; EXPERIENCE → State Patterns > Alert] [Owner: E1]
- UX-DR40: Alert eye: the open-eye art (7×5, predator red) in the right gutter, centred x 450, top y 68. It shows and hides with the alert frame. [UX: DESIGN → Components > Alert eye; EXPERIENCE → Component Patterns] [Owner: E1]
- UX-DR41: Autosave icon (D11):
  - A 7×7 lantern in the HP colour, left gutter, centred x 30, top y 252.
  - Shown while saving for at least 1000 ms, steady (no blink).
  - On failure it becomes the crossed lantern and stays crossed until a save succeeds.
  - At the same time the field note "Not saved" shows for 3 s at the bottom-left of the play area (x 64, level with the icon), in the HP colour with the text outline.
  - The save retries at the next rest.
  [UX: DESIGN → Components > Autosave icon; EXPERIENCE → Component Patterns, State Patterns] [Owner: E1]

##### In-world UI components
- UX-DR42: Cling cue:
  - A 2×8 vertical bar 2 px outside the player sprite, on the side away from the wall, with its top level with the sprite's head. HP colour with the text outline.
  - Appears full when a cling starts, drains top-down in step with the grace bar, refills on a pogo hit, and hides when the cling ends.
  [UX: DESIGN → Components > Cling cue, In-world UI positions; EXPERIENCE → Component Patterns] [Owner: E1]
- UX-DR43: Off-screen edge cue:
  - A 7×5 predator-red eye 2 px inside the play-area edge (x 62 left, x 411 right), on the play-area side of the gutter rule.
  - Level with the lurker, tracking its height, clamped 8 px from the top and bottom of the play area. Shows on the side where a lurker stirs.
  - The eye steps closed → half → open as the lurker stirs.
  - A red glow goes with it, pulsing at 2 Hz (A12) and never dropping below the 3:1 glow floor. The glow is never shown alone.
  [UX: DESIGN → Components > Off-screen edge cue, In-world UI positions, Shapes; EXPERIENCE → Component Patterns] [Owner: E1 (stirring sound E3)]
- UX-DR44: Glyph prompt (D5):
  - A 12 px square keycap: 1 px outline and 8 px label in the HP colour, filled with the zone surface as a backing (no text outline).
  - Long keys (Esc, Enter, Space) widen to the label plus 4 px, up to 32 px. Arrows are 5×5 arrow icons.
  - Gamepad face buttons use the same box with the corner pixels removed and a generic letter (A, B, X, Y). Sticks and d-pad use 5×5 direction icons. No brand colours.
  - Centred above the object, bottom edge 4 px above the object's top, clamped 4 px inside the play area (x 64–416, y ≥ 4).
  - Appears in range and hides out of range at once, with no bob. Follows the last-used device.
  [UX: DESIGN → Components > Glyph prompt, In-world UI positions; EXPERIENCE → Component Patterns] [Owner: E1]
- UX-DR45: Bank popup (kept from M1):
  - Amber text `x{links} +{embers}` (e.g. "x12 +24", 33 px wide), 8 px, or 10 px at 10+ links, with the text outline.
  - Starts with its bottom edge 6 px above the top of the player sprite, centred on it.
  [UX: DESIGN → Components > Bank popup, In-world UI positions] [Owner: E1 (implied by HUD v2)]

##### Menu kit components
- UX-DR46: Menu item:
  - `menu-item` type, rows at 24 px pitch, text at x 64.
  - Selected = HP colour, idle = label colour, no glow.
  - Up/down moves the selection.
  [UX: DESIGN → Components > Menu item; EXPERIENCE → Component Patterns] [Owner: E1]
- UX-DR47: Ember cursor:
  - A 5×5 amber ember, 9 px left of the selected item's text, flickering by 1 px.
  - Follows the selection with a 120 ms ease; jumps instead under reduced motion.
  [UX: DESIGN → Components > Ember cursor; EXPERIENCE → Component Patterns] [Owner: E1]
- UX-DR48: Tab bar:
  - Labels from x 60, top y 18, at 70 px pitch.
  - Active = HP colour with a 1 px underline at y 30. Idle = label colour.
  - A full-width 1 px divider in the rule colour at y 36, across x 60–420.
  - Switch with Q / E or LB / RB; wraps.
  - Tabs that have not landed are hidden, not disabled, in Pause and Options alike (A6).
  [UX: DESIGN → Components > Tab, Menu positions; EXPERIENCE → Component Patterns] [Owner: E1]
- UX-DR49: Options controls (D12):
  - Values are right-aligned at x 412.
  - Toggle: a 7 px box at x 387 plus "On" / "Off" in a 15 px text slot, 3 px from box to text. On = filled in the HP colour; Off = 1 px outline in the Empty colour.
  - Slider: 10 segments of 4×6 at 5 px pitch (49 px). Filled = HP colour, empty = outlines, value number to the right.
  - Choice list: value text between 3×5 arrows in the label colour; an arrow hides at the end of the list.
  - On/Off and choice text use the label colour, and the HP colour on the selected row.
  - Toggles flip on confirm. Sliders and choices change with left/right. Changes apply at once (A13).
  [UX: DESIGN → Components > Options control; EXPERIENCE → Component Patterns] [Owner: E1]
- UX-DR50: Confirm step:
  - Replaces the current menu's items in place: no box, no stacking.
  - One `body-line` question in the HP colour at y 64, then No / Yes as menu items on the next two rows. No is selected by default.
  - Used by Quit, slot overwrite and slot delete.
  [UX: DESIGN → Components > Confirm step, Menu positions] [Owner: E1]
- UX-DR51: Bank summary:
  - Read-only, no heading. Rows: Deposited, Carried, Held, then Depth and Best chain.
  - Labels on the left in the label colour; values right-aligned in the HP colour; the held value in amber. Rows at 14 px pitch.
  - Placed at x 280–420 from y 72, with a 1 px divider at y 118 and the stats from y 126.
  [UX: DESIGN → Components > Bank summary, Menu positions; EXPERIENCE → Component Patterns] [Owner: E1]
- UX-DR52: Controls reference:
  - Read-only, two columns: action name in the label colour at x 64, binding glyph in the HP colour at x 120 (glyph prompt art).
  - `body-line` type, rows at 14 px pitch (12 px keycaps need more than the body pitch), from y 172.
  - Lists the current bindings for the last-used device.
  [UX: DESIGN → Components > Controls reference, Menu positions; EXPERIENCE → Component Patterns] [Owner: E1]
- UX-DR53: Pause note:
  - The save-failure explanation in `body-line`, HP colour, no icon, at x 64, y 136, wrapped to 208 px so it clears the bank column.
  - Example copy: "Saves are blocked. Allow site storage for this page, then rest again."
  [UX: DESIGN → Components > Pause note; EXPERIENCE → State Patterns > Save failed] [Owner: E1]

#### Screens

##### Copy and voice (all screens)
- UX-DR54: Voice is terse field notes: short, factual, slightly ominous, never tutorial-sounding.
  - Menu labels are one or two words (Resume, Options, Load, Quit, Descend).
  - Errors never show codes (e.g. "Controller disconnected").
  [UX: EXPERIENCE → Voice and Tone] [Owner: E1]
- UX-DR55: Copy rule (O16): death lines, tips and cues name the shape (eye, glow, frame), never the colour. Example: "Watch the edge for an opening eye." [UX: EXPERIENCE → Voice and Tone] [Owner: E1]
- UX-DR56: Never call the game "roguelike" or "Downwell-like" in any UI or store text. Never show a completion percentage. [UX: EXPERIENCE → Inspiration & Anti-patterns; DESIGN → Do's and Don'ts] [Owner: E1 (rule); E7 (store text)]

##### Click-to-play gate (web)
- UX-DR57: The gate shows on web page load, before the title.
  - One `body-line` line, "Click to play", in the HP colour on the Dusk menu surface, centred at x 240, y 131. No gutters.
  - Waits for the first click or key, which gives the game focus and unlocks audio. No audio before it.
  [UX: DESIGN → Components > Click-to-play gate, Menu positions; EXPERIENCE → Component Patterns, State Patterns > Web cold load] [Owner: E1 (A3)]
- UX-DR58: If the window is below ×2, the gate adds a second line, "Small window. Try fullscreen.", in the label colour. The two lines sit at y 125 and 137. [UX: DESIGN → Menu positions; EXPERIENCE → Component Patterns] [Owner: E1]

##### Title
- UX-DR59: Title layout:
  - Logo over a dark, slowly scrolling live shaft. No gutters, Dusk surface.
  - Items Continue / New Game / Load / Options / Quit, first row at y 104, then 24 px pitch, with the ember cursor.
  - Logo art is open (O19); E1 uses a text placeholder.
  [UX: DESIGN → Components > Title screen, Menu positions; EXPERIENCE → Information Architecture] [Owner: E1 (A3); logo E7]
- UX-DR60: Title states:
  - First launch with no save: Continue and Load are hidden and the cursor starts on New Game.
  - With a save: the cursor starts on Continue.
  [UX: EXPERIENCE → Component Patterns > Title screen] [Owner: E1]
- UX-DR61: Title routing:
  - Continue loads the most recent slot.
  - New Game → Slot picker → Difficulty step → Play.
  - Load → Slot picker → Play.
  - Options → Options (Dusk).
  - Quit is PC only (A5), has no confirm, and is hidden on web.
  [UX: EXPERIENCE → Information Architecture] [Owner: E1]

##### Slot picker
- UX-DR62: Slot picker layout:
  - 3 slot rows at 40 px pitch from y 64.
  - Line 1: "Slot N" as a menu item.
  - Line 2, 12 px below, in `body-line` and the label colour: depth · best chain · play time (h:mm) · difficulty, e.g. "Depth S3 · Best chain 17 · 2:14 · Normal".
  [UX: DESIGN → Components > Slot picker, Menu positions] [Owner: E1]
- UX-DR63: An empty slot reads "Slot N — Empty" (e.g. "Slot 3 — Empty") in the label colour, with no details line. [UX: EXPERIENCE → State Patterns > Empty slot, Component Patterns] [Owner: E1]
- UX-DR64: Slot picker behaviour from New Game:
  - The cursor starts on the most recent slot, or slot 1.
  - An empty slot goes to the difficulty step.
  - A filled slot asks "Overwrite slot N?" (confirm step, No default).
  - Back returns to the title.
  [UX: EXPERIENCE → Component Patterns > Slot picker] [Owner: E1]
- UX-DR65: Slot picker behaviour from Load:
  - The cursor skips empty slots.
  - C (keyboard) or Y (gamepad) on a filled slot asks "Delete slot N?" (No default).
  - Back returns to the title.
  - The save system must support 3 slots, slot delete and a Load path from the title.
  [UX: EXPERIENCE → Component Patterns > Slot picker; Notes for Other Docs] [Owner: E1]

##### Difficulty step
- UX-DR66: Difficulty step:
  - Three menu items, Easy / Normal / Hard, plus one `body-line` text block, then Play.
  - The text says only what death costs on each tier, and that difficulty can be changed later in Options.
  - It never uses words like "casual" or "hardcore".
  [UX: DESIGN → Components > Difficulty step; EXPERIENCE → Information Architecture, Voice and Tone] [Owner: E1]
- UX-DR67: Difficulty changes only death cost. It never changes telegraphs. [UX: EXPERIENCE → Accessibility Floor] [Owner: E1]

##### Pause
- UX-DR68: Opening Pause:
  - Triggers: Esc or P, Start on gamepad, window focus loss (auto-pause on web), and disconnect of a pad that was in use.
  - The game stops and the Pause tab opens.
  - Pause replaces the view and never stacks.
  [UX: EXPERIENCE → Information Architecture, State Patterns > Paused] [Owner: E1]
- UX-DR69: Pause tab bar is Pause | Map | Journal, with unlanded tabs hidden. In E1 the bar holds Pause alone; Map appears in E4 and Journal in E5. [UX: EXPERIENCE → Options tabs, Information Architecture] [Owner: E1 (Pause), E4 (Map), E5 (Journal)]
- UX-DR70: Pause tab contents:
  - Resume / Options / Quit from y 64 at 24 px pitch.
  - The bank summary (UX-DR51) and the controls reference (UX-DR52).
  - The pause note (UX-DR53) when a save has failed.
  [UX: EXPERIENCE → Information Architecture; DESIGN → Menu positions] [Owner: E1]
- UX-DR71: Closing Pause: Esc, P, or Back on the Pause tab; Start, or B on the Pause tab. Options opens from Pause and returns to Pause. [UX: EXPERIENCE → Menu bindings, Information Architecture] [Owner: E1]
- UX-DR72: Quit from the Pause tab (D10):
  - Uses the confirm step "Quit to title?" No / Yes, with No selected.
  - Away from a lit anchor or station it adds the line "You will wake at the last rest."
  - Yes returns to the title. Quitting at a lit anchor autosaves.
  [UX: EXPERIENCE → Information Architecture, State Patterns > Autosave] [Owner: E1]
- UX-DR73: "Controller disconnected" pause: auto-pause with that line when a pad in use is lost mid-play, and glyphs switch to keyboard. Reconnecting the pad or pressing any key resumes, with game state (including the chain) unchanged. [UX: EXPERIENCE → State Patterns > Gamepad disconnected, J6] [Owner: E1]

##### Options
- UX-DR74: Options has 5 tabs: Game / Video / Audio / Controls / Accessibility, plus a Credits entry.
  - Reached from the Title and the Pause tab.
  - Unlanded tabs are hidden. Rows start at y 64.
  [UX: EXPERIENCE → Information Architecture, Options tabs; DESIGN → Menu positions] [Owner: E1]
- UX-DR75: Game tab: Difficulty (Easy / Normal / Hard), changeable at any time. [UX: EXPERIENCE → Options tabs] [Owner: E1]
- UX-DR76: Accessibility tab, E1 settings:
  - Reduce flashing (toggle).
  - Screen shake (on/off).
  - Reduced motion (toggle).
  - Light tap window (choice: 0.12 / 0.2 / 0.3 s, default 0.12; A10).
  - Cling toggle (Off by default).
  - Snuff toggle (Off by default).
  [UX: EXPERIENCE → Options tabs, Accessibility Floor] [Owner: E1]
- UX-DR77: Audio tab: volume sliders. Mono audio and separate sliders are open (O14). [UX: EXPERIENCE → Options tabs, Open Q O14] [Owner: E3]
- UX-DR78: Video tab: Brightness (4 levels), Fullscreen, Scale. This replaces the M1 F1 brightness hotkey. Brightness ships earlier, in Options > Accessibility from E1, and moves here in E7 (R1). [UX: EXPERIENCE → Options tabs, Accessibility Floor] [Owner: E7; E1 for the Accessibility entry]
- UX-DR79: Controls tab: rebinding of every action, keyboard and gamepad. [UX: EXPERIENCE → Options tabs, Input Schemes > Rules] [Owner: E7]
- UX-DR80: Accessibility tab, E7 additions:
  - Large HUD.
  - Text scale (menus, speech, journal).
  - Game-speed and timing assists, as separate settings, not difficulty. Runs that use them are kept out of Guild records.
  - Visual sound cues: on-screen markers for predator sounds (A8).
  [UX: EXPERIENCE → Options tabs, Accessibility Floor] [Owner: E7]

##### Death card
- UX-DR81: Death card layout:
  - On HP 0: a short fade, then the play area dims to the zone surface at 70%. The gutters stay.
  - The death line is centred in the play area, 328 px wide (16 px margins), vertically centred, in `body-line` with the text outline.
  - The cause is in the HP colour and the tip in the label colour.
  [UX: DESIGN → Components > Death card, In-world UI positions; EXPERIENCE → State Patterns > Death] [Owner: E1]
- UX-DR82: Tier line: a third body line under the tip, in the label colour.
  - Normal: "Embers left below. Once."
  - Hard: "Nothing left below."
  - Easy: no line.
  - The death line itself is the same on every tier.
  [UX: DESIGN → components.death-card; EXPERIENCE → Death card by difficulty, Voice and Tone] [Owner: E1]
- UX-DR83: Cache gone (Normal only, dying again before recovering the cache): a line after the tier line says the cache is gone. Example copy (A9): "The cache went dark." [UX: EXPERIENCE → State Patterns > Cache lost, Voice and Tone] [Owner: E1]
- UX-DR84: Ember losses show in the left gutter:
  - The held and carried rows count to their new values over 500 ms.
  - A row that lost everything shows its icon as an outline.
  - A held row at zero shows `+0`; on Easy its icon stays solid and still.
  - Per tier: Easy moves held into carried (the gutter shows the new carried total). Normal loses held and drops carried as an Ember Cache. Hard loses both.
  [UX: DESIGN → Components > Death card; EXPERIENCE → Death card by difficulty] [Owner: E1]
- UX-DR85: Death card timing:
  - Buttons held at the moment of death are ignored.
  - A fresh press skips the card, but only after 0.6 s.
  - The card auto-advances after about 3 s.
  - Then respawn at the last lit anchor or station with full HP.
  [UX: EXPERIENCE → State Patterns > Death, Interaction Primitives] [Owner: E1]
- UX-DR86: Death line content is the cause plus how to avoid it, e.g. "Lurker. It waits where the light is dim. Watch the edge for an opening eye." Every death is stored from E1 as its cause id + room id, so the E7 Journal death log can show its lines. [UX: EXPERIENCE → Voice and Tone, State Patterns > Death, Notes for Other Docs] [Owner: E1 (store), E7 (display)]
- UX-DR87: Map marks after death: Easy marks the last death point only; Normal marks the Cache and the last death point; Hard marks the last death point only. [UX: EXPERIENCE → Death card by difficulty] [Owner: E4]

##### Lift Station rest and station menu
- UX-DR88: One-press rest: a single ↓ at a Lift Station runs the whole sequence, with no menu until it ends:
  1. full heal;
  2. embers fly into the bank while the deposited total counts up at the top of the play area;
  3. autosave icon;
  4. station menu.
  [UX: EXPERIENCE → State Patterns > Rest, Interaction Primitives, Game Feel & Juice] [Owner: E1 (placeholder), E4 (full)]
- UX-DR89: Station menu (D14):
  - Replaces the play area only; the gutters stay, so the healed HP shows. Surface fill.
  - Deposited total row at x 80, y 40, value right-aligned at x 400.
  - Items Descend / Fast travel / Leave from y 64 at 24 px pitch, text at x 80 so the cursor stays out of the gutter.
  - The cursor starts on Descend. Back = Leave.
  [UX: DESIGN → Components > Station menu, Menu positions; EXPERIENCE → Component Patterns] [Owner: E1 (placeholder), E4 (full)]
- UX-DR90: Fast travel list:
  - Replaces the station items in place.
  - Order: hub first, then stations top to bottom, excluding the current station and unlit ones. In M2 Layer 1 every lit station counts (none is broken).
  - Back returns to the station menu.
  [UX: EXPERIENCE → Component Patterns > Station menu] [Owner: E4 (hub entry E5)]

##### Speech box and shop (hub NPCs)
- UX-DR91: Speech box:
  - Opens on ↓ at an NPC.
  - Sits at the bottom of the 360 px play area, with a name tag, one line at a time, no portraits, `body-line` type.
  - Confirm advances.
  - Frame, height, name-tag style, reveal (typewriter or instant), skip rules and line length are open (O5).
  - Mock before build via gds-ux Update.
  [UX: DESIGN → Components > Speech box; EXPERIENCE → Component Patterns, Open Q O5] [Owner: E5]
- UX-DR92: Shop list:
  - Menu items with the ember cursor, the deposited total and prices.
  - Layout, buy confirm and the can't-afford response are open (O6).
  - Mock before build.
  [UX: DESIGN → Components > Shop list; EXPERIENCE → Component Patterns, Open Q O6] [Owner: E5]

##### Map tab
- UX-DR93: Map tab content:
  - Room boxes with doors.
  - Rooms the Cartographer revealed but the player hasn't visited are dotted outlines.
  - Icons for stations, anchors, the Ember Cache and chain gates.
  - The Ember Cache and the last death point are marked automatically.
  - Per-layer reward counts, with no % total.
  [UX: DESIGN → Components > Map tab; EXPERIENCE → Component Patterns] [Owner: E4]
- UX-DR94: Map tab controls:
  - Pan with arrows or stick.
  - Two zoom levels: layer view and close view.
  - Up to about 10 player pins.
  - Room colours, icon art, pin controls and the empty-map state are open (O3, O7).
  - Mock before build via gds-ux Update.
  [UX: EXPERIENCE → Component Patterns, Epic Rollout, Open Q] [Owner: E4]

##### Journal tab, Guild records, Credits
- UX-DR95: Minimal Journal tab:
  - Creature entries (sketch, how it hunts, how to beat it) in `body-line`, e.g. "Lurker. Waits where the light is dim."
  - Entries the Naturalist pays for carry a "new" mark.
  - Entry layout, mark art and the empty state are open (O7). Mock before build.
  [UX: DESIGN → Components > Journal tab; EXPERIENCE → Component Patterns, Voice and Tone] [Owner: E5]
- UX-DR96: Full Journal: death log grouped by cause, lore notes plus Memorial Wall names, Guild records, polish. [UX: EXPERIENCE → Component Patterns > Journal tab, Epic Rollout] [Owner: E7]
- UX-DR97: Guild records board:
  - Shows deepest depth, best chain, most embers banked in one chain, and deaths.
  - Runs that use timing assists are excluded.
  - Whether it is an in-world board or a menu panel is open (O7).
  [UX: DESIGN → Components > Guild records board; EXPERIENCE → Component Patterns] [Owner: E5]
- UX-DR98: Credits screen:
  - `body-line` text on the Dusk menu surface, including the AI disclosure line and the font credit.
  - Scroll or page through; Back returns to Options.
  [UX: DESIGN → Components > Credits screen; EXPERIENCE → Component Patterns] [Owner: E7 (A4)]

##### Boss (Weaver) UI
- UX-DR99: The Weaver has no health bar. Its health is diegetic: segments fray and fall off, and threads sag. The gutters stay in the arena. [UX: EXPERIENCE → HUD & Diegetic UI, Inspiration & Anti-patterns, Epic Rollout] [Owner: E2 (prototype), E6 (final visuals)]
- UX-DR100: Debug entry into the Weaver arena, dev builds only. [UX: EXPERIENCE → Epic Rollout] [Owner: E2]
- UX-DR101: Post-boss return flow to the hub, and the phase checkpoint. [UX: EXPERIENCE → Epic Rollout, J5] [Owner: E6]

##### Large HUD (Accessibility option)
- UX-DR102: Large HUD doubles only numbers and icons. Pips, meter, notch, grace bar and frame keep ×1. There is no behaviour change. Positions:
  - Heart: 14×14, centred x 30, y 8–21.
  - Pips: x 26, y 28 + 10·n, ending at y 64.
  - Held icon: 10×10, centred x 30, top y 120, flickers.
  - Held `+N`: 16 px, centred x 30, top y 132.
  - Carried icon: 10×10, top y 154, solid.
  - Carried count: 16 px, top y 166 (the block ends near y 182).
  - Chain icon: 14×14, centred x 450, y 8–21.
  - Chain number: top y 26, sizes unchanged (A16).
  - Alert eye: ×2, centred x 450, top y 66.
  - Meter, notch and grace bar: as the default layout.
  [UX: DESIGN → Large HUD layout; EXPERIENCE → Component Patterns] [Owner: E7]
- UX-DR103: Large HUD capacity: `+999` (about 40 px) and `+1240` (about 50 px) at 16 px must fit 58 px. Six characters (`+12400`, about 60 px) don't fit; that case is open (O12). [UX: DESIGN → Large HUD layout] [Owner: E7]

#### Flows

- UX-DR104: J1, first 5 minutes:
  1. Web gate.
  2. Title with the scrolling shaft and the ember cursor.
  3. New Game → slot → Normal; the difficulty step explains death cost only.
  4. The first shaft, with the meter filling.
  5. Landing at chain 6 banks the chain: held → carried, popup and chord.
  6. The first Lift Station: ↓ rest, embers count into the bank, autosave icon.
  - Before E4/E5 land, J1 ends at that station rest. The full version adds Fast travel to the hub and the Map tab in Pause.
  - Failure path: death before the station shows the death card naming the cause, then respawn at the last lit anchor.
  [UX: EXPERIENCE → Key Flows J1] [Owner: E1 (steps 1–5), E4/E5 (steps 6–7)]
- UX-DR105: J1 tutorial prompts (glyph prompts teaching jump, slash and pogo) are open: spec them or use in-world signs (O2). [UX: EXPERIENCE → J1 step 3, Open Q O2] [Owner: E4]
- UX-DR106: J2, greedy chain near death:
  1. At chain 15 the number is at peak size.
  2. A half-open edge eye appears with its glow and a panned growl, opening wider as the lurker stirs.
  3. Cling: the light drops, the links stay lit, and the grace bar and cling cue drain.
  4. The telegraph shows the frame and eye for 0.9 s.
  5. Tapping Light inside the window does a Flare Toss (allowed because the meter is past the notch), removing the hatched top half.
  6. Pogo to a ledge: the chain banks with a chord.
  - Failure path: a pip cracks and becomes an outline, the pips blink, and the segments fall away and dim.
  [UX: EXPERIENCE → J2] [Owner: E1 (audio parts E3)]
- UX-DR107: J3, death and cache run:
  1. The death card shows cause, tip and tier line, with gutter losses.
  2. Held input is ignored; skip opens at 0.6 s; auto-advance at about 3 s.
  3. Respawn at full HP.
  4. The Ember Cache glows amber in the world, and that glow stirs nearby lurkers (their edge cues show).
  5. One touch restores the carried embers.
  - Dying again first removes the Cache, and the card says so.
  - Easy: no cache, held → carried. Hard: no cache, both lost.
  [UX: EXPERIENCE → J3, Notes for Other Docs] [Owner: E1]
- UX-DR108: J4, station → hub → spend: rest (heal, deposit, autosave) → Fast travel → Hub → talk to the Smith (speech box plus shop list with deposited total and prices) → the Naturalist pays for journal entries, marked new → the Guild records board shows a beaten best chain → Descend from the station menu. The can't-afford response is open (O6). [UX: EXPERIENCE → J4] [Owner: E5]
- UX-DR109: J5, Weaver fight UX:
  - Rest at the Hollow Station before the arena. The arena is one-way, the gutters stay, the Weaver's theme plays, there is no boss bar.
  - Health is shown by fray-and-fall.
  - Re-Weave: silk threads glow along the new paths for 3 s.
  - At 6 HP, The Fall: 0.5 s slow motion, then about 6 s of free fall with debris to pogo, while the meter climbs toward the cap.
  - On defeat: slow motion, Weaver Silk drops (Swing unlocked), and the repaired station returns the player to the hub.
  - Death in phase 2 respawns at the station before the arena with full HP, and the fight resumes in phase 2. Death in phase 1 resets the fight.
  [UX: EXPERIENCE → J5] [Owner: E2 (prototype), E6 (final)]
- UX-DR110: J6, gamepad session:
  1. Keyboard glyphs on the title; moving the stick switches to pad glyphs, and the d-pad moves the cursor.
  2. Load slot 2 with A (B goes back).
  3. In play, prompts show pad glyphs, and the ↓ prompt shows the pad's down.
  4. Start opens Pause, whose controls reference lists pad bindings.
  5. Options > Accessibility: reduced motion on (the cursor now jumps); tap window set to 0.2 s.
  6. Flare Toss with B inside the wider window.
  7. Pad battery dies: auto-pause with "Controller disconnected" and keyboard glyphs. Reconnecting resumes with the chain intact, or any key resumes on keyboard.
  [UX: EXPERIENCE → J6] [Owner: E1]
- UX-DR111: Navigation model: one screen at a time, replacing, never stacking. Options returns to its opener (Title or Pause). Pause Quit → Title. Continue → most recent slot. [UX: EXPERIENCE → Information Architecture] [Owner: E1]
- UX-DR112: Resume saves happen only at a station rest, the hub and a quit at a lit anchor; progress saves (R14) happen at progress moments. Each shows the autosave icon. [UX: EXPERIENCE → State Patterns > Autosave] [Owner: E1 (hub E5)]
- UX-DR113: Save-failure flow:
  - Triggers: web storage blocked or full, or a disk error.
  - Response: crossed icon plus "Not saved" for 3 s, retry at the next rest, and the Pause note explains the fix.
  - Never crashes or pauses the game. Saves must report failure to the UI.
  [UX: EXPERIENCE → State Patterns > Save failed, Notes for Other Docs] [Owner: E1]

#### Input & navigation

- UX-DR114: Default gameplay bindings (keyboard / gamepad):
  - Move: Arrow keys / left stick or d-pad. ↓ drops off a wall.
  - Interact: ↓ on the ground while standing still.
  - Jump: Z or ↑ / A. Hold for height; hold at a wall while falling = cling.
  - Attack: X / X. Air attack = pogo, any direction.
  - Dash: C / RB. Near a silk anchor = grab rope (post-Weaver).
  - Light: V / B. Tap = Flare Toss; hold past the tap window = Snuff.
  - Pause: Esc or P / Start. P is the web fallback, since Esc can leave browser fullscreen.
  [UX: EXPERIENCE → Input Schemes > Gameplay bindings] [Owner: E1]
- UX-DR115: Every action is a single button: no chords, and no new buttons for new abilities (Pillar 4). Every screen and prompt works on both keyboard and gamepad. [UX: EXPERIENCE → Input Schemes, Foundation, Anti-patterns] [Owner: E1]
- UX-DR116: Menu bindings (D6):
  - Move selection: Arrows / d-pad or left stick.
  - Confirm: Z, Enter or Space / A.
  - Back: X, Backspace or Esc / B.
  - Switch tab: Q / E, LB / RB.
  - Change value (slider, choice): ← / → , d-pad or stick left / right.
  [UX: EXPERIENCE → Menu bindings] [Owner: E1]
- UX-DR117: Menu repeat, wrap and stick:
  - Holding a direction moves once, then repeats after 400 ms every 80 ms. Sliders step one segment per repeat.
  - Vertical lists and the tab bar wrap end to end. Sliders and choice lists stop at their ends.
  - The stick fires a move at 0.5 tilt and must return below 0.3 before the next non-repeat move.
  [UX: EXPERIENCE → Menu bindings] [Owner: E1]
- UX-DR118: Interact (D7):
  - ↓ on the ground while standing still; never ↑.
  - On a stick it fires at ≥ 0.6 down with ≤ 0.35 sideways, and re-arms below 0.3.
  - Movement deadzone is 0.2; "standing still" means sideways tilt below it.
  [UX: EXPERIENCE → Interaction Primitives] [Owner: E1]
- UX-DR119: Light tap window: 0.12 s (default), 0.2 s or 0.3 s. Releasing Light inside the window = Flare Toss; holding past it = Snuff. A tap must never break the chain. Quick Wick changes the Snuff response, not the tap window. [UX: EXPERIENCE → Input Schemes > Rules, Interaction Primitives] [Owner: E1]
- UX-DR120: Hold-to-toggle options (O13):
  - Cling toggle: turns the cling hold into a press.
  - Snuff toggle: when On, Light only throws Flare Tosses (any press, no tap window). Snuff moves to its own key (default Shift; pad LB), pressed once to start and again to end. Snuff still ends the chain.
  - Quick Wick has no extra effect in Snuff-toggle mode.
  [UX: EXPERIENCE → Input Schemes > Rules] [Owner: E1]
- UX-DR121: Glyph swap (D7):
  - Prompts and the controls reference show the last-used device's glyphs.
  - Any button press, or a stick or trigger past 0.5, switches to gamepad. Any key press switches to keyboard.
  - Stick input below 0.5 and mouse movement never flip glyphs.
  - UI text never hard-codes key names; it uses glyph prompts.
  [UX: EXPERIENCE → Input Schemes > Rules] [Owner: E1]
- UX-DR122: On web, Arrows, Space and F-keys never scroll or act on the page. [UX: EXPERIENCE → Input Schemes > Rules] [Owner: E1]
- UX-DR123: Debug keys: the M1 F1 brightness key moves into Options; F2/F3 debug keys are removed from player builds (A7). [UX: EXPERIENCE → Input Schemes > Rules] [Owner: E1 (removal); E7 (brightness option)]
- UX-DR124: Full rebinding of every action on both devices in Options > Controls. [UX: EXPERIENCE → Input Schemes > Rules] [Owner: E7]

#### Accessibility

- UX-DR125: Flash cap: no more than 3 flashes per second anywhere, checked for every effect. Pulses ≤ 2 Hz; blinks 2.5 Hz. The HUD never flashes. [UX: EXPERIENCE → Accessibility Floor; DESIGN → Do's and Don'ts] [Owner: E1]
- UX-DR126: Reduce flashing (toggle) changes:
  - Hit flash → a short dim.
  - Pogo sparks → smaller.
  - Alert frame → solid, no pulse.
  - Invulnerability (pips and player) 2.5 Hz blink → steady transparency.
  - Bank burst and bloom → toned down.
  [UX: EXPERIENCE → Game Feel & Juice] [Owner: E1]
- UX-DR127: Reduced motion (toggle):
  - Stops cursor easing (the cursor jumps), rising popups (the bank popup doesn't rise) and UI shake (the pip doesn't shake).
  - Makes the zone cross-fade snap in one frame.
  - Defaults to the OS setting on web and to off on PC (A11).
  [UX: EXPERIENCE → Game Feel & Juice, Accessibility Floor] [Owner: E1]
- UX-DR128: Screen shake on/off in Options > Accessibility. [UX: EXPERIENCE → Accessibility Floor] [Owner: E1]
- UX-DR129: Colour is never the only signal:
  - Alert = frame + pulse + eye.
  - Empty = outline.
  - Held = `+` and flicker; carried = solid icon.
  - Toss cost = diagonal hatch.
  - Save failed = crossed icon.
  - Off-screen cue = eye that opens, never glow alone.
  [UX: EXPERIENCE → Accessibility Floor; DESIGN → Do's and Don'ts] [Owner: E1]
- UX-DR130: Contrast floors per UX-DR7/8 enforced in every zone. [UX: EXPERIENCE → Accessibility Floor] [Owner: E1]
- UX-DR131: Steam Deck legibility check in E1 at ×2 (960×540 on a 7" panel or equivalent) with Fusion Pixel Font 8px. The full Deck pass, with gamepad glyphs, is E7. [UX: EXPERIENCE → Responsive & Platform, Foundation] [Owner: E1 (check), E7 (pass)]
- UX-DR132: Death-card accessibility: held input is ignored, there is a skip lockout and auto-advance, and lines are kept for the death log. [UX: EXPERIENCE → Accessibility Floor] [Owner: E1]
- UX-DR133: Brightness at 4 levels: Options > Accessibility from E1 (R1), Options > Video from E7. [UX: EXPERIENCE → Accessibility Floor] [Owner: E1 → E7]
- UX-DR134: E7 accessibility additions:
  - Large HUD.
  - Text scale (menus, speech, journal; layout open, O12).
  - Timing assists (not difficulty; excluded from Guild records).
  - Visual sound cues (on-screen markers for predator sounds; with them on, the stirring state also shows an edge marker).
  - An accessibility test pass (colour-blind sim, sound off, ×2) is open (O15).
  [UX: EXPERIENCE → Accessibility Floor, State Patterns > Stirring, Open Q] [Owner: E7]

#### Feedback

- UX-DR135: Link gained: the chain number moves up 1 px for 67 ms then returns, and one meter segment fills. Same under reduced motion. [UX: EXPERIENCE → Game Feel & Juice] [Owner: E1]
- UX-DR136: Chain 3 / 6 / 10: the number steps 24 → 26 → 28 → 32 px together with the music layer. [UX: EXPERIENCE → Game Feel & Juice] [Owner: E1 (music sync E3)]
- UX-DR137: Bank (landing, Snuff or cling timeout):
  - The bank popup rises and fades over 600 ms.
  - Then ember sprites fly from the player into the left-gutter counter, which counts up. Held → carried, with a chord.
  - The meter empties.
  - Under reduced motion the popup does not rise.
  [UX: EXPERIENCE → Game Feel & Juice, State Patterns > Chain bank] [Owner: E1 (chord E3)]
- UX-DR138: HP lost: the pip cracks and shakes, then becomes an outline (no shake under reduced motion). Then the invulnerability blink: pips blink at 2.5 Hz for 0.6 s. [UX: EXPERIENCE → Game Feel & Juice, State Patterns > Invulnerability] [Owner: E1]
- UX-DR139: Chain break: segments fall away and dim with no flash, and the number returns to 0 in the Empty colour. Chain 0 shows all segments as outlines, with the notch still visible. [UX: EXPERIENCE → State Patterns > Chain break / Chain 0] [Owner: E1]
- UX-DR140: Flare thrown: half the chain goes (GDD Flare Toss), the meter drops, and the flare dims in the world over 4 s (diegetic flare burn). [UX: EXPERIENCE → State Patterns > Flare thrown, HUD & Diegetic UI] [Owner: E1]
- UX-DR141: Chain at cap (20): the meter is full and hits still pay. Any extra cue at the cap is open (O11). [UX: EXPERIENCE → State Patterns > Chain at cap] [Owner: E1 (base), E7 (O11)]
- UX-DR142: Zone boundary (O4): when the camera centre crosses a palette-zone boundary, the gutter fill, rules and every zone-role UI colour cross-fade to the new zone over 500 ms, with no flash. Snaps under reduced motion. Amber and red never change. [UX: EXPERIENCE → Game Feel & Juice, State Patterns > Zone change] [Owner: E4]
- UX-DR143: Stirring: off-screen edge cue on that side (E1), plus a panned stirring sound (E3). [UX: EXPERIENCE → State Patterns > Stirring] [Owner: E1 / E3]
- UX-DR144: Chain gate count: shown in the world with a glow and a rising tone (GDD Ability-Gating). [UX: EXPERIENCE → HUD & Diegetic UI] [Owner: ? (not in rollout; chain gates likely E4, tone E3)]
- UX-DR145: Menu move: the ember cursor eases over 120 ms and flickers; it jumps under reduced motion. [UX: EXPERIENCE → Game Feel & Juice] [Owner: E1]

#### Platform

- UX-DR146: Web:
  - The itch embed is 960×540 (×2), with whole-number scaling.
  - Below ×2 the gate suggests fullscreen.
  - Auto-pause on focus loss.
  - Fullscreen toggle in Options, plus the itch fullscreen button.
  [UX: EXPERIENCE → Responsive & Platform] [Owner: E1 (Options fullscreen E7)]
- UX-DR147: Web HiDPI (D15):
  - The canvas backing size is the CSS size × devicePixelRatio, and the whole-number scale is picked from physical pixels (a 960×540 embed at DPR 1.5 runs at ×3).
  - Below 480×270 physical pixels, fit the window with a fractional nearest-neighbour downscale, still letterboxed, and both the gate and the Pause tab suggest fullscreen.
  [UX: EXPERIENCE → Responsive & Platform, Notes for Other Docs] [Owner: E1]
- UX-DR148: PC:
  - The window is at a whole-number scale (default ×3, 1440×810).
  - Fullscreen is letterboxed.
  - Minimum window size is 480×270, so PC never drops below ×1.
  - HiDPI uses physical pixels.
  [UX: EXPERIENCE → Responsive & Platform] [Owner: E1]
- UX-DR149: Room framing: rooms are framed for 360 px of visible width. Spine shafts are 22 tiles (352 px) and never scroll sideways; wider rooms (Weaver arena, hub) scroll horizontally. E1 rebuilds the M1 shaft at 22 tiles. [UX: EXPERIENCE → Responsive & Platform, Notes for Other Docs] [Owner: E1 (shaft), E2/E5 (wide rooms)]
- UX-DR150: Localization readiness:
  - String table from day one; M2 ships English only.
  - The HUD carries no localised text.
  - Menu, speech and journal text fits the 360 px column.
  - Tab widths by measure and CJK glyph size are open (O18).
  [UX: EXPERIENCE → Localization] [Owner: E1]

#### Epic Rollout (as stated)

| Epic | UX surfaces |
|---|---|
| E1 Kit v2 | Gutter HUD v2: gutter icons, HP pips with outlined empties, held/carried ember counter (flicker vs solid), chain number, chain meter, cling grace bar, flare notch, flare cost hatch, cling cue, alert frame + eye, off-screen edge cue with glow floor. Contrast floors and per-zone UI tokens. Fusion Pixel Font 8px integrated (OFL files shipped) and the Deck-size check run with it. Gutter outer rule. Options with Game + Accessibility tabs (reduce flashing, screen shake, reduced motion, Light tap window [ASSUMPTION], Cling toggle and Snuff toggle). Pause tab (Resume / Options / Quit, bank summary, controls reference). Gamepad defaults, glyph swap, disconnect pause. Glyph prompts. Death card (timing, 3 tiers, layout). Placeholder station rest and station menu. Save/load with save-failure handling, autosave icon, difficulty step. Menu bindings (keys, repeat, wrap) and confirm step. String table. 960×540 embed with fullscreen suggestion. [ASSUMPTION] Title (with Load), slot picker and click-to-play gate also land here, since save/load does. |
| E2 Weaver prototype | Debug entry into the Weaver arena (dev only). Gutters in the arena. Diegetic Weaver health (no bar). |
| E3 Audio | Options > Audio volume sliders. Stirring sound for the off-screen edge cue. |
| E4 Layer 1 world | Map tab; full station menu with fast travel; journal objects read via ↓; zone-tinted UI across Dusk, Umber and Cold violet, with the 500 ms zone cross-fade. Map tab: mock before build via gds-ux Update. |
| E5 Hub | Speech box, shop list, Guild records board, minimal Journal tab (creature entries, "new" marks for Naturalist payouts), fast travel to hub. Speech box, shop list and Journal tab: mock before build via gds-ux Update. |
| E6 Weaver final | Post-boss return flow to hub; phase checkpoint; final fray-and-fall health visuals. |
| E7 Slice polish and ship | Options Video and Controls tabs; rebinding; large HUD; text scale; timing assists; visual sound cues; full Journal tab (death log, lore, records, polish); HUD polish; Steam Deck pass; Credits with AI disclosure [ASSUMPTION]. |

Also stated:
- In Options, Accessibility (E7 additions) lands in E7. The Pause tab bar shows Pause in E1, Map in E4 and Journal in E5.
- Key mocks exist for the HUD, death card, title and slot picker, Pause and Options, station rest and menu, and the web gate.
- Quit confirm, the controller-disconnected pause and credits stay spine-only.
- "The spines win": if a mock disagrees with DESIGN.md or EXPERIENCE.md, the spine is the contract.

#### Open UX questions / deferred items

**Open, later epic**
- O2: Tutorial prompts in J1 step 3: spec them or use in-world signs. [Owner: E4]
- O3: Map room colours, icon art, pin place/remove controls. [Owner: E4]
- O5: Speech box frame, height, name tag, reveal (typewriter or instant), skip, line length. [Owner: E5]
- O6: Shop buy confirm and can't-afford response; shop layout. [Owner: E5]
- O7: Empty journal and map states; "new" mark art; Guild records board form. [Owner: E4/E5]
- O8: Gutters during cutscene moments (The Watching Departure, The Fall). [Owner: E5/E6]
- O9: Hub and Layer 2 palettes, their UI tokens and floor checks, and the landing-arena UI palette. [Owner: E5/E6]
- O10: Whether the Weaver's bite telegraph shows the alert frame; how the Swing unlock is shown; how a phase-2 respawn reaches the landing arena. [Owner: E2/E6]
- O11: Extra cue at chain cap. [Owner: E7]
- O12: Large HUD ember display above 4 digits; text scale layout for menus, speech and journal. [Owner: E7]
- O14: Mono audio and separate sliders [Owner: E3]; the full list of visual sound cues [Owner: E7].
- O15: Accessibility persona or test pass (colour-blind sim, sound off, ×2). [Owner: E7]
- O18: Tab widths and CJK glyph size for later localisation. [Owner: ? (post-M2)]
- O19: Title logo art; E1 uses a text placeholder. [Owner: E7]
- O20: If Snuff gains a cost (GDD Risks), the HUD must show it. [Owner: ?]
- Open, blocks E1: none.

**E1 defaults to review (D1–D15), all specified and tagged `[ASSUMPTION — default, review]`** [Owner: E1]
- D1 chain number steps and pop.
- D2 text outline.
- D3 cling cue and grace-bar colour.
- D4 icon art and no ember header.
- D5 glyph prompt.
- D6 menu keys, repeat, wrap.
- D7 glyph swap and ↓ deadzone.
- D8 alert hold on overlap.
- D9 slot picker states and confirms.
- D10 Quit confirm.
- D11 autosave icon.
- D12 Options toggle and slider.
- D13 Dusk menus outside play.
- D14 station menu placement.
- D15 HiDPI and small windows.
- The key-mock positions and colours are also defaults to review.

**Assumptions that affect rollout**
- A1: Brightness may move from E7 into an earlier Video tab. **Resolved (R1):** it ships in E1 under Accessibility and moves to Video in E7.
- A3: Title, slot picker and gate land in E1.
- A4: Credits land in E7.
- A5: Quit on the title is PC only.
- A6: Unlanded tabs are hidden, not disabled.
- A8: Visual sound cues land in E7.
- A10: The tap window lands in E1.
- A11: Reduced motion defaults to off on PC.
- A12: The edge-cue glow pulses at 2 Hz.
- A13: Options changes apply at once.

**Ambiguities to settle while writing stories (my reading, not stated in the spec)**
1. Brightness gap: E1 removes the F1 key, but the Video tab lands in E7, so builds from E1 to E6 have no brightness control unless A1 is applied. **Resolved (R1).**
2. Credits entry: Options lists a Credits entry, but Credits land in E7. Presumably the entry is hidden until then. Meanwhile the font licence files ship from E1, while the "credits name the font" rule waits for E7.
3. E1 station menu: the spec says only "placeholder station menu", so it is unclear whether Fast travel shows (and with what list) before E4.
4. Tab bar with one tab: in E1 the Pause tab bar holds only "Pause", so what Q/E or LB/RB do there is not specified.
5. Chain gate count UI (glow and rising tone): no epic owns it in the rollout.
6. Mocks still to make: Map (E4) and Journal / speech box / shop (E5) need gds-ux Update mocks at epic start, before build. These should be explicit stories.


### Narrative Requirements

Source: `narrative-design.md` (complete 2026-11-12). These become stories (systems, content) or acceptance criteria on every story that writes player-facing story text.

**Gates and process**

NR1: Voice-anchor gate: sonlm approves 3 anchor lines per speaker before any line for that speaker is written, and later lines must match them. Speakers and due points: death card (E1); Oda's journal hand and the lost-islander documents (before E4 writing); Old Tessaly, Smith, Cartographer, Naturalist (before E5 lines). [E1 / E4 / E5]
NR2: Writing workflow for every story string: anchors approved → Claude drafts against the anchors and `narrative-design.md` → sonlm edits and approves before commit → strings go into `game/text/strings.csv` under the key scheme → the length and flag validators pass. [E1 / E4 / E5 / E6]
NR3: String-key scheme: `NPC_<WHO>_<FLAG>_<n>`, `NPC_<WHO>_IDLE_<n>`, `DEATH_<CAUSE>_LINE` + `DEATH_<CAUSE>_TIP`, `JOURNAL_<ID>_BODY`; all via `tr()`. [E1+]
NR4: M2 writing budget ≈ 2,000–2,500 words: 6 hub conversations, 4 documents, 5 scripted moments, ≈ 40 dialogue lines, ≈ 8 death causes, ≈ 20 Memorial names, 5 creature entries. [E1–E6]

**Narrative systems**

NR5: Story-flag registry (one list in `rules/`; ids are save data, never renamed; set only through `Game.slot` rule methods): `first_dive`, `memorial_read`, `bought_map`, `bought_wick`, `first_entry_sold`, `last_entry_read`, `lurker_met` (set when a lurker telegraph starts inside `World.play_rect()`), `departure_l1_seen`, `departure_l2_seen`, `weaver_defeated`, plus the partner-tag flag (E6; id not yet named). The registry starts in E4 with the first flags; the `requires_flag` validator (NR7) lands in E5. [E4 / E5 / E6]
NR6: Persistent object ids: `anchor_s4_oda` (Oda's cold lantern, a lantern anchor), `prop_house_page_last_entry` (the page pinned on her gear wall), plus the Swing-secret objects (E6; ids not yet named). [E4 / E5 / E6]
NR7: Flag validator (pure, returns an error list): every `requires_flag` in `rules/dialogue.gd` and every flag a rule method sets exists in the registry; run by the test suite and `tools/export.sh`. [E5]
NR8: Length validator (pure, returns an error list): every speech string fits ≤ 2 rows of the 360 px speech box, measured in the UI font; a death line fits ≈ 1 row; `tools/export.sh` refuses to build on any error. Full pass over all M2 text in E7. [E5 / E7]
NR9: Dialogue selection: per-NPC ordered `{key, requires_flag}` lists in `rules/dialogue.gd`; linear, no choices; Glim is silent. A new flag unlocks ≤ 3 lines per NPC; old story lines never replay in the speech box; with nothing new the NPC says one idle line, then opens the shop (Tessaly opens the record board). Idle lines rotate by a saved per-NPC talk counter (no randomness); per-NPC `{seen, idle}` record in `SlotState`. [E5]
NR10: Story screens open only by player choice (↓ while standing still) and never stop a chain; speech advances one line per confirm; documents close at will; reading a document opens a screen through `ScreenRouter` and pauses gameplay. The only forced moments are The Fall and the First Dive registration. [E4 / E5]
NR11: Death card: one line per death (cause + plain avoidance, ≈ one row, readable in 3 s), auto-advances after ≈ 3 s and is kept in the Journal death log (`death_log` ships in E1). Tone matter-of-fact, kind, never mocking. [E1]
NR12: Scripted moments are in-engine (no cutscene mode, letterbox, video or skip), keep input live wherever safe, add no time, and go through `Fx` / `Game.clock` honouring `reduced_motion` and `reduce_flashing`. [E2 / E5 / E6]

**M2 content**

NR13: New-game opening (E5): fade in in Oda's house; Glim wakes beside the empty chair; ↓ interact is taught on the door; outside, Old Tessaly registers the First Dive at the Guild (clue 1: Oda never let Glim near the pit's edge; sets `first_dive`) and points at Oda's record on the board; this is the only required talk; the Memorial Wall is optional on the way to the lift; the map and Journal tabs are introduced at the first station rest; story and hub land within the first 2 minutes. [E5]
NR14: Hub conversations (E5): The Memorial Wall (Tessaly; `memorial_read`; quiet, no humour); Smith (first visit, and `bought_wick`: Oda's lantern; terse, fond); Cartographer (first visit, and `bought_map`: Oda's handwriting; precise, wistful); Naturalist (`first_entry_sold`: introduces the observer; eager, questioning; no clue in M2); 3 idle lines per NPC. [E5]
NR15: Hub content (E5): Memorial Wall of ≈ 20 names plus Oda (the partner added in E6), names matching the documents; Guild record board (Oda's all-time depth record, Glim's logged depth, labels); 5 creature entries (crawler walker, crawler hoverer, spiderling, lurker, Weaver; ≈ 300 words); Oda's house gear wall shows `prop_house_page_last_entry` after `last_entry_read`; static industrial props (lift cage, one winch, pipe, relic crates stamped for shipping); lit amber lanterns. [E5]
NR16: Layer 1 documents (E4): *The Last Entry* on the S4 main path (Oda's camp: bedroll, cold lantern, half-written **unsigned** journal, "going deeper"; sets `last_entry_read`; Layer 1's only set piece; the lantern is `anchor_s4_oda`); 3 lost-islander documents (A ×2, B ×1) whose writers' names are on the Memorial Wall: world history only, no origin clues. ≈ 500 words for the 4. [E4]
NR17: Layer 1 set dressing (E4): working scaffolds and rope → the abandoned Rope Works and Old Mine (dead lamps, snapped lines, rusted carts) → wild abyss at Weaver's Hollow; camps of lost explorers mark how far the island reached. [E4]
NR18: Weaver introduction: triggered on entering S5; heard and glimpsed before the arena while the player keeps moving (placeholder staging E2, final E6). Story reveals land after victory, never mid-fight. [E2 / E6]
NR19: M2 closing beat (E6): the first ride up from the landing arena plays the full Watching Departure with Layer 1's cast (hoverers, crawlers, lurker eyes opening to watch, not hunt; `departure_l2_seen`); on the first hub return after `weaver_defeated`, Tessaly logs the new depth, still short of Oda's record (clue 3: Glim keeps coming back, "luck"; proud, uneasy). The slice ends on a question, not a reveal. [E6]
NR20: Memorial clue (E6): the Guild tag of Oda's dive partner, found in a Swing secret, adds the partner's name to the Wall; sonlm names the partner. [E6]

**Style rules (acceptance criteria on every writing story)**

NR21: Island dialect lives in word choice, idiom and rhythm, never phonetic spelling or dropped letters; every line reads clearly to a non-native English player; early-industrial register, no modern slang; no profanity (mild trade oaths at most); dry humour in the hub only, never in reveals or the Memorial; melancholic wonder, never grim; creatures are hungry, not hateful; subtext over exposition.
NR22: Glim is silent and never gendered in any player-facing line.
NR23: Clue budget: exactly three pointed clues in Layer 1 (Tessaly's First Dive line, The Watching Departure, Tessaly after the Weaver); ambient texture (the name "Glim", the amber hub, only Glim comes back) is never pointed at; clues use existing systems only (no new creature behaviour for story); the main path carries every pointed clue; at most one set piece per layer.
NR24: Voice distinctions: Tessaly gruff, short sentences, island sayings, calls Glim "Glim", says less than he knows; Smith fewest words, tools and materials; Cartographer precise and fussy; Naturalist asks rather than states; Oda's hand first person, warm early, clipped and hungry later.
NR25: Bosses are never shown dying; no blood or corpses; English only in M2 (gutter labels are icons); text only, no voice acting.

### Cross-document Resolutions (step 1, 2026-11-12)

Conflicts found between the input documents while extracting requirements, and how they were settled. Decided by sonlm unless marked "default".

| # | Conflict | Resolution |
|---|---|---|
| R1 | E1 removes the F1 brightness hotkey, but the Video tab is E7 | **sonlm:** a 4-level Brightness choice ships in E1 (UX A1); it moves to the Video tab in E7 (FR33) |
| R2 | E4 sets story flags; the registry and validator were listed in E5 | **sonlm:** the flag registry starts in E4 with the first flags; the `requires_flag` validator lands in E5 (NR5, NR7) |
| R3 | Narrative: compose the hub theme first (E3); GDD epics: themes out of E3, composed in E7 | **sonlm:** E3 sketches the shared motif as a placeholder hub stem; composed themes stay in E7 (FR77) |
| R4 | Narrative says `{seen, idle}` needs "no migration"; project rule: every save-format change ships a migration + fixture | default: project rule wins (more restrictive) |
| R5 | Chain gate count glow + rising tone has no owner in the UX rollout | default: E4 with the gate object; the tone uses E3's pipeline |
| R6 | E1 station menu is a "placeholder": does Fast travel show before E4? | default: E1 shows Descend / Leave only; Fast travel appears in E4 |
| R7 | Options lists a Credits entry, but Credits land in E7 | default: hidden until E7 (unlanded = hidden, UX A6); licence files ship from E1 |
| R8 | One-tab Pause bar in E1: what do Q/E, LB/RB do? | default: nothing (no-op) until a second tab lands |
| R9 | Map (E4) and speech box, shop, Journal (E5) are "mock before build via gds-ux Update" | default: explicit UX-update stories at the start of E4 and E5 |
| R10 | Voice-anchor approvals are a gate, not a story | default: explicit approval stories before the first writing story of E1 (death card), E4 (Oda's hand, documents) and E5 (NPCs) |
| R11 | Narrative creature-entry list says "walker"; everywhere else "crawler" | default: "crawler walker" / "crawler hoverer" |
| R12 | 13 small inconsistencies inside `game-architecture.md` | default: the more specific reading wins; listed at the end of Additional Requirements |
| R13 | Open details deferred to their epic: ≈ 8 death causes (E1), Smith / Cartographer / Naturalist names and pronouns (E5; copy avoids pronouns until then), partner-tag flag id and Swing-secret ids (E6), flare cap (E1 perf scene + playtest), Weaver flee target (E2), phase-2 respawn route (E6) | default: decided in the named epic's stories |
| R14 | Readiness check (2026-11-12): only rest, hub arrival and anchor quit save, so a difficulty change, hub purchases and flags, the Weaver phase checkpoint and the Weaver win can be lost on quit | **sonlm:** progress saves at those moments rewrite world progress but never move the resume point or make carried embers safe (AR38, FR29) |
| R15 | Readiness check: Godot 4.7.2 prints an engine `ERROR:` on a corrupt `ConfigFile` (load and parse), which fails the test runner | **sonlm:** settings are stored as `user://settings.json`, parsed with the silent `JSON.new().parse()` like the slots (AR14, AR37) |
| R16 | Readiness check: the E1 shaft is one-way, so after the first anchor the player can't return to the top station to rest, deposit or save | **sonlm:** the shaft's bottom exit loops to its own top entry; crossing it banks the chain like a landing (Stories 1.5, 1.7, 1.24) |
| R17 | Readiness re-review (verified on Godot 4.7.2): under `--script`, a test that touches the `Game` autoload (directly, via `preload` or a `class_name` hint) fails to compile and can hang or exit 0 with no output, so the M1 runner would report green | **sonlm:** tests extend `Node` and run as scenes through `tests/runner.tscn`; a test with no `PASS` line or running > 120 s fails (Story 1.2, AR47) |

### FR Coverage Map

A → B means the requirement starts in A and is finished in B.

FR1: Epic 1 - Movement tuning carried from M1, preserved through the migration
FR2: Epic 1 - Air dash carried from M1
FR3: Epic 1 - Downward camera lead carried from M1
FR4: Epic 1 - Slash, pogo, hitstop and boxes carried from M1
FR5: Epic 1 - Chain, Chain-Light radius, Blade Bloom carried from M1
FR6: Epic 1 - Chain-end rules incl. any-hit and room-exit backstop
FR7: Epic 1 - Wall cling carried from M1
FR8: Epic 1 - Ember earning curve carried from M1
FR9: Epic 1 - Light tap vs Snuff with the configurable tap window
FR10: Epic 1 - 4 HP and the damage table
FR11: Epic 1 - Any hit breaks the chain, held → carried
FR12: Epic 1 → Epic 5 - Healing at rest and bank-heal (E1); on arriving home (E5)
FR13: Epic 1 - Death and respawn without scene reload
FR14: Epic 1 - Flare Toss input and cost
FR15: Epic 1 - Flare flight, burn and fade
FR16: Epic 1 → Epic 2 - Predators treat a flare as the player (E1); the Weaver is repelled (E2)
FR17: Epic 1 - Lurker wake rule on the play rect
FR18: Epic 1 - Off-screen stirring edge eye (sound in E3)
FR19: Epic 1 - Telegraph and gutter alert
FR20: Epic 1 - Hunt, lose-scent and escape guarantee
FR21: Epic 1 - Retarget telegraph; lurkers not killable
FR22: Epic 1 - Three ember stages
FR23: Epic 1 - Ember Cache on death
FR24: Epic 1 - Cache glow wakes lurkers
FR25: Epic 1 - Difficulty death-cost tiers
FR26: Epic 1 - ↓ interact
FR27: Epic 1 → Epic 4 - Lantern anchor object (E1); ≈ 5 placed in Layer 1 (E4)
FR28: Epic 1 → Epic 4 - Placeholder Lift Station rest (E1); final station with fast travel (E4)
FR29: Epic 1 → Epic 5 - Autosave at rest and anchor quit (E1); on arriving home (E5)
FR30: Epic 1 - Three save slots, picker, Continue, Load, failure state
FR31: Epic 1 - Default keyboard and gamepad mappings
FR32: Epic 1 - Pause triggers incl. focus loss and pad disconnect
FR33: Epic 1 → Epic 3 → Epic 7 - Options: Game, Accessibility, Brightness (E1); Audio (E3); Video, Controls, a11y additions (E7)
FR34: Epic 1 - Snuff toggle mode
FR35: Epic 7 - Timing assists kept out of Guild records
FR36: Epic 1 - HUD v2 in the gutters
FR37: Epic 1 - Field Journal death line
FR38: Epic 1 → Epic 4 → Epic 6 - Pogo freeze/sparks and shake toggle (E1); creature spark dissolve (E4); boss-climax slow-mo (E6)
FR39: Epic 1 - M1 shaft rebuilt at 22 tiles with placeholder station and 2 anchors
FR40: Epic 2 → Epic 6 - Arena, strands and anchors (prototype → final)
FR41: Epic 2 - Weaver light-shy states and bite
FR42: Epic 2 - Light-burst stun
FR43: Epic 2 - Strand drop
FR44: Epic 2 → Epic 6 - HP 12, Re-Weave, diegetic health (E2 stubs The Fall at 6 HP)
FR45: Epic 2 - Flare herding
FR46: Epic 2 - Spiderling
FR47: Epic 6 - The Fall
FR48: Epic 6 - Phase 2 in the landing arena
FR49: Epic 2 → Epic 6 - Fight reset on death (E2); phase-2 checkpoint (E6)
FR50: Epic 6 - Defeat presentation, Silk, station repair, `weaver_defeated`
FR51: Epic 6 - Swing
FR52: Epic 4 → Epic 6 - Inert silk anchors and sealed alcoves with ids (E4); activation and rewards (E6)
FR53: Epic 4 - Rooms and transitions
FR54: Epic 4 - Spine S1–S5
FR55: Epic 4 - Side areas A, B, C
FR56: Epic 4 - Chain gates (glow; tone via E3's pipeline)
FR57: Epic 4 - Level design rules
FR58: Epic 4 - Layer 1 enemies and respawn
FR59: Epic 4 - Palette zones, ledge rims, dead lamps
FR60: Epic 4 → Epic 5 - Map tab (E4); Cartographer reveal (E5)
FR61: Epic 4 - Journal objects and The Last Entry
FR62: Epic 4 → Epic 6 - Ember Hoards in A, B, C (E4); Swing-secret hoard (E6)
FR63: Epic 4 - Story flags `last_entry_read`, `lurker_met`
FR64: Epic 5 - Hub village, deposit + heal on arrival
FR65: Epic 5 - Fast travel to the hub and stations
FR66: Epic 5 - The Watching Departure
FR67: Epic 5 - Cartographer
FR68: Epic 5 - Smith gear
FR69: Epic 5 - Naturalist
FR70: Epic 5 → Epic 6 - Guild records and Memorial Wall (E5); partner name (E6)
FR71: Epic 5 - Minimal Journal tab
FR72: Epic 5 - Oda's house and the new-game opening
FR73: Epic 5 - NPC dialogue framework
FR74: Epic 6 - M2 closing beat
FR75: Epic 3 - SFX script pipeline
FR76: Epic 3 - Core SFX set
FR77: Epic 3 → Epic 7 - Chain-reactive music and motif sketch (E3); composed themes (E7)
FR78: Epic 7 - Full Field Journal
FR79: Epic 7 - Title logo art
FR80: Epic 7 - Art pass
FR81: Epic 7 - Shared build, tester round, distribution decision

**Other requirement families** (each carries its owner tag above; summary):
- **NFR1–NFR19:** cross-cutting acceptance criteria. Performance (NFR1–5) is measured in the E1 perf scene and the E7 performance pass; NFR8–10 and NFR16–17 apply to every story from E1.
- **AR1–AR58:** Epic 1 holds the migration and foundations (AR1–AR15, AR18–AR31, AR34–AR42, AR46–AR58). AR16 gear → E5/E6. AR17 economy/dialogue → E4/E5. AR32 Weaver → E2/E6. AR33 objects → E1–E6 by tag (silk anchor moves to E4, inert). AR43–AR45 audio → E3. AR56 scripted moments → E4–E6.
- **UX-DR1–UX-DR150:** owners as tagged. E1 owns tokens, HUD, menus kit and E1 screens; E4 the map, the full station menu and zone cross-fade; E5 the speech box, shop, Journal tab and Guild board; E2/E6 the Weaver UI; E3 the Audio tab and stirring sound; E7 Video, Controls, large HUD, full Journal and credits.
- **NR1–NR25:** NR1–NR4 and NR21–NR25 are acceptance criteria on every writing story. NR11 → E1; NR5–NR6, NR10, NR16–NR17 → E4 (registry starts in E4); NR7–NR9, NR13–NR15 → E5; NR12, NR18 → E2/E5/E6; NR19–NR20 → E6.

## Epic List

Milestone 2 (the vertical slice), in risk-first order. Numbering matches the GDD, the architecture, the narrative design and `project-context.md` (E1–E7). Approved 2026-11-12 after advanced elicitation (pre-mortem, cascading failure, assumption audit, steelmanning, time-traveler council) and a party-mode review.

**Rules for every epic**
- Each epic ends in something playable and one playtest question; post a short devlog or private build after each epic and each internal checkpoint.
- **A playtest "no" blocks only the epics that build on that answer** (see Dependencies); its fix becomes the first story of the next dependent epic. Independent epics may proceed.
- **Save format:** `slot_v1` freezes when E1 ships. Every later epic that changes `SlotState` starts with its migration + fixture story, before any feature writes a new field.
- **Writing gate:** voice-anchor approval stories come before the first writing story that needs them (E1 death card; E4 Oda's hand and documents early, the four NPC sets at E4's end).
- **Outside players:** 1–2 at E2 and at E4 through the private web build. E2 testers play blind (never told the fight is "about restraint") and are told the art is placeholder. E7 is the ≈ 5-tester round.

**Dependencies:** E1 → every epic · E2 → E6 · E2 → E3 (the Weaver SFX and the test-arena theme) · E4 → E5, E6 · E5 → E6 · E1–E6 → E7 · E3 has no hard dependents (E7's composed music builds on it; E3 may interleave with E4); soft: E3's Story 3.2 lands before E4's Story 4.11 (the gate tone), and scripted moments use audio cues only when `Audio` exists.

**Story types and human gates** (added after the step-3 elicitation; read by `gds-create-story` and `gds-dev-story`)
- Every story has a **Type:** line. `dev`: the dev agent implements it; done when every AC passes and `run_tests.sh` is green. `content`: the agent drafts text, sprite grids, room layouts or SFX parameters; sonlm approves before commit (story text follows NR2). `designer`: sonlm decides, approves or composes; the agent prepares the material (drafts, builds, mocks) and records the outcome. `playtest`: sonlm (and any outside players) play a build; the agent prepares the build and the record; the outcome is the record. `ux-update`: run `gds-ux` in Update mode with sonlm.
- **Human gates:** any AC that names sonlm, a playtest, an outside player or a devlog is a human gate. The dev agent HALTs and asks; it never fills in, assumes or marks a human gate done itself.
- **Decide before dev (sonlm):** these lines are asked while `gds-create-story` writes the story file and the answer is recorded in its Dev Notes; `gds-dev-story` never makes a design call.
- **Tune after play (sonlm):** for calls that need a playable build (party review, 2026-11-12), the dev agent ships the stated default as a `Tuning` option with tests for every option; the story is code-done when tests pass and design-done when sonlm's choice after playing is recorded in the GDD.
- **Playtest records:** every `playtest` story writes `implementation-artifacts/playtests/<story-key>.md` with: the question(s), who played (sonlm / outside players, blind or not), the build version, the answer (yes / no / mixed), evidence (notes, deaths, attempts), and the follow-up stories it creates.

**Estimate:** E1 L, E2 M, E3 M, E4 L, E5 L, E6 L, E7 M ≈ 44–88 weeks at 5–10 h/week (the GDD's size bands: M ≈ 4–8 weeks, L ≈ 8–16 weeks).

**Follow-ups before `gds-check-implementation-readiness`** (owner: sonlm; both done 2026-11-12)
1. **Done 2026-11-12.** Update the GDD with `gds-gdd` (Update mode): the Epic Structure table (E1 M → L; M2 ≈ 44–88 weeks, corrected from the pre-resize 40–80); the rule that a playtest "no" blocks only the epics that depend on it; the dependency E2 → E3; Brightness in the E1 Options (R1).
2. **Done 2026-11-12.** Customize `gds-create-story` with `bmad-customize` so its inputs load `_bmad-output/game-architecture.md` and the nested GDD and UX spines listed under Source documents (`_bmad/custom/gds-create-story.toml`, commit 81480d1).

### Epic 1: Kit v2: Fair Deaths, Full Move Set

The player dives the rebuilt 22-tile shaft with the full M2 kit (4 HP, Flare Toss, lantern anchors, the three ember stages and the Ember Cache, difficulty tiers), dies fairly and learns why from the death card, saves in 3 slots, and plays on keyboard or gamepad, on desktop and in the browser. Under the hood, the M1 prototype moves onto the M2 architecture.
**Size:** L. **Playable:** the shaft with a placeholder station at the top and two anchors.
**Internal checkpoints:**
- **CP1 Foundations:** M1 migration, `Log`, `Clock`, state objects, `Game`, `RoomLoader` + `World`, `PlayerInput`, glob runner + lint + `spec.gd`, 22-tile shaft, perf scene, export + web smoke. Gate: `test_chain_state` green unchanged, `test_lint` green, the shaft bot-reachable to chain ≥ 5, web debug build boots, perf scene go/no-go (bloom, light budget); then sonlm's laptop feel check (physics interpolation kept or dropped).
- **CP2 Kit:** Health, Flare Toss, `LightSource` + `Sensing` + stirring, interact, anchors, embers and cache, difficulty, placeholder station, HUD v2 + font + Deck check, flash cap + accessibility gate, death-card voice anchors → death card + death line. The playtest question is answerable here.
- **CP3 Menus and meta:** web gate, title, slot picker, difficulty step, saves (3 slots, failure state), Pause + controls reference, Options (Game, Accessibility, Brightness), gamepad defaults + glyph swap + disconnect pause; sonlm reviews UX defaults D1–D15 in the build. `slot_v1` freezes at close.
**Playtest question:** do HP and Flare Toss keep deaths fair?
**FRs covered:** FR1–FR11, FR12 (rest, bank-heal), FR13–FR15, FR16 (lurkers), FR17–FR26, FR27 (object), FR28 (placeholder), FR29 (rest, anchor quit), FR30–FR32, FR33 (E1 tabs + Brightness), FR34, FR36, FR37, FR38 (pogo feel, shake), FR39.
**Also:** AR1–AR15, AR18–AR31, AR34–AR42, AR46–AR58; UX-DR1–UX-DR86 and the E1 rows of the rollout; NR1 (death card), NR2–NR4, NR11.

### Epic 2: Weaver Prototype: The Restraint Fight Is Fun

The player fights a rough Weaver in a test arena and wins by going dark, herding with flares and striking with a light burst; it is proven fun and readable before any content is built around it.
**Size:** M. **Playable:** a debug entry straight into the Weaver test arena (30 × 34 tiles, scrolling inside the 360 px view).
**Notes:** placeholder art; The Fall is stubbed (the fight ends at 6 HP); E2 decides the behaviour at 62–78 px of light and the exact flee target. 1–2 blind outside players.
**Playtest question:** is "go dark → herd → strike" fun and readable, and do testers call it *about restraint* without being told?
**FRs covered:** FR16 (Weaver repel), FR40–FR46 (prototype), FR49 (phase-1 reset).
**Also:** AR32, AR33 (spiderling), AR54 (arena entry arg); UX-DR99–UX-DR100, UX-DR109 (prototype); NR12, NR18 (placeholder staging).

### Epic 3: Audio: Hear the Chain and the Hunters

The player hears the chain climb (pogo pitch +1 semitone per link), hears lurkers stir and growl before seeing them, and feels the music swell with the chain and resolve on a bank.
**Size:** M. **Playable:** the shaft and the Weaver test arena with sound.
**Notes:** SFX script pipeline; positional lurker cues incl. the stirring sound; chain-reactive stems with placeholder music plus a sketch of the shared abyss motif as a placeholder hub stem; 6 dB ducking; Options > Audio. Composed hub, Weaver and Fall themes stay in E7.
**Playtest question:** does sound make the pogo feel great, and are lurkers heard before they are seen?
**FRs covered:** FR33 (Audio tab), FR75, FR76, FR77 (system + motif sketch).
**Also:** AR9 (`Audio` autoload), AR43–AR45; UX-DR77, UX-DR143 (sound).

### Epic 4: Layer 1: Edge of the Abyss

The player descends Layer 1 from the Lip to the Hollow Station: learns each move before it is tested, opens chain gates, explores the Rope Works, Old Mine and Sky Ledge, reads the island's lost and finds Oda's last camp, and maps it all.
**Size:** L. **Playable:** start at the Lip, descend to the Hollow Station (the hub is a placeholder room; the gate-2 shortcut leads to it).
**Internal checkpoint:** save v2 migration first → **S1–S3 + chain gate 1** (the teaching half: every move taught; 1–2 outside players) → S4, S5, side areas, map tab.
**Notes:** UX update (map tab mock) at the start; the story-flag registry starts here; places **visible, inert silk anchors and sealed secret alcoves** in A, S2 and C with their ids in the room headers (the bot skips them); Oda's hand and document voice anchors early, the four NPC anchor sets at the end; a third regular enemy only if the walk-through needs one.
**Playtest question:** does each move get taught before it is tested, do anchors keep retries short, and do players go for the gates and side areas?
**FRs covered:** FR27 (placement), FR28 (final station), FR38 (creature sparks), FR52 (inert anchors + alcoves), FR53–FR59, FR60 (map), FR61, FR62 (A, B, C hoards), FR63.
**Also:** AR17 (economy), AR21 `map=`, AR26 (Layer 1 rooms), AR33 (gate, hoard, journal, silk anchor inert), AR50 (bot over every room), AR56 (`last_entry.gd`, `weaver_reveal.gd`); UX-DR87, UX-DR90, UX-DR93–UX-DR94, UX-DR105, UX-DR142, UX-DR144; NR1 (Oda, documents, NPC anchors), NR5–NR6, NR10, NR16–NR17.

### Epic 5: Abyss Island: Come Home and Spend

The player starts a new game in Oda's house, registers the First Dive with Old Tessaly, dives, rides the lift home (watched by the creatures), deposits and heals, and spends embers on maps, hints, gear and palettes while the hub's people slowly react to what they've done.
**Size:** L. **Playable:** dive into Layer 1, come home and spend.
**Notes:** save migration first; UX update first (Oda's house and the opening, lift-ride timing, speech box, shop, Journal tab); dialogue framework (`{seen, idle}`, flag and length validators); gear as data; price-tuning pass. NPC names and pronouns decided here (copy avoids pronouns until then).
**Playtest question:** do the three ember stages and the shops make "get home with it" feel worth it? Are the prices right?
**FRs covered:** FR12 (home heal), FR29 (hub autosave), FR60 (Cartographer reveal), FR64–FR69, FR70 (records + Wall), FR71–FR73.
**Also:** AR16 (gear), AR17 (dialogue), AR26 (hub room), AR33 (`npc.gd`), AR56 (`watching_departure.gd`); UX-DR91–UX-DR92, UX-DR95, UX-DR97, UX-DR108; NR7–NR9, NR13–NR15.

### Epic 6: The Weaver and Swing: The Complete Slice

The player faces the final Weaver at Weaver's Hollow, survives The Fall into the Layer 2 landing arena, wins phase 2, gains Swing, rides home watched by the abyss, and returns to Layer 1 to open the three Swing secrets, one of which adds a name to the Memorial Wall.
**Size:** L. **Playable:** the full slice, from the hub through the Weaver and back for the secrets.
**Notes:** save migration first; segmented Weaver art; The Fall via `World.scripted_cut()`; phase checkpoint and its respawn route; Swing activates the anchors and alcoves E4 placed (no E4 room re-edits); sonlm names Oda's dive partner; defeat reads as a win, then the withdraw coda.
**Playtest question:** does the fight teach restraint within 3–8 attempts, and does Swing make the return trip rewarding?
**FRs covered:** FR38 (slow-mo climaxes), FR40 + FR44 (final), FR47, FR48, FR49 (phase checkpoint), FR50, FR51, FR52 (activation + rewards), FR62 (secret hoard), FR70 (partner name), FR74.
**Also:** AR16 (`silk_grip`), AR24 (`scripted_cut`), AR26 (landing arena), AR32, AR56 (`the_fall.gd`, defeat slow-mo); UX-DR99, UX-DR101, UX-DR109 (final); NR5 (partner flag), NR12, NR18–NR20.

### Epic 7: Slice Polish and Ship: The First Shared Build

About five outside testers play the polished M2 slice on web and desktop with full settings (video, rebinding, large HUD, text scale, timing assists, visual sound cues), the full Field Journal, composed music and the final art pass; their notes are measured against the Success Metrics and the Steam vs itch.io decision is made.
**Size:** M. **Playable:** the shared M2 build.
**Notes:** Steam Deck and accessibility test passes; title logo; credits with AI disclosure and the font credit; performance pass (60 FPS over a 10-minute Layer 1 run incl. the Weaver); length-validator pass over all M2 text.
**Playtest question:** the GDD Success Metrics table (≈ 5 testers).
**FRs covered:** FR33 (Video, Controls, a11y additions), FR35, FR77 (composed themes), FR78–FR81.
**Also:** AR35 (rebinding), AR36 (`set_assist`), AR52 (final builds); UX-DR78–UX-DR80, UX-DR96, UX-DR98, UX-DR102–UX-DR103, UX-DR124, UX-DR133–UX-DR134; NR8 (pass).

## Epic 1: Kit v2: Fair Deaths, Full Move Set

The player dives the rebuilt 22-tile shaft with the full M2 kit (4 HP, Flare Toss, lantern anchors, three ember stages and the Ember Cache, difficulty tiers), dies fairly and learns why from the death card, saves in 3 slots, and plays on keyboard or gamepad, on desktop and in the browser. Under the hood, the M1 prototype moves onto the M2 architecture. Story order follows the architecture's foundation order (AR4). Checkpoints: **CP1 Foundations** (1.1–1.15) → **CP2 Kit** (1.16–1.30) → **CP3 Menus and meta** (1.31–1.41).

Every story in this epic: tests green (`cd game && ./run_tests.sh` → `== ALL GREEN`); new design guarantees compare against `tests/spec.gd`, never the tuning value under test; feel is reported as "needs a feel check on the laptop", never claimed from headless tests.

### Story 1.1: Move M1 into the M2 folder layout

**Type:** dev

As the developer,
I want the M1 scripts, scenes and tests moved into the M2 domain folders with no behaviour change,
So that every later story builds on the architecture's layout instead of extending M1 patterns.

**Acceptance Criteria:**

**Given** the M1 tree (`scripts/chain_state.gd`, `player.gd`, `crawler.gd`, `lurker.gd`, `fx.gd`; `scenes/enemies/*`, `scenes/player.tscn`; `tests/run_tests.gd`)
**When** the migration commit lands
**Then** `chain_state.gd` is in `scripts/rules/`; `player.gd`, `crawler.gd`, `lurker.gd` in `scripts/actors/`; `fx.gd` in `scripts/core/`; `scenes/enemies/*` and `player.tscn` in `scenes/actors/`; `tests/run_tests.gd` is `tests/test_chain_state.gd` (AR1)
**And** every move is a `git mv` in one commit, with each `.gd.uid` moved beside its script; `scripts/` and `scenes/` share the domain folders `core/ rules/ world/ actors/ objects/ moments/ ui/ audio/ dev/` (AR58)

**Given** the moved files
**When** every `res://` path that points at a moved file is rewritten by hand (the M1 scenes carry no `uid=` attributes: e.g. `shaft.gd`'s preloads of `res://scenes/enemies/*.tscn`, `shaft.tscn`'s `res://scenes/player.tscn`, the test's `res://scripts/chain_state.gd`; the full list goes in the commit message) and `godot --headless --path game --import` runs
**Then** loading the project and every moved scene prints no `SCRIPT ERROR` or `ERROR:` line

**Given** `run_tests.sh` updated only for the renamed test
**When** it runs
**Then** it is green, with `test_chain_state` unchanged except its preload path and `smoke_shaft` still passing, before any other change is made
**And** `shaft.gd` and `shaft.tscn` stay where they are until Story 1.7 retires them

### Story 1.2: Log and a Clock that owns time

**Type:** dev

As the developer,
I want one logger and one owner of `Engine.time_scale`,
So that hitstop and later slow-mo stack predictably and freeze with the pause.

**Acceptance Criteria:**

**Given** `scripts/core/log.gd` (a static `Log` class, not an autoload, with no dependency on `Game` or `Settings`)
**When** code calls `Log.info(cat, msg)` or `Log.debug(cat, msg)`
**Then** it prints `[category] message`; the categories are `SAVE ROOM INPUT CLOCK LURKER WEAVER AUDIO UI`; an unknown category asserts; info and debug are silent in release builds; `Log.enabled(cat)` guards hot paths (AR55)

**Given** the `Game` autoload (`scripts/core/game.gd`, no `class_name`) registered as the project's first `[autoload]`, holding a `clock` child (`scripts/core/clock.gd`)
**When** `Game.clock.request(&"hitstop", 0.05, 0.075)` is active
**Then** `Engine.time_scale` equals the product of all active requests (× assist 1.0) and the request ends after 0.075 s of real, unpaused time via `create_timer(t, false, false, true)` (AR36); `Game` is the only autoload until `Audio` arrives in E3 (AR9)
**And** while `SceneTree.paused` is true, requests do not count down
**And** player death and `_exit_tree` clear every request

**Given** `player.gd`'s four direct `Engine.time_scale` writes (M1 lines 85, 270, 272 and 338)
**When** they are replaced by Clock requests
**Then** a pogo hit still freezes for 75 ms (FR4) and no script outside `clock.gd` writes `Engine.time_scale`
**And** re-requesting an id that is already active refreshes its duration and never stacks with itself
**And** `tests/test_clock.gd` covers stacking of different ids, re-requesting the same id, real-time expiry, pause freeze and clear-on-death

**Given** `Game` as the first autoload
**When** headless tests run
**Then** each test is a script extending `Node`, run as a scene by `tests/runner.tscn` (`godot --headless --path . res://tests/runner.tscn -- res://tests/<test>.gd`), so `Game`, `preload` and `class_name` work as in game code (under `--script` a test that touches `Game` fails to compile and can hang or exit 0 with no output); the runner prints the test's `ok` / `FAIL` lines and `PASS` / `FAILED`, exits non-zero on a failure, and fails a test that prints no `PASS` line or runs longer than 120 s (R17)
**And** `test_chain_state.gd`, `smoke_shaft.gd` and `screenshot.gd` move onto the runner in this story with no assertion changes, and `run_tests.sh` runs its listed tests through it

### Story 1.3: Tuning as data

**Type:** dev

As the developer,
I want every number a rule could bend to live in `rules/tuning.gd`,
So that gear, assists and playtests change values in one place that matches the GDD tables.

**Acceptance Criteria:**

**Given** the 44 `@export` tuning vars on `player.gd` (28), `crawler.gd` (5) and `lurker.gd` (11)
**When** they migrate
**Then** each bendable value is a `const` in `scripts/rules/tuning.gd` with a `##` comment giving unit, intent and "was X", listed in `BASE`; values no system will bend (physics layer values, pixel offsets) stay local consts; the chain-curve consts that `test_chain_state` reads (`MAX_CHAIN`, `BASE_RADIUS`, `SNUFF_RADIUS`, `BASE_BLOOM` and the rest of the curve) stay in `ChainState`, since no gear bends them in M2 and that test must stay unchanged (AR15)
**And** a regression test iterates over a fixture of all 44 M1 `@export` defaults, each marked moved to `Tuning` or kept local (with its new home), and asserts every value still equals its M1 default; these include the playtested values in FR1–FR8 and FR58: run 110 px/s with ground/air accel 900/1500 px/s²; jump −330 px/s (apex ≈ 60 px), early release ×0.45; gravity 900 px/s² rising, ×0.6 falling, max fall 210 px/s; coyote 0.08 s, buffer 0.10 s; air dash 260 px/s for 0.12 s; slash active 0.12 s, cooldown 0.22 s, hitbox 22×16; pogo armed 0.22 s, hitbox 26×24, bounce −300 px/s, hitstop 75 ms; body 10×20, hurtbox 8×18; chain cap 20 links, light 40 + 22·√links px, Blade Bloom ×(1 + 0.18·√links) up to ×1.8; base light 40 px, Snuff light 12 px; cling grace 1.0 s per cling (a pogo hit refills it), slide 18 px/s, kick (150, −260) px/s with 0.15 s no steering; hoverer drift 10 px over 2.4 s

**Given** `Tuning`
**When** code calls `f(&"key")`, `flag(&"key")` or `apply_gear(ids)`
**Then** `f` returns the current value and asserts on an unknown key; `apply_gear` applies modifiers in the fixed order set → add → mul regardless of gear order and emits `changed`; the gear table is empty until E5
**And** `tests/test_tuning.gd` covers the ordering with fixture modifiers, and `rules/tuning.gd` mentions no `Node`, `Input`, `Engine` or `Game`

**Given** `Game.tuning`
**When** actors need a value
**Then** they read `Game.tuning.f(&"key")` each tick and never cache it across frames

### Story 1.4: State objects in the Game autoload

**Type:** dev

As the developer,
I want `Settings`, `SlotState` and `DiveState` as pure objects that `Game` holds for the whole session,
So that global, per-slot and per-dive state each have exactly one home.

**Acceptance Criteria:**

**Given** `scripts/rules/settings.gd`, `slot_state.gd` and `dive_state.gd` (`RefCounted`, typed signals, `to_dict()` / `from_dict()` / `reset()`)
**When** `Game` initialises
**Then** `Game.settings`, `Game.slot`, `Game.dive`, `Game.tuning` and `Game.clock` exist and stay the same instances all session; `reset()` and `from_dict()` reset in place and emit their change signals (AR10, AR11)
**And** `Game.reset_for_tests()` restores defaults in place

**Given** `shaft.gd`'s statics (`ambient_index`, `show_controls`, `best_chain`, `deaths`, `checkpoint`, `banked_embers`)
**When** they move into the state objects
**Then** `best_chain` and `deaths` are `SlotState` records, `checkpoint` becomes the `DiveState` respawn point, which no longer follows M1's per-frame "last ledge stood on" (the room's spawn until stations and anchors set it in Story 1.24; the last-ledge tracker survives only for hazard respawn, Story 1.19), `banked_embers` is `DiveState` carried embers, `ambient_index` becomes `Settings` brightness, and `show_controls` is dropped (the M1 controls bar is removed, UX-DR26)
**And** `SlotState` also holds `difficulty` (default Normal); its death-cost rules arrive in Story 1.22
**And** `DiveState` holds `killed` (room_id + grid cell) with `mark_killed(room_id, cell)` and `is_killed()`, and `reset()` clears it (AR14, AR24)
**And** `shaft.gd` reads and writes them only through `Game` until Story 1.7 retires it

**Given** `Settings.set_value(&"key", v)`
**When** a value changes
**Then** `Settings` (pure, in `rules/`) emits `changed`, and a `core/` store writes `user://settings.json` with its own `version`, at most once per frame, to a path tests can redirect so they never touch the real file; a missing or corrupt file, or a missing or bad key, falls back to the default and the file is rewritten; parsing uses `JSON.new().parse()`, which prints no engine error (AR14, R15)
**And** `SlotState.set_flag(id, value)` emits `flag_set` and `DiveState.add_carried(n)` emits `carried_changed`
**And** state is written only through rule methods that emit typed signals; reads go through `Game` refs; no event bus, no node paths (AR18)
**And** `tests/test_state.gd` builds fresh instances per test and covers round-trips, `killed` and the corrupt-file fallback, with no `ERROR:` line in the output

### Story 1.5: Rooms as text, the M1 shaft at 22 tiles

**Type:** dev, content

As the level designer,
I want rooms written as text files that are validated before they build,
So that every room is reviewable in git, testable on its own, and fits the 360 px play area.

**Acceptance Criteria:**

**Given** `game/rooms/l1/m1_shaft.txt` (`key=value` header with `id=`, `zone=`, `spine=true`, `exits=`, its bottom exit leading to its own top entry (R16); `---`; a grid of equal-width rows, 22 columns including walls, 1 char = 16 px)
**When** `RoomLoader.load_room_from_path()` parses it
**Then** the pure validator returns no errors and the room builds with the TileSet and ledge rims made in code (AR21, AR22, FR39)
**And** the layout keeps the M1 shaft's intent within 352 px: hoverer rows with left/right choices, lurker pockets with an escape in reach, ledges every ≤ 1.5 s of fall (FR57)
**And** the 22-column layout is level design: Claude drafts it from the M1 30-column layout and sonlm approves it before commit, since the CP1 and CP2 verdicts are judged on it

**Given** the M1 tests that load `shaft.tscn` (`tests/smoke_shaft.gd`, `tests/screenshot.gd`)
**When** `m1_shaft.txt` builds
**Then** both are ported to load `m1_shaft` through `RoomLoader` with a test player and a stub node in group `world` that provides `play_rect()`, with M1's hard-coded coordinates (spawn ledge, 2-tile walls, rows 44–84) re-targeted by position, and every M1 smoke check passes against the 22-column layout; no test loads `shaft.tscn` any more

**Given** a room file with unequal rows, an unknown char or a duplicate id (fixtures in `tests/rooms/`)
**When** it is validated
**Then** the validator returns `Array[String]` errors as `file:row:col` messages; the loader `push_error`s each and returns null; tests inspect the list without triggering `push_error`

**Given** `world/room_legend.gd`
**When** a char is used in a grid
**Then** the legend is its single definition (`c` crawler walker, `h` crawler hoverer, `L` lurker, …), documented in `docs/rooms.md`, and a new char is added there first

**Given** `world/room.gd`
**When** it spawns or places entities
**Then** `spawn(scene, pos, args := {})` sets args before `add_child`, and `entry_position(entry)` and `bounds()` exist (AR23)
**And** the room builds headless without `World`, a save or the hub; `RoomLoader.load_room(id)` resolves an id to its file

### Story 1.6: The World scene replaces the M1 shaft

**Type:** dev

As a player,
I want death to put me straight back in the shaft without a reload, with the play area framed between the HUD gutters,
So that respawns are instant and the HUD has its own space.

**Acceptance Criteria:**

**Given** `scenes/world/world.tscn` + `world/world.gd` (group `world`) as `run/main_scene`, with `RoomHolder`, `Player`, `Camera2D` (`world/camera_rig.gd`) and `UI` (`CanvasLayer`, `PROCESS_MODE_ALWAYS`) holding `Gutters` (two flat 60 px strips in a placeholder dark colour until the palette tokens land) and `ScreenRouter` (one screen at a time; opening replaces, never stacks)
**When** the game boots
**Then** `m1_shaft` loads into `RoomHolder` and the 360 px play area sits centred between the gutters (usable gutter width 58 px; menus use the x 60–420 column) with camera limits from the room bounds, and UI layers follow the depth order world → gutters and in-world UI → full-screen menus (AR19, AR39, UX-DR18, UX-DR23)

**Given** `World.play_rect()`
**When** the lurker checks whether it is on screen
**Then** it uses the play rect inside the gutters, never the viewport (`get_viewport_rect()` is gone from `lurker.gd`)
**And** a test proves a lurker inside the viewport but behind a gutter never notices the player (AR20)

**Given** the player dies (M1 rules still apply until Story 1.19)
**When** `World` handles the death
**Then** it re-instances `Player` at the `DiveState` respawn point without `reload_current_scene()`, emits `player_spawned(player)` and clears Clock requests; enemies killed this dive stay dead (`DiveState.killed`); the respawn point is the room's spawn until stations and anchors set it (Story 1.24), and M1's per-frame last-ledge checkpoint no longer moves it (AR25)

**Given** the camera
**When** this story lands
**Then** camera shake lives only in `camera_rig.gd` (the only `randf` use) with the 70 px downward lead (FR3, AR27, UX-DR123)
**And** `shaft.gd` and `shaft.tscn` stay, loaded by neither the game nor any test (Story 1.5 ported the tests), until Story 1.7 deletes them

### Story 1.7: Room swaps, physics interpolation and retiring `shaft.gd`

**Type:** dev

As a player,
I want to cross from one room to the next without a hitch or a smear,
So that the shaft, and later the whole layer, feels continuous.

**Acceptance Criteria:**

**Given** `enter_room(room_id, entry)` (exercised with two rooms in `tests/rooms/`)
**When** the player crosses an exit
**Then** the swap is deferred, the old room is removed from the tree before `queue_free()`, the player is placed, camera limits update, `reset_physics_interpolation()` runs, `Game.slot.visit(id)` and `room_entered` fire; crossing with `chain.count > 0` calls `chain.break_chain()` first (FR6, AR24)

**Given** physics interpolation
**When** this story lands
**Then** 2D physics interpolation is on (`physics/common/physics_interpolation`, 60 ticks, `snap_2d_transforms_to_pixel` kept) and every teleport calls `reset_physics_interpolation()` (AR6)

**Given** `m1_shaft`'s bottom exit (R16)
**When** the player crosses it
**Then** `enter_room(&"m1_shaft", <top entry>)` places them at the top entry, and a live chain is banked first, exactly like a landing; a test crosses it with a chain and checks the carried total

**Given** a death
**When** `World` respawns the player
**Then** it goes through `enter_room(respawn room, respawn object)`, rebuilding the room so persistent objects, the Ember Cache rule and the killed-enemy rule apply (cells in `DiveState.killed` are skipped) (AR24, AR25)
**And** an enemy the player kills calls `Game.dive.mark_killed(room_id, cell)`; a test kills a crawler, then dies (and, separately, loops through the bottom exit) and finds it still gone

**Given** no test loads `shaft.tscn` any more (Story 1.5)
**When** `shaft.gd` is retired
**Then** `shaft.gd` and `shaft.tscn` are deleted, with the M1 patterns in AR3 (statics, scene reload, viewport-based notice); the F1/F2/F3 hotkeys are gone (no `KEY_F` in `game/scripts/`) and the brightness level applies from `Settings` (changed through DevTools until Options lands in Story 1.36) (AR2)

### Story 1.8: PlayerInput intents

**Type:** dev

As a player,
I want every press read once per tick and kept through hitstop,
So that no input is ever dropped and a tap on Light never breaks my chain.

**Acceptance Criteria:**

**Given** `actors/player_input.gd` (`PlayerInput`, a child of `Player`)
**When** a physics tick runs
**Then** it samples `InputMap` once into intents `move`, `jump_pressed` / `jump_held`, `attack_pressed`, `dash_pressed` / `dash_held`, `light_tap`, `snuff_active`, `cling_held`, `interact`, and `player.gd` reads only these intents (AR34)

**Given** Light pressed and released
**When** the release comes inside `Settings.light_tap_window` (0.12 s default; 0.2 and 0.3 s also tested)
**Then** it produces `light_tap` and never `snuff_active`; held past the window it produces `snuff_active` (FR9, UX-DR119)
**And** the Light timer runs on real time, so a hitstop never stretches the window; a test holds Light across a 75 ms hitstop

**Given** a 75 ms hitstop (`Engine.time_scale` 0.05)
**When** Jump or Attack is pressed during it
**Then** the press is buffered in real time and acted on after the hitstop (NFR2)

**Given** `interact`
**When** ↓ is pressed while standing still on the ground (sideways input below the 0.2 deadzone)
**Then** `interact` fires; ↓ on a wall still drops off it (FR26, UX-DR118)
**And** `lock()` / `unlock()` suppress all intents for scripted moments
**And** before switching to intents, smoke checks are added against the M1 input path for run 110 px/s, coyote time 0.08 s, jump buffer 0.10 s and air dash 260 px/s for 0.12 s (M1 has none); they and the existing jump-height and cling/kick-off checks still pass after the switch (FR1, FR2, FR7, AR3)

### Story 1.9: Glob test runner, Spec and the architecture lint

**Type:** dev

As the developer,
I want tests discovered by name and the architecture's rules enforced automatically,
So that no test silently stops running and the M2 patterns hold as the code grows.

**Acceptance Criteria:**

**Given** `run_tests.sh`
**When** it runs
**Then** it executes every `tests/test_*.gd` and `tests/smoke_*.gd` by glob through the scene runner (Story 1.2), fails a test with no `PASS` line or running longer than 120 s, fails on any `SCRIPT ERROR` or `ERROR:` line, keeps the `ok …` / `FAIL …` + `PASS` / `FAILED` format, and ends with `== ALL GREEN` when everything passes (AR47)

**Given** `tests/spec.gd` (preloaded, no `class_name`)
**When** a test checks a design guarantee
**Then** it compares against Spec constants (`TELEGRAPH_MIN := 0.75`, `BOT_MIN_CHAIN := 5`, `BASE_LIGHT := 40.0`, `NOTICE_MIN_RADIUS := 80.0`), each carrying its GDD citation (AR49)

**Given** `tests/test_lint.gd`
**When** it scans `game/scripts/`
**Then** it fails on `Engine.time_scale =` outside `clock.gd`; `Input.` outside `player_input.gd`, `core/devices.gd` and `ui/kit/`; bare `print(` outside `core/log.gd`; `.free()`; `"/root/`; `KEY_F`; `randf`/`randi` outside camera shake; `Node`/`Input`/`Engine`/`Game.` in `rules/`; upper-layer class names in `core/`; `DevTools` outside `dev/` and `tests/` — each hit printing `FAIL lint <file>:<line> <rule>` (AR48)
**And** the lint is green on the migrated code, and each rule is proven to fire by a sample-line test

### Story 1.10: Room smoke tests and the reachability bot

**Type:** dev

As the level designer,
I want every room checked for fairness and reachability automatically,
So that a layout change can never quietly break a guarantee.

**Acceptance Criteria:**

**Given** `tests/smoke_rooms.gd` (replacing `smoke_shaft.gd` as ported in Story 1.7)
**When** it loads every `rooms/**/*.txt` standalone, with a stub node in group `world` that provides `play_rect()`
**Then** it checks: the file validates; ids are unique across all files; every lurker telegraph ≥ `Spec.TELEGRAPH_MIN`; no lurker notices outside the play rect; a Snuff, landing or cling in time drops a hunting lurker's lethality; base light (40 px) is never noticed; every hazard pit has a ledge or wall within a 1.5 s fall (AR50, NFR10)
**And** in rooms marked `spine=true`, no fall between ledges lasts longer than `Spec.LEDGE_FALL_MAX` (1.5 s at 210 px/s = 315 px; GDD Level Types), measured as the vertical gap between consecutive ledge rows across all columns, unless the stretch is declared a narrow cling stretch in the room header; rooms under `rooms/dev/` are only validated, never swept for fairness

**Given** `tests/smoke_bot.gd` (the M1 bot, ported)
**When** it runs every `spine=true` room with plain movement and no dash
**Then** it reaches chain ≥ `Spec.BOT_MIN_CHAIN` in each (`m1_shaft` today) and the exit backstop never fires on its line; targets are picked by position, never by group index

### Story 1.11: DevTools: entry args and overlays

**Type:** dev

As the developer,
I want debug-only entry arguments and overlays,
So that I can jump straight into any room and state and see the invisible rules without any of it shipping.

**Acceptance Criteria:**

**Given** `scripts/dev/dev_tools.gd` (`DevTools`)
**When** `World._ready()` runs in a debug build (`OS.is_debug_build()`)
**Then** `world.gd` adds DevTools by loading `res://scripts/dev/dev_tools.gd` by path string inside `if OS.is_debug_build()` (no `preload`, so a release export without `scripts/dev/` still loads `world.gd`); in a release build it is never added; that line is the only reference to `dev/` outside `dev/` and `tests/`, and the lint allows exactly that line, proven by a test (AR54)

**Given** desktop args `-- --room=<id> --chain=<n>` or the URL query `?room=<id>&chain=<n>` in a web debug build
**When** the game starts
**Then** it loads that room with that chain; later systems register their own args as they land (`--hp` in Story 1.19, `--difficulty` in Story 1.22) and `-- --log=lurker,clock` enables those `Log` categories; `--set=<key>:<value>` overrides any `Settings` value for the session only, never written to `settings.json`
**And** the URL-query parsing is a pure function with a unit test here; Story 1.13's Playwright check boots `?room=perf_worst` in the web debug build (how accessibility and brightness settings are changed until Options lands)

**Given** the dev-only overlay action on the backquote key
**When** it is pressed repeatedly
**Then** it cycles: play rect + gutters; light radii + notice/sense rings; room exits + persistent object ids; FPS + on-screen `PointLight2D` count + active Clock requests; then off
**And** no function key is bound anywhere

### Story 1.12: Worst-case performance scene

**Type:** dev

As the developer,
I want the heaviest Layer 1 situation measured early on my weakest targets,
So that the light budget and bloom are decided on data before any art depends on them.

**Acceptance Criteria:**

**Given** `rooms/dev/perf_worst.txt` (Old Mine density: ≥ 1 lurker per screen plus hoverer rows; the player at chain 20; stand-in light sources where a flare and an Ember Cache will be; placeholder art)
**When** it is started with `--room=perf_worst`
**Then** it runs in the editor and in desktop debug builds; its web debug run and its exclusion from release presets arrive with the presets in Story 1.13 (AR5)

**Given** the lights in the scene
**When** they render
**Then** every `PointLight2D` shares `art/light.png` via `texture_scale`; small glows (eye cores, ember cores, ledge rims) are unshaded sprites; lurker wall glow falls back to a sprite glow when more than 6 `PointLight2D` would be on screen; a test with 8 light sources on screen proves at most 6 `PointLight2D` stay lit, lurker glows switching to sprites first and the player's and flares' lights never (AR46)
**And** `Fx` builds each material once as a cached static (M1's per-effect `_unshaded()` is fixed)

**Given** the measurement procedure the agent writes in `docs/perf.md` (60 s run at ×3 on the laptop and at the ×2 embed in desktop Chrome/Firefox, with engine glow off and on; plus an HD 620-class machine if available) an FPS + worst-frame readout in the DevTools overlay, and a debug `--glow=on|off` entry arg (`?glow=` on web) that switches engine glow
**When** this story is done
**Then** the procedure and the readout are ready to run; the measurements themselves are taken by sonlm in Story 1.15 (a human gate: the server is headless, and the agent never records a number it did not measure) (NFR1, NFR5)

### Story 1.13: Export pipeline and web boot smoke

**Type:** dev

As the developer,
I want one server command that validates content, exports every target and smoke-tests the web build,
So that every build I play on the laptop is known to boot.

**Acceptance Criteria:**

**Given** a committed `game/export_presets.cfg`
**When** it is inspected
**Then** it has Windows, Linux and Web (single-threaded) release presets plus a debug web preset; templates are pinned to 4.7.2; the include filter has `rooms/**/*.txt`; release presets exclude `rooms/dev/*`, `tests/*` and `scripts/dev/*`; the debug web preset includes `rooms/dev/perf_worst.txt` (Story 1.12); all built from Godot 4.7.2 with the Compatibility renderer (AR51, NFR7)

**Given** `tools/export.sh`
**When** it runs on the server
**Then** it validates every room file (any error stops the build), exports the three targets headless, checks the web download is under 30 MB, runs the web smoke check and writes to `builds/<version>/` (gitignored) (AR52)
**And** it lists each release PCK's contents and fails if `rooms/dev/`, `tests/` or `scripts/dev/` appear, and the release web build gets the boot-only check (AR53), proving `world.gd` loads without `scripts/dev/`
**And** later stories add their checks to it (string keys and licence copy in Story 1.17)

**Given** `tools/web_smoke/` (Playwright version pinned in `package.json`, Node 24, headless Chromium; outside `game/`)
**When** the debug web build boots
**Then** the console shows `SMOKE boot ok` and the check passes, also when booted with `?room=perf_worst`; the save/reload check is added in Story 1.39 (AR53)
**And** the engine upgrade checklist is written in `docs/` (AR7)

### Story 1.14: Display scaling and web input

**Type:** dev

As a player on any screen,
I want the game scaled crisply to my window or browser,
So that pixels stay sharp and the page never scrolls under me.

**Acceptance Criteria:**

**Given** `core/display.gd`
**When** the window or canvas size changes
**Then** the 480×270 view uses an integer scale, letterboxed with nearest filtering; on web the scale is picked from physical pixels (CSS size × devicePixelRatio; a 960×540 embed at DPR 1.5 runs at ×3) and below 480×270 physical pixels it fits with a fractional nearest-neighbour downscale; on PC the default window is ×3 and the minimum is 480×270 (AR8, UX-DR147, UX-DR148, NFR6)
**And** on web, arrows, Space and function keys never scroll or act on the page (UX-DR122)

**Given** the debug web build in the Playwright check
**When** a simulated devicePixelRatio is applied
**Then** the chosen integer scale matches the rule above (AR53)

### Story 1.15: CP1 gate: feel check and performance verdict

**Type:** playtest

As the designer,
I want to play the migrated shaft on my laptop and in the browser and record the verdicts,
So that the kit is built on foundations I trust.

**Acceptance Criteria:**

**Given** the CP1 build
**When** the automated gate runs
**Then** `test_chain_state` passes unchanged from M1 (except its preload path and its move onto the scene runner in Story 1.2; no assertion changes), `test_lint` is green, the bot reaches chain ≥ 5 in the 22-tile shaft, and the web debug build boots in the Playwright check

**Given** sonlm plays the desktop build at ×3 (60 Hz, and a high-refresh display if available)
**When** the feel check is done
**Then** physics interpolation is kept or turned off, and the decision and reason are recorded in `project-context.md` and the architecture (AR6)

**Given** the Story 1.12 procedure
**When** sonlm runs it on the laptop (×3), in desktop Chrome and Firefox at the ×2 embed and, if available, on an HD 620-class machine (if not, the gap is recorded), with engine glow off and on
**Then** min/average FPS and the worst frame time for each run are recorded in `docs/perf.md`, and the engine-glow go/no-go, the confirmed or tightened light budget and a recommendation on a flare cap are recorded in the architecture and the GDD Open Questions rows (AR5)
**And** a devlog or private build is posted; if the feel check fails, its fix stories come before CP2

### Story 1.16: Effects accessibility gate and flash cap

**Type:** dev

As a player sensitive to flashing or motion,
I want every effect to respect reduce flashing, screen shake and reduced motion,
So that the game is safe to play from the first kit build.

**Acceptance Criteria:**

**Given** `Settings.reduce_flashing`, `shake` and `reduced_motion`
**When** an effect plays
**Then** only `Fx`, camera shake, the invulnerability blink and UI easing read them, through one gate; there are no per-effect toggles (AR57)

**Given** every `Fx` effect
**When** it is defined
**Then** it declares its flash rate, and a test asserts no effect exceeds 3 flashes per second, pulses ≤ 2 Hz and blinks at 2.5 Hz (NFR8, UX-DR125)

**Given** reduce flashing is on
**When** pogo sparks play
**Then** they use half the count and half the size (UX-DR126); the hit flash (Story 1.19) and the bank burst (Story 1.26) are new effects that declare their reduce-flashing variants through this gate when they land
**And** with screen shake off the camera never shakes; the pogo freeze frame and sparks on every hit still play (FR38)

**Given** code-built effects
**When** they finish
**Then** they free themselves (`finished` → `queue_free`), use `CPUParticles2D` with cached materials, and new effects warm up at room load (AR46)
**And** until Options lands (Story 1.36) these settings are set through `Settings` in tests and DevTools

### Story 1.17: String table, pixel font and theme

**Type:** dev

As a player,
I want crisp 8 px text in every menu and on the HUD,
So that everything I read is sharp at every integer scale.

**Acceptance Criteria:**

**Given** `game/text/strings.csv` and its generated `.translation` files (committed)
**When** code shows player-facing text
**Then** it uses `tr("UPPER_SNAKE_KEY")` with a domain prefix; a test fails on any `tr()` key missing from the table, and `tools/export.sh` validates keys too (AR41, NFR17)

**Given** `game/fonts/fusion-pixel-8px-proportional-latin.otf` + `OFL.txt` + `LICENSES/` (release tag pinned at download)
**When** text renders
**Then** it uses size 8 with antialiasing and hinting off; `tools/export.sh` copies `OFL.txt` and `LICENSES/` into every build, plus Godot's MIT licence and third-party notices (from `Engine.get_license_text()`, `Engine.get_copyright_info()` and `Engine.get_license_info()`) as `GODOT_LICENSES.txt` (AR42, NFR18, UX-DR11, UX-DR16)

**Given** `ui/theme_builder.gd`
**When** the theme is built in code (no `.tres`)
**Then** it provides `hud-value` (8/8), `hud-value-large` (16/16), `menu-item` (8 px, 24 px rows) and `body-line` (8 px on a 12 px pitch), plus the 1 px four-side text outline in the zone surface colour for text over the play area (UX-DR12, UX-DR15)
**And** coverage is Latin-1 + Latin Extended-A; M2 ships English only, the HUD carries no localised text, and text is text only, no voice acting (UX-DR17, UX-DR150, NR25)
**And** all UI copy is terse field notes, names shapes never colours, never says "roguelike" or "Downwell-like" and never shows a completion percentage (UX-DR54, UX-DR55, UX-DR56)

### Story 1.18: Palette tokens, contrast and the Deck-size check

**Type:** dev

As a player,
I want HUD colours that stay readable in every zone and at Deck size,
So that I can read the game at ×2 on a small screen.

**Acceptance Criteria:**

**Given** `core/palettes.gd`
**When** UI asks for a colour
**Then** it gets reserved amber `#ffd27a` or predator red `#d9473f`, or the active zone's role colour (hp / label / empty / rule / surface / gutter) for Dusk, Umber and Cold violet, including the UX-DR7 overrides (UX-DR1–UX-DR6)
**And** a contrast test checks every role against its zone's gutter and play-area colour (≥ 4.5:1 text, ≥ 3:1 shapes) and the edge-cue glow floor (UX-DR7–UX-DR9, UX-DR130)
**And** the World gutters switch from the placeholder colour to the active zone's gutter colour

**Given** a ×2 (960×540) screenshot from `tests/screenshot.gd` showing a test scene with the HUD mock values (chain digits 0–20, `+1240`, four pips) and a `body-line` sample
**When** sonlm views it at Deck size on the laptop
**Then** sonlm signs off that the text and HUD are legible, or the font choice is revisited before Story 1.25 (UX-DR131, NFR12)

### Story 1.19: Health: 4 HP and the damage table

**Type:** dev

As a player,
I want 4 HP, with readable knockback and a moment of invulnerability, instead of one-touch death,
So that a mistake costs me health, not the whole run.

**Acceptance Criteria:**

**Given** `rules/health.gd` (per-life on `Player`; signal `damaged(amount, cause)`, where `cause` is a cause id such as `&"crawler_walker"` or `&"lurker"` that the death card reads)
**When** damage arrives
**Then** it applies the table: crawler contact 1, boss attack 1, hunting lurker 2, spikes/hazard 1; at 0 HP the player dies (FR10, AR12)
**And** `tests/test_health.gd` covers the table, invulnerability and bank-heal

**Given** crawler contact (still polled with `get_overlapping_bodies`)
**When** it hits the player
**Then** the player takes 1, is knocked back at (150, −150) px/s and is invulnerable for 0.6 s, blinking at 2.5 Hz through the Fx gate (steady transparency under reduce flashing); the hit flash shows the player white for 67 ms, and under reduce flashing dims the player to 60% for 100 ms instead (defaults, reviewed in Story 1.30)

**Given** a lurker
**When** it touches the player
**Then** it deals 2 only while it hunts with the player as its target (`monitorable` rule), with the same knockback and 0.6 s invulnerability as crawler contact; M1's one-touch death is removed

**Given** any hit
**When** it lands
**Then** the chain breaks and held embers move to carried (FR11; `test_chain_state` extended)
**And** a spike tile (new legend char, fixture room in `tests/rooms/`) deals 1 and puts the player at the last safe ledge in the same room, tracked per-life by `World`

**Given** a chain of ≥ 10 banked
**When** it banks
**Then** the player heals +1 HP up to the maximum; the threshold is `Tuning` `bank_heal_min` (10); chains that end by landing, Snuff, cling timeout or a room exit count, while a chain broken by a hit or spent by a Flare Toss never triggers bank-heal (FR12)
**And** at 0 HP `World` respawns the player with full HP without a scene reload (FR13), and DevTools gains `--hp=<n>`

### Story 1.20: Light sensing for predators

**Type:** dev

As a player,
I want lurkers to sense light by one fair rule that only works on screen,
So that I always know what wakes them and I'm never hunted from the dark.

**Acceptance Criteria:**

**Given** `actors/light_source.gd` (`LightSource`, group `light_source`, `kind` = `&"player"` / `&"flare"` / `&"cache"`, `radius()`)
**When** the player exists
**Then** the player carries a `LightSource` whose radius is the Chain-Light radius (FR5, AR28)

**Given** `rules/sensing.gd` (static, pure: `can_notice`, `can_sense`, `can_stir`, `pick_target`)
**When** a lurker evaluates a light
**Then** notice needs radius ≥ 80 px (4 links), distance ≤ radius × 1.6, and the lurker inside the play rect shrunk by the screen margin; `tests/test_sensing.gd` covers the boundaries (79.9 vs 80 px, distance ± 1 px around the limit, the play-rect edge) (FR17, AR29)

**Given** the lurker FSM (`IDLE → TELEGRAPH → HUNT → RETURN`, `enum State` + `match` + `_enter`, public `state`)
**When** it notices its target
**Then** it telegraphs for 0.9 s (≥ `Spec.TELEGRAPH_MIN`, 0.75 s), then hunts at 95 px/s through walls; the moment it can't sense its target it stops, is harmless, waits 0.6 s and returns home (FR19, FR20, AR30, AR31)
**And** `monitorable` is true only in `HUNT` with the player as target

**Given** several sensed lights
**When** the lurker picks a target
**Then** it takes the largest radius, a tie going to the non-player light; switching from a non-player light to the player re-enters `TELEGRAPH` for the full telegraph (FR21), proven with a stand-in `LightSource` in a test

**Given** the lurker would notice but sits outside the play rect within 96 px of its edge
**When** it updates
**Then** it stays `IDLE` and exposes `stir` (0 closed, 1 half, 2 open, rising while the condition holds); it never telegraphs or hunts while stirring (FR18)
**And** the `smoke_rooms` guarantees stay green

### Story 1.21: Save store

**Type:** dev

As a player,
I want my progress written to disk safely,
So that a crash or a bad write never costs me my save.

**Acceptance Criteria:**

**Given** `core/save_store.gd`
**When** a slot is saved
**Then** it writes `user://slot_N.json` as `{"version", "meta", "slot", "dive"|null}` via `.tmp` → re-read and parse → rename, keeping the previous file as `.bak` (the first save, with no previous file, skips the copy so no engine error prints); `meta` holds depth, best chain, play time, difficulty and last-saved time (AR37)
**And** play time accumulates in `SlotState` while the game runs unpaused, and depth is the deepest screen row reached (from the room's map position once rooms carry `map=` in E4; the shaft's own screen rows before that)

**Given** a main file that fails to parse
**When** the slot loads
**Then** it falls back to `.bak`; if both fail, the slot is reported as damaged; a file with a newer `version` than the build knows is rejected and left untouched
**And** a damaged or newer-version slot is never written over by an autosave: saves to it emit `save_failed` until the player overwrites or deletes it in the slot picker (Story 1.38); files are parsed with `JSON.new().parse()`, so a corrupt file prints no engine `ERROR:` line (R15)

**Given** `rules/migrations.gd`
**When** an older `version` loads
**Then** `migrate_vN_to_vN1()` functions run in order (scaffold only; the first real migration lands in E4)

**Given** a progress moment (R14; in E1, a difficulty change)
**When** `Game.save_progress()` runs
**Then** the slot's world progress is rewritten while the resume point, the dive snapshot and the Ember Cache stay as the last resume save left them (so a quit away from an anchor never loses a cache that a progress save would have cleared); it emits `save_succeeded` / `save_failed` and shows the icon or the failure state exactly like `save_now()`; a test saves progress mid-dive, reloads, and finds the player at the last rest with the new progress kept and carried embers not made safe (AR38)

**Given** `Game.save_now()`
**When** the write fails (simulated unwritable directory)
**Then** `Game` emits `save_failed(n, err)` and `push_warning` fires once; on success it emits `save_succeeded`; the game never crashes or pauses (AR38)
**And** until the slot picker (Story 1.38) the game uses slot 1 and loads it at boot if present; the save directory is injectable, and tests use a temporary directory they remove
**And** `tests/test_saves.gd` covers the round-trip, the `.bak` fallback, the newer-version rejection, the damaged-slot write refusal, progress saves and the failure signal, with no `ERROR:` line in the output

### Story 1.22: Three ember stages, the Ember Cache and difficulty tiers

**Type:** dev

As a player,
I want embers to move from held to carried to deposited, and a dropped cache I can win back,
So that "one more hit" and "can I reach the station?" are both real choices.

**Acceptance Criteria:**

**Given** rule methods on `DiveState` / `SlotState`
**When** the chain ends safely (landing, Snuff, cling timeout, a hit, a room exit)
**Then** held embers move to carried; a rest deposits carried into `slot.deposited` (FR22, AR13)

**Given** death on Normal with carried > 0
**When** death cost applies
**Then** held embers are lost and an Ember Cache (room, position, amount) is stored in `SlotState`, replacing any older cache; touching it returns the amount to carried; dying again first destroys it; no cache is made when carried is 0 (FR23)

**Given** Easy or Hard
**When** death cost applies
**Then** Easy moves held to carried and keeps carried (no cache); Hard loses both; difficulty lives in `SlotState`, is not a tuning modifier and changes nothing but death cost, never telegraphs, damage or chain rules (FR25, UX-DR67)
**And** DevTools gains `--difficulty=easy|normal|hard`

**Given** `objects/ember_cache.gd` (a `LightSource` of kind `cache`, amber glow, radius from `Tuning`, starting at 80 px and tuned at the CP2 gate)
**When** `enter_room` builds a room whose id matches `slot.cache.room`
**Then** the cache spawns there; it wakes lurkers only if its radius is ≥ 80 px (tested at 79 and 80); a lurker hunting the cache is harmless; the cache survives rests and saves (FR24, AR24)
**And** the cache always sits at the last safe ground position the player stood on in that room (the per-life tracker from Story 1.19), so a mid-air or hazard death never leaves it floating or out of reach; tests cover a ground, a mid-air and a hazard death
**And** a smoke test dies on Normal in `m1_shaft` with carried > 0, respawns through `enter_room`, finds the cache in the room and touches it to get the embers back
**And** rule tests cover every stage transition and tier

### Story 1.23: Flare Toss

**Type:** dev

As a player,
I want to spend half my chain on a flare that lures predators away,
So that I can keep diving bright when the eyes open.

**Decide before dev (sonlm):** can a Flare Toss be thrown while clinging (and does the cling continue), and while snuffed in Snuff-toggle mode?

**Acceptance Criteria:**

**Given** a chain of n ≥ 2
**When** the player taps Light (`light_tap`: released inside the tap window, 0.12 / 0.2 / 0.3 s from `Settings`)
**Then** a flare is thrown, the chain drops by ceil(n/2) (8 → 4, 5 → 2) and keeps going, the light shrinks to the new chain, and held embers move to carried in proportion to the links spent (floor(held × spent / n); the rest stays held); the meter drops to match (FR14, UX-DR140)
**And** with a chain below 2 a tap does nothing and the chain is untouched

**Given** a thrown flare (`actors/flare.gd`, spawned with `room.spawn`; AR33)
**When** it flies
**Then** it arcs at 180 px/s forward in the facing direction and −160 px/s up under normal gravity, sticks to the first surface it hits, burns `Tuning` `flare_burn` (4.0 s) with the pre-toss light radius, fades smoothly over its last 1.0 s with no flashing and deals no damage (FR15)

**Given** a lurker that senses the flare (`LightSource` kind `flare`)
**When** it chooses a target
**Then** it telegraphs and hunts the flare as if it were the player; switching from the player to the flare needs no telegraph; switching back re-telegraphs (FR16, FR21) — covered by a smoke test

**Given** the light budget
**When** flares are on screen
**Then** each flare keeps its `PointLight2D`, the overlay counts it, and the flare cap from the CP1 verdict (if one was recommended) is a `Tuning` value
**And** a tap never breaks the chain and Snuff behaviour is unchanged

### Story 1.24: Interact, lantern anchors and Lift Station rest

**Type:** dev

As a player,
I want to light lanterns that bring me back nearby and rest at a station that heals and banks my embers,
So that deaths cost distance, not the whole descent.

**Acceptance Criteria:**

**Given** the `interact` intent
**When** the player presses ↓ standing still on the ground within range of an interactable
**Then** that object's interaction runs (FR26)

**Given** `objects/lantern_anchor.gd` (persistent id in the room header, e.g. `obj=anchor_m1_1@x,y`, following `<kind>_<room short>_<n>`; AR26, AR33)
**When** the player touches it
**Then** it lights (cold → amber; a lit anchor holds the player's spark, so it may burn amber per `DESIGN.md` Reserved), the lit state is a `SlotState` flag, and it becomes the respawn point if it is deeper than the current one (FR27)

**Given** `objects/lift_station.gd` (placeholder, id `station_m1_top`)
**When** the player touches it
**Then** it lights and becomes the respawn point if it is deeper than the current one
**And** ↓ rests: full heal → deposit carried → `dive.reset()` → `enter_room(current room, station)`, so killed enemies are back at once → `Game.save_now()`; a rest starts a new dive with this station as the respawn point (FR28, AR25)

**Given** both an anchor and a station are lit
**When** the player dies
**Then** they respawn at whichever is deeper, with full HP (FR13); the respawn point is per dive (`DiveState`), so after a rest at the top station, touching an already-lit deeper anchor makes it the respawn point again; tested on the loop
**And** `m1_shaft.txt` now has the station at the top and two anchors (FR39); their legend chars are in `room_legend.gd` and `docs/rooms.md`
**And** through the bottom-exit loop (R16) the player can return to the top station and rest again; a smoke test dives, lights an anchor, kills an enemy, loops to the top, rests, and finds the enemy back and the carried embers deposited

### Story 1.25: Gutter HUD v2: frame, HP and embers

**Type:** dev

As a player,
I want my HP and embers in the left gutter, readable at a glance,
So that the play area stays clear and I always know what I'm risking.

**Acceptance Criteria:**

**Given** `ui/gutters.gd`
**When** the player spawns or respawns
**Then** it binds to the player's `chain`, `health` and `Game.dive` signals and rebinds on `World.player_spawned` (smoke test "HUD after a death") (FR36, AR39)

**Given** the gutters
**When** they draw
**Then** the two 60 px gutters beside the 360 px play area have the 1 px inner and outer rules in the zone rule colour, the heart icon (left, centred x 30, y 10) and chain-link icon (right, centred x 450, y 10), and no text except numbers (UX-DR14, UX-DR22, UX-DR30, UX-DR31)
**And** the M1 bottom controls bar and debug label HUD are gone; hierarchy is chain number, then HP, then embers; deposited embers never show on the dive HUD; only in-world UI, the death card and the station menu may cover the play area; all positions and timings use the DESIGN.md spacing and motion tokens; shapes are square, whole-pixel, empty = 1 px outline (UX-DR19, UX-DR21, UX-DR24, UX-DR26, UX-DR27, UX-DR28)

**Given** HP and embers
**When** they change
**Then** 4 pips at x 26, y 24 + 10·n fill or outline (UX-DR32); the held row (amber, flickering while > 0) and carried row (solid, HP colour) sit at y 96 and y 108 and fit `+999` and `+1240` (UX-DR33)
**And** a lost pip cracks, shakes (no shake under reduced motion) and outlines, then the pips blink at 2.5 Hz for 0.6 s, holding steady transparency instead under reduce flashing (UX-DR138, UX-DR126)
**And** the held row's flicker runs at ≤ 3 changes per second through the Fx gate and is steady under reduce flashing
**And** on `save_succeeded` the steady lantern autosave icon (left gutter, y 252) shows for ≥ 1000 ms (UX-DR41)

### Story 1.26: Gutter HUD v2: chain number, meter and cling cues

**Type:** dev, content

As a player,
I want my chain to grow visibly in the right gutter and my cling time to show beside me,
So that I feel every link and know when a cling will run out.

**Acceptance Criteria:**

**Given** the chain
**When** it grows
**Then** the amber number (0 in the Empty colour) steps 24 → 26 → 28 → 32 px at 3 / 6 / 10 with a 1 px pop for 67 ms, its digits hand-pixelled at each of the 4 heights as sprite grids (`tools/sprites/`, built by `build_sprites.py`), drafted by Claude and approved by sonlm before commit; the 20-segment meter at x 444 fills bottom-up; the flare notch sits beside segment 2 (UX-DR13, UX-DR34, UX-DR35, UX-DR37, UX-DR135, UX-DR136)

**Given** a bank
**When** the chain ends safely
**Then** the popup `x{links} +{embers}` rises and fades over 600 ms (no rise under reduced motion), a bank burst of 12 amber sparks plays at the player over 300 ms (under reduce flashing: 6 sparks at half alpha, no bloom; defaults reviewed in Story 1.30), embers fly into the gutter counter, and the meter empties; M1's English "+N banked" / "-N lost" popups are removed; on a break, segments fall away and dim with no flash (UX-DR45, UX-DR137, UX-DR139)

**Given** a cling
**When** it starts
**Then** the 2 px grace bar beside the meter and the 2×8 cling cue beside the player appear full, drain together over the grace and refill on a pogo (UX-DR36, UX-DR42)

### Story 1.27: Alert frame, off-screen stirring and flare cost

**Type:** dev

As a player,
I want the gutters to warn me when a lurker stirs or telegraphs,
So that I hear and see it before it can reach me.

**Acceptance Criteria:**

**Given** any lurker in `TELEGRAPH`
**When** the alert shows
**Then** both gutters get a 1 px predator-red frame pulsing ≤ 2 Hz for at least 400 ms, plus the open-eye icon (right gutter, centred x 450, y 68); overlapping telegraphs keep one frame without restarting the pulse; under reduce flashing the frame is solid; HUD values are never recoloured; colour is never the only signal (FR19, UX-DR29, UX-DR39, UX-DR40, UX-DR129)
**And** no `Color(1, 0.35, 0.3)` or `#ff594d` remains in the code (M1: the `shaft.gd` alert and the `player.gd` loss popup); predator red is `#d9473f` from `core/palettes.gd` (UX-DR2)

**Given** a stirring lurker (`stir` from Story 1.20)
**When** it is off screen
**Then** a 7×5 eye shows 2 px inside the play-area edge on its side (x 62 or x 411), level with the lurker and clamped 8 px from the top and bottom, stepping closed → half → open with `stir`, with a red glow pulsing at 2 Hz that never drops below the glow floor; the glow never shows alone (FR18, UX-DR43, UX-DR9)
**And** a test proves stirring never leads to a hunt without an on-screen telegraph (AR50)

**Given** a lurker stirring or hunting and a chain ≥ 2
**When** the meter draws
**Then** the segments a toss would remove carry a 1 px diagonal hatch every 3 px in the gutter colour, hiding at once when either condition ends (UX-DR38)

### Story 1.28: Death-card voice anchors

**Type:** designer

As the designer,
I want to approve three anchor lines for the death card before any death line is written,
So that the first story text testers read has the voice I want.

**Acceptance Criteria:**

**Given** `narrative-design.md` (death-card voice: matter-of-fact, kind, never mocking; cause may carry island idiom; avoidance always plain; names shapes, never colours)
**When** Claude drafts at least 6 candidate death lines for the E1 causes (crawler walker, crawler hoverer, lurker, spikes/hazard)
**Then** sonlm picks and edits 3 as the death-card anchors (NR1, NR21, NR22)

**Given** the approved anchors
**When** they are recorded
**Then** they sit in `narrative-design.md` (Dialogue Framework, voice anchors) with the date, and no `DEATH_*` string exists before this approval
**And** the E1 cause list is fixed; later epics add their causes (spiderling, Weaver bite) with their content, within the M2 budget of ≈ 8 causes and ≈ 120 words (NR4)

### Story 1.29: Death card and the Field Journal death line

**Type:** dev, content

As a player,
I want each death to tell me what killed me and how to avoid it,
So that every death teaches.

**Acceptance Criteria:**

**Given** the player reaches 0 HP
**When** the death card opens through `ScreenRouter` (`PROCESS_MODE_ALWAYS`)
**Then** after a short fade the play area dims to the zone surface at 70% with the gutters still visible, and the death line shows centred, 328 px wide, in `body-line` with the text outline: the cause line in the HP colour, then the avoidance tip in the label colour (FR37, UX-DR81)

**Given** the E1 causes
**When** their lines are written
**Then** each cause has two keys, `DEATH_<CAUSE>_LINE` (the cause; may carry island idiom) and `DEATH_<CAUSE>_TIP` (the avoidance; always plain), each fitting one 328 px row, written against the approved anchors and approved by sonlm before commit (NR2, NR3, NR11)

**Given** the difficulty tier
**When** the card shows
**Then** Normal adds "Embers left below. Once.", Hard adds "Nothing left below.", Easy adds nothing; a Normal death that destroyed an unrecovered cache adds the cache-gone line; the gutter ember rows count down to their new values over 500 ms (UX-DR82, UX-DR83, UX-DR84)

**Given** buttons held at the moment of death
**When** the card is up
**Then** they are ignored; a fresh press of any action skips the card only after 0.6 s (`menu_confirm` once Story 1.31 lands); it auto-advances after about 3 s; then the player respawns (UX-DR85, UX-DR132)
**And** each death appends an entry to `slot.death_log` holding the cause id from `damaged(amount, cause)` and the room id (not string keys or rendered text; this format freezes with `slot_v1`), so the E7 Journal can group deaths by cause (AR14, UX-DR86)

### Story 1.30: CP2 gate: the kit playtest

**Type:** playtest

As the designer,
I want to play the full kit build and record whether deaths feel fair,
So that the Weaver prototype is built on a kit I trust.

**Tune after play (sonlm):** the Ember Cache glow radius (start: 80 px, the minimum that can wake a lurker) and the bank-heal threshold (start: chain 10), GDD assumptions A8 and A1.

**Acceptance Criteria:**

**Given** the GDD's E1 watch items
**When** sonlm plays the kit build mid-chain under lurker pressure
**Then** the record also answers: does tap vs hold on Light feel overwhelming mid-chain? Does an instant mid-air Snuff become a free bank every time an eye opens? A "yes" on Snuff triggers the GDD Risks fix (e.g. Snuff banks only half the held embers) as a fix story before E2, with its HUD cue (UX O20)

**Given** the HUD defaults D1 (chain number steps), D3 (cling cue and grace bar), D4 (icon art), D8 (alert hold on overlap) and D11 (autosave icon), plus the hit flash (Story 1.19) and bank burst (Story 1.26) defaults and their reduce-flashing variants
**When** sonlm reviews them in the kit build with `DESIGN.md` open
**Then** each is marked keep or change; small changes are fixed before CP3, and the spine tags are updated with the decision and date

**Given** GDD assumptions A1 (bank-heal at chain ≥ 10) and A8 (Ember Cache glow radius)
**When** sonlm plays the kit build
**Then** both are confirmed or retuned in `rules/tuning.gd` with "was X" comments, and the GDD assumption index marks them closed (FR12, FR24)

**Given** CP2 is complete (Stories 1.16–1.29)
**When** sonlm plays the kit build
**Then** the J2 (greedy chain near death) and J3 (death and cache run) flows play end to end (UX-DR106, UX-DR107), and the answer to "do HP and Flare Toss keep deaths fair?" is recorded with notes, and a devlog or private build is posted; a "no" becomes fix stories before E2 (E2 depends on the kit)

### Story 1.31: UI kit and menu bindings

**Type:** dev

As a player,
I want menus that move, repeat and confirm the same way everywhere, on keyboard or gamepad,
So that every screen feels the same and never surprises me.

**Acceptance Criteria:**

**Given** `ui/kit/` (MenuList, TabBar, EmberCursor, ConfirmStep, Toggle, Slider, choice list, GlyphPrompt; AR40)
**When** a menu draws
**Then** using the DESIGN.md menu spacing tokens (UX-DR20), items use `menu-item` rows at 24 px pitch with text at x 64, selected in the HP colour, idle in the label colour; the 5×5 amber ember cursor sits 9 px left of the selection, flickers by 1 px and eases over 120 ms (jumps under reduced motion) (UX-DR46, UX-DR47, UX-DR145)

**Given** the menu actions (`menu_confirm`, `menu_back`, `menu_tab_next`, …)
**When** the player navigates
**Then** confirm is Z / Enter / Space / A, back is X / Backspace / Esc / B, tabs are Q / E or LB / RB, values change with ← / →; a held direction moves once, then repeats after 400 ms every 80 ms; lists and tabs wrap, sliders and choices stop at their ends; the stick fires at 0.5 tilt and re-arms below 0.3 (UX-DR116, UX-DR117)

**Given** TabBar
**When** a tab's epic hasn't landed
**Then** the tab is hidden, not disabled; with one tab, Q/E and LB/RB do nothing (UX-DR48, R8)

**Given** ConfirmStep
**When** it opens
**Then** it replaces the menu's items in place with one `body-line` question and No / Yes, No selected by default (UX-DR50)
**And** GlyphPrompt draws a 12 px keycap with backing (long keys up to 32 px, arrows as 5×5 icons) for keyboard bindings (UX-DR44)
**And** menu screens fill with the zone surface; no menu reads gameplay intents, and raw input is read only inside `ui/kit/` (plus device tracking in `core/devices.gd`) (UX-DR25, AR35)

### Story 1.32: Placeholder station menu

**Type:** dev

As a player,
I want a short rest sequence and a station menu after I rest,
So that I see my healed HP and banked embers before I go on.

**Acceptance Criteria:**

**Given** a rest (Story 1.24)
**When** it runs from one ↓ press
**Then** it plays without a menu until the end: full heal → embers fly into the bank while the deposited total counts up at the top of the play area → autosave icon → station menu (UX-DR88)

**Given** the station menu
**When** it opens
**Then** it replaces only the play area (gutters stay, showing the healed HP) with the deposited total at x 80, y 40 (value right-aligned at x 400) and items Descend / Leave from y 64 at text x 80; the cursor starts on Descend; Back = Leave (UX-DR89)
**And** Fast travel is hidden until E4 (R6), and in E1 both items return to play

### Story 1.33: Web gate and title screen

**Type:** dev

As a player,
I want a click-to-play gate on the web and a title screen with my save,
So that the game starts cleanly in the browser and I can continue where I left off.

**Acceptance Criteria:**

**Given** a web page load
**When** the game starts
**Then** the gate shows "Click to play" (`body-line`, HP colour) centred on the Dusk surface with no gutters, and waits for the first click or key, which gives focus; no audio plays before it (UX-DR57)
**And** if the window is below ×2 a second line "Small window. Try fullscreen." shows in the label colour (UX-DR58)

**Given** the title
**When** it shows
**Then** a text logo placeholder sits over a dark, slowly scrolling view of the shaft on the Dusk surface with no gutters, and the items Continue / New Game / Load / Options / Quit start at y 104 with the ember cursor (UX-DR59)
**And** items whose screens haven't landed are hidden; Quit is PC only, has no confirm and is hidden on web (UX-DR61)
**And** until the slot picker lands (Story 1.38), New Game starts a game in slot 1 directly, after a confirm step if slot 1 holds a save

**Given** no save exists
**When** the title shows
**Then** Continue is hidden and the cursor starts on New Game; with a save, the cursor starts on Continue, which loads it (UX-DR60)

### Story 1.34: Pause tab

**Type:** dev

As a player,
I want to pause any time, see my bank and controls, and quit safely,
So that I can stop a long descent without losing progress or guessing the controls.

**Acceptance Criteria:**

**Given** play
**When** the player presses Esc or P (Start on gamepad), or the window loses focus (desktop and web)
**Then** `SceneTree.paused` is set and the Pause tab opens, replacing the view; Esc, P or Back closes it (UX-DR68, UX-DR71, FR32, NFR5)
**And** while the death card, the rest sequence or the station menu is up, Pause does nothing; a focus loss there pauses the tree without opening a second screen, and the sequence resumes on focus; pausing during hitstop or slow-mo resumes the remaining Clock request on unpause; tests cover each case

**Given** the Pause tab
**When** it shows
**Then** the tab bar holds Pause only; Resume / Options / Quit start at y 64 (Options hidden until Story 1.36); the bank summary shows Deposited, Carried, Held, Depth and Best chain at x 280–420 (held in amber); the controls reference lists the current keyboard bindings with glyphs from y 172 (UX-DR51, UX-DR52, UX-DR69, UX-DR70)

**Given** Quit
**When** it is chosen
**Then** a confirm step asks "Quit to title?" (No selected); away from a lit anchor or station it adds "You will wake at the last rest."; Yes returns to the title (UX-DR72)
**And** quitting at a lit anchor autosaves the slot plus the dive snapshot (anchor id + carried embers), and a desktop window close runs the same Quit path; resume saves happen only at a station rest, the hub and a quit at a lit anchor, while progress saves have already kept world progress (FR29, AR35, AR38, R14, UX-DR112)

### Story 1.35: Cling and Snuff hold→press toggles

**Type:** dev

As a player who finds holding buttons hard,
I want to turn the Cling and Snuff holds into presses,
So that I can play the full kit without sustained holds.

**Acceptance Criteria:**

**Given** `Settings` Cling toggle on
**When** the player presses Jump at a side wall while falling
**Then** the cling starts and continues without holding; the next Jump press kicks off at (150 away, −260 up); ↓ drops off; grace and slide are unchanged (FR33)

**Given** `Settings` Snuff toggle on
**When** the player presses Light
**Then** any press throws a Flare Toss (no tap window); Snuff moves to its own `snuff_toggle` action (default Shift, pad LB), pressed once to start and again to end; Snuff still breaks the chain and banks (FR34, UX-DR120)
**And** both toggles default to Off, and `PlayerInput` tests cover both modes alongside the default hold mode

### Story 1.36: Options: Game, Accessibility and Brightness

**Type:** dev

As a player,
I want to change difficulty, accessibility settings and brightness from the title or the pause menu,
So that I can make the game fit me without restarting.

**Acceptance Criteria:**

**Given** Options opened from the title (Dusk surface) or from Pause
**When** it closes
**Then** it returns to its opener; the tab bar shows Game and Accessibility only (Video, Audio, Controls and the Credits entry hidden); the Game tab is hidden when no slot is loaded (UX-DR74, UX-DR111, R7)

**Given** the Game tab
**When** the player changes Difficulty (Easy / Normal / Hard)
**Then** it applies at once to the loaded slot's death cost and triggers a progress save, so the slot picker shows the new tier (FR25, UX-DR75, R14)

**Given** the Accessibility tab
**When** it shows
**Then** it has Reduce flashing, Screen shake, Reduced motion (default follows the OS on web, Off on PC), Light tap window (0.12 / 0.2 / 0.3 s), Cling toggle, Snuff toggle, and Brightness (4 levels, replacing M1's F1 key) (FR33, R1, UX-DR76, UX-DR127, UX-DR128)
**And** Brightness changes only the world's ambient level; a test proves light radii, `Sensing` results, the reserved colours and the HUD colours are identical at every level

**Given** any control
**When** it changes
**Then** toggles flip on confirm, choices change with ← / →, values sit right-aligned at x 412, and the change applies at once and persists in `settings.json` (UX-DR49, R15)

### Story 1.37: Gamepad, glyph swap and disconnect pause

**Type:** dev

As a player with a controller,
I want the game to work fully on a gamepad and show my pad's buttons,
So that I never need the keyboard and prompts always match what I hold.

**Acceptance Criteria:**

**Given** a connected gamepad
**When** the player plays
**Then** the defaults are left stick / d-pad move, A jump, X attack, RB dash, B light, Start pause; every action is one button with no chords (FR31, UX-DR114, UX-DR115)

**Given** `core/devices.gd` (held by `Game`)
**When** input arrives
**Then** any pad button, or a stick or trigger past 0.5, switches glyphs to gamepad; any key switches to keyboard; stick input below 0.5 and mouse movement never switch; browser pads appear only after a press (UX-DR121, AR35)

**Given** GlyphPrompts in the world and the controls reference
**When** the last-used device changes
**Then** they show that device's glyphs (pad buttons drawn with the corners removed and generic letters); in-world prompts sit centred 4 px above their object, clamped inside the play area, and appear and hide at once (UX-DR44)
**And** on a stick, interact fires at ≥ 0.6 down while sideways stays below the 0.2 movement deadzone (tightening UX D7's ≤ 0.35 so it agrees with "standing still"; reviewed in Story 1.40), and re-arms below 0.3 (UX-DR118)

**Given** the pad in use disconnects mid-play
**When** it is lost
**Then** the game pauses with "Controller disconnected" and keyboard glyphs (a disconnect while a menu or the death card is open only switches glyphs; it never opens a second screen); reconnecting or pressing any key resumes with game state (including the chain) unchanged; J6 steps 1 and 3–7 of the gamepad session work end to end; step 2 (Load slot 2) is verified in Story 1.38 (FR32, UX-DR73, UX-DR110)

### Story 1.38: Slot picker and difficulty step

**Type:** dev

As a player,
I want three save slots with clear details and a simple difficulty choice,
So that I can keep separate runs and pick how much death costs me.

**Acceptance Criteria:**

**Given** the slot picker
**When** it shows
**Then** three rows at 40 px pitch from y 64 read "Slot N" with a details line (depth · best chain · play time h:mm · difficulty) from `meta`; an empty slot reads "Slot N — Empty" with no details (FR30, UX-DR62, UX-DR63)

**Given** New Game
**When** the picker opens
**Then** the cursor starts on the most recent slot (or slot 1); an empty slot goes to the difficulty step; a filled slot asks "Overwrite slot N?" (No default); Back returns to the title (UX-DR64)

**Given** Load
**When** the picker opens
**Then** the cursor skips empty slots; C (keyboard) or Y (pad) on a filled slot asks "Delete slot N?" (No default) and Yes removes `slot_N.json` and `.bak` (UX-DR65, AR38)

**Given** the difficulty step
**When** it shows
**Then** Easy / Normal / Hard and one `body-line` text say only what death costs on each tier and that it can be changed later in Options, never "casual" or "hardcore"; Play writes the slot at once and starts in the shaft (the hub opening arrives in E5) (UX-DR66, AR38)
**And** Continue on the title loads the most recently saved slot, and Load appears on the title once a save exists
**And** a slot whose file and `.bak` both fail reads "Slot N — Damaged" and can only be overwritten or deleted; deleting the most recent slot makes Continue load the next most recent, or hides it if none is left
**And** J6 step 2 works on a gamepad: Load opens the picker, A loads slot 2, B goes back (UX-DR110)

### Story 1.39: Save-failure feedback and web persistence

**Type:** dev

As a player,
I want to know when my progress didn't save and what to do,
So that I'm never surprised by lost progress, especially in the browser.

**Acceptance Criteria:**

**Given** `Game.save_failed`
**When** a save fails
**Then** the autosave lantern becomes the crossed lantern and stays crossed until a save succeeds; "Not saved" shows for 3 s at the bottom-left of the play area (x 64) with the text outline; the Pause tab shows the pause note explaining the fix; the game never crashes or pauses (UX-DR41, UX-DR53, UX-DR113, NFR13)
**And** the save retries at the next trigger and on quit to title; a retry on quit to title away from a lit anchor is a progress save (R14), so it never moves the resume point

**Given** a web build
**When** it boots and before each save
**Then** it checks `OS.is_userfs_persistent()`; if false the failure state shows at once and `push_warning` fires once per session

**Given** the Playwright web smoke check
**When** it runs against the debug web build
**Then** it passes the gate, starts a game, writes a save (`SMOKE save ok`), reloads the page and confirms the save persists (AR53)

### Story 1.40: Review the UX defaults in the build

**Type:** designer

As the designer,
I want to review the 15 UX defaults in the running game,
So that the UX spine records decisions, not assumptions.

**Acceptance Criteria:**

**Given** the CP3 build and `DESIGN.md` / `EXPERIENCE.md`
**When** sonlm plays it at ×2 and ×3 on keyboard and gamepad
**Then** each remaining default (D2, D5–D7, D9, D10, D12–D15; the HUD defaults were reviewed at the CP2 gate) and the key-mock positions and colours is marked keep or change (UX-DR19–UX-DR24, UX-DR44, UX-DR46–UX-DR53)

**Given** a "change"
**When** it is small
**Then** it is fixed in this story; a larger change becomes a follow-up story in E1 before it closes
**And** the spine's `[ASSUMPTION — default, review]` tags are replaced by the decision and its date

### Story 1.41: Freeze save format v1 and close E1

**Type:** dev

As the developer,
I want the E1 save format frozen as a fixture every later build must load,
So that testers' saves survive every update from here on.

**Acceptance Criteria:**

**Given** a real E1 slot with an Ember Cache, lit anchors, records and `death_log` entries
**When** it is captured
**Then** it is committed as `tests/fixtures/slot_v1.json`, and a test in every later build loads it and asserts its values (the cache, lit anchors, records and `death_log` entries), not just that it loads (AR37)
**And** a schema guard test fails if the keys of `SlotState.to_dict()` or `DiveState.to_dict()` change without a version bump, a migration and a new fixture; it also checks the shape of a `death_log` entry (cause id + room id) and of the Ember Cache

**Given** the end of E1
**When** the close-out runs
**Then** `tools/export.sh` is green for all three targets including the web smoke check, the CP2 (Story 1.30) and CP3 (Story 1.40) records are in `implementation-artifacts/playtests/`, and a devlog or private build is posted

## Epic 2: Weaver Prototype: The Restraint Fight Is Fun

The player fights a rough Weaver in a test arena and wins by going dark, herding with flares and striking with a light burst. The fight is proven fun and readable before any content is built around it. Placeholder art; The Fall is stubbed; no save-format change. 1–2 outside players test it blind.

### Story 2.1: Weaver test arena and debug entry

**Type:** dev

As the designer,
I want a debug entry straight into a full-size test arena,
So that I can iterate on the Weaver fight without descending Layer 1.

**Acceptance Criteria:**

**Given** `rooms/dev/weaver_test.txt` (30 × 34 tiles, two screens tall, with a `weaver_test.tscn` overlay for set-piece objects) excluded from release presets
**When** the game starts with `-- --room=weaver_test` or `?room=weaver_test` in a web debug build
**Then** the player enters the arena at its top entry with full HP (FR40, UX-DR100, AR54)

**Given** the arena is wider than the 360 px play area
**When** the player moves sideways
**Then** the camera scrolls horizontally inside the room bounds while keeping the downward lead, and the gutters stay visible (UX-DR30, UX-DR149)
**And** the arena has no exit the player can use mid-fight

**Given** the arena loads
**When** `smoke_rooms` runs
**Then** it validates, and its ids are unique across all room files

### Story 2.2: Strands and anchors

**Type:** dev

As a player,
I want web strands I can pogo off and anchors I can cut,
So that the arena itself is my chain fuel and my weapon.

**Acceptance Criteria:**

**Given** 4 strands spanning the arena wall to wall at different heights (`actors/weaver/strand.gd`, each with a `strand_anchor.gd` at both ends; AR32)
**When** the player pogoes a strand
**Then** they bounce, gain 1 link and their air dash refreshes; the strand takes no damage (FR40)

**Given** a strand anchor
**When** the player slashes it twice
**Then** that strand becomes weakened: a frayed placeholder sprite and a visible sag; slashing a weakened strand's anchors again does nothing until Story 2.8 adds the drop

**Given** the strand layout
**When** the arena builds
**Then** strand positions come from a fixed layout in the overlay (no randomness, NFR11), and strands and anchors are owned by the Weaver set piece, not by `World`

### Story 2.3: Weaver movement and light-shy states

**Type:** dev

As a player,
I want the Weaver to flee my light and creep closer in the dark,
So that I learn the fight is about when to shine.

**Tune after play (sonlm):** the Weaver's behaviour at 62–78 px of light. Default: slow descent; hold position and slow retreat are the other options.

**Acceptance Criteria:**

**Given** `actors/weaver/weaver.gd` (FSM with `BRIGHT_RETREAT` and `DARK_DESCEND` here; `enum State` + `match` + `_enter`, public `state`) reading lights through the same `light_source` query and `Sensing` as the lurker
**When** the player's light radius is ≥ 80 px
**Then** the Weaver retreats along the strands to the ceiling anchor at 120 px/s, out of reach (FR41, AR32)

**Given** the player's light radius is ≤ 40 px (base, Snuff or cling)
**When** the Weaver updates
**Then** it descends along the strands toward the player at 70 px/s

**Given** a light radius between 40 and 80 px (1–3 links, 62–78 px)
**When** the Weaver updates
**Then** it uses the default (slow descent), selectable in `rules/tuning.gd` among hold position, slow descent and slow retreat, with tests for each option; after sonlm plays it, the choice and reason are recorded in the GDD Open Questions row "Weaver at 62–78 px" (closing it)
**And** a placeholder segmented body (body, 8 legs) shows its movement; tests cover each state transition by light radius

### Story 2.4: Bite telegraph

**Type:** dev

As a player,
I want the Weaver's bite to be clearly telegraphed,
So that every bite I take is one I could have avoided.

**Decide before dev (sonlm):** UX O10: does the bite telegraph also show the gutter alert frame and eye?

**Acceptance Criteria:**

**Given** the Weaver in `DARK_DESCEND` within bite reach of the player
**When** it starts a bite
**Then** it enters `BITE_TELEGRAPH` for 0.9 s (legs rear up, eyes glow), and only then bites; a bite that lands deals 1 (boss attack) with the usual knockback and invulnerability (FR41, FR10)

**Given** the player brightens to ≥ 80 px or leaves reach during the telegraph
**When** the telegraph ends
**Then** the bite does not land

**Given** a guarantee test
**When** it scans every bite in a scripted fight
**Then** every bite was preceded by a telegraph ≥ `Spec.TELEGRAPH_MIN` (NFR10)
**And** UX O10 is decided and recorded in `EXPERIENCE.md`: whether the bite telegraph also shows the gutter alert frame and eye

### Story 2.5: Spiderlings

**Type:** dev

As a player,
I want the Weaver to drop spiderlings while I'm bright,
So that staying bright costs me, but also gives me chain fuel.

**Acceptance Criteria:**

**Given** the Weaver in `BRIGHT_RETREAT`
**When** 2.0 s pass
**Then** it drops one spiderling (`actors/spiderling.gd`, spawned with `room.spawn`), up to 3 alive at once (FR41, FR46, AR33)

**Given** a spiderling
**When** it drops
**Then** it falls slowly, lands, then crawls like a walker; it has 1 HP, deals 1 on contact (polled) and can be pogoed for a link
**And** spiderlings are room children and disappear with the room

### Story 2.6: Light-burst stun and diegetic boss health

**Type:** dev

As a player,
I want a sudden burst of light near the Weaver to stun it so I can strike,
So that the payoff of going dark is a well-timed flash.

**Tune after play (sonlm):** whether the stun triggers on the pogo hit that brings the chain to 3 (default) or whenever the chain is ≥ 3 within 96 px.

**Acceptance Criteria:**

**Given** the player reaches chain 3 within 96 px of the Weaver
**When** the burst happens
**Then** the Weaver enters `STUNNED` for 2.5 s; each player hit during the stun deals 1, at most 3 per stun (FR42)

**Given** the Weaver's 12 HP
**When** it takes damage
**Then** its health reads in the world only (body segments fray and fall off, threads sag), with no health bar (FR44, UX-DR99)
**And** the trigger mode is a `Tuning` option (default: the hit that brings the chain to 3); tests cover both modes, the stun threshold (chain 3 at 96 px vs 97 px), the 3-hit cap and the HP bookkeeping; sonlm's choice after playing is recorded in the GDD

### Story 2.7: Flare herding

**Type:** dev

As a player,
I want a flare to drive the light-shy Weaver away,
So that I can herd it where I want it.

**Tune after play (sonlm):** the exact flee-target rule. Default: the farthest strand point from the flare, ties broken by position.

**Acceptance Criteria:**

**Given** a burning flare the Weaver senses
**When** it reacts
**Then** it enters `FLEE` and moves along the strands at 110 px/s to the farthest reachable point inside the flare's radius × 1.5 (FR45)
**And** the Weaver is repelled by flares, the one exception to "predators treat a flare as the player" (FR16)

**Given** several possible flee points
**When** the target is chosen
**Then** it follows the default rule (the farthest strand point from the flare, ties broken by position), selectable in `rules/tuning.gd`; after sonlm plays it, the rule is confirmed or changed and recorded in the GDD Open Questions row "exact flee target" (closing it)
**And** tests cover the flee target for flares placed left, right and above the Weaver

### Story 2.8: Strand drop

**Type:** dev

As a player,
I want to drop a weakened strand while the Weaver stands on it,
So that herding it onto the right strand pays off.

**Acceptance Criteria:**

**Given** the Weaver on a weakened strand
**When** the player slashes that strand's second anchor
**Then** the strand drops, the Weaver takes 2 damage and is stunned for 2.5 s; hits during this stun count (FR43)

**Given** the Weaver is not on the strand
**When** the second anchor is slashed
**Then** the strand drops without damage (it stays dropped until a Re-Weave)
**And** tests cover both cases

### Story 2.9: Re-Weave

**Type:** dev

As a player,
I want the Weaver to rebuild its web at 9 HP,
So that the fight changes shape and I have to read it again.

**Acceptance Criteria:**

**Given** the Weaver drops to 9 HP
**When** the Re-Weave starts
**Then** it enters `RE_WEAVE` with a 3.0 s telegraph in which silk threads glow along the new paths, then rebuilds every strand in a new pattern and restores weakened and dropped strands (FR44)

**Given** the Re-Weave
**When** it runs
**Then** the player is not harmed, spiderlings keep dropping, and the new pattern comes from a fixed list (no randomness, NFR11)
**And** the glow honours reduce flashing (no flashing; a steady glow) through the Fx gate; the prototype follows the J5 flow so far: one-way arena, gutters stay, no boss bar, fray-and-fall health, 3 s Re-Weave glow (UX-DR109)

### Story 2.10: Phase stub, fight reset and the Weaver's death lines

**Type:** dev, content

As a player,
I want the prototype fight to end cleanly at 6 HP and reset fairly when I die,
So that every attempt starts the same way and teaches me something.

**Acceptance Criteria:**

**Given** the Weaver reaches 6 HP
**When** The Fall would start
**Then** the stub ends phase 1: the Weaver withdraws, a placeholder "phase 1 complete" note shows, and the arena can be restarted (The Fall is E6)

**Given** the player dies in the arena
**When** they respawn
**Then** they return to the arena entry (standing in for the Hollow Station) with full HP and the fight fully reset: Weaver HP 12, strands rebuilt to the first pattern, spiderlings cleared (FR49)

**Given** the new death causes
**When** their lines are written
**Then** the `DEATH_WEAVER_BITE_LINE` / `_TIP` and `DEATH_SPIDERLING_LINE` / `_TIP` keys follow the approved death-card anchors and are approved by sonlm before commit (NR2, NR11, NR21)

**Given** the player enters the arena
**When** the fight begins
**Then** a placeholder staging shows the Weaver glimpsed above before it engages, without locking input longer than the moment needs (NR12, NR18)

### Story 2.11: Winnability guarantee

**Type:** dev

As the designer,
I want a test that proves phase 1 can be won with the starting kit and no Flare Toss,
So that a later tuning change can never make the fight unwinnable.

**Acceptance Criteria:**

**Given** a scripted test (`tests/smoke_weaver.gd`) in the test arena
**When** it plays a win path using only darkness to lure, the light-burst stun and a strand drop, with no Flare Toss
**Then** the Weaver reaches 6 HP and the stub ends phase 1 (FR42, FR43, FR44, NFR10, AR49)

**Given** the same test with the bite guarantee
**When** it runs
**Then** every bite in the run was telegraphed ≥ `Spec.TELEGRAPH_MIN`, and the test picks targets by position, never by group index

### Story 2.12: E2 playtest with blind outside players

**Type:** playtest

As the designer,
I want 1–2 outside players to fight the prototype without being told what it's about,
So that "the fight teaches restraint" is tested by someone who didn't design it.

**Acceptance Criteria:**

**Given** a private web build with the arena entry (`?room=weaver_test`)
**When** 1–2 outside players play it
**Then** they are told the art is placeholder and are never told the fight is "about restraint" (FR41–FR45)

**Given** their sessions and sonlm's own
**When** they are reviewed
**Then** the answers to "is go dark → herd → strike fun and readable?" and "do they describe it as about restraint unprompted?" are recorded in `implementation-artifacts/`, together with the decisions from Stories 2.3, 2.4 and 2.7
**And** a devlog or private build is posted; a "no" becomes the first stories of E6 (the epic that builds on it)

## Epic 3: Audio: Hear the Chain and the Hunters

The player hears the chain climb, hears lurkers stir and growl before seeing them, and feels the music swell with the chain and resolve on a bank. Sound effects come from a script pipeline; music uses placeholder stems that quote a sketched abyss motif. No slot-format change (volumes live in `settings.cfg`).

### Story 3.1: SFX script pipeline

**Type:** dev

As the developer,
I want sound effects generated from text parameter files on the server,
So that every sound is reproducible, reviewable in git and built like the sprites.

**Acceptance Criteria:**

**Given** `tools/build_sfx.py` and `tools/sfx/<event>.txt` parameter files
**When** the script runs on the server (Python 3)
**Then** it writes `game/audio/sfx/<event>.wav` (build output, committed with its `.import`) and the same parameters always produce the same file (FR75, AR45)

**Given** the boundary rule
**When** the pipeline writes files
**Then** `tools/` writes only into `game/art/` and `game/audio/sfx/`, and no WAV under `game/audio/sfx/` is hand-made
**And** `docs/` describes the parameter format and how to add an event

### Story 3.2: The Audio autoload and the core SFX set

**Type:** dev

As a player,
I want the world to sound physical and my light to sound synthetic,
So that I can hear the difference between me and the abyss.

**Acceptance Criteria:**

**Given** `audio/audio.gd` registered as the autoload `Audio` (the second and last autoload; no `class_name`)
**When** it starts
**Then** it holds a small pool of SFX players (the only pooling allowed) and runs `PROCESS_MODE_ALWAYS`, while gameplay SFX players are pausable children that stop with the game (AR9, AR43)
**And** everything plays on Master with no bus effects, and on web nothing plays before the click-to-play gate (ADR-5)

**Given** gameplay signals (`chain.banked`, Snuff, cling start, flare thrown and burning, Weaver strand pogo and retreat)
**When** they fire
**Then** `Audio` plays: a bank chime that grows longer with the amount banked; the light blown out, then muffled silence for Snuff; a rope or wood creak for cling; a whoosh then a sizzle while a flare burns; a strand twang and a hiss when light makes the Weaver retreat (FR76)
**And** `audio/` only listens to signals; it never changes gameplay state

**Given** the chain gate sound (a resonant tone that rises to the required count and opens on a chord, or a dull thud)
**When** this story lands
**Then** its SFX files exist in the pipeline, ready for the gate object in E4

### Story 3.3: Pogo pitch crescendo

**Type:** dev

As a player,
I want every pogo hit to ring a semitone higher than the last,
So that the chain itself becomes the "one more hit" temptation.

**Acceptance Criteria:**

**Given** a pogo hit at link k
**When** the strike plays
**Then** its pitch is `pow(2.0, mini(k, 12) / 12.0)` (+1 semitone per link, capped at +12), set before `play()` (FR76, AR44)

**Given** a 75 ms hitstop during a fast chain
**When** strikes overlap
**Then** a scripted test render of a 20-hit chain with hitstop peaks at or below −1 dBFS (NFR15)
**And** the Playwright web smoke check verifies the pitch on web

### Story 3.4: Positional lurker cues

**Type:** dev

As a player,
I want to hear a lurker stir, growl and hunt from its side of the screen,
So that I hear it before I see it.

**Acceptance Criteria:**

**Given** a lurker entering `TELEGRAPH`
**When** its eyes open
**Then** a low breath or growl plays, panned to the lurker's side, always mixed above the music (FR76)

**Given** a lurker in `HUNT`
**When** it moves
**Then** a rising hiss follows its position

**Given** a lurker stirring off screen (`stir` > 0)
**When** the edge eye shows
**Then** a quiet stirring sound plays panned to that side, rising with `stir`; it stops when stirring stops (FR18, UX-DR143)
**And** lurker cue players are pausable and stop with the game

### Story 3.5: Sketch the motif and the placeholder stems

**Type:** designer

As the composer,
I want a short abyss motif and rough placeholder stems,
So that the music system has real stems to run and every layer stem quotes the motif from the start.

**Acceptance Criteria:**

**Given** the narrative note that the hub theme's melody is quietly an abyss melody that layer themes quote
**When** sonlm sketches it on the laptop
**Then** it is committed as a placeholder `hub_theme` stem with a short note of the motif (key, intervals, rhythm) in `docs/` (FR77, R3)
**And** sonlm also sketches the placeholder Layer 1 stems `l1_pulse`, `l1_melody`, `l1_full` (equal length, quoting the motif) and a single-stem placeholder theme for the Weaver test arena, committed as audio files with their `.import` (no tool generates music)
**And** the composed hub, Weaver and Fall themes remain E7 work

### Story 3.6: Chain-reactive music stems and Layer 1 ambience

**Type:** dev

As a player,
I want the music to build with my chain and resolve when I bank,
So that the music itself rewards daring.

**Acceptance Criteria:**

**Given** `audio/music_stems.gd` and placeholder Layer 1 stems `l1_pulse`, `l1_melody`, `l1_full` (equal length, quoting the motif) plus a silent stem at −80 dB
**When** a dive starts
**Then** all stems start together and loop forever in sync; at rest only the ambient soundscape is heard (creaking rope, wind, dripping, iron settling) (FR77, AR43)

**Given** `chain.changed(count)`
**When** the chain reaches 3, 6 and 10 links
**Then** the pulse, melody and full layers fade in over 0.5 s, in step with the chain number's size steps (UX-DR136, AR44)

**Given** `chain.banked`
**When** the chain ends safely
**Then** a resolve chord plays and the stems fade to 0 within 0.3 s

**Given** `player.died`
**When** the player dies
**Then** the stems cut with a muffled, dissonant tail
**And** the Weaver test arena uses a single-stem placeholder theme from the same player set

### Story 3.7: Ducking and mix

**Type:** dev

As a player,
I want predator cues to cut through the music every time,
So that a telegraph is never drowned out.

**Acceptance Criteria:**

**Given** a predator cue playing
**When** the music is up
**Then** music ducks by ×0.5 (−6 dB) and recovers after the cue (NFR15, AR44)

**Given** stem volume = layer × duck × music volume × master
**When** a duck lands during a fade
**Then** one `_apply(i)` recomputes the final volume, so the stem never jumps; all fades use tweens with `set_ignore_time_scale(true)` and never freeze during hitstop

**Given** the game is paused
**When** the pause menu is open
**Then** music and menu sounds keep playing and gameplay SFX (including a lurker hiss) stop
**And** a written levels table in `docs/` records each event's level against the mix rules

### Story 3.8: Options > Audio tab

**Type:** dev

As a player,
I want volume sliders,
So that I can balance music and effects for where I'm playing.

**Decide before dev (sonlm):** UX O14: which volume sliders exist, and whether a mono toggle ships.

**Acceptance Criteria:**

**Given** Options
**When** E3 lands
**Then** the Audio tab appears (unlanded tabs stay hidden) with volume sliders using the UI kit Slider (10 segments, value number to the right) (FR33, UX-DR77)

**Given** UX O14 (mono audio and separate sliders)
**When** this story is planned
**Then** sonlm decides which sliders exist (e.g. master, music, effects) and whether a mono toggle ships, and the decision is recorded in `EXPERIENCE.md`

**Given** a slider change
**When** it applies
**Then** it takes effect at once, multiplies with master through `Audio._apply`, and persists in `settings.json`

### Story 3.9: E3 playtest

**Type:** playtest

As the designer,
I want to play the shaft and the Weaver arena with sound on the laptop and in the browser,
So that I know whether sound makes the pogo feel great and lurkers readable.

**Acceptance Criteria:**

**Given** the E3 build (desktop and web)
**When** sonlm plays the shaft and the test arena
**Then** the answers to "does sound make the pogo feel great?" and "are lurkers heard before they are seen?" are recorded with notes in `implementation-artifacts/` (FR76, FR77, NFR15)

**Given** the web build
**When** the export pipeline runs
**Then** the download is still under 30 MB with the stems included, and the web smoke check passes
**And** a devlog or private build is posted; E3 has no hard dependents, so a "no" becomes fix stories at the head of E7's music work

## Epic 4: Layer 1: Edge of the Abyss

The player descends Layer 1 from the Lip to the Hollow Station: learns each move before it is tested, opens chain gates, explores the Rope Works, Old Mine and Sky Ledge, reads the island's lost and finds Oda's last camp, and maps it all. The hub is a placeholder room; the Weaver arena room and fight are E6 (its door is sealed here). Checkpoint after the teaching half (S1–S3, Story 4.13).

Every room story in this epic: the room file validates; `smoke_rooms` guarantees hold; the bot reaches chain ≥ `Spec.BOT_MIN_CHAIN` in every spine room with plain movement and no dash; lantern anchors land about every 4–6 screens (≈ 5 in the layer, FR27); level rules from FR57 hold (ledges every ≤ 1.5 s of fall in spines, an escape near every predator-heavy stretch, exits behind a landing, each new move shown safe first and tested 2–4 screens later). **Exit wiring:** a room story wires exits only to rooms that already exist; a passage to an unbuilt room is walled, and the story that builds the next room opens it, adding the exit on both sides.

### Story 4.1: Save format v2

**Type:** dev

As a player with an E1 save,
I want my slot to load in the Layer 1 build,
So that my progress survives the update.

**Acceptance Criteria:**

**Given** `rules/migrations.gd`
**When** a v1 slot loads
**Then** `migrate_v1_to_v2()` adds the E4 fields with safe defaults: collected journal entries, map pins, the last death point (AR37)

**Given** `tests/fixtures/slot_v1.json`
**When** the test suite runs
**Then** it loads, migrates to v2 and round-trips; a new `tests/fixtures/slot_v2.json` is committed from a real E4-format slot

**Given** E1-era saves point into `m1_shaft` (a resume point, respawn point or Ember Cache; lit flags for `anchor_m1_*` and `station_m1_top`)
**When** they migrate
**Then** the data is remapped by id: any resume or respawn point becomes `station_lip`, a cache moves to room `s1_lip` at the Lip Station's position keeping its amount, and `m1_*` object flags are dropped
**And** a data-level test migrates `slot_v1` with a cache in `m1_shaft` and asserts the remapped ids and the cache amount (the runtime check lands with S1 in Story 4.9)
**And** this story lands before any E4 feature writes a new field

### Story 4.2: UX update: map tab and tutorial prompts

**Type:** ux-update

As the designer,
I want the map tab and the first-dive prompts mocked before they're built,
So that the E4 UI follows a reviewed design, not guesses.

**Acceptance Criteria:**

**Given** `gds-ux` in Update mode with `DESIGN.md` and `EXPERIENCE.md`
**When** the update runs
**Then** it settles O2 (S1 tutorial: glyph prompts or in-world signs), O3 (map room colours, icon art, pin place/remove controls) and O7 for the map (empty-map state), with a map-tab mock (UX-DR93, UX-DR94, UX-DR105)

**Given** the found Cartographer hint in [B]
**When** the map design is settled
**Then** it defines what the hint pickup reveals on the map

### Story 4.3: Voice anchors for Oda's hand and the documents

**Type:** designer

As the designer,
I want to approve three anchor lines for Oda's journal hand and for the lost-islander documents,
So that The Last Entry and the documents are written in the right voices.

**Acceptance Criteria:**

**Given** `narrative-design.md` (Oda's hand: first person, warm and vivid early, clipped and hungry later; love and greed in the same hand; documents: industrial-age workers and divers, world history only, no origin clues)
**When** Claude drafts at least 6 candidates for each voice
**Then** sonlm picks and edits 3 anchors per voice, recorded with the date in `narrative-design.md` (NR1, NR21, NR24)
**And** no `JOURNAL_*_BODY` string exists before its voice's anchors are approved

### Story 4.4: Story-flag registry and `lurker_met`

**Type:** dev

As the developer,
I want every story flag declared in one registry that saves understand,
So that a typo in a flag id can't silently break a payoff.

**Acceptance Criteria:**

**Given** `rules/story_flags.gd` (one list; ids are save data and never renamed)
**When** E4 lands
**Then** it declares `lurker_met` and `last_entry_read`, and story flags are set only through `Game.slot.set_story_flag(id)`, which asserts on an id not in the registry; world-object flags (anchors, stations, gates, hoards, secrets) keep using `set_flag()` and are validated against room-header ids (NR5, R2)

**Given** a lurker
**When** its telegraph starts with the lurker inside `World.play_rect()` (not the viewport)
**Then** `lurker_met` is set once and saved with the slot (FR63)
**And** the `requires_flag` validator is E5 work (NR7)

### Story 4.5: Layer 1 tileset, palette zones and the zone cross-fade

**Type:** dev, content

As a player,
I want the daylight to fade as I descend,
So that depth shows on screen and my amber light stands out more the deeper I go.

**Acceptance Criteria:**

**Given** the Layer 1 tileset (text grids → `tools/build_sprites.py` → PNG, with a ledge-rim variant)
**When** a room loads
**Then** its `zone=` header picks the palette: Dusk (S1, A), Umber (S2–S3), Cold violet (S4–S5, B, C), with the GDD hex values (FR59)
**And** ledge rims glow faintly, and old lamps in the layer are dead or a cold tint (amber burns only on lantern anchors and in the hub)

**Given** the camera centre crosses a palette-zone boundary
**When** the zone changes
**Then** the gutter fill, rules and every zone-role UI colour cross-fade to the new zone over 500 ms with no flash; under reduced motion they snap in one frame; amber and predator red never change (UX-DR142)

### Story 4.6: Layer 1 creature and object sprites

**Type:** content, dev

As a player,
I want every creature and object to read clearly in the dark,
So that I can tell fuel, danger and help apart at a glance.

**Acceptance Criteria:**

**Given** sprite grids in `tools/sprites/` with `palette_edge.txt`
**When** `build_sprites.py` runs
**Then** it produces 16–24 px sprites for the crawler walker, crawler hoverer, lurker, spiderling, lantern anchor (cold and lit), Lift Station, chain gate, Ember Cache, flare, Ember Hoard, journal object and silk anchor; no PNG is hand-made (FR58)

**Given** a creature is hit or killed
**When** it reacts
**Then** it bursts into small sparks in its own tint that turn amber as they fade (no travel to the HUD, not a flash, never blood), built through `Fx` as `CPUParticles2D` with a cached material warmed at room load and honouring reduce flashing (FR38, NFR19)
**And** things that must read in the dark (predators, the player's light effects) use `LIGHT_MODE_UNSHADED`

### Story 4.7: Room-to-room flow across Layer 1

**Type:** dev

As a player,
I want to move between Layer 1's rooms smoothly,
So that the layer feels like one connected place.

**Decide before dev (sonlm):** how each side area exits back to the spine.

**Acceptance Criteria:**

**Given** rooms with `exits=` and `map=` headers
**When** the player crosses an exit
**Then** the next room loads behind a short transition, the player appears at the matching entry, the camera leads downward in tall rooms and never scrolls sideways in 22-tile (352 px) spines; wider rooms scroll horizontally (FR53, AR21)

**Given** the GDD open question "how each side area exits back to the spine"
**When** this story is planned
**Then** sonlm picks the pattern (e.g. a one-way drop back into the spine below the branch, or a return to the branch door), and it is recorded in the GDD and `docs/rooms.md`

**And** the validator rejects an exit whose target room id doesn't exist

### Story 4.8: Final Lift Station, fast travel and a placeholder hub

**Type:** dev

As a player,
I want real stations I can rest at and travel between, and a place up top to bank everything,
So that a long descent can be split into safe legs.

**Acceptance Criteria:**

**Given** `objects/lift_station.gd` (final)
**When** the player touches a station
**Then** it lights and becomes the respawn point; ↓ rests (heal, deposit, enemies respawn, autosave, station menu) (FR28)

**Given** the station menu
**When** Fast travel is chosen
**Then** a list replaces the items in place: the hub first, then lit stations top to bottom, excluding the current one; Back returns to the station menu (UX-DR90)

**Given** `rooms/hub/placeholder.txt` (one flat room, no enemies, with a lift)
**When** the player arrives by lift or by the gate-2 shortcut
**Then** all carried embers are deposited, HP is full, the slot autosaves, and the lift goes down to any lit station (the Lip Station once S1 exists); the real hub is E5

**Given** the player leaves the layer (to the hub)
**When** the dive ends
**Then** `dive.reset()` respawns the layer's enemies (FR58)

### Story 4.9: S1 The Lip

**Type:** dev, content

As a new player,
I want a safe first stretch that teaches running, jumping, slashing and my first pogo,
So that I learn the basics before anything hunts me.

**Acceptance Criteria:**

**Given** `rooms/l1/s1_lip.txt` (screens 0–3, Dusk, with the Lip Station `station_lip`; room and object ids follow the AR26 naming rules)
**When** the player plays it
**Then** it teaches run, jump, slash and a first pogo over safety nets, shows that landing banks embers, and has no lurkers (FR54)
**And** the tutorial cues follow the O2 decision from Story 4.2 (UX-DR105)
**And** the Lip Station is the first respawn point and its lift reaches the placeholder hub
**And** S1's way down is walled until S2 lands

**Given** S1 exists
**When** this story lands
**Then** New Game starts in `s1_lip` at the Lip Station, the title's backdrop scrolls S1, and `m1_shaft` moves to `rooms/dev/` as a test room excluded from release builds (FR72: until E5, New Game starts in S1)
**And** a runtime test loads the migrated `slot_v1` fixture with a cache in `m1_shaft` and asserts the player wakes at the Lip Station with carried embers and the cache amount intact

### Story 4.10: S2 Scaffold Drop

**Type:** dev, content

As a player,
I want to meet my first lurker with a ledge right below it, then learn to cling and to toss a flare,
So that every escape is shown safe before it's tested.

**Acceptance Criteria:**

**Given** `rooms/l1/s2_scaffold.txt` (screens 4–9, Umber)
**When** the player descends
**Then** the first lurker's eyes open right above a ledge (the cash-out lesson); a narrow stretch 6–10 tiles wide with no ledges teaches wall cling; a lurker pocket teaches Flare Toss; S2 opens S1's way down into it (FR54, FR57)

**Given** the branch to [A] Rope Works
**When** S2 ships
**Then** the branch is walled off until Story 4.21 opens it

**Given** `objects/silk_anchor.gd` (new, inert)
**When** S2 builds
**Then** a visible silk anchor and a sealed secret alcove sit in S2 with ids in the room header (`silk_s2_1`, `secret_s2_1`); the anchor can't be grabbed and the bot ignores what's behind it (FR52, AR33)

### Story 4.11: The chain gate

**Type:** dev

As a player,
I want lantern doors that open only for a long enough chain,
So that progress comes from mastery, not grinding.

**Acceptance Criteria:**

**Given** `objects/chain_gate.gd` with a required count in its header entry
**When** the player touches it with chain ≥ required
**Then** it opens for good (a `SlotState` flag) with a resonant tone that rises to the count and a chord (FR56)

**Given** chain < required
**When** the player touches it
**Then** it stays shut, glows the required number and bounces the player off with a dull thud; the chain is not broken (FR56, UX-DR144)
**And** the gate reads the current chain count, including a chain paused by cling

**Given** the gate sound
**When** this story is scheduled
**Then** E3's Story 3.2 (the gate SFX and the `Audio` autoload) has landed first; if E3 is interleaved with E4, 3.2 is pulled ahead of this story

**Given** `tests/smoke_bot.gd`
**When** it runs a gate room
**Then** it arrives at every gate with at least the required chain using plain movement and no dash (AR50)

### Story 4.12: S3 The Lantern Door

**Type:** dev, content

As a player,
I want a gate on the main path that I can open by reading a row of hoverers,
So that the first chain requirement feels earned, not lucky.

**Acceptance Criteria:**

**Given** `rooms/l1/s3_gate.txt` (screens 10–12, Umber)
**When** the player approaches gate 1 (≥ 4)
**Then** a row of hoverers above it makes chain 4 reachable on the first try with plain movement and no dash, and the way past it is walled until S4 lands (FR54, FR56)
**And** most players should need 1–3 tries; the bot proves the minimum is reachable

### Story 4.13: Teaching-half checkpoint

**Type:** playtest

As the designer,
I want S1–S3 played by me and 1–2 outside players before the rest of the layer is built,
So that the teaching problems are fixed before the testing half depends on them.

**Decide before dev (sonlm):** whether Layer 1 needs a third regular enemy (after the walk-through).

**Acceptance Criteria:**

**Given** a private web build from the Lip to gate 1
**When** sonlm and 1–2 outside players play it
**Then** the answers to "is each move taught before it is tested?" and "do anchors keep retries short?" are recorded in `implementation-artifacts/`

**Given** the GDD note on a third regular enemy
**When** the walk-through is reviewed
**Then** sonlm decides whether Layer 1 needs one; if yes, it becomes a story before Story 4.16 (FR58)
**And** a devlog or private build is posted

### Story 4.14: Ember Hoards and the economy rules

**Type:** dev

As a player,
I want hidden ember hoards that reward exploring off the main path,
So that side areas pay for the risk.

**Acceptance Criteria:**

**Given** `objects/ember_hoard.gd` (persistent id, e.g. `hoard_a_1`)
**When** the player touches it
**Then** its amount moves into carried (not deposited) and a `SlotState` flag stops it ever reappearing (FR62)

**Given** `rules/economy.gd`
**When** values are needed
**Then** it holds the hoard amounts (A ≈ 60, B ≈ 80, C ≈ 100), the prices (map 60, hint 25, gear 200–300, cosmetics 75–150), the ember curve and the journal payout, each citing its GDD table (AR17)

### Story 4.15: Journal objects and the document screen

**Type:** dev

As a player,
I want to read the notes the island's lost left behind, whenever I choose,
So that the story never interrupts a chain.

**Acceptance Criteria:**

**Given** `objects/journal_object.gd` (persistent id, e.g. `journal_a_1`; text key `JOURNAL_<ID>_BODY`)
**When** the player presses ↓ standing still beside it
**Then** a document screen opens through `ScreenRouter`, gameplay pauses, the text shows in `body-line`, and the player closes it at will (FR61, NR10)

**Given** the entry is read
**When** the screen closes
**Then** it is recorded in `SlotState` and never lost
**And** story screens open only by player choice; nothing story-related opens during a chain

### Story 4.16: S4 Explorers' Grave

**Type:** dev, content

As a player,
I want lurker rooms that test my Flare Toss and cling under pressure,
So that I prove what S2 taught me.

**Acceptance Criteria:**

**Given** `rooms/l1/s4_grave.txt` (screens 13–18, Cold violet)
**When** the player descends
**Then** lurker rooms require committed use of Flare Toss and cling with an escape always in reach, and camps of lost explorers dress the space (FR54, FR57, NR17)
**And** S4 opens the way down past gate 1 into it
**And** the branches to [B] and [C] are walled off until Stories 4.22 and 4.23 open them
**And** the space for Oda's camp is reserved for Story 4.17

### Story 4.17: The Last Entry

**Type:** dev, content

As a player,
I want to find Oda's last camp and relight her lantern,
So that the descent has its one quiet, personal moment.

**Acceptance Criteria:**

**Given** Oda's camp on the S4 main path (bedroll, cold lantern, half-written journal; set-piece overlay `s4_grave.tscn`)
**When** the player touches the cold lantern
**Then** it lights as the lantern anchor `anchor_s4_oda`, and from then on the player respawns at her camp (FR61, NR6, NR16)

**Given** the journal
**When** the player reads it (↓, document screen)
**Then** `last_entry_read` is set, it counts as a journal entry, and its text ("going deeper", unsigned) follows the approved Oda anchors and is approved by sonlm (NR2, NR16, NR21, NR22)

**Given** `scripts/moments/last_entry.gd`
**When** the moment plays
**Then** it uses only Clock requests, `PlayerInput.lock()`, camera hooks and audio cues, honours reduced motion and reduce flashing, and never stops a live chain (AR56, NR12)
**And** it is Layer 1's only set piece

### Story 4.18: The lost-islander documents and the Memorial name list

**Type:** content

As the designer,
I want the three documents and the Memorial's names written together,
So that the names on the Wall match the people who wrote the notes.

**Acceptance Criteria:**

**Given** the approved document anchors
**When** Claude drafts the 3 documents (Rope Works ×2, Old Mine ×1)
**Then** each is world history only (the yard and the mine going dark, "the taking"), with no origin clues, about 500 words for all 4 documents including The Last Entry, and sonlm approves them before commit (NR4, NR16, NR23)

**Given** the Memorial Wall list (≈ 20 names plus Oda Vell)
**When** it is written
**Then** the document writers' names are on it, it carries no humour, and it is stored as data for E5 to display (FR61)

### Story 4.19: S5 Weaver's Hollow

**Type:** dev, content

As a player,
I want to hear and glimpse something huge before I reach its lair,
So that the boss is set up before I fight it.

**Acceptance Criteria:**

**Given** `rooms/l1/s5_hollow.txt` (screens 19–22, Cold violet, wild abyss dressing)
**When** the player enters
**Then** `scripts/moments/weaver_reveal.gd` lets them hear and glimpse the Weaver (a placeholder silhouette) while they keep moving, with input live (NR18, AR56)

**Given** the Hollow Station `station_hollow` before the arena
**When** the player rests there
**Then** it works like any station, and no enemies are within 2 screens of it (FR57)
**And** S5 opens S4's way down into it
**And** the arena door below is sealed in E4; the arena is E6

### Story 4.20: The map tab

**Type:** dev

As a player,
I want a map that fills in as I explore and marks where I lost my embers,
So that I know where to be daring and where to go back.

**Acceptance Criteria:**

**Given** the Pause tab bar
**When** E4 lands
**Then** it reads Pause | Map, and Q/E or LB/RB switch tabs (UX-DR69)

**Given** the Map tab (built to the Story 4.2 mock)
**When** it opens
**Then** visited screens show as room boxes with doors (from `map=` headers); Lift Stations and lit anchors always show; chain gates, the Ember Cache and the last death point are marked (Easy and Hard: last death point only; Normal: cache and last death point); per-layer reward counts show, never a percentage (FR60, UX-DR87, UX-DR93)

**Given** map controls
**When** the player uses them
**Then** they pan with arrows or stick, switch between layer view and close view, and place or remove up to about 10 pins, saved in the slot (UX-DR94)

### Story 4.21: [A] Rope Works

**Type:** dev, content

As a player who likes to explore,
I want an old rope yard off S2 with stories and embers in it,
So that leaving the main path pays off.

**Acceptance Criteria:**

**Given** `rooms/l1/a_rope_works.txt` (Dusk; S2's branch now opened)
**When** the player explores it
**Then** it holds Ember Hoard `hoard_a_1` (≈ 60), journal objects `journal_a_1` and `journal_a_2`, and an inert silk anchor with a sealed alcove (`silk_a_1`, `secret_a_1`), and it exits back to the spine by the pattern from Story 4.7 (FR55, FR52)
**And** a cling-kick plus air dash can reach its entrance early; that skip is allowed

### Story 4.22: [B] Old Mine

**Type:** dev, content

As a daring player,
I want dark galleries packed with lurkers,
So that I can test everything I know for a bigger reward.

**Acceptance Criteria:**

**Given** `rooms/l1/b_old_mine.txt` (Cold violet, ≥ 1 lurker per screen; S4's branch now opened)
**When** the player explores it
**Then** it holds Ember Hoard `hoard_b_1` (≈ 80), journal object `journal_b_1` and the Cartographer hint pickup (its effect from Story 4.2), with an escape in reach in every lurker room, and it exits back to the spine by the Story 4.7 pattern (FR55, FR57)

### Story 4.23: [C] Sky Ledge and the shortcut home

**Type:** dev, content

As a player with a long chain,
I want a gate that opens a shortcut home,
So that the best divers get the only safe mid-layer deposit.

**Acceptance Criteria:**

**Given** `rooms/l1/c_sky_ledge.txt` (open cliff; S4's branch now opened)
**When** the player reaches gate 2 (≥ 8, `gate_c_1`)
**Then** opening it reveals a shortcut that leads up to the hub (the placeholder hub in E4) and stays open for good (FR55, FR56)
**And** the area holds Ember Hoard `hoard_c_1` (≈ 100) and an inert silk anchor with a sealed alcove (`silk_c_1`, `secret_c_1`) (FR52)
**And** the shortcut goes up only, so it can never softlock the descent

### Story 4.24: Full-layer bot and softlock pass

**Type:** dev

As the developer,
I want every Layer 1 room and gate checked automatically,
So that no change can quietly make the layer unreachable or unfair.

**Acceptance Criteria:**

**Given** every `rooms/l1/*.txt`
**When** the suite runs
**Then** the bot reaches chain ≥ `Spec.BOT_MIN_CHAIN` in every spine room and the required chain at every gate, with plain movement and no dash; the exit backstop never fires on its line (AR50, FR57)

**Given** the softlock rules
**When** they are checked
**Then** every drop between stations leads on to the Hollow Station or a station; gate 2's shortcut goes up only; every hazard pit has a ledge or wall within a 1.5 s fall at 210 px/s; zero softlocks are found (NFR14)

### Story 4.25: NPC voice anchors

**Type:** designer

As the designer,
I want the four hub voices anchored before E5 starts,
So that hub writing never waits on approvals.

**Acceptance Criteria:**

**Given** `narrative-design.md` (Old Tessaly gruff, short sentences, island sayings, calls Glim "Glim"; the Smith fewest words, tools and materials; the Cartographer precise and fussy; the Naturalist asks rather than states)
**When** Claude drafts at least 6 candidates per speaker
**Then** sonlm picks and edits 3 anchors each for Tessaly, the Smith, the Cartographer and the Naturalist, recorded with the date in `narrative-design.md` (NR1, NR24)
**And** no `NPC_*` string exists before its speaker's anchors are approved

### Story 4.26: E4 playtest

**Type:** playtest

As the designer,
I want the full layer played from the Lip to the Hollow Station,
So that I know it teaches, tempts and stays fair end to end.

**Acceptance Criteria:**

**Given** a private web build of the full layer
**When** sonlm and 1–2 outside players play it
**Then** the answers to "does each move get taught before it is tested?", "do anchors keep retries short?" and "do players go for the gates and side areas?" are recorded in `implementation-artifacts/` (FR54–FR57)
**And** a devlog or private build is posted; a "no" becomes the first stories of E5 or E6, whichever builds on it

## Epic 5: Abyss Island: Come Home and Spend

The player starts a new game in Oda's house, registers the First Dive with Old Tessaly, dives, rides the lift home watched by the creatures, deposits and heals, and spends embers on maps, hints, gear and palettes while the hub's people slowly react to what they have done. Hub writing follows the voice anchors approved in Story 4.25; creature entries follow the death-card anchors (field-note voice).

Every writing story in this epic: lines are drafted against the approved anchors and `narrative-design.md`, approved by sonlm before commit, keyed per NR3, and pass the flag and length validators (NR2, NR21–NR24).

### Story 5.1: Save format v3

**Type:** dev

As a player with an E4 save,
I want my slot to load in the hub build,
So that my progress survives the update.

**Acceptance Criteria:**

**Given** `rules/migrations.gd`
**When** a v2 slot loads
**Then** `migrate_v2_to_v3()` adds per-NPC `{seen, idle}` records and talk counters, gear and palettes owned, the equipped palette, hints bought, unlocked creature entries, entries the Naturalist has paid for, the new Guild records (deepest depth, most embers banked in one chain) and the departure flags, with safe defaults (AR37, R4)

**Given** `tests/fixtures/slot_v1.json` and `slot_v2.json`
**When** the suite runs
**Then** both migrate to v3 and round-trip, and `tests/fixtures/slot_v3.json` is committed
**And** this story lands before any E5 feature writes a new field

### Story 5.2: UX update: the hub surfaces

**Type:** ux-update

As the designer,
I want the hub's screens and moments mocked before they're built,
So that the hub follows a reviewed design.

**Acceptance Criteria:**

**Given** `gds-ux` in Update mode
**When** the update runs
**Then** it settles: Oda's house and the opening sequence; lift-ride timing (mocked together with the speech box); the speech box frame, height, name tag, reveal, skip rules and line length (O5); the shop layout, buy confirm and can't-afford response (O6); the Journal tab layout, "new" mark art, empty states and the Guild records board form (O7); the gutters during scripted moments, both The Watching Departure and The Fall (O8) (UX-DR91, UX-DR92, UX-DR95, UX-DR97)

**Given** the hub palette (O9)
**When** it is designed (bright, warm, low contrast)
**Then** its zone-role UI tokens are added and pass the same contrast floors as Layer 1 (UX-DR10)

### Story 5.3: Abyss Island village

**Type:** dev, content

As a player,
I want a warm, small home above the pit,
So that coming back up feels like coming home.

**Acceptance Criteria:**

**Given** `rooms/hub/island.txt` (2 screens wide, flat ground, scrolls horizontally, no enemies, no chain, no platforming) built with the hub tileset and palette
**When** the player walks it
**Then** the layout reads Smith, Cartographer, Lift, Naturalist, Guild + Memorial Wall, Oda's house; the gutters stay (FR64, AR26)

**Given** the dressing
**When** the hub renders
**Then** it has static industrial props only (lift cage, one winch, some pipe), a stack of relic crates by the lift stamped for shipping, and amber ember lanterns lit (the only place besides anchors where amber lanterns burn) (NR15)

**Given** the player arrives home
**When** the lift (or the gate-2 shortcut) reaches the hub
**Then** all carried embers are deposited, HP is full, the layer's enemies reset and the slot autosaves (FR12, FR29, FR64)
**And** the placeholder hub room is removed and its references point here

**Given** the hub's soundscape
**When** the player is in the hub
**Then** boiler hiss, the winch and distant voices play through `Audio` as organic-world ambience, with no chain-reactive music (the placeholder hub theme from Story 3.5 may play) (NR15)

### Story 5.4: The lift ride

**Type:** dev

As a player,
I want the lift home to be a ride, not a cut,
So that leaving the layer feels like a journey, with room for whatever watches me go.

**Acceptance Criteria:**

**Given** the real hub's lift (replacing the placeholder hub's lift from Story 4.8)
**When** the player rides up from any lit station
**Then** the ride lasts a fixed time set in `Tuning` (long enough for the full Departure, which fills it in Story 5.15) and ends at the hub, triggering the arrival from Story 5.3 (FR65)

**Given** the hub lift
**When** the player rides down
**Then** they pick any lit station from the fast-travel list built in Story 4.8, with the hub listed first from stations (UX-DR90); there is no fast travel to lantern anchors, and trips down or sideways have no ride sequence

### Story 5.5: Hub NPC sprites and the NPC object

**Type:** dev, content

As a player,
I want four distinct people in the hub I can walk up to,
So that home has faces.

**Acceptance Criteria:**

**Given** sprite grids for the Smith, the Cartographer, the Naturalist and Old Tessaly
**When** `build_sprites.py` runs
**Then** each NPC has an idle sprite in the hub palette (no hand-made PNGs)

**Given** `objects/npc.gd` (persistent id, e.g. `npc_smith`)
**When** the player presses ↓ standing still beside an NPC
**Then** a glyph prompt shows in range and the interaction starts (AR33)

### Story 5.6: NPC dialogue framework

**Type:** dev

As a player,
I want NPCs to say something new only when something has changed, then get on with business,
So that talking never feels like a chore.

**Acceptance Criteria:**

**Given** `rules/dialogue.gd` (per-NPC ordered `{key, requires_flag}` lists; linear, no choices; Glim is silent)
**When** the player talks to an NPC
**Then** lines unlocked by a newly set flag play (≤ 3 per NPC per flag), never replaying old story lines; with nothing new the NPC says one idle line, then runs the NPC's after-talk action, a hook that the shop (Story 5.9) and the record board (Story 5.13) plug into, doing nothing until then; idle lines rotate by a saved per-NPC talk counter, never at random (FR73, NR9, AR17)

**Given** the speech box (built to the Story 5.2 mock)
**When** lines play
**Then** it sits at the bottom of the 360 px play area with a name tag, one line at a time in `body-line`, and confirm advances (UX-DR91, NR10)

**Given** the flag registry
**When** E5 lands
**Then** it gains `first_dive`, `memorial_read`, `bought_map`, `bought_wick`, `first_entry_sold`, `departure_l1_seen` (NR5)

### Story 5.7: Flag and length validators

**Type:** dev

As the developer,
I want story text checked for unknown flags and overlong lines before any build,
So that a typo or a long line never reaches a player.

**Acceptance Criteria:**

**Given** the validators (pure, returning error lists)
**When** the suite or `tools/export.sh` runs
**Then** the flag validator fails on any `requires_flag` or set flag missing from the registry, and the length validator fails on any speech string longer than 2 rows of the speech box measured in the UI font; export refuses to build on either (NR7, NR8)

### Story 5.8: Hub writing

**Type:** content

As the designer,
I want every hub line written and approved in one pass,
So that the hub's voices are consistent and the clue budget is respected.

**Decide before dev (sonlm):** names and pronouns for the Smith, the Cartographer and the Naturalist (or keep them pronoun-free).

**Acceptance Criteria:**

**Given** the approved NPC anchors and `narrative-design.md`
**When** Claude drafts the hub text
**Then** it covers: Tessaly's First Dive lines (clue 1: Oda never let Glim near the pit's edge; points at Oda's record), the Memorial Wall lines (quiet, no humour), the Smith (first visit, `bought_wick`: Oda's lantern), the Cartographer (first visit, `bought_map`: Oda's handwriting), the Naturalist (`first_entry_sold`: the observer, no clue), and 3 idle lines per NPC (NR14)

**Given** the creature entries and board labels
**When** they are drafted
**Then** the 5 creature entries (crawler walker, crawler hoverer, spiderling, lurker, Weaver; ≈ 300 words) follow the death-card field-note anchors, and the Guild board labels are written (NR15, R11)
**And** the inspect texts in Oda's house (bed, the empty chair, the gear wall) are written in the same field-note voice; Glim stays silent

**Given** the Smith, the Cartographer and the Naturalist have no names or pronouns yet
**When** this story is planned
**Then** sonlm decides their names and pronouns (or keeps them pronoun-free), recorded in `narrative-design.md` (R13)
**And** sonlm approves every line before commit; the clue budget holds (only the First Dive line is pointed in E5) (NR23)

### Story 5.9: Shop framework

**Type:** dev

As a player,
I want a clear shop list with prices and what I can afford,
So that spending feels deliberate.

**Acceptance Criteria:**

**Given** an NPC's shop (built to the Story 5.2 mock)
**When** it opens after the idle line
**Then** it lists items as menu items with the ember cursor, the deposited total and each price from `rules/economy.gd` (UX-DR92)

**Given** the player buys
**When** they can afford it
**Then** the buy confirm runs, deposited embers are spent through a `SlotState` rule method, and the item is owned and saved; when they can't afford it, the O6 response shows and nothing changes
**And** only deposited embers can be spent; carried and held never can

### Story 5.10: The Smith and gear

**Type:** dev

As a player,
I want gear that bends one rule I already know,
So that I get more options, never raw power.

**Acceptance Criteria:**

**Given** `rules/gear.gd` (data: `{id, stat, op, value}`)
**When** gear is owned
**Then** `Game.tuning` is rebuilt with `apply_gear()`: `long_wick` sets `flare_burn` 6.0; `steady_grip` sets `cling_slide` 10.0; `quick_wick` sets the flag `instant_snuff`; no actor ever checks `has_gear` (FR68, AR16)

**Given** the Smith's shop
**When** it opens
**Then** it sells Quick Wick (200), Long Wick (250) and Steady Grip (300); buying either Wick sets `bought_wick`

**Given** Quick Wick owned
**When** the player presses Light
**Then** the light starts dimming at once; releasing inside the tap window still throws a Flare Toss; the tap window doesn't change; in Snuff-toggle mode Quick Wick has no extra effect (FR68, FR34)
**And** tests cover each gear effect and the set → add → mul order with Silk Grip's `add` (E6) mocked

### Story 5.11: The Cartographer

**Type:** dev

As a player,
I want to buy a map and hints,
So that knowledge tells me where to be daring.

**Acceptance Criteria:**

**Given** the Cartographer's shop
**When** the player buys the Layer 1 map (60)
**Then** the map tab shows unvisited screens as dotted outlines, plus gate locations and secret markers; `bought_map` is set (FR67, FR60, UX-DR93)

**Given** the 3 hints (25 each)
**When** they are bought
**Then** each adds a map marker pointing to, in turn, a side area, gate 2 and a Swing secret

### Story 5.12: The Naturalist, journal payouts and the minimal Journal tab

**Type:** dev

As a player,
I want my journal entries to pay a little and to see what I've recorded,
So that reading the world is worth my time.

**Decide before dev (sonlm):** confirm the default: the Naturalist pays 10 embers once for every new Journal entry, the 5 creature entries and the 4 documents alike (≈ 90 embers in M2); a creature entry unlocks on the player's first on-screen encounter with that creature.

**Acceptance Criteria:**

**Given** the Pause tab bar
**When** E5 lands
**Then** it reads Pause | Map | Journal (UX-DR69)

**Given** the Journal tab (built to the Story 5.2 mock)
**When** it opens
**Then** it lists creature entries (sketch, how it hunts, how to beat it) in `body-line`, and entries the Naturalist hasn't paid for yet carry a "new" mark (FR71, UX-DR95)
**And** a creature entry unlocks on the first on-screen encounter with that creature, and documents the player has read appear in the tab too

**Given** the Naturalist
**When** the player has new entries
**Then** the Naturalist copies each new entry and pays 10 embers per copy into deposited; originals stay with the player; the first sale sets `first_entry_sold` (FR69)
**And** the Naturalist sells 2 cosmetic palettes (75, 150) that swap the player's colours; chain-light amber never changes

### Story 5.13: The Guild records board and the Memorial Wall

**Type:** dev

As a player,
I want to see my records next to the Last Explorer's, and the names of those the abyss kept,
So that I have a target, and a reason to care.

**Acceptance Criteria:**

**Given** the Guild records board (form per Story 5.2)
**When** Tessaly opens it after his idle line
**Then** it shows deepest depth, best chain, most embers banked in one chain and deaths, with Oda's all-time depth record as the target; runs using timing assists will be excluded once E7 adds them (FR70, UX-DR97)

**Given** the Memorial Wall
**When** the player reads it (↓)
**Then** it shows the E4 name list plus Oda Vell, and the first read sets `memorial_read` (FR70, NR15)

### Story 5.14: Oda's house and the new-game opening

**Type:** dev

As a new player,
I want to wake in the house of the woman who raised me and be sent on my first dive,
So that the story starts with a person, not a menu.

**Acceptance Criteria:**

**Given** Oda's house (a small interior beside the Guild: bed, Oda's empty chair, her gear wall)
**When** the player visits it
**Then** it is props and flag-gated lines only, not a save or rest point; after `last_entry_read`, the page `prop_house_page_last_entry` is pinned on the gear wall (FR72, NR6, NR15)

**Given** New Game (after the difficulty step)
**When** play begins
**Then** it fades in inside Oda's house; Glim wakes beside the empty chair; ↓ is taught on the door; outside, Tessaly's First Dive registration at the Guild is the only required talk and sets `first_dive`; the Memorial Wall is optional on the way to the lift; the full J1 first-five-minutes flow now holds (NR13, UX-DR104)

**Given** the first station rest
**When** it happens
**Then** the Map and Journal tabs are introduced; story and hub land within the first 2 minutes of a new game
**And** New Game no longer starts in S1

### Story 5.15: The Watching Departure

**Type:** dev

As a player,
I want the creatures to gather at the edge of my light and watch me leave,
So that the abyss feels like it knows me.

**Acceptance Criteria:**

**Given** `scripts/moments/watching_departure.gd` on the lift ride up from a Layer 1 station
**When** `lurker_met` is set and `departure_l1_seen` is not
**Then** the full gathering plays: Layer 1's creatures (hoverers, crawlers, lurker eyes) gather at the edge of the light to watch, not hunt, within the ride's fixed duration; `departure_l1_seen` is set (FR66, AR56, NR12)

**Given** later rides
**When** the player rides up again
**Then** a few eyes watch within the same ride time; before `lurker_met`, rides are plain; fast travel down or sideways plays no Departure

**Given** accessibility settings
**When** the moment plays
**Then** it uses only Clock requests, camera hooks and audio cues, honours reduced motion and reduce flashing, and follows the O8 gutter decision

### Story 5.16: Price tuning pass

**Type:** designer

As the designer,
I want prices set against real dive earnings,
So that "get home with it" pays off without trivialising the shops.

**Acceptance Criteria:**

**Given** several Layer 1 dives played between stations on Normal
**When** earnings are logged
**Then** the GDD assumption (100–250 embers per dive for a competent player) is confirmed or corrected (FR67, FR68, FR69, AR17)

**Given** the measured earnings
**When** prices are tuned
**Then** `rules/economy.gd` is updated with "was X" comments and the GDD Economy tables are updated to match

### Story 5.17: E5 playtest

**Type:** playtest

As the designer,
I want the full dive → home → spend loop played,
So that I know whether the three ember stages and the shops make diving home feel worth it.

**Acceptance Criteria:**

**Given** a private build from a new game through a few dives home
**When** sonlm plays it (outside players optional)
**Then** the answers to "do the three ember stages and the shops make 'get home with it' feel worth it?" and "are the prices right?" are recorded in `implementation-artifacts/` (UX-DR108)
**And** a devlog or private build is posted; a "no" becomes the first stories of E6

## Epic 6: The Weaver and Swing: The Complete Slice

The player faces the final Weaver at Weaver's Hollow, survives The Fall into the Layer 2 landing arena, wins phase 2, gains Swing, rides home watched by the abyss, and returns to Layer 1 to open the three Swing secrets, one of which adds a name to the Memorial Wall. Swing activates the silk anchors and alcoves E4 placed; E6 touches E4 rooms only to open S5's arena exit and to fill the three alcoves, never their layouts.

### Story 6.1: Save format v4

**Type:** dev

As a player with an E5 save,
I want my slot to load in the complete slice,
So that my progress survives the update.

**Acceptance Criteria:**

**Given** `rules/migrations.gd`
**When** a v3 slot loads
**Then** `migrate_v3_to_v4()` adds: abilities (Swing), the Weaver phase checkpoint, `weaver_defeated`, `departure_l2_seen`, opened secrets and the repaired landing station, with safe defaults (AR37)

**Given** the fixtures `slot_v1` … `slot_v3`
**When** the suite runs
**Then** each migrates to v4 and round-trips, and `tests/fixtures/slot_v4.json` is committed
**And** story flags (including the partner-tag flag named in Story 6.11) need no schema change: the story-flag set is generic
**And** this story lands before any E6 feature writes a new field

### Story 6.2: Apply the E2 prototype findings

**Type:** designer, dev

As the designer,
I want the prototype's decisions and playtest answers carried into the final fight,
So that E6 builds on what E2 proved, not on the original guesses.

**Acceptance Criteria:**

**Given** the E2 record in `implementation-artifacts/` (the 62–78 px band, the flee-target rule, the O10 alert decision, the blind-tester answers)
**When** this story starts
**Then** the GDD Weaver section and the Weaver code reflect each decision, and any tuning changes are made in `rules/tuning.gd` with "was X" comments (FR41, FR45, AR32)

**Given** the E2 playtest answered "no" on fun, readability or restraint
**When** this story is planned
**Then** the fixes are designed and built here, before Story 6.3, and re-checked with at least one outside player (the dependents-only rule)

### Story 6.3: Weaver art and animation

**Type:** content, dev

As a player,
I want a Weaver whose body tells me its state and its health,
So that I read the fight from the creature, not from a bar.

**Acceptance Criteria:**

**Given** segment sprites (body, 8 legs) and strand and anchor sprites (whole, frayed, sagging) built by `build_sprites.py`
**When** the Weaver moves
**Then** it animates retreat, descent, the bite rear-up with glowing eyes, stun, flee, Re-Weave and withdraw (FR40, FR44)

**Given** damage
**When** the Weaver loses HP
**Then** segments fray and fall off and threads sag in steps that let a player judge how close the end is, with no health bar (FR44, UX-DR99)
**And** sparks follow the creature spark rule (own tint fading to amber), and nothing shows blood or a body

### Story 6.4: The final arena and the Weaver's introduction

**Type:** dev, content

As a player,
I want to glimpse the Weaver on the way down, then enter its lair with no way back,
So that the fight feels like an arrival.

**Acceptance Criteria:**

**Given** `rooms/l1/weaver_arena.txt` + `weaver_arena.tscn` (30 × 34 tiles, scrolling horizontally, the 4-strand final layout)
**When** the player passes S5's door (now unsealed)
**Then** they enter one-way; the arena can't be left mid-fight; the fight logic from the E2 prototype (the Weaver FSM and its strand helpers) runs with the final art (FR40, AR26, AR32)

**Given** `scripts/moments/weaver_reveal.gd` in S5
**When** the player descends S5
**Then** the final staging lets them hear and glimpse the Weaver with its art while they keep moving, input live (NR18, NR12)
**And** the dev arena `rooms/dev/weaver_test` stays for debugging

### Story 6.5: The Layer 2 landing arena

**Type:** dev, content

As a player,
I want to land under a new sky,
So that beating the first layer shows me there's more below.

**Acceptance Criteria:**

**Given** `rooms/l2/landing_arena.txt` (one screen, 2 strand positions for phase 2)
**When** it renders
**Then** it uses the Bright Moon palette (cool silver-blue), designed in this story with zone-role UI tokens that pass the contrast floors (UX-DR10)

**Given** the landing arena
**When** the player explores it
**Then** it holds a broken Lift Station (repaired only on victory), the way down into Layer 2 is sealed, and the Bright Moon rule ("predators always see you up close") is off, so going dark still lures the Weaver (FR48)

### Story 6.6: The Fall

**Type:** dev

As a player,
I want the Weaver to cut the floor out from under us at half health,
So that the fight's climax is a free-fall chain that pays.

**Acceptance Criteria:**

**Given** the Weaver reaches 6 HP
**When** The Fall starts (`scripts/moments/the_fall.gd`)
**Then** the Weaver cuts its anchors, the web floor gives way, and `Game.clock.request(&"slowmo", 0.3, 0.5)` plays 0.5 s at ×0.3 (FR47, FR38)

**Given** about 6 s of free fall with debris and web clumps
**When** the player pogoes them
**Then** links and embers build as usual (a bonus chain section)

**Given** the hand-off
**When** the fall ends
**Then** `World.scripted_cut(&"landing_arena", entry)` moves the player without the exit backstop, so the chain survives the room change (the one exception), and the player lands in the landing arena (AR24, AR56)
**And** the gutters follow the O8 decision from Story 5.2
**And** the moment honours reduced motion and reduce flashing, and never writes `Engine.time_scale` directly

### Story 6.7: Phase 2

**Type:** dev

As a player,
I want a faster, tighter second phase,
So that the end of the fight tests what I've learned.

**Acceptance Criteria:**

**Given** phase 2 in the landing arena (6 → 0 HP)
**When** it runs
**Then** the Weaver uses 2 strands, a 0.75 s bite telegraph and a 90 px/s descent; all other rules match phase 1 (FR48)

**Given** 3 HP
**When** it is reached
**Then** the Weaver Re-Weaves, rebuilding the 2 strands with the 3.0 s glowing-thread telegraph

**Given** the guarantee test
**When** it scans phase-2 bites
**Then** every bite is telegraphed ≥ `Spec.TELEGRAPH_MIN` (NFR10)

### Story 6.8: Phase checkpoint and the respawn route

**Type:** dev

As a player,
I want a phase-2 death to send me back to phase 2,
So that I never replay a phase I've already beaten.

**Decide before dev (sonlm):** the phase-2 respawn route (GDD open question, UX O10), and whether a death during The Fall counts as phase 1 or phase 2.

**Acceptance Criteria:**

**Given** death in phase 1
**When** the player respawns
**Then** they are at the Hollow Station with full HP and the fight fully reset (FR49)

**Given** death in phase 2
**When** the player respawns
**Then** the fight resumes from phase 2 in the landing arena at 6 HP, with full player HP (FR49, UX-DR101)

**Given** the GDD open question "respawn point for a phase-2 death" and UX O10 ("how a phase-2 respawn reaches the landing arena")
**When** this story is planned
**Then** sonlm picks the route (e.g. respawn at the Hollow Station, then a short scripted descent straight to the landing arena), and it is recorded in the GDD and `EXPERIENCE.md`
**And** the checkpoint is saved in the slot and cleared on victory

### Story 6.9: Defeat, Weaver Silk and the repaired station

**Type:** dev

As a player,
I want the win to feel like a win, then show me the Weaver was never just a monster,
So that the climax lands and leaves a question.

**Decide before dev (sonlm):** UX O10: how the Swing unlock is shown.

**Acceptance Criteria:**

**Given** the Weaver reaches 0 HP
**When** the defeat plays
**Then** it reads as a win first: 0.5 s at ×0.3 through Clock, a burst of light, the landing-arena Lift Station repairs for free, then control returns; as a coda the Weaver dims and withdraws downward into the dark in sparks (never shown dying) (FR50, FR38, NR12, NR25)

**Given** the defeat
**When** it completes
**Then** Weaver Silk drops; picking it up unlocks Swing, shown as decided in this story (UX O10); `weaver_defeated` is set; the repaired station returns the player to the hub (FR50)
**And** the way down into Layer 2 stays sealed

### Story 6.10: Swing

**Type:** dev

As a player,
I want to grab silk anchors and swing without touching the ground,
So that I can reach what I saw but couldn't touch before.

**Acceptance Criteria:**

**Given** Swing unlocked and a silk anchor within 56 px (the E4 anchors become active)
**When** the player presses Dash
**Then** they grab the rope at the current distance, clamped to 32–96 px; holding Dash keeps them on; left/right pumps the pendulum; releasing Dash launches them at their current velocity ×1.1 (FR51)

**Given** no anchor in range, or Swing not unlocked
**When** the player presses Dash
**Then** it is the normal air dash with no delay

**Given** a live chain
**When** the player swings
**Then** the chain continues (no ground touch) and their light stays bright, so predators keep hunting them
**And** `PlayerInput` gains no new button (Pillar 4); tests cover grab range (56 vs 57 px), length clamps and the release multiplier

### Story 6.11: The partner's name and the closing lines

**Type:** content

As the designer,
I want the slice's last story text written and approved together,
So that the ending lands in the right voice.

**Acceptance Criteria:**

**Given** the narrative design
**When** this story runs
**Then** sonlm names Oda's dive partner (the one who went down with her on the dive where she found Glim), recorded in `narrative-design.md` (NR20)

**Given** the approved anchors
**When** Claude drafts the partner's Guild-tag text and Tessaly's "After the Weaver" lines (clue 3: Glim keeps coming back, "luck"; proud, uneasy; he logs the new depth, still short of Oda's record)
**Then** sonlm approves them before commit, and the clue budget holds (exactly three pointed clues in Layer 1) (NR19, NR23)
**And** the partner-tag flag gets its id in the registry (NR5)

### Story 6.12: The three Swing secrets

**Type:** dev, content

As a player who beat the Weaver,
I want the silk anchors I saw earlier to lead somewhere,
So that coming back to Layer 1 pays off.

**Decide before dev (sonlm):** which alcove (A, S2, C) holds Silk Grip, the Memorial clue and the hoard, and the fourth hoard's amount (a starting value to tune).

**Acceptance Criteria:**

**Given** the sealed alcoves behind `silk_a_1`, `silk_s2_1` and `silk_c_1`
**When** the player swings into each
**Then** they hold, as assigned by sonlm in this story: Silk Grip gear (found, not sold: `silk_grip` adds 0.25 s to cling grace), the Memorial clue (the partner's Guild tag) and the fourth Ember Hoard (FR52, FR62, AR16)

**Given** the Memorial clue
**When** the player picks it up
**Then** the partner-tag flag is set and the partner's name appears on the Memorial Wall (FR70, NR20)

**Given** a reachability test
**When** it runs each alcove room
**Then** each secret is reachable with Swing from its anchor and unreachable without it

### Story 6.13: The M2 closing beat

**Type:** dev

As a player,
I want to ride home watched by every creature I passed, and see my depth logged short of Oda's,
So that the slice ends on a question.

**Acceptance Criteria:**

**Given** the first ride up from the repaired landing-arena station
**When** it plays
**Then** the full Watching Departure runs through Layer 1 with Layer 1's cast (hoverers, crawlers, lurker eyes opening to watch, not hunt) within the ride's fixed time, and `departure_l2_seen` is set (FR74, NR19)

**Given** the first hub return after `weaver_defeated`
**When** the player talks to Tessaly
**Then** his "After the Weaver" lines play, he logs the new depth on the board, and it is still short of Oda's record (FR74, NR19)

### Story 6.14: Full-slice loop and guarantee pass

**Type:** dev

As the developer,
I want the whole slice checked end to end,
So that a tester can always finish it and always get home.

**Acceptance Criteria:**

**Given** the post-boss route
**When** it is played or scripted
**Then** the landing station returns to the hub, the Lip Station puts the player back at the top of Layer 1, all three secrets can be collected, and the gate-2 shortcut or the Hollow Station takes them home (UX-DR101)

**Given** `tests/smoke_weaver.gd` against the final arena
**When** it runs
**Then** phases 1 and 2 can be won with the starting kit and no Flare Toss, every bite is telegraphed ≥ `Spec.TELEGRAPH_MIN`, and the full fight follows the J5 flow (UX-DR109)

**Given** the softlock rules
**When** the full-slice checks run
**Then** zero softlocks are found and every room still passes `smoke_rooms` and the bot (NFR14)

### Story 6.15: E6 playtest

**Type:** playtest

As the designer,
I want the full slice played from a new game to the secrets,
So that I know whether the Weaver teaches restraint and Swing rewards the return trip.

**Acceptance Criteria:**

**Given** a private build of the full slice
**When** sonlm and at least one outside player play it
**Then** the answers to "does the fight teach restraint within 3–8 attempts?" and "does Swing make the return trip rewarding?" are recorded in `implementation-artifacts/` (FR47–FR52)
**And** a devlog or private build is posted; a "no" becomes the first stories of E7

## Epic 7: Slice Polish and Ship: The First Shared Build

About five outside testers play the polished M2 slice on web and desktop with full settings, the full Field Journal, composed music and the final art pass. Their notes are measured against the GDD Success Metrics, and the Steam vs itch.io decision is made.

### Story 7.1: Save format v5

**Type:** dev

As a player with an E6 save,
I want my slot to load in the shared build,
So that my progress survives the update.

**Acceptance Criteria:**

**Given** `rules/migrations.gd`
**When** a v4 slot loads
**Then** `migrate_v4_to_v5()` adds a marker recording whether the slot's current run has used timing assists, defaulting to "not used" (AR37)

**Given** the fixtures `slot_v1` … `slot_v4`
**When** the suite runs
**Then** each migrates to v5 and round-trips, and `tests/fixtures/slot_v5.json` is committed
**And** this story lands before any E7 feature writes a new field

### Story 7.2: Options > Video

**Type:** dev

As a player,
I want brightness, fullscreen and scale together in one place,
So that I can fit the game to my screen.

**Acceptance Criteria:**

**Given** Options
**When** E7 lands
**Then** a Video tab appears with Brightness (4 levels, moved here from Accessibility), Fullscreen and Scale (whole-number scales only) (FR33, UX-DR78, UX-DR133)
**And** each change applies at once and persists in `settings.json`; on web, Fullscreen sits beside the itch fullscreen button (UX-DR146)

### Story 7.3: Options > Controls: rebinding

**Type:** dev

As a player,
I want to rebind every action on keyboard and gamepad,
So that the controls fit my hands and my hardware.

**Decide before dev (sonlm):** the rule for a rebinding clash.

**Acceptance Criteria:**

**Given** the Controls tab
**When** the player rebinds an action
**Then** `InputMap` is edited, the binding is stored in `Settings`, and every glyph prompt and the controls reference update (FR33, AR35, UX-DR79, UX-DR124)

**Given** a binding that would clash with another action or create a chord
**When** it is confirmed
**Then** the clash is resolved by a clear rule decided in this story (e.g. swap the two bindings), and every action stays one button with no chords (NFR16)
**And** a "reset to defaults" option exists per device, and function keys can't be bound

### Story 7.4: Large HUD and text scale

**Type:** dev

As a player who needs bigger text,
I want a large HUD and scalable menu, speech and journal text,
So that I can read everything comfortably.

**Decide before dev (sonlm):** UX O12: the layout for ember counts above 4 digits and the text-scale layouts.

**Acceptance Criteria:**

**Given** Large HUD on
**When** the gutters draw
**Then** only numbers and icons double, at the DESIGN.md large-HUD positions; pips, meter, notch, grace bar and frame stay ×1; behaviour is unchanged (UX-DR102)

**Given** UX O12
**When** this story is planned
**Then** the layout for ember counts above 4 digits at 16 px and the text-scale layouts for menus, speech and journal are decided and recorded in `DESIGN.md` (UX-DR103, UX-DR134)

**Given** Text scale on
**When** menus, the speech box or the journal show text
**Then** they use the decided larger layout and still fit the 360 px column (UX-DR80)

### Story 7.5: Timing assists

**Type:** dev

As a player who struggles with timing,
I want a slower game speed as a separate assist,
So that I can play without changing what death costs.

**Acceptance Criteria:**

**Given** the Accessibility tab
**When** the player turns on a timing assist (e.g. game speed 80%)
**Then** `Game.clock.set_assist(0.8)` scales time together with any active Clock requests; difficulty, telegraph rules and chain rules are unchanged (FR35, AR36, UX-DR80)

**Given** a slot whose run used an assist
**When** records update
**Then** the run is kept out of the Guild records, using the v5 marker (FR35)

### Story 7.6: Visual sound cues

**Type:** dev

As a player who plays with sound off or can't hear well,
I want on-screen markers for predator sounds,
So that I never miss a warning the sound would have given me.

**Decide before dev (sonlm):** UX O14: the list of sounds that get a visual marker.

**Acceptance Criteria:**

**Given** UX O14 (the full list of visual sound cues)
**When** this story is planned
**Then** sonlm decides the list of sounds that get a marker (at least the lurker stirring, telegraph growl and hunting hiss) and it is recorded in `EXPERIENCE.md`

**Given** visual sound cues on
**When** a listed sound plays
**Then** a marker shows on its side of the play area; a stirring lurker shows an edge marker even before its eye opens (UX-DR134)
**And** markers never use colour as their only signal and respect the flash cap

### Story 7.7: The full Field Journal

**Type:** dev

As a player,
I want a journal that keeps my deaths, the lore I found and my records,
So that the abyss's story and my own are in one place.

**Acceptance Criteria:**

**Given** the Journal tab
**When** E7 lands
**Then** it adds the death log grouped by cause (from `slot.death_log`, collected since E1), the lore notes (documents read) with the Memorial Wall names, and the Guild records (FR78, UX-DR96)
**And** layout, empty states and "new" marks follow the E5 Journal tab design

### Story 7.8: HUD polish and the chain-cap cue

**Type:** dev

As a player,
I want the HUD to feel finished and to mark the moment I hit the chain cap,
So that the top of the chain feels like an achievement.

**Decide before dev (sonlm):** UX O11: whether chain 20 gets an extra cue, and which.

**Acceptance Criteria:**

**Given** UX O11
**When** this story is planned
**Then** sonlm decides whether reaching chain 20 gets an extra cue (and which), and it respects the flash cap and the accessibility gate (UX-DR141)

**Given** the HUD polish list from the E1–E6 playtests
**When** it is worked through
**Then** each item is fixed or deliberately parked with a note (FR80)

### Story 7.9: Player animation set

**Type:** content, dev

As a player,
I want Glim to move with clear, readable animations,
So that every action reads at a glance.

**Acceptance Criteria:**

**Given** sprite grids for about 10 animations (idle, run, jump, fall, pogo, slash, dash, cling, swing, hurt)
**When** `build_sprites.py` runs
**Then** each animation is built from text grids (no hand-made PNGs), with the reserved amber (`#ffd27a`) unchanged across palettes (FR80)
**And** the player's hurtbox and the M1 boxes are unchanged by the new art

### Story 7.10: Hub and Layer 2 landing palette pass

**Type:** content

As a player,
I want home to look warm and the landing arena to look like a new world,
So that the two ends of the slice feel distinct.

**Acceptance Criteria:**

**Given** the hub palette (E5) and the Bright Moon landing palette (E6)
**When** the art pass runs
**Then** both are final, their UI role tokens still pass the contrast floors, and the hub reads bright, warm and low contrast while the landing arena reads cool silver-blue (FR80, UX-DR10)

### Story 7.11: Title logo and Credits

**Type:** dev, content

As a player,
I want a real title and a credits screen,
So that the game feels finished and its makers and tools are named.

**Acceptance Criteria:**

**Given** title logo art (UX O19), built through the sprite pipeline
**When** the title shows
**Then** it replaces the E1 text placeholder (FR79)

**Given** the Credits screen
**When** the player opens it from Options (the entry now appears)
**Then** it shows `body-line` text on the Dusk surface, including the AI-assisted pipeline disclosure line and the Fusion Pixel Font credit, and pages or scrolls with Back returning to Options (UX-DR98, UX-DR16, NFR18)

### Story 7.12: Composed music

**Type:** designer, dev

As a player,
I want composed music that rises with my chain and themes for home, the Weaver and The Fall,
So that the soundtrack carries the game's feeling.

**Acceptance Criteria:**

**Given** sonlm's composed stems (laptop)
**When** they replace the placeholders
**Then** Layer 1 has `pulse`, `melody` and `full` stems of equal length, and the hub, Weaver and Fall themes exist; the hub theme carries the abyss motif sketched in E3 and the layer stems quote it (FR77)

**Given** the export pipeline
**When** the web build is made
**Then** the download stays under 30 MB with all music; if not, the plan-B steps from the architecture (web template with 3D disabled, stem compression) are applied (NFR5)

### Story 7.13: Performance pass

**Type:** dev

As a player on a modest laptop or in a browser,
I want the game to hold 60 FPS,
So that the feel never stutters.

**Acceptance Criteria:**

**Given** a 10-minute Layer 1 run including the Weaver fight
**When** it is measured at ×3 on the developer laptop and on an Intel HD 620-class iGPU
**Then** it holds 60 FPS with no frame over 20 ms outside the intentional 75 ms hitstop (NFR1)

**Given** the web build at the ×2 embed in desktop Chrome and Firefox
**When** it is measured
**Then** it holds 60 FPS, is playable within 10 s on a 50 Mbps link, and stays within 300 MB of memory (NFR4, NFR5)
**And** desktop memory stays ≤ 512 MB and hub → Lift Station load time is under 2 s on the laptop (NFR3, NFR4); any fix is recorded in `docs/perf.md`

### Story 7.14: Steam Deck and accessibility test passes

**Type:** playtest

As the designer,
I want the slice checked on Deck-sized screens and against the accessibility floor,
So that the shared build works for the players we said it would.

**Acceptance Criteria:**

**Given** the build at ×2 (960×540, letterboxed) on a Deck or a 7-inch equivalent with a gamepad
**When** the pass runs
**Then** the HUD and all text are readable, pad glyphs show everywhere, and battery behaviour is noted (NFR12, UX-DR131)

**Given** the accessibility pass (UX O15)
**When** it runs with a colour-blind simulation, with sound off and at ×2
**Then** every telegraph still reads by shape and motion, every cue respects the flash cap, and findings are fixed or logged (NFR8, NFR9)

**Given** the length validator
**When** it runs over all M2 text
**Then** every speech line, death line and journal text fits its box (NR8)

### Story 7.15: Final builds

**Type:** dev

As the developer,
I want release builds for web, Windows and Linux from one command,
So that testers get a clean, complete build.

**Acceptance Criteria:**

**Given** `tools/export.sh` on the server
**When** it runs the release presets
**Then** it validates rooms and strings, exports all three targets, copies `OFL.txt` and `LICENSES/` into each, keeps the web download under 30 MB and passes the web smoke check (FR81, AR52)

**Given** the release exports
**When** they are inspected
**Then** they contain no `rooms/dev/*`, no `tests/*` and no `scripts/dev/*`, and DevTools never loads

### Story 7.16: The tester round

**Type:** playtest

As the designer,
I want about five outside testers to play the slice and be measured against the Success Metrics,
So that M2's pillars are judged by players, not by me.

**Acceptance Criteria:**

**Given** about 5 testers with the shared build (web or desktop)
**When** they play and are interviewed
**Then** each GDD Success Metric is recorded against its target: "one more hit" and best chain ≥ 8 by the Weaver; naming what killed them for ≥ 80% of deaths; opening gate 2 or buying a map or hint; using Flare Toss and cling unprompted after S2; winning the Weaver within 8 attempts and calling it "about restraint" unprompted (FR81)

**Given** the story-clue question "Where do you think Glim comes from?"
**When** it is asked
**Then** the answers are recorded against the target (≥ 1 suspects the abyss, 0 certain), and clue volume is tuned if it misses
**And** a report goes into `implementation-artifacts/`

### Story 7.17: The distribution decision

**Type:** designer

As the designer,
I want to decide where the game is sold and how it's announced, with the tester report in hand,
So that M2 ends with a clear path forward.

**Acceptance Criteria:**

**Given** the tester report and the M2 build
**When** sonlm decides
**Then** Steam vs itch.io is chosen, the store and marketing plan is written (no store text calls the game a "roguelike" or "Downwell-like"; AI-assisted pipelines are disclosed), and the decision is recorded in the GDD (FR81, UX-DR56, NFR18)
**And** if Steam is chosen, Steam Cloud saves and Deck "Verified" become items for the next milestone
